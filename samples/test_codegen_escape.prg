/* Quick unit check for hbbuilder_common.prg
 * Full suite: run_tests.bat / run_tests.sh in project root */
#include "../include/hbide.ch"

REQUEST HB_EscapeHarbourStr
REQUEST HB_QHarbourStr
REQUEST HB_NormalizeCtrlType
REQUEST ComponentTypeFromName
REQUEST IsNonVisual

FUNCTION Main()
   LOCAL c, cQ

   c := 'Say "Hello"' + Chr(13) + Chr(10) + 'path\file'
   cQ := HB_QHarbourStr( c )

   IF HB_EscapeHarbourStr( "" ) != ""
      ? "FAIL: empty string"
      RETURN 1
   ENDIF

   IF ! ( '"' $ cQ )
      ? "FAIL: missing quotes"
      RETURN 1
   ENDIF

   IF ! ( '\"' $ cQ )
      ? "FAIL: inner quote not escaped"
      RETURN 1
   ENDIF

   IF HB_NormalizeCtrlType( CT_POPUPMENU_LEGACY ) != CT_POPUPMENU
      ? "FAIL: legacy popup type"
      RETURN 1
   ENDIF

   IF HB_NormalizeCtrlType( CT_BAND ) != CT_BAND
      ? "FAIL: band type must stay 132"
      RETURN 1
   ENDIF

   ? "OK: codegen escape tests passed"
RETURN 0