// Project1.prg - fixture roundtrip test
#include "hbbuilder.ch"
PROCEDURE Main()
   local oApp, oForm1
   oApp := TApplication():New()
   oApp:cTitle := "Fixture Roundtrip"
   oForm1 := TForm1():New()
   oApp:CreateForm( oForm1 )
   oApp:Run()
return
