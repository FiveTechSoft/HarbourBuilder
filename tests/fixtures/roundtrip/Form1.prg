// Form1.prg - FIXTURE roundtrip v3: order preservation + side-effect calls
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oButton1   // TButton
   DATA oLabel1    // TLabel
   DATA oEdit1     // TEdit
   DATA oChk1      // TCheckBox
   DATA oCombo1    // TComboBox
   DATA oGroup1    // TGroupBox
   DATA oRadio1    // TRadioButton
   DATA oBitBtn1   // TBitBtn
   DATA oImage1    // TImage
   DATA oMemo1     // TMemo
   DATA oList1     // TListBox

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Fixture Roundtrip"
   ::nLeft   := 200
   ::nTop    := 150
   ::nWidth  := 640
   ::nHeight := 480

   @ 20, 20 BUTTON ::oButton1 PROMPT "Aceptar" OF Self SIZE 110, 30
   ::oButton1:oFont := "Sans,10"
   @ 20, 160 SAY ::oLabel1 PROMPT "Etiqueta fija" OF Self SIZE 200
   @ 60, 20 GET ::oEdit1 VAR "texto inicial" OF Self SIZE 220, 26
   FixtureTrace( "after-edit1", ::oEdit1 )
   @ 100, 20 CHECKBOX ::oChk1 PROMPT "Marcado" OF Self SIZE 140 CHECKED
   @ 140, 20 COMBOBOX ::oCombo1 OF Self SIZE 180, 26 ITEMS "Uno", "Dos", "Tres"
   ::oLabel1:cText := FixtureCaption( ::oCombo1 )
   @ 190, 20 GROUPBOX ::oGroup1 PROMPT "Grupo" OF Self SIZE 260, 90
   @ 210, 40 RADIOBUTTON ::oRadio1 PROMPT "Opcion A" OF Self SIZE 120 CHECKED
   @ 300, 20 BITBTN ::oBitBtn1 PROMPT "ConIcono" OF Self SIZE 110, 32 PICTURE "icon.png"
   @ 350, 20 IMAGE ::oImage1 OF Self SIZE 64, 64 PICTURE "test.png"
   @ 430, 20 MEMO ::oMemo1 VAR "linea1" OF Self SIZE 240, 80
   @ 430, 300 LISTBOX ::oList1 OF Self SIZE 160, 90 ITEMS "Alfa", "Beta"
   ::oList1:Value := 2

   // comentario manual del usuario
   ::oEdit1:cText := "modificado"

   // Event wiring
   ::oButton1:OnClick := { || FixtureClick( Self ) }

return nil
//--------------------------------------------------------------------

// User code - MUST SURVIVE save/reopen
//--------------------------------------------------------------------
static function FixtureHelper( x )
   return Upper( hb_ValToStr( x ) )

function FixtureCaption( oCtrl )
   return iif( oCtrl:ClassName() == "TCOMBOBOX", "caption-ok", "caption-bad" )

function FixtureTrace( cTag, oCtrl )
   MemoWrit( "/tmp/fixture_trace.log", cTag + ":" + oCtrl:cText + Chr(10) )
return nil

function FixtureClick( oForm )
   oForm:oLabel1:cText := "fixture-ok"
return nil
