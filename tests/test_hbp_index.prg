/* HB_BuildHbpIndex — project file [modules] section */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST HB_BuildHbpIndex
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()
   LOCAL cHbp, aLines, i

   cHbp := HB_BuildHbpIndex( { "Form1", "Form2" }, { "utils", "helpers" } )
   aLines := hb_ATokens( cHbp, Chr(10) )

   TEST_ASSERT_EQ( Len( aLines ), 6, "header + 2 forms + [modules] + 2 modules" )
   TEST_ASSERT_EQ( aLines[1], "Project1", "project header" )
   TEST_ASSERT_EQ( aLines[2], "Form1", "first form" )
   TEST_ASSERT_EQ( aLines[3], "Form2", "second form" )
   TEST_ASSERT_EQ( aLines[4], "[modules]", "modules section" )
   TEST_ASSERT_EQ( aLines[5], "utils", "first module" )
   TEST_ASSERT_EQ( aLines[6], "helpers", "second module" )

   cHbp := HB_BuildHbpIndex( { "Main" }, {} )
   aLines := hb_ATokens( cHbp, Chr(10) )
   TEST_ASSERT_EQ( Len( aLines ), 2, "no modules section when empty" )
   TEST_ASSERT( ! ( "[modules]" $ cHbp ), "no [modules] tag without modules" )

RETURN TestPass( "hbp index" )