"""Worked example: five slide patterns that read as designed, built with deck_kit.

    python example_build.py <brand.json> <scratch_dir> <out.pptx> [hero.jpg]

Copy it per run and replace the copy; keep the patterns that fit. Each slide ends with its
'CANVA ANIMATIONS —' note, which stage 3 applies in Canva. Placeholder copy is English; a real run
writes copy in the product's language.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
from PIL import Image  # noqa: E402

from deck_kit import H, MSO_ANCHOR, MSO_SHAPE, PP_ALIGN, W, Deck, crop_to  # noqa: E402

brand, S, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(S, exist_ok=True)
hero = sys.argv[4] if len(sys.argv) > 4 else None
if not hero:  # placeholder photo so the example runs with no assets
    hero = f"{S}/hero-placeholder.jpg"
    Image.new("RGB", (1600, 1000), (120, 140, 170)).save(hero)

d = Deck(brand, S)
c = d.c
hero_tall = crop_to(hero, f"{S}/hero-tall.jpg", 5.6 / H)
hero_wide = crop_to(hero, f"{S}/hero-wide.jpg", (W - 1.0) / H)

# ── 1 Cover: photo right, diagonal edge, accent strip ───────
s = d.slide()
d.frame(s, logo=False)
d.picture(s, hero_tall, W - 5.6, 0, h=H)
d.shape(s, MSO_SHAPE.RIGHT_TRIANGLE, W - 5.6, 0, 1.6, H, c("white"), name="Photo edge").rotation = 180
d.shape(s, MSO_SHAPE.RECTANGLE, W - 4.35, H - 0.22, 4.35, 0.22, c("accent"), name="Accent strip")
d.kicker(s, 1.7, 1.55, "KICKER LINE")
d.text(s, 1.7, 2.0, 7, 1.5, "Deck title", 72, c("primary"), True, name="Title")
d.shape(s, MSO_SHAPE.RECTANGLE, 1.75, 3.45, 1.4, 0.12, c("accent"), name="Title underline")
d.text(s, 1.7, 3.85, 5.6, 1.6,
       [[("Lead phrase", c("primary"), True), (" and the one-sentence promise of the deck.", c("ink"), False)]],
       20, name="Subtitle")
d.notes(s, "CANVA ANIMATIONS — Page: 'Rise'. (Optional per element: photo 'Pan' slow, title 'Rise', "
           "underline 'Wipe' left→right, subtitle 'Fade'.)")

# ── 2 Big number + cards ─────────────────────────────────────
s = d.slide()
d.frame(s)
d.kicker(s, 1.7, 0.95, "WHAT")
d.text(s, 1.55, 1.15, 4.2, 4.6, "4", 300, c("accent"), True, name="Big number")
d.text(s, 1.7, 5.4, 4.4, 1.4, "things the audience should remember", 22, c("primary"), True,
       name="Number caption")
for i, name in enumerate(["First item", "Second item", "Third item", "Fourth item"]):
    y = 1.55 + i * 1.3
    card = d.shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 6.3, y, 6.35, 1.08, c("pale"), name=f"Card {i + 1}")
    card.adjustments[0] = 0.5
    d.text(s, 6.8, y, 5.6, 1.08, name, 21, c("primary"), True, anchor=MSO_ANCHOR.MIDDLE,
           name=f"Item {i + 1}")
    if i == 0:
        pill = d.shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, 11.25, y - 0.2, 1.5, 0.42, c("accent"), name="Tag")
        pill.rotation, pill.adjustments[0] = -6, 0.5
        d.label_in(pill, "New", 12, c("deep"))
d.notes(s, "CANVA ANIMATIONS — Page: 'Pop'. (Optional: big number 'Stomp', cards 'Rise' one by one.)")

# ── 3 Dark timeline ──────────────────────────────────────────
s = d.slide()
d.frame(s, dark=True)
d.kicker(s, 1.7, 0.95, "HOW")
d.text(s, 1.7, 1.35, 10, 1.0, "From start to done in six steps", 44, c("white"), True, name="Title")
steps = [("One", "Short description"), ("Two", "Short description"), ("Three", "Short description"),
         ("Four", "Short description"), ("Five", "Short description"), ("Done", "Short description")]
x0, step, cy = 1.7, 1.86, 3.35
d.line(s, x0 + 0.45, cy, x0 + 5 * step + 0.45, cy, c("accent"), 4, name="Timeline")
for i, (t, desc) in enumerate(steps):
    cx, last = x0 + i * step, i == len(steps) - 1
    dot = d.shape(s, MSO_SHAPE.OVAL, cx, cy - 0.45, 0.9, 0.9, c("accent") if last else c("white"),
                  name=f"Step {i + 1}")
    d.label_in(dot, str(i + 1), 24, c("deep"))
    d.text(s, cx - 0.35, cy + 0.7, 1.6, 0.5, t, 20, c("accent") if last else c("white"), True, PP_ALIGN.CENTER)
    d.text(s, cx - 0.35, cy + 1.2, 1.6, 1.3, desc, 12.5, c("soft"), False, PP_ALIGN.CENTER, spacing=0.1)
d.notes(s, "CANVA ANIMATIONS — Page: 'Wipe'. (Optional: timeline 'Wipe' slow, dots 'Pop' in order.)")

# ── 4 Hub and spokes ─────────────────────────────────────────
s = d.slide()
d.frame(s)
d.kicker(s, 1.7, 0.95, "BEHIND IT")
d.text(s, 1.7, 1.35, 10, 1.0, "Everything runs on one core", 40, c("primary"), True, name="Title")
hx, hy, hr, tw, th = 7.15, 4.45, 1.25, 3.6, 1.6
tiles = [(1.7, 2.65, "Partner A"), (9.05, 2.65, "Partner B"), (1.7, 4.85, "Partner C"), (9.05, 4.85, "Partner D")]
for x, y, _ in tiles:
    d.line(s, x + tw if x < hx else x, y + th / 2, hx, hy, c("accent"), 3, name="Spoke")
for i, (x, y, t) in enumerate(tiles):
    d.shape(s, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, tw, th, c("pale"), name=f"Partner {i + 1}").adjustments[0] = 0.15
    d.text(s, x + 0.25, y + 0.2, tw - 0.4, 0.45, t, 16, c("primary"), True)
    d.text(s, x + 0.25, y + 0.78, tw - 0.5, 0.75, "What it does, one line", 12.5, c("muted"), spacing=0.1)
halo = d.shape(s, MSO_SHAPE.OVAL, hx - hr - 0.18, hy - hr - 0.18, 2 * hr + 0.36, 2 * hr + 0.36,
               c("accent"), name="Hub halo")
d.alpha(halo, 35)
d.shape(s, MSO_SHAPE.OVAL, hx - hr, hy - hr, 2 * hr, 2 * hr, c("primary"), name="Hub")
d.text(s, hx - hr + 0.2, hy - 0.3, 2 * hr - 0.4, 0.6, "Core", 22, c("white"), True, PP_ALIGN.CENTER)
d.notes(s, "CANVA ANIMATIONS — Page: 'Fade'. (Optional: hub 'Pop' first, spokes 'Wipe' outward.)")

# ── 5 Closing over a veiled photo ────────────────────────────
s = d.slide()
d.picture(s, hero_wide, 1.0, 0, h=H)
d.alpha(d.shape(s, MSO_SHAPE.RECTANGLE, 1.0, 0, W - 1.0, H, c("deep"), name="Veil"), 82)
d.frame(s, logo=False)
if d.logo_white:
    d.picture(s, d.logo_white, W - 2.35, 0.38, h=0.5)
d.kicker(s, 1.7, 1.55, "NEXT")
d.text(s, 1.7, 2.0, 10.5, 2.2, ["The closing line:", [("one accent phrase", c("accent"), True)]], 60,
       c("white"), True, spacing=0.05, name="Title")
d.shape(s, MSO_SHAPE.RECTANGLE, 1.75, 5.55, 0.9, 0.08, c("accent"), name="Rule")
d.text(s, 1.7, 5.8, 10.5, 0.8, "The sentence people leave with.", 28, c("white"), True, name="Closing line")
d.notes(s, "CANVA ANIMATIONS — Page: 'Pan'. (Optional: closing line 'Typewriter', last, after a pause.)")

print("saved", d.save(OUT))
