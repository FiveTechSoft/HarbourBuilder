/*
 * hbbridge.cpp - Harbour ↔ C++ bridge functions
 * Exposes TForm, TControl, TButton etc. to Harbour via HB_FUNC.
 *
 * Usage from Harbour:
 *   hForm := UI_FormNew( "Title", 471, 405 )
 *   hBtn  := UI_ButtonNew( hForm, "Click", 170, 326, 88, 26 )
 *   UI_SetProp( hBtn, "Default", .T. )
 *   UI_FormRun( hForm )
 */

/* Prevent windows.h from including old winsock.h (we need winsock2.h) */
#define _WINSOCKAPI_
#include "hbide.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <string.h>

#pragma comment(lib, "ws2_32.lib")

/* DPI awareness + dark mode - must be called before any window is created */
/* C++ static initializer runs before main() and before Harbour VM */
static struct _DpiInit {
   _DpiInit() {
      SetProcessDPIAware();
      /* Enable dark menus/scrollbars on Win10 1903+ / Win11 */
      HMODULE hUx = LoadLibraryA("uxtheme.dll");
      if( hUx ) {
         /* SetPreferredAppMode: 0=Default, 1=AllowDark, 2=ForceDark, 3=ForceLight */
         typedef int (WINAPI *fnSPAM)(int);
         fnSPAM pfn = (fnSPAM) GetProcAddress(hUx, MAKEINTRESOURCEA(135));
         if( pfn ) pfn( 2 ); /* ForceDark */

         /* RefreshImmersiveColorPolicyState */
         typedef void (WINAPI *fnRefresh)(void);
         fnRefresh pfnR = (fnRefresh) GetProcAddress(hUx, MAKEINTRESOURCEA(104));
         if( pfnR ) pfnR();

         FreeLibrary( hUx );
      }
   }
} _s_dpiInit;

HB_FUNC( SETDPIAWARE )
{
   SetProcessDPIAware();
}

/* W32_InvalidateWindow( hWnd ) - force full repaint including children */
static BOOL CALLBACK _InvalidateChild( HWND h, LPARAM lp )
{
   (void)lp;
   InvalidateRect( h, NULL, TRUE );
   return TRUE;
}

HB_FUNC( W32_INVALIDATEWINDOW )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   if( hWnd )
   {
      InvalidateRect( hWnd, NULL, TRUE );
      UpdateWindow( hWnd );
      EnumChildWindows( hWnd, _InvalidateChild, 0 );
   }
}

/* UI_MsgBox - cross-platform message box */
HB_FUNC( UI_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1),
      HB_ISCHAR(2) ? hb_parc(2) : "HbBuilder",
      MB_OK | MB_ICONINFORMATION );
}

/* Helper: get TControl pointer from Harbour handle */
static TControl * GetCtrl( int nParam )
{
   return (TControl *) (LONG_PTR) hb_parnint( nParam );
}

static TForm * GetForm( int nParam )
{
   return (TForm *) (LONG_PTR) hb_parnint( nParam );
}

/* Return handle to Harbour */
static void RetCtrl( TControl * p )
{
   hb_retnint( (HB_PTRUINT) p );
}

/* ======================================================================
 * Form
 * ====================================================================== */

/* UI_FormNew( cTitle, nWidth, nHeight, cFontName, nFontSize ) --> hForm */
HB_FUNC( UI_FORMNEW )
{
   TForm * p = new TForm();

   if( HB_ISCHAR(1) ) p->SetText( hb_parc(1) );
   if( HB_ISNUM(2) )  p->FWidth = hb_parni(2);
   if( HB_ISNUM(3) )  p->FHeight = hb_parni(3);

   /* Custom font - convert point size to pixel height correctly */
   if( HB_ISCHAR(4) && HB_ISNUM(5) )
   {
      LOGFONTA lf = {0};
      HDC hDC = GetDC( NULL );
      int nPtSize = hb_parni(5);
      lf.lfHeight = -MulDiv( nPtSize, GetDeviceCaps( hDC, LOGPIXELSY ), 72 );
      ReleaseDC( NULL, hDC );
      lf.lfCharSet = DEFAULT_CHARSET;
      lstrcpynA( lf.lfFaceName, hb_parc(4), LF_FACESIZE );
      if( p->FFormFont ) DeleteObject( p->FFormFont );
      p->FFormFont = CreateFontIndirectA( &lf );
      p->FFont = p->FFormFont;
   }

   RetCtrl( p );
}

/* UI_OnSelChange( hForm, bBlock ) - callback when selection changes */
HB_FUNC( UI_ONSELCHANGE )
{
   TForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p && pBlock )
   {
      if( p->FOnSelChange ) hb_itemRelease( p->FOnSelChange );
      p->FOnSelChange = hb_itemNew( pBlock );
   }
}

/* UI_GetSelected( hForm ) --> hCtrl (first selected control, or 0) */
HB_FUNC( UI_GETSELECTED )
{
   TForm * p = GetForm(1);
   if( p && p->FSelCount > 0 )
      RetCtrl( p->FSelected[0] );
   else
      hb_retnint( 0 );
}

/* UI_FormSetDesign( hForm, lDesign ) */
HB_FUNC( UI_FORMSETDESIGN )
{
   TForm * p = GetForm(1);
   if( p ) p->SetDesignMode( hb_parl(2) );
}

/* UI_FormRun( hForm ) - create, show, and enter message loop */
HB_FUNC( UI_FORMRUN )
{
   TForm * p = GetForm(1);
   if( p ) p->Run();
}

/* UI_FormShow( hForm ) - create and show without message loop */
HB_FUNC( UI_FORMSHOW )
{
   TForm * p = GetForm(1);
   if( p ) p->Show();
}

/* UI_FormClose( hForm ) */
HB_FUNC( UI_FORMCLOSE )
{
   TForm * p = GetForm(1);
   if( p ) p->Close();
}

/* UI_FormDestroy( hForm ) */
HB_FUNC( UI_FORMDESTROY )
{
   TForm * p = GetForm(1);
   if( p ) delete p;
}

/* UI_FormResult( hForm ) --> nResult */
HB_FUNC( UI_FORMRESULT )
{
   TForm * p = GetForm(1);
   hb_retni( p ? p->FModalResult : 0 );
}

/* ======================================================================
 * Control creation
 * ====================================================================== */

/* UI_LabelNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_LABELNEW )
{
   TForm * pForm = GetForm(1);
   TLabel * p = new TLabel();

   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) )  p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) )  p->FTop = hb_parni(4);
   if( HB_ISNUM(5) )  p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) )  p->FHeight = hb_parni(6);

   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_EditNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_EDITNEW )
{
   TForm * pForm = GetForm(1);
   TEdit * p = new TEdit();

   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) )  p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) )  p->FTop = hb_parni(4);
   if( HB_ISNUM(5) )  p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) )  p->FHeight = hb_parni(6);

   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ButtonNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_BUTTONNEW )
{
   TForm * pForm = GetForm(1);
   TButton * p = new TButton();

   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) )  p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) )  p->FTop = hb_parni(4);
   if( HB_ISNUM(5) )  p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) )  p->FHeight = hb_parni(6);

   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_CheckBoxNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_CHECKBOXNEW )
{
   TForm * pForm = GetForm(1);
   TCheckBox * p = new TCheckBox();

   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) )  p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) )  p->FTop = hb_parni(4);
   if( HB_ISNUM(5) )  p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) )  p->FHeight = hb_parni(6);

   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ComboBoxNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_COMBOBOXNEW )
{
   TForm * pForm = GetForm(1);
   TComboBox * p = new TComboBox();

   if( HB_ISNUM(2) )  p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) )  p->FTop = hb_parni(3);
   if( HB_ISNUM(4) )  p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) )  p->FHeight = hb_parni(5);

   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_GroupBoxNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_GROUPBOXNEW )
{
   TForm * pForm = GetForm(1);
   TGroupBox * p = new TGroupBox();

   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) )  p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) )  p->FTop = hb_parni(4);
   if( HB_ISNUM(5) )  p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) )  p->FHeight = hb_parni(6);

   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ListBoxNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_LISTBOXNEW )
{
   TForm * pForm = GetForm(1);
   TListBox * p = new TListBox();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_RadioButtonNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_RADIOBUTTONNEW )
{
   TForm * pForm = GetForm(1);
   TRadioButton * p = new TRadioButton();
   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_BitBtnNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_BITBTNNEW )
{
   TForm * pForm = GetForm(1);
   TBitBtn * p = new TBitBtn();
   if( HB_ISCHAR(2) ) p->SetText( hb_parc(2) );
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);
   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);
   if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ImageNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_IMAGENEW )
{
   TForm * pForm = GetForm(1);
   TImage * p = new TImage();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ShapeNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_SHAPENEW )
{
   TForm * pForm = GetForm(1);
   TShape * p = new TShape();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_BevelNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_BEVELNEW )
{
   TForm * pForm = GetForm(1);
   TBevel * p = new TBevel();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_TreeViewNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_TREEVIEWNEW )
{
   TForm * pForm = GetForm(1);
   TTreeView * p = new TTreeView();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ListViewNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_LISTVIEWNEW )
{
   TForm * pForm = GetForm(1);
   TListView * p = new TListView();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_ProgressBarNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_PROGRESSBARNEW )
{
   TForm * pForm = GetForm(1);
   TProgressBar * p = new TProgressBar();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_RichEditNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_RICHEDITNEW )
{
   TForm * pForm = GetForm(1);
   TRichEdit * p = new TRichEdit();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* ======================================================================
 * TBrowse - Data Grid
 * ====================================================================== */

/* UI_BrowseNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_BROWSENEW )
{
   TForm * pForm = GetForm(1);
   TBrowse * p = new TBrowse();
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) pForm->AddChild( p );
   RetCtrl( p );
}

/* UI_BrowseAddCol( hBrowse, cTitle, cField, nWidth, nAlign ) --> nColIdx */
HB_FUNC( UI_BROWSEADDCOL )
{
   TBrowse * p = (TBrowse *) GetCtrl(1);
   if( p && p->FControlType == CT_BROWSE )
      hb_retni( p->AddColumn( hb_parc(2), HB_ISCHAR(3) ? hb_parc(3) : "",
         HB_ISNUM(4) ? hb_parni(4) : 100, HB_ISNUM(5) ? hb_parni(5) : 0 ) );
   else
      hb_retni( -1 );
}

/* UI_BrowseSetCell( hBrowse, nRow, nCol, cText ) */
HB_FUNC( UI_BROWSESETCELL )
{
   TBrowse * p = (TBrowse *) GetCtrl(1);
   if( p && p->FControlType == CT_BROWSE && HB_ISCHAR(4) )
      p->SetCellText( hb_parni(2), hb_parni(3), hb_parc(4) );
}

/* UI_BrowseGetCell( hBrowse, nRow, nCol ) --> cText */
HB_FUNC( UI_BROWSEGETCELL )
{
   TBrowse * p = (TBrowse *) GetCtrl(1);
   if( p && p->FControlType == CT_BROWSE )
      hb_retc( p->GetCellText( hb_parni(2), hb_parni(3) ) );
   else
      hb_retc( "" );
}

/* UI_BrowseSetFooter( hBrowse, nCol, cText ) */
HB_FUNC( UI_BROWSESETFOOTER )
{
   TBrowse * p = (TBrowse *) GetCtrl(1);
   if( p && p->FControlType == CT_BROWSE && HB_ISCHAR(3) )
      p->SetFooterText( hb_parni(2), hb_parc(3) );
}

/* UI_BrowseRefresh( hBrowse ) */
HB_FUNC( UI_BROWSEREFRESH )
{
   TBrowse * p = (TBrowse *) GetCtrl(1);
   if( p && p->FControlType == CT_BROWSE )
      p->Refresh();
}

/* UI_BrowseOnEvent( hBrowse, cEvent, bBlock ) */
HB_FUNC( UI_BROWSEONEVENT )
{
   TBrowse * p = (TBrowse *) GetCtrl(1);
   const char * ev = hb_parc(2);
   PHB_ITEM blk = hb_param(3, HB_IT_BLOCK);
   PHB_ITEM * ppTarget = NULL;

   if( !p || p->FControlType != CT_BROWSE || !ev || !blk ) return;

   if( lstrcmpi(ev,"OnCellClick")==0 )     ppTarget = &p->FOnCellClick;
   else if( lstrcmpi(ev,"OnCellDblClick")==0 ) ppTarget = &p->FOnCellDblClick;
   else if( lstrcmpi(ev,"OnHeaderClick")==0 )  ppTarget = &p->FOnHeaderClick;
   else if( lstrcmpi(ev,"OnSort")==0 )         ppTarget = &p->FOnSort;
   else if( lstrcmpi(ev,"OnScroll")==0 )       ppTarget = &p->FOnScroll;
   else if( lstrcmpi(ev,"OnCellEdit")==0 )     ppTarget = &p->FOnCellEdit;
   else if( lstrcmpi(ev,"OnCellPaint")==0 )    ppTarget = &p->FOnCellPaint;
   else if( lstrcmpi(ev,"OnRowSelect")==0 )    ppTarget = &p->FOnRowSelect;
   else if( lstrcmpi(ev,"OnKeyDown")==0 )      ppTarget = &p->FOnKeyDown;
   else if( lstrcmpi(ev,"OnColumnResize")==0 ) ppTarget = &p->FOnColumnResize;

   if( ppTarget ) {
      if( *ppTarget ) hb_itemRelease( *ppTarget );
      *ppTarget = hb_itemNew( blk );
   }
}

/* ======================================================================
 * Property access
 * ====================================================================== */

/* UI_SetProp( hCtrl, cProp, xValue ) */
HB_FUNC( UI_SETPROP )
{
   TControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);

   if( !p || !szProp ) return;

   if( lstrcmpi( szProp, "cText" ) == 0 && HB_ISCHAR(3) )
      p->SetText( hb_parc(3) );
   else if( lstrcmpi( szProp, "nLeft" ) == 0 )
   {  p->FLeft = hb_parni(3);
      if( p->FControlType == CT_FORM ) ((TForm*)p)->FCenter = FALSE;
      if( p->FHandle ) SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop, p->FWidth, p->FHeight, SWP_NOZORDER ); }
   else if( lstrcmpi( szProp, "nTop" ) == 0 )
   {  p->FTop = hb_parni(3);
      if( p->FControlType == CT_FORM ) ((TForm*)p)->FCenter = FALSE;
      if( p->FHandle ) SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop, p->FWidth, p->FHeight, SWP_NOZORDER ); }
   else if( lstrcmpi( szProp, "nWidth" ) == 0 )
   {  p->FWidth = hb_parni(3);
      if( p->FHandle ) SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop, p->FWidth, p->FHeight, SWP_NOZORDER ); }
   else if( lstrcmpi( szProp, "nHeight" ) == 0 )
   {  p->FHeight = hb_parni(3);
      if( p->FHandle ) SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop, p->FWidth, p->FHeight, SWP_NOZORDER ); }
   else if( lstrcmpi( szProp, "lVisible" ) == 0 )
   {  p->FVisible = hb_parl(3);
      if( p->FHandle ) ShowWindow( p->FHandle, p->FVisible ? SW_SHOW : SW_HIDE ); }
   else if( lstrcmpi( szProp, "lEnabled" ) == 0 )
   {  p->FEnabled = hb_parl(3);
      if( p->FHandle ) EnableWindow( p->FHandle, p->FEnabled ); }
   else if( lstrcmpi( szProp, "lDefault" ) == 0 && p->FControlType == CT_BUTTON )
      ((TButton*)p)->FDefault = hb_parl(3);
   else if( lstrcmpi( szProp, "lCancel" ) == 0 && p->FControlType == CT_BUTTON )
      ((TButton*)p)->FCancel = hb_parl(3);
   else if( lstrcmpi( szProp, "lChecked" ) == 0 && p->FControlType == CT_CHECKBOX )
      ((TCheckBox*)p)->SetChecked( hb_parl(3) );
   else if( lstrcmpi( szProp, "cName" ) == 0 && HB_ISCHAR(3) )
      lstrcpynA( p->FName, hb_parc(3), sizeof(p->FName) );
   else if( lstrcmpi( szProp, "lSizable" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FSizable = hb_parl(3);
   else if( lstrcmpi( szProp, "lAppBar" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FAppBar = hb_parl(3);
   else if( lstrcmpi( szProp, "lToolWindow" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FToolWindow = hb_parl(3);
   else if( lstrcmpi( szProp, "nBorderStyle" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FBorderStyle = hb_parni(3);
   else if( lstrcmpi( szProp, "nBorderIcons" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FBorderIcons = hb_parni(3);
   else if( lstrcmpi( szProp, "nBorderWidth" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FBorderWidth = hb_parni(3);
   else if( lstrcmpi( szProp, "nPosition" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FPosition = hb_parni(3);
   else if( lstrcmpi( szProp, "nWindowState" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FWindowState = hb_parni(3);
   else if( lstrcmpi( szProp, "nFormStyle" ) == 0 && p->FControlType == CT_FORM )
   {  ((TForm*)p)->FFormStyle = hb_parni(3);
      if( ((TForm*)p)->FHandle )
         SetWindowPos( ((TForm*)p)->FHandle, hb_parni(3)==1 ? HWND_TOPMOST : HWND_NOTOPMOST,
            0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE ); }
   else if( lstrcmpi( szProp, "nCursor" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FCursor = hb_parni(3);
   else if( lstrcmpi( szProp, "lKeyPreview" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FKeyPreview = hb_parl(3);
   else if( lstrcmpi( szProp, "lAlphaBlend" ) == 0 && p->FControlType == CT_FORM )
   {  ((TForm*)p)->FAlphaBlend = hb_parl(3);
      if( ((TForm*)p)->FHandle ) {
         LONG_PTR exStyle = GetWindowLongPtr( ((TForm*)p)->FHandle, GWL_EXSTYLE );
         if( hb_parl(3) ) {
            SetWindowLongPtr( ((TForm*)p)->FHandle, GWL_EXSTYLE, exStyle | WS_EX_LAYERED );
            SetLayeredWindowAttributes( ((TForm*)p)->FHandle, 0, (BYTE)((TForm*)p)->FAlphaBlendValue, LWA_ALPHA );
         } else {
            SetWindowLongPtr( ((TForm*)p)->FHandle, GWL_EXSTYLE, exStyle & ~WS_EX_LAYERED );
            RedrawWindow( ((TForm*)p)->FHandle, NULL, NULL, RDW_ERASE | RDW_INVALIDATE | RDW_FRAME | RDW_ALLCHILDREN );
         }
      } }
   else if( lstrcmpi( szProp, "nAlphaBlendValue" ) == 0 && p->FControlType == CT_FORM )
   {  ((TForm*)p)->FAlphaBlendValue = hb_parni(3);
      if( ((TForm*)p)->FAlphaBlend && ((TForm*)p)->FHandle )
         SetLayeredWindowAttributes( ((TForm*)p)->FHandle, 0, (BYTE)hb_parni(3), LWA_ALPHA ); }
   else if( lstrcmpi( szProp, "lShowHint" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FShowHint = hb_parl(3);
   else if( lstrcmpi( szProp, "cHint" ) == 0 && p->FControlType == CT_FORM && HB_ISCHAR(3) )
      lstrcpynA( ((TForm*)p)->FHint, hb_parc(3), 255 );
   else if( lstrcmpi( szProp, "lAutoScroll" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FAutoScroll = hb_parl(3);
   else if( lstrcmpi( szProp, "lDoubleBuffered" ) == 0 && p->FControlType == CT_FORM )
      ((TForm*)p)->FDoubleBuffered = hb_parl(3);
   else if( lstrcmpi( szProp, "nClrPane" ) == 0 )
   {
      p->FClrPane = (COLORREF) hb_parnint(3);
      if( p->FBkBrush ) DeleteObject( p->FBkBrush );
      p->FBkBrush = CreateSolidBrush( p->FClrPane );

      if( p->FControlType == CT_FORM )
      {
         TForm * pF = (TForm *) p;
         /* Invalidate grid cache so design-mode grid redraws with new color */
         if( pF->FGridBmp ) { SelectObject( pF->FGridDC, NULL ); DeleteObject( pF->FGridBmp ); DeleteDC( pF->FGridDC ); pF->FGridBmp = NULL; pF->FGridDC = NULL; }
         if( pF->FHandle )
         {
            SetClassLongPtr( pF->FHandle, GCLP_HBRBACKGROUND, (LONG_PTR) p->FBkBrush );
            InvalidateRect( pF->FHandle, NULL, TRUE );
         }
      }
      else
      {
         /* Buttons need owner-draw to respect background color */
         if( p->FControlType == CT_BUTTON && p->FHandle )
         {
            LONG_PTR style = GetWindowLongPtr( p->FHandle, GWL_STYLE );
            style = ( style & ~0x0FL ) | BS_OWNERDRAW;
            SetWindowLongPtr( p->FHandle, GWL_STYLE, style );
         }
         /* Child control: repaint via parent */
         if( p->FHandle )
         {
            HWND hParent = GetParent( p->FHandle );
            if( hParent ) InvalidateRect( hParent, NULL, TRUE );
            InvalidateRect( p->FHandle, NULL, TRUE );
         }
      }
   }
   else if( lstrcmpi( szProp, "oFont" ) == 0 && HB_ISCHAR(3) )
   {
      char szFace[LF_FACESIZE] = {0};
      int nSize = 12, i;
      const char * val = hb_parc(3);
      const char * comma = strchr( val, ',' );
      if( comma ) {
         int len = (int)(comma - val);
         if( len >= LF_FACESIZE ) len = LF_FACESIZE - 1;
         memcpy( szFace, val, len ); szFace[len] = 0;
         nSize = atoi( comma + 1 );
      } else
         lstrcpynA( szFace, val, LF_FACESIZE );
      if( nSize <= 0 ) nSize = 12;

      { LOGFONTA lf = {0};
        HFONT hNew;
        HDC hTmpDC = GetDC( NULL );
        lf.lfHeight = -MulDiv( nSize, GetDeviceCaps( hTmpDC, LOGPIXELSY ), 72 );
        ReleaseDC( NULL, hTmpDC );
        lf.lfCharSet = DEFAULT_CHARSET;
        lstrcpynA( lf.lfFaceName, szFace, LF_FACESIZE );
        hNew = CreateFontIndirectA( &lf );
        if( hNew )
        {
           if( p->FControlType == CT_FORM )
           {
              TForm * pF = (TForm *) p;
              if( pF->FFormFont ) DeleteObject( pF->FFormFont );
              pF->FFormFont = hNew;
              pF->FFont = hNew;
              if( pF->FHandle )
                 SendMessage( pF->FHandle, WM_SETFONT, (WPARAM) hNew, TRUE );
              for( i = 0; i < pF->FChildCount; i++ )
              {
                 pF->FChildren[i]->FFont = hNew;
                 if( pF->FChildren[i]->FHandle )
                    SendMessage( pF->FChildren[i]->FHandle, WM_SETFONT, (WPARAM) hNew, TRUE );
              }
              if( pF->FHandle )
                 InvalidateRect( pF->FHandle, NULL, TRUE );
           }
           else
           {
              p->FFont = hNew;
              if( p->FHandle )
              {
                 SendMessage( p->FHandle, WM_SETFONT, (WPARAM) hNew, TRUE );
                 InvalidateRect( p->FHandle, NULL, TRUE );
              }
           }
        }
      }
   }
}

/* UI_GetProp( hCtrl, cProp ) --> xValue */
HB_FUNC( UI_GETPROP )
{
   TControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);

   if( !p || !szProp ) { hb_ret(); return; }

   if( lstrcmpi( szProp, "cText" ) == 0 )
      hb_retc( p->FText );
   else if( lstrcmpi( szProp, "nLeft" ) == 0 )
      hb_retni( p->FLeft );
   else if( lstrcmpi( szProp, "nTop" ) == 0 )
      hb_retni( p->FTop );
   else if( lstrcmpi( szProp, "nWidth" ) == 0 )
      hb_retni( p->FWidth );
   else if( lstrcmpi( szProp, "nHeight" ) == 0 )
      hb_retni( p->FHeight );
   else if( lstrcmpi( szProp, "lDefault" ) == 0 && p->FControlType == CT_BUTTON )
      hb_retl( ((TButton*)p)->FDefault );
   else if( lstrcmpi( szProp, "lCancel" ) == 0 && p->FControlType == CT_BUTTON )
      hb_retl( ((TButton*)p)->FCancel );
   else if( lstrcmpi( szProp, "lChecked" ) == 0 && p->FControlType == CT_CHECKBOX )
      hb_retl( ((TCheckBox*)p)->FChecked );
   else if( lstrcmpi( szProp, "cName" ) == 0 )
      hb_retc( p->FName );
   else if( lstrcmpi( szProp, "cClassName" ) == 0 )
      hb_retc( p->FClassName );
   else if( lstrcmpi( szProp, "lSizable" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FSizable );
   else if( lstrcmpi( szProp, "lAppBar" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FAppBar );
   else if( lstrcmpi( szProp, "nBorderStyle" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FBorderStyle );
   else if( lstrcmpi( szProp, "nBorderIcons" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FBorderIcons );
   else if( lstrcmpi( szProp, "nBorderWidth" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FBorderWidth );
   else if( lstrcmpi( szProp, "nPosition" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FPosition );
   else if( lstrcmpi( szProp, "nWindowState" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FWindowState );
   else if( lstrcmpi( szProp, "nFormStyle" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FFormStyle );
   else if( lstrcmpi( szProp, "nCursor" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FCursor );
   else if( lstrcmpi( szProp, "lKeyPreview" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FKeyPreview );
   else if( lstrcmpi( szProp, "lAlphaBlend" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FAlphaBlend );
   else if( lstrcmpi( szProp, "nAlphaBlendValue" ) == 0 && p->FControlType == CT_FORM )
      hb_retni( ((TForm*)p)->FAlphaBlendValue );
   else if( lstrcmpi( szProp, "lShowHint" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FShowHint );
   else if( lstrcmpi( szProp, "cHint" ) == 0 && p->FControlType == CT_FORM )
      hb_retc( ((TForm*)p)->FHint );
   else if( lstrcmpi( szProp, "lAutoScroll" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FAutoScroll );
   else if( lstrcmpi( szProp, "lDoubleBuffered" ) == 0 && p->FControlType == CT_FORM )
      hb_retl( ((TForm*)p)->FDoubleBuffered );
   else if( lstrcmpi( szProp, "nClientWidth" ) == 0 && p->FControlType == CT_FORM )
   {  TForm * f = (TForm*)p; RECT rc;
      if( f->FHandle && GetClientRect(f->FHandle, &rc) ) hb_retni( rc.right );
      else hb_retni( f->FWidth ); }
   else if( lstrcmpi( szProp, "nClientHeight" ) == 0 && p->FControlType == CT_FORM )
   {  TForm * f = (TForm*)p; RECT rc;
      if( f->FHandle && GetClientRect(f->FHandle, &rc) ) hb_retni( rc.bottom );
      else hb_retni( f->FHeight ); }
   else if( lstrcmpi( szProp, "cFontName" ) == 0 )
   {  LOGFONTA lf = {0};
      if( p->FFont && GetObjectA( p->FFont, sizeof(lf), &lf ) ) hb_retc( lf.lfFaceName );
      else hb_retc( "Segoe UI" ); }
   else if( lstrcmpi( szProp, "nFontSize" ) == 0 )
   {  LOGFONTA lf = {0}; HDC hDC;
      if( p->FFont && GetObjectA( p->FFont, sizeof(lf), &lf ) ) {
         hDC = GetDC(NULL);
         hb_retni( MulDiv( lf.lfHeight < 0 ? -lf.lfHeight : lf.lfHeight, 72, GetDeviceCaps(hDC, LOGPIXELSY) ) );
         ReleaseDC(NULL, hDC);
      } else hb_retni( 12 ); }
   else if( lstrcmpi( szProp, "nItemIndex" ) == 0 && p->FControlType == CT_COMBOBOX )
      hb_retni( ((TComboBox*)p)->FItemIndex );
   else if( lstrcmpi( szProp, "nClrPane" ) == 0 )
      hb_retnint( (HB_MAXINT) p->FClrPane );
   else if( lstrcmpi( szProp, "oFont" ) == 0 )
   {
      char szFont[128] = "Segoe UI,12";
      LOGFONTA lf = {0};
      if( p->FFont && GetObjectA( p->FFont, sizeof(lf), &lf ) )
         sprintf( szFont, "%s,%d", lf.lfFaceName, lf.lfHeight < 0 ? -lf.lfHeight : lf.lfHeight );
      hb_retc( szFont );
   }
   else
      hb_ret();
}

/* ======================================================================
 * Events
 * ====================================================================== */

/* UI_OnEvent( hCtrl, cEvent, bBlock ) */
HB_FUNC( UI_ONEVENT )
{
   TControl * p = GetCtrl(1);
   const char * szEvent = hb_parc(2);
   PHB_ITEM pBlock = hb_param(3, HB_IT_BLOCK);

   if( p && szEvent && pBlock )
   {
      /* Try base events first */
      p->SetEvent( szEvent, pBlock );

      /* If it's a form, also try form-specific events */
      if( p->FControlType == CT_FORM )
         ((TForm*)p)->SetFormEvent( szEvent, pBlock );
   }
}

/* UI_GetAllEvents( hCtrl ) --> aEvents
 * Each event: { cName, lAssigned, cCategory } */
HB_FUNC( UI_GETALLEVENTS )
{
   TControl * p = GetCtrl(1);
   PHB_ITEM pArray, pRow;
   if( !p ) { hb_reta(0); return; }
   pArray = hb_itemArrayNew(0);

   #define ADD_E(n,assigned,c) \
      pRow=hb_itemArrayNew(3); hb_arraySetC(pRow,1,n); \
      hb_arraySetL(pRow,2,assigned); hb_arraySetC(pRow,3,c); \
      hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);

   switch( p->FControlType ) {
      case CT_FORM: {
         TForm * f = (TForm *) p;
         ADD_E("OnClick",       f->FOnClick != NULL,      "Action");
         ADD_E("OnDblClick",    f->FOnDblClick != NULL,    "Action");
         ADD_E("OnCreate",      f->FOnCreate != NULL,      "Lifecycle");
         ADD_E("OnDestroy",     f->FOnDestroy != NULL,     "Lifecycle");
         ADD_E("OnShow",        f->FOnShow != NULL,        "Lifecycle");
         ADD_E("OnHide",        f->FOnHide != NULL,        "Lifecycle");
         ADD_E("OnClose",       f->FOnClose != NULL,       "Lifecycle");
         ADD_E("OnCloseQuery",  f->FOnCloseQuery != NULL,  "Lifecycle");
         ADD_E("OnActivate",    f->FOnActivate != NULL,    "Lifecycle");
         ADD_E("OnDeactivate",  f->FOnDeactivate != NULL,  "Lifecycle");
         ADD_E("OnResize",      f->FOnResize != NULL,      "Layout");
         ADD_E("OnPaint",       f->FOnPaint != NULL,       "Layout");
         ADD_E("OnKeyDown",     f->FOnKeyDown != NULL,     "Keyboard");
         ADD_E("OnKeyUp",       f->FOnKeyUp != NULL,       "Keyboard");
         ADD_E("OnKeyPress",    f->FOnKeyPress != NULL,    "Keyboard");
         ADD_E("OnMouseDown",   f->FOnMouseDown != NULL,   "Mouse");
         ADD_E("OnMouseUp",     f->FOnMouseUp != NULL,     "Mouse");
         ADD_E("OnMouseMove",   f->FOnMouseMove != NULL,   "Mouse");
         ADD_E("OnMouseWheel",  f->FOnMouseWheel != NULL,  "Mouse");
         break;
      }
      case CT_BUTTON:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnKeyUp",    0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         break;
      case CT_EDIT:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnKeyUp",    0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         break;
      case CT_CHECKBOX:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_COMBOBOX:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_LABEL:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_GROUPBOX:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_LISTBOX:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         break;
      case CT_RADIO:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         break;
      case CT_MEMO: case CT_RICHEDIT:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnKeyUp",    0,                    "Keyboard");
         ADD_E("OnKeyPress", 0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         break;
      case CT_PANEL: case CT_SCROLLBOX:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnResize",   0,                    "Layout");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseMove",0,                    "Mouse");
         break;
      case CT_SCROLLBAR: case CT_TRACKBAR:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnScroll",   0,                    "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         break;
      case CT_BITBTN: case CT_SPEEDBTN:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_IMAGE:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         ADD_E("OnMouseMove",0,                    "Mouse");
         break;
      case CT_SHAPE: case CT_BEVEL:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_TREEVIEW:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnExpand",   0,                    "Action");
         ADD_E("OnCollapse", 0,                    "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_LISTVIEW:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnColumnClick",0,                  "Action");
         ADD_E("OnInsert",   0,                    "Action");
         ADD_E("OnDelete",   0,                    "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_PROGRESSBAR:
         /* No user events - data-driven control */
         break;
      case CT_TABCONTROL2:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         break;
      case CT_UPDOWN:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         break;
      case CT_DATETIMEPICKER:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnCloseUp",  0,                    "Action");
         ADD_E("OnDropDown", 0,                    "Action");
         break;
      case CT_MONTHCALENDAR:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         break;
      case CT_PAINTBOX:
         ADD_E("OnPaint",    0,                    "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         ADD_E("OnMouseMove",0,                    "Mouse");
         ADD_E("OnResize",   0,                    "Layout");
         break;
      case CT_BROWSE: case CT_DBGRID: {
         TBrowse * b = (TBrowse *) p;
         ADD_E("OnCellClick",    b->FOnCellClick != NULL,    "Action");
         ADD_E("OnCellDblClick", b->FOnCellDblClick != NULL, "Action");
         ADD_E("OnHeaderClick",  b->FOnHeaderClick != NULL,  "Action");
         ADD_E("OnSort",         b->FOnSort != NULL,         "Action");
         ADD_E("OnScroll",       b->FOnScroll != NULL,       "Action");
         ADD_E("OnCellEdit",     b->FOnCellEdit != NULL,     "Data");
         ADD_E("OnCellPaint",    b->FOnCellPaint != NULL,    "Layout");
         ADD_E("OnRowSelect",    b->FOnRowSelect != NULL,    "Action");
         ADD_E("OnKeyDown",      b->FOnKeyDown != NULL,      "Keyboard");
         ADD_E("OnColumnResize", b->FOnColumnResize != NULL, "Layout");
         break;
      }
      case CT_TIMER:
         ADD_E("OnTimer",    0,                    "Action");
         break;
      case CT_MASKEDIT2: case CT_LABELEDEDIT:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         break;
      case CT_STRINGGRID:
         ADD_E("OnCellClick",    0,                "Action");
         ADD_E("OnCellDblClick", 0,                "Action");
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnColumnResize", 0,                "Layout");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         break;
      case CT_STATICTEXT:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         break;
      /* Database components (non-visual) */
      case CT_DBFTABLE: case CT_MYSQL: case CT_MARIADB:
      case CT_POSTGRESQL: case CT_SQLITE: case CT_FIREBIRD:
      case CT_SQLSERVER: case CT_ORACLE: case CT_MONGODB:
         ADD_E("OnConnect",     0,  "Connection");
         ADD_E("OnDisconnect",  0,  "Connection");
         ADD_E("OnError",       0,  "Error");
         ADD_E("OnBeforeQuery", 0,  "Data");
         ADD_E("OnAfterQuery",  0,  "Data");
         break;
      /* Internet components */
      case CT_WEBVIEW:
         ADD_E("OnNavigate",    0,  "Navigation");
         ADD_E("OnLoad",        0,  "Navigation");
         ADD_E("OnError",       0,  "Error");
         ADD_E("OnTitleChange",  0,  "Navigation");
         break;
      case CT_WEBSERVER:
         ADD_E("OnRequest",     0,  "Server");
         ADD_E("OnConnect",     0,  "Server");
         ADD_E("OnDisconnect",  0,  "Server");
         ADD_E("OnStart",       0,  "Server");
         ADD_E("OnStop",        0,  "Server");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_WEBSOCKET:
         ADD_E("OnOpen",        0,  "Connection");
         ADD_E("OnMessage",     0,  "Data");
         ADD_E("OnClose",       0,  "Connection");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_HTTPCLIENT:
         ADD_E("OnResponse",    0,  "Data");
         ADD_E("OnProgress",    0,  "Data");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_TCPSERVER:
         ADD_E("OnAccept",      0,  "Connection");
         ADD_E("OnReceive",     0,  "Data");
         ADD_E("OnDisconnect",  0,  "Connection");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_TCPCLIENT:
         ADD_E("OnConnect",     0,  "Connection");
         ADD_E("OnReceive",     0,  "Data");
         ADD_E("OnDisconnect",  0,  "Connection");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_UDPSOCKET:
         ADD_E("OnReceive",     0,  "Data");
         ADD_E("OnError",       0,  "Error");
         break;
      /* Threading */
      case CT_THREAD:
         ADD_E("OnExecute",     0,  "Thread");
         ADD_E("OnTerminate",   0,  "Thread");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_THREADPOOL:
         ADD_E("OnTaskComplete", 0,  "Thread");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_CHANNEL:
         ADD_E("OnReceive",     0,  "Data");
         break;
      /* AI */
      case CT_OPENAI: case CT_GEMINI: case CT_CLAUDE:
      case CT_DEEPSEEK: case CT_GROK: case CT_OLLAMA:
         ADD_E("OnResponse",    0,  "AI");
         ADD_E("OnStream",      0,  "AI");
         ADD_E("OnError",       0,  "Error");
         ADD_E("OnTokenCount",  0,  "AI");
         break;
      case CT_TRANSFORMER:
         ADD_E("OnAttention",   0,  "AI");
         ADD_E("OnGenerate",    0,  "AI");
         ADD_E("OnTrainStep",   0,  "Training");
         ADD_E("OnLoss",        0,  "Training");
         break;
      /* ERP */
      case CT_REPORTDESIGNER:
         ADD_E("OnBeforePrint", 0,  "Report");
         ADD_E("OnAfterPrint",  0,  "Report");
         ADD_E("OnPreview",     0,  "Report");
         break;
      case CT_BARCODE: case CT_BARCODEPRINTER:
         ADD_E("OnGenerate",    0,  "Action");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_PDFGENERATOR: case CT_EXCELEXPORT:
         ADD_E("OnBeforeExport", 0,  "Export");
         ADD_E("OnAfterExport",  0,  "Export");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_AUDITLOG:
         ADD_E("OnLog",         0,  "Data");
         break;
      case CT_SCHEDULER:
         ADD_E("OnEvent",       0,  "Action");
         ADD_E("OnReminder",    0,  "Action");
         ADD_E("OnChange",     p->FOnChange != NULL, "Action");
         break;
      case CT_DASHBOARD:
         ADD_E("OnRefresh",     0,  "Action");
         ADD_E("OnClick",      p->FOnClick != NULL, "Action");
         break;
      /* Printing */
      case CT_PRINTER:
         ADD_E("OnStartDoc",    0,  "Print");
         ADD_E("OnEndDoc",      0,  "Print");
         ADD_E("OnStartPage",   0,  "Print");
         ADD_E("OnEndPage",     0,  "Print");
         ADD_E("OnError",       0,  "Error");
         break;
      case CT_REPORT:
         ADD_E("OnBeforePrint", 0,  "Report");
         ADD_E("OnAfterPrint",  0,  "Report");
         ADD_E("OnData",        0,  "Data");
         ADD_E("OnPreview",     0,  "Report");
         break;
      case CT_LABELS:
         ADD_E("OnBeforePrint", 0,  "Print");
         ADD_E("OnAfterPrint",  0,  "Print");
         break;
      case CT_REPORTVIEWER: case CT_PRINTPREVIEW:
         ADD_E("OnPageChange",  0,  "Navigation");
         ADD_E("OnZoom",        0,  "Navigation");
         ADD_E("OnPrint",       0,  "Action");
         ADD_E("OnExport",      0,  "Action");
         break;
      /* DB Navigator */
      case CT_DBNAVIGATOR:
         ADD_E("OnFirst",       0,  "Navigation");
         ADD_E("OnPrior",       0,  "Navigation");
         ADD_E("OnNext",        0,  "Navigation");
         ADD_E("OnLast",        0,  "Navigation");
         ADD_E("OnInsert",      0,  "Data");
         ADD_E("OnDelete",      0,  "Data");
         ADD_E("OnEdit",        0,  "Data");
         ADD_E("OnPost",        0,  "Data");
         ADD_E("OnCancel",      0,  "Data");
         ADD_E("OnRefresh",     0,  "Data");
         break;
      /* Data-aware controls */
      case CT_DBTEXT: case CT_DBEDIT: case CT_DBCOMBOBOX:
      case CT_DBCHECKBOX: case CT_DBIMAGE:
         ADD_E("OnChange",   p->FOnChange != NULL, "Data");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         break;
      default:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
   }
   #undef ADD_E
   hb_itemReturnRelease(pArray);
}

/* ======================================================================
 * ComboBox helpers
 * ====================================================================== */

/* ======================================================================
 * Children iteration (for TUI/Web renderers)
 * ====================================================================== */

/* UI_GetChildCount( hCtrl ) --> nCount */
HB_FUNC( UI_GETCHILDCOUNT )
{
   TControl * p = GetCtrl(1);
   hb_retni( p ? p->FChildCount : 0 );
}

/* UI_GetChild( hCtrl, nIndex ) --> hChild  (1-based) */
HB_FUNC( UI_GETCHILD )
{
   TControl * p = GetCtrl(1);
   int nIdx = hb_parni(2) - 1;

   if( p && nIdx >= 0 && nIdx < p->FChildCount )
      RetCtrl( p->FChildren[nIdx] );
   else
      hb_retnint( 0 );
}

/* UI_GetType( hCtrl ) --> nControlType */
HB_FUNC( UI_GETTYPE )
{
   TControl * p = GetCtrl(1);
   hb_retni( p ? p->FControlType : -1 );
}

/* UI_ComboGetItem( hCombo, nIndex ) --> cItem (1-based) */
HB_FUNC( UI_COMBOGETITEM )
{
   TComboBox * p = (TComboBox *) GetCtrl(1);
   int nIdx = hb_parni(2) - 1;

   if( p && p->FControlType == CT_COMBOBOX && nIdx >= 0 && nIdx < p->FItemCount )
      hb_retc( p->FItems[nIdx] );
   else
      hb_retc( "" );
}

/* UI_ComboGetCount( hCombo ) --> nCount */
HB_FUNC( UI_COMBOGETCOUNT )
{
   TComboBox * p = (TComboBox *) GetCtrl(1);
   hb_retni( p && p->FControlType == CT_COMBOBOX ? p->FItemCount : 0 );
}

/* ======================================================================
 * Property introspection (for Object Inspector)
 * ====================================================================== */

/* UI_GetPropCount( hCtrl ) --> nCount (base + specific) */
HB_FUNC( UI_GETPROPCOUNT )
{
   TControl * p = GetCtrl(1);
   int nBase = 0, nSpec = 0;
   if( p )
   {
      /* Base TControl props: Name,Left,Top,Width,Height,Text,Visible,Enabled = 8 */
      nBase = 8;
      /* Type-specific props */
      p->GetPropDescs( &nSpec );
   }
   hb_retni( nBase + nSpec );
}

/* UI_GetAllProps( hCtrl ) --> { { "Name","value","Category","Type" }, ... } */
HB_FUNC( UI_GETALLPROPS )
{
   TControl * p = GetCtrl(1);
   PHB_ITEM pArray, pRow;
   int n = 0;

   if( !p ) { hb_reta(0); return; }

   pArray = hb_itemArrayNew( 0 );

   /* Helper macro to add a property row */
   #define ADD_PROP_S( name, val, cat ) \
      pRow = hb_itemArrayNew(4); \
      hb_arraySetC( pRow, 1, name ); \
      hb_arraySetC( pRow, 2, val ); \
      hb_arraySetC( pRow, 3, cat ); \
      hb_arraySetC( pRow, 4, "S" ); \
      hb_arrayAdd( pArray, pRow ); \
      hb_itemRelease( pRow );

   #define ADD_PROP_N( name, val, cat ) \
      pRow = hb_itemArrayNew(4); \
      hb_arraySetC( pRow, 1, name ); \
      hb_arraySetNI( pRow, 2, val ); \
      hb_arraySetC( pRow, 3, cat ); \
      hb_arraySetC( pRow, 4, "N" ); \
      hb_arrayAdd( pArray, pRow ); \
      hb_itemRelease( pRow );

   #define ADD_PROP_L( name, val, cat ) \
      pRow = hb_itemArrayNew(4); \
      hb_arraySetC( pRow, 1, name ); \
      hb_arraySetL( pRow, 2, val ); \
      hb_arraySetC( pRow, 3, cat ); \
      hb_arraySetC( pRow, 4, "L" ); \
      hb_arrayAdd( pArray, pRow ); \
      hb_itemRelease( pRow );

   #define ADD_PROP_C( name, val, cat ) \
      pRow = hb_itemArrayNew(4); \
      hb_arraySetC( pRow, 1, name ); \
      hb_arraySetNInt( pRow, 2, (HB_MAXINT)(val) ); \
      hb_arraySetC( pRow, 3, cat ); \
      hb_arraySetC( pRow, 4, "C" ); \
      hb_arrayAdd( pArray, pRow ); \
      hb_itemRelease( pRow );

   #define ADD_PROP_F( name, val, cat ) \
      pRow = hb_itemArrayNew(4); \
      hb_arraySetC( pRow, 1, name ); \
      hb_arraySetC( pRow, 2, val ); \
      hb_arraySetC( pRow, 3, cat ); \
      hb_arraySetC( pRow, 4, "F" ); \
      hb_arrayAdd( pArray, pRow ); \
      hb_itemRelease( pRow );

   /* Base properties */
   ADD_PROP_S( "cClassName", p->FClassName, "Info" );
   ADD_PROP_S( "cName", p->FName, "Appearance" );
   ADD_PROP_S( "cText", p->FText, "Appearance" );
   ADD_PROP_N( "nLeft", p->FLeft, "Position" );
   ADD_PROP_N( "nTop", p->FTop, "Position" );
   ADD_PROP_N( "nWidth", p->FWidth, "Position" );
   ADD_PROP_N( "nHeight", p->FHeight, "Position" );
   ADD_PROP_L( "lVisible", p->FVisible, "Behavior" );
   ADD_PROP_L( "lEnabled", p->FEnabled, "Behavior" );
   ADD_PROP_L( "lTabStop", p->FTabStop, "Behavior" );

   /* Font property */
   {
      char szFont[128] = "Segoe UI,12";
      LOGFONTA lf = {0};
      if( p->FFont && GetObjectA( p->FFont, sizeof(lf), &lf ) )
         sprintf( szFont, "%s,%d", lf.lfFaceName, lf.lfHeight < 0 ? -lf.lfHeight : lf.lfHeight );
      ADD_PROP_F( "oFont", szFont, "Appearance" );
   }

   /* Color - base property (CLR_INVALID means inherited) */
   ADD_PROP_C( "nClrPane", p->FClrPane, "Appearance" );

   /* Type-specific properties */
   switch( p->FControlType )
   {
      case CT_FORM:
      {
         TForm * f = (TForm *) p;
         RECT rc;
         int cw, ch;
         ADD_PROP_N( "nBorderStyle", f->FBorderStyle, "Appearance" );
         ADD_PROP_N( "nBorderIcons", f->FBorderIcons, "Appearance" );
         ADD_PROP_N( "nBorderWidth", f->FBorderWidth, "Appearance" );
         ADD_PROP_N( "nPosition", f->FPosition, "Position" );
         ADD_PROP_N( "nWindowState", f->FWindowState, "Appearance" );
         ADD_PROP_N( "nFormStyle", f->FFormStyle, "Appearance" );
         ADD_PROP_L( "lKeyPreview", f->FKeyPreview, "Behavior" );
         ADD_PROP_L( "lAlphaBlend", f->FAlphaBlend, "Appearance" );
         ADD_PROP_N( "nAlphaBlendValue", f->FAlphaBlendValue, "Appearance" );
         ADD_PROP_N( "nCursor", f->FCursor, "Appearance" );
         ADD_PROP_L( "lShowHint", f->FShowHint, "Behavior" );
         ADD_PROP_S( "cHint", f->FHint, "Behavior" );
         ADD_PROP_L( "lAutoScroll", f->FAutoScroll, "Behavior" );
         ADD_PROP_L( "lDoubleBuffered", f->FDoubleBuffered, "Behavior" );
         /* Read-only: client area */
         cw = f->FWidth; ch = f->FHeight;
         if( f->FHandle && GetClientRect( f->FHandle, &rc ) )
         {  cw = rc.right; ch = rc.bottom; }
         ADD_PROP_N( "nClientWidth", cw, "Position" );
         ADD_PROP_N( "nClientHeight", ch, "Position" );
         break;
      }
      case CT_BUTTON:
         ADD_PROP_L( "lDefault", ((TButton*)p)->FDefault, "Behavior" );
         ADD_PROP_L( "lCancel", ((TButton*)p)->FCancel, "Behavior" );
         break;
      case CT_CHECKBOX:
         ADD_PROP_L( "lChecked", ((TCheckBox*)p)->FChecked, "Data" );
         break;
      case CT_EDIT:
         ADD_PROP_L( "lReadOnly", ((TEdit*)p)->FReadOnly, "Behavior" );
         ADD_PROP_L( "lPassword", ((TEdit*)p)->FPassword, "Behavior" );
         break;
      case CT_COMBOBOX:
         ADD_PROP_N( "nItemIndex", ((TComboBox*)p)->FItemIndex, "Data" );
         ADD_PROP_N( "nItemCount", ((TComboBox*)p)->FItemCount, "Data" );
         break;
   }

   hb_itemReturnRelease( pArray );
}

/* ======================================================================
 * JSON Serialization
 * ====================================================================== */

/* UI_FormToJSON( hForm ) --> cJSON */
HB_FUNC( UI_FORMTOJSON )
{
   TForm * pForm = GetForm(1);
   char buf[16384];  /* 16K buffer */
   char tmp[512];
   int pos = 0, i, j;
   TControl * p;
   TComboBox * pCbx;

   if( !pForm ) { hb_retc("{}"); return; }

   #define ADDC(s) { int l=lstrlenA(s); if(pos+l<(int)sizeof(buf)-1){lstrcpyA(buf+pos,s);pos+=l;} }

   ADDC("{\"class\":\"Form\"")
   sprintf(tmp,",\"w\":%d,\"h\":%d", pForm->FWidth, pForm->FHeight);  ADDC(tmp)
   sprintf(tmp,",\"text\":\"%s\"", pForm->FText);  ADDC(tmp)
   ADDC(",\"children\":[")

   for( i = 0; i < pForm->FChildCount; i++ )
   {
      p = pForm->FChildren[i];
      if( i > 0 ) ADDC(",")

      ADDC("{")
      sprintf(tmp,"\"type\":%d,\"name\":\"%s\"", p->FControlType, p->FName); ADDC(tmp)
      sprintf(tmp,",\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d", p->FLeft, p->FTop, p->FWidth, p->FHeight); ADDC(tmp)
      sprintf(tmp,",\"text\":\"%s\"", p->FText); ADDC(tmp)

      if( p->FControlType == CT_BUTTON ) {
         sprintf(tmp,",\"default\":%s,\"cancel\":%s",
            ((TButton*)p)->FDefault?"true":"false",
            ((TButton*)p)->FCancel?"true":"false"); ADDC(tmp)
      }
      if( p->FControlType == CT_CHECKBOX ) {
         sprintf(tmp,",\"checked\":%s", ((TCheckBox*)p)->FChecked?"true":"false"); ADDC(tmp)
      }
      if( p->FControlType == CT_COMBOBOX ) {
         pCbx = (TComboBox*)p;
         sprintf(tmp,",\"sel\":%d,\"items\":[", pCbx->FItemIndex); ADDC(tmp)
         for( j = 0; j < pCbx->FItemCount; j++ ) {
            if( j > 0 ) ADDC(",")
            sprintf(tmp,"\"%s\"", pCbx->FItems[j]); ADDC(tmp)
         }
         ADDC("]")
      }

      ADDC("}")
   }

   ADDC("]}")
   buf[pos] = 0;

   hb_retclen( buf, pos );

   #undef ADDC
}

/* UI_ComboAddItem( hCombo, cItem ) */
HB_FUNC( UI_COMBOADDITEM )
{
   TComboBox * p = (TComboBox *) GetCtrl(1);
   if( p && p->FControlType == CT_COMBOBOX && HB_ISCHAR(2) )
      p->AddItem( hb_parc(2) );
}

/* UI_ComboSetIndex( hCombo, nIndex ) */
HB_FUNC( UI_COMBOSETINDEX )
{
   TComboBox * p = (TComboBox *) GetCtrl(1);
   if( p && p->FControlType == CT_COMBOBOX )
      p->SetItemIndex( hb_parni(2) );
}

/* ======================================================================
 * Toolbar
 * ====================================================================== */

/* UI_ToolBarNew( hForm ) --> hToolBar */
HB_FUNC( UI_TOOLBARNEW )
{
   TForm * pForm = GetForm(1);
   TToolBar * p = new TToolBar();

   if( pForm )
      pForm->AttachToolBar( p );

   RetCtrl( p );
}

/* UI_ToolBtnAdd( hToolBar, cText, cTooltip ) --> nIndex */
HB_FUNC( UI_TOOLBTNADD )
{
   TToolBar * p = (TToolBar *) GetCtrl(1);
   if( p && p->FControlType == CT_TOOLBAR )
      hb_retni( p->AddButton( hb_parc(2), HB_ISCHAR(3) ? hb_parc(3) : "" ) );
   else
      hb_retni( -1 );
}

/* UI_ToolBtnAddSep( hToolBar ) */
HB_FUNC( UI_TOOLBTNADDSEP )
{
   TToolBar * p = (TToolBar *) GetCtrl(1);
   if( p && p->FControlType == CT_TOOLBAR )
      p->AddSeparator();
}

/* UI_ToolBarGetWidth( hToolBar ) --> nWidth */
HB_FUNC( UI_TOOLBARGETWIDTH )
{
   TToolBar * p = (TToolBar *) GetCtrl(1);
   if( p && p->FControlType == CT_TOOLBAR )
      hb_retni( p->FWidth );
   else
      hb_retni( 0 );
}

/* UI_ToolBtnOnClick( hToolBar, nIndex, bBlock ) */
HB_FUNC( UI_TOOLBTNONCLICK )
{
   TToolBar * p = (TToolBar *) GetCtrl(1);
   int nIdx = hb_parni(2);
   PHB_ITEM pBlock = hb_param(3, HB_IT_BLOCK);
   if( p && p->FControlType == CT_TOOLBAR && pBlock )
      p->SetBtnClick( nIdx, pBlock );
}

/* UI_ToolBarLoadImages( hToolBar, cBmpPath ) */
HB_FUNC( UI_TOOLBARLOADIMAGES )
{
   TToolBar * p = (TToolBar *) GetCtrl(1);
   if( p && p->FControlType == CT_TOOLBAR && HB_ISCHAR(2) )
      p->LoadImages( hb_parc(2) );
}

/* UI_StackToolBars( hForm ) - reposition second toolbar below first */
HB_FUNC( UI_STACKTOOLBARS )
{
   TForm * pForm = GetForm(1);
   if( pForm )
      pForm->StackToolBars();
}

/* ======================================================================
 * Menu
 * ====================================================================== */

/* UI_MenuBarCreate( hForm ) */
HB_FUNC( UI_MENUBARCREATE )
{
   TForm * p = GetForm(1);
   if( p ) p->CreateMenuBar();
}

/* UI_MenuBarSetDark( hForm ) — convert menu bar items to owner-draw dark */
extern void DarkifyMenuBar( HMENU hMenu );
HB_FUNC( UI_MENUBARSETDARK )
{
   TForm * p = GetForm(1);
   if( p && p->FMenuBar && p->FHandle )
   {
      DarkifyMenuBar( p->FMenuBar );
      SetMenu( p->FHandle, p->FMenuBar );
      DrawMenuBar( p->FHandle );
   }
}

/* UI_MenuPopupAdd( hForm, cText ) --> hPopup (as number) */
HB_FUNC( UI_MENUPOPUPADD )
{
   TForm * p = GetForm(1);
   if( p && HB_ISCHAR(2) )
      hb_retnint( (HB_PTRUINT) p->AddMenuPopup( hb_parc(2) ) );
   else
      hb_retnint( 0 );
}

/* UI_MenuItemAdd( hPopup, cText, bBlock ) --> nIndex */
HB_FUNC( UI_MENUITEMADD )
{
   HMENU hPopup = (HMENU) (LONG_PTR) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(3, HB_IT_BLOCK);
   /* Need form reference to store action - find form from popup parent */
   /* Walk open forms... For simplicity, pass form handle too */
   /* Actually, let's use UI_MenuItemAddEx with form handle */
   (void) hPopup; (void) pBlock;
   hb_retni( -1 );
}

/* UI_MenuItemAddEx( hForm, hPopup, cText, bBlock ) --> nIndex */
HB_FUNC( UI_MENUITEMADDEX )
{
   TForm * pForm = GetForm(1);
   HMENU hPopup = (HMENU) (LONG_PTR) hb_parnint(2);
   PHB_ITEM pBlock = hb_param(4, HB_IT_BLOCK);

   if( pForm && hPopup && HB_ISCHAR(3) )
      hb_retni( pForm->AddMenuItem( hPopup, hb_parc(3), pBlock ) );
   else
      hb_retni( -1 );
}

/* Load PNG as HBITMAP using GDI+ flat API (C-compatible, works with BCC) */

typedef int (__stdcall *PFN_GdiplusStartup)(ULONG_PTR*, void*, void*);
typedef void (__stdcall *PFN_GdiplusShutdown)(ULONG_PTR);
typedef int (__stdcall *PFN_GdipCreateBitmapFromFile)(const WCHAR*, void**);
typedef int (__stdcall *PFN_GdipCreateHBITMAPFromBitmap)(void*, HBITMAP*, DWORD);
typedef int (__stdcall *PFN_GdipDisposeImage)(void*);

static HMODULE    s_hGdiPlus = NULL;
static ULONG_PTR  s_gdipToken = 0;

static HBITMAP LoadPngAsBitmap( const char * szPath )
{
   WCHAR wPath[MAX_PATH];
   void * pBitmap = NULL;
   HBITMAP hBmp = NULL;

   if( !s_hGdiPlus )
   {
      s_hGdiPlus = LoadLibraryA( "gdiplus.dll" );
      if( !s_hGdiPlus ) return NULL;

      PFN_GdiplusStartup pStartup = (PFN_GdiplusStartup)
         GetProcAddress( s_hGdiPlus, "GdiplusStartup" );
      if( pStartup )
      {
         /* GdiplusStartupInput: version=1, rest=0 */
         BYTE input[16] = {0};
         *(UINT32*)input = 1;
         pStartup( &s_gdipToken, input, NULL );
      }
   }

   PFN_GdipCreateBitmapFromFile pFromFile = (PFN_GdipCreateBitmapFromFile)
      GetProcAddress( s_hGdiPlus, "GdipCreateBitmapFromFile" );
   PFN_GdipCreateHBITMAPFromBitmap pToHBmp = (PFN_GdipCreateHBITMAPFromBitmap)
      GetProcAddress( s_hGdiPlus, "GdipCreateHBITMAPFromBitmap" );
   PFN_GdipDisposeImage pDispose = (PFN_GdipDisposeImage)
      GetProcAddress( s_hGdiPlus, "GdipDisposeImage" );

   if( !pFromFile || !pToHBmp || !pDispose ) return NULL;

   MultiByteToWideChar( CP_ACP, 0, szPath, -1, wPath, MAX_PATH );

   if( pFromFile( wPath, &pBitmap ) != 0 || !pBitmap ) return NULL;

   pToHBmp( pBitmap, &hBmp, 0x00000000 ); /* bg = transparent black */
   pDispose( pBitmap );

   return hBmp;
}

/* UI_DropNonVisual( hForm, nType, cName, cIconPath ) - place a non-visual component icon on form */
HB_FUNC( UI_DROPNONVISUAL )
{
   TForm * form = GetForm(1);
   int nType = hb_parni(2);
   const char * cName = hb_parc(3);
   const char * cIconPath = HB_ISCHAR(4) ? hb_parc(4) : NULL;

   if( !form || !form->FHandle || !cName ) return;

   /* Find next available position (grid of 40x40, bottom area of form) */
   int nExisting = 0;
   int i;
   for( i = 0; i < form->FChildCount; i++ )
   {
      if( form->FChildren[i]->FControlType >= CT_TIMER )
         nExisting++;
   }
   int col = nExisting % 8;
   int row = nExisting / 8;
   int x = 8 + col * 40;
   int y = form->FHeight - 80 + row * 40;  /* bottom area of form */
   if( y < 40 ) y = 40;

   /* Create a static control with icon/text */
   TControl * ctrl = CreateControlByType( (BYTE) nType );
   if( !ctrl )
   {
      /* For unknown types, create a generic label */
      ctrl = new TLabel();
   }

   ctrl->FLeft = x;
   ctrl->FTop = y;
   ctrl->FWidth = 32;
   ctrl->FHeight = 32;
   ctrl->FControlType = (BYTE) nType;
   lstrcpynA( ctrl->FName, cName, sizeof(ctrl->FName) );
   lstrcpynA( ctrl->FText, cName, sizeof(ctrl->FText) );

   form->AddChild( ctrl );

   /* Create as a small static window with icon or text */
   HWND hChild = CreateWindowExA( 0, "STATIC", cName,
      WS_CHILD | WS_VISIBLE | SS_CENTER | SS_NOTIFY,
      x, y + form->FClientTop, 32, 32,
      form->FHandle, NULL, GetModuleHandle(NULL), NULL );

   if( hChild )
   {
      ctrl->FHandle = hChild;

      /* Try to load icon from PNG */
      if( cIconPath )
      {
         HBITMAP hBmp = LoadPngAsBitmap( cIconPath );
         if( hBmp )
         {
            /* Convert STATIC to SS_BITMAP and set the image */
            SetWindowLongA( hChild, GWL_STYLE,
               (GetWindowLongA(hChild, GWL_STYLE) & ~0xF) | SS_BITMAP );
            SendMessageA( hChild, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM) hBmp );
         }
      }

      /* Subclass for design-mode dragging */
      SetWindowLongPtr( hChild, GWLP_USERDATA, (LONG_PTR) ctrl );
   }

   /* Select the new component */
   form->SelectControl( ctrl, FALSE );
   form->UpdateOverlay();

   hb_retnint( (HB_PTRUINT) ctrl );
}

/* ================================================================
 * BUILD PROGRESS DIALOG
 * ================================================================ */

static HWND s_hProgressWnd = NULL;
static HWND s_hProgressBar = NULL;
static HWND s_hProgressLabel = NULL;

/* W32_ProgressOpen( cTitle, nSteps ) - show progress dialog */
HB_FUNC( W32_PROGRESSOPEN )
{
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Building...";
   int nSteps = HB_ISNUM(2) ? hb_parni(2) : 7;

   if( s_hProgressWnd ) {
      ShowWindow( s_hProgressWnd, SW_SHOW );
      SetForegroundWindow( s_hProgressWnd );
      return;
   }

   /* Register window class for progress dialog */
   {  static BOOL bReg = FALSE;
      if( !bReg ) {
         WNDCLASSEXA wc = { sizeof(WNDCLASSEXA) };
         wc.lpfnWndProc = DefWindowProcA;
         wc.hInstance = GetModuleHandle(NULL);
         wc.lpszClassName = "HbProgressDlg";
         wc.hCursor = LoadCursor( NULL, IDC_ARROW );
         wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
         RegisterClassExA( &wc );
         bReg = TRUE;
      }
   }

   int sw = GetSystemMetrics( SM_CXSCREEN );
   int sh = GetSystemMetrics( SM_CYSCREEN );
   int dlgW = 420, dlgH = 130;
   int x = (sw - dlgW) / 2, y = (sh - dlgH) / 2;

   s_hProgressWnd = CreateWindowExA( WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
      "HbProgressDlg", cTitle,
      WS_POPUP | WS_CAPTION | WS_VISIBLE,
      x, y, dlgW, dlgH, NULL, NULL, GetModuleHandle(NULL), NULL );

   /* Dark title bar */
   {  typedef HRESULT (WINAPI *PFN)(HWND, DWORD, LPCVOID, DWORD);
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         PFN pFn = (PFN)GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( pFn ) { BOOL val = TRUE; pFn( s_hProgressWnd, 20, &val, sizeof(val) ); }
         FreeLibrary( hDwm );
      }
   }

   HFONT hFont = (HFONT)GetStockObject( DEFAULT_GUI_FONT );

   /* Status label */
   s_hProgressLabel = CreateWindowExA( 0, "STATIC", "Preparing...",
      WS_CHILD | WS_VISIBLE | SS_LEFT,
      16, 12, dlgW - 40, 20, s_hProgressWnd, NULL, GetModuleHandle(NULL), NULL );
   SendMessageA( s_hProgressLabel, WM_SETFONT, (WPARAM) hFont, TRUE );

   /* Progress bar */
   s_hProgressBar = CreateWindowExA( 0, PROGRESS_CLASSA, NULL,
      WS_CHILD | WS_VISIBLE | PBS_SMOOTH,
      16, 40, dlgW - 40, 24, s_hProgressWnd, NULL, GetModuleHandle(NULL), NULL );
   SendMessageA( s_hProgressBar, PBM_SETRANGE, 0, MAKELPARAM(0, nSteps) );
   SendMessageA( s_hProgressBar, PBM_SETSTEP, 1, 0 );
   SendMessageA( s_hProgressBar, PBM_SETPOS, 0, 0 );

   /* Process messages so the dialog shows immediately */
   { MSG m; while( PeekMessage(&m, NULL, 0, 0, PM_REMOVE) )
     { TranslateMessage(&m); DispatchMessage(&m); } }
}

/* W32_ProgressStep( cText ) - advance progress and update label */
HB_FUNC( W32_PROGRESSSTEP )
{
   if( !s_hProgressWnd ) return;

   if( HB_ISCHAR(1) && s_hProgressLabel )
      SetWindowTextA( s_hProgressLabel, hb_parc(1) );

   if( s_hProgressBar )
      SendMessageA( s_hProgressBar, PBM_STEPIT, 0, 0 );

   UpdateWindow( s_hProgressWnd );

   /* Process messages to keep UI responsive */
   { MSG m; while( PeekMessage(&m, NULL, 0, 0, PM_REMOVE) )
     { TranslateMessage(&m); DispatchMessage(&m); } }
}

/* W32_ProgressClose() - close progress dialog */
HB_FUNC( W32_PROGRESSCLOSE )
{
   if( s_hProgressWnd )
   {
      DestroyWindow( s_hProgressWnd );
      s_hProgressWnd = NULL;
      s_hProgressBar = NULL;
      s_hProgressLabel = NULL;
   }
}

/* W32_BuildErrorDialog( cTitle, cLog ) - resizable dialog with selectable/copyable text */

static HWND s_errEdit = NULL;
static HWND s_errCopyBtn = NULL;

static LRESULT CALLBACK BuildErrProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_COMMAND:
      {
         int id = LOWORD(wParam);
         if( id == 1001 && s_errEdit )
         {
            /* Select all + copy */
            SendMessageA( s_errEdit, EM_SETSEL, 0, -1 );
            SendMessageA( s_errEdit, WM_COPY, 0, 0 );
            if( s_errCopyBtn )
               SetWindowTextA( s_errCopyBtn, "Copied!" );
            return 0;
         }
         if( id == 1002 || id == IDCANCEL )
         {
            PostQuitMessage( 0 );
            return 0;
         }
         break;
      }
      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         if( s_errEdit )
            MoveWindow( s_errEdit, 8, 8, w - 16, h - 56, TRUE );
         if( s_errCopyBtn )
            MoveWindow( s_errCopyBtn, w / 2 - 140, h - 40, 130, 30, TRUE );
         { HWND hClose = GetDlgItem( hWnd, 1002 );
           if( hClose ) MoveWindow( hClose, w / 2 + 10, h - 40, 130, 30, TRUE ); }
         return 0;
      }
      case WM_CLOSE:
         PostQuitMessage( 0 );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

HB_FUNC( W32_BUILDERRORDIALOG )
{
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Build Error";
   const char * cLog   = HB_ISCHAR(2) ? hb_parc(2) : "";

   /* Register class */
   {  static BOOL bReg = FALSE;
      if( !bReg ) {
         WNDCLASSEXA wc = { sizeof(WNDCLASSEXA) };
         wc.lpfnWndProc = BuildErrProc;
         wc.hInstance = GetModuleHandle(NULL);
         wc.lpszClassName = "HbBuildErr";
         wc.hCursor = LoadCursor( NULL, IDC_ARROW );
         wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
         RegisterClassExA( &wc );
         bReg = TRUE;
      }
   }

   int sw = GetSystemMetrics( SM_CXSCREEN );
   int sh = GetSystemMetrics( SM_CYSCREEN );
   int dlgW = 620, dlgH = 400;

   HWND hDlg = CreateWindowExA( WS_EX_TOPMOST, "HbBuildErr", cTitle,
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      (sw-dlgW)/2, (sh-dlgH)/2, dlgW, dlgH,
      NULL, NULL, GetModuleHandle(NULL), NULL );

   /* Dark title bar */
   {  typedef HRESULT (WINAPI *PFN)(HWND, DWORD, LPCVOID, DWORD);
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         PFN pFn = (PFN)GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( pFn ) { BOOL val = TRUE; pFn( hDlg, 20, &val, sizeof(val) ); }
         FreeLibrary( hDwm );
      }
   }

   HFONT hMono = CreateFontA( -18, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, "Consolas" );
   HFONT hGui = (HFONT) GetStockObject( DEFAULT_GUI_FONT );

   /* Convert LF to CRLF for Windows Edit control */
   char * cLogCRLF = NULL;
   {
      int len = (int) strlen( cLog );
      cLogCRLF = (char *) malloc( len * 2 + 1 );
      int j = 0;
      for( int k = 0; k < len; k++ )
      {
         if( cLog[k] == '\n' && ( k == 0 || cLog[k-1] != '\r' ) )
            cLogCRLF[j++] = '\r';
         cLogCRLF[j++] = cLog[k];
      }
      cLogCRLF[j] = 0;
   }

   /* Edit: full log, read-only, selectable, Ctrl+C works */
   s_errEdit = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", cLogCRLF,
      WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL |
      WS_VSCROLL | WS_HSCROLL | ES_AUTOHSCROLL,
      8, 8, dlgW - 32, dlgH - 90, hDlg, NULL, GetModuleHandle(NULL), NULL );
   SendMessageA( s_errEdit, WM_SETFONT, (WPARAM) hMono, TRUE );

   /* Copy button */
   s_errCopyBtn = CreateWindowExA( 0, "BUTTON", "Copy to Clipboard",
      WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
      dlgW/2 - 140, dlgH - 74, 130, 30, hDlg, (HMENU) 1001,
      GetModuleHandle(NULL), NULL );
   SendMessageA( s_errCopyBtn, WM_SETFONT, (WPARAM) hGui, TRUE );

   /* Close button */
   HWND hClose = CreateWindowExA( 0, "BUTTON", "Close",
      WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
      dlgW/2 + 10, dlgH - 74, 130, 30, hDlg, (HMENU) 1002,
      GetModuleHandle(NULL), NULL );
   SendMessageA( hClose, WM_SETFONT, (WPARAM) hGui, TRUE );

   /* Modal loop */
   { MSG msg;
     while( GetMessage( &msg, NULL, 0, 0 ) > 0 )
     {
        TranslateMessage( &msg );
        DispatchMessage( &msg );
     }
   }

   s_errEdit = NULL;
   s_errCopyBtn = NULL;
   DeleteObject( hMono );
   DestroyWindow( hDlg );
   if( cLogCRLF ) free( cLogCRLF );
}

/* UI_MenuSetBitmapByPos( hPopup, nPos, cPngPath ) - set PNG bitmap on menu item */
HB_FUNC( UI_MENUSETBITMAPBYPOS )
{
   HMENU hPopup = (HMENU)(LONG_PTR) hb_parnint(1);
   int nPos = hb_parni(2);
   const char * szPath = hb_parc(3);

   if( !hPopup || !szPath ) return;

   HBITMAP hBmp = LoadPngAsBitmap( szPath );
   if( !hBmp ) return;

   MENUITEMINFOA mii = { sizeof(mii) };
   mii.fMask = MIIM_BITMAP;
   mii.hbmpItem = hBmp;
   SetMenuItemInfoA( hPopup, nPos, TRUE, &mii );
}

/* UI_MenuSepAdd( hForm, hPopup ) */
HB_FUNC( UI_MENUSEPADD )
{
   TForm * pForm = GetForm(1);
   HMENU hPopup = (HMENU) (LONG_PTR) hb_parnint(2);
   if( pForm && hPopup )
      pForm->AddMenuSeparator( hPopup );
}

/* ======================================================================
 * Component Palette
 * ====================================================================== */

/* UI_PaletteNew( hForm ) --> hPalette */
HB_FUNC( UI_PALETTENEW )
{
   TForm * pForm = GetForm(1);
   TComponentPalette * p = new TComponentPalette();

   if( pForm )
   {
      pForm->FPalette = p;
      p->FCtrlParent = pForm;
      p->FParent = pForm;
   }

   RetCtrl( p );
}

/* UI_PaletteAddTab( hPalette, cName ) --> nTabIndex */
HB_FUNC( UI_PALETTEADDTAB )
{
   TComponentPalette * p = (TComponentPalette *) GetCtrl(1);
   if( p && p->FControlType == CT_TABCONTROL && HB_ISCHAR(2) )
      hb_retni( p->AddTab( hb_parc(2) ) );
   else
      hb_retni( -1 );
}

/* UI_PaletteAddComp( hPalette, nTab, cText, cTooltip, nCtrlType ) */
HB_FUNC( UI_PALETTEADDCOMP )
{
   TComponentPalette * p = (TComponentPalette *) GetCtrl(1);
   if( p && p->FControlType == CT_TABCONTROL )
      p->AddComponent( hb_parni(2), hb_parc(3),
         HB_ISCHAR(4) ? hb_parc(4) : "", hb_parni(5) );
}

/* UI_PaletteLoadImages( hPalette, cBmpPath ) */
HB_FUNC( UI_PALETTELOADIMAGES )
{
   TComponentPalette * p = (TComponentPalette *) GetCtrl(1);
   if( p && p->FControlType == CT_TABCONTROL && HB_ISCHAR(2) )
      p->LoadImages( hb_parc(2) );
}

/* UI_PaletteAppendImages( hPalette, cBmpPath ) - append more icons to existing ImageList */
HB_FUNC( UI_PALETTEAPPENDIMAGES )
{
   TComponentPalette * p = (TComponentPalette *) GetCtrl(1);
   if( p && p->FControlType == CT_TABCONTROL && HB_ISCHAR(2) )
      p->AppendImages( hb_parc(2) );
}

/* UI_PaletteOnSelect( hPalette, bBlock ) */
HB_FUNC( UI_PALETTEONSELECT )
{
   TComponentPalette * p = (TComponentPalette *) GetCtrl(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p && p->FControlType == CT_TABCONTROL && pBlock )
   {
      if( p->FOnSelect ) hb_itemRelease( p->FOnSelect );
      p->FOnSelect = hb_itemNew( pBlock );
   }
}

/* ======================================================================
 * StatusBar
 * ====================================================================== */

/* UI_StatusBarCreate( hForm ) - marks form to create a statusbar during Run/Show */
HB_FUNC( UI_STATUSBARCREATE )
{
   TForm * p = GetForm(1);
   if( p ) p->FHasStatusBar = TRUE;
}

/* UI_StatusBarSetText( hForm, nPanel, cText ) */
HB_FUNC( UI_STATUSBARSETTEXT )
{
   TForm * p = GetForm(1);
   int nPanel = hb_parni(2);
   if( p && p->FStatusBar && HB_ISCHAR(3) )
      SendMessageA( p->FStatusBar, SB_SETTEXTA, nPanel, (LPARAM) hb_parc(3) );
}

/* UI_FormSelectCtrl( hForm, hCtrl ) - select a control in design mode */
/* UI_FormSelectCtrl( hForm, hCtrl ) - select a control in design mode
 * Called from inspector combo - suppresses FOnSelChange to avoid recursion */
HB_FUNC( UI_FORMSELECTCTRL )
{
   TForm * pForm = GetForm(1);
   TControl * pCtrl = GetCtrl(2);
   if( pForm && pForm->FDesignMode )
   {
      /* Suppress notification to avoid combo->select->refresh->combo loop */
      PHB_ITEM pSaved = pForm->FOnSelChange;
      pForm->FOnSelChange = NULL;

      if( pCtrl && pCtrl != (TControl*)pForm )
      {
         pForm->SelectControl( pCtrl, FALSE );
         /* Bring selected control's HWND to top z-order */
         if( pCtrl->FHandle )
            SetWindowPos( pCtrl->FHandle, HWND_TOP, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE );
      }
      else
         pForm->ClearSelection();

      pForm->FOnSelChange = pSaved;

      /* Bring the design form to the foreground so handles are visible */
      if( pForm->FHandle )
      {
         ShowWindow( pForm->FHandle, SW_SHOW );
         SetWindowPos( pForm->FHandle, HWND_TOP, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE );
         InvalidateRect( pForm->FHandle, NULL, TRUE );
      }
   }
}

/* UI_FormSetSizable( hForm, lSizable ) */
HB_FUNC( UI_FORMSETSIZABLE )
{
   TForm * p = GetForm(1);
   if( p ) p->FSizable = hb_parl(2);
}

/* UI_FormSetAppBar( hForm, lAppBar ) */
HB_FUNC( UI_FORMSETAPPBAR )
{
   TForm * p = GetForm(1);
   if( p ) p->FAppBar = hb_parl(2);
}

/* UI_FormSetPos( hForm, nLeft, nTop ) - set screen position */
HB_FUNC( UI_FORMSETPOS )
{
   TForm * p = GetForm(1);
   if( p )
   {
      p->FLeft = hb_parni(2);
      p->FTop = hb_parni(3);
      p->FCenter = FALSE;
      if( p->FHandle )
         SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop, 0, 0,
            SWP_NOSIZE | SWP_NOZORDER );
   }
}

/* UI_FormSetBgColor( hForm, nRGB ) - set background color */
HB_FUNC( UI_FORMSETBGCOLOR )
{
   TForm * p = GetForm(1);
   if( p )
   {
      COLORREF clr = (COLORREF) hb_parnl(2);
      p->FClrPane = clr;
      if( p->FBkBrush ) DeleteObject( p->FBkBrush );
      p->FBkBrush = CreateSolidBrush( clr );
      /* Invalidate cached grid bitmap so it's rebuilt with new bg */
      if( p->FGridBmp ) { SelectObject( p->FGridDC, NULL ); DeleteObject( p->FGridBmp ); DeleteDC( p->FGridDC ); p->FGridBmp = NULL; }
      if( p->FHandle ) InvalidateRect( p->FHandle, NULL, TRUE );
   }
}

/* UI_FormGetHwnd( hForm ) --> nHwnd */
HB_FUNC( UI_FORMGETHWND )
{
   TForm * p = GetForm(1);
   hb_retnint( p && p->FHandle ? (HB_PTRUINT) p->FHandle : 0 );
}

/* ======================================================================
 * Networking - HTTP Client (simple WinHTTP wrapper)
 * ====================================================================== */

/* UI_HttpGet( cURL ) --> cResponse */
HB_FUNC( UI_HTTPGET )
{
   /* Placeholder - in production uses WinHTTP/libcurl */
   const char * url = hb_parc(1);
   char buf[256];
   if( url )
      sprintf( buf, "HTTP GET %s -> 200 OK (placeholder)", url );
   else
      strcpy( buf, "" );
   hb_retc( buf );
}

/* UI_HttpPost( cURL, cBody ) --> cResponse */
HB_FUNC( UI_HTTPPOST )
{
   const char * url = hb_parc(1);
   const char * body = hb_parc(2);
   char buf[256];
   if( url )
      sprintf( buf, "HTTP POST %s [%d bytes] -> 200 OK (placeholder)",
               url, body ? (int)strlen(body) : 0 );
   else
      strcpy( buf, "" );
   hb_retc( buf );
}

/* UI_WebServerStart( nPort ) --> lSuccess */
HB_FUNC( UI_WEBSERVERSTART )
{
   int nPort = hb_parni(1);
   if( nPort <= 0 ) nPort = 8080;
   /* Placeholder - in production creates a listening socket + thread pool */
   hb_retl( TRUE );
}

/* UI_WebServerStop() */
HB_FUNC( UI_WEBSERVERSTOP )
{
   /* Placeholder */
}

/* UI_TcpConnect( cHost, nPort ) --> nSocket */
HB_FUNC( UI_TCPCONNECT )
{
   /* Placeholder - returns simulated socket handle */
   hb_retnint( 1001 );
}

/* UI_TcpSend( nSocket, cData ) --> nBytesSent */
HB_FUNC( UI_TCPSEND )
{
   hb_retni( HB_ISCHAR(2) ? (int) hb_parclen(2) : 0 );
}

/* UI_TcpRecv( nSocket, nMaxBytes ) --> cData */
HB_FUNC( UI_TCPRECV )
{
   hb_retc( "(no data - placeholder)" );
}

/* UI_TcpClose( nSocket ) */
HB_FUNC( UI_TCPCLOSE )
{
   /* Placeholder */
}

/* ======================================================================
 * Threading - Harbour thread wrappers
 * ====================================================================== */

/* UI_ThreadStart( bBlock ) --> nThreadId */
HB_FUNC( UI_THREADSTART )
{
   /* Placeholder - in production uses hb_threadStart() */
   /* PHB_ITEM pBlock = hb_param(1, HB_IT_BLOCK); */
   hb_retnint( 1 );  /* simulated thread ID */
}

/* UI_ThreadWait( nThreadId ) */
HB_FUNC( UI_THREADWAIT )
{
   /* Placeholder - in production uses hb_threadWait() */
}

/* UI_ThreadSleep( nMilliseconds ) */
HB_FUNC( UI_THREADSLEEP )
{
   int nMs = hb_parni(1);
   if( nMs > 0 )
      Sleep( nMs );
}

/* UI_MutexCreate() --> nMutex */
HB_FUNC( UI_MUTEXCREATE )
{
   HANDLE hMutex = CreateMutexA( NULL, FALSE, NULL );
   hb_retnint( (HB_PTRUINT) hMutex );
}

/* UI_MutexLock( nMutex ) */
HB_FUNC( UI_MUTEXLOCK )
{
   HANDLE hMutex = (HANDLE)(HB_PTRUINT) hb_parnint(1);
   if( hMutex )
      WaitForSingleObject( hMutex, INFINITE );
}

/* UI_MutexUnlock( nMutex ) */
HB_FUNC( UI_MUTEXUNLOCK )
{
   HANDLE hMutex = (HANDLE)(HB_PTRUINT) hb_parnint(1);
   if( hMutex )
      ReleaseMutex( hMutex );
}

/* UI_MutexDestroy( nMutex ) */
HB_FUNC( UI_MUTEXDESTROY )
{
   HANDLE hMutex = (HANDLE)(HB_PTRUINT) hb_parnint(1);
   if( hMutex )
      CloseHandle( hMutex );
}

/* UI_CriticalSectionCreate() --> nCS */
HB_FUNC( UI_CRITICALSECTIONCREATE )
{
   CRITICAL_SECTION * pCS = (CRITICAL_SECTION *) malloc( sizeof(CRITICAL_SECTION) );
   InitializeCriticalSection( pCS );
   hb_retnint( (HB_PTRUINT) pCS );
}

/* UI_CriticalSectionEnter( nCS ) */
HB_FUNC( UI_CRITICALSECTIONENTER )
{
   CRITICAL_SECTION * pCS = (CRITICAL_SECTION *)(HB_PTRUINT) hb_parnint(1);
   if( pCS )
      EnterCriticalSection( pCS );
}

/* UI_CriticalSectionLeave( nCS ) */
HB_FUNC( UI_CRITICALSECTIONLEAVE )
{
   CRITICAL_SECTION * pCS = (CRITICAL_SECTION *)(HB_PTRUINT) hb_parnint(1);
   if( pCS )
      LeaveCriticalSection( pCS );
}

/* UI_CriticalSectionDestroy( nCS ) */
HB_FUNC( UI_CRITICALSECTIONDESTROY )
{
   CRITICAL_SECTION * pCS = (CRITICAL_SECTION *)(HB_PTRUINT) hb_parnint(1);
   if( pCS ) {
      DeleteCriticalSection( pCS );
      free( pCS );
   }
}

/* UI_AtomicIncrement( @nValue ) --> nNewValue */
HB_FUNC( UI_ATOMICINCREMENT )
{
   /* Simple atomic increment using InterlockedIncrement */
   long val = (long) hb_parnl(1);
   val = InterlockedIncrement( &val );
   hb_retnl( val );
}

/* UI_AtomicDecrement( @nValue ) --> nNewValue */
HB_FUNC( UI_ATOMICDECREMENT )
{
   long val = (long) hb_parnl(1);
   val = InterlockedDecrement( &val );
   hb_retnl( val );
}

/* UI_FormSetPending( hForm, nControlType ) - set pending control type for palette drop */
HB_FUNC( UI_FORMSETPENDING )
{
   TForm * p = GetForm(1);
   if( p )
   {
      p->FPendingControlType = hb_parni(2);
      if( p->FPendingControlType >= 0 && p->FHandle )
         SetCursor( LoadCursor(NULL, IDC_CROSS) );
      else if( p->FHandle )
         SetCursor( LoadCursor(NULL, IDC_ARROW) );
   }
}

/* UI_SetDesignForm( hForm ) - set active design form (used by palette drop) */
TForm * g_designForm = NULL;

HB_FUNC( UI_SETDESIGNFORM )
{
   TForm * p = GetForm(1);
   g_designForm = p;
}

/* UI_FormBringToFront( hForm ) */
HB_FUNC( UI_FORMBRINGTOFRONT )
{
   TForm * p = GetForm(1);
   if( p && p->FHandle )
      SetWindowPos( p->FHandle, HWND_TOP, 0, 0, 0, 0,
         SWP_NOMOVE | SWP_NOSIZE );
}

/* UI_FormOnComponentDrop( hForm, bBlock ) - set callback for component palette drop */
HB_FUNC( UI_FORMONCOMPONENTDROP )
{
   TForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p )
   {
      if( p->FOnComponentDrop ) hb_itemRelease( p->FOnComponentDrop );
      p->FOnComponentDrop = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* UI_FormSetActivateApp( hForm, bBlock ) - set callback for WM_ACTIVATEAPP */
HB_FUNC( UI_FORMSETACTIVATEAPP )
{
   TForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p )
   {
      if( p->FOnActivateApp ) hb_itemRelease( p->FOnActivateApp );
      p->FOnActivateApp = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* UI_FormAlignSelected( hForm, nMode ) - align selected controls
 * Modes: 1=left, 2=right, 3=top, 4=bottom, 5=centerH, 6=centerV, 7=spaceH, 8=spaceV */
HB_FUNC( UI_FORMALIGNSELECTED )
{
   TForm * form = GetForm(1);
   int nMode = hb_parni(2);
   int nSel, i;

   if( !form || nMode < 1 || nMode > 8 ) return;
   nSel = form->FSelCount;
   if( nSel < 2 ) return;

   TControl * ref = form->FSelected[0];
   int refX = ref->FLeft, refY = ref->FTop;
   int refR = refX + ref->FWidth, refB = refY + ref->FHeight;
   int refCX = refX + ref->FWidth / 2, refCY = refY + ref->FHeight / 2;

   int minX = refX, maxR = refR, minY = refY, maxB = refB;
   for( i = 1; i < nSel; i++ ) {
      TControl * c = form->FSelected[i];
      if( c->FLeft < minX ) minX = c->FLeft;
      if( c->FLeft + c->FWidth > maxR ) maxR = c->FLeft + c->FWidth;
      if( c->FTop < minY ) minY = c->FTop;
      if( c->FTop + c->FHeight > maxB ) maxB = c->FTop + c->FHeight;
   }

   for( i = 1; i < nSel; i++ )
   {
      TControl * c = form->FSelected[i];
      int newX = c->FLeft, newY = c->FTop;

      switch( nMode ) {
         case 1: newX = refX; break;
         case 2: newX = refR - c->FWidth; break;
         case 3: newY = refY; break;
         case 4: newY = refB - c->FHeight; break;
         case 5: newX = refCX - c->FWidth / 2; break;
         case 6: newY = refCY - c->FHeight / 2; break;
         case 7: case 8:
         {
            int totalW = 0, totalH = 0, gap, j;
            for( j = 0; j < nSel; j++ ) {
               totalW += form->FSelected[j]->FWidth;
               totalH += form->FSelected[j]->FHeight;
            }
            if( nMode == 7 ) {
               gap = (nSel > 1) ? (maxR - minX - totalW) / (nSel - 1) : 0;
               int cx = minX;
               for( j = 0; j < nSel; j++ ) {
                  TControl * cj = form->FSelected[j];
                  cj->FLeft = cx;
                  if( cj->FHandle ) SetWindowPos( cj->FHandle, NULL, cx, cj->FTop, 0, 0, SWP_NOSIZE | SWP_NOZORDER );
                  cx += cj->FWidth + gap;
               }
            } else {
               gap = (nSel > 1) ? (maxB - minY - totalH) / (nSel - 1) : 0;
               int cy = minY;
               for( j = 0; j < nSel; j++ ) {
                  TControl * cj = form->FSelected[j];
                  cj->FTop = cy;
                  if( cj->FHandle ) SetWindowPos( cj->FHandle, NULL, cj->FLeft, cy, 0, 0, SWP_NOSIZE | SWP_NOZORDER );
                  cy += cj->FHeight + gap;
               }
            }
            if( form->FHandle ) InvalidateRect( form->FHandle, NULL, TRUE );
            return;
         }
      }

      c->FLeft = newX; c->FTop = newY;
      if( c->FHandle ) SetWindowPos( c->FHandle, NULL, newX, newY, 0, 0, SWP_NOSIZE | SWP_NOZORDER );
   }

   if( form->FHandle ) InvalidateRect( form->FHandle, NULL, TRUE );
}

/* ================================================================
 * DEBUGGER ENGINE - IDE_Debug* functions
 * Port of the GTK3/Cocoa debugger to WinAPI.
 * Uses Harbour VM debug hooks (hbapidbg.h).
 * ================================================================ */

#include <hbapidbg.h>

/* Debugger states */
#define DBG_IDLE      0
#define DBG_RUNNING   1
#define DBG_PAUSED    2
#define DBG_STEPPING  3
#define DBG_STEPOVER  4
#define DBG_STOPPED   5

static int           s_dbgState = DBG_IDLE;
static int           s_dbgLine = 0;
static int           s_dbgStepDepth = 0;
static char          s_dbgModule[256] = "";
static PHB_ITEM      s_dbgOnPause = NULL;

/* Breakpoints */
#define DBG_MAX_BP 64
typedef struct { char module[256]; int line; } DBGBP;
static DBGBP s_breakpoints[DBG_MAX_BP];
static int   s_nBreakpoints = 0;

/* Debug panel UI handles */
static HWND s_hDbgWnd = NULL;
static HWND s_dbgTabCtrl = NULL;
static HWND s_dbgLocalsLV = NULL;
static HWND s_dbgStackLV = NULL;
static HWND s_dbgBpLV = NULL;
static HWND s_dbgWatchLV = NULL;
static HWND s_dbgOutputEdit = NULL;
static HWND s_dbgStatusLbl = NULL;
static HWND s_dbgToolbar = NULL;

/* Socket-based debugger (port 19800) — matches macOS/Linux architecture */
static SOCKET       s_dbgServerSock = INVALID_SOCKET;
static SOCKET       s_dbgClientSock = INVALID_SOCKET;
static char         s_dbgRecvBuf[8192];
static int          s_dbgRecvLen = 0;
static BOOL         s_wsaInited = FALSE;

static void DbgWsaInit(void)
{
   if( !s_wsaInited ) {
      WSADATA wsa;
      WSAStartup( MAKEWORD(2,2), &wsa );
      s_wsaInited = TRUE;
   }
}

static int DbgServerStart( int port )
{
   struct sockaddr_in addr;
   int yes = 1;

   DbgWsaInit();

   s_dbgServerSock = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
   if( s_dbgServerSock == INVALID_SOCKET ) return -1;

   setsockopt( s_dbgServerSock, SOL_SOCKET, SO_REUSEADDR, (const char *)&yes, sizeof(yes) );

   memset( &addr, 0, sizeof(addr) );
   addr.sin_family = AF_INET;
   addr.sin_addr.s_addr = htonl( INADDR_LOOPBACK );
   addr.sin_port = htons( (u_short)port );

   if( bind( s_dbgServerSock, (struct sockaddr *)&addr, sizeof(addr) ) == SOCKET_ERROR ||
       listen( s_dbgServerSock, 1 ) == SOCKET_ERROR )
   {
      closesocket( s_dbgServerSock );
      s_dbgServerSock = INVALID_SOCKET;
      return -1;
   }
   return 0;
}

static int DbgServerAccept( double timeoutSec )
{
   fd_set fds;
   struct timeval tv;
   double elapsed = 0;
   MSG winMsg;

   while( elapsed < timeoutSec )
   {
      FD_ZERO( &fds );
      FD_SET( s_dbgServerSock, &fds );
      tv.tv_sec = 0; tv.tv_usec = 200000;

      if( select( 0, &fds, NULL, NULL, &tv ) > 0 )
      {
         s_dbgClientSock = accept( s_dbgServerSock, NULL, NULL );
         if( s_dbgClientSock != INVALID_SOCKET ) return 0;
      }

      /* Pump Win32 messages while waiting */
      while( PeekMessage( &winMsg, NULL, 0, 0, PM_REMOVE ) )
      {
         TranslateMessage( &winMsg );
         DispatchMessage( &winMsg );
      }
      if( s_dbgState == DBG_STOPPED ) return -1;
      elapsed += 0.25;
   }
   return -1;
}

static void DbgServerSend( const char * cmd )
{
   char buf[512];
   if( s_dbgClientSock == INVALID_SOCKET ) return;
   snprintf( buf, sizeof(buf), "%s\n", cmd );
   send( s_dbgClientSock, buf, (int)strlen(buf), 0 );
}

/* Receive one complete line from the debug client (line-buffered).
 * Returns length of line (without \n), or -1 on disconnect. */
static int DbgServerRecv( char * buf, int bufSize )
{
   fd_set fds;
   struct timeval tv;
   MSG winMsg;

   if( s_dbgClientSock == INVALID_SOCKET ) return -1;

   while(1) {
      /* Check if we already have a complete line in the buffer */
      int i;
      for( i = 0; i < s_dbgRecvLen; i++ )
      {
         if( s_dbgRecvBuf[i] == '\n' )
         {
            int lineLen = i;
            while( lineLen > 0 && s_dbgRecvBuf[lineLen-1] == '\r' ) lineLen--;
            if( lineLen >= bufSize ) lineLen = bufSize - 1;
            memcpy( buf, s_dbgRecvBuf, (size_t)lineLen );
            buf[lineLen] = 0;
            int consumed = i + 1;
            s_dbgRecvLen -= consumed;
            if( s_dbgRecvLen > 0 )
               memmove( s_dbgRecvBuf, s_dbgRecvBuf + consumed, (size_t)s_dbgRecvLen );
            return lineLen;
         }
      }

      /* No complete line yet — read more data */
      FD_ZERO( &fds );
      FD_SET( s_dbgClientSock, &fds );
      tv.tv_sec = 0; tv.tv_usec = 100000;
      int r = select( 0, &fds, NULL, NULL, &tv );
      if( r > 0 ) {
         int space = (int)sizeof(s_dbgRecvBuf) - s_dbgRecvLen - 1;
         if( space <= 0 ) { s_dbgRecvLen = 0; continue; }
         int n = recv( s_dbgClientSock, s_dbgRecvBuf + s_dbgRecvLen, space, 0 );
         if( n <= 0 ) return -1;
         s_dbgRecvLen += n;
      }

      /* Pump Win32 messages while waiting */
      while( PeekMessage( &winMsg, NULL, 0, 0, PM_REMOVE ) )
      {
         TranslateMessage( &winMsg );
         DispatchMessage( &winMsg );
      }
      if( s_dbgState == DBG_STOPPED ) return -1;
   }
}

static void DbgServerStop(void)
{
   if( s_dbgClientSock != INVALID_SOCKET ) { closesocket( s_dbgClientSock ); s_dbgClientSock = INVALID_SOCKET; }
   if( s_dbgServerSock != INVALID_SOCKET ) { closesocket( s_dbgServerSock ); s_dbgServerSock = INVALID_SOCKET; }
   s_dbgRecvLen = 0;
}

static int DbgIsBreakpoint( const char * module, int line )
{
   int i;
   for( i = 0; i < s_nBreakpoints; i++ )
      if( s_breakpoints[i].line == line &&
          ( s_breakpoints[i].module[0] == 0 ||
            strstr( module, s_breakpoints[i].module ) != NULL ) )
         return 1;
   return 0;
}

static void DbgOutput( const char * text )
{
   if( !s_dbgOutputEdit ) return;
   int len = GetWindowTextLengthA( s_dbgOutputEdit );
   SendMessageA( s_dbgOutputEdit, EM_SETSEL, (WPARAM)len, (LPARAM)len );
   SendMessageA( s_dbgOutputEdit, EM_REPLACESEL, FALSE, (LPARAM)text );
}

/* Debug hook - called by Harbour VM on every line */
static void IDE_DebugHook( int nMode, int nLine, const char * szName,
                            int nIndex, PHB_ITEM pFrame )
{
   (void)nIndex; (void)pFrame;

   if( nMode == 1 && szName ) /* HB_DBG_MODULENAME */
      strncpy( s_dbgModule, szName, sizeof(s_dbgModule) - 1 );

   if( nMode != 5 ) return; /* Only process HB_DBG_SHOWLINE */

   s_dbgLine = nLine;
   if( s_dbgState == DBG_STOPPED ) return;

   if( s_dbgState == DBG_RUNNING && !DbgIsBreakpoint( s_dbgModule, nLine ) )
      return;

   if( s_dbgState == DBG_STEPOVER )
   {
      HB_ULONG curDepth = hb_dbg_ProcLevel();
      if( (int)curDepth > s_dbgStepDepth ) return;
   }

   /* === PAUSE === */
   s_dbgState = DBG_PAUSED;

   /* Notify Harbour callback */
   if( s_dbgOnPause && HB_IS_BLOCK( s_dbgOnPause ) )
   {
      PHB_ITEM pMod  = hb_itemPutC( NULL, s_dbgModule );
      PHB_ITEM pLine = hb_itemPutNI( NULL, nLine );
      hb_itemDo( s_dbgOnPause, 2, pMod, pLine );
      hb_itemRelease( pMod );
      hb_itemRelease( pLine );
   }

   { char msg[512];
     snprintf( msg, sizeof(msg), "Paused at %s:%d\r\n", s_dbgModule, nLine );
     DbgOutput( msg );
   }

   /* Process Win32 messages while paused (keeps UI responsive) */
   {  MSG winMsg;
      while( s_dbgState == DBG_PAUSED )
      {
         if( PeekMessage( &winMsg, NULL, 0, 0, PM_REMOVE ) )
         {
            TranslateMessage( &winMsg );
            DispatchMessage( &winMsg );
         }
         else
            Sleep( 10 );
      }
   }

   if( s_dbgState == DBG_STOPPED )
      DbgOutput( "Debug session stopped.\r\n" );
}

/* IDE_DebugStart( cHrbFile, bOnPause ) */
HB_FUNC( IDE_DEBUGSTART )
{
   const char * cHrbFile = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   if( !cHrbFile || s_dbgState != DBG_IDLE ) { hb_retl( HB_FALSE ); return; }

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Install debug hook */
   hb_dbg_SetEntry( IDE_DebugHook );
   s_dbgState = DBG_STEPPING;
   s_nBreakpoints = 0;

   DbgOutput( "=== Debug session started ===\r\n" );
   { char msg[512]; snprintf( msg, sizeof(msg), "Loading: %s\r\n", cHrbFile ); DbgOutput( msg ); }

   /* Execute .hrb via Harbour's HB_HRBRUN */
   {
      PHB_DYNS pDyn = hb_dynsymFind( "HB_HRBRUN" );
      if( pDyn )
      {
         PHB_ITEM pFile = hb_itemPutC( NULL, cHrbFile );
         hb_vmPushDynSym( pDyn );
         hb_vmPushNil();
         hb_vmPush( pFile );
         hb_vmDo( 1 );
         hb_itemRelease( pFile );
      }
      else
         DbgOutput( "ERROR: HB_HRBRUN symbol not found.\r\n" );
   }

   hb_dbg_SetEntry( NULL );
   s_dbgState = DBG_IDLE;
   DbgOutput( "=== Debug session ended ===\r\n" );
   hb_retl( HB_TRUE );
}

/* IDE_DebugGo() - continue execution */
HB_FUNC( IDE_DEBUGGO )
{
   if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_RUNNING;
}

/* IDE_DebugStep() - step into */
HB_FUNC( IDE_DEBUGSTEP )
{
   if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_STEPPING;
}

/* IDE_DebugStepOver() */
HB_FUNC( IDE_DEBUGSTEPOVER )
{
   if( s_dbgState == DBG_PAUSED ) {
      s_dbgStepDepth = (int) hb_dbg_ProcLevel();
      s_dbgState = DBG_STEPOVER;
   }
}

/* IDE_DebugStop() */
HB_FUNC( IDE_DEBUGSTOP )
{
   if( s_dbgState != DBG_IDLE ) s_dbgState = DBG_STOPPED;
}

/* IDE_DebugAddBreakpoint( cModule, nLine ) */
HB_FUNC( IDE_DEBUGADDBREAKPOINT )
{
   if( s_nBreakpoints >= DBG_MAX_BP ) return;
   const char * mod = HB_ISCHAR(1) ? hb_parc(1) : "";
   strncpy( s_breakpoints[s_nBreakpoints].module, mod, 255 );
   s_breakpoints[s_nBreakpoints].line = hb_parni(2);
   s_nBreakpoints++;
}

/* IDE_DebugClearBreakpoints() */
HB_FUNC( IDE_DEBUGCLEARBREAKPOINTS )
{
   s_nBreakpoints = 0;
}

/* IDE_DebugGetState() -> nState */
HB_FUNC( IDE_DEBUGGETSTATE )
{
   hb_retni( s_dbgState );
}

/* IDE_DebugGetLine() -> nLine */
HB_FUNC( IDE_DEBUGGETLINE )
{
   hb_retni( s_dbgLine );
}

/* IDE_DebugGetModule() -> cModule */
HB_FUNC( IDE_DEBUGGETMODULE )
{
   hb_retc( s_dbgModule );
}

/* IDE_DebugGetLocals( nLevel ) -> { { cName, cValue, cType }, ... } */
HB_FUNC( IDE_DEBUGGETLOCALS )
{
   int nLevel = HB_ISNUM(1) ? hb_parni(1) : 1;
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   int i;

   for( i = 1; i <= 30; i++ )
   {
      PHB_ITEM pVal = hb_dbg_vmVarLGet( nLevel, i );
      if( !pVal ) break;

      PHB_ITEM pEntry = hb_itemArrayNew( 3 );
      char szName[32], szValue[256], szType[32];
      snprintf( szName, sizeof(szName), "Local_%d", i );

      switch( hb_itemType( pVal ) )
      {
         case HB_IT_STRING:
            snprintf( szValue, sizeof(szValue), "\"%.*s\"",
               (int)(hb_itemGetCLen(pVal) > 200 ? 200 : hb_itemGetCLen(pVal)),
               hb_itemGetCPtr(pVal) );
            strcpy( szType, "String" ); break;
         case HB_IT_INTEGER: case HB_IT_LONG: case HB_IT_NUMERIC:
            snprintf( szValue, sizeof(szValue), "%g", hb_itemGetND(pVal) );
            strcpy( szType, "Numeric" ); break;
         case HB_IT_LOGICAL:
            strcpy( szValue, hb_itemGetL(pVal) ? ".T." : ".F." );
            strcpy( szType, "Logical" ); break;
         case HB_IT_NIL:
            strcpy( szValue, "NIL" ); strcpy( szType, "NIL" ); break;
         case HB_IT_ARRAY:
            snprintf( szValue, sizeof(szValue), "Array(%lu)", (unsigned long)hb_arrayLen(pVal) );
            strcpy( szType, "Array" ); break;
         case HB_IT_BLOCK:
            strcpy( szValue, "{||}" ); strcpy( szType, "Block" ); break;
         default:
            if( hb_itemType(pVal) & HB_IT_OBJECT )
               { strcpy( szValue, "(object)" ); strcpy( szType, "Object" ); }
            else
               { strcpy( szValue, "(?)" ); strcpy( szType, "?" ); }
            break;
      }
      hb_arraySetC( pEntry, 1, szName );
      hb_arraySetC( pEntry, 2, szValue );
      hb_arraySetC( pEntry, 3, szType );
      hb_arrayAdd( pArray, pEntry );
      hb_itemRelease( pEntry );
   }
   hb_itemReturnRelease( pArray );
}

/* Debug trace log */
static void DbgTrace( const char * msg )
{
   FILE * f = fopen( "c:\\hbbuilder_debug\\dbg_trace_c.log", "a" );
   if( f ) { fprintf( f, "%s\n", msg ); fclose( f ); }
}

/* IDE_DebugStart2( cExePath, bOnPause ) — socket-based debug session
 * Mirrors the macOS/Linux implementation: starts TCP server on port 19800,
 * launches user exe as separate process, communicates via socket protocol. */
HB_FUNC( IDE_DEBUGSTART2 )
{
   const char * cExePath = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   /* Clear trace log */
   { FILE * f = fopen("c:\\hbbuilder_debug\\dbg_trace_c.log","w"); if(f) fclose(f); }

   { char t[512]; snprintf(t,sizeof(t),"IDE_DebugStart2: exe='%s' block=%p state=%d", cExePath?cExePath:"(null)", pOnPause, s_dbgState); DbgTrace(t); }

   if( !cExePath || s_dbgState != DBG_IDLE ) { DbgTrace("REJECTED: null exe or state != IDLE"); hb_retl( HB_FALSE ); return; }

   /* Clean up any previous debug session */
   DbgServerStop();
   /* Kill any leftover DebugApp */
   system( "taskkill /F /IM DebugApp.exe >nul 2>&1" );

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Start TCP server */
   DbgTrace("Starting TCP server on port 19800...");
   if( DbgServerStart( 19800 ) != 0 )
   {
      DbgTrace("DbgServerStart FAILED");
      DbgOutput( "ERROR: Could not start debug server on port 19800\r\n" );
      hb_retl( HB_FALSE );
      return;
   }
   DbgTrace("TCP server started OK");

   s_dbgState = DBG_STEPPING;
   s_nBreakpoints = 0;
   DbgOutput( "=== Debug session started (socket) ===\r\n" );
   DbgOutput( "Listening on port 19800...\r\n" );

   /* Launch user executable as separate process */
   {
      STARTUPINFOA si;
      PROCESS_INFORMATION pi;
      char cmd[1024];
      snprintf( cmd, sizeof(cmd), "\"%s\"", cExePath );
      memset( &si, 0, sizeof(si) );
      si.cb = sizeof(si);
      si.dwFlags = STARTF_USESHOWWINDOW;
      si.wShowWindow = SW_SHOW;
      memset( &pi, 0, sizeof(pi) );
      { char t[1024]; snprintf(t,sizeof(t),"CreateProcessA cmd='%s'", cmd); DbgTrace(t); }
      if( !CreateProcessA( NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi ) )
      {
         char err[512];
         snprintf( err, sizeof(err), "ERROR: Could not launch %s (GetLastError=%lu)\r\n", cExePath, GetLastError() );
         DbgTrace( err );
         DbgOutput( err );
         DbgServerStop();
         s_dbgState = DBG_IDLE;
         hb_retl( HB_FALSE );
         return;
      }
      DbgTrace("CreateProcessA OK");
      if( pi.hProcess ) CloseHandle( pi.hProcess );
      if( pi.hThread ) CloseHandle( pi.hThread );
   }
   DbgOutput( "Launched debug process. Waiting for connection...\r\n" );

   if( s_dbgStatusLbl )
      SetWindowTextA( s_dbgStatusLbl, "Waiting for debug client..." );

   /* Accept connection */
   DbgTrace("Waiting for client connection (30s timeout)...");
   if( DbgServerAccept( 30.0 ) != 0 )
   {
      DbgTrace("DbgServerAccept FAILED (timeout or stopped)");
      DbgOutput( "ERROR: Client did not connect within 30s\r\n" );
      DbgServerStop();
      s_dbgState = DBG_IDLE;
      hb_retl( HB_FALSE );
      return;
   }
   DbgTrace("Client connected!");
   DbgOutput( "Client connected.\r\n" );

   /* Command loop */
   char recvBuf[4096];
   s_dbgState = DBG_PAUSED;
   DbgTrace("Entering command loop...");

   while( s_dbgState != DBG_IDLE && s_dbgState != DBG_STOPPED )
   {
      int n = DbgServerRecv( recvBuf, sizeof(recvBuf) );
      { char t[256]; snprintf(t,sizeof(t),"recv n=%d buf='%.80s'", n, n>0?recvBuf:""); DbgTrace(t); }
      if( n <= 0 ) {
         DbgTrace("Client disconnected (n<=0)");
         DbgOutput( "Client disconnected.\r\n" );
         break;
      }

      if( strncmp( recvBuf, "HELLO", 5 ) == 0 )
      {
         DbgOutput( recvBuf ); DbgOutput( "\r\n" );
         DbgServerSend( "STEP" );
         s_dbgState = DBG_PAUSED;
         continue;
      }

      if( strncmp( recvBuf, "PAUSE ", 6 ) == 0 )
      {
         /* Format: PAUSE filepath:FUNCNAME:line|VARS ...|STACK ... */
         char localsStr[4096] = "VARS";
         char stackStr[4096] = "STACK";

         char * pipe1 = strchr( recvBuf, '|' );
         if( pipe1 ) {
            *pipe1 = 0;
            char * pipe2 = strchr( pipe1 + 1, '|' );
            if( pipe2 ) {
               *pipe2 = 0;
               strncpy( localsStr, pipe1 + 1, sizeof(localsStr) - 1 );
               strncpy( stackStr, pipe2 + 1, sizeof(stackStr) - 1 );
            } else {
               strncpy( localsStr, pipe1 + 1, sizeof(localsStr) - 1 );
            }
         }

         /* Parse PAUSE filepath:FUNCNAME:line */
         char * lastColon = strrchr( recvBuf + 6, ':' );
         if( !lastColon ) continue;
         int line = atoi( lastColon + 1 );
         *lastColon = 0;

         char * funcColon = strrchr( recvBuf + 6, ':' );
         const char * funcName = "";
         if( funcColon ) {
            funcName = funcColon + 1;
         }

         s_dbgLine = line;

         /* In RUNNING mode, skip pause */
         if( s_dbgState == DBG_RUNNING )
         {
            DbgServerSend( "GO" );
            continue;
         }

         /* === STEPPING/PAUSED: show state and wait for user === */
         s_dbgState = DBG_PAUSED;

         /* Call Harbour callback: ( cFuncName, nLine, cLocals, cStack )
          * Returns .T. if user code (should pause), .F. if framework (auto-step). */
         HB_BOOL shouldPause = HB_TRUE;
         if( s_dbgOnPause && HB_IS_BLOCK( s_dbgOnPause ) )
         {
            PHB_ITEM pFunc   = hb_itemPutC( NULL, funcName );
            PHB_ITEM pLine   = hb_itemPutNI( NULL, line );
            PHB_ITEM pLocals = hb_itemPutC( NULL, localsStr );
            PHB_ITEM pStack  = hb_itemPutC( NULL, stackStr );
            PHB_ITEM pResult = hb_itemDo( s_dbgOnPause, 4, pFunc, pLine, pLocals, pStack );
            if( pResult && HB_IS_LOGICAL( pResult ) )
               shouldPause = hb_itemGetL( pResult );
            else
               shouldPause = HB_TRUE;
            hb_itemRelease( pFunc );
            hb_itemRelease( pLine );
            hb_itemRelease( pLocals );
            hb_itemRelease( pStack );
            if( pResult ) hb_itemRelease( pResult );
         }

         /* Framework code — auto-step */
         if( !shouldPause )
         {
            DbgServerSend( "STEP" );
            s_dbgState = DBG_PAUSED;
            continue;
         }

         /* Update status */
         if( s_dbgStatusLbl ) {
            char status[512];
            snprintf(status, sizeof(status), "Paused at %s() line %d", funcName, line);
            SetWindowTextA( s_dbgStatusLbl, status );
         }

         /* Wait for user action (Step/Go/Stop via debug panel buttons) */
         {
            MSG winMsg;
            while( s_dbgState == DBG_PAUSED )
            {
               if( PeekMessage( &winMsg, NULL, 0, 0, PM_REMOVE ) )
               {
                  TranslateMessage( &winMsg );
                  DispatchMessage( &winMsg );
               }
               else
                  Sleep( 10 );
            }
         }

         /* Send command based on new state */
         if( s_dbgState == DBG_STEPPING || s_dbgState == DBG_STEPOVER )
         {
            DbgServerSend( "STEP" );
            s_dbgState = DBG_PAUSED;
         }
         else if( s_dbgState == DBG_RUNNING )
            DbgServerSend( "GO" );
         else if( s_dbgState == DBG_STOPPED )
            DbgServerSend( "QUIT" );
      }
   }

   /* Cleanup */
   DbgServerSend( "QUIT" );
   DbgServerStop();

   /* Kill any remaining DebugApp process */
   system( "taskkill /F /IM DebugApp.exe >nul 2>&1" );

   s_dbgState = DBG_IDLE;
   s_dbgRecvLen = 0;

   hb_retl( HB_TRUE );
}

/* ================================================================
 * DEBUG PANEL UI - W32_DebugPanel with WinAPI
 * Dark-themed window with 5 tabs: Watch, Locals, Call Stack,
 * Breakpoints, Output. Matches GTK3/Cocoa debug panel.
 * ================================================================ */

#define DBG_PANEL_CLASS "HbDbgPanel"
#define DBG_WND_ID_TAB     200
#define DBG_WND_ID_TOOLBAR 201

/* Helper: create a ListView with columns */
static HWND DbgCreateListView( HWND hParent, int x, int y, int w, int h, int nCols, ... )
{
   HWND hLV = CreateWindowExA( 0, WC_LISTVIEWA, "",
      WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL | LVS_NOSORTHEADER,
      x, y, w, h, hParent, NULL, GetModuleHandle(NULL), NULL );

   ListView_SetExtendedListViewStyle( hLV,
      LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES | LVS_EX_DOUBLEBUFFER );

   /* Dark colors */
   ListView_SetBkColor( hLV, RGB(30,30,30) );
   ListView_SetTextBkColor( hLV, RGB(30,30,30) );
   ListView_SetTextColor( hLV, RGB(212,212,212) );

   va_list args;
   va_start( args, nCols );
   for( int i = 0; i < nCols; i++ )
   {
      const char * title = va_arg( args, const char * );
      int colW = va_arg( args, int );
      LVCOLUMNA col = { 0 };
      col.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_FMT;
      col.pszText = (LPSTR)title;
      col.cx = colW;
      col.fmt = LVCFMT_LEFT;
      ListView_InsertColumn( hLV, i, &col );
   }
   va_end( args );

   return hLV;
}

/* Debug panel WndProc */
static LRESULT CALLBACK DbgPanelProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         int tbH = 32;

         if( s_dbgToolbar ) MoveWindow( s_dbgToolbar, 0, 0, w, tbH, TRUE );
         if( s_dbgTabCtrl ) MoveWindow( s_dbgTabCtrl, 0, tbH, w, h - tbH, TRUE );

         /* Resize active list/edit to fill tab body */
         int lvY = 24 + 4, lvH = h - tbH - 24 - 8;
         if( s_dbgWatchLV )   MoveWindow( s_dbgWatchLV,   4, lvY, w - 8, lvH, TRUE );
         if( s_dbgLocalsLV )  MoveWindow( s_dbgLocalsLV,  4, lvY, w - 8, lvH, TRUE );
         if( s_dbgStackLV )   MoveWindow( s_dbgStackLV,   4, lvY, w - 8, lvH, TRUE );
         if( s_dbgBpLV )      MoveWindow( s_dbgBpLV,      4, lvY, w - 8, lvH, TRUE );
         if( s_dbgOutputEdit) MoveWindow( s_dbgOutputEdit, 4, lvY, w - 8, lvH, TRUE );
         return 0;
      }

      case WM_NOTIFY:
      {
         NMHDR * pNM = (NMHDR *)lParam;
         if( pNM->idFrom == DBG_WND_ID_TAB && pNM->code == TCN_SELCHANGE )
         {
            int sel = TabCtrl_GetCurSel( s_dbgTabCtrl );
            ShowWindow( s_dbgWatchLV,   sel == 0 ? SW_SHOW : SW_HIDE );
            ShowWindow( s_dbgLocalsLV,  sel == 1 ? SW_SHOW : SW_HIDE );
            ShowWindow( s_dbgStackLV,   sel == 2 ? SW_SHOW : SW_HIDE );
            ShowWindow( s_dbgBpLV,      sel == 3 ? SW_SHOW : SW_HIDE );
            ShowWindow( s_dbgOutputEdit,sel == 4 ? SW_SHOW : SW_HIDE );
         }
         return 0;
      }

      case WM_COMMAND:
      {
         int id = LOWORD(wParam);
         switch( id )
         {
            case 1001: /* Run/Continue */
               if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_RUNNING;
               break;
            case 1002: /* Step Into */
               if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_STEPPING;
               break;
            case 1003: /* Step Over */
               if( s_dbgState == DBG_PAUSED ) {
                  s_dbgStepDepth = (int) hb_dbg_ProcLevel();
                  s_dbgState = DBG_STEPOVER;
               }
               break;
            case 1004: /* Stop */
               if( s_dbgState != DBG_IDLE ) s_dbgState = DBG_STOPPED;
               break;
         }
         return 0;
      }

      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLOREDIT:
      {
         HDC hdc = (HDC)wParam;
         SetTextColor( hdc, RGB(212,212,212) );
         SetBkColor( hdc, RGB(30,30,30) );
         static HBRUSH hBrDark = CreateSolidBrush( RGB(30,30,30) );
         return (LRESULT)hBrDark;
      }

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;

      case WM_ERASEBKGND:
      {
         HDC hdc = (HDC)wParam;
         RECT rc; GetClientRect( hWnd, &rc );
         HBRUSH hBr = CreateSolidBrush( RGB(37,37,38) );
         FillRect( hdc, &rc, hBr );
         DeleteObject( hBr );
         return 1;
      }
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* W32_DebugPanel() - create/show the debug panel window */
HB_FUNC( W32_DEBUGPANEL )
{
   if( s_hDbgWnd ) {
      ShowWindow( s_hDbgWnd, SW_SHOW );
      SetForegroundWindow( s_hDbgWnd );
      return;
   }

   /* Register window class */
   {  WNDCLASSEXA wc = { sizeof(WNDCLASSEXA) };
      wc.lpfnWndProc = DbgPanelProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.lpszClassName = DBG_PANEL_CLASS;
      wc.hCursor = LoadCursor( NULL, IDC_ARROW );
      wc.hbrBackground = CreateSolidBrush( RGB(37,37,38) );
      RegisterClassExA( &wc );
   }

   s_hDbgWnd = CreateWindowExA( WS_EX_TOOLWINDOW, DBG_PANEL_CLASS, "Debugger",
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      100, 300, 700, 420, NULL, NULL, GetModuleHandle(NULL), NULL );

   /* Dark mode title bar (Windows 10/11) */
   {  typedef HRESULT (WINAPI *PFN_DwmSetWindowAttribute)(HWND, DWORD, LPCVOID, DWORD);
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         PFN_DwmSetWindowAttribute pFn = (PFN_DwmSetWindowAttribute)GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( pFn ) { BOOL val = TRUE; pFn( s_hDbgWnd, 20, &val, sizeof(val) ); }
         FreeLibrary( hDwm );
      }
   }

   int w = 700, h = 420, tbH = 32;

   /* === Toolbar with buttons === */
   s_dbgToolbar = CreateWindowExA( 0, "STATIC", "", WS_CHILD | WS_VISIBLE,
      0, 0, w, tbH, s_hDbgWnd, (HMENU)DBG_WND_ID_TOOLBAR, GetModuleHandle(NULL), NULL );

   { const char * labels[] = { "\xE2\x96\xB6 Run", "\xE2\x86\x93 Step", "\xE2\x86\x92 Over", "\xE2\x96\xA0 Stop" };
     int ids[] = { 1001, 1002, 1003, 1004 };
     int bx = 4;
     for( int i = 0; i < 4; i++ )
     {
        HWND hBtn = CreateWindowExA( 0, "BUTTON", labels[i],
           WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
           bx, 2, 72, 26, s_hDbgWnd, (HMENU)(LONG_PTR)ids[i],
           GetModuleHandle(NULL), NULL );
        SendMessageA( hBtn, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE );
        bx += 76;
     }

     /* Status label */
     s_dbgStatusLbl = CreateWindowExA( 0, "STATIC", "Ready",
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        bx + 12, 6, 300, 20, s_hDbgWnd, NULL, GetModuleHandle(NULL), NULL );
     SendMessageA( s_dbgStatusLbl, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE );
   }

   /* === Tab control === */
   s_dbgTabCtrl = CreateWindowExA( 0, WC_TABCONTROLA, "",
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
      0, tbH, w, h - tbH, s_hDbgWnd, (HMENU)DBG_WND_ID_TAB,
      GetModuleHandle(NULL), NULL );
   SendMessageA( s_dbgTabCtrl, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE );

   { const char * tabs[] = { "Watch", "Locals", "Call Stack", "Breakpoints", "Output" };
     for( int i = 0; i < 5; i++ ) {
        TCITEMA ti = { 0 };
        ti.mask = TCIF_TEXT;
        ti.pszText = (LPSTR)tabs[i];
        TabCtrl_InsertItem( s_dbgTabCtrl, i, &ti );
     }
   }

   int lvY = 24 + 4, lvW = w - 8, lvH = h - tbH - 24 - 8;

   /* Tab 0: Watch */
   s_dbgWatchLV = DbgCreateListView( s_dbgTabCtrl, 4, lvY, lvW, lvH,
      3, "Expression", 180, "Value", 200, "Type", 100 );

   /* Tab 1: Locals */
   s_dbgLocalsLV = DbgCreateListView( s_dbgTabCtrl, 4, lvY, lvW, lvH,
      3, "Name", 140, "Value", 280, "Type", 100 );
   ShowWindow( s_dbgLocalsLV, SW_HIDE );

   /* Tab 2: Call Stack */
   s_dbgStackLV = DbgCreateListView( s_dbgTabCtrl, 4, lvY, lvW, lvH,
      4, "#", 40, "Function", 180, "Module", 180, "Line", 60 );
   ShowWindow( s_dbgStackLV, SW_HIDE );

   /* Tab 3: Breakpoints */
   s_dbgBpLV = DbgCreateListView( s_dbgTabCtrl, 4, lvY, lvW, lvH,
      3, "File", 250, "Line", 80, "Enabled", 80 );
   ShowWindow( s_dbgBpLV, SW_HIDE );

   /* Tab 4: Output */
   s_dbgOutputEdit = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", "",
      WS_CHILD | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL | WS_VSCROLL,
      4, lvY, lvW, lvH, s_dbgTabCtrl, NULL, GetModuleHandle(NULL), NULL );
   {  HFONT hMonoFont = CreateFontA( -18, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
         DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, "Consolas" );
      SendMessageA( s_dbgOutputEdit, WM_SETFONT, (WPARAM)hMonoFont, TRUE );
   }
   ShowWindow( s_dbgOutputEdit, SW_HIDE );

   /* Default: show Watch tab */
   TabCtrl_SetCurSel( s_dbgTabCtrl, 0 );
   ShowWindow( s_dbgWatchLV, SW_SHOW );
}

/* W32_DebugUpdateLocals( aLocals ) - populate Locals ListView */
HB_FUNC( W32_DEBUGUPDATELOCALS )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_dbgLocalsLV || !pArray ) return;

   ListView_DeleteAllItems( s_dbgLocalsLV );

   int n = (int) hb_arrayLen( pArray );
   for( int i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 3 ) continue;

      LVITEMA item = { 0 };
      item.mask = LVIF_TEXT;
      item.iItem = i - 1;
      item.pszText = (LPSTR)hb_arrayGetCPtr( pEntry, 1 );
      ListView_InsertItem( s_dbgLocalsLV, &item );
      ListView_SetItemText( s_dbgLocalsLV, i - 1, 1, (LPSTR)hb_arrayGetCPtr( pEntry, 2 ) );
      ListView_SetItemText( s_dbgLocalsLV, i - 1, 2, (LPSTR)hb_arrayGetCPtr( pEntry, 3 ) );
   }
}

/* W32_DebugUpdateStack( aStack ) - populate Call Stack ListView */
HB_FUNC( W32_DEBUGUPDATESTACK )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_dbgStackLV || !pArray ) return;

   ListView_DeleteAllItems( s_dbgStackLV );

   int n = (int) hb_arrayLen( pArray );
   for( int i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 4 ) continue;

      LVITEMA item = { 0 };
      item.mask = LVIF_TEXT;
      item.iItem = i - 1;
      item.pszText = (LPSTR)hb_arrayGetCPtr( pEntry, 1 );
      ListView_InsertItem( s_dbgStackLV, &item );
      ListView_SetItemText( s_dbgStackLV, i - 1, 1, (LPSTR)hb_arrayGetCPtr( pEntry, 2 ) );
      ListView_SetItemText( s_dbgStackLV, i - 1, 2, (LPSTR)hb_arrayGetCPtr( pEntry, 3 ) );
      ListView_SetItemText( s_dbgStackLV, i - 1, 3, (LPSTR)hb_arrayGetCPtr( pEntry, 4 ) );
   }
}

/* W32_DebugSetStatus( cText ) - update status label */
HB_FUNC( W32_DEBUGSETSTATUS )
{
   if( s_dbgStatusLbl && HB_ISCHAR(1) )
      SetWindowTextA( s_dbgStatusLbl, hb_parc(1) );
}

/* W32_DebugUpdateLocalsStr( cVars ) - parse VARS string and populate Locals ListView
 * Format: "VARS [PUBLIC] name=val(T) [PRIVATE] ... [LOCAL] ..." */
HB_FUNC( W32_DEBUGUPDATELOCALSSTR )
{
   const char * cVars = HB_ISCHAR(1) ? hb_parc(1) : "";
   if( !s_dbgLocalsLV ) return;

   ListView_DeleteAllItems( s_dbgLocalsLV );

   const char * p = cVars;
   if( strncmp( p, "VARS", 4 ) == 0 ) p += 4;
   char category[64] = "";
   int row = 0;

   while( *p )
   {
      while( *p == ' ' ) p++;
      if( !*p ) break;

      /* Check for [CATEGORY] header */
      if( *p == '[' ) {
         const char * end = strchr( p, ']' );
         if( end ) {
            int len = (int)(end - p - 1);
            if( len > 63 ) len = 63;
            strncpy( category, p + 1, len );
            category[len] = 0;

            /* Insert category header row */
            LVITEMA item = { 0 };
            item.mask = LVIF_TEXT;
            item.iItem = row;
            item.pszText = (LPSTR)category;
            ListView_InsertItem( s_dbgLocalsLV, &item );
            ListView_SetItemText( s_dbgLocalsLV, row, 1, (LPSTR)"" );
            ListView_SetItemText( s_dbgLocalsLV, row, 2, (LPSTR)"---" );
            row++;

            p = end + 1;
            continue;
         }
      }

      /* Parse name=value(type) token */
      char name[128] = "", value[256] = "", type[32] = "";
      const char * eq = strchr( p, '=' );
      if( !eq ) break;

      int nLen = (int)(eq - p);
      if( nLen > 127 ) nLen = 127;
      strncpy( name, p, nLen ); name[nLen] = 0;
      p = eq + 1;

      /* Value extends until '(' for type or next space */
      const char * paren = NULL;
      const char * sp = NULL;
      {
         int depth = 0;
         const char * scan = p;
         while( *scan && !(*scan == ' ' && depth == 0) ) {
            if( *scan == '(' ) { if( depth == 0 ) paren = scan; depth++; }
            else if( *scan == ')' ) depth--;
            scan++;
         }
         sp = scan;
      }

      if( paren && paren < sp ) {
         int vLen = (int)(paren - p);
         if( vLen > 255 ) vLen = 255;
         strncpy( value, p, vLen ); value[vLen] = 0;
         int tLen = (int)(sp - paren - 2);
         if( tLen > 0 ) {
            if( tLen > 31 ) tLen = 31;
            strncpy( type, paren + 1, tLen ); type[tLen] = 0;
         }
      } else {
         int vLen = (int)(sp - p);
         if( vLen > 255 ) vLen = 255;
         strncpy( value, p, vLen ); value[vLen] = 0;
      }
      p = sp;

      LVITEMA item = { 0 };
      item.mask = LVIF_TEXT;
      item.iItem = row;
      item.pszText = (LPSTR)name;
      ListView_InsertItem( s_dbgLocalsLV, &item );
      ListView_SetItemText( s_dbgLocalsLV, row, 1, (LPSTR)value );
      ListView_SetItemText( s_dbgLocalsLV, row, 2, (LPSTR)type );
      row++;
   }
}

/* W32_DebugUpdateStackStr( cStack ) - parse STACK string and populate Call Stack ListView
 * Format: "STACK FUNC(line) FUNC2(line2) ..." */
HB_FUNC( W32_DEBUGUPDATESTACKSTR )
{
   const char * cStack = HB_ISCHAR(1) ? hb_parc(1) : "";
   if( !s_dbgStackLV ) return;

   ListView_DeleteAllItems( s_dbgStackLV );

   const char * p = cStack;
   if( strncmp( p, "STACK", 5 ) == 0 ) p += 5;
   int row = 0;

   while( *p )
   {
      while( *p == ' ' ) p++;
      if( !*p ) break;

      char token[256] = "";
      const char * sp = strchr( p, ' ' );
      if( !sp ) sp = p + strlen(p);
      int tLen = (int)(sp - p);
      if( tLen > 255 ) tLen = 255;
      strncpy( token, p, tLen ); token[tLen] = 0;
      p = sp;

      /* Parse FUNC(line) */
      char func[128] = "", lineStr[32] = "";
      char * paren = strchr( token, '(' );
      if( paren ) {
         *paren = 0;
         strncpy( func, token, 127 );
         char * endP = strchr( paren + 1, ')' );
         if( endP ) {
            *endP = 0;
            strncpy( lineStr, paren + 1, 31 );
         }
      } else {
         strncpy( func, token, 127 );
      }

      char numStr[16];
      snprintf( numStr, sizeof(numStr), "%d", row + 1 );

      LVITEMA item = { 0 };
      item.mask = LVIF_TEXT;
      item.iItem = row;
      item.pszText = (LPSTR)numStr;
      ListView_InsertItem( s_dbgStackLV, &item );
      ListView_SetItemText( s_dbgStackLV, row, 1, (LPSTR)func );
      ListView_SetItemText( s_dbgStackLV, row, 2, (LPSTR)lineStr );
      row++;
   }
}

/* ================================================================
 * FORM CLIPBOARD & UNDO
 * Copy/Paste controls, 50-step undo, ClearChildren, TabOrder dialog
 * ================================================================ */

/* Clipboard for copied controls */
#define CLIP_MAX 32
typedef struct {
   BYTE  bType;
   int   nLeft, nTop, nWidth, nHeight;
   char  szText[256];
   char  szName[64];
} ClipCtrl;

static ClipCtrl s_clipboard[CLIP_MAX];
static int      s_clipCount = 0;

/* Undo stack */
#define UNDO_MAX_STEPS 50
#define UNDO_MAX_CTRLS 256
typedef struct {
   int nCount;
   struct {
      BYTE bType;
      int  nLeft, nTop, nWidth, nHeight;
      char szName[64];
      char szText[256];
   } ctrls[UNDO_MAX_CTRLS];
} UndoSnapshot;

static UndoSnapshot s_undoStack[UNDO_MAX_STEPS];
static int s_undoPos   = 0;
static int s_undoCount = 0;

/* UI_FormCopySelected( hForm ) - copy selected controls to clipboard */
HB_FUNC( UI_FORMCOPYSELECTED )
{
   TForm * form = GetForm(1);
   if( !form ) return;

   s_clipCount = 0;
   for( int i = 0; i < form->FSelCount && s_clipCount < CLIP_MAX; i++ )
   {
      TControl * c = form->FSelected[i];
      ClipCtrl * cc = &s_clipboard[s_clipCount++];
      cc->bType  = c->FControlType;
      cc->nLeft  = c->FLeft;
      cc->nTop   = c->FTop;
      cc->nWidth = c->FWidth;
      cc->nHeight= c->FHeight;
      strncpy( cc->szText, c->FText, 255 );
      strncpy( cc->szName, c->FName, 63 );
   }
   hb_retni( s_clipCount );
}

/* UI_FormPasteControls( hForm ) - paste clipboard controls with 16px offset */
HB_FUNC( UI_FORMPASTECONTROLS )
{
   TForm * form = GetForm(1);
   if( !form || s_clipCount == 0 ) return;

   form->ClearSelection();

   for( int i = 0; i < s_clipCount; i++ )
   {
      ClipCtrl * cc = &s_clipboard[i];
      TControl * ctrl = CreateControlByType( cc->bType );
      if( !ctrl ) continue;

      ctrl->FLeft   = cc->nLeft + 16;
      ctrl->FTop    = cc->nTop + 16;
      ctrl->FWidth  = cc->nWidth;
      ctrl->FHeight = cc->nHeight;
      ctrl->SetText( cc->szText );

      form->AddChild( ctrl );
      ctrl->CreateHandle( form->FHandle );
      ctrl->Show();

      form->SelectControl( ctrl, TRUE );
   }

   form->UpdateOverlay();
   hb_retni( s_clipCount );
}

/* UI_FormGetClipCount() -> nCount */
HB_FUNC( UI_FORMGETCLIPCOUNT )
{
   hb_retni( s_clipCount );
}

/* UI_FormUndoPush( hForm ) - save current state to undo stack */
HB_FUNC( UI_FORMUNDOPUSH )
{
   TForm * form = GetForm(1);
   if( !form ) return;

   UndoSnapshot * snap = &s_undoStack[ s_undoPos % UNDO_MAX_STEPS ];
   snap->nCount = 0;

   for( int i = 0; i < form->FChildCount && snap->nCount < UNDO_MAX_CTRLS; i++ )
   {
      TControl * c = form->FChildren[i];
      int idx = snap->nCount++;
      snap->ctrls[idx].bType  = c->FControlType;
      snap->ctrls[idx].nLeft  = c->FLeft;
      snap->ctrls[idx].nTop   = c->FTop;
      snap->ctrls[idx].nWidth = c->FWidth;
      snap->ctrls[idx].nHeight= c->FHeight;
      strncpy( snap->ctrls[idx].szName, c->FName, 63 );
      strncpy( snap->ctrls[idx].szText, c->FText, 255 );
   }

   s_undoPos++;
   if( s_undoCount < UNDO_MAX_STEPS ) s_undoCount++;
}

/* UI_FormUndo( hForm ) - restore previous state */
HB_FUNC( UI_FORMUNDO )
{
   TForm * form = GetForm(1);
   if( !form || s_undoCount == 0 ) return;

   s_undoPos--;
   s_undoCount--;

   UndoSnapshot * snap = &s_undoStack[ s_undoPos % UNDO_MAX_STEPS ];

   /* Restore positions and sizes of existing controls */
   for( int i = 0; i < snap->nCount && i < form->FChildCount; i++ )
   {
      TControl * c = form->FChildren[i];
      c->FLeft   = snap->ctrls[i].nLeft;
      c->FTop    = snap->ctrls[i].nTop;
      c->FWidth  = snap->ctrls[i].nWidth;
      c->FHeight = snap->ctrls[i].nHeight;
      if( c->FHandle )
         SetWindowPos( c->FHandle, NULL, c->FLeft, c->FTop,
            c->FWidth, c->FHeight, SWP_NOZORDER );
   }

   if( form->FHandle ) InvalidateRect( form->FHandle, NULL, TRUE );
   form->UpdateOverlay();
   hb_retl( HB_TRUE );
}

/* UI_FormClearChildren( hForm ) - remove all child controls */
HB_FUNC( UI_FORMCLEARCHILDREN )
{
   TForm * form = GetForm(1);
   if( !form ) return;

   form->ClearSelection();

   for( int i = form->FChildCount - 1; i >= 0; i-- )
   {
      TControl * c = form->FChildren[i];
      if( c->FHandle ) DestroyWindow( c->FHandle );
      delete c;
   }
   form->FChildCount = 0;

   if( form->FHandle ) InvalidateRect( form->FHandle, NULL, TRUE );
   form->UpdateOverlay();
}

/* UI_FormTabOrderDialog( hForm ) - show tab order dialog */
HB_FUNC( UI_FORMTABORDERDIALOG )
{
   TForm * form = GetForm(1);
   if( !form || form->FChildCount == 0 ) return;

   /* Build list of control names with current tab order */
   char buf[4096] = "Tab Order:\r\n\r\n";
   for( int i = 0; i < form->FChildCount; i++ )
   {
      TControl * c = form->FChildren[i];
      char line[128];
      snprintf( line, sizeof(line), "%d. %s (%s)\r\n",
         i + 1, c->FName, c->FClassName );
      strcat( buf, line );
   }

   MessageBoxA( form->FHandle, buf, "Tab Order", MB_OK | MB_ICONINFORMATION );
}

/* ================================================================
 * REPORT DESIGNER - RPT_Designer* functions
 * Visual band/field editor using GDI rendering (WinAPI port of Cairo)
 * ================================================================ */

#include <math.h>

/* Forward declarations for Preview (used by Designer's Preview button) */
#define RPT_PRV_MAX_PAGES 100
#define RPT_PRV_MAX_CMDS  500

typedef struct {
   int  type;         /* 1=text, 2=rect, 3=line */
   int  x, y, w, h;
   int  x2, y2;
   char text[256];
   char fontName[64];
   int  fontSize;
   int  bold, italic;
   int  color;
   int  filled;
   int  lineWidth;
} RptDrawCmd;

typedef struct {
   int        nCmds;
   RptDrawCmd cmds[RPT_PRV_MAX_CMDS];
} RptPrvPage;

static HWND        s_rptPreview = NULL;
static RptPrvPage  s_rptPrvPages[RPT_PRV_MAX_PAGES];
static int         s_rptPrvPageCount = 0;
static int         s_rptPrvCurPage = 0;
static int         s_rptPrvPgW = 210, s_rptPrvPgH = 297;
static int         s_rptPrvMgL = 15, s_rptPrvMgR = 15;
static int         s_rptPrvMgT = 15, s_rptPrvMgB = 15;
static int         s_rptPreviewZoom = 100;
static HWND        s_rptPrvPageLabel = NULL;

static void RptShowAddBandMenu( HWND hWnd );
static void RptPrvUpdateLabel(void);

#define RPT_MAX_BANDS  20
#define RPT_MAX_FIELDS 50
#define RPT_MARGIN_W   24
#define RPT_RULER_H    24
#define RPT_HANDLE_SZ  6

typedef struct {
   char cName[32];
   char cText[128];
   char cFieldName[64];
   int  nLeft, nTop, nWidth, nHeight;
   int  nAlignment;   /* 0=Left, 1=Center, 2=Right */
} RptField;

typedef struct {
   char     cName[32];
   int      nHeight;
   int      nFieldCount;
   RptField fields[RPT_MAX_FIELDS];
   COLORREF color;
   int      lPrintOnEveryPage;
   int      lKeepTogether;
   int      lVisible;
} RptBand;

static HWND    s_rptDesigner = NULL;
static RptBand s_rptBands[RPT_MAX_BANDS];
static int     s_rptBandCount = 0;
static int     s_rptSelBand  = -1;
static int     s_rptSelField = -1;
static int     s_rptPageWidth  = 210;
static int     s_rptPageHeight = 297;
static int     s_rptScale = 3;

/* Drag state */
static int     s_rptDragging = 0;   /* 0=none, 1=move field, 2=resize band */
static int     s_rptDragStartX, s_rptDragStartY;
static int     s_rptDragOrigX, s_rptDragOrigY;

/* Band color from name */
static COLORREF rpt_band_color( const char * name )
{
   if( strstr(name,"Header") && !strstr(name,"Page") && !strstr(name,"Group") )
      return RGB(74,144,217);
   if( strstr(name,"Detail") )  return RGB(128,128,128);
   if( strstr(name,"Footer") )  return RGB(74,144,217);
   if( strstr(name,"Group") )   return RGB(107,191,107);
   if( strstr(name,"Page") )    return RGB(212,168,67);
   if( strstr(name,"Summary") ) return RGB(180,100,180);
   if( strstr(name,"Title") )   return RGB(200,100,100);
   return RGB(128,128,128);
}

/* Paint the designer surface */
static void RptDesignerPaint( HWND hWnd )
{
   PAINTSTRUCT ps;
   HDC hdc = BeginPaint( hWnd, &ps );
   RECT rc; GetClientRect( hWnd, &rc );

   /* Double buffer */
   HDC memDC = CreateCompatibleDC( hdc );
   HBITMAP memBmp = CreateCompatibleBitmap( hdc, rc.right, rc.bottom );
   SelectObject( memDC, memBmp );

   /* Dark background */
   HBRUSH hBrBg = CreateSolidBrush( RGB(37,37,38) );
   FillRect( memDC, &rc, hBrBg );
   DeleteObject( hBrBg );

   int pageW = s_rptPageWidth * s_rptScale;
   int pageX = 40;

   /* Ruler */
   HPEN hPenGray = CreatePen( PS_SOLID, 1, RGB(80,80,80) );
   SelectObject( memDC, hPenGray );
   SetTextColor( memDC, RGB(180,180,180) );
   SetBkMode( memDC, TRANSPARENT );
   HFONT hSmallFont = CreateFontA( -15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, 0, 0, DEFAULT_QUALITY, DEFAULT_PITCH, "Segoe UI" );
   SelectObject( memDC, hSmallFont );
   for( int mm = 0; mm <= s_rptPageWidth; mm += 10 )
   {
      int x = pageX + RPT_MARGIN_W + mm * s_rptScale;
      MoveToEx( memDC, x, 0, NULL );
      LineTo( memDC, x, mm % 50 == 0 ? RPT_RULER_H : RPT_RULER_H / 2 );
      if( mm % 50 == 0 )
      {
         char buf[8]; snprintf( buf, sizeof(buf), "%d", mm );
         TextOutA( memDC, x + 2, 1, buf, (int)strlen(buf) );
      }
   }

   /* Bands */
   HFONT hFieldFont = CreateFontA( -17, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, DEFAULT_PITCH, "Segoe UI" );

   int bandY = RPT_RULER_H;
   for( int i = 0; i < s_rptBandCount; i++ )
   {
      RptBand * b = &s_rptBands[i];
      int bH = b->nHeight;

      /* Left margin strip with band color */
      HBRUSH hBrBand = CreateSolidBrush( b->color );
      RECT rcMargin = { pageX, bandY, pageX + RPT_MARGIN_W, bandY + bH };
      FillRect( memDC, &rcMargin, hBrBand );
      DeleteObject( hBrBand );

      /* Band name in margin (vertical) */
      SetTextColor( memDC, RGB(255,255,255) );
      HFONT hVFont = CreateFontA( -16, 0, 900, 900, FW_BOLD, FALSE, FALSE, FALSE,
         DEFAULT_CHARSET, 0, 0, DEFAULT_QUALITY, DEFAULT_PITCH, "Segoe UI" );
      SelectObject( memDC, hVFont );
      TextOutA( memDC, pageX + 4, bandY + bH - 4, b->cName, (int)strlen(b->cName) );
      DeleteObject( hVFont );

      /* Band body - light background if selected */
      if( s_rptSelBand == i && s_rptSelField < 0 )
      {
         HBRUSH hBrSel = CreateSolidBrush( RGB(50,55,65) );
         RECT rcBody = { pageX + RPT_MARGIN_W, bandY, pageX + RPT_MARGIN_W + pageW, bandY + bH };
         FillRect( memDC, &rcBody, hBrSel );
         DeleteObject( hBrSel );
      }
      else
      {
         HBRUSH hBrBody = CreateSolidBrush( RGB(45,45,46) );
         RECT rcBody = { pageX + RPT_MARGIN_W, bandY, pageX + RPT_MARGIN_W + pageW, bandY + bH };
         FillRect( memDC, &rcBody, hBrBody );
         DeleteObject( hBrBody );
      }

      /* Band separator line */
      HPEN hPenSep = CreatePen( PS_DOT, 1, RGB(100,100,100) );
      SelectObject( memDC, hPenSep );
      MoveToEx( memDC, pageX, bandY + bH, NULL );
      LineTo( memDC, pageX + RPT_MARGIN_W + pageW, bandY + bH );
      DeleteObject( hPenSep );

      /* Fields */
      SelectObject( memDC, hFieldFont );
      for( int f = 0; f < b->nFieldCount; f++ )
      {
         RptField * fld = &b->fields[f];
         int fx = pageX + RPT_MARGIN_W + fld->nLeft;
         int fy = bandY + fld->nTop;
         int fw = fld->nWidth;
         int fh = fld->nHeight;

         /* Field rectangle */
         HBRUSH hBrFld = CreateSolidBrush( RGB(242,242,247) );
         RECT rcFld = { fx, fy, fx + fw, fy + fh };
         FillRect( memDC, &rcFld, hBrFld );
         DeleteObject( hBrFld );

         /* Field border */
         HPEN hPenFld = CreatePen( PS_SOLID, 1, RGB(160,160,170) );
         SelectObject( memDC, hPenFld );
         SelectObject( memDC, GetStockObject(NULL_BRUSH) );
         Rectangle( memDC, fx, fy, fx + fw, fy + fh );
         DeleteObject( hPenFld );

         /* Field text */
         SetTextColor( memDC, RGB(30,30,30) );
         RECT rcText = { fx + 2, fy + 1, fx + fw - 2, fy + fh - 1 };
         if( fld->cText[0] )
            DrawTextA( memDC, fld->cText, -1, &rcText, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX );
         else if( fld->cFieldName[0] )
         {
            char buf[80]; snprintf( buf, sizeof(buf), "[%s]", fld->cFieldName );
            DrawTextA( memDC, buf, -1, &rcText, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX );
         }
         else
            DrawTextA( memDC, fld->cName, -1, &rcText, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX );

         /* Selection handles */
         if( s_rptSelBand == i && s_rptSelField == f )
         {
            HPEN hPenSel = CreatePen( PS_SOLID, 2, RGB(0,122,204) );
            SelectObject( memDC, hPenSel );
            SelectObject( memDC, GetStockObject(NULL_BRUSH) );
            Rectangle( memDC, fx - 1, fy - 1, fx + fw + 1, fy + fh + 1 );
            DeleteObject( hPenSel );

            /* 4 corner handles */
            HBRUSH hBrHandle = CreateSolidBrush( RGB(0,122,204) );
            int hs = RPT_HANDLE_SZ;
            RECT h1 = { fx-hs, fy-hs, fx, fy }; FillRect( memDC, &h1, hBrHandle );
            RECT h2 = { fx+fw, fy-hs, fx+fw+hs, fy }; FillRect( memDC, &h2, hBrHandle );
            RECT h3 = { fx-hs, fy+fh, fx, fy+fh+hs }; FillRect( memDC, &h3, hBrHandle );
            RECT h4 = { fx+fw, fy+fh, fx+fw+hs, fy+fh+hs }; FillRect( memDC, &h4, hBrHandle );
            DeleteObject( hBrHandle );
         }
      }

      bandY += bH;
   }

   DeleteObject( hFieldFont );
   DeleteObject( hSmallFont );
   DeleteObject( hPenGray );

   /* Blit to screen */
   BitBlt( hdc, 0, 0, rc.right, rc.bottom, memDC, 0, 0, SRCCOPY );
   DeleteObject( memBmp );
   DeleteDC( memDC );

   EndPaint( hWnd, &ps );
}

/* Designer WndProc */
#define RPT_DESIGNER_CLASS "HbRptDesigner"
#define RPT_ID_ADD_BAND  2001
#define RPT_ID_ADD_FIELD 2002
#define RPT_ID_DELETE    2003
#define RPT_ID_PREVIEW   2004

static LRESULT CALLBACK RptDesignerProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_PAINT:
         RptDesignerPaint( hWnd );
         return 0;

      case WM_LBUTTONDOWN:
      {
         int mx = LOWORD(lParam), my = HIWORD(lParam);
         int pageX = 40, pageW = s_rptPageWidth * s_rptScale;

         s_rptSelBand = -1;
         s_rptSelField = -1;
         s_rptDragging = 0;

         int bandY = RPT_RULER_H;
         for( int i = 0; i < s_rptBandCount; i++ )
         {
            RptBand * b = &s_rptBands[i];
            int bH = b->nHeight;

            if( my >= bandY && my < bandY + bH + 2 )
            {
               /* Band separator drag? */
               if( my >= bandY + bH - 8 && mx >= pageX && mx < pageX + RPT_MARGIN_W )
               {
                  s_rptSelBand = i;
                  s_rptDragging = 2;
                  s_rptDragStartY = my;
                  s_rptDragOrigY = bH;
                  SetCapture( hWnd );
                  goto done;
               }

               /* Margin click = select band */
               if( mx >= pageX && mx < pageX + RPT_MARGIN_W )
               {
                  s_rptSelBand = i;
                  goto done;
               }

               /* Field hit test */
               for( int f = b->nFieldCount - 1; f >= 0; f-- )
               {
                  RptField * fld = &b->fields[f];
                  int fx = pageX + RPT_MARGIN_W + fld->nLeft;
                  int fy = bandY + fld->nTop;
                  if( mx >= fx && mx < fx + fld->nWidth &&
                      my >= fy && my < fy + fld->nHeight )
                  {
                     s_rptSelBand  = i;
                     s_rptSelField = f;
                     s_rptDragging = 1;
                     s_rptDragStartX = mx;
                     s_rptDragStartY = my;
                     s_rptDragOrigX = fld->nLeft;
                     s_rptDragOrigY = fld->nTop;
                     SetCapture( hWnd );
                     goto done;
                  }
               }

               s_rptSelBand = i;
               goto done;
            }
            bandY += bH;
         }
done:
         InvalidateRect( hWnd, NULL, FALSE );
         return 0;
      }

      case WM_MOUSEMOVE:
      {
         if( !s_rptDragging ) return 0;
         int mx = LOWORD(lParam), my = HIWORD(lParam);

         if( s_rptDragging == 1 && s_rptSelBand >= 0 && s_rptSelField >= 0 )
         {
            /* Move field */
            RptField * fld = &s_rptBands[s_rptSelBand].fields[s_rptSelField];
            int dx = mx - s_rptDragStartX;
            int dy = my - s_rptDragStartY;
            int newLeft = s_rptDragOrigX + dx;
            int newTop  = s_rptDragOrigY + dy;
            if( newLeft < 0 ) newLeft = 0;
            if( newTop  < 0 ) newTop  = 0;
            fld->nLeft = newLeft;
            fld->nTop  = newTop;
            InvalidateRect( hWnd, NULL, FALSE );
         }
         else if( s_rptDragging == 2 && s_rptSelBand >= 0 )
         {
            /* Resize band */
            int dy = my - s_rptDragStartY;
            int newH = s_rptDragOrigY + dy;
            if( newH < 20 ) newH = 20;
            if( newH > 400 ) newH = 400;
            s_rptBands[s_rptSelBand].nHeight = newH;
            InvalidateRect( hWnd, NULL, FALSE );
         }
         return 0;
      }

      case WM_LBUTTONUP:
         if( s_rptDragging ) { s_rptDragging = 0; ReleaseCapture(); }
         return 0;

      case WM_COMMAND:
      {
         int id = LOWORD(wParam);
         if( id == RPT_ID_ADD_BAND )
         {
            RptShowAddBandMenu( hWnd );
            return 0;
         }
         else if( id == RPT_ID_PREVIEW )
         {
            /* Build preview from designer bands */
            s_rptPrvPageCount = 0;
            s_rptPrvCurPage = 0;
            memset( s_rptPrvPages, 0, sizeof(s_rptPrvPages) );
            s_rptPrvPgW = s_rptPageWidth;
            s_rptPrvPgH = s_rptPageHeight;
            s_rptPreviewZoom = 100;

            if( s_rptBandCount > 0 )
            {
               RptPrvPage * pg = &s_rptPrvPages[0];
               pg->nCmds = 0;
               s_rptPrvPageCount = 1;
               int nY = s_rptPrvMgT;
               for( int bi = 0; bi < s_rptBandCount; bi++ )
               {
                  RptBand * band = &s_rptBands[bi];
                  if( !band->lVisible ) continue;
                  for( int fi = 0; fi < band->nFieldCount; fi++ )
                  {
                     if( pg->nCmds >= RPT_PRV_MAX_CMDS ) break;
                     RptField * fld = &band->fields[fi];
                     RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
                     memset( cmd, 0, sizeof(RptDrawCmd) );
                     cmd->type = 1;
                     cmd->x = s_rptPrvMgL + fld->nLeft;
                     cmd->y = nY + fld->nTop;
                     if( fld->cText[0] )
                        strncpy( cmd->text, fld->cText, sizeof(cmd->text)-1 );
                     else
                        snprintf( cmd->text, sizeof(cmd->text), "[%s]", fld->cFieldName );
                     strncpy( cmd->fontName, "Segoe UI", sizeof(cmd->fontName)-1 );
                     cmd->fontSize = 10;
                     cmd->color = 0x000000;
                     pg->nCmds++;
                  }
                  nY += band->nHeight;
               }
            }

            /* Show preview window */
            if( !s_rptPreview )
            {
               PHB_DYNS pSym = hb_dynsymFind( "RPT_PREVIEWOPEN" );
               if( pSym ) { hb_vmPushDynSym(pSym); hb_vmPushNil(); hb_vmDo(0); }
            }
            else
            {
               ShowWindow( s_rptPreview, SW_SHOW );
               SetForegroundWindow( s_rptPreview );
            }
            RptPrvUpdateLabel();
            if( s_rptPreview ) InvalidateRect( s_rptPreview, NULL, FALSE );
            return 0;
         }
         else if( id >= 2010 && id <= 2020 )
         {
            /* Add band by type */
            const char * types[] = { "Header", "Detail", "Footer",
               "GroupHeader", "GroupFooter", "PageHeader", "PageFooter" };
            int idx = id - 2010;
            if( idx >= 0 && idx < 7 && s_rptBandCount < RPT_MAX_BANDS )
            {
               RptBand * b = &s_rptBands[s_rptBandCount];
               memset( b, 0, sizeof(RptBand) );
               strncpy( b->cName, types[idx], sizeof(b->cName) - 1 );
               b->nHeight = 80;
               b->lVisible = 1;
               b->color = rpt_band_color( types[idx] );
               s_rptBandCount++;
               InvalidateRect( hWnd, NULL, FALSE );
            }
         }
         else if( id == RPT_ID_ADD_FIELD )
         {
            int bi = s_rptSelBand >= 0 ? s_rptSelBand : 0;
            if( bi < s_rptBandCount )
            {
               RptBand * b = &s_rptBands[bi];
               if( b->nFieldCount < RPT_MAX_FIELDS )
               {
                  RptField * f = &b->fields[b->nFieldCount];
                  memset( f, 0, sizeof(RptField) );
                  snprintf( f->cName, sizeof(f->cName), "Field%d", b->nFieldCount + 1 );
                  snprintf( f->cText, sizeof(f->cText), "Field%d", b->nFieldCount + 1 );
                  f->nLeft   = 10 + (b->nFieldCount % 4) * 80;
                  f->nTop    = 10;
                  f->nWidth  = 70;
                  f->nHeight = 20;
                  s_rptSelBand  = bi;
                  s_rptSelField = b->nFieldCount;
                  b->nFieldCount++;
                  InvalidateRect( hWnd, NULL, FALSE );
               }
            }
         }
         else if( id == RPT_ID_DELETE )
         {
            if( s_rptSelBand >= 0 )
            {
               if( s_rptSelField >= 0 )
               {
                  /* Delete field */
                  RptBand * b = &s_rptBands[s_rptSelBand];
                  int f = s_rptSelField;
                  if( f < b->nFieldCount - 1 )
                     memmove( &b->fields[f], &b->fields[f + 1],
                              sizeof(RptField) * (b->nFieldCount - f - 1) );
                  b->nFieldCount--;
                  s_rptSelField = -1;
               }
               else
               {
                  /* Delete band */
                  int i = s_rptSelBand;
                  if( i < s_rptBandCount - 1 )
                     memmove( &s_rptBands[i], &s_rptBands[i + 1],
                              sizeof(RptBand) * (s_rptBandCount - i - 1) );
                  s_rptBandCount--;
                  s_rptSelBand = -1;
               }
               InvalidateRect( hWnd, NULL, FALSE );
            }
         }
         return 0;
      }

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;

      case WM_ERASEBKGND:
         return 1;  /* handled in WM_PAINT */
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* RPT_DESIGNEROPEN() - create/show the report designer window */
HB_FUNC( RPT_DESIGNEROPEN )
{
   if( s_rptDesigner )
   {
      ShowWindow( s_rptDesigner, SW_SHOW );
      SetForegroundWindow( s_rptDesigner );
      return;
   }

   /* Register window class */
   {  WNDCLASSEXA wc = { sizeof(WNDCLASSEXA) };
      wc.lpfnWndProc = RptDesignerProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.lpszClassName = RPT_DESIGNER_CLASS;
      wc.hCursor = LoadCursor( NULL, IDC_ARROW );
      wc.hbrBackground = CreateSolidBrush( RGB(37,37,38) );
      RegisterClassExA( &wc );
   }

   s_rptDesigner = CreateWindowExA( WS_EX_TOOLWINDOW, RPT_DESIGNER_CLASS,
      "Report Designer",
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      120, 80, 800, 600, NULL, NULL, GetModuleHandle(NULL), NULL );

   /* Dark title bar */
   {  typedef HRESULT (WINAPI *PFN)(HWND, DWORD, LPCVOID, DWORD);
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         PFN pFn = (PFN)GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( pFn ) { BOOL val = TRUE; pFn( s_rptDesigner, 20, &val, sizeof(val) ); }
         FreeLibrary( hDwm );
      }
   }

   /* Toolbar with buttons */
   {  int bx = 4;
      HWND hBtn;
      HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

      /* Add Band dropdown button */
      hBtn = CreateWindowExA( 0, "BUTTON", "Add Band",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         bx, 4, 80, 26, s_rptDesigner, (HMENU)(LONG_PTR)RPT_ID_ADD_BAND,
         GetModuleHandle(NULL), NULL );
      SendMessageA( hBtn, WM_SETFONT, (WPARAM)hFont, TRUE );
      bx += 84;

      hBtn = CreateWindowExA( 0, "BUTTON", "Add Field",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         bx, 4, 80, 26, s_rptDesigner, (HMENU)(LONG_PTR)RPT_ID_ADD_FIELD,
         GetModuleHandle(NULL), NULL );
      SendMessageA( hBtn, WM_SETFONT, (WPARAM)hFont, TRUE );
      bx += 84;

      hBtn = CreateWindowExA( 0, "BUTTON", "Delete",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         bx, 4, 70, 26, s_rptDesigner, (HMENU)(LONG_PTR)RPT_ID_DELETE,
         GetModuleHandle(NULL), NULL );
      SendMessageA( hBtn, WM_SETFONT, (WPARAM)hFont, TRUE );
      bx += 74;

      hBtn = CreateWindowExA( 0, "BUTTON", "Preview",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         bx, 4, 70, 26, s_rptDesigner, (HMENU)(LONG_PTR)RPT_ID_PREVIEW,
         GetModuleHandle(NULL), NULL );
      SendMessageA( hBtn, WM_SETFONT, (WPARAM)hFont, TRUE );

      /* "Add Band" shows a popup menu with 7 band types */
      /* Handled when RPT_ID_ADD_BAND is clicked: */
   }
}

/* Override Add Band button to show popup menu */
static void RptShowAddBandMenu( HWND hWnd )
{
   HMENU hMenu = CreatePopupMenu();
   const char * types[] = { "Header", "Detail", "Footer",
      "GroupHeader", "GroupFooter", "PageHeader", "PageFooter" };
   for( int i = 0; i < 7; i++ )
      AppendMenuA( hMenu, MF_STRING, 2010 + i, types[i] );

   RECT rc;
   GetWindowRect( GetDlgItem( hWnd, RPT_ID_ADD_BAND ) ? hWnd : hWnd, &rc );
   /* Get button position */
   HWND hBtn = NULL;
   HWND hChild = GetWindow( hWnd, GW_CHILD );
   while( hChild )
   {
      if( GetDlgCtrlID( hChild ) == RPT_ID_ADD_BAND ) { hBtn = hChild; break; }
      hChild = GetWindow( hChild, GW_HWNDNEXT );
   }
   if( hBtn )
   {
      GetWindowRect( hBtn, &rc );
      TrackPopupMenu( hMenu, TPM_LEFTALIGN | TPM_TOPALIGN, rc.left, rc.bottom, 0, hWnd, NULL );
   }
   DestroyMenu( hMenu );
}

/* RPT_DESIGNERCLOSE() */
HB_FUNC( RPT_DESIGNERCLOSE )
{
   if( s_rptDesigner )
      ShowWindow( s_rptDesigner, SW_HIDE );
}

/* RPT_SETREPORT( nReportHandle ) - reserved for future Harbour object binding */
HB_FUNC( RPT_SETREPORT )
{
   (void)hb_parni(1);
}

/* RPT_ADDBAND( cBandName, nHeight ) -> nIndex */
HB_FUNC( RPT_ADDBAND )
{
   if( s_rptBandCount >= RPT_MAX_BANDS ) { hb_retni( -1 ); return; }

   const char * cName = hb_parc(1);
   int nHeight = HB_ISNUM(2) ? hb_parni(2) : 80;

   if( !cName || !cName[0] ) { hb_retni( -1 ); return; }

   RptBand * b = &s_rptBands[s_rptBandCount];
   memset( b, 0, sizeof(RptBand) );
   strncpy( b->cName, cName, sizeof(b->cName) - 1 );
   b->nHeight = nHeight;
   b->lVisible = 1;
   b->color = rpt_band_color( cName );

   int idx = s_rptBandCount;
   s_rptBandCount++;

   if( s_rptDesigner ) InvalidateRect( s_rptDesigner, NULL, FALSE );
   hb_retni( idx );
}

/* RPT_ADDFIELD( nBandIndex, cName, cText, nLeft, nTop, nWidth, nHeight ) -> nFieldIndex */
HB_FUNC( RPT_ADDFIELD )
{
   int bi = hb_parni(1);
   if( bi < 0 || bi >= s_rptBandCount ) { hb_retni( -1 ); return; }

   RptBand * b = &s_rptBands[bi];
   if( b->nFieldCount >= RPT_MAX_FIELDS ) { hb_retni( -1 ); return; }

   RptField * f = &b->fields[b->nFieldCount];
   memset( f, 0, sizeof(RptField) );

   if( HB_ISCHAR(2) ) strncpy( f->cName, hb_parc(2), sizeof(f->cName) - 1 );
   if( HB_ISCHAR(3) ) strncpy( f->cText, hb_parc(3), sizeof(f->cText) - 1 );
   f->nLeft   = HB_ISNUM(4) ? hb_parni(4) : 10;
   f->nTop    = HB_ISNUM(5) ? hb_parni(5) : 10;
   f->nWidth  = HB_ISNUM(6) ? hb_parni(6) : 70;
   f->nHeight = HB_ISNUM(7) ? hb_parni(7) : 20;

   int idx = b->nFieldCount;
   b->nFieldCount++;

   if( s_rptDesigner ) InvalidateRect( s_rptDesigner, NULL, FALSE );
   hb_retni( idx );
}

/* RPT_GETSELECTED() -> { nBandIdx, nFieldIdx, cBandName, cFieldName } */
HB_FUNC( RPT_GETSELECTED )
{
   PHB_ITEM pArray = hb_itemArrayNew( 4 );
   hb_arraySetNI( pArray, 1, s_rptSelBand );
   hb_arraySetNI( pArray, 2, s_rptSelField );

   if( s_rptSelBand >= 0 && s_rptSelBand < s_rptBandCount )
   {
      hb_arraySetC( pArray, 3, s_rptBands[s_rptSelBand].cName );
      if( s_rptSelField >= 0 && s_rptSelField < s_rptBands[s_rptSelBand].nFieldCount )
         hb_arraySetC( pArray, 4, s_rptBands[s_rptSelBand].fields[s_rptSelField].cName );
      else
         hb_arraySetC( pArray, 4, "" );
   }
   else
   {
      hb_arraySetC( pArray, 3, "" );
      hb_arraySetC( pArray, 4, "" );
   }
   hb_itemReturnRelease( pArray );
}

/* RPT_GETBANDPROPS( nBandIndex ) -> { {cPropName, xValue, cCategory, cType}, ... } */
HB_FUNC( RPT_GETBANDPROPS )
{
   int bi = hb_parni(1);
   if( bi < 0 || bi >= s_rptBandCount ) { hb_reta(0); return; }

   RptBand * b = &s_rptBands[bi];
   PHB_ITEM pArray = hb_itemArrayNew( 5 );
   PHB_ITEM pRow;

   pRow = hb_itemArrayNew(4);
   hb_arraySetC(pRow,1,"cName"); hb_arraySetC(pRow,2,b->cName);
   hb_arraySetC(pRow,3,"Info"); hb_arraySetC(pRow,4,"S");
   hb_arraySet(pArray,1,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4);
   hb_arraySetC(pRow,1,"nHeight"); hb_arraySetNI(pRow,2,b->nHeight);
   hb_arraySetC(pRow,3,"Position"); hb_arraySetC(pRow,4,"N");
   hb_arraySet(pArray,2,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4);
   hb_arraySetC(pRow,1,"lPrintOnEveryPage"); hb_arraySetL(pRow,2,b->lPrintOnEveryPage?HB_TRUE:HB_FALSE);
   hb_arraySetC(pRow,3,"Behavior"); hb_arraySetC(pRow,4,"L");
   hb_arraySet(pArray,3,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4);
   hb_arraySetC(pRow,1,"lKeepTogether"); hb_arraySetL(pRow,2,b->lKeepTogether?HB_TRUE:HB_FALSE);
   hb_arraySetC(pRow,3,"Behavior"); hb_arraySetC(pRow,4,"L");
   hb_arraySet(pArray,4,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4);
   hb_arraySetC(pRow,1,"lVisible"); hb_arraySetL(pRow,2,b->lVisible?HB_TRUE:HB_FALSE);
   hb_arraySetC(pRow,3,"Behavior"); hb_arraySetC(pRow,4,"L");
   hb_arraySet(pArray,5,pRow); hb_itemRelease(pRow);

   hb_itemReturnRelease( pArray );
}

/* RPT_GETFIELDPROPS( nBandIndex, nFieldIndex ) -> { {cPropName, xValue, cCategory, cType}, ... } */
HB_FUNC( RPT_GETFIELDPROPS )
{
   int bi = hb_parni(1), fi = hb_parni(2);
   if( bi < 0 || bi >= s_rptBandCount || fi < 0 || fi >= s_rptBands[bi].nFieldCount )
   { hb_reta(0); return; }

   RptField * f = &s_rptBands[bi].fields[fi];
   PHB_ITEM pArray = hb_itemArrayNew( 8 );
   PHB_ITEM pRow;

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"cName"); hb_arraySetC(pRow,2,f->cName);
   hb_arraySetC(pRow,3,"Info"); hb_arraySetC(pRow,4,"S"); hb_arraySet(pArray,1,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"cText"); hb_arraySetC(pRow,2,f->cText);
   hb_arraySetC(pRow,3,"Appearance"); hb_arraySetC(pRow,4,"S"); hb_arraySet(pArray,2,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"cFieldName"); hb_arraySetC(pRow,2,f->cFieldName);
   hb_arraySetC(pRow,3,"Data"); hb_arraySetC(pRow,4,"S"); hb_arraySet(pArray,3,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"nLeft"); hb_arraySetNI(pRow,2,f->nLeft);
   hb_arraySetC(pRow,3,"Position"); hb_arraySetC(pRow,4,"N"); hb_arraySet(pArray,4,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"nTop"); hb_arraySetNI(pRow,2,f->nTop);
   hb_arraySetC(pRow,3,"Position"); hb_arraySetC(pRow,4,"N"); hb_arraySet(pArray,5,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"nWidth"); hb_arraySetNI(pRow,2,f->nWidth);
   hb_arraySetC(pRow,3,"Position"); hb_arraySetC(pRow,4,"N"); hb_arraySet(pArray,6,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"nHeight"); hb_arraySetNI(pRow,2,f->nHeight);
   hb_arraySetC(pRow,3,"Position"); hb_arraySetC(pRow,4,"N"); hb_arraySet(pArray,7,pRow); hb_itemRelease(pRow);

   pRow = hb_itemArrayNew(4); hb_arraySetC(pRow,1,"nAlignment"); hb_arraySetNI(pRow,2,f->nAlignment);
   hb_arraySetC(pRow,3,"Appearance"); hb_arraySetC(pRow,4,"N"); hb_arraySet(pArray,8,pRow); hb_itemRelease(pRow);

   hb_itemReturnRelease( pArray );
}

/* RPT_SETBANDPROP( nBandIndex, cPropName, xValue ) */
HB_FUNC( RPT_SETBANDPROP )
{
   int bi = hb_parni(1);
   const char * cProp = hb_parc(2);
   if( bi < 0 || bi >= s_rptBandCount || !cProp ) { hb_retl(HB_FALSE); return; }

   RptBand * b = &s_rptBands[bi];

   if( strcmp(cProp,"cName")==0 && HB_ISCHAR(3) )
      strncpy( b->cName, hb_parc(3), sizeof(b->cName)-1 );
   else if( strcmp(cProp,"nHeight")==0 && HB_ISNUM(3) )
      b->nHeight = hb_parni(3);
   else if( strcmp(cProp,"lPrintOnEveryPage")==0 && HB_ISLOG(3) )
      b->lPrintOnEveryPage = hb_parl(3) ? 1 : 0;
   else if( strcmp(cProp,"lKeepTogether")==0 && HB_ISLOG(3) )
      b->lKeepTogether = hb_parl(3) ? 1 : 0;
   else if( strcmp(cProp,"lVisible")==0 && HB_ISLOG(3) )
      b->lVisible = hb_parl(3) ? 1 : 0;
   else { hb_retl(HB_FALSE); return; }

   if( s_rptDesigner ) InvalidateRect( s_rptDesigner, NULL, FALSE );
   hb_retl( HB_TRUE );
}

/* RPT_SETFIELDPROP( nBandIndex, nFieldIndex, cPropName, xValue ) */
HB_FUNC( RPT_SETFIELDPROP )
{
   int bi = hb_parni(1), fi = hb_parni(2);
   const char * cProp = hb_parc(3);
   if( bi < 0 || bi >= s_rptBandCount || fi < 0 || fi >= s_rptBands[bi].nFieldCount || !cProp )
   { hb_retl(HB_FALSE); return; }

   RptField * f = &s_rptBands[bi].fields[fi];

   if( strcmp(cProp,"cName")==0 && HB_ISCHAR(4) )
      strncpy( f->cName, hb_parc(4), sizeof(f->cName)-1 );
   else if( strcmp(cProp,"cText")==0 && HB_ISCHAR(4) )
      strncpy( f->cText, hb_parc(4), sizeof(f->cText)-1 );
   else if( strcmp(cProp,"cFieldName")==0 && HB_ISCHAR(4) )
      strncpy( f->cFieldName, hb_parc(4), sizeof(f->cFieldName)-1 );
   else if( strcmp(cProp,"nLeft")==0 && HB_ISNUM(4) )      f->nLeft = hb_parni(4);
   else if( strcmp(cProp,"nTop")==0 && HB_ISNUM(4) )       f->nTop = hb_parni(4);
   else if( strcmp(cProp,"nWidth")==0 && HB_ISNUM(4) )     f->nWidth = hb_parni(4);
   else if( strcmp(cProp,"nHeight")==0 && HB_ISNUM(4) )    f->nHeight = hb_parni(4);
   else if( strcmp(cProp,"nAlignment")==0 && HB_ISNUM(4) ) f->nAlignment = hb_parni(4);
   else { hb_retl(HB_FALSE); return; }

   if( s_rptDesigner ) InvalidateRect( s_rptDesigner, NULL, FALSE );
   hb_retl( HB_TRUE );
}

/* ================================================================
 * REPORT PREVIEW - RPT_Preview* functions
 * Page rendering with GDI, zoom, navigation
 * (Data types and statics declared above, before Designer section)
 * ================================================================ */

static void RptPrvUpdateLabel(void)
{
   if( !s_rptPrvPageLabel ) return;
   char buf[64];
   snprintf( buf, sizeof(buf), "Page %d / %d  (%d%%)",
      s_rptPrvCurPage + 1, s_rptPrvPageCount > 0 ? s_rptPrvPageCount : 1,
      s_rptPreviewZoom );
   SetWindowTextA( s_rptPrvPageLabel, buf );
}

/* Preview paint */
static void RptPreviewPaint( HWND hWnd )
{
   PAINTSTRUCT ps;
   HDC hdc = BeginPaint( hWnd, &ps );
   RECT rc; GetClientRect( hWnd, &rc );

   HDC memDC = CreateCompatibleDC( hdc );
   HBITMAP memBmp = CreateCompatibleBitmap( hdc, rc.right, rc.bottom );
   SelectObject( memDC, memBmp );

   /* Dark background */
   HBRUSH hBrBg = CreateSolidBrush( RGB(50,50,50) );
   FillRect( memDC, &rc, hBrBg );
   DeleteObject( hBrBg );

   if( s_rptPrvPageCount > 0 )
   {
   /* Page dimensions scaled by zoom */
   double scale = s_rptPreviewZoom / 100.0 * 3.0;  /* 3 px/mm at 100% */
   int pgW = (int)(s_rptPrvPgW * scale);
   int pgH = (int)(s_rptPrvPgH * scale);
   int pgX = (rc.right - pgW) / 2;
   int pgY = 40;
   if( pgX < 20 ) pgX = 20;

   /* White page with shadow */
   HBRUSH hBrShadow = CreateSolidBrush( RGB(30,30,30) );
   RECT rcShadow = { pgX + 4, pgY + 4, pgX + pgW + 4, pgY + pgH + 4 };
   FillRect( memDC, &rcShadow, hBrShadow );
   DeleteObject( hBrShadow );

   HBRUSH hBrPage = CreateSolidBrush( RGB(255,255,255) );
   RECT rcPage = { pgX, pgY, pgX + pgW, pgY + pgH };
   FillRect( memDC, &rcPage, hBrPage );
   DeleteObject( hBrPage );

   /* Dashed margin lines */
   HPEN hPenMargin = CreatePen( PS_DOT, 1, RGB(200,200,200) );
   SelectObject( memDC, hPenMargin );
   int mgL = (int)(s_rptPrvMgL * scale);
   int mgR = (int)(s_rptPrvMgR * scale);
   int mgT = (int)(s_rptPrvMgT * scale);
   int mgB = (int)(s_rptPrvMgB * scale);
   MoveToEx( memDC, pgX + mgL, pgY, NULL ); LineTo( memDC, pgX + mgL, pgY + pgH );
   MoveToEx( memDC, pgX + pgW - mgR, pgY, NULL ); LineTo( memDC, pgX + pgW - mgR, pgY + pgH );
   MoveToEx( memDC, pgX, pgY + mgT, NULL ); LineTo( memDC, pgX + pgW, pgY + mgT );
   MoveToEx( memDC, pgX, pgY + pgH - mgB, NULL ); LineTo( memDC, pgX + pgW, pgY + pgH - mgB );
   DeleteObject( hPenMargin );

   /* Render draw commands for current page */
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvCurPage];
   SetBkMode( memDC, TRANSPARENT );

   for( int i = 0; i < pg->nCmds; i++ )
   {
      RptDrawCmd * cmd = &pg->cmds[i];
      int cx = pgX + (int)(cmd->x * scale);
      int cy = pgY + (int)(cmd->y * scale);

      switch( cmd->type )
      {
         case 1: /* Text */
         {
            int fs = (int)(cmd->fontSize * scale / 3.0);
            if( fs < 8 ) fs = 8;
            HFONT hFont = CreateFontA( -fs, 0, 0, 0,
               cmd->bold ? FW_BOLD : FW_NORMAL,
               cmd->italic, FALSE, FALSE,
               DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY,
               DEFAULT_PITCH, cmd->fontName[0] ? cmd->fontName : "Segoe UI" );
            SelectObject( memDC, hFont );
            SetTextColor( memDC, RGB(
               (cmd->color >> 16) & 0xFF,
               (cmd->color >> 8) & 0xFF,
               cmd->color & 0xFF ) );
            TextOutA( memDC, cx, cy, cmd->text, (int)strlen(cmd->text) );
            DeleteObject( hFont );
            break;
         }
         case 2: /* Rectangle */
         {
            int cw = (int)(cmd->w * scale);
            int ch = (int)(cmd->h * scale);
            COLORREF clr = RGB( (cmd->color>>16)&0xFF, (cmd->color>>8)&0xFF, cmd->color&0xFF );
            if( cmd->filled )
            {
               HBRUSH hBr = CreateSolidBrush( clr );
               RECT r = { cx, cy, cx + cw, cy + ch };
               FillRect( memDC, &r, hBr );
               DeleteObject( hBr );
            }
            else
            {
               HPEN hPen = CreatePen( PS_SOLID, 1, clr );
               SelectObject( memDC, hPen );
               SelectObject( memDC, GetStockObject(NULL_BRUSH) );
               Rectangle( memDC, cx, cy, cx + cw, cy + ch );
               DeleteObject( hPen );
            }
            break;
         }
         case 3: /* Line */
         {
            int cx2 = pgX + (int)(cmd->x2 * scale);
            int cy2 = pgY + (int)(cmd->y2 * scale);
            COLORREF clr = RGB( (cmd->color>>16)&0xFF, (cmd->color>>8)&0xFF, cmd->color&0xFF );
            HPEN hPen = CreatePen( PS_SOLID, cmd->lineWidth > 0 ? cmd->lineWidth : 1, clr );
            SelectObject( memDC, hPen );
            MoveToEx( memDC, cx, cy, NULL );
            LineTo( memDC, cx2, cy2 );
            DeleteObject( hPen );
            break;
         }
      }
   }
   } /* end if( s_rptPrvPageCount > 0 ) */

   BitBlt( hdc, 0, 0, rc.right, rc.bottom, memDC, 0, 0, SRCCOPY );
   DeleteObject( memBmp );
   DeleteDC( memDC );
   EndPaint( hWnd, &ps );
}

/* Preview WndProc */
#define RPT_PREVIEW_CLASS "HbRptPreview"
#define RPT_PRV_FIRST 3001
#define RPT_PRV_PREV  3002
#define RPT_PRV_NEXT  3003
#define RPT_PRV_LAST  3004
#define RPT_PRV_ZOOMIN  3005
#define RPT_PRV_ZOOMOUT 3006
#define RPT_PRV_CLOSE   3007

static LRESULT CALLBACK RptPreviewProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_PAINT:
         RptPreviewPaint( hWnd );
         return 0;

      case WM_COMMAND:
      {
         int id = LOWORD(wParam);
         switch( id )
         {
            case RPT_PRV_FIRST: s_rptPrvCurPage = 0; break;
            case RPT_PRV_PREV:  if(s_rptPrvCurPage>0) s_rptPrvCurPage--; break;
            case RPT_PRV_NEXT:  if(s_rptPrvCurPage<s_rptPrvPageCount-1) s_rptPrvCurPage++; break;
            case RPT_PRV_LAST:  s_rptPrvCurPage = s_rptPrvPageCount > 0 ? s_rptPrvPageCount-1 : 0; break;
            case RPT_PRV_ZOOMIN:  if(s_rptPreviewZoom<400) s_rptPreviewZoom+=25; break;
            case RPT_PRV_ZOOMOUT: if(s_rptPreviewZoom>25) s_rptPreviewZoom-=25; break;
            case RPT_PRV_CLOSE: ShowWindow(hWnd,SW_HIDE); return 0;
         }
         RptPrvUpdateLabel();
         InvalidateRect( hWnd, NULL, FALSE );
         return 0;
      }

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;

      case WM_ERASEBKGND:
         return 1;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* RPT_PREVIEWOPEN( nPageWidth, nPageHeight, nMarginL, nMarginR, nMarginT, nMarginB ) */
HB_FUNC( RPT_PREVIEWOPEN )
{
   s_rptPrvPgW = HB_ISNUM(1) ? hb_parni(1) : 210;
   s_rptPrvPgH = HB_ISNUM(2) ? hb_parni(2) : 297;
   s_rptPrvMgL = HB_ISNUM(3) ? hb_parni(3) : 15;
   s_rptPrvMgR = HB_ISNUM(4) ? hb_parni(4) : 15;
   s_rptPrvMgT = HB_ISNUM(5) ? hb_parni(5) : 15;
   s_rptPrvMgB = HB_ISNUM(6) ? hb_parni(6) : 15;

   s_rptPrvPageCount = 0;
   s_rptPrvCurPage = 0;
   memset( s_rptPrvPages, 0, sizeof(s_rptPrvPages) );
   s_rptPreviewZoom = 100;

   if( s_rptPreview )
   {
      ShowWindow( s_rptPreview, SW_SHOW );
      SetForegroundWindow( s_rptPreview );
      RptPrvUpdateLabel();
      return;
   }

   /* Register */
   {  WNDCLASSEXA wc = { sizeof(WNDCLASSEXA) };
      wc.lpfnWndProc = RptPreviewProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.lpszClassName = RPT_PREVIEW_CLASS;
      wc.hCursor = LoadCursor( NULL, IDC_ARROW );
      wc.hbrBackground = CreateSolidBrush( RGB(50,50,50) );
      RegisterClassExA( &wc );
   }

   s_rptPreview = CreateWindowExA( 0, RPT_PREVIEW_CLASS, "Report Preview",
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      80, 40, 750, 850, NULL, NULL, GetModuleHandle(NULL), NULL );

   /* Dark title bar */
   {  typedef HRESULT (WINAPI *PFN)(HWND, DWORD, LPCVOID, DWORD);
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         PFN pFn = (PFN)GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( pFn ) { BOOL val = TRUE; pFn( s_rptPreview, 20, &val, sizeof(val) ); }
         FreeLibrary( hDwm );
      }
   }

   /* Toolbar */
   HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
   int bx = 4;
   struct { const char * text; int id; int w; } btns[] = {
      { "|<", RPT_PRV_FIRST, 30 }, { "<", RPT_PRV_PREV, 30 },
      { ">", RPT_PRV_NEXT, 30 },   { ">|", RPT_PRV_LAST, 30 },
      { "Zoom +", RPT_PRV_ZOOMIN, 60 }, { "Zoom -", RPT_PRV_ZOOMOUT, 60 },
      { "Close", RPT_PRV_CLOSE, 60 }
   };
   for( int i = 0; i < 7; i++ )
   {
      HWND hBtn = CreateWindowExA( 0, "BUTTON", btns[i].text,
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         bx, 4, btns[i].w, 26, s_rptPreview, (HMENU)(LONG_PTR)btns[i].id,
         GetModuleHandle(NULL), NULL );
      SendMessageA( hBtn, WM_SETFONT, (WPARAM)hFont, TRUE );
      bx += btns[i].w + 4;
   }

   /* Page label */
   s_rptPrvPageLabel = CreateWindowExA( 0, "STATIC", "",
      WS_CHILD | WS_VISIBLE | SS_LEFT,
      bx + 8, 8, 200, 20, s_rptPreview, NULL, GetModuleHandle(NULL), NULL );
   SendMessageA( s_rptPrvPageLabel, WM_SETFONT, (WPARAM)hFont, TRUE );
   RptPrvUpdateLabel();
}

/* RPT_PREVIEWCLOSE() */
HB_FUNC( RPT_PREVIEWCLOSE )
{
   if( s_rptPreview ) ShowWindow( s_rptPreview, SW_HIDE );
}

/* RPT_PREVIEWADDPAGE() */
HB_FUNC( RPT_PREVIEWADDPAGE )
{
   if( s_rptPrvPageCount >= RPT_PRV_MAX_PAGES ) { hb_retl(HB_FALSE); return; }
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount];
   memset( pg, 0, sizeof(RptPrvPage) );
   s_rptPrvPageCount++;
   s_rptPrvCurPage = s_rptPrvPageCount - 1;
   hb_retl( HB_TRUE );
}

/* RPT_PREVIEWDRAWTEXT( nX, nY, cText, cFontName, nFontSize, lBold, lItalic, nColor ) */
HB_FUNC( RPT_PREVIEWDRAWTEXT )
{
   if( s_rptPrvPageCount <= 0 ) return;
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount - 1];
   if( pg->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
   memset( cmd, 0, sizeof(RptDrawCmd) );
   cmd->type = 1;
   cmd->x = hb_parni(1);
   cmd->y = hb_parni(2);
   if( HB_ISCHAR(3) ) strncpy( cmd->text, hb_parc(3), sizeof(cmd->text)-1 );
   if( HB_ISCHAR(4) ) strncpy( cmd->fontName, hb_parc(4), sizeof(cmd->fontName)-1 );
   cmd->fontSize = HB_ISNUM(5) ? hb_parni(5) : 10;
   cmd->bold     = HB_ISLOG(6) ? ( hb_parl(6) ? 1 : 0 ) : 0;
   cmd->italic   = HB_ISLOG(7) ? ( hb_parl(7) ? 1 : 0 ) : 0;
   cmd->color    = HB_ISNUM(8) ? hb_parni(8) : 0;
   pg->nCmds++;
}

/* RPT_PREVIEWDRAWRECT( nX, nY, nW, nH, nColor, lFilled ) */
HB_FUNC( RPT_PREVIEWDRAWRECT )
{
   if( s_rptPrvPageCount <= 0 ) return;
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount - 1];
   if( pg->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
   memset( cmd, 0, sizeof(RptDrawCmd) );
   cmd->type   = 2;
   cmd->x      = hb_parni(1);
   cmd->y      = hb_parni(2);
   cmd->w      = hb_parni(3);
   cmd->h      = hb_parni(4);
   cmd->color  = HB_ISNUM(5) ? hb_parni(5) : 0;
   cmd->filled = HB_ISLOG(6) ? ( hb_parl(6) ? 1 : 0 ) : 0;
   pg->nCmds++;
}

/* RPT_PREVIEWDRAWLINE( nX1, nY1, nX2, nY2, nColor, nWidth ) */
HB_FUNC( RPT_PREVIEWDRAWLINE )
{
   if( s_rptPrvPageCount <= 0 ) return;
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount - 1];
   if( pg->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
   memset( cmd, 0, sizeof(RptDrawCmd) );
   cmd->type      = 3;
   cmd->x         = hb_parni(1);
   cmd->y         = hb_parni(2);
   cmd->x2        = hb_parni(3);
   cmd->y2        = hb_parni(4);
   cmd->color     = HB_ISNUM(5) ? hb_parni(5) : 0;
   cmd->lineWidth = HB_ISNUM(6) ? hb_parni(6) : 1;
   pg->nCmds++;
}

/* RPT_PREVIEWRENDER() */
HB_FUNC( RPT_PREVIEWRENDER )
{
   if( s_rptPrvPageCount > 0 ) s_rptPrvCurPage = 0;
   RptPrvUpdateLabel();
   if( s_rptPreview ) InvalidateRect( s_rptPreview, NULL, FALSE );
}

/* ================================================================
 * GIT INTEGRATION - Wraps git.exe CLI commands
 * Returns output as Harbour strings/arrays.
 * ================================================================ */

/* Helper: run a git command and capture stdout */
static char * GitExec( const char * szArgs, const char * szWorkDir )
{
   HANDLE hReadPipe, hWritePipe;
   SECURITY_ATTRIBUTES sa = { sizeof(sa), NULL, TRUE };
   PROCESS_INFORMATION pi = {0};
   STARTUPINFOA si = { sizeof(si) };
   char cmdLine[1024];
   char * pBuf = NULL;
   DWORD dwRead, dwTotal = 0, dwBufSize = 4096;

   if( !CreatePipe( &hReadPipe, &hWritePipe, &sa, 0 ) ) return NULL;
   SetHandleInformation( hReadPipe, HANDLE_FLAG_INHERIT, 0 );

   si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
   si.hStdOutput = hWritePipe;
   si.hStdError  = hWritePipe;
   si.hStdInput  = NULL;
   si.wShowWindow = SW_HIDE;

   snprintf( cmdLine, sizeof(cmdLine), "git %s", szArgs );

   if( !CreateProcessA( NULL, cmdLine, NULL, NULL, TRUE,
      CREATE_NO_WINDOW, NULL, szWorkDir, &si, &pi ) )
   {
      CloseHandle( hReadPipe );
      CloseHandle( hWritePipe );
      return NULL;
   }
   CloseHandle( hWritePipe );

   pBuf = (char *) malloc( dwBufSize );
   pBuf[0] = 0;

   while( ReadFile( hReadPipe, pBuf + dwTotal, dwBufSize - dwTotal - 1, &dwRead, NULL ) && dwRead > 0 )
   {
      dwTotal += dwRead;
      if( dwTotal >= dwBufSize - 256 )
      {
         dwBufSize *= 2;
         pBuf = (char *) realloc( pBuf, dwBufSize );
      }
   }
   pBuf[dwTotal] = 0;

   WaitForSingleObject( pi.hProcess, 5000 );
   CloseHandle( pi.hProcess );
   CloseHandle( pi.hThread );
   CloseHandle( hReadPipe );

   return pBuf;
}

/* GIT_Exec( cArgs, [cWorkDir] ) -> cOutput
 * Run any git command and return raw output */
HB_FUNC( GIT_EXEC )
{
   const char * szArgs = hb_parc(1);
   const char * szDir  = HB_ISCHAR(2) ? hb_parc(2) : ".";
   if( !szArgs ) { hb_retc(""); return; }
   char * pOut = GitExec( szArgs, szDir );
   if( pOut ) { hb_retc( pOut ); free( pOut ); }
   else hb_retc( "" );
}

/* GIT_Status( [cWorkDir] ) -> { { cStatus, cFile }, ... }
 * Parse `git status --porcelain` into array of {status, filename} */
HB_FUNC( GIT_STATUS )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "status --porcelain", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   if( pOut )
   {
      char * p = pOut;
      while( *p )
      {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);

         if( eol - p >= 4 )
         {
            PHB_ITEM pEntry = hb_itemArrayNew( 2 );
            char status[4] = { p[0], p[1], 0 };
            char file[512];
            int fLen = (int)(eol - p - 3);
            if( fLen > 511 ) fLen = 511;
            strncpy( file, p + 3, fLen );
            file[fLen] = 0;

            hb_arraySetC( pEntry, 1, status );
            hb_arraySetC( pEntry, 2, file );
            hb_arrayAdd( pArray, pEntry );
            hb_itemRelease( pEntry );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_Log( [nCount], [cWorkDir] ) -> { { cHash, cAuthor, cDate, cMessage }, ... } */
HB_FUNC( GIT_LOG )
{
   int nCount = HB_ISNUM(1) ? hb_parni(1) : 20;
   const char * szDir = HB_ISCHAR(2) ? hb_parc(2) : ".";
   char args[256];
   snprintf( args, sizeof(args),
      "log --oneline --format=%%H|%%an|%%ar|%%s -n %d", nCount );

   char * pOut = GitExec( args, szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   if( pOut )
   {
      char * p = pOut;
      while( *p )
      {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);

         if( eol > p )
         {
            /* Parse: hash|author|date|message */
            char line[1024];
            int len = (int)(eol - p);
            if( len > 1023 ) len = 1023;
            strncpy( line, p, len ); line[len] = 0;

            char * f1 = line;
            char * f2 = strchr(f1, '|'); if(f2) *f2++ = 0; else f2 = (char*)"";
            char * f3 = strchr(f2, '|'); if(f3) *f3++ = 0; else f3 = (char*)"";
            char * f4 = strchr(f3, '|'); if(f4) *f4++ = 0; else f4 = (char*)"";

            PHB_ITEM pEntry = hb_itemArrayNew( 4 );
            hb_arraySetC( pEntry, 1, f1 );
            hb_arraySetC( pEntry, 2, f2 );
            hb_arraySetC( pEntry, 3, f3 );
            hb_arraySetC( pEntry, 4, f4 );
            hb_arrayAdd( pArray, pEntry );
            hb_itemRelease( pEntry );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_Diff( [cFile], [cWorkDir] ) -> cDiffText */
HB_FUNC( GIT_DIFF )
{
   const char * szFile = HB_ISCHAR(1) ? hb_parc(1) : "";
   const char * szDir  = HB_ISCHAR(2) ? hb_parc(2) : ".";
   char args[512];
   if( szFile[0] )
      snprintf( args, sizeof(args), "diff -- \"%s\"", szFile );
   else
      snprintf( args, sizeof(args), "diff" );

   char * pOut = GitExec( args, szDir );
   if( pOut ) { hb_retc( pOut ); free( pOut ); }
   else hb_retc( "" );
}

/* GIT_BranchList( [cWorkDir] ) -> { { cName, lCurrent }, ... } */
HB_FUNC( GIT_BRANCHLIST )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "branch --no-color", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   if( pOut )
   {
      char * p = pOut;
      while( *p )
      {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);

         if( eol - p >= 2 )
         {
            PHB_ITEM pEntry = hb_itemArrayNew( 2 );
            int isCurrent = ( p[0] == '*' ) ? 1 : 0;
            char name[256];
            char * start = p + 2;
            int nLen = (int)(eol - start);
            if( nLen > 255 ) nLen = 255;
            strncpy( name, start, nLen ); name[nLen] = 0;
            /* Trim trailing spaces */
            while( nLen > 0 && name[nLen-1] == ' ' ) name[--nLen] = 0;

            hb_arraySetC( pEntry, 1, name );
            hb_arraySetL( pEntry, 2, isCurrent ? HB_TRUE : HB_FALSE );
            hb_arrayAdd( pArray, pEntry );
            hb_itemRelease( pEntry );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_CurrentBranch( [cWorkDir] ) -> cBranchName */
HB_FUNC( GIT_CURRENTBRANCH )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "rev-parse --abbrev-ref HEAD", szDir );
   if( pOut )
   {
      /* Remove trailing newline */
      int len = (int)strlen(pOut);
      while( len > 0 && (pOut[len-1] == '\n' || pOut[len-1] == '\r') ) pOut[--len] = 0;
      hb_retc( pOut );
      free( pOut );
   }
   else hb_retc( "" );
}

/* GIT_Blame( cFile, [cWorkDir] ) -> cBlameOutput */
HB_FUNC( GIT_BLAME )
{
   const char * szFile = hb_parc(1);
   const char * szDir  = HB_ISCHAR(2) ? hb_parc(2) : ".";
   if( !szFile ) { hb_retc(""); return; }
   char args[512];
   snprintf( args, sizeof(args), "blame --date=short \"%s\"", szFile );
   char * pOut = GitExec( args, szDir );
   if( pOut ) { hb_retc( pOut ); free( pOut ); }
   else hb_retc( "" );
}

/* GIT_IsRepo( [cWorkDir] ) -> lIsGitRepo */
HB_FUNC( GIT_ISREPO )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "rev-parse --is-inside-work-tree", szDir );
   if( pOut )
   {
      hb_retl( strstr(pOut, "true") != NULL );
      free( pOut );
   }
   else hb_retl( HB_FALSE );
}

/* GIT_RemoteList( [cWorkDir] ) -> { { cName, cUrl }, ... } */
HB_FUNC( GIT_REMOTELIST )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "remote -v", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   if( pOut )
   {
      char * p = pOut;
      while( *p )
      {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);

         /* Only take (fetch) lines to avoid duplicates */
         if( eol > p && strstr( p, "(fetch)" ) )
         {
            char line[512];
            int len = (int)(eol - p);
            if( len > 511 ) len = 511;
            strncpy( line, p, len ); line[len] = 0;

            char * tab = strchr( line, '\t' );
            if( tab )
            {
               *tab = 0;
               char * url = tab + 1;
               char * sp = strstr( url, " (fetch)" );
               if( sp ) *sp = 0;

               PHB_ITEM pEntry = hb_itemArrayNew( 2 );
               hb_arraySetC( pEntry, 1, line );
               hb_arraySetC( pEntry, 2, url );
               hb_arrayAdd( pArray, pEntry );
               hb_itemRelease( pEntry );
            }
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* ================================================================
 * GIT PANEL UI - Source Control window with WinAPI
 * ================================================================ */

#define GIT_PANEL_CLASS "HbGitPanel"
#define GIT_ID_REFRESH  4001
#define GIT_ID_COMMIT   4002
#define GIT_ID_PUSH     4003
#define GIT_ID_PULL     4004
#define GIT_ID_STASH    4005
#define GIT_ID_MSGEDIT  4010

static HWND s_hGitWnd = NULL;
static HWND s_gitBranchLbl = NULL;
static HWND s_gitChangesLV = NULL;
static HWND s_gitMsgEdit = NULL;

static LRESULT CALLBACK GitPanelProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         int y = 32;
         if( s_gitBranchLbl ) MoveWindow( s_gitBranchLbl, 4, 6, w - 8, 20, TRUE );
         if( s_gitChangesLV ) MoveWindow( s_gitChangesLV, 4, y, w - 8, h - y - 100, TRUE );
         int msgY = h - 96;
         if( s_gitMsgEdit ) MoveWindow( s_gitMsgEdit, 4, msgY, w - 8, 54, TRUE );
         /* Buttons at bottom */
         {
            HWND hChild = GetWindow( hWnd, GW_CHILD );
            int bx = 4, btnY = h - 34;
            while( hChild )
            {
               int id = GetDlgCtrlID( hChild );
               if( id >= GIT_ID_REFRESH && id <= GIT_ID_STASH )
               {
                  MoveWindow( hChild, bx, btnY, 60, 28, TRUE );
                  bx += 64;
               }
               hChild = GetWindow( hChild, GW_HWNDNEXT );
            }
         }
         return 0;
      }

      case WM_COMMAND:
      {
         int id = LOWORD(wParam);
         /* Commit, Push, Pull etc are handled from Harbour via menu actions */
         if( id == GIT_ID_REFRESH )
         {
            /* Trigger Harbour-level refresh */
            PHB_DYNS pSym = hb_dynsymFind( "GITREFRESHPANEL" );
            if( pSym ) { hb_vmPushDynSym(pSym); hb_vmPushNil(); hb_vmDo(0); }
         }
         else if( id == GIT_ID_COMMIT )
         {
            PHB_DYNS pSym = hb_dynsymFind( "GITCOMMIT" );
            if( pSym ) { hb_vmPushDynSym(pSym); hb_vmPushNil(); hb_vmDo(0); }
         }
         else if( id == GIT_ID_PUSH )
         {
            PHB_DYNS pSym = hb_dynsymFind( "GITPUSH" );
            if( pSym ) { hb_vmPushDynSym(pSym); hb_vmPushNil(); hb_vmDo(0); }
         }
         else if( id == GIT_ID_PULL )
         {
            PHB_DYNS pSym = hb_dynsymFind( "GITPULL" );
            if( pSym ) { hb_vmPushDynSym(pSym); hb_vmPushNil(); hb_vmDo(0); }
         }
         return 0;
      }

      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLOREDIT:
      case WM_CTLCOLORLISTBOX:
      {
         HDC hdc = (HDC)wParam;
         SetTextColor( hdc, RGB(212,212,212) );
         SetBkColor( hdc, RGB(30,30,30) );
         static HBRUSH hBrDark = NULL;
         if( !hBrDark ) hBrDark = CreateSolidBrush( RGB(30,30,30) );
         return (LRESULT)hBrDark;
      }

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;

      case WM_ERASEBKGND:
      {
         HDC hdc = (HDC)wParam;
         RECT rc; GetClientRect( hWnd, &rc );
         HBRUSH hBr = CreateSolidBrush( RGB(37,37,38) );
         FillRect( hdc, &rc, hBr );
         DeleteObject( hBr );
         return 1;
      }
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* W32_GitPanel() - create/show the Source Control panel */
HB_FUNC( W32_GITPANEL )
{
   if( s_hGitWnd ) {
      ShowWindow( s_hGitWnd, SW_SHOW );
      SetForegroundWindow( s_hGitWnd );
      return;
   }

   {  WNDCLASSEXA wc = { sizeof(WNDCLASSEXA) };
      wc.lpfnWndProc = GitPanelProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.lpszClassName = GIT_PANEL_CLASS;
      wc.hCursor = LoadCursor( NULL, IDC_ARROW );
      wc.hbrBackground = CreateSolidBrush( RGB(37,37,38) );
      RegisterClassExA( &wc );
   }

   s_hGitWnd = CreateWindowExA( WS_EX_TOOLWINDOW, GIT_PANEL_CLASS,
      "Source Control",
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      80, 100, 380, 520, NULL, NULL, GetModuleHandle(NULL), NULL );

   /* Dark title bar */
   {  typedef HRESULT (WINAPI *PFN)(HWND, DWORD, LPCVOID, DWORD);
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         PFN pFn = (PFN)GetProcAddress(hDwm, "DwmSetWindowAttribute");
         if( pFn ) { BOOL val = TRUE; pFn( s_hGitWnd, 20, &val, sizeof(val) ); }
         FreeLibrary( hDwm );
      }
   }

   HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

   /* Branch label */
   s_gitBranchLbl = CreateWindowExA( 0, "STATIC", "Branch: (none)",
      WS_CHILD | WS_VISIBLE | SS_LEFT,
      4, 6, 360, 20, s_hGitWnd, NULL, GetModuleHandle(NULL), NULL );
   SendMessageA( s_gitBranchLbl, WM_SETFONT, (WPARAM)hFont, TRUE );

   /* Changes ListView */
   s_gitChangesLV = CreateWindowExA( 0, WC_LISTVIEWA, "",
      WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL | LVS_NOSORTHEADER,
      4, 32, 364, 300, s_hGitWnd, NULL, GetModuleHandle(NULL), NULL );
   ListView_SetExtendedListViewStyle( s_gitChangesLV,
      LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES | LVS_EX_DOUBLEBUFFER );
   ListView_SetBkColor( s_gitChangesLV, RGB(30,30,30) );
   ListView_SetTextBkColor( s_gitChangesLV, RGB(30,30,30) );
   ListView_SetTextColor( s_gitChangesLV, RGB(212,212,212) );

   { LVCOLUMNA col = { 0 };
     col.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_FMT;
     col.pszText = (LPSTR)"St"; col.cx = 30; col.fmt = LVCFMT_LEFT;
     ListView_InsertColumn( s_gitChangesLV, 0, &col );
     col.pszText = (LPSTR)"File"; col.cx = 320;
     ListView_InsertColumn( s_gitChangesLV, 1, &col );
   }

   /* Commit message edit */
   s_gitMsgEdit = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", "",
      WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL,
      4, 340, 364, 54, s_hGitWnd, (HMENU)(LONG_PTR)GIT_ID_MSGEDIT,
      GetModuleHandle(NULL), NULL );
   SendMessageA( s_gitMsgEdit, WM_SETFONT, (WPARAM)hFont, TRUE );
   SendMessageA( s_gitMsgEdit, EM_SETCUEBANNER, TRUE, (LPARAM)L"Commit message..." );

   /* Action buttons */
   { const char * labels[] = { "Refresh", "Commit", "Push", "Pull", "Stash" };
     int ids[] = { GIT_ID_REFRESH, GIT_ID_COMMIT, GIT_ID_PUSH, GIT_ID_PULL, GIT_ID_STASH };
     int bx = 4;
     for( int i = 0; i < 5; i++ )
     {
        HWND hBtn = CreateWindowExA( 0, "BUTTON", labels[i],
           WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
           bx, 400, 60, 28, s_hGitWnd, (HMENU)(LONG_PTR)ids[i],
           GetModuleHandle(NULL), NULL );
        SendMessageA( hBtn, WM_SETFONT, (WPARAM)hFont, TRUE );
        bx += 64;
     }
   }

   /* Force layout */
   { RECT rc; GetClientRect( s_hGitWnd, &rc );
     SendMessage( s_hGitWnd, WM_SIZE, 0, MAKELPARAM(rc.right, rc.bottom) );
   }
}

/* W32_GitSetBranch( cBranch ) - update branch label */
HB_FUNC( W32_GITSETBRANCH )
{
   if( s_gitBranchLbl && HB_ISCHAR(1) )
   {
      char buf[256];
      snprintf( buf, sizeof(buf), "Branch: %s", hb_parc(1) );
      SetWindowTextA( s_gitBranchLbl, buf );
   }
}

/* W32_GitSetChanges( aChanges ) - populate changes ListView */
HB_FUNC( W32_GITSETCHANGES )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_gitChangesLV || !pArray ) return;

   ListView_DeleteAllItems( s_gitChangesLV );

   int n = (int) hb_arrayLen( pArray );
   for( int i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 2 ) continue;

      LVITEMA item = { 0 };
      item.mask = LVIF_TEXT;
      item.iItem = i - 1;
      item.pszText = (LPSTR)hb_arrayGetCPtr( pEntry, 1 );
      ListView_InsertItem( s_gitChangesLV, &item );
      ListView_SetItemText( s_gitChangesLV, i - 1, 1,
         (LPSTR)hb_arrayGetCPtr( pEntry, 2 ) );
   }
}

/* W32_GitGetMessage() -> cMessage - get text from commit message edit */
HB_FUNC( W32_GITGETMESSAGE )
{
   if( s_gitMsgEdit )
   {
      char buf[2048] = "";
      GetWindowTextA( s_gitMsgEdit, buf, sizeof(buf) );
      hb_retc( buf );
   }
   else hb_retc( "" );
}

/* W32_GitClearMessage() - clear the commit message edit */
HB_FUNC( W32_GITCLEARMESSAGE )
{
   if( s_gitMsgEdit )
      SetWindowTextA( s_gitMsgEdit, "" );
}

/* GIT_StashList( [cWorkDir] ) -> { cStash1, cStash2, ... } */
HB_FUNC( GIT_STASHLIST )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "stash list", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   if( pOut )
   {
      char * p = pOut;
      while( *p )
      {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);
         if( eol > p )
         {
            char line[256];
            int len = (int)(eol - p);
            if( len > 255 ) len = 255;
            strncpy( line, p, len ); line[len] = 0;

            PHB_ITEM pStr = hb_itemPutC( NULL, line );
            hb_arrayAdd( pArray, pStr );
            hb_itemRelease( pStr );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}
