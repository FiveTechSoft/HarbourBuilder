// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel
   DATA oEdit1   // TEdit
   DATA oButton1   // TButton
   DATA oListBox1   // TListBox

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "Okno główne aplikacji test1"
   ::Left   := 1011
   ::Top    := 260
   ::Width  := 709
   ::Height := 436
   ::Color  := 16776563

   @ 24, 328 SAY ::oLabel1 PROMPT "To moja aplikacja testowa" OF Self SIZE 320
   ::oLabel1:nClrPane := 9640787
   ::oLabel1:nClrText := 14191103
   ::oLabel1:lTransparent := .F.
   ::oLabel1:nAlign := 1
   ::oLabel1:oFont := "SnellRoundhand-Bold,24,FF89D8"
   @ 296, 224 GET ::oEdit1 VAR "" OF Self SIZE 360, 40
   ::oEdit1:oFont := "SnellRoundhand-Bold,12"
   @ 352, 304 BUTTON ::oButton1 PROMPT "Wyświetl zawartość i zapisz" OF Self SIZE 200, 32
   ::oButton1:oFont := "SnellRoundhand-Bold,12"
   @ 80, 24 LISTBOX ::oListBox1 OF Self SIZE 96, 144 ITEMS "pierwsza", "druga", "trzecia", "czwarta", "piąta", "szósta", "siódma"
   ::oListBox1:nClrText := 15395562
   ::oListBox1:oFont := "Skia-Regular,24,EAEAEA"

   // Event wiring
   ::oLabel1:OnClick := { || Label1Click( Self ) }
   ::oButton1:OnClick := { || Button1Click( Self ) }
   ::oListBox1:OnChange := { || ListBox1Change( Self ) }

return nil
//--------------------------------------------------------------------

//--------------------------------------------------------------------
static function Label1Click( oForm )

   MsgInfo("Działa wszystko jak szalone ")

return nil
//--------------------------------------------------------------------
static function Button1Click( oForm )

	//W32_MsgBox(::PoleTekstowe:Text)
   msginfo( oForm:oEdit1:Text)
	hb_memowrit("/users/marekolszewski/projekty/test1/test1.txt", oForm:oEdit1:Text)

return nil

/*
#pragma BEGINDUMP
#include <hbapi.h>
#include "windows.h"
HB_FUNC( W32_MSGBOX )
{
   MessageBoxA( NULL, hb_parc(1), hb_parc(2), MB_OK );
}
#pragma ENDDUMP
*///--------------------------------------------------------------------
//--------------------------------------------------------------------
static function ListBox1Change( oForm )

   

return nil
