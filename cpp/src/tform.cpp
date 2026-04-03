/*
 * tform.cpp - TForm (top-level window) implementation
 */

#include "hbide.h"
#include <string.h>

/* Global pointer to the current design form (set by UI_SetDesignForm) */
extern TForm * g_designForm;

static PROPDESC aFormProps[] = {
   { "cFontName", PT_STRING,  0, "Appearance" },
   { "nFontSize", PT_NUMBER,  0, "Appearance" },
   { "lCenter",   PT_LOGICAL, 0, "Position" },
   { "lSizable",  PT_LOGICAL, 0, "Behavior" },
};

static int s_nFormCount = 0;

TForm::TForm()
{
   lstrcpy( FClassName, "TForm" );
   FControlType = CT_FORM;
   FFormFont = NULL;
   FClrPane = GetSysColor( COLOR_BTNFACE );
   FCenter = TRUE;
   FSizable = FALSE;
   FAppBar = FALSE;
   FToolWindow = FALSE;
   FModalResult = 0;
   FRunning = FALSE;
   FMainWindow = FALSE;
   FGridBmp = NULL;
   FGridDC = NULL;
   FGridW = FGridH = 0;
   FOverlay = NULL;
   FBorderStyle = 0;
   FBorderIcons = 7;  /* biSystemMenu | biMinimize | biMaximize */
   FBorderWidth = 0;
   FPosition = 0;
   FWindowState = 0;
   FFormStyle = 0;
   FCursor = 0;
   FKeyPreview = FALSE;
   FAlphaBlend = FALSE;
   FAlphaBlendValue = 255;
   FShowHint = FALSE;
   FHint[0] = 0;
   FAutoScroll = FALSE;
   FDoubleBuffered = FALSE;
   FDesignMode = FALSE;
   FSelCount = 0;
   FDragging = FALSE;
   FResizing = FALSE;
   FRubberBand = FALSE;
   FRubberX1 = FRubberY1 = FRubberX2 = FRubberY2 = 0;
   FResizeHandle = -1;
   FOnDblClick = NULL;
   FOnCreate = NULL;
   FOnDestroy = NULL;
   FOnShow = NULL;
   FOnHide = NULL;
   FOnCloseQuery = NULL;
   FOnActivate = NULL;
   FOnDeactivate = NULL;
   FOnResize = NULL;
   FOnPaint = NULL;
   FOnKeyDown = NULL;
   FOnKeyUp = NULL;
   FOnKeyPress = NULL;
   FOnMouseDown = NULL;
   FOnMouseUp = NULL;
   FOnMouseMove = NULL;
   FOnMouseWheel = NULL;
   FOnSelChange = NULL;
   FOnComponentDrop = NULL;
   FPendingControlType = -1;
   FDragStartX = FDragStartY = 0;
   FDragOffsetX = FDragOffsetY = 0;
   memset( FSelected, 0, sizeof(FSelected) );
   FWidth = 470;
   FHeight = 400;
   lstrcpy( FText, "New Form" );

   /* Toolbar */
   FToolBar = NULL;
   FPalette = NULL;
   FStatusBar = NULL;
   FHasStatusBar = FALSE;
   FClientTop = 0;

   /* Menu */
   FMenuBar = NULL;
   FMenuItemCount = 0;
   memset( FMenuActions, 0, sizeof(FMenuActions) );

}

TForm::~TForm()
{
   int i;
   if( FGridBmp ) { SelectObject( FGridDC, NULL ); DeleteObject( FGridBmp ); }
   if( FGridDC )  DeleteDC( FGridDC );
   if( FFormFont ) DeleteObject( FFormFont );
   ReleaseFormEvents();
   if( FOnSelChange ) hb_itemRelease( FOnSelChange );
   FOnSelChange = NULL;
   if( FOnComponentDrop ) hb_itemRelease( FOnComponentDrop );
   FOnComponentDrop = NULL;
   /* Release menu action blocks */
   for( i = 0; i < FMenuItemCount; i++ )
      if( FMenuActions[i] ) hb_itemRelease( FMenuActions[i] );
   if( FMenuBar ) DestroyMenu( FMenuBar );
   /* FBkBrush cleaned up by ~TControl() */
}

void TForm::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   if( FSizable )
      *pdwStyle = WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN;
   else
      *pdwStyle = WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_MODALFRAME | WS_CLIPCHILDREN;
   *pdwExStyle = 0;
   *pszClass = "HbIdeForm";
}

void TForm::CreateHandle( HWND hParent )
{
   WNDCLASSA wc = {0};
   char szClass[32];

   /* Prevent double creation */
   if( FHandle ) return;

   /* Create default font only if not already set by UI_FormNew */
   if( !FFormFont )
   {
      LOGFONTA lf = {0};
      HDC hTmpDC = GetDC( NULL );
      lf.lfHeight = -MulDiv( 9, GetDeviceCaps( hTmpDC, LOGPIXELSY ), 72 );
      ReleaseDC( NULL, hTmpDC );
      lf.lfCharSet = DEFAULT_CHARSET;
      lstrcpyA( lf.lfFaceName, "Segoe UI" );
      FFormFont = CreateFontIndirectA( &lf );
   }
   FFont = FFormFont;

   /* Background brush */
   FBkBrush = CreateSolidBrush( FClrPane );

   /* Register unique window class */
   s_nFormCount++;
   sprintf( szClass, "HbIdeForm%d", s_nFormCount );

   wc.lpfnWndProc   = TControl::WndProc;
   wc.hInstance      = GetModuleHandle(NULL);
   wc.hCursor        = LoadCursor(NULL, IDC_ARROW);
   wc.hbrBackground  = FBkBrush;
   wc.lpszClassName  = szClass;
   wc.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
   RegisterClassA( &wc );

   /* Create window */
   {
      DWORD dwStyle;
      DWORD dwExStyle = WS_EX_COMPOSITED;

      if( FAppBar )
      {
         /* Top bar: caption + min/max/close, NO thick resize border. */
         dwStyle = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX |
                   WS_MAXIMIZEBOX | WS_CLIPCHILDREN;
      }
      else if( FToolWindow )
      {
         /* Compact caption, no taskbar entry (design form, inspector) */
         dwStyle = WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_CLIPCHILDREN;
         dwExStyle = WS_EX_TOOLWINDOW;
      }
      else if( FSizable )
         dwStyle = WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN;
      else
         dwStyle = WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_MODALFRAME | WS_CLIPCHILDREN;

      FHandle = CreateWindowExA( dwExStyle, szClass, FText,
         dwStyle,
         FCenter ? CW_USEDEFAULT : FLeft,
         FCenter ? CW_USEDEFAULT : FTop,
         FWidth, FHeight,
         NULL, NULL, GetModuleHandle(NULL), NULL );
   }

   if( FHandle )
   {
      SetWindowLongPtr( FHandle, GWLP_USERDATA, (LONG_PTR) this );

      if( FFormFont )
         SendMessage( FHandle, WM_SETFONT, (WPARAM) FFormFont, TRUE );

      /* Attach menu bar if created before window */
      if( FMenuBar )
         SetMenu( FHandle, FMenuBar );
   }
}

LRESULT TForm::HandleMessage( UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_COMMAND:
      {
         WORD wId = LOWORD(wParam);
         WORD wNotify = HIWORD(wParam);

         /* Toolbar button clicks */
         if( FToolBar && wId >= TOOLBAR_BTN_ID_BASE &&
             wId < TOOLBAR_BTN_ID_BASE + FToolBar->FBtnCount )
         {
            FToolBar->DoCommand( wId - TOOLBAR_BTN_ID_BASE );
            return 0;
         }

         /* Palette component button clicks (IDs 200+) */
         if( FPalette && wId >= 200 && wId < 200 + MAX_PALETTE_BTNS )
         {
            int btnIdx = wId - 200;
            int nTab = FPalette->FCurrentTab;
            if( nTab >= 0 && nTab < FPalette->FTabCount &&
                btnIdx >= 0 && btnIdx < FPalette->FTabs[nTab].nBtnCount )
            {
               int ctrlType = FPalette->FTabs[nTab].btns[btnIdx].nControlType;

               /* Fire FOnSelect callback with the control type */
               if( FPalette->FOnSelect && HB_IS_BLOCK( FPalette->FOnSelect ) )
               {
                  hb_vmPushEvalSym();
                  hb_vmPush( FPalette->FOnSelect );
                  hb_vmPushInteger( ctrlType );
                  hb_vmSend( 1 );
               }

               /* Set pending control on the design form */
               if( g_designForm )
               {
                  g_designForm->FPendingControlType = ctrlType;
                  SetCursor( LoadCursor(NULL, IDC_CROSS) );
               }
            }
            return 0;
         }

         /* Menu item clicks */
         if( wId >= MENU_ID_BASE && wId < (WORD)(MENU_ID_BASE + FMenuItemCount) )
         {
            int idx = wId - MENU_ID_BASE;
            if( idx < FMenuItemCount && FMenuActions[idx] &&
                HB_IS_BLOCK( FMenuActions[idx] ) )
            {
               hb_vmPushEvalSym();
               hb_vmPush( FMenuActions[idx] );
               hb_vmSend( 0 );
            }
            return 0;
         }

         /* Child control notifications */
         {
            HWND hCtrl = (HWND) lParam;
            int i;
            for( i = 0; i < FChildCount; i++ )
            {
               if( FChildren[i]->FHandle == hCtrl )
               {
                  if( wNotify == BN_CLICKED )
                     FChildren[i]->DoOnClick();
                  else if( wNotify == CBN_SELCHANGE )
                     FChildren[i]->DoOnChange();
                  break;
               }
            }
         }

         /* IDOK / IDCANCEL from keyboard */
         if( wId == 1 || wId == 2 )
         {
            Close();
            return 0;
         }
         break;
      }

      case WM_ERASEBKGND:
      {
         RECT rc;
         HDC hDC = (HDC) wParam;
         GetClientRect( FHandle, &rc );

         if( FDesignMode )
         {
            /* Build grid bitmap once, cache it */
            if( !FGridBmp || FGridW != rc.right || FGridH != rc.bottom )
            {
               int x, y;
               if( FGridBmp ) { SelectObject( FGridDC, NULL ); DeleteObject( FGridBmp ); DeleteDC( FGridDC ); }
               FGridW = rc.right; FGridH = rc.bottom;
               FGridDC = CreateCompatibleDC( hDC );
               FGridBmp = CreateCompatibleBitmap( hDC, FGridW, FGridH );
               SelectObject( FGridDC, FGridBmp );
               FillRect( FGridDC, &rc, FBkBrush );
               for( y = FClientTop + 8; y < FGridH; y += 8 )
                  for( x = 8; x < FGridW; x += 8 )
                     SetPixel( FGridDC, x, y, RGB(200, 200, 200) );
            }
            BitBlt( hDC, 0, 0, FGridW, FGridH, FGridDC, 0, 0, SRCCOPY );
         }
         else
            FillRect( hDC, &rc, FBkBrush );

         return 1;
      }

      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLORBTN:
      case WM_CTLCOLOREDIT:
      case WM_CTLCOLORLISTBOX:
      {
         HWND hChild = (HWND) lParam;
         int i;
         for( i = 0; i < FChildCount; i++ )
         {
            if( FChildren[i]->FHandle == hChild && FChildren[i]->FClrPane != CLR_INVALID )
            {
               SetBkColor( (HDC) wParam, FChildren[i]->FClrPane );
               return (LRESULT) FChildren[i]->FBkBrush;
            }
         }
         SetBkMode( (HDC) wParam, TRANSPARENT );
         return (LRESULT) FBkBrush;
      }

      case WM_DRAWITEM:
      {
         DRAWITEMSTRUCT * pDIS = (DRAWITEMSTRUCT *) lParam;
         if( pDIS && pDIS->CtlType == ODT_BUTTON )
         {
            int i;
            for( i = 0; i < FChildCount; i++ )
            {
               if( FChildren[i]->FHandle == pDIS->hwndItem &&
                   FChildren[i]->FControlType == CT_BUTTON &&
                   FChildren[i]->FClrPane != CLR_INVALID )
               {
                  RECT rc = pDIS->rcItem;
                  UINT uEdge = ( pDIS->itemState & ODS_SELECTED ) ? EDGE_SUNKEN : EDGE_RAISED;
                  HBRUSH hBr = FChildren[i]->FBkBrush;

                  FillRect( pDIS->hDC, &rc, hBr );
                  DrawEdge( pDIS->hDC, &rc, uEdge, BF_RECT );

                  /* Draw text */
                  SetBkMode( pDIS->hDC, TRANSPARENT );
                  if( pDIS->itemState & ODS_SELECTED ) { rc.left += 1; rc.top += 1; }
                  if( FChildren[i]->FFont )
                     SelectObject( pDIS->hDC, FChildren[i]->FFont );
                  DrawTextA( pDIS->hDC, FChildren[i]->FText, -1, &rc,
                     DT_CENTER | DT_VCENTER | DT_SINGLELINE );

                  /* Focus rect */
                  if( pDIS->itemState & ODS_FOCUS )
                  {
                     InflateRect( &rc, -3, -3 );
                     DrawFocusRect( pDIS->hDC, &rc );
                  }
                  return TRUE;
               }
            }
         }
         break;
      }

      case WM_ACTIVATE:
         if( !FDesignMode )
         {
            if( LOWORD(wParam) != WA_INACTIVE )
               FireEvent( FOnActivate );
            else
               FireEvent( FOnDeactivate );
         }
         break;

      case WM_SHOWWINDOW:
         if( !FDesignMode )
         {
            if( wParam )
               FireEvent( FOnShow );
            else
               FireEvent( FOnHide );
         }
         break;

      case WM_LBUTTONDBLCLK:
         if( !FDesignMode )
            FireEvent( FOnDblClick );
         break;

      case WM_RBUTTONDOWN:
      case WM_RBUTTONUP:
         break;

      case WM_MOUSEWHEEL:
         if( !FDesignMode )
            FireEvent( FOnMouseWheel );
         break;

      case WM_MOVE:
      case WM_SIZE:
      {
         /* Update FLeft/FTop/FWidth/FHeight from actual window position */
         {
            RECT rcWnd;
            GetWindowRect( FHandle, &rcWnd );
            FLeft = rcWnd.left;
            FTop = rcWnd.top;
            FWidth = rcWnd.right - rcWnd.left;
            FHeight = rcWnd.bottom - rcWnd.top;
         }

         /* Resize toolbar */
         if( FToolBar && FToolBar->FHandle )
         {
            FClientTop = FToolBar->GetBarHeight();
         }
         /* Resize splitter + palette to fill remaining width */
         if( FPalette && FPalette->FTabCtrl )
         {
            RECT rc;
            GetClientRect( FHandle, &rc );
            if( FPalette->FSplitter )
               SetWindowPos( FPalette->FSplitter, NULL,
                  FPalette->FSplitPos, 0, 6, rc.bottom, SWP_NOZORDER );
            SetWindowPos( FPalette->FTabCtrl, NULL,
               FPalette->FSplitPos + 6, 0,
               rc.right - FPalette->FSplitPos - 6, rc.bottom, SWP_NOZORDER );
         }
         /* Resize status bar */
         if( FStatusBar )
            SendMessage( FStatusBar, WM_SIZE, 0, 0 );
         if( FDesignMode )
            UpdateOverlay();
         /* Fire OnResize for both design and runtime mode */
         FireEvent( FOnResize );
         break;
      }

      case WM_NOTIFY:
      {
         LPNMHDR pNMH = (LPNMHDR) lParam;
         if( pNMH->code == TTN_GETDISPINFOA && FToolBar )
         {
            LPNMTTDISPINFOA pTTDI = (LPNMTTDISPINFOA) lParam;
            int idx = (int) pTTDI->hdr.idFrom - TOOLBAR_BTN_ID_BASE;
            if( idx >= 0 && idx < FToolBar->FBtnCount )
               pTTDI->lpszText = FToolBar->FBtns[idx].szTooltip;
         }
         /* Tab control selection changed (component palette) */
         if( pNMH->code == TCN_SELCHANGE && FPalette &&
             pNMH->hwndFrom == FPalette->FTabCtrl )
         {
            FPalette->HandleTabChange();
         }
         break;
      }

      case WM_PARENTNOTIFY:
      {
         if( FDesignMode )
            return 0;
         break;
      }

      case WM_LBUTTONDOWN:
      {
         if( FDesignMode )
         {
            int mx = (short)LOWORD(lParam), my = (short)HIWORD(lParam) - FClientTop;
            BOOL bCtrl = ( wParam & MK_CONTROL ) != 0;
            int nHandle;
            TControl * pHit;

            /* Check if clicking on a resize handle first */
            nHandle = HitTestHandle( mx, my );
            if( nHandle >= 0 )
            {
               FResizing = TRUE;
               FResizeHandle = nHandle;
               FDragStartX = mx;
               FDragStartY = my;
               SetCapture( FHandle );
               return 0;
            }

            pHit = HitTest( mx, my );

            if( pHit )
            {
               if( bCtrl )
               {
                  /* Toggle selection */
                  if( IsSelected( pHit ) )
                  {
                     /* Remove from selection */
                     int k;
                     for( k = 0; k < FSelCount; k++ )
                        if( FSelected[k] == pHit ) { FSelected[k] = FSelected[--FSelCount]; break; }
                     UpdateOverlay();
                  }
                  else
                     SelectControl( pHit, TRUE );
               }
               else
               {
                  if( !IsSelected( pHit ) )
                     SelectControl( pHit, FALSE );
                  /* Bring selected controls to top of z-order */
                  {
                     int s;
                     for( s = 0; s < FSelCount; s++ )
                     {
                        if( FSelected[s]->FHandle )
                           SetWindowPos( FSelected[s]->FHandle, HWND_TOP,
                              0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE );
                     }
                  }

                  /* Start drag */
                  FDragging = TRUE;
                  FDragStartX = mx;
                  FDragStartY = my;
                  SetCapture( FHandle );
               }
            }
            else
            {
               ClearSelection();

               /* If a palette component is pending, start rubber band for drop */
               if( FPendingControlType >= 0 )
               {
                  FRubberBand = TRUE;
                  FRubberX1 = FRubberX2 = mx;
                  FRubberY1 = FRubberY2 = my;
                  SetCapture( FHandle );
               }
               else
               {
                  /* Start rubber band selection */
                  FRubberBand = TRUE;
                  FRubberX1 = FRubberX2 = mx;
                  FRubberY1 = FRubberY2 = my;
                  SetCapture( FHandle );
               }
            }
            return 0;
         }
         break;
      }

      case WM_MOUSEMOVE:
      {
         /* Rubber band */
         if( FDesignMode && FRubberBand )
         {
            int mx = (short)LOWORD(lParam), my = (short)HIWORD(lParam) - FClientTop;
            HDC hDC = GetDC( FHandle );
            HPEN hPen = CreatePen( PS_DOT, 1, RGB(0, 120, 215) );
            HPEN hOld = (HPEN) SelectObject( hDC, hPen );
            int oldRop = SetROP2( hDC, R2_XORPEN );

            /* Erase old rectangle */
            SelectObject( hDC, GetStockObject(NULL_BRUSH) );
            if( FRubberX1 != FRubberX2 || FRubberY1 != FRubberY2 )
               Rectangle( hDC, FRubberX1, FRubberY1, FRubberX2, FRubberY2 );

            FRubberX2 = mx;
            FRubberY2 = my;

            /* Draw new rectangle */
            Rectangle( hDC, FRubberX1, FRubberY1, FRubberX2, FRubberY2 );

            SetROP2( hDC, oldRop );
            SelectObject( hDC, hOld );
            DeleteObject( hPen );
            ReleaseDC( FHandle, hDC );
            return 0;
         }

         /* Resize */
         if( FDesignMode && FResizing && FSelCount > 0 )
         {
            int mx = (short)LOWORD(lParam), my = (short)HIWORD(lParam) - FClientTop;
            int dx = mx - FDragStartX, dy = my - FDragStartY;
            TControl * p = FSelected[0];
            int nl = p->FLeft, nt = p->FTop, nw = p->FWidth, nh = p->FHeight;

            dx = (dx / 4) * 4;
            dy = (dy / 4) * 4;
            if( dx == 0 && dy == 0 ) return 0;

            /* Apply delta based on which handle */
            switch( FResizeHandle )
            {
               case 0: nl += dx; nt += dy; nw -= dx; nh -= dy; break; /* TL */
               case 1: nt += dy; nh -= dy; break;                     /* TC */
               case 2: nw += dx; nt += dy; nh -= dy; break;           /* TR */
               case 3: nw += dx; break;                               /* MR */
               case 4: nw += dx; nh += dy; break;                     /* BR */
               case 5: nh += dy; break;                               /* BC */
               case 6: nl += dx; nw -= dx; nh += dy; break;           /* BL */
               case 7: nl += dx; nw -= dx; break;                     /* ML */
            }

            /* Minimum size */
            if( nw < 20 ) { nw = 20; nl = p->FLeft; }
            if( nh < 10 ) { nh = 10; nt = p->FTop; }

            p->FLeft = nl; p->FTop = nt; p->FWidth = nw; p->FHeight = nh;
            if( p->FHandle )
               SetWindowPos( p->FHandle, NULL, nl, nt + FClientTop, nw, nh, SWP_NOZORDER );

            FDragStartX += dx;
            FDragStartY += dy;
            UpdateOverlay();
            /* Live inspector update during resize */
            if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) && FSelCount > 0 )
            {
               hb_vmPushEvalSym();
               hb_vmPush( FOnSelChange );
               hb_vmPushNumInt( (HB_PTRUINT) FSelected[0] );
               hb_vmSend( 1 );
            }
            return 0;
         }

         /* Drag/move */
         if( FDesignMode && FDragging && FSelCount > 0 )
         {
            int mx = (short)LOWORD(lParam), my = (short)HIWORD(lParam) - FClientTop;
            int dx = mx - FDragStartX, dy = my - FDragStartY;
            int i;
            RECT rcOld, rcNew, rcInval;

            dx = (dx / 4) * 4;
            dy = (dy / 4) * 4;

            if( dx != 0 || dy != 0 )
            {
               for( i = 0; i < FSelCount; i++ )
               {
                  TControl * p = FSelected[i];
                  p->FLeft += dx;
                  p->FTop += dy;
                  if( p->FHandle )
                     SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop + FClientTop,
                        p->FWidth, p->FHeight, SWP_NOZORDER | SWP_NOSIZE );
               }
               FDragStartX += dx;
               FDragStartY += dy;
               UpdateOverlay();
               /* Live inspector update during drag */
               if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) && FSelCount > 0 )
               {
                  hb_vmPushEvalSym();
                  hb_vmPush( FOnSelChange );
                  hb_vmPushNumInt( (HB_PTRUINT) FSelected[0] );
                  hb_vmSend( 1 );
               }
            }
            return 0;
         }

         /* Change cursor in design mode */
         if( FDesignMode )
         {
            int mx = (short)LOWORD(lParam), my = (short)HIWORD(lParam) - FClientTop;
            int nH = HitTestHandle( mx, my );
            LPCTSTR cur = IDC_ARROW;

            if( nH >= 0 )
            {
               /* Resize cursors per handle: TL TC TR MR BR BC BL ML */
               static LPCTSTR aCurs[] = {
                  IDC_SIZENWSE, IDC_SIZENS, IDC_SIZENESW, IDC_SIZEWE,
                  IDC_SIZENWSE, IDC_SIZENS, IDC_SIZENESW, IDC_SIZEWE };
               cur = aCurs[nH];
            }
            else if( HitTest( mx, my ) )
               cur = IDC_SIZEALL;

            SetCursor( LoadCursor( NULL, cur ) );
            return 0;
         }
         break;
      }

      case WM_LBUTTONUP:
      {
         if( FDesignMode && FRubberBand )
         {
            int i, rx1, ry1, rx2, ry2;
            FRubberBand = FALSE;
            ReleaseCapture();

            /* Normalize rect */
            rx1 = FRubberX1 < FRubberX2 ? FRubberX1 : FRubberX2;
            ry1 = FRubberY1 < FRubberY2 ? FRubberY1 : FRubberY2;
            rx2 = FRubberX1 > FRubberX2 ? FRubberX1 : FRubberX2;
            ry2 = FRubberY1 > FRubberY2 ? FRubberY1 : FRubberY2;

            /* Clear old rubber band from screen */
            InvalidateRect( FHandle, NULL, TRUE );

            /* Component drop from palette */
            if( FPendingControlType >= 0 )
            {
               int ctrlType = FPendingControlType;
               int rw = rx2 - rx1, rh = ry2 - ry1;
               FPendingControlType = -1;
               SetCursor( LoadCursor(NULL, IDC_ARROW) );

               /* Enforce minimum size */
               if( rw < 20 ) rw = 80;
               if( rh < 10 ) rh = 24;
               /* Snap to 8-pixel grid */
               rx1 = (rx1 / 8) * 8;
               ry1 = (ry1 / 8) * 8;

               /* Create the control via factory */
               {
                  TControl * newCtrl = CreateControlByType( (BYTE) ctrlType );
                  if( newCtrl )
                  {
                     newCtrl->FLeft = rx1;
                     newCtrl->FTop = ry1;
                     newCtrl->FWidth = rw;
                     newCtrl->FHeight = rh;
                     newCtrl->FFont = FFormFont;
                     AddChild( newCtrl );

                     /* Create the Win32 control */
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

                     /* Select the new control */
                     SelectControl( newCtrl, FALSE );

                     /* Fire OnComponentDrop callback */
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
                     }
                  }
               }
               return 0;
            }

            /* Select all controls that intersect */
            ClearSelection();
            for( i = 0; i < FChildCount; i++ )
            {
               TControl * p = FChildren[i];
               if( p->FControlType == CT_GROUPBOX ) continue;
               /* Check intersection */
               if( p->FLeft + p->FWidth > rx1 && p->FLeft < rx2 &&
                   p->FTop + p->FHeight > ry1 && p->FTop < ry2 )
               {
                  if( FSelCount < MAX_CHILDREN )
                     FSelected[FSelCount++] = p;
               }
            }
            UpdateOverlay();

            /* Notify inspector */
            if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) && FSelCount > 0 )
            {
               hb_vmPushEvalSym();
               hb_vmPush( FOnSelChange );
               hb_vmPushNumInt( (HB_PTRUINT) FSelected[0] );
               hb_vmSend( 1 );
            }
            return 0;
         }

         if( FDesignMode && ( FDragging || FResizing ) )
         {
            FDragging = FALSE;
            FResizing = FALSE;
            FResizeHandle = -1;
            ReleaseCapture();
            UpdateOverlay();

            /* Refresh inspector with updated positions */
            if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) && FSelCount > 0 )
            {
               hb_vmPushEvalSym();
               hb_vmPush( FOnSelChange );
               hb_vmPushNumInt( (HB_PTRUINT) FSelected[0] );
               hb_vmSend( 1 );
            }
            return 0;
         }
         break;
      }

      case WM_KEYDOWN:
      {
         if( FDesignMode )
         {
            /* Delete selected controls */
            if( wParam == VK_DELETE && FSelCount > 0 )
            {
               int i;
               for( i = 0; i < FSelCount; i++ )
               {
                  if( FSelected[i]->FHandle )
                     DestroyWindow( FSelected[i]->FHandle );
                  FSelected[i]->FHandle = NULL;
               }
               ClearSelection();
               return 0;
            }

            /* Arrow keys nudge selected controls */
            if( FSelCount > 0 && (wParam == VK_LEFT || wParam == VK_RIGHT ||
                wParam == VK_UP || wParam == VK_DOWN) )
            {
               int dx = 0, dy = 0, i;
               int step = ( GetKeyState(VK_SHIFT) & 0x8000 ) ? 1 : 4;  /* Shift=1px, else 4px */

               if( wParam == VK_LEFT )  dx = -step;
               if( wParam == VK_RIGHT ) dx = step;
               if( wParam == VK_UP )    dy = -step;
               if( wParam == VK_DOWN )  dy = step;

               for( i = 0; i < FSelCount; i++ )
               {
                  FSelected[i]->FLeft += dx;
                  FSelected[i]->FTop += dy;
                  if( FSelected[i]->FHandle )
                     SetWindowPos( FSelected[i]->FHandle, NULL,
                        FSelected[i]->FLeft, FSelected[i]->FTop + FClientTop, 0, 0,
                        SWP_NOZORDER | SWP_NOSIZE );
               }
               UpdateOverlay();

               /* Refresh inspector */
               if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) && FSelCount > 0 )
               {
                  hb_vmPushEvalSym();
                  hb_vmPush( FOnSelChange );
                  hb_vmPushNumInt( (HB_PTRUINT) FSelected[0] );
                  hb_vmSend( 1 );
               }
               return 0;
            }
         }
         if( !FDesignMode )
            FireEvent( FOnKeyDown );
         break;
      }

      case WM_KEYUP:
         if( !FDesignMode )
            FireEvent( FOnKeyUp );
         break;

      case WM_CHAR:
         if( !FDesignMode )
            FireEvent( FOnKeyPress );
         break;

      case WM_CLOSE:
         /* Fire OnCloseQuery - could be used to cancel closing */
         FireEvent( FOnCloseQuery );
         /* Fire OnClose event before closing */
         FireEvent( FOnClose );

         if( FMainWindow )
            Close();   /* Main window: destroy -> PostQuitMessage */
         else
         {
            /* Secondary window: just hide, don't destroy */
            ShowWindow( FHandle, SW_HIDE );
         }
         return 0;

      case WM_DESTROY:
         FireEvent( FOnDestroy );
         if( FMainWindow )
            PostQuitMessage(0);
         return 0;
   }

   return DefWindowProc( FHandle, msg, wParam, lParam );
}

void TForm::Run()
{
   MSG msg;

   FMainWindow = TRUE;

   CreateHandle( NULL );
   CreateAllChildren();

   if( FDesignMode )
      SubclassChildren();

   if( FCenter )
      Center();

   ShowWindow( FHandle, SW_SHOW );
   UpdateWindow( FHandle );

   FireEvent( FOnCreate );

   FRunning = TRUE;

   while( GetMessage( &msg, NULL, 0, 0 ) > 0 )
   {
      if( !IsDialogMessage( FHandle, &msg ) )
      {
         TranslateMessage( &msg );
         DispatchMessage( &msg );
      }
   }

   FRunning = FALSE;
}

/* Show() - Create window and show it, but do NOT enter a message loop.
 * Use this for secondary windows (inspector, design form) that share
 * the message loop of the main window (which uses Run()). */
void TForm::Show()
{
   CreateHandle( NULL );
   CreateAllChildren();

   if( FDesignMode )
      SubclassChildren();

   if( FCenter )
      Center();

   ShowWindow( FHandle, SW_SHOW );
   UpdateWindow( FHandle );
   FRunning = TRUE;
}

void TForm::Close()
{
   FRunning = FALSE;
   DestroyWindow( FHandle );
   FHandle = NULL;
}

void TForm::Center()
{
   RECT rc;
   int cx, cy;

   if( !FHandle ) return;

   GetWindowRect( FHandle, &rc );
   cx = ( GetSystemMetrics(SM_CXSCREEN) - (rc.right - rc.left) ) / 2;
   cy = ( GetSystemMetrics(SM_CYSCREEN) - (rc.bottom - rc.top) ) / 2;
   SetWindowPos( FHandle, NULL, cx, cy, 0, 0, SWP_NOSIZE | SWP_NOZORDER );
}

void TForm::CreateAllChildren()
{
   int i;

   /* Create toolbar first (it docks to the top-left) */
   if( FToolBar )
   {
      FToolBar->CreateHandle( FHandle );
      FClientTop = FToolBar->GetBarHeight();
   }

   /* Create component palette (to the right of toolbar) */
   if( FPalette )
   {
      FPalette->CreateHandle( FHandle );
      /* If palette is taller than toolbar, use palette height */
      if( FPalette->GetBarHeight() > FClientTop )
         FClientTop = FPalette->GetBarHeight();
   }

   /* Create status bar */
   if( FHasStatusBar && !FStatusBar )
   {
      int parts[] = { 80, 200, -1 };
      FStatusBar = CreateWindowExA( 0, STATUSCLASSNAMEA, NULL,
         WS_CHILD | WS_VISIBLE,
         0, 0, 0, 0,
         FHandle, NULL, GetModuleHandle(NULL), NULL );
      SendMessage( FStatusBar, SB_SETPARTS, 3, (LPARAM) parts );
      SendMessageA( FStatusBar, SB_SETTEXTA, 0, (LPARAM) "1:1" );
      SendMessageA( FStatusBar, SB_SETTEXTA, 1, (LPARAM) "Modified" );
      SendMessageA( FStatusBar, SB_SETTEXTA, 2, (LPARAM) "" );
   }

   /* GroupBoxes first (lowest z-order) */
   for( i = 0; i < FChildCount; i++ )
   {
      if( FChildren[i]->FControlType == CT_GROUPBOX )
      {
         FChildren[i]->SetFont( FFormFont );
         FChildren[i]->CreateHandle( FHandle );
         /* Offset below toolbar */
         if( FClientTop > 0 && FChildren[i]->FHandle )
            SetWindowPos( FChildren[i]->FHandle, NULL,
               FChildren[i]->FLeft, FChildren[i]->FTop + FClientTop,
               FChildren[i]->FWidth, FChildren[i]->FHeight, SWP_NOZORDER );
      }
   }

   /* All other controls (except toolbar) */
   for( i = 0; i < FChildCount; i++ )
   {
      if( FChildren[i]->FControlType != CT_GROUPBOX &&
          FChildren[i]->FControlType != CT_TOOLBAR )
      {
         FChildren[i]->SetFont( FFormFont );
         FChildren[i]->CreateHandle( FHandle );
         /* Offset below toolbar */
         if( FClientTop > 0 && FChildren[i]->FHandle )
            SetWindowPos( FChildren[i]->FHandle, NULL,
               FChildren[i]->FLeft, FChildren[i]->FTop + FClientTop,
               FChildren[i]->FWidth, FChildren[i]->FHeight, SWP_NOZORDER );
      }
   }
}

static LRESULT CALLBACK DesignChildProc( HWND, UINT, WPARAM, LPARAM );

void TForm::SubclassChildren()
{
   int i;
   /* Subclass children to return HTTRANSPARENT */
   for( i = 0; i < FChildCount; i++ )
   {
      HWND hChild = FChildren[i]->FHandle;
      if( hChild )
      {
         WNDPROC pOld = (WNDPROC) GetWindowLongPtr( hChild, GWLP_WNDPROC );
         SetPropA( hChild, "OldProc", (HANDLE) pOld );
         SetWindowLongPtr( hChild, GWLP_WNDPROC, (LONG_PTR) DesignChildProc );
      }
   }
}

/* Child subclass - just makes clicks pass through to parent */
static LRESULT CALLBACK DesignChildProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_NCHITTEST )
      return HTTRANSPARENT;

   WNDPROC pOld = (WNDPROC) GetPropA( hWnd, "OldProc" );
   if( pOld )
      return CallWindowProc( pOld, hWnd, msg, wParam, lParam );
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

void TForm::SetDesignMode( BOOL bDesign )
{
   FDesignMode = bDesign;
   ClearSelection();
   if( bDesign )
      SubclassChildren();
}

TControl * TForm::HitTest( int x, int y )
{
   int i;
   TControl * pGroupHit = NULL;
   int border = 8;  /* pixels from edge to count as border click */

   for( i = FChildCount - 1; i >= 0; i-- )
   {
      TControl * p = FChildren[i];
      int l = p->FLeft, t = p->FTop, r = l + p->FWidth, b = t + p->FHeight;

      if( x >= l && x <= r && y >= t && y <= b )
      {
         if( p->FControlType == CT_GROUPBOX )
         {
            /* Only match on the border/title area of the groupbox */
            if( y <= t + 18 ||                /* title area */
                x <= l + border ||             /* left border */
                x >= r - border ||             /* right border */
                y >= b - border )              /* bottom border */
            {
               if( !pGroupHit )
                  pGroupHit = p;
            }
         }
         else
            return p;
      }
   }
   return pGroupHit;
}

/* Returns handle index 0-7 if mouse is over a handle, -1 otherwise.
   0=TL 1=TC 2=TR 3=MR 4=BR 5=BC 6=BL 7=ML */
int TForm::HitTestHandle( int x, int y )
{
   int i, j;
   for( i = 0; i < FSelCount; i++ )
   {
      TControl * p = FSelected[i];
      int px = p->FLeft, py = p->FTop, pw = p->FWidth, ph = p->FHeight;
      int hx[8], hy[8];

      hx[0]=px-3;      hy[0]=py-3;
      hx[1]=px+pw/2-3; hy[1]=py-3;
      hx[2]=px+pw-3;   hy[2]=py-3;
      hx[3]=px+pw-3;   hy[3]=py+ph/2-3;
      hx[4]=px+pw-3;   hy[4]=py+ph-3;
      hx[5]=px+pw/2-3; hy[5]=py+ph-3;
      hx[6]=px-3;      hy[6]=py+ph-3;
      hx[7]=px-3;      hy[7]=py+ph/2-3;

      for( j = 0; j < 8; j++ )
      {
         if( x >= hx[j] && x <= hx[j]+7 && y >= hy[j] && y <= hy[j]+7 )
            return j;
      }
   }
   return -1;
}

void TForm::SelectControl( TControl * pCtrl, BOOL bAdd )
{
   if( !bAdd )
   {
      FSelCount = 0;
      memset( FSelected, 0, sizeof(FSelected) );
   }

   if( pCtrl && FSelCount < MAX_CHILDREN && !IsSelected( pCtrl ) )
      FSelected[FSelCount++] = pCtrl;

   UpdateOverlay();

   /* Notify Harbour of selection change */
   if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( FOnSelChange );
      hb_vmPushNumInt( FSelCount > 0 ? (HB_PTRUINT) FSelected[0] : 0 );
      hb_vmSend( 1 );
   }
}

void TForm::ClearSelection()
{
   FSelCount = 0;
   memset( FSelected, 0, sizeof(FSelected) );
   UpdateOverlay();

   if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( FOnSelChange );
      hb_vmPushNumInt( 0 );
      hb_vmSend( 1 );
   }
}

BOOL TForm::IsSelected( TControl * pCtrl )
{
   int i;
   for( i = 0; i < FSelCount; i++ )
      if( FSelected[i] == pCtrl ) return TRUE;
   return FALSE;
}

/* Draw handles on a 32-bit ARGB DC (for layered window) */
void TForm::PaintSelectionHandles( HDC hDC )
{
   int i, j;
   HPEN hPen = CreatePen( PS_SOLID, 1, RGB(0, 120, 215) );
   HBRUSH hBr = CreateSolidBrush( RGB(0, 120, 215) );
   HBRUSH hWhite = CreateSolidBrush( RGB(255, 255, 255) );
   HPEN hOldPen = (HPEN) SelectObject( hDC, hPen );
   HBRUSH hOldBr;

   for( i = 0; i < FSelCount; i++ )
   {
      TControl * p = FSelected[i];
      int x = p->FLeft, y = p->FTop + FClientTop, w = p->FWidth, h = p->FHeight;
      int hx[8], hy[8];

      /* Dashed border */
      HPEN hDash = CreatePen( PS_DASH, 1, RGB(0, 120, 215) );
      SelectObject( hDC, hDash );
      hOldBr = (HBRUSH) SelectObject( hDC, GetStockObject(NULL_BRUSH) );
      Rectangle( hDC, x - 1, y - 1, x + w + 1, y + h + 1 );
      SelectObject( hDC, hOldBr );
      DeleteObject( hDash );

      /* 8 handles: white fill + blue border */
      hx[0]=x-3;     hy[0]=y-3;
      hx[1]=x+w/2-3; hy[1]=y-3;
      hx[2]=x+w-3;   hy[2]=y-3;
      hx[3]=x+w-3;   hy[3]=y+h/2-3;
      hx[4]=x+w-3;   hy[4]=y+h-3;
      hx[5]=x+w/2-3; hy[5]=y+h-3;
      hx[6]=x-3;     hy[6]=y+h-3;
      hx[7]=x-3;     hy[7]=y+h/2-3;

      SelectObject( hDC, hPen );
      SelectObject( hDC, hWhite );
      for( j = 0; j < 8; j++ )
         Rectangle( hDC, hx[j], hy[j], hx[j]+7, hy[j]+7 );
   }

   SelectObject( hDC, hOldPen );
   DeleteObject( hPen );
   DeleteObject( hBr );
   DeleteObject( hWhite );
}

/* Updates the layered popup overlay window with current selection handles */
void TForm::UpdateOverlay()
{
   RECT rcClient;
   POINT ptClient = {0, 0};
   int w, h, x, y;
   HDC hScreenDC, hMemDC;
   HBITMAP hBmp, hOldBmp;
   BITMAPINFO bmi = {0};
   void * pBits = NULL;
   BLENDFUNCTION bf;
   POINT ptSrc = {0, 0};
   POINT ptDst;
   SIZE sz;

   if( !FHandle ) return;

   /* No selection = hide overlay */
   if( FSelCount == 0 )
   {
      if( FOverlay )
         ShowWindow( FOverlay, SW_HIDE );
      return;
   }

   GetClientRect( FHandle, &rcClient );
   ClientToScreen( FHandle, &ptClient );
   w = rcClient.right;
   h = rcClient.bottom;

   /* Create overlay popup if needed */
   if( !FOverlay )
   {
      FOverlay = CreateWindowExA(
         WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW,
         "STATIC", "",
         WS_POPUP,
         0, 0, 1, 1,
         FHandle, NULL, GetModuleHandle(NULL), NULL );
   }

   /* Create 32-bit DIB for per-pixel alpha */
   hScreenDC = GetDC( NULL );
   hMemDC = CreateCompatibleDC( hScreenDC );

   bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
   bmi.bmiHeader.biWidth = w;
   bmi.bmiHeader.biHeight = -h;  /* top-down */
   bmi.bmiHeader.biPlanes = 1;
   bmi.bmiHeader.biBitCount = 32;
   bmi.bmiHeader.biCompression = BI_RGB;

   hBmp = CreateDIBSection( hMemDC, &bmi, DIB_RGB_COLORS, &pBits, NULL, 0 );
   hOldBmp = (HBITMAP) SelectObject( hMemDC, hBmp );

   /* Clear to transparent (all zeros = transparent ARGB) */
   memset( pBits, 0, w * h * 4 );

   /* Draw handles - they'll be opaque on transparent background */
   /* Set alpha for drawn pixels */
   PaintSelectionHandles( hMemDC );

   /* Fix alpha channel: any non-zero RGB pixel gets full alpha */
   {
      unsigned char * p = (unsigned char *) pBits;
      int i, total = w * h;
      for( i = 0; i < total; i++ )
      {
         if( p[0] || p[1] || p[2] )
            p[3] = 255;  /* fully opaque */
         p += 4;
      }
   }

   /* Position overlay exactly over the form's client area */
   ptDst.x = ptClient.x;
   ptDst.y = ptClient.y;
   sz.cx = w;
   sz.cy = h;

   bf.BlendOp = AC_SRC_OVER;
   bf.BlendFlags = 0;
   bf.SourceConstantAlpha = 255;
   bf.AlphaFormat = AC_SRC_ALPHA;

   SetWindowPos( FOverlay, HWND_TOPMOST, ptDst.x, ptDst.y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW );
   UpdateLayeredWindow( FOverlay, hScreenDC, &ptDst, &sz, hMemDC, &ptSrc, 0, &bf, ULW_ALPHA );

   SelectObject( hMemDC, hOldBmp );
   DeleteObject( hBmp );
   DeleteDC( hMemDC );
   ReleaseDC( NULL, hScreenDC );
}

/* ======================================================================
 * Toolbar
 * ====================================================================== */

void TForm::AttachToolBar( TToolBar * pTB )
{
   FToolBar = pTB;
   pTB->FCtrlParent = this;
   pTB->FParent = this;

   /* If form already has HWND, create toolbar immediately */
   if( FHandle )
   {
      pTB->CreateHandle( FHandle );
      FClientTop = pTB->GetBarHeight();
   }
}

/* ======================================================================
 * Menu
 * ====================================================================== */

void TForm::CreateMenuBar()
{
   if( !FMenuBar )
      FMenuBar = CreateMenu();
}

HMENU TForm::AddMenuPopup( const char * szText )
{
   HMENU hPopup;
   if( !FMenuBar ) CreateMenuBar();
   hPopup = CreatePopupMenu();
   AppendMenuA( FMenuBar, MF_POPUP, (UINT_PTR) hPopup, szText );
   if( FHandle ) SetMenu( FHandle, FMenuBar );
   return hPopup;
}

int TForm::AddMenuItem( HMENU hPopup, const char * szText, PHB_ITEM pBlock )
{
   int idx;
   if( !hPopup || FMenuItemCount >= MAX_MENUITEMS ) return -1;
   idx = FMenuItemCount++;
   if( pBlock )
      FMenuActions[idx] = hb_itemNew( pBlock );
   else
      FMenuActions[idx] = NULL;
   AppendMenuA( hPopup, MF_STRING, MENU_ID_BASE + idx, szText );
   return idx;
}

void TForm::AddMenuSeparator( HMENU hPopup )
{
   if( hPopup )
      AppendMenuA( hPopup, MF_SEPARATOR, 0, NULL );
}

void TForm::SetFormEvent( const char * szEvent, PHB_ITEM pBlock )
{
   PHB_ITEM * ppTarget = NULL;

   if( lstrcmpi( szEvent, "OnDblClick" ) == 0 )        ppTarget = &FOnDblClick;
   else if( lstrcmpi( szEvent, "OnCreate" ) == 0 )      ppTarget = &FOnCreate;
   else if( lstrcmpi( szEvent, "OnDestroy" ) == 0 )     ppTarget = &FOnDestroy;
   else if( lstrcmpi( szEvent, "OnShow" ) == 0 )        ppTarget = &FOnShow;
   else if( lstrcmpi( szEvent, "OnHide" ) == 0 )        ppTarget = &FOnHide;
   else if( lstrcmpi( szEvent, "OnCloseQuery" ) == 0 )  ppTarget = &FOnCloseQuery;
   else if( lstrcmpi( szEvent, "OnActivate" ) == 0 )    ppTarget = &FOnActivate;
   else if( lstrcmpi( szEvent, "OnDeactivate" ) == 0 )  ppTarget = &FOnDeactivate;
   else if( lstrcmpi( szEvent, "OnResize" ) == 0 )      ppTarget = &FOnResize;
   else if( lstrcmpi( szEvent, "OnPaint" ) == 0 )       ppTarget = &FOnPaint;
   else if( lstrcmpi( szEvent, "OnKeyDown" ) == 0 )     ppTarget = &FOnKeyDown;
   else if( lstrcmpi( szEvent, "OnKeyUp" ) == 0 )       ppTarget = &FOnKeyUp;
   else if( lstrcmpi( szEvent, "OnKeyPress" ) == 0 )    ppTarget = &FOnKeyPress;
   else if( lstrcmpi( szEvent, "OnMouseDown" ) == 0 )   ppTarget = &FOnMouseDown;
   else if( lstrcmpi( szEvent, "OnMouseUp" ) == 0 )     ppTarget = &FOnMouseUp;
   else if( lstrcmpi( szEvent, "OnMouseMove" ) == 0 )   ppTarget = &FOnMouseMove;
   else if( lstrcmpi( szEvent, "OnMouseWheel" ) == 0 )  ppTarget = &FOnMouseWheel;

   if( ppTarget )
   {
      if( *ppTarget ) hb_itemRelease( *ppTarget );
      *ppTarget = hb_itemNew( pBlock );
   }
}

void TForm::ReleaseFormEvents()
{
   #define REL(e) if( e ) { hb_itemRelease( e ); e = NULL; }
   REL(FOnDblClick);    REL(FOnCreate);      REL(FOnDestroy);
   REL(FOnShow);        REL(FOnHide);        REL(FOnCloseQuery);
   REL(FOnActivate);    REL(FOnDeactivate);   REL(FOnResize);
   REL(FOnPaint);       REL(FOnKeyDown);      REL(FOnKeyUp);
   REL(FOnKeyPress);    REL(FOnMouseDown);    REL(FOnMouseUp);
   REL(FOnMouseMove);   REL(FOnMouseWheel);
   #undef REL
}

const PROPDESC * TForm::GetPropDescs( int * pnCount )
{
   *pnCount = sizeof(aFormProps) / sizeof(aFormProps[0]);
   return aFormProps;
}
