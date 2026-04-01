// test_design_gtk.prg - Design mode with live inspector (Linux GTK3 version)

#include "../harbour/commands.ch"

function Main()

   local oForm, oCbx, oChk, oBtn, oEdit

   DEFINE FORM oForm TITLE "Design Mode" SIZE 500, 400 FONT "Sans", 12

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

   oForm:Destroy()

return nil

// Framework - Harbour OOP wrappers (same as other platforms, they just call UI_* bridge functions)
#include "../harbour/classes.prg"
#include "../harbour/inspector_gtk.prg"
