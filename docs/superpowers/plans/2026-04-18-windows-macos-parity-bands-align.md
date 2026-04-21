# Windows — macOS Parity: Bands, Rulers, ControlAlign, Multiline Inspector

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Windows IDE up to feature parity with the macOS IDE for all features added in sessions 2026-04-17 and 2026-04-18 — report bands, ruler overlay, ControlAlign dock layout, REPORTFIELD code gen/restore, and the Inspector multiline string editor.

**Architecture:** Changes span 4 files: `include/hbide.h` (struct additions), `source/cpp/hbbridge.cpp` + `source/cpp/tform.cpp` (C++ backend), `source/hbbuilder_win.prg` (Harbour IDE logic), and `source/inspector/inspector_win.prg` (Inspector UI). The macOS implementations in `source/backends/cocoa/cocoa_core.m` and `source/hbbuilder_macos.prg` are the reference — port logic 1:1, replacing Cocoa/CoreGraphics APIs with Win32/GDI equivalents.

**Tech Stack:** Win32 API, GDI, Harbour PRG, C++/BCC32

---

### Task 1: Extend TControl struct + add CT_BAND constant

**Files:**
- Modify: `include/hbide.h`

CT_BAND (132) is already in `include/hbide.ch` (used by Harbour code) but missing from `include/hbide.h` (used by C++). TControl also needs `FDockAlign` for ControlAlign and `FData[4096]` for band field serialization.

- [ ] **Step 1: Add CT_BAND to hbide.h**

In `include/hbide.h`, after line `#define CT_COMPARRAY  131`, add:

```c
/* Report designer band */
#define CT_BAND       132

/* ControlAlign constants (matches macOS ALIGN_* values) */
#define ALIGN_NONE    0
#define ALIGN_TOP     1
#define ALIGN_BOTTOM  2
#define ALIGN_LEFT    3
#define ALIGN_RIGHT   4
#define ALIGN_CLIENT  5
```

- [ ] **Step 2: Add FDockAlign and FData to TControl**

In `include/hbide.h`, in the `TControl` class body, after the `FTimerID` line, add:

```c
   /* ControlAlign dock layout (0=alNone..5=alClient) */
   int          FDockAlign;

   /* Band field serialization: pipe/newline separated records up to 4096 bytes */
   char         FData[4096];
```

- [ ] **Step 3: Initialize new fields in TControl constructor**

In `source/cpp/tcontrol.cpp`, in `TControl::TControl()`, after `FTimerID = 0;`, add:

```c
   FDockAlign = ALIGN_NONE;
   FData[0] = '\0';
```

- [ ] **Step 4: Build to verify struct compiles**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit**

```bash
git add include/hbide.h source/cpp/tcontrol.cpp
git commit -m "feat(win): CT_BAND=132, ALIGN_* constants, FDockAlign+FData in TControl"
```

---

### Task 2: CT_BAND visual control + band functions in hbbridge.cpp

**Files:**
- Modify: `source/cpp/hbbridge.cpp`

Implements `UI_BandNew`, `UI_BandGetType`, `UI_BandSetType`, `BandStackAll`, `UI_BandRulersUpdate`, and CT_BAND rendering (colored rectangle + label). Also adds `cBandType` / `aData` support in `UI_SetProp` / `UI_GetProp` / `UI_GetAllProps`.

Band colors per type (matching macOS HBBandView):
- Header → `RGB(59, 130, 246)` (blue)
- PageHeader → `RGB(34, 197, 94)` (green)
- Detail → `RGB(240, 240, 240)` (light gray)
- PageFooter → `RGB(34, 197, 94)` (green)
- Footer → `RGB(107, 114, 128)` (gray)

Rulers are two transparent child `STATIC` windows (horizontal 20px tall at top, vertical 20px wide at left) with a subclassed `WM_PAINT` that draws tick marks every 10px and labels every 100px.

- [ ] **Step 1: Add CT_BAND WndProc subclass + helpers at top of hbbridge.cpp**

After the `#include` block (after line 17), add:

```c
/* ---- CT_BAND helpers ---------------------------------------------------- */
static COLORREF BandColor( const char * szType )
{
   if( lstrcmpiA( szType, "Header" ) == 0 )     return RGB(59, 130, 246);
   if( lstrcmpiA( szType, "PageHeader" ) == 0 ) return RGB(34, 197, 94);
   if( lstrcmpiA( szType, "PageFooter" ) == 0 ) return RGB(34, 197, 94);
   if( lstrcmpiA( szType, "Footer" ) == 0 )     return RGB(107, 114, 128);
   return RGB(240, 240, 240);  /* Detail = light gray */
}

static LRESULT CALLBACK BandWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_PAINT )
   {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint( hWnd, &ps );
      RECT rc;
      GetClientRect( hWnd, &rc );

      TControl * p = (TControl *) GetWindowLongPtr( hWnd, GWLP_USERDATA );
      const char * szType = (p && p->FText[0]) ? p->FText : "Detail";

      COLORREF clr = BandColor( szType );
      HBRUSH hBr = CreateSolidBrush( clr );
      FillRect( hdc, &rc, hBr );
      DeleteObject( hBr );

      /* Bottom hairline */
      HPEN hPen = CreatePen( PS_SOLID, 1, RGB(180,180,180) );
      HPEN hOld = (HPEN) SelectObject( hdc, hPen );
      MoveToEx( hdc, rc.left, rc.bottom - 1, NULL );
      LineTo( hdc, rc.right, rc.bottom - 1 );
      SelectObject( hdc, hOld );
      DeleteObject( hPen );

      /* Centered label */
      SetBkMode( hdc, TRANSPARENT );
      SetTextColor( hdc, RGB(255,255,255) );
      DrawTextA( hdc, szType, -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE );

      EndPaint( hWnd, &ps );
      return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* ---- Ruler overlay ------------------------------------------------------- */
static LRESULT CALLBACK RulerWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_PAINT )
   {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint( hWnd, &ps );
      RECT rc;
      GetClientRect( hWnd, &rc );

      BOOL bHoriz = (BOOL)(INT_PTR) GetPropA( hWnd, "Horiz" );

      HBRUSH hBr = CreateSolidBrush( RGB(230, 230, 230) );
      FillRect( hdc, &rc, hBr );
      DeleteObject( hBr );

      SetBkMode( hdc, TRANSPARENT );
      SetTextColor( hdc, RGB(80, 80, 80) );

      HFONT hFont = CreateFontA( 8, 0, 0, 0, FW_NORMAL, 0, 0, 0,
         ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
         DEFAULT_QUALITY, DEFAULT_PITCH, "Arial" );
      HFONT hOld = (HFONT) SelectObject( hdc, hFont );

      int span = bHoriz ? rc.right : rc.bottom;
      int i;
      for( i = 0; i <= span; i += 10 )
      {
         int tick = (i % 100 == 0) ? 6 : 3;
         if( bHoriz )
         {
            MoveToEx( hdc, i, rc.bottom, NULL );
            LineTo( hdc, i, rc.bottom - tick );
            if( i % 100 == 0 && i > 0 )
            {
               char szNum[8];
               RECT rLabel = { i + 1, 0, i + 30, rc.bottom - tick };
               wsprintfA( szNum, "%d", i );
               DrawTextA( hdc, szNum, -1, &rLabel, DT_LEFT | DT_TOP | DT_SINGLELINE );
            }
         }
         else
         {
            MoveToEx( hdc, rc.right, i, NULL );
            LineTo( hdc, rc.right - tick, i );
            if( i % 100 == 0 && i > 0 )
            {
               char szNum[8];
               RECT rLabel = { 0, i + 1, rc.right - tick, i + 14 };
               wsprintfA( szNum, "%d", i );
               DrawTextA( hdc, szNum, -1, &rLabel, DT_LEFT | DT_TOP | DT_SINGLELINE );
            }
         }
      }

      /* Corner square (only drawn on horizontal ruler at x=0) */
      if( bHoriz )
      {
         RECT rcCorner = { 0, 0, 20, rc.bottom };
         HBRUSH hCorn = CreateSolidBrush( RGB(200, 200, 200) );
         FillRect( hdc, &rcCorner, hCorn );
         DeleteObject( hCorn );
      }

      SelectObject( hdc, hOld );
      DeleteObject( hFont );
      EndPaint( hWnd, &ps );
      return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

static void RegisterBandClasses()
{
   static BOOL bRegistered = FALSE;
   if( bRegistered ) return;
   bRegistered = TRUE;

   WNDCLASSA wc = {0};
   HINSTANCE hInst = GetModuleHandleA(NULL);

   wc.lpfnWndProc   = BandWndProc;
   wc.hInstance     = hInst;
   wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
   wc.hbrBackground = NULL;
   wc.lpszClassName = "HBBandView";
   RegisterClassA( &wc );

   wc.lpfnWndProc   = RulerWndProc;
   wc.lpszClassName = "HBRulerView";
   RegisterClassA( &wc );
}
```

- [ ] **Step 2: Add BandStackAll + UI_BandRulersUpdate + ruler tag names**

After the `RegisterBandClasses()` function, add:

```c
#define RULER_H_PROP "RulerH"
#define RULER_V_PROP "RulerV"

/* Restack all CT_BAND children of hParent vertically, starting at y=20 (below ruler).
   Width = parent client width - 20 (left ruler). */
static void BandStackAll( HWND hParent )
{
   if( !hParent ) return;

   RECT rcParent;
   GetClientRect( hParent, &rcParent );
   int formW = rcParent.right - rcParent.left;
   int formH = rcParent.bottom - rcParent.top;

   /* Collect bands in order from FChildren */
   TForm * pForm = (TForm *) GetWindowLongPtr( hParent, GWLP_USERDATA );
   if( !pForm ) return;

   static const char * s_order[] = { "Header","PageHeader","Detail","PageFooter","Footer", NULL };
   int yPos = 20;  /* below horizontal ruler */
   int bandW = formW - 20;  /* right of vertical ruler */

   for( int o = 0; s_order[o]; o++ )
   {
      for( int i = 0; i < pForm->FChildCount; i++ )
      {
         TControl * c = pForm->FChildren[i];
         if( !c || c->FControlType != CT_BAND ) continue;
         if( lstrcmpiA( c->FText, s_order[o] ) != 0 ) continue;

         c->FLeft = 20;
         c->FTop  = yPos;
         c->FWidth = bandW;
         if( c->FHandle )
            SetWindowPos( c->FHandle, NULL, 20, yPos, bandW, c->FHeight,
               SWP_NOZORDER | SWP_NOACTIVATE );
         yPos += c->FHeight;
      }
   }
}

/* Show/hide ruler overlay windows on the design form depending on band presence. */
static void UI_BandRulersUpdate( TForm * pForm )
{
   if( !pForm || !pForm->FHandle ) return;

   BOOL bHasBand = FALSE;
   for( int i = 0; i < pForm->FChildCount; i++ )
      if( pForm->FChildren[i] && pForm->FChildren[i]->FControlType == CT_BAND )
         { bHasBand = TRUE; break; }

   HWND hRH = (HWND)(INT_PTR) GetPropA( pForm->FHandle, RULER_H_PROP );
   HWND hRV = (HWND)(INT_PTR) GetPropA( pForm->FHandle, RULER_V_PROP );

   if( bHasBand )
   {
      RegisterBandClasses();
      RECT rcClient;
      GetClientRect( pForm->FHandle, &rcClient );
      HINSTANCE hInst = GetModuleHandleA(NULL);

      if( !hRH )
      {
         hRH = CreateWindowExA( 0, "HBRulerView", "",
            WS_CHILD | WS_VISIBLE,
            20, 0, rcClient.right - 20, 20,
            pForm->FHandle, NULL, hInst, NULL );
         SetPropA( hRH, "Horiz", (HANDLE)(INT_PTR) TRUE );
         SetPropA( pForm->FHandle, RULER_H_PROP, (HANDLE)(INT_PTR) hRH );
      }
      if( !hRV )
      {
         hRV = CreateWindowExA( 0, "HBRulerView", "",
            WS_CHILD | WS_VISIBLE,
            0, 0, 20, rcClient.bottom,
            pForm->FHandle, NULL, hInst, NULL );
         SetPropA( hRV, "Horiz", (HANDLE)(INT_PTR) FALSE );
         SetPropA( pForm->FHandle, RULER_V_PROP, (HANDLE)(INT_PTR) hRV );
      }
      /* Rulers must be on top of bands */
      if( hRH ) SetWindowPos( hRH, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE|SWP_NOSIZE );
      if( hRV ) SetWindowPos( hRV, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE|SWP_NOSIZE );
   }
   else
   {
      if( hRH ) { DestroyWindow( hRH ); RemovePropA( pForm->FHandle, RULER_H_PROP ); }
      if( hRV ) { DestroyWindow( hRV ); RemovePropA( pForm->FHandle, RULER_V_PROP ); }
   }
}
```

- [ ] **Step 3: Add UI_BandNew / UI_BandGetType / UI_BandSetType / HB_FUNC(BANDSTACKALL)**

After `UI_BandRulersUpdate`, add:

```c
/* UI_BandNew( hForm, cType, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_BANDNEW )
{
   TForm * pForm = (TForm *) GetCtrl(1);
   if( !pForm || pForm->FControlType != CT_FORM ) { hb_retni(0); return; }

   RegisterBandClasses();

   TControl * p = new TControl();
   p->FControlType = CT_BAND;
   lstrcpyA( p->FClassName, "TBand" );

   const char * szType = HB_ISCHAR(2) ? hb_parc(2) : "Detail";
   lstrcpynA( p->FText, szType, sizeof(p->FText) );

   p->FLeft   = hb_parni(3);
   p->FTop    = hb_parni(4);
   p->FWidth  = hb_parni(5);
   p->FHeight = hb_parni(6) > 0 ? hb_parni(6) : 65;

   p->FHandle = CreateWindowExA( 0, "HBBandView", szType,
      WS_CHILD | WS_VISIBLE,
      p->FLeft, p->FTop, p->FWidth, p->FHeight,
      pForm->FHandle, NULL, GetModuleHandleA(NULL), NULL );

   SetWindowLongPtr( p->FHandle, GWLP_USERDATA, (LONG_PTR) p );

   pForm->AddChild( p );
   p->FCtrlParent = (TControl *) pForm;

   UI_BandRulersUpdate( pForm );
   BandStackAll( pForm->FHandle );

   RetCtrl( p );
}

/* UI_BandGetType( hCtrl ) --> cType */
HB_FUNC( UI_BANDGETTYPE )
{
   TControl * p = GetCtrl(1);
   hb_retc( (p && p->FControlType == CT_BAND) ? p->FText : "" );
}

/* UI_BandSetType( hCtrl, cType ) */
HB_FUNC( UI_BANDSETTYPE )
{
   TControl * p = GetCtrl(1);
   if( p && p->FControlType == CT_BAND && HB_ISCHAR(2) )
   {
      lstrcpynA( p->FText, hb_parc(2), sizeof(p->FText) );
      if( p->FHandle ) InvalidateRect( p->FHandle, NULL, TRUE );
   }
}

/* UI_BandSetLayout( hCtrl ) — restack all bands after drop */
HB_FUNC( UI_BANDSETLAYOUT )
{
   TControl * p = GetCtrl(1);
   if( p && p->FCtrlParent && p->FControlType == CT_BAND )
      BandStackAll( ((TForm*)p->FCtrlParent)->FHandle );
}
```

- [ ] **Step 4: Wire CT_BAND into UI_SetProp**

In `UI_SetProp` (around the `else if` chain, after the existing `lEnabled` block), add:

```c
   else if( lstrcmpi( szProp, "cBandType" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_BAND )
   {
      lstrcpynA( p->FText, hb_parc(3), sizeof(p->FText) );
      if( p->FHandle ) InvalidateRect( p->FHandle, NULL, TRUE );
   }
   else if( lstrcmpi( szProp, "aData" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_BAND )
   {
      lstrcpynA( p->FData, hb_parc(3), sizeof(p->FData) - 1 );
   }
   else if( lstrcmpi( szProp, "nControlAlign" ) == 0 && HB_ISNUM(3) )
   {
      p->FDockAlign = hb_parni(3);
   }
```

- [ ] **Step 5: Wire CT_BAND into UI_GetProp**

In `UI_GetProp` (the large switch/if-else chain), add (after the `cText` block):

```c
   else if( lstrcmpi( szProp, "cBandType" ) == 0 && p->FControlType == CT_BAND )
      hb_retc( p->FText );
   else if( lstrcmpi( szProp, "aData" ) == 0 && p->FControlType == CT_BAND )
      hb_retc( p->FData );
   else if( lstrcmpi( szProp, "nControlAlign" ) == 0 )
      hb_retni( p->FDockAlign );
```

- [ ] **Step 6: Wire CT_BAND + ControlAlign into UI_GetAllProps**

In `UI_GetAllProps`, after the existing `ADD_PROP_L( "lEnabled", ...)` line, add:

```c
The exact code to add after the existing `ADD_PROP_L( "lEnabled", ...)` line:

```c
   /* ControlAlign for all controls */
   {
      static const char * szAlignEnum = "alNone|alTop|alBottom|alLeft|alRight|alClient";
      pRow = hb_itemArrayNew(4);
      hb_arraySetC( pRow, 1, "nControlAlign" );
      hb_arraySetNI( pRow, 2, p->FDockAlign );
      hb_arraySetC( pRow, 3, "Layout" );
      hb_arraySetC( pRow, 4, szAlignEnum );
      hb_arrayAdd( pArray, pRow );
      hb_itemRelease( pRow );
   }

   /* CT_BAND-specific properties */
   if( p->FControlType == CT_BAND )
   {
      static const char * szBandEnum = "Header|PageHeader|Detail|PageFooter|Footer";
      pRow = hb_itemArrayNew(4);
      hb_arraySetC( pRow, 1, "cBandType" );
      hb_arraySetC( pRow, 2, p->FText );
      hb_arraySetC( pRow, 3, "Band" );
      hb_arraySetC( pRow, 4, szBandEnum );
      hb_arrayAdd( pArray, pRow );
      hb_itemRelease( pRow );
   }
```

- [ ] **Step 7: Add CT_BAND to type-name mapping in UI_GetAllProps region**

Find the `{ CT_WEBVIEW, "TWebView" }` line in hbbridge.cpp type-name table and add:

```c
      { CT_BAND, "TBand" },
```

- [ ] **Step 8: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 9: Commit**

```bash
git add source/cpp/hbbridge.cpp
git commit -m "feat(win): CT_BAND visual control, rulers, UI_BandNew/GetType/SetType, BandStackAll, ControlAlign in bridge"
```

---

### Task 3: ControlAlign dock layout (ApplyDockAlign) in tform.cpp

**Files:**
- Modify: `source/cpp/tform.cpp`

Ports the macOS 5-pass dock layout to Win32. Called on `WM_EXITSIZEMOVE` and at runtime form creation. Does not run in design mode (`FDesignMode`).

- [ ] **Step 1: Add ApplyDockAlign function before TForm::HandleMessage**

In `source/cpp/tform.cpp`, before the `TForm::HandleMessage` function, add:

```c
static void ApplyDockAlign( TForm * form )
{
   if( !form || form->FDesignMode || !form->FHandle ) return;

   RECT rcClient;
   GetClientRect( form->FHandle, &rcClient );

   int cTop    = form->FClientTop;
   int cBottom = rcClient.bottom;
   int cLeft   = 0;
   int cRight  = rcClient.right;

   /* Pass 1 — alTop */
   for( int i = 0; i < form->FChildCount; i++ )
   {
      TControl * c = form->FChildren[i];
      if( !c || c->FDockAlign != ALIGN_TOP || !c->FHandle ) continue;
      c->FLeft  = cLeft;
      c->FTop   = cTop;
      c->FWidth = cRight - cLeft;
      SetWindowPos( c->FHandle, NULL, cLeft, cTop, cRight - cLeft, c->FHeight,
         SWP_NOZORDER | SWP_NOACTIVATE );
      cTop += c->FHeight;
   }
   /* Pass 2 — alBottom */
   for( int i = form->FChildCount - 1; i >= 0; i-- )
   {
      TControl * c = form->FChildren[i];
      if( !c || c->FDockAlign != ALIGN_BOTTOM || !c->FHandle ) continue;
      int vy = cBottom - c->FHeight;
      c->FLeft  = cLeft;
      c->FTop   = vy;
      c->FWidth = cRight - cLeft;
      SetWindowPos( c->FHandle, NULL, cLeft, vy, cRight - cLeft, c->FHeight,
         SWP_NOZORDER | SWP_NOACTIVATE );
      cBottom -= c->FHeight;
   }
   /* Pass 3 — alLeft */
   for( int i = 0; i < form->FChildCount; i++ )
   {
      TControl * c = form->FChildren[i];
      if( !c || c->FDockAlign != ALIGN_LEFT || !c->FHandle ) continue;
      c->FLeft   = cLeft;
      c->FTop    = cTop;
      c->FHeight = cBottom - cTop;
      SetWindowPos( c->FHandle, NULL, cLeft, cTop, c->FWidth, cBottom - cTop,
         SWP_NOZORDER | SWP_NOACTIVATE );
      cLeft += c->FWidth;
   }
   /* Pass 4 — alRight */
   for( int i = form->FChildCount - 1; i >= 0; i-- )
   {
      TControl * c = form->FChildren[i];
      if( !c || c->FDockAlign != ALIGN_RIGHT || !c->FHandle ) continue;
      int vx = cRight - c->FWidth;
      c->FLeft   = vx;
      c->FTop    = cTop;
      c->FHeight = cBottom - cTop;
      SetWindowPos( c->FHandle, NULL, vx, cTop, c->FWidth, cBottom - cTop,
         SWP_NOZORDER | SWP_NOACTIVATE );
      cRight -= c->FWidth;
   }
   /* Pass 5 — alClient (fills remaining area) */
   for( int i = 0; i < form->FChildCount; i++ )
   {
      TControl * c = form->FChildren[i];
      if( !c || c->FDockAlign != ALIGN_CLIENT || !c->FHandle ) continue;
      c->FLeft   = cLeft;
      c->FTop    = cTop;
      c->FWidth  = cRight - cLeft;
      c->FHeight = cBottom - cTop;
      SetWindowPos( c->FHandle, NULL, cLeft, cTop, cRight - cLeft, cBottom - cTop,
         SWP_NOZORDER | SWP_NOACTIVATE );
   }
}
```

- [ ] **Step 2: Call ApplyDockAlign in WM_EXITSIZEMOVE**

In `TForm::HandleMessage`, find the `WM_EXITSIZEMOVE` case. Add a call to `ApplyDockAlign`:

```c
      case WM_EXITSIZEMOVE:
         ApplyDockAlign( this );
         /* ... existing code ... */
```

If there is no `WM_EXITSIZEMOVE` case, find where OnResize is fired (after `WM_SIZE` where `FDesignMode` is false) and add the call there.

- [ ] **Step 3: Call ApplyDockAlign on form show (WM_CREATE or UI_FormShow)**

In `UI_FormShow` or after `UI_FormRun` creates the window, find where the form becomes visible and add:

```c
   ApplyDockAlign( (TForm *) p );
```

The easiest place is in `hbbridge.cpp` where `UI_FORMSHOW` or `UI_FORMRUN` is implemented: after `ShowWindow( p->FHandle, SW_SHOW )`, add:

```c
   ApplyDockAlign( (TForm *) p );
```

Also call it from `UI_SetProp` when `nControlAlign` is set, after `p->FDockAlign = hb_parni(3)`:

```c
   /* Re-run layout immediately if this control has a form parent */
   if( p->FCtrlParent && p->FCtrlParent->FControlType == CT_FORM )
      ApplyDockAlign( (TForm *) p->FCtrlParent );
```

Since `ApplyDockAlign` is defined in `tform.cpp`, add a forward declaration at the top of `hbbridge.cpp`:

```c
/* Forward declaration — defined in tform.cpp */
class TForm;
void ApplyDockAlign( TForm * form );
```

- [ ] **Step 4: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit**

```bash
git add source/cpp/tform.cpp source/cpp/hbbridge.cpp
git commit -m "feat(win): ApplyDockAlign 5-pass layout (alTop/Bottom/Left/Right/Client)"
```

---

### Task 4: Harbour PRG — BAND/REPORTFIELD code gen, restore, palette, run detection

**Files:**
- Modify: `source/hbbuilder_win.prg`

Ports 6 sub-features from macOS PRG to Windows PRG:
1. CT_BAND in palette (Printing tab)
2. CT_BAND in IsNonVisual() (must return .F.)
3. CT_BAND in ComponentTypeName() and naming array
4. Band auto-resize form on first band drop + ControlAlign code gen/restore
5. RegenerateFormCode: emit BAND + REPORTFIELD lines
6. RestoreFormFromCode: parse BAND + REPORTFIELD lines
7. Run detection: form with CT_BAND → TReport:Print()

- [ ] **Step 1: Add CT_BAND to Printing palette tab**

Find the line `oPal:AddComp( nTab, "Prt", "Printer", 102 )` in `hbbuilder_win.prg` (around line 494).

After the `BPr` / BarcodePrinter line, add:

```harbour
   oPal:AddComp( nTab, "Bnd",  "Band",          132 )
```

- [ ] **Step 2: Fix IsNonVisual to exclude CT_BAND**

Find `static function IsNonVisual( nType )` (around line 5166). The function currently checks `nType == 62 .or. ( nType >= 79 .and. nType <= 86 )`. Add CT_BAND (132) to the visual exclusion:

```harbour
static function IsNonVisual( nType )
   // Visual controls that should not use COMPONENT syntax
   // CT_BROWSE=79..CT_DBIMAGE=86, CT_WEBVIEW=62, CT_BAND=132
   if nType == 62 .or. ( nType >= 79 .and. nType <= 86 ) .or. nType == 132
      return .F.
   endif
return nType >= 38
```

- [ ] **Step 3: Add CT_BAND to ComponentTypeName (for inspector/debug use)**

Find `static function ComponentTypeName( nType )` (around line 5176). Add before the `endcase`:

```harbour
      case nType == 132; return "CT_BAND"
```

- [ ] **Step 4: Add CT_BAND to naming array and aNames counter**

In the large `do case` block for naming (around line 1402), add:

```harbour
      case nType == 132; cName := "Band"          + LTrim(Str(aCnt[nType]))
```

The `aCnt` array is `array( 200 )` — CT_BAND = 132 is within range, no change needed.

- [ ] **Step 5: Add CT_BAND to ComponentTypeFromName and type-name mapping**

Find the `{ "CT_BAND", 132 }` entry. It may already exist in the macOS-shared section. If not, find the `aNames` array (around line 5221 area) and add:

```harbour
      { "CT_BAND", 132 }, ;
```

- [ ] **Step 6: Add BAND case to RegenerateFormCode**

In `RegenerateFormCode`, find the `case nType == 80  // Browse` block (around line 919). After the Browse block and before `otherwise`, add:

```harbour
            case nType == 132  // Band
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BAND ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "cBandType" )
               if ! Empty( cVal ) .and. cVal != "Detail"
                  cCreate += ' TYPE "' + cVal + '"'
               endif
               cCreate += e
               // Emit REPORTFIELD lines for each field stored in this band
               cBandFields := UI_GetProp( hCtrl, "aData" )
               if ! Empty( cBandFields )
                  aBandField := hb_ATokens( cBandFields, Chr(10) )
                  for kk := 1 to Len( aBandField )
                     cBandFldLine := AllTrim( aBandField[kk] )
                     if Empty( cBandFldLine ); loop; endif
                     aBandRec := hb_ATokens( cBandFldLine, "|" )
                     // name|type|text|field|format|top|left|w|h|font|fontsize|bold|italic|align
                     if Len( aBandRec ) >= 14
                        cCreate += '   REPORTFIELD ::o' + aBandRec[1] + ;
                           ' TYPE "' + aBandRec[2] + '"'
                        if ! Empty( aBandRec[3] )
                           cCreate += ' PROMPT "' + aBandRec[3] + '"'
                        endif
                        if ! Empty( aBandRec[4] )
                           cCreate += ' FIELD "' + aBandRec[4] + '"'
                        endif
                        if ! Empty( aBandRec[5] )
                           cCreate += ' FORMAT "' + aBandRec[5] + '"'
                        endif
                        cCreate += ' OF ::o' + cCtrlName + ;
                           ' AT ' + aBandRec[6] + ',' + aBandRec[7] + ;
                           ' SIZE ' + aBandRec[8] + ',' + aBandRec[9]
                        if aBandRec[10] != "Sans" .or. Val(aBandRec[11]) != 10
                           cCreate += ' FONT "' + aBandRec[10] + '",' + aBandRec[11]
                        endif
                        if aBandRec[12] == "1"; cCreate += ' BOLD';   endif
                        if aBandRec[13] == "1"; cCreate += ' ITALIC'; endif
                        if Val(aBandRec[14]) != 0
                           cCreate += ' ALIGN ' + aBandRec[14]
                        endif
                        cCreate += e
                     endif
                  next
               endif
```

Add local variables to `RegenerateFormCode` declaration: `cBandFields`, `aBandField`, `cBandFldLine`, `aBandRec`.

- [ ] **Step 7: Add ControlAlign code gen in RegenerateFormCode**

After the `cCreate += e` that terminates each control's creation line, and before the next iteration, add (inside the loop that iterates controls, after all the control-specific code):

```harbour
            // Emit ControlAlign if non-default (0=alNone)
            cVal := UI_GetProp( hCtrl, "nControlAlign" )
            if ValType( cVal ) == "N" .and. cVal != 0
               cCreate += '   ::o' + cCtrlName + ':ControlAlign := ' + LTrim( Str( cVal ) ) + e
            endif
```

Place this just before the closing of the control loop (before the `next` that ends the child-iteration loop).

- [ ] **Step 8: Add BAND + REPORTFIELD + ControlAlign parsing to RestoreFormFromCode**

In `RestoreFormFromCode`, find the `case " BROWSE " $ Upper( cTrim )` block. After the Browse block, add the BAND case:

```harbour
         case " BAND " $ Upper( cTrim )
            hCtrl := UI_BandNew( hForm, "Detail", nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( 'TYPE "', cTrim )
               if nPos > 0
                  cVal := SubStr( cTrim, nPos + 6 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "cBandType", Left( cVal, nPos2 - 1 ) )
                  endif
               endif
               UI_BandSetLayout( hCtrl )
            endif
```

Also add REPORTFIELD parsing. In the section of `RestoreFormFromCode` where non-`@ ` lines are parsed (the block that handles `COMPONENT`, `::Title :=`, etc.), add BEFORE the `if ! ( Left( cTrim, 2 ) == "@ " )` guard:

```harbour
      // Parse REPORTFIELD lines
      if Left( Upper( cTrim ), 12 ) == "REPORTFIELD "
         local cFldName, cFldType, cFldPrompt, cFldField, cFldFormat, cBandName
         local cFldFont, nFldFontSize, lFldBold, lFldItalic, nFldAlign
         local cFldSerial, cExistFields, hBandCtrl, nLastQ, nQpos, cTail
         cFldName := ""; cFldType := "text"; cFldPrompt := ""; cFldField := ""
         cFldFormat := ""; cBandName := ""; cFldFont := "Sans"; nFldFontSize := 10
         lFldBold := .F.; lFldItalic := .F.; nFldAlign := 0
         // Extract field variable name
         nPos := At( "::o", cTrim )
         if nPos > 0
            cFldName := SubStr( cTrim, nPos + 3 )
            nPos2 := At( " ", cFldName )
            if nPos2 > 0; cFldName := Left( cFldName, nPos2 - 1 ); endif
         endif
         // Extract TYPE "..."
         nPos := At( ' TYPE "', cTrim )
         if nPos > 0
            cFldType := SubStr( cTrim, nPos + 7 )
            nPos2 := At( '"', cFldType )
            if nPos2 > 0; cFldType := Left( cFldType, nPos2 - 1 ); endif
         endif
         // Extract PROMPT "..."
         nPos := At( ' PROMPT "', cTrim )
         if nPos > 0
            cFldPrompt := SubStr( cTrim, nPos + 9 )
            nPos2 := At( '"', cFldPrompt )
            if nPos2 > 0; cFldPrompt := Left( cFldPrompt, nPos2 - 1 ); endif
         endif
         // Extract FIELD "..."
         nPos := At( ' FIELD "', cTrim )
         if nPos > 0
            cFldField := SubStr( cTrim, nPos + 8 )
            nPos2 := At( '"', cFldField )
            if nPos2 > 0; cFldField := Left( cFldField, nPos2 - 1 ); endif
         endif
         // Extract FORMAT "..."
         nPos := At( ' FORMAT "', cTrim )
         if nPos > 0
            cFldFormat := SubStr( cTrim, nPos + 9 )
            nPos2 := At( '"', cFldFormat )
            if nPos2 > 0; cFldFormat := Left( cFldFormat, nPos2 - 1 ); endif
         endif
         // Extract OF ::oBandName
         nPos := At( " OF ::o", cTrim )
         if nPos > 0
            cBandName := SubStr( cTrim, nPos + 7 )
            nPos2 := At( " ", cBandName )
            if nPos2 > 0; cBandName := Left( cBandName, nPos2 - 1 ); endif
         endif
         // Extract AT top, left
         nT := 0; nL := 0
         nPos := At( " AT ", Upper( cTrim ) )
         if nPos > 0
            cVal := AllTrim( SubStr( cTrim, nPos + 4 ) )
            nT := Val( cVal )
            nPos2 := At( ",", cVal )
            if nPos2 > 0; nL := Val( SubStr( cVal, nPos2 + 1 ) ); endif
         endif
         // Extract SIZE w, h
         nW := 80; nH := 14
         nPos := At( " SIZE ", Upper( cTrim ) )
         if nPos > 0
            cVal := AllTrim( SubStr( cTrim, nPos + 6 ) )
            nW := Val( cVal )
            nPos2 := At( ",", cVal )
            if nPos2 > 0; nH := Val( SubStr( cVal, nPos2 + 1 ) ); endif
         endif
         // Extract FONT "name", size
         nPos := At( ' FONT "', cTrim )
         if nPos > 0
            cFldFont := SubStr( cTrim, nPos + 7 )
            nPos2 := At( '"', cFldFont )
            if nPos2 > 0
               cFldFont := Left( cFldFont, nPos2 - 1 )
               cVal := AllTrim( SubStr( cTrim, nPos + 7 + nPos2 ) )
               if Left( cVal, 1 ) == ","
                  nFldFontSize := Val( AllTrim( SubStr( cVal, 2 ) ) )
                  if nFldFontSize < 1; nFldFontSize := 10; endif
               endif
            endif
         endif
         // Extract BOLD/ITALIC (after last quote to avoid false matches in font names)
         nLastQ := 0; nQpos := At( '"', cTrim )
         do while nQpos > 0
            nLastQ += nQpos
            nQpos := At( '"', SubStr( cTrim, nLastQ + 1 ) )
         enddo
         cTail := iif( nLastQ > 0, Upper( SubStr( cTrim, nLastQ + 1 ) ), Upper( cTrim ) )
         lFldBold   := " BOLD"   $ cTail
         lFldItalic := " ITALIC" $ cTail
         // Extract ALIGN n
         nPos := At( " ALIGN ", Upper( cTrim ) )
         if nPos > 0
            nFldAlign := Val( AllTrim( SubStr( cTrim, nPos + 7 ) ) )
         endif
         // Find parent band and append serialized field data
         if ! Empty( cBandName )
            hBandCtrl := 0
            for kk := 1 to UI_GetChildCount( hForm )
               if AllTrim( UI_GetProp( UI_GetChild( hForm, kk ), "cName" ) ) == cBandName
                  hBandCtrl := UI_GetChild( hForm, kk )
                  exit
               endif
            next
            if hBandCtrl != 0
               cFldSerial := StrTran( cFldName,   "|", "" ) + "|" + ;
                  StrTran( cFldType,   "|", "" ) + "|" + ;
                  StrTran( cFldPrompt, "|", "" ) + "|" + ;
                  StrTran( cFldField,  "|", "" ) + "|" + ;
                  StrTran( cFldFormat, "|", "" ) + "|" + ;
                  LTrim(Str(nT)) + "|" + LTrim(Str(nL)) + "|" + ;
                  LTrim(Str(nW)) + "|" + LTrim(Str(nH)) + "|" + ;
                  StrTran( cFldFont, "|", "" ) + "|" + LTrim(Str(nFldFontSize)) + "|" + ;
                  iif( lFldBold, "1", "0" ) + "|" + ;
                  iif( lFldItalic, "1", "0" ) + "|" + ;
                  LTrim(Str(nFldAlign))
               cExistFields := UI_GetProp( hBandCtrl, "aData" )
               if Len( cExistFields ) + Len( cFldSerial ) + 1 < 3900
                  if Empty( cExistFields )
                     UI_SetProp( hBandCtrl, "aData", cFldSerial )
                  else
                     UI_SetProp( hBandCtrl, "aData", cExistFields + Chr(10) + cFldSerial )
                  endif
               endif
            endif
         endif
         loop
      endif
```

**Note:** The `local` declarations for the REPORTFIELD block must be moved to the top of `RestoreFormFromCode` (Harbour requires all locals at function start). Add these to the existing `local` declaration block at the top of `RestoreFormFromCode`:

```harbour
   local cFldName, cFldType, cFldPrompt, cFldField, cFldFormat, cBandName
   local cFldFont, nFldFontSize, lFldBold, lFldItalic, nFldAlign
   local cFldSerial, cExistFields, hBandCtrl, nLastQ, nQpos, cTail, cBandFields
   local aBandField, cBandFldLine, aBandRec
```

- [ ] **Step 9: Parse ControlAlign restore in RestoreFormFromCode**

In the second pass of `RestoreFormFromCode` where `::oCtrlName:Prop :=` assignments are parsed, add (in the block that reads `lInCreateForm` assignments):

```harbour
         if ":ControlAlign :=" $ cTrim .and. "::o" $ cTrim
            nPos := At( "::o", cTrim )
            if nPos > 0
               cName := SubStr( cTrim, nPos + 3 )
               nPos2 := At( ":", cName )
               if nPos2 > 0; cName := Left( cName, nPos2 - 1 ); endif
               // Find control by name
               for kk := 1 to UI_GetChildCount( hForm )
                  if AllTrim( UI_GetProp( UI_GetChild( hForm, kk ), "cName" ) ) == cName
                     UI_SetProp( UI_GetChild( hForm, kk ), "nControlAlign", ;
                        Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
                     exit
                  endif
               next
            endif
            loop
         endif
```

- [ ] **Step 10: Band auto-resize form on first band drop**

In `hbbuilder_win.prg`, find the function that handles palette item drop onto the design form (the drop handler where `UI_BandNew` will be called, which now happens when nType == 132 is dropped). This logic is in the existing palette drop / `TBNew` / control drop logic.

Find where new controls are added to the design form (search for `UI_DropNonVisual` or the control creation dispatch based on `nType`). In the Windows PRG, palette drops go through `OnPaletteDrop` or similar. Find where nType == 132 creates the band, and add auto-resize logic:

```harbour
         if nType == 132
            // Check if this is the first band
            local nBandCount := 0
            local iBand
            for iBand := 1 to UI_GetChildCount( hDesign )
               if UI_GetType( UI_GetChild( hDesign, iBand ) ) == 132
                  nBandCount++
               endif
            next
            hCtrl := UI_BandNew( hDesign, "Detail", 20, 20, UI_GetProp(hDesign,"nWidth") - 20, 65 )
            if hCtrl != 0
               // Auto-rename form and resize on first band
               if nBandCount == 0
                  UI_SetProp( hDesign, "cText", "Report" )
                  UI_SetProp( hDesign, "nWidth", 850 )
                  UI_SetProp( hDesign, "nHeight", 450 )
               endif
               UI_BandSetLayout( hCtrl )
            endif
         endif
```

Identify the exact location by searching for how other controls (e.g. CT_TIMER) are created on drop and mirror the pattern.

- [ ] **Step 11: Run detection — form with bands calls TReport:Print()**

Find the `TBRun()` function (or equivalent Run button handler) in `hbbuilder_win.prg`. At the top of the function body, add (after loading the active form handle):

```harbour
   // If the active form is a report (has bands), print instead of compile+run
   local hRunForm, nRunCount, hRunCtrl, oRunReport, oRunBand, cRunType, nRunH
   if nActiveForm > 0 .and. nActiveForm <= Len( aForms ) .and. ;
      aForms[ nActiveForm ][ 2 ] != nil
      hRunForm  := aForms[ nActiveForm ][ 2 ]:hCpp
      nRunCount := UI_GetChildCount( hRunForm )
      for i := 1 to nRunCount
         hRunCtrl := UI_GetChild( hRunForm, i )
         if UI_GetType( hRunCtrl ) == 132  // CT_BAND
            if oRunReport == nil
               oRunReport := TReport():New()
               oRunReport:nPageWidth  := UI_GetProp( hRunForm, "nWidth" )
               oRunReport:nPageHeight := UI_GetProp( hRunForm, "nHeight" )
            endif
            cRunType := UI_GetProp( hRunCtrl, "cBandType" )
            nRunH    := UI_GetProp( hRunCtrl, "nHeight" )
            oRunBand := TBand():New( nil, cRunType, nRunH )
            oRunReport:AddDesignBand( oRunBand )
         endif
      next
      if oRunReport != nil
         oRunReport:Print()
         return nil
      endif
   endif
```

These `local` declarations must go at the top of `TBRun()`.

- [ ] **Step 12: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 13: Commit**

```bash
git add source/hbbuilder_win.prg
git commit -m "feat(win): BAND/REPORTFIELD code gen+restore, palette entry, ControlAlign, auto-resize, report run"
```

---

### Task 5: Inspector — "..." multiline editor for all string properties

**Files:**
- Modify: `source/inspector/inspector_win.prg`

Currently, the `"..."` button in the Inspector only appears for `cFileName` (file picker) and `cType == 'C'` / `'F'` / `'A'`. The macOS inspector shows a multiline NSTextView dialog for ANY string (`'S'`) property. Port this: for any `'S'` property that is NOT `cFileName`, show a dialog with a multiline `EDIT` control.

- [ ] **Step 1: Extend bNeedsBtn to all string properties**

In `inspector_win.prg`, find the `bNeedsBtn` assignment (around line 1244):

```c
   bNeedsBtn = ( d->rows[nReal].cType == 'C' ||
                 d->rows[nReal].cType == 'F' ||
                 d->rows[nReal].cType == 'A' ||
                 ( d->rows[nReal].cType == 'S' &&
                   lstrcmpiA( d->rows[nReal].szName, "cFileName" ) == 0 ) );
```

Replace with:

```c
   bNeedsBtn = ( d->rows[nReal].cType == 'C' ||
                 d->rows[nReal].cType == 'F' ||
                 d->rows[nReal].cType == 'A' ||
                 d->rows[nReal].cType == 'S' );
```

- [ ] **Step 2: Add multiline string editor dialog procedure**

Near the top of the C section in `inspector_win.prg`, add:

```c
/* Multiline string editor dialog */
typedef struct { char szValue[4096]; } MLEDITDATA;

static LRESULT CALLBACK MLEditDlgProc( HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam )
{
   MLEDITDATA * pMD;
   if( msg == WM_INITDIALOG )
   {
      pMD = (MLEDITDATA *) lParam;
      SetWindowLongPtr( hDlg, GWLP_USERDATA, (LONG_PTR) pMD );
      HWND hEdit = GetDlgItem( hDlg, 101 );
      SetWindowTextA( hEdit, pMD->szValue );
      SetFocus( hEdit );
      SendMessage( hEdit, EM_SETSEL, 0, -1 );
      return FALSE;
   }
   if( msg == WM_COMMAND )
   {
      int id = LOWORD( wParam );
      if( id == IDOK )
      {
         pMD = (MLEDITDATA *) GetWindowLongPtr( hDlg, GWLP_USERDATA );
         HWND hEdit = GetDlgItem( hDlg, 101 );
         GetWindowTextA( hEdit, pMD->szValue, sizeof(pMD->szValue) );
         EndDialog( hDlg, IDOK );
      }
      else if( id == IDCANCEL )
         EndDialog( hDlg, IDCANCEL );
   }
   return FALSE;
}

static int ShowMLEditDialog( HWND hParent, char * szValue, int nMaxLen )
{
   /* Build dialog template in memory */
   #pragma pack(push, 4)
   struct {
      DLGTEMPLATE tmpl;
      WORD        menu, cls, title[1];
      WORD        pointsize;
      WCHAR       typeface[9];  /* "MS Shell" terminator */
      /* Items */
      DLGITEMTEMPLATE edit;
      WORD            editCls[2], editTitle[1], editExtra;
      DLGITEMTEMPLATE btnOk;
      WORD            btnOkCls[2], btnOkTitle[5], btnOkExtra;
      DLGITEMTEMPLATE btnCancel;
      WORD            btnCancelCls[2], btnCancelTitle[7], btnCancelExtra;
   } dlg;
   #pragma pack(pop)

   /* Build programmatically instead — use CreateDialog with a resource-like approach.
      Simplest: create a top-level window manually. */
   HWND hDlg = CreateWindowExA( WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
      "STATIC", "Edit Text",
      WS_POPUP | WS_CAPTION | WS_SYSMENU,
      100, 100, 440, 280,
      hParent, NULL, GetModuleHandleA(NULL), NULL );
   if( !hDlg ) return IDCANCEL;

   /* Multiline edit */
   HWND hEdit = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", szValue,
      WS_CHILD | WS_VISIBLE | WS_VSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN,
      10, 10, 410, 200, hDlg, (HMENU) 101, GetModuleHandleA(NULL), NULL );

   /* OK button */
   HWND hOK = CreateWindowExA( 0, "BUTTON", "OK",
      WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
      250, 220, 80, 26, hDlg, (HMENU) IDOK, GetModuleHandleA(NULL), NULL );

   /* Cancel button */
   HWND hCancel = CreateWindowExA( 0, "BUTTON", "Cancel",
      WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
      340, 220, 80, 26, hDlg, (HMENU) IDCANCEL, GetModuleHandleA(NULL), NULL );

   SetFocus( hEdit );
   SendMessage( hEdit, EM_SETSEL, 0, -1 );

   ShowWindow( hDlg, SW_SHOW );
   UpdateWindow( hDlg );

   /* Modal message loop */
   int nResult = IDCANCEL;
   MSG msg;
   while( GetMessage( &msg, NULL, 0, 0 ) )
   {
      if( msg.message == WM_COMMAND && msg.hwnd == hDlg )
      {
         int id = LOWORD( msg.wParam );
         if( id == IDOK )
         {
            GetWindowTextA( hEdit, szValue, nMaxLen );
            nResult = IDOK;
            break;
         }
         else if( id == IDCANCEL ) break;
      }
      else if( msg.message == WM_COMMAND && (msg.hwnd == hOK || msg.hwnd == hCancel) )
      {
         int id = (int)(INT_PTR) GetMenu( msg.hwnd );
         if( id == IDOK )
         {
            GetWindowTextA( hEdit, szValue, nMaxLen );
            nResult = IDOK;
            break;
         }
         else if( id == IDCANCEL ) break;
      }
      else if( msg.message == WM_KEYDOWN && msg.wParam == VK_ESCAPE ) break;
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }

   DestroyWindow( hDlg );
   return nResult;
}
```

- [ ] **Step 3: Route string "..." clicks to ShowMLEditDialog**

In `InsBtnProc` (the button subclass WndProc), find where the existing `'A'` array editor and `'C'` color picker are handled. Add a new branch for `'S'`:

```c
   else if( d->rows[nReal].cType == 'S' &&
            lstrcmpiA( d->rows[nReal].szName, "cFileName" ) != 0 )
   {
      /* Multiline string editor */
      char szVal[4096];
      lstrcpynA( szVal, d->rows[nReal].szValue, sizeof(szVal) );
      if( ShowMLEditDialog( d->hWnd, szVal, sizeof(szVal) - 1 ) == IDOK )
      {
         lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
         InsApplyValue( d, nReal, szVal );
         InsRebuild( d );
      }
   }
```

- [ ] **Step 4: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit**

```bash
git add source/inspector/inspector_win.prg
git commit -m "feat(win): Inspector multiline string editor for all string properties"
```

---

### Task 6: ChangeLog + final build + push

**Files:**
- Modify: `ChangeLog.txt`

- [ ] **Step 1: Add ChangeLog entry**

At the top of `ChangeLog.txt`, add:

```
2026-04-18 (Windows — macOS parity: bands, ControlAlign, REPORTFIELD, inspector)

  REPORT DESIGNER (Windows):
  - CT_BAND (132) visual control: colored rectangle per band type (Header=blue,
    PageHeader/PageFooter=green, Detail=light gray, Footer=gray), centered
    label, bottom hairline. Registered as "HBBandView" Win32 window class.
  - UI_BandNew / UI_BandGetType / UI_BandSetType / UI_BandSetLayout / BandStackAll:
    Windows equivalents of the macOS band functions.
  - BandStackAll(): restacks CT_BAND children of a form in the type order
    (Header→PageHeader→Detail→PageFooter→Footer) starting at y=20 (below ruler),
    x=20 (right of ruler), width = formW-20.
  - HBRulerView: horizontal (20px) + vertical (20px) ruler overlays shown
    whenever at least one CT_BAND child is present. Tick marks every 10px,
    labels every 100px. Corner square at origin. GDI custom-paint.
  - UI_BandRulersUpdate(): creates/removes ruler pair automatically after
    band add/delete on a form.
  - Band default height 65px (matches macOS).
  - Auto-resize: dropping first band resizes form to 850×450, sets title to "Report".
  - Printing palette tab: Band (CT_BAND=132) entry added.
  - RegenerateFormCode: BAND + REPORTFIELD emission (exact same format as macOS).
  - RestoreFormFromCode: BAND and REPORTFIELD parsing (field data serialized
    as pipe-delimited records stored in FData[4096] on the band TControl).
  - Run button: if active form has CT_BAND children, builds TReport from design
    bands and calls TReport:Print() instead of compile+run pipeline.

  CONTROL ALIGN (Windows):
  - FDockAlign field added to TControl (0=alNone..5=alClient).
  - nControlAlign property in UI_SetProp / UI_GetProp / UI_GetAllProps
    (shown as dropdown in Inspector Layout category).
  - ApplyDockAlign(): 5-pass dock layout (Top→Bottom→Left→Right→Client)
    called on WM_EXITSIZEMOVE and form show. Only runs at runtime (not design mode).
  - Code gen emits ::oCtrl:ControlAlign := n for non-zero values.
  - RestoreFormFromCode parses ::oCtrl:ControlAlign := n assignments.

  INSPECTOR (Windows):
  - "..." button now appears for ALL string ('S') properties, not just cFileName.
  - Clicking "..." opens a modal multiline text editor (resizable, multi-line
    EDIT control with OK/Cancel). On OK the value is pushed to the control and
    the code is synced.
```

- [ ] **Step 2: Final build**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 3: Smoke test**
  - Open HarbourBuilder on Windows
  - Drag a Band from Printing palette onto a form → form resizes to 850×450, title becomes "Report", rulers appear
  - Add a second band (type=Detail) → stacks below Header
  - Open Inspector → verify cBandType dropdown shows Header/PageHeader/Detail/PageFooter/Footer
  - Set ControlAlign on a Label to alClient → verify it fills remaining area after Run
  - Open Inspector on any Label's cText → click "..." → multiline editor opens
  - Press Run on a report form → print dialog or TReport:Print() called

- [ ] **Step 4: Commit and push**

```bash
git add ChangeLog.txt
git commit -m "docs: ChangeLog for Windows macOS parity (bands, ControlAlign, inspector)"
git push
```
