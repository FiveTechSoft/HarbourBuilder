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

#include "../harbour/hbbuilder.ch"

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

function Main()

   local oTB, oTB2, oFile, oEdit, oSearch, oView, oProject, oRun, oFormat, oComp, oTools, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY

   nScreenW := GTK_GetScreenWidth()
   nScreenH := GTK_GetScreenHeight()
   cCurrentFile := ""
   aForms := {}
   nActiveForm := 0

   // C++Builder classic proportions scaled to current screen
   nBarH    := 72                            // toolbar(36) + tabs(24) + margins(12)
   nInsW    := Int( nScreenW * 0.18 )        // ~18% of screen width

   // === Window 1: Main Bar (full screen width) ===
   DEFINE FORM oIDE TITLE "HbBuilder 1.0 - Visual IDE for Harbour" ;
      SIZE nScreenW, nBarH FONT "Sans", 11 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()

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
   MENUSEPARATOR OF oFile
   MENUITEM "Open..."    OF oFile ACTION TBOpen()                   ACCEL "o"
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
   MENUITEM "Debugger"          OF oView ACTION GTK_DebugPanel()

   DEFINE POPUP oProject PROMPT "Project" OF oIDE
   MENUITEM "Add to Project..."    OF oProject ACTION AddToProject()
   MENUITEM "Remove from Project"  OF oProject ACTION RemoveFromProject()
   MENUSEPARATOR OF oProject
   MENUITEM "Options..."           OF oProject ACTION ShowProjectOptions()

   DEFINE POPUP oRun PROMPT "Run" OF oIDE
   MENUITEM "Run"            OF oRun ACTION TBRun()                ACCEL "r"
   MENUITEM "Debug"          OF oRun ACTION TBDebugRun()
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

   // Load toolbar icons (Lazarus IDE icon set)
   UI_ToolBarLoadImages( oTB:hCpp, "../resources/toolbar.bmp" )

   // Row 2: Run & Debug speedbar
   DEFINE TOOLBAR oTB2 OF oIDE
   BUTTON "Run"   OF oTB2 TOOLTIP "Run project (F9)"      ACTION TBRun()
   BUTTON "Debug" OF oTB2 TOOLTIP "Debug (F8)"             ACTION TBDebugRun()
   SEPARATOR OF oTB2
   BUTTON "Step"  OF oTB2 TOOLTIP "Step Into (F7)"         ACTION DebugStepInto()
   BUTTON "Over"  OF oTB2 TOOLTIP "Step Over (F8)"         ACTION DebugStepOver()
   BUTTON "Go"    OF oTB2 TOOLTIP "Continue (F5)"          ACTION IDE_DebugGo()
   BUTTON "Stop"  OF oTB2 TOOLTIP "Stop Debugging"         ACTION IDE_DebugStop()

   UI_ToolBarLoadImages( oTB2:hCpp, "../resources/toolbar_debug.bmp" )

   // Component Palette (icon grid, tabbed, right of splitter)
   CreatePalette()

   // === Window 4: Code Editor ===
   hCodeEditor := CodeEditorCreate( nEditorX, nEditorTop, nEditorW, nEditorH )

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
   oIDE:Destroy()

return nil

static function CreatePalette()

   local oPal, nTab

   DEFINE PALETTE oPal OF oIDE

   // Standard tab (C++Builder)
   nTab := oPal:AddTab( "Standard" )
   oPal:AddComp( nTab, "A",    "Label",       1 )
   oPal:AddComp( nTab, "ab",   "Edit",        2 )
   oPal:AddComp( nTab, "Mem",  "Memo",       24 )
   oPal:AddComp( nTab, "Btn",  "Button",      3 )
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
   oPal:AddComp( nTab, "Tab",  "TabControl",  33 )
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

   local hTarget

   if nSel == 0
      hTarget := oDesignForm:hCpp
   else
      hTarget := UI_GetChild( oDesignForm:hCpp, nSel )
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
   local nW, nH, nFL, nFT, cTitle, nClr
   local nL, nT, nCW, nCH, cText
   local cDatas := "", cCreate := "", cEvents := ""
   local cExistingCode, aEvents, j, cEvName, cEvSuffix, cHandlerName

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
   else
      cTitle := cName
      nFL := 0; nFT := 0; nW := 400; nH := 300
      nClr   := 15790320
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

         cDatas += "   DATA o" + cCtrlName + "   // " + cCtrlClass + e

         nL := UI_GetProp( hCtrl, "nLeft" )
         nT := UI_GetProp( hCtrl, "nTop" )
         nCW := UI_GetProp( hCtrl, "nWidth" )
         nCH := UI_GetProp( hCtrl, "nHeight" )
         cText := UI_GetProp( hCtrl, "cText" )

         do case
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
            case nType == 5
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' COMBOBOX ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 6
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' GROUPBOX ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            otherwise
               cCreate += '   // ::o' + cCtrlName + ' (' + cCtrlClass + ') at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
         endcase

         // Scan for event handlers matching this control
         // Pattern: METHOD ControlName + EventSuffix (e.g. Button1Click)
         aEvents := { "OnClick", "OnChange", "OnDblClick", "OnCreate", ;
                       "OnClose", "OnResize", "OnKeyDown", "OnKeyUp", ;
                       "OnMouseDown", "OnMouseUp", "OnEnter", "OnExit" }
         for j := 1 to Len( aEvents )
            cEvName := aEvents[j]
            cEvSuffix := SubStr( cEvName, 3 )  // "Click", "Change"...
            cHandlerName := cCtrlName + cEvSuffix
            if cHandlerName $ cExistingCode
               cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                  " := { || " + cHandlerName + "( Self ) }" + e
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

static function OnEventDblClick( hCtrl, cEvent )

   local cName, cClass, cHandler, cCode, cDecl, e, cSep, nCursorOfs

   e := Chr(13) + Chr(10)
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
      "StaticText", "LabeledEdit", "TabControl", "TrackBar", ;
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
      "Whisper", "Embeddings" }

   if aCnt == nil; aCnt := Array(120); AFill(aCnt,0); endif
   if nType < 1 .or. nType > Len(aNames) .or. Empty(aNames[nType]); return nil; endif
   aCnt[nType]++
   cName := aNames[nType] + LTrim(Str(aCnt[nType]))

   nCount := UI_GetChildCount( hForm )
   hCtrl  := UI_GetChild( hForm, nCount )
   if hCtrl != 0
      UI_SetProp( hCtrl, "cName", cName )
   endif

   SyncDesignerToCode()
   InspectorRefresh( hCtrl )
   InspectorPopulateCombo( hForm )

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

static function MenuNewForm()

   local nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop

   SaveActiveFormCode()

   if nActiveForm > 0
      aForms[ nActiveForm ][ 2 ]:Close()
   endif

   nInsW := Int( nScreenW * 0.18 )
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

   nInsW := Int( nScreenW * 0.18 )
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

static function TBOpen()

   local cFile, cContent, cDir, aLines, i
   local cFormName, cFormCode, nFormX, nFormY
   local nInsW, nInsTop, nEditorTop, nEditorX, nEditorW, nEditorH

   cFile := GTK_OpenFileDialog( "Open HbBuilder Project", "hbp" )
   if Empty( cFile ); return nil; endif

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

   CodeEditorClearTabs( hCodeEditor )

   nInsW := Int( nScreenW * 0.18 )
   nInsTop := GTK_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 1
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop

   aLines := HB_ATokens( cContent, Chr(10) )

   cFormCode := MemoRead( cDir + "Project1.prg" )
   if ! Empty( cFormCode )
      CodeEditorSetTabText( hCodeEditor, 1, cFormCode )
   endif

   for i := 2 to Len( aLines )
      cFormName := AllTrim( aLines[i] )
      if Empty( cFormName ); loop; endif

      cFormCode := MemoRead( cDir + cFormName + ".prg" )
      if Empty( cFormCode ); loop; endif

      nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 ) + ( Len(aForms) ) * 20
      nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 ) + ( Len(aForms) ) * 20

      CreateDesignForm( nFormX, nFormY )
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

   if Len( aForms ) > 0
      nActiveForm := 1
      oDesignForm := aForms[1][2]
      UI_SetDesignForm( oDesignForm:hCpp )
      CodeEditorSelectTab( hCodeEditor, 2 )
      InspectorRefresh( oDesignForm:hCpp )
      InspectorPopulateCombo( oDesignForm:hCpp )
   endif

   cCurrentFile := cFile

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
   MemoWrit( cCurrentFile, cHbp )

   MemoWrit( cDir + "Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )

   for i := 1 to Len( aForms )
      MemoWrit( cDir + aForms[i][1] + ".prg", aForms[i][3] )
   next

return nil

static function TBRun()

   local cBuildDir, cOutput, cLog, i, lError
   local cHbDir, cHbBin, cHbInc, cHbLib, cProjDir
   local cAllPrg, cCmd

   SaveActiveFormCode()

   cBuildDir := "/tmp/hbbuilder_build"
   cHbDir   := GetEnv( "HOME" ) + "/harbour"
   cHbBin   := cHbDir + "/bin/linux/gcc"
   cHbInc   := cHbDir + "/include"
   cHbLib   := cHbDir + "/lib/linux/gcc"
   cProjDir := GetEnv( "HOME" ) + "/hbcpp"
   cLog     := ""
   lError   := .F.

   GTK_ShellExec( "mkdir -p " + cBuildDir )

   cLog += "[1] Saving project files..." + Chr(10)
   MemoWrit( cBuildDir + "/Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "/" + aForms[i][1] + ".prg", aForms[i][3] )
      cLog += "    " + aForms[i][1] + ".prg" + Chr(10)
   next
   GTK_ShellExec( "cp " + cProjDir + "/harbour/classes.prg " + cBuildDir + "/" )
   GTK_ShellExec( "cp " + cProjDir + "/harbour/hbbuilder.ch " + cBuildDir + "/" )

   cLog += "[2] Building main.prg..." + Chr(10)
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10) + Chr(10)
   cAllPrg += StrTran( MemoRead( cBuildDir + "/Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += MemoRead( cBuildDir + "/" + aForms[i][1] + ".prg" ) + Chr(10)
   next
   MemoWrit( cBuildDir + "/main.prg", cAllPrg )

   if ! lError
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

   if ! lError
      cLog += "[4] Compiling framework..." + Chr(10)
      cCmd := cHbBin + "/harbour " + cBuildDir + "/classes.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/classes.c 2>&1"
      GTK_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   if ! lError
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

   if ! lError
      cLog += "[6] Compiling GTK3 backend..." + Chr(10)
      cCmd := "gcc -c -O2 -I" + cHbInc + ;
              " $(pkg-config --cflags gtk+-3.0)" + ;
              " " + cProjDir + "/backends/gtk3/gtk3_core.c" + ;
              " -o " + cBuildDir + "/gtk3_core.o 2>&1"
      GTK_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   if ! lError
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
              " -lgttrm -lhbpcre" + ;
              " -Wl,--end-group" + ;
              " $(pkg-config --libs gtk+-3.0)" + ;
              " -lm -lpthread -ldl -lrt -lncurses 2>&1"
      cOutput := GTK_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   if lError
      MsgInfo( "Build FAILED:" + Chr(10) + Chr(10) + cLog )
   else
      cLog += Chr(10) + "Build succeeded. Running..." + Chr(10)
      GTK_ShellExec( cBuildDir + "/UserApp 2>/tmp/userapp_debug.log &" )
   endif

return nil

// === Debug Run (executes user code inside the IDE with debug hooks) ===

static function TBDebugRun()

   local cBuildDir, cOutput, cLog, cAllPrg, cCmd, i
   local cHbDir, cHbBin, cHbInc
   local lError := .F.

   SaveActiveFormCode()

   cBuildDir := "/tmp/hbbuilder_debug"
   cHbDir   := GetEnv( "HBDIR" )
   if Empty( cHbDir ); cHbDir := GetEnv( "HOME" ) + "/harbour"; endif
   cHbBin   := cHbDir + "/bin/linux/gcc"
   cHbInc   := cHbDir + "/include"

   GTK_ShellExec( "mkdir -p " + cBuildDir )

   // Open debugger panel
   GTK_DebugPanel()
   GTK_DebugSetStatus( "Compiling..." )

   // Save all project files
   MemoWrit( cBuildDir + "/Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "/" + aForms[i][1] + ".prg", aForms[i][3] )
   next

   // Build single .prg with all code
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10) + Chr(10)
   cAllPrg += StrTran( MemoRead( cBuildDir + "/Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += MemoRead( cBuildDir + "/" + aForms[i][1] + ".prg" ) + Chr(10)
   next
   MemoWrit( cBuildDir + "/debug_main.prg", cAllPrg )

   // Compile to .hrb (portable bytecode) with debug info
   cCmd := cHbBin + "/harbour " + cBuildDir + "/debug_main.prg -gh -b -n -w -q" + ;
           " -I" + cHbInc + " -I" + cBuildDir + ;
           " -o" + cBuildDir + "/debug_main.hrb 2>&1"
   cOutput := GTK_ShellExec( cCmd )

   if "Error" $ cOutput .or. ! File( cBuildDir + "/debug_main.hrb" )
      GTK_DebugSetStatus( "Compile FAILED" )
      MsgInfo( "Debug compile failed:" + Chr(10) + cOutput )
      return nil
   endif

   GTK_DebugSetStatus( "Running (debugger active)..." )

   // Execute .hrb inside IDE VM with debug hooks
   IDE_DebugStart( cBuildDir + "/debug_main.hrb", ;
      { |cModule, nLine| OnDebugPause( cModule, nLine ) } )

   GTK_DebugSetStatus( "Ready" )

return nil

// Called by debug hook when execution pauses at a line
static function OnDebugPause( cModule, nLine )

   local aLocals, aStack, i

   GTK_DebugSetStatus( "Paused at " + cModule + ":" + LTrim(Str(nLine)) )

   // Update Locals tab
   aLocals := IDE_DebugGetLocals( 1 )
   GTK_DebugUpdateLocals( aLocals )

   // Update Call Stack tab (basic: show current position)
   aStack := { { "0", ProcName(2), cModule, LTrim(Str(nLine)) } }
   for i := 3 to 8
      if ! Empty( ProcName(i) )
         AAdd( aStack, { LTrim(Str(i-2)), ProcName(i), "", LTrim(Str(ProcLine(i))) } )
      endif
   next
   GTK_DebugUpdateStack( aStack )

return nil

// === Debugger ===

static function DebugStepOver()
   if IDE_DebugGetState() == 2  // DBG_PAUSED
      IDE_DebugStepOver()
   else
      GTK_DebugPanel()
      GTK_DebugSetStatus( "Start debug with Run > Run (F9)" )
   endif
return nil

static function DebugStepInto()
   if IDE_DebugGetState() == 2  // DBG_PAUSED
      IDE_DebugStep()
   else
      GTK_DebugPanel()
      GTK_DebugSetStatus( "Start debug with Run > Run (F9)" )
   endif
return nil

static function ToggleBreakpoint()
   static aBreakpoints := {}
   local cFile := aForms[ nActiveForm ][ 1 ] + ".prg"
   AAdd( aBreakpoints, { cFile, 1 } )
   IDE_DebugAddBreakpoint( cFile, 1 )
   GTK_DebugSetStatus( "Breakpoints: " + LTrim(Str(Len(aBreakpoints))) )
return nil

static function ClearBreakpoints()
   IDE_DebugClearBreakpoints()
   GTK_DebugSetStatus( "All breakpoints cleared" )
return nil

// === Components ===

static function InstallComponent()
   local cFile := GTK_OpenFileDialog( "Install Component (.prg)", "prg" )
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
   // Add as new tab in editor
   CodeEditorAddTab( hCodeEditor, "MyComponent.prg" )
   CodeEditorSetTabText( hCodeEditor, Len(aForms) + 2, cCode )
   CodeEditorSelectTab( hCodeEditor, Len(aForms) + 2 )
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
      AAdd( aItems, "  " + aForms[i][1] + ".prg" )
   next
   AAdd( aItems, "  classes.prg" )
   AAdd( aItems, "  hbbuilder.ch" )
   GTK_ProjectInspector( aItems )
return nil

// === Add/Remove from Project ===

static function AddToProject()
   local cFile := GTK_OpenFileDialog( "Add File to Project", "prg" )
   local cName, cCode, i
   if Empty( cFile ); return nil; endif
   cName := SubStr( cFile, RAt( "/", cFile ) + 1 )
   // Remove extension
   if "." $ cName
      cName := Left( cName, At( ".", cName ) - 1 )
   endif
   // Check if already in project
   for i := 1 to Len( aForms )
      if Lower( aForms[i][1] ) == Lower( cName )
         MsgInfo( cName + " is already in the project" )
         return nil
      endif
   next
   // Read file and add as new form tab
   cCode := MemoRead( cFile )
   if Empty( cCode )
      cCode := "// " + cName + ".prg" + Chr(10)
   endif
   // Add to project (as code-only unit, no visual form)
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
   nSel := GTK_SelectFromList( "Remove from Project", aNames )
   if nSel > 0 .and. nSel <= Len( aForms )
      aForms[nSel][2]:Destroy()
      ADel( aForms, nSel )
      ASize( aForms, Len(aForms) - 1 )
      if nActiveForm > Len( aForms )
         nActiveForm := Len( aForms )
      endif
      // Rebuild editor tabs
      CodeEditorClearTabs( hCodeEditor )
      CodeEditorSetTabText( hCodeEditor, 1, GenerateProjectCode() )
      for i := 1 to Len( aForms )
         CodeEditorAddTab( hCodeEditor, aForms[i][1] + ".prg" )
         CodeEditorSetTabText( hCodeEditor, i + 1, aForms[i][3] )
      next
      SwitchToForm( nActiveForm )
   endif
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
      UI_FormAlignSelected( oDesignForm:hCpp, nMode )
      SyncDesignerToCode()
   endif
return nil

// === Dark Mode (toggle) ===

static function ToggleDarkMode()
   static lDark := .F.
   lDark := !lDark
   GTK_SetDarkMode( lDark )
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

// Framework
#include "../harbour/classes.prg"
#include "../harbour/inspector_gtk.prg"
