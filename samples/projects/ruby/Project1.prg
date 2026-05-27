// Project1.prg — TRuby demo
#include "hbbuilder.ch"

PROCEDURE Main()
   local oApp, oForm
   oApp := TApplication():New()
   oApp:cTitle := "TRuby Demo"
   oForm := TForm1():New()
   oApp:CreateForm( oForm )
   oApp:Run()
return
