// Form1.prg
//--------------------------------------------------------------------

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
   METHOD RouteHome()
   METHOD RouteApiInfo()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "HIX App Demo"
   ::Left   := 976
   ::Top    := 251
   ::Width  := 900
   ::Height := 650

   COMPONENT ::oWebServer1 TYPE CT_WEBSERVER OF Self  // TWebServer @ 808,8
   ::oWebServer1:nPort := 8081
   @ 10, 10 BUTTON ::oBtnStart PROMPT "Start Server" OF Self SIZE 120, 32
   ::oBtnStart:oFont := ".AppleSystemUIFont,12"
   @ 10, 140 BUTTON ::oBtnStop PROMPT "Stop Server" OF Self SIZE 120, 32
   ::oBtnStop:oFont := ".AppleSystemUIFont,12"
   @ 10, 270 BUTTON ::oBtnBrowser PROMPT "Open in Browser" OF Self SIZE 130, 32
   ::oBtnBrowser:oFont := ".AppleSystemUIFont,12"
   @ 16, 410 SAY ::oLabel PROMPT "Server stopped" OF Self SIZE 360
   ::oLabel:oFont := ".AppleSystemUIFont,12"
   @ 50, 10 WEBVIEW ::oWebView1 OF Self SIZE 880, 580
   ::oWebView1:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oBtnStart:OnClick   := { || ::OnStartClick() }
   ::oBtnStop:Enabled    := .F.
   ::oBtnStop:OnClick    := { || ::OnStopClick() }
   ::oBtnBrowser:Enabled := .F.
   ::oBtnBrowser:OnClick := { || ::OnBrowserClick() }

return nil
//--------------------------------------------------------------------

METHOD OnStartClick() CLASS TForm1
   ::oWebServer1:aRoutes := {}
   ::oWebServer1:AddRoute( "GET", "/",         { || ::RouteHome() } )
   ::oWebServer1:AddRoute( "GET", "/api/info", { || ::RouteApiInfo() } )
   ::oWebServer1:Start()
   if ::oWebServer1:lRunning
      ::oLabel:Text := "Running: http://localhost:" + hb_ntos( ::oWebServer1:nPort ) + "/"
      ::oWebView1:Navigate( "http://localhost:" + hb_ntos( ::oWebServer1:nPort ) + "/" )
      ::oBtnStart:Enabled   := .F.
      ::oBtnStop:Enabled    := .T.
      ::oBtnBrowser:Enabled := .T.
   endif
return nil

METHOD OnStopClick() CLASS TForm1
   ::oWebServer1:Stop()
   ::oLabel:Text := "Server stopped"
   ::oWebView1:Navigate( "about:blank" )
   ::oBtnStart:Enabled   := .T.
   ::oBtnStop:Enabled    := .F.
   ::oBtnBrowser:Enabled := .F.
return nil

METHOD OnBrowserClick() CLASS TForm1
   MAC_ShellExec( "open http://localhost:" + hb_ntos( ::oWebServer1:nPort ) + "/" )
return nil

METHOD RouteHome() CLASS TForm1
   local aTickets := { ;
      { "TKT-001", "Login button broken",    "Open"        }, ;
      { "TKT-002", "Dashboard loads slowly", "In Progress" }, ;
      { "TKT-003", "Export CSV not working", "Open"        }, ;
      { "TKT-004", "Dark mode contrast",     "Closed"      } }
   local cUser := iif( Empty( UGet("user") ), "Guest", UGet("user") )
   local i

   UWrite( '<!DOCTYPE html><html><head><title>HIX App</title>' + ;
      '<style>body{font-family:sans-serif;padding:1.5em;background:#f8f8f8}' + ;
      'table{border-collapse:collapse;width:100%}' + ;
      'th,td{border:1px solid #ccc;padding:8px 12px;text-align:left}' + ;
      'th{background:#336699;color:#fff}.closed{color:#888}' + ;
      '</style></head><body>' + ;
      '<h2>HIX App &mdash; Welcome, ' + UHtmlEncode( cUser ) + '</h2>' + ;
      '<table><tr><th>ID</th><th>Title</th><th>Status</th></tr>' )
   for i := 1 to Len( aTickets )
      UWrite( '<tr' + iif( aTickets[i][3] == "Closed", ' class="closed"', '' ) + '>' + ;
         '<td>' + aTickets[i][1] + '</td>' + ;
         '<td>' + aTickets[i][2] + '</td>' + ;
         '<td>' + aTickets[i][3] + '</td></tr>' )
   next
   UWrite( '</table><p><a href="/api/info">/api/info</a></p></body></html>' )
return nil

METHOD RouteApiInfo() CLASS TForm1
   UWrite( hb_jsonEncode( { ;
      "server" => "HarbourBuilder/HIX", ;
      "time"   => Time(), ;
      "date"   => DToC( Date() ), ;
      "port"   => ::oWebServer1:nPort } ) )
return nil
