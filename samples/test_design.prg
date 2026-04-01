// test_design.prg - IDE with 3 independent windows (C++Builder layout)
//
// Window 1: IDE bar (top strip) - menu + speedbar
// Window 2: Object Inspector (left, floating)
// Window 3: Design Form (center-right, floating)
//
// All 3 are independent top-level windows sharing one message loop.

#include "c:\ide\harbour\commands.ch"

REQUEST HB_GT_GUI_DEFAULT

static oIDE          // Main IDE bar (top strip)
static oDesignForm   // Design form (independent floating window)
static nScreenW      // Screen width
static nScreenH      // Screen height

function Main()

   local oTB, oFile, oEdit, oView, oHelp

   nScreenW := W32_GetScreenWidth()
   nScreenH := W32_GetScreenHeight()

   // === Window 1: Main IDE bar (top strip, full screen width) ===
   // APPBAR = thin top bar with caption+min/max/close, no resize border
   // Height: title(23) + menu(20) + borders(8) + toolbar(28) + palette area(40) = ~119
   DEFINE FORM oIDE TITLE "IDE - Project1" ;
      SIZE nScreenW, 120 FONT "Segoe UI", 9 APPBAR

   // Position at top-left corner of screen
   UI_FormSetPos( oIDE:hCpp, 0, 0 )

   // Menu bar
   DEFINE MENUBAR OF oIDE

   DEFINE POPUP oFile PROMPT "&File" OF oIDE
   MENUITEM "&New"        OF oFile ACTION MsgInfo( "New file" )
   MENUITEM "&Open..."    OF oFile ACTION MsgInfo( "Open file" )
   MENUITEM "&Save"       OF oFile ACTION MsgInfo( "Save file" )
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

   DEFINE POPUP oView PROMPT "&Search" OF oIDE
   MENUITEM "&Find..."      OF oView ACTION MsgInfo( "Find" )
   MENUITEM "&Replace..."   OF oView ACTION MsgInfo( "Replace" )

   DEFINE POPUP oView PROMPT "&View" OF oIDE
   MENUITEM "&Inspector"    OF oView ACTION InspectorOpen()
   MENUITEM "&Object Tree"  OF oView ACTION MsgInfo( "Object Tree" )

   DEFINE POPUP oView PROMPT "&Project" OF oIDE
   MENUITEM "&Add to Project..." OF oView ACTION MsgInfo( "Add to Project" )
   MENUITEM "&Remove from Project" OF oView ACTION MsgInfo( "Remove" )
   MENUSEPARATOR OF oView
   MENUITEM "&Options..." OF oView ACTION MsgInfo( "Project Options" )

   DEFINE POPUP oView PROMPT "&Run" OF oIDE
   MENUITEM "&Run"           OF oView ACTION MsgInfo( "Run" )
   MENUITEM "&Step Over"     OF oView ACTION MsgInfo( "Step Over" )
   MENUITEM "Step &Into"     OF oView ACTION MsgInfo( "Step Into" )

   DEFINE POPUP oView PROMPT "&Component" OF oIDE
   MENUITEM "&Install Component..." OF oView ACTION MsgInfo( "Install" )
   MENUITEM "&New Component..."     OF oView ACTION MsgInfo( "New Component" )

   DEFINE POPUP oView PROMPT "&Tools" OF oIDE
   MENUITEM "&Environment Options..." OF oView ACTION MsgInfo( "Options" )

   DEFINE POPUP oHelp PROMPT "&Help" OF oIDE
   MENUITEM "&About IDE..." OF oHelp ACTION ;
      MsgInfo( "IDE v0.1 - Cross-platform visual designer" )

   // Speedbar (toolbar)
   DEFINE TOOLBAR oTB OF oIDE
   BUTTON "New"   OF oTB TOOLTIP "New file (Ctrl+N)"    ACTION MsgInfo( "New" )
   BUTTON "Open"  OF oTB TOOLTIP "Open file (Ctrl+O)"   ACTION MsgInfo( "Open" )
   BUTTON "Save"  OF oTB TOOLTIP "Save file (Ctrl+S)"   ACTION MsgInfo( "Save" )
   SEPARATOR OF oTB
   BUTTON "Cut"   OF oTB TOOLTIP "Cut (Ctrl+X)"         ACTION MsgInfo( "Cut" )
   BUTTON "Copy"  OF oTB TOOLTIP "Copy (Ctrl+C)"        ACTION MsgInfo( "Copy" )
   BUTTON "Paste" OF oTB TOOLTIP "Paste (Ctrl+V)"       ACTION MsgInfo( "Paste" )
   SEPARATOR OF oTB
   BUTTON "Undo"  OF oTB TOOLTIP "Undo (Ctrl+Z)"        ACTION MsgInfo( "Undo" )
   BUTTON "Redo"  OF oTB TOOLTIP "Redo (Ctrl+Y)"        ACTION MsgInfo( "Redo" )
   SEPARATOR OF oTB
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F5)"     ACTION MsgInfo( "Run" )

   // Component Palette (tabs with control buttons, right of speedbar)
   CreatePalette()

   // Status bar
   UI_StatusBarCreate( oIDE:hCpp )

   // === Window 3: Design Form (independent, positioned right of inspector) ===
   CreateDesignForm()
   oDesignForm:SetDesign( .t. )

   // === Window 2: Inspector (independent, positioned left) ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   // When user selects a control from the inspector combo:
   // nSel=0 means form, nSel=N means child N
   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )

   // Sync: selection change in design form -> refresh inspector + status
   UI_OnSelChange( oDesignForm:hCpp, ;
      { |hCtrl| OnDesignSelChange( hCtrl ) } )

   // Show design form first (no message loop)
   oDesignForm:Show()

   // When IDE closes, destroy all secondary windows first
   oIDE:OnClose := { || InspectorClose(), oDesignForm:Destroy() }

   // IDE enters the message loop (dispatches for ALL windows)
   oIDE:Activate()

   // Cleanup after message loop exits
   oIDE:Destroy()

return nil

static function CreatePalette()

   local oPal, nStd, nAdd

   DEFINE PALETTE oPal OF oIDE

   // Standard tab
   nStd := oPal:AddTab( "Standard" )
   oPal:AddComp( nStd, "A",    "Label",    1 )   // CT_LABEL
   oPal:AddComp( nStd, "ab",   "Edit",     2 )   // CT_EDIT
   oPal:AddComp( nStd, "Btn",  "Button",   3 )   // CT_BUTTON
   oPal:AddComp( nStd, "Chk",  "CheckBox", 4 )   // CT_CHECKBOX
   oPal:AddComp( nStd, "Cmb",  "ComboBox", 5 )   // CT_COMBOBOX
   oPal:AddComp( nStd, "Grp",  "GroupBox", 6 )   // CT_GROUPBOX
   oPal:AddComp( nStd, "Lst",  "ListBox",  7 )   // CT_LISTBOX
   oPal:AddComp( nStd, "Rad",  "Radio",    8 )   // CT_RADIO

   // Additional tab
   nAdd := oPal:AddTab( "Additional" )
   oPal:AddComp( nAdd, "Img",  "Image",    0 )
   oPal:AddComp( nAdd, "Shp",  "Shape",    0 )
   oPal:AddComp( nAdd, "Spd",  "SpeedBtn", 0 )

   // Data Access tab
   nAdd := oPal:AddTab( "Data Access" )
   oPal:AddComp( nAdd, "Tbl",  "Table",    0 )
   oPal:AddComp( nAdd, "Qry",  "Query",    0 )

   // Data Controls tab
   nAdd := oPal:AddTab( "Data Controls" )
   oPal:AddComp( nAdd, "DBG",  "DBGrid",   0 )
   oPal:AddComp( nAdd, "DBN",  "DBNav",    0 )

return nil

static function CreateDesignForm()

   local oCbx, oChk, oBtn

   DEFINE FORM oDesignForm TITLE "Form1" SIZE 470, 380 FONT "Segoe UI", 9 TOOLWINDOW

   // Position: right of inspector, below IDE bar
   UI_FormSetPos( oDesignForm:hCpp, 270, 145 )

   // Sample controls
   @ 13, 12 GROUPBOX "General" OF oDesignForm SIZE 430, 120

   @ 40, 26 SAY "Name:" OF oDesignForm SIZE 70
   @ 38, 100 GET oBtn VAR "John Doe" OF oDesignForm SIZE 200, 26

   @ 75, 26 SAY "City:" OF oDesignForm SIZE 70
   @ 73, 100 GET oBtn VAR "Madrid" OF oDesignForm SIZE 200, 26

   @ 150, 12 GROUPBOX "Options" OF oDesignForm SIZE 430, 100

   @ 175, 30 CHECKBOX oChk PROMPT "Active" OF oDesignForm SIZE 120 CHECKED
   @ 175, 180 CHECKBOX oChk PROMPT "Admin" OF oDesignForm SIZE 120

   @ 210, 30 SAY "Role:" OF oDesignForm SIZE 60
   @ 208, 100 COMBOBOX oCbx OF oDesignForm ITEMS { "User", "Manager", "Admin" } SIZE 150
   oCbx:Value := 0

   @ 290, 150 BUTTON oBtn PROMPT "&OK" OF oDesignForm SIZE 88, 26
   @ 290, 250 BUTTON oBtn PROMPT "&Cancel" OF oDesignForm SIZE 88, 26

return nil

static function OnComboSelect( nSel )

   local hTarget

   // nSel: 0 = form, N = child N (1-based)
   if nSel == 0
      hTarget := oDesignForm:hCpp
   else
      hTarget := UI_GetChild( oDesignForm:hCpp, nSel )
   endif

   if hTarget != 0
      // Select control in design form (shows dotted handles)
      UI_FormSelectCtrl( oDesignForm:hCpp, hTarget )
      // Refresh inspector properties for the selected control
      InspectorRefresh( hTarget )
   endif

return nil

static function OnDesignSelChange( hCtrl )

   local hTarget, cPos, cDim, i, nCount, nSel

   hTarget := If( hCtrl == 0, oDesignForm:hCpp, hCtrl )
   InspectorRefresh( hTarget )

   // Select the right entry in the inspector combo
   nSel := 0  // default = form itself
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

   // Update status bar: position and dimensions
   if oIDE:hCpp != 0
      cPos := LTrim( Str( UI_GetProp( hTarget, "nLeft" ) ) ) + ":" + ;
              LTrim( Str( UI_GetProp( hTarget, "nTop" ) ) )
      cDim := LTrim( Str( oDesignForm:Width ) ) + " x " + ;
              LTrim( Str( oDesignForm:Height ) )
      UI_StatusBarSetText( oIDE:hCpp, 0, cPos )
      UI_StatusBarSetText( oIDE:hCpp, 2, cDim )
   endif

return nil

static function MsgInfo( cText )

   W32_MsgBox( cText, "IDE" )

return nil

// Framework
#include "c:\ide\harbour\classes.prg"
#include "c:\ide\harbour\inspector.prg"

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>

HB_FUNC( W32_MSGBOX )
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

#pragma ENDDUMP
