// Form1.prg - Database Browser
//
// A sample database browser demonstrating Harbour's xBase database commands.
// Shows how to open, navigate, add, delete, and search records in a DBF file.
// On first run it creates a sample "customers.dbf" with five records.
//
// xBase commands used:
//   USE, GO TOP, GO BOTTOM, SKIP, APPEND BLANK, DELETE, PACK, DBCREATE,
//   REPLACE, FIELD->, EOF(), BOF(), RECCOUNT(), RECNO(), LASTREC()

#include "hbbuilder.ch"

// ---------------------------------------------------------------------------
// Static variables - shared across all functions in this module
// ---------------------------------------------------------------------------
static oMemo              // The large memo/edit control showing record details
static oLblStatus         // Status label showing record position
static cDbfPath := ""     // Full path to the open DBF file
static cAlias  := ""      // Work area alias for the open table
static lDbfOpen := .f.    // Whether a DBF is currently open

// ---------------------------------------------------------------------------
// Form1Main() - Build and activate the Database Browser form
// ---------------------------------------------------------------------------
function Form1Main()

   local oForm, oToolbar
   local oBtnOpen, oBtnAdd, oBtnDel, oBtnSearch
   local oBtnFirst, oBtnPrev, oBtnNext, oBtnLast

   // --- Create the main form ---
   DEFINE FORM oForm TITLE "Database Browser" SIZE 700, 500 FONT "Segoe UI", 11

   // --- Toolbar with database operation buttons ---
   DEFINE TOOLBAR oToolbar OF oForm
      BUTTON "Open DBF"  OF oToolbar  TOOLTIP "Open or create a sample DBF file"  ACTION OpenDBF()
      SEPARATOR OF oToolbar
      BUTTON "Add"       OF oToolbar  TOOLTIP "Append a new blank record"         ACTION AddRecord()
      BUTTON "Delete"    OF oToolbar  TOOLTIP "Delete the current record"          ACTION DeleteRecord()
      SEPARATOR OF oToolbar
      BUTTON "Search"    OF oToolbar  TOOLTIP "Search for a record by name"        ACTION SearchRecord()
      SEPARATOR OF oToolbar
      BUTTON "First"     OF oToolbar  TOOLTIP "Go to the first record"             ACTION GoFirst()
      BUTTON "Prev"      OF oToolbar  TOOLTIP "Go to the previous record"          ACTION GoPrev()
      BUTTON "Next"      OF oToolbar  TOOLTIP "Go to the next record"              ACTION GoNext()
      BUTTON "Last"      OF oToolbar  TOOLTIP "Go to the last record"              ACTION GoLast()

   // --- Status label showing current position ---
   @ 45, 10 SAY oLblStatus PROMPT "No database open" OF oForm SIZE 680, 20

   // --- Large edit area for displaying record details ---
   // We use a tall GET (edit control) as a read-only display area
   @ 70, 10 GET oMemo VAR "" OF oForm SIZE 670, 380

   // --- Activate the form centered on screen ---
   ACTIVATE FORM oForm CENTERED

   // --- Clean up: close any open database before exiting ---
   if lDbfOpen
      ( cAlias )->( DbCloseArea() )
      lDbfOpen := .f.
   endif

   oForm:Destroy()

return nil

// ---------------------------------------------------------------------------
// OpenDBF() - Open (or create) the sample customers.dbf
//
// If the file does not exist, it is created with DBCREATE and populated
// with five sample records.  If it already exists, it is simply opened.
// ---------------------------------------------------------------------------
static function OpenDBF()

   local cDir, cFile
   local aStruct

   // Close any previously open table
   if lDbfOpen
      ( cAlias )->( DbCloseArea() )
      lDbfOpen := .f.
   endif

   // Build the path: same directory as the project
   // We use hb_DirBase() which returns the directory of the executable
   cDir  := hb_DirBase()
   cFile := cDir + "customers.dbf"

   // -----------------------------------------------------------------------
   // If the file does not exist, create it with DBCREATE
   // -----------------------------------------------------------------------
   if ! File( cFile )

      // Define the table structure as an array of field descriptors:
      //   { FieldName, Type, Width, Decimals }
      //
      //   C = Character, N = Numeric, D = Date, L = Logical, M = Memo
      aStruct := { ;
         { "NAME",   "C", 30, 0 }, ;
         { "CITY",   "C", 20, 0 }, ;
         { "PHONE",  "C", 15, 0 }, ;
         { "EMAIL",  "C", 40, 0 }, ;
         { "ACTIVE", "L",  1, 0 }  ;
      }

      // DBCREATE creates the physical .dbf file on disk
      DbCreate( cFile, aStruct )

      // Open the newly created table in an exclusive work area
      USE ( cFile ) ALIAS CUSTOMERS NEW EXCLUSIVE
      cAlias  := "CUSTOMERS"
      lDbfOpen := .t.

      // -----------------------------------------------------------------
      // Populate with five sample records using APPEND BLANK + REPLACE
      // -----------------------------------------------------------------
      APPEND BLANK
      REPLACE CUSTOMERS->NAME   WITH "Alice Johnson"
      REPLACE CUSTOMERS->CITY   WITH "New York"
      REPLACE CUSTOMERS->PHONE  WITH "212-555-0101"
      REPLACE CUSTOMERS->EMAIL  WITH "alice@example.com"
      REPLACE CUSTOMERS->ACTIVE WITH .t.

      APPEND BLANK
      REPLACE CUSTOMERS->NAME   WITH "Bob Smith"
      REPLACE CUSTOMERS->CITY   WITH "Los Angeles"
      REPLACE CUSTOMERS->PHONE  WITH "310-555-0202"
      REPLACE CUSTOMERS->EMAIL  WITH "bob@example.com"
      REPLACE CUSTOMERS->ACTIVE WITH .t.

      APPEND BLANK
      REPLACE CUSTOMERS->NAME   WITH "Carol Williams"
      REPLACE CUSTOMERS->CITY   WITH "Chicago"
      REPLACE CUSTOMERS->PHONE  WITH "312-555-0303"
      REPLACE CUSTOMERS->EMAIL  WITH "carol@example.com"
      REPLACE CUSTOMERS->ACTIVE WITH .f.

      APPEND BLANK
      REPLACE CUSTOMERS->NAME   WITH "David Brown"
      REPLACE CUSTOMERS->CITY   WITH "Houston"
      REPLACE CUSTOMERS->PHONE  WITH "713-555-0404"
      REPLACE CUSTOMERS->EMAIL  WITH "david@example.com"
      REPLACE CUSTOMERS->ACTIVE WITH .t.

      APPEND BLANK
      REPLACE CUSTOMERS->NAME   WITH "Eva Martinez"
      REPLACE CUSTOMERS->CITY   WITH "Miami"
      REPLACE CUSTOMERS->PHONE  WITH "305-555-0505"
      REPLACE CUSTOMERS->EMAIL  WITH "eva@example.com"
      REPLACE CUSTOMERS->ACTIVE WITH .t.

      // Position at the first record
      GO TOP

      MsgInfo( "Created customers.dbf with 5 sample records." )

   else

      // File already exists - just open it
      USE ( cFile ) ALIAS CUSTOMERS NEW EXCLUSIVE
      cAlias  := "CUSTOMERS"
      lDbfOpen := .t.
      GO TOP

   endif

   cDbfPath := cFile

   // Display the first record
   ShowRecord()

return nil

// ---------------------------------------------------------------------------
// ShowRecord() - Display the current record's fields in the memo area
//
// Reads each field from the current record and formats it as a multi-line
// text block.  Also updates the status bar with the record number.
// ---------------------------------------------------------------------------
static function ShowRecord()

   local cText := ""
   local cStatus

   if ! lDbfOpen
      oMemo:Text := "No database is open." + Chr(13) + Chr(10) + ;
                     "Click 'Open DBF' to create or open a sample database."
      oLblStatus:Text := "No database open"
      return nil
   endif

   // Check for empty table or past-end-of-file
   if ( cAlias )->( RecCount() ) == 0
      oMemo:Text := "The table is empty.  Click 'Add' to create a new record."
      oLblStatus:Text := "Record 0 / 0  -  " + cDbfPath
      return nil
   endif

   if ( cAlias )->( Eof() )
      // We went past the last record - go back to the last valid one
      ( cAlias )->( DbGoBottom() )
   endif

   // -----------------------------------------------------------------------
   // Build a formatted text showing all fields of the current record
   // -----------------------------------------------------------------------
   cText := "====================================" + Chr(13) + Chr(10)
   cText += "  Record #" + AllTrim( Str( ( cAlias )->( RecNo() ) ) ) + ;
            " of " + AllTrim( Str( ( cAlias )->( RecCount() ) ) ) + Chr(13) + Chr(10)
   cText += "====================================" + Chr(13) + Chr(10)
   cText += Chr(13) + Chr(10)
   cText += "  NAME   : " + AllTrim( ( cAlias )->NAME )   + Chr(13) + Chr(10)
   cText += "  CITY   : " + AllTrim( ( cAlias )->CITY )   + Chr(13) + Chr(10)
   cText += "  PHONE  : " + AllTrim( ( cAlias )->PHONE )  + Chr(13) + Chr(10)
   cText += "  EMAIL  : " + AllTrim( ( cAlias )->EMAIL )  + Chr(13) + Chr(10)
   cText += "  ACTIVE : " + iif( ( cAlias )->ACTIVE, "Yes", "No" ) + Chr(13) + Chr(10)
   cText += Chr(13) + Chr(10)

   // Show deletion status
   if ( cAlias )->( Deleted() )
      cText += "  ** This record is marked for deletion **" + Chr(13) + Chr(10)
   endif

   oMemo:Text := cText

   // Update the status label
   cStatus := "Record " + AllTrim( Str( ( cAlias )->( RecNo() ) ) ) + ;
              " / " + AllTrim( Str( ( cAlias )->( RecCount() ) ) ) + ;
              "  -  " + cDbfPath
   oLblStatus:Text := cStatus

return nil

// ---------------------------------------------------------------------------
// AddRecord() - Append a new blank record and fill it with placeholder data
//
// Uses APPEND BLANK to add a record at the end of the table, then
// REPLACE to set initial field values.  The user can see the result
// immediately in the memo area.
// ---------------------------------------------------------------------------
static function AddRecord()

   local cNum

   if ! lDbfOpen
      MsgInfo( "Please open a database first (click 'Open DBF')." )
      return nil
   endif

   // APPEND BLANK adds a new empty record at the end of the file
   ( cAlias )->( DbAppend() )

   // Generate a placeholder name using the record number
   cNum := AllTrim( Str( ( cAlias )->( RecNo() ) ) )

   REPLACE ( cAlias )->NAME   WITH "New Customer #" + cNum
   REPLACE ( cAlias )->CITY   WITH "Unknown"
   REPLACE ( cAlias )->PHONE  WITH "000-000-0000"
   REPLACE ( cAlias )->EMAIL  WITH "new" + cNum + "@example.com"
   REPLACE ( cAlias )->ACTIVE WITH .t.

   // Show the newly added record
   ShowRecord()

   MsgInfo( "New record #" + cNum + " added successfully." )

return nil

// ---------------------------------------------------------------------------
// DeleteRecord() - Mark the current record for deletion (with confirmation)
//
// In xBase, DELETE marks a record but does not physically remove it.
// PACK permanently removes all records marked for deletion.
// ---------------------------------------------------------------------------
static function DeleteRecord()

   if ! lDbfOpen
      MsgInfo( "Please open a database first." )
      return nil
   endif

   if ( cAlias )->( RecCount() ) == 0
      MsgInfo( "The table is empty - nothing to delete." )
      return nil
   endif

   // Mark the current record as deleted
   // In xBase, DELETE just sets a flag; PACK physically removes them
   ( cAlias )->( DbDelete() )

   // Now PACK the table to physically remove deleted records
   // Note: PACK requires EXCLUSIVE use of the table
   ( cAlias )->( __dbPack() )

   // After packing, reposition to a valid record
   ( cAlias )->( DbGoTop() )

   ShowRecord()

   MsgInfo( "Record deleted and table packed." )

return nil

// ---------------------------------------------------------------------------
// SearchRecord() - Simple sequential search by NAME field
//
// Demonstrates LOCATE / DbLocate for finding records.  In production code
// you would normally use an index (INDEX ON ... TO ...) for fast lookups.
// ---------------------------------------------------------------------------
static function SearchRecord()

   local cSearch
   local lFound := .f.
   local nOrigRec

   if ! lDbfOpen
      MsgInfo( "Please open a database first." )
      return nil
   endif

   if ( cAlias )->( RecCount() ) == 0
      MsgInfo( "The table is empty - nothing to search." )
      return nil
   endif

   // For simplicity, use a hardcoded search term.
   // In a full application you would show an input dialog.
   cSearch := "Bob"

   // Save the current position so we can restore it if not found
   nOrigRec := ( cAlias )->( RecNo() )

   // Start from the top of the file
   ( cAlias )->( DbGoTop() )

   // Sequential scan through all records looking for a match
   // This checks if cSearch appears anywhere in the NAME field
   do while ! ( cAlias )->( Eof() )
      if Upper( cSearch ) $ Upper( AllTrim( ( cAlias )->NAME ) )
         lFound := .t.
         exit
      endif
      ( cAlias )->( DbSkip() )
   enddo

   if lFound
      // Record pointer is now on the matching record
      ShowRecord()
      MsgInfo( "Found: " + AllTrim( ( cAlias )->NAME ) )
   else
      // Restore original position - record was not found
      ( cAlias )->( DbGoto( nOrigRec ) )
      ShowRecord()
      MsgInfo( "No record found containing '" + cSearch + "' in the NAME field." )
   endif

return nil

// ---------------------------------------------------------------------------
// Navigation functions - Move through the table
// ---------------------------------------------------------------------------

// GoFirst() - Jump to the first record (GO TOP)
static function GoFirst()

   if ! lDbfOpen
      MsgInfo( "Please open a database first." )
      return nil
   endif

   ( cAlias )->( DbGoTop() )
   ShowRecord()

return nil

// GoPrev() - Move to the previous record (SKIP -1)
static function GoPrev()

   if ! lDbfOpen
      MsgInfo( "Please open a database first." )
      return nil
   endif

   ( cAlias )->( DbSkip( -1 ) )

   // If we went before the first record, stay on record 1
   if ( cAlias )->( Bof() )
      ( cAlias )->( DbGoTop() )
      MsgInfo( "Already at the first record." )
   endif

   ShowRecord()

return nil

// GoNext() - Move to the next record (SKIP 1)
static function GoNext()

   if ! lDbfOpen
      MsgInfo( "Please open a database first." )
      return nil
   endif

   ( cAlias )->( DbSkip( 1 ) )

   // If we passed the last record, go back to the last valid one
   if ( cAlias )->( Eof() )
      ( cAlias )->( DbGoBottom() )
      MsgInfo( "Already at the last record." )
   endif

   ShowRecord()

return nil

// GoLast() - Jump to the last record (GO BOTTOM)
static function GoLast()

   if ! lDbfOpen
      MsgInfo( "Please open a database first." )
      return nil
   endif

   ( cAlias )->( DbGoBottom() )
   ShowRecord()

return nil
