// Form1.prg
//--------------------------------------------------------------------
CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oDBFTable1   // TControl
   DATA oButton1   // TButton

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 932
   ::nTop    := 255
   ::nWidth  := 400
   ::nHeight := 300

   COMPONENT ::oDBFTable1 TYPE CT_DBFTABLE OF Self  // TControl
   ::oDBFTable1:cFileName := CustomerDbfPath()
   ::oDBFTable1:Open()
   @ 176, 152 BUTTON ::oButton1 PROMPT "Button" OF Self SIZE 112, 37

   // Event wiring
   ::oButton1:OnClick := { || Button1Click( Self ) }

return nil
//--------------------------------------------------------------------

//--------------------------------------------------------------------
static function Button1Click( oForm )

   MsgInfo( Alias() )

return nil
