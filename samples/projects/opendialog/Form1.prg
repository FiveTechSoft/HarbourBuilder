// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oOpenDialog1   // TOpenDialog

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 1129
   ::nTop    := 456
   ::nWidth  := 650
   ::nHeight := 421
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane  := 2960685

   COMPONENT ::oOpenDialog1 TYPE CT_OPENDIALOG OF Self  // TOpenDialog

   // Event wiring
   ::OnClick := { || Form1Click( Self ) }

return nil
//--------------------------------------------------------------------

//--------------------------------------------------------------------
static function Form1Click( oForm )

   if oForm:oOpenDialog1:Execute()
	   MsgInfo( oForm:oOpenDialog1:cFileName )
	endif	

return nil

