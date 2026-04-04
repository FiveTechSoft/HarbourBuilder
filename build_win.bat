@echo off
REM Build HbBuilder for Windows
REM Requires: Harbour, BCC77, and Scintilla/Lexilla DLLs in resources/

set HBDIR=C:\harbour
set HBBIN=%HBDIR%\bin\win\bcc
set HBINC=%HBDIR%\include
set HBLIB=%HBDIR%\lib\win\bcc
set CCDIR=C:\bcc77
set CCBIN=%CCDIR%\bin
set CCLIB=%CCDIR%\lib
set PSDKLIB=%CCDIR%\lib\psdk
set SRCDIR=%~dp0samples
set CPPDIR=%~dp0cpp
set OUTDIR=%~dp0bin

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

echo === Step 1: Compile Harbour PRG ===
cd /d "%SRCDIR%"
"%HBBIN%\harbour.exe" hbbuilder_win.prg -n -w -es2 -q -I%HBINC%
if errorlevel 1 (echo HARBOUR FAILED & pause & exit /b 1)

echo === Step 2: Compile C framework ===
REM Compile the C++ framework sources
"%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include hbbuilder_win.c
if not exist hbbuilder_win.obj (echo BCC32 FAILED & pause & exit /b 1)

REM Compile tform.cpp
if exist "%CPPDIR%\src\tform.cpp" (
   "%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include "%CPPDIR%\src\tform.cpp"
)
REM Compile hbbridge.cpp
if exist "%CPPDIR%\src\hbbridge.cpp" (
   "%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include "%CPPDIR%\src\hbbridge.cpp"
)
REM Compile tcontrol.cpp
if exist "%CPPDIR%\src\tcontrol.cpp" (
   "%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include "%CPPDIR%\src\tcontrol.cpp"
)
REM Compile tcontrols.cpp
if exist "%CPPDIR%\src\tcontrols.cpp" (
   "%CCBIN%\bcc32.exe" -c -O2 -tW -w- -I%HBINC% -I%CPPDIR%\include "%CPPDIR%\src\tcontrols.cpp"
)

echo === Step 3: Link ===
set OBJS=c0w32.obj hbbuilder_win.obj
if exist tform.obj set OBJS=%OBJS% tform.obj
if exist hbbridge.obj set OBJS=%OBJS% hbbridge.obj
if exist tcontrol.obj set OBJS=%OBJS% tcontrol.obj
if exist tcontrols.obj set OBJS=%OBJS% tcontrols.obj

"%CCBIN%\ilink32.exe" -Tpe -aa -Gn -L%CCLIB%;%PSDKLIB%;%HBLIB% %OBJS%, "%OUTDIR%\hbbuilder_win.exe", , cw32mt.lib import32.lib hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib rddntx.lib rddcdx.lib rddfpt.lib hbsix.lib hbcpage.lib hbpcre.lib hbzlib.lib gtgui.lib gtwin.lib hbsqlit3.lib sqlite3.lib hbdebug.lib user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib
if errorlevel 1 (echo LINK FAILED & pause & exit /b 1)

echo === Step 4: Copy Scintilla DLLs ===
copy /y "%~dp0resources\Scintilla.dll" "%OUTDIR%\" >nul
copy /y "%~dp0resources\Lexilla.dll" "%OUTDIR%\" >nul

echo === BUILD SUCCESS ===
echo Output: %OUTDIR%\hbbuilder_win.exe
pause
