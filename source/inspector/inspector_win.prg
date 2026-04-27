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
// hSelect: if non-zero, select this control in the combo after populating
function InspectorPopulateCombo( hForm, hSelect )
   local h := _InsGetData()
   local i, j, nCount, hChild, cName, cClass, cEntry, nColCount
   local aMap, cTabsStr, aTabsArr, jj, nSelIdx

   if h == 0 .or. hForm == 0
      return nil
   endif

   INS_ComboClear( h )
   INS_SetFormCtrl( h, hForm )
   aMap := {}
   nSelIdx := 0  // default: select form

   // Add the form itself: "oForm1 AS TForm1"
   cName  := UI_GetProp( hForm, "cName" )
   cClass := UI_GetProp( hForm, "cClassName" )
   if Empty( cName ); cName := "Form1"; endif
   cEntry := "o" + cName + " AS T" + cName
   INS_ComboAdd( h, cEntry )
   AAdd( aMap, { 0, hForm, 0 } )
   if hSelect != nil .and. hSelect == hForm; nSelIdx := 0; endif

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
         if hSelect != nil .and. hSelect == hChild; nSelIdx := Len( aMap ) - 1; endif

         // If it's a Browse, add its columns as sub-entries
         if UI_GetType( hChild ) == 79  // CT_BROWSE
            nColCount := UI_BrowseColCount( hChild )
            for j := 1 to nColCount
               cEntry := "o" + cName + "Col" + LTrim( Str( j ) ) + " AS TBrwColumn"
               INS_ComboAdd( h, cEntry )
               AAdd( aMap, { 2, hChild, j - 1 } )  // 0-based col index
            next
         endif

         // If it's a Folder/TPageControl, add its pages as sub-entries
         // "oFolderN:aPages[N] AS TFolderPage"
         if UI_GetType( hChild ) == 33  // CT_TABCONTROL2
            cTabsStr := UI_GetProp( hChild, "aTabs" )
            if ! Empty( cTabsStr )
               aTabsArr := hb_ATokens( cTabsStr, "|" )
               for jj := 1 to Len( aTabsArr )
                  cEntry := "o" + cName + ":aPages[" + LTrim( Str( jj ) ) + ;
                            "] AS TFolderPage  /* " + aTabsArr[jj] + " */"
                  INS_ComboAdd( h, cEntry )
                  AAdd( aMap, { 3, hChild, jj - 1 } )  // 0-based page idx
               next
            endif
         endif
      endif
   next

   _InsSetComboMap( aMap )

   // Select the target control (or form if not specified)
   INS_ComboSelect( h, nSelIdx )

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
/* Scaled at runtime in INS_Init: 205px at 96 DPI, doubled at 192 DPI etc.
   Used for "Property"/"Event" name column width. */
static int s_colNameW = 205;
#define COL_NAME_W (s_colNameW)

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
   int    nFolderPage; /* -1 = normal view, >= 0 = showing TFolderPage N */
   PHB_ITEM pOnComboSel; /* callback when combo selection changes: {|nIndex| ... } */
   PHB_ITEM pOnEventDblClick; /* callback when event double-clicked: {|hCtrl, cEvent| ... } */
   PHB_ITEM pOnPropChanged;   /* callback when property value changes: {|| ... } */
   BOOL   bComboReady;  /* TRUE once the in-place combo is ready for user interaction */
} INSDATA;

/* Forward */
static void InsPopulate( INSDATA * d );
static void InsRebuild( INSDATA * d );
static void InsStartEdit( INSDATA * d, int nLVRow );
static void InsEndEdit( INSDATA * d, BOOL bApply );
static void InsApplyValue( INSDATA * d, int nReal, const char * szVal );
static void InsColorPick( INSDATA * d, int nLVRow );
static void InsFontPick( INSDATA * d, int nLVRow );
static void InsFilePick( INSDATA * d, int nLVRow );
static void InsPopulateEvents( INSDATA * d );
static void InsUpdateCombo( INSDATA * d );  /* updates combo from current rows data */
static void InsArrayEdit( INSDATA * d, int nLVRow );
static void InsMenuEdit( INSDATA * d, int nLVRow );

/* Sentinel message IDs for MLEdit dialog internal signaling */
#define WM_MLEDIT_OK     (WM_USER + 501)
#define WM_MLEDIT_CANCEL (WM_USER + 502)

static LRESULT CALLBACK MLEditWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   static HBRUSH s_hEdBr = NULL;
   if( msg == WM_COMMAND )
   {
      int id = LOWORD( wParam );
      if( id == IDOK )
         PostMessage( hWnd, WM_MLEDIT_OK, 0, 0 );
      else if( id == IDCANCEL )
         PostMessage( hWnd, WM_MLEDIT_CANCEL, 0, 0 );
      return 0;
   }
   if( msg == WM_CLOSE )
   {
      PostMessage( hWnd, WM_MLEDIT_CANCEL, 0, 0 );
      return 0;
   }
   if( msg == WM_KEYDOWN && wParam == VK_ESCAPE )
   {
      PostMessage( hWnd, WM_MLEDIT_CANCEL, 0, 0 );
      return 0;
   }
   if( msg == WM_ERASEBKGND && s_bDarkIDE )
   {
      HDC hdc = (HDC) wParam;
      RECT rc;
      HBRUSH hBr;
      GetClientRect( hWnd, &rc );
      hBr = CreateSolidBrush( CLR_WND_BG );
      FillRect( hdc, &rc, hBr );
      DeleteObject( hBr );
      return 1;
   }
   if( msg == WM_CTLCOLOREDIT && s_bDarkIDE )
   {
      HDC hdc = (HDC) wParam;
      SetBkColor( hdc, CLR_EDIT_BG );
      SetTextColor( hdc, CLR_EDIT_TEXT );
      if( s_hEdBr ) DeleteObject( s_hEdBr );
      s_hEdBr = CreateSolidBrush( CLR_EDIT_BG );
      return (LRESULT) s_hEdBr;
   }
   return DefWindowProcA( hWnd, msg, wParam, lParam );
}

static void RegisterMLEditClass( void )
{
   static BOOL bDone = FALSE;
   WNDCLASSA wc;
   if( bDone ) return;
   bDone = TRUE;
   memset( &wc, 0, sizeof(wc) );
   wc.lpfnWndProc   = MLEditWndProc;
   wc.hInstance     = GetModuleHandleA( NULL );
   wc.hCursor       = LoadCursorA( NULL, IDC_ARROW );
   wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
   wc.lpszClassName = "HBMLEditDlg";
   RegisterClassA( &wc );
}

static int ShowMLEditDialog( HWND hParent, char * szValue, int nMaxLen )
{
   HWND hDlg, hEdit, hOK, hCancel;
   int nResult;
   MSG msg;
   /* Dialog dimensions */
   int dlgW = 460, dlgH = 340;
   int btnW = 90, btnH = 28, btnY = 0, editH = 0;
   int scrW, scrH, dlgX, dlgY;
   RECT rcWork;

   RegisterMLEditClass();

   /* Center on working area */
   SystemParametersInfoA( SPI_GETWORKAREA, 0, &rcWork, 0 );
   scrW = rcWork.right  - rcWork.left;
   scrH = rcWork.bottom - rcWork.top;
   dlgX = rcWork.left + ( scrW - dlgW ) / 2;
   dlgY = rcWork.top  + ( scrH - dlgH ) / 2;

   hDlg = CreateWindowExA( WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
      "HBMLEditDlg", "Edit Text",
      WS_POPUP | WS_CAPTION | WS_SYSMENU,
      dlgX, dlgY, dlgW, dlgH,
      hParent, NULL, GetModuleHandleA(NULL), NULL );
   if( !hDlg ) return IDCANCEL;

   /* Apply dark title bar if needed */
   if( s_bDarkIDE )
   {
      BOOL bDark = TRUE;
      DwmSetWindowAttribute( hDlg, DWMWA_USE_IMMERSIVE_DARK_MODE, &bDark, sizeof(bDark) );
   }

   /* Layout based on actual client area */
   {
      RECT rcCl;
      int cW, cH;
      GetClientRect( hDlg, &rcCl );
      cW = rcCl.right;
      cH = rcCl.bottom;
      btnY  = cH - btnH - 10;
      editH = btnY - 20;   /* 10px top margin + 10px gap above buttons */

      hEdit = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", szValue,
         WS_CHILD | WS_VISIBLE | WS_VSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN,
         10, 10, cW - 20, editH, hDlg, (HMENU) 101, GetModuleHandleA(NULL), NULL );

      hOK = CreateWindowExA( 0, "BUTTON", "OK",
         WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
         cW - btnW*2 - 20, btnY, btnW, btnH,
         hDlg, (HMENU) IDOK, GetModuleHandleA(NULL), NULL );

      hCancel = CreateWindowExA( 0, "BUTTON", "Cancel",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         cW - btnW - 10, btnY, btnW, btnH,
         hDlg, (HMENU) IDCANCEL, GetModuleHandleA(NULL), NULL );
   }

   (void) hOK; (void) hCancel;
   SetFocus( hEdit );
   SendMessage( hEdit, EM_SETSEL, 0, -1 );
   ShowWindow( hDlg, SW_SHOW );
   UpdateWindow( hDlg );

   nResult = IDCANCEL;
   while( GetMessage( &msg, NULL, 0, 0 ) )
   {
      if( msg.hwnd == hDlg && msg.message == WM_MLEDIT_OK )
      {
         GetWindowTextA( hEdit, szValue, nMaxLen );
         nResult = IDOK;
         break;
      }
      if( msg.hwnd == hDlg && msg.message == WM_MLEDIT_CANCEL )
         break;
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }

   DestroyWindow( hDlg );
   return nResult;
}

static LRESULT CALLBACK InsBtnProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   INSDATA * d = (INSDATA *) GetPropA( hWnd, "InsData" );
   WNDPROC oldProc = (WNDPROC) GetPropA( hWnd, "OldBtnProc" );
   if( msg == WM_LBUTTONUP && d )
   {
      int nLV = d->nEditRow;
      int nReal = ( nLV >= 0 && nLV < d->nVisible ) ? d->map[nLV] : -1;
      char cType = ( nReal >= 0 ) ? d->rows[nReal].cType : 0;
      const char * szName = ( nReal >= 0 ) ? d->rows[nReal].szName : "";
      LRESULT r = CallWindowProc( oldProc, hWnd, msg, wParam, lParam );
      InsEndEdit( d, FALSE );
      if( cType == 'C' )
         InsColorPick( d, nLV );
      else if( cType == 'F' )
         InsFontPick( d, nLV );
      else if( cType == 'A' )
         InsArrayEdit( d, nLV );
      else if( cType == 'M' )
         InsMenuEdit( d, nLV );
      else if( cType == 'S' && lstrcmpiA( szName, "cFileName" ) == 0 )
         InsFilePick( d, nLV );
      else if( cType == 'S' && lstrcmpiA( szName, "cFileName" ) != 0 )
      {
         char szVal[4096];
         lstrcpynA( szVal, d->rows[nReal].szValue, sizeof(szVal) );
         if( ShowMLEditDialog( d->hWnd, szVal, sizeof(szVal) - 1 ) == IDOK )
         {
            lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
            InsApplyValue( d, nReal, szVal );
            InsRebuild( d );
         }
      }
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

   /* CBS_DROPDOWNLIST: CB_SETCURSEL fires a spurious CBN_SELCHANGE during
      setup (before the user opens the dropdown).  bComboReady is FALSE until
      InsStartEdit posts WM_USER+202 which sets it TRUE.  Ignore any
      CBN_SELCHANGE that arrives before the combo is ready.
      After that, commit only when the dropdown has actually closed (real
      pick by click or Enter), not while still open (hover / key navigation). */
   if( msg == WM_COMMAND && HIWORD(wParam) == CBN_SELCHANGE )
   {
      LRESULT r = CallWindowProc( d->oldEditProc, hWnd, msg, wParam, lParam );
      if( d->bComboReady && !SendMessage( hWnd, CB_GETDROPPEDSTATE, 0, 0 ) )
         PostMessage( d->hWnd, WM_USER + 200, 0, 0 );
      return r;
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

/* File picker for string properties with a "..." button (cFileName).
   Opens a standard file-open dialog starting from the current value's
   folder, writes the chosen path back and refreshes the inspector. */
static void InsFilePick( INSDATA * d, int nLVRow )
{
   OPENFILENAMEA ofn = {0};
   char szFile[MAX_PATH];
   int nReal;

   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];

   lstrcpynA( szFile, d->rows[nReal].szValue, sizeof(szFile) );

   ofn.lStructSize = sizeof(ofn);
   ofn.hwndOwner = d->hWnd;
   ofn.lpstrFilter = "DBF tables (*.dbf)\0*.dbf\0All files (*.*)\0*.*\0";
   ofn.lpstrFile = szFile;
   ofn.nMaxFile = sizeof(szFile);
   ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY | OFN_EXPLORER;
   ofn.lpstrDefExt = "dbf";

   if( GetOpenFileNameA( &ofn ) )
   {
      lstrcpynA( d->rows[nReal].szValue, szFile, sizeof(d->rows[0].szValue) );
      InsApplyValue( d, nReal, szFile );
      InsRebuild( d );
   }
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
   char face[LF_FACESIZE];
   char * comma;
   char * comma2;
   int sz;

   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];

   /* Parse current "FontName,Size[,RRGGBB]" (Size = point size) */
   lstrcpynA( face, d->rows[nReal].szValue, LF_FACESIZE );
   comma = strchr( face, ',' );
   sz = 12;
   cf.rgbColors = GetSysColor( COLOR_WINDOWTEXT );
   if( comma ) {
      *comma = 0;
      sz = atoi( comma + 1 );
      comma2 = strchr( comma + 1, ',' );
      if( comma2 ) {
         unsigned int r=0,g=0,b=0;
         if( sscanf( comma2 + 1, "%02X%02X%02X", &r, &g, &b ) == 3 )
            cf.rgbColors = RGB( r, g, b );
      }
   }
   lstrcpynA( lf.lfFaceName, face, LF_FACESIZE );
   /* Convert point size -> logical pixel height for the LOGFONT the dialog expects */
   { HDC hTmpDC = GetDC( NULL );
     lf.lfHeight = -MulDiv( sz, GetDeviceCaps( hTmpDC, LOGPIXELSY ), 72 );
     ReleaseDC( NULL, hTmpDC );
   }
   lf.lfCharSet = DEFAULT_CHARSET;

   cf.lStructSize = sizeof(cf);
   cf.hwndOwner = d->hWnd;
   cf.lpLogFont = &lf;
   cf.iPointSize = sz * 10;
   cf.Flags = CF_SCREENFONTS | CF_INITTOLOGFONTSTRUCT | CF_EFFECTS;

   if( ChooseFontA( &cf ) )
   {
      /* cf.iPointSize is point size * 10 — this is what we must store */
      int pt = cf.iPointSize / 10;
      if( pt <= 0 ) pt = 12;
      sprintf( szVal, "%s,%d,%02X%02X%02X", lf.lfFaceName, pt,
         GetRValue(cf.rgbColors), GetGValue(cf.rgbColors), GetBValue(cf.rgbColors) );
      lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
      InsApplyValue( d, nReal, szVal );

      /* Also push nClrText so WM_CTLCOLORSTATIC sees it immediately */
      if( d->hCtrl )
      {
         PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
         if( pDyn )
         {
            hb_vmPushDynSym( pDyn ); hb_vmPushNil();
            hb_vmPushNumInt( (HB_MAXINT) d->hCtrl );
            hb_vmPushString( "nClrText", 8 );
            hb_vmPushNumInt( (HB_MAXINT) cf.rgbColors );
            hb_vmDo( 3 );
         }
      }
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

/* ===== Menu Items Editor (CT_MAINMENU) ===================================
 * Tree on left, property panel on right, toolbar buttons across the top.
 * Mirrors gtk3_inspector.c::OpenMenuEditor and cocoa_inspector.m.
 * Serial format: items separated by '|', fields by '\x01':
 *   caption \x01 shortcut \x01 handler \x01 enabled \x01 level \x01 parent
 * Separator caption is "---". Up to 128 nodes.
 * ====================================================================== */

#define MEI_MAX     128
#define MEI_IDC_TREE   2001
#define MEI_IDC_CAP    2002
#define MEI_IDC_SCUT   2003
#define MEI_IDC_HNDL   2004
#define MEI_IDC_ENAB   2005
#define MEI_IDC_BPOP   2010
#define MEI_IDC_BITM   2011
#define MEI_IDC_BSUB   2012
#define MEI_IDC_BSEP   2013
#define MEI_IDC_BUP    2014
#define MEI_IDC_BDN    2015
#define MEI_IDC_BDEL   2016

typedef struct {
   char szCaption[128];
   char szShortcut[32];
   char szHandler[128];
   int  bSeparator;
   int  bEnabled;
   int  nLevel;
   int  nParent;
} MEINode;

typedef struct {
   MEINode nodes[MEI_MAX];
   int     nCount;
   int     nSel;
   int     bUpdating;
   HWND    hDlg;
   HWND    hTree;
   HWND    hCap;
   HWND    hScut;
   HWND    hHndl;
   HWND    hEnab;
   HTREEITEM hItems[MEI_MAX];
   BOOL    bOK;
} MEIDATA;

static void MEI_Serialize( MEIDATA * d, char * out, int outLen )
{
   int pos = 0, i, n;
   const char * cap;
   out[0] = 0;
   for( i = 0; i < d->nCount && pos < outLen - 64; i++ ) {
      if( i > 0 ) out[pos++] = '|';
      cap = d->nodes[i].bSeparator ? "---" : d->nodes[i].szCaption;
      n = _snprintf( out + pos, outLen - pos, "%s\x01%s\x01%s\x01%d\x01%d\x01%d",
         cap, d->nodes[i].szShortcut, d->nodes[i].szHandler,
         d->nodes[i].bEnabled, d->nodes[i].nLevel, d->nodes[i].nParent );
      if( n > 0 ) pos += n;
   }
   if( pos < outLen ) out[pos] = 0;
}

static void MEI_Parse( MEIDATA * d, const char * raw )
{
   const char * pipe;
   int tl, fi;
   char tok[512];
   char * f0; char * f1; char * f2; char * f3; char * f4; char * f5;
   d->nCount = 0;
   if( !raw || !raw[0] ) return;
   while( *raw && d->nCount < MEI_MAX ) {
      pipe = strchr( raw, '|' );
      tl = pipe ? (int)(pipe - raw) : (int)strlen(raw);
      if( tl > 511 ) tl = 511;
      memcpy( tok, raw, tl ); tok[tl] = 0;
      fi = d->nCount;
      f0 = tok;
      f1 = strchr( f0, '\x01' ); if( f1 ) { *f1++ = 0; } else f1 = (char*)"";
      f2 = f1[0] ? strchr( f1, '\x01' ) : NULL; if( f2 ) { *f2++ = 0; } else f2 = (char*)"";
      f3 = f2[0] ? strchr( f2, '\x01' ) : NULL; if( f3 ) { *f3++ = 0; } else f3 = (char*)"";
      f4 = f3[0] ? strchr( f3, '\x01' ) : NULL; if( f4 ) { *f4++ = 0; } else f4 = (char*)"";
      f5 = f4[0] ? strchr( f4, '\x01' ) : NULL; if( f5 ) { *f5++ = 0; } else f5 = (char*)"-1";
      d->nodes[fi].bSeparator = strcmp( f0, "---" ) == 0;
      lstrcpynA( d->nodes[fi].szCaption, d->nodes[fi].bSeparator ? "" : f0, 128 );
      lstrcpynA( d->nodes[fi].szShortcut, f1, 32 );
      lstrcpynA( d->nodes[fi].szHandler,  f2, 128 );
      d->nodes[fi].bEnabled = f3[0] ? atoi( f3 ) : 1;
      d->nodes[fi].nLevel   = f4[0] ? atoi( f4 ) : 0;
      d->nodes[fi].nParent  = f5[0] ? atoi( f5 ) : -1;
      d->nCount++;
      if( !pipe ) break;
      raw = pipe + 1;
   }
}

static void MEI_RebuildTree( MEIDATA * d )
{
   HTREEITEM hParent;
   TVINSERTSTRUCTA tvis;
   int i, lv;
   char szDisp[200];
   SendMessage( d->hTree, WM_SETREDRAW, FALSE, 0 );
   TreeView_DeleteAllItems( d->hTree );
   for( i = 0; i < d->nCount; i++ ) {
      hParent = TVI_ROOT;
      lv = d->nodes[i].nLevel;
      if( lv > 0 && lv <= 7 ) {
         /* Find most recent node at level (lv-1) */
         int j;
         for( j = i - 1; j >= 0; j-- ) {
            if( !d->nodes[j].bSeparator && d->nodes[j].nLevel == lv - 1 ) {
               hParent = d->hItems[j];
               break;
            }
         }
      }
      memset( &tvis, 0, sizeof(tvis) );
      tvis.hParent = hParent;
      tvis.hInsertAfter = TVI_LAST;
      tvis.item.mask = TVIF_TEXT | TVIF_PARAM;
      tvis.item.lParam = (LPARAM) i;
      if( d->nodes[i].bSeparator )
         lstrcpyA( szDisp, "----------" );
      else if( d->nodes[i].szShortcut[0] )
         _snprintf( szDisp, sizeof(szDisp), "%s\t%s",
                    d->nodes[i].szCaption, d->nodes[i].szShortcut );
      else
         lstrcpynA( szDisp, d->nodes[i].szCaption, 199 );
      tvis.item.pszText = szDisp;
      d->hItems[i] = (HTREEITEM) SendMessageA( d->hTree, TVM_INSERTITEMA, 0, (LPARAM) &tvis );
   }
   /* Expand all */
   for( i = 0; i < d->nCount; i++ )
      TreeView_Expand( d->hTree, d->hItems[i], TVE_EXPAND );
   SendMessage( d->hTree, WM_SETREDRAW, TRUE, 0 );
   InvalidateRect( d->hTree, NULL, TRUE );
}

static void MEI_LoadSelected( MEIDATA * d )
{
   MEINode * n;
   d->bUpdating = 1;
   if( d->nSel < 0 || d->nSel >= d->nCount ) {
      SetWindowTextA( d->hCap,  "" );
      SetWindowTextA( d->hScut, "" );
      SetWindowTextA( d->hHndl, "" );
      SendMessage( d->hEnab, BM_SETCHECK, BST_UNCHECKED, 0 );
      EnableWindow( d->hCap,  FALSE );
      EnableWindow( d->hScut, FALSE );
      EnableWindow( d->hHndl, FALSE );
      EnableWindow( d->hEnab, FALSE );
      d->bUpdating = 0;
      return;
   }
   n = &d->nodes[d->nSel];
   EnableWindow( d->hCap,  !n->bSeparator );
   EnableWindow( d->hScut, !n->bSeparator );
   EnableWindow( d->hHndl, !n->bSeparator );
   EnableWindow( d->hEnab, !n->bSeparator );
   SetWindowTextA( d->hCap,  n->bSeparator ? "" : n->szCaption );
   SetWindowTextA( d->hScut, n->szShortcut );
   SetWindowTextA( d->hHndl, n->szHandler );
   SendMessage( d->hEnab, BM_SETCHECK, n->bEnabled ? BST_CHECKED : BST_UNCHECKED, 0 );
   d->bUpdating = 0;
}

static void MEI_AddNode( MEIDATA * d, int nLevel, int bSeparator )
{
   int ins, parent;
   if( d->nCount >= MEI_MAX ) return;
   ins = ( d->nSel >= 0 && d->nSel < d->nCount ) ? d->nSel + 1 : d->nCount;
   parent = -1;
   if( nLevel > 0 ) {
      int i;
      for( i = ins - 1; i >= 0; i-- ) {
         if( !d->nodes[i].bSeparator && d->nodes[i].nLevel == nLevel - 1 ) {
            parent = i; break;
         }
      }
   }
   /* Shift down */
   { int i;
     for( i = d->nCount; i > ins; i-- )
        d->nodes[i] = d->nodes[i-1];
   }
   memset( &d->nodes[ins], 0, sizeof(MEINode) );
   d->nodes[ins].bSeparator = bSeparator;
   d->nodes[ins].bEnabled   = 1;
   d->nodes[ins].nLevel     = nLevel;
   d->nodes[ins].nParent    = parent;
   if( !bSeparator )
      lstrcpyA( d->nodes[ins].szCaption,
         nLevel == 0 ? "Menu" : nLevel == 1 ? "Item" : "SubItem" );
   d->nCount++;
   d->nSel = ins;
   MEI_RebuildTree( d );
   MEI_LoadSelected( d );
}

static void MEI_DeleteNode( MEIDATA * d )
{
   int i;
   if( d->nSel < 0 || d->nSel >= d->nCount ) return;
   for( i = d->nSel; i < d->nCount - 1; i++ )
      d->nodes[i] = d->nodes[i+1];
   d->nCount--;
   if( d->nSel >= d->nCount ) d->nSel = d->nCount - 1;
   MEI_RebuildTree( d );
   MEI_LoadSelected( d );
}

static void MEI_MoveSel( MEIDATA * d, int nDir )
{
   int s, t;
   MEINode tmp;
   s = d->nSel;
   if( s < 0 || s >= d->nCount ) return;
   t = s + nDir;
   if( t < 0 || t >= d->nCount ) return;
   tmp = d->nodes[s]; d->nodes[s] = d->nodes[t]; d->nodes[t] = tmp;
   d->nSel = t;
   MEI_RebuildTree( d );
   MEI_LoadSelected( d );
}

static MEIDATA * s_pMEI = NULL;

static LRESULT CALLBACK MEIDlgProc( HWND hDlg, UINT msg, WPARAM wp, LPARAM lp )
{
   static HBRUSH s_hMEIBgBr = NULL;
   static HBRUSH s_hMEIEdBr = NULL;
   MEIDATA * d = s_pMEI;
   if( msg == WM_COMMAND && d ) {
      WORD id = LOWORD( wp );
      WORD code = HIWORD( wp );
      if( id == IDOK )     { d->bOK = TRUE;  DestroyWindow( hDlg ); return 0; }
      if( id == IDCANCEL ) { d->bOK = FALSE; DestroyWindow( hDlg ); return 0; }
      if( id == MEI_IDC_BPOP && code == BN_CLICKED ) { MEI_AddNode( d, 0, 0 ); return 0; }
      if( id == MEI_IDC_BITM && code == BN_CLICKED ) { MEI_AddNode( d, 1, 0 ); return 0; }
      if( id == MEI_IDC_BSUB && code == BN_CLICKED ) { MEI_AddNode( d, 2, 0 ); return 0; }
      if( id == MEI_IDC_BSEP && code == BN_CLICKED ) {
         int lv = ( d->nSel >= 0 ) ? d->nodes[d->nSel].nLevel : 1;
         if( lv == 0 ) lv = 1;
         MEI_AddNode( d, lv, 1 ); return 0;
      }
      if( id == MEI_IDC_BUP  && code == BN_CLICKED ) { MEI_MoveSel( d, -1 ); return 0; }
      if( id == MEI_IDC_BDN  && code == BN_CLICKED ) { MEI_MoveSel( d, +1 ); return 0; }
      if( id == MEI_IDC_BDEL && code == BN_CLICKED ) { MEI_DeleteNode( d );  return 0; }
      if( !d->bUpdating && d->nSel >= 0 && d->nSel < d->nCount ) {
         MEINode * n = &d->nodes[d->nSel];
         if( id == MEI_IDC_CAP && code == EN_CHANGE ) {
            GetWindowTextA( d->hCap, n->szCaption, 128 );
            MEI_RebuildTree( d );
            return 0;
         }
         if( id == MEI_IDC_SCUT && code == EN_CHANGE ) {
            GetWindowTextA( d->hScut, n->szShortcut, 32 );
            MEI_RebuildTree( d );
            return 0;
         }
         if( id == MEI_IDC_HNDL && code == EN_CHANGE ) {
            GetWindowTextA( d->hHndl, n->szHandler, 128 );
            return 0;
         }
         if( id == MEI_IDC_ENAB && code == BN_CLICKED ) {
            n->bEnabled = ( SendMessage( d->hEnab, BM_GETCHECK, 0, 0 ) == BST_CHECKED );
            return 0;
         }
      }
   }
   if( msg == WM_NOTIFY && d ) {
      LPNMHDR pnmh = (LPNMHDR) lp;
      if( pnmh->idFrom == MEI_IDC_TREE && pnmh->code == TVN_SELCHANGED ) {
         LPNMTREEVIEWA pnmtv = (LPNMTREEVIEWA) lp;
         if( pnmtv->itemNew.lParam >= 0 && pnmtv->itemNew.lParam < d->nCount )
            d->nSel = (int) pnmtv->itemNew.lParam;
         else
            d->nSel = -1;
         MEI_LoadSelected( d );
         return 0;
      }
   }
   /* Dark theme paint */
   if( msg == WM_ERASEBKGND && s_bDarkIDE ) {
      HDC hdc = (HDC) wp;
      RECT rc;
      GetClientRect( hDlg, &rc );
      if( !s_hMEIBgBr ) s_hMEIBgBr = CreateSolidBrush( CLR_WND_BG );
      FillRect( hdc, &rc, s_hMEIBgBr );
      return 1;
   }
   if( ( msg == WM_CTLCOLORSTATIC || msg == WM_CTLCOLORBTN || msg == WM_CTLCOLORDLG )
       && s_bDarkIDE ) {
      HDC hdc = (HDC) wp;
      SetBkColor( hdc, CLR_WND_BG );
      SetTextColor( hdc, CLR_TEXT );
      if( !s_hMEIBgBr ) s_hMEIBgBr = CreateSolidBrush( CLR_WND_BG );
      return (LRESULT) s_hMEIBgBr;
   }
   if( msg == WM_CTLCOLOREDIT && s_bDarkIDE ) {
      HDC hdc = (HDC) wp;
      SetBkColor( hdc, CLR_EDIT_BG );
      SetTextColor( hdc, CLR_EDIT_TEXT );
      if( !s_hMEIEdBr ) s_hMEIEdBr = CreateSolidBrush( CLR_EDIT_BG );
      return (LRESULT) s_hMEIEdBr;
   }
   if( msg == WM_CLOSE && d ) { d->bOK = FALSE; DestroyWindow( hDlg ); return 0; }
   return DefWindowProcA( hDlg, msg, wp, lp );
}

static void InsMenuEdit( INSDATA * d, int nLVRow )
{
   MEIDATA * mei;
   int nReal;
   char fullSerial[4096] = "";
   HINSTANCE hInst = GetModuleHandle( NULL );
   static BYTE tplBuf[1024];
   DLGTEMPLATE * pDT;
   WORD * pw;
   int w = 480, h = 320;

   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];

   /* Fetch full serial via UI_GetProp (IROW.szValue is too small) */
   {
      PHB_DYNS pDyn = hb_dynsymFindName( "UI_GETPROP" );
      if( pDyn ) {
         hb_vmPushDynSym( pDyn ); hb_vmPushNil();
         hb_vmPushNumInt( d->hCtrl );
         hb_vmPushString( "aMenuItems", 10 );
         hb_vmDo( 2 );
         {  const char * res = hb_parc( -1 );
            if( res ) lstrcpynA( fullSerial, res, sizeof(fullSerial) );
         }
      }
   }

   mei = (MEIDATA *) calloc( 1, sizeof(MEIDATA) );
   mei->nSel = -1;
   MEI_Parse( mei, fullSerial );

   /* Minimal empty dialog template; controls are created in WM_INITDIALOG via subclass.
      Easier path: build a manual modal window. We'll use DialogBoxIndirect with empty
      template and create children when WM_INITDIALOG fires — but our proc uses s_pMEI.
      Simpler: create modal window directly with CreateWindowEx, run own message loop. */

   memset( tplBuf, 0, sizeof(tplBuf) );
   pDT = (DLGTEMPLATE *) tplBuf;
   pDT->style = DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU;
   pDT->cdit = 0;
   pDT->cx = (short) w; pDT->cy = (short) h;
   pw = (WORD *)( pDT + 1 );
   *pw++ = 0; *pw++ = 0;
   { const char * t = "Menu Items Editor";
     while( *t ) *pw++ = (WORD)(unsigned char)*t++;
     *pw++ = 0; }

   s_pMEI = mei;

   /* Use modeless creation: DialogBoxIndirect w/ INITDIALOG handler that builds children */
   /* Simpler: define WM_INITDIALOG branch that populates children */

   /* Custom dialog proc that creates children on init */
   {
      DLGPROC oldProc = (DLGPROC) MEIDlgProc;
      (void) oldProc;
   }

   /* We use a different approach: create a modal popup window manually */
   {
      WNDCLASSA wc = {0};
      static BOOL bReg = FALSE;
      HWND hDlg, hPar = d->hWnd;
      int x, y, sw, sh;
      MSG msg;
      BOOL bDone = FALSE;
      const int dlgW = 720, dlgH = 480;

      if( !bReg ) {
         wc.lpfnWndProc = (WNDPROC) DefWindowProcA;
         wc.hInstance = hInst;
         wc.hCursor = LoadCursor( NULL, IDC_ARROW );
         wc.hbrBackground = (HBRUSH)( COLOR_BTNFACE + 1 );
         wc.lpszClassName = "HBMEIDlg";
         RegisterClassA( &wc );
         bReg = TRUE;
      }
      /* Center on primary screen */
      sw = GetSystemMetrics( SM_CXSCREEN );
      sh = GetSystemMetrics( SM_CYSCREEN );
      x = ( sw - dlgW ) / 2; if( x < 0 ) x = 50;
      y = ( sh - dlgH ) / 2; if( y < 0 ) y = 50;
      hDlg = CreateWindowExA( WS_EX_DLGMODALFRAME | WS_EX_APPWINDOW,
         "HBMEIDlg", "Menu Items Editor",
         WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
         x, y, dlgW, dlgH, NULL, NULL, hInst, NULL );
      if( !hDlg ) { free( mei ); s_pMEI = NULL; return; }
      mei->hDlg = hDlg;
      SetWindowTextA( hDlg, "Menu Items Editor" );
      SetWindowLongPtr( hDlg, GWLP_WNDPROC, (LONG_PTR) MEIDlgProc );
      /* Dark frame */
      if( s_bDarkIDE ) {
         BOOL bDark = TRUE;
         DwmSetWindowAttribute( hDlg, DWMWA_USE_IMMERSIVE_DARK_MODE,
                                &bDark, sizeof(bDark) );
      }

      /* Toolbar buttons */
      {
         struct { const char * txt; int id; int x; int w; } btns[] = {
            { "+ Popup",    MEI_IDC_BPOP, 8,    66 },
            { "+ Item",     MEI_IDC_BITM, 78,   66 },
            { "+ SubItem",  MEI_IDC_BSUB, 148,  74 },
            { "+ Sep",      MEI_IDC_BSEP, 226,  56 },
            { "Up",         MEI_IDC_BUP,  286,  40 },
            { "Down",       MEI_IDC_BDN,  330,  44 },
            { "Delete",     MEI_IDC_BDEL, 378,  56 }
         };
         int i;
         for( i = 0; i < 7; i++ ) {
            CreateWindowExA( 0, "BUTTON", btns[i].txt,
               WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
               btns[i].x, 8, btns[i].w, 26,
               hDlg, (HMENU)(LONG_PTR) btns[i].id, hInst, NULL );
         }
      }

      /* Tree control */
      mei->hTree = CreateWindowExA( WS_EX_CLIENTEDGE, "SysTreeView32", "",
         WS_CHILD | WS_VISIBLE | WS_BORDER | TVS_HASLINES | TVS_LINESATROOT |
         TVS_HASBUTTONS | TVS_SHOWSELALWAYS,
         8, 44, 380, 380,
         hDlg, (HMENU)(LONG_PTR) MEI_IDC_TREE, hInst, NULL );
      if( s_bDarkIDE ) {
         TreeView_SetBkColor( mei->hTree, CLR_EDIT_BG );
         TreeView_SetTextColor( mei->hTree, CLR_EDIT_TEXT );
      }

      /* Right panel */
      CreateWindowExA( 0, "STATIC", "Caption:", WS_CHILD | WS_VISIBLE,
         400, 50, 70, 20, hDlg, NULL, hInst, NULL );
      mei->hCap = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", "",
         WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
         400, 70, 280, 22, hDlg, (HMENU)(LONG_PTR) MEI_IDC_CAP, hInst, NULL );

      CreateWindowExA( 0, "STATIC", "Shortcut:", WS_CHILD | WS_VISIBLE,
         400, 100, 70, 20, hDlg, NULL, hInst, NULL );
      mei->hScut = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", "",
         WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
         400, 120, 280, 22, hDlg, (HMENU)(LONG_PTR) MEI_IDC_SCUT, hInst, NULL );

      CreateWindowExA( 0, "STATIC", "OnClick:", WS_CHILD | WS_VISIBLE,
         400, 150, 70, 20, hDlg, NULL, hInst, NULL );
      mei->hHndl = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", "",
         WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL,
         400, 170, 280, 22, hDlg, (HMENU)(LONG_PTR) MEI_IDC_HNDL, hInst, NULL );

      mei->hEnab = CreateWindowExA( 0, "BUTTON", "Enabled",
         WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
         400, 200, 100, 22, hDlg, (HMENU)(LONG_PTR) MEI_IDC_ENAB, hInst, NULL );

      /* OK / Cancel */
      CreateWindowExA( 0, "BUTTON", "OK",
         WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
         500, 410, 80, 28, hDlg, (HMENU)(LONG_PTR) IDOK, hInst, NULL );
      CreateWindowExA( 0, "BUTTON", "Cancel",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         590, 410, 80, 28, hDlg, (HMENU)(LONG_PTR) IDCANCEL, hInst, NULL );

      /* Apply font */
      {
         HFONT hF = (HFONT) SendMessage( hPar, WM_GETFONT, 0, 0 );
         if( hF ) {
            HWND hChild;
            for( hChild = GetWindow( hDlg, GW_CHILD ); hChild;
                 hChild = GetWindow( hChild, GW_HWNDNEXT ) )
               SendMessage( hChild, WM_SETFONT, (WPARAM) hF, TRUE );
         }
      }

      MEI_RebuildTree( mei );
      if( mei->nCount > 0 ) {
         mei->nSel = 0;
         TreeView_SelectItem( mei->hTree, mei->hItems[0] );
      }
      MEI_LoadSelected( mei );

      EnableWindow( hPar, FALSE );
      ShowWindow( hDlg, SW_SHOW );
      UpdateWindow( hDlg );
      SetForegroundWindow( hDlg );
      SetFocus( mei->hTree );

      while( !bDone && GetMessage( &msg, NULL, 0, 0 ) ) {
         if( !IsWindow( hDlg ) ) { bDone = TRUE; break; }
         if( msg.message == WM_KEYDOWN && msg.wParam == VK_ESCAPE ) {
            mei->bOK = FALSE;
            DestroyWindow( hDlg );
            bDone = TRUE;
            break;
         }
         if( !IsDialogMessageA( hDlg, &msg ) ) {
            TranslateMessage( &msg );
            DispatchMessage( &msg );
         }
      }
      EnableWindow( hPar, TRUE );
      SetForegroundWindow( hPar );
   }

   if( mei->bOK ) {
      char result[4096] = "";
      MEI_Serialize( mei, result, sizeof(result) );
      /* Apply via UI_SetProp directly */
      {
         PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
         if( pDyn ) {
            hb_vmPushDynSym( pDyn ); hb_vmPushNil();
            hb_vmPushNumInt( d->hCtrl );
            hb_vmPushString( "aMenuItems", 10 );
            hb_vmPushString( result, (HB_SIZE) strlen( result ) );
            hb_vmDo( 3 );
         }
      }
      /* Update display in IROW */
      sprintf( d->rows[nReal].szValue, "(%d nodes)", mei->nCount );
      /* Notify IDE: triggers SyncDesignerToCode -> InspectorRefresh */
      if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) ) {
         if( hb_vmRequestReenter() ) {
            hb_vmPushEvalSym();
            hb_vmPush( d->pOnPropChanged );
            hb_vmSend( 0 );
            hb_vmRequestRestore();
         }
      }
      InsRebuild( d );
   }
   free( mei );
   s_pMEI = NULL;
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
         int comboH = 32, tabH = 32, topY = comboH + tabH + 8;
         if( d )
         {
            if( d->hCombo ) MoveWindow( d->hCombo, 2, 2, w - 4, 200, TRUE );
            if( d->hTab )   MoveWindow( d->hTab, 2, comboH + 4, w - 4, tabH + 2, TRUE );
            if( d->hList )
            {
               MoveWindow( d->hList, 0, topY, w, h - topY, TRUE );
               ListView_SetColumnWidth( d->hList, 1, w - COL_NAME_W );
            }
            if( d->hEventList )
            {
               MoveWindow( d->hEventList, 0, topY, w, h - topY, TRUE );
               ListView_SetColumnWidth( d->hEventList, 1, w - COL_NAME_W );
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

      case WM_USER + 202:
         /* Mark the in-place combo as ready; ignores CB_SETCURSEL's spurious CBN_SELCHANGE */
         if( d ) d->bComboReady = TRUE;
         return 0;

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* Enum definitions for dropdown properties.
   bIsString: TRUE means the stored value is one of the strings in aValues
   (e.g. cRDD = "DBFCDX"); FALSE means the stored value is the numeric
   index into aValues (legacy behavior). */
typedef struct { const char * szPropName; const char ** aValues; int nCount; BOOL bIsString; } ENUMDEF;

static const char * s_borderStyle[] = { "bsNone", "bsSingle", "bsSizeable", "bsDialog", "bsToolWindow", "bsSizeToolWin" };
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
static const char * s_cRdd[]        = { "DBFCDX", "DBFNTX", "DBFFPT" };
static const char * s_bandType[]    = { "Header", "PageHeader", "Detail", "PageFooter", "Footer" };
static const char * s_controlAlign[] = { "alNone", "alTop", "alBottom", "alLeft", "alRight", "alClient" };

/* Shared dropdown for all PT_LOGICAL properties: "No" / "Yes" */
static const char * s_logical[]     = { "No", "Yes" };

static ENUMDEF s_enums[] = {
   { "nBorderStyle",  s_borderStyle,  6, FALSE },
   { "nBorderIcons",  s_borderIcons,  8, FALSE },
   { "nPosition",     s_position,     3, FALSE },
   { "nWindowState",  s_windowState,  3, FALSE },
   { "nFormStyle",    s_formStyle,    2, FALSE },
   { "nCursor",       s_cursor,       9, FALSE },
   { "nBevelStyle",   s_bevelStyle,   2, FALSE },
   { "nBevelOuter",   s_bevelOuter,   3, FALSE },
   { "nAlignment",    s_alignment,    3, FALSE },
   { "nScrollBars",   s_scrollBars,   4, FALSE },
   { "nShapeType",    s_shapeType,    4, FALSE },
   { "nViewStyle",    s_viewStyle,    4, FALSE },
   { "cRDD",          s_cRdd,         3, TRUE  },
   { "cBandType",     s_bandType,     5, TRUE  },
   { "nControlAlign", s_controlAlign, 6, FALSE },
   { NULL, NULL, 0, FALSE }
};

/* Synthetic Yes/No enum returned for any PT_LOGICAL row regardless
   of property name. bIsString is TRUE-ish but the end-edit path
   special-cases it (stores ".T." / ".F." into szValue). */
static ENUMDEF s_boolEnum = { "(logical)", s_logical, 2, FALSE };

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
   BOOL bNeedsBtn;

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

   /* Dropdown path: either a named enum, a string enum, or any
      PT_LOGICAL property which all get a synthetic Yes/No picker.
      We use TrackPopupMenu (same as the boolean handler) to avoid
      in-place ComboBox focus fights with the ListView parent. */
   pEnum = InsGetEnum( d->rows[nReal].szName );
   if( !pEnum && d->rows[nReal].cType == 'L' )
      pEnum = &s_boolEnum;
   if( pEnum )
   {
      HMENU hMenu = CreatePopupMenu();
      POINT pt;
      int i, nSel = -1, nCmd;
      char szVal[256];
      /* Compute current selection index for checkmark */
      if( d->rows[nReal].cType == 'L' )
         nSel = ( lstrcmpiA( d->rows[nReal].szValue, ".T." ) == 0 ) ? 1 : 0;
      else if( pEnum->bIsString )
      {
         for( i = 0; i < pEnum->nCount; i++ )
            if( lstrcmpiA( d->rows[nReal].szValue, pEnum->aValues[i] ) == 0 )
               { nSel = i; break; }
      }
      else
         nSel = atoi( d->rows[nReal].szValue );
      for( i = 0; i < pEnum->nCount; i++ )
         AppendMenuA( hMenu, MF_STRING, i + 1, pEnum->aValues[i] );
      if( nSel >= 0 && nSel < pEnum->nCount )
         CheckMenuItem( hMenu, nSel + 1, MF_CHECKED );
      pt.x = rc.left; pt.y = rc.bottom;
      ClientToScreen( d->hList, &pt );
      d->nEditRow = -1;  /* no in-place control */
      nCmd = TrackPopupMenu( hMenu, TPM_RETURNCMD | TPM_NONOTIFY, pt.x, pt.y, 0, d->hWnd, NULL );
      DestroyMenu( hMenu );
      if( nCmd > 0 )
      {
         nSel = nCmd - 1;
         if( d->rows[nReal].cType == 'L' )
            lstrcpyA( szVal, nSel == 1 ? ".T." : ".F." );
         else if( pEnum->bIsString )
            lstrcpynA( szVal, pEnum->aValues[nSel], sizeof(szVal) );
         else
            sprintf( szVal, "%d", nSel );
         lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
         InsApplyValue( d, nReal, szVal );
         InsRebuild( d );
      }
      return;
   }

   /* Rows that need a "..." picker button next to the edit:
      - cType 'C' (color), 'F' (font), 'A' (array) as before
      - cType 'S' with name cFileName  -> file open dialog
      - cType 'S' other names          -> multiline text editor (ShowMLEditDialog)
      Declared at top-of-function above to keep BCC happy (C89). */
   bNeedsBtn = ( d->rows[nReal].cType == 'C' ||
                 d->rows[nReal].cType == 'F' ||
                 d->rows[nReal].cType == 'A' ||
                 d->rows[nReal].cType == 'M' ||
                 d->rows[nReal].cType == 'S' );
   nBtnW = bNeedsBtn ? 22 : 0;
   { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
     if(f){fprintf(f,"  bNeedsBtn=%d nBtnW=%d\n",(int)bNeedsBtn,nBtnW);fclose(f);} }

   d->hEdit = CreateWindowExA( 0, "EDIT", d->rows[nReal].szValue,
      WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, rc.left, rc.top, rc.right-rc.left-nBtnW, rc.bottom-rc.top,
      d->hList, NULL, GetModuleHandle(NULL), NULL );
   SendMessage( d->hEdit, WM_SETFONT, (WPARAM) d->hFont, TRUE );
   SendMessage( d->hEdit, EM_SETSEL, 0, -1 );
   SetFocus( d->hEdit );
   SetPropA( d->hEdit, "InsData", (HANDLE) d );
   d->oldEditProc = (WNDPROC) SetWindowLongPtr( d->hEdit, GWLP_WNDPROC, (LONG_PTR) InsEditProc );

   if( bNeedsBtn )
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
      BOOL bBoolEnum = ( !pEnum && d->rows[nReal].cType == 'L' );
      if( pEnum || bBoolEnum )
      {
         int nSel = (int) SendMessage( d->hEdit, CB_GETCURSEL, 0, 0 );
         { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
           if(f){fprintf(f,"  END COMBO prop='%s' bApply=1 bBool=%d bIsString=%d nSel=%d\n",
             d->rows[nReal].szName, bBoolEnum,
             pEnum ? pEnum->bIsString : -1, nSel); fclose(f);} }
         if( nSel >= 0 ) {
            if( bBoolEnum )
               lstrcpyA( szVal, nSel == 1 ? ".T." : ".F." );
            else if( pEnum->bIsString )
               lstrcpynA( szVal, pEnum->aValues[nSel], sizeof(szVal) );
            else
               sprintf( szVal, "%d", nSel );
            { FILE*f=fopen("c:\\HarbourBuilder\\inspector_trace.log","a");
              if(f){fprintf(f,"  END COMBO writing szVal='%s'\n", szVal); fclose(f);} }
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

   /* Folder page view: the Harbour side of the combo handler cleared
      rows, pushed 2 synthetic entries (cCaption, nPage) via INS_AddRow
      and set nFolderPage before calling InsRebuild. Don't clobber them. */
   if( d->nFolderPage >= 0 && d->nRows > 0 )
      return;

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
         else if( d->rows[d->nRows].cType == 'M' )
         {
            /* Menu serial may exceed 256; store "(N nodes)" summary.
               Editor fetches full string via UI_GetProp directly. */
            const char * raw = hb_arrayGetCPtr(pRow,2);
            int cnt = 0;
            if( raw && raw[0] ) {
               const char * pp; cnt = 1;
               for( pp = raw; *pp; pp++ ) if( *pp == '|' ) cnt++;
            }
            sprintf( d->rows[d->nRows].szValue, "(%d nodes)", cnt );
         }

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
               ENUMDEF * pE = InsGetEnum( d->rows[i].szName );
               if( pE && !pE->bIsString ) {
                  int idx = atoi( d->rows[i].szValue );
                  lvi.pszText = ( idx >= 0 && idx < pE->nCount )
                                ? (char *) pE->aValues[idx]
                                : d->rows[i].szValue;
               } else {
                  lvi.pszText = d->rows[i].szValue;
               }
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
            } else {
               ENUMDEF * pE = InsGetEnum( d->rows[i].szName );
               if( pE && !pE->bIsString ) {
                  int idx = atoi( d->rows[i].szValue );
                  if( idx >= 0 && idx < pE->nCount )
                     pDisp = (char *) pE->aValues[idx];
               }
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
   int comboH = 32, tabH = 32, topY;

   d = (INSDATA *) malloc( sizeof(INSDATA) );
   memset( d, 0, sizeof(INSDATA) );
   d->nEditRow = -1;
   d->hBtn = NULL;
   d->nActiveTab = 0;
   d->hFormCtrl = 0;
   d->nBrowseCol = -1;
   d->nFolderPage = -1;
   d->pOnComboSel = NULL;
   d->pOnEventDblClick = NULL;
   d->pOnPropChanged = NULL;

   { LOGFONTA lf = {0};
     /* Scale font + name-column width by current system DPI with a 50%
        dampening factor so they grow with DPI but don't dominate
        (font 13pt -> 17pt at 200% DPI; col 205 -> 308 at 200%). */
     int sysDpi = 96;
     { HDC hScreen = GetDC( NULL );
       sysDpi = GetDeviceCaps( hScreen, LOGPIXELSY );
       ReleaseDC( NULL, hScreen ); }
     int dampedDpi = 96 + ( sysDpi - 96 ) / 2;  /* 96 at 96, 144 at 192 */
     if( dampedDpi < 96 ) dampedDpi = 96;
     lf.lfHeight = -MulDiv( 13, dampedDpi, 72 );
     lf.lfCharSet = DEFAULT_CHARSET;
     lstrcpyA(lf.lfFaceName, "Segoe UI");
     d->hFont = CreateFontIndirectA(&lf);
     lf.lfWeight = FW_BOLD; d->hBold = CreateFontIndirectA(&lf);
     s_colNameW = MulDiv( 205, dampedDpi, 96 ); }

   d->hBrush = CreateSolidBrush( CLR_WND_BG );

   if( !bReg ) {
      wc.lpfnWndProc = InsWndProc; wc.hInstance = GetModuleHandle(NULL);
      wc.hCursor = LoadCursor(NULL,IDC_ARROW); wc.hbrBackground = d->hBrush;
      wc.lpszClassName = "HbIdeInspector"; RegisterClassA(&wc); bReg = TRUE;
   }

   { INITCOMMONCONTROLSEX ic = { sizeof(ic),
        ICC_LISTVIEW_CLASSES | ICC_TAB_CLASSES | ICC_TREEVIEW_CLASSES };
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
   d->nFolderPage = -1; /* reset; INS_SetFolderPage sets it after */
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
         else if( d->rows[d->nRows].cType == 'M' )
         {
            /* Menu serial may exceed 256; store "(N nodes)" summary.
               Editor fetches full string via UI_GetProp directly. */
            const char * raw = hb_arrayGetCPtr(pRow,2);
            int cnt = 0;
            if( raw && raw[0] ) {
               const char * pp; cnt = 1;
               for( pp = raw; *pp; pp++ ) if( *pp == '|' ) cnt++;
            }
            sprintf( d->rows[d->nRows].szValue, "(%d nodes)", cnt );
         }

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

/* INS_SetFolderPage( hInsData, hFolder, nPageIdx ) - switch inspector to
   "TFolderPage" view. Clears existing rows; next InsRebuild will honor
   nFolderPage >= 0 and not overwrite the rows Harbour pushed via
   INS_AddRow. hFolder is stored as d->hCtrl so the caller can keep
   editing folder-level state. */
HB_FUNC( INS_SETFOLDERPAGE )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   d->hCtrl = (HB_PTRUINT) hb_parnint(2);
   d->nFolderPage = HB_ISNUM(3) ? hb_parni(3) : -1;
   d->nRows = 0;
}

/* INS_AddRow( hInsData, cName, cValue, cCategory, cType ) - append one
   synthetic row to the inspector. Used for folder-page view; Harbour
   drives the layout, then calls InsRebuild. */
HB_FUNC( INS_ADDROW )
{
   INSDATA * d;
   IROW * r;
   d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d || d->nRows >= MAX_ROWS - 1 ) return;

   r = &d->rows[d->nRows++];
   lstrcpynA( r->szName,     HB_ISCHAR(2) ? hb_parc(2) : "", 32 );
   lstrcpynA( r->szValue,    HB_ISCHAR(3) ? hb_parc(3) : "", 256 );
   lstrcpynA( r->szCategory, HB_ISCHAR(4) ? hb_parc(4) : "General", 32 );
   r->cType = ( HB_ISCHAR(5) && hb_parc(5)[0] ) ? hb_parc(5)[0] : 'S';
   r->bIsCat = FALSE;
   r->bCollapsed = FALSE;
   r->bVisible = TRUE;
}

/* INS_AddCategoryRow( hInsData, cName ) - header/divider row */
HB_FUNC( INS_ADDCATEGORYROW )
{
   INSDATA * d;
   IROW * r;
   d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d || d->nRows >= MAX_ROWS - 1 ) return;

   r = &d->rows[d->nRows++];
   lstrcpynA( r->szName,     HB_ISCHAR(2) ? hb_parc(2) : "", 32 );
   r->szValue[0] = 0;
   lstrcpynA( r->szCategory, HB_ISCHAR(2) ? hb_parc(2) : "", 32 );
   r->cType = 0;
   r->bIsCat = TRUE;
   r->bCollapsed = FALSE;
   r->bVisible = TRUE;
}

/* INS_Rebuild( hInsData ) - refresh layout after Harbour pushes rows */
HB_FUNC( INS_REBUILD )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( d ) InsRebuild( d );
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

/* INS_GetCurrentCtrl( hInsData ) - return currently displayed control handle */
HB_FUNC( INS_GETCURRENTCTRL )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   hb_retnint( d ? (HB_PTRUINT) d->hCtrl : 0 );
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
