// Form1.prg
//--------------------------------------------------------------------
CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel
   DATA oEdit1   // TEdit
   DATA oButton1   // TButton
   DATA oDbfTable1   // TDBFTable

   // Event handlers
   METHOD Button1Click()

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "DBF Table Demo"
   ::nLeft   := 1175
   ::nTop    := 568
   ::nWidth  := 420
   ::nHeight := 240
   ::cFontName := "Segoe UI"
   ::nFontSize := 9
   ::nClrPane  := 14147434
   ::cAppTitle := "DbfTableDemo"

   @ 12, 64 SAY ::oLabel1 PROMPT "Customer name:" OF Self SIZE 200, 24
   ::oLabel1:nClrPane := 14147190
   ::oLabel1:oFont := "Segoe UI,12"
   @ 52, 66 GET ::oEdit1 VAR "" OF Self SIZE 260, 26
   ::oEdit1:oFont := "Segoe UI,12"
   @ 92, 112 BUTTON ::oButton1 PROMPT "Open table" OF Self SIZE 160, 32
   ::oButton1:oFont := "Segoe UI,12"
   COMPONENT ::oDbfTable1 TYPE CT_DBFTABLE OF Self  // TDBFTable
   ::oDbfTable1:cFileName := CustomerDbfPath()

   // Event wiring
   ::oButton1:OnClick := { || ::Button1Click() }

return nil
//--------------------------------------------------------------------

METHOD Button1Click() CLASS TForm1

   // Open the DBF, show the first field of the first record in the
   // Edit, and put a status line in the Label. Keeps the file open
   // for as little as possible (close right after read).
   if ! ::oDbfTable1:Open()
      ::oLabel1:cText := "Could not open " + ::oDbfTable1:cFileName + ;
                        " (" + ::oDbfTable1:cLastError + ")"
      ::oEdit1:cText  := ""
      return nil
   endif

   ::oDbfTable1:GoTop()
   ::oEdit1:cText  := hb_CStr( ::oDbfTable1:FieldGet( 1 ) )
   ::oLabel1:cText := ::oDbfTable1:FieldName( 1 ) + " (rec 1 of " + ;
                     LTrim( Str( ::oDbfTable1:RecCount() ) ) + ")"

   ::oDbfTable1:Close()

return nil

//--------------------------------------------------------------------
