// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oPython   // TPython
   DATA oLblSample   // TLabel
   DATA oCboSamples   // TComboBox
   DATA oLblScript   // TLabel
   DATA oScriptEdit   // TMemo
   DATA oBtnRun   // TButton
   DATA oBtnEval   // TButton
   DATA oBtnClear   // TButton
   DATA oLblOutput   // TLabel
   DATA oOutput   // TMemo

   // Event handlers

   METHOD CreateForm()
   METHOD DoRun()
   METHOD DoEval()
   METHOD DoClear()
   METHOD LoadSample( nIdx )
   METHOD Log( cMsg )

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TPython — Getting started"
   ::nLeft   := 939
   ::nTop    := 270
   ::nWidth  := 620
   ::nHeight := 500
   ::nPosition := 2

   COMPONENT ::oPython TYPE CT_PYTHON OF Self  // TPython @ 560,8
   ::oPython:oFont := ".AppleSystemUIFont,12"
   ::oPython:cRuntimePath := ""
   ::oPython:OnError  := { |o, cErr| ::Log( "[error] " + cErr ) }
   ::oPython:OnOutput := { |o, cOut| ::Log( cOut ) }
   @ 16, 16 SAY ::oLblSample PROMPT "Sample:" OF Self SIZE 60
   ::oLblSample:oFont := ".AppleSystemUIFont,12"
   @ 14, 80 COMBOBOX ::oCboSamples OF Self ITEMS { "Hello, world", "Square root", "Sum 1..100", "Python version", "Fibonacci (10)" } SIZE 300, 26
   ::oCboSamples:oFont := ".AppleSystemUIFont,12"
   @ 48, 16 SAY ::oLblScript PROMPT "Script (editable):" OF Self SIZE 200
   ::oLblScript:oFont := ".AppleSystemUIFont,12"
   @ 68, 16 MEMO ::oScriptEdit OF Self SIZE 588, 160
   ::oScriptEdit:cText := "# Classic greeting" + Chr(10) + "print( 'Hello, world from Python!' )" + Chr(10) + ""
   ::oScriptEdit:oFont := ".AppleSystemUIFont,12"
   @ 236, 16 BUTTON ::oBtnRun PROMPT "Run" OF Self SIZE 100, 28
   ::oBtnRun:oFont := ".AppleSystemUIFont,12"
   ::oBtnRun:OnClick := { || ::DoRun() }
   @ 236, 124 BUTTON ::oBtnEval PROMPT "Eval" OF Self SIZE 100, 28
   ::oBtnEval:oFont := ".AppleSystemUIFont,12"
   ::oBtnEval:OnClick := { || ::DoEval() }
   @ 236, 504 BUTTON ::oBtnClear PROMPT "Clear" OF Self SIZE 100, 28
   ::oBtnClear:oFont := ".AppleSystemUIFont,12"
   ::oBtnClear:OnClick := { || ::DoClear() }
   ::oCboSamples:OnChange := { || ::LoadSample( ::oCboSamples:Value + 1 ) }
   @ 282, 16 SAY ::oLblOutput PROMPT "Output:" OF Self SIZE 200
   ::oLblOutput:oFont := ".AppleSystemUIFont,12"
   @ 302, 16 MEMO ::oOutput OF Self SIZE 588, 170
   ::oOutput:oFont := ".AppleSystemUIFont,12"

return nil
//--------------------------------------------------------------------

METHOD LoadSample( nIdx ) CLASS TForm1
   local cCode := ""
   local e     := Chr(10)
   do case
   case nIdx == 1
      cCode := "# Classic greeting" + e + "print( 'Hello, world from Python!' )" + e
   case nIdx == 2
      cCode := "import math" + e + "x = 144" + e + ;
               "print( 'sqrt(' + str(x) + ') =', math.sqrt(x) )" + e
   case nIdx == 3
      cCode := "total = sum( range(1, 101) )" + e + ;
               "print( 'sum(1..100) =', total )" + e
   case nIdx == 4
      cCode := "import sys" + e + "print( 'Python', sys.version )" + e
   case nIdx == 5
      cCode := "a, b = 0, 1" + e + "for i in range(10):" + e + ;
               "    print( i, a )" + e + "    a, b = b, a + b" + e
   endcase
   ::oScriptEdit:cText := cCode
return nil

//--------------------------------------------------------------------
METHOD DoRun() CLASS TForm1
   ::Log( "=== Run ===" )
   ::oPython:Exec( ::oScriptEdit:cText )
return nil

//--------------------------------------------------------------------
METHOD DoEval() CLASS TForm1
   local cExpr := AllTrim( ::oScriptEdit:cText )
   local cValue
   if Empty( cExpr )
      ::Log( "(nothing to evaluate)" )
      return nil
   endif
   cValue := ::oPython:Eval( cExpr )
   ::Log( "=== Eval: " + cExpr + " ===" )
   ::Log( cValue )
return nil

//--------------------------------------------------------------------
METHOD DoClear() CLASS TForm1
   ::oOutput:cText := ""
return nil

//--------------------------------------------------------------------
METHOD Log( cMsg ) CLASS TForm1
   ::oOutput:cText := ::oOutput:cText + cMsg + Chr(10)
return nil
//--------------------------------------------------------------------
