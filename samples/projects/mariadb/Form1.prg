// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   DATA oDb1
   DATA oLbHost, oEdHost, oLbPort, oEdPort
   DATA oLbUser, oEdUser, oLbPass, oEdPass
   DATA oLbDb, oEdDb, oBtnConnect
   DATA oLbTables, oLstTables
   DATA oLbSQL, oMemSQL, oBtnExec, oMemOut
   DATA oStatus1

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TMariaDB Sample"
   ::nLeft   := 220
   ::nTop    := 120
   ::nWidth  := 720
   ::nHeight := 540

   COMPONENT ::oDb1 TYPE CT_MARIADB OF Self  // TMariaDB
   ::oDb1:cServer   := "127.0.0.1"
   ::oDb1:nPort     := 3306
   ::oDb1:cUser     := "root"
   ::oDb1:cPassword := ""
   ::oDb1:cDatabase := "test"

   @ 16,  16 SAY    ::oLbHost PROMPT "Host:"     OF Self SIZE 60
   @ 16,  84 GET    ::oEdHost VAR "127.0.0.1"    OF Self SIZE 200
   @ 16, 296 SAY    ::oLbPort PROMPT "Port:"     OF Self SIZE 40
   @ 16, 340 GET    ::oEdPort VAR "3306"         OF Self SIZE 60
   @ 16, 412 SAY    ::oLbUser PROMPT "User:"     OF Self SIZE 40
   @ 16, 456 GET    ::oEdUser VAR "root"         OF Self SIZE 100
   @ 16, 568 SAY    ::oLbPass PROMPT "Password:" OF Self SIZE 70
   @ 48, 568 GET    ::oEdPass VAR ""             OF Self SIZE 130
   @ 48,  16 SAY    ::oLbDb   PROMPT "Database:" OF Self SIZE 70
   @ 48,  84 GET    ::oEdDb   VAR "test"         OF Self SIZE 200
   @ 48, 296 BUTTON ::oBtnConnect PROMPT "Connect / Reload" OF Self SIZE 180, 28

   @ 92,  16 SAY     ::oLbTables  PROMPT "Tables:" OF Self SIZE 100
   @ 112, 16 LISTBOX ::oLstTables OF Self SIZE 200, 320

   @ 92, 232 SAY    ::oLbSQL  PROMPT "SQL:" OF Self SIZE 100
   @ 112, 232 MEMO ::oMemSQL VAR "SHOW DATABASES" OF Self SIZE 472, 80
   @ 196, 232 BUTTON ::oBtnExec PROMPT "Execute" OF Self SIZE 100, 28
   @ 232, 232 MEMO ::oMemOut VAR "" OF Self SIZE 472, 200

   @ 460, 16 SAY ::oStatus1 PROMPT "Idle." OF Self SIZE 680

return nil
//--------------------------------------------------------------------
