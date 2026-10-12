#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ci
xcodebuild -workspace MadeRoom.xcworkspace -scheme MadeRoom \
  -destination "${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0}" \
  -derivedDataPath build -resultBundlePath "build/ci/Tests-${CM_BUILD_ID:-$(date +%s)}.xcresult" \
  -parallel-testing-enabled NO -only-testing:MadeRoomTests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test 2>&1 | tee build/ci/tests.log
