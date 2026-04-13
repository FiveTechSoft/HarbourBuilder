@echo off
rem ============================================================
rem  HarbourBuilder - Android GUI demo, one-click runner
rem
rem  Builds the GUI APK (hello_gui.prg), boots the emulator if
rem  needed, installs and launches the app, and opens a logcat
rem  window filtered to our tag.
rem ============================================================
setlocal enabledelayedexpansion

set "BASH=C:\Program Files\Git\bin\bash.exe"
set "ADB=C:\Android\Sdk\platform-tools\adb.exe"
set "EMULATOR=C:\Android\Sdk\emulator\emulator.exe"
set "AVD=HarbourBuilderAVD"
set "APK=C:\HarbourAndroid\apk-gui\harbour-gui.apk"
set "PKG=com.harbour.builder"
set "SCRIPT=/c/HarbourBuilder/source/backends/android/build-apk-gui.sh"

echo.
echo ============================================================
echo  [1/4] Building APK (hello_gui.prg -^> harbour-gui.apk)
echo ============================================================
"%BASH%" -lc "bash %SCRIPT%"
if errorlevel 1 (
  echo.
  echo *** BUILD FAILED -- aborting.
  pause
  exit /b 1
)
if not exist "%APK%" (
  echo.
  echo *** APK not found at %APK% -- aborting.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo  [2/4] Checking emulator
echo ============================================================
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
  echo No device connected. Booting %AVD% in a new window...
  start "Android Emulator" "%EMULATOR%" -avd %AVD%
  echo Waiting for the emulator to be ready ^(can take 30-60s^)...
  "%ADB%" wait-for-device
  rem Wait until boot is complete
  :wait_boot
  for /f "delims=" %%i in ('"%ADB%" shell getprop sys.boot_completed 2^>nul') do set BOOT=%%i
  if not "!BOOT!"=="1" (
    timeout /t 2 /nobreak >nul
    goto wait_boot
  )
  echo Emulator is ready.
) else (
  echo Emulator already running.
)

echo.
echo ============================================================
echo  [3/4] Installing APK
echo ============================================================
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo *** INSTALL FAILED.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo  [4/4] Launching app + opening logcat window
echo ============================================================
"%ADB%" shell am start -n %PKG%/.MainActivity

rem Clear previous logcat and open a dedicated window tailing our tag.
"%ADB%" logcat -c
start "HarbourBuilder logcat" cmd /k ""%ADB%" logcat -s HbAndroid:* AndroidRuntime:* *:E"

echo.
echo Done. Check the emulator window for the app, and the
echo "HarbourBuilder logcat" window for live log output.
echo.
pause
endlocal
