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

#include "hbide.h"
#include <string.h>

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
      if( p->FHandle ) SetWindowPos( p->FHandle, NULL, p->FLeft, p->FTop, p->FWidth, p->FHeight, SWP_NOZORDER ); }
   else if( lstrcmpi( szProp, "nTop" ) == 0 )
   {  p->FTop = hb_parni(3);
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

/* ======================================================================
 * Menu
 * ====================================================================== */

/* UI_MenuBarCreate( hForm ) */
HB_FUNC( UI_MENUBARCREATE )
{
   TForm * p = GetForm(1);
   if( p ) p->CreateMenuBar();
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
