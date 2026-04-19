// FormReport.prg
//------------------------------------------------------------------------

CLASS TFormReport FROM TForm

   // IDE-managed Components
   DATA oBandHeader      // TBand
   DATA oBandPageHeader  // TBand
   DATA oBandDetail      // TBand
   DATA oBandFooter      // TBand
   DATA oBandPageFooter  // TBand

   METHOD CreateForm()

ENDCLASS
//------------------------------------------------------------------------

METHOD CreateForm() CLASS TFormReport

   ::Title    := "Sales Report - Acme Corp."
   ::Left     := 100
   ::Top      := 80
   ::Width    := 870
   ::Height   := 720
   ::FontName := "Segoe UI"
   ::FontSize := 9

   // -- Header Band --
   @ 0, 20 BAND ::oBandHeader OF Self SIZE 810, 80 TYPE "Header"
   REPORTFIELD ::oHdrCompany TYPE "label" PROMPT "Acme Corporation" OF ::oBandHeader AT 5,0 SIZE 810,24 FONT "Segoe UI",14 BOLD
   REPORTFIELD ::oHdrTitle TYPE "label" PROMPT "Monthly Sales Report" OF ::oBandHeader AT 34,0 SIZE 810,18 FONT "Segoe UI",11 ALIGN 1
   REPORTFIELD ::oHdrDate TYPE "label" PROMPT "Report Date" OF ::oBandHeader AT 34,540 SIZE 270,18 FONT "Segoe UI",9 ITALIC ALIGN 2

   // -- PageHeader Band --
   @ 80, 20 BAND ::oBandPageHeader OF Self SIZE 810, 45 TYPE "PageHeader"
   REPORTFIELD ::oPHCustomer TYPE "label" PROMPT "Customer" OF ::oBandPageHeader AT 14,0 SIZE 210,18 FONT "Segoe UI",9 BOLD
   REPORTFIELD ::oPHProduct TYPE "label" PROMPT "Product" OF ::oBandPageHeader AT 14,215 SIZE 185,18 FONT "Segoe UI",9 BOLD
   REPORTFIELD ::oPHQty TYPE "label" PROMPT "Qty" OF ::oBandPageHeader AT 14,405 SIZE 55,18 FONT "Segoe UI",9 BOLD ALIGN 2
   REPORTFIELD ::oPHPrice TYPE "label" PROMPT "Unit Price" OF ::oBandPageHeader AT 14,465 SIZE 120,18 FONT "Segoe UI",9 BOLD ALIGN 2
   REPORTFIELD ::oPHTotal TYPE "label" PROMPT "Total" OF ::oBandPageHeader AT 14,590 SIZE 220,18 FONT "Segoe UI",9 BOLD ALIGN 2

   // -- Detail Band --
   @ 125, 20 BAND ::oBandDetail OF Self SIZE 810, 35
   REPORTFIELD ::oDtlCustomer TYPE "data" FIELD "CUSTOMER" OF ::oBandDetail AT 8,0 SIZE 210,18 FONT "Segoe UI",9
   REPORTFIELD ::oDtlProduct TYPE "data" FIELD "PRODUCT" OF ::oBandDetail AT 8,215 SIZE 185,18 FONT "Segoe UI",9
   REPORTFIELD ::oDtlQty TYPE "data" FIELD "QTY" OF ::oBandDetail AT 8,405 SIZE 55,18 FONT "Segoe UI",9 ALIGN 2
   REPORTFIELD ::oDtlPrice TYPE "data" FIELD "UNITPRICE" OF ::oBandDetail AT 8,465 SIZE 120,18 FONT "Segoe UI",9 ALIGN 2
   REPORTFIELD ::oDtlTotal TYPE "data" FIELD "LINETOTAL" OF ::oBandDetail AT 8,590 SIZE 220,18 FONT "Segoe UI",9 ALIGN 2

   // -- Footer Band (Grand Total) --
   @ 160, 20 BAND ::oBandFooter OF Self SIZE 810, 55 TYPE "Footer"
   REPORTFIELD ::oFtrLabel TYPE "label" PROMPT "Grand Total:" OF ::oBandFooter AT 18,465 SIZE 120,18 FONT "Segoe UI",9 BOLD ALIGN 2
   REPORTFIELD ::oFtrTotal TYPE "data" FIELD "GRANDTOTAL" OF ::oBandFooter AT 18,590 SIZE 220,18 FONT "Segoe UI",9 BOLD ALIGN 2

   // -- PageFooter Band --
   @ 215, 20 BAND ::oBandPageFooter OF Self SIZE 810, 40 TYPE "PageFooter"
   REPORTFIELD ::oPFInfo TYPE "label" PROMPT "Acme Corporation - Confidential" OF ::oBandPageFooter AT 12,0 SIZE 380,16 FONT "Segoe UI",8 ITALIC
   REPORTFIELD ::oPFPage TYPE "label" PROMPT "Page 1" OF ::oBandPageFooter AT 12,430 SIZE 380,16 FONT "Segoe UI",8 ALIGN 2

return nil
//------------------------------------------------------------------------
