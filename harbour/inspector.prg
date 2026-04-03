// inspector.prg - Live Property Grid Inspector (non-modal)

function InspectorOpen()
   if _InsGetData() == 0
      _InsSetData( INS_Create() )
   endif
return nil

function InspectorRefresh( hCtrl, hForm )
   local h := _InsGetData()
   local aProps
   if h != 0
      if hCtrl != nil .and. hCtrl != 0
         aProps := UI_GetAllProps( hCtrl )
         INS_RefreshWithData( h, hCtrl, aProps )
      else
         INS_RefreshWithData( h, 0, {} )
      endif
   endif
return nil

// Populate combo with all controls from the design form
function InspectorPopulateCombo( hForm )
   local h := _InsGetData()
   local i, nCount, hChild, cName, cClass, cEntry

   if h == 0 .or. hForm == 0
      return nil
   endif

   INS_ComboClear( h )
   INS_SetFormCtrl( h, hForm )

   // Add the form itself
   cName  := UI_GetProp( hForm, "cName" )
   cClass := UI_GetProp( hForm, "cClassName" )
   if Empty( cName ); cName := "Form1"; endif
   cEntry := cName + " AS " + cClass
   INS_ComboAdd( h, cEntry )

   // Add all child controls
   nCount := UI_GetChildCount( hForm )
   for i := 1 to nCount
      hChild := UI_GetChild( hForm, i )
      if hChild != 0
         cName  := UI_GetProp( hChild, "cName" )
         cClass := UI_GetProp( hChild, "cClassName" )
         if Empty( cName ); cName := "ctrl" + LTrim( Str( i ) ); endif
         cEntry := cName + " AS " + cClass
         INS_ComboAdd( h, cEntry )
      endif
   next

   // Select current control in combo
   INS_ComboSelect( h, 0 )

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
static HB_PTRUINT s_insData = 0;
HB_FUNC( _INSGETDATA ) { hb_retnint( s_insData ); }
HB_FUNC( _INSSETDATA ) { s_insData = (HB_PTRUINT) hb_parnint(1); }
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
#include <stdarg.h>

#define MAX_ROWS 64
#define COL_NAME_W 95

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
      return r;
   }
   return CallWindowProc( oldProc, hWnd, msg, wParam, lParam );
}

static LRESULT CALLBACK InsEditProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   INSDATA * d = (INSDATA *) GetPropA( hWnd, "InsData" );
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
   else        lf.lfHeight = -12;
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

static LRESULT CALLBACK InsWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   INSDATA * d = (INSDATA *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   switch( msg )
   {
      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         int comboH = 24, tabH = 24, topY = comboH + tabH + 8;
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
                     pcd->clrTextBk = GetSysColor( COLOR_BTNFACE );
                     pcd->clrText = GetSysColor( COLOR_BTNTEXT );
                     SelectObject( pcd->nmcd.hdc, d->hBold );
                     return CDRF_NEWFONT;
                  }
                  pcd->clrTextBk = ( nRow % 2 ) ? RGB(248,248,248) : RGB(255,255,255);
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
                     pcd->clrTextBk = GetSysColor( COLOR_BTNFACE );
                     pcd->clrText = GetSysColor( COLOR_BTNTEXT );
                     SelectObject( pcd->nmcd.hdc, d->hBold );
                     return CDRF_NEWFONT;
                  }
                  pcd->clrTextBk = ( pcd->nmcd.dwItemSpec % 2 )
                     ? RGB(248,248,248) : RGB(255,255,255);
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
                  /* Mark as collapsed */
                  lviCheck.mask = LVIF_PARAM;
                  lviCheck.iItem = pe->iItem;
                  lviCheck.lParam = 2;
                  SendMessageA( d->hEventList, LVM_SETITEMA, 0, (LPARAM) &lviCheck );
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
            else
            {
               ShowWindow( d->hList, SW_HIDE );
               ShowWindow( d->hEventList, SW_SHOW );
               InsPopulateEvents( d );
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

static ENUMDEF s_enums[] = {
   { "nBorderStyle",  s_borderStyle,  4 },
   { "nPosition",     s_position,     3 },
   { "nWindowState",  s_windowState,  3 },
   { "nFormStyle",    s_formStyle,    2 },
   { "nCursor",       s_cursor,       9 },
   { "nBevelStyle",   s_bevelStyle,   2 },
   { "nAlignment",    s_alignment,    3 },
   { "nScrollBars",   s_scrollBars,   4 },
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

   if( !d ) return;
   if( d->hEdit ) InsEndEdit( d, FALSE );
   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];
   if( nReal < 0 || nReal >= d->nRows ) return;
   if( d->rows[nReal].bIsCat ) return;  /* don't edit category rows */
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

   nBtnW = ( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' ) ? 22 : 0;

   d->hEdit = CreateWindowExA( 0, "EDIT", d->rows[nReal].szValue,
      WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, rc.left, rc.top, rc.right-rc.left-nBtnW, rc.bottom-rc.top,
      d->hList, NULL, GetModuleHandle(NULL), NULL );
   SendMessage( d->hEdit, WM_SETFONT, (WPARAM) d->hFont, TRUE );
   SendMessage( d->hEdit, EM_SETSEL, 0, -1 );
   SetFocus( d->hEdit );
   SetPropA( d->hEdit, "InsData", (HANDLE) d );
   d->oldEditProc = (WNDPROC) SetWindowLongPtr( d->hEdit, GWLP_WNDPROC, (LONG_PTR) InsEditProc );

   /* Color/Font property: add "..." button to the right */
   if( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' )
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
      InsRebuild( d );
   }
   if( d->hBtn ) { DestroyWindow( d->hBtn ); d->hBtn = NULL; }
   DestroyWindow( d->hEdit );
   d->hEdit = NULL;
   d->nEditRow = -1;
}

static void InsApplyValue( INSDATA * d, int nReal, const char * szVal )
{
   PHB_DYNS pDyn;
   char logBuf[256];
   sprintf( logBuf, "InsApplyValue: nReal=%d name='%s' type='%c' val='%s' hCtrl=%p",
      nReal, d->rows[nReal].szName, d->rows[nReal].cType, szVal, (void*)(size_t)d->hCtrl );
   InsLog( logBuf );

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
   else
      hb_vmPushNil();
   hb_vmDo( 3 );
   InsLog( "  -> hb_vmDo(3) returned OK" );

   /* Notify IDE that a property changed */
   if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) )
   {
      InsLog( "  -> firing pOnPropChanged" );
      hb_vmPush( d->pOnPropChanged );
      hb_vmPushNil();
      hb_vmDo( 0 );
   }
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
            lvi.pszText = d->rows[i].szValue;
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
            ListView_GetItemText( d->hList, nVis, 1, szOld, sizeof(szOld) );
            if( lstrcmpA( szOld, d->rows[i].szValue ) != 0 )
               ListView_SetItemText( d->hList, nVis, 1, d->rows[i].szValue );
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
   int comboH = 24, tabH = 24, topY;

   d = (INSDATA *) malloc( sizeof(INSDATA) );
   memset( d, 0, sizeof(INSDATA) );
   d->nEditRow = -1;
   d->hBtn = NULL;
   d->nActiveTab = 0;
   d->hFormCtrl = 0;
   d->pOnComboSel = NULL;
   d->pOnEventDblClick = NULL;
   d->pOnPropChanged = NULL;

   { LOGFONTA lf = {0}; lf.lfHeight = -12; lf.lfCharSet = DEFAULT_CHARSET;
     lstrcpyA(lf.lfFaceName, "Segoe UI");
     d->hFont = CreateFontIndirectA(&lf);
     lf.lfWeight = FW_BOLD; d->hBold = CreateFontIndirectA(&lf); }

   d->hBrush = CreateSolidBrush( GetSysColor(COLOR_BTNFACE) );

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
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
      2, comboH + 4, 200, tabH + 2,
      d->hWnd, (HMENU)102, GetModuleHandle(NULL), NULL );
   SendMessage( d->hTab, WM_SETFONT, (WPARAM) d->hFont, TRUE );

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
   lvi.mask = LVIF_TEXT | LVIF_PARAM;
   lvi.iItem = nRow;
   lvi.iSubItem = 0;
   lvi.pszText = (char *) szCat;
   lvi.lParam = 1;  /* 1 = category row */
   SendMessageA( d->hEventList, LVM_INSERTITEMA, 0, (LPARAM) &lvi );
}

/* Add one event row to the Events ListView */
static void InsAddEvent( INSDATA * d, int nRow, const char * szEvent )
{
   LVITEMA lvi = {0};
   lvi.mask = LVIF_TEXT | LVIF_PARAM;
   lvi.iItem = nRow;
   lvi.iSubItem = 0;
   lvi.pszText = (char *) szEvent;
   lvi.lParam = 0;  /* 0 = event row */
   SendMessageA( d->hEventList, LVM_INSERTITEMA, 0, (LPARAM) &lvi );
   lvi.iSubItem = 1;
   lvi.pszText = "";
   SendMessageA( d->hEventList, LVM_SETITEMA, 0, (LPARAM) &lvi );
}

static void InsPopulateEvents( INSDATA * d )
{
   int nType, n = 0;
   PHB_DYNS pDyn;

   if( !d || !d->hEventList ) return;
   SendMessage( d->hEventList, LVM_DELETEALLITEMS, 0, 0 );
   if( d->hCtrl == 0 ) return;

   /* Get control type via UI_GetType */
   pDyn = hb_dynsymFindName( "UI_GETTYPE" );
   if( !pDyn ) {
      /* Fallback: show basic events */
      InsAddEvent( d, 0, "OnClick" );
      InsAddEvent( d, 1, "OnChange" );
      InsAddEvent( d, 2, "OnInit" );
      InsAddEvent( d, 3, "OnClose" );
      return;
   }

   hb_vmPushDynSym( pDyn ); hb_vmPushNil();
   hb_vmPushNumInt( d->hCtrl );
   hb_vmDo( 1 );
   nType = hb_itemGetNI( hb_stackReturnItem() );

   /* Show events based on control type */
   switch( nType )
   {
      case 0: /* CT_FORM */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEventCat(d, n++, "Lifecycle");
         InsAddEvent(d, n++, "OnCreate");
         InsAddEvent(d, n++, "OnDestroy");
         InsAddEvent(d, n++, "OnShow");
         InsAddEvent(d, n++, "OnHide");
         InsAddEvent(d, n++, "OnClose");
         InsAddEvent(d, n++, "OnCloseQuery");
         InsAddEvent(d, n++, "OnActivate");
         InsAddEvent(d, n++, "OnDeactivate");
         InsAddEventCat(d, n++, "Layout");
         InsAddEvent(d, n++, "OnResize");
         InsAddEvent(d, n++, "OnPaint");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         InsAddEvent(d, n++, "OnKeyUp");
         InsAddEvent(d, n++, "OnKeyPress");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         InsAddEvent(d, n++, "OnMouseUp");
         InsAddEvent(d, n++, "OnMouseMove");
         InsAddEvent(d, n++, "OnMouseWheel");
         break;
      case 3: /* CT_BUTTON */
      case 12: /* CT_BITBTN */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEventCat(d, n++, "Focus");
         InsAddEvent(d, n++, "OnEnter");
         InsAddEvent(d, n++, "OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         break;
      case 2: /* CT_EDIT */
      case 24: /* CT_MEMO */
      case 23: /* CT_RICHEDIT */
      case 28: /* CT_MASKEDIT */
      case 32: /* CT_LABELEDEDIT */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnChange");
         InsAddEvent(d, n++, "OnClick");
         InsAddEventCat(d, n++, "Focus");
         InsAddEvent(d, n++, "OnEnter");
         InsAddEvent(d, n++, "OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         InsAddEvent(d, n++, "OnKeyUp");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         break;
      case 4: /* CT_CHECKBOX */
      case 8: /* CT_RADIO */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEventCat(d, n++, "Focus");
         InsAddEvent(d, n++, "OnEnter");
         InsAddEvent(d, n++, "OnExit");
         break;
      case 5: /* CT_COMBOBOX */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnChange");
         InsAddEvent(d, n++, "OnClick");
         InsAddEventCat(d, n++, "Focus");
         InsAddEvent(d, n++, "OnEnter");
         InsAddEvent(d, n++, "OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         break;
      case 1: /* CT_LABEL */
      case 31: /* CT_STATICTEXT */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         break;
      case 6: /* CT_GROUPBOX */
      case 25: /* CT_PANEL */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEventCat(d, n++, "Layout");
         InsAddEvent(d, n++, "OnResize");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         break;
      case 7: /* CT_LISTBOX */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEvent(d, n++, "OnChange");
         InsAddEventCat(d, n++, "Focus");
         InsAddEvent(d, n++, "OnEnter");
         InsAddEvent(d, n++, "OnExit");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         break;
      case 20: /* CT_TREEVIEW */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEvent(d, n++, "OnChange");
         InsAddEvent(d, n++, "OnExpand");
         InsAddEvent(d, n++, "OnCollapse");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         break;
      case 21: /* CT_LISTVIEW */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEvent(d, n++, "OnChange");
         InsAddEvent(d, n++, "OnColumnClick");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         break;
      case 79: case 80: /* CT_BROWSE, CT_DBGRID */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnCellClick");
         InsAddEvent(d, n++, "OnCellDblClick");
         InsAddEvent(d, n++, "OnHeaderClick");
         InsAddEvent(d, n++, "OnSort");
         InsAddEvent(d, n++, "OnScroll");
         InsAddEvent(d, n++, "OnRowSelect");
         InsAddEventCat(d, n++, "Data");
         InsAddEvent(d, n++, "OnCellEdit");
         InsAddEventCat(d, n++, "Layout");
         InsAddEvent(d, n++, "OnColumnResize");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         break;
      case 39: /* CT_PAINTBOX */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnPaint");
         InsAddEvent(d, n++, "OnClick");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         InsAddEvent(d, n++, "OnMouseUp");
         InsAddEvent(d, n++, "OnMouseMove");
         InsAddEventCat(d, n++, "Layout");
         InsAddEvent(d, n++, "OnResize");
         break;
      case 38: /* CT_TIMER */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnTimer");
         break;
      case 22: /* CT_PROGRESSBAR */
         break; /* no user events */
      case 34: /* CT_TRACKBAR */
      case 26: /* CT_SCROLLBAR */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnChange");
         InsAddEvent(d, n++, "OnScroll");
         break;
      case 33: /* CT_TABCONTROL */
      case 35: /* CT_UPDOWN */
      case 36: /* CT_DATETIMEPICKER */
      case 37: /* CT_MONTHCALENDAR */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnChange");
         InsAddEvent(d, n++, "OnClick");
         break;
      case 14: /* CT_IMAGE */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnDblClick");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         break;
      default:
         /* Generic events for all other controls */
         InsAddEventCat(d, n++, "Action");
         InsAddEvent(d, n++, "OnClick");
         InsAddEvent(d, n++, "OnChange");
         InsAddEventCat(d, n++, "Keyboard");
         InsAddEvent(d, n++, "OnKeyDown");
         InsAddEventCat(d, n++, "Mouse");
         InsAddEvent(d, n++, "OnMouseDown");
         break;
   }
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
