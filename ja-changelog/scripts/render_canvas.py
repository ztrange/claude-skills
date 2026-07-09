#!/usr/bin/env python3
"""
Render / re-render a per-app Slack canvas body for the Jalisco Alerta changelog.

Why this exists: the changelog now lives in four per-app Slack canvases (App JA,
Gabinete, EDL, SIGEM), one release per `### vX.Y.Z (fecha)` grouped under `## Mes AAAA`
month headers. The Slack integration's targeted `replace` (with a section_id) INSERTS a
duplicate instead of replacing, so the only safe way to add a release without leaving
cruft is to REBUILD the whole canvas body and full-replace it. This script does the
deterministic part: month grouping + heading levels. The model then full-replaces the
canvas with this body and re-adds the `**Meses:**` index + `↑ Arriba` links via prepend.

Two modes:

  # build: flat newest-first entries -> structured canvas body (# product / ## month / ### release)
  python3 render_canvas.py --product "JA Gabinete" < flat_entries.md > body.md

  # extract: an existing canvas markdown dump -> the flat entry list (### -> ##, drops
  #          the product title, the **Meses:** index, ## month headers, and ↑ Arriba links)
  python3 render_canvas.py --extract < canvas_dump.md > flat_entries.md

Typical add-a-release flow:
  1. slack_read_canvas -> save its markdown to canvas_dump.md
  2. render_canvas.py --extract < canvas_dump.md > flat.md
  3. put the new `## vX.Y.Z (D mes AAAA)` + bullets at the TOP of flat.md
  4. render_canvas.py --product "<name>" < flat.md > body.md
  5. slack_update_canvas replace (NO section_id) with body.md
  6. slack_read_canvas -> prepend `**Meses:**` index under the product header,
     and an `↑ Arriba` link under each `## Mes AAAA` header (prepend only; never replace).

A "flat entry" is a `## vX.Y.Z (D mes AAAA)` heading followed by its bullet lines
(top-level `- `, nested `    - `). Newest first. Version RANGES / odd tokens are kept verbatim.
"""
import argparse
import re
import sys

MONTHS = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
          "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
MONTH_HEADER_RE = re.compile(r'^(?:' + '|'.join(m.capitalize() for m in MONTHS) + r')\s+\d{4}$')


def month_year(heading):
    """Extract (mes, año) from a version heading's parenthetical date, e.g. '## v2.27.0 (1 julio 2026)'."""
    m = re.search(r'\((?:\d+\s+)?([a-záéíóúü]+)\s+(\d{4})\)', heading, re.I) \
        or re.search(r'([a-záéíóúü]+)\s+(\d{4})', heading, re.I)
    return (m.group(1).lower(), m.group(2)) if m else None


def parse_flat(text):
    """Parse flat entries: list of (version_heading, [body_lines]). Accepts ## or ### version headings."""
    entries, cur = [], None
    for ln in text.split("\n"):
        s = ln.rstrip()
        if re.match(r'^#\s', s):                    # product title '# ...' — always skip
            continue
        head_text = s.lstrip("#").strip() if (s.startswith("## ") or s.startswith("### ")) else None
        if head_text is not None and MONTH_HEADER_RE.match(head_text):
            continue                                # '## Julio 2026' month header — skip, don't pollute body
        if head_text is not None:                   # a version entry heading (## or ###)
            if cur:
                entries.append(cur)
            cur = ["## " + head_text, []]
        elif cur is not None:
            if s.startswith("**Meses:**") or s.lstrip().startswith("[↑"):
                continue                            # skip index line and ↑ Arriba links
            cur[1].append(ln)
    if cur:
        entries.append(cur)
    # trim leading/trailing blank body lines
    for _, body in entries:
        while body and not body[0].strip():
            body.pop(0)
        while body and not body[-1].strip():
            body.pop()
    return entries


def build(product, entries):
    out = [f"# {product}", ""]
    cur_my = None
    for heading, body in entries:
        my = month_year(heading)
        label = f"{my[0].capitalize()} {my[1]}" if my else "Sin fecha"
        if my != cur_my:
            out += [f"## {label}", ""]
            cur_my = my
        out.append("### " + heading[3:])          # ## vX -> ### vX
        out += body + [""]
    return "\n".join(out).rstrip() + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--product", help="Product name for the '# ' header (build mode).")
    ap.add_argument("--extract", action="store_true",
                    help="Extract flat '## vX' entries from a canvas markdown dump.")
    args = ap.parse_args()
    text = sys.stdin.read()
    entries = parse_flat(text)
    if args.extract:
        out = []
        for heading, body in entries:
            out.append(heading)
            out += body + [""]
        sys.stdout.write("\n".join(out).rstrip() + "\n")
    else:
        if not args.product:
            sys.exit("--product is required in build mode")
        sys.stdout.write(build(args.product, entries))


if __name__ == "__main__":
    main()
