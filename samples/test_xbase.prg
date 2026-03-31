// test_xbase.prg - Preferences using xBase commands
// Familiar Clipper/FiveWin-like syntax, C++ core underneath.

#include "c:\ide\harbour\commands.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm, oCbx, oEdit, oChk, oBtn

   DEFINE FORM oForm TITLE "Preferencias" SIZE 471, 405 FONT "Segoe UI", 12

   // General
   @ 13, 12 GROUPBOX "General" OF oForm SIZE 431, 122
   @ 43, 26 SAY "Idioma:" OF oForm SIZE 79
   @ 39, 112 COMBOBOX oCbx OF oForm ITEMS { "Espanol", "English", "Portugues", "Deutsch" } SIZE 175
   oCbx:Value := 0

   @ 77, 26 SAY "Ruta:" OF oForm SIZE 79
   @ 73, 112 GET oEdit VAR "C:\Projects" OF oForm SIZE 312, 24

   // Apariencia
   @ 146, 12 GROUPBOX "Apariencia" OF oForm SIZE 431, 150
   @ 176, 26 SAY "Fuente:" OF oForm SIZE 79
   @ 173, 112 COMBOBOX oCbx OF oForm ITEMS { "Segoe UI", "Tahoma", "Arial", "Consolas" } SIZE 210
   oCbx:Value := 0

   @ 210, 112 CHECKBOX oChk PROMPT "Mostrar barra de herramientas" OF oForm SIZE 245 CHECKED
   @ 234, 112 CHECKBOX oChk PROMPT "Mostrar barra de estado" OF oForm SIZE 245 CHECKED
   @ 259, 112 CHECKBOX oChk PROMPT "Confirmar al salir" OF oForm SIZE 245 CHECKED

   // Buttons
   @ 326, 170 BUTTON oBtn PROMPT "&Aceptar" OF oForm SIZE 88, 26 DEFAULT
   oBtn:OnClick := { |h| MsgInfo( "Aceptar!" ) }

   @ 326, 266 BUTTON oBtn PROMPT "&Cancelar" OF oForm SIZE 88, 26 CANCEL

   ACTIVATE FORM oForm CENTERED

   oForm:Destroy()

return nil

function MsgInfo( cMsg )
   W32_MsgBox( cMsg, "Info" )
return nil

// Framework
#include "c:\ide\harbour\classes.prg"

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>
HB_FUNC( W32_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2), MB_OK | MB_ICONINFORMATION );
}
#pragma ENDDUMP
