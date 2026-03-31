// backend.prg - Win32 backend using raw Win32 API (no FiveWin)
// All window creation via CreateWindowEx in C.

#include "hbclass.ch"
#include "hbide.ch"

CLASS Win32Backend

   DATA hWnd       INIT 0     // Main window handle
   DATA hFont      INIT 0     // Shared font handle
   DATA hBrush     INIT 0     // Background brush
   DATA oForm                  // Reference to UIForm
   DATA lRunning   INIT .f.

   METHOD New()
   METHOD Run( oForm )
   METHOD CreateControls( oForm )
   METHOD Shutdown()

ENDCLASS

METHOD New() CLASS Win32Backend
return Self

METHOD Run( oForm ) CLASS Win32Backend

   local nFontSize, aGroupBoxes := {}, n, oChild

   ::oForm := oForm
   oForm:oBackend := Self

   // Create font
   nFontSize := oForm:GetProp( "FontSize" )
   ::hFont := W32_CreateFont( oForm:GetProp( "FontName" ), -nFontSize )

   // Create main window
   ::hWnd := W32_CreateMainWindow( oForm:Text, oForm:Width, oForm:Height, ;
      ::hFont, 0 )

   oForm:hNative := ::hWnd

   // Create all child controls
   ::CreateControls( oForm )

   // Center
   if oForm:GetProp( "Center" )
      W32_CenterWindow( ::hWnd )
   endif

   // Show and message loop
   W32_ShowWindow( ::hWnd )
   ::lRunning := .t.
   W32_MessageLoop()
   ::lRunning := .f.

   // Cleanup
   ::Shutdown()

return nil

METHOD CreateControls( oForm ) CLASS Win32Backend

   local n, oChild, cClass, nStyle, hCtrl

   for n := 1 to Len( oForm:aChildren )
      oChild := oForm:aChildren[ n ]
      cClass := oChild:cClass

      do case
         case cClass == CTRL_GROUPBOX
            W32_CreateGroupBox( ::hWnd, oChild:Text, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont )

         case cClass == CTRL_LABEL
            hCtrl := W32_CreateStatic( ::hWnd, oChild:Text, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont )
            oChild:hNative := hCtrl

         case cClass == CTRL_EDIT
            hCtrl := W32_CreateEdit( ::hWnd, oChild:Text, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont )
            oChild:hNative := hCtrl

         case cClass == CTRL_BUTTON
            hCtrl := W32_CreateButton( ::hWnd, oChild:Text, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont, ;
               oChild:GetProp( "Default" ) )
            oChild:hNative := hCtrl

         case cClass == CTRL_CHECKBOX
            hCtrl := W32_CreateCheckBox( ::hWnd, oChild:Text, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont, ;
               oChild:GetProp( "Checked" ) )
            oChild:hNative := hCtrl

         case cClass == CTRL_COMBOBOX
            hCtrl := W32_CreateComboBox( ::hWnd, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont, ;
               oChild:GetProp( "Items" ), oChild:GetProp( "ItemIndex" ) )
            oChild:hNative := hCtrl

         case cClass == CTRL_LISTBOX
            hCtrl := W32_CreateListBox( ::hWnd, ;
               oChild:Left, oChild:Top, oChild:Width, oChild:Height, ::hFont, ;
               oChild:GetProp( "Items" ) )
            oChild:hNative := hCtrl

      endcase
   next

return nil

METHOD Shutdown() CLASS Win32Backend

   if ::hFont != 0;  W32_DeleteObject( ::hFont );  ::hFont := 0;  endif
   if ::hBrush != 0; W32_DeleteObject( ::hBrush ); ::hBrush := 0; endif

return nil

//----------------------------------------------------------------------------//
// Win32 API layer in C
//----------------------------------------------------------------------------//

#pragma BEGINDUMP

#include <hbapi.h>
#include <hbapiitm.h>
#include <windows.h>
#include <commctrl.h>

static HBRUSH s_hBrush = NULL;

// WndProc for main window
static LRESULT CALLBACK MainWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_COMMAND:
      {
         WORD wId = LOWORD( wParam );
         if( wId == 2 || wId == 1 )
         {
            DestroyWindow( hWnd );
            return 0;
         }
         break;
      }

      case WM_ERASEBKGND:
      {
         RECT rc;
         GetClientRect( hWnd, &rc );
         FillRect( ( HDC ) wParam, &rc, s_hBrush ? s_hBrush : GetSysColorBrush( COLOR_BTNFACE ) );
         return 1;
      }

      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLORBTN:
      {
         HBRUSH hBr = s_hBrush ? s_hBrush : GetSysColorBrush( COLOR_BTNFACE );
         SetBkMode( ( HDC ) wParam, TRANSPARENT );
         return ( LRESULT ) hBr;
      }

      case WM_CLOSE:
         DestroyWindow( hWnd );
         return 0;

      case WM_DESTROY:
         PostQuitMessage( 0 );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

// W32_CreateMainWindow( cTitle, nWidth, nHeight, hFont, hBrush )
HB_FUNC( W32_CREATEMAINWINDOW )
{
   const char * cTitle = hb_parc( 1 );
   int nW = hb_parni( 2 );
   int nH = hb_parni( 3 );
   HFONT hFont = ( HFONT ) ( HB_PTRUINT ) hb_parnint( 4 );
   WNDCLASSA wc = {0};
   HWND hWnd;
   static int nFormCount = 0;
   char szClass[32];

   s_hBrush = CreateSolidBrush( GetSysColor( COLOR_BTNFACE ) );

   nFormCount++;
   sprintf( szClass, "HbIdeForm%d", nFormCount );

   wc.lpfnWndProc   = MainWndProc;
   wc.hInstance      = GetModuleHandle( NULL );
   wc.hCursor        = LoadCursor( NULL, IDC_ARROW );
   wc.hbrBackground  = s_hBrush;
   wc.lpszClassName  = szClass;
   wc.hIcon          = LoadIcon( NULL, IDI_APPLICATION );
   RegisterClassA( &wc );

   hWnd = CreateWindowExA( 0, szClass, cTitle,
      WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_MODALFRAME,
      0, 0, nW, nH,
      NULL, NULL, GetModuleHandle( NULL ), NULL );

   if( hWnd && hFont )
      SendMessage( hWnd, WM_SETFONT, ( WPARAM ) hFont, TRUE );

   hb_retnint( ( HB_PTRUINT ) hWnd );
}

// W32_CreateFont( cFace, nHeight )
HB_FUNC( W32_CREATEFONT )
{
   LOGFONTA lf = {0};
   lf.lfHeight = hb_parni( 2 );
   lf.lfCharSet = DEFAULT_CHARSET;
   lstrcpynA( lf.lfFaceName, hb_parc( 1 ), LF_FACESIZE );
   hb_retnint( ( HB_PTRUINT ) CreateFontIndirectA( &lf ) );
}

// Helper: create control and set font
static HWND CreateCtrl( HWND hParent, const char * cls, const char * text,
   int x, int y, int w, int h, DWORD style, DWORD exStyle, HFONT hFont, int nId )
{
   HWND hCtrl = CreateWindowExA( exStyle, cls, text, style,
      x, y, w, h, hParent, ( HMENU ) ( HB_PTRUINT ) nId,
      GetModuleHandle( NULL ), NULL );
   if( hCtrl && hFont )
      SendMessage( hCtrl, WM_SETFONT, ( WPARAM ) hFont, TRUE );
   return hCtrl;
}

// W32_CreateGroupBox( hParent, cText, x, y, w, h, hFont )
HB_FUNC( W32_CREATEGROUPBOX )
{
   hb_retnint( ( HB_PTRUINT ) CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "BUTTON", hb_parc( 2 ),
      hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ), hb_parni( 6 ),
      WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
      WS_EX_TRANSPARENT,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 7 ), 0 ) );
}

// W32_CreateStatic( hParent, cText, x, y, w, h, hFont )
HB_FUNC( W32_CREATESTATIC )
{
   hb_retnint( ( HB_PTRUINT ) CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "STATIC", hb_parc( 2 ),
      hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ), hb_parni( 6 ),
      WS_CHILD | WS_VISIBLE,
      0,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 7 ), 0 ) );
}

// W32_CreateEdit( hParent, cText, x, y, w, h, hFont )
HB_FUNC( W32_CREATEEDIT )
{
   hb_retnint( ( HB_PTRUINT ) CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "EDIT", hb_parc( 2 ),
      hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ), hb_parni( 6 ),
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL,
      0,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 7 ), 0 ) );
}

// W32_CreateButton( hParent, cText, x, y, w, h, hFont, lDefault )
HB_FUNC( W32_CREATEBUTTON )
{
   BOOL lDef = hb_parl( 8 );
   int nId = lDef ? 1 : 0;
   DWORD style = WS_CHILD | WS_VISIBLE | WS_TABSTOP;
   if( lDef ) style |= BS_DEFPUSHBUTTON;

   // Detect Cancel button by text containing "Cancel"
   if( strstr( hb_parc( 2 ), "ancel" ) != NULL )
      nId = 2;

   hb_retnint( ( HB_PTRUINT ) CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "BUTTON", hb_parc( 2 ),
      hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ), hb_parni( 6 ),
      style, 0,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 7 ), nId ) );
}

// W32_CreateCheckBox( hParent, cText, x, y, w, h, hFont, lChecked )
HB_FUNC( W32_CREATECHECKBOX )
{
   HWND hCtrl;
   hCtrl = CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "BUTTON", hb_parc( 2 ),
      hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ), hb_parni( 6 ),
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX,
      0,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 7 ), 0 );
   if( hCtrl && hb_parl( 8 ) )
      SendMessage( hCtrl, BM_SETCHECK, BST_CHECKED, 0 );
   hb_retnint( ( HB_PTRUINT ) hCtrl );
}

// W32_CreateComboBox( hParent, x, y, w, h, hFont, aItems, nSel )
HB_FUNC( W32_CREATECOMBOBOX )
{
   HWND hCtrl;
   PHB_ITEM pItems = hb_param( 7, HB_IT_ARRAY );
   HB_SIZE i, nLen;
   int nSel = hb_parnidef( 8, 1 ) - 1;

   hCtrl = CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "COMBOBOX", "",
      hb_parni( 2 ), hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ),
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_VSCROLL | CBS_DROPDOWNLIST,
      0,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 6 ), 0 );

   if( hCtrl && pItems )
   {
      nLen = hb_arrayLen( pItems );
      for( i = 1; i <= nLen; i++ )
         SendMessageA( hCtrl, CB_ADDSTRING, 0, ( LPARAM ) hb_arrayGetCPtr( pItems, i ) );
      if( nSel >= 0 )
         SendMessage( hCtrl, CB_SETCURSEL, nSel, 0 );
   }

   hb_retnint( ( HB_PTRUINT ) hCtrl );
}

// W32_CreateListBox( hParent, x, y, w, h, hFont, aItems )
HB_FUNC( W32_CREATELISTBOX )
{
   HWND hCtrl;
   PHB_ITEM pItems = hb_param( 7, HB_IT_ARRAY );
   HB_SIZE i, nLen;

   hCtrl = CreateCtrl(
      ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ),
      "LISTBOX", "",
      hb_parni( 2 ), hb_parni( 3 ), hb_parni( 4 ), hb_parni( 5 ),
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_VSCROLL | WS_BORDER | LBS_NOTIFY,
      0,
      ( HFONT ) ( HB_PTRUINT ) hb_parnint( 6 ), 0 );

   if( hCtrl && pItems )
   {
      nLen = hb_arrayLen( pItems );
      for( i = 1; i <= nLen; i++ )
         SendMessageA( hCtrl, LB_ADDSTRING, 0, ( LPARAM ) hb_arrayGetCPtr( pItems, i ) );
   }

   hb_retnint( ( HB_PTRUINT ) hCtrl );
}

// W32_ShowWindow( hWnd )
HB_FUNC( W32_SHOWWINDOW )
{
   ShowWindow( ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ), SW_SHOW );
   UpdateWindow( ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 ) );
}

// W32_CenterWindow( hWnd )
HB_FUNC( W32_CENTERWINDOW )
{
   HWND hWnd = ( HWND ) ( HB_PTRUINT ) hb_parnint( 1 );
   RECT rc;
   int cx, cy;
   GetWindowRect( hWnd, &rc );
   cx = ( GetSystemMetrics( SM_CXSCREEN ) - ( rc.right - rc.left ) ) / 2;
   cy = ( GetSystemMetrics( SM_CYSCREEN ) - ( rc.bottom - rc.top ) ) / 2;
   SetWindowPos( hWnd, NULL, cx, cy, 0, 0, SWP_NOSIZE | SWP_NOZORDER );
}

// W32_MessageLoop()
HB_FUNC( W32_MESSAGELOOP )
{
   MSG msg;
   while( GetMessage( &msg, NULL, 0, 0 ) > 0 )
   {
      if( !IsDialogMessage( GetActiveWindow(), &msg ) )
      {
         TranslateMessage( &msg );
         DispatchMessage( &msg );
      }
   }
}

// W32_GetSysColor( nIndex )
HB_FUNC( W32_GETSYSCOLOR )
{
   hb_retnint( GetSysColor( hb_parni( 1 ) ) );
}

// W32_CreateSolidBrush( nColor )
HB_FUNC( W32_CREATESOLIDBRUSH )
{
   hb_retnint( ( HB_PTRUINT ) CreateSolidBrush( ( COLORREF ) hb_parnint( 1 ) ) );
}

// W32_DeleteObject( hObj )
HB_FUNC( W32_DELETEOBJECT )
{
   DeleteObject( ( HGDIOBJ ) ( HB_PTRUINT ) hb_parnint( 1 ) );
}

#pragma ENDDUMP
