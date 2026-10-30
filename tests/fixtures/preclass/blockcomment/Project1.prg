// Project1.prg - fixture preclass frontier test
#include "hbbuilder.ch"
PROCEDURE Main()
   local oApp, oForm1
   oApp := TApplication():New()
   oApp:cTitle := "Fixture PreClass"
   oForm1 := TForm1():New()
   oApp:CreateForm( oForm1 )
   oApp:Run()
return
