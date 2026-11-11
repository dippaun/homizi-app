#!/usr/bin/env python3
"""Write a staging dart-define file that replaces the placeholder password.

Reads STAGING_TEST_PASSWORD from the environment. Does not print that value
and does not modify config/staging.json.
"""

import json
import os
import sys
from pathlib import Path

PLACEHOLDER = "REDACTED_STAGING_PASSWORD"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: staging_build_defines.py <output.json>", file=sys.stderr)
        return 2
    secret = os.environ.get("STAGING_TEST_PASSWORD", "")
    if not secret.strip() or secret == PLACEHOLDER:
        print(
            "STAGING_TEST_PASSWORD is missing or still the placeholder. "
            "Set the GitHub Actions secret to the same value as "
            "private.staging_secrets test_password.",
            file=sys.stderr,
        )
        return 1
    data = json.loads(Path("config/staging.json").read_text())
    data["STAGING_TEST_PASSWORD"] = secret
    Path(sys.argv[1]).write_text(json.dumps(data, indent=2) + "\n")
    print("wrote staging defines without printing the password")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
