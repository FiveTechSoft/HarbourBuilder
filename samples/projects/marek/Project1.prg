// Project1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:Title := "Test nr 1 na Mac"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
