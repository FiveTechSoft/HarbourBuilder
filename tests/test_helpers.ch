/* Shared assertions for headless Harbour tests */

#ifndef _TEST_HELPERS_CH
#define _TEST_HELPERS_CH

#define TEST_FAIL( msg )    TestFail( __FILE__, __LINE__, (msg) )

#define TEST_ASSERT( cond, msg ) ;
   IF !(cond); TestFail( __FILE__, __LINE__, (msg) ); ENDIF

#define TEST_ASSERT_EQ( got, exp, msg ) ;
   IF (got) != (exp); ;
      TestFail( __FILE__, __LINE__, (msg) + " (got=" + hb_ValToStr(got) + " exp=" + hb_ValToStr(exp) + ")" ); ;
   ENDIF

#endif