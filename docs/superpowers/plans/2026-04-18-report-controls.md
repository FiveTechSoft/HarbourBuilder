# Report Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add visually-placeable ReportLabel (133), ReportField (134), ReportImage (135) controls that live inside bands in the report designer, with full selection, drag, resize, inspector, and serialization support.

**Architecture:** Report controls are TControl subclasses whose HWNDs are children of the band's HBBandView HWND (so they move with the band automatically). They are stored in the form's FChildren with a FBandParent pointer. FLeft/FTop are band-relative. A UI_SyncBandData() function serializes live controls back to band FData before code gen.

**Tech Stack:** Win32, C++, Harbour PRG, existing hbbridge.cpp/tform.cpp/hbbuilder_win.prg patterns.

---

## File Map

| File | Changes |
|---|---|
| `include/hbide.h` | CT_REPORTLABEL=133, CT_REPORTFIELD=134, CT_REPORTIMAGE=135; FBandParent field on TControl |
| `source/cpp/hbbridge.cpp` | HBReportCtrl window class + WM_PAINT; UI_ReportCtrlNew(); UI_SyncBandData(); UI_GetAllProps/SetProp/GetProp for 133-135 |
| `source/cpp/tcontrols.cpp` | CreateControlByType cases for 133/134/135 |
| `source/cpp/tform.cpp` | Drop logic band targeting; HitTest coord translation; PaintSelectionHandles coord translation; drag/resize clamping and HWND update for report controls |
| `source/hbbuilder_win.prg` | Report tab palette entries; OnComponentDrop for 133-135; SyncDesignerToCode calls UI_SyncBandData; RestoreFormFromCode creates visual controls via UI_ReportCtrlNew |

---

## Task 1: CT_ constants and FBandParent

**Files:**
- Modify: `include/hbide.h`

- [ ] **Step 1: Add CT_ constants after CT_BAND**

In `include/hbide.h`, find the line `#define CT_BAND 132` and add immediately after:

```c
#define CT_REPORTLABEL  133
#define CT_REPORTFIELD  134
#define CT_REPORTIMAGE  135
```

- [ ] **Step 2: Add FBandParent to TControl**

In `include/hbide.h`, inside the TControl class definition (around line 273 where FCtrlParent is declared), add:

```c
TControl *   FCtrlParent;
TControl *   FBandParent;   /* non-NULL for report controls; points to owning CT_BAND */
```

- [ ] **Step 3: Initialize FBandParent to NULL in TControl constructor**

In `source/cpp/tcontrol.cpp`, find the TControl constructor body where other fields are zeroed (e.g. near `FCtrlParent = NULL`) and add:

```cpp
FBandParent = NULL;
```

- [ ] **Step 4: Commit**

```bash
git add include/hbide.h source/cpp/tcontrol.cpp
git commit -m "feat: CT_REPORTLABEL/FIELD/IMAGE constants; FBandParent on TControl"
```

---

## Task 2: HBReportCtrl Win32 window class

**Files:**
- Modify: `source/cpp/hbbridge.cpp`

The existing `RegisterBandClasses()` function in hbbridge.cpp (around line 123) registers HBBandView and HBRulerView. We extend it to also register HBReportCtrl.

- [ ] **Step 1: Add ReportCtrlWndProc before RegisterBandClasses()**

In `source/cpp/hbbridge.cpp`, immediately before the `static void RegisterBandClasses()` function, add:

```cpp
static LRESULT CALLBACK ReportCtrlWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_PAINT )
   {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint( hWnd, &ps );
      RECT rc;
      GetClientRect( hWnd, &rc );
      TControl * p = (TControl *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

      /* White background */
      HBRUSH hBr = CreateSolidBrush( RGB(255,255,255) );
      FillRect( hdc, &rc, hBr );
      DeleteObject( hBr );

      /* Blue dashed border */
      HPEN hPen = CreatePen( PS_DASH, 1, RGB(0,100,220) );
      HPEN hOld = (HPEN) SelectObject( hdc, hPen );
      SelectObject( hdc, GetStockObject(NULL_BRUSH) );
      Rectangle( hdc, rc.left, rc.top, rc.right-1, rc.bottom-1 );
      SelectObject( hdc, hOld );
      DeleteObject( hPen );

      if( p )
      {
         BYTE ct = p->FControlType;
         SetBkMode( hdc, TRANSPARENT );
         HFONT hFont = CreateFontA( -11, 0, 0, 0,
            FW_NORMAL, ct==CT_REPORTFIELD ? TRUE : FALSE, 0, 0,
            ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
            DEFAULT_QUALITY, DEFAULT_PITCH|FF_SWISS, "Segoe UI" );
         HFONT hFontOld = (HFONT) SelectObject( hdc, hFont );
         SetTextColor( hdc, RGB(30,30,30) );

         if( ct == CT_REPORTLABEL )
         {
            const char * sz = p->FText[0] ? p->FText : "Label";
            DrawTextA( hdc, sz, -1, &rc, DT_CENTER|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS );
         }
         else if( ct == CT_REPORTFIELD )
         {
            char buf[320];
            if( p->FFileName[0] )
               wsprintfA( buf, "[%s]", p->FFileName );
            else if( p->FData[0] )
               wsprintfA( buf, "[%s]", p->FData );
            else
               lstrcpyA( buf, "[field]" );
            DrawTextA( hdc, buf, -1, &rc, DT_CENTER|DT_VCENTER|DT_SINGLELINE|DT_END_ELLIPSIS );
         }
         else /* CT_REPORTIMAGE */
         {
            HPEN hPDiag = CreatePen( PS_SOLID, 1, RGB(180,180,180) );
            SelectObject( hdc, hPDiag );
            MoveToEx( hdc, rc.left+2, rc.top+2, NULL );
            LineTo( hdc, rc.right-2, rc.bottom-2 );
            MoveToEx( hdc, rc.right-2, rc.top+2, NULL );
            LineTo( hdc, rc.left+2, rc.bottom-2 );
            DeleteObject( hPDiag );
         }
         SelectObject( hdc, hFontOld );
         DeleteObject( hFont );
      }
      EndPaint( hWnd, &ps );
      return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}
```

- [ ] **Step 2: Register HBReportCtrl inside RegisterBandClasses()**

In the existing `RegisterBandClasses()` body (after the HBRulerView RegisterClassA call), add:

```cpp
   wc.style         = CS_HREDRAW | CS_VREDRAW;
   wc.lpfnWndProc   = ReportCtrlWndProc;
   wc.hInstance     = hInst;
   wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
   wc.hbrBackground = NULL;
   wc.lpszClassName = "HBReportCtrl";
   RegisterClassA( &wc );
```

- [ ] **Step 3: Commit**

```bash
git add source/cpp/hbbridge.cpp
git commit -m "feat: HBReportCtrl Win32 window class with WM_PAINT for label/field/image"
```

---

## Task 3: UI_ReportCtrlNew and UI_SyncBandData

**Files:**
- Modify: `source/cpp/hbbridge.cpp`

- [ ] **Step 1: Add UI_ReportCtrlNew after UI_BandNew (around line 835)**

```cpp
/* UI_ReportCtrlNew( hForm, hBand, nCtrlType, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_REPORTCTRLNEW )
{
   TForm    * pForm = (TForm *)    GetCtrl(1);
   TControl * pBand = (TControl *) GetCtrl(2);
   int ct   = hb_parni(3);
   int nL   = hb_parni(4), nT = hb_parni(5);
   int nW   = hb_parni(6), nH = hb_parni(7);

   if( !pForm || !pBand ) { hb_retnint(0); return; }
   RegisterBandClasses();

   TControl * p = new TControl();
   p->FControlType = (BYTE) ct;
   p->FBandParent  = pBand;
   p->FLeft  = nL;
   p->FTop   = nT;
   p->FWidth  = nW < 10 ? 120 : nW;
   p->FHeight = nH < 6  ? 20  : nH;
   p->FFont   = pForm->FFormFont;
   p->FVisible = TRUE;
   p->FEnabled = TRUE;

   pForm->AddChild( p );

   if( pBand->FHandle )
   {
      p->FHandle = CreateWindowExA( 0, "HBReportCtrl", "",
         WS_CHILD | WS_VISIBLE,
         p->FLeft, p->FTop, p->FWidth, p->FHeight,
         pBand->FHandle, NULL, GetModuleHandleA(NULL), NULL );
      if( p->FHandle )
         SetWindowLongPtr( p->FHandle, GWLP_USERDATA, (LONG_PTR) p );
   }

   pForm->SelectControl( p, FALSE );
   pForm->SubclassChildren();

   hb_retnint( (HB_PTRUINT) p );
}
```

- [ ] **Step 2: Add UI_SyncBandData after UI_ReportCtrlNew**

This function walks the form's FChildren, groups report controls by FBandParent, and rebuilds each band's FData string. Call it before code gen.

```cpp
/* UI_SyncBandData( hForm ) — rebuild FData on every band from live report controls */
HB_FUNC( UI_SYNCBANDDATA )
{
   TForm * pForm = (TForm *) GetCtrl(1);
   if( !pForm ) return;
   int i;

   /* Clear FData on all bands */
   for( i = 0; i < pForm->FChildCount; i++ )
   {
      TControl * c = pForm->FChildren[i];
      if( c && c->FControlType == CT_BAND )
         c->FData[0] = '\0';
   }

   /* Serialize each report control into its band's FData */
   for( i = 0; i < pForm->FChildCount; i++ )
   {
      TControl * p = pForm->FChildren[i];
      if( !p || !p->FBandParent ) continue;

      const char * szType =
         p->FControlType == CT_REPORTLABEL ? "label" :
         p->FControlType == CT_REPORTFIELD ? "field" : "image";

      char rec[600];
      /* Format: cName|type|cText|cFieldName|cFormat|nTop|nLeft|nW|nH|font|sz|bold|italic|align */
      wsprintfA( rec, "%s|%s|%s|%s||%d|%d|%d|%d|Sans|10|0|0|0",
         p->FName[0] ? p->FName : "rctrl",
         szType,
         p->FText,
         p->FControlType == CT_REPORTFIELD ? p->FFileName : "",
         p->FTop, p->FLeft, p->FWidth, p->FHeight );

      TControl * pBand = p->FBandParent;
      int curLen = lstrlenA( pBand->FData );
      int recLen = lstrlenA( rec );
      if( curLen + recLen + 2 < (int)sizeof(pBand->FData) )
      {
         if( curLen > 0 )
         {
            pBand->FData[curLen] = '\n';
            lstrcpyA( pBand->FData + curLen + 1, rec );
         }
         else
            lstrcpyA( pBand->FData, rec );
      }
   }
}
```

Note: `FName` is an existing field on TControl (used for cName). If it doesn't exist, use `FText` for the name field in the serialized record, or add a char FName[64] field. Check tcontrol.cpp — if FName is absent, use FText and store the control name there during OnComponentDrop.

- [ ] **Step 3: Commit**

```bash
git add source/cpp/hbbridge.cpp
git commit -m "feat: UI_ReportCtrlNew creates visual report ctrl in band; UI_SyncBandData serializes to FData"
```

---

## Task 4: CreateControlByType for report controls

**Files:**
- Modify: `source/cpp/tcontrols.cpp`

- [ ] **Step 1: Add cases for 133/134/135 in CreateControlByType**

In `source/cpp/tcontrols.cpp`, in the `CreateControlByType` switch (around line 1796, before the closing `}`), add:

```cpp
      case CT_REPORTLABEL:
      case CT_REPORTFIELD:
      case CT_REPORTIMAGE:
      {
         TControl * p = new TControl();
         p->FControlType = (BYTE) bType;
         p->FWidth  = (bType == CT_REPORTIMAGE) ? 80 : 120;
         p->FHeight = (bType == CT_REPORTIMAGE) ? 60 : 20;
         return p;
      }
```

- [ ] **Step 2: Commit**

```bash
git add source/cpp/tcontrols.cpp
git commit -m "feat: CreateControlByType handles CT_REPORTLABEL/FIELD/IMAGE"
```

---

## Task 5: Drop logic — band targeting in tform.cpp

**Files:**
- Modify: `source/cpp/tform.cpp`

The rubber-band drop code in `WM_LBUTTONUP` (around line 1296) creates a TControl and then builds its HWND as a child of the form. For report controls, we need the HWND parented to the band instead.

- [ ] **Step 1: Add band-targeting block after CreateControlByType in WM_LBUTTONUP**

Find the block in WM_LBUTTONUP that starts:
```cpp
TControl * newCtrl = CreateControlByType( (BYTE) ctrlType );
if( newCtrl )
{
   newCtrl->FLeft = rx1;
   newCtrl->FTop = ry1;
```

Replace the entire `if(newCtrl)` block with:

```cpp
               TControl * newCtrl = CreateControlByType( (BYTE) ctrlType );
               BOOL bIsReportCtrl = ( ctrlType == CT_REPORTLABEL ||
                                      ctrlType == CT_REPORTFIELD ||
                                      ctrlType == CT_REPORTIMAGE );

               if( newCtrl && bIsReportCtrl )
               {
                  /* Find band under drop point */
                  TControl * pBand = NULL;
                  { int j;
                    for( j = 0; j < FChildCount; j++ )
                    {
                       TControl * pB = FChildren[j];
                       if( pB && pB->FControlType == CT_BAND &&
                           rx1 >= pB->FLeft && rx1 < pB->FLeft + pB->FWidth &&
                           ry1 >= pB->FTop  && ry1 < pB->FTop  + pB->FHeight )
                       { pBand = pB; break; }
                    }
                  }
                  if( !pBand )
                  {
                     delete newCtrl;
                     newCtrl = NULL;
                  }
                  else
                  {
                     newCtrl->FBandParent = pBand;
                     newCtrl->FLeft   = rx1 - pBand->FLeft;
                     newCtrl->FTop    = ry1 - pBand->FTop;
                     newCtrl->FWidth  = rw;
                     newCtrl->FHeight = rh;
                     newCtrl->FFont   = FFormFont;
                     AddChild( newCtrl );

                     if( pBand->FHandle )
                     {
                        newCtrl->FHandle = CreateWindowExA( 0, "HBReportCtrl", "",
                           WS_CHILD | WS_VISIBLE,
                           newCtrl->FLeft, newCtrl->FTop,
                           newCtrl->FWidth, newCtrl->FHeight,
                           pBand->FHandle, NULL, GetModuleHandle(NULL), NULL );
                        if( newCtrl->FHandle )
                           SetWindowLongPtr( newCtrl->FHandle, GWLP_USERDATA, (LONG_PTR) newCtrl );
                     }
                     SelectControl( newCtrl, FALSE );
                     SubclassChildren();
                  }
               }
               else if( newCtrl )
               {
                  newCtrl->FLeft = rx1;
                  newCtrl->FTop = ry1;
                  newCtrl->FWidth = rw;
                  newCtrl->FHeight = rh;
                  newCtrl->FFont = FFormFont;

                  if( ctrlType != CT_TABCONTROL2 )
                  {
                     extern void HbSetPendingPageOwner( TControl *, int );
                     int j;
                     for( j = 0; j < FChildCount; j++ )
                     {
                        TControl * pF = FChildren[j];
                        if( pF && pF->FControlType == CT_TABCONTROL2 &&
                            rx1 >= pF->FLeft && rx1 < pF->FLeft + pF->FWidth &&
                            ry1 >= pF->FTop  && ry1 < pF->FTop  + pF->FHeight )
                        {
                           int nPage = pF->FHandle
                              ? (int) SendMessageA( pF->FHandle, TCM_GETCURSEL, 0, 0 )
                              : 0;
                           HbSetPendingPageOwner( pF, nPage < 0 ? 0 : nPage );
                           break;
                        }
                     }
                  }
                  AddChild( newCtrl );

                  if( FHandle )
                  {
                     DWORD dwStyle, dwExStyle;
                     const char * szClass;
                     newCtrl->CreateParams( &dwStyle, &dwExStyle, &szClass );
                     newCtrl->FHandle = CreateWindowExA( dwExStyle, szClass,
                        newCtrl->FText, dwStyle,
                        newCtrl->FLeft, newCtrl->FTop + FClientTop,
                        newCtrl->FWidth, newCtrl->FHeight,
                        FHandle, NULL, GetModuleHandle(NULL), NULL );
                     if( newCtrl->FHandle && newCtrl->FFont )
                        SendMessage( newCtrl->FHandle, WM_SETFONT,
                           (WPARAM) newCtrl->FFont, TRUE );
                  }

                  SelectControl( newCtrl, FALSE );
                  SubclassChildren();
               }

               /* Fire OnComponentDrop — runs even when newCtrl is NULL (CT_BAND via UI_BandNew) */
               if( FOnComponentDrop && HB_IS_BLOCK( FOnComponentDrop ) )
               {
                  hb_vmPushEvalSym();
                  hb_vmPush( FOnComponentDrop );
                  hb_vmPushNumInt( (HB_PTRUINT) this );
                  hb_vmPushInteger( ctrlType );
                  hb_vmPushInteger( rx1 );
                  hb_vmPushInteger( ry1 );
                  hb_vmPushInteger( rw );
                  hb_vmPushInteger( rh );
                  hb_vmSend( 6 );
                  SubclassChildren();
               }
```

- [ ] **Step 2: Commit**

```bash
git add source/cpp/tform.cpp
git commit -m "feat: report control drop targets band by position; HWND parented to band HWND"
```

---

## Task 6: HitTest and PaintSelectionHandles coordinate translation

**Files:**
- Modify: `source/cpp/tform.cpp`

Report controls have FLeft/FTop in band-relative coords. HitTest and PaintSelectionHandles must translate to form-absolute before comparing with mouse coords.

- [ ] **Step 1: Update HitTest to use absolute coords for report controls**

In `TForm::HitTest` (around line 1906), the loop reads:
```cpp
int l = p->FLeft, t = p->FTop, r = l + p->FWidth, b = t + p->FHeight;
if( x >= l && x <= r && y >= t && y <= b )
```

Replace those two lines with:
```cpp
int l = p->FBandParent ? p->FBandParent->FLeft + p->FLeft : p->FLeft;
int t = p->FBandParent ? p->FBandParent->FTop  + p->FTop  : p->FTop;
int r = l + p->FWidth, b = t + p->FHeight;
if( x >= l && x <= r && y >= t && y <= b )
```

- [ ] **Step 2: Update HitTestHandle to use absolute coords for report controls**

In `TForm::HitTestHandle` (around line 1940), the line:
```cpp
int px = p->FLeft, py = p->FTop, pw = p->FWidth, ph = p->FHeight;
```

Replace with:
```cpp
int px = p->FBandParent ? p->FBandParent->FLeft + p->FLeft : p->FLeft;
int py = p->FBandParent ? p->FBandParent->FTop  + p->FTop  : p->FTop;
int pw = p->FWidth, ph = p->FHeight;
```

- [ ] **Step 3: Update PaintSelectionHandles to use absolute coords for report controls**

In `TForm::PaintSelectionHandles` (around line 2022), the line:
```cpp
int x = p->FLeft, y = p->FTop + FClientTop, w = p->FWidth, h = p->FHeight;
```

Replace with:
```cpp
int absL = p->FBandParent ? p->FBandParent->FLeft + p->FLeft : p->FLeft;
int absT = p->FBandParent ? p->FBandParent->FTop  + p->FTop  : p->FTop;
int x = absL, y = absT + FClientTop, w = p->FWidth, h = p->FHeight;
```

- [ ] **Step 4: Commit**

```bash
git add source/cpp/tform.cpp
git commit -m "feat: HitTest/HitTestHandle/PaintSelectionHandles translate band-relative coords to form-absolute"
```

---

## Task 7: Drag and resize for report controls

**Files:**
- Modify: `source/cpp/tform.cpp`

When dragging or resizing a report control, FLeft/FTop are band-relative. The HWND parent is the band, so SetWindowPos/MoveWindow also uses band-relative coords (no FClientTop offset). Clamp to band bounds.

- [ ] **Step 1: Update WM_MOUSEMOVE drag section**

In the drag section of WM_MOUSEMOVE (around line 1193), the per-control move code:
```cpp
p->FLeft += dx;
p->FTop += dy;
if( p->FHandle )
{
   MoveWindow( p->FHandle, p->FLeft, p->FTop + FClientTop,
      p->FWidth, p->FHeight, TRUE );
   UpdateWindow( p->FHandle );
}
```

Replace with:
```cpp
p->FLeft += dx;
p->FTop  += dy;
if( p->FBandParent )
{
   /* Clamp to band bounds */
   if( p->FLeft < 0 ) p->FLeft = 0;
   if( p->FTop  < 0 ) p->FTop  = 0;
   if( p->FLeft + p->FWidth  > p->FBandParent->FWidth  ) p->FLeft = p->FBandParent->FWidth  - p->FWidth;
   if( p->FTop  + p->FHeight > p->FBandParent->FHeight ) p->FTop  = p->FBandParent->FHeight - p->FHeight;
   if( p->FHandle )
      MoveWindow( p->FHandle, p->FLeft, p->FTop, p->FWidth, p->FHeight, TRUE );
}
else if( p->FHandle )
{
   MoveWindow( p->FHandle, p->FLeft, p->FTop + FClientTop,
      p->FWidth, p->FHeight, TRUE );
   UpdateWindow( p->FHandle );
}
```

- [ ] **Step 2: Update WM_MOUSEMOVE resize section**

In the resize section of WM_MOUSEMOVE (around line 1162), the SetWindowPos line:
```cpp
if( p->FHandle )
   SetWindowPos( p->FHandle, NULL, nl, nt + FClientTop, nw, nh, SWP_NOZORDER );
```

Replace with:
```cpp
if( p->FHandle )
{
   if( p->FBandParent )
      SetWindowPos( p->FHandle, NULL, nl, nt, nw, nh, SWP_NOZORDER );
   else
      SetWindowPos( p->FHandle, NULL, nl, nt + FClientTop, nw, nh, SWP_NOZORDER );
}
```

- [ ] **Step 3: Commit**

```bash
git add source/cpp/tform.cpp
git commit -m "feat: drag/resize report controls uses band-relative coords with clamping"
```

---

## Task 8: Inspector — UI_GetAllProps, UI_SetProp, UI_GetProp

**Files:**
- Modify: `source/cpp/hbbridge.cpp`

- [ ] **Step 1: Add cases for 133/134/135 in UI_GetAllProps**

In `UI_GetAllProps` (the function that returns the property array for the inspector), find the switch-case for CT_BAND and add after it:

```cpp
case CT_REPORTLABEL:
{
   hb_reta(5);
   ADD_PROP_S( "cText",     p->FText,   "Text" );
   ADD_PROP_S( "cFontName", "Sans",     "Font" );
   ADD_PROP_N( "nFontSize", 10,         "Font" );
   ADD_PROP_N( "nLeft",     p->FLeft,   "Position" );
   ADD_PROP_N( "nTop",      p->FTop,    "Position" );
   break;
}
case CT_REPORTFIELD:
{
   hb_reta(7);
   ADD_PROP_S( "cText",       p->FText,     "Text" );
   ADD_PROP_S( "cFieldName",  p->FFileName, "Data" );
   ADD_PROP_S( "cExpression", p->FData,     "Data" );
   ADD_PROP_S( "cFontName",   "Sans",       "Font" );
   ADD_PROP_N( "nFontSize",   10,           "Font" );
   ADD_PROP_N( "nLeft",       p->FLeft,     "Position" );
   ADD_PROP_N( "nTop",        p->FTop,      "Position" );
   break;
}
case CT_REPORTIMAGE:
{
   hb_reta(3);
   ADD_PROP_S( "cFileName", p->FFileName, "Image" );
   ADD_PROP_N( "nLeft",     p->FLeft,     "Position" );
   ADD_PROP_N( "nTop",      p->FTop,      "Position" );
   break;
}
```

Note: `ADD_PROP_S` and `ADD_PROP_N` are the existing macros used in this function — check their exact definition near the top of UI_GetAllProps and use the same pattern.

- [ ] **Step 2: Add cFieldName and cExpression handling in UI_SetProp**

In `UI_SETPROP` (around line 1063), after the `cBandType` handler, add:

```cpp
   else if( lstrcmpi( szProp, "cFieldName" ) == 0 &&
            p->FControlType == CT_REPORTFIELD && HB_ISCHAR(3) )
   {
      lstrcpynA( p->FFileName, hb_parc(3), sizeof(p->FFileName) );
      if( p->FHandle ) InvalidateRect( p->FHandle, NULL, TRUE );
   }
   else if( lstrcmpi( szProp, "cExpression" ) == 0 &&
            p->FControlType == CT_REPORTFIELD && HB_ISCHAR(3) )
   {
      lstrcpynA( p->FData, hb_parc(3), sizeof(p->FData) - 1 );
      if( p->FHandle ) InvalidateRect( p->FHandle, NULL, TRUE );
   }
```

Also: for CT_REPORTLABEL/FIELD/IMAGE, the existing `cText` handler already calls `p->SetText()` which sets `FText` and calls `InvalidateRect` — no change needed there.

For `nLeft`/`nTop` on report controls, the existing handler calls `SetWindowPos(p->FHandle, NULL, p->FLeft, p->FTop, ...)`. For report controls, FHandle is parented to the band, so band-relative coords are correct — no change needed.

- [ ] **Step 3: Add cFieldName and cExpression handling in UI_GetProp**

In `UI_GETPROP`, after the `cBandType` / `aData` handlers, add:

```cpp
   else if( lstrcmpi( szProp, "cFieldName" ) == 0 &&
            p->FControlType == CT_REPORTFIELD )
      hb_retc( p->FFileName );
   else if( lstrcmpi( szProp, "cExpression" ) == 0 &&
            p->FControlType == CT_REPORTFIELD )
      hb_retc( p->FData );
```

- [ ] **Step 4: Commit**

```bash
git add source/cpp/hbbridge.cpp
git commit -m "feat: inspector GetAllProps/SetProp/GetProp for CT_REPORTLABEL/FIELD/IMAGE"
```

---

## Task 9: Palette entries and OnComponentDrop

**Files:**
- Modify: `source/hbbuilder_win.prg`

- [ ] **Step 1: Add ReportLabel, ReportField, ReportImage to Report tab**

In `source/hbbuilder_win.prg`, find the Report tab section (around line 404):
```harbour
   nTab := oPal:AddTab( "Report" )
   oPal:AddComp( nTab, "Bnd",  "Band",          132 )
```

Add the three new controls:
```harbour
   nTab := oPal:AddTab( "Report" )
   oPal:AddComp( nTab, "Bnd",  "Band",          132 )
   oPal:AddComp( nTab, "RLb",  "ReportLabel",   133 )
   oPal:AddComp( nTab, "RFd",  "ReportField",   134 )
   oPal:AddComp( nTab, "RIm",  "ReportImage",   135 )
```

- [ ] **Step 2: Add OnComponentDrop handlers for 133/134/135**

In `static function OnComponentDrop` (around line 1334), after the `if nType == 132` block (and before `if nType < 1 .or. nType > 131`), add:

```harbour
   // Report control drop — visual C++ control created in tform.cpp drop logic
   // OnComponentDrop just assigns the name
   if nType == 133 .or. nType == 134 .or. nType == 135
      aCnt[ nType ]++
      do case
         case nType == 133; cName := "RLabel" + LTrim(Str(aCnt[nType]))
         case nType == 134; cName := "RField" + LTrim(Str(aCnt[nType]))
         case nType == 135; cName := "RImage" + LTrim(Str(aCnt[nType]))
      endcase
      // The C++ control already exists in FChildren (created by drop logic)
      // Find the most recently added child and set its name
      local hLastCtrl := UI_GetChild( hForm, UI_GetChildCount( hForm ) )
      if hLastCtrl != 0 .and. UI_GetType( hLastCtrl ) == nType
         UI_SetProp( hLastCtrl, "cName", cName )
         if nType == 133
            UI_SetProp( hLastCtrl, "cText", "Label" )
         endif
      endif
      SyncDesignerToCode()
      InspectorPopulateCombo( hForm )
      INS_ComboSelect( _InsGetData(), UI_GetChildCount( hForm ) )
      InspectorRefresh( hLastCtrl )
      return nil
   endif
```

- [ ] **Step 3: Add cName guard in OnComponentDrop**

The existing line `if nType < 1 .or. nType > 131; return nil; endif` now needs to allow 133-135 through. Since we handled them above with early return, this guard is fine as-is.

- [ ] **Step 4: Add type names for 133/134/135 in do-case naming (around line 1483)**

Find the `do case` block that assigns cName for all types (used in code gen, around line 1483) and add:
```harbour
      case nType == 133; cName := "RLabel" + LTrim(Str(aCnt[nType]))
      case nType == 134; cName := "RField" + LTrim(Str(aCnt[nType]))
      case nType == 135; cName := "RImage" + LTrim(Str(aCnt[nType]))
```

- [ ] **Step 5: Commit**

```bash
git add source/hbbuilder_win.prg
git commit -m "feat: Report tab palette entries RLabel/RField/RImage; OnComponentDrop handlers"
```

---

## Task 10: SyncDesignerToCode and RestoreFormFromCode

**Files:**
- Modify: `source/hbbuilder_win.prg`

- [ ] **Step 1: Call UI_SyncBandData before code gen loop in SyncDesignerToCode**

Find the `static function SyncDesignerToCode` function. Near the top of its main loop (before it starts iterating children to build `cCreate`), add:

```harbour
   // Rebuild band FData from live visual report controls
   UI_SyncBandData( hForm )
```

This ensures FData on each band reflects the current positions of all visual report controls before the code gen reads it.

- [ ] **Step 2: Add UI_ReportCtrlNew calls in RestoreFormFromCode**

In `RestoreFormFromCode` (the function that parses code and rebuilds the form), find the section that handles `REPORTFIELD` lines and stores them into `FData` (around line 2092-2110). After storing into FData, also create the visual C++ control:

```harbour
            // Also create visual C++ report control
            if hBandCtrl != 0
               local nCtType := if( cFldType == "image", 135, if( cFldType == "field", 134, 133 ) )
               local hRCtrl  := UI_ReportCtrlNew( hForm, hBandCtrl, nCtType, nL, nT, nW, nH )
               if hRCtrl != 0
                  if ! Empty( cFldName );  UI_SetProp( hRCtrl, "cName",      cFldName );  endif
                  if ! Empty( cFldPrompt ); UI_SetProp( hRCtrl, "cText",     cFldPrompt ); endif
                  if ! Empty( cFldField );  UI_SetProp( hRCtrl, "cFieldName", cFldField ); endif
               endif
            endif
```

- [ ] **Step 3: Declare UI_SyncBandData and UI_ReportCtrlNew in hbbuilder_win.prg external declarations (if needed)**

Search the top of hbbuilder_win.prg for any `EXTERNAL` or `REQUEST` declarations for C functions. If they exist, add:
```harbour
REQUEST UI_SYNCBANDDATA
REQUEST UI_REPORTCTRLNEW
```

If no such section exists (functions are found automatically via the Harbour/C link), skip this step.

- [ ] **Step 4: Commit**

```bash
git add source/hbbuilder_win.prg
git commit -m "feat: SyncDesignerToCode calls UI_SyncBandData; RestoreFormFromCode creates visual report controls"
```

---

## Self-Review

**Spec coverage check:**
- ✅ CT_ constants (Task 1)
- ✅ FBandParent on TControl (Task 1)
- ✅ HBReportCtrl WM_PAINT with 3 rendering modes (Task 2)
- ✅ UI_ReportCtrlNew for programmatic creation (Task 3)
- ✅ UI_SyncBandData for serialization (Task 3)
- ✅ CreateControlByType (Task 4)
- ✅ Drop targeting by position, HWND parented to band (Task 5)
- ✅ HitTest coord translation (Task 6)
- ✅ PaintSelectionHandles coord translation (Task 6)
- ✅ Drag clamping + band-relative MoveWindow (Task 7)
- ✅ Resize band-relative SetWindowPos (Task 7)
- ✅ Inspector GetAllProps/SetProp/GetProp (Task 8)
- ✅ Palette entries (Task 9)
- ✅ OnComponentDrop (Task 9)
- ✅ SyncDesignerToCode (Task 10)
- ✅ RestoreFormFromCode (Task 10)

**Potential issue — FName field:** UI_SyncBandData uses `p->FName` for control name. Check if TControl has a `FName` field or if name is stored in `FText`. If TControl has no FName, use `p->FText` for both cName and cText in the serialized record, storing the name from Harbour side via `UI_SetProp(hCtrl, "cText", cName)` in OnComponentDrop. Adjust Task 3 accordingly if FName is absent.

**Potential issue — ADD_PROP_S/N macros:** Task 8 uses these macros. Check their exact names and signatures by reading the existing CT_BAND case in UI_GetAllProps before implementing Task 8.
