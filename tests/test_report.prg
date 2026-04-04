// test_report.prg - Unit tests for TReportBand + TReportField data model
//
// Tests the report designer data model classes.
// Run: cd tests && bash build_test_report.sh
//
// Each test prints PASS or FAIL. Exit code 0 = all passed.

#include "../harbour/hbbuilder.ch"

static nTests    := 0
static nPassed   := 0
static nFailed   := 0
static lVerbose  := .T.

function Main()

   ? "============================================"
   ? "HarbourBuilder Report Designer - Unit Tests"
   ? "============================================"
   ?

   TestGroup( "Band Creation" )
   Test_BandCreation()

   TestGroup( "Field Addition" )
   Test_FieldAddition()

   TestGroup( "Band Properties" )
   Test_BandProperties()

   TestGroup( "Field Properties" )
   Test_FieldProperties()

   TestGroup( "Field Data Binding" )
   Test_FieldDataBinding()

   TestGroup( "Report Band Management" )
   Test_ReportBandManagement()

   TestGroup( "Code Generation" )
   Test_CodeGeneration()

   // === Summary ===
   ?
   ? "============================================"
   ? "Results: " + LTrim(Str(nPassed)) + " passed, " + ;
     LTrim(Str(nFailed)) + " failed, " + ;
     LTrim(Str(nTests)) + " total"
   ? "============================================"

   if nFailed > 0
      ? "SOME TESTS FAILED"
      ErrorLevel( 1 )
   else
      ? "ALL TESTS PASSED"
      ErrorLevel( 0 )
   endif

return nil

// =========================================================
// Test helpers
// =========================================================

static function TestGroup( cName )
   ?
   ? "--- " + cName + " ---"
return nil

static function Assert( lCondition, cDescription )
   nTests++
   if lCondition
      nPassed++
      if lVerbose
         ? "  PASS: " + cDescription
      endif
   else
      nFailed++
      ? "  FAIL: " + cDescription
   endif
return lCondition

static function AssertEquals( xActual, xExpected, cDescription )
   local lOk
   if ValType( xActual ) == "N" .and. ValType( xExpected ) == "N"
      lOk := ( xActual == xExpected )
   elseif ValType( xActual ) == "C" .and. ValType( xExpected ) == "C"
      lOk := ( xActual == xExpected )
   elseif ValType( xActual ) == "L" .and. ValType( xExpected ) == "L"
      lOk := ( xActual == xExpected )
   else
      lOk := .F.
   endif
   if ! lOk
      cDescription += " (expected=" + hb_ValToStr(xExpected) + ;
                      " actual=" + hb_ValToStr(xActual) + ")"
   endif
   Assert( lOk, cDescription )
return lOk

// =========================================================
// Test 1: Band Creation
// =========================================================

static function Test_BandCreation()
   local oBand

   oBand := TReportBand():New( "Header" )
   Assert( oBand != nil, "Band object created" )
   AssertEquals( oBand:cName, "Header", "Band name is Header" )
   AssertEquals( oBand:nHeight, 30, "Default height is 30" )
   AssertEquals( oBand:FieldCount(), 0, "New band has no fields" )
   Assert( oBand:lPrintOnEveryPage, "Header band prints on every page" )

   oBand := TReportBand():New( "Detail" )
   Assert( ! oBand:lPrintOnEveryPage, "Detail band does not print on every page" )

   oBand := TReportBand():New( "PageHeader" )
   Assert( oBand:lPrintOnEveryPage, "PageHeader band prints on every page" )

return nil

// =========================================================
// Test 2: Field Addition
// =========================================================

static function Test_FieldAddition()
   local oBand, oField1, oField2

   oBand := TReportBand():New( "Detail" )
   oField1 := TReportField():New( "Field1" )
   oField2 := TReportField():New( "Field2" )

   oBand:AddField( oField1 )
   AssertEquals( oBand:FieldCount(), 1, "One field after adding" )

   oBand:AddField( oField2 )
   AssertEquals( oBand:FieldCount(), 2, "Two fields after adding second" )

   oBand:RemoveField( 1 )
   AssertEquals( oBand:FieldCount(), 1, "One field after removing" )
   AssertEquals( oBand:aFields[1]:cName, "Field2", "Correct field remains" )

return nil

// =========================================================
// Test 3: Band Properties
// =========================================================

static function Test_BandProperties()
   local oBand

   oBand := TReportBand():New( "Detail" )

   AssertEquals( oBand:lKeepTogether, .T., "Default lKeepTogether is true" )
   AssertEquals( oBand:lVisible, .T., "Default lVisible is true" )
   AssertEquals( oBand:nBackColor, -1, "Default nBackColor is -1" )

   oBand:nHeight := 50
   oBand:lKeepTogether := .F.
   oBand:nBackColor := 16777215

   AssertEquals( oBand:nHeight, 50, "Height changed to 50" )
   AssertEquals( oBand:lKeepTogether, .F., "lKeepTogether changed to false" )
   AssertEquals( oBand:nBackColor, 16777215, "nBackColor changed" )

return nil

// =========================================================
// Test 4: Field Properties
// =========================================================

static function Test_FieldProperties()
   local oField

   oField := TReportField():New( "TitleField" )

   AssertEquals( oField:cName, "TitleField", "Field name set" )
   AssertEquals( oField:nWidth, 80, "Default width is 80" )
   AssertEquals( oField:nHeight, 16, "Default height is 16" )
   AssertEquals( oField:cFontName, "Sans", "Default font is Sans" )
   AssertEquals( oField:nFontSize, 10, "Default font size is 10" )
   AssertEquals( oField:lBold, .F., "Default bold is false" )
   AssertEquals( oField:cFieldType, "text", "Default field type is text" )

   oField:cText := "My Title"
   oField:lBold := .T.
   oField:nFontSize := 14
   oField:cFontName := "Arial"

   AssertEquals( oField:cText, "My Title", "Text changed" )
   Assert( oField:lBold, "Bold changed to true" )
   AssertEquals( oField:nFontSize, 14, "Font size changed" )
   AssertEquals( oField:cFontName, "Arial", "Font name changed" )

return nil

// =========================================================
// Test 5: Field Data Binding
// =========================================================

static function Test_FieldDataBinding()
   local oField

   oField := TReportField():New( "NameField" )
   Assert( ! oField:IsDataBound(), "Field without cFieldName is not data-bound" )

   oField:cFieldName := "CUSTOMER_NAME"
   Assert( oField:IsDataBound(), "Field with cFieldName is data-bound" )

   // GetValue with nil datasource returns nil
   Assert( oField:GetValue( nil ) == nil, "GetValue with nil datasource returns nil" )

return nil

// =========================================================
// Test 6: Report Band Management
// =========================================================

static function Test_ReportBandManagement()
   local oReport, oBand1, oBand2, oBand3, oFound

   oReport := TReport():New()

   oBand1 := TReportBand():New( "Header" )
   oBand2 := TReportBand():New( "Detail" )
   oBand3 := TReportBand():New( "Footer" )

   oReport:AddDesignBand( oBand1 )
   oReport:AddDesignBand( oBand2 )
   oReport:AddDesignBand( oBand3 )

   AssertEquals( Len( oReport:aDesignBands ), 3, "Three design bands added" )

   oFound := oReport:GetDesignBand( "Detail" )
   Assert( oFound != nil, "GetDesignBand finds Detail" )
   AssertEquals( oFound:cName, "Detail", "Found band name matches" )

   oFound := oReport:GetDesignBand( "detail" )
   Assert( oFound != nil, "GetDesignBand is case-insensitive" )

   oFound := oReport:GetDesignBand( "NonExistent" )
   Assert( oFound == nil, "GetDesignBand returns nil for unknown band" )

   oReport:RemoveDesignBand( 2 )
   AssertEquals( Len( oReport:aDesignBands ), 2, "Two bands after removal" )
   AssertEquals( oReport:aDesignBands[1]:cName, "Header", "First band is Header" )
   AssertEquals( oReport:aDesignBands[2]:cName, "Footer", "Second band is Footer" )

return nil

// =========================================================
// Test 7: Code Generation
// =========================================================

static function Test_CodeGeneration()
   local oReport, oBand, oField, cCode

   oReport := TReport():New()
   oReport:nPageWidth := 210
   oReport:nMarginLeft := 20

   oBand := TReportBand():New( "Header" )
   oBand:nHeight := 40
   oField := TReportField():New( "Title" )
   oField:cText := "Sales Report"
   oField:lBold := .T.
   oField:nFontSize := 14
   oBand:AddField( oField )
   oReport:AddDesignBand( oBand )

   oBand := TReportBand():New( "Detail" )
   oField := TReportField():New( "CustName" )
   oField:cFieldName := "NAME"
   oField:nWidth := 150
   oBand:AddField( oField )
   oReport:AddDesignBand( oBand )

   cCode := oReport:GenerateCode( "TSalesReport" )

   Assert( "CLASS TSalesReport INHERIT TReport" $ cCode, "Code contains class declaration" )
   Assert( "METHOD CreateReport()" $ cCode, "Code contains CreateReport method" )
   Assert( "::nPageWidth" $ cCode, "Code contains page width" )
   Assert( "::nMarginLeft" $ cCode, "Code contains margin left" )
   Assert( '"Header"' $ cCode, "Code contains Header band" )
   Assert( '"Detail"' $ cCode, "Code contains Detail band" )
   Assert( '"Sales Report"' $ cCode, "Code contains field text" )
   Assert( "lBold := .T." $ cCode, "Code contains bold setting" )
   Assert( '"NAME"' $ cCode, "Code contains field name" )
   Assert( "return Self" $ cCode, "Code contains return Self" )

return nil
