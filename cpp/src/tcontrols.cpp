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
   FHeight = 15;
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
   }
   return NULL;
}
