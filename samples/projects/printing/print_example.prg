// print_example.prg - Printing components demo
// Shows TPrinter and TReport with band-based report generation

#include "hbbuilder.ch"

REQUEST DBFCDX, DBFNTX

function Main()

   local oPrn, oRpt, oDb, oDS, i, nRow

   ? "=== Printing Example ==="
   ?

   // --- TPrinter direct usage ---
   ? "1. TPrinter direct printing:"
   oPrn := TPrinter():New()
   oPrn:cPrinterName := "PDF"
   oPrn:nCopies := 1
   ? "   Printer: " + oPrn:cPrinterName
   ? "   Copies: " + LTrim(Str(oPrn:nCopies))
   ? "   Landscape: " + iif( oPrn:lLandscape, "Yes", "No" )

   oPrn:BeginDoc( "Test Document" )
   oPrn:PrintLine( 1, 1, "Header Line" )
   oPrn:PrintLine( 3, 1, "Detail Line 1" )
   oPrn:PrintLine( 4, 1, "Detail Line 2" )
   oPrn:PrintRect( 6, 1, 40, 10 )
   oPrn:NewPage()
   oPrn:PrintLine( 1, 1, "Page 2" )
   oPrn:EndDoc()
   ? "   Document printed (2 pages)"
   ?

   // --- TReport with data ---
   ? "2. TReport band-based report:"

   // Create test data
   if ! File( "products.dbf" )
      dbCreate( "products.dbf", { ;
         { "NAME",  "C", 20, 0 }, ;
         { "PRICE", "N", 10, 2 }, ;
         { "STOCK", "N",  5, 0 } } )
   endif

   oDb := TDBFTable():New()
   oDb:cDatabase := "products.dbf"
   oDb:Open()

   if oDb:RecCount() == 0
      oDb:Append(); oDb:FieldPut(1, "Laptop");   oDb:FieldPut(2, 999.99); oDb:FieldPut(3, 15)
      oDb:Append(); oDb:FieldPut(1, "Mouse");    oDb:FieldPut(2, 29.99);  oDb:FieldPut(3, 200)
      oDb:Append(); oDb:FieldPut(1, "Keyboard"); oDb:FieldPut(2, 79.99);  oDb:FieldPut(3, 85)
      oDb:Append(); oDb:FieldPut(1, "Monitor");  oDb:FieldPut(2, 449.99); oDb:FieldPut(3, 30)
   endif

   oDS := TDataSource():New( oDb )

   // Create report
   oRpt := TReport():New( oPrn )
   oRpt:cTitle := "Product Inventory"
   oRpt:oDataSource := oDS

   oRpt:AddColumn( "Product", "NAME", 20 )
   oRpt:AddColumn( "Price", "PRICE", 12 )
   oRpt:AddColumn( "Stock", "STOCK", 8 )

   nRow := 0
   oRpt:AddBand( "Header", { |p| PrintHeader( p, oRpt, @nRow ) } )
   oRpt:AddBand( "Detail", { |p, db| PrintDetail( p, db, @nRow ) } )
   oRpt:AddBand( "Footer", { |p| PrintFooter( p, nRow ) } )

   ? "   Columns: " + LTrim(Str(Len(oRpt:aColumns)))
   ? "   Bands: " + LTrim(Str(Len(oRpt:aBands)))
   ?
   oRpt:Print()

   oDb:Close()
   ?
   ? "=== Done ==="

return nil

static function PrintHeader( p, oRpt, nRow )
   nRow := 1
   ? "   --- REPORT HEADER: " + oRpt:cTitle + " ---"
return nil

static function PrintDetail( p, db, nRow )
   nRow++
   ? "   " + PadR(AllTrim(db:FieldGet(1)), 20) + ;
     PadR(LTrim(Str(db:FieldGet(2), 10, 2)), 12) + ;
     LTrim(Str(db:FieldGet(3)))
return nil

static function PrintFooter( p, nRow )
   ? "   --- REPORT FOOTER: " + LTrim(Str(nRow-1)) + " records ---"
return nil
