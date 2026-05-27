// Form1.prg — TJava getting started
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   DATA oJava
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

   ::cTitle  := "TJava — Getting started"
   ::nLeft   := 260
   ::nTop    := 150
   ::nWidth  := 660
   ::nHeight := 540

   COMPONENT ::oJava TYPE CT_JAVA OF Self
   ::oJava:cRuntimePath := ""
   ::oJava:cMainClass   := "Main"
   ::oJava:OnReady  := { |o| ::Log( "[ready] javac: " + o:cLastResult ) }
   ::oJava:OnError  := { |o, cErr| ::Log( "[error] " + cErr ) }
   ::oJava:OnOutput := { |o, cOut| ::Log( cOut ) }
   ::oJava:OnBuild  := { |o, lOk, cBuild| ;
      ::Log( iif( lOk, "[build ok]", "[build FAIL] " + cBuild ) ) }

   @ 16, 16 SAY ::oLblSample PROMPT "Sample:" OF Self SIZE 60
   @ 14, 80 COMBOBOX ::oCboSamples OF Self SIZE 360, 26 ;
       ITEMS { "Hello, world", "Sum 1..100", "Fibonacci (10)", "Eval expression" }

   @ 48, 16 SAY ::oLblScript PROMPT "Java source (editable):" OF Self SIZE 240
   @ 68, 16 MEMO ::oScriptEdit OF Self SIZE 624, 200

   @ 280, 16  BUTTON ::oBtnRun   PROMPT "Run"        OF Self SIZE 110, 28
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
      "public class Main {" + Chr(10) + ;
      "    public static void main(String[] a) {" + Chr(10) + ;
      "        System.out.println(\"Hello, world from Java!\");" + Chr(10) + ;
      "    }" + Chr(10) + ;
      "}" + Chr(10)

return nil
//--------------------------------------------------------------------

METHOD LoadSample( nIdx ) CLASS TForm1
   local cCode := "", e := Chr(10)
   do case
   case nIdx == 1
      cCode := "public class Main {" + e + ;
               "    public static void main(String[] a) {" + e + ;
               "        System.out.println(\"Hello, world from Java!\");" + e + ;
               "    }" + e + "}" + e
   case nIdx == 2
      cCode := "public class Main {" + e + ;
               "    public static void main(String[] a) {" + e + ;
               "        long s = 0; for (int i=1;i<=100;i++) s+=i;" + e + ;
               "        System.out.println(\"sum(1..100) = \" + s);" + e + ;
               "    }" + e + "}" + e
   case nIdx == 3
      cCode := "public class Main {" + e + ;
               "    public static void main(String[] a) {" + e + ;
               "        long x=0,y=1;" + e + ;
               "        for(int i=0;i<10;i++){ System.out.println(i+\" \"+x); long t=x+y; x=y; y=t; }" + e + ;
               "    }" + e + "}" + e
   case nIdx == 4
      cCode := "Math.sqrt(144) + 1"
   endcase
   ::oScriptEdit:cText := cCode
return nil
//--------------------------------------------------------------------

METHOD DoRun() CLASS TForm1
   ::Log( "=== Run ===" )
   ::oJava:Exec( ::oScriptEdit:cText )
return nil

METHOD DoEval() CLASS TForm1
   local cExpr := AllTrim( ::oScriptEdit:cText ), cValue
   if Empty( cExpr ); ::Log( "(empty)" ); return nil; endif
   cValue := ::oJava:Eval( cExpr )
   ::Log( "=== Eval: " + cExpr + " ===" )
   ::Log( cValue )
return nil

METHOD DoBuild() CLASS TForm1
   ::Log( "=== Build ===" )
   ::oJava:Build( ::oScriptEdit:cText )
return nil

METHOD DoClear() CLASS TForm1
   ::oOutput:cText := ""
return nil

METHOD Log( cMsg ) CLASS TForm1
   ::oOutput:cText := ::oOutput:cText + cMsg + Chr(10)
return nil
//--------------------------------------------------------------------
