"""Draws Triamail's icon (1024 px canvas, macOS grid), supersampled for crisp edges.

Run: python3 design/icone.py  →  design/icone-1024.png
"""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math

S = 4                      # supersampling
W = 1024 * S
OUT = __file__.replace("icone.py", "icone-1024.png")


def superellipse(cx, cy, half, n=5.0, steps=720):
    """Apple-like continuous-corner square (squircle)."""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        x = cx + half * math.copysign(abs(c) ** (2 / n), c)
        y = cy + half * math.copysign(abs(s) ** (2 / n), s)
        pts.append((x, y))
    return pts


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def gradient(size, c1, c2, angle_deg=45):
    """Linear gradient from top-left (c1) to bottom-right (c2)."""
    w, h = size
    small = Image.new("RGB", (256, 256))
    px = small.load()
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    for y in range(256):
        for x in range(256):
            t = ((x / 255) * dx + (y / 255) * dy) / (dx + dy)
            px[x, y] = lerp(c1, c2, max(0, min(1, t)))
    return small.resize((w, h), Image.BICUBIC)


def rounded(draw, box, r, fill):
    draw.rounded_rectangle(box, radius=r, fill=fill)


def shadow(size, shape_fn, blur, offset, opacity):
    layer = Image.new("L", size, 0)
    shape_fn(ImageDraw.Draw(layer))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    layer = ImageChops.offset(layer, *offset)
    return layer.point(lambda v: int(v * opacity))


canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
c = W / 2
half = 412 * S                                    # 824 px squircle on 1024 canvas
squircle = superellipse(c, c + 6 * S, half)

# Drop shadow under the tile
tile_shadow = shadow((W, W), lambda d: d.polygon(squircle, fill=255), 18 * S, (0, 10 * S), 0.35)
canvas.paste((0, 0, 0, 255), (0, 0), tile_shadow)

# Tile: indigo → teal, with a soft light sweep
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).polygon(squircle, fill=255)
tile = gradient((W, W), (62, 40, 176), (8, 168, 160), 50)
sweep = Image.new("L", (W, W), 0)
ImageDraw.Draw(sweep).ellipse((-0.5 * W, -1.05 * W, 0.9 * W, 0.32 * W), fill=26)
sweep = sweep.filter(ImageFilter.GaussianBlur(40 * S))
tile = Image.composite(Image.new("RGB", (W, W), (255, 255, 255)), tile, sweep)
canvas.paste(tile, (0, 0), mask)

d = ImageDraw.Draw(canvas)

# Geometry of the envelope (in px on the 1024 grid)
ex0, ex1 = 262 * S, 762 * S          # envelope left / right
ey_top, ey_bot = 470 * S, 760 * S    # envelope body
r_env = 52 * S


def card(y, color, check=False):
    x0, x1 = 300 * S, 724 * S
    h = 215 * S
    sh = shadow((W, W), lambda dd: dd.rounded_rectangle((x0, y, x1, y + h), 40 * S, fill=255), 14 * S, (0, 8 * S), 0.28)
    canvas.paste((10, 20, 60, 255), (0, 0), sh)
    dd = ImageDraw.Draw(canvas)
    dd.rounded_rectangle((x0, y, x1, y + h), radius=40 * S, fill=color)
    light = tuple(min(255, int(v + (255 - v) * 0.55)) for v in color[:3]) + (255,)
    cy = y + 62 * S
    dd.ellipse((x0 + 44 * S, cy - 26 * S, x0 + 96 * S, cy + 26 * S), fill=light)
    dd.rounded_rectangle((x0 + 122 * S, cy - 26 * S, x0 + 300 * S, cy - 6 * S), 10 * S, fill=light)
    dd.rounded_rectangle((x0 + 122 * S, cy + 8 * S, x0 + 240 * S, cy + 28 * S), 10 * S, fill=light)
    if check:
        dd.line([(x1 - 108 * S, cy + 2 * S), (x1 - 82 * S, cy + 28 * S), (x1 - 38 * S, cy - 26 * S)],
                fill=(255, 255, 255, 255), width=20 * S, joint="curve")
        for p in [(x1 - 108 * S, cy + 2 * S), (x1 - 38 * S, cy - 26 * S)]:
            dd.ellipse((p[0] - 10 * S, p[1] - 10 * S, p[0] + 10 * S, p[1] + 10 * S), fill=(255, 255, 255, 255))


# Back of the envelope (open), behind the cards
d.rounded_rectangle((ex0, ey_top - 60 * S, ex1, ey_bot), radius=r_env, fill=(214, 220, 245, 255))

card(250 * S, (240, 104, 84, 255))
card(340 * S, (98, 128, 232, 255))
card(430 * S, (26, 188, 150, 255), check=True)

# Front of the envelope: a pocket whose top edge dips in a V, so the cards sit inside it
front = Image.new("L", (W, W), 0)
fd = ImageDraw.Draw(front)
v_bottom = 640 * S
fd.polygon([(ex0, ey_top), (c, v_bottom), (ex1, ey_top), (ex1, ey_bot - r_env), (ex0, ey_bot - r_env)], fill=255)
fd.rounded_rectangle((ex0, v_bottom - 40 * S, ex1, ey_bot), radius=r_env, fill=255)
front = front.filter(ImageFilter.GaussianBlur(1.5 * S)).point(lambda v: 255 if v > 127 else 0)
front_shadow = front.filter(ImageFilter.GaussianBlur(18 * S))
front_shadow = ImageChops.offset(front_shadow, 0, -10 * S).point(lambda v: int(v * 0.30))
canvas.paste((20, 30, 80, 255), (0, 0), front_shadow)
body = gradient((W, W), (253, 254, 255), (220, 226, 248), 90)
canvas.paste(body, (0, 0), front)

# Fold lines: from the bottom corners up to the middle, like the back of a real envelope
d = ImageDraw.Draw(canvas)
fold = (198, 206, 236, 255)
d.line([(ex0 + 26 * S, ey_bot - 22 * S), (c - 16 * S, 700 * S)], fill=fold, width=7 * S)
d.line([(ex1 - 26 * S, ey_bot - 22 * S), (c + 16 * S, 700 * S)], fill=fold, width=7 * S)

canvas.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("écrit", OUT)
