// Form1.prg — TRust getting started
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   DATA oRust
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

   ::cTitle  := "TRust — Getting started"
   ::nLeft   := 200
   ::nTop    := 120
   ::nWidth  := 660
   ::nHeight := 540

   COMPONENT ::oRust TYPE CT_RUST OF Self
   ::oRust:cRuntimePath := ""
   ::oRust:cCompileFlags := ""
   ::oRust:OnReady  := { |o| ::Log( "[ready] rustc " + o:cLastResult ) }
   ::oRust:OnError  := { |o, cErr| ::Log( "[error] " + cErr ) }
   ::oRust:OnOutput := { |o, cOut| ::Log( cOut ) }
   ::oRust:OnBuild  := { |o, lOk, cBuild| ;
      ::Log( iif( lOk, "[build ok]", "[build FAIL] " + cBuild ) ) }

   @ 16,  16 SAY ::oLblSample PROMPT "Sample:" OF Self SIZE 60
   @ 14,  80 COMBOBOX ::oCboSamples OF Self SIZE 360, 26 ;
       ITEMS { "Hello, world", "Sum 1..100", "Fibonacci (10)", "Eval expression", "SetVar demo" }

   @ 48,  16 SAY ::oLblScript PROMPT "Source (editable):" OF Self SIZE 200
   @ 68,  16 MEMO ::oScriptEdit OF Self SIZE 624, 200

   @ 280, 16  BUTTON ::oBtnRun   PROMPT "Run (Exec)"  OF Self SIZE 110, 28
   @ 280, 132 BUTTON ::oBtnEval  PROMPT "Eval"        OF Self SIZE 110, 28
   @ 280, 248 BUTTON ::oBtnBuild PROMPT "Build only"  OF Self SIZE 110, 28
   @ 280, 580 BUTTON ::oBtnClear PROMPT "Clear"       OF Self SIZE 60,  28

   ::oBtnRun:OnClick   := { || ::DoRun()   }
   ::oBtnEval:OnClick  := { || ::DoEval()  }
   ::oBtnBuild:OnClick := { || ::DoBuild() }
   ::oBtnClear:OnClick := { || ::DoClear() }
   ::oCboSamples:OnChange := { || ::LoadSample( ::oCboSamples:Value + 1 ) }

   @ 320, 16 SAY ::oLblOutput PROMPT "Output:" OF Self SIZE 200
   @ 340, 16 MEMO ::oOutput OF Self SIZE 624, 160

   ::oScriptEdit:cText := ;
      "fn main() {" + Chr(10) + ;
      e"    println!(\"Hello, world from Rust!\");" + Chr(10) + ;
      "}" + Chr(10)

return nil
//--------------------------------------------------------------------

METHOD LoadSample( nIdx ) CLASS TForm1
   local cCode := "", e := Chr(10)
   do case
   case nIdx == 1
      cCode := "fn main() {" + e + e"    println!(\"Hello, world from Rust!\");" + e + "}" + e
   case nIdx == 2
      cCode := "fn main() {" + e + ;
               "    let s: i64 = (1..=100).sum();" + e + ;
               e"    println!(\"sum(1..100) = {}\", s);" + e + "}" + e
   case nIdx == 3
      cCode := "fn main() {" + e + ;
               "    let (mut a, mut b) = (0i64, 1i64);" + e + ;
               "    for i in 0..10 {" + e + ;
               e"        println!(\"{} {}\", i, a);" + e + ;
               "        let t = a + b; a = b; b = t;" + e + ;
               "    }" + e + "}" + e
   case nIdx == 4
      // Eval mode: just an expression
      cCode := "2 + 2 * 5"
   case nIdx == 5
      cCode := "fn main() {" + e + ;
               "    // Vars injected by SetVar will appear here at top of main()." + e + ;
               e"    println!(\"see Eval log\");" + e + "}" + e
   endcase
   ::oScriptEdit:cText := cCode
return nil
//--------------------------------------------------------------------

METHOD DoRun() CLASS TForm1
   ::Log( "=== Run ===" )
   ::oRust:Exec( ::oScriptEdit:cText )
return nil

METHOD DoEval() CLASS TForm1
   local cExpr := AllTrim( ::oScriptEdit:cText ), cValue
   if Empty( cExpr ); ::Log( "(empty)" ); return nil; endif
   ::oRust:SetVar( "name", "World" )    // demo SetVar
   cValue := ::oRust:Eval( cExpr )
   ::Log( "=== Eval: " + cExpr + " ===" )
   ::Log( cValue )
return nil

METHOD DoBuild() CLASS TForm1
   ::Log( "=== Build ===" )
   ::oRust:Build( ::oScriptEdit:cText )
return nil

METHOD DoClear() CLASS TForm1
   ::oOutput:cText := ""
return nil

METHOD Log( cMsg ) CLASS TForm1
   ::oOutput:cText := ::oOutput:cText + cMsg + Chr(10)
return nil
//--------------------------------------------------------------------
