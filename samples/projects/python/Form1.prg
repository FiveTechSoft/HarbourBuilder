// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oPython   // TPython
   DATA oScriptEdit   // TMemo
   DATA oBtnStart   // TButton
   DATA oBtnRun   // TButton
   DATA oBtnEval   // TButton
   DATA oBtnVar   // TButton
   DATA oBtnStop   // TButton
   DATA oOutput   // TMemo

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "TPython — TInteropRuntime demo"
   ::Left   := 922
   ::Top    := 265
   ::Width  := 600
   ::Height := 460

   COMPONENT ::oPython TYPE CT_PYTHON OF Self  // TPython @ 16,212
   ::oPython:oFont := ".AppleSystemUIFont,12"
   @ 36, 16 MEMO ::oScriptEdit OF Self SIZE 568, 140
   ::oScriptEdit:oFont := ".AppleSystemUIFont,12"
   @ 186, 16 BUTTON ::oBtnStart PROMPT "Start" OF Self SIZE 100, 28
   ::oBtnStart:oFont := ".AppleSystemUIFont,12"
   @ 186, 124 BUTTON ::oBtnRun PROMPT "Exec" OF Self SIZE 100, 28
   ::oBtnRun:oFont := ".AppleSystemUIFont,12"
   @ 186, 232 BUTTON ::oBtnEval PROMPT "Eval" OF Self SIZE 100, 28
   ::oBtnEval:oFont := ".AppleSystemUIFont,12"
   @ 186, 340 BUTTON ::oBtnVar PROMPT "Set/Get" OF Self SIZE 100, 28
   ::oBtnVar:oFont := ".AppleSystemUIFont,12"
   @ 186, 448 BUTTON ::oBtnStop PROMPT "Stop" OF Self SIZE 100, 28
   ::oBtnStop:oFont := ".AppleSystemUIFont,12"
   @ 252, 16 MEMO ::oOutput OF Self SIZE 568, 180
   ::oOutput:oFont := ".AppleSystemUIFont,12"

return nil
//--------------------------------------------------------------------

METHOD DoRun() CLASS TForm1
   local cCode := ::oScriptEdit:Text
   ::Log( "-> Exec( ... " + LTrim( Str( Len( cCode ) ) ) + " chars )" )
   ::oPython:Exec( cCode )
   if ! Empty( ::oPython:cLastResult )
      ::Log( "   result: " + ::oPython:cLastResult )
   endif
return nil

//--------------------------------------------------------------------
METHOD DoEval() CLASS TForm1
   local cExpr := "2 + 3 * 4"
   ::Log( "-> Eval( " + cExpr + " )" )
   ::oPython:Eval( cExpr )
   ::Log( "   result: " + ::oPython:cLastResult )
return nil

//--------------------------------------------------------------------
METHOD DoVar() CLASS TForm1
   ::Log( "-> SetVar( name, 'HarbourBuilder' )" )
   ::oPython:SetVar( "name", "HarbourBuilder" )
   ::Log( "-> GetVar( name ) = " + Var2Char( ::oPython:GetVar( "name" ) ) )
return nil

//--------------------------------------------------------------------
METHOD DoStop() CLASS TForm1
   ::oPython:Stop()
   ::Log( "-> Stop()  running=" + If( ::oPython:lRunning, ".T.", ".F." ) )
return nil

//--------------------------------------------------------------------
METHOD Log( cMsg ) CLASS TForm1
   ::oOutput:Text := ::oOutput:Text + cMsg + Chr(10)
return nil

//--------------------------------------------------------------------
static function Var2Char( x )
return If( x == nil, "nil", If( ValType( x ) == "C", x, "?" ) )
//--------------------------------------------------------------------
