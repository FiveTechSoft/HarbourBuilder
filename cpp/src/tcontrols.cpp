/*
 * tcontrols.cpp - Concrete control implementations
 * TLabel, TEdit, TButton, TCheckBox, TComboBox, TGroupBox
 */

#include "hbide.h"
#include <string.h>

/* ======================================================================
 * TLabel
 * ====================================================================== */

TLabel::TLabel()
{
   lstrcpy( FClassName, "TLabel" );
   FControlType = CT_LABEL;
   FWidth = 80;
   FHeight = 18;
   FTabStop = FALSE;
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
   FHeight = 24;
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
         pForm->Close();
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

      if( FItemIndex >= 0 )
         SendMessage( FHandle, CB_SETCURSEL, FItemIndex, 0 );
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
   FItemIndex = nIndex;
   if( FHandle )
      SendMessage( FHandle, CB_SETCURSEL, nIndex, 0 );
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
         tbb.idCommand = TOOLBAR_BTN_ID_BASE + i;
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
            FillRect( hDC, &rc, (HBRUSH)(COLOR_BTNFACE + 1) );
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
 * TComponentPalette
 * ====================================================================== */

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
   FTabStop = FALSE;
   memset( FTabs, 0, sizeof(FTabs) );
   memset( FBtns, 0, sizeof(FBtns) );
}

TComponentPalette::~TComponentPalette()
{
   if( FOnSelect ) hb_itemRelease( FOnSelect );
}

void TComponentPalette::CreateHandle( HWND hParent )
{
   RECT rcParent;
   int tbWidth;
   TForm * pForm;

   if( !hParent ) return;

   /* Get parent form to find toolbar width */
   pForm = (TForm *) GetWindowLongPtr( hParent, GWLP_USERDATA );
   tbWidth = ( pForm && pForm->FToolBar ) ? pForm->FToolBar->FWidth + 4 : 0;

   GetClientRect( hParent, &rcParent );

   /* Store initial split position */
   FSplitPos = tbWidth;

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
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | TCS_TABS,
      FSplitPos + 6, 0,
      rcParent.right - FSplitPos - 6, rcParent.bottom,
      hParent, NULL, GetModuleHandle(NULL), NULL );

   if( !FTabCtrl ) return;
   FHandle = FTabCtrl;

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
   int i, xPos = 4;
   RECT rcTab;
   HWND hToolTip;

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

   /* Create buttons for this tab */
   {
      PaletteTab * t = &FTabs[nTab];
      int y = rcTab.top + 2;
      int btnH = rcTab.bottom - rcTab.top - 4;
      if( btnH > 24 ) btnH = 24;
      if( btnH < 16 ) btnH = 16;

      xPos = rcTab.left + 4;
      for( i = 0; i < t->nBtnCount; i++ )
      {
         int btnW = lstrlenA( t->btns[i].szText ) * 7 + 16;
         if( btnW < 32 ) btnW = 32;

         FBtns[i] = CreateWindowExA( 0, "BUTTON", t->btns[i].szText,
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_FLAT,
            xPos, y, btnW, btnH,
            FTabCtrl, (HMENU)(LONG_PTR)(200 + i),
            GetModuleHandle(NULL), NULL );

         if( FBtns[i] )
         {
            SendMessage( FBtns[i], WM_SETFONT,
               SendMessage( FTabCtrl, WM_GETFONT, 0, 0 ), TRUE );
         }

         xPos += btnW + 2;
      }
   }
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
      case CT_TOOLBAR:  return new TToolBar();
   }
   return NULL;
}
