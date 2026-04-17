#include "hbbuilder.ch"

CLASS Form1 FROM TForm
   DATA oServer
   DATA oBtnStart
   DATA oBtnStop
   DATA oLabel
   DATA oWebView

   METHOD New() CONSTRUCTOR
   METHOD OnStartClick()
   METHOD OnStopClick()
ENDCLASS

METHOD New() CLASS Form1
   local cWwwDir

   ::Super:New()
   ::cTitle := "WebServer Demo"
   ::nWidth  := 800
   ::nHeight := 600

   // Resolve www/ path relative to project directory
   cWwwDir := hb_DirBase() + "www"

   // TWebServer component
   ::oServer := TWebServer():New()
   ::oServer:nPort := 8080
   ::oServer:cRoot := cWwwDir

   // Register routes
   ::oServer:AddRoute( "GET", "/", {|| } )   // served as static www/index.html

   ::oServer:AddRoute( "GET", "/api/time", {|| ;
      USetStatusCode( 200 ) ; ;
      UAddHeader( "Content-Type", "application/json" ) ; ;
      UWrite( '{"time":"' + Time() + '"}' ) } )

   ::oServer:AddRoute( "POST", "/api/echo", {|| ;
      UWrite( '{"body":' + hb_jsonEncode( UPost() ) + '}' ) } )

   // UI: Start button
   ::oBtnStart := TButton():New( 10, 10, 120, 32, "Start Server", Self )
   ::oBtnStart:bOnClick := { || ::OnStartClick() }

   // UI: Stop button
   ::oBtnStop := TButton():New( 140, 10, 120, 32, "Stop Server", Self )
   ::oBtnStop:bOnClick := { || ::OnStopClick() }
   ::oBtnStop:lEnabled := .F.

   // URL label
   ::oLabel := TLabel():New( 270, 16, 300, 20, "Server stopped", Self )

   // WebView
   ::oWebView := TWebView():New( 10, 50, 780, 530, Self )
   ::oWebView:cURL := "about:blank"

return Self

METHOD OnStartClick() CLASS Form1
   ::oServer:Start()
   if ::oServer:lRunning
      ::oLabel:cText := "Running: http://localhost:8080/"
      ::oWebView:cURL := "http://localhost:8080/"
      ::oBtnStart:lEnabled := .F.
      ::oBtnStop:lEnabled  := .T.
   endif
return nil

METHOD OnStopClick() CLASS Form1
   ::oServer:Stop()
   ::oLabel:cText := "Server stopped"
   ::oBtnStart:lEnabled := .T.
   ::oBtnStop:lEnabled  := .F.
return nil
