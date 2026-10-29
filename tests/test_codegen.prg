/* Codegen string helpers and control-type normalization */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST HB_EscapeHarbourStr
REQUEST HB_QHarbourStr
REQUEST HB_NormalizeCtrlType
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()
   LOCAL c, cQ, cEsc

   c := 'Say "Hello"' + Chr(13) + Chr(10) + 'path\file'
   cQ := HB_QHarbourStr( c )
   cEsc := HB_EscapeHarbourStr( c )

   TEST_ASSERT( HB_EscapeHarbourStr( "" ) == "", "empty string" )
   TEST_ASSERT( HB_EscapeHarbourStr( NIL ) == "", "NIL input" )
   TEST_ASSERT( '"' $ cQ, "quoted harbour string" )
   // compile-safe contract: no backslash escapes (Harbour literals do not
   // process them - "a\"b" does not compile); quotes/control chars are
   // emitted as Chr() terms and the expression must round-trip exactly
   TEST_ASSERT( ! ( '\"' $ cQ ), "no backslash-quote escape (would not compile)" )
   TEST_ASSERT_EQ( HB_HarbourStrEval( cQ ), c, "QHarbourStr round-trip quotes/CRLF/backslash" )
   TEST_ASSERT_EQ( Eval( &( "{|| " + cQ + " }" ) ), c, "QHarbourStr expression compiles and evaluates" )

   TEST_ASSERT_EQ( HB_NormalizeCtrlType( CT_POPUPMENU_LEGACY ), CT_POPUPMENU, "legacy popup menu" )
   TEST_ASSERT_EQ( HB_NormalizeCtrlType( CT_BAND ), CT_BAND, "band type unchanged" )
   TEST_ASSERT_EQ( HB_NormalizeCtrlType( CT_BUTTON ), CT_BUTTON, "ordinary type unchanged" )

RETURN TestPass( "codegen" )