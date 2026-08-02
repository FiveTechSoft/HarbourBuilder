@echo off
REM Push FiveTech_ERP meta → FWH DesktopWeb meta (keeps both trees in sync).
REM Additive copy (no /MIR deletes). Call after every meta save in this project.
setlocal
set "SRC=%~dp0meta"
set "DST=C:\fwteam\samples\DesktopWeb\meta"

if not exist "%SRC%\app.json" (
  echo ERROR: source meta missing: %SRC%
  exit /b 1
)
if not exist "%DST%" (
  echo ERROR: FWH meta not found: %DST%
  exit /b 1
)

echo Pushing FiveTech_ERP meta -^> FWH DesktopWeb...
echo   %SRC%
echo   -^> %DST%
robocopy "%SRC%" "%DST%" /E /XO /NFL /NDL /NJH /NJS /nc /ns /np
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
  echo ERROR: robocopy failed code %RC%
  exit /b 1
)

REM Ensure local-only packs always land even if timestamps confuse /XO
if exist "%SRC%\verticals\ferreteria" (
  robocopy "%SRC%\verticals\ferreteria" "%DST%\verticals\ferreteria" /E /IS /IT /NFL /NDL /NJH /NJS /nc /ns /np >nul
)
echo Push OK.
endlocal
exit /b 0
