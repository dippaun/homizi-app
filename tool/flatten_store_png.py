#!/usr/bin/env python3
"""Flatten store PNGs onto white and reject sizes Play will not accept."""

import struct
import sys
from pathlib import Path


def read_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} is not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    return width, height, data


def flatten(path: Path) -> None:
    try:
        from PIL import Image
    except ImportError as error:
        raise SystemExit("pillow is required: pip install pillow") from error

    image = Image.open(path).convert("RGBA")
    flat = Image.new("RGB", image.size, (255, 255, 255))
    flat.paste(image, mask=image.getchannel("A"))
    width, height = flat.size
    long_side = max(width, height)
    short_side = min(width, height)
    if short_side < 320 or long_side > 3840 or long_side > short_side * 2:
        raise SystemExit(f"{path} is {width}x{height}, outside Play phone limits")
    flat.save(path, "PNG")
    print(f"{path.name} {width}x{height}")


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/store/graphics")
    pngs = sorted(root.glob("*.png"))
    if not pngs:
        raise SystemExit(f"no png files in {root}")
    for path in pngs:
        if path.name == "feature-graphic.png":
            width, height, _ = read_png(path)
            if (width, height) != (1024, 500):
                raise SystemExit(f"feature graphic is {width}x{height}, want 1024x500")
            flatten_feature(path)
            continue
        flatten(path)


def flatten_feature(path: Path) -> None:
    from PIL import Image

    image = Image.open(path).convert("RGBA")
    flat = Image.new("RGB", image.size, (247, 86, 32))
    flat.paste(image, mask=image.getchannel("A"))
    flat.save(path, "PNG")
    print(f"{path.name} 1024x500")


if __name__ == "__main__":
    main()
