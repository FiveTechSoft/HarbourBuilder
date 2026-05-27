// Project1.prg — WebView sample
//--------------------------------------------------------------------
// Demonstrates TWebView: navigation, URL bar, Back/Forward/Reload,
// and the OnNavigate / OnLoad / OnError events.
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:cTitle := "WebView Demo"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
