/* HB_ProjectTabInfo and HB_PrgBaseName */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST HB_ProjectTabInfo
REQUEST HB_PrgBaseName
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()
   LOCAL aInfo

   aInfo := HB_ProjectTabInfo( 1, 2, 1 )
   TEST_ASSERT_EQ( aInfo[1], "project", "tab 1 is project" )
   TEST_ASSERT_EQ( aInfo[2], 0, "project tab index" )

   aInfo := HB_ProjectTabInfo( 2, 2, 1 )
   TEST_ASSERT_EQ( aInfo[1], "form", "tab 2 is form" )
   TEST_ASSERT_EQ( aInfo[2], 1, "first form index" )

   aInfo := HB_ProjectTabInfo( 4, 2, 1 )
   TEST_ASSERT_EQ( aInfo[1], "module", "tab 4 is module" )
   TEST_ASSERT_EQ( aInfo[2], 1, "first module index" )

   aInfo := HB_ProjectTabInfo( 5, 2, 1 )
   TEST_ASSERT_EQ( aInfo[1], "openfile", "tab 5 is open file" )
   TEST_ASSERT_EQ( aInfo[2], 1, "first open file index" )

   TEST_ASSERT_EQ( HB_PrgBaseName( "C:\proj\utils.prg" ), "utils", "windows path basename" )
   TEST_ASSERT_EQ( HB_PrgBaseName( "/home/proj/helpers.prg" ), "helpers", "unix path basename" )
   TEST_ASSERT_EQ( HB_PrgBaseName( "" ), "", "empty filename" )

RETURN TestPass( "project tab" )