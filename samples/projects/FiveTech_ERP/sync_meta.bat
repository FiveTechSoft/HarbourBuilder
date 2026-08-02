@echo off
REM Copy FWH DesktopWeb meta JSON tree into FiveTech_ERP\meta (byte-identical).
setlocal
set "SRC=C:\fwteam\samples\DesktopWeb\meta"
set "DST=%~dp0meta"

if not exist "%SRC%\app.json" (
  echo ERROR: FWH meta not found: %SRC%
  exit /b 1
)

if not exist "%DST%" mkdir "%DST%"
echo Syncing meta from FWH DesktopWeb...
echo   %SRC%
echo   -^> %DST%
robocopy "%SRC%" "%DST%" /E /XO /NFL /NDL /NJH /NJS /nc /ns /np
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
  echo ERROR: robocopy failed code %RC%
  exit /b 1
)

REM Force full mirror so deletes in FWH are reflected (exact same set)
robocopy "%SRC%" "%DST%" /MIR /NFL /NDL /NJH /NJS /nc /ns /np
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
  echo ERROR: robocopy mirror failed code %RC%
  exit /b 1
)

echo Meta sync OK ^(exact copy of FWH DesktopWeb meta^).
fc /b "%SRC%\app.json" "%DST%\app.json" >nul && echo app.json: identical
fc /b "%SRC%\modules.json" "%DST%\modules.json" >nul && echo modules.json: identical

REM Extract FWH login HTML only. www\dashboard.html is owned by FiveTech_ERP
REM (status bar, collapsible menu, pagination) and must NOT be overwritten.
if exist "%~dp0_extract_fwh_html.py" (
  echo Syncing FWH login HTML into www\ ^(dashboard.html preserved^)...
  python "%~dp0_extract_fwh_html.py"
)
endlocal
exit /b 0
