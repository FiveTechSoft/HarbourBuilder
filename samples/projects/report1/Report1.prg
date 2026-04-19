// Report1.prg - Sales Report definition
//
// Builds a professional A4 sales report with five bands:
//   Header      - company name, report title, run date
//   PageHeader  - column headers (shaded)
//   Detail      - one row per sale record
//   PageFooter  - page number
//   Footer      - grand total
//
// Layout (A4, margins 15 mm, usable width 180 mm):
//   Customer  0..49   Product  51..94   Qty  96..109
//   Price    111..139  Total  141..170

#include "hbbuilder.ch"

// nAlignment constants
#define ALIGN_LEFT   0
#define ALIGN_CENTER 1
#define ALIGN_RIGHT  2

//----------------------------------------------------------------------------//
// SalesReport( aData ) -> oReport
//
// aData: array of { cCustomer, cProduct, nQty, nUnitPrice }
// Returns a fully configured TReport ready to Preview() or ExportPDF().
//----------------------------------------------------------------------------//

function SalesReport( aData )

   local oReport, oBand, oFld
   local i, nTotal, nGrand := 0

   oReport := TReport():New()
   oReport:cTitle      := "Monthly Sales Report"
   oReport:nPageWidth  := 210
   oReport:nPageHeight := 297
   oReport:nMarginLeft := 15
   oReport:nMarginRight  := 15
   oReport:nMarginTop    := 15
   oReport:nMarginBottom := 15

   // ── Header band ─────────────────────────────────────────────────────────

   oBand := TReportBand():New( "Header" )
   oBand:nHeight := 30

   // Company name — large, bold, dark blue
   oFld := TReportField():New( "hdr_company" )
   oFld:cText      := "Acme Corporation"
   oFld:nTop       := 2
   oFld:nLeft      := 0
   oFld:nWidth     := 180
   oFld:nHeight    := 10
   oFld:cFontName  := "Segoe UI"
   oFld:nFontSize  := 14
   oFld:lBold      := .T.
   oFld:nForeColor := RGB( 0, 51, 102 )
   oFld:nAlignment := ALIGN_LEFT
   oBand:AddField( oFld )

   // Report title — centered, 11pt
   oFld := TReportField():New( "hdr_title" )
   oFld:cText      := "Monthly Sales Report"
   oFld:nTop       := 14
   oFld:nLeft      := 0
   oFld:nWidth     := 180
   oFld:nHeight    := 8
   oFld:cFontName  := "Segoe UI"
   oFld:nFontSize  := 11
   oFld:lBold      := .F.
   oFld:nForeColor := RGB( 40, 40, 40 )
   oFld:nAlignment := ALIGN_CENTER
   oBand:AddField( oFld )

   // Run date — right-aligned, 9pt, italic
   oFld := TReportField():New( "hdr_date" )
   oFld:cText      := "Date: " + DToC( Date() )
   oFld:nTop       := 14
   oFld:nLeft      := 0
   oFld:nWidth     := 180
   oFld:nHeight    := 8
   oFld:cFontName  := "Segoe UI"
   oFld:nFontSize  := 9
   oFld:lItalic    := .T.
   oFld:nForeColor := RGB( 100, 100, 100 )
   oFld:nAlignment := ALIGN_RIGHT
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

   // ── PageHeader band ──────────────────────────────────────────────────────

   oBand := TReportBand():New( "PageHeader" )
   oBand:nHeight    := 12
   oBand:nBackColor := RGB( 0, 82, 155 )

   oFld := TReportField():New( "ph_customer" )
   oFld:cText := "Customer"          ; oFld:nTop := 2 ; oFld:nLeft := 0
   oFld:nWidth := 49  ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_product" )
   oFld:cText := "Product"           ; oFld:nTop := 2 ; oFld:nLeft := 51
   oFld:nWidth := 43  ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_qty" )
   oFld:cText := "Qty"               ; oFld:nTop := 2 ; oFld:nLeft := 96
   oFld:nWidth := 13  ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_price" )
   oFld:cText := "Unit Price"        ; oFld:nTop := 2 ; oFld:nLeft := 111
   oFld:nWidth := 28  ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ph_total" )
   oFld:cText := "Total"             ; oFld:nTop := 2 ; oFld:nLeft := 141
   oFld:nWidth := 29  ; oFld:nHeight := 8 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
   oFld:nForeColor := RGB( 255, 255, 255 )
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

   // ── Detail bands (one per data row) ─────────────────────────────────────

   for i := 1 to Len( aData )

      nTotal := aData[i][3] * aData[i][4]
      nGrand += nTotal

      oBand := TReportBand():New( "Detail" )
      oBand:nHeight    := 8
      // Alternate row shading
      if i % 2 == 0
         oBand:nBackColor := RGB( 240, 245, 255 )
      else
         oBand:nBackColor := RGB( 255, 255, 255 )
      endif

      oFld := TReportField():New( "det_cust_" + hb_NToS(i) )
      oFld:cText := aData[i][1]      ; oFld:nTop := 1 ; oFld:nLeft := 0
      oFld:nWidth := 49  ; oFld:nHeight := 6
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_prod_" + hb_NToS(i) )
      oFld:cText := aData[i][2]      ; oFld:nTop := 1 ; oFld:nLeft := 51
      oFld:nWidth := 43  ; oFld:nHeight := 6
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_qty_" + hb_NToS(i) )
      oFld:cText := hb_NToS( aData[i][3] )
      oFld:nTop := 1 ; oFld:nLeft := 96
      oFld:nWidth := 13  ; oFld:nHeight := 6
      oFld:nAlignment := ALIGN_RIGHT
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_price_" + hb_NToS(i) )
      oFld:cText := "$" + Transform( aData[i][4], "9,999.99" )
      oFld:nTop := 1 ; oFld:nLeft := 111
      oFld:nWidth := 28  ; oFld:nHeight := 6
      oFld:nAlignment := ALIGN_RIGHT
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
      oFld:nForeColor := RGB( 30, 30, 30 )
      oBand:AddField( oFld )

      oFld := TReportField():New( "det_total_" + hb_NToS(i) )
      oFld:cText := "$" + Transform( nTotal, "9,999.99" )
      oFld:nTop := 1 ; oFld:nLeft := 141
      oFld:nWidth := 29  ; oFld:nHeight := 6
      oFld:nAlignment := ALIGN_RIGHT
      oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9
      oFld:nForeColor := iif( nTotal >= 1000, RGB( 0, 100, 0 ), RGB( 30, 30, 30 ) )
      oBand:AddField( oFld )

      oReport:AddDesignBand( oBand )

   next

   // ── Footer band (grand total) ────────────────────────────────────────────

   oBand := TReportBand():New( "Footer" )
   oBand:nHeight    := 14
   oBand:nBackColor := RGB( 230, 230, 230 )

   oFld := TReportField():New( "ftr_label" )
   oFld:cText := "Grand Total:"      ; oFld:nTop := 4 ; oFld:nLeft := 96
   oFld:nWidth := 43  ; oFld:nHeight := 7
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:nForeColor := RGB( 0, 51, 102 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "ftr_grand" )
   oFld:cText := "$" + Transform( nGrand, "99,999.99" )
   oFld:nTop := 4 ; oFld:nLeft := 141
   oFld:nWidth := 29  ; oFld:nHeight := 7
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 9 ; oFld:lBold := .T.
   oFld:nAlignment := ALIGN_RIGHT
   oFld:nForeColor := RGB( 0, 100, 0 )
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

   // ── PageFooter band ──────────────────────────────────────────────────────

   oBand := TReportBand():New( "PageFooter" )
   oBand:nHeight := 10

   oFld := TReportField():New( "pf_info" )
   oFld:cText := "Acme Corporation - Confidential"
   oFld:nTop := 2 ; oFld:nLeft := 0
   oFld:nWidth := 90  ; oFld:nHeight := 6
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8 ; oFld:lItalic := .T.
   oFld:nForeColor := RGB( 130, 130, 130 )
   oBand:AddField( oFld )

   oFld := TReportField():New( "pf_page" )
   oFld:cText := "Page 1"
   oFld:nTop := 2 ; oFld:nLeft := 91
   oFld:nWidth := 89  ; oFld:nHeight := 6
   oFld:nAlignment := ALIGN_RIGHT
   oFld:cFontName := "Segoe UI" ; oFld:nFontSize := 8
   oFld:nForeColor := RGB( 130, 130, 130 )
   oBand:AddField( oFld )

   oReport:AddDesignBand( oBand )

return oReport
