/*
 * tcontrols.cpp - Concrete control implementations
 * TLabel, TEdit, TButton, TCheckBox, TComboBox, TGroupBox
 */

#include "hbide.h"
#include <string.h>
#include <objidl.h>
#include <gdiplus.h>

extern "C" int g_bDarkIDE;

/* ======================================================================
 * TLabel
 * ====================================================================== */

TLabel::TLabel()
{
   lstrcpy( FClassName, "TLabel" );
   FControlType = CT_LABEL;
   lstrcpy( FText, "Label" );
   FWidth = 80;
   FHeight = 18;
   FTabStop = FALSE;
   FTransparent = TRUE;   /* Delphi/VCL default: labels inherit parent's bg */
   lstrcpy( FText, "Label" );
}

void TLabel::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE;
   *pdwExStyle = 0;
   *pszClass = "STATIC";
}

const PROPDESC * TLabel::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TEdit
 * ====================================================================== */

static PROPDESC aEditProps[] = {
   { "lReadOnly", PT_LOGICAL, 0, "Behavior" },
   { "lPassword", PT_LOGICAL, 0, "Behavior" },
};

TEdit::TEdit()
{
   lstrcpy( FClassName, "TEdit" );
   FControlType = CT_EDIT;
   FWidth = 200;
   FHeight = 26;
   FReadOnly = FALSE;
   FPassword = FALSE;
}

void TEdit::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL;
   *pdwExStyle = 0;
   *pszClass = "EDIT";

   if( FReadOnly )
      *pdwStyle |= ES_READONLY;
   if( FPassword )
      *pdwStyle |= ES_PASSWORD;
}

const PROPDESC * TEdit::GetPropDescs( int * pnCount )
{
   *pnCount = sizeof(aEditProps) / sizeof(aEditProps[0]);
   return aEditProps;
}

/* ======================================================================
 * TButton
 * ====================================================================== */

static PROPDESC aButtonProps[] = {
   { "lDefault", PT_LOGICAL, 0, "Behavior" },
   { "lCancel",  PT_LOGICAL, 0, "Behavior" },
};

TButton::TButton()
{
   lstrcpy( FClassName, "TButton" );
   FControlType = CT_BUTTON;
   lstrcpy( FText, "Button" );
   FWidth = 88;
   FHeight = 26;
   FDefault = FALSE;
   FCancel = FALSE;
}

void TButton::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_TABSTOP;
   *pdwExStyle = 0;
   *pszClass = "BUTTON";

   if( FDefault )
      *pdwStyle |= BS_DEFPUSHBUTTON;
}

void TButton::CreateHandle( HWND hParent )
{
   DWORD dwStyle, dwExStyle;
   const char * szClass;
   int nId = 0;

   CreateParams( &dwStyle, &dwExStyle, &szClass );

   /* Assign IDOK/IDCANCEL for keyboard handling */
   if( FDefault ) nId = 1;   /* IDOK */
   if( FCancel )  nId = 2;   /* IDCANCEL */

   FHandle = CreateWindowExA( dwExStyle, szClass, FText, dwStyle,
      FLeft, FTop, FWidth, FHeight,
      hParent, (HMENU)(LONG_PTR) nId, GetModuleHandle(NULL), NULL );

   if( FHandle )
   {
      SetWindowLongPtr( FHandle, GWLP_USERDATA, (LONG_PTR) this );

      if( FFont )
         SendMessage( FHandle, WM_SETFONT, (WPARAM) FFont, TRUE );
      else if( hParent )
         SendMessage( FHandle, WM_SETFONT,
            SendMessage( hParent, WM_GETFONT, 0, 0 ), TRUE );
   }
}

void TButton::DoOnClick()
{
   TForm * pForm;

   /* Fire Harbour event first */
   FireEvent( FOnClick );

   /* Then handle modal result */
   TControl * p = FCtrlParent;
   while( p && p->FControlType != CT_FORM )
      p = p->FCtrlParent;

   pForm = (TForm *) p;

   if( pForm )
   {
      if( FDefault )
         pForm->FModalResult = 1;
      else if( FCancel )
         pForm->FModalResult = 2;

      if( FDefault || FCancel )
      {
         /* Send WM_CLOSE so the form's message handler runs the correct
          * close logic (modal hide vs main destroy vs secondary hide) */
         if( pForm->FHandle )
            SendMessage( pForm->FHandle, WM_CLOSE, 0, 0 );
      }
   }
}

const PROPDESC * TButton::GetPropDescs( int * pnCount )
{
   *pnCount = sizeof(aButtonProps) / sizeof(aButtonProps[0]);
   return aButtonProps;
}

/* ======================================================================
 * TCheckBox
 * ====================================================================== */

static PROPDESC aCheckProps[] = {
   { "lChecked", PT_LOGICAL, 0, "Data" },
};

TCheckBox::TCheckBox()
{
   lstrcpy( FClassName, "TCheckBox" );
   FControlType = CT_CHECKBOX;
   lstrcpy( FText, "CheckBox" );
   FWidth = 150;
   FHeight = 19;
   FChecked = FALSE;
}

void TCheckBox::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX;
   *pdwExStyle = 0;
   *pszClass = "BUTTON";
}

void TCheckBox::CreateHandle( HWND hParent )
{
   TControl::CreateHandle( hParent );
   if( FHandle && FChecked )
      SendMessage( FHandle, BM_SETCHECK, BST_CHECKED, 0 );
}

void TCheckBox::SetChecked( BOOL bChecked )
{
   FChecked = bChecked;
   if( FHandle )
      SendMessage( FHandle, BM_SETCHECK, bChecked ? BST_CHECKED : BST_UNCHECKED, 0 );
}

const PROPDESC * TCheckBox::GetPropDescs( int * pnCount )
{
   *pnCount = sizeof(aCheckProps) / sizeof(aCheckProps[0]);
   return aCheckProps;
}

/* ======================================================================
 * TComboBox
 * ====================================================================== */

static PROPDESC aComboProps[] = {
   { "nItemIndex", PT_NUMBER, 0, "Data" },
};

TComboBox::TComboBox()
{
   lstrcpy( FClassName, "TComboBox" );
   FControlType = CT_COMBOBOX;
   FWidth = 175;
   FHeight = 200;  /* dropdown height */
   FItemIndex = 0;
   FItemCount = 0;
   memset( FItems, 0, sizeof(FItems) );
}

void TComboBox::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_VSCROLL | CBS_DROPDOWNLIST;
   *pdwExStyle = 0;
   *pszClass = "COMBOBOX";
}

void TComboBox::CreateHandle( HWND hParent )
{
   int i;
   TControl::CreateHandle( hParent );

   /* Add stored items after handle exists */
   if( FHandle )
   {
      for( i = 0; i < FItemCount; i++ )
         SendMessageA( FHandle, CB_ADDSTRING, 0, (LPARAM) FItems[i] );

      /* FItemIndex is 1-based (1=first item, 0=nothing selected) */
      if( FItemIndex > 0 )
         SendMessage( FHandle, CB_SETCURSEL, FItemIndex - 1, 0 );
   }
}

void TComboBox::AddItem( const char * szItem )
{
   /* Store for later if handle doesn't exist yet */
   if( FItemCount < 32 )
      lstrcpynA( FItems[FItemCount++], szItem, 64 );

   /* Also add to live control if already created */
   if( FHandle )
      SendMessageA( FHandle, CB_ADDSTRING, 0, (LPARAM) szItem );
}

void TComboBox::SetItemIndex( int nIndex )
{
   /* nIndex is 1-based (1=first item, 0=no selection) */
   FItemIndex = nIndex;
   if( FHandle )
      SendMessage( FHandle, CB_SETCURSEL, nIndex > 0 ? nIndex - 1 : -1, 0 );
}

const PROPDESC * TComboBox::GetPropDescs( int * pnCount )
{
   *pnCount = sizeof(aComboProps) / sizeof(aComboProps[0]);
   return aComboProps;
}

/* ======================================================================
 * TGroupBox
 * ====================================================================== */

TGroupBox::TGroupBox()
{
   lstrcpy( FClassName, "TGroupBox" );
   FControlType = CT_GROUPBOX;
   FWidth = 200;
   FHeight = 100;
   FTabStop = FALSE;
}

void TGroupBox::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE | BS_GROUPBOX;
   *pdwExStyle = WS_EX_TRANSPARENT;
   *pszClass = "BUTTON";
}

const PROPDESC * TGroupBox::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TToolBar
 * ====================================================================== */

TToolBar::TToolBar()
{
   lstrcpy( FClassName, "TToolBar" );
   FControlType = CT_TOOLBAR;
   FBtnCount = 0;
   FTabStop = FALSE;
   FHeight = 28;
   FImageList = NULL;
   FIdBase = TOOLBAR_BTN_ID_BASE;
   memset( FBtns, 0, sizeof(FBtns) );
}

TToolBar::~TToolBar()
{
   int i;
   for( i = 0; i < FBtnCount; i++ )
      if( FBtns[i].pOnClick ) hb_itemRelease( FBtns[i].pOnClick );
}

void TToolBar::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE | TBSTYLE_FLAT | TBSTYLE_TOOLTIPS | TBSTYLE_LIST | CCS_TOP;
   *pdwExStyle = 0;
   *pszClass = TOOLBARCLASSNAME;
}

void TToolBar::CreateHandle( HWND hParent )
{
   int i, btnIdx = 0;
   TBBUTTON tbb;

   /* Prevent double creation */
   if( FHandle ) return;

   FHandle = CreateWindowExA( 0, TOOLBARCLASSNAME, NULL,
      WS_CHILD | WS_VISIBLE | TBSTYLE_FLAT | TBSTYLE_TOOLTIPS | TBSTYLE_LIST |
      CCS_NOPARENTALIGN | CCS_NORESIZE | CCS_NODIVIDER,
      0, 0, 0, 0,
      hParent, NULL, GetModuleHandle(NULL), NULL );

   if( !FHandle ) return;

   SendMessage( FHandle, TB_BUTTONSTRUCTSIZE, sizeof(TBBUTTON), 0 );
   SendMessage( FHandle, TB_SETEXTENDEDSTYLE, 0, TBSTYLE_EX_MIXEDBUTTONS );

   /* Apply font from parent form - use FFormFont directly for consistency */
   {
      HFONT hFont = (HFONT) SendMessage( hParent, WM_GETFONT, 0, 0 );
      if( hFont )
         SendMessage( FHandle, WM_SETFONT, (WPARAM) hFont, TRUE );
   }

   /* Add all buttons */
   for( i = 0; i < FBtnCount; i++ )
   {
      memset( &tbb, 0, sizeof(tbb) );

      if( FBtns[i].bSeparator )
      {
         tbb.iBitmap = 0;
         tbb.idCommand = 0;
         tbb.fsState = 0;
         tbb.fsStyle = BTNS_SEP;
         tbb.iString = 0;
      }
      else
      {
         tbb.iBitmap = I_IMAGENONE;
         tbb.idCommand = FIdBase + i;
         tbb.fsState = TBSTATE_ENABLED;
         tbb.fsStyle = BTNS_BUTTON | BTNS_AUTOSIZE | BTNS_SHOWTEXT;
         tbb.iString = (INT_PTR) FBtns[i].szText;
      }

      SendMessage( FHandle, TB_ADDBUTTONS, 1, (LPARAM) &tbb );
   }

   /* Calculate ideal size and position toolbar */
   {
      SIZE sz = {0};
      SendMessage( FHandle, TB_GETMAXSIZE, 0, (LPARAM) &sz );
      FWidth = sz.cx + 8;
      FHeight = sz.cy;
      SetWindowPos( FHandle, NULL, 0, 0, FWidth, FHeight, SWP_NOZORDER );
   }
}

static void TBLog( const char * fmt, ... )
{
   FILE * f = fopen( "c:\\ide\\toolbar.log", "a" );
   if( f ) {
      va_list ap; va_start( ap, fmt );
      vfprintf( f, fmt, ap );
      fprintf( f, "\n" );
      va_end( ap );
      fclose( f );
   }
}

void TToolBar::LoadImages( const char * szBmpPath )
{
   HBITMAP hBmp;
   int i, imgIdx;

   TBLog( "LoadImages called: path='%s' hWnd=%p", szBmpPath, (void*)FHandle );

   if( !FHandle || !szBmpPath ) { TBLog("ABORT: null handle or path"); return; }

   hBmp = (HBITMAP) LoadImageA( NULL, szBmpPath, IMAGE_BITMAP,
      0, 0, LR_LOADFROMFILE );
   TBLog( "LoadImageA: hBmp=%p error=%lu", (void*)hBmp, GetLastError() );
   if( !hBmp ) return;

   /* Scale icon + button size by current system DPI so toolbar buttons look
      proportional on high-DPI displays. Apply a 50% dampening factor so
      icons grow with DPI but don't dominate (32->48 at 200%, not 32->64).
      Source bitmap is 32x32 cells; we stretch onto a larger bitmap when
      DPI > 96 so icons render crisp. */
   {
      int dpi = 96;
      HDC hScr = GetDC( NULL );
      if( hScr ) { dpi = GetDeviceCaps( hScr, LOGPIXELSY ); ReleaseDC( NULL, hScr ); }
      int icoSz = 32 + MulDiv( 32, dpi - 96, 192 );  /* 32 at 96, 48 at 192 */
      int btnSz = 40 + MulDiv( 40, dpi - 96, 192 );  /* 40 at 96, 60 at 192 */
      if( icoSz < 32 ) icoSz = 32;
      if( btnSz < 40 ) btnSz = 40;

      HBITMAP hBmpScaled = hBmp;
      if( icoSz != 32 ) {
         BITMAP bmpInfo;
         if( GetObject( hBmp, sizeof(bmpInfo), &bmpInfo ) ) {
            int srcW = bmpInfo.bmWidth, srcH = bmpInfo.bmHeight;
            int dstW = MulDiv( srcW, icoSz, 32 );
            int dstH = MulDiv( srcH, icoSz, 32 );
            HDC hdcS = GetDC( NULL );
            HDC hSrc = CreateCompatibleDC( hdcS );
            HDC hDst = CreateCompatibleDC( hdcS );
            HBITMAP hOut = CreateCompatibleBitmap( hdcS, dstW, dstH );
            HGDIOBJ oS = SelectObject( hSrc, hBmp );
            HGDIOBJ oD = SelectObject( hDst, hOut );
            /* Pre-fill destination with the mask color (RGB 255,0,255).
               Combined with COLORONCOLOR (nearest-neighbor) stretch, this
               keeps edge pixels at exact mask RGB so ImageList_AddMasked
               removes them cleanly — no fuchsia halo around scaled icons. */
            { RECT rcF = { 0, 0, dstW, dstH };
              HBRUSH hbrM = CreateSolidBrush( RGB(255,0,255) );
              FillRect( hDst, &rcF, hbrM );
              DeleteObject( hbrM ); }
            SetStretchBltMode( hDst, COLORONCOLOR );
            SetBrushOrgEx( hDst, 0, 0, NULL );
            StretchBlt( hDst, 0, 0, dstW, dstH, hSrc, 0, 0, srcW, srcH, SRCCOPY );
            SelectObject( hSrc, oS );
            SelectObject( hDst, oD );
            DeleteDC( hSrc );
            DeleteDC( hDst );
            ReleaseDC( NULL, hdcS );
            DeleteObject( hBmp );
            hBmpScaled = hOut;
         }
      }

      FImageList = ImageList_Create( icoSz, icoSz, ILC_COLOR24 | ILC_MASK, 16, 4 );
      int nAdded = ImageList_AddMasked( FImageList, hBmpScaled, RGB(255, 0, 255) );
      int nCount = ImageList_GetImageCount( FImageList );
      TBLog( "ImageList: handle=%p added=%d count=%d dpi=%d ico=%d btn=%d",
             (void*)FImageList, nAdded, nCount, dpi, icoSz, btnSz );
      DeleteObject( hBmpScaled );

      SendMessage( FHandle, TB_SETIMAGELIST, 0, (LPARAM) FImageList );
      SendMessage( FHandle, TB_SETBUTTONSIZE, 0, MAKELONG(btnSz, btnSz) );
   }
   TBLog( "TB_SETIMAGELIST and TB_SETBUTTONSIZE sent" );

   /* Remove LIST style and MIXEDBUTTONS so buttons show only icons */
   {
      LONG style = GetWindowLong( FHandle, GWL_STYLE );
      style &= ~TBSTYLE_LIST;
      SetWindowLong( FHandle, GWL_STYLE, style );
   }
   SendMessage( FHandle, TB_SETEXTENDEDSTYLE, 0, 0 );

   /* Delete all buttons and re-add with images (cleanest approach) */
   {
      int nBtns = (int) SendMessage( FHandle, TB_BUTTONCOUNT, 0, 0 );
      TBLog( "  Deleting %d old buttons", nBtns );
      while( nBtns-- > 0 )
         SendMessage( FHandle, TB_DELETEBUTTON, 0, 0 );
   }

   imgIdx = 0;
   for( i = 0; i < FBtnCount; i++ )
   {
      TBBUTTON tbb;
      memset( &tbb, 0, sizeof(tbb) );
      if( FBtns[i].bSeparator )
      {
         tbb.fsStyle = BTNS_SEP;
      }
      else
      {
         tbb.iBitmap = imgIdx;
         tbb.idCommand = FIdBase + i;
         tbb.fsState = TBSTATE_ENABLED;
         tbb.fsStyle = BTNS_BUTTON;
         tbb.iString = -1;  /* no text, icon only */
         imgIdx++;
      }
      SendMessage( FHandle, TB_ADDBUTTONS, 1, (LPARAM) &tbb );
      TBLog( "  Added btn %d img=%d sep=%d", i, tbb.iBitmap, FBtns[i].bSeparator );
   }

   /* Recalculate size */
   SendMessage( FHandle, TB_AUTOSIZE, 0, 0 );
   {
      SIZE sz = {0};
      SendMessage( FHandle, TB_GETMAXSIZE, 0, (LPARAM) &sz );
      FWidth = sz.cx + 8;
      FHeight = sz.cy;
      SetWindowPos( FHandle, NULL, 0, 0, FWidth, FHeight, SWP_NOZORDER );
      TBLog( "Final size: %dx%d", FWidth, FHeight );
   }
}

int TToolBar::AddButton( const char * szText, const char * szTooltip )
{
   if( FBtnCount >= MAX_TOOLBTNS ) return -1;

   int idx = FBtnCount++;
   lstrcpynA( FBtns[idx].szText, szText, sizeof(FBtns[idx].szText) );
   lstrcpynA( FBtns[idx].szTooltip, szTooltip, sizeof(FBtns[idx].szTooltip) );
   FBtns[idx].bSeparator = FALSE;
   FBtns[idx].pOnClick = NULL;

   /* If toolbar already created, add button dynamically */
   if( FHandle )
   {
      TBBUTTON tbb = {0};
      tbb.iBitmap = I_IMAGENONE;
      tbb.idCommand = TOOLBAR_BTN_ID_BASE + idx;
      tbb.fsState = TBSTATE_ENABLED;
      tbb.fsStyle = BTNS_BUTTON | BTNS_AUTOSIZE | BTNS_SHOWTEXT;
      tbb.iString = (INT_PTR) FBtns[idx].szText;
      SendMessage( FHandle, TB_ADDBUTTONS, 1, (LPARAM) &tbb );
      SendMessage( FHandle, TB_AUTOSIZE, 0, 0 );
   }

   return idx;
}

void TToolBar::AddSeparator()
{
   if( FBtnCount >= MAX_TOOLBTNS ) return;

   int idx = FBtnCount++;
   FBtns[idx].bSeparator = TRUE;
   FBtns[idx].pOnClick = NULL;
   FBtns[idx].szText[0] = 0;
   FBtns[idx].szTooltip[0] = 0;

   if( FHandle )
   {
      TBBUTTON tbb = {0};
      tbb.fsStyle = BTNS_SEP;
      SendMessage( FHandle, TB_ADDBUTTONS, 1, (LPARAM) &tbb );
      SendMessage( FHandle, TB_AUTOSIZE, 0, 0 );
   }
}

void TToolBar::SetBtnClick( int nIdx, PHB_ITEM pBlock )
{
   if( nIdx < 0 || nIdx >= FBtnCount ) return;
   if( FBtns[nIdx].pOnClick ) hb_itemRelease( FBtns[nIdx].pOnClick );
   FBtns[nIdx].pOnClick = hb_itemNew( pBlock );
}

void TToolBar::DoCommand( int nBtnIdx )
{
   if( nBtnIdx >= 0 && nBtnIdx < FBtnCount && FBtns[nBtnIdx].pOnClick )
   {
      hb_vmPushEvalSym();
      hb_vmPush( FBtns[nBtnIdx].pOnClick );
      hb_vmSend( 0 );
   }
}

int TToolBar::GetBarHeight()
{
   if( FHandle )
   {
      RECT rc;
      GetWindowRect( FHandle, &rc );
      return rc.bottom - rc.top + 2;  /* +2 for spacing below toolbar */
   }
   return 30;
}

const PROPDESC * TToolBar::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * Splitter WndProc
 * ====================================================================== */

static BOOL s_splitterDragging = FALSE;
static int  s_splitterStartX = 0;
static int  s_splitterStartPos = 0;

static LRESULT CALLBACK SplitterWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   TComponentPalette * pal = (TComponentPalette *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   switch( msg )
   {
      case WM_PAINT:
      {
         PAINTSTRUCT ps;
         RECT rc;
         HDC hDC = BeginPaint( hWnd, &ps );
         GetClientRect( hWnd, &rc );
         /* Draw etched vertical lines for grip appearance */
         {
            int cx = rc.right / 2;
            HPEN hLight = CreatePen( PS_SOLID, 1, GetSysColor( COLOR_3DHIGHLIGHT ) );
            HPEN hShadow = CreatePen( PS_SOLID, 1, GetSysColor( COLOR_3DSHADOW ) );
            HPEN hOld;
            int y;
            /* Fill background */
            { HBRUSH hbr = CreateSolidBrush( g_bDarkIDE ? RGB(45,45,48) : GetSysColor(COLOR_BTNFACE) );
              FillRect( hDC, &rc, hbr );
              DeleteObject( hbr ); }
            /* Draw grip dots */
            hOld = (HPEN) SelectObject( hDC, hShadow );
            for( y = 4; y < rc.bottom - 4; y += 4 )
            {
               MoveToEx( hDC, cx - 1, y, NULL );
               LineTo( hDC, cx - 1, y + 2 );
            }
            SelectObject( hDC, hLight );
            for( y = 5; y < rc.bottom - 3; y += 4 )
            {
               MoveToEx( hDC, cx, y, NULL );
               LineTo( hDC, cx, y + 2 );
            }
            SelectObject( hDC, hOld );
            DeleteObject( hLight );
            DeleteObject( hShadow );
         }
         EndPaint( hWnd, &ps );
         return 0;
      }

      case WM_SETCURSOR:
         SetCursor( LoadCursor( NULL, IDC_SIZEWE ) );
         return TRUE;

      case WM_LBUTTONDOWN:
      {
         POINT pt;
         GetCursorPos( &pt );
         s_splitterDragging = TRUE;
         s_splitterStartX = pt.x;
         s_splitterStartPos = pal ? pal->FSplitPos : 0;
         SetCapture( hWnd );
         return 0;
      }

      case WM_MOUSEMOVE:
         if( s_splitterDragging && pal )
         {
            POINT pt;
            int dx, newPos;
            HWND hParent;
            RECT rcParent;

            GetCursorPos( &pt );
            dx = pt.x - s_splitterStartX;
            newPos = s_splitterStartPos + dx;

            /* Clamp to reasonable range */
            if( newPos < 80 ) newPos = 80;
            hParent = GetParent( hWnd );
            if( hParent )
            {
               GetClientRect( hParent, &rcParent );
               if( newPos > rcParent.right - 200 )
                  newPos = rcParent.right - 200;
            }

            pal->FSplitPos = newPos;

            /* Reposition splitter */
            SetWindowPos( hWnd, NULL, newPos, 0, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER );

            /* Reposition palette tab control */
            if( pal->FTabCtrl && hParent )
            {
               GetClientRect( hParent, &rcParent );
               SetWindowPos( pal->FTabCtrl, NULL,
                  newPos + 6, 0,
                  rcParent.right - newPos - 6, rcParent.bottom,
                  SWP_NOZORDER );
               /* Re-show current tab buttons */
               pal->ShowTab( pal->FCurrentTab );
            }
         }
         return 0;

      case WM_LBUTTONUP:
         if( s_splitterDragging )
         {
            s_splitterDragging = FALSE;
            ReleaseCapture();
         }
         return 0;
   }

   return DefWindowProc( hWnd, msg, wParam, lParam );
}

static BOOL s_splitterClassReg = FALSE;

static void EnsureSplitterClass( void )
{
   if( !s_splitterClassReg )
   {
      WNDCLASSA wc = {0};
      wc.lpfnWndProc   = SplitterWndProc;
      wc.hInstance      = GetModuleHandle( NULL );
      wc.hCursor        = LoadCursor( NULL, IDC_SIZEWE );
      wc.hbrBackground  = (HBRUSH)(COLOR_BTNFACE + 1);
      wc.lpszClassName  = "HbIdeSplitter";
      RegisterClassA( &wc );
      s_splitterClassReg = TRUE;
   }
}

/* ======================================================================
 * TMemo (Standard)
 * ====================================================================== */
TMemo::TMemo() { lstrcpy(FClassName,"TMemo"); FControlType=CT_MEMO; FWidth=180; FHeight=80; FReadOnly=FALSE; FWordWrap=TRUE; FScrollBars=1; }
void TMemo::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="EDIT"; *s=WS_CHILD|WS_VISIBLE|WS_BORDER|ES_MULTILINE|ES_AUTOVSCROLL|WS_VSCROLL|ES_WANTRETURN; *e=WS_EX_CLIENTEDGE; }
const PROPDESC* TMemo::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TPanel (Standard)
 * ====================================================================== */
TPanel::TPanel() { lstrcpy(FClassName,"TPanel"); FControlType=CT_PANEL; lstrcpy(FText,"Panel"); FWidth=185; FHeight=41; FBevelOuter=2; FAlignment=1; }
void TPanel::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="STATIC"; *s=WS_CHILD|WS_VISIBLE|SS_CENTER|SS_CENTERIMAGE|SS_SUNKEN; *e=0; }
const PROPDESC* TPanel::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TScrollBar (Standard)
 * ====================================================================== */
TScrollBar::TScrollBar() { lstrcpy(FClassName,"TScrollBar"); FControlType=CT_SCROLLBAR; FWidth=150; FHeight=17; FMin=0; FMax=100; FPosition=0; FHorizontal=TRUE; }
void TScrollBar::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="SCROLLBAR"; *s=WS_CHILD|WS_VISIBLE|SBS_HORZ; *e=0; }
const PROPDESC* TScrollBar::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TSpeedButton (Additional)
 * ====================================================================== */
TSpeedButton::TSpeedButton() { lstrcpy(FClassName,"TSpeedButton"); FControlType=CT_SPEEDBTN; lstrcpy(FText,"Speed"); FWidth=23; FHeight=22; FFlat=TRUE; }
void TSpeedButton::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="BUTTON"; *s=WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON|BS_FLAT; *e=0; }
const PROPDESC* TSpeedButton::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TMaskEdit (Additional)
 * ====================================================================== */
TMaskEdit::TMaskEdit() { lstrcpy(FClassName,"TMaskEdit"); FControlType=CT_MASKEDIT2; FEditMask[0]=0; }
const PROPDESC* TMaskEdit::GetPropDescs(int*n) { return TEdit::GetPropDescs(n); }

/* ======================================================================
 * TStringGrid (Additional)
 * ====================================================================== */
TStringGrid::TStringGrid() { lstrcpy(FClassName,"TStringGrid"); FControlType=CT_STRINGGRID; FWidth=200; FHeight=120; FColCount=5; FRowCount=5; FFixedCols=1; FFixedRows=1; }
void TStringGrid::CreateParams(DWORD*s,DWORD*e,const char**c) { *c=WC_LISTVIEWA; *s=WS_CHILD|WS_VISIBLE|WS_BORDER|LVS_REPORT|LVS_SHOWSELALWAYS; *e=WS_EX_CLIENTEDGE; }
const PROPDESC* TStringGrid::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TScrollBox (Additional)
 * ====================================================================== */
TScrollBox::TScrollBox() { lstrcpy(FClassName,"TScrollBox"); FControlType=CT_SCROLLBOX; FWidth=185; FHeight=140; }
void TScrollBox::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="STATIC"; *s=WS_CHILD|WS_VISIBLE|WS_HSCROLL|WS_VSCROLL|SS_SUNKEN; *e=WS_EX_CLIENTEDGE; }
const PROPDESC* TScrollBox::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TStaticText (Additional)
 * ====================================================================== */
TStaticText::TStaticText() { lstrcpy(FClassName,"TStaticText"); FControlType=CT_STATICTEXT; lstrcpy(FText,"StaticText"); FWidth=65; FHeight=17; }
void TStaticText::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="STATIC"; *s=WS_CHILD|WS_VISIBLE|SS_SIMPLE|SS_SUNKEN; *e=0; }
const PROPDESC* TStaticText::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TLabeledEdit (Additional)
 * ====================================================================== */
TLabeledEdit::TLabeledEdit() { lstrcpy(FClassName,"TLabeledEdit"); FControlType=CT_LABELEDEDIT; FLabelText[0]=0; }
const PROPDESC* TLabeledEdit::GetPropDescs(int*n) { return TEdit::GetPropDescs(n); }

/* ======================================================================
 * TTabControl2 (Win32)
 * ====================================================================== */
TTabControl2::TTabControl2()
{
   lstrcpy( FClassName, "TFolder" );
   FControlType = CT_TABCONTROL2;
   FWidth = 300; FHeight = 200;
   FTabs[0] = '\0';
   FPageCount = 0;
}

void TTabControl2::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = WC_TABCONTROLA;
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | TCS_TABS;
   *pdwExStyle = 0;
}

const PROPDESC * TTabControl2::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

void TTabControl2::SetTabs( const char * szTabs )
{
   const char * p, * start;
   char buf[256];
   if( !szTabs ) szTabs = "";
   lstrcpynA( FTabs, szTabs, sizeof(FTabs) );
   FPageCount = 0;
   if( !FHandle ) return;
   SendMessageA( FHandle, TCM_DELETEALLITEMS, 0, 0 );
   start = szTabs;
   for( p = szTabs; ; p++ )
   {
      if( *p == '|' || *p == 0 )
      {
         int len = (int)( p - start );
         if( len > (int)sizeof(buf) - 1 ) len = sizeof(buf) - 1;
         memcpy( buf, start, len );
         buf[len] = 0;

         TCITEMA tci = {0};
         tci.mask = TCIF_TEXT;
         tci.pszText = buf;
         SendMessageA( FHandle, TCM_INSERTITEMA, FPageCount, (LPARAM) &tci );
         FPageCount++;

         if( *p == 0 ) break;
         start = p + 1;
      }
   }
   ApplyPageVisibility();
}

int TTabControl2::GetActivePage()
{
   if( !FHandle ) return 0;
   return (int) SendMessageA( FHandle, TCM_GETCURSEL, 0, 0 );
}

void TTabControl2::ApplyPageVisibility()
{
   int i, sel;
   TForm * pForm;
   if( !FHandle || !FCtrlParent ) return;
   pForm = (TForm *) FCtrlParent;
   if( pForm->FControlType != CT_FORM ) return;
   sel = GetActivePage();
   for( i = 0; i < pForm->FChildCount; i++ )
   {
      TControl * c = pForm->FChildren[i];
      if( c && c->FPageOwner == this && c->FHandle )
         ShowWindow( c->FHandle, ( c->FPageIndex == sel ) ? SW_SHOW : SW_HIDE );
   }
}

/* ======================================================================
 * TTrackBar (Win32)
 * ====================================================================== */
TTrackBar::TTrackBar() { lstrcpy(FClassName,"TTrackBar"); FControlType=CT_TRACKBAR; FWidth=150; FHeight=25; FMin=0; FMax=10; FPosition=0; }
void TTrackBar::CreateParams(DWORD*s,DWORD*e,const char**c) { *c=TRACKBAR_CLASSA; *s=WS_CHILD|WS_VISIBLE|TBS_AUTOTICKS|TBS_BOTTOM; *e=0; }
const PROPDESC* TTrackBar::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TUpDown (Win32)
 * ====================================================================== */
TUpDown::TUpDown() { lstrcpy(FClassName,"TUpDown"); FControlType=CT_UPDOWN; FWidth=17; FHeight=22; FMin=0; FMax=100; FPosition=0; }
void TUpDown::CreateParams(DWORD*s,DWORD*e,const char**c) { *c=UPDOWN_CLASSA; *s=WS_CHILD|WS_VISIBLE|UDS_ARROWKEYS|UDS_SETBUDDYINT|UDS_ALIGNRIGHT; *e=0; }
const PROPDESC* TUpDown::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TDateTimePicker (Win32)
 * ====================================================================== */
TDateTimePicker::TDateTimePicker() { lstrcpy(FClassName,"TDateTimePicker"); FControlType=CT_DATETIMEPICKER; FWidth=186; FHeight=24; }
void TDateTimePicker::CreateParams(DWORD*s,DWORD*e,const char**c) { *c=DATETIMEPICK_CLASSA; *s=WS_CHILD|WS_VISIBLE|DTS_SHORTDATEFORMAT; *e=0; }
const PROPDESC* TDateTimePicker::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TMonthCalendar (Win32)
 * ====================================================================== */
TMonthCalendar::TMonthCalendar() { lstrcpy(FClassName,"TMonthCalendar"); FControlType=CT_MONTHCALENDAR; FWidth=227; FHeight=155; }
void TMonthCalendar::CreateParams(DWORD*s,DWORD*e,const char**c) { *c=MONTHCAL_CLASSA; *s=WS_CHILD|WS_VISIBLE; *e=0; }
const PROPDESC* TMonthCalendar::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TWebView (Win32 placeholder — design-time only)
 * ====================================================================== */
TWebView::TWebView() { lstrcpy(FClassName,"TWebView"); FControlType=CT_WEBVIEW; FWidth=320; FHeight=240; }
void TWebView::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="STATIC"; *s=WS_CHILD|WS_VISIBLE|WS_BORDER|SS_BLACKFRAME; *e=0; }
const PROPDESC* TWebView::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TPaintBox (System)
 * ====================================================================== */
TPaintBox::TPaintBox() { lstrcpy(FClassName,"TPaintBox"); FControlType=CT_PAINTBOX; FWidth=105; FHeight=105; }
void TPaintBox::CreateParams(DWORD*s,DWORD*e,const char**c) { *c="STATIC"; *s=WS_CHILD|WS_VISIBLE|SS_OWNERDRAW; *e=0; }
const PROPDESC* TPaintBox::GetPropDescs(int*n) { return TControl::GetPropDescs(n); }

/* ======================================================================
 * TListBox
 * ====================================================================== */

TListBox::TListBox()
{
   lstrcpy( FClassName, "TListBox" );
   FControlType = CT_LISTBOX;
   FWidth = 120; FHeight = 80;
   FItemCount = 0;
   FItemIndex  = 0;
   memset( FItems, 0, sizeof(FItems) );
}

void TListBox::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = "LISTBOX";
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL | LBS_NOTIFY;
   *pdwExStyle = WS_EX_CLIENTEDGE;
}

void TListBox::CreateHandle( HWND hParent )
{
   TControl::CreateHandle( hParent );
   if( FHandle ) {
      for( int i = 0; i < FItemCount; i++ )
         SendMessage( FHandle, LB_ADDSTRING, 0, (LPARAM) FItems[i] );
      if( FItemIndex > 0 )
         SendMessage( FHandle, LB_SETCURSEL, FItemIndex - 1, 0 );
   }
}

const PROPDESC * TListBox::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TRadioButton
 * ====================================================================== */

TRadioButton::TRadioButton()
{
   lstrcpy( FClassName, "TRadioButton" );
   FControlType = CT_RADIO;
   lstrcpy( FText, "RadioButton" );
   FWidth = 120; FHeight = 20;
   FChecked = FALSE;
}

void TRadioButton::CreateHandle( HWND hParent )
{
   TControl::CreateHandle( hParent );
   if( FHandle && FChecked )
      SendMessage( FHandle, BM_SETCHECK, BST_CHECKED, 0 );
}

void TRadioButton::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = "BUTTON";
   *pdwStyle = WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON;
   *pdwExStyle = 0;
}

const PROPDESC * TRadioButton::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TBitBtn (C++Builder Additional: button with glyph)
 * ====================================================================== */

TBitBtn::TBitBtn()
{
   lstrcpy( FClassName, "TBitBtn" );
   FControlType = CT_BITBTN;
   lstrcpy( FText, "BitBtn" );
   FWidth = 88; FHeight = 26;
}

const PROPDESC * TBitBtn::GetPropDescs( int * pnCount )
{
   return TButton::GetPropDescs( pnCount );
}

/* ======================================================================
 * TImage (C++Builder Additional: static image)
 * ====================================================================== */

TImage::TImage()
{
   lstrcpy( FClassName, "TImage" );
   FControlType = CT_IMAGE;
   FWidth = 100; FHeight = 100;
   FStretch = FALSE;
   FCenter = FALSE;
   FProportional = FALSE;
}

void TImage::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = "STATIC";
   *pdwStyle = WS_CHILD | WS_VISIBLE | SS_BITMAP | SS_CENTERIMAGE;
   *pdwExStyle = 0;
}

const PROPDESC * TImage::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TShape (C++Builder Additional: geometric shape)
 * ====================================================================== */

TShape::TShape()
{
   lstrcpy( FClassName, "TShape" );
   FControlType = CT_SHAPE;
   FShapeType = 0;  /* Rectangle */
   FWidth = 65; FHeight = 65;
}

void TShape::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = "STATIC";
   *pdwStyle = WS_CHILD | WS_VISIBLE | SS_OWNERDRAW;
   *pdwExStyle = 0;
}

const PROPDESC * TShape::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TBevel (C++Builder Additional: etched frame)
 * ====================================================================== */

TBevel::TBevel()
{
   lstrcpy( FClassName, "TBevel" );
   FControlType = CT_BEVEL;
   FBevelStyle = 0;  /* bsLowered */
   FWidth = 150; FHeight = 50;
}

void TBevel::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = "STATIC";
   *pdwStyle = WS_CHILD | WS_VISIBLE | SS_ETCHEDFRAME;
   *pdwExStyle = 0;
}

const PROPDESC * TBevel::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TTreeView (C++Builder Win32 tab)
 * ====================================================================== */

TTreeView::TTreeView()
{
   lstrcpy( FClassName, "TTreeView" );
   FControlType = CT_TREEVIEW;
   FWidth = 150; FHeight = 200;
}

void TTreeView::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = WC_TREEVIEWA;
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_BORDER |
               TVS_HASLINES | TVS_LINESATROOT | TVS_HASBUTTONS | TVS_SHOWSELALWAYS;
   *pdwExStyle = WS_EX_CLIENTEDGE;
}

const PROPDESC * TTreeView::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* TPageControl class removed - logic merged into TTabControl2 above. */

/* ======================================================================
 * TListView (C++Builder Win32 tab)
 * ====================================================================== */

TListView::TListView()
{
   lstrcpy( FClassName, "TListView" );
   FControlType = CT_LISTVIEW;
   FViewStyle = 2;  /* vsReport */
   FWidth = 200; FHeight = 150;
}

void TListView::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = WC_LISTVIEWA;
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_SHOWSELALWAYS;
   *pdwExStyle = WS_EX_CLIENTEDGE;
}

const PROPDESC * TListView::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TProgressBar (C++Builder Win32 tab)
 * ====================================================================== */

TProgressBar::TProgressBar()
{
   lstrcpy( FClassName, "TProgressBar" );
   FControlType = CT_PROGRESSBAR;
   FMin = 0; FMax = 100; FPosition = 0;
   FWidth = 150; FHeight = 20;
}

void TProgressBar::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = PROGRESS_CLASSA;
   *pdwStyle = WS_CHILD | WS_VISIBLE;
   *pdwExStyle = 0;
}

const PROPDESC * TProgressBar::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TRichEdit (C++Builder Win32 tab)
 * ====================================================================== */

TRichEdit::TRichEdit()
{
   lstrcpy( FClassName, "TRichEdit" );
   FControlType = CT_RICHEDIT;
   FReadOnly = FALSE;
   FWidth = 200; FHeight = 100;
}

void TRichEdit::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = "RichEdit20A";
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL |
               ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN;
   *pdwExStyle = WS_EX_CLIENTEDGE;
}

const PROPDESC * TRichEdit::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TBrowse - Powerful data grid
 * ====================================================================== */

TBrowse::TBrowse()
{
   lstrcpy( FClassName, "TBrowse" );
   FControlType = CT_BROWSE;
   FWidth = 400; FHeight = 200;
   FColCount = 0;
   FRowCount = 0;
   FCurrentRow = -1;
   FCurrentCol = -1;
   FShowHeaders = TRUE;
   FShowFooters = FALSE;
   FShowGridLines = TRUE;
   FShowRowNumbers = FALSE;
   FCellEditing = FALSE;
   FMultiSelect = FALSE;
   FAltRowColors = TRUE;
   FAltRowColor = RGB(245, 245, 250);
   FRowHeight = 20;
   FHeaderHeight = 24;
   FFooterHeight = 22;
   FSortColumn = -1;
   FSortAscending = TRUE;
   FOnCellClick = NULL;
   FOnCellDblClick = NULL;
   FOnHeaderClick = NULL;
   FOnSort = NULL;
   FOnScroll = NULL;
   FOnCellEdit = NULL;
   FOnCellPaint = NULL;
   FOnRowSelect = NULL;
   FOnKeyDown = NULL;
   FOnColumnResize = NULL;
   FDataSource = NULL;
   FDataSourceName[0] = 0;
   FFooterWnd = NULL;
   memset( FCols, 0, sizeof(FCols) );
}

TBrowse::~TBrowse()
{
   if( FFooterWnd ) { DestroyWindow( FFooterWnd ); FFooterWnd = NULL; }
   #define RELB(e) if( e ) { hb_itemRelease( e ); e = NULL; }
   RELB(FOnCellClick);   RELB(FOnCellDblClick); RELB(FOnHeaderClick);
   RELB(FOnSort);        RELB(FOnScroll);        RELB(FOnCellEdit);
   RELB(FOnCellPaint);   RELB(FOnRowSelect);     RELB(FOnKeyDown);
   RELB(FOnColumnResize); RELB(FDataSource);
   #undef RELB
}

/* Footer bar WndProc — paints column footer texts */
static LRESULT CALLBACK BrowseFooterProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   TBrowse * br = (TBrowse *) GetWindowLongPtr( hWnd, GWLP_USERDATA );
   if( msg == WM_PAINT && br )
   {
      PAINTSTRUCT ps;
      HDC hDC = BeginPaint( hWnd, &ps );
      RECT rc;
      int i, x;
      HFONT hFont = (HFONT) SendMessage( br->FHandle, WM_GETFONT, 0, 0 );
      HFONT hOld = hFont ? (HFONT) SelectObject( hDC, hFont ) : NULL;
      HBRUSH hBg;
      HPEN hPen;

      GetClientRect( hWnd, &rc );

      /* Background: light gray */
      hBg = CreateSolidBrush( RGB(240, 240, 240) );
      FillRect( hDC, &rc, hBg );
      DeleteObject( hBg );

      /* Top border line */
      hPen = CreatePen( PS_SOLID, 1, RGB(200, 200, 200) );
      SelectObject( hDC, hPen );
      MoveToEx( hDC, 0, 0, NULL );
      LineTo( hDC, rc.right, 0 );
      DeleteObject( hPen );

      SetBkMode( hDC, TRANSPARENT );
      SetTextColor( hDC, RGB(60, 60, 60) );

      /* Draw each column footer aligned with ListView columns */
      x = 0;
      for( i = 0; i < br->FColCount; i++ )
      {
         int cw = (int) SendMessageA( br->FHandle, LVM_GETCOLUMNWIDTH, i, 0 );
         if( br->FCols[i].szFooterText[0] )
         {
            RECT rcCol;
            rcCol.left = x + 4;
            rcCol.top = 2;
            rcCol.right = x + cw - 2;
            rcCol.bottom = rc.bottom;
            DrawTextA( hDC, br->FCols[i].szFooterText, -1, &rcCol,
               DT_SINGLELINE | DT_VCENTER | DT_LEFT | DT_NOPREFIX );
         }
         /* Column separator */
         hPen = CreatePen( PS_SOLID, 1, RGB(210, 210, 210) );
         SelectObject( hDC, hPen );
         MoveToEx( hDC, x + cw - 1, 2, NULL );
         LineTo( hDC, x + cw - 1, rc.bottom );
         DeleteObject( hPen );

         x += cw;
      }

      if( hOld ) SelectObject( hDC, hOld );
      EndPaint( hWnd, &ps );
      return 0;
   }
   if( msg == WM_ERASEBKGND ) return 1;
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

void TBrowse::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pszClass = WC_LISTVIEWA;
   *pdwStyle = WS_CHILD | WS_VISIBLE | WS_BORDER |
               LVS_REPORT | LVS_SHOWSELALWAYS | LVS_SINGLESEL;
   if( FShowGridLines )
      *pdwStyle |= LVS_NOSORTHEADER;
   *pdwExStyle = WS_EX_CLIENTEDGE;
}

void TBrowse::CreateHandle( HWND hParent )
{
   int i;
   LVCOLUMNA lvc;

   /* Create the ListView */
   TControl::CreateHandle( hParent );
   if( !FHandle ) return;

   /* Extended styles: grid lines, full row select, alternating rows */
   SendMessage( FHandle, LVM_SETEXTENDEDLISTVIEWSTYLE, 0,
      LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES | LVS_EX_DOUBLEBUFFER |
      LVS_EX_HEADERDRAGDROP );

   /* Apply background color if set */
   if( FClrPane != CLR_INVALID )
   {
      SendMessage( FHandle, LVM_SETBKCOLOR, 0, (LPARAM) FClrPane );
      SendMessage( FHandle, LVM_SETTEXTBKCOLOR, 0, (LPARAM) FClrPane );
   }

   /* Add columns */
   for( i = 0; i < FColCount; i++ )
   {
      memset( &lvc, 0, sizeof(lvc) );
      lvc.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_FMT;
      lvc.pszText = FCols[i].szTitle;
      lvc.cx = FCols[i].nWidth;
      switch( FCols[i].nAlign ) {
         case 1: lvc.fmt = LVCFMT_CENTER; break;
         case 2: lvc.fmt = LVCFMT_RIGHT; break;
         default: lvc.fmt = LVCFMT_LEFT; break;
      }
      SendMessageA( FHandle, LVM_INSERTCOLUMNA, i, (LPARAM) &lvc );
   }

   /* Create footer bar below ListView */
   {
      static BOOL bFooterReg = FALSE;
      HWND hParent = GetParent( FHandle );
      if( !bFooterReg ) {
         WNDCLASSA wc = {0};
         wc.lpfnWndProc = BrowseFooterProc;
         wc.hInstance = GetModuleHandle(NULL);
         wc.lpszClassName = "HBBrowseFooter";
         wc.hCursor = LoadCursor( NULL, IDC_ARROW );
         RegisterClassA( &wc );
         bFooterReg = TRUE;
      }
      FFooterWnd = CreateWindowExA( 0, "HBBrowseFooter", NULL,
         WS_CHILD | WS_VISIBLE,
         FLeft, FTop + FHeight - FFooterHeight, FWidth, FFooterHeight,
         hParent, NULL, GetModuleHandle(NULL), NULL );
      SetWindowLongPtr( FFooterWnd, GWLP_USERDATA, (LONG_PTR) this );
      /* Shrink ListView to make room for footer */
      SetWindowPos( FHandle, NULL, FLeft, FTop, FWidth, FHeight - FFooterHeight,
         SWP_NOZORDER );
   }
}

int TBrowse::AddColumn( const char * szTitle, const char * szField, int nWidth, int nAlign )
{
   if( FColCount >= MAX_BROWSE_COLS ) return -1;
   int idx = FColCount++;
   lstrcpynA( FCols[idx].szTitle, szTitle, 64 );
   lstrcpynA( FCols[idx].szFieldName, szField, 64 );
   FCols[idx].nWidth = nWidth > 0 ? nWidth : 100;
   FCols[idx].nAlign = nAlign;
   FCols[idx].bEditable = FALSE;
   FCols[idx].bVisible = TRUE;
   FCols[idx].bSortable = TRUE;
   FCols[idx].nHeaderClr = RGB(240, 240, 240);
   FCols[idx].nFooterClr = RGB(240, 240, 240);
   FCols[idx].szFooterText[0] = 0;
   FCols[idx].szFormat[0] = 0;
   return idx;
}

void TBrowse::SetFooterText( int nCol, const char * szText )
{
   if( nCol >= 0 && nCol < FColCount )
   {
      lstrcpynA( FCols[nCol].szFooterText, szText, 64 );
      UpdateFooter();
   }
}

void TBrowse::UpdateFooter()
{
   if( FFooterWnd )
      InvalidateRect( FFooterWnd, NULL, TRUE );
}

void TBrowse::SetCellText( int nRow, int nCol, const char * szText )
{
   LVITEMA lvi;
   if( !FHandle || nCol < 0 || nCol >= FColCount ) return;

   /* Ensure row exists */
   while( FRowCount <= nRow )
   {
      memset( &lvi, 0, sizeof(lvi) );
      lvi.mask = LVIF_TEXT;
      lvi.iItem = FRowCount;
      lvi.pszText = (LPSTR) "";
      SendMessageA( FHandle, LVM_INSERTITEMA, 0, (LPARAM) &lvi );
      FRowCount++;
   }

   /* Set cell text */
   lvi.mask = LVIF_TEXT;
   lvi.iItem = nRow;
   lvi.iSubItem = nCol;
   lvi.pszText = (char *) szText;
   SendMessageA( FHandle, LVM_SETITEMA, 0, (LPARAM) &lvi );
}

const char * TBrowse::GetCellText( int nRow, int nCol )
{
   static char buf[256];
   LVITEMA lvi;
   buf[0] = 0;
   if( !FHandle ) return buf;
   lvi.iItem = nRow;
   lvi.iSubItem = nCol;
   lvi.pszText = buf;
   lvi.cchTextMax = sizeof(buf);
   SendMessageA( FHandle, LVM_GETITEMTEXTA, nRow, (LPARAM) &lvi );
   return buf;
}

void TBrowse::Refresh()
{
   if( FHandle )
      InvalidateRect( FHandle, NULL, TRUE );
}

const PROPDESC * TBrowse::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * TComponentPalette
 * ====================================================================== */

/* Subclass TabControl to forward WM_COMMAND (button clicks) to the form */
static WNDPROC s_oldTabProc = NULL;

static void PalLog( const char * fmt, ... )
{
   FILE * f = fopen( "c:\\HarbourBuilder\\palette_trace.log", "a" );
   if( f ) { va_list ap; va_start(ap,fmt); vfprintf(f,fmt,ap); va_end(ap); fprintf(f,"\n"); fclose(f); }
}

static LRESULT CALLBACK PaletteTabSubProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_ERASEBKGND )
   {
      HDC hdc = (HDC) wParam;
      RECT rc;
      HBRUSH hbr = CreateSolidBrush( g_bDarkIDE ? RGB(45,45,48) : GetSysColor(COLOR_BTNFACE) );
      GetClientRect( hWnd, &rc );
      FillRect( hdc, &rc, hbr );
      DeleteObject( hbr );
      return 1;
   }
   if( msg == WM_CTLCOLORBTN )
   {
      static HBRUSH s_hBtnBrush = NULL;
      if( s_hBtnBrush ) DeleteObject( s_hBtnBrush );
      s_hBtnBrush = CreateSolidBrush( g_bDarkIDE ? RGB(45,45,48) : GetSysColor(COLOR_BTNFACE) );
      return (LRESULT) s_hBtnBrush;
   }
   /* Owner-draw palette icon buttons */
   if( msg == WM_DRAWITEM )
   {
      DRAWITEMSTRUCT * di = (DRAWITEMSTRUCT *) lParam;
      if( di && di->CtlType == ODT_BUTTON )
      {
         TComponentPalette * pal = (TComponentPalette *) GetWindowLongPtr( hWnd, GWLP_USERDATA );
         int imgIdx = (int) GetWindowLongPtr( di->hwndItem, GWLP_USERDATA );
         BOOL isHot = ( di->itemState & ODS_SELECTED );
         if( g_bDarkIDE )
         {
            HBRUSH hbr = CreateSolidBrush( isHot ? RGB(70,70,70) : RGB(50,50,53) );
            FillRect( di->hDC, &di->rcItem, hbr );
            DeleteObject( hbr );
         }
         else
         {
            HBRUSH hbr = CreateSolidBrush( isHot ? GetSysColor(COLOR_BTNHIGHLIGHT) : GetSysColor(COLOR_BTNFACE) );
            FillRect( di->hDC, &di->rcItem, hbr );
            DeleteObject( hbr );
         }
         /* Draw icon centered — special-case CT_MAINMENU since palette.bmp
            has no slot for it; render a vector menubar glyph instead. */
         {
            int iconW = 48, iconH = 48;
            /* Cap icon to button area so larger icons don't overflow narrow tabs */
            int btnW = di->rcItem.right - di->rcItem.left;
            int btnH = di->rcItem.bottom - di->rcItem.top;
            if( iconW > btnW - 4 ) iconW = btnW - 4;
            if( iconH > btnH - 4 ) iconH = btnH - 4;
            int cx = di->rcItem.left + (btnW - iconW) / 2;
            int cy = di->rcItem.top + (btnH - iconH) / 2;
            int nCtrlType = -1;
            if( pal )
            {
               int btnIdx = (int)( di->CtlID - 200 );
               int nTabCur = pal->FCurrentTab;
               if( nTabCur >= 0 && nTabCur < pal->FTabCount &&
                   btnIdx >= 0 && btnIdx < pal->FTabs[nTabCur].nBtnCount )
                  nCtrlType = pal->FTabs[nTabCur].btns[btnIdx].nControlType;
            }
            /* Per-control-type PNG override takes priority */
            if( pal && nCtrlType > 0 && nCtrlType < 256 &&
                pal->FCompIconOverride[nCtrlType] )
            {
               HDC hMem = CreateCompatibleDC( di->hDC );
               HBITMAP hOld = (HBITMAP) SelectObject( hMem, pal->FCompIconOverride[nCtrlType] );
               BLENDFUNCTION bf = { AC_SRC_OVER, 0, 255, AC_SRC_ALPHA };
               AlphaBlend( di->hDC, cx, cy, iconW, iconH,
                           hMem, 0, 0, 48, 48, bf );
               SelectObject( hMem, hOld );
               DeleteDC( hMem );
            }
            else if( nCtrlType == 200 /* CT_MAINMENU */ )
            {
               /* Window outline */
               COLORREF clrBorder = g_bDarkIDE ? RGB(180,180,180) : RGB(60,60,60);
               COLORREF clrTitle  = RGB( 70,130,180);
               COLORREF clrMenu   = g_bDarkIDE ? RGB(80,80,80) : RGB(225,225,225);
               COLORREF clrItem   = g_bDarkIDE ? RGB(200,200,200) : RGB(60,60,60);
               RECT rcW = { cx, cy + 2, cx + iconW, cy + iconH - 1 };
               RECT rcT = { cx + 1, cy + 3, cx + iconW - 1, cy + 7 };
               RECT rcM = { cx + 1, cy + 7, cx + iconW - 1, cy + 12 };
               HBRUSH hbT = CreateSolidBrush( clrTitle );
               HBRUSH hbM = CreateSolidBrush( clrMenu );
               HPEN   hpB = CreatePen( PS_SOLID, 1, clrBorder );
               HBRUSH hbX = (HBRUSH) GetStockObject( NULL_BRUSH );
               HPEN   hpO = (HPEN)   SelectObject( di->hDC, hpB );
               HBRUSH hbO = (HBRUSH) SelectObject( di->hDC, hbX );
               Rectangle( di->hDC, rcW.left, rcW.top, rcW.right, rcW.bottom );
               FillRect( di->hDC, &rcT, hbT );
               FillRect( di->hDC, &rcM, hbM );
               /* Menu item ticks: File Edit View Help */
               { HBRUSH hbI = CreateSolidBrush( clrItem ); int k;
                 int xs[4] = { cx + 3, cx + 9, cx + 14, cx + 19 };
                 int ws[4] = { 4, 3, 4, 3 };
                 for( k = 0; k < 4; k++ ) {
                    RECT rcI = { xs[k], cy + 8, xs[k] + ws[k], cy + 11 };
                    FillRect( di->hDC, &rcI, hbI );
                 }
                 DeleteObject( hbI );
               }
               SelectObject( di->hDC, hpO );
               SelectObject( di->hDC, hbO );
               DeleteObject( hbT );
               DeleteObject( hbM );
               DeleteObject( hpB );
            }
            else if( pal && pal->FPalImageList )
            {
               ImageList_Draw( pal->FPalImageList, imgIdx, di->hDC, cx, cy, ILD_TRANSPARENT );
            }
         }
         /* Subtle border */
         {
            HPEN hPen = CreatePen( PS_SOLID, 1, g_bDarkIDE ? RGB(65,65,65) : GetSysColor(COLOR_BTNSHADOW) );
            HPEN hOld = (HPEN) SelectObject( di->hDC, hPen );
            HBRUSH hNull = (HBRUSH) GetStockObject( NULL_BRUSH );
            HBRUSH hOldBr = (HBRUSH) SelectObject( di->hDC, hNull );
            Rectangle( di->hDC, di->rcItem.left, di->rcItem.top, di->rcItem.right, di->rcItem.bottom );
            SelectObject( di->hDC, hOld );
            SelectObject( di->hDC, hOldBr );
            DeleteObject( hPen );
         }
         return TRUE;
      }
   }
   if( msg == WM_COMMAND )
   {
      WORD wId = LOWORD(wParam);
      WORD wNotify = HIWORD(wParam);
      HWND hForm = GetParent( hWnd );
      PalLog( "TabSubProc WM_COMMAND: id=%d notify=%d hForm=%p", wId, wNotify, hForm );
      if( hForm )
         return SendMessage( hForm, WM_COMMAND, wParam, lParam );
   }
   return CallWindowProc( s_oldTabProc, hWnd, msg, wParam, lParam );
}

TComponentPalette::TComponentPalette()
{
   lstrcpy( FClassName, "TComponentPalette" );
   FControlType = CT_TABCONTROL;
   FTabCtrl = NULL;
   FSplitter = NULL;
   FBtnPanel = NULL;
   FTabCount = 0;
   FCurrentTab = 0;
   FSplitPos = 0;
   FOnSelect = NULL;
   FPalImageList = NULL;
   FTabStop = FALSE;
   memset( FTabs, 0, sizeof(FTabs) );
   memset( FBtns, 0, sizeof(FBtns) );
   memset( FCompIconOverride, 0, sizeof(FCompIconOverride) );
}

TComponentPalette::~TComponentPalette()
{
   if( FOnSelect ) hb_itemRelease( FOnSelect );
   for( int i = 0; i < 256; i++ )
      if( FCompIconOverride[i] ) DeleteObject( FCompIconOverride[i] );
}

void TComponentPalette::CreateHandle( HWND hParent )
{
   RECT rcParent;
   int tbWidth;
   TForm * pForm;

   if( !hParent ) return;

   /* Get parent form to find toolbar width (max of both rows) */
   pForm = (TForm *) GetWindowLongPtr( hParent, GWLP_USERDATA );
   tbWidth = ( pForm && pForm->FToolBar ) ? pForm->FToolBar->FWidth + 4 : 0;
   if( pForm && pForm->FToolBar2 && pForm->FToolBar2->FWidth + 4 > tbWidth )
      tbWidth = pForm->FToolBar2->FWidth + 4;

   GetClientRect( hParent, &rcParent );

   /* Store initial split position */
   FSplitPos = tbWidth + 62;

   /* Draggable vertical splitter between speedbar and palette */
   EnsureSplitterClass();
   FSplitter = CreateWindowExA( 0, "HbIdeSplitter", NULL,
      WS_CHILD | WS_VISIBLE,
      FSplitPos, 0, 6, rcParent.bottom,
      hParent, NULL, GetModuleHandle(NULL), NULL );
   if( FSplitter )
      SetWindowLongPtr( FSplitter, GWLP_USERDATA, (LONG_PTR) this );

   /* Create tab control to the right of the splitter */
   FTabCtrl = CreateWindowExA( 0, WC_TABCONTROLA, NULL,
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | TCS_TABS | TCS_OWNERDRAWFIXED,
      FSplitPos + 6, 0,
      rcParent.right - FSplitPos - 6, rcParent.bottom,
      hParent, NULL, GetModuleHandle(NULL), NULL );

   if( !FTabCtrl ) return;
   FHandle = FTabCtrl;

   /* Subclass TabControl to forward button WM_COMMAND to the form */
   s_oldTabProc = (WNDPROC) SetWindowLongPtr( FTabCtrl, GWLP_WNDPROC, (LONG_PTR) PaletteTabSubProc );
   SetWindowLongPtr( FTabCtrl, GWLP_USERDATA, (LONG_PTR) this );

   /* Apply the exact same font as the toolbar for visual consistency */
   if( pForm && pForm->FToolBar && pForm->FToolBar->FHandle )
      SendMessage( FTabCtrl, WM_SETFONT,
         SendMessage( pForm->FToolBar->FHandle, WM_GETFONT, 0, 0 ), TRUE );
   else
      SendMessage( FTabCtrl, WM_SETFONT,
         SendMessage( hParent, WM_GETFONT, 0, 0 ), TRUE );

   /* Add tabs */
   {
      int i;
      TCITEMA tci;
      for( i = 0; i < FTabCount; i++ )
      {
         memset( &tci, 0, sizeof(tci) );
         tci.mask = TCIF_TEXT;
         tci.pszText = FTabs[i].szName;
         SendMessageA( FTabCtrl, TCM_INSERTITEMA, i, (LPARAM) &tci );
      }
   }

   /* Show first tab's buttons */
   ShowTab( 0 );
}

int TComponentPalette::AddTab( const char * szName )
{
   if( FTabCount >= MAX_PALETTE_TABS ) return -1;
   int idx = FTabCount++;
   lstrcpynA( FTabs[idx].szName, szName, sizeof(FTabs[idx].szName) );
   FTabs[idx].nBtnCount = 0;
   return idx;
}

void TComponentPalette::AddComponent( int nTab, const char * szText, const char * szTooltip, int nCtrlType )
{
   if( nTab < 0 || nTab >= FTabCount ) return;
   PaletteTab * t = &FTabs[nTab];
   if( t->nBtnCount >= MAX_PALETTE_BTNS ) return;
   int idx = t->nBtnCount++;
   lstrcpynA( t->btns[idx].szText, szText, sizeof(t->btns[idx].szText) );
   lstrcpynA( t->btns[idx].szTooltip, szTooltip, sizeof(t->btns[idx].szTooltip) );
   t->btns[idx].nControlType = nCtrlType;
}

void TComponentPalette::ShowTab( int nTab )
{
   int i, xPos = 4, imgBase = 0;
   RECT rcTab;

   if( nTab < 0 || nTab >= FTabCount ) return;
   FCurrentTab = nTab;

   /* Remove existing buttons */
   for( i = 0; i < MAX_PALETTE_BTNS; i++ )
   {
      if( FBtns[i] ) { DestroyWindow( FBtns[i] ); FBtns[i] = NULL; }
   }

   /* Get the display area inside the tab control */
   GetClientRect( FTabCtrl, &rcTab );
   SendMessage( FTabCtrl, TCM_ADJUSTRECT, FALSE, (LPARAM) &rcTab );

   /* Calculate image base index: sum of buttons in all previous tabs */
   for( i = 0; i < nTab; i++ )
      imgBase += FTabs[i].nBtnCount;

   /* Create square buttons for this tab (as large as the tab area allows) */
   {
      PaletteTab * t = &FTabs[nTab];
      int areaH = rcTab.bottom - rcTab.top - 4;
      int btnSize = areaH;          /* square: width = height */
      if( btnSize < 16 ) btnSize = 16;
      int y = rcTab.top + ( rcTab.bottom - rcTab.top - btnSize ) / 2;

      xPos = rcTab.left + 4;
      for( i = 0; i < t->nBtnCount; i++ )
      {
         if( FPalImageList )
         {
            /* Owner-draw icon button for dark mode support */
            FBtns[i] = CreateWindowExA( 0, "BUTTON", NULL,
               WS_CHILD | WS_VISIBLE | BS_OWNERDRAW,
               xPos, y, btnSize, btnSize,
               FTabCtrl, (HMENU)(LONG_PTR)(200 + i),
               GetModuleHandle(NULL), NULL );

            if( FBtns[i] )
            {
               /* Store image index in window user data for WM_DRAWITEM */
               SetWindowLongPtr( FBtns[i], GWLP_USERDATA, (LONG_PTR)(imgBase + i) );
            }
         }
         else
         {
            /* Text fallback */
            FBtns[i] = CreateWindowExA( 0, "BUTTON", t->btns[i].szText,
               WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT | BS_CENTER,
               xPos, y, btnSize, btnSize,
               FTabCtrl, (HMENU)(LONG_PTR)(200 + i),
               GetModuleHandle(NULL), NULL );

            if( FBtns[i] )
               SendMessage( FBtns[i], WM_SETFONT,
                  SendMessage( FTabCtrl, WM_GETFONT, 0, 0 ), TRUE );
         }

         /* Add tooltip for this button */
         if( FBtns[i] && t->btns[i].szTooltip[0] )
         {
            HWND hTT = CreateWindowExA( WS_EX_TOPMOST, TOOLTIPS_CLASSA, NULL,
               WS_POPUP | TTS_NOPREFIX | TTS_ALWAYSTIP,
               0, 0, 0, 0, FTabCtrl, NULL, GetModuleHandle(NULL), NULL );
            if( hTT )
            {
               TOOLINFOA ti = {0};
               ti.cbSize = sizeof(ti);
               ti.uFlags = TTF_SUBCLASS | TTF_IDISHWND;
               ti.hwnd = FTabCtrl;
               ti.uId = (UINT_PTR) FBtns[i];
               ti.lpszText = t->btns[i].szTooltip;
               SendMessageA( hTT, TTM_ADDTOOLA, 0, (LPARAM) &ti );
            }
         }

         xPos += btnSize + 2;
      }
   }
}

void TComponentPalette::LoadImages( const char * szBmpPath )
{
   HBITMAP hBmp;

   if( !szBmpPath ) return;

   hBmp = (HBITMAP) LoadImageA( NULL, szBmpPath, IMAGE_BITMAP,
      0, 0, LR_LOADFROMFILE );
   if( !hBmp ) return;

   FPalImageList = ImageList_Create( 32, 32, ILC_COLOR24 | ILC_MASK, 16, 4 );
   ImageList_AddMasked( FPalImageList, hBmp, RGB(255, 0, 255) );
   DeleteObject( hBmp );

   /* Refresh current tab to use images */
   if( FTabCtrl )
      ShowTab( FCurrentTab );
}

void TComponentPalette::AppendImages( const char * szBmpPath )
{
   HBITMAP hBmp;

   if( !szBmpPath || !FPalImageList ) return;

   hBmp = (HBITMAP) LoadImageA( NULL, szBmpPath, IMAGE_BITMAP,
      0, 0, LR_LOADFROMFILE );
   if( !hBmp ) return;

   ImageList_AddMasked( FPalImageList, hBmp, RGB(255, 0, 255) );
   DeleteObject( hBmp );

   /* Refresh current tab */
   if( FTabCtrl )
      ShowTab( FCurrentTab );
}

/* Load a PNG file via GDI+ as a 32x32 32-bit BGRA HBITMAP. */
static HBITMAP LoadPng32( const char * szPath )
{
   if( !szPath ) return NULL;

   /* Convert UTF-8 path to wide string */
   int wlen = MultiByteToWideChar( CP_UTF8, 0, szPath, -1, NULL, 0 );
   if( wlen <= 0 ) return NULL;
   WCHAR * wpath = (WCHAR *) malloc( wlen * sizeof(WCHAR) );
   MultiByteToWideChar( CP_UTF8, 0, szPath, -1, wpath, wlen );

   ULONG_PTR gpToken = 0;
   Gdiplus::GdiplusStartupInput gpInput;
   Gdiplus::GdiplusStartup( &gpToken, &gpInput, NULL );

   HBITMAP hbm = NULL;
   Gdiplus::Bitmap * src = Gdiplus::Bitmap::FromFile( wpath, FALSE );
   if( src && src->GetLastStatus() == Gdiplus::Ok )
   {
      Gdiplus::Bitmap dst( 48, 48, PixelFormat32bppPARGB );
      Gdiplus::Graphics g( &dst );
      g.SetInterpolationMode( Gdiplus::InterpolationModeHighQualityBicubic );
      g.SetSmoothingMode( Gdiplus::SmoothingModeHighQuality );
      g.Clear( Gdiplus::Color( 0, 0, 0, 0 ) );

      UINT sw = src->GetWidth(), sh = src->GetHeight();
      UINT dw = sw, dh = sh;
      if( dw < 40 || dh < 40 ) {
         /* Upscale tiny source PNG (16/24px) so it fills the larger 48px slot */
         dw = 40; dh = 40;
      }
      if( dw > 40 ) dw = 40;
      if( dh > 40 ) dh = 40;
      int x = ( 48 - (int)dw ) / 2;
      int y = ( 48 - (int)dh ) / 2;
      g.DrawImage( src, Gdiplus::Rect( x, y, dw, dh ),
                   0, 0, sw, sh, Gdiplus::UnitPixel );
      dst.GetHBITMAP( Gdiplus::Color( 0, 0, 0, 0 ), &hbm );
   }
   if( src ) delete src;

   Gdiplus::GdiplusShutdown( gpToken );
   free( wpath );
   return hbm;
}

void TComponentPalette::SetCompIcon( int nCtrlType, const char * szPngPath )
{
   if( nCtrlType <= 0 || nCtrlType >= 256 || !szPngPath ) return;

   HBITMAP hbm = LoadPng32( szPngPath );
   if( !hbm ) return;

   if( FCompIconOverride[nCtrlType] )
      DeleteObject( FCompIconOverride[nCtrlType] );
   FCompIconOverride[nCtrlType] = hbm;

   /* Repaint current tab to reflect new icon */
   if( FTabCtrl )
      ShowTab( FCurrentTab );
}

void TComponentPalette::HandleTabChange()
{
   int sel = (int) SendMessage( FTabCtrl, TCM_GETCURSEL, 0, 0 );
   if( sel >= 0 && sel < FTabCount )
      ShowTab( sel );
}

int TComponentPalette::GetBarHeight()
{
   if( FTabCtrl )
   {
      RECT rc;
      GetWindowRect( FTabCtrl, &rc );
      return rc.bottom - rc.top;
   }
   return 40;
}

const PROPDESC * TComponentPalette::GetPropDescs( int * pnCount )
{
   return TControl::GetPropDescs( pnCount );
}

/* ======================================================================
 * Factory
 * ====================================================================== */

TControl * CreateControlByType( BYTE bType )
{
   switch( bType )
   {
      case CT_FORM:     return new TForm();
      case CT_LABEL:    return new TLabel();
      case CT_EDIT:     return new TEdit();
      case CT_BUTTON:   return new TButton();
      case CT_CHECKBOX: return new TCheckBox();
      case CT_COMBOBOX: return new TComboBox();
      case CT_GROUPBOX: return new TGroupBox();
      case CT_LISTBOX:  return new TListBox();
      case CT_RADIO:    return new TRadioButton();
      case CT_TOOLBAR:  return new TToolBar();
      case CT_BITBTN:   return new TBitBtn();
      case CT_IMAGE:    return new TImage();
      case CT_SHAPE:    return new TShape();
      case CT_BEVEL:    return new TBevel();
      case CT_TREEVIEW: return new TTreeView();
      case CT_LISTVIEW: return new TListView();
      case CT_PROGRESSBAR: return new TProgressBar();
      case CT_RICHEDIT: return new TRichEdit();
      case CT_MEMO:     return new TMemo();
      case CT_PANEL:    return new TPanel();
      case CT_SCROLLBAR: return new TScrollBar();
      case CT_SPEEDBTN: return new TSpeedButton();
      case CT_MASKEDIT2: return new TMaskEdit();
      case CT_STRINGGRID: return new TStringGrid();
      case CT_SCROLLBOX: return new TScrollBox();
      case CT_STATICTEXT: return new TStaticText();
      case CT_LABELEDEDIT: return new TLabeledEdit();
      case CT_TABCONTROL2: return new TTabControl2();
      case CT_TRACKBAR: return new TTrackBar();
      case CT_UPDOWN:   return new TUpDown();
      case CT_DATETIMEPICKER: return new TDateTimePicker();
      case CT_MONTHCALENDAR: return new TMonthCalendar();
      case CT_WEBVIEW: return new TWebView();
      case CT_PAINTBOX: return new TPaintBox();
      case CT_BROWSE:  return new TBrowse();
      case CT_DBGRID:  { TBrowse * p = new TBrowse(); p->FControlType = CT_DBGRID; return p; }
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
   }
   return NULL;
}
