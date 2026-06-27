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
   TEST_ASSERT( '\"' $ cQ, "inner quote escaped in QHarbourStr" )
   TEST_ASSERT( '\\' $ cEsc, "backslash escaped" )
   TEST_ASSERT( '\r' $ cEsc .AND. '\n' $ cEsc, "CR/LF escaped" )

   TEST_ASSERT_EQ( HB_NormalizeCtrlType( CT_POPUPMENU_LEGACY ), CT_POPUPMENU, "legacy popup menu" )
   TEST_ASSERT_EQ( HB_NormalizeCtrlType( CT_BAND ), CT_BAND, "band type unchanged" )
   TEST_ASSERT_EQ( HB_NormalizeCtrlType( CT_BUTTON ), CT_BUTTON, "ordinary type unchanged" )

RETURN TestPass( "codegen" )