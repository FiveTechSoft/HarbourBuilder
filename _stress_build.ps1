param(
  [string]$Sample = "calculator",
  [switch]$Run
)

$ErrorActionPreference = "Continue"
$repo    = "C:\HarbourBuilder"
$hbBin   = "C:\harbour\bin\win\msvc64"
$hbLib   = "C:\harbour\lib\win\msvc64"
$hbInc   = "C:\harbour\include"
$resPath = "$repo\bin\HbBuilder.app\Contents\Resources"
$buildD  = "$env:TEMP\hbstress_$Sample"
$sampleD = "$repo\samples\projects\$Sample"

if (-not (Test-Path $sampleD)) { Write-Error "sample not found: $sampleD"; exit 1 }

# vswhere -> VsDevCmd
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { $vswhere = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe" }
$vsDir = & $vswhere -latest -property installationPath
$vsDevCmd = "$vsDir\Common7\Tools\VsDevCmd.bat"

# Load VsDevCmd env vars into current PS session
$envSnap = & cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul 2>&1 && set"
foreach ($line in $envSnap) {
  if ($line -match '^([^=]+)=(.*)$') { Set-Item "env:$($matches[1])" $matches[2] }
}

# Clean + recreate build dir
Remove-Item -Recurse -Force $buildD -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $buildD | Out-Null

# Collect every .prg in the sample (Project1 + Form1/2/... + FormReport, etc.)
$prgs = Get-ChildItem $sampleD -Filter "*.prg" | Sort-Object Name

# Copy bundled classes.prg + headers into the build dir
Copy-Item "$resPath\classes.prg"        "$buildD\classes.prg" -Force
Copy-Item "$repo\include\hbbuilder.ch"  "$buildD\hbbuilder.ch" -Force
Copy-Item "$repo\include\hbide.ch"      "$buildD\hbide.ch" -Force

$prgList = @() + $prgs.Name
"[1] harbour: $($prgList -join ', '), classes.prg"
foreach ($p in $prgs) {
  Copy-Item $p.FullName "$buildD\$($p.Name)" -Force
  $base = [System.IO.Path]::GetFileNameWithoutExtension($p.Name)
  & "$hbBin\harbour.exe" "$buildD\$($p.Name)" -n -w -es2 -q -I"$hbInc" -I"$repo\include" -I"$buildD" -I"$resPath" -o"$buildD\$base.c" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Error "harbour $($p.Name) failed"; exit 1 }
}
& "$hbBin\harbour.exe" "$buildD\classes.prg" -n -w -es2 -q -I"$hbInc" -I"$repo\include" -I"$buildD" -o"$buildD\classes.c" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "harbour classes failed"; exit 1 }

"[2] cl PRG-derived C"
$clFlags = @("/nologo", "/c", "/O2", "/EHsc", "/MD", "/D_CRT_SECURE_NO_WARNINGS",
             "/I$hbInc", "/I$repo\include")
$prgObjs = @()
foreach ($p in $prgs) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($p.Name)
  & cl.exe @clFlags "$buildD\$base.c" "/Fo$buildD\$base.obj" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Error "cl $base.c failed"; exit 1 }
  $prgObjs += "$buildD\$base.obj"
}
& cl.exe @clFlags "$buildD\classes.c" "/Fo$buildD\classes.obj" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "cl classes failed"; exit 1 }
$prgObjs += "$buildD\classes.obj"

"[3] cl C++ core"
$cppFiles = @("tform","hbbridge","tcontrol","tcontrols","hb_db_real")
foreach ($f in $cppFiles) {
  & cl.exe @clFlags "$repo\source\cpp\$f.cpp" "/Fo$buildD\$f.obj" 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Error "cl $f.cpp failed"; exit 1 }
}

"[4] link"
$exePath = "$buildD\$Sample.exe"
$cppObjs = $cppFiles | ForEach-Object { "$buildD\$_.obj" }
$objs = $prgObjs + $cppObjs
$hbLibs = "hbvm.lib hbrtl.lib hbcommon.lib hblang.lib hbrdd.lib hbmacro.lib hbpp.lib hbcplr.lib hbct.lib hbhsx.lib hbsix.lib hbusrrdd.lib rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib hbcpage.lib hbpcre.lib hbzlib.lib hbdebug.lib hbsqlit3.lib sqlite3.lib gtgui.lib gtwin.lib gtwvt.lib".Split(" ")
$sysLibs = "user32.lib kernel32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib ole32.lib oleaut32.lib advapi32.lib uuid.lib ws2_32.lib winmm.lib msimg32.lib gdiplus.lib winspool.lib dwmapi.lib iphlpapi.lib".Split(" ")
$linkOut = & link.exe /NOLOGO "/OUT:$exePath" /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT "/LIBPATH:$hbLib" $objs $hbLibs $sysLibs 2>&1
if ($LASTEXITCODE -ne 0) { $linkOut | Select-Object -Last 30; Write-Error "link failed"; exit 1 }

$sz = (Get-Item $exePath).Length
"BUILD OK: $exePath ($([math]::Round($sz/1024)) KB)"

if ($Run) {
  $p = Start-Process -FilePath $exePath -PassThru
  Start-Sleep -Seconds 4
  if (-not $p.HasExited) {
    "RUN OK: '$($p.MainWindowTitle)' PID=$($p.Id)"
    Stop-Process -Id $p.Id -Force
  } else {
    "RUN CRASHED: exit=$($p.ExitCode)"
    exit 2
  }
}
