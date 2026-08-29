#!/usr/bin/env python3
"""Report what is in ~/.aws/sso/cache/ without ever printing a secret.

The cache files hold accessToken, refreshToken and clientSecret next to the fields that are
actually useful for diagnosis. `cat`ting one leaks credentials into a transcript. This reads the
same files and can only emit the safe fields, so the rule is enforced by the tool instead of by
remembering it.

Usage:
    python3 inspect_sso_cache.py                    # every cache file
    python3 inspect_sso_cache.py --key mysession    # sha1 of a session name or start URL
"""

import argparse
import hashlib
import json
import pathlib
import sys

CACHE = pathlib.Path.home() / ".aws" / "sso" / "cache"

# Anything not on this list never leaves the file.
SAFE = ("startUrl", "region", "expiresAt", "registrationExpiresAt")


def digest(value: str) -> str:
    """The cache key: sha1 of the session name (sso-session) or start URL (legacy)."""
    return hashlib.sha1(value.encode("utf-8")).hexdigest()


def describe(path: pathlib.Path) -> dict:
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        return {"file": path.name, "error": str(exc)}

    if not isinstance(data, dict):
        return {"file": path.name, "error": "not a JSON object"}

    out = {"file": path.name}
    for field in SAFE:
        if field in data:
            out[field] = data[field]
    # Presence only — the token itself is never read out.
    out["hasRefreshToken"] = "refreshToken" in data
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--key",
        metavar="NAME_OR_URL",
        help="print the sha1 cache key for a session name or start URL and exit",
    )
    args = parser.parse_args()

    if args.key:
        print(f"{digest(args.key)}.json")
        return 0

    if not CACHE.is_dir():
        print(f"no cache directory at {CACHE}", file=sys.stderr)
        return 1

    files = sorted(CACHE.glob("*.json"))
    if not files:
        print(f"no cache files in {CACHE}")
        return 0

    for entry in (describe(f) for f in files):
        print(json.dumps(entry, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
