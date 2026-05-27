// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oSQLite1   // TSQLite
   DATA oDBGrid1   // TDBGrid

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 574
   ::nTop    := 222
   ::nWidth  := 1172
   ::nHeight := 687

   COMPONENT ::oSQLite1 TYPE CT_SQLITE OF Self  // TSQLite @ 16,220
   ::oSQLite1:cFileName := "/Users/usuario/HarbourBuilder/data/NatalData"
   ::oSQLite1:Open()
   @ 0, 0 DBGRID ::oDBGrid1 OF Self SIZE 1172, 687
   ::oDBGrid1:oDataSource := "SQLite1"
   ::oDBGrid1:nAlign := 5
   ::oDBGrid1:nControlAlign := 5
   ::oDBGrid1:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oSQLite1:cTable    := "Natal"

   // Load datasource grids after all components are created
   ::oDBGrid1:LoadFromDataSource( Self )

return nil
//--------------------------------------------------------------------
