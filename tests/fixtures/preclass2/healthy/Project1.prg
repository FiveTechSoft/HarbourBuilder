// Project1.prg - fixture multiform class refusal
#include "hbbuilder.ch"
PROCEDURE Main()
   local oApp, oForm1, oForm2
   oApp := TApplication():New()
   oApp:cTitle := "Fixture MultiForm"
   oForm1 := TForm1():New()
   oApp:CreateForm( oForm1 )
   oForm2 := TForm2():New()
   oApp:CreateForm( oForm2 )
   oApp:Run()
return
