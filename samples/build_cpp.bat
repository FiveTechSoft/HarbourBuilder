@echo off
setlocal

set HDIR=c:\harbour
set CDIR=c:\bcc77c
set HARBOUR=%HDIR%\bin\win\bcc\harbour.exe
set CC=%CDIR%\bin\bcc32c.exe
set ILINK=%CDIR%\bin\ilink32.exe
set PROG=%1
set CPPDIR=c:\ide\cpp

if "%PROG%"=="" (
   echo Usage: build_cpp.bat progname
   goto EXIT
)

echo [1/5] Compiling %PROG%.prg...
%HARBOUR% %PROG%.prg /n /w /q /i%HDIR%\include > comp.log 2>&1
if errorlevel 1 (
   type comp.log
   echo -- Harbour compile error --
   goto EXIT
)

echo [2/5] Compiling %PROG%.c...
%CC% -c -O2 -tW -I%HDIR%\include -I%CDIR%\include -I%CPPDIR%\include %PROG%.c > cc.log 2>&1
if errorlevel 1 (
   type cc.log
   echo -- C compile error --
   goto EXIT
)

echo [3/5] Compiling C++ core...
%CC% -c -O2 -tW -I%HDIR%\include -I%CDIR%\include -I%CPPDIR%\include ^
   %CPPDIR%\src\tcontrol.cpp ^
   %CPPDIR%\src\tform.cpp ^
   %CPPDIR%\src\tcontrols.cpp ^
   %CPPDIR%\src\hbbridge.cpp > cc_cpp.log 2>&1
if errorlevel 1 (
   type cc_cpp.log
   echo -- C++ compile error --
   goto EXIT
)

echo [4/5] Linking %PROG%.exe...
%ILINK% -Gn -aa -Tpe -L%CDIR%\lib -L%CDIR%\lib\psdk -L%HDIR%\lib\win\bcc ^
   c0w32.obj %PROG%.obj tcontrol.obj tform.obj tcontrols.obj hbbridge.obj, %PROG%.exe,, ^
   hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib ^
   hbcommon.lib hbcplr.lib hbct.lib ^
   hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib ^
   hbdebug.lib gtwin.lib gtwvt.lib gtgui.lib ^
   cw32.lib import32.lib ws2_32.lib ^
   user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib uuid.lib ^
   , , > link.log 2>&1

if errorlevel 1 (
   type link.log
   echo -- Link error --
   goto EXIT
)

echo [5/5] Done!
echo.
echo -- %PROG%.exe built successfully (C++ core) --
start %PROG%

:EXIT
endlocal
