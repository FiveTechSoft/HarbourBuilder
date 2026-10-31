// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oEdit1   // TEdit

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 100
   ::nTop    := 100
   ::nWidth  := 552
   ::nHeight := 357
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane := 2960685

   @ 100, 40 GET ::oEdit1 VAR "" OF Self SIZE 200, 26
   ::oEdit1:lReadOnly := .T.

return nil
//--------------------------------------------------------------------
