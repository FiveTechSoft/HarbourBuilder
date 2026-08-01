// Project1.prg — FiveTech_ERP entry (same PRG on Windows / Linux / macOS)
// UI: HarbourBuilder TForm + TWebView
//   Windows  → Edge WebView2
//   macOS    → WKWebView (Cocoa)
//   Linux    → GTK WebKit
// Meta: ./meta (FWH DesktopWeb JSON)  |  HTTP: erp_http.prg (MT sockets)
//--------------------------------------------------------------------
#include "hbbuilder.ch"

// GT is injected by assemble_main (Win: GUI_DEFAULT, Mac/Linux: NUL)
// so the same Project1.prg works on every OS without #ifdef.
REQUEST HB_CODEPAGE_UTF8EX
REQUEST HB_MT

//--------------------------------------------------------------------
function Main()

   // Same codepage on all hosts so UTF-8 meta (€, accents) is consistent
   hb_cdpSelect( "UTF8EX" )

   Form1()

return nil
