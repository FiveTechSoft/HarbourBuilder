// test_tui.prg - Same C++ core, rendered as TUI
// Controls created in C++, rendered in text mode via GTWVT

#include "hbgtinfo.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "box.ch"

REQUEST HB_GT_WVT_DEFAULT

// Control types (must match C++ CT_* defines)
#define CT_FORM       0
#define CT_LABEL      1
#define CT_EDIT       2
#define CT_BUTTON     3
#define CT_CHECKBOX   4
#define CT_COMBOBOX   5
#define CT_GROUPBOX   6

function Main()

   local hForm

   // Build form using C++ core (same as Win32 version)
   hForm := BuildForm()

   // Render with TUI instead of UI_FormRun
   TuiRender( hForm )

   // Cleanup
   UI_FormDestroy( hForm )

return nil

//----------------------------------------------------------------------------//

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

   UI_EditNew( hForm, "C:\Projects", 112, 73, 312, 24 )

   hCtrl := UI_CheckBoxNew( hForm, "Mostrar barra de herramientas", 112, 210, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   hCtrl := UI_CheckBoxNew( hForm, "Mostrar barra de estado", 112, 234, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   hCtrl := UI_CheckBoxNew( hForm, "Confirmar al salir", 112, 259, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   hCtrl := UI_ButtonNew( hForm, "&Aceptar", 170, 326, 88, 26 )
   UI_SetProp( hCtrl, "lDefault", .t. )

   hCtrl := UI_ButtonNew( hForm, "&Cancelar", 266, 326, 88, 26 )
   UI_SetProp( hCtrl, "lCancel", .t. )

return hForm

//----------------------------------------------------------------------------//
// TUI Renderer - reads C++ objects and draws with hb_DispOutAt
//----------------------------------------------------------------------------//

function TuiRender( hForm )

   local nRows, nCols, n, nCount, hChild, nType
   local nRow, nCol, nW, nH, cText, cBtn, nItemIdx, nItemCount
   local xTop, xLeft, xWidth, xHeight, lChk

   // Setup GTWVT
   hb_gtInfo( HB_GTI_FONTNAME, "Consolas" )
   hb_gtInfo( HB_GTI_FONTWIDTH, 8 )
   hb_gtInfo( HB_GTI_FONTSIZE, 16 )

   nRows := Max( Int( UI_GetProp( hForm, "nHeight" ) / 16 ) + 2, 25 )
   nCols := Max( Int( UI_GetProp( hForm, "nWidth" ) / 8 ) + 2, 80 )

   SetMode( nRows, nCols )
   SetCursor( SC_NONE )

   DispBegin()
   hb_Scroll()

   // Form border
   hb_DispBox( 0, 0, nRows - 1, nCols - 1, HB_B_DOUBLE_UNI + " ", "W+/B" )
   hb_DispOutAt( 0, 2, " " + UI_GetProp( hForm, "cText" ) + " ", "GR+/B" )

   // Render children
   nCount := UI_GetChildCount( hForm )
   MemoWrit( "tui_trace.log", "Children: " + LTrim(Str(nCount)) + Chr(13)+Chr(10) )
   for n := 1 to nCount
      hChild := UI_GetChild( hForm, n )
      if hChild == 0; loop; endif

      nType  := UI_GetType( hChild )
      cText  := UI_GetProp( hChild, "cText" )
      if cText == nil; cText := ""; endif

      xTop := UI_GetProp( hChild, "nTop" )
      xLeft := UI_GetProp( hChild, "nLeft" )
      xWidth := UI_GetProp( hChild, "nWidth" )
      xHeight := UI_GetProp( hChild, "nHeight" )

      MemoWrit( "tui_trace.log", MemoRead("tui_trace.log") + ;
         "n=" + LTrim(Str(n)) + " type=" + LTrim(Str(nType)) + ;
         " text=" + cText + ;
         " top=" + ValType(xTop) + ":" + hb_ValToStr(xTop) + ;
         " left=" + ValType(xLeft) + ":" + hb_ValToStr(xLeft) + ;
         Chr(13)+Chr(10) )

      if ! ValType( xTop ) == "N" .or. ! ValType( xLeft ) == "N"
         loop
      endif

      nRow   := Int( xTop / 16 ) + 1
      nCol   := Int( xLeft / 8 ) + 1
      nW     := Max( Int( xWidth / 8 ), 4 )
      nH     := Max( Int( xHeight / 16 ), 1 )

      if nRow >= nRows .or. nCol >= nCols
         loop
      endif

      do case
         case nType == CT_GROUPBOX
            hb_DispBox( nRow, nCol, nRow + nH, nCol + nW, HB_B_SINGLE_UNI + " ", "W/B" )
            if ! Empty( cText )
               hb_DispOutAt( nRow, nCol + 2, " " + cText + " ", "W+/B" )
            endif

         case nType == CT_LABEL
            hb_DispOutAt( nRow, nCol, PadR( cText, nW ), "W/B" )

         case nType == CT_EDIT
            hb_DispOutAt( nRow, nCol, "[" + PadR( AllTrim( cText ), nW - 2 ) + "]", "W+/BG" )

         case nType == CT_BUTTON
            cBtn := AllTrim( StrTran( cText, "&", "" ) )
            hb_DispOutAt( nRow, nCol, Chr(255) + " " + cBtn + " " + Chr(255), "N/W" )
            hb_DispOutAt( nRow, nCol + Len(cBtn) + 4, Chr(220), "N/W" )
            if nRow + 1 < nRows
               hb_DispOutAt( nRow + 1, nCol + 1, Replicate( Chr(223), Len(cBtn) + 4 ), "N/W" )
            endif

         case nType == CT_CHECKBOX
            lChk := UI_GetProp( hChild, "lChecked" )
            if lChk == nil; lChk := .f.; endif
            hb_DispOutAt( nRow, nCol, ;
               If( lChk, "[X]", "[ ]" ) + " " + cText, "W/B" )

         case nType == CT_COMBOBOX
            nItemIdx   := UI_GetProp( hChild, "nItemIndex" )
            if nItemIdx == nil; nItemIdx := 0; endif
            nItemCount := UI_ComboGetCount( hChild )
            cText := ""
            if nItemIdx >= 0 .and. nItemIdx < nItemCount
               cText := UI_ComboGetItem( hChild, nItemIdx + 1 )
            endif
            hb_DispOutAt( nRow, nCol, "[" + PadR( AllTrim(cText), nW - 4 ) + " v]", "W+/BG" )

      endcase
   next

   // Status bar
   hb_DispOutAt( nRows - 1, 2, " ESC=Close ", "N/W" )

   DispEnd()

   // Wait for ESC
   do while Inkey( 0, INKEY_ALL + HB_INKEY_GTEVENT ) != K_ESC
   enddo

return nil
