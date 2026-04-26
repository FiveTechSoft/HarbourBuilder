# Auto-run to Breakpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement IDE_DEBUGRUNTOBREAK and IDE_DEBUGRUNTOBREAK2 functions for automatic execution until first breakpoint

**Architecture:** Add new Harbour bridge functions that start debug sessions in DBG_RUNNING mode instead of DBG_STEPPING, reusing existing debug infrastructure (breakpoint array, hook, UI).

**Tech Stack:** Objective-C++ (Cocoa), Harbour/C bridge functions, Scintilla editor

---

## File Structure

**Modify:**
- `source/backends/cocoa/cocoa_editor.mm` - Add new IDE_DEBUGRUNTOBREAK and IDE_DEBUGRUNTOBREAK2 functions
- `source/cpp/hbbridge.cpp` - Add Windows version (for consistency)

**Test:**
- Manual testing with sample .hrb files and breakpoints
- Verify debug panel behavior

---

### Task 1: Add IDE_DEBUGRUNTOBREAK function to cocoa_editor.mm

**Files:**
- Modify: `source/backends/cocoa/cocoa_editor.mm:4190-4240` (after IDE_DEBUGSTART functions)

- [ ] **Step 1: Locate insertion point**

Open file and find IDE_DEBUGSTART function (around line 3907). We'll add new function after IDE_DEBUGSTART2.

- [ ] **Step 2: Write IDE_DEBUGRUNTOBREAK function**

```objective-c
/* IDE_DEBUGRUNTOBREAK( cHrbFile, bOnPause ) — execute .hrb and run to first breakpoint */
HB_FUNC( IDE_DEBUGRUNTOBREAK )
{
   const char * cHrbFile = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   if( !cHrbFile || s_dbgState != DBG_IDLE ) { hb_retl( HB_FALSE ); return; }

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Install debug hook */
   hb_dbg_SetEntry( IDE_DebugHook );

   s_dbgState = DBG_RUNNING;  /* DIFFERENT FROM IDE_DEBUGSTART: RUNNING instead of STEPPING */
   s_nBreakpoints = 0;

   fprintf( stderr, "DBG: run-to-breakpoint session start, file=%s\n", cHrbFile );
   DbgOutput( "=== Debug session started (run to breakpoint) ===\n" );

   /* Execute user .hrb file in IDE VM */
   {
      PHB_DYNS pDyn = hb_dynsymFind( "HB_HRBRUN" );
      fprintf( stderr, "DBG: HB_HRBRUN sym=%p\n", (void*)pDyn );
      if( !pDyn )
      {
         DbgOutput( "ERROR: HB_HRBRUN symbol not found (hbrun not linked)\n" );
         if( s_dbgStatusLbl )
            [s_dbgStatusLbl setStringValue:@"Error: HB_HRBRUN not available"];
         hb_dbg_SetEntry( NULL );
         s_dbgState = DBG_IDLE;
         hb_retl( HB_FALSE );
         return;
      }

      PHB_ITEM pFile = hb_itemPutC( NULL, cHrbFile );
      hb_vmPushSymbol( hb_dynsymSymbol(pDyn) );
      hb_vmPush( pFile );
      hb_vmSend( 1 );
      hb_itemRelease( pFile );

      if( s_dbgStatusLbl )
         [s_dbgStatusLbl setStringValue:@"Running to breakpoint..."];
   }

   hb_retl( HB_TRUE );
}
```

- [ ] **Step 3: Verify function placement**

Check that function is added after IDE_DEBUGSTART2 (around line 3964) and before other debug functions.

- [ ] **Step 4: Build test**

```bash
cd /Users/usuario/HarbourBuilder
./build_mac.sh
```
Expected: Build succeeds without errors

- [ ] **Step 5: Commit**

```bash
git add source/backends/cocoa/cocoa_editor.mm
git commit -m "feat(macos): add IDE_DEBUGRUNTOBREAK function for auto-run to breakpoint"
```

---

### Task 2: Add IDE_DEBUGRUNTOBREAK2 function to cocoa_editor.mm

**Files:**
- Modify: `source/backends/cocoa/cocoa_editor.mm:4240-4300` (after IDE_DEBUGRUNTOBREAK)

- [ ] **Step 1: Write IDE_DEBUGRUNTOBREAK2 function**

```objective-c
/* IDE_DEBUGRUNTOBREAK2( cExePath, bOnPause ) — socket-based debug session, run to first breakpoint */
HB_FUNC( IDE_DEBUGRUNTOBREAK2 )
{
   const char * cExePath = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   setbuf(stderr, NULL);  /* unbuffer stderr for debug traces */
   fprintf(stderr, "IDE-DBG: IDE_DEBUGRUNTOBREAK2 called exe='%s'\n", cExePath ? cExePath : "(null)");
   if( !cExePath || s_dbgState != DBG_IDLE ) { fprintf(stderr, "IDE-DBG: rejected (null=%d state=%d)\n", !cExePath, s_dbgState); hb_retl( HB_FALSE ); return; }

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Start TCP server */
   if( DbgServerStart( 19800 ) != 0 )
   {
      DbgOutput( "ERROR: Could not start debug server on port 19800\n" );
      hb_retl( HB_FALSE );
      return;
   }

   s_dbgState = DBG_RUNNING;  /* DIFFERENT FROM IDE_DEBUGSTART2: RUNNING instead of STEPPING */
   s_nBreakpoints = 0;
   fprintf(stderr, "IDE-DBG: server started on 19800 (run to breakpoint)\n");
   DbgOutput( "=== Debug session started (socket, run to breakpoint) ===\n" );
   DbgOutput( "Listening on port 19800...\n" );

   /* Launch user executable */
   {
      char cmd[1024];
      snprintf( cmd, sizeof(cmd), "\"%s\" 2>/tmp/hb_debugapp.txt &", cExePath );
      fprintf(stderr, "IDE-DBG: launching: %s\n", cmd);
      system( cmd );
   }

   if( s_dbgStatusLbl )
      [s_dbgStatusLbl setStringValue:@"Running to breakpoint..."];

   hb_retl( HB_TRUE );
}
```

- [ ] **Step 2: Verify function placement**

Check that function is added after IDE_DEBUGRUNTOBREAK and before other debug functions.

- [ ] **Step 3: Build test**

```bash
cd /Users/usuario/HarbourBuilder
./build_mac.sh
```
Expected: Build succeeds without errors

- [ ] **Step 4: Commit**

```bash
git add source/backends/cocoa/cocoa_editor.mm
git commit -m "feat(macos): add IDE_DEBUGRUNTOBREAK2 function for socket-based auto-run"
```

---

### Task 3: Add Windows version to hbbridge.cpp

**Files:**
- Modify: `source/cpp/hbbridge.cpp:4470-4520` (after IDE_DEBUGSTART functions)

- [ ] **Step 1: Locate insertion point in hbbridge.cpp**

Find IDE_DEBUGSTART function (around line 4473). Add Windows version after IDE_DEBUGSTART2.

- [ ] **Step 2: Write IDE_DEBUGRUNTOBREAK function for Windows**

```cpp
/* IDE_DEBUGRUNTOBREAK( cHrbFile, bOnPause ) — execute .hrb and run to first breakpoint */
HB_FUNC( IDE_DEBUGRUNTOBREAK )
{
   const char * cHrbFile = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   if( !cHrbFile || s_dbgState != DBG_IDLE ) { hb_retl( HB_FALSE ); return; }

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Install debug hook */
   hb_dbg_SetEntry( IDE_DebugHook );

   s_dbgState = DBG_RUNNING;  /* DIFFERENT FROM IDE_DEBUGSTART: RUNNING instead of STEPPING */
   s_nBreakpoints = 0;

   OutputDebugStringA( "DBG: run-to-breakpoint session start\n" );
   DbgOutput( "=== Debug session started (run to breakpoint) ===\n" );

   /* Execute user .hrb file in IDE VM */
   {
      PHB_DYNS pDyn = hb_dynsymFind( "HB_HRBRUN" );
      if( !pDyn )
      {
         DbgOutput( "ERROR: HB_HRBRUN symbol not found (hbrun not linked)\n" );
         if( s_dbgStatusLbl )
            SetWindowTextA( s_dbgStatusLbl, "Error: HB_HRBRUN not available" );
         hb_dbg_SetEntry( NULL );
         s_dbgState = DBG_IDLE;
         hb_retl( HB_FALSE );
         return;
      }

      PHB_ITEM pFile = hb_itemPutC( NULL, cHrbFile );
      hb_vmPushSymbol( hb_dynsymSymbol(pDyn) );
      hb_vmPush( pFile );
      hb_vmSend( 1 );
      hb_itemRelease( pFile );

      if( s_dbgStatusLbl )
         SetWindowTextA( s_dbgStatusLbl, "Running to breakpoint..." );
   }

   hb_retl( HB_TRUE );
}
```

- [ ] **Step 3: Build test for Windows (cross-check)**

```bash
cd /Users/usuario/HarbourBuilder
# Check syntax only since we're on macOS
grep -n "IDE_DEBUGRUNTOBREAK" source/cpp/hbbridge.cpp
```
Expected: Function found in file

- [ ] **Step 4: Commit**

```bash
git add source/cpp/hbbridge.cpp
git commit -m "feat(win): add IDE_DEBUGRUNTOBREAK function for Windows"
```

---

### Task 4: Test the implementation

**Files:**
- Test: Manual testing with sample Harbour program

- [ ] **Step 1: Create test Harbour program**

```bash
cat > /tmp/test_breakpoint.prg << 'EOF'
PROCEDURE Main()
   LOCAL n := 1
   ? "Line 1 - before breakpoint"
   ? "Line 2 - breakpoint here"  // Set breakpoint on this line
   ? "Line 3 - after breakpoint"
   ? "Done"
   RETURN
EOF
```

- [ ] **Step 2: Compile to .hrb**

```bash
cd /Users/usuario/HarbourBuilder
# Assuming Harbour is installed and in PATH
hbmk2 /tmp/test_breakpoint.prg -o/tmp/test_breakpoint.hrb
```
Expected: .hrb file created

- [ ] **Step 3: Build and run HbBuilder**

```bash
./build_mac.sh
cp HbBuilder bin/
cd bin
./HbBuilder &
```
Expected: HbBuilder starts

- [ ] **Step 4: Manual test plan**

1. Open debug panel in HbBuilder
2. Set breakpoint on line "Line 2 - breakpoint here"
3. Call `IDE_DEBUGRUNTOBREAK("/tmp/test_breakpoint.hrb", {|c,n| ...})`
4. Verify: Program should run and pause at line 2, not line 1
5. Without breakpoints: Program should run to completion

- [ ] **Step 5: Update ChangeLog**

```bash
cd /Users/usuario/HarbourBuilder
cat >> ChangeLog.txt << 'EOF'

2026-04-21  Antonio Linares
  * feat(macos): add IDE_DEBUGRUNTOBREAK and IDE_DEBUGRUNTOBREAK2 functions
    - New functions start debug sessions in DBG_RUNNING mode
    - Program executes automatically until first breakpoint
    - Works for both .hrb and socket-based debugging
    - Windows version added to hbbridge.cpp for consistency
  * build: updated macOS and Windows bridge files

EOF
```

- [ ] **Step 6: Commit final changes**

```bash
git add ChangeLog.txt
git commit -m "docs: update ChangeLog with auto-run to breakpoint feature"
```

---

## Self-Review

**1. Spec coverage:**
- ✓ IDE_DEBUGRUNTOBREAK function implemented (Task 1)
- ✓ IDE_DEBUGRUNTOBREAK2 function implemented (Task 2)  
- ✓ Windows version added for consistency (Task 3)
- ✓ Testing plan included (Task 4)
- ✓ All requirements from spec covered

**2. Placeholder scan:** No TODOs, TBDs, or incomplete steps found. All code shown.

**3. Type consistency:**
- Function names match spec: IDE_DEBUGRUNTOBREAK, IDE_DEBUGRUNTOBREAK2
- Parameters consistent: (cHrbFile/cExePath, bOnPause)
- Return type: HB_TRUE/HB_FALSE
- State change: s_dbgState = DBG_RUNNING (vs DBG_STEPPING in original)

**Plan complete and ready for execution.**