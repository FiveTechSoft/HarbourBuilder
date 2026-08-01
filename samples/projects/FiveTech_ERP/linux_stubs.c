/* linux_stubs.c — stubs so FiveTech_ERP links without MySQL/PostgreSQL/HIX contrib libs.
 * GTK3 + WebKitGTK are used natively; only the missing optional symbols are stubbed. */
#include "hbapi.h"

/* GT GUI stub — request HB_GT_GUI_DEFAULT from main.prg but provide empty body
 * so it links; the GTK3 backend already drives the GUI loop. */
HB_FUNC( HB_GT_GUI_DEFAULT ) {}

/* Code editor runtime hooks (unused outside IDE) */
void CE_DebugForceStop( void ) {}
int  CE_IsInDebugPauseLoop( void ) { return 0; }
void CE_NotifyRunLoopEnded( void ) {}
void CE_RequestAppStop( void ) {}

/* Stub optional DB / HIX / dialog / report symbols referenced by classes.prg */
#define STUB0( n ) HB_FUNC( n ) {}
#define STUBN( n ) HB_FUNC( n ) { hb_retni( 0 ); }
#define STUBC( n ) HB_FUNC( n ) { hb_retc( "" ); }
#define STUBL( n ) HB_FUNC( n ) { hb_retl( 0 ); }

STUB0( HBMYSQL_CLOSE )
STUBC( HBMYSQL_ERROR )
STUBN( HBMYSQL_EXEC )
STUB0( HBMYSQL_FIELDS )
STUBN( HBMYSQL_LASTID )
STUBN( HBMYSQL_OPEN )
STUB0( HBMYSQL_QUERY )
STUB0( HBMYSQL_TABLES )

STUB0( HBPGSQL_CLOSE )
STUBC( HBPGSQL_ERROR )
STUBN( HBPGSQL_EXEC )
STUB0( HBPGSQL_FIELDS )
STUBN( HBPGSQL_LASTID )
STUBN( HBPGSQL_OPEN )
STUB0( HBPGSQL_QUERY )
STUB0( HBPGSQL_TABLES )

STUBC( HIX_RESOLVEPATH )
