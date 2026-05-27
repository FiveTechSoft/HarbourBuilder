// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oDb1         // TMySQL (non-visual)
   DATA oLbHost      // TLabel
   DATA oEdHost      // TEdit
   DATA oLbPort      // TLabel
   DATA oEdPort      // TEdit
   DATA oLbUser      // TLabel
   DATA oEdUser      // TEdit
   DATA oLbPass      // TLabel
   DATA oEdPass      // TEdit
   DATA oLbDb        // TLabel
   DATA oEdDb        // TEdit
   DATA oBtnConnect  // TButton
   DATA oLbTables    // TLabel
   DATA oLstTables   // TListBox
   DATA oLbSQL       // TLabel
   DATA oMemSQL      // TMemo
   DATA oBtnExec     // TButton
   DATA oMemOut      // TMemo
   DATA oStatus1     // TLabel

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "TMySQL Sample"
   ::nLeft   := 200
   ::nTop    := 100
   ::nWidth  := 720
   ::nHeight := 540

   // Non-visual MySQL connection
   COMPONENT ::oDb1 TYPE CT_MYSQL OF Self  // TMySQL @ 16,440
   ::oDb1:cServer   := "127.0.0.1"
   ::oDb1:nPort     := 3306
   ::oDb1:cUser     := "root"
   ::oDb1:cPassword := ""
   ::oDb1:cDatabase := "test"

   // Connection inputs
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

   // Tables list
   @ 92,  16 SAY     ::oLbTables  PROMPT "Tables:" OF Self SIZE 100
   @ 112, 16 LISTBOX ::oLstTables OF Self SIZE 200, 320

   // SQL editor + run button + output
   @ 92, 232 SAY    ::oLbSQL  PROMPT "SQL:" OF Self SIZE 100
   @ 112, 232 MEMO ::oMemSQL VAR "SELECT 1+1 AS sum, NOW() AS now"  OF Self SIZE 472, 80
   @ 196, 232 BUTTON ::oBtnExec PROMPT "Execute" OF Self SIZE 100, 28
   @ 232, 232 MEMO ::oMemOut VAR "" OF Self SIZE 472, 200

   // Status line
   @ 460, 16 SAY ::oStatus1 PROMPT "Idle." OF Self SIZE 680

return nil
//--------------------------------------------------------------------
