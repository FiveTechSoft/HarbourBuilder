@echo off
cd /d C:\HarbourBuilder\source
echo === Linking ===
C:\bcc77\bin\ilink32.exe -Tpe -aa -Gn -LC:\bcc77\lib;C:\bcc77\lib\psdk;C:\harbour\lib\win\bcc c0w32.obj hbbuilder_win.obj tform.obj hbbridge.obj tcontrol.obj tcontrols.obj, ..\bin\hbbuilder_win.exe, , cw32mt.lib import32.lib hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib rddntx.lib rddcdx.lib rddfpt.lib hbsix.lib hbcpage.lib hbpcre.lib hbzlib.lib gtgui.lib gtwin.lib hbsqlit3.lib sqlite3.lib hbdebug.lib user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib
if errorlevel 1 (
   echo LINK FAILED
   exit /b 1
)
echo LINK OK
dir ..\bin\hbbuilder_win.exe
exit /b 0
