// inspector.prg - Live Property Grid Inspector (non-modal)

// Force symbol registration for C functions called via hb_dynsymFindName
EXTERNAL UI_BROWSESETCOLPROP
EXTERNAL UI_BROWSEGETCOLPROPS
EXTERNAL UI_BROWSECOLCOUNT

function InspectorOpen()
   if _InsGetData() == 0
      _InsSetData( INS_Create() )
   else
      INS_BringToFront( _InsGetData() )
   endif
return nil

function InspectorRefresh( hCtrl, hForm )
   local h := _InsGetData()
   local aProps, aEvents
   local i, cName, cHandler, cCode
   if h != 0
      if hCtrl != nil .and. hCtrl != 0
         aProps  := UI_GetAllProps( hCtrl )
         aEvents := UI_GetAllEvents( hCtrl )

         // Resolve handler names from editor code
         cCode := _InsGetEditorCode()
         cName := UI_GetProp( hCtrl, "cName" )
         if Empty( cName )
            if UI_GetProp( hCtrl, "cClassName" ) == "TForm"
               cName := "Form1"
            else
               cName := "ctrl"
            endif
         endif
         if ! Empty( cCode ) .and. ! Empty( aEvents )
            for i := 1 to Len( aEvents )
               if Len( aEvents[i] ) >= 3 .and. ! Empty( aEvents[i][1] )
                  cHandler := cName + SubStr( aEvents[i][1], 3 )
                  if ( "function " + cHandler ) $ cCode
                     aEvents[i][2] := cHandler
                  endif
               endif
            next
         endif

         INS_RefreshWithData( h, hCtrl, aProps )
         INS_SetEvents( h, aEvents )
      else
         INS_RefreshWithData( h, 0, {} )
         INS_SetEvents( h, {} )
      endif
   endif
return nil

// Populate combo with all controls from the design form
// Combo map: maps combo index -> { nType, hCtrl, nColIdx }
//   nType: 0=form, 1=control, 2=browse column
function InspectorPopulateCombo( hForm )
   local h := _InsGetData()
   local i, j, nCount, hChild, cName, cClass, cEntry, nColCount
   local aMap

   if h == 0 .or. hForm == 0
      return nil
   endif

   INS_ComboClear( h )
   INS_SetFormCtrl( h, hForm )
   aMap := {}

   // Add the form itself: "oForm1 AS TForm1"
   cName  := UI_GetProp( hForm, "cName" )
   cClass := UI_GetProp( hForm, "cClassName" )
   if Empty( cName ); cName := "Form1"; endif
   cEntry := "o" + cName + " AS T" + cName
   INS_ComboAdd( h, cEntry )
   AAdd( aMap, { 0, hForm, 0 } )

   // Add all child controls: "oButton1 AS TButton"
   nCount := UI_GetChildCount( hForm )
   for i := 1 to nCount
      hChild := UI_GetChild( hForm, i )
      if hChild != 0
         cName  := UI_GetProp( hChild, "cName" )
         cClass := UI_GetProp( hChild, "cClassName" )
         if Empty( cName ); cName := "ctrl" + LTrim( Str( i ) ); endif
         cEntry := "o" + cName + " AS " + cClass
         INS_ComboAdd( h, cEntry )
         AAdd( aMap, { 1, hChild, 0 } )

         // If it's a Browse, add its columns as sub-entries
         if UI_GetType( hChild ) == 79  // CT_BROWSE
            nColCount := UI_BrowseColCount( hChild )
            for j := 1 to nColCount
               cEntry := "o" + cName + "Col" + LTrim( Str( j ) ) + " AS TBrwColumn"
               INS_ComboAdd( h, cEntry )
               AAdd( aMap, { 2, hChild, j - 1 } )  // 0-based col index
            next
         endif
      endif
   next

   _InsSetComboMap( aMap )

   // Select form (first entry)
   INS_ComboSelect( h, 0 )

return nil

function InspectorGetComboMap()
return _InsGetComboMap()

// Refresh inspector showing column properties
function InspectorRefreshColumn( hBrowse, nCol )
   local h := _InsGetData()
   local aProps
   if h != 0 .and. hBrowse != 0
      aProps := UI_BrowseGetColProps( hBrowse, nCol )
      if ! Empty( aProps )
         INS_RefreshWithData( h, hBrowse, aProps )
         INS_SetBrowseCol( h, nCol )  // Tell inspector we're editing a column
         INS_SetEvents( h, {} )  // Columns have no events
      endif
   endif
return nil

function InspectorClose()
   local h := _InsGetData()
   if h != 0
      INS_Destroy( h )
      _InsSetData( 0 )
   endif
return nil

function Inspector( hCtrl )
   InspectorOpen()
   InspectorRefresh( hCtrl )
return nil

// Simple global storage via C static
#pragma BEGINDUMP
#include <hbapi.h>
#include <hbapiitm.h>
static HB_PTRUINT s_insData = 0;
HB_FUNC( _INSGETDATA ) { hb_retnint( s_insData ); }
HB_FUNC( _INSSETDATA ) { s_insData = (HB_PTRUINT) hb_parnint(1); }

static PHB_ITEM s_comboMap = NULL;

HB_FUNC( _INSSETCOMBOMAP ) {
   if( s_comboMap ) hb_itemRelease( s_comboMap );
   s_comboMap = hb_itemClone( hb_param(1, HB_IT_ARRAY) );
}
HB_FUNC( _INSGETCOMBOMAP ) {
   if( s_comboMap )
      hb_itemReturn( s_comboMap );
   else
      hb_reta( 0 );
}

/* INS_SetEvents( hInsData, aEvents ) - store events from Harbour.
 * On Windows, events are populated internally by InsPopulateEvents(),
 * so this is a no-op stub for cross-platform compatibility. */
HB_FUNC( INS_SETEVENTS ) { /* no-op on Windows */ }

#pragma ENDDUMP

#pragma BEGINDUMP

#include <hbapi.h>
#include <hbapiitm.h>
#include <hbvm.h>
#include <hbstack.h>
#include <windows.h>
#include <commctrl.h>
#include <string.h>
#include <stdio.h>
#include <dwmapi.h>
#ifndef __GNUC__
#pragma comment(lib, "dwmapi.lib")
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#include <stdarg.h>

/* Global dark mode flag — set by W32_SetIDEDarkMode() from Harbour */
static int s_bDarkIDE = 1;

extern int g_bDarkIDE;
HB_FUNC( W32_SETIDEDARKMODE ) { s_bDarkIDE = hb_parl(1) ? 1 : 0; g_bDarkIDE = s_bDarkIDE; }

/* Dark/light color helpers */
#define CLR_BG       ( s_bDarkIDE ? RGB(30,30,30) : GetSysColor(COLOR_WINDOW) )
#define CLR_BG_ALT   ( s_bDarkIDE ? RGB(38,38,38) : RGB(245,245,245) )
#define CLR_TEXT      ( s_bDarkIDE ? RGB(212,212,212) : GetSysColor(COLOR_WINDOWTEXT) )
#define CLR_CAT_BG   ( s_bDarkIDE ? RGB(50,50,50) : GetSysColor(COLOR_BTNFACE) )
#define CLR_CAT_TEXT  ( s_bDarkIDE ? RGB(220,220,220) : GetSysColor(COLOR_BTNTEXT) )
#define CLR_TAB_SEL   ( s_bDarkIDE ? RGB(50,50,50) : GetSysColor(COLOR_WINDOW) )
#define CLR_TAB_BG    ( s_bDarkIDE ? RGB(35,35,35) : GetSysColor(COLOR_BTNFACE) )
#define CLR_TAB_TEXT_SEL ( s_bDarkIDE ? RGB(255,255,255) : GetSysColor(COLOR_BTNTEXT) )
#define CLR_TAB_TEXT_OFF ( s_bDarkIDE ? RGB(160,160,160) : GetSysColor(COLOR_GRAYTEXT) )
#define CLR_EDIT_BG   ( s_bDarkIDE ? RGB(45,45,45) : GetSysColor(COLOR_WINDOW) )
#define CLR_EDIT_TEXT  ( s_bDarkIDE ? RGB(212,212,212) : GetSysColor(COLOR_WINDOWTEXT) )
#define CLR_WND_BG    ( s_bDarkIDE ? RGB(30,30,30) : GetSysColor(COLOR_BTNFACE) )

#define MAX_ROWS 64
#define COL_NAME_W 205

/* Debug log to file */
static void INSLOG( const char * fmt, ... )
{
   FILE * f = fopen( "c:\\ide\\samples\\inspector.log", "a" );
   if( f ) {
      va_list ap;
      va_start( ap, fmt );
      vfprintf( f, fmt, ap );
      fprintf( f, "\n" );
      va_end( ap );
      fclose( f );
   }
}

typedef struct {
   char szName[32];
   char szValue[256];
   char szCategory[32];
   char cType;
   BOOL bIsCat;     /* category header */
   BOOL bCollapsed;
   BOOL bVisible;
} IROW;

typedef struct {
   HWND   hWnd;
   HWND   hCombo;      /* control selector combobox */
   HWND   hTab;        /* Properties / Events tab */
   HWND   hList;       /* property grid listview */
   HWND   hEventList;  /* events grid listview */
   HFONT  hFont;
   HFONT  hBold;
   HBRUSH hBrush;
   HB_PTRUINT hCtrl;   /* currently inspected control */
   HB_PTRUINT hFormCtrl; /* form handle (for enumerating controls) */
   IROW   rows[MAX_ROWS];
   int    nRows;
   int    map[MAX_ROWS]; /* visible row -> rows index */
   int    nVisible;
   HWND   hEdit;        /* in-place edit */
   HWND   hBtn;         /* color picker "..." button */
   int    nEditRow;     /* listview row being edited */
   WNDPROC oldEditProc;
   int    nActiveTab;   /* 0=Properties, 1=Events */
   int    bDebugMode;  /* 1=showing Vars/CallStack/Watch */
   int    nBrowseCol;  /* -1 = not editing column, >= 0 = column index */
   PHB_ITEM pOnComboSel; /* callback when combo selection changes: {|nIndex| ... } */
   PHB_ITEM pOnEventDblClick; /* callback when event double-clicked: {|hCtrl, cEvent| ... } */
   PHB_ITEM pOnPropChanged;   /* callback when property value changes: {|| ... } */
} INSDATA;

/* Forward */
static void InsPopulate( INSDATA * d );
static void InsRebuild( INSDATA * d );
static void InsStartEdit( INSDATA * d, int nLVRow );
static void InsEndEdit( INSDATA * d, BOOL bApply );
static void InsApplyValue( INSDATA * d, int nReal, const char * szVal );
static void InsColorPick( INSDATA * d, int nLVRow );
static void InsFontPick( INSDATA * d, int nLVRow );
static void InsPopulateEvents( INSDATA * d );
static void InsUpdateCombo( INSDATA * d );  /* updates combo from current rows data */
static void InsArrayEdit( INSDATA * d, int nLVRow );

static LRESULT CALLBACK InsBtnProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   INSDATA * d = (INSDATA *) GetPropA( hWnd, "InsData" );
   WNDPROC oldProc = (WNDPROC) GetPropA( hWnd, "OldBtnProc" );
   if( msg == WM_LBUTTONUP && d )
   {
      int nLV = d->nEditRow;
      int nReal = ( nLV >= 0 && nLV < d->nVisible ) ? d->map[nLV] : -1;
      char cType = ( nReal >= 0 ) ? d->rows[nReal].cType : 0;
      LRESULT r = CallWindowProc( oldProc, hWnd, msg, wParam, lParam );
      InsEndEdit( d, FALSE );
      if( cType == 'C' )
         InsColorPick( d, nLV );
      else if( cType == 'F' )
         InsFontPick( d, nLV );
      else if( cType == 'A' )
         InsArrayEdit( d, nLV );
      return r;
   }
   return CallWindowProc( oldProc, hWnd, msg, wParam, lParam );
}

static LRESULT CALLBACK InsEditProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   INSDATA * d = (INSDATA *) GetPropA( hWnd, "InsData" );

   /* Log ALL messages to trace file for debugging */
   if( msg == WM_KEYDOWN || msg == WM_KILLFOCUS || msg == WM_COMMAND || msg == WM_DESTROY )
   {
      FILE * f = fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
      if(f) { fprintf(f,"InsEditProc: msg=0x%04X wParam=%d d=%p oldProc=%p hWnd=%p hEdit=%p\n",
         msg,(int)wParam,d,d?d->oldEditProc:0,hWnd,d?d->hEdit:0); fclose(f); }
   }

   if( !d || !d->oldEditProc ) return DefWindowProc( hWnd, msg, wParam, lParam );

   /* Guard: if our edit was already destroyed, don't process */
   if( d->hEdit != hWnd && !IsWindow(hWnd) ) return 0;

   if( msg == WM_KEYDOWN && wParam == VK_RETURN ) { InsEndEdit( d, TRUE ); return 0; }
   if( msg == WM_KEYDOWN && wParam == VK_ESCAPE ) { InsEndEdit( d, FALSE ); return 0; }

   /* ComboBox: CBN_SELCHANGE means user picked a value -> apply */
   if( msg == WM_COMMAND && HIWORD(wParam) == CBN_SELCHANGE )
   {
      /* Post a delayed end-edit so the combo finishes its selection */
      PostMessage( GetParent(hWnd), WM_USER + 200, 0, 0 );
      return 0;
   }

   if( msg == WM_KILLFOCUS )
   {
      HWND hFocus = (HWND) wParam;
      /* Don't close if focus goes to our own button */
      if( d->hBtn && hFocus == d->hBtn ) return 0;
      /* Don't close if focus goes to a ComboBox dropdown */
      if( hFocus ) {
         char cls[32] = {0};
         GetClassNameA(hFocus, cls, 31);
         if( lstrcmpiA(cls, "ComboLBox") == 0 ) return 0;
      }
      InsEndEdit( d, TRUE );
      return 0;
   }

   return CallWindowProc( d->oldEditProc, hWnd, msg, wParam, lParam );
}

static void InsColorPick( INSDATA * d, int nLVRow )
{
   CHOOSECOLORA cc = {0};
   static COLORREF aCustom[16] = {0};
   int nReal;
   COLORREF clr;
   char szVal[32];

   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];
   clr = (COLORREF) atoi( d->rows[nReal].szValue );

   cc.lStructSize = sizeof(cc);
   cc.hwndOwner = d->hWnd;
   cc.rgbResult = clr;
   cc.lpCustColors = aCustom;
   cc.Flags = CC_FULLOPEN | CC_RGBINIT;

   if( ChooseColorA( &cc ) )
   {
      sprintf( szVal, "%u", (unsigned) cc.rgbResult );
      lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
      InsApplyValue( d, nReal, szVal );
      InsRebuild( d );
   }
}

static void InsFontPick( INSDATA * d, int nLVRow )
{
   CHOOSEFONTA cf = {0};
   LOGFONTA lf = {0};
   int nReal;
   char szVal[256];
   char * comma;

   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];

   /* Parse current "FontName,Size" */
   lstrcpynA( lf.lfFaceName, d->rows[nReal].szValue, LF_FACESIZE );
   comma = strchr( lf.lfFaceName, ',' );
   if( comma ) { *comma = 0; lf.lfHeight = -atoi( comma + 1 ); }
   else        lf.lfHeight = -18;
   lf.lfCharSet = DEFAULT_CHARSET;

   cf.lStructSize = sizeof(cf);
   cf.hwndOwner = d->hWnd;
   cf.lpLogFont = &lf;
   cf.Flags = CF_SCREENFONTS | CF_INITTOLOGFONTSTRUCT;

   if( ChooseFontA( &cf ) )
   {
      sprintf( szVal, "%s,%d", lf.lfFaceName, lf.lfHeight < 0 ? -lf.lfHeight : lf.lfHeight );
      lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
      InsApplyValue( d, nReal, szVal );
      InsRebuild( d );
   }
}

/* Array editor dialog: pipe-separated items in a multiline edit */
static char s_arrayResult[2048];  /* shared buffer for dialog result */

static INT_PTR CALLBACK ArrayDlgProc( HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_INITDIALOG:
      {
         const char * src = (const char *) lParam;
         char buf[2048] = {0};
         int i = 0;
         RECT rc;
         int sw, sh;
         if( src ) {
            while( *src && i < (int)sizeof(buf) - 3 ) {
               if( *src == '|' ) { buf[i++] = '\r'; buf[i++] = '\n'; }
               else buf[i++] = *src;
               src++;
            }
            buf[i] = 0;
         }
         SetDlgItemTextA( hDlg, 101, buf );
         /* Center dialog on screen */
         GetWindowRect( hDlg, &rc );
         sw = GetSystemMetrics( SM_CXSCREEN );
         sh = GetSystemMetrics( SM_CYSCREEN );
         SetWindowPos( hDlg, NULL,
            ( sw - (rc.right - rc.left) ) / 2,
            ( sh - (rc.bottom - rc.top) ) / 2,
            0, 0, SWP_NOSIZE | SWP_NOZORDER );
         if( s_bDarkIDE ) {
            BOOL bDark = TRUE;
            DwmSetWindowAttribute( hDlg, DWMWA_USE_IMMERSIVE_DARK_MODE, &bDark, sizeof(bDark) );
         }
         return TRUE;
      }
      case WM_CTLCOLOREDIT:
      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLORDLG:
         if( s_bDarkIDE ) {
            HDC hdc = (HDC) wParam;
            static HBRUSH s_hBr = NULL;
            if( s_hBr ) DeleteObject( s_hBr );
            s_hBr = CreateSolidBrush( RGB(45,45,48) );
            SetTextColor( hdc, RGB(212,212,212) );
            SetBkColor( hdc, RGB(45,45,48) );
            return (INT_PTR) s_hBr;
         }
         break;
      case WM_COMMAND:
         if( LOWORD(wParam) == IDOK )
         {
            /* Capture multiline text, convert lines to pipe-separated */
            char szBuf[2048] = {0};
            int len, i, o = 0;
            GetDlgItemTextA( hDlg, 101, szBuf, sizeof(szBuf) );
            len = (int)strlen( szBuf );
            s_arrayResult[0] = 0;
            for( i = 0; i < len && o < (int)sizeof(s_arrayResult) - 1; i++ )
            {
               if( szBuf[i] == '\r' ) continue;
               if( szBuf[i] == '\n' ) s_arrayResult[o++] = '|';
               else s_arrayResult[o++] = szBuf[i];
            }
            /* Trim trailing pipes */
            while( o > 0 && s_arrayResult[o-1] == '|' ) o--;
            s_arrayResult[o] = 0;
            EndDialog( hDlg, IDOK );
            return TRUE;
         }
         if( LOWORD(wParam) == IDCANCEL ) { EndDialog( hDlg, IDCANCEL ); return TRUE; }
         break;
      case WM_CLOSE:
         EndDialog( hDlg, IDCANCEL );
         return TRUE;
   }
   return FALSE;
}

static void InsArrayEdit( INSDATA * d, int nLVRow )
{
   int nReal;
   HINSTANCE hInst = GetModuleHandle(NULL);
   INT_PTR nRet;

   /* In-memory dialog template */
   static BYTE tplBuf[512];
   DLGTEMPLATE * pDT = (DLGTEMPLATE *) tplBuf;
   WORD * pw;
   DLGITEMTEMPLATE * pDI;
   int w = 260, h = 200;

   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];

   memset( tplBuf, 0, sizeof(tplBuf) );
   pDT->style = DS_MODALFRAME | WS_POPUP | WS_CAPTION | WS_SYSMENU;
   pDT->cdit = 3;
   pDT->cx = (short)w; pDT->cy = (short)h;

   pw = (WORD *)(pDT + 1);
   *pw++ = 0; /* menu */
   *pw++ = 0; /* class */
   /* title: "Array Editor" as wide chars */
   { const char * t = "Array Editor";
     while( *t ) *pw++ = (WORD)(unsigned char)*t++;
     *pw++ = 0; }

   /* Edit control (id=101) — multiline */
   pw = (WORD *)(((ULONG_PTR)pw + 3) & ~3);  /* align to DWORD */
   pDI = (DLGITEMTEMPLATE *) pw;
   pDI->style = WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN;
   pDI->x = 8; pDI->y = 8; pDI->cx = (short)(w-16); pDI->cy = (short)(h-40);
   pDI->id = 101;
   pw = (WORD *)(pDI + 1);
   *pw++ = 0xFFFF; *pw++ = 0x0081; /* Edit class */
   *pw++ = 0; /* title */
   *pw++ = 0; /* extra */

   /* OK button */
   pw = (WORD *)(((ULONG_PTR)pw + 3) & ~3);
   pDI = (DLGITEMTEMPLATE *) pw;
   pDI->style = WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON;
   pDI->x = (short)(w-120); pDI->y = (short)(h-24); pDI->cx = 50; pDI->cy = 14;
   pDI->id = IDOK;
   pw = (WORD *)(pDI + 1);
   *pw++ = 0xFFFF; *pw++ = 0x0080; /* Button class */
   *pw++ = 'O'; *pw++ = 'K'; *pw++ = 0;
   *pw++ = 0;

   /* Cancel button */
   pw = (WORD *)(((ULONG_PTR)pw + 3) & ~3);
   pDI = (DLGITEMTEMPLATE *) pw;
   pDI->style = WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON;
   pDI->x = (short)(w-60); pDI->y = (short)(h-24); pDI->cx = 50; pDI->cy = 14;
   pDI->id = IDCANCEL;
   pw = (WORD *)(pDI + 1);
   *pw++ = 0xFFFF; *pw++ = 0x0080;
   *pw++ = 'C'; *pw++ = 'a'; *pw++ = 'n'; *pw++ = 'c'; *pw++ = 'e'; *pw++ = 'l'; *pw++ = 0;
   *pw++ = 0;

   s_arrayResult[0] = 0;
   nRet = DialogBoxIndirectParamA( hInst, pDT, d->hWnd, ArrayDlgProc,
      (LPARAM) d->rows[nReal].szValue );

   if( nRet == IDOK )
   {
      lstrcpynA( d->rows[nReal].szValue, s_arrayResult, sizeof(d->rows[0].szValue) );
      InsApplyValue( d, nReal, s_arrayResult );
      InsRebuild( d );

      /* If this was aColumns, repopulate the combo to show TBrwColumn entries */
      if( lstrcmpiA( d->rows[nReal].szName, "aColumns" ) == 0 && d->hFormCtrl )
      {
         PHB_DYNS pDyn = hb_dynsymFindName( "INSPECTORPOPULATECOMBO" );
         if( pDyn && hb_vmRequestReenter() ) {
            hb_vmPushDynSym( pDyn ); hb_vmPushNil();
            hb_vmPushNumInt( d->hFormCtrl );
            hb_vmDo( 1 );
            hb_vmRequestRestore();
         }
      }
   }
}

/* Subclass tab control to paint dark background */
static WNDPROC s_oldTabProc = NULL;
static LRESULT CALLBACK InsTabProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_ERASEBKGND )
   {
      HDC hdc = (HDC) wParam;
      RECT rc;
      HBRUSH hbr = CreateSolidBrush( CLR_WND_BG );
      GetClientRect( hWnd, &rc );
      FillRect( hdc, &rc, hbr );
      DeleteObject( hbr );
      return 1;
   }
   return CallWindowProc( s_oldTabProc, hWnd, msg, wParam, lParam );
}

static LRESULT CALLBACK InsWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   INSDATA * d = (INSDATA *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   switch( msg )
   {
      /* Dark mode: owner-draw tabs */
      case WM_DRAWITEM:
      {
         DRAWITEMSTRUCT * di = (DRAWITEMSTRUCT *) lParam;
         if( di->CtlID == 102 ) /* Tab control */
         {
            char txt[64] = "";
            TCITEMA tci2 = {0};
            HBRUSH hbr;
            int isSel = ( TabCtrl_GetCurSel( di->hwndItem ) == (int)di->itemID );
            tci2.mask = TCIF_TEXT;
            tci2.pszText = txt;
            tci2.cchTextMax = sizeof(txt);
            SendMessageA( di->hwndItem, TCM_GETITEMA, di->itemID, (LPARAM)&tci2 );

            hbr = CreateSolidBrush( isSel ? CLR_TAB_SEL : CLR_TAB_BG );
            FillRect( di->hDC, &di->rcItem, hbr );
            DeleteObject( hbr );

            SetTextColor( di->hDC, isSel ? CLR_TAB_TEXT_SEL : CLR_TAB_TEXT_OFF );
            SetBkMode( di->hDC, TRANSPARENT );
            SelectObject( di->hDC, d ? d->hFont : GetStockObject(DEFAULT_GUI_FONT) );
            DrawTextA( di->hDC, txt, -1, &di->rcItem, DT_CENTER | DT_VCENTER | DT_SINGLELINE );
            return TRUE;
         }
         break;
      }

      /* Dark mode: paint combo, edit, and static controls */
      case WM_CTLCOLOREDIT:
      case WM_CTLCOLORLISTBOX:
      case WM_CTLCOLORSTATIC:
      {
         HDC hdc = (HDC) wParam;
         static HBRUSH s_hDarkBrush = NULL;
         if( s_hDarkBrush ) DeleteObject( s_hDarkBrush );
         s_hDarkBrush = CreateSolidBrush( CLR_EDIT_BG );
         SetTextColor( hdc, CLR_EDIT_TEXT );
         SetBkColor( hdc, CLR_EDIT_BG );
         return (LRESULT) s_hDarkBrush;
      }

      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         int comboH = 28, tabH = 28, topY = comboH + tabH + 8;
         if( d )
         {
            if( d->hCombo ) MoveWindow( d->hCombo, 2, 2, w - 4, 200, TRUE );
            if( d->hTab )   MoveWindow( d->hTab, 2, comboH + 4, w - 4, tabH + 2, TRUE );
            if( d->hList )
            {
               MoveWindow( d->hList, 0, topY, w, h - topY, TRUE );
               ListView_SetColumnWidth( d->hList, 1, w - COL_NAME_W - 20 );
            }
            if( d->hEventList )
            {
               MoveWindow( d->hEventList, 0, topY, w, h - topY, TRUE );
               ListView_SetColumnWidth( d->hEventList, 1, w - COL_NAME_W - 20 );
            }
         }
         return 0;
      }

      case WM_NOTIFY:
      {
         NMHDR * pnm = (NMHDR *) lParam;

         /* Custom draw */
         if( pnm->code == NM_CUSTOMDRAW && pnm->idFrom == 100 )
         {
            NMLVCUSTOMDRAW * pcd = (NMLVCUSTOMDRAW *) lParam;
            switch( pcd->nmcd.dwDrawStage )
            {
               case CDDS_PREPAINT: return CDRF_NOTIFYITEMDRAW;
               case CDDS_ITEMPREPAINT:
               {
                  int nRow = (int) pcd->nmcd.dwItemSpec;
                  int nReal = ( d && nRow < d->nVisible ) ? d->map[nRow] : -1;
                  if( nReal >= 0 && d->rows[nReal].bIsCat )
                  {
                     pcd->clrTextBk = CLR_CAT_BG;
                     pcd->clrText = CLR_CAT_TEXT;
                     SelectObject( pcd->nmcd.hdc, d->hBold );
                     return CDRF_NEWFONT;
                  }
                  pcd->clrTextBk = ( nRow % 2 ) ? CLR_BG_ALT : CLR_BG;
                  pcd->clrText = CLR_TEXT;
                  return CDRF_DODEFAULT;
               }
            }
            return CDRF_DODEFAULT;
         }

         /* Click */
         if( pnm->code == NM_CLICK && pnm->idFrom == 100 )
         {
            NMITEMACTIVATE * pa = (NMITEMACTIVATE *) lParam;
            int nLV = pa->iItem;
            int nReal;
            { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
              if(f){fprintf(f,"NM_CLICK: iItem=%d iSubItem=%d d=%p nVisible=%d\n",
                nLV,pa->iSubItem,d,d?d->nVisible:0);fclose(f);} }
            if( !d || nLV < 0 || nLV >= d->nVisible ) return 0;
            nReal = d->map[nLV];

            /* Category - toggle */
            if( d->rows[nReal].bIsCat )
            {
               int k;
               d->rows[nReal].bCollapsed = !d->rows[nReal].bCollapsed;
               for( k = nReal + 1; k < d->nRows && !d->rows[k].bIsCat; k++ )
                  d->rows[k].bVisible = !d->rows[nReal].bCollapsed;
               InsRebuild( d );
               return 0;
            }

            /* Value column - edit */
            if( pa->iSubItem == 1 )
            {
               if( d->rows[nReal].cType == 'L' )
               {
                  /* Popup menu for logical */
                  HMENU hMenu = CreatePopupMenu();
                  POINT pt;
                  int nCmd;
                  BOOL bVal;
                  RECT rc;
                  ListView_GetSubItemRect( d->hList, nLV, 1, LVIR_LABEL, &rc );
                  pt.x = rc.left; pt.y = rc.bottom;
                  ClientToScreen( d->hList, &pt );
                  AppendMenuA( hMenu, MF_STRING, 1, ".T." );
                  AppendMenuA( hMenu, MF_STRING, 2, ".F." );
                  bVal = ( lstrcmpiA(d->rows[nReal].szValue, ".T.") == 0 );
                  CheckMenuItem( hMenu, bVal ? 1 : 2, MF_CHECKED );
                  nCmd = TrackPopupMenu( hMenu, TPM_RETURNCMD | TPM_NONOTIFY, pt.x, pt.y, 0, d->hList, NULL );
                  DestroyMenu( hMenu );
                  if( nCmd > 0 )
                  {
                     lstrcpyA( d->rows[nReal].szValue, nCmd == 1 ? ".T." : ".F." );
                     InsApplyValue( d, nReal, d->rows[nReal].szValue );
                     InsRebuild( d );
                  }
               }
               else
                  InsStartEdit( d, nLV );
            }
            return 0;
         }

         /* Arrow key navigation: skip category rows */
         if( pnm->code == LVN_ITEMCHANGED && pnm->idFrom == 100 )
         {
            NMLISTVIEW * pnlv = (NMLISTVIEW *) lParam;
            if( d && (pnlv->uNewState & LVIS_SELECTED) && !(pnlv->uOldState & LVIS_SELECTED) )
            {
               int nRow = pnlv->iItem;
               if( nRow >= 0 && nRow < d->nVisible )
               {
                  int nReal = d->map[nRow];
                  if( d->rows[nReal].bIsCat )
                  {
                     int next = nRow + 1;
                     if( next < d->nVisible && !d->rows[d->map[next]].bIsCat ) {
                        ListView_SetItemState( d->hList, next, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED );
                     } else if( nRow > 0 ) {
                        ListView_SetItemState( d->hList, nRow - 1, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED );
                     }
                     ListView_SetItemState( d->hList, nRow, 0, LVIS_SELECTED|LVIS_FOCUSED );
                  }
               }
            }
         }

         /* Custom draw for Events ListView: bold category rows */
         if( pnm->code == NM_CUSTOMDRAW && pnm->idFrom == 103 )
         {
            NMLVCUSTOMDRAW * pcd = (NMLVCUSTOMDRAW *) lParam;
            switch( pcd->nmcd.dwDrawStage )
            {
               case CDDS_PREPAINT: return CDRF_NOTIFYITEMDRAW;
               case CDDS_ITEMPREPAINT:
               {
                  /* Check lParam: 1=category, 0=event */
                  if( pcd->nmcd.lItemlParam == 1 || pcd->nmcd.lItemlParam == 2 )
                  {
                     pcd->clrTextBk = CLR_CAT_BG;
                     pcd->clrText = CLR_CAT_TEXT;
                     SelectObject( pcd->nmcd.hdc, d->hBold );
                     return CDRF_NEWFONT;
                  }
                  pcd->clrTextBk = ( pcd->nmcd.dwItemSpec % 2 )
                     ? CLR_BG_ALT : CLR_BG;
                  pcd->clrText = CLR_TEXT;
                  return CDRF_DODEFAULT;
               }
            }
            return CDRF_DODEFAULT;
         }

         /* Click on Events list: toggle category collapse */
         if( pnm->code == NM_CLICK && pnm->idFrom == 103 )
         {
            NMITEMACTIVATE * pe = (NMITEMACTIVATE *) lParam;
            if( d && pe->iItem >= 0 )
            {
               LVITEMA lviCheck = {0};
               lviCheck.mask = LVIF_PARAM;
               lviCheck.iItem = pe->iItem;
               SendMessageA( d->hEventList, LVM_GETITEMA, 0, (LPARAM) &lviCheck );
               { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
                 if(f){fprintf(f,"EventList NM_CLICK: iItem=%d lParam=%d\n",
                   pe->iItem,(int)lviCheck.lParam);fclose(f);} }

               /* If it's a category row (lParam=1), toggle visibility of following event rows */
               if( lviCheck.lParam == 1 )
               {
                  int j = pe->iItem + 1;
                  int nTotal = (int) SendMessage( d->hEventList, LVM_GETITEMCOUNT, 0, 0 );
                  LVITEMA lviNext = {0};

                  /* Collapse: delete event rows until next category */
                  while( j < nTotal )
                  {
                     lviNext.mask = LVIF_PARAM;
                     lviNext.iItem = j;
                     SendMessageA( d->hEventList, LVM_GETITEMA, 0, (LPARAM) &lviNext );
                     if( lviNext.lParam == 1 || lviNext.lParam == 2 ) break; /* next category */
                     SendMessage( d->hEventList, LVM_DELETEITEM, j, 0 );
                     nTotal--;
                  }
                  /* Mark as collapsed + change - to + in text */
                  { char catText[80] = {0};
                    LVITEMA lviText = {0};
                    lviText.iItem = pe->iItem;
                    lviText.pszText = catText;
                    lviText.cchTextMax = 80;
                    SendMessageA( d->hEventList, LVM_GETITEMTEXTA, pe->iItem, (LPARAM) &lviText );
                    if( catText[1] == '-' ) catText[1] = '+';
                    lviCheck.mask = LVIF_TEXT | LVIF_PARAM;
                    lviCheck.iItem = pe->iItem;
                    lviCheck.pszText = catText;
                    lviCheck.lParam = 2;
                    SendMessageA( d->hEventList, LVM_SETITEMA, 0, (LPARAM) &lviCheck );
                  }
               }
               else if( lviCheck.lParam == 2 )
               {
                  /* Expand: repopulate events */
                  InsPopulateEvents( d );
               }
            }
            return 0;
         }

         /* Double-click on Events list -> fire OnEventDblClick callback */
         if( pnm->code == NM_DBLCLK && pnm->idFrom == 103 )
         {
            NMITEMACTIVATE * pe = (NMITEMACTIVATE *) lParam;
            if( d && pe->iItem >= 0 && d->pOnEventDblClick && HB_IS_BLOCK(d->pOnEventDblClick) )
            {
               char szEvName[64] = {0};
               LVITEMA evi = {0};
               evi.iItem = pe->iItem;
               evi.iSubItem = 0;
               evi.pszText = szEvName;
               evi.cchTextMax = 64;
               SendMessageA( d->hEventList, LVM_GETITEMTEXTA, pe->iItem, (LPARAM) &evi );

               /* Strip leading spaces (events are indented for display) */
               { char * p = szEvName; while( *p == ' ' ) p++;
                 if( p != szEvName ) memmove( szEvName, p, strlen(p) + 1 ); }

               if( szEvName[0] && hb_vmRequestReenter() )
               {
                  PHB_ITEM pCtrl = hb_itemPutNInt( NULL, d->hCtrl );
                  PHB_ITEM pEvt  = hb_itemPutC( NULL, szEvName );
                  hb_vmPushEvalSym();
                  hb_vmPush( d->pOnEventDblClick );
                  hb_vmPush( pCtrl );
                  hb_vmPush( pEvt );
                  hb_vmSend( 2 );
                  hb_itemRelease( pCtrl );
                  hb_itemRelease( pEvt );
                  hb_vmRequestRestore();

                  /* Refresh events to show the new handler name */
                  InsPopulateEvents( d );
               }
            }
            return 0;
         }

         /* Right-click on Events list -> context menu to delete handler */
         if( pnm->code == NM_RCLICK && pnm->idFrom == 103 )
         {
            NMITEMACTIVATE * pe = (NMITEMACTIVATE *) lParam;
            if( d && pe->iItem >= 0 )
            {
               /* Get handler name from column 1 */
               char szHandler[128] = {0};
               LVITEMA evi = {0};
               evi.iItem = pe->iItem;
               evi.iSubItem = 1;
               evi.pszText = szHandler;
               evi.cchTextMax = 128;
               SendMessageA( d->hEventList, LVM_GETITEMTEXTA, pe->iItem, (LPARAM) &evi );

               /* Only show menu if handler exists */
               if( szHandler[0] )
               {
                  HMENU hMenu = CreatePopupMenu();
                  POINT pt;
                  char szMenu[160];
                  int cmd;
                  wsprintfA( szMenu, "Delete %s", szHandler );
                  AppendMenuA( hMenu, MF_STRING, 1, szMenu );
                  GetCursorPos( &pt );

                  cmd = (int) TrackPopupMenu( hMenu, TPM_RETURNCMD | TPM_NONOTIFY,
                     pt.x, pt.y, 0, d->hWnd, NULL );
                  DestroyMenu( hMenu );

                  if( cmd == 1 )
                  {
                     /* Call Harbour function to delete the handler from code */
                     PHB_DYNS pDel = hb_dynsymFindName( "INS_DELETEHANDLER" );
                     if( pDel && hb_vmRequestReenter() )
                     {
                        hb_vmPushDynSym( pDel ); hb_vmPushNil();
                        hb_vmPushString( szHandler, strlen(szHandler) );
                        hb_vmDo( 1 );
                        hb_vmRequestRestore();

                        /* Refresh events to update display */
                        InsPopulateEvents( d );
                     }
                  }
               }
            }
            return 0;
         }

         /* Tab change: Properties / Events */
         if( pnm->code == TCN_SELCHANGE && pnm->idFrom == 102 )
         {
            int sel = (int) SendMessage( d->hTab, TCM_GETCURSEL, 0, 0 );
            d->nActiveTab = sel;
            if( sel == 0 )
            {
               ShowWindow( d->hList, SW_SHOW );
               ShowWindow( d->hEventList, SW_HIDE );
            }
            else if( sel == 1 )
            {
               ShowWindow( d->hList, SW_HIDE );
               ShowWindow( d->hEventList, SW_SHOW );
               /* Only populate events in normal mode, not debug mode */
               if( !d->bDebugMode )
                  InsPopulateEvents( d );
            }
            else
            {
               /* Tab 2 (Watch in debug mode) — both hidden for now */
               ShowWindow( d->hList, SW_HIDE );
               ShowWindow( d->hEventList, SW_HIDE );
            }
            return 0;
         }

         break;
      }

      case WM_COMMAND:
      {
         WORD wId = LOWORD(wParam);
         WORD wNotify = HIWORD(wParam);
         /* ComboBox selection changed - select control in design form */
         if( wId == 101 && wNotify == CBN_SELCHANGE && d && d->hCombo && d->hFormCtrl )
         {
            int sel = (int) SendMessage( d->hCombo, CB_GETCURSEL, 0, 0 );
            if( sel >= 0 )
            {
               /* Use direct C bridge calls instead of hb_vmPushDynSym.
                * Store the selected index and post a custom message to
                * handle it safely outside the combo notification. */
               PostMessage( hWnd, WM_USER + 100, (WPARAM) sel, 0 );
            }
         }
         break;
      }

      case WM_USER + 100:
      {
         /* Deferred combo selection - eval Harbour codeblock */
         if( d && d->pOnComboSel && HB_IS_BLOCK( d->pOnComboSel ) )
         {
            int sel = (int) wParam;
            INSLOG( "ComboSel: sel=%d, firing codeblock", sel );
            hb_vmPushEvalSym();
            hb_vmPush( d->pOnComboSel );
            hb_vmPushInteger( sel );
            hb_vmSend( 1 );
            INSLOG( "ComboSel: codeblock done" );
         }
         return 0;
      }

      case WM_USER + 200:
         /* Deferred combo selection end-edit (from InsEditProc CBN_SELCHANGE) */
         if( d ) InsEndEdit( d, TRUE );
         return 0;

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* Enum definitions for dropdown properties */
typedef struct { const char * szPropName; const char ** aValues; int nCount; } ENUMDEF;

static const char * s_borderStyle[] = { "bsSizeable", "bsSingle", "bsNone", "bsToolWindow" };
static const char * s_position[]    = { "poDesigned", "poCenter", "poCenterScreen" };
static const char * s_windowState[] = { "wsNormal", "wsMinimized", "wsMaximized" };
static const char * s_formStyle[]   = { "fsNormal", "fsStayOnTop" };
static const char * s_cursor[]      = { "crDefault", "crArrow", "crCross", "crIBeam", "crHand",
                                        "crHelp", "crNo", "crWait", "crSizeAll" };
static const char * s_bevelStyle[]  = { "bsLowered", "bsRaised" };
static const char * s_alignment[]   = { "taLeftJustify", "taCenter", "taRightJustify" };
static const char * s_scrollBars[]  = { "ssNone", "ssVertical", "ssHorizontal", "ssBoth" };
static const char * s_borderIcons[] = { "biNone", "biSystemMenu", "biMinimize", "biSystemMenu+biMinimize",
                                        "biMaximize", "biSystemMenu+biMaximize", "biMinimize+biMaximize", "biAll" };
static const char * s_shapeType[]   = { "stRectangle", "stCircle", "stRoundRect", "stEllipse" };
static const char * s_viewStyle[]   = { "vsIcon", "vsList", "vsReport", "vsSmallIcon" };
static const char * s_bevelOuter[]  = { "bvNone", "bvLowered", "bvRaised" };

static ENUMDEF s_enums[] = {
   { "nBorderStyle",  s_borderStyle,  4 },
   { "nBorderIcons",  s_borderIcons,  8 },
   { "nPosition",     s_position,     3 },
   { "nWindowState",  s_windowState,  3 },
   { "nFormStyle",    s_formStyle,    2 },
   { "nCursor",       s_cursor,       9 },
   { "nBevelStyle",   s_bevelStyle,   2 },
   { "nBevelOuter",   s_bevelOuter,   3 },
   { "nAlignment",    s_alignment,    3 },
   { "nScrollBars",   s_scrollBars,   4 },
   { "nShapeType",    s_shapeType,    4 },
   { "nViewStyle",    s_viewStyle,    4 },
   { NULL, NULL, 0 }
};

static ENUMDEF * InsGetEnum( const char * szName )
{
   int i;
   for( i = 0; s_enums[i].szPropName; i++ )
      if( lstrcmpiA( szName, s_enums[i].szPropName ) == 0 )
         return &s_enums[i];
   return NULL;
}

static void InsStartEdit( INSDATA * d, int nLVRow )
{
   RECT rc;
   int nReal, nBtnW;
   ENUMDEF * pEnum;

   { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
     if(f){fprintf(f,"InsStartEdit: nLVRow=%d d=%p\n",nLVRow,d);fclose(f);} }

   if( !d ) return;
   if( d->hEdit ) InsEndEdit( d, FALSE );
   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];
   if( nReal < 0 || nReal >= d->nRows ) return;
   if( d->rows[nReal].bIsCat ) return;  /* don't edit category rows */

   { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
     if(f){fprintf(f,"  nReal=%d name='%s' type='%c'\n",nReal,d->rows[nReal].szName,d->rows[nReal].cType);fclose(f);} }
   d->nEditRow = nLVRow;
   ListView_GetSubItemRect( d->hList, nLVRow, 1, LVIR_LABEL, &rc );

   /* Check if this property should be an enum dropdown */
   pEnum = InsGetEnum( d->rows[nReal].szName );
   if( pEnum )
   {
      int i, nSel;
      d->hEdit = CreateWindowExA( 0, "COMBOBOX", NULL,
         WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_VSCROLL,
         rc.left, rc.top - 2, rc.right - rc.left, 200,
         d->hList, NULL, GetModuleHandle(NULL), NULL );
      SendMessage( d->hEdit, WM_SETFONT, (WPARAM) d->hFont, TRUE );
      for( i = 0; i < pEnum->nCount; i++ )
         SendMessageA( d->hEdit, CB_ADDSTRING, 0, (LPARAM) pEnum->aValues[i] );
      nSel = atoi( d->rows[nReal].szValue );
      if( nSel >= 0 && nSel < pEnum->nCount )
         SendMessage( d->hEdit, CB_SETCURSEL, nSel, 0 );
      SetFocus( d->hEdit );
      SetPropA( d->hEdit, "InsData", (HANDLE) d );
      d->oldEditProc = (WNDPROC) SetWindowLongPtr( d->hEdit, GWLP_WNDPROC, (LONG_PTR) InsEditProc );
      return;
   }

   nBtnW = ( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' || d->rows[nReal].cType == 'A' ) ? 22 : 0;

   d->hEdit = CreateWindowExA( 0, "EDIT", d->rows[nReal].szValue,
      WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, rc.left, rc.top, rc.right-rc.left-nBtnW, rc.bottom-rc.top,
      d->hList, NULL, GetModuleHandle(NULL), NULL );
   SendMessage( d->hEdit, WM_SETFONT, (WPARAM) d->hFont, TRUE );
   SendMessage( d->hEdit, EM_SETSEL, 0, -1 );
   SetFocus( d->hEdit );
   SetPropA( d->hEdit, "InsData", (HANDLE) d );
   d->oldEditProc = (WNDPROC) SetWindowLongPtr( d->hEdit, GWLP_WNDPROC, (LONG_PTR) InsEditProc );

   /* Color/Font property: add "..." button to the right */
   if( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' || d->rows[nReal].cType == 'A' )
   {
      d->hBtn = CreateWindowExA( 0, "BUTTON", "...",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         rc.right - nBtnW, rc.top, nBtnW, rc.bottom - rc.top,
         d->hList, (HMENU) 200, GetModuleHandle(NULL), NULL );
      SendMessage( d->hBtn, WM_SETFONT, (WPARAM) d->hFont, TRUE );
      SetPropA( d->hBtn, "InsData", (HANDLE) d );
      SetPropA( d->hBtn, "OldBtnProc", (HANDLE) GetWindowLongPtr( d->hBtn, GWLP_WNDPROC ) );
      SetWindowLongPtr( d->hBtn, GWLP_WNDPROC, (LONG_PTR) InsBtnProc );
   }
}

static void InsLog( const char * msg )
{
   FILE * f = fopen( "c:\\HarbourBuilder\\inspector_trace.log", "a" );
   if( f ) { fprintf( f, "%s\n", msg ); fclose( f ); }
}

static void InsEndEdit( INSDATA * d, BOOL bApply )
{
   char szVal[256];
   int nReal;
   InsLog( "InsEndEdit called" );
   if( !d || !d->hEdit || d->nEditRow < 0 || d->nEditRow >= d->nVisible ) { InsLog("  -> guard exit"); return; }
   nReal = d->map[d->nEditRow];
   if( nReal < 0 || nReal >= d->nRows ) {
      if( d->hBtn ) { DestroyWindow(d->hBtn); d->hBtn=NULL; }
      DestroyWindow(d->hEdit); d->hEdit=NULL; d->nEditRow=-1;
      return;
   }
   if( bApply )
   {
      ENUMDEF * pEnum = InsGetEnum( d->rows[nReal].szName );
      if( pEnum )
      {
         /* Enum dropdown: get selected index as the numeric value */
         int nSel = (int) SendMessage( d->hEdit, CB_GETCURSEL, 0, 0 );
         if( nSel >= 0 ) {
            sprintf( szVal, "%d", nSel );
            lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
            InsApplyValue( d, nReal, szVal );
         }
      }
      else
      {
         GetWindowTextA( d->hEdit, szVal, sizeof(szVal) );
         lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
         InsApplyValue( d, nReal, szVal );
      }
      /* Note: InsRebuild is NOT called here because pOnPropChanged
         already triggers SyncDesignerToCode -> InspectorRefresh
         which rebuilds the property list. Calling InsRebuild again
         would operate on stale/invalid data and crash. */
      InsLog( "  -> skipping InsRebuild (pOnPropChanged handles refresh)" );
   }
   InsLog( "  -> destroying edit control" );
   if( d->hBtn ) { HWND hb = d->hBtn; d->hBtn = NULL; DestroyWindow( hb ); }
   if( d->hEdit ) { HWND he = d->hEdit; d->hEdit = NULL; d->nEditRow = -1; DestroyWindow( he ); }
   else d->nEditRow = -1;
   InsLog( "InsEndEdit done" );
}

static void InsApplyValue( INSDATA * d, int nReal, const char * szVal )
{
   PHB_DYNS pDyn;
   char logBuf[256];
   sprintf( logBuf, "InsApplyValue: nReal=%d name='%s' type='%c' val='%s' hCtrl=%p",
      nReal, d->rows[nReal].szName, d->rows[nReal].cType, szVal, (void*)(size_t)d->hCtrl );
   InsLog( logBuf );

   /* If editing a browse column, use UI_BrowseSetColProp instead of UI_SetProp */
   if( d->nBrowseCol >= 0 )
   {
      pDyn = hb_dynsymFindName( "UI_BROWSESETCOLPROP" );
      if( !pDyn ) { InsLog("  -> UI_BROWSESETCOLPROP not found!"); return; }
      InsLog( "  -> calling UI_BrowseSetColProp" );
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushInteger( d->nBrowseCol );
      hb_vmPushString( d->rows[nReal].szName, lstrlenA(d->rows[nReal].szName) );
      if( d->rows[nReal].cType == 'N' )
         hb_vmPushInteger( atoi(szVal) );
      else
         hb_vmPushString( szVal, lstrlenA(szVal) );
      hb_vmDo( 4 );
      InsLog( "  -> UI_BrowseSetColProp returned OK" );
   }
   else
   {
      pDyn = hb_dynsymFindName( "UI_SETPROP" );
      if( !pDyn ) { InsLog("  -> UI_SETPROP not found!"); return; }
      InsLog( "  -> calling hb_vmDo(3)" );
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, lstrlenA(d->rows[nReal].szName) );
      if( d->rows[nReal].cType == 'S' )
         hb_vmPushString( szVal, lstrlenA(szVal) );
      else if( d->rows[nReal].cType == 'N' )
         hb_vmPushInteger( atoi(szVal) );
      else if( d->rows[nReal].cType == 'L' )
         hb_vmPushLogical( lstrcmpiA(szVal,".T.")==0 );
      else if( d->rows[nReal].cType == 'C' )
         hb_vmPushNumInt( (HB_MAXINT) strtoul(szVal, NULL, 10) );
      else if( d->rows[nReal].cType == 'F' )
         hb_vmPushString( szVal, lstrlenA(szVal) );
      else if( d->rows[nReal].cType == 'A' )
         hb_vmPushString( szVal, lstrlenA(szVal) );
      else
         hb_vmPushNil();
      hb_vmDo( 3 );
      InsLog( "  -> hb_vmDo(3) returned OK" );
   }

   /* Notify IDE that a property changed */
   if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) )
   {
      InsLog( "  -> firing pOnPropChanged (with reenter)" );
      if( hb_vmRequestReenter() )
      {
         hb_vmPushEvalSym();
         hb_vmPush( d->pOnPropChanged );
         hb_vmSend( 0 );
         hb_vmRequestRestore();
      }
      InsLog( "  -> pOnPropChanged returned OK" );
   }
   InsLog( "InsApplyValue done" );
}

static void InsPopulate( INSDATA * d )
{
   PHB_DYNS pDyn;
   PHB_ITEM pResult;
   HB_SIZE nLen, i;
   char szCats[16][32];
   int nCats = 0, j;
   BOOL bNew;

   d->nRows = 0;

   if( d->hCtrl == 0 ) return;

   /* Call UI_GetAllProps */
   pDyn = hb_dynsymFindName( "UI_GETALLPROPS" );
   if( !pDyn ) return;
   hb_vmPushDynSym( pDyn ); hb_vmPushNil();
   hb_vmPushNumInt( d->hCtrl );
   hb_vmDo( 1 );
   pResult = hb_stackReturnItem();
   if( !pResult || !HB_IS_ARRAY(pResult) ) return;
   nLen = hb_arrayLen( pResult );

   /* Collect categories */
   for( i = 1; i <= nLen && nCats < 16; i++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pResult, i );
      const char * c = hb_arrayGetCPtr( pRow, 3 );
      bNew = TRUE;
      for( j = 0; j < nCats; j++ )
         if( lstrcmpiA(szCats[j], c) == 0 ) { bNew = FALSE; break; }
      if( bNew ) lstrcpynA( szCats[nCats++], c, 32 );
   }

   /* Build rows */
   for( j = 0; j < nCats && d->nRows < MAX_ROWS - 1; j++ )
   {
      /* Category header */
      lstrcpynA( d->rows[d->nRows].szName, szCats[j], 32 );
      d->rows[d->nRows].szValue[0] = 0;
      lstrcpynA( d->rows[d->nRows].szCategory, szCats[j], 32 );
      d->rows[d->nRows].cType = 0;
      d->rows[d->nRows].bIsCat = TRUE;
      d->rows[d->nRows].bCollapsed = FALSE;
      d->rows[d->nRows].bVisible = TRUE;
      d->nRows++;

      for( i = 1; i <= nLen && d->nRows < MAX_ROWS; i++ )
      {
         PHB_ITEM pRow = hb_arrayGetItemPtr( pResult, i );
         if( lstrcmpiA( hb_arrayGetCPtr(pRow,3), szCats[j] ) != 0 ) continue;

         lstrcpynA( d->rows[d->nRows].szName, hb_arrayGetCPtr(pRow,1), 32 );
         lstrcpynA( d->rows[d->nRows].szCategory, hb_arrayGetCPtr(pRow,3), 32 );
         d->rows[d->nRows].cType = hb_arrayGetCPtr(pRow,4)[0];
         d->rows[d->nRows].bIsCat = FALSE;
         d->rows[d->nRows].bCollapsed = FALSE;
         d->rows[d->nRows].bVisible = TRUE;

         if( d->rows[d->nRows].cType == 'S' )
            lstrcpynA( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 256 );
         else if( d->rows[d->nRows].cType == 'N' )
            sprintf( d->rows[d->nRows].szValue, "%d", hb_arrayGetNI(pRow,2) );
         else if( d->rows[d->nRows].cType == 'L' )
            lstrcpyA( d->rows[d->nRows].szValue, hb_arrayGetL(pRow,2) ? ".T." : ".F." );
         else if( d->rows[d->nRows].cType == 'C' )
            sprintf( d->rows[d->nRows].szValue, "%u", (unsigned) hb_arrayGetNInt(pRow,2) );
         else if( d->rows[d->nRows].cType == 'F' )
            lstrcpynA( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 256 );
         else if( d->rows[d->nRows].cType == 'A' )
            lstrcpynA( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 256 );

         d->nRows++;
      }
   }
}

static void InsRebuild( INSDATA * d )
{
   int i, nOldVisible;
   LVITEMA lvi;
   char buf[300];
   BOOL bFullRebuild;

   /* Check if structure changed or just values */
   nOldVisible = d->nVisible;
   d->nVisible = 0;
   for( i = 0; i < d->nRows; i++ )
      if( d->rows[i].bVisible || d->rows[i].bIsCat )
         d->nVisible++;

   bFullRebuild = ( d->nVisible != nOldVisible );

   if( bFullRebuild )
   {
      /* Structure changed - full rebuild */
      SendMessage( d->hList, WM_SETREDRAW, FALSE, 0 );
      ListView_DeleteAllItems( d->hList );
      d->nVisible = 0;

      for( i = 0; i < d->nRows; i++ )
      {
         if( !d->rows[i].bVisible && !d->rows[i].bIsCat ) continue;

         d->map[d->nVisible] = i;
         memset( &lvi, 0, sizeof(lvi) );
         lvi.mask = LVIF_TEXT;
         lvi.iItem = d->nVisible;

         if( d->rows[i].bIsCat )
            sprintf( buf, " %c  %s", d->rows[i].bCollapsed ? '+' : '-', d->rows[i].szName );
         else
            sprintf( buf, "      %s", d->rows[i].szName );

         lvi.pszText = buf;
         SendMessageA( d->hList, LVM_INSERTITEMA, 0, (LPARAM) &lvi );

         if( !d->rows[i].bIsCat )
         {
            lvi.iSubItem = 1;
            if( d->rows[i].cType == 'A' ) {
               /* Show "(N items)" for array properties */
               int cnt = 0;
               if( d->rows[i].szValue[0] ) {
                  const char * pp; cnt = 1;
                  for( pp = d->rows[i].szValue; *pp; pp++ )
                     if( *pp == '|' ) cnt++;
               }
               sprintf( buf, "(%d items)", cnt );
               lvi.pszText = buf;
            } else {
               lvi.pszText = d->rows[i].szValue;
            }
            SendMessageA( d->hList, LVM_SETITEMA, 0, (LPARAM) &lvi );
         }
         d->nVisible++;
      }

      SendMessage( d->hList, WM_SETREDRAW, TRUE, 0 );
      InvalidateRect( d->hList, NULL, TRUE );
   }
   else
   {
      /* Same structure - only update cells whose value actually changed */
      int nVis = 0;
      char szOld[256];
      for( i = 0; i < d->nRows; i++ )
      {
         if( !d->rows[i].bVisible && !d->rows[i].bIsCat ) continue;
         d->map[nVis] = i;

         if( !d->rows[i].bIsCat )
         {
            char szDisp[256];
            char * pDisp = d->rows[i].szValue;
            if( d->rows[i].cType == 'A' ) {
               int cnt = 0;
               if( d->rows[i].szValue[0] ) {
                  const char * pp; cnt = 1;
                  for( pp = d->rows[i].szValue; *pp; pp++ )
                     if( *pp == '|' ) cnt++;
               }
               sprintf( szDisp, "(%d items)", cnt );
               pDisp = szDisp;
            }
            ListView_GetItemText( d->hList, nVis, 1, szOld, sizeof(szOld) );
            if( lstrcmpA( szOld, pDisp ) != 0 )
               ListView_SetItemText( d->hList, nVis, 1, pDisp );
         }

         nVis++;
      }
   }
}

/* INS_Create() --> hInsWnd */
HB_FUNC( INS_CREATE )
{
   INSDATA * d;
   WNDCLASSA wc = {0};
   LVCOLUMNA lvc = {0};
   TCITEMA tci = {0};
   static BOOL bReg = FALSE;
   int comboH = 28, tabH = 28, topY;

   d = (INSDATA *) malloc( sizeof(INSDATA) );
   memset( d, 0, sizeof(INSDATA) );
   d->nEditRow = -1;
   d->hBtn = NULL;
   d->nActiveTab = 0;
   d->hFormCtrl = 0;
   d->nBrowseCol = -1;
   d->pOnComboSel = NULL;
   d->pOnEventDblClick = NULL;
   d->pOnPropChanged = NULL;

   { LOGFONTA lf = {0}; lf.lfHeight = -18; lf.lfCharSet = DEFAULT_CHARSET;
     lstrcpyA(lf.lfFaceName, "Segoe UI");
     d->hFont = CreateFontIndirectA(&lf);
     lf.lfWeight = FW_BOLD; d->hBold = CreateFontIndirectA(&lf); }

   d->hBrush = CreateSolidBrush( CLR_WND_BG );

   if( !bReg ) {
      wc.lpfnWndProc = InsWndProc; wc.hInstance = GetModuleHandle(NULL);
      wc.hCursor = LoadCursor(NULL,IDC_ARROW); wc.hbrBackground = d->hBrush;
      wc.lpszClassName = "HbIdeInspector"; RegisterClassA(&wc); bReg = TRUE;
   }

   { INITCOMMONCONTROLSEX ic = { sizeof(ic), ICC_LISTVIEW_CLASSES | ICC_TAB_CLASSES };
     InitCommonControlsEx(&ic); }

   d->hWnd = CreateWindowExA( WS_EX_TOOLWINDOW, "HbIdeInspector", "Object Inspector",
      WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME,
      0, 130, 250, 500,
      NULL, NULL, GetModuleHandle(NULL), NULL );

   SetWindowLongPtr( d->hWnd, GWLP_USERDATA, (LONG_PTR) d );

   /* ComboBox: control selector at top */
   d->hCombo = CreateWindowExA( 0, "COMBOBOX", "",
      WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_VSCROLL,
      2, 2, 200, 200,
      d->hWnd, (HMENU)101, GetModuleHandle(NULL), NULL );
   SendMessage( d->hCombo, WM_SETFONT, (WPARAM) d->hFont, TRUE );

   /* TabControl: Properties | Events */
   d->hTab = CreateWindowExA( 0, WC_TABCONTROLA, "",
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | TCS_OWNERDRAWFIXED,
      2, comboH + 4, 200, tabH + 2,
      d->hWnd, (HMENU)102, GetModuleHandle(NULL), NULL );
   SendMessage( d->hTab, WM_SETFONT, (WPARAM) d->hFont, TRUE );
   s_oldTabProc = (WNDPROC) SetWindowLongPtr( d->hTab, GWLP_WNDPROC, (LONG_PTR) InsTabProc );

   tci.mask = TCIF_TEXT;
   tci.pszText = "Properties"; SendMessageA( d->hTab, TCM_INSERTITEMA, 0, (LPARAM) &tci );
   tci.pszText = "Events";     SendMessageA( d->hTab, TCM_INSERTITEMA, 1, (LPARAM) &tci );

   topY = comboH + tabH + 8;

   /* Properties ListView (visible by default) */
   d->hList = CreateWindowExA( 0, WC_LISTVIEWA, "",
      WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS | LVS_NOCOLUMNHEADER,
      0, topY, 215, 440 - topY, d->hWnd, (HMENU)100, GetModuleHandle(NULL), NULL );

   SendMessage( d->hList, LVM_SETEXTENDEDLISTVIEWSTYLE, 0,
      LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES | LVS_EX_DOUBLEBUFFER );
   SendMessage( d->hList, WM_SETFONT, (WPARAM) d->hFont, TRUE );

   lvc.mask = LVCF_TEXT | LVCF_WIDTH;
   lvc.cx = COL_NAME_W; lvc.pszText = "Property";
   SendMessageA( d->hList, LVM_INSERTCOLUMNA, 0, (LPARAM) &lvc );
   lvc.cx = 130; lvc.pszText = "Value";
   SendMessageA( d->hList, LVM_INSERTCOLUMNA, 1, (LPARAM) &lvc );

   /* Events ListView (hidden by default) */
   d->hEventList = CreateWindowExA( 0, WC_LISTVIEWA, "",
      WS_CHILD | LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS | LVS_NOCOLUMNHEADER,
      0, topY, 245, 440 - topY, d->hWnd, (HMENU)103, GetModuleHandle(NULL), NULL );

   SendMessage( d->hEventList, LVM_SETEXTENDEDLISTVIEWSTYLE, 0,
      LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES | LVS_EX_DOUBLEBUFFER );
   SendMessage( d->hEventList, WM_SETFONT, (WPARAM) d->hFont, TRUE );

   lvc.cx = COL_NAME_W; lvc.pszText = "Event";
   SendMessageA( d->hEventList, LVM_INSERTCOLUMNA, 0, (LPARAM) &lvc );
   lvc.cx = 130; lvc.pszText = "Handler";
   SendMessageA( d->hEventList, LVM_INSERTCOLUMNA, 1, (LPARAM) &lvc );

   /* Dark mode colors for ListViews */
   ListView_SetBkColor( d->hList, CLR_BG );
   ListView_SetTextBkColor( d->hList, CLR_BG );
   ListView_SetTextColor( d->hList, CLR_TEXT );
   ListView_SetBkColor( d->hEventList, CLR_BG );
   ListView_SetTextBkColor( d->hEventList, CLR_BG );
   ListView_SetTextColor( d->hEventList, CLR_TEXT );

   /* Dark title bar (conditional) */
   if( s_bDarkIDE )
   { BOOL useDark = TRUE; DwmSetWindowAttribute( d->hWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &useDark, sizeof(useDark) ); }

   ShowWindow( d->hWnd, SW_SHOW );

   hb_retnint( (HB_PTRUINT) d );
}

/* INS_Refresh( hInsData, hCtrl ) */
/* INS_RefreshWithData( hInsData, hCtrl, aProps ) - receives props from Harbour */
HB_FUNC( INS_REFRESHWITHDATA )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pArray = hb_param(3, HB_IT_ARRAY);
   HB_SIZE nLen, i;
   char szCats[16][32];
   int nCats = 0, j;
   BOOL bNew;
   char szTitle[128];

   if( !d ) return;

   d->hCtrl = (HB_PTRUINT) hb_parnint(2);
   d->nBrowseCol = -1;  /* reset; InspectorRefreshColumn sets it after */
   d->nRows = 0;

   if( d->hCtrl == 0 || !pArray || hb_arrayLen(pArray) == 0 )
   {
      ListView_DeleteAllItems( d->hList );
      d->nVisible = 0;
      SetWindowTextA( d->hWnd, "Inspector" );
      return;
   }

   nLen = hb_arrayLen( pArray );

   /* Title always "Object Inspector" (control shown in combo) */
   (void) szTitle;
   SetWindowTextA( d->hWnd, "Object Inspector" );

   /* Collect categories */
   for( i = 1; i <= nLen && nCats < 16; i++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
      const char * c = hb_arrayGetCPtr( pRow, 3 );
      bNew = TRUE;
      for( j = 0; j < nCats; j++ )
         if( lstrcmpiA(szCats[j], c) == 0 ) { bNew = FALSE; break; }
      if( bNew ) lstrcpynA( szCats[nCats++], c, 32 );
   }

   /* Build rows */
   for( j = 0; j < nCats && d->nRows < MAX_ROWS - 1; j++ )
   {
      lstrcpynA( d->rows[d->nRows].szName, szCats[j], 32 );
      d->rows[d->nRows].szValue[0] = 0;
      lstrcpynA( d->rows[d->nRows].szCategory, szCats[j], 32 );
      d->rows[d->nRows].cType = 0;
      d->rows[d->nRows].bIsCat = TRUE;
      d->rows[d->nRows].bCollapsed = FALSE;
      d->rows[d->nRows].bVisible = TRUE;
      d->nRows++;

      for( i = 1; i <= nLen && d->nRows < MAX_ROWS; i++ )
      {
         PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
         if( lstrcmpiA( hb_arrayGetCPtr(pRow,3), szCats[j] ) != 0 ) continue;

         lstrcpynA( d->rows[d->nRows].szName, hb_arrayGetCPtr(pRow,1), 32 );
         lstrcpynA( d->rows[d->nRows].szCategory, hb_arrayGetCPtr(pRow,3), 32 );
         d->rows[d->nRows].cType = hb_arrayGetCPtr(pRow,4)[0];
         d->rows[d->nRows].bIsCat = FALSE;
         d->rows[d->nRows].bCollapsed = FALSE;
         d->rows[d->nRows].bVisible = TRUE;

         if( d->rows[d->nRows].cType == 'S' )
            lstrcpynA( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 256 );
         else if( d->rows[d->nRows].cType == 'N' )
            sprintf( d->rows[d->nRows].szValue, "%d", hb_arrayGetNI(pRow,2) );
         else if( d->rows[d->nRows].cType == 'L' )
            lstrcpyA( d->rows[d->nRows].szValue, hb_arrayGetL(pRow,2) ? ".T." : ".F." );
         else if( d->rows[d->nRows].cType == 'C' )
            sprintf( d->rows[d->nRows].szValue, "%u", (unsigned) hb_arrayGetNInt(pRow,2) );
         else if( d->rows[d->nRows].cType == 'F' )
            lstrcpynA( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 256 );
         else if( d->rows[d->nRows].cType == 'A' )
            lstrcpynA( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 256 );

         d->nRows++;
      }
   }

   InsRebuild( d );
   InsUpdateCombo( d );

   /* If events tab is active, refresh events too */
   if( d->nActiveTab == 1 )
      InsPopulateEvents( d );
}

/* INS_SetFormCtrl( hInsData, hForm ) - set form handle for combo enumeration */
HB_FUNC( INS_SETFORMCTRL )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d ) d->hFormCtrl = (HB_PTRUINT) hb_parnint(2);
}

/* INS_SetOnComboSel( hInsData, bBlock ) - set callback for combo selection change */
HB_FUNC( INS_SETONCOMBOSEL )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnComboSel ) hb_itemRelease( d->pOnComboSel );
      d->pOnComboSel = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* INS_SetOnEventDblClick( hInsData, bBlock ) */
HB_FUNC( INS_SETONEVENTDBLCLICK )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnEventDblClick ) hb_itemRelease( d->pOnEventDblClick );
      d->pOnEventDblClick = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* INS_SetOnPropChanged( hInsData, bBlock ) */
HB_FUNC( INS_SETONPROPCHANGED )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnPropChanged ) hb_itemRelease( d->pOnPropChanged );
      d->pOnPropChanged = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* INS_BringToFront( hInsData ) */
/* Populate the Events tab with available events for the current control */
/* Add a category header row (bold, gray background) to Events ListView */
static void InsAddEventCat( INSDATA * d, int nRow, const char * szCat )
{
   LVITEMA lvi = {0};
   char buf[80];
   sprintf( buf, " -  %s", szCat );  /* same format as properties: " -  Category" */
   lvi.mask = LVIF_TEXT | LVIF_PARAM;
   lvi.iItem = nRow;
   lvi.iSubItem = 0;
   lvi.pszText = buf;
   lvi.lParam = 1;  /* 1 = expanded category */
   SendMessageA( d->hEventList, LVM_INSERTITEMA, 0, (LPARAM) &lvi );
}

/* Add one event row to the Events ListView (indented under category) */
/* szCtrlName: control name for building handler (e.g. "Form1")
 * szEvent: event name (e.g. "OnClick") — handler = szCtrlName + szEvent[2..]
 * pCode: source code text to search for existing handler (NULL = don't check) */
static const char * s_pEventCode = NULL;

static void InsAddEvent2( INSDATA * d, int nRow, const char * szEvent, const char * szCtrlName )
{
   LVITEMA lvi;
   char buf[128], handler[128], search[160];
   int nInserted;
   BOOL bExists = FALSE;

   /* Build handler name: CtrlName + event suffix (skip "On") */
   if( szCtrlName && szCtrlName[0] && lstrlenA(szEvent) > 2 )
   {
      wsprintfA( handler, "%s%s", szCtrlName, szEvent + 2 );
      /* Check if handler function exists in source code */
      if( s_pEventCode )
      {
         wsprintfA( search, "function %s", handler );
         /* Case-insensitive search */
         { const char * p = s_pEventCode;
           int slen = lstrlenA(search);
           while( *p ) {
              if( CompareStringA(LOCALE_INVARIANT, NORM_IGNORECASE, p, slen, search, slen) == CSTR_EQUAL )
                 { bExists = TRUE; break; }
              p++;
           }
         }
      }
   }
   else
      handler[0] = 0;

   /* Column 0: event name (indented) */
   ZeroMemory( &lvi, sizeof(lvi) );
   wsprintfA( buf, "      %s", szEvent );
   lvi.mask = LVIF_TEXT | LVIF_PARAM;
   lvi.iItem = nRow;
   lvi.iSubItem = 0;
   lvi.pszText = buf;
   lvi.lParam = 0;
   nInserted = (int) SendMessageA( d->hEventList, LVM_INSERTITEMA, 0, (LPARAM) &lvi );

   /* Column 1: handler name — only show if function exists in code */
   if( nInserted >= 0 )
   {
      ZeroMemory( &lvi, sizeof(lvi) );
      lvi.mask = LVIF_TEXT;
      lvi.iItem = nInserted;
      lvi.iSubItem = 1;
      lvi.pszText = bExists ? handler : (char *)"";
      SendMessageA( d->hEventList, LVM_SETITEMA, 0, (LPARAM) &lvi );
   }
}

static void InsPopulateEvents( INSDATA * d )
{
   int nType, n = 0;
   PHB_DYNS pDyn, pGetProp;
   char szCtrlName[64] = "ctrl";
   char * pCode = NULL;
   HB_SIZE nCodeLen = 0;

   InsLog( "InsPopulateEvents called" );
   if( !d || !d->hEventList ) { InsLog("  -> guard exit (no d or no hEventList)"); return; }
   SendMessage( d->hEventList, LVM_DELETEALLITEMS, 0, 0 );
   if( d->hCtrl == 0 ) return;

   /* Get control name via UI_GetProp( hCtrl, "cName" ) */
   pGetProp = hb_dynsymFindName( "UI_GETPROP" );
   if( pGetProp && hb_vmRequestReenter() )
   {
      hb_vmPushDynSym( pGetProp ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( "cName", 5 );
      hb_vmDo( 2 );
      {
         const char * s = hb_itemGetCPtr( hb_stackReturnItem() );
         if( s && s[0] ) lstrcpynA( szCtrlName, s, 64 );
      }
      hb_vmRequestRestore();
   }
   /* For forms, if name is empty use "Form1" */
   if( szCtrlName[0] == 0 || lstrcmpA(szCtrlName, "ctrl") == 0 )
      lstrcpynA( szCtrlName, "Form1", 64 );

   /* Read all code from editor to check which handlers exist */
   {
      PHB_DYNS pGetCode = hb_dynsymFindName( "INS_GETALLCODE" );
      if( pGetCode && hb_vmRequestReenter() )
      {
         hb_vmPushDynSym( pGetCode ); hb_vmPushNil();
         hb_vmDo( 0 );
         {
            const char * s = hb_itemGetCPtr( hb_stackReturnItem() );
            nCodeLen = hb_itemGetCLen( hb_stackReturnItem() );
            if( s && nCodeLen > 0 )
            {
               pCode = (char *) HeapAlloc( GetProcessHeap(), 0, nCodeLen + 1 );
               CopyMemory( pCode, s, nCodeLen );
               pCode[nCodeLen] = 0;
            }
         }
         hb_vmRequestRestore();
      }
   }


   /* Set code for handler existence checking */
   s_pEventCode = pCode;

   /* Get control type via UI_GetType - use reenter for VM safety */
   pDyn = hb_dynsymFindName( "UI_GETTYPE" );
   if( !pDyn ) {
      InsLog("  -> UI_GETTYPE not found, using fallback");
      InsAddEvent2( d, 0, "OnClick", NULL );
      InsAddEvent2( d, 1, "OnChange", NULL );
      InsAddEvent2( d, 2, "OnInit", NULL );
      InsAddEvent2( d, 3, "OnClose", NULL );
      return;
   }

   if( hb_vmRequestReenter() )
   {
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmDo( 1 );
      nType = hb_itemGetNI( hb_stackReturnItem() );
      hb_vmRequestRestore();
   }
   { char tb[64]; sprintf(tb,"  -> nType = %d",nType); InsLog(tb); }

   /* Shorthand: add event row with auto-generated handler name */
   #define AE(ev) InsAddEvent2(d, n++, ev, szCtrlName)

   /* Show events based on control type */
   switch( nType )
   {
      case 0: /* CT_FORM */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         InsAddEventCat(d, n++, "Lifecycle");
         AE("OnCreate");
         AE("OnDestroy");
         AE("OnShow");
         AE("OnHide");
         AE("OnClose");
         AE("OnCloseQuery");
         AE("OnActivate");
         AE("OnDeactivate");
         InsAddEventCat(d, n++, "Layout");
         AE("OnResize");
         AE("OnPaint");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         AE("OnKeyUp");
         AE("OnKeyPress");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         AE("OnMouseUp");
         AE("OnMouseMove");
         AE("OnMouseWheel");
         break;
      case 3: /* CT_BUTTON */
      case 12: /* CT_BITBTN */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         InsAddEventCat(d, n++, "Focus");
         AE("OnEnter");
         AE("OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         break;
      case 2: /* CT_EDIT */
      case 24: /* CT_MEMO */
      case 23: /* CT_RICHEDIT */
      case 28: /* CT_MASKEDIT */
      case 32: /* CT_LABELEDEDIT */
         InsAddEventCat(d, n++, "Action");
         AE("OnChange");
         AE("OnClick");
         InsAddEventCat(d, n++, "Focus");
         AE("OnEnter");
         AE("OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         AE("OnKeyUp");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         break;
      case 4: /* CT_CHECKBOX */
      case 8: /* CT_RADIO */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         InsAddEventCat(d, n++, "Focus");
         AE("OnEnter");
         AE("OnExit");
         break;
      case 5: /* CT_COMBOBOX */
         InsAddEventCat(d, n++, "Action");
         AE("OnChange");
         AE("OnClick");
         InsAddEventCat(d, n++, "Focus");
         AE("OnEnter");
         AE("OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         break;
      case 1: /* CT_LABEL */
      case 31: /* CT_STATICTEXT */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         break;
      case 6: /* CT_GROUPBOX */
      case 25: /* CT_PANEL */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         InsAddEventCat(d, n++, "Layout");
         AE("OnResize");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         break;
      case 7: /* CT_LISTBOX */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         AE("OnChange");
         InsAddEventCat(d, n++, "Focus");
         AE("OnEnter");
         AE("OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         break;
      case 20: /* CT_TREEVIEW */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         AE("OnChange");
         AE("OnExpand");
         AE("OnCollapse");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         break;
      case 21: /* CT_LISTVIEW */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         AE("OnChange");
         AE("OnColumnClick");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         break;
      case 79: case 80: /* CT_BROWSE, CT_DBGRID */
         InsAddEventCat(d, n++, "Action");
         AE("OnCellClick");
         AE("OnCellDblClick");
         AE("OnHeaderClick");
         AE("OnSort");
         AE("OnScroll");
         AE("OnRowSelect");
         InsAddEventCat(d, n++, "Data");
         AE("OnCellEdit");
         InsAddEventCat(d, n++, "Layout");
         AE("OnColumnResize");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         break;
      case 39: /* CT_PAINTBOX */
         InsAddEventCat(d, n++, "Action");
         AE("OnPaint");
         AE("OnClick");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         AE("OnMouseUp");
         AE("OnMouseMove");
         InsAddEventCat(d, n++, "Layout");
         AE("OnResize");
         break;
      case 38: /* CT_TIMER */
         InsAddEventCat(d, n++, "Action");
         AE("OnTimer");
         break;
      case 22: /* CT_PROGRESSBAR */
         break; /* no user events */
      case 34: /* CT_TRACKBAR */
      case 26: /* CT_SCROLLBAR */
         InsAddEventCat(d, n++, "Action");
         AE("OnChange");
         AE("OnScroll");
         break;
      case 33: /* CT_TABCONTROL */
      case 35: /* CT_UPDOWN */
      case 36: /* CT_DATETIMEPICKER */
      case 37: /* CT_MONTHCALENDAR */
         InsAddEventCat(d, n++, "Action");
         AE("OnChange");
         AE("OnClick");
         break;
      case 14: /* CT_IMAGE */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnDblClick");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         break;
      default:
         /* Generic events for all other controls */
         InsAddEventCat(d, n++, "Action");
         AE("OnClick");
         AE("OnChange");
         InsAddEventCat(d, n++, "Keyboard");
         AE("OnKeyDown");
         InsAddEventCat(d, n++, "Mouse");
         AE("OnMouseDown");
         break;
   }

   #undef AE

   /* Cleanup */
   s_pEventCode = NULL;
   if( pCode ) HeapFree( GetProcessHeap(), 0, pCode );
}

/* Update the combo selection to match the currently inspected control.
 * Does NOT clear the combo - the full list is populated from Harbour. */
static void InsUpdateCombo( INSDATA * d )
{
   int i, nCount, nSel = -1;

   if( !d || !d->hCombo || !d->hFormCtrl ) return;

   nCount = (int) SendMessage( d->hCombo, CB_GETCOUNT, 0, 0 );
   if( nCount <= 0 ) return;

   /* Find which combo index matches the current control */
   if( d->hCtrl == d->hFormCtrl )
      nSel = 0;  /* form itself is always index 0 */
   else
   {
      /* Search by matching the name from rows data */
      char szName[64] = "", szClass[64] = "", szSearch[128];
      int j;
      for( j = 0; j < d->nRows; j++ )
      {
         if( !d->rows[j].bIsCat && lstrcmpiA( d->rows[j].szName, "cName" ) == 0 )
            lstrcpynA( szName, d->rows[j].szValue, 64 );
         if( !d->rows[j].bIsCat && lstrcmpiA( d->rows[j].szName, "cClassName" ) == 0 )
            lstrcpynA( szClass, d->rows[j].szValue, 64 );
      }
      if( szName[0] )
      {
         sprintf( szSearch, "%s AS %s", szName, szClass );
         nSel = (int) SendMessageA( d->hCombo, CB_FINDSTRINGEXACT, (WPARAM)-1, (LPARAM) szSearch );
      }
   }

   if( nSel >= 0 )
      SendMessage( d->hCombo, CB_SETCURSEL, nSel, 0 );
}

/* INS_ComboAdd( hInsData, cText ) - add entry to combo from Harbour */
HB_FUNC( INS_COMBOADD )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d && d->hCombo && HB_ISCHAR(2) )
      SendMessageA( d->hCombo, CB_ADDSTRING, 0, (LPARAM) hb_parc(2) );
}

/* INS_ComboSelect( hInsData, nIndex ) */
HB_FUNC( INS_COMBOSELECT )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d && d->hCombo )
      SendMessage( d->hCombo, CB_SETCURSEL, hb_parni(2), 0 );
}

/* INS_ComboClear( hInsData ) */
HB_FUNC( INS_COMBOCLEAR )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d && d->hCombo )
      SendMessage( d->hCombo, CB_RESETCONTENT, 0, 0 );
}

HB_FUNC( INS_BRINGTOFRONT )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d && d->hWnd )
   {
      SetWindowPos( d->hWnd, HWND_TOPMOST, 0, 0, 0, 0,
         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE );
      SetWindowPos( d->hWnd, HWND_NOTOPMOST, 0, 0, 0, 0,
         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE );
   }
}

/* INS_Destroy( hInsData ) */
/* INS_SetPos( hInsData, nLeft, nTop, nWidth, nHeight ) */
HB_FUNC( INS_SETPOS )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d || !d->hWnd ) return;
   MoveWindow( d->hWnd, hb_parni(2), hb_parni(3), hb_parni(4), hb_parni(5), TRUE );
}

/* INS_SetDebugMode( hInsData, lDebug )
 * .T. = switch to debug tabs (Vars, Call Stack, Watch), hide combo
 * .F. = restore Properties/Events, show combo */
HB_FUNC( INS_SETDEBUGMODE )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   HB_BOOL bDebug = hb_parl(2);
   TCITEMA tci;
   if( !d ) return;

   d->bDebugMode = bDebug ? 1 : 0;

   /* Remove all tabs */
   SendMessage( d->hTab, TCM_DELETEALLITEMS, 0, 0 );
   memset( &tci, 0, sizeof(tci) );
   tci.mask = TCIF_TEXT;

   if( bDebug )
   {
      tci.pszText = "Vars";       SendMessageA( d->hTab, TCM_INSERTITEMA, 0, (LPARAM)&tci );
      tci.pszText = "Call Stack"; SendMessageA( d->hTab, TCM_INSERTITEMA, 1, (LPARAM)&tci );
      tci.pszText = "Watch";     SendMessageA( d->hTab, TCM_INSERTITEMA, 2, (LPARAM)&tci );
      ShowWindow( d->hCombo, SW_HIDE );
      SetWindowTextA( d->hWnd, "Debugger" );
      /* Show Vars list, hide Events list */
      ListView_DeleteAllItems( d->hList );
      ListView_DeleteAllItems( d->hEventList );
      ShowWindow( d->hList, SW_SHOW );
      ShowWindow( d->hEventList, SW_HIDE );
      /* Set column headers for debug: Vars = Variable/Value, Stack = Function/Line */
      {
         LVCOLUMNA lvc;
         memset( &lvc, 0, sizeof(lvc) );
         lvc.mask = LVCF_TEXT;
         lvc.pszText = "Variable";
         SendMessageA( d->hList, LVM_SETCOLUMNA, 0, (LPARAM)&lvc );
         lvc.pszText = "Value";
         SendMessageA( d->hList, LVM_SETCOLUMNA, 1, (LPARAM)&lvc );
         lvc.pszText = "Function";
         SendMessageA( d->hEventList, LVM_SETCOLUMNA, 0, (LPARAM)&lvc );
         lvc.pszText = "Line";
         SendMessageA( d->hEventList, LVM_SETCOLUMNA, 1, (LPARAM)&lvc );
      }
      d->nActiveTab = 0;
   }
   else
   {
      tci.pszText = "Properties"; SendMessageA( d->hTab, TCM_INSERTITEMA, 0, (LPARAM)&tci );
      tci.pszText = "Events";    SendMessageA( d->hTab, TCM_INSERTITEMA, 1, (LPARAM)&tci );
      ShowWindow( d->hCombo, SW_SHOW );
      SetWindowTextA( d->hWnd, "Object Inspector" );
      /* Clear debug data and show property list */
      ListView_DeleteAllItems( d->hList );
      ListView_DeleteAllItems( d->hEventList );
      ShowWindow( d->hList, SW_SHOW );
      ShowWindow( d->hEventList, SW_HIDE );
      d->nRows = 0;
      d->nVisible = 0;
      /* Restore column headers */
      {
         LVCOLUMNA lvc;
         memset( &lvc, 0, sizeof(lvc) );
         lvc.mask = LVCF_TEXT;
         lvc.pszText = "Property";
         SendMessageA( d->hList, LVM_SETCOLUMNA, 0, (LPARAM)&lvc );
         lvc.pszText = "Value";
         SendMessageA( d->hList, LVM_SETCOLUMNA, 1, (LPARAM)&lvc );
         lvc.pszText = "Event";
         SendMessageA( d->hEventList, LVM_SETCOLUMNA, 0, (LPARAM)&lvc );
         lvc.pszText = "Handler";
         SendMessageA( d->hEventList, LVM_SETCOLUMNA, 1, (LPARAM)&lvc );
      }
      d->nActiveTab = 0;
   }
   SendMessage( d->hTab, TCM_SETCURSEL, 0, 0 );
   InvalidateRect( d->hTab, NULL, TRUE );
   InvalidateRect( d->hWnd, NULL, TRUE );
}

/* INS_SetDebugLocals( hInsData, cVarsStr )
 * Format: "VARS [PUBLIC] name=val(T) [PRIVATE] ... [LOCAL] ..." */
HB_FUNC( INS_SETDEBUGLOCALS )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   const char * str = HB_ISCHAR(2) ? hb_parc(2) : "";
   int row = 0;
   if( !d || !d->bDebugMode ) return;

   ListView_DeleteAllItems( d->hList );
   if( strncmp( str, "VARS", 4 ) == 0 ) str += 4;

   while( *str )
   {
      LVITEMA item;
      while( *str == ' ' ) str++;
      if( !*str ) break;

      /* Category header [PUBLIC], [PRIVATE], [LOCAL] */
      if( *str == '[' )
      {
         char cat[32];
         int ci = 0;
         str++;
         while( *str && *str != ']' && ci < 31 ) cat[ci++] = *str++;
         cat[ci] = 0;
         if( *str == ']' ) str++;
         while( *str == ' ' ) str++;

         memset( &item, 0, sizeof(item) );
         item.mask = LVIF_TEXT;
         item.iItem = row;
         item.pszText = cat;
         ListView_InsertItem( d->hList, &item );
         ListView_SetItemText( d->hList, row, 1, (LPSTR)"" );
         row++;
         continue;
      }

      /* Parse name=value */
      {
         char name[64], value[256];
         int ni = 0, vi = 0;
         while( *str && *str != '=' && *str != ' ' && ni < 63 ) name[ni++] = *str++;
         name[ni] = 0;
         if( *str == '=' ) str++;
         while( *str && *str != ' ' && vi < 255 ) value[vi++] = *str++;
         value[vi] = 0;
         while( *str == ' ' ) str++;

         if( ni > 0 )
         {
            memset( &item, 0, sizeof(item) );
            item.mask = LVIF_TEXT;
            item.iItem = row;
            item.pszText = name;
            ListView_InsertItem( d->hList, &item );
            ListView_SetItemText( d->hList, row, 1, value );
            row++;
         }
      }
   }
}

/* INS_SetDebugStack( hInsData, cStackStr )
 * Format: "STACK FUNC(line) FUNC2(line2) ..." */
HB_FUNC( INS_SETDEBUGSTACK )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   const char * str = HB_ISCHAR(2) ? hb_parc(2) : "";
   int row = 0;
   if( !d || !d->bDebugMode ) return;

   /* Use hEventList for stack (hidden in normal mode, reused in debug) */
   ListView_DeleteAllItems( d->hEventList );
   if( strncmp( str, "STACK", 5 ) == 0 ) str += 5;

   while( *str )
   {
      LVITEMA item;
      char token[128], func[64], lineStr[16];
      char * paren;
      int ti = 0;

      while( *str == ' ' ) str++;
      if( !*str ) break;

      while( *str && *str != ' ' && ti < 127 ) token[ti++] = *str++;
      token[ti] = 0;

      /* Parse FUNC(line) */
      func[0] = 0; lineStr[0] = 0;
      paren = strchr( token, '(' );
      if( paren )
      {
         char * endP;
         *paren = 0;
         strncpy( func, token, 63 ); func[63] = 0;
         endP = strchr( paren + 1, ')' );
         if( endP ) { *endP = 0; strncpy( lineStr, paren + 1, 15 ); lineStr[15] = 0; }
      }
      else
         strncpy( func, token, 63 );

      memset( &item, 0, sizeof(item) );
      item.mask = LVIF_TEXT;
      item.iItem = row;
      item.pszText = func;
      ListView_InsertItem( d->hEventList, &item );
      ListView_SetItemText( d->hEventList, row, 1, lineStr );
      row++;
   }
}

/* INS_RefreshTheme( hInsData ) — update colors after dark/light toggle */
HB_FUNC( INS_REFRESHTHEME )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d ) return;

   /* Update window brush */
   if( d->hBrush ) DeleteObject( d->hBrush );
   d->hBrush = CreateSolidBrush( CLR_WND_BG );
   SetClassLongPtr( d->hWnd, GCLP_HBRBACKGROUND, (LONG_PTR) d->hBrush );

   /* Update ListViews */
   ListView_SetBkColor( d->hList, CLR_BG );
   ListView_SetTextBkColor( d->hList, CLR_BG );
   ListView_SetTextColor( d->hList, CLR_TEXT );
   ListView_SetBkColor( d->hEventList, CLR_BG );
   ListView_SetTextBkColor( d->hEventList, CLR_BG );
   ListView_SetTextColor( d->hEventList, CLR_TEXT );

   /* Dark/light title bar */
   {
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         typedef long (WINAPI *pDwmFn)(HWND,DWORD,const void*,DWORD);
         pDwmFn fn = (pDwmFn) GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( fn ) { BOOL val = s_bDarkIDE; fn(d->hWnd, 20, &val, sizeof(val)); }
         FreeLibrary(hDwm);
      }
   }

   /* Force full repaint */
   InvalidateRect( d->hWnd, NULL, TRUE );
   InvalidateRect( d->hList, NULL, TRUE );
   InvalidateRect( d->hEventList, NULL, TRUE );
   InvalidateRect( d->hTab, NULL, TRUE );
}

/* INS_SetBrowseCol( hInsData, nCol ) - set column index for property editing */
HB_FUNC( INS_SETBROWSECOL )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d ) d->nBrowseCol = hb_parni(2);
}

HB_FUNC( INS_DESTROY )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   if( d->pOnComboSel ) hb_itemRelease( d->pOnComboSel );
   if( d->pOnEventDblClick ) hb_itemRelease( d->pOnEventDblClick );
   if( d->pOnPropChanged ) hb_itemRelease( d->pOnPropChanged );
   if( d->hWnd ) DestroyWindow( d->hWnd );
   DeleteObject( d->hFont );
   DeleteObject( d->hBold );
   DeleteObject( d->hBrush );
   free( d );
}

#pragma ENDDUMP
