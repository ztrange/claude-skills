#!/usr/bin/env python3
"""Read-only health snapshot of this Mac: load, memory, CPU by session tree, orphans, runaway
system daemons. Kills nothing; prints findings with the command that would fix each.

    python3 -I snapshot.py            # report, always exit 0
    python3 -I snapshot.py --check    # same report, exit 1 if any finding is WARN or CRIT
    python3 -I snapshot.py --quiet --check   # print only findings (for schedulers)
    python3 -I snapshot.py --fix      # also kill leaked Claude Bash shells (the only auto-fix)

macOS only: it reads `top -l`, `sysctl vm.swapusage` and `memory_pressure`.
"""
import os
import re
import signal
import subprocess
import time
import sys

# Thresholds. CPU figures are percent of one core, measured over a 2 s `top` sample rather than
# `ps %cpu`, which is a decaying average and lags a process that just started or stopped.
LOAD_WARN, LOAD_CRIT = 1.0, 1.5          # load average / cores
FREE_WARN, FREE_CRIT = 20, 10            # memory_pressure "free percentage"
SWAP_WARN = 0.75                         # fraction of swap in use
DAEMON_CPU_WARN = 40                     # fseventsd, mds*, mdworker*, sysmond
FSEVENTSD_CRIT = 80                      # the one that has wedged the machine before
TREE_CPU_WARN = 400                      # one session tree using > 4 cores
APP_CPU_WARN = 80                        # Claude.app main process
ORPHAN_MIN_AGE = int(os.environ.get("MH_ORPHAN_MIN_AGE", 600))  # s; younger PPID-1 ones are mid-handoff
IDLE_SESSION_AGE = 24 * 3600             # s; a claude CLI this old and idle is worth a look

SYSTEM_PREFIXES = ("/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/Library/Apple/",
                   "/usr/bin/", "/Library/")
DAEMONS = re.compile(r"(^|/)(fseventsd|mds|mds_stores|mdworker(_shared)?|sysmond|spotlightknowledged)$")
LEAKED_SHELL = re.compile(r"\.claude/shell-snapshots/snapshot-")


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def etime_seconds(s):
    days, _, rest = s.strip().rpartition("-")
    parts = [int(p) for p in rest.split(":")]
    while len(parts) < 3:
        parts.insert(0, 0)
    h, m, sec = parts
    return (int(days) if days else 0) * 86400 + h * 3600 + m * 60 + sec


def human_age(sec):
    if sec >= 86400:
        return f"{sec // 86400}d{(sec % 86400) // 3600}h"
    if sec >= 3600:
        return f"{sec // 3600}h{(sec % 3600) // 60}m"
    return f"{sec // 60}m"


def processes():
    out = run(["ps", "-Ao", "pid=,ppid=,uid=,stat=,rss=,etime=,command="])
    procs = {}
    for line in out.splitlines():
        f = line.split(None, 6)
        if len(f) < 7:
            continue
        pid, ppid, uid, stat, rss, etime, cmd = f
        procs[int(pid)] = dict(pid=int(pid), ppid=int(ppid), uid=int(uid), stat=stat,
                               rss_mb=int(rss) // 1024, age=etime_seconds(etime), cmd=cmd, cpu=0.0)
    # Second sample of `top -l 2` is the instantaneous one; the first is since-boot.
    top = run(["top", "-l", "2", "-s", "2", "-o", "cpu", "-n", "200", "-stats", "pid,cpu"])
    sample = top.split("PID")[-1].splitlines()[1:]
    for line in sample:
        f = line.split()
        if len(f) == 2 and f[0].isdigit():
            p = procs.get(int(f[0]))
            if p:
                p["cpu"] = float(f[1])
    return procs


def short(cmd, n=110):
    cmd = re.sub(r"^/(usr/local/Cellar|opt/homebrew/Cellar)/python@[^ ]+/Python", "python", cmd)
    cmd = re.sub(r"^/Applications/([^/]+)\.app/\S*", r"[\1]", cmd)
    cmd = re.sub(r"^/Users/[^/]+/Library/Application Support/Claude/claude-code/\S+/claude",
                 "claude", cmd)
    return cmd if len(cmd) <= n else cmd[: n - 1] + "…"


def is_claude_cli(p):
    return bool(re.match(r"^(claude( |$)|\S*/claude\.app/Contents/MacOS/claude)", p["cmd"]))


def children_map(procs):
    kids = {}
    for p in procs.values():
        kids.setdefault(p["ppid"], []).append(p["pid"])
    return kids


def tree_root(pid, procs):
    """Nearest claude CLI ancestor (a session), else the top ancestor below launchd."""
    p, top = procs.get(pid), pid
    while p and p["ppid"] not in (0, 1):
        if is_claude_cli(p):
            return p["pid"]
        top = p["ppid"]
        p = procs.get(top)
    if p and is_claude_cli(p):
        return p["pid"]
    return top


def launchd_pids():
    """PIDs launchd runs as jobs: PPID 1 is their normal state, not an orphan's."""
    pids = set()
    for line in run(["launchctl", "list"]).splitlines():
        f = line.split()
        if f and f[0].isdigit():
            pids.add(int(f[0]))
    return pids


def kill_leaked_shell(p):
    """TERM, then KILL after 5 s. Re-reads the pid's command and start time first, so a pid
    reused since the snapshot is never hit. Returns what happened, for the report."""
    pid = p["pid"]
    def ident():
        out = run(["ps", "-o", "ppid=,lstart=,command=", "-p", str(pid)]).strip()
        return out or None
    before = ident()
    if not before or before.split()[0] != "1" or not LEAKED_SHELL.search(before):
        return "skipped: pid no longer a PPID-1 leaked shell"
    for sig, wait in ((signal.SIGTERM, 5), (signal.SIGKILL, 2)):
        try:
            os.kill(pid, sig)
        except ProcessLookupError:
            return "gone"
        for _ in range(wait * 10):
            if ident() != before:
                return f"killed ({sig.name})"
            time.sleep(0.1)
    return "STILL ALIVE after SIGKILL"


def session_cwd(pid):
    out = run(["lsof", "-a", "-p", str(pid), "-d", "cwd", "-Fn"])
    for line in out.splitlines():
        if line.startswith("n"):
            return line[1:]
    return "?"


def main():
    check = "--check" in sys.argv
    fix = "--fix" in sys.argv
    quiet = "--quiet" in sys.argv
    me = os.getuid()
    procs = processes()
    kids = children_map(procs)
    findings = []  # (level, title, detail lines)

    def add(level, title, *detail):
        findings.append((level, title, list(detail)))

    # --- Load and memory -------------------------------------------------------------------------
    cores = int(run(["sysctl", "-n", "hw.ncpu"]).strip() or 1)
    load = [float(x) for x in run(["sysctl", "-n", "vm.loadavg"]).strip("{} \n").split()[:3]]
    ratio = load[0] / cores
    swap = run(["sysctl", "-n", "vm.swapusage"])
    m = re.search(r"total = ([\d.]+)M\s+used = ([\d.]+)M", swap)
    swap_total, swap_used = (float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0)
    m = re.search(r"free percentage: (\d+)%", run(["memory_pressure"]))
    free_pct = int(m.group(1)) if m else -1

    header = (f"load {load[0]:.1f}/{load[1]:.1f}/{load[2]:.1f} on {cores} cores ({ratio:.2f}×)  ·  "
              f"memory free {free_pct}%  ·  swap {swap_used:.0f}/{swap_total:.0f} MB  ·  "
              f"{len(procs)} processes")

    if ratio >= LOAD_CRIT:
        add("CRIT", f"load {load[0]:.1f} is {ratio:.1f}× the {cores} cores")
    elif ratio >= LOAD_WARN:
        add("WARN", f"load {load[0]:.1f} is {ratio:.1f}× the {cores} cores")
    if 0 <= free_pct < FREE_CRIT:
        add("CRIT", f"memory free {free_pct}% (memory_pressure)")
    elif 0 <= free_pct < FREE_WARN:
        add("WARN", f"memory free {free_pct}% (memory_pressure)")
    if swap_total and swap_used / swap_total >= SWAP_WARN:
        add("WARN", f"swap {swap_used:.0f} of {swap_total:.0f} MB in use")

    # --- CPU by session tree ---------------------------------------------------------------------
    trees = {}
    for p in procs.values():
        if p["cpu"] <= 0:
            continue
        r = tree_root(p["pid"], procs)
        t = trees.setdefault(r, {"cpu": 0.0, "n": 0})
        t["cpu"] += p["cpu"]
        t["n"] += 1
    ranked = sorted(trees.items(), key=lambda kv: -kv[1]["cpu"])[:8]
    tree_lines = []
    for root, t in ranked:
        rp = procs.get(root, {"cmd": "?", "age": 0})
        where = ""
        if root in procs and is_claude_cli(rp):
            where = f"  cwd {session_cwd(root)}"
        tree_lines.append(f"{t['cpu']:6.0f}%  {t['n']:3d} busy  pid {root:<6} "
                          f"{human_age(rp['age']):>6}  {short(rp['cmd'], 70)}{where}")
        if t["cpu"] >= TREE_CPU_WARN:
            add("WARN", f"tree pid {root} uses {t['cpu']:.0f}% CPU across {t['n']} processes",
                short(rp["cmd"]) + where,
                f"inspect: pstree -p {root}  ·  stop it: kill -TERM -- -$(ps -o pgid= -p {root})")

    # --- System daemons --------------------------------------------------------------------------
    for p in procs.values():
        base = p["cmd"].split()[0]
        if DAEMONS.search(base) and p["cpu"] >= DAEMON_CPU_WARN:
            name = base.rsplit("/", 1)[-1]
            if name == "fseventsd":
                level = "CRIT" if p["cpu"] >= FSEVENTSD_CRIT else "WARN"
                add(level, f"fseventsd at {p['cpu']:.0f}% CPU (pid {p['pid']})",
                    "recover (root, launchd respawns it): sudo killall fseventsd; "
                    "sleep 10; pgrep -x fseventsd && sudo killall -9 fseventsd",
                    "cause is usually a file-event storm: a test suite or build churning a "
                    "watched tree — find it in the CPU-by-tree table")
            else:
                add("WARN", f"{name} at {p['cpu']:.0f}% CPU (pid {p['pid']})",
                    "Spotlight indexing churn; exclude the busy tree in System Settings → "
                    "Spotlight → Search Privacy")

    app = [p for p in procs.values()
           if p["cmd"].startswith("/Applications/Claude.app/Contents/MacOS/Claude")]
    for p in app:
        if p["cpu"] >= APP_CPU_WARN:
            add("WARN", f"Claude.app main process at {p['cpu']:.0f}% CPU, up {human_age(p['age'])}",
                "restart the app to clear it — this ends every desktop session it hosts")

    # --- Orphans and zombies ---------------------------------------------------------------------
    managed = launchd_pids()
    for p in procs.values():
        if p["uid"] != me or p["ppid"] != 1 or p["age"] < ORPHAN_MIN_AGE:
            continue
        cmd = p["cmd"]
        if LEAKED_SHELL.search(cmd):
            body = re.search(r"eval '([^']{0,120})", cmd)
            body = body.group(1) if body else short(cmd)
            title = f"leaked Claude Bash shell pid {p['pid']}, up {human_age(p['age'])}"
            if fix:
                outcome = kill_leaked_shell(p)
                add("FIXED" if outcome.startswith(("killed", "gone")) else "WARN",
                    f"{title}: {outcome}", f"body: {body}")
            else:
                add("WARN", title, f"body: {body}", f"kill: kill {p['pid']}")
            continue
        if p["pid"] in managed or cmd.startswith(SYSTEM_PREFIXES) or ".app/Contents/" in cmd or cmd.startswith("/Applications/"):
            continue
        live_kids = [k for k in kids.get(p["pid"], []) if k in procs]
        if live_kids:
            continue  # detached on purpose (daemons, run conductors) — counted in its tree instead
        add("INFO", f"orphan candidate pid {p['pid']}, up {human_age(p['age'])}, "
                    f"{p['cpu']:.0f}% CPU, {p['rss_mb']} MB",
            short(cmd), f"kill: kill {p['pid']}")

    zombies = [p for p in procs.values() if p["stat"].startswith("Z")]
    if zombies:
        parents = sorted({z["ppid"] for z in zombies})
        add("INFO", f"{len(zombies)} zombie(s); parents {parents} have not reaped them",
            *[f"parent {pp}: {short(procs[pp]['cmd'])}" for pp in parents if pp in procs])

    # --- Idle long-lived claude sessions ---------------------------------------------------------
    for p in procs.values():
        if is_claude_cli(p) and p["age"] >= IDLE_SESSION_AGE and p["cpu"] < 1:
            add("INFO", f"idle claude session pid {p['pid']}, up {human_age(p['age'])}, "
                        f"{p['rss_mb']} MB", f"cwd {session_cwd(p['pid'])}")

    # --- Output ----------------------------------------------------------------------------------
    order = {"CRIT": 0, "WARN": 1, "FIXED": 2, "INFO": 3}
    findings.sort(key=lambda f: order[f[0]])
    if not quiet:
        print(header)
        print("\nCPU by tree (2 s sample; root = owning claude session, else top ancestor):")
        print("\n".join(tree_lines) or "  (idle)")
        print()
    if findings:
        print("Findings:")
        for level, title, detail in findings:
            print(f"  {level:5} {title}")
            for d in detail:
                print(f"        {d}")
    elif not quiet:
        print("Findings: none")
    if check and any(f[0] in ("CRIT", "WARN") for f in findings):
        sys.exit(1)


if __name__ == "__main__":
    main()
