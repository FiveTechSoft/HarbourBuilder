// test_web.prg - C++ core rendered on HTML5 Canvas
// Generates JSON data + fixed JS renderer

REQUEST HB_GT_GUI_DEFAULT

#define CT_FORM       0
#define CT_LABEL      1
#define CT_EDIT       2
#define CT_BUTTON     3
#define CT_CHECKBOX   4
#define CT_COMBOBOX   5
#define CT_GROUPBOX   6

#define CRLF Chr(13) + Chr(10)

function Main()

   local hForm

   hForm := BuildForm()
   MemoWrit( "canvas.html", GenCanvas( hForm ) )
   hb_run( 'start "" "canvas.html"' )
   UI_FormDestroy( hForm )

return nil

function BuildForm()

   local hForm, hCtrl

   hForm := UI_FormNew( "Preferencias", 471, 405, "Segoe UI", 12 )

   UI_GroupBoxNew( hForm, "General", 12, 13, 431, 122 )
   UI_GroupBoxNew( hForm, "Apariencia", 12, 146, 431, 150 )

   UI_LabelNew( hForm, "Idioma:", 26, 43, 79, 15 )
   UI_LabelNew( hForm, "Ruta:", 26, 77, 79, 15 )
   UI_LabelNew( hForm, "Fuente:", 26, 176, 79, 15 )

   hCtrl := UI_ComboBoxNew( hForm, 112, 39, 175, 200 )
   UI_ComboAddItem( hCtrl, "Espanol" )
   UI_ComboAddItem( hCtrl, "English" )
   UI_ComboAddItem( hCtrl, "Portugues" )
   UI_ComboAddItem( hCtrl, "Deutsch" )
   UI_ComboSetIndex( hCtrl, 0 )

   hCtrl := UI_ComboBoxNew( hForm, 112, 173, 210, 200 )
   UI_ComboAddItem( hCtrl, "Segoe UI" )
   UI_ComboAddItem( hCtrl, "Tahoma" )
   UI_ComboAddItem( hCtrl, "Arial" )
   UI_ComboAddItem( hCtrl, "Consolas" )
   UI_ComboSetIndex( hCtrl, 0 )

   UI_EditNew( hForm, "C:\\Projects", 112, 73, 312, 24 )

   hCtrl := UI_CheckBoxNew( hForm, "Mostrar barra de herramientas", 112, 210, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )
   hCtrl := UI_CheckBoxNew( hForm, "Mostrar barra de estado", 112, 234, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )
   hCtrl := UI_CheckBoxNew( hForm, "Confirmar al salir", 112, 259, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   hCtrl := UI_ButtonNew( hForm, "Aceptar", 170, 326, 88, 26 )
   UI_SetProp( hCtrl, "lDefault", .t. )
   hCtrl := UI_ButtonNew( hForm, "Cancelar", 266, 326, 88, 26 )
   UI_SetProp( hCtrl, "lCancel", .t. )

return hForm

//----------------------------------------------------------------------------//
// Generate self-contained HTML: JSON data + JS canvas renderer
//----------------------------------------------------------------------------//

function GenCanvas( hForm )

   local cJSON, cHTML, cJS

   cJSON := ControlsToJSON( hForm )
   cJS := MemoRead( "canvas.js" )

   cHTML := '<!DOCTYPE html><html><head><meta charset="UTF-8">' + CRLF
   cHTML += '<title>' + UI_GetProp(hForm,"cText") + '</title></head><body style="margin:0;display:flex;' + CRLF
   cHTML += 'justify-content:center;align-items:center;min-height:100vh;background:#808080">' + CRLF
   cHTML += '<canvas id="c"></canvas>' + CRLF
   cHTML += '<script>' + CRLF
   cHTML += 'const FORM = ' + cJSON + ';' + CRLF
   cHTML += cJS + CRLF
   cHTML += '</script></body></html>' + CRLF

return cHTML

function ControlsToJSON( hForm )

   local cJ := "{", n, nCount, hChild, nType, i
   local nItemIdx, nItemCount, cItem, lChk, cText

   cJ += '"title":"' + JE( UI_GetProp(hForm,"cText") ) + '",'
   cJ += '"w":' + LTrim(Str(UI_GetProp(hForm,"nWidth"))) + ','
   cJ += '"h":' + LTrim(Str(UI_GetProp(hForm,"nHeight"))) + ','
   cJ += '"controls":['

   nCount := UI_GetChildCount( hForm )
   for n := 1 to nCount
      hChild := UI_GetChild( hForm, n )
      if hChild == 0; loop; endif
      nType := UI_GetType( hChild )
      cText := UI_GetProp( hChild, "cText" )
      if cText == nil; cText := ""; endif

      if n > 1; cJ += ","; endif
      cJ += '{"t":' + LTrim(Str(nType))
      cJ += ',"x":' + LTrim(Str(UI_GetProp(hChild,"nLeft")))
      cJ += ',"y":' + LTrim(Str(UI_GetProp(hChild,"nTop")))
      cJ += ',"w":' + LTrim(Str(UI_GetProp(hChild,"nWidth")))
      cJ += ',"h":' + LTrim(Str(UI_GetProp(hChild,"nHeight")))
      cJ += ',"text":"' + JE(cText) + '"'

      if nType == CT_CHECKBOX
         lChk := UI_GetProp( hChild, "lChecked" )
         cJ += ',"checked":' + If( lChk == .t., "true", "false" )
      endif

      if nType == CT_COMBOBOX
         nItemIdx := UI_GetProp( hChild, "nItemIndex" )
         if nItemIdx == nil; nItemIdx := 0; endif
         nItemCount := UI_ComboGetCount( hChild )
         cJ += ',"sel":' + LTrim(Str(nItemIdx))
         cJ += ',"items":['
         for i := 1 to nItemCount
            if i > 1; cJ += ","; endif
            cJ += '"' + JE( UI_ComboGetItem( hChild, i ) ) + '"'
         next
         cJ += ']'
      endif

      cJ += '}'
   next

   cJ += ']}'

return cJ

// JS escape
static function JE( c )
   if c == nil; return ""; endif
   c := StrTran( c, '\', '\\' )
   c := StrTran( c, '"', '\"' )
return AllTrim( c )

