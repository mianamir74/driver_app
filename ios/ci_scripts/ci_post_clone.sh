#!/bin/sh
# Xcode Cloud — runs right after the repo is cloned.
# Installs Flutter, fetches packages, installs CocoaPods.
set -e

echo "=== Installing Flutter (stable) ==="
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter precache --ios

echo "=== flutter pub get ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "=== pod install ==="
cd ios
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
pod install

echo "=== ci_post_clone.sh done ==="
exit 0
