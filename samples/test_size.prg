// Minimal test: create two forms side by side, compare sizes
// Build: same as hbbuilder_win.prg

#include "../harbour/hbbuilder.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local oForm1, oForm2

   SetDPIAware()

   // Form 1: created with explicit size 400x300
   DEFINE FORM oForm1 TITLE "Form1 - 400x300" SIZE 400, 300 SIZABLE
   UI_FormSetPos( oForm1:hCpp, 100, 100 )
   oForm1:Show()

   // Read what Form1 actually got
   MemoWrit( "c:\HarbourBuilder\test_size.log", ;
      "Form1 requested: 400x300" + Chr(10) + ;
      "Form1 Width=" + LTrim(Str(UI_GetProp(oForm1:hCpp,"nWidth"))) + ;
      " Height=" + LTrim(Str(UI_GetProp(oForm1:hCpp,"nHeight"))) + ;
      " ClientW=" + LTrim(Str(UI_GetProp(oForm1:hCpp,"nClientWidth"))) + ;
      " ClientH=" + LTrim(Str(UI_GetProp(oForm1:hCpp,"nClientHeight"))) + Chr(10) )

   // Form 2: same size, created in another process would it differ?
   DEFINE FORM oForm2 TITLE "Form2 - 400x300" SIZE 400, 300 SIZABLE
   UI_FormSetPos( oForm2:hCpp, 520, 100 )
   oForm2:Show()

   MemoWrit( "c:\HarbourBuilder\test_size.log", ;
      MemoRead( "c:\HarbourBuilder\test_size.log" ) + ;
      "Form2 Width=" + LTrim(Str(UI_GetProp(oForm2:hCpp,"nWidth"))) + ;
      " Height=" + LTrim(Str(UI_GetProp(oForm2:hCpp,"nHeight"))) + ;
      " ClientW=" + LTrim(Str(UI_GetProp(oForm2:hCpp,"nClientWidth"))) + ;
      " ClientH=" + LTrim(Str(UI_GetProp(oForm2:hCpp,"nClientHeight"))) + Chr(10) )

   oForm1:Activate()

return nil
