// Form1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oDBFTable1   // TDbfTable
   DATA oDBGrid1   // TDBGrid

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 970
   ::nTop    := 281
   ::nWidth  := 400
   ::nHeight := 300

   COMPONENT ::oDBFTable1 TYPE CT_DBFTABLE OF Self  // TDbfTable @ 24,236
   ::oDBFTable1:cFileName := CustomerDbfPath()
   ::oDBFTable1:Open()
   @ 24, 32 DBGRID ::oDBGrid1 OF Self SIZE 330, 175
   ::oDBGrid1:oDataSource := "DBFTable1"
   ::oDBGrid1:oFont := ".AppleSystemUIFont,12"

return nil
//--------------------------------------------------------------------

