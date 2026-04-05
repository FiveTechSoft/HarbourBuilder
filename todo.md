# HbBuilder TODO

## Fixed
- [x] Inspector event double-click: cursor was not positioned correctly on new handler code. Cause: CRLF (`Chr(13)+Chr(10)`) was used for line breaks but Scintilla on macOS converts to LF internally, making the byte offset calculation wrong. Fix: use `Chr(10)` in `OnEventDblClick()` in `hbbuilder_macos.prg`.
- [x] Inspector window focus: when clicking the inspector window, only that window came to front while the rest of the IDE stayed behind. Fix: added `NSWindowDelegate` with `windowDidBecomeKey:` to `HBInspectorDelegate` in `cocoa_inspector.m` — brings all visible IDE windows to front when the inspector is activated.
