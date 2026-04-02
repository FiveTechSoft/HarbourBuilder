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

   local oTB, oFile, oEdit, oSearch, oView, oProject, oRun, oComp, oTools, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY

   nScreenW := MAC_GetScreenWidth()
   nScreenH := MAC_GetScreenHeight()
   cCurrentFile := ""
   aForms := {}
   nActiveForm := 0

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
   MENUITEM "New Application" OF oFile ACTION TBNew()               ACCEL "n"
   MENUITEM "New Form"        OF oFile ACTION MenuNewForm()
   MENUSEPARATOR OF oFile
   MENUITEM "Open..."    OF oFile ACTION TBOpen()                   ACCEL "o"
   MENUITEM "Save"       OF oFile ACTION TBSave()                   ACCEL "s"
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
   MENUITEM "Forms..."     OF oView ACTION MenuViewForms()
   MENUITEM "Code Editor"  OF oView ACTION CodeEditorBringToFront( hCodeEditor )
   MENUITEM "Inspector"    OF oView ACTION InspectorOpen()

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
   MENUITEM "About HbBuilder..." OF oHelp ACTION ShowAbout()

   // Speedbar (toolbar with 28x28 icon-sized buttons)
   DEFINE TOOLBAR oTB OF oIDE
   BUTTON "New"   OF oTB TOOLTIP "New project (Cmd+N)"  ACTION TBNew()
   BUTTON "Open"  OF oTB TOOLTIP "Open file (Cmd+O)"    ACTION TBOpen()
   BUTTON "Save"  OF oTB TOOLTIP "Save file (Cmd+S)"    ACTION TBSave()
   SEPARATOR OF oTB
   BUTTON "Cut"   OF oTB TOOLTIP "Cut (Cmd+X)"          ACTION MsgInfo( "Cut" )
   BUTTON "Copy"  OF oTB TOOLTIP "Copy (Cmd+C)"         ACTION MsgInfo( "Copy" )
   BUTTON "Paste" OF oTB TOOLTIP "Paste (Cmd+V)"        ACTION MsgInfo( "Paste" )
   SEPARATOR OF oTB
   BUTTON "Undo"  OF oTB TOOLTIP "Undo (Cmd+Z)"         ACTION MsgInfo( "Undo" )
   BUTTON "Redo"  OF oTB TOOLTIP "Redo (Cmd+Y)"         ACTION MsgInfo( "Redo" )
   SEPARATOR OF oTB
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F9)"      ACTION TBRun()

   // Load toolbar icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_ToolBarLoadImages( oTB:hCpp, "../resources/toolbar.bmp" )

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

   local oPal, nStd, nAdd

   DEFINE PALETTE oPal OF oIDE

   // Standard tab - only controls that are implemented
   nStd := oPal:AddTab( "Standard" )
   oPal:AddComp( nStd, "A",    "Label",    1 )
   oPal:AddComp( nStd, "ab",   "Edit",     2 )
   oPal:AddComp( nStd, "Btn",  "Button",   3 )
   oPal:AddComp( nStd, "Chk",  "CheckBox", 4 )
   oPal:AddComp( nStd, "Cmb",  "ComboBox", 5 )
   oPal:AddComp( nStd, "Grp",  "GroupBox", 6 )

   // Load palette icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_PaletteLoadImages( oPal:hCpp, "../resources/palette.bmp" )

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

// Regenerate form code from current designer state (two-way tools)
// Reads all properties from the live form and its children
static function RegenerateFormCode( cName, hForm )

   local cCode := "", e := Chr(13) + Chr(10)
   local cSep := "//" + Replicate( "-", 68 ) + e
   local cClass := "T" + cName  // TForm1, TForm2...
   local i, nCount, hCtrl, cCtrlName, cCtrlClass, nType
   local nW, nH, nFL, nFT, cTitle, nClr
   local nL, nT, nCW, nCH, cText
   local cDatas := "", cCreate := "", cEvents := ""

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
         endcase
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
   cCode += e
   cCode += "return nil" + e
   cCode += cSep

return cCode

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

// === Component drop from palette ===

static function OnComponentDrop( hForm, nType, nL, nT, nW, nH )

   local cName, nCount, hCtrl
   static nLabelCnt := 0, nEditCnt := 0, nBtnCnt := 0
   static nChkCnt := 0, nCmbCnt := 0, nGrpCnt := 0

   // Auto-name the new control (C++Builder style: Button1, Button2...)
   do case
      case nType == 1;  nLabelCnt++;  cName := "Label"    + LTrim(Str(nLabelCnt))
      case nType == 2;  nEditCnt++;   cName := "Edit"     + LTrim(Str(nEditCnt))
      case nType == 3;  nBtnCnt++;    cName := "Button"   + LTrim(Str(nBtnCnt))
      case nType == 4;  nChkCnt++;    cName := "CheckBox" + LTrim(Str(nChkCnt))
      case nType == 5;  nCmbCnt++;    cName := "ComboBox" + LTrim(Str(nCmbCnt))
      case nType == 6;  nGrpCnt++;    cName := "GroupBox" + LTrim(Str(nGrpCnt))
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

   local cNewCode

   if nActiveForm < 1 .or. nActiveForm > Len( aForms )
      return nil
   endif

   // Regenerate form code from current designer state
   cNewCode := RegenerateFormCode( aForms[ nActiveForm ][ 1 ], oDesignForm:hCpp )

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
   local nInsTop, nEditorTop, nBottomY

   // Save current form code
   SaveActiveFormCode()

   // Hide current form
   if nActiveForm > 0
      aForms[ nActiveForm ][ 2 ]:Close()
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

// === Toolbar actions ===

// New Application: reset everything (like C++Builder File > New > Application)
static function TBNew()

   local i, nFormX, nFormY, nInsW, nEditorX, nEditorW, nEditorH
   local nInsTop, nEditorTop, nBottomY

   // Destroy all existing forms
   for i := 1 to Len( aForms )
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0

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

   local cFile, cContent, cDir, cLine, aLines, i
   local cFormName, cFormCode, nFormX, nFormY
   local nInsW, nInsTop, nEditorTop, nEditorX, nEditorW, nEditorH

   cFile := MAC_OpenFileDialog( "Open HbBuilder Project", "hbp" )
   if Empty( cFile )
      return nil
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
      aForms[i][2]:Destroy()
   next
   aForms := {}
   nActiveForm := 0

   // Clear editor tabs
   CodeEditorClearTabs( hCodeEditor )

   // Calculate form positions
   nInsW := Int( nScreenW * 0.18 )
   nInsTop := MAC_GetWindowBottom( oIDE:hCpp )
   nEditorTop := nInsTop + 80
   nEditorX := nInsW
   nEditorW := nScreenW - nEditorX
   nEditorH := nScreenH - nEditorTop

   // Read project file: each line is a form name (Form1, Form2...)
   // First line is the project title, rest are form names
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
      cFile := MAC_SaveFileDialog( "Save HbBuilder Project", "Project1.hbp", "hbp" )
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
   local cHbDir, cHbBin, cHbInc, cHbLib, cProjDir
   local cAllPrg, cCmd

   SaveActiveFormCode()

   cBuildDir := "/tmp/hbbuilder_build"
   cHbDir   := "/Users/usuario/harbour"
   cHbBin   := cHbDir + "/bin/darwin/clang"
   cHbInc   := cHbDir + "/include"
   cHbLib   := cHbDir + "/lib/darwin/clang"
   cProjDir := "/Users/usuario/hbcpp"
   cLog     := ""
   lError   := .F.

   MAC_ShellExec( "mkdir -p " + cBuildDir )

   // Step 1: Save files
   cLog += "[1] Saving project files..." + Chr(10)
   MemoWrit( cBuildDir + "/Project1.prg", CodeEditorGetTabText( hCodeEditor, 1 ) )
   for i := 1 to Len( aForms )
      MemoWrit( cBuildDir + "/" + aForms[i][1] + ".prg", aForms[i][3] )
      cLog += "    " + aForms[i][1] + ".prg" + Chr(10)
   next
   MAC_ShellExec( "cp " + cProjDir + "/harbour/classes.prg " + cBuildDir + "/" )
   MAC_ShellExec( "cp " + cProjDir + "/harbour/hbbuilder.ch " + cBuildDir + "/" )

   // Step 2: Assemble main.prg
   cLog += "[2] Building main.prg..." + Chr(10)
   cAllPrg := '#include "hbbuilder.ch"' + Chr(10)
   cAllPrg += "REQUEST HB_GT_GUI_DEFAULT" + Chr(10) + Chr(10)
   cAllPrg += StrTran( MemoRead( cBuildDir + "/Project1.prg" ), ;
                       '#include "hbbuilder.ch"', "" ) + Chr(10)
   for i := 1 to Len( aForms )
      cAllPrg += MemoRead( cBuildDir + "/" + aForms[i][1] + ".prg" ) + Chr(10)
   next
   MemoWrit( cBuildDir + "/main.prg", cAllPrg )

   // Step 3: Compile user code with Harbour
   if ! lError
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
      cLog += "[4] Compiling framework..." + Chr(10)
      cCmd := cHbBin + "/harbour " + cBuildDir + "/classes.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/classes.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 5: Compile C
   if ! lError
      cLog += "[5] Compiling C sources..." + Chr(10)
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/main.c -o " + cBuildDir + "/main.o 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      endif
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/classes.c -o " + cBuildDir + "/classes.o 2>&1"
      MAC_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 6: Compile Cocoa backend + GT dummy
   if ! lError
      cLog += "[6] Compiling Cocoa backend..." + Chr(10)
      cCmd := "clang -c -O2 -fobjc-arc -I" + cHbInc + ;
              " " + cProjDir + "/backends/cocoa/cocoa_core.m" + ;
              " -o " + cBuildDir + "/cocoa_core.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -I" + cHbInc + ;
              " " + cHbDir + "/src/rtl/gtgui/gtgui.c" + ;
              " -o " + cBuildDir + "/gtgui.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -I" + cHbInc + ;
              " " + cProjDir + "/backends/cocoa/gt_dummy.c" + ;
              " -o " + cBuildDir + "/gt_dummy.o 2>&1"
      MAC_ShellExec( cCmd )
      cLog += "    OK" + Chr(10)
   endif

   // Step 7: Link
   if ! lError
      cLog += "[7] Linking..." + Chr(10)
      cCmd := "clang++ -o " + cBuildDir + "/UserApp" + ;
              " " + cBuildDir + "/main.o" + ;
              " " + cBuildDir + "/classes.o" + ;
              " " + cBuildDir + "/cocoa_core.o" + ;
              " " + cBuildDir + "/gtgui.o" + ;
              " " + cBuildDir + "/gt_dummy.o" + ;
              " -L" + cHbLib + ;
              " -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang" + ;
              " -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug" + ;
              " -lhbct -lhbextern" + ;
              " -lrddntx -lrddnsx -lrddcdx -lrddfpt" + ;
              " -lhbhsx -lhbsix -lhbusrrdd" + ;
              " -lgtcgi -lgtstd" + ;
              " -framework Cocoa -framework UniformTypeIdentifiers" + ;
              " -lm -lpthread 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if "error" $ Lower( cOutput )
         cLog += "    FAILED:" + Chr(10) + cOutput + Chr(10)
         lError := .T.
      else
         cLog += "    OK" + Chr(10)
      endif
   endif

   // Result
   if lError
      MsgInfo( "Build FAILED:" + Chr(10) + Chr(10) + cLog )
   else
      cLog += Chr(10) + "Build succeeded. Running..." + Chr(10)
      // Create .app bundle and launch (macOS needs bundle for GUI app)
      MAC_ShellExec( "mkdir -p " + cBuildDir + "/UserApp.app/Contents/MacOS" )
      MAC_ShellExec( "cp " + cBuildDir + "/UserApp " + cBuildDir + "/UserApp.app/Contents/MacOS/" )
      MemoWrit( cBuildDir + "/UserApp.app/Contents/Info.plist", ;
         '<?xml version="1.0"?>' + Chr(10) + ;
         '<plist version="1.0"><dict>' + Chr(10) + ;
         '<key>CFBundleExecutable</key><string>UserApp</string>' + Chr(10) + ;
         '</dict></plist>' + Chr(10) )
      MAC_ShellExec( "open " + cBuildDir + "/UserApp.app" )
   endif

return nil

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

   MAC_AboutDialog( "About HbBuilder", cMsg, "../resources/harbour_logo.png" )

return nil

static function MsgInfo( cText )

   MAC_MsgBox( cText, "HbBuilder" )

return nil

// Framework
#include "../harbour/classes.prg"
#include "../harbour/inspector_mac.prg"
