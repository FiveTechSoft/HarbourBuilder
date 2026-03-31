// prefs_web.prg - Preferences as HTML page
// Same abstract form, rendered to HTML/CSS/JS

#include "hbide.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm

   oForm := BuildPrefsForm()
   WebBackend():New():Run( oForm )

return nil

function BuildPrefsForm()

   local oForm, o

   oForm := UIForm():New()
   oForm:Init( nil )
   oForm:cName  := "frmPrefs"
   oForm:Text   := "Preferencias"
   oForm:Width  := 471
   oForm:Height := 405

   o := UIGroupBox():New();  o:Init( oForm )
   o:cName := "grpGeneral";  o:Text := "General"
   o:Left := 12;  o:Top := 13;  o:Width := 431;  o:Height := 122

   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblIdioma";  o:Text := "Idioma:"
   o:Left := 26;  o:Top := 43;  o:Width := 79

   o := UIComboBox():New();  o:Init( oForm )
   o:cName := "cboIdioma"
   o:Left := 112;  o:Top := 39;  o:Width := 175
   o:SetProp( "Items", { "Espanol", "English", "Portugues", "Deutsch" } )

   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblRuta";  o:Text := "Ruta:"
   o:Left := 26;  o:Top := 77;  o:Width := 79

   o := UIEdit():New();  o:Init( oForm )
   o:cName := "edtRuta";  o:Text := "C:\Projects"
   o:Left := 112;  o:Top := 73;  o:Width := 312;  o:Height := 24

   o := UIGroupBox():New();  o:Init( oForm )
   o:cName := "grpApariencia";  o:Text := "Apariencia"
   o:Left := 12;  o:Top := 146;  o:Width := 431;  o:Height := 150

   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblFuente";  o:Text := "Fuente:"
   o:Left := 26;  o:Top := 176;  o:Width := 79

   o := UIComboBox():New();  o:Init( oForm )
   o:cName := "cboFuente"
   o:Left := 112;  o:Top := 173;  o:Width := 210
   o:SetProp( "Items", { "Segoe UI", "Tahoma", "Arial", "Consolas" } )

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

   o := UIButton():New();  o:Init( oForm )
   o:cName := "btnAceptar";  o:Text := "&Aceptar"
   o:Left := 170;  o:Top := 326

   o := UIButton():New();  o:Init( oForm )
   o:cName := "btnCancelar";  o:Text := "&Cancelar"
   o:Left := 266;  o:Top := 326

return oForm

// Framework
#include "c:\ide\core\property.prg"
#include "c:\ide\core\control.prg"
#include "c:\ide\core\controls.prg"
#include "c:\ide\core\json.prg"
#include "c:\ide\backends\web\backend.prg"
