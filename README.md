# Harbour Builder

C++ powered cross-platform visual IDE for Harbour

This entire framework has been **vibe coded from scratch using [Claude Code](https://claude.ai/claude-code)** -- from the C++ core and native backends (Win32, Cocoa, GTK3) to the Harbour OOP layer, the visual designer with live inspector, and the IDE layout with 4 independent windows.

![macOS](images/macos_now.png)

![Linux](images/linux_now.png)

## Architecture

Harbour Builder uses a layered architecture that achieves native performance on each platform while keeping application code 100% portable.

```
+------------------------------------------------------+
|                  Application Code                     |
|            (test_design.prg, user apps)               |
+------------------------------------------------------+
|              xBase Command Layer                      |
|  DEFINE FORM, @ GET, BUTTON, CHECKBOX, COMBOBOX ...   |
|                (hbbuilder.ch)                          |
+------------------------------------------------------+
|             Harbour OOP Layer                         |
|    TForm, TControl, TToolBar, TMenuPopup ...          |
|                (classes.prg)                          |
+------------------------------------------------------+
|              HB_FUNC Bridge                           |
|   UI_FormNew, UI_SetProp, UI_GetProp, UI_OnEvent ...  |
|     Identical function signatures on all platforms     |
+------------------------------------------------------+
|            Native C/C++ Backend                       |
|  Win32 (C++)  |  Cocoa (Obj-C)  |  GTK3 (C)          |
|  hbide.h      |  cocoa_core.m   |  gtk3_core.c        |
|  tform.cpp    |                 |                     |
|  tcontrol.cpp |                 |                     |
|  tcontrols.cpp|                 |                     |
|  hbbridge.cpp |                 |                     |
+------------------------------------------------------+
|          Operating System                             |
|  Win32 API    |  AppKit/NSView  |  GTK3/Cairo         |
+------------------------------------------------------+
```

### Why this model is efficient

1. **C++ core for raw speed**: Controls are created with native API calls (`CreateWindowEx`, `NSView`, `GtkWidget`). No intermediate abstraction layers at runtime. Property access is a direct C struct field read/write.

2. **HB_FUNC bridge is the only boundary**: Each platform reimplements the same set of `HB_FUNC` exports. The Harbour VM calls directly into native code with zero marshalling overhead.

3. **Harbour OOP is a thin wrapper**: The `TForm`, `TButton`, etc. classes in `classes.prg` are simple ACCESS/ASSIGN wrappers that call `UI_GetProp`/`UI_SetProp`. No data duplication -- the C++ object is the single source of truth.

4. **xBase commands compile away**: The `#xcommand` preprocessor rules in `hbbuilder.ch` translate to method calls at compile time. Zero runtime cost.

### Performance vs FiveWin

| Test | FiveWin | Harbour Builder | Factor |
|------|---------|-----------|--------|
| Create 500 buttons | 0.243s | 0.001s | **243x** |
| Set property 100K times | 24.86s | 0.07s | **355x** |

## IDE Layout

The visual designer follows the C++Builder paradigm with 4 independent top-level windows:

```
+== IDE Bar (top strip, full screen width) =========================+
| File Edit Search View Project Run Component Tools Help            |
| [New][Open][Save]|[Cut][Copy][Paste]| Standard | Additional | ... |
| 1:1              Modified                             470 x 380  |
+===================================================================+

+- Object Inspector -+    +---- Form1 (design) ----+
| [Form1 AS TForm  v]|    | . . . . . . . . . . .  |
| Properties | Events|    | . . +--General---+ . .  |
|---------------------|    | . . | Name: [...] . .  |
| Caption    Form1    |    | . . +-----------+ . .  |
| Height       380    |    | . . . . . . . . . . .  |
| Width        470    |    +-------------------------+
+---------------------+
```

- **IDE Bar**: Menu + speedbar + component palette (TabControl)
- **Object Inspector**: ComboBox (all controls) + Properties/Events tabs + property grid
- **Code Editor**: Dark theme (Consolas 15pt), syntax highlighting, line number gutter
- **Design Form**: Independent floating window with grid dots and selection handles

All 4 share one message loop via `TForm:Show()` (no loop) + `TForm:Activate()` (enters loop).

## File Structure

```
cpp/
  include/hbide.h       - All class declarations (TForm, TControl, TToolBar, etc.)
  src/tcontrol.cpp       - TObject, TControl base (WndProc, events, properties)
  src/tform.cpp          - TForm (design mode, grid, overlay, menu, toolbar)
  src/tcontrols.cpp      - TLabel, TEdit, TButton, TCheckBox, TComboBox, TGroupBox,
                           TToolBar, TComponentPalette
  src/hbbridge.cpp       - HB_FUNC exports (Win32 backend)

harbour/
  classes.prg            - Harbour OOP wrappers (TForm, TControl, TToolBar, TMenuPopup)
  hbbuilder.ch            - xBase #xcommand syntax (DEFINE FORM, @ GET, BUTTON, etc.)
  inspector.prg          - Object Inspector (Win32 implementation)

backends/
  cocoa/cocoa_core.m     - macOS Cocoa/AppKit backend (same HB_FUNC interface)
  gtk3/gtk3_core.c       - Linux GTK3 backend (same HB_FUNC interface)
  console/backend.prg    - TUI console backend
  web/backend.prg        - HTML5 Canvas backend

samples/
  hbbuilder_win.prg      - Windows IDE
  hbbuilder_macos.prg    - macOS IDE: save/build/run projects
  hbbuilder_linux.prg    - Linux IDE: save/build/run projects
  test_design.prg        - Windows IDE (legacy, hardcoded positions)
  build_cpp.bat          - Windows build script (BCC77C + Harbour)
```

## Adding a New Control

1. Add `CT_MYCONTROL` constant to `hbide.h`
2. Create `TMyControl` class in `tcontrols.cpp` (constructor, `CreateParams`, `GetPropDescs`)
3. Add `UI_MyControlNew` bridge function in `hbbridge.cpp`
4. Add `TMyControl` Harbour class in `classes.prg`
5. Add `#xcommand` in `hbbuilder.ch`
6. Implement in `cocoa_core.m` and `gtk3_core.c` with matching `HB_FUNC`

## Build

### Windows
```
cd samples
build_cpp.bat test_design
```

### macOS
```
cd samples
./build_mac.sh
```

### Linux
```
cd samples
./build_gtk.sh
```
