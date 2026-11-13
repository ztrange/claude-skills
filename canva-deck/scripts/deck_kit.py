"""Helpers for building an editable 16:9 .pptx that imports cleanly into Canva.

Every element is a native text box, shape, line or picture, so Canva keeps the text editable after
import. Animations are NOT written here: Canva drops PowerPoint animations on import, so the
animation plan goes into each slide's speaker notes (`notes()`) and is applied in Canva itself.

Usage from a per-run build script:

    from deck_kit import Deck
    d = Deck("brand.json", assets_out="/scratch/assets")
    s = d.slide()
    d.frame(s)
    d.kicker(s, 1.7, 1.0, "KICKER")
    d.text(s, 1.7, 1.4, 10, 1, "Title", 44, d.c("primary"), True, name="Title")
    d.notes(s, "CANVA ANIMATIONS — Title: 'Rise'.")
    d.save("/scratch/deck.pptx")

brand.json:
    {"font": "Montserrat",
     "colors": {"primary": "003896", "deep": "001F5C", "accent": "9CD41C", "ink": "1E1E1E",
                "muted": "6B7280", "pale": "EEF3FB", "soft": "B9CCEE", "white": "FFFFFF"},
     "logo": "/abs/path/logo.svg|png"   # optional; SVG is rasterised with resvg-py
    }
"""
import json
import os

from lxml import etree
from PIL import Image, ImageDraw
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

W, H = 13.333, 7.5  # inches; Canva maps this to 1920×1080 (144 px/in)

__all__ = ["Deck", "MSO_SHAPE", "PP_ALIGN", "MSO_ANCHOR", "W", "H", "crop_to", "round_png",
           "to_png", "whiten"]


def crop_to(src, out, ratio):
    """Centre-crop an image to width/height `ratio`."""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    if w / h > ratio:
        nw = int(h * ratio)
        x = (w - nw) // 2
        im = im.crop((x, 0, x + nw, h))
    else:
        nh = int(w / ratio)
        y = (h - nh) // 2
        im = im.crop((0, y, w, y + nh))
    im.save(out, quality=90)
    return out


def round_png(src, out, size=600):
    """Circular PNG thumbnail (alpha outside the circle)."""
    im = Image.open(src).convert("RGBA").resize((size, size))
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, size - 1, size - 1), fill=255)
    im.putalpha(m)
    im.save(out)
    return out


def to_png(src, out, width=1200):
    """Any logo → PNG. SVG goes through resvg-py (python-pptx cannot embed SVG)."""
    if src.lower().endswith(".svg"):
        import resvg_py  # pip install resvg-py

        png = resvg_py.svg_to_bytes(svg_path=src, width=width)
        with open(out, "wb") as f:
            f.write(bytes(png))
    else:
        Image.open(src).convert("RGBA").save(out)
    return out


def whiten(src, out):
    """Same silhouette, solid white — the logo for dark slides."""
    im = Image.open(src).convert("RGBA")
    white = Image.new("RGBA", im.size, (255, 255, 255, 255))
    white.putalpha(im.split()[3])
    white.save(out)
    return out


class Deck:
    def __init__(self, brand_path, assets_out):
        with open(brand_path) as f:
            self.brand = json.load(f)
        self.font = self.brand.get("font", "Montserrat")
        self.colors = {k: RGBColor.from_string(v.lstrip("#").upper())
                       for k, v in self.brand["colors"].items()}
        os.makedirs(assets_out, exist_ok=True)
        self.assets = assets_out
        self.logo = self.logo_white = None
        if self.brand.get("logo"):
            self.logo = to_png(self.brand["logo"], f"{assets_out}/logo.png")
            self.logo_white = whiten(self.logo, f"{assets_out}/logo-white.png")
        self.prs = Presentation()
        self.prs.slide_width, self.prs.slide_height = Inches(W), Inches(H)

    def c(self, name):
        return self.colors[name]

    def slide(self):
        return self.prs.slides.add_slide(self.prs.slide_layouts[6])  # blank

    def save(self, out):
        self.prs.save(out)
        return out

    # ── elements ───────────────────────────────────────────────
    def text(self, slide, x, y, w, h, paras, size=18, color=None, bold=False,
             align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, spacing=0.35, name=None):
        """`paras`: a string, or a list of paragraphs; each paragraph is a string or a list of
        (text, color, bold) runs — that is how one word gets the accent colour."""
        color = color or self.c("ink")
        tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
        if name:
            tb.name = name
        tf = tb.text_frame
        tf.word_wrap = True
        tf.vertical_anchor = anchor
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        for i, p in enumerate([paras] if isinstance(paras, str) else paras):
            para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            para.alignment = align
            para.space_after = Pt(size * spacing)
            para.line_spacing = 1.0
            for t, c, b in ([(p, color, bold)] if isinstance(p, str) else p):
                r = para.add_run()
                r.text = t
                r.font.name, r.font.size, r.font.bold = self.font, Pt(size), b
                r.font.color.rgb = c
        return tb

    def shape(self, slide, kind, x, y, w, h, fill, line=None, name=None):
        """`fill` None = no fill; `line` None = no outline, else (RGBColor, width_pt)."""
        s = slide.shapes.add_shape(kind, Inches(x), Inches(y), Inches(w), Inches(h))
        if name:
            s.name = name
        if fill is None:
            s.fill.background()
        else:
            s.fill.solid()
            s.fill.fore_color.rgb = fill
        if line is None:
            s.line.fill.background()
        else:
            s.line.color.rgb, s.line.width = line[0], Pt(line[1])
        s.shadow.inherit = False
        return s

    @staticmethod
    def alpha(s, pct):
        """Fill opacity in percent. Canva renders semi-transparent overlays lighter than
        PowerPoint does — push veils a few points darker than looks right here."""
        srgb = s.fill._xPr.find(qn("a:solidFill")).find(qn("a:srgbClr"))
        etree.SubElement(srgb, qn("a:alpha")).set("val", str(int(pct * 1000)))

    def label_in(self, s, t, size, color, bold=True):
        """Centred label inside a shape (pill, numbered dot)."""
        tf = s.text_frame
        tf.text = t
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.vertical_anchor = MSO_ANCHOR.MIDDLE
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        r = p.runs[0]
        r.font.name, r.font.size, r.font.bold, r.font.color.rgb = self.font, Pt(size), bold, color

    @staticmethod
    def line(slide, x1, y1, x2, y2, color, width, name=None):
        c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1),
                                       Inches(x2), Inches(y2))
        c.line.color.rgb, c.line.width = color, Pt(width)
        if name:
            c.name = name
        return c

    def picture(self, slide, path, x, y, w=None, h=None):
        return slide.shapes.add_picture(path, Inches(x), Inches(y),
                                        width=Inches(w) if w else None,
                                        height=Inches(h) if h else None)

    # ── the recurring frame ────────────────────────────────────
    def frame(self, slide, dark=False, logo=True, bar=True):
        """The deck's recurring chrome: optional dark background, a side colour bar, the logo top
        right. Copy the reference deck's chrome here — consistency across slides is most of what
        makes a deck read as designed."""
        if dark:
            self.shape(slide, MSO_SHAPE.RECTANGLE, 0, 0, W, H, self.c("deep"), name="Background")
        if bar:
            self.shape(slide, MSO_SHAPE.RECTANGLE, 0, 0, 1.0, H,
                       self.c("accent") if dark else self.c("primary"), name="Side bar")
        if logo and self.logo:
            self.picture(slide, self.logo_white if dark else self.logo, W - 2.35, 0.38, h=0.5)

    def kicker(self, slide, x, y, t, color=None):
        """Small all-caps line above a title."""
        return self.text(slide, x, y, 8, 0.4, t, 14, color or self.c("accent"), True, name="Kicker")

    @staticmethod
    def notes(slide, s):
        """Speaker notes. Put the slide's Canva animation plan here, prefixed
        'CANVA ANIMATIONS —', so stage 3 reads it back instead of re-deciding."""
        slide.notes_slide.notes_text_frame.text = s
