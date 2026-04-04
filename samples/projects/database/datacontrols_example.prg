// datacontrols_example.prg - Data Controls with TDataSource binding
// Shows TDBFTable + TDataSource + TDBNavigator + TDBEdit working together
//
// This is how a typical database form looks in HarbourBuilder:
// drop a TDBFTable, a TDataSource, a TDBNavigator, and data-aware controls.

#include "hbbuilder.ch"

function Main()

   local oDb, oDS

   ? "=== Data Controls Example ==="
   ?

   // Create test DBF if not exists
   if ! File( "employees.dbf" )
      ? "Creating employees.dbf..."
      dbCreate( "employees.dbf", { ;
         { "ID",     "N",  5, 0 }, ;
         { "NAME",   "C", 30, 0 }, ;
         { "DEPT",   "C", 20, 0 }, ;
         { "SALARY", "N", 10, 2 }, ;
         { "ACTIVE", "L",  1, 0 } } )

      // Populate with sample data
      oDb := TDBFTable():New()
      oDb:cDatabase := "employees.dbf"
      oDb:Open()
      oDb:Append(); oDb:FieldPut(1, 1); oDb:FieldPut(2, "Alice Johnson");  oDb:FieldPut(3, "Engineering"); oDb:FieldPut(4, 85000); oDb:FieldPut(5, .T.)
      oDb:Append(); oDb:FieldPut(1, 2); oDb:FieldPut(2, "Bob Smith");      oDb:FieldPut(3, "Marketing");   oDb:FieldPut(4, 72000); oDb:FieldPut(5, .T.)
      oDb:Append(); oDb:FieldPut(1, 3); oDb:FieldPut(2, "Carol Williams"); oDb:FieldPut(3, "Engineering"); oDb:FieldPut(4, 92000); oDb:FieldPut(5, .T.)
      oDb:Append(); oDb:FieldPut(1, 4); oDb:FieldPut(2, "David Brown");    oDb:FieldPut(3, "Sales");       oDb:FieldPut(4, 65000); oDb:FieldPut(5, .F.)
      oDb:Append(); oDb:FieldPut(1, 5); oDb:FieldPut(2, "Eve Davis");      oDb:FieldPut(3, "Engineering"); oDb:FieldPut(4, 95000); oDb:FieldPut(5, .T.)
      oDb:Close()
      ? "  5 employees created"
   endif

   // === Open database ===
   oDb := TDBFTable():New()
   oDb:cDatabase := "employees.dbf"

   if ! oDb:Open()
      ? "Error: " + oDb:LastError()
      return nil
   endif

   // === Create DataSource (binds DB to controls) ===
   oDS := TDataSource():New( oDb )

   // === Create bound controls ===
   local oName := TDBEdit():New()
   oName:nFieldIndex := 2  // NAME field
   oDS:AddControl( oName )

   local oDept := TDBEdit():New()
   oDept:nFieldIndex := 3  // DEPT field
   oDS:AddControl( oDept )

   local oActive := TDBCheckBox():New()
   oActive:nFieldIndex := 5  // ACTIVE field
   oDS:AddControl( oActive )

   // === Create Navigator ===
   local oNav := TDBNavigator():New( oDS )

   // === Simulate navigation ===
   ? "Record navigation:"
   ?

   oDS:MoveFirst()
   ? "First: " + oName:Text + " | " + oDept:Text

   oDS:MoveNext()
   ? "Next:  " + oName:Text + " | " + oDept:Text

   oDS:MoveNext()
   ? "Next:  " + oName:Text + " | " + oDept:Text

   oDS:MoveLast()
   ? "Last:  " + oName:Text + " | " + oDept:Text

   oDS:MovePrev()
   ? "Prev:  " + oName:Text + " | " + oDept:Text

   ?
   ? "Navigator buttons:"
   oNav:First()
   ? "  First(): " + oName:Text
   oNav:Next()
   ? "  Next():  " + oName:Text
   oNav:Last()
   ? "  Last():  " + oName:Text

   ?
   ? "Total records: " + LTrim(Str(oDb:RecCount()))

   oDb:Close()
   ? "=== Done ==="

return nil
