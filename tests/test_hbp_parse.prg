/* HB_ParseHbpIndex, HB_BuildHbpFromProject, HB_ProjectDirFromFile, tab helpers */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST HB_ParseHbpIndex
REQUEST HB_BuildHbpFromProject
REQUEST HB_BuildHbpIndex
REQUEST HB_ProjectDirFromFile
REQUEST HB_ModuleEditorTab
REQUEST HB_OpenFileEditorTab
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()
   LOCAL cHbp, aParsed, aForms, aModules

   cHbp := "Project1" + Chr(10) + "Form1" + Chr(10) + "Form2" + Chr(10) + ;
           "[modules]" + Chr(10) + "utils" + Chr(10)
   aParsed := HB_ParseHbpIndex( cHbp )
   aForms := aParsed[1]
   aModules := aParsed[2]

   TEST_ASSERT_EQ( Len( aForms ), 2, "parsed form count" )
   TEST_ASSERT_EQ( aForms[1], "Form1", "first form name" )
   TEST_ASSERT_EQ( Len( aModules ), 1, "parsed module count" )
   TEST_ASSERT_EQ( aModules[1], "utils", "module name" )

   cHbp := HB_BuildHbpFromProject( { { "Main", NIL } }, { { "helpers", NIL, "" } } )
   aParsed := HB_ParseHbpIndex( cHbp )
   TEST_ASSERT_EQ( aParsed[1][1], "Main", "round-trip form" )
   TEST_ASSERT_EQ( aParsed[2][1], "helpers", "round-trip module" )

   TEST_ASSERT_EQ( HB_ProjectDirFromFile( "C:\proj\demo\Project1.hbp" ), "C:\proj\demo\", "win project dir" )
   TEST_ASSERT_EQ( HB_ProjectDirFromFile( "/home/user/app/Project1.hbp" ), "/home/user/app/", "unix project dir" )

   TEST_ASSERT_EQ( HB_ModuleEditorTab( 2, 1 ), 4, "module tab index" )
   TEST_ASSERT_EQ( HB_OpenFileEditorTab( 2, 1, 2 ), 6, "open file tab index" )

RETURN TestPass( "hbp parse" )