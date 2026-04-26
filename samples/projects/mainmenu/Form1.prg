// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oMenu1   // TMainMenu
   DATA oMemo1   // TEdit
   DATA oStatus1   // TLabel

   // Event handlers

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "TMainMenu Sample"
   ::Left   := 1094
   ::Top    := 249
   ::Width  := 640
   ::Height := 448

   COMPONENT ::oMenu1 TYPE CT_MAINMENU OF Self  // TMainMenu @ 8,400
   DEFINE MENUBAR ::oMenu1
      DEFINE POPUP "&File"
         MENUITEM "&New" ACTION FileNew( Self ) ACCEL "Cmd+N"
         MENUITEM "&Open..." ACTION FileOpen( Self ) ACCEL "Cmd+O"
         MENUITEM "&Save" ACTION FileSave( Self ) ACCEL "Cmd+S"
         MENUSEPARATOR
         MENUITEM "E&xit" ACTION ::Close() ACCEL "Cmd+Q"
      END POPUP
      DEFINE POPUP "&Edit"
         MENUITEM "&Undo" ACTION EditAction( Self, "Undo" ) ACCEL "Cmd+Z"
         MENUITEM "Cu&t" ACTION EditAction( Self, "Cut" ) ACCEL "Cmd+X"
         MENUITEM "&Copy" ACTION EditAction( Self, "Copy" ) ACCEL "Cmd+C"
         MENUITEM "&Paste" ACTION EditAction( Self, "Paste" ) ACCEL "Cmd+V"
      END POPUP
      DEFINE POPUP "&Help"
         MENUITEM "&About" ACTION ShowAbout( Self, oMenuItem ) ACCEL "F1"
      END POPUP
   END MENUBAR
   @ 64, 32 GET ::oMemo1 VAR "Pick any menu item to see it dispatch..." OF Self SIZE 584, 40
   ::oMemo1:oFont := ".AppleSystemUIFont,12"
   @ 362, 18 SAY ::oStatus1 PROMPT "Ready" OF Self SIZE 600
   ::oStatus1:oFont := ".AppleSystemUIFont,12"

return nil
//--------------------------------------------------------------------

// Menu handlers — each updates the status line so the click is visible
//--------------------------------------------------------------------
static function FileNew( oForm )
   oForm:oMemo1:Text := ""
   SetStatus( oForm, "File > New" )
return nil

static function FileOpen( oForm )
   SetStatus( oForm, "File > Open..." )
   MsgInfo( "OpenDialog would appear here." )
return nil

static function FileSave( oForm )
   SetStatus( oForm, "File > Save" )
   MsgInfo( "SaveDialog would appear here." )
return nil

static function EditAction( oForm, cWhat )
   SetStatus( oForm, "Edit > " + cWhat )
return nil

static function ShowAbout()
   MsgInfo( "TMainMenu Sample 1.0" + Chr(10) + ;
            "Built with HarbourBuilder" + Chr(10) + ;
            "DEFINE MENUBAR DSL - Win/Mac/Linux" )
return nil

static function SetStatus( oForm, cMsg )
   if oForm:oStatus1 != nil
      oForm:oStatus1:Text := cMsg
   endif
return nil
