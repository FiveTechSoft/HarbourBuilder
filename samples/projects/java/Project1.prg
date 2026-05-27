// Project1.prg — TJava demo
#include "hbbuilder.ch"

PROCEDURE Main()
   local oApp, oForm
   oApp := TApplication():New()
   oApp:cTitle := "TJava Demo"
   oForm := TForm1():New()
   oApp:CreateForm( oForm )
   oApp:Run()
return
