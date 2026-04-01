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
   if( msg == WM_KEYDOWN && wParam == VK_RETURN ) { InsEndEdit( d, TRUE ); return 0; }
   if( msg == WM_KEYDOWN && wParam == VK_ESCAPE ) { InsEndEdit( d, FALSE ); return 0; }
   if( msg == WM_KILLFOCUS ) { if( d->hBtn && (HWND)wParam == d->hBtn ) return 0; InsEndEdit( d, TRUE ); return 0; }
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
         /* Deferred combo selection - safe to call Harbour VM here */
         if( d && d->hFormCtrl )
         {
            int sel = (int) wParam;
            HB_PTRUINT hTarget = d->hFormCtrl;  /* sel 0 = form */
            PHB_DYNS pDyn;

            INSLOG( "ComboSel: sel=%d hFormCtrl=%p", sel, (void*)(LONG_PTR)d->hFormCtrl );

            if( sel > 0 )
            {
               /* Get child handle via HB_FUNC call */
               pDyn = hb_dynsymFind( "UI_GETCHILD" );
               INSLOG( "  UI_GETCHILD dynsym=%p", (void*)pDyn );
               if( pDyn )
               {
                  hb_vmPushDynSym( pDyn );
                  hb_vmPushNil();
                  hb_vmPushNumInt( (HB_MAXINT) d->hFormCtrl );
                  hb_vmPushInteger( sel );
                  hb_vmDo( 2 );
                  hTarget = (HB_PTRUINT) hb_itemGetNInt( hb_stackReturnItem() );
                  INSLOG( "  UI_GETCHILD result: hTarget=%p", (void*)(LONG_PTR)hTarget );
               }
            }

            if( hTarget )
            {
               d->hCtrl = hTarget;

               /* Select control in design form */
               pDyn = hb_dynsymFind( "UI_FORMSELECTCTRL" );
               INSLOG( "  UI_FORMSELECTCTRL dynsym=%p", (void*)pDyn );
               if( pDyn )
               {
                  hb_vmPushDynSym( pDyn );
                  hb_vmPushNil();
                  hb_vmPushNumInt( (HB_MAXINT) d->hFormCtrl );
                  hb_vmPushNumInt( (HB_MAXINT) hTarget );
                  hb_vmDo( 2 );
                  INSLOG( "  UI_FORMSELECTCTRL done" );
               }

               /* Refresh inspector properties */
               pDyn = hb_dynsymFind( "INSPECTORREFRESH" );
               INSLOG( "  INSPECTORREFRESH dynsym=%p", (void*)pDyn );
               if( pDyn )
               {
                  hb_vmPushDynSym( pDyn );
                  hb_vmPushNil();
                  hb_vmPushNumInt( (HB_MAXINT) hTarget );
                  hb_vmDo( 1 );
                  INSLOG( "  INSPECTORREFRESH done" );
               }
            }
            INSLOG( "ComboSel: complete" );
         }
         return 0;
      }

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

static void InsStartEdit( INSDATA * d, int nLVRow )
{
   RECT rc;
   int nReal, nBtnW;
   if( d->hEdit ) InsEndEdit( d, FALSE );
   if( nLVRow < 0 || nLVRow >= d->nVisible ) return;
   nReal = d->map[nLVRow];
   d->nEditRow = nLVRow;
   ListView_GetSubItemRect( d->hList, nLVRow, 1, LVIR_LABEL, &rc );

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

static void InsEndEdit( INSDATA * d, BOOL bApply )
{
   char szVal[256];
   int nReal;
   if( !d->hEdit || d->nEditRow < 0 ) return;
   nReal = d->map[d->nEditRow];
   if( bApply )
   {
      GetWindowTextA( d->hEdit, szVal, sizeof(szVal) );
      lstrcpynA( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) );
      InsApplyValue( d, nReal, szVal );
      InsRebuild( d );
   }
   if( d->hBtn ) { DestroyWindow( d->hBtn ); d->hBtn = NULL; }
   DestroyWindow( d->hEdit );
   d->hEdit = NULL;
   d->nEditRow = -1;
}

static void InsApplyValue( INSDATA * d, int nReal, const char * szVal )
{
   PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
   if( !pDyn ) return;
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
      0, 130, 220, 500,
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
   lvc.cx = 100; lvc.pszText = "Value";
   SendMessageA( d->hList, LVM_INSERTCOLUMNA, 1, (LPARAM) &lvc );

   /* Events ListView (hidden by default) */
   d->hEventList = CreateWindowExA( 0, WC_LISTVIEWA, "",
      WS_CHILD | LVS_REPORT | LVS_SINGLESEL | LVS_SHOWSELALWAYS | LVS_NOCOLUMNHEADER,
      0, topY, 215, 440 - topY, d->hWnd, (HMENU)103, GetModuleHandle(NULL), NULL );

   SendMessage( d->hEventList, LVM_SETEXTENDEDLISTVIEWSTYLE, 0,
      LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES | LVS_EX_DOUBLEBUFFER );
   SendMessage( d->hEventList, WM_SETFONT, (WPARAM) d->hFont, TRUE );

   lvc.cx = COL_NAME_W; lvc.pszText = "Event";
   SendMessageA( d->hEventList, LVM_INSERTCOLUMNA, 0, (LPARAM) &lvc );
   lvc.cx = 100; lvc.pszText = "Handler";
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

/* INS_BringToFront( hInsData ) */
/* Populate the Events tab with available events for the current control */
static void InsPopulateEvents( INSDATA * d )
{
   LVITEMA lvi = {0};
   static const char * aEvents[] = { "OnClick", "OnChange", "OnInit", "OnClose" };
   int i, nEvents = 4;

   if( !d || !d->hEventList ) return;

   SendMessage( d->hEventList, LVM_DELETEALLITEMS, 0, 0 );

   for( i = 0; i < nEvents; i++ )
   {
      lvi.mask = LVIF_TEXT;
      lvi.iItem = i;
      lvi.iSubItem = 0;
      lvi.pszText = (char *) aEvents[i];
      SendMessageA( d->hEventList, LVM_INSERTITEMA, 0, (LPARAM) &lvi );

      /* Show handler name if set (placeholder for now) */
      lvi.iSubItem = 1;
      lvi.pszText = "";
      SendMessageA( d->hEventList, LVM_SETITEMA, 0, (LPARAM) &lvi );
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
HB_FUNC( INS_DESTROY )
{
   INSDATA * d = (INSDATA *) (HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   if( d->hWnd ) DestroyWindow( d->hWnd );
   DeleteObject( d->hFont );
   DeleteObject( d->hBold );
   DeleteObject( d->hBrush );
   free( d );
}

#pragma ENDDUMP
