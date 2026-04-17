/*
 * hix_runtime.prg — HIX-compatible global functions for TWebServer
 *
 * All U* functions read/write through UI_HIX_* HB_FUNCs which access
 * the current HixCtx* in cocoa_webserver.m (main-thread only, safe).
 */

#include "hbbuilder.ch"

STATIC s_cHixRoot := "."

//─── Query string parser ─────────────────────────────────────────────────────

STATIC FUNCTION HIX_ParseQuery( cStr )
   local hResult := { => }
   local aPairs, aPair, i
   if Empty( cStr ); return hResult; endif
   aPairs := hb_aTokens( cStr, "&" )
   for i := 1 to Len( aPairs )
      aPair := hb_aTokens( aPairs[i], "=" )
      if Len( aPair ) >= 2
         hResult[ UUrlDecode(aPair[1]) ] := UUrlDecode(aPair[2])
      elseif Len( aPair ) == 1 .and. !Empty(aPair[1])
         hResult[ UUrlDecode(aPair[1]) ] := ""
      endif
   next
return hResult

//─── Input functions ─────────────────────────────────────────────────────────

FUNCTION UGet( cVar )
   local hGet := HIX_ParseQuery( UI_HIX_QUERY() )
   if cVar == nil; return hGet; endif
   if hb_hHasKey( hGet, cVar ); return hGet[ cVar ]; endif
return ""

FUNCTION UPost( cVar )
   local cBody := UI_HIX_BODY()
   local hPost
   if "{" $ cBody .or. "[" $ cBody
      hPost := { "body" => cBody }
   else
      hPost := HIX_ParseQuery( cBody )
   endif
   if cVar == nil; return hPost; endif
   if hb_hHasKey( hPost, cVar ); return hPost[ cVar ]; endif
return ""

FUNCTION UHeader( cVar )
   HB_SYMBOL_UNUSED( cVar )
return ""

FUNCTION UCookie( cName )
   HB_SYMBOL_UNUSED( cName )
return ""

FUNCTION USetCookie( cKey, cVal, nSecs, cPath, cDomain, lHttps, lOnlyHttp, cSameSite )
   HB_SYMBOL_UNUSED( cKey ); HB_SYMBOL_UNUSED( cVal )
   HB_SYMBOL_UNUSED( nSecs ); HB_SYMBOL_UNUSED( cPath )
   HB_SYMBOL_UNUSED( cDomain ); HB_SYMBOL_UNUSED( lHttps )
   HB_SYMBOL_UNUSED( lOnlyHttp ); HB_SYMBOL_UNUSED( cSameSite )
return nil

FUNCTION UServer( cKey )
   local hInfo := { ;
      "SERVER_SOFTWARE" => "HbBuilder/HIX", ;
      "REQUEST_METHOD"  => UI_HIX_METHOD(), ;
      "REQUEST_URI"     => UI_HIX_PATH(), ;
      "QUERY_STRING"    => UI_HIX_QUERY() ;
   }
   if cKey == nil; return hInfo; endif
   if hb_hHasKey( hInfo, cKey ); return hInfo[ cKey ]; endif
return ""

FUNCTION UGetServerInfo()
return UServer()

FUNCTION UGetIp()
return UI_HIX_IP()

//─── Output functions ────────────────────────────────────────────────────────

FUNCTION UWrite( ... )
   local i
   for i := 1 to PCount()
      UI_HIX_WRITE( hb_CStr( hb_pValue(i) ) )
   next
return nil

FUNCTION USetStatusCode( nCode )
   UI_HIX_SETSTATUS( nCode )
return nil

FUNCTION USetErrorStatus( nStatus, cPage, cAjax )
   HB_SYMBOL_UNUSED( cPage ); HB_SYMBOL_UNUSED( cAjax )
   UI_HIX_SETSTATUS( nStatus )
return nil

FUNCTION UAddHeader( cType, uValue )
   HB_SYMBOL_UNUSED( cType ); HB_SYMBOL_UNUSED( uValue )
return nil

FUNCTION UView( cTpl, ... )
   local aArgs := hb_aParams()
   local cRoot, cFile, cHtml
   cRoot := HIX_GetRoot()
   cFile := cRoot + "/" + cTpl
   if ! File( cFile )
      cFile := cTpl
   endif
   if ! File( cFile )
      UWrite( "<!-- UView: template not found: " + cTpl + " -->" )
      return nil
   endif
   cHtml := HIX_RenderTemplate( MemoRead( cFile ), aArgs )
   UWrite( cHtml )
return nil

//─── Encoding / helpers ──────────────────────────────────────────────────────

FUNCTION UHtmlEncode( c )
   c := StrTran( c, "&",  "&amp;"  )
   c := StrTran( c, "<",  "&lt;"   )
   c := StrTran( c, ">",  "&gt;"   )
   c := StrTran( c, '"',  "&quot;" )
return c

FUNCTION UUrlEncode( c )
   local i, cOut := "", cCh, nAsc
   for i := 1 to Len(c)
      cCh  := SubStr(c, i, 1)
      nAsc := Asc(cCh)
      if (nAsc >= 65 .and. nAsc <= 90)  .or. ;
         (nAsc >= 97 .and. nAsc <= 122) .or. ;
         (nAsc >= 48 .and. nAsc <= 57)  .or. ;
         cCh $ "-_.~"
         cOut += cCh
      else
         cOut += "%" + hb_NumToHex( nAsc, 2 )
      endif
   next
return cOut

FUNCTION UUrlDecode( c )
   local i, cOut := "", cHex
   i := 1
   do while i <= Len(c)
      if SubStr(c,i,1) == "+"
         cOut += " "
         i++
      elseif SubStr(c,i,1) == "%" .and. i+2 <= Len(c)
         cHex := SubStr(c, i+1, 2)
         cOut += Chr( hb_HexToNum(cHex) )
         i += 3
      else
         cOut += SubStr(c,i,1)
         i++
      endif
   enddo
return cOut

FUNCTION Ulink( cText, cUrl )
return "<a href='" + cUrl + "'>" + cText + "</a>"

FUNCTION ULoadHtml( cFile )
   local cRoot := HIX_GetRoot()
   local cPath := cRoot + "/" + cFile
   if File( cPath )
      UWrite( MemoRead( cPath ) )
   endif
return nil

FUNCTION UExecuteHtml( cFile )
   if File( cFile )
      UWrite( MemoRead( cFile ) )
   endif
return nil

FUNCTION UExecutePrg( cFile )
   HIX_ExecPrg( cFile )
return nil

FUNCTION _d( ... )
   local i
   for i := 1 to PCount()
      hb_ToOutErr( hb_CStr( hb_pValue(i) ) + Chr(10) )
   next
return nil

FUNCTION _w( uVal )
return "<pre>" + UHtmlEncode( hb_CStr(uVal) ) + "</pre>"

//─── Internal helpers ────────────────────────────────────────────────────────

FUNCTION HIX_SetRoot( cRoot )
   s_cHixRoot := cRoot
return nil

FUNCTION HIX_GetRoot()
return s_cHixRoot

FUNCTION HIX_ServeStatic( cFilePath )
   local cExt := Lower( hb_FNameExt( cFilePath ) )
   local cMime
   local hMime := { ;
      ".html" => "text/html; charset=utf-8", ;
      ".htm"  => "text/html; charset=utf-8", ;
      ".css"  => "text/css", ;
      ".js"   => "application/javascript", ;
      ".json" => "application/json", ;
      ".png"  => "image/png", ;
      ".jpg"  => "image/jpeg", ;
      ".jpeg" => "image/jpeg", ;
      ".gif"  => "image/gif", ;
      ".svg"  => "image/svg+xml", ;
      ".ico"  => "image/x-icon", ;
      ".txt"  => "text/plain" ;
   }
   cMime := iif( hb_hHasKey(hMime, cExt), hMime[cExt], "application/octet-stream" )
   UI_HIX_SETCONTENTTYPE( cMime )
   UI_HIX_WRITE( MemoRead( cFilePath ) )
return nil

FUNCTION HIX_ExecPrg( cFile )
   local cCode, pHrb
   if ! File( cFile )
      UWrite( "<!-- HIX_ExecPrg: file not found: " + cFile + " -->" )
      return nil
   endif
   cCode := MemoRead( cFile )
   pHrb  := hb_compileStr( cCode, "-n", "-w", "-q" )
   if pHrb != nil
      hb_hrbDo( hb_hrbLoad( pHrb ) )
   else
      UWrite( "<!-- HIX_ExecPrg: compile error in: " + cFile + " -->" )
   endif
return nil
