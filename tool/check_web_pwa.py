#!/usr/bin/env python3
"""Check a Flutter web build for installability and the update prompt.

Usage: python3 tool/check_web_pwa.py [build/web]
"""

import json
import struct
import sys
from pathlib import Path


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} is not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    if not root.is_dir():
        raise SystemExit(f"missing web build: {root}")

    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    for key in ("name", "short_name", "start_url", "display", "icons"):
        if key not in manifest:
            raise SystemExit(f"manifest missing {key}")
    if manifest["display"] not in ("standalone", "fullscreen", "minimal-ui"):
        raise SystemExit(f"display {manifest['display']!r} is not installable")
    if manifest["name"] != "HOMIZI":
        raise SystemExit("manifest name is not HOMIZI")

    sizes = {}
    for icon in manifest["icons"]:
        src = icon["src"]
        path = root / src
        if not path.is_file():
            raise SystemExit(f"missing icon {src}")
        width, height = png_size(path)
        declared = icon.get("sizes", "")
        if declared and declared != f"{width}x{height}":
            raise SystemExit(f"{src} is {width}x{height}, manifest says {declared}")
        sizes.setdefault(icon.get("purpose", "any"), set()).add((width, height))

    any_icons = sizes.get("any", set())
    if (192, 192) not in any_icons or (512, 512) not in any_icons:
        raise SystemExit(f"need 192 and 512 purpose=any icons, found {any_icons}")

    index = (root / "index.html").read_text()
    if 'id="homizi-update"' not in index:
        raise SystemExit("index.html has no update prompt")
    if "A new version of HOMIZI is available." not in index:
        raise SystemExit("update prompt copy is missing")

    worker = root / "flutter_service_worker.js"
    if not worker.is_file():
        raise SystemExit("flutter_service_worker.js was not generated")
    script = worker.read_text()
    if 'addEventListener("fetch"' not in script and "addEventListener('fetch'" not in script:
        raise SystemExit("service worker has no fetch listener")

    print(f"PWA check passed for {root}")


if __name__ == "__main__":
    main()
