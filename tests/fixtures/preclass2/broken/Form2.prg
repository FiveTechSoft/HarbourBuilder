// Form2.prg - FIXTURE multiform: form 2 sano
//--------------------------------------------------------------------

#include "hbbuilder.ch"

// COMENTARIO-PRECLASS-F2-SINCLASE



   // IDE-managed Components
   DATA oButton2   // TButton

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm2

   ::cTitle  := "Fixture PreClass F2"
   ::nWidth  := 400
   ::nHeight := 300

   @ 20, 20 BUTTON ::oButton2 PROMPT "Boton2" OF Self SIZE 100, 26

RETURN Self
