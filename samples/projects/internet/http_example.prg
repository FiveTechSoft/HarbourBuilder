// http_example.prg - Internet components demo
// Shows THttpClient and TWebServer

#include "hbbuilder.ch"

function Main()

   local oHttp, cResp, oSrv, i

   ? "=== Internet Components Example ==="
   ?

   // --- THttpClient ---
   ? "1. THttpClient - HTTP requests via curl:"
   ?

   oHttp := THttpClient():New( "https://httpbin.org" )
   oHttp:nTimeout := 10
   oHttp:SetHeader( "Accept", "application/json" )

   ? "   Base URL: " + oHttp:cBaseUrl
   ? "   Timeout: " + LTrim(Str(oHttp:nTimeout)) + "s"
   ? "   Headers: " + LTrim(Str(Len(oHttp:aHeaders)))
   ?

   ? "   GET /ip ..."
   cResp := oHttp:Get( "/ip" )
   if ! Empty( cResp )
      ? "   Response: " + Left( cResp, 60 )
   else
      ? "   (no response - check network)"
   endif
   ?

   // --- TWebServer ---
   ? "2. TWebServer - route configuration:"
   ?

   oSrv := TWebServer():New()
   oSrv:nPort := 8080
   oSrv:cRoot := "/tmp"

   oSrv:AddRoute( "GET", "/", { || "Hello from HarbourBuilder!" } )
   oSrv:AddRoute( "GET", "/api/status", { || '{"status":"ok","version":"1.0"}' } )
   oSrv:AddRoute( "POST", "/api/data", { || '{"result":"saved"}' } )

   ? "   Port: " + LTrim(Str(oSrv:nPort))
   ? "   Document root: " + oSrv:cRoot
   ? "   Routes configured: " + LTrim(Str(Len(oSrv:aRoutes)))
   ?

   ? "   Route table:"
   for i := 1 to Len( oSrv:aRoutes )
      ? "     " + PadR(oSrv:aRoutes[i][1], 6) + oSrv:aRoutes[i][2]
   next
   ?

   // Test static file serving
   MemoWrit( "/tmp/test_static.txt", "Static file content" )
   ? "   ServeStatic('test_static.txt'): " + oSrv:ServeStatic( "test_static.txt" )
   ? "   ServeStatic('missing.txt'): " + oSrv:ServeStatic( "missing.txt" )

   ?
   ? "=== Done ==="

return nil
