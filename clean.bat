@echo off
REM clean.bat - Remove build artifacts and dev clutter from HarbourBuilder
REM Safe to run; does not touch source or committed files.

echo Cleaning build artifacts...

REM Root level
del /q /s *.obj *.o *.exe *.tds *.log *.res *.c 2>nul
del /q startup_timing.log pos_trace.log error_trace.log save_trace.log android_trace.log scintilla_trace.log palette*.log inspector_trace.log bp_trace.log 2>nul

REM Common dirs
rd /s /q test_memo 2>nul
rd /s /q terminals 2>nul
rd /s /q hbbuilder_build hbbuilder_debug 2>nul

REM Samples and tests
for /d %%D in (samples\projects\*) do (
  del /q "%%D\*.obj" "%%D\*.o" "%%D\*.exe" "%%D\*.tds" "%%D\*.log" "%%D\*.c" 2>nul
)
del /q samples\*.obj samples\*.o samples\*.exe samples\*.tds samples\*.log samples\*.c 2>nul
del /q tests\*.obj tests\*.o tests\*.c 2>nul
rd /s /q tests\bin 2>nul

REM Android build dirs (common locations)
rd /s /q "%TEMP%\HarbourAndroid" 2>nul
rd /s /q C:\HarbourAndroid 2>nul

echo Done. (Some files may require admin rights or be in use.)
pause
