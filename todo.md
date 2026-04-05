# HbBuilder TODO

## Fixed
- [x] Inspector event double-click: cursor was not positioned correctly on new handler code. Cause: CRLF (`Chr(13)+Chr(10)`) was used for line breaks but Scintilla on macOS converts to LF internally, making the byte offset calculation wrong. Fix: use `Chr(10)` in `OnEventDblClick()` in `hbbuilder_macos.prg`.
- [x] Inspector window focus: when clicking the inspector window, only that window came to front while the rest of the IDE stayed behind. Fix: added `NSWindowDelegate` with `windowDidBecomeKey:` to `HBInspectorDelegate` in `cocoa_inspector.m` — brings all visible IDE windows to front when the inspector is activated.
- [x] Run from .app bundle: paths to backends, scintilla, and framework files were wrong when running from the macOS bundle. Fix: detect bundle via `Resources/backends` and resolve paths accordingly in `TBRun()` and `TBDebugRun()` in `hbbuilder_macos.prg`.
- [x] Run link failure: `gtgui.o` was compiled from `~/harbour/src/rtl/gtgui/gtgui.c` which doesn't exist in Harbour install. Fix: removed gtgui compile/link step, added `HB_GT_GUI_DEFAULT` stub to `gt_dummy.c`.
- [x] Event handler cursor positioning: after double-clicking an event in inspector, cursor landed at correct line but column 0. Fix: `CodeEditorGotoFunction()` in `cocoa_editor.mm` now adds 3 to position for the indent. Also added re-positioning call after `SyncDesignerToCode()` in `OnEventDblClick()`.

- [x] Project load does not restore visual controls. Implemented `RestoreFormFromCode()` — parses .prg code to recreate controls (Button, Label, Edit, CheckBox, ComboBox, GroupBox, ListBox, RadioButton) with correct position, size, text and name. Called from `TBOpen()` after `CreateDesignForm()`.

- [x] Non-visual components (Timer, OpenAI, Thread, SQLite, etc.) now serialize as `COMPONENT ::oName TYPE nType OF Self` in `RegenerateFormCode()` and restore via `UI_DropNonVisual()` in `RestoreFormFromCode()`.

- [x] Loading a project shows both the default startup form AND the loaded project forms. Fix: `TBOpen()` now calls `Close()` + `Destroy()` on each existing form before loading (was only calling `Destroy()` which didn't close the window).

- [x] TMemo not appearing at runtime. Cause: no `MEMO` command in `hbbuilder.ch`, no TMemo class in `classes.prg`, no `UI_MemoNew` in cocoa_core.m, and `RegenerateFormCode` sent Memo to the `otherwise` (comment) case. Fix: added all four pieces + parser in `RestoreFormFromCode`.

## Open
- [ ] Before loading a project (`TBOpen`), ask the user if they want to save the current work. If the project has unsaved changes (modified code, added controls, etc.), prompt "Save current project before opening?" with Yes/No/Cancel. Cancel aborts the open.
