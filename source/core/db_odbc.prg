// db_odbc.prg - database base class + universal ODBC backend.
// #included by classes.prg; also compiles standalone (UI-free) for the smoke.
//
// TODBCDatabase fills the former Firebird/SQLServer/Oracle stubs through one
// ODBC path (Harbour's hbodbc low-level SQL* API). Named TODBCDatabase (NOT
// TODBC) because hbodbc.lib already exports HB_FUN_TODBC.

#include "hbclass.ch"   // idempotent (guarded); needed when compiled standalone

// --- ODBC constants (sql.ch is not on the portable include path) ---
#define SQL_SUCCESS             0
#define SQL_SUCCESS_WITH_INFO   1
#define SQL_NO_DATA             100
#define SQL_DRIVER_NOPROMPT     0
#define SQL_FREESTMT_CLOSE      0
#define SQL_FREESTMT_DROP       1
#define SQL_C_CHAR              1
#define SQL_C_DOUBLE            8

//----------------------------------------------------------------------------//
// TDatabase - Abstract base class for all database connections
//----------------------------------------------------------------------------//

CLASS TDatabase

   DATA cServer     INIT ""        // Host/server name
   DATA nPort       INIT 0         // Port number
   DATA cDatabase   INIT ""        // Database name or file path
   DATA cUser       INIT ""        // Username
   DATA cPassword   INIT ""        // Password
   DATA cCharSet    INIT "UTF8"    // Character set
   DATA lConnected  INIT .F.       // Connection status
   DATA cLastError  INIT ""        // Last error message
   DATA pHandle     INIT nil       // Native connection handle
   DATA cDriver     INIT ""        // Driver name (for identification)

   METHOD New() CONSTRUCTOR
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD TableExists( cTable )
   METHOD Tables()
   METHOD LastError()
   METHOD IsConnected()

ENDCLASS

METHOD New() CLASS TDatabase
return Self

METHOD Open() CLASS TDatabase
   ::cLastError := "Abstract: override Open() in subclass"
return .F.

METHOD Close() CLASS TDatabase
   ::lConnected := .F.
   ::pHandle := nil
return nil

METHOD Execute( cSQL ) CLASS TDatabase
   HB_SYMBOL_UNUSED( cSQL )
   ::cLastError := "Abstract: override Execute() in subclass"
return .F.

METHOD Query( cSQL ) CLASS TDatabase
   HB_SYMBOL_UNUSED( cSQL )
   ::cLastError := "Abstract: override Query() in subclass"
return {}

METHOD TableExists( cTable ) CLASS TDatabase
   HB_SYMBOL_UNUSED( cTable )
return .F.

METHOD Tables() CLASS TDatabase
return {}

METHOD LastError() CLASS TDatabase
return ::cLastError

METHOD IsConnected() CLASS TDatabase
return ::lConnected

//----------------------------------------------------------------------------//
// TODBCDatabase - generic ODBC connection via hbodbc low-level SQL*
//----------------------------------------------------------------------------//
CLASS TODBCDatabase INHERIT TDatabase

   DATA cConnString INIT ""
   DATA pHEnv       INIT nil
   DATA pHDbc       INIT nil
   DATA cTable      INIT ""
   DATA cSQL        INIT ""
   DATA aRows       INIT {}
   DATA aFieldNames INIT {}
   DATA nRecord     INIT 0
   DATA bOnConnect    INIT nil
   DATA bOnDisconnect INIT nil
   DATA bOnError      INIT nil

   METHOD New() CONSTRUCTOR
   METHOD BuildConnString()
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD TableExists( cTable )
   METHOD Tables()
   METHOD LoadCursor()
   METHOD FieldCount()
   METHOD FieldName( n )
   METHOD GoTop()
   METHOD Eof()
   METHOD FieldGet( n )
   METHOD Skip( n )
   METHOD FireError( cMsg )
   METHOD LastDiag()

ENDCLASS

METHOD New() CLASS TODBCDatabase
   ::cDriver := "ODBC"
   return Self

METHOD FireError( cMsg ) CLASS TODBCDatabase
   ::cLastError := cMsg
   if ::bOnError != nil
      Eval( ::bOnError, cMsg )
   endif
   return Self

METHOD LastDiag() CLASS TODBCDatabase
   local cState := Space( 16 ), nNative := 0, cText := Space( 512 )
   SQLError( ::pHEnv, ::pHDbc, nil, @cState, @nNative, @cText )
   return AllTrim( cState ) + ": " + AllTrim( cText )

METHOD BuildConnString() CLASS TODBCDatabase
   // Task 2 fills the per-dialect templates; base returns cConnString as-is.
   return ::cConnString

METHOD Open() CLASS TODBCDatabase
   local hEnv := nil, hDbc := nil, nRet, cOut := Space( 1024 )
   if SQLAllocEnv( @hEnv ) != SQL_SUCCESS
      ::FireError( "ODBC: cannot allocate environment" ); return .F.
   endif
   if SQLAllocConnect( hEnv, @hDbc ) != SQL_SUCCESS
      ::FireError( "ODBC: cannot allocate connection" ); SQLFreeEnv( hEnv ); return .F.
   endif
   nRet := SQLDriverConnect( hDbc, ::BuildConnString(), @cOut, SQL_DRIVER_NOPROMPT )
   if nRet != SQL_SUCCESS .and. nRet != SQL_SUCCESS_WITH_INFO
      ::pHEnv := hEnv ; ::pHDbc := hDbc
      ::FireError( "ODBC connect failed: " + ::LastDiag() )
      SQLDisconnect( hDbc ) ; SQLFreeConnect( hDbc ) ; SQLFreeEnv( hEnv )
      ::pHEnv := nil ; ::pHDbc := nil
      return .F.
   endif
   ::pHEnv := hEnv
   ::pHDbc := hDbc
   ::lConnected := .T.
   if ::bOnConnect != nil ; Eval( ::bOnConnect ) ; endif
   return .T.

METHOD Close() CLASS TODBCDatabase
   if ::pHDbc != nil
      SQLDisconnect( ::pHDbc )
      SQLFreeConnect( ::pHDbc )
   endif
   if ::pHEnv != nil
      SQLFreeEnv( ::pHEnv )
   endif
   ::pHDbc := nil ; ::pHEnv := nil
   ::lConnected := .F.
   if ::bOnDisconnect != nil ; Eval( ::bOnDisconnect ) ; endif
   return nil

// Each operation uses its OWN fresh statement handle (allocated + dropped here).
// A shared/reused handle hits a dBase/Jet quirk where a SELECT re-executed on a
// handle that previously ran a SELECT returns no rows even after SQL_CLOSE.
METHOD Execute( cSQL ) CLASS TODBCDatabase
   local hStmt := nil, nRet
   if ! ::lConnected ; ::FireError( "Not connected" ) ; return .F. ; endif
   if SQLAllocStmt( ::pHDbc, @hStmt ) != SQL_SUCCESS
      ::FireError( "ODBC: cannot allocate statement" ) ; return .F.
   endif
   nRet := SQLExecDirect( hStmt, cSQL )
   if nRet != SQL_SUCCESS .and. nRet != SQL_SUCCESS_WITH_INFO
      ::FireError( "ODBC exec failed: " + ::LastDiag() )
      SQLFreeStmt( hStmt, SQL_FREESTMT_DROP )
      return .F.
   endif
   SQLFreeStmt( hStmt, SQL_FREESTMT_DROP )
   return .T.

METHOD Query( cSQL ) CLASS TODBCDatabase
   local hStmt := nil, nRet, nCols := 0, i, aRow, xVal
   local cName, nNameLen, nType, nColSize, nDec, nNull
   local aTypes := {}
   ::aRows := {} ; ::aFieldNames := {} ; ::nRecord := 0
   if ! ::lConnected ; ::FireError( "Not connected" ) ; return {} ; endif
   if ! Empty( cSQL ) ; ::cSQL := cSQL ; endif
   if SQLAllocStmt( ::pHDbc, @hStmt ) != SQL_SUCCESS
      ::FireError( "ODBC: cannot allocate statement" ) ; return {}
   endif
   nRet := SQLExecDirect( hStmt, ::cSQL )
   if nRet != SQL_SUCCESS .and. nRet != SQL_SUCCESS_WITH_INFO
      ::FireError( "ODBC query failed: " + ::LastDiag() )
      SQLFreeStmt( hStmt, SQL_FREESTMT_DROP ) ; return {}
   endif
   SQLNumResultCols( hStmt, @nCols )
   for i := 1 to nCols
      cName := Space( 256 ) ; nNameLen := 0 ; nType := 0
      nColSize := 0 ; nDec := 0 ; nNull := 0
      SQLDescribeCol( hStmt, i, @cName, 256, @nNameLen, @nType, @nColSize, @nDec, @nNull )
      AAdd( ::aFieldNames, AllTrim( cName ) )
      AAdd( aTypes, nType )
   next
   do while ( nRet := SQLFetch( hStmt ) ) == SQL_SUCCESS .or. nRet == SQL_SUCCESS_WITH_INFO
      aRow := {}
      for i := 1 to nCols
         if _OdbcIsNumeric( aTypes[ i ] )
            xVal := nil
            SQLGetData( hStmt, i, SQL_C_DOUBLE, 0, @xVal )
         else
            xVal := Space( 4096 )
            SQLGetData( hStmt, i, SQL_C_CHAR, 4096, @xVal )
            xVal := RTrim( xVal )
         endif
         AAdd( aRow, xVal )
      next
      AAdd( ::aRows, aRow )
   enddo
   SQLFreeStmt( hStmt, SQL_FREESTMT_DROP )
   ::nRecord := iif( Len( ::aRows ) > 0, 1, 0 )
   return ::aRows

METHOD LoadCursor() CLASS TODBCDatabase
   local cQuery := iif( ! Empty( ::cSQL ), ::cSQL, ;
                  iif( ! Empty( ::cTable ), "SELECT * FROM " + ::cTable, "" ) )
   if Empty( cQuery ) ; return Self ; endif
   ::Query( cQuery )
   return Self

METHOD FieldCount() CLASS TODBCDatabase
   return Len( ::aFieldNames )

METHOD FieldName( n ) CLASS TODBCDatabase
   return iif( n >= 1 .and. n <= Len( ::aFieldNames ), ::aFieldNames[ n ], "" )

METHOD GoTop() CLASS TODBCDatabase
   ::nRecord := iif( Len( ::aRows ) > 0, 1, 0 )
   return Self

METHOD Eof() CLASS TODBCDatabase
   return ::nRecord == 0 .or. ::nRecord > Len( ::aRows )

METHOD FieldGet( n ) CLASS TODBCDatabase
   if ! ::Eof() .and. n >= 1 .and. n <= Len( ::aRows[ ::nRecord ] )
      return ::aRows[ ::nRecord ][ n ]
   endif
   return nil

METHOD Skip( n ) CLASS TODBCDatabase
   hb_default( @n, 1 )
   ::nRecord += n
   if ::nRecord < 1 ; ::nRecord := 1 ; endif
   return Self

METHOD TableExists( cTable ) CLASS TODBCDatabase
   // Probe with a zero-row SELECT on a fresh statement (this hbodbc build does
   // not export SQLTables). Does not touch ::aRows / ::cLastError.
   local hStmt := nil, nRet, lOk
   if ! ::lConnected ; return .F. ; endif
   if SQLAllocStmt( ::pHDbc, @hStmt ) != SQL_SUCCESS ; return .F. ; endif
   nRet := SQLExecDirect( hStmt, "SELECT * FROM " + cTable + " WHERE 1 = 0" )
   lOk  := ( nRet == SQL_SUCCESS .or. nRet == SQL_SUCCESS_WITH_INFO )
   SQLFreeStmt( hStmt, SQL_FREESTMT_DROP )
   return lOk

METHOD Tables() CLASS TODBCDatabase
   // Generic table enumeration needs the ODBC catalog API (SQLTables), which is
   // NOT exported by this hbodbc build -> returns empty. Callers that need a
   // table list should use a dialect-specific catalog query via Query().
   return {}

// Numeric SQL type codes (ANSI): NUMERIC 2, DECIMAL 3, INTEGER 4, SMALLINT 5,
// FLOAT 6, REAL 7, DOUBLE 8, BIGINT -5, TINYINT -6, BIT -7.
STATIC FUNCTION _OdbcIsNumeric( nType )
   return nType == 2 .or. nType == 3 .or. nType == 4 .or. nType == 5 .or. ;
          nType == 6 .or. nType == 7 .or. nType == 8 .or. ;
          nType == -5 .or. nType == -6 .or. nType == -7
