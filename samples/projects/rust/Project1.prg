// Project1.prg — TRust demo
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()
   local oApp, oForm
   oApp := TApplication():New()
   oApp:cTitle := "TRust Demo"
   oForm := TForm1():New()
   oApp:CreateForm( oForm )
   oApp:Run()
return
//--------------------------------------------------------------------
