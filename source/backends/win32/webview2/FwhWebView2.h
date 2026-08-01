// copyright Bruno Cantero 2024. Modifications implemented by FiveTech

#ifndef _FWH_WEBVIEW2_H_
#define _FWH_WEBVIEW2_H_

#include <windows.h>
#include "webview2.h"
#include <hbapi.h>

class FwhWv2Handler;
interface ICoreWebView2;
interface ICoreWebView2Controller;

class FwhWebView2
{
   public:
      BOOL bShowDownloads;

   private:
      char * szDll;
      LPWSTR wszAppData;
      LONG lRefCount;
      FwhWv2Handler * pWebView2ComHandler;
      ICoreWebView2 * pCoreWebView2;
      ICoreWebView2Controller * pController;
      HWND hWnd;
      BOOL bVisible;
      EventRegistrationToken iWebMessageReceivedToken;
      EventRegistrationToken iPermissionRequestedToken;
      EventRegistrationToken iNavigationCompletedToken;
      EventRegistrationToken iDownloadStartingRequested;
      ICoreWebView2Settings * pSettings;
      ICoreWebView2Settings2 * pSettings2;
      BOOL bBusy;

   private:
      HRESULT QueryInterface( REFIID, PVOID * );

   protected:
      void Initialize( void );

   EventRegistrationToken iNewWindowRequestedToken;

   public:
      FwhWebView2( HWND hWnd, const char * szUserDataFolder = NULL,
                const char * szBrowserExecutableFolder = NULL );
      virtual ~FwhWebView2( void );
      void Navigate( const char * szUrl );
      void SetHtml( const char * szHtml );
      void SetSize( LONG lWidth, LONG lHeight );
      void Eval( const char * js );
      void SetUserAgent( const char * szUserAgent );
      void OpenDevToolsWindow( BOOL bOnOff );
		void * operator new( size_t size ) { return hb_xgrab( size ); }
		void operator delete( void *pVoid ) { hb_xfree( pVoid ); }	
      void HideDownloads( void );

   friend class FwhWv2Handler;
};

#endif