// Project1.prg
//--------------------------------------------------------------------
// Sample iOS project for HarbourBuilder.
//
// Open this project, hit Run > Run on iOS... and the designed
// Form1 will appear on the iPhone Simulator with NATIVE UIKit
// controls (UILabel, UIButton, UITextField) — no web views.
//
// The macOS/Windows/Linux target runs the same code via TForm; the
// iOS target re-emits it as UI_* calls (see GenerateiOSPRG
// in source/hbbuilder_macos.prg).
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:Title := "HarbourBuilder iOS Sample"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
