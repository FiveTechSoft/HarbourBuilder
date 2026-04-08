// console/backend.prg - TUI backend using GTWVT (like hbide)
// Uses hb_DispOutAt, hb_DispBox, InKey for text-mode rendering.

#include "hbclass.ch"
#include "hbide.ch"
#include "hbgtinfo.ch"
#include "inkey.ch"
#include "setcurs.ch"
#include "box.ch"

REQUEST HB_GT_WVT_DEFAULT

CLASS ConsoleBackend

   DATA oForm
   DATA nRows    INIT 25
   DATA nCols    INIT 80

   METHOD New()
   METHOD Run( oForm )
   METHOD Render()
   METHOD RenderControl( oCtrl )
   METHOD PixToRow( nPix )  INLINE Max( Int( nPix / 16 ), 0 )
   METHOD PixToCol( nPix )  INLINE Max( Int( nPix / 8 ), 0 )

ENDCLASS

METHOD New() CLASS ConsoleBackend
return Self

METHOD Run( oForm ) CLASS ConsoleBackend

   ::oForm := oForm
   oForm:oBackend := Self

   // Setup GTWVT
   hb_gtInfo( HB_GTI_FONTNAME, "Consolas" )
   hb_gtInfo( HB_GTI_FONTWIDTH, 8 )
   hb_gtInfo( HB_GTI_FONTSIZE, 16 )

   ::nRows := Max( ::PixToRow( oForm:Height ) + 2, 25 )
   ::nCols := Max( ::PixToCol( oForm:Width ) + 2, 80 )

   SetMode( ::nRows, ::nCols )
   SetCursor( SC_NONE )
   Set( _SET_EVENTMASK, INKEY_ALL + HB_INKEY_GTEVENT )

   ::Render()

   // Event loop
   do while InKey( 0, INKEY_ALL + HB_INKEY_GTEVENT ) != K_ESC
   enddo

return nil

METHOD Render() CLASS ConsoleBackend

   local n

   DispBegin()

   // Clear screen
   hb_Scroll()

   // Form border
   hb_DispBox( 0, 0, ::nRows - 1, ::nCols - 1, HB_B_DOUBLE_UNI + " ", "W+/B" )
   hb_DispOutAt( 0, 2, " " + ::oForm:Text + " ", "GR+/B" )

   // Render children
   for n := 1 to Len( ::oForm:aChildren )
      ::RenderControl( ::oForm:aChildren[ n ] )
   next

   // Status bar
   hb_DispOutAt( ::nRows - 1, 2, " ESC=Close ", "N/W" )

   DispEnd()

return nil

METHOD RenderControl( oCtrl ) CLASS ConsoleBackend

   local nRow, nCol, nW, nH, cClass, cText
   local aItems, nIdx, cItem, aLst, i, cMark, cBtn

   cClass := oCtrl:cClass
   cText  := oCtrl:Text
   nRow   := ::PixToRow( oCtrl:Top ) + 1
   nCol   := ::PixToCol( oCtrl:Left ) + 1
   nW     := Max( ::PixToCol( oCtrl:Width ), 4 )
   nH     := Max( ::PixToRow( oCtrl:Height ), 1 )

   if nRow < 1; nRow := 1; endif
   if nCol < 1; nCol := 1; endif
   if nRow >= ::nRows; return nil; endif
   if nCol >= ::nCols; return nil; endif

   do case
      case cClass == CTRL_GROUPBOX
         hb_DispBox( nRow, nCol, nRow + nH, nCol + nW, HB_B_SINGLE_UNI + " ", "W/B" )
         if ! Empty( cText )
            hb_DispOutAt( nRow, nCol + 2, " " + cText + " ", "W+/B" )
         endif

      case cClass == CTRL_LABEL
         hb_DispOutAt( nRow, nCol, PadR( cText, nW ), "W/B" )

      case cClass == CTRL_EDIT
         hb_DispOutAt( nRow, nCol, "[" + PadR( AllTrim( cText ), nW - 2 ) + "]", "W+/BG" )

      case cClass == CTRL_BUTTON
         // hbide-style 3D button with shadow
         cBtn := AllTrim( StrTran( cText, "&", "" ) )
         hb_DispOutAt( nRow, nCol, Chr( 255 ) + " " + cBtn + " " + Chr( 255 ), "N/W" )
         hb_DispOutAt( nRow, nCol + Len( cBtn ) + 4, Chr( 220 ), "N/W" )
         hb_DispOutAt( nRow + 1, nCol + 1, Replicate( Chr( 223 ), Len( cBtn ) + 4 ), "N/W" )

      case cClass == CTRL_CHECKBOX
         cMark := If( oCtrl:GetProp( "Checked" ), "[X]", "[ ]" )
         hb_DispOutAt( nRow, nCol, cMark + " " + cText, "W/B" )

      case cClass == CTRL_COMBOBOX
         aItems := oCtrl:GetProp( "Items" )
         nIdx   := oCtrl:GetProp( "ItemIndex" )
         cItem  := If( nIdx > 0 .and. nIdx <= Len( aItems ), aItems[ nIdx ], "" )
         hb_DispOutAt( nRow, nCol, "[" + PadR( AllTrim( cItem ), nW - 4 ) + " v]", "W+/BG" )

      case cClass == CTRL_LISTBOX
         aLst := oCtrl:GetProp( "Items" )
         hb_DispBox( nRow, nCol, nRow + nH, nCol + nW, HB_B_SINGLE_UNI + " ", "W/B" )
         for i := 1 to Min( Len( aLst ), nH - 1 )
            hb_DispOutAt( nRow + i, nCol + 1, PadR( aLst[ i ], nW - 2 ), "W/B" )
         next

      case cClass == CTRL_RADIOBUTTON
         cMark := If( oCtrl:GetProp( "Checked" ), "(o)", "( )" )
         hb_DispOutAt( nRow, nCol, cMark + " " + cText, "W/B" )

   endcase

return nil
