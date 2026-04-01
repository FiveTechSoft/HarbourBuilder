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
static hCodeEditor   // Code editor window (below design form)
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

   // === Window 4: Code Editor (below design form) ===
   hCodeEditor := CodeEditorCreate( 270, 540, 700, 300 )
   CodeEditorSetText( hCodeEditor, GenerateSampleCode() )

   // Show design form first (no message loop)
   oDesignForm:Show()

   // When IDE closes, destroy all secondary windows first
   oIDE:OnClose := { || InspectorClose(), oDesignForm:Destroy(), ;
                        CodeEditorDestroy( hCodeEditor ) }

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
   cCode += '      SIZE 470, 380 FONT "Segoe UI", 9' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   @ 13, 12 GROUPBOX "General" OF oForm ;' + Chr(13) + Chr(10)
   cCode += '      SIZE 430, 120' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   @ 40, 26 SAY "Name:" OF oForm SIZE 70' + Chr(13) + Chr(10)
   cCode += '   @ 38, 100 GET oEdit VAR "" OF oForm ;' + Chr(13) + Chr(10)
   cCode += '      SIZE 200, 26' + Chr(13) + Chr(10)
   cCode += '' + Chr(13) + Chr(10)
   cCode += '   @ 290, 150 BUTTON oBtn PROMPT "&OK" ;' + Chr(13) + Chr(10)
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
#include "c:\ide\harbour\classes.prg"
#include "c:\ide\harbour\inspector.prg"

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

/* ======================================================================
 * Code Editor - RichEdit with syntax highlighting
 * ====================================================================== */

typedef struct {
   HWND hWnd;     /* Tool window */
   HWND hEdit;    /* RichEdit control */
   HFONT hFont;   /* Monospace font */
} CODEEDITOR;

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

   /* Reset all to black */
   SetRichColor( hEdit, 0, nLen, RGB(0,0,0), FALSE );

   i = 0;
   while( i < nLen )
   {
      /* Line comments: // */
      if( buf[i] == '/' && i + 1 < nLen && buf[i+1] == '/' )
      {
         int start = i;
         while( i < nLen && buf[i] != '\r' && buf[i] != '\n' ) i++;
         SetRichColor( hEdit, start, i, RGB(0,128,0), FALSE );
         continue;
      }

      /* Block comments */
      if( buf[i] == '/' && i + 1 < nLen && buf[i+1] == '*' )
      {
         int start = i;
         i += 2;
         while( i + 1 < nLen && !( buf[i] == '*' && buf[i+1] == '/' ) ) i++;
         if( i + 1 < nLen ) i += 2;
         SetRichColor( hEdit, start, i, RGB(0,128,0), FALSE );
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
         SetRichColor( hEdit, start, i, RGB(163,21,21), FALSE );
         continue;
      }

      /* Preprocessor: #include, #define, #xcommand */
      if( buf[i] == '#' )
      {
         int start = i;
         i++;
         while( i < nLen && IsWordChar(buf[i]) ) i++;
         SetRichColor( hEdit, start, i, RGB(128,0,128), TRUE );
         continue;
      }

      /* Logical literals: .T. .F. .AND. .OR. .NOT. */
      if( buf[i] == '.' && i + 2 < nLen )
      {
         int start = i;
         i++;
         while( i < nLen && buf[i] != '.' && IsWordChar(buf[i]) ) i++;
         if( i < nLen && buf[i] == '.' ) { i++; SetRichColor( hEdit, start, i, RGB(128,0,128), FALSE ); }
         continue;
      }

      /* Words: keywords and commands */
      if( IsWordChar(buf[i]) )
      {
         ws = i;
         while( i < nLen && IsWordChar(buf[i]) ) i++;
         if( IsKeyword( buf + ws, i - ws ) )
            SetRichColor( hEdit, ws, i, RGB(0,0,180), TRUE );
         else if( IsCommand( buf + ws, i - ws ) )
            SetRichColor( hEdit, ws, i, RGB(0,0,180), FALSE );
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

static LRESULT CALLBACK CodeEdWndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
   CODEEDITOR * ed = (CODEEDITOR *) GetWindowLongPtr( hWnd, GWLP_USERDATA );

   switch( msg )
   {
      case WM_SIZE:
      {
         int w = LOWORD(lParam), h = HIWORD(lParam);
         if( ed && ed->hEdit )
            MoveWindow( ed->hEdit, 0, 0, w, h, TRUE );
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

   /* Monospace font */
   {
      LOGFONTA lf = {0};
      hDC = GetDC( NULL );
      lf.lfHeight = -MulDiv( 11, GetDeviceCaps( hDC, LOGPIXELSY ), 72 );
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

   /* RichEdit control */
   ed->hEdit = CreateWindowExA( 0, "RICHEDIT50W", "",
      WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
      ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_WANTRETURN | ES_NOHIDESEL,
      0, 0, nWidth, nHeight,
      ed->hWnd, NULL, GetModuleHandle(NULL), NULL );

   /* If RICHEDIT50W fails, try RICHEDIT20A */
   if( !ed->hEdit )
   {
      LoadLibraryA( "Riched20.dll" );
      ed->hEdit = CreateWindowExA( 0, "RichEdit20A", "",
         WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
         ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL | ES_WANTRETURN | ES_NOHIDESEL,
         0, 0, nWidth, nHeight,
         ed->hWnd, NULL, GetModuleHandle(NULL), NULL );
   }

   if( ed->hEdit )
   {
      /* Set default font via CHARFORMAT */
      cf.cbSize = sizeof(cf);
      cf.dwMask = CFM_FACE | CFM_SIZE | CFM_COLOR;
      cf.yHeight = 11 * 20;  /* 11pt in twips (1pt = 20 twips) */
      cf.crTextColor = RGB(0,0,0);
      lstrcpyA( cf.szFaceName, "Consolas" );
      SendMessageA( ed->hEdit, EM_SETCHARFORMAT, SCF_ALL, (LPARAM) &cf );

      /* White background */
      SendMessage( ed->hEdit, EM_SETBKGNDCOLOR, 0, (LPARAM) RGB(255,255,255) );

      /* Enable ENM_CHANGE for future auto-highlight */
      SendMessage( ed->hEdit, EM_SETEVENTMASK, 0, ENM_CHANGE );
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
