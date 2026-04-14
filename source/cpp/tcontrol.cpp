/*
 * tcontrol.cpp - TObject, TControl base implementation
 * All window creation, message routing, and property access in C++.
 */

#include "hbide.h"
#include <string.h>
#include <stdio.h>

/* ======================================================================
 * TObject
 * ====================================================================== */

TObject::TObject()
{
   FClassName[0] = 0;
   FName[0] = 0;
   FParent = NULL;
}

TObject::~TObject() {}

const PROPDESC * TObject::GetPropDescs( int * pnCount )
{
   *pnCount = 0;
   return NULL;
}

/* ======================================================================
 * TControl
 * ====================================================================== */

static PROPDESC aControlProps[] = {
   { "cName",    PT_STRING,  0, "Appearance" },
   { "nLeft",    PT_NUMBER,  0, "Position" },
   { "nTop",     PT_NUMBER,  0, "Position" },
   { "nWidth",   PT_NUMBER,  0, "Position" },
   { "nHeight",  PT_NUMBER,  0, "Position" },
   { "cText",    PT_STRING,  0, "Appearance" },
   { "lVisible", PT_LOGICAL, 0, "Behavior" },
   { "lEnabled", PT_LOGICAL, 0, "Behavior" },
};

TControl::TControl()
{
   lstrcpy( FClassName, "TControl" );
   FHandle = NULL;
   FLeft = 0;
   FTop = 0;
   FWidth = 80;
   FHeight = 24;
   FText[0] = 0;
   FVisible = TRUE;
   FEnabled = TRUE;
   FTabStop = TRUE;
   FControlType = 0;
   FFont = NULL;
   FClrPane = CLR_INVALID;  /* no color = inherit from parent */
   FClrText = CLR_INVALID;  /* no text color = system default */
   FInterval = 1000;
   FBkBrush = NULL;
   FFileName[0] = '\0';
   lstrcpyA( FRDD, "DBFCDX" );
   FActive = FALSE;
   FTransparent = FALSE;
   FPageOwner = NULL;
   FPageIndex = 0;   /* TLabel overrides to TRUE in its own ctor */
   FCtrlParent = NULL;
   FChildCount = 0;
   memset( FChildren, 0, sizeof(FChildren) );
   FOnClick = NULL;
   FOnChange = NULL;
   FOnInit = NULL;
   FOnClose = NULL;
   FOnTimer = NULL;
   FTimerID = 0;
}

TControl::~TControl()
{
   if( FBkBrush ) DeleteObject( FBkBrush );
   ReleaseEvents();
   DestroyHandle();
}

void TControl::CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass )
{
   *pdwStyle = WS_CHILD | WS_VISIBLE;
   *pdwExStyle = 0;
   *pszClass = "STATIC";

   if( FTabStop )
      *pdwStyle |= WS_TABSTOP;
}

void TControl::CreateHandle( HWND hParent )
{
   DWORD dwStyle, dwExStyle;
   const char * szClass;

   CreateParams( &dwStyle, &dwExStyle, &szClass );

   FHandle = CreateWindowExA( dwExStyle, szClass, FText, dwStyle,
      FLeft, FTop, FWidth, FHeight,
      hParent, NULL, GetModuleHandle(NULL), NULL );

   if( FHandle )
   {
      /* Store pointer to C++ object in window data */
      SetWindowLongPtr( FHandle, GWLP_USERDATA, (LONG_PTR) this );

      /* Apply font */
      if( FFont )
         SendMessage( FHandle, WM_SETFONT, (WPARAM) FFont, TRUE );
      else if( hParent )
         SendMessage( FHandle, WM_SETFONT,
            SendMessage( hParent, WM_GETFONT, 0, 0 ), TRUE );

      /* Apply stored background color if set */
      if( FClrPane != CLR_INVALID )
      {
         if( !FBkBrush ) FBkBrush = CreateSolidBrush( FClrPane );
      }

      /* Replay any per-class state that was set BEFORE the HWND existed.
         For TFolder/TPageControl: SetTabs called from SetPrompts() during
         CreateForm just stored FTabs (FHandle was NULL at that point);
         now that the window exists we can push the tab items into it. */
      if( FControlType == CT_TABCONTROL2 )
      {
         TTabControl2 * pPC = (TTabControl2 *) this;
         if( pPC->FTabs[0] )
         {
            char saved[1024];
            lstrcpynA( saved, pPC->FTabs, sizeof(saved) );
            pPC->SetTabs( saved );
         }
      }
   }
}

void TControl::DestroyHandle()
{
   if( FHandle )
   {
      DestroyWindow( FHandle );
      FHandle = NULL;
   }
}

extern void HbApplyPendingPageOwner( TControl * pCtrl );

void TControl::AddChild( TControl * pChild )
{
   if( FChildCount < MAX_CHILDREN )
   {
      FChildren[FChildCount++] = pChild;
      pChild->FCtrlParent = this;
      pChild->FParent = this;
      /* If a TFolderPage:hCpp call set a pending owner just before
         this AddChild, claim ownership for that page now. */
      HbApplyPendingPageOwner( pChild );
   }
}

void TControl::SetText( const char * szText )
{
   lstrcpynA( FText, szText, sizeof(FText) );
   if( FHandle )
   {
      SetWindowTextA( FHandle, FText );
      /* Transparent statics (TLabel) draw with SetBkMode(TRANSPARENT)
         so without forcing the PARENT to erase its background first the
         old text bleeds through the new one. The cleanest cure: hide
         briefly, force the parent to redraw the underlying region with
         erase + paint synchronously (RedrawWindow), then show again so
         the static repaints on top of the freshly drawn parent bg. */
      if( FTransparent && FCtrlParent && FCtrlParent->FHandle )
      {
         RECT rc;
         rc.left = FLeft;
         rc.top  = FTop;
         rc.right  = FLeft + FWidth;
         rc.bottom = FTop  + FHeight;
         ShowWindow( FHandle, SW_HIDE );
         RedrawWindow( FCtrlParent->FHandle, &rc, NULL,
            RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW );
         ShowWindow( FHandle, SW_SHOW );
      }
   }
}

void TControl::SetBounds( int nLeft, int nTop, int nWidth, int nHeight )
{
   FLeft = nLeft;
   FTop = nTop;
   FWidth = nWidth;
   FHeight = nHeight;
   if( FHandle )
      SetWindowPos( FHandle, NULL, FLeft, FTop, FWidth, FHeight,
         SWP_NOZORDER | SWP_NOACTIVATE );
}

void TControl::SetFont( HFONT hFont )
{
   FFont = hFont;
   if( FHandle )
      SendMessage( FHandle, WM_SETFONT, (WPARAM) FFont, TRUE );
}

void TControl::Show()
{
   FVisible = TRUE;
   if( FHandle )
      ShowWindow( FHandle, SW_SHOW );
}

void TControl::Hide()
{
   FVisible = FALSE;
   if( FHandle )
      ShowWindow( FHandle, SW_HIDE );
}

LRESULT TControl::HandleMessage( UINT msg, WPARAM wParam, LPARAM lParam )
{
   return DefWindowProc( FHandle, msg, wParam, lParam );
}

void TControl::DoOnClick()
{
   FireEvent( FOnClick );
}

void TControl::DoOnChange()
{
   FireEvent( FOnChange );
}

void TControl::SetEvent( const char * szEvent, PHB_ITEM pBlock )
{
   PHB_ITEM * ppTarget = NULL;

   if( lstrcmpi( szEvent, "OnClick" ) == 0 )
      ppTarget = &FOnClick;
   else if( lstrcmpi( szEvent, "OnChange" ) == 0 )
      ppTarget = &FOnChange;
   else if( lstrcmpi( szEvent, "OnInit" ) == 0 )
      ppTarget = &FOnInit;
   else if( lstrcmpi( szEvent, "OnClose" ) == 0 )
      ppTarget = &FOnClose;
   else if( lstrcmpi( szEvent, "OnTimer" ) == 0 )
      ppTarget = &FOnTimer;

   if( ppTarget )
   {
      /* Release old block */
      if( *ppTarget )
         hb_itemRelease( *ppTarget );

      /* Copy new block (increases reference count) */
      *ppTarget = hb_itemNew( pBlock );
   }
}

void TControl::FireEvent( PHB_ITEM pBlock )
{
   if( pBlock && HB_IS_BLOCK( pBlock ) )
   {
      if( hb_vmRequestReenter() )
      {
         hb_vmPushEvalSym();
         hb_vmPush( pBlock );
         hb_vmSend( 0 );
         hb_vmRequestRestore();
      }
   }
}

void TControl::ReleaseEvents()
{
   if( FOnClick )  { hb_itemRelease( FOnClick );  FOnClick = NULL; }
   if( FOnChange ) { hb_itemRelease( FOnChange ); FOnChange = NULL; }
   if( FOnInit )   { hb_itemRelease( FOnInit );   FOnInit = NULL; }
   if( FOnClose )  { hb_itemRelease( FOnClose );  FOnClose = NULL; }
   if( FOnTimer )  { hb_itemRelease( FOnTimer );  FOnTimer = NULL; }
   if( FTimerID )  { KillTimer( NULL, FTimerID );  FTimerID = 0; }
}

const PROPDESC * TControl::GetPropDescs( int * pnCount )
{
   *pnCount = sizeof(aControlProps) / sizeof(aControlProps[0]);
   return aControlProps;
}

/* Static WndProc - routes messages to C++ objects */
LRESULT CALLBACK TControl::WndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   TForm * pForm = (TForm *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   if( pForm )
      return pForm->HandleMessage( msg, wParam, lParam );

   return DefWindowProc( hWnd, msg, wParam, lParam );
}
