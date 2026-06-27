/* Canonical CT_* values — must stay aligned with include/hbide_ct.h */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST TestFail
REQUEST TestPass

FUNCTION Main()

   TEST_ASSERT_EQ( CT_FORM, 0, "CT_FORM" )
   TEST_ASSERT_EQ( CT_TIMER, 38, "CT_TIMER" )
   TEST_ASSERT_EQ( CT_BAND, 132, "CT_BAND" )
   TEST_ASSERT_EQ( CT_MAINMENU_LEGACY, 132, "CT_MAINMENU_LEGACY" )
   TEST_ASSERT_EQ( CT_POPUPMENU_LEGACY, 136, "CT_POPUPMENU_LEGACY" )
   TEST_ASSERT_EQ( CT_MAP, 140, "CT_MAP" )
   TEST_ASSERT_EQ( CT_MAINMENU, 200, "CT_MAINMENU" )
   TEST_ASSERT_EQ( CT_POPUPMENU, 201, "CT_POPUPMENU" )

   /* Linux palette fix: menus use 200/201, not legacy 132/136 */
   TEST_ASSERT( CT_MAINMENU != CT_BAND, "main menu distinct from band" )
   TEST_ASSERT( CT_POPUPMENU != CT_POPUPMENU_LEGACY, "canonical popup != legacy" )

RETURN TestPass( "ct constants" )