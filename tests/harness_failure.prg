/* A prefix mismatch must fail: Harbour =/!= depend on SET EXACT. */
#include "test_helpers.ch"
FUNCTION Main()
   TEST_ASSERT_EQ( "prefix/child", "prefix", "intentional exact-match failure" )
RETURN TestPass( "harness self-check" )
