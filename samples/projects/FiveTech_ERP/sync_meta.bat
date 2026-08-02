@echo off
REM Optional: copy shared FWH DesktopWeb meta into FiveTech_ERP\meta.
REM NEVER use /MIR — that deletes FiveTech-only packs (ferreteria, companies apps, users CRC, …).
REM Prefer: leave this off (build_win64.bat only runs when SYNC_FWH_META=1).
setlocal
set "SRC=C:\fwteam\samples\DesktopWeb\meta"
set "DST=%~dp0meta"

if not exist "%SRC%\app.json" (
  echo ERROR: FWH meta not found: %SRC%
  exit /b 1
)

if not exist "%DST%" mkdir "%DST%"
echo Syncing meta from FWH DesktopWeb (additive /XO only — no mirror deletes)...
echo   %SRC%
echo   -^> %DST%
REM /XO = skip older; no /MIR so local-only verticals and screens survive
robocopy "%SRC%" "%DST%" /E /XO /NFL /NDL /NJH /NJS /nc /ns /np
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 (
  echo ERROR: robocopy failed code %RC%
  exit /b 1
)

echo Meta sync OK ^(additive; FiveTech-only files kept^).

REM Extract FWH login HTML only. www\dashboard.html is owned by FiveTech_ERP
if exist "%~dp0_extract_fwh_html.py" (
  echo Syncing FWH login HTML into www\ ^(dashboard.html preserved^)...
  python "%~dp0_extract_fwh_html.py"
)
endlocal
exit /b 0
