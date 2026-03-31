@echo off
setlocal

set HDIR=c:\harbour
set CDIR=c:\bcc77c
set HARBOUR=%HDIR%\bin\win\bcc\harbour.exe
set CC=%CDIR%\bin\bcc32c.exe
set ILINK=%CDIR%\bin\ilink32.exe
set PROG=%1

if "%PROG%"=="" (
   echo Usage: build_con.bat progname
   goto EXIT
)

echo Compiling %PROG%.prg...
%HARBOUR% %PROG%.prg /n /w /q /ic:\ide\include;%HDIR%\include > comp.log 2>&1
if errorlevel 1 (
   type comp.log
   echo * Harbour compile error *
   goto EXIT
)

echo Compiling %PROG%.c...
%CC% -c -O2 -I%HDIR%\include -I%CDIR%\include %PROG%.c > cc.log 2>&1
if errorlevel 1 (
   type cc.log
   echo * C compile error *
   goto EXIT
)

echo Linking %PROG%.exe...
%ILINK% -Gn -ap -Tpe -L%CDIR%\lib -L%CDIR%\lib\psdk -L%HDIR%\lib\win\bcc ^
   c0x32.obj %PROG%.obj, %PROG%.exe,, ^
   hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib ^
   hbcommon.lib hbcplr.lib hbct.lib ^
   hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib ^
   hbdebug.lib gtwin.lib ^
   cw32.lib import32.lib ws2_32.lib ^
   user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ^
   , , > link.log 2>&1

if errorlevel 1 (
   type link.log
   echo * Link error *
   goto EXIT
)

echo.
echo * %PROG%.exe built successfully (console) *
.\%PROG%.exe

:EXIT
endlocal
