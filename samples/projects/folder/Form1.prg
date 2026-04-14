// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oFolder1   // TFolder
   DATA oButton1   // TButton

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "Form1"
   ::Left   := 1129
   ::Top    := 456
   ::Width  := 650
   ::Height := 421
   ::FontName := "Segoe UI"
   ::FontSize := 9
   ::Color  := 2960685

   @ 48, 144 FOLDER ::oFolder1 OF Self SIZE 355, 194 PROMPTS "Uno", "Dos", "Tres"
   ::oFolder1:oFont := "Segoe UI,12"
   @ 156, 260 BUTTON ::oButton1 PROMPT "Button" OF ::oFolder1:aPages[1] SIZE 105, 32
   ::oButton1:oFont := "Segoe UI,12"

return nil
//--------------------------------------------------------------------
