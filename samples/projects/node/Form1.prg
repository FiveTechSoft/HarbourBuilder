// Form1.prg — TNode getting started
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   DATA oNode
   DATA oLblSample, oCboSamples
   DATA oLblScript, oScriptEdit
   DATA oBtnRun, oBtnEval, oBtnClear
   DATA oLblOutput, oOutput

   METHOD CreateForm()
   METHOD DoRun()
   METHOD DoEval()
   METHOD DoClear()
   METHOD LoadSample( nIdx )
   METHOD Log( cMsg )

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TNode — Getting started"
   ::nLeft   := 220
   ::nTop    := 130
   ::nWidth  := 620
   ::nHeight := 500

   COMPONENT ::oNode TYPE CT_NODE OF Self
   ::oNode:cRuntimePath := ""
   ::oNode:OnReady  := { |o| ::Log( "[ready] node " + o:cLastResult ) }
   ::oNode:OnError  := { |o, cErr| ::Log( "[error] " + cErr ) }
   ::oNode:OnOutput := { |o, cOut| ::Log( cOut ) }

   @ 16, 16 SAY ::oLblSample PROMPT "Sample:" OF Self SIZE 60
   @ 14, 80 COMBOBOX ::oCboSamples OF Self SIZE 360, 26 ;
       ITEMS { "Hello, world", "Sum 1..100", "JSON.stringify date", "Eval (2+2)", "SetVar demo" }

   @ 48, 16 SAY ::oLblScript PROMPT "Script (editable):" OF Self SIZE 200
   @ 68, 16 MEMO ::oScriptEdit OF Self SIZE 588, 160

   @ 240, 16  BUTTON ::oBtnRun   PROMPT "Run"   OF Self SIZE 100, 28
   @ 240, 124 BUTTON ::oBtnEval  PROMPT "Eval"  OF Self SIZE 100, 28
   @ 240, 504 BUTTON ::oBtnClear PROMPT "Clear" OF Self SIZE 100, 28
   ::oBtnRun:OnClick   := { || ::DoRun()  }
   ::oBtnEval:OnClick  := { || ::DoEval() }
   ::oBtnClear:OnClick := { || ::DoClear() }
   ::oCboSamples:OnChange := { || ::LoadSample( ::oCboSamples:Value + 1 ) }

   @ 282, 16 SAY ::oLblOutput PROMPT "Output:" OF Self SIZE 200
   @ 302, 16 MEMO ::oOutput OF Self SIZE 588, 160

   ::oScriptEdit:cText := "console.log('Hello, world from Node!');" + Chr(10)

return nil
//--------------------------------------------------------------------

METHOD LoadSample( nIdx ) CLASS TForm1
   local cCode := "", e := Chr(10)
   do case
   case nIdx == 1
      cCode := "console.log('Hello, world from Node!');" + e
   case nIdx == 2
      cCode := "let s = 0; for (let i = 1; i <= 100; i++) s += i;" + e + ;
               "console.log('sum(1..100) =', s);" + e
   case nIdx == 3
      cCode := "console.log(JSON.stringify({ now: new Date().toISOString() }));" + e
   case nIdx == 4
      cCode := "2 + 2"     // Eval mode
   case nIdx == 5
      cCode := "console.log('greeting:', greeting + ' ' + name);" + e
   endcase
   ::oScriptEdit:cText := cCode
return nil
//--------------------------------------------------------------------

METHOD DoRun() CLASS TForm1
   ::oNode:SetVar( "greeting", "Hello" )
   ::oNode:SetVar( "name",     "Antonio" )
   ::Log( "=== Run ===" )
   ::oNode:Exec( ::oScriptEdit:cText )
return nil

METHOD DoEval() CLASS TForm1
   local cExpr := AllTrim( ::oScriptEdit:cText ), cValue
   if Empty( cExpr ); ::Log( "(empty)" ); return nil; endif
   cValue := ::oNode:Eval( cExpr )
   ::Log( "=== Eval: " + cExpr + " ===" )
   ::Log( cValue )
return nil

METHOD DoClear() CLASS TForm1
   ::oOutput:cText := ""
return nil

METHOD Log( cMsg ) CLASS TForm1
   ::oOutput:cText := ::oOutput:cText + cMsg + Chr(10)
return nil
//--------------------------------------------------------------------
