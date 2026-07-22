#!/usr/bin/env python3
"""Build a tightly-cropped, centered, square app-icon source from the logo.

The raw source (assests/kidszee_icon_square.png) is a 1024x1024 square, but the
"KidsZee" logo is a ~2:1 landscape lockup sitting in the middle with large empty
white margins above/below (it fills only ~76% width / ~38% height). That makes
the generated launcher icon look tiny and "far away".

This script trims the flat white margins, scales the artwork to fill the icon
inside a small safe-zone margin, and re-centers it on a clean white square so
the logo reads large and clear at launcher size — without stretching (aspect
ratio is preserved, so a 2:1 lockup fills the width and centers vertically).

Run from the project root:
    python3 tool/make_app_icon.py
    dart run flutter_launcher_icons
"""
from PIL import Image, ImageChops

SRC = "assests/kidszee_icon_square.png"
OUT = "assests/app_icon.png"
CANVAS = 1024              # square icon source size
PAD_RATIO = 0.04          # safe-zone margin around the artwork (per side)
THRESHOLD = 12            # ignore near-white anti-aliasing when trimming
BG = (255, 255, 255)      # white icon background


def autocrop(im: Image.Image) -> Image.Image:
    """Crop away the uniform (near-white) border around the artwork."""
    im = im.convert("RGB")
    bg = Image.new("RGB", im.size, im.getpixel((0, 0)))
    diff = ImageChops.difference(im, bg).convert("L").point(
        lambda p: 255 if p > THRESHOLD else 0)
    bbox = diff.getbbox()
    return im.crop(bbox) if bbox else im


def main() -> None:
    logo = autocrop(Image.open(SRC))

    inner = int(CANVAS * (1 - 2 * PAD_RATIO))
    scale = min(inner / logo.width, inner / logo.height)  # preserve aspect
    new = (max(1, round(logo.width * scale)), max(1, round(logo.height * scale)))
    logo = logo.resize(new, Image.LANCZOS)

    canvas = Image.new("RGB", (CANVAS, CANVAS), BG)
    x = (CANVAS - logo.width) // 2
    y = (CANVAS - logo.height) // 2
    canvas.paste(logo, (x, y))
    canvas.save(OUT)
    print(f"Wrote {OUT} ({CANVAS}x{CANVAS}); artwork {new} "
          f"(fills W {100 * new[0] / CANVAS:.0f}% / H {100 * new[1] / CANVAS:.0f}%), centered.")


if __name__ == "__main__":
    main()
