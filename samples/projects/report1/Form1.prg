// Form1.prg - Sales Report sample main form
//
// Displays sample sales data in a list and provides buttons to
// preview the report or export it to PDF using the HarbourBuilder
// visual report designer engine (TReport / TReportBand / TReportField).

#include "hbbuilder.ch"

static s_aData := nil   // { cCustomer, cProduct, nQty, nUnitPrice }

//----------------------------------------------------------------------------//
// Form1() — build and activate the main window
//----------------------------------------------------------------------------//

function Form1()

   local oForm, oList, oLblTitle, oLblCols
   local oBtnPrev, oBtnPDF, oLblStatus
   local i, cLine

   BuildSampleData()

   DEFINE FORM oForm TITLE "Sales Report — HarbourBuilder Sample" ;
      SIZE 660, 500 FONT "Segoe UI", 10

   // Report title label
   @ 12, 12 SAY oLblTitle PROMPT "Monthly Sales Report" OF oForm SIZE 630, 22
   oLblTitle:FontSize := 13
   oLblTitle:Bold     := .T.

   // Fixed-font column headers (monospaced for alignment)
   @ 42, 12 SAY oLblCols ;
      PROMPT "Customer              Product              Qty    Unit Price      Total" ;
      OF oForm SIZE 630, 18
   oLblCols:FontName := "Courier New"
   oLblCols:FontSize := 9

   // Listbox — fixed-font rows
   @ 64, 12 LISTBOX oList OF oForm SIZE 630, 340
   oList:FontName := "Courier New"
   oList:FontSize := 9

   for i := 1 to Len( s_aData )
      cLine := FormatLine( s_aData[i] )
      oList:AddItem( cLine )
   next

   // Status / summary label
   @ 412, 12 SAY oLblStatus ;
      PROMPT "Records: " + hb_NToS( Len(s_aData) ) + ;
             "    Grand total: $" + Transform( GrandTotal(), "99,999.99" ) ;
      OF oForm SIZE 400, 18
   oLblStatus:FontSize := 9
   oLblStatus:Bold     := .T.

   // Preview button
   @ 412, 440 BUTTON oBtnPrev PROMPT "Preview..." OF oForm SIZE 100, 30
   oBtnPrev:OnClick := { || DoPreview() }

   // Export PDF button
   @ 450, 440 BUTTON oBtnPDF PROMPT "Export PDF..." OF oForm SIZE 100, 30
   oBtnPDF:OnClick := { || DoExportPDF() }

   ACTIVATE FORM oForm CENTERED

   oForm:Destroy()

return nil

//----------------------------------------------------------------------------//
// BuildSampleData() — populate s_aData with realistic sales records
//----------------------------------------------------------------------------//

static function BuildSampleData()

   s_aData := {}

   // { cCustomer, cProduct, nQty, nUnitPrice }
   AAdd( s_aData, { "Atlas Retail Group",   "Office Desk Pro 120",    4,   349.00 } )
   AAdd( s_aData, { "BlueSky Interiors",    "Ergonomic Chair X5",    12,   189.50 } )
   AAdd( s_aData, { "Coastal Supplies Co.", "LED Panel Light 60W",   30,    42.00 } )
   AAdd( s_aData, { "Delta Systems Ltd",    "Laptop Stand Alu",       8,    59.99 } )
   AAdd( s_aData, { "EastWind Trading",     "Wireless Keyboard K3",  20,    79.00 } )
   AAdd( s_aData, { "Falcon Distributors",  "USB-C Hub 7-Port",      50,    34.90 } )
   AAdd( s_aData, { "Global Parts Inc.",    "Monitor Arm Dual",       6,   119.00 } )
   AAdd( s_aData, { "Horizon Tech",         "Noise-Cancel Headset",  15,   149.00 } )
   AAdd( s_aData, { "Ironclad Supplies",    "Cable Mgmt Tray XL",   100,     9.50 } )
   AAdd( s_aData, { "Jupiter Office",       "Standing Desk Kit",      3,   599.00 } )
   AAdd( s_aData, { "Keystone Business",    "Webcam HD 1080p",       25,    64.00 } )
   AAdd( s_aData, { "Lighthouse Media",     "Presenter Remote Pro",  10,    44.00 } )
   AAdd( s_aData, { "Metro Solutions",      "Docking Station USB-C",  7,   219.00 } )
   AAdd( s_aData, { "Nova Corp",            "4K Display 27in",        2,   489.00 } )
   AAdd( s_aData, { "Omega Industries",     "Filing Cabinet 3-Dr",    5,   159.00 } )

return nil

//----------------------------------------------------------------------------//
// FormatLine( aRec ) — format one record as a fixed-width string
//----------------------------------------------------------------------------//

static function FormatLine( aRec )

   local cCustomer := PadR( aRec[1], 22 )
   local cProduct  := PadR( aRec[2], 22 )
   local cQty      := PadL( hb_NToS( aRec[3] ), 4 )
   local cPrice    := PadL( "$" + Transform( aRec[4], "9,999.99" ), 12 )
   local cTotal    := PadL( "$" + Transform( aRec[3] * aRec[4], "9,999.99" ), 12 )

return cCustomer + " " + cProduct + " " + cQty + cPrice + cTotal

//----------------------------------------------------------------------------//
// GrandTotal() — sum all totals
//----------------------------------------------------------------------------//

static function GrandTotal()

   local i, nGrand := 0
   for i := 1 to Len( s_aData )
      nGrand += s_aData[i][3] * s_aData[i][4]
   next

return nGrand

//----------------------------------------------------------------------------//
// DoPreview() — build report and call Preview()
//----------------------------------------------------------------------------//

static function DoPreview()

   local oRpt := SalesReport( s_aData )
   oRpt:Preview()

return nil

//----------------------------------------------------------------------------//
// DoExportPDF() — build report and export to PDF
//----------------------------------------------------------------------------//

static function DoExportPDF()

   local cFile := "SalesReport_" + StrTran( DToC( Date() ), "/", "" ) + ".pdf"
   local oRpt  := SalesReport( s_aData )
   oRpt:ExportPDF( cFile )
   MsgInfo( "Report exported to " + cFile )

return nil
