// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oPrinter1     // TPrinter
   DATA oBtnPrint     // TButton
   DATA oBtnPreview   // TButton
   DATA oCbLandscape  // TCheckBox
   DATA oCbCopies     // TComboBox
   DATA oLblPrinter   // TLabel
   DATA oCbPrinter    // TComboBox
   DATA oLog          // TMemo

   // Event handlers

   METHOD CreateForm()
   METHOD OnPrintClick()
   METHOD OnPreviewClick()
   METHOD DoPrint()
   METHOD OnBeginDoc()
   METHOD OnEndDoc()
   METHOD OnNewPage()
   METHOD OnPrinterError()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TPrinter Demo"
   ::nLeft   := 982
   ::nTop    := 278
   ::nWidth  := 620
   ::nHeight := 560

   COMPONENT ::oPrinter1 TYPE CT_PRINTER OF Self  // TPrinter @ 8,456

   // Row 1: Print / Preview / Landscape / Copies
   @ 10, 10  BUTTON   ::oBtnPrint    PROMPT "Print"     OF Self SIZE 100, 32
   @ 10, 120 BUTTON   ::oBtnPreview  PROMPT "Preview"   OF Self SIZE 100, 32
   @ 16, 240 CHECKBOX ::oCbLandscape PROMPT "Landscape" OF Self SIZE 120
   @ 16, 380 COMBOBOX ::oCbCopies    OF Self ITEMS { "1", "2", "3", "5" } SIZE 80, 26

   // Row 2: Printer selector
   @ 55, 10  SAY      ::oLblPrinter  PROMPT "Printer:"  OF Self SIZE 60, 22
   @ 52, 75  COMBOBOX ::oCbPrinter   OF Self            SIZE 520, 26

   // Log memo
   @ 100, 10 MEMO ::oLog OF Self SIZE 590, 420

   ::oLog:cText := "Press Print or Preview to select and use a printer." + Chr(13) + Chr(10)

   // Event wiring
   ::oPrinter1:OnBeginDoc := { || ::OnBeginDoc()      }
   ::oPrinter1:OnEndDoc   := { || ::OnEndDoc()        }
   ::oPrinter1:OnNewPage  := { || ::OnNewPage()       }
   ::oPrinter1:OnError    := { || ::OnPrinterError()  }
   ::oBtnPrint:OnClick    := { || ::OnPrintClick()    }
   ::oBtnPreview:OnClick  := { || ::OnPreviewClick()  }

return nil
//--------------------------------------------------------------------

METHOD OnPrintClick() CLASS TForm1
   local aCopies := { 1, 2, 3, 5 }
   local nSel    := ::oCbCopies:Value + 1
   local aP      := ::oPrinter1:GetPrinters()
   local nPrinter
   // If no system printers, use demo list
   if Len( aP ) == 0
      aP := { "PDF (virtual)", "HP LaserJet (demo)", "Epson WF (demo)" }
   endif
   ::oCbPrinter:FillItems( aP )
   nPrinter := ::oCbPrinter:Value + 1
   if nPrinter < 1 .or. nPrinter > Len( aP ); nPrinter := 1; ::oCbPrinter:Value := 0; endif
   ::oPrinter1:cPrinterName := aP[ nPrinter ]
   ::oLog:cText += "Printer: " + ::oPrinter1:cPrinterName + Chr(13)+Chr(10)
   ::oPrinter1:lLandscape := ::oCbLandscape:lChecked
   ::oPrinter1:nCopies    := iif( nSel >= 1 .and. nSel <= Len(aCopies), aCopies[nSel], 1 )
   ::oPrinter1:lPreview   := .F.
   ::DoPrint()
return nil

METHOD OnPreviewClick() CLASS TForm1
   local aP      := ::oPrinter1:GetPrinters()
   local nPrinter
   if Len( aP ) == 0
      aP := { "PDF (virtual)", "HP LaserJet (demo)", "Epson WF (demo)" }
   endif
   ::oCbPrinter:FillItems( aP )
   nPrinter := ::oCbPrinter:Value + 1
   if nPrinter < 1 .or. nPrinter > Len( aP ); nPrinter := 1; ::oCbPrinter:Value := 0; endif
   ::oPrinter1:cPrinterName := aP[ nPrinter ]
   ::oLog:cText += "Printer: " + ::oPrinter1:cPrinterName + Chr(13)+Chr(10)
   ::oPrinter1:lLandscape := ::oCbLandscape:lChecked
   ::oPrinter1:nCopies    := 1
   ::oPrinter1:lPreview   := .T.
   ::DoPrint()
return nil

METHOD DoPrint() CLASS TForm1
   ::oPrinter1:BeginDoc( "TPrinter Demo" )

   // Page 1 — text lines
   ::oPrinter1:PrintLine(  20, 20, "HarbourBuilder — TPrinter Demo" )
   ::oPrinter1:PrintLine(  40, 20, "Date: " + DToC( Date() ) + "   Time: " + Time() )
   ::oPrinter1:PrintLine(  60, 20, Replicate( "-", 60 ) )
   ::oPrinter1:PrintLine(  80, 20, "Harbour is a free software compiler for the xBase language." )
   ::oPrinter1:PrintLine( 100, 20, "This demo exercises BeginDoc, PrintLine, PrintRect," )
   ::oPrinter1:PrintLine( 120, 20, "PrintImage, NewPage and EndDoc." )
   ::oPrinter1:PrintLine( 140, 20, "Printer : " + ::oPrinter1:cPrinterName )
   ::oPrinter1:PrintRect( 160, 20, 560, 2 )
   ::oPrinter1:PrintLine( 180, 20, "Copies  : " + hb_ntos( ::oPrinter1:nCopies ) )
   ::oPrinter1:PrintLine( 200, 20, "Landscape: " + iif( ::oPrinter1:lLandscape, "Yes", "No" ) )

   // Page 2 — second page demo
   ::oPrinter1:NewPage()
   ::oPrinter1:PrintLine( 20, 20, "Page 2 — NewPage() fired the OnNewPage event." )
   ::oPrinter1:PrintRect( 40, 20, 200, 100 )
   ::oPrinter1:PrintLine( 50, 30, "Rect demo" )

   ::oPrinter1:EndDoc()
return nil

METHOD OnBeginDoc() CLASS TForm1
   ::oLog:cText += "[Event] OnBeginDoc fired" + Chr(13) + Chr(10)
return nil

METHOD OnEndDoc() CLASS TForm1
   ::oLog:cText += "[Event] OnEndDoc fired" + Chr(13) + Chr(10)
return nil

METHOD OnNewPage() CLASS TForm1
   ::oLog:cText += "[Event] OnNewPage fired" + Chr(13) + Chr(10)
return nil

METHOD OnPrinterError() CLASS TForm1
   ::oLog:cText += "[Event] OnError fired" + Chr(13) + Chr(10)
return nil
