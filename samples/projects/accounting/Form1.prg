// Form1.prg - Premium General Ledger & Accounting Application (Contabilidad RAD)
//
// A state-of-the-art Double-Entry Bookkeeping general ledger browser.
// Designed with a premium sidebar column layout, data grids (TListView)
// and stylized real-time financial KPI cards.

#include "hbbuilder.ch"

static oListView
static oLblViewTitle
static oCardDeb
static oCardCre
static oCardDiff
static oGrpMenu
static cDbfPath := ""
static cAlias := ""
static lDbfOpen := .F.
static cCurrentView := "DIARIO" // "DIARIO" | "BALANZA"

function Form1Main()

   local oForm, oMenu, oNav
   local oBtnOpen, oBtnAdd, oBtnBal, oBtnToggle
   local nBtnW, nBtnH

   cDbfPath := hb_DirBase() + "ledger.dbf"

   // 1. Define the main form with modern dark corporate colors
   DEFINE FORM oForm TITLE "Harbour Accounting Suite Pro" ;
      SIZE 900, 600 FONT "Segoe UI", 10

   // Style the main form background (elegant charcoal/slate pane)
   oForm:nClrPane := RGB(43, 43, 46)

   // Menu bar
   DEFINE MENUBAR OF oForm

   DEFINE POPUP oMenu PROMPT "&Diario" OF oForm
   MENUITEM "&Abrir Diario"              OF oMenu ACTION OpenLedger()
   MENUITEM "&Nueva Poliza Automatica"   OF oMenu ACTION AddTransaction()
   MENUITEM "&Balanza de Comprobacion"   OF oMenu ACTION ShowBalanceSheet()
   MENUSEPARATOR OF oMenu
   MENUITEM "&Salir"                     OF oMenu ACTION oForm:Close()

   DEFINE POPUP oNav PROMPT "&Navegacion" OF oForm
   MENUITEM "&Primero"       OF oNav ACTION GoFirst()
   MENUITEM "&Anterior"      OF oNav ACTION GoPrev()
   MENUITEM "&Siguiente"     OF oNav ACTION GoNext()
   MENUITEM "&Ultimo"        OF oNav ACTION GoLast()

   // 2. Left Sidebar panel (Acciones/Operaciones)
   @ 15, 15 GROUPBOX oGrpMenu PROMPT "Operaciones Contables" OF oForm SIZE 200, 520
   oGrpMenu:nClrText := RGB(240, 240, 240)

   nBtnW := 170
   nBtnH := 36

   @ 45, 30 BUTTON oBtnOpen PROMPT "📁 Abrir Diario" OF oForm SIZE nBtnW, nBtnH
   oBtnOpen:OnClick := { || OpenLedger() }
   
   @ 95, 30 BUTTON oBtnAdd PROMPT "➕ Nueva Poliza" OF oForm SIZE nBtnW, nBtnH
   oBtnAdd:OnClick := { || AddTransaction() }
   
   @ 145, 30 BUTTON oBtnBal PROMPT "📊 Ver Balanza" OF oForm SIZE nBtnW, nBtnH
   oBtnBal:OnClick := { || ShowBalanceSheet() }

   @ 195, 30 BUTTON oBtnToggle PROMPT "📋 Ver Libro Diario" OF oForm SIZE nBtnW, nBtnH
   oBtnToggle:OnClick := { || ViewDiario() }

   // 3. Right Main Content Area (Visual Grid + Dashboard Title)
   @ 20, 230 SAY oLblViewTitle PROMPT "VISTA: NINGUN DIARIO ABIERTO" OF oForm SIZE 640, 22
   oLblViewTitle:oFont    := "Segoe UI,12,Bold"
   oLblViewTitle:nClrText := RGB(224, 224, 224)

   // Main grid utilizing TLabel and TListView
   @ 50, 230 LISTVIEW oListView OF oForm SIZE 640, 420

   // 4. Stylized Financial KPI cards at the bottom
   // Debit KPI (Green Theme)
   @ 485, 230 SAY oCardDeb PROMPT "📈 DEBE: $ 0.00" OF oForm SIZE 200, 48
   oCardDeb:nAlign      := 1
   oCardDeb:oFont       := "Segoe UI,11,Bold"
   oCardDeb:nClrPane    := RGB(30, 48, 30)
   oCardDeb:nClrText    := RGB(98, 224, 98)
   oCardDeb:lTransparent := .F.

   // Credit KPI (Red Theme)
   @ 485, 450 SAY oCardCre PROMPT "📉 HABER: $ 0.00" OF oForm SIZE 200, 48
   oCardCre:nAlign      := 1
   oCardCre:oFont       := "Segoe UI,11,Bold"
   oCardCre:nClrPane    := RGB(48, 30, 30)
   oCardCre:nClrText    := RGB(224, 98, 98)
   oCardCre:lTransparent := .F.

   // Difference/Variance KPI (Blue/Cyan Theme)
   @ 485, 670 SAY oCardDiff PROMPT "⚖️ DIFERENCIA: $ 0.00" OF oForm SIZE 200, 48
   oCardDiff:nAlign      := 1
   oCardDiff:oFont       := "Segoe UI,11,Bold"
   oCardDiff:nClrPane    := RGB(30, 35, 48)
   oCardDiff:nClrText    := RGB(98, 180, 224)
   oCardDiff:lTransparent := .F.

   oForm:OnResize := { || FormResize( oForm ) }

   ACTIVATE FORM oForm CENTERED

   if lDbfOpen
      ( cAlias )->( DbCloseArea() )
      lDbfOpen := .F.
   endif

   oForm:Destroy()

return nil

// ---------------------------------------------------------------------------
// OpenLedger() - Open (or create) the DBF Ledger
// ---------------------------------------------------------------------------
static function OpenLedger()

   local aStruct

   if lDbfOpen
      ( cAlias )->( DbCloseArea() )
      lDbfOpen := .F.
   endif

   if ! File( cDbfPath )
      aStruct := { ;
         { "DATE",    "D",  8, 0 }, ;
         { "ACC_NO",  "C",  5, 0 }, ;
         { "ACC_NM",  "C", 20, 0 }, ;
         { "DEB",     "N", 12, 2 }, ;
         { "CRE",     "N", 12, 2 }, ;
         { "CONCEPT", "C", 40, 0 }  ;
      }

      DbCreate( cDbfPath, aStruct )

      USE ( cDbfPath ) ALIAS LEDGER NEW EXCLUSIVE
      cAlias := "LEDGER"
      lDbfOpen := .T.

      // Pre-populate with beautiful balanced accounting records
      APPEND BLANK
      REPLACE DATE WITH Date(), ACC_NO WITH "1100", ACC_NM WITH "Bancos (Efectivo)", DEB WITH 500000.00, CRE WITH 0.00, CONCEPT WITH "Aportacion Inicial Capital"
      APPEND BLANK
      REPLACE DATE WITH Date(), ACC_NO WITH "3000", ACC_NM WITH "Capital Social", DEB WITH 0.00, CRE WITH 500000.00, CONCEPT WITH "Aportacion Inicial Capital"

      APPEND BLANK
      REPLACE DATE WITH Date(), ACC_NO WITH "1500", ACC_NM WITH "Mobiliario Oficina", DEB WITH 25000.00, CRE WITH 0.00, CONCEPT WITH "Escritorios corporativos"
      APPEND BLANK
      REPLACE DATE WITH Date(), ACC_NO WITH "1100", ACC_NM WITH "Bancos (Efectivo)", DEB WITH 0.00, CRE WITH 25000.00, CONCEPT WITH "Escritorios corporativos"

      APPEND BLANK
      REPLACE DATE WITH Date(), ACC_NO WITH "1100", ACC_NM WITH "Bancos (Efectivo)", DEB WITH 85000.00, CRE WITH 0.00, CONCEPT WITH "Consultoria Tecnologica"
      APPEND BLANK
      REPLACE DATE WITH Date(), ACC_NO WITH "4000", ACC_NM WITH "Ingresos p. Servicios", DEB WITH 0.00, CRE WITH 85000.00, CONCEPT WITH "Consultoria Tecnologica"

      DbCommit()
   else
      USE ( cDbfPath ) ALIAS LEDGER NEW EXCLUSIVE
      cAlias := "LEDGER"
      lDbfOpen := .T.
   endif

   cCurrentView := "DIARIO"
   ViewDiario()

return nil

// ---------------------------------------------------------------------------
// ViewDiario() - Displays the active ledger records in the list view
// ---------------------------------------------------------------------------
static function ViewDiario()

   local aRows := {}
   local nTotalDeb := 0
   local nTotalCre := 0

   if ! lDbfOpen
      MsgInfo("Por favor, abre un Libro Diario primero.")
      return nil
   endif

   cCurrentView := "DIARIO"
   oLblViewTitle:cText := "LIBRO DIARIO GENERAL - REGISTROS DEL SISTEMA"

   // Setup grid columns
   oListView:SetColumns( { "Reg", "Fecha", "Cuenta", "Nombre Cuenta", "Debe (Cargo)", "Haber (Abono)", "Concepto" } )

   (cAlias)->(DbGoTop())
   while ! (cAlias)->(Eof())
      AAdd( aRows, { ;
         LTrim(Str((cAlias)->(RecNo()))), ;
         DToC( (cAlias)->DATE ), ;
         (cAlias)->ACC_NO, ;
         (cAlias)->ACC_NM, ;
         If( (cAlias)->DEB > 0, "$" + Transform((cAlias)->DEB, "9,999,999.99"), "" ), ;
         If( (cAlias)->CRE > 0, "$" + Transform((cAlias)->CRE, "9,999,999.99"), "" ), ;
         (cAlias)->CONCEPT ;
      } )
      nTotalDeb += (cAlias)->DEB
      nTotalCre += (cAlias)->CRE
      (cAlias)->(DbSkip())
   end

   oListView:SetItems( aRows )

   // Refresh bottom stylized metrics cards
   oCardDeb:cText  := "📈 SUMA DEBE:" + Chr(13) + Chr(10) + "$ " + Transform( nTotalDeb, "9,999,999.99" )
   oCardCre:cText  := "📉 SUMA HABER:" + Chr(13) + Chr(10) + "$ " + Transform( nTotalCre, "9,999,999.99" )
   
   if Abs( nTotalDeb - nTotalCre ) < 0.01
      oCardDiff:nClrPane := RGB(30, 48, 30)
      oCardDiff:nClrText := RGB(98, 224, 98)
      oCardDiff:cText   := "⚖️ BALANCEADO" + Chr(13) + Chr(10) + "$ 0.00"
   else
      oCardDiff:nClrPane := RGB(48, 30, 30)
      oCardDiff:nClrText := RGB(224, 98, 98)
      oCardDiff:cText   := "⚖️ DIFERENCIA:" + Chr(13) + Chr(10) + "$ " + Transform( Abs(nTotalDeb - nTotalCre), "9,999,999.99" )
   endif

return nil

// ---------------------------------------------------------------------------
// AddTransaction() - Appends a balanced random double entry transaction
// ---------------------------------------------------------------------------
static function AddTransaction()

   local nRand
   local cConcept := ""
   local nAmt := 0.00
   local cDebAcc := "", cDebNm := ""
   local cCreAcc := "", cCreNm := ""

   if ! lDbfOpen
      MsgInfo("Debe abrir el diario primero.")
      return nil
   endif

   nRand := Seconds() % 3

   if nRand == 0
      cConcept := "Pago mensual de arrendamiento"
      nAmt     := 18000.00
      cDebAcc  := "6100"
      cDebNm   := "Gastos de Renta"
      cCreAcc  := "1100"
      cCreNm   := "Bancos (Efectivo)"
   elseif nRand == 1
      cConcept := "Adquisicion papeleria corporativa"
      nAmt     := 2450.00
      cDebAcc  := "6200"
      cDebNm   := "Gastos de Oficina"
      cCreAcc  := "1100"
      cCreNm   := "Bancos (Efectivo)"
   else
      cConcept := "Cobro factura consultoria"
      nAmt     := 35000.00
      cDebAcc  := "1100"
      cDebNm   := "Bancos (Efectivo)"
      cCreAcc  := "1200"
      cCreNm   := "Clientes Nacionales"
   endif

   (cAlias)->(DbAppend())
   REPLACE DATE WITH Date(), ACC_NO WITH cDebAcc, ACC_NM WITH cDebNm, DEB WITH nAmt, CRE WITH 0.00, CONCEPT WITH cConcept

   (cAlias)->(DbAppend())
   REPLACE DATE WITH Date(), ACC_NO WITH cCreAcc, ACC_NM WITH cCreNm, DEB WITH 0.00, CRE WITH nAmt, CONCEPT WITH cConcept

   (cAlias)->(DbCommit())

   cCurrentView := "DIARIO"
   ViewDiario()

   MsgInfo( "Asiento de poliza automatica balanceada e inyectada con exito!" )

return nil

// ---------------------------------------------------------------------------
// ShowBalanceSheet() - Aggregates accounts and outputs a gorgeous Trial Balance grid
// ---------------------------------------------------------------------------
static function ShowBalanceSheet()

   local aAccounts := {}
   local aRows := {}
   local nIdx, i
   local nTotalDeb := 0
   local nTotalCre := 0

   if ! lDbfOpen
      MsgInfo("Debe abrir el diario primero.")
      return nil
   endif

   cCurrentView := "BALANZA"
   oLblViewTitle:cText := "BALANZA DE COMPROBACION - ESTADO DE SALDOS"

   // Reconfigure Grid Columns for Financial Report
   oListView:SetColumns( { "Codigo", "Nombre de Cuenta", "Cargos (Debe)", "Abonos (Haber)" } )

   // Aggregate totals
   (cAlias)->(DbGoTop())
   while ! (cAlias)->(Eof())
      nIdx := AScan( aAccounts, {|x| x[1] == LEDGER->ACC_NO} )
      if nIdx == 0
         AAdd( aAccounts, { LEDGER->ACC_NO, LEDGER->ACC_NM, LEDGER->DEB, LEDGER->CRE } )
      else
         aAccounts[nIdx][3] += LEDGER->DEB
         aAccounts[nIdx][4] += LEDGER->CRE
      endif
      (cAlias)->(DbSkip())
   end

   // Sort by account code
   ASort( aAccounts,,, {|x,y| x[1] < y[1]} )

   // Populate grid items
   for i := 1 to Len( aAccounts )
      AAdd( aRows, { ;
         aAccounts[i][1], ;
         aAccounts[i][2], ;
         If( aAccounts[i][3] > 0, "$" + Transform(aAccounts[i][3], "9,999,999.99"), "" ), ;
         If( aAccounts[i][4] > 0, "$" + Transform(aAccounts[i][4], "9,999,999.99"), "" )  ;
      } )
      nTotalDeb += aAccounts[i][3]
      nTotalCre += aAccounts[i][4]
   next

   oListView:SetItems( aRows )

   // Refresh stylized cards
   oCardDeb:cText  := "📈 SUMA DEBE:" + Chr(13) + Chr(10) + "$ " + Transform( nTotalDeb, "9,999,999.99" )
   oCardCre:cText  := "📉 SUMA HABER:" + Chr(13) + Chr(10) + "$ " + Transform( nTotalCre, "9,999,999.99" )

   if Abs( nTotalDeb - nTotalCre ) < 0.01
      oCardDiff:nClrPane := RGB(30, 48, 30)
      oCardDiff:nClrText := RGB(98, 224, 98)
      oCardDiff:cText   := "⚖️ CUADRADO" + Chr(13) + Chr(10) + "$ 0.00"
   else
      oCardDiff:nClrPane := RGB(48, 30, 30)
      oCardDiff:nClrText := RGB(224, 98, 98)
      oCardDiff:cText   := "⚖️ DESCUADRE:" + Chr(13) + Chr(10) + "$ " + Transform( Abs(nTotalDeb - nTotalCre), "9,999,999.99" )
   endif

return nil

// ---------------------------------------------------------------------------
// Database Navigation
// ---------------------------------------------------------------------------
static function GoFirst()
   if lDbfOpen .and. cCurrentView == "DIARIO"
      (cAlias)->(DbGoTop())
      ViewDiario()
   endif
return nil

static function GoPrev()
   if lDbfOpen .and. cCurrentView == "DIARIO"
      (cAlias)->(DbSkip(-1))
      if (cAlias)->(Bof())
         (cAlias)->(DbGoTop())
      endif
      ViewDiario()
   endif
return nil

static function GoNext()
   if lDbfOpen .and. cCurrentView == "DIARIO"
      (cAlias)->(DbSkip(1))
      if (cAlias)->(Eof())
         (cAlias)->(DbGoBottom())
      endif
      ViewDiario()
   endif
return nil

static function GoLast()
   if lDbfOpen .and. cCurrentView == "DIARIO"
      (cAlias)->(DbGoBottom())
      ViewDiario()
   endif
return nil

// ---------------------------------------------------------------------------
// FormResize() - Responsively adjusts control sizes and positions on resize
// ---------------------------------------------------------------------------
static function FormResize( oForm )
   local nClientW := oForm:nClientWidth
   local nClientH := oForm:nClientHeight
   local nRemainW
   local nCardW
   local nKpiTop

   // Resize sidebar groupbox
   if oGrpMenu != nil
      oGrpMenu:nHeight := nClientH - 40
   endif

   nRemainW := nClientW - 230 - 15
   if nRemainW < 300
      nRemainW := 300
   endif

   // Resize title label
   if oLblViewTitle != nil
      oLblViewTitle:nWidth := nRemainW
   endif

   // Positions of KPI cards
   nKpiTop := nClientH - 48 - 15
   if nKpiTop < 100
      nKpiTop := 100
   endif

   // Resize listview
   if oListView != nil
      oListView:nWidth := nRemainW
      oListView:nHeight := nKpiTop - 50 - 15
   endif

   // Position and resize KPI cards
   nCardW := ( nRemainW - 40 ) / 3
   if nCardW < 80
      nCardW := 80
   endif

   if oCardDeb != nil
      oCardDeb:nTop   := nKpiTop
      oCardDeb:nLeft  := 230
      oCardDeb:nWidth := nCardW
   endif

   if oCardCre != nil
      oCardCre:nTop   := nKpiTop
      oCardCre:nLeft  := 230 + nCardW + 20
      oCardCre:nWidth := nCardW
   endif

   if oCardDiff != nil
      oCardDiff:nTop   := nKpiTop
      oCardDiff:nLeft  := 230 + ( nCardW + 20 ) * 2
      oCardDiff:nWidth := nCardW
   endif

return nil

