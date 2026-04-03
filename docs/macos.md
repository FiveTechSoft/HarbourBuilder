# macOS Build & Review Guide

## Prerequisites

- **Xcode Command Line Tools** -- install with `xcode-select --install`
- **Harbour 3.2** compiled for darwin/clang

## Build

```bash
cd samples
./build_mac.sh
```

Build output is a native `.app` bundle produced by `build_mac.sh`.

## Architecture

| Layer | File |
|-------|------|
| Backend (Objective-C, Cocoa/AppKit) | `backends/cocoa/cocoa_core.m` |
| IDE entry point | `samples/hbbuilder_macos.prg` |
| Inspector (native) | `backends/cocoa/cocoa_inspector.m` |
| Inspector (Harbour) | `harbour/inspector_mac.prg` |

## Native Widgets

The Cocoa backend wraps the following AppKit classes:

NSTextField, NSButton, NSTableView, NSOutlineView, NSDatePicker, NSSlider, NSTabView, NSScrollView, NSTextView, NSProgressIndicator, NSBox, NSImageView

## Palette & Controls

- **14 palette tabs** (same set as Windows)
- **109 controls** (same set as Windows)

## Menus

All menus are synced with the Windows version:

File, Edit, Search, View, Project, Run, Component, Tools, Help

## Implemented Features

- Palette drop
- Two-way sync (form <-> code)
- Code editor
- Project save / open / build / run

## Stub Features (show MsgInfo)

- Debugger panel
- AI assistant panel
- Project inspector
- Editor colors

## Dark Mode

macOS handles dark mode automatically via `NSAppearance`. No extra code is required.

## Font

Helvetica Neue, 12 pt.

## Known Issues to Review

- Ensure all 109 controls create correctly in `cocoa_core.m` `createViewInParent`.

## Reviewer Checklist

- [ ] Xcode Command Line Tools installed
- [ ] Harbour 3.2 (darwin/clang) available on PATH
- [ ] `build_mac.sh` completes without errors
- [ ] `.app` bundle launches and main window appears
- [ ] All 14 palette tabs are visible
- [ ] Dropping each of the 109 controls onto the form succeeds
- [ ] Two-way sync: editing a property updates the code and vice-versa
- [ ] File / Open loads a saved project correctly
- [ ] File / Save writes the project without errors
- [ ] Build / Run compiles and launches the sample project
- [ ] All nine menus are present and match the Windows version
- [ ] Dark mode: toggle System Preferences and verify the IDE adapts
- [ ] Stub features show MsgInfo when invoked
- [ ] Inspector displays and updates properties for selected controls
