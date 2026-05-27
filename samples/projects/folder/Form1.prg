// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oFolder1   // TFolder
   DATA oButton1   // TButton

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 514
   ::nTop    := 236
   ::nWidth  := 650
   ::nHeight := 421
   ::nClrPane  := 2960685

   @ 48, 144 FOLDER ::oFolder1 OF Self SIZE 355, 194 PROMPTS "Uno", "Dos", "Tres"
   ::oFolder1:oFont := "Segoe UI,12"
   @ 156, 260 BUTTON ::oButton1 PROMPT "Button" OF ::oFolder1:aPages[1] SIZE 105, 32
   ::oButton1:oFont := "Segoe UI,12"

   // Event wiring
   ::oButton1:OnClick := { || Button1Click( Self ) }

return nil
//--------------------------------------------------------------------

//--------------------------------------------------------------------
static function Button1Click( oForm )

   MsgInfo( 'click' )

return nil

