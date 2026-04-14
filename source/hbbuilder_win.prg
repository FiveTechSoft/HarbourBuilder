// hbbuilder_win.prg - HbBuilder: visual IDE for Harbour (C++Builder layout)
//
// Classic layout (originally 1024x768, scaled proportionally):
//
// +-------------------------------------------------------------+ 0
// |  Main Bar: toolbar + splitter + palette tabs (full width)    |
// +----------+--------------------------------------------------+ ~140
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

REQUEST HB_GT_GUI_DEFAULT

static oIDE          // Main IDE bar (top strip)
static oDesignForm   // Design form (active, floats on top of editor)
static hCodeEditor   // Code editor (background, right of inspector)
static nScreenW      // Screen width
static nScreenH      // Screen height
static cCurrentFile  // Current file path (empty = untitled)
static lSwitching := .f.  // Guard against re-entrant SwitchToForm
static lSyncingFromCode := .f.  // Guard: true while syncing code editor -> form

// Project form list (C++Builder: each form = a unit)
// Each entry: { cName, oForm, cCode, nFormX, nFormY }
static aForms        // Array of form entries
static nActiveForm   // Index of active form (1-based)
static lDarkMode := .T.   // Dark mode state for toggle
static cSelectedCompiler := ""  // "", "msvc", "bcc" (empty = auto-detect)
static nSelectedCompIdx := 0    // index into aCompilers (0 = auto)
static aCompilers := nil        // compiler registry from ScanCompilers()
static aDbgOffsets              // Line offset map for debug_main.prg → editor tabs
static hToolsPopup := 0        // Tools menu popup handle (for Dark Mode checkmark)

function Main()

   local oTB, oTB2, oFile, oEdit, oSearch, oView, oProject, oRun, oFormat, oComp, oTools, oGit, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY
   local cIcoDir, aCI0, cCompLabel

   // Install global error handler as early as possible so any runtime
   // error (including from Win32 callbacks like designer clicks, menu
   // actions, inspector edits) surfaces with a readable diagnostic
   // dialog instead of failing silently.
   ErrorBlock( {|oErr| IDE_ErrorHandler( oErr ) } )

   // DPI awareness (only for IDE, not for DebugApp)
   SetDPIAware()

   // Load dark mode preference from INI
   lDarkMode := ( IniRead( "IDE", "DarkMode", "1" ) == "1" )

   // Apply dark mode to system (menus, scrollbars) — must be before any window
   W32_SetIDEDarkMode( lDarkMode )
   if lDarkMode
      W32_SetAppDarkMode( .T. )
   endif

   // Harbour check moved to TBRun() — auto-download + build on first Run

   // Auto-generate icons if they don't exist yet
   if ! File( HB_DirBase() + "..\resources\palette_new.bmp" )
      W32_GeneratePaletteIcons( .T. )
   endif
   if ! File( HB_DirBase() + "..\resources\toolbar_new.bmp" )
      W32_GenerateToolbarIcons( .T. )
   endif

   nScreenW := W32_GetScreenWidth()
   nScreenH := W32_GetScreenHeight()
   cCurrentFile := ""
   aForms := {}
   nActiveForm := 0

   // C++Builder classic proportions scaled to current screen
   // Reference: 1024x768 -> Inspector 250px (24.4%), Bar 140px
   nBarH    := 160                           // title + menu + 2 toolbars(40+40) + palette
   nInsW    := Max( 270, Int( nScreenW * 0.18 ) )  // at least 270px to show property values

   // === Window 1: Main Bar (full screen width) ===
   cCompLabel := "Visual IDE for Harbour"

   DEFINE FORM oIDE TITLE "HbBuilder 1.0 - " + cCompLabel ;
      SIZE nScreenW, nBarH FONT "Segoe UI", 12 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()
   W32_BringToTop( UI_FormGetHwnd( oIDE:hCpp ) )

   // Enable dark mode for IDE windows (Windows 10/11)
   if lDarkMode
      W32_SetWindowDarkMode( UI_FormGetHwnd( oIDE:hCpp ), .T. )
      UI_FormSetBgColor( oIDE:hCpp, 45 + 45 * 256 + 48 * 65536 )
   endif

   // Inspector and editor: compensate DWM invisible borders (~8px each side)
   nInsTop  := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 10
   nEditorTop := nInsTop
   nEditorX := nInsW - 17
   nEditorW := nScreenW - nEditorX + 9      // cover right DWM border
   nBottomY := W32_GetWorkAreaHeight() + 16  // +16 to cover bottom DWM border
   nEditorH := nBottomY - nEditorTop

   // Form Designer: default position
   nFormX := 1129
   nFormY := 456

   // Menu bar
   DEFINE MENUBAR OF oIDE

   DEFINE POPUP oFile PROMPT "&File" OF oIDE
   MENUITEM "&New Application"       OF oFile ACTION TBNew()
   MENUITEM "New &Form"              OF oFile ACTION MenuNewForm()
   MENUSEPARATOR OF oFile
   MENUITEM "&Open..."               OF oFile ACTION TBOpen()
   MENUITEM "Reopen &Last Project"   OF oFile ACTION ReopenLastProject()
   MENUITEM "&Save"                  OF oFile ACTION TBSave()
   MENUITEM "Save &As..."            OF oFile ACTION TBSaveAs()
   MENUSEPARATOR OF oFile
   MENUITEM "E&xit"                  OF oFile ACTION oIDE:Close()

   DEFINE POPUP oEdit PROMPT "&Edit" OF oIDE
   MENUITEM "&Undo"  OF oEdit ACTION CodeEditorUndo( hCodeEditor )
   MENUITEM "&Redo"  OF oEdit ACTION CodeEditorRedo( hCodeEditor )
   MENUSEPARATOR OF oEdit
   MENUITEM "Cu&t"   OF oEdit ACTION CodeEditorCut( hCodeEditor )
   MENUITEM "&Copy"  OF oEdit ACTION CodeEditorCopy( hCodeEditor )
   MENUITEM "&Paste" OF oEdit ACTION CodeEditorPaste( hCodeEditor )
   MENUSEPARATOR OF oEdit
   MENUITEM "Undo &Design"     OF oEdit ACTION UndoDesign()
   MENUITEM "Cop&y Controls"   OF oEdit ACTION CopyControls()
   MENUITEM "Past&e Controls"  OF oEdit ACTION PasteControls()

   DEFINE POPUP oSearch PROMPT "&Search" OF oIDE
   MENUITEM "&Find..."        OF oSearch ACTION CodeEditorFind( hCodeEditor )
   MENUITEM "&Replace..."     OF oSearch ACTION CodeEditorReplace( hCodeEditor )
   MENUSEPARATOR OF oSearch
   MENUITEM "Find &Next"      OF oSearch ACTION CodeEditorFindNext( hCodeEditor )
   MENUITEM "Find &Previous"  OF oSearch ACTION CodeEditorFindPrev( hCodeEditor )
   MENUSEPARATOR OF oSearch
   MENUITEM "&Auto-Complete"  OF oSearch ACTION CodeEditorAutoComplete( hCodeEditor )

   DEFINE POPUP oView PROMPT "&View" OF oIDE
   MENUITEM "&Forms..."     OF oView ACTION MenuViewForms()
   MENUITEM "&Code Editor"  OF oView ACTION CodeEditorBringToFront( hCodeEditor )
   MENUITEM "&Inspector"       OF oView ACTION InspectorOpen()
   MENUITEM "&Project Inspector" OF oView ACTION ShowProjectInspector()
   MENUITEM "&Debugger"          OF oView ACTION W32_DebugPanel()

   DEFINE POPUP oProject PROMPT "&Project" OF oIDE
   MENUITEM "&Add to Project..."    OF oProject ACTION AddToProject()
   MENUITEM "&Remove from Project"  OF oProject ACTION RemoveFromProject()
   MENUSEPARATOR OF oProject
   MENUITEM "&Options..."           OF oProject ACTION ShowProjectOptions()

   DEFINE POPUP oRun PROMPT "&Run" OF oIDE
   MENUITEM "&Run"              OF oRun ACTION TBRun()
   MENUITEM "&Debug"            OF oRun ACTION TBDebugRun()
   MENUSEPARATOR OF oRun
   MENUITEM "Run on &Android..." OF oRun ACTION TBRunAndroid()
   MENUITEM "Android Setup &Wizard..." OF oRun ACTION AndroidSetupWizard()
   MENUSEPARATOR OF oRun
   MENUITEM "&Continue"      OF oRun ACTION IDE_DebugGo()
   MENUITEM "&Step Over"     OF oRun ACTION DebugStepOver()
   MENUITEM "Step &Into"     OF oRun ACTION DebugStepInto()
   MENUITEM "S&top"          OF oRun ACTION IDE_DebugStop()
   MENUSEPARATOR OF oRun
   MENUITEM "&Toggle Breakpoint"  OF oRun ACTION ToggleBreakpoint()
   MENUITEM "C&lear Breakpoints"  OF oRun ACTION ClearBreakpoints()

   DEFINE POPUP oFormat PROMPT "F&ormat" OF oIDE
   MENUITEM "Align &Left"              OF oFormat ACTION AlignControls( 1 )
   MENUITEM "Align &Right"             OF oFormat ACTION AlignControls( 2 )
   MENUITEM "Align &Top"               OF oFormat ACTION AlignControls( 3 )
   MENUITEM "Align &Bottom"            OF oFormat ACTION AlignControls( 4 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Center &Horizontally"     OF oFormat ACTION AlignControls( 5 )
   MENUITEM "Center &Vertically"       OF oFormat ACTION AlignControls( 6 )
   MENUSEPARATOR OF oFormat
   MENUITEM "Space Evenly Hori&zontal" OF oFormat ACTION AlignControls( 7 )
   MENUITEM "Space Evenly Ve&rtical"   OF oFormat ACTION AlignControls( 8 )
   MENUSEPARATOR OF oFormat
   MENUITEM "&Tab Order..."            OF oFormat ACTION TabOrderDialog()

   DEFINE POPUP oComp PROMPT "&Component" OF oIDE
   MENUITEM "&Install Component..." OF oComp ACTION InstallComponent()
   MENUITEM "&New Component..."     OF oComp ACTION NewComponent()

   DEFINE POPUP oTools PROMPT "&Tools" OF oIDE
   MENUITEM "&Editor Colors..." OF oTools ACTION ShowEditorSettings()
   MENUITEM "&Environment Options..." OF oTools ACTION ShowProjectOptions()
   MENUITEM "&Dark Mode"              OF oTools ACTION ToggleDarkMode()
   hToolsPopup := oTools:hPopup
   MENUSEPARATOR OF oTools
   MENUITEM "&AI Assistant..."        OF oTools ACTION ShowAIAssistant()
   MENUITEM "&Report Designer"        OF oTools ACTION OpenReportDesigner()
   MENUSEPARATOR OF oTools
   MENUITEM "&Select C Compiler..."     OF oTools ACTION SelectCompiler()
   MENUSEPARATOR OF oTools
   MENUITEM "&Generate Palette Icons" OF oTools ACTION ( W32_GeneratePaletteIcons( .F. ), W32_GenerateToolbarIcons( .F. ) )

   DEFINE POPUP oGit PROMPT "&Git" OF oIDE
   MENUITEM "&Init Repository"      OF oGit ACTION GitInit()
   MENUITEM "&Clone..."             OF oGit ACTION GitClone()
   MENUSEPARATOR OF oGit
   MENUITEM "&Status"               OF oGit ACTION GitShowPanel()
   MENUITEM "C&ommit..."            OF oGit ACTION GitCommit()
   MENUITEM "&Push"                 OF oGit ACTION GitPush()
   MENUITEM "Pu&ll"                 OF oGit ACTION GitPull()
   MENUSEPARATOR OF oGit
   MENUITEM "&Branch >  Create..."  OF oGit ACTION GitBranchCreate()
   MENUITEM "Branc&h >  Switch..."  OF oGit ACTION GitBranchSwitch()
   MENUITEM "Branch >  &Merge..."   OF oGit ACTION GitMerge()
   MENUSEPARATOR OF oGit
   MENUITEM "S&tash"                OF oGit ACTION GitStash()
   MENUITEM "Stash P&op"            OF oGit ACTION GitStashPop()
   MENUSEPARATOR OF oGit
   MENUITEM "&Log / History"        OF oGit ACTION GitLogShow()
   MENUITEM "&Diff"                 OF oGit ACTION GitDiffShow()
   MENUITEM "B&lame"                OF oGit ACTION GitBlameShow()

   DEFINE POPUP oHelp PROMPT "&Help" OF oIDE
   MENUITEM "&Documentation"        OF oHelp ACTION W32_OpenDocs( "en" )
   MENUITEM "&Quick Start"          OF oHelp ACTION W32_OpenDocs( "en/quickstart.html" )
   MENUITEM "&Controls Reference"   OF oHelp ACTION W32_OpenDocs( "en/controls-standard.html" )
   MENUSEPARATOR OF oHelp
   MENUITEM "&About HbBuilder..."   OF oHelp ACTION ShowAbout()

   // Menu bitmaps (16x16 from Lazarus IDE icon set)
   cIcoDir := HB_DirBase() + "..\resources\menu_icons\"
   // File menu (0:New, 1:NewForm, -sep-, 3:Open, 4:Save, 5:SaveAs, -sep-, 7:Exit)
   UI_MenuSetBitmapByPos( oFile:hPopup, 0, cIcoDir + "menu_new.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 1, cIcoDir + "menu_new_form.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 3, cIcoDir + "menu_open.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 4, cIcoDir + "menu_open.png" )   // Reopen Last
   UI_MenuSetBitmapByPos( oFile:hPopup, 5, cIcoDir + "menu_save.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 6, cIcoDir + "menu_saveas.png" )
   UI_MenuSetBitmapByPos( oFile:hPopup, 8, cIcoDir + "menu_exit.png" )
   // Edit menu (0:Undo, 1:Redo, -sep-, 3:Cut, 4:Copy, 5:Paste, -sep-, 7:UndoDesign, 8:CopyCtrl, 9:PasteCtrl)
   UI_MenuSetBitmapByPos( oEdit:hPopup, 0, cIcoDir + "menu_undo.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 1, cIcoDir + "menu_redo.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 3, cIcoDir + "menu_cut.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 4, cIcoDir + "menu_copy.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 5, cIcoDir + "menu_paste.png" )
   UI_MenuSetBitmapByPos( oEdit:hPopup, 7, cIcoDir + "menu_edit_undo_design.png" )
   // Search menu (0:Find, 1:Replace, -sep-, 3:FindNext, 4:FindPrev, -sep-, 6:AutoComplete)
   UI_MenuSetBitmapByPos( oSearch:hPopup, 0, cIcoDir + "menu_search_find.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 1, cIcoDir + "menu_search_replace.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 3, cIcoDir + "menu_search_findnext.png" )
   UI_MenuSetBitmapByPos( oSearch:hPopup, 4, cIcoDir + "menu_search_findprev.png" )
   // View menu (0:Forms, 1:CodeEditor, 2:Inspector, 3:ProjInspector, 4:Debugger)
   UI_MenuSetBitmapByPos( oView:hPopup, 0, cIcoDir + "menu_view_forms.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 1, cIcoDir + "menu_view_editor.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 2, cIcoDir + "menu_view_inspector.png" )
   UI_MenuSetBitmapByPos( oView:hPopup, 3, cIcoDir + "menu_project_inspector.png" )
   // Project menu (0:Add, 1:Remove, -sep-, 3:Options)
   UI_MenuSetBitmapByPos( oProject:hPopup, 0, cIcoDir + "menu_project_add.png" )
   UI_MenuSetBitmapByPos( oProject:hPopup, 1, cIcoDir + "menu_project_remove.png" )
   UI_MenuSetBitmapByPos( oProject:hPopup, 3, cIcoDir + "menu_project_options.png" )
   // Run menu (0:Run, 1:Debug, -sep-, 3:Continue, 4:StepOver, 5:StepInto, 6:Stop, -sep-, 8:ToggleBP, 9:ClearBP)
   UI_MenuSetBitmapByPos( oRun:hPopup, 0, cIcoDir + "menu_run.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 1, cIcoDir + "menu_debug.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 3, cIcoDir + "menu_continue.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 4, cIcoDir + "menu_stepover.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 5, cIcoDir + "menu_stepinto.png" )
   UI_MenuSetBitmapByPos( oRun:hPopup, 6, cIcoDir + "menu_stop.png" )
   // Tools menu (0:EditorColors, 1:EnvOptions, 2:DarkMode, -sep-, 4:AI, 5:Report, -sep-, 7:GenIcons)
   UI_MenuSetBitmapByPos( oTools:hPopup, 0, cIcoDir + "menu_editor_colors.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 1, cIcoDir + "menu_environment_options.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 2, cIcoDir + "menu_darkmode.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 4, cIcoDir + "menu_ai.png" )
   UI_MenuSetBitmapByPos( oTools:hPopup, 5, cIcoDir + "menu_report.png" )
   // Git menu (0:Init, 1:Clone, -sep-, 3:Status, 4:Commit, 5:Push, 6:Pull, ...)
   UI_MenuSetBitmapByPos( oGit:hPopup, 0, cIcoDir + "menu_git_init.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 1, cIcoDir + "menu_git_clone.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 3, cIcoDir + "menu_git_status.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 4, cIcoDir + "menu_git_commit.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 5, cIcoDir + "menu_git_push.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 6, cIcoDir + "menu_git_pull.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 8, cIcoDir + "menu_git_branch.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 12, cIcoDir + "menu_git_stash.png" )
   UI_MenuSetBitmapByPos( oGit:hPopup, 14, cIcoDir + "menu_git_log.png" )
   // Help menu (0:Docs, 1:QuickStart, 2:Controls, -sep-, 4:About)
   UI_MenuSetBitmapByPos( oHelp:hPopup, 4, cIcoDir + "menu_about.png" )

   // Dark menu bar: convert items to owner-draw + NC paint for background
   if lDarkMode
      UI_MenuBarSetDark( oIDE:hCpp )
   endif
   // Set initial checkmark on Dark Mode menu item (position 2 in Tools popup)
   if lDarkMode
      W32_MenuCheck( hToolsPopup, 2, .T. )
   endif

   // Speedbar (toolbar with 28x28 icon-sized buttons)
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
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F9)"       ACTION TBRun()
   SEPARATOR OF oTB
   BUTTON "Form"  OF oTB TOOLTIP "Toggle Form/Code"      ACTION ToggleFormCode()

   // Load toolbar icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_ToolBarLoadImages( oTB:hCpp, HB_DirBase() + "..\resources\toolbar.bmp" )

   // Row 2: Debug speedbar (Run is already in row 1)
   DEFINE TOOLBAR oTB2 OF oIDE
   BUTTON "Debug" OF oTB2 TOOLTIP "Debug (F8)"              ACTION TBDebugRun()
   SEPARATOR OF oTB2
   BUTTON "Step"  OF oTB2 TOOLTIP "Step Into (F7)"          ACTION DebugStepInto()
   BUTTON "Over"  OF oTB2 TOOLTIP "Step Over (F8)"          ACTION DebugStepOver()
   BUTTON "Go"    OF oTB2 TOOLTIP "Continue (F5)"           ACTION IDE_DebugGo()
   BUTTON "Stop"  OF oTB2 TOOLTIP "Stop Debugging"          ACTION IDE_DebugStop()
   SEPARATOR OF oTB2
   BUTTON "Exit"  OF oTB2 TOOLTIP "Exit IDE"                ACTION oIDE:Close()

   // Load debug toolbar icons
   UI_ToolBarLoadImages( oTB2:hCpp, HB_DirBase() + "..\resources\toolbar_debug.bmp" )

   // Stack both toolbars vertically
   UI_StackToolBars( oIDE:hCpp )

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

   // Ensure form is visually above the editor
   W32_BringToTop( UI_FormGetHwnd( oDesignForm:hCpp ) )

   // Set up editor tabs: Project1.prg (tab 1) + Form1.prg (tab 2)
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
   CodeEditorAddTab( hCodeEditor, "Form1.prg" )
   // Sync form code AFTER Show() so Left/Top/Width/Height reflect actual position
   SyncDesignerToCode()
   CodeEditorSetTabText( hCodeEditor, 2, aForms[1][3] )
   CodeEditorSelectTab( hCodeEditor, 2 )  // Show Form1.prg initially

   // Tab change callback
   CodeEditorOnTabChange( hCodeEditor, { |hEd, nTab| OnEditorTabChange( hEd, nTab ) } )
   CodeEditorOnTextChange( hCodeEditor, { |hEd, nTab| OnEditorTextChange( hEd, nTab ) } )

   // === Window 2: Object Inspector (left column, below bar) ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )
   INS_SetOnEventDblClick( _InsGetData(), ;
      { |hCtrl, cEvent| OnEventDblClick( hCtrl, cEvent ) } )
   INS_SetOnPropChanged( _InsGetData(), ;
      { || SyncDesignerToCode(), ;
            InspectorPopulateCombo( oDesignForm:hCpp ) } )
   INS_SetPos( _InsGetData(), -8, nInsTop, nInsW + 8, nBottomY - nInsTop )

   WireDesignForm()

   // When IDE closes, destroy all secondary windows
   oIDE:OnClose := { || DestroyAllForms(), InspectorClose(), ;
                       CodeEditorDestroy( hCodeEditor ) }

   // Give focus to IDE bar so tooltips work immediately
   W32_SetFocus( UI_FormGetHwnd( oIDE:hCpp ) )

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

   // Win32 tab (C++Builder: native OS controls)
   nTab := oPal:AddTab( "Win32" )
   oPal:AddComp( nTab, "Fol",  "Folder",      33 )
   oPal:AddComp( nTab, "TV",   "TreeView",    20 )
   oPal:AddComp( nTab, "LV",   "ListView",    21 )
   oPal:AddComp( nTab, "PB",   "ProgressBar", 22 )
   oPal:AddComp( nTab, "RE",   "RichEdit",    23 )
   oPal:AddComp( nTab, "TB",   "TrackBar",    34 )
   oPal:AddComp( nTab, "UD",   "UpDown",      35 )
   oPal:AddComp( nTab, "DTP",  "DateTimePicker", 36 )
   oPal:AddComp( nTab, "MC",   "MonthCalendar",  37 )

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

   // Data Access tab (C++Builder: database components)
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

   // Data Controls tab (C++Builder: data-aware visual controls)
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

   // Threading tab (multithreading primitives)
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

   // Load palette icons (includes Connectivity language logos)
   UI_PaletteLoadImages( oPal:hCpp, HB_DirBase() + "..\resources\palette.bmp" )

return nil

static function CreateDesignForm( nX, nY )

   local cName, nIdx

   // Generate form name: Form1, Form2, Form3...
   nIdx := Len( aForms ) + 1
   cName := "Form" + LTrim( Str( nIdx ) )

   // Create new empty form (like C++Builder File > New > VCL Forms Application)
   DEFINE FORM oDesignForm TITLE cName SIZE 650, 421 FONT "Segoe UI", 12 SIZABLE
   UI_FormSetPos( oDesignForm:hCpp, nX, nY )
   if lDarkMode
      UI_FormSetBgColor( oDesignForm:hCpp, 45 + 45 * 256 + 45 * 65536 )
   endif

   // Register in project form list
   // { cName, oForm, cCode, nX, nY }
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
   for i := 1 to Len( aForms )
      cCode += "   local o" + aForms[i][1] + "   // AS T" + aForms[i][1] + e
   next
   cCode += e
   cCode += "   oApp := TApplication():New()" + e
   cCode += '   oApp:Title := "Project1"' + e

   for i := 1 to Len( aForms )
      cCode += "   o" + aForms[i][1] + " := T" + aForms[i][1] + "():New()" + e
      cCode += "   oApp:CreateForm( o" + aForms[i][1] + " )" + e
   next

   cCode += "   oApp:Run()" + e
   cCode += e
   cCode += "return" + e
   cCode += cSep

return cCode

// Generate initial form code (empty form, no controls)
static function GenerateFormCode( cName )
return RegenerateFormCode( cName, 0 )

// Regenerate form code from current designer state (two-way sync)
// Reads all properties from the live form and its children
static function RegenerateFormCode( cName, hForm )

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e
   local cClass := "T" + cName  // TForm1, TForm2...
   local i, nCount, hCtrl, cCtrlName, cCtrlClass, nType
   local nW, nH, nFL, nFT, cTitle, nClr, cAppTitle
   local nL, nT, nCW, nCH, cText, nCtrlClr
   local cDatas := "", cCreate := "", cEvents := ""
   local cExistingCode, aEvents, j, cEvName, cEvSuffix, cHandlerName
   local cVal, aHdrs, kk, nColCount, aColProps, nColW, nInterval
   local aCtrlMap := {}, cOf, hOwner, nPg, kk2, nLen0, cSlice

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
      PosTrace( "RegenerateFormCode " + cName + ": L=" + LTrim(Str(nFL)) + ;
                " T=" + LTrim(Str(nFT)) + " W=" + LTrim(Str(nW)) + ;
                " H=" + LTrim(Str(nH)) )
   else
      cTitle := cName
      nFL := 100; nFT := 100; nW := 400; nH := 300
      nClr   := 15790320  // 0x00F0F0F0
      cAppTitle := ""
   endif

   // First pass: collect every control's name keyed by its hCtrl pointer
   // so that for children of a TFolder we can emit
   // OF ::oFolderName:aPages[N] instead of OF Self.
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

   // Enumerate child controls
   if hForm != 0
      nCount := UI_GetChildCount( hForm )
      for i := 1 to nCount
         hCtrl := UI_GetChild( hForm, i )
         if hCtrl == 0; loop; endif

         cCtrlName  := AllTrim( UI_GetProp( hCtrl, "cName" ) )
         cCtrlClass := AllTrim( UI_GetProp( hCtrl, "cClassName" ) )
         nType      := UI_GetType( hCtrl )
         if Empty( cCtrlName ); cCtrlName := "ctrl" + LTrim(Str(i)); endif

         // Build OF clause: usually "Self", but if the control belongs
         // to a TFolder page we emit "::oFolderName:aPages[N]" so the
         // page ownership round-trips through Save / Open.
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

         // DATA declaration
         cDatas += "   DATA o" + cCtrlName + "   // " + cCtrlClass + e

         // Creation code in CreateForm
         nL := UI_GetProp( hCtrl, "nLeft" )
         nT := UI_GetProp( hCtrl, "nTop" )
         nCW := UI_GetProp( hCtrl, "nWidth" )
         nCH := UI_GetProp( hCtrl, "nHeight" )
         cText := UI_GetProp( hCtrl, "cText" )

         // Snapshot cCreate length so we can post-process only the
         // slice the do case below emits: replace "OF Self" with "OF
         // <cOf>" when the control belongs to a TFolder page.
         nLen0 := Len( cCreate )

         do case
            case nType == 1  // Label
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' SAY ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 2  // Edit
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GET ::o' + cCtrlName + ' VAR "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 3  // Button
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BUTTON ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 4  // CheckBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' CHECKBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + e
            case nType == 5  // ComboBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' COMBOBOX ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 6  // GroupBox
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GROUPBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 33  // Folder / TPageControl (CT_TABCONTROL2)
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' FOLDER ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aTabs" )
               if ! Empty( cVal )
                  cCreate += ' PROMPTS '
                  for kk := 1 to Len( hb_ATokens( cVal, "|" ) )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + hb_ATokens( cVal, "|" )[ kk ] + '"'
                  next
               endif
               cCreate += e
            case nType == 7  // ListBox
               cCreate += '   // ::o' + cCtrlName + ' (TListBox) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 8  // RadioButton
               cCreate += '   // ::o' + cCtrlName + ' (TRadioButton) "' + cText + '" at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + e
            case nType == 12  // BitBtn
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BUTTON ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 14  // Image
               cCreate += '   // ::o' + cCtrlName + ' (TImage) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 15  // Shape
               cCreate += '   // ::o' + cCtrlName + ' (TShape) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 16  // Bevel
               cCreate += '   // ::o' + cCtrlName + ' (TBevel) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 20  // TreeView
               cCreate += '   // ::o' + cCtrlName + ' (TTreeView) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 21  // ListView
               cCreate += '   // ::o' + cCtrlName + ' (TListView) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 22  // ProgressBar
               cCreate += '   // ::o' + cCtrlName + ' (TProgressBar) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 23  // RichEdit
               cCreate += '   // ::o' + cCtrlName + ' (TRichEdit) at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
            case nType == 9   // Memo
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' MEMO ::o' + cCtrlName + ' VAR "' + cText + '" OF Self SIZE ' + ;
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
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "cDataSource" )
               if ! Empty( cVal )
                  cCreate += '   ::o' + cCtrlName + ':cDataSource := "' + cVal + '"' + e
               endif
            otherwise
               if IsNonVisual( nType )
                  cCreate += '   COMPONENT ::o' + cCtrlName + ' TYPE ' + ;
                     ComponentTypeName( nType ) + ' OF Self  // ' + cCtrlClass + e
                  if nType == 53  // DBFTable
                     cVal := UI_GetProp( hCtrl, "cFileName" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':cFileName := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "cRDD" )
                     if ValType( cVal ) == "C" .and. ! Empty( cVal ) .and. Upper( cVal ) != "DBFCDX"
                        cCreate += '   ::o' + cCtrlName + ':cRDD := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "lActive" )
                     if ValType( cVal ) == "L" .and. cVal
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
                  endif
               else
                  cCreate += '   // ::o' + cCtrlName + ' (' + cCtrlClass + ') at ' + ;
                     LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                     LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
               endif
         endcase

         // Page ownership: rewrite "OF Self" to "OF ::oFolderN:aPages[N]"
         // for controls whose FPageOwner points at a TFolder.
         if cOf != "Self" .and. Len( cCreate ) > nLen0
            cSlice := SubStr( cCreate, nLen0 + 1 )
            cSlice := StrTran( cSlice, " OF Self ", " OF " + cOf + " " )
            cCreate := Left( cCreate, nLen0 ) + cSlice
         endif

         // Non-visual components don't support visual DATAs like nClrPane or oFont
         if ! IsNonVisual( nType )
            // nClrPane for any control (CLR_INVALID = -1 on 32-bit or 4294967295 on 64-bit)
            nCtrlClr := UI_GetProp( hCtrl, "nClrPane" )
            if nCtrlClr != -1 .and. nCtrlClr != 4294967295 .and. nCtrlClr > 0
               cCreate += '   ::o' + cCtrlName + ':nClrPane := ' + LTrim( Str( nCtrlClr ) ) + e
            endif

            // Emit oFont if non-default
            cVal := UI_GetProp( hCtrl, "oFont" )
            if ! Empty( cVal ) .and. cVal != "System,12" .and. cVal != "Segoe UI,9"
               cCreate += '   ::o' + cCtrlName + ':oFont := "' + cVal + '"' + e
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
            if cHandlerName $ cExistingCode
               // METHOD Button1Click() CLASS TForm1 -> emit ::Button1Click()
               // plain FUNCTION Button1Click         -> emit Button1Click( Self )
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
         if ( "function " + cHandlerName ) $ cExistingCode
            cEvents += "   ::" + cEvName + ;
               " := { || " + cHandlerName + "( Self ) }" + e
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
   // Scan the existing event-handler code for "METHOD <Name>() CLASS <cClass>"
   // implementations and auto-declare each one in the CLASS body. Without
   // that, calling ::<Name>() on a TForm1 instance throws "Message not
   // found" at runtime because the symbol was never registered on the
   // class. Also the link step needs the bare-function symbol, which the
   // class-method compilation provides, but dispatch needs the declaration.
   cCode += ScanMethodDeclarations( cExistingCode, cClass )
   cCode += e
   cCode += "   METHOD CreateForm()" + e
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
   cCode += '   ::FontName := "Segoe UI"' + e
   cCode += "   ::FontSize := 9" + e
   if nClr != 15790320  // non-default color
      cCode += "   ::Color  := " + LTrim(Str(nClr)) + e
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
   cCode += e
   cCode += "return nil" + e
   cCode += cSep

return cCode

// Save current editor text back to active form's code slot
static function SaveActiveFormCode()

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
      return nil
   endif

   // Read from the form's tab (tab index = nActiveForm + 1)
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

return cAll

// Double-click on event in inspector: generate METHOD handler
static function OnEventDblClick( hCtrl, cEvent )

   local cName, cClass, cHandler, cCode, e, cSep, nCursorOfs

   e := Chr(13) + Chr(10)
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
   cHandler := AllTrim( cName ) + SubStr( cEvent, 3 )  // skip "On"

   // Ensure we're on the form's tab in the editor
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

   // Refresh inspector to show handler name in Events tab
   InspectorRefresh( hCtrl )

return cHandler

// === Component drop from palette ===

static function OnComponentDrop( hForm, nType, nL, nT, nW, nH )

   local cName, nCount, hCtrl
   static aCnt := nil

   // Initialize counters on first call (indexed by control type)
   if aCnt == nil
      aCnt := Array( 120 )
      AFill( aCnt, 0 )
   endif

   // Auto-name the new control (C++Builder style: Button1, Button2...)
   if nType < 1 .or. nType > 119; return nil; endif
   aCnt[ nType ]++

   do case
      // Standard
      case nType == 1;  cName := "Label"          + LTrim(Str(aCnt[nType]))
      case nType == 2;  cName := "Edit"           + LTrim(Str(aCnt[nType]))
      case nType == 3;  cName := "Button"         + LTrim(Str(aCnt[nType]))
      case nType == 4;  cName := "CheckBox"       + LTrim(Str(aCnt[nType]))
      case nType == 5;  cName := "ComboBox"       + LTrim(Str(aCnt[nType]))
      case nType == 6;  cName := "GroupBox"       + LTrim(Str(aCnt[nType]))
      case nType == 7;  cName := "ListBox"        + LTrim(Str(aCnt[nType]))
      case nType == 8;  cName := "RadioButton"    + LTrim(Str(aCnt[nType]))
      case nType == 24; cName := "Memo"           + LTrim(Str(aCnt[nType]))
      case nType == 25; cName := "Panel"          + LTrim(Str(aCnt[nType]))
      case nType == 26; cName := "ScrollBar"      + LTrim(Str(aCnt[nType]))
      // Additional
      case nType == 12; cName := "BitBtn"         + LTrim(Str(aCnt[nType]))
      case nType == 14; cName := "Image"          + LTrim(Str(aCnt[nType]))
      case nType == 15; cName := "Shape"          + LTrim(Str(aCnt[nType]))
      case nType == 16; cName := "Bevel"          + LTrim(Str(aCnt[nType]))
      case nType == 27; cName := "SpeedButton"    + LTrim(Str(aCnt[nType]))
      case nType == 28; cName := "MaskEdit"       + LTrim(Str(aCnt[nType]))
      case nType == 29; cName := "StringGrid"     + LTrim(Str(aCnt[nType]))
      case nType == 30; cName := "ScrollBox"      + LTrim(Str(aCnt[nType]))
      case nType == 31; cName := "StaticText"     + LTrim(Str(aCnt[nType]))
      case nType == 32; cName := "LabeledEdit"    + LTrim(Str(aCnt[nType]))
      // Win32
      case nType == 20; cName := "TreeView"       + LTrim(Str(aCnt[nType]))
      case nType == 21; cName := "ListView"       + LTrim(Str(aCnt[nType]))
      case nType == 22; cName := "ProgressBar"    + LTrim(Str(aCnt[nType]))
      case nType == 23; cName := "RichEdit"       + LTrim(Str(aCnt[nType]))
      case nType == 33; cName := "Folder"         + LTrim(Str(aCnt[nType]))
      case nType == 34; cName := "TrackBar"       + LTrim(Str(aCnt[nType]))
      case nType == 35; cName := "UpDown"         + LTrim(Str(aCnt[nType]))
      case nType == 36; cName := "DateTimePicker"  + LTrim(Str(aCnt[nType]))
      case nType == 37; cName := "MonthCalendar"   + LTrim(Str(aCnt[nType]))
      // System
      case nType == 38; cName := "Timer"          + LTrim(Str(aCnt[nType]))
      case nType == 39; cName := "PaintBox"       + LTrim(Str(aCnt[nType]))
      // Dialogs
      case nType == 40; cName := "OpenDialog"     + LTrim(Str(aCnt[nType]))
      case nType == 41; cName := "SaveDialog"     + LTrim(Str(aCnt[nType]))
      case nType == 42; cName := "FontDialog"     + LTrim(Str(aCnt[nType]))
      case nType == 43; cName := "ColorDialog"    + LTrim(Str(aCnt[nType]))
      case nType == 44; cName := "FindDialog"     + LTrim(Str(aCnt[nType]))
      case nType == 45; cName := "ReplaceDialog"  + LTrim(Str(aCnt[nType]))
      // AI tab
      case nType == 46; cName := "OpenAI"         + LTrim(Str(aCnt[nType]))
      case nType == 47; cName := "Gemini"         + LTrim(Str(aCnt[nType]))
      case nType == 48; cName := "Claude"         + LTrim(Str(aCnt[nType]))
      case nType == 49; cName := "DeepSeek"       + LTrim(Str(aCnt[nType]))
      case nType == 50; cName := "Grok"           + LTrim(Str(aCnt[nType]))
      case nType == 51; cName := "Ollama"         + LTrim(Str(aCnt[nType]))
      case nType == 52; cName := "Transformer"    + LTrim(Str(aCnt[nType]))
      case nType == 110; cName := "Whisper"       + LTrim(Str(aCnt[nType]))
      case nType == 111; cName := "Embeddings"    + LTrim(Str(aCnt[nType]))
      // Connectivity tab
      case nType == 112; cName := "Python"        + LTrim(Str(aCnt[nType]))
      case nType == 113; cName := "Swift"         + LTrim(Str(aCnt[nType]))
      case nType == 114; cName := "Go"            + LTrim(Str(aCnt[nType]))
      case nType == 115; cName := "Node"          + LTrim(Str(aCnt[nType]))
      case nType == 116; cName := "Rust"          + LTrim(Str(aCnt[nType]))
      case nType == 117; cName := "Java"          + LTrim(Str(aCnt[nType]))
      case nType == 118; cName := "DotNet"        + LTrim(Str(aCnt[nType]))
      case nType == 119; cName := "Lua"           + LTrim(Str(aCnt[nType]))
      case nType == 120; cName := "Ruby"          + LTrim(Str(aCnt[nType]))
      // Source Control tab
      case nType == 121; cName := "GitRepo"       + LTrim(Str(aCnt[nType]))
      case nType == 122; cName := "GitCommit"     + LTrim(Str(aCnt[nType]))
      case nType == 123; cName := "GitBranch"     + LTrim(Str(aCnt[nType]))
      case nType == 124; cName := "GitLog"        + LTrim(Str(aCnt[nType]))
      case nType == 125; cName := "GitDiff"       + LTrim(Str(aCnt[nType]))
      case nType == 126; cName := "GitRemote"     + LTrim(Str(aCnt[nType]))
      case nType == 127; cName := "GitStash"      + LTrim(Str(aCnt[nType]))
      case nType == 128; cName := "GitTag"        + LTrim(Str(aCnt[nType]))
      case nType == 129; cName := "GitBlame"      + LTrim(Str(aCnt[nType]))
      case nType == 130; cName := "GitMerge"      + LTrim(Str(aCnt[nType]))
      // Data Access tab
      case nType == 53; cName := "DBFTable"       + LTrim(Str(aCnt[nType]))
      case nType == 54; cName := "MySQL"          + LTrim(Str(aCnt[nType]))
      case nType == 55; cName := "MariaDB"        + LTrim(Str(aCnt[nType]))
      case nType == 56; cName := "PostgreSQL"     + LTrim(Str(aCnt[nType]))
      case nType == 57; cName := "SQLite"         + LTrim(Str(aCnt[nType]))
      case nType == 58; cName := "Firebird"       + LTrim(Str(aCnt[nType]))
      case nType == 59; cName := "SQLServer"      + LTrim(Str(aCnt[nType]))
      case nType == 60; cName := "Oracle"         + LTrim(Str(aCnt[nType]))
      case nType == 61; cName := "MongoDB"        + LTrim(Str(aCnt[nType]))
      // Internet tab
      case nType == 62; cName := "WebView"        + LTrim(Str(aCnt[nType]))
      // Threading tab
      case nType == 63; cName := "Thread"         + LTrim(Str(aCnt[nType]))
      case nType == 64; cName := "Mutex"          + LTrim(Str(aCnt[nType]))
      case nType == 65; cName := "Semaphore"      + LTrim(Str(aCnt[nType]))
      case nType == 66; cName := "CriticalSection" + LTrim(Str(aCnt[nType]))
      case nType == 67; cName := "ThreadPool"     + LTrim(Str(aCnt[nType]))
      case nType == 68; cName := "AtomicInt"      + LTrim(Str(aCnt[nType]))
      case nType == 69; cName := "CondVar"        + LTrim(Str(aCnt[nType]))
      case nType == 70; cName := "Channel"        + LTrim(Str(aCnt[nType]))
      // Printing tab
      case nType == 102; cName := "Printer"       + LTrim(Str(aCnt[nType]))
      case nType == 103; cName := "Report"        + LTrim(Str(aCnt[nType]))
      case nType == 104; cName := "Labels"        + LTrim(Str(aCnt[nType]))
      case nType == 105; cName := "PrintPreview"  + LTrim(Str(aCnt[nType]))
      case nType == 106; cName := "PageSetup"     + LTrim(Str(aCnt[nType]))
      case nType == 107; cName := "PrintDialog"   + LTrim(Str(aCnt[nType]))
      case nType == 108; cName := "ReportViewer"  + LTrim(Str(aCnt[nType]))
      case nType == 109; cName := "BarcodePrinter" + LTrim(Str(aCnt[nType]))
      // ERP tab
      case nType == 90; cName := "Preprocessor"   + LTrim(Str(aCnt[nType]))
      case nType == 91; cName := "ScriptEngine"   + LTrim(Str(aCnt[nType]))
      case nType == 92; cName := "ReportDesigner"  + LTrim(Str(aCnt[nType]))
      case nType == 93; cName := "Barcode"        + LTrim(Str(aCnt[nType]))
      case nType == 94; cName := "PDFGenerator"   + LTrim(Str(aCnt[nType]))
      case nType == 95; cName := "ExcelExport"    + LTrim(Str(aCnt[nType]))
      case nType == 96; cName := "AuditLog"       + LTrim(Str(aCnt[nType]))
      case nType == 97; cName := "Permissions"    + LTrim(Str(aCnt[nType]))
      case nType == 98; cName := "Currency"       + LTrim(Str(aCnt[nType]))
      case nType == 99; cName := "TaxEngine"      + LTrim(Str(aCnt[nType]))
      case nType == 100; cName := "Dashboard"     + LTrim(Str(aCnt[nType]))
      case nType == 101; cName := "Scheduler"     + LTrim(Str(aCnt[nType]))
      // Data Controls tab
      case nType == 79; cName := "Browse"        + LTrim(Str(aCnt[nType]))
      case nType == 80; cName := "DBGrid"        + LTrim(Str(aCnt[nType]))
      case nType == 81; cName := "DBNavigator"   + LTrim(Str(aCnt[nType]))
      case nType == 82; cName := "DBText"        + LTrim(Str(aCnt[nType]))
      case nType == 83; cName := "DBEdit"        + LTrim(Str(aCnt[nType]))
      case nType == 84; cName := "DBComboBox"    + LTrim(Str(aCnt[nType]))
      case nType == 85; cName := "DBCheckBox"    + LTrim(Str(aCnt[nType]))
      case nType == 86; cName := "DBImage"       + LTrim(Str(aCnt[nType]))
      // Internet tab (networking)
      case nType == 71; cName := "WebServer"     + LTrim(Str(aCnt[nType]))
      case nType == 72; cName := "WebSocket"     + LTrim(Str(aCnt[nType]))
      case nType == 73; cName := "HttpClient"    + LTrim(Str(aCnt[nType]))
      case nType == 74; cName := "FtpClient"     + LTrim(Str(aCnt[nType]))
      case nType == 75; cName := "SmtpClient"    + LTrim(Str(aCnt[nType]))
      case nType == 76; cName := "TcpServer"     + LTrim(Str(aCnt[nType]))
      case nType == 77; cName := "TcpClient"     + LTrim(Str(aCnt[nType]))
      case nType == 78; cName := "UdpSocket"     + LTrim(Str(aCnt[nType]))
      otherwise;  return nil
   endcase

   // Set name on the new control (last child)
   nCount := UI_GetChildCount( hForm )
   hCtrl  := UI_GetChild( hForm, nCount )
   if hCtrl != 0
      UI_SetProp( hCtrl, "cName", cName )
   endif

   // Two-way: regenerate entire form code from designer state
   SyncDesignerToCode()

   // Refresh inspector and select the new component
   InspectorPopulateCombo( hForm )
   INS_ComboSelect( _InsGetData(), nCount )  // select last item (new component)
   InspectorRefresh( hCtrl )

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

   // When design form gets focus from another app, bring IDE to front
   // Uses WM_ACTIVATEAPP (not WM_ACTIVATE) to avoid blocking resize
   UI_FormSetActivateApp( oDesignForm:hCpp, { || RestoreAllIDEWindows() } )

return nil

// Two-way sync: regenerate code from designer state
static function SyncDesignerToCode()

   local cNewCode, cOldCode, cMethods, nPos, nPos2
   local cSep := "//" + Replicate( "-", 68 )

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
      return nil
   endif

   // Don't regenerate code while syncing from code editor
   if lSyncingFromCode
      return nil
   endif

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

   // Update stored code and editor tab. Guard against the re-entrant
   // loop: CodeEditorSetTabText fires OnEditorTextChange, which calls
   // RestoreFormFromCode, which destroys and recreates every child
   // control (losing any in-memory state the backend stores outside
   // the parsed code, like TDbfTable::FRDD set moments ago).
   aForms[ nActiveForm ][ 3 ] := cNewCode
   PosTrace( "SyncDesignerToCode setting editor tab, guard .t." )
   lSyncingFromCode := .t.
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, cNewCode )
   lSyncingFromCode := .f.
   PosTrace( "SyncDesignerToCode guard released" )

return nil

// Live sync: code editor -> form designer + inspector (debounced 500ms)
static function OnEditorTextChange( hEd, nTab )

   local nFormIdx, cCode, hForm

   HB_SYMBOL_UNUSED( hEd )

   PosTrace( "OnEditorTextChange fired nTab=" + LTrim(Str(nTab)) + ;
             " lSyncingFromCode=" + iif( lSyncingFromCode, "Y", "N" ) )

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

   cCode := CodeEditorGetTabText( hCodeEditor, nTab )
   if Empty( cCode )
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

// Editor tab changed: switch to the corresponding form
static function OnEditorTabChange( hEd, nTab )

   local nFormIdx

   // Tab 1 = Project1.prg (no form switch needed)
   // Tab 2+ = Form1.prg, Form2.prg...
   if nTab > 1
      nFormIdx := nTab - 1
      if nFormIdx != nActiveForm .and. nFormIdx <= Len( aForms )
         SwitchToForm( nFormIdx )
      endif
   endif

return nil

// === Multi-form management (C++Builder style) ===

// Switch active form: bring selected form to front
static function SwitchToForm( nIdx )

   if lSwitching; return nil; endif
   if nIdx < 1 .or. nIdx > Len( aForms )
      return nil
   endif

   lSwitching := .t.

   // Save current form's code from editor
   if nActiveForm > 0 .and. nActiveForm != nIdx
      SaveActiveFormCode()
   endif

   // Activate new form
   nActiveForm := nIdx
   oDesignForm := aForms[ nIdx ][ 2 ]
   UI_SetDesignForm( oDesignForm:hCpp )

   // Switch editor tab first (may trigger OnEditorTabChange, guarded by lSwitching)
   CodeEditorSelectTab( hCodeEditor, nIdx + 1 )

   // Refresh inspector
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   // Bring form to front LAST so it stays on top
   UI_FormBringToFront( oDesignForm:hCpp )

   lSwitching := .f.

return nil

// File > New Form: add a new form to the project
static function MenuNewForm()

   local nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop

   // Save current form code
   SaveActiveFormCode()

   // Hide current form (don't Close — that destroys the window)
   if nActiveForm > 0
      UI_FormHide( aForms[ nActiveForm ][ 2 ]:hCpp )
   endif

   // Calculate position (same as initial form, offset a bit)
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 3
   nEditorTop := nInsTop
   nEditorX := nInsW - 5
   nEditorW := nScreenW - nEditorX
   nEditorH := W32_GetWorkAreaHeight() - nEditorTop
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

// View > Forms...: show list dialog and switch
static function MenuViewForms()

   local aNames := {}, i, nSel

   for i := 1 to Len( aForms )
      AAdd( aNames, aForms[i][1] )
   next

   nSel := W32_SelectFromList( "Select a form", aNames )
   if nSel > 0
      SwitchToForm( nSel )
   endif

return nil

// Destroy all forms on exit
static function RefreshIDEToolbars()
   // Force repaint of IDE bar after running user app
   local hWnd := UI_FormGetHwnd( oIDE:hCpp )
   if hWnd != 0
      W32_InvalidateWindow( hWnd )
   endif
return nil

static function RestoreAllIDEWindows()
   // Bring all IDE windows to front and repaint toolbars
   W32_BringToTop( UI_FormGetHwnd( oIDE:hCpp ) )
   W32_InvalidateWindow( UI_FormGetHwnd( oIDE:hCpp ) )
   INS_BringToFront( _InsGetData() )
   CodeEditorBringToFront( hCodeEditor )
   if oDesignForm != nil
      W32_BringToTop( UI_FormGetHwnd( oDesignForm:hCpp ) )
   endif
return nil

static function DestroyAllForms()

   local i

   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next

return nil

// === Toolbar actions ===

// New Application: reset everything (like C++Builder File > New > Application)
static function TBNew()

   local i, nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop, nAns

   // Ask to save current work if there are forms open
   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before creating a new one?", "HbBuilder" )
      if nAns == 0  // Cancel
         return nil
      elseif nAns == 1  // Yes
         TBSave()
      endif
   endif

   // Destroy all existing forms
   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0

   // Calculate position for Form1
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 3
   nEditorTop := nInsTop
   nEditorX := nInsW - 5
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

// Restore visual controls on a design form by parsing the form .prg code
static function RestoreFormFromCode( hForm, cCode )

   local aLines, cLine, cTrim, i, nType, kk
   local nT, nL, nW, nH, cText, cName, hCtrl, cVal
   local nPos, nPos2, cTitle, nCh, cProp, cTypeStr
   local cFolderName, hFolder, nPageIdx, kkF, hChildN

   if Empty( cCode ) .or. hForm == 0
      return nil
   endif

   aLines := HB_ATokens( cCode, Chr(10) )

   for i := 1 to Len( aLines )
      cLine := aLines[i]
      cTrim := StrTran( AllTrim( cLine ), Chr(13), "" )

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
      if '::Width' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nWidth", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::Height' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nHeight", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
         loop
      endif
      if '::Left' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         nPos := Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) )
         UI_SetProp( hForm, "nLeft", nPos )
         PosTrace( "RestoreFormFromCode Left := " + LTrim( Str( nPos ) ) )
         loop
      endif
      if '::Top' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         nPos := Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) )
         UI_SetProp( hForm, "nTop", nPos )
         PosTrace( "RestoreFormFromCode Top  := " + LTrim( Str( nPos ) ) )
         loop
      endif
      if '::Color' $ cTrim .and. ':=' $ cTrim .and. ! "::o" $ cTrim
         UI_SetProp( hForm, "nClrPane", Val( AllTrim( SubStr( cTrim, At( ":=", cTrim ) + 2 ) ) ) )
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
            // Strip any trailing ':' the parser may leave behind
            if Right( cName, 1 ) == ":"; cName := Left( cName, Len( cName ) - 1 ); endif
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

      // OF ::oFolderN:aPages[N] -> set pending page owner BEFORE creating
      // so the new control auto-attaches to that page.
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
            // Parse PROMPTS "tab1", "tab2", ... -> aTabs ("tab1|tab2|...")
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
      endcase

      // Set the control name
      if hCtrl != 0
         UI_SetProp( hCtrl, "cName", cName )
      endif
   next

   // Second pass: apply property assignments like ::oCtrlName:prop := value
   nCh := UI_GetChildCount( hForm )
   for i := 1 to Len( aLines )
      cTrim := StrTran( AllTrim( aLines[i] ), Chr(13), "" )
      // Skip comments
      if Left( cTrim, 2 ) == "//"; loop; endif
      if ! ( Left( cTrim, 3 ) == "::o" ) .or. ! ( ":=" $ cTrim ); loop; endif
      // Must have a second ":" for the property (::oName:prop := value)
      nPos := At( ":", SubStr( cTrim, 4 ) )
      if nPos == 0; loop; endif
      cName := SubStr( cTrim, 4, nPos - 1 )
      cText := SubStr( cTrim, 4 + nPos )
      nPos2 := At( ":=", cText )
      if nPos2 == 0; loop; endif
      cProp := AllTrim( Left( cText, nPos2 - 1 ) )
      cText := AllTrim( SubStr( cText, nPos2 + 2 ) )

      // Only process known properties
      if ! ( cProp == "nClrPane" .or. cProp == "Color" .or. cProp == "cDataSource" .or. ;
             cProp == "nInterval" .or. cProp == "oFont" .or. ;
             cProp == "cFileName" .or. cProp == "cRDD" .or. cProp == "lActive" )
         loop
      endif

      // Find the control by name
      hCtrl := 0
      for kk := 1 to nCh
         if AllTrim( UI_GetProp( UI_GetChild( hForm, kk ), "cName" ) ) == cName
            hCtrl := UI_GetChild( hForm, kk )
            exit
         endif
      next
      if hCtrl == 0; loop; endif

      if cProp == "nClrPane" .or. cProp == "Color"
         UI_SetProp( hCtrl, "nClrPane", Val( cText ) )
      elseif cProp == "oFont"
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, "oFont", cText )
      elseif cProp == "cDataSource"
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, "cDataSource", cText )
      elseif cProp == "nInterval"
         UI_SetProp( hCtrl, "nInterval", Val( cText ) )
      elseif cProp == "cFileName" .or. cProp == "cRDD"
         // Strip surrounding quotes from string literal
         if Left( cText, 1 ) == '"'
            cText := SubStr( cText, 2, Len( cText ) - 2 )
         endif
         UI_SetProp( hCtrl, cProp, cText )
      elseif cProp == "lActive"
         UI_SetProp( hCtrl, "lActive", Upper( AllTrim( cText ) ) == ".T." )
      endif
   next

return nil

// Open Project: load a .hbp project file
static function TBOpen()

   local cFile, nAns

   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before opening?", "HbBuilder" )
      if nAns == 0  // Cancel
         return nil
      elseif nAns == 1  // Yes
         TBSave()
      endif
   endif

   cFile := W32_OpenFileDialog( "Open HbBuilder Project", "hbp" )
   if Empty( cFile ); return nil; endif

return OpenProjectFile( cFile )

// Load a .hbp project given an exact path. Shared by TBOpen (file dialog)
// and the File > Recent menu items.
static function OpenProjectFile( cFile )

   local cContent, cDir, aLines, i
   local cFormName, cFormCode, nFormX, nFormY
   local nInsW, nInsTop, nEditorTop, nEditorX, nEditorW, nEditorH

   if Empty( cFile ) .or. ! File( cFile )
      MsgInfo( "Project file not found: " + Chr(10) + cFile, "HbBuilder" )
      return nil
   endif

   cContent := MemoRead( cFile )
   if Empty( cContent )
      MsgInfo( "Could not read project: " + cFile )
      return nil
   endif

   cDir := Left( cFile, RAt( "\", cFile ) )

   // Destroy current forms
   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0

   // Clear editor tabs
   CodeEditorClearTabs( hCodeEditor )

   // Calculate form positions
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 3
   nEditorTop := nInsTop
   nEditorX := nInsW - 5
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop

   // Read project file: each line is a form name (Form1, Form2...)
   aLines := HB_ATokens( cContent, Chr(10) )

   // Load Project1.prg
   cFormCode := MemoRead( cDir + "Project1.prg" )
   if ! Empty( cFormCode )
      CodeEditorSetTabText( hCodeEditor, 1, cFormCode )
   endif

   // Load each form
   for i := 2 to Len( aLines )
      cFormName := AllTrim( StrTran( aLines[i], Chr(13), "" ) )
      if Empty( cFormName ); loop; endif

      // Read form code
      cFormCode := MemoRead( cDir + cFormName + ".prg" )
      if Empty( cFormCode ); loop; endif

      // Calculate position
      nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 ) + ( Len(aForms) ) * 20
      nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 ) + ( Len(aForms) ) * 20

      // Create design form and restore properties/controls from code
      CreateDesignForm( nFormX, nFormY )
      RestoreFormFromCode( oDesignForm:hCpp, cFormCode )
      oDesignForm:SetDesign( .t. )

      // Only show the first form; hide the rest
      if Len( aForms ) == 1
         oDesignForm:Show()
      else
         oDesignForm:Show()
         UI_FormHide( oDesignForm:hCpp )
      endif

      // Store the loaded code
      aForms[ Len(aForms) ][ 3 ] := cFormCode

      // Add editor tab
      CodeEditorAddTab( hCodeEditor, cFormName + ".prg" )
      CodeEditorSetTabText( hCodeEditor, Len(aForms) + 1, cFormCode )

      // Wire up
      UI_OnSelChange( oDesignForm:hCpp, ;
         { |hCtrl| OnDesignSelChange( hCtrl ) } )
      UI_FormOnComponentDrop( oDesignForm:hCpp, ;
         { |hForm, nType, nL, nT, nW, nH| OnComponentDrop( hForm, nType, nL, nT, nW, nH ) } )
      // Two-way: sync code + inspector when form is moved/resized.
      // Was wired in TBNew but missing here - that's why dragging the
      // design form after Open never updated ::Left / ::Top before save.
      oDesignForm:OnResize := { || SyncDesignerToCode(), ;
         InspectorRefresh( oDesignForm:hCpp ) }
   next

   // Activate first form
   if Len( aForms ) > 0
      nActiveForm := 1
      oDesignForm := aForms[1][2]
      UI_SetDesignForm( oDesignForm:hCpp )
      CodeEditorSelectTab( hCodeEditor, 2 )
      UI_FormBringToFront( oDesignForm:hCpp )
      InspectorRefresh( oDesignForm:hCpp )
      InspectorPopulateCombo( oDesignForm:hCpp )
   endif

   cCurrentFile := cFile
   AddRecentProject( cFile )

return nil

// --- File > Recent project list ------------------------------------------
// Persisted across sessions via IniWrite/IniRead under [Recent] File1..N.
// Capped at MAX_RECENT; most-recent-first order, deduped.
#define MAX_RECENT 8

static function AddRecentProject( cFile )
   local aList := GetRecentProjects()
   local nPos := AScan( aList, {|c| Upper( c ) == Upper( cFile ) } )
   if nPos > 0
      ADel( aList, nPos )
      ASize( aList, Len( aList ) - 1 )
   endif
   AAdd( aList, cFile )
   while Len( aList ) > MAX_RECENT
      ADel( aList, 1 )
      ASize( aList, Len( aList ) - 1 )
   enddo
   // Persist most-recent-first
   for nPos := 1 to MAX_RECENT
      if nPos <= Len( aList )
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
      if ! Empty( cVal ) .and. File( cVal )
         AAdd( aList, cVal )
      endif
   next
return aList   // oldest .. newest (so AAdd of a new one keeps newest last)

// File > Reopen Last Project - opens the most recent .hbp stored in
// [Recent]/File1. Silent no-op if the file no longer exists on disk.
static function ReopenLastProject()
   local aList := GetRecentProjects()
   local nAns
   if Empty( aList )
      MsgInfo( "No recent project. Use File > Open... first.", "HbBuilder" )
      return nil
   endif
   // Optional save prompt if forms are open (same policy as TBOpen)
   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before reopening?", "HbBuilder" )
      if nAns == 0; return nil; endif
      if nAns == 1; TBSave(); endif
   endif
return OpenProjectFile( ATail( aList ) )

// Global error handler. Shows a modal W32_BuildErrorDialog with the
// error class, description, operation, args and the Harbour call stack
// (captured via ProcName()/ProcLine()), then propagates Break so the
// runtime unwinds to the nearest BEGIN SEQUENCE / main event loop
// instead of leaving the IDE in a corrupt state.
static function IDE_ErrorHandler( oErr )

   local cMsg := "", i, n, cVal

   cMsg += "Class:       " + hb_CStr( oErr:ClassName() ) + Chr(10)
   cMsg += "Subsystem:   " + hb_CStr( oErr:SubSystem() ) + Chr(10)
   cMsg += "Code:        " + hb_CStr( oErr:GenCode ) + " / " + ;
                             hb_CStr( oErr:SubCode )   + Chr(10)
   cMsg += "Description: " + hb_CStr( oErr:Description ) + Chr(10)
   cMsg += "Operation:   " + hb_CStr( oErr:Operation ) + Chr(10)

   if ValType( oErr:Args ) == "A" .and. ! Empty( oErr:Args )
      cMsg += Chr(10) + "Arguments:" + Chr(10)
      for i := 1 to Len( oErr:Args )
         cVal := oErr:Args[i]
         cMsg += "  [" + LTrim( Str( i ) ) + "] (" + ValType( cVal ) + ") " + ;
                 hb_CStr( cVal ) + Chr(10)
      next
   endif

   cMsg += Chr(10) + "Call stack:" + Chr(10)
   n := 2   // skip this handler frame
   while ! Empty( ProcName( n ) )
      cMsg += "  " + PadR( ProcName( n ), 40 ) + ;
              " line " + LTrim( Str( ProcLine( n ) ) ) + ;
              "  (" + ProcFile( n ) + ")" + Chr(10)
      n += 1
      if n > 60; exit; endif
   enddo

   // Also append to a persistent log so the user can inspect later
   // without needing to copy the dialog text.
   AppendErrorLog( cMsg )

   W32_BuildErrorDialog( "Runtime Error", cMsg )

   // Unwind to the outer message loop instead of continuing with broken
   // state. The IDE's event loop keeps running; only the failing
   // operation is aborted.
   Break( oErr )

return nil

// Append position-related diagnostics to pos_trace.log. Short-lived,
// only used while we debug form save/restore.
static function PosTrace( cMsg )
   local nH := FOpen( "c:\HarbourBuilder\pos_trace.log", 2 )
   if nH == -1
      nH := FCreate( "c:\HarbourBuilder\pos_trace.log" )
   else
      FSeek( nH, 0, 2 )
   endif
   if nH != -1
      FWrite( nH, DToS( Date() ) + " " + Time() + "  " + cMsg + Chr(13) + Chr(10) )
      FClose( nH )
   endif
return nil

// Extract every "METHOD <Name>() CLASS <cClass>" implementation from
// cCode and return a block of "   METHOD <Name>()" declarations suitable
// for inclusion inside the CLASS body. Skips CreateForm which is
// already hardcoded. Returns "" if no user methods are found.
static function ScanMethodDeclarations( cCode, cClass )
   local cOut := "", e := Chr(10)
   local aLines, cLine, cTrim, cName, nPos, nPos2, i
   local cTag := "CLASS " + cClass
   if Empty( cCode ); return ""; endif
   aLines := hb_ATokens( cCode, e )
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

static function AppendErrorLog( cMsg )
   local nH := FOpen( "c:\HarbourBuilder\error_trace.log", 2 )
   local cStamp := DToS( Date() ) + " " + Time()
   if nH == -1
      nH := FCreate( "c:\HarbourBuilder\error_trace.log" )
   else
      FSeek( nH, 0, 2 )
   endif
   if nH != -1
      FWrite( nH, "=== " + cStamp + " ===" + Chr(13) + Chr(10) )
      FWrite( nH, cMsg + Chr(13) + Chr(10) )
      FClose( nH )
   endif
return nil
static function TBSave()

   local cDir, cFile, cHbp, i

   // Sync current form code. SyncDesignerToCode first so the live
   // designer state (including any post-Open form drag) is captured,
   // then SaveActiveFormCode picks up any manual edits in the editor.
   SyncDesignerToCode()
   SaveActiveFormCode()

   if Empty( cCurrentFile )
      cFile := W32_SaveFileDialog( "Save HbBuilder Project", "Project1.hbp", "hbp" )
      if Empty( cFile ); return nil; endif
      cCurrentFile := cFile
   endif

   // Project directory = same as .hbp file
   cDir := Left( cCurrentFile, RAt( "\", cCurrentFile ) )

   // Trace to log file
   LogTrace( "TBSave: file=[" + cCurrentFile + "] dir=[" + cDir + "]" )

   // Write .hbp file (project index)
   cHbp := "Project1" + Chr(10)
   for i := 1 to Len( aForms )
      cHbp += aForms[i][1] + Chr(10)
   next
   MemoWrit( cCurrentFile, cHbp )
   LogTrace( "  .hbp written" )

   // Write Project1.prg
   MemoWrit( cDir + "Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   LogTrace( "  Project1.prg written" )

   // Write each form .prg
   for i := 1 to Len( aForms )
      MemoWrit( cDir + aForms[i][1] + ".prg", aForms[i][3] )
      LogTrace( "  " + aForms[i][1] + ".prg written" )
   next

   LogTrace( "  Save complete." )

return nil

static function LogTrace( cMsg )

   local nH := FOpen( "c:\HarbourBuilder\save_trace.log", 2 )  // FO_READWRITE

   if nH == -1
      nH := FCreate( "c:\HarbourBuilder\save_trace.log" )
   else
      FSeek( nH, 0, 2 )  // seek to end
   endif
   if nH != -1
      FWrite( nH, cMsg + Chr(13) + Chr(10) )
      FClose( nH )
   endif

return nil

// Compiler registry: { { cId, cLabel, cClPath, cMsvcBase, cWinKitVer }, ... }

static function ScanCompilers()

   local aMsvcPaths, aWinKitVers, aMsvcVers, i, j, k, m, cBase, cCl, cYear, cEdition, cLabel
   local aYears, aEditions, aProgramDirs, aBccPaths, aMinGWPaths, cPDir, cMsvcVer

   aCompilers := {}

   // Scan MSVC installations
   aProgramDirs := { "c:\Program Files (x86)", "c:\Program Files" }
   aYears    := { "2022", "2019", "18" }
   aEditions := { "Community", "BuildTools", "Professional", "Enterprise" }

   // Find Windows SDK version (use newest)
   aWinKitVers := {}
   if File( "c:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um\windows.h" )
      AAdd( aWinKitVers, "10.0.26100.0" )
   endif
   if File( "c:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um\windows.h" )
      AAdd( aWinKitVers, "10.0.22621.0" )
   endif
   if File( "c:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0\um\windows.h" )
      AAdd( aWinKitVers, "10.0.19041.0" )
   endif

   for i := 1 to Len( aProgramDirs )
      cPDir := aProgramDirs[i]
      for j := 1 to Len( aYears )
         cYear := aYears[j]
         for k := 1 to Len( aEditions )
            cEdition := aEditions[k]
            // Scan for MSVC tool versions in this VS installation
            cBase := cPDir + "\Microsoft Visual Studio\" + cYear + "\" + cEdition + "\VC\Tools\MSVC"
            // Try known version numbers
            aMsvcVers := { "14.50.35717", "14.44.35207", "14.43.34808", ;
                                  "14.41.34120", "14.40.33807", "14.39.33519", ;
                                  "14.38.33130", "14.37.32822", "14.36.32532", ;
                                  "14.35.32215", "14.34.31933", "14.33.31629", ;
                                  "14.29.30133", "14.29.30037", "14.28.29910" }
            for m := 1 to Len( aMsvcVers )
               cMsvcVer := aMsvcVers[m]
               cCl := cBase + "\" + cMsvcVer + "\bin\Hostx86\x86\cl.exe"
               if File( cCl )
                  cLabel := "MSVC " + cYear + " " + cEdition + " (v" + cMsvcVer + ") 32-bit"
                  AAdd( aCompilers, { "msvc", cLabel, cCl, ;
                     cBase + "\" + cMsvcVer, ;
                     iif( Len(aWinKitVers) > 0, aWinKitVers[1], "" ) } )
               endif
            next
         next
      next
   next

   // Scan BCC
   aBccPaths := { "c:\bcc77c", "c:\bcc77", "c:\bcc82", "c:\borland\bcc55" }
   for i := 1 to Len( aBccPaths )
      if File( aBccPaths[i] + "\bin\bcc32.exe" )
         AAdd( aCompilers, { "bcc", "BCC (" + aBccPaths[i] + ") 32-bit", ;
            aBccPaths[i] + "\bin\bcc32.exe", aBccPaths[i], "" } )
      endif
   next

   // Scan MinGW 32-bit
   aMinGWPaths := { "c:\gcc85", "c:\mingw", "c:\mingw32", ;
      "c:\msys64\mingw32", "c:\msys64\mingw64", ;
      "c:\TDM-GCC-32", "c:\TDM-GCC-64" }
   for i := 1 to Len( aMinGWPaths )
      if File( aMinGWPaths[i] + "\bin\gcc.exe" )
         AAdd( aCompilers, { "mingw", "MinGW GCC (" + aMinGWPaths[i] + ") 32-bit", ;
            aMinGWPaths[i] + "\bin\gcc.exe", aMinGWPaths[i], "" } )
      endif
   next

return nil

static function DetectCompiler()

   // User selected a specific compiler
   if ! Empty( cSelectedCompiler )
      return cSelectedCompiler
   endif

   // Scan if not done yet
   if aCompilers == nil
      ScanCompilers()
   endif

   // Return first found (MSVC preferred, appears first)
   if Len( aCompilers ) > 0
      return aCompilers[1][1]
   endif

return ""

static function GetCompilerInfo()
   // Return the full info array for the active compiler
   if aCompilers == nil; ScanCompilers(); endif

   // User selected a specific compiler by index
   if nSelectedCompIdx > 0 .and. nSelectedCompIdx <= Len( aCompilers )
      return aCompilers[ nSelectedCompIdx ]
   endif

   // Auto: return first found
   if Len( aCompilers ) > 0
      return aCompilers[1]
   endif

return nil

static function SelectCompiler()

   local aOptions := {}, i, nSel

   if aCompilers == nil; ScanCompilers(); endif

   for i := 1 to Len( aCompilers )
      AAdd( aOptions, aCompilers[i][2] + ;
         iif( i == 1 .and. Empty(cSelectedCompiler), " [auto]", "" ) )
   next
   AAdd( aOptions, "Auto-detect (use first found)" + ;
      iif( Empty(cSelectedCompiler), " [active]", "" ) )

   if Len( aOptions ) <= 1
      MsgInfo( "No compiler found!" + Chr(10) + Chr(10) + ;
               "Install:" + Chr(10) + ;
               "- Visual Studio Build Tools (free): visualstudio.microsoft.com" + Chr(10) + ;
               "- Embarcadero BCC: embarcadero.com" + Chr(10) + ;
               "- MinGW/TDM-GCC: jmeubank.github.io/tdm-gcc/" )
      return nil
   endif

   nSel := W32_SelectFromList( "Select C Compiler", aOptions )

   if nSel > 0
      if nSel <= Len( aCompilers )
         cSelectedCompiler := aCompilers[nSel][1]
         nSelectedCompIdx  := nSel
         // Update IDE title bar
         UI_SetProp( oIDE:hCpp, "cText", "HbBuilder 1.0 - [" + aCompilers[nSel][2] + "]" )
      else
         cSelectedCompiler := ""
         nSelectedCompIdx  := 0
         UI_SetProp( oIDE:hCpp, "cText", "HbBuilder 1.0 - [Auto]" )
      endif
   endif

return nil

// Toggle between Design Form and Code Editor windows
static function ToggleFormCode()

   if oDesignForm == nil
      return nil
   endif

   if UI_FormIsVisible( oDesignForm:hCpp )
      // Form is visible - hide it and bring code editor to front
      UI_FormHide( oDesignForm:hCpp )
      CodeEditorBringToFront( hCodeEditor )
   else
      // Form is hidden - show it and bring to front
      UI_FormBringToFront( oDesignForm:hCpp )
   endif

return nil

// Run: compile and execute the project (C++Builder F9)
static function TBRun()

   local cBuildDir, cOutput, cLog, i, k, lError
   local cHbDir, cHbBin, cHbInc, cHbLib
   local cCDir, cCC, cLinker
   local cProjDir, cAllPrg, cCmd, cObjs
   local aCppFiles, cCppBase
   local cAllCode, nHash
   local cCompiler, cMsvcBase, cWinKit, cWinKitVer
   local cMsvcInc, cMsvcLib, cUcrtInc, cUmInc, cSharedInc, cUcrtLib, cUmLib
   local cRsp, cRspContent, aCI, cAppName, cAppTitle, cExePath
   static nLastHash := 0

   SaveActiveFormCode()
   SyncDesignerToCode()  // Ensure event bindings are up to date

   cBuildDir := "c:\hbbuilder_build"

   // Honour ::AppTitle from the main form: user's chosen app name
   // becomes the .exe name so what they ship matches the inspector.
   cAppTitle := ""
   if Len( aForms ) > 0 .and. aForms[1][2] != nil .and. aForms[1][2]:hCpp != 0
      cAppTitle := UI_GetProp( aForms[1][2]:hCpp, "cAppTitle" )
   endif
   cAppName := iif( ! Empty( cAppTitle ), AllTrim( cAppTitle ), "UserApp" )
   cExePath := cBuildDir + "\" + cAppName + ".exe"

   // Quick check: if nothing changed since last successful build, just run
   cAllCode := CodeEditorGetTabText( hCodeEditor, 1 )
   for i := 1 to Len( aForms )
      cAllCode += aForms[i][3]
   next
   // Include compiler and framework in hash so changes force rebuild
   cAllCode += DetectCompiler() + LTrim( Str( nSelectedCompIdx ) )
   cAllCode += MemoRead( "c:\HarbourBuilder\source\core\classes.prg" )
   // Include backend C++ sources so IDE-side backend updates force a rebuild
   cAllCode += MemoRead( "c:\HarbourBuilder\source\cpp\hbbridge.cpp" )
   cAllCode += MemoRead( "c:\HarbourBuilder\source\cpp\tform.cpp" )
   cAllCode += MemoRead( "c:\HarbourBuilder\source\cpp\tcontrol.cpp" )
   cAllCode += MemoRead( "c:\HarbourBuilder\source\cpp\tcontrols.cpp" )
   // Include this file too: the W32_ErrorDialog template + main.prg
   // assembly logic live here, so changes here must invalidate the cache.
   cAllCode += MemoRead( "c:\HarbourBuilder\source\hbbuilder_win.prg" )
   nHash := Len( cAllCode )
   for i := 1 to Min( Len( cAllCode ), 5000 )
      nHash := nHash + Asc( SubStr( cAllCode, i, 1 ) ) * i
   next
   if nHash == nLastHash .and. nLastHash != 0 .and. File( cExePath )
      W32_ShellExec( 'cmd /c start "" "' + cExePath + '"' )
      RefreshIDEToolbars()
      return nil
   endif
   cProjDir := "c:\HarbourBuilder"
   cLog     := ""
   lError   := .F.

   // Detect compiler from scanned list
   aCI := GetCompilerInfo()
   // Update title with compiler info on first build
   if aCI != nil
      UI_SetProp( oIDE:hCpp, "cText", "HbBuilder 1.0 - [" + aCI[2] + "]" )
   endif
   if aCI == nil
      ShowNoCompilerDialog()
      return nil
   endif

   cCompiler := aCI[1]  // "msvc" or "bcc"

   // Find Harbour installation (search multiple paths)
   cHbDir := FindHarbour( cCompiler )
   if Empty( cHbDir )
      cHbDir := EnsureHarbour( cCompiler, aCI )
      if Empty( cHbDir )
         return nil
      endif
   endif
   cHbInc := cHbDir + "\include"

   if cCompiler == "msvc"
      cMsvcBase  := aCI[4]  // e.g. "...\MSVC\14.29.30133"
      cWinKit    := "c:\Program Files (x86)\Windows Kits\10"
      cWinKitVer := aCI[5]  // e.g. "10.0.26100.0"
      cCC        := cMsvcBase + '\bin\Hostx86\x86\cl.exe'
      cLinker    := cMsvcBase + '\bin\Hostx86\x86\link.exe'
      cMsvcInc   := cMsvcBase + "\include"
      cMsvcLib   := cMsvcBase + "\lib\x86"
      cUcrtInc   := cWinKit + "\Include\" + cWinKitVer + "\ucrt"
      cUmInc     := cWinKit + "\Include\" + cWinKitVer + "\um"
      cSharedInc := cWinKit + "\Include\" + cWinKitVer + "\shared"
      cUcrtLib   := cWinKit + "\Lib\" + cWinKitVer + "\ucrt\x86"
      cUmLib     := cWinKit + "\Lib\" + cWinKitVer + "\um\x86"
      cHbBin := FindHarbourSub( cHbDir, "bin", "msvc", "harbour.exe" )
      cHbLib := FindHarbourSub( cHbDir, "lib", "msvc", "hbrtl.lib" )
   elseif cCompiler == "mingw"
      cCDir      := aCI[4]  // e.g. "c:\gcc85"
      cCC        := cCDir + "\bin\gcc.exe"
      cLinker    := cCDir + "\bin\g++.exe"
      cHbBin := FindHarbourSub( cHbDir, "bin", "mingw", "harbour.exe" )
      cHbLib := FindHarbourSub( cHbDir, "lib", "mingw", "libhbrtl.a" )
   else
      cCDir      := aCI[4]  // e.g. "c:\bcc77c"
      cCC        := cCDir + "\bin\bcc32.exe"
      cLinker    := cCDir + "\bin\ilink32.exe"
      cHbBin := FindHarbourSub( cHbDir, "bin", "bcc", "harbour.exe" )
      cHbLib := FindHarbourSub( cHbDir, "lib", "bcc", "hbrtl.lib" )
   endif
   cLog += "Compiler: " + aCI[2] + Chr(10)
   cLog += "Harbour bin: " + cHbBin + Chr(10)
   cLog += "Harbour lib: " + cHbLib + Chr(10)

   W32_ShellExec( 'cmd /c mkdir "' + cBuildDir + '" 2>nul' )
   // Delete old exe to avoid running stale builds
   W32_ShellExec( 'cmd /c del "' + cExePath + '" 2>nul' )
   W32_ShellExec( 'cmd /c del "' + cBuildDir + '\*.obj" 2>nul' )
   W32_ShellExec( 'cmd /c del "' + cBuildDir + '\*.o" 2>nul' )


   // Show progress dialog (7 steps)
   W32_ProgressOpen( "Building Project...", 7 )

   // Step 1: Save files
   W32_ProgressStep( "Saving project files..." )
   cLog += "[1] Saving project files..." + Chr(10)
   MemoWrit( cBuildDir + "\Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "\" + aForms[i][1] + ".prg", aForms[i][3] )
      cLog += "    " + aForms[i][1] + ".prg" + Chr(10)
   next
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\source\core\classes.prg" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\include\hbbuilder.ch" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\include\hbide.ch" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\resources\stddlgs.c" "' + cBuildDir + '\" >nul 2>&1' )

   // Step 2: Assemble main.prg
   W32_ProgressStep( "Assembling main.prg..." )
   cLog += "[2] Building main.prg..." + Chr(10)
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_GUI_DEFAULT" + Chr(10)
   // RDD drivers required by TDBFTable (cRDD = DBFCDX/DBFNTX/DBFFPT) and
   // RDDSYS so REQUEST is honored. Without these the user app links but
   // dbUseArea("DBFCDX",...) fails with EG_ARG/1015 - the driver name
   // is not registered with the RDD subsystem.
   cAllPrg += "REQUEST DBFCDX, DBFNTX, DBFFPT" + Chr(10)
   cAllPrg += "REQUEST RDDSYS" + Chr(10) + Chr(10)
   cAllPrg += StrTran( MemoRead( cBuildDir + "\Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += MemoRead( cBuildDir + "\" + aForms[i][1] + ".prg" ) + Chr(10)
   next
   // Add early DPI awareness (must be before any window creation)
   cAllPrg += Chr(10)
   cAllPrg += "INIT PROCEDURE _InitDPI()" + Chr(10)
   cAllPrg += "   SetDPIAware()" + Chr(10)
   cAllPrg += "return" + Chr(10)
   // Platform stubs for macOS/Linux functions referenced by classes.prg
   cAllPrg += '#pragma BEGINDUMP' + Chr(10)
   cAllPrg += '#include <hbapi.h>' + Chr(10)
   cAllPrg += '#include <windows.h>' + Chr(10)
   cAllPrg += 'HB_FUNC( UI_MEMONEW )        { hb_retnint( 0 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( UI_MSGBOX )         { MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "App", 0x40 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( UI_MSGYESNO )      { hb_retl( MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "Confirm", 0x24 ) == 6 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( MAC_RUNTIMEERRORDIALOG ) { hb_retni( 0 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( MAC_APPTERMINATE )  { }' + Chr(10)
   cAllPrg += 'HB_FUNC( W32_ERRORDIALOG ) {' + Chr(10)
   cAllPrg += '  const char * raw = hb_parc(1);' + Chr(10)
   cAllPrg += '  char msg[16384]; int ri, mi = 0;' + Chr(10)
   cAllPrg += '  /* Normalize LF -> CRLF so MessageBox lays out lines correctly. */' + Chr(10)
   cAllPrg += '  for( ri = 0; raw && raw[ri] && mi < (int)sizeof(msg) - 2; ri++ ) {' + Chr(10)
   cAllPrg += '    if( raw[ri] == 0x0A && ( ri == 0 || raw[ri-1] != 0x0D ) )' + Chr(10)
   cAllPrg += '      msg[mi++] = 0x0D;' + Chr(10)
   cAllPrg += '    msg[mi++] = raw[ri];' + Chr(10)
   cAllPrg += '  }' + Chr(10)
   cAllPrg += '  msg[mi] = 0;' + Chr(10)
   cAllPrg += '  /* Native MessageBox: DPI-aware, kernel-managed dialog. Vista+' + Chr(10)
   cAllPrg += '     supports Ctrl+C to copy contents to the clipboard. Avoids' + Chr(10)
   cAllPrg += '     the previous custom GetMessage-pump-inside-a-callback path' + Chr(10)
   cAllPrg += '     that occasionally corrupted the desktop image under DPI. */' + Chr(10)
   cAllPrg += '  /* Custom dialog: EDIT with the formatted text + Copy button +' + Chr(10)
   cAllPrg += '     OK. MessageBoxA was tried but in some configurations did not' + Chr(10)
   cAllPrg += '     show on top of the user form, so we use our own window. */' + Chr(10)
   cAllPrg += '  { HWND hDlg, hEdit, hOK, hCopy;' + Chr(10)
   cAllPrg += '    MSG m; HFONT hF, hFMono;' + Chr(10)
   cAllPrg += '    int sw = GetSystemMetrics(SM_CXSCREEN);' + Chr(10)
   cAllPrg += '    int sh = GetSystemMetrics(SM_CYSCREEN);' + Chr(10)
   cAllPrg += '    int W = 1000, H = 700, X = (sw-W)/2, Y = (sh-H)/2;' + Chr(10)
   cAllPrg += '    int btnH = 36, btnY = H - btnH - 60;' + Chr(10)
   cAllPrg += '  hDlg = CreateWindowExA(WS_EX_DLGMODALFRAME|WS_EX_TOPMOST,"#32770","Runtime Error",' + Chr(10)
   cAllPrg += '    WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_VISIBLE,' + Chr(10)
   cAllPrg += '    X,Y,W,H,NULL,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  hF = (HFONT)GetStockObject(DEFAULT_GUI_FONT);' + Chr(10)
   cAllPrg += '  hFMono = CreateFontA(-16,0,0,0,FW_NORMAL,0,0,0,DEFAULT_CHARSET,0,0,DEFAULT_QUALITY,FIXED_PITCH|FF_MODERN,"Consolas");' + Chr(10)
   cAllPrg += '  if (!hFMono) hFMono = (HFONT)GetStockObject(ANSI_FIXED_FONT);' + Chr(10)
   cAllPrg += '  hEdit = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",msg,' + Chr(10)
   cAllPrg += '    WS_CHILD|WS_VISIBLE|WS_VSCROLL|WS_HSCROLL|ES_MULTILINE|ES_READONLY|ES_AUTOVSCROLL|ES_AUTOHSCROLL,' + Chr(10)
   cAllPrg += '    8,8,W-24,btnY-16,hDlg,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  SendMessage(hEdit,WM_SETFONT,(WPARAM)hFMono,TRUE);' + Chr(10)
   cAllPrg += '  hCopy = CreateWindowExA(0,"BUTTON","Copy to clipboard",' + Chr(10)
   cAllPrg += '    WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,' + Chr(10)
   cAllPrg += '    8,btnY,200,btnH,hDlg,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  SendMessage(hCopy,WM_SETFONT,(WPARAM)hF,TRUE);' + Chr(10)
   cAllPrg += '  hOK = CreateWindowExA(0,"BUTTON","OK",' + Chr(10)
   cAllPrg += '    WS_CHILD|WS_VISIBLE|BS_DEFPUSHBUTTON,' + Chr(10)
   cAllPrg += '    W-130,btnY,110,btnH,hDlg,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  SendMessage(hOK,WM_SETFONT,(WPARAM)hF,TRUE);' + Chr(10)
   cAllPrg += '  SetForegroundWindow(hDlg);' + Chr(10)
   cAllPrg += '  while(GetMessage(&m,NULL,0,0)) {' + Chr(10)
   cAllPrg += '    TranslateMessage(&m); DispatchMessage(&m);' + Chr(10)
   cAllPrg += '    if(m.message==WM_LBUTTONUP && m.hwnd==hOK) break;' + Chr(10)
   cAllPrg += '    if(m.message==WM_LBUTTONUP && m.hwnd==hCopy) {' + Chr(10)
   cAllPrg += '      size_t len = strlen(msg) + 1;' + Chr(10)
   cAllPrg += '      if(OpenClipboard(hDlg)) {' + Chr(10)
   cAllPrg += '        HGLOBAL hg = GlobalAlloc(GMEM_MOVEABLE, len);' + Chr(10)
   cAllPrg += '        if(hg) { char * dst=(char*)GlobalLock(hg); memcpy(dst,msg,len); GlobalUnlock(hg);' + Chr(10)
   cAllPrg += '                 EmptyClipboard(); SetClipboardData(CF_TEXT,hg); }' + Chr(10)
   cAllPrg += '        CloseClipboard();' + Chr(10)
   cAllPrg += '        SetWindowTextA(hCopy,"Copied!");' + Chr(10)
   cAllPrg += '      }' + Chr(10)
   cAllPrg += '    }' + Chr(10)
   cAllPrg += '    if(m.message==WM_KEYDOWN && m.wParam==VK_ESCAPE) break;' + Chr(10)
   cAllPrg += '    if(m.message==WM_CLOSE || m.message==WM_DESTROY) break;' + Chr(10)
   cAllPrg += '  }' + Chr(10)
   cAllPrg += '  if(hFMono) DeleteObject(hFMono);' + Chr(10)
   cAllPrg += '  DestroyWindow(hDlg);' + Chr(10)
   cAllPrg += '  }' + Chr(10)
   cAllPrg += '  /* QUIT does not break the form GetMessage loop on Win32,' + Chr(10)
   cAllPrg += '     so the user app process kept running silently after the' + Chr(10)
   cAllPrg += '     error dialog was dismissed. ExitProcess terminates it. */' + Chr(10)
   cAllPrg += '  ExitProcess(1);' + Chr(10)
   cAllPrg += '}' + Chr(10)
   cAllPrg += '#pragma ENDDUMP' + Chr(10)
   MemoWrit( cBuildDir + "\main.prg", cAllPrg )

   // Step 3: Compile user code with Harbour
   if ! lError
      W32_ProgressStep( "Compiling Harbour code..." )
      cLog += "[3] Compiling main.prg..." + Chr(10)
      cCmd := cHbBin + '\harbour.exe ' + cBuildDir + '\main.prg /n /w /q' + ;
              " /i" + cHbInc + " /i" + cBuildDir + ;
              " /o" + cBuildDir + "\main.c"
      cOutput := W32_ShellExec( cCmd )
      if "Error" $ cOutput
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 4: Compile framework
   if ! lError
      W32_ProgressStep( "Compiling framework..." )
      cLog += "[4] Compiling framework..." + Chr(10)
      cCmd := cHbBin + '\harbour.exe ' + cBuildDir + '\classes.prg /n /w /q' + ;
              " /i" + cHbInc + " /i" + cBuildDir + ;
              " /o" + cBuildDir + "\classes.c"
      W32_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 5: Compile C sources (compiler-specific)
   if ! lError
      W32_ProgressStep( "Compiling C sources..." )
      cLog += "[5] Compiling C sources..." + Chr(10)
      if cCompiler == "msvc"
         // Use response file for cl.exe (avoids quoting issues with spaces in paths)
         cRspContent := "/c /O2 /W0 /EHsc" + Chr(10)
         cRspContent += '/I"' + cHbInc + '"' + Chr(10)
         cRspContent += '/I"' + cMsvcInc + '"' + Chr(10)
         cRspContent += '/I"' + cUcrtInc + '"' + Chr(10)
         cRspContent += '/I"' + cUmInc + '"' + Chr(10)
         cRspContent += '/I"' + cSharedInc + '"' + Chr(10)
         cRspContent += '/I"' + cProjDir + '\include"' + Chr(10)

         cRsp := cBuildDir + "\cl_main.rsp"
         MemoWrit( cRsp, cRspContent + '"' + cBuildDir + '\main.c"' + Chr(10) + '/Fo"' + cBuildDir + '\main.obj"' )
         cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
         cOutput := W32_ShellExec( cCmd )
         if "error" $ Lower( cOutput )
            cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
            lError := .T.
         endif
         if ! lError
            cRsp := cBuildDir + "\cl_classes.rsp"
            MemoWrit( cRsp, cRspContent + '"' + cBuildDir + '\classes.c"' + Chr(10) + '/Fo"' + cBuildDir + '\classes.obj"' )
            cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
            W32_ShellExec( cCmd )
         endif
         if ! lError .and. File( cBuildDir + "\stddlgs.c" )
            cRsp := cBuildDir + "\cl_stddlgs.rsp"
            MemoWrit( cRsp, cRspContent + '"' + cBuildDir + '\stddlgs.c"' + Chr(10) + '/Fo"' + cBuildDir + '\stddlgs.obj"' )
            cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
            W32_ShellExec( cCmd )
         endif
      elseif cCompiler == "mingw"
         cCmd := cCC + ' -c -O2 -I' + cHbInc + ;
                 " -I" + cProjDir + "\include" + ;
                 " " + cBuildDir + "\main.c" + ;
                 " -o " + cBuildDir + "\main.o"
         cOutput := W32_ShellExec( cCmd )
         if "error" $ Lower( cOutput )
            cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
            lError := .T.
         endif
         if ! lError
            cCmd := cCC + ' -c -O2 -I' + cHbInc + ;
                    " -I" + cProjDir + "\include" + ;
                    " " + cBuildDir + "\classes.c" + ;
                    " -o " + cBuildDir + "\classes.o"
            W32_ShellExec( cCmd )
         endif
         if ! lError .and. File( cBuildDir + "\stddlgs.c" )
            cCmd := cCC + ' -c -O2 -I' + cHbInc + ;
                    " -I" + cProjDir + "\include" + ;
                    " " + cBuildDir + "\stddlgs.c" + ;
                    " -o " + cBuildDir + "\stddlgs.o"
            W32_ShellExec( cCmd )
         endif
      else
         cCmd := cCC + ' -c -O2 -tW -I' + cHbInc + ;
                 " -I" + cCDir + "\include" + ;
                 " -I" + cProjDir + "\include" + ;
                 " " + cBuildDir + "\main.c" + ;
                 " -o" + cBuildDir + "\main.obj"
         cOutput := W32_ShellExec( cCmd )
         if "Error" $ cOutput
            cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
            lError := .T.
         endif
         cCmd := cCC + ' -c -O2 -tW -I' + cHbInc + ;
                 " -I" + cCDir + "\include" + ;
                 " -I" + cProjDir + "\include" + ;
                 " " + cBuildDir + "\classes.c" + ;
                 " -o" + cBuildDir + "\classes.obj"
         W32_ShellExec( cCmd )
         if File( cBuildDir + "\stddlgs.c" )
            cCmd := cCC + ' -c -O2 -tW -I' + cHbInc + ;
                    " -I" + cCDir + "\include" + ;
                    " -I" + cProjDir + "\include" + ;
                    " " + cBuildDir + "\stddlgs.c" + ;
                    " -o" + cBuildDir + "\stddlgs.obj"
            W32_ShellExec( cCmd )
         endif
      endif
      if ! lError; cLog += "    OK" + Chr(10); endif
   endif

   // Step 6: Compile C++ core
   if ! lError
      W32_ProgressStep( "Compiling C++ core..." )
      cLog += "[6] Compiling C++ core..." + Chr(10)
      aCppFiles := { "tcontrol", "tform", "tcontrols", "hbbridge" }
      if cCompiler == "msvc"
         cCppBase := "/c /O2 /W0 /EHsc" + Chr(10) + ;
                 '/I"' + cHbInc + '"' + Chr(10) + ;
                 '/I"' + cMsvcInc + '"' + Chr(10) + ;
                 '/I"' + cUcrtInc + '"' + Chr(10) + ;
                 '/I"' + cUmInc + '"' + Chr(10) + ;
                 '/I"' + cSharedInc + '"' + Chr(10) + ;
                 '/I"' + cProjDir + '\include"' + Chr(10)
      elseif cCompiler == "mingw"
         cCppBase := " -c -O2 -I" + cHbInc + ;
                 " -I" + cProjDir + "\include "
      else
         cCppBase := " -c -O2 -tW -w- -I" + cHbInc + ;
                 " -I" + cCDir + "\include" + ;
                 " -I" + cProjDir + "\include "
      endif
      for k := 1 to Len( aCppFiles )
         if cCompiler == "msvc"
            cRsp := cBuildDir + "\cl_" + aCppFiles[k] + ".rsp"
            MemoWrit( cRsp, cCppBase + '"' + cProjDir + "\source\cpp\" + aCppFiles[k] + '.cpp"' + Chr(10) + ;
                     '/Fo"' + cBuildDir + "\" + aCppFiles[k] + '.obj"' )
            cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
         elseif cCompiler == "mingw"
            cCmd := cCDir + "\bin\g++.exe" + cCppBase + ;
                    cProjDir + "\source\cpp\" + aCppFiles[k] + ".cpp" + ;
                    " -o " + cBuildDir + "\" + aCppFiles[k] + ".o"
         else
            cCmd := cCC + cCppBase + ;
                    cProjDir + "\source\cpp\" + aCppFiles[k] + ".cpp" + ;
                    " -o" + cBuildDir + "\" + aCppFiles[k] + ".obj"
         endif
         cOutput := W32_ShellExec( cCmd )
         if "error" $ Lower( cOutput )
            cLog += "    FAILED (" + aCppFiles[k] + "):" + Chr(10) + cOutput + Chr(10)
            lError := .T.
            exit
         endif
      next
      if ! lError; cLog += "    OK" + Chr(10); endif
   endif

   // Step 7: Link
   if ! lError
      W32_ProgressStep( "Linking executable..." )
      cLog += "[7] Linking..." + Chr(10)
      if cCompiler == "mingw"
         cObjs := cBuildDir + "\main.o " + ;
                  cBuildDir + "\classes.o " + ;
                  cBuildDir + "\tcontrol.o " + ;
                  cBuildDir + "\tform.o " + ;
                  cBuildDir + "\tcontrols.o " + ;
                  cBuildDir + "\hbbridge.o"
         if File( cBuildDir + "\stddlgs.o" )
            cObjs += " " + cBuildDir + "\stddlgs.o"
         endif
      else
         cObjs := cBuildDir + "\main.obj " + ;
                  cBuildDir + "\classes.obj " + ;
                  cBuildDir + "\tcontrol.obj " + ;
                  cBuildDir + "\tform.obj " + ;
                  cBuildDir + "\tcontrols.obj " + ;
                  cBuildDir + "\hbbridge.obj"
         if File( cBuildDir + "\stddlgs.obj" )
            cObjs += " " + cBuildDir + "\stddlgs.obj"
         endif
      endif
      if cCompiler == "msvc"
         // Write link response file (avoids cmd line length/quoting issues)
         cRsp := cBuildDir + "\link.rsp"
         cRspContent := ""
         cRspContent += "/NOLOGO /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT" + Chr(10)
         cRspContent += '/OUT:"' + cExePath + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cMsvcLib + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cUcrtLib + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cUmLib + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cHbLib + '"' + Chr(10)
         cRspContent += cObjs + Chr(10)
         cRspContent += "hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib" + Chr(10)
         cRspContent += "hbmacro.lib hbpp.lib hbcommon.lib hbcplr.lib hbct.lib" + Chr(10)
         cRspContent += "hbhsx.lib hbsix.lib hbusrrdd.lib" + Chr(10)
         cRspContent += "rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib" + Chr(10)
         cRspContent += "hbdebug.lib hbpcre.lib hbzlib.lib" + Chr(10)
         cRspContent += "hbsqlit3.lib sqlite3.lib" + Chr(10)
         cRspContent += "gtwin.lib gtwvt.lib gtgui.lib" + Chr(10)
         cRspContent += "user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib" + Chr(10)
         cRspContent += "ole32.lib oleaut32.lib advapi32.lib ws2_32.lib winmm.lib" + Chr(10)
         cRspContent += "msimg32.lib gdiplus.lib iphlpapi.lib ucrt.lib vcruntime.lib msvcrt.lib" + Chr(10)
         MemoWrit( cRsp, cRspContent )
         cCmd := 'cmd /S /c ""' + cLinker + '" @"' + cRsp + '" 2>&1"'
      elseif cCompiler == "mingw"
         cCmd := cLinker + " -static -mwindows -o " + cExePath + ;
                 " " + cObjs + ;
                 " -L" + cHbLib + ;
                 " -Wl,--start-group" + ;
                 " -lhbvm -lhbrtl -lhbcommon -lhblang -lhbrdd" + ;
                 " -lhbmacro -lhbpp -lhbcpage -lhbcplr -lhbct" + ;
                 " -lhbhsx -lhbsix -lhbusrrdd" + ;
                 " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
                 " -lhbdebug -lhbpcre -lhbzlib" + ;
                 " -lhbsqlit3 -lsqlite3" + ;
                 " -lgtgui -lgtwin -lgtwvt" + ;
                 " -Wl,--end-group" + ;
                 " -luser32 -lgdi32 -lcomctl32 -lcomdlg32 -lshell32" + ;
                 " -lole32 -loleaut32 -ladvapi32 -lws2_32 -lwinmm" + ;
                 " -lmsimg32 -lgdiplus -liphlpapi -luuid -lwinspool -lstdc++"
      else
         cObjs := "c0w32.obj " + cObjs
         cCmd := cLinker + ' -Gn -aa -Tpe' + ;
                 " -L" + cCDir + "\lib" + ;
                 " -L" + cCDir + "\lib\psdk" + ;
                 " -L" + cHbLib + ;
                 " " + cObjs + "," + ;
                 " " + cExePath + ",," + ;
                 " hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib" + ;
                 " hbmacro.lib hbpp.lib hbcommon.lib hbcplr.lib hbct.lib" + ;
                 " hbhsx.lib hbsix.lib hbusrrdd.lib" + ;
                 " rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib" + ;
                 " hbdebug.lib hbpcre.lib hbzlib.lib" + ;
                 " hbsqlit3.lib sqlite3.lib" + ;
                 " gtwin.lib gtwvt.lib gtgui.lib" + ;
                 " cw32mt.lib import32.lib ws2_32.lib winmm.lib iphlpapi.lib" + ;
                 " user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib" + ;
                 " ole32.lib oleaut32.lib uuid.lib advapi32.lib" + ;
                 " msimg32.lib gdiplus.lib,,"
      endif
      cOutput := W32_ShellExec( cCmd )
      // Also check if exe was actually created
      if ! File( cExePath )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Write full build log to trace file
   MemoWrit( cBuildDir + "\build_trace.log", cLog )

   // Close progress dialog
   W32_ProgressClose()

   // Result
   if lError
      W32_BuildErrorDialog( "Build Failed", cLog )
   elseif ! File( cExePath )
      cLog += Chr(10) + "ERROR: " + cAppName + ".exe was not created." + Chr(10)
      W32_BuildErrorDialog( "Build Failed", cLog )
   else
      nLastHash := nHash  // remember successful build hash
      W32_ShellExec( 'cmd /c start "" "' + cExePath + '"' )
      RefreshIDEToolbars()
   endif

return nil

// === Android target: build APK and run on emulator ===
//
// Pipeline:
//   1. Generate a UI_*-based PRG from the active form (aForms[1]).
//   2. Invoke build-apk-gui.sh to produce a signed APK.
//   3. Install it on the first connected device / emulator and launch.
//
// See memory/project_android_build.md and project_android_gui_validated.md.
static function TBRunAndroid()

   local cRepoRoot   := "C:\HarbourBuilder"
   local cAndroidDir := "C:\HarbourAndroid"
   local cBackend    := cRepoRoot + "\source\backends\android"
   local cGenPrg     := cBackend + "\_generated.prg"
   local cBuildSh    := cBackend + "\build-apk-gui.sh"
   local cApkPath    := cAndroidDir + "\apk-gui\harbour-gui.apk"
   // Build log lives OUTSIDE apk-gui because build-apk-gui.sh does
   // rm -rf /c/HarbourAndroid/apk-gui at startup, which nuked the file.
   local cLogPath    := cAndroidDir + "\build-apk-gui.log"
   local cBash       := "C:\Program Files\Git\bin\bash.exe"
   local cAdb        := "C:\Android\Sdk\platform-tools\adb.exe"
   local cPrg, cLog, cCmd, nRc

   AndroidTrace( "=== TBRunAndroid start ===" )
   AndroidTrace( "cBash    = " + cBash + " exists=" + iif( File(cBash), "Y", "N" ) )
   AndroidTrace( "cAdb     = " + cAdb  + " exists=" + iif( File(cAdb),  "Y", "N" ) )
   AndroidTrace( "cGenPrg  = " + cGenPrg )
   AndroidTrace( "cApkPath = " + cApkPath )

   if ! lIsDir( cAndroidDir )
      AndroidTrace( "ABORT: toolchain dir missing" )
      MsgInfo( "Android toolchain not found at " + cAndroidDir + Chr(10) + ;
               "See memory/project_android_build.md for the required layout.", ;
               "Android target" )
      return nil
   endif
   if ! File( cBash )
      AndroidTrace( "ABORT: bash.exe missing" )
      MsgInfo( "bash.exe not found at " + cBash + Chr(10) + ;
               "Install Git for Windows to provide bash.", "Android target" )
      return nil
   endif

   SaveActiveFormCode()
   SyncDesignerToCode()

   AndroidTrace( "Generating Android PRG..." )
   cPrg := GenerateAndroidPRG()
   if Empty( cPrg )
      AndroidTrace( "ABORT: empty generated PRG" )
      MsgInfo( "No form to build - add at least one control to the designer.", ;
               "Android target" )
      return nil
   endif
   MemoWrit( cGenPrg, cPrg )
   AndroidTrace( "Wrote " + cGenPrg + " (" + LTrim(Str(Len(cPrg))) + " bytes)" )

   W32_ProgressOpen( "Building Android APK...", 2 )
   W32_ProgressStep( "Compiling generated PRG -> signed APK..." )

   // Delete any stale APK so the "APK exists=Y" check below reflects THIS
   // build, not a leftover from a previous run.
   FErase( cApkPath )

   // cmd.exe /c quote rule: if the first char is '"' and the string has
   // more than two quotes, cmd strips only the first and last '"' and
   // passes the rest through. Without an OUTER wrapping pair, cmd would
   // strip a "real" quote from our bash path and the command would break
   // silently (which is what made every build a no-op). Wrap everything
   // in a double-quote at each end to give cmd a pair to strip.
   cCmd := '""' + cBash + '" -lc "bash /c/HarbourBuilder/source/backends/android/build-apk-gui.sh ' + ;
           '/c/HarbourBuilder/source/backends/android/_generated.prg > /c/HarbourAndroid/build-apk-gui.log 2>&1""'
   AndroidTrace( "Build cmd: " + cCmd )
   W32_ShellExec( cCmd )
   AndroidTrace( "Build cmd returned. APK exists=" + iif( File( cApkPath ), "Y", "N" ) )

   cLog := iif( File( cLogPath ), MemoRead( cLogPath ), "(no log produced)" )

   if ! File( cApkPath )
      AndroidTrace( "ABORT: APK not produced. build.log follows:" )
      AndroidTrace( cLog )
      W32_ProgressClose()
      W32_BuildErrorDialog( "Android Build Failed", cLog )
      return nil
   endif

   W32_ProgressClose()

   // Show the info dialog BEFORE spawning the terminal. Otherwise the new
   // cmd window steals focus and auto-dismisses this MsgInfo before the
   // user has a chance to read it.
   MsgInfo( "APK built:" + Chr(10) + cApkPath + Chr(10) + Chr(10) + ;
            "Click OK to start install + launch in a separate terminal." + Chr(10) + ;
            "The emulator will boot if it isn't already running." + Chr(10) + ;
            "Live logcat (HbAndroid + errors) will stream in that window.", ;
            "Android target" )

   // Fire install-and-run.sh in its own terminal window and return
   // control to the IDE. hb_run uses system() so it does not inherit
   // our stdout pipes (W32_ShellExec does, which caused earlier hangs).
   // Same outer-quote trick here: start parses its own args, but the
   // surrounding cmd /c still applies rule 2 to the whole thing.
   cCmd := '"start "HarbourBuilder Android" "' + cBash + '" -lc ' + ;
           '"bash /c/HarbourBuilder/source/backends/android/install-and-run.sh; exec bash""'
   AndroidTrace( "Launch cmd: " + cCmd )
   nRc := hb_run( cCmd )
   AndroidTrace( "Launch cmd returned rc=" + LTrim( Str( nRc ) ) )

   AndroidTrace( "=== TBRunAndroid end (success path) ===" )
return nil

// Android Setup Wizard
//
// Reports which toolchain components are present and, if anything is
// missing, offers to run setup-android-toolchain.sh in a dedicated
// terminal window. That script downloads and installs JDK, NDK, SDK
// cmdline-tools + packages, creates the HarbourBuilderAVD, and
// extracts the prebuilt Harbour-for-Android libs from releases/.
static function AndroidSetupWizard()

   local cReport := "Android toolchain status:" + Chr(10) + Chr(10)
   local lNdk, lSdk, lBT, lPT, lEmu, lJdk, lBash, lHbAnd, lAvd
   local cHbRoot := "C:\HarbourAndroid\harbour-core"
   local cAvdDir := GetEnv( "USERPROFILE" ) + "\.android\avd\HarbourBuilderAVD.avd"
   local cCmd

   lNdk   := hb_DirExists( "C:\Android\android-ndk-r26d" )
   lSdk   := hb_DirExists( "C:\Android\Sdk\platforms\android-34" )
   lBT    := hb_DirExists( "C:\Android\Sdk\build-tools\34.0.0" )
   lPT    := File( "C:\Android\Sdk\platform-tools\adb.exe" )
   lEmu   := File( "C:\Android\Sdk\emulator\emulator.exe" )
   lJdk   := File( "C:\JDK17\jdk-17.0.13+11\bin\javac.exe" )
   lBash  := File( "C:\Program Files\Git\bin\bash.exe" )
   lHbAnd := hb_DirExists( cHbRoot + "\lib\android\clang-android-arm64-v8a" )
   lAvd   := hb_DirExists( cAvdDir )

   cReport += "  NDK r26d        " + iif( lNdk,   "OK", "MISSING" ) + Chr(10)
   cReport += "  SDK platform 34 " + iif( lSdk,   "OK", "MISSING" ) + Chr(10)
   cReport += "  build-tools 34  " + iif( lBT,    "OK", "MISSING" ) + Chr(10)
   cReport += "  platform-tools  " + iif( lPT,    "OK", "MISSING" ) + Chr(10)
   cReport += "  emulator        " + iif( lEmu,   "OK", "MISSING" ) + Chr(10)
   cReport += "  JDK 17          " + iif( lJdk,   "OK", "MISSING" ) + Chr(10)
   cReport += "  Git Bash        " + iif( lBash,  "OK", "MISSING" ) + Chr(10)
   cReport += "  Harbour-Android " + iif( lHbAnd, "OK", "MISSING" ) + Chr(10)
   cReport += "  AVD             " + iif( lAvd,   "OK", "MISSING" ) + Chr(10)

   // Everything present?
   if lNdk .and. lSdk .and. lBT .and. lPT .and. lEmu .and. lJdk .and. lBash .and. lHbAnd .and. lAvd
      MsgInfo( cReport + Chr(10) + "Toolchain is complete. Ready to Run on Android.", ;
               "Android Setup Wizard" )
      return nil
   endif

   // Git Bash is required for the installer script itself
   if ! lBash
      MsgInfo( cReport + Chr(10) + "Git Bash is required to run the installer." + ;
               Chr(10) + "Install from https://git-scm.com/download/win and " + ;
               "re-open this wizard.", "Android Setup Wizard" )
      return nil
   endif

   // Offer the full installer (downloads JDK, NDK, SDK, creates AVD,
   // extracts shipped Harbour libs). Runs in its own terminal window.
   cReport += Chr(10) + "Download + install the missing components now?" + Chr(10) + ;
              "(Up to 2.8 GB on a fresh machine, 5-20 min. Runs in its own " + ;
              "terminal so you can watch progress and accept the Android " + ;
              "SDK license prompts.)"
   if ! MsgYesNo( cReport, "Android Setup Wizard" )
      return nil
   endif

   cCmd := "start " + Chr(34) + "HarbourBuilder - Android setup" + Chr(34) + " " + ;
           Chr(34) + "C:\Program Files\Git\bin\bash.exe" + Chr(34) + " -lc " + ;
           Chr(34) + ;
           "bash /c/HarbourBuilder/source/backends/android/setup-android-toolchain.sh; " + ;
           "exec bash" + Chr(34)
   hb_run( cCmd )

   MsgInfo( "Setup terminal launched. When it says 'All done', close it " + ;
            "and try Run > Run on Android...", "Android Setup Wizard" )

return nil

static function AndroidTrace( cMsg )
   local nH, cLine
   cLine := DToS( Date() ) + " " + Time() + " " + cMsg + Chr(13) + Chr(10)
   nH := FOpen( "c:\HarbourBuilder\android_trace.log", 2 )
   if nH == -1
      nH := FCreate( "c:\HarbourBuilder\android_trace.log" )
   else
      FSeek( nH, 0, 2 )
   endif
   if nH != -1
      FWrite( nH, cLine )
      FClose( nH )
   endif
return nil

// Ensure an Android device is ready. If none is connected, launch the
// AVD "HarbourBuilderAVD" in background and poll getprop sys.boot_completed
// for up to 120 seconds. Returns .T. when the device is ready.
//
// Important: W32_ShellExec captures the child's stdout via an inherited
// pipe. When adb spawns its daemon for the first time the daemon inherits
// the write end and never closes it, so ReadFile blocks forever and the
// IDE appears to "wait" with the emulator visible. We sidestep that with:
//   - Pre-starting the adb server detached (cmd /c start "" ...) so later
//     calls don't have to fork a child that holds our pipe.
//   - Using hb_run with a file redirect to run adb and read the output
//     back from disk — no inherited pipes involved.
static function AndroidEnsureDevice( cAdb )

   local cEmulator := "C:\Android\Sdk\emulator\emulator.exe"
   local cAvd      := "HarbourBuilderAVD"
   local cTmp      := hb_DirTemp() + "hb_adb_probe.txt"
   local nTries

   // 1. Make sure the adb daemon is running so nothing blocks our pipes.
   W32_ShellExec( 'start "" "' + cAdb + '" start-server' )
   hb_idleSleep( 2 )

   // 2. Already a fully-booted device?
   if AdbGetProp( cAdb, cTmp ) == "1"
      return .T.
   endif

   // 3. No booted device - launch the AVD detached
   if ! File( cEmulator )
      MsgInfo( "Android emulator not found at " + cEmulator, "Android target" )
      return .F.
   endif
   W32_ShellExec( 'start "" "' + cEmulator + '" -avd ' + cAvd + ' -no-snapshot-save' )

   // 4. Poll boot_completed up to ~120 s
   for nTries := 1 to 60
      W32_ProgressStep( "Waiting for emulator (" + LTrim( Str( nTries ) ) + "/60)..." )
      hb_idleSleep( 2 )
      if AdbGetProp( cAdb, cTmp ) == "1"
         return .T.
      endif
   next

return .F.

// Run "adb shell getprop sys.boot_completed" without capturing via an
// inherited pipe - redirect to a temp file and read it back. Returns
// "1" when boot finished, "" otherwise (device absent, daemon busy, ...).
static function AdbGetProp( cAdb, cTmp )
   local cOut
   hb_run( 'cmd /c ""' + cAdb + '" shell getprop sys.boot_completed > "' + cTmp + '" 2>nul"' )
   cOut := iif( File( cTmp ), MemoRead( cTmp ), "" )
   FErase( cTmp )
return AllTrim( StrTran( StrTran( cOut, Chr(13), "" ), Chr(10), "" ) )

// Build a UI_*-based PRG from the currently designed form.
// Supported in iteration 1b: Label (1), Edit (2), Button (3) + button OnClick
// codeblocks if the user named a handler function <CtrlName>Click. Other
// control types emit a comment line (rendered as no-op on Android).
//
// Event handlers written as METHODs on the form class are translated into
// plain FUNCTIONs and appended, with ::oXxx:Text accesses rewritten into
// UI_GetText / UI_SetText calls against the control handles.
static function GenerateAndroidPRG()

   local cPRG, e := Chr(10)
   local hForm, nCount, i, hCtrl, nType
   local cName, cText, nL, nT, nW, nH, cTitle, nFW, nFH, nFormClr, nCtrlClr
   local cFontSpec, cFontFam, nFontSize, aFont
   local cEventTab, aDecls := {}, aCreate := {}, aBind := {}
   local aCtrlNames := {}
   local cQ := Chr(34)

   AndroidTrace( "-- GenerateAndroidPRG --" )
   AndroidTrace( "  nActiveForm = " + LTrim( Str( iif( ValType( nActiveForm ) == "N", nActiveForm, -1 ) ) ) )
   AndroidTrace( "  Len(aForms) = " + LTrim( Str( Len( aForms ) ) ) )
   AndroidTrace( "  oDesignForm type = " + ValType( oDesignForm ) )

   // Prefer the live design form over aForms[1] — that's the one the user
   // is actively dragging controls onto. aForms[1][2] can be a stale
   // object when the designer re-created the form.
   hForm := nil
   if oDesignForm != nil .and. ValType( oDesignForm ) == "O"
      hForm := oDesignForm:hCpp
      AndroidTrace( "  using oDesignForm:hCpp = " + hb_CStr( hForm ) )
   endif
   if ( hForm == nil .or. hForm == 0 ) .and. ! Empty( aForms )
      if aForms[1][2] != nil .and. ValType( aForms[1][2] ) == "O"
         hForm := aForms[1][2]:hCpp
         AndroidTrace( "  fallback aForms[1][2]:hCpp = " + hb_CStr( hForm ) )
      endif
   endif
   if hForm == nil .or. hForm == 0
      AndroidTrace( "  ABORT: no form handle available" )
      return ""
   endif

   cTitle := UI_GetProp( hForm, "cText" )
   if Empty( cTitle )
      cTitle := iif( ! Empty( aForms ), aForms[1][1], "Form1" )
   endif
   nFW := UI_GetProp( hForm, "nWidth" )
   nFH := UI_GetProp( hForm, "nHeight" )
   nFormClr := UI_GetProp( hForm, "nClrPane" )
   AndroidTrace( "  title='" + cTitle + "' w=" + LTrim(Str(nFW)) + ;
                 " h=" + LTrim(Str(nFH)) + " color=" + LTrim(Str(nFormClr)) )

   cEventTab := ""
   if ! Empty( aForms ) .and. ValType( aForms[1][3] ) == "C"
      cEventTab := aForms[1][3]
   endif

   nCount := UI_GetChildCount( hForm )
   AndroidTrace( "  nCount = " + LTrim( Str( nCount ) ) )
   for i := 1 to nCount
      hCtrl := UI_GetChild( hForm, i )
      if hCtrl == 0
         AndroidTrace( "  [" + LTrim(Str(i)) + "] hCtrl == 0, skipped" )
         loop
      endif

      nType := UI_GetType( hCtrl )
      cName := AllTrim( UI_GetProp( hCtrl, "cName" ) )
      if Empty( cName ); cName := "ctrl" + LTrim( Str( i ) ); endif

      cText := StrTran( UI_GetProp( hCtrl, "cText" ), cQ, "'" )
      nL := UI_GetProp( hCtrl, "nLeft" )
      nT := UI_GetProp( hCtrl, "nTop" )
      nW := UI_GetProp( hCtrl, "nWidth" )
      nH := UI_GetProp( hCtrl, "nHeight" )
      AndroidTrace( "  [" + LTrim(Str(i)) + "] type=" + LTrim(Str(nType)) + ;
                    " name=" + cName + " text='" + cText + "' @(" + ;
                    LTrim(Str(nL)) + "," + LTrim(Str(nT)) + ") " + ;
                    LTrim(Str(nW)) + "x" + LTrim(Str(nH)) )

      do case
         case nType == 1  // Label
            AAdd( aDecls,  "   LOCAL h" + cName )
            AAdd( aCreate, '   h' + cName + ' := UI_LabelNew( hForm, "' + cText + '", ' + ;
                  LTrim(Str(nL)) + ', ' + LTrim(Str(nT)) + ', ' + ;
                  LTrim(Str(nW)) + ', ' + LTrim(Str(nH)) + ' )' )
            AAdd( aCtrlNames, cName )
         case nType == 2  // Edit
            AAdd( aDecls,  "   LOCAL h" + cName )
            AAdd( aCreate, '   h' + cName + ' := UI_EditNew( hForm, "' + cText + '", ' + ;
                  LTrim(Str(nL)) + ', ' + LTrim(Str(nT)) + ', ' + ;
                  LTrim(Str(nW)) + ', ' + LTrim(Str(nH)) + ' )' )
            AAdd( aCtrlNames, cName )
         case nType == 3  // Button
            AAdd( aDecls,  "   LOCAL h" + cName )
            AAdd( aCreate, '   h' + cName + ' := UI_ButtonNew( hForm, "' + cText + '", ' + ;
                  LTrim(Str(nL)) + ', ' + LTrim(Str(nT)) + ', ' + ;
                  LTrim(Str(nW)) + ', ' + LTrim(Str(nH)) + ' )' )
            AAdd( aCtrlNames, cName )
            if ( cName + "Click" ) $ cEventTab
               AAdd( aBind, '   UI_OnClick( h' + cName + ', {|| ' + cName + 'Click() } )' )
            endif
         otherwise
            AAdd( aCreate, '   // ' + cName + ' (type ' + LTrim(Str(nType)) + ') - not yet supported on Android' )
      endcase

      // Per-control visual extras: background color + font.
      if nType >= 1 .and. nType <= 3   // only the visual types supported in iter 1b
         nCtrlClr := UI_GetProp( hCtrl, "nClrPane" )
         if ValType( nCtrlClr ) == "N" .and. nCtrlClr >= 0 .and. nCtrlClr != 4294967295
            AAdd( aCreate, '   UI_SetCtrlColor( h' + cName + ', ' + LTrim( Str( nCtrlClr ) ) + ' )' )
         endif
         cFontSpec := UI_GetProp( hCtrl, "oFont" )
         if ValType( cFontSpec ) == "C" .and. ! Empty( cFontSpec )
            aFont := hb_ATokens( cFontSpec, "," )
            cFontFam  := iif( Len( aFont ) >= 1, AllTrim( aFont[1] ), "" )
            nFontSize := iif( Len( aFont ) >= 2, Val( AllTrim( aFont[2] ) ), 0 )
            if ! Empty( cFontFam ) .or. nFontSize > 0
               AAdd( aCreate, '   UI_SetCtrlFont( h' + cName + ', "' + ;
                     StrTran( cFontFam, cQ, "'" ) + '", ' + LTrim( Str( nFontSize ) ) + ' )' )
            endif
         endif
      endif
   next

   cPRG := "// Auto-generated for Android target - DO NOT EDIT" + e
   cPRG += "// Regenerated every time you click Run on Android..." + e + e
   // Declare control handles as module-scope STATICs so the event
   // handlers (separate FUNCTIONs below) can read them. LOCALs of Main
   // would be invisible to Button1Click and crash on first tap.
   cPRG += "STATIC hForm"
   AEval( aCtrlNames, {|c| cPRG += ", h" + c } )
   cPRG += e + e
   cPRG += "PROCEDURE Main()" + e
   cPRG += '   hForm := UI_FormNew( "' + StrTran( cTitle, cQ, "'" ) + '", ' + ;
           LTrim( Str( nFW ) ) + ', ' + LTrim( Str( nFH ) ) + ' )' + e
   if ValType( nFormClr ) == "N" .and. nFormClr >= 0 .and. nFormClr != 4294967295
      cPRG += '   UI_SetFormColor( ' + LTrim( Str( nFormClr ) ) + ' )' + e
   endif
   AEval( aCreate, {|c| cPRG += c + e } )
   if ! Empty( aBind )
      cPRG += e
      AEval( aBind, {|c| cPRG += c + e } )
   endif
   cPRG += e + "   UI_FormRun( hForm )" + e + "RETURN" + e

   // Translate user's METHOD handlers into standalone FUNCTIONs so the
   // generated PRG is self-contained and the Android linker finds every
   // symbol referenced by the UI_OnClick codeblocks.
   cPRG += TranslateHandlers( aBind, cEventTab, aCtrlNames )

   AndroidTrace( "  emitted " + LTrim(Str(Len(aCreate))) + " creation lines, " + ;
                 LTrim(Str(Len(aBind))) + " bindings, " + ;
                 LTrim(Str(Len(aCtrlNames))) + " controls tracked" )

return cPRG

// Translate METHOD handlers referenced by the emitted UI_OnClick bindings
// into plain FUNCTIONs usable by the generated PRG. Rewrites ::oXxx:Text
// access so it hits UI_GetText/UI_SetText against the backend handles.
// Any handler we can't find is emitted as an empty stub (so the link
// succeeds and the button is simply inert until the user fills it in).
static function TranslateHandlers( aBind, cEventTab, aCtrlNames )

   local cOut := "", e := Chr(10)
   local i, j, cBind, cName, nPos, nEnd
   local cBody, aLines, k, cLine, cSetter, cCtrl
   local cStartTag

   if Empty( aBind )
      return cOut
   endif

   for i := 1 to Len( aBind )
      // Extract handler function name: the piece between "{|| " and "()"
      cBind := aBind[i]
      nPos := At( "{|| ", cBind )
      if nPos == 0; loop; endif
      nEnd := At( "()", cBind )
      if nEnd == 0 .or. nEnd <= nPos; loop; endif
      cName := SubStr( cBind, nPos + 4, nEnd - nPos - 4 )

      // Find "METHOD <cName>() CLASS ..." in the user's form code.
      cBody := ""
      cStartTag := "METHOD " + cName + "()"
      nPos := At( cStartTag, cEventTab )
      if nPos > 0
         // Skip to the method body: the line after the METHOD declaration.
         nPos := At( e, SubStr( cEventTab, nPos ) ) + nPos - 1
         nEnd := FindMethodEnd( cEventTab, nPos + 1 )
         cBody := SubStr( cEventTab, nPos + 1, nEnd - nPos - 1 )
      endif

      // Rewrite ::oXxx:Text references. Works line by line so we can
      // balance parentheses on setter assignments.
      aLines := hb_ATokens( cBody, e )
      for k := 1 to Len( aLines )
         cLine := aLines[k]
         for j := 1 to Len( aCtrlNames )
            cCtrl := aCtrlNames[j]
            // Setter first (longer match). We turn
            //   ::oLabel1:Text := expr
            // into
            //   UI_SetText( hLabel1, expr )
            cSetter := "::o" + cCtrl + ":Text :="
            if cSetter $ cLine
               cLine := StrTran( cLine, cSetter, ;
                                 "UI_SetText( h" + cCtrl + ", " ) + " )"
            else
               cSetter := "::o" + cCtrl + ":Text:="
               if cSetter $ cLine
                  cLine := StrTran( cLine, cSetter, ;
                                    "UI_SetText( h" + cCtrl + ", " ) + " )"
               endif
            endif
            // Remaining bare accesses are getters.
            cLine := StrTran( cLine, "::o" + cCtrl + ":Text", ;
                              "UI_GetText( h" + cCtrl + " )" )
         next
         aLines[k] := cLine
      next

      cBody := ""
      AEval( aLines, {|c| cBody += c + e } )

      cOut += e + "FUNCTION " + cName + "()" + e + cBody
      if ! ( "RETURN" $ Upper( cBody ) )
         cOut += "RETURN NIL" + e
      endif
   next

return cOut

// Find the end of a method body starting from nFrom (just past the METHOD
// declaration). Ends at the next "METHOD ", "ENDCLASS", or "STATIC FUNCTION"
// - whichever comes first.
static function FindMethodEnd( cCode, nFrom )
   local aMarkers := { Chr(10) + "METHOD ",      ;
                       Chr(10) + "method ",      ;
                       Chr(10) + "ENDCLASS",     ;
                       Chr(10) + "endclass",     ;
                       Chr(10) + "FUNCTION ",    ;
                       Chr(10) + "function ",    ;
                       Chr(10) + "STATIC",       ;
                       Chr(10) + "static" }
   local nEnd := 0, n, k
   for k := 1 to Len( aMarkers )
      n := At( aMarkers[k], SubStr( cCode, nFrom ) )
      if n > 0 .and. ( nEnd == 0 .or. n < nEnd )
         nEnd := n
      endif
   next
   if nEnd == 0
      nEnd := Len( cCode ) + 1
   else
      nEnd += nFrom - 1
   endif
return nEnd

static function lIsDir( cPath )
return ! Empty( hb_DirExists( cPath ) )

// === Project Inspector (VS Solution Explorer / C++Builder Project Manager) ===

static function ShowProjectInspector()

   local aItems := {}, i

   // Build tree items: project root + source files
   AAdd( aItems, "Project1" )
   AAdd( aItems, "  Project1.prg" )
   for i := 1 to Len( aForms )
      AAdd( aItems, "  " + aForms[i][1] + ".prg" )
   next

   W32_ProjectInspector( aItems )

return nil

// === Editor Colors Dialog (C++Builder: Tools > Editor Options > Colors) ===

static function ShowEditorSettings()

   static cFontName  := "Consolas"
   static nFontSize  := 15
   static nBgColor   := 1973790    // RGB(30,30,30) dark
   static nTextColor := 13948116   // RGB(212,212,212) light gray
   static nKeywordClr := 5668054   // RGB(86,156,214) blue
   static nCommandClr := 5098318   // RGB(78,201,176) teal
   static nCommentClr := 6985578   // RGB(0,200,0) green
   static nStringClr  := 13538510  // RGB(255,150,50) orange
   static nPreProcClr := 14530758  // RGB(255,100,255) purple
   static nNumberClr  := 15185578  // RGB(170,170,120) yellow-gray
   static nSelBgClr   := 4536632   // RGB(40,70,100) selection

   W32_EditorSettingsDialog( ;
      cFontName, nFontSize, ;
      nBgColor, nTextColor, nKeywordClr, nCommandClr, ;
      nCommentClr, nStringClr, nPreProcClr, nNumberClr, nSelBgClr )

return nil

// === Project Options Dialog (C++Builder: Project > Options) ===

static function ShowProjectOptions()

   // Project settings stored as statics
   static cHarbourDir   := ""
   static cCompilerDir  := ""
   static cProjectDir   := "c:\HarbourBuilder"
   static cOutputDir    := ""
   static cHbFlags      := "/n /w /q"
   static cCFlags       := ""
   static cLinkFlags    := ""
   static cIncludePaths := ""
   static cLibPaths     := ""
   static cLibraries    := ""
   static lDebugInfo    := .F.
   static lWarnings     := .T.
   static lOptimize     := .T.
   local aCI

   // Auto-detect paths from current compiler on first open
   if Empty( cHarbourDir )
      aCI := GetCompilerInfo()
      if aCI != nil
         cCompilerDir := aCI[4]
         if aCI[1] == "msvc"
            cCFlags    := "/c /O2 /W0 /EHsc"
            cLinkFlags := "/SUBSYSTEM:WINDOWS"
         else
            cCFlags    := "-c -O2 -tW"
            cLinkFlags := "-Gn -aa -Tpe"
         endif
      endif
      cHarbourDir := FindHarbour( iif( aCI != nil, aCI[1], "bcc" ) )
      if Empty( cHarbourDir ); cHarbourDir := "c:\harbour"; endif
   endif

   W32_ProjectOptionsDialog( ;
      cHarbourDir, cCompilerDir, cProjectDir, cOutputDir, ;
      cHbFlags, cCFlags, cLinkFlags, ;
      cIncludePaths, cLibPaths, cLibraries, ;
      lDebugInfo, lWarnings, lOptimize )

return nil

// === Debugger ===

static function ToggleBreakpoint()

   static aBreakpoints := {}
   local nLine := 1  // TODO: get current line from code editor
   local cFile := "Form1.prg"
   local i, lFound := .F.

   for i := 1 to Len( aBreakpoints )
      if aBreakpoints[i][1] == cFile .and. aBreakpoints[i][2] == nLine
         ADel( aBreakpoints, i )
         ASize( aBreakpoints, Len(aBreakpoints) - 1 )
         lFound := .T.
         exit
      endif
   next

   if ! lFound
      AAdd( aBreakpoints, { cFile, nLine } )
      IDE_DebugAddBreakpoint( cFile, nLine )
   endif

return nil

static function ClearBreakpoints()
   IDE_DebugClearBreakpoints()
return nil

static function DebugStepOver()
   if IDE_DebugGetState() == 2  // DBG_PAUSED
      IDE_DebugStepOver()
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

// === Debug Run (socket-based, native exe — matches macOS/Linux) ===

static function TBDebugRun()

   local cBuildDir, cOutput, cLog, i, lError
   local cHbDir, cHbBin, cHbInc, cHbLib
   local cCDir, cCC, cLinker
   local cProjDir, cAllPrg, cCmd, cSection
   local cCompiler, cMsvcBase, cWinKit, cWinKitVer
   local cMsvcInc, cMsvcLib, cUcrtInc, cUmInc, cSharedInc, cUcrtLib, cUmLib
   local cRsp, cRspContent, aCI, cObjs
   local cMainPrg, nCurLine, cCppBase, k
   local aCppFiles

   SaveActiveFormCode()
   SyncDesignerToCode()  // Ensure event bindings are up to date
   W32_SetWaitCursor( .T. )

   cBuildDir := "c:\hbbuilder_debug"
   cProjDir  := "c:\HarbourBuilder"
   cLog      := ""
   lError    := .F.

   // Detect compiler
   aCI := GetCompilerInfo()
   if aCI == nil
      ShowNoCompilerDialog()
      return nil
   endif

   cCompiler := aCI[1]

   // Find Harbour installation (search multiple paths)
   cHbDir := FindHarbour( cCompiler )
   if Empty( cHbDir )
      cHbDir := EnsureHarbour( cCompiler, aCI )
      if Empty( cHbDir )
         return nil
      endif
   endif
   cHbInc := cHbDir + "\include"

   if cCompiler == "msvc"
      cMsvcBase  := aCI[4]
      cWinKit    := "c:\Program Files (x86)\Windows Kits\10"
      cWinKitVer := aCI[5]
      cCC        := cMsvcBase + '\bin\Hostx86\x86\cl.exe'
      cLinker    := cMsvcBase + '\bin\Hostx86\x86\link.exe'
      cMsvcInc   := cMsvcBase + "\include"
      cMsvcLib   := cMsvcBase + "\lib\x86"
      cUcrtInc   := cWinKit + "\Include\" + cWinKitVer + "\ucrt"
      cUmInc     := cWinKit + "\Include\" + cWinKitVer + "\um"
      cSharedInc := cWinKit + "\Include\" + cWinKitVer + "\shared"
      cUcrtLib   := cWinKit + "\Lib\" + cWinKitVer + "\ucrt\x86"
      cUmLib     := cWinKit + "\Lib\" + cWinKitVer + "\um\x86"
      cHbBin := FindHarbourSub( cHbDir, "bin", "msvc", "harbour.exe" )
      cHbLib := FindHarbourSub( cHbDir, "lib", "msvc", "hbrtl.lib" )
   elseif cCompiler == "mingw"
      cCDir      := aCI[4]
      cCC        := cCDir + "\bin\gcc.exe"
      cLinker    := cCDir + "\bin\g++.exe"
      cHbBin := FindHarbourSub( cHbDir, "bin", "mingw", "harbour.exe" )
      cHbLib := FindHarbourSub( cHbDir, "lib", "mingw", "libhbrtl.a" )
   else
      cCDir      := aCI[4]
      cCC        := cCDir + "\bin\bcc32.exe"
      cLinker    := cCDir + "\bin\ilink32.exe"
      cHbBin := FindHarbourSub( cHbDir, "bin", "bcc", "harbour.exe" )
      cHbLib := FindHarbourSub( cHbDir, "lib", "bcc", "hbrtl.lib" )
   endif

   W32_ShellExec( 'cmd /c mkdir "' + cBuildDir + '" 2>nul' )
   W32_ShellExec( 'cmd /c del "' + cBuildDir + '\DebugApp.exe" 2>nul' )
   W32_ShellExec( 'cmd /c del "' + cBuildDir + '\*.obj" 2>nul' )
   W32_ShellExec( 'cmd /c del "' + cBuildDir + '\*.o" 2>nul' )

   W32_DebugSetStatus( "Compiling debug build..." )

   // Step 1: Save user code + copy framework
   cLog += "[1] Saving files..." + Chr(10)
   MemoWrit( cBuildDir + "\Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "\" + aForms[i][1] + ".prg", ;
         CodeEditorGetTabText( hCodeEditor, i + 1 ) )
   next
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\source\core\classes.prg" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\include\hbbuilder.ch" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\include\hbide.ch" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\source\debugger\dbgclient.prg" "' + cBuildDir + '\" >nul 2>&1' )

   // Step 2: Assemble debug_main.prg (tracking line offsets for each section)
   cLog += "[2] Assembling debug_main.prg..." + Chr(10)

   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_GUI_DEFAULT" + Chr(10)
   cAllPrg += "INIT PROCEDURE __DbgInit" + Chr(10)
   cAllPrg += "   DbgClientStart( 19800 )" + Chr(10)
   cAllPrg += "return" + Chr(10) + Chr(10)
   // DPI awareness
   cAllPrg += "INIT PROCEDURE _InitDPI()" + Chr(10)
   cAllPrg += "   SetDPIAware()" + Chr(10)
   cAllPrg += "return" + Chr(10) + Chr(10)
   nCurLine := 11

   aDbgOffsets := {}

   // Project1.prg
   AAdd( aDbgOffsets, { nCurLine, "Project1.prg", 1, 1 } )
   cMainPrg := CodeEditorGetTabText( hCodeEditor, 1 )
   cMainPrg := StrTran( cMainPrg, '#include "hbbuilder.ch"', "" )
   cAllPrg += cMainPrg + Chr(10)
   nCurLine += NumLines( cMainPrg ) + 1

   // Form files
   for i := 1 to Len( aForms )
      AAdd( aDbgOffsets, { nCurLine, aForms[i][1] + ".prg", i + 1, 2 } )
      cSection := MemoRead( cBuildDir + "\" + aForms[i][1] + ".prg" )
      cAllPrg += cSection + Chr(10)
      nCurLine += NumLines( cSection ) + 1
   next

   // classes.prg (framework — not in editor)
   AAdd( aDbgOffsets, { nCurLine, "classes.prg", 0, 0 } )
   cSection := MemoRead( cBuildDir + "\classes.prg" )
   cAllPrg += cSection + Chr(10)
   nCurLine += NumLines( cSection ) + 1

   // dbgclient.prg (debug client — not in editor)
   AAdd( aDbgOffsets, { nCurLine, "dbgclient.prg", 0, 0 } )
   cAllPrg += MemoRead( cBuildDir + "\dbgclient.prg" ) + Chr(10)

   // Platform stubs for macOS/Linux functions referenced by classes.prg
   cAllPrg += '#pragma BEGINDUMP' + Chr(10)
   cAllPrg += '#include <hbapi.h>' + Chr(10)
   cAllPrg += '#include <windows.h>' + Chr(10)
   cAllPrg += 'HB_FUNC( UI_MEMONEW )        { hb_retnint( 0 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( UI_MSGBOX )         { MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "App", 0x40 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( UI_MSGYESNO )      { hb_retl( MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2) ? hb_parc(2) : "Confirm", 0x24 ) == 6 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( MAC_RUNTIMEERRORDIALOG ) { hb_retni( 0 ); }' + Chr(10)
   cAllPrg += 'HB_FUNC( MAC_APPTERMINATE )  { }' + Chr(10)
   cAllPrg += 'HB_FUNC( W32_ERRORDIALOG ) {' + Chr(10)
   cAllPrg += '  const char * msg = hb_parc(1);' + Chr(10)
   cAllPrg += '  HWND hDlg, hEdit, hBtn;' + Chr(10)
   cAllPrg += '  MSG m; HFONT hF;' + Chr(10)
   cAllPrg += '  hDlg = CreateWindowExA(0,"STATIC","Runtime Error",' + Chr(10)
   cAllPrg += '    WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_VISIBLE,' + Chr(10)
   cAllPrg += '    100,100,600,400,NULL,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  hF = (HFONT)GetStockObject(DEFAULT_GUI_FONT);' + Chr(10)
   cAllPrg += '  hEdit = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",msg,' + Chr(10)
   cAllPrg += '    WS_CHILD|WS_VISIBLE|WS_VSCROLL|ES_MULTILINE|ES_READONLY|ES_AUTOVSCROLL,' + Chr(10)
   cAllPrg += '    8,8,576,320,hDlg,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  SendMessage(hEdit,WM_SETFONT,(WPARAM)hF,TRUE);' + Chr(10)
   cAllPrg += '  hBtn = CreateWindowExA(0,"BUTTON","OK",' + Chr(10)
   cAllPrg += '    WS_CHILD|WS_VISIBLE|BS_DEFPUSHBUTTON,' + Chr(10)
   cAllPrg += '    260,340,80,28,hDlg,NULL,GetModuleHandle(NULL),NULL);' + Chr(10)
   cAllPrg += '  SendMessage(hBtn,WM_SETFONT,(WPARAM)hF,TRUE);' + Chr(10)
   cAllPrg += '  while(GetMessage(&m,NULL,0,0)) {' + Chr(10)
   cAllPrg += '    TranslateMessage(&m); DispatchMessage(&m);' + Chr(10)
   cAllPrg += '    if(m.message==WM_LBUTTONUP && m.hwnd==hBtn) break;' + Chr(10)
   cAllPrg += '    if(m.message==WM_CLOSE || m.message==WM_DESTROY) break;' + Chr(10)
   cAllPrg += '  }' + Chr(10)
   cAllPrg += '  DestroyWindow(hDlg);' + Chr(10)
   cAllPrg += '}' + Chr(10)
   cAllPrg += '#pragma ENDDUMP' + Chr(10)

   MemoWrit( cBuildDir + "\debug_main.prg", cAllPrg )

   // Step 3: Harbour compile → C
   cLog += "[3] Harbour compile..." + Chr(10)
   cCmd := cHbBin + '\harbour.exe ' + cBuildDir + '\debug_main.prg /b /n /w /q' + ;
           " /i" + cHbInc + " /i" + cBuildDir + ;
           " /o" + cBuildDir + "\debug_main.c"
   cOutput := W32_ShellExec( cCmd )
   if "Error" $ cOutput
      cLog += cOutput + Chr(10)
      lError := .T.
   else
      cLog += "    OK" + Chr(10)
   endif

   // Step 4: Compile C sources (debug_main.c)
   if ! lError
      cLog += "[4] C compile..." + Chr(10)
      if cCompiler == "msvc"
         cRspContent := "/c /Od /Zi /W0 /EHsc" + Chr(10)
         cRspContent += '/I"' + cHbInc + '"' + Chr(10)
         cRspContent += '/I"' + cMsvcInc + '"' + Chr(10)
         cRspContent += '/I"' + cUcrtInc + '"' + Chr(10)
         cRspContent += '/I"' + cUmInc + '"' + Chr(10)
         cRspContent += '/I"' + cSharedInc + '"' + Chr(10)
         cRspContent += '/I"' + cProjDir + '\include"' + Chr(10)
         cRsp := cBuildDir + "\cl_dbg.rsp"
         MemoWrit( cRsp, cRspContent + '"' + cBuildDir + '\debug_main.c"' + Chr(10) + '/Fo"' + cBuildDir + '\debug_main.obj"' )
         cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
      elseif cCompiler == "mingw"
         cCmd := cCC + ' -c -O0 -g -I' + cHbInc + ;
                 " -I" + cProjDir + "\include" + ;
                 " " + cBuildDir + "\debug_main.c" + ;
                 " -o " + cBuildDir + "\debug_main.o"
      else
         cCmd := cCC + ' -c -O0 -tW -w- -I' + cHbInc + ;
                 " -I" + cCDir + "\include" + ;
                 " -I" + cProjDir + "\include" + ;
                 " " + cBuildDir + "\debug_main.c" + ;
                 " -o" + cBuildDir + "\debug_main.obj"
      endif
      cOutput := W32_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 5: Compile dbghook.c
   if ! lError
      cLog += "[5] Compiling dbghook.c..." + Chr(10)
      if cCompiler == "msvc"
         cRsp := cBuildDir + "\cl_hook.rsp"
         MemoWrit( cRsp, cRspContent + '"' + cProjDir + '\source\debugger\dbghook.c"' + Chr(10) + '/Fo"' + cBuildDir + '\dbghook.obj"' )
         cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
      elseif cCompiler == "mingw"
         cCmd := cCC + ' -c -O2 -I' + cHbInc + ;
                 " " + cProjDir + "\source\debugger\dbghook.c" + ;
                 " -o " + cBuildDir + "\dbghook.o"
      else
         cCmd := cCC + ' -c -O2 -tW -w- -I' + cHbInc + ;
                 " -I" + cCDir + "\include" + ;
                 " " + cProjDir + "\source\debugger\dbghook.c" + ;
                 " -o" + cBuildDir + "\dbghook.obj"
      endif
      cOutput := W32_ShellExec( cCmd )
      if "error" $ Lower( cOutput ) .or. ;
         ( cCompiler == "mingw" .and. ! File( cBuildDir + "\dbghook.o" ) ) .or. ;
         ( cCompiler != "mingw" .and. ! File( cBuildDir + "\dbghook.obj" ) )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 6: Compile C++ core (same as TBRun)
   if ! lError
      cLog += "[6] Compiling C++ core..." + Chr(10)
      aCppFiles := { "tcontrol", "tform", "tcontrols", "hbbridge" }
      if cCompiler == "msvc"
         cCppBase := "/c /Od /Zi /W0 /EHsc" + Chr(10) + ;
                 '/I"' + cHbInc + '"' + Chr(10) + ;
                 '/I"' + cMsvcInc + '"' + Chr(10) + ;
                 '/I"' + cUcrtInc + '"' + Chr(10) + ;
                 '/I"' + cUmInc + '"' + Chr(10) + ;
                 '/I"' + cSharedInc + '"' + Chr(10) + ;
                 '/I"' + cProjDir + '\include"' + Chr(10)
      elseif cCompiler == "mingw"
         cCppBase := " -c -O0 -g -I" + cHbInc + ;
                 " -I" + cProjDir + "\include "
      else
         cCppBase := " -c -O2 -tW -w- -I" + cHbInc + ;
                 " -I" + cCDir + "\include" + ;
                 " -I" + cProjDir + "\include "
      endif
      for k := 1 to Len( aCppFiles )
         if cCompiler == "msvc"
            cRsp := cBuildDir + "\cl_" + aCppFiles[k] + ".rsp"
            MemoWrit( cRsp, cCppBase + '"' + cProjDir + "\source\cpp\" + aCppFiles[k] + '.cpp"' + Chr(10) + ;
                     '/Fo"' + cBuildDir + "\" + aCppFiles[k] + '.obj"' )
            cCmd := 'cmd /S /c ""' + cCC + '" @"' + cRsp + '" 2>&1"'
         elseif cCompiler == "mingw"
            cCmd := cCDir + "\bin\g++.exe" + cCppBase + ;
                    cProjDir + "\source\cpp\" + aCppFiles[k] + ".cpp" + ;
                    " -o " + cBuildDir + "\" + aCppFiles[k] + ".o"
         else
            cCmd := cCC + cCppBase + ;
                    cProjDir + "\source\cpp\" + aCppFiles[k] + ".cpp" + ;
                    " -o" + cBuildDir + "\" + aCppFiles[k] + ".obj"
         endif
         cOutput := W32_ShellExec( cCmd )
         if "error" $ Lower( cOutput )
            cLog += "    FAILED (" + aCppFiles[k] + "):" + Chr(10) + cOutput + Chr(10)
            lError := .T.
            exit
         endif
      next
      if ! lError; cLog += "    OK" + Chr(10); endif
   endif

   // Step 7: Link native executable (DebugApp.exe)
   if ! lError
      cLog += "[7] Linking DebugApp.exe..." + Chr(10)
      if cCompiler == "mingw"
         cObjs := cBuildDir + "\debug_main.o " + ;
                  cBuildDir + "\dbghook.o " + ;
                  cBuildDir + "\tcontrol.o " + ;
                  cBuildDir + "\tform.o " + ;
                  cBuildDir + "\tcontrols.o " + ;
                  cBuildDir + "\hbbridge.o"
      else
         cObjs := cBuildDir + "\debug_main.obj " + ;
                  cBuildDir + "\dbghook.obj " + ;
                  cBuildDir + "\tcontrol.obj " + ;
                  cBuildDir + "\tform.obj " + ;
                  cBuildDir + "\tcontrols.obj " + ;
                  cBuildDir + "\hbbridge.obj"
      endif
      if cCompiler == "msvc"
         cRsp := cBuildDir + "\link_dbg.rsp"
         cRspContent := ""
         cRspContent += "/NOLOGO /SUBSYSTEM:WINDOWS /NODEFAULTLIB:LIBCMT" + Chr(10)
         cRspContent += '/OUT:"' + cBuildDir + '\DebugApp.exe"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cMsvcLib + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cUcrtLib + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cUmLib + '"' + Chr(10)
         cRspContent += '/LIBPATH:"' + cHbLib + '"' + Chr(10)
         cRspContent += cObjs + Chr(10)
         cRspContent += "hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib" + Chr(10)
         cRspContent += "hbmacro.lib hbpp.lib hbcommon.lib hbcplr.lib hbct.lib" + Chr(10)
         cRspContent += "hbhsx.lib hbsix.lib hbusrrdd.lib" + Chr(10)
         cRspContent += "rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib" + Chr(10)
         cRspContent += "hbdebug.lib hbpcre.lib hbzlib.lib" + Chr(10)
         cRspContent += "hbsqlit3.lib sqlite3.lib" + Chr(10)
         cRspContent += "gtwin.lib gtwvt.lib gtgui.lib" + Chr(10)
         cRspContent += "user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib" + Chr(10)
         cRspContent += "ole32.lib oleaut32.lib advapi32.lib ws2_32.lib winmm.lib" + Chr(10)
         cRspContent += "msimg32.lib gdiplus.lib iphlpapi.lib ucrt.lib vcruntime.lib msvcrt.lib" + Chr(10)
         MemoWrit( cRsp, cRspContent )
         cCmd := 'cmd /S /c ""' + cLinker + '" @"' + cRsp + '" 2>&1"'
      elseif cCompiler == "mingw"
         cCmd := cLinker + " -static -mwindows -o " + cBuildDir + "\DebugApp.exe" + ;
                 " " + cObjs + ;
                 " -L" + cHbLib + ;
                 " -Wl,--start-group" + ;
                 " -lhbvm -lhbrtl -lhbcommon -lhblang -lhbrdd" + ;
                 " -lhbmacro -lhbpp -lhbcpage -lhbcplr -lhbct" + ;
                 " -lhbhsx -lhbsix -lhbusrrdd" + ;
                 " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
                 " -lhbdebug -lhbpcre -lhbzlib" + ;
                 " -lhbsqlit3 -lsqlite3" + ;
                 " -lgtgui -lgtwin -lgtwvt" + ;
                 " -Wl,--end-group" + ;
                 " -luser32 -lgdi32 -lcomctl32 -lcomdlg32 -lshell32" + ;
                 " -lole32 -loleaut32 -ladvapi32 -lws2_32 -lwinmm" + ;
                 " -lmsimg32 -lgdiplus -liphlpapi -luuid -lwinspool -lstdc++"
      else
         cObjs := "c0w32.obj " + cObjs
         cCmd := cLinker + ' -Gn -aa -Tpe' + ;
                 " -L" + cCDir + "\lib" + ;
                 " -L" + cCDir + "\lib\psdk" + ;
                 " -L" + cHbLib + ;
                 " " + cObjs + "," + ;
                 " " + cBuildDir + "\DebugApp.exe,," + ;
                 " hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib" + ;
                 " hbmacro.lib hbpp.lib hbcommon.lib hbcplr.lib hbct.lib" + ;
                 " hbhsx.lib hbsix.lib hbusrrdd.lib" + ;
                 " rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib" + ;
                 " hbdebug.lib hbpcre.lib hbzlib.lib" + ;
                 " hbsqlit3.lib sqlite3.lib" + ;
                 " gtwin.lib gtwvt.lib gtgui.lib" + ;
                 " cw32mt.lib import32.lib ws2_32.lib winmm.lib iphlpapi.lib" + ;
                 " user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib" + ;
                 " ole32.lib oleaut32.lib uuid.lib advapi32.lib" + ;
                 " msimg32.lib gdiplus.lib,,"
      endif
      cOutput := W32_ShellExec( cCmd )
      if ! File( cBuildDir + "\DebugApp.exe" )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   if lError
      W32_BuildErrorDialog( "Debug Build Failed", cLog )
      return nil
   endif

   // Step 8: Launch socket-based debug session
   cLog += "[8] Launching socket debugger..." + Chr(10)
   cLog += "    Exe: " + cBuildDir + "\DebugApp.exe" + Chr(10)
   cLog += "    Exists: " + iif( File( cBuildDir + "\DebugApp.exe" ), "YES", "NO" ) + Chr(10)
   MemoWrit( cBuildDir + "\debug_trace.log", cLog )

   // Hide design form during debug
   if oDesignForm != nil
      W32_ShowWindow( UI_FormGetHwnd( oDesignForm:hCpp ), 0 )  // SW_HIDE
   endif
   W32_ProcessEvents()

   // Switch inspector to debug mode (Vars/CallStack/Watch)
   InspectorOpen()
   W32_ProcessEvents()
   INS_SetDebugMode( _InsGetData(), .t. )
   W32_ProcessEvents()
   CodeEditorSelectTab( hCodeEditor, 1 )
   W32_ProcessEvents()

   IDE_DebugStart2( cBuildDir + "\DebugApp.exe", ;
      { |cFunc, nLine, cLocals, cStack| OnDebugPause( cFunc, nLine, cLocals, cStack ) } )

   // Restore: clear debug marker, restore inspector with properties
   CodeEditorShowDebugLine( hCodeEditor, 0 )
   INS_SetDebugMode( _InsGetData(), .f. )
   W32_ProcessEvents()
   if oDesignForm != nil
      InspectorPopulateCombo( oDesignForm:hCpp )
      InspectorRefresh( oDesignForm:hCpp )
      W32_ShowWindow( UI_FormGetHwnd( oDesignForm:hCpp ), 5 )  // SW_SHOW
      // Switch editor to the active form's code tab
      CodeEditorSelectTab( hCodeEditor, nActiveForm + 1 )
   endif
   W32_ProcessEvents()

return nil

// === Debug Pause Callback (called from socket command loop) ===

static function DbgLog2( cMsg )
   local nH := FOpen( "c:\hbbuilder_debug\pause_trace.log", 1 + 16 )
   if nH == -1; nH := FCreate( "c:\hbbuilder_debug\pause_trace.log" ); endif
   if nH >= 0
      FSeek( nH, 0, 2 )
      FWrite( nH, cMsg + Chr(13) + Chr(10) )
      FClose( nH )
   endif
return nil

static function OnDebugPause( cFunc, nLine, cLocals, cStack )

   local i, nTab, nTabLine, hIns

   // Map debug_main.prg line number to the correct editor tab and line
   nTab := 0
   nTabLine := 0
   if aDbgOffsets != nil
      for i := Len( aDbgOffsets ) to 1 step -1
         if nLine >= aDbgOffsets[i][1]
            nTab := aDbgOffsets[i][3]
            nTabLine := nLine - aDbgOffsets[i][1] + aDbgOffsets[i][4]
            exit
         endif
      next
   endif

   // Append trace
   DbgLog2( "OnDebugPause: func=" + cFunc + " line=" + LTrim(Str(nLine)) + ;
      " -> tab=" + LTrim(Str(nTab)) + " tabLine=" + LTrim(Str(nTabLine)) )

   // Framework code (nTab == 0) — skip, don't pause, don't update
   if nTab == 0
      return .f.
   endif


   DbgLog2( "  step A: SelectTab" )
   if nTabLine > 0
      CodeEditorSelectTab( hCodeEditor, nTab )
      DbgLog2( "  step B: ShowDebugLine(" + LTrim(Str(nTabLine)) + ")" )
      CodeEditorShowDebugLine( hCodeEditor, nTabLine )
      DbgLog2( "  step C: ShowDebugLine done" )
   endif

   DbgLog2( "  step D: MapLocalNames" )
   if cLocals != nil .and. nTab > 0
      cLocals := DbgMapLocalNames( cLocals, cFunc, nTab )
   endif

   // Update inspector with locals and call stack
   DbgLog2( "  step E: UpdateInspector" )
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

// === AI Assistant (Ollama / LM Studio) ===

static function ShowAIAssistant()

   // Check if Ollama is running before opening the panel
   local cResult := W32_ShellExec( 'curl -s http://localhost:11434/api/tags 2>nul' )

   if Empty( cResult ) .or. ! ( "models" $ cResult )
      // Ollama not detected - offer to help
      MsgInfo( "Ollama is not running!" + Chr(10) + ;
               Chr(10) + ;
               "The AI Assistant requires Ollama for local AI." + Chr(10) + ;
               Chr(10) + ;
               "To install Ollama:" + Chr(10) + ;
               "1. Download from https://ollama.com/download" + Chr(10) + ;
               "2. Run the installer" + Chr(10) + ;
               "3. Open a terminal and run: ollama pull codellama" + Chr(10) + ;
               "4. Restart HbBuilder and try again" + Chr(10) + ;
               Chr(10) + ;
               "The AI Assistant will open anyway for preview.", ;
               "Ollama Not Detected" )
   endif

   W32_AIAssistantPanel()

return nil

// === C Compiler Not Found Dialog ===

static function ShowNoCompilerDialog()

   if MsgYesNo( "No C/C++ compiler found!" + Chr(10) + Chr(10) + ;
                "HbBuilder needs a C compiler to build projects." + Chr(10) + ;
                "You can install one of these (all free):" + Chr(10) + Chr(10) + ;
                "  1. Visual Studio Build Tools (recommended)" + Chr(10) + ;
                "     visualstudio.microsoft.com/downloads" + Chr(10) + ;
                "     (select 'Desktop development with C++')" + Chr(10) + Chr(10) + ;
                "  2. Embarcadero C++ Builder / BCC" + Chr(10) + ;
                "     www.embarcadero.com/free-tools" + Chr(10) + Chr(10) + ;
                "  3. MinGW / TDM-GCC" + Chr(10) + ;
                "     jmeubank.github.io/tdm-gcc/" + Chr(10) + Chr(10) + ;
                "Open the Visual Studio download page now?", ;
                "C Compiler Not Found" )
      W32_ShellExec( 'cmd /c start "" "https://visualstudio.microsoft.com/downloads/"' )
   endif

return nil

// === Harbour Detection & Auto-Install ===

// Find a file inside Harbour dir, trying: dir\sub\win\compiler, dir\sub\win, dir\sub
// e.g. FindHarbourSub( "c:\harbour", "lib", "msvc", "hbrtl.lib" )
// tries: c:\harbour\lib\win\msvc\hbrtl.lib, c:\harbour\lib\win\hbrtl.lib, c:\harbour\lib\hbrtl.lib
static function FindHarbourSub( cHbDir, cCategory, cComp, cFile )

   if File( cHbDir + "\" + cCategory + "\win\" + cComp + "\" + cFile )
      return cHbDir + "\" + cCategory + "\win\" + cComp
   endif
   if File( cHbDir + "\" + cCategory + "\win\" + cFile )
      return cHbDir + "\" + cCategory + "\win"
   endif
   if File( cHbDir + "\" + cCategory + "\" + cFile )
      return cHbDir + "\" + cCategory
   endif

return cHbDir + "\" + cCategory + "\win\" + cComp  // fallback to standard path

static function FindHarbour( cCompiler )

   local aPaths, cSub, i, cPath
   local cUserProfile := GetEnv( "USERPROFILE" )

   cSub := iif( cCompiler == "msvc", "bin\win\msvc", ;
            iif( cCompiler == "mingw", "bin\win\mingw", "bin\win\bcc" ) )

   aPaths := { ;
      "c:\harbour", ;
      cUserProfile + "\harbour", ;
      "c:\hb32", ;
      "c:\hb", ;
      HB_DirBase() + "..\harbour", ;
      "c:\Program Files\harbour", ;
      "c:\Program Files (x86)\harbour", ;
      cUserProfile + "\.harbour", ;
      "d:\harbour" }

   for i := 1 to Len( aPaths )
      cPath := aPaths[i]
      if File( cPath + "\" + cSub + "\harbour.exe" ) .or. ;
         File( cPath + "\bin\harbour.exe" )
         return cPath
      endif
   next

return ""

static function EnsureHarbour( cCompiler, aCI )

   local cHbDir, cHbSrc, cOutput, cCmd, cCDir, cDiag
   local cMsvcBase, cWinKit, cWinKitVer
   local cZipFile, cBatFile, lHasGit, lOk
   local cTmp := GetEnv( "TEMP" )
   local cUserProfile := GetEnv( "USERPROFILE" )
   static lBusy := .F.

   // Prevent re-entry if already downloading/building
   if lBusy
      MsgInfo( "Harbour is already being downloaded and built." + Chr(10) + ;
               "Please wait for it to finish.", "Please Wait" )
      return ""
   endif

   // First try to find an existing Harbour installation
   cHbDir := FindHarbour( cCompiler )
   if ! Empty( cHbDir )
      return cHbDir
   endif

   // Install to user profile (no admin needed), source also in user profile
   // (%TEMP% has permission issues with MSVC compiler output)
   cHbDir := cUserProfile + "\harbour"
   cHbSrc := cUserProfile + "\harbour_src"

   if ! MsgYesNo( "Harbour compiler not found!" + Chr(10) + ;
                  Chr(10) + ;
                  "HbBuilder needs Harbour to compile projects." + Chr(10) + ;
                  Chr(10) + ;
                  "Download from GitHub and build it now?" + Chr(10) + ;
                  "(This may take several minutes)", ;
                  "Harbour Not Found" )
      return ""
   endif

   lBusy := .T.

   // Step 1: Download Harbour source
   if ! File( cHbSrc + "\config\global.mk" )
      // Check if git is available
      lHasGit := File( "c:\Program Files\Git\cmd\git.exe" ) .or. ;
                 File( "c:\Program Files (x86)\Git\cmd\git.exe" )
      if ! lHasGit
         // Also check PATH
         cOutput := W32_ShellExec( "cmd /c where git 2>&1" )
         lHasGit := "git" $ Lower( cOutput ) .and. ! ( "not found" $ Lower( cOutput ) )
      endif

      cBatFile := cTmp + "\hb_download.bat"

      if lHasGit
         // Use git clone (faster, shallow)
         MemoWrit( cBatFile, ;
            "@echo off" + Chr(10) + ;
            'git clone --depth 1 https://github.com/harbour/core.git "' + cHbSrc + '"' + Chr(10) )
         cOutput := W32_RunBatchWithProgress( cBatFile, ;
            "Downloading Harbour...", ;
            "Cloning harbour/core from GitHub..." )
      else
         // No git — download zip via PowerShell
         cZipFile := cTmp + "\harbour_src.zip"
         MemoWrit( cBatFile, ;
            "@echo off" + Chr(10) + ;
            "powershell -NoProfile -Command " + Chr(34) + ;
               "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " + ;
               "Invoke-WebRequest -Uri " + Chr(39) + "https://github.com/harbour/core/archive/refs/heads/master.zip" + Chr(39) + " " + ;
               "-OutFile " + Chr(39) + cZipFile + Chr(39) + ;
            Chr(34) + Chr(10) + ;
            "if not exist " + Chr(34) + cZipFile + Chr(34) + " exit /b 1" + Chr(10) + ;
            "powershell -NoProfile -Command " + Chr(34) + ;
               "Expand-Archive -Path " + Chr(39) + cZipFile + Chr(39) + " " + ;
               "-DestinationPath " + Chr(39) + cTmp + "\harbour_tmp" + Chr(39) + " -Force" + ;
            Chr(34) + Chr(10) + ;
            "move " + Chr(34) + cTmp + "\harbour_tmp\core-master" + Chr(34) + " " + Chr(34) + cHbSrc + Chr(34) + Chr(10) + ;
            "rd /s /q " + Chr(34) + cTmp + "\harbour_tmp" + Chr(34) + " 2>nul" + Chr(10) + ;
            "del " + Chr(34) + cZipFile + Chr(34) + " 2>nul" + Chr(10) )
         cOutput := W32_RunBatchWithProgress( cBatFile, ;
            "Downloading Harbour...", ;
            "Downloading harbour/core.zip from GitHub..." )
      endif

      if ! File( cHbSrc + "\config\global.mk" )
         lBusy := .F.
         W32_BuildErrorDialog( "Download Failed", ;
            "Failed to download Harbour source." + Chr(10) + Chr(10) + ;
            "Check your internet connection and try again." + Chr(10) + ;
            Chr(10) + "Output:" + Chr(10) + cOutput )
         return ""
      endif
   endif

   // Step 2: Write build batch for detected compiler
   lOk := .F.

   if cCompiler == "msvc"
      cMsvcBase  := aCI[4]
      cWinKitVer := aCI[5]
      cWinKit    := "c:\Program Files (x86)\Windows Kits\10"

      MemoWrit( cHbSrc + "\hb_build.bat", ;
         "@echo off" + Chr(10) + ;
         "cd /d " + cHbSrc + Chr(10) + ;
         "set PATH=" + cMsvcBase + "\bin\Hostx86\x86;" + ;
            cWinKit + "\bin\" + cWinKitVer + "\x86;%PATH%" + Chr(10) + ;
         "set INCLUDE=" + cMsvcBase + "\include;" + ;
            cWinKit + "\Include\" + cWinKitVer + "\ucrt;" + ;
            cWinKit + "\Include\" + cWinKitVer + "\um;" + ;
            cWinKit + "\Include\" + cWinKitVer + "\shared" + Chr(10) + ;
         "set LIB=" + cMsvcBase + "\lib\x86;" + ;
            cWinKit + "\Lib\" + cWinKitVer + "\ucrt\x86;" + ;
            cWinKit + "\Lib\" + cWinKitVer + "\um\x86" + Chr(10) + ;
         "set HB_INSTALL_PREFIX=" + cHbDir + Chr(10) + ;
         "win-make.exe install" + Chr(10) )
   else
      cCDir := aCI[4]
      MemoWrit( cHbSrc + "\hb_build.bat", ;
         "@echo off" + Chr(10) + ;
         "cd /d " + cHbSrc + Chr(10) + ;
         "set PATH=" + cCDir + "\bin;%PATH%" + Chr(10) + ;
         "set HB_COMPILER=bcc" + Chr(10) + ;
         "set HB_INSTALL_PREFIX=" + cHbDir + Chr(10) + ;
         "win-make.exe install" + Chr(10) )
   endif

   // Step 3: Build Harbour (with animated marquee progress bar)
   cOutput := W32_RunBatchWithProgress( cHbSrc + "\hb_build.bat", ;
      "Building Harbour...", ;
      "Compiling with " + aCI[2] + " (this may take several minutes)..." )

   lBusy := .F.

   // Step 4: Verify — check multiple possible locations
   lOk := .F.
   if cCompiler == "msvc"
      lOk := File( cHbDir + "\bin\win\msvc\harbour.exe" ) .or. ;
             File( cHbDir + "\bin\harbour.exe" )
   else
      lOk := File( cHbDir + "\bin\win\bcc\harbour.exe" ) .or. ;
             File( cHbDir + "\bin\harbour.exe" )
   endif

   if lOk
      MsgInfo( "Harbour installed successfully!" + Chr(10) + Chr(10) + ;
               "Location: " + cHbDir, "Installation Complete" )
      return cHbDir
   endif

   // Build diagnostic info for the error dialog
   cDiag := "Harbour build did not produce the expected files." + Chr(10)
   cDiag += "Compiler: " + aCI[2] + Chr(10)
   cDiag += "Install prefix: " + cHbDir + Chr(10)
   cDiag += "Source dir: " + cHbSrc + Chr(10) + Chr(10)
   cDiag += "Expected:" + Chr(10)
   if cCompiler == "msvc"
      cDiag += "  " + cHbDir + "\bin\win\msvc\harbour.exe" + Chr(10)
   else
      cDiag += "  " + cHbDir + "\bin\win\bcc\harbour.exe" + Chr(10)
   endif
   cDiag += Chr(10) + "Checked paths:" + Chr(10)
   cDiag += "  bin\win\msvc\harbour.exe -> " + iif( File( cHbDir + "\bin\win\msvc\harbour.exe" ), "FOUND", "not found" ) + Chr(10)
   cDiag += "  bin\win\bcc\harbour.exe  -> " + iif( File( cHbDir + "\bin\win\bcc\harbour.exe" ), "FOUND", "not found" ) + Chr(10)
   cDiag += "  bin\harbour.exe          -> " + iif( File( cHbDir + "\bin\harbour.exe" ), "FOUND", "not found" ) + Chr(10)
   cDiag += "  include\hbapi.h          -> " + iif( File( cHbDir + "\include\hbapi.h" ), "FOUND", "not found" ) + Chr(10)
   cDiag += "  lib\win\msvc\hbvm.lib    -> " + iif( File( cHbDir + "\lib\win\msvc\hbvm.lib" ), "FOUND", "not found" ) + Chr(10)
   cDiag += "  lib\win\bcc\hbvm.lib     -> " + iif( File( cHbDir + "\lib\win\bcc\hbvm.lib" ), "FOUND", "not found" ) + Chr(10)
   cDiag += Chr(10) + "Build output (last 2000 chars):" + Chr(10) + Right( cOutput, 2000 )

   W32_BuildErrorDialog( "Harbour Build Failed", cDiag )

return ""

// === Dark Mode Toggle ===

static function ToggleDarkMode()

   lDarkMode := ! lDarkMode

   // Update global C flag + checkmark
   W32_SetIDEDarkMode( lDarkMode )
   W32_MenuCheck( hToolsPopup, 2, lDarkMode )

   // Save to INI
   IniWrite( "IDE", "DarkMode", iif( lDarkMode, "1", "0" ) )

   // Apply dark/light to IDE bar
   W32_SetWindowDarkMode( UI_FormGetHwnd( oIDE:hCpp ), lDarkMode )
   if lDarkMode
      UI_FormSetBgColor( oIDE:hCpp, 45 + 45 * 256 + 48 * 65536 )
      W32_SetAppDarkMode( .T. )
   else
      UI_FormSetBgColor( oIDE:hCpp, GetSysColor( 15 ) )  // COLOR_BTNFACE = 15
      W32_SetAppDarkMode( .F. )
   endif

   // Apply to design form
   if oDesignForm != nil
      if lDarkMode
         UI_FormSetBgColor( oDesignForm:hCpp, 45 + 45 * 256 + 45 * 65536 )
      else
         UI_FormSetBgColor( oDesignForm:hCpp, GetSysColor( 15 ) )
      endif
   endif

   // Refresh inspector theme
   if _InsGetData() != 0
      INS_RefreshTheme( _InsGetData() )
   endif

   // Repaint IDE bar + all children (toolbars, palette)
   W32_RedrawAll( UI_FormGetHwnd( oIDE:hCpp ) )

   // Refresh code editor: title bar + tabs + status bar
   if hCodeEditor != nil .and. hCodeEditor != 0
      CodeEditorRefreshTheme( hCodeEditor, lDarkMode )
   endif

   // Refresh design form title bar
   if oDesignForm != nil
      W32_SetWindowDarkMode( UI_FormGetHwnd( oDesignForm:hCpp ), lDarkMode )
   endif

return nil

static function IniWrite( cSection, cKey, cValue )

   local cFile := HB_DirBase() + "..\hbbuilder.ini"
   local cContent, cLine, aLines, i, lFound, cSearch

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

   local cFile := HB_DirBase() + "..\hbbuilder.ini"
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

// === Debug Helper Functions ===

// Convert stack line numbers from debug_main.prg to editor tab line numbers
static function DbgFixStackLines( cStack )
   local cOut := "STACK", cToken, nPos, nLine, nTabLine, i, nP1, nP2

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

      nP1 := At( "(", cToken )
      nP2 := At( ")", cToken )
      if nP1 > 0 .and. nP2 > nP1
         nLine := Val( SubStr( cToken, nP1 + 1, nP2 - nP1 - 1 ) )
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

// Replace "localN" with real variable names from source code
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
      if ! lInFunc
         if ( "PROCEDURE " $ cTrim .or. "FUNCTION " $ cTrim .or. "METHOD " $ cTrim ) .and. ;
            Upper( cFunc ) $ cTrim
            lInFunc := .t.
         endif
         loop
      endif
      if Left( cTrim, 6 ) == "LOCAL "
         cLine := AllTrim( SubStr( AllTrim( aLines[i] ), 7 ) )
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
         exit
      endif
   next

   // Replace "localN" with real names
   for i := 1 to Len( aNames )
      cVars := StrTran( cVars, "local" + LTrim(Str(i)) + "=", aNames[i] + "=" )
   next

   // Remove unmapped extras
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

// === Git Integration ===

static function GitInit()
   local cDir := cCurrentFile
   if Empty( cDir )
      cDir := HB_DirBase() + "..\"
   else
      cDir := SubStr( cDir, 1, RAt( "\", cDir ) )
   endif
   GIT_Exec( "init", cDir )
   MsgInfo( "Git repository initialized in " + cDir )
return nil

static function GitClone()
   local cUrl := ""
   // TODO: input dialog for URL
   MsgInfo( "Use: git clone <url> from the terminal" )
return nil

static function GitShowPanel()
   W32_GitPanel()
   GitRefreshPanel()
return nil

function GitRefreshPanel()
   local cDir, aChanges, cBranch
   cDir := HB_DirBase() + "..\"
   if ! GIT_IsRepo( cDir )
      W32_GitSetBranch( "(not a git repo)" )
      return nil
   endif
   cBranch := GIT_CurrentBranch( cDir )
   W32_GitSetBranch( cBranch )
   aChanges := GIT_Status( cDir )
   W32_GitSetChanges( aChanges )
return nil

function GitCommit()
   local cMsg, cDir, cOutput
   cDir := HB_DirBase() + "..\"
   cMsg := W32_GitGetMessage()
   if Empty( cMsg )
      MsgInfo( "Please enter a commit message" )
      return nil
   endif
   // Stage all changes
   GIT_Exec( "add -A", cDir )
   // Commit
   cOutput := GIT_Exec( 'commit -m "' + cMsg + '"', cDir )
   W32_GitClearMessage()
   GitRefreshPanel()
   MsgInfo( cOutput )
return nil

function GitPush()
   local cDir := HB_DirBase() + "..\"
   local cOutput := GIT_Exec( "push", cDir )
   MsgInfo( iif( Empty(cOutput), "Push completed", cOutput ) )
   GitRefreshPanel()
return nil

function GitPull()
   local cDir := HB_DirBase() + "..\"
   local cOutput := GIT_Exec( "pull", cDir )
   MsgInfo( iif( Empty(cOutput), "Already up to date", cOutput ) )
   GitRefreshPanel()
return nil

static function GitBranchCreate()
   local cName := ""
   // TODO: input dialog
   MsgInfo( "Use: Git > Status panel or terminal to create branches" )
return nil

static function GitBranchSwitch()
   local cDir := HB_DirBase() + "..\"
   local aBranches := GIT_BranchList( cDir )
   local aNames := {}, i, nSel
   for i := 1 to Len( aBranches )
      AAdd( aNames, iif( aBranches[i][2], "* ", "  " ) + aBranches[i][1] )
   next
   if Len( aNames ) == 0
      MsgInfo( "No branches found" )
      return nil
   endif
   nSel := W32_SelectFromList( "Switch Branch", aNames )
   if nSel > 0
      GIT_Exec( "checkout " + AllTrim( aBranches[nSel][1] ), cDir )
      GitRefreshPanel()
   endif
return nil

static function GitMerge()
   MsgInfo( "Use: git merge <branch> from the terminal" )
return nil

static function GitStash()
   local cDir := HB_DirBase() + "..\"
   GIT_Exec( "stash", cDir )
   GitRefreshPanel()
   MsgInfo( "Changes stashed" )
return nil

static function GitStashPop()
   local cDir := HB_DirBase() + "..\"
   local cOutput := GIT_Exec( "stash pop", cDir )
   GitRefreshPanel()
   MsgInfo( iif( Empty(cOutput), "Stash popped", cOutput ) )
return nil

static function GitLogShow()
   local cDir := HB_DirBase() + "..\"
   local aLog := GIT_Log( 30, cDir )
   local cText := "", i
   for i := 1 to Len( aLog )
      cText += SubStr( aLog[i][1], 1, 7 ) + " " + ;
               aLog[i][3] + " " + aLog[i][4] + Chr(13) + Chr(10)
   next
   MsgInfo( iif( Empty(cText), "No commits found", cText ), "Git Log" )
return nil

static function GitDiffShow()
   local cDir := HB_DirBase() + "..\"
   local cDiff := GIT_Diff( "", cDir )
   MsgInfo( iif( Empty(cDiff), "No changes", Left(cDiff, 2000) ), "Git Diff" )
return nil

static function GitBlameShow()
   MsgInfo( "Select a file first, then use Git > Blame" )
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

   W32_AboutDialog( "About HbBuilder", cMsg, HB_DirBase() + "..\resources\harbour_logo.png" )

return nil

// === Report Designer ===

static function OpenReportDesigner()

   RPT_DesignerOpen()

   // Add default bands if empty
   if RPT_GetSelected()[1] < 0
      RPT_AddBand( "Header", 60 )
      RPT_AddField( 0, "Title", "Report Title", 10, 10, 180, 20 )
      RPT_AddBand( "Detail", 80 )
      RPT_AddField( 1, "Field1", "", 10, 10, 80, 16 )
      RPT_AddField( 1, "Field2", "", 100, 10, 80, 16 )
      RPT_AddBand( "Footer", 40 )
   endif

return nil

// === Form Designer: Undo, Copy, Paste, Tab Order ===

static function UndoDesign()
   if oDesignForm != nil
      UI_FormUndo( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil

static function CopyControls()
   if oDesignForm != nil
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormCopySelected( oDesignForm:hCpp )
   endif
return nil

static function PasteControls()
   if oDesignForm != nil
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormPasteControls( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil

static function TabOrderDialog()
   if oDesignForm != nil
      UI_FormTabOrderDialog( oDesignForm:hCpp )
   endif
return nil

// === Format > Align Controls ===

static function AlignControls( nMode )
   if oDesignForm != nil
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormAlignSelected( oDesignForm:hCpp, nMode )
      SyncDesignerToCode()
   endif
return nil

// === Save As ===

static function TBSaveAs()
   cCurrentFile := ""
   TBSave()
return nil

// === Add/Remove from Project ===

static function AddToProject()
   local cFile := W32_OpenFileDialog( "Add File to Project", "Project1.prg", "prg" )
   local cName, cCode, i
   if Empty( cFile ); return nil; endif
   cName := SubStr( cFile, RAt( "\", cFile ) + 1 )
   if "." $ cName
      cName := Left( cName, At( ".", cName ) - 1 )
   endif
   for i := 1 to Len( aForms )
      if Lower( aForms[i][1] ) == Lower( cName )
         MsgInfo( cName + " is already in the project" )
         return nil
      endif
   next
   cCode := MemoRead( cFile )
   if Empty( cCode )
      cCode := "// " + cName + ".prg" + Chr(10)
   endif
   CodeEditorAddTab( hCodeEditor, cName + ".prg" )
   CodeEditorSetTabText( hCodeEditor, Len(aForms) + 2, cCode )
   CodeEditorSelectTab( hCodeEditor, Len(aForms) + 2 )
   CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
return nil

static function RemoveFromProject()
   local aNames := {}, i, nSel
   if Len( aForms ) <= 1
      MsgInfo( "Cannot remove the last form" )
      return nil
   endif
   for i := 1 to Len( aForms )
      AAdd( aNames, aForms[i][1] + ".prg" )
   next
   nSel := W32_SelectFromList( "Remove from Project", aNames )
   if nSel > 0 .and. nSel <= Len( aForms )
      aForms[nSel][2]:Destroy()
      ADel( aForms, nSel )
      ASize( aForms, Len(aForms) - 1 )
      if nActiveForm > Len( aForms )
         nActiveForm := Len( aForms )
      endif
      CodeEditorClearTabs( hCodeEditor )
      CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
      for i := 1 to Len( aForms )
         CodeEditorAddTab( hCodeEditor, aForms[i][1] + ".prg" )
         CodeEditorSetTabText( hCodeEditor, i + 1, aForms[i][3] )
      next
      SwitchToForm( nActiveForm )
   endif
return nil

// === Components ===

static function InstallComponent()
   local cFile := W32_OpenFileDialog( "Install Component (.prg)", "*.prg", "prg" )
   local cName
   if Empty( cFile ); return nil; endif
   cName := SubStr( cFile, RAt( "\", cFile ) + 1 )
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

// MsgInfo() is now in classes.prg (cross-platform)

// Helper for inspector: get current editor code for handler name resolution
function _InsGetEditorCode()

   if hCodeEditor != nil .and. nActiveForm > 0
      return CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   endif

return ""

static function IsNonVisual( nType )
   // Visual controls that have high CT_* numbers
   // CT_BROWSE=79, CT_DBGRID=80, CT_DBNAVIGATOR=81, CT_DBTEXT=82,
   // CT_DBEDIT=83, CT_DBCOMBOBOX=84, CT_DBCHECKBOX=85, CT_DBIMAGE=86,
   // CT_WEBVIEW=62
   if nType == 62 .or. ( nType >= 79 .and. nType <= 86 )
      return .F.
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
      case nType == 63;  return "CT_WEBSERVER"
      case nType == 64;  return "CT_WEBSOCKET"
      case nType == 65;  return "CT_HTTPCLIENT"
      case nType == 131; return "CT_COMPARRAY"
   endcase
return "CT_UNKNOWN_" + LTrim( Str( nType ) )

// Reverse map: CT_* define name -> numeric type. Used when parsing saved
// form code that emitted symbolic CT_ names instead of literal numbers.
static function ComponentTypeFromName( cName )
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
      { "CT_COMPARRAY", 131 } }
   for i := 1 to Len( aMap )
      if Upper( cName ) == aMap[i][1]
         return aMap[i][2]
      endif
   next
return 0

// Framework
#include "core/classes.prg"
#include "inspector/inspector_win.prg"

#pragma BEGINDUMP
#include <hbapi.h>
#include <hbapiitm.h>
#include <windows.h>
#include <commctrl.h>
#include <richedit.h>
#include <commdlg.h>
#include <shlobj.h>
#include <ctype.h>
#include <stdio.h>

/* GDI+ flat API for C (no C++ headers needed) */
typedef struct { UINT32 GdiplusVersion; void *DebugEventCallback;
   BOOL SuppressBackgroundThread; BOOL SuppressExternalCodecs; } GdiplusStartupInput;
typedef int GpStatus;
typedef void GpImage;
typedef void GpGraphics;
extern GpStatus __stdcall GdiplusStartup(ULONG_PTR*,const GdiplusStartupInput*,void*);
extern void    __stdcall GdiplusShutdown(ULONG_PTR);
extern GpStatus __stdcall GdipCreateFromHDC(HDC,GpGraphics**);
extern GpStatus __stdcall GdipDeleteGraphics(GpGraphics*);
extern GpStatus __stdcall GdipLoadImageFromFile(const WCHAR*,GpImage**);
extern GpStatus __stdcall GdipDisposeImage(GpImage*);
extern GpStatus __stdcall GdipGetImageWidth(GpImage*,UINT*);
extern GpStatus __stdcall GdipGetImageHeight(GpImage*,UINT*);
extern GpStatus __stdcall GdipDrawImageRectI(GpGraphics*,GpImage*,INT,INT,INT,INT);

static ULONG_PTR s_gdipToken = 0;

static void EnsureGdiPlus(void)
{
   if( !s_gdipToken ) {
      GdiplusStartupInput si = {1,NULL,FALSE,FALSE};
      GdiplusStartup( &s_gdipToken, &si, NULL );
   }
}

/* W32_DebugPanel() - implemented in hbbridge.cpp */

/* W32_ProjectInspector( aItems ) - show project tree */
static LRESULT CALLBACK ProjInsWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg ) {
      case WM_SIZE: {
         HWND hTree = GetWindow(hWnd, GW_CHILD);
         if( hTree ) {
            RECT rc; GetClientRect(hWnd, &rc);
            MoveWindow(hTree, 0, 0, rc.right, rc.bottom, TRUE);
         }
         return 0;
      }
      case WM_CLOSE:
         ShowWindow(hWnd, SW_HIDE);
         return 0;
   }
   return DefWindowProc(hWnd, msg, wParam, lParam);
}

HB_FUNC( W32_PROJECTINSPECTOR )
{
   static HWND s_hProjWnd = NULL;
   static BOOL bReg = FALSE;
   PHB_ITEM pArray = hb_param(1, HB_IT_ARRAY);
   HWND hTree, hOwner;
   HFONT hFont;
   int i, nCount;
   RECT rc;
   TVINSERTSTRUCT tvis;
   HTREEITEM hRoot, hParent;
   WNDCLASSA wc = {0};

   if( s_hProjWnd && IsWindow(s_hProjWnd) ) {
      SetWindowPos(s_hProjWnd,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE);
      ShowWindow(s_hProjWnd, SW_SHOW);
      return;
   }

   if( !bReg ) {
      wc.lpfnWndProc = ProjInsWndProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.hCursor = LoadCursor(NULL, IDC_ARROW);
      wc.hbrBackground = (HBRUSH)(COLOR_WINDOW+1);
      wc.lpszClassName = "HbProjInspector";
      RegisterClassA(&wc);
      bReg = TRUE;
   }

   hOwner = GetActiveWindow();
   GetWindowRect(hOwner,&rc);

   s_hProjWnd = CreateWindowExA(WS_EX_TOOLWINDOW,
      "HbProjInspector","Project Inspector",
      WS_POPUP|WS_CAPTION|WS_SYSMENU|WS_THICKFRAME|WS_VISIBLE,
      rc.right-260, rc.top+80, 250, 400,
      NULL,NULL,GetModuleHandle(NULL),NULL);

   hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

   hTree = CreateWindowExA(WS_EX_CLIENTEDGE,WC_TREEVIEWA,NULL,
      WS_CHILD|WS_VISIBLE|TVS_HASLINES|TVS_LINESATROOT|TVS_HASBUTTONS|TVS_SHOWSELALWAYS,
      0,0,250,380,s_hProjWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hTree,WM_SETFONT,(WPARAM)hFont,TRUE);

   /* Populate tree */
   if( pArray ) {
      nCount = (int)hb_arrayLen(pArray);
      hRoot = TVI_ROOT; hParent = NULL;
      for( i = 1; i <= nCount; i++ ) {
         const char * text = hb_arrayGetCPtr(pArray, i);
         memset(&tvis,0,sizeof(tvis));
         if( text[0] == ' ' ) {
            tvis.hParent = hParent ? hParent : TVI_ROOT;
            tvis.item.pszText = (char*)(text+2);
         } else {
            tvis.hParent = TVI_ROOT;
            tvis.item.pszText = (char*)text;
         }
         tvis.hInsertAfter = TVI_LAST;
         tvis.item.mask = TVIF_TEXT;
         { HTREEITEM h = (HTREEITEM)SendMessageA(hTree,TVM_INSERTITEMA,0,(LPARAM)&tvis);
           if( !hParent && text[0] != ' ' ) hParent = h;
         }
      }
      /* Expand root */
      if( hParent )
         SendMessage(hTree,TVM_EXPAND,TVE_EXPAND,(LPARAM)hParent);
   }
}

/* W32_AIAssistantPanel() - AI coding assistant with Ollama/LM Studio */
HB_FUNC( W32_AIASSISTANTPANEL )
{
   static HWND s_hAIWnd = NULL;
   HWND hOwner, hOutput, hInput, hSend, hModel, hLbl;
   HFONT hFont, hMonoFont;
   RECT rc;
   LOGFONTA lf = {0};

   if( s_hAIWnd && IsWindow(s_hAIWnd) ) {
      SetWindowPos(s_hAIWnd,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE);
      return;
   }

   hOwner = GetActiveWindow();
   GetWindowRect(hOwner, &rc);
   hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

   /* Monospace font for chat */
   lf.lfHeight = -18; lf.lfCharSet = DEFAULT_CHARSET;
   lf.lfPitchAndFamily = FIXED_PITCH;
   lstrcpyA(lf.lfFaceName, "Consolas");
   hMonoFont = CreateFontIndirectA(&lf);

   s_hAIWnd = CreateWindowExA(WS_EX_TOOLWINDOW,
      "STATIC","AI Assistant (Ollama)",
      WS_POPUP|WS_CAPTION|WS_SYSMENU|WS_THICKFRAME|WS_VISIBLE,
      rc.right-420, rc.top+80, 400, 550,
      NULL,NULL,GetModuleHandle(NULL),NULL);

   /* Model selector */
   hLbl = CreateWindowExA(0,"STATIC","Model:",WS_CHILD|WS_VISIBLE,
      8,8,45,20,s_hAIWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hLbl,WM_SETFONT,(WPARAM)hFont,TRUE);

   hModel = CreateWindowExA(0,"COMBOBOX",NULL,
      WS_CHILD|WS_VISIBLE|CBS_DROPDOWNLIST|WS_VSCROLL,
      55,6,180,200,s_hAIWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hModel,WM_SETFONT,(WPARAM)hFont,TRUE);
   SendMessageA(hModel,CB_ADDSTRING,0,(LPARAM)"codellama");
   SendMessageA(hModel,CB_ADDSTRING,0,(LPARAM)"llama3");
   SendMessageA(hModel,CB_ADDSTRING,0,(LPARAM)"deepseek-coder");
   SendMessageA(hModel,CB_ADDSTRING,0,(LPARAM)"mistral");
   SendMessageA(hModel,CB_ADDSTRING,0,(LPARAM)"phi3");
   SendMessageA(hModel,CB_ADDSTRING,0,(LPARAM)"gemma2");
   SendMessage(hModel,CB_SETCURSEL,0,0);

   { HWND hClear = CreateWindowExA(0,"BUTTON","Clear",
      WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
      245,6,60,22,s_hAIWnd,(HMENU)800,GetModuleHandle(NULL),NULL);
     SendMessage(hClear,WM_SETFONT,(WPARAM)hFont,TRUE);
   }

   /* Chat output (read-only rich text area) */
   hOutput = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",
      "AI Assistant ready.\r\n"
      "Connected to: localhost:11434 (Ollama)\r\n"
      "Model: codellama\r\n"
      "\r\n"
      "Type a question about Harbour, xBase, or your code.\r\n"
      "Examples:\r\n"
      "  - How do I create a database browser?\r\n"
      "  - Explain this error: 'undefined function'\r\n"
      "  - Refactor this code to use classes\r\n"
      "  - Write a function to sort an array\r\n"
      "\r\n"
      "Shortcuts:\r\n"
      "  Right-click code > Explain / Refactor / Fix\r\n"
      "  Ctrl+Shift+A: Ask AI\r\n",
      WS_CHILD|WS_VISIBLE|WS_VSCROLL|ES_MULTILINE|ES_READONLY|ES_AUTOVSCROLL,
      4,34,388,410,s_hAIWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hOutput,WM_SETFONT,(WPARAM)hMonoFont,TRUE);
   /* Dark background for chat */
   /* Note: standard EDIT doesn't support EM_SETBKGNDCOLOR, but we set it via WM_CTLCOLOREDIT */

   /* Input field */
   hInput = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT","",
      WS_CHILD|WS_VISIBLE|ES_AUTOHSCROLL,
      4,450,310,24,s_hAIWnd,(HMENU)801,GetModuleHandle(NULL),NULL);
   SendMessage(hInput,WM_SETFONT,(WPARAM)hFont,TRUE);

   /* Send button */
   hSend = CreateWindowExA(0,"BUTTON","Send",
      WS_CHILD|WS_VISIBLE|BS_DEFPUSHBUTTON,
      320,449,72,26,s_hAIWnd,(HMENU)802,GetModuleHandle(NULL),NULL);
   SendMessage(hSend,WM_SETFONT,(WPARAM)hFont,TRUE);

   /* Status bar */
   hLbl = CreateWindowExA(0,"STATIC","Status: Ready | Ollama: localhost:11434",
      WS_CHILD|WS_VISIBLE|SS_LEFT,
      4,480,388,18,s_hAIWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hLbl,WM_SETFONT,(WPARAM)hFont,TRUE);
}

/* W32_SetDarkMode( hWnd, lDark ) - enable Windows 10/11 dark title bar */
HB_FUNC( W32_SETDARKMODE )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   BOOL bDark = hb_parl(2);
   typedef HRESULT (WINAPI *pDwmSetWindowAttribute)(HWND,DWORD,LPCVOID,DWORD);
   HMODULE hDwm = LoadLibraryA("dwmapi.dll");
   if( hDwm && hWnd ) {
      pDwmSetWindowAttribute fn = (pDwmSetWindowAttribute)
         GetProcAddress(hDwm,"DwmSetWindowAttribute");
      if( fn ) {
         /* DWMWA_USE_IMMERSIVE_DARK_MODE = 20 (Win10 build 18985+) */
         BOOL val = bDark;
         fn(hWnd, 20, &val, sizeof(val));
         SetWindowPos(hWnd,NULL,0,0,0,0,
            SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED);
      }
      FreeLibrary(hDwm);
   }
}

/* W32_OpenDocs( cPage ) - open HTML documentation in system browser */
HB_FUNC( W32_OPENDOCS )
{
   char szPath[MAX_PATH];
   const char * page = HB_ISCHAR(1) ? hb_parc(1) : "en/index.html";

   /* Build path relative to executable */
   GetModuleFileNameA( NULL, szPath, MAX_PATH );
   { char * p = strrchr( szPath, '\\' );
     if( p ) *p = 0; }

   /* Go up one level from samples/ to project root */
   { char * p = strrchr( szPath, '\\' );
     if( p ) *p = 0; }

   lstrcatA( szPath, "\\docs\\" );
   lstrcatA( szPath, page );

   /* If page doesn't end with .html, append index.html */
   if( !strstr( page, ".html" ) )
      lstrcatA( szPath, "\\index.html" );

   ShellExecuteA( NULL, "open", szPath, NULL, NULL, SW_SHOWNORMAL );
}

HB_FUNC( W32_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2), MB_OK | MB_ICONINFORMATION );
}

/* UI_MsgBox - cross-platform alias */
HB_FUNC( UI_MSGBOX )
{
   MessageBoxA( GetActiveWindow(), hb_parc(1), hb_parc(2), MB_OK | MB_ICONINFORMATION );
}

/* UI_MsgYesNo - Yes/No dialog, returns .T. if user clicks Yes */
HB_FUNC( UI_MSGYESNO )
{
   int nResult = MessageBoxA( GetActiveWindow(), hb_parc(1),
      hb_parc(2) ? hb_parc(2) : "Confirm", MB_YESNO | MB_ICONQUESTION );
   hb_retl( nResult == IDYES );
}

/* MsgYesNoCancel( cText, cTitle ) -> 0=Cancel, 1=Yes, 2=No */
HB_FUNC( MSGYESNOCANCEL )
{
   int nResult = MessageBoxA( GetActiveWindow(),
      hb_parc(1),
      HB_ISCHAR(2) ? hb_parc(2) : "Confirm",
      MB_YESNOCANCEL | MB_ICONQUESTION );
   switch( nResult ) {
      case IDYES:    hb_retni( 1 ); break;
      case IDNO:     hb_retni( 2 ); break;
      default:       hb_retni( 0 ); break;
   }
}

HB_FUNC( W32_GETSCREENWIDTH )
{
   hb_retni( GetSystemMetrics( SM_CXSCREEN ) );
}

HB_FUNC( W32_GETSCREENHEIGHT )
{
   hb_retni( GetSystemMetrics( SM_CYSCREEN ) );
}

HB_FUNC( W32_GETWORKAREAHEIGHT )
{
   RECT rc;
   SystemParametersInfoA( SPI_GETWORKAREA, 0, &rc, 0 );
   hb_retni( rc.bottom );
}

HB_FUNC( W32_GETWINDOWBOTTOM )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   if( hWnd )
   {
      RECT rc;
      GetWindowRect( hWnd, &rc );
      hb_retni( rc.bottom );
   }
   else
      hb_retni( 0 );
}

HB_FUNC( W32_BRINGTOTOP )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   if( hWnd )
      SetWindowPos( hWnd, HWND_TOP, 0, 0, 0, 0,
         SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE );
}

HB_FUNC( W32_SETFOCUS )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   if( hWnd )
   {
      SetForegroundWindow( hWnd );
      SetFocus( hWnd );
   }
}

/* W32_OpenFileDialog( cTitle, cExt ) --> cFilePath or "" */
HB_FUNC( W32_OPENFILEDIALOG )
{
   OPENFILENAMEA ofn;
   char szFile[MAX_PATH] = "";
   char szFilter[256];
   const char * cExt = hb_parc(2);

   sprintf( szFilter, "HbBuilder Files (*.%s)%c*.%s%cAll Files (*.*)%c*.*%c",
            cExt, 0, cExt, 0, 0, 0 );

   memset( &ofn, 0, sizeof(ofn) );
   ofn.lStructSize = sizeof(ofn);
   ofn.hwndOwner = GetActiveWindow();
   ofn.lpstrFilter = szFilter;
   ofn.lpstrFile = szFile;
   ofn.nMaxFile = MAX_PATH;
   ofn.lpstrTitle = hb_parc(1);
   ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;

   if( GetOpenFileNameA( &ofn ) )
      hb_retc( szFile );
   else
      hb_retc( "" );
}

/* W32_SaveFileDialog( cTitle, cDefault, cExt ) --> cFilePath or "" */
HB_FUNC( W32_SAVEFILEDIALOG )
{
   OPENFILENAMEA ofn;
   char szFile[MAX_PATH];
   char szFilter[256];
   const char * cExt = hb_parc(3);
   char szInitDir[MAX_PATH];

   lstrcpynA( szFile, hb_parc(2), MAX_PATH );

   /* Default to user's Desktop (avoids OneDrive-redirected Documents) */
   SHGetFolderPathA( NULL, CSIDL_DESKTOPDIRECTORY, NULL, 0, szInitDir );

   sprintf( szFilter, "HbBuilder Files (*.%s)%c*.%s%cAll Files (*.*)%c*.*%c",
            cExt, 0, cExt, 0, 0, 0 );

   memset( &ofn, 0, sizeof(ofn) );
   ofn.lStructSize = sizeof(ofn);
   ofn.hwndOwner = GetActiveWindow();
   ofn.lpstrFilter = szFilter;
   ofn.lpstrFile = szFile;
   ofn.nMaxFile = MAX_PATH;
   ofn.lpstrTitle = hb_parc(1);
   ofn.lpstrDefExt = cExt;
   ofn.lpstrInitialDir = szInitDir;
   ofn.Flags = OFN_OVERWRITEPROMPT | OFN_HIDEREADONLY;

   if( GetSaveFileNameA( &ofn ) )
      hb_retc( szFile );
   else
      hb_retc( "" );
}

/* ======================================================================
 * Runtime dialog components — TOpenDialog / TSaveDialog / TFontDialog /
 * TColorDialog (Execute() backends). Accept user-supplied filter strings
 * with '|' separators (Delphi/Lazarus style), converted to the double-NUL
 * format Win32 expects.
 * ====================================================================== */

/* Convert "Text Files (*.txt)|*.txt|All Files|*.*" -> double-NUL string */
static void DlgBuildFilter( const char * src, char * dst, int dstSize )
{
   int di = 0;
   if( !src || !src[0] ) {
      /* Default: All Files */
      lstrcpynA( dst, "All Files (*.*)", dstSize - 2 );
      di = (int) strlen( dst ) + 1;
      lstrcpynA( dst + di, "*.*", dstSize - di - 2 );
      di += (int) strlen( dst + di ) + 1;
      dst[di] = 0;
      return;
   }
   while( *src && di < dstSize - 2 ) {
      if( *src == '|' ) { dst[di++] = 0; src++; }
      else dst[di++] = *src++;
   }
   dst[di++] = 0;
   dst[di]   = 0;
}

/* W32_ExecOpenDialog( cTitle, cFilter, cInitialDir, cDefaultExt, nOptions )
 *   --> cFileName (empty if cancelled) */
HB_FUNC( W32_EXECOPENDIALOG )
{
   OPENFILENAMEA ofn;
   char szFile[MAX_PATH] = "";
   char szFilter[1024];
   const char * cInit = hb_parc(3);
   const char * cExt  = hb_parc(4);

   DlgBuildFilter( hb_parc(2), szFilter, sizeof(szFilter) );

   memset( &ofn, 0, sizeof(ofn) );
   ofn.lStructSize     = sizeof(ofn);
   ofn.hwndOwner       = GetActiveWindow();
   ofn.lpstrFilter     = szFilter;
   ofn.lpstrFile       = szFile;
   ofn.nMaxFile        = MAX_PATH;
   ofn.lpstrTitle      = hb_parclen(1) ? hb_parc(1) : NULL;
   ofn.lpstrInitialDir = ( cInit && cInit[0] ) ? cInit : NULL;
   ofn.lpstrDefExt     = ( cExt && cExt[0] ) ? cExt : NULL;
   ofn.Flags           = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;

   if( GetOpenFileNameA( &ofn ) )
      hb_retc( szFile );
   else
      hb_retc( "" );
}

/* W32_ExecSaveDialog( cTitle, cFilter, cInitialDir, cDefaultExt, cFileName, nOptions )
 *   --> cFileName (empty if cancelled) */
HB_FUNC( W32_EXECSAVEDIALOG )
{
   OPENFILENAMEA ofn;
   char szFile[MAX_PATH] = "";
   char szFilter[1024];
   const char * cInit = hb_parc(3);
   const char * cExt  = hb_parc(4);
   const char * cName = hb_parc(5);

   DlgBuildFilter( hb_parc(2), szFilter, sizeof(szFilter) );

   if( cName && cName[0] )
      lstrcpynA( szFile, cName, MAX_PATH );

   memset( &ofn, 0, sizeof(ofn) );
   ofn.lStructSize     = sizeof(ofn);
   ofn.hwndOwner       = GetActiveWindow();
   ofn.lpstrFilter     = szFilter;
   ofn.lpstrFile       = szFile;
   ofn.nMaxFile        = MAX_PATH;
   ofn.lpstrTitle      = hb_parclen(1) ? hb_parc(1) : NULL;
   ofn.lpstrInitialDir = ( cInit && cInit[0] ) ? cInit : NULL;
   ofn.lpstrDefExt     = ( cExt && cExt[0] ) ? cExt : NULL;
   ofn.Flags           = OFN_OVERWRITEPROMPT | OFN_HIDEREADONLY;

   if( GetSaveFileNameA( &ofn ) )
      hb_retc( szFile );
   else
      hb_retc( "" );
}

/* W32_ExecFontDialog( cFontName, nSize, nColor, nStyle )
 *   --> { cFontName, nSize, nColor, nStyle } or NIL */
HB_FUNC( W32_EXECFONTDIALOG )
{
   CHOOSEFONTA cf;
   LOGFONTA lf;
   const char * cName = hb_parc(1);
   int nSize  = hb_parni(2);
   int nColor = hb_parni(3);
   int nStyle = hb_parni(4);
   HDC hdc;

   memset( &lf, 0, sizeof(lf) );
   if( cName && cName[0] ) lstrcpynA( lf.lfFaceName, cName, LF_FACESIZE );
   else lstrcpyA( lf.lfFaceName, "Segoe UI" );
   hdc = GetDC( NULL );
   lf.lfHeight    = -MulDiv( nSize > 0 ? nSize : 10, GetDeviceCaps( hdc, LOGPIXELSY ), 72 );
   ReleaseDC( NULL, hdc );
   lf.lfWeight    = ( nStyle & 1 ) ? FW_BOLD : FW_NORMAL;
   lf.lfItalic    = ( nStyle & 2 ) ? 1 : 0;
   lf.lfUnderline = ( nStyle & 4 ) ? 1 : 0;
   lf.lfCharSet   = DEFAULT_CHARSET;

   memset( &cf, 0, sizeof(cf) );
   cf.lStructSize = sizeof(cf);
   cf.hwndOwner   = GetActiveWindow();
   cf.lpLogFont   = &lf;
   cf.rgbColors   = nColor;
   cf.Flags       = CF_SCREENFONTS | CF_INITTOLOGFONTSTRUCT | CF_EFFECTS;

   if( ChooseFontA( &cf ) )
   {
      PHB_ITEM aRet;
      int outStyle = 0;
      int pts;
      hdc = GetDC( NULL );
      pts = MulDiv( -lf.lfHeight, 72, GetDeviceCaps( hdc, LOGPIXELSY ) );
      ReleaseDC( NULL, hdc );
      if( lf.lfWeight >= FW_BOLD ) outStyle |= 1;
      if( lf.lfItalic )             outStyle |= 2;
      if( lf.lfUnderline )          outStyle |= 4;
      aRet = hb_itemArrayNew( 4 );
      hb_arraySetC ( aRet, 1, lf.lfFaceName );
      hb_arraySetNI( aRet, 2, pts );
      hb_arraySetNI( aRet, 3, (int) cf.rgbColors );
      hb_arraySetNI( aRet, 4, outStyle );
      hb_itemReturnRelease( aRet );
   }
   else
      hb_ret();  /* NIL */
}

/* W32_ExecColorDialog( nInitialColor ) --> nColor or -1 */
HB_FUNC( W32_EXECCOLORDIALOG )
{
   CHOOSECOLORA cc;
   static COLORREF custColors[16] = {0};
   memset( &cc, 0, sizeof(cc) );
   cc.lStructSize  = sizeof(cc);
   cc.hwndOwner    = GetActiveWindow();
   cc.rgbResult    = (COLORREF) hb_parni(1);
   cc.lpCustColors = custColors;
   cc.Flags        = CC_RGBINIT | CC_FULLOPEN;

   if( ChooseColorA( &cc ) )
      hb_retni( (int) cc.rgbResult );
   else
      hb_retni( -1 );
}

/* W32_SelectFromList( cTitle, aItems ) --> nSelection (1-based) or 0 */
/* Forms selection dialog - result stored here by WndProc */
static int s_formsSel = 0;
static HWND s_formsListBox = NULL;
static BOOL s_formsDlgDone = FALSE;

static LRESULT CALLBACK FormsDlgProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_COMMAND:
      {
         WORD wId = LOWORD(wParam);
         WORD wNotify = HIWORD(wParam);
         if( wId == IDOK || ( wId == 100 && wNotify == LBN_DBLCLK ) )
         {
            if( s_formsListBox ) {
               int sel = (int) SendMessage( s_formsListBox, LB_GETCURSEL, 0, 0 );
               s_formsSel = ( sel != LB_ERR ) ? sel + 1 : 0;
            }
            s_formsDlgDone = TRUE;
            PostMessage( hWnd, WM_CLOSE, 0, 0 );
            return 0;
         }
         if( wId == IDCANCEL ) {
            s_formsSel = 0;
            s_formsDlgDone = TRUE;
            PostMessage( hWnd, WM_CLOSE, 0, 0 );
            return 0;
         }
         break;
      }
      case WM_CLOSE:
      {
         HWND hOwner = GetWindow( hWnd, GW_OWNER );
         if( hOwner ) EnableWindow( hOwner, TRUE );
         DestroyWindow( hWnd );
         return 0;
      }
      /* NO PostQuitMessage - that would kill the IDE's message loop! */
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

HB_FUNC( W32_SELECTFROMLIST )
{
   static BOOL bReg = FALSE;
   WNDCLASSA wc = {0};
   PHB_ITEM pArray = hb_param( 2, HB_IT_ARRAY );
   int nCount, i;
   HWND hDlg, hList, hBtnOK, hBtnCancel, hOwner;
   HFONT hFont;
   MSG msg;
   int dlgW = 300, dlgH = 350;
   int x, y;

   if( !pArray ) { hb_retni(0); return; }
   nCount = (int) hb_arrayLen( pArray );
   if( nCount == 0 ) { hb_retni(0); return; }

   s_formsSel = 0;

   if( !bReg ) {
      wc.lpfnWndProc = FormsDlgProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.hCursor = LoadCursor(NULL, IDC_ARROW);
      wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
      wc.lpszClassName = "HbFormsDlg";
      RegisterClassA( &wc );
      bReg = TRUE;
   }

   hOwner = GetActiveWindow();
   x = ( GetSystemMetrics(SM_CXSCREEN) - dlgW ) / 2;
   y = ( GetSystemMetrics(SM_CYSCREEN) - dlgH ) / 2;

   hDlg = CreateWindowExA( WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
      "HbFormsDlg", HB_ISCHAR(1) ? hb_parc(1) : "Select",
      WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE,
      x, y, dlgW, dlgH,
      hOwner, NULL, GetModuleHandle(NULL), NULL );

   hFont = (HFONT) GetStockObject( DEFAULT_GUI_FONT );

   /* Use client rect for symmetric layout */
   {
      RECT rc;
      int m = 12;        /* margin */
      int btnW = 80, btnH = 28, btnGap = 10;
      int cw, ch, btnTotalW, btnX, btnY;
      GetClientRect( hDlg, &rc );
      cw = rc.right;  ch = rc.bottom;
      btnTotalW = btnW + btnGap + btnW;
      btnX = ( cw - btnTotalW ) / 2;
      btnY = ch - m - btnH;

      hList = CreateWindowExA( WS_EX_CLIENTEDGE, "LISTBOX", NULL,
         WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_NOTIFY,
         m, m, cw - 2 * m, btnY - m - m,
         hDlg, (HMENU)100, GetModuleHandle(NULL), NULL );

      hBtnOK = CreateWindowExA( 0, "BUTTON", "OK",
         WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
         btnX, btnY, btnW, btnH,
         hDlg, (HMENU)IDOK, GetModuleHandle(NULL), NULL );

      hBtnCancel = CreateWindowExA( 0, "BUTTON", "Cancel",
         WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
         btnX + btnW + btnGap, btnY, btnW, btnH,
         hDlg, (HMENU)IDCANCEL, GetModuleHandle(NULL), NULL );
   }
   SendMessage( hList, WM_SETFONT, (WPARAM) hFont, TRUE );
   SendMessage( hBtnOK, WM_SETFONT, (WPARAM) hFont, TRUE );
   SendMessage( hBtnCancel, WM_SETFONT, (WPARAM) hFont, TRUE );
   s_formsListBox = hList;

   for( i = 0; i < nCount; i++ )
   {
      PHB_ITEM pItem = hb_arrayGetItemPtr( pArray, i + 1 );
      if( pItem )
         SendMessageA( hList, LB_ADDSTRING, 0, (LPARAM) hb_itemGetCPtr( pItem ) );
   }
   SendMessage( hList, LB_SETCURSEL, 0, 0 );

   /* Modal loop - uses flag instead of PostQuitMessage */
   s_formsDlgDone = FALSE;
   EnableWindow( hOwner, FALSE );
   while( !s_formsDlgDone && GetMessage( &msg, NULL, 0, 0 ) > 0 )
   {
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }
   /* hOwner re-enabled by WM_CLOSE handler */

   s_formsListBox = NULL;
   hb_retni( s_formsSel );
}

/* W32_ShellExec( cCommand ) --> cOutput */
HB_FUNC( W32_SHELLEXEC )
{
   SECURITY_ATTRIBUTES sa;
   STARTUPINFOA si;
   PROCESS_INFORMATION pi;
   HANDLE hReadPipe, hWritePipe;
   char * buf;
   DWORD dwRead, dwTotal = 0;
   int bufSize = 32768;
   char * cmd;
   int cmdLen;

   sa.nLength = sizeof(sa);
   sa.bInheritHandle = TRUE;
   sa.lpSecurityDescriptor = NULL;

   if( !CreatePipe( &hReadPipe, &hWritePipe, &sa, 0 ) )
   {
      hb_retc( "" );
      return;
   }
   SetHandleInformation( hReadPipe, HANDLE_FLAG_INHERIT, 0 );

   memset( &si, 0, sizeof(si) );
   si.cb = sizeof(si);
   si.hStdOutput = hWritePipe;
   si.hStdError = hWritePipe;
   si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
   si.wShowWindow = SW_HIDE;

   cmdLen = (int) strlen( hb_parc(1) ) + 16;
   cmd = (char *) malloc( cmdLen );
   sprintf( cmd, "cmd /c %s", hb_parc(1) );

   buf = (char *) malloc( bufSize );

   if( CreateProcessA( NULL, cmd, NULL, NULL, TRUE,
       CREATE_NO_WINDOW, NULL, NULL, &si, &pi ) )
   {
      CloseHandle( hWritePipe );
      hWritePipe = NULL;

      while( ReadFile( hReadPipe, buf + dwTotal, bufSize - dwTotal - 1, &dwRead, NULL ) && dwRead > 0 )
      {
         dwTotal += dwRead;
         if( dwTotal >= (DWORD)(bufSize - 256) )
         {
            bufSize *= 2;
            buf = (char *) realloc( buf, bufSize );
         }
      }
      buf[dwTotal] = 0;

      WaitForSingleObject( pi.hProcess, 10000 );
      CloseHandle( pi.hProcess );
      CloseHandle( pi.hThread );
   }
   else
   {
      buf[0] = 0;
   }

   if( hWritePipe ) CloseHandle( hWritePipe );
   CloseHandle( hReadPipe );

   hb_retc( buf );
   free( buf );
   free( cmd );
}

/* ======================================================================
 * Editor Settings Dialog (C++Builder: Tools > Editor Options > Colors)
 * ====================================================================== */

#define ES_DLG_W 480
#define ES_DLG_H 460

static COLORREF PickColor( HWND hOwner, COLORREF crInit )
{
   CHOOSECOLORA cc = {0};
   static COLORREF custClrs[16] = {0};
   cc.lStructSize = sizeof(cc);
   cc.hwndOwner = hOwner;
   cc.lpCustColors = custClrs;
   cc.rgbResult = crInit;
   cc.Flags = CC_FULLOPEN | CC_RGBINIT;
   if( ChooseColorA( &cc ) )
      return cc.rgbResult;
   return crInit;
}

static HWND ES_AddColorRow( HWND hDlg, const char * label, COLORREF clr, int y, int id )
{
   HWND hLbl, hBtn;
   char buf[32];
   hLbl = CreateWindowExA(0,"STATIC",label,WS_CHILD|WS_VISIBLE,16,y,160,20,
      hDlg,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hLbl,WM_SETFONT,(WPARAM)GetStockObject(DEFAULT_GUI_FONT),TRUE);

   sprintf(buf, "  ");
   hBtn = CreateWindowExA(0,"BUTTON",buf,WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
      180,y-2,60,22,hDlg,(HMENU)(LONG_PTR)id,GetModuleHandle(NULL),NULL);
   SendMessage(hBtn,WM_SETFONT,(WPARAM)GetStockObject(DEFAULT_GUI_FONT),TRUE);
   return hBtn;
}

static LRESULT CALLBACK EditorSettingsProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch(msg) {
      case WM_COMMAND:
      {
         WORD wId = LOWORD(wParam);
         if(wId==IDOK || wId==IDCANCEL) {
            EnableWindow(GetParent(hWnd)?GetParent(hWnd):GetDesktopWindow(),TRUE);
            DestroyWindow(hWnd); return 0;
         }
         /* Color buttons: IDs 600-608 */
         if(wId >= 600 && wId <= 608) {
            COLORREF crInit = RGB(128,128,128);
            COLORREF crNew = PickColor(hWnd, crInit);
            /* Update button text with color name */
            { char buf[32]; sprintf(buf, "#%02X%02X%02X",
                GetRValue(crNew), GetGValue(crNew), GetBValue(crNew));
              SetWindowTextA((HWND)lParam, buf); }
            return 0;
         }
         break;
      }
      case WM_CLOSE:
         EnableWindow(GetParent(hWnd)?GetParent(hWnd):GetDesktopWindow(),TRUE);
         DestroyWindow(hWnd); return 0;
   }
   return DefWindowProc(hWnd,msg,wParam,lParam);
}

/* W32_EditorSettingsDialog( cFont,nSize,nBg,nText,nKw,nCmd,nCom,nStr,nPP,nNum,nSel ) */
HB_FUNC( W32_EDITORSETTINGSDIALOG )
{
   static BOOL bReg = FALSE;
   WNDCLASSA wc = {0};
   HWND hDlg, hOwner, hBtn, hFontName, hFontSize;
   HFONT hFont;
   RECT rc;
   MSG msg;
   int x, y, row;
   static const char * labels[] = {
      "Background:", "Text:", "Keywords:", "Commands:",
      "Comments:", "Strings:", "Preprocessor:", "Numbers:", "Selection:", NULL };

   if(!bReg) {
      wc.lpfnWndProc=EditorSettingsProc; wc.hInstance=GetModuleHandle(NULL);
      wc.hCursor=LoadCursor(NULL,IDC_ARROW);
      wc.hbrBackground=(HBRUSH)(COLOR_BTNFACE+1);
      wc.lpszClassName="HbEditorSettings"; RegisterClassA(&wc); bReg=TRUE;
   }

   hOwner = GetActiveWindow();
   x = ( GetSystemMetrics(SM_CXSCREEN) - ES_DLG_W ) / 2;
   y = ( GetSystemMetrics(SM_CYSCREEN) - ES_DLG_H ) / 2;

   hDlg = CreateWindowExA(WS_EX_DLGMODALFRAME|WS_EX_TOPMOST,
      "HbEditorSettings","Editor Colors && Font",
      WS_POPUP|WS_CAPTION|WS_SYSMENU|WS_VISIBLE,
      x,y,ES_DLG_W,ES_DLG_H,hOwner,NULL,GetModuleHandle(NULL),NULL);

   hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

   /* Font section */
   { HWND h;
     h = CreateWindowExA(0,"STATIC","Font:",WS_CHILD|WS_VISIBLE,16,16,50,20,
        hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

     hFontName = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",
        HB_ISCHAR(1)?hb_parc(1):"Consolas",
        WS_CHILD|WS_VISIBLE|ES_AUTOHSCROLL,
        70,14,200,22,hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(hFontName,WM_SETFONT,(WPARAM)hFont,TRUE);

     h = CreateWindowExA(0,"STATIC","Size:",WS_CHILD|WS_VISIBLE,290,16,40,20,
        hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

     { char sz[8]; sprintf(sz,"%d",HB_ISNUM(2)?hb_parni(2):15);
       hFontSize = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",sz,
          WS_CHILD|WS_VISIBLE|ES_AUTOHSCROLL|ES_NUMBER,
          335,14,50,22,hDlg,NULL,GetModuleHandle(NULL),NULL);
       SendMessage(hFontSize,WM_SETFONT,(WPARAM)hFont,TRUE);
     }
   }

   /* Theme presets */
   { HWND h;
     h = CreateWindowExA(0,"STATIC","Presets:",WS_CHILD|WS_VISIBLE,16,48,60,20,
        hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

     h = CreateWindowExA(0,"BUTTON","Dark",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
        80,46,60,22,hDlg,(HMENU)500,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
     h = CreateWindowExA(0,"BUTTON","Light",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
        148,46,60,22,hDlg,(HMENU)501,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
     h = CreateWindowExA(0,"BUTTON","Monokai",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
        216,46,70,22,hDlg,(HMENU)502,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
     h = CreateWindowExA(0,"BUTTON","Solarized",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
        294,46,80,22,hDlg,(HMENU)503,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
   }

   /* Color rows */
   { HWND h;
     h = CreateWindowExA(0,"STATIC","Syntax Colors",WS_CHILD|WS_VISIBLE|SS_LEFT,
        16,80,200,18,hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
   }

   row = 106;
   for(x=0; labels[x]; x++) {
      ES_AddColorRow(hDlg, labels[x], 0, row, 600+x);
      row += 28;
   }

   /* Preview */
   { HWND h;
     h = CreateWindowExA(0,"STATIC","Preview:",WS_CHILD|WS_VISIBLE,
        270,96,80,18,hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
     h = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",
        "// Preview\r\nfunction Main()\r\n   local x := 42\r\n   MsgInfo( \"Hello\" )\r\nreturn nil",
        WS_CHILD|WS_VISIBLE|ES_MULTILINE|ES_READONLY,
        270,118,ES_DLG_W-290,200,hDlg,NULL,GetModuleHandle(NULL),NULL);
     SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
   }

   /* OK / Cancel */
   hBtn = CreateWindowExA(0,"BUTTON","OK",WS_CHILD|WS_VISIBLE|BS_DEFPUSHBUTTON,
      ES_DLG_W/2-100,ES_DLG_H-70,90,28,hDlg,(HMENU)IDOK,GetModuleHandle(NULL),NULL);
   SendMessage(hBtn,WM_SETFONT,(WPARAM)hFont,TRUE);
   hBtn = CreateWindowExA(0,"BUTTON","Cancel",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
      ES_DLG_W/2+10,ES_DLG_H-70,90,28,hDlg,(HMENU)IDCANCEL,GetModuleHandle(NULL),NULL);
   SendMessage(hBtn,WM_SETFONT,(WPARAM)hFont,TRUE);

   /* Modal loop */
   EnableWindow(hOwner, FALSE);
   while(IsWindow(hDlg) && GetMessage(&msg,NULL,0,0)) {
      if(msg.message==WM_KEYDOWN && msg.wParam==VK_ESCAPE) {
         SendMessage(hDlg,WM_CLOSE,0,0); break; }
      TranslateMessage(&msg); DispatchMessage(&msg);
   }
}

/* ======================================================================
 * Project Options Dialog (C++Builder: Project > Options)
 * Tabs: Harbour | C Compiler | Linker | Directories
 * ====================================================================== */

#define PO_TAB_HEIGHT 28
#define PO_DLG_W 520
#define PO_DLG_H 440

typedef struct {
   HWND hDlg, hTab;
   /* Harbour tab */
   HWND hHbDir, hHbFlags, hChkWarn, hChkDebug;
   /* C Compiler tab */
   HWND hCDir, hCFlags, hChkOpt;
   /* Linker tab */
   HWND hLinkFlags, hLibs;
   /* Directories tab */
   HWND hProjDir, hOutDir, hIncPaths, hLibPaths;
   int nActiveTab;
} PROJOPTDATA;

static void PO_ShowTab( PROJOPTDATA * d, int nTab );
static void PO_CreateControls( PROJOPTDATA * d );

static HWND PO_AddLabel( HWND hParent, const char * text, int x, int y, int w )
{
   HWND h = CreateWindowExA(0,"STATIC",text,WS_CHILD,x,y,w,18,hParent,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(h,WM_SETFONT,(WPARAM)GetStockObject(DEFAULT_GUI_FONT),TRUE);
   return h;
}

static HWND PO_AddEdit( HWND hParent, const char * text, int x, int y, int w, int h )
{
   HWND hE = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT",text,
      WS_CHILD|ES_AUTOHSCROLL|(h>24?ES_MULTILINE|ES_AUTOVSCROLL|WS_VSCROLL:0),
      x,y,w,h,hParent,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hE,WM_SETFONT,(WPARAM)GetStockObject(DEFAULT_GUI_FONT),TRUE);
   return hE;
}

static HWND PO_AddCheck( HWND hParent, const char * text, int x, int y, BOOL checked )
{
   HWND h = CreateWindowExA(0,"BUTTON",text,WS_CHILD|BS_AUTOCHECKBOX,
      x,y,200,20,hParent,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(h,WM_SETFONT,(WPARAM)GetStockObject(DEFAULT_GUI_FONT),TRUE);
   if(checked) SendMessage(h,BM_SETCHECK,BST_CHECKED,0);
   return h;
}

static void PO_HideAll( PROJOPTDATA * d )
{
   HWND all[13];
   int i;
   all[0]=d->hHbDir; all[1]=d->hHbFlags; all[2]=d->hChkWarn; all[3]=d->hChkDebug;
   all[4]=d->hCDir; all[5]=d->hCFlags; all[6]=d->hChkOpt;
   all[7]=d->hLinkFlags; all[8]=d->hLibs;
   all[9]=d->hProjDir; all[10]=d->hOutDir; all[11]=d->hIncPaths; all[12]=d->hLibPaths;
   for(i=0;i<13;i++) if(all[i]) ShowWindow(all[i],SW_HIDE);
   /* Hide all labels too */
   EnumChildWindows(d->hDlg, (WNDENUMPROC)NULL, 0); /* handled by ShowTab */
}

static void PO_ShowTab( PROJOPTDATA * d, int nTab )
{
   /* Hide everything first - simple approach: hide known controls */
   ShowWindow(d->hHbDir,SW_HIDE); ShowWindow(d->hHbFlags,SW_HIDE);
   ShowWindow(d->hChkWarn,SW_HIDE); ShowWindow(d->hChkDebug,SW_HIDE);
   ShowWindow(d->hCDir,SW_HIDE); ShowWindow(d->hCFlags,SW_HIDE);
   ShowWindow(d->hChkOpt,SW_HIDE);
   ShowWindow(d->hLinkFlags,SW_HIDE); ShowWindow(d->hLibs,SW_HIDE);
   ShowWindow(d->hProjDir,SW_HIDE); ShowWindow(d->hOutDir,SW_HIDE);
   ShowWindow(d->hIncPaths,SW_HIDE); ShowWindow(d->hLibPaths,SW_HIDE);

   d->nActiveTab = nTab;
   switch(nTab) {
      case 0: /* Harbour */
         ShowWindow(d->hHbDir,SW_SHOW); ShowWindow(d->hHbFlags,SW_SHOW);
         ShowWindow(d->hChkWarn,SW_SHOW); ShowWindow(d->hChkDebug,SW_SHOW);
         break;
      case 1: /* C Compiler */
         ShowWindow(d->hCDir,SW_SHOW); ShowWindow(d->hCFlags,SW_SHOW);
         ShowWindow(d->hChkOpt,SW_SHOW);
         break;
      case 2: /* Linker */
         ShowWindow(d->hLinkFlags,SW_SHOW); ShowWindow(d->hLibs,SW_SHOW);
         break;
      case 3: /* Directories */
         ShowWindow(d->hProjDir,SW_SHOW); ShowWindow(d->hOutDir,SW_SHOW);
         ShowWindow(d->hIncPaths,SW_SHOW); ShowWindow(d->hLibPaths,SW_SHOW);
         break;
   }
}

static LRESULT CALLBACK ProjOptProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   PROJOPTDATA * d = (PROJOPTDATA*) GetWindowLongPtr(hWnd, GWLP_USERDATA);
   switch(msg) {
      case WM_NOTIFY: {
         NMHDR * pnm = (NMHDR*)lParam;
         if(d && pnm->hwndFrom == d->hTab && pnm->code == TCN_SELCHANGE)
            PO_ShowTab(d, (int)SendMessage(d->hTab,TCM_GETCURSEL,0,0));
         break;
      }
      case WM_COMMAND:
         if(LOWORD(wParam)==IDOK || LOWORD(wParam)==IDCANCEL) {
            EnableWindow(GetParent(hWnd)?GetParent(hWnd):GetDesktopWindow(),TRUE);
            DestroyWindow(hWnd);
            return 0;
         }
         break;
      case WM_CLOSE:
         EnableWindow(GetParent(hWnd)?GetParent(hWnd):GetDesktopWindow(),TRUE);
         DestroyWindow(hWnd); return 0;
   }
   return DefWindowProc(hWnd,msg,wParam,lParam);
}

/* W32_ProjectOptionsDialog( cHbDir,cCDir,cProjDir,cOutDir,cHbFlags,cCFlags,
   cLinkFlags,cIncPaths,cLibPaths,cLibs,lDebug,lWarn,lOpt ) */
HB_FUNC( W32_PROJECTOPTIONSDIALOG )
{
   static BOOL bReg = FALSE;
   WNDCLASSA wc = {0};
   PROJOPTDATA d = {0};
   HWND hOwner; RECT rc;
   int x, y;
   TCITEMA tci;
   HFONT hFont;
   MSG msg;
   int baseY = PO_TAB_HEIGHT + 48;

   if(!bReg) {
      wc.lpfnWndProc=ProjOptProc; wc.hInstance=GetModuleHandle(NULL);
      wc.hCursor=LoadCursor(NULL,IDC_ARROW);
      wc.hbrBackground=(HBRUSH)(COLOR_BTNFACE+1);
      wc.lpszClassName="HbProjOpt"; RegisterClassA(&wc); bReg=TRUE;
   }

   hOwner = GetActiveWindow();
   x = (GetSystemMetrics(SM_CXSCREEN)-PO_DLG_W)/2;
   y = (GetSystemMetrics(SM_CYSCREEN)-PO_DLG_H)/2;

   d.hDlg = CreateWindowExA(WS_EX_DLGMODALFRAME|WS_EX_TOPMOST,
      "HbProjOpt","Project Options",
      WS_POPUP|WS_CAPTION|WS_SYSMENU|WS_VISIBLE,
      x,y,PO_DLG_W,PO_DLG_H,hOwner,NULL,GetModuleHandle(NULL),NULL);
   SetWindowLongPtr(d.hDlg,GWLP_USERDATA,(LONG_PTR)&d);

   hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

   /* Tab control */
   d.hTab = CreateWindowExA(0,WC_TABCONTROLA,NULL,
      WS_CHILD|WS_VISIBLE|WS_CLIPSIBLINGS,
      8,8,PO_DLG_W-24,PO_TAB_HEIGHT+8,
      d.hDlg,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(d.hTab,WM_SETFONT,(WPARAM)hFont,TRUE);

   tci.mask=TCIF_TEXT;
   tci.pszText="Harbour";    SendMessageA(d.hTab,TCM_INSERTITEMA,0,(LPARAM)&tci);
   tci.pszText="C Compiler"; SendMessageA(d.hTab,TCM_INSERTITEMA,1,(LPARAM)&tci);
   tci.pszText="Linker";     SendMessageA(d.hTab,TCM_INSERTITEMA,2,(LPARAM)&tci);
   tci.pszText="Directories";SendMessageA(d.hTab,TCM_INSERTITEMA,3,(LPARAM)&tci);

   /* === Tab 0: Harbour === */
   PO_AddLabel(d.hDlg,"Harbour directory:",16,baseY,150);
   d.hHbDir = PO_AddEdit(d.hDlg,hb_parc(1),16,baseY+18,PO_DLG_W-48,22);
   PO_AddLabel(d.hDlg,"Compiler flags:",16,baseY+50,150);
   d.hHbFlags = PO_AddEdit(d.hDlg,hb_parc(5),16,baseY+68,PO_DLG_W-48,22);
   d.hChkWarn = PO_AddCheck(d.hDlg,"Enable warnings (/w)",16,baseY+100,hb_parl(12));
   d.hChkDebug = PO_AddCheck(d.hDlg,"Debug info (/b)",16,baseY+124,hb_parl(11));

   /* === Tab 1: C Compiler === */
   PO_AddLabel(d.hDlg,"C Compiler directory:",16,baseY,150);
   d.hCDir = PO_AddEdit(d.hDlg,hb_parc(2),16,baseY+18,PO_DLG_W-48,22);
   PO_AddLabel(d.hDlg,"C compiler flags:",16,baseY+50,150);
   d.hCFlags = PO_AddEdit(d.hDlg,hb_parc(6),16,baseY+68,PO_DLG_W-48,22);
   d.hChkOpt = PO_AddCheck(d.hDlg,"Enable optimization (-O2)",16,baseY+100,hb_parl(13));

   /* === Tab 2: Linker === */
   PO_AddLabel(d.hDlg,"Linker flags:",16,baseY,150);
   d.hLinkFlags = PO_AddEdit(d.hDlg,hb_parc(7),16,baseY+18,PO_DLG_W-48,22);
   PO_AddLabel(d.hDlg,"Additional libraries (one per line):",16,baseY+50,250);
   d.hLibs = PO_AddEdit(d.hDlg,hb_parc(10),16,baseY+68,PO_DLG_W-48,120);

   /* === Tab 3: Directories === */
   PO_AddLabel(d.hDlg,"Project directory:",16,baseY,150);
   d.hProjDir = PO_AddEdit(d.hDlg,hb_parc(3),16,baseY+18,PO_DLG_W-48,22);
   PO_AddLabel(d.hDlg,"Output directory:",16,baseY+50,150);
   d.hOutDir = PO_AddEdit(d.hDlg,hb_parc(4),16,baseY+68,PO_DLG_W-48,22);
   PO_AddLabel(d.hDlg,"Include paths (semicolon-separated):",16,baseY+100,280);
   d.hIncPaths = PO_AddEdit(d.hDlg,hb_parc(8),16,baseY+118,PO_DLG_W-48,22);
   PO_AddLabel(d.hDlg,"Library paths (semicolon-separated):",16,baseY+148,280);
   d.hLibPaths = PO_AddEdit(d.hDlg,hb_parc(9),16,baseY+166,PO_DLG_W-48,22);

   /* OK / Cancel buttons */
   { HWND hBtn;
     hBtn = CreateWindowExA(0,"BUTTON","OK",WS_CHILD|WS_VISIBLE|BS_DEFPUSHBUTTON,
        PO_DLG_W/2-100,PO_DLG_H-70,90,28,d.hDlg,(HMENU)IDOK,GetModuleHandle(NULL),NULL);
     SendMessage(hBtn,WM_SETFONT,(WPARAM)hFont,TRUE);
     hBtn = CreateWindowExA(0,"BUTTON","Cancel",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
        PO_DLG_W/2+10,PO_DLG_H-70,90,28,d.hDlg,(HMENU)IDCANCEL,GetModuleHandle(NULL),NULL);
     SendMessage(hBtn,WM_SETFONT,(WPARAM)hFont,TRUE);
   }

   /* Show first tab */
   PO_ShowTab(&d, 0);

   /* Modal loop */
   EnableWindow(hOwner, FALSE);
   while(IsWindow(d.hDlg) && GetMessage(&msg,NULL,0,0)) {
      if(msg.message==WM_KEYDOWN && msg.wParam==VK_ESCAPE) {
         SendMessage(d.hDlg,WM_CLOSE,0,0); break; }
      TranslateMessage(&msg); DispatchMessage(&msg);
   }
}

/* ======================================================================
 * Palette Icon Generator - generates palette_new.bmp from within IDE
 * ====================================================================== */

HB_FUNC( W32_GENERATEPALETTEICONS )
{
   #undef IC
   #undef IS
   #define IC 109
   #define IS 32
   /* Map each palette slot to a Lazarus icon filename (or NULL for fallback) */
   static const char * pngNames[] = {
      "tlabel","tedit","tbutton","tmemo","tcheckbox","tradiobutton","tlistbox","tcombobox",
      "tgroupbox","tpanel","tscrollbar",
      "tbitbtn","tspeedbutton","timage","tshape","tbevel","tmaskededit","tstringgrid",
      "tscrollbox","tstatusbar","tlabel",
      "ttabcontrol","ttreeview","tlistview","tprogressbar","trichmemo","ttrackbar",
      "tupdown","tdatetimepicker","tcalendar",
      "ttimer","tpaintbox",
      "topendialog","tsavedialog","tfontdialog","tcolordialog","tfinddialog","treplacedialog",
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      "tdbgrid","tdbgrid","tdbnavigator","tdbtext","tdbedit","tdbcombobox","tdbcheckbox","tdbimage",
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,
      NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL
   };
   static const char * ab[] = {
      "A","ab","Btn","M","Ck","Rd","Ls","Cb","Gp","Pn","SB",
      "BB","Sp","Im","Sh","Bv","Mk","SG","SB","ST","LE",
      "Tb","TV","LV","PB","RE","TK","UD","DT","MC",
      "Tm","Px","Op","Sv","Ft","Cl","Fn","Rp",
      "DB","My","Mr","Pg","SL","Fb","MS","Or","Mg",
      "Bw","DG","DN","DT","DE","DC","DK","DI",
      "Pr","Rp","Lb","PP","PS","PD","RV","BP",
      "Wb","WS","Wk","HT","FT","SM","TS","TC","UD",
      "PP","Sc","Rp","BC","PD","XL","Au","Pm","Cu","Tx","Ds","Sh",
      "Th","Mx","Se","CS","TP","At","CV","Ch",
      "OA","Gm","Cl","DS","Gk","Ol","Tf",
      "x","x","x","x","x","x","x","x","x","x","x","x"
   };
   static COLORREF cl[] = {
      0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,0xDB9834,
      0xB6599B,0xB6599B,0xB6599B,0xB6599B,0xB6599B,0xB6599B,0xB6599B,0xB6599B,0xB6599B,0xB6599B,
      0x71CC2E,0x71CC2E,0x71CC2E,0x71CC2E,0x71CC2E,0x71CC2E,0x71CC2E,0x71CC2E,0x71CC2E,
      0x0FC4F1,0x0FC4F1,0x227EE6,0x227EE6,0x227EE6,0x227EE6,0x227EE6,0x227EE6,
      0x3C4CE7,0x3C4CE7,0x3C4CE7,0x3C4CE7,0x3C4CE7,0x3C4CE7,0x3C4CE7,0x3C4CE7,0x3C4CE7,
      0x2B39C0,0x2B39C0,0x2B39C0,0x2B39C0,0x2B39C0,0x2B39C0,0x2B39C0,0x2B39C0,
      0x8D8C7F,0x8D8C7F,0x8D8C7F,0x8D8C7F,0x8D8C7F,0x8D8C7F,0x8D8C7F,0x8D8C7F,
      0x9CBC1A,0x9CBC1A,0x9CBC1A,0x9CBC1A,0x9CBC1A,0x9CBC1A,0x9CBC1A,0x9CBC1A,0x9CBC1A,
      0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,0xAD448E,
      0x503E2C,0x503E2C,0x503E2C,0x503E2C,0x503E2C,0x503E2C,0x503E2C,0x503E2C,
      0x129CF3,0x129CF3,0x129CF3,0x129CF3,0x129CF3,0x129CF3,0x129CF3,
      0,0,0,0,0,0,0,0,0,0,0,0
   };

   int tw = IC * IS, i, rb, ds;
   HDC hS, hM; HBITMAP hB, hO; void * pB;
   BITMAPFILEHEADER bf; BITMAPINFOHEADER bi;
   HFONT hF, hOF; LOGFONTA lf; FILE * fp;
   char szPath[MAX_PATH];

   hS = GetDC(NULL); hM = CreateCompatibleDC(hS);
   memset(&bi,0,sizeof(bi)); bi.biSize=sizeof(bi); bi.biWidth=tw; bi.biHeight=IS;
   bi.biPlanes=1; bi.biBitCount=24;
   hB = CreateDIBSection(hM,(BITMAPINFO*)&bi,DIB_RGB_COLORS,&pB,NULL,0);
   hO = (HBITMAP)SelectObject(hM,hB);

   { RECT r; HBRUSH b;
     r.left=0; r.top=0; r.right=tw; r.bottom=IS;
     b=CreateSolidBrush(RGB(255,0,255));
     FillRect(hM,&r,b); DeleteObject(b); }

   memset(&lf,0,sizeof(lf)); lf.lfHeight=-11; lf.lfWeight=FW_BOLD;
   lf.lfCharSet=DEFAULT_CHARSET; lstrcpyA(lf.lfFaceName,"Segoe UI");
   hF=CreateFontIndirectA(&lf); hOF=(HFONT)SelectObject(hM,hF);
   SetBkMode(hM,TRANSPARENT); SetTextColor(hM,RGB(255,255,255));

   EnsureGdiPlus();

   for(i=0;i<IC;i++) {
      int x=i*IS;
      RECT ri, rt;
      BOOL bDrawn = FALSE;
      ri.left=x+1; ri.top=1; ri.right=x+IS-1; ri.bottom=IS-1;
      rt.left=x+2; rt.top=7; rt.right=x+IS-2; rt.bottom=IS-4;

      /* Try to load Lazarus PNG icon */
      if( i < (int)(sizeof(pngNames)/sizeof(pngNames[0])) && pngNames[i] )
      {
         char pngPath[MAX_PATH]; WCHAR wPath[MAX_PATH];
         GpImage * pImg = NULL;
         GetModuleFileNameA(NULL, pngPath, MAX_PATH);
         { char*p=strrchr(pngPath,'\\'); if(p)*p=0; }
         { char*p=strrchr(pngPath,'\\'); if(p)*p=0; }
         lstrcatA(pngPath,"\\resources\\lazarus_icons\\");
         lstrcatA(pngPath,pngNames[i]); lstrcatA(pngPath,".png");
         MultiByteToWideChar(CP_ACP,0,pngPath,-1,wPath,MAX_PATH);
         if( GdipLoadImageFromFile(wPath,&pImg) == 0 && pImg )
         {
            GpGraphics * gfx = NULL;
            GdipCreateFromHDC(hM, &gfx);
            if( gfx ) {
               /* Draw PNG centered in 32x32 cell (PNG is 24x24) */
               GdipDrawImageRectI(gfx, pImg, x+4, 4, 24, 24);
               GdipDeleteGraphics(gfx);
               bDrawn = TRUE;
            }
            GdipDisposeImage(pImg);
         }
      }

      /* Fallback: colored rectangle with text */
      if( !bDrawn )
      {
         COLORREF bg=cl[i]; int r=GetRValue(bg),g=GetGValue(bg),b=GetBValue(bg);
         HBRUSH hBr; HPEN hP;
         r=r>40?r-40:0; g=g>40?g-40:0; b=b>40?b-40:0;
         hBr=CreateSolidBrush(bg); hP=CreatePen(PS_SOLID,1,RGB(r,g,b));
         SelectObject(hM,hBr); SelectObject(hM,hP);
         RoundRect(hM,ri.left,ri.top,ri.right,ri.bottom,6,6);
         DeleteObject(hBr); DeleteObject(hP);
         DrawTextA(hM,ab[i],-1,&rt,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
      }
   }
   SelectObject(hM,hOF); DeleteObject(hF);

   rb=((tw*3+3)&~3); ds=rb*IS;
   memset(&bf,0,sizeof(bf)); bf.bfType=0x4D42;
   bf.bfSize=sizeof(bf)+sizeof(bi)+ds; bf.bfOffBits=sizeof(bf)+sizeof(bi);

   GetModuleFileNameA(NULL,szPath,MAX_PATH);
   { char*p=strrchr(szPath,'\\'); if(p)*p=0; }
   { char*p=strrchr(szPath,'\\'); if(p)*p=0; } /* up to project root */
   lstrcatA(szPath,"\\resources\\palette_new.bmp");

   fp=fopen(szPath,"wb");
   if(fp) {
      fwrite(&bf,sizeof(bf),1,fp); fwrite(&bi,sizeof(bi),1,fp);
      fwrite(pB,ds,1,fp); fclose(fp);
      { FILE*fl=fopen("c:\\HarbourBuilder\\palette_gen_trace.log","a");
        if(fl){fprintf(fl,"Generated: %s (%d icons)\n",szPath,IC);fclose(fl);} }
      if( !hb_parl(1) ) /* not silent */
      { char msg[300]; sprintf(msg,"Generated: %s\n\n%d icons, %dx%d pixels\n\nRename to palette.bmp to use.",
         szPath,IC,IS,IS);
        MessageBoxA(NULL,msg,"Palette Icons Generated",MB_OK|MB_ICONINFORMATION); }
   } else {
      if( !hb_parl(1) )
         MessageBoxA(NULL,"Error creating file!","Error",MB_OK|MB_ICONERROR);
   }
   SelectObject(hM,hO); DeleteObject(hB); DeleteDC(hM); ReleaseDC(NULL,hS);
}

/* ======================================================================
 * Toolbar Icon Generator - generates toolbar_new.bmp from Lazarus PNGs
 * ====================================================================== */

HB_FUNC( W32_GENERATETOOLBARICONS )
{
   /* 9 toolbar buttons: New, Open, Save, Cut, Copy, Paste, Undo, Redo, Run */
   static const char * tbPngs[] = {
      "menu_new", "menu_project_open", "menu_project_save",
      "laz_cut", "laz_copy", "laz_paste",
      "menu_undo", "menu_redo", "menu_build_run_file"
   };
   int nBtns = 9, tw = nBtns * 32, i, rb, ds;
   HDC hS, hM; HBITMAP hB, hO; void * pB;
   BITMAPFILEHEADER bf; BITMAPINFOHEADER bi;
   FILE * fp; char szPath[MAX_PATH], szBase[MAX_PATH];

   EnsureGdiPlus();

   hS = GetDC(NULL); hM = CreateCompatibleDC(hS);
   memset(&bi,0,sizeof(bi)); bi.biSize=sizeof(bi); bi.biWidth=tw; bi.biHeight=32;
   bi.biPlanes=1; bi.biBitCount=24;
   hB = CreateDIBSection(hM,(BITMAPINFO*)&bi,DIB_RGB_COLORS,&pB,NULL,0);
   hO = (HBITMAP)SelectObject(hM,hB);

   /* Fill with magenta (transparency key) */
   { RECT r; HBRUSH b;
     r.left=0; r.top=0; r.right=tw; r.bottom=32;
     b=CreateSolidBrush(RGB(255,0,255));
     FillRect(hM,&r,b); DeleteObject(b); }

   /* Get base path */
   GetModuleFileNameA(NULL, szBase, MAX_PATH);
   { char*p=strrchr(szBase,'\\'); if(p)*p=0; }
   { char*p=strrchr(szBase,'\\'); if(p)*p=0; }

   for(i=0;i<nBtns;i++) {
      WCHAR wPath[MAX_PATH]; GpImage * pImg = NULL;
      sprintf(szPath,"%s\\resources\\lazarus_icons\\%s.png",szBase,tbPngs[i]);
      MultiByteToWideChar(CP_ACP,0,szPath,-1,wPath,MAX_PATH);
      if( GdipLoadImageFromFile(wPath,&pImg) == 0 && pImg ) {
         GpGraphics * gfx = NULL;
         GdipCreateFromHDC(hM, &gfx);
         if( gfx ) {
            /* Scale 16x16 PNG to 28x28, centered in 32x32 cell */
            GdipDrawImageRectI(gfx, pImg, i*32+2, 2, 28, 28);
            GdipDeleteGraphics(gfx);
         }
         GdipDisposeImage(pImg);
      }
   }

   rb=((tw*3+3)&~3); ds=rb*32;
   memset(&bf,0,sizeof(bf)); bf.bfType=0x4D42;
   bf.bfSize=sizeof(bf)+sizeof(bi)+ds; bf.bfOffBits=sizeof(bf)+sizeof(bi);

   sprintf(szPath,"%s\\resources\\toolbar_new.bmp",szBase);
   fp=fopen(szPath,"wb");
   if(fp) {
      fwrite(&bf,sizeof(bf),1,fp); fwrite(&bi,sizeof(bi),1,fp);
      fwrite(pB,ds,1,fp); fclose(fp);
      { FILE*fl=fopen("c:\\HarbourBuilder\\toolbar_gen_trace.log","a");
        if(fl){fprintf(fl,"Generated: %s (%d icons)\n",szPath,nBtns);fclose(fl);} }
      if( !hb_parl(1) )
      { char msg[300]; sprintf(msg,"Generated: %s\n9 toolbar icons",szPath);
        MessageBoxA(NULL,msg,"Toolbar Icons",MB_OK|MB_ICONINFORMATION); }
   }
   SelectObject(hM,hO); DeleteObject(hB); DeleteDC(hM); ReleaseDC(NULL,hS);
}

/* ======================================================================
 * About Dialog - custom dialog with logo image
 * ====================================================================== */

static GpImage * s_aboutLogo = NULL;
static const char * s_aboutText = NULL;

static LRESULT CALLBACK AboutDlgProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   switch( msg )
   {
      case WM_PAINT:
      {
         PAINTSTRUCT ps;
         HDC hDC = BeginPaint( hWnd, &ps );
         RECT rc;
         int imgY = 20;

         GetClientRect( hWnd, &rc );

         /* Draw logo if loaded (PNG via GDI+) */
         if( s_aboutLogo )
         {
            UINT imgW = 0, imgH = 0;
            GpGraphics * gfx = NULL;
            int imgX;
            GdipGetImageWidth( s_aboutLogo, &imgW );
            GdipGetImageHeight( s_aboutLogo, &imgH );
            imgX = ( rc.right - (int)imgW ) / 2;
            if( imgX < 10 ) imgX = 10;
            GdipCreateFromHDC( hDC, &gfx );
            if( gfx ) {
               GdipDrawImageRectI( gfx, s_aboutLogo, imgX, imgY, (INT)imgW, (INT)imgH );
               GdipDeleteGraphics( gfx );
            }
            imgY += (int)imgH + 16;
         }

         /* Draw text */
         if( s_aboutText )
         {
            RECT rcText;
            HFONT hFont, hOldFont;
            LOGFONTA lf = {0};
            lf.lfHeight = -15; lf.lfCharSet = DEFAULT_CHARSET;
            lstrcpyA( lf.lfFaceName, "Segoe UI" );
            hFont = CreateFontIndirectA( &lf );
            hOldFont = (HFONT) SelectObject( hDC, hFont );
            SetTextColor( hDC, RGB(40, 40, 40) );
            SetBkMode( hDC, TRANSPARENT );
            rcText.left = 20; rcText.top = imgY;
            rcText.right = rc.right - 20; rcText.bottom = rc.bottom - 46;
            DrawTextA( hDC, s_aboutText, -1, &rcText,
               DT_LEFT | DT_WORDBREAK | DT_NOPREFIX );
            SelectObject( hDC, hOldFont );
            DeleteObject( hFont );
         }

         EndPaint( hWnd, &ps );
         return 0;
      }

      case WM_COMMAND:
         if( LOWORD(wParam) == IDOK || LOWORD(wParam) == IDCANCEL )
         {
            EnableWindow( GetParent(hWnd) ? GetParent(hWnd) : GetDesktopWindow(), TRUE );
            DestroyWindow( hWnd );
            return 0;
         }
         break;

      case WM_CLOSE:
         EnableWindow( GetParent(hWnd) ? GetParent(hWnd) : GetDesktopWindow(), TRUE );
         DestroyWindow( hWnd );
         return 0;
   }
   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* W32_AboutDialog( cTitle, cText, cImagePath ) */
HB_FUNC( W32_ABOUTDIALOG )
{
   static BOOL bReg = FALSE;
   WNDCLASSA wc = {0};
   HWND hDlg, hBtn, hOwner;
   HFONT hFont, hTextFont;
   int dlgW = 380, dlgH;
   int x, y;
   int contentH = 20; /* top padding */
   MSG msg;

   s_aboutText = HB_ISCHAR(2) ? hb_parc(2) : "";

   /* Load PNG logo via GDI+ */
   EnsureGdiPlus();
   if( s_aboutLogo ) { GdipDisposeImage( s_aboutLogo ); s_aboutLogo = NULL; }
   if( HB_ISCHAR(3) )
   {
      WCHAR wPath[MAX_PATH];
      MultiByteToWideChar( CP_ACP, 0, hb_parc(3), -1, wPath, MAX_PATH );
      GdipLoadImageFromFile( wPath, &s_aboutLogo );
   }

   /* Measure content height: logo + text + button */
   if( s_aboutLogo )
   {
      UINT imgH = 0;
      GdipGetImageHeight( s_aboutLogo, &imgH );
      contentH += (int)imgH + 16;
   }

   /* Measure text height */
   {
      HDC hScreen = GetDC( NULL );
      LOGFONTA lf = {0};
      RECT rcMeasure;
      rcMeasure.left = 0; rcMeasure.top = 0; rcMeasure.right = dlgW - 40; rcMeasure.bottom = 0;
      lf.lfHeight = -15; lf.lfCharSet = DEFAULT_CHARSET;
      lstrcpyA( lf.lfFaceName, "Segoe UI" );
      hTextFont = CreateFontIndirectA( &lf );
      SelectObject( hScreen, hTextFont );
      DrawTextA( hScreen, s_aboutText, -1, &rcMeasure,
         DT_LEFT | DT_WORDBREAK | DT_NOPREFIX | DT_CALCRECT );
      contentH += rcMeasure.bottom + 20; /* text + spacing */
      DeleteObject( hTextFont );
      ReleaseDC( NULL, hScreen );
   }

   contentH += 30 + 16; /* OK button height + bottom padding */

   /* Add frame (title bar + borders) */
   dlgH = contentH + GetSystemMetrics( SM_CYCAPTION ) + GetSystemMetrics( SM_CYFIXEDFRAME ) * 2;

   if( !bReg )
   {
      wc.lpfnWndProc = AboutDlgProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.hCursor = LoadCursor(NULL, IDC_ARROW);
      wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
      wc.lpszClassName = "HbAboutDlg";
      RegisterClassA( &wc );
      bReg = TRUE;
   }

   hOwner = GetActiveWindow();
   /* Center on screen */
   x = ( GetSystemMetrics(SM_CXSCREEN) - dlgW ) / 2;
   y = ( GetSystemMetrics(SM_CYSCREEN) - dlgH ) / 2;

   hDlg = CreateWindowExA( WS_EX_DLGMODALFRAME | WS_EX_TOPMOST,
      "HbAboutDlg", HB_ISCHAR(1) ? hb_parc(1) : "About",
      WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE,
      x, y, dlgW, dlgH,
      hOwner, NULL, GetModuleHandle(NULL), NULL );

   /* OK button — positioned relative to client bottom */
   {
      RECT rcClient;
      GetClientRect( hDlg, &rcClient );
      hFont = (HFONT) GetStockObject( DEFAULT_GUI_FONT );
      hBtn = CreateWindowExA( 0, "BUTTON", "OK",
         WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
         (rcClient.right - 90) / 2, rcClient.bottom - 30 - 12, 90, 30,
         hDlg, (HMENU)IDOK, GetModuleHandle(NULL), NULL );
      SendMessage( hBtn, WM_SETFONT, (WPARAM) hFont, TRUE );
   }

   /* Modal loop */
   EnableWindow( hOwner, FALSE );
   while( IsWindow(hDlg) && GetMessage( &msg, NULL, 0, 0 ) )
   {
      if( msg.message == WM_KEYDOWN && msg.wParam == VK_ESCAPE )
      {
         SendMessage( hDlg, WM_CLOSE, 0, 0 );
         break;
      }
      if( msg.message == WM_KEYDOWN && msg.wParam == VK_RETURN )
      {
         SendMessage( hDlg, WM_COMMAND, IDOK, 0 );
         break;
      }
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }

   /* Cleanup */
   if( s_aboutLogo ) { GdipDisposeImage( s_aboutLogo ); s_aboutLogo = NULL; }
   s_aboutText = NULL;
}

/* ======================================================================
 * Code Editor - Scintilla with syntax highlighting and TABS
 * ====================================================================== */

#define MAX_TABS         32
#define TAB_HEIGHT       24
#define STATUSBAR_HEIGHT 22

/* Scintilla message defines */
#define SCI_SETTEXT        2181
#define SCI_GETTEXT        2182
#define SCI_GETTEXTLENGTH  2183
#define SCI_ADDTEXT        2001
#define SCI_CLEARALL       2004
#define SCI_GETLENGTH      2006
#define SCI_GETCURRENTPOS  2008
#define SCI_SETSEL         2160
#define SCI_GOTOPOS        2025
#define SCI_GOTOLINE       2024
#define SCI_SCROLLCARET    2169
#define SCI_SETREADONLY     2171
#define SCI_GETREADONLY     2173
#define SCI_REPLACESEL     2170
#define SCI_SEARCHNEXT     2367
#define SCI_SEARCHPREV     2368
#define SCI_SETTARGETSTART 2190
#define SCI_SETTARGETEND   2192
#define SCI_SEARCHINTARGET 2197
#define SCI_REPLACETARGET  2194
#define SCI_GETSELECTIONSTART 2143
#define SCI_GETSELECTIONEND   2145
#define SCI_SETSELECTIONSTART 2142
#define SCI_SETSELECTIONEND   2144
#define SCI_FINDTEXT       2150

/* Lexer + Styles */
#define SCI_SETILEXER      4033
#define SCI_SETKEYWORDS    4005
#define SCI_SETPROPERTY    4004
#define SCI_STYLESETFORE   2051
#define SCI_STYLESETBACK   2052
#define SCI_STYLESETBOLD   2053
#define SCI_STYLESETITALIC 2054
#define SCI_STYLESETSIZE   2055
#define SCI_STYLESETFONT   2056
#define SCI_STYLECLEARALL  2050

/* Margin */
#define SCI_SETMARGINTYPEN   2240
#define SCI_SETMARGINWIDTHN  2242
#define SCI_SETMARGINSENSITIVEN 2246
#define SC_MARGIN_NUMBER     1
#define SC_MARGIN_SYMBOL     0

/* Folding */
#define SCI_SETFOLDFLAGS       2233
#define SCI_SETMARGINMASKN     2244
#define SCI_MARKERDEFINE       2040
#define SCI_SETAUTOMATICFOLD   2663
#define SC_AUTOMATICFOLD_SHOW  0x01
#define SC_AUTOMATICFOLD_CLICK 0x02
#define SC_AUTOMATICFOLD_CHANGE 0x04
#define SC_FOLDLEVELBASE       0x400
#define SC_FOLDLEVELHEADERFLAG 0x2000
#define SC_MARKNUM_FOLDEROPEN  31
#define SC_MARKNUM_FOLDER      30
#define SC_MARKNUM_FOLDERSUB   29
#define SC_MARKNUM_FOLDERTAIL  28
#define SC_MARKNUM_FOLDEREND   25
#define SC_MARKNUM_FOLDEROPENMID 26
#define SC_MARKNUM_FOLDERMIDTAIL 27
#define SC_MARK_BOXPLUS         12
#define SC_MARK_BOXMINUS        14
#define SC_MARK_VLINE           9
#define SC_MARK_LCORNER         10
#define SC_MARK_BOXPLUSCONNECTED  13
#define SC_MARK_BOXMINUSCONNECTED 15
#define SC_MARK_TCORNER         11
#define SC_MASK_FOLDERS          0xFE000000

/* Misc */
#define SCI_SETTABWIDTH        2036
#define SCI_GETFIRSTVISIBLELINE 2152
#define SCI_SETFIRSTVISIBLELINE 2613
#define SCI_SETINDENTATIONGUIDES 2132
#define SC_IV_LOOKBOTH           3
#define SCI_SETVIEWEOL         2356
#define SCI_SETWRAPMODE        2268
#define SCI_SETSELEOLFILLED    2477
#define SCI_SETCARETFORE       2069
#define SCI_SETSELBACK         2068
#define SCI_SETWHITESPACEFORE  2084
#define SCI_SETWHITESPACEBACK  2085
#define SCI_SETEXTRAASCENT     2525
#define SCI_SETEXTRADESCENT    2527
#define SCI_EMPTYUNDOBUFFER    2175
#define SCI_SETUNDOCOLLECTION  2012
#define SCI_SETSAVEPOINT       2014
#define SCI_SETFOCUS           2380
#define SCI_GETCURLINE         2027
#define SCI_LINEFROMPOSITION   2166
#define SCI_POSITIONFROMLINE   2167
#define SCI_GETLINECOUNT       2154
#define SCI_GETLINE            2153
#define SCI_LINELENGTH         2350
#define SCI_SETCODEPAGE        2037
#define SC_CP_UTF8             65001
#define STYLE_DEFAULT          32
#define STYLE_LINENUMBER       33

/* C/C++ lexer style IDs (used for Harbour too) */
#define SCE_C_DEFAULT          0
#define SCE_C_COMMENT          1
#define SCE_C_COMMENTLINE      2
#define SCE_C_COMMENTDOC       3
#define SCE_C_NUMBER           4
#define SCE_C_WORD             5
#define SCE_C_STRING           6
#define SCE_C_CHARACTER        7
#define SCE_C_PREPROCESSOR     9
#define SCE_C_OPERATOR         10
#define SCE_C_IDENTIFIER       11
#define SCE_C_WORD2            16
#define SCE_C_GLOBALCLASS      19
#define SCE_C_PREPROCESSORCOMMENT 23

/* Scintilla DLL function types */
typedef void * ILexer5;
typedef ILexer5 * (__stdcall * CreateLexerFn)(const char * name);

static HMODULE s_hScintilla = NULL;
static HMODULE s_hLexilla   = NULL;
static CreateLexerFn s_pCreateLexer = NULL;

/* Send message to Scintilla */
#define SciMsg(hwnd, msg, wp, lp) SendMessage((hwnd), (msg), (WPARAM)(wp), (LPARAM)(lp))

typedef struct {
   HWND hWnd;       /* Tool window */
   HWND hEdit;      /* Scintilla control */
   HWND hTab;       /* Tab control */
   /* Tab management */
   int nTabs;
   int nActiveTab;  /* 0-based */
   char * aTexts[MAX_TABS];
   /* Harbour callback for tab change */
   PHB_ITEM pOnTabChange;
   /* Debounced text-change callback */
   PHB_ITEM pOnTextChange;
   UINT_PTR debounceTimer;    /* SetTimer id, 0 = none */
   int bSettingText;          /* guard: programmatic text set in progress */
   /* Find bar */
   HWND hFindBar;     /* Find bar panel */
   HWND hFindEdit;    /* Search text input */
   HWND hFindLabel;   /* Match count label */
   HWND hReplaceEdit; /* Replace text input */
   BOOL bFindVisible;
   BOOL bReplaceVisible;
   /* Status bar */
   HWND hStatusBar;   /* Status bar at bottom */
} CODEEDITOR;

static void SwitchTab( CODEEDITOR * ed, int nNewTab );

/* Initialize Scintilla DLLs */
static BOOL InitScintilla( void )
{
   char szPath[MAX_PATH];
   FILE * fLog;

   if( s_hScintilla ) return TRUE;  /* already loaded */

   fLog = fopen( "c:\\HarbourBuilder\\scintilla_trace.log", "a" );

   /* Try loading from resources/ first */
   GetModuleFileNameA( NULL, szPath, MAX_PATH );
   { char * p = strrchr( szPath, '\\' );
     if( p ) { *p = 0; }
   }
   strcat( szPath, "\\..\\resources\\Scintilla.dll" );

   s_hScintilla = LoadLibraryA( szPath );
   if( fLog ) fprintf( fLog, "LoadLibrary Scintilla '%s' => %p\n", szPath, s_hScintilla );

   if( !s_hScintilla ) {
      /* Try current directory */
      s_hScintilla = LoadLibraryA( "Scintilla.dll" );
      if( fLog ) fprintf( fLog, "LoadLibrary Scintilla.dll (cwd) => %p\n", s_hScintilla );
   }

   if( !s_hScintilla ) {
      if( fLog ) { fprintf( fLog, "FAILED to load Scintilla.dll\n" ); fclose( fLog ); }
      return FALSE;
   }

   /* Load Lexilla */
   { char * p = strrchr( szPath, '\\' );
     if( p ) { *p = 0; strcat( szPath, "\\Lexilla.dll" ); }
   }
   s_hLexilla = LoadLibraryA( szPath );
   if( fLog ) fprintf( fLog, "LoadLibrary Lexilla '%s' => %p\n", szPath, s_hLexilla );

   if( !s_hLexilla ) {
      s_hLexilla = LoadLibraryA( "Lexilla.dll" );
      if( fLog ) fprintf( fLog, "LoadLibrary Lexilla.dll (cwd) => %p\n", s_hLexilla );
   }

   if( s_hLexilla ) {
      s_pCreateLexer = (CreateLexerFn) GetProcAddress( s_hLexilla, "CreateLexer" );
      if( fLog ) fprintf( fLog, "CreateLexer proc => %p\n", s_pCreateLexer );
   }

   if( fLog ) { fprintf( fLog, "InitScintilla OK\n" ); fclose( fLog ); }
   return TRUE;
}

/* Configure Scintilla with Harbour syntax highlighting */
static void ConfigureScintilla( HWND hSci )
{
   ILexer5 * pLexer;

   /* UTF-8 code page */
   SciMsg( hSci, SCI_SETCODEPAGE, SC_CP_UTF8, 0 );

   /* Tab width */
   SciMsg( hSci, SCI_SETTABWIDTH, 3, 0 );

   /* Set C/C++ lexer via Lexilla (works for Harbour too) */
   if( s_pCreateLexer ) {
      pLexer = s_pCreateLexer( "cpp" );
      if( pLexer ) {
         SciMsg( hSci, SCI_SETILEXER, 0, (LPARAM) pLexer );
      }
   }

   /* Default style: Consolas 11pt, light gray on dark */
   SciMsg( hSci, SCI_STYLESETFONT, STYLE_DEFAULT, (LPARAM) "Consolas" );
   SciMsg( hSci, SCI_STYLESETSIZE, STYLE_DEFAULT, 14 );
   SciMsg( hSci, SCI_STYLESETFORE, STYLE_DEFAULT, RGB(212,212,212) );
   SciMsg( hSci, SCI_STYLESETBACK, STYLE_DEFAULT, RGB(30,30,30) );
   SciMsg( hSci, SCI_STYLECLEARALL, 0, 0 );  /* Apply default to all styles */

   /* Line number margin */
   SciMsg( hSci, SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER );
   SciMsg( hSci, SCI_SETMARGINWIDTHN, 0, 48 );
   SciMsg( hSci, SCI_STYLESETFORE, STYLE_LINENUMBER, RGB(133,133,133) );
   SciMsg( hSci, SCI_STYLESETBACK, STYLE_LINENUMBER, RGB(37,37,38) );

   /* Folding margin */
   SciMsg( hSci, SCI_SETMARGINTYPEN, 2, SC_MARGIN_SYMBOL );
   SciMsg( hSci, SCI_SETMARGINMASKN, 2, SC_MASK_FOLDERS );
   SciMsg( hSci, SCI_SETMARGINWIDTHN, 2, 16 );
   SciMsg( hSci, SCI_SETMARGINSENSITIVEN, 2, 1 );
   SciMsg( hSci, SCI_SETAUTOMATICFOLD, SC_AUTOMATICFOLD_SHOW | SC_AUTOMATICFOLD_CLICK | SC_AUTOMATICFOLD_CHANGE, 0 );

   /* Fold markers - box style */
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDER,        SC_MARK_BOXPLUS );
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEROPEN,    SC_MARK_BOXMINUS );
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERSUB,     SC_MARK_VLINE );
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERTAIL,    SC_MARK_LCORNER );
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEREND,     SC_MARK_BOXPLUSCONNECTED );
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEROPENMID, SC_MARK_BOXMINUSCONNECTED );
   SciMsg( hSci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERMIDTAIL, SC_MARK_TCORNER );

   { int m;
     for( m = 25; m <= 31; m++ ) {
        SciMsg( hSci, 2041, m, RGB(160,160,160) );  /* SCI_MARKERSETFORE */
        SciMsg( hSci, 2042, m, RGB(37,37,38) );     /* SCI_MARKERSETBACK */
     }
   }

   /* Debug execution line marker (marker 11) - yellow background */
   SciMsg( hSci, SCI_MARKERDEFINE, 11, 22 );    /* SC_MARK_BACKGROUND = 22 */
   SciMsg( hSci, 2042, 11, RGB(80,80,0) );       /* SCI_MARKERSETBACK - yellow-ish */
   SciMsg( hSci, 2041, 11, RGB(0,0,0) );          /* SCI_MARKERSETFORE */

   /* Enable folding property */
   SciMsg( hSci, SCI_SETPROPERTY, (WPARAM) "fold", (LPARAM) "1" );
   SciMsg( hSci, SCI_SETPROPERTY, (WPARAM) "fold.compact", (LPARAM) "0" );
   SciMsg( hSci, SCI_SETPROPERTY, (WPARAM) "fold.comment", (LPARAM) "1" );
   SciMsg( hSci, SCI_SETPROPERTY, (WPARAM) "fold.preprocessor", (LPARAM) "1" );

   /* ===== Harbour keyword lists ===== */
   /* Keywords set 0: Harbour language keywords (lowercase) */
   SciMsg( hSci, SCI_SETKEYWORDS, 0, (LPARAM)
      "function procedure return local static private public "
      "if else elseif endif do while enddo for next to step in "
      "switch case otherwise endswitch endcase default "
      "class endclass method data access assign inherit inline "
      "nil self super begin end exit loop with sequence recover "
      "try catch finally true false and or not "
      "init announce request external memvar field parameters "
      "break continue optional redefine "
      "FUNCTION PROCEDURE RETURN LOCAL STATIC PRIVATE PUBLIC "
      "IF ELSE ELSEIF ENDIF DO WHILE ENDDO FOR NEXT TO STEP IN "
      "SWITCH CASE OTHERWISE ENDSWITCH ENDCASE DEFAULT "
      "CLASS ENDCLASS METHOD DATA ACCESS ASSIGN INHERIT INLINE "
      "NIL SELF SUPER BEGIN END EXIT LOOP WITH SEQUENCE RECOVER "
      "TRY CATCH FINALLY TRUE FALSE AND OR NOT "
      "INIT ANNOUNCE REQUEST EXTERNAL MEMVAR FIELD PARAMETERS "
      "BREAK CONTINUE OPTIONAL REDEFINE "
      "Function Procedure Return Local Static Private Public "
      "If Else ElseIf EndIf Do While EndDo For Next To Step In "
      "Switch Case Otherwise EndSwitch EndCase Default "
      "Class EndClass Method Data Access Assign Inherit Inline "
      "Nil Self Super Begin End Exit Loop With Sequence Recover "
      "Try Catch Finally True False And Or Not " );

   /* Keywords set 1: xBase commands + FiveWin (uppercase mapped to WORD2) */
   SciMsg( hSci, SCI_SETKEYWORDS, 1, (LPARAM)
      "DEFINE ACTIVATE FORM TITLE SIZE FONT SIZABLE APPBAR TOOLWINDOW "
      "CENTERED SAY GET BUTTON PROMPT CHECKBOX COMBOBOX GROUPBOX "
      "ITEMS CHECKED DEFAULT CANCEL OF VAR ACTION ON VALID WHEN FROM "
      "TOOLBAR SEPARATOR TOOLTIP MENUBAR POPUP MENUITEM MENUSEPARATOR "
      "PALETTE REQUEST ACCEL BITMAP ICON BROWSE DIALOG "
      "LISTBOX RADIOBUTTON SCROLLBAR PANEL IMAGE SHAPE BEVEL "
      "TREEVIEW LISTVIEW PROGRESSBAR RICHEDIT STATUSBAR SPLITTER "
      "TABS TAB MEMO DATEPICKER SPINNER GAUGE HEADER "
      "REPORT BAND COLUMN PRINTER PREVIEW "
      "WEBVIEW WEBSERVER SOCKET WEBSOCKET HTTPGET HTTPPOST "
      "THREAD MUTEX SEMAPHORE CRITICALSECTION ATOMICOP "
      "OLLAMA OPENAI GEMINI CLAUDE DEEPSEEK TRANSFORMER " );

   /* ===== Syntax highlighting colors (VS Code Dark+ inspired) ===== */
   /* Keywords: bright blue, bold */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_WORD, RGB(86,156,214) );
   SciMsg( hSci, SCI_STYLESETBOLD, SCE_C_WORD, 1 );

   /* Commands (WORD2): teal/cyan */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_WORD2, RGB(78,201,176) );

   /* Comments: green */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_COMMENT,     RGB(106,153,85) );
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_COMMENTLINE,  RGB(106,153,85) );
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_COMMENTDOC,   RGB(106,153,85) );
   SciMsg( hSci, SCI_STYLESETITALIC, SCE_C_COMMENT, 1 );
   SciMsg( hSci, SCI_STYLESETITALIC, SCE_C_COMMENTLINE, 1 );

   /* Strings: orange */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_STRING,    RGB(206,145,120) );
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_CHARACTER,  RGB(206,145,120) );

   /* Numbers: light green */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_NUMBER, RGB(181,206,168) );

   /* Preprocessor: magenta */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_PREPROCESSOR, RGB(197,134,192) );

   /* Operators: light gray */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_OPERATOR, RGB(212,212,212) );

   /* Identifiers: default light gray */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_IDENTIFIER, RGB(220,220,220) );

   /* Global classes: yellow-ish */
   SciMsg( hSci, SCI_STYLESETFORE, SCE_C_GLOBALCLASS, RGB(78,201,176) );

   /* Caret and selection */
   SciMsg( hSci, SCI_SETCARETFORE, RGB(255,255,255), 0 );
   SciMsg( hSci, SCI_SETSELBACK, 1, RGB(38,79,120) );

   /* Extra line spacing for readability */
   SciMsg( hSci, SCI_SETEXTRAASCENT, 1, 0 );
   SciMsg( hSci, SCI_SETEXTRADESCENT, 1, 0 );

   /* Indentation guides */
   SciMsg( hSci, SCI_SETINDENTATIONGUIDES, SC_IV_LOOKBOTH, 0 );

   { FILE * fLog = fopen( "c:\\HarbourBuilder\\scintilla_trace.log", "a" );
     if( fLog ) { fprintf( fLog, "ConfigureScintilla done for hwnd=%p\n", hSci ); fclose( fLog ); }
   }
}

/* ======================================================================
 * Harbour-aware code folding
 * Scans all lines and sets fold levels based on Harbour keywords:
 *   Open:  function, procedure, class, if, do while, for, switch, begin
 *   Close: return (top-level), endclass, endif, enddo, next, endswitch, end
 * ====================================================================== */

#define SCI_SETFOLDLEVEL   2222
#define SCI_GETFOLDLEVEL   2223
#define SCI_SETFOLDFLAGS2  2233

/* Check if a line starts with a word (case-insensitive), skipping leading spaces */
static int LineStartsWithCI( const char * line, int lineLen, const char * word )
{
   int i = 0, wLen = lstrlenA(word);
   /* Skip leading whitespace */
   while( i < lineLen && (line[i] == ' ' || line[i] == '\t') ) i++;
   if( i + wLen > lineLen ) return 0;
   if( _strnicmp( line + i, word, wLen ) != 0 ) return 0;
   /* Must be followed by space, (, EOL, or nothing */
   if( i + wLen < lineLen ) {
      char c = line[i + wLen];
      if( (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_' || (c >= '0' && c <= '9') )
         return 0;  /* Part of a longer word */
   }
   return 1;
}

static void UpdateHarbourFolding( HWND hSci )
{
   int lineCount, i;
   int level;

   if( !hSci ) return;

   lineCount = (int) SciMsg( hSci, SCI_GETLINECOUNT, 0, 0 );
   level = SC_FOLDLEVELBASE;

   for( i = 0; i < lineCount; i++ )
   {
      int lineLen = (int) SciMsg( hSci, SCI_LINELENGTH, i, 0 );
      int curLevel = level;
      int nextLevel = level;
      int isHeader = 0;

      if( lineLen > 0 && lineLen < 4096 )
      {
         char * buf = (char *) malloc( lineLen + 1 );
         SciMsg( hSci, SCI_GETLINE, i, (LPARAM) buf );
         buf[lineLen] = 0;

         /* Remove trailing CR/LF for matching */
         while( lineLen > 0 && (buf[lineLen-1] == '\r' || buf[lineLen-1] == '\n') )
            buf[--lineLen] = 0;

         /* === Fold openers === */
         if( LineStartsWithCI(buf, lineLen, "function") ||
             LineStartsWithCI(buf, lineLen, "procedure") ||
             LineStartsWithCI(buf, lineLen, "method") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "class") &&
                  !LineStartsWithCI(buf, lineLen, "endclass") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "if") &&
                  !LineStartsWithCI(buf, lineLen, "endif") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "do") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "for") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "switch") &&
                  !LineStartsWithCI(buf, lineLen, "endswitch") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "begin") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "while") &&
                  !LineStartsWithCI(buf, lineLen, "enddo") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }
         else if( LineStartsWithCI(buf, lineLen, "#pragma BEGINDUMP") ||
                  LineStartsWithCI(buf, lineLen, "#pragma begindump") )
         {
            isHeader = 1;
            nextLevel = level + 1;
         }

         /* === Fold closers === */
         else if( LineStartsWithCI(buf, lineLen, "return") ||
                  LineStartsWithCI(buf, lineLen, "endclass") ||
                  LineStartsWithCI(buf, lineLen, "endif") ||
                  LineStartsWithCI(buf, lineLen, "enddo") ||
                  LineStartsWithCI(buf, lineLen, "next") ||
                  LineStartsWithCI(buf, lineLen, "endswitch") ||
                  LineStartsWithCI(buf, lineLen, "endcase") ||
                  LineStartsWithCI(buf, lineLen, "end") ||
                  LineStartsWithCI(buf, lineLen, "#pragma ENDDUMP") ||
                  LineStartsWithCI(buf, lineLen, "#pragma enddump") )
         {
            if( level > SC_FOLDLEVELBASE )
            {
               curLevel = level - 1;
               nextLevel = level - 1;
            }
         }

         free( buf );
      }

      /* Set fold level for this line */
      SciMsg( hSci, SCI_SETFOLDLEVEL, i,
         curLevel | (isHeader ? SC_FOLDLEVELHEADERFLAG : 0) );

      level = nextLevel;
   }
}

/* Save current Scintilla text to the active tab's buffer */
static void SaveCurrentTabText( CODEEDITOR * ed )
{
   int nLen;
   if( !ed || !ed->hEdit || ed->nActiveTab < 0 || ed->nActiveTab >= ed->nTabs )
      return;

   if( ed->aTexts[ed->nActiveTab] )
      free( ed->aTexts[ed->nActiveTab] );

   nLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
   ed->aTexts[ed->nActiveTab] = (char *) malloc( nLen + 1 );
   SciMsg( ed->hEdit, SCI_GETTEXT, nLen + 1, (LPARAM) ed->aTexts[ed->nActiveTab] );
}

/* Switch to a different tab */
static void SwitchTab( CODEEDITOR * ed, int nNewTab )
{
   if( !ed || nNewTab < 0 || nNewTab >= ed->nTabs || nNewTab == ed->nActiveTab )
      return;

   /* Save current text */
   SaveCurrentTabText( ed );

   /* Load new tab text */
   ed->nActiveTab = nNewTab;
   ed->bSettingText = 1;
   SciMsg( ed->hEdit, SCI_SETTEXT, 0,
      (LPARAM)( ed->aTexts[nNewTab] ? ed->aTexts[nNewTab] : "" ) );

   /* Reset undo buffer for new tab */
   SciMsg( ed->hEdit, SCI_EMPTYUNDOBUFFER, 0, 0 );

   /* Update Harbour folding for the new tab */
   UpdateHarbourFolding( ed->hEdit );
   ed->bSettingText = 0;

   /* Update tab selection */
   SendMessage( ed->hTab, TCM_SETCURSEL, nNewTab, 0 );

   /* Harbour callback */
   if( ed->pOnTabChange )
   {
      PHB_ITEM pEd = hb_itemPutNInt( NULL, (HB_PTRUINT) ed );
      PHB_ITEM pTab = hb_itemPutNI( NULL, nNewTab + 1 );  /* 1-based */
      hb_evalBlock( ed->pOnTabChange, pEd, pTab, NULL );
      hb_itemRelease( pEd );
      hb_itemRelease( pTab );
   }
}

/* Scintilla handles line numbers and gutter natively - no manual gutter needed */

/* Scintilla find text helper struct */
typedef struct {
   int cpMin;
   int cpMax;
   const char * lpstrText;
   int flags;
} SCI_FINDINFO;

/* ======================================================================
 * Class member autocomplete — triggered when ':' is typed
 * ====================================================================== */

typedef struct {
   const char * className;
   const char * members;
} ClassMembers;

static ClassMembers s_classMembers[] = {
   { "TForm",
     "Activate() AlphaBlend AlphaBlendValue AppBar AutoScroll BorderIcons "
     "BorderStyle BorderWidth ClientHeight ClientWidth Close() Color CreateForm() Cursor "
     "Destroy() DoubleBuffered FontName FontSize FormStyle Height Hint "
     "KeyPreview Left ModalResult Name OnActivate OnChange OnClick OnClose "
     "OnCloseQuery OnCreate OnDblClick OnDeactivate OnDestroy OnHide "
     "OnKeyDown OnKeyPress OnKeyUp OnMouseDown OnMouseMove OnMouseUp "
     "OnMouseWheel OnPaint OnResize OnShow Position Show() ShowHint "
     "ShowModal() Sizable Text Title ToolWindow Top Width WindowState" },
   { "TLabel",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TEdit",
     "Height Left Name OnChange OnClick OnClose Text Top Value Width" },
   { "TMemo",
     "Height Left Name OnChange OnClick OnClose Text Top Value Width" },
   { "TButton",
     "Cancel Default Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TCheckBox",
     "Checked Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TRadioButton",
     "Checked Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TComboBox",
     "AddItem() Height Left Name OnChange OnClick OnClose Text Top Value Width" },
   { "TListBox",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TGroupBox",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TToolBar",
     "AddButton() AddSeparator() Height Left Name Text Top Width" },
   { "TTimer",
     "Height Left Name OnChange OnClick OnClose OnTimer Text Top Width" },
   { "TApplication",
     "CreateForm() Run() Title" },
   { "TPanel",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TProgressBar",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TTabControl",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TTreeView",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TListView",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TImage",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TDatabase",
     "Close() Exec() Field() FieldCount() FieldName() FreeResult() Goto() Host Name "
     "Open() Password Port Query() RecCount() RecNo() Server Skip() Table User" },
   { "TSQLite",
     "Close() Exec() Field() FieldCount() FieldName() FreeResult() Goto() Host Name "
     "Open() Password Port Query() RecCount() RecNo() Server Skip() Table User" },
   { "TReport",
     "Preview() Print()" },
   { "TWebServer",
     "Get() Post() Run()" },
   { "THttpClient",
     "Get() Post()" },
   { "TThread",
     "Join() Start()" },
   { "TOpenDialog",
     "cFileName cFilter cInitialDir cTitle DefaultExt Execute() Files FilterIndex "
     "Height Left Name OnClose Options Top Width" },
   { "TSaveDialog",
     "cFileName cFilter cInitialDir cTitle DefaultExt Execute() FilterIndex "
     "Height Left Name OnClose Options Top Width" },
   { "TFontDialog",
     "cFontName Color Execute() Height Left Name OnClose Size Style Top Width" },
   { "TColorDialog",
     "Color Execute() Height Left Name OnClose Top Width" },
   { "TFindDialog",
     "Execute() FindText Height Left Name OnClose OnFind Options Top Width" },
   { "TReplaceDialog",
     "Execute() FindText Height Left Name OnClose OnFind OnReplace Options ReplaceText Top Width" },
   { "TDBFTable",
     "Append() Bof() cAlias cDatabase cFileName cIndexFile cRDD Close() "
     "CreateIndex() Delete() Deleted() Eof() FieldCount() FieldGet() "
     "FieldName() FieldPut() Found() GoBottom() GoTo() GoTop() "
     "lConnected lExclusive lReadOnly nArea Open() Recall() "
     "RecCount() RecNo() Seek() Skip() Structure() Tables()" },
   { NULL, NULL }
};

/* Collect DATA/METHOD from current editor CLASS block */
static int CE_CollectUserData( HWND hSci, int classLine, char * buf, int bufSize )
{
   int pos = 0, l;
   int totalLines = (int) SciMsg( hSci, SCI_GETLINECOUNT,0, 0 );
   for( l = classLine + 1; l < totalLines; l++ )
   {
      char line[512];
      int len = (int) SciMsg( hSci, SCI_LINELENGTH,l, 0 );
      const char * p;
      int isData, isMethod;
      char name[64];
      int ni;
      if( len <= 0 || len >= (int)sizeof(line) ) continue;
      SciMsg( hSci, SCI_GETLINE,l, (LPARAM)line );
      line[len] = 0;
      p = line;
      while( *p == ' ' || *p == '\t' || *p == '\r' || *p == '\n' ) p++;
      if( *p == 0 ) continue;
      if( _strnicmp( p, "ENDCLASS", 8 ) == 0 ) break;
      isData = ( _strnicmp( p, "DATA ", 5 ) == 0 );
      isMethod = ( _strnicmp( p, "METHOD ", 7 ) == 0 ) ||
                 ( _strnicmp( p, "ACCESS ", 7 ) == 0 );
      if( !isData && !isMethod ) continue;
      if( isData ) p += 5; else p += 7;
      while( *p == ' ' ) p++;
      ni = 0;
      while( ni < 63 && (isalnum((unsigned char)p[ni]) || p[ni] == '_') )
         { name[ni] = p[ni]; ni++; }
      name[ni] = 0;
      if( ni == 0 ) continue;
      if( isMethod && ni < 61 ) { name[ni++] = '('; name[ni++] = ')'; name[ni] = 0; }
      if( pos > 0 && pos < bufSize - 1 ) buf[pos++] = ' ';
      if( ni > bufSize - pos - 1 ) break;
      memcpy( buf + pos, name, (size_t)ni );
      pos += ni;
   }
   buf[pos] = 0;
   return pos;
}

/* Search plain text for CLASS declaration matching cls */
static const char * CE_FindClassInText( const char * text, const char * cls, char * parentCls )
{
   const char * cur = text;
   parentCls[0] = 0;
   while( *cur )
   {
      const char * lineStart = cur;
      const char * lineEnd = cur;
      int lineLen;
      while( *lineEnd && *lineEnd != '\n' ) lineEnd++;
      lineLen = (int)(lineEnd - cur);
      if( lineLen > 0 && lineLen < 510 )
      {
         char line[512];
         const char * p;
         char foundCls[64];
         int fi;
         memcpy( line, cur, (size_t)lineLen );
         line[lineLen] = 0;
         p = line;
         while( *p == ' ' || *p == '\t' ) p++;
         if( _strnicmp( p, "CLASS ", 6 ) == 0 )
         {
            p += 6;
            while( *p == ' ' ) p++;
            fi = 0;
            while( fi < 63 && (isalnum((unsigned char)p[fi]) || p[fi] == '_') )
               { foundCls[fi] = p[fi]; fi++; }
            foundCls[fi] = 0;
            if( _stricmp( foundCls, cls ) == 0 )
            {
               p += fi;
               while( *p == ' ' ) p++;
               if( _strnicmp( p, "INHERIT ", 8 ) == 0 ) p += 8;
               else if( _strnicmp( p, "FROM ", 5 ) == 0 ) p += 5;
               else p = NULL;
               if( p ) {
                  int pi = 0;
                  while( *p == ' ' ) p++;
                  while( pi < 63 && (isalnum((unsigned char)p[pi]) || p[pi] == '_') )
                     { parentCls[pi] = p[pi]; pi++; }
                  parentCls[pi] = 0;
               }
               return lineStart;
            }
         }
      }
      cur = lineEnd;
      if( *cur == '\n' ) cur++;
   }
   return NULL;
}

/* Collect DATA/METHOD from plain text starting after CLASS line */
static int CE_CollectUserDataFromText( const char * text, const char * classLineStart,
                                        char * buf, int bufSize )
{
   int pos = 0;
   const char * cur = classLineStart;
   while( *cur && *cur != '\n' ) cur++;
   if( *cur == '\n' ) cur++;
   while( *cur )
   {
      const char * lineEnd = cur;
      int lineLen;
      while( *lineEnd && *lineEnd != '\n' ) lineEnd++;
      lineLen = (int)(lineEnd - cur);
      if( lineLen > 0 && lineLen < 510 )
      {
         char line[512];
         const char * p;
         int isData, isMethod;
         memcpy( line, cur, (size_t)lineLen );
         line[lineLen] = 0;
         p = line;
         while( *p == ' ' || *p == '\t' || *p == '\r' ) p++;
         if( *p != 0 )
         {
            if( _strnicmp( p, "ENDCLASS", 8 ) == 0 ) break;
            isData = ( _strnicmp( p, "DATA ", 5 ) == 0 );
            isMethod = ( _strnicmp( p, "METHOD ", 7 ) == 0 ) ||
                       ( _strnicmp( p, "ACCESS ", 7 ) == 0 );
            if( isData || isMethod )
            {
               char name[64];
               int ni = 0;
               if( isData ) p += 5; else p += 7;
               while( *p == ' ' ) p++;
               while( ni < 63 && (isalnum((unsigned char)p[ni]) || p[ni] == '_') )
                  { name[ni] = p[ni]; ni++; }
               name[ni] = 0;
               if( isMethod && ni < 61 ) { name[ni++] = '('; name[ni++] = ')'; name[ni] = 0; }
               if( ni > 0 ) {
                  if( pos > 0 && pos < bufSize - 1 ) buf[pos++] = ' ';
                  if( ni > bufSize - pos - 1 ) break;
                  memcpy( buf + pos, name, (size_t)ni );
                  pos += ni;
               }
            }
         }
      }
      cur = lineEnd;
      if( *cur == '\n' ) cur++;
   }
   buf[pos] = 0;
   return pos;
}

/* Find current CLASS name by scanning backwards from line */
static const char * CE_FindCurrentClass( HWND hSci, int fromLine )
{
   static char s_curClass[64];
   int l;
   for( l = fromLine; l >= 0; l-- )
   {
      char buf[512];
      int len = (int) SciMsg( hSci, SCI_LINELENGTH,l, 0 );
      const char * cp;
      int ci;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( hSci, SCI_GETLINE,l, (LPARAM)buf );
      buf[len] = 0;
      cp = buf;
      while( *cp == ' ' || *cp == '\t' ) cp++;
      if( _strnicmp( cp, "CLASS ", 6 ) == 0 ) {
         cp += 6;
         while( *cp == ' ' ) cp++;
         ci = 0;
         while( ci < 63 && (isalnum((unsigned char)cp[ci]) || cp[ci] == '_') )
            { s_curClass[ci] = cp[ci]; ci++; }
         s_curClass[ci] = 0;
         if( ci > 0 ) return s_curClass;
         break;
      }
   }
   return NULL;
}

/* Find class members combining standard + user-defined */
static const char * CE_FindClassMembers( CODEEDITOR * ed, const char * cls )
{
   static char s_combined[4096];
   const char * stdMembers = NULL;
   char userMembers[2048] = "";
   int classLine = -1, i, t;

   for( i = 0; s_classMembers[i].className; i++ )
      if( _stricmp( cls, s_classMembers[i].className ) == 0 )
         { stdMembers = s_classMembers[i].members; break; }

   if( !ed || !ed->hEdit ) goto cm_combine;

   /* If cls is TForm (or similar base), substitute the user's subclass
    * found in any editor tab so its DATAs show in the dropdown. */
   if( _stricmp( cls, "TForm" ) == 0 ) {
      int tl = (int) SciMsg( ed->hEdit, SCI_GETLINECOUNT, 0, 0 );
      int kk, found = 0;
      char userCls[64] = "";
      for( kk = 0; kk < tl && !found; kk++ ) {
         char lb[512];
         int ll = (int) SciMsg( ed->hEdit, SCI_LINELENGTH, kk, 0 );
         const char * lp; char fc[64]; int fi;
         if( ll <= 0 || ll >= (int)sizeof(lb) ) continue;
         SciMsg( ed->hEdit, SCI_GETLINE, kk, (LPARAM)lb );
         lb[ll] = 0;
         lp = lb;
         while( *lp == ' ' || *lp == '\t' ) lp++;
         if( _strnicmp( lp, "CLASS ", 6 ) != 0 ) continue;
         lp += 6; while( *lp == ' ' ) lp++;
         fi = 0;
         while( fi < 63 && (isalnum((unsigned char)lp[fi]) || lp[fi] == '_') )
            { fc[fi] = lp[fi]; fi++; }
         fc[fi] = 0; lp += fi;
         while( *lp == ' ' ) lp++;
         if( _strnicmp( lp, "FROM ", 5 ) == 0 ) lp += 5;
         else if( _strnicmp( lp, "INHERIT ", 8 ) == 0 ) lp += 8;
         else continue;
         while( *lp == ' ' ) lp++;
         if( _strnicmp( lp, "TForm", 5 ) == 0 &&
             (lp[5] == 0 || lp[5] == ' ' || lp[5] == '\r' || lp[5] == '\n') ) {
            lstrcpynA( userCls, fc, 63 );
            found = 1;
         }
      }
      if( !found ) {
         for( t = 0; t < ed->nTabs && !found; t++ ) {
            if( t == ed->nActiveTab || !ed->aTexts[t] || !ed->aTexts[t][0] ) continue;
            /* Scan text line by line for CLASS X FROM TForm */
            { const char * cur = ed->aTexts[t];
              while( *cur && !found ) {
                 const char * le = cur;
                 const char * lp; char fc[64]; int fi;
                 while( *le && *le != '\n' ) le++;
                 lp = cur;
                 while( lp < le && (*lp == ' ' || *lp == '\t') ) lp++;
                 if( (le - lp) >= 6 && _strnicmp( lp, "CLASS ", 6 ) == 0 ) {
                    lp += 6; while( lp < le && *lp == ' ' ) lp++;
                    fi = 0;
                    while( fi < 63 && lp < le &&
                           (isalnum((unsigned char)*lp) || *lp == '_') )
                       { fc[fi++] = *lp++; }
                    fc[fi] = 0;
                    while( lp < le && *lp == ' ' ) lp++;
                    if( (le - lp) >= 5 && _strnicmp( lp, "FROM ", 5 ) == 0 ) lp += 5;
                    else if( (le - lp) >= 8 && _strnicmp( lp, "INHERIT ", 8 ) == 0 ) lp += 8;
                    else { cur = (*le == '\n') ? le + 1 : le; continue; }
                    while( lp < le && *lp == ' ' ) lp++;
                    if( (le - lp) >= 5 && _strnicmp( lp, "TForm", 5 ) == 0 &&
                        (lp + 5 == le || lp[5] == ' ' || lp[5] == '\r') ) {
                       lstrcpynA( userCls, fc, 63 );
                       found = 1;
                       break;
                    }
                 }
                 cur = (*le == '\n') ? le + 1 : le;
              }
            }
         }
      }
      if( found ) cls = userCls;
   }

   /* Search current editor for CLASS definition */
   {
      int totalLines = (int) SciMsg( ed->hEdit, SCI_GETLINECOUNT, 0, 0 );
      for( i = 0; i < totalLines; i++ )
      {
         char buf[512];
         int len = (int) SciMsg( ed->hEdit, SCI_LINELENGTH, i, 0 );
         const char * cp;
         char foundCls[64];
         int fi;
         if( len <= 0 || len >= (int)sizeof(buf) ) continue;
         SciMsg( ed->hEdit, SCI_GETLINE, i, (LPARAM)buf );
         buf[len] = 0;
         cp = buf;
         while( *cp == ' ' || *cp == '\t' ) cp++;
         if( _strnicmp( cp, "CLASS ", 6 ) != 0 ) continue;
         cp += 6;
         while( *cp == ' ' ) cp++;
         fi = 0;
         while( fi < 63 && (isalnum((unsigned char)cp[fi]) || cp[fi] == '_') )
            { foundCls[fi] = cp[fi]; fi++; }
         foundCls[fi] = 0;
         if( _stricmp( foundCls, cls ) == 0 )
         {
            classLine = i;
            cp += fi;
            while( *cp == ' ' ) cp++;
            if( _strnicmp( cp, "INHERIT ", 8 ) == 0 ) cp += 8;
            else if( _strnicmp( cp, "FROM ", 5 ) == 0 ) cp += 5;
            else cp = NULL;
            if( cp && !stdMembers ) {
               char parent[64];
               int pi = 0;
               while( *cp == ' ' ) cp++;
               while( pi < 63 && (isalnum((unsigned char)cp[pi]) || cp[pi] == '_') )
                  { parent[pi] = cp[pi]; pi++; }
               parent[pi] = 0;
               for( i = 0; s_classMembers[i].className; i++ )
                  if( _stricmp( parent, s_classMembers[i].className ) == 0 )
                     { stdMembers = s_classMembers[i].members; break; }
            }
            break;
         }
      }
      if( classLine >= 0 )
         CE_CollectUserData( ed->hEdit, classLine, userMembers, sizeof(userMembers) );
   }

   /* If not found, search other tabs */
   if( classLine < 0 )
   {
      for( t = 0; t < ed->nTabs; t++ )
      {
         char parentCls[64];
         const char * classPos;
         if( t == ed->nActiveTab || !ed->aTexts[t] || !ed->aTexts[t][0] ) continue;
         classPos = CE_FindClassInText( ed->aTexts[t], cls, parentCls );
         if( classPos ) {
            CE_CollectUserDataFromText( ed->aTexts[t], classPos, userMembers, sizeof(userMembers) );
            if( parentCls[0] && !stdMembers ) {
               for( i = 0; s_classMembers[i].className; i++ )
                  if( _stricmp( parentCls, s_classMembers[i].className ) == 0 )
                     { stdMembers = s_classMembers[i].members; break; }
            }
            break;
         }
      }
   }

cm_combine:
   if( stdMembers && userMembers[0] ) {
      _snprintf( s_combined, sizeof(s_combined), "%s %s", stdMembers, userMembers );
      return s_combined;
   }
   if( stdMembers ) return stdMembers;
   if( userMembers[0] ) { lstrcpynA( s_combined, userMembers, sizeof(s_combined) ); return s_combined; }
   return NULL;
}

/* Resolve variable class from context (4 strategies) */
static const char * CE_ResolveVarClass( CODEEDITOR * ed, int colonPos )
{
   static char s_resolved[64];
   int line, lineStart, lineLen;
   char lineBuf[512];
   int end, nameEnd, nameStart, varLen;
   char varName[128];
   int hasDblColon;
   int totalLines, l, i;

   static struct { const char * prefix; const char * cls; } s_nameMap[] = {
      { "Form", "TForm" }, { "Button", "TButton" }, { "Edit", "TEdit" },
      { "Label", "TLabel" }, { "Memo", "TMemo" }, { "CheckBox", "TCheckBox" },
      { "RadioButton", "TRadioButton" }, { "ComboBox", "TComboBox" },
      { "ListBox", "TListBox" }, { "GroupBox", "TGroupBox" }, { "Panel", "TPanel" },
      { "Timer", "TTimer" }, { "ToolBar", "TToolBar" }, { "ProgressBar", "TProgressBar" },
      { "TabControl", "TTabControl" }, { "TreeView", "TTreeView" },
      { "ListView", "TListView" }, { "Image", "TImage" }, { "Database", "TDatabase" },
      { "DBFTable", "TDBFTable" }, { "SQLite", "TSQLite" }, { "Report", "TReport" },
      { "WebServer", "TWebServer" }, { "HttpClient", "THttpClient" },
      { "Thread", "TThread" }, { "App", "TApplication" }, { NULL, NULL }
   };

   if( !ed || !ed->hEdit ) return NULL;

   line = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION, colonPos, 0 );
   lineStart = (int) SciMsg( ed->hEdit, SCI_POSITIONFROMLINE, line, 0 );
   lineLen = colonPos - lineStart;
   if( lineLen <= 0 || lineLen > 500 ) return NULL;

   /* Get text before colon char by char */
   {
      int ci;
      for( ci = 0; ci < lineLen && ci < 511; ci++ )
         lineBuf[ci] = (char) SciMsg( ed->hEdit, 2007, lineStart + ci, 0 );
      lineBuf[ci] = 0;
   }

   end = lineLen - 1;
   while( end >= 0 && lineBuf[end] == ':' ) end--;
   nameEnd = end;
   while( end >= 0 && (isalnum((unsigned char)lineBuf[end]) || lineBuf[end] == '_') ) end--;
   nameStart = end + 1;
   if( nameStart > nameEnd ) return NULL;

   varLen = nameEnd - nameStart + 1;
   if( varLen <= 0 || varLen >= (int)sizeof(varName) ) return NULL;
   memcpy( varName, &lineBuf[nameStart], (size_t)varLen );
   varName[varLen] = 0;

   hasDblColon = ( nameStart >= 2 && lineBuf[nameStart-1] == ':' && lineBuf[nameStart-2] == ':' );

   /* "Self:" */
   if( _stricmp( varName, "Self" ) == 0 )
      return CE_FindCurrentClass( ed->hEdit, line );

   /* Strategy 1: DATA comment — "DATA oName // TClassName" */
   totalLines = (int) SciMsg( ed->hEdit, SCI_GETLINECOUNT, 0, 0 );
   for( l = 0; l < totalLines; l++ )
   {
      char buf[512];
      int len = (int) SciMsg( ed->hEdit, SCI_LINELENGTH, l, 0 );
      const char * dp, * cmt;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( ed->hEdit, SCI_GETLINE, l, (LPARAM)buf );
      buf[len] = 0;
      dp = buf;
      while( *dp == ' ' || *dp == '\t' ) dp++;
      if( _strnicmp( dp, "DATA ", 5 ) != 0 ) continue;
      dp += 5;
      while( *dp == ' ' ) dp++;
      if( _strnicmp( dp, varName, (size_t)varLen ) != 0 ) continue;
      dp += varLen;
      if( isalnum((unsigned char)*dp) || *dp == '_' ) continue;
      cmt = strstr( dp, "//" );
      if( !cmt ) continue;
      cmt += 2;
      while( *cmt == ' ' ) cmt++;
      if( isalpha((unsigned char)*cmt) ) {
         int ri = 0;
         char rawCls[64];
         while( ri < 63 && (isalnum((unsigned char)cmt[ri]) || cmt[ri] == '_') )
            { rawCls[ri] = cmt[ri]; ri++; }
         rawCls[ri] = 0;
         if( rawCls[0] == 'T' && isupper((unsigned char)rawCls[1]) )
            lstrcpynA( s_resolved, rawCls, 63 );
         else
            _snprintf( s_resolved, 64, "T%s", rawCls );
         return s_resolved;
      }
   }

   /* Strategy 2: assignment pattern — "varName := TClassName():New" */
   for( l = 0; l < totalLines; l++ )
   {
      char buf[512];
      int len = (int) SciMsg( ed->hEdit, SCI_LINELENGTH, l, 0 );
      const char * vp;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( ed->hEdit, SCI_GETLINE, l, (LPARAM)buf );
      buf[len] = 0;
      vp = strstr( buf, varName );
      if( !vp ) continue;
      vp += varLen;
      while( *vp == ' ' ) vp++;
      if( *vp != ':' || vp[1] != '=' ) continue;
      vp += 2;
      while( *vp == ' ' ) vp++;
      if( *vp == 'T' && isalpha((unsigned char)vp[1]) ) {
         int ci = 0, slen;
         while( ci < 63 && (isalnum((unsigned char)vp[ci]) || vp[ci] == '_') )
            { s_resolved[ci] = vp[ci]; ci++; }
         s_resolved[ci] = 0;
         slen = (int)strlen( s_resolved );
         if( slen > 2 && s_resolved[slen-1] == ')' && s_resolved[slen-2] == '(' )
            s_resolved[slen-2] = 0;
         return s_resolved;
      }
   }

   /* Strategy 3: :: prefix → current class */
   if( hasDblColon )
      return CE_FindCurrentClass( ed->hEdit, line );

   /* Strategy 4: naming convention — oForm→TForm, oButton→TButton */
   {
      const char * base = varName;
      if( (base[0] == 'o' || base[0] == 'O') && isupper((unsigned char)base[1]) )
         base++;
      for( i = 0; s_nameMap[i].prefix; i++ ) {
         int plen = (int)strlen( s_nameMap[i].prefix );
         if( _strnicmp( base, s_nameMap[i].prefix, (size_t)plen ) == 0 ) {
            char next = base[plen];
            if( next == 0 || isdigit((unsigned char)next) || isupper((unsigned char)next) || next == '_' ) {
               /* Special-case oForm: prefer the user form class (e.g. Form1)
                * so DATAs declared in that CLASS appear in the dropdown. */
               if( _stricmp( s_nameMap[i].cls, "TForm" ) == 0 ) {
                  /* Scan active tab lines */
                  int tl = (int) SciMsg( ed->hEdit, SCI_GETLINECOUNT, 0, 0 );
                  int k;
                  for( k = 0; k < tl; k++ ) {
                     char lb[512];
                     int ll = (int) SciMsg( ed->hEdit, SCI_LINELENGTH, k, 0 );
                     const char * lp;
                     char fc[64]; int fi;
                     if( ll <= 0 || ll >= (int)sizeof(lb) ) continue;
                     SciMsg( ed->hEdit, SCI_GETLINE, k, (LPARAM)lb );
                     lb[ll] = 0;
                     lp = lb;
                     while( *lp == ' ' || *lp == '\t' ) lp++;
                     if( _strnicmp( lp, "CLASS ", 6 ) != 0 ) continue;
                     lp += 6;
                     while( *lp == ' ' ) lp++;
                     fi = 0;
                     while( fi < 63 && (isalnum((unsigned char)lp[fi]) || lp[fi] == '_') )
                        { fc[fi] = lp[fi]; fi++; }
                     fc[fi] = 0;
                     lp += fi;
                     while( *lp == ' ' ) lp++;
                     if( _strnicmp( lp, "FROM ", 5 ) == 0 ) lp += 5;
                     else if( _strnicmp( lp, "INHERIT ", 8 ) == 0 ) lp += 8;
                     else continue;
                     while( *lp == ' ' ) lp++;
                     if( _strnicmp( lp, "TForm", 5 ) == 0 &&
                         (lp[5] == 0 || lp[5] == ' ' || lp[5] == '\r' || lp[5] == '\n') ) {
                        lstrcpynA( s_resolved, fc, 63 );
                        return s_resolved;
                     }
                  }
               }
               lstrcpynA( s_resolved, s_nameMap[i].cls, 63 );
               return s_resolved;
            }
         }
      }
   }

   return NULL;
}

/* ======================================================================
 * Auto-completion - uses Scintilla's built-in autocomplete
 * ====================================================================== */

#define SCI_AUTOCSHOW    2100
#define SCI_AUTOCCANCEL  2101
#define SCI_AUTOCACTIVE  2102
#define SCI_AUTOCSETSEPARATOR 2106
#define SCI_AUTOCSETIGNORECASE 2115

/* All Harbour keywords + functions for auto-complete (space-separated) */
static const char * s_acList =
   "AAdd AClone ADel AEval AFill AIns ASize AScan ASort "
   "Abs AllTrim Array Asc At "
   "begin break "
   "CToD Chr class "
   "DToC Date data default do "
   "Empty Eval "
   "FClose FOpen FRead FWrite File "
   "GetEnv "
   "HB_ATokens HB_CRC32 HB_DirCreate HB_FNameDir HB_Random HB_StrToUTF8 HB_UTF8ToStr HB_ValToStr "
   "Iif If Int "
   "LTrim Len Lower "
   "Max MemoRead MemoWrit Min MsgInfo MsgStop MsgYesNo "
   "RTrim RAt Replicate Round "
   "Space Str StrTran SubStr "
   "Time Type "
   "Upper "
   "Val ValType "
   "access assign "
   "case class "
   "else elseif end endcase endclass enddo endif endswitch exit "
   "for function "
   "if in inherit inline "
   "local loop "
   "method "
   "next nil not "
   "or otherwise "
   "private procedure public "
   "recover request return "
   "self sequence static step super switch "
   "to try "
   "while with";

static void CE_ShowAutoComplete( CODEEDITOR * ed )
{
   int nPos, nStart;
   char wordBuf[64] = {0};

   if( !ed || !ed->hEdit ) return;

   nPos = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
   nStart = nPos;

   /* Scan backward for word start */
   while( nStart > 0 ) {
      int ch = (int) SciMsg( ed->hEdit, 2007, nStart - 1, 0 ); /* SCI_GETCHARAT */
      if( (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
          (ch >= '0' && ch <= '9') || ch == '_' )
         nStart--;
      else
         break;
   }

   if( nPos - nStart >= 2 ) {
      SciMsg( ed->hEdit, SCI_AUTOCSETIGNORECASE, 1, 0 );
      SciMsg( ed->hEdit, SCI_AUTOCSETSEPARATOR, ' ', 0 );
      SciMsg( ed->hEdit, SCI_AUTOCSHOW, nPos - nStart, (LPARAM) s_acList );
   }
}

/* Show/hide the find bar */
static void CE_ShowFindBar( CODEEDITOR * ed, BOOL bShow, BOOL bReplace )
{
   int barH = bReplace ? 56 : 28;
   RECT rc;
   HFONT hFont = (HFONT) GetStockObject(DEFAULT_GUI_FONT);

   if( !ed || !ed->hWnd ) return;
   GetClientRect( ed->hWnd, &rc );
   ed->bFindVisible = bShow;
   ed->bReplaceVisible = bReplace;

   if( bShow && !ed->hFindBar ) {
      /* Create find bar at bottom of editor */
      ed->hFindBar = CreateWindowExA(0,"STATIC",NULL,
         WS_CHILD|WS_VISIBLE,
         0, rc.bottom-barH, rc.right, barH,
         ed->hWnd, NULL, GetModuleHandle(NULL), NULL);

      /* Search input */
      ed->hFindEdit = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT","",
         WS_CHILD|WS_VISIBLE|ES_AUTOHSCROLL,
         70, 2, 200, 22, ed->hFindBar, (HMENU)900, GetModuleHandle(NULL), NULL);
      SendMessage(ed->hFindEdit, WM_SETFONT, (WPARAM)hFont, TRUE);

      { HWND h;
        h = CreateWindowExA(0,"STATIC","Find:",WS_CHILD|WS_VISIBLE,
           8,5,55,18,ed->hFindBar,NULL,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        h = CreateWindowExA(0,"BUTTON","Next",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
           278,2,50,22,ed->hFindBar,(HMENU)901,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        h = CreateWindowExA(0,"BUTTON","Prev",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
           332,2,50,22,ed->hFindBar,(HMENU)902,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        h = CreateWindowExA(0,"BUTTON","X",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
           rc.right-32,2,26,22,ed->hFindBar,(HMENU)903,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        ed->hFindLabel = CreateWindowExA(0,"STATIC","",WS_CHILD|WS_VISIBLE,
           390,5,120,18,ed->hFindBar,NULL,GetModuleHandle(NULL),NULL);
        SendMessage(ed->hFindLabel,WM_SETFONT,(WPARAM)hFont,TRUE);
      }

      if( bReplace ) {
         HWND h;
         ed->hReplaceEdit = CreateWindowExA(WS_EX_CLIENTEDGE,"EDIT","",
            WS_CHILD|WS_VISIBLE|ES_AUTOHSCROLL,
            70,28,200,22,ed->hFindBar,(HMENU)904,GetModuleHandle(NULL),NULL);
         SendMessage(ed->hReplaceEdit,WM_SETFONT,(WPARAM)hFont,TRUE);
         h = CreateWindowExA(0,"STATIC","Replace:",WS_CHILD|WS_VISIBLE,
            8,31,60,18,ed->hFindBar,NULL,GetModuleHandle(NULL),NULL);
         SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
         h = CreateWindowExA(0,"BUTTON","Replace",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
            278,28,60,22,ed->hFindBar,(HMENU)905,GetModuleHandle(NULL),NULL);
         SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
         h = CreateWindowExA(0,"BUTTON","All",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
            342,28,40,22,ed->hFindBar,(HMENU)906,GetModuleHandle(NULL),NULL);
         SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);
      }

      /* Resize Scintilla editor to make room */
      MoveWindow(ed->hEdit, 0, TAB_HEIGHT,
         rc.right, rc.bottom-TAB_HEIGHT-barH-STATUSBAR_HEIGHT, TRUE);

      SetFocus( ed->hFindEdit );
   }
   else if( !bShow && ed->hFindBar ) {
      DestroyWindow( ed->hFindBar );
      ed->hFindBar = NULL; ed->hFindEdit = NULL; ed->hFindLabel = NULL; ed->hReplaceEdit = NULL;

      GetClientRect( ed->hWnd, &rc );
      MoveWindow(ed->hEdit, 0, TAB_HEIGHT,
         rc.right, rc.bottom-TAB_HEIGHT-STATUSBAR_HEIGHT, TRUE);

      SetFocus( ed->hEdit );
   }
}

/* Find text in Scintilla */
static void CE_FindNext( CODEEDITOR * ed, BOOL bForward )
{
   char szFind[256];
   int nPos, nCount = 0, nLen, nFindLen;
   int nCurPos;

   if( !ed || !ed->hEdit || !ed->hFindEdit ) return;

   GetWindowTextA( ed->hFindEdit, szFind, sizeof(szFind) );
   if( !szFind[0] ) return;

   nLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
   nFindLen = lstrlenA( szFind );
   nCurPos = (int) SciMsg( ed->hEdit, bForward ? SCI_GETSELECTIONEND : SCI_GETSELECTIONSTART, 0, 0 );

   /* Search forward or backward */
   if( bForward ) {
      SciMsg( ed->hEdit, SCI_SETTARGETSTART, nCurPos, 0 );
      SciMsg( ed->hEdit, SCI_SETTARGETEND, nLen, 0 );
   } else {
      SciMsg( ed->hEdit, SCI_SETTARGETSTART, nCurPos - 1, 0 );
      SciMsg( ed->hEdit, SCI_SETTARGETEND, 0, 0 );
   }

   nPos = (int) SciMsg( ed->hEdit, SCI_SEARCHINTARGET, nFindLen, (LPARAM) szFind );

   /* Wrap around if not found */
   if( nPos < 0 ) {
      if( bForward ) {
         SciMsg( ed->hEdit, SCI_SETTARGETSTART, 0, 0 );
         SciMsg( ed->hEdit, SCI_SETTARGETEND, nLen, 0 );
      } else {
         SciMsg( ed->hEdit, SCI_SETTARGETSTART, nLen, 0 );
         SciMsg( ed->hEdit, SCI_SETTARGETEND, 0, 0 );
      }
      nPos = (int) SciMsg( ed->hEdit, SCI_SEARCHINTARGET, nFindLen, (LPARAM) szFind );
   }

   if( nPos >= 0 ) {
      SciMsg( ed->hEdit, SCI_SETSEL, nPos, nPos + nFindLen );
      SciMsg( ed->hEdit, SCI_SCROLLCARET, 0, 0 );
   }

   /* Count total matches */
   { int p, s = 0;
     while( s < nLen ) {
        SciMsg( ed->hEdit, SCI_SETTARGETSTART, s, 0 );
        SciMsg( ed->hEdit, SCI_SETTARGETEND, nLen, 0 );
        p = (int) SciMsg( ed->hEdit, SCI_SEARCHINTARGET, nFindLen, (LPARAM) szFind );
        if( p < 0 ) break;
        nCount++;
        s = p + 1;
     }
   }

   if( ed->hFindLabel ) {
      char buf[64];
      sprintf(buf, "%d matches", nCount);
      SetWindowTextA(ed->hFindLabel, buf);
   }
}

/* Scintilla parent WndProc handles keyboard shortcuts via WM_COMMAND/WM_NOTIFY
   Scintilla manages its own WndProc - no subclass needed */

/* Scintilla notification codes */
#define SCN_CHARADDED     2001
#define SCN_UPDATEUI      2007
#define SCN_MODIFIED      2008
#define SCN_MARGINCLICK   2010
#define SCI_TOGGLEFOLD    2231
#define SCI_GETCOLUMN     2129
#define SCI_GETOVERTYPE   2187

/* NMHDR-compatible Scintilla notification header */
typedef struct {
   HWND hwndFrom;
   unsigned int idFrom;
   unsigned int code;
   int position;
   int ch;
   int modifiers;
   int modificationType;
   const char * text;
   int length;
   int linesAdded;
   int message;
   uintptr_t wParam;
   intptr_t lParam;
   int line;
   int foldLevelNow;
   int foldLevelPrev;
   int margin;
   int listType;
   int x;
   int y;
   int token;
   int annotationLinesAdded;
   int updated;
   int listCompletionMethod;
   int characterSource;
} SCNotification;

/* Update status bar: Ln X, Col Y | INS/OVR | lines | chars */
static void UpdateStatusBar( CODEEDITOR * ed )
{
   int pos, line, col, lineCount, nLen, ovr;
   char szStatus[256];

   if( !ed || !ed->hEdit || !ed->hStatusBar ) return;

   pos = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
   line = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION, pos, 0 );
   col = (int) SciMsg( ed->hEdit, SCI_GETCOLUMN, pos, 0 );
   lineCount = (int) SciMsg( ed->hEdit, SCI_GETLINECOUNT, 0, 0 );
   nLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
   ovr = (int) SciMsg( ed->hEdit, SCI_GETOVERTYPE, 0, 0 );

   sprintf( szStatus, "  Ln %d, Col %d      %s      %d lines      %d chars      UTF-8",
      line + 1, col + 1,
      ovr ? "OVR" : "INS",
      lineCount, nLen );

   SetWindowTextA( ed->hStatusBar, szStatus );
}

/* Subclass for editor tab: conditional dark background */
extern int g_bDarkIDE;
static WNDPROC s_oldEdTabProc = NULL;
static LRESULT CALLBACK EdTabSubProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   if( msg == WM_ERASEBKGND && g_bDarkIDE )
   {
      HDC hdc = (HDC) wParam;
      RECT rc;
      HBRUSH hbr = CreateSolidBrush( RGB(30,30,30) );
      GetClientRect( hWnd, &rc );
      FillRect( hdc, &rc, hbr );
      DeleteObject( hbr );
      return 1;
   }
   return CallWindowProc( s_oldEdTabProc, hWnd, msg, wParam, lParam );
}

static LRESULT CALLBACK CodeEdWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   CODEEDITOR * ed = (CODEEDITOR *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   switch( msg )
   {
      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         if( ed )
         {
            if( ed->hTab )
               MoveWindow( ed->hTab, 0, 0, w, TAB_HEIGHT, TRUE );
            if( ed->hStatusBar )
               MoveWindow( ed->hStatusBar, 0, h - STATUSBAR_HEIGHT, w, STATUSBAR_HEIGHT, TRUE );
            if( ed->hEdit )
               MoveWindow( ed->hEdit, 0, TAB_HEIGHT, w,
                  h - TAB_HEIGHT - (ed->hStatusBar ? STATUSBAR_HEIGHT : 0), TRUE );
         }
         return 0;
      }

      case WM_DRAWITEM:
      {
         DRAWITEMSTRUCT * di = (DRAWITEMSTRUCT *) lParam;
         if( di && di->CtlType == ODT_TAB && ed && di->hwndItem == ed->hTab )
         {
            char txt[128] = "";
            TCITEMA tci2 = {0};
            HBRUSH hbr;
            int isSel = ( TabCtrl_GetCurSel( di->hwndItem ) == (int)di->itemID );
            tci2.mask = TCIF_TEXT;
            tci2.pszText = txt;
            tci2.cchTextMax = sizeof(txt);
            SendMessageA( di->hwndItem, TCM_GETITEMA, di->itemID, (LPARAM)&tci2 );

            if( g_bDarkIDE ) {
               hbr = CreateSolidBrush( isSel ? RGB(50,50,50) : RGB(30,30,30) );
               SetTextColor( di->hDC, isSel ? RGB(255,255,255) : RGB(140,140,140) );
            } else {
               hbr = CreateSolidBrush( isSel ? GetSysColor(COLOR_WINDOW) : GetSysColor(COLOR_BTNFACE) );
               SetTextColor( di->hDC, GetSysColor(COLOR_BTNTEXT) );
            }
            FillRect( di->hDC, &di->rcItem, hbr );
            DeleteObject( hbr );
            SetBkMode( di->hDC, TRANSPARENT );
            DrawTextA( di->hDC, txt, -1, &di->rcItem, DT_CENTER | DT_VCENTER | DT_SINGLELINE );
            return TRUE;
         }
         break;
      }

      case WM_NOTIFY:
      {
         NMHDR * pnm = (NMHDR *) lParam;

         /* Tab change */
         if( ed && pnm->hwndFrom == ed->hTab && pnm->code == TCN_SELCHANGE )
         {
            int nSel = (int) SendMessage( ed->hTab, TCM_GETCURSEL, 0, 0 );
            if( nSel >= 0 && nSel < ed->nTabs && nSel != ed->nActiveTab )
               SwitchTab( ed, nSel );
         }

         /* Scintilla notifications */
         if( ed && pnm->hwndFrom == ed->hEdit )
         {
            SCNotification * scn = (SCNotification *) lParam;

            if( scn->code == SCN_MARGINCLICK ) {
               /* Fold/unfold on margin click */
               int line = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION, scn->position, 0 );
               SciMsg( ed->hEdit, SCI_TOGGLEFOLD, line, 0 );
            }

            if( scn->code == SCN_CHARADDED ) {
               /* Auto-indent on Enter */
               if( scn->ch == '\n' || scn->ch == '\r' ) {
                  int curLine = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION,
                     SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 ), 0 );
                  if( curLine > 0 ) {
                     int prevLine = curLine - 1;
                     int indent, pos;
                     indent = (int) SciMsg( ed->hEdit, 2127, prevLine, 0 ); /* SCI_GETLINEINDENTATION */
                     SciMsg( ed->hEdit, 2126, curLine, indent ); /* SCI_SETLINEINDENTATION */
                     pos = (int) SciMsg( ed->hEdit, 2128, curLine, 0 ); /* SCI_GETLINEINDENTPOSITION */
                     SciMsg( ed->hEdit, SCI_GOTOPOS, pos, 0 );
                  }
               }
               /* ':' typed — show class member dropdown */
               else if( scn->ch == ':' )
               {
                  int pos = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
                  const char * cls = CE_ResolveVarClass( ed, pos - 1 );
                  if( cls )
                  {
                     const char * members = CE_FindClassMembers( ed, cls );
                     if( members )
                     {
                        SciMsg( ed->hEdit, SCI_AUTOCSETIGNORECASE, 1, 0 );
                        SciMsg( ed->hEdit, SCI_AUTOCSETSEPARATOR, ' ', 0 );
                        SciMsg( ed->hEdit, 2660, 1, 0 );  /* SCI_AUTOCSETORDER = SC_ORDER_PERFORMSORT */
                        SciMsg( ed->hEdit, SCI_AUTOCSHOW, 0, (LPARAM) members );
                     }
                  }
               }
            }

            /* Update status bar on cursor/selection change */
            if( scn->code == SCN_UPDATEUI ) {
               UpdateStatusBar( ed );
            }

            /* Update Harbour folding when text is inserted/deleted (not fold changes) */
            if( scn->code == SCN_MODIFIED ) {
               if( scn->modificationType & (0x01|0x02) ) {  /* SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT */
                  /* Only update folding on actual text insert/delete with line changes */
                  if( scn->linesAdded != 0 ) {
                     static int s_inFoldUpdate = 0;
                     if( !s_inFoldUpdate ) {
                        s_inFoldUpdate = 1;
                        UpdateHarbourFolding( ed->hEdit );
                        s_inFoldUpdate = 0;
                     }
                  }
                  /* Schedule debounced text-change callback (500ms) */
                  if( ed->pOnTextChange && !ed->bSettingText && ed->hWnd )
                  {
                     if( ed->debounceTimer )
                        KillTimer( ed->hWnd, ed->debounceTimer );
                     ed->debounceTimer = SetTimer( ed->hWnd, 7701, 500, NULL );
                  }
               }
               UpdateStatusBar( ed );
            }
         }
         break;
      }

      case WM_COMMAND:
         if( ed ) {
            WORD id = LOWORD(wParam);
            if( id == 901 ) CE_FindNext(ed, TRUE);
            if( id == 902 ) CE_FindNext(ed, FALSE);
            if( id == 903 ) CE_ShowFindBar(ed, FALSE, FALSE);
         }
         break;

      case WM_TIMER:
         if( ed && wParam == 7701 )
         {
            /* If autocomplete dropdown is active, defer the sync so typing ':'
             * or selecting a member doesn't close the popup. */
            if( ed->hEdit && SciMsg( ed->hEdit, 2102, 0, 0 ) )  /* SCI_AUTOCACTIVE */
            {
               ed->debounceTimer = SetTimer( hWnd, 7701, 300, NULL );
               return 0;
            }

            KillTimer( hWnd, 7701 );
            ed->debounceTimer = 0;

            if( ed->pOnTextChange && HB_IS_BLOCK( ed->pOnTextChange ) && ed->hEdit )
            {
               int savedPos   = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
               int savedFirst = (int) SciMsg( ed->hEdit, SCI_GETFIRSTVISIBLELINE, 0, 0 );
               int newLen;
               PHB_ITEM pEd, pTab;

               ed->bSettingText = 1;

               pEd  = hb_itemPutNInt( NULL, (HB_PTRUINT) ed );
               pTab = hb_itemPutNI( NULL, ed->nActiveTab + 1 );
               hb_evalBlock( ed->pOnTextChange, pEd, pTab, NULL );
               hb_itemRelease( pEd );
               hb_itemRelease( pTab );

               ed->bSettingText = 0;

               /* Restore cursor and scroll position */
               newLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
               if( savedPos > newLen ) savedPos = newLen;
               SciMsg( ed->hEdit, SCI_GOTOPOS, savedPos, 0 );
               SciMsg( ed->hEdit, SCI_SETFIRSTVISIBLELINE, savedFirst, 0 );
               SetFocus( ed->hEdit );
            }
            return 0;
         }
         break;

      /* Forward keyboard shortcuts from parent to Scintilla actions */
      case WM_KEYDOWN:
         if( ed && ed->hEdit ) {
            BOOL ctrl = GetKeyState(VK_CONTROL) & 0x8000;
            BOOL shift = GetKeyState(VK_SHIFT) & 0x8000;

            if( ctrl && wParam == 'F' ) {
               CE_ShowFindBar(ed, !ed->bFindVisible, FALSE);
               return 0;
            }
            if( ctrl && wParam == 'H' ) {
               CE_ShowFindBar(ed, TRUE, TRUE);
               return 0;
            }
            if( wParam == VK_ESCAPE && ed->bFindVisible ) {
               CE_ShowFindBar(ed, FALSE, FALSE);
               return 0;
            }
            if( wParam == VK_F3 ) {
               CE_FindNext(ed, !shift);
               return 0;
            }
            if( ctrl && wParam == VK_SPACE ) {
               CE_ShowAutoComplete(ed);
               return 0;
            }
            if( ctrl && wParam == 'G' ) {
               /* Go to beginning for now */
               SciMsg( ed->hEdit, SCI_GOTOPOS, 0, 0 );
               return 0;
            }
            if( ctrl && wParam == VK_OEM_2 ) {
               /* Toggle line comment */
               int pos = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
               int line = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION, pos, 0 );
               int lineStart = (int) SciMsg( ed->hEdit, SCI_POSITIONFROMLINE, line, 0 );
               int lineLen = (int) SciMsg( ed->hEdit, SCI_LINELENGTH, line, 0 );
               if( lineLen > 0 && lineLen < 1000 ) {
                  char * lineBuf = (char *) malloc( lineLen + 1 );
                  SciMsg( ed->hEdit, SCI_GETLINE, line, (LPARAM) lineBuf );
                  lineBuf[lineLen] = 0;
                  if( lineBuf[0] == '/' && lineBuf[1] == '/' ) {
                     int rmLen = (lineLen > 2 && lineBuf[2] == ' ') ? 3 : 2;
                     SciMsg( ed->hEdit, SCI_SETSEL, lineStart, lineStart + rmLen );
                     SciMsg( ed->hEdit, SCI_REPLACESEL, 0, (LPARAM) "" );
                  } else {
                     SciMsg( ed->hEdit, SCI_SETSEL, lineStart, lineStart );
                     SciMsg( ed->hEdit, SCI_REPLACESEL, 0, (LPARAM) "// " );
                  }
                  free( lineBuf );
               }
               return 0;
            }
            if( ctrl && shift && wParam == 'D' ) {
               /* Duplicate line */
               SciMsg( ed->hEdit, 2469, 0, 0 ); /* SCI_LINEDUPLICATE */
               return 0;
            }
            if( ctrl && shift && wParam == 'K' ) {
               /* Delete line */
               SciMsg( ed->hEdit, 2338, 0, 0 ); /* SCI_LINEDELETE */
               return 0;
            }
            if( ctrl && wParam == 'L' && !shift ) {
               /* Select line */
               int pos2 = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
               int ln2 = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION, pos2, 0 );
               int ls2 = (int) SciMsg( ed->hEdit, SCI_POSITIONFROMLINE, ln2, 0 );
               int le2 = (int) SciMsg( ed->hEdit, SCI_POSITIONFROMLINE, ln2 + 1, 0 );
               if( le2 <= ls2 ) le2 = ls2 + (int)SciMsg( ed->hEdit, SCI_LINELENGTH, ln2, 0 );
               SciMsg( ed->hEdit, SCI_SETSEL, ls2, le2 );
               return 0;
            }
         }
         break;

      /* Status bar background (dark/light) */
      case WM_CTLCOLORSTATIC:
         if( ed && ed->hStatusBar && (HWND) lParam == ed->hStatusBar && g_bDarkIDE )
         {
            static HBRUSH s_hSbBrush = NULL;
            HDC hdc = (HDC) wParam;
            SetTextColor( hdc, RGB(180,180,180) );
            SetBkColor( hdc, RGB(37,37,38) );
            if( s_hSbBrush ) DeleteObject( s_hSbBrush );
            s_hSbBrush = CreateSolidBrush( RGB(37,37,38) );
            return (LRESULT) s_hSbBrush;
         }
         break;

      case WM_CLOSE:
         ShowWindow( hWnd, SW_HIDE );
         return 0;
   }

   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* CodeEditorCreate( nLeft, nTop, nWidth, nHeight ) --> hEditor */
HB_FUNC( CODEEDITORCREATE )
{
   CODEEDITOR * ed;
   WNDCLASSA wc = {0};
   static BOOL bReg = FALSE;
   TCITEMA tci;
   int nLeft = hb_parni(1), nTop = hb_parni(2);
   int nWidth = hb_parni(3), nHeight = hb_parni(4);
   FILE * fLog;

   fLog = fopen( "c:\\HarbourBuilder\\scintilla_trace.log", "a" );
   if( fLog ) fprintf( fLog, "CodeEditorCreate: %d,%d %dx%d\n", nLeft, nTop, nWidth, nHeight );

   /* Load Scintilla + Lexilla DLLs */
   if( !InitScintilla() ) {
      if( fLog ) { fprintf( fLog, "FATAL: Cannot load Scintilla DLLs!\n" ); fclose( fLog ); }
      MessageBoxA( NULL, "Cannot load Scintilla.dll / Lexilla.dll\nCheck resources/ folder.",
         "HbBuilder Error", MB_OK | MB_ICONERROR );
      hb_retnint( 0 );
      return;
   }

   /* Init common controls for Tab */
   {
      INITCOMMONCONTROLSEX icc = { sizeof(icc), ICC_TAB_CLASSES };
      InitCommonControlsEx( &icc );
   }

   ed = (CODEEDITOR *) malloc( sizeof(CODEEDITOR) );
   memset( ed, 0, sizeof(CODEEDITOR) );

   if( !bReg ) {
      wc.lpfnWndProc = CodeEdWndProc;
      wc.hInstance = GetModuleHandle(NULL);
      wc.hCursor = LoadCursor(NULL, IDC_ARROW);
      wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
      wc.lpszClassName = "HbIdeCodeEditor";
      RegisterClassA( &wc );
      bReg = TRUE;
   }

   ed->hWnd = CreateWindowExA( WS_EX_TOOLWINDOW,
      "HbIdeCodeEditor", "Code Editor",
      WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME,
      nLeft, nTop, nWidth, nHeight,
      NULL, NULL, GetModuleHandle(NULL), NULL );

   SetWindowLongPtr( ed->hWnd, GWLP_USERDATA, (LONG_PTR) ed );

   /* Tab control */
   ed->hTab = CreateWindowExA( 0, WC_TABCONTROLA, NULL,
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS | TCS_OWNERDRAWFIXED,
      0, 0, nWidth, TAB_HEIGHT,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   {
      HFONT hTabFont = (HFONT) GetStockObject( DEFAULT_GUI_FONT );
      SendMessage( ed->hTab, WM_SETFONT, (WPARAM) hTabFont, TRUE );
   }
   s_oldEdTabProc = (WNDPROC) SetWindowLongPtr( ed->hTab, GWLP_WNDPROC, (LONG_PTR) EdTabSubProc );

   /* First tab: "Project1.prg" */
   memset( &tci, 0, sizeof(tci) );
   tci.mask = TCIF_TEXT;
   tci.pszText = "Project1.prg";
   SendMessageA( ed->hTab, TCM_INSERTITEMA, 0, (LPARAM) &tci );
   ed->nTabs = 1;
   ed->nActiveTab = 0;
   ed->aTexts[0] = NULL;

   /* Create Scintilla editor (full width, no separate gutter needed) */
   ed->hEdit = CreateWindowExA( 0, "Scintilla", "",
      WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL,
      0, TAB_HEIGHT, nWidth, nHeight - TAB_HEIGHT,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );

   if( fLog ) fprintf( fLog, "Scintilla hwnd => %p\n", ed->hEdit );

   if( ed->hEdit )
   {
      /* Configure syntax highlighting, colors, margins */
      ConfigureScintilla( ed->hEdit );

      if( fLog ) fprintf( fLog, "Scintilla configured OK\n" );
   }
   else
   {
      if( fLog ) fprintf( fLog, "FAILED to create Scintilla window!\n" );
      MessageBoxA( NULL, "Failed to create Scintilla editor window.",
         "HbBuilder Error", MB_OK | MB_ICONERROR );
   }

   /* Status bar at bottom (position will be corrected by WM_SIZE) */
   ed->hStatusBar = CreateWindowExA( 0, "STATIC",
      "  Ln 1, Col 1      INS      0 lines      0 chars      UTF-8",
      WS_CHILD | WS_VISIBLE | SS_LEFT | SS_CENTERIMAGE,
      0, 0, nWidth, STATUSBAR_HEIGHT,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   {
      HFONT hSbFont = (HFONT) GetStockObject( DEFAULT_GUI_FONT );
      SendMessage( ed->hStatusBar, WM_SETFONT, (WPARAM) hSbFont, TRUE );
   }

   /* Dark title bar for code editor window (conditional) */
   if( g_bDarkIDE )
   {
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         typedef HRESULT (WINAPI *pDwmFn)(HWND,DWORD,LPCVOID,DWORD);
         pDwmFn fn = (pDwmFn) GetProcAddress(hDwm,"DwmSetWindowAttribute");
         if( fn ) { BOOL val = TRUE; fn(ed->hWnd, 20, &val, sizeof(val)); }
         FreeLibrary(hDwm);
      }
   }

   ShowWindow( ed->hWnd, SW_SHOW );

   /* Force layout: send WM_SIZE with current client rect to position all children */
   { RECT rcClient;
     GetClientRect( ed->hWnd, &rcClient );
     SendMessage( ed->hWnd, WM_SIZE, SIZE_RESTORED,
        MAKELPARAM( rcClient.right, rcClient.bottom ) );
   }

   if( fLog ) fclose( fLog );

   hb_retnint( (HB_PTRUINT) ed );
}

/* CodeEditorSetTabText( hEditor, nTab, cText ) - sets text for a tab (1-based) */
HB_FUNC( CODEEDITORSETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;  /* Convert to 0-based */

   if( !ed || nTab < 0 || nTab >= ed->nTabs || !HB_ISCHAR(3) ) return;

   /* Free old text */
   if( ed->aTexts[nTab] )
      free( ed->aTexts[nTab] );

   /* Store new text */
   {
      int nLen = (int) hb_parclen(3);
      ed->aTexts[nTab] = (char *) malloc( nLen + 1 );
      memcpy( ed->aTexts[nTab], hb_parc(3), nLen );
      ed->aTexts[nTab][nLen] = 0;
   }

   /* If this is the active tab, update Scintilla */
   if( nTab == ed->nActiveTab && ed->hEdit )
   {
      int nCurLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
      int nNewLen = (int) hb_parclen(3);
      BOOL bChanged = ( nCurLen != nNewLen );

      if( !bChanged && nCurLen > 0 )
      {
         char * cur = (char *) malloc( nCurLen + 1 );
         SciMsg( ed->hEdit, SCI_GETTEXT, nCurLen + 1, (LPARAM) cur );
         bChanged = ( memcmp( cur, hb_parc(3), nNewLen ) != 0 );
         free( cur );
      }

      if( bChanged )
      {
         ed->bSettingText = 1;
         SciMsg( ed->hEdit, SCI_SETTEXT, 0, (LPARAM) ed->aTexts[nTab] );
         SciMsg( ed->hEdit, SCI_EMPTYUNDOBUFFER, 0, 0 );
         /* Scintilla handles syntax highlighting automatically via lexer */
         UpdateHarbourFolding( ed->hEdit );
         ed->bSettingText = 0;
      }
   }
}

/* CodeEditorGetTabText( hEditor, nTab ) --> cText (1-based) */
HB_FUNC( CODEEDITORGETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;  /* Convert to 0-based */

   if( !ed || nTab < 0 || nTab >= ed->nTabs )
   {
      hb_retc( "" );
      return;
   }

   /* If active tab, read from Scintilla (may have been edited) */
   if( nTab == ed->nActiveTab && ed->hEdit )
   {
      int nLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
      char * buf = (char *) malloc( nLen + 1 );
      SciMsg( ed->hEdit, SCI_GETTEXT, nLen + 1, (LPARAM) buf );
      hb_retclen( buf, nLen );
      free( buf );
   }
   else if( ed->aTexts[nTab] )
   {
      hb_retc( ed->aTexts[nTab] );
   }
   else
   {
      hb_retc( "" );
   }
}

/* CodeEditorAddTab( hEditor, cTitle ) - add a new tab */
HB_FUNC( CODEEDITORADDTAB )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   TCITEMA tci;

   if( !ed || ed->nTabs >= MAX_TABS || !HB_ISCHAR(2) ) return;

   memset( &tci, 0, sizeof(tci) );
   tci.mask = TCIF_TEXT;
   tci.pszText = (char *) hb_parc(2);
   SendMessageA( ed->hTab, TCM_INSERTITEMA, ed->nTabs, (LPARAM) &tci );

   ed->aTexts[ed->nTabs] = NULL;
   ed->nTabs++;
}

/* CodeEditorSelectTab( hEditor, nTab ) - switch to tab (1-based) */
HB_FUNC( CODEEDITORSELECTTAB )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;  /* Convert to 0-based */

   if( !ed || nTab < 0 || nTab >= ed->nTabs ) return;

   if( nTab != ed->nActiveTab )
      SwitchTab( ed, nTab );
   else
      SendMessage( ed->hTab, TCM_SETCURSEL, nTab, 0 );
}

/* CodeEditorClearTabs( hEditor ) - remove all tabs and add "Project1.prg" */
HB_FUNC( CODEEDITORCLEARTABS )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   TCITEMA tci;
   int i;

   if( !ed ) return;

   /* Free all text buffers */
   for( i = 0; i < ed->nTabs; i++ )
   {
      if( ed->aTexts[i] ) { free( ed->aTexts[i] ); ed->aTexts[i] = NULL; }
   }

   /* Remove all tabs */
   SendMessage( ed->hTab, TCM_DELETEALLITEMS, 0, 0 );

   /* Re-add first tab */
   memset( &tci, 0, sizeof(tci) );
   tci.mask = TCIF_TEXT;
   tci.pszText = "Project1.prg";
   SendMessageA( ed->hTab, TCM_INSERTITEMA, 0, (LPARAM) &tci );
   ed->nTabs = 1;
   ed->nActiveTab = 0;

   ed->bSettingText = 1;
   SciMsg( ed->hEdit, SCI_SETTEXT, 0, (LPARAM) "" );
   ed->bSettingText = 0;
}

/* CodeEditorOnTabChange( hEditor, bBlock ) - set tab change callback */
HB_FUNC( CODEEDITORONTABCHANGE )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param( 2, HB_IT_BLOCK );

   if( !ed ) return;

   if( ed->pOnTabChange )
      hb_itemRelease( ed->pOnTabChange );

   ed->pOnTabChange = pBlock ? hb_itemNew( pBlock ) : NULL;
}

/* CodeEditorOnTextChange( hEditor, bBlock )
 * Register a debounced callback fired 500ms after the user stops typing.
 * Block receives ( hEditor, nTab ) where nTab is 1-based. */
HB_FUNC( CODEEDITORONTEXTCHANGE )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param( 2, HB_IT_BLOCK );

   if( !ed ) return;

   if( ed->pOnTextChange )
      hb_itemRelease( ed->pOnTextChange );

   ed->pOnTextChange = pBlock ? hb_itemNew( pBlock ) : NULL;
}

/* CodeEditorBringToFront( hEditor ) */
HB_FUNC( CODEEDITORBRINGTOFRONT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hWnd )
   {
      ShowWindow( ed->hWnd, SW_SHOW );
      /* Force to front: TOPMOST then NOTOPMOST trick */
      SetWindowPos( ed->hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE );
      SetWindowPos( ed->hWnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE );
      SetForegroundWindow( ed->hWnd );
   }
}

/* CodeEditorAppendText( hEditor, cText, nCursorOfs ) - append text at end */
HB_FUNC( CODEEDITORAPPENDTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);

   if( !ed || !ed->hEdit || !HB_ISCHAR(2) ) return;

   {
      int nLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
      int nAppend = (int) hb_parclen(2);

      /* Append at end */
      SciMsg( ed->hEdit, SCI_GOTOPOS, nLen, 0 );
      SciMsg( ed->hEdit, SCI_ADDTEXT, nAppend, (LPARAM) hb_parc(2) );

      /* Set cursor position */
      if( HB_ISNUM(3) )
      {
         int nOfs = nLen + hb_parni(3);
         SciMsg( ed->hEdit, SCI_GOTOPOS, nOfs, 0 );
         SciMsg( ed->hEdit, SCI_SCROLLCARET, 0, 0 );
      }
   }
}

/* CodeEditorGotoFunction( hEditor, cFuncName ) --> lFound */
HB_FUNC( CODEEDITORGOTOFUNCTION )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   const char * cFunc = hb_parc(2);
   int nLen, nFuncLen;
   char * buf;
   char * pos;
   char szSearch[256];

   if( !ed || !ed->hEdit || !cFunc )
   {
      hb_retl( FALSE );
      return;
   }

   nLen = (int) SciMsg( ed->hEdit, SCI_GETLENGTH, 0, 0 );
   if( nLen <= 0 ) { hb_retl( FALSE ); return; }

   buf = (char *) malloc( nLen + 1 );
   SciMsg( ed->hEdit, SCI_GETTEXT, nLen + 1, (LPARAM) buf );

   sprintf( szSearch, "function %s", cFunc );
   nFuncLen = (int) strlen( szSearch );

   pos = strstr( buf, szSearch );
   if( pos )
   {
      int nOfs = (int)(pos - buf) + nFuncLen;
      SciMsg( ed->hEdit, SCI_GOTOPOS, nOfs, 0 );
      SciMsg( ed->hEdit, SCI_SCROLLCARET, 0, 0 );
      SetFocus( ed->hEdit );
      free( buf );
      hb_retl( TRUE );
      return;
   }

   free( buf );
   hb_retl( FALSE );
}

/* CodeEditorDestroy( hEditor ) */
HB_FUNC( CODEEDITORDESTROY )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   int i;

   if( ed )
   {
      if( ed->pOnTabChange ) hb_itemRelease( ed->pOnTabChange );
      if( ed->pOnTextChange ) hb_itemRelease( ed->pOnTextChange );
      if( ed->debounceTimer && ed->hWnd ) KillTimer( ed->hWnd, ed->debounceTimer );
      for( i = 0; i < ed->nTabs; i++ )
         if( ed->aTexts[i] ) free( ed->aTexts[i] );
      if( ed->hWnd ) DestroyWindow( ed->hWnd );
      free( ed );
   }
}

/* CodeEditorUndo( hEditor ) */
HB_FUNC( CODEEDITORUNDO )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit ) SciMsg( ed->hEdit, 2176, 0, 0 ); /* SCI_UNDO */
}

/* CodeEditorRedo( hEditor ) */
HB_FUNC( CODEEDITORREDO )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit ) SciMsg( ed->hEdit, 2011, 0, 0 ); /* SCI_REDO */
}

/* CodeEditorCut( hEditor ) */
HB_FUNC( CODEEDITORCUT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit ) SciMsg( ed->hEdit, 2177, 0, 0 ); /* SCI_CUT */
}

/* CodeEditorCopy( hEditor ) */
HB_FUNC( CODEEDITORCOPY )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit ) SciMsg( ed->hEdit, 2178, 0, 0 ); /* SCI_COPY */
}

/* CodeEditorPaste( hEditor ) */
HB_FUNC( CODEEDITORPASTE )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit ) SciMsg( ed->hEdit, 2179, 0, 0 ); /* SCI_PASTE */
}

/* CodeEditorFind( hEditor ) - show find bar */
HB_FUNC( CODEEDITORFIND )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_ShowFindBar( ed, TRUE, FALSE );
}

/* CodeEditorReplace( hEditor ) - show find+replace bar */
HB_FUNC( CODEEDITORREPLACE )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_ShowFindBar( ed, TRUE, TRUE );
}

/* CodeEditorFindNext( hEditor ) */
HB_FUNC( CODEEDITORFINDNEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_FindNext( ed, TRUE );
}

/* CodeEditorFindPrev( hEditor ) */
HB_FUNC( CODEEDITORFINDPREV )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_FindNext( ed, FALSE );
}

/* CodeEditorAutoComplete( hEditor ) */
HB_FUNC( CODEEDITORAUTOCOMPLETE )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_ShowAutoComplete( ed );
}

/* CodeEditorShowDebugLine( hEditor, nLine ) — highlight execution line
 * Clears previous marker, sets marker 11 on nLine, scrolls to it.
 * nLine is 1-based (Harbour convention). Pass 0 to clear. */
static int s_dbgPrevLine = -1;

HB_FUNC( CODEEDITORSHOWDEBUGLINE )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   int nLine = hb_parni(2) - 1;  /* convert to 0-based */
   if( !ed || !ed->hEdit ) return;

   /* Delete old marker and add new one (correct Scintilla message IDs) */
   SciMsg( ed->hEdit, 2045, 11, 0 );  /* SCI_MARKERDELETEALL=2045 marker 11 */

   if( nLine >= 0 )
   {
      SciMsg( ed->hEdit, 2043, (WPARAM)nLine, 11 );  /* SCI_MARKERADD=2043 */
      s_dbgPrevLine = nLine;
      /* Scroll via PostMessage (avoids re-entrant crash during debugger) */
      PostMessage( ed->hEdit, 2024, (WPARAM)nLine, 0 );   /* SCI_GOTOLINE */
   }
   else
   {
      s_dbgPrevLine = -1;
   }
}

/* W32_SetWaitCursor( lWait ) — set/restore wait cursor */
static HCURSOR s_hOldCursor = NULL;
static int s_bWaitCursor = 0;
HB_FUNC( W32_SETWAITCURSOR )
{
   if( hb_parl(1) )
   {
      s_hOldCursor = SetCursor( LoadCursor( NULL, IDC_WAIT ) );
      s_bWaitCursor = 1;
   }
   else if( s_bWaitCursor )
   {
      SetCursor( LoadCursor( NULL, IDC_ARROW ) );
      s_bWaitCursor = 0;
   }
}
/* Hook into WM_SETCURSOR to maintain wait cursor */
HB_FUNC( W32_ISWAITCURSOR ) { hb_retl( s_bWaitCursor ); }
HB_FUNC( W32_CLEARWAITCURSOR ) { s_bWaitCursor = 0; }

/* W32_ShowWindow( hWnd, nCmd ) — show/hide a window */
HB_FUNC( W32_SHOWWINDOW )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   if( hWnd ) ShowWindow( hWnd, hb_parni(2) );
}

/* W32_RedrawAll( hWnd ) — force repaint of window + all children */
HB_FUNC( W32_REDRAWALL )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   if( hWnd )
      RedrawWindow( hWnd, NULL, NULL,
         RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_FRAME | RDW_UPDATENOW );
}

/* W32_MenuCheck( hPopup, nPos, lChecked ) — check/uncheck a menu item by 0-based position */
HB_FUNC( W32_MENUCHECK )
{
   HMENU hMenu = (HMENU)(LONG_PTR) hb_parnint(1);
   int nPos = hb_parni(2);
   BOOL bCheck = hb_parl(3);
   if( hMenu )
      CheckMenuItem( hMenu, nPos, MF_BYPOSITION | ( bCheck ? MF_CHECKED : MF_UNCHECKED ) );
}

/* GetSysColor( nIndex ) --> nColor */
HB_FUNC( GETSYSCOLOR )
{
   hb_retnl( (long) GetSysColor( hb_parni(1) ) );
}

/* W32_SetAppDarkMode( lDark ) — enable/disable dark menus+scrollbars (Win10 1903+) */
HB_FUNC( W32_SETAPPDARKMODE )
{
   typedef int (WINAPI *fnSetPreferredAppMode)(int);
   typedef void (WINAPI *fnFlushMenuThemes)(void);
   HMODULE hUx = LoadLibraryA("uxtheme.dll");
   if( hUx ) {
      /* SetPreferredAppMode = ordinal 135: 0=Default, 1=AllowDark, 2=ForceDark, 3=ForceLight */
      fnSetPreferredAppMode fn = (fnSetPreferredAppMode) GetProcAddress(hUx, MAKEINTRESOURCEA(135));
      if( fn ) fn( hb_parl(1) ? 1 : 0 ); /* AllowDark or Default */

      /* FlushMenuThemes = ordinal 136 — forces menus to refresh */
      {
         fnFlushMenuThemes fn2 = (fnFlushMenuThemes) GetProcAddress(hUx, MAKEINTRESOURCEA(136));
         if( fn2 ) fn2();
      }

      FreeLibrary( hUx );
   }
}

/* W32_SetWindowDarkMode( hWnd, lDark ) — dark title bar + menu bar for a specific window */
HB_FUNC( W32_SETWINDOWDARKMODE )
{
   HWND hWnd = (HWND)(LONG_PTR) hb_parnint(1);
   BOOL bDark = hb_parl(2);
   HMODULE hUx, hDwm;

   if( !hWnd ) return;

   /* 1. DwmSetWindowAttribute for dark title bar */
   hDwm = LoadLibraryA("dwmapi.dll");
   if( hDwm ) {
      typedef HRESULT (WINAPI *pDwmFn)(HWND,DWORD,LPCVOID,DWORD);
      pDwmFn fn = (pDwmFn) GetProcAddress(hDwm, "DwmSetWindowAttribute");
      if( fn ) { BOOL val = bDark; fn(hWnd, 20, &val, sizeof(val)); }
      FreeLibrary(hDwm);
   }

   /* 2. AllowDarkModeForWindow (uxtheme ordinal 133) — needed for menu bar */
   hUx = LoadLibraryA("uxtheme.dll");
   if( hUx ) {
      typedef BOOL (WINAPI *fnAllowDarkModeForWindow)(HWND, BOOL);
      typedef void (WINAPI *fnRefresh)(void);
      typedef void (WINAPI *fnFlush)(void);
      fnAllowDarkModeForWindow fn133 = (fnAllowDarkModeForWindow) GetProcAddress(hUx, MAKEINTRESOURCEA(133));
      fnRefresh fn104;
      fnFlush fn136;
      if( fn133 ) fn133(hWnd, bDark);

      /* RefreshImmersiveColorPolicyState (ordinal 104) — apply the policy */
      fn104 = (fnRefresh) GetProcAddress(hUx, MAKEINTRESOURCEA(104));
      if( fn104 ) fn104();

      /* FlushMenuThemes (ordinal 136) — refresh menu visuals */
      fn136 = (fnFlush) GetProcAddress(hUx, MAKEINTRESOURCEA(136));
      if( fn136 ) fn136();

      FreeLibrary(hUx);
   }

   /* 3. Force redraw of non-client area (menu bar) */
   SetWindowPos(hWnd, NULL, 0,0,0,0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
   DrawMenuBar(hWnd);
}

/* W32_ProcessEvents() — pump pending Win32 messages (like GTK_ProcessEvents) */
HB_FUNC( W32_PROCESSEVENTS )
{
   MSG msg;
   while( PeekMessage( &msg, NULL, 0, 0, PM_REMOVE ) )
   {
      TranslateMessage( &msg );
      DispatchMessage( &msg );
   }
}

/* CodeEditorRefreshTheme( hEditor, lDark ) — update editor window theme */
HB_FUNC( CODEEDITORREFRESHTHEME )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   BOOL bDark = hb_parl(2);
   if( !ed || !ed->hWnd ) return;

   /* Title bar */
   {
      HMODULE hDwm = LoadLibraryA("dwmapi.dll");
      if( hDwm ) {
         typedef HRESULT (WINAPI *pDwmFn)(HWND,DWORD,LPCVOID,DWORD);
         pDwmFn fn = (pDwmFn) GetProcAddress(hDwm,"DwmSetWindowAttribute");
         if( fn ) { BOOL val = bDark; fn(ed->hWnd, 20, &val, sizeof(val)); }
         FreeLibrary(hDwm);
      }
   }

   /* Repaint tabs + status bar */
   if( ed->hTab ) InvalidateRect( ed->hTab, NULL, TRUE );
   if( ed->hStatusBar ) InvalidateRect( ed->hStatusBar, NULL, TRUE );
   RedrawWindow( ed->hWnd, NULL, NULL,
      RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_FRAME | RDW_UPDATENOW );
}

/* Stubs for macOS/Linux functions referenced from classes.prg */
HB_FUNC( UI_MEMONEW )        { hb_retnint( 0 ); }
HB_FUNC( MAC_RUNTIMEERRORDIALOG ) { hb_retni( 0 ); }
HB_FUNC( MAC_APPTERMINATE )  { }
HB_FUNC( W32_ERRORDIALOG ) { /* IDE shows errors via its own dialog */ }

#pragma ENDDUMP
