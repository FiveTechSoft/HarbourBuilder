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
   local cArg

   if ! ErpHttpStart( ::nPort, @cMsg )
      ::SetWinTitle( "HTTP failed: " + cMsg )
      MsgInfo( "Could not start HTTP on port " + hb_ntos( ::nPort ) + ;
         Chr( 10 ) + cMsg, "FiveTech_ERP" )
      return nil
   endif

   ::cUrl := "http://127.0.0.1:" + hb_ntos( ::nPort ) + "/"
   // Rama PC parametrizable: ZWEB_FRONT=<montura> FiveTech_ERP_local.exe
   // carga ese bundle dentro del WebView2 (mismo contrato que el navegador).
   // Ej.: set ZWEB_FRONT=web-vainilla
   cArg := AllTrim( hb_GetEnv( "ZWEB_FRONT" ) )
   if ! Empty( cArg )
      ::cUrl += cArg + "/index.html"
   endif
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

//--------------------------------------------------------------------
// WebView2 → host: mensajes de JS (window.chrome.webview.postMessage / external.invoke).
// Convención del prototipo web-branch:
//   "open:http://..."  o  JSON {"cmd":"open","url":"http://..."}
// Abre el navegador nativo del SO; NO navega el WebView embebido.
// (Por defecto NewWindowRequested en fwh_webview2.cpp hace Navigate in-place.)
function WEBVIEW2_ONBIND( cMsg, hWeb )

   local cUrl, h, cCmd

   HB_SYMBOL_UNUSED( hWeb )
   cMsg := AllTrim( cMsg )
   if Empty( cMsg )
      return nil
   endif

   cUrl := ""
   if Left( Lower( cMsg ), 5 ) == "open:"
      cUrl := AllTrim( SubStr( cMsg, 6 ) )
   elseif Left( cMsg, 1 ) == "{"
      h := hb_jsonDecode( cMsg )
      if ValType( h ) == "H"
         cCmd := Lower( AllTrim( ErpToStr( hb_HGetDef( h, "cmd", "" ) ) ) )
         if Empty( cCmd )
            cCmd := Lower( AllTrim( ErpToStr( hb_HGetDef( h, "action", "" ) ) ) )
         endif
         if cCmd == "open" .or. cCmd == "openurl" .or. cCmd == "open-browser"
            cUrl := AllTrim( ErpToStr( hb_HGetDef( h, "url", "" ) ) )
         endif
      endif
   endif

   if ! Empty( cUrl )
      ErpShellOpenUrl( cUrl )
   endif

return nil
