// Project1.prg — TDotNet demo
#include "hbbuilder.ch"

PROCEDURE Main()
   local oApp, oForm
   oApp := TApplication():New()
   oApp:cTitle := "TDotNet Demo"
   oForm := TForm1():New()
   oApp:CreateForm( oForm )
   oApp:Run()
return
