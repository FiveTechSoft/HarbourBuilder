// Form1.prg - FIXTURE handedit parser: COMPONENT case/tab + menu END trailing comments
//--------------------------------------------------------------------

#include "hbbuilder.ch"

// COMENTARIO-CABECERA-HANDEDIT: linea manuscrita pre-CLASS que debe preservarse

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oButton1   // TButton
   DATA oSay1      // TLabel
   DATA oTimer1    // TTimer
   DATA oTimer2    // TTimer
   DATA oMainMenu1 // TMainMenu

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Fixture HandEdit"
   ::nWidth  := 400
   ::nHeight := 300

   COMPONENT ::OTimer1 TYPE CT_TIMER OF Self
   COMPONENT ::oTimer2	TYPE CT_TIMER OF Self

   COMPONENT ::oMainMenu1 TYPE CT_MAINMENU OF Self  // TMainMenu
   DEFINE MENUBAR ::oMainMenu1
      DEFINE POPUP "Archivo"
         MENUITEM "Abrir" ACTION AbrirClicked()
      END POPUP // trailing comment on END POPUP
   END MENUBAR // trailing comment on END MENUBAR

   @ 20, 20 BUTTON ::oButton1 PROMPT "Boton" OF Self SIZE 100, 26
   @ 60, 20 SAY ::oSay1 PROMPT "Texto" OF Self SIZE 80, 15

RETURN Self
