/* mac_stubs.c — weak stubs so FiveTech_ERP links without full IDE extras.
 * Same PRG set as Windows; only this file is macOS-specific at link time. */
#include "hbapi.h"

/* GT stubs only if not provided by Harbour libs (gtnul/gttrm/...). */
/* Do NOT stub HB_GT_NUL — REQUEST HB_GT_NUL pulls it from Harbour. */
HB_FUNC( HB_GT_GUI_DEFAULT ) {}
/* HB_GT_TRM comes from libgttrm when linked */

/* Code editor runtime hooks used by cocoa_core window close */
void CE_DebugForceStop( void ) {}
int  CE_IsInDebugPauseLoop( void ) { return 0; }
void CE_NotifyRunLoopEnded( void ) {}
void CE_RequestAppStop( void ) {}

/* Optional DB / HIX / dialog / report symbols referenced by classes.prg */
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

STUBN( SQLITE3_COLUMN_COUNT )
STUBC( SQLITE3_COLUMN_NAME )
STUBC( SQLITE3_COLUMN_TEXT )
STUBC( SQLITE3_ERRMSG )
STUBN( SQLITE3_EXEC )
STUB0( SQLITE3_FINALIZE )
STUBN( SQLITE3_OPEN )
STUBN( SQLITE3_PREPARE )
STUBN( SQLITE3_STEP )

STUBC( HIX_RESOLVEPATH )
STUB0( HIX_EXECPRG )
STUB0( HIX_SERVESTATIC )
STUB0( HIX_SETROOT )

STUBN( MAC_EXECCOLORDIALOG )
STUBN( MAC_EXECFONTDIALOG )
STUBC( MAC_EXECOPENDIALOG )
STUBC( MAC_EXECSAVEDIALOG )
/* MAC_RUNTIMEERRORDIALOG / MAC_APPTERMINATE live in cocoa_core.m */

STUB0( RPT_PREVIEWADDPAGE )
STUB0( RPT_PREVIEWDRAWRECT )
STUB0( RPT_PREVIEWDRAWTEXT )
STUB0( RPT_PREVIEWOPEN )
STUB0( RPT_PREVIEWRENDER )
