# HbBuilder TODO

## Fixed
- [x] Inspector event double-click: cursor was not positioned correctly on new handler code. Cause: CRLF (`Chr(13)+Chr(10)`) was used for line breaks but Scintilla on macOS converts to LF internally, making the byte offset calculation wrong. Fix: use `Chr(10)` in `OnEventDblClick()` in `hbbuilder_macos.prg`.
- [x] Inspector window focus: when clicking the inspector window, only that window came to front while the rest of the IDE stayed behind. Fix: added `NSWindowDelegate` with `windowDidBecomeKey:` to `HBInspectorDelegate` in `cocoa_inspector.m` — brings all visible IDE windows to front when the inspector is activated.
- [x] Run from .app bundle: paths to backends, scintilla, and framework files were wrong when running from the macOS bundle. Fix: detect bundle via `Resources/backends` and resolve paths accordingly in `TBRun()` and `TBDebugRun()` in `hbbuilder_macos.prg`.
- [x] Run link failure: `gtgui.o` was compiled from `~/harbour/src/rtl/gtgui/gtgui.c` which doesn't exist in Harbour install. Fix: removed gtgui compile/link step, added `HB_GT_GUI_DEFAULT` stub to `gt_dummy.c`.
- [x] Event handler cursor positioning: after double-clicking an event in inspector, cursor landed at correct line but column 0. Fix: `CodeEditorGotoFunction()` in `cocoa_editor.mm` now adds 3 to position for the indent. Also added re-positioning call after `SyncDesignerToCode()` in `OnEventDblClick()`.
