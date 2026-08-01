# Assemble main.prg (Project1 + Form1 only). erp_* compile as separate units.
param(
  [string]$ProjDir,
  [string]$BuildDir
)

$ErrorActionPreference = "Stop"
$files = @("Project1.prg", "Form1.prg")
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('#include "hbbuilder.ch"')
[void]$sb.AppendLine("REQUEST HB_GT_GUI_DEFAULT")
[void]$sb.AppendLine("REQUEST HB_CODEPAGE_UTF8EX")
[void]$sb.AppendLine("REQUEST DBFCDX, DBFNTX, DBFFPT")
[void]$sb.AppendLine("REQUEST RDDSYS")
[void]$sb.AppendLine("")

foreach ($f in $files) {
  $path = Join-Path $ProjDir $f
  $t = [System.IO.File]::ReadAllText($path)
  $t = $t -replace '#include\s+"hbbuilder\.ch"', ""
  $t = $t -replace '#include\s+"classes\.prg"', ""
  $t = $t.Replace([string][char]26, "")
  [void]$sb.AppendLine($t)
  [void]$sb.AppendLine("")
}

$stub = @'

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>
/* Msg helpers + stubs for optional controls referenced by classes.prg */
HB_FUNC( UI_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "FiveTech_ERP", 0x40 );
}
HB_FUNC( UI_MSGYESNO )
{
   hb_retl( MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "Confirm", 0x24 ) == 6 );
}
HB_FUNC( MAC_RUNTIMEERRORDIALOG ) { hb_retni( 0 ); }
HB_FUNC( MAC_APPTERMINATE ) {}

HB_FUNC( UI_SCENE3DNEW )    { hb_retnint( 0 ); }
HB_FUNC( UI_EARTHVIEWNEW )  { hb_retnint( 0 ); }
HB_FUNC( UI_MAPNEW )        { hb_retnint( 0 ); }
HB_FUNC( UI_MAPSETREGION )  {}
HB_FUNC( UI_MAPADDPIN )     {}
HB_FUNC( UI_MAPCLEARPINS )  {}
HB_FUNC( UI_MASKEDITNEW )   { hb_retnint( 0 ); }
HB_FUNC( UI_STRINGGRIDNEW ) { hb_retnint( 0 ); }
HB_FUNC( UI_GRIDSETCELL )   {}
HB_FUNC( UI_GRIDGETCELL )   { hb_retc( "" ); }
/* HarbourBuilder AppShowError → W32_ErrorDialog (full text, stack, Quit) */
/* W32_ErrorDialog is implemented in fte_errdlg.c (Copy to Clipboard + Quit) */
HB_FUNC( HIX_RESOLVEPATH )
{
   hb_retc( "" );
}
#pragma ENDDUMP
'@
[void]$sb.AppendLine($stub)

$out = Join-Path $BuildDir "main.prg"
[System.IO.File]::WriteAllText($out, $sb.ToString())
Write-Host "Wrote $out ($($sb.Length) chars)"

# Copy erp modules for separate compile
Copy-Item (Join-Path $ProjDir "erp_meta.prg") (Join-Path $BuildDir "erp_meta.prg") -Force
Copy-Item (Join-Path $ProjDir "erp_http.prg") (Join-Path $BuildDir "erp_http.prg") -Force
