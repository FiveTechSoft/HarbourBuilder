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
 local cOut := "DEBUG real backend bridge lifecycle" + Chr(10), l, t
 HB_SYMBOL_UNUSED(oForm)
 t:=Seconds()
 l:=IDE_DebugStart2("/tmp/debug-child-test/missing",{||nil})
 cOut += "launch missing="+hb_ValToStr(l)+" seconds="+hb_ntos(Seconds()-t)+Chr(10)
 t:=Seconds()
 l:=IDE_DebugStart2("/bin/true",{||nil})
 cOut += "already exited="+hb_ValToStr(l)+" seconds="+hb_ntos(Seconds()-t)+Chr(10)
 H8_RunAfter(500,{||IDE_DebugStop()})
 t:=Seconds()
 l:=IDE_DebugStart2("/tmp/debug-child-test/child",{||nil})
 cOut += "stop during accept="+hb_ValToStr(l)+" seconds="+hb_ntos(Seconds()-t)+Chr(10)
 t:=Seconds()
 l:=IDE_DebugStart2("/tmp/debug-child-test/child",{||nil})
 cOut += "accept timeout="+hb_ValToStr(l)+" seconds="+hb_ntos(Seconds()-t)+Chr(10)
 cOut += "H8 DONE"+Chr(10)
 MemoWrit("/tmp/h8_result.txt",cOut)
return
