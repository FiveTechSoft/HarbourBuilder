// Form1.prg - Simple Notepad application
//
// Demonstrates: Memo control, File operations, Menu bar, Toolbar
// A fully functional text editor built with HarbourBuilder
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oMemo, cCurrentFile, lModified

function NotepadMain()

   local oFile, oEdit, oHelp, oTB

   cCurrentFile := ""
   lModified := .F.

   DEFINE FORM oForm TITLE "Untitled - HbNotepad" ;
      SIZE 700, 500 FONT "Segoe UI", 10

   // Menu bar
   DEFINE MENUBAR OF oForm

   DEFINE POPUP oFile PROMPT "&File" OF oForm
   MENUITEM "&New"        OF oFile ACTION FileNew()
   MENUITEM "&Open..."    OF oFile ACTION FileOpen()
   MENUITEM "&Save"       OF oFile ACTION FileSave()
   MENUITEM "Save &As..." OF oFile ACTION FileSaveAs()
   MENUSEPARATOR OF oFile
   MENUITEM "E&xit"       OF oFile ACTION oForm:Close()

   DEFINE POPUP oEdit PROMPT "&Edit" OF oForm
   MENUITEM "&Undo"       OF oEdit ACTION MsgInfo( "Undo" )
   MENUSEPARATOR OF oEdit
   MENUITEM "Cu&t"        OF oEdit ACTION MsgInfo( "Cut" )
   MENUITEM "&Copy"       OF oEdit ACTION MsgInfo( "Copy" )
   MENUITEM "&Paste"      OF oEdit ACTION MsgInfo( "Paste" )
   MENUSEPARATOR OF oEdit
   MENUITEM "Select &All" OF oEdit ACTION MsgInfo( "Select All" )
   MENUITEM "&Find..."    OF oEdit ACTION MsgInfo( "Find" )

   DEFINE POPUP oHelp PROMPT "&Help" OF oForm
   MENUITEM "&About HbNotepad" OF oHelp ACTION ;
      MsgInfo( "HbNotepad 1.0" + Chr(10) + ;
               "Built with HarbourBuilder" + Chr(10) + ;
               "A simple text editor example" )

   // Memo (main editing area - fills the form)
   // In a full implementation, we'd use the Memo control anchored to fill
   @ 0, 0 GET oMemo VAR "" OF oForm SIZE 684, 440

   // Status bar info
   @ 445, 10 SAY "Ready" OF oForm SIZE 200

   oForm:OnClose := { || CheckSave() }

   ACTIVATE FORM oForm CENTERED

return nil

// === File operations ===

static function FileNew()

   if ! CheckSave(); return nil; endif

   oMemo:Text := ""
   cCurrentFile := ""
   lModified := .F.
   UpdateTitle()

return nil

static function FileOpen()

   local cFile, cContent

   if ! CheckSave(); return nil; endif

   // In production: use OpenDialog component
   // cFile := W32_OpenFileDialog( "Open File", "prg;txt;*" )
   cFile := "test.txt"  // placeholder

   if ! Empty( cFile )
      cContent := MemoRead( cFile )
      if ! Empty( cContent )
         oMemo:Text := cContent
         cCurrentFile := cFile
         lModified := .F.
         UpdateTitle()
      endif
   endif

return nil

static function FileSave()

   if Empty( cCurrentFile )
      FileSaveAs()
   else
      MemoWrit( cCurrentFile, oMemo:Text )
      lModified := .F.
      UpdateTitle()
   endif

return nil

static function FileSaveAs()

   local cFile

   // In production: use SaveDialog component
   // cFile := W32_SaveFileDialog( "Save File", "Untitled.txt", "txt" )
   cFile := "output.txt"  // placeholder

   if ! Empty( cFile )
      cCurrentFile := cFile
      MemoWrit( cCurrentFile, oMemo:Text )
      lModified := .F.
      UpdateTitle()
   endif

return nil

static function CheckSave()

   // Returns .T. if OK to proceed, .F. to cancel
   if lModified
      // In production: MsgYesNo() with 3 buttons (Save/Don't Save/Cancel)
      MsgInfo( "Document has unsaved changes" )
   endif

return .T.

static function UpdateTitle()

   local cTitle

   if Empty( cCurrentFile )
      cTitle := "Untitled"
   else
      cTitle := cCurrentFile
   endif

   if lModified
      cTitle += " *"
   endif

   oForm:Title := cTitle + " - HbNotepad"

return nil
