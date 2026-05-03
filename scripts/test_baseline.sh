#!/usr/bin/env bash
set -euo pipefail

xcodebuild \
  -project Lociq.xcodeproj \
  -scheme Lociq \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/lociq-derived-data \
  test
