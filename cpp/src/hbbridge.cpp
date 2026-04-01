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
      p->SetEvent( szEvent, pBlock );
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
