// Form1.prg - FIXTURE multiform: form 1 sano
//--------------------------------------------------------------------

#include "hbbuilder.ch"

// COMENTARIO-PRECLASS-F1

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oButton1   // TButton

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Fixture PreClass F1"
   ::nWidth  := 400
   ::nHeight := 300

   @ 20, 20 BUTTON ::oButton1 PROMPT "Boton1" OF Self SIZE 100, 26

RETURN Self
