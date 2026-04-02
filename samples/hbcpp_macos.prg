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

#include "../harbour/commands.ch"

static oIDE          // Main IDE bar (top strip)
static oDesignForm   // Design form (floats on top of editor)
static hCodeEditor   // Code editor (background, right of inspector)
static nScreenW      // Screen width
static nScreenH      // Screen height

function Main()

   local oTB, oFile, oEdit, oSearch, oView, oProject, oRun, oComp, oTools, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY

   nScreenW := MAC_GetScreenWidth()
   nScreenH := MAC_GetScreenHeight()

   // C++Builder classic proportions scaled to current screen
   // Reference: 1024x768 -> Inspector 250px (24.4%), Bar 100px (13%)
   nBarH    := 72                            // toolbar(36) + tabs(24) + margins(12)
   nInsW    := Int( nScreenW * 0.18 )        // ~18% of screen width

   // === Window 1: Main Bar (full screen width) ===
   DEFINE FORM oIDE TITLE "HbBuilder" ;
      SIZE nScreenW, nBarH FONT "Helvetica Neue", 12 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()

   // Inspector: right below IDE window
   nInsTop  := MAC_GetWindowBottom( oIDE:hCpp )
   // Editor: starts below IDE bar + offset
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
   MENUITEM "New"        OF oFile ACTION MsgInfo( "New file" )      ACCEL "n"
   MENUITEM "Open..."    OF oFile ACTION MsgInfo( "Open file" )     ACCEL "o"
   MENUITEM "Save"       OF oFile ACTION MsgInfo( "Save file" )     ACCEL "s"
   MENUITEM "Save As..." OF oFile ACTION MsgInfo( "Save As" )
   MENUSEPARATOR OF oFile
   MENUITEM "Exit"       OF oFile ACTION oIDE:Close()               ACCEL "q"

   DEFINE POPUP oEdit PROMPT "Edit" OF oIDE
   MENUITEM "Undo"  OF oEdit ACTION MsgInfo( "Undo" )              ACCEL "z"
   MENUITEM "Redo"  OF oEdit ACTION MsgInfo( "Redo" )              ACCEL "y"
   MENUSEPARATOR OF oEdit
   MENUITEM "Cut"   OF oEdit ACTION MsgInfo( "Cut" )               ACCEL "x"
   MENUITEM "Copy"  OF oEdit ACTION MsgInfo( "Copy" )              ACCEL "c"
   MENUITEM "Paste" OF oEdit ACTION MsgInfo( "Paste" )             ACCEL "v"

   DEFINE POPUP oSearch PROMPT "Search" OF oIDE
   MENUITEM "Find..."      OF oSearch ACTION MsgInfo( "Find" )     ACCEL "f"
   MENUITEM "Replace..."   OF oSearch ACTION MsgInfo( "Replace" )  ACCEL "h"

   DEFINE POPUP oView PROMPT "View" OF oIDE
   MENUITEM "Inspector"    OF oView ACTION InspectorOpen()
   MENUITEM "Object Tree"  OF oView ACTION MsgInfo( "Object Tree" )

   DEFINE POPUP oProject PROMPT "Project" OF oIDE
   MENUITEM "Add to Project..."    OF oProject ACTION MsgInfo( "Add to Project" )
   MENUITEM "Remove from Project"  OF oProject ACTION MsgInfo( "Remove" )
   MENUSEPARATOR OF oProject
   MENUITEM "Options..."           OF oProject ACTION MsgInfo( "Project Options" )

   DEFINE POPUP oRun PROMPT "Run" OF oIDE
   MENUITEM "Run"           OF oRun ACTION MsgInfo( "Run" )        ACCEL "r"
   MENUITEM "Step Over"     OF oRun ACTION MsgInfo( "Step Over" )
   MENUITEM "Step Into"     OF oRun ACTION MsgInfo( "Step Into" )

   DEFINE POPUP oComp PROMPT "Component" OF oIDE
   MENUITEM "Install Component..." OF oComp ACTION MsgInfo( "Install" )
   MENUITEM "New Component..."     OF oComp ACTION MsgInfo( "New Component" )

   DEFINE POPUP oTools PROMPT "Tools" OF oIDE
   MENUITEM "Environment Options..." OF oTools ACTION MsgInfo( "Options" )

   DEFINE POPUP oHelp PROMPT "Help" OF oIDE
   MENUITEM "About..." OF oHelp ACTION ;
      MsgInfo( "HbBuilder v0.1 - Visual development environment for Harbour" )

   // Speedbar (toolbar with 28x28 icon-sized buttons)
   DEFINE TOOLBAR oTB OF oIDE
   BUTTON "New"   OF oTB TOOLTIP "New file (Cmd+N)"    ACTION MsgInfo( "New" )
   BUTTON "Open"  OF oTB TOOLTIP "Open file (Cmd+O)"   ACTION MsgInfo( "Open" )
   BUTTON "Save"  OF oTB TOOLTIP "Save file (Cmd+S)"   ACTION MsgInfo( "Save" )
   SEPARATOR OF oTB
   BUTTON "Cut"   OF oTB TOOLTIP "Cut (Cmd+X)"         ACTION MsgInfo( "Cut" )
   BUTTON "Copy"  OF oTB TOOLTIP "Copy (Cmd+C)"        ACTION MsgInfo( "Copy" )
   BUTTON "Paste" OF oTB TOOLTIP "Paste (Cmd+V)"       ACTION MsgInfo( "Paste" )
   SEPARATOR OF oTB
   BUTTON "Undo"  OF oTB TOOLTIP "Undo (Cmd+Z)"        ACTION MsgInfo( "Undo" )
   BUTTON "Redo"  OF oTB TOOLTIP "Redo (Cmd+Y)"        ACTION MsgInfo( "Redo" )
   SEPARATOR OF oTB
   BUTTON "Run"   OF oTB TOOLTIP "Run project (Cmd+R)"  ACTION MsgInfo( "Run" )

   // Load toolbar icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_ToolBarLoadImages( oTB:hCpp, "../resources/toolbar.bmp" )

   // Component Palette (icon grid, tabbed, right of splitter)
   CreatePalette()

   // === Window 4: Code Editor (background, right of inspector, full area) ===
   // Created FIRST so it appears BEHIND the form
   hCodeEditor := CodeEditorCreate( nEditorX, nEditorTop, nEditorW, nEditorH )
   CodeEditorSetText( hCodeEditor, GenerateSampleCode() )

   // === Window 3: Form Designer (floating on top of editor) ===
   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   oDesignForm:Show()

   // === Window 2: Object Inspector (left column, below bar) ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )
   INS_SetOnEventDblClick( _InsGetData(), ;
      { |hCtrl, cEvent| OnEventDblClick( hCtrl, cEvent ) } )
   INS_SetPos( _InsGetData(), 0, nInsTop, nInsW, nBottomY - nInsTop - 50 )

   // Sync: selection change in design form -> refresh inspector
   UI_OnSelChange( oDesignForm:hCpp, ;
      { |hCtrl| OnDesignSelChange( hCtrl ) } )

   // When IDE closes, destroy all secondary windows
   oIDE:OnClose := { || InspectorClose(), oDesignForm:Destroy(), ;
                       CodeEditorDestroy( hCodeEditor ) }

   // IDE enters the message loop (dispatches for ALL windows)
   oIDE:Activate()

   // Cleanup
   oIDE:Destroy()

return nil

static function CreatePalette()

   local oPal, nStd, nAdd

   DEFINE PALETTE oPal OF oIDE

   // Standard tab (28x28 icon buttons)
   nStd := oPal:AddTab( "Standard" )
   oPal:AddComp( nStd, "A",    "Label",    1 )
   oPal:AddComp( nStd, "ab",   "Edit",     2 )
   oPal:AddComp( nStd, "Btn",  "Button",   3 )
   oPal:AddComp( nStd, "Chk",  "CheckBox", 4 )
   oPal:AddComp( nStd, "Cmb",  "ComboBox", 5 )
   oPal:AddComp( nStd, "Grp",  "GroupBox", 6 )
   oPal:AddComp( nStd, "Lst",  "ListBox",  7 )
   oPal:AddComp( nStd, "Rad",  "Radio",    8 )

   // Additional tab
   nAdd := oPal:AddTab( "Additional" )
   oPal:AddComp( nAdd, "Img",  "Image",    9 )
   oPal:AddComp( nAdd, "Shp",  "Shape",   10 )
   oPal:AddComp( nAdd, "Spd",  "SpeedBtn",11 )

   // Data Access tab
   nAdd := oPal:AddTab( "Data Access" )
   oPal:AddComp( nAdd, "Tbl",  "Table",   12 )
   oPal:AddComp( nAdd, "Qry",  "Query",   13 )

   // Data Controls tab
   nAdd := oPal:AddTab( "Data Controls" )
   oPal:AddComp( nAdd, "DBG",  "DBGrid",  14 )
   oPal:AddComp( nAdd, "DBN",  "DBNav",   15 )

   // Load palette icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_PaletteLoadImages( oPal:hCpp, "../resources/palette.bmp" )

return nil

static function CreateDesignForm( nX, nY )

   // New empty form, like C++Builder "File > New > VCL Forms Application"
   DEFINE FORM oDesignForm TITLE "Form1" SIZE 400, 300 FONT "Helvetica Neue", 12

   UI_FormSetPos( oDesignForm:hCpp, nX, nY )

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

return nil

static function GenerateSampleCode()

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e

   // === Project1.prg section ===
   cCode += "// Project1.prg" + e
   cCode += cSep
   cCode += '#include "commands.ch"' + e
   cCode += cSep
   cCode += e
   cCode += "PROCEDURE Main()" + e
   cCode += e
   cCode += "   local oApp" + e
   cCode += e
   cCode += "   oApp := TApplication():New()" + e
   cCode += '   oApp:Title := "Project1"' + e
   cCode += "   oApp:CreateForm( TForm1() )" + e
   cCode += "   oApp:Run()" + e
   cCode += e
   cCode += "return" + e
   cCode += e
   cCode += cSep
   cCode += "// Form1.prg" + e
   cCode += cSep
   cCode += e

   // === Form1.prg section (C++Builder Unit1.h + Unit1.cpp equivalent) ===
   cCode += "CLASS TForm1 FROM TForm" + e
   cCode += e
   cCode += "   // IDE-managed Components" + e
   cCode += e
   cCode += "   // Event handlers" + e
   cCode += e
   cCode += "   METHOD CreateForm()" + e
   cCode += e
   cCode += "ENDCLASS" + e
   cCode += cSep
   cCode += e
   cCode += "METHOD CreateForm() CLASS TForm1" + e
   cCode += e
   cCode += '   ::Title  := "Form1"' + e
   cCode += "   ::Width  := 400" + e
   cCode += "   ::Height := 300" + e
   cCode += e
   cCode += "return nil" + e
   cCode += cSep

return cCode

// Double-click on event in inspector: generate METHOD handler
// Follows C++Builder pattern: ComponentName + EventNameWithoutOn
// e.g. Button1 + OnClick -> Button1Click
// e.g. Form1 + OnCreate -> Form1Create
// e.g. Edit1 + OnChange -> Edit1Change
static function OnEventDblClick( hCtrl, cEvent )

   local cName, cClass, cHandler, cCode, cDecl, e, cSep, nCursorOfs
   local cEditorText

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

   // Check if handler already exists in code editor -> jump to it
   if CodeEditorGotoFunction( hCodeEditor, cHandler )
      return cHandler
   endif

   // Generate the METHOD implementation (C++Builder pattern)
   cCode := cSep
   cCode += "METHOD " + cHandler + "( oSender ) CLASS TForm1" + e
   cCode += e
   cCode += "   " + e
   cCode += e
   cCode += "return nil" + e

   // Cursor offset: place cursor on the empty line inside the method body
   nCursorOfs := Len( cSep ) + ;
                 Len( "METHOD " + cHandler + "( oSender ) CLASS TForm1" ) + ;
                 Len( e ) + Len( e ) + 3  // "   " indent

   // Append METHOD implementation to code editor
   CodeEditorAppendText( hCodeEditor, cCode, nCursorOfs )

   // Also insert METHOD declaration in the CLASS block
   // Find "// Event handlers" line and insert after it
   cDecl := "   METHOD " + cHandler + "( oSender )" + e
   CodeEditorInsertAfter( hCodeEditor, "// Event handlers", cDecl )

return cHandler

static function MsgInfo( cText )

   MAC_MsgBox( cText, "IDE" )

return nil

// Framework
#include "../harbour/classes.prg"
#include "../harbour/inspector_mac.prg"
