# Linux GTK3 Parity with macOS/Windows — Design Spec

**Date**: 2026-04-05  
**Goal**: Bring the GTK3 (Linux) backend to feature parity with Cocoa (macOS) and partially with Win32 (Windows).

## Current State

The GTK3 backend implements 152 HB_FUNC across 8,173 LOC in C. It covers all 15 base controls, full inspector, Scintilla editor (25 functions), debugger, dark mode, AI assistant, and all IDE dialogs. It is production-ready for basic form design, editing, and debugging.

### What's Missing vs macOS (Phase A)

| Feature | macOS Has | GTK3 Has |
|---------|-----------|----------|
| Undo/Redo on Form | UI_FORMUNDO, UI_FORMUNDOPUSH | No |
| Copy/Paste Controls | UI_FORMCOPYSELECTED, UI_FORMGETCLIPCOUNT, UI_FORMPASTECONTROLS | No |
| Tab Order Dialog | UI_FORMTABORDERDIALOG | No |
| Editor Error Messages | CODEEDITORADDMESSAGE, CODEEDITORCLEARMESSAGES, CODEEDITORPARSEERRORS | No |
| Editor Show Find Bar | CODEEDITORSHOWFINDBAR | No |

### What's Missing vs Windows (Phase B)

| Control | Win32 Widget | Proposed GTK3 Widget |
|---------|-------------|---------------------|
| RadioButton | BUTTON (BS_RADIOBUTTON) | GtkRadioButton |
| Image | STATIC (SS_BITMAP) | GtkImage |
| Shape | Custom draw | GtkDrawingArea + cairo |
| Bevel | Custom draw | GtkFrame styled |
| ListView | SysListView32 | GtkTreeView (list mode) |
| Browse (data grid) | Custom grid | GtkTreeView (tabular model) |
| BitBtn | BUTTON + bitmap | GtkButton + GtkImage |
| RichEdit | RICHEDIT | GtkTextView |

---

## Phase A: macOS Parity

### A1. Undo/Redo on Form Designer

**Files**: `backends/gtk3/gtk3_core.c`

**Functions to add**:
- `HB_FUNC(UI_FORMUNDOPUSH)` — Captures a snapshot of the current form state (all controls' positions, sizes, and key properties) and pushes it onto an undo stack.
- `HB_FUNC(UI_FORMUNDO)` — Pops the most recent snapshot from the stack and restores all control positions/sizes to that state.

**Data structures**:
```c
#define MAX_UNDO_LEVELS 50

typedef struct {
    char szName[64];
    int nLeft, nTop, nWidth, nHeight;
    int bVisible;
} UndoControlState;

typedef struct {
    UndoControlState controls[MAX_CONTROLS];
    int nControlCount;
} UndoSnapshot;

static UndoSnapshot g_undoStack[MAX_UNDO_LEVELS];
static int g_undoTop = -1;
```

**Behavior**:
- `UI_FORMUNDOPUSH` is called by Harbour code before any destructive operation (move, resize, delete, create control).
- `UI_FORMUNDO` restores the previous state and decrements the stack pointer.
- Stack is circular: oldest entries are overwritten when exceeding MAX_UNDO_LEVELS.

**Reference**: `cocoa_core.m` implements the same pattern. Follow its serialization approach.

### A2. Copy/Paste Controls

**Files**: `backends/gtk3/gtk3_core.c`

**Functions to add**:
- `HB_FUNC(UI_FORMCOPYSELECTED)` — Iterates over all controls on the active form, finds those marked as selected, serializes their class name, properties, and relative positions into an internal clipboard buffer.
- `HB_FUNC(UI_FORMGETCLIPCOUNT)` — Returns the number of controls currently in the clipboard buffer.
- `HB_FUNC(UI_FORMPASTECONTROLS)` — Deserializes controls from the clipboard buffer, creates new instances on the active form with a +10px offset from original positions, and assigns auto-generated unique names.

**Data structures**:
```c
#define MAX_CLIPBOARD_CONTROLS 32

typedef struct {
    char szClassName[32];
    char szName[64];
    int nLeft, nTop, nWidth, nHeight;
    char szText[256];
    // Additional properties as needed
} ClipboardControl;

static ClipboardControl g_clipboard[MAX_CLIPBOARD_CONTROLS];
static int g_clipCount = 0;
```

**Behavior**:
- Internal buffer only (not system clipboard). This matches the macOS implementation.
- Paste creates controls with names like `Label1_Copy`, `Button2_Copy`.
- Multiple pastes increment offset (+10px each time).

### A3. Tab Order Dialog

**Files**: `backends/gtk3/gtk3_core.c`

**Functions to add**:
- `HB_FUNC(UI_FORMTABORDERDIALOG)` — Opens a modal GtkDialog showing all controls in their current tab order. User can reorder with Up/Down buttons. On OK, updates the TabOrder property of each control.

**UI Design**:
```
+---------------------------+
| Tab Order                 |
+---------------------------+
| [GtkListBox]              |
|   1. edtName              |
|   2. edtAge               |
|   3. cmbCity       [Up]   |
|   4. chkActive     [Down] |
|   5. btnSave              |
|   6. btnCancel            |
+---------------------------+
|        [OK]  [Cancel]     |
+---------------------------+
```

**Behavior**:
- Enumerates controls from the active form via existing control iteration logic.
- Displays control name + class in the list.
- Up/Down buttons swap adjacent entries.
- OK applies new tab order by setting each control's TabOrder property.

### A4. Editor Error Messages Panel

**Files**: `backends/gtk3/gtk3_core.c` (alongside existing CODEEDITOR_* functions)

**Functions to add**:
- `HB_FUNC(CODEEDITORADDMESSAGE)` — Adds a row to the error messages panel. Parameters: type (error/warning/info), line number, column, message text, filename.
- `HB_FUNC(CODEEDITORCLEARMESSAGES)` — Clears all rows from the error messages panel.
- `HB_FUNC(CODEEDITORPARSEERRORS)` — Takes compiler output as a string, parses it using Harbour error format regex (`filename(line) Error/Warning Exxx message`), and calls CODEEDITORADDMESSAGE for each match.

**UI Design**:
- A `GtkTreeView` panel below the code editor with columns: Icon (error/warning), Line, Column, Message, File.
- Clicking a row navigates to the corresponding line in the editor via `SCI_GOTOLINE`.
- Panel is shown/hidden via a toggle in the View menu.

**Error format regex**:
```
^(.+)\((\d+)\)\s+(Error|Warning)\s+(E\d+)\s+(.+)$
```

### A5. Editor Show Find Bar

**Files**: `backends/gtk3/gtk3_core.c`

**Functions to add**:
- `HB_FUNC(CODEEDITORSHOWFINDBAR)` — Programmatically shows/focuses the find bar. The find bar already exists (Ctrl+F works); this function provides an explicit entry point for menu items or toolbar buttons.

**Behavior**: Calls the same internal logic that Ctrl+F triggers. If the find bar is already visible, focuses the search field.

---

## Phase B: Additional Controls (Win32 Parity)

Each control requires:
1. `HB_FUNC(UI_<CONTROL>NEW)` — Creates the widget and returns its handle
2. Integration with `UI_GETALLPROPS` / `UI_SETPROP` / `UI_GETPROP` for inspector support
3. Registration in the palette/component panel

### B1. RadioButton
- **GTK Widget**: `GtkRadioButton`
- **Properties**: Text, Checked, GroupName
- **Events**: OnClick, OnChange
- **Notes**: Radio buttons in the same GroupName form a mutual-exclusion group. Use `gtk_radio_button_new_with_label_from_widget()` to link them.

### B2. Image
- **GTK Widget**: `GtkImage`
- **Properties**: Picture (file path), Stretch, Center, Proportional
- **Events**: OnClick, OnDblClick
- **Notes**: Load via `gtk_image_new_from_file()`. For Stretch/Proportional, use `GdkPixbuf` scaling and wrap in a `GtkDrawingArea` with cairo.

### B3. Shape
- **GTK Widget**: `GtkDrawingArea` with cairo drawing
- **Properties**: Shape (rectangle, circle, rounded rect, ellipse), PenColor, PenWidth, BrushColor
- **Events**: OnClick
- **Notes**: Draw in the `draw` signal handler using cairo primitives.

### B4. Bevel
- **GTK Widget**: `GtkFrame` with CSS styling
- **Properties**: BevelStyle (raised, lowered, none), Shape (box, frame, top line, bottom line)
- **Events**: None (decorative)
- **Notes**: Use GTK CSS classes to achieve raised/lowered appearance.

### B5. ListView
- **GTK Widget**: `GtkTreeView` with `GtkListStore`
- **Properties**: Columns (array), ViewStyle (icon, list, report, small icon), GridLines
- **Events**: OnClick, OnDblClick, OnColumnClick
- **Notes**: Column definitions via `UI_LISTVIEWADDCOLUMN`. Items via `UI_LISTVIEWADDITEM`.

### B6. Browse (Data Grid)
- **GTK Widget**: `GtkTreeView` with `GtkListStore` (tabular mode)
- **Properties**: Columns, DataSource, ReadOnly, GridLines, RowHeight
- **Events**: OnCellEdit, OnRowSelect, OnDblClick
- **Notes**: Most complex control. Needs cell editing support via `GtkCellRendererText` with `edited` signal. Column types: text, number, logical (checkbox renderer), date.

### B7. BitBtn (Bitmap Button)
- **GTK Widget**: `GtkButton` with `GtkImage` child
- **Properties**: Caption, Glyph (image path), Layout (left, right, top, bottom), Spacing
- **Events**: OnClick
- **Notes**: Use `gtk_button_new()` + `gtk_box_new()` to arrange image and label.

### B8. RichEdit
- **GTK Widget**: `GtkTextView` with `GtkTextBuffer`
- **Properties**: Text, ReadOnly, WordWrap, ScrollBars
- **Events**: OnChange, OnKeyPress
- **Notes**: For rich formatting, use `GtkTextTag` for bold/italic/color. Alternative: use Scintilla without syntax highlighting.

---

## Implementation Order

### Phase A (macOS parity) — Recommended order:
1. **A1: Undo/Redo** — Foundational for designer usability
2. **A2: Copy/Paste** — Depends on same control serialization as Undo
3. **A5: Show Find Bar** — Simplest, quick win
4. **A4: Error Messages** — Important for build workflow
5. **A3: Tab Order Dialog** — Self-contained dialog

### Phase B (additional controls) — Recommended order:
1. **B7: BitBtn** — Simplest, just a button with image
2. **B1: RadioButton** — Simple GTK widget
3. **B2: Image** — Common need in forms
4. **B4: Bevel** — Decorative, CSS-based
5. **B3: Shape** — Cairo drawing
6. **B8: RichEdit** — Text editing
7. **B5: ListView** — Multi-column list
8. **B6: Browse** — Most complex, data grid

---

## Files Modified

| File | Changes |
|------|---------|
| `backends/gtk3/gtk3_core.c` | All Phase A functions + Phase B controls |
| `harbour/inspector_gtk.prg` | Register new controls in inspector |
| `harbour/classes.prg` | Add new control classes (TRadioButton, TImage, etc.) |
| `samples/hbbuilder_linux.prg` | Add menu items for new features, palette entries for new controls |
| `harbour/hbbuilder.ch` | Add DEFINE macros for new controls |
| `core/controls.prg` | Add control definitions for new types |

## Testing Strategy

- Each Phase A feature: manual test in the running IDE
- Each Phase B control: create a sample form using the new control, verify properties in inspector, verify events fire
- Cross-reference with macOS behavior for Phase A features
- Verify no regressions in existing controls
