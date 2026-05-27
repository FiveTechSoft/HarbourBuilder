/*
 * cocoa_mysql.c - libmysqlclient bindings for HbBuilder TMySQL class
 *
 * Exposes minimal MySQL C API to Harbour PRG layer:
 *   HBMYSQL_OPEN( cHost, cUser, cPass, cDB, nPort ) -> nHandle | 0
 *   HBMYSQL_CLOSE( nHandle )
 *   HBMYSQL_EXEC ( nHandle, cSQL )                  -> lOk
 *   HBMYSQL_QUERY( nHandle, cSQL )                  -> aRows ( array of array of string )
 *   HBMYSQL_FIELDS(nHandle, cSQL )                  -> aFieldNames
 *   HBMYSQL_ERROR( nHandle )                        -> cMsg
 *   HBMYSQL_LASTID(nHandle )                        -> nId
 *   HBMYSQL_TABLES(nHandle )                        -> aTableNames
 */

#include <hbapi.h>
#include <hbapiitm.h>
#include <string.h>
#include <stdlib.h>

#ifdef HB_NO_MYSQL
/* No-op stubs when mysql-client headers/libs are unavailable. classes.prg
   declares EXTERNAL HBMYSQL_* on macOS, so every entry point must link. */
HB_FUNC( HBMYSQL_OPEN )   { hb_retnint( 0 ); }
HB_FUNC( HBMYSQL_CLOSE )  { }
HB_FUNC( HBMYSQL_EXEC )   { hb_retl( 0 ); }
HB_FUNC( HBMYSQL_QUERY )  { hb_reta( 0 ); }
HB_FUNC( HBMYSQL_FIELDS ) { hb_reta( 0 ); }
HB_FUNC( HBMYSQL_ERROR )  { hb_retc( "mysql disabled at build (HB_NO_MYSQL)" ); }
HB_FUNC( HBMYSQL_LASTID ) { hb_retnint( 0 ); }
HB_FUNC( HBMYSQL_TABLES ) { hb_reta( 0 ); }
#else
#include <mysql.h>

static const char * mysql_safe_err( MYSQL * h )
{
   const char * s = h ? mysql_error( h ) : NULL;
   return s ? s : "";
}

HB_FUNC( HBMYSQL_OPEN )
{
   const char * host = HB_ISCHAR(1) ? hb_parc(1) : "127.0.0.1";
   const char * user = HB_ISCHAR(2) ? hb_parc(2) : "root";
   const char * pass = HB_ISCHAR(3) ? hb_parc(3) : "";
   const char * db   = HB_ISCHAR(4) ? hb_parc(4) : NULL;
   unsigned int port = HB_ISNUM(5) ? (unsigned int) hb_parni(5) : 3306;

   MYSQL * h = mysql_init( NULL );
   if( ! h ) { hb_retnint(0); return; }

   if( ! mysql_real_connect( h, host, user, pass, db, port, NULL, 0 ) ) {
      mysql_close( h );
      hb_retnint(0);
      return;
   }

   mysql_set_character_set( h, "utf8mb4" );
   hb_retnint( (HB_PTRUINT) h );
}

HB_FUNC( HBMYSQL_CLOSE )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   if( h ) mysql_close( h );
}

HB_FUNC( HBMYSQL_EXEC )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   if( !h || !sql ) { hb_retl(0); return; }

   if( mysql_query( h, sql ) != 0 ) { hb_retl(0); return; }

   /* Drain any result set so subsequent queries don't fail */
   MYSQL_RES * res = mysql_store_result( h );
   if( res ) mysql_free_result( res );
   hb_retl(1);
}

static void rows_to_array( MYSQL * h, const char * sql, PHB_ITEM aRet, PHB_ITEM aFields )
{
   if( mysql_query( h, sql ) != 0 ) return;
   MYSQL_RES * res = mysql_store_result( h );
   if( !res ) return;

   unsigned int nCols = mysql_num_fields( res );

   if( aFields ) {
      MYSQL_FIELD * f;
      mysql_field_seek( res, 0 );
      while( ( f = mysql_fetch_field( res ) ) ) {
         PHB_ITEM s = hb_itemPutC( NULL, f->name ? f->name : "" );
         hb_arrayAddForward( aFields, s );
         hb_itemRelease( s );
      }
   }

   if( aRet ) {
      MYSQL_ROW row;
      while( ( row = mysql_fetch_row( res ) ) ) {
         unsigned long * lens = mysql_fetch_lengths( res );
         PHB_ITEM aRow = hb_itemArrayNew( nCols );
         for( unsigned int i = 0; i < nCols; i++ ) {
            if( row[i] )
               hb_arraySetCL( aRow, i + 1, row[i], lens ? lens[i] : strlen( row[i] ) );
            else
               hb_arraySetC( aRow, i + 1, "" );
         }
         hb_arrayAddForward( aRet, aRow );
         hb_itemRelease( aRow );
      }
   }

   mysql_free_result( res );
}

HB_FUNC( HBMYSQL_QUERY )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( h && sql ) rows_to_array( h, sql, aRet, NULL );
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBMYSQL_FIELDS )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( h && sql ) rows_to_array( h, sql, NULL, aRet );
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBMYSQL_ERROR )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   hb_retc( mysql_safe_err( h ) );
}

HB_FUNC( HBMYSQL_LASTID )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   hb_retnint( h ? (HB_LONGLONG) mysql_insert_id( h ) : 0 );
}

HB_FUNC( HBMYSQL_TABLES )
{
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( h ) {
      MYSQL_RES * res = mysql_list_tables( h, NULL );
      if( res ) {
         MYSQL_ROW row;
         while( ( row = mysql_fetch_row( res ) ) ) {
            if( row[0] ) {
               PHB_ITEM s = hb_itemPutC( NULL, row[0] );
               hb_arrayAddForward( aRet, s );
               hb_itemRelease( s );
            }
         }
         mysql_free_result( res );
      }
   }
   hb_itemReturnRelease( aRet );
}
#endif /* HB_NO_MYSQL */
