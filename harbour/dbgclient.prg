// dbgclient.prg — Socket-based debug client for HbBuilder
//
// State stored in a static array via DbgState() to avoid Harbour E0004.
// Uses DbgHookInstall() from dbghook.c for the C-level VM hook.

#include "hbsocket.ch"

#define DBG_SOCKET    1
#define DBG_CONNECTED 2
#define DBG_READY     3

static function DbgState()
   static s_aState := nil
   if s_aState == nil
      s_aState := { nil, .f., .f. }
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

   // Install C-level debug hook — block receives ( nLine, cModule )
   DbgHookInstall( { |nLine, cModule| DbgHook( nLine, cModule ) } )

   // Handshake: send HELLO, wait for STEP
   DbgSend( "HELLO " + ProcFile(2) )
   cReply := DbgRecv()

   // Enable hook
   aS[ DBG_READY ] := .t.

return .t.

// Called from C hook on each source line — receives ( nLine, cModule )

static function DbgHook( nLine, cModule )

   local cCmd, aS := DbgState()

   if ! aS[ DBG_CONNECTED ] .or. ! aS[ DBG_READY ]
      return nil
   endif

   // Send PAUSE and wait for IDE command
   DbgSend( "PAUSE " + cModule + ":" + LTrim( Str( nLine ) ) )

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

      if Left( cCmd, 9 ) == "GETLOCALS"
         DbgSendLocals()
      elseif Left( cCmd, 8 ) == "GETSTACK"
         DbgSendStack()
      endif
   enddo

return nil

static function DbgSendLocals()

   local i, j, cOut, cName, xVal, cType, aLocals, nFrame

   cOut := "LOCALS"
   nFrame := 0

   // Walk the call stack to find the user's frame
   for i := 1 to 30
      cName := ProcName( i )
      if Empty( cName ); exit; endif
      if ! ( "DBGSEND" $ Upper(cName) .or. "DBGHOOK" $ Upper(cName) .or. ;
             "(B)" $ Upper(cName) .or. "DBGCLIENT" $ Upper(cName) )
         nFrame := i
         exit
      endif
   next

   if nFrame > 0
      BEGIN SEQUENCE
         aLocals := __dbgVmLocalList( nFrame )
         if ValType( aLocals ) == "A"
            for j := 1 to Len( aLocals )
               if ValType( aLocals[j] ) != "C"; loop; endif
               BEGIN SEQUENCE
                  xVal := __dbgVmVarLGet( nFrame, j )
               RECOVER
                  xVal := "?"
               END SEQUENCE
               cType := ValType( xVal )
               cOut += " " + aLocals[j] + "=" + hb_ValToStr( xVal ) + "(" + cType + ")"
            next
         endif
      END SEQUENCE
   endif

   DbgSend( cOut )

return nil

static function DbgSendStack()

   local i, cOut, cName

   cOut := "STACK"
   for i := 1 to 25
      cName := ProcName( i )
      if Empty( cName ); exit; endif
      // Skip internal debug frames
      if "DBGSEND" $ Upper(cName) .or. "DBGHOOK" $ Upper(cName) .or. ;
         "(B)" $ Upper(cName) .or. "DBGCLIENT" $ Upper(cName)
         loop
      endif
      cOut += " " + cName + "(" + LTrim( Str( ProcLine( i ) ) ) + ")"
   next

   DbgSend( cOut )

return nil

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
