param(
  [switch]$Run
)

# test_framework_link.ps1 - Regression test for the user-app link pipeline.
#
# Reproduces exactly what the IDE does when compiling a user project:
#   1. main.prg + classes.prg + hix_runtime.prg + hix_template.prg -> C
#   2. cl.exe compiles the PRG-derived C, stddlgs.c and the C++ core
#      (hbbridge.cpp built WITH /DHBIDE_WITH_HIX_RUNTIME, like the IDE does
#      for user apps)
#   3. link.exe links everything
#
# Regression: hbbridge.cpp used to define HIX_SETROOT/HIX_EXECPRG/
# HIX_SERVESTATIC link shims unconditionally, duplicating the Harbour
# implementations in hix_runtime.prg (LNK2005) and it was missing the
# UI_HIX_QUERY/BODY/METHOD/PATH/IP/SETCONTENTTYPE accessors that
# hix_runtime.prg calls (LNK2001). A brand-new empty project failed to
# build. This test fails if the link step fails.

$ErrorActionPreference = "Stop"
$repo    = "C:\HarbourBuilder"
$hbBin   = "C:\harbour\bin\win\msvc64"
$hbLib   = "C:\harbour\lib\win\msvc64"
$hbInc   = "C:\harbour\include"
$buildD  = "$env:TEMP\hbtest_framework_link"

# --- Locate Visual Studio (vswhere -> VsDevCmd) ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { $vswhere = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe" }
if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found - is Visual Studio installed?" }
$vsDir = & $vswhere -latest -property installationPath
$vsDevCmd = "$vsDir\Common7\Tools\VsDevCmd.bat"
if (-not (Test-Path $vsDevCmd)) { throw "VsDevCmd.bat not found: $vsDevCmd" }

# Load VsDevCmd env vars into current PS session
$envSnap = & cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul 2>&1 && set"
foreach ($line in $envSnap) {
  if ($line -match '^([^=]+)=(.*)$') { Set-Item "env:$($matches[1])" $matches[2] }
}

# --- Fresh build dir ---
Remove-Item -Recurse -Force $buildD -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $buildD | Out-Null

# --- Minimal user project (mirrors IDE's assembled main.prg) ---
$mainPrg = @"
#include "hbbuilder.ch"
REQUEST HB_GT_GUI_DEFAULT
REQUEST DBFCDX, DBFNTX, DBFFPT
REQUEST RDDSYS

PROCEDURE Main()
   local oApp
   oApp := TApplication():New()
   oApp:Run()
return
"@
[System.IO.File]::WriteAllText("$buildD\main.prg", $mainPrg)

# Platform stubs the IDE inlines into main.prg via #pragma BEGINDUMP
$stubsC = @"
#include "hbapi.h"
#include <windows.h>
HB_FUNC( UI_MSGBOX )         { MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "App", 0x40 ); }
HB_FUNC( UI_MSGYESNO )      { hb_retl( MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "Confirm", 0x24 ) == 6 ); }
HB_FUNC( MAC_RUNTIMEERRORDIALOG ) { hb_retni( 0 ); }
HB_FUNC( MAC_APPTERMINATE )  { }
HB_FUNC( UI_SCENE3DNEW )    { hb_retnint( 0 ); }
HB_FUNC( UI_EARTHVIEWNEW )  { hb_retnint( 0 ); }
HB_FUNC( UI_MAPNEW )        { hb_retnint( 0 ); }
HB_FUNC( UI_MAPSETREGION )  { }
HB_FUNC( UI_MAPADDPIN )     { }
HB_FUNC( UI_MAPCLEARPINS )  { }
HB_FUNC( UI_MASKEDITNEW )   { hb_retnint( 0 ); }
HB_FUNC( UI_STRINGGRIDNEW ) { hb_retnint( 0 ); }
HB_FUNC( UI_GRIDSETCELL )   { }
HB_FUNC( UI_GRIDGETCELL )   { hb_retc( "" ); }
HB_FUNC( W32_ERRORDIALOG )  { MessageBoxA( GetActiveWindow(), hb_parc(1), "Error", 0x10 ); }
"@
[System.IO.File]::WriteAllText("$buildD\platform_stubs.c", $stubsC)

# Copy framework files the IDE copies into the build dir
Copy-Item "$repo/source/core/classes.prg" "$buildD/classes.prg" -Force -ErrorAction Stop
Copy-Item "$repo/source/hix_runtime.prg"  "$buildD/hix_runtime.prg" -Force -ErrorAction Stop
Copy-Item "$repo/source/hix_template.prg" "$buildD/hix_template.prg" -Force -ErrorAction Stop
Copy-Item "$repo/include/hbbuilder.ch"    "$buildD/hbbuilder.ch" -Force
Copy-Item "$repo/include/hbide.ch"        "$buildD/hbide.ch" -Force
Copy-Item "$repo/resources/stddlgs.c"     "$buildD/stddlgs.c" -Force

"[1] harbour: main.prg, classes.prg, hix_runtime.prg, hix_template.prg"
foreach ($p in @("main", "classes", "hix_runtime", "hix_template")) {
  & "$hbBin\harbour.exe" "$buildD\$p.prg" -n -w -es2 -q -I"$hbInc" -I"$repo\include" -I"$buildD" -o"$buildD\$p.c" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "harbour $p.prg failed (exit $LASTEXITCODE)" }
}

"[2] cl PRG-derived C + stddlgs.c + platform stubs"
$clFlags = @("/nologo", "/c", "/O2", "/EHsc", "/MD", "/D_CRT_SECURE_NO_WARNINGS",
             "/I$hbInc", "/I$repo\include")
$prgObjs = @()
foreach ($p in @("main", "classes", "hix_runtime", "hix_template", "stddlgs", "platform_stubs")) {
  & cl.exe @clFlags "$buildD\$p.c" "/Fo$buildD\$p.obj" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "cl $p.c failed (exit $LASTEXITCODE)" }
  $prgObjs += "$buildD\$p.obj"
}

"[3] cl C++ core (hbbridge.cpp with /DHBIDE_WITH_HIX_RUNTIME)"
$cppFlags = @("/nologo", "/c", "/O2", "/EHsc", "/MD", "/D_CRT_SECURE_NO_WARNINGS",
              "/DHBIDE_WITH_HIX_RUNTIME", "/I$hbInc", "/I$repo\include")
$cppFiles = @("tform", "hbbridge", "tcontrol", "tcontrols", "hb_db_real")
$cppObjs = @()
foreach ($f in $cppFiles) {
  & cl.exe @cppFlags "$repo\source\cpp\$f.cpp" "/Fo$buildD\$f.obj" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "cl $f.cpp failed (exit $LASTEXITCODE)" }
  $cppObjs += "$buildD\$f.obj"
}

# FWH WebView2 host (the IDE compiles it when present)
$wv2Dir = "$repo/source/backends/win32/webview2"
if (Test-Path "$wv2Dir/fwh_webview2.cpp") {
  & cl.exe @cppFlags "/I$wv2Dir" "$wv2Dir/fwh_webview2.cpp" "/Fo$buildD\fwh_webview2.obj" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "cl fwh_webview2.cpp failed (exit $LASTEXITCODE)" }
  $cppObjs += "$buildD\fwh_webview2.obj"
}

"[4] link"
$exePath = "$buildD\UserApp.exe"
$objs = $prgObjs + $cppObjs
$hbLibs = "hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib hbcplr.lib hbct.lib hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib hbcpage.lib hbpcre.lib hbzlib.lib hbdebug.lib hbsqlit3.lib sqlite3.lib gtgui.lib gtwin.lib gtwvt.lib".Split(" ")
$sysLibs = "user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib uuid.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib winspool.lib dwmapi.lib iphlpapi.lib".Split(" ")
$linkOut = & link.exe /NOLOGO "/OUT:$exePath" /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT "/LIBPATH:$hbLib" $objs $hbLibs $sysLibs 2>&1
if ($LASTEXITCODE -ne 0) {
  $linkOut | Select-Object -Last 30
  throw "link failed (exit $LASTEXITCODE) - user app build is broken"
}

$sz = (Get-Item $exePath).Length
"BUILD OK: $exePath ($([math]::Round($sz/1024)) KB)"

if ($Run) {
  $p = Start-Process -FilePath $exePath -PassThru
  Start-Sleep -Seconds 4
  if (-not $p.HasExited) {
    "RUN OK: '$($p.MainWindowTitle)' PID=$($p.Id)"
    Stop-Process -Id $p.Id -Force
  } else {
    "RUN CRASHED: exit=$($p.ExitCode)"
    exit 2
  }
}
