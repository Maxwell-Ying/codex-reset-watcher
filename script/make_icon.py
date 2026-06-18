#!/usr/bin/env python3
"""Generate the app icon PNG and ICNS.

This optional maintainer script needs Pillow. The generated AppIcon.icns is
checked into source so normal builds do not need Pillow.
"""

from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
ICONSET = ASSETS / "AppIcon.iconset"
PNG = ASSETS / "AppIcon.png"
ICNS = ASSETS / "AppIcon.icns"


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def vertical_gradient(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    px = image.load()
    for y in range(size):
        t = y / (size - 1)
        for x in range(size):
            u = x / (size - 1)
            r = int(88 + 58 * (1 - t) + 38 * u)
            g = int(111 + 74 * (1 - t) + 24 * math.sin(u * math.pi))
            b = int(190 + 48 * (1 - u) + 28 * t)
            px[x, y] = (r, g, min(b, 255), 255)
    return image


def glow(size: int, center: tuple[int, int], color: tuple[int, int, int], radius: int) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*color, 150))
    return layer.filter(ImageFilter.GaussianBlur(radius // 2))


def make_icon() -> Image.Image:
    size = 1024
    image = vertical_gradient(size)
    image.alpha_composite(glow(size, (700, 250), (255, 202, 58), 210))
    image.alpha_composite(glow(size, (300, 740), (67, 213, 255), 240))

    draw = ImageDraw.Draw(image)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((200, 286, 824, 780), radius=86, fill=(0, 0, 0, 155))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    image.alpha_composite(shadow)

    panel = (188, 268, 836, 754)
    draw.rounded_rectangle(panel, radius=86, fill=(31, 36, 42, 244), outline=(115, 129, 146, 120), width=3)
    draw.rounded_rectangle((244, 350, 780, 396), radius=23, fill=(67, 76, 89, 220))
    draw.rounded_rectangle((244, 424, 780, 470), radius=23, fill=(60, 69, 82, 210))

    # Highlighted reset-credit region.
    draw.rounded_rectangle((232, 512, 792, 666), radius=26, outline=(255, 224, 54, 255), width=7)
    card_specs = [
        (266, 548, 495, 628, (72, 82, 96, 240)),
        (529, 548, 758, 628, (72, 82, 96, 240)),
    ]
    for rect in card_specs:
        x1, y1, x2, y2, color = rect
        draw.rounded_rectangle((x1, y1, x2, y2), radius=28, fill=color, outline=(142, 155, 172, 100), width=2)
        draw.rounded_rectangle((x1 + 32, y1 + 25, x2 - 32, y1 + 38), radius=6, fill=(179, 188, 201, 210))
        draw.rounded_rectangle((x1 + 32, y1 + 48, x2 - 74, y1 + 61), radius=6, fill=(242, 246, 252, 235))

    # Floating command glyph.
    cloud_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cloud_draw = ImageDraw.Draw(cloud_shadow)
    cloud_draw.rounded_rectangle((381, 140, 643, 286), radius=72, fill=(0, 0, 0, 140))
    cloud_shadow = cloud_shadow.filter(ImageFilter.GaussianBlur(28))
    image.alpha_composite(cloud_shadow)

    draw.rounded_rectangle((380, 132, 644, 280), radius=74, fill=(98, 113, 255, 250))
    draw.ellipse((430, 92, 555, 217), fill=(120, 134, 255, 255))
    draw.ellipse((508, 122, 650, 270), fill=(77, 96, 241, 255))
    draw.line((474, 178, 510, 212, 474, 246), fill=(238, 247, 255, 245), width=20, joint="curve")
    draw.rounded_rectangle((542, 221, 606, 240), radius=8, fill=(238, 247, 255, 235))

    # Subtle top shine.
    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    shine_draw.rounded_rectangle((72, 52, 952, 400), radius=190, fill=(255, 255, 255, 38))
    shine = shine.filter(ImageFilter.GaussianBlur(20))
    image.alpha_composite(shine)

    mask = rounded_rect_mask(size, 205)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(image, (0, 0), mask)
    return out


def write_iconset(source: Image.Image) -> None:
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True)

    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, pixels in specs:
        source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ICONSET / name)


def main() -> int:
    ASSETS.mkdir(exist_ok=True)
    icon = make_icon()
    icon.save(PNG)
    write_iconset(icon)
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    print(PNG)
    print(ICNS)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
