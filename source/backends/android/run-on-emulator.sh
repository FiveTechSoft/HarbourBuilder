#!/usr/bin/env bash
# Launch emulator, install Harbour demo APK, run it, capture logs
set -eu

SDK=/c/Android/Sdk
AVD_NAME=HarbourBuilderAVD
APK=/c/HarbourAndroid/apk-demo/build/harbour-demo.apk
PKG=com.harbour.demo
ACTIVITY=.MainActivity

ADB=$SDK/platform-tools/adb.exe
EMULATOR=$SDK/emulator/emulator.exe

export ANDROID_HOME=$SDK
export ANDROID_SDK_ROOT=$SDK

# ---- 1. start emulator if none running ----
if ! "$ADB" devices | grep -q "emulator-"; then
  echo ">>> Starting emulator $AVD_NAME..."
  "$EMULATOR" -avd "$AVD_NAME" -no-snapshot-save -gpu auto -no-boot-anim >/tmp/emulator.log 2>&1 &
  EMU_PID=$!
  echo "    PID=$EMU_PID   log=/tmp/emulator.log"
fi

echo ">>> Waiting for device..."
"$ADB" wait-for-device

echo ">>> Waiting for boot complete..."
for i in $(seq 1 120); do
  BOOTED=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
  [ "$BOOTED" = "1" ] && break
  sleep 2
done
[ "$BOOTED" = "1" ] || { echo "Boot timeout"; exit 1; }
echo "    booted."

# ---- 2. install APK ----
echo ">>> adb install -r $APK"
"$ADB" install -r "$APK"

# ---- 3. clear logcat, launch, tail logs ----
"$ADB" logcat -c
echo ">>> Launching $PKG/$ACTIVITY"
"$ADB" shell am start -n "$PKG/$ACTIVITY"

echo ">>> Logcat (Ctrl-C to stop):"
"$ADB" logcat -v brief AndroidRuntime:E HarbourDemo:V "*:S"
