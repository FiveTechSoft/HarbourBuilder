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
   oForm:cText   := "Preferencias"
   oForm:nWidth  := 471
   oForm:nHeight := 405

   o := UIGroupBox():New();  o:Init( oForm )
   o:cName := "grpGeneral";  o:cText := "General"
   o:nLeft := 12;  o:nTop := 13;  o:nWidth := 431;  o:nHeight := 122

   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblIdioma";  o:cText := "Idioma:"
   o:nLeft := 26;  o:nTop := 43;  o:nWidth := 79

   o := UIComboBox():New();  o:Init( oForm )
   o:cName := "cboIdioma"
   o:nLeft := 112;  o:nTop := 39;  o:nWidth := 175
   o:SetProp( "Items", { "Espanol", "English", "Portugues", "Deutsch" } )

   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblRuta";  o:cText := "Ruta:"
   o:nLeft := 26;  o:nTop := 77;  o:nWidth := 79

   o := UIEdit():New();  o:Init( oForm )
   o:cName := "edtRuta";  o:cText := "C:\Projects"
   o:nLeft := 112;  o:nTop := 73;  o:nWidth := 312;  o:nHeight := 24

   o := UIGroupBox():New();  o:Init( oForm )
   o:cName := "grpApariencia";  o:cText := "Apariencia"
   o:nLeft := 12;  o:nTop := 146;  o:nWidth := 431;  o:nHeight := 150

   o := UILabel():New();  o:Init( oForm )
   o:cName := "lblFuente";  o:cText := "Fuente:"
   o:nLeft := 26;  o:nTop := 176;  o:nWidth := 79

   o := UIComboBox():New();  o:Init( oForm )
   o:cName := "cboFuente"
   o:nLeft := 112;  o:nTop := 173;  o:nWidth := 210
   o:SetProp( "Items", { "Segoe UI", "Tahoma", "Arial", "Consolas" } )

   o := UICheckBox():New();  o:Init( oForm )
   o:cName := "chkToolbar";  o:cText := "Mostrar barra de herramientas"
   o:nLeft := 112;  o:nTop := 210;  o:nWidth := 245
   o:SetProp( "Checked", .t. )

   o := UICheckBox():New();  o:Init( oForm )
   o:cName := "chkStatus";  o:cText := "Mostrar barra de estado"
   o:nLeft := 112;  o:nTop := 234;  o:nWidth := 245
   o:SetProp( "Checked", .t. )

   o := UICheckBox():New();  o:Init( oForm )
   o:cName := "chkConfirm";  o:cText := "Confirmar al salir"
   o:nLeft := 112;  o:nTop := 259;  o:nWidth := 245
   o:SetProp( "Checked", .t. )

   o := UIButton():New();  o:Init( oForm )
   o:cName := "btnAceptar";  o:cText := "&Aceptar"
   o:nLeft := 170;  o:nTop := 326

   o := UIButton():New();  o:Init( oForm )
   o:cName := "btnCancelar";  o:cText := "&Cancelar"
   o:nLeft := 266;  o:nTop := 326

return oForm

// Framework
#include "c:\ide\core\property.prg"
#include "c:\ide\core\control.prg"
#include "c:\ide\core\controls.prg"
#include "c:\ide\core\json.prg"
#include "c:\ide\backends\web\backend.prg"
