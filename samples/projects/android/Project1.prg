// Project1.prg
//--------------------------------------------------------------------
// Sample Android project for HarbourBuilder.
//
// Open this project, hit Run > Run on Android... and the designed
// Form1 will appear on the emulator with NATIVE android.widget.*
// controls (not a web view, not a skinned UI).
//
// The Windows/macOS/Linux target runs the same code via TForm; the
// Android target re-emits it as UI_* calls (see GenerateAndroidPRG
// in source/hbbuilder_win.prg).
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:cTitle := "HarbourBuilder Android Sample"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
