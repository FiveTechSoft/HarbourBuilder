// test_oop.prg - Preferences using Harbour OOP + C++ core
// Clean, intuitive object syntax. C++ does all the heavy lifting.

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm, oGrp, oLbl, oCbx, oEdit, oChk, oBtn

   // Form
   oForm := TForm():New( "Preferencias", 471, 405 )
   oForm:FontName := "Segoe UI"
   oForm:FontSize := 12

   // General group
   TGroupBox():New( oForm, "General", 12, 13, 431, 122 )

   TLabel():New( oForm, "Idioma:", 26, 43 )
   oCbx := TComboBox():New( oForm, 112, 39, 175 )
   oCbx:AddItem( "Espanol" )
   oCbx:AddItem( "English" )
   oCbx:AddItem( "Portugues" )
   oCbx:AddItem( "Deutsch" )
   oCbx:Value := 0
   oCbx:OnChange := { |h| MsgInfo( "Idioma cambiado!" ) }

   TLabel():New( oForm, "Ruta:", 26, 77 )
   oEdit := TEdit():New( oForm, "C:\Projects", 112, 73, 312, 24 )

   // Apariencia group
   TGroupBox():New( oForm, "Apariencia", 12, 146, 431, 150 )

   TLabel():New( oForm, "Fuente:", 26, 176 )
   oCbx := TComboBox():New( oForm, 112, 173, 210 )
   oCbx:AddItem( "Segoe UI" )
   oCbx:AddItem( "Tahoma" )
   oCbx:AddItem( "Arial" )
   oCbx:AddItem( "Consolas" )
   oCbx:Value := 0

   // Checkboxes
   oChk := TCheckBox():New( oForm, "Mostrar barra de herramientas", 112, 210, 245 )
   oChk:Checked := .t.

   oChk := TCheckBox():New( oForm, "Mostrar barra de estado", 112, 234, 245 )
   oChk:Checked := .t.

   oChk := TCheckBox():New( oForm, "Confirmar al salir", 112, 259, 245 )
   oChk:Checked := .t.

   // Buttons
   oBtn := TButton():New( oForm, "&Aceptar", 170, 326 )
   oBtn:Default := .t.
   oBtn:OnClick := { |h| MsgInfo( "Aceptar!" ) }

   oBtn := TButton():New( oForm, "&Cancelar", 266, 326 )
   oBtn:Cancel := .t.

   // Go!
   oForm:Activate()
   oForm:Destroy()

return nil

// Simple MsgInfo (no FiveWin dependency)
function MsgInfo( cMsg )
   W32_MsgBox( cMsg, "Info" )
return nil

// Framework classes
#include "c:\ide\harbour\classes.prg"

// MsgBox in C
#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>
HB_FUNC( W32_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2), MB_OK | MB_ICONINFORMATION );
}
#pragma ENDDUMP
