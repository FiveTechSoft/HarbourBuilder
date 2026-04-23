// dbgclient.prg — Socket-based debug client for HbBuilder
//
// State stored in a static array via DbgState() to avoid Harbour E0004.
// Uses DbgHookInstall() from dbghook.c for the C-level VM hook.

#include "hbsocket.ch"

#define DBG_SOCKET    1
#define DBG_CONNECTED 2
#define DBG_READY     3
#define DBG_STEPPING  4
#define DBG_RUNNING   5

static function DbgState()
   static s_aState := nil
   if s_aState == nil
      s_aState := { nil, .f., .f., .t., .f. }  // socket, connected, ready, stepping, running
   endif
return s_aState

function DbgClientStart( nPort )

   local hSocket, aAddr, aS, cReply

   if nPort == nil; nPort := 19800; endif

   DbgLog( "DbgClientStart port=" + LTrim(Str(nPort)) )

   hSocket := hb_socketOpen( HB_SOCKET_AF_INET, 1 /* SOCK_STREAM */, 0 )
   if Empty( hSocket )
      DbgLog( "hb_socketOpen FAILED" )
      return .f.
   endif
   DbgLog( "hb_socketOpen OK" )

   aAddr := { HB_SOCKET_AF_INET, "127.0.0.1", nPort }
   if ! hb_socketConnect( hSocket, aAddr )
      DbgLog( "hb_socketConnect FAILED err=" + LTrim(Str(hb_socketGetError())) )
      hb_socketClose( hSocket )
      return .f.
   endif
   DbgLog( "hb_socketConnect OK" )

   aS := DbgState()
   aS[ DBG_SOCKET ] := hSocket
   aS[ DBG_CONNECTED ] := .t.

   // Install C-level debug hook — block receives ( nLine, cModule, cProcName )
   DbgLog( "Installing debug hook..." )
   DbgHookInstall( { |nLine, cModule, cProc| DbgHook( nLine, cModule, cProc ) } )
   DbgLog( "Debug hook installed" )

   // Handshake: send HELLO, wait for STEP
   DbgLog( "Sending HELLO..." )
   DbgSend( "HELLO " + ProcFile(2) )
   DbgLog( "Waiting for STEP reply..." )
   cReply := DbgRecv()
   DbgLog( "Got reply: " + iif( cReply != nil, cReply, "(nil)" ) )

   // Enable hook
   aS[ DBG_READY ] := .t.
   DbgLog( "DbgClientStart done, hook ready" )

return .t.

static function DbgLog( cMsg )
   local nH := FOpen( "/tmp/hbbuilder_debug/dbgclient_trace.log", 1 + 16 )  // FO_WRITE + FO_SHARED
   if nH == -1
      nH := FCreate( "/tmp/hbbuilder_debug/dbgclient_trace.log" )
   else
      FSeek( nH, 0, 2 )  // seek to end
   endif
   if nH >= 0
      FWrite( nH, cMsg + Chr(13) + Chr(10) )
      FClose( nH )
   endif
return nil

// Called from C hook on each source line — receives ( nLine, cModule )

static function DbgHook( nLine, cModule, cProcName )

   local cCmd, cMsg, aS := DbgState()

   if ! aS[ DBG_CONNECTED ] .or. ! aS[ DBG_READY ]
      return nil
   endif

   // Check BEFORE the RUNNING branch: if the main form was closed (user
   // pressed X after Continue), the flag is set but otherwise we'd never
   // notice until a STEP arrived — which it won't if IDE is idle.
   if IDE_DbgRunLoopEnded()
      DbgSend( "DONE" )
      aS[ DBG_CONNECTED ] := .f.
      hb_socketClose( aS[ DBG_SOCKET ] )
      return nil
   endif

   // In RUNNING mode: don't block — just check for STEP/QUIT non-blocking
   if aS[ DBG_RUNNING ]
      cCmd := DbgRecvNonBlock()
      if cCmd != nil
         if Left( cCmd, 4 ) == "QUIT"
            aS[ DBG_CONNECTED ] := .f.
            hb_socketClose( aS[ DBG_SOCKET ] )
            QUIT
            return nil
         endif
         if Left( cCmd, 4 ) == "STEP"
            aS[ DBG_RUNNING ] := .f.
            // Fall through to send PAUSE and wait
         endif
      else
         return nil  // No command pending — continue running freely
      endif
   endif

   // Second check (redundant with the early check above, kept for clarity)
   if IDE_DbgRunLoopEnded()
      DbgSend( "DONE" )
      aS[ DBG_CONNECTED ] := .f.
      hb_socketClose( aS[ DBG_SOCKET ] )
      return nil
   endif

   // Build full PAUSE message with locals and stack inline
   // cModule already includes function name (format: "module:FUNCNAME")
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

      if Left( cCmd, 4 ) == "STEP"
         aS[ DBG_RUNNING ] := .f.
         exit
      endif

      if Left( cCmd, 2 ) == "GO"
         aS[ DBG_RUNNING ] := .t.
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
   local lReady

   if ! aS[ DBG_CONNECTED ] .or. aS[ DBG_SOCKET ] == nil
      return nil
   endif

   // Non-blocking select loop: pump Cocoa events every 50ms so the
   // executed form (running in this subprocess) can process UI events
   // (e.g. close button) while waiting for a STEP/GO command from IDE
   do while aS[ DBG_CONNECTED ]
      lReady := hb_socketSelect( { aS[ DBG_SOCKET ] }, ,, 50 )
      if lReady > 0
         exit
      endif
      if lReady < 0
         aS[ DBG_CONNECTED ] := .f.
         return nil
      endif
      IDE_DbgPumpEvents()
      // If the main form was destroyed (user clicked X during pause),
      // signal IDE and bail out of the wait loop.
      if IDE_DbgRunLoopEnded()
         DbgSend( "DONE" )
         aS[ DBG_CONNECTED ] := .f.
         hb_socketClose( aS[ DBG_SOCKET ] )
         return nil
      endif
   enddo

   if ! aS[ DBG_CONNECTED ]
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

// Non-blocking receive: returns nil if no data available
static function DbgRecvNonBlock()

   local cBuf := Space( 256 ), nLen, aS := DbgState()
   local lReady

   if ! aS[ DBG_CONNECTED ] .or. aS[ DBG_SOCKET ] == nil
      return nil
   endif

   // Check if data is available (0ms timeout = non-blocking)
   lReady := hb_socketSelect( { aS[ DBG_SOCKET ] }, ,, 0 )
   if lReady <= 0
      return nil  // No data available
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
