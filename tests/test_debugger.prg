// test_debugger.prg - Unit tests for the integrated debugger engine
//
// Tests the IDE_Debug* HB_FUNC interface without GUI dependencies.
// Run: cd tests && ../samples/build_test_debugger.sh
//
// Each test prints PASS or FAIL. Exit code 0 = all passed.

#include "../harbour/hbbuilder.ch"

static nTests    := 0
static nPassed   := 0
static nFailed   := 0
static lVerbose  := .T.

function Main()

   ? "============================================"
   ? "HarbourBuilder Debugger - Unit Test Suite"
   ? "============================================"
   ?

   // === Group 1: State machine ===
   TestGroup( "Debugger State Machine" )
   Test_InitialState()
   Test_StateAfterStop()

   // === Group 2: Breakpoint management ===
   TestGroup( "Breakpoint Management" )
   Test_AddBreakpoint()
   Test_ClearBreakpoints()
   Test_MaxBreakpoints()

   // === Group 3: .hrb compilation ===
   TestGroup( "HRB Compilation" )
   Test_CompileSimpleHrb()
   Test_CompileWithDebugInfo()
   Test_CompileInvalidCode()

   // === Group 4: Debug execution ===
   // NOTE: HRB pcode does NOT trigger hb_dbg_SetEntry hook.
   // Debug hooks only fire for compiled C code linked into the executable.
   // These tests verify the API doesn't crash; actual debugging requires
   // the pipe-based debug agent approach (compile user code as executable).
   TestGroup( "Debug Execution (HRB API)" )
   Test_DebugStartStop()
   Test_HrbRunsToCompletion()

   // === Group 5: Variable inspection ===
   TestGroup( "Variable Inspection" )
   Test_GetLocalsFromSelf()

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
// Group 1: State machine tests
// =========================================================

static function Test_InitialState()
   // Debugger should be idle when not debugging
   AssertEquals( IDE_DebugGetState(), 0, "Initial state is DBG_IDLE (0)" )
return nil

static function Test_StateAfterStop()
   // Stop when idle should stay idle
   IDE_DebugStop()
   // State should still be idle (stop on idle = no-op since state was already 0)
   // Actually IDE_DebugStop sets to 5 if state != 0, so idle stays idle
   AssertEquals( IDE_DebugGetState(), 0, "Stop when idle keeps state idle" )
return nil

// =========================================================
// Group 2: Breakpoint management tests
// =========================================================

static function Test_AddBreakpoint()
   IDE_DebugClearBreakpoints()
   IDE_DebugAddBreakpoint( "Form1.prg", 10 )
   IDE_DebugAddBreakpoint( "Form1.prg", 25 )
   IDE_DebugAddBreakpoint( "Project1.prg", 5 )
   Assert( .T., "Add 3 breakpoints without crash" )
return nil

static function Test_ClearBreakpoints()
   IDE_DebugAddBreakpoint( "test.prg", 1 )
   IDE_DebugClearBreakpoints()
   Assert( .T., "Clear breakpoints without crash" )
return nil

static function Test_MaxBreakpoints()
   local i
   IDE_DebugClearBreakpoints()
   // Add up to max (64)
   for i := 1 to 64
      IDE_DebugAddBreakpoint( "stress.prg", i )
   next
   // 65th should be silently ignored (no crash)
   IDE_DebugAddBreakpoint( "overflow.prg", 999 )
   Assert( .T., "64 breakpoints + 1 overflow handled without crash" )
   IDE_DebugClearBreakpoints()
return nil

// =========================================================
// Group 3: .hrb compilation tests
// =========================================================

static function Test_CompileSimpleHrb()
   local cDir := "/tmp/hbtest_dbg"
   local cPrg, cCmd, cOutput
   local cHbBin := GetHbBin()

   GTK_ShellExec( "mkdir -p " + cDir )

   // Write a minimal test program
   cPrg := 'function Main()' + Chr(10) + ;
           '   local x := 42' + Chr(10) + ;
           '   return nil' + Chr(10)
   MemoWrit( cDir + "/simple.prg", cPrg )

   // Compile to .hrb
   cCmd := cHbBin + "/harbour " + cDir + "/simple.prg -gh -n -w -q" + ;
           " -o" + cDir + "/simple.hrb 2>&1"
   cOutput := GTK_ShellExec( cCmd )

   Assert( File( cDir + "/simple.hrb" ), "Simple .prg compiles to .hrb" )
   Assert( ! ("Error" $ cOutput), "No errors in compilation output" )
return nil

static function Test_CompileWithDebugInfo()
   local cDir := "/tmp/hbtest_dbg"
   local cPrg, cCmd, cOutput
   local cHbBin := GetHbBin()

   cPrg := 'function Main()' + Chr(10) + ;
           '   local x := 42' + Chr(10) + ;
           '   local y := "hello"' + Chr(10) + ;
           '   ? x, y' + Chr(10) + ;
           '   return nil' + Chr(10)
   MemoWrit( cDir + "/debug_info.prg", cPrg )

   // Compile with -b (debug info) + -gh (hrb)
   cCmd := cHbBin + "/harbour " + cDir + "/debug_info.prg -gh -b -n -w -q" + ;
           " -o" + cDir + "/debug_info.hrb 2>&1"
   cOutput := GTK_ShellExec( cCmd )

   Assert( File( cDir + "/debug_info.hrb" ), ".prg with -b -gh produces .hrb" )
   Assert( ! ("Error" $ cOutput), "No errors with debug info compilation" )
return nil

static function Test_CompileInvalidCode()
   local cDir := "/tmp/hbtest_dbg"
   local cPrg, cCmd, cOutput
   local cHbBin := GetHbBin()

   // Invalid syntax
   cPrg := 'function Main(' + Chr(10) + ;
           '   invalid syntax here %%% ' + Chr(10)
   MemoWrit( cDir + "/invalid.prg", cPrg )

   cCmd := cHbBin + "/harbour " + cDir + "/invalid.prg -gh -n -w -q" + ;
           " -o" + cDir + "/invalid.hrb 2>&1"
   cOutput := GTK_ShellExec( cCmd )

   Assert( "Error" $ cOutput .or. "error" $ cOutput, ;
           "Invalid code produces compilation error" )
return nil

// =========================================================
// Group 4: Debug execution tests
// =========================================================

static function Test_DebugStartStop()
   local cDir := "/tmp/hbtest_dbg"
   local cPrg, cCmd, cHbBin := GetHbBin()
   local lStarted

   cPrg := 'function Main()' + Chr(10) + ;
           '   return nil' + Chr(10)
   MemoWrit( cDir + "/run_test.prg", cPrg )
   cCmd := cHbBin + "/harbour " + cDir + "/run_test.prg -gh -b -n -w -q" + ;
           " -o" + cDir + "/run_test.hrb 2>&1"
   GTK_ShellExec( cCmd )

   if ! File( cDir + "/run_test.hrb" )
      Assert( .F., "DebugStart - .hrb not compiled" )
      return nil
   endif

   lStarted := IDE_DebugStart( cDir + "/run_test.hrb", ;
      { |cMod, nLine| IDE_DebugStop() } )

   Assert( lStarted, "IDE_DebugStart returns .T. for valid .hrb" )
   AssertEquals( IDE_DebugGetState(), 0, "State returns to IDLE after execution" )
return nil

static function Test_HrbRunsToCompletion()
   local cDir := "/tmp/hbtest_dbg"
   local cPrg, cCmd, cHbBin := GetHbBin()

   cPrg := 'function Main()' + Chr(10) + ;
           '   local x := 1' + Chr(10) + ;
           '   x := x + 1' + Chr(10) + ;
           '   return nil' + Chr(10)
   MemoWrit( cDir + "/complete_test.prg", cPrg )
   cCmd := cHbBin + "/harbour " + cDir + "/complete_test.prg -gh -n -w -q" + ;
           " -o" + cDir + "/complete_test.hrb 2>&1"
   GTK_ShellExec( cCmd )

   if ! File( cDir + "/complete_test.hrb" )
      Assert( .F., "HrbRunsToCompletion - .hrb not compiled" )
      return nil
   endif

   // HRB should execute and return without crash
   IDE_DebugStart( cDir + "/complete_test.hrb", ;
      { |cMod, nLine| IDE_DebugStop() } )

   AssertEquals( IDE_DebugGetState(), 0, "HRB execution completes and returns to IDLE" )
return nil

// =========================================================
// Group 5: Variable inspection tests
// =========================================================

// Test IDE_DebugGetLocals on our own function's locals
static function Test_GetLocalsFromSelf()
   local nTestVar := 42
   local cTestStr := "hello"
   local aLocals

   // IDE_DebugGetLocals inspects locals at a given call stack level
   // Level 0 = current function. It may return empty if we're not in
   // a debug session, but it should not crash.
   aLocals := IDE_DebugGetLocals( 0 )
   Assert( ValType( aLocals ) == "A", "IDE_DebugGetLocals returns an array" )

   // Also test that it works with level 1
   aLocals := IDE_DebugGetLocals( 1 )
   Assert( ValType( aLocals ) == "A", "IDE_DebugGetLocals(1) returns an array" )

   // If it found locals, verify structure
   if Len( aLocals ) > 0
      Assert( Len( aLocals[1] ) == 3, "Each local entry has 3 fields (name, value, type)" )
   else
      Assert( .T., "IDE_DebugGetLocals returns empty array (no debug session - expected)" )
   endif
return nil

// =========================================================
// Helpers
// =========================================================

static function GetHbBin()
   local cHbDir := GetEnv( "HBDIR" )
   if Empty( cHbDir ); cHbDir := GetEnv( "HOME" ) + "/harbour"; endif
return cHbDir + "/bin/linux/gcc"

// MsgInfo stub for test context (no GUI)
function MsgInfo( cMsg, cTitle )
   ? "[MsgInfo] " + hb_DefaultValue( cTitle, "" ) + ": " + cMsg
return nil
