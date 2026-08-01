// Form1.prg — FiveTech_ERP shell (same PRG on Windows / Linux / macOS)
// HTTP server + embedded WebView (title bar shows URL / status, FWH style)
//--------------------------------------------------------------------
#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   DATA oWeb
   DATA nPort     INIT 2222
   DATA cUrl      INIT ""
   DATA cAppTitle INIT "FiveTech_ERP"

   METHOD CreateForm()
   METHOD StartServer()
   METHOD StopServer()
   METHOD SetWinTitle( cExtra )

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cAppTitle := "FiveTech_ERP"
   ::cTitle    := ::cAppTitle + "  |  Starting HTTP server..."
   ::nLeft     := 80
   ::nTop      := 40
   ::nWidth    := 1280
   ::nHeight   := 820
   ::nPort     := 2222

   // Full-client WebView — backend is OS-specific, API is the same TWebView
   @ 0, 0 WEBVIEW ::oWeb OF Self SIZE 1280, 820
   ::oWeb:nControlAlign := 5   // alClient (resize with form / maximize)

   ::OnClose := {|| ::StopServer() }

   // Start HTTP before Activate so first Navigate finds the port open
   ::StartServer()

return nil
//--------------------------------------------------------------------

METHOD SetWinTitle( cExtra ) CLASS TForm1

   local c := ::cAppTitle

   if ! Empty( cExtra )
      c += "  |  " + cExtra
   endif
   ::cTitle := c

return nil
//--------------------------------------------------------------------

METHOD StartServer() CLASS TForm1

   local cMsg := ""

   if ! ErpHttpStart( ::nPort, @cMsg )
      ::SetWinTitle( "HTTP failed: " + cMsg )
      MsgInfo( "Could not start HTTP on port " + hb_ntos( ::nPort ) + ;
         Chr( 10 ) + cMsg, "FiveTech_ERP" )
      return nil
   endif

   ::cUrl := "http://127.0.0.1:" + hb_ntos( ::nPort ) + "/"
   ::SetWinTitle( ::cUrl + "   ·   meta: " + ErpMetaRoot() )
   if ::oWeb != nil
      ::oWeb:Navigate( ::cUrl )
   endif

return nil
//--------------------------------------------------------------------

METHOD StopServer() CLASS TForm1
   ErpHttpStop()
return nil
//--------------------------------------------------------------------

// Form1 factory — TApplication installs ErrorBlock → AppShowError
function Form1()

   local oApp, oForm

   oApp  := TApplication():New()
   oApp:cTitle := "FiveTech_ERP"
   oForm := TForm1():New()
   oApp:CreateForm( oForm )
   oApp:Run()

return nil
