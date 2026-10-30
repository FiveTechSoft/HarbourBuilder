#include "hbbuilder.ch"
CLASS TTestForm FROM TForm
   DATA oLbl
   DATA oSrv
   METHOD CreateForm()
ENDCLASS
METHOD CreateForm() CLASS TTestForm
   ::cTitle := "HixTest"
   ::nLeft := 50
   ::nTop := 50
   ::nWidth := 300
   ::nHeight := 120
   @ 10, 10 SAY ::oLbl PROMPT "hix test" OF Self SIZE 200
   ::oSrv := TWebServer():New()
   ::oSrv:nPort := 8091
   ::oSrv:AddRoute( "GET", "/", { || UI_HIX_WRITE( "hello-root" ) } )
   ::oSrv:AddRoute( "GET", "/q", { || UI_HIX_WRITE( "q=" + UI_HIX_Query() ) } )
   ::oSrv:Start()
   MemoWrit( "/tmp/hix_mainloop_out.txt", "lRunning=" + iif( ::oSrv:lRunning, "T", "F" ) )
return nil
PROCEDURE Main()
   local oApp, oForm
   oApp := TApplication():New()
   oForm := TTestForm():New()
   oApp:CreateForm( oForm )
   oApp:Run()
return
