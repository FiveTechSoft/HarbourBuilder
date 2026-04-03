// Form1.prg - Web Application sample for HarbourBuilder
//
// Demonstrates a desktop+web hybrid application concept using TWebServer.
// The desktop form acts as a control panel to start/stop a local web server
// and monitor incoming connections and requests.
//
// In production, TWebServer would bind to a TCP port and serve HTTP responses.
// This sample simulates the server behavior to illustrate the architecture:
//   - Desktop GUI as the admin control panel
//   - Web server running in a background thread
//   - Request routing to handler functions
//   - JSON API endpoints alongside HTML pages
//
// Routes:
//   /             -> Welcome page with navigation links
//   /api/status   -> JSON object with server information
//   /api/time     -> JSON object with current date and time

#include "hbbuilder.ch"

// ---------------------------------------------------------------------------
// Static variables for server state
// ---------------------------------------------------------------------------
static lRunning := .f.       // Whether the server is currently running
static nPort    := 8080      // Port number the server listens on
static aLog     := {}        // Array of log entry strings

// Control references shared between functions
static oEditUrl              // Edit showing the server URL
static oMemoLog              // Edit (multi-line) showing the server log
static oLblStatus            // Label showing current server status
static oBtnStart             // Start/Stop toggle button
static oBtnOpen              // Open in Browser button

// ---------------------------------------------------------------------------
// WebAppMain() - Build and activate the web server control panel
// ---------------------------------------------------------------------------
function WebAppMain()

   local oForm

   // --- Create the main form ---
   DEFINE FORM oForm TITLE "HbBuilder Web App" SIZE 600, 400 FONT "Segoe UI", 11

   // --- Title label ---
   @ 15, 20 SAY "Web Server Control Panel" OF oForm SIZE 350

   // --- URL display ---
   @ 55, 20 SAY "Server URL:" OF oForm SIZE 90
   @ 53, 120 GET oEditUrl VAR "http://localhost:8080" OF oForm SIZE 340, 24

   // --- Start / Stop button ---
   @ 50, 475 BUTTON oBtnStart PROMPT "Start Server" OF oForm SIZE 105, 28
   oBtnStart:OnClick := { || ToggleServer() }

   // --- Server log (multi-line edit used as a read-only memo) ---
   // In a full implementation this would be a TMemo control.
   // Here we use a TEdit and refresh its text to display log entries.
   @ 95, 20 SAY "Server Log:" OF oForm SIZE 200
   @ 115, 20 GET oMemoLog VAR "" OF oForm SIZE 560, 200

   // --- Status bar label at the bottom ---
   @ 335, 20 SAY oLblStatus PROMPT "Server: Stopped" OF oForm SIZE 300

   // --- Open in Browser button ---
   @ 330, 475 BUTTON oBtnOpen PROMPT "Open in Browser" OF oForm SIZE 105, 28
   oBtnOpen:OnClick := { || OpenBrowser() }

   // --- Show the form centered on screen ---
   ACTIVATE FORM oForm CENTERED

   // --- Clean up ---
   // If server is still running when the form closes, stop it
   if lRunning
      StopServer()
   endif

   oForm:Destroy()

return nil

// ---------------------------------------------------------------------------
// ToggleServer() - Start or stop the server based on current state
// ---------------------------------------------------------------------------
static function ToggleServer()

   if lRunning
      StopServer()
   else
      StartServer()
   endif

return nil

// ---------------------------------------------------------------------------
// StartServer() - Simulate starting the web server
//
// In production this would:
//   1. Create a TWebServer instance bound to nPort
//   2. Register route handlers for each URL pattern
//   3. Start listening in a background thread
//   4. Example:
//        oServer := TWebServer():New( nPort )
//        oServer:Route( "/",           { |oReq| HandleRequest( "/" ) } )
//        oServer:Route( "/api/status", { |oReq| HandleRequest( "/api/status" ) } )
//        oServer:Route( "/api/time",   { |oReq| HandleRequest( "/api/time" ) } )
//        oServer:Start()
// ---------------------------------------------------------------------------
static function StartServer()

   lRunning := .t.

   // Update button text to reflect new state
   oBtnStart:SetText( "Stop Server" )

   // Update status label
   oLblStatus:SetText( "Server: Running on port " + LTrim( Str( nPort ) ) )

   // Add startup log entries
   AddLog( "Server starting on port " + LTrim( Str( nPort ) ) + "..." )
   AddLog( "Route registered: / (Welcome page)" )
   AddLog( "Route registered: /api/status (Server info)" )
   AddLog( "Route registered: /api/time (Current time)" )
   AddLog( "Server started successfully. Listening for connections." )
   AddLog( "" )

   // Simulate a few incoming requests to show what the log looks like
   AddLog( "GET / from 127.0.0.1 -> 200 OK" )
   AddLog( "Response: " + LTrim( Str( Len( HandleRequest( "/" ) ) ) ) + " bytes (text/html)" )
   AddLog( "GET /api/status from 127.0.0.1 -> 200 OK" )
   AddLog( "Response: " + LTrim( Str( Len( HandleRequest( "/api/status" ) ) ) ) + " bytes (application/json)" )

return nil

// ---------------------------------------------------------------------------
// StopServer() - Simulate stopping the web server
//
// In production this would:
//   oServer:Stop()
//   oServer := nil
// ---------------------------------------------------------------------------
static function StopServer()

   lRunning := .f.

   // Update button text
   oBtnStart:SetText( "Start Server" )

   // Update status label
   oLblStatus:SetText( "Server: Stopped" )

   // Log the shutdown
   AddLog( "" )
   AddLog( "Server shutting down..." )
   AddLog( "All connections closed." )
   AddLog( "Server stopped." )

return nil

// ---------------------------------------------------------------------------
// AddLog() - Append a timestamped entry to the log and refresh the display
// ---------------------------------------------------------------------------
static function AddLog( cMessage )

   local cEntry

   if Empty( cMessage )
      cEntry := ""
   else
      cEntry := "[" + Time() + "] " + cMessage
   endif

   AAdd( aLog, cEntry )

   // Refresh the memo display with all log entries
   RefreshLog()

return nil

// ---------------------------------------------------------------------------
// RefreshLog() - Update the memo control with current log contents
// ---------------------------------------------------------------------------
static function RefreshLog()

   local cText := ""
   local n

   for n := 1 to Len( aLog )
      if n > 1
         cText += Chr( 13 ) + Chr( 10 )
      endif
      cText += aLog[ n ]
   next

   oMemoLog:SetText( cText )

return nil

// ---------------------------------------------------------------------------
// OpenBrowser() - Open the server URL in the default web browser
//
// Uses ShellExecute on Windows or xdg-open/open on Linux/macOS.
// In production TWebServer would serve actual pages at this URL.
// ---------------------------------------------------------------------------
static function OpenBrowser()

   local cUrl := "http://localhost:" + LTrim( Str( nPort ) )

   if !lRunning
      MsgInfo( "The server is not running." + Chr(10) + ;
               "Please start the server first." )
      return nil
   endif

   // Show what would be served at each route
   MsgInfo( "Opening " + cUrl + " in browser..." + Chr(10) + Chr(10) + ;
            "The server would respond with:" + Chr(10) + ;
            "  /            - Welcome HTML page" + Chr(10) + ;
            "  /api/status  - Server status JSON" + Chr(10) + ;
            "  /api/time    - Current time JSON" )

   // In production:
   //   hb_run( "start " + cUrl )         // Windows
   //   hb_run( "xdg-open " + cUrl )      // Linux
   //   hb_run( "open " + cUrl )           // macOS

   AddLog( "Browser opened: " + cUrl )

return nil

// ---------------------------------------------------------------------------
// HandleRequest() - Route handler that returns HTML or JSON for a given path
//
// cPath: the URL path requested by the client
//
// In production, TWebServer would call this function for each incoming
// HTTP request and send the returned string as the response body.
//
// Supported routes:
//   "/"           -> HTML welcome page with navigation links
//   "/api/status" -> JSON with server name, port, uptime, version
//   "/api/time"   -> JSON with current date and time
//   (other)       -> HTML 404 page
// ---------------------------------------------------------------------------
static function HandleRequest( cPath )

   local cHtml, cJson

   do case

   case cPath == "/"
      // ---------------------------------------------------------------
      // Welcome page: a simple HTML page with links to API endpoints
      // ---------------------------------------------------------------
      cHtml := '<!DOCTYPE html>' + Chr(10)
      cHtml += '<html><head><title>HbBuilder Web App</title>' + Chr(10)
      cHtml += '<style>' + Chr(10)
      cHtml += '  body { font-family: Segoe UI, Arial, sans-serif; margin: 40px; }' + Chr(10)
      cHtml += '  h1 { color: #2c3e50; }' + Chr(10)
      cHtml += '  a { color: #2980b9; text-decoration: none; }' + Chr(10)
      cHtml += '  a:hover { text-decoration: underline; }' + Chr(10)
      cHtml += '  .nav { margin: 20px 0; }' + Chr(10)
      cHtml += '  .nav a { display: inline-block; margin-right: 20px; padding: 8px 16px;' + Chr(10)
      cHtml += '           background: #3498db; color: white; border-radius: 4px; }' + Chr(10)
      cHtml += '  .nav a:hover { background: #2980b9; text-decoration: none; }' + Chr(10)
      cHtml += '</style></head>' + Chr(10)
      cHtml += '<body>' + Chr(10)
      cHtml += '<h1>Welcome to HbBuilder Web App</h1>' + Chr(10)
      cHtml += '<p>This web application is powered by Harbour and TWebServer.</p>' + Chr(10)
      cHtml += '<div class="nav">' + Chr(10)
      cHtml += '  <a href="/">Home</a>' + Chr(10)
      cHtml += '  <a href="/api/status">Server Status</a>' + Chr(10)
      cHtml += '  <a href="/api/time">Current Time</a>' + Chr(10)
      cHtml += '</div>' + Chr(10)
      cHtml += '<p>Server running on port ' + LTrim( Str( nPort ) ) + '</p>' + Chr(10)
      cHtml += '</body></html>'
      return cHtml

   case cPath == "/api/status"
      // ---------------------------------------------------------------
      // JSON endpoint: server status information
      // ---------------------------------------------------------------
      cJson := '{'
      cJson += '  "server": "HbBuilder Web App",'
      cJson += '  "status": "running",'
      cJson += '  "port": ' + LTrim( Str( nPort ) ) + ','
      cJson += '  "connections": ' + LTrim( Str( Len( aLog ) ) ) + ','
      cJson += '  "version": "1.0.0",'
      cJson += '  "engine": "Harbour + TWebServer"'
      cJson += '}'
      return cJson

   case cPath == "/api/time"
      // ---------------------------------------------------------------
      // JSON endpoint: current date and time
      // ---------------------------------------------------------------
      cJson := '{'
      cJson += '  "date": "' + DToC( Date() ) + '",'
      cJson += '  "time": "' + Time() + '",'
      cJson += '  "timestamp": "' + DToC( Date() ) + " " + Time() + '"'
      cJson += '}'
      return cJson

   otherwise
      // ---------------------------------------------------------------
      // 404 Not Found: unknown route
      // ---------------------------------------------------------------
      cHtml := '<!DOCTYPE html>' + Chr(10)
      cHtml += '<html><head><title>404 - Not Found</title></head>' + Chr(10)
      cHtml += '<body><h1>404 - Page Not Found</h1>' + Chr(10)
      cHtml += '<p>The requested path "' + cPath + '" was not found.</p>' + Chr(10)
      cHtml += '<p><a href="/">Return to Home</a></p>' + Chr(10)
      cHtml += '</body></html>'
      return cHtml

   endcase

return ""
