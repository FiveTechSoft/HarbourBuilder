// erp_proc.prg — server-side business processes (whitelist handlers)
// Meta JSON process.* names a registered handler; the browser never executes code.
//--------------------------------------------------------------------

//--------------------------------------------------------------------
// Catalog of compiled handlers (id is the value stored in process.handler).
function ErpProcHandlers()

   local a := {}

   AAdd( a, { "id" => "Hello", ;
      "title" => "Hello (demo)", ;
      "desc" => "Returns a greeting with user and work date." } )
   AAdd( a, { "id" => "EchoContext", ;
      "title" => "Echo context", ;
      "desc" => "Echoes session + screen + selected row keys (debug)." } )
   AAdd( a, { "id" => "PingStatus", ;
      "title" => "Ping status", ;
      "desc" => "Lightweight health check of the process engine." } )
return a

//--------------------------------------------------------------------
function ErpProcHandlerOk( cId )

   local a := ErpProcHandlers(), h

   cId := AllTrim( ErpToStr( cId ) )
   if Empty( cId )
      return .F.
   endif
   for each h in a
      if Upper( AllTrim( ErpToStr( hb_HGetDef( h, "id", "" ) ) ) ) == Upper( cId )
         return .T.
      endif
   next
return .F.

//--------------------------------------------------------------------
// Run a whitelist handler. hCtx keys: user, workDate, screenKey, dataRef,
// row (hash or NIL), params (hash), processKey, processTitle.
// Always returns a hash { ok, msg, data? }.
function ErpProcRun( cHandler, hCtx )

   local hOut := { "ok" => .F., "msg" => "Unknown handler" }
   local cId := AllTrim( ErpToStr( cHandler ) )

   if Empty( cId )
      return { "ok" => .F., "msg" => "Handler required" }
   endif
   if ! ErpProcHandlerOk( cId )
      return { "ok" => .F., "msg" => "Handler not registered: " + cId }
   endif
   if ValType( hCtx ) != "H"
      hCtx := { => }
   endif

   do case
   case Upper( cId ) == "HELLO"
      hOut := ErpProc_Hello( hCtx )
   case Upper( cId ) == "ECHOCONTEXT"
      hOut := ErpProc_EchoContext( hCtx )
   case Upper( cId ) == "PINGSTATUS"
      hOut := ErpProc_PingStatus( hCtx )
   otherwise
      hOut := { "ok" => .F., "msg" => "Handler not implemented: " + cId }
   endcase

   if ValType( hOut ) != "H"
      return { "ok" => .F., "msg" => "Handler returned invalid result" }
   endif
   if ! hb_HHasKey( hOut, "ok" )
      hOut[ "ok" ] := .T.
   endif
   if ! hb_HHasKey( hOut, "msg" )
      hOut[ "msg" ] := iif( hOut[ "ok" ], "OK", "Failed" )
   endif
return hOut

//--------------------------------------------------------------------
static function ErpProc_Hello( hCtx )

   local cUser := AllTrim( ErpToStr( hb_HGetDef( hCtx, "user", "" ) ) )
   local cWd := AllTrim( ErpToStr( hb_HGetDef( hCtx, "workDate", "" ) ) )
   local cTitle := AllTrim( ErpToStr( hb_HGetDef( hCtx, "processTitle", "Hello" ) ) )
   local cMsg

   if Empty( cUser )
      cUser := "user"
   endif
   cMsg := cTitle + ": Hello, " + cUser
   if ! Empty( cWd )
      cMsg += " — work date " + cWd
   endif
return { "ok" => .T., "msg" => cMsg, ;
   "data" => { "user" => cUser, "workDate" => cWd } }

//--------------------------------------------------------------------
static function ErpProc_EchoContext( hCtx )

   local hRow := hb_HGetDef( hCtx, "row", NIL )
   local hParams := hb_HGetDef( hCtx, "params", { => } )
   local aKeys := {}, cK, hData

   if ValType( hRow ) == "H"
      for each cK in hb_HKeys( hRow )
         AAdd( aKeys, ErpToStr( cK ) )
      next
   endif
   hData := { ;
      "user" => ErpToStr( hb_HGetDef( hCtx, "user", "" ) ), ;
      "workDate" => ErpToStr( hb_HGetDef( hCtx, "workDate", "" ) ), ;
      "screenKey" => ErpToStr( hb_HGetDef( hCtx, "screenKey", "" ) ), ;
      "dataRef" => ErpToStr( hb_HGetDef( hCtx, "dataRef", "" ) ), ;
      "processKey" => ErpToStr( hb_HGetDef( hCtx, "processKey", "" ) ), ;
      "rowKeys" => aKeys, ;
      "paramCount" => iif( ValType( hParams ) == "H", Len( hb_HKeys( hParams ) ), 0 ) }
return { "ok" => .T., "msg" => "Context echoed", "data" => hData }

//--------------------------------------------------------------------
static function ErpProc_PingStatus( hCtx )

   HB_SYMBOL_UNUSED( hCtx )
return { "ok" => .T., "msg" => "Process engine OK", ;
   "data" => { "handlers" => Len( ErpProcHandlers() ), ;
      "ts" => DToC( Date() ) + " " + Time() } }
