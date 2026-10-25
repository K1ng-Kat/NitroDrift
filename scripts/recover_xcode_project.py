#!/usr/bin/env python3
"""Recover safe local Xcode signing settings after nd-sync updated project.pbxproj.

Usage: python3 scripts/recover_xcode_project.py ~/Documents/.nd-sync-backups/recovery.NAME

This never overwrites a currently modified or staged project file, never drops
the original backup, and only reapplies personal signing keys that do not
conflict with new GitHub values. Structural/other local edits remain in backup.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

from merge_xcode_settings import merge, SETTING

PROJECT_PATH = pathlib.Path("NitroDrift.xcodeproj/project.pbxproj")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/recover_xcode_project.py BACKUP_FOLDER")
    backup = pathlib.Path(sys.argv[1]).expanduser().resolve()
    original = backup / "local" / PROJECT_PATH
    base = backup / "base" / PROJECT_PATH
    current = pathlib.Path.cwd() / PROJECT_PATH
    if not (original.is_file() and base.is_file() and current.is_file()):
        raise SystemExit("Missing original/base/current .pbxproj; no files were modified.")
    if subprocess.run(["git", "diff", "--quiet", "--", str(PROJECT_PATH)]).returncode != 0:
        raise SystemExit("Current project has uncommitted edits; refusing to overwrite them.")
    if subprocess.run(["git", "diff", "--cached", "--quiet", "--", str(PROJECT_PATH)]).returncode != 0:
        raise SystemExit("Current project has staged edits; refusing to overwrite them.")

    base_text = base.read_text(encoding="utf-8")
    original_text = original.read_text(encoding="utf-8")
    current_text = current.read_text(encoding="utf-8")
    try:
        recovered = merge(base_text, original_text, current_text)
    except ValueError as exc:
        raise SystemExit(f"Cannot safely restore settings: {exc}; original backup retained.")

    def scrub(text):
        return SETTING.sub(lambda m: m["indent"] + m["key"] + m["eq"] + "<SIGNING>" + m["tail"], text)

    extras = scrub(base_text) != scrub(original_text)
    # Ensure any full output is valid Xcode syntax BEFORE touching project.
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".pbxproj",
                                     dir=current.parent, delete=False) as output:
        temp = pathlib.Path(output.name)
        output.write(recovered)
    try:
        result = subprocess.run(["plutil", "-lint", str(temp)],
                                capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError("Xcode project validation failed: " + result.stdout + result.stderr)
        if recovered != current_text:
            shutil.copymode(current, temp)
            temp.replace(current)
            print("✅ Personal Xcode signing preferences restored onto updated GitHub project.")
        else:
            print("✅ Updated GitHub project already contains the recoverable signing preferences.")
    except Exception as error:
        raise SystemExit(str(error))
    finally:
        temp.unlink(missing_ok=True)

    if extras:
        print("⚠️ Other original Xcode project edits could NOT be safely auto-merged.")
        print("🛡️ Original complete settings remain at:", original)
        print("   Review this backup if Xcode reports missing resources or configurations.")
    else:
        print("✅ All detectable local signing differences were handled; original backup retained.")
    print("📂 Project:", current)


if __name__ == "__main__":
    main()
