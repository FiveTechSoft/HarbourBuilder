// hbbuilder_linux.prg - HbBuilder: visual IDE for Harbour (C++Builder layout)
//
// Classic layout (originally 1024x768, scaled proportionally):
//
// +-------------------------------------------------------------+ 0
// |  Main Bar: toolbar + splitter + palette tabs (full width)    |
// +----------+--------------------------------------------------+ ~100
// | Object   |  Code Editor (background, full area)              |
// | Inspector|  +---------------------+                          |
// |          |  |  Form Designer      |  (floating on top)       |
// | combo +  |  |  (400x300)          |                          |
// | property |  +---------------------+                          |
// | grid     |                                                   |
// |          |                                                   |
// +----------+---------------------------------------------------+ ~650
// |  Messages / Compiler output (future)                         |
// +--------------------------------------------------------------+ 768

#include "../include/hbbuilder.ch"

static oIDE          // Main IDE bar (top strip)
static oDesignForm   // Design form (active, floats on top of editor)
static hCodeEditor   // Code editor (background, right of inspector)
static nScreenW      // Screen width
static nScreenH      // Screen height
static cCurrentFile  // Current file path (empty = untitled)

// Project form list (C++Builder: each form = a unit)
// Each entry: { cName, oForm, cCode, nFormX, nFormY }
static aForms        // Array of form entries
static nActiveForm   // Index of active form (1-based)
static aModules      // Array of project modules: { { cName, cCode, cFilePath }, ... }
static aOpenFiles    // Array of open files (not in project): { { cName, cCode, cFilePath }, ... }
static oTB2          // Debug toolbar (for highlighting Debug button)
static aDbgOffsets   // line offset tracking for debug_main.prg sections
static lSyncingFromCode := .f.  // Guard: prevents re-entrant loop when syncing code→form

function Main()

   local oTB, oFile, oEdit, oSearch, oView, oProject, oRun, oFormat, oComp, oTools, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY
   local cIcoDir

   nScreenW := GTK_GetScreenWidth()
   nScreenH := GTK_GetScreenHeight()
   cCurrentFile := ""
   aForms := {}
   nActiveForm := 0
   aModules := {}
   aOpenFiles := {}

   // C++Builder classic proportions scaled to current screen
   nBarH    := 72                            // toolbar(36) + tabs(24) + margins(12)
   nInsW    := Int( nScreenW * 0.18 ) + 20    // ~18% of screen width + 20px

   // === Window 1: Main Bar (full screen width) ===
   DEFINE FORM oIDE TITLE "HbBuilder 1.0 - Visual IDE for Harbour" ;
      SIZE nScreenW, nBarH FONT "Sans", 11 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()

   // Restore dark mode preference from ini
   LoadDarkMode()

   // Inspector: right below IDE window
   nInsTop  := GTK_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 1
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nBottomY := nScreenH
   nEditorH := nBottomY - nEditorTop

   // Form Designer: centered in editor area
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 )
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 )

   // Menu bar
   DEFINE MENUBAR OF oIDE

   DEFINE POPUP oFile PROMPT "File" OF oIDE
   MENUITEM "New Application" OF oFile ACTION TBNew()               ACCEL "n"
   MENUITEM "New Form"        OF oFile ACTION MenuNewForm()
   MENUITEM "Add Module..."   OF oFile ACTION MenuAddModule()
   MENUSEPARATOR OF oFile
   MENUITEM "Open Project..." OF oFile ACTION TBOpen()              ACCEL "o"
   MENUITEM "Reopen Last Project" OF oFile ACTION ReopenLastProject()
   MENUITEM "Open File..."    OF oFile ACTION MenuOpenFile()
   MENUITEM "Close File"      OF oFile ACTION MenuCloseFile()
   MENUITEM "Save"       OF oFile ACTION TBSave()                   ACCEL "s"
   MENUITEM "Save As..." OF oFile ACTION TBSaveAs()
   MENUSEPARATOR OF oFile
   MENUITEM "Exit"       OF oFile ACTION oIDE:Close()               ACCEL "q"

   DEFINE POPUP oEdit PROMPT "Edit" OF oIDE
   MENUITEM "Undo"  OF oEdit ACTION CodeEditorUndo( hCodeEditor )  ACCEL "z"
   MENUITEM "Redo"  OF oEdit ACTION CodeEditorRedo( hCodeEditor )  ACCEL "y"
   MENUSEPARATOR OF oEdit
   MENUITEM "Cut"   OF oEdit ACTION CodeEditorCut( hCodeEditor )   ACCEL "x"
   MENUITEM "Copy"  OF oEdit ACTION CodeEditorCopy( hCodeEditor )  ACCEL "c"
   MENUITEM "Paste" OF oEdit ACTION CodeEditorPaste( hCodeEditor ) ACCEL "v"
   MENUSEPARATOR OF oEdit
   MENUITEM "Form Undo"  OF oEdit ACTION FormUndo()
   MENUITEM "Copy Controls"  OF oEdit ACTION CopyControls()
   MENUITEM "Paste Controls" OF oEdit ACTION PasteControls()

   DEFINE POPUP oSearch PROMPT "Search" OF oIDE
   MENUITEM "Find..."        OF oSearch ACTION CodeEditorFind( hCodeEditor )          ACCEL "f"
   MENUITEM "Replace..."     OF oSearch ACTION CodeEditorReplace( hCodeEditor )       ACCEL "h"
   MENUSEPARATOR OF oSearch
   MENUITEM "Find Next"      OF oSearch ACTION CodeEditorFindNext( hCodeEditor )
   MENUITEM "Find Previous"  OF oSearch ACTION CodeEditorFindPrev( hCodeEditor )
   MENUSEPARATOR OF oSearch
   MENUITEM "Auto-Complete"  OF oSearch ACTION CodeEditorAutoComplete( hCodeEditor )

   DEFINE POPUP oView PROMPT "View" OF oIDE
   MENUITEM "Forms..."     OF oView ACTION MenuViewForms()
   MENUITEM "Code Editor"  OF oView ACTION CodeEditorBringToFront( hCodeEditor )
   MENUITEM "Inspector"        OF oView ACTION InspectorOpen()
   MENUITEM "Project Inspector" OF oView ACTION ShowProjectInspector()
   MENUITEM "Debugger"          OF oView ACTION TBDebugRun()

   DEFINE POPUP oProject PROMPT "Project" OF oIDE
   MENUITEM "Add to Project..."    OF oProject ACTION AddToProject()
   MENUITEM "Remove from Project"  OF oProject ACTION RemoveFromProject()
   MENUSEPARATOR OF oProject
   MENUITEM "Options..."           OF oProject ACTION ShowProjectOptions()

   DEFINE POPUP oRun PROMPT "Run" OF oIDE
   MENUITEM "Run"            OF oRun ACTION TBRun()                ACCEL "r"
   MENUITEM "Debug"          OF oRun ACTION TBDebugRun()
   MENUITEM "Debug to BP"    OF oRun ACTION TBDebugRunToBreak()
   MENUSEPARATOR OF oRun
   MENUITEM "Step Over"      OF oRun ACTION DebugStepOver()
   MENUITEM "Step Into"      OF oRun ACTION DebugStepInto()
   MENUITEM "Continue"       OF oRun ACTION IDE_DebugGo()
   MENUITEM "Stop"           OF oRun ACTION IDE_DebugStop()
   MENUSEPARATOR OF oRun
   MENUITEM "Toggle Breakpoint"  OF oRun ACTION ToggleBreakpoint()
   MENUITEM "Clear Breakpoints"  OF oRun ACTION ClearBreakpoints()

   DEFINE POPUP oFormat PROMPT "Format" OF oIDE
   MENUITEM "Align Left"              OF oFormat ACTION AlignControls( 1 )
   MENUITEM "Align Right"             OF oFormat ACTION AlignControls( 2 )
   MENUITEM "Align Top"               OF oFormat ACTION AlignControls( 3 )
   MENUITEM "Align Bottom"            OF oFormat ACTION AlignControls( 4 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Center Horizontally"     OF oFormat ACTION AlignControls( 5 )
   MENUITEM "Center Vertically"       OF oFormat ACTION AlignControls( 6 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Space Evenly Horizontal" OF oFormat ACTION AlignControls( 7 )
   MENUITEM "Space Evenly Vertical"   OF oFormat ACTION AlignControls( 8 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Tab Order..."            OF oFormat ACTION ShowTabOrder()

   DEFINE POPUP oComp PROMPT "Component" OF oIDE
   MENUITEM "Install Component..." OF oComp ACTION InstallComponent()
   MENUITEM "New Component..."     OF oComp ACTION NewComponent()

   DEFINE POPUP oTools PROMPT "Tools" OF oIDE
   MENUITEM "Editor Colors..."        OF oTools ACTION ShowEditorSettings()
   MENUITEM "Environment Options..."  OF oTools ACTION ShowEnvironmentOptions()
   MENUITEM "Dark Mode"              OF oTools ACTION ToggleDarkMode()
   MENUSEPARATOR OF oTools
   MENUITEM "AI Assistant..."         OF oTools ACTION ShowAIAssistant()
   MENUSEPARATOR OF oTools
   MENUITEM "Report Designer"        OF oTools ACTION OpenReportDesigner()

   DEFINE POPUP oHelp PROMPT "Help" OF oIDE
   MENUITEM "Documentation"        OF oHelp ACTION GTK_ShellExec( "xdg-open ../docs/en/index.html" )
   MENUITEM "Quick Start"          OF oHelp ACTION GTK_ShellExec( "xdg-open ../docs/en/quickstart.html" )
   MENUITEM "Controls Reference"   OF oHelp ACTION GTK_ShellExec( "xdg-open ../docs/en/controls-standard.html" )
   MENUSEPARATOR OF oHelp
   MENUITEM "About HbBuilder..." OF oHelp ACTION ShowAbout()

   // Menu bitmaps (16x16 from Lazarus IDE icon set)
   cIcoDir := "../resources/menu_icons/"

   UI_MenuSetBitmapByPos( oFile:hPopup, 0, cIcoDir + "menu_new.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 1, cIcoDir + "menu_new_form.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 2, cIcoDir + "menu_project_add.png" )  // Add Module
   UI_MenuSetBitmapByPos( oFile:hPopup, 4, cIcoDir + "menu_open.png" )         // Open Project
   UI_MenuSetBitmapByPos( oFile:hPopup, 5, cIcoDir + "menu_open.png" )         // Reopen Last
   UI_MenuSetBitmapByPos( oFile:hPopup, 6, cIcoDir + "menu_open.png" )         // Open File
   UI_MenuSetBitmapByPos( oFile:hPopup, 8, cIcoDir + "menu_save.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 9, cIcoDir + "menu_saveas.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 11, cIcoDir + "menu_exit.png" )

   UI_MenuSetBitmapByPos( oEdit:hPopup, 0, cIcoDir + "menu_undo.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 1, cIcoDir + "menu_redo.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 3, cIcoDir + "menu_cut.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 4, cIcoDir + "menu_copy.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 5, cIcoDir + "menu_paste.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 7, cIcoDir + "menu_edit_undo_design.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 8, cIcoDir + "menu_copy_controls.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 9, cIcoDir + "menu_paste.png" )

   UI_MenuSetBitmapByPos( oSearch:hPopup, 0, cIcoDir + "menu_search_find.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 1, cIcoDir + "menu_search_replace.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 3, cIcoDir + "menu_search_findnext.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 4, cIcoDir + "menu_search_findprev.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 6, cIcoDir + "menu_autocomplete.png" )

   UI_MenuSetBitmapByPos( oView:hPopup, 0, cIcoDir + "menu_view_forms.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 1, cIcoDir + "menu_view_editor.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 2, cIcoDir + "menu_view_inspector.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 3, cIcoDir + "menu_project_inspector.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 4, cIcoDir + "menu_view_debug.png" )

   UI_MenuSetBitmapByPos( oProject:hPopup, 0, cIcoDir + "menu_project_add.png" )
   UI_MenuSetBitmapByPos( oProject:hPopup, 1, cIcoDir + "menu_project_remove.png" )
   UI_MenuSetBitmapByPos( oProject:hPopup, 3, cIcoDir + "menu_project_options.png" )

   UI_MenuSetBitmapByPos( oRun:hPopup, 0, cIcoDir + "menu_run.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 1, cIcoDir + "menu_debug.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 3, cIcoDir + "menu_stepover.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 4, cIcoDir + "menu_stepinto.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 5, cIcoDir + "menu_continue.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 6, cIcoDir + "menu_stop.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 8, cIcoDir + "menu_breakpoint.png" )

   UI_MenuSetBitmapByPos( oFormat:hPopup, 0, cIcoDir + "menu_align.png" )
   UI_MenuSetBitmapByPos( oFormat:hPopup, 10, cIcoDir + "menu_taborder.png" )

   UI_MenuSetBitmapByPos( oTools:hPopup, 0, cIcoDir + "menu_editor_colors.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 1, cIcoDir + "menu_environment_options.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 2, cIcoDir + "menu_darkmode.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 4, cIcoDir + "menu_ai.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 6, cIcoDir + "menu_report.png" )

   UI_MenuSetBitmapByPos( oHelp:hPopup, 0, cIcoDir + "menu_help_docs.png" )
   UI_MenuSetBitmapByPos( oHelp:hPopup, 4, cIcoDir + "menu_about.png" )

   // Row 1: File & Edit speedbar
   DEFINE TOOLBAR oTB OF oIDE
   BUTTON "New"   OF oTB TOOLTIP "New project (Ctrl+N)"  ACTION TBNew()
   BUTTON "Open"  OF oTB TOOLTIP "Open file (Ctrl+O)"    ACTION TBOpen()
   BUTTON "Save"  OF oTB TOOLTIP "Save file (Ctrl+S)"    ACTION TBSave()
   SEPARATOR OF oTB
   BUTTON "Cut"   OF oTB TOOLTIP "Cut (Ctrl+X)"          ACTION CodeEditorCut( hCodeEditor )
   BUTTON "Copy"  OF oTB TOOLTIP "Copy (Ctrl+C)"         ACTION CodeEditorCopy( hCodeEditor )
   BUTTON "Paste" OF oTB TOOLTIP "Paste (Ctrl+V)"        ACTION CodeEditorPaste( hCodeEditor )
   SEPARATOR OF oTB
   BUTTON "Undo"  OF oTB TOOLTIP "Undo (Ctrl+Z)"         ACTION CodeEditorUndo( hCodeEditor )
   BUTTON "Redo"  OF oTB TOOLTIP "Redo (Ctrl+Y)"         ACTION CodeEditorRedo( hCodeEditor )
   SEPARATOR OF oTB
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F9)"      ACTION TBRun()
   SEPARATOR OF oTB
   BUTTON "Form"  OF oTB TOOLTIP "Toggle Form/Code"     ACTION ToggleFormCode()

   // Load toolbar icons (Lazarus IDE icon set)
   UI_ToolBarLoadImages( oTB:hCpp, "../resources/toolbar.bmp" )

   // Row 2: Debug speedbar
   DEFINE TOOLBAR oTB2 OF oIDE
   BUTTON "Debug" OF oTB2 TOOLTIP "Debug (F8)"             ACTION TBDebugRun()
   BUTTON "DebBP" OF oTB2 TOOLTIP "Debug to Breakpoint"   ACTION TBDebugRunToBreak()
   SEPARATOR OF oTB2
   BUTTON "Step"  OF oTB2 TOOLTIP "Step Into (F7)"         ACTION DebugStepInto()
   BUTTON "Over"  OF oTB2 TOOLTIP "Step Over (F8)"         ACTION DebugStepOver()
   BUTTON "Stop"  OF oTB2 TOOLTIP "Stop Debugging"         ACTION IDE_DebugStop()
   BUTTON "Exit"  OF oTB2 TOOLTIP "Exit IDE"               ACTION oIDE:Close()

   UI_ToolBarLoadImages( oTB2:hCpp, "../resources/toolbar_debug.bmp" )

   // Component Palette (icon grid, tabbed, right of splitter)
   CreatePalette()

   // === Window 4: Code Editor ===
   hCodeEditor := CodeEditorCreate( nEditorX, nEditorTop, nEditorW, nEditorH )

   // Apply saved dark/light theme to editor
   if ! GTK_IsDarkMode()
      CodeEditorApplyTheme( hCodeEditor, .F. )
   endif

   // === Window 3: Form Designer ===
   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   UI_SetDesignForm( oDesignForm:hCpp )
   oDesignForm:Show()

   // Set up editor tabs: Project1.prg (tab 1) + Form1.prg (tab 2)
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
   CodeEditorAddTab( hCodeEditor, "Form1.prg" )
   SyncDesignerToCode()
   CodeEditorSetTabText( hCodeEditor, 2, aForms[1][3] )
   CodeEditorSelectTab( hCodeEditor, 2 )

   CodeEditorOnTabChange( hCodeEditor, { |hEd, nTab| OnEditorTabChange( hEd, nTab ) } )
   CodeEditorOnTextChange( hCodeEditor, { |hEd, nTab| OnEditorTextChange( hEd, nTab ) } )

   // === Window 2: Object Inspector ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )
   INS_SetOnEventDblClick( _InsGetData(), ;
      { |hCtrl, cEvent| OnEventDblClick( hCtrl, cEvent ) } )
   INS_SetOnPropChanged( _InsGetData(), { || SyncDesignerToCode() } )
   INS_SetPos( _InsGetData(), 0, nInsTop - 50, nInsW, nBottomY - nInsTop + 50 - 50 )

   WireDesignForm()

   oIDE:OnClose := { || DestroyAllForms(), InspectorClose(), ;
                       CodeEditorDestroy( hCodeEditor ) }

   oIDE:Activate()

   // Cleanup after main loop exits
   DestroyAllForms()
   InspectorClose()
   CodeEditorDestroy( hCodeEditor )

   oIDE:Destroy()

return nil

static function CreatePalette()

   local oPal, nTab

   DEFINE PALETTE oPal OF oIDE

   // Standard tab (C++Builder)
   nTab := oPal:AddTab( "Standard" )
   oPal:AddComp( nTab, "A",    "Label",       1 )
   oPal:AddComp( nTab, "ab",   "Edit",        2 )
   oPal:AddComp( nTab, "Btn",  "Button",      3 )
   oPal:AddComp( nTab, "Mem",  "Memo",       24 )
   oPal:AddComp( nTab, "Chk",  "CheckBox",    4 )
   oPal:AddComp( nTab, "Rad",  "RadioButton", 8 )
   oPal:AddComp( nTab, "Lst",  "ListBox",     7 )
   oPal:AddComp( nTab, "Cmb",  "ComboBox",    5 )
   oPal:AddComp( nTab, "Grp",  "GroupBox",    6 )
   oPal:AddComp( nTab, "Pnl",  "Panel",      25 )
   oPal:AddComp( nTab, "SB",   "ScrollBar",  26 )

   // Additional tab (C++Builder)
   nTab := oPal:AddTab( "Additional" )
   oPal:AddComp( nTab, "BBt",  "BitBtn",      12 )
   oPal:AddComp( nTab, "Spd",  "SpeedButton", 27 )
   oPal:AddComp( nTab, "Img",  "Image",       14 )
   oPal:AddComp( nTab, "Shp",  "Shape",       15 )
   oPal:AddComp( nTab, "Bvl",  "Bevel",       16 )
   oPal:AddComp( nTab, "Msk",  "MaskEdit",    28 )
   oPal:AddComp( nTab, "SG",   "StringGrid",  29 )
   oPal:AddComp( nTab, "SBx",  "ScrollBox",   30 )
   oPal:AddComp( nTab, "STx",  "StaticText",  31 )
   oPal:AddComp( nTab, "LEd",  "LabeledEdit", 32 )

   // GTK3 tab (equivalent to Win32 in C++Builder)
   nTab := oPal:AddTab( "GTK3" )
   oPal:AddComp( nTab, "Fol",  "Folder",      33 )
   oPal:AddComp( nTab, "TV",   "TreeView",    20 )
   oPal:AddComp( nTab, "LV",   "ListView",    21 )
   oPal:AddComp( nTab, "PB",   "ProgressBar", 22 )
   oPal:AddComp( nTab, "RE",   "RichEdit",    23 )
   oPal:AddComp( nTab, "TB",   "TrackBar",    34 )
   oPal:AddComp( nTab, "UD",   "SpinButton",  35 )
   oPal:AddComp( nTab, "DTP",  "DatePicker",  36 )
   oPal:AddComp( nTab, "MC",   "Calendar",    37 )

   // System tab (C++Builder)
   nTab := oPal:AddTab( "System" )
   oPal:AddComp( nTab, "Tmr",  "Timer",       38 )
   oPal:AddComp( nTab, "PBx",  "PaintBox",    39 )

   // Dialogs tab (C++Builder)
   nTab := oPal:AddTab( "Dialogs" )
   oPal:AddComp( nTab, "OD",   "OpenDialog",  40 )
   oPal:AddComp( nTab, "SD",   "SaveDialog",  41 )
   oPal:AddComp( nTab, "FD",   "FontDialog",  42 )
   oPal:AddComp( nTab, "CD",   "ColorDialog", 43 )
   oPal:AddComp( nTab, "FnD",  "FindDialog",  44 )
   oPal:AddComp( nTab, "RD",   "ReplaceDialog", 45 )

   // Data Access tab
   nTab := oPal:AddTab( "Data Access" )
   oPal:AddComp( nTab, "DBF",  "DBFTable",    53 )
   oPal:AddComp( nTab, "MyS",  "MySQL",       54 )
   oPal:AddComp( nTab, "MrD",  "MariaDB",     55 )
   oPal:AddComp( nTab, "PgS",  "PostgreSQL",  56 )
   oPal:AddComp( nTab, "SLt",  "SQLite",      57 )
   oPal:AddComp( nTab, "FB",   "Firebird",    58 )
   oPal:AddComp( nTab, "MSS",  "SQLServer",   59 )
   oPal:AddComp( nTab, "Ora",  "Oracle",      60 )
   oPal:AddComp( nTab, "Mng",  "MongoDB",     61 )

   // Data Controls tab
   nTab := oPal:AddTab( "Data Controls" )
   oPal:AddComp( nTab, "Brw",  "Browse",      79 )
   oPal:AddComp( nTab, "DBG",  "DBGrid",      80 )
   oPal:AddComp( nTab, "DBN",  "DBNavigator", 81 )
   oPal:AddComp( nTab, "DBT",  "DBText",      82 )
   oPal:AddComp( nTab, "DBE",  "DBEdit",      83 )
   oPal:AddComp( nTab, "DBC",  "DBComboBox",  84 )
   oPal:AddComp( nTab, "DBK",  "DBCheckBox",  85 )
   oPal:AddComp( nTab, "DBI",  "DBImage",     86 )

   // Internet tab (full networking stack)
   nTab := oPal:AddTab( "Internet" )
   oPal:AddComp( nTab, "Web",  "WebView",     62 )
   oPal:AddComp( nTab, "WSv",  "WebServer",   71 )
   oPal:AddComp( nTab, "WSk",  "WebSocket",   72 )
   oPal:AddComp( nTab, "HTTP", "HttpClient",  73 )
   oPal:AddComp( nTab, "FTP",  "FtpClient",   74 )
   oPal:AddComp( nTab, "SMTP", "SmtpClient",  75 )
   oPal:AddComp( nTab, "TSv",  "TcpServer",   76 )
   oPal:AddComp( nTab, "TCl",  "TcpClient",   77 )
   oPal:AddComp( nTab, "UDP",  "UdpSocket",   78 )

   // Printing tab
   nTab := oPal:AddTab( "Printing" )
   oPal:AddComp( nTab, "Prt",  "Printer",       102 )
   oPal:AddComp( nTab, "Rpt",  "Report",        103 )
   oPal:AddComp( nTab, "Lbl",  "Labels",        104 )
   oPal:AddComp( nTab, "PPv",  "PrintPreview",  105 )
   oPal:AddComp( nTab, "PSt",  "PageSetup",     106 )
   oPal:AddComp( nTab, "PDl",  "PrintDialog",   107 )
   oPal:AddComp( nTab, "RVw",  "ReportViewer",  108 )
   oPal:AddComp( nTab, "BPr",  "BarcodePrinter", 109 )

   // ERP tab (enterprise / business components)
   nTab := oPal:AddTab( "ERP" )
   oPal:AddComp( nTab, "PP",   "Preprocessor",  90 )
   oPal:AddComp( nTab, "Scr",  "ScriptEngine",  91 )
   oPal:AddComp( nTab, "Rpt",  "ReportDesigner", 92 )
   oPal:AddComp( nTab, "BC",   "Barcode",       93 )
   oPal:AddComp( nTab, "PDF",  "PDFGenerator",  94 )
   oPal:AddComp( nTab, "XLS",  "ExcelExport",   95 )
   oPal:AddComp( nTab, "Aud",  "AuditLog",      96 )
   oPal:AddComp( nTab, "Prm",  "Permissions",   97 )
   oPal:AddComp( nTab, "Cur",  "Currency",      98 )
   oPal:AddComp( nTab, "Tax",  "TaxEngine",     99 )
   oPal:AddComp( nTab, "Dsh",  "Dashboard",    100 )
   oPal:AddComp( nTab, "Sch",  "Scheduler",    101 )

   // Threading tab
   nTab := oPal:AddTab( "Threading" )
   oPal:AddComp( nTab, "Thr",  "Thread",          63 )
   oPal:AddComp( nTab, "Mtx",  "Mutex",            64 )
   oPal:AddComp( nTab, "Sem",  "Semaphore",        65 )
   oPal:AddComp( nTab, "CS",   "CriticalSection",  66 )
   oPal:AddComp( nTab, "TPl",  "ThreadPool",       67 )
   oPal:AddComp( nTab, "Atm",  "AtomicInt",        68 )
   oPal:AddComp( nTab, "CV",   "CondVar",          69 )
   oPal:AddComp( nTab, "Ch",   "Channel",          70 )

   // AI tab (LLM & Transformer components)
   nTab := oPal:AddTab( "AI" )
   oPal:AddComp( nTab, "OAI",  "OpenAI",      46 )
   oPal:AddComp( nTab, "Gem",  "Gemini",       47 )
   oPal:AddComp( nTab, "Cld",  "Claude",       48 )
   oPal:AddComp( nTab, "DSk",  "DeepSeek",     49 )
   oPal:AddComp( nTab, "Grk",  "Grok",         50 )
   oPal:AddComp( nTab, "Oll",  "Ollama",       51 )
   oPal:AddComp( nTab, "Tfm",  "Transformer",  52 )
   oPal:AddComp( nTab, "Wsp",  "Whisper",     110 )
   oPal:AddComp( nTab, "Emb",  "Embeddings",  111 )

   // Connectivity tab (language/runtime interop)
   nTab := oPal:AddTab( "Connectivity" )
   oPal:AddComp( nTab, "Py",   "Python",      112 )
   oPal:AddComp( nTab, "Swf",  "Swift",       113 )
   oPal:AddComp( nTab, "Go",   "Go",          114 )
   oPal:AddComp( nTab, "Nod",  "Node",        115 )
   oPal:AddComp( nTab, "Rst",  "Rust",        116 )
   oPal:AddComp( nTab, "Jav",  "Java",        117 )
   oPal:AddComp( nTab, "Net",  "DotNet",      118 )
   oPal:AddComp( nTab, "Lua",  "Lua",         119 )
   oPal:AddComp( nTab, "Rby",  "Ruby",        120 )

   // Source Control tab (Git)
   nTab := oPal:AddTab( "Git" )
   oPal:AddComp( nTab, "Rpo",  "GitRepo",     121 )
   oPal:AddComp( nTab, "Cmt",  "GitCommit",   122 )
   oPal:AddComp( nTab, "Bch",  "GitBranch",   123 )
   oPal:AddComp( nTab, "Log",  "GitLog",      124 )
   oPal:AddComp( nTab, "Dif",  "GitDiff",     125 )
   oPal:AddComp( nTab, "Rem",  "GitRemote",   126 )
   oPal:AddComp( nTab, "Sth",  "GitStash",    127 )
   oPal:AddComp( nTab, "Tag",  "GitTag",      128 )
   oPal:AddComp( nTab, "Blm",  "GitBlame",    129 )
   oPal:AddComp( nTab, "Mrg",  "GitMerge",    130 )

   UI_PaletteLoadImages( oPal:hCpp, "../resources/palette.bmp" )

return nil

static function CreateDesignForm( nX, nY )

   local cName, nIdx

   nIdx := Len( aForms ) + 1
   cName := "Form" + LTrim( Str( nIdx ) )

   DEFINE FORM oDesignForm TITLE cName SIZE 400, 300 FONT "Sans", 11
   UI_FormSetPos( oDesignForm:hCpp, nX, nY )

   AAdd( aForms, { cName, oDesignForm, GenerateFormCode( cName ), nX, nY } )
   nActiveForm := Len( aForms )

return nil

static function OnComboSelect( nSel )

   local hTarget, aMap, aEntry
   local cTabs, aLabels, cCap, hIns

   aMap := InspectorGetComboMap()

   if ! Empty( aMap ) .and. nSel >= 0 .and. nSel < Len( aMap )
      aEntry := aMap[ nSel + 1 ]  // 0-based -> 1-based

      if aEntry[1] == 2  // Browse column
         // aEntry = { 2, hBrowse, nColIdx }
         UI_FormSelectCtrl( oDesignForm:hCpp, aEntry[2] )
         InspectorRefreshColumn( aEntry[2], aEntry[3] )
         return nil
      endif

      if aEntry[1] == 3  // Folder page
         // aEntry = { 3, hFolder, nPageIdx } — switch tab and show
         // TFolderPage props (cCaption, nPage) in the inspector.
         // NOTE: do not call UI_FormSelectCtrl here — it fires OnSelChange
         // which calls InspectorRefresh(folder) and clobbers the page rows.
         cTabs := UI_GetProp( aEntry[2], "aTabs" )
         aLabels := iif( Empty( cTabs ), {}, hb_ATokens( cTabs, "|" ) )
         cCap := iif( aEntry[3]+1 <= Len(aLabels), aLabels[aEntry[3]+1], "" )
         UI_TabControlSetSel( aEntry[2], aEntry[3] )
         hIns := _InsGetData()
         INS_SetFolderPage( hIns, aEntry[2], aEntry[3] )
         INS_AddCategoryRow( hIns, "Page" )
         INS_AddRow( hIns, "cCaption", cCap, "Page", "S" )
         INS_AddRow( hIns, "nPage", LTrim(Str(aEntry[3]+1)), "Page", "N" )
         INS_Rebuild( hIns )
         return nil
      endif

      // Form or control
      hTarget := aEntry[2]
   else
      if nSel == 0
         hTarget := oDesignForm:hCpp
      else
         hTarget := UI_GetChild( oDesignForm:hCpp, nSel )
      endif
   endif

   if hTarget != 0
      UI_FormSelectCtrl( oDesignForm:hCpp, hTarget )
      InspectorRefresh( hTarget )
   endif

return nil

static function OnDesignSelChange( hCtrl )

   local hTarget, i, nCount, nSel

   hTarget := If( hCtrl == 0, oDesignForm:hCpp, hCtrl )
   InspectorRefresh( hTarget )

   nSel := 0
   if hCtrl != 0 .and. hCtrl != oDesignForm:hCpp
      nCount := UI_GetChildCount( oDesignForm:hCpp )
      for i := 1 to nCount
         if UI_GetChild( oDesignForm:hCpp, i ) == hCtrl
            nSel := i
            exit
         endif
      next
   endif
   INS_ComboSelect( _InsGetData(), nSel )

   SyncDesignerToCode()

return nil

static function GenerateProjectCode()

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e
   local i

   cCode += "// Project1.prg" + e
   cCode += cSep
   cCode += '#include "hbbuilder.ch"' + e
   cCode += cSep
   cCode += e
   cCode += "PROCEDURE Main()" + e
   cCode += e
   cCode += "   local oApp" + e
   cCode += e
   cCode += "   oApp := TApplication():New()" + e
   cCode += '   oApp:Title := "Project1"' + e

   for i := 1 to Len( aForms )
      cCode += "   oApp:CreateForm( T" + aForms[i][1] + "():New() )" + e
   next

   cCode += "   oApp:Run()" + e
   cCode += e
   cCode += "return" + e
   cCode += cSep

return cCode

static function GenerateFormCode( cName )
return RegenerateFormCode( cName, 0 )

static function RegenerateFormCode( cName, hForm )

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e
   local cClass := "T" + cName
   local i, nCount, hCtrl, cCtrlName, cCtrlClass, nType
   local nW, nH, nFL, nFT, cTitle, nClr, cAppTitle := ""
   local nL, nT, nCW, nCH, cText
   local cDatas := "", cCreate := "", cEvents := ""
   local cExistingCode, aEvents, j, cEvName, cEvSuffix, cHandlerName
   local cVal, aHdrs, kk, nColCount, aColProps, nColW, nCtrlClr, nInterval, nVal
   local aCtrlMap := {}, cOf, hOwner, nPg, kk2, nLen0, cSlice
   local aExLines, lInClass, cExLine

   // Read existing code to find declared event handlers
   cExistingCode := ""
   if nActiveForm > 0 .and. nActiveForm <= Len( aForms )
      cExistingCode := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   endif

   if hForm != 0
      cTitle := UI_GetProp( hForm, "cText" )
      nFL    := UI_GetProp( hForm, "nLeft" )
      nFT    := UI_GetProp( hForm, "nTop" )
      nW     := UI_GetProp( hForm, "nWidth" )
      nH     := UI_GetProp( hForm, "nHeight" )
      nClr   := UI_GetProp( hForm, "nClrPane" )
      cAppTitle := UI_GetProp( hForm, "cAppTitle" )
      if ValType( cAppTitle ) != "C"; cAppTitle := ""; endif
   else
      cTitle := cName
      nFL := 0; nFT := 0; nW := 400; nH := 300
      nClr   := 15790320
   endif

   // First pass: map each hCtrl → cCtrlName for OF ::oFolder:aPages[N] emit
   if hForm != 0
      nCount := UI_GetChildCount( hForm )
      for i := 1 to nCount
         hCtrl := UI_GetChild( hForm, i )
         if hCtrl == 0; loop; endif
         cCtrlName := AllTrim( UI_GetProp( hCtrl, "cName" ) )
         if Empty( cCtrlName ); cCtrlName := "ctrl" + LTrim(Str(i)); endif
         AAdd( aCtrlMap, { hCtrl, cCtrlName } )
      next
   endif

   if hForm != 0
      nCount := UI_GetChildCount( hForm )
      for i := 1 to nCount
         hCtrl := UI_GetChild( hForm, i )
         if hCtrl == 0; loop; endif

         cCtrlName  := UI_GetProp( hCtrl, "cName" )
         cCtrlClass := UI_GetProp( hCtrl, "cClassName" )
         nType      := UI_GetType( hCtrl )
         if Empty( cCtrlName ); cCtrlName := "ctrl" + LTrim(Str(i)); endif

         // OF clause: "Self" or "::oFolder:aPages[N]" for paged children
         cOf := "Self"
         hOwner := UI_GetCtrlOwner( hCtrl )
         if ValType( hOwner ) == "N" .and. hOwner != 0
            nPg := UI_GetCtrlPage( hCtrl )
            for kk2 := 1 to Len( aCtrlMap )
               if aCtrlMap[kk2][1] == hOwner
                  cOf := "::o" + aCtrlMap[kk2][2] + ":aPages[" + ;
                         LTrim( Str( nPg + 1 ) ) + "]"
                  exit
               endif
            next
         endif

         cDatas += "   DATA o" + cCtrlName + "   // " + cCtrlClass + e

         nL := UI_GetProp( hCtrl, "nLeft" )
         nT := UI_GetProp( hCtrl, "nTop" )
         nCW := UI_GetProp( hCtrl, "nWidth" )
         nCH := UI_GetProp( hCtrl, "nHeight" )
         cText := UI_GetProp( hCtrl, "cText" )

         // Snapshot cCreate length so we can post-process only this slice
         nLen0 := Len( cCreate )

         do case
            case nType == CT_TABCONTROL2  // TFolder (33)
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' FOLDER ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aTabs" )
               if ! Empty( cVal )
                  cCreate += ' PROMPTS '
                  aHdrs := hb_ATokens( cVal, "|" )
                  for kk := 1 to Len( aHdrs )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + aHdrs[kk] + '"'
                  next
               endif
               cCreate += e
            case nType == 1
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' SAY ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + e
            case nType == 2
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GET ::o' + cCtrlName + ' VAR "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 3
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BUTTON ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 4
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' CHECKBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + e
            case nType == 5  // ComboBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' COMBOBOX ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aItems" )
               if ValType( cVal ) == "C" .and. ! Empty( cVal )
                  cCreate += ' ITEMS '
                  for kk := 1 to Len( hb_ATokens( cVal, "|" ) )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + hb_ATokens( cVal, "|" )[ kk ] + '"'
                  next
               endif
               cCreate += e
               nVal := UI_GetProp( hCtrl, "nItemIndex" )
               if ValType( nVal ) == "N" .and. nVal > 0
                  cCreate += '   ::o' + cCtrlName + ':Value := ' + LTrim( Str( nVal ) ) + e
               endif
            case nType == 7  // ListBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' LISTBOX ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aItems" )
               if ValType( cVal ) == "C" .and. ! Empty( cVal )
                  cCreate += ' ITEMS '
                  for kk := 1 to Len( hb_ATokens( cVal, "|" ) )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + hb_ATokens( cVal, "|" )[ kk ] + '"'
                  next
               endif
               cCreate += e
               nVal := UI_GetProp( hCtrl, "nItemIndex" )
               if ValType( nVal ) == "N" .and. nVal > 0
                  cCreate += '   ::o' + cCtrlName + ':Value := ' + LTrim( Str( nVal ) ) + e
               endif
            case nType == 6
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GROUPBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 79  // Browse
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BROWSE ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aColumns" )
               if ! Empty( cVal )
                  aHdrs := hb_ATokens( cVal, "|" )
                  cCreate += ' HEADERS '
                  for kk := 1 to Len( aHdrs )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + AllTrim( aHdrs[kk] ) + '"'
                  next
               endif
               nColCount := UI_BrowseColCount( hCtrl )
               if nColCount > 0
                  cCreate += ' COLSIZES '
                  for kk := 1 to nColCount
                     if kk > 1; cCreate += ', '; endif
                     aColProps := UI_BrowseGetColProps( hCtrl, kk - 1 )
                     nColW := 100
                     if Len( aColProps ) >= 3; nColW := aColProps[3][2]; endif
                     cCreate += LTrim( Str( nColW ) )
                  next
                  // Emit FOOTERS if any column has footer text
                  cVal := ""
                  for kk := 1 to nColCount
                     aColProps := UI_BrowseGetColProps( hCtrl, kk - 1 )
                     if Len( aColProps ) >= 5 .and. ! Empty( aColProps[5][2] )
                        cVal := "x"  // flag: has footers
                        exit
                     endif
                  next
                  if ! Empty( cVal )
                     cCreate += ' FOOTERS '
                     for kk := 1 to nColCount
                        if kk > 1; cCreate += ', '; endif
                        aColProps := UI_BrowseGetColProps( hCtrl, kk - 1 )
                        cVal := ""
                        if Len( aColProps ) >= 5; cVal := aColProps[5][2]; endif
                        cCreate += '"' + cVal + '"'
                     next
                  endif
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "cDataSource" )
               if ! Empty( cVal )
                  cCreate += '   ::o' + cCtrlName + ':cDataSource := "' + cVal + '"' + e
               endif
            case nType == 62  // WebView
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' WEBVIEW ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "cUrl" )
               if ! Empty( cVal )
                  cCreate += ' URL "' + cVal + '"'
               endif
               cCreate += e
            otherwise
               if nType >= CT_TIMER  // Non-visual component
                  cCreate += '   COMPONENT ::o' + cCtrlName + ' TYPE CT_' + ;
                     Upper( SubStr( cCtrlClass, 2 ) ) + ' OF Self  // ' + cCtrlClass + e
                  if nType == CT_TIMER
                     nInterval := UI_GetProp( hCtrl, "nInterval" )
                     if ValType( nInterval ) == "N" .and. nInterval != 1000
                        cCreate += '   ::o' + cCtrlName + ':nInterval := ' + LTrim( Str( nInterval ) ) + e
                     endif
                  endif
               else
                  cCreate += '   // ::o' + cCtrlName + ' (' + cCtrlClass + ') at ' + ;
                     LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                     LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
               endif
         endcase

         // Rewrite "OF Self" in the slice emitted above to "OF <cOf>" when
         // this control belongs to a TFolder page.
         if cOf != "Self" .and. Len( cCreate ) > nLen0
            cSlice := SubStr( cCreate, nLen0 + 1 )
            cSlice := StrTran( cSlice, " OF Self ", " OF " + cOf + " " )
            cCreate := Left( cCreate, nLen0 ) + cSlice
         endif

         // Emit nClrPane if non-default (default = 0xFFFFFFFF = 4294967295)
         nCtrlClr := UI_GetProp( hCtrl, "nClrPane" )
         if nCtrlClr != 4294967295 .and. nCtrlClr != 0
            cCreate += '   ::o' + cCtrlName + ':nClrPane := ' + LTrim( Str( nCtrlClr ) ) + e
         endif

         // Emit nClrText (Label/Edit/StaticText) if non-default
         if nType == CT_LABEL .or. nType == CT_EDIT .or. nType == 28 /*CT_MASKEDIT2*/ .or. ;
            nType == CT_LABELEDEDIT .or. nType == CT_STATICTEXT
            nCtrlClr := UI_GetProp( hCtrl, "nClrText" )
            if ValType( nCtrlClr ) == "N" .and. nCtrlClr != 4294967295
               cCreate += '   ::o' + cCtrlName + ':nClrText := ' + LTrim( Str( nCtrlClr ) ) + e
            endif
            // Emit nAlign if non-default (0=Left)
            cVal := UI_GetProp( hCtrl, "nAlign" )
            if ValType( cVal ) == "N" .and. cVal != 0
               cCreate += '   ::o' + cCtrlName + ':nAlign := ' + LTrim( Str( cVal ) ) + e
            endif
         endif

         // Emit lTransparent for labels when not default (.F. instead of default .T.)
         if nType == 1 .and. UI_GetProp( hCtrl, "lTransparent" ) == .F.
            cCreate += '   ::o' + cCtrlName + ':lTransparent := .F.' + e
         endif

         // Emit oFont if non-default (skip Linux/Windows defaults)
         cVal := UI_GetProp( hCtrl, "oFont" )
         if ! Empty( cVal ) .and. cVal != "System,12" .and. ;
            cVal != "Segoe UI,12" .and. cVal != "Segoe UI,9" .and. cVal != "Sans,12"
            cCreate += '   ::o' + cCtrlName + ':oFont := "' + cVal + '"' + e
         endif

         // Scan for event handlers matching this control
         // Pattern: METHOD ControlName + EventSuffix (e.g. Button1Click)
         aEvents := { "OnClick", "OnChange", "OnDblClick", "OnCreate", ;
                       "OnClose", "OnResize", "OnKeyDown", "OnKeyUp", ;
                       "OnMouseDown", "OnMouseUp", "OnEnter", "OnExit", ;
                       "OnTimer" }
         for j := 1 to Len( aEvents )
            cEvName := aEvents[j]
            cEvSuffix := SubStr( cEvName, 3 )  // "Click", "Change"...
            cHandlerName := cCtrlName + cEvSuffix
            if cHandlerName $ cExistingCode
               // Check if handler is a METHOD of the class or a standalone function
               if ( "METHOD " + cHandlerName ) $ cExistingCode
                  cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                     " := {|| ::" + cHandlerName + "() }" + e
               else
                  cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                     " := { || " + cHandlerName + "( Self ) }" + e
               endif
            endif
         next
      next
   endif

   // Scan form-level events (Form1Click, Form1Create, etc.)
   if ! Empty( cExistingCode )
      aEvents := { "OnClick", "OnDblClick", "OnCreate", "OnDestroy", ;
                    "OnShow", "OnHide", "OnClose", "OnCloseQuery", ;
                    "OnActivate", "OnDeactivate", "OnResize", "OnPaint", ;
                    "OnKeyDown", "OnKeyUp", "OnKeyPress", ;
                    "OnMouseDown", "OnMouseUp", "OnMouseMove" }
      for j := 1 to Len( aEvents )
         cEvName := aEvents[j]
         cEvSuffix := SubStr( cEvName, 3 )
         cHandlerName := cName + cEvSuffix
         if ( "function " + cHandlerName ) $ cExistingCode
            cEvents += "   ::" + cEvName + ;
               " := { || " + cHandlerName + "( Self ) }" + e
         endif
      next
   endif

   cCode += "// " + cName + ".prg" + e
   cCode += cSep
   cCode += e
   cCode += "CLASS " + cClass + " FROM TForm" + e
   cCode += e
   cCode += "   // IDE-managed Components" + e
   if ! Empty( cDatas ); cCode += cDatas; endif
   cCode += e
   cCode += "   // Event handlers" + e
   cCode += e
   cCode += "   METHOD CreateForm()" + e

   // Preserve user-declared METHOD lines from existing code
   if ! Empty( cExistingCode )
      aExLines := HB_ATokens( cExistingCode, Chr(10) )
      lInClass := .F.
      for j := 1 to Len( aExLines )
         cExLine := AllTrim( StrTran( aExLines[j], Chr(13), "" ) )
         if Upper( Left( cExLine, 6 ) ) == "CLASS " .and. Upper( cClass ) $ Upper( cExLine )
            lInClass := .T.
            loop
         endif
         if lInClass
            if Upper( Left( cExLine, 8 ) ) == "ENDCLASS"
               exit
            endif
            if Upper( Left( cExLine, 7 ) ) == "METHOD " .and. ;
               ! ( "CREATEFORM" $ Upper( cExLine ) )
               cCode += "   " + cExLine + e
            endif
         endif
      next
   endif

   cCode += e
   cCode += "ENDCLASS" + e
   cCode += cSep
   cCode += e
   cCode += "METHOD CreateForm() CLASS " + cClass + e
   cCode += e
   cCode += '   ::Title  := "' + cTitle + '"' + e
   cCode += "   ::Left   := " + LTrim(Str(nFL)) + e
   cCode += "   ::Top    := " + LTrim(Str(nFT)) + e
   cCode += "   ::Width  := " + LTrim(Str(nW)) + e
   cCode += "   ::Height := " + LTrim(Str(nH)) + e
   if nClr != 15790320
      cCode += "   ::Color  := " + LTrim(Str(nClr)) + e
   endif
   if ! Empty( cAppTitle )
      cCode += '   ::AppTitle := "' + cAppTitle + '"' + e
   endif
   if ! Empty( cCreate )
      cCode += e + cCreate
   endif
   if ! Empty( cEvents )
      cCode += e
      cCode += "   // Event wiring" + e
      cCode += cEvents
   endif
   cCode += e
   cCode += "return nil" + e
   cCode += cSep

return cCode

static function SaveActiveFormCode()
   if nActiveForm < 1 .or. nActiveForm > Len( aForms ); return nil; endif
   aForms[ nActiveForm ][ 3 ] := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
return nil

// Delete an event handler function from the active form's code
function INS_DeleteHandler( cHandler )

   local cCode, cNew, nStart, nEnd, nLen, cSearch
   local cLine, nLineStart, nLineEnd
   local nSepStart, nSepLineStart

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
      return nil
   endif

   // Get current code from the editor tab
   cCode := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   cSearch := "static function " + cHandler

   // Find the function (case-insensitive)
   nStart := At( Lower( cSearch ), Lower( cCode ) )
   if nStart == 0
      cSearch := "function " + cHandler
      nStart := At( Lower( cSearch ), Lower( cCode ) )
   endif
   if nStart == 0
      return nil
   endif

   // Find end of function: look for "return" line
   nLen := Len( cCode )
   nEnd := nStart + Len( cSearch )

   do while nEnd < nLen
      if SubStr( cCode, nEnd, 1 ) == Chr(10)
         nLineStart := nEnd + 1
         nLineEnd := At( Chr(10), SubStr( cCode, nLineStart ) )
         if nLineEnd > 0
            cLine := AllTrim( SubStr( cCode, nLineStart, nLineEnd - 1 ) )
         else
            cLine := AllTrim( SubStr( cCode, nLineStart ) )
         endif
         cLine := Lower( cLine )
         if cLine == "return nil" .or. cLine == "return" .or. Left( cLine, 7 ) == "return "
            if nLineEnd > 0
               nEnd := nLineStart + nLineEnd
               do while nEnd < nLen .and. ;
                  ( SubStr( cCode, nEnd, 1 ) == Chr(10) .or. ;
                    SubStr( cCode, nEnd, 1 ) == Chr(13) )
                  nEnd++
               enddo
            else
               nEnd := nLen
            endif
            exit
         endif
      endif
      nEnd++
   enddo

   // Remove separator comment (//----) before the function
   if nStart > 3
      nSepStart := nStart - 1
      do while nSepStart > 1 .and. ;
         ( SubStr( cCode, nSepStart, 1 ) == Chr(10) .or. ;
           SubStr( cCode, nSepStart, 1 ) == Chr(13) )
         nSepStart--
      enddo
      nSepLineStart := nSepStart
      do while nSepLineStart > 1 .and. SubStr( cCode, nSepLineStart - 1, 1 ) != Chr(10)
         nSepLineStart--
      enddo
      if Left( SubStr( cCode, nSepLineStart, nSepStart - nSepLineStart + 1 ), 3 ) == "//-"
         nStart := nSepLineStart
      endif
   endif

   // Remove the function block
   cNew := Left( cCode, nStart - 1 ) + SubStr( cCode, nEnd )

   // Update editor and form data
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, cNew )
   aForms[ nActiveForm ][ 3 ] := cNew

   // Re-sync to remove event binding
   SyncDesignerToCode()

return nil

// Return all editor code for inspector event handler checking
function INS_GetAllCode()

   local cAll := "", i

   cAll := CodeEditorGetTabText( hCodeEditor, 1 )  // Project1.prg
   for i := 1 to Len( aForms )
      cAll += aForms[i][3]  // Form code from memory
      cAll += CodeEditorGetTabText( hCodeEditor, i + 1 )  // Editor tab
   next
   for i := 1 to Len( aModules )
      cAll += CodeEditorGetTabText( hCodeEditor, 1 + Len(aForms) + i )
   next

return cAll

// Determine what kind of tab is at position nTab
static function TabInfo( nTab )

   local nF := Len( aForms )
   local nM := Len( aModules )

   if nTab == 1
      return { "project", 0 }
   elseif nTab <= nF + 1
      return { "form", nTab - 1 }
   elseif nTab <= nF + nM + 1
      return { "module", nTab - nF - 1 }
   endif

return { "openfile", nTab - nF - nM - 1 }

static function OnEventDblClick( hCtrl, cEvent )

   local cName, cClass, cHandler, cCode, cDecl, e, cSep, nCursorOfs

   e := Chr(10)
   cSep := "//" + Replicate( "-", 68 ) + e

   cName  := UI_GetProp( hCtrl, "cName" )
   cClass := UI_GetProp( hCtrl, "cClassName" )
   if Empty( cName )
      cName := If( cClass == "TForm", "Form1", "ctrl" )
   endif

   cHandler := cName + SubStr( cEvent, 3 )

   // Ensure we're on the form's tab in the editor
   if nActiveForm > 0
      CodeEditorSelectTab( hCodeEditor, nActiveForm + 1 )
   endif

   if CodeEditorGotoFunction( hCodeEditor, cHandler )
      return cHandler
   endif

   cCode := cSep
   cCode += "static function " + cHandler + "( oForm )" + e
   cCode += e
   cCode += "   " + e
   cCode += e
   cCode += "return nil" + e

   nCursorOfs := Len( cSep ) + ;
                 Len( "static function " + cHandler + "( oForm )" ) + ;
                 Len( e ) + Len( e ) + 3

   CodeEditorAppendText( hCodeEditor, cCode, nCursorOfs )

   // Regenerate CreateForm to include event wiring (preserves METHOD implementations)
   SyncDesignerToCode()

   // Re-position cursor on the new handler (SyncDesignerToCode may have moved it)
   CodeEditorGotoFunction( hCodeEditor, cHandler )

   // Refresh inspector to show handler name in Events tab
   InspectorRefresh( hCtrl )

return cHandler

static function OnComponentDrop( hForm, nType, nL, nT, nW, nH )

   local cName, nCount, hCtrl
   static aCnt := nil
   static aNames := { ;
      "Label", "Edit", "Button", "CheckBox", "ComboBox", "GroupBox", ;
      "ListBox", "RadioButton", "", "", "", "BitBtn", "SpeedButton", ;
      "Image", "Shape", "Bevel", "", "", "", "TreeView", "ListView", ;
      "ProgressBar", "RichEdit", "Memo", "Panel", "ScrollBar", ;
      "SpeedButton", "MaskEdit", "StringGrid", "ScrollBox", ;
      "StaticText", "LabeledEdit", "Folder", "TrackBar", ;
      "SpinButton", "DatePicker", "Calendar", "Timer", "PaintBox", ;
      "OpenDialog", "SaveDialog", "FontDialog", "ColorDialog", ;
      "FindDialog", "ReplaceDialog", ;
      "OpenAI", "Gemini", "Claude", "DeepSeek", "Grok", "Ollama", "Transformer", ;
      "DBFTable", "MySQL", "MariaDB", "PostgreSQL", "SQLite", ;
      "Firebird", "SQLServer", "Oracle", "MongoDB", "WebView", ;
      "Thread", "Mutex", "Semaphore", "CriticalSection", ;
      "ThreadPool", "AtomicInt", "CondVar", "Channel", ;
      "WebServer", "WebSocket", "HttpClient", "FtpClient", ;
      "SmtpClient", "TcpServer", "TcpClient", "UdpSocket", ;
      "Browse", "DBGrid", "DBNavigator", "DBText", ;
      "DBEdit", "DBComboBox", "DBCheckBox", "DBImage", ;
      "", "", "", "Preprocessor", "ScriptEngine", ;
      "ReportDesigner", "Barcode", "PDFGenerator", "ExcelExport", ;
      "AuditLog", "Permissions", "Currency", "TaxEngine", ;
      "Dashboard", "Scheduler", ;
      "Printer", "Report", "Labels", "PrintPreview", ;
      "PageSetup", "PrintDialog", "ReportViewer", "BarcodePrinter", ;
      "Whisper", "Embeddings", ;
      "Python", "Swift", "Go", "Node", "Rust", "Java", "DotNet", "Lua", "Ruby", ;
      "GitRepo", "GitCommit", "GitBranch", "GitLog", "GitDiff", ;
      "GitRemote", "GitStash", "GitTag", "GitBlame", "GitMerge" }

   // Push undo before adding control
   UI_FormUndoPush( hForm )

   if aCnt == nil; aCnt := Array(120); AFill(aCnt,0); endif
   if nType < 1 .or. nType > Len(aNames) .or. Empty(aNames[nType]); return nil; endif
   aCnt[nType]++
   cName := aNames[nType] + LTrim(Str(aCnt[nType]))

   nCount := UI_GetChildCount( hForm )
   hCtrl  := UI_GetChild( hForm, nCount )
   if hCtrl != 0
      UI_SetProp( hCtrl, "cName", cName )
      // Folder: seed default tabs so runtime + codegen have something
      if nType == CT_TABCONTROL2 .and. Empty( UI_GetProp( hCtrl, "aTabs" ) )
         UI_SetProp( hCtrl, "aTabs", "Tab 1|Tab 2|Tab 3" )
      endif
   endif

   SyncDesignerToCode()

   // Refresh inspector and select the new component
   InspectorPopulateCombo( hForm )
   INS_ComboSelect( _InsGetData(), nCount )
   InspectorRefresh( hCtrl )

return nil

static function WireDesignForm()

   UI_SetDesignForm( oDesignForm:hCpp )

   UI_OnSelChange( oDesignForm:hCpp, ;
      { |hCtrl| OnDesignSelChange( hCtrl ) } )

   UI_FormOnComponentDrop( oDesignForm:hCpp, ;
      { |hForm, nType, nL, nT, nW, nH| OnComponentDrop( hForm, nType, nL, nT, nW, nH ) } )

   oDesignForm:OnResize := { || SyncDesignerToCode(), ;
      InspectorRefresh( oDesignForm:hCpp ) }

return nil

static function SyncDesignerToCode()

   local cNewCode, cOldCode, cMethods, nPos, nPos2
   local cSep := "//" + Replicate( "-", 68 )

   if nActiveForm < 1 .or. nActiveForm > Len( aForms ); return nil; endif

   // If already syncing from code→form, don't sync back form→code
   if lSyncingFromCode; return nil; endif

   lSyncingFromCode := .t.

   // Get existing code to preserve METHOD implementations
   cOldCode := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )

   // Find METHOD implementations after CreateForm:
   // Look for "METHOD CreateForm()", then find "return nil" after it,
   // then the separator after that = end of generated code
   cMethods := ""
   nPos := At( "METHOD CreateForm()", cOldCode )
   if nPos > 0
      // Find "return nil" after CreateForm
      nPos2 := At( "return nil", SubStr( cOldCode, nPos ) )
      if nPos2 > 0
         nPos := nPos + nPos2 - 1 + Len( "return nil" )
         // Find separator after return nil
         nPos2 := At( cSep, SubStr( cOldCode, nPos ) )
         if nPos2 > 0
            nPos := nPos + nPos2 - 1 + Len( cSep )
            // Everything after = user METHOD implementations
            if nPos <= Len( cOldCode )
               cMethods := SubStr( cOldCode, nPos )
               do while Left( cMethods, 1 ) == Chr(10) .or. Left( cMethods, 1 ) == Chr(13)
                  cMethods := SubStr( cMethods, 2 )
               enddo
            endif
         endif
      endif
   endif

   // Regenerate CLASS + CreateForm
   cNewCode := RegenerateFormCode( aForms[ nActiveForm ][ 1 ], oDesignForm:hCpp )

   // Append preserved METHOD implementations
   if ! Empty( cMethods )
      cNewCode += Chr(13) + Chr(10) + cMethods
   endif

   aForms[ nActiveForm ][ 3 ] := cNewCode
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, cNewCode )

   lSyncingFromCode := .f.

return nil

// Re-wire event handlers in all form code before building.
// Scans for handler functions (e.g. Timer1Timer, Button1Click) and ensures
// the corresponding event assignment exists in CreateForm().
// Works purely on code text — does NOT need the visual designer.
static function RewireAllFormEvents()

   local i, cCode, cCreateEnd, nPos, nPos2, nRetPos
   local cBefore, cAfter, cEvents, e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 )
   local aEvents := { "OnClick", "OnChange", "OnDblClick", "OnCreate", ;
                       "OnClose", "OnResize", "OnKeyDown", "OnKeyUp", ;
                       "OnMouseDown", "OnMouseUp", "OnEnter", "OnExit", ;
                       "OnTimer" }
   local j, cEvName, cEvSuffix, cHandlerName
   local aComps, nC, cLine, cCtrlName

   for i := 1 to Len( aForms )
      cCode := aForms[i][3]
      if Empty( cCode ); loop; endif

      // Find "return nil" that ends CreateForm()
      nPos := At( "METHOD CreateForm()", cCode )
      if nPos == 0; loop; endif
      nRetPos := At( "return nil", SubStr( cCode, nPos ) )
      if nRetPos == 0; loop; endif
      nRetPos := nPos + nRetPos - 1  // absolute position of "return nil"

      // Collect component names from COMPONENT and @ lines
      aComps := {}
      nC := 1
      do while nC < nRetPos
         nPos2 := At( "::o", SubStr( cCode, nC, nRetPos - nC ) )
         if nPos2 == 0; exit; endif
         nPos2 := nC + nPos2 - 1 + 3  // skip "::o"
         cCtrlName := ""
         do while nPos2 <= Len( cCode ) .and. ( IsAlpha( SubStr( cCode, nPos2, 1 ) ) .or. ;
               IsDigit( SubStr( cCode, nPos2, 1 ) ) .or. SubStr( cCode, nPos2, 1 ) == "_" )
            cCtrlName += SubStr( cCode, nPos2, 1 )
            nPos2++
         enddo
         if ! Empty( cCtrlName ) .and. AScan( aComps, cCtrlName ) == 0
            AAdd( aComps, cCtrlName )
         endif
         nC := nPos2
      enddo

      // Remove existing "// Event wiring" block (between last COMPONENT/control and return nil)
      nPos2 := At( "   // Event wiring", cCode )
      if nPos2 > 0 .and. nPos2 < nRetPos
         cBefore := Left( cCode, nPos2 - 1 )
         cAfter  := SubStr( cCode, nRetPos )
         // Trim trailing blank lines from cBefore
         do while Right( cBefore, 2 ) == e
            cBefore := Left( cBefore, Len( cBefore ) - 2 )
         enddo
         cCode := cBefore + e + e + cAfter
         // Recalculate nRetPos
         nRetPos := At( "return nil", cCode )
         if nRetPos == 0; loop; endif
      endif

      // Build new event wiring block by scanning for handler functions
      cEvents := ""
      for nC := 1 to Len( aComps )
         cCtrlName := aComps[nC]
         for j := 1 to Len( aEvents )
            cEvName := aEvents[j]
            cEvSuffix := SubStr( cEvName, 3 )
            cHandlerName := cCtrlName + cEvSuffix
            if cHandlerName $ cCode
               if ( "METHOD " + cHandlerName ) $ cCode
                  cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                     " := {|| ::" + cHandlerName + "() }" + e
               else
                  cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                     " := { || " + cHandlerName + "( Self ) }" + e
               endif
            endif
         next
      next

      // Also scan form-level events
      for j := 1 to Len( aEvents )
         cEvName := aEvents[j]
         cEvSuffix := SubStr( cEvName, 3 )
         cHandlerName := aForms[i][1] + cEvSuffix
         if ( "function " + cHandlerName ) $ cCode
            // Check it's not already wired
            if ! ( "::" + cEvName + " :=" ) $ Left( cCode, nRetPos )
               cEvents += "   ::" + cEvName + ;
                  " := { || " + cHandlerName + "( Self ) }" + e
            endif
         endif
      next

      // Inject event wiring block before "return nil"
      if ! Empty( cEvents )
         cBefore := Left( cCode, nRetPos - 1 )
         cAfter  := SubStr( cCode, nRetPos )
         // Trim trailing blank lines
         do while Right( cBefore, 2 ) == e
            cBefore := Left( cBefore, Len( cBefore ) - 2 )
         enddo
         cCode := cBefore + e + e + "   // Event wiring" + e + cEvents + e + cAfter
      endif

      aForms[i][3] := cCode
   next

return nil

static function OnEditorTabChange( hEd, nTab )

   local nFormIdx

   if nTab > 1
      nFormIdx := nTab - 1
      if nFormIdx != nActiveForm .and. nFormIdx <= Len( aForms )
         SwitchToForm( nFormIdx )
      endif
   endif

return nil

// Live sync: code editor → form designer + inspector (debounced, 500ms)
static function OnEditorTextChange( hEd, nTab )

   local nFormIdx, cCode, hForm

   HB_SYMBOL_UNUSED( hEd )

   // Avoid re-entrant loop (SyncDesignerToCode updates editor text)
   if lSyncingFromCode
      return nil
   endif

   // Only sync form tabs (tab 1 = project, tab 2+ = forms)
   if nTab <= 1
      return nil
   endif

   nFormIdx := nTab - 1
   if nFormIdx < 1 .or. nFormIdx > Len( aForms )
      return nil
   endif

   // Read current editor content for this tab
   cCode := CodeEditorGetTabText( hCodeEditor, nTab )
   if Empty( cCode )
      return nil
   endif

   // Skip rebuild if the text hasn't actually changed since last sync.
   // Otherwise debounced notifications from programmatic SCI_SETTEXT (load,
   // tab switch) destroy live HBControls and invalidate inspector combo map.
   if cCode == aForms[ nFormIdx ][ 3 ]
      return nil
   endif

   hForm := aForms[ nFormIdx ][ 2 ]:hCpp
   if hForm == 0
      return nil
   endif

   lSyncingFromCode := .t.

   // Remove existing child controls before re-parsing
   UI_FormClearChildren( hForm )

   // Re-parse code and rebuild form controls
   RestoreFormFromCode( hForm, cCode )

   // Update stored code
   aForms[ nFormIdx ][ 3 ] := cCode

   // Refresh inspector with updated properties
   InspectorRefresh( hForm )

   lSyncingFromCode := .f.

return nil

static function SwitchToForm( nIdx )

   if nIdx < 1 .or. nIdx > Len( aForms ); return nil; endif

   if nActiveForm > 0 .and. nActiveForm != nIdx
      SaveActiveFormCode()
   endif

   nActiveForm := nIdx
   oDesignForm := aForms[ nIdx ][ 2 ]

   UI_SetDesignForm( oDesignForm:hCpp )
   UI_FormBringToFront( oDesignForm:hCpp )

   CodeEditorSelectTab( hCodeEditor, nIdx + 1 )

   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

return nil

// Toggle Form/Code: if form is in front bring code editor, otherwise bring form
static function ToggleFormCode()

   if oDesignForm == nil
      return nil
   endif

   if UI_FormIsKeyWindow( oDesignForm:hCpp )
      // Form is the active window — switch to code editor
      CodeEditorBringToFront( hCodeEditor )
   else
      // Code editor (or other) is active — switch to design form
      UI_FormBringToFront( oDesignForm:hCpp )
   endif

return nil

static function MenuNewForm()

   local nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop

   SaveActiveFormCode()

   // Hide current form (use Hide, not Close — Close destroys the window)
   if nActiveForm > 0
      UI_FormHide( aForms[ nActiveForm ][ 2 ]:hCpp )
   endif

   nInsW := Int( nScreenW * 0.18 ) + 20
   nInsTop := GTK_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 1
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 ) + Len(aForms) * 20
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 ) + Len(aForms) * 20

   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   UI_SetDesignForm( oDesignForm:hCpp )
   oDesignForm:Show()

   WireDesignForm()

   CodeEditorAddTab( hCodeEditor, aForms[ nActiveForm ][ 1 ] + ".prg" )
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, aForms[ nActiveForm ][ 3 ] )
   CodeEditorSelectTab( hCodeEditor, nActiveForm + 1 )

   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )

   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

return nil

static function MenuViewForms()

   local aNames := {}, i, nSel

   for i := 1 to Len( aForms )
      AAdd( aNames, aForms[i][1] )
   next

   nSel := GTK_SelectFromList( "View Forms", aNames )
   if nSel > 0
      SwitchToForm( nSel )
   endif

return nil

// Add a standalone .prg module to the project
static function MenuAddModule()

   local cFile, cName, cCode, i, nTabPos

   cFile := GTK_OpenFileDialog( "Add Module to Project", "prg" )
   if Empty( cFile ); return nil; endif

   cName := SubStr( cFile, RAt( "/", cFile ) + 1 )
   if "." $ cName
      cName := Left( cName, At( ".", cName ) - 1 )
   endif

   // Check duplicates in forms and modules
   for i := 1 to Len( aForms )
      if Lower( aForms[i][1] ) == Lower( cName )
         MsgInfo( cName + " is already in the project (as a form)" )
         return nil
      endif
   next
   for i := 1 to Len( aModules )
      if Lower( aModules[i][1] ) == Lower( cName )
         MsgInfo( cName + " is already in the project (as a module)" )
         return nil
      endif
   next

   cCode := hb_MemoRead( cFile )
   if Empty( cCode )
      cCode := "// " + cName + ".prg" + Chr(10)
   endif

   AAdd( aModules, { cName, cCode, cFile } )

   nTabPos := 1 + Len( aForms ) + Len( aModules )
   CodeEditorAddTab( hCodeEditor, cName + ".prg" )
   CodeEditorSetTabText( hCodeEditor, nTabPos, cCode )
   CodeEditorSelectTab( hCodeEditor, nTabPos )

return nil

// Open a .prg file for viewing/editing (not added to project)
static function MenuOpenFile()

   local cFile, cName, cCode, i, nTabPos

   cFile := GTK_OpenFileDialog( "Open File", "prg" )
   if Empty( cFile ); return nil; endif

   cName := SubStr( cFile, RAt( "/", cFile ) + 1 )
   if "." $ cName
      cName := Left( cName, At( ".", cName ) - 1 )
   endif

   // Check if already open
   for i := 1 to Len( aOpenFiles )
      if Lower( aOpenFiles[i][3] ) == Lower( cFile )
         CodeEditorSelectTab( hCodeEditor, 1 + Len(aForms) + Len(aModules) + i )
         return nil
      endif
   next

   cCode := hb_MemoRead( cFile )
   if Empty( cCode )
      MsgInfo( "Could not read file: " + cFile )
      return nil
   endif

   AAdd( aOpenFiles, { cName, cCode, cFile } )

   nTabPos := 1 + Len( aForms ) + Len( aModules ) + Len( aOpenFiles )
   CodeEditorAddTab( hCodeEditor, cName + ".prg" )
   CodeEditorSetTabText( hCodeEditor, nTabPos, cCode )
   CodeEditorSelectTab( hCodeEditor, nTabPos )

return nil

// Close the current open-file tab (only for open files, not forms/modules)
static function MenuCloseFile()

   local nTab, aInfo, nIdx

   nTab := CodeEditorGetActiveTab( hCodeEditor )
   aInfo := TabInfo( nTab )

   if aInfo[1] != "openfile"
      MsgInfo( "Only open files can be closed. Use 'Remove from Project' for forms and modules." )
      return nil
   endif

   nIdx := aInfo[2]
   if nIdx < 1 .or. nIdx > Len( aOpenFiles )
      return nil
   endif

   CodeEditorRemoveTab( hCodeEditor, nTab )

   ADel( aOpenFiles, nIdx )
   ASize( aOpenFiles, Len(aOpenFiles) - 1 )

return nil

static function DestroyAllForms()

   local i

   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next

return nil

// === Toolbar actions ===

static function TBNew()

   local i, nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop

   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0
   aModules := {}
   aOpenFiles := {}

   nInsW := Int( nScreenW * 0.18 ) + 20
   nInsTop := GTK_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 1
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 )
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 )

   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   UI_SetDesignForm( oDesignForm:hCpp )
   oDesignForm:Show()

   WireDesignForm()

   CodeEditorClearTabs( hCodeEditor )
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
   CodeEditorAddTab( hCodeEditor, "Form1.prg" )
   CodeEditorSetTabText( hCodeEditor, 2, aForms[1][3] )
   CodeEditorSelectTab( hCodeEditor, 2 )
   cCurrentFile := ""

   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

return nil

// Restore visual controls on a design form by parsing the form .prg code
static function RestoreFormFromCode( hForm, cCode )

   local aLines, cLine, cTrim, i, nType
   local nT, nL, nW, nH, cText, cName, hCtrl
   local nPos, nPos2, cTitle, cVal, kk, nCount, cTypeStr
   local cFolderName, hFolder, nPageIdx, kkF, hChildN

   if Empty( cCode ) .or. hForm == 0
      return nil
   endif

   aLines := HB_ATokens( cCode, Chr(10) )

   for i := 1 to Len( aLines )
      cLine := aLines[i]
      cTrim := AllTrim( cLine )

      // Parse form properties: ::Title, ::Width, ::Height, ::Left, ::Top, ::Color
      if '::Title' $ cTrim .and. ':=' $ cTrim
         nPos := At( '"', cTrim )
         nPos2 := RAt( '"', cTrim )
         if nPos > 0 .and. nPos2 > nPos
            cTitle := SubStr( cTrim, nPos + 1, nPos2 - nPos - 1 )
            UI_SetProp( hForm, "cText", cTitle )
         endif
         loop
      endif
      if '::AppTitle' $ cTrim .and. ':=' $ cTrim
         nPos := At( '"', cTrim )
         nPos2 := RAt( '"', cTrim )
         if nPos > 0 .and. nPos2 > nPos
            UI_SetProp( hForm, "cAppTitle", SubStr( cTrim, nPos + 1, nPos2 - nPos - 1 ) )
         endif
         loop
      endif
      if '::Width' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nWidth", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::Height' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nHeight", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::Left' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nLeft", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::Top' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nTop", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::Color' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nClrPane", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif

      // Parse non-visual components: COMPONENT ::oName TYPE nType OF Self
      if Left( Upper( cTrim ), 10 ) == "COMPONENT "
         nPos := At( "::o", cTrim )
         if nPos > 0
            cName := SubStr( cTrim, nPos + 3 )
            nPos2 := At( " ", cName )
            if nPos2 > 0; cName := Left( cName, nPos2 - 1 ); endif
            nPos := At( "TYPE ", Upper( cTrim ) )
            if nPos > 0
               cTypeStr := AllTrim( SubStr( cTrim, nPos + 5 ) )
               nPos2 := At( " ", cTypeStr )
               if nPos2 > 0; cTypeStr := Left( cTypeStr, nPos2 - 1 ); endif
               if Left( cTypeStr, 3 ) == "CT_"
                  nType := ComponentTypeFromName( cTypeStr )
               else
                  nType := Val( cTypeStr )
               endif
               if nType >= 38
                  hCtrl := UI_DropNonVisual( hForm, nType, cName )
               endif
            endif
         endif
         loop
      endif

      // Parse control creation lines: @ nT, nL KEYWORD ::oName ...
      if ! ( Left( cTrim, 2 ) == "@ " )
         loop
      endif

      // Extract coordinates: @ nT, nL
      nT := Val( SubStr( cTrim, 3 ) )
      nPos := At( ",", cTrim )
      if nPos == 0; loop; endif
      nL := Val( SubStr( cTrim, nPos + 1 ) )

      // Extract control name from ::oName
      nPos := At( "::o", cTrim )
      if nPos == 0; loop; endif
      cName := SubStr( cTrim, nPos + 3 )
      nPos2 := At( " ", cName )
      if nPos2 > 0; cName := Left( cName, nPos2 - 1 ); endif

      // Extract text from PROMPT "..."
      cText := ""
      nPos := At( 'PROMPT "', cTrim )
      if nPos > 0
         nPos2 := At( '"', SubStr( cTrim, nPos + 8 ) )
         if nPos2 > 0
            cText := SubStr( cTrim, nPos + 8, nPos2 - 1 )
         endif
      endif

      // Extract SIZE w, h  or  SIZE w
      nW := 80
      nH := 24
      nPos := At( "SIZE ", cTrim )
      if nPos > 0
         nW := Val( SubStr( cTrim, nPos + 5 ) )
         nPos2 := At( ",", SubStr( cTrim, nPos + 5 ) )
         if nPos2 > 0
            nH := Val( SubStr( cTrim, nPos + 5 + nPos2 ) )
         endif
      endif
      if nH < 1; nH := 24; endif

      // OF ::oFolder:aPages[N] -> set pending page owner BEFORE creating the
      // control so AddChild tags it with (FPageOwner, FPageIndex).
      if At( "OF ::o", cTrim ) > 0 .and. ":aPages[" $ cTrim
         cVal := SubStr( cTrim, At( "OF ::o", cTrim ) + 6 )
         cFolderName := Left( cVal, At( ":aPages[", cVal ) - 1 )
         nPageIdx    := Val( SubStr( cVal, At( ":aPages[", cVal ) + 8 ) )
         hFolder := 0
         hChildN := UI_GetChildCount( hForm )
         for kkF := 1 to hChildN
            if AllTrim( UI_GetProp( UI_GetChild( hForm, kkF ), "cName" ) ) == cFolderName
               hFolder := UI_GetChild( hForm, kkF )
               exit
            endif
         next
         if hFolder != 0
            UI_SetPendingPageOwner( hFolder, nPageIdx - 1 )
         endif
      endif

      // Determine control type and create it
      hCtrl := 0
      do case
         case " FOLDER " $ Upper( cTrim )
            hCtrl := UI_TabControlNew( hForm, nL, nT, nW, nH )
            nPos := At( "PROMPTS ", Upper( cTrim ) )
            if nPos > 0 .and. hCtrl != 0
               cText := SubStr( cTrim, nPos + 8 )
               cVal := ""
               do while ! Empty( cText )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  cText := SubStr( cText, nPos2 + 1 )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  if ! Empty( cVal ); cVal += "|"; endif
                  cVal += Left( cText, nPos2 - 1 )
                  cText := SubStr( cText, nPos2 + 1 )
               enddo
               if ! Empty( cVal )
                  UI_SetProp( hCtrl, "aTabs", cVal )
               endif
            endif
         case " SAY " $ Upper( cTrim )
            hCtrl := UI_LabelNew( hForm, cText, nL, nT, nW, nH )
         case " BUTTON " $ Upper( cTrim )
            hCtrl := UI_ButtonNew( hForm, cText, nL, nT, nW, nH )
         case " GET " $ Upper( cTrim )
            // Extract VAR "..."
            cText := ""
            nPos := At( 'VAR "', cTrim )
            if nPos > 0
               nPos2 := At( '"', SubStr( cTrim, nPos + 5 ) )
               if nPos2 > 0; cText := SubStr( cTrim, nPos + 5, nPos2 - 1 ); endif
            endif
            hCtrl := UI_EditNew( hForm, cText, nL, nT, nW, nH )
         case " CHECKBOX " $ Upper( cTrim )
            hCtrl := UI_CheckBoxNew( hForm, cText, nL, nT, nW, nH )
         case " COMBOBOX " $ Upper( cTrim )
            hCtrl := UI_ComboBoxNew( hForm, nL, nT, nW, nH )
         case " GROUPBOX " $ Upper( cTrim )
            hCtrl := UI_GroupBoxNew( hForm, cText, nL, nT, nW, nH )
         case " LISTBOX " $ Upper( cTrim )
            hCtrl := UI_ListBoxNew( hForm, nL, nT, nW, nH )
         case " RADIOBUTTON " $ Upper( cTrim )
            hCtrl := UI_RadioButtonNew( hForm, cText, nL, nT, nW, nH )
         case " MEMO " $ Upper( cTrim )
            hCtrl := UI_MemoNew( hForm, "", nL, nT, nW, nH )
         case " WEBVIEW " $ Upper( cTrim )
            hCtrl := UI_WebViewNew( hForm, nL, nT, nW, nH )
            // Extract URL "..."
            nPos := At( 'URL "', cTrim )
            if nPos > 0 .and. hCtrl != 0
               nPos2 := At( '"', SubStr( cTrim, nPos + 5 ) )
               if nPos2 > 0
                  UI_SetProp( hCtrl, "cUrl", SubStr( cTrim, nPos + 5, nPos2 - 1 ) )
               endif
            endif
         case " BROWSE " $ Upper( cTrim )
            hCtrl := UI_BrowseNew( hForm, nL, nT, nW, nH )
            // Extract HEADERS "col1", "col2", "col3"
            nPos := At( "HEADERS ", Upper( cTrim ) )
            if nPos > 0
               cText := SubStr( cTrim, nPos + 8 )
               // Limit to text before COLSIZES/FOOTERS so we don't consume footer strings
               nPos2 := At( "COLSIZES ", Upper( cText ) )
               if nPos2 > 0; cText := Left( cText, nPos2 - 1 ); endif
               nPos2 := At( "FOOTERS ", Upper( cText ) )
               if nPos2 > 0; cText := Left( cText, nPos2 - 1 ); endif
               cVal := ""
               do while ! Empty( cText )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  cText := SubStr( cText, nPos2 + 1 )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  if ! Empty( cVal ); cVal += "|"; endif
                  cVal += Left( cText, nPos2 - 1 )
                  cText := SubStr( cText, nPos2 + 1 )
               enddo
               if hCtrl != 0 .and. ! Empty( cVal )
                  UI_SetProp( hCtrl, "aColumns", cVal )
               endif
            endif
            // Extract COLSIZES n1, n2, n3
            nPos := At( "COLSIZES ", Upper( cTrim ) )
            if nPos > 0 .and. hCtrl != 0
               cText := SubStr( cTrim, nPos + 9 )
               kk := 0
               do while ! Empty( cText )
                  cText := LTrim( cText )
                  if ! IsDigit( Left( cText, 1 ) ); exit; endif
                  UI_BrowseSetColProp( hCtrl, kk, "nWidth", Val( cText ) )
                  kk++
                  nPos2 := At( ",", cText )
                  if nPos2 == 0; exit; endif
                  cText := SubStr( cText, nPos2 + 1 )
               enddo
            endif
            // Extract FOOTERS "text1", "text2", "text3"
            nPos := At( "FOOTERS ", Upper( cTrim ) )
            if nPos > 0 .and. hCtrl != 0
               cText := SubStr( cTrim, nPos + 8 )
               kk := 0
               do while ! Empty( cText )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  cText := SubStr( cText, nPos2 + 1 )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  UI_BrowseSetColProp( hCtrl, kk, "cFooterText", Left( cText, nPos2 - 1 ) )
                  kk++
                  cText := SubStr( cText, nPos2 + 1 )
               enddo
            endif
      endcase

      // Set the control name
      if hCtrl != 0
         UI_SetProp( hCtrl, "cName", cName )
      endif
   next

   // Second pass: apply property assignments like ::oCtrlName:prop := value
   for i := 1 to Len( aLines )
      cTrim := StrTran( AllTrim( aLines[i] ), Chr(13), "" )
      if Left( cTrim, 2 ) == "//"; loop; endif
      if ! ( Left( cTrim, 3 ) == "::o" ) .or. ! ( ":=" $ cTrim ); loop; endif
      // Must have a second ":" for the property (::oName:prop := value)
      nPos := At( ":", SubStr( cTrim, 4 ) )
      if nPos == 0; loop; endif
      cName := SubStr( cTrim, 4, nPos - 1 )
      cText := SubStr( cTrim, 4 + nPos )
      nPos2 := At( ":=", cText )
      if nPos2 == 0; loop; endif
      cVal := AllTrim( Left( cText, nPos2 - 1 ) )
      cText := AllTrim( SubStr( cText, nPos2 + 2 ) )

      // Find the control by name
      hCtrl := 0
      nCount := UI_GetChildCount( hForm )
      for kk := 1 to nCount
         if AllTrim( UI_GetProp( UI_GetChild( hForm, kk ), "cName" ) ) == cName
            hCtrl := UI_GetChild( hForm, kk )
            exit
         endif
      next
      if hCtrl == 0; loop; endif

      if cVal == "nClrPane" .or. cVal == "Color"
         UI_SetProp( hCtrl, "nClrPane", Val( cText ) )
      elseif cVal == "nClrText"
         UI_SetProp( hCtrl, "nClrText", Val( cText ) )
      elseif cVal == "lTransparent"
         UI_SetProp( hCtrl, "lTransparent", AllTrim( cText ) == ".T." )
      elseif cVal == "nAlign"
         UI_SetProp( hCtrl, "nAlign", Val( cText ) )
      elseif cVal == "oFont"
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, "oFont", cText )
      elseif cVal == "cDataSource"
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, "cDataSource", cText )
      endif
   next

return nil

static function TBOpen()
   local cFile := GTK_OpenFileDialog( "Open HbBuilder Project", "hbp" )
   if Empty( cFile ); return nil; endif
   OpenProjectFile( cFile )
return nil

static function OpenProjectFile( cFile )

   local cContent, cDir, aLines, i, lInModules
   local cFormName, cFormCode, nFormX, nFormY
   local nInsW, nInsTop, nEditorTop, nEditorX, nEditorW, nEditorH

   cContent := MemoRead( cFile )
   if Empty( cContent )
      MsgInfo( "Could not read project: " + cFile )
      return nil
   endif

   cDir := Left( cFile, RAt( "/", cFile ) )

   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0
   aModules := {}
   aOpenFiles := {}

   CodeEditorClearTabs( hCodeEditor )

   nInsW := Int( nScreenW * 0.18 ) + 20
   nInsTop := GTK_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 1
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop

   aLines := HB_ATokens( cContent, Chr(10) )

   // Suppress editor→designer sync while we populate tabs; we restore from the
   // source on disk directly, and the change callback would otherwise tear down
   // and rebuild each form's widgets (losing runtime state).
   lSyncingFromCode := .t.

   cFormCode := MemoRead( cDir + "Project1.prg" )
   if ! Empty( cFormCode )
      CodeEditorSetTabText( hCodeEditor, 1, cFormCode )
   endif

   for i := 2 to Len( aLines )
      cFormName := AllTrim( aLines[i] )
      if Empty( cFormName ); loop; endif
      if Lower( cFormName ) == "[modules]"; exit; endif

      cFormCode := MemoRead( cDir + cFormName + ".prg" )
      if Empty( cFormCode ); loop; endif

      nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 ) + ( Len(aForms) ) * 20
      nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 ) + ( Len(aForms) ) * 20

      CreateDesignForm( nFormX, nFormY )
      RestoreFormFromCode( oDesignForm:hCpp, cFormCode )
      oDesignForm:SetDesign( .t. )
      oDesignForm:Show()

      aForms[ Len(aForms) ][ 3 ] := cFormCode

      CodeEditorAddTab( hCodeEditor, cFormName + ".prg" )
      CodeEditorSetTabText( hCodeEditor, Len(aForms) + 1, cFormCode )

      UI_OnSelChange( oDesignForm:hCpp, ;
         { |hCtrl| OnDesignSelChange( hCtrl ) } )
      UI_FormOnComponentDrop( oDesignForm:hCpp, ;
         { |hForm, nType, nL, nT, nW, nH| OnComponentDrop( hForm, nType, nL, nT, nW, nH ) } )
   next

   // Load modules
   aModules := {}
   lInModules := .F.
   for i := 2 to Len( aLines )
      cFormName := AllTrim( aLines[i] )
      if Empty( cFormName ); loop; endif
      if Lower( cFormName ) == "[modules]"
         lInModules := .T.
         loop
      endif
      if lInModules
         cFormCode := MemoRead( cDir + cFormName + ".prg" )
         if Empty( cFormCode ); loop; endif
         AAdd( aModules, { cFormName, cFormCode, cDir + cFormName + ".prg" } )
         CodeEditorAddTab( hCodeEditor, cFormName + ".prg" )
         CodeEditorSetTabText( hCodeEditor, 1 + Len(aForms) + Len(aModules), cFormCode )
      endif
   next

   lSyncingFromCode := .f.

   if Len( aForms ) > 0
      nActiveForm := 1
      oDesignForm := aForms[1][2]
      UI_SetDesignForm( oDesignForm:hCpp )
      CodeEditorSelectTab( hCodeEditor, 2 )
      InspectorRefresh( oDesignForm:hCpp )
      InspectorPopulateCombo( oDesignForm:hCpp )
   endif

   cCurrentFile := cFile
   AddRecentProject( cFile )

return nil

static function TBSaveAs()
   cCurrentFile := ""
   TBSave()
return nil

static function TBSave()

   local cDir, cFile, cHbp, i

   SaveActiveFormCode()

   if Empty( cCurrentFile )
      cFile := GTK_SaveFileDialog( "Save HbBuilder Project", "Project1.hbp", "hbp" )
      if Empty( cFile ); return nil; endif
      cCurrentFile := cFile
   endif

   cDir := Left( cCurrentFile, RAt( "/", cCurrentFile ) )

   cHbp := "Project1" + Chr(10)
   for i := 1 to Len( aForms )
      cHbp += aForms[i][1] + Chr(10)
   next
   if Len( aModules ) > 0
      cHbp += "[modules]" + Chr(10)
      for i := 1 to Len( aModules )
         cHbp += aModules[i][1] + Chr(10)
      next
   endif
   MemoWrit( cCurrentFile, cHbp )

   MemoWrit( cDir + "Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )

   for i := 1 to Len( aForms )
      MemoWrit( cDir + aForms[i][1] + ".prg", aForms[i][3] )
   next

   // Write each module .prg
   for i := 1 to Len( aModules )
      aModules[i][2] := CodeEditorGetTabText( hCodeEditor, 1 + Len(aForms) + i )
      MemoWrit( cDir + aModules[i][1] + ".prg", aModules[i][2] )
   next

   AddRecentProject( cCurrentFile )

return nil

// Check if Harbour compiler is installed, download and build if not
// Returns .T. if Harbour is available, .F. if user cancelled or build failed
static function EnsureHarbour( cHbDir )

   local cHbSrc := "/tmp/harbour-src"
   local cOutput, cDiag
   static lBusy := .F.

   // Re-entry protection
   if lBusy
      MsgInfo( "Harbour is already being downloaded and built." + Chr(10) + ;
         "Please wait for the current operation to finish.", "HbBuilder" )
      return .F.
   endif

   // Ask user before downloading
   if ! UI_MsgYesNo( ;
      "Harbour compiler not found!" + Chr(10) + Chr(10) + ;
      "HbBuilder needs Harbour to compile projects." + Chr(10) + Chr(10) + ;
      "Download from GitHub and build it now?" + Chr(10) + ;
      "(This may take several minutes)", ;
      "HbBuilder Setup" )
      return .F.
   endif

   lBusy := .T.

   // Download source if not already present
   if ! File( cHbSrc + "/config/global.mk" )
      GTK_ProgressOpen( "Downloading Harbour...", 0 )
      GTK_ShellExec( "rm -rf " + cHbSrc )
      GTK_ShellExec( "git clone --depth 1 https://github.com/harbour/core.git " + cHbSrc + " 2>&1" )
      GTK_ProgressClose()

      // Verify download
      if ! File( cHbSrc + "/config/global.mk" )
         lBusy := .F.
         GTK_BuildErrorDialog( "Download Failed", ;
            "Could not download Harbour source." + Chr(10) + Chr(10) + ;
            "Please check your internet connection and try again." + Chr(10) + ;
            "You can also install manually:" + Chr(10) + ;
            "  git clone https://github.com/harbour/core " + cHbSrc )
         return .F.
      endif
   endif

   // Build and install Harbour
   GTK_ProgressOpen( "Building Harbour...", 0 )
   cOutput := GTK_ShellExec( "cd " + cHbSrc + " && HB_INSTALL_PREFIX=" + cHbDir + ;
      " make -j$(nproc) install 2>&1" )
   GTK_ProgressClose()

   lBusy := .F.

   // Verify build succeeded
   if File( cHbDir + "/bin/harbour" ) .or. File( cHbDir + "/bin/linux/gcc/harbour" )
      MsgInfo( "Harbour compiler installed successfully!" + Chr(10) + ;
         "Location: " + cHbDir, "HbBuilder Setup" )
      return .T.
   endif

   // Build failed — show diagnostic
   cDiag := "Harbour build failed." + Chr(10) + Chr(10) + ;
      "Install prefix: " + cHbDir + Chr(10) + ;
      "Source dir: " + cHbSrc + Chr(10) + Chr(10) + ;
      "Expected files:" + Chr(10) + ;
      "  bin/harbour: " + iif( File( cHbDir + "/bin/harbour" ), "FOUND", "MISSING" ) + Chr(10) + ;
      "  bin/linux/gcc/harbour: " + iif( File( cHbDir + "/bin/linux/gcc/harbour" ), "FOUND", "MISSING" ) + Chr(10) + ;
      "  include/hbapi.h: " + iif( File( cHbDir + "/include/hbapi.h" ), "FOUND", "MISSING" ) + Chr(10) + Chr(10) + ;
      "Manual build:" + Chr(10) + ;
      "  cd " + cHbSrc + Chr(10) + ;
      "  HB_INSTALL_PREFIX=" + cHbDir + " make install"

   if ! Empty( cOutput ) .and. Len( cOutput ) > 2000
      cDiag += Chr(10) + Chr(10) + "Last output:" + Chr(10) + Right( cOutput, 2000 )
   elseif ! Empty( cOutput )
      cDiag += Chr(10) + Chr(10) + "Build output:" + Chr(10) + cOutput
   endif

   GTK_BuildErrorDialog( "Build Failed", cDiag )

return .F.

static function TBRun()

   local cBuildDir, cOutput, cLog, i, lError
   local cHbDir, cHbBin, cHbInc, cHbLib, cProjDir
   local cAllPrg, cCmd, cAllCode, nHash, cDestDir, cAppExe, cAppTitle
   static nLastHash := 0

   SaveActiveFormCode()

   // Re-sync all forms so new event handlers get wired into CreateForm()
   RewireAllFormEvents()

   cBuildDir := "/tmp/hbbuilder_build"

   // Quick check: if nothing changed since last successful build, just run
   cAllCode := CodeEditorGetTabText( hCodeEditor, 1 )
   for i := 1 to Len( aForms )
      cAllCode += aForms[i][3]
   next
   for i := 1 to Len( aModules )
      cAllCode += CodeEditorGetTabText( hCodeEditor, 1 + Len(aForms) + i )
   next
   nHash := Len( cAllCode )
   for i := 1 to Min( Len( cAllCode ), 5000 )
      nHash := nHash + Asc( SubStr( cAllCode, i, 1 ) ) * i
   next
   if nHash == nLastHash .and. nLastHash != 0 .and. File( cBuildDir + "/UserApp" )
      GTK_ShellExec( cBuildDir + "/UserApp 2>/tmp/userapp_debug.log &" )
      return nil
   endif
   cHbDir   := GetEnv( "HOME" ) + "/harbour"
   cHbInc   := cHbDir + "/include"
   cProjDir := HB_DirBase() + ".."
   cLog     := ""
   lError   := .F.

   // Auto-download and build Harbour if not installed
   if ! File( cHbDir + "/bin/harbour" ) .and. ! File( cHbDir + "/bin/linux/gcc/harbour" )
      if ! EnsureHarbour( cHbDir )
         return nil
      endif
   endif

   // Detect Harbour directory layout
   if File( cHbDir + "/bin/linux/gcc/harbour" )
      cHbBin := cHbDir + "/bin/linux/gcc"
      cHbLib := cHbDir + "/lib/linux/gcc"
   else
      cHbBin := cHbDir + "/bin"
      cHbLib := cHbDir + "/lib"
   endif

   GTK_ShellExec( "mkdir -p " + cBuildDir )

   // Show progress dialog (7 steps)
   GTK_ProgressOpen( "Building Project...", 7 )

   // Step 1: Save files
   GTK_ProgressStep( "Saving project files..." )
   cLog += "[1] Saving project files..." + Chr(10)
   MemoWrit( cBuildDir + "/Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "/" + aForms[i][1] + ".prg", aForms[i][3] )
      cLog += "    " + aForms[i][1] + ".prg" + Chr(10)
   next
   for i := 1 to Len( aModules )
      aModules[i][2] := CodeEditorGetTabText( hCodeEditor, 1 + Len(aForms) + i )
      MemoWrit( cBuildDir + "/" + aModules[i][1] + ".prg", aModules[i][2] )
      cLog += "    " + aModules[i][1] + ".prg (module)" + Chr(10)
   next
   GTK_ShellExec( "cp " + cProjDir + "/source/core/classes.prg " + cBuildDir + "/" )
   GTK_ShellExec( "cp " + cProjDir + "/include/hbbuilder.ch " + cBuildDir + "/" )
   GTK_ShellExec( "cp " + cProjDir + "/include/hbide.ch " + cBuildDir + "/" )

   // Step 2: Assemble main.prg
   GTK_ProgressStep( "Assembling main.prg..." )
   cLog += "[2] Building main.prg..." + Chr(10)
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10) + Chr(10)
   cAllPrg += StrTran( MemoRead( cBuildDir + "/Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += MemoRead( cBuildDir + "/" + aForms[i][1] + ".prg" ) + Chr(10)
   next
   for i := 1 to Len( aModules )
      cAllPrg += StrTran( StrTran( MemoRead( cBuildDir + "/" + aModules[i][1] + ".prg" ), ;
                          '#include "classes.prg"', "" ), ;
                          '#include "hbbuilder.ch"', "" ) + Chr(10)
   next
   MemoWrit( cBuildDir + "/main.prg", cAllPrg )
   MemoWrit( "/tmp/hbbuilder_debug_main.prg", cAllPrg )

   // Step 3: Compile Harbour code
   if ! lError
      GTK_ProgressStep( "Compiling Harbour code..." )
      cLog += "[3] Compiling main.prg..." + Chr(10)
      cCmd := cHbBin + "/harbour " + cBuildDir + "/main.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/main.c 2>&1"
      cOutput := GTK_ShellExec( cCmd )
      if "Error" $ cOutput
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 4: Compile framework
   if ! lError
      GTK_ProgressStep( "Compiling framework..." )
      cLog += "[4] Compiling framework..." + Chr(10)
      cCmd := cHbBin + "/harbour " + cBuildDir + "/classes.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/classes.c 2>&1"
      GTK_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 5: Compile C sources
   if ! lError
      GTK_ProgressStep( "Compiling C sources..." )
      cLog += "[5] Compiling C sources..." + Chr(10)
      cCmd := "gcc -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/main.c -o " + cBuildDir + "/main.o 2>&1"
      cOutput := GTK_ShellExec( cCmd )
      if ! Empty( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      endif
      cCmd := "gcc -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/classes.c -o " + cBuildDir + "/classes.o 2>&1"
      GTK_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 6: Compile GTK3 backend
   if ! lError
      GTK_ProgressStep( "Compiling GTK3 backend..." )
      cLog += "[6] Compiling GTK3 backend..." + Chr(10)
      cCmd := "gcc -c -O2 -I" + cHbInc + ;
              " $(pkg-config --cflags gtk+-3.0)" + ;
              " $(pkg-config --exists webkit2gtk-4.1 2>/dev/null && echo '-DHAVE_WEBKIT2GTK '$(pkg-config --cflags webkit2gtk-4.1) || " + ;
              "  (pkg-config --exists webkit2gtk-4.0 2>/dev/null && echo '-DHAVE_WEBKIT2GTK '$(pkg-config --cflags webkit2gtk-4.0) || echo ''))" + ;
              " " + cProjDir + "/source/backends/gtk3/gtk3_core.c" + ;
              " -o " + cBuildDir + "/gtk3_core.o 2>&1"
      GTK_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 7: Link
   if ! lError
      GTK_ProgressStep( "Linking executable..." )
      cLog += "[7] Linking..." + Chr(10)
      cCmd := "gcc -o " + cBuildDir + "/UserApp" + ;
              " " + cBuildDir + "/main.o" + ;
              " " + cBuildDir + "/classes.o" + ;
              " " + cBuildDir + "/gtk3_core.o" + ;
              " -L" + cHbLib + ;
              " -Wl,--start-group" + ;
              " -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang" + ;
              " -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug" + ;
              " -lhbct -lhbextern" + ;
              " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
              " -lhbhsx -lhbsix -lhbusrrdd" + ;
              " -lhbsqlit3 -lsddsqlt3 -lrddsql" + ;
              " -lgttrm -lhbpcre" + ;
              " -Wl,--end-group" + ;
              " $(pkg-config --libs gtk+-3.0)" + ;
              " $(pkg-config --exists webkit2gtk-4.1 2>/dev/null && pkg-config --libs webkit2gtk-4.1 || " + ;
              "  (pkg-config --exists webkit2gtk-4.0 2>/dev/null && pkg-config --libs webkit2gtk-4.0 || echo ''))" + ;
              " -lm -lpthread -ldl -lrt -lsqlite3 -lncurses 2>&1"
      cOutput := GTK_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   GTK_ProgressClose()

   if lError
      GTK_BuildErrorDialog( "Build Failed", cLog )
   else
      nLastHash := nHash
      cLog += Chr(10) + "Build succeeded. Running..." + Chr(10)
      if ! Empty( cCurrentFile )
         cDestDir := Left( cCurrentFile, RAt( "/", cCurrentFile ) )
         cAppTitle := ""
         if Len( aForms ) >= 1
            cAppTitle := UI_GetProp( aForms[1][2]:hCpp, "cAppTitle" )
            if ValType( cAppTitle ) != "C"; cAppTitle := ""; endif
            cAppTitle := StrTran( AllTrim( cAppTitle ), " ", "_" )
         endif
         if Empty( cAppTitle )
            cAppTitle := Left( cDestDir, Len( cDestDir ) - 1 )
            cAppTitle := SubStr( cAppTitle, RAt( "/", cAppTitle ) + 1 )
         endif
         cAppExe := iif( ! Empty( cAppTitle ), cAppTitle, "UserApp" )
         GTK_ShellExec( "cp " + cBuildDir + "/UserApp " + cDestDir + cAppExe + " 2>/dev/null" )
      endif
      GTK_ShellExec( cBuildDir + "/UserApp 2>/tmp/userapp_debug.log &" )
   endif

return nil

// === Debug Run (socket-based, compiles native exe with dbgclient.prg) ===

static function TBDebugRunToBreak()
   TBDebugRun( .T. )
return nil

static function TBDebugRun( lRunToBreak )

   local cBuildDir, cOutput, cLog, i, lError
   local cHbDir, cHbBin, cHbInc, cHbLib, cProjDir
   local cAllPrg, cCmd, cMainPrg, cSection
   local nCurLine, cWebKitLibs

   if lRunToBreak == nil; lRunToBreak := .F.; endif

   SaveActiveFormCode()

   cBuildDir := "/tmp/hbbuilder_debug"
   cHbDir   := GetEnv( "HOME" ) + "/harbour"
   cHbInc   := cHbDir + "/include"
   cProjDir := HB_DirBase() + ".."
   cLog     := ""
   lError   := .F.

   // Auto-download and build Harbour if not installed
   if ! File( cHbDir + "/bin/harbour" ) .and. ! File( cHbDir + "/bin/linux/gcc/harbour" )
      if ! EnsureHarbour( cHbDir )
         return nil
      endif
   endif

   // Detect Harbour directory layout
   if File( cHbDir + "/bin/linux/gcc/harbour" )
      cHbBin := cHbDir + "/bin/linux/gcc"
      cHbLib := cHbDir + "/lib/linux/gcc"
   else
      cHbBin := cHbDir + "/bin"
      cHbLib := cHbDir + "/lib"
   endif

   GTK_ShellExec( "mkdir -p " + cBuildDir )

   // Step 1: Save user code + copy framework
   cLog += "[1] Saving files..." + Chr(10)
   MemoWrit( cBuildDir + "/Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "/" + aForms[i][1] + ".prg", ;
         CodeEditorGetTabText( hCodeEditor, i + 1 ) )
   next
   GTK_ShellExec( "cp " + cProjDir + "/source/core/classes.prg " + cBuildDir + "/" )
   GTK_ShellExec( "cp " + cProjDir + "/include/hbbuilder.ch " + cBuildDir + "/" )
   GTK_ShellExec( "cp " + cProjDir + "/include/hbide.ch " + cBuildDir + "/" )
   GTK_ShellExec( "cp " + cProjDir + "/source/debugger/dbgclient.prg " + cBuildDir + "/" )

   // Step 2: Assemble debug_main.prg (tracking line offsets for each section)
   cLog += "[2] Assembling debug_main.prg..." + Chr(10)

   // Header: #include + GT + INIT PROCEDURE to start debug client
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_NUL_DEFAULT" + Chr(10)
   cAllPrg += "INIT PROCEDURE __DbgInit" + Chr(10)
   cAllPrg += "   DbgClientStart( 19800 )" + Chr(10)
   cAllPrg += "return" + Chr(10) + Chr(10)
   nCurLine := 7

   aDbgOffsets := {}

   // Project1.prg — #include removed (StrTran leaves empty line, offsets match)
   AAdd( aDbgOffsets, { nCurLine, "Project1.prg", 1, 1 } )
   cMainPrg := CodeEditorGetTabText( hCodeEditor, 1 )
   cMainPrg := StrTran( cMainPrg, '#include "hbbuilder.ch"', "" )
   cAllPrg += cMainPrg + Chr(10)
   nCurLine += NumLines( cMainPrg ) + 1

   // Form files
   for i := 1 to Len( aForms )
      AAdd( aDbgOffsets, { nCurLine, aForms[i][1] + ".prg", i + 1, 2 } )
      cSection := MemoRead( cBuildDir + "/" + aForms[i][1] + ".prg" )
      cAllPrg += cSection + Chr(10)
      nCurLine += NumLines( cSection ) + 1
   next

   // classes.prg (framework — not in editor)
   AAdd( aDbgOffsets, { nCurLine, "classes.prg", 0, 0 } )
   cSection := MemoRead( cBuildDir + "/classes.prg" )
   cAllPrg += cSection + Chr(10)
   nCurLine += NumLines( cSection ) + 1

   // dbgclient.prg (debug — not in editor)
   AAdd( aDbgOffsets, { nCurLine, "dbgclient.prg", 0, 0 } )
   cAllPrg += MemoRead( cBuildDir + "/dbgclient.prg" ) + Chr(10)

   MemoWrit( cBuildDir + "/debug_main.prg", cAllPrg )

   // Step 3: Harbour compile → C
   cLog += "[3] Harbour compile..." + Chr(10)

   cCmd := cHbBin + "/harbour " + cBuildDir + "/debug_main.prg -b -n -w -q" + ;
           " -I" + cHbInc + " -I" + cBuildDir + ;
           " -o" + cBuildDir + "/debug_main.c 2>&1"
   cOutput := GTK_ShellExec( cCmd )
   if "Error" $ cOutput
      cLog += cOutput + Chr(10)
      lError := .t.
   else
      cLog += "    OK" + Chr(10)
   endif

   // Step 4: Compile C sources
   if ! lError
      cLog += "[4] C compile..." + Chr(10)

      cCmd := "gcc -c -O0 -g -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/debug_main.c" + ;
              " -o " + cBuildDir + "/debug_main.o 2>&1"
      cOutput := GTK_ShellExec( cCmd )
      if "error:" $ Lower( cOutput )
         cLog += cOutput + Chr(10)
         lError := .t.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 5: Compile dbghook.c + reuse prebuilt gtk3_core.o and gtk3_inspector.o
   if ! lError
      cLog += "[5] dbghook + backend (prebuilt)..." + Chr(10)

      cCmd := "gcc -c -O2 -I" + cHbInc + ;
              " " + cProjDir + "/source/debugger/dbghook.c" + ;
              " -o " + cBuildDir + "/dbghook.o 2>&1"
      GTK_ShellExec( cCmd )

      // Reuse prebuilt gtk3_core.o and gtk3_inspector.o from IDE build
      GTK_ShellExec( "cp " + cProjDir + "/source/gtk3_core.o " + cBuildDir + "/" )
      GTK_ShellExec( "cp " + cProjDir + "/source/gtk3_inspector.o " + cBuildDir + "/" )
      cLog += "    OK" + Chr(10)
   endif

   // Detect WebKit2GTK for linker flags (same logic as build_linux.sh)
   cWebKitLibs := ""
   if GTK_ShellExec( "pkg-config --exists webkit2gtk-4.1 2>/dev/null; echo $?" ) == "0" + Chr(10)
      cWebKitLibs := "$(pkg-config --libs webkit2gtk-4.1)"
   elseif GTK_ShellExec( "pkg-config --exists webkit2gtk-4.0 2>/dev/null; echo $?" ) == "0" + Chr(10)
      cWebKitLibs := "$(pkg-config --libs webkit2gtk-4.0)"
   endif

   // Step 6: Link native executable
   if ! lError
      cLog += "[6] Linking..." + Chr(10)

      cCmd := "gcc -o " + cBuildDir + "/DebugApp" + ;
              " " + cBuildDir + "/debug_main.o" + ;
              " " + cBuildDir + "/dbghook.o" + ;
              " " + cBuildDir + "/gtk3_core.o" + ;
              " " + cBuildDir + "/gtk3_inspector.o" + ;
              " -L" + cHbLib + ;
              " -Wl,--start-group" + ;
              " -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang" + ;
              " -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug" + ;
              " -lhbct -lhbextern" + ;
              " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
              " -lhbhsx -lhbsix -lhbusrrdd" + ;
              " -lhbsqlit3 -lsddsqlt3 -lrddsql" + ;
              " -lgttrm -lhbpcre" + ;
              " -Wl,--end-group" + ;
              " $(pkg-config --libs gtk+-3.0)" + ;
              " " + cWebKitLibs + ;
              " -lm -lpthread -ldl -lrt -lsqlite3 -lncurses 2>&1"
      cOutput := GTK_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += cOutput + Chr(10)
         lError := .t.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif


   if lError
      GTK_BuildErrorDialog( "Debug Build Failed", cLog )
      return nil
   endif

   if ! File( cBuildDir + "/DebugApp" )
      GTK_BuildErrorDialog( "Debug Build Failed", cLog + "ERROR: DebugApp not created" + Chr(10) )
      return nil
   endif


   // Step 7: Hide design form, highlight Debug button, switch inspector to debug, launch
   if oDesignForm != nil
      UI_FormHide( oDesignForm:hCpp )
   endif
   GTK_ProcessEvents()
   if oTB2 != nil
      UI_ToolBtnHighlight( oTB2:hCpp, 1, .t. )
   endif
   GTK_ProcessEvents()
   InspectorOpen()
   GTK_ProcessEvents()
   INS_SetDebugMode( _InsGetData(), .t. )
   GTK_ProcessEvents()
   CodeEditorSelectTab( hCodeEditor, 1 )  // switch to Project1.prg
   GTK_ProcessEvents()

   IDE_DebugStart2( cBuildDir + "/DebugApp", ;
      { |cFunc, nLine, cLocals, cStack| OnDebugPause( cFunc, nLine, cLocals, cStack ) } )

   // Restore: clear debug marker, unhighlight, restore inspector, show design form
   CodeEditorShowDebugLine( hCodeEditor, 0 )  // clear yellow marker
   if oTB2 != nil
      UI_ToolBtnHighlight( oTB2:hCpp, 1, .f. )
   endif
   GTK_ProcessEvents()
   INS_SetDebugMode( _InsGetData(), .f. )
   GTK_ProcessEvents()
   if oDesignForm != nil
      UI_FormBringToFront( oDesignForm:hCpp )
   endif

return nil

// Convert stack line numbers from debug_main.prg to editor tab line numbers
static function DbgFixStackLines( cStack )
   local cOut := "STACK", cToken, nPos, nLine, nTabLine, i, nP1, nP2

   // Parse "STACK FUNC(line) FUNC2(line2) ..."
   cStack := AllTrim( cStack )
   if Left( cStack, 5 ) == "STACK"; cStack := SubStr( cStack, 6 ); endif

   do while ! Empty( cStack )
      cStack := LTrim( cStack )
      nPos := At( " ", cStack )
      if nPos == 0
         cToken := cStack
         cStack := ""
      else
         cToken := Left( cStack, nPos - 1 )
         cStack := SubStr( cStack, nPos + 1 )
      endif

      // Extract line from "FUNC(line)"
      nP1 := At( "(", cToken )
      nP2 := At( ")", cToken )
      if nP1 > 0 .and. nP2 > nP1
         nLine := Val( SubStr( cToken, nP1 + 1, nP2 - nP1 - 1 ) )
         // Convert using offsets
         nTabLine := nLine
         if aDbgOffsets != nil
            for i := Len( aDbgOffsets ) to 1 step -1
               if nLine >= aDbgOffsets[i][1] .and. aDbgOffsets[i][3] > 0
                  nTabLine := nLine - aDbgOffsets[i][1] + aDbgOffsets[i][4]
                  exit
               endif
            next
         endif
         cOut += " " + Left( cToken, nP1 ) + LTrim( Str( nTabLine ) ) + ")"
      else
         cOut += " " + cToken
      endif
   enddo

return cOut

// Replace "local1", "local2" etc with real variable names from source
static function DbgMapLocalNames( cVars, cFunc, nTab )
   local cCode, aLines, cLine, i, aNames, nPos, cName, cTrim, lInFunc, c
   local cTag, nP, nEnd

   cCode := CodeEditorGetTabText( hCodeEditor, nTab )
   if Empty( cCode ); return cVars; endif

   aLines := HB_ATokens( cCode, Chr(10) )
   aNames := {}
   lInFunc := .f.

   for i := 1 to Len( aLines )
      cTrim := Upper( AllTrim( aLines[i] ) )
      // Look for PROCEDURE/FUNCTION/METHOD matching cFunc
      if ! lInFunc
         if ( "PROCEDURE " $ cTrim .or. "FUNCTION " $ cTrim .or. "METHOD " $ cTrim ) .and. ;
            Upper( cFunc ) $ cTrim
            lInFunc := .t.
         endif
         loop
      endif
      // Inside the function — collect local declarations
      if Left( cTrim, 6 ) == "LOCAL "
         cLine := AllTrim( SubStr( AllTrim( aLines[i] ), 7 ) )
         // Parse comma-separated names: "oApp, nVal, cText"
         do while ! Empty( cLine )
            cLine := LTrim( cLine )
            cName := ""
            nPos := 1
            do while nPos <= Len( cLine )
               c := SubStr( cLine, nPos, 1 )
               if c == "," .or. c == " " .or. c == ":" .or. c == Chr(13) .or. c == Chr(10)
                  exit
               endif
               cName += c
               nPos++
            enddo
            if ! Empty( cName )
               AAdd( aNames, cName )
            endif
            nPos := At( ",", cLine )
            if nPos > 0
               cLine := SubStr( cLine, nPos + 1 )
            else
               exit
            endif
         enddo
      elseif ! Empty( cTrim ) .and. Left( cTrim, 2 ) != "//" .and. ;
             Left( cTrim, 6 ) != "LOCAL " .and. Left( cTrim, 7 ) != "STATIC "
         // First non-local, non-comment line = end of declarations
         exit
      endif
   next

   // Replace "localN" with real names and remove unmapped extras
   for i := 1 to Len( aNames )
      cVars := StrTran( cVars, "local" + LTrim(Str(i)) + "=", aNames[i] + "=" )
   next

   // Remove any remaining "localN=..." entries (VM internal extras)
   for i := Len( aNames ) + 1 to 30
      cTag := " local" + LTrim(Str(i)) + "="
      nP := At( cTag, cVars )
      if nP > 0
         nEnd := At( " ", SubStr( cVars, nP + 1 ) )
         if nEnd > 0
            cVars := Left( cVars, nP - 1 ) + SubStr( cVars, nP + nEnd )
         else
            cVars := Left( cVars, nP - 1 )
         endif
      else
         exit
      endif
   next

return cVars

static function NumLines( cText )
   local n := 1, i
   for i := 1 to Len( cText )
      if SubStr( cText, i, 1 ) == Chr(10); n++; endif
   next
return n

// === Debug Pause Callback (called from socket command loop) ===

static function OnDebugPause( cFunc, nLine, cLocals, cStack )

   local i, nTab, nTabLine, hIns, cFile

   // Map debug_main.prg line number to the correct editor tab and line
   nTab := 0
   nTabLine := 0
   cFile := ""
   if aDbgOffsets != nil
      for i := Len( aDbgOffsets ) to 1 step -1
         if nLine >= aDbgOffsets[i][1]
            nTab    := aDbgOffsets[i][3]
            nTabLine := nLine - aDbgOffsets[i][1] + aDbgOffsets[i][4]
            cFile   := aDbgOffsets[i][2]
            exit
         endif
      next
   endif

   // Framework code (nTab == 0) — skip, don't pause
   if nTab == 0
      return .f.
   endif

   // Only pause at breakpoints or when user is stepping line-by-line
   if ! IDE_IsBreakpoint( cFile, nTabLine ) .and. ! IDE_DbgIsStepping()
      return .f.
   endif

   // Select the tab and highlight the line
   if nTabLine > 0
      CodeEditorSelectTab( hCodeEditor, nTab )
      CodeEditorShowDebugLine( hCodeEditor, nTabLine )
   endif

   // Map local index names to real names from source code
   if cLocals != nil .and. nTab > 0
      cLocals := DbgMapLocalNames( cLocals, cFunc, nTab )
   endif

   // Update inspector with locals and call stack
   hIns := _InsGetData()
   if hIns != 0
      if cLocals != nil
         INS_SetDebugLocals( hIns, cLocals )
      endif
      if cStack != nil
         INS_SetDebugStack( hIns, DbgFixStackLines( cStack ) )
      endif
   endif

return .t.  // pause here — user code

// === Debugger ===

static function DebugStepOver()
   if IDE_DebugGetState() == 2  // DBG_PAUSED
      IDE_DebugStep()
   else
      MsgInfo( "Start debug first with Debug button" )
   endif
return nil

static function DebugStepInto()
   if IDE_DebugGetState() == 2  // DBG_PAUSED
      IDE_DebugStep()
   else
      MsgInfo( "Start debug first with Debug button" )
   endif
return nil

static function ToggleBreakpoint()
   static aBreakpoints := {}
   local cFile := aForms[ nActiveForm ][ 1 ] + ".prg"
   AAdd( aBreakpoints, { cFile, 1 } )
   IDE_DebugAddBreakpoint( cFile, 1 )
   MsgInfo( "Breakpoints: " + LTrim(Str(Len(aBreakpoints))) )
return nil

static function ClearBreakpoints()
   IDE_DebugClearBreakpoints()
   MsgInfo( "All breakpoints cleared" )
return nil

// === Components ===

static function InstallComponent()
   MenuAddModule()
return nil

static function NewComponent()
   local cCode := ;
      "// New Component Template" + Chr(10) + ;
      "// Inherit from an existing control class" + Chr(10) + Chr(10) + ;
      "#include 'hbbuilder.ch'" + Chr(10) + Chr(10) + ;
      "class TMyComponent from TButton" + Chr(10) + ;
      "   data cCustomProp init ''" + Chr(10) + ;
      "   method New() constructor" + Chr(10) + ;
      "   method Paint()" + Chr(10) + ;
      "endclass" + Chr(10) + Chr(10) + ;
      "method New() class TMyComponent" + Chr(10) + ;
      "   ::Super:New()" + Chr(10) + ;
      "return self" + Chr(10) + Chr(10) + ;
      "method Paint() class TMyComponent" + Chr(10) + ;
      "   ::Super:Paint()" + Chr(10) + ;
      "return nil" + Chr(10)
   // Add as module
   AAdd( aModules, { "MyComponent", cCode, "" } )
   CodeEditorAddTab( hCodeEditor, "MyComponent.prg" )
   CodeEditorSetTabText( hCodeEditor, 1 + Len(aForms) + Len(aModules), cCode )
   CodeEditorSelectTab( hCodeEditor, 1 + Len(aForms) + Len(aModules) )
return nil

// === AI Assistant ===

static function ShowAIAssistant()
   GTK_AIAssistantPanel()
return nil

// === Project Inspector ===

static function ShowProjectInspector()
   local aItems := {}
   local i
   AAdd( aItems, "Project1" )
   for i := 1 to Len( aForms )
      AAdd( aItems, "  " + aForms[i][1] + ".prg (Form)" )
   next
   for i := 1 to Len( aModules )
      AAdd( aItems, "  " + aModules[i][1] + ".prg (Module)" )
   next
   AAdd( aItems, "  classes.prg" )
   AAdd( aItems, "  hbbuilder.ch" )
   GTK_ProjectInspector( aItems )
return nil

// === Add/Remove from Project ===

static function AddToProject()
   MenuAddModule()
return nil

static function RemoveFromProject()

   local aNames := {}, i, nSel

   for i := 1 to Len( aForms )
      AAdd( aNames, aForms[i][1] + ".prg (Form)" )
   next
   for i := 1 to Len( aModules )
      AAdd( aNames, aModules[i][1] + ".prg (Module)" )
   next

   if Len( aNames ) == 0
      MsgInfo( "No items to remove" )
      return nil
   endif

   nSel := GTK_SelectFromList( "Remove from Project", aNames )
   if nSel < 1; return nil; endif

   if nSel <= Len( aForms )
      // Removing a form
      if Len( aForms ) <= 1 .and. Len( aModules ) == 0
         MsgInfo( "Cannot remove the last item from the project" )
         return nil
      endif
      aForms[nSel][2]:Destroy()
      CodeEditorRemoveTab( hCodeEditor, nSel + 1 )
      ADel( aForms, nSel )
      ASize( aForms, Len(aForms) - 1 )
      if nActiveForm > Len( aForms )
         nActiveForm := Max( Len( aForms ), 1 )
      endif
      if nActiveForm > 0 .and. Len( aForms ) > 0
         SwitchToForm( nActiveForm )
      endif
   else
      // Removing a module
      i := nSel - Len( aForms )
      CodeEditorRemoveTab( hCodeEditor, 1 + Len(aForms) + i )
      ADel( aModules, i )
      ASize( aModules, Len(aModules) - 1 )
   endif

   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )

return nil

// === Environment Options ===

static function ShowEnvironmentOptions()
   static cHbDir  := "~/harbour"
   static cCFlags := "-g -Wno-unused-value"
   static cHbFlags := "-n -w -q"
   GTK_ProjectOptionsDialog( cHbDir, "/usr/bin", ".", "./build", ;
      cHbFlags, cCFlags, "", "", "", "" )
return nil

// === Format > Align Controls ===

static function AlignControls( nMode )
   if oDesignForm != nil
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormAlignSelected( oDesignForm:hCpp, nMode )
      SyncDesignerToCode()
   endif
return nil

// === Tab Order ===

static function ShowTabOrder()
   if oDesignForm != nil
      UI_FormTabOrderDialog( oDesignForm:hCpp )
   endif
return nil

// === Dark Mode (toggle + persist) ===

static function GetIniPath()
return hb_DirBase() + "hbbuilder.ini"

static function IniRead( cSection, cKey, cDefault )
   local cContent, aLines, i, cSearch
   HB_SYMBOL_UNUSED( cSection )
   cContent := MemoRead( GetIniPath() )
   if Empty( cContent ); return cDefault; endif
   aLines := HB_ATokens( cContent, Chr(10) )
   cSearch := Lower( cKey ) + "="
   for i := 1 to Len( aLines )
      if Left( Lower( AllTrim( aLines[i] ) ), Len( cSearch ) ) == cSearch
         return SubStr( AllTrim( aLines[i] ), Len( cSearch ) + 1 )
      endif
   next
return cDefault

static function IniWrite( cSection, cKey, cValue )
   local cContent, aLines, i, lFound, cSearch
   HB_SYMBOL_UNUSED( cSection )
   cContent := MemoRead( GetIniPath() )
   if Empty( cContent ); cContent := ""; endif
   aLines := HB_ATokens( cContent, Chr(10) )
   cSearch := Lower( cKey ) + "="
   lFound := .f.
   for i := 1 to Len( aLines )
      if Left( Lower( AllTrim( aLines[i] ) ), Len( cSearch ) ) == cSearch
         aLines[i] := cKey + "=" + cValue
         lFound := .t.
         exit
      endif
   next
   if ! lFound; AAdd( aLines, cKey + "=" + cValue ); endif
   cContent := ""
   for i := 1 to Len( aLines )
      if ! Empty( AllTrim( aLines[i] ) )
         cContent += aLines[i] + Chr(10)
      endif
   next
   MemoWrit( GetIniPath(), cContent )
return nil

#define MAX_RECENT 8

static function GetRecentProjects()
   local aList := {}, i, cVal
   for i := MAX_RECENT to 1 step -1
      cVal := IniRead( "Recent", "File" + LTrim( Str( i ) ), "" )
      if ! Empty( cVal ); AAdd( aList, cVal ); endif
   next
return aList

static function AddRecentProject( cFile )
   local aList := GetRecentProjects()
   local nPos
   nPos := AScan( aList, { |x| Lower(x) == Lower(cFile) } )
   if nPos > 0
      ADel( aList, nPos )
      aList := ASize( aList, Len(aList) - 1 )
   endif
   AAdd( aList, cFile )
   while Len( aList ) > MAX_RECENT
      ADel( aList, 1 )
      aList := ASize( aList, Len(aList) - 1 )
   enddo
   for nPos := 1 to MAX_RECENT
      if Len( aList ) >= nPos
         IniWrite( "Recent", "File" + LTrim( Str( nPos ) ), aList[ Len(aList) - nPos + 1 ] )
      else
         IniWrite( "Recent", "File" + LTrim( Str( nPos ) ), "" )
      endif
   next
return nil

static function ReopenLastProject()
   local cFile := IniRead( "Recent", "File1", "" )
   if Empty( cFile )
      MsgInfo( "No recent project found.", "HbBuilder" )
      return nil
   endif
   if ! File( cFile )
      MsgInfo( "File not found: " + cFile, "HbBuilder" )
      return nil
   endif
   OpenProjectFile( cFile )
return nil

static function LoadDarkMode()
   if IniRead( "General", "DarkMode", "0" ) == "1"
      GTK_SetDarkMode( .T. )
      return .T.
   endif
return .F.

static function SaveDarkMode( lDark )
   IniWrite( "General", "DarkMode", If( lDark, "1", "0" ) )
return nil

static function ToggleDarkMode()
   local lDark
   lDark := ! GTK_IsDarkMode()
   GTK_SetDarkMode( lDark )
   SaveDarkMode( lDark )

   // Apply to code editor
   if hCodeEditor != nil .and. hCodeEditor != 0
      CodeEditorApplyTheme( hCodeEditor, lDark )
   endif

   // Apply to design form background
   if oDesignForm != nil
      if lDark
         UI_SetProp( oDesignForm:hCpp, "nClrPane", 2960685 )  // RGB(45,45,45)
      else
         UI_SetProp( oDesignForm:hCpp, "nClrPane", 15790320 ) // RGB(240,240,240)
      endif
      InspectorRefresh( oDesignForm:hCpp )
   endif
return nil

// === Editor Settings ===

static function ShowEditorSettings()
   GTK_EditorSettingsDialog()
return nil

// === Project Options ===

static function ShowProjectOptions()
   GTK_ProjectOptionsDialog()
return nil

// === Helpers ===

static function ShowAbout()

   local cMsg := ""

   cMsg += "Harbour Builder 1.0" + Chr(10)
   cMsg += "Visual development environment for Harbour" + Chr(10)
   cMsg += Chr(10)
   cMsg += "(c) 2025-2026 The Harbour Project" + Chr(10)
   cMsg += "https://harbour.github.io/" + Chr(10)
   cMsg += Chr(10)
   cMsg += "Based on Harbour 3.2" + Chr(10)
   cMsg += "Cross-platform GUI framework" + Chr(10)
   cMsg += Chr(10)
   cMsg += "Inspired by Borland C++Builder" + Chr(10)
   cMsg += Chr(10)
   cMsg += "Vibe coded 100% using Claude Code" + Chr(10)

   GTK_AboutDialog( "About HbBuilder", cMsg, "../resources/harbour_logo.png" )

return nil

static function FormUndo()
   if oDesignForm != nil
      UI_FormUndo( oDesignForm:hCpp )
      InspectorRefresh( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil

static function CopyControls()
   if oDesignForm != nil
      UI_FormCopySelected( oDesignForm:hCpp )
   endif
return nil

static function PasteControls()
   if oDesignForm != nil .and. UI_FormGetClipCount() > 0
      UI_FormPasteControls( oDesignForm:hCpp )
      InspectorRefresh( oDesignForm:hCpp )
      InspectorPopulateCombo( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil

// === Report Designer ===

static function OpenReportDesigner()

   // Open the designer window
   RPT_DesignerOpen()

   // Add default bands
   RPT_AddBand( "Header", 40 )
   RPT_AddBand( "Detail", 20 )
   RPT_AddBand( "Footer", 30 )

   // Add sample fields to Header (band index 0)
   RPT_AddField( 0, "Title", "Report Title", 10, 5, 180, 20 )

   // Add sample fields to Detail (band index 1)
   RPT_AddField( 1, "Field1", "[Field1]", 10, 2, 80, 14 )
   RPT_AddField( 1, "Field2", "[Field2]", 100, 2, 80, 14 )

return nil

// MsgInfo() is now in classes.prg (cross-platform)

// Helper for inspector: get current editor code for handler name resolution
function _InsGetEditorCode()

   if hCodeEditor != nil .and. nActiveForm > 0
      return CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   endif

return ""

static function ComponentTypeFromName( cName )
   do case
      case cName == "CT_TIMER";         return 38
      case cName == "CT_PAINTBOX";      return 39
      case cName == "CT_OPENDIALOG";    return 40
      case cName == "CT_SAVEDIALOG";    return 41
      case cName == "CT_FONTDIALOG";    return 42
      case cName == "CT_COLORDIALOG";   return 43
      case cName == "CT_FINDDIALOG";    return 44
      case cName == "CT_REPLACEDIALOG"; return 45
      case cName == "CT_DBFTABLE";      return 53
      case cName == "CT_MYSQL";         return 54
      case cName == "CT_MARIADB";       return 55
      case cName == "CT_POSTGRESQL";    return 56
      case cName == "CT_SQLITE";        return 57
      case cName == "CT_FIREBIRD";      return 58
      case cName == "CT_SQLSERVER";     return 59
      case cName == "CT_ORACLE";        return 60
      case cName == "CT_MONGODB";       return 61
      case cName == "CT_WEBVIEW";       return 62
      case cName == "CT_WEBSERVER";     return 63
      case cName == "CT_WEBSOCKET";     return 64
      case cName == "CT_HTTPCLIENT";    return 65
      case cName == "CT_COMPARRAY";     return 131
   endcase
return 0

// Framework
#include "core/classes.prg"
#include "inspector/inspector_gtk.prg"
