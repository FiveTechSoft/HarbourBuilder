@echo off
setlocal enabledelayedexpansion

set ROOT=%~dp0
set HBDIR=C:\harbour
if not "%HBDIR_OVERRIDE%"=="" set HBDIR=%HBDIR_OVERRIDE%

set HBBIN=%HBDIR%\bin
set HBLIB=%HBDIR%\lib
set HBINC=%HBDIR%\include
if not exist "%HBBIN%\harbour.exe" if exist "%HBDIR%\bin\win\msvc64\harbour.exe" set HBBIN=%HBDIR%\bin\win\msvc64
if not exist "%HBLIB%\hbvm.lib" if exist "%HBDIR%\lib\win\msvc64\hbvm.lib" set HBLIB=%HBDIR%\lib\win\msvc64

if not exist "%HBBIN%\harbour.exe" (
   echo ERROR: harbour.exe not found in %HBDIR%
   exit /b 1
)

set COMMON=%ROOT%source\hbbuilder_common.prg
set RUNNER=%ROOT%tests\test_runner.prg
set INCDIR=%ROOT%include
set TESTDIR=%ROOT%tests
set BINDIR=%ROOT%tests\bin
if not exist "%BINDIR%" mkdir "%BINDIR%"

for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2^>nul`) do set VSDIR=%%i
if not defined VSDIR for /f "usebackq tokens=*" %%i in (`"%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2^>nul`) do set VSDIR=%%i
if defined VSDIR call "%VSDIR%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul 2>&1

set FAIL=0
set PASS=0
set HBLIBS=hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib hbct.lib hbsix.lib rddntx.lib rddfpt.lib gtwin.lib gtwvt.lib
set SYSLIBS=user32.lib kernel32.lib gdi32.lib advapi32.lib ws2_32.lib winmm.lib ole32.lib
set CL_FLAGS=/nologo /c /O2 /MD /D_CRT_SECURE_NO_WARNINGS /I"%HBINC%" /I"%INCDIR%" /wd4101

cd /d "%TESTDIR%"

echo === messages_stubs ===
del /q messages_stubs.c messages_stubs.obj 2>nul
"%HBBIN%\harbour.exe" messages_stubs.prg -n -w -es2 -q -I"%HBINC%" -omessages_stubs
if errorlevel 1 ( echo HARBOUR FAILED: messages_stubs & exit /b 1 )
cl.exe %CL_FLAGS% messages_stubs.c /Fomessages_stubs.obj
if errorlevel 1 ( echo CL FAILED: messages_stubs & exit /b 1 )

call :run_test test_codegen
call :run_test test_hbp_index
call :run_test test_project_tab
call :run_test test_hix_path
call :run_test test_component_types
call :run_test test_hbp_parse
call :run_test test_messages
call :run_test test_ct_constants

echo.
echo === compile-only: IDE sources ===
cd /d "%ROOT%source"
"%HBBIN%\harbour.exe" hbbuilder_common.prg hbbuilder_win.prg -n -w -es2 -q -I"%HBINC%" -I"%INCDIR%" -ohbbuilder_win_syntax
if errorlevel 1 ( echo SYNTAX CHECK FAILED: hbbuilder_win.prg & set /a FAIL+=1 ) else ( echo OK: hbbuilder_win.prg syntax )
"%HBBIN%\harbour.exe" hbbuilder_common.prg hbbuilder_linux.prg -n -w -es2 -q -I"%HBINC%" -I"%INCDIR%" -I"%ROOT%source" -ohbbuilder_linux_syntax
if errorlevel 1 ( echo SYNTAX CHECK FAILED: hbbuilder_linux.prg & set /a FAIL+=1 ) else ( echo OK: hbbuilder_linux.prg syntax )
"%HBBIN%\harbour.exe" hbbuilder_common.prg hbbuilder_macos.prg -n -w -es2 -q -I"%HBINC%" -I"%INCDIR%" -I"%ROOT%source" -ohbbuilder_macos_syntax
if errorlevel 1 ( echo SYNTAX CHECK FAILED: hbbuilder_macos.prg & set /a FAIL+=1 ) else ( echo OK: hbbuilder_macos.prg syntax )
del /q hbbuilder_win_syntax.c hbbuilder_linux_syntax.c hbbuilder_macos_syntax.c hbbuilder_common.c 2>nul

echo.
if %FAIL%==0 (
   echo ALL TESTS PASSED (%PASS% tests^)
   exit /b 0
) else (
   echo TESTS FAILED (%FAIL% failed, %PASS% passed^)
   exit /b 1
)

:run_test
set TNAME=%~1
echo === %TNAME% ===
del /q "%TNAME%.c" "%TNAME%.obj" 2>nul
   "%HBBIN%\harbour.exe" "%TNAME%.prg" "%RUNNER%" "%COMMON%" -n -w -es2 -q -I"%HBINC%" -I"%INCDIR%" -o"%TNAME%"
if errorlevel 1 ( echo HARBOUR FAILED: %TNAME% & set /a FAIL+=1 & goto :eof )
if not exist "%TNAME%.c" ( echo NO C OUTPUT: %TNAME% & set /a FAIL+=1 & goto :eof )
cl.exe %CL_FLAGS% "%TNAME%.c" /Fo"%TNAME%.obj"
if errorlevel 1 ( echo CL FAILED: %TNAME% & set /a FAIL+=1 & goto :eof )
link.exe /NOLOGO /OUT:"%BINDIR%\%TNAME%.exe" /SUBSYSTEM:CONSOLE /NODEFAULTLIB:LIBCMT /LIBPATH:"%HBLIB%" %TNAME%.obj messages_stubs.obj %HBLIBS% %SYSLIBS%
if errorlevel 1 ( echo LINK FAILED: %TNAME% & set /a FAIL+=1 & goto :eof )
"%BINDIR%\%TNAME%.exe"
if errorlevel 1 ( echo FAILED: %TNAME% & set /a FAIL+=1 ) else ( set /a PASS+=1 )
goto :eof