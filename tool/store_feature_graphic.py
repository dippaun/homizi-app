#!/usr/bin/env python3
"""1024x500 Play feature graphic from the HOMIZI icon and brand type."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "web" / "icons" / "Icon-512.png"
FONT = ROOT / "assets" / "fonts" / "PlusJakartaSans-Bold.ttf"
MEDIUM = ROOT / "assets" / "fonts" / "PlusJakartaSans-Medium.ttf"
OUT = ROOT / "docs" / "store" / "graphics" / "feature-graphic.png"

ORANGE = (247, 86, 32)
INK = (20, 20, 20)
WHITE = (255, 255, 255)


def main() -> None:
    canvas = Image.new("RGB", (1024, 500), ORANGE)
    icon = Image.open(ICON).convert("RGBA").resize((280, 280), Image.Resampling.LANCZOS)
    canvas.paste(icon, (96, 110), icon)
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.truetype(str(FONT), 92)
    subtitle = ImageFont.truetype(str(MEDIUM), 32)
    draw.text((440, 170), "HOMIZI", font=title, fill=INK)
    draw.text((440, 280), "Homes and flatmates.", font=subtitle, fill=INK)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT, "PNG")
    print(OUT)


if __name__ == "__main__":
    main()
