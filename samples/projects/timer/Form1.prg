// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oTimer1   // TTimer

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Form1"
   ::nLeft   := 100
   ::nTop    := 100
   ::nWidth  := 400
   ::nHeight := 300

   COMPONENT ::oTimer1 TYPE CT_TIMER OF Self  // TTimer

   // Event wiring
   ::oTimer1:OnTimer := { || Timer1Timer( Self ) }

return nil
//--------------------------------------------------------------------

//--------------------------------------------------------------------
static function Timer1Timer( oForm )

   oForm:cTitle := Time()

return nil

