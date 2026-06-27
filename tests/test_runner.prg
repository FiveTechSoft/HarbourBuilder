/* Minimal test runner helpers — each test .prg links this + hbbuilder_common.prg */

STATIC s_nFailures := 0

INIT PROCEDURE TestInit
   s_nFailures := 0
RETURN

PROCEDURE TestFail( cFile, nLine, cMsg )
   s_nFailures++
   ? "FAIL [" + cFile + ":" + LTrim( Str( nLine ) ) + "] " + cMsg
RETURN

FUNCTION TestPass( cName )
   IF s_nFailures > 0
      ? "FAILED: " + cName + " (" + LTrim( Str( s_nFailures ) ) + " assertion failures)"
      RETURN 1
   ENDIF
   ? "OK: " + cName
RETURN 0