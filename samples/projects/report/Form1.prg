// Form1.prg — Product Inventory Report Designer Demo
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oPrinter1           // TPrinter
   DATA oReport1            // TReport

   // Bands
   DATA oBand1              // Header
   DATA oBand2              // PageHeader
   DATA oBand3              // Detail
   DATA oBand4              // PageFooter
   DATA oBand5              // Footer

   // Header fields
   DATA oFldTitle           // title label
   DATA oFldDate            // date label

   // PageHeader fields
   DATA oFldSep1            // separator line
   DATA oFldHdrName         // "Name" column header
   DATA oFldHdrPrice        // "Price" column header
   DATA oFldHdrStock        // "Stock" column header

   // Detail fields
   DATA oFldName            // NAME data field
   DATA oFldPrice           // PRICE data field
   DATA oFldStock           // STOCK data field

   // PageFooter fields
   DATA oFldPageNo          // page number label

   // Footer fields
   DATA oFldSep2            // separator line
   DATA oFldEnd             // "End of Report" label

   // Buttons and log
   DATA oBtnPrint           // TButton
   DATA oBtnSetup           // TButton
   DATA oLog                // TMemo

   METHOD CreateForm()
   METHOD OnStartClick()
   METHOD OnSetupClick()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "Report Designer Demo"
   ::Left   := 100
   ::Top    := 100
   ::Width  := 640
   ::Height := 580

   COMPONENT ::oPrinter1 TYPE CT_PRINTER OF Self
   COMPONENT ::oReport1  TYPE CT_REPORT  OF Self

   // Bands — @ row,col syntax (matches IDE code generator)
   @ 0,   0 BAND ::oBand1 OF Self SIZE 620, 40 TYPE "Header"
   @ 40,  0 BAND ::oBand2 OF Self SIZE 620, 24 TYPE "PageHeader"
   @ 64,  0 BAND ::oBand3 OF Self SIZE 620, 18 TYPE "Detail"
   @ 82,  0 BAND ::oBand4 OF Self SIZE 620, 20 TYPE "PageFooter"
   @ 102, 0 BAND ::oBand5 OF Self SIZE 620, 30 TYPE "Footer"

   // Header: title and date
   REPORTFIELD ::oFldTitle TYPE "label" PROMPT "Product Inventory" ;
      OF ::oBand1 AT 12, 10 SIZE 300, 16 FONT ".AppleSystemUIFont", 14 BOLD

   REPORTFIELD ::oFldDate TYPE "label" PROMPT "Date Report" ;
      OF ::oBand1 AT 12, 480 SIZE 130, 16 FONT ".AppleSystemUIFont", 11

   // PageHeader: separator line and column labels
   REPORTFIELD ::oFldSep1 TYPE "line" ;
      OF ::oBand2 AT 22, 0 SIZE 620, 1

   REPORTFIELD ::oFldHdrName TYPE "label" PROMPT "Name" ;
      OF ::oBand2 AT 4, 10 SIZE 200, 14 BOLD

   REPORTFIELD ::oFldHdrPrice TYPE "label" PROMPT "Price" ;
      OF ::oBand2 AT 4, 220 SIZE 80, 14 BOLD

   REPORTFIELD ::oFldHdrStock TYPE "label" PROMPT "Stock" ;
      OF ::oBand2 AT 4, 310 SIZE 60, 14 BOLD

   // Detail: data-bound fields
   REPORTFIELD ::oFldName TYPE "data" FIELD "NAME" ;
      OF ::oBand3 AT 2, 10 SIZE 200, 14

   REPORTFIELD ::oFldPrice TYPE "data" FIELD "PRICE" FORMAT "999,999.99" ;
      OF ::oBand3 AT 2, 220 SIZE 80, 14

   REPORTFIELD ::oFldStock TYPE "data" FIELD "STOCK" ;
      OF ::oBand3 AT 2, 310 SIZE 60, 14

   // PageFooter: page number
   REPORTFIELD ::oFldPageNo TYPE "label" PROMPT "Page 1" ;
      OF ::oBand4 AT 4, 280 SIZE 60, 14

   // Footer: separator and end label
   REPORTFIELD ::oFldSep2 TYPE "line" ;
      OF ::oBand5 AT 4, 0 SIZE 620, 1

   REPORTFIELD ::oFldEnd TYPE "label" PROMPT "End of Report" ;
      OF ::oBand5 AT 10, 220 SIZE 200, 16 BOLD

   // Buttons and log
   @ 480, 10  BUTTON ::oBtnPrint OF Self PROMPT "Print"         SIZE 100, 30
   @ 480, 120 BUTTON ::oBtnSetup OF Self PROMPT "Printer Setup" SIZE 120, 30
   @ 520, 10  MEMO   ::oLog      OF Self SIZE 610, 50

   ::oLog:Text := "Press Print to send to printer, or Printer Setup to configure." + Chr(13) + Chr(10)

   // Wiring
   ::oReport1:oPrinter := ::oPrinter1
   ::oReport1:cTitle   := "Product Inventory"
   ::oBtnPrint:OnClick := { || ::OnStartClick() }
   ::oBtnSetup:OnClick := { || ::OnSetupClick() }

return nil
//--------------------------------------------------------------------

METHOD OnStartClick() CLASS TForm1
   // Wire bands to report and print
   ::oReport1:aDesignBands := { ::oBand1, ::oBand2, ::oBand3, ::oBand4, ::oBand5 }
   ::oReport1:nPageWidth   := 210
   ::oReport1:nPageHeight  := 297
   ::oReport1:nMarginLeft  := 15
   ::oReport1:nMarginRight := 15
   ::oReport1:nMarginTop   := 15
   ::oReport1:nMarginBottom := 15
   ::oReport1:Print()
   ::oLog:Text += "Printed." + Chr(13) + Chr(10)
return nil
//--------------------------------------------------------------------

METHOD OnSetupClick() CLASS TForm1
   ::oPrinter1:ShowPrintPanel()
return nil
//--------------------------------------------------------------------
