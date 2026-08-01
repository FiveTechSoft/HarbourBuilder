@echo off
REM Build HbBuilder for Windows - VS 2022/2026 Ready (MSVC x64)
setlocal enabledelayedexpansion

set SRCDIR=%~dp0source
set CPPDIR=%~dp0source\cpp
set INCDIR=%~dp0include
set OUTDIR=%~dp0bin
set RESDIR=%~dp0resources

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

REM ============================================================
REM   Auto-detect Harbour installation (like the IDE does)
REM ============================================================
set HBDIR=
for %%D in (
   "C:\harbour"
   "%USERPROFILE%\harbour"
   "C:\hb"
   "C:\hb32"
   "%ProgramFiles%\harbour"
   "%ProgramFiles(x86)%\harbour"
   "%~dp0harbour"
   "%~dp0..\harbour"
) do (
   if exist "%%~D\bin\harbour.exe" (
      set HBDIR=%%~D
      goto :found_hb
   )
   if exist "%%~D\bin\win\msvc64\harbour.exe" (
      set HBDIR=%%~D
      goto :found_hb
   )
)
:found_hb
if "%HBDIR%"=="" (
   echo ERROR: No se encontro Harbour. Configura HBDIR manualmente o instala en una ubicacion comun.
   pause & exit /b 1
)

set HBINC=%HBDIR%\include
set HBBIN=%HBDIR%\bin
set HBLIB=%HBDIR%\lib

REM El install de Harbour puede ser plano o por-compilador
if not exist "%HBBIN%\harbour.exe" if exist "%HBDIR%\bin\win\msvc64\harbour.exe" set HBBIN=%HBDIR%\bin\win\msvc64
if not exist "%HBLIB%\hbvm.lib" if exist "%HBDIR%\lib\win\msvc64\hbvm.lib" set HBLIB=%HBDIR%\lib\win\msvc64

if not exist "%HBBIN%\harbour.exe" (
   echo ERROR: harbour.exe no encontrado en "%HBDIR%".
   pause & exit /b 1
)
if not exist "%HBLIB%\hbvm.lib" (
   echo ERROR: librerias de Harbour no encontradas en "%HBDIR%".
   pause & exit /b 1
)

REM ============================================================
REM   Detect Visual Studio via vswhere
REM ============================================================
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist %VSWHERE% set VSWHERE="%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist %VSWHERE% (
   echo ERROR: vswhere.exe no encontrado. Instala Visual Studio.
   pause & exit /b 1
)

for /f "usebackq tokens=*" %%i in (`%VSWHERE% -latest -property installationPath`) do set VSDIR=%%i

if not exist "%VSDIR%" (
   echo ERROR: No se encontro instalacion de Visual Studio.
   pause & exit /b 1
)

echo Detectado: %VSDIR%
echo Harbour:   %HBDIR% (x64)
echo.

REM Configura cl.exe / link.exe para x64 (Harbour install es x64)
call "%VSDIR%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul 2>&1
if errorlevel 1 (echo VsDevCmd FAILED & pause & exit /b 1)

REM ============================================================
REM   Build Process
REM ============================================================
echo === Step 1: Compile Harbour PRG ===
cd /d "%SRCDIR%"
"%HBBIN%\harbour.exe" hbbuilder_common.prg hbbuilder_win.prg -n -w -es2 -q -I%HBINC% -I%INCDIR%
if errorlevel 1 (echo HARBOUR FAILED & pause & exit /b 1)

echo === Step 2: Compile C/CPP sources ===
REM /D_CRT_SECURE_NO_WARNINGS silencia las deprecaciones de strcpy/sprintf/fopen...
REM (codigo C estandar legitimo; no migramos a las variantes _s no portables).
REM /MD (CRT dinamica): las libs de Harbour x64 estan compiladas contra la CRT
REM dinamica (importan __imp_*), asi que /MT provoca LNK2019 (_beginthreadex,
REM strspn, _dclass, ...). Mantener /MD para que coincidan.
set CL_BASE=/nologo /c /O2 /EHsc /MD /D_CRT_SECURE_NO_WARNINGS /I"%HBINC%" /I"%INCDIR%"

REM /wd4101 solo en el .c generado por harbour.exe (unreferenced locals
REM intrinsecos a la generacion PRG -> C, no corregibles aqui).
cl.exe %CL_BASE% /W3 /wd4101 hbbuilder_common.c /Fohbbuilder_common.obj
if errorlevel 1 (echo CL FAILED on hbbuilder_common.c & pause & exit /b 1)
cl.exe %CL_BASE% /W3 /wd4101 hbbuilder_win.c /Fohbbuilder_win.obj
if errorlevel 1 (echo CL FAILED on hbbuilder_win.c & pause & exit /b 1)

for %%f in (tform hbbridge tcontrol tcontrols hb_db_real) do (
   if exist "%CPPDIR%\%%f.cpp" (
      cl.exe %CL_BASE% /W3 "%CPPDIR%\%%f.cpp" /Fo%%f.obj
      if errorlevel 1 (echo CL FAILED on %%f.cpp & pause & exit /b 1)
   )
)

REM FWH WebView2 host (Edge) — live TWebView on Windows
set WV2DIR=%~dp0source\backends\win32\webview2
if exist "%WV2DIR%\fwh_webview2.cpp" (
   cl.exe %CL_BASE% /W3 /I"%WV2DIR%" "%WV2DIR%\fwh_webview2.cpp" /Fofwh_webview2.obj
   if errorlevel 1 (echo CL FAILED on fwh_webview2.cpp & pause & exit /b 1)
) else (
   echo WARNING: fwh_webview2.cpp not found - TWebView will not render on Windows
)

echo === Step 3: Link ===
set OBJS=hbbuilder_common.obj hbbuilder_win.obj tform.obj hbbridge.obj tcontrol.obj tcontrols.obj hb_db_real.obj
if exist fwh_webview2.obj set OBJS=%OBJS% fwh_webview2.obj
set HBLIBS=hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib ^
 hbcplr.lib hbct.lib hbhsx.lib hbsix.lib hbusrrdd.lib ^
 rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib ^
 hbcpage.lib hbpcre.lib hbzlib.lib hbdebug.lib ^
 hbsqlit3.lib sqlite3.lib ^
 gtgui.lib gtwin.lib gtwvt.lib
set SYSLIBS=user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ^
 ole32.lib oleaut32.lib advapi32.lib uuid.lib ws2_32.lib winmm.lib msimg32.lib ^
 gdiplus.lib winspool.lib dwmapi.lib iphlpapi.lib shlwapi.lib

REM /NODEFAULTLIB:LIBCMT: algunos .obj de las libs de Harbour referencian la CRT
REM estatica; con /MD forzamos la dinamica y silenciamos el LNK4098.
link.exe /NOLOGO /OUT:"%OUTDIR%\hbbuilder_win.exe" /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT ^
   /LIBPATH:"%HBLIB%" %OBJS% %HBLIBS% %SYSLIBS%

if errorlevel 1 (
    echo LINK FAILED
    pause
    exit /b 1
)

echo === Step 4: Copy Scintilla DLLs (x64) ===
REM Build x64 -> usa las DLL x64 de resources\x64\ (fallback al resources\ plano).
set DLLDIR=%RESDIR%\x64
if not exist "%DLLDIR%\Scintilla.dll" set DLLDIR=%RESDIR%
if exist "%DLLDIR%\Scintilla.dll" ( copy /y "%DLLDIR%\Scintilla.dll" "%OUTDIR%\" >nul ) else ( echo WARNING: Scintilla.dll no encontrada en "%DLLDIR%" - el editor de codigo no cargara )
if exist "%DLLDIR%\Lexilla.dll"   ( copy /y "%DLLDIR%\Lexilla.dll"   "%OUTDIR%\" >nul ) else ( echo WARNING: Lexilla.dll no encontrada en "%DLLDIR%" )

REM Optional: ship WebView2Loader next to exe (Evergreen Runtime still required on target)
if exist "C:\fwteam\dll\webview64\WebView2Loader.dll" (
   copy /y "C:\fwteam\dll\webview64\WebView2Loader.dll" "%OUTDIR%\" >nul
)

echo.
echo === BUILD SUCCESSFUL ===
echo Output: %OUTDIR%\hbbuilder_win.exe
echo WebView2: live Edge host (FWH engine) - requires WebView2 Runtime on the machine.
pause
