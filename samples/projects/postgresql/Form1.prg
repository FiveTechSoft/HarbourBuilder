// Form1.prg — TPostgreSQL demo: properties + events + cursor nav
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   DATA oDb1
   DATA oLbHost,  oEdHost
   DATA oLbPort,  oEdPort
   DATA oLbUser,  oEdUser
   DATA oLbPass,  oEdPass
   DATA oLbDb,    oEdDb
   DATA oLbCharSet, oEdCharSet
   DATA oBtnConnect, oBtnDisconnect
   DATA oLbTables, oLstTables, oBtnLoadTable
   DATA oLbSQL,   oMemSQL,   oBtnExec, oBtnQuery
   DATA oLbSeq,   oEdSeq,    oBtnLastId
   DATA oLbCursor, oBtnTop, oBtnPrev, oBtnNext, oLbRec
   DATA oMemOut
   DATA oStatus1

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TPostgreSQL Demo (props + events + cursor)"
   ::nLeft   := 200
   ::nTop    := 100
   ::nWidth  := 820
   ::nHeight := 620

   // --- Non-visual TPostgreSQL component ---
   COMPONENT ::oDb1 TYPE CT_POSTGRESQL OF Self
   ::oDb1:cServer   := "127.0.0.1"
   ::oDb1:nPort     := 5432
   ::oDb1:cUser     := "postgres"
   ::oDb1:cPassword := ""
   ::oDb1:cDatabase := "postgres"
   ::oDb1:cCharSet  := "UTF8"

   // --- Connection block ---
   @ 12,  12 SAY    ::oLbHost    PROMPT "Host:"     OF Self SIZE 40
   @ 12,  56 GET    ::oEdHost    VAR "127.0.0.1"    OF Self SIZE 160
   @ 12, 224 SAY    ::oLbPort    PROMPT "Port:"     OF Self SIZE 36
   @ 12, 264 GET    ::oEdPort    VAR "5432"         OF Self SIZE 60
   @ 12, 332 SAY    ::oLbUser    PROMPT "User:"     OF Self SIZE 36
   @ 12, 372 GET    ::oEdUser    VAR "postgres"     OF Self SIZE 100
   @ 12, 480 SAY    ::oLbPass    PROMPT "Pass:"     OF Self SIZE 36
   @ 12, 520 GET    ::oEdPass    VAR ""             OF Self SIZE 120

   @ 44,  12 SAY    ::oLbDb      PROMPT "Database:" OF Self SIZE 60
   @ 44,  76 GET    ::oEdDb      VAR "postgres"     OF Self SIZE 140
   @ 44, 224 SAY    ::oLbCharSet PROMPT "Charset:"  OF Self SIZE 56
   @ 44, 284 GET    ::oEdCharSet VAR "UTF8"         OF Self SIZE 80
   @ 44, 376 BUTTON ::oBtnConnect    PROMPT "Connect"    OF Self SIZE 110, 26
   @ 44, 492 BUTTON ::oBtnDisconnect PROMPT "Disconnect" OF Self SIZE 110, 26

   // --- Tables list ---
   @ 84,  12 SAY     ::oLbTables    PROMPT "Tables:" OF Self SIZE 100
   @ 104, 12 LISTBOX ::oLstTables   OF Self SIZE 200, 200
   @ 308, 12 BUTTON  ::oBtnLoadTable PROMPT "Load selected → cursor" OF Self SIZE 200, 26

   // --- SQL editor ---
   @ 84,  228 SAY  ::oLbSQL  PROMPT "SQL:" OF Self SIZE 60
   @ 104, 228 MEMO ::oMemSQL VAR "SELECT version();" OF Self SIZE 568, 70
   @ 180, 228 BUTTON ::oBtnExec  PROMPT "Execute"       OF Self SIZE 100, 26
   @ 180, 336 BUTTON ::oBtnQuery PROMPT "Query (array)" OF Self SIZE 120, 26

   // --- LastInsertId / cIdSequence ---
   @ 180, 464 SAY    ::oLbSeq    PROMPT "Seq:"         OF Self SIZE 36
   @ 180, 504 GET    ::oEdSeq    VAR ""                OF Self SIZE 140
   @ 180, 656 BUTTON ::oBtnLastId PROMPT "LastInsertId" OF Self SIZE 120, 26

   // --- Cursor navigation ---
   @ 220, 228 SAY    ::oLbCursor PROMPT "Cursor:" OF Self SIZE 60
   @ 220, 292 BUTTON ::oBtnTop   PROMPT "Top"  OF Self SIZE 60, 24
   @ 220, 360 BUTTON ::oBtnPrev  PROMPT "Prev" OF Self SIZE 60, 24
   @ 220, 428 BUTTON ::oBtnNext  PROMPT "Next" OF Self SIZE 60, 24
   @ 220, 496 SAY    ::oLbRec    PROMPT "Rec: 0/0" OF Self SIZE 200

   // --- Output ---
   @ 252, 228 MEMO ::oMemOut VAR "" OF Self SIZE 568, 290

   // --- Status ---
   @ 552,  12 SAY ::oStatus1 PROMPT "Idle." OF Self SIZE 784

return nil
//--------------------------------------------------------------------
