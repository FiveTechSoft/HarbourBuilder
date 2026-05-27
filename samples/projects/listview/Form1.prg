// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLblInfo   // TLabel
   DATA oLV1   // TListView
   DATA oBtnAdd   // TButton
   DATA oBtnClear   // TButton

   // Event handlers
   METHOD BtnAddClick()
   METHOD BtnClearClick()

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TListView Sample"
   ::nLeft   := 1430
   ::nTop    := 445
   ::nWidth  := 540
   ::nHeight := 420
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane  := 2960685

   @ 20, 20 SAY ::oLblInfo PROMPT "Employees:" OF Self SIZE 200, 24
   ::oLblInfo:oFont := "Segoe UI,12"
   ::oLblInfo:lTransparent := .T.
   @ 50, 20 LISTVIEW ::oLV1 OF Self SIZE 480, 250 COLUMNS "Name", "Age", "City" ITEMS "Alice;30;New York", "Bob;25;Los Angeles", "Charlie;40;Chicago" IMAGES "C:\fwteam\icons\bitmap.ico"
   ::oLV1:oFont := "Segoe UI,12"
   @ 320, 20 BUTTON ::oBtnAdd PROMPT "&Add row" OF Self SIZE 120, 30
   ::oBtnAdd:oFont := "Segoe UI,12"
   @ 320, 160 BUTTON ::oBtnClear PROMPT "&Clear" OF Self SIZE 120, 30
   ::oBtnClear:oFont := "Segoe UI,12"

   // Event wiring
   ::oBtnAdd:OnClick := { || ::BtnAddClick() }
   ::oBtnClear:OnClick := { || ::BtnClearClick() }

return nil
//--------------------------------------------------------------------

METHOD BtnAddClick() CLASS TForm1
   local n := Len( ::oLV1:aItems ) + 1
   ::oLV1:AddItem( { "Person" + LTrim(Str(n)),;
                     LTrim(Str(20 + n)),;
                     "City" + LTrim(Str(n)) } )
return nil

METHOD BtnClearClick() CLASS TForm1
   ::oLV1:SetItems( {} )
return nil
//--------------------------------------------------------------------
