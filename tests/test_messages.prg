/* IDE messages panel helpers */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST IDE_MessagesHeight
REQUEST IDE_LogLine
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()

   TEST_ASSERT( IDE_MessagesHeight( 1080 ) >= 96, "messages height scaled" )
   TEST_ASSERT_EQ( IDE_MessagesHeight( 0 ), 120, "messages height default" )
   TEST_ASSERT( "step1" $ IDE_LogLine( "", "step1" + Chr(10) ), "log line append" )

RETURN TestPass( "messages helpers" )