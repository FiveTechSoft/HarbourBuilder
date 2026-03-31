// prefs.prg - Preferences dialog rendered on 3 backends
// Same abstract form → Win32 GUI + Console TUI + Web HTML
// Zero external dependencies.

#include "hbide.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm, cJSON

   // Build form
   oForm := BuildPrefsForm()

   // Save to JSON
   cJSON := FormToJSON( oForm )
   MemoWrit( "prefs.json", cJSON )

   // Win32 GUI
   Win32Backend():New():Run( oForm )

return nil

function BuildPrefsForm()

   local oForm, o

   oForm := UIForm():New()
   oForm:Init( nil )
   oForm:cName  := "frmPrefs"
   oForm:Text   := "Preferencias"
   oForm:Width  := 471
   oForm:Height := 405

   // GroupBox: General
   o := UIGroupBox():New();  o:Init( oForm )
   o:cName := "grpGeneral";  o:Text := "General"
   o:Left := 12;  o:Top := 13;  o:Width := 431;  o:Height := 122

   // Idioma
   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblIdioma";  o:Text := "Idioma:"
   o:Left := 26;  o:Top := 43;  o:Width := 79

   o := UIComboBox():New();  o:Init( oForm )
   o:cName := "cboIdioma"
   o:Left := 112;  o:Top := 39;  o:Width := 175
   o:SetProp( "Items", { "Espanol", "English", "Portugues", "Deutsch" } )

   // Ruta
   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblRuta";  o:Text := "Ruta:"
   o:Left := 26;  o:Top := 77;  o:Width := 79

   o := UIEdit():New();  o:Init( oForm )
   o:cName := "edtRuta";  o:Text := "C:\Projects"
   o:Left := 112;  o:Top := 73;  o:Width := 312;  o:Height := 24

   // GroupBox: Apariencia
   o := UIGroupBox():New();  o:Init( oForm )
   o:cName := "grpApariencia";  o:Text := "Apariencia"
   o:Left := 12;  o:Top := 146;  o:Width := 431;  o:Height := 150

   // Fuente
   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblFuente";  o:Text := "Fuente:"
   o:Left := 26;  o:Top := 176;  o:Width := 79

   o := UIComboBox():New();  o:Init( oForm )
   o:cName := "cboFuente"
   o:Left := 112;  o:Top := 173;  o:Width := 210
   o:SetProp( "Items", { "Segoe UI", "Tahoma", "Arial", "Consolas" } )

   // Checkboxes
   o := UICheckBox():New();  o:Init( oForm )
   o:cName := "chkToolbar";  o:Text := "Mostrar barra de herramientas"
   o:Left := 112;  o:Top := 210;  o:Width := 245
   o:SetProp( "Checked", .t. )

   o := UICheckBox():New();  o:Init( oForm )
   o:cName := "chkStatus";  o:Text := "Mostrar barra de estado"
   o:Left := 112;  o:Top := 234;  o:Width := 245
   o:SetProp( "Checked", .t. )

   o := UICheckBox():New();  o:Init( oForm )
   o:cName := "chkConfirm";  o:Text := "Confirmar al salir"
   o:Left := 112;  o:Top := 259;  o:Width := 245
   o:SetProp( "Checked", .t. )

   // Buttons
   o := UIButton():New();  o:Init( oForm )
   o:cName := "btnAceptar";  o:Text := "&Aceptar"
   o:Left := 170;  o:Top := 326
   o:SetProp( "Default", .t. )

   o := UIButton():New();  o:Init( oForm )
   o:cName := "btnCancelar";  o:Text := "&Cancelar"
   o:Left := 266;  o:Top := 326
   o:SetProp( "Cancel", .t. )

return oForm

// Framework includes (will become a library)

// Simple trace (no FiveWin)
procedure LogFile( cFile, aData )
   local cLine := DToC( Date() ) + " " + Time() + ": ", n
   for n := 1 to Len( aData )
      cLine += hb_ValToStr( aData[ n ] ) + " "
   next
   hb_MemoWrit( cFile, hb_MemoRead( cFile ) + cLine + Chr(13) + Chr(10) )
return

#include "c:\ide\core\property.prg"
#include "c:\ide\core\control.prg"
#include "c:\ide\core\controls.prg"
#include "c:\ide\core\json.prg"
#include "c:\ide\backends\win32\backend.prg"
#include "c:\ide\backends\console\backend.prg"
#include "c:\ide\backends\web\backend.prg"
