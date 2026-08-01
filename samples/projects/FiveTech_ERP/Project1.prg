// Project1.prg — FiveTech_ERP (HarbourBuilder multi-platform)
// Windows: Edge WebView2 (FWH engine)  |  Linux/macOS: native WebView
// Shared meta: meta_fwh -> FWH samples/DesktopWeb/meta  (or local meta/)
//--------------------------------------------------------------------
#include "hbbuilder.ch"

REQUEST HB_GT_GUI_DEFAULT
REQUEST HB_CODEPAGE_UTF8EX

// ---------------------------------------------------------------------------
// Main()
// ---------------------------------------------------------------------------
function Main()

   hb_cdpSelect( "UTF8EX" )

   Form1()

return nil

// Framework classes (cross-platform)
#include "classes.prg"
