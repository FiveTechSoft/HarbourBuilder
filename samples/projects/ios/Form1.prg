// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel
   DATA oEdit1   // TEdit
   DATA oButton1   // TButton

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "Hello iOS"
   ::Left   := 1056
   ::Top    := 260
   ::Width  := 400
   ::Height := 600
   ::Color  := 10679296

   @ 20, 20 SAY ::oLabel1 PROMPT "Type your name:" OF Self SIZE 300
   ::oLabel1:oFont := ".AppleSystemUIFont,12"
   @ 76, 76 GET ::oEdit1 VAR "" OF Self SIZE 300, 50
   ::oEdit1:oFont := ".AppleSystemUIFont,12"
   @ 284, 74 BUTTON ::oButton1 PROMPT "Greet" OF Self SIZE 300, 50
   ::oButton1:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oButton1:OnClick := { || Button1Click( Self ) }

return nil
//--------------------------------------------------------------------

static function Button1Click( oForm )

   oForm:oLabel1:Text := "Hello, " + oForm:oEdit1:Text + " !"

return nil

//--------------------------------------------------------------------
