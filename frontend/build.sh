#!/bin/bash
set -euo pipefail

# NUS Motion — Build Script
# Usage:
#   ./build.sh android    Build Android App Bundle (AAB)
#   ./build.sh ios        Build iOS Archive (IPA)
#   ./build.sh both       Build both platforms
#   ./build.sh icons      Generate launcher icons

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

build_android() {
    echo "==> Building Android App Bundle..."
    if [ ! -f android/key.properties ]; then
        echo "WARNING: android/key.properties not found. Using debug signing."
        echo "         Copy android/key.properties.example and fill in your keystore details."
    fi
    flutter build appbundle --release
    echo "==> AAB output: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
    echo "==> Building iOS Archive..."
    echo "    Make sure Xcode signing is configured (Team, Bundle ID, Provisioning Profile)."
    flutter build ipa --release
    echo "==> IPA output: build/ios/ipa/"
}

generate_icons() {
    echo "==> Generating launcher icons..."
    if [ ! -f assets/icon/app_icon.png ]; then
        echo "ERROR: assets/icon/app_icon.png not found."
        echo "       Place your 1024x1024 icon there first."
        exit 1
    fi
    dart run flutter_launcher_icons
    echo "==> Icons generated for both platforms."
}

case "${1:-}" in
    android) build_android ;;
    ios) build_ios ;;
    both) build_android; build_ios ;;
    icons) generate_icons ;;
    *)
        echo "NUS Motion Build Script"
        echo "Usage: $0 {android|ios|both|icons}"
        exit 1
        ;;
esac
