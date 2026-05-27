/*
 * cocoa_pgsql.c - libpq bindings for HbBuilder TPostgreSQL class
 *
 *   HBPGSQL_OPEN ( cHost, cUser, cPass, cDB, nPort ) -> nHandle | 0
 *   HBPGSQL_CLOSE( nHandle )
 *   HBPGSQL_EXEC ( nHandle, cSQL )                  -> lOk
 *   HBPGSQL_QUERY( nHandle, cSQL )                  -> aRows
 *   HBPGSQL_FIELDS(nHandle, cSQL )                  -> aFieldNames
 *   HBPGSQL_ERROR( nHandle )                        -> cMsg
 *   HBPGSQL_LASTID(nHandle, cSeq )                  -> nId  (uses CURRVAL)
 *   HBPGSQL_TABLES(nHandle )                        -> aTableNames
 */

#include <hbapi.h>
#include <hbapiitm.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#ifdef HB_NO_PGSQL
/* No-op stubs when libpq headers/libs are unavailable. classes.prg declares
   EXTERNAL HBPGSQL_* on macOS, so every entry point must link. */
HB_FUNC( HBPGSQL_OPEN )   { hb_retnint( 0 ); }
HB_FUNC( HBPGSQL_CLOSE )  { }
HB_FUNC( HBPGSQL_EXEC )   { hb_retl( 0 ); }
HB_FUNC( HBPGSQL_QUERY )  { hb_reta( 0 ); }
HB_FUNC( HBPGSQL_FIELDS ) { hb_reta( 0 ); }
HB_FUNC( HBPGSQL_ERROR )  { hb_retc( "pgsql disabled at build (HB_NO_PGSQL)" ); }
HB_FUNC( HBPGSQL_LASTID ) { hb_retnint( 0 ); }
HB_FUNC( HBPGSQL_TABLES ) { hb_reta( 0 ); }
#else
#include <libpq-fe.h>

HB_FUNC( HBPGSQL_OPEN )
{
   const char * host = HB_ISCHAR(1) ? hb_parc(1) : "127.0.0.1";
   const char * user = HB_ISCHAR(2) ? hb_parc(2) : "postgres";
   const char * pass = HB_ISCHAR(3) ? hb_parc(3) : "";
   const char * db   = HB_ISCHAR(4) ? hb_parc(4) : "postgres";
   int port          = HB_ISNUM(5) ? hb_parni(5) : 5432;

   char conninfo[1024];
   snprintf( conninfo, sizeof(conninfo),
      "host=%s port=%d user=%s password=%s dbname=%s "
      "client_encoding=UTF8 connect_timeout=5",
      host, port, user, pass, db );

   PGconn * c = PQconnectdb( conninfo );
   if( !c || PQstatus( c ) != CONNECTION_OK ) {
      if( c ) PQfinish( c );
      hb_retnint(0);
      return;
   }
   hb_retnint( (HB_PTRUINT) c );
}

HB_FUNC( HBPGSQL_CLOSE )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   if( c ) PQfinish( c );
}

HB_FUNC( HBPGSQL_EXEC )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   if( !c || !sql ) { hb_retl(0); return; }

   PGresult * r = PQexec( c, sql );
   ExecStatusType st = PQresultStatus( r );
   int ok = ( st == PGRES_COMMAND_OK || st == PGRES_TUPLES_OK );
   PQclear( r );
   hb_retl( ok );
}

static void rows_to_array( PGconn * c, const char * sql, PHB_ITEM aRet, PHB_ITEM aFields )
{
   PGresult * r = PQexec( c, sql );
   ExecStatusType st = PQresultStatus( r );
   if( st != PGRES_TUPLES_OK && st != PGRES_COMMAND_OK ) { PQclear(r); return; }

   int nCols = PQnfields( r );
   int nRows = PQntuples( r );

   if( aFields ) {
      for( int i = 0; i < nCols; i++ ) {
         const char * n = PQfname( r, i );
         PHB_ITEM s = hb_itemPutC( NULL, n ? n : "" );
         hb_arrayAddForward( aFields, s );
         hb_itemRelease( s );
      }
   }

   if( aRet ) {
      for( int row = 0; row < nRows; row++ ) {
         PHB_ITEM aRow = hb_itemArrayNew( nCols );
         for( int col = 0; col < nCols; col++ ) {
            if( PQgetisnull( r, row, col ) ) {
               hb_arraySetC( aRow, col + 1, "" );
            } else {
               const char * v = PQgetvalue( r, row, col );
               int len = PQgetlength( r, row, col );
               hb_arraySetCL( aRow, col + 1, v, len );
            }
         }
         hb_arrayAddForward( aRet, aRow );
         hb_itemRelease( aRow );
      }
   }
   PQclear( r );
}

HB_FUNC( HBPGSQL_QUERY )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( c && sql ) rows_to_array( c, sql, aRet, NULL );
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBPGSQL_FIELDS )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( c && sql ) rows_to_array( c, sql, NULL, aRet );
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBPGSQL_ERROR )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   hb_retc( c ? PQerrorMessage( c ) : "" );
}

HB_FUNC( HBPGSQL_LASTID )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   const char * seq = HB_ISCHAR(2) ? hb_parc(2) : NULL;
   if( !c || !seq ) { hb_retnint(0); return; }
   char sql[512];
   snprintf( sql, sizeof(sql), "SELECT CURRVAL('%s')", seq );
   PGresult * r = PQexec( c, sql );
   long long id = 0;
   if( PQresultStatus(r) == PGRES_TUPLES_OK && PQntuples(r) > 0 ) {
      const char * v = PQgetvalue( r, 0, 0 );
      if( v ) id = atoll( v );
   }
   PQclear( r );
   hb_retnint( id );
}

HB_FUNC( HBPGSQL_TABLES )
{
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( c ) {
      PGresult * r = PQexec( c,
         "SELECT tablename FROM pg_catalog.pg_tables "
         "WHERE schemaname NOT IN ('pg_catalog','information_schema') "
         "ORDER BY tablename" );
      if( PQresultStatus(r) == PGRES_TUPLES_OK ) {
         int n = PQntuples( r );
         for( int i = 0; i < n; i++ ) {
            const char * v = PQgetvalue( r, i, 0 );
            PHB_ITEM s = hb_itemPutC( NULL, v ? v : "" );
            hb_arrayAddForward( aRet, s );
            hb_itemRelease( s );
         }
      }
      PQclear( r );
   }
   hb_itemReturnRelease( aRet );
}
#endif /* HB_NO_PGSQL */
