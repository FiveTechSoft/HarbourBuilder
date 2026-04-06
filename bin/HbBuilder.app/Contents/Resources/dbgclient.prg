// dbgclient.prg — Socket-based debug client for HbBuilder
//
// State stored in a static array via DbgState() to avoid Harbour E0004.
// Uses DbgHookInstall() from dbghook.c for the C-level VM hook.

#include "hbsocket.ch"

#define DBG_SOCKET    1
#define DBG_CONNECTED 2
#define DBG_READY     3
#define DBG_STEPPING  4

static function DbgState()
   static s_aState := nil
   if s_aState == nil
      s_aState := { nil, .f., .f., .t. }  // socket, connected, ready, stepping
   endif
return s_aState

function DbgClientStart( nPort )

   local hSocket, aAddr, aS, cReply

   if nPort == nil; nPort := 19800; endif

   hSocket := hb_socketOpen( HB_SOCKET_AF_INET, 1 /* SOCK_STREAM */, 0 )
   if Empty( hSocket )
      return .f.
   endif

   aAddr := { HB_SOCKET_AF_INET, "127.0.0.1", nPort }
   if ! hb_socketConnect( hSocket, aAddr )
      hb_socketClose( hSocket )
      return .f.
   endif

   aS := DbgState()
   aS[ DBG_SOCKET ] := hSocket
   aS[ DBG_CONNECTED ] := .t.

   // Install C-level debug hook — block receives ( nLine, cModule, cProcName )
   DbgHookInstall( { |nLine, cModule, cProc| DbgHook( nLine, cModule, cProc ) } )

   // Handshake: send HELLO, wait for STEP
   DbgSend( "HELLO " + ProcFile(2) )
   cReply := DbgRecv()

   // Enable hook
   aS[ DBG_READY ] := .t.

return .t.

// Called from C hook on each source line — receives ( nLine, cModule )

static function DbgHook( nLine, cModule, cProcName )

   local cCmd, cMsg, aS := DbgState()

   if ! aS[ DBG_CONNECTED ] .or. ! aS[ DBG_READY ]
      return nil
   endif

   // Build full PAUSE message with locals and stack inline
   cMsg := "PAUSE " + cModule + ":" + LTrim( Str( nLine ) )
   cMsg += "|" + BuildLocals( cProcName )
   cMsg += "|" + BuildStack()
   DbgSend( cMsg )

   // Wait for single command: STEP, GO, or QUIT
   do while aS[ DBG_CONNECTED ]
      cCmd := DbgRecv()
      if cCmd == nil
         aS[ DBG_CONNECTED ] := .f.
         return nil
      endif

      if Left( cCmd, 4 ) == "QUIT"
         aS[ DBG_CONNECTED ] := .f.
         hb_socketClose( aS[ DBG_SOCKET ] )
         QUIT
         return nil
      endif

      if Left( cCmd, 4 ) == "STEP" .or. Left( cCmd, 2 ) == "GO"
         exit
      endif
   enddo

return nil

static function BuildLocals( cTargetFunc )

   local i, j, cOut, cName, xVal, cType, aLocals, nFrame
   local aNames, nCount, nTry, aTest, cUpper

   cOut := "VARS"
   nFrame := 0

   // Find user's stack frame — match the exact function name from C hook
   if ! Empty( cTargetFunc )
      cUpper := Upper( cTargetFunc )
      for i := 1 to 20
         cName := Upper( ProcName( i ) )
         if Empty( cName ); exit; endif
         // Exact match or CLASS:METHOD match (ProcName may return "TAPPLICATION:NEW")
         if cName == cUpper .or. ;
            ( ":" $ cName .and. SubStr( cName, At( ":", cName ) + 1 ) == cUpper )
            nFrame := i
            exit
         endif
      next
   endif

   // Fallback: first non-debug frame
   if nFrame == 0
      for i := 1 to 15
         cName := ProcName( i )
         if Empty( cName ); exit; endif
         if ! ( "BUILD" $ Upper(cName) .or. "DBGHOOK" $ Upper(cName) .or. ;
                "(B)" $ Upper(cName) .or. "DBGCLIENT" $ Upper(cName) .or. ;
                "__DBGINIT" $ Upper(cName) )
            nFrame := i
            exit
         endif
      next
   endif

   // PUBLIC variables
   BEGIN SEQUENCE
      nCount := __mvDbgInfo( 1 )  // HB_MV_PUBLIC count
      if ValType( nCount ) == "N" .and. nCount > 0
         cOut += " [PUBLIC]"
         for j := 1 to Min( nCount, 30 )
            cName := ""
            xVal := nil
            __mvDbgInfo( 1, j, @cName, @xVal )  // get public #j
            if ! Empty( cName )
               cOut += " " + cName + "=" + DbgValStr( xVal )
            endif
         next
      endif
   END SEQUENCE

   // PRIVATE variables
   BEGIN SEQUENCE
      nCount := __mvDbgInfo( 2 )  // HB_MV_PRIVATE count
      if ValType( nCount ) == "N" .and. nCount > 0
         cOut += " [PRIVATE]"
         for j := 1 to Min( nCount, 30 )
            cName := ""
            xVal := nil
            __mvDbgInfo( 2, j, @cName, @xVal )
            if ! Empty( cName )
               cOut += " " + cName + "=" + DbgValStr( xVal )
            endif
         next
      endif
   END SEQUENCE

   // LOCAL variables
   if nFrame > 0 .and. nFrame <= __dbgProcLevel()
      aLocals := __dbgVmLocalList( nFrame )
      if ValType( aLocals ) == "A" .and. Len( aLocals ) > 0
         cOut += " [LOCAL]"
         // If inside a method, add Self as first entry
         if ":" $ ProcName( nFrame )
            xVal := __dbgVmVarLGet( nFrame, 0 )
            if ValType( xVal ) == "O"
               cOut += " Self=" + DbgValStr( xVal )
            endif
         endif
         for j := 1 to Len( aLocals )
            xVal := aLocals[j]
            cOut += " local" + LTrim(Str(j)) + "=" + DbgValStr( xVal )
         next
      endif
   endif

return cOut

static function BuildStack()

   local i, cOut, cName

   cOut := "STACK"
   for i := 1 to 25
      cName := ProcName( i )
      if Empty( cName ); exit; endif
      if "BUILD" $ Upper(cName) .or. "DBGHOOK" $ Upper(cName) .or. ;
         "(B)" $ Upper(cName) .or. "DBGCLIENT" $ Upper(cName)
         loop
      endif
      cOut += " " + cName + "(" + LTrim( Str( ProcLine( i ) ) ) + ")"
   next

return cOut

static function IsFrameworkFunc( cModule )
   local cFunc, nPos, i, lHasDigit
   // Extract function name from module string "path:FUNCNAME"
   nPos := RAt( ":", cModule )
   if nPos > 0
      cFunc := Upper( SubStr( cModule, nPos + 1 ) )
   else
      cFunc := Upper( cModule )
   endif
   // Framework: starts with T without digits (TAPPLICATION, TFORM, TCONTROL...),
   //   but NOT user classes with digits (TFORM1, TFORM2...)
   if Left( cFunc, 1 ) == "T" .and. Len( cFunc ) > 3
      lHasDigit := .f.
      for i := 1 to Len( cFunc )
         if SubStr( cFunc, i, 1 ) >= "0" .and. SubStr( cFunc, i, 1 ) <= "9"
            lHasDigit := .t.
            exit
         endif
      next
      if ! lHasDigit
         return .t.
      endif
   endif
   if "DBGSTATE" $ cFunc .or. "DBGHOOK" $ cFunc .or. ;
      "BUILDLOCALS" $ cFunc .or. "BUILDSTACK" $ cFunc .or. ;
      "DBGCLIENT" $ cFunc .or. "__DBGINIT" $ cFunc .or. ;
      "APPSHOWERROR" $ cFunc .or. "VALTOSTR" $ cFunc .or. ;
      "SETDPIAWARE" $ cFunc .or. "ISFRAMEWORKFUNC" $ cFunc .or. ;
      "ERRORBLOCK" $ cFunc .or. "ISDEBUGGMODE" $ cFunc
      return .t.
   endif
return .f.

static function DbgValStr( xVal )
   local cType := ValType( xVal ), cClass
   do case
      case xVal == nil;  return "nil"
      case cType == "O"
         cClass := xVal:ClassName()
         // TAPPLICATION → TApplication
         if Len( cClass ) > 1
            cClass := Left( cClass, 1 ) + Upper( SubStr( cClass, 2, 1 ) ) + Lower( SubStr( cClass, 3 ) )
         endif
         return cClass
      case cType == "A";  return "{Array(" + LTrim(Str(Len(xVal))) + ")}"
      case cType == "B";  return "{Block}"
      case cType == "L";  return If( xVal, ".T.", ".F." )
      case cType == "N";  return LTrim( Str( xVal ) )
      case cType == "D";  return DToC( xVal )
      case cType == "C"
         if Len( xVal ) > 40
            return '"' + Left( xVal, 40 ) + '..."'
         endif
         return '"' + xVal + '"'
   endcase
return hb_ValToStr( xVal )

static function DbgSend( cMsg )

   local aS := DbgState()
   if aS[ DBG_CONNECTED ] .and. aS[ DBG_SOCKET ] != nil
      hb_socketSend( aS[ DBG_SOCKET ], cMsg + Chr(10) )
   endif

return nil

static function DbgRecv()

   local cBuf := Space( 4096 ), nLen, aS := DbgState()

   if ! aS[ DBG_CONNECTED ] .or. aS[ DBG_SOCKET ] == nil
      return nil
   endif

   nLen := hb_socketRecv( aS[ DBG_SOCKET ], @cBuf )
   if nLen <= 0
      aS[ DBG_CONNECTED ] := .f.
      return nil
   endif

   cBuf := Left( cBuf, nLen )
   do while Right( cBuf, 1 ) == Chr(10) .or. Right( cBuf, 1 ) == Chr(13)
      cBuf := Left( cBuf, Len( cBuf ) - 1 )
   enddo

return cBuf
