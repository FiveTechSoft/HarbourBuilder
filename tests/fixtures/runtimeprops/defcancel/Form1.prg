// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oButton1   // TButton
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

   @ 100, 40 BUTTON ::oButton1 PROMPT "DefaultBtn" OF Self SIZE 140, 32
   ::oButton1:lDefault := .T.
   ::oButton1:OnClick := { || DefClick( Self ) }
   @ 160, 40 SAY ::oLabel1 PROMPT "AnchorLabel" OF Self SIZE 120, 24

return nil
//--------------------------------------------------------------------
//--------------------------------------------------------------------

static function DefClick( oForm )

   hb_MemoWrit( "/tmp/hb-runtimeprops-out/defclick.txt", "fired" )

return nil
