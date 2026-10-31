// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel

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

   ::nWindowState := 2
   ::nBorderStyle := 3
   ::nFormStyle := 1
   ::lSizable := .T.
   @ 104, 200 SAY ::oLabel1 PROMPT "FormProps" OF Self SIZE 120, 24

return nil
//--------------------------------------------------------------------
