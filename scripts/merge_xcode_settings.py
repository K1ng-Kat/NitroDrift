#!/usr/bin/env python3
"""Conservatively merge personal signing values when Xcode pbxproj hunks overlap."""
import pathlib
import re
import sys

KEYS = (
    "DEVELOPMENT_TEAM", "PRODUCT_BUNDLE_IDENTIFIER", "CODE_SIGN_STYLE",
    "CODE_SIGN_IDENTITY", "PROVISIONING_PROFILE",
    "PROVISIONING_PROFILE_SPECIFIER", "CODE_SIGN_ENTITLEMENTS",
    "CODE_SIGNING_REQUIRED", "CODE_SIGNING_ALLOWED",
)
SETTING = re.compile(
    r"^(?P<indent>[^\S\r\n]*)(?P<key>" + "|".join(KEYS)
    + r")(?P<eq>\s*=\s*)(?P<value>[^;\n]*)(?P<tail>;[^\S\r\n]*)$",
    re.MULTILINE,
)

def settings(text):
    found = {}
    for match in SETTING.finditer(text):
        found.setdefault(match["key"], []).append(match)
    return found

def merge(base, local, incoming):
    scrub = lambda text: SETTING.sub(
        lambda m: m["indent"] + m["key"] + m["eq"] + "<SIGNING>" + m["tail"], text
    )
    if scrub(base) != scrub(local):
        raise ValueError("local project edits exceed known personal signing settings")
    before, edited, remote = settings(base), settings(local), settings(incoming)
    replacements = []
    for key in KEYS:
        old, new, current = (
            before.get(key, []), edited.get(key, []), remote.get(key, [])
        )
        if len(old) != len(new) or len(old) != len(current):
            if len(old) != len(new) or any(
                x["value"] != y["value"] for x, y in zip(old, new)
            ):
                raise ValueError("GitHub altered signing setting count: " + key)
            continue
        for index, (original, user, upstream) in enumerate(zip(old, new, current)):
            if user["value"] == original["value"]:
                continue
            if upstream["value"] not in (original["value"], user["value"]):
                raise ValueError("Both local and remote changed " + key + " #" + str(index + 1))
            replacements.append(
                (upstream.start("value"), upstream.end("value"), user["value"])
            )
    for start, end, value in sorted(replacements, reverse=True):
        incoming = incoming[:start] + value + incoming[end:]
    return incoming

def main():
    if len(sys.argv) != 5:
        raise SystemExit("Usage: merge_xcode_settings.py BASE LOCAL UPDATED OUTPUT")
    paths = [pathlib.Path(p) for p in sys.argv[1:]]
    try:
        base, local, incoming = [p.read_text(encoding="utf-8") for p in paths[:3]]
        paths[3].write_text(merge(base, local, incoming), encoding="utf-8")
    except ValueError as error:
        print("Cannot safely merge project settings:", error, file=sys.stderr)
        raise SystemExit(1)

if __name__ == "__main__":
    main()
