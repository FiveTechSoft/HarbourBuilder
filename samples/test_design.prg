// test_design.prg - Design mode with live inspector

#include "c:\ide\harbour\commands.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm, oCbx, oChk, oBtn

   DEFINE FORM oForm TITLE "Design Mode" SIZE 500, 400 FONT "Segoe UI", 12

   @ 13, 12 GROUPBOX "General" OF oForm SIZE 460, 120

   @ 40, 26 SAY "Name:" OF oForm SIZE 60
   @ 38, 100 GET oEdit VAR "John Doe" OF oForm SIZE 200, 24

   @ 75, 26 SAY "City:" OF oForm SIZE 60
   @ 73, 100 GET oEdit VAR "Madrid" OF oForm SIZE 200, 24

   @ 150, 12 GROUPBOX "Options" OF oForm SIZE 460, 100

   @ 175, 30 CHECKBOX oChk PROMPT "Active" OF oForm SIZE 120 CHECKED
   @ 175, 180 CHECKBOX oChk PROMPT "Admin" OF oForm SIZE 120

   @ 210, 30 SAY "Role:" OF oForm SIZE 50
   @ 208, 100 COMBOBOX oCbx OF oForm ITEMS { "User", "Manager", "Admin" } SIZE 150
   oCbx:Value := 0

   @ 300, 150 BUTTON oBtn PROMPT "&OK" OF oForm SIZE 88, 26
   @ 300, 250 BUTTON oBtn PROMPT "&Cancel" OF oForm SIZE 88, 26

   // Open inspector window showing form properties by default
   InspectorOpen()
   InspectorRefresh( oForm:hCpp )

   // When selection changes, refresh inspector (0 = no selection = show form)
   UI_OnSelChange( oForm:hCpp, ;
      { |hCtrl| InspectorRefresh( If( hCtrl == 0, oForm:hCpp, hCtrl ) ) } )

   // Enable design mode
   oForm:SetDesign( .t. )

   oForm:Activate()

   // Cleanup
   InspectorClose()

   W32_MsgBox( oForm:ToJSON(), "Final Layout" )
   oForm:Destroy()

return nil

// Framework
#include "c:\ide\harbour\classes.prg"
#include "c:\ide\harbour\inspector.prg"

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>
HB_FUNC( W32_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2), MB_OK | MB_ICONINFORMATION );
}
#pragma ENDDUMP
