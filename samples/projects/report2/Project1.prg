// Project1.prg - Customer Report sample entry point

#include "hbbuilder.ch"

function Main()

   local oApp

   oApp := TApplication():New()
   oApp:cTitle := "Report"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return nil

// Framework
#include "classes.prg"
