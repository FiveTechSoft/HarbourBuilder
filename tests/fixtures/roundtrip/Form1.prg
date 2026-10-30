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
   DATA oLedit1    // TLabeledEdit
   DATA oFld1   // TFolder
   DATA oBtnPg2   // TButton
   DATA oBrw1   // TBrowse

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
   @ 140, 20 COMBOBOX ::oCombo1 OF Self SIZE 180, 26 ITEMS "Uno", "Di " + Chr( 34 ) + "si" + Chr( 34 ), "Tre, s"
   ::oCombo1:Value := 0
   ::oLabel1:cText := FixtureCaption( ::oCombo1 )
   @ 190, 20 GROUPBOX ::oGroup1 PROMPT "Grupo" OF Self SIZE 260, 90
   @ 210, 40 RADIOBUTTON ::oRadio1 PROMPT "Opcion A" OF Self SIZE 120 CHECKED
   @ 300, 20 BITBTN ::oBitBtn1 PROMPT "ConIcono" OF Self SIZE 110, 32 PICTURE "icon.png"
   @ 350, 20 IMAGE ::oImage1 OF Self SIZE 64, 64 PICTURE "test.png"
   @ 430, 20 MEMO ::oMemo1 VAR "linea1" OF Self SIZE 240, 80
   @ 60, 320 LABELEDEDIT ::oLedit1 VAR "editable" OF Self SIZE 160, 24
   @ 430, 300 LISTBOX ::oList1 OF Self SIZE 160, 90 ITEMS "Alfa", "Beta"
   ::oList1:Value := 2
   @ 60, 460 FOLDER ::oFld1 OF Self SIZE 165, 160 PROMPTS "P1", "P2"
   @ 90, 475 BUTTON ::oBtnPg2 PROMPT "Pag2" OF ::oFld1:aPages[2] SIZE 90, 26
   @ 240, 460 BROWSE ::oBrw1 OF Self SIZE 165, 150 HEADERS "Nombre", "Edad" COLSIZES 90, 60 FOOTERS "Total", ""
   FixtureTraceRaw( "folder-tabs:" + UI_GetProp( ::oFld1:hCpp, "aTabs" ) )
   FixtureTraceRaw( "browse-cols:" + LTrim( hb_ValToStr( UI_BrowseColCount( ::oBrw1:hCpp ) ) ) )
   FixtureTraceRaw( "page2-btn:" + UI_GetProp( ::oBtnPg2:hCpp, "cText" ) )
   FixtureTraceRaw( "page2-owner:" + iif( UI_GetCtrlOwner( ::oBtnPg2:hCpp ) == ::oFld1:hCpp, "folder", "other" ) )
   FixtureTraceRaw( "page2-page:" + LTrim( hb_ValToStr( UI_GetCtrlPage( ::oBtnPg2:hCpp ) ) ) )

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

function FixtureTraceRaw( cLine )
   local c := ""
   if File( "/tmp/fixture_trace.log" )
      c := MemoRead( "/tmp/fixture_trace.log" )
   endif
   MemoWrit( "/tmp/fixture_trace.log", c + cLine + Chr(10) )
return nil

function FixtureTrace( cTag, oCtrl )
   MemoWrit( "/tmp/fixture_trace.log", cTag + ":" + oCtrl:cText + Chr(10) )
return nil

function FixtureClick( oForm )
   oForm:oLabel1:cText := "fixture-ok"
return nil
