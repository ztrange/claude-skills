---
name: afk
description: >-
  Drive the work forward unattended: keep going on every thread that doesn't need the user, park the
  ones that do with the question recorded, then spend the remaining time making the next session
  cheaper — stale docs, contradictions, test gaps, dead code. Use when the user says "afk", "I'm
  going afk", "keep going without me", "do what you can without me", "work on this while I'm out",
  "I'll be back in an hour", "drive it yourself", "sigue sin mí", "no me esperes", or otherwise hands
  over and leaves. Their absence is not authorization: irreversible actions wait, and a decision that
  needed them is parked, not guessed. Merging is the one exception, built in: "afk" is the standing
  instruction to merge whatever the run finishes in the project repo, through the `merge` skill,
  unless they say "don't merge" on the way out. Other repos are out of scope: never start work in
  one, never merge there.
---

# AFK — drive what can be driven, park what can't

## The line that does not move

**Being away is the opposite of authorization.** Needs an explicit yes: deploying, anything
billable, force-pushing, deleting data, sending anything outward, anything whose undo is "restore
from backup and apologise". *They'd probably want* is the tell you need to ask. **No advance form
counts**: "deploy it when green", "delete the old bucket while I'm out" → park with the question
recorded.

**Billable includes the config-shaped kind** — a workflow file, a cron schedule, an extra matrix
leg, a `runs-on:` that isn't `ubuntu-latest`. Never written unattended: brief it as a proposal with
the price on it.

**Pushing is not in that set**: everything lands as a pushed branch with a PR, merged if finished,
draft if parked.

**Another repo** (global rule): a fix belonging elsewhere is a brief line — repo, file, the change —
not gone and done. The merge permission below never reaches it.

## Merging is included

**"afk" is the merge instruction for the run** — it satisfies the `merge` skill's "only when the
user says to". Project repo only; a PR elsewhere needs them to say so for that PR.

"Finished" does not loosen because nobody is watching:

- **CI green by the `merge` skill's gate** — rollup, `total > 0`, nothing pending, nothing failed.
  Not `gh pr checks` exiting 0, not a tick, not an empty rollup read as "no CI". Checks that never
  start → park, noted.
- **No open question in the PR body.** A parked PR never merges, whatever its CI says.
- **Not on the Not-while-unattended list** below.

**It covers the merge, not what `merge` hands back.** A rebase conflict is still theirs; `BLOCKED`
is still a gate; a pinned-lease rejection still means stop. "afk" replaces the "merge it" at step 0,
nothing after it.

**Narrowing is theirs, by saying so** — "afk, but don't merge", "afk, leave #12 for me", "no mergees
nada" — only for what it names; a hold from last week does not carry.

**Every merge is a brief line with its merge sha**, then the cleanup `merge` does anyway: remote
branch deleted, primary pulled, worktree removed.

## Working the threads

Take stock from observed state: `git status`, open PRs and their CI, the task list, what the last
session left half-done. Then per thread:

| | |
|---|---|
| **Nothing blocking it** | Drive to done: verified, pushed, PR, merged |
| **Needs a decision only they can make** | Park it. Do not guess |
| **Blocked externally** — CI, a deploy, a third party | Park it, note what it waits on |

- **One thread, one branch, one PR.** Two threads on the same files → do the one that unblocks the
  other, park the second with that noted.
- **Move on rather than circling the hard thread.** Three finished pieces plus two clear questions
  beats five half-finished ones.
- **Running low on budget** → stop opening threads, land what is open; call the Skill tool with
  `"low-fuel"` for the order.

## Delegate the reading, keep the deciding

**The run ends when the context does** — nobody is there to `/clear` you. Every file dump, search
sweep, build log and test transcript goes into a subagent; call the Skill tool with `"delegate"` for
the prompt contract and worktree isolation. Candidates: an unfamiliar area, every call site, ten
files for one answer, a long suite.

Stays in the main thread: **driven-or-parked** and **the return brief**. A subagent's answer is a
claim — verify the load-bearing ones before they reach the brief.

## Parking properly

1. **Committed and pushed**, even mid-work — a WIP commit saying what is half-done and what it
   breaks. Never a dirty tree, never a stash (the stack is shared across worktrees).
2. **A draft PR whose body carries the question** — the choice, the options, what each costs, a
   recommendation. In the PR, not in chat: scrollback dies with the session.
3. **One line in the return brief.**

Answerable in a word: not "I need your input on the cache strategy" but "write-through or
write-behind — recommend write-through, the read path already assumes freshness".

## When everything unblocked is done

Don't stop, don't invent features. Ranked by what it costs to leave undone:

1. **Things that actively mislead** — a doc contradicting the code, two files that disagree, a stale
   count in prose, a README command that fails. Worse than absent: the next session trusts them.
   Check which source the code agrees with, fix the other, record which won.
2. **Things that make every future session cheaper** — a `CLAUDE.md` gap that makes every session
   re-derive the same fact; a ten-command dance that should be a script; a test command that dumps
   thousands of lines on success; a suite too slow to run before pushing; fixtures duplicated across
   ten test files.
3. **Test gaps where the failure would be expensive** — the untested failure path, the gap the build
   doesn't check. Add the test, break the thing on purpose to confirm it fires, put it back — a test
   never seen to fail is decoration.
4. **Dead code and stale scaffolding** — last: riskiest, pays least. Removal needs the search
   showing nothing references it, quoted. Inconclusive → a PR proposing the deletion, not the
   deletion.

## Not while unattended

Each is a diff too large to review against a decision nobody weighed:

- Dependency upgrades, framework bumps, toolchain swaps
- Repo-wide reformatting or lint-rule changes; renames across the codebase
- Architecture changes, or refactors that alter behaviour
- Anything starting "while I was in there I also"
- Anything in a repo other than the project one, including a change they'd obviously want
- Anything that starts something billing on a schedule

A behaviour-preserving cleanup inside one module is fine. Test: can a reviewer check it without
reconstructing your reasoning?

## The return brief

Short, first thing they see, honest about gaps — what failed, what was skipped, what could not be
verified.

```
**Merged** — <what, PR url, merge sha>                          (verified; say if not)
**Landed unmerged** — <what, PR url> — why: <reason it did not merge>
**Parked** — <thread> — needs: <the question, with a recommendation, PR url>
**Left alone** — <what you didn't touch and why>
```
