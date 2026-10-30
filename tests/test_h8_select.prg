// test_h8_select.prg - H8: combo/listbox nItemIndex selection correctness.
// Asserts against the real GTK widget state (via h8_helper probes):
//  1) combo Value:=2 selects row 1 (0-based) and reads back 2
//  2) combo Value:=0 clears the selection and reads back 0
//  3) direct widget change (user pick of 3rd item) maps to FItemIndex 3
//     through on_combo_changed (H8b: callback is 0-based + 1)
//  4) listbox nItemIndex:=2 selects row 1 and reads back 2
//  5) listbox nItemIndex:=0 really unselects (H8a) and reads back 0
#include "hbbuilder.ch"

CLASS TTestForm FROM TForm
   DATA oCombo
   DATA oList
   METHOD CreateForm()
ENDCLASS

METHOD CreateForm() CLASS TTestForm
   ::cTitle := "H8SelectTest"
   ::nLeft := 60
   ::nTop := 60
   ::nWidth := 420
   ::nHeight := 320
   @ 20, 20 COMBOBOX ::oCombo OF Self SIZE 180 ITEMS "Uno", "Dos", "Tres"
   @ 80, 20 LISTBOX ::oList OF Self SIZE 180, 100 ITEMS "Alpha", "Beta", "Gamma"
   H8_RunAfter( 1500, { || H8Asserts( Self ) } )
return nil

PROCEDURE Main()
   local oApp := TApplication():New()
   oApp:CreateForm( TTestForm():New() )
   oApp:Run()
return

static procedure H8Asserts( oForm )
   local cOut := "H8 selection assertions" + Chr(10)
   local nW, nV
   // Fresh widget and model must agree before any selection mutation.
   nW := H8_ComboGetActive()
   nV := oForm:oCombo:Value
   cOut += iif( nW == -1 .and. nV == 0, "OK", "FAIL" ) + " fresh combo: widget=" + hb_ntos(nW) + " value=" + hb_ntos(nV) + Chr(10)
   // combo: programmatic select
   oForm:oCombo:Value := 2
   nW := H8_ComboGetActive()
   nV := oForm:oCombo:Value
   cOut += iif( nW == 1 .and. nV == 2, "OK", "FAIL" ) + " combo set 2: widget=" + AllTrim( Str( nW ) ) + " value=" + AllTrim( Str( nV ) ) + Chr(10)
   // combo: programmatic unselect
   oForm:oCombo:Value := 0
   nW := H8_ComboGetActive()
   nV := oForm:oCombo:Value
   cOut += iif( nW == -1 .and. nV == 0, "OK", "FAIL" ) + " combo set 0: widget=" + AllTrim( Str( nW ) ) + " value=" + AllTrim( Str( nV ) ) + Chr(10)
   // combo: direct widget change (user path) -> on_combo_changed must store 1-based
   H8_ComboSetActive0( 2 )
   nV := oForm:oCombo:Value
   cOut += iif( nV == 3, "OK", "FAIL" ) + " combo user-pick row 2 (0-based): value=" + AllTrim( Str( nV ) ) + Chr(10)
   // listbox: programmatic select
   oForm:oList:nItemIndex := 2
   nW := H8_ListSelRow()
   nV := oForm:oList:nItemIndex
   cOut += iif( nW == 1 .and. nV == 2, "OK", "FAIL" ) + " listbox set 2: widget=" + AllTrim( Str( nW ) ) + " value=" + AllTrim( Str( nV ) ) + Chr(10)
   // listbox: programmatic unselect (H8a)
   oForm:oList:nItemIndex := 0
   nW := H8_ListSelRow()
   nV := oForm:oList:nItemIndex
   cOut += iif( nW == -1 .and. nV == 0, "OK", "FAIL" ) + " listbox set 0: widget=" + AllTrim( Str( nW ) ) + " value=" + AllTrim( Str( nV ) ) + Chr(10)
   cOut += "H8 DONE" + Chr(10)
   MemoWrit( "/tmp/h8_result.txt", cOut )
   H8_Quit()
return
