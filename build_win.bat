@echo off
REM Build HbBuilder for Windows
REM Auto-detects compilers: BCC -> MSVC x86 -> MinGW
REM Requires: Harbour and Scintilla/Lexilla DLLs in resources/

setlocal enabledelayedexpansion

set HBDIR=C:\harbour
set HBINC=%HBDIR%\include
set SRCDIR=%~dp0samples
set CPPDIR=%~dp0cpp
set OUTDIR=%~dp0bin

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

REM ============================================================
REM   Detect available compilers
REM ============================================================
set N_COMPILERS=0

REM --- Check BCC ---
set BCC_FOUND=0
for %%d in (C:\bcc77c C:\bcc77 C:\bcc C:\Embarcadero\BCC77 C:\Embarcadero\BCC) do (
   if exist "%%d\bin\bcc32.exe" (
      set BCC_FOUND=1
      set BCC_DIR=%%d
      set /a N_COMPILERS+=1
      set COMP_!N_COMPILERS!=bcc
      set COMP_!N_COMPILERS!_NAME=Embarcadero BCC [%%d]
      set COMP_!N_COMPILERS!_DIR=%%d
   )
)

REM --- Check MSVC x86 (via vswhere) ---
set MSVC_FOUND=0
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist %VSWHERE% (
   for /f "usebackq tokens=*" %%i in (`%VSWHERE% -latest -property installationPath`) do set VSDIR=%%i
   if defined VSDIR (
      REM Find MSVC tools version
      for /d %%v in ("!VSDIR!\VC\Tools\MSVC\*") do set MSVC_VER_DIR=%%v
      if defined MSVC_VER_DIR (
         if exist "!MSVC_VER_DIR!\bin\Hostx86\x86\cl.exe" (
            set MSVC_FOUND=1
            set MSVC_BASE=!MSVC_VER_DIR!
            set /a N_COMPILERS+=1
            set COMP_!N_COMPILERS!=msvc
            set COMP_!N_COMPILERS!_NAME=MSVC x86 [!MSVC_VER_DIR!]
            set COMP_!N_COMPILERS!_DIR=!MSVC_VER_DIR!
         )
      )
   )
)

REM --- Check MinGW ---
set MINGW_FOUND=0
for %%d in (C:\mingw C:\mingw64 C:\msys64\mingw32 C:\msys64\mingw64 C:\TDM-GCC-64 C:\TDM-GCC-32) do (
   if exist "%%d\bin\gcc.exe" if !MINGW_FOUND!==0 (
      set MINGW_FOUND=1
      set MINGW_DIR=%%d
      set /a N_COMPILERS+=1
      set COMP_!N_COMPILERS!=mingw
      set COMP_!N_COMPILERS!_NAME=MinGW GCC [%%d]
      set COMP_!N_COMPILERS!_DIR=%%d
   )
)

REM ============================================================
REM   No compilers found?
REM ============================================================
if %N_COMPILERS%==0 (
   echo.
   echo ERROR: No C/C++ compiler found!
   echo.
   echo Please install one of:
   echo   - Embarcadero BCC: www.embarcadero.com ^(free^)
   echo   - Visual Studio Build Tools: visualstudio.microsoft.com ^(free^)
   echo   - MinGW/TDM-GCC: https://jmeubank.github.io/tdm-gcc/
   echo.
   pause
   exit /b 1
)

REM ============================================================
REM   One compiler: use it. Multiple: let user choose.
REM ============================================================
if %N_COMPILERS%==1 (
   set COMPILER=!COMP_1!
   set COMPILER_DIR=!COMP_1_DIR!
   echo Using: !COMP_1_NAME!
   goto :build
)

echo.
echo Available C/C++ compilers:
echo.
for /L %%i in (1,1,%N_COMPILERS%) do (
   echo   %%i. !COMP_%%i_NAME!
)
echo.
set /p CHOICE="Select compiler (1-%N_COMPILERS%): "

if not defined CHOICE set CHOICE=1
if %CHOICE% LSS 1 set CHOICE=1
if %CHOICE% GTR %N_COMPILERS% set CHOICE=%N_COMPILERS%

set COMPILER=!COMP_%CHOICE%!
set COMPILER_DIR=!COMP_%CHOICE%_DIR!
echo.
echo Using: !COMP_%CHOICE%_NAME!

:build
echo.

REM ============================================================
REM   Build with selected compiler
REM ============================================================

if "%COMPILER%"=="bcc" goto :build_bcc
if "%COMPILER%"=="msvc" goto :build_msvc
if "%COMPILER%"=="mingw" goto :build_mingw
echo ERROR: Unknown compiler %COMPILER%
pause
exit /b 1

REM ============================================================
:build_bcc
REM ============================================================
set HBBIN=%HBDIR%\bin\win\bcc
set HBLIB=%HBDIR%\lib\win\bcc
set CCBIN=%COMPILER_DIR%\bin
set CCLIB=%COMPILER_DIR%\lib
set PSDKLIB=%COMPILER_DIR%\lib\psdk

echo === Step 1: Compile Harbour PRG ===
cd /d "%SRCDIR%"
"%HBBIN%\harbour.exe" hbbuilder_win.prg -n -w -es2 -q -I%HBINC%
if errorlevel 1 (echo HARBOUR FAILED & pause & exit /b 1)

echo === Step 2: Compile C sources ===
"%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include hbbuilder_win.c
if not exist hbbuilder_win.obj (echo BCC32 FAILED on hbbuilder_win.c & pause & exit /b 1)

for %%f in (tform hbbridge tcontrol tcontrols) do (
   if exist "%CPPDIR%\src\%%f.cpp" (
      "%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include "%CPPDIR%\src\%%f.cpp"
      if not exist %%f.obj (echo BCC32 FAILED on %%f.cpp & pause & exit /b 1)
   )
)

echo === Step 3: Link ===
set OBJS=c0w32.obj hbbuilder_win.obj tform.obj hbbridge.obj tcontrol.obj tcontrols.obj
"%CCBIN%\ilink32.exe" -Tpe -aa -Gn -L%CCLIB%;%PSDKLIB%;%HBLIB% %OBJS%, "%OUTDIR%\hbbuilder_win.exe", , cw32mt.lib import32.lib hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib rddntx.lib rddcdx.lib rddfpt.lib hbsix.lib hbcpage.lib hbpcre.lib hbzlib.lib gtgui.lib gtwin.lib hbsqlit3.lib sqlite3.lib hbdebug.lib user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib
if errorlevel 1 (echo LINK FAILED & pause & exit /b 1)
goto :copy_dlls

REM ============================================================
:build_msvc
REM ============================================================
set HBBIN=%HBDIR%\bin\win\msvc
set HBLIB=%HBDIR%\lib\win\msvc
set MSVC_BIN=%COMPILER_DIR%\bin\Hostx86\x86
set MSVC_INC=%COMPILER_DIR%\include
set MSVC_LIB=%COMPILER_DIR%\lib\x86

REM Find Windows SDK
set WINKITDIR=C:\Program Files (x86)\Windows Kits\10
set WINKITVER=
for /d %%v in ("%WINKITDIR%\Include\10.*") do set WINKITVER=%%~nxv
if not defined WINKITVER (
   echo ERROR: Windows SDK not found in "%WINKITDIR%"
   pause & exit /b 1
)
set UCRT_INC=%WINKITDIR%\Include\%WINKITVER%\ucrt
set UM_INC=%WINKITDIR%\Include\%WINKITVER%\um
set SHARED_INC=%WINKITDIR%\Include\%WINKITVER%\shared
set UCRT_LIB=%WINKITDIR%\Lib\%WINKITVER%\ucrt\x86
set UM_LIB=%WINKITDIR%\Lib\%WINKITVER%\um\x86

echo === Step 1: Compile Harbour PRG ===
cd /d "%SRCDIR%"
"%HBBIN%\harbour.exe" hbbuilder_win.prg -n -w -es2 -q -I%HBINC%
if errorlevel 1 (echo HARBOUR FAILED & pause & exit /b 1)

echo === Step 2: Compile C sources ===
set CL_BASE=/c /O2 /W0 /EHsc /I"%HBINC%" /I"%MSVC_INC%" /I"%UCRT_INC%" /I"%UM_INC%" /I"%SHARED_INC%" /I"%CPPDIR%\include"

"%MSVC_BIN%\cl.exe" %CL_BASE% hbbuilder_win.c /Fohbbuilder_win.obj
if not exist hbbuilder_win.obj (echo CL FAILED on hbbuilder_win.c & pause & exit /b 1)

for %%f in (tform hbbridge tcontrol tcontrols) do (
   if exist "%CPPDIR%\src\%%f.cpp" (
      "%MSVC_BIN%\cl.exe" %CL_BASE% "%CPPDIR%\src\%%f.cpp" /Fo%%f.obj
      if not exist %%f.obj (echo CL FAILED on %%f.cpp & pause & exit /b 1)
   )
)

echo === Step 3: Link ===
set OBJS=hbbuilder_win.obj tform.obj hbbridge.obj tcontrol.obj tcontrols.obj
"%MSVC_BIN%\link.exe" /NOLOGO /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT /OUT:"%OUTDIR%\hbbuilder_win.exe" /LIBPATH:"%MSVC_LIB%" /LIBPATH:"%UCRT_LIB%" /LIBPATH:"%UM_LIB%" /LIBPATH:"%HBLIB%" %OBJS% hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib hbcommon.lib hbcplr.lib hbct.lib hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib hbdebug.lib hbpcre.lib hbzlib.lib hbsqlit3.lib sqlite3.lib gtwin.lib gtwvt.lib gtgui.lib user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib ucrt.lib vcruntime.lib msvcrt.lib
if errorlevel 1 (echo LINK FAILED & pause & exit /b 1)
goto :copy_dlls

REM ============================================================
:build_mingw
REM ============================================================
set HBBIN=%HBDIR%\bin\win\mingw
set HBLIB=%HBDIR%\lib\win\mingw
set GCCBIN=%COMPILER_DIR%\bin

echo === Step 1: Compile Harbour PRG ===
cd /d "%SRCDIR%"
"%HBBIN%\harbour.exe" hbbuilder_win.prg -n -w -es2 -q -I%HBINC%
if errorlevel 1 (echo HARBOUR FAILED & pause & exit /b 1)

echo === Step 2: Compile C sources ===
"%GCCBIN%\gcc.exe" -c -O2 -I"%HBINC%" -I"%CPPDIR%\include" hbbuilder_win.c -o hbbuilder_win.o
if not exist hbbuilder_win.o (echo GCC FAILED on hbbuilder_win.c & pause & exit /b 1)

for %%f in (tform hbbridge tcontrol tcontrols) do (
   if exist "%CPPDIR%\src\%%f.cpp" (
      "%GCCBIN%\g++.exe" -c -O2 -I"%HBINC%" -I"%CPPDIR%\include" "%CPPDIR%\src\%%f.cpp" -o %%f.o
      if not exist %%f.o (echo G++ FAILED on %%f.cpp & pause & exit /b 1)
   )
)

echo === Step 3: Link ===
set OBJS=hbbuilder_win.o tform.o hbbridge.o tcontrol.o tcontrols.o
"%GCCBIN%\g++.exe" -mwindows -o "%OUTDIR%\hbbuilder_win.exe" %OBJS% -L"%HBLIB%" -lhbvm -lhbrtl -lhbcommon -lhblang -lhbrdd -lhbmacro -lhbpp -lhbcpage -lrddntx -lrddcdx -lrddfpt -lhbsix -lhbpcre -lhbzlib -lgtgui -lgtwin -lhbsqlit3 -lsqlite3 -lhbdebug -luser32 -lgdi32 -lcomctl32 -lcomdlg32 -lshell32 -lole32 -loleaut32 -ladvapi32 -lws2_32 -lwinmm -lmsimg32 -lgdiplus
if errorlevel 1 (echo LINK FAILED & pause & exit /b 1)
goto :copy_dlls

REM ============================================================
:copy_dlls
REM ============================================================
echo === Step 4: Copy Scintilla DLLs ===
copy /y "%~dp0resources\Scintilla.dll" "%OUTDIR%\" >nul
copy /y "%~dp0resources\Lexilla.dll" "%OUTDIR%\" >nul

echo.
echo === BUILD SUCCESS ===
echo Output: %OUTDIR%\hbbuilder_win.exe
echo.
pause
