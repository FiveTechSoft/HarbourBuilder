// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oEditRO   // TEdit
   DATA oEditOK   // TEdit
   DATA oBtnOff   // TButton
   DATA oBtnOK   // TButton
   DATA oLabelHidden   // TLabel
   DATA oLabelShown   // TLabel

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

   @ 40, 40 GET ::oEditRO VAR "" OF Self SIZE 200, 26
   ::oEditRO:lReadOnly := .T.
   @ 80, 40 GET ::oEditOK VAR "" OF Self SIZE 200, 26
   @ 130, 40 BUTTON ::oBtnOff PROMPT "BtnOff" OF Self SIZE 120, 30
   ::oBtnOff:lEnabled := .F.
   ::oBtnOff:OnClick := { || BtnOffClick( Self ) }
   @ 130, 200 BUTTON ::oBtnOK PROMPT "BtnOK" OF Self SIZE 120, 30
   ::oBtnOK:OnClick := { || BtnOKClick( Self ) }
   @ 180, 40 SAY ::oLabelHidden PROMPT "HIDDEN" OF Self SIZE 120, 24
   ::oLabelHidden:lVisible := .F.
   @ 180, 200 SAY ::oLabelShown PROMPT "SHOWN" OF Self SIZE 120, 24

return nil
//--------------------------------------------------------------------

static function BtnOffClick( oForm )

   hb_MemoWrit( "/tmp/hb-runtimeprops-out/btnoff.txt", "fired" )

return nil

static function BtnOKClick( oForm )

   hb_MemoWrit( "/tmp/hb-runtimeprops-out/btnok.txt", ;
      "RO=[" + oForm:oEditRO:Value + "] OK=[" + oForm:oEditOK:Value + "]" )

return nil
