// Report1.prg - Customer Report definition
//
// Builds a professional A4 customer report from customer.dbf.
//
// Bands:
//   Header      - company name, report title, run date
//   PageHeader  - column headers (dark blue, white text)
//   Detail      - one row per customer, alternating row shading
//   Footer      - record count + average salary
//   PageFooter  - page number
//
// Layout (A4, margins 15 mm, usable width 180 mm):
//   Name   0..54    City  57..94    State  97..108
//   Age  111..122   Salary 125..149  Hired  152..179

#include "hbbuilder.ch"

#define ALIGN_LEFT   0
#define ALIGN_CENTER 1
#define ALIGN_RIGHT  2

//----------------------------------------------------------------------------//
// CustomerReport( cFile ) -> oReport
//
// cFile  : full path to customer.dbf
// Returns a fully configured TReport ready to Preview() or ExportPDF().
//----------------------------------------------------------------------------//

function CustomerReport( cFile )

   local oReport, oBand, oFld
   local oDb
   local nRec, nCount, nSalarySum, nAvgSalary
   local cFirst, cLast, cCity, cState, dHired, nAge, nSalary
   local lAlt

   oDb := TDBFTable():New()
   oDb:cFileName := cFile
   oDb:cRDD      := "DBFCDX"
   oDb:lReadOnly := .T.
   oDb:Open()

   oReport := TReport():New()
   oReport:cTitle       := "Customer Database Report"
   oReport:nPageWidth   := 210
   oReport:nPageHeight  := 297
   oReport:nMarginLeft  := 15
   oReport:nMarginRight  := 15
   oReport:nMarginTop    := 15
   oReport:nMarginBottom := 15

   // ── Header band ─────────────────────────────────────────────────────────

   oBand := TReportBand():New( "Header" )
   oBand:nHeight := 30

   oFld := TReportField():New( "hdr_company" )
   oFld:cText      := "HarbourBuilder Inc."
   oFld:nTop       := 2  ; oFld:nLeft := 0
   oFld:nWidth     := 180 ; oFld:nHeight := 10
   oFld:cFontName  := "Segoe UI" ; oFld:nFontSize := 14 ; oFld:lBold := .T.
   oFld:nForeColor := RGB( 0, 51, 102 )
   oFld:nAlignment := ALIGN_LEFT
   oBand:AddField( oFld )

   oFld := TReportField():New( "hdr_title" )
   oFld:cText      := "Customer Database Report"
   oFld:nTop       := 14 ; oFld:nLeft := 0
   oFld:nWidth     := 180 ; oFld:nHeight := 8
   oFld:cFontName  := "Segoe UI" ; oFld:nFontSize := 11
   oFld:nForeColor := RGB( 40, 40, 40 )
   oFld:nAlignment := ALIGN_CENTER
   oBand:AddField( oFld )

   oFld := TReportField():New( "hdr_date" )
   oFld:cText      := "Date: " + DToC( Date() )
   oFld:nTop       := 14 ; oFld:nLeft := 0
   oFld:nWidth     := 180 ; oFld:nHeight := 8
   oFld:cFontName  := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lItalic := .T.
   oFld:nForeColor := RGB( 100, 100, 100 )
   oFld:nAlignment := ALIGN_RIGHT
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

   // ── PageHeader band ──────────────────────────────────────────────────────

   oBand := TReportBand():New( "PageHeader" )
   oBand:nHeight    := 12
   oBand:nBackColor := RGB( 0, 82, 155 )

   oFld := TReportField():New( "ph_name" )
   oFld:cText := "Name"         ; oFld:nTop := 2 ; oFld:nLeft := 0
   oFld:nWidth := 55 ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_city" )
   oFld:cText := "City"         ; oFld:nTop := 2 ; oFld:nLeft := 57
   oFld:nWidth := 38 ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_state" )
   oFld:cText := "ST"           ; oFld:nTop := 2 ; oFld:nLeft := 97
   oFld:nWidth := 12 ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_age" )
   oFld:cText := "Age"          ; oFld:nTop := 2 ; oFld:nLeft := 111
   oFld:nWidth := 12 ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_salary" )
   oFld:cText := "Salary"       ; oFld:nTop := 2 ; oFld:nLeft := 125
   oFld:nWidth := 25 ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_hired" )
   oFld:cText := "Hired"        ; oFld:nTop := 2 ; oFld:nLeft := 152
   oFld:nWidth := 28 ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

   // ── Detail bands (one per record) ───────────────────────────────────────

   nCount     := 0
   nSalarySum := 0
   lAlt       := .F.
   nRec       := 0
   oDb:GoTop()

   do while ! oDb:Eof()

      nRec++
      cFirst  := Trim( oDb:FieldGet(1) )
      cLast   := Trim( oDb:FieldGet(2) )
      cCity   := Trim( oDb:FieldGet(4) )
      cState  := oDb:FieldGet(5)
      dHired  := oDb:FieldGet(7)
      nAge    := oDb:FieldGet(9)
      nSalary := oDb:FieldGet(10)

      nCount++
      nSalarySum += nSalary
      lAlt := ! lAlt

      oBand := TReportBand():New( "Detail" )
      oBand:nHeight    := 7
      oBand:nBackColor := iif( lAlt, RGB( 240, 245, 255 ), RGB( 255, 255, 255 ) )

      oFld := TReportField():New( "det_name_" + hb_NToS(nRec) )
      oFld:cText := cFirst + " " + cLast
      oFld:nTop := 1 ; oFld:nLeft := 0
      oFld:nWidth := 55 ; oFld:nHeight := 5
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_city_" + hb_NToS(nRec) )
      oFld:cText := cCity
      oFld:nTop := 1 ; oFld:nLeft := 57
      oFld:nWidth := 38 ; oFld:nHeight := 5
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_state_" + hb_NToS(nRec) )
      oFld:cText := cState
      oFld:nTop := 1 ; oFld:nLeft := 97
      oFld:nWidth := 12 ; oFld:nHeight := 5
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_age_" + hb_NToS(nRec) )
      oFld:cText := hb_NToS( nAge )
      oFld:nTop := 1 ; oFld:nLeft := 111
      oFld:nWidth := 12 ; oFld:nHeight := 5
      oFld:nAlignment := ALIGN_RIGHT
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_salary_" + hb_NToS(nRec) )
      oFld:cText := "$" + Transform( nSalary, "99,999" )
      oFld:nTop := 1 ; oFld:nLeft := 125
      oFld:nWidth := 25 ; oFld:nHeight := 5
      oFld:nAlignment := ALIGN_RIGHT
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
      oFld:nForeColor := iif( nSalary >= 50000, RGB( 0, 100, 0 ), RGB( 30, 30, 30 ) )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_hired_" + hb_NToS(nRec) )
      oFld:cText := DToC( dHired )
      oFld:nTop := 1 ; oFld:nLeft := 152
      oFld:nWidth := 28 ; oFld:nHeight := 5
      oFld:nAlignment := ALIGN_RIGHT
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
      oFld:nForeColor := RGB( 80, 80, 80 )
      oBand:AddField( oFld )

      oReport:AddDesignBand( oBand )

      oDb:Skip(1)
   enddo

   oDb:Close()

   // ── Footer band ──────────────────────────────────────────────────────────

   nAvgSalary := iif( nCount > 0, nSalarySum / nCount, 0 )

   oBand := TReportBand():New( "Footer" )
   oBand:nHeight    := 14
   oBand:nBackColor := RGB( 220, 230, 245 )

   oFld := TReportField():New( "ftr_count_lbl" )
   oFld:cText := "Total records:"
   oFld:nTop := 2 ; oFld:nLeft := 0
   oFld:nWidth := 55 ; oFld:nHeight := 6
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_LEFT
   oFld:nForeColor := RGB( 0, 51, 102 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ftr_count_val" )
   oFld:cText := hb_NToS( nCount )
   oFld:nTop := 2 ; oFld:nLeft := 57
   oFld:nWidth := 20 ; oFld:nHeight := 6
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lBold := .T.
   oFld:nForeColor := RGB( 0, 51, 102 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ftr_avg_lbl" )
   oFld:cText := "Avg Salary:"
   oFld:nTop := 2 ; oFld:nLeft := 97
   oFld:nWidth := 53 ; oFld:nHeight := 6
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:nForeColor := RGB( 0, 51, 102 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ftr_avg_val" )
   oFld:cText := "$" + Transform( nAvgSalary, "99,999" )
   oFld:nTop := 2 ; oFld:nLeft := 152
   oFld:nWidth := 28 ; oFld:nHeight := 6
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:nForeColor := RGB( 0, 100, 0 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ftr_line" )
   oFld:cText := Replicate( Chr(196), 120 )
   oFld:nTop := 1 ; oFld:nLeft := 0
   oFld:nWidth := 180 ; oFld:nHeight := 2
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 6
   oFld:nForeColor := RGB( 0, 82, 155 )
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

   // ── PageFooter band ──────────────────────────────────────────────────────

   oBand := TReportBand():New( "PageFooter" )
   oBand:nHeight := 10

   oFld := TReportField():New( "pf_info" )
   oFld:cText := "HarbourBuilder Inc. - Confidential"
   oFld:nTop := 2 ; oFld:nLeft := 0
   oFld:nWidth := 90 ; oFld:nHeight := 6
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8 ; oFld:lItalic := .T.
   oFld:nForeColor := RGB( 130, 130, 130 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "pf_page" )
   oFld:cText := "Page 1"
   oFld:nTop := 2 ; oFld:nLeft := 91
   oFld:nWidth := 89 ; oFld:nHeight := 6
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
   oFld:nForeColor := RGB( 130, 130, 130 )
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

return oReport
