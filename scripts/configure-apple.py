#!/usr/bin/env python3
"""Apply a known Apple team/bundle ID locally, then regenerate the project.

No credentials, certificates, purchases, or App Store submissions are performed.
"""
import argparse
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--team", required=True, help="10-character Apple Developer team ID")
parser.add_argument("--bundle-id", default="io.github.kas5852.Connect4x4")
parser.add_argument("--dry-run", action="store_true")
args = parser.parse_args()
if not re.fullmatch(r"[A-Z0-9]{10}", args.team):
    parser.error("The team ID must be 10 uppercase letters/digits")
if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", args.bundle_id):
    parser.error("Use a reverse-DNS bundle ID with letters, digits, periods, and hyphens")

root = Path(__file__).resolve().parent.parent
spec = root / "project.yml"
text = spec.read_text()
text, count = re.subn(r'(?m)^(\s*DEVELOPMENT_TEAM:)\s*[^\n]*$',
                     lambda match: match[1] + ' "' + args.team + '"', text)
if count != 1:
    raise SystemExit("Expected exactly one DEVELOPMENT_TEAM setting; inspect project.yml")
bundles = iter([args.bundle_id, args.bundle_id + ".UITests"])
text, count = re.subn(r"(?m)^(\s*PRODUCT_BUNDLE_IDENTIFIER:)\s*[^\n]*$",
                     lambda match: match[1] + " " + next(bundles), text)
if count != 2:
    raise SystemExit("Expected app and UI-test bundle identifiers; inspect project.yml")
print("Team:", args.team)
print("App bundle ID:", args.bundle_id)
print("App Store name: Connect 4x4; primary language: English (US); SKU: connect4x4-ios-2026")
if args.dry_run:
    print("Dry run: no files or Apple account resources were changed")
else:
    spec.write_text(text)
    subprocess.run(["xcodegen", "generate"], cwd=root, check=True)
    print("Local signing configuration prepared. Registration still requires an active Apple account.")
