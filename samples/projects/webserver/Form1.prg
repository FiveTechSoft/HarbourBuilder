// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oWebServer1   // TWebServer
   DATA oBtnStart   // TButton
   DATA oBtnStop   // TButton
   DATA oBtnBrowser   // TButton
   DATA oLabel   // TLabel
   DATA oWebView1   // TWebView

   // Event handlers

   METHOD CreateForm()
   METHOD OnStartClick()
   METHOD OnStopClick()
   METHOD OnBrowserClick()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "WebServer Demo"
   ::nLeft   := 978
   ::nTop    := 278
   ::nWidth  := 803
   ::nHeight := 597

   COMPONENT ::oWebServer1 TYPE CT_WEBSERVER OF Self  // TWebServer @ 752,8
   ::oWebServer1:nPort := 8080

   @ 10, 10 BUTTON ::oBtnStart PROMPT "Start Server" OF Self SIZE 120, 32
   ::oBtnStart:oFont := ".AppleSystemUIFont,12"
   @ 10, 140 BUTTON ::oBtnStop PROMPT "Stop Server" OF Self SIZE 120, 32
   ::oBtnStop:oFont := ".AppleSystemUIFont,12"
   @ 10, 270 BUTTON ::oBtnBrowser PROMPT "Open in Browser" OF Self SIZE 130, 32
   ::oBtnBrowser:oFont := ".AppleSystemUIFont,12"
   @ 16, 410 SAY ::oLabel PROMPT "Server stopped" OF Self SIZE 300
   ::oLabel:oFont := ".AppleSystemUIFont,12"
   @ 50, 10 WEBVIEW ::oWebView1 OF Self SIZE 780, 530
   ::oWebView1:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oBtnStart:OnClick   := { || ::OnStartClick() }
   ::oBtnStop:lEnabled    := .F.
   ::oBtnStop:OnClick    := { || ::OnStopClick() }
   ::oBtnBrowser:lEnabled := .F.
   ::oBtnBrowser:OnClick := { || ::OnBrowserClick() }

return nil
//--------------------------------------------------------------------

METHOD OnStartClick() CLASS TForm1

   // Register routes before starting
   ::oWebServer1:aRoutes := {}
   ::oWebServer1:AddRoute( "GET", "/", {|| ;
      UWrite( '<!DOCTYPE html><html><head><title>HbBuilder WebServer</title>' + ;
              '<style>body{font-family:sans-serif;padding:2em;background:#f5f5f5}' + ;
              'h1{color:#336699}</style></head><body>' + ;
              '<h1>HbBuilder TWebServer</h1>' + ;
              '<p>Time: <b>' + Time() + '</b></p>' + ;
              '<p><a href="/api/time">/api/time</a></p>' + ;
              '</body></html>' ) } )

   ::oWebServer1:AddRoute( "GET", "/api/time", {|| ;
      UWrite( '{"time":"' + Time() + '","date":"' + DToC( Date() ) + '"}' ) } )

   ::oWebServer1:Start()
   if ::oWebServer1:lRunning
      ::oLabel:cText := "Running: http://localhost:" + hb_ntos( ::oWebServer1:nPort ) + "/"
      ::oWebView1:Navigate( "http://localhost:" + hb_ntos( ::oWebServer1:nPort ) + "/" )
      ::oBtnStart:lEnabled   := .F.
      ::oBtnStop:lEnabled    := .T.
      ::oBtnBrowser:lEnabled := .T.
   endif

return nil

METHOD OnStopClick() CLASS TForm1
   ::oWebServer1:Stop()
   ::oLabel:cText := "Server stopped"
   ::oWebView1:Navigate( "about:blank" )
   ::oBtnStart:lEnabled   := .T.
   ::oBtnStop:lEnabled    := .F.
   ::oBtnBrowser:lEnabled := .F.
return nil

METHOD OnBrowserClick() CLASS TForm1
   MAC_ShellExec( "open http://localhost:" + hb_ntos( ::oWebServer1:nPort ) + "/" )
return nil
