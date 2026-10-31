// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oEdit1   // TEdit
   DATA oBtnRead   // TButton
   DATA oBtnSet   // TButton

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

   @ 40, 40 GET ::oEdit1 VAR "" OF Self SIZE 200, 26
   @ 90, 40 BUTTON ::oBtnRead PROMPT "ReadVal" OF Self SIZE 120, 30
   ::oBtnRead:OnClick := { || BtnReadClick( Self ) }
   @ 90, 200 BUTTON ::oBtnSet PROMPT "SetVal" OF Self SIZE 120, 30
   ::oBtnSet:OnClick := { || BtnSetClick( Self ) }

return nil
//--------------------------------------------------------------------

static function BtnReadClick( oForm )

   hb_MemoWrit( "@OUTDIR@/read.txt", "VALUE=[" + oForm:oEdit1:Value + "]" )

return nil

static function BtnSetClick( oForm )

   oForm:oEdit1:Value := "SETVALUE"
   hb_MemoWrit( "@OUTDIR@/set.txt", "AFTERSET=[" + oForm:oEdit1:Value + "]" )

return nil
