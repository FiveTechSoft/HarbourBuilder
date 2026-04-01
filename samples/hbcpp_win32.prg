// hbcpp_win32.prg - IDE with 4 independent windows (Borland C++Builder layout)
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

#include "../harbour/commands.ch"

REQUEST HB_GT_GUI_DEFAULT

static oIDE          // Main IDE bar (top strip)
static oDesignForm   // Design form (floats on top of editor)
static hCodeEditor   // Code editor (background, right of inspector)
static nScreenW      // Screen width
static nScreenH      // Screen height

function Main()

   local oTB, oFile, oEdit, oSearch, oView, oProject, oRun, oComp, oTools, oHelp
   local nBarH, nInsW, nEditorX, nEditorW, nEditorH
   local nFormX, nFormY, nInsTop, nEditorTop, nBottomY

   nScreenW := W32_GetScreenWidth()
   nScreenH := W32_GetScreenHeight()

   // C++Builder classic proportions scaled to current screen
   // Reference: 1024x768 -> Inspector 250px (24.4%), Bar 100px (13%)
   nBarH    := 140                           // title(23) + menu(20) + borders(8) + toolbar(36) + palette(52)
   nInsW    := Int( nScreenW * 0.18 )        // ~18% of screen width

   // === Window 1: Main Bar (full screen width) ===
   DEFINE FORM oIDE TITLE "hbcpp (GUI framework for Harbour)" ;
      SIZE nScreenW, nBarH FONT "Segoe UI", 9 APPBAR

   UI_FormSetPos( oIDE:hCpp, 0, 0 )
   oIDE:Show()

   // Inspector and editor: right below IDE window (3px overlap to close gap)
   nInsTop  := W32_GetWindowBottom( UI_FormGetHwnd( oIDE:hCpp ) ) - 3
   nEditorTop := nInsTop
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

   DEFINE POPUP oSearch PROMPT "&Search" OF oIDE
   MENUITEM "&Find..."      OF oSearch ACTION MsgInfo( "Find" )
   MENUITEM "&Replace..."   OF oSearch ACTION MsgInfo( "Replace" )

   DEFINE POPUP oView PROMPT "&View" OF oIDE
   MENUITEM "&Inspector"    OF oView ACTION InspectorOpen()
   MENUITEM "&Object Tree"  OF oView ACTION MsgInfo( "Object Tree" )

   DEFINE POPUP oProject PROMPT "&Project" OF oIDE
   MENUITEM "&Add to Project..."    OF oProject ACTION MsgInfo( "Add to Project" )
   MENUITEM "&Remove from Project"  OF oProject ACTION MsgInfo( "Remove" )
   MENUSEPARATOR OF oProject
   MENUITEM "&Options..."           OF oProject ACTION MsgInfo( "Project Options" )

   DEFINE POPUP oRun PROMPT "&Run" OF oIDE
   MENUITEM "&Run"           OF oRun ACTION MsgInfo( "Run" )
   MENUITEM "&Step Over"     OF oRun ACTION MsgInfo( "Step Over" )
   MENUITEM "Step &Into"     OF oRun ACTION MsgInfo( "Step Into" )

   DEFINE POPUP oComp PROMPT "&Component" OF oIDE
   MENUITEM "&Install Component..." OF oComp ACTION MsgInfo( "Install" )
   MENUITEM "&New Component..."     OF oComp ACTION MsgInfo( "New Component" )

   DEFINE POPUP oTools PROMPT "&Tools" OF oIDE
   MENUITEM "&Environment Options..." OF oTools ACTION MsgInfo( "Options" )

   DEFINE POPUP oHelp PROMPT "&Help" OF oIDE
   MENUITEM "&About IDE..." OF oHelp ACTION ;
      MsgInfo( "IDE v0.1 - Cross-platform visual designer" )

   // Speedbar (toolbar with icon buttons)
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
   BUTTON "Run"   OF oTB TOOLTIP "Run project (F9)"      ACTION MsgInfo( "Run" )

   // Load toolbar icons (Silk icon set by famfamfam, CC BY 2.5)
   UI_ToolBarLoadImages( oTB:hCpp, "c:\ide\resources\toolbar.bmp" )

   // Component Palette (tabbed, right of splitter)
   CreatePalette()

   // === Window 4: Code Editor (background, right of inspector, full area) ===
   // Created FIRST so it appears BEHIND the form
   hCodeEditor := CodeEditorCreate( nEditorX, nEditorTop, nEditorW, nEditorH )
   CodeEditorSetText( hCodeEditor, GenerateSampleCode() )

   // === Window 3: Form Designer (floating on top of editor) ===
   CreateDesignForm( nFormX, nFormY )
   oDesignForm:SetDesign( .t. )
   oDesignForm:Show()

   // Ensure form is visually above the editor
   W32_BringToTop( UI_FormGetHwnd( oDesignForm:hCpp ) )

   // === Window 2: Object Inspector (left column, below bar) ===
   InspectorOpen()
   InspectorRefresh( oDesignForm:hCpp )
   InspectorPopulateCombo( oDesignForm:hCpp )

   INS_SetOnComboSel( _InsGetData(), { |nSel| OnComboSelect( nSel ) } )
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

   // Standard tab
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

static function CreateDesignForm( nX, nY )

   local oCbx, oChk, oBtn, oEdit

   // C++Builder default form: 400x340 (extra height for Win32 title bar + borders)
   DEFINE FORM oDesignForm TITLE "Form1" SIZE 400, 340 FONT "Segoe UI", 9

   UI_FormSetPos( oDesignForm:hCpp, nX, nY )

   // Sample controls
   @ 13, 12 GROUPBOX "General" OF oDesignForm SIZE 370, 100

   @ 36, 26 SAY "Name:" OF oDesignForm SIZE 60
   @ 34, 100 GET oEdit VAR "John Doe" OF oDesignForm SIZE 200, 26

   @ 67, 26 SAY "City:" OF oDesignForm SIZE 60
   @ 65, 100 GET oEdit VAR "Madrid" OF oDesignForm SIZE 200, 26

   @ 125, 12 GROUPBOX "Options" OF oDesignForm SIZE 370, 80

   @ 147, 30 CHECKBOX oChk PROMPT "Active" OF oDesignForm SIZE 120 CHECKED
   @ 147, 180 CHECKBOX oChk PROMPT "Admin" OF oDesignForm SIZE 120

   @ 175, 30 SAY "Role:" OF oDesignForm SIZE 50
   @ 173, 100 COMBOBOX oCbx OF oDesignForm ITEMS { "User", "Manager", "Admin" } SIZE 150
   oCbx:Value := 0

   @ 240, 120 BUTTON oBtn PROMPT "&OK" OF oDesignForm SIZE 88, 26
   @ 240, 220 BUTTON oBtn PROMPT "&Cancel" OF oDesignForm SIZE 88, 26

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

   local cCode := ""

   cCode += '// Form1.prg - Generated code' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '#include "commands.ch"' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += 'function Main()' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   local oForm, oBtn' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   DEFINE FORM oForm TITLE "Form1" ;' + Chr(13) + Chr(10)
   cCode += '      SIZE 400, 340 FONT "Segoe UI", 9' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   @ 13, 12 GROUPBOX "General" OF oForm ;' + Chr(13) + Chr(10)
   cCode += '      SIZE 370, 100' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   @ 36, 26 SAY "Name:" OF oForm SIZE 60' + Chr(13) + Chr(10)
   cCode += '   @ 34, 100 GET oEdit VAR "" OF oForm ;' + Chr(13) + Chr(10)
   cCode += '      SIZE 200, 26' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   @ 240, 120 BUTTON oBtn PROMPT "&OK" ;' + Chr(13) + Chr(10)
   cCode += '      OF oForm SIZE 88, 26' + Chr(13) + Chr(10)
   cCode += '   oBtn:OnClick := { || oForm:Close() }' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   ACTIVATE FORM oForm CENTERED' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += 'return nil' + Chr(13) + Chr(10)

return cCode

static function MsgInfo( cText )

   W32_MsgBox( cText, "IDE" )

return nil

// Framework
#include "../harbour/classes.prg"
#include "../harbour/inspector.prg"

#pragma BEGINDUMP
#include <hbapi.h>
#include <windows.h>
#include <commctrl.h>
#include <richedit.h>
#include <ctype.h>

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

/* ======================================================================
 * Code Editor - RichEdit with syntax highlighting
 * ====================================================================== */

#define GUTTER_WIDTH 45

typedef struct {
   HWND hWnd;       /* Tool window */
   HWND hEdit;      /* RichEdit control */
   HWND hGutter;    /* Line number gutter */
   HFONT hFont;     /* Monospace font */
   WNDPROC oldEditProc;  /* Original RichEdit WndProc */
} CODEEDITOR;

static void GutterPaint( CODEEDITOR * ed );
static void GutterSync( CODEEDITOR * ed );

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
   "PALETTE", "REQUEST",
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

   nLen = GetWindowTextLengthA( hEdit );
   if( nLen <= 0 ) return;

   buf = (char *) malloc( nLen + 1 );
   GetWindowTextA( hEdit, buf, nLen + 1 );

   /* Save selection, disable redraw */
   SendMessage( hEdit, EM_EXGETSEL, 0, (LPARAM) &crSave );
   SendMessage( hEdit, WM_SETREDRAW, FALSE, 0 );

   /* Reset all to light gray (default text on dark bg) */
   SetRichColor( hEdit, 0, nLen, RGB(212,212,212), FALSE );

   i = 0;
   while( i < nLen )
   {
      /* Line comments: // */
      if( buf[i] == '/' && i + 1 < nLen && buf[i+1] == '/' )
      {
         int start = i;
         while( i < nLen && buf[i] != '\r' && buf[i] != '\n' ) i++;
         SetRichColor( hEdit, start, i, RGB(106,153,85), FALSE );
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

      /* Words: keywords and commands */
      if( IsWordChar(buf[i]) )
      {
         ws = i;
         while( i < nLen && IsWordChar(buf[i]) ) i++;
         if( IsKeyword( buf + ws, i - ws ) )
            SetRichColor( hEdit, ws, i, RGB(86,156,214), TRUE );
         else if( IsCommand( buf + ws, i - ws ) )
            SetRichColor( hEdit, ws, i, RGB(78,201,176), FALSE );
         continue;
      }

      i++;
   }

   /* Restore selection and redraw */
   SendMessage( hEdit, EM_EXSETSEL, 0, (LPARAM) &crSave );
   SendMessage( hEdit, WM_SETREDRAW, TRUE, 0 );
   InvalidateRect( hEdit, NULL, TRUE );

   free( buf );
}

/* Gutter: paint line numbers */
static void GutterPaint( CODEEDITOR * ed )
{
   PAINTSTRUCT ps;
   HDC hDC;
   RECT rcGutter;
   int firstLine, lineCount, lineH, y, i;
   HFONT hOld;
   char szNum[16];

   if( !ed || !ed->hGutter || !ed->hEdit ) return;

   hDC = BeginPaint( ed->hGutter, &ps );
   GetClientRect( ed->hGutter, &rcGutter );

   /* Dark fill background */
   {
      HBRUSH hBr = CreateSolidBrush( RGB(37, 37, 38) );
      FillRect( hDC, &rcGutter, hBr );
      DeleteObject( hBr );
   }

   /* Right border line */
   {
      HPEN hPen = CreatePen( PS_SOLID, 1, RGB(60, 60, 60) );
      HPEN hOldPen = (HPEN) SelectObject( hDC, hPen );
      MoveToEx( hDC, rcGutter.right - 1, 0, NULL );
      LineTo( hDC, rcGutter.right - 1, rcGutter.bottom );
      SelectObject( hDC, hOldPen );
      DeleteObject( hPen );
   }

   hOld = (HFONT) SelectObject( hDC, ed->hFont );
   SetBkMode( hDC, TRANSPARENT );
   SetTextColor( hDC, RGB(133, 133, 133) );

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
   for( i = firstLine; i < lineCount && y < rcGutter.bottom; i++ )
   {
      RECT rcNum;
      sprintf( szNum, "%d", i + 1 );
      rcNum.left = 2;
      rcNum.top = y;
      rcNum.right = GUTTER_WIDTH - 6;
      rcNum.bottom = y + lineH;
      DrawTextA( hDC, szNum, -1, &rcNum, DT_RIGHT | DT_SINGLELINE | DT_VCENTER );
      y += lineH;
   }

   SelectObject( hDC, hOld );
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
static LRESULT CALLBACK CodeEditSubProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   CODEEDITOR * ed = (CODEEDITOR *) GetPropA( hWnd, "CodeEd" );
   LRESULT r;

   if( !ed ) return DefWindowProc( hWnd, msg, wParam, lParam );

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
            if( ed->hGutter )
               MoveWindow( ed->hGutter, 0, 0, GUTTER_WIDTH, h, TRUE );
            if( ed->hEdit )
               MoveWindow( ed->hEdit, GUTTER_WIDTH, 0, w - GUTTER_WIDTH, h, TRUE );
         }
         return 0;
      }

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
   int nLeft = hb_parni(1), nTop = hb_parni(2);
   int nWidth = hb_parni(3), nHeight = hb_parni(4);

   /* Load RichEdit library */
   LoadLibraryA( "Msftedit.dll" );

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
      0, 0, GUTTER_WIDTH, nHeight,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   SetWindowLongPtr( ed->hGutter, GWLP_USERDATA, (LONG_PTR) ed );

   /* RichEdit control (to the right of gutter) */
   ed->hEdit = CreateWindowExA( 0, "RICHEDIT50W", "",
      WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
      ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_WANTRETURN | ES_NOHIDESEL,
      GUTTER_WIDTH, 0, nWidth - GUTTER_WIDTH, nHeight,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );

   /* If RICHEDIT50W fails, try RICHEDIT20A */
   if( !ed->hEdit )
   {
      LoadLibraryA( "Riched20.dll" );
      ed->hEdit = CreateWindowExA( 0, "RichEdit20A", "",
         WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
         ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_WANTRETURN | ES_NOHIDESEL,
         GUTTER_WIDTH, 0, nWidth - GUTTER_WIDTH, nHeight,
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

/* CodeEditorSetText( hEditor, cText ) - sets text and applies syntax highlighting */
HB_FUNC( CODEEDITORSETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit && HB_ISCHAR(2) )
   {
      SetWindowTextA( ed->hEdit, hb_parc(2) );
      HighlightCode( ed->hEdit );
   }
}

/* CodeEditorGetText( hEditor ) --> cText */
HB_FUNC( CODEEDITORGETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed && ed->hEdit )
   {
      int nLen = GetWindowTextLengthA( ed->hEdit );
      char * buf = (char *) malloc( nLen + 1 );
      GetWindowTextA( ed->hEdit, buf, nLen + 1 );
      hb_retclen( buf, nLen );
      free( buf );
   }
   else
      hb_retc( "" );
}

/* CodeEditorDestroy( hEditor ) */
HB_FUNC( CODEEDITORDESTROY )
{
   CODEEDITOR * ed = (CODEEDITOR *) (HB_PTRUINT) hb_parnint(1);
   if( ed )
   {
      if( ed->hWnd ) DestroyWindow( ed->hWnd );
      if( ed->hFont ) DeleteObject( ed->hFont );
      free( ed );
   }
}

#pragma ENDDUMP
