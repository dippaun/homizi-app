#!/usr/bin/env python3
"""Replace Flutter 3.44's unregister-only service worker with HOMIZI's.

Flutter's generated flutter_service_worker.js unregisters itself and has no
fetch handler, so Chrome will not offer to install the PWA. The loader still
registers that file name. This copies web/homizi_sw.js over it.
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    web = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "build" / "web")
    source = ROOT / "web" / "homizi_sw.js"
    target = web / "flutter_service_worker.js"
    if not source.is_file():
        raise SystemExit(f"missing {source}")
    if not web.is_dir():
        raise SystemExit(f"missing web build {web}")
    shutil.copyfile(source, target)
    print(f"Installed {source.name} as {target}")


if __name__ == "__main__":
    main()
