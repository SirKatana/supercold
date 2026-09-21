#!/usr/bin/env python3
"""Draws ui/splash.png, the boot splash: SUPER in black, COLD in pink, on the game's white.
Run again after changing it: python3 tools/make_splash.py"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
W, H = 1280, 720
BG, INK, PINK = (240, 243, 248), (16, 16, 20), (255, 45, 149)
img = Image.new("RGB", (W, H), BG)
# A cold vignette, like the slow-motion shader in the game.
edge = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(edge)
d.ellipse((-W * 0.25, -H * 0.35, W * 1.25, H * 1.35), fill=255)
edge = edge.filter(ImageFilter.GaussianBlur(140))
img = Image.composite(img, Image.new("RGB", (W, H), (176, 196, 226)), edge)
d = ImageDraw.Draw(img)
big = ImageFont.truetype(FONT, 190)
small = ImageFont.truetype(FONT, 30)
def centred(text, y, font, fill, spacing=0):
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = (W - total) / 2
    for c, w in zip(text, widths):
        d.text((x, y), c, font=font, fill=fill)
        x += w + spacing
centred("SUPER", 120, big, INK, 10)
# COLD leaves a pink trail, like a bullet.
glow = Image.new("RGB", (W, H), BG)
ImageDraw.Draw(glow)
trail = Image.new("L", (W, H), 0)
td = ImageDraw.Draw(trail)
widths = [td.textlength(c, font=big) for c in "COLD"]
x = (W - (sum(widths) + 30)) / 2
for c, w in zip("COLD", widths):
    td.text((x, 330), c, font=big, fill=120)
    x += w + 10
trail = trail.filter(ImageFilter.GaussianBlur(18))
img = Image.composite(Image.new("RGB", (W, H), PINK), img, trail)
d = ImageDraw.Draw(img)
centred("COLD", 330, big, PINK, 10)
centred("TIME CRAWLS WHEN YOU STAND STILL", 600, small, INK, 3)
# The bullet that is always on its way.
d.rounded_rectangle((120, 300, 200, 312), 6, fill=INK)
d.polygon([(200, 300), (222, 306), (200, 312)], fill=INK)
d.rectangle((0, 304, 120, 308), fill=PINK)
img.save("ui/splash.png")
print("ui/splash.png")
