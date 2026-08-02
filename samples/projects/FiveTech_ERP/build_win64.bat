@echo off
setlocal EnableDelayedExpansion
REM =====================================================================
REM  FiveTech_ERP — Windows x64 (MSVC + Harbour MT + WebView2)
REM  Output:  FiveTech_ERP.exe  in this folder
REM =====================================================================

set "PROJDIR=%~dp0"
set "PROJDIR=%PROJDIR:~0,-1%"
set "HBROOT=C:\harbourbuilder"
set "BUILDDIR=%PROJDIR%\_build_win64"
set "OUT=%PROJDIR%\FiveTech_ERP.exe"

echo.
echo === FiveTech_ERP build (Windows x64) ===
echo Project: %PROJDIR%
echo.

REM --- Harbour ---
set "HBDIR="
if exist "C:\harbour\bin\win\msvc64\harbour.exe" (
  set "HBDIR=C:\harbour"
  set "HBBIN=C:\harbour\bin\win\msvc64"
  set "HBLIB=C:\harbour\lib\win\msvc64"
  set "HBINC=C:\harbour\include"
) else if exist "C:\harbour\bin\harbour.exe" (
  set "HBDIR=C:\harbour"
  set "HBBIN=C:\harbour\bin"
  set "HBLIB=C:\harbour\lib"
  set "HBINC=C:\harbour\include"
  if exist "C:\harbour\lib\win\msvc64\hbvm.lib" set "HBLIB=C:\harbour\lib\win\msvc64"
)
if "%HBDIR%"=="" (
  echo ERROR: Harbour not found under C:\harbour
  exit /b 1
)
if not exist "%HBLIB%\hbvmmt.lib" (
  echo ERROR: hbvmmt.lib not found - need multi-thread Harbour VM for HTTP threads
  echo Looked in: %HBLIB%
  exit /b 1
)
echo Harbour: %HBDIR%
echo Libs:    %HBLIB%

REM --- VS x64 ---
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do set "VSDIR=%%i"
if not exist "%VSDIR%" (
  echo ERROR: Visual Studio not found
  exit /b 1
)
call "%VSDIR%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 (
  echo ERROR: VsDevCmd failed
  exit /b 1
)
echo VS:      %VSDIR%

if exist "%BUILDDIR%" rmdir /s /q "%BUILDDIR%"
mkdir "%BUILDDIR%"
cd /d "%BUILDDIR%"

REM --- Assemble main.prg (app + framework classes) ---
echo.
echo [1] Assemble main.prg
copy /y "%HBROOT%\source\core\classes.prg" "%BUILDDIR%\classes.prg" >nul
copy /y "%HBROOT%\include\hbbuilder.ch" "%BUILDDIR%\" >nul
copy /y "%HBROOT%\include\hbide.ch" "%BUILDDIR%\" >nul 2>nul
copy /y "%HBROOT%\include\hbide_ct.h" "%BUILDDIR%\" >nul 2>nul
copy /y "%HBROOT%\include\hbide.h" "%BUILDDIR%\" >nul 2>nul
if exist "%HBROOT%\resources\stddlgs.c" copy /y "%HBROOT%\resources\stddlgs.c" "%BUILDDIR%\" >nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJDIR%\assemble_main.ps1" -ProjDir "%PROJDIR%" -BuildDir "%BUILDDIR%"
if not exist "%BUILDDIR%\main.prg" (
  echo ERROR: failed to assemble main.prg
  exit /b 1
)

echo [2] Harbour compile main + erp_meta + erp_http + erp_db + erp_proc + classes
"%HBBIN%\harbour.exe" main.prg -n -w -q -i"%HBINC%" -i"%BUILDDIR%" -i"%HBROOT%\include" -omain.c
if errorlevel 1 (
  echo HARBOUR FAILED on main.prg
  exit /b 1
)
"%HBBIN%\harbour.exe" erp_meta.prg -n -w -q -i"%HBINC%" -i"%BUILDDIR%" -i"%HBROOT%\include" -oerp_meta.c
if errorlevel 1 (
  echo HARBOUR FAILED on erp_meta.prg
  exit /b 1
)
"%HBBIN%\harbour.exe" erp_http.prg -n -w -q -i"%HBINC%" -i"%BUILDDIR%" -i"%HBROOT%\include" -oerp_http.c
if errorlevel 1 (
  echo HARBOUR FAILED on erp_http.prg
  exit /b 1
)
copy /y "%PROJDIR%\erp_db.prg" "%BUILDDIR%\erp_db.prg" >nul
"%HBBIN%\harbour.exe" erp_db.prg -n -w -q -i"%HBINC%" -i"%BUILDDIR%" -i"%HBROOT%\include" -oerp_db.c
if errorlevel 1 (
  echo HARBOUR FAILED on erp_db.prg
  exit /b 1
)
copy /y "%PROJDIR%\erp_proc.prg" "%BUILDDIR%\erp_proc.prg" >nul
"%HBBIN%\harbour.exe" erp_proc.prg -n -w -q -i"%HBINC%" -i"%BUILDDIR%" -i"%HBROOT%\include" -oerp_proc.c
if errorlevel 1 (
  echo HARBOUR FAILED on erp_proc.prg
  exit /b 1
)
"%HBBIN%\harbour.exe" classes.prg -n -w -q -i"%HBINC%" -i"%BUILDDIR%" -i"%HBROOT%\include" -oclasses.c
if errorlevel 1 (
  echo HARBOUR FAILED on classes.prg
  exit /b 1
)

echo [3] Compile C / C++
set "CL_BASE=/nologo /c /O2 /EHsc /MD /W0 /D_CRT_SECURE_NO_WARNINGS /I%HBINC% /I%HBROOT%\include /I%BUILDDIR%"
cl.exe %CL_BASE% main.c /Fomain.obj
if errorlevel 1 exit /b 1
cl.exe %CL_BASE% erp_meta.c /Foerp_meta.obj
if errorlevel 1 exit /b 1
cl.exe %CL_BASE% erp_http.c /Foerp_http.obj
if errorlevel 1 exit /b 1
cl.exe %CL_BASE% erp_db.c /Foerp_db.obj
if errorlevel 1 exit /b 1
cl.exe %CL_BASE% erp_proc.c /Foerp_proc.obj
if errorlevel 1 exit /b 1
cl.exe %CL_BASE% classes.c /Foclasses.obj
if errorlevel 1 exit /b 1
if exist stddlgs.c (
  cl.exe %CL_BASE% stddlgs.c /Fostddlgs.obj
)
REM FWH-style error dialog: multi-line + Copy to Clipboard
copy /y "%PROJDIR%\fte_errdlg.c" "%BUILDDIR%\fte_errdlg.c" >nul
cl.exe %CL_BASE% fte_errdlg.c /Fofte_errdlg.obj
if errorlevel 1 (
  echo CL FAILED on fte_errdlg.c
  exit /b 1
)

set "CPPDIR=%HBROOT%\source\cpp"
for %%f in (tcontrol tform tcontrols hbbridge hb_db_real) do (
  cl.exe %CL_BASE% "%CPPDIR%\%%f.cpp" /Fo%%f.obj
  if errorlevel 1 (
    echo CL FAILED on %%f.cpp
    exit /b 1
  )
)

set "WV2=%HBROOT%\source\backends\win32\webview2"
if not exist "%WV2%\fwh_webview2.cpp" (
  echo ERROR: WebView2 host missing: %WV2%\fwh_webview2.cpp
  exit /b 1
)
cl.exe %CL_BASE% /I"%WV2%" "%WV2%\fwh_webview2.cpp" /Fofwh_webview2.obj
if errorlevel 1 (
  echo CL FAILED on fwh_webview2.cpp
  exit /b 1
)

echo [4] Link FiveTech_ERP.exe  (hbvmmt)
set "OBJS=main.obj erp_meta.obj erp_http.obj erp_db.obj erp_proc.obj classes.obj tcontrol.obj tform.obj tcontrols.obj hbbridge.obj hb_db_real.obj fwh_webview2.obj fte_errdlg.obj"
if exist stddlgs.obj set "OBJS=%OBJS% stddlgs.obj"

set "HBLIBS=hbvmmt.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib hbcplr.lib hbct.lib hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib hbcpage.lib hbpcre.lib hbzlib.lib hbdebug.lib hbsqlit3.lib sqlite3.lib gtgui.lib gtwin.lib gtwvt.lib hbmainwin.lib"
REM hbmainwin may be named differently
if not exist "%HBLIB%\hbmainwin.lib" set "HBLIBS=hbvmmt.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib hbcplr.lib hbct.lib hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib hbcpage.lib hbpcre.lib hbzlib.lib hbdebug.lib hbsqlit3.lib sqlite3.lib gtgui.lib gtwin.lib gtwvt.lib"

REM OpenADS: rddads (Harbour contrib) + ACE import lib; ace64.dll is
REM delay-loaded so the exe still starts when the DLL is not present
set "ADSLIBS="
set "ADSLINK="
if exist "%HBLIB%\rddads.lib" (
  set "ADSLIBS=rddads.lib ace64.lib delayimp.lib legacy_stdio_definitions.lib oldnames.lib"
  set "ADSLINK=/DELAYLOAD:ace64.dll"
) else (
  echo WARNING: rddads.lib not found in %HBLIB% - openads driver will not link
)

set "SYSLIBS=user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib uuid.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib winspool.lib dwmapi.lib iphlpapi.lib shlwapi.lib"

link.exe /NOLOGO /OUT:"%OUT%" /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT %ADSLINK% /LIBPATH:"%HBLIB%" %OBJS% %HBLIBS% %ADSLIBS% %SYSLIBS%
if errorlevel 1 (
  echo LINK FAILED
  exit /b 1
)

REM ACE client DLL for the openads driver (OpenADS build copied as ace64.dll)
if exist "C:\OpenADS\build\default\src\Release\openace64.dll" (
  copy /y "C:\OpenADS\build\default\src\Release\openace64.dll" "%PROJDIR%\ace64.dll" >nul
  echo Copied ace64.dll - OpenADS ACE - next to the exe
)

REM Runtime next to exe: www + exact FWH meta JSON copy
if not exist "%PROJDIR%\www\index.html" (
  echo WARNING: www\index.html missing
)
REM Keep FWH DesktopWeb meta in sync with this project's meta (source of truth).
echo [5] Push meta -^> FWH DesktopWeb
call "%PROJDIR%\push_meta_to_fwh.bat"
if errorlevel 1 (
  echo WARNING: push_meta_to_fwh failed — FWH may be outdated
)
REM Optional reverse pull (FWH -^> here). Off by default; use only when FWH is newer.
if /I "%SYNC_FWH_META%"=="1" (
  echo [5b] Pull meta from FWH DesktopWeb (SYNC_FWH_META=1)
  call "%PROJDIR%\sync_meta.bat"
  if errorlevel 1 (
    echo WARNING: meta pull failed — using existing meta\ if present
  )
)
if exist "C:\fwteam\dll\webview64\WebView2Loader.dll" (
  copy /y "C:\fwteam\dll\webview64\WebView2Loader.dll" "%PROJDIR%\" >nul
)

echo.
echo === BUILD OK ===
echo Output: %OUT%
dir "%OUT%"
echo.
echo Run:  %PROJDIR%\FiveTech_ERP.exe
echo URL:  http://127.0.0.1:2222/  (inside WebView2)
echo Login: admin/1234  or  demo/demo
echo.
endlocal
exit /b 0
