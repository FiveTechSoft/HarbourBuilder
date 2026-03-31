// minimal.prg - Minimal Win32 window test. No framework.

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local hFont, hWnd

   hFont := W32_CreateFont( "Segoe UI", -12 )
   hWnd  := W32_CreateMainWindow( "Test", 300, 200, hFont, 0 )

   if hWnd == 0
      ? "ERROR: CreateMainWindow failed"
      Inkey(0)
      return nil
   endif

   W32_CreateButton( hWnd, "Click Me", 100, 80, 100, 30, hFont, .f. )

   W32_CenterWindow( hWnd )
   W32_ShowWindow( hWnd )
   W32_MessageLoop()

   W32_DeleteObject( hFont )

return nil

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>

static LRESULT CALLBACK WndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_ERASEBKGND:
      {
         RECT rc;
         GetClientRect( hWnd, &rc );
         FillRect( (HDC) wParam, &rc, GetSysColorBrush( COLOR_BTNFACE ) );
         return 1;
      }
      case WM_CTLCOLORSTATIC:
      case WM_CTLCOLORBTN:
         SetBkMode( (HDC) wParam, TRANSPARENT );
         return (LRESULT) GetSysColorBrush( COLOR_BTNFACE );
      case WM_COMMAND:
         if( LOWORD(wParam) == 100 )
            MessageBoxA( hWnd, "Button clicked!", "Test", MB_OK );
         return 0;
      case WM_CLOSE:
         DestroyWindow( hWnd );
         return 0;
      case WM_DESTROY:
         PostQuitMessage( 0 );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

HB_FUNC( W32_CREATEMAINWINDOW )
{
   WNDCLASSA wc = {0};
   HWND hWnd;
   HFONT hFont = (HFONT)(HB_PTRUINT) hb_parnint( 4 );

   wc.lpfnWndProc   = WndProc;
   wc.hInstance      = GetModuleHandle(NULL);
   wc.hCursor        = LoadCursor(NULL, IDC_ARROW);
   wc.hbrBackground  = GetSysColorBrush( COLOR_BTNFACE );
   wc.lpszClassName  = "MinTest";
   RegisterClassA( &wc );

   hWnd = CreateWindowExA( 0, "MinTest", hb_parc(1),
      WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT, CW_USEDEFAULT, hb_parni(2), hb_parni(3),
      NULL, NULL, GetModuleHandle(NULL), NULL );

   if( hWnd && hFont )
      SendMessage( hWnd, WM_SETFONT, (WPARAM) hFont, TRUE );

   hb_retnint( (HB_PTRUINT) hWnd );
}

HB_FUNC( W32_CREATEFONT )
{
   LOGFONTA lf = {0};
   lf.lfHeight = hb_parni(2);
   lf.lfCharSet = DEFAULT_CHARSET;
   lstrcpynA( lf.lfFaceName, hb_parc(1), LF_FACESIZE );
   hb_retnint( (HB_PTRUINT) CreateFontIndirectA( &lf ) );
}

HB_FUNC( W32_CREATEBUTTON )
{
   HWND hBtn = CreateWindowExA( 0, "BUTTON", hb_parc(2),
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
      hb_parni(3), hb_parni(4), hb_parni(5), hb_parni(6),
      (HWND)(HB_PTRUINT) hb_parnint(1), (HMENU) 100,
      GetModuleHandle(NULL), NULL );
   if( hBtn )
      SendMessage( hBtn, WM_SETFONT, (WPARAM)(HB_PTRUINT) hb_parnint(7), TRUE );
   hb_retnint( (HB_PTRUINT) hBtn );
}

HB_FUNC( W32_SHOWWINDOW )
{
   ShowWindow( (HWND)(HB_PTRUINT) hb_parnint(1), SW_SHOW );
   UpdateWindow( (HWND)(HB_PTRUINT) hb_parnint(1) );
}

HB_FUNC( W32_CENTERWINDOW )
{
   HWND hWnd = (HWND)(HB_PTRUINT) hb_parnint(1);
   RECT rc;
   GetWindowRect( hWnd, &rc );
   SetWindowPos( hWnd, NULL,
      (GetSystemMetrics(SM_CXSCREEN)-(rc.right-rc.left))/2,
      (GetSystemMetrics(SM_CYSCREEN)-(rc.bottom-rc.top))/2,
      0, 0, SWP_NOSIZE | SWP_NOZORDER );
}

HB_FUNC( W32_MESSAGELOOP )
{
   MSG msg;
   while( GetMessage( &msg, NULL, 0, 0 ) > 0 )
   {
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }
}

HB_FUNC( W32_DELETEOBJECT )
{
   DeleteObject( (HGDIOBJ)(HB_PTRUINT) hb_parnint(1) );
}

#pragma ENDDUMP
