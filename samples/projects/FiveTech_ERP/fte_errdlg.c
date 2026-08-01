/*
 * fte_errdlg.c — W32_ErrorDialog for FiveTech_ERP
 * Same idea as FWH ErrorDialog / HbBuilder BuildErrDialog:
 * multi-line read-only edit (selectable) + "Copy to Clipboard" + "Quit"
 */
#include <windows.h>
#include <hbapi.h>
#include <string.h>
#include <stdlib.h>

static HWND s_fteEdit = NULL;
static HWND s_fteCopy = NULL;
static BOOL s_fteModal = FALSE;

static LRESULT CALLBACK FteErrProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_COMMAND:
         if( LOWORD( wParam ) == 1001 && s_fteEdit )
         {
            /* Select all + copy (Ctrl+C also works when edit has focus) */
            SendMessageA( s_fteEdit, EM_SETSEL, 0, (LPARAM)-1 );
            SendMessageA( s_fteEdit, WM_COPY, 0, 0 );
            if( s_fteCopy )
               SetWindowTextA( s_fteCopy, "Copied!" );
            return 0;
         }
         if( LOWORD( wParam ) == 1002 || LOWORD( wParam ) == IDCANCEL )
         {
            s_fteModal = FALSE;
            DestroyWindow( hWnd );
            return 0;
         }
         break;
      case WM_SIZE:
      {
         int w = LOWORD( lParam ), h = HIWORD( lParam );
         if( s_fteEdit )
            MoveWindow( s_fteEdit, 8, 8, w - 16, h - 56, TRUE );
         if( s_fteCopy )
            MoveWindow( s_fteCopy, w / 2 - 140, h - 40, 130, 30, TRUE );
         {
            HWND hQuit = GetDlgItem( hWnd, 1002 );
            if( hQuit )
               MoveWindow( hQuit, w / 2 + 10, h - 40, 130, 30, TRUE );
         }
         return 0;
      }
      case WM_CLOSE:
         s_fteModal = FALSE;
         DestroyWindow( hWnd );
         return 0;
      case WM_DESTROY:
         s_fteModal = FALSE;
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* AppShowError (classes.prg) calls W32_ErrorDialog( cMsg ) */
HB_FUNC( W32_ERRORDIALOG )
{
   const char * cLog = HB_ISCHAR( 1 ) ? hb_parc( 1 ) : "";
   static BOOL bReg = FALSE;
   int sw, sh, dlgW, dlgH;
   HWND hDlg, hQuit;
   HFONT hMono, hGui;
   char * cLogCRLF = NULL;
   int len, j, k;
   MSG msg;

   if( ! bReg )
   {
      WNDCLASSEXA wc;
      memset( &wc, 0, sizeof( wc ) );
      wc.cbSize        = sizeof( WNDCLASSEXA );
      wc.lpfnWndProc   = FteErrProc;
      wc.hInstance     = GetModuleHandle( NULL );
      wc.lpszClassName = "FteRuntimeErr";
      wc.hCursor       = LoadCursor( NULL, IDC_ARROW );
      wc.hbrBackground = (HBRUSH)( COLOR_WINDOW + 1 );
      RegisterClassExA( &wc );
      bReg = TRUE;
   }

   sw = GetSystemMetrics( SM_CXSCREEN );
   sh = GetSystemMetrics( SM_CYSCREEN );
   dlgW = 720;
   dlgH = 480;

   hDlg = CreateWindowExA( WS_EX_TOPMOST | WS_EX_DLGMODALFRAME,
      "FteRuntimeErr",
      "FiveTech_ERP — Runtime Error",
      WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN,
      ( sw - dlgW ) / 2, ( sh - dlgH ) / 2, dlgW, dlgH,
      NULL, NULL, GetModuleHandle( NULL ), NULL );

   hMono = CreateFontA( -15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, "Consolas" );
   hGui = (HFONT) GetStockObject( DEFAULT_GUI_FONT );

   /* LF → CRLF so EDIT control shows lines correctly */
   len = (int) strlen( cLog );
   cLogCRLF = (char *) malloc( (size_t) len * 2 + 1 );
   j = 0;
   for( k = 0; k < len; k++ )
   {
      if( cLog[k] == '\n' && ( k == 0 || cLog[k - 1] != '\r' ) )
         cLogCRLF[j++] = '\r';
      cLogCRLF[j++] = cLog[k];
   }
   cLogCRLF[j] = 0;

   /* Read-only multi-line edit: select + Ctrl+C works */
   s_fteEdit = CreateWindowExA( WS_EX_CLIENTEDGE, "EDIT", cLogCRLF,
      WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL |
      WS_VSCROLL | WS_HSCROLL | ES_AUTOHSCROLL,
      8, 8, dlgW - 32, dlgH - 90, hDlg, NULL, GetModuleHandle( NULL ), NULL );
   SendMessageA( s_fteEdit, WM_SETFONT, (WPARAM) hMono, TRUE );

   s_fteCopy = CreateWindowExA( 0, "BUTTON", "Copy to Clipboard",
      WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
      dlgW / 2 - 140, dlgH - 74, 130, 30, hDlg, (HMENU) 1001,
      GetModuleHandle( NULL ), NULL );
   SendMessageA( s_fteCopy, WM_SETFONT, (WPARAM) hGui, TRUE );

   hQuit = CreateWindowExA( 0, "BUTTON", "Quit",
      WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
      dlgW / 2 + 10, dlgH - 74, 130, 30, hDlg, (HMENU) 1002,
      GetModuleHandle( NULL ), NULL );
   SendMessageA( hQuit, WM_SETFONT, (WPARAM) hGui, TRUE );

   SetFocus( s_fteEdit );
   SendMessageA( s_fteEdit, EM_SETSEL, 0, 0 );

   s_fteModal = TRUE;
   while( s_fteModal )
   {
      if( PeekMessage( &msg, NULL, 0, 0, PM_REMOVE ) )
      {
         if( msg.message == WM_QUIT )
         {
            PostQuitMessage( (int) msg.wParam );
            break;
         }
         if( ! IsDialogMessage( hDlg, &msg ) )
         {
            TranslateMessage( &msg );
            DispatchMessage( &msg );
         }
      }
      else
         WaitMessage();
   }

   s_fteEdit = NULL;
   s_fteCopy = NULL;
   DeleteObject( hMono );
   DestroyWindow( hDlg );
   if( cLogCRLF )
      free( cLogCRLF );
}
