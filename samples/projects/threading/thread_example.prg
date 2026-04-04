// thread_example.prg - Threading components demo
// Shows TThread, TMutex, and TChannel

#include "hbbuilder.ch"

static s_nCounter := 0

function Main()

   local oMtx, oChan, oThread, i, xVal

   ? "=== Threading Components Example ==="
   ?

   // --- TMutex ---
   ? "1. TMutex - thread-safe locking:"
   oMtx := TMutex():New()
   ? "   Mutex created: " + iif( oMtx:pHandle != nil, "Yes", "No" )

   oMtx:Lock()
   s_nCounter := 42
   ? "   Counter (locked): " + LTrim(Str(s_nCounter))
   oMtx:Unlock()
   ? "   Mutex lock/unlock: OK"
   ?

   // --- TChannel ---
   ? "2. TChannel - thread-safe message queue:"
   oChan := TChannel():New()
   ? "   Channel created, queue size: " + LTrim(Str(oChan:Count()))

   oChan:Send( "Hello" )
   oChan:Send( 42 )
   oChan:Send( { 1, 2, 3 } )
   ? "   Sent 3 messages, queue size: " + LTrim(Str(oChan:Count()))

   xVal := oChan:Receive()
   ? "   Receive 1: " + hb_ValToStr( xVal ) + " (type: " + ValType(xVal) + ")"

   xVal := oChan:Receive()
   ? "   Receive 2: " + hb_ValToStr( xVal ) + " (type: " + ValType(xVal) + ")"

   xVal := oChan:Receive()
   ? "   Receive 3: " + hb_ValToStr( xVal ) + " (type: " + ValType(xVal) + ")"

   ? "   Queue after drain: " + LTrim(Str(oChan:Count()))

   xVal := oChan:Receive()
   ? "   Receive from empty: " + iif( xVal == nil, "NIL (correct)", "ERROR" )
   ?

   // --- TThread ---
   ? "3. TThread - background execution:"
   s_nCounter := 0

   oThread := TThread():New( { || WorkerTask() } )
   ? "   Starting worker thread..."
   oThread:Start()
   ? "   Thread started: " + iif( oThread:IsRunning(), "Yes", "No" )
   ? "   Thread handle: " + iif( oThread:pHandle != nil, "valid", "nil" )

   // Wait for thread to finish
   if oThread:pHandle != nil
      hb_threadWait( oThread:pHandle, 5 )  // wait up to 5 seconds
   endif

   ? "   Counter after thread: " + LTrim(Str(s_nCounter))
   ?

   // --- Producer-Consumer pattern ---
   ? "4. Producer-Consumer with TChannel:"
   oChan := TChannel():New()

   // Producer thread
   oThread := TThread():New( { || ProducerTask( oChan ) } )
   oThread:Start()

   if oThread:pHandle != nil
      hb_threadWait( oThread:pHandle, 5 )
   endif

   ? "   Consumer reading:"
   for i := 1 to 5
      xVal := oChan:Receive()
      if xVal != nil
         ? "     Item " + LTrim(Str(i)) + ": " + hb_ValToStr( xVal )
      endif
   next

   ? "   Remaining in queue: " + LTrim(Str(oChan:Count()))
   ?
   ? "=== Done ==="

return nil

static function WorkerTask()
   local i
   for i := 1 to 10
      s_nCounter++
      hb_idleSleep( 0.01 )  // simulate work
   next
return nil

static function ProducerTask( oChan )
   local i
   for i := 1 to 5
      oChan:Send( "Item_" + LTrim(Str(i)) )
      hb_idleSleep( 0.01 )
   next
return nil
