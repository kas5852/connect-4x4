#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_sdk="${CONNECT_SDK:-$(xcrun --show-sdk-path)}"
task_bundle=".build/Connect4x4.app"
bash scripts/check-local.sh
mkdir -p "$task_bundle/Contents/MacOS" "$task_bundle/Contents/Frameworks" "$task_bundle/Contents/Resources"
swiftc -sdk "$task_sdk" -target arm64-apple-macosx14.0 -parse-as-library \
  -I .build/local -L .build/local -lConnectCore -lConnectUI \
  -Xlinker -rpath -Xlinker '@executable_path/../Frameworks' \
  App/Connect4x4App.swift -o "$task_bundle/Contents/MacOS/Connect4x4"
cp .build/local/libConnectCore.dylib .build/local/libConnectUI.dylib "$task_bundle/Contents/Frameworks/"
python3 - <<'PY'
import plistlib
from pathlib import Path
bundle = Path('.build/Connect4x4.app')
with (bundle / 'Contents/Info.plist').open('wb') as file:
    plistlib.dump({'CFBundleExecutable': 'Connect4x4',
                  'CFBundleIdentifier': 'io.github.kas5852.Connect4x4.MacPreview',
                  'CFBundleName': 'Connect 4x4', 'CFBundlePackageType': 'APPL',
                  'CFBundleShortVersionString': '1.0.0', 'CFBundleVersion': '1',
                  'LSMinimumSystemVersion': '14.0', 'NSHighResolutionCapable': True,
                  'NSPrincipalClass': 'NSApplication'}, file)
PY
codesign --force --sign - "$task_bundle/Contents/Frameworks/libConnectCore.dylib"
codesign --force --sign - "$task_bundle/Contents/Frameworks/libConnectUI.dylib"
codesign --force --sign - "$task_bundle"
printf 'Playable Mac preview: %s/%s\n' "$(pwd)" "$task_bundle"
