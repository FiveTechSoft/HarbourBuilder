#!/usr/bin/env bash
# install-and-run.sh
#
# Runs after build-apk-gui.sh produced /c/HarbourAndroid/apk-gui/harbour-gui.apk
# Responsibilities:
#   1. Ensure an emulator is booted (start HarbourBuilderAVD if nothing connected).
#   2. Wait for it to be fully ready (sys.boot_completed == 1).
#   3. Install the APK.
#   4. Launch com.harbour.builder/.MainActivity.
#   5. Tail logcat filtered to our tag so the user sees live output.
#
# This runs in its own shell window; the IDE just spawns it and moves on.

set -u

ADB=/c/Android/Sdk/platform-tools/adb.exe
EMULATOR=/c/Android/Sdk/emulator/emulator.exe
AVD=HarbourBuilderAVD
APK=/c/HarbourAndroid/apk-gui/harbour-gui.apk
PKG=com.harbour.builder

if [ ! -f "$APK" ]; then
  echo "APK not found at $APK - did the build fail?"
  read -p "Press enter to close..." dummy
  exit 1
fi

echo "[install-and-run] adb start-server"
"$ADB" start-server >/dev/null 2>&1 || true

echo "[install-and-run] checking for running device..."
STATE=$("$ADB" get-state 2>/dev/null || true)
if [ "$STATE" != "device" ]; then
  echo "[install-and-run] no device - launching AVD $AVD ..."
  ( "$EMULATOR" -avd "$AVD" -no-snapshot-save & ) >/dev/null 2>&1

  echo "[install-and-run] waiting for device to appear..."
  "$ADB" wait-for-device
fi

echo "[install-and-run] waiting for boot to complete..."
until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')" = "1" ]; do
  sleep 2
  printf '.'
done
echo
echo "[install-and-run] device is ready."

echo "[install-and-run] installing $APK ..."
"$ADB" install -r "$APK"

echo "[install-and-run] launching $PKG/.MainActivity ..."
"$ADB" shell am start -n "$PKG/.MainActivity"

echo
echo "[install-and-run] live logcat (Ctrl+C to stop):"
echo "========================================"
"$ADB" logcat -c
"$ADB" logcat -s HbAndroid:* AndroidRuntime:*E *:E
