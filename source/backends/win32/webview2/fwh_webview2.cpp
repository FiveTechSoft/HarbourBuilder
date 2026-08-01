// copyright Bruno Cantero 2024. Modifications implemented by FiveTech

#include "FwhWebView2.h"
#include <shlobj.h>
#include "webview2.h"
#include <hbapiitm.h>
#include <hbvm.h>

#ifndef LSTATUS // VC98
   #define LSTATUS int
   #define KEY_WOW64_32KEY         (0x0200)
   #if ( defined( _MSC_VER ) && ( _MSC_VER <= 1500 ) )
      WINOLEAPI CoInitializeEx(LPVOID,DWORD);
      SHFOLDERAPI SHGetFolderPathA( HWND hwnd, int csidl, HANDLE hToken, DWORD dwFlags, LPSTR pszPath );
      #define SHGetFolderPath SHGetFolderPathA
   #endif   
#endif   

/* Pump Win32 messages while waiting for WebView2 COM callbacks (FWH SysRefresh). */
extern "C" BOOL SysRefresh( void )
{
   MSG msg;
   while( PeekMessage( &msg, NULL, 0, 0, PM_REMOVE ) )
   {
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }
   Sleep( 1 );
   return TRUE;
}

/* Optional Harbour callbacks — only if PRG defined the function. */
static void HbCallOptional( const char * szName, const char * szArg, void * pEngine )
{
   PHB_DYNS pDyn = hb_dynsymFindName( szName );
   if( pDyn == NULL || ! hb_dynsymIsFunction( pDyn ) )
      return;
   hb_vmPushSymbol( hb_dynsymSymbol( pDyn ) );
   hb_vmPushNil();
   if( szArg )
      hb_vmPushString( szArg, ( HB_SIZE ) strlen( szArg ) );
   else
      hb_vmPushNil();
   hb_vmPushPointer( pEngine );
   hb_vmFunction( 2 );
}

#if defined( __GNUC__ )
#pragma GCC diagnostic ignored "-Wdelete-non-virtual-dtor"
#endif

class FwhWv2Handler : public ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler,
                                   ICoreWebView2CreateCoreWebView2ControllerCompletedHandler,
                                   ICoreWebView2WebMessageReceivedEventHandler,
                                   ICoreWebView2PermissionRequestedEventHandler,
                                   ICoreWebView2NavigationCompletedEventHandler,
                                   ICoreWebView2ExecuteScriptCompletedHandler,
                                   ICoreWebView2DownloadStartingEventHandler,
                                   ICoreWebView2NewWindowRequestedEventHandler
                                   // ICoreWebView2ExecuteScriptWithResultCompletedHandler
{
   private:
      LONG lAttempts;
      FwhWebView2 * hWebView;

   protected:
      /* IUnknown */
      STDMETHOD( QueryInterface )( REFIID, PVOID * );
      STDMETHOD_( ULONG, AddRef )( void );
      STDMETHOD_( ULONG, Release )( void );

      /* ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler */
      STDMETHOD( Invoke )( HRESULT, ICoreWebView2Environment * );

      /* ICoreWebView2CreateCoreWebView2ControllerCompletedHandler */
      STDMETHOD( Invoke )( HRESULT, ICoreWebView2Controller * );

      /* ICoreWebView2WebMessageReceivedEventHandler */
      STDMETHOD( Invoke )( ICoreWebView2 *, ICoreWebView2WebMessageReceivedEventArgs * pArgs );

      /* ICoreWebView2PermissionRequestedEventHandler */
      STDMETHOD( Invoke )( ICoreWebView2 *, ICoreWebView2PermissionRequestedEventArgs * );

      /* ICoreWebView2NavigationCompletedEventHandler */
      STDMETHOD(Invoke)(ICoreWebView2*, ICoreWebView2NavigationCompletedEventArgs * );

      /* ICoreWebView2ExecuteScriptCompletedHandler */
      STDMETHOD( Invoke)( HRESULT errorCode, LPCWSTR resultObjectAsJson);

      STDMETHOD( Invoke )(ICoreWebView2 *,ICoreWebView2DownloadStartingEventArgs * e )
      {
         if( ! hWebView->bShowDownloads )
            e->put_Handled( TRUE );

         return S_OK;
      }

      /* ICoreWebView2NewWindowRequestedEventHandler */
      STDMETHOD( Invoke )( ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs * );

   public:
      FwhWv2Handler( FwhWebView2 * );
      HRESULT CreateEnvironment( void );

   friend class FwhWebView2;
};

FwhWv2Handler::FwhWv2Handler( FwhWebView2 * _hWebView )
{
   hWebView = _hWebView;
   lAttempts = 0;
}

STDMETHODIMP FwhWv2Handler::QueryInterface( REFIID riid, PVOID * ppv )
{
   return hWebView->QueryInterface( riid, ppv );
}

STDMETHODIMP_( ULONG ) FwhWv2Handler::AddRef( void )
{
   return ++hWebView->lRefCount;
}

STDMETHODIMP_( ULONG ) FwhWv2Handler::Release( void )
{
   return --hWebView->lRefCount;
}

STDMETHODIMP FwhWv2Handler::Invoke( HRESULT hResult, ICoreWebView2Environment * pCoreWebView2Environment )
{
   if( SUCCEEDED( hResult ) )
   {
      hResult = pCoreWebView2Environment->CreateCoreWebView2Controller( hWebView->hWnd, this );

      if( SUCCEEDED( hResult ) )
         return S_OK;
   }

   CreateEnvironment();

   return S_OK;
}

STDMETHODIMP FwhWv2Handler::Invoke( HRESULT hResult, ICoreWebView2Controller * pController )
{
   ICoreWebView2 * pCoreWebView2;

   if( hResult == E_ABORT || hResult == HRESULT_FROM_WIN32( ERROR_INVALID_STATE ) )
      return S_OK;

   if( FAILED( hResult ) )
   {
      CreateEnvironment();

      return S_OK;
   }

   pController->get_CoreWebView2( &pCoreWebView2 );
   hWebView->pCoreWebView2 = pCoreWebView2;
   hWebView->pCoreWebView2->AddRef();
   hWebView->pController = pController;
   hWebView->pController->AddRef();
   hWebView->bBusy = FALSE;

   return S_OK;
}

STDMETHODIMP FwhWv2Handler::Invoke( ICoreWebView2 *, ICoreWebView2WebMessageReceivedEventArgs * pArgs )
{
   LPWSTR wszMessage = NULL; 
   char * szArgs;
   int iLen;

   pArgs->TryGetWebMessageAsString( &wszMessage );
   iLen = WideCharToMultiByte(CP_ACP, 0, wszMessage, -1, NULL, 0, NULL, NULL );
   szArgs = (char*)hb_xgrab(iLen);
   WideCharToMultiByte(CP_ACP, 0, wszMessage, -1, szArgs, iLen, NULL, NULL);

   HbCallOptional( "WEBVIEW2_ONBIND", szArgs, hWebView );

   hb_xfree(( void * ) szArgs );
   CoTaskMemFree( wszMessage );

   return S_OK;
}

STDMETHODIMP FwhWv2Handler::Invoke( ICoreWebView2 *, ICoreWebView2PermissionRequestedEventArgs * )
{
   return S_OK;
}

STDMETHODIMP FwhWv2Handler::Invoke( ICoreWebView2 * pCoreWebView2, ICoreWebView2NavigationCompletedEventArgs * )
{
   WCHAR * szWideText;
   char * szUrl;
   int iSize;

   hWebView->bBusy = FALSE;

   pCoreWebView2->get_Source( &szWideText );
   iSize = WideCharToMultiByte( CP_ACP, 0, szWideText, -1, NULL, 0, NULL, NULL );
   szUrl = ( char * ) hb_xgrab( iSize );
   WideCharToMultiByte( CP_ACP, 0, szWideText, iSize, szUrl, iSize, NULL, NULL );

   HbCallOptional( "WEBVIEW2_ONNAVIGATIONCOMPLETED", szUrl, hWebView );

   hb_xfree( ( void * ) szUrl );
   CoTaskMemFree( szWideText );   
   
   return S_OK;
}

STDMETHODIMP FwhWv2Handler::Invoke( HRESULT, LPCWSTR resultObjectAsJson )
{   
   int iLen = WideCharToMultiByte(CP_ACP, 0, resultObjectAsJson, -1, NULL, 0, NULL, NULL );
   char * szJson = ( char * ) hb_xgrab( iLen );

   hWebView->bBusy = FALSE;

   WideCharToMultiByte(CP_ACP, 0, resultObjectAsJson, -1, szJson, iLen, NULL, NULL);

   HbCallOptional( "WEBVIEW2_ONEVAL", szJson, hWebView );

   hb_xfree(( void * ) szJson);

   return S_OK;
}

STDMETHODIMP FwhWv2Handler::Invoke( ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs * e )
{
   LPWSTR uri = NULL;
   char * szUrl;
   int iLen;

   e->get_Uri( &uri );
   if( uri )
   {
      iLen = WideCharToMultiByte( CP_ACP, 0, uri, -1, NULL, 0, NULL, NULL );
      szUrl = ( char * ) hb_xgrab( iLen );
      WideCharToMultiByte( CP_ACP, 0, uri, -1, szUrl, iLen, NULL, NULL );

      e->put_Handled( TRUE );

      hWebView->Navigate( szUrl );

      hb_xfree( ( void * ) szUrl );
      CoTaskMemFree( uri );
   }

   return S_OK;
}

HRESULT FwhWv2Handler::CreateEnvironment( void )
{
   HMODULE hDll;
   HRESULT hResult;
   HRESULT ( CALLBACK * pCreateWebViewEnvironmentWithOptionsInternal )( bool, int, PCWSTR, IUnknown *, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler * );

   if( lAttempts >= 5 || hWebView->szDll == NULL || * hWebView->szDll == 0 )
      return TRUE;

   lAttempts++;
   hDll = LoadLibrary( hWebView->szDll );

   if( hDll == NULL )
      return TRUE;

   pCreateWebViewEnvironmentWithOptionsInternal = ( HRESULT ( CALLBACK * )( bool, int, PCWSTR, IUnknown *, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler * ) ) ( void (*)( void ) ) GetProcAddress( hDll, "CreateWebViewEnvironmentWithOptionsInternal" );

   if( pCreateWebViewEnvironmentWithOptionsInternal != NULL )
   {
      hResult = pCreateWebViewEnvironmentWithOptionsInternal( true, 0, hWebView->wszAppData, NULL, this );

      if( hResult == S_OK || hResult == HRESULT_FROM_WIN32( ERROR_INVALID_STATE ) )
      {
         FreeLibrary( hDll );

         return S_OK;
      }

      FreeLibrary( hDll );

      return CreateEnvironment();
   }

   FreeLibrary( hDll );

   return TRUE;
}

/* Build path to EmbeddedBrowserWebView.dll from a Fixed Version /
 * browserExecutableFolder root (folder that contains msedgewebview2.exe).
 * Returns an hb_xgrab buffer, or NULL if the DLL is not found. */
static char * WebView2_DllFromBrowserFolder( const char * szBrowserFolder )
{
   char szPath[ MAX_PATH + 80 ];
   int iLen;
   DWORD dwAttr;

   if( szBrowserFolder == NULL || * szBrowserFolder == 0 )
      return NULL;

   iLen = lstrlen( szBrowserFolder );
   if( iLen >= MAX_PATH )
      return NULL;

   lstrcpyn( szPath, szBrowserFolder, MAX_PATH );

   /* Strip trailing backslash / slash */
   while( iLen > 0 && ( szPath[ iLen - 1 ] == '\\' || szPath[ iLen - 1 ] == '/' ) )
   {
      szPath[ iLen - 1 ] = 0;
      iLen--;
   }

   /* If the caller already passed the full path to the DLL, accept it. */
   if( iLen > 4 && lstrcmpi( szPath + iLen - 4, ".dll" ) == 0 )
   {
      dwAttr = GetFileAttributes( szPath );
      if( dwAttr != INVALID_FILE_ATTRIBUTES && ! ( dwAttr & FILE_ATTRIBUTE_DIRECTORY ) )
      {
         char * szDll = ( char * ) hb_xgrab( iLen + 1 );
         lstrcpy( szDll, szPath );
         return szDll;
      }
      return NULL;
   }

   /* Standard layout: {folder}\EBWebView\{x86|x64}\EmbeddedBrowserWebView.dll */
   lstrcat( szPath, "\\EBWebView\\" );
#ifdef _WIN64
   lstrcat( szPath, "x64" );
#else
   lstrcat( szPath, "x86" );
#endif
   lstrcat( szPath, "\\EmbeddedBrowserWebView.dll" );

   dwAttr = GetFileAttributes( szPath );
   if( dwAttr != INVALID_FILE_ATTRIBUTES && ! ( dwAttr & FILE_ATTRIBUTE_DIRECTORY ) )
   {
      char * szDll = ( char * ) hb_xgrab( lstrlen( szPath ) + 1 );
      lstrcpy( szDll, szPath );
      return szDll;
   }

   return NULL;
}

FwhWebView2::FwhWebView2( HWND _hWnd, const char * szUserDataFolder,
                    const char * szBrowserExecutableFolder )
{
   DWORD dwSize = 0;
   char * szValue = NULL;
   char * szVersion = NULL;
   char * szPos = NULL;
   LSTATUS hStatus = ( LSTATUS ) -1;
   HKEY hKey;

   hWnd = _hWnd;
   lRefCount = 1;
   bVisible = TRUE;
   bShowDownloads = TRUE;
   bBusy = FALSE;
   szDll = NULL;
   pCoreWebView2 = NULL;
   pController = NULL;
   pSettings = NULL;
   pSettings2 = NULL;
   pWebView2ComHandler = NULL;

   /* Prefer Fixed Version / standalone Runtime when a browser folder is given
      (Microsoft browserExecutableFolder: folder that contains msedgewebview2.exe).
      If the folder is specified but the DLL is missing, do not fall back to
      the system Evergreen Runtime — that would hide a packaging error. */
   if( szBrowserExecutableFolder && * szBrowserExecutableFolder )
      szDll = WebView2_DllFromBrowserFolder( szBrowserExecutableFolder );

   /* Evergreen Runtime installed on the system (registry) when no folder given. */
   if( szDll == NULL &&
       ( szBrowserExecutableFolder == NULL || * szBrowserExecutableFolder == 0 ) )
   {
      hStatus = RegOpenKeyEx( HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\EdgeUpdate\\ClientState\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}", 0, KEY_READ | KEY_WOW64_32KEY, &hKey );

      if( hStatus != ERROR_SUCCESS )
         hStatus = RegOpenKeyEx( HKEY_CURRENT_USER, "SOFTWARE\\Microsoft\\EdgeUpdate\\ClientState\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}", 0, KEY_READ | KEY_WOW64_32KEY, &hKey );

      if( hStatus == ERROR_SUCCESS )
      {
         dwSize = 0;
         hStatus = RegQueryValueEx( hKey, "EBWebView", NULL, NULL, NULL, &dwSize );

         if( hStatus == ERROR_SUCCESS || hStatus == ERROR_MORE_DATA )
         {
            szValue = ( char * ) hb_xgrab( dwSize );
            hStatus = RegQueryValueEx( hKey, "EBWebView", NULL, NULL, ( LPBYTE ) szValue, &dwSize );

            if( hStatus == ERROR_SUCCESS )
            {
               szPos = strrchr( szValue, '\\' );
               hStatus = szPos == NULL ? TRUE : ERROR_SUCCESS;
            }

            if( hStatus == ERROR_SUCCESS )
            {
               szPos++;
               szVersion = szPos;
               szPos = strrchr( szVersion, '.' );
               hStatus = szPos == NULL ? TRUE : ERROR_SUCCESS;
            }

            if( hStatus == ERROR_SUCCESS )
            {
               * szPos = 0;
               szVersion = strrchr( szVersion, '.' );
               hStatus = szVersion == NULL ? TRUE : ERROR_SUCCESS;
            }

            if( hStatus == ERROR_SUCCESS )
            {
               hStatus = lstrcmp( szVersion + 1, "1150" ) < 0 ? TRUE : ERROR_SUCCESS;
               * szPos = '.';
            }

            if( hStatus != ERROR_SUCCESS )
               hb_xfree( ( void * ) szValue );
         }

         RegCloseKey( hKey );
      }

      if( hStatus == ERROR_SUCCESS )
      {
         szValue = ( char * ) hb_xrealloc( szValue, dwSize + 41 + 1 );
         lstrcat( szValue, "\\EBWebView\\" );
#ifdef _WIN64
         lstrcat( szValue, "x64" );
#else
         lstrcat( szValue, "x86" );
#endif

         lstrcat( szValue, "\\EmbeddedBrowserWebView.dll" );
         szDll = szValue;
      }
   }

   if( szUserDataFolder && *szUserDataFolder )
   {
      int iLen = ( int ) strlen( szUserDataFolder );
      wszAppData = ( LPWSTR ) hb_xgrab( ( iLen + 1 ) * 2 );
      MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szUserDataFolder, iLen + 1, wszAppData, iLen + 1 );
   }
   else
   {
      wszAppData = ( LPWSTR ) hb_xgrab( 2 );
      memset( wszAppData, 0, 2 );
   }

   pWebView2ComHandler = new FwhWv2Handler( this );
   CoInitializeEx( NULL, COINIT_APARTMENTTHREADED );
   Initialize();
}

FwhWebView2::~FwhWebView2( void )
{
   if( szDll != NULL )
      hb_xfree( ( void * ) szDll );
   if( wszAppData != NULL )
      hb_xfree( ( void * ) wszAppData );

   if( pCoreWebView2 != NULL )
   {
      pCoreWebView2->remove_WebMessageReceived( iWebMessageReceivedToken);
      pCoreWebView2->remove_PermissionRequested( iPermissionRequestedToken);
      pCoreWebView2->remove_NavigationCompleted( iNavigationCompletedToken);
      pCoreWebView2->remove_NewWindowRequested( iNewWindowRequestedToken );
      ( ( ICoreWebView2_4 * ) pCoreWebView2 )->remove_DownloadStarting( iDownloadStartingRequested );
   }

   if( pSettings != NULL )
      pSettings->Release();
   if( pSettings2 != NULL )
      pSettings2->Release();

   if( pWebView2ComHandler != NULL )
      delete pWebView2ComHandler;
   CoUninitialize();
}

void FwhWebView2::Initialize( void )
{
   LONG lLength;
   char szExeName[ MAX_PATH ];
   char szAppData[ MAX_PATH ];
   char * szPos;
   HRESULT hResult;
   RECT rect;

   /* Only invent a default user-data folder when the caller did not supply one.
      (cUserDataFolder from TWebView2:New must be honoured.) */
   if( wszAppData == NULL || * wszAppData == 0 )
   {
      GetModuleFileName( GetModuleHandle( 0 ), szExeName, MAX_PATH );
      szPos = strrchr( szExeName, '\\' );

      if( szPos == NULL )
         return;

      szPos++;

      if( SHGetFolderPath( NULL, CSIDL_APPDATA, NULL, 0, szAppData ) != S_OK )
         return;

      lstrcat( szAppData, "\\" );
      lstrcat( szAppData, szPos );
      lLength = lstrlen( szAppData );
      wszAppData = ( LPWSTR ) hb_xrealloc( wszAppData, ( lLength + 1 ) * 2 );
      MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szAppData, lLength + 1, wszAppData, lLength + 1 );
   }

   bBusy = TRUE;
   pWebView2ComHandler->CreateEnvironment();
   while( bBusy )
      SysRefresh();
   
   if( pCoreWebView2 == NULL || pController == NULL )
      return;

   pCoreWebView2->add_WebMessageReceived(pWebView2ComHandler, &iWebMessageReceivedToken);
   pCoreWebView2->add_PermissionRequested(pWebView2ComHandler, &iPermissionRequestedToken);
   pCoreWebView2->add_NavigationCompleted(pWebView2ComHandler, &iNavigationCompletedToken);
   pCoreWebView2->add_NewWindowRequested(pWebView2ComHandler, &iNewWindowRequestedToken);
   ( ( ICoreWebView2_4 * ) pCoreWebView2 )->add_DownloadStarting(pWebView2ComHandler, &iDownloadStartingRequested );

   hResult = pCoreWebView2->get_Settings( &pSettings );

   if( hResult != S_OK )
      return;

   pSettings->QueryInterface( IID_ICoreWebView2Settings2, ( void ** ) ( &pSettings2 ) );

   hResult = pSettings->put_AreDevToolsEnabled( FALSE );

   if( hResult != S_OK )
      return;

   hResult = pSettings->put_IsStatusBarEnabled( FALSE );

   if( hResult != S_OK )
      return;

   pCoreWebView2->AddScriptToExecuteOnDocumentCreated( L"window.external={invoke:s=>window.chrome.webview.postMessage(s)}", NULL );
   pCoreWebView2->AddScriptToExecuteOnDocumentCreated(L"(function()"
       L"{"
       L"   var name = 'SendToFWH';"
       L"   var RPC = window._rpc = (window._rpc || {nextSeq: 1});"
       L"   window[name] = function()"
       L"   {"
       L"      var seq = RPC.nextSeq++;"
       L"      var promise = new Promise(function(resolve, reject)"
       L"      {"
       L"         RPC[seq] ="
       L"         {"
       L"            resolve: resolve,"
       L"            reject: reject,"
       L"         };"
       L"      });"
       L"   window.external.invoke(JSON.stringify("
       L"   {"
       L"      id: seq,"
       L"      method: name,"
       L"      params: Array.prototype.slice.call(arguments),"
       L"   }));"
       L"   return promise;"
       L"}})();", NULL);

   GetWindowRect( hWnd, &rect );    
   SetSize( rect.right - rect.left, rect.bottom - rect.top );
   pController->put_IsVisible( bVisible );
}

void FwhWebView2::Navigate( const char * szUrl )
{
   LONG lLength;
   LPWSTR szWideText;

   if( pCoreWebView2 == NULL )
      return;

   if( szUrl == NULL || * szUrl == 0 )
      szUrl = ( char * ) "about:blank";

   lLength = lstrlen( szUrl );
   szWideText = ( LPWSTR ) hb_xgrab( ( lLength + 1 ) * 2 );
   MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szUrl, lLength + 1, szWideText, lLength + 1 );
   while( bBusy )
      SysRefresh();

   bBusy = TRUE;
   pCoreWebView2->Navigate( szWideText );
   hb_xfree( ( void * ) szWideText);
}

void FwhWebView2::SetHtml( const char * szHtml )
{
   LONG lLength;
   LPWSTR szWideText;

   if( pCoreWebView2 == NULL )
      return;

   if( szHtml == NULL || * szHtml == 0 )
      szHtml = ( char * ) "";

   lLength = lstrlen( szHtml );
   szWideText = ( LPWSTR ) hb_xgrab( ( lLength + 1 ) * 2 );
   MultiByteToWideChar( CP_UTF8, MB_PRECOMPOSED, szHtml, lLength + 1, szWideText, lLength + 1 );
   while( bBusy )
      SysRefresh();

   bBusy = TRUE;
   pCoreWebView2->NavigateToString( szWideText );
   hb_xfree( ( void * ) szWideText);
}

HRESULT FwhWebView2::QueryInterface( REFIID riid, PVOID * ppv )
{
   if( ppv == NULL )
      return E_POINTER;

   if( IsEqualIID( riid, IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler ) ||
       IsEqualIID( riid, IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler ) ||
       IsEqualIID( riid, IID_ICoreWebView2WebMessageReceivedEventHandler ) ||
       IsEqualIID( riid, IID_ICoreWebView2PermissionRequestedEventHandler ) || 
       IsEqualIID( riid, IID_ICoreWebView2NavigationCompletedEventHandler ) || 
       IsEqualIID( riid, IID_ICoreWebView2ExecuteScriptCompletedHandler ) ||
       IsEqualIID( riid, IID_ICoreWebView2DownloadStartingEventHandler ) ||
       IsEqualIID( riid, IID_ICoreWebView2NewWindowRequestedEventHandler ) )

      * ppv = pWebView2ComHandler;
   else
   {
      * ppv = NULL;
      return E_NOINTERFACE;
   }

   pWebView2ComHandler->AddRef();

   return S_OK;
}

void FwhWebView2::SetSize( LONG lWidth, LONG lHeight )
{
   if( hWnd != NULL && pController != NULL )
   {
      RECT rect;

      rect.top = 0;
      rect.left = 0;
      rect.right = lWidth;
      rect.bottom = lHeight;
      pController->put_Bounds( rect );
   }
}

void FwhWebView2::Eval( const char * szJS )
{
   LONG lLength;
   LPWSTR szWideText;

   if( pCoreWebView2 == NULL)
      return;

   if( szJS == NULL || * szJS == 0 )
      szJS = ( const char * ) "";

   lLength = lstrlen( szJS );
   szWideText = ( LPWSTR ) hb_xgrab( ( lLength + 1 ) * 2 );
   MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szJS, lLength + 1, szWideText, lLength + 1 );
   
   // while( bBusy )
   //    SysRefresh();
      
   // bBusy = TRUE;

   pCoreWebView2->ExecuteScript( szWideText, pWebView2ComHandler );
   
   hb_xfree( ( void * ) szWideText );
}

void FwhWebView2::SetUserAgent( const char * szUserAgent )
{
   LONG lLength;
   LPWSTR szWideText;

   if( pCoreWebView2 == NULL)
      return;

   if( szUserAgent == NULL || * szUserAgent == 0 )
      szUserAgent = ( const char * ) "";

   lLength = lstrlen( szUserAgent );
   szWideText = ( LPWSTR ) hb_xgrab( ( lLength + 1 ) * 2 );
   MultiByteToWideChar( CP_ACP, MB_PRECOMPOSED, szUserAgent, lLength + 1, szWideText, lLength + 1 );
   pSettings2->put_UserAgent( szWideText );
   hb_xfree( ( void * ) szWideText );
}

void FwhWebView2::OpenDevToolsWindow( BOOL bOnOff )
{
   if( bOnOff )
      pCoreWebView2->OpenDevToolsWindow();

   pSettings->put_AreDevToolsEnabled( bOnOff );
}

extern "C"
{
   void * webview2_new( HWND hWnd, const char * szUserDataFolder,
                        const char * szBrowserExecutableFolder )
   {
      return new FwhWebView2( hWnd, szUserDataFolder, szBrowserExecutableFolder );
   }

   void webview2_end( FwhWebView2 * hWebView )
   {
      delete hWebView;
   }

   void webview2_navigate( FwhWebView2 * hWebView, const char * szUrl )
   {
      hWebView->Navigate( szUrl );
   }

   void webview2_sethtml( FwhWebView2 * hWebView, const char * szHtml )
   {
      hWebView->SetHtml( szHtml );
   }

   void webview2_setsize( FwhWebView2 * hWebView, LONG lWidth, LONG lHeight )
   {
      hWebView->SetSize( lWidth, lHeight );
   }

   void webview2_eval( FwhWebView2 * hWebView, const char * szJS )
   {
      hWebView->Eval( szJS );
   }

   void webview2_setuseragent( FwhWebView2 * hWebView, const char * szUserAgent )
   {
      hWebView->SetUserAgent( szUserAgent );
   }

   void webview2_opendevtoolswindow( FwhWebView2 * hWebView, BOOL bOnOff )
   {
      hWebView->OpenDevToolsWindow( bOnOff ); 
   }

   void webview2_showdownloads( FwhWebView2 * hWebView, BOOL bOnOff )
   {
      hWebView->bShowDownloads = bOnOff;
   } 
}