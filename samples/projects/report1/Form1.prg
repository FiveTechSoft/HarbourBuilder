// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLblTitle   // TLabel
   DATA oLblCols   // TLabel
   DATA oList   // TListBox
   DATA oLblStatus   // TLabel
   DATA oBtnPrev   // TButton
   DATA oBtnPDF   // TButton

   // Event handlers
   METHOD BtnPrevClick()
   METHOD BtnPDFClick()

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "Sales Report - HarbourBuilder Sample"
   ::Left   := 1222
   ::Top    := 422
   ::Width  := 660
   ::Height := 509
   ::FontName := "Segoe UI"
   ::FontSize := 9
   ::Color  := 14605931

   @ 12, 12 SAY ::oLblTitle PROMPT "Monthly Sales Report" OF Self SIZE 630, 24
   ::oLblTitle:nClrPane := 14062743
   ::oLblTitle:oFont := "Segoe UI,12"
   @ 42, 12 SAY ::oLblCols PROMPT "Customer              Product              Qty    Unit Price      Total" OF Self SIZE 630, 24
   ::oLblCols:oFont := "Segoe UI,12"
   ::oLblCols:lTransparent := .T.
   @ 64, 12 LISTBOX ::oList OF Self SIZE 630, 340
   ::oList:oFont := "Segoe UI,12"
   @ 412, 12 SAY ::oLblStatus PROMPT "Records: 15" OF Self SIZE 364, 24
   ::oLblStatus:oFont := "Segoe UI,12"
   ::oLblStatus:lTransparent := .T.
   @ 404, 392 BUTTON ::oBtnPrev PROMPT "Preview..." OF Self SIZE 100, 30
   ::oBtnPrev:oFont := "Segoe UI,12"
   @ 402, 508 BUTTON ::oBtnPDF PROMPT "Export PDF..." OF Self SIZE 100, 30
   ::oBtnPDF:oFont := "Segoe UI,12"

   // Event wiring
   ::oBtnPrev:OnClick := { || ::BtnPrevClick() }
   ::oBtnPDF:OnClick  := { || ::BtnPDFClick() }

return nil
//--------------------------------------------------------------------

function Form1Create( oSelf )

   local aData, aItems, i, cLine

   aData  := SampleData()
   aItems := {}
   for i := 1 to Len( aData )
      cLine := PadR( aData[i][1], 20 ) + "  " + PadR( aData[i][2], 16 ) + "  " + ;
               Str( aData[i][3], 4 ) + "  " + ;
               Transform( aData[i][4], "9,999.99" ) + "  " + ;
               Transform( aData[i][3] * aData[i][4], "9,999.99" )
      AAdd( aItems, cLine )
   next
   oSelf:oList:SetItems( aItems )
   oSelf:oLblStatus:Text := "Records: " + hb_NToS( Len( aData ) )

return nil
//--------------------------------------------------------------------

METHOD BtnPrevClick() CLASS TForm1
   local oReport := SalesReport( SampleData() )
   oReport:Preview()
return nil
//--------------------------------------------------------------------

METHOD BtnPDFClick() CLASS TForm1
   local cDir, cFile, oReport
   cDir  := hb_GetEnv( "TEMP" )
   if Empty( cDir ); cDir := hb_GetEnv( "TMP" ); endif
   if Empty( cDir ); cDir := "C:\Temp"; endif
   cFile := cDir + "\SalesReport.pdf"
   oReport := SalesReport( SampleData() )
   oReport:ExportPDF( cFile )
   MsgInfo( "PDF exported to:" + Chr(13) + cFile )
return nil
//--------------------------------------------------------------------

static function SampleData()
return { ;
   { "Acme Corp",      "Widget A",   10,  49.99 }, ;
   { "Globex",         "Gadget B",    5, 129.00 }, ;
   { "Initech",        "Doohickey",  20,  14.50 }, ;
   { "Umbrella Ltd",   "Widget A",    3,  49.99 }, ;
   { "Soylent Inc",    "Gizmo Pro",   8,  89.95 }, ;
   { "Acme Corp",      "Gadget B",    2, 129.00 }, ;
   { "Globex",         "Doohickey",  15,  14.50 }, ;
   { "Initech",        "Gizmo Pro",   4,  89.95 }, ;
   { "Umbrella Ltd",   "Widget A",    6,  49.99 }, ;
   { "Soylent Inc",    "Gadget B",    1, 129.00 }, ;
   { "Acme Corp",      "Doohickey",  12,  14.50 }, ;
   { "Globex",         "Gizmo Pro",   7,  89.95 }, ;
   { "Initech",        "Widget A",    9,  49.99 }, ;
   { "Umbrella Ltd",   "Gadget B",    3, 129.00 }, ;
   { "Soylent Inc",    "Doohickey",  25,  14.50 }  }

FUNCTION Form1()
   LOCAL oForm := TForm1():New()
   oForm:CreateForm()
   oForm:Activate()
RETURN oForm
//--------------------------------------------------------------------

----
