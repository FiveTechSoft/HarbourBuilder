---
name: Auto-run to breakpoint
description: Implement IDE_DEBUGRUNTOBREAK function for automatic execution until first breakpoint
type: feature
---

# Auto-run to Breakpoint Feature Design

## Overview
Add new debugger functions `IDE_DEBUGRUNTOBREAK` and `IDE_DEBUGRUNTOBREAK2` that start debug sessions in `DBG_RUNNING` mode instead of `DBG_STEPPING`, allowing programs to execute automatically until the first breakpoint is hit.

## Background
Current debugger implementation:
- `IDE_DEBUGSTART` starts in `DBG_STEPPING` mode (pauses on first line)
- `IDE_DEBUGSTART2` (socket-based) also starts in `DBG_STEPPING`
- Debug hook logic: when `s_dbgState == DBG_RUNNING && !DbgIsBreakpoint(...)` continues execution
- Need ability to run directly to breakpoints without manual "Run" click after start

## Requirements
1. **New Harbour functions:**
   - `IDE_DEBUGRUNTOBREAK(cHrbFile, bOnPause)` - for .hrb execution
   - `IDE_DEBUGRUNTOBREAK2(cExePath, bOnPause)` - for socket-based debugging

2. **Behavior:**
   - Start debug session in `DBG_RUNNING` state
   - Install debug hook `hb_dbg_SetEntry(IDE_DebugHook)`
   - Execute program (HRB or external executable)
   - Automatically pause at first breakpoint encountered
   - If no breakpoints set, run to completion

3. **Integration:**
   - Reuse existing debug infrastructure (breakpoint array, hook, UI)
   - Maintain compatibility with current debug panel and toolbar

## Design Details

### Function Signatures
```c
HB_FUNC( IDE_DEBUGRUNTOBREAK )  // (cHrbFile, bOnPause) -> .T./.F.
HB_FUNC( IDE_DEBUGRUNTOBREAK2 ) // (cExePath, bOnPause) -> .T./.F.
```

### Implementation Plan
1. **Copy `IDE_DEBUGSTART` logic** with one change: `s_dbgState = DBG_RUNNING`
2. **Copy `IDE_DEBUGSTART2` logic** with same change
3. **Add to header/exports** for Harbour accessibility
4. **Optional UI integration**: New toolbar button or menu option (could be "Run to breakpoint" button alongside existing "Run")

### Code Changes
**File: `source/backends/cocoa/cocoa_editor.mm`**
- Add `IDE_DEBUGRUNTOBREAK` function after `IDE_DEBUGSTART`
- Add `IDE_DEBUGRUNTOBREAK2` function after `IDE_DEBUGSTART2`
- Update function declarations in appropriate header

**File: `source/cpp/hbbridge.cpp`** (if Windows needs same feature)
- Add corresponding Windows implementations

### Edge Cases
1. **No breakpoints**: Program runs to completion, debug session ends
2. **Breakpoint at first line**: Should pause immediately (hook checks breakpoint before state)
3. **Multiple breakpoints**: Pauses at first encountered, respects `DBG_RUNNING` logic
4. **Error handling**: Same as existing debug start functions

## Testing
1. Create test .hrb with breakpoints at various lines
2. Call `IDE_DEBUGRUNTOBREAK` and verify:
   - Program doesn't pause on first line
   - Pauses at first breakpoint
   - UI shows paused state
3. Test without breakpoints (should run to completion)
4. Test socket-based version with external executable

## Why This Design?
- **Minimal changes**: Reuses 95% of existing debug infrastructure
- **Clear separation**: New functions for new behavior, doesn't break existing `IDE_DEBUGSTART`
- **Consistent API**: Follows same pattern as existing debug functions
- **Flexible**: Can be called from Harbour code or UI buttons

## Success Criteria
- Program starts and runs automatically to first breakpoint
- No manual "Run" button click required after debug start
- Works for both .hrb and external executable debugging
- Maintains all existing debug functionality