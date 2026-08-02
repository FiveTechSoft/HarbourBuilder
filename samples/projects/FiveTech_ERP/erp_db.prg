// erp_db.prg — selectable data layer for FiveTech_ERP
// driver: json (default, meta/data/*.json) | dbfcdx (local <exedir>/data) |
//         openads (remote OpenADS server via rddads tcp://host:port/dataPath)
// Config lives in meta/app.json -> "database" (saved by the UI via POST /api/meta).
//--------------------------------------------------------------------

REQUEST DBFCDX
REQUEST ADS, ADSCDX

// ads.ch constants (avoid the extra include path — same values as
// C:\harbour\contrib\rddads\ads.ch and the OpenADS smoke tests)
#define ADS_CDX            2
#define ADS_REMOTE_SERVER  2

static s_mtxDb := hb_MutexCreate()
static s_hAdsConn := 0
static s_cDbErr := ""        // last data-layer error (diagnostics via /api/db/status)

//--------------------------------------------------------------------
// app.json -> "database" with defaults. No own cache: ErpMetaGet() already
// caches and the POST /api/meta handler invalidates on save.
function ErpDbConfig()

   local h := { "driver" => "json", "backend" => "dbfcdx", "host" => "", ;
      "port" => 0, "dataPath" => "", "user" => "", "password" => "" }
   local hApp := ErpMetaGet( "app" ), hDb

   if ValType( hApp ) == "H" .and. hb_HHasKey( hApp, "database" )
      hDb := hApp[ "database" ]
      if ValType( hDb ) == "H"
         if hb_HHasKey( hDb, "driver" )    ; h[ "driver" ]    := Lower( AllTrim( ErpToStr( hDb[ "driver" ] ) ) ) ; endif
         if hb_HHasKey( hDb, "backend" )   ; h[ "backend" ]   := Lower( AllTrim( ErpToStr( hDb[ "backend" ] ) ) ) ; endif
         if hb_HHasKey( hDb, "host" )      ; h[ "host" ]      := AllTrim( ErpToStr( hDb[ "host" ] ) ) ; endif
         if hb_HHasKey( hDb, "port" )      ; h[ "port" ]      := Val( ErpToStr( hDb[ "port" ] ) ) ; endif
         if hb_HHasKey( hDb, "dataPath" )  ; h[ "dataPath" ]  := AllTrim( ErpToStr( hDb[ "dataPath" ] ) ) ; endif
         if hb_HHasKey( hDb, "user" )      ; h[ "user" ]      := ErpToStr( hDb[ "user" ] ) ; endif
         if hb_HHasKey( hDb, "password" )  ; h[ "password" ]  := ErpToStr( hDb[ "password" ] ) ; endif
      endif
   endif
   if Empty( h[ "driver" ] )
      h[ "driver" ] := "json"
   endif
return h

//--------------------------------------------------------------------
function ErpDbDriver()
return hb_HGetDef( ErpDbConfig(), "driver", "json" )

//--------------------------------------------------------------------
// Local DBF dir: <exedir>/data\  (NEVER meta\ — sync_meta.bat mirrors it)
function ErpDbDataDir()

   local cDir := hb_DirBase()

   if ! ( Right( cDir, 1 ) $ "/\" )
      cDir += hb_ps()
   endif
return cDir + "data" + hb_ps()

//--------------------------------------------------------------------
// "data.patients" -> "patients" ("" if not a data.* key)
static function ErpDbDataName( cDataKey )

   cDataKey := AllTrim( ErpToStr( cDataKey ) )
   if Left( cDataKey, 5 ) != "data." .or. Len( cDataKey ) <= 5
      return ""
   endif
return SubStr( cDataKey, 6 )

//--------------------------------------------------------------------
// rddads is linked into this build (REQUEST ADS/ADSCDX above); the ACE
// client DLL is delay-loaded, so the exe runs without it — OpenADS only
// works when ace64.dll sits next to the exe.
function ErpDbAdsAvailable()
return File( hb_DirBase() + "ace64.dll" )

//--------------------------------------------------------------------
// Lazy one-time remote connection; the handle stays in s_hAdsConn and is
// reused by every open. Call with s_mtxDb held.
static function ErpDbAdsConnect()

   local hCfg, cUri, hConn := 0

   if s_hAdsConn != 0
      return .T.
   endif
   hCfg := ErpDbConfig()
   if Empty( hCfg[ "host" ] )
      return .F.
   endif
   // tcp://host:port/<dataPath> — absolute POSIX dataPath keeps its leading
   // slash, giving the double slash seen in the OpenADS samples:
   // tcp://192.168.18.184:16262//tmp/openads_mac
   cUri := "tcp://" + hCfg[ "host" ]
   if hCfg[ "port" ] > 0
      cUri += ":" + hb_ntos( hCfg[ "port" ] )
   endif
   cUri += "/" + hCfg[ "dataPath" ]

   AdsSetFileType( ADS_CDX )
   if ! AdsConnect60( cUri, ADS_REMOTE_SERVER, ;
         iif( Empty( hCfg[ "user" ] ), NIL, hCfg[ "user" ] ), ;
         iif( Empty( hCfg[ "password" ] ), NIL, hCfg[ "password" ] ), 0, @hConn )
      return .F.
   endif
   s_hAdsConn := hConn
return .T.

//--------------------------------------------------------------------
// Open <cName> (dataset base name) in a NEW workarea with the RDD that
// matches the active driver. Returns the alias or "" on failure.
// Call with s_mtxDb held and a trapping ErrorBlock installed.
static function ErpDbOpen( cName )

   local cDriver := ErpDbDriver()
   local cRDD, cFile

   if cDriver == "openads"
      if ! ErpDbAdsConnect()
         return ""
      endif
      cRDD  := "ADSCDX"
      cFile := cName              // relative to the server dataPath
   else
      cRDD  := "DBFCDX"
      cFile := ErpDbDataDir() + cName + ".dbf"
      if ! File( cFile )
         return ""
      endif
   endif

   dbUseArea( .T., cRDD, cFile, "ERPDBWA", .T. )
   if ! Used()
      return ""
   endif
   SET DELETED ON
   // structural <cName>.cdx auto-opens when present; writes stay indexed
return "ERPDBWA"

//--------------------------------------------------------------------
// rows array of meta/data/<cBase>.json ({} if missing/broken)
static function ErpDbJsonRows( cBase )

   local cRaw := ErpMetaGetRaw( "data." + cBase ), hDoc := { => }

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
// Field-name map data/<cBase>.map.json:
// { "fields": [ {"dbf":"BILLINGTYP","json":"billingType","type":"C","len":40,"dec":0}, ... ] }
static function ErpDbLoadMap( cBase )

   local cFile := ErpDbDataDir() + cBase + ".map.json"
   local hDoc := { => }

   if ! File( cFile )
      return {}
   endif
   hb_jsonDecode( MemoRead( cFile ), @hDoc )
   if ValType( hDoc ) == "H" .and. hb_HHasKey( hDoc, "fields" ) .and. ;
         ValType( hDoc[ "fields" ] ) == "A"
      return hDoc[ "fields" ]
   endif
return {}

//--------------------------------------------------------------------
static function ErpDbSaveMap( cBase, aFields )

   local cDir := ErpDbDataDir()

   if ! hb_DirExists( cDir )
      hb_DirCreate( cDir )
   endif
return MemoWrit( cDir + cBase + ".map.json", ;
   hb_jsonEncode( { "fields" => aFields } ) + Chr( 10 ) )

//--------------------------------------------------------------------
// DBF field name: uppercase, [A-Z0-9_], max 10 chars, numeric suffix on
// collision after truncation.
static function ErpDbDbfName( cJson, aUsed )

   local c := "", n, cCh, cBase, i

   for n := 1 to Len( cJson )
      cCh := Upper( SubStr( cJson, n, 1 ) )
      if ( cCh >= "A" .and. cCh <= "Z" ) .or. ( cCh >= "0" .and. cCh <= "9" )
         c += cCh
      else
         c += "_"
      endif
   next
   if Empty( c )
      c := "F"
   endif
   if Left( c, 1 ) >= "0" .and. Left( c, 1 ) <= "9"
      c := "F" + c
   endif
   cBase := Left( c, 10 )
   c := cBase
   i := 1
   while AScan( aUsed, c ) > 0
      i++
      c := Left( cBase, 8 ) + StrZero( i, 2 )
   enddo
   AAdd( aUsed, c )
return c

//--------------------------------------------------------------------
// Infer the DBF schema from the JSON rows:
//   string -> C(max(10,min(254,maxlen)))   number -> N(16, 2 if any float)
//   logical -> L    array/object -> M (JSON-encoded)   all-null -> C(10)
static function ErpDbInferSchema( aRows )

   local hInfo := { => }, aOrder := {}, aFields := {}, aUsed := {}
   local hRow, cF, xV, cT, h, cType, nLen, nDec

   if ValType( aRows ) != "A"
      return {}
   endif

   for each hRow in aRows
      if ValType( hRow ) != "H"
         loop
      endif
      for each cF in hb_HKeys( hRow )
         xV := hRow[ cF ]
         cT := ValType( xV )
         if ! hb_HHasKey( hInfo, cF )
            hInfo[ cF ] := { "type" => "", "len" => 0, "float" => .F. }
            AAdd( aOrder, cF )
         endif
         h := hInfo[ cF ]
         do case
         case cT == "C"
            h[ "len" ] := Max( h[ "len" ], hb_BLen( xV ) )
            if Empty( h[ "type" ] )
               h[ "type" ] := "C"
            endif
         case cT == "N"
            if Empty( h[ "type" ] ) .or. h[ "type" ] == "L"
               h[ "type" ] := "N"
            endif
            if xV != Int( xV )
               h[ "float" ] := .T.
            endif
         case cT == "L"
            if Empty( h[ "type" ] )
               h[ "type" ] := "L"
            endif
         case cT == "A" .or. cT == "H"
            h[ "type" ] := "M"
         endcase
      next
   next

   for each cF in aOrder
      h := hInfo[ cF ]
      cType := h[ "type" ]
      if Empty( cType )
         cType := "C"                    // every row had it null/absent
      endif
      do case
      case cType == "C" ; nLen := Max( 10, Min( 254, h[ "len" ] ) ) ; nDec := 0
      case cType == "N" ; nLen := 16 ; nDec := iif( h[ "float" ], 2, 0 )
      case cType == "L" ; nLen := 1  ; nDec := 0
      otherwise         ; nLen := 10 ; nDec := 0   // M
      endcase
      AAdd( aFields, { "dbf" => ErpDbDbfName( cF, aUsed ), "json" => cF, ;
         "type" => cType, "len" => nLen, "dec" => nDec } )
   next
return aFields

//--------------------------------------------------------------------
// JSON value -> DBF field value according to the map entry
static function ErpDbToDbf( xVal, hMap )

   do case
   case hMap[ "type" ] == "C"
      return Left( ErpToStr( xVal ), hMap[ "len" ] )
   case hMap[ "type" ] == "N"
      if ValType( xVal ) == "N"
         return xVal
      endif
      return Val( ErpToStr( xVal ) )
   case hMap[ "type" ] == "L"
      if ValType( xVal ) == "L"
         return xVal
      endif
      xVal := Lower( ErpToStr( xVal ) )
      return xVal == "true" .or. xVal == "t" .or. xVal == "1"
   case hMap[ "type" ] == "M"
      if ValType( xVal ) == "A" .or. ValType( xVal ) == "H"
         return hb_jsonEncode( xVal )
      endif
      return ErpToStr( xVal )
   endcase
return ""

//--------------------------------------------------------------------
// Byte-level UTF-8 validity check.
// RDD access runs under codepage "EN": GET is byte-identity, but FieldPut of
// JSON-decoded (UTF8-tagged) strings stores CP1252. So a table can hold a mix
// of UTF-8 rows (seeded from meta JSON) and CP1252 rows (written via the
// API); ErpDbFromDbf normalizes everything to UTF-8 for the HTTP layer.
static function ErpDbIsUtf8( c )

   local n := 1, nLen := hb_BLen( c ), b, nExtra, i

   while n <= nLen
      b := Asc( hb_BSubStr( c, n, 1 ) )
      if b < 0x80
         n++
         loop
      endif
      if b >= 0xC2 .and. b <= 0xDF
         nExtra := 1
      elseif b >= 0xE0 .and. b <= 0xEF
         nExtra := 2
      elseif b >= 0xF0 .and. b <= 0xF4
         nExtra := 3
      else
         return .F.
      endif
      if n + nExtra > nLen
         return .F.
      endif
      for i := 1 to nExtra
         b := Asc( hb_BSubStr( c, n + i, 1 ) )
         if b < 0x80 .or. b > 0xBF
            return .F.
         endif
      next
      n += nExtra + 1
   enddo
return .T.

//--------------------------------------------------------------------
// Deterministic CP1252 -> UTF-8 conversion (no codepage APIs involved).
static function ErpDb1252ToUtf8( c )

   local cOut := "", n, b
   // CP1252 0x80-0x9F specials -> Unicode codepoint
   local aSpec := { 0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, ;
      0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, ;
      0x008F, 0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, ;
      0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178 }

   for n := 1 to hb_BLen( c )
      b := Asc( hb_BSubStr( c, n, 1 ) )
      if b < 0x80
         cOut += Chr( b )
      elseif b >= 0xA0
         // U+00A0..U+00FF -> 2-byte UTF-8
         cOut += Chr( 0xC0 + Int( b / 64 ) ) + Chr( 0x80 + b % 64 )
      else
         b := aSpec[ b - 0x7F ]
         if b < 0x800
            cOut += Chr( 0xC0 + Int( b / 64 ) ) + Chr( 0x80 + b % 64 )
         else
            cOut += Chr( 0xE0 + Int( b / 4096 ) ) + ;
               Chr( 0x80 + Int( b / 64 ) % 64 ) + Chr( 0x80 + b % 64 )
         endif
      endif
   next
return cOut

//--------------------------------------------------------------------
static function ErpDbUtf8( c )

   if ValType( c ) == "C" .and. ! Empty( c ) .and. ! ErpDbIsUtf8( c )
      return ErpDb1252ToUtf8( c )
   endif
return c

//--------------------------------------------------------------------
// DBF field value -> JSON value according to the map entry
static function ErpDbFromDbf( xVal, hMap )

   local cRaw, hTmp

   do case
   case hMap[ "type" ] == "C"
      return ErpDbUtf8( Trim( xVal ) )
   case hMap[ "type" ] == "M"
      cRaw := ErpDbUtf8( xVal )
      if Left( cRaw, 1 ) $ "[{"
         hTmp := NIL
         hb_jsonDecode( cRaw, @hTmp )
         if ValType( hTmp ) == "A" .or. ValType( hTmp ) == "H"
            return hTmp
         endif
      endif
      return cRaw
   endcase
return xVal

//--------------------------------------------------------------------
// Generate the tables that are missing (dbfcdx: local files; openads with
// backend dbfcdx: server-side via the ADS connection). Existing tables are
// NEVER regenerated or overwritten. Returns the number of tables created.
function ErpDbEnsureTables()

   local cDriver := ErpDbDriver(), hCfg
   local cDir, aDir, aItem, cName, cBase, nDot, nCreated := 0
   local aRows, aMap
   local bOld, oErr, cCp

   if cDriver != "dbfcdx" .and. cDriver != "openads"
      return 0
   endif
   if cDriver == "openads"
      hCfg := ErpDbConfig()
      if hCfg[ "backend" ] != "dbfcdx"
         // SQL backends (sqlite/mysql/mariadb/postgresql) are OpenADS
         // server-side roadmap — nothing to generate from here
         return 0
      endif
   endif

   cDir := ErpDbDataDir()
   hb_MutexLock( s_mtxDb )
   // RDD ops under "EN": byte identity in both directions. Under UTF8EX the
   // DBF RDD translates field data and mangles the UTF-8 JSON payloads;
   // "EN" reads/writes the raw bytes and hb_jsonEncode passes them through.
   cCp := hb_cdpSelect( "EN" )
   bOld := ErrorBlock( {| e | Break( e ) } )
   begin sequence
      if ! hb_DirExists( cDir )
         hb_DirCreate( cDir )
      endif
      if cDriver == "openads" .and. ! ErpDbAdsConnect()
         Break( NIL )      // server down — nothing to do
      endif
      aDir := Directory( ErpMetaRoot() + "data" + hb_ps() + "*.json" )
      for each aItem in aDir
         cName := AllTrim( ErpToStr( aItem[ 1 ] ) )
         if Empty( cName ) .or. "D" $ Upper( ErpToStr( aItem[ 5 ] ) )
            loop
         endif
         nDot := RAt( ".", cName )
         cBase := iif( nDot > 1, Left( cName, nDot - 1 ), cName )
         if cDriver == "dbfcdx" .and. File( cDir + cBase + ".dbf" )
            loop                              // never overwrite
         endif
         aRows := ErpDbJsonRows( cBase )
         if Empty( aRows )
            loop
         endif
         aMap := ErpDbLoadMap( cBase )
         if Empty( aMap )
            aMap := ErpDbInferSchema( aRows )
            ErpDbSaveMap( cBase, aMap )
         endif
         // one bad table must not abort the rest
         begin sequence
            if ErpDbCreateTable( cBase, aMap, aRows )
               nCreated++
            endif
         recover using oErr
            // a failed create may have left the workarea open
            begin sequence
               ( "ERPDBWA" )->( dbCloseArea() )
            recover
            end sequence
         end sequence
      next
   recover using oErr
      // best-effort: keep whatever was created before the error
   end sequence
   ErrorBlock( bOld )
   hb_cdpSelect( cCp )
   hb_MutexUnlock( s_mtxDb )
return nCreated

//--------------------------------------------------------------------
// Create + fill + index one table. Call with s_mtxDb held and a trapping
// ErrorBlock installed (any DBF/ADS error aborts via recover).
static function ErpDbCreateTable( cBase, aMap, aRows )

   local aStruct := {}, h, hRow, nF, cKey := ""
   local cDriver := ErpDbDriver(), cRDD, cFile, cBag, lOk := .F.
   local bOld, oErr

   for each h in aMap
      AAdd( aStruct, { h[ "dbf" ], h[ "type" ], h[ "len" ], h[ "dec" ] } )
      if Empty( cKey ) .and. h[ "type" ] == "C"
         cKey := h[ "dbf" ]
      endif
   next
   if Empty( aStruct )
      return .F.
   endif

   if cDriver == "openads"
      cRDD  := "ADSCDX"
      cFile := cBase
      cBag  := cBase
   else
      cRDD  := "DBFCDX"
      cFile := ErpDbDataDir() + cBase + ".dbf"
      cBag  := ErpDbDataDir() + cBase   // full path — a bare name lands in the CWD
   endif

   dbCreate( cFile, aStruct, cRDD )
   dbUseArea( .T., cRDD, cFile, "ERPDBWA", .T. )
   if ! Used()
      return .F.
   endif

   for each hRow in aRows
      if ValType( hRow ) != "H"
         loop
      endif
      if ( "ERPDBWA" )->( dbAppend() )
         for nF := 1 to Len( aMap )
            h := aMap[ nF ]
            if hb_HHasKey( hRow, h[ "json" ] )
               ( "ERPDBWA" )->( FieldPut( nF, ErpDbToDbf( hRow[ h[ "json" ] ], h ) ) )
            endif
         next
         ( "ERPDBWA" )->( dbUnlock() )
      endif
   next
   ( "ERPDBWA" )->( dbCommit() )

   // CDX tag KEY1 over the first character field (code/key/id). Structural
   // bag <cBag>.cdx; failure only costs the index, not the table.
   if ! Empty( cKey )
      bOld := ErrorBlock( {| e | Break( e ) } )
      begin sequence
         ( "ERPDBWA" )->( OrdCreate( cBag, "KEY1", cKey, &( "{||" + cKey + "}" ) ) )
         ( "ERPDBWA" )->( dbCommit() )
      recover using oErr
      end sequence
      ErrorBlock( bOld )
   endif

   ( "ERPDBWA" )->( dbCloseArea() )
   lOk := .T.
return lOk

//--------------------------------------------------------------------
// Read all rows of a dataset through the active driver.
// Returns an array of hashes with the JSON field names from the map.
function ErpDbReadRows( cDataKey )

   local aRows := {}, cName := ErpDbDataName( cDataKey ), aMap, cAlias := ""
   local nF, hMap, hRow
   local bOld, oErr, cCp

   if Empty( cName )
      return aRows
   endif
   aMap := ErpDbLoadMap( cName )
   if Empty( aMap )
      return aRows
   endif

   hb_MutexLock( s_mtxDb )
   s_cDbErr := ""
   cCp := hb_cdpSelect( "EN" )   // byte-identity RDD access (see EnsureTables)
   bOld := ErrorBlock( {| e | Break( e ) } )
   begin sequence
      cAlias := ErpDbOpen( cName )
      if ! Empty( cAlias )
         ( cAlias )->( dbGoTop() )
         while ! ( cAlias )->( Eof() )
            hRow := { => }
            for nF := 1 to Len( aMap )
               hMap := aMap[ nF ]
               s_cDbErr := "at rec " + hb_ntos( ( cAlias )->( RecNo() ) ) + ;
                  " field " + hMap[ "json" ]
               hRow[ hMap[ "json" ] ] := ;
                  ErpDbFromDbf( ( cAlias )->( FieldGet( nF ) ), hMap )
            next
            AAdd( aRows, hRow )
            ( cAlias )->( dbSkip() )
         enddo
         ( cAlias )->( dbCloseArea() )
         cAlias := ""
         s_cDbErr := ""
      else
         s_cDbErr := "open failed: " + cName
      endif
   recover using oErr
      // return what was read so far
      s_cDbErr := cName + " " + s_cDbErr + ": " + oErr:Description + " | op:" + ;
         oErr:Operation + " | " + ;
         hb_ntos( oErr:GenCode ) + "/" + hb_ntos( oErr:SubCode ) + " " + ;
         oErr:SubSystem
   end sequence
   if ! Empty( cAlias )
      begin sequence
         ( cAlias )->( dbCloseArea() )
      recover using oErr
      end sequence
   endif
   ErrorBlock( bOld )
   hb_cdpSelect( cCp )
   hb_MutexUnlock( s_mtxDb )
return aRows

//--------------------------------------------------------------------
// CRUD through the active driver: add (APPEND+REPLACE), update / delete by
// keyField == keyValue (string compare, same rule as the JSON handler).
// Delete flags the record (SET DELETED ON hides it); no PACK — shared mode.
// NOTE: takes the raw request BODY, not a decoded hash — the JSON is decoded
// under codepage "EN" (inside the mutex section). FieldPut of the decoded
// (UTF8-tagged) strings stores CP1252; reads normalize back to UTF-8 in
// ErpDbFromDbf, so the HTTP API always sees UTF-8.
function ErpDbApply( cDataKey, cAction, cBody )

   local cName := ErpDbDataName( cDataKey ), aMap, cAlias := ""
   local nF, hMap, nKey := 0, lOk := .F.
   local bOld, oErr, cCp
   local hReq := { => }, hRow, cKeyField, cKeyValue

   if Empty( cName )
      return .F.
   endif
   aMap := ErpDbLoadMap( cName )
   if Empty( aMap )
      return .F.
   endif
   cAction := Lower( AllTrim( ErpToStr( cAction ) ) )

   hb_MutexLock( s_mtxDb )
   s_cDbErr := ""
   cCp := hb_cdpSelect( "EN" )   // byte-identity RDD access (see EnsureTables)
   if "{" $ cBody
      hb_jsonDecode( cBody, @hReq )
   endif
   if ValType( hReq ) != "H"
      hReq := { => }
   endif
   hRow := hb_HGetDef( hReq, "row", NIL )
   cKeyField := AllTrim( ErpToStr( hb_HGetDef( hReq, "keyField", "" ) ) )
   cKeyValue := ErpToStr( hb_HGetDef( hReq, "keyValue", "" ) )

   bOld := ErrorBlock( {| e | Break( e ) } )
   begin sequence
      cAlias := ErpDbOpen( cName )
      if ! Empty( cAlias )
         if cAction == "add"
            if ( cAlias )->( dbAppend() )
               for nF := 1 to Len( aMap )
                  hMap := aMap[ nF ]
                  if ValType( hRow ) == "H" .and. hb_HHasKey( hRow, hMap[ "json" ] )
                     ( cAlias )->( FieldPut( nF, ErpDbToDbf( hRow[ hMap[ "json" ] ], hMap ) ) )
                  endif
               next
               ( cAlias )->( dbUnlock() )
               lOk := .T.
            endif
         else
            for nF := 1 to Len( aMap )
               if aMap[ nF ][ "json" ] == cKeyField
                  nKey := nF
                  exit
               endif
            next
            if nKey > 0
               ( cAlias )->( dbGoTop() )
               while ! ( cAlias )->( Eof() )
                  if ErpToStr( ErpDbFromDbf( ( cAlias )->( FieldGet( nKey ) ), ;
                        aMap[ nKey ] ) ) == cKeyValue
                     if ( cAlias )->( RLock() )
                        if cAction == "update"
                           for nF := 1 to Len( aMap )
                              hMap := aMap[ nF ]
                              if ValType( hRow ) == "H" .and. ;
                                    hb_HHasKey( hRow, hMap[ "json" ] )
                                 ( cAlias )->( FieldPut( nF, ;
                                    ErpDbToDbf( hRow[ hMap[ "json" ] ], hMap ) ) )
                              endif
                           next
                        else
                           ( cAlias )->( dbDelete() )
                        endif
                        ( cAlias )->( dbUnlock() )
                        // remote OpenADS: dbDelete() can be a silent no-op
                        // (Deleted() stays .F.) and FieldPut on rows that were
                        // not written by this connection throws "write failed"
                        if cAction == "delete" .and. ! ( cAlias )->( Deleted() )
                           s_cDbErr := "delete not persisted by the OpenADS server"
                           lOk := .F.
                        else
                           lOk := .T.
                        endif
                     else
                        s_cDbErr := "record lock failed (RLock)"
                     endif
                     exit
                  endif
                  ( cAlias )->( dbSkip() )
               enddo
               if ! lOk .and. Empty( s_cDbErr )
                  s_cDbErr := "row not found: " + cKeyField + "=" + cKeyValue
               endif
            else
               s_cDbErr := "keyField not in table map: " + cKeyField
            endif
         endif
         ( cAlias )->( dbCommit() )
         ( cAlias )->( dbCloseArea() )
         cAlias := ""
      else
         s_cDbErr := "open failed: " + cName
      endif
   recover using oErr
      lOk := .F.
      s_cDbErr := cAction + " " + cName + ": " + oErr:Description + ;
         iif( Empty( oErr:Operation ), "", " (" + oErr:Operation + ")" )
      if ErpDbDriver() == "openads"
         s_cDbErr += " — remote update/delete of pre-existing rows is not supported by this OpenADS server"
      endif
   end sequence
   if ! Empty( cAlias )
      begin sequence
         ( cAlias )->( dbCloseArea() )
      recover using oErr
      end sequence
   endif
   ErrorBlock( bOld )
   hb_cdpSelect( cCp )
   hb_MutexUnlock( s_mtxDb )
return lOk

//--------------------------------------------------------------------
function ErpDbLastError()
return s_cDbErr

//--------------------------------------------------------------------
// Status hash for GET /api/db/status
function ErpDbStatus()

   local hCfg := ErpDbConfig(), cDir := ErpDbDataDir(), aTables := {}
   local aDir, aItem, cName, nDot, hOut

   if hb_DirExists( cDir )
      aDir := Directory( cDir + "*.dbf" )
      for each aItem in aDir
         cName := AllTrim( ErpToStr( aItem[ 1 ] ) )
         nDot := RAt( ".", cName )
         AAdd( aTables, iif( nDot > 1, Left( cName, nDot - 1 ), cName ) )
      next
   endif

   hOut := { "ok" => .T., ;
      "driver"   => hCfg[ "driver" ], ;
      "backend"  => hCfg[ "backend" ], ;
      "host"     => hCfg[ "host" ], ;
      "port"     => hCfg[ "port" ], ;
      "dataPath" => hCfg[ "dataPath" ], ;
      "dbfDir"   => cDir, ;
      "tables"   => aTables, ;
      "openadsAvailable" => ErpDbAdsAvailable(), ;
      "lastError" => s_cDbErr }

   if hCfg[ "driver" ] == "openads"
      // measured against openads_serverd (2026-08): reads work; appends are
      // accepted but only live in the server session cache (not durable);
      // update/delete of on-disk rows are rejected server-side
      hOut[ "remoteNote" ] := "OpenADS server: read ok; add is session-cached (not durable); update/delete of existing rows not supported"
   endif
return hOut
