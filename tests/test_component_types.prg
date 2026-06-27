/* Component type metadata round-trip */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST IsNonVisual
REQUEST ComponentTypeName
REQUEST ComponentTypeFromName
REQUEST ResolveComponentType
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()

   TEST_ASSERT( IsNonVisual( CT_TIMER ), "timer is non-visual" )
   TEST_ASSERT( IsNonVisual( CT_MAINMENU ), "main menu is non-visual" )
   TEST_ASSERT( ! IsNonVisual( CT_BUTTON ), "button is visual" )
   TEST_ASSERT( ! IsNonVisual( CT_WEBVIEW ), "webview is visual" )
   TEST_ASSERT( ! IsNonVisual( CT_BAND ), "report band is visual" )

   TEST_ASSERT_EQ( ComponentTypeFromName( "CT_TIMER" ), CT_TIMER, "name to id" )
   TEST_ASSERT_EQ( ComponentTypeFromName( "ct_mainmenu" ), CT_MAINMENU, "case insensitive" )
   TEST_ASSERT_EQ( ComponentTypeFromName( "UNKNOWN" ), 0, "unknown name" )

   TEST_ASSERT_EQ( ComponentTypeName( CT_POPUPMENU ), "CT_POPUPMENU", "id to name" )
   TEST_ASSERT_EQ( ResolveComponentType( "CT_BAND" ), CT_BAND, "resolve alias" )

RETURN TestPass( "component types" )