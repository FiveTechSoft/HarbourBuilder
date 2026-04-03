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
