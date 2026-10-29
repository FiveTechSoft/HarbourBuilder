/* ITEMS clause parsing: top-level comma split + restricted eval (R2) */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST HB_SplitTopLevelCommas
REQUEST HB_HarbourStrEval
REQUEST HB_QHarbourStr
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()
   LOCAL a, cJoined := "", i

   // quotes are written as Chr() terms; commas inside items must not split
   a := HB_SplitTopLevelCommas( '"Uno", "Di " + Chr( 34 ) + "si" + Chr( 34 ), "Tre, s" ' )
   TEST_ASSERT_EQ( Len( a ), 3, "top-level split count" )
   for i := 1 to Len( a )
      a[ i ] := HB_HarbourStrEval( AllTrim( a[ i ] ) )
      TEST_ASSERT( a[ i ] != nil, "item " + hb_ValToStr( i ) + " evaluates" )
      cJoined += a[ i ] + "|"
   next
   TEST_ASSERT_EQ( a[ 2 ], 'Di "si"', "quoted item survives exactly" )
   TEST_ASSERT_EQ( a[ 3 ], "Tre, s", "comma inside item survives" )

   // the restricted eval never accepts arbitrary source (B3 architecture)
   TEST_ASSERT( HB_HarbourStrEval( "SomeFunc( 1 )" ) == nil, "arbitrary code refused" )
   TEST_ASSERT( HB_HarbourStrEval( "'single'" ) == nil, "single-quote literal refused" )
   TEST_ASSERT( HB_HarbourStrEval( '"a" - 1' ) == nil, "non-plus operator refused" )

   // generator round-trip: re-emit and re-parse, text must be identical
   TEST_ASSERT_EQ( HB_HarbourStrEval( HB_QHarbourStr( a[ 2 ] ) ), a[ 2 ], "quotes round-trip" )
   TEST_ASSERT_EQ( HB_HarbourStrEval( HB_QHarbourStr( a[ 3 ] ) ), a[ 3 ], "comma round-trip" )
   TEST_ASSERT_EQ( HB_HarbourStrEval( HB_QHarbourStr( "" ) ), "", "empty round-trip" )

   ? "OK items-parse:", cJoined
RETURN 0
