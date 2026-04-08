/* dbghook.c — C-level debug hook for socket debugger
 * Registers a C callback with hb_dbg_SetEntry() that forwards
 * debug events to a Harbour block (stored in a static).
 * Module name tracking is done in C to avoid re-entrancy issues. */

#include "hbapi.h"
#include "hbapiitm.h"
#include "hbvm.h"
#include "hbapidbg.h"
#include <string.h>
#include <stdio.h>

/* Windows uses _strnicmp instead of POSIX strncasecmp */
#ifdef _WIN32
   #define strncasecmp _strnicmp
#endif

static PHB_ITEM s_pDbgBlock = NULL;
static int s_nReentrancy = 0;
static char s_szModule[256] = "";
static int s_nHookCalls = 0;
static int s_nPassCount = 0;

static void DbgHookTrace( const char * msg )
{
   FILE * f = fopen( "c:\\hbbuilder_debug\\dbghook_trace.log", "a" );
   if( f ) { fprintf( f, "%s\n", msg ); fclose( f ); }
}

static void DbgHookC( int nMode, int nLine, const char * szName,
                       int nIndex, PHB_ITEM pFrame )
{
   (void)nIndex; (void)pFrame;

   /* Mode 1 = module name — only track when NOT in re-entrancy */
   if( nMode == 1 && szName && s_nReentrancy == 0 )
   {
      strncpy( s_szModule, szName, sizeof(s_szModule) - 1 );
      s_szModule[sizeof(s_szModule) - 1] = 0;
      return;
   }
   if( nMode == 1 ) return;

   /* Only forward mode 5 (source line) to Harbour */
   if( nMode != 5 ) return;

   /* Prevent re-entrancy */
   if( s_nReentrancy > 0 ) return;

   if( s_pDbgBlock && HB_IS_BLOCK( s_pDbgBlock ) )
   {
      /* Use STATIC buffers to avoid stack overflow in debug hook callback */
      static char szFull[256];
      static char procBuf[128];
      const char * procName;

      procBuf[0] = 0;
      hb_procinfo( 0, procBuf, NULL, NULL );
      procName = procBuf;

      snprintf( szFull, sizeof(szFull), "%s:%s",
                s_szModule[0] ? s_szModule : "?",
                procName ? procName : "?" );

      /* Skip framework T-classes (TForm, TButton, TApplication...) but NOT
       * user classes (TForm1, TForm2...) which contain digits */
      if( procName && procName[0] == 'T' && strlen(procName) > 3 )
      {
         int hasDigit = 0, k;
         for( k = 0; procName[k] && procName[k] != ':'; k++ )
            if( procName[k] >= '0' && procName[k] <= '9' ) { hasDigit = 1; break; }
         if( !hasDigit ) {
            static int s_nTSkip = 0;
            if( s_nTSkip < 3 ) { char t[128]; snprintf(t,sizeof(t),"SKIP T-class: '%s'", procName); DbgHookTrace(t); }
            s_nTSkip++;
            return;
         }
      }
      if( procName && (
          strncasecmp(procName, "DBGSTATE", 8) == 0 ||
          strncasecmp(procName, "DBGHOOK", 7) == 0 ||
          strncasecmp(procName, "DBGCLIENT", 9) == 0 ||
          strncasecmp(procName, "BUILDLOCALS", 11) == 0 ||
          strncasecmp(procName, "BUILDSTACK", 10) == 0 ||
          strncasecmp(procName, "__DBGINIT", 9) == 0 ||
          strncasecmp(procName, "SETDPIAWARE", 11) == 0 ||
          strncasecmp(procName, "_INITDPI", 8) == 0 ||
          strncasecmp(procName, "APPSHOWERROR", 12) == 0 ||
          strncasecmp(procName, "VALTOSTR", 8) == 0 ||
          strncasecmp(procName, "ISFRAMEWORKFUNC", 15) == 0 ||
          strncasecmp(procName, "DBGVALSTR", 9) == 0 ||
          strncasecmp(procName, "DBGSEND", 7) == 0 ||
          strncasecmp(procName, "DBGRECV", 7) == 0 ||
          strncasecmp(procName, "DBGLOG", 6) == 0 ||
          strncasecmp(procName, "MSGINFO", 7) == 0 ) )
         return;

      /* Trace: we passed all filters, about to call block */
      {
         if( s_nPassCount < 20 ) {
            char t[256];
            snprintf(t, sizeof(t), "PASS #%d: '%s' line %d (calling block...)", s_nPassCount, szFull, nLine);
            DbgHookTrace(t);
         }
         s_nPassCount++;
      }

      s_nReentrancy++;

      /* Call block with ( nLine, cModule, cProcName ) */
      {
         PHB_ITEM pLine = hb_itemPutNI( NULL, nLine );
         PHB_ITEM pModule = hb_itemPutC( NULL, szFull );
         PHB_ITEM pProc = hb_itemPutC( NULL, procName ? procName : "" );
         hb_itemDo( s_pDbgBlock, 3, pLine, pModule, pProc );
         hb_itemRelease( pLine );
         hb_itemRelease( pModule );
         hb_itemRelease( pProc );
      }

      if( s_nPassCount <= 20 ) DbgHookTrace("  block returned OK");
      s_nReentrancy--;
   }
}

/* DbgHookInstall( bBlock ) — install C-level debug hook
 * bBlock receives: ( nLine, cModule ) on each source line */
void DbgHookResetPass(void) { s_nPassCount = 0; }

HB_FUNC( DBGHOOKINSTALL )
{
   PHB_ITEM pBlock = hb_param( 1, HB_IT_BLOCK );
   /* Clear trace log and counters */
   { FILE * f = fopen("c:\\hbbuilder_debug\\dbghook_trace.log","w"); if(f) fclose(f); }
   s_nHookCalls = 0;
   { extern void DbgHookResetPass(void); DbgHookResetPass(); }
   DbgHookTrace( "DbgHookInstall called" );
   if( pBlock )
   {
      DbgHookTrace( "Block is valid, storing..." );
      if( s_pDbgBlock )
         hb_itemRelease( s_pDbgBlock );
      s_pDbgBlock = hb_itemNew( pBlock );
      DbgHookTrace( "Calling hb_dbg_SetEntry..." );
      hb_dbg_SetEntry( DbgHookC );
      DbgHookTrace( "hb_dbg_SetEntry OK" );
   }
   else
      DbgHookTrace( "Block is NULL!" );
}

/* DbgHookRemove() — remove the debug hook */
HB_FUNC( DBGHOOKREMOVE )
{
   hb_dbg_SetEntry( NULL );
   if( s_pDbgBlock )
   {
      hb_itemRelease( s_pDbgBlock );
      s_pDbgBlock = NULL;
   }
}
