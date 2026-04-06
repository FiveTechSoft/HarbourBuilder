/* dbghook.c — C-level debug hook for socket debugger
 * Registers a C callback with hb_dbg_SetEntry() that forwards
 * debug events to a Harbour block (stored in a static).
 * Module name tracking is done in C to avoid re-entrancy issues. */

#include "hbapi.h"
#include "hbapiitm.h"
#include "hbvm.h"
#include "hbapidbg.h"
#include <string.h>

static PHB_ITEM s_pDbgBlock = NULL;
static int s_nReentrancy = 0;
static char s_szModule[256] = "";

static void DbgHookC( int nMode, int nLine, const char * szName,
                       int nIndex, PHB_ITEM pFrame )
{
   (void)nIndex; (void)pFrame;

   /* Mode 1 = module name — always track, even during re-entrancy */
   if( nMode == 1 && szName )
   {
      strncpy( s_szModule, szName, sizeof(s_szModule) - 1 );
      s_szModule[sizeof(s_szModule) - 1] = 0;
      return;
   }

   /* Only forward mode 5 (source line) to Harbour */
   if( nMode != 5 ) return;

   /* Prevent re-entrancy */
   if( s_nReentrancy > 0 ) return;

   if( s_pDbgBlock && HB_IS_BLOCK( s_pDbgBlock ) )
   {
      s_nReentrancy++;

      /* Call block with ( nLine, cModule ) */
      PHB_ITEM pLine = hb_itemPutNI( NULL, nLine );
      PHB_ITEM pModule = hb_itemPutC( NULL, s_szModule );
      hb_itemDo( s_pDbgBlock, 2, pLine, pModule );
      hb_itemRelease( pLine );
      hb_itemRelease( pModule );

      s_nReentrancy--;
   }
}

/* DbgHookInstall( bBlock ) — install C-level debug hook
 * bBlock receives: ( nLine, cModule ) on each source line */
HB_FUNC( DBGHOOKINSTALL )
{
   PHB_ITEM pBlock = hb_param( 1, HB_IT_BLOCK );
   if( pBlock )
   {
      if( s_pDbgBlock )
         hb_itemRelease( s_pDbgBlock );
      s_pDbgBlock = hb_itemNew( pBlock );
      hb_dbg_SetEntry( DbgHookC );
   }
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
