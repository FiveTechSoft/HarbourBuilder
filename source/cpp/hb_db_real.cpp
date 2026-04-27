// hb_db_real.cpp - Real HBMYSQL_x / HBPGSQL_x impl for Windows builds
//
// Uses runtime LoadLibrary so the correct arch DLL is picked automatically:
//   32-bit exe -> bin\libmysql.dll
//   64-bit exe -> bin\libmysql64.dll
// PostgreSQL: bin\libpq.dll (any arch). Falls back to PostgreSQL install path.
//
// No .lib import library is linked. If the DLL is missing or symbols can't
// be resolved, HBMYSQL_*/HBPGSQL_* return safe defaults (0/false/empty).
//
// Function signatures match libmysqlclient (mysql.h) and libpq (libpq-fe.h)
// exactly so any libmysql.dll / libpq.dll is binary-compatible.

#include <windows.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern "C" {
#include <hbapi.h>
#include <hbapiitm.h>
}

// ============================================================
// MySQL — runtime-loaded libmysql.dll / libmysql64.dll
// ============================================================

typedef struct st_mysql       MYSQL;
typedef struct st_mysql_res   MYSQL_RES;
typedef struct st_mysql_field MYSQL_FIELD;
typedef char ** MYSQL_ROW;

typedef MYSQL *      (__stdcall *PFN_mysql_init)            ( MYSQL * );
typedef MYSQL *      (__stdcall *PFN_mysql_real_connect)    ( MYSQL *, const char *, const char *, const char *, const char *, unsigned int, const char *, unsigned long );
typedef void         (__stdcall *PFN_mysql_close)           ( MYSQL * );
typedef int          (__stdcall *PFN_mysql_query)           ( MYSQL *, const char * );
typedef MYSQL_RES *  (__stdcall *PFN_mysql_store_result)    ( MYSQL * );
typedef void         (__stdcall *PFN_mysql_free_result)     ( MYSQL_RES * );
typedef unsigned int (__stdcall *PFN_mysql_num_fields)      ( MYSQL_RES * );
typedef MYSQL_ROW    (__stdcall *PFN_mysql_fetch_row)       ( MYSQL_RES * );
typedef unsigned long * (__stdcall *PFN_mysql_fetch_lengths)( MYSQL_RES * );
typedef MYSQL_FIELD * (__stdcall *PFN_mysql_fetch_field)    ( MYSQL_RES * );
typedef void         (__stdcall *PFN_mysql_field_seek)      ( MYSQL_RES *, unsigned int );
typedef const char * (__stdcall *PFN_mysql_error)           ( MYSQL * );
typedef unsigned long long (__stdcall *PFN_mysql_insert_id) ( MYSQL * );
typedef MYSQL_RES *  (__stdcall *PFN_mysql_list_tables)     ( MYSQL *, const char * );
typedef int          (__stdcall *PFN_mysql_set_character_set)( MYSQL *, const char * );

static struct {
   HMODULE h;
   PFN_mysql_init             init;
   PFN_mysql_real_connect     real_connect;
   PFN_mysql_close            close;
   PFN_mysql_query            query;
   PFN_mysql_store_result     store_result;
   PFN_mysql_free_result      free_result;
   PFN_mysql_num_fields       num_fields;
   PFN_mysql_fetch_row        fetch_row;
   PFN_mysql_fetch_lengths    fetch_lengths;
   PFN_mysql_fetch_field      fetch_field;
   PFN_mysql_field_seek       field_seek;
   PFN_mysql_error            error;
   PFN_mysql_insert_id        insert_id;
   PFN_mysql_list_tables      list_tables;
   PFN_mysql_set_character_set set_character_set;
} g_my = { 0 };

static int my_load( void )
{
   if( g_my.h ) return 1;
   const char * dll = ( sizeof(void*) == 8 ) ? "libmysql64.dll" : "libmysql.dll";
   g_my.h = LoadLibraryA( dll );
   if( ! g_my.h ) g_my.h = LoadLibraryA( "libmysql.dll" );  // fallback
   if( ! g_my.h ) return 0;

   #define MY_GET(name) g_my.name = (PFN_mysql_##name) GetProcAddress( g_my.h, "mysql_" #name )
   MY_GET(init); MY_GET(real_connect); MY_GET(close); MY_GET(query);
   MY_GET(store_result); MY_GET(free_result); MY_GET(num_fields);
   MY_GET(fetch_row); MY_GET(fetch_lengths); MY_GET(fetch_field);
   MY_GET(field_seek); MY_GET(error); MY_GET(insert_id);
   MY_GET(list_tables); MY_GET(set_character_set);
   #undef MY_GET

   if( !g_my.init || !g_my.real_connect || !g_my.close || !g_my.query ) {
      FreeLibrary( g_my.h ); g_my.h = NULL; return 0;
   }
   return 1;
}

extern "C" {

HB_FUNC( HBMYSQL_OPEN )
{
   if( ! my_load() ) { hb_retnint(0); return; }

   const char * host = HB_ISCHAR(1) ? hb_parc(1) : "127.0.0.1";
   const char * user = HB_ISCHAR(2) ? hb_parc(2) : "root";
   const char * pass = HB_ISCHAR(3) ? hb_parc(3) : "";
   const char * db   = HB_ISCHAR(4) ? hb_parc(4) : NULL;
   unsigned int port = HB_ISNUM(5) ? (unsigned int) hb_parni(5) : 3306;

   MYSQL * h = g_my.init( NULL );
   if( ! h ) { hb_retnint(0); return; }
   if( ! g_my.real_connect( h, host, user, pass, db, port, NULL, 0 ) ) {
      g_my.close( h ); hb_retnint(0); return;
   }
   if( g_my.set_character_set ) g_my.set_character_set( h, "utf8mb4" );
   hb_retnint( (HB_PTRUINT) h );
}

HB_FUNC( HBMYSQL_CLOSE )
{
   if( ! g_my.h ) return;
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   if( h ) g_my.close( h );
}

HB_FUNC( HBMYSQL_EXEC )
{
   if( ! g_my.h ) { hb_retl(0); return; }
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   if( !h || !sql ) { hb_retl(0); return; }
   if( g_my.query( h, sql ) != 0 ) { hb_retl(0); return; }
   MYSQL_RES * res = g_my.store_result( h );
   if( res ) g_my.free_result( res );
   hb_retl(1);
}

}

static void my_rows_to_array( MYSQL * h, const char * sql, PHB_ITEM aRet, PHB_ITEM aFields )
{
   if( g_my.query( h, sql ) != 0 ) return;
   MYSQL_RES * res = g_my.store_result( h );
   if( !res ) return;

   unsigned int nCols = g_my.num_fields( res );

   if( aFields && g_my.fetch_field && g_my.field_seek ) {
      MYSQL_FIELD * f;
      g_my.field_seek( res, 0 );
      while( ( f = g_my.fetch_field( res ) ) ) {
         // MYSQL_FIELD layout: char *name is at offset 0 in stable ABI
         const char * nm = *(const char **) f;
         PHB_ITEM s = hb_itemPutC( NULL, nm ? nm : "" );
         hb_arrayAddForward( aFields, s );
         hb_itemRelease( s );
      }
   }

   if( aRet ) {
      MYSQL_ROW row;
      while( ( row = g_my.fetch_row( res ) ) ) {
         unsigned long * lens = g_my.fetch_lengths ? g_my.fetch_lengths( res ) : NULL;
         PHB_ITEM aRow = hb_itemArrayNew( nCols );
         for( unsigned int i = 0; i < nCols; i++ ) {
            if( row[i] )
               hb_arraySetCL( aRow, i + 1, row[i], lens ? (HB_SIZE) lens[i] : (HB_SIZE) strlen( row[i] ) );
            else
               hb_arraySetC( aRow, i + 1, "" );
         }
         hb_arrayAddForward( aRet, aRow );
         hb_itemRelease( aRow );
      }
   }
   g_my.free_result( res );
}

extern "C" {

HB_FUNC( HBMYSQL_QUERY )
{
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( g_my.h ) {
      MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
      const char * sql = hb_parc(2);
      if( h && sql ) my_rows_to_array( h, sql, aRet, NULL );
   }
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBMYSQL_FIELDS )
{
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( g_my.h ) {
      MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
      const char * sql = hb_parc(2);
      if( h && sql ) my_rows_to_array( h, sql, NULL, aRet );
   }
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBMYSQL_ERROR )
{
   if( ! g_my.h ) { hb_retc( "libmysql.dll not loaded" ); return; }
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   const char * s = h ? g_my.error( h ) : NULL;
   hb_retc( s ? s : "" );
}

HB_FUNC( HBMYSQL_LASTID )
{
   if( ! g_my.h ) { hb_retnint(0); return; }
   MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
   hb_retnint( h ? (HB_LONGLONG) g_my.insert_id( h ) : 0 );
}

HB_FUNC( HBMYSQL_TABLES )
{
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( g_my.h ) {
      MYSQL * h = (MYSQL *) (HB_PTRUINT) hb_parnint(1);
      if( h && g_my.list_tables ) {
         MYSQL_RES * res = g_my.list_tables( h, NULL );
         if( res ) {
            MYSQL_ROW row;
            while( ( row = g_my.fetch_row( res ) ) ) {
               if( row[0] ) {
                  PHB_ITEM s = hb_itemPutC( NULL, row[0] );
                  hb_arrayAddForward( aRet, s );
                  hb_itemRelease( s );
               }
            }
            g_my.free_result( res );
         }
      }
   }
   hb_itemReturnRelease( aRet );
}

}

// ============================================================
// PostgreSQL — runtime-loaded libpq.dll
// ============================================================

typedef struct pg_conn   PGconn;
typedef struct pg_result PGresult;
typedef enum { PGRES_EMPTY_QUERY=0, PGRES_COMMAND_OK, PGRES_TUPLES_OK,
   PGRES_COPY_OUT, PGRES_COPY_IN, PGRES_BAD_RESPONSE,
   PGRES_NONFATAL_ERROR, PGRES_FATAL_ERROR } ExecStatusType;
typedef enum { CONNECTION_OK=0, CONNECTION_BAD } ConnStatusType;

typedef PGconn *       (__cdecl *PFN_PQconnectdb)    ( const char * );
typedef void           (__cdecl *PFN_PQfinish)       ( PGconn * );
typedef ConnStatusType (__cdecl *PFN_PQstatus)       ( const PGconn * );
typedef PGresult *     (__cdecl *PFN_PQexec)         ( PGconn *, const char * );
typedef ExecStatusType (__cdecl *PFN_PQresultStatus) ( const PGresult * );
typedef void           (__cdecl *PFN_PQclear)        ( PGresult * );
typedef int            (__cdecl *PFN_PQnfields)      ( const PGresult * );
typedef int            (__cdecl *PFN_PQntuples)      ( const PGresult * );
typedef char *         (__cdecl *PFN_PQfname)        ( const PGresult *, int );
typedef int            (__cdecl *PFN_PQgetisnull)    ( const PGresult *, int, int );
typedef char *         (__cdecl *PFN_PQgetvalue)     ( const PGresult *, int, int );
typedef int            (__cdecl *PFN_PQgetlength)    ( const PGresult *, int, int );
typedef char *         (__cdecl *PFN_PQerrorMessage) ( const PGconn * );

static struct {
   HMODULE h;
   PFN_PQconnectdb    connectdb;
   PFN_PQfinish       finish;
   PFN_PQstatus       status;
   PFN_PQexec         exec;
   PFN_PQresultStatus resultStatus;
   PFN_PQclear        clear;
   PFN_PQnfields      nfields;
   PFN_PQntuples      ntuples;
   PFN_PQfname        fname;
   PFN_PQgetisnull    getisnull;
   PFN_PQgetvalue     getvalue;
   PFN_PQgetlength    getlength;
   PFN_PQerrorMessage errorMessage;
} g_pg = { 0 };

static int pg_load( void )
{
   if( g_pg.h ) return 1;
   g_pg.h = LoadLibraryA( "libpq.dll" );
   if( ! g_pg.h ) g_pg.h = LoadLibraryA( "C:\\Program Files\\PostgreSQL\\18\\bin\\libpq.dll" );
   if( ! g_pg.h ) return 0;

   #define PG_GET(name) g_pg.name = (PFN_PQ##name) GetProcAddress( g_pg.h, "PQ" #name )
   PG_GET(connectdb); PG_GET(finish); PG_GET(status); PG_GET(exec);
   PG_GET(resultStatus); PG_GET(clear); PG_GET(nfields); PG_GET(ntuples);
   PG_GET(fname); PG_GET(getisnull); PG_GET(getvalue); PG_GET(getlength);
   PG_GET(errorMessage);
   #undef PG_GET

   if( !g_pg.connectdb || !g_pg.exec || !g_pg.finish ) {
      FreeLibrary( g_pg.h ); g_pg.h = NULL; return 0;
   }
   return 1;
}

extern "C" {

HB_FUNC( HBPGSQL_OPEN )
{
   if( ! pg_load() ) { hb_retnint(0); return; }
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

   PGconn * c = g_pg.connectdb( conninfo );
   if( !c || g_pg.status( c ) != CONNECTION_OK ) {
      if( c ) g_pg.finish( c );
      hb_retnint(0); return;
   }
   hb_retnint( (HB_PTRUINT) c );
}

HB_FUNC( HBPGSQL_CLOSE )
{
   if( ! g_pg.h ) return;
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   if( c ) g_pg.finish( c );
}

HB_FUNC( HBPGSQL_EXEC )
{
   if( ! g_pg.h ) { hb_retl(0); return; }
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   const char * sql = hb_parc(2);
   if( !c || !sql ) { hb_retl(0); return; }
   PGresult * r = g_pg.exec( c, sql );
   ExecStatusType st = g_pg.resultStatus( r );
   int ok = ( st == PGRES_COMMAND_OK || st == PGRES_TUPLES_OK );
   g_pg.clear( r );
   hb_retl( ok );
}

}

static void pg_rows_to_array( PGconn * c, const char * sql, PHB_ITEM aRet, PHB_ITEM aFields )
{
   PGresult * r = g_pg.exec( c, sql );
   ExecStatusType st = g_pg.resultStatus( r );
   if( st != PGRES_TUPLES_OK && st != PGRES_COMMAND_OK ) { g_pg.clear(r); return; }

   int nCols = g_pg.nfields( r );
   int nRows = g_pg.ntuples( r );

   if( aFields ) {
      for( int i = 0; i < nCols; i++ ) {
         const char * n = g_pg.fname( r, i );
         PHB_ITEM s = hb_itemPutC( NULL, n ? n : "" );
         hb_arrayAddForward( aFields, s );
         hb_itemRelease( s );
      }
   }

   if( aRet ) {
      for( int row = 0; row < nRows; row++ ) {
         PHB_ITEM aRow = hb_itemArrayNew( nCols );
         for( int col = 0; col < nCols; col++ ) {
            if( g_pg.getisnull( r, row, col ) ) {
               hb_arraySetC( aRow, col + 1, "" );
            } else {
               const char * v = g_pg.getvalue( r, row, col );
               int len = g_pg.getlength( r, row, col );
               hb_arraySetCL( aRow, col + 1, v, (HB_SIZE) len );
            }
         }
         hb_arrayAddForward( aRet, aRow );
         hb_itemRelease( aRow );
      }
   }
   g_pg.clear( r );
}

extern "C" {

HB_FUNC( HBPGSQL_QUERY )
{
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( g_pg.h ) {
      PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
      const char * sql = hb_parc(2);
      if( c && sql ) pg_rows_to_array( c, sql, aRet, NULL );
   }
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBPGSQL_FIELDS )
{
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( g_pg.h ) {
      PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
      const char * sql = hb_parc(2);
      if( c && sql ) pg_rows_to_array( c, sql, NULL, aRet );
   }
   hb_itemReturnRelease( aRet );
}

HB_FUNC( HBPGSQL_ERROR )
{
   if( ! g_pg.h ) { hb_retc( "libpq.dll not loaded" ); return; }
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   hb_retc( c ? g_pg.errorMessage( c ) : "" );
}

HB_FUNC( HBPGSQL_LASTID )
{
   if( ! g_pg.h ) { hb_retnint(0); return; }
   PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
   const char * seq = HB_ISCHAR(2) ? hb_parc(2) : NULL;
   if( !c || !seq ) { hb_retnint(0); return; }
   char sql[512];
   snprintf( sql, sizeof(sql), "SELECT CURRVAL('%s')", seq );
   PGresult * r = g_pg.exec( c, sql );
   long long id = 0;
   if( g_pg.resultStatus(r) == PGRES_TUPLES_OK && g_pg.ntuples(r) > 0 ) {
      const char * v = g_pg.getvalue( r, 0, 0 );
      if( v ) id = atoll( v );
   }
   g_pg.clear( r );
   hb_retnint( id );
}

HB_FUNC( HBPGSQL_TABLES )
{
   PHB_ITEM aRet = hb_itemArrayNew(0);
   if( g_pg.h ) {
      PGconn * c = (PGconn *) (HB_PTRUINT) hb_parnint(1);
      if( c ) {
         PGresult * r = g_pg.exec( c,
            "SELECT tablename FROM pg_catalog.pg_tables "
            "WHERE schemaname NOT IN ('pg_catalog','information_schema') "
            "ORDER BY tablename" );
         if( g_pg.resultStatus(r) == PGRES_TUPLES_OK ) {
            int n = g_pg.ntuples( r );
            for( int i = 0; i < n; i++ ) {
               const char * v = g_pg.getvalue( r, i, 0 );
               PHB_ITEM s = hb_itemPutC( NULL, v ? v : "" );
               hb_arrayAddForward( aRet, s );
               hb_itemRelease( s );
            }
         }
         g_pg.clear( r );
      }
   }
   hb_itemReturnRelease( aRet );
}

}
