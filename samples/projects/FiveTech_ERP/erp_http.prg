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

   // Selectable data layer: auto-generate missing DBF tables when
   // database.driver is dbfcdx/openads (no-op for the default json driver)
   ErpDbEnsureTables()

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

   // same codepage as the main thread (Project1): the DBF RDD translates
   // field data with the THREAD codepage, and the meta JSON is UTF-8
   hb_cdpSelect( "UTF8EX" )

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
            // Keep the real received length: Left() pads with spaces when the
            // body arrived short (truncated POST), corrupting the JSON tail.
            if Len( cBody ) > nCL
               cBody := Left( cBody, nCL )
            endif
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
// POST /api/meta — runtime form designer (admin only).
// Body: { "key":"app"|"modules"|"screen.x"|"lookup.x"|"report.x",
//         "doc":{...}, "writeFile":true|false }
//   or: { "key":"screen.x"|"lookup.x"|"report.x", "action":"delete" }
// Resp: { "ok":true, "key":..., "path":... } or { "ok":false, "msg"/"error":... }
static function ErpApiMetaPost( cBody, hSess )

   local hReq := { => }, cKey, hDoc, lWrite, xW, cAction
   local cFull, cJson, lOk, cOut, cDir, nEr

   if Empty( hSess )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated", ;
         "error" => "Not authenticated" } ), "application/json; charset=utf-8" )
   endif
   if ! ErpSessIsAdmin( hSess )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Admin only", ;
         "error" => "Admin only" } ), "application/json; charset=utf-8" )
   endif

   if "{" $ cBody
      hb_jsonDecode( cBody, @hReq )
   endif
   if ValType( hReq ) != "H" .or. Empty( hb_HKeys( hReq ) )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Bad JSON body", ;
         "error" => "Bad JSON body" } ), "application/json; charset=utf-8" )
   endif

   cKey := AllTrim( ErpToStr( hb_HGetDef( hReq, "key", "" ) ) )
   if cKey != "app" .and. cKey != "modules" .and. ;
      ! ErpKeySafe( cKey, "screen." ) .and. ! ErpKeySafe( cKey, "lookup." ) .and. ;
      ! ErpKeySafe( cKey, "report." ) .and. ! ErpKeySafe( cKey, "process." )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
         "msg" => "Invalid key (only app / modules / screen.* / lookup.* / report.* / process.*)", ;
         "error" => "Invalid key (only app / modules / screen.* / lookup.* / report.* / process.*)" } ), ;
         "application/json; charset=utf-8" )
   endif

   cAction := Lower( AllTrim( ErpToStr( hb_HGetDef( hReq, "action", "" ) ) ) )
   if cAction == "delete"
      // Lifecycle delete: only screen / lookup / report / process JSON (never app/modules)
      if cKey == "app" .or. cKey == "modules"
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "Cannot delete app or modules", ;
            "error" => "Cannot delete app or modules" } ), ;
            "application/json; charset=utf-8" )
      endif
      if cKey == "screen.login"
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "Cannot delete screen.login", ;
            "error" => "Cannot delete screen.login" } ), ;
            "application/json; charset=utf-8" )
      endif
      if ! ErpKeySafe( cKey, "screen." ) .and. ! ErpKeySafe( cKey, "lookup." ) .and. ;
            ! ErpKeySafe( cKey, "report." ) .and. ! ErpKeySafe( cKey, "process." )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "Delete only allowed for screen.* / lookup.* / report.* / process.*", ;
            "error" => "Delete only allowed for screen.* / lookup.* / report.* / process.*" } ), ;
            "application/json; charset=utf-8" )
      endif
      cFull := ErpMetaPathForKey( cKey )
      if Empty( cFull )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Unknown meta key", ;
            "error" => "Unknown meta key" } ), "application/json; charset=utf-8" )
      endif
      if s_mtx != NIL
         hb_mutexLock( s_mtx )
      endif
      lOk := .T.
      if File( cFull )
         nEr := FErase( cFull )
         lOk := ( nEr == 0 )
      endif
      if s_mtx != NIL
         hb_mutexUnlock( s_mtx )
      endif
      if ! lOk
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Delete failed", ;
            "error" => "Delete failed" } ), "application/json; charset=utf-8" )
      endif
      ErpMetaInvalidate( cKey )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "key" => cKey, "action" => "delete", ;
         "path" => cFull } ), "application/json; charset=utf-8" )
   endif

   hDoc := hb_HGetDef( hReq, "doc", NIL )
   if ValType( hDoc ) != "H"
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
         "msg" => "doc must be a JSON object", ;
         "error" => "doc must be a JSON object" } ), ;
         "application/json; charset=utf-8" )
   endif

   xW := hb_HGetDef( hReq, "writeFile", .F. )
   lWrite := ( ValType( xW ) == "L" .and. xW ) .or. ;
      ( ValType( xW ) == "C" .and. Lower( AllTrim( xW ) ) == "true" )

   if ! lWrite
      // memory-only save: update the cache, no file write
      ErpMetaCachePut( cKey, hDoc )
      if cKey == "app"
         ErpMetaInvalidate( "modules" )
         ErpDbEnsureTables()   // no-op unless database.driver is dbfcdx/openads
      endif
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "key" => cKey } ), ;
         "application/json; charset=utf-8" )
   endif

   cFull := ErpMetaPathForKey( cKey )
   if Empty( cFull )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Unknown meta key", ;
         "error" => "Unknown meta key" } ), "application/json; charset=utf-8" )
   endif

   // Ensure parent folder exists (new screens under meta/screens/)
   cDir := hb_FNameDir( cFull )
   if ! Empty( cDir ) .and. ! hb_DirExists( cDir )
      hb_DirCreate( cDir )
   endif

   cJson := hb_jsonEncode( hDoc ) + Chr( 10 )
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   lOk := ErpWriteFileAtomic( cFull, cJson )
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
   if ! lOk
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Write failed", ;
         "error" => "Write failed" } ), "application/json; charset=utf-8" )
   endif
   ErpMetaInvalidate( cKey )
   if cKey == "app"
      // vertical may have changed: the modules key resolves to another file now
      ErpMetaInvalidate( "modules" )
      ErpDbEnsureTables()   // no-op unless database.driver is dbfcdx/openads
   endif
   cOut := hb_jsonEncode( { "ok" => .T., "key" => cKey, "path" => cFull } )
return ErpHttpOk( cOut, "application/json; charset=utf-8" )

//--------------------------------------------------------------------
// GET /api/process — list process.* meta + registered handlers
// GET /api/process?key=process.xxx — one process doc
// GET /api/process?handlers=1 — handlers only
static function ErpApiProcessGet( cQuery )

   local hQ := ErpQuery( cQuery ), cKey, aItems := {}, aAll, h, aOut := {}
   local lHandlersOnly

   cKey := AllTrim( ErpToStr( hb_HGetDef( hQ, "key", "" ) ) )
   lHandlersOnly := ! Empty( hb_HGetDef( hQ, "handlers", "" ) )

   if lHandlersOnly
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "handlers" => ErpProcHandlers() } ), ;
         "application/json; charset=utf-8" )
   endif

   if ! Empty( cKey )
      if ! ErpKeySafe( cKey, "process." )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Invalid process key" } ), ;
            "application/json; charset=utf-8" )
      endif
      return ErpHttpOk( ErpMetaApiEnvelope( cKey ), "application/json; charset=utf-8" )
   endif

   aAll := ErpMetaCatalog()
   for each h in aAll
      if ValType( h ) == "H" .and. Left( AllTrim( ErpToStr( hb_HGetDef( h, "key", "" ) ) ), 8 ) == "process."
         AAdd( aItems, h )
      endif
   next
return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "count" => Len( aItems ), ;
   "items" => aItems, "handlers" => ErpProcHandlers() } ), ;
   "application/json; charset=utf-8" )

//--------------------------------------------------------------------
// POST /api/process — run a process (any logged user; roles checked later)
// Body: { "key":"process.xxx", "params":{...}, "screenKey":"...",
//         "dataRef":"...", "row":{...} }
static function ErpApiProcessPost( cBody, hSess )

   local hReq := { => }, cKey, hDoc, cHandler, hCtx, hOut, hParams, hRow
   local cUser, cWd, cConfirm

   if "{" $ cBody
      hb_jsonDecode( cBody, @hReq )
   endif
   if ValType( hReq ) != "H" .or. Empty( hb_HKeys( hReq ) )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Bad JSON body" } ), ;
         "application/json; charset=utf-8" )
   endif

   cKey := AllTrim( ErpToStr( hb_HGetDef( hReq, "key", "" ) ) )
   if ! ErpKeySafe( cKey, "process." )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Invalid process key" } ), ;
         "application/json; charset=utf-8" )
   endif

   hDoc := ErpMetaGet( cKey )
   if ValType( hDoc ) != "H" .or. Empty( hb_HKeys( hDoc ) )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Process not found: " + cKey } ), ;
         "application/json; charset=utf-8" )
   endif

   cHandler := AllTrim( ErpToStr( hb_HGetDef( hDoc, "handler", "" ) ) )
   if Empty( cHandler )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Process has no handler" } ), ;
         "application/json; charset=utf-8" )
   endif
   if ! ErpProcHandlerOk( cHandler )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
         "msg" => "Handler not registered: " + cHandler } ), ;
         "application/json; charset=utf-8" )
   endif

   cUser := AllTrim( ErpToStr( hb_HGetDef( hSess, "user", "" ) ) )
   cWd := AllTrim( ErpToStr( hb_HGetDef( hSess, "workDate", "" ) ) )
   hParams := hb_HGetDef( hReq, "params", { => } )
   if ValType( hParams ) != "H"
      hParams := { => }
   endif
   hRow := hb_HGetDef( hReq, "row", NIL )
   if ValType( hRow ) != "H"
      hRow := NIL
   endif

   // Optional client-side confirm string is informational only (already confirmed in UI)
   cConfirm := AllTrim( ErpToStr( hb_HGetDef( hDoc, "confirm", "" ) ) )
   HB_SYMBOL_UNUSED( cConfirm )

   hCtx := { ;
      "user" => cUser, ;
      "workDate" => cWd, ;
      "processKey" => cKey, ;
      "processTitle" => ErpToStr( hb_HGetDef( hDoc, "title", cKey ) ), ;
      "screenKey" => AllTrim( ErpToStr( hb_HGetDef( hReq, "screenKey", "" ) ) ), ;
      "dataRef" => AllTrim( ErpToStr( hb_HGetDef( hReq, "dataRef", "" ) ) ), ;
      "params" => hParams, ;
      "row" => hRow }

   hOut := ErpProcRun( cHandler, hCtx )
   if ValType( hOut ) != "H"
      hOut := { "ok" => .F., "msg" => "Invalid process result" }
   endif
   hOut[ "key" ] := cKey
   hOut[ "handler" ] := cHandler
   // Surface process onSuccess hints for the client (optional)
   if hb_HHasKey( hDoc, "onSuccess" ) .and. ValType( hDoc[ "onSuccess" ] ) == "H"
      hOut[ "onSuccess" ] := hDoc[ "onSuccess" ]
   endif
return ErpHttpOk( hb_jsonEncode( hOut ), "application/json; charset=utf-8" )

//--------------------------------------------------------------------
// POST /api/dataset — row CRUD on data.* docs (any logged user).
// Body: { "key":"data.x", "action":"add"|"update"|"delete",
//         "row":{...}, "keyField":"code", "keyValue":"P0001" }
// - add:    appends row
// - update: replaces the row where row[keyField] == keyValue
// - delete: removes that row (row not needed)
// Persists the whole doc (other keys like id/kind/entity are kept) to
// meta/data/<x>.json and invalidates the meta cache.
static function ErpApiDatasetPost( cBody, hSess )

   local hReq := { => }, cKey, cAction, cKeyField, cKeyValue, hRow, cOut
   local cRaw, hDoc := { => }, aRows, n, lFound := .F.
   local cFull, cJson, lOk

   if Empty( hSess )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
         "application/json; charset=utf-8" )
   endif

   if "{" $ cBody
      hb_jsonDecode( cBody, @hReq )
   endif
   if ValType( hReq ) != "H" .or. Empty( hb_HKeys( hReq ) )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Bad JSON body" } ), ;
         "application/json; charset=utf-8" )
   endif

   cKey := AllTrim( ErpToStr( hb_HGetDef( hReq, "key", "" ) ) )
   if ! ErpKeySafe( cKey, "data." )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
         "msg" => "Invalid key (only data.*)" } ), "application/json; charset=utf-8" )
   endif

   cAction := Lower( AllTrim( ErpToStr( hb_HGetDef( hReq, "action", "" ) ) ) )
   if ! ( cAction == "add" .or. cAction == "update" .or. cAction == "delete" )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
         "msg" => "Unknown action (add|update|delete)" } ), ;
         "application/json; charset=utf-8" )
   endif

   cKeyField := AllTrim( ErpToStr( hb_HGetDef( hReq, "keyField", "" ) ) )
   cKeyValue := ErpToStr( hb_HGetDef( hReq, "keyValue", "" ) )
   hRow := hb_HGetDef( hReq, "row", NIL )

   if ErpDbDriver() != "json"
      // selectable data layer (dbfcdx / openads): apply on the DBF table,
      // the meta/data/*.json files stay untouched
      if cAction != "delete" .and. ValType( hRow ) != "H"
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "row must be a JSON object" } ), "application/json; charset=utf-8" )
      endif
      if cAction != "add" .and. Empty( cKeyField )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "keyField required" } ), "application/json; charset=utf-8" )
      endif
      if ! ErpDbApply( cKey, cAction, cBody )
         cOut := "DB apply failed: " + cAction + " " + cKey
         if ! Empty( ErpDbLastError() )
            cOut += " — " + ErpDbLastError()
         endif
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => cOut } ), ;
            "application/json; charset=utf-8" )
      endif
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "key" => cKey, ;
         "action" => cAction } ), "application/json; charset=utf-8" )
   endif

   // Fresh copy from disk — never mutate the ErpMetaGet() cached hash
   cRaw := ErpMetaGetRaw( cKey )
   if Empty( cRaw )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Dataset not found", ;
         "key" => cKey } ), "application/json; charset=utf-8" )
   endif
   hb_jsonDecode( cRaw, @hDoc )
   if ValType( hDoc ) != "H" .or. ! hb_HHasKey( hDoc, "rows" ) .or. ;
         ValType( hDoc[ "rows" ] ) != "A"
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Dataset has no rows", ;
         "key" => cKey } ), "application/json; charset=utf-8" )
   endif
   aRows := hDoc[ "rows" ]

   if cAction == "add"
      if ValType( hRow ) != "H"
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "row must be a JSON object" } ), "application/json; charset=utf-8" )
      endif
      // data.users: store only CRC of password (never plain text)
      if cKey == "data.users"
         if Empty( AllTrim( ErpToStr( hb_HGetDef( hRow, "password", "" ) ) ) )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "Password required for new user" } ), ;
               "application/json; charset=utf-8" )
         endif
         ErpUsersNormalizeRow( hRow, NIL )
      elseif cKey == "data.companies"
         ErpCompanyNormalizeRow( hRow )
      else
         ErpCompanyStampRow( cKey, hRow, hSess )
      endif
      AAdd( aRows, hRow )
   else
      if Empty( cKeyField )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "keyField required" } ), "application/json; charset=utf-8" )
      endif
      for n := 1 to Len( aRows )
         if ValType( aRows[ n ] ) == "H" .and. hb_HHasKey( aRows[ n ], cKeyField ) .and. ;
               ErpToStr( aRows[ n ][ cKeyField ] ) == cKeyValue
            lFound := .T.
            exit
         endif
      next
      if ! lFound
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
            "msg" => "Row not found: " + cKeyField + "=" + cKeyValue } ), ;
            "application/json; charset=utf-8" )
      endif
      if cAction == "update"
         if ValType( hRow ) != "H"
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "row must be a JSON object" } ), "application/json; charset=utf-8" )
         endif
         if cKey == "data.users"
            ErpUsersNormalizeRow( hRow, aRows[ n ] )
         elseif cKey == "data.companies"
            ErpCompanyNormalizeRow( hRow )
         else
            ErpCompanyStampRow( cKey, hRow, hSess )
         endif
         aRows[ n ] := hRow
      else
         // protect last admin user
         if cKey == "data.users" .and. ValType( aRows[ n ] ) == "H" .and. ;
               ErpUserRowIsAdmin( aRows[ n ] )
            if ErpUsersAdminCount( aRows ) <= 1
               return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
                  "msg" => "Cannot delete the last admin user" } ), ;
                  "application/json; charset=utf-8" )
            endif
         endif
         ADel( aRows, n )
         ASize( aRows, Len( aRows ) - 1 )
      endif
   endif

   cFull := ErpMetaPathForKey( cKey )
   if Empty( cFull )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Unknown meta key" } ), ;
         "application/json; charset=utf-8" )
   endif
   cJson := hb_jsonEncode( hDoc ) + Chr( 10 )
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   lOk := ErpWriteFileAtomic( cFull, cJson )
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
   if ! lOk
      return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Write failed" } ), ;
         "application/json; charset=utf-8" )
   endif
   ErpMetaInvalidate( cKey )
return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "key" => cKey, ;
   "action" => cAction, "rows" => Len( aRows ) } ), "application/json; charset=utf-8" )

//--------------------------------------------------------------------
// Password storage: decimal CRC32 of the plain password (never store plain).
// hb_CRC32 is IEEE polynomial; value stored as unsigned decimal string.
function ErpPassCrc( cPass )

   local n

   cPass := AllTrim( ErpToStr( cPass ) )
   n := hb_CRC32( cPass )
   // Harbour may return signed 32-bit; normalize to unsigned decimal
   if n < 0
      n += 4294967296
   endif
return hb_ntos( n )

//--------------------------------------------------------------------
// True if string looks like a stored CRC (digits only, not a typical plain pass)
static function ErpPassLooksLikeCrc( c )

   local n, cCh
   c := AllTrim( ErpToStr( c ) )
   if Empty( c ) .or. Len( c ) < 5 .or. Len( c ) > 12
      return .F.
   endif
   for n := 1 to Len( c )
      cCh := SubStr( c, n, 1 )
      if ! ( cCh >= "0" .and. cCh <= "9" )
         return .F.
      endif
   next
return .T.

//--------------------------------------------------------------------
// Normalize data.users row before save:
//  - password → CRC only (empty on update keeps previous CRC)
//  - companies → clean string array; always includes defaultCompany
//  - defaultCompany / defaultApp trimmed
// On update, preserve any keys the form did not send (merge from hOld).
static function ErpUsersNormalizeRow( hRow, hOld )

   local cP, cDef, aCo := {}, aIn, x, c, lHas := .F., aKeys, cKey

   if ValType( hRow ) != "H"
      return NIL
   endif

   // Merge: keep old fields the client omitted (e.g. future extras)
   if ValType( hOld ) == "H"
      aKeys := hb_HKeys( hOld )
      for each cKey in aKeys
         if ! hb_HHasKey( hRow, cKey )
            hRow[ cKey ] := hOld[ cKey ]
         endif
      next
   endif

   // Password → CRC
   if ! hb_HHasKey( hRow, "password" ) .or. ;
         Empty( AllTrim( ErpToStr( hb_HGetDef( hRow, "password", "" ) ) ) )
      if ValType( hOld ) == "H" .and. hb_HHasKey( hOld, "password" ) .and. ;
            ! Empty( AllTrim( ErpToStr( hOld[ "password" ] ) ) )
         hRow[ "password" ] := hOld[ "password" ]
      else
         hRow[ "password" ] := ErpPassCrc( "" )
      endif
   else
      cP := AllTrim( ErpToStr( hRow[ "password" ] ) )
      if ErpPassLooksLikeCrc( cP ) .and. ValType( hOld ) == "H" .and. ;
            AllTrim( ErpToStr( hb_HGetDef( hOld, "password", "" ) ) ) == cP
         hRow[ "password" ] := cP
      else
         hRow[ "password" ] := ErpPassCrc( cP )
      endif
   endif

   // role / active
   if ! hb_HHasKey( hRow, "role" ) .or. Empty( AllTrim( ErpToStr( hRow[ "role" ] ) ) )
      hRow[ "role" ] := "user"
   endif
   if ! hb_HHasKey( hRow, "active" )
      hRow[ "active" ] := .T.
   endif

   // defaultCompany / defaultApp as clean strings
   cDef := AllTrim( ErpToStr( hb_HGetDef( hRow, "defaultCompany", ;
      hb_HGetDef( hRow, "company", "" ) ) ) )
   if ! Empty( cDef )
      hRow[ "defaultCompany" ] := cDef
   endif
   if hb_HHasKey( hRow, "defaultApp" )
      hRow[ "defaultApp" ] := AllTrim( ErpToStr( hRow[ "defaultApp" ] ) )
   endif

   // companies: accept array or comma-separated string → array of codes
   if hb_HHasKey( hRow, "companies" )
      aIn := hRow[ "companies" ]
   elseif hb_HHasKey( hRow, "allowedCompanies" )
      aIn := hRow[ "allowedCompanies" ]
   else
      aIn := NIL
   endif
   if ValType( aIn ) == "A"
      for each x in aIn
         c := AllTrim( ErpToStr( x ) )
         if ! Empty( c ) .and. ;
               AScan( aCo, {| z | Upper( z ) == Upper( c ) } ) == 0
            AAdd( aCo, c )
         endif
      next
   elseif ValType( aIn ) == "C" .and. ! Empty( AllTrim( aIn ) )
      aIn := hb_ATokens( AllTrim( aIn ), "," )
      for each x in aIn
         c := AllTrim( ErpToStr( x ) )
         if ! Empty( c ) .and. ;
               AScan( aCo, {| z | Upper( z ) == Upper( c ) } ) == 0
            AAdd( aCo, c )
         endif
      next
   endif
   // Always authorize defaultCompany (editing only defaultCompany used to leave
   // companies=[MAD] while defaultCompany=HQ → login fell back to MAD/clinic)
   if ! Empty( cDef )
      lHas := .F.
      for each c in aCo
         if Upper( c ) == Upper( cDef )
            lHas := .T.
            exit
         endif
      next
      if ! lHas
         AAdd( aCo, cDef )
      endif
   endif
   hRow[ "companies" ] := aCo

   // apps / verticals: same rules as companies (empty = only defaultApp)
   aCo := {}
   if hb_HHasKey( hRow, "apps" )
      aIn := hRow[ "apps" ]
   elseif hb_HHasKey( hRow, "allowedApps" )
      aIn := hRow[ "allowedApps" ]
   elseif hb_HHasKey( hRow, "verticals" )
      aIn := hRow[ "verticals" ]
   else
      aIn := NIL
   endif
   if ValType( aIn ) == "A"
      for each x in aIn
         c := AllTrim( ErpToStr( x ) )
         if ! Empty( c ) .and. ;
               AScan( aCo, {| z | Upper( z ) == Upper( c ) } ) == 0
            AAdd( aCo, c )
         endif
      next
   elseif ValType( aIn ) == "C" .and. ! Empty( AllTrim( aIn ) )
      aIn := hb_ATokens( AllTrim( aIn ), "," )
      for each x in aIn
         c := AllTrim( ErpToStr( x ) )
         if ! Empty( c ) .and. ;
               AScan( aCo, {| z | Upper( z ) == Upper( c ) } ) == 0
            AAdd( aCo, c )
         endif
      next
   endif
   cDef := AllTrim( ErpToStr( hb_HGetDef( hRow, "defaultApp", "" ) ) )
   if ! Empty( cDef )
      lHas := .F.
      for each c in aCo
         if Upper( c ) == Upper( cDef )
            lHas := .T.
            exit
         endif
      next
      if ! lHas
         AAdd( aCo, cDef )
      endif
   endif
   hRow[ "apps" ] := aCo
return NIL

//--------------------------------------------------------------------
static function ErpUserRowIsAdmin( hRow )

   local cRole, cCode
   if ValType( hRow ) != "H"
      return .F.
   endif
   cRole := Lower( AllTrim( ErpToStr( hb_HGetDef( hRow, "role", "" ) ) ) )
   cCode := Lower( AllTrim( ErpToStr( hb_HGetDef( hRow, "code", "" ) ) ) )
   if cRole == "admin" .or. cRole == "administrator"
      return .T.
   endif
   // legacy: code "admin" without role still admin
   if cCode == "admin" .and. Empty( cRole )
      return .T.
   endif
return .F.

//--------------------------------------------------------------------
static function ErpUsersAdminCount( aRows )

   local n := 0, h
   if ValType( aRows ) != "A"
      return 0
   endif
   for each h in aRows
      if ValType( h ) == "H" .and. ErpUserRowIsAdmin( h )
         // count only active admins when active is present
         if hb_HHasKey( h, "active" )
            if h[ "active" ] == .T. .or. Upper( AllTrim( ErpToStr( h[ "active" ] ) ) ) $ "1|Y|YES|TRUE|.T."
               n++
            endif
         else
            n++
         endif
      endif
   next
return n

//--------------------------------------------------------------------
// Find user row in data.users; NIL if bad password / inactive / missing.
function ErpUserAuth( cUser, cPass )

   local hDoc := { => }, aRows, h, cCode, cStored, cCrc, lActive

   cUser := AllTrim( ErpToStr( cUser ) )
   cPass := AllTrim( ErpToStr( cPass ) )
   if Empty( cUser )
      return NIL
   endif

   hDoc := ErpMetaGet( "data.users" )
   if ValType( hDoc ) != "H" .or. ! hb_HHasKey( hDoc, "rows" ) .or. ;
         ValType( hDoc[ "rows" ] ) != "A"
      // Fallback hardcoded only if dataset missing (fresh install)
      if ( Upper( cUser ) == "ADMIN" .and. cPass == "1234" ) .or. ;
            ( Upper( cUser ) == "DEMO" .and. cPass == "demo" )
         return { "code" => Lower( cUser ), "name" => cUser, ;
            "role" => iif( Upper( cUser ) == "ADMIN", "admin", "user" ), ;
            "active" => .T. }
      endif
      return NIL
   endif

   aRows := hDoc[ "rows" ]
   cCrc := ErpPassCrc( cPass )
   for each h in aRows
      if ValType( h ) != "H"
         loop
      endif
      cCode := AllTrim( ErpToStr( hb_HGetDef( h, "code", "" ) ) )
      if Upper( cCode ) != Upper( cUser )
         loop
      endif
      lActive := .T.
      if hb_HHasKey( h, "active" )
         lActive := ( h[ "active" ] == .T. ) .or. ;
            Upper( AllTrim( ErpToStr( h[ "active" ] ) ) ) $ "1|Y|YES|TRUE|.T."
      endif
      if ! lActive
         return NIL
      endif
      cStored := AllTrim( ErpToStr( hb_HGetDef( h, "password", "" ) ) )
      // Stored value is CRC decimal; accept match only (never plain)
      if ! Empty( cStored ) .and. cStored == cCrc
         return h
      endif
      return NIL
   next
return NIL

//--------------------------------------------------------------------
// Find user row by code (no password check). Returns hash or NIL.
function ErpUserFind( cUser )

   local hDoc, aRows, h, cCode
   cUser := AllTrim( ErpToStr( cUser ) )
   if Empty( cUser )
      return NIL
   endif
   hDoc := ErpMetaGet( "data.users" )
   if ValType( hDoc ) != "H" .or. ! hb_HHasKey( hDoc, "rows" ) .or. ;
         ValType( hDoc[ "rows" ] ) != "A"
      return NIL
   endif
   aRows := hDoc[ "rows" ]
   for each h in aRows
      if ValType( h ) != "H"
         loop
      endif
      cCode := AllTrim( ErpToStr( hb_HGetDef( h, "code", "" ) ) )
      if Upper( cCode ) == Upper( cUser )
         return h
      endif
   next
return NIL

//--------------------------------------------------------------------
// Persist last company/app so the next login restores them via
// ErpCompanyDefaultForUser / ErpCompanyDefaultApp (user.defaultCompany /
// user.defaultApp). Empty cCompany or cAppId leaves that field unchanged.
// Writes meta/data/users.json (what login reads); also syncs DBF when the
// data driver is not json.
static function ErpUserSavePrefs( cUser, cCompany, cAppId )

   local hDoc := { => }, aRows, n, cRaw, cFull, cJson, lOk := .F., lChanged := .F.
   local cOldCo, cOldApp, hRow, cBody

   cUser := AllTrim( ErpToStr( cUser ) )
   cCompany := AllTrim( ErpToStr( cCompany ) )
   cAppId := AllTrim( ErpToStr( cAppId ) )
   if Empty( cUser ) .or. ( Empty( cCompany ) .and. Empty( cAppId ) )
      return .F.
   endif

   cRaw := ErpMetaGetRaw( "data.users" )
   if Empty( cRaw )
      return .F.
   endif
   hb_jsonDecode( cRaw, @hDoc )
   if ValType( hDoc ) != "H" .or. ! hb_HHasKey( hDoc, "rows" ) .or. ;
         ValType( hDoc[ "rows" ] ) != "A"
      return .F.
   endif
   aRows := hDoc[ "rows" ]
   hRow := NIL
   for n := 1 to Len( aRows )
      if ValType( aRows[ n ] ) != "H"
         loop
      endif
      if Upper( AllTrim( ErpToStr( hb_HGetDef( aRows[ n ], "code", "" ) ) ) ) != Upper( cUser )
         loop
      endif
      hRow := aRows[ n ]
      if ! Empty( cCompany )
         cOldCo := AllTrim( ErpToStr( hb_HGetDef( hRow, "defaultCompany", ;
            hb_HGetDef( hRow, "company", "" ) ) ) )
         if Upper( cOldCo ) != Upper( cCompany )
            hRow[ "defaultCompany" ] := cCompany
            lChanged := .T.
         endif
      endif
      if ! Empty( cAppId )
         cOldApp := AllTrim( ErpToStr( hb_HGetDef( hRow, "defaultApp", ;
            hb_HGetDef( hRow, "defaultVertical", "" ) ) ) )
         if Upper( cOldApp ) != Upper( cAppId )
            hRow[ "defaultApp" ] := cAppId
            lChanged := .T.
         endif
      endif
      exit
   next
   if ValType( hRow ) != "H"
      return .F.
   endif
   if ! lChanged
      return .T.
   endif

   cFull := ErpMetaPathForKey( "data.users" )
   if Empty( cFull )
      return .F.
   endif
   cJson := hb_jsonEncode( hDoc ) + Chr( 10 )
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   lOk := ErpWriteFileAtomic( cFull, cJson )
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
   if ! lOk
      return .F.
   endif
   ErpMetaInvalidate( "data.users" )

   // Keep DBF/OpenADS table in sync when that is the active driver
   if ErpDbDriver() != "json"
      cBody := hb_jsonEncode( { "key" => "data.users", "action" => "update", ;
         "keyField" => "code", "keyValue" => cUser, "row" => hRow } )
      ErpDbApply( "data.users", "update", cBody )
   endif
return .T.

//--------------------------------------------------------------------
// Is this user code an admin (look up data.users, fallback to code name)
function ErpUserCodeIsAdmin( cUser )

   local hDoc, aRows, h, cCode
   cUser := AllTrim( ErpToStr( cUser ) )
   if Empty( cUser )
      return .F.
   endif
   hDoc := ErpMetaGet( "data.users" )
   if ValType( hDoc ) == "H" .and. hb_HHasKey( hDoc, "rows" ) .and. ;
         ValType( hDoc[ "rows" ] ) == "A"
      aRows := hDoc[ "rows" ]
      for each h in aRows
         if ValType( h ) != "H"
            loop
         endif
         cCode := AllTrim( ErpToStr( hb_HGetDef( h, "code", "" ) ) )
         if Upper( cCode ) == Upper( cUser )
            return ErpUserRowIsAdmin( h )
         endif
      next
   endif
return Upper( cUser ) == "ADMIN"

//--------------------------------------------------------------------
function ErpSessIsAdmin( hSess )

   if Empty( hSess ) .or. ValType( hSess ) != "H"
      return .F.
   endif
   if hb_HHasKey( hSess, "isAdmin" ) .and. ValType( hSess[ "isAdmin" ] ) == "L"
      return hSess[ "isAdmin" ]
   endif
   if Lower( AllTrim( ErpToStr( hb_HGetDef( hSess, "role", "" ) ) ) ) == "admin"
      return .T.
   endif
return ErpUserCodeIsAdmin( hb_HGetDef( hSess, "user", "" ) )

//--------------------------------------------------------------------
// Multi-company: global (unfiltered) datasets
function ErpCompanyIsGlobalKey( cKey )

   cKey := Lower( AllTrim( ErpToStr( cKey ) ) )
return cKey == "data.companies" .or. cKey == "data.users" .or. ;
   cKey == "data.roles" .or. cKey == "data.user_roles" .or. ;
   cKey == "data.settings" .or. cKey == "data.groups"

//--------------------------------------------------------------------
// Active companies from data.companies (array of hashes)
function ErpCompanyList()

   local hDoc := ErpMetaGet( "data.companies" ), aOut := {}, aRows, h, lAct

   if ValType( hDoc ) != "H" .or. ! hb_HHasKey( hDoc, "rows" ) .or. ;
         ValType( hDoc[ "rows" ] ) != "A"
      return { { "code" => "HQ", "name" => "Default", "currency" => "EUR", "active" => .T. } }
   endif
   aRows := hDoc[ "rows" ]
   for each h in aRows
      if ValType( h ) != "H"
         loop
      endif
      lAct := .T.
      if hb_HHasKey( h, "active" )
         lAct := ( h[ "active" ] == .T. ) .or. ;
            Upper( AllTrim( ErpToStr( h[ "active" ] ) ) ) $ "1|Y|YES|TRUE|.T."
      endif
      if lAct
         AAdd( aOut, h )
      endif
   next
   if Empty( aOut )
      AAdd( aOut, { "code" => "HQ", "name" => "Default", "currency" => "EUR", "active" => .T. } )
   endif
return aOut

//--------------------------------------------------------------------
// Company codes a non-admin user may use (from user.companies / allowedCompanies).
// Empty list means "only defaultCompany" — no multi-company switch unless admin.
static function ErpUserCompanyCodes( hUser )

   local aOut := {}, x, a, i, c, cDef

   if ValType( hUser ) != "H"
      return aOut
   endif
   // Prefer explicit multi-company grant list
   x := NIL
   if hb_HHasKey( hUser, "companies" )
      x := hUser[ "companies" ]
   elseif hb_HHasKey( hUser, "allowedCompanies" )
      x := hUser[ "allowedCompanies" ]
   endif
   if ValType( x ) == "A"
      for each c in x
         c := AllTrim( ErpToStr( c ) )
         if ! Empty( c )
            AAdd( aOut, c )
         endif
      next
   elseif ValType( x ) == "C" .and. ! Empty( AllTrim( x ) )
      a := hb_ATokens( AllTrim( x ), "," )
      for i := 1 to Len( a )
         c := AllTrim( a[ i ] )
         if ! Empty( c )
            AAdd( aOut, c )
         endif
      next
   endif
   // Always include default company so login never leaves the user stranded
   cDef := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultCompany", ;
      hb_HGetDef( hUser, "company", "" ) ) ) )
   if ! Empty( cDef )
      if AScan( aOut, {| z | Upper( AllTrim( ErpToStr( z ) ) ) == Upper( cDef ) } ) == 0
         AAdd( aOut, cDef )
      endif
   endif
return aOut

//--------------------------------------------------------------------
// .T. if this user may open / switch to company cCode.
// Admins: always. Non-admins: only codes in user.companies (+ defaultCompany).
// hUser NIL → deny (callers must pass the data.users row).
function ErpUserCanAccessCompany( hUser, cCode )

   local aCodes, c

   cCode := AllTrim( ErpToStr( cCode ) )
   if Empty( cCode ) .or. ValType( hUser ) != "H"
      return .F.
   endif
   if ValType( ErpCompanyFind( cCode ) ) != "H"
      return .F.
   endif
   if ErpUserRowIsAdmin( hUser )
      return .T.
   endif
   aCodes := ErpUserCompanyCodes( hUser )
   if Empty( aCodes )
      c := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultCompany", ;
         hb_HGetDef( hUser, "company", "" ) ) ) )
      return ! Empty( c ) .and. Upper( c ) == Upper( cCode )
   endif
   for each c in aCodes
      if Upper( AllTrim( ErpToStr( c ) ) ) == Upper( cCode )
         return .T.
      endif
   next
return .F.

//--------------------------------------------------------------------
// Companies visible/selectable for a user (admin = all active).
// Unknown / missing user → empty list (never the full catalog).
function ErpCompanyListForUser( hUser )

   local aAll := ErpCompanyList(), aOut := {}, h, cCode

   if ValType( hUser ) != "H"
      return aOut
   endif
   if ErpUserRowIsAdmin( hUser )
      return aAll
   endif
   for each h in aAll
      if ValType( h ) != "H"
         loop
      endif
      cCode := AllTrim( ErpToStr( hb_HGetDef( h, "code", "" ) ) )
      if ErpUserCanAccessCompany( hUser, cCode )
         AAdd( aOut, h )
      endif
   next
return aOut

//--------------------------------------------------------------------
// Switch is allowed only when authorized for 2+ companies (admins always).
// Single-company users (e.g. demo → MAD only) must NOT switch.
function ErpUserCanSwitchCompany( hUser )

   local a

   if ValType( hUser ) != "H"
      return .F.
   endif
   if ErpUserRowIsAdmin( hUser )
      return .T.
   endif
   a := ErpCompanyListForUser( hUser )
return Len( a ) > 1

//--------------------------------------------------------------------
// App / vertical codes a non-admin may use (user.apps / allowedApps / verticals).
// Empty list means "only defaultApp" — no app/vertical switch unless admin.
static function ErpUserAppCodes( hUser )

   local aOut := {}, x, a, i, c, cDef

   if ValType( hUser ) != "H"
      return aOut
   endif
   x := NIL
   if hb_HHasKey( hUser, "apps" )
      x := hUser[ "apps" ]
   elseif hb_HHasKey( hUser, "allowedApps" )
      x := hUser[ "allowedApps" ]
   elseif hb_HHasKey( hUser, "verticals" )
      x := hUser[ "verticals" ]
   endif
   if ValType( x ) == "A"
      for each c in x
         c := AllTrim( ErpToStr( c ) )
         if ! Empty( c )
            AAdd( aOut, c )
         endif
      next
   elseif ValType( x ) == "C" .and. ! Empty( AllTrim( x ) )
      a := hb_ATokens( AllTrim( x ), "," )
      for i := 1 to Len( a )
         c := AllTrim( a[ i ] )
         if ! Empty( c )
            AAdd( aOut, c )
         endif
      next
   endif
   cDef := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultApp", ;
      hb_HGetDef( hUser, "defaultVertical", "" ) ) ) )
   if ! Empty( cDef )
      if AScan( aOut, {| z | Upper( AllTrim( ErpToStr( z ) ) ) == Upper( cDef ) } ) == 0
         AAdd( aOut, cDef )
      endif
   endif
return aOut

//--------------------------------------------------------------------
// .T. if user may use this app id / vertical (must also be linked on company).
function ErpUserCanAccessApp( hUser, cAppId )

   local aCodes, c

   cAppId := AllTrim( ErpToStr( cAppId ) )
   if Empty( cAppId ) .or. ValType( hUser ) != "H"
      return .F.
   endif
   if ErpUserRowIsAdmin( hUser )
      return .T.
   endif
   aCodes := ErpUserAppCodes( hUser )
   if Empty( aCodes )
      c := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultApp", ;
         hb_HGetDef( hUser, "defaultVertical", "" ) ) ) )
      return ! Empty( c ) .and. Upper( c ) == Upper( cAppId )
   endif
   for each c in aCodes
      if Upper( AllTrim( ErpToStr( c ) ) ) == Upper( cAppId )
         return .T.
      endif
   next
return .F.

//--------------------------------------------------------------------
// Company apps filtered by user authorization (admin = all company apps).
function ErpCompanyAppsForUser( hCo, hUser )

   local aAll := ErpCompanyApps( hCo ), aOut := {}, h, cId, cVert

   if ValType( hUser ) != "H" .or. ErpUserRowIsAdmin( hUser )
      return aAll
   endif
   for each h in aAll
      if ValType( h ) != "H"
         loop
      endif
      cId := AllTrim( ErpToStr( hb_HGetDef( h, "id", "" ) ) )
      cVert := AllTrim( ErpToStr( hb_HGetDef( h, "vertical", cId ) ) )
      if ErpUserCanAccessApp( hUser, cId ) .or. ;
            ( ! Empty( cVert ) .and. ErpUserCanAccessApp( hUser, cVert ) )
         AAdd( aOut, h )
      endif
   next
   // Never leave non-admin with zero apps if company has some and user has default
   if Empty( aOut ) .and. ! Empty( aAll )
      cId := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultApp", "" ) ) )
      if ! Empty( cId )
         for each h in aAll
            if Upper( AllTrim( ErpToStr( hb_HGetDef( h, "id", "" ) ) ) ) == Upper( cId ) .or. ;
                  Upper( AllTrim( ErpToStr( hb_HGetDef( h, "vertical", "" ) ) ) ) == Upper( cId )
               AAdd( aOut, h )
               exit
            endif
         next
      endif
      if Empty( aOut )
         AAdd( aOut, aAll[ 1 ] )
      endif
   endif
return aOut

//--------------------------------------------------------------------
// Switch app/vertical only when 2+ authorized apps exist on current company.
function ErpUserCanSwitchApp( hUser, hCo )

   local a

   if ValType( hUser ) != "H"
      return .F.
   endif
   if ErpUserRowIsAdmin( hUser )
      return .T.
   endif
   a := ErpCompanyAppsForUser( hCo, hUser )
return Len( a ) > 1

//--------------------------------------------------------------------
function ErpCompanyFind( cCode )

   local a := ErpCompanyList(), h
   cCode := AllTrim( ErpToStr( cCode ) )
   if Empty( cCode )
      return NIL
   endif
   for each h in a
      if Upper( AllTrim( ErpToStr( hb_HGetDef( h, "code", "" ) ) ) ) == Upper( cCode )
         return h
      endif
   next
return NIL

//--------------------------------------------------------------------
// Default company for a user row (defaultCompany field or first allowed)
function ErpCompanyDefaultForUser( hUser )

   local cDef := "", a

   if ValType( hUser ) == "H"
      cDef := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultCompany", ;
         hb_HGetDef( hUser, "company", "" ) ) ) )
      if ! Empty( cDef ) .and. ErpUserCanAccessCompany( hUser, cDef )
         return cDef
      endif
      a := ErpCompanyListForUser( hUser )
      if ! Empty( a ) .and. ValType( a[ 1 ] ) == "H"
         return AllTrim( ErpToStr( hb_HGetDef( a[ 1 ], "code", "HQ" ) ) )
      endif
   endif
   a := ErpCompanyList()
   if ! Empty( a ) .and. ValType( a[ 1 ] ) == "H"
      return AllTrim( ErpToStr( hb_HGetDef( a[ 1 ], "code", "HQ" ) ) )
   endif
return "HQ"

//--------------------------------------------------------------------
// Friendly label for a vertical pack id (clinic, demo, …).
static function ErpAppLabel( cId )

   local c := Lower( AllTrim( ErpToStr( cId ) ) )
   if c == "clinic"
      return "Clinic"
   elseif c == "demo"
      return "Consulting demo"
   elseif c == "services"
      return "Professional services"
   elseif c == "retail"
      return "Retail / POS"
   elseif c == "ferreteria"
      return "Ferretería"
   elseif c == "base" .or. Empty( c )
      return "Base modules"
   endif
return AllTrim( ErpToStr( cId ) )

//--------------------------------------------------------------------
// Apps linked to a company. Each app maps to a vertical pack name.
// Supported company fields (any combination):
//   apps: [ { id, label, vertical } | "clinic" | ... ]
//   verticals: [ "clinic", "demo" ]   (checklist from Admin → Companies)
//   vertical: "clinic"               (single)
// If none: fall back to app.vertical, then base (empty vertical = modules.json).
//
// Resolution at runtime (session + next login):
//   user.defaultApp → company.defaultApp → first linked app
// Switching company/app updates the session and persists user.default*
// so logout → login restores the last choice.
function ErpCompanyApps( hCo )

   local aOut := {}, xApps, x, hApp, cId, cLab, cVert, aVert, i, cAppVert

   // From company.apps
   if ValType( hCo ) == "H" .and. hb_HHasKey( hCo, "apps" )
      xApps := hCo[ "apps" ]
      if ValType( xApps ) == "A"
         for each x in xApps
            if ValType( x ) == "C"
               cVert := AllTrim( ErpToStr( x ) )
               if ! Empty( cVert )
                  AAdd( aOut, { "id" => cVert, "label" => ErpAppLabel( cVert ), ;
                     "vertical" => cVert } )
               endif
            elseif ValType( x ) == "H"
               cVert := AllTrim( ErpToStr( hb_HGetDef( x, "vertical", ;
                  hb_HGetDef( x, "id", "" ) ) ) )
               cId := AllTrim( ErpToStr( hb_HGetDef( x, "id", cVert ) ) )
               cLab := AllTrim( ErpToStr( hb_HGetDef( x, "label", ;
                  hb_HGetDef( x, "name", "" ) ) ) )
               if ! Empty( cVert ) .or. ! Empty( cId )
                  if Empty( cVert )
                     cVert := cId
                  endif
                  if Empty( cId )
                     cId := cVert
                  endif
                  if Empty( cLab )
                     cLab := ErpAppLabel( cId )
                  endif
                  AAdd( aOut, { "id" => cId, "label" => cLab, "vertical" => cVert } )
               endif
            endif
         next
      endif
   endif

   // From company.verticals (checklist of pack names)
   if Empty( aOut ) .and. ValType( hCo ) == "H" .and. hb_HHasKey( hCo, "verticals" )
      aVert := hCo[ "verticals" ]
      if ValType( aVert ) == "A"
         for each x in aVert
            cVert := AllTrim( ErpToStr( x ) )
            if ! Empty( cVert )
               AAdd( aOut, { "id" => cVert, "label" => ErpAppLabel( cVert ), ;
                  "vertical" => cVert } )
            endif
         next
      elseif ValType( aVert ) == "C" .and. ! Empty( AllTrim( aVert ) )
         // comma-separated
         aVert := hb_ATokens( AllTrim( aVert ), "," )
         for i := 1 to Len( aVert )
            cVert := AllTrim( aVert[ i ] )
            if ! Empty( cVert )
               AAdd( aOut, { "id" => cVert, "label" => ErpAppLabel( cVert ), ;
                  "vertical" => cVert } )
            endif
         next
      endif
   endif

   // Single company.vertical
   if Empty( aOut ) .and. ValType( hCo ) == "H"
      cVert := AllTrim( ErpToStr( hb_HGetDef( hCo, "vertical", "" ) ) )
      if ! Empty( cVert )
         AAdd( aOut, { "id" => cVert, "label" => ErpAppLabel( cVert ), ;
            "vertical" => cVert } )
      endif
   endif

   // Fallback: global app.vertical
   if Empty( aOut )
      hApp := ErpMetaGet( "app" )
      cAppVert := ""
      if ValType( hApp ) == "H"
         cAppVert := AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) )
      endif
      if ! Empty( cAppVert )
         AAdd( aOut, { "id" => cAppVert, "label" => ErpAppLabel( cAppVert ), ;
            "vertical" => cAppVert } )
      else
         AAdd( aOut, { "id" => "base", "label" => "Base modules", "vertical" => "" } )
      endif
   endif
return aOut

//--------------------------------------------------------------------
// Pick default app for company (+ optional user preference), filtered by
// user.apps authorization. Order: user.defaultApp → company.defaultApp →
// app.vertical → first authorized linked app.
// Returns hash { id, label, vertical } or NIL.
function ErpCompanyDefaultApp( hCo, hUser )

   local aApps := ErpCompanyAppsForUser( hCo, hUser ), cWant := "", h, cId, hAppMeta

   if ValType( hUser ) == "H"
      cWant := AllTrim( ErpToStr( hb_HGetDef( hUser, "defaultApp", ;
         hb_HGetDef( hUser, "defaultVertical", "" ) ) ) )
   endif
   if Empty( cWant ) .and. ValType( hCo ) == "H"
      cWant := AllTrim( ErpToStr( hb_HGetDef( hCo, "defaultApp", ;
         hb_HGetDef( hCo, "defaultVertical", "" ) ) ) )
   endif
   // Align with global Edit app → Vertical pack when no user/company pref
   if Empty( cWant )
      hAppMeta := ErpMetaGet( "app" )
      if ValType( hAppMeta ) == "H"
         cWant := AllTrim( ErpToStr( hb_HGetDef( hAppMeta, "vertical", "" ) ) )
      endif
   endif
   if ! Empty( cWant )
      for each h in aApps
         cId := AllTrim( ErpToStr( hb_HGetDef( h, "id", "" ) ) )
         if Upper( cId ) == Upper( cWant ) .or. ;
               Upper( AllTrim( ErpToStr( hb_HGetDef( h, "vertical", "" ) ) ) ) == Upper( cWant )
            return h
         endif
      next
   endif
   if ! Empty( aApps )
      return aApps[ 1 ]
   endif
return { "id" => "base", "label" => "Base modules", "vertical" => "" }

//--------------------------------------------------------------------
function ErpCompanyFindApp( hCo, cAppId )

   local aApps := ErpCompanyApps( hCo ), h, cId
   cAppId := AllTrim( ErpToStr( cAppId ) )
   if Empty( cAppId )
      return NIL
   endif
   for each h in aApps
      cId := AllTrim( ErpToStr( hb_HGetDef( h, "id", "" ) ) )
      if Upper( cId ) == Upper( cAppId ) .or. ;
            Upper( AllTrim( ErpToStr( hb_HGetDef( h, "vertical", "" ) ) ) ) == Upper( cAppId )
         return h
      endif
   next
return NIL

//--------------------------------------------------------------------
function ErpSessCompany( hSess )
return AllTrim( ErpToStr( hb_HGetDef( hSess, "company", "" ) ) )

//--------------------------------------------------------------------
function ErpSessVertical( hSess )
return AllTrim( ErpToStr( hb_HGetDef( hSess, "vertical", "" ) ) )

//--------------------------------------------------------------------
function ErpSessApp( hSess )
return AllTrim( ErpToStr( hb_HGetDef( hSess, "app", "" ) ) )

//--------------------------------------------------------------------
// Normalize data.companies row: verticals checklist → apps array
static function ErpCompanyNormalizeRow( hRow )

   local aVert, aApps := {}, x, cVert, cDef
   if ValType( hRow ) != "H"
      return NIL
   endif
   // If verticals present (from checklist UI), rebuild apps from packs
   if hb_HHasKey( hRow, "verticals" )
      aVert := hRow[ "verticals" ]
      if ValType( aVert ) == "A"
         for each x in aVert
            cVert := AllTrim( ErpToStr( x ) )
            if ! Empty( cVert )
               AAdd( aApps, { "id" => cVert, "label" => ErpAppLabel( cVert ), ;
                  "vertical" => cVert } )
            endif
         next
         hRow[ "apps" ] := aApps
      endif
   endif
   // Keep defaultApp if set; if empty and apps exist, use first
   if hb_HHasKey( hRow, "defaultApp" )
      cDef := AllTrim( ErpToStr( hRow[ "defaultApp" ] ) )
      hRow[ "defaultApp" ] := cDef
   endif
   if Empty( AllTrim( ErpToStr( hb_HGetDef( hRow, "defaultApp", "" ) ) ) ) .and. ;
         ValType( hb_HGetDef( hRow, "apps", NIL ) ) == "A" .and. ;
         ! Empty( hRow[ "apps" ] ) .and. ValType( hRow[ "apps" ][ 1 ] ) == "H"
      hRow[ "defaultApp" ] := AllTrim( ErpToStr( hb_HGetDef( hRow[ "apps" ][ 1 ], "id", "" ) ) )
   endif
return NIL

//--------------------------------------------------------------------
// Filter rows by session company when dataset is multi-company scoped.
// Rows without a company field, or with empty company, are shared (visible to all).
function ErpCompanyFilterRows( cKey, aRows, hSess )

   local cCo, aOut := {}, h, cRowCo, lHasCompany := .F.

   if ErpCompanyIsGlobalKey( cKey )
      return aRows
   endif
   if ValType( aRows ) != "A"
      return {}
   endif
   cCo := ErpSessCompany( hSess )
   if Empty( cCo )
      return aRows
   endif
   for each h in aRows
      if ValType( h ) == "H" .and. hb_HHasKey( h, "company" )
         lHasCompany := .T.
         exit
      endif
   next
   if ! lHasCompany
      return aRows
   endif
   for each h in aRows
      if ValType( h ) != "H"
         loop
      endif
      if ! hb_HHasKey( h, "company" )
         AAdd( aOut, h )
         loop
      endif
      cRowCo := AllTrim( ErpToStr( h[ "company" ] ) )
      if Empty( cRowCo ) .or. Upper( cRowCo ) == Upper( cCo )
         AAdd( aOut, h )
      endif
   next
return aOut

//--------------------------------------------------------------------
// Stamp company on new/updated business rows when session has a company
function ErpCompanyStampRow( cKey, hRow, hSess )

   local cCo
   if ErpCompanyIsGlobalKey( cKey ) .or. ValType( hRow ) != "H"
      return NIL
   endif
   cCo := ErpSessCompany( hSess )
   if Empty( cCo )
      return NIL
   endif
   // Only stamp if field missing or empty (allow explicit override)
   if ! hb_HHasKey( hRow, "company" ) .or. ;
         Empty( AllTrim( ErpToStr( hRow[ "company" ] ) ) )
      hRow[ "company" ] := cCo
   endif
return NIL

//--------------------------------------------------------------------
// Decode dataset rows array from meta JSON
function ErpDatasetRowsArray( cKey )

   local cRaw := ErpMetaGetRaw( cKey ), hDoc := { => }

   if Empty( cRaw )
      return {}
   endif
   hb_jsonDecode( cRaw, @hDoc )
   if ValType( hDoc ) == "H" .and. hb_HHasKey( hDoc, "rows" ) .and. ;
         ValType( hDoc[ "rows" ] ) == "A"
      return hDoc[ "rows" ]
   endif
return {}

//--------------------------------------------------------------------
// Strict meta key whitelist: prefix + [A-Za-z0-9_] only.
// Rejects "..", "/", "\", spaces and any traversal attempt.
static function ErpKeySafe( cKey, cPrefix )

   local n, cCh

   cKey := AllTrim( ErpToStr( cKey ) )
   if Empty( cKey ) .or. Left( cKey, Len( cPrefix ) ) != cPrefix
      return .F.
   endif
   if Len( cKey ) <= Len( cPrefix )
      return .F.
   endif
   for n := Len( cPrefix ) + 1 to Len( cKey )
      cCh := SubStr( cKey, n, 1 )
      if ! ( ( cCh >= "A" .and. cCh <= "Z" ) .or. ;
             ( cCh >= "a" .and. cCh <= "z" ) .or. ;
             ( cCh >= "0" .and. cCh <= "9" ) .or. cCh == "_" )
         return .F.
      endif
   next
return .T.

//--------------------------------------------------------------------
// Atomic file write: write <file>.tmp then rename over the target.
// Call with s_mtx held (meta writes are globally serialized).
static function ErpWriteFileAtomic( cFull, cContent )

   local cTmp := cFull + ".tmp"

   if ! MemoWrit( cTmp, cContent )
      return .F.
   endif
   if File( cFull )
      if FErase( cFull ) != 0
         FErase( cTmp )
         return .F.
      endif
   endif
   if FRename( cTmp, cFull ) == 0
      return .T.
   endif
   FErase( cTmp )
return .F.

//--------------------------------------------------------------------
static function ErpHttpForbidden( cPath )

   local cOut := "<h1>403</h1><p>" + cPath + "</p>"

return "HTTP/1.1 403 Forbidden" + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Type: text/html; charset=utf-8" + Chr( 13 ) + Chr( 10 ) + ;
       "Content-Length: " + hb_ntos( hb_BLen( cOut ) ) + Chr( 13 ) + Chr( 10 ) + ;
       "Connection: close" + Chr( 13 ) + Chr( 10 ) + Chr( 13 ) + Chr( 10 ) + cOut

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
   local cFile, cMime, cCookie, cDate, cAction, cArg, nSel, cRel, bOld
   local cCo, cCoName, cCur, hCo, aRows, hApp, cAppId, cAppLab

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
   // Per-request modules path follows session company-app vertical
   if ! Empty( hSess )
      ErpMetaSetRequestVertical( ErpSessVertical( hSess ) )
   else
      ErpMetaSetRequestVertical( "" )
   endif

   // --- pages (same routes as FWH DesktopWeb login.prg) ---
   if cMethod == "GET" .and. ( cPath == "/" .or. cPath == "/login" .or. cPath == "/index.html" )
      ErpMetaSetRequestVertical( "" )
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
      // Ensure modules embed uses session vertical
      ErpMetaSetRequestVertical( ErpSessVertical( hSess ) )
      return ErpHttpOk( ErpFwhDashboardHtml( ;
         ErpToStr( hb_HGetDef( hSess, "user", "" ) ), ;
         ErpToStr( hb_HGetDef( hSess, "workDate", DToC( Date() ) ) ), ;
         nSel ), "text/html; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/logout"
      ErpSessDel( cTok )
      return ErpHttpRedirect( "/login", "DWSESS=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0" )
   endif

   // --- API (FWH-compatible) ---
   if cMethod == "GET" .and. cPath == "/api/meta"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
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

   // Runtime form designer save (admin only, screen.* / lookup.* / process.* keys)
   if cMethod == "POST" .and. cPath == "/api/meta"
      return ErpApiMetaPost( cBody, hSess )
   endif

   // Business processes (whitelist Harbour handlers; meta process.* configures them)
   if cMethod == "GET" .and. cPath == "/api/process"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      return ErpApiProcessGet( cQuery )
   endif
   if cMethod == "POST" .and. cPath == "/api/process"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      return ErpApiProcessPost( cBody, hSess )
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
      if ErpDbDriver() != "json"
         aRows := ErpDbReadRows( cKey )
      else
         aRows := ErpDatasetRowsArray( cKey )
      endif
      aRows := ErpCompanyFilterRows( cKey, aRows, hSess )
      cOut := hb_jsonEncode( { "ok" => .T., "key" => cKey, ;
         "rows" => aRows, ;
         "company" => ErpSessCompany( hSess ) } )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   // Dataset row CRUD (any logged user): add / update / delete by keyField
   if cMethod == "POST" .and. cPath == "/api/dataset"
      return ErpApiDatasetPost( cBody, hSess )
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

   // Selectable data layer status (driver/backend/tables/ADS availability)
   if cMethod == "GET" .and. cPath == "/api/db/status"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      // Prefer live data-layer status; fall back to app.database so the UI
      // always knows which driver is configured.
      bOld := ErrorBlock( {| e | Break( e ) } )
      begin sequence
         cOut := hb_jsonEncode( ErpDbStatus() )
      recover
         cOut := ""
      end sequence
      ErrorBlock( bOld )
      if Empty( cOut )
         cOut := hb_jsonEncode( ErpDbStatusFromApp() )
      endif
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
      // Authenticate against data.users (password stored as CRC32 only)
      hDoc := ErpUserAuth( cUser, cPass )
      if ValType( hDoc ) == "H"
         cUser := AllTrim( ErpToStr( hb_HGetDef( hDoc, "code", cUser ) ) )
         cCo := ErpCompanyDefaultForUser( hDoc )
         cCoName := cCo
         cCur := ""
         hCo := ErpCompanyFind( cCo )
         if ValType( hCo ) == "H"
            cCoName := AllTrim( ErpToStr( hb_HGetDef( hCo, "name", cCo ) ) )
            cCur := AllTrim( ErpToStr( hb_HGetDef( hCo, "currency", "" ) ) )
         endif
         // Company → apps (vertical packs); pick default for user/company
         hApp := ErpCompanyDefaultApp( hCo, hDoc )
         cAppId := AllTrim( ErpToStr( hb_HGetDef( hApp, "id", "" ) ) )
         cAppLab := AllTrim( ErpToStr( hb_HGetDef( hApp, "label", cAppId ) ) )
         cRel := AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) )
         cTok := hb_MD5( cUser + cDate + Time() + hb_ntos( Seconds() ) )
         if s_mtx != NIL
            hb_mutexLock( s_mtx )
         endif
         s_hSess[ cTok ] := { "user" => cUser, "workDate" => cDate, "sel" => 2, ;
            "ts" => hb_DateTime(), ;
            "role" => Lower( AllTrim( ErpToStr( hb_HGetDef( hDoc, "role", "user" ) ) ) ), ;
            "isAdmin" => ErpUserRowIsAdmin( hDoc ), ;
            "company" => cCo, ;
            "app" => cAppId, ;
            "appLabel" => cAppLab, ;
            "vertical" => cRel }
         if s_mtx != NIL
            hb_mutexUnlock( s_mtx )
         endif
         cOut := hb_jsonEncode( { "ok" => .T., "msg" => "Welcome, " + cUser, ;
            "user" => cUser, ;
            "role" => Lower( AllTrim( ErpToStr( hb_HGetDef( hDoc, "role", "user" ) ) ) ), ;
            "isAdmin" => ErpUserRowIsAdmin( hDoc ), ;
            "company" => cCo, "companyName" => cCoName, "currency" => cCur, ;
            "app" => cAppId, "appLabel" => cAppLab, "vertical" => cRel, ;
            "apps" => ErpCompanyAppsForUser( hCo, hDoc ), ;
            "companies" => ErpCompanyListForUser( hDoc ), ;
            "canSwitchCompany" => ErpUserCanSwitchCompany( hDoc ), ;
            "canSwitchApp" => ErpUserCanSwitchApp( hDoc, hCo ) } )
         return ErpHttpOkCookie( cOut, "application/json; charset=utf-8", ;
            "DWSESS=" + cTok + "; Path=/; HttpOnly; SameSite=Lax" )
      endif
      cOut := hb_jsonEncode( { "ok" => .F., ;
         "msg" => "Invalid credentials (manage users in Admin → Users)" } )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   if cMethod == "POST" .and. cPath == "/api/cmd"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated", ;
            "redirect" => "/login" } ), "application/json; charset=utf-8" )
      endif
      hQ := ErpQuery( cBody )
      cAction := Lower( AllTrim( hb_HGetDef( hQ, "action", "" ) ) )
      cArg := AllTrim( hb_HGetDef( hQ, "a1", "" ) )
      if cAction == "logout"
         ErpSessDel( cTok )
         // Always land on login page (same HTML as /)
         return ErpHttpOkCookie( hb_jsonEncode( { "ok" => .T., "redirect" => "/login" } ), ;
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
      elseif cAction == "workdate" .or. cAction == "work_date" .or. cAction == "work-date"
         // a1 = display date (DD/MM/YYYY etc.), optional a2 = ISO YYYY-MM-DD
         if Empty( cArg )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "work date required" } ), ;
               "application/json; charset=utf-8" )
         endif
         hSess[ "workDate" ] := cArg
         ErpSessPut( cTok, hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "workDate" => cArg } ), ;
            "application/json; charset=utf-8" )
      elseif cAction == "company" .or. cAction == "setcompany" .or. cAction == "set_company"
         // a1 = company code; optional a2 = app id within that company
         if Empty( cArg )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "company code required" } ), ;
               "application/json; charset=utf-8" )
         endif
         hDoc := ErpUserFind( ErpToStr( hb_HGetDef( hSess, "user", "" ) ) )
         hCo := ErpCompanyFind( cArg )
         if ValType( hCo ) != "H"
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "Unknown company: " + cArg } ), ;
               "application/json; charset=utf-8" )
         endif
         cCo := AllTrim( ErpToStr( hb_HGetDef( hCo, "code", cArg ) ) )
         // Non-admin: only companies granted in user.companies (+ defaultCompany)
         if ! ErpUserCanAccessCompany( hDoc, cCo )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "Not authorized to switch to company " + cCo } ), ;
               "application/json; charset=utf-8" )
         endif
         // Switching away from current company requires multi-company grant (or admin)
         if Upper( cCo ) != Upper( ErpSessCompany( hSess ) ) .and. ;
               ! ErpUserCanSwitchCompany( hDoc )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "Company switch not authorized for this user" } ), ;
               "application/json; charset=utf-8" )
         endif
         cAppId := AllTrim( ErpToStr( hb_HGetDef( hQ, "a2", "" ) ) )
         if ! Empty( cAppId )
            hApp := ErpCompanyFindApp( hCo, cAppId )
            // App must be authorized for this user (and linked on company)
            if ValType( hApp ) == "H" .and. ! ErpUserCanAccessApp( hDoc, ;
                  AllTrim( ErpToStr( hb_HGetDef( hApp, "id", cAppId ) ) ) ) .and. ;
                  ! ErpUserCanAccessApp( hDoc, cAppId )
               hApp := NIL
            endif
         else
            // Prefer session user's defaultApp if linked + authorized
            hApp := ErpCompanyDefaultApp( hCo, hDoc )
         endif
         if ValType( hApp ) != "H"
            hApp := ErpCompanyDefaultApp( hCo, hDoc )
         endif
         if ValType( hApp ) != "H"
            hApp := { "id" => "base", "label" => "Base modules", "vertical" => "" }
         endif
         cAppId := AllTrim( ErpToStr( hb_HGetDef( hApp, "id", "" ) ) )
         cAppLab := AllTrim( ErpToStr( hb_HGetDef( hApp, "label", cAppId ) ) )
         cRel := AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) )
         hSess[ "company" ] := cCo
         hSess[ "app" ] := cAppId
         hSess[ "appLabel" ] := cAppLab
         hSess[ "vertical" ] := cRel
         ErpSessPut( cTok, hSess )
         ErpMetaSetRequestVertical( cRel )
         // Remember for next login (user.defaultCompany / user.defaultApp)
         ErpUserSavePrefs( ErpToStr( hb_HGetDef( hSess, "user", "" ) ), cCo, cAppId )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .T., ;
            "company" => cCo, ;
            "companyName" => AllTrim( ErpToStr( hb_HGetDef( hCo, "name", cCo ) ) ), ;
            "currency" => AllTrim( ErpToStr( hb_HGetDef( hCo, "currency", "" ) ) ), ;
            "app" => cAppId, "appLabel" => cAppLab, "vertical" => cRel, ;
            "apps" => ErpCompanyAppsForUser( hCo, hDoc ), ;
            "companies" => ErpCompanyListForUser( hDoc ), ;
            "canSwitchCompany" => ErpUserCanSwitchCompany( hDoc ), ;
            "canSwitchApp" => ErpUserCanSwitchApp( hDoc, hCo ) } ), ;
            "application/json; charset=utf-8" )
      elseif cAction == "app" .or. cAction == "setapp" .or. cAction == "vertical"
         // a1 = app id (or vertical name) within current company
         if Empty( cArg )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "app id required" } ), ;
               "application/json; charset=utf-8" )
         endif
         hDoc := ErpUserFind( ErpToStr( hb_HGetDef( hSess, "user", "" ) ) )
         cCo := ErpSessCompany( hSess )
         hCo := ErpCompanyFind( cCo )
         hApp := ErpCompanyFindApp( hCo, cArg )
         if ValType( hApp ) != "H"
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "App not linked to company " + cCo + ": " + cArg } ), ;
               "application/json; charset=utf-8" )
         endif
         cAppId := AllTrim( ErpToStr( hb_HGetDef( hApp, "id", cArg ) ) )
         // Non-admin: only apps granted in user.apps (+ defaultApp)
         if ! ErpUserCanAccessApp( hDoc, cAppId ) .and. ;
               ! ErpUserCanAccessApp( hDoc, AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) ) )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "Not authorized to switch to app " + cAppId } ), ;
               "application/json; charset=utf-8" )
         endif
         // Switching away from current app requires multi-app grant (or admin)
         if Upper( cAppId ) != Upper( ErpSessApp( hSess ) ) .and. ;
               Upper( AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) ) ) != ;
                  Upper( ErpSessVertical( hSess ) ) .and. ;
               ! ErpUserCanSwitchApp( hDoc, hCo )
            return ErpHttpOk( hb_jsonEncode( { "ok" => .F., ;
               "msg" => "App / vertical switch not authorized for this user" } ), ;
               "application/json; charset=utf-8" )
         endif
         cAppLab := AllTrim( ErpToStr( hb_HGetDef( hApp, "label", cAppId ) ) )
         cRel := AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) )
         hSess[ "app" ] := cAppId
         hSess[ "appLabel" ] := cAppLab
         hSess[ "vertical" ] := cRel
         ErpSessPut( cTok, hSess )
         ErpMetaSetRequestVertical( cRel )
         // Remember for next login (user.defaultApp + current company)
         ErpUserSavePrefs( ErpToStr( hb_HGetDef( hSess, "user", "" ) ), cCo, cAppId )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .T., ;
            "company" => cCo, ;
            "companyName" => iif( ValType( hCo ) == "H", ;
               AllTrim( ErpToStr( hb_HGetDef( hCo, "name", cCo ) ) ), cCo ), ;
            "app" => cAppId, "appLabel" => cAppLab, "vertical" => cRel, ;
            "apps" => ErpCompanyAppsForUser( hCo, hDoc ), ;
            "canSwitchApp" => ErpUserCanSwitchApp( hDoc, hCo ), ;
            "canSwitchCompany" => ErpUserCanSwitchCompany( hDoc ) } ), ;
            "application/json; charset=utf-8" )
      endif
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., "toast" => "Action: " + cArg } ), ;
         "application/json; charset=utf-8" )
   endif

   // Multi-company + multi-app context
   if cMethod == "GET" .and. cPath == "/api/context"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      hDoc := ErpUserFind( ErpToStr( hb_HGetDef( hSess, "user", "" ) ) )
      cCo := ErpSessCompany( hSess )
      if Empty( cCo ) .or. ! ErpUserCanAccessCompany( hDoc, cCo )
         cCo := ErpCompanyDefaultForUser( hDoc )
         hSess[ "company" ] := cCo
      endif
      hCo := ErpCompanyFind( cCo )
      cCoName := cCo
      cCur := ""
      if ValType( hCo ) == "H"
         cCoName := AllTrim( ErpToStr( hb_HGetDef( hCo, "name", cCo ) ) )
         cCur := AllTrim( ErpToStr( hb_HGetDef( hCo, "currency", "" ) ) )
      endif
      cAppId := ErpSessApp( hSess )
      hApp := NIL
      if ! Empty( cAppId )
         hApp := ErpCompanyFindApp( hCo, cAppId )
         // Drop session app if user is no longer authorized for it
         if ValType( hApp ) == "H" .and. ! ErpUserCanAccessApp( hDoc, ;
               AllTrim( ErpToStr( hb_HGetDef( hApp, "id", cAppId ) ) ) ) .and. ;
               ! ErpUserCanAccessApp( hDoc, AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) ) )
            hApp := NIL
         endif
      endif
      if ValType( hApp ) != "H"
         hApp := ErpCompanyDefaultApp( hCo, hDoc )
         cAppId := AllTrim( ErpToStr( hb_HGetDef( hApp, "id", "" ) ) )
         hSess[ "app" ] := cAppId
         hSess[ "appLabel" ] := AllTrim( ErpToStr( hb_HGetDef( hApp, "label", cAppId ) ) )
         hSess[ "vertical" ] := AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) )
      endif
      cAppLab := AllTrim( ErpToStr( hb_HGetDef( hSess, "appLabel", ;
         hb_HGetDef( hApp, "label", cAppId ) ) ) )
      cRel := AllTrim( ErpToStr( hb_HGetDef( hSess, "vertical", ;
         hb_HGetDef( hApp, "vertical", "" ) ) ) )
      hSess[ "company" ] := cCo
      hSess[ "app" ] := cAppId
      hSess[ "appLabel" ] := cAppLab
      hSess[ "vertical" ] := cRel
      ErpSessPut( cTok, hSess )
      ErpMetaSetRequestVertical( cRel )
      return ErpHttpOk( hb_jsonEncode( { "ok" => .T., ;
         "company" => cCo, ;
         "companyName" => cCoName, ;
         "currency" => cCur, ;
         "app" => cAppId, ;
         "appLabel" => cAppLab, ;
         "vertical" => cRel, ;
         "apps" => ErpCompanyAppsForUser( hCo, hDoc ), ;
         "companies" => ErpCompanyListForUser( hDoc ), ;
         "canSwitchCompany" => ErpUserCanSwitchCompany( hDoc ), ;
         "canSwitchApp" => ErpUserCanSwitchApp( hDoc, hCo ), ;
         "isAdmin" => ErpSessIsAdmin( hSess ), ;
         "allVerticals" => ErpMetaVerticals() } ), ;
         "application/json; charset=utf-8" )
   endif

   if cMethod == "GET" .and. cPath == "/api/verticals"
      if Empty( hSess )
         return ErpHttpOk( hb_jsonEncode( { "ok" => .F., "msg" => "Not authenticated" } ), ;
            "application/json; charset=utf-8" )
      endif
      cOut := hb_jsonEncode( { "ok" => .T., "items" => ErpMetaVerticals(), ;
         "current" => iif( ! Empty( ErpSessVertical( hSess ) ), ErpSessVertical( hSess ), ;
            ErpToStr( hb_HGetDef( ErpMetaGet( "app" ), "vertical", "" ) ) ) } )
      return ErpHttpOk( cOut, "application/json; charset=utf-8" )
   endif

   // static www assets (path traversal guard: URL-decode first, reject "..")
   if Left( cPath, 1 ) == "/"
      cRel := ErpUrlDecode( cPath )
      if ".." $ cRel
         return ErpHttpForbidden( cPath )
      endif
      cFile := hb_DirBase() + "www" + StrTran( cRel, "/", hb_ps() )
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
   local cHtml

   if ! File( cFile )
      return "<!DOCTYPE html><html><body><h1>login.html missing</h1>" + ;
         "<p>Run _extract_fwh_html.py</p></body></html>"
   endif
   cHtml := MemoRead( cFile )
   // Same placeholders as dashboard (login only uses version for now)
   cHtml := StrTran( cHtml, "__APPVER__", ErpAppVersion() )
return cHtml

//--------------------------------------------------------------------
// Version string for status bar (__APPVER__)
static function ErpAppVersion()

   local hApp := ErpMetaGet( "app" )
   local cVer := ""

   if ValType( hApp ) == "H"
      cVer := AllTrim( ErpToStr( hb_HGetDef( hApp, "version", "" ) ) )
   endif
   if Empty( cVer )
      cVer := "1.0.0"
   endif
return cVer

//--------------------------------------------------------------------
// Minimal DB status from app.database when ErpDbStatus() is unavailable
static function ErpDbStatusFromApp()

   local hApp := ErpMetaGet( "app" )
   local hDb := { => }
   local cDriver := "json", cBackend := "", cHost := "", cPath := ""
   local nPort := 0

   if ValType( hApp ) == "H" .and. hb_HHasKey( hApp, "database" ) .and. ;
         ValType( hApp[ "database" ] ) == "H"
      hDb := hApp[ "database" ]
      cDriver := Lower( AllTrim( ErpToStr( hb_HGetDef( hDb, "driver", "json" ) ) ) )
      cBackend := Lower( AllTrim( ErpToStr( hb_HGetDef( hDb, "backend", "" ) ) ) )
      cHost := AllTrim( ErpToStr( hb_HGetDef( hDb, "host", "" ) ) )
      nPort := Val( ErpToStr( hb_HGetDef( hDb, "port", "0" ) ) )
      cPath := AllTrim( ErpToStr( hb_HGetDef( hDb, "dataPath", "" ) ) )
   endif
   if Empty( cDriver )
      cDriver := "json"
   endif
return { "ok" => .T., ;
   "driver"   => cDriver, ;
   "backend"  => cBackend, ;
   "host"     => cHost, ;
   "port"     => nPort, ;
   "dataPath" => cPath, ;
   "dbfDir"   => "", ;
   "tables"   => {}, ;
   "openadsAvailable" => .F., ;
   "lastError" => "", ;
   "fromApp"  => .T. }

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

   // App version from meta/app.json when available
   cHtml := StrTran( cHtml, "__APPVER__", ErpAppVersion() )
   cHtml := StrTran( cHtml, "__USER__", cUser )
   cHtml := StrTran( cHtml, "__WORKDATE__", cWorkDate )
   cHtml := StrTran( cHtml, "__AVATAR__", cAv )
   cHtml := StrTran( cHtml, "__SEL__", hb_ntos( nSel ) )
   cHtml := StrTran( cHtml, "__APPTDATA__", ErpApptDataJson() )
   cHtml := StrTran( cHtml, "__IS_ADMIN__", ;
      iif( ErpUserCodeIsAdmin( cUser ), "true", "false" ) )
   cHtml := StrTran( cHtml, "__BODY_ADMIN_CLASS__", ;
      iif( ErpUserCodeIsAdmin( cUser ), "is-admin", "" ) )
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
   local nTtl

   if Empty( cTok )
      return NIL
   endif
   nTtl := ErpSessTtlMin()
   if s_mtx != NIL
      hb_mutexLock( s_mtx )
   endif
   if hb_HHasKey( s_hSess, cTok )
      h := s_hSess[ cTok ]
      if ValType( h ) == "H" .and. hb_HHasKey( h, "ts" ) .and. ;
            ( hb_DateTime() - h[ "ts" ] ) * 1440 > nTtl
         // expired (sessions.ttlMinutes in app.json) — destroy it
         hb_HDel( s_hSess, cTok )
         h := NIL
      elseif ValType( h ) == "H"
         h[ "ts" ] := hb_DateTime()  // sliding renewal on each valid hit
      endif
   endif
   if s_mtx != NIL
      hb_mutexUnlock( s_mtx )
   endif
return h

//--------------------------------------------------------------------
// sessions.ttlMinutes from app.json (fallback 480)
static function ErpSessTtlMin()

   local hApp := ErpMetaGet( "app" ), hSes, n := 480

   if ValType( hApp ) == "H" .and. hb_HHasKey( hApp, "sessions" )
      hSes := hApp[ "sessions" ]
      if ValType( hSes ) == "H" .and. hb_HHasKey( hSes, "ttlMinutes" )
         n := Val( ErpToStr( hSes[ "ttlMinutes" ] ) )
      endif
   endif
   if n <= 0
      n := 480
   endif
return n

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
