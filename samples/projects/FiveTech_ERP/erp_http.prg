// erp_http.prg — portable multi-thread HTTP for FiveTech_ERP
//--------------------------------------------------------------------
#include "hbsocket.ch"

static s_lRun := .F.
static s_hListen := NIL
static s_nPort := 2222
static s_cErr := ""
static s_mtx := NIL
static s_hSess := { => }

//--------------------------------------------------------------------
function ErpHttpStart( nPort, cMsg )

   local pTh

   if nPort == NIL
      nPort := 2222
   endif
   cMsg := ""

   if s_lRun
      cMsg := "already running"
      return .T.
   endif

   s_nPort := nPort
   s_cErr := ""
   if s_mtx == NIL
      s_mtx := hb_mutexCreate()
   endif
   s_lRun := .T.

   pTh := hb_threadStart( @ErpHttpListen(), nPort )
   if Empty( pTh )
      s_lRun := .F.
      cMsg := "thread start failed"
      return .F.
   endif
   hb_threadDetach( pTh )

   // wait briefly for bind
   hb_idleSleep( 0.3 )
   if ! Empty( s_cErr )
      cMsg := s_cErr
      s_lRun := .F.
      return .F.
   endif

return .T.

//--------------------------------------------------------------------
function ErpHttpStop()
   s_lRun := .F.
   if ! Empty( s_hListen )
      hb_socketClose( s_hListen )
      s_hListen := NIL
   endif
return nil

//--------------------------------------------------------------------
static function ErpHttpListen( nPort )

   local hSock

   s_hListen := hb_socketOpen()
   if Empty( s_hListen )
      s_cErr := "socket open error"
      s_lRun := .F.
      return nil
   endif

   hb_socketSetReuseAddr( s_hListen, .T. )
   if ! hb_socketBind( s_hListen, { HB_SOCKET_AF_INET, "0.0.0.0", nPort } )
      s_cErr := "bind error port " + hb_ntos( nPort )
      hb_socketClose( s_hListen )
      s_hListen := NIL
      s_lRun := .F.
      return nil
   endif

   if ! hb_socketListen( s_hListen )
      s_cErr := "listen error"
      hb_socketClose( s_hListen )
      s_hListen := NIL
      s_lRun := .F.
      return nil
   endif

   s_cErr := ""
   while s_lRun
      hSock := hb_socketAccept( s_hListen,, 400 )
      if ! Empty( hSock )
         hb_threadDetach( hb_threadStart( @ErpHttpClient(), hSock ) )
      endif
   enddo

   if ! Empty( s_hListen )
      hb_socketClose( s_hListen )
      s_hListen := NIL
   endif
return nil

//--------------------------------------------------------------------
static function ErpHttpClient( hSock )

   local cReq := "", cBuf, nLen, nTries := 0, nHdr, nCL
   local hHdr, cBody := "", cMethod, cPath, cQuery, cResp
   local cLine, aTok

   while nTries < 200
      cBuf := Space( 8192 )
      nLen := hb_socketRecv( hSock, @cBuf,,, 200 )
      if nLen > 0
         cReq += Left( cBuf, nLen )
         nHdr := At( Chr( 13 ) + Chr( 10 ) + Chr( 13 ) + Chr( 10 ), cReq )
         if nHdr > 0
            hHdr := ErpParseHdr( Left( cReq, nHdr - 1 ) )
            nCL := Val( hb_HGetDef( hHdr, "CONTENT-LENGTH", "0" ) )
            cBody := SubStr( cReq, nHdr + 4 )
            while Len( cBody ) < nCL
               cBuf := Space( 8192 )
               nLen := hb_socketRecv( hSock, @cBuf,,, 400 )
               if nLen <= 0
                  exit
               endif
               cBody += Left( cBuf, nLen )
            enddo
            cBody := Left( cBody, nCL )
            exit
         endif
      elseif nLen == 0
         exit
      endif
      nTries++
   enddo

   if Empty( cReq )
      hb_socketClose( hSock )
      return nil
   endif

   cLine := Left( cReq, At( Chr( 13 ) + Chr( 10 ), cReq + Chr( 13 ) + Chr( 10 ) ) - 1 )
   aTok := hb_ATokens( cLine, " " )
   cMethod := iif( Len( aTok ) >= 1, Upper( aTok[ 1 ] ), "GET" )
   cPath := iif( Len( aTok ) >= 2, aTok[ 2 ], "/" )
   cQuery := ""
   if "?" $ cPath
      cQuery := SubStr( cPath, At( "?", cPath ) + 1 )
      cPath := Left( cPath, At( "?", cPath ) - 1 )
   endif

   cResp := ErpDispatch( cMethod, cPath, cQuery, cBody, hHdr )
   // FWH-style full send. Use hb_BLen/hb_BSubStr — with UTF-8 strings Len()
   // counts characters, not bytes; Content-Length/send must be byte-accurate
   // or the browser cuts the JSON mid-object (error at pos 761 with €).
   while hb_BLen( cResp ) > 0
      nLen := hb_socketSend( hSock, cResp )
      if nLen == NIL .or. nLen <= 0
         exit
      endif
      cResp := hb_BSubStr( cResp, nLen + 1 )
   enddo
   hb_socketClose( hSock )
return nil

//--------------------------------------------------------------------
static function ErpParseHdr( cHdr )

   local h := { => }, aLines, cL, n, cN, cV

   aLines := hb_ATokens( StrTran( cHdr, Chr( 13 ), "" ), Chr( 10 ) )
   for n := 2 to Len( aLines )
      cL := aLines[ n ]
      if ":" $ cL
         cN := Upper( AllTrim( Left( cL, At( ":", cL ) - 1 ) ) )
         cV := AllTrim( SubStr( cL, At( ":", cL ) + 1 ) )
         h[ cN ] := cV
      endif
   next
return h

//--------------------------------------------------------------------
// {"ok":true,"key":"<key>","doc":<raw file JSON>}
// Key is restricted to safe meta id chars; body is never re-encoded.
static function ErpMetaApiEnvelope( cKey )

   local cRaw, cHead, cOut

   cKey := AllTrim( cKey )
   cRaw := ErpMetaGetRaw( cKey )
   if Empty( cRaw )
      return hb_jsonEncode( { "ok" => .F., "msg" => "Unknown meta key", "key" => cKey } )
   endif

   // ASCII-only head/tail — avoid hb_jsonEncode of the UTF-8 document.
   cHead := '{"ok":true,"key":"' + cKey + '","doc":'
   cOut := cHead
   cOut := cOut + cRaw
   cOut := cOut + "}"
return cOut

//--------------------------------------------------------------------
// {"ok":true,"key":"<key>","rows":<raw rows array from file>}
static function ErpDatasetApiEnvelope( cKey )

   local cRaw, cRows, cOut

   cKey := AllTrim( cKey )
   cRaw := ErpMetaGetRaw( cKey )
   if Empty( cRaw )
      return hb_jsonEncode( { "ok" => .F., "msg" => "Dataset not found", "key" => cKey } )
   endif

   cRows := ErpJsonTopFieldRaw( cRaw, "rows" )
   if Empty( cRows )
      return hb_jsonEncode( { "ok" => .F., "msg" => "Dataset not found", "key" => cKey } )
   endif

   cOut := '{"ok":true,"key":"' + cKey + '","rows":'
   cOut := cOut + cRows
   cOut := cOut + "}"
return cOut

//--------------------------------------------------------------------
static function ErpHttpOk( cBody, cType )

   local cHdr, nBody

   if cType == NIL .or. Empty( cType )
      cType := "text/html; charset=utf-8"
   endif
   if cBody == NIL
      cBody := ""
   endif
   // Byte length (not character length) for HTTP Content-Length
   nBody := hb_BLen( cBody )
   cHdr := "HTTP/1.1 200 OK" + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Type: " + cType + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Length: " + hb_ntos( nBody ) + Chr( 13 ) + Chr( 10 ) + ;
       "Connection: close" + Chr( 13 ) + Chr( 10 ) + ;
       "Access-Control-Allow-Origin: *" + Chr( 13 ) + Chr( 10 ) + ;
       "Cache-Control: no-store" + Chr( 13 ) + Chr( 10 ) + ;
       Chr( 13 ) + Chr( 10 )
return cHdr + cBody

//--------------------------------------------------------------------
static function ErpDispatch( cMethod, cPath, cQuery, cBody, hHdr )

   local cOut, hDoc, aItems, cKey, hQ, cUser, cPass, cTok, hSess
   local cFile, cMime, cCookie, cDate, cAction, cArg, nSel

   cPath := Lower( AllTrim( cPath ) )
   if Empty( cPath )
      cPath := "/"
   endif

   // Session from FWH cookie DWSESS
   cCookie := ""
   if ValType( hHdr ) == "H"
      cCookie := hb_HGetDef( hHdr, "COOKIE", "" )
   endif
   cTok := ErpCookieGet( cCookie, "DWSESS" )
   hSess := ErpSessGet( cTok )

   // --- pages (same routes as FWH DesktopWeb login.prg) ---
   if cMethod == "GET" .and. ( cPath == "/" .or. cPath == "/login" .or. cPath == "/index.html" )
      return ErpHttpOk( ErpFwhLoginHtml(), "text/html; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/dashboard"
      if Empty( hSess )
         return ErpHttpRedirect( "/" )
      endif
      nSel := Val( ErpToStr( hb_HGetDef( hSess, "sel", "2" ) ) )
      if nSel < 1
         nSel := 2
      endif
      return ErpHttpOk( ErpFwhDashboardHtml( ;
         ErpToStr( hb_HGetDef( hSess, "user", "" ) ), ;
         ErpToStr( hb_HGetDef( hSess, "workDate", DToC( Date() ) ) ), ;
         nSel ), "text/html; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/logout"
      ErpSessDel( cTok )
      return ErpHttpRedirect( "/", "DWSESS=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0" )
   endif

   // --- API (FWH-compatible) ---
   if cMethod == "GET" .and. cPath == "/api/meta"
      hQ := ErpQuery( cQuery )
      cKey := AllTrim( hb_HGetDef( hQ, "key", "" ) )
      if Empty( cKey )
         aItems := ErpMetaCatalog()
         cOut := hb_jsonEncode( { "ok" => .T., "count" => Len( aItems ), "items" => aItems } )
      else
         cOut := ErpMetaApiEnvelope( cKey )
      endif
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/api/meta/fields"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      hQ := ErpQuery( cQuery )
      cKey := AllTrim( hb_HGetDef( hQ, "key", "" ) )
      cOut := ErpMetaFieldsJson( cKey )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/api/dataset"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      hQ := ErpQuery( cQuery )
      cKey := AllTrim( hb_HGetDef( hQ, "key", "" ) )
      cOut := ErpDatasetApiEnvelope( cKey )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/api/patients"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      // Same data as dataset patients (FWH PatientSearchJson shape simplified)
      cOut := ErpDatasetApiEnvelope( "data.patients" )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/api/balances"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      cOut := ErpDatasetApiEnvelope( "data.balances" )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "POST" .and. cPath == "/api/login"
      cUser := ""
      cPass := ""
      cDate := ""
      if "{" $ cBody
         hDoc := { => }
         hb_jsonDecode( cBody, @hDoc )
         if ValType( hDoc ) == "H"
            cUser := AllTrim( ErpToStr( hb_HGetDef( hDoc, "user", "" ) ) )
            cPass := AllTrim( ErpToStr( hb_HGetDef( hDoc, "password", "" ) ) )
            cDate := AllTrim( ErpToStr( hb_HGetDef( hDoc, "workDate", ;
               hb_HGetDef( hDoc, "workdate", "" ) ) ) )
         endif
      else
         hQ := ErpQuery( cBody )
         cUser := AllTrim( hb_HGetDef( hQ, "user", "" ) )
         cPass := AllTrim( hb_HGetDef( hQ, "password", "" ) )
         cDate := AllTrim( hb_HGetDef( hQ, "workDate", ;
            hb_HGetDef( hQ, "workdate", "" ) ) )
      endif
      if Empty( cDate )
         cDate := DToC( Date() )
      endif
      // Case-insensitive user like FWH
      if ( Upper( cUser ) == "ADMIN" .and. cPass == "1234" ) .or. ;
            ( Upper( cUser ) == "DEMO" .and. cPass == "demo" )
         cTok := hb_MD5( cUser + cDate + Time() + hb_ntos( Seconds() ) )
         if s_mtx != NIL
            hb_mutexLock( s_mtx )
         endif
         s_hSess[ cTok ] := { "user" => cUser, "workDate" => cDate, "sel" => 2 }
         if s_mtx != NIL
            hb_mutexUnlock( s_mtx )
         endif
         cOut := hb_jsonEncode( { "ok" => .T., "msg" => "Welcome, " + cUser, "user" => cUser } )
         return ErpHttpOkCookie( cOut, "application/json; charset=utf-8", ;
            "DWSESS=" + cTok + "; Path=/; HttpOnly; SameSite=Lax" )
      endif
      cOut := hb_jsonEncode( { "ok" => .F., "msg" => "Invalid credentials (admin/1234 or demo/demo)" } )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "POST" .and. cPath == "/api/cmd"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated", ;
            "redirect" => "/" } ), "application/json; charset=utf-8" )
      endif
      hQ := ErpQuery( cBody )
      cAction := Lower( AllTrim( hb_HGetDef( hQ, "action", "" ) ) )
      cArg := AllTrim( hb_HGetDef( hQ, "a1", "" ) )
      if cAction == "logout"
         ErpSessDel( cTok )
         return ErpHttpOkCookie( hb_jsonEncode( { "ok" => .T., "redirect" => "/" } ), ;
            "application/json; charset=utf-8", ;
            "DWSESS=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0" )
      elseif cAction == "select"
         nSel := Max( 1, Val( cArg ) )
         hSess[ "sel" ] := nSel
         ErpSessPut( cTok, hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "sel" => nSel } ), ;
            "application/json; charset=utf-8" )
      elseif cAction == "nav"
         return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "nav" => cArg } ), ;
            "application/json; charset=utf-8" )
      elseif cAction == "filter"
         return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "filter" => cArg } ), ;
            "application/json; charset=utf-8" )
      endif
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "toast" => "Action: " + cArg } ), ;
         "application/json; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/api/verticals"
      cOut := hb_jsonEncode( { "ok" => .T., "items" => { "clinic", "services", "retail" }, ;
         "current" => ErpToStr( hb_HGetDef( ErpMetaGet( "app" ), "vertical", "" ) ) } )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   // static www assets
   if Left( cPath, 1 ) == "/"
      cFile := hb_DirBase() + "www" + StrTran( cPath, "/", hb_ps() )
      if File( cFile )
         cMime := "text/plain"
         if Right( Lower( cFile ), 5 ) == ".html" ; cMime := "text/html; charset=utf-8" ; endif
         if Right( Lower( cFile ), 3 ) == ".js"   ; cMime := "application/javascript" ; endif
         if Right( Lower( cFile ), 4 ) == ".css"  ; cMime := "text/css" ; endif
         if Right( Lower( cFile ), 5 ) == ".json" ; cMime := "application/json" ; endif
         return ErpHttpOk( MemoRead( cFile ), cMime )
      endif
   endif

   cOut := "<h1>404</h1><p>" + cPath + "</p>"
return "HTTP/1.1 404 Not Found" + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Type: text/html; charset=utf-8" + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Length: " + hb_ntos( hb_BLen( cOut ) ) + Chr( 13 ) + Chr( 10 ) + ;
       "Connection: close" + Chr( 13 ) + Chr( 10 ) + Chr( 13 ) + Chr( 10 ) + cOut

//--------------------------------------------------------------------
// Extract top-level JSON field value as raw text (array/object/string/number).
// Avoids hb_jsonEncode so UTF-8 in nested values is preserved.
static function ErpJsonTopFieldRaw( cJson, cName )

   local cNeedle, nPos, n, nLen, cCh, nDepth, lInStr, lEsc, cStart

   if Empty( cJson ) .or. Empty( cName )
      return ""
   endif

   cNeedle := '"' + cName + '"'
   nPos := At( cNeedle, cJson )
   if nPos == 0
      return ""
   endif

   n := nPos + Len( cNeedle )
   nLen := Len( cJson )
   // skip whitespace and colon
   while n <= nLen
      cCh := SubStr( cJson, n, 1 )
      if cCh $ " " + Chr( 9 ) + Chr( 10 ) + Chr( 13 )
         n++
         loop
      endif
      if cCh == ":"
         n++
         exit
      endif
      // not a proper field start
      return ""
   enddo
   while n <= nLen
      cCh := SubStr( cJson, n, 1 )
      if cCh $ " " + Chr( 9 ) + Chr( 10 ) + Chr( 13 )
         n++
         loop
      endif
      exit
   enddo
   if n > nLen
      return ""
   endif

   cStart := SubStr( cJson, n, 1 )
   if cStart $ "[{"
      nDepth := 0
      lInStr := .F.
      lEsc := .F.
      nPos := n
      while n <= nLen
         cCh := SubStr( cJson, n, 1 )
         if lInStr
            if lEsc
               lEsc := .F.
            elseif cCh == "\"
               lEsc := .T.
            elseif cCh == '"'
               lInStr := .F.
            endif
         else
            if cCh == '"'
               lInStr := .T.
            elseif cCh == "[" .or. cCh == "{"
               nDepth++
            elseif cCh == "]" .or. cCh == "}"
               nDepth--
               if nDepth == 0
                  return SubStr( cJson, nPos, n - nPos + 1 )
               endif
            endif
         endif
         n++
      enddo
      return ""
   endif

   if cStart == '"'
      lEsc := .F.
      nPos := n
      n++
      while n <= nLen
         cCh := SubStr( cJson, n, 1 )
         if lEsc
            lEsc := .F.
         elseif cCh == "\"
            lEsc := .T.
         elseif cCh == '"'
            return SubStr( cJson, nPos, n - nPos + 1 )
         endif
         n++
      enddo
      return ""
   endif

   // number, true, false, null
   nPos := n
   while n <= nLen
      cCh := SubStr( cJson, n, 1 )
      if cCh $ ",}]" .or. cCh $ " " + Chr( 9 ) + Chr( 10 ) + Chr( 13 )
         exit
      endif
      n++
   enddo
return AllTrim( SubStr( cJson, nPos, n - nPos ) )

//--------------------------------------------------------------------
static function ErpQuery( cQ )

   local h := { => }, aP, cP, cN, cV, n

   if Empty( cQ )
      return h
   endif
   aP := hb_ATokens( cQ, "&" )
   for n := 1 to Len( aP )
      cP := aP[ n ]
      if "=" $ cP
         cN := Lower( AllTrim( Left( cP, At( "=", cP ) - 1 ) ) )
         cV := AllTrim( SubStr( cP, At( "=", cP ) + 1 ) )
         cV := ErpUrlDecode( cV )
         h[ cN ] := cV
      endif
   next
return h

//--------------------------------------------------------------------
// FWH login.html (extracted from DesktopWeb login.prg LoginHtml)
static function ErpFwhLoginHtml()

   local cFile := hb_DirBase() + "www" + hb_ps() + "login.html"
   if File( cFile )
      return MemoRead( cFile )
   endif
return "<!DOCTYPE html><html><body><h1>login.html missing</h1>" + ;
       "<p>Run _extract_fwh_html.py</p></body></html>"

//--------------------------------------------------------------------
// FWH dashboard.html + same placeholders as DesktopWeb DashboardHtml()
static function ErpFwhDashboardHtml( cUser, cWorkDate, nSel )

   local cFile := hb_DirBase() + "www" + hb_ps() + "dashboard.html"
   local cHtml, cRaw, cAv

   if ! File( cFile )
      return "<!DOCTYPE html><html><body><h1>dashboard.html missing</h1></body></html>"
   endif

   cHtml := MemoRead( cFile )
   if Empty( cUser )
      cUser := "user"
   endif
   if Empty( cWorkDate )
      cWorkDate := DToC( Date() )
   endif
   if nSel == NIL .or. nSel < 1
      nSel := 2
   endif

   cAv := Upper( Left( AllTrim( cUser ), 2 ) )
   if Empty( cAv )
      cAv := "??"
   endif

   cHtml := StrTran( cHtml, "__APPVER__", "1.0.0" )
   cHtml := StrTran( cHtml, "__USER__", cUser )
   cHtml := StrTran( cHtml, "__WORKDATE__", cWorkDate )
   cHtml := StrTran( cHtml, "__AVATAR__", cAv )
   cHtml := StrTran( cHtml, "__SEL__", hb_ntos( nSel ) )
   cHtml := StrTran( cHtml, "__APPTDATA__", ErpApptDataJson() )
   cHtml := StrTran( cHtml, "__IS_ADMIN__", iif( Upper( AllTrim( cUser ) ) == "ADMIN", "true", "false" ) )
   cHtml := StrTran( cHtml, "__BODY_ADMIN_CLASS__", iif( Upper( AllTrim( cUser ) ) == "ADMIN", "is-admin", "" ) )
   cHtml := StrTran( cHtml, "__HTTP_PORT__", hb_ntos( s_nPort ) )

   // Raw meta JSON embeds (avoid hb_jsonEncode UTF-8 truncation)
   cRaw := ErpMetaGetRaw( "app" )
   if Empty( cRaw )
      cRaw := "{}"
   endif
   cHtml := StrTran( cHtml, "__APP_JSON__", cRaw )

   cRaw := ErpMetaGetRaw( "modules" )
   if Empty( cRaw )
      cRaw := "{}"
   endif
   cHtml := StrTran( cHtml, "__MODULES_JSON__", cRaw )

   cRaw := ErpMetaGetRaw( "lookup.patients" )
   if Empty( cRaw )
      cRaw := "{}"
   endif
   cHtml := StrTran( cHtml, "__LOOKUP_PATIENTS_JSON__", cRaw )

   cRaw := ErpMetaGetRaw( "screen.balance" )
   if Empty( cRaw )
      cRaw := "{}"
   endif
   cHtml := StrTran( cHtml, "__SCREEN_BALANCE_JSON__", cRaw )

return cHtml

//--------------------------------------------------------------------
static function ErpApptDataJson()
   // Same seed rows as FWH ApptDataJson() — appointments grid demo data
return '[{"id":1,"date":"17/05/2025","time":"17:17","local":"MM","name":"ALEX RIVERA","type":"Health","tel":"9650","claim":"","esc":"","comple":"","status":"NORA","attention":"5","pag":"1"},' + ;
   '{"id":2,"date":"17/05/2025","time":"16:19","local":"RECODE","name":"ALEX RIVERA","type":"Task","tel":"9650","claim":"","esc":"","comple":"","status":"KIM","attention":"5","pag":"1"},' + ;
   '{"id":3,"date":"17/05/2025","time":"16:17","local":"UPAR","name":"JORDAN BLAKE","type":"Message","tel":"9650","claim":"","esc":"","comple":"","status":"AVA","attention":"5","pag":"1"},' + ;
   '{"id":4,"date":"16/05/2025","time":"11:05","local":"SOLID","name":"CASEY MORGAN","type":"Task","tel":"9025","claim":"","esc":"","comple":"","status":"KIM","attention":"5","pag":"1"},' + ;
   '{"id":5,"date":"12/05/2025","time":"18:31","local":"UPAR","name":"RILEY QUINN","type":"Health","tel":"9814","claim":"","esc":"","comple":"","status":"AVA","attention":"5","pag":"1"}]'

//--------------------------------------------------------------------
static function ErpMetaFieldsJson( cKey )

   local cRaw, cRows, hDoc := { => }, aFields := {}, aRows, hRow, aKeys, cF

   cRaw := ErpMetaGetRaw( cKey )
   if Empty( cRaw )
      return hb_jsonEncode( { "ok" => .F., "msg" => "key must be data.*", "fields" => {} } )
   endif
   hb_jsonDecode( cRaw, @hDoc )
   if ValType( hDoc ) != "H" .or. ! hb_HHasKey( hDoc, "rows" )
      return hb_jsonEncode( { "ok" => .F., "msg" => "no rows", "fields" => {} } )
   endif
   aRows := hDoc[ "rows" ]
   if ValType( aRows ) == "A" .and. Len( aRows ) > 0 .and. ValType( aRows[ 1 ] ) == "H"
      aKeys := hb_HKeys( aRows[ 1 ] )
      for each cF in aKeys
         AAdd( aFields, cF )
      next
   endif
return hb_jsonEncode( { "ok" => .T., "key" => cKey, "fields" => aFields } )

//--------------------------------------------------------------------
static function ErpCookieGet( cCookie, cName )

   local aP, cP, cN, cV, n

   cCookie := AllTrim( ErpToStr( cCookie ) )
   cName := AllTrim( cName )
   if Empty( cCookie ) .or. Empty( cName )
      return ""
   endif
   aP := hb_ATokens( cCookie, ";" )
   for n := 1 to Len( aP )
      cP := AllTrim( aP[ n ] )
      if "=" $ cP
         cN := AllTrim( Left( cP, At( "=", cP ) - 1 ) )
         cV := AllTrim( SubStr( cP, At( "=", cP ) + 1 ) )
         if Upper( cN ) == Upper( cName )
            return cV
         endif
      endif
   next
return ""

//--------------------------------------------------------------------
static function ErpSessGet( cTok )

   local h := NIL
   if Empty( cTok )
      return NIL
   endif
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   if hb_HHasKey( s_hSess, cTok )
      h := s_hSess[ cTok ]
   endif
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
return h

//--------------------------------------------------------------------
static function ErpSessPut( cTok, h )
   if Empty( cTok ) .or. ValType( h ) != "H"
      return nil
   endif
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   s_hSess[ cTok ] := h
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
return nil

//--------------------------------------------------------------------
static function ErpSessDel( cTok )
   if Empty( cTok )
      return nil
   endif
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   if hb_HHasKey( s_hSess, cTok )
      hb_HDel( s_hSess, cTok )
   endif
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
return nil

//--------------------------------------------------------------------
static function ErpHttpOkCookie( cBody, cType, cSetCookie )

   local cHdr, nBody

   if cType == NIL .or. Empty( cType )
      cType := "application/json; charset=utf-8"
   endif
   if cBody == NIL
      cBody := ""
   endif
   nBody := hb_BLen( cBody )
   cHdr := "HTTP/1.1 200 OK" + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Type: " + cType + Chr( 13 ) + Chr( 10 ) + ;
       "Set-Cookie: " + cSetCookie + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Length: " + hb_ntos( nBody ) + Chr( 13 ) + Chr( 10 ) + ;
       "Connection: close" + Chr( 13 ) + Chr( 10 ) + ;
       "Cache-Control: no-store" + Chr( 13 ) + Chr( 10 ) + ;
       Chr( 13 ) + Chr( 10 )
return cHdr + cBody

//--------------------------------------------------------------------
static function ErpHttpRedirect( cUrl, cSetCookie )

   local cHdr

   if Empty( cUrl )
      cUrl := "/"
   endif
   cHdr := "HTTP/1.1 302 Found" + Chr( 13 ) + Chr( 10 ) + ;
       "Location: " + cUrl + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Length: 0" + Chr( 13 ) + Chr( 10 ) + ;
       "Connection: close" + Chr( 13 ) + Chr( 10 )
   if ! Empty( cSetCookie )
      cHdr += "Set-Cookie: " + cSetCookie + Chr( 13 ) + Chr( 10 )
   endif
   cHdr += Chr( 13 ) + Chr( 10 )
return cHdr

//--------------------------------------------------------------------
function ErpUrlDecode( c )

   local cOut := "", i := 1, cH, n

   c := StrTran( ErpToStr( c ), "+", " " )
   while i <= Len( c )
      if SubStr( c, i, 1 ) == "%" .and. i + 2 <= Len( c )
         cH := Upper( SubStr( c, i + 1, 2 ) )
         n := ( At( Left( cH, 1 ), "0123456789ABCDEF" ) - 1 ) * 16 + ;
              ( At( Right( cH, 1 ), "0123456789ABCDEF" ) - 1 )
         if n >= 0
            cOut += Chr( n )
         endif
         i += 3
      else
         cOut += SubStr( c, i, 1 )
         i++
      endif
   enddo
return cOut
