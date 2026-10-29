#!/usr/bin/env python3
"""Copy the built app shell to 404.html so GitHub Pages serves the Flutter app.

Path URLs such as /privacy have no file. Pages returns 404.html. That file is
the same shell as index.html, and the shell rewrites the path to a hash URL.
"""

import pathlib
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
index = root / "index.html"
if not index.is_file():
    raise SystemExit(f"missing {index}")
text = index.read_text(encoding="utf-8")
if "delete-account" not in text or "#/" not in text:
    raise SystemExit("index.html is missing the legal hash rewrite")
(root / "404.html").write_text(text, encoding="utf-8")
(root / ".nojekyll").write_text("", encoding="utf-8")
print(f"wrote {root / '404.html'} and {root / '.nojekyll'}")
