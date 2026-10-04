#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_sdk="${CONNECT_SDK:-$(xcrun --show-sdk-path)}"
mkdir -p .build/local
swiftc -sdk "$task_sdk" -target arm64-apple-macosx14.0 -O \
  -parse-as-library -emit-library -emit-module -enable-testing -module-name ConnectCore \
  Sources/ConnectCore/*.swift -emit-module-path .build/local/ConnectCore.swiftmodule \
  -o .build/local/libConnectCore.dylib
swiftc -sdk "$task_sdk" -target arm64-apple-macosx14.0 -O \
  -I .build/local -L .build/local -lConnectCore -Xlinker -rpath -Xlinker "$(pwd)/.build/local" \
  scripts/core-smoke.swift -o .build/local/core-smoke
.build/local/core-smoke
swiftc -sdk "$task_sdk" -target arm64-apple-macosx14.0 \
  -parse-as-library -emit-library -emit-module -module-name ConnectUI \
  -I .build/local -L .build/local -lConnectCore Sources/ConnectUI/*.swift \
  -emit-module-path .build/local/ConnectUI.swiftmodule -o .build/local/libConnectUI.dylib
swiftc -sdk "$task_sdk" -target arm64-apple-macosx14.0 -parse-as-library \
  -I .build/local -L .build/local -lConnectCore -lConnectUI \
  -Xlinker -rpath -Xlinker "$(pwd)/.build/local" \
  Sources/ConnectPreview/main.swift -o .build/local/connect-preview
.build/local/connect-preview docs/images
cp docs/images/app-icon.png App/Assets.xcassets/AppIcon.appiconset/AppIcon.png
