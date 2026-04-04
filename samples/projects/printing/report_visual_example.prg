// report_visual_example.prg - Visual report using xcommand syntax
#include "hbbuilder.ch"

REQUEST DBFCDX, DBFNTX

function Main()
   local oDb, oDS, oRpt, oBand, oFld

   ? "=== Visual Report Example ==="
   ?

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
      oDb:Append(); oDb:FieldPut(1, "USB Cable"); oDb:FieldPut(2, 9.99);  oDb:FieldPut(3, 500)
   endif

   oDS := TDataSource():New( oDb )

   // === Define report using xcommand syntax ===
   DEFINE REPORT oRpt TITLE "Product Inventory" DATASOURCE oDS

   // Header band
   DEFINE BAND oBand NAME "Header" HEIGHT 45 OF oRpt
   REPORT TEXT oFld PROMPT "PRODUCT INVENTORY" AT 5, 10 SIZE 180, 22 FONT "Sans", 18 BOLD OF oBand
   REPORT TEXT oFld PROMPT "Generated: " + DToC(Date()) AT 30, 10 SIZE 120, 14 FONT "Sans", 9 ITALIC OF oBand

   // Column headers (in a separate band)
   DEFINE BAND oBand NAME "PageHeader" HEIGHT 20 OF oRpt
   REPORT TEXT oFld PROMPT "Product" AT 2, 10 SIZE 80, 14 FONT "Sans", 10 BOLD OF oBand
   REPORT TEXT oFld PROMPT "Price" AT 2, 100 SIZE 50, 14 FONT "Sans", 10 BOLD ALIGN 2 OF oBand
   REPORT TEXT oFld PROMPT "Stock" AT 2, 160 SIZE 40, 14 FONT "Sans", 10 BOLD ALIGN 2 OF oBand

   // Detail band (repeats for each record)
   DEFINE BAND oBand NAME "Detail" HEIGHT 16 OF oRpt
   REPORT DATA oFld FIELD "NAME"  AT 1, 10 SIZE 80, 14 OF oBand
   REPORT DATA oFld FIELD "PRICE" AT 1, 100 SIZE 50, 14 ALIGN 2 OF oBand
   REPORT DATA oFld FIELD "STOCK" AT 1, 160 SIZE 40, 14 ALIGN 2 OF oBand

   // Footer band
   DEFINE BAND oBand NAME "Footer" HEIGHT 25 OF oRpt
   REPORT TEXT oFld PROMPT "--- End of Report ---" AT 5, 60 SIZE 100, 14 ITALIC OF oBand

   // Show report info
   ? "Report: " + oRpt:cTitle
   ? "Bands: " + LTrim(Str(Len(oRpt:aDesignBands)))
   ? "Page: " + LTrim(Str(oRpt:nPageWidth)) + "x" + LTrim(Str(oRpt:nPageHeight)) + " mm"
   ?

   // Generate code
   ? "=== Generated Code ==="
   ? oRpt:GenerateCode( "ProductReport" )

   oDb:Close()
   ? "=== Done ==="
return nil
