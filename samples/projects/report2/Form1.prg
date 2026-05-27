// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLblTitle   // TLabel
   DATA oLblCols   // TLabel
   DATA oList   // TListBox
   DATA oLblStatus   // TLabel
   DATA oBtnPrev   // TButton
   DATA oBtnPDF   // TButton

   // Event handlers

   METHOD CreateForm()
   METHOD BtnPrevClick()
   METHOD BtnPDFClick()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Customer Report - HarbourBuilder Sample"
   ::nLeft   := 1222
   ::nTop    := 422
   ::nWidth  := 660
   ::nHeight := 509
   ::nClrPane  := 14605931

   @ 12, 12 SAY ::oLblTitle PROMPT "Customer Database Report" OF Self SIZE 630
   ::oLblTitle:nClrPane := 14062743
   ::oLblTitle:oFont := ".AppleSystemUIFont,12"
   @ 42, 12 SAY ::oLblCols PROMPT "Name                            City                ST" OF Self SIZE 630
   ::oLblCols:oFont := ".AppleSystemUIFont,12"
   @ 64, 12 LISTBOX ::oList OF Self SIZE 630, 340
   ::oList:oFont := "CourierNewPSMT,10"
   @ 412, 12 SAY ::oLblStatus PROMPT "Records: 0" OF Self SIZE 364
   ::oLblStatus:oFont := ".AppleSystemUIFont,12"
   @ 404, 392 BUTTON ::oBtnPrev PROMPT "Preview..." OF Self SIZE 100, 30
   ::oBtnPrev:oFont := ".AppleSystemUIFont,12"
   @ 402, 508 BUTTON ::oBtnPDF PROMPT "Export PDF..." OF Self SIZE 100, 30
   ::oBtnPDF:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oBtnPrev:OnClick := { || ::BtnPrevClick() }
   ::oBtnPDF:OnClick  := { || ::BtnPDFClick() }
   ::OnCreate := { || Form1Create( Self ) }

return nil
//--------------------------------------------------------------------

function Form1Create( oSelf )

   local oDb, aItems, cLine, nCount

   oDb := TDBFTable():New()
   oDb:cFileName := CustomerDbfPath()
   oDb:cRDD      := "DBFCDX"
   oDb:lReadOnly := .T.
   oDb:Open()

   aItems := {}
   nCount := oDb:RecCount()
   oDb:GoTop()

   // FItems buffer holds max 64 rows
   do while ! oDb:Eof() .and. Len( aItems ) < 64
      cLine := PadR( Trim( oDb:FieldGet(1) ) + " " + Trim( oDb:FieldGet(2) ), 30 ) + "  " + ;
               PadR( Trim( oDb:FieldGet(4) ), 18 ) + "  " + ;
               oDb:FieldGet(5)
      AAdd( aItems, cLine )
      oDb:Skip(1)
   enddo

   oDb:Close()

   oSelf:oList:SetItems( aItems )
   oSelf:oLblStatus:cText := "Records: " + hb_NToS( nCount ) + ;
                            "  (showing first " + hb_NToS( Len( aItems ) ) + ")"

return nil
//--------------------------------------------------------------------

METHOD BtnPrevClick() CLASS TForm1
   local oReport := CustomerReport( CustomerDbfPath() )
   oReport:Preview()
return nil
//--------------------------------------------------------------------

METHOD BtnPDFClick() CLASS TForm1
   local cDir, cFile, oReport
   #ifdef __PLATFORM__UNIX
      cDir := "/tmp"
   #else
      cDir := hb_GetEnv( "TEMP" )
      if Empty( cDir ); cDir := hb_GetEnv( "TMP" ); endif
      if Empty( cDir ); cDir := "C:\Temp"; endif
   #endif
   cFile := cDir + hb_ps() + "CustomerReport.pdf"
   oReport := CustomerReport( CustomerDbfPath() )
   oReport:ExportPDF( cFile )
   MsgInfo( "PDF exported to:" + Chr(13) + cFile )
return nil
//--------------------------------------------------------------------

FUNCTION Form1()
   LOCAL oForm := TForm1():New()
   oForm:CreateForm()
   oForm:Activate()
RETURN oForm
//--------------------------------------------------------------------

