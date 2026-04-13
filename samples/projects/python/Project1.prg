// Project1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:Title := "Python Sample"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
