// bench.prg - Benchmark: create 500 controls, measure time
// Tests: control creation, property set/get, message throughput

REQUEST HB_GT_GUI_DEFAULT

#define N_CONTROLS  500
#define N_PROPSETS  100000
#define N_PROPGETS  100000

function Main()

   local hForm, aCtrl := {}, i, t1, t2, t3, t4, t5, t6
   local cResult := ""
   local oForm, oBtn, xDummy

   // =============================================
   // Test 1: Create N_CONTROLS buttons
   // =============================================
   t1 := Seconds()

   hForm := UI_FormNew( "Benchmark", 800, 600, "Segoe UI", 12 )

   for i := 1 to N_CONTROLS
      AAdd( aCtrl, UI_ButtonNew( hForm, "Btn" + LTrim(Str(i)), ;
         ( (i-1) % 20 ) * 38 + 5, ;
         Int( (i-1) / 20 ) * 22 + 5, ;
         36, 20 ) )
   next

   t1 := Seconds() - t1

   // =============================================
   // Test 2: Set property N_PROPSETS times
   // =============================================
   t2 := Seconds()

   for i := 1 to N_PROPSETS
      UI_SetProp( aCtrl[ (i % N_CONTROLS) + 1 ], "nLeft", i % 700 )
   next

   t2 := Seconds() - t2

   // =============================================
   // Test 3: Get property N_PROPGETS times
   // =============================================
   t3 := Seconds()

   for i := 1 to N_PROPGETS
      UI_GetProp( aCtrl[ (i % N_CONTROLS) + 1 ], "nLeft" )
   next

   t3 := Seconds() - t3

   // =============================================
   // Test 4: Create form + controls + run (visual)
   // =============================================
   UI_FormDestroy( hForm )

   t4 := Seconds()

   hForm := UI_FormNew( "Bench Visual", 400, 300, "Segoe UI", 12 )

   for i := 1 to 100
      UI_LabelNew( hForm, "Label " + LTrim(Str(i)), ;
         10 + (i % 10) * 38, 10 + Int(i/10) * 18, 36, 16 )
   next

   for i := 1 to 100
      UI_ButtonNew( hForm, "B" + LTrim(Str(i)), ;
         10 + (i % 10) * 38, 200 + Int(i/10) * 22, 36, 20 )
   next

   t4 := Seconds() - t4

   // =============================================
   // Test 5: Harbour OOP wrapper overhead
   // =============================================
   UI_FormDestroy( hForm )

   t5 := Seconds()

   oForm := TForm():New( "OOP Bench", 400, 300 )

   for i := 1 to N_CONTROLS
      oBtn := TButton():New( oForm, "B" + LTrim(Str(i)), ;
         ( (i-1) % 20 ) * 38 + 5, ;
         Int( (i-1) / 20 ) * 22 + 5 )
   next

   t5 := Seconds() - t5

   // =============================================
   // Test 6: OOP property access
   // =============================================
   t6 := Seconds()

   for i := 1 to N_PROPGETS
      xDummy := oBtn:Left
      xDummy := oBtn:Top
   next

   t6 := Seconds() - t6

   oForm:Destroy()

   // =============================================
   // Results
   // =============================================
   cResult := "=== IDE Framework C++ Core Benchmark ===" + Chr(13)+Chr(10)
   cResult += Chr(13)+Chr(10)
   cResult += "Test 1: Create " + LTrim(Str(N_CONTROLS)) + " buttons (C++ direct)" + Chr(13)+Chr(10)
   cResult += "   Time: " + LTrim(Str(t1, 10, 4)) + " sec" + Chr(13)+Chr(10)
   cResult += "   Rate: " + LTrim(Str(Int(N_CONTROLS/t1))) + " controls/sec" + Chr(13)+Chr(10)
   cResult += Chr(13)+Chr(10)
   cResult += "Test 2: Set property " + LTrim(Str(N_PROPSETS)) + " times (C++ bridge)" + Chr(13)+Chr(10)
   cResult += "   Time: " + LTrim(Str(t2, 10, 4)) + " sec" + Chr(13)+Chr(10)
   cResult += "   Rate: " + LTrim(Str(Int(N_PROPSETS/t2))) + " sets/sec" + Chr(13)+Chr(10)
   cResult += Chr(13)+Chr(10)
   cResult += "Test 3: Get property " + LTrim(Str(N_PROPGETS)) + " times (C++ bridge)" + Chr(13)+Chr(10)
   cResult += "   Time: " + LTrim(Str(t3, 10, 4)) + " sec" + Chr(13)+Chr(10)
   cResult += "   Rate: " + LTrim(Str(Int(N_PROPGETS/t3))) + " gets/sec" + Chr(13)+Chr(10)
   cResult += Chr(13)+Chr(10)
   cResult += "Test 4: Create 200 controls visual (Label+Button)" + Chr(13)+Chr(10)
   cResult += "   Time: " + LTrim(Str(t4, 10, 4)) + " sec" + Chr(13)+Chr(10)
   cResult += Chr(13)+Chr(10)
   cResult += "Test 5: Create " + LTrim(Str(N_CONTROLS)) + " buttons (Harbour OOP wrapper)" + Chr(13)+Chr(10)
   cResult += "   Time: " + LTrim(Str(t5, 10, 4)) + " sec" + Chr(13)+Chr(10)
   cResult += "   Rate: " + LTrim(Str(Int(N_CONTROLS/t5))) + " controls/sec" + Chr(13)+Chr(10)
   cResult += Chr(13)+Chr(10)
   cResult += "Test 6: Get 2 properties " + LTrim(Str(N_PROPGETS)) + " times (Harbour OOP)" + Chr(13)+Chr(10)
   cResult += "   Time: " + LTrim(Str(t6, 10, 4)) + " sec" + Chr(13)+Chr(10)
   cResult += "   Rate: " + LTrim(Str(Int(N_PROPGETS*2/t6))) + " gets/sec" + Chr(13)+Chr(10)

   MemoWrit( "bench_results.txt", cResult )
   W32_MsgBox( cResult, "Benchmark Results" )

return nil

// Framework
#include "c:\ide\harbour\classes.prg"

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>
HB_FUNC( W32_MSGBOX )
{
   MessageBoxA( NULL, hb_parc(1), hb_parc(2), MB_OK );
}
#pragma ENDDUMP
