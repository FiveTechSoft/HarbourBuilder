// test_inspector.prg - Demo: click a button to inspect any control

#include "c:\ide\harbour\commands.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm, oCbx, oChk, oBtnOk, oBtnInspect

   DEFINE FORM oForm TITLE "Inspector Demo" SIZE 400, 300 FONT "Segoe UI", 12

   @ 10, 10 SAY "Name:" OF oForm SIZE 60
   @ 8, 80 GET oEdit VAR "Hello World" OF oForm SIZE 200, 24

   @ 45, 10 SAY "Language:" OF oForm SIZE 70
   @ 43, 80 COMBOBOX oCbx OF oForm ITEMS { "Espanol", "English", "Deutsch" } SIZE 150
   oCbx:Value := 0
   oCbx:Name := "cboLanguage"

   @ 80, 80 CHECKBOX oChk PROMPT "Active" OF oForm SIZE 120 CHECKED
   oChk:Name := "chkActive"

   // Inspect button - opens inspector for the combobox
   @ 130, 10 BUTTON oBtnInspect PROMPT "Inspect ComboBox" OF oForm SIZE 160, 26
   oBtnInspect:OnClick := { |h| Inspector( oCbx:hCpp ) }

   // Inspect checkbox
   @ 130, 180 BUTTON oBtnInspect PROMPT "Inspect CheckBox" OF oForm SIZE 160, 26
   oBtnInspect:OnClick := { |h| Inspector( oChk:hCpp ) }

   // Close
   @ 220, 155 BUTTON oBtnOk PROMPT "&Close" OF oForm SIZE 88, 26 CANCEL

   ACTIVATE FORM oForm CENTERED
   oForm:Destroy()

return nil

function MsgInfo( cMsg )
   W32_MsgBox( cMsg, "Info" )
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
