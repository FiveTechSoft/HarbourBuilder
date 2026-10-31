// Project1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp
   local oForm1   // AS TForm1
   local oForm2   // AS TForm2

   oApp := TApplication():New()
   oApp:cTitle := "Project1"
   oForm1 := TForm1():New()
   oApp:CreateForm( oForm1 )
   oForm2 := TForm2():New()
   oApp:CreateForm( oForm2 )
   oApp:Run()

return
//--------------------------------------------------------------------
