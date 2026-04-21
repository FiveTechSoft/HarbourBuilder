// Form2.prg
//--------------------------------------------------------------------

CLASS TForm2 FROM TForm

   // IDE-managed Components
   DATA oBandHeader   // TBand
   DATA oBandPageHeader   // TBand
   DATA oBandDetail   // TBand
   DATA oBandFooter   // TBand
   DATA oBandPageFooter   // TBand

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm2

   ::Title  := "Sales Report - Acme Corp."
   ::Left   := 1205
   ::Top    := 258
   ::Width  := 870
   ::Height := 720
   ::FontName := "Segoe UI"
   ::FontSize := 9
   ::Color  := 2960685

   @ 20, 20 BAND ::oBandHeader OF Self SIZE 832, 80 TYPE "Header"
   REPORTFIELD ::oHdrCompany TYPE "label" PROMPT "Acme Corporation" OF ::oBandHeader AT 5,0 SIZE 810,24
   REPORTFIELD ::oHdrTitle TYPE "label" PROMPT "Monthly Sales Report" OF ::oBandHeader AT 34,0 SIZE 810,18
   REPORTFIELD ::oHdrDate TYPE "label" PROMPT "Report Date" OF ::oBandHeader AT 34,540 SIZE 270,18
   ::oBandHeader:oFont := "Segoe UI,12"
   @ 100, 20 BAND ::oBandPageHeader OF Self SIZE 832, 45 TYPE "PageHeader"
   REPORTFIELD ::oPHCustomer TYPE "label" PROMPT "Customer" OF ::oBandPageHeader AT 14,0 SIZE 210,18
   REPORTFIELD ::oPHProduct TYPE "label" PROMPT "Product" OF ::oBandPageHeader AT 14,215 SIZE 185,18
   REPORTFIELD ::oPHQty TYPE "label" PROMPT "Qty" OF ::oBandPageHeader AT 14,405 SIZE 55,18
   REPORTFIELD ::oPHPrice TYPE "label" PROMPT "Unit Price" OF ::oBandPageHeader AT 14,465 SIZE 120,18
   REPORTFIELD ::oPHTotal TYPE "label" PROMPT "Total" OF ::oBandPageHeader AT 14,590 SIZE 220,18
   ::oBandPageHeader:oFont := "Segoe UI,12"
   @ 145, 20 BAND ::oBandDetail OF Self SIZE 832, 35
   REPORTFIELD ::oDtlCustomer TYPE "label" OF ::oBandDetail AT 8,0 SIZE 210,18
   REPORTFIELD ::oDtlProduct TYPE "label" OF ::oBandDetail AT 8,215 SIZE 185,18
   REPORTFIELD ::oDtlQty TYPE "label" OF ::oBandDetail AT 8,405 SIZE 55,18
   REPORTFIELD ::oDtlPrice TYPE "label" OF ::oBandDetail AT 8,465 SIZE 120,18
   REPORTFIELD ::oDtlTotal TYPE "label" OF ::oBandDetail AT 8,590 SIZE 220,18
   ::oBandDetail:oFont := "Segoe UI,12"
   @ 220, 20 BAND ::oBandFooter OF Self SIZE 832, 55 TYPE "Footer"
   REPORTFIELD ::oFtrLabel TYPE "label" PROMPT "Grand Total:" OF ::oBandFooter AT 18,465 SIZE 120,18
   REPORTFIELD ::oFtrTotal TYPE "label" OF ::oBandFooter AT 18,590 SIZE 220,18
   ::oBandFooter:oFont := "Segoe UI,12"
   @ 180, 20 BAND ::oBandPageFooter OF Self SIZE 832, 40 TYPE "PageFooter"
   REPORTFIELD ::oPFInfo TYPE "label" PROMPT "Acme Corporation - Confidential" OF ::oBandPageFooter AT 12,0 SIZE 380,16
   REPORTFIELD ::oPFPage TYPE "label" PROMPT "Page 1" OF ::oBandPageFooter AT 12,430 SIZE 380,16
   ::oBandPageFooter:oFont := "Segoe UI,12"

return nil
//--------------------------------------------------------------------

----
