#!/usr/bin/env bash
set -euo pipefail

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/lociq-derived-data}"

xcodebuild \
  -project Lociq.xcodeproj \
  -scheme Lociq \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test
