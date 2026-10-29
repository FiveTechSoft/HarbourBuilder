/* Headless persistence of the project index, not a GUI Save/Reload test. */
#include "test_helpers.ch"
FUNCTION Main()
   LOCAL cFile := "", nHandle := hb_FTempCreate( hb_DirTemp(), "hbr", NIL, @cFile )
   LOCAL aForms := { { "Form1", NIL }, { "Formulario_á", NIL } }
   LOCAL aModules := { { "utilidades", NIL, "" } }
   LOCAL cIndex := HB_BuildHbpFromProject( aForms, aModules )
   LOCAL cRead, aParsed
   TEST_ASSERT( nHandle != -1, "create private temporary fixture" )
   IF nHandle == -1
      RETURN TestPass( "project index disk roundtrip" )
   ENDIF
   FClose( nHandle )
   TEST_ASSERT( hb_MemoWrit( cFile, cIndex ), "write project index" )
   cRead := hb_MemoRead( cFile )
   TEST_ASSERT_EQ( cRead, cIndex, "disk bytes preserved" )
   aParsed := HB_ParseHbpIndex( cRead )
   TEST_ASSERT_EQ( Len( aParsed[1] ), 2, "two forms restored" )
   TEST_ASSERT_EQ( aParsed[1][2], "Formulario_á", "UTF-8 name preserved" )
   TEST_ASSERT_EQ( aParsed[2][1], "utilidades", "module restored" )
   TEST_ASSERT_EQ( HB_BuildHbpIndex( aParsed[1], aParsed[2] ), cIndex, "second save unchanged" )
   TEST_ASSERT_EQ( FErase( cFile ), 0, "remove own fixture" )
RETURN TestPass( "project index disk roundtrip" )
