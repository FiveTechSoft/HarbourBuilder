// erp_meta.prg — load meta JSON from disk (shared with FWH DesktopWeb / FiveTech_ERP)
//--------------------------------------------------------------------

static s_hMeta := { => }
static s_cRoot := ""

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

   // Exact copy of FWH DesktopWeb meta (sync via build_win64.bat / sync_meta.bat)
   cTry := cBase + "meta" + hb_ps()
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif

   // Live FWH tree (dev machine) — same files, no local copy yet
   cTry := "C:\fwteam\samples\DesktopWeb\meta\"
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif

   // Legacy junction name
   cTry := cBase + "meta_fwh" + hb_ps()
   if hb_DirExists( cTry ) .and. File( cTry + "app.json" )
      s_cRoot := cTry
      return s_cRoot
   endif

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
   case Left( cKey, 7 ) == "screen." ; return "screens" + hb_ps() + SubStr( cKey, 8 ) + ".json"
   case Left( cKey, 5 ) == "data."   ; return "data" + hb_ps() + SubStr( cKey, 6 ) + ".json"
   case Left( cKey, 7 ) == "lookup." ; return "lookups" + hb_ps() + SubStr( cKey, 8 ) + ".json"
   case Left( cKey, 7 ) == "report." ; return "reports" + hb_ps() + SubStr( cKey, 8 ) + ".json"
   case Left( cKey, 5 ) == "demo."   ; return "demo" + hb_ps() + SubStr( cKey, 6 ) + ".json"
   endcase
return ""

//--------------------------------------------------------------------
// Raw UTF-8 JSON text from disk (no decode/encode). Prefer for HTTP responses
// so multi-byte chars (€, ↔, accents) stay valid for the browser JSON.parse.
function ErpMetaGetRaw( cKey )

   local cRel, cFull, cJson

   cKey := AllTrim( cKey )
   if Empty( cKey )
      return ""
   endif

   cRel := MetaDefaultPath( cKey )
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

   cKey := AllTrim( cKey )
   if Empty( cKey )
      return h
   endif

   if hb_HHasKey( s_hMeta, cKey )
      return s_hMeta[ cKey ]
   endif

   cRel := MetaDefaultPath( cKey )
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

   s_hMeta[ cKey ] := h
return h

//--------------------------------------------------------------------
function ErpMetaCatalog()

   local aList := {}
   local aDir, aItem, cName, cBase, nDot, cKey, h
   local cRoot := ErpMetaRoot()
   local aPairs := { ;
      { "screens" + hb_ps(), "screen." }, ;
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
               "title" => iif( hb_HHasKey( h, "title" ), ErpToStr( h[ "title" ] ), cKey ) } )
         endif
      next
   next

return aList

//--------------------------------------------------------------------
function ErpMetaClearCache()
   s_hMeta := { => }
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
