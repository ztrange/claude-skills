---
name: canva-deck
description: >-
  Turn a brief into a flashy but tasteful, fully animated Canva deck in three gated stages: full
  text outline → slide prototypes the user reviews → a brand-new Canva design with editable text
  and one animation per slide. Use when the user asks for a Canva deck, Canva presentation or Canva
  slides, or to "make the slides in Canva".
---

# canva-deck — outline → prototypes → animated Canva deck

**Three stages, each ending in a stop for the user's edits.** Nothing reaches Canva until the
user has approved the words (stage 1) and the look (stage 2); a Canva design is the most expensive
place to discover the copy was wrong. Work through `/delegate` where it keeps the main context
small — building and rendering run in a subagent that returns paths and a slide count, not logs.

## Inputs — ask once, up front, in one message

| Input | Default if not given |
|---|---|
| Audience, and what they already know | none — ask; it decides what *not* to say |
| Purpose / the one thing they should leave with | none — ask |
| Slide cap | 5 |
| Style-reference Canva link (an existing deck to match) | none — use the brand alone |
| Brand: logo file (SVG/PNG), fonts, colours | read from the reference deck or the product repo's assets |
| Language of the copy | the product's language |
| Photos / product images | from the product repo's assets, if any |

## Stage 1 — outline (text only)

1. Write the **full text of every slide** — kicker, title, body, footer — in the product's
   language, plus one line per slide naming its layout pattern (see
   [`references/example_build.py`](references/example_build.py): cover, big number + cards, dark
   timeline, hub and spokes, closing over a veiled photo).
2. Cut what the audience already knows. An internal audience that knows the products does not need
   feature benefits or dev status.
3. Print it all and **stop**. The user edits the words here; do not start stage 2 on silence.

## Stage 2 — prototypes

1. Scratchpad venv (never the project's): `uv venv <scratch>/venv && uv pip install --python
   <scratch>/venv python-pptx Pillow resvg-py`. `resvg-py` is only for SVG logos.
2. Write `<scratch>/brand.json` (shape: [`references/brand.example.json`](references/brand.example.json)),
   then copy `references/example_build.py` to `<scratch>/build.py` and replace its slides with the
   approved outline. Build with [`scripts/deck_kit.py`](scripts/deck_kit.py): every element is a
   native text box / shape / picture, so **text stays editable in Canva**. Write each slide's
   animation plan into its notes, prefixed `CANVA ANIMATIONS —`, with one *page* animation named
   first.
3. Render: `python scripts/preview.py deck.pptx <scratch>/preview/index.html "<Font>"`, serve with
   `node scripts/serve.mjs <scratch>/preview 8765` (Bash, `run_in_background`), open
   `http://localhost:8765` with `preview_start`, and screenshot each `#sN`.
4. Check every slide for overflow, overlap and text that hugs an edge; fix and re-render before
   showing. The preview is approximate (fonts from Google Fonts, no kerning) — it checks layout,
   not pixels.
5. Show the screenshots and **stop** for edits.

Taste rules, applied while building: one accent colour, used sparingly; the reference deck's
recurring chrome (side bar, logo position, kicker style) on every slide; at most one dark slide
in the middle for rhythm; one idea per slide; numbers big, sentences short.

## Stage 3 — the Canva deck (Claude in Chrome)

Canva needs the user's signed-in session, so this runs in **Claude in Chrome**, not the built-in
browser. Ask before switching if Chrome isn't connected.

1. Import the `.pptx` from Canva's home (drag it in, or *Create* → *Import file*) so it becomes a
   **new design**.
   Never edit the style-reference deck, not even to duplicate a page into it.
2. Rename the design to the deck's title.
3. Per slide: select the page (click empty canvas, not an element), *Animate* → the page animation
   from its notes, *On enter*. One page animation per slide; per-element animations only where the
   notes call for them and the user asked for more motion.
4. Verify each slide after animating: text still editable, nothing shifted, fonts held. Then
   return the design's link.

## Don't

- **No Keynote.** Exporting through Keynote via `osascript` hangs on AppleEvents; Quick Look
  renders nothing. python-pptx → HTML preview is the path.
- **No PowerPoint animations.** Canva drops them on import; set them in Canva.
- **No `python -m http.server`** (PermissionError in the sandbox) and no `file://` (the built-in
  browser refuses it) — use `serve.mjs`.
- **No keystrokes on the Canva canvas outside text-edit mode**: single keys are shortcuts (`c`
  draws a circle, `t` adds text). Double-click into text, confirm the selection highlight, then
  type; `cmd+z` recovers.

## Gotchas

- Canva canvas is 1920×1080 px = 144 px/in on the 13.333×7.5 in slide. Import keeps fonts,
  colours and images.
- Semi-transparent overlays render lighter in Canva than in the preview: veils need a few points
  more opacity than looks right in stage 2.
- Decline non-essential cookies on Canva's banner.
- Preview HTML needs `<meta charset="utf-8">` or accented copy turns to mojibake — `preview.py`
  emits it.
