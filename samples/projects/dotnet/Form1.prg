// Form1.prg — TDotNet getting started
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   DATA oDotNet
   DATA oLblSample, oCboSamples
   DATA oLblScript, oScriptEdit
   DATA oBtnRun, oBtnEval, oBtnBuild, oBtnClear
   DATA oLblOutput, oOutput

   METHOD CreateForm()
   METHOD DoRun()
   METHOD DoEval()
   METHOD DoBuild()
   METHOD DoClear()
   METHOD LoadSample( nIdx )
   METHOD Log( cMsg )

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TDotNet — Getting started"
   ::nLeft   := 240
   ::nTop    := 140
   ::nWidth  := 660
   ::nHeight := 540

   COMPONENT ::oDotNet TYPE CT_DOTNET OF Self
   ::oDotNet:cRuntimePath := ""
   ::oDotNet:OnReady  := { |o| ::Log( "[ready] dotnet " + o:cLastResult ) }
   ::oDotNet:OnError  := { |o, cErr| ::Log( "[error] " + cErr ) }
   ::oDotNet:OnOutput := { |o, cOut| ::Log( cOut ) }
   ::oDotNet:OnBuild  := { |o, lOk, cBuild| ;
      ::Log( iif( lOk, "[build ok]", "[build FAIL] " + cBuild ) ) }

   @ 16, 16 SAY ::oLblSample PROMPT "Sample:" OF Self SIZE 60
   @ 14, 80 COMBOBOX ::oCboSamples OF Self SIZE 360, 26 ;
       ITEMS { "Hello, world", "Sum 1..100", "DateTime.Now", "Eval expression" }

   @ 48, 16 SAY ::oLblScript PROMPT "C# source (editable):" OF Self SIZE 240
   @ 68, 16 MEMO ::oScriptEdit OF Self SIZE 624, 200

   @ 280, 16  BUTTON ::oBtnRun   PROMPT "Run (Exec)" OF Self SIZE 110, 28
   @ 280, 132 BUTTON ::oBtnEval  PROMPT "Eval"       OF Self SIZE 110, 28
   @ 280, 248 BUTTON ::oBtnBuild PROMPT "Build only" OF Self SIZE 110, 28
   @ 280, 580 BUTTON ::oBtnClear PROMPT "Clear"      OF Self SIZE 60,  28

   ::oBtnRun:OnClick   := { || ::DoRun()  }
   ::oBtnEval:OnClick  := { || ::DoEval() }
   ::oBtnBuild:OnClick := { || ::DoBuild() }
   ::oBtnClear:OnClick := { || ::DoClear() }
   ::oCboSamples:OnChange := { || ::LoadSample( ::oCboSamples:Value + 1 ) }

   @ 320, 16 SAY ::oLblOutput PROMPT "Output:" OF Self SIZE 200
   @ 340, 16 MEMO ::oOutput OF Self SIZE 624, 160

   ::oScriptEdit:cText := ;
      "using System;" + Chr(10) + ;
      e"Console.WriteLine(\"Hello, world from .NET!\");" + Chr(10)

return nil
//--------------------------------------------------------------------

METHOD LoadSample( nIdx ) CLASS TForm1
   local cCode := "", e := Chr(10)
   do case
   case nIdx == 1
      cCode := "using System;" + e + ;
               e"Console.WriteLine(\"Hello, world from .NET!\");" + e
   case nIdx == 2
      cCode := "using System;" + e + ;
               "long s = 0; for (int i=1;i<=100;i++) s+=i;" + e + ;
               e"Console.WriteLine($\"sum(1..100) = {s}\");" + e
   case nIdx == 3
      cCode := "using System;" + e + ;
               e"Console.WriteLine(DateTime.Now.ToString(\"O\"));" + e
   case nIdx == 4
      cCode := "Math.Sqrt(144) + 1"
   endcase
   ::oScriptEdit:cText := cCode
return nil
//--------------------------------------------------------------------

METHOD DoRun() CLASS TForm1
   ::Log( "=== Run (this can take 5-15s on first build) ===" )
   ::oDotNet:Exec( ::oScriptEdit:cText )
return nil

METHOD DoEval() CLASS TForm1
   local cExpr := AllTrim( ::oScriptEdit:cText ), cValue
   if Empty( cExpr ); ::Log( "(empty)" ); return nil; endif
   cValue := ::oDotNet:Eval( cExpr )
   ::Log( "=== Eval: " + cExpr + " ===" )
   ::Log( cValue )
return nil

METHOD DoBuild() CLASS TForm1
   ::Log( "=== Build ===" )
   ::oDotNet:Build( ::oScriptEdit:cText )
return nil

METHOD DoClear() CLASS TForm1
   ::oOutput:cText := ""
return nil

METHOD Log( cMsg ) CLASS TForm1
   ::oOutput:cText := ::oOutput:cText + cMsg + Chr(10)
return nil
//--------------------------------------------------------------------
