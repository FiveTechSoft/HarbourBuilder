// Form2.prg
//--------------------------------------------------------------------

CLASS TForm2 FROM TForm

   // IDE-managed Components
   DATA oLabel2   // TLabel

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm2

   ::cTitle  := "Form2"
   ::nLeft   := 761
   ::nTop    := 341
   ::nWidth  := 552
   ::nHeight := 357
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane := 2960685

   @ 104, 200 SAY ::oLabel2 PROMPT "HolaF2b" OF Self SIZE 80, 24
   ::oLabel2:oFont := "Segoe UI,12"
   ::oLabel2:lTransparent := .T.

return nil
//--------------------------------------------------------------------
