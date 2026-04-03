# Linux Build & Review Guide

## Prerequisites

- **GCC**
- **GTK3 development libraries** -- install with `apt install libgtk-3-dev`
- **Harbour 3.2** compiled for linux/gcc

## Build

```bash
cd samples
./build_gtk.sh
```

Build output is a native ELF binary.

## Architecture

| Layer | File |
|-------|------|
| Backend (C, GTK3) | `backends/gtk3/gtk3_core.c` |
| IDE entry point | `samples/hbbuilder_linux.prg` |
| Inspector (native) | `backends/gtk3/gtk3_inspector.c` |
| Inspector (Harbour) | `harbour/inspector_gtk.prg` |

## Native Widgets

The GTK3 backend wraps the following widget classes:

GtkLabel, GtkEntry, GtkButton, GtkTreeView, GtkListStore, GtkNotebook, GtkScale, GtkSpinButton, GtkCalendar, GtkDrawingArea, GtkScrolledWindow, GtkTextView, GtkProgressBar

## Palette & Controls

- **14 palette tabs** (same set as Windows)
- **109 controls** (same set as Windows)
- The first tab is named **"GTK3"** instead of "Win32"

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

## GDK Backend

Primary: **X11**, with fallback to **Wayland**.

## Font

Sans, 11 pt.

## Inspector Requirements

The Object Inspector must match Windows behavior exactly:

### Properties Tab
- Categories (Info, Appearance, Position, Behavior) with ` -  ` prefix (expanded) / ` +  ` prefix (collapsed)
- Properties indented with 6 spaces under their category
- Bold font + gray background for category rows
- Click category to collapse/expand
- Enum properties (nBorderStyle, nPosition, nWindowState, etc.) show as dropdown ComboBox
- Color properties show color picker dialog
- Font properties show font picker dialog
- Logical properties toggle .T./.F. via popup menu

### Events Tab
- Categories (Action, Lifecycle, Layout, Keyboard, Mouse) with same ` -  ` / ` +  ` format as Properties
- Events indented with 6 spaces under their category
- Bold font + gray background for category rows (same NM_CUSTOMDRAW as Properties)
- Click category to collapse/expand (same behavior as Properties)
- Double-click event name to generate handler code
- Event list populated dynamically per control type via UI_GetType

### Both Tabs
- Categories must look IDENTICAL between Properties and Events
- Same bold font, same gray background, same +/- indicators, same indentation

## Known Issues to Review

- Ensure GTK3 widget creation works for all 109 controls in `gtk3_core.c`.

## Reviewer Checklist

- [ ] GCC installed
- [ ] `libgtk-3-dev` installed (verify with `pkg-config --modversion gtk+-3.0`)
- [ ] Harbour 3.2 (linux/gcc) available on PATH
- [ ] `build_gtk.sh` completes without errors
- [ ] ELF binary launches and main window appears
- [ ] All 14 palette tabs are visible (first tab reads "GTK3")
- [ ] Dropping each of the 109 controls onto the form succeeds
- [ ] Two-way sync: editing a property updates the code and vice-versa
- [ ] File / Open loads a saved project correctly
- [ ] File / Save writes the project without errors
- [ ] Build / Run compiles and launches the sample project
- [ ] All nine menus are present and match the Windows version
- [ ] Stub features show MsgInfo when invoked
- [ ] Inspector displays and updates properties for selected controls
- [ ] Application works under both X11 and Wayland sessions
