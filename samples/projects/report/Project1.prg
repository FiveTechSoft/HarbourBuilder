// Project1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:Title := "Report Designer Demo"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
