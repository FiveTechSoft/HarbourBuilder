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

   ::Title  := "Form1"
   ::Left   := 932
   ::Top    := 255
   ::Width  := 400
   ::Height := 300

   COMPONENT ::oDBFTable1 TYPE CT_DBFTABLE OF Self  // TControl
   ::oDBFTable1:cFileName := "/Users/anto/HarbourBuilder/data/customer.dbf"
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