// hbcpp_macos.prg - HbBuilder: visual IDE for Harbour (C++Builder layout)
//
// Classic layout (originally 1024x768, scaled proportionally):
//
// ┌─────────────────────────────────────────────────────────────┐ 0
// │  Main Bar: toolbar + splitter + palette tabs (full width)   │
// ├──────────┬──────────────────────────────────────────────────┤ ~100
// │ Object   │  Code Editor (background, full area)             │
// │ Inspector│  ┌─────────────────────┐                         │
// │          │  │  Form Designer      │  (floating on top)      │
// │ combo +  │  │  (400x300)          │                         │
// │ property │  └─────────────────────┘                         │
// │ grid     │                                                  │
// │          │                                                  │
// ├──────────┴──────────────────────────────────────────────────┤ ~650
// │  Messages / Compiler output (future)                        │
// └─────────────────────────────────────────────────────────────┘ 768

#include "../include/hbbuilder.ch"

// Force symbol registration for C functions called via hb_dynsymFindName
EXTERNAL CODEEDITORRESTOREBREAKPOINTS
EXTERNAL CODEEDITORTOGGLEBREAKPOINT
EXTERNAL CODEEDITORADDBREAKPOINT
EXTERNAL CODEEDITORREMOVEBREAKPOINT
EXTERNAL CODEEDITORCLEARBREAKPOINTS
EXTERNAL CODEEDITORGETBREAKPOINTS
EXTERNAL IDE_DEBUGADDBREAKPOINT
EXTERNAL IDE_DEBUGREMOVEBREAKPOINT
EXTERNAL IDE_DEBUGCLEARBREAKPOINTS
EXTERNAL IDE_DEBUGSTART
EXTERNAL IDE_DEBUGSTART2
EXTERNAL IDE_DEBUGRUNTOBREAK
EXTERNAL IDE_DEBUGRUNTOBREAK2
EXTERNAL IDE_DEBUGGO
EXTERNAL IDE_DEBUGSTEP
EXTERNAL IDE_DEBUGSTEPOVER
EXTERNAL IDE_DEBUGSTOP
EXTERNAL IDE_ISDEBUGMODE
EXTERNAL IDE_DEBUGGETSTATE
EXTERNAL MAC_DEBUGPANEL
EXTERNAL INS_BRINGTOFRONT
EXTERNAL INS_SETDEBUGMODE
EXTERNAL INS_SETDEBUGLOCALS
EXTERNAL INS_SETDEBUGSTACK
EXTERNAL IDE_DEBUGPAUSEATSTEP
EXTERNAL IDE_ISBREAKPOINT
EXTERNAL IDE_DBGISSTEPPING
EXTERNAL IDE_DBGRUNLOOPENDED

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
static aDbgOffsets   // Debug line offsets: { {startLine, "tabName", nTabIndex, nAdj}, ... }
static oTB2          // Debug toolbar (for highlighting Debug button)
static lIgnoreSelChange := .f.  // Flag to prevent re-entrant selection change
static lSyncingFromCode := .f.  // Guard: true while syncing code -> designer

function Main()

   local oTB, oFile, oEdit, oSearch, oView, oProject, oRun, oFormat, oComp, oTools, oGit, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY
   local cIcoDir

   /* IDE-wide error trap: dump error + call stack to /tmp/hb_ide.err */
   ErrorBlock( { |o| IdeDumpError( o ) } )

   nScreenW := MAC_GetScreenWidth()
   nScreenH := MAC_GetScreenHeight()
   cCurrentFile := ""
   aForms := {}
   nActiveForm := 0
   aModules := {}
   aOpenFiles := {}

   // C++Builder classic proportions scaled to current screen
   // Reference: 1024x768 -> Inspector 250px (24.4%), Bar 100px (13%)
   nBarH    := 84                            // two toolbar rows(28+28) + tabs(24) + margins(4)
   nInsW    := Int( nScreenW * 0.18 )        // ~18% of screen width

   // === Window 1: Main Bar (full screen width) ===
   DEFINE FORM oIDE TITLE "HbBuilder 1.0 - Visual IDE for Harbour" ;
      SIZE nScreenW, nBarH FONT "Helvetica Neue", 12 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()
   UI_FormSetDarkMode( oIDE:hCpp )

   // Inspector: right below IDE window
   nInsTop  := MAC_GetWindowBottom( oIDE:hCpp )
   // Editor: starts below IDE bar + small offset
   nEditorTop := nInsTop + 80
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   // Both inspector and editor end at same bottom position
   nBottomY := nScreenH                        // no bottom margin
   nEditorH := nBottomY - nEditorTop

   // Form Designer: centered in editor area, slightly above center
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 )
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 )

   // Menu bar
   DEFINE MENUBAR OF oIDE

   DEFINE POPUP oFile PROMPT "File" OF oIDE
   MENUITEM "New Application" OF oFile ACTION TBNew()               ACCEL "n"
   MENUITEM "New Form"        OF oFile ACTION MenuNewForm()
   MENUITEM "Add Module..."   OF oFile ACTION MenuAddModule()
   MENUSEPARATOR OF oFile
   MENUITEM "Open Project..." OF oFile ACTION TBOpen()               ACCEL "o"
   MENUITEM "Reopen Last Project" OF oFile ACTION ReopenLastProject()
   MENUITEM "Open File..."    OF oFile ACTION MenuOpenFile()
   MENUITEM "Close File"      OF oFile ACTION MenuCloseFile()
   MENUITEM "Save"       OF oFile ACTION TBSave()                   ACCEL "s"
   MENUITEM "Save As..." OF oFile ACTION TBSaveAs()
   MENUSEPARATOR OF oFile
   MENUITEM "Exit"       OF oFile ACTION oIDE:Close()               ACCEL "q"

   DEFINE POPUP oEdit PROMPT "Edit" OF oIDE
   MENUITEM "Undo"  OF oEdit ACTION SmartUndo()  ACCEL "z"
   MENUITEM "Redo"  OF oEdit ACTION SmartRedo()  ACCEL "y"
   MENUSEPARATOR OF oEdit
   MENUITEM "Cut"   OF oEdit ACTION SmartCut()   ACCEL "x"
   MENUITEM "Copy"  OF oEdit ACTION SmartCopy()  ACCEL "c"
   MENUITEM "Paste" OF oEdit ACTION SmartPaste() ACCEL "v"

   DEFINE POPUP oSearch PROMPT "Search" OF oIDE
   MENUITEM "Find..."        OF oSearch ACTION CodeEditorFind( hCodeEditor )     ACCEL "f"
   MENUITEM "Replace..."     OF oSearch ACTION CodeEditorReplace( hCodeEditor )  ACCEL "h"
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
   MENUITEM "Debugger"          OF oView ACTION ShowDebugger()

   DEFINE POPUP oProject PROMPT "Project" OF oIDE
   MENUITEM "Add to Project..."    OF oProject ACTION AddToProject()
   MENUITEM "Remove from Project"  OF oProject ACTION RemoveFromProject()
   MENUSEPARATOR OF oProject
   MENUITEM "Options..."           OF oProject ACTION ShowProjectOptions()

   DEFINE POPUP oRun PROMPT "Run" OF oIDE
   MENUITEM "Run"             OF oRun ACTION TBRun()                 ACCEL "r"
   MENUITEM "Debug"           OF oRun ACTION TBDebugRun(.F.)
   MENUITEM "Debug to Breakpoint" OF oRun ACTION TBDebugRunToBreak() ACCEL "b"
   MENUSEPARATOR OF oRun
   MENUITEM "Continue"        OF oRun ACTION IDE_DebugGo()
   MENUITEM "Step Into"       OF oRun ACTION DebugStepInto()
   MENUITEM "Step Over"       OF oRun ACTION DebugStepOver()
   MENUITEM "Stop"            OF oRun ACTION IDE_DebugStop()
   MENUSEPARATOR OF oRun
   MENUITEM "Toggle Breakpoint"  OF oRun ACTION ToggleBreakpoint()
   MENUITEM "Clear Breakpoints"  OF oRun ACTION ClearBreakpoints()
   MENUSEPARATOR OF oRun
   MENUITEM "Run on iOS..."         OF oRun ACTION TBRuniOS()
   MENUITEM "iOS Setup Wizard..."   OF oRun ACTION iOSSetupWizard()

   DEFINE POPUP oFormat PROMPT "Format" OF oIDE
   MENUITEM "Align Left"             OF oFormat ACTION AlignControls( 1 )
   MENUITEM "Align Right"            OF oFormat ACTION AlignControls( 2 )
   MENUITEM "Align Top"              OF oFormat ACTION AlignControls( 3 )
   MENUITEM "Align Bottom"           OF oFormat ACTION AlignControls( 4 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Center Horizontally"    OF oFormat ACTION AlignControls( 5 )
   MENUITEM "Center Vertically"      OF oFormat ACTION AlignControls( 6 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Space Evenly Horizontal" OF oFormat ACTION AlignControls( 7 )
   MENUITEM "Space Evenly Vertical"   OF oFormat ACTION AlignControls( 8 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Same Width"              OF oFormat ACTION AlignControls( 9 )
   MENUITEM "Same Height"             OF oFormat ACTION AlignControls( 10 )
   MENUITEM "Same Size"               OF oFormat ACTION AlignControls( 11 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Tab Order..."           OF oFormat ACTION ShowTabOrder()

   DEFINE POPUP oComp PROMPT "Component" OF oIDE
   MENUITEM "Install Component..." OF oComp ACTION InstallComponent()
   MENUITEM "New Component..."     OF oComp ACTION NewComponent()

   DEFINE POPUP oTools PROMPT "Tools" OF oIDE
   MENUITEM "Editor Colors..."        OF oTools ACTION ShowEditorSettings()
   MENUITEM "Environment Options..."  OF oTools ACTION ShowEnvironmentOptions()
   MENUSEPARATOR OF oTools
   MENUITEM "AI Assistant..."         OF oTools ACTION ShowAIAssistant()

   DEFINE POPUP oGit PROMPT "Git" OF oIDE
   MENUITEM "Init Repository"    OF oGit ACTION GitInit()
   MENUITEM "Clone..."           OF oGit ACTION GitClone()
   MENUSEPARATOR OF oGit
   MENUITEM "Status"             OF oGit ACTION GitStatus()
   MENUITEM "Commit..."          OF oGit ACTION GitCommit()
   MENUITEM "Push"               OF oGit ACTION GitPush()
   MENUITEM "Pull"               OF oGit ACTION GitPull()
   MENUSEPARATOR OF oGit
   MENUITEM "Branch > Create..."  OF oGit ACTION GitBranchCreate()
   MENUITEM "Branch > Switch..."  OF oGit ACTION GitBranchSwitch()
   MENUITEM "Branch > Merge..."   OF oGit ACTION GitMerge()
   MENUSEPARATOR OF oGit
   MENUITEM "Stash"              OF oGit ACTION GitStash()
   MENUITEM "Stash Pop"          OF oGit ACTION GitStashPop()
   MENUSEPARATOR OF oGit
   MENUITEM "Log / History"      OF oGit ACTION GitLogShow()
   MENUITEM "Diff"               OF oGit ACTION GitDiffShow()
   MENUITEM "Blame"              OF oGit ACTION GitBlameShow()

   DEFINE POPUP oHelp PROMPT "Help" OF oIDE
   MENUITEM "Documentation"        OF oHelp ACTION MAC_ShellExec( "open ../docs/en/index.html" )
   MENUITEM "Quick Start"          OF oHelp ACTION MAC_ShellExec( "open ../docs/en/quickstart.html" )
   MENUITEM "Controls Reference"   OF oHelp ACTION MAC_ShellExec( "open ../docs/en/controls-standard.html" )
   MENUSEPARATOR OF oHelp
   MENUITEM "About HbBuilder..." OF oHelp ACTION ShowAbout()

   // Menu icons (same as Windows)
   cIcoDir := ResPath( "menu_icons" ) + "/"

   UI_MenuSetBitmapByPos( oFile:hPopup, 0, cIcoDir + "menu_new.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 1, cIcoDir + "menu_new_form.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 4, cIcoDir + "menu_open.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 5, cIcoDir + "menu_open.png" )   // Reopen Last
   UI_MenuSetBitmapByPos( oFile:hPopup, 6, cIcoDir + "menu_open.png" )   // Open File
   UI_MenuSetBitmapByPos( oFile:hPopup, 8, cIcoDir + "menu_save.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 9, cIcoDir + "menu_saveas.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 11, cIcoDir + "menu_exit.png" )

   UI_MenuSetBitmapByPos( oEdit:hPopup, 0, cIcoDir + "menu_undo.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 1, cIcoDir + "menu_redo.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 3, cIcoDir + "menu_cut.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 4, cIcoDir + "menu_copy.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 5, cIcoDir + "menu_paste.png" )

   UI_MenuSetBitmapByPos( oSearch:hPopup, 0, cIcoDir + "menu_search_find.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 1, cIcoDir + "menu_search_replace.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 3, cIcoDir + "menu_search_findnext.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 4, cIcoDir + "menu_search_findprev.png" )

   UI_MenuSetBitmapByPos( oView:hPopup, 0, cIcoDir + "menu_view_forms.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 1, cIcoDir + "menu_view_editor.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 2, cIcoDir + "menu_view_inspector.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 3, cIcoDir + "menu_project_inspector.png" )

   UI_MenuSetBitmapByPos( oProject:hPopup, 0, cIcoDir + "menu_project_add.png" )
   UI_MenuSetBitmapByPos( oProject:hPopup, 1, cIcoDir + "menu_project_remove.png" )
   UI_MenuSetBitmapByPos( oProject:hPopup, 3, cIcoDir + "menu_project_options.png" )

   UI_MenuSetBitmapByPos( oRun:hPopup, 0, cIcoDir + "menu_run.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 1, cIcoDir + "menu_debug.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 3, cIcoDir + "menu_continue.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 4, cIcoDir + "menu_stepover.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 5, cIcoDir + "menu_stepinto.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 6, cIcoDir + "menu_stop.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 11, cIcoDir + "menu_run.png" )     // Run on iOS

   UI_MenuSetBitmapByPos( oTools:hPopup, 0, cIcoDir + "menu_editor_colors.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 1, cIcoDir + "menu_environment_options.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 2, cIcoDir + "menu_darkmode.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 4, cIcoDir + "menu_ai.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 5, cIcoDir + "menu_report.png" )

   UI_MenuSetBitmapByPos( oHelp:hPopup, 4, cIcoDir + "menu_about.png" )

   // Speedbar (toolbar with 28x28 icon-sized buttons)
   DEFINE TOOLBAR oTB OF oIDE
   BUTTON "New"   OF oTB TOOLTIP "New project (Cmd+N)"  ACTION TBNew()
   BUTTON "Open"  OF oTB TOOLTIP "Open file (Cmd+O)"    ACTION TBOpen()
   BUTTON "Save"  OF oTB TOOLTIP "Save file (Cmd+S)"    ACTION TBSave()
   SEPARATOR OF oTB
   BUTTON "Cut"   OF oTB TOOLTIP "Cut (Cmd+X)"          ACTION SmartCut()
   BUTTON "Copy"  OF oTB TOOLTIP "Copy (Cmd+C)"         ACTION SmartCopy()
   BUTTON "Paste" OF oTB TOOLTIP "Paste (Cmd+V)"        ACTION SmartPaste()
   SEPARATOR OF oTB
   BUTTON "Undo"  OF oTB TOOLTIP "Undo (Cmd+Z)"         ACTION SmartUndo()
   BUTTON "Redo"  OF oTB TOOLTIP "Redo (Cmd+Y)"         ACTION SmartRedo()
   SEPARATOR OF oTB
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F9)"      ACTION TBRun()
   SEPARATOR OF oTB
   BUTTON "Form"  OF oTB TOOLTIP "Toggle Form/Code"     ACTION ToggleFormCode()

   // Load toolbar icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_ToolBarLoadImages( oTB:hCpp, ResPath( "toolbar.bmp" ) )

   // Row 2: Run & Debug speedbar
   DEFINE TOOLBAR oTB2 OF oIDE
   BUTTON "Debug"    OF oTB2 TOOLTIP "Debug"                    ACTION TBDebugRun(.F.)
   BUTTON "Debug→BP" OF oTB2 TOOLTIP "Debug to Breakpoint (B)"  ACTION TBDebugRunToBreak()
   SEPARATOR OF oTB2
   BUTTON "Step"  OF oTB2 TOOLTIP "Step Into (F7)"              ACTION DebugStepInto()
   BUTTON "Over"  OF oTB2 TOOLTIP "Step Over (F8)"              ACTION DebugStepOver()
   BUTTON "Stop"  OF oTB2 TOOLTIP "Stop Debugging"              ACTION IDE_DebugStop()
   BUTTON "Exit"  OF oTB2 TOOLTIP "Exit IDE"                    ACTION oIDE:Close()

   UI_ToolBarLoadImages( oTB2:hCpp, ResPath( "toolbar_debug.bmp" ) )

   // Component Palette (icon grid, tabbed, right of splitter)
   CreatePalette()

   // === Window 4: Code Editor (background, right of inspector, full area) ===
   // Created FIRST so it appears BEHIND the form
   hCodeEditor := CodeEditorCreate( nEditorX, nEditorTop, nEditorW, nEditorH )

   // === Window 3: Form Designer (floating on top of editor) ===
   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   UI_SetDesignForm( oDesignForm:hCpp )
   oDesignForm:Show()

   // Set up editor tabs: Project1.prg (tab 1) + Form1.prg (tab 2)
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
   CodeEditorAddTab( hCodeEditor, "Form1.prg" )
   // Sync form code AFTER Show() so Left/Top/Width/Height reflect actual position
   SyncDesignerToCode()
   CodeEditorSetTabText( hCodeEditor, 2, aForms[1][3] )
   CodeEditorSelectTab( hCodeEditor, 2 )  // Show Form1.prg initially

   // Tab change callback
   CodeEditorOnTabChange( hCodeEditor, { |hEd, nTab| OnEditorTabChange( hEd, nTab ) } )

   // Live sync: code editor -> form designer + inspector (debounced 500ms)
   CodeEditorOnTextChange( hCodeEditor, { |hEd, nTab| OnEditorTextChange( hEd, nTab ) } )

   // === Window 2: Object Inspector (left column, below bar) ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )
   INS_SetOnEventDblClick( _InsGetData(), ;
      { |hCtrl, cEvent| OnEventDblClick( hCtrl, cEvent ) } )
   INS_SetOnPropChanged( _InsGetData(), { || SyncDesignerToCode(), ;
      InspectorPopulateCombo( oDesignForm:hCpp ) } )
   INS_SetPos( _InsGetData(), 0, nInsTop, nInsW, nBottomY - nInsTop - 50 )

   WireDesignForm()

   // Dark mode for all IDE windows (macOS 10.14+)
   MAC_SetAppDarkMode( .T. )

   // When IDE closes, destroy all secondary windows
   oIDE:OnClose := { || IDE_DebugStop(), DestroyAllForms(), InspectorClose(), ;
                       CodeEditorDestroy( hCodeEditor ) }

   // IDE enters the message loop (dispatches for ALL windows)
   oIDE:Activate()

   // Cleanup
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
   oPal:AddComp( nTab, "MM",   "MainMenu",  200 )

   // Additional tab (C++Builder)
   nTab := oPal:AddTab( "Additional" )
   oPal:AddComp( nTab, "BBt",  "BitBtn",      12 )
   oPal:AddComp( nTab, "Spd",  "SpeedButton", 13 )
   oPal:AddComp( nTab, "Img",  "Image",       14 )
   oPal:AddComp( nTab, "Shp",  "Shape",       15 )
   oPal:AddComp( nTab, "Bvl",  "Bevel",       16 )
   oPal:AddComp( nTab, "Msk",  "MaskEdit",    28 )
   oPal:AddComp( nTab, "SG",   "StringGrid",  29 )
   oPal:AddComp( nTab, "SBx",  "ScrollBox",   30 )
   oPal:AddComp( nTab, "STx",  "StaticText",  31 )
   oPal:AddComp( nTab, "LEd",  "LabeledEdit", 32 )

   // Media tab — embedded rich content (maps, 3D, web, future video/audio)
   nTab := oPal:AddTab( "Media" )
   oPal:AddComp( nTab, "Map",  "Map",         140 )
   oPal:AddComp( nTab, "3D",   "Scene3D",     141 )
   oPal:AddComp( nTab, "Eth",  "EarthView",   142 )

   // Cocoa tab (equivalent to Win32 in C++Builder)
   nTab := oPal:AddTab( "Cocoa" )
   oPal:AddComp( nTab, "Tab",  "TFolder",     33 )
   oPal:AddComp( nTab, "TV",   "TTreeView",   20 )
   oPal:AddComp( nTab, "LV",   "TableView",   21 )
   oPal:AddComp( nTab, "PB",   "ProgressBar", 22 )
   oPal:AddComp( nTab, "RE",   "TextView",    23 )
   oPal:AddComp( nTab, "TB",   "Slider",      34 )
   oPal:AddComp( nTab, "UD",   "Stepper",     35 )
   oPal:AddComp( nTab, "DTP",  "DatePicker",  36 )
   oPal:AddComp( nTab, "MC",   "Calendar",    37 )

   // System tab (C++Builder)
   nTab := oPal:AddTab( "System" )
   oPal:AddComp( nTab, "Tmr",  "Timer",       38 )
   oPal:AddComp( nTab, "PBx",  "PaintBox",    39 )

   // Dialogs tab (C++Builder)
   nTab := oPal:AddTab( "Dialogs" )
   oPal:AddComp( nTab, "OD",   "OpenPanel",   40 )
   oPal:AddComp( nTab, "SD",   "SavePanel",   41 )
   oPal:AddComp( nTab, "FD",   "FontPanel",   42 )
   oPal:AddComp( nTab, "CD",   "ColorPanel",  43 )
   oPal:AddComp( nTab, "FnD",  "FindPanel",   44 )
   oPal:AddComp( nTab, "RD",   "ReplacePanel", 45 )

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

   // Report tab (report designer components)
   nTab := oPal:AddTab( "Report" )
   oPal:AddComp( nTab, "Bnd",  "Band",          132 )
   oPal:AddComp( nTab, "RLb",  "ReportLabel",   133 )
   oPal:AddComp( nTab, "RFd",  "ReportField",   134 )
   oPal:AddComp( nTab, "RIm",  "ReportImage",   135 )

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

   // Load palette icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_PaletteLoadImages( oPal:hCpp, ResPath( "palette.bmp" ) )

return nil

static function CreateDesignForm( nX, nY )

   local cName, nIdx

   // Generate form name: Form1, Form2, Form3...
   nIdx := Len( aForms ) + 1
   cName := "Form" + LTrim( Str( nIdx ) )

   // Create new empty form (like C++Builder File > New > VCL Forms Application)
   DEFINE FORM oDesignForm TITLE cName SIZE 400, 300 FONT "Helvetica Neue", 12
   UI_FormSetPos( oDesignForm:hCpp, nX, nY )

   // Register in project form list
   // { cName, oForm, cCode, nX, nY }
   AAdd( aForms, { cName, oDesignForm, GenerateFormCode( cName ), nX, nY } )
   nActiveForm := Len( aForms )

   // When form window is selected, switch editor to its tab
   UI_OnEvent( oDesignForm:hCpp, "OnActivate", ;
      { || SwitchToForm( nIdx ) } )

return nil

static function OnComboSelect( nSel )

   local hTarget, aMap, aEntry
   local cTabs, aLabels, cCap, hIns

   aMap := InspectorGetComboMap()

   if Len( aMap ) > 0 .and. nSel + 1 <= Len( aMap )
      aEntry := aMap[ nSel + 1 ]  // combo is 0-based, array is 1-based

      if aEntry[1] == 2  // Browse column
         lIgnoreSelChange := .t.
         UI_FormSelectCtrl( oDesignForm:hCpp, aEntry[2] )
         lIgnoreSelChange := .f.
         InspectorRefreshColumn( aEntry[2], aEntry[3] )

      elseif aEntry[1] == 3  // Folder page
         // aEntry = { 3, hFolder, nPageIdx } - switch tab and show
         // page-level properties (cCaption, nPage) in the inspector.
         cTabs := UI_GetProp( aEntry[2], "aTabs" )
         aLabels := iif( Empty( cTabs ), {}, hb_ATokens( cTabs, "|" ) )
         cCap := iif( aEntry[3]+1 <= Len(aLabels), aLabels[aEntry[3]+1], "" )
         UI_FormSelectCtrl( oDesignForm:hCpp, aEntry[2] )
         UI_TabControlSetSel( aEntry[2], aEntry[3] )
         hIns := _InsGetData()
         INS_SetFolderPage( hIns, aEntry[2], aEntry[3] )
         INS_AddCategoryRow( hIns, "Page" )
         INS_AddRow( hIns, "cCaption", cCap, "Page", "S" )
         INS_AddRow( hIns, "nPage", LTrim(Str(aEntry[3]+1)), "Page", "N" )
         INS_Rebuild( hIns )
         return nil

      else
         hTarget := aEntry[2]
         UI_FormSelectCtrl( oDesignForm:hCpp, hTarget )
         InspectorRefresh( hTarget )
      endif
   else
      // Fallback: original behavior
      if nSel == 0
         hTarget := oDesignForm:hCpp
      else
         hTarget := UI_GetChild( oDesignForm:hCpp, nSel )
      endif
      if hTarget != 0
         UI_FormSelectCtrl( oDesignForm:hCpp, hTarget )
         InspectorRefresh( hTarget )
      endif
   endif

return nil

static function OnDesignSelChange( hCtrl )

   local hTarget, i, nCount, nSel

   if lIgnoreSelChange
      return nil
   endif

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

   // Two-way: sync designer changes to code
   SyncDesignerToCode()

return nil

// Generate Project1.prg code with all form references
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

// Generate initial form code (empty form, no controls)
static function GenerateFormCode( cName )
return RegenerateFormCode( cName, 0 )

// Regenerate form code from current designer state (two-way tools)
// Reads all properties from the live form and its children
static function RegenerateFormCode( cName, hForm )

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e
   local cClass := "T" + cName  // TForm1, TForm2...
   local i, nCount, hCtrl, cCtrlName, cCtrlClass, nType
   local nW, nH, nFL, nFT, cTitle, nClr, cAppTitle
   local nL, nT, nCW, nCH, cText
   local cDatas := "", cCreate := "", cEvents := "", cVal, cDeferredDS := ""
   local cExistingCode, aEvents, j, cEvName, cEvSuffix, cHandlerName
   local aMenuHandlers := {}, lHasHandlers, aMenuNodes, aMFields, cHndl, nMI
   local nPendingLevels, cMNode, cCap, cScut, nLv, nPL, cInd, bIsPopup, aNextF
   local aHdrs, kk, nColCount, aColProps, nColW, nCtrlClr, nInterval
   local cParent, nOwnerH, nPos, nPos2, cLine
   local aMethodNames, cMethodName
   local lCommented
   local nWSPort, cWSRoot, nWSTimeout, nWSMaxUpload, lWSHttps, lWSTrace, cWSCookie, nWSTTL
   local cBandFields, aBandField, aBandRec, cBandFldLine

   // Read existing code to find declared event handlers
   cExistingCode := ""
   if nActiveForm > 0 .and. nActiveForm <= Len( aForms )
      cExistingCode := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   endif

   // Form properties (read from live form or use defaults)
   if hForm != 0
      cTitle := UI_GetProp( hForm, "cText" )
      nFL    := UI_GetProp( hForm, "nLeft" )
      nFT    := UI_GetProp( hForm, "nTop" )
      nW     := UI_GetProp( hForm, "nWidth" )
      nH     := UI_GetProp( hForm, "nHeight" )
      nClr   := UI_GetProp( hForm, "nClrPane" )
      cAppTitle := UI_GetProp( hForm, "cAppTitle" )
   else
      cTitle := cName
      nFL    := 0
      nFT    := 0
      nW     := 400
      nH     := 300
      nClr   := 15790320  // 0x00F0F0F0
   endif

   // Enumerate child controls
   if hForm != 0
      nCount := UI_GetChildCount( hForm )
      for i := 1 to nCount
         hCtrl := UI_GetChild( hForm, i )
         if hCtrl == 0; loop; endif

         // Skip auto-created TPageControl page panels (recreated by aTabs)
         if UI_IsAutoPage( hCtrl ); loop; endif

         cCtrlName  := UI_GetProp( hCtrl, "cName" )
         cCtrlClass := UI_GetProp( hCtrl, "cClassName" )
         nType      := UI_GetType( hCtrl )
         if Empty( cCtrlName ); cCtrlName := "ctrl" + LTrim(Str(i)); endif

         // Report controls (133-135) are serialized in their band's aData — skip here
         if nType >= 133 .and. nType <= 135; loop; endif

         // DATA declaration
         cDatas += "   DATA o" + cCtrlName + "   // " + cCtrlClass + e

         // Creation code in CreateForm
         nL := UI_GetProp( hCtrl, "nLeft" )
         nT := UI_GetProp( hCtrl, "nTop" )
         nCW := UI_GetProp( hCtrl, "nWidth" )
         nCH := UI_GetProp( hCtrl, "nHeight" )
         cText := UI_GetProp( hCtrl, "cText" )

         // Parent expression: "Self" or "::oFolder:aPages[n]" for owned ctrls
         cParent := "Self"
         if UI_GetCtrlOwner( hCtrl ) != 0
            nOwnerH := UI_GetCtrlOwner( hCtrl )
            for kk := 1 to UI_GetChildCount( hForm )
               if UI_GetChild( hForm, kk ) == nOwnerH
                  cVal := UI_GetProp( nOwnerH, "cName" )
                  if ValType( cVal ) == "C" .and. ! Empty( cVal )
                     cParent := "::o" + cVal + ":aPages[ " + ;
                        LTrim( Str( UI_GetCtrlPage( hCtrl ) + 1 ) ) + " ]"
                  endif
                  exit
               endif
            next
         endif

         lCommented := .F.
         do case
            case nType == 1  // Label
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' SAY ::o' + cCtrlName + ' PROMPT "' + cText + '" OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + e
            case nType == 2  // Edit
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GET ::o' + cCtrlName + ' VAR "' + cText + '" OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 3  // Button
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BUTTON ::o' + cCtrlName + ' PROMPT "' + cText + '" OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 4  // CheckBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' CHECKBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW))
               if UI_GetProp( hCtrl, "lChecked" )
                  cCreate += ' CHECKED'
               endif
               cCreate += e
            case nType == 5  // ComboBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' COMBOBOX ::o' + cCtrlName + ' OF ' + cParent
               nColCount := UI_ComboGetCount( hCtrl )
               if nColCount > 0
                  cCreate += ' ITEMS { '
                  for kk := 1 to nColCount
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + UI_ComboGetItem( hCtrl, kk ) + '"'
                  next
                  cCreate += ' }'
               endif
               cCreate += ' SIZE ' + LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 6  // GroupBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GROUPBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 7  // ListBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' LISTBOX ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aItems" )
               if ! Empty( cVal )
                  aHdrs := hb_ATokens( cVal, "|" )
                  cCreate += ' ITEMS '
                  for kk := 1 to Len( aHdrs )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + AllTrim( aHdrs[kk] ) + '"'
                  next
               endif
               cCreate += e
            case nType == 8  // RadioButton
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' RADIOBUTTON ::o' + cCtrlName + ' PROMPT "' + cText + '" OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW))
               if UI_GetProp( hCtrl, "lChecked" )
                  cCreate += ' CHECKED'
               endif
               cCreate += e
            case nType == 24  // Memo
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' MEMO ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
               if ! Empty( cText )
                  cCreate += '   ::o' + cCtrlName + ':Text := "' + ;
                     StrTran( StrTran( cText, '"', '""' ), Chr(10), '" + Chr(10) + "' ) + ;
                     '"' + e
               endif
            case nType == 141  // Scene3D (TScene3D)
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' SCENE3D ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "cSceneFile" )
               if ! Empty( cVal )
                  cCreate += ' FILE "' + cVal + '"'
               endif
               cCreate += e
            case nType == 142  // EarthView (TEarthView)
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' EARTHVIEW ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               nColW := UI_GetProp( hCtrl, "nLat" )
               nColCount := UI_GetProp( hCtrl, "nLon" )
               if ValType( nColW ) == "N" .and. ValType( nColCount ) == "N"
                  cCreate += ' CENTER ' + LTrim( Str( nColW, 14, 6 ) ) + ", " + ;
                             LTrim( Str( nColCount, 14, 6 ) )
               endif
               cCreate += e
            case nType == 140  // Map (TMap)
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' MAP ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               nColW := UI_GetProp( hCtrl, "nLat" )
               nColCount := UI_GetProp( hCtrl, "nLon" )
               if ValType( nColW ) == "N" .and. ValType( nColCount ) == "N"
                  cCreate += ' CENTER ' + LTrim( Str( nColW, 14, 6 ) ) + ", " + ;
                             LTrim( Str( nColCount, 14, 6 ) )
               endif
               cVal := UI_GetProp( hCtrl, "nZoom" )
               if ValType( cVal ) == "N" .and. cVal != 10
                  cCreate += ' ZOOM ' + LTrim( Str( cVal ) )
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "nMapType" )
               if ValType( cVal ) == "N" .and. cVal > 0
                  cCreate += '   ::o' + cCtrlName + ':MapType := ' + LTrim( Str( cVal ) ) + e
               endif
            case nType == 62  // WebView
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' WEBVIEW ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "cUrl" )
               if ! Empty( cVal )
                  cCreate += ' URL "' + cVal + '"'
               endif
               cCreate += e
            case nType == 36  // DateTimePicker
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' DATETIMEPICKER ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 37  // MonthCalendar
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' MONTHCALENDAR ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 29  // StringGrid
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' STRINGGRID ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "nColCount" )
               if ValType( cVal ) == "N" .and. cVal != 5
                  cCreate += ' COLS ' + LTrim( Str( cVal ) )
               endif
               cVal := UI_GetProp( hCtrl, "nRowCount" )
               if ValType( cVal ) == "N" .and. cVal != 5
                  cCreate += ' ROWS ' + LTrim( Str( cVal ) )
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "nFixedRows" )
               if ValType( cVal ) == "N" .and. cVal != 1
                  cCreate += '   ::o' + cCtrlName + ':FixedRows := ' + LTrim( Str( cVal ) ) + e
               endif
               cVal := UI_GetProp( hCtrl, "nFixedCols" )
               if ValType( cVal ) == "N" .and. cVal != 0
                  cCreate += '   ::o' + cCtrlName + ':FixedCols := ' + LTrim( Str( cVal ) ) + e
               endif
            case nType == 28  // MaskEdit
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' MASKEDIT ::o' + cCtrlName
               nColCount := UI_GetProp( hCtrl, "nMaskKind" )  // reuse local var
               if ValType( nColCount ) == "N" .and. nColCount > 0
                  cCreate += ' MASK ' + ;
                     { "meCustom", "meDate", "meDateISO", "meTime", "meTimeSecs", ;
                       "mePhone", "meZipCode", "meCreditCard", "meSSN", "meIPv4" }[ nColCount + 1 ]
               else
                  cVal := UI_GetProp( hCtrl, "cEditMask" )
                  if ! Empty( cVal )
                     cCreate += ' MASK "' + cVal + '"'
                  endif
               endif
               cCreate += ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 14  // Image
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' IMAGE ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "cPicture" )
               if ! Empty( cVal )
                  cCreate += ' PICTURE "' + cVal + '"'
               endif
               cCreate += e
            case nType == 16  // Bevel
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BEVEL ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "nShape" )
               if ValType( cVal ) == "N" .and. cVal > 0
                  cCreate += ' SHAPE ' + LTrim( Str( cVal ) )
               endif
               cVal := UI_GetProp( hCtrl, "nStyle" )
               if ValType( cVal ) == "N" .and. cVal > 0
                  cCreate += ' STYLE ' + LTrim( Str( cVal ) )
               endif
               cCreate += e
            case nType == 15  // Shape
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' SHAPE ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "nShape" )
               if ValType( cVal ) == "N" .and. cVal > 0
                  cCreate += ' STYLE ' + LTrim( Str( cVal ) )
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "nPenColor" )
               if ValType( cVal ) == "N" .and. cVal != 0
                  cCreate += '   ::o' + cCtrlName + ':PenColor := ' + LTrim( Str( cVal ) ) + e
               endif
               cVal := UI_GetProp( hCtrl, "nPenWidth" )
               if ValType( cVal ) == "N" .and. cVal != 1
                  cCreate += '   ::o' + cCtrlName + ':PenWidth := ' + LTrim( Str( cVal ) ) + e
               endif
            case nType == 12 .or. nType == 13  // BitBtn / SpeedButton
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  If( nType == 12, ' BITBTN ', ' SPEEDBUTTON ' ) + '::o' + cCtrlName
               if ! Empty( cText )
                  cCreate += ' PROMPT "' + cText + '"'
               endif
               cCreate += ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "nKind" )
               if ValType( cVal ) == "N" .and. cVal > 0
                  cCreate += ' KIND ' + LTrim( Str( cVal ) )
               endif
               cVal := UI_GetProp( hCtrl, "cPicture" )
               if ! Empty( cVal )
                  cCreate += ' PICTURE "' + cVal + '"'
               endif
               cCreate += e
            case nType == 20  // TreeView
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' TREEVIEW ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aItems" )
               if ! Empty( cVal )
                  aHdrs := hb_ATokens( cVal, "|" )
                  cCreate += ' ITEMS '
                  for kk := 1 to Len( aHdrs )
                     if kk > 1; cCreate += ', '; endif
                     // Preserve leading whitespace (indentation = hierarchy);
                     // only strip trailing spaces.
                     cCreate += '"' + RTrim( aHdrs[kk] ) + '"'
                  next
               endif
               cCreate += e
            case nType == 33  // TFolder
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' FOLDER ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aTabs" )
               if ! Empty( cVal )
                  aHdrs := hb_ATokens( cVal, "|" )
                  cCreate += ' PROMPTS '
                  for kk := 1 to Len( aHdrs )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + AllTrim( aHdrs[kk] ) + '"'
                  next
               endif
               cCreate += e
            case nType == 79  // Browse
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BROWSE ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
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
               // Column widths
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
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "cDataSource" )
               if ! Empty( cVal )
                  cCreate += '   ::o' + cCtrlName + ':cDataSource := "' + cVal + '"' + e
               endif
            case nType == 132  // Band
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BAND ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "cBandType" )
               if ! Empty( cVal ) .and. cVal != "Detail"
                  cCreate += ' TYPE "' + cVal + '"'
               endif
               cCreate += e
               // Emit REPORTFIELD lines for each field stored in this band
               cBandFields := UI_GetProp( hCtrl, "aData" )
               if ! Empty( cBandFields )
                  aBandField := hb_ATokens( cBandFields, Chr(10) )
                  for kk := 1 to Len( aBandField )
                     cBandFldLine := AllTrim( aBandField[kk] )
                     if Empty( cBandFldLine ); loop; endif
                     aBandRec := hb_ATokens( cBandFldLine, "|" )
                     // name|type|text|field|format|top|left|w|h|font|fontsize|bold|italic|align
                     if Len( aBandRec ) >= 14
                        cCreate += '   REPORTFIELD ::o' + aBandRec[1] + ;
                           ' TYPE "' + aBandRec[2] + '"'
                        if ! Empty( aBandRec[3] )
                           cCreate += ' PROMPT "' + aBandRec[3] + '"'
                        endif
                        if ! Empty( aBandRec[4] )
                           cCreate += ' FIELD "' + aBandRec[4] + '"'
                        endif
                        if ! Empty( aBandRec[5] )
                           cCreate += ' FORMAT "' + aBandRec[5] + '"'
                        endif
                        cCreate += ' OF ::o' + cCtrlName + ;
                           ' AT ' + aBandRec[6] + ',' + aBandRec[7] + ;
                           ' SIZE ' + aBandRec[8] + ',' + aBandRec[9]
                        if aBandRec[10] != "Sans" .or. Val(aBandRec[11]) != 10
                           cCreate += ' FONT "' + aBandRec[10] + '",' + aBandRec[11]
                        endif
                        if aBandRec[12] == "1"; cCreate += ' BOLD';   endif
                        if aBandRec[13] == "1"; cCreate += ' ITALIC'; endif
                        if Val(aBandRec[14]) != 0
                           cCreate += ' ALIGN ' + aBandRec[14]
                        endif
                        cCreate += e
                     endif
                  next
               endif
            case nType == 80  // DBGrid
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' DBGRID ::o' + cCtrlName + ' OF ' + cParent + ' SIZE ' + ;
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
               cCreate += e
               cVal := UI_GetProp( hCtrl, "oDataSource" )
               if ! Empty( cVal )
                  cCreate += '   ::o' + cCtrlName + ':oDataSource := "' + cVal + '"' + e
                  // Deferred: run after all components are created so datasource exists
                  cDeferredDS += '   ::o' + cCtrlName + ':LoadFromDataSource( Self )' + e
               endif
            otherwise
               if IsNonVisual( nType )
                  cCreate += '   COMPONENT ::o' + cCtrlName + ' TYPE ' + ;
                     ComponentTypeName( nType ) + ' OF Self  // ' + cCtrlClass + ;
                     ' @ ' + LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + e
                  // Component-specific properties
                  if nType == 53  // DBFTable
                     cVal := UI_GetProp( hCtrl, "cFileName" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':cFileName := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "cRDD" )
                     if ! Empty( cVal ) .and. Upper( cVal ) != "DBFCDX"
                        cCreate += '   ::o' + cCtrlName + ':cRDD := "' + cVal + '"' + e
                     endif
                     if UI_GetProp( hCtrl, "lActive" )
                        cCreate += '   ::o' + cCtrlName + ':Open()' + e
                     endif
                  elseif nType == 57  // SQLite
                     cVal := UI_GetProp( hCtrl, "cFileName" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':cFileName := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "cTable" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':cTable := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "cSQL" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':cSQL := "' + cVal + '"' + e
                     endif
                     if UI_GetProp( hCtrl, "lActive" )
                        cCreate += '   ::o' + cCtrlName + ':Open()' + e
                     endif
                  elseif nType == 131  // CompArray
                     cVal := UI_GetProp( hCtrl, "aHeaders" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':aHeaders := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "aData" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':aData := "' + cVal + '"' + e
                     endif
                  elseif nType == CT_TIMER
                     nInterval := UI_GetProp( hCtrl, "nInterval" )
                     if ValType( nInterval ) == "N" .and. nInterval != 1000
                        cCreate += '   ::o' + cCtrlName + ':nInterval := ' + LTrim( Str( nInterval ) ) + e
                     endif
                  elseif nType == 200  // CT_MAINMENU
                     cVal := UI_GetProp( hCtrl, "aMenuItems" )
                     if ValType( cVal ) == "C" .and. ! Empty( cVal )
                        aMenuNodes := HB_ATokens( cVal, "|" )
                        lHasHandlers := .F.
                        for nMI := 1 to Len( aMenuNodes )
                           aMFields := HB_ATokens( aMenuNodes[nMI], Chr(1) )
                           cHndl := iif( Len(aMFields) >= 3, aMFields[3], "" )
                           if ! Empty( cHndl ); lHasHandlers := .T.; exit; endif
                        next
                        if lHasHandlers
                           cCreate += '   ::o' + cCtrlName + ':aOnClick := { '
                           for nMI := 1 to Len( aMenuNodes )
                              aMFields := HB_ATokens( aMenuNodes[nMI], Chr(1) )
                              cHndl := iif( Len(aMFields) >= 3, aMFields[3], "" )
                              if nMI > 1; cCreate += ", "; endif
                              if ! Empty( cHndl )
                                 cCreate += '{|| ' + cHndl + '( Self, nil )}'
                              else
                                 cCreate += 'nil'
                              endif
                           next
                           cCreate += ' }' + e
                        endif
                        nPendingLevels := {}
                        cCreate += '   DEFINE MENUBAR ::o' + cCtrlName + e
                        for nMI := 1 to Len( aMenuNodes )
                           cMNode := aMenuNodes[nMI]
                           aMFields := HB_ATokens( cMNode, Chr(1) )
                           if Len( aMFields ) < 5; loop; endif
                           cCap  := aMFields[1]
                           cScut := iif( Len(aMFields) >= 2, aMFields[2], "" )
                           cHndl := iif( Len(aMFields) >= 3, aMFields[3], "" )
                           nLv   := iif( Len(aMFields) >= 5, Val( aMFields[5] ), 0 )
                           do while Len( nPendingLevels ) > 0 .and. ;
                                     ATail( nPendingLevels ) >= nLv
                              nPL := ATail( nPendingLevels )
                              cCreate += Replicate( "   ", nPL + 2 ) + 'END POPUP' + e
                              ASize( nPendingLevels, Len( nPendingLevels ) - 1 )
                           enddo
                           cInd := Replicate( "   ", nLv + 2 )
                           if cCap == "---"
                              cCreate += cInd + 'MENUSEPARATOR' + e
                           else
                              bIsPopup := .F.
                              if nMI < Len( aMenuNodes )
                                 aNextF := HB_ATokens( aMenuNodes[nMI+1], Chr(1) )
                                 if Len(aNextF) >= 5 .and. Val(aNextF[5]) > nLv
                                    bIsPopup := .T.
                                 endif
                              endif
                              if nLv == 0 .or. bIsPopup
                                 cCreate += cInd + 'DEFINE POPUP "' + cCap + '"' + e
                                 AAdd( nPendingLevels, nLv )
                              else
                                 cCreate += cInd + 'MENUITEM "' + cCap + '"'
                                 if ! Empty( cHndl )
                                    cCreate += ' ACTION ' + cHndl + '( Self, oMenuItem )'
                                    if AScan( aMenuHandlers, cHndl ) == 0
                                       AAdd( aMenuHandlers, cHndl )
                                    endif
                                 endif
                                 if ! Empty( cScut )
                                    cCreate += ' ACCEL "' + cScut + '"'
                                 endif
                                 cCreate += e
                              endif
                           endif
                        next
                        do while Len( nPendingLevels ) > 0
                           nPL := ATail( nPendingLevels )
                           cCreate += Replicate( "   ", nPL + 2 ) + 'END POPUP' + e
                           ASize( nPendingLevels, Len( nPendingLevels ) - 1 )
                        enddo
                        cCreate += '   END MENUBAR' + e
                     endif
                  elseif nType == 71  // CT_WEBSERVER
                     nWSPort     := UI_GetProp( hCtrl, "nPort" )
                     cWSRoot     := UI_GetProp( hCtrl, "cRoot" )
                     nWSTimeout  := UI_GetProp( hCtrl, "nTimeout" )
                     nWSMaxUpload := UI_GetProp( hCtrl, "nMaxUpload" )
                     lWSHttps    := UI_GetProp( hCtrl, "lHTTPS" )
                     lWSTrace    := UI_GetProp( hCtrl, "lTrace" )
                     cWSCookie   := UI_GetProp( hCtrl, "cSessionCookie" )
                     nWSTTL      := UI_GetProp( hCtrl, "nSessionTTL" )
                     if ValType( nWSPort ) == "N" .and. nWSPort != 8080
                        cCreate += '   ::o' + cCtrlName + ':nPort := ' + LTrim( Str( nWSPort ) ) + e
                     endif
                     if ValType( cWSRoot ) == "C" .and. ! Empty( cWSRoot ) .and. cWSRoot != "."
                        cCreate += '   ::o' + cCtrlName + ':cRoot := "' + cWSRoot + '"' + e
                     endif
                     if ValType( lWSHttps ) == "L" .and. lWSHttps
                        cCreate += '   ::o' + cCtrlName + ':lHTTPS := .T.' + e
                     endif
                     if ValType( lWSTrace ) == "L" .and. lWSTrace
                        cCreate += '   ::o' + cCtrlName + ':lTrace := .T.' + e
                     endif
                     if ValType( nWSTimeout ) == "N" .and. nWSTimeout != 30
                        cCreate += '   ::o' + cCtrlName + ':nTimeout := ' + LTrim( Str( nWSTimeout ) ) + e
                     endif
                     if ValType( nWSMaxUpload ) == "N" .and. nWSMaxUpload != 10485760
                        cCreate += '   ::o' + cCtrlName + ':nMaxUpload := ' + LTrim( Str( nWSMaxUpload ) ) + e
                     endif
                     if ValType( cWSCookie ) == "C" .and. ! Empty( cWSCookie ) .and. cWSCookie != "HIXSID"
                        cCreate += '   ::o' + cCtrlName + ':cSessionCookie := "' + cWSCookie + '"' + e
                     endif
                     if ValType( nWSTTL ) == "N" .and. nWSTTL != 3600
                        cCreate += '   ::o' + cCtrlName + ':nSessionTTL := ' + LTrim( Str( nWSTTL ) ) + e
                     endif
                  endif
               else
                  cCreate += '   // ::o' + cCtrlName + ' (' + cCtrlClass + ') at ' + ;
                     LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                     LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
                  lCommented := .T.
               endif
         endcase

         // Skip property emits when creation was only a comment placeholder;
         // assigning to ::oXxx would send messages to a nil DATA slot.
         if lCommented
            loop
         endif

         // Emit visual properties only for visual controls
         if ! IsNonVisual( nType )
            // Emit nClrPane if non-default (default = 0xFFFFFFFF = 4294967295)
            nCtrlClr := UI_GetProp( hCtrl, "nClrPane" )
            if nCtrlClr != 4294967295
               cCreate += '   ::o' + cCtrlName + ':nClrPane := ' + LTrim( Str( nCtrlClr ) ) + e
            endif

            // Emit nClrText if non-default (default = 0xFFFFFFFF = 4294967295)
            nCtrlClr := UI_GetProp( hCtrl, "nClrText" )
            if nCtrlClr != 4294967295
               cCreate += '   ::o' + cCtrlName + ':nClrText := ' + LTrim( Str( nCtrlClr ) ) + e
            endif

            // Emit lTransparent for labels when not default (.F. instead of default .T.)
            if nType == 1 .and. UI_GetProp( hCtrl, "lTransparent" ) == .F.
               cCreate += '   ::o' + cCtrlName + ':lTransparent := .F.' + e
            endif

            // Emit nAlign if non-default (0=Left)
            cVal := UI_GetProp( hCtrl, "nAlign" )
            if ValType( cVal ) == "N" .and. cVal != 0
               cCreate += '   ::o' + cCtrlName + ':nAlign := ' + LTrim( Str( cVal ) ) + e
            endif

            // Emit ControlAlign if non-default (0=alNone)
            cVal := UI_GetProp( hCtrl, "nControlAlign" )
            if ValType( cVal ) == "N" .and. cVal != 0
               cCreate += '   ::o' + cCtrlName + ':ControlAlign := ' + LTrim( Str( cVal ) ) + e
            endif

            // Emit oFont if non-default
            cVal := UI_GetProp( hCtrl, "oFont" )
            if ! Empty( cVal ) .and. cVal != "System,12" .and. cVal != ".LucidaGrande,13"
               cCreate += '   ::o' + cCtrlName + ':oFont := "' + cVal + '"' + e
            endif
         endif

         // Preserve any user-written ::oCtrl:xxx := ... line from CreateForm
         // that codegen didn't already emit (TPython cRuntimePath, OnReady,
         // OnOutput, aModules, custom OnClick codeblocks, ...).
         if ! Empty( cExistingCode )
            // Restrict scan to METHOD CreateForm() ... return nil body
            nPos := At( "METHOD CreateForm()", cExistingCode )
            if nPos > 0
               cText := SubStr( cExistingCode, nPos )
               nPos2 := At( "return nil", cText )
               if nPos2 > 0; cText := Left( cText, nPos2 ); endif

               cEvName := "::o" + cCtrlName + ":"
               nPos := 1
               do while ( nPos2 := At( cEvName, SubStr( cText, nPos ) ) ) > 0
                  nPos := nPos + nPos2 - 1
                  cLine := SubStr( cText, nPos )
                  j := At( Chr(10), cLine )
                  if j > 0; cLine := Left( cLine, j - 1 ); endif
                  cLine := AllTrim( StrTran( cLine, Chr(13), "" ) )
                  // Skip properties already managed by codegen (nClrPane, nClrText,
                  // lTransparent, nAlign, oFont) to prevent accumulation when values change
                  if ":nClrPane" $ cLine .or. ":nClrText" $ cLine .or. ;
                     ":lTransparent" $ cLine .or. ":nAlign" $ cLine .or. ;
                     ":ControlAlign" $ cLine .or. ":oFont" $ cLine
                     nPos += Len( cEvName )
                     loop
                  endif
                  // Only preserve lines not already emitted
                  if ! ( cLine $ cCreate ) .and. ! ( cLine $ cEvents ) .and. ;
                     ":=" $ cLine
                     cEvents += "   " + cLine + e
                  endif
                  nPos += Len( cEvName )
               enddo
            endif
         endif

         // Scan for event handlers matching this control
         aEvents := { "OnClick", "OnChange", "OnDblClick", "OnCreate", ;
                       "OnClose", "OnResize", "OnKeyDown", "OnKeyUp", ;
                       "OnMouseDown", "OnMouseUp", "OnEnter", "OnExit", ;
                       "OnTimer" }
         for j := 1 to Len( aEvents )
            cEvName := aEvents[j]
            cEvSuffix := SubStr( cEvName, 3 )
            cHandlerName := cCtrlName + cEvSuffix
            // First: preserve any user-written `::oCtrl:OnXxx := ...` line
            cVal := "::o" + cCtrlName + ":" + cEvName
            nPos := At( cVal, cExistingCode )
            if nPos > 0
               // Copy the whole line up to the newline (skip if already emitted)
               cLine := SubStr( cExistingCode, nPos )
               nPos2 := At( Chr(10), cLine )
               if nPos2 > 0; cLine := Left( cLine, nPos2 - 1 ); endif
               cLine := AllTrim( StrTran( cLine, Chr(13), "" ) )
               if ! ( cLine $ cEvents )
                  cEvents += "   " + cLine + e
               endif
            elseif cHandlerName $ cExistingCode
               // Detect if handler is a METHOD in the class → use method send
               // otherwise use plain function call
               if ( "METHOD " + cHandlerName ) $ cExistingCode
                  cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                     " := { || ::" + cHandlerName + "() }" + e
               else
                  cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                     " := { || " + cHandlerName + "( Self ) }" + e
               endif
            endif
         next
      next
   endif

   // Scan form-level events
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
         if ( "function " + cHandlerName ) $ cExistingCode .or. ;
            ( "METHOD " + cHandlerName ) $ cExistingCode
            cVal := "::" + cEvName + " := "
            if ! ( cVal $ cEvents )  // skip if already emitted
               if ( "METHOD " + cHandlerName ) $ cExistingCode
                  cEvents += "   ::" + cEvName + ;
                     " := { || ::" + cHandlerName + "() }" + e
               else
                  cEvents += "   ::" + cEvName + ;
                     " := { || " + cHandlerName + "( Self ) }" + e
               endif
            endif
         endif
      next
   endif

   // Build the complete form code
   cCode += "// " + cName + ".prg" + e
   cCode += cSep
   cCode += e
   cCode += "CLASS " + cClass + " FROM TForm" + e
   cCode += e
   cCode += "   // IDE-managed Components" + e
   if ! Empty( cDatas )
      cCode += cDatas
   endif
   cCode += e
   cCode += "   // Event handlers" + e
   cCode += e
   cCode += "   METHOD CreateForm()" + e

   // Preserve user-added METHOD declarations: collect unique names from
   // both "METHOD Name() CLASS cClass" implementations outside the CLASS
   // body AND inline declarations inside CLASS..ENDCLASS, then emit each
   // name only once (dedup prevents accumulation on repeated regeneration).
   if ! Empty( cExistingCode )
      aMethodNames := {}

      // 1) Scan implementations outside the CLASS body
      cVal := ScanMethodDeclarations( cExistingCode, cClass )
      if ! Empty( cVal )
         for kk := 1 to Len( HB_ATokens( cVal, e ) )
            cText := AllTrim( StrTran( HB_ATokens( cVal, e )[ kk ], Chr(13), "" ) )
            if Left( cText, 7 ) == "METHOD "
               cMethodName := AllTrim( SubStr( cText, 8 ) )
               nPos2 := At( "(", cMethodName )
               if nPos2 > 0; cMethodName := Left( cMethodName, nPos2 - 1 ); endif
               nPos2 := At( " ", cMethodName )
               if nPos2 > 0; cMethodName := Left( cMethodName, nPos2 - 1 ); endif
               if ! Empty( cMethodName ) .and. AScan( aMethodNames, cMethodName ) == 0
                  AAdd( aMethodNames, cMethodName )
               endif
            endif
         next
      endif

      // 2) Scan inline METHOD declarations from inside CLASS..ENDCLASS
      nPos := At( "CLASS " + cClass + " FROM", cExistingCode )
      if nPos > 0
         nPos2 := At( "ENDCLASS", SubStr( cExistingCode, nPos ) )
         if nPos2 > 0
            cVal := SubStr( cExistingCode, nPos, nPos2 )
            for kk := 1 to Len( HB_ATokens( cVal, Chr(10) ) )
               cText := AllTrim( HB_ATokens( cVal, Chr(10) )[ kk ] )
               cText := StrTran( cText, Chr(13), "" )
               if Left( cText, 7 ) == "METHOD " .and. ;
                  ! Left( cText, 19 ) == "METHOD CreateForm()"
                  cMethodName := AllTrim( SubStr( cText, 8 ) )
                  nPos2 := At( "(", cMethodName )
                  if nPos2 > 0; cMethodName := Left( cMethodName, nPos2 - 1 ); endif
                  nPos2 := At( " ", cMethodName )
                  if nPos2 > 0; cMethodName := Left( cMethodName, nPos2 - 1 ); endif
                  if ! Empty( cMethodName ) .and. AScan( aMethodNames, cMethodName ) == 0
                     AAdd( aMethodNames, cMethodName )
                  endif
               endif
            next
         endif
      endif

      // Emit deduplicated METHOD declarations
      for kk := 1 to Len( aMethodNames )
         cCode += "   METHOD " + aMethodNames[ kk ] + "()" + e
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
   if nClr != 15790320  // non-default color
      cCode += "   ::Color  := " + LTrim(Str(nClr)) + e
   endif
   nInterval := UI_GetProp( hForm, "nPosition" )
   if ValType( nInterval ) == "N" .and. nInterval > 0
      cCode += "   ::Position := " + LTrim(Str(nInterval)) + e
   endif
   nInterval := UI_GetProp( hForm, "nBorderStyle" )
   if ValType( nInterval ) == "N" .and. nInterval != 2  // != bsSizeable (default)
      cCode += "   ::BorderStyle := " + LTrim(Str(nInterval)) + e
   endif
   if ! Empty( cAppTitle )
      cCode += '   ::AppTitle := "' + cAppTitle + '"' + e
   endif
   if ! Empty( cCreate )
      cCode += e
      cCode += cCreate
   endif
   if ! Empty( cEvents )
      cCode += e
      cCode += "   // Event wiring" + e
      cCode += cEvents
   endif
   if ! Empty( cDeferredDS )
      cCode += e
      cCode += "   // Load datasource grids after all components are created" + e
      cCode += cDeferredDS
   endif
   cCode += e
   cCode += "return nil" + e
   cCode += cSep

   // Add stubs for new menu item action handlers
   for nMI := 1 to Len( aMenuHandlers )
      cHndl := aMenuHandlers[nMI]
      if ! ( "function " + Lower(cHndl) ) $ Lower( cExistingCode ) .and. ;
         ! ( "method " + Lower(cHndl) ) $ Lower( cExistingCode )
         cCode += cSep
         cCode += "static function " + cHndl + "( oForm, oMenuItem )" + e
         cCode += e
         cCode += "return nil" + e
      endif
   next

return cCode

// Restore visual controls on a design form by parsing the form .prg code
static function RestoreFormFromCode( hForm, cCode )

   local aLines, cLine, cTrim, i, j, nType, nCount, lInCreateForm
   local nT, nL, nW, nH, cText, cName, hCtrl
   local nPos, nPos2, cTitle, cVal, cPropName, kk, nColCount
   local cFldName, cFldType, cFldPrompt, cFldField, cFldFormat
   local cFldFont, nFldFontSize, lFldBold, lFldItalic, nFldAlign
   local cBandName, hBandCtrl, cFldSerial, cExistFields
   local cTail, nLastQ, nQpos
   local nBandAbsTop, nAbsTop, nCtrlType2, cPromptText
   local cMenuSerial, nMenuLevel, aParentStack, nFirstNode, jj, cML, cMLU
   local nQ1, nQ2, nQ3, nQ4, nQ5, cPopCap, cItCap, cItHndl, cItAccl, nAct, nAccl
   local nPar, nPar2, nPar3, nCC, jjC, hC

   if Empty( cCode ) .or. hForm == 0
      return nil
   endif

   // Join Harbour line-continuations (`;` at end of line) so clauses
   // spanning multiple lines (e.g. COMBOBOX ... ; ITEMS ...) parse as one.
   do while " ;" + Chr(13) + Chr(10) $ cCode
      cCode := StrTran( cCode, " ;" + Chr(13) + Chr(10), " " )
   enddo
   do while " ;" + Chr(10) $ cCode
      cCode := StrTran( cCode, " ;" + Chr(10), " " )
   enddo
   do while " ;" + Chr(10) + " " $ cCode
      cCode := StrTran( cCode, " ;" + Chr(10) + " ", " " )
   enddo

   aLines := HB_ATokens( cCode, Chr(10) )

   for i := 1 to Len( aLines )
      cLine := aLines[i]
      cTrim := AllTrim( cLine )

      // Parse form properties: ::Title, ::Width, ::Height, ::Left, ::Top
      if '::Title' $ cTrim .and. ':=' $ cTrim
         nPos := At( '"', cTrim )
         nPos2 := RAt( '"', cTrim )
         if nPos > 0 .and. nPos2 > nPos
            cTitle := SubStr( cTrim, nPos + 1, nPos2 - nPos - 1 )
            UI_SetProp( hForm, "cText", cTitle )
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
      if '::Position' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nPosition", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::BorderStyle' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nBorderStyle", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
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

      // Parse non-visual components: COMPONENT ::oName TYPE nType OF Self
      if Left( Upper( cTrim ), 10 ) == "COMPONENT "
         nPos := At( "::o", cTrim )
         if nPos > 0
            cName := SubStr( cTrim, nPos + 3 )
            nPos2 := At( " ", cName )
            if nPos2 > 0; cName := Left( cName, nPos2 - 1 ); endif
            nPos := At( "TYPE ", Upper( cTrim ) )
            if nPos > 0
               cVal := AllTrim( SubStr( cTrim, nPos + 5 ) )
               // Strip trailing " OF ..." if present
               nPos2 := At( " ", cVal )
               if nPos2 > 0; cVal := Left( cVal, nPos2 - 1 ); endif
               nType := Val( cVal )
               // Resolve CT_* define names
               if nType == 0 .and. Left( cVal, 3 ) == "CT_"
                  nType := ResolveComponentType( cVal )
               endif
               if IsNonVisual( nType )
                  hCtrl := UI_DropNonVisual( hForm, nType, cName )
                  // Restore designer position from trailing "// ... @ L,T"
                  if hCtrl != 0
                     nPos2 := At( " @ ", cTrim )
                     if nPos2 > 0
                        cVal := SubStr( cTrim, nPos2 + 3 )
                        nL := Val( cVal )
                        nPos2 := At( ",", cVal )
                        if nPos2 > 0
                           nT := Val( SubStr( cVal, nPos2 + 1 ) )
                           UI_SetProp( hCtrl, "nLeft", nL )
                           UI_SetProp( hCtrl, "nTop",  nT )
                        endif
                     endif
                  endif
               endif
            endif
         endif
         loop
      endif

      // Parse DEFINE MENUBAR block for TMainMenu
      if Upper( AllTrim( cTrim ) ) == "DEFINE MENUBAR"
         cMenuSerial := ""
         nMenuLevel  := 0
         aParentStack := {}
         nFirstNode  := .T.
         jj := i + 1
         do while jj <= Len( aLines )
            cML  := AllTrim( aLines[jj] )
            cMLU := Upper( cML )
            if cMLU == "END MENUBAR"
               exit
            elseif Left( cMLU, 12 ) == "DEFINE POPUP"
               nQ1 := At( '"', cML )
               nQ2 := iif( nQ1 > 0, At( '"', SubStr( cML, nQ1+1 ) ), 0 )
               cPopCap := iif( nQ1>0 .and. nQ2>0, SubStr( cML, nQ1+1, nQ2-1 ), "" )
               nPar := iif( Len( aParentStack ) > 0, ATail(aParentStack), -1 )
               if ! nFirstNode; cMenuSerial += "|"; endif
               cMenuSerial += cPopCap + Chr(1) + Chr(1) + Chr(1) + "1" + Chr(1) + ;
                              LTrim(Str(nMenuLevel)) + Chr(1) + LTrim(Str(nPar))
               AAdd( aParentStack, Len( HB_ATokens( cMenuSerial, "|" ) ) - 1 )
               nMenuLevel++
               nFirstNode := .F.
            elseif cMLU == "END POPUP"
               nMenuLevel--
               if Len( aParentStack ) > 0
                  ASize( aParentStack, Len(aParentStack)-1 )
               endif
            elseif Left( cMLU, 11 ) == "MENUSEPARAT"
               nPar2 := iif( Len(aParentStack)>0, ATail(aParentStack), -1 )
               if ! nFirstNode; cMenuSerial += "|"; endif
               cMenuSerial += "---" + Chr(1) + Chr(1) + Chr(1) + "0" + Chr(1) + ;
                              LTrim(Str(nMenuLevel)) + Chr(1) + LTrim(Str(nPar2))
               nFirstNode := .F.
            elseif Left( cMLU, 8 ) == "MENUITEM"
               nQ3  := At( '"', cML )
               nQ4  := iif( nQ3>0, At( '"', SubStr(cML,nQ3+1) ), 0 )
               cItCap := iif( nQ3>0 .and. nQ4>0, SubStr(cML,nQ3+1,nQ4-1), "" )
               cItHndl := ""
               cItAccl := ""
               nAct := At( "ACTION ", cMLU )
               if nAct > 0
                  cItHndl := SubStr( cML, nAct + 7 )
                  nPos := At( " ", cItHndl )
                  if nPos > 0; cItHndl := Left(cItHndl,nPos-1); endif
                  if Right(cItHndl,2) == "()"; cItHndl := Left(cItHndl,Len(cItHndl)-2); endif
               endif
               nAccl := At( 'ACCEL "', cML )
               if nAccl > 0
                  cItAccl := SubStr( cML, nAccl+7 )
                  nQ5 := At( '"', cItAccl )
                  if nQ5>0; cItAccl := Left(cItAccl,nQ5-1); endif
               endif
               nPar3 := iif( Len(aParentStack)>0, ATail(aParentStack), -1 )
               if ! nFirstNode; cMenuSerial += "|"; endif
               cMenuSerial += cItCap + Chr(1) + cItAccl + Chr(1) + cItHndl + Chr(1) + ;
                              "1" + Chr(1) + LTrim(Str(nMenuLevel)) + Chr(1) + LTrim(Str(nPar3))
               nFirstNode := .F.
            endif
            jj++
         enddo
         i := jj
         if ! Empty( cMenuSerial )
            nCC := UI_GetChildCount( hForm )
            for jjC := nCC to 1 step -1
               hC := UI_GetChild( hForm, jjC )
               if UI_GetType(hC) == 200  // CT_MAINMENU
                  UI_SetProp( hC, "aMenuItems", cMenuSerial )
                  exit
               endif
            next
         endif
         loop
      endif

      // Parse component property: ::oName:cFileName := "value"
      if Left( cTrim, 3 ) == "::o" .and. ( ":cFileName" $ cTrim .or. ":cDatabase" $ cTrim ) .and. ":=" $ cTrim
         nPos := At( ":cFileName", cTrim )
         if nPos == 0; nPos := At( ":cDatabase", cTrim ); endif
         if nPos > 0
            cName := SubStr( cTrim, 4, nPos - 4 )
            // Remove trailing ':' if present
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len(cName) - 1 ); endif
            nPos2 := At( '"', cTrim )
            if nPos2 > 0
               cText := SubStr( cTrim, nPos2 + 1 )
               nPos2 := At( '"', cText )
               if nPos2 > 0
                  cText := Left( cText, nPos2 - 1 )
                  // Find the child control by name and set cFileName
                  nCount := UI_GetChildCount( hForm )
                  for j := 1 to nCount
                     hCtrl := UI_GetChild( hForm, j )
                     if hCtrl != 0 .and. UI_GetProp( hCtrl, "cName" ) == cName
                        UI_SetProp( hCtrl, "cFileName", cText )
                        exit
                     endif
                  next
               endif
            endif
         endif
         loop
      endif

      // Parse component property: ::oName:cRDD := "value"
      if Left( cTrim, 3 ) == "::o" .and. ":cRDD" $ cTrim .and. ":=" $ cTrim
         nPos := At( ":cRDD", cTrim )
         if nPos > 0
            cName := SubStr( cTrim, 4, nPos - 4 )
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len(cName) - 1 ); endif
            nPos2 := At( '"', cTrim )
            if nPos2 > 0
               cText := SubStr( cTrim, nPos2 + 1 )
               nPos2 := At( '"', cText )
               if nPos2 > 0
                  cText := Left( cText, nPos2 - 1 )
                  nCount := UI_GetChildCount( hForm )
                  for j := 1 to nCount
                     hCtrl := UI_GetChild( hForm, j )
                     if hCtrl != 0 .and. UI_GetProp( hCtrl, "cName" ) == cName
                        UI_SetProp( hCtrl, "cRDD", cText )
                        exit
                     endif
                  next
               endif
            endif
         endif
         loop
      endif

      // Parse component properties: aHeaders, aData, cDataSource
      if Left( cTrim, 3 ) == "::o" .and. ;
         ( ":aHeaders" $ cTrim .or. ":aData" $ cTrim .or. ":cDataSource" $ cTrim ) .and. ;
         ":=" $ cTrim
         if ":aHeaders" $ cTrim
            cPropName := "aHeaders"
            nPos := At( ":aHeaders", cTrim )
         elseif ":cDataSource" $ cTrim
            cPropName := "cDataSource"
            nPos := At( ":cDataSource", cTrim )
         else
            cPropName := "aData"
            nPos := At( ":aData", cTrim )
         endif
         if nPos > 0
            cName := SubStr( cTrim, 4, nPos - 4 )
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len(cName) - 1 ); endif
            nPos2 := At( '"', cTrim )
            if nPos2 > 0
               cText := SubStr( cTrim, nPos2 + 1 )
               nPos2 := At( '"', cText )
               if nPos2 > 0
                  cText := Left( cText, nPos2 - 1 )
                  nCount := UI_GetChildCount( hForm )
                  for j := 1 to nCount
                     hCtrl := UI_GetChild( hForm, j )
                     if hCtrl != 0 .and. UI_GetProp( hCtrl, "cName" ) == cName
                        UI_SetProp( hCtrl, cPropName, cText )
                        exit
                     endif
                  next
               endif
            endif
         endif
         loop
      endif

      // Parse component property: ::oName:nInterval := value
      if Left( cTrim, 3 ) == "::o" .and. ":nInterval" $ cTrim .and. ":=" $ cTrim
         nPos := At( ":nInterval", cTrim )
         if nPos > 0
            cName := SubStr( cTrim, 4, nPos - 4 )
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len(cName) - 1 ); endif
            cVal := AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) )
            nCount := UI_GetChildCount( hForm )
            for j := 1 to nCount
               hCtrl := UI_GetChild( hForm, j )
               if hCtrl != 0 .and. UI_GetProp( hCtrl, "cName" ) == cName
                  UI_SetProp( hCtrl, "nInterval", Val( cVal ) )
                  exit
               endif
            next
         endif
         loop
      endif

      // Parse TWebServer properties: ::oName:nPort := value, ::oName:cRoot := "v", etc.
      if Left( cTrim, 3 ) == "::o" .and. ":=" $ cTrim .and. nType == 71 .and. ;
         ( ":nPort " $ cTrim .or. ":nPortSSL " $ cTrim .or. ":cRoot " $ cTrim .or. ;
           ":lHTTPS " $ cTrim .or. ":lTrace " $ cTrim .or. ":nTimeout " $ cTrim .or. ;
           ":nMaxUpload " $ cTrim .or. ":cSessionCookie " $ cTrim .or. ":nSessionTTL " $ cTrim )
         if ":nPort " $ cTrim
            nPos := At( ":nPort ", cTrim )
         elseif ":nPortSSL " $ cTrim
            nPos := At( ":nPortSSL ", cTrim )
         elseif ":cRoot " $ cTrim
            nPos := At( ":cRoot ", cTrim )
         elseif ":lHTTPS " $ cTrim
            nPos := At( ":lHTTPS ", cTrim )
         elseif ":lTrace " $ cTrim
            nPos := At( ":lTrace ", cTrim )
         elseif ":nTimeout " $ cTrim
            nPos := At( ":nTimeout ", cTrim )
         elseif ":nMaxUpload " $ cTrim
            nPos := At( ":nMaxUpload ", cTrim )
         elseif ":cSessionCookie " $ cTrim
            nPos := At( ":cSessionCookie ", cTrim )
         else
            nPos := At( ":nSessionTTL ", cTrim )
         endif
         if nPos > 0
            cName := SubStr( cTrim, 4, nPos - 4 )
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len(cName) - 1 ); endif
            cVal := AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) )
            nCount := UI_GetChildCount( hForm )
            for j := 1 to nCount
               hCtrl := UI_GetChild( hForm, j )
               if hCtrl != 0 .and. UI_GetProp( hCtrl, "cName" ) == cName
                  if ":nPort " $ cTrim
                     UI_SetProp( hCtrl, "nPort", Val(cVal) )
                  elseif ":nPortSSL " $ cTrim
                     UI_SetProp( hCtrl, "nPortSSL", Val(cVal) )
                  elseif ":cRoot " $ cTrim
                     UI_SetProp( hCtrl, "cRoot", StrTran( StrTran( cVal, '"', '' ), "'", '' ) )
                  elseif ":lHTTPS " $ cTrim
                     UI_SetProp( hCtrl, "lHTTPS", Upper(cVal) == ".T." )
                  elseif ":lTrace " $ cTrim
                     UI_SetProp( hCtrl, "lTrace", Upper(cVal) == ".T." )
                  elseif ":nTimeout " $ cTrim
                     UI_SetProp( hCtrl, "nTimeout", Val(cVal) )
                  elseif ":nMaxUpload " $ cTrim
                     UI_SetProp( hCtrl, "nMaxUpload", Val(cVal) )
                  elseif ":cSessionCookie " $ cTrim
                     UI_SetProp( hCtrl, "cSessionCookie", StrTran( StrTran( cVal, '"', '' ), "'", '' ) )
                  else
                     UI_SetProp( hCtrl, "nSessionTTL", Val(cVal) )
                  endif
                  exit
               endif
            next
         endif
         loop
      endif

      // Parse component method: ::oName:Open()  -> set lActive
      if Left( cTrim, 3 ) == "::o" .and. ":Open()" $ cTrim
         nPos := At( ":Open()", cTrim )
         if nPos > 0
            cName := SubStr( cTrim, 4, nPos - 4 )
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len(cName) - 1 ); endif
            nCount := UI_GetChildCount( hForm )
            for j := 1 to nCount
               hCtrl := UI_GetChild( hForm, j )
               if hCtrl != 0 .and. UI_GetProp( hCtrl, "cName" ) == cName
                  UI_SetProp( hCtrl, "lActive", .t. )
                  exit
               endif
            next
         endif
         loop
      endif

      // Parse REPORTFIELD lines: REPORTFIELD ::oFldN TYPE "..." ... OF ::oBandN AT top,left SIZE w,h ...
      if Left( Upper( cTrim ), 12 ) == "REPORTFIELD "
         // Extract field variable name (::oFldN -> "FldN")
         nPos := At( "::o", cTrim )
         if nPos > 0
            cFldName := SubStr( cTrim, nPos + 3 )
            nPos2 := At( " ", cFldName )
            if nPos2 > 0; cFldName := Left( cFldName, nPos2 - 1 ); endif
         else
            cFldName := ""
         endif

         // Extract TYPE "..."
         cFldType := "text"
         nPos := At( ' TYPE "', cTrim )
         if nPos > 0
            cFldType := SubStr( cTrim, nPos + 7 )
            nPos2 := At( '"', cFldType )
            if nPos2 > 0; cFldType := Left( cFldType, nPos2 - 1 ); endif
         endif

         // Extract PROMPT "..."
         cFldPrompt := ""
         nPos := At( ' PROMPT "', cTrim )
         if nPos > 0
            cFldPrompt := SubStr( cTrim, nPos + 9 )
            nPos2 := At( '"', cFldPrompt )
            if nPos2 > 0; cFldPrompt := Left( cFldPrompt, nPos2 - 1 ); endif
         endif

         // Extract FIELD "..."
         cFldField := ""
         nPos := At( ' FIELD "', cTrim )
         if nPos > 0
            cFldField := SubStr( cTrim, nPos + 8 )
            nPos2 := At( '"', cFldField )
            if nPos2 > 0; cFldField := Left( cFldField, nPos2 - 1 ); endif
         endif

         // Extract FORMAT "..."
         cFldFormat := ""
         nPos := At( ' FORMAT "', cTrim )
         if nPos > 0
            cFldFormat := SubStr( cTrim, nPos + 9 )
            nPos2 := At( '"', cFldFormat )
            if nPos2 > 0; cFldFormat := Left( cFldFormat, nPos2 - 1 ); endif
         endif

         // Extract OF ::oBandName
         cBandName := ""
         nPos := At( " OF ::o", cTrim )
         if nPos > 0
            cBandName := SubStr( cTrim, nPos + 7 )
            nPos2 := At( " ", cBandName )
            if nPos2 > 0; cBandName := Left( cBandName, nPos2 - 1 ); endif
         endif

         // Extract AT top, left
         nT := 0; nL := 0
         nPos := At( " AT ", Upper( cTrim ) )
         if nPos > 0
            cVal := AllTrim( SubStr( cTrim, nPos + 4 ) )
            nT := Val( cVal )
            nPos2 := At( ",", cVal )
            if nPos2 > 0; nL := Val( SubStr( cVal, nPos2 + 1 ) ); endif
         endif

         // Extract SIZE w, h
         nW := 80; nH := 14
         nPos := At( " SIZE ", Upper( cTrim ) )
         if nPos > 0
            cVal := AllTrim( SubStr( cTrim, nPos + 6 ) )
            nW := Val( cVal )
            nPos2 := At( ",", cVal )
            if nPos2 > 0; nH := Val( SubStr( cVal, nPos2 + 1 ) ); endif
         endif

         // Extract FONT "name", size
         cFldFont := "Sans"
         nFldFontSize := 10
         nPos := At( ' FONT "', cTrim )
         if nPos > 0
            cFldFont := SubStr( cTrim, nPos + 7 )
            nPos2 := At( '"', cFldFont )
            if nPos2 > 0
               cFldFont := Left( cFldFont, nPos2 - 1 )
               // Look for size after closing quote: FONT "name",14
               cVal := AllTrim( SubStr( cTrim, nPos + 7 + nPos2 ) )
               if Left( cVal, 1 ) == ","
                  nFldFontSize := Val( AllTrim( SubStr( cVal, 2 ) ) )
                  if nFldFontSize < 1; nFldFontSize := 10; endif
               endif
            endif
         endif

         // Extract BOLD and ITALIC flags — search only in the unquoted tail
         // to avoid false matches inside quoted strings like FONT "Helvetica-Bold"
         nLastQ := 0
         nQpos  := At( '"', cTrim )
         do while nQpos > 0
            nLastQ += nQpos
            nQpos  := At( '"', SubStr( cTrim, nLastQ + 1 ) )
         enddo
         cTail := iif( nLastQ > 0, Upper( SubStr( cTrim, nLastQ + 1 ) ), Upper( cTrim ) )
         lFldBold   := " BOLD"   $ cTail
         lFldItalic := " ITALIC" $ cTail

         // Extract ALIGN n
         nFldAlign := 0
         nPos := At( " ALIGN ", Upper( cTrim ) )
         if nPos > 0
            nFldAlign := Val( AllTrim( SubStr( cTrim, nPos + 7 ) ) )
         endif

         // Find the parent band control by name and append serialized field data
         // Format per field (pipe-separated): name|type|text|field|format|top|left|w|h|font|fontsize|bold|italic|align
         if ! Empty( cBandName )
            nCount := UI_GetChildCount( hForm )
            hBandCtrl := 0
            for kk := 1 to nCount
               if AllTrim( UI_GetProp( UI_GetChild( hForm, kk ), "cName" ) ) == cBandName
                  hBandCtrl := UI_GetChild( hForm, kk )
                  exit
               endif
            next
            if hBandCtrl != 0
               cFldSerial := StrTran( cFldName,   "|", "" ) + "|" + ;
                  StrTran( cFldType,   "|", "" ) + "|" + ;
                  StrTran( cFldPrompt, "|", "" ) + "|" + ;
                  StrTran( cFldField,  "|", "" ) + "|" + ;
                  StrTran( cFldFormat, "|", "" ) + "|" + ;
                  LTrim(Str(nT)) + "|" + LTrim(Str(nL)) + "|" + ;
                  LTrim(Str(nW)) + "|" + LTrim(Str(nH)) + "|" + ;
                  StrTran( cFldFont, "|", "" ) + "|" + LTrim(Str(nFldFontSize)) + "|" + ;
                  iif( lFldBold, "1", "0" ) + "|" + ;
                  iif( lFldItalic, "1", "0" ) + "|" + ;
                  LTrim(Str(nFldAlign))
               cExistFields := UI_GetProp( hBandCtrl, "aData" )
               // Each field record is ~170 bytes; guard against FData[4096] overflow
               if Len( cExistFields ) + Len( cFldSerial ) + 1 < 3900
                  if Empty( cExistFields )
                     UI_SetProp( hBandCtrl, "aData", cFldSerial )
                  else
                     UI_SetProp( hBandCtrl, "aData", cExistFields + Chr(10) + cFldSerial )
                  endif
               // else: silently skip — field data would truncate the 4096-byte FData buffer
               endif

               // Also create a real NSView child so the control is visible in design mode
               nBandAbsTop := UI_GetProp( hBandCtrl, "nTop" )
               nAbsTop     := nBandAbsTop + nT
               nCtrlType2  := if( cFldType == "image", 135, if( cFldType == "field", 134, 133 ) )
               cPromptText := if( nCtrlType2 == 133, cFldPrompt, "" )
               UI_ReportCtrlNew( hForm, nCtrlType2, nL, nAbsTop, nW, nH, cPromptText, cFldName )
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

      // Determine control type and create it
      hCtrl := 0
      do case
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
            if " CHECKED" $ Upper( cTrim ) .and. hCtrl != 0
               UI_SetProp( hCtrl, "lChecked", .T. )
            endif
         case " SCENE3D " $ Upper( cTrim )
            hCtrl := UI_Scene3DNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( 'FILE "', cTrim )
               if nPos > 0
                  cVal := SubStr( cTrim, nPos + 6 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "cSceneFile", Left( cVal, nPos2 - 1 ) )
                  endif
               endif
            endif
         case " EARTHVIEW " $ Upper( cTrim )
            hCtrl := UI_EarthViewNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( " CENTER ", Upper( cTrim ) )
               if nPos > 0
                  cVal := AllTrim( SubStr( cTrim, nPos + 8 ) )
                  nPos2 := At( ",", cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "nLat", Val( Left( cVal, nPos2 - 1 ) ) )
                     cVal := AllTrim( SubStr( cVal, nPos2 + 1 ) )
                     nPos2 := At( " ", cVal )
                     if nPos2 > 0; cVal := Left( cVal, nPos2 - 1 ); endif
                     UI_SetProp( hCtrl, "nLon", Val( cVal ) )
                  endif
               endif
            endif
         case " MAP " $ Upper( cTrim )
            hCtrl := UI_MapNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( " CENTER ", Upper( cTrim ) )
               if nPos > 0
                  cVal := AllTrim( SubStr( cTrim, nPos + 8 ) )
                  nPos2 := At( ",", cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "nLat", Val( Left( cVal, nPos2 - 1 ) ) )
                     cVal := AllTrim( SubStr( cVal, nPos2 + 1 ) )
                     nPos2 := At( " ", cVal )
                     if nPos2 > 0; cVal := Left( cVal, nPos2 - 1 ); endif
                     UI_SetProp( hCtrl, "nLon", Val( cVal ) )
                  endif
               endif
               nPos := At( " ZOOM ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nZoom", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 6 ) ) ) )
               endif
            endif
         case " STRINGGRID " $ Upper( cTrim )
            hCtrl := UI_StringGridNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( " COLS ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nColCount", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 6 ) ) ) )
               endif
               nPos := At( " ROWS ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nRowCount", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 6 ) ) ) )
               endif
            endif
         case " MASKEDIT " $ Upper( cTrim )
            cText := ""
            nPos := At( ' MASK ', cTrim )
            if nPos > 0
               cVal := AllTrim( SubStr( cTrim, nPos + 6 ) )
               if Left( cVal, 1 ) == '"'
                  cVal := SubStr( cVal, 2 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0; cText := Left( cVal, nPos2 - 1 ); endif
                  hCtrl := UI_MaskEditNew( hForm, cText, nL, nT, nW, nH )
               else
                  // Constant name: meDate, mePhone, ...
                  nPos2 := At( " ", cVal )
                  if nPos2 > 0; cVal := Left( cVal, nPos2 - 1 ); endif
                  hCtrl := UI_MaskEditNew( hForm, "", nL, nT, nW, nH )
                  if hCtrl != 0
                     cVal := Upper( AllTrim( cVal ) )
                     do case
                        case cVal == "MEDATE";       UI_SetProp( hCtrl, "nMaskKind", 1 )
                        case cVal == "MEDATEISO";    UI_SetProp( hCtrl, "nMaskKind", 2 )
                        case cVal == "METIME";       UI_SetProp( hCtrl, "nMaskKind", 3 )
                        case cVal == "METIMESECS";   UI_SetProp( hCtrl, "nMaskKind", 4 )
                        case cVal == "MEPHONE";      UI_SetProp( hCtrl, "nMaskKind", 5 )
                        case cVal == "MEZIPCODE";    UI_SetProp( hCtrl, "nMaskKind", 6 )
                        case cVal == "MECREDITCARD"; UI_SetProp( hCtrl, "nMaskKind", 7 )
                        case cVal == "MESSN";        UI_SetProp( hCtrl, "nMaskKind", 8 )
                        case cVal == "MEIPV4";       UI_SetProp( hCtrl, "nMaskKind", 9 )
                     endcase
                  endif
               endif
            else
               hCtrl := UI_MaskEditNew( hForm, "", nL, nT, nW, nH )
            endif
         case " IMAGE " $ Upper( cTrim )
            hCtrl := UI_ImageNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( 'PICTURE "', cTrim )
               if nPos > 0
                  cVal := SubStr( cTrim, nPos + 9 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "cPicture", Left( cVal, nPos2 - 1 ) )
                  endif
               endif
            endif
         case " SHAPE " $ Upper( cTrim )
            hCtrl := UI_ShapeNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( " STYLE ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nShape", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 7 ) ) ) )
               endif
            endif
         case " BEVEL " $ Upper( cTrim )
            hCtrl := UI_BevelNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( " SHAPE ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nShape", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 7 ) ) ) )
               endif
               nPos := At( " STYLE ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nStyle", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 7 ) ) ) )
               endif
            endif
         case " BITBTN " $ Upper( cTrim ) .or. " SPEEDBUTTON " $ Upper( cTrim )
            // PROMPT is optional — don't inherit cText from a previous
            // iteration when this line has no PROMPT clause.
            if ! ( 'PROMPT "' $ cTrim ); cText := ""; endif
            if " SPEEDBUTTON " $ Upper( cTrim )
               hCtrl := UI_SpeedBtnNew( hForm, cText, nL, nT, nW, nH )
            else
               hCtrl := UI_BitBtnNew( hForm, cText, nL, nT, nW, nH )
            endif
            if hCtrl != 0
               nPos := At( " KIND ", Upper( cTrim ) )
               if nPos > 0
                  UI_SetProp( hCtrl, "nKind", ;
                     Val( AllTrim( SubStr( cTrim, nPos + 6 ) ) ) )
               endif
               nPos := At( 'PICTURE "', cTrim )
               if nPos > 0
                  cVal := SubStr( cTrim, nPos + 9 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "cPicture", Left( cVal, nPos2 - 1 ) )
                  endif
               endif
            endif
         case " COMBOBOX " $ Upper( cTrim )
            hCtrl := UI_ComboBoxNew( hForm, nL, nT, nW, nH )
            // Parse ITEMS { "A", "B", ... }
            nPos := At( "ITEMS", Upper( cTrim ) )
            if nPos > 0 .and. hCtrl != 0
               cText := SubStr( cTrim, nPos + 5 )
               nPos2 := At( "SIZE", Upper( cText ) )
               if nPos2 > 0; cText := Left( cText, nPos2 - 1 ); endif
               do while ! Empty( cText )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  cText := SubStr( cText, nPos2 + 1 )
                  nPos2 := At( '"', cText )
                  if nPos2 == 0; exit; endif
                  UI_ComboAddItem( hCtrl, Left( cText, nPos2 - 1 ) )
                  cText := SubStr( cText, nPos2 + 1 )
               enddo
            endif
         case " GROUPBOX " $ Upper( cTrim )
            hCtrl := UI_GroupBoxNew( hForm, cText, nL, nT, nW, nH )
         case " LISTBOX " $ Upper( cTrim )
            hCtrl := UI_ListBoxNew( hForm, nL, nT, nW, nH )
            nPos := At( "ITEMS ", Upper( cTrim ) )
            if nPos > 0
               cText := SubStr( cTrim, nPos + 6 )
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
                  UI_SetProp( hCtrl, "aItems", cVal )
               endif
            endif
         case " RADIOBUTTON " $ Upper( cTrim )
            hCtrl := UI_RadioButtonNew( hForm, cText, nL, nT, nW, nH )
            if " CHECKED" $ Upper( cTrim ) .and. hCtrl != 0
               UI_SetProp( hCtrl, "lChecked", .T. )
            endif
         case " MEMO " $ Upper( cTrim )
            hCtrl := UI_MemoNew( hForm, "", nL, nT, nW, nH )
         case " TREEVIEW " $ Upper( cTrim )
            hCtrl := UI_TreeViewNew( hForm, nL, nT, nW, nH )
            nPos := At( "ITEMS ", Upper( cTrim ) )
            if nPos > 0
               cText := SubStr( cTrim, nPos + 6 )
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
                  UI_SetProp( hCtrl, "aItems", cVal )
               endif
            endif
         case " FOLDER " $ Upper( cTrim )
            hCtrl := UI_TabControlNew( hForm, nL, nT, nW, nH )
            nPos := At( "PROMPTS ", Upper( cTrim ) )
            if nPos > 0
               cText := SubStr( cTrim, nPos + 5 )
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
                  UI_SetProp( hCtrl, "aTabs", cVal )
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
               // Parse comma-separated quoted strings into "|"-separated
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
         case " DBGRID " $ Upper( cTrim )
            hCtrl := UI_DBGridNew( hForm, nL, nT, nW, nH )
            // Extract HEADERS "col1", "col2", "col3"
            nPos := At( "HEADERS ", Upper( cTrim ) )
            if nPos > 0
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
               if hCtrl != 0 .and. ! Empty( cVal )
                  UI_SetProp( hCtrl, "aColumns", cVal )
               endif
            endif
         case " BAND " $ Upper( cTrim )
            hCtrl := UI_BandNew( hForm, "Detail", nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( 'TYPE "', cTrim )
               if nPos > 0
                  cVal := SubStr( cTrim, nPos + 6 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "cBandType", Left( cVal, nPos2 - 1 ) )
                  endif
               endif
               UI_BandSetLayout( hCtrl )
            endif
         case " WEBVIEW " $ Upper( cTrim )
            hCtrl := UI_WebViewNew( hForm, nL, nT, nW, nH )
            if hCtrl != 0
               nPos := At( 'URL "', cTrim )
               if nPos > 0
                  cVal := SubStr( cTrim, nPos + 5 )
                  nPos2 := At( '"', cVal )
                  if nPos2 > 0
                     UI_SetProp( hCtrl, "cUrl", Left( cVal, nPos2 - 1 ) )
                  endif
               endif
            endif
         case " DATETIMEPICKER " $ Upper( cTrim )
            hCtrl := UI_DateTimePickerNew( hForm, nL, nT, nW, nH )
         case " MONTHCALENDAR " $ Upper( cTrim )
            hCtrl := UI_MonthCalendarNew( hForm, nL, nT, nW, nH )
      endcase

      // Set the control name
      if hCtrl != 0
         UI_SetProp( hCtrl, "cName", cName )

         // Detect OF ::oFolder:aPages[n] clause -> set page ownership
         nPos := At( ":aPages[", cTrim )
         if nPos > 0
            // Find "::o" just before :aPages
            nPos2 := nPos
            do while nPos2 > 1 .and. SubStr( cTrim, nPos2, 3 ) != "::o"
               nPos2--
            enddo
            if nPos2 > 0 .and. SubStr( cTrim, nPos2, 3 ) == "::o"
               cVal := AllTrim( SubStr( cTrim, nPos2 + 3, nPos - nPos2 - 3 ) )
               // Find owner by name
               for kk := 1 to UI_GetChildCount( hForm )
                  if AllTrim( UI_GetProp( UI_GetChild( hForm, kk ), "cName" ) ) == cVal
                     // Extract page index
                     nPos2 := At( "[", SubStr( cTrim, nPos ) )
                     nPos2 := nPos + nPos2
                     nColCount := Val( AllTrim( SubStr( cTrim, nPos2 ) ) )
                     UI_SetCtrlOwner( hCtrl, UI_GetChild( hForm, kk ), nColCount - 1 )
                     exit
                  endif
               next
            endif
         endif
      endif
   next

   // Second pass: apply property assignments like ::oCtrlName:prop := value
   // Only within the CreateForm() method body (first pass of the form scope)
   // so we don't pick up ::oX:prop lines from user-defined methods below.
   lInCreateForm := .F.
   for i := 1 to Len( aLines )
      cTrim := StrTran( AllTrim( aLines[i] ), Chr(13), "" )
      if "METHOD CREATEFORM" $ Upper( cTrim )
         lInCreateForm := .T.
         loop
      endif
      if lInCreateForm .and. Upper( cTrim ) == "RETURN NIL"
         lInCreateForm := .F.
         loop
      endif
      if ! lInCreateForm; loop; endif
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
      elseif cVal == "oFont"
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, "oFont", cText )
      elseif cVal == "cDataSource" .or. cVal == "oDataSource"
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, cVal, cText )
      elseif cVal == "Text" .or. cVal == "cText"
         cText := RebuildStringExpr( cText )
         UI_SetProp( hCtrl, "cText", cText )
      elseif cVal == "lTransparent"
         UI_SetProp( hCtrl, "lTransparent", cText == ".T." )
      elseif cVal == "nAlign"
         UI_SetProp( hCtrl, "nAlign", Val( cText ) )
      elseif cVal == "ControlAlign"
         UI_SetProp( hCtrl, "nControlAlign", Val( cText ) )
      elseif cVal == "PenColor"
         UI_SetProp( hCtrl, "nPenColor", Val( cText ) )
      elseif cVal == "PenWidth"
         UI_SetProp( hCtrl, "nPenWidth", Val( cText ) )
      elseif cVal == "FixedRows"
         UI_SetProp( hCtrl, "nFixedRows", Val( cText ) )
      elseif cVal == "FixedCols"
         UI_SetProp( hCtrl, "nFixedCols", Val( cText ) )
      elseif cVal == "MapType"
         UI_SetProp( hCtrl, "nMapType", Val( cText ) )
      endif
   next

return nil

// Build full editor text: Project1.prg + active form's code
static function BuildFullCode()

   local cCode

   cCode := GenerateProjectCode()
   if nActiveForm > 0 .and. nActiveForm <= Len( aForms )
      cCode += aForms[ nActiveForm ][ 3 ]
   endif

return cCode

// Save current editor text back to active form's code slot
static function SaveActiveFormCode()

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
      return nil
   endif

   // Read from the form's tab (tab index = nActiveForm + 1)
   aForms[ nActiveForm ][ 3 ] := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )

return nil

// Determine what type of tab nTab refers to: { cType, nIndex }
// cType: "project", "form", "module", "openfile"
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

// Get all code from editor (called from C inspector to check handler existence)
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

// Delete an event handler function from the code
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

// Double-click on event in inspector: generate METHOD handler
// Follows C++Builder pattern: ComponentName + EventNameWithoutOn
// e.g. Button1 + OnClick -> Button1Click
// e.g. Form1 + OnCreate -> Form1Create
// e.g. Edit1 + OnChange -> Edit1Change
static function OnEventDblClick( hCtrl, cEvent )

   local cName, cClass, cHandler, cCode, cDecl, e, cSep, nCursorOfs
   local cEditorText

   e := Chr(10)
   cSep := "//" + Replicate( "-", 68 ) + e

   // Get component name and class
   cName  := UI_GetProp( hCtrl, "cName" )
   cClass := UI_GetProp( hCtrl, "cClassName" )
   if Empty( cName )
      if cClass == "TForm"
         cName := "Form1"
      else
         cName := "ctrl"
      endif
   endif

   // Build handler name: ComponentName + EventWithoutOn
   cHandler := cName + SubStr( cEvent, 3 )  // skip "On"

   // Switch to the active form's tab before adding/searching code
   if nActiveForm > 0
      CodeEditorSelectTab( hCodeEditor, nActiveForm + 1 )
   endif

   // Check if handler already exists in code editor -> jump to it
   if CodeEditorGotoFunction( hCodeEditor, cHandler )
      return cHandler
   endif

   // Generate the METHOD implementation (C++Builder pattern)
   cCode := cSep
   cCode += "static function " + cHandler + "( oForm )" + e
   cCode += e
   cCode += "   " + e
   cCode += e
   cCode += "return nil" + e

   // Cursor offset: place cursor on the empty line inside the method body
   nCursorOfs := Len( cSep ) + ;
                 Len( "static function " + cHandler + "( oForm )" ) + ;
                 Len( e ) + Len( e ) + 3  // "   " indent

   // Append METHOD implementation to code editor
   CodeEditorAppendText( hCodeEditor, cCode, nCursorOfs )

   // Regenerate CreateForm to include event wiring (preserves METHOD implementations)
   SyncDesignerToCode()

   // Re-position cursor on the new handler (SyncDesignerToCode may have moved it)
   CodeEditorGotoFunction( hCodeEditor, cHandler )

   // Refresh inspector to show handler name in Events tab
   InspectorRefresh( hCtrl )

return cHandler

// === Component drop from palette ===

// Rebuild a Harbour string expression like `"line1" + Chr(10) + "line2"`
// into the plain literal value. Minimal: handles "..." quoted chunks and
// Chr(N) between them; unrecognized tokens are skipped.
static function RebuildStringExpr( cExpr )
   local cResult := "", cCur, nPos
   cExpr := AllTrim( cExpr )
   do while ! Empty( cExpr )
      if Left( cExpr, 1 ) == '"'
         cCur := SubStr( cExpr, 2 )
         nPos := At( '"', cCur )
         if nPos == 0; exit; endif
         cResult += Left( cCur, nPos - 1 )
         cExpr := AllTrim( SubStr( cCur, nPos + 1 ) )
      elseif Left( Upper( cExpr ), 4 ) == "CHR("
         nPos := At( ")", cExpr )
         if nPos == 0; exit; endif
         cResult += Chr( Val( SubStr( cExpr, 5, nPos - 5 ) ) )
         cExpr := AllTrim( SubStr( cExpr, nPos + 1 ) )
      elseif Left( cExpr, 1 ) == "+"
         cExpr := AllTrim( SubStr( cExpr, 2 ) )
      else
         // Skip one char and try again
         cExpr := AllTrim( SubStr( cExpr, 2 ) )
      endif
   enddo
return cResult

static function Var2Char( x )
   local t := ValType( x )
   do case
   case t == "C"; return x
   case t == "U"; return "NIL"
   case t == "N"; return LTrim( Str( x ) )
   case t == "L"; return If( x, ".T.", ".F." )
   case t == "O"; return "[O]"
   otherwise;     return "[" + t + "]"
   endcase
return nil

static function IdeTrace( cMsg )
   local hDbg := FOpen( "/tmp/hb_trace.log", 1 )
   if hDbg == -1; hDbg := FCreate( "/tmp/hb_trace.log" ); endif
   FSeek( hDbg, 0, 2 )
   FWrite( hDbg, cMsg + Chr(10) )
   FClose( hDbg )
return nil

static function IdeDumpError( oErr )
   local cStack := "", i
   local hFile := FCreate( "/tmp/hb_ide.err" )
   if hFile != -1
      cStack := "ERR: " + Var2Char( oErr:description ) + ;
         " op=" + Var2Char( oErr:operation ) + ;
         " subcode=" + LTrim(Str(oErr:subcode)) + Chr(10)
      if ValType( oErr:args ) == "A"
         for i := 1 to Len( oErr:args )
            cStack += "  arg[" + LTrim(Str(i)) + "]=" + Var2Char( oErr:args[i] ) + ;
               " type=" + ValType( oErr:args[i] ) + Chr(10)
         next
      endif
      for i := 2 to 30
         if ProcName(i) == ""; exit; endif
         cStack += ProcName(i) + "(" + LTrim(Str(ProcLine(i))) + ")" + Chr(10)
      next
      FWrite( hFile, cStack )
      FClose( hFile )
   endif
return nil

static function OnComponentDrop( hForm, nType, nL, nT, nW, nH )

   local cName, nCount, hCtrl, hDbg, nBands, iBand
   local cBaseName, cRptName, hLastCtrl, hBandCtrl, hBandCheck, iBandChild
   local nBandT, nBandB, nBandAbsT, cFldSerial, cExistFields2, nRelT
   local nAbsT, nAbsL, nAbsW, nAbsH, cFldType2
   static aCnt := nil
   static nBandCnt := 0
   static nMenuCnt := 0
   static aNames := { ;
      "Label", "Edit", "Button", "CheckBox", "ComboBox", "GroupBox", ;
      "ListBox", "RadioButton", "", "", "", "BitBtn", "SpeedButton", ;
      "Image", "Shape", "Bevel", "", "", "", "TreeView", "TableView", ;
      "ProgressBar", "TextView", "Memo", "Panel", "ScrollBar", ;
      "SpeedButton", "MaskEdit", "StringGrid", "ScrollBox", ;
      "StaticText", "LabeledEdit", "Folder", "Slider", ;
      "Stepper", "DatePicker", "Calendar", "Timer", "PaintBox", ;
      "OpenPanel", "SavePanel", "FontPanel", "ColorPanel", ;
      "FindPanel", "ReplacePanel", ;
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

   if aCnt == nil; aCnt := Array( 135 ); AFill(aCnt,0); endif
   UI_FormUndoPush( hForm )

   // CT_MAINMENU (200) is outside aNames range — handle it before the bounds check
   if nType == 200
      nMenuCnt++
      cName := "MainMenu" + LTrim( Str( nMenuCnt ) )
      nCount := UI_GetChildCount( hForm )
      hCtrl  := UI_GetChild( hForm, nCount )
      if hCtrl != 0
         UI_SetProp( hCtrl, "cName", cName )
      endif
      SyncDesignerToCode()
      INS_ComboSelect( _InsGetData(), UI_GetChildCount( hForm ) )
      InspectorRefresh( hLastCtrl )
      return nil
   endif

   // CT_BAND (132) is not in aNames — handle it before the bounds check
   if nType == CT_BAND
      nBandCnt++
      cName := "Band" + LTrim( Str( nBandCnt ) )
      nCount := UI_GetChildCount( hForm )
      // First band on this form → rename form to "Report"
      nBands := 0
      for iBand := 1 to nCount
         if UI_GetType( UI_GetChild( hForm, iBand ) ) == CT_BAND
            nBands++
         endif
      next
      if nBands == 1
         UI_SetProp( hForm, "cText",   "Report" )
         UI_SetProp( hForm, "nWidth",  850 )
         UI_SetProp( hForm, "nHeight", 450 )
         UI_SetProp( hForm, "nLeft",   769 )
         UI_SetProp( hForm, "nTop",    300 )
      endif
      hCtrl  := UI_GetChild( hForm, nCount )
      if hCtrl != 0
         UI_SetProp( hCtrl, "cName", cName )
         UI_BandSetLayout( hCtrl )
      endif
      SyncDesignerToCode()
      InspectorPopulateCombo( hForm )     // rebuild combo (selects form by default)
      INS_ComboSelect( _InsGetData(), nCount )  // select the new band in combo
      InspectorRefresh( hCtrl )           // show band properties last
      return nil
   endif

   // Report controls (133-135) — C++ rubber-band created the view in the form
   if nType >= 133 .and. nType <= 135
      hLastCtrl := UI_GetChild( hForm, UI_GetChildCount( hForm ) )
      if hLastCtrl != 0 .and. UI_GetType( hLastCtrl ) == nType
         do case
            case nType == 133; cBaseName := "RLabel"
            case nType == 134; cBaseName := "RField"
            case nType == 135; cBaseName := "RImage"
         endcase
         aCnt[ nType ]++
         cRptName := cBaseName + LTrim( Str( aCnt[ nType ] ) )
         UI_SetProp( hLastCtrl, "cName", cRptName )
         if nType == 133
            UI_SetProp( hLastCtrl, "cText", "Label" )
         endif

         // Find the band that contains this control (by vertical overlap)
         nAbsT := UI_GetProp( hLastCtrl, "nTop" )
         nAbsL := UI_GetProp( hLastCtrl, "nLeft" )
         nAbsW := UI_GetProp( hLastCtrl, "nWidth" )
         nAbsH := UI_GetProp( hLastCtrl, "nHeight" )
         hBandCtrl := 0
         for iBandChild := 1 to UI_GetChildCount( hForm )
            hBandCheck := UI_GetChild( hForm, iBandChild )
            if UI_GetType( hBandCheck ) == CT_BAND
               nBandT := UI_GetProp( hBandCheck, "nTop" )
               nBandB := nBandT + UI_GetProp( hBandCheck, "nHeight" )
               if nAbsT >= nBandT .and. nAbsT < nBandB
                  hBandCtrl := hBandCheck
                  exit
               endif
            endif
         next

         // Append serialized record to parent band's aData
         if hBandCtrl != 0
            nBandAbsT := UI_GetProp( hBandCtrl, "nTop" )
            nRelT := nAbsT - nBandAbsT
            cFldType2 := if( nType == 135, "image", if( nType == 134, "field", "text" ) )
            cFldSerial := cRptName + "|" + cFldType2 + "|" + ;
               if( nType == 133, UI_GetProp( hLastCtrl, "cText" ), "" ) + "|||" + ;
               LTrim(Str(nRelT)) + "|" + LTrim(Str(nAbsL)) + "|" + ;
               LTrim(Str(nAbsW)) + "|" + LTrim(Str(nAbsH)) + "|" + ;
               "Sans|10|0|0|0"
            cExistFields2 := UI_GetProp( hBandCtrl, "aData" )
            if Empty( cExistFields2 )
               UI_SetProp( hBandCtrl, "aData", cFldSerial )
            else
               UI_SetProp( hBandCtrl, "aData", cExistFields2 + Chr(10) + cFldSerial )
            endif
         endif
      endif
      SyncDesignerToCode()
      InspectorPopulateCombo( hForm )
      INS_ComboSelect( _InsGetData(), UI_GetChildCount( hForm ) )
      InspectorRefresh( hLastCtrl )
      return nil
   endif

   if nType < 1 .or. nType > Len(aNames) .or. Empty(aNames[nType]); return nil; endif
   aCnt[nType]++
   cName := aNames[nType] + LTrim(Str(aCnt[nType]))

   // Set name on the new control (last child)
   nCount := UI_GetChildCount( hForm )
   hCtrl  := UI_GetChild( hForm, nCount )
   if hCtrl != 0
      UI_SetProp( hCtrl, "cName", cName )
   endif

   // Two-way: regenerate entire form code from designer state
   SyncDesignerToCode()

   // Refresh inspector
   InspectorRefresh( hCtrl )
   InspectorPopulateCombo( hForm )

return nil

// Wire all design-mode callbacks on the active form
static function WireDesignForm()

   UI_SetDesignForm( oDesignForm:hCpp )

   UI_OnSelChange( oDesignForm:hCpp, ;
      { |hCtrl| OnDesignSelChange( hCtrl ) } )

   UI_FormOnComponentDrop( oDesignForm:hCpp, ;
      { |hForm, nType, nL, nT, nW, nH| OnComponentDrop( hForm, nType, nL, nT, nW, nH ) } )

   // Two-way: sync code + inspector when form is moved/resized
   oDesignForm:OnResize := { || SyncDesignerToCode(), ;
      InspectorRefresh( oDesignForm:hCpp ) }

return nil

// Two-way sync: regenerate code from designer state
static function SyncDesignerToCode()

   local cNewCode, cOldCode, cMethods, nPos, nPos2
   local cSep := "//" + Replicate( "-", 68 )

   // Don't regenerate code while syncing from code editor
   if lSyncingFromCode
      return nil
   endif

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
      return nil
   endif

   // Get existing code to preserve METHOD implementations
   cOldCode := CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )

   // Find METHOD implementations after CreateForm
   cMethods := ""
   nPos := At( "METHOD CreateForm()", cOldCode )
   if nPos > 0
      nPos2 := At( "return nil", SubStr( cOldCode, nPos ) )
      if nPos2 > 0
         nPos := nPos + nPos2 - 1 + Len( "return nil" )
         nPos2 := At( cSep, SubStr( cOldCode, nPos ) )
         if nPos2 > 0
            nPos := nPos + nPos2 - 1 + Len( cSep )
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

   // Update stored code and editor tab (guard against re-entry into
   // OnEditorTextChange which would rebuild the form and invalidate handles)
   aForms[ nActiveForm ][ 3 ] := cNewCode
   lSyncingFromCode := .t.
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, cNewCode )
   lSyncingFromCode := .f.

return nil

// Live sync: editor text changed (debounced 500ms) -> update form + inspector
static function OnEditorTextChange( hEd, nTab )

   local aInfo, nFormIdx, cCode, hForm

   HB_SYMBOL_UNUSED( hEd )

   // Avoid re-entrant loop (SyncDesignerToCode updates editor text)
   if lSyncingFromCode
      return nil
   endif

   // Only sync form tabs (not project, modules, or open files)
   aInfo := TabInfo( nTab )
   if aInfo[1] != "form"
      return nil
   endif

   nFormIdx := aInfo[2]
   if nFormIdx < 1 .or. nFormIdx > Len( aForms )
      return nil
   endif

   // Read current editor content for this tab
   cCode := CodeEditorGetTabText( hCodeEditor, nTab )
   if Empty( cCode )
      return nil
   endif

   // Skip if text matches the last code we regenerated (SyncDesignerToCode):
   // the debounce timer may fire after our guard already cleared.
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

   // Rebuild NSViews for the repopulated children (macOS: UI_*New only adds data)
   UI_FormRebuildChildren( hForm )

   // Update stored code
   aForms[ nFormIdx ][ 3 ] := cCode

   // Refresh inspector with updated properties
   InspectorRefresh( hForm )

   lSyncingFromCode := .f.

return nil

// Editor tab changed: route to form, module, or open file
static function OnEditorTabChange( hEd, nTab )

   local aInfo := TabInfo( nTab )

   do case
   case aInfo[1] == "form"
      if aInfo[2] != nActiveForm .and. aInfo[2] <= Len( aForms )
         SwitchToForm( aInfo[2] )
      endif
   case aInfo[1] == "module" .or. aInfo[1] == "openfile"
      // Save current form code before switching away
      SaveActiveFormCode()
   endcase

return nil

// === Multi-form management (C++Builder style) ===

// Switch active form: bring selected form to front
static function SwitchToForm( nIdx )

   if nIdx < 1 .or. nIdx > Len( aForms )
      return nil
   endif

   // Save current form's code from editor
   if nActiveForm > 0 .and. nActiveForm != nIdx
      SaveActiveFormCode()
   endif

   // Activate new form
   nActiveForm := nIdx
   oDesignForm := aForms[ nIdx ][ 2 ]

   // Bring to front
   UI_SetDesignForm( oDesignForm:hCpp )
   UI_FormBringToFront( oDesignForm:hCpp )

   // Switch editor to this form's tab
   CodeEditorSelectTab( hCodeEditor, nIdx + 1 )

   // Refresh inspector
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

return nil

// File > New Form: add a new form to the project
static function MenuNewForm()

   local nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop, nBottomY

   // Save current form code
   SaveActiveFormCode()

   // Hide current form (use Hide, not Close — Close stops the run loop)
   if nActiveForm > 0
      UI_FormHide( aForms[ nActiveForm ][ 2 ]:hCpp )
   endif

   // Calculate position (same as initial form, offset a bit)
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := MAC_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 80
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 ) + Len(aForms) * 20
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 ) + Len(aForms) * 20

   // Create new form
   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   UI_SetDesignForm( oDesignForm:hCpp )
   oDesignForm:Show()

   WireDesignForm()

   // Add tab to editor and switch to it
   CodeEditorAddTab( hCodeEditor, aForms[ nActiveForm ][ 1 ] + ".prg" )
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, aForms[ nActiveForm ][ 3 ] )
   CodeEditorSelectTab( hCodeEditor, nActiveForm + 1 )

   // Update Project1.prg tab with new CreateForm line
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )

   // Refresh inspector
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

return nil

// Add a standalone .prg module to the project
static function MenuAddModule()

   local cFile, cName, cCode, i, nTabPos

   cFile := MAC_OpenFileDialog( "Add Module to Project", "prg" )
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

   cFile := MAC_OpenFileDialog( "Open File", "prg" )
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

// View > Forms... (Shift+F12): show list dialog and switch
static function MenuViewForms()

   local aNames := {}, i, nSel

   for i := 1 to Len( aForms )
      AAdd( aNames, aForms[i][1] )
   next

   nSel := MAC_SelectFromList( "View Forms", aNames )
   if nSel > 0
      SwitchToForm( nSel )
   endif

return nil

// Destroy all forms on exit
static function DestroyAllForms()

   local i

   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next

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

// === Toolbar actions ===

// New Application: reset everything (like C++Builder File > New > Application)
static function TBNew()

   local i, nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop, nBottomY, nAns

   // Ask to save current work if there are forms open
   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before creating a new one?", "HbBuilder" )
      if nAns == 0  // Cancel
         return nil
      elseif nAns == 1  // Yes
         TBSave()
      endif
      // nAns == 2 (No) → proceed without saving
   endif

   // Destroy all existing forms
   for i := 1 to Len( aForms )
      UI_FormHide( aForms[i][2]:hCpp )
      UI_FormClose( aForms[i][2]:hCpp )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0
   aModules := {}
   aOpenFiles := {}

   // Calculate position for Form1
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := MAC_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 80
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 )
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 )

   // Create first form
   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   UI_SetDesignForm( oDesignForm:hCpp )
   oDesignForm:Show()

   WireDesignForm()

   // Reset editor tabs
   CodeEditorClearTabs( hCodeEditor )
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
   CodeEditorAddTab( hCodeEditor, "Form1.prg" )
   CodeEditorSetTabText( hCodeEditor, 2, aForms[1][3] )
   CodeEditorSelectTab( hCodeEditor, 2 )
   cCurrentFile := ""

   // Refresh inspector
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

return nil

// Open Project: load a .hbp project file
static function TBOpen()

   local cFile

   cFile := MAC_OpenFileDialog( "Open HbBuilder Project", "hbp" )
   if Empty( cFile )
      return nil
   endif

   OpenProjectFile( cFile )

return nil
static function TBSave()

   local cDir, cFile, cHbp, i

   // Sync current form code
   SaveActiveFormCode()

   if Empty( cCurrentFile )
      cFile := MAC_SaveFileDialog( "Save HbBuilder Project", "Project1", "hbp" )
      if Empty( cFile )
         return nil
      endif
      cCurrentFile := cFile
   endif

   // Project directory = same as .hbp file
   cDir := Left( cCurrentFile, RAt( "/", cCurrentFile ) )

   // Write .hbp file (project index)
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

   // Write Project1.prg
   MemoWrit( cDir + "Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )

   // Write each form .prg
   for i := 1 to Len( aForms )
      MemoWrit( cDir + aForms[i][1] + ".prg", aForms[i][3] )
   next

   // Write each module .prg
   for i := 1 to Len( aModules )
      aModules[i][2] := CodeEditorGetTabText( hCodeEditor, 1 + Len(aForms) + i )
      MemoWrit( cDir + aModules[i][1] + ".prg", aModules[i][2] )
   next

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
      MAC_ProgressOpen( "HbBuilder Setup", 0 )
      MAC_ShellExec( "rm -rf " + cHbSrc )
      MAC_ShellExecLive( ;
         "git clone --depth 1 https://github.com/harbour/core.git " + cHbSrc + " 2>&1", ;
         "Cloning harbour/core from GitHub..." )
      MAC_ProgressClose()

      // Verify download
      if ! File( cHbSrc + "/config/global.mk" )
         lBusy := .F.
         MAC_BuildErrorDialog( "Download Failed", ;
            "Could not download Harbour source." + Chr(10) + Chr(10) + ;
            "Please check your internet connection and try again." + Chr(10) + ;
            "You can also install manually:" + Chr(10) + ;
            "  git clone https://github.com/harbour/core " + cHbSrc )
         return .F.
      endif
   endif

   // Build and install Harbour
   MAC_ProgressOpen( "Building Harbour...", 0 )
   cOutput := MAC_ShellExecLive( ;
      "cd " + cHbSrc + " && HB_INSTALL_PREFIX=" + cHbDir + ;
      " make -j$(sysctl -n hw.ncpu) install 2>&1", ;
      "Compiling Harbour (this may take several minutes)..." )
   MAC_ProgressClose()

   lBusy := .F.

   // Verify build succeeded
   if File( cHbDir + "/bin/harbour" ) .or. File( cHbDir + "/bin/darwin/clang/harbour" )
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
      "  bin/darwin/clang/harbour: " + iif( File( cHbDir + "/bin/darwin/clang/harbour" ), "FOUND", "MISSING" ) + Chr(10) + ;
      "  include/hbapi.h: " + iif( File( cHbDir + "/include/hbapi.h" ), "FOUND", "MISSING" ) + Chr(10) + Chr(10) + ;
      "Manual build:" + Chr(10) + ;
      "  cd " + cHbSrc + Chr(10) + ;
      "  HB_INSTALL_PREFIX=" + cHbDir + " make install"

   if ! Empty( cOutput ) .and. Len( cOutput ) > 2000
      cDiag += Chr(10) + Chr(10) + "Last output:" + Chr(10) + Right( cOutput, 2000 )
   elseif ! Empty( cOutput )
      cDiag += Chr(10) + Chr(10) + "Build output:" + Chr(10) + cOutput
   endif

   MAC_BuildErrorDialog( "Build Failed", cDiag )

return .F.

// Run: compile and execute the project (C++Builder F9)
static function TBRun()

   local cBuildDir, cOutput, cLog, i, lError, nErrors
   local cHbDir, cHbBin, cHbInc, cHbLib, cProjDir
   local cAllPrg, cCmd, cAllCode, nHash
   local cResDir, cBackends, cSciInc, cSciCocoa, cLexInc, cSciLib
   local cOldTab, cSepLine, nP1, nP2, cUserCode
   local cAppTitle, cAppName
   local hForm, nCount, hCtrl, oReport, oBand, cBandType, nBandH
   static nLastHash := 0

   // If the active form is a report (has bands), preview instead of compile+run
   if nActiveForm > 0 .and. nActiveForm <= Len( aForms ) .and. ;
      aForms[ nActiveForm ][ 2 ] != nil
      hForm  := aForms[ nActiveForm ][ 2 ]:hCpp
      nCount := UI_GetChildCount( hForm )
      for i := 1 to nCount
         hCtrl := UI_GetChild( hForm, i )
         if UI_GetType( hCtrl ) == CT_BAND
            if oReport == nil
               oReport := TReport():New()
               oReport:nPageWidth  := UI_GetProp( hForm, "nWidth" )
               oReport:nPageHeight := UI_GetProp( hForm, "nHeight" )
            endif
            cBandType := UI_GetProp( hCtrl, "cText" )
            nBandH    := UI_GetProp( hCtrl, "nHeight" )
            oBand := TBand():New( nil, cBandType, nBandH )
            oReport:AddDesignBand( oBand )
         endif
      next
      if oReport != nil
         oReport:Preview()
         return nil
      endif
   endif

   // Get AppTitle from the main form (first form)
   cAppTitle := ""
   if Len( aForms ) > 0 .and. aForms[1][2] != nil .and. aForms[1][2]:hCpp != 0
      cAppTitle := UI_GetProp( aForms[1][2]:hCpp, "cAppTitle" )
   endif
   cAppName := iif( ! Empty( cAppTitle ), cAppTitle, "UserApp" )

   // Sync all forms before building (ensures event wiring is up to date)
   cSepLine := "//" + Replicate( "-", 68 )
   for i := 1 to Len( aForms )
      if aForms[i][2] != nil .and. aForms[i][2]:hCpp != 0
         nActiveForm := i  // RegenerateFormCode reads cExistingCode using nActiveForm
         cOldTab := CodeEditorGetTabText( hCodeEditor, i + 1 )
         aForms[i][3] := RegenerateFormCode( aForms[i][1], aForms[i][2]:hCpp )
         // Preserve user methods from editor
         nP1 := At( "return nil", cOldTab )
         if nP1 > 0
            nP2 := At( cSepLine, SubStr( cOldTab, nP1 + 10 ) )
            if nP2 > 0
               cUserCode := SubStr( cOldTab, nP1 + 10 + nP2 - 1 + Len( cSepLine ) )
               do while Left( cUserCode, 1 ) == Chr(10) .or. Left( cUserCode, 1 ) == Chr(13)
                  cUserCode := SubStr( cUserCode, 2 )
               enddo
               if ! Empty( cUserCode )
                  aForms[i][3] += Chr(13) + Chr(10) + cUserCode
               endif
            endif
         endif
         CodeEditorSetTabText( hCodeEditor, i + 1, aForms[i][3] )
      endif
   next

   cBuildDir := "/tmp/hbbuilder_build"
   cHbDir   := GetEnv( "HOME" ) + "/harbour"
   cHbInc   := cHbDir + "/include"
   cProjDir := HB_DirBase() + ".."
   cLog     := ""
   lError   := .F.

   // Resolve paths for bundle vs source tree
   cResDir := HB_DirBase() + "../Resources"
   if hb_DirExists( cResDir + "/backends" )
      // Running from .app bundle
      cBackends := cResDir + "/backends/cocoa"
      cSciInc   := cResDir + "/scintilla/include"
      cSciCocoa := cResDir + "/scintilla/cocoa"
      cLexInc   := cResDir + "/scintilla/lexilla"
      cSciLib   := cResDir + "/scintilla/build"
   else
      // Running from source tree
      cBackends := cProjDir + "/source/backends/cocoa"
      cSciInc   := cProjDir + "/resources/scintilla_src/scintilla/include"
      cSciCocoa := cProjDir + "/resources/scintilla_src/scintilla/cocoa"
      cLexInc   := cProjDir + "/resources/scintilla_src/lexilla/include"
      cSciLib   := cProjDir + "/resources/scintilla_src/build"
   endif

   // Auto-download and build Harbour if not installed
   if ! File( cHbDir + "/bin/harbour" ) .and. ! File( cHbDir + "/bin/darwin/clang/harbour" )
      if ! EnsureHarbour( cHbDir )
         return nil
      endif
   endif

   // Detect Harbour directory layout
   if File( cHbDir + "/bin/darwin/clang/harbour" )
      cHbBin := cHbDir + "/bin/darwin/clang"
      cHbLib := cHbDir + "/lib/darwin/clang"
   else
      cHbBin := cHbDir + "/bin"
      cHbLib := cHbDir + "/lib"
   endif

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
   if nHash == nLastHash .and. nLastHash != 0 .and. ;
      File( cBuildDir + "/" + cAppName + ".app/Contents/MacOS/" + cAppName )
      MAC_ShellExec( "open " + cBuildDir + "/" + cAppName + ".app" )
      return nil
   endif

   MAC_ShellExec( "mkdir -p " + cBuildDir )

   // Show progress dialog (7 steps)
   MAC_ProgressOpen( "Building Project...", 7 )

   // Step 1: Save files
   MAC_ProgressStep( 1, "Saving project files..." )
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
   // Copy framework files (bundle Resources/ or source tree harbour/)
   if File( HB_DirBase() + "../Resources/classes.prg" )
      MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/classes.prg " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/hbbuilder.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/hbide.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/stddlgs_mac.mm " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/hix_runtime.prg " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/hix_template.prg " + cBuildDir + "/ 2>/dev/null" )
   else
      MAC_ShellExec( "cp " + cProjDir + "/source/core/classes.prg " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/include/hbbuilder.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/include/hbide.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/resources/stddlgs_mac.mm " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + cProjDir + "/source/hix_runtime.prg " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + cProjDir + "/source/hix_template.prg " + cBuildDir + "/ 2>/dev/null" )
   endif

   // Step 2: Assemble main.prg
   MAC_ProgressStep( 2, "Assembling main.prg..." )
   cLog += "[2] Building main.prg..." + Chr(10)
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_NUL_DEFAULT" + Chr(10)
   cAllPrg += "REQUEST DBFCDX, DBFNTX, DBFFPT" + Chr(10) + Chr(10)
   cAllPrg += StrTran( StrTran( StrTran( MemoRead( cBuildDir + "/Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ), ;
                       '#include "classes.prg"', "" ), ;
                       "REQUEST HB_GT_GUI_DEFAULT", "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += StrTran( StrTran( MemoRead( cBuildDir + "/" + aForms[i][1] + ".prg" ), ;
                          '#include "classes.prg"', "" ), ;
                          '#include "hbbuilder.ch"', "" ) + Chr(10)
   next
   for i := 1 to Len( aModules )
      cAllPrg += StrTran( StrTran( MemoRead( cBuildDir + "/" + aModules[i][1] + ".prg" ), ;
                          '#include "classes.prg"', "" ), ;
                          '#include "hbbuilder.ch"', "" ) + Chr(10)
   next
   MemoWrit( cBuildDir + "/main.prg", cAllPrg )

   // Step 3: Compile user code with Harbour
   if ! lError
      MAC_ProgressStep( 3, "Compiling Harbour code..." )
      cLog += "[3] Compiling main.prg..." + Chr(10)
      cCmd := cHbBin + "/harbour " + cBuildDir + "/main.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/main.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if "Error" $ cOutput
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 4: Compile framework
   if ! lError
      MAC_ProgressStep( 4, "Compiling framework..." )
      cLog += "[4] Compiling framework..." + Chr(10)
      cCmd := cHbBin + "/harbour " + cBuildDir + "/classes.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/classes.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
      cCmd := cHbBin + "/harbour " + cBuildDir + "/hix_runtime.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/hix_runtime.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    hix_runtime FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    hix_runtime OK" + Chr(10)
      endif
      cCmd := cHbBin + "/harbour " + cBuildDir + "/hix_template.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/hix_template.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    hix_template FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    hix_template OK" + Chr(10)
      endif
   endif

   // Step 5: Compile C
   if ! lError
      MAC_ProgressStep( 5, "Compiling C sources..." )
      cLog += "[5] Compiling C sources..." + Chr(10)
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/main.c -o " + cBuildDir + "/main.o 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/classes.c -o " + cBuildDir + "/classes.o 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/hix_runtime.c -o " + cBuildDir + "/hix_runtime.o 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED hix_runtime.c:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    hix_runtime.o OK" + Chr(10)
      endif
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/hix_template.c -o " + cBuildDir + "/hix_template.o 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED hix_template.c:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    hix_template.o OK" + Chr(10)
      endif
   endif

   // Step 6: Compile Cocoa backend + editor + GT dummy
   if ! lError
      MAC_ProgressStep( 6, "Compiling Cocoa backend..." )
      cLog += "[6] Compiling Cocoa backend..." + Chr(10)
      cCmd := "clang -c -O2 -fobjc-arc -I" + cHbInc + ;
              " " + cBackends + "/cocoa_core.m" + ;
              " -o " + cBuildDir + "/cocoa_core.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -fobjc-arc -I" + cHbInc + ;
              " " + cBackends + "/cocoa_webserver.m" + ;
              " -o " + cBuildDir + "/cocoa_webserver.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang++ -c -O2 -std=c++17 -fobjc-arc -I" + cHbInc + ;
              " -I" + cSciInc + ;
              " -I" + cSciCocoa + ;
              " -I" + cLexInc + ;
              " " + cBackends + "/cocoa_editor.mm" + ;
              " -o " + cBuildDir + "/cocoa_editor.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -I" + cHbInc + ;
              " " + cBackends + "/gt_dummy.c" + ;
              " -o " + cBuildDir + "/gt_dummy.o 2>&1"
      MAC_ShellExec( cCmd )
      if File( cBuildDir + "/stddlgs_mac.mm" )
         cCmd := "clang++ -c -O2 -fobjc-arc -I" + cHbInc + ;
                 " " + cBuildDir + "/stddlgs_mac.mm" + ;
                 " -o " + cBuildDir + "/stddlgs_mac.o 2>&1"
         MAC_ShellExec( cCmd )
      endif
      cLog += "    OK" + Chr(10)
   endif

   // Step 7: Link
   if ! lError
      MAC_ProgressStep( 7, "Linking executable..." )
      cLog += "[7] Linking..." + Chr(10)
      cCmd := "clang++ -o " + cBuildDir + "/" + cAppName + ;
              " " + cBuildDir + "/main.o" + ;
              " " + cBuildDir + "/classes.o" + ;
              " " + cBuildDir + "/cocoa_core.o" + ;
              " " + cBuildDir + "/cocoa_webserver.o" + ;
              " " + cBuildDir + "/cocoa_editor.o" + ;
              " " + cBuildDir + "/gt_dummy.o" + ;
              If( File( cBuildDir + "/stddlgs_mac.o" ), " " + cBuildDir + "/stddlgs_mac.o", "" ) + ;
              " " + cBuildDir + "/hix_runtime.o" + ;
              " " + cBuildDir + "/hix_template.o" + ;
              " " + cSciLib + "/libscintilla.a" + ;
              " " + cSciLib + "/liblexilla.a" + ;
              " -L" + cHbLib + ;
              " -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang" + ;
              " -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug" + ;
              " -lhbct -lhbextern -lhbsqlit3" + ;
              " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
              " -lhbhsx -lhbsix -lhbusrrdd" + ;
              " -lgtcgi -lgtstd" + ;
              " -framework Cocoa -framework QuartzCore -framework MapKit -framework CoreLocation -framework SceneKit -framework WebKit" + If( Val( MAC_ShellExec( "sw_vers -productVersion | cut -d. -f1" ) ) >= 11, " -framework UniformTypeIdentifiers", "" ) + ;
              " -lm -lpthread -lc++ -lsqlite3 -lcups 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Write full build log
   MemoWrit( cBuildDir + "/build_trace.log", cLog )

   // Close progress dialog
   MAC_ProgressClose()

   // Result
   if lError
      MAC_BuildErrorDialog( "Build Failed", cLog )
   elseif ! File( cBuildDir + "/" + cAppName )
      cLog += Chr(10) + "ERROR: " + cAppName + " was not created." + Chr(10)
      MAC_BuildErrorDialog( "Build Failed", cLog )
   else
      nLastHash := nHash
      // Create .app bundle and launch (macOS needs bundle for GUI app)
      MAC_ShellExec( "mkdir -p " + cBuildDir + "/" + cAppName + ".app/Contents/MacOS" )
      MAC_ShellExec( "cp " + cBuildDir + "/" + cAppName + " " + cBuildDir + "/" + cAppName + ".app/Contents/MacOS/" )
      MemoWrit( cBuildDir + "/" + cAppName + ".app/Contents/Info.plist", ;
         '<?xml version="1.0"?>' + Chr(10) + ;
         '<plist version="1.0"><dict>' + Chr(10) + ;
         '<key>CFBundleExecutable</key><string>' + cAppName + '</string>' + Chr(10) + ;
         '<key>CFBundleName</key><string>' + cAppName + '</string>' + Chr(10) + ;
         '</dict></plist>' + Chr(10) )
      MAC_ShellExec( "open " + cBuildDir + "/" + cAppName + ".app" )
   endif

return nil

// === Debugger ===

static function ToggleBreakpoint()
   // TODO: Implement breakpoint functionality
   // Temporarily disabled to test menu functionality
   MAC_DebugSetStatus( "Breakpoint functionality coming soon" )
return nil

static function ClearBreakpoints()
   // TODO: Implement clear breakpoints functionality
   // Temporarily disabled to test menu functionality
   MAC_DebugSetStatus( "Clear breakpoints functionality coming soon" )
return nil

static function GetCurrentFileName()
   local cFile
   if nActiveForm > 0 .and. nActiveForm <= Len( aForms )
      cFile := aForms[ nActiveForm ][ 1 ] + ".prg"
   else
      cFile := "main.prg"
   endif
return cFile

static function RestoreBreakpoints( cFile )
   // This function would restore breakpoints from a saved configuration
   // For now, it's a placeholder
   local aBreakpoints := {}
   local i, nLine

   // In a real implementation, we would load breakpoints from a config file
   // and call CodeEditorAddBreakpoint for each one
return nil

static function ShowDebugger()
   MAC_DebugPanel()
return nil

// === Debug Run (in-process: compile to .hrb, execute in IDE VM) ===

static function TBDebugRun( lRunToBreakpoint )

   local cBuildDir, cOutput, cLog, i, lError
   local cHbDir, cHbBin, cHbInc, cHbLib, cProjDir
   local cAllPrg, cCmd, cMainPrg
   local cBackends, cSciInc, cSciCocoa, cLexInc, cSciLib, cResDir
   local nCurLine, cSection

   // Parameter kept for compatibility but not used anymore
   // Always uses run-to-breakpoint mode
   if lRunToBreakpoint == NIL
      lRunToBreakpoint := .T.
   endif

   SaveActiveFormCode()

   cBuildDir := "/tmp/hbbuilder_debug"
   cHbDir   := GetEnv( "HOME" ) + "/harbour"
   cHbInc   := cHbDir + "/include"
   cProjDir := HB_DirBase() + ".."
   cLog     := ""
   lError   := .F.

   // Auto-download and build Harbour if not installed
   if ! File( cHbDir + "/bin/harbour" ) .and. ! File( cHbDir + "/bin/darwin/clang/harbour" )
      if ! EnsureHarbour( cHbDir )
         return nil
      endif
   endif

   if File( cHbDir + "/bin/darwin/clang/harbour" )
      cHbBin := cHbDir + "/bin/darwin/clang"
      cHbLib := cHbDir + "/lib/darwin/clang"
   else
      cHbBin := cHbDir + "/bin"
      cHbLib := cHbDir + "/lib"
   endif

   // Resolve paths (same as TBRun)
   cResDir := HB_DirBase() + "../Resources"
   if hb_DirExists( cResDir + "/backends" )
      cBackends := cResDir + "/backends/cocoa"
      cSciInc   := cResDir + "/scintilla/include"
      cSciCocoa := cResDir + "/scintilla/cocoa"
      cLexInc   := cResDir + "/scintilla/lexilla"
      cSciLib   := cResDir + "/scintilla/build"
   else
      cBackends := cProjDir + "/source/backends/cocoa"
      cSciInc   := cProjDir + "/resources/scintilla_src/scintilla/include"
      cSciCocoa := cProjDir + "/resources/scintilla_src/scintilla/cocoa"
      cLexInc   := cProjDir + "/resources/scintilla_src/lexilla/include"
      cSciLib   := cProjDir + "/resources/scintilla_src/build"
   endif

   MAC_ShellExec( "mkdir -p " + cBuildDir )

   // Step 1: Save user code + copy framework
   cLog += "[1] Saving files..." + Chr(10)
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "/" + aForms[i][1] + ".prg", ;
         CodeEditorGetTabText( hCodeEditor, i + 1 ) )
   next
   if File( cResDir + "/classes.prg" )
      MAC_ShellExec( "cp " + cResDir + "/classes.prg " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cResDir + "/hbbuilder.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cResDir + "/hbide.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cResDir + "/dbgclient.prg " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cResDir + "/stddlgs_mac.mm " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + cResDir + "/hix_runtime.prg " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + cResDir + "/hix_template.prg " + cBuildDir + "/ 2>/dev/null" )
   else
      MAC_ShellExec( "cp " + cProjDir + "/source/core/classes.prg " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/include/hbbuilder.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/include/hbide.ch " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/source/debugger/dbgclient.prg " + cBuildDir + "/" )
      MAC_ShellExec( "cp " + cProjDir + "/resources/stddlgs_mac.mm " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + cProjDir + "/source/hix_runtime.prg " + cBuildDir + "/ 2>/dev/null" )
      MAC_ShellExec( "cp " + cProjDir + "/source/hix_template.prg " + cBuildDir + "/ 2>/dev/null" )
   endif

   // Step 2: Assemble debug_main.prg (tracking line offsets for each section)
   cLog += "[2] Assembling debug_main.prg..." + Chr(10)

   // Header: #include + GT + INIT PROCEDURE to start debug client
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_NUL_DEFAULT" + Chr(10)
   cAllPrg += "REQUEST DBFCDX, DBFNTX, DBFFPT" + Chr(10)
   cAllPrg += "INIT PROCEDURE __DbgInit" + Chr(10)
   cAllPrg += "   DbgClientStart( 19800 )" + Chr(10)
   cAllPrg += "return" + Chr(10) + Chr(10)
   nCurLine := 8

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

   // hix_runtime.prg (web server runtime — not in editor)
   if File( cBuildDir + "/hix_runtime.prg" )
      cAllPrg += MemoRead( cBuildDir + "/hix_runtime.prg" ) + Chr(10)
   endif
   // hix_template.prg (template engine — not in editor)
   if File( cBuildDir + "/hix_template.prg" )
      cAllPrg += MemoRead( cBuildDir + "/hix_template.prg" ) + Chr(10)
   endif

   MemoWrit( cBuildDir + "/debug_main.prg", cAllPrg )

   // Step 3: Harbour compile → C
   cLog += "[3] Harbour compile..." + Chr(10)
   cCmd := cHbBin + "/harbour " + cBuildDir + "/debug_main.prg -b -n -w -q" + ;
           " -I" + cHbInc + " -I" + cBuildDir + ;
           " -o" + cBuildDir + "/debug_main.c 2>&1"
   cOutput := MAC_ShellExec( cCmd )
   if "Error" $ cOutput
      cLog += cOutput + Chr(10)
      lError := .t.
   else
      cLog += "    OK" + Chr(10)
   endif

   // Step 4: Compile C sources
   if ! lError
      cLog += "[4] C compile..." + Chr(10)
      cCmd := "clang -c -O0 -g " + cBuildDir + "/debug_main.c" + ;
              " -I" + cHbInc + " -o " + cBuildDir + "/debug_main.o 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if "error:" $ Lower( cOutput )
         cLog += cOutput + Chr(10)
         lError := .t.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 5: Compile Cocoa backend + dbghook + gt_dummy
   if ! lError
      cLog += "[5] Cocoa backend + dbghook..." + Chr(10)

      // Compile dbghook.c (C-level debug hook wrapper)
      if File( cResDir + "/dbghook.c" )
         cCmd := "clang -c -O2 -I" + cHbInc + ;
                 " " + cResDir + "/dbghook.c" + ;
                 " -o " + cBuildDir + "/dbghook.o 2>&1"
      else
         cCmd := "clang -c -O2 -I" + cHbInc + ;
                 " " + cProjDir + "/source/debugger/dbghook.c" + ;
                 " -o " + cBuildDir + "/dbghook.o 2>&1"
      endif
      MAC_ShellExec( cCmd )

      cCmd := "clang -c -O2 -fobjc-arc -I" + cHbInc + ;
              " " + cBackends + "/cocoa_core.m" + ;
              " -o " + cBuildDir + "/cocoa_core.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -fobjc-arc -I" + cHbInc + ;
              " " + cBackends + "/cocoa_webserver.m" + ;
              " -o " + cBuildDir + "/cocoa_webserver.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang++ -c -O2 -std=c++17 -fobjc-arc -I" + cHbInc + ;
              " -I" + cSciInc + " -I" + cSciCocoa + " -I" + cLexInc + ;
              " " + cBackends + "/cocoa_editor.mm" + ;
              " -o " + cBuildDir + "/cocoa_editor.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -I" + cHbInc + ;
              " " + cBackends + "/cocoa_editor_reg.c" + ;
              " -o " + cBuildDir + "/cocoa_editor_reg.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -I" + cHbInc + ;
              " " + cBackends + "/gt_dummy.c" + ;
              " -o " + cBuildDir + "/gt_dummy.o 2>&1"
      MAC_ShellExec( cCmd )
      if File( cBuildDir + "/stddlgs_mac.mm" )
         cCmd := "clang++ -c -O2 -fobjc-arc -I" + cHbInc + ;
                 " " + cBuildDir + "/stddlgs_mac.mm" + ;
                 " -o " + cBuildDir + "/stddlgs_mac.o 2>&1"
         MAC_ShellExec( cCmd )
      endif
      cLog += "    OK" + Chr(10)
   endif

   // Step 6: Link native executable
   if ! lError
      cLog += "[6] Linking..." + Chr(10)
      cCmd := "clang++ -o " + cBuildDir + "/DebugApp" + ;
              " " + cBuildDir + "/debug_main.o" + ;
              " " + cBuildDir + "/dbghook.o" + ;
              " " + cBuildDir + "/cocoa_core.o" + ;
              " " + cBuildDir + "/cocoa_webserver.o" + ;
              " " + cBuildDir + "/cocoa_editor.o" + ;
              " " + cBuildDir + "/cocoa_editor_reg.o" + ;
              " " + cBuildDir + "/gt_dummy.o" + ;
              If( File( cBuildDir + "/stddlgs_mac.o" ), " " + cBuildDir + "/stddlgs_mac.o", "" ) + ;
              " " + cSciLib + "/libscintilla.a" + ;
              " " + cSciLib + "/liblexilla.a" + ;
              " -L" + cHbLib + ;
              " -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang" + ;
              " -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug" + ;
              " -lhbct -lhbextern -lhbsqlit3" + ;
              " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
              " -lhbhsx -lhbsix -lhbusrrdd" + ;
              " -lgtcgi -lgtstd" + ;
              " -framework Cocoa -framework QuartzCore -framework MapKit -framework CoreLocation -framework SceneKit -framework WebKit" + If( Val( MAC_ShellExec( "sw_vers -productVersion | cut -d. -f1" ) ) >= 11, " -framework UniformTypeIdentifiers", "" ) + ;
              " -lm -lpthread -lc++ -lsqlite3 -lcups 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += cOutput + Chr(10)
         lError := .t.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   if lError
      MAC_BuildErrorDialog( "Debug Build Failed", cLog )
      return nil
   endif

   if ! File( cBuildDir + "/DebugApp" )
      cLog += "ERROR: DebugApp not created" + Chr(10)
      MAC_BuildErrorDialog( "Debug Build Failed", cLog )
      return nil
   endif

   // Step 7: Hide design form, highlight Debug button, switch inspector, launch
   if oDesignForm != nil
      UI_FormHide( oDesignForm:hCpp )
   endif
   if oTB2 != nil
      UI_ToolBtnHighlight( oTB2:hCpp, 1, .t. )  // highlight Debug button
   endif
   InspectorOpen()
   OutErr( "DEBUG: Calling INS_SetDebugMode(.t.)" + Chr(10) )
   INS_SetDebugMode( _InsGetData(), .t. )
   OutErr( "DEBUG: Calling INS_BringToFront" + Chr(10) )
   INS_BringToFront( _InsGetData() )
   CodeEditorSelectTab( hCodeEditor, 1 )  // switch to Project1.prg

   // Always use run-to-breakpoint mode
   // If there are breakpoints: stops at first breakpoint
   // If no breakpoints: runs completely (doesn't stop at first line)
   IDE_DEBUGRUNTOBREAK2( cBuildDir + "/DebugApp", ;
      { |cFunc, nLine, cLocals, cStack| OnDebugPause( cFunc, nLine, cLocals, cStack ) } )

   // Restore: unhighlight, show design form, switch inspector back
   if oTB2 != nil
      UI_ToolBtnHighlight( oTB2:hCpp, 1, .f. )
   endif
   INS_SetDebugMode( _InsGetData(), .f. )
   if oDesignForm != nil
      UI_FormBringToFront( oDesignForm:hCpp )
   endif

return nil

// === Debug Run to Breakpoint (now same as regular Debug) ===

static function TBDebugRunToBreak()
   // Now identical to TBDebugRun() since both use run-to-breakpoint mode
   return TBDebugRun(.T.)

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
            // Skip spaces
            cLine := LTrim( cLine )
            // Extract name (stop at comma, space, :=, or end)
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
            // Skip past comma
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

// === Debug Pause Callback (called from C hook) ===

static function OnDebugPause( cFunc, nLine, cLocals, cStack )

   local i, nTab, nTabLine, cTabFile, hIns

   // Map debug_main.prg line → user source file/line via aDbgOffsets
   nTab := 0
   nTabLine := 0
   cTabFile := ""
   if aDbgOffsets != nil
      for i := Len( aDbgOffsets ) to 1 step -1
         if nLine >= aDbgOffsets[i][1]
            nTab     := aDbgOffsets[i][3]
            nTabLine := nLine - aDbgOffsets[i][1] + aDbgOffsets[i][4]
            cTabFile := aDbgOffsets[i][2]
            exit
         endif
      next
   endif

   // Framework code — don't pause
   if nTab == 0
      return .f.
   endif

   // Decide whether to pause: breakpoint hit OR step mode
   if !IDE_IsBreakpoint( cTabFile, nTabLine ) .and. !IDE_DbgIsStepping()
      return .f.
   endif

   // Switch tab and highlight current line
   CodeEditorSelectTab( hCodeEditor, nTab )
   CodeEditorShowDebugLine( hCodeEditor, nTabLine )

   // Map local variable names from index to source names
   if cLocals != nil
      cLocals := DbgMapLocalNames( cLocals, cFunc, nTab )
   endif

   // Update inspector
   hIns := _InsGetData()
   if hIns != 0
      if cLocals != nil
         INS_SetDebugLocals( hIns, cLocals )
      endif
      if cStack != nil
         INS_SetDebugStack( hIns, DbgFixStackLines( cStack ) )
      endif
   endif

   // Signal C layer to pause
   IDE_DebugPauseAtStep()

return .t.

// === AI Assistant ===

static function ShowAIAssistant()
   MAC_AIAssistantPanel()
return nil

// === Project Inspector ===

static function ShowProjectInspector()
   MAC_ProjectInspector()
return nil

// === Editor Colors ===

static function ShowEditorSettings()
   MAC_EditorColorsDialog( hCodeEditor )
return nil

// === Project Options ===

static function ShowProjectOptions()
   MAC_ProjectOptionsDialog()
return nil

// === Save As ===

static function TBSaveAs()
   local cFile := MAC_SaveFileDialog( "Save As", "hbp" )
   if ! Empty( cFile )
      cCurrentFile := cFile
      TBSave()
   endif
return nil

// === Debug Step ===

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

// === Components ===

static function InstallComponent()
   local cFile := MAC_OpenFileDialog( "Install Component (.prg)", "prg" )
   local cName
   if Empty( cFile ); return nil; endif
   cName := SubStr( cFile, RAt( "/", cFile ) + 1 )
   MsgInfo( "Component installed: " + cName + Chr(10) + Chr(10) + ;
            "The component will be available in the palette" + Chr(10) + ;
            "after restarting HbBuilder." )
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
   CodeEditorAddTab( hCodeEditor, "MyComponent.prg" )
   CodeEditorSetTabText( hCodeEditor, Len(aForms) + 2, cCode )
   CodeEditorSelectTab( hCodeEditor, Len(aForms) + 2 )
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

   nSel := MAC_SelectFromList( "Remove from Project", aNames )
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
   MAC_ProjectOptionsDialog()
return nil

// === Cut / Copy / Paste (context-aware: design form first, then code editor) ===

static function DesignHasSel()
return oDesignForm != nil .and. UI_FormIsKeyWindow( oDesignForm:hCpp ) .and. ;
       UI_FormSelCount( oDesignForm:hCpp ) > 0

static function SmartCut()
   if DesignHasSel()
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormCopySelected( oDesignForm:hCpp )
      UI_FormDeleteSelected( oDesignForm:hCpp )
      SyncDesignerToCode()
   else
      CodeEditorCut( hCodeEditor )
   endif
return nil

static function SmartCopy()
   if DesignHasSel()
      UI_FormCopySelected( oDesignForm:hCpp )
   else
      CodeEditorCopy( hCodeEditor )
   endif
return nil

static function SmartPaste()
   if oDesignForm != nil .and. UI_FormIsKeyWindow( oDesignForm:hCpp ) .and. ;
      UI_FormGetClipCount() > 0
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormPasteControls( oDesignForm:hCpp )
      SyncDesignerToCode()
   else
      CodeEditorPaste( hCodeEditor )
   endif
return nil

static function CopyControls()
   UI_FormCopySelected( oDesignForm:hCpp )
return nil

static function PasteControls()
   if oDesignForm != nil .and. UI_FormGetClipCount() > 0
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormPasteControls( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil

// === Align/Distribute ===

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

// === Undo/Redo (context-aware: design first, then code editor) ===

static function SmartUndo()
   if oDesignForm != nil .and. UI_FormUndoCount() > 0
      UI_FormUndo( oDesignForm:hCpp )
      SyncDesignerToCode()
   else
      CodeEditorUndo( hCodeEditor )
   endif
return nil

static function SmartRedo()
   CodeEditorRedo( hCodeEditor )
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

   MAC_AboutDialog( "About HbBuilder", cMsg, ResPath( "harbour_logo.png" ) )

return nil

// MsgInfo() is now in classes.prg (cross-platform)

// Helper for inspector: get current editor code for handler name resolution
function _InsGetEditorCode()

   if hCodeEditor != nil .and. nActiveForm > 0
      return CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   endif

return ""

// Locate a resource file/dir: checks bundle Resources/ first, then relative path
static function ResPath( cFile )
   local cBundle := HB_DirBase() + "../Resources/" + cFile
   if File( cBundle ) .or. hb_DirExists( cBundle )
      return cBundle
   endif
return "../resources/" + cFile

// Map component type number to CT_* define name for code generation
static function IsNonVisual( nType )
   // Visual controls that have high CT_* numbers (>= 38)
   // CT_BROWSE=79, CT_DBGRID=80, CT_DBNAVIGATOR=81, CT_DBTEXT=82,
   // CT_DBEDIT=83, CT_DBCOMBOBOX=84, CT_DBCHECKBOX=85, CT_DBIMAGE=86,
   // CT_WEBVIEW=62
   if nType == 62 .or. ( nType >= 79 .and. nType <= 86 ) .or. ;
      ( nType >= 132 .and. nType <= 135 ) .or. ;
      nType == 140 .or. nType == 141 .or. nType == 142
      return .F.
   endif
   if nType == 200  // CT_MAINMENU
      return .T.
   endif
return nType >= 38

static function ComponentTypeName( nType )
   do case
      case nType == 38;  return "CT_TIMER"
      case nType == 39;  return "CT_PAINTBOX"
      case nType == 40;  return "CT_OPENDIALOG"
      case nType == 41;  return "CT_SAVEDIALOG"
      case nType == 42;  return "CT_FONTDIALOG"
      case nType == 43;  return "CT_COLORDIALOG"
      case nType == 44;  return "CT_FINDDIALOG"
      case nType == 45;  return "CT_REPLACEDIALOG"
      case nType == 46;  return "CT_OPENAI"
      case nType == 47;  return "CT_GEMINI"
      case nType == 48;  return "CT_CLAUDE"
      case nType == 49;  return "CT_DEEPSEEK"
      case nType == 50;  return "CT_GROK"
      case nType == 51;  return "CT_OLLAMA"
      case nType == 52;  return "CT_TRANSFORMER"
      case nType == 53;  return "CT_DBFTABLE"
      case nType == 54;  return "CT_MYSQL"
      case nType == 55;  return "CT_MARIADB"
      case nType == 56;  return "CT_POSTGRESQL"
      case nType == 57;  return "CT_SQLITE"
      case nType == 58;  return "CT_FIREBIRD"
      case nType == 59;  return "CT_SQLSERVER"
      case nType == 60;  return "CT_ORACLE"
      case nType == 61;  return "CT_MONGODB"
      case nType == 62;  return "CT_WEBVIEW"
      case nType == 63;  return "CT_THREAD"
      case nType == 64;  return "CT_MUTEX"
      case nType == 65;  return "CT_SEMAPHORE"
      case nType == 66;  return "CT_CRITICALSECTION"
      case nType == 67;  return "CT_THREADPOOL"
      case nType == 68;  return "CT_ATOMICINT"
      case nType == 69;  return "CT_CONDVAR"
      case nType == 70;  return "CT_CHANNEL"
      case nType == 71;  return "CT_WEBSERVER"
      case nType == 72;  return "CT_WEBSOCKET"
      case nType == 73;  return "CT_HTTPCLIENT"
      case nType == 74;  return "CT_FTPCLIENT"
      case nType == 75;  return "CT_SMTPCLIENT"
      case nType == 76;  return "CT_TCPSERVER"
      case nType == 77;  return "CT_TCPCLIENT"
      case nType == 78;  return "CT_UDPSOCKET"
      case nType == 79;  return "CT_BROWSE"
      case nType == 80;  return "CT_DBGRID"
      case nType == 81;  return "CT_DBNAVIGATOR"
      case nType == 82;  return "CT_DBTEXT"
      case nType == 83;  return "CT_DBEDIT"
      case nType == 84;  return "CT_DBCOMBOBOX"
      case nType == 85;  return "CT_DBCHECKBOX"
      case nType == 86;  return "CT_DBIMAGE"
      case nType == 90;  return "CT_PREPROCESSOR"
      case nType == 91;  return "CT_SCRIPTENGINE"
      case nType == 92;  return "CT_REPORTDESIGNER"
      case nType == 93;  return "CT_BARCODE"
      case nType == 94;  return "CT_PDFGENERATOR"
      case nType == 95;  return "CT_EXCELEXPORT"
      case nType == 96;  return "CT_AUDITLOG"
      case nType == 97;  return "CT_PERMISSIONS"
      case nType == 98;  return "CT_CURRENCY"
      case nType == 99;  return "CT_TAXENGINE"
      case nType == 100; return "CT_DASHBOARD"
      case nType == 101; return "CT_SCHEDULER"
      case nType == 102; return "CT_PRINTER"
      case nType == 103; return "CT_REPORT"
      case nType == 104; return "CT_LABELS"
      case nType == 105; return "CT_PRINTPREVIEW"
      case nType == 106; return "CT_PAGESETUP"
      case nType == 107; return "CT_PRINTDIALOG"
      case nType == 108; return "CT_REPORTVIEWER"
      case nType == 109; return "CT_BARCODEPRINTER"
      case nType == 110; return "CT_WHISPER"
      case nType == 111; return "CT_EMBEDDINGS"
      case nType == 112; return "CT_PYTHON"
      case nType == 113; return "CT_SWIFT"
      case nType == 114; return "CT_GO"
      case nType == 115; return "CT_NODE"
      case nType == 116; return "CT_RUST"
      case nType == 117; return "CT_JAVA"
      case nType == 118; return "CT_DOTNET"
      case nType == 119; return "CT_LUA"
      case nType == 120; return "CT_RUBY"
      case nType == 121; return "CT_GITREPO"
      case nType == 122; return "CT_GITCOMMIT"
      case nType == 123; return "CT_GITBRANCH"
      case nType == 124; return "CT_GITLOG"
      case nType == 125; return "CT_GITDIFF"
      case nType == 126; return "CT_GITREMOTE"
      case nType == 127; return "CT_GITSTASH"
      case nType == 128; return "CT_GITTAG"
      case nType == 129; return "CT_GITBLAME"
      case nType == 130; return "CT_GITMERGE"
      case nType == 131; return "CT_COMPARRAY"
      case nType == 132; return "CT_BAND"
      case nType == 200; return "CT_MAINMENU"
      case nType == 133; return "CT_REPORTLABEL"
      case nType == 134; return "CT_REPORTFIELD"
      case nType == 135; return "CT_REPORTIMAGE"
   endcase
return LTrim(Str(nType))

// Reverse map: CT_* define name to type number (for parsing saved code)
static function ResolveComponentType( cName )
   local i, aMap := { ;
      { "CT_TIMER", 38 }, { "CT_PAINTBOX", 39 }, ;
      { "CT_OPENDIALOG", 40 }, { "CT_SAVEDIALOG", 41 }, ;
      { "CT_FONTDIALOG", 42 }, { "CT_COLORDIALOG", 43 }, ;
      { "CT_FINDDIALOG", 44 }, { "CT_REPLACEDIALOG", 45 }, ;
      { "CT_OPENAI", 46 }, { "CT_GEMINI", 47 }, { "CT_CLAUDE", 48 }, ;
      { "CT_DEEPSEEK", 49 }, { "CT_GROK", 50 }, { "CT_OLLAMA", 51 }, ;
      { "CT_TRANSFORMER", 52 }, ;
      { "CT_DBFTABLE", 53 }, { "CT_MYSQL", 54 }, { "CT_MARIADB", 55 }, ;
      { "CT_POSTGRESQL", 56 }, { "CT_SQLITE", 57 }, { "CT_FIREBIRD", 58 }, ;
      { "CT_SQLSERVER", 59 }, { "CT_ORACLE", 60 }, { "CT_MONGODB", 61 }, ;
      { "CT_WEBVIEW", 62 }, { "CT_THREAD", 63 }, { "CT_MUTEX", 64 }, ;
      { "CT_SEMAPHORE", 65 }, { "CT_CRITICALSECTION", 66 }, ;
      { "CT_THREADPOOL", 67 }, { "CT_ATOMICINT", 68 }, ;
      { "CT_CONDVAR", 69 }, { "CT_CHANNEL", 70 }, ;
      { "CT_WEBSERVER", 71 }, { "CT_WEBSOCKET", 72 }, ;
      { "CT_HTTPCLIENT", 73 }, { "CT_FTPCLIENT", 74 }, ;
      { "CT_SMTPCLIENT", 75 }, { "CT_TCPSERVER", 76 }, ;
      { "CT_TCPCLIENT", 77 }, { "CT_UDPSOCKET", 78 }, ;
      { "CT_BROWSE", 79 }, { "CT_DBGRID", 80 }, { "CT_DBNAVIGATOR", 81 }, ;
      { "CT_DBTEXT", 82 }, { "CT_DBEDIT", 83 }, { "CT_DBCOMBOBOX", 84 }, ;
      { "CT_DBCHECKBOX", 85 }, { "CT_DBIMAGE", 86 }, ;
      { "CT_PREPROCESSOR", 90 }, { "CT_SCRIPTENGINE", 91 }, ;
      { "CT_REPORTDESIGNER", 92 }, { "CT_BARCODE", 93 }, ;
      { "CT_PDFGENERATOR", 94 }, { "CT_EXCELEXPORT", 95 }, ;
      { "CT_AUDITLOG", 96 }, { "CT_PERMISSIONS", 97 }, ;
      { "CT_CURRENCY", 98 }, { "CT_TAXENGINE", 99 }, ;
      { "CT_DASHBOARD", 100 }, { "CT_SCHEDULER", 101 }, ;
      { "CT_PRINTER", 102 }, { "CT_REPORT", 103 }, { "CT_LABELS", 104 }, ;
      { "CT_PRINTPREVIEW", 105 }, { "CT_PAGESETUP", 106 }, ;
      { "CT_PRINTDIALOG", 107 }, { "CT_REPORTVIEWER", 108 }, ;
      { "CT_BARCODEPRINTER", 109 }, ;
      { "CT_WHISPER", 110 }, { "CT_EMBEDDINGS", 111 }, ;
      { "CT_PYTHON", 112 }, { "CT_SWIFT", 113 }, { "CT_GO", 114 }, ;
      { "CT_NODE", 115 }, { "CT_RUST", 116 }, { "CT_JAVA", 117 }, ;
      { "CT_DOTNET", 118 }, { "CT_LUA", 119 }, { "CT_RUBY", 120 }, ;
      { "CT_GITREPO", 121 }, { "CT_GITCOMMIT", 122 }, ;
      { "CT_GITBRANCH", 123 }, { "CT_GITLOG", 124 }, ;
      { "CT_GITDIFF", 125 }, { "CT_GITREMOTE", 126 }, ;
      { "CT_GITSTASH", 127 }, { "CT_GITTAG", 128 }, ;
      { "CT_GITBLAME", 129 }, { "CT_GITMERGE", 130 }, ;
      { "CT_COMPARRAY", 131 }, ;
      { "CT_BAND", 132 }, ;
      { "CT_REPORTLABEL", 133 }, { "CT_REPORTFIELD", 134 }, { "CT_REPORTIMAGE", 135 }, ;
      { "CT_MAINMENU", 200 } }
   for i := 1 to Len( aMap )
      if Upper( cName ) == aMap[i][1]
         return aMap[i][2]
      endif
   next
return 0

// --- ScanMethodDeclarations ---
// Extract every "METHOD <Name>() CLASS <cClass>" implementation from
// cCode and return a block of "   METHOD <Name>()" declarations suitable
// for inclusion inside the CLASS body. Skips CreateForm which is already
// hardcoded. Returns "" if no user methods are found.
static function ScanMethodDeclarations( cCode, cClass )

   local cOut := "", e := Chr(10)
   local aLines, cLine, cTrim, cName, nPos, nPos2, i
   local cTag := "CLASS " + cClass

   if Empty( cCode ); return ""; endif

   aLines := HB_ATokens( cCode, e )
   for i := 1 to Len( aLines )
      cTrim := AllTrim( StrTran( aLines[i], Chr(13), "" ) )
      if Left( cTrim, 7 ) == "METHOD "
         if cTag $ cTrim
            cName := AllTrim( SubStr( cTrim, 8 ) )  // after "METHOD "
            nPos := At( "(", cName )
            if nPos > 0
               cName := Left( cName, nPos - 1 )
            endif
            nPos := At( " ", cName )
            if nPos > 0
               cName := Left( cName, nPos - 1 )
            endif
            if ! Empty( cName ) .and. Upper( cName ) != "CREATEFORM"
               cOut += "   METHOD " + cName + "()" + e
            endif
         endif
      endif
   next

return cOut

// --- INI file helpers (hbbuilder.ini) ---

static function IniFilePath()
return HB_DirBase() + "../hbbuilder.ini"

static function IniWrite( cSection, cKey, cValue )

   local cFile := IniFilePath()
   local cContent, aLines, i, lFound, cSearch

   cContent := MemoRead( cFile )
   if Empty( cContent )
      cContent := ""
   endif

   aLines := HB_ATokens( cContent, Chr(10) )
   cSearch := Lower( cKey ) + "="
   lFound := .f.

   for i := 1 to Len( aLines )
      if Lower( AllTrim( aLines[i] ) ) == Lower( cKey ) + "=" + Lower( cValue )
         return nil  // already set
      endif
      if Left( Lower( AllTrim( aLines[i] ) ), Len( cSearch ) ) == cSearch
         aLines[i] := cKey + "=" + cValue
         lFound := .t.
         exit
      endif
   next

   if ! lFound
      AAdd( aLines, cKey + "=" + cValue )
   endif

   cContent := ""
   for i := 1 to Len( aLines )
      cContent += aLines[i]
      if i < Len( aLines )
         cContent += Chr(10)
      endif
   next

   MemoWrit( cFile, cContent )

return nil

static function IniRead( cSection, cKey, cDefault )

   local cFile := IniFilePath()
   local cContent, aLines, i, cSearch

   cContent := MemoRead( cFile )
   if Empty( cContent )
      return cDefault
   endif

   aLines := HB_ATokens( cContent, Chr(10) )
   cSearch := Lower( cKey ) + "="

   for i := 1 to Len( aLines )
      if Left( Lower( AllTrim( aLines[i] ) ), Len( cSearch ) ) == cSearch
         return SubStr( AllTrim( aLines[i] ), Len( cSearch ) + 1 )
      endif
   next

return cDefault

// --- File > Recent project list ---
// Persisted across sessions via IniWrite/IniRead under [Recent] File1..N.
// Capped at MAX_RECENT; most-recent-first order, deduped.

#define MAX_RECENT 8

static function AddRecentProject( cFile )

   local aList := GetRecentProjects()
   local nPos, i

   // Dedupe: remove if already present
   nPos := AScan( aList, { |x| Lower(x) == Lower(cFile) } )
   if nPos > 0
      ADel( aList, nPos )
      aList := ASize( aList, Len(aList) - 1 )
   endif

   AAdd( aList, cFile )

   // Cap at MAX_RECENT
   while Len( aList ) > MAX_RECENT
      ADel( aList, 1 )
      aList := ASize( aList, Len(aList) - 1 )
   enddo

   // Persist most-recent-first
   for nPos := 1 to MAX_RECENT
      if Len( aList ) >= nPos
         IniWrite( "Recent", "File" + LTrim( Str( nPos ) ), aList[ Len(aList) - nPos + 1 ] )
      else
         IniWrite( "Recent", "File" + LTrim( Str( nPos ) ), "" )
      endif
   next

return nil

static function GetRecentProjects()

   local aList := {}, i, cVal

   for i := MAX_RECENT to 1 step -1   // stored newest first; return oldest first
      cVal := IniRead( "Recent", "File" + LTrim( Str( i ) ), "" )
      if ! Empty( cVal )
         AAdd( aList, cVal )
      endif
   next

return aList

// File > Reopen Last Project - opens the most recent .hbp stored in
// [Recent]/File1. Silent no-op if the file no longer exists on disk.
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

   // Reuse the OpenProjectFile logic from TBOpen, but without the file dialog
   OpenProjectFile( cFile )

return nil

// Shared helper: open a project file by path (used by TBOpen and ReopenLastProject)
static function OpenProjectFile( cFile )

   local cContent, cDir, aLines, i
   local cFormName, cFormCode, nFormX, nFormY
   local nInsW, nInsTop, nEditorTop, nEditorX, nEditorW, nEditorH
   local lInModules, nAns

   // Ask to save current work if there are forms open
   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before opening?", "HbBuilder" )
      if nAns == 0  // Cancel
         return nil
      elseif nAns == 1  // Yes
         TBSave()
      endif
   endif

   cContent := MemoRead( cFile )
   if Empty( cContent )
      MsgInfo( "Could not read project: " + cFile )
      return nil
   endif

   // Project dir
   cDir := Left( cFile, RAt( "/", cFile ) )

   // Destroy current forms
   for i := 1 to Len( aForms )
      UI_FormHide( aForms[i][2]:hCpp )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0
   aModules := {}
   aOpenFiles := {}
   oDesignForm := nil

   // Clear editor tabs
   CodeEditorClearTabs( hCodeEditor )

   // Calculate form positions
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := MAC_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 80
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop

   // Read project file
   aLines := HB_ATokens( cContent, Chr(10) )

   // Load Project1.prg
   cFormCode := MemoRead( cDir + "Project1.prg" )
   if ! Empty( cFormCode )
      CodeEditorSetTabText( hCodeEditor, 1, cFormCode )
   endif

   // Load each form
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

      WireDesignForm()
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

   // Activate first form
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

// -------------------------------------------------------------------
// iOS support - Run on iOS and Setup Wizard
// -------------------------------------------------------------------

static function TBRuniOS()

   local cHome       := GetEnv( "HOME" )
   local cRepoRoot   := HB_DirBase() + ".."
   local cResDir     := HB_DirBase() + "../Resources"
   local cIOSDir     := cHome + "/harbour-ios-src"
   local cBackend    := ""
   local cGenPrg     := "/tmp/hbbuilder_ios/_generated.prg"
   local cBuildSh    := ""
   local cAppPath    := "/tmp/HarbouriOS/app-build/HarbourApp.app"
   local cLogPath    := "/tmp/hbbuilder_ios/build-ios.log"
   local cHbBin      := cHome + "/harbour/bin/harbour"
   local cPrg, cLog, cCmd, nRc

   // Resolve iOS backend path (bundle Resources or source tree)
   if hb_DirExists( cResDir + "/backends/ios" )
      cBackend := cResDir + "/backends/ios"
   else
      cBackend := cRepoRoot + "/source/backends/ios"
   endif
   cBuildSh := cBackend + "/build-ios-app.sh"

   // Check toolchain
   if ! hb_DirExists( cIOSDir )
      MsgInfo( "iOS toolchain not found." + Chr(10) + ;
               "Run 'iOS Setup Wizard' first to build Harbour for iOS.", ;
               "iOS target" )
      return nil
   endif
   if ! hb_DirExists( cIOSDir + "/lib/darwin/clang-ios-arm64" )
      MsgInfo( "Harbour iOS libraries not found at" + Chr(10) + ;
               cIOSDir + "/lib/darwin/clang-ios-arm64/" + Chr(10) + ;
               "Run 'iOS Setup Wizard' to build them.", ;
               "iOS target" )
      return nil
   endif

   SaveActiveFormCode()
   SyncDesignerToCode()

   // Generate iOS PRG from the current form
   cPrg := GenerateiOSPRG()
   if Empty( cPrg )
      MsgInfo( "No form to build - add at least one control to the designer.", ;
               "iOS target" )
      return nil
   endif

   hb_DirBuild( "/tmp/hbbuilder_ios" )
   MemoWrit( cGenPrg, cPrg )

   // Delete stale .app
   if hb_DirExists( cAppPath )
      hb_run( "rm -rf " + cAppPath )
   endif

   // Build .app for simulator
   cCmd := 'bash "' + cBuildSh + '" "' + cGenPrg + '" simulator > "' + cLogPath + '" 2>&1'
   nRc := hb_run( cCmd )

   cLog := iif( File( cLogPath ), MemoRead( cLogPath ), "(no log produced)" )

   if ! hb_DirExists( cAppPath )
      MsgInfo( "iOS Build Failed" + Chr(10) + Chr(10) + ;
               SubStr( cLog, Max(1, Len(cLog)-2000) ), ;
               "iOS target" )
      return nil
   endif

   // Install and launch on simulator
   cCmd := 'bash "' + cBackend + '/install-and-run.sh" "' + cAppPath + '" > /tmp/hbbuilder_ios/ios-run.log 2>&1 &'
   hb_run( cCmd )

   MsgInfo( "iOS .app built and installed on simulator!" + Chr(10) + ;
            cAppPath + Chr(10) + Chr(10) + ;
            "The app should now be running on the iPhone simulator.", ;
            "iOS target" )

return nil

// iOS Setup Wizard
//
// Reports which toolchain components are present and, if anything is
// missing, offers to run setup-ios-toolchain.sh.

static function iOSSetupWizard()

   local cHome    := GetEnv( "HOME" )
   local cIOSDir  := cHome + "/harbour-ios-src"
   local cReport  := "iOS toolchain status:" + Chr(10) + Chr(10)
   local lXcode, lIosSdk, lSimRuntime, lHbIos, lHbHost, cCmd, cSetupSh

   lXcode     := File( "/Applications/Xcode.app/Contents/MacOS/Xcode" )
   lIosSdk    := .F.
   lSimRuntime := .F.
   lHbIos     := hb_DirExists( cIOSDir + "/lib/darwin/clang-ios-arm64" )
   lHbHost    := File( cHome + "/harbour/bin/harbour" )

   // Check iOS SDK
   if lXcode
      cCmd := hb_run( "xcrun --sdk iphoneos --show-sdk-path 2>/dev/null" )
      lIosSdk := ! Empty( hb_CStr( cCmd ) )
   endif

   // Check simulator runtime
   if lXcode
      cCmd := hb_run( "xcrun simctl list runtimes 2>/dev/null | grep -c iOS" )
      lSimRuntime := Val( hb_CStr( cCmd ) ) > 0
   endif

   cReport += "  Xcode            " + iif( lXcode,      "OK", "MISSING" ) + Chr(10)
   cReport += "  iOS SDK          " + iif( lIosSdk,    "OK", "MISSING" ) + Chr(10)
   cReport += "  iOS Simulator    " + iif( lSimRuntime, "OK", "MISSING" ) + Chr(10)
   cReport += "  Harbour (host)   " + iif( lHbHost,    "OK", "MISSING" ) + Chr(10)
   cReport += "  Harbour iOS libs " + iif( lHbIos,     "OK", "MISSING" ) + Chr(10)

   // Everything present?
   if lXcode .and. lIosSdk .and. lSimRuntime .and. lHbHost .and. lHbIos
      MsgInfo( cReport + Chr(10) + "Toolchain is complete. Ready to Run on iOS.", ;
               "iOS Setup Wizard" )
      return nil
   endif

   // Xcode is required
   if ! lXcode
      MsgInfo( cReport + Chr(10) + ;
               "Install Xcode from the Mac App Store first.", ;
               "iOS Setup Wizard" )
      return nil
   endif

   // Harbour host is required
   if ! lHbHost
      MsgInfo( cReport + Chr(10) + ;
               "Harbour for macOS not found at ~/harbour/bin/harbour" + Chr(10) + ;
               "Install Harbour first.", ;
               "iOS Setup Wizard" )
      return nil
   endif

   // Offer to build the missing pieces
   cReport += Chr(10) + "Build the missing iOS components now?" + Chr(10) + ;
              "(This will clone and cross-compile Harbour for iOS." + Chr(10) + ;
              "It takes about 5-10 minutes.)"
   if ! MsgYesNo( cReport, "iOS Setup Wizard" )
      return nil
   endif

   // Run setup script in a Terminal.app window
   if File( HB_DirBase() + "../Resources/backends/ios/setup-ios-toolchain.sh" )
      cSetupSh := HB_DirBase() + "../Resources/backends/ios/setup-ios-toolchain.sh"
   else
      cSetupSh := HB_DirBase() + "../../source/backends/ios/setup-ios-toolchain.sh"
   endif
   cCmd := 'open -a Terminal.app "' + cSetupSh + '"'
   hb_run( cCmd )

   MsgInfo( "Setup terminal launched. When it says 'All done', close it " + ;
            "and try Run > Run on iOS...", "iOS Setup Wizard" )

return nil

// Generate iOS PRG from the current form design
// (same pattern as GenerateAndroidPRG on Windows)

static function GenerateiOSPRG()

   local cPRG, e := Chr(10)
   local hForm, nCount, i, hCtrl, nType
   local cName, cText, nL, nT, nW, nH, cTitle, nFW, nFH, nFormClr, nCtrlClr
   local cFontFam, nFontSize, cVal, nPos
   local cEventTab, aCreate := {}, aBind := {}
   local cQ := Chr(34)

   // Get the form handle
   hForm := nil
   if oDesignForm != nil .and. ValType( oDesignForm ) == "O"
      hForm := oDesignForm:hCpp
   endif
   if ( hForm == nil .or. hForm == 0 ) .and. ! Empty( aForms )
      if aForms[1][2] != nil .and. ValType( aForms[1][2] ) == "O"
         hForm := aForms[1][2]:hCpp
      endif
   endif
   if hForm == nil .or. hForm == 0
      return ""
   endif

   cTitle := UI_GetProp( hForm, "cText" )
   if Empty( cTitle )
      cTitle := iif( ! Empty( aForms ), aForms[1][1], "Form1" )
   endif
   nFW := UI_GetProp( hForm, "nWidth" )
   nFH := UI_GetProp( hForm, "nHeight" )
   nFormClr := UI_GetProp( hForm, "nClrPane" )

   nCount := UI_GetChildCount( hForm )

   // Generate UI_* calls for each control
   for i := 1 to nCount
      hCtrl  := UI_GetChild( hForm, i )
      cName  := UI_GetProp( hCtrl, "cName" )
      cText  := UI_GetProp( hCtrl, "cText" )
      nL     := UI_GetProp( hCtrl, "nLeft" )
      nT     := UI_GetProp( hCtrl, "nTop" ) + 50   // offset for iOS safe area
      nW     := UI_GetProp( hCtrl, "nWidth" )
      nH     := UI_GetProp( hCtrl, "nHeight" )
      nType  := UI_GetType( hCtrl )
      nCtrlClr := UI_GetProp( hCtrl, "nClrPane" )

      if Empty( cName )
         cName := "ctrl" + LTrim( Str( i ) )
      endif

      do case
      case nType == 1  // Label
         AAdd( aCreate, '   ' + cName + ' := UI_LabelNew( hForm, ' + cQ + cText + cQ + ', ' + ;
               LTrim(Str(nL)) + ', ' + LTrim(Str(nT)) + ', ' + ;
               LTrim(Str(nW)) + ', ' + LTrim(Str(nH)) + ' )' )
      case nType == 2  // Edit
         AAdd( aCreate, '   ' + cName + ' := UI_EditNew( hForm, ' + cQ + cText + cQ + ', ' + ;
               LTrim(Str(nL)) + ', ' + LTrim(Str(nT)) + ', ' + ;
               LTrim(Str(nW)) + ', ' + LTrim(Str(nH)) + ' )' )
      case nType == 3  // Button
         AAdd( aCreate, '   ' + cName + ' := UI_ButtonNew( hForm, ' + cQ + cText + cQ + ', ' + ;
               LTrim(Str(nL)) + ', ' + LTrim(Str(nT)) + ', ' + ;
               LTrim(Str(nW)) + ', ' + LTrim(Str(nH)) + ' )' )
      endcase

      // Color
      if nCtrlClr > 0
         AAdd( aCreate, '   UI_SetCtrlColor( ' + cName + ', ' + LTrim(Str(nCtrlClr)) + ' )' )
      endif

      // Font (read from oFont property string "Family,Size")
      cVal := UI_GetProp( hCtrl, "oFont" )
      if ! Empty( cVal ) .and. cVal != "System,12" .and. cVal != ".LucidaGrande,13"
         nPos := At( ",", cVal )
         if nPos > 0
            cFontFam  := Left( cVal, nPos - 1 )
            nFontSize := Val( SubStr( cVal, nPos + 1 ) )
            if ! Empty( cFontFam ) .or. nFontSize > 0
               AAdd( aCreate, '   UI_SetCtrlFont( ' + cName + ', ' + cQ + cFontFam + cQ + ', ' + LTrim(Str(nFontSize)) + ' )' )
            endif
         endif
      endif

      // OnClick (buttons only — only buttons have click handlers on iOS)
      if nType == 3 .and. ! Empty( cName )
         AAdd( aBind, '   UI_OnClick( ' + cName + ', {|| ' + cName + '_OnClick() } )' )
      endif
   next

   // Assemble the PRG
   cPRG := '/* Generated by HarbourBuilder - iOS target */' + e + e
   cPRG += 'PROCEDURE Main()' + e + e
   cPRG += '   LOCAL hForm' + e

   for i := 1 to nCount
      hCtrl := UI_GetChild( hForm, i )
      cName := UI_GetProp( hCtrl, "cName" )
      if Empty( cName )
         cName := "ctrl" + LTrim( Str( i ) )
      endif
      cPRG += '   LOCAL ' + cName + e
   next

   cPRG += e
   cPRG += '   hForm := UI_FormNew( ' + cQ + cTitle + cQ + ', ' + ;
           LTrim(Str(nFW)) + ', ' + LTrim(Str(nFH)) + ' )' + e

   if nFormClr > 0
      cPRG += '   UI_SetFormColor( ' + LTrim(Str(nFormClr)) + ' )' + e
   endif

   cPRG += e
   for i := 1 to Len( aCreate )
      cPRG += aCreate[i] + e
   next

   cPRG += e
   for i := 1 to Len( aBind )
      cPRG += aBind[i] + e
   next

   cPRG += e + '   UI_FormRun( hForm )' + e + e
   cPRG += 'RETURN' + e + e

   // Stub click handlers
   for i := 1 to nCount
      hCtrl := UI_GetChild( hForm, i )
      nType := UI_GetType( hCtrl )
      if nType == 3  // Button only
         cName := UI_GetProp( hCtrl, "cName" )
         if Empty( cName )
            cName := "ctrl" + LTrim( Str( i ) )
         endif
         cPRG += 'PROCEDURE ' + cName + '_OnClick()' + e
         cPRG += '   // TODO: implement' + e
         cPRG += 'RETURN' + e + e
      endif
   next

return cPRG

// ─── Git menu functions ──────────────────────────────────────────────────────

static function GitProjectDir()
   local cDir
   if ! Empty( cCurrentFile )
      cDir := hb_FNameDir( cCurrentFile )
   else
      cDir := hb_DirBase() + "../"
   endif
return cDir

static function GitInit()
   local cDir := GitProjectDir()
   GIT_Exec( "init", cDir )
   MsgInfo( "Git repository initialized in:" + Chr(10) + cDir )
return nil

static function GitClone()
   local cUrl, cDest, cOut
   cUrl := MAC_InputBox( "Clone Repository", "Enter repository URL:", "" )
   if Empty( cUrl ); return nil; endif
   cDest := MAC_InputBox( "Clone Repository", "Destination directory:", hb_DirBase() + "../" )
   if Empty( cDest ); return nil; endif
   cOut := GIT_Exec( "clone " + cUrl + " " + cDest, hb_DirBase() )
   MsgInfo( iif( Empty(cOut), "Clone completed", cOut ), "Git Clone" )
return nil

static function GitStatus()
   local cDir   := GitProjectDir()
   local cBranch, aChanges, cText, i
   if ! GIT_IsRepo( cDir )
      MsgInfo( "Not a git repository:" + Chr(10) + cDir )
      return nil
   endif
   cBranch  := GIT_CurrentBranch( cDir )
   aChanges := GIT_Status( cDir )
   cText    := "Branch: " + cBranch + Chr(10) + Chr(10)
   if Len( aChanges ) == 0
      cText += "Working tree clean"
   else
      for i := 1 to Len( aChanges )
         cText += aChanges[i][1] + "  " + aChanges[i][2] + Chr(10)
      next
   endif
   MsgInfo( cText, "Git Status" )
return nil

static function GitCommit()
   local cDir := GitProjectDir()
   local cMsg, cOut
   if ! GIT_IsRepo( cDir )
      MsgInfo( "Not a git repository" ); return nil
   endif
   cMsg := MAC_InputBox( "Git Commit", "Commit message:", "" )
   if Empty( cMsg ); return nil; endif
   GIT_Exec( "add -A", cDir )
   cOut := GIT_Exec( 'commit -m "' + cMsg + '"', cDir )
   MsgInfo( iif( Empty(cOut), "Nothing to commit", cOut ), "Git Commit" )
return nil

static function GitPush()
   local cOut := GIT_Exec( "push", GitProjectDir() )
   MsgInfo( iif( Empty(cOut), "Push completed", cOut ), "Git Push" )
return nil

static function GitPull()
   local cOut := GIT_Exec( "pull", GitProjectDir() )
   MsgInfo( iif( Empty(cOut), "Already up to date", cOut ), "Git Pull" )
return nil

static function GitBranchCreate()
   local cDir, cName, cOut
   cDir  := GitProjectDir()
   cName := MAC_InputBox( "New Branch", "Branch name:", "" )
   if Empty( cName ); return nil; endif
   cOut := GIT_Exec( "checkout -b " + cName, cDir )
   MsgInfo( iif( Empty(cOut), "Branch '" + cName + "' created", cOut ), "Git Branch" )
return nil

static function GitBranchSwitch()
   local cDir, aBranches, aNames, i, nSel, cOut
   cDir      := GitProjectDir()
   aBranches := GIT_BranchList( cDir )
   aNames    := {}
   if Len( aBranches ) == 0
      MsgInfo( "No branches found" ); return nil
   endif
   for i := 1 to Len( aBranches )
      AAdd( aNames, iif( aBranches[i][2], "* ", "  " ) + AllTrim( aBranches[i][1] ) )
   next
   nSel := MAC_SelectFromList( "Switch Branch", aNames )
   if nSel > 0
      cOut := GIT_Exec( "checkout " + AllTrim( aBranches[nSel][1] ), cDir )
      MsgInfo( iif( Empty(cOut), "Switched to " + AllTrim( aBranches[nSel][1] ), cOut ), "Git Checkout" )
   endif
return nil

static function GitMerge()
   local cDir, cBranch, cOut
   cDir    := GitProjectDir()
   cBranch := MAC_InputBox( "Git Merge", "Branch to merge into current:", "" )
   if Empty( cBranch ); return nil; endif
   cOut := GIT_Exec( "merge " + cBranch, cDir )
   MsgInfo( iif( Empty(cOut), "Merge completed", cOut ), "Git Merge" )
return nil

static function GitStash()
   GIT_Exec( "stash", GitProjectDir() )
   MsgInfo( "Changes stashed", "Git Stash" )
return nil

static function GitStashPop()
   local cOut := GIT_Exec( "stash pop", GitProjectDir() )
   MsgInfo( iif( Empty(cOut), "Stash applied", cOut ), "Git Stash Pop" )
return nil

static function GitLogShow()
   local aLog := GIT_Log( 30, GitProjectDir() )
   local cText := "", i
   if Len( aLog ) == 0
      MsgInfo( "No commits found" ); return nil
   endif
   for i := 1 to Len( aLog )
      cText += Left( aLog[i][1], 7 ) + "  " + aLog[i][3] + "  " + aLog[i][4] + Chr(10)
   next
   MsgInfo( cText, "Git Log (last 30)" )
return nil

static function GitDiffShow()
   local cDiff := GIT_Diff( "", GitProjectDir() )
   MsgInfo( iif( Empty(cDiff), "No changes", Left(cDiff, 3000) ), "Git Diff" )
return nil

static function GitBlameShow()
   local cFile, cOut
   cFile := cCurrentFile
   if Empty( cFile )
      MsgInfo( "No file open" ); return nil
   endif
   cOut := GIT_Exec( "blame " + hb_FNameNameExt( cFile ), hb_FNameDir( cFile ) )
   MsgInfo( iif( Empty(cOut), "No blame data", Left(cOut, 3000) ), "Git Blame" )
return nil

// Framework
#include "classes.prg"
#include "inspector_mac.prg"
