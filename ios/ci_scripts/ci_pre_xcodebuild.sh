#!/bin/sh
# Xcode Cloud — runs right before xcodebuild.
# Sets a unique build number: 500 + Xcode Cloud's build counter,
# so it never clashes with Codemagic builds (1-141 range used so far).
set -e

export PATH="$PATH:$HOME/flutter/bin"

cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
BUILD_NUM=$((500 + $CI_BUILD_NUMBER))
echo "=== Setting iOS build number to $BUILD_NUM ==="
agvtool new-version -all "$BUILD_NUM"

exit 0
