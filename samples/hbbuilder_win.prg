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

#include "../harbour/hbbuilder.ch"

REQUEST HB_GT_GUI_DEFAULT

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

   local oTB, oFile, oEdit, oSearch, oView, oProject, oRun, oComp, oTools, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY

   // Check if Harbour and BCC are installed
   CheckHarbourInstall()

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
   nBarH    := 140                           // title(23) + menu(20) + borders(8) + toolbar(36) + palette(52)
   nInsW    := Int( nScreenW * 0.18 )        // ~18% of screen width

   // === Window 1: Main Bar (full screen width) ===
   DEFINE FORM oIDE TITLE "HbBuilder 1.0 - Visual IDE for Harbour" ;
      SIZE nScreenW, nBarH FONT "Segoe UI", 9 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()

   // Enable dark mode for all IDE windows (Windows 10/11)
   W32_SetDarkMode( UI_FormGetHwnd( oIDE:hCpp ), .T. )

   // Inspector and editor: right below IDE window (3px overlap to close gap)
   nInsTop  := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 3
   nEditorTop := nInsTop
   nEditorX := nInsW - 5
   nEditorW := nScreenW - nEditorX
   // Both inspector and editor end at same bottom position
   nBottomY := nScreenH                        // no bottom margin
   nEditorH := nBottomY - nEditorTop

   // Form Designer: centered in editor area, slightly above center
   nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 )
   nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 )

   // Menu bar
   DEFINE MENUBAR OF oIDE

   DEFINE POPUP oFile PROMPT "&File" OF oIDE
   MENUITEM "&New Application" OF oFile ACTION TBNew()
   MENUITEM "New &Form"        OF oFile ACTION MenuNewForm()
   MENUSEPARATOR OF oFile
   MENUITEM "&Open..."    OF oFile ACTION TBOpen()
   MENUITEM "&Save"       OF oFile ACTION TBSave()
   MENUITEM "Save &As..." OF oFile ACTION MsgInfo( "Save As" )
   MENUSEPARATOR OF oFile
   MENUITEM "E&xit"       OF oFile ACTION oIDE:Close()

   DEFINE POPUP oEdit PROMPT "&Edit" OF oIDE
   MENUITEM "&Undo"  OF oEdit ACTION MsgInfo( "Undo" )
   MENUITEM "&Redo"  OF oEdit ACTION MsgInfo( "Redo" )
   MENUSEPARATOR OF oEdit
   MENUITEM "Cu&t"   OF oEdit ACTION MsgInfo( "Cut" )
   MENUITEM "&Copy"  OF oEdit ACTION MsgInfo( "Copy" )
   MENUITEM "&Paste" OF oEdit ACTION MsgInfo( "Paste" )

   DEFINE POPUP oSearch PROMPT "&Search" OF oIDE
   MENUITEM "&Find..."      OF oSearch ACTION MsgInfo( "Find" )
   MENUITEM "&Replace..."   OF oSearch ACTION MsgInfo( "Replace" )

   DEFINE POPUP oView PROMPT "&View" OF oIDE
   MENUITEM "&Forms..."     OF oView ACTION MenuViewForms()
   MENUITEM "&Code Editor"  OF oView ACTION CodeEditorBringToFront( hCodeEditor )
   MENUITEM "&Inspector"       OF oView ACTION InspectorOpen()
   MENUITEM "&Project Inspector" OF oView ACTION ShowProjectInspector()

   DEFINE POPUP oProject PROMPT "&Project" OF oIDE
   MENUITEM "&Add to Project..."    OF oProject ACTION MsgInfo( "Add to Project" )
   MENUITEM "&Remove from Project"  OF oProject ACTION MsgInfo( "Remove" )
   MENUSEPARATOR OF oProject
   MENUITEM "&Options..."           OF oProject ACTION ShowProjectOptions()

   DEFINE POPUP oRun PROMPT "&Run" OF oIDE
   MENUITEM "&Run"           OF oRun ACTION TBRun()
   MENUITEM "&Step Over"     OF oRun ACTION MsgInfo( "Step Over" )
   MENUITEM "Step &Into"     OF oRun ACTION MsgInfo( "Step Into" )
   MENUSEPARATOR OF oRun
   MENUITEM "&Toggle Breakpoint"  OF oRun ACTION ToggleBreakpoint()
   MENUITEM "&Clear Breakpoints"  OF oRun ACTION ClearBreakpoints()

   DEFINE POPUP oComp PROMPT "&Component" OF oIDE
   MENUITEM "&Install Component..." OF oComp ACTION MsgInfo( "Install" )
   MENUITEM "&New Component..."     OF oComp ACTION MsgInfo( "New Component" )

   DEFINE POPUP oTools PROMPT "&Tools" OF oIDE
   MENUITEM "&Editor Colors..." OF oTools ACTION ShowEditorSettings()
   MENUITEM "&Environment Options..." OF oTools ACTION MsgInfo( "Options" )
   MENUSEPARATOR OF oTools
   MENUITEM "&Generate Palette Icons" OF oTools ACTION ( W32_GeneratePaletteIcons( .F. ), W32_GenerateToolbarIcons( .F. ) )
   MENUSEPARATOR OF oTools
   MENUITEM "&AI Assistant..."        OF oTools ACTION ShowAIAssistant()

   DEFINE POPUP oHelp PROMPT "&Help" OF oIDE
   MENUITEM "&Documentation"        OF oHelp ACTION W32_OpenDocs( "en" )
   MENUITEM "&Quick Start"          OF oHelp ACTION W32_OpenDocs( "en/quickstart.html" )
   MENUITEM "&Controls Reference"   OF oHelp ACTION W32_OpenDocs( "en/controls-standard.html" )
   MENUSEPARATOR OF oHelp
   MENUITEM "&About HbBuilder..."   OF oHelp ACTION ShowAbout()

   // Speedbar (toolbar with 28x28 icon-sized buttons)
   DEFINE TOOLBAR oTB OF oIDE
   BUTTON "New"   OF oTB TOOLTIP "New project (Ctrl+N)"  ACTION TBNew()
   BUTTON "Open"  OF oTB TOOLTIP "Open file (Ctrl+O)"    ACTION TBOpen()
   BUTTON "Save"  OF oTB TOOLTIP "Save file (Ctrl+S)"    ACTION TBSave()
   SEPARATOR OF oTB
   BUTTON "Cut"   OF oTB TOOLTIP "Cut (Ctrl+X)"          ACTION MsgInfo( "Cut" )
   BUTTON "Copy"  OF oTB TOOLTIP "Copy (Ctrl+C)"         ACTION MsgInfo( "Copy" )
   BUTTON "Paste" OF oTB TOOLTIP "Paste (Ctrl+V)"        ACTION MsgInfo( "Paste" )
   SEPARATOR OF oTB
   BUTTON "Undo"  OF oTB TOOLTIP "Undo (Ctrl+Z)"         ACTION MsgInfo( "Undo" )
   BUTTON "Redo"  OF oTB TOOLTIP "Redo (Ctrl+Y)"         ACTION MsgInfo( "Redo" )
   SEPARATOR OF oTB
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F9)"       ACTION TBRun()

   // Load toolbar icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_ToolBarLoadImages( oTB:hCpp, HB_DirBase() + "..\resources\toolbar.bmp" )

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

   // === Window 2: Object Inspector (left column, below bar) ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )
   INS_SetOnEventDblClick( _InsGetData(), ;
      { |hCtrl, cEvent| OnEventDblClick( hCtrl, cEvent ) } )
   INS_SetOnPropChanged( _InsGetData(), { || SyncDesignerToCode() } )
   INS_SetPos( _InsGetData(), 0, nInsTop, nInsW, nBottomY - nInsTop - 50 )

   WireDesignForm()

   // When IDE closes, destroy all secondary windows
   oIDE:OnClose := { || DestroyAllForms(), InspectorClose(), ;
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
   oPal:AddComp( nTab, "Tab",  "TabControl",  33 )
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

   // Load palette icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_PaletteLoadImages( oPal:hCpp, HB_DirBase() + "..\resources\palette.bmp" )

return nil

static function CreateDesignForm( nX, nY )

   local cName, nIdx

   // Generate form name: Form1, Form2, Form3...
   nIdx := Len( aForms ) + 1
   cName := "Form" + LTrim( Str( nIdx ) )

   // Create new empty form (like C++Builder File > New > VCL Forms Application)
   DEFINE FORM oDesignForm TITLE cName SIZE 400, 300 FONT "Segoe UI", 9 SIZABLE
   UI_FormSetPos( oDesignForm:hCpp, nX, nY )

   // Register in project form list
   // { cName, oForm, cCode, nX, nY }
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

// Regenerate form code from current designer state (two-way sync)
// Reads all properties from the live form and its children
static function RegenerateFormCode( cName, hForm )

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e
   local cClass := "T" + cName  // TForm1, TForm2...
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

   // Form properties (read from live form or use defaults)
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
      nClr   := 15790320  // 0x00F0F0F0
   endif

   // Enumerate child controls
   if hForm != 0
      nCount := UI_GetChildCount( hForm )
      for i := 1 to nCount
         hCtrl := UI_GetChild( hForm, i )
         if hCtrl == 0; loop; endif

         cCtrlName  := UI_GetProp( hCtrl, "cName" )
         cCtrlClass := UI_GetProp( hCtrl, "cClassName" )
         nType      := UI_GetType( hCtrl )
         if Empty( cCtrlName ); cCtrlName := "ctrl" + LTrim(Str(i)); endif

         // DATA declaration
         cDatas += "   DATA o" + cCtrlName + "   // " + cCtrlClass + e

         // Creation code in CreateForm
         nL := UI_GetProp( hCtrl, "nLeft" )
         nT := UI_GetProp( hCtrl, "nTop" )
         nCW := UI_GetProp( hCtrl, "nWidth" )
         nCH := UI_GetProp( hCtrl, "nHeight" )
         cText := UI_GetProp( hCtrl, "cText" )

         do case
            case nType == 1  // Label
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' SAY ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + e
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
            otherwise
               // Generic: all other control types
               cCreate += '   // ::o' + cCtrlName + ' (' + cCtrlClass + ') at ' + ;
                  LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                  LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
         endcase

         // Scan for event handlers matching this control
         aEvents := { "OnClick", "OnChange", "OnDblClick", "OnCreate", ;
                       "OnClose", "OnResize", "OnKeyDown", "OnKeyUp", ;
                       "OnMouseDown", "OnMouseUp", "OnEnter", "OnExit" }
         for j := 1 to Len( aEvents )
            cEvName := aEvents[j]
            cEvSuffix := SubStr( cEvName, 3 )
            cHandlerName := cCtrlName + cEvSuffix
            if cHandlerName $ cExistingCode
               cEvents += "   ::o" + cCtrlName + ":" + cEvName + ;
                  " := { || " + cHandlerName + "( Self ) }" + e
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
   if nClr != 15790320  // non-default color
      cCode += "   ::Color  := " + LTrim(Str(nClr)) + e
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
   cHandler := cName + SubStr( cEvent, 3 )  // skip "On"

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
      case nType == 33; cName := "TabControl"     + LTrim(Str(aCnt[nType]))
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

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
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

   // Update stored code and editor tab
   aForms[ nActiveForm ][ 3 ] := cNewCode
   CodeEditorSetTabText( hCodeEditor, nActiveForm + 1, cNewCode )

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
   local nInsTop, nEditorTop

   // Save current form code
   SaveActiveFormCode()

   // Hide current form
   if nActiveForm > 0
      aForms[ nActiveForm ][ 2 ]:Close()
   endif

   // Calculate position (same as initial form, offset a bit)
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 3
   nEditorTop := nInsTop
   nEditorX := nInsW - 5
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
   local nInsTop, nEditorTop

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

// Open Project: load a .hbp project file
static function TBOpen()

   local cFile, cContent, cDir, aLines, i
   local cFormName, cFormCode, nFormX, nFormY
   local nInsW, nInsTop, nEditorTop, nEditorX, nEditorW, nEditorH

   cFile := W32_OpenFileDialog( "Open HbBuilder Project", "hbp" )
   if Empty( cFile ); return nil; endif

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
      cFormName := AllTrim( aLines[i] )
      if Empty( cFormName ); loop; endif

      // Read form code
      cFormCode := MemoRead( cDir + cFormName + ".prg" )
      if Empty( cFormCode ); loop; endif

      // Calculate position
      nFormX := nEditorX + Int( ( nEditorW - 400 ) / 2 ) + ( Len(aForms) ) * 20
      nFormY := nEditorTop + Int( ( nEditorH - 300 ) * 0.35 ) + ( Len(aForms) ) * 20

      // Create design form
      CreateDesignForm( nFormX, nFormY )
      oDesignForm:SetDesign( .t. )
      oDesignForm:Show()

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

return nil

// Save Project: write .hbp + all .prg files
static function TBSave()

   local cDir, cFile, cHbp, i

   // Sync current form code
   SaveActiveFormCode()

   if Empty( cCurrentFile )
      cFile := W32_SaveFileDialog( "Save HbBuilder Project", "Project1.hbp", "hbp" )
      if Empty( cFile ); return nil; endif
      cCurrentFile := cFile
   endif

   // Project directory = same as .hbp file
   cDir := Left( cCurrentFile, RAt( "\", cCurrentFile ) )

   // Write .hbp file (project index)
   cHbp := "Project1" + Chr(10)
   for i := 1 to Len( aForms )
      cHbp += aForms[i][1] + Chr(10)
   next
   MemoWrit( cCurrentFile, cHbp )

   // Write Project1.prg
   MemoWrit( cDir + "Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )

   // Write each form .prg
   for i := 1 to Len( aForms )
      MemoWrit( cDir + aForms[i][1] + ".prg", aForms[i][3] )
   next

return nil

// Run: compile and execute the project (C++Builder F9)
static function TBRun()

   local cBuildDir, cOutput, cLog, i, lError
   local cHbDir, cHbBin, cHbInc, cHbLib
   local cCDir, cCC, cILink
   local cProjDir, cAllPrg, cCmd, cObjs

   SaveActiveFormCode()

   cBuildDir := "c:\hbbuilder_build"
   cHbDir   := "c:\harbour"
   cHbBin   := cHbDir + "\bin\win\bcc"
   cHbInc   := cHbDir + "\include"
   cHbLib   := cHbDir + "\lib\win\bcc"
   cCDir    := "c:\bcc77c"
   cCC      := cCDir + "\bin\bcc32.exe"
   cILink   := cCDir + "\bin\ilink32.exe"
   cProjDir := "c:\HarbourBuilder"
   cLog     := ""
   lError   := .F.

   W32_ShellExec( 'cmd /c mkdir "' + cBuildDir + '" 2>nul' )

   // Trace log
   MemoWrit( cBuildDir + "\build_trace.log", "=== TBRun started ===" + Chr(10) + ;
      "BuildDir: " + cBuildDir + Chr(10) + ;
      "HbDir: " + cHbDir + Chr(10) + ;
      "CDir: " + cCDir + Chr(10) + ;
      "ProjDir: " + cProjDir + Chr(10) + ;
      "Forms: " + LTrim(Str(Len(aForms))) + Chr(10) )

   // Step 1: Save files
   cLog += "[1] Saving project files..." + Chr(10)
   MemoWrit( cBuildDir + "\Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "\" + aForms[i][1] + ".prg", aForms[i][3] )
      cLog += "    " + aForms[i][1] + ".prg" + Chr(10)
   next
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\harbour\classes.prg" "' + cBuildDir + '\" >nul 2>&1' )
   W32_ShellExec( 'cmd /c copy "' + cProjDir + '\harbour\hbbuilder.ch" "' + cBuildDir + '\" >nul 2>&1' )

   // Step 2: Assemble main.prg
   cLog += "[2] Building main.prg..." + Chr(10)
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_GUI_DEFAULT" + Chr(10) + Chr(10)
   cAllPrg += StrTran( MemoRead( cBuildDir + "\Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += MemoRead( cBuildDir + "\" + aForms[i][1] + ".prg" ) + Chr(10)
   next
   MemoWrit( cBuildDir + "\main.prg", cAllPrg )

   // Step 3: Compile user code with Harbour
   if ! lError
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
      cLog += "[4] Compiling framework..." + Chr(10)
      cCmd := cHbBin + '\harbour.exe ' + cBuildDir + '\classes.prg /n /w /q' + ;
              " /i" + cHbInc + " /i" + cBuildDir + ;
              " /o" + cBuildDir + "\classes.c"
      W32_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 5: Compile C sources
   if ! lError
      cLog += "[5] Compiling C sources..." + Chr(10)
      cCmd := cCC + ' -c -O2 -tW -I' + cHbInc + ;
              " -I" + cCDir + "\include" + ;
              " -I" + cProjDir + "\cpp\include" + ;
              " " + cBuildDir + "\main.c" + ;
              " -o" + cBuildDir + "\main.obj"
      cOutput := W32_ShellExec( cCmd )
      if "Error" $ cOutput
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      endif
      cCmd := cCC + ' -c -O2 -tW -I' + cHbInc + ;
              " -I" + cCDir + "\include" + ;
              " -I" + cProjDir + "\cpp\include" + ;
              " " + cBuildDir + "\classes.c" + ;
              " -o" + cBuildDir + "\classes.obj"
      W32_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 6: Compile C++ core
   if ! lError
      cLog += "[6] Compiling C++ core..." + Chr(10)
      cCmd := cCC + ' -c -O2 -tW -I' + cHbInc + ;
              " -I" + cCDir + "\include" + ;
              " -I" + cProjDir + "\cpp\include" + ;
              " " + cProjDir + "\cpp\src\tcontrol.cpp" + ;
              " " + cProjDir + "\cpp\src\tform.cpp" + ;
              " " + cProjDir + "\cpp\src\tcontrols.cpp" + ;
              " " + cProjDir + "\cpp\src\hbbridge.cpp" + ;
              " -o" + cBuildDir + "\"
      cOutput := W32_ShellExec( cCmd )
      if "Error" $ cOutput
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Step 7: Link
   if ! lError
      cLog += "[7] Linking..." + Chr(10)
      cObjs := "c0w32.obj " + ;
               cBuildDir + "\main.obj " + ;
               cBuildDir + "\classes.obj " + ;
               cBuildDir + "\tcontrol.obj " + ;
               cBuildDir + "\tform.obj " + ;
               cBuildDir + "\tcontrols.obj " + ;
               cBuildDir + "\hbbridge.obj"
      cCmd := cILink + ' -Gn -aa -Tpe' + ;
              " -L" + cCDir + "\lib" + ;
              " -L" + cCDir + "\lib\psdk" + ;
              " -L" + cHbLib + ;
              " " + cObjs + "," + ;
              " " + cBuildDir + "\UserApp.exe,," + ;
              " hbrtl.lib hbvm.lib hbcpage.lib hblang.lib hbrdd.lib" + ;
              " hbmacro.lib hbpp.lib hbcommon.lib hbcplr.lib hbct.lib" + ;
              " hbhsx.lib hbsix.lib hbusrrdd.lib" + ;
              " rddntx.lib rddnsx.lib rddcdx.lib rddfpt.lib" + ;
              " hbdebug.lib gtwin.lib gtwvt.lib gtgui.lib" + ;
              " cw32.lib import32.lib ws2_32.lib" + ;
              " user32.lib gdi32.lib comctl32.lib comdlg32.lib shell32.lib" + ;
              " ole32.lib uuid.lib,,"
      cOutput := W32_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Write full build log to trace file
   MemoWrit( cBuildDir + "\build_trace.log", cLog )

   // Result
   if lError
      MsgInfo( "Build FAILED:" + Chr(10) + Chr(10) + cLog )
   else
      cLog += Chr(10) + "Build succeeded. Running..." + Chr(10)
      W32_ShellExec( 'cmd /c start "" "' + cBuildDir + '\UserApp.exe"' )
   endif

return nil

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
   static nCommentClr := 6985578   // RGB(106,153,85) green
   static nStringClr  := 13538510  // RGB(206,145,120) orange
   static nPreProcClr := 14530758  // RGB(198,120,221) purple
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
   static cHarbourDir   := "c:\harbour"
   static cCompilerDir  := "c:\bcc77c"
   static cProjectDir   := "c:\HarbourBuilder"
   static cOutputDir    := ""
   static cHbFlags      := "/n /w /q"
   static cCFlags       := "-c -O2 -tW"
   static cLinkFlags    := "-Gn -aa -Tpe"
   static cIncludePaths := ""
   static cLibPaths     := ""
   static cLibraries    := ""
   static lDebugInfo    := .F.
   static lWarnings     := .T.
   static lOptimize     := .T.

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
   endif

   MsgInfo( "Breakpoints: " + LTrim(Str(Len(aBreakpoints))) )
return nil

static function ClearBreakpoints()
   MsgInfo( "All breakpoints cleared" )
return nil

static function ShowDebugPanel()
   W32_DebugPanel()
return nil

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

// === Harbour Installation Check ===

static function CheckHarbourInstall()

   if ! File( "c:\harbour\bin\win\bcc\harbour.exe" )
      MsgInfo( "Harbour compiler not found!" + Chr(10) + ;
               Chr(10) + ;
               "HbBuilder requires Harbour 3.2 to compile projects." + Chr(10) + ;
               Chr(10) + ;
               "Please install Harbour from:" + Chr(10) + ;
               "https://harbour.github.io/" + Chr(10) + ;
               Chr(10) + ;
               "Expected path: c:\harbour" + Chr(10) + ;
               Chr(10) + ;
               "After installation, restart HbBuilder.", ;
               "Harbour Not Found" )
   endif

   if ! File( "c:\bcc77c\bin\bcc32.exe" )
      MsgInfo( "C Compiler (BCC) not found!" + Chr(10) + ;
               Chr(10) + ;
               "HbBuilder requires Embarcadero BCC to link projects." + Chr(10) + ;
               Chr(10) + ;
               "Expected path: c:\bcc77c" + Chr(10) + ;
               Chr(10) + ;
               "Download from: www.embarcadero.com", ;
               "Compiler Not Found" )
   endif

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

// MsgInfo() is now in classes.prg (cross-platform)

// Helper for inspector: get current editor code for handler name resolution
function _InsGetEditorCode()

   if hCodeEditor != nil .and. nActiveForm > 0
      return CodeEditorGetTabText( hCodeEditor, nActiveForm + 1 )
   endif

return ""

// Framework
#include "../harbour/classes.prg"
#include "../harbour/inspector.prg"

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

/* W32_DebugPanel() - Debugger panel with Watch, Locals, Call Stack */
HB_FUNC( W32_DEBUGPANEL )
{
   static HWND s_hDbgWnd = NULL;
   HWND hTab, hList, hOwner;
   HFONT hFont;
   RECT rc;
   TCITEMA tci;
   LVCOLUMNA lvc;

   if( s_hDbgWnd && IsWindow(s_hDbgWnd) ) {
      SetWindowPos(s_hDbgWnd,HWND_TOP,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE);
      return;
   }

   hOwner = GetActiveWindow();
   GetWindowRect(hOwner, &rc);
   hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);

   s_hDbgWnd = CreateWindowExA(WS_EX_TOOLWINDOW,
      "STATIC","Debugger",
      WS_POPUP|WS_CAPTION|WS_SYSMENU|WS_THICKFRAME|WS_VISIBLE,
      rc.left+50, rc.bottom-250, rc.right-rc.left-100, 230,
      NULL,NULL,GetModuleHandle(NULL),NULL);

   /* Tab control: Watch | Locals | Call Stack */
   hTab = CreateWindowExA(0,WC_TABCONTROLA,NULL,
      WS_CHILD|WS_VISIBLE|WS_CLIPSIBLINGS,
      0,0,rc.right-rc.left-100,28,
      s_hDbgWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hTab,WM_SETFONT,(WPARAM)hFont,TRUE);

   tci.mask=TCIF_TEXT;
   tci.pszText="Watch"; SendMessageA(hTab,TCM_INSERTITEMA,0,(LPARAM)&tci);
   tci.pszText="Locals"; SendMessageA(hTab,TCM_INSERTITEMA,1,(LPARAM)&tci);
   tci.pszText="Call Stack"; SendMessageA(hTab,TCM_INSERTITEMA,2,(LPARAM)&tci);
   tci.pszText="Breakpoints"; SendMessageA(hTab,TCM_INSERTITEMA,3,(LPARAM)&tci);
   tci.pszText="Output"; SendMessageA(hTab,TCM_INSERTITEMA,4,(LPARAM)&tci);

   /* ListView for variables */
   hList = CreateWindowExA(WS_EX_CLIENTEDGE,WC_LISTVIEWA,NULL,
      WS_CHILD|WS_VISIBLE|LVS_REPORT|LVS_SHOWSELALWAYS,
      0,28,rc.right-rc.left-100,180,
      s_hDbgWnd,NULL,GetModuleHandle(NULL),NULL);
   SendMessage(hList,WM_SETFONT,(WPARAM)hFont,TRUE);
   SendMessage(hList,LVM_SETEXTENDEDLISTVIEWSTYLE,0,
      LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES);

   memset(&lvc,0,sizeof(lvc));
   lvc.mask = LVCF_TEXT|LVCF_WIDTH;
   lvc.pszText="Name"; lvc.cx=150;
   SendMessageA(hList,LVM_INSERTCOLUMNA,0,(LPARAM)&lvc);
   lvc.pszText="Value"; lvc.cx=200;
   SendMessageA(hList,LVM_INSERTCOLUMNA,1,(LPARAM)&lvc);
   lvc.pszText="Type"; lvc.cx=100;
   SendMessageA(hList,LVM_INSERTCOLUMNA,2,(LPARAM)&lvc);

   /* Sample data */
   { LVITEMA lvi = {0};
     lvi.mask=LVIF_TEXT; lvi.iItem=0; lvi.pszText="oForm";
     SendMessageA(hList,LVM_INSERTITEMA,0,(LPARAM)&lvi);
     lvi.iSubItem=1; lvi.pszText="TForm {hCpp=0x...}";
     SendMessageA(hList,LVM_SETITEMA,0,(LPARAM)&lvi);
     lvi.iSubItem=2; lvi.pszText="Object";
     SendMessageA(hList,LVM_SETITEMA,0,(LPARAM)&lvi);

     lvi.iSubItem=0; lvi.iItem=1; lvi.pszText="nCount";
     SendMessageA(hList,LVM_INSERTITEMA,0,(LPARAM)&lvi);
     lvi.iSubItem=1; lvi.pszText="42";
     SendMessageA(hList,LVM_SETITEMA,0,(LPARAM)&lvi);
     lvi.iSubItem=2; lvi.pszText="Numeric";
     SendMessageA(hList,LVM_SETITEMA,0,(LPARAM)&lvi);

     lvi.iSubItem=0; lvi.iItem=2; lvi.pszText="cName";
     SendMessageA(hList,LVM_INSERTITEMA,0,(LPARAM)&lvi);
     lvi.iSubItem=1; lvi.pszText="\"Form1\"";
     SendMessageA(hList,LVM_SETITEMA,0,(LPARAM)&lvi);
     lvi.iSubItem=2; lvi.pszText="String";
     SendMessageA(hList,LVM_SETITEMA,0,(LPARAM)&lvi);
   }
}

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
   lf.lfHeight = -13; lf.lfCharSet = DEFAULT_CHARSET;
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

HB_FUNC( W32_GETSCREENWIDTH )
{
   hb_retni( GetSystemMetrics( SM_CXSCREEN ) );
}

HB_FUNC( W32_GETSCREENHEIGHT )
{
   hb_retni( GetSystemMetrics( SM_CYSCREEN ) );
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

   lstrcpynA( szFile, hb_parc(2), MAX_PATH );

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
   ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;

   if( GetSaveFileNameA( &ofn ) )
      hb_retc( szFile );
   else
      hb_retc( "" );
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

   hList = CreateWindowExA( WS_EX_CLIENTEDGE, "LISTBOX", NULL,
      WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_NOTIFY,
      10, 10, dlgW - 30, dlgH - 90,
      hDlg, (HMENU)100, GetModuleHandle(NULL), NULL );
   SendMessage( hList, WM_SETFONT, (WPARAM) hFont, TRUE );
   s_formsListBox = hList;

   hBtnOK = CreateWindowExA( 0, "BUTTON", "OK",
      WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
      dlgW/2 - 90, dlgH - 70, 80, 28,
      hDlg, (HMENU)IDOK, GetModuleHandle(NULL), NULL );
   SendMessage( hBtnOK, WM_SETFONT, (WPARAM) hFont, TRUE );

   hBtnCancel = CreateWindowExA( 0, "BUTTON", "Cancel",
      WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
      dlgW/2, dlgH - 70, 80, 28,
      hDlg, (HMENU)IDCANCEL, GetModuleHandle(NULL), NULL );
   SendMessage( hBtnCancel, WM_SETFONT, (WPARAM) hFont, TRUE );

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
   HWND all[] = { d->hHbDir, d->hHbFlags, d->hChkWarn, d->hChkDebug,
      d->hCDir, d->hCFlags, d->hChkOpt,
      d->hLinkFlags, d->hLibs,
      d->hProjDir, d->hOutDir, d->hIncPaths, d->hLibPaths };
   int i;
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
   GetWindowRect(hOwner,&rc);
   x = rc.left+((rc.right-rc.left)-PO_DLG_W)/2;
   y = rc.top+((rc.bottom-rc.top)-PO_DLG_H)/2;

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

   { RECT r={0,0,tw,IS}; HBRUSH b=CreateSolidBrush(RGB(255,0,255));
     FillRect(hM,&r,b); DeleteObject(b); }

   memset(&lf,0,sizeof(lf)); lf.lfHeight=-11; lf.lfWeight=FW_BOLD;
   lf.lfCharSet=DEFAULT_CHARSET; lstrcpyA(lf.lfFaceName,"Segoe UI");
   hF=CreateFontIndirectA(&lf); hOF=(HFONT)SelectObject(hM,hF);
   SetBkMode(hM,TRANSPARENT); SetTextColor(hM,RGB(255,255,255));

   EnsureGdiPlus();

   for(i=0;i<IC;i++) {
      int x=i*IS; RECT ri={x+1,1,x+IS-1,IS-1}, rt={x+2,7,x+IS-2,IS-4};
      BOOL bDrawn = FALSE;

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
   { RECT r={0,0,tw,32}; HBRUSH b=CreateSolidBrush(RGB(255,0,255));
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
            lf.lfHeight = -14; lf.lfCharSet = DEFAULT_CHARSET;
            lstrcpyA( lf.lfFaceName, "Segoe UI" );
            hFont = CreateFontIndirectA( &lf );
            hOldFont = (HFONT) SelectObject( hDC, hFont );
            SetTextColor( hDC, RGB(40, 40, 40) );
            SetBkMode( hDC, TRANSPARENT );
            rcText.left = 20; rcText.top = imgY;
            rcText.right = rc.right - 20; rcText.bottom = rc.bottom - 50;
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
   HFONT hFont;
   int dlgW = 380, dlgH = 420;
   int x, y;
   RECT rcOwner;
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

   /* OK button */
   hFont = (HFONT) GetStockObject( DEFAULT_GUI_FONT );
   hBtn = CreateWindowExA( 0, "BUTTON", "OK",
      WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON,
      dlgW/2 - 45, dlgH - 70, 90, 30,
      hDlg, (HMENU)IDOK, GetModuleHandle(NULL), NULL );
   SendMessage( hBtn, WM_SETFONT, (WPARAM) hFont, TRUE );

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
 * Code Editor - RichEdit with syntax highlighting and TABS
 * ====================================================================== */

#define GUTTER_WIDTH 45
#define MAX_TABS     32
#define TAB_HEIGHT   24

typedef struct {
   HWND hWnd;       /* Tool window */
   HWND hEdit;      /* RichEdit control */
   HWND hGutter;    /* Line number gutter */
   HWND hTab;       /* Tab control */
   HFONT hFont;     /* Monospace font */
   WNDPROC oldEditProc;  /* Original RichEdit WndProc */
   /* Tab management */
   int nTabs;
   int nActiveTab;  /* 0-based */
   char * aTexts[MAX_TABS];
   /* Harbour callback for tab change */
   PHB_ITEM pOnTabChange;
   /* Find bar */
   HWND hFindBar;     /* Find bar panel */
   HWND hFindEdit;    /* Search text input */
   HWND hFindLabel;   /* Match count label */
   HWND hReplaceEdit; /* Replace text input */
   BOOL bFindVisible;
   BOOL bReplaceVisible;
} CODEEDITOR;

static void GutterPaint( CODEEDITOR * ed );
static void GutterSync( CODEEDITOR * ed );
static void SwitchTab( CODEEDITOR * ed, int nNewTab );

/* Harbour/xBase keywords for syntax highlighting */
static const char * s_keywords[] = {
   "function", "procedure", "return", "local", "static", "private", "public",
   "if", "else", "elseif", "endif", "do", "while", "enddo", "for", "next", "to", "step",
   "switch", "case", "otherwise", "endswitch", "endcase",
   "class", "endclass", "method", "data", "access", "assign", "inherit", "inline",
   "nil", "self", "begin", "end", "exit", "loop", "with",
   NULL
};

/* xBase commands (uppercase) */
static const char * s_commands[] = {
   "DEFINE", "ACTIVATE", "FORM", "TITLE", "SIZE", "FONT", "SIZABLE", "APPBAR", "TOOLWINDOW",
   "CENTERED", "SAY", "GET", "BUTTON", "PROMPT", "CHECKBOX", "COMBOBOX", "GROUPBOX",
   "ITEMS", "CHECKED", "DEFAULT", "CANCEL", "OF", "VAR", "ACTION",
   "TOOLBAR", "SEPARATOR", "TOOLTIP", "MENUBAR", "POPUP", "MENUITEM", "MENUSEPARATOR",
   "PALETTE", "REQUEST", "ACCEL",
   NULL
};

static int IsWordChar( char c )
{
   return ( c >= 'A' && c <= 'Z' ) || ( c >= 'a' && c <= 'z' ) ||
          ( c >= '0' && c <= '9' ) || c == '_';
}

static int IsKeyword( const char * word, int len )
{
   int i;
   char buf[64];
   if( len <= 0 || len >= 63 ) return 0;
   for( i = 0; i < len; i++ ) buf[i] = (char)tolower( (unsigned char)word[i] );
   buf[len] = 0;
   for( i = 0; s_keywords[i]; i++ )
      if( lstrcmpA( buf, s_keywords[i] ) == 0 ) return 1;
   return 0;
}

static int IsCommand( const char * word, int len )
{
   int i;
   char buf[64];
   if( len <= 0 || len >= 63 ) return 0;
   for( i = 0; i < len; i++ ) buf[i] = (char)toupper( (unsigned char)word[i] );
   buf[len] = 0;
   for( i = 0; s_commands[i]; i++ )
      if( lstrcmpA( buf, s_commands[i] ) == 0 ) return 1;
   return 0;
}

/* Apply color to a range in RichEdit */
static void SetRichColor( HWND hEdit, int nStart, int nEnd, COLORREF clr, BOOL bBold )
{
   CHARRANGE cr;
   CHARFORMATA cf = {0};
   cr.cpMin = nStart; cr.cpMax = nEnd;
   SendMessage( hEdit, EM_EXSETSEL, 0, (LPARAM) &cr );
   cf.cbSize = sizeof(cf);
   cf.dwMask = CFM_COLOR | CFM_BOLD;
   cf.crTextColor = clr;
   if( bBold ) cf.dwEffects = CFE_BOLD;
   SendMessageA( hEdit, EM_SETCHARFORMAT, SCF_SELECTION, (LPARAM) &cf );
}

/* Full syntax highlight pass */
static void HighlightCode( HWND hEdit )
{
   int nLen, i, ws;
   char * buf;
   CHARRANGE crSave;
   int nKeywords = 0, nComments = 0, nStrings = 0, nCommands = 0, nNumbers = 0;

   nLen = GetWindowTextLengthA( hEdit );
   if( nLen <= 0 ) return;

   buf = (char *) malloc( nLen + 1 );
   GetWindowTextA( hEdit, buf, nLen + 1 );

   /* Save selection, disable redraw */
   SendMessage( hEdit, EM_EXGETSEL, 0, (LPARAM) &crSave );
   SendMessage( hEdit, WM_SETREDRAW, FALSE, 0 );

   /* Reset all to light gray (default text on dark bg) */
   SetRichColor( hEdit, 0, nLen, RGB(220,220,220), FALSE );

   i = 0;
   while( i < nLen )
   {
      /* Line comments: // */
      if( buf[i] == '/' && i + 1 < nLen && buf[i+1] == '/' )
      {
         int start = i;
         while( i < nLen && buf[i] != '\r' && buf[i] != '\n' ) i++;
         SetRichColor( hEdit, start, i, RGB(106,153,85), FALSE );
         nComments++;
         continue;
      }

      /* Block comments */
      if( buf[i] == '/' && i + 1 < nLen && buf[i+1] == '*' )
      {
         int start = i;
         i += 2;
         while( i + 1 < nLen && !( buf[i] == '*' && buf[i+1] == '/' ) ) i++;
         if( i + 1 < nLen ) i += 2;
         SetRichColor( hEdit, start, i, RGB(106,153,85), FALSE );
         continue;
      }

      /* Strings: "..." or '...' */
      if( buf[i] == '"' || buf[i] == '\'' )
      {
         char q = buf[i];
         int start = i;
         i++;
         while( i < nLen && buf[i] != q && buf[i] != '\r' && buf[i] != '\n' ) i++;
         if( i < nLen && buf[i] == q ) i++;
         SetRichColor( hEdit, start, i, RGB(206,145,120), FALSE );
         nStrings++;
         continue;
      }

      /* Preprocessor: #include, #define, #xcommand */
      if( buf[i] == '#' )
      {
         int start = i;
         i++;
         while( i < nLen && IsWordChar(buf[i]) ) i++;
         SetRichColor( hEdit, start, i, RGB(198,120,221), TRUE );
         continue;
      }

      /* Logical literals: .T. .F. .AND. .OR. .NOT. */
      if( buf[i] == '.' && i + 2 < nLen )
      {
         int start = i;
         i++;
         while( i < nLen && buf[i] != '.' && IsWordChar(buf[i]) ) i++;
         if( i < nLen && buf[i] == '.' ) { i++; SetRichColor( hEdit, start, i, RGB(198,120,221), FALSE ); }
         continue;
      }

      /* Numbers: 123, 0x1A, etc. */
      if( buf[i] >= '0' && buf[i] <= '9' )
      {
         ws = i;
         while( i < nLen && ((buf[i]>='0'&&buf[i]<='9')||buf[i]=='.') ) i++;
         SetRichColor( hEdit, ws, i, RGB(180,230,150), FALSE ); nNumbers++;
            if(nNumbers<=3){FILE*f=fopen("c:\\HarbourBuilder\\syntax_detail.log","a");
              if(f){char w[64]={0};memcpy(w,buf+ws,i-ws>60?60:i-ws);
                fprintf(f,"NUM[%d]: '%s' pos=%d-%d\n",nNumbers,w,ws,i);fclose(f);}}
         continue;
      }

      /* Words: keywords and commands */
      if( IsWordChar(buf[i]) )
      {
         ws = i;
         while( i < nLen && IsWordChar(buf[i]) ) i++;
         if( IsKeyword( buf + ws, i - ws ) )
         {  SetRichColor( hEdit, ws, i, RGB(100,180,255), TRUE ); nKeywords++;
            if(nKeywords<=3){FILE*f=fopen("c:\\HarbourBuilder\\syntax_detail.log","a");
              if(f){char w[64]={0};memcpy(w,buf+ws,i-ws>60?60:i-ws);
                fprintf(f,"KW[%d]: '%s' pos=%d-%d\n",nKeywords,w,ws,i);fclose(f);}} }
         else if( IsCommand( buf + ws, i - ws ) )
         {  SetRichColor( hEdit, ws, i, RGB(80,220,190), FALSE ); nCommands++; }
         continue;
      }

      i++;
   }

   /* Log trace to file */
   { FILE * fLog = fopen( "c:\\HarbourBuilder\\syntax_trace.log", "a" );
     if( fLog ) {
        fprintf( fLog, "HighlightCode: len=%d kw=%d cmd=%d cmt=%d str=%d num=%d\n",
           nLen, nKeywords, nCommands, nComments, nStrings, nNumbers );
        fclose( fLog );
     }
   }

   /* Restore selection and redraw */
   SendMessage( hEdit, EM_EXSETSEL, 0, (LPARAM) &crSave );
   SendMessage( hEdit, WM_SETREDRAW, TRUE, 0 );
   InvalidateRect( hEdit, NULL, TRUE );

   free( buf );
}

/* Save current RichEdit text to the active tab's buffer */
static void SaveCurrentTabText( CODEEDITOR * ed )
{
   int nLen;
   if( !ed || !ed->hEdit || ed->nActiveTab < 0 || ed->nActiveTab >= ed->nTabs )
      return;

   if( ed->aTexts[ed->nActiveTab] )
      free( ed->aTexts[ed->nActiveTab] );

   nLen = GetWindowTextLengthA( ed->hEdit );
   ed->aTexts[ed->nActiveTab] = (char *) malloc( nLen + 1 );
   GetWindowTextA( ed->hEdit, ed->aTexts[ed->nActiveTab], nLen + 1 );
}

/* Switch to a different tab */
static void SwitchTab( CODEEDITOR * ed, int nNewTab )
{
   CHARFORMATA cf = {0};

   if( !ed || nNewTab < 0 || nNewTab >= ed->nTabs || nNewTab == ed->nActiveTab )
      return;

   /* Save current text */
   SaveCurrentTabText( ed );

   /* Load new tab text */
   ed->nActiveTab = nNewTab;
   if( ed->aTexts[nNewTab] )
      SetWindowTextA( ed->hEdit, ed->aTexts[nNewTab] );
   else
      SetWindowTextA( ed->hEdit, "" );

   /* Re-apply font formatting after SetWindowText */
   cf.cbSize = sizeof(cf);
   cf.dwMask = CFM_FACE | CFM_SIZE | CFM_COLOR;
   cf.yHeight = 15 * 20;
   cf.crTextColor = RGB(212,212,212);
   lstrcpyA( cf.szFaceName, "Consolas" );
   SendMessageA( ed->hEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM) &cf );

   HighlightCode( ed->hEdit );
   GutterSync( ed );

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

/* Gutter: paint line numbers */
static void GutterPaint( CODEEDITOR * ed )
{
   PAINTSTRUCT ps;
   HDC hDC, hMemDC;
   HBITMAP hBmp, hOldBmp;
   RECT rcGutter;
   int firstLine, lineCount, lineH, y, i, w, h;
   HFONT hOld;
   char szNum[16];

   if( !ed || !ed->hGutter || !ed->hEdit ) return;

   hDC = BeginPaint( ed->hGutter, &ps );
   GetClientRect( ed->hGutter, &rcGutter );
   w = rcGutter.right; h = rcGutter.bottom;

   /* Double buffer: paint to memory DC then BitBlt */
   hMemDC = CreateCompatibleDC( hDC );
   hBmp = CreateCompatibleBitmap( hDC, w, h );
   hOldBmp = (HBITMAP) SelectObject( hMemDC, hBmp );

   /* Dark fill background */
   {
      HBRUSH hBr = CreateSolidBrush( RGB(37, 37, 38) );
      FillRect( hMemDC, &rcGutter, hBr );
      DeleteObject( hBr );
   }

   /* Right border line */
   {
      HPEN hPen = CreatePen( PS_SOLID, 1, RGB(60, 60, 60) );
      HPEN hOldPen = (HPEN) SelectObject( hMemDC, hPen );
      MoveToEx( hMemDC, w - 1, 0, NULL );
      LineTo( hMemDC, w - 1, h );
      SelectObject( hMemDC, hOldPen );
      DeleteObject( hPen );
   }

   hOld = (HFONT) SelectObject( hMemDC, ed->hFont );
   SetBkMode( hMemDC, TRANSPARENT );
   SetTextColor( hMemDC, RGB(133, 133, 133) );

   /* Get first visible line and line height */
   firstLine = (int) SendMessage( ed->hEdit, EM_GETFIRSTVISIBLELINE, 0, 0 );
   lineCount = (int) SendMessage( ed->hEdit, EM_GETLINECOUNT, 0, 0 );

   /* Get line height from first char position */
   {
      POINTL pt1, pt2;
      int charIdx1, charIdx2;
      charIdx1 = (int) SendMessage( ed->hEdit, EM_LINEINDEX, firstLine, 0 );
      charIdx2 = (int) SendMessage( ed->hEdit, EM_LINEINDEX, firstLine + 1, 0 );
      SendMessage( ed->hEdit, EM_POSFROMCHAR, (WPARAM) &pt1, charIdx1 );
      if( charIdx2 > charIdx1 )
      {
         SendMessage( ed->hEdit, EM_POSFROMCHAR, (WPARAM) &pt2, charIdx2 );
         lineH = pt2.y - pt1.y;
      }
      else
         lineH = 18;  /* fallback */
      if( lineH < 8 ) lineH = 18;
      y = pt1.y;  /* starting Y from RichEdit's first visible line */
   }

   /* Draw line numbers */
   for( i = firstLine; i < lineCount && y < h; i++ )
   {
      RECT rcNum;
      sprintf( szNum, "%d", i + 1 );
      rcNum.left = 2;
      rcNum.top = y;
      rcNum.right = GUTTER_WIDTH - 6;
      rcNum.bottom = y + lineH;
      DrawTextA( hMemDC, szNum, -1, &rcNum, DT_RIGHT | DT_SINGLELINE | DT_VCENTER );
      y += lineH;
   }

   SelectObject( hMemDC, hOld );

   /* BitBlt from memory DC to screen - no flicker */
   BitBlt( hDC, 0, 0, w, h, hMemDC, 0, 0, SRCCOPY );

   SelectObject( hMemDC, hOldBmp );
   DeleteObject( hBmp );
   DeleteDC( hMemDC );
   EndPaint( ed->hGutter, &ps );
}

/* Sync gutter with RichEdit scroll position */
static void GutterSync( CODEEDITOR * ed )
{
   if( ed && ed->hGutter )
      InvalidateRect( ed->hGutter, NULL, TRUE );
}

/* Gutter WndProc */
static LRESULT CALLBACK GutterWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   CODEEDITOR * ed = (CODEEDITOR *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   if( msg == WM_PAINT && ed )
   {
      GutterPaint( ed );
      return 0;
   }

   return DefWindowProc( hWnd, msg, wParam, lParam );
}

/* Subclassed RichEdit: intercept scroll/changes to sync gutter */
/* RichEdit Find Text - define if not available */
#ifndef EM_FINDTEXT
#define EM_FINDTEXT  (WM_USER + 56)
#endif

typedef struct {
   CHARRANGE chrg;
   const char * lpstrText;
} FINDTEXTINFO;

/* ======================================================================
 * Auto-completion popup
 * ====================================================================== */

static const char * s_hbKeywords[] = {
   "function", "procedure", "return", "local", "static", "private", "public",
   "if", "else", "elseif", "endif", "do", "while", "enddo", "for", "next",
   "class", "endclass", "method", "data", "access", "assign",
   "switch", "case", "otherwise", "endswitch", "endcase",
   "begin", "end", "exit", "loop", "nil", "self", "with",
   NULL
};

static const char * s_hbFunctions[] = {
   "MsgInfo(", "MsgYesNo(", "MsgStop(", "MemoRead(", "MemoWrit(",
   "AllTrim(", "LTrim(", "RTrim(", "Upper(", "Lower(", "Len(",
   "SubStr(", "At(", "RAt(", "StrTran(", "Replicate(", "Space(",
   "Val(", "Str(", "HB_ValToStr(", "ValType(", "Type(",
   "AAdd(", "ASize(", "ADel(", "AIns(", "ASort(", "AScan(", "AEval(",
   "Array(", "AFill(", "AClone(", "HB_ATokens(",
   "Date(", "Time(", "Seconds(", "DToC(", "CToD(",
   "File(", "FOpen(", "FClose(", "FRead(", "FWrite(",
   "GetEnv(", "HB_DirCreate(", "HB_FNameDir(",
   "Empty(", "Iif(", "If(", "Max(", "Min(", "Abs(", "Int(", "Round(",
   "Chr(", "Asc(", "HB_UTF8ToStr(", "HB_StrToUTF8(",
   "Eval(", "HB_Random(", "HB_CRC32(",
   NULL
};

static const char * s_xbaseCommands[] = {
   "DEFINE FORM", "ACTIVATE FORM", "DEFINE TOOLBAR", "DEFINE PALETTE",
   "DEFINE MENUBAR", "DEFINE POPUP", "MENUITEM", "MENUSEPARATOR",
   "BUTTON", "CHECKBOX", "COMBOBOX", "GROUPBOX",
   "SAY", "GET", "PROMPT", "OF", "SIZE", "FONT", "ACTION",
   "TITLE", "APPBAR", "CENTERED", "SIZABLE", "TOOLWINDOW",
   "ITEMS", "CHECKED", "DEFAULT", "CANCEL", "VAR",
   "TOOLBAR", "SEPARATOR", "TOOLTIP",
   NULL
};

static void CE_ShowAutoComplete( CODEEDITOR * ed, const char * prefix )
{
   static HWND s_hPopup = NULL;
   HWND hList;
   HFONT hFont;
   RECT rc;
   POINTL pt;
   CHARRANGE cr;
   int i, nMatches = 0, prefLen;

   if( !ed || !ed->hEdit || !prefix || !prefix[0] ) {
      if( s_hPopup && IsWindow(s_hPopup) ) { DestroyWindow(s_hPopup); s_hPopup = NULL; }
      return;
   }

   prefLen = lstrlenA(prefix);

   /* Get cursor position on screen */
   SendMessage(ed->hEdit, EM_EXGETSEL, 0, (LPARAM)&cr);
   SendMessage(ed->hEdit, EM_POSFROMCHAR, (WPARAM)&pt, cr.cpMin);
   { POINT sp; sp.x = pt.x; sp.y = pt.y + 20;
     ClientToScreen(ed->hEdit, &sp);

     if( s_hPopup && IsWindow(s_hPopup) ) DestroyWindow(s_hPopup);

     s_hPopup = CreateWindowExA(WS_EX_TOOLWINDOW|WS_EX_TOPMOST,
        "STATIC", NULL, WS_POPUP|WS_VISIBLE|WS_BORDER,
        sp.x, sp.y, 280, 180,
        NULL, NULL, GetModuleHandle(NULL), NULL);

     hList = CreateWindowExA(0, "LISTBOX", NULL,
        WS_CHILD|WS_VISIBLE|WS_VSCROLL|LBS_NOTIFY,
        0, 0, 280, 180,
        s_hPopup, (HMENU)950, GetModuleHandle(NULL), NULL);

     hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
     SendMessage(hList, WM_SETFONT, (WPARAM)hFont, TRUE);

     /* Add matching keywords */
     for( i = 0; s_hbKeywords[i]; i++ )
        if( _strnicmp(s_hbKeywords[i], prefix, prefLen) == 0 ) {
           SendMessageA(hList, LB_ADDSTRING, 0, (LPARAM)s_hbKeywords[i]);
           nMatches++;
        }
     /* Add matching functions */
     for( i = 0; s_hbFunctions[i]; i++ )
        if( _strnicmp(s_hbFunctions[i], prefix, prefLen) == 0 ) {
           SendMessageA(hList, LB_ADDSTRING, 0, (LPARAM)s_hbFunctions[i]);
           nMatches++;
        }
     /* Add matching commands */
     for( i = 0; s_xbaseCommands[i]; i++ )
        if( _strnicmp(s_xbaseCommands[i], prefix, prefLen) == 0 ) {
           SendMessageA(hList, LB_ADDSTRING, 0, (LPARAM)s_xbaseCommands[i]);
           nMatches++;
        }

     if( nMatches == 0 ) {
        DestroyWindow(s_hPopup); s_hPopup = NULL;
     } else {
        SendMessage(hList, LB_SETCURSEL, 0, 0);
     }
   }
}

static void CE_CloseAutoComplete( void )
{
   HWND hPop = FindWindowA(NULL, NULL); /* handled by static var in ShowAutoComplete */
   /* The popup is managed by s_hPopup static in CE_ShowAutoComplete */
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

        /* Find Next button */
        h = CreateWindowExA(0,"BUTTON","Next",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
           278,2,50,22,ed->hFindBar,(HMENU)901,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        /* Find Prev button */
        h = CreateWindowExA(0,"BUTTON","Prev",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
           332,2,50,22,ed->hFindBar,(HMENU)902,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        /* Close button */
        h = CreateWindowExA(0,"BUTTON","X",WS_CHILD|WS_VISIBLE|BS_PUSHBUTTON,
           rc.right-32,2,26,22,ed->hFindBar,(HMENU)903,GetModuleHandle(NULL),NULL);
        SendMessage(h,WM_SETFONT,(WPARAM)hFont,TRUE);

        /* Match count label */
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

      /* Resize editor to make room */
      MoveWindow(ed->hEdit, GUTTER_WIDTH, TAB_HEIGHT,
         rc.right-GUTTER_WIDTH, rc.bottom-TAB_HEIGHT-barH, TRUE);
      MoveWindow(ed->hGutter, 0, TAB_HEIGHT, GUTTER_WIDTH, rc.bottom-TAB_HEIGHT-barH, TRUE);

      SetFocus( ed->hFindEdit );
   }
   else if( !bShow && ed->hFindBar ) {
      DestroyWindow( ed->hFindBar );
      ed->hFindBar = NULL; ed->hFindEdit = NULL; ed->hFindLabel = NULL; ed->hReplaceEdit = NULL;

      GetClientRect( ed->hWnd, &rc );
      MoveWindow(ed->hEdit, GUTTER_WIDTH, TAB_HEIGHT,
         rc.right-GUTTER_WIDTH, rc.bottom-TAB_HEIGHT, TRUE);
      MoveWindow(ed->hGutter, 0, TAB_HEIGHT, GUTTER_WIDTH, rc.bottom-TAB_HEIGHT, TRUE);

      SetFocus( ed->hEdit );
   }
}

/* Find text in RichEdit */
static void CE_FindNext( CODEEDITOR * ed, BOOL bForward )
{
   FINDTEXTINFO ft;
   CHARRANGE cr;
   char szFind[256];
   int nPos, nCount = 0, nLen;

   if( !ed || !ed->hEdit || !ed->hFindEdit ) return;

   GetWindowTextA( ed->hFindEdit, szFind, sizeof(szFind) );
   if( !szFind[0] ) return;

   /* Get current cursor position */
   SendMessage(ed->hEdit, EM_EXGETSEL, 0, (LPARAM)&cr);

   ft.chrg.cpMin = bForward ? cr.cpMax : cr.cpMin - 1;
   nLen = GetWindowTextLengthA(ed->hEdit);
   ft.chrg.cpMax = bForward ? nLen : 0;
   ft.lpstrText = szFind;

   nPos = (int) SendMessageA(ed->hEdit, EM_FINDTEXT,
      (bForward ? FR_DOWN : 0) | FR_MATCHCASE, (LPARAM)&ft);

   /* Wrap around if not found */
   if( nPos < 0 ) {
      ft.chrg.cpMin = bForward ? 0 : nLen;
      ft.chrg.cpMax = bForward ? nLen : 0;
      nPos = (int) SendMessageA(ed->hEdit, EM_FINDTEXT,
         (bForward ? FR_DOWN : 0) | FR_MATCHCASE, (LPARAM)&ft);
   }

   if( nPos >= 0 ) {
      cr.cpMin = nPos; cr.cpMax = nPos + lstrlenA(szFind);
      SendMessage(ed->hEdit, EM_EXSETSEL, 0, (LPARAM)&cr);
      SendMessage(ed->hEdit, EM_SCROLLCARET, 0, 0);
   }

   /* Count total matches */
   { FINDTEXTINFO fc; int p;
     fc.chrg.cpMin = 0; fc.chrg.cpMax = nLen; fc.lpstrText = szFind;
     nCount = 0;
     while( (p = (int)SendMessageA(ed->hEdit, EM_FINDTEXT, FR_DOWN|FR_MATCHCASE, (LPARAM)&fc)) >= 0 ) {
        nCount++; fc.chrg.cpMin = p + 1;
     }
   }

   if( ed->hFindLabel ) {
      char buf[64];
      sprintf(buf, "%d matches", nCount);
      SetWindowTextA(ed->hFindLabel, buf);
   }
}

static LRESULT CALLBACK CodeEditSubProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   CODEEDITOR * ed = (CODEEDITOR *) GetPropA( hWnd, "CodeEd" );
   LRESULT r;

   if( !ed ) return DefWindowProc( hWnd, msg, wParam, lParam );

   /* Intercept Ctrl+F (Find) and Ctrl+H (Replace) BEFORE RichEdit */
   if( msg == WM_KEYDOWN ) {
      BOOL ctrl = GetKeyState(VK_CONTROL) & 0x8000;
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
         CE_FindNext(ed, !(GetKeyState(VK_SHIFT) & 0x8000));
         return 0;
      }

      /* Ctrl+Space = auto-complete */
      if( ctrl && wParam == VK_SPACE ) {
         /* Get word before cursor */
         CHARRANGE cra;
         int nPos, nStart;
         char wordBuf[64] = {0};
         SendMessage(hWnd, EM_EXGETSEL, 0, (LPARAM)&cra);
         nPos = cra.cpMin;
         /* Scan backward for word start */
         if( nPos > 0 ) {
            int nLen = GetWindowTextLengthA(hWnd);
            char * allText = (char*)malloc(nLen+1);
            GetWindowTextA(hWnd, allText, nLen+1);
            nStart = nPos - 1;
            while( nStart > 0 && (IsWordChar(allText[nStart-1])) ) nStart--;
            if( nPos - nStart > 0 && nPos - nStart < 60 ) {
               memcpy(wordBuf, allText+nStart, nPos-nStart);
               wordBuf[nPos-nStart] = 0;
               CE_ShowAutoComplete(ed, wordBuf);
            }
            free(allText);
         }
         return 0;
      }

      /* Ctrl+Shift+[ = fold current block, Ctrl+Shift+] = unfold */
      if( ctrl && (GetKeyState(VK_SHIFT) & 0x8000) ) {
         if( wParam == VK_OEM_4 ) { /* [ key */
            /* Simple fold: hide lines from current to matching end */
            /* For now, just show a message - full folding needs custom line tracking */
            return 0;
         }
         if( wParam == VK_OEM_6 ) { /* ] key */
            return 0;
         }
      }

      /* Ctrl+G = Go to line */
      if( ctrl && wParam == 'G' ) {
         char buf[16] = "";
         CHARRANGE crg;
         int nLine;
         /* Simple input box via a prompt */
         /* For now, scroll to top as placeholder */
         crg.cpMin = 0; crg.cpMax = 0;
         SendMessage(hWnd, EM_EXSETSEL, 0, (LPARAM)&crg);
         SendMessage(hWnd, EM_SCROLLCARET, 0, 0);
         return 0;
      }

      /* Ctrl+/ = toggle line comment */
      if( ctrl && wParam == VK_OEM_2 ) { /* / key */
         CHARRANGE crc;
         int nLine;
         SendMessage(hWnd, EM_EXGETSEL, 0, (LPARAM)&crc);
         nLine = (int) SendMessage(hWnd, EM_LINEFROMCHAR, crc.cpMin, 0);
         /* Get line start */
         { int lineStart = (int) SendMessage(hWnd, EM_LINEINDEX, nLine, 0);
           int lineLen = (int) SendMessage(hWnd, EM_LINELENGTH, lineStart, 0);
           char lineBuf[512] = {0};
           CHARRANGE sel;
           if( lineLen > 0 && lineLen < 510 ) {
              *(WORD*)lineBuf = 510;
              SendMessageA(hWnd, EM_GETLINE, nLine, (LPARAM)lineBuf);
              lineBuf[lineLen] = 0;
              sel.cpMin = lineStart; sel.cpMax = lineStart;
              SendMessage(hWnd, EM_EXSETSEL, 0, (LPARAM)&sel);
              if( lineBuf[0] == '/' && lineBuf[1] == '/' ) {
                 /* Remove comment: select first 3 chars (// + space) */
                 int rmLen = (lineLen > 2 && lineBuf[2] == ' ') ? 3 : 2;
                 sel.cpMax = lineStart + rmLen;
                 SendMessage(hWnd, EM_EXSETSEL, 0, (LPARAM)&sel);
                 SendMessageA(hWnd, EM_REPLACESEL, TRUE, (LPARAM)"");
              } else {
                 /* Add comment */
                 SendMessageA(hWnd, EM_REPLACESEL, TRUE, (LPARAM)"// ");
              }
           }
         }
         return 0;
      }

      /* Ctrl+Shift+D = duplicate line */
      if( ctrl && (GetKeyState(VK_SHIFT) & 0x8000) && wParam == 'D' ) {
         CHARRANGE crd;
         int nLine, lineStart, lineLen;
         char dupBuf[1024] = {0};
         SendMessage(hWnd, EM_EXGETSEL, 0, (LPARAM)&crd);
         nLine = (int) SendMessage(hWnd, EM_LINEFROMCHAR, crd.cpMin, 0);
         lineStart = (int) SendMessage(hWnd, EM_LINEINDEX, nLine, 0);
         lineLen = (int) SendMessage(hWnd, EM_LINELENGTH, lineStart, 0);
         if( lineLen > 0 && lineLen < 1020 ) {
            *(WORD*)dupBuf = 1020;
            SendMessageA(hWnd, EM_GETLINE, nLine, (LPARAM)dupBuf);
            dupBuf[lineLen] = 0;
            /* Position at end of line */
            crd.cpMin = lineStart + lineLen;
            crd.cpMax = lineStart + lineLen;
            SendMessage(hWnd, EM_EXSETSEL, 0, (LPARAM)&crd);
            /* Insert newline + duplicate */
            { char ins[1030];
              ins[0] = '\r'; ins[1] = '\n';
              memcpy(ins+2, dupBuf, lineLen);
              ins[lineLen+2] = 0;
              SendMessageA(hWnd, EM_REPLACESEL, TRUE, (LPARAM)ins);
            }
         }
         return 0;
      }

      /* Ctrl+Shift+K = delete entire line */
      if( ctrl && (GetKeyState(VK_SHIFT) & 0x8000) && wParam == 'K' ) {
         CHARRANGE crk;
         int nLine, lineStart, lineEnd;
         SendMessage(hWnd, EM_EXGETSEL, 0, (LPARAM)&crk);
         nLine = (int) SendMessage(hWnd, EM_LINEFROMCHAR, crk.cpMin, 0);
         lineStart = (int) SendMessage(hWnd, EM_LINEINDEX, nLine, 0);
         lineEnd = (int) SendMessage(hWnd, EM_LINEINDEX, nLine + 1, 0);
         if( lineEnd <= lineStart ) lineEnd = lineStart + (int)SendMessage(hWnd, EM_LINELENGTH, lineStart, 0);
         crk.cpMin = lineStart; crk.cpMax = lineEnd;
         SendMessage(hWnd, EM_EXSETSEL, 0, (LPARAM)&crk);
         SendMessageA(hWnd, EM_REPLACESEL, TRUE, (LPARAM)"");
         return 0;
      }

      /* Ctrl+L = select entire line */
      if( ctrl && wParam == 'L' && !(GetKeyState(VK_SHIFT) & 0x8000) ) {
         CHARRANGE crl;
         int nLine, lineStart, lineEnd;
         SendMessage(hWnd, EM_EXGETSEL, 0, (LPARAM)&crl);
         nLine = (int) SendMessage(hWnd, EM_LINEFROMCHAR, crl.cpMin, 0);
         lineStart = (int) SendMessage(hWnd, EM_LINEINDEX, nLine, 0);
         lineEnd = (int) SendMessage(hWnd, EM_LINEINDEX, nLine + 1, 0);
         if( lineEnd <= lineStart ) lineEnd = lineStart + (int)SendMessage(hWnd, EM_LINELENGTH, lineStart, 0);
         crl.cpMin = lineStart; crl.cpMax = lineEnd;
         SendMessage(hWnd, EM_EXSETSEL, 0, (LPARAM)&crl);
         return 0;
      }
   }

   r = CallWindowProc( ed->oldEditProc, hWnd, msg, wParam, lParam );

   /* After scroll, key, or size: sync gutter */
   if( msg == WM_VSCROLL || msg == WM_MOUSEWHEEL ||
       msg == WM_KEYUP || msg == WM_SIZE ||
       msg == WM_CHAR || msg == WM_PASTE )
   {
      GutterSync( ed );
   }

   return r;
}

static BOOL s_gutterClassReg = FALSE;

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
            if( ed->hGutter )
               MoveWindow( ed->hGutter, 0, TAB_HEIGHT, GUTTER_WIDTH, h - TAB_HEIGHT, TRUE );
            if( ed->hEdit )
               MoveWindow( ed->hEdit, GUTTER_WIDTH, TAB_HEIGHT, w - GUTTER_WIDTH, h - TAB_HEIGHT, TRUE );
         }
         return 0;
      }

      case WM_NOTIFY:
      {
         NMHDR * pnm = (NMHDR *) lParam;
         if( ed && pnm->hwndFrom == ed->hTab && pnm->code == TCN_SELCHANGE )
         {
            int nSel = (int) SendMessage( ed->hTab, TCM_GETCURSEL, 0, 0 );
            if( nSel >= 0 && nSel < ed->nTabs && nSel != ed->nActiveTab )
               SwitchTab( ed, nSel );
         }
         break;
      }

      case WM_COMMAND:
         if( ed ) {
            WORD id = LOWORD(wParam);
            if( id == 901 ) CE_FindNext(ed, TRUE);        /* Next */
            if( id == 902 ) CE_FindNext(ed, FALSE);       /* Prev */
            if( id == 903 ) CE_ShowFindBar(ed, FALSE, FALSE); /* Close */
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
   CHARFORMATA cf = {0};
   HDC hDC;
   TCITEMA tci;
   int nLeft = hb_parni(1), nTop = hb_parni(2);
   int nWidth = hb_parni(3), nHeight = hb_parni(4);

   /* Load RichEdit library */
   LoadLibraryA( "Msftedit.dll" );

   /* Init common controls for Tab */
   {
      INITCOMMONCONTROLSEX icc = { sizeof(icc), ICC_TAB_CLASSES };
      InitCommonControlsEx( &icc );
   }

   ed = (CODEEDITOR *) malloc( sizeof(CODEEDITOR) );
   memset( ed, 0, sizeof(CODEEDITOR) );

   /* Monospace font - 15pt Consolas */
   {
      LOGFONTA lf = {0};
      hDC = GetDC( NULL );
      lf.lfHeight = -MulDiv( 15, GetDeviceCaps( hDC, LOGPIXELSY ), 72 );
      ReleaseDC( NULL, hDC );
      lf.lfCharSet = DEFAULT_CHARSET;
      lf.lfPitchAndFamily = FIXED_PITCH | FF_MODERN;
      lstrcpyA( lf.lfFaceName, "Consolas" );
      ed->hFont = CreateFontIndirectA( &lf );
   }

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
      WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
      0, 0, nWidth, TAB_HEIGHT,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   {
      HFONT hTabFont = (HFONT) GetStockObject( DEFAULT_GUI_FONT );
      SendMessage( ed->hTab, WM_SETFONT, (WPARAM) hTabFont, TRUE );
   }

   /* First tab: "Project1.prg" */
   memset( &tci, 0, sizeof(tci) );
   tci.mask = TCIF_TEXT;
   tci.pszText = "Project1.prg";
   SendMessageA( ed->hTab, TCM_INSERTITEMA, 0, (LPARAM) &tci );
   ed->nTabs = 1;
   ed->nActiveTab = 0;
   ed->aTexts[0] = NULL;

   /* Register gutter class */
   if( !s_gutterClassReg )
   {
      WNDCLASSA gc = {0};
      gc.lpfnWndProc = GutterWndProc;
      gc.hInstance = GetModuleHandle(NULL);
      gc.hCursor = LoadCursor(NULL, IDC_ARROW);
      gc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
      gc.lpszClassName = "HbIdeGutter";
      RegisterClassA( &gc );
      s_gutterClassReg = TRUE;
   }

   /* Gutter (line numbers) */
   ed->hGutter = CreateWindowExA( 0, "HbIdeGutter", NULL,
      WS_CHILD | WS_VISIBLE,
      0, TAB_HEIGHT, GUTTER_WIDTH, nHeight - TAB_HEIGHT,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   SetWindowLongPtr( ed->hGutter, GWLP_USERDATA, (LONG_PTR) ed );

   /* RichEdit control (to the right of gutter, below tabs) */
   ed->hEdit = CreateWindowExA( 0, "RICHEDIT50W", "",
      WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
      ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_WANTRETURN | ES_NOHIDESEL,
      GUTTER_WIDTH, TAB_HEIGHT, nWidth - GUTTER_WIDTH, nHeight - TAB_HEIGHT,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );

   /* If RICHEDIT50W fails, try RICHEDIT20A */
   if( !ed->hEdit )
   {
      LoadLibraryA( "Riched20.dll" );
      ed->hEdit = CreateWindowExA( 0, "RichEdit20A", "",
         WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
         ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_WANTRETURN | ES_NOHIDESEL,
         GUTTER_WIDTH, TAB_HEIGHT, nWidth - GUTTER_WIDTH, nHeight - TAB_HEIGHT,
         ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   }

   if( ed->hEdit )
   {
      /* Set default font via CHARFORMAT - 15pt Consolas */
      cf.cbSize = sizeof(cf);
      cf.dwMask = CFM_FACE | CFM_SIZE | CFM_COLOR;
      cf.yHeight = 15 * 20;  /* 15pt in twips */
      cf.crTextColor = RGB(212,212,212);  /* light gray text on dark bg */
      lstrcpyA( cf.szFaceName, "Consolas" );
      SendMessageA( ed->hEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM) &cf );

      /* Dark background */
      SendMessage( ed->hEdit, EM_SETBKGNDCOLOR, 0, (LPARAM) RGB(30,30,30) );

      /* Enable ENM_CHANGE for future auto-highlight */
      SendMessage( ed->hEdit, EM_SETEVENTMASK, 0, ENM_CHANGE );

      /* Subclass RichEdit to catch scroll events for gutter sync */
      SetPropA( ed->hEdit, "CodeEd", (HANDLE) ed );
      ed->oldEditProc = (WNDPROC) SetWindowLongPtr( ed->hEdit,
         GWLP_WNDPROC, (LONG_PTR) CodeEditSubProc );
   }

   ShowWindow( ed->hWnd, SW_SHOW );

   hb_retnint( (HB_PTRUINT) ed );
}

/* CodeEditorSetTabText( hEditor, nTab, cText ) - sets text for a tab (1-based) */
HB_FUNC( CODEEDITORSETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;  /* Convert to 0-based */
   CHARFORMATA cf = {0};

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

   /* If this is the active tab, update RichEdit - only if text changed */
   if( nTab == ed->nActiveTab && ed->hEdit )
   {
      /* Check if text actually changed to avoid unnecessary re-highlight */
      int nCurLen = GetWindowTextLengthA( ed->hEdit );
      int nNewLen = (int) hb_parclen(3);
      BOOL bChanged = ( nCurLen != nNewLen );

      if( !bChanged && nCurLen > 0 )
      {
         char * cur = (char *) malloc( nCurLen + 1 );
         GetWindowTextA( ed->hEdit, cur, nCurLen + 1 );
         bChanged = ( memcmp( cur, hb_parc(3), nNewLen ) != 0 );
         free( cur );
      }

      if( bChanged )
      {
         SetWindowTextA( ed->hEdit, ed->aTexts[nTab] );

         /* Re-apply font formatting */
         cf.cbSize = sizeof(cf);
         cf.dwMask = CFM_FACE | CFM_SIZE | CFM_COLOR;
         cf.yHeight = 15 * 20;
         cf.crTextColor = RGB(212,212,212);
         lstrcpyA( cf.szFaceName, "Consolas" );
         SendMessageA( ed->hEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM) &cf );

         HighlightCode( ed->hEdit );
         GutterSync( ed );
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

   /* If active tab, read from RichEdit (may have been edited) */
   if( nTab == ed->nActiveTab && ed->hEdit )
   {
      int nLen = GetWindowTextLengthA( ed->hEdit );
      char * buf = (char *) malloc( nLen + 1 );
      GetWindowTextA( ed->hEdit, buf, nLen + 1 );
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

   SetWindowTextA( ed->hEdit, "" );
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

/* CodeEditorBringToFront( hEditor ) */
HB_FUNC( CODEEDITORBRINGTOFRONT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hWnd )
   {
      ShowWindow( ed->hWnd, SW_SHOW );
      SetWindowPos( ed->hWnd, HWND_TOP, 0, 0, 0, 0,
         SWP_NOMOVE | SWP_NOSIZE );
   }
}

/* CodeEditorAppendText( hEditor, cText, nCursorOfs ) - append text at end */
HB_FUNC( CODEEDITORAPPENDTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   CHARFORMATA cf = {0};

   if( !ed || !ed->hEdit || !HB_ISCHAR(2) ) return;

   {
      int nLen = GetWindowTextLengthA( ed->hEdit );
      int nAppend = (int) hb_parclen(2);
      char * buf = (char *) malloc( nLen + nAppend + 1 );
      CHARRANGE cr;

      GetWindowTextA( ed->hEdit, buf, nLen + 1 );
      memcpy( buf + nLen, hb_parc(2), nAppend );
      buf[nLen + nAppend] = 0;

      SetWindowTextA( ed->hEdit, buf );

      /* Re-apply font formatting */
      cf.cbSize = sizeof(cf);
      cf.dwMask = CFM_FACE | CFM_SIZE | CFM_COLOR;
      cf.yHeight = 15 * 20;
      cf.crTextColor = RGB(212,212,212);
      lstrcpyA( cf.szFaceName, "Consolas" );
      SendMessageA( ed->hEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM) &cf );

      HighlightCode( ed->hEdit );

      /* Set cursor position */
      if( HB_ISNUM(3) )
      {
         int nOfs = nLen + hb_parni(3);
         cr.cpMin = nOfs; cr.cpMax = nOfs;
         SendMessage( ed->hEdit, EM_EXSETSEL, 0, (LPARAM) &cr );
         SendMessage( ed->hEdit, EM_SCROLLCARET, 0, 0 );
      }

      free( buf );
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
   CHARRANGE cr;

   if( !ed || !ed->hEdit || !cFunc )
   {
      hb_retl( FALSE );
      return;
   }

   nLen = GetWindowTextLengthA( ed->hEdit );
   if( nLen <= 0 ) { hb_retl( FALSE ); return; }

   buf = (char *) malloc( nLen + 1 );
   GetWindowTextA( ed->hEdit, buf, nLen + 1 );

   sprintf( szSearch, "function %s", cFunc );
   nFuncLen = (int) strlen( szSearch );

   pos = strstr( buf, szSearch );
   if( pos )
   {
      int nOfs = (int)(pos - buf) + nFuncLen;
      cr.cpMin = nOfs; cr.cpMax = nOfs;
      SendMessage( ed->hEdit, EM_EXSETSEL, 0, (LPARAM) &cr );
      SendMessage( ed->hEdit, EM_SCROLLCARET, 0, 0 );
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
      for( i = 0; i < ed->nTabs; i++ )
         if( ed->aTexts[i] ) free( ed->aTexts[i] );
      if( ed->hWnd ) DestroyWindow( ed->hWnd );
      if( ed->hFont ) DeleteObject( ed->hFont );
      free( ed );
   }
}

#pragma ENDDUMP
