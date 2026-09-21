"""Generates the Nourish app icons and social preview image.

The mark is the same leaf the sign-in screen uses, in the app's green
(#2E7D57), drawn as two arcs so it reads at 32px as well as 512px.
"""
from PIL import Image, ImageDraw, ImageFont
import os

GREEN = (46, 125, 87)
CREAM = (244, 249, 245)
OUT = "/home/user/nourish/web"

SCALE = 8  # supersample, then downscale for smooth edges


def _bezier(p0, c, p1, steps=80):
    """Points along a quadratic bezier."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        out.append((
            u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0],
            u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1],
        ))
    return out


def leaf_mask(size):
    """A leaf: two bezier curves meeting at a base and a pointed tip, with
    the midrib cut back out so the shape reads as a folded leaf."""
    s = size * SCALE
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)

    base = (s * 0.16, s * 0.84)
    tip = (s * 0.86, s * 0.14)

    # One control point either side of the midrib gives the two edges.
    upper = _bezier(base, (s * 0.20, s * 0.26), tip)
    lower = _bezier(tip, (s * 0.80, s * 0.74), base)
    d.polygon(upper + lower, fill=255)

    # Midrib, cut out so it stays visible against a solid fill.
    d.line([base, tip], fill=0, width=max(1, int(s * 0.045)))
    return img.resize((size, size), Image.LANCZOS)


def icon(size, maskable=False, transparent_bg=False):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Maskable icons get a full-bleed background; Android crops them to a
    # circle or squircle, so the mark sits inside a safe zone.
    inset = 0.28 if maskable else 0.16
    if not transparent_bg:
        bg = Image.new("RGBA", (size, size), CREAM + (255,))
        img.alpha_composite(bg)

    mark = int(size * (1 - inset * 2))
    m = leaf_mask(mark)
    tinted = Image.new("RGBA", (mark, mark), GREEN + (255,))
    tinted.putalpha(m)
    img.alpha_composite(tinted, (int(size * inset), int(size * inset)))
    return img


def favicon():
    # Favicons render at 16-32px, so the mark fills more of the frame.
    size = 64
    img = Image.new("RGBA", (size, size), GREEN + (255,))
    mark = int(size * 0.66)
    m = leaf_mask(mark)
    tinted = Image.new("RGBA", (mark, mark), CREAM + (255,))
    tinted.putalpha(m)
    img.alpha_composite(tinted, ((size - mark) // 2, (size - mark) // 2))
    return img


def social(width=1200, height=630):
    """Open Graph card, for when the link is shared."""
    img = Image.new("RGB", (width, height), CREAM)
    d = ImageDraw.Draw(img)

    mark = 190
    m = leaf_mask(mark)
    tinted = Image.new("RGBA", (mark, mark), GREEN + (255,))
    tinted.putalpha(m)
    img.paste(GREEN, (0, 0, width, 12))
    img.paste(tinted, (int(width / 2 - mark / 2), 128), tinted)

    def font(size, bold=False):
        for path in (
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
            else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        ):
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
        return ImageFont.load_default()

    def centre(text, y, f, fill):
        w = d.textbbox((0, 0), text, font=f)[2]
        d.text(((width - w) / 2, y), text, font=f, fill=fill)

    centre("Nourish", 350, font(86, bold=True), GREEN)
    centre("Tell us how you eat once.", 462, font(36), (60, 72, 64))
    centre("Then keep it honest in 20 seconds a day.", 512, font(36), (60, 72, 64))
    return img


os.makedirs(f"{OUT}/icons", exist_ok=True)
icon(192).save(f"{OUT}/icons/Icon-192.png")
icon(512).save(f"{OUT}/icons/Icon-512.png")
icon(192, maskable=True).save(f"{OUT}/icons/Icon-maskable-192.png")
icon(512, maskable=True).save(f"{OUT}/icons/Icon-maskable-512.png")
favicon().save(f"{OUT}/favicon.png")
social().save(f"{OUT}/social-preview.png", optimize=True)

for name in (
    "icons/Icon-192.png",
    "icons/Icon-512.png",
    "icons/Icon-maskable-192.png",
    "icons/Icon-maskable-512.png",
    "favicon.png",
    "social-preview.png",
):
    p = f"{OUT}/{name}"
    print(f"{os.path.getsize(p):>8,}  {name}  {Image.open(p).size}")
