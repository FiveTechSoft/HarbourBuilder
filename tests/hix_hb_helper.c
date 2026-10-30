/* hix_hb_helper.c - test-only GTK main-loop heartbeat for the HIX mainloop
 * characterization. A 50ms g_timeout tick appends the monotonic clock (ms)
 * to a file: while the main loop is busy in the synchronous HIX request
 * callback, ticks stop; the gap in the file IS the measured UI freeze. */
#include <gtk/gtk.h>
#include <hbapi.h>

static FILE * g_hbFile = NULL;

static gboolean hb_tick( gpointer data )
{
   (void) data;
   if( g_hbFile )
   {
      fprintf( g_hbFile, "%lld\n", (long long)( g_get_monotonic_time() / 1000 ) );
      fflush( g_hbFile );
   }
   return G_SOURCE_CONTINUE;
}

HB_FUNC( HIX_HEARTBEAT_START )  /* ( cPath ) -> lOk */
{
   if( g_hbFile ) fclose( g_hbFile );
   g_hbFile = fopen( hb_parc(1), "w" );
   if( g_hbFile )
      g_timeout_add( 50, hb_tick, NULL );
   hb_retl( g_hbFile != NULL );
}
