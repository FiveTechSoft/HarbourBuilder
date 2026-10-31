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
   ::nLeft   := 688
   ::nTop    := 261
   ::nWidth  := 552
   ::nHeight := 357
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane := 2960685

   @ 104, 200 SAY ::oLabel1 PROMPT "EvFix" OF Self SIZE 80, 24
   ::oLabel1:oFont := "Segoe UI,9"
   ::oLabel1:lTransparent := .T.
   ::oLabel1:OnClick := { || Label1Click( Self ) }

return nil
//--------------------------------------------------------------------

static function Label1Click( oForm )

   

return nil
