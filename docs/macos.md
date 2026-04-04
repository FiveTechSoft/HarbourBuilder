# macOS Build & Review Guide

## Prerequisites

- **Xcode Command Line Tools** -- install with `xcode-select --install`
- **Harbour 3.2** compiled for darwin/clang

## Build

```bash
cd samples
./build_mac.sh
```

On first build, Scintilla and Lexilla are compiled as static libraries from source in `resources/scintilla_src/`. Build output is a native `.app` bundle.

## Architecture

| Layer | File | Description |
|-------|------|-------------|
| Backend (Objective-C, Cocoa) | `backends/cocoa/cocoa_core.m` | Controls, forms, dialogs, platform API |
| Scintilla editor (Obj-C++) | `backends/cocoa/cocoa_editor.mm` | 1631 lines: Scintilla, debugger, panels |
| IDE entry point | `samples/hbbuilder_macos.prg` | 1400+ lines: 53 menus, 42 helper functions |
| Inspector (native) | `backends/cocoa/cocoa_inspector.m` | Property/Event inspector |
| Inspector (Harbour) | `harbour/inspector.prg` | Inspector OOP layer |

## Code Editor: Scintilla 5.5.3

The editor uses **Scintilla** statically linked via `libscintilla.a` + `liblexilla.a`:

- C++ lexer via Lexilla `CreateLexer("cpp")` for Harbour syntax
- VS Code Dark+ color theme: keywords (blue, bold), commands (teal), comments (green, italic), strings (orange), numbers (light green), preprocessor (magenta)
- Line numbers margin + code folding margin (box style, Harbour-aware)
- Indentation guides, UTF-8, Menlo 15pt font
- Find/Replace via NSTextFinder (Cmd+F / Cmd+H)
- Auto-complete popup (Cmd+Space) with 150+ Harbour keywords and functions
- Auto-indent on Enter, toggle comment (Cmd+/), duplicate line (Cmd+Shift+D), delete line (Cmd+Shift+K)
- Status bar: Ln, Col, INS/OVR, line count, char count, UTF-8
- 26 CodeEditor HB_FUNCs (most of any platform)

## Menus (53 items, 100% functional, zero stubs)

macOS has the **most complete menu set** of all three platforms:

| Menu | Items | Key features |
|------|-------|--------------|
| File | 6 | New, New Form, Open, Save, Save As, Exit |
| Edit | 5 | Undo, Redo, Cut, Copy, Paste (all via Scintilla) |
| Search | 7 | Find, Replace, Find Next, Find Previous, Auto-Complete |
| View | 5 | Forms, Code Editor, Inspector, Project Inspector, Debugger |
| Project | 3 | Add to Project, Remove from Project, Options |
| Run | 8 | Run, Debug, Continue, Step Into, Step Over, Stop, Toggle/Clear Breakpoints |
| Format | 8 | Align Left/Right/Top/Bottom, Center H/V, Space Evenly H/V |
| Component | 2 | Install Component, New Component |
| Tools | 3 | Editor Colors, Environment Options, AI Assistant |
| Help | 4 | Documentation, Quick Start, Controls Reference, About |

## Toolbar (9 buttons, single row)

New, Open, Save | Cut, Copy, Paste | Undo, Redo | Run

All buttons functional with original project icons.

## IDE Panels & Dialogs (all fully implemented)

| Panel | Description |
|-------|-------------|
| **Debugger** | 5-tab panel (Watch, Locals, Call Stack, Breakpoints, Output). NSTabView with NSTableView per tab. Dark Aqua appearance. |
| **AI Assistant** | Ollama chat with NSPopUpButton model selector, async HTTP via NSURLSession, NSJSONSerialization parsing. |
| **Project Inspector** | NSOutlineView with tree hierarchy. |
| **Editor Colors** | Modal dialog with 4 presets (Dark/Light/Monokai/Solarized), live Scintilla style application. |
| **Project Options** | Modal dialog with NSTabView (4 tabs: Harbour/C Compiler/Linker/Directories). |

## Integrated Debugger

Same architecture as Linux -- runs user code inside the IDE process via `.hrb` bytecode:

1. `harbour -gh -b` compiles to portable bytecode with debug info
2. `hb_hrbRun()` executes within the IDE's Harbour VM
3. `hb_dbg_SetEntry()` hook intercepts source lines
4. Debug panel updates Locals and Call Stack in real-time
5. OnDebugPause callback syncs IDE state

## Dark Mode

- **App-wide**: `MAC_SetAppDarkMode(.T.)` sets `NSAppearanceNameDarkAqua` on startup
- **Per-window**: Each panel window explicitly sets dark appearance
- **Scintilla**: 4 color presets (Dark, Light, Monokai, Solarized) applied via SCI_STYLESETFORE/BACK
- Toggles automatically with macOS system appearance

## Format > Align Controls (8 modes)

Select multiple controls on the form designer, then use Format menu:
- Align Left / Right / Top / Bottom
- Center Horizontally / Vertically
- Space Evenly Horizontal / Vertical

## Build Pipeline

The `build_mac.sh` script performs a 7-step compile-link-bundle process:
1. Compile Harbour .prg to .c
2. Compile .c to .o (clang -O2)
3. Compile cocoa_core.m (Objective-C)
4. Compile cocoa_editor.mm (Objective-C++ -std=c++17)
5. Link with Harbour VM + Cocoa framework + Scintilla static libs
6. Create .app bundle structure
7. Launch via `open` command

## Native Widgets

NSTextField, NSButton, NSTableView, NSOutlineView, NSDatePicker, NSSlider, NSTabView, NSScrollView, NSProgressIndicator, NSBox, NSImageView, and ScintillaView (code editor).

## Palette & Controls

- **14 palette tabs** (same set across all platforms)
- **109 controls** (same set across all platforms)
- First tab named **"Cocoa"**

## Reviewer Checklist

- [ ] Xcode Command Line Tools installed
- [ ] Harbour 3.2 (darwin/clang) available
- [ ] `build_mac.sh` completes without errors (auto-builds Scintilla static libs)
- [ ] `.app` bundle launches with main window
- [ ] Scintilla editor opens with syntax highlighting and dark theme
- [ ] All 14 palette tabs visible, 109 controls droppable
- [ ] Two-way sync: editing property updates code and vice-versa
- [ ] File > Open/Save works correctly
- [ ] Run > Run compiles, links, creates .app bundle, launches
- [ ] Run > Debug opens debugger panel and loads .hrb
- [ ] All 53 menu items are functional (zero stubs)
- [ ] Debugger panel shows 5 tabs
- [ ] AI Assistant connects to Ollama
- [ ] Format > Align controls works with multi-selection
- [ ] Editor Colors > preset buttons change Scintilla theme live
- [ ] Dark mode adapts to system appearance
- [ ] Inspector displays properties and events for selected controls
