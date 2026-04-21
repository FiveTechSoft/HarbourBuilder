# Report Controls Design Spec

**Goal:** Add visually-placeable report controls (ReportLabel, ReportField, ReportImage) inside bands in the HarbourBuilder report designer, matching FastReport/C++Builder UX.

**Date:** 2026-04-18

---

## Architecture

### Control Types

Three new CT_ constants added to `include/hbide.h`:

```c
#define CT_REPORTLABEL  133
#define CT_REPORTFIELD  134
#define CT_REPORTIMAGE  135
```

All three are subclasses of `TControl` in `source/cpp/tcontrols.cpp`.

`TControl` gains one new field: `TControl * FBandParent` (NULL for non-report controls). When a report control lives inside a band, `FBandParent` points to the band's TControl. `FLeft`/`FTop` are **band-relative**.

---

## Palette

A new **"Report"** tab is inserted as the **first tab** in the palette (before Standard), with four entries in order:

| Button | Tooltip | CT |
|---|---|---|
| Bnd | Band | 132 |
| RLb | ReportLabel | 133 |
| RFd | ReportField | 134 |
| RIm | ReportImage | 135 |

`W32_GENERATEPALETTEICONS`: Report tab icons inserted at positions 0–3, shifting all existing indices by +4. Icon style: dark green background (`RGB(34,120,60)`), white abbreviation text — except Band which keeps its existing brown 3-stripe icon.

---

## C++ Classes

### TReportLabel (CT_REPORTLABEL = 133)
```cpp
class TReportLabel : public TControl {
public:
    TReportLabel() { FControlType=CT_REPORTLABEL; FWidth=120; FHeight=20; }
};
```
Properties: `cText`, `cFontName`, `nFontSize`, `lBold`, `lItalic`, `nAlignment`.

### TReportField (CT_REPORTFIELD = 134)
```cpp
class TReportField : public TControl {
public:
    char FFieldName[128];   // "TABLE->FIELD"
    char FExpression[256];  // arbitrary Harbour expression
    TReportField() { FControlType=CT_REPORTFIELD; FWidth=120; FHeight=20; }
};
```
Properties: everything from ReportLabel + `cFieldName`, `cExpression`.

### TReportImage (CT_REPORTIMAGE = 135)
```cpp
class TReportImage : public TControl {
public:
    TReportImage() { FControlType=CT_REPORTIMAGE; FWidth=80; FHeight=60; }
};
```
Properties: `cFileName`.

`CreateControlByType()` handles all three cases.

---

## Win32 Window Class

A single `"HBReportCtrl"` Win32 window class is registered (with `CS_HREDRAW|CS_VREDRAW`) with a shared `ReportCtrlWndProc`. The HWND for each report control is created as a **child of the band's HBBandView HWND** — this means report controls move with the band automatically when BandStackAll repositions it.

### WM_PAINT rendering per type:
- **ReportLabel**: white background, blue dashed border, centered text in Segoe UI
- **ReportField**: white background, blue dashed border, `[cFieldName]` or `[expr]` in italic Segoe UI
- **ReportImage**: white background, blue dashed border, diagonal cross placeholder

---

## Drop Logic

When `FPendingControlType` is 133/134/135 and the user releases the rubber-band:

1. Find which CT_BAND child of the form contains the rubber-band origin point `(rx1, ry1)` in form coordinates.
2. **If a band is found:**
   - Create the report control via `CreateControlByType()`
   - Set `FBandParent = pBand`
   - `FLeft = rx1 - pBand->FLeft` (band-relative)
   - `FTop  = ry1 - pBand->FTop`  (band-relative)
   - `FWidth = max(rw, 20)`, `FHeight = max(rh, 10)`
   - Create HWND as child of `pBand->FHandle` at `(FLeft, FTop, FWidth, FHeight)`
   - Add to form's `FChildren`
   - Fire `OnComponentDrop` callback
3. **If no band found:** drop is silently ignored — report controls only exist inside bands.

---

## Coordinate Translation

Report controls have band-relative `FLeft`/`FTop`. All form-level operations that use control coordinates must translate to form-absolute:

```cpp
int absLeft = (p->FBandParent ? p->FBandParent->FLeft + p->FLeft : p->FLeft);
int absTop  = (p->FBandParent ? p->FBandParent->FTop  + p->FTop  : p->FTop);
```

Affected functions in `tform.cpp`:
- `HitTest()` — use abs coords for hit detection
- `PaintSelectionHandles()` — use abs coords for handle positions and dashed border
- `WM_MOUSEMOVE` drag — apply delta to band-relative `FLeft`/`FTop`, clamp to `[0, band->FWidth - p->FWidth]` / `[0, band->FHeight - p->FHeight]`
- `WM_MOUSEMOVE` resize — apply delta to band-relative coords

Report controls show **8 handles** (normal resize, not band-only BC handle).

HWND position is kept in sync: on drag/resize commit, call `SetWindowPos(p->FHandle, NULL, p->FLeft, p->FTop, p->FWidth, p->FHeight, SWP_NOZORDER)` — coordinates are band-relative since the HWND parent is the band window.

---

## Inspector Integration

`UI_GetAllProps` in `hbbridge.cpp` adds cases for 133/134/135:

**CT_REPORTLABEL (133):**
```
cText, cFontName, nFontSize, lBold, lItalic, nAlignment, nLeft, nTop, nWidth, nHeight
```

**CT_REPORTFIELD (134):**
```
cText (label), cFieldName, cExpression, cFontName, nFontSize, lBold, lItalic, nAlignment, nLeft, nTop, nWidth, nHeight
```

**CT_REPORTIMAGE (135):**
```
cFileName, nLeft, nTop, nWidth, nHeight
```

`UI_SetProp` / `UI_GetProp` handle `cFieldName` → `FFieldName` and `cExpression` → `FExpression` for CT_REPORTFIELD.

nLeft/nTop shown and edited in Inspector as band-relative values.

---

## Serialization

Report controls are serialized into the band's `aData` pipe-delimited string (existing format), one record per line:

```
cName|cType|cText|cFieldName|cFormat|nTop|nLeft|nWidth|nHeight|cFont|nFontSize|lBold|lItalic|nAlignment
```

Where `cType` is `"label"`, `"field"`, or `"image"`.

**Save**: when `SyncDesignerToCode` processes a band, it iterates `FChildren` of the form, filters by `FBandParent == pBand`, and appends each to `aData`.

**Load** (`RestoreFormFromCode`): after creating a band, parse `REPORTFIELD`/`REPORTLABEL`/`REPORTIMAGE` lines and recreate the C++ controls with correct `FBandParent` and band-relative coordinates.

---

## Preview Integration

`TReport:Preview()` already iterates `oBand:aFields` and calls `RPT_PreviewDrawText`. No changes needed to the preview engine — the serialized `aData` continues to feed `TReportField` objects as before.

The band type label ("Header", "Detail", etc.) never appears in preview — it is design-time only.

---

## Files Modified

| File | Change |
|---|---|
| `include/hbide.h` | Add CT_REPORTLABEL=133, CT_REPORTFIELD=134, CT_REPORTIMAGE=135 |
| `source/cpp/tcontrols.cpp` | TReportLabel, TReportField, TReportImage classes; CreateControlByType cases; HBReportCtrl window class registration |
| `source/cpp/tcontrol.h` (or tcontrols.h) | FBandParent field on TControl; declare new classes |
| `source/cpp/tform.cpp` | Drop logic band targeting; HitTest coord translation; PaintSelectionHandles coord translation; drag/resize clamping |
| `source/cpp/hbbridge.cpp` | UI_GetAllProps/SetProp/GetProp for 133/134/135; cFieldName/cExpression handling |
| `source/hbbuilder_win.prg` | Report tab in palette (first tab, 4 entries); OnComponentDrop for 133/134/135; SyncDesignerToCode band-children serialization; RestoreFormFromCode parsing; W32_GENERATEPALETTEICONS Report tab icons |
