#!/usr/bin/env bash
# build-ios-app.sh - Build an iOS .app from the iOS UIKit backend.
#
# Compiles ios_core.m + the user's PRG, links with Harbour iOS libs,
# and produces a signed .app bundle ready for the simulator or device.
#
# Usage:
#   build-ios-app.sh <project_prg> [device|simulator]
#     project_prg : path to a .prg whose Main() calls UI_FormNew etc.
#     target      : device (default) or simulator

set -eu

# ---------- paths ----------
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"   # source/backends/ios/
PRG_SRC="${1:-$SCRIPT_DIR/hello_ios.prg}"
TARGET="${2:-device}"

WORK=/tmp/HarbouriOS/app-build
HB_SRC=/Users/usuario/harbour-ios-src
HB_LIB=$HB_SRC/lib/darwin/clang-ios-arm64   # default, overridden below
HB_INC=$HB_SRC/include
HOST_HB=/Users/usuario/harbour/bin/harbour

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
CLANG=$(xcrun --sdk iphoneos --find clang)

APP_NAME=HarbourApp
BUNDLE_ID=com.harbour.builder.app
TEAM_ID=${TEAM_ID:-""}

# ---------- target config ----------
case "$TARGET" in
  device)
    ARCH=arm64
    MIN_IOS=14.0
    CLANG_TARGET=arm64-apple-ios14.0
    SDK=iphoneos
    HB_LIB=$HB_SRC/lib/darwin/clang-ios-arm64
    ;;
  simulator)
    ARCH=x86_64
    MIN_IOS=14.0
    CLANG_TARGET=x86_64-apple-ios14.0-simulator
    SDK=iphonesimulator
    SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
    HB_LIB=$HB_SRC/lib/darwin/clang-ios-sim-x86_64
    ;;
  *)
    echo "Unknown target: $TARGET (use 'device' or 'simulator')"
    exit 1
    ;;
esac

echo "=============================================="
echo " Harbour iOS Build"
echo "=============================================="
echo " Target    : $TARGET ($ARCH)"
echo " SDK       : $SDK_PATH"
echo " PRG       : $PRG_SRC"
echo "=============================================="

# ---------- stage build dir ----------
echo ">>> staging $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"/{obj,app}

cp "$SCRIPT_DIR/ios_core.m" "$WORK/obj/"
cp "$PRG_SRC"                "$WORK/obj/hello.prg"

# ---------- 1. PRG -> C ----------
echo ">>> [1/4] harbour hello.prg"
cd "$WORK/obj"
"$HOST_HB" hello.prg -n -q -I"$HB_INC" -o"$WORK/obj/"
ls "$WORK/obj/hello.c"

# ---------- 2. cross-compile ----------
echo ">>> [2/4] cross-compile C sources"
CFLAGS="-target $CLANG_TARGET -isysroot $SDK_PATH -fPIC -O2 -Wall -I$HB_INC -fobjc-arc"
xcrun --sdk $SDK clang $CFLAGS -c "$WORK/obj/hello.c"     -o "$WORK/obj/hello.o"
xcrun --sdk $SDK clang $CFLAGS -c "$WORK/obj/ios_core.m"  -o "$WORK/obj/ios_core.o"

# ---------- 3. link ----------
echo ">>> [3/4] link $APP_NAME"
xcrun --sdk $SDK clang \
  -target $CLANG_TARGET \
  -isysroot "$SDK_PATH" \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  -framework QuartzCore \
  -o "$WORK/obj/$APP_NAME" \
  "$WORK/obj/ios_core.o" \
  -Wl,-force_load,"$WORK/obj/hello.o" \
  -L"$HB_LIB" \
  -lhbvm \
  -Wl,-force_load,"$HB_LIB/libhbrtl.a" \
  -lhbrdd -lhbmacro -lhbpp -lhbcommon \
  -lhblang -lhbcpage -lhbcplr -lhbnulrdd \
  -lhbdebug -lhbextern -lhbsix -lhbhsx \
  -lhbuddall -lhbusrrdd \
  -lrddntx -lrddcdx -lrddfpt -lrddnsx \
  -lgtstd -lgttrm -lgtcgi -lgtpca \
  -lhbpcre -lhbzlib -lhbnortl \
  -lm -lpthread -ldl

ls -lh "$WORK/obj/$APP_NAME"

# ---------- 4. create .app bundle ----------
echo ">>> [4/4] create .app bundle"
APP_DIR="$WORK/$APP_NAME.app"
mkdir -p "$APP_DIR"

cp "$WORK/obj/$APP_NAME" "$APP_DIR/$APP_NAME"

# Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>HarbourApp</string>
    <key>CFBundleIdentifier</key>
PLIST
echo "    <string>$BUNDLE_ID</string>" >> "$APP_DIR/Info.plist"
cat >> "$APP_DIR/Info.plist" << 'PLIST'
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>HarbourApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>MinimumOSVersion</key>
PLIST
echo "    <string>$MIN_IOS</string>" >> "$APP_DIR/Info.plist"
echo "</dict>" >> "$APP_DIR/Info.plist"
echo "</plist>" >> "$APP_DIR/Info.plist"

# LaunchScreen.storyboard (minimal)
mkdir -p "$APP_DIR/Base.lproj"
cat > "$APP_DIR/Base.lproj/LaunchScreen.storyboard" << 'SB'
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0">
  <scenes>
    <scene sceneID="EHf-IW-A2E">
      <objects>
        <viewController id="01J-lp-oVM" sceneMemberID="viewController">
          <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
            <rect key="frame" x="0.0" y="0.0" width="375" height="667"/>
            <color key="backgroundColor" white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
          </view>
        </viewController>
        <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-A1G" userLabel="First Responder" sceneMemberID="firstResponder"/>
      </objects>
      <point key="canvasLocation" x="53" y="375"/>
    </scene>
  </scenes>
</document>
SB

# Sign with ad-hoc identity (for local testing)
codesign --force --sign - "$APP_DIR/$APP_NAME"
codesign --force --sign - "$APP_DIR"

echo "=============================================="
echo " .app ready: $APP_DIR"
ls -lh "$APP_DIR/$APP_NAME"
echo "=============================================="
echo ""
echo "To install on simulator:"
echo "  xcrun simctl boot 'iPhone 16' 2>/dev/null || true"
echo "  xcrun simctl install booted '$APP_DIR'"
echo "  xcrun simctl launch booted $BUNDLE_ID"
echo ""
echo "To install on device:"
echo "  Open the .app in Xcode, select your device, and run."
