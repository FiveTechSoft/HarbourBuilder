// Project1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp
   local oForm1   // AS TForm1

   oApp := TApplication():New()
   oApp:Title := "Project1"
   oForm1 := TForm1():New()
   oApp:CreateForm( oForm1 )
   oApp:Run()

return
//--------------------------------------------------------------------
