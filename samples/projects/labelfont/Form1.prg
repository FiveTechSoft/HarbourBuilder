// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 1122
   ::nTop    := 377
   ::nWidth  := 603
   ::nHeight := 441
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane  := 2960685

   @ 112, 152 SAY ::oLabel1 PROMPT "Hello" OF Self SIZE 240, 104
   ::oLabel1:oFont := "Georgia,60,00FF2E"

return nil
//--------------------------------------------------------------------

