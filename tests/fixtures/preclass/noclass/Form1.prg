// Form1.prg - FIXTURE preclass: el test borra la linea CLASS en el editor
//--------------------------------------------------------------------

#include "hbbuilder.ch"

// COMENTARIO-PRECLASS-NOCLASS

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oButton1   // TButton
   DATA oSay1      // TLabel

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Fixture PreClass"
   ::nWidth  := 400
   ::nHeight := 300

   @ 20, 20 BUTTON ::oButton1 PROMPT "Boton" OF Self SIZE 100, 26
   @ 60, 20 SAY ::oSay1 PROMPT "Texto" OF Self SIZE 80, 15

RETURN Self
