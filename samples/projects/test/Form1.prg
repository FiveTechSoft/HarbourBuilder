// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel
   DATA oEdit1   // TEdit
   DATA oButton1   // TButton

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Okno główne aplikacji test1"
   ::nLeft   := 884
   ::nTop    := 244
   ::nWidth  := 587
   ::nHeight := 436
   ::nClrPane  := 16776563

   @ 8, 32 SAY ::oLabel1 PROMPT "Jeśli widzisz to okno, to jest to moja pierwsza appka na MacBook" OF Self SIZE 320
   ::oLabel1:nClrPane := 9640787
   ::oLabel1:oFont := "SnellRoundhand-Bold,24,011993"
   @ 288, 168 GET ::oEdit1 VAR "" OF Self SIZE 360, 40
   ::oEdit1:oFont := ".AppleSystemUIFont,12"
   @ 352, 304 BUTTON ::oButton1 PROMPT "Safe to file" OF Self SIZE 200, 32
   ::oButton1:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oLabel1:OnClick := { || Label1Click( Self ) }
   ::oButton1:OnClick := { || Button1Click( Self ) }

return nil
//--------------------------------------------------------------------

//--------------------------------------------------------------------
static function Label1Click( oForm )

   MsgInfo("Działa wszystko jak szalone")

return nil
//--------------------------------------------------------------------
static function Button1Click( oForm )

	//W32_MsgBox(::PoleTekstowe:cText)
   MsgInfo( oForm:oEdit1:cText )

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
*/
