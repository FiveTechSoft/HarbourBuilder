// Unit test for HB_QHarbourStr / HB_HarbourStrEval (T4 audit: whitespace-only
// segments must survive). Prints "QSTR FAIL: ..." lines; QSTR PASS at the end.
function Main()
   local nFail := 0
   nFail += QCheck( "", '""' )
   nFail += QCheck( "A", '"A"' )
   nFail += QCheck( " ", '" "' )
   nFail += QCheck( "  ", '"  "' )
   nFail += QCheck( " Nombre ", '" Nombre "' )
   nFail += QCheck( "A" + Chr(9) + "B", '"A" + Chr(9) + "B"' )
   nFail += QCheck( " " + Chr(9) + "B", '" " + Chr(9) + "B"' )
   nFail += QCheck( 'Di "si"', '"Di " + Chr(34) + "si" + Chr(34)' )
   nFail += QCheck( "a'b", '"a" + Chr(39) + "b"' )
   // eval(quote(x)) must round-trip to x exactly
   nFail += RTCheck( "" )
   nFail += RTCheck( " " )
   nFail += RTCheck( "  " )
   nFail += RTCheck( " Nombre " )
   nFail += RTCheck( "A" + Chr(9) + "B" )
   nFail += RTCheck( " " + Chr(9) + " " )
   nFail += RTCheck( 'Di "si"' )
   if nFail == 0
      QOut( "QSTR PASS: whitespace-only, quote and tab segments preserved; eval round-trips" )
   else
      QOut( "QSTR FAIL: " + hb_ntos( nFail ) + " check(s)" )
   endif
return nFail

function QCheck( cIn, cWant )
   local cGot := HB_QHarbourStr( cIn )
   if !( cGot == cWant )
      QOut( "QSTR FAIL: HB_QHarbourStr(" + ValDisp( cIn ) + ") = " + cGot + " want " + cWant )
      return 1
   endif
return 0

function RTCheck( cIn )
   local cQ := HB_QHarbourStr( cIn )
   local xBack := HB_HarbourStrEval( cQ )
   if xBack == nil .or. !( xBack == cIn )
      QOut( "QSTR FAIL: roundtrip " + ValDisp( cIn ) + " via " + cQ + " gave " + ValDisp( xBack ) )
      return 1
   endif
return 0

function ValDisp( x )
   if x == nil; return "NIL"; endif
   if ValType( x ) != "C"; return hb_ValToExp( x ); endif
   if Empty( x ); return iif( Len( x ) == 0, "<empty>", "<" + hb_ntos( Len( x ) ) + " spaces>" ); endif
return x
