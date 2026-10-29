@echo off
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "HBDIR=C:\harbour"
if not "%HBDIR_OVERRIDE%"=="" set "HBDIR=%HBDIR_OVERRIDE%"
set "HBBIN=%HBDIR%\bin"
if not exist "%HBBIN%\hbmk2.exe" set "HBBIN=%HBDIR%\bin\win\msvc64"
if not exist "%HBBIN%\hbmk2.exe" ( echo ERROR: hbmk2.exe not found & exit /b 1 )
if not exist "%HBBIN%\harbour.exe" ( echo ERROR: harbour.exe not found & exit /b 1 )
set "PATH=%HBBIN%;%PATH%"
set "BINDIR=%ROOT%tests\bin"
if not exist "%BINDIR%" mkdir "%BINDIR%"
set FAIL=0
set PASS=0
rem hbmk2 selects the native compiler and the complete platform linker inputs.
echo === test harness self-check ===
"%HBBIN%\hbmk2.exe" "%ROOT%tests\harness_failure.prg" "%ROOT%tests\test_runner.prg" -I"%ROOT%tests" -q -quiet -w -es2 -gtstd -o"%BINDIR%\harness_failure.exe"
if errorlevel 1 exit /b 1
"%BINDIR%\harness_failure.exe"
if not errorlevel 1 ( echo ERROR: harness accepted an assertion failure & exit /b 1 )
for %%T in (test_codegen test_hbp_index test_hbp_parse test_messages test_project_tab test_hix_path test_component_types test_ct_constants test_project_roundtrip) do call :run_test %%T
for %%I in (hbbuilder_win hbbuilder_linux hbbuilder_macos) do (
   "%HBBIN%\harbour.exe" "%ROOT%source\%%I.prg" -n -w -es2 -q -I"%HBDIR%\include" -I"%ROOT%include" -I"%ROOT%source" -o"%BINDIR%\%%I_syntax.c"
   if errorlevel 1 ( set /a FAIL+=1 ) else ( echo OK: %%I syntax )
)
echo TEST SUMMARY: %PASS% suites passed, %FAIL% failures
if not %FAIL%==0 exit /b 1
exit /b 0
:run_test
set "TNAME=%~1"
echo === %TNAME% ===
"%HBBIN%\hbmk2.exe" "%ROOT%tests\%TNAME%.prg" "%ROOT%tests\test_runner.prg" "%ROOT%source\hbbuilder_common.prg" "%ROOT%tests\messages_stubs.prg" -I"%ROOT%include" -I"%ROOT%tests" -q -quiet -w -es2 -gtstd -o"%BINDIR%\%TNAME%.exe"
if errorlevel 1 ( echo BUILD FAILED: %TNAME% & set /a FAIL+=1 & goto :eof )
"%BINDIR%\%TNAME%.exe"
if errorlevel 1 ( set /a FAIL+=1 ) else ( set /a PASS+=1 )
goto :eof
