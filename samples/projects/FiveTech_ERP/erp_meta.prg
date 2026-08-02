// erp_meta.prg — load meta JSON from disk (shared with FWH DesktopWeb / FiveTech_ERP)
//--------------------------------------------------------------------

static s_hMeta := { => }
static s_cRoot := ""
// MT HTTP server: protect s_hMeta (ErpMetaGet / ErpMetaClearCache / invalidate)
static s_mtxMeta := hb_MutexCreate()
// Per-request vertical override (HTTP session company-app). Empty = use app.vertical.
static s_cReqVertical := ""

//--------------------------------------------------------------------
function ErpMetaRoot()

   local cBase := hb_DirBase()
   local cTry

   if ! Empty( s_cRoot )
      return s_cRoot
   endif

   if Right( cBase, 1 ) $ "/\"
      // ok
   else
      cBase += hb_ps()
   endif

   // 1) ./meta next to the executable (exact FWH DesktopWeb JSON tree)
   cTry := cBase + "meta" + hb_ps()
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif

   // 2) Inside .app bundle Resources (macOS)
   cTry := cBase + ".." + hb_ps() + "Resources" + hb_ps() + "meta" + hb_ps()
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif

   // 3) Legacy junction name
   cTry := cBase + "meta_fwh" + hb_ps()
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif

#ifdef __PLATFORM__WINDOWS
   // 4) Windows dev: live FWH tree
   cTry := "C:\fwteam\samples\DesktopWeb\meta\"
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif
#endif

   s_cRoot := cBase + "meta" + hb_ps()
return s_cRoot

//--------------------------------------------------------------------
static function MetaStripBom( c )

   if ValType( c ) != "C" .or. Empty( c )
      return c
   endif
   if Len( c ) >= 3 .and. Asc( SubStr( c, 1, 1 ) ) == 0xEF .and. ;
         Asc( SubStr( c, 2, 1 ) ) == 0xBB .and. Asc( SubStr( c, 3, 1 ) ) == 0xBF
      return SubStr( c, 4 )
   endif
return c

//--------------------------------------------------------------------
// Binary file read (avoid any text-mode translation of multi-byte UTF-8).
static function MetaReadFile( cFull )

   local nH, nSize, cBuf := ""

   nH := FOpen( cFull, 64 )  // FO_READ + FO_SHARED
   if nH < 0
      // fallback
      return MemoRead( cFull )
   endif
   nSize := FSeek( nH, 0, 2 )
   FSeek( nH, 0, 0 )
   if nSize > 0
      cBuf := Space( nSize )
      FRead( nH, @cBuf, nSize )
      cBuf := Left( cBuf, nSize )
   endif
   FClose( nH )
return cBuf

//--------------------------------------------------------------------
static function MetaTrimAscii( c )

   local cWS := " " + Chr( 9 ) + Chr( 10 ) + Chr( 13 )

   if ValType( c ) != "C"
      return ""
   endif
   while Len( c ) > 0 .and. Left( c, 1 ) $ cWS
      c := SubStr( c, 2 )
   enddo
   while Len( c ) > 0 .and. Right( c, 1 ) $ cWS
      c := Left( c, Len( c ) - 1 )
   enddo
return c

//--------------------------------------------------------------------
static function MetaDefaultPath( cKey )

   cKey := AllTrim( cKey )
   do case
   case cKey == "app"     ; return "app.json"
   case cKey == "modules" ; return "modules.json"
   case cKey == "theme"   ; return "theme.json"
   case cKey == "demo.main" ; return "demo.json"
   case Left( cKey, 7 ) == "screen."  ; return "screens" + hb_ps() + SubStr( cKey, 8 ) + ".json"
   case Left( cKey, 8 ) == "process." ; return "processes" + hb_ps() + SubStr( cKey, 9 ) + ".json"
   case Left( cKey, 5 ) == "data."    ; return "data" + hb_ps() + SubStr( cKey, 6 ) + ".json"
   case Left( cKey, 7 ) == "lookup."  ; return "lookups" + hb_ps() + SubStr( cKey, 8 ) + ".json"
   case Left( cKey, 7 ) == "report."  ; return "reports" + hb_ps() + SubStr( cKey, 8 ) + ".json"
   case Left( cKey, 5 ) == "demo."    ; return "demo" + hb_ps() + SubStr( cKey, 6 ) + ".json"
   endcase
return ""

//--------------------------------------------------------------------
// Charset guard for vertical pack names (no traversal via app.vertical).
static function MetaNameSafe( cName )

   local n, cCh

   cName := AllTrim( ErpToStr( cName ) )
   if Empty( cName )
      return .F.
   endif
   for n := 1 to Len( cName )
      cCh := SubStr( cName, n, 1 )
      if ! ( cCh >= "A" .and. cCh <= "Z" ) .and. ! ( cCh >= "a" .and. cCh <= "z" ) .and. ;
         ! ( cCh >= "0" .and. cCh <= "9" ) .and. ! cCh $ "_-"
         return .F.
      endif
   next
return .T.

//--------------------------------------------------------------------
// Set vertical pack for this request/thread (used by multi-company apps).
// Clears modules cache so the next modules read uses the new path.
function ErpMetaSetRequestVertical( cVert )

   cVert := AllTrim( ErpToStr( cVert ) )
   if ! Empty( cVert ) .and. ! MetaNameSafe( cVert )
      cVert := ""
   endif
   if s_cReqVertical != cVert
      s_cReqVertical := cVert
      ErpMetaInvalidate( "modules" )
   endif
return s_cReqVertical

//--------------------------------------------------------------------
function ErpMetaRequestVertical()
return s_cReqVertical

//--------------------------------------------------------------------
// Vertical-aware "modules" resolution:
//  1) per-request vertical (session company-app)
//  2) app.vertical in app.json
//  3) base modules.json
// With a pack file present: meta/verticals/<name>/modules.json
static function MetaModulesRel()

   local cJson, hApp := { => }, cVert := "", cTry

   // 1) request / session override (company → app vertical)
   cVert := AllTrim( s_cReqVertical )
   if Empty( cVert )
      cJson := ErpMetaGetRaw( "app" )
      if ! Empty( cJson )
         hb_jsonDecode( cJson, @hApp )
      endif
      if ValType( hApp ) == "H"
         cVert := AllTrim( ErpToStr( hb_HGetDef( hApp, "vertical", "" ) ) )
      endif
   endif
   if ! Empty( cVert ) .and. MetaNameSafe( cVert )
      cTry := "verticals" + hb_ps() + cVert + hb_ps() + "modules.json"
      if File( ErpMetaRoot() + cTry )
         return cTry
      endif
   endif
return "modules.json"

//--------------------------------------------------------------------
// MetaDefaultPath + vertical override for the "modules" key.
static function MetaKeyRelPath( cKey )

   local cRel := MetaDefaultPath( cKey )

   if AllTrim( cKey ) == "modules"
      cRel := MetaModulesRel()
   endif
return cRel

//--------------------------------------------------------------------
// Raw UTF-8 JSON text from disk (no decode/encode). Prefer for HTTP responses
// so multi-byte chars (€, ↔, accents) stay valid for the browser JSON.parse.
function ErpMetaGetRaw( cKey )

   local cRel, cFull, cJson

   cKey := AllTrim( cKey )
   if Empty( cKey )
      return ""
   endif

   cRel := MetaKeyRelPath( cKey )
   if Empty( cRel )
      return ""
   endif

   cFull := ErpMetaRoot() + cRel
   if ! File( cFull )
      return ""
   endif

   // MemoRead is fine for binary-safe byte strings in Harbour; keep UTF-8 as-is.
   cJson := MetaStripBom( MemoRead( cFull ) )
   if Empty( cJson )
      return ""
   endif

return MetaTrimAscii( cJson )

//--------------------------------------------------------------------
function ErpMetaGet( cKey )

   local h := { => }
   local cRel, cFull, cJson
   local lCached := .F.

   cKey := AllTrim( cKey )
   if Empty( cKey )
      return h
   endif

   // cache lookup under mutex (disk read stays outside the lock)
   hb_MutexLock( s_mtxMeta )
   if hb_HHasKey( s_hMeta, cKey )
      h := s_hMeta[ cKey ]
      lCached := .T.
   endif
   hb_MutexUnlock( s_mtxMeta )
   if lCached
      return h
   endif

   cRel := MetaKeyRelPath( cKey )
   if Empty( cRel )
      return h
   endif

   cFull := ErpMetaRoot() + cRel
   if ! File( cFull )
      return h
   endif

   cJson := MetaStripBom( MemoRead( cFull ) )
   if Empty( cJson )
      return h
   endif

   hb_jsonDecode( cJson, @h )
   if ValType( h ) != "H"
      return { => }
   endif

   hb_MutexLock( s_mtxMeta )
   s_hMeta[ cKey ] := h
   hb_MutexUnlock( s_mtxMeta )
return h

//--------------------------------------------------------------------
function ErpMetaCatalog()

   local aList := {}
   local aDir, aItem, cName, cBase, nDot, cKey, h
   local cRoot := ErpMetaRoot()
   local aPairs := { ;
      { "screens" + hb_ps(), "screen." }, ;
      { "processes" + hb_ps(), "process." }, ;
      { "data" + hb_ps(), "data." }, ;
      { "lookups" + hb_ps(), "lookup." }, ;
      { "reports" + hb_ps(), "report." } }
   local aP

   // root docs
   for each cKey in { "app", "modules", "theme", "demo.main" }
      h := ErpMetaGet( cKey )
      if ValType( h ) == "H" .and. ! Empty( hb_HKeys( h ) )
         AAdd( aList, { "key" => cKey, ;
            "kind" => iif( hb_HHasKey( h, "kind" ), ErpToStr( h[ "kind" ] ), "meta" ), ;
            "title" => iif( hb_HHasKey( h, "title" ), ErpToStr( h[ "title" ] ), cKey ) } )
      endif
   next

   for each aP in aPairs
      if ! hb_DirExists( cRoot + aP[ 1 ] )
         loop
      endif
      aDir := Directory( cRoot + aP[ 1 ] + "*.json" )
      for each aItem in aDir
         cName := AllTrim( ErpToStr( aItem[ 1 ] ) )
         if Empty( cName ) .or. "D" $ Upper( ErpToStr( aItem[ 5 ] ) )
            loop
         endif
         nDot := RAt( ".", cName )
         cBase := iif( nDot > 1, Left( cName, nDot - 1 ), cName )
         cKey := aP[ 2 ] + cBase
         h := ErpMetaGet( cKey )
         if ValType( h ) == "H" .and. ! Empty( hb_HKeys( h ) )
            AAdd( aList, { "key" => cKey, ;
               "kind" => iif( hb_HHasKey( h, "kind" ), ErpToStr( h[ "kind" ] ), Left( aP[ 2 ], Len( aP[ 2 ] ) - 1 ) ), ;
               "title" => iif( hb_HHasKey( h, "title" ), ErpToStr( h[ "title" ] ), cKey ), ;
               "layout" => iif( hb_HHasKey( h, "layout" ), ErpToStr( h[ "layout" ] ), "" ), ;
               "dataRef" => iif( hb_HHasKey( h, "dataRef" ), ErpToStr( h[ "dataRef" ] ), "" ), ;
               "handler" => iif( hb_HHasKey( h, "handler" ), ErpToStr( h[ "handler" ] ), "" ) } )
         endif
      next
   next

return aList

//--------------------------------------------------------------------
// Vertical packs available on disk: subfolders of meta/verticals that
// contain a modules.json. Scanned live (no cache) so new packs appear
// without restarting the app.
function ErpMetaVerticals()

   local aOut := {}
   local cDir := ErpMetaRoot() + "verticals" + hb_ps()
   local aDir, aItem, cName

   if hb_DirExists( cDir )
      aDir := Directory( cDir + "*.*", "D" )
      for each aItem in aDir
         cName := AllTrim( ErpToStr( aItem[ 1 ] ) )
         if Empty( cName ) .or. cName == "." .or. cName == ".."
            loop
         endif
         if ! "D" $ Upper( ErpToStr( aItem[ 5 ] ) )
            loop
         endif
         if File( cDir + cName + hb_ps() + "modules.json" )
            AAdd( aOut, cName )
         endif
      next
   endif
   ASort( aOut )
return aOut

//--------------------------------------------------------------------
function ErpMetaClearCache()
   hb_MutexLock( s_mtxMeta )
   s_hMeta := { => }
   hb_MutexUnlock( s_mtxMeta )
return nil

//--------------------------------------------------------------------
// Full path on disk for a meta key ("" if the key has no known mapping).
// Public wrapper around MetaDefaultPath() for the HTTP POST handlers.
function ErpMetaPathForKey( cKey )

   local cRel := MetaKeyRelPath( cKey )

   if Empty( cRel )
      return ""
   endif
return ErpMetaRoot() + cRel

//--------------------------------------------------------------------
// Drop one key from the cache (POST /api/meta and /api/dataset use it
// after writing the JSON file so the next GET re-reads from disk).
function ErpMetaInvalidate( cKey )

   cKey := AllTrim( ErpToStr( cKey ) )
   if Empty( cKey )
      return nil
   endif
   hb_MutexLock( s_mtxMeta )
   if hb_HHasKey( s_hMeta, cKey )
      hb_HDel( s_hMeta, cKey )
   endif
   hb_MutexUnlock( s_mtxMeta )
return nil

//--------------------------------------------------------------------
// Put/replace one decoded doc in the cache (POST /api/meta writeFile:false —
// memory-only designer save, no file write).
function ErpMetaCachePut( cKey, hDoc )

   cKey := AllTrim( ErpToStr( cKey ) )
   if Empty( cKey ) .or. ValType( hDoc ) != "H"
      return nil
   endif
   hb_MutexLock( s_mtxMeta )
   s_hMeta[ cKey ] := hDoc
   hb_MutexUnlock( s_mtxMeta )
return nil

//--------------------------------------------------------------------
function ErpToStr( x )

   do case
   case ValType( x ) == "C" ; return x
   case ValType( x ) == "N" ; return hb_ntos( x )
   case ValType( x ) == "L" ; return iif( x, "T", "F" )
   case ValType( x ) == "D" ; return DToC( x )
   endcase
return ""
