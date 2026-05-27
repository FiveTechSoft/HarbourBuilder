// Project1.prg
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp
   local oForm1   // AS TForm1

   oApp := TApplication():New()
   oApp:cTitle := "TPopupMenu Sample"
   oForm1 := TForm1():New()
   oApp:CreateForm( oForm1 )

   // Wire button click → show popup. Done here (not in Form1.prg's CreateForm)
   // because the IDE's RegenerateFormCode rewrites CreateForm on every Save
   // and would strip the assignment.
   oForm1:oButton1:OnClick := { || oForm1:oPopup1:Popup() }

   oApp:Run()

return
//--------------------------------------------------------------------
