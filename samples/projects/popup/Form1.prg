// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oPopup1   // TPopupMenu
   DATA oButton1   // TButton
   DATA oStatus1   // TLabel

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TPopupMenu Sample"
   ::nLeft   := 1042
   ::nTop    := 323
   ::nWidth  := 480
   ::nHeight := 280

   COMPONENT ::oPopup1 TYPE CT_POPUPMENU OF Self  // TPopupMenu
   DEFINE POPUPMENU ::oPopup1
      MENUITEM "Cu&t"   ACTION PopAction( Self, "Cut" )   ACCEL "Ctrl+X"
      MENUITEM "&Copy"  ACTION PopAction( Self, "Copy" )  ACCEL "Ctrl+C"
      MENUITEM "&Paste" ACTION PopAction( Self, "Paste" ) ACCEL "Ctrl+V"
      MENUSEPARATOR
      DEFINE POPUP "&Format"
         MENUITEM "&Bold"      ACTION PopAction( Self, "Format > Bold" )      ACCEL "Ctrl+B"
         MENUITEM "&Italic"    ACTION PopAction( Self, "Format > Italic" )    ACCEL "Ctrl+I"
         MENUITEM "&Underline" ACTION PopAction( Self, "Format > Underline" ) ACCEL "Ctrl+U"
      END POPUP
      MENUSEPARATOR
      MENUITEM "Select &All" ACTION PopAction( Self, "Select All" ) ACCEL "Ctrl+A"
   END POPUPMENU
   @ 96, 60 BUTTON ::oButton1 PROMPT "Show Popup" OF Self SIZE 120, 32
   @ 200, 16 SAY ::oStatus1 PROMPT "Click the button to open the context menu." OF Self SIZE 329

return nil
//--------------------------------------------------------------------

// Popup handlers
//--------------------------------------------------------------------
static function PopAction( oForm, cWhat )
   if oForm:oStatus1 != nil
      oForm:oStatus1:cText := "Picked: " + cWhat
   endif
return nil

