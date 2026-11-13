"""Rough HTML render of a deck_kit .pptx, for layout checks only (not a faithful renderer).

    python preview.py deck.pptx out/index.html [Font Family]

Handles what deck_kit emits: pictures, straight lines, rectangles, ovals, rounded rectangles,
right triangles, text with per-run colour/size/weight, fill alpha, rotation. Anything else renders
as its bounding box. One <div id="sN"> per slide, so a screenshot per slide is a scroll away.
"""
import base64
import html
import sys
import urllib.parse

from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE, MSO_SHAPE_TYPE
from pptx.oxml.ns import qn

src, out = sys.argv[1], sys.argv[2]
font = sys.argv[3] if len(sys.argv) > 3 else "Montserrat"
prs = Presentation(src)
E = 914400
PX = 96  # px per inch
W, H = prs.slide_width / E * PX, prs.slide_height / E * PX


def px(v):
    return v / E * PX


def fill_css(sh):
    try:
        if sh.fill.type is None or sh.fill.type == 5:  # 5 = background (no fill)
            return "transparent"
        c = str(sh.fill.fore_color.rgb)
        a = sh.fill._xPr.find(qn("a:solidFill")).find(qn("a:srgbClr")).find(qn("a:alpha"))
        op = int(a.get("val")) / 100000 if a is not None else 1
        r, g, b = int(c[:2], 16), int(c[2:4], 16), int(c[4:], 16)
        return f"rgba({r},{g},{b},{op})"
    except Exception:
        return "transparent"


gf = urllib.parse.quote_plus(font)
parts = ['<!doctype html><html><head><meta charset="utf-8">'
         f'<link href="https://fonts.googleapis.com/css2?family={gf}:wght@400;700&display=swap" rel="stylesheet">'
         f"<style>body{{margin:0;background:#888;font-family:'{font}',sans-serif}}"
         ".s{position:relative;overflow:hidden;background:#fff;margin:20px auto}"
         ".e{position:absolute;box-sizing:border-box}p{margin:0}</style></head><body>"]
for n, slide in enumerate(prs.slides, 1):
    parts.append(f'<div class="s" id="s{n}" style="width:{W}px;height:{H}px">')
    for sh in slide.shapes:
        st = f"left:{px(sh.left)}px;top:{px(sh.top)}px;width:{px(sh.width)}px;height:{px(sh.height)}px;"
        if sh.rotation:
            st += f"transform:rotate({sh.rotation}deg);"
        if sh.shape_type == MSO_SHAPE_TYPE.PICTURE:
            b = base64.b64encode(sh.image.blob).decode()
            parts.append(f'<img class="e" style="{st}" src="data:{sh.image.content_type};base64,{b}">')
            continue
        if sh.shape_type == MSO_SHAPE_TYPE.LINE or (sh.shape_type is None and hasattr(sh, "begin_x")):
            x1, y1, x2, y2 = px(sh.begin_x), px(sh.begin_y), px(sh.end_x), px(sh.end_y)
            c = str(sh.line.color.rgb)
            w = sh.line.width.pt * PX / 72
            parts.append(f'<svg class="e" style="left:0;top:0;width:{W}px;height:{H}px;overflow:visible">'
                         f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#{c}" stroke-width="{w}"/></svg>')
            continue
        css = st
        if sh.shape_type == MSO_SHAPE_TYPE.AUTO_SHAPE:
            css += f"background:{fill_css(sh)};"
            t = sh.auto_shape_type
            if t == MSO_SHAPE.OVAL:
                css += "border-radius:50%;"
            elif t == MSO_SHAPE.ROUNDED_RECTANGLE:
                css += f"border-radius:{sh.adjustments[0] * min(px(sh.width), px(sh.height))}px;"
            elif t == MSO_SHAPE.RIGHT_TRIANGLE:
                css += "clip-path:polygon(0 100%,100% 100%,0 0);"
        inner = ""
        if sh.has_text_frame and sh.text_frame.text.strip():
            tf = sh.text_frame
            va = {None: "flex-start", 1: "flex-start", 3: "center", 4: "flex-end"}.get(tf.vertical_anchor, "flex-start")
            css += f"display:flex;flex-direction:column;justify-content:{va};"
            for p in tf.paragraphs:
                al = {None: "left", 1: "left", 2: "center", 3: "right"}.get(p.alignment, "left")
                runs = ""
                for r in p.runs:
                    size = r.font.size.pt if r.font.size else 18
                    try:
                        col = str(r.font.color.rgb)
                    except AttributeError:
                        col = "000000"
                    runs += (f'<span style="font-size:{size * PX / 72}px;color:#{col};'
                             f'font-weight:{700 if r.font.bold else 400}">{html.escape(r.text)}</span>')
                sa = p.space_after.pt * PX / 72 if p.space_after is not None else 0
                inner += f'<p style="text-align:{al};line-height:1.15;margin-bottom:{sa}px">{runs}</p>'
        parts.append(f'<div class="e" style="{css}">{inner}</div>')
    parts.append("</div>")
parts.append("</body></html>")
with open(out, "w", encoding="utf-8") as f:
    f.write("".join(parts))
print("ok", out, f"{len(prs.slides)} slides")
