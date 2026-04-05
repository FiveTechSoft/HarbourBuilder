/* ======================================================================
 * cocoa_editor.mm — Scintilla-based Code Editor for HbBuilder (macOS)
 *
 * Replaces the previous NSTextView-based editor with Scintilla 5.5.3 +
 * Lexilla (C++ lexer) — the same editing component used by Notepad++,
 * SciTE, Code::Blocks, and many professional IDEs.
 *
 * FEATURES (automatic via Scintilla):
 *   - Syntax highlighting (C++ lexer with Harbour keywords)
 *   - Line numbers with dark gutter
 *   - Code folding with box-style markers
 *   - Indentation guides
 *   - UTF-8 support
 *   - Auto-complete popup (Harbour keywords + functions)
 *   - Built-in find/replace
 *   - Undo/redo
 * ====================================================================== */

#import <Cocoa/Cocoa.h>
#import "ScintillaView.h"
#include "Scintilla.h"
#include "SciLexer.h"
#include "ILexer.h"

/* Harbour VM headers */
#include "hbapi.h"
#include "hbapiitm.h"
#include "hbvm.h"
#include "hbapidbg.h"
#include "hbapierr.h"

/* Lexilla CreateLexer (linked statically from liblexilla.a) */
extern "C" Scintilla::ILexer5 * CreateLexer(const char *name);

/* -----------------------------------------------------------------------
 * Helpers
 * ----------------------------------------------------------------------- */

static sptr_t SciMsg( ScintillaView * sv, unsigned int msg, uptr_t wParam, sptr_t lParam )
{
   return [sv message:msg wParam:wParam lParam:lParam];
}

static sptr_t SciMsg0( ScintillaView * sv, unsigned int msg )
{
   return [sv message:msg wParam:0 lParam:0];
}

static sptr_t SCIRGB( int r, int g, int b )
{
   return r | (g << 8) | (b << 16);
}

/* -----------------------------------------------------------------------
 * CODEEDITOR struct
 * ----------------------------------------------------------------------- */

#define CE_MAX_TABS 16

typedef struct {
   NSWindow *       window;
   ScintillaView *  sciView;
   NSSegmentedControl * tabBar;
   NSTextField *    statusBar;        /* Ln/Col/INS status label */
   NSTableView *    msgTable;         /* Messages/errors table */
   NSView *         msgPanel;         /* Messages panel container */
   NSMutableArray * msgData;          /* Array of [file, line, col, type, text] */
   char           tabNames[CE_MAX_TABS][64];
   char *         tabTexts[CE_MAX_TABS];
   int            nTabs;
   int            nActiveTab;
   PHB_ITEM       pOnTabChange;
} CODEEDITOR;

/* Forward declarations for messages panel (defined at end of file) */
static CODEEDITOR * s_msgEditor = nil;

/* -----------------------------------------------------------------------
 * Harbour-aware code folding
 * Sets fold levels for function/procedure/method/class/if/for/while/switch
 * ----------------------------------------------------------------------- */

static int CE_LineStartsWithCI( const char * line, int lineLen, const char * word )
{
   int i = 0;
   int wLen = (int)strlen(word);
   /* Skip leading whitespace */
   while( i < lineLen && (line[i] == ' ' || line[i] == '\t') ) i++;
   if( i + wLen > lineLen ) return 0;
   if( strncasecmp( line + i, word, wLen ) != 0 ) return 0;
   /* Must be followed by non-identifier char */
   if( i + wLen < lineLen ) {
      char c = line[i + wLen];
      if( (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_' || (c >= '0' && c <= '9') )
         return 0;
   }
   return 1;
}

static void CE_UpdateHarbourFolding( ScintillaView * sv )
{
   sptr_t lineCount = SciMsg0( sv, SCI_GETLINECOUNT );
   int level = SC_FOLDLEVELBASE;

   for( sptr_t i = 0; i < lineCount; i++ )
   {
      sptr_t lineLen = SciMsg( sv, SCI_LINELENGTH, (uptr_t)i, 0 );
      int curLevel = level;
      int nextLevel = level;
      int isHeader = 0;

      if( lineLen > 0 && lineLen < 4096 )
      {
         char * buf = (char *) malloc( (size_t)lineLen + 1 );
         SciMsg( sv, SCI_GETLINE, (uptr_t)i, (sptr_t) buf );
         buf[lineLen] = 0;

         /* Trim trailing CR/LF */
         while( lineLen > 0 && (buf[lineLen-1] == '\r' || buf[lineLen-1] == '\n') )
            buf[--lineLen] = 0;

         int ll = (int)lineLen;

         /* Fold openers */
         if( CE_LineStartsWithCI(buf, ll, "function") ||
             CE_LineStartsWithCI(buf, ll, "procedure") ||
             CE_LineStartsWithCI(buf, ll, "method") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "class") &&
                  !CE_LineStartsWithCI(buf, ll, "endclass") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "if") &&
                  !CE_LineStartsWithCI(buf, ll, "endif") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "do") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "for") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "switch") &&
                  !CE_LineStartsWithCI(buf, ll, "endswitch") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "begin") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "while") &&
                  !CE_LineStartsWithCI(buf, ll, "enddo") )
         { isHeader = 1; nextLevel = level + 1; }
         else if( CE_LineStartsWithCI(buf, ll, "#pragma begindump") )
         { isHeader = 1; nextLevel = level + 1; }

         /* Fold closers */
         else if( CE_LineStartsWithCI(buf, ll, "return") ||
                  CE_LineStartsWithCI(buf, ll, "endclass") ||
                  CE_LineStartsWithCI(buf, ll, "endif") ||
                  CE_LineStartsWithCI(buf, ll, "enddo") ||
                  CE_LineStartsWithCI(buf, ll, "next") ||
                  CE_LineStartsWithCI(buf, ll, "endswitch") ||
                  CE_LineStartsWithCI(buf, ll, "endcase") ||
                  CE_LineStartsWithCI(buf, ll, "end") ||
                  CE_LineStartsWithCI(buf, ll, "#pragma enddump") )
         {
            if( level > SC_FOLDLEVELBASE )
            { curLevel = level - 1; nextLevel = level - 1; }
         }

         free( buf );
      }

      SciMsg( sv, SCI_SETFOLDLEVEL, (uptr_t)i,
         curLevel | (isHeader ? SC_FOLDLEVELHEADERFLAG : 0) );
      level = nextLevel;
   }
}

/* -----------------------------------------------------------------------
 * Status bar update — Ln X, Col Y | INS | Lines: N | UTF-8
 * ----------------------------------------------------------------------- */

static void CE_UpdateStatusBar( CODEEDITOR * ed )
{
   if( !ed || !ed->sciView || !ed->statusBar ) return;

   sptr_t pos  = SciMsg0( ed->sciView, SCI_GETCURRENTPOS );
   sptr_t line = SciMsg( ed->sciView, SCI_LINEFROMPOSITION, (uptr_t)pos, 0 ) + 1;
   sptr_t col  = SciMsg( ed->sciView, SCI_GETCOLUMN, (uptr_t)pos, 0 ) + 1;
   sptr_t lines = SciMsg0( ed->sciView, SCI_GETLINECOUNT );
   sptr_t chars = SciMsg0( ed->sciView, SCI_GETLENGTH );
   BOOL ovr = SciMsg0( ed->sciView, SCI_GETOVERTYPE ) != 0;

   NSString * text = [NSString stringWithFormat:@"  Ln %ld, Col %ld  |  %s  |  Lines: %ld  |  Chars: %ld  |  UTF-8",
      (long)line, (long)col, ovr ? "OVR" : "INS", (long)lines, (long)chars];
   [ed->statusBar setStringValue:text];
}

/* -----------------------------------------------------------------------
 * Configure Scintilla: lexer, keywords, colours, margins, folding
 * ----------------------------------------------------------------------- */

static void CE_ConfigureScintilla( ScintillaView * sv )
{
   /* UTF-8 */
   SciMsg( sv, SCI_SETCODEPAGE, SC_CP_UTF8, 0 );

   /* Tab width */
   SciMsg( sv, SCI_SETTABWIDTH, 3, 0 );

   /* Set C/C++ lexer via Lexilla (works for Harbour) */
   Scintilla::ILexer5 * pLexer = CreateLexer( "cpp" );
   if( pLexer )
      SciMsg( sv, SCI_SETILEXER, 0, (sptr_t) pLexer );

   /* Default style: Menlo 15pt, light gray on dark */
   SciMsg( sv, SCI_STYLESETFONT, STYLE_DEFAULT, (sptr_t) "Menlo" );
   SciMsg( sv, SCI_STYLESETSIZE, STYLE_DEFAULT, 15 );
   SciMsg( sv, SCI_STYLESETFORE, STYLE_DEFAULT, SCIRGB(212,212,212) );
   SciMsg( sv, SCI_STYLESETBACK, STYLE_DEFAULT, SCIRGB(30,30,30) );
   SciMsg( sv, SCI_STYLECLEARALL, 0, 0 );

   /* Line number margin */
   SciMsg( sv, SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER );
   SciMsg( sv, SCI_SETMARGINWIDTHN, 0, 48 );
   SciMsg( sv, SCI_STYLESETFORE, STYLE_LINENUMBER, SCIRGB(133,133,133) );
   SciMsg( sv, SCI_STYLESETBACK, STYLE_LINENUMBER, SCIRGB(37,37,38) );

   /* Folding margin — dark background matching editor */
   SciMsg( sv, SCI_SETMARGINTYPEN, 2, SC_MARGIN_SYMBOL );
   SciMsg( sv, SCI_SETMARGINMASKN, 2, SC_MASK_FOLDERS );
   SciMsg( sv, SCI_SETMARGINWIDTHN, 2, 16 );
   SciMsg( sv, SCI_SETMARGINSENSITIVEN, 2, 1 );
   SciMsg( sv, SCI_SETFOLDMARGINCOLOUR, 1, SCIRGB(37,37,38) );
   SciMsg( sv, SCI_SETFOLDMARGINHICOLOUR, 1, SCIRGB(37,37,38) );
   SciMsg( sv, SCI_SETAUTOMATICFOLD,
           SC_AUTOMATICFOLD_SHOW | SC_AUTOMATICFOLD_CLICK | SC_AUTOMATICFOLD_CHANGE, 0 );

   /* Fold markers — box style */
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDER,        SC_MARK_BOXPLUS );
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEROPEN,    SC_MARK_BOXMINUS );
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERSUB,     SC_MARK_VLINE );
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERTAIL,    SC_MARK_LCORNER );
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEREND,     SC_MARK_BOXPLUSCONNECTED );
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEROPENMID, SC_MARK_BOXMINUSCONNECTED );
   SciMsg( sv, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERMIDTAIL, SC_MARK_TCORNER );

   for( int m = 25; m <= 31; m++ ) {
      SciMsg( sv, 2041, m, SCIRGB(160,160,160) );  /* SCI_MARKERSETFORE */
      SciMsg( sv, 2042, m, SCIRGB(37,37,38) );     /* SCI_MARKERSETBACK */
   }

   /* Enable folding */
   SciMsg( sv, SCI_SETPROPERTY, (uptr_t) "fold",              (sptr_t) "1" );
   SciMsg( sv, SCI_SETPROPERTY, (uptr_t) "fold.compact",      (sptr_t) "0" );
   SciMsg( sv, SCI_SETPROPERTY, (uptr_t) "fold.comment",      (sptr_t) "1" );
   SciMsg( sv, SCI_SETPROPERTY, (uptr_t) "fold.preprocessor", (sptr_t) "1" );

   /* ===== Harbour keyword lists ===== */
   SciMsg( sv, SCI_SETKEYWORDS, 0, (sptr_t)
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

   SciMsg( sv, SCI_SETKEYWORDS, 1, (sptr_t)
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

   /* ===== Syntax highlighting colours ===== */
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_WORD,  SCIRGB(86,156,214) );
   SciMsg( sv, SCI_STYLESETBOLD, SCE_C_WORD,  1 );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_WORD2, SCIRGB(78,201,176) );

   SciMsg( sv, SCI_STYLESETFORE,   SCE_C_COMMENT,     SCIRGB(106,153,85) );
   SciMsg( sv, SCI_STYLESETFORE,   SCE_C_COMMENTLINE,  SCIRGB(106,153,85) );
   SciMsg( sv, SCI_STYLESETFORE,   SCE_C_COMMENTDOC,   SCIRGB(106,153,85) );
   SciMsg( sv, SCI_STYLESETITALIC, SCE_C_COMMENT,     1 );
   SciMsg( sv, SCI_STYLESETITALIC, SCE_C_COMMENTLINE,  1 );

   SciMsg( sv, SCI_STYLESETFORE, SCE_C_STRING,    SCIRGB(206,145,120) );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_CHARACTER,  SCIRGB(206,145,120) );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_NUMBER,     SCIRGB(181,206,168) );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_PREPROCESSOR, SCIRGB(197,134,192) );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_OPERATOR,   SCIRGB(212,212,212) );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_IDENTIFIER, SCIRGB(220,220,220) );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_GLOBALCLASS, SCIRGB(78,201,176) );

   /* Caret and selection */
   SciMsg( sv, SCI_SETCARETFORE, SCIRGB(255,255,255), 0 );
   SciMsg( sv, SCI_SETSELBACK, 1, SCIRGB(38,79,120) );

   /* Line spacing */
   SciMsg( sv, SCI_SETEXTRAASCENT, 1, 0 );
   SciMsg( sv, SCI_SETEXTRADESCENT, 1, 0 );

   /* Indentation guides */
   SciMsg( sv, SCI_SETINDENTATIONGUIDES, SC_IV_LOOKBOTH, 0 );

   /* Bracket matching style */
   SciMsg( sv, SCI_STYLESETFORE, STYLE_BRACELIGHT, SCIRGB(255,255,0) );
   SciMsg( sv, SCI_STYLESETBACK, STYLE_BRACELIGHT, SCIRGB(60,60,60) );
   SciMsg( sv, SCI_STYLESETBOLD, STYLE_BRACELIGHT, 1 );
   SciMsg( sv, SCI_STYLESETFORE, STYLE_BRACEBAD, SCIRGB(255,0,0) );
   SciMsg( sv, SCI_STYLESETBACK, STYLE_BRACEBAD, SCIRGB(60,30,30) );
   SciMsg( sv, SCI_STYLESETBOLD, STYLE_BRACEBAD, 1 );

   /* Error marker: red background for error lines (marker 10) */
   SciMsg( sv, SCI_MARKERDEFINE, 10, SC_MARK_BACKGROUND );
   SciMsg( sv, 2042, 10, SCIRGB(80,20,20) );  /* SCI_MARKERSETBACK: dark red bg */

   /* Bookmarks: markers 0-9 using circles in margin 1 */
   SciMsg( sv, SCI_SETMARGINTYPEN, 1, SC_MARGIN_SYMBOL );
   SciMsg( sv, SCI_SETMARGINWIDTHN, 1, 16 );
   SciMsg( sv, SCI_SETMARGINMASKN, 1, 0x3FF );  /* bits 0-9 */
   SciMsg( sv, SCI_SETMARGINSENSITIVEN, 1, 1 );
   for( int m = 0; m <= 9; m++ ) {
      SciMsg( sv, SCI_MARKERDEFINE, m, SC_MARK_SHORTARROW );
      SciMsg( sv, 2041, m, SCIRGB(80,180,255) );  /* SCI_MARKERSETFORE */
      SciMsg( sv, 2042, m, SCIRGB(40,40,50) );    /* SCI_MARKERSETBACK */
   }
}

/* -----------------------------------------------------------------------
 * Tab bar target
 * ----------------------------------------------------------------------- */

@interface HBSciTabTarget : NSObject
{
@public
   CODEEDITOR * ed;
}
- (void)tabChanged:(id)sender;
@end

@implementation HBSciTabTarget

- (void)tabChanged:(id)sender
{
   if( !ed || !ed->tabBar ) return;
   int newTab = (int)[ed->tabBar selectedSegment];
   if( newTab == ed->nActiveTab ) return;

   /* Save current tab */
   if( ed->nActiveTab >= 0 && ed->nActiveTab < ed->nTabs )
   {
      sptr_t len = SciMsg0( ed->sciView, SCI_GETLENGTH );
      char * buf = (char *) malloc( (size_t)len + 1 );
      SciMsg( ed->sciView, SCI_GETTEXT, (uptr_t)(len + 1), (sptr_t) buf );
      if( ed->tabTexts[ed->nActiveTab] ) free( ed->tabTexts[ed->nActiveTab] );
      ed->tabTexts[ed->nActiveTab] = buf;
   }

   ed->nActiveTab = newTab;

   const char * newText = ed->tabTexts[newTab] ? ed->tabTexts[newTab] : "";
   SciMsg( ed->sciView, SCI_SETTEXT, 0, (sptr_t) newText );
   SciMsg( ed->sciView, SCI_EMPTYUNDOBUFFER, 0, 0 );
   CE_UpdateHarbourFolding( ed->sciView );
   CE_UpdateStatusBar( ed );

   if( ed->pOnTabChange && HB_IS_BLOCK( ed->pOnTabChange ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( ed->pOnTabChange );
      hb_vmPushNumInt( (HB_PTRUINT) ed );
      hb_vmPushInteger( newTab + 1 );
      hb_vmSend( 2 );
   }
}

@end

static HBSciTabTarget * s_sciTabTarget = nil;

/* -----------------------------------------------------------------------
 * Scintilla notification delegate — auto-indent, fold click
 * ----------------------------------------------------------------------- */

@interface HBSciDelegate : NSObject <ScintillaNotificationProtocol>
{
@public
   CODEEDITOR * ed;
}
@end

@implementation HBSciDelegate

- (void)notification:(SCNotification *)scn
{
   if( !ed || !ed->sciView ) return;

   switch( scn->nmhdr.code )
   {
      case SCN_CHARADDED:
      {
         /* Auto-indent on Enter: copy previous line's indentation */
         if( scn->ch == '\n' || scn->ch == '\r' )
         {
            sptr_t pos = SciMsg0( ed->sciView, SCI_GETCURRENTPOS );
            sptr_t curLine = SciMsg( ed->sciView, SCI_LINEFROMPOSITION, (uptr_t)pos, 0 );
            if( curLine > 0 )
            {
               sptr_t prevIndent = SciMsg( ed->sciView, SCI_GETLINEINDENTATION,
                                           (uptr_t)(curLine - 1), 0 );
               SciMsg( ed->sciView, SCI_SETLINEINDENTATION, (uptr_t)curLine, prevIndent );
               sptr_t indentPos = SciMsg( ed->sciView, SCI_GETLINEINDENTPOSITION,
                                          (uptr_t)curLine, 0 );
               SciMsg( ed->sciView, SCI_GOTOPOS, (uptr_t)indentPos, 0 );
            }
         }
         break;
      }

      case SCN_MARGINCLICK:
      {
         /* Fold/unfold on margin click */
         if( scn->margin == 2 )
         {
            sptr_t line = SciMsg( ed->sciView, SCI_LINEFROMPOSITION,
                                  (uptr_t)scn->position, 0 );
            SciMsg( ed->sciView, SCI_TOGGLEFOLD, (uptr_t)line, 0 );
         }
         break;
      }

      case SCN_UPDATEUI:
      {
         /* Update status bar */
         CE_UpdateStatusBar( ed );

         /* Bracket matching */
         sptr_t pos = SciMsg0( ed->sciView, SCI_GETCURRENTPOS );
         char ch = (char) SciMsg( ed->sciView, SCI_GETCHARAT, (uptr_t)pos, 0 );
         char chPrev = pos > 0 ? (char) SciMsg( ed->sciView, SCI_GETCHARAT, (uptr_t)(pos-1), 0 ) : 0;

         sptr_t bracePos = -1;
         if( ch == '(' || ch == ')' || ch == '[' || ch == ']' || ch == '{' || ch == '}' )
            bracePos = pos;
         else if( chPrev == '(' || chPrev == ')' || chPrev == '[' || chPrev == ']' || chPrev == '{' || chPrev == '}' )
            bracePos = pos - 1;

         if( bracePos >= 0 )
         {
            sptr_t match = SciMsg( ed->sciView, SCI_BRACEMATCH, (uptr_t)bracePos, 0 );
            if( match >= 0 )
               SciMsg( ed->sciView, SCI_BRACEHIGHLIGHT, (uptr_t)bracePos, match );
            else
               SciMsg( ed->sciView, SCI_BRACEBADLIGHT, (uptr_t)bracePos, 0 );
         }
         else
         {
            SciMsg( ed->sciView, SCI_BRACEHIGHLIGHT, (uptr_t)-1, -1 );
         }
         break;
      }

      case SCN_MODIFIED:
      {
         /* Update Harbour folding when text changes */
         if( scn->modificationType & (SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT) )
            CE_UpdateHarbourFolding( ed->sciView );
         break;
      }
   }
}

@end

static HBSciDelegate * s_sciDelegate = nil;

/* -----------------------------------------------------------------------
 * Keyboard shortcut subclass — intercepts Cmd+/ Cmd+Shift+D/K Cmd+L Cmd+G
 * ----------------------------------------------------------------------- */

@interface HBSciKeyView : SCIContentView
@end

/* We can't subclass SCIContentView easily (it's internal).
 * Instead, use an NSEvent monitor installed when editor is created. */

/* Auto-complete word list (must be before key monitor that references it) */
static const char * s_harbourAutoComplete =
   "AAdd Access ACopy AClone ADel AEval AFill AIns Alert AllTrim Array "
   "AScan ASize ASort Assign ATail "
   "Begin Break Button "
   "Cancel Case Catch Chr Class ComboBox Continue CToD CurDir "
   "Data Date DateTime Default Define DToC DToS "
   "Else ElseIf Empty End EndCase EndClass EndDo EndIf EndSwitch "
   "Exit External "
   "Field File For Form Function "
   "GroupBox "
   "hb_HGet hb_HHasKey hb_HKeys hb_HNew hb_HSet hb_HValues "
   "hb_MemoRead hb_MemoWrit hb_MilliSeconds hb_ntos hb_NumToHex "
   "hb_threadStart hb_UTF8ToStr hb_ValToStr "
   "HB_ISARRAY HB_ISBLOCK HB_ISDATE HB_ISLOGICAL HB_ISNIL HB_ISNUMERIC HB_ISOBJECT HB_ISSTRING "
   "If In Init Inherit Inline Int "
   "Left Len Local Loop Lower LTrim "
   "Max MenuBar MenuItem MenuSeparator Method Min Mod Month MsgInfo MsgStop MsgYesNo "
   "Next Nil Not "
   "Of Or Otherwise "
   "PadC PadL PadR Palette Private Procedure Prompt Public "
   "Recover Redefine Replicate Request Return Right Round RTrim "
   "Say Self Separator Sequence Size Space Static Step Str SubStr Super Switch "
   "TApplication TButton TCheckBox TComboBox TEdit TForm TGroupBox "
   "Title TLabel TListBox TListView TMemo TPanel TProgressBar "
   "TRadioButton TTabControl TTimer TToolBar TTreeView "
   "To ToolBar Tooltip Transform Trim True Try "
   "Upper "
   "Val ValType Var "
   "While With "
   "Year";

static CODEEDITOR * s_keyMonitorEd = nil;
static id s_keyMonitor = nil;

static void CE_ToggleLineComment( ScintillaView * sv )
{
   sptr_t pos = SciMsg0( sv, SCI_GETCURRENTPOS );
   sptr_t line = SciMsg( sv, SCI_LINEFROMPOSITION, (uptr_t)pos, 0 );
   sptr_t lineStart = SciMsg( sv, SCI_POSITIONFROMLINE, (uptr_t)line, 0 );

   /* Get line text to check if already commented */
   sptr_t lineLen = SciMsg( sv, SCI_LINELENGTH, (uptr_t)line, 0 );
   char * buf = (char *) malloc( (size_t)lineLen + 1 );
   SciMsg( sv, SCI_GETLINE, (uptr_t)line, (sptr_t) buf );
   buf[lineLen] = 0;

   /* Skip leading whitespace */
   int ws = 0;
   while( buf[ws] == ' ' || buf[ws] == '\t' ) ws++;

   if( buf[ws] == '/' && buf[ws+1] == '/' && buf[ws+2] == ' ' )
   {
      /* Remove "// " */
      SciMsg( sv, SCI_SETTARGETSTART, (uptr_t)(lineStart + ws), 0 );
      SciMsg( sv, SCI_SETTARGETEND, (uptr_t)(lineStart + ws + 3), 0 );
      SciMsg( sv, SCI_REPLACETARGET, 0, (sptr_t) "" );
   }
   else if( buf[ws] == '/' && buf[ws+1] == '/' )
   {
      /* Remove "//" (no space) */
      SciMsg( sv, SCI_SETTARGETSTART, (uptr_t)(lineStart + ws), 0 );
      SciMsg( sv, SCI_SETTARGETEND, (uptr_t)(lineStart + ws + 2), 0 );
      SciMsg( sv, SCI_REPLACETARGET, 0, (sptr_t) "" );
   }
   else
   {
      /* Add "// " at start of content */
      SciMsg( sv, SCI_INSERTTEXT, (uptr_t)(lineStart + ws), (sptr_t) "// " );
   }

   free( buf );
}

static void CE_SelectLine( ScintillaView * sv )
{
   sptr_t pos = SciMsg0( sv, SCI_GETCURRENTPOS );
   sptr_t line = SciMsg( sv, SCI_LINEFROMPOSITION, (uptr_t)pos, 0 );
   sptr_t lineStart = SciMsg( sv, SCI_POSITIONFROMLINE, (uptr_t)line, 0 );
   sptr_t lineEnd = SciMsg( sv, SCI_GETLINEENDPOSITION, (uptr_t)line, 0 );
   SciMsg( sv, SCI_SETSEL, (uptr_t)lineStart, lineEnd );
}

static void CE_InstallKeyMonitor( CODEEDITOR * ed )
{
   s_keyMonitorEd = ed;
   if( s_keyMonitor ) return;  /* Already installed */

   s_keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
      handler:^NSEvent *(NSEvent * event)
   {
      if( !s_keyMonitorEd || !s_keyMonitorEd->sciView ) return event;

      /* Only handle when our editor window is key */
      if( [event window] != s_keyMonitorEd->window ) return event;

      NSUInteger flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
      BOOL cmd   = (flags & NSEventModifierFlagCommand) != 0;
      BOOL shift = (flags & NSEventModifierFlagShift) != 0;
      unsigned short keyCode = [event keyCode];
      ScintillaView * sv = s_keyMonitorEd->sciView;

      /* Cmd+/ (keyCode 44 = /) — Toggle line comment */
      if( cmd && !shift && keyCode == 44 )
      {
         CE_ToggleLineComment( sv );
         return nil;  /* Consumed */
      }

      /* Cmd+Shift+D (keyCode 2 = D) — Duplicate line */
      if( cmd && shift && keyCode == 2 )
      {
         SciMsg( sv, SCI_LINEDUPLICATE, 0, 0 );
         return nil;
      }

      /* Cmd+Shift+K (keyCode 40 = K) — Delete line */
      if( cmd && shift && keyCode == 40 )
      {
         SciMsg( sv, SCI_LINEDELETE, 0, 0 );
         return nil;
      }

      /* Cmd+L (keyCode 37 = L) — Select line */
      if( cmd && !shift && keyCode == 37 )
      {
         CE_SelectLine( sv );
         return nil;
      }

      /* Cmd+G (keyCode 5 = G) — Go to line (prompt via panel) */
      if( cmd && !shift && keyCode == 5 )
      {
         /* Simple goto: use Scintilla's goto line */
         sptr_t lineCount = SciMsg0( sv, SCI_GETLINECOUNT );

         /* Show input dialog */
         NSAlert * alert = [[NSAlert alloc] init];
         [alert setMessageText:@"Go to Line"];
         [alert setInformativeText:[NSString stringWithFormat:@"Line number (1-%ld):",
                                    (long)lineCount]];
         [alert addButtonWithTitle:@"Go"];
         [alert addButtonWithTitle:@"Cancel"];

         NSTextField * input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
         [input setStringValue:@"1"];
         [alert setAccessoryView:input];

         if( [alert runModal] == NSAlertFirstButtonReturn )
         {
            int lineNum = [[input stringValue] intValue];
            if( lineNum >= 1 && lineNum <= (int)lineCount )
            {
               sptr_t pos = SciMsg( sv, SCI_POSITIONFROMLINE, (uptr_t)(lineNum - 1), 0 );
               SciMsg( sv, SCI_GOTOPOS, (uptr_t)pos, 0 );
               SciMsg( sv, SCI_SCROLLCARET, 0, 0 );
            }
         }
         return nil;
      }

      /* Cmd+Space — Auto-complete */
      if( cmd && !shift && keyCode == 49 )
      {
         sptr_t pos = SciMsg0( sv, SCI_GETCURRENTPOS );
         sptr_t wordStart = SciMsg( sv, SCI_WORDSTARTPOSITION, (uptr_t)pos, 1 );
         SciMsg( sv, SCI_AUTOCSETIGNORECASE, 1, 0 );
         SciMsg( sv, SCI_AUTOCSETSEPARATOR, ' ', 0 );
         SciMsg( sv, SCI_AUTOCSHOW, (uptr_t)(pos - wordStart),
                 (sptr_t) s_harbourAutoComplete );
         return nil;
      }

      /* Cmd+0..9 — Toggle bookmark / Cmd+Shift+0..9 — Go to bookmark */
      /* macOS keyCodes: 0=29, 1=18, 2=19, 3=20, 4=21, 5=23, 6=22, 7=26, 8=28, 9=25 */
      {
         static const unsigned short numKeyCodes[] = {29,18,19,20,21,23,22,26,28,25};
         for( int bm = 0; bm <= 9; bm++ )
         {
            if( cmd && keyCode == numKeyCodes[bm] )
            {
               sptr_t curLine = SciMsg( sv, SCI_LINEFROMPOSITION,
                  (uptr_t)SciMsg0( sv, SCI_GETCURRENTPOS ), 0 );

               if( shift )
               {
                  /* Cmd+Shift+N: go to bookmark N */
                  sptr_t found = SciMsg( sv, SCI_MARKERNEXT, 0, 1 << bm );
                  if( found >= 0 )
                  {
                     sptr_t pos = SciMsg( sv, SCI_POSITIONFROMLINE, (uptr_t)found, 0 );
                     SciMsg( sv, SCI_GOTOPOS, (uptr_t)pos, 0 );
                     SciMsg( sv, SCI_SCROLLCARET, 0, 0 );
                  }
               }
               else
               {
                  /* Cmd+N: toggle bookmark N on current line */
                  sptr_t mask = SciMsg( sv, SCI_MARKERGET, (uptr_t)curLine, 0 );
                  if( mask & (1 << bm) )
                     SciMsg( sv, SCI_MARKERDELETE, (uptr_t)curLine, bm );
                  else
                     SciMsg( sv, SCI_MARKERADD, (uptr_t)curLine, bm );
               }
               return nil;
            }
         }
      }

      /* Tab key (keyCode 48) — code snippet expansion */
      if( !cmd && !shift && keyCode == 48 )
      {
         /* Get word before cursor */
         sptr_t pos = SciMsg0( sv, SCI_GETCURRENTPOS );
         sptr_t wordStart = SciMsg( sv, SCI_WORDSTARTPOSITION, (uptr_t)pos, 1 );
         sptr_t wLen = pos - wordStart;

         if( wLen > 0 && wLen < 20 )
         {
            char word[20];
            struct Sci_TextRange tr;
            tr.chrg.cpMin = (long)wordStart;
            tr.chrg.cpMax = (long)pos;
            tr.lpstrText = word;
            SciMsg( sv, SCI_GETTEXTRANGE, 0, (sptr_t)&tr );
            word[wLen] = 0;

            /* Match snippet triggers */
            const char * snippet = NULL;
            int cursorOff = 0;  /* offset from start of insertion for cursor */

            if( strcasecmp(word, "forn") == 0 ) {
               snippet = "for i := 1 to 10\n   \nnext";
               cursorOff = 20;  /* after "   " */
            } else if( strcasecmp(word, "iff") == 0 ) {
               snippet = "if \n   \nendif";
               cursorOff = 3;
            } else if( strcasecmp(word, "cls") == 0 ) {
               snippet = "class TMyClass from TForm\n\n   data cName init \"\"\n\n   method New() constructor\n\nendclass\n\nmethod New() class TMyClass\n   ::Super:New()\nreturn self";
               cursorOff = 6;
            } else if( strcasecmp(word, "func") == 0 ) {
               snippet = "function MyFunction()\n\n   \n\nreturn nil";
               cursorOff = 9;
            } else if( strcasecmp(word, "proc") == 0 ) {
               snippet = "procedure MyProcedure()\n\n   \n\nreturn";
               cursorOff = 10;
            } else if( strcasecmp(word, "whil") == 0 ) {
               snippet = "do while .T.\n   \nenddo";
               cursorOff = 16;
            } else if( strcasecmp(word, "swit") == 0 ) {
               snippet = "switch \n   case 1\n      \n   otherwise\n      \nendswitch";
               cursorOff = 7;
            } else if( strcasecmp(word, "tryx") == 0 ) {
               snippet = "begin sequence\n   \nrecover using oErr\n   MsgInfo( oErr:Description )\nend sequence";
               cursorOff = 18;
            }

            if( snippet )
            {
               /* Replace trigger word with snippet */
               SciMsg( sv, SCI_SETSEL, (uptr_t)wordStart, pos );
               SciMsg( sv, SCI_REPLACESEL, 0, (sptr_t) snippet );
               /* Position cursor */
               SciMsg( sv, SCI_GOTOPOS, (uptr_t)(wordStart + cursorOff), 0 );
               return nil;
            }
         }
      }

      /* F12 (keyCode 111) — Go to definition */
      if( !cmd && !shift && keyCode == 111 )
      {
         /* Get word under cursor */
         sptr_t pos = SciMsg0( sv, SCI_GETCURRENTPOS );
         sptr_t wordStart = SciMsg( sv, SCI_WORDSTARTPOSITION, (uptr_t)pos, 1 );
         sptr_t wordEnd = SciMsg( sv, SCI_WORDENDPOSITION, (uptr_t)pos, 1 );
         sptr_t wLen = wordEnd - wordStart;

         if( wLen > 0 && wLen < 128 )
         {
            char word[128];
            struct Sci_TextRange tr;
            tr.chrg.cpMin = (long)wordStart;
            tr.chrg.cpMax = (long)wordEnd;
            tr.lpstrText = word;
            SciMsg( sv, SCI_GETTEXTRANGE, 0, (sptr_t)&tr );
            word[wLen] = 0;

            /* Search for "function word(", "procedure word(", "method word(",
               "class word", "#define word" */
            sptr_t docLen = SciMsg0( sv, SCI_GETLENGTH );
            char patterns[6][160];
            snprintf( patterns[0], 160, "function %s", word );
            snprintf( patterns[1], 160, "procedure %s", word );
            snprintf( patterns[2], 160, "method %s", word );
            snprintf( patterns[3], 160, "FUNCTION %s", word );
            snprintf( patterns[4], 160, "METHOD %s", word );
            snprintf( patterns[5], 160, "class %s", word );

            sptr_t found = -1;
            for( int p = 0; p < 6 && found < 0; p++ )
            {
               SciMsg( sv, SCI_SETTARGETSTART, 0, 0 );
               SciMsg( sv, SCI_SETTARGETEND, (uptr_t)docLen, 0 );
               SciMsg( sv, SCI_SETSEARCHFLAGS, SCFIND_NONE, 0 );
               found = SciMsg( sv, SCI_SEARCHINTARGET,
                               (uptr_t)strlen(patterns[p]), (sptr_t)patterns[p] );
            }

            if( found >= 0 )
            {
               SciMsg( sv, SCI_GOTOPOS, (uptr_t)found, 0 );
               SciMsg( sv, SCI_SCROLLCARET, 0, 0 );
               /* Select the found line */
               sptr_t line = SciMsg( sv, SCI_LINEFROMPOSITION, (uptr_t)found, 0 );
               sptr_t ls = SciMsg( sv, SCI_POSITIONFROMLINE, (uptr_t)line, 0 );
               sptr_t le = SciMsg( sv, SCI_GETLINEENDPOSITION, (uptr_t)line, 0 );
               SciMsg( sv, SCI_SETSEL, (uptr_t)ls, le );
            }
         }
         return nil;
      }

      return event;
   }];
}

/* -----------------------------------------------------------------------
 * HB_FUNC Bridge functions
 * ----------------------------------------------------------------------- */

extern "C" {

/* Ensure NSApp is initialised (defined in cocoa_core.m) */
extern void EnsureNSApp(void);

/* CodeEditorCreate( nLeft, nTop, nWidth, nHeight ) --> hEditor */
HB_FUNC( CODEEDITORCREATE )
{
   EnsureNSApp();

   int nLeft   = hb_parni(1);
   int nTop    = hb_parni(2);
   int nWidth  = hb_parni(3);
   int nHeight = hb_parni(4);

   CODEEDITOR * ed = (CODEEDITOR *) calloc( 1, sizeof(CODEEDITOR) );

   NSRect screenFrame = [[NSScreen mainScreen] frame];
   NSRect frame = NSMakeRect( nLeft, screenFrame.size.height - nTop - nHeight, nWidth, nHeight );
   ed->window = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
      backing:NSBackingStoreBuffered defer:NO];
   [ed->window setTitle:@"Code Editor"];
   [ed->window setReleasedWhenClosed:NO];
   [ed->window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * content = [ed->window contentView];
   NSRect contentBounds = [content bounds];
   CGFloat tabBarH = 32;

   /* Tab bar */
   ed->nTabs = 0;
   ed->nActiveTab = 0;
   ed->pOnTabChange = NULL;
   memset( ed->tabTexts, 0, sizeof(ed->tabTexts) );
   ed->tabBar = [NSSegmentedControl segmentedControlWithLabels:@[@"Project1.prg"]
      trackingMode:NSSegmentSwitchTrackingSelectOne target:nil action:nil];
   [ed->tabBar setSelectedSegment:0];
   [ed->tabBar setFrame:NSMakeRect( 0, contentBounds.size.height - tabBarH,
      contentBounds.size.width, tabBarH )];
   [ed->tabBar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
   [ed->tabBar setFont:[NSFont boldSystemFontOfSize:13]];
   [ed->tabBar setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
   strncpy( ed->tabNames[0], "Project1.prg", 63 );
   ed->tabTexts[0] = strdup( "" );
   ed->nTabs = 1;

   s_sciTabTarget = [[HBSciTabTarget alloc] init];
   s_sciTabTarget->ed = ed;
   [ed->tabBar setTarget:s_sciTabTarget];
   [ed->tabBar setAction:@selector(tabChanged:)];

   /* Status bar at bottom */
   CGFloat statusH = 22;
   ed->statusBar = [NSTextField labelWithString:@"  Ln 1, Col 1  |  INS  |  Lines: 0  |  UTF-8"];
   [ed->statusBar setFrame:NSMakeRect( 0, 0, contentBounds.size.width, statusH )];
   [ed->statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
   [ed->statusBar setFont:[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular]];
   [ed->statusBar setBackgroundColor:[NSColor colorWithCalibratedRed:0.14 green:0.14 blue:0.15 alpha:1]];
   [ed->statusBar setTextColor:[NSColor colorWithCalibratedRed:0.6 green:0.6 blue:0.6 alpha:1]];
   [ed->statusBar setDrawsBackground:YES];

   /* Messages panel (above status bar) — build errors, warnings */
   CGFloat msgH = 120;
   ed->msgData = [NSMutableArray array];

   NSScrollView * msgSV = [[NSScrollView alloc] initWithFrame:
      NSMakeRect( 0, statusH, contentBounds.size.width, msgH )];
   [msgSV setHasVerticalScroller:YES];
   [msgSV setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
   [msgSV setBorderType:NSBezelBorder];

   ed->msgTable = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, contentBounds.size.width, msgH)];
   NSString * msgCols[] = { @"File", @"Line", @"Type", @"Message" };
   CGFloat  msgWidths[] = { 120, 50, 60, 500 };
   for( int c = 0; c < 4; c++ ) {
      NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:msgCols[c]];
      [[col headerCell] setStringValue:msgCols[c]];
      [col setWidth:msgWidths[c]];
      [ed->msgTable addTableColumn:col];
   }
   [ed->msgTable setRowHeight:18];
   [ed->msgTable setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
   s_msgEditor = ed;
   /* Data source set lazily when first message is added (class defined later) */
   [msgSV setDocumentView:ed->msgTable];

   ed->msgPanel = msgSV;

   /* Scintilla view (between tab bar and messages panel) */
   CGFloat sciBottom = statusH + msgH;
   NSRect sciFrame = NSMakeRect( 0, sciBottom, contentBounds.size.width,
                                 contentBounds.size.height - tabBarH - sciBottom );
   ed->sciView = [[ScintillaView alloc] initWithFrame:sciFrame];
   [ed->sciView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

   CE_ConfigureScintilla( ed->sciView );

   /* Notification delegate for auto-indent, fold click, status bar */
   s_sciDelegate = [[HBSciDelegate alloc] init];
   s_sciDelegate->ed = ed;
   [ed->sciView setDelegate:s_sciDelegate];

   /* Keyboard shortcut monitor (Cmd+/ Cmd+Shift+D/K Cmd+L Cmd+G Cmd+Space) */
   CE_InstallKeyMonitor( ed );

   [content addSubview:ed->statusBar];
   [content addSubview:ed->msgPanel];
   [content addSubview:ed->sciView];
   [content addSubview:ed->tabBar positioned:NSWindowAbove relativeTo:nil];

   [ed->window orderFront:nil];

   hb_retnint( (HB_PTRUINT) ed );
}

/* CodeEditorSetText( hEditor, cText ) */
HB_FUNC( CODEEDITORSETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView && HB_ISCHAR(2) )
   {
      SciMsg( ed->sciView, SCI_SETTEXT, 0, (sptr_t) hb_parc(2) );
      SciMsg( ed->sciView, SCI_EMPTYUNDOBUFFER, 0, 0 );
      CE_UpdateHarbourFolding( ed->sciView );
      CE_UpdateStatusBar( ed );
   }
}

/* CodeEditorGetText( hEditor ) --> cText */
HB_FUNC( CODEEDITORGETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView )
   {
      sptr_t len = SciMsg0( ed->sciView, SCI_GETLENGTH );
      char * buf = (char *) malloc( (size_t)len + 1 );
      SciMsg( ed->sciView, SCI_GETTEXT, (uptr_t)(len + 1), (sptr_t) buf );
      hb_retclen( buf, (HB_SIZE)len );
      free( buf );
   }
   else
      hb_retc( "" );
}

/* CodeEditorAppendText( hEditor, cText [, nCursorOffset] ) */
HB_FUNC( CODEEDITORAPPENDTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView && HB_ISCHAR(2) )
   {
      const char * text = hb_parc(2);
      sptr_t len = SciMsg0( ed->sciView, SCI_GETLENGTH );
      SciMsg( ed->sciView, SCI_APPENDTEXT, (uptr_t)strlen(text), (sptr_t) text );

      sptr_t cursorPos = len + (sptr_t)strlen(text);
      if( HB_ISNUM(3) )
         cursorPos = len + (sptr_t)hb_parni(3);
      SciMsg( ed->sciView, SCI_GOTOPOS, (uptr_t)cursorPos, 0 );
      SciMsg( ed->sciView, SCI_SCROLLCARET, 0, 0 );
      [ed->window makeKeyAndOrderFront:nil];
   }
}

/* CodeEditorGetText2( hEditor ) --> cText (alias) */
HB_FUNC( CODEEDITORGETTEXT2 )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView )
   {
      sptr_t len = SciMsg0( ed->sciView, SCI_GETLENGTH );
      char * buf = (char *) malloc( (size_t)len + 1 );
      SciMsg( ed->sciView, SCI_GETTEXT, (uptr_t)(len + 1), (sptr_t) buf );
      hb_retclen( buf, (HB_SIZE)len );
      free( buf );
   }
   else
      hb_retc( "" );
}

/* CodeEditorGotoFunction( hEditor, cFuncName ) */
HB_FUNC( CODEEDITORGOTOFUNCTION )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView || !HB_ISCHAR(2) ) { hb_retl(0); return; }

   const char * funcName = hb_parc(2);
   sptr_t docLen = SciMsg0( ed->sciView, SCI_GETLENGTH );

   char patterns[4][128];
   snprintf( patterns[0], 128, "METHOD %s(", funcName );
   snprintf( patterns[1], 128, "function %s(", funcName );
   snprintf( patterns[2], 128, "METHOD %s (", funcName );
   snprintf( patterns[3], 128, "function %s (", funcName );

   sptr_t found = -1;
   for( int i = 0; i < 4 && found < 0; i++ )
   {
      SciMsg( ed->sciView, SCI_SETTARGETSTART, 0, 0 );
      SciMsg( ed->sciView, SCI_SETTARGETEND, (uptr_t)docLen, 0 );
      SciMsg( ed->sciView, SCI_SETSEARCHFLAGS, SCFIND_NONE, 0 );
      found = SciMsg( ed->sciView, SCI_SEARCHINTARGET,
                      (uptr_t)strlen(patterns[i]), (sptr_t) patterns[i] );
   }

   if( found >= 0 )
   {
      sptr_t line = SciMsg( ed->sciView, SCI_LINEFROMPOSITION, (uptr_t)found, 0 );
      sptr_t pos = SciMsg( ed->sciView, SCI_POSITIONFROMLINE, (uptr_t)(line + 2), 0 );
      pos += 3;  /* skip "   " indent */
      SciMsg( ed->sciView, SCI_GOTOPOS, (uptr_t)pos, 0 );
      SciMsg( ed->sciView, SCI_SCROLLCARET, 0, 0 );
      [ed->window makeKeyAndOrderFront:nil];
   }
   hb_retl( found >= 0 );
}

/* CodeEditorInsertAfter( hEditor, cSearchLine, cTextToInsert ) */
HB_FUNC( CODEEDITORINSERTAFTER )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView || !HB_ISCHAR(2) || !HB_ISCHAR(3) ) return;

   const char * search = hb_parc(2);
   const char * insert = hb_parc(3);
   sptr_t docLen = SciMsg0( ed->sciView, SCI_GETLENGTH );

   SciMsg( ed->sciView, SCI_SETTARGETSTART, 0, 0 );
   SciMsg( ed->sciView, SCI_SETTARGETEND, (uptr_t)docLen, 0 );
   SciMsg( ed->sciView, SCI_SETSEARCHFLAGS, SCFIND_NONE, 0 );
   sptr_t found = SciMsg( ed->sciView, SCI_SEARCHINTARGET,
                           (uptr_t)strlen(search), (sptr_t) search );

   if( found >= 0 )
   {
      sptr_t line = SciMsg( ed->sciView, SCI_LINEFROMPOSITION, (uptr_t)found, 0 );
      sptr_t nextLine = SciMsg( ed->sciView, SCI_POSITIONFROMLINE, (uptr_t)(line + 1), 0 );
      SciMsg( ed->sciView, SCI_INSERTTEXT, (uptr_t)nextLine, (sptr_t) insert );
   }
}

/* --- Tab management --- */

HB_FUNC( CODEEDITORADDTAB )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->tabBar || !HB_ISCHAR(2) || ed->nTabs >= CE_MAX_TABS )
   { hb_retni(0); return; }

   strncpy( ed->tabNames[ed->nTabs], hb_parc(2), 63 );
   ed->tabTexts[ed->nTabs] = strdup( "" );
   ed->nTabs++;

   [ed->tabBar setSegmentCount:ed->nTabs];
   for( int i = 0; i < ed->nTabs; i++ )
      [ed->tabBar setLabel:[NSString stringWithUTF8String:ed->tabNames[i]] forSegment:i];

   hb_retni( ed->nTabs );
}

HB_FUNC( CODEEDITORSETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;
   if( !ed || nTab < 0 || nTab >= ed->nTabs || !HB_ISCHAR(3) ) return;

   if( ed->tabTexts[nTab] ) free( ed->tabTexts[nTab] );
   ed->tabTexts[nTab] = strdup( hb_parc(3) );

   if( nTab == ed->nActiveTab && ed->sciView )
   {
      SciMsg( ed->sciView, SCI_SETTEXT, 0, (sptr_t) ed->tabTexts[nTab] );
      SciMsg( ed->sciView, SCI_EMPTYUNDOBUFFER, 0, 0 );
   }
}

HB_FUNC( CODEEDITORGETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;
   if( !ed || nTab < 0 || nTab >= ed->nTabs ) { hb_retc(""); return; }

   if( nTab == ed->nActiveTab && ed->sciView )
   {
      sptr_t len = SciMsg0( ed->sciView, SCI_GETLENGTH );
      char * buf = (char *) malloc( (size_t)len + 1 );
      SciMsg( ed->sciView, SCI_GETTEXT, (uptr_t)(len + 1), (sptr_t) buf );
      hb_retclen( buf, (HB_SIZE)len );
      free( buf );
   }
   else
      hb_retc( ed->tabTexts[nTab] ? ed->tabTexts[nTab] : "" );
}

HB_FUNC( CODEEDITORSELECTTAB )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;
   if( !ed || !ed->tabBar || nTab < 0 || nTab >= ed->nTabs ) return;

   /* Save current tab */
   if( ed->nActiveTab >= 0 && ed->nActiveTab < ed->nTabs && ed->sciView )
   {
      sptr_t len = SciMsg0( ed->sciView, SCI_GETLENGTH );
      char * buf = (char *) malloc( (size_t)len + 1 );
      SciMsg( ed->sciView, SCI_GETTEXT, (uptr_t)(len + 1), (sptr_t) buf );
      if( ed->tabTexts[ed->nActiveTab] ) free( ed->tabTexts[ed->nActiveTab] );
      ed->tabTexts[ed->nActiveTab] = buf;
   }

   ed->nActiveTab = nTab;
   [ed->tabBar setSelectedSegment:nTab];

   const char * newText = ed->tabTexts[nTab] ? ed->tabTexts[nTab] : "";
   SciMsg( ed->sciView, SCI_SETTEXT, 0, (sptr_t) newText );
   SciMsg( ed->sciView, SCI_EMPTYUNDOBUFFER, 0, 0 );
   SciMsg( ed->sciView, SCI_GOTOPOS, 0, 0 );
}

HB_FUNC( CODEEDITORCLEARTABS )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed ) return;

   for( int i = 1; i < ed->nTabs; i++ )
   {
      if( ed->tabTexts[i] ) { free( ed->tabTexts[i] ); ed->tabTexts[i] = NULL; }
      ed->tabNames[i][0] = 0;
   }
   ed->nTabs = 1;
   ed->nActiveTab = 0;
   [ed->tabBar setSegmentCount:1];
}

HB_FUNC( CODEEDITORONTABCHANGE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( ed )
   {
      if( ed->pOnTabChange ) hb_itemRelease( ed->pOnTabChange );
      ed->pOnTabChange = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

HB_FUNC( CODEEDITORBRINGTOFRONT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->window ) {
      [ed->window makeKeyAndOrderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
   }
}

HB_FUNC( CODEEDITORDESTROY )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed )
   {
      if( ed->window ) [ed->window close];
      for( int i = 0; i < ed->nTabs; i++ )
         if( ed->tabTexts[i] ) free( ed->tabTexts[i] );
      free( ed );
   }
}

/* --- Find Bar --- */

HB_FUNC( CODEEDITORSHOWFINDBAR )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView ) return;

   [ed->window makeKeyAndOrderFront:nil];

   /* Use ScintillaView's findAndHighlightText or NSTextFinder */
   BOOL showReplace = HB_ISLOG(2) ? hb_parl(2) : NO;
   NSInteger action = showReplace ? 12 : 1; /* NSTextFinderAction */
   NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:@"Find"
      action:@selector(performTextFinderAction:) keyEquivalent:@""];
   [item setTag:action];

   /* Try the content view first (SCIContentView handles text input) */
   SCIContentView * contentView = [ed->sciView content];
   if( [contentView respondsToSelector:@selector(performTextFinderAction:)] )
      [contentView performTextFinderAction:item];
}

HB_FUNC( CODEEDITORFINDNEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->window ) [ed->window makeKeyAndOrderFront:nil];
}

HB_FUNC( CODEEDITORFINDPREV )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->window ) [ed->window makeKeyAndOrderFront:nil];
}

/* --- Auto-Complete --- */

HB_FUNC( CODEEDITORAUTOCOMPLETE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView ) return;

   [ed->window makeKeyAndOrderFront:nil];

   sptr_t pos = SciMsg0( ed->sciView, SCI_GETCURRENTPOS );
   sptr_t wordStart = SciMsg( ed->sciView, SCI_WORDSTARTPOSITION, (uptr_t)pos, 1 );
   sptr_t wordLen = pos - wordStart;

   SciMsg( ed->sciView, SCI_AUTOCSETIGNORECASE, 1, 0 );
   SciMsg( ed->sciView, SCI_AUTOCSETSEPARATOR, ' ', 0 );
   SciMsg( ed->sciView, SCI_AUTOCSHOW, (uptr_t)wordLen, (sptr_t) s_harbourAutoComplete );
}

/* --- Dark Mode --- */

HB_FUNC( MAC_SETAPPDARKMODE )
{
   BOOL dark = HB_ISLOG(1) ? hb_parl(1) : YES;
   NSString * name = dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua;
   [NSApp setAppearance:[NSAppearance appearanceNamed:name]];
}

HB_FUNC( MAC_SETALLDARKMODE )
{
   BOOL dark = HB_ISLOG(1) ? hb_parl(1) : YES;
   NSString * name = dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua;
   for( NSWindow * win in [NSApp windows] )
      [win setAppearance:[NSAppearance appearanceNamed:name]];
}

HB_FUNC( MAC_SETDARKMODE )
{
   /* Not used with Scintilla editor — dark mode is set app-wide */
   (void) hb_parnint(1);
   (void) hb_parl(2);
}

/* -----------------------------------------------------------------------
 * Clipboard / Undo / Redo — Scintilla SCI_CUT/COPY/PASTE/UNDO/REDO
 * ----------------------------------------------------------------------- */

HB_FUNC( CODEEDITORUNDO )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView ) SciMsg( ed->sciView, SCI_UNDO, 0, 0 );
}

HB_FUNC( CODEEDITORREDO )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView ) SciMsg( ed->sciView, SCI_REDO, 0, 0 );
}

HB_FUNC( CODEEDITORCUT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView ) SciMsg( ed->sciView, SCI_CUT, 0, 0 );
}

HB_FUNC( CODEEDITORCOPY )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView ) SciMsg( ed->sciView, SCI_COPY, 0, 0 );
}

HB_FUNC( CODEEDITORPASTE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciView ) SciMsg( ed->sciView, SCI_PASTE, 0, 0 );
}

/* CodeEditorFind / CodeEditorReplace — aliases for ShowFindBar */
HB_FUNC( CODEEDITORFIND )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView ) return;
   [ed->window makeKeyAndOrderFront:nil];
   NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:@"Find"
      action:@selector(performTextFinderAction:) keyEquivalent:@""];
   [item setTag:1];
   SCIContentView * cv = [ed->sciView content];
   if( [cv respondsToSelector:@selector(performTextFinderAction:)] )
      [cv performTextFinderAction:item];
}

HB_FUNC( CODEEDITORREPLACE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView ) return;
   [ed->window makeKeyAndOrderFront:nil];
   NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:@"Replace"
      action:@selector(performTextFinderAction:) keyEquivalent:@""];
   [item setTag:12];
   SCIContentView * cv = [ed->sciView content];
   if( [cv respondsToSelector:@selector(performTextFinderAction:)] )
      [cv performTextFinderAction:item];
}

/* Debugger Panel — now implemented in the debugger section at end of file */

/* -----------------------------------------------------------------------
 * AI Assistant Panel — singleton floating window with Ollama chat
 * ----------------------------------------------------------------------- */

static NSWindow * s_aiPanel = nil;
static NSTextView * s_aiOutput = nil;
static NSTextField * s_aiInput = nil;
static NSPopUpButton * s_aiModelBtn = nil;

@interface HBAISendTarget : NSObject
- (void)sendMessage:(id)sender;
- (void)clearChat:(id)sender;
@end

@implementation HBAISendTarget

- (void)sendMessage:(id)sender
{
   NSString * prompt = [s_aiInput stringValue];
   if( [prompt length] == 0 ) return;

   NSString * model = [s_aiModelBtn titleOfSelectedItem];

   /* Append user message to chat */
   NSString * userMsg = [NSString stringWithFormat:@"\n> %@\n", prompt];
   [[[s_aiOutput textStorage] mutableString] appendString:userMsg];
   [s_aiInput setStringValue:@""];
   [s_aiOutput scrollRangeToVisible:NSMakeRange([[s_aiOutput textStorage] length], 0)];

   /* Call Ollama API asynchronously */
   dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSString * urlStr = @"http://localhost:11434/api/generate";
      NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
      [req setHTTPMethod:@"POST"];
      [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

      /* Escape prompt for JSON */
      NSString * escaped = [prompt stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
      escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
      escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

      NSString * body = [NSString stringWithFormat:
         @"{\"model\":\"%@\",\"prompt\":\"%@\",\"stream\":false}", model, escaped];
      [req setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
      [req setTimeoutInterval:60];

      NSURLResponse * response = nil;
      NSError * error = nil;
      NSData * data = [NSURLConnection sendSynchronousRequest:req
                       returningResponse:&response error:&error];

      dispatch_async( dispatch_get_main_queue(), ^{
         if( error || !data )
         {
            NSString * errMsg = [NSString stringWithFormat:@"\n[Error: %@]\n",
               error ? [error localizedDescription] : @"No data"];
            [[[s_aiOutput textStorage] mutableString] appendString:errMsg];
         }
         else
         {
            NSDictionary * json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString * reply = json[@"response"];
            if( reply )
               [[[s_aiOutput textStorage] mutableString] appendString:
                  [NSString stringWithFormat:@"\n%@\n", reply]];
            else
               [[[s_aiOutput textStorage] mutableString] appendString:@"\n[No response]\n"];
         }
         [s_aiOutput scrollRangeToVisible:NSMakeRange([[s_aiOutput textStorage] length], 0)];
      });
   });
}

- (void)clearChat:(id)sender
{
   [[s_aiOutput textStorage] replaceCharactersInRange:
      NSMakeRange(0, [[s_aiOutput textStorage] length]) withString:@"AI Assistant ready.\n"];
}

@end

static HBAISendTarget * s_aiTarget = nil;

/* MAC_AIAssistantPanel() */
HB_FUNC( MAC_AIASSISTANTPANEL )
{
   if( s_aiPanel )
   {
      [s_aiPanel makeKeyAndOrderFront:nil];
      return;
   }

   NSRect frame = NSMakeRect( 120, 150, 420, 550 );
   s_aiPanel = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_aiPanel setTitle:@"AI Assistant (Ollama)"];
   [s_aiPanel setReleasedWhenClosed:NO];
   [s_aiPanel setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_aiPanel contentView];
   CGFloat w = [cv bounds].size.width;
   CGFloat h = [cv bounds].size.height;

   /* Model selector */
   s_aiModelBtn = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(10, h-35, 200, 28) pullsDown:NO];
   NSArray * models = @[@"codellama", @"llama3", @"deepseek-coder", @"mistral", @"phi3", @"gemma2"];
   for( NSString * m in models ) [s_aiModelBtn addItemWithTitle:m];
   [s_aiModelBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
   [cv addSubview:s_aiModelBtn];

   /* Chat output */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 50, w-20, h-95)];
   [sv setHasVerticalScroller:YES];
   [sv setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   s_aiOutput = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, w-20, h-95)];
   [s_aiOutput setEditable:NO];
   [s_aiOutput setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
   [s_aiOutput setBackgroundColor:[NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1]];
   [s_aiOutput setTextColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1]];
   [[s_aiOutput textStorage] replaceCharactersInRange:NSMakeRange(0,0)
      withString:@"AI Assistant ready.\nConnect to Ollama at localhost:11434\n"];
   [sv setDocumentView:s_aiOutput];
   [cv addSubview:sv];

   /* Input + Send + Clear */
   s_aiInput = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 12, w-160, 28)];
   [s_aiInput setPlaceholderString:@"Ask a question..."];
   [s_aiInput setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
   [cv addSubview:s_aiInput];

   s_aiTarget = [[HBAISendTarget alloc] init];

   NSButton * sendBtn = [NSButton buttonWithTitle:@"Send" target:s_aiTarget action:@selector(sendMessage:)];
   [sendBtn setFrame:NSMakeRect(w-140, 12, 60, 28)];
   [sendBtn setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
   [cv addSubview:sendBtn];

   NSButton * clearBtn = [NSButton buttonWithTitle:@"Clear" target:s_aiTarget action:@selector(clearChat:)];
   [clearBtn setFrame:NSMakeRect(w-70, 12, 60, 28)];
   [clearBtn setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
   [cv addSubview:clearBtn];

   [s_aiPanel makeKeyAndOrderFront:nil];
}

/* -----------------------------------------------------------------------
 * Project Inspector — singleton floating window with tree view
 * ----------------------------------------------------------------------- */

static NSWindow * s_projInspector = nil;

/* MAC_ProjectInspector( aItems ) — array of strings, "  " prefix = child */
HB_FUNC( MAC_PROJECTINSPECTOR )
{
   if( s_projInspector )
   {
      [s_projInspector makeKeyAndOrderFront:nil];
      /* TODO: rebuild tree from new array */
      return;
   }

   NSRect frame = NSMakeRect( 80, 250, 260, 400 );
   s_projInspector = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_projInspector setTitle:@"Project Inspector"];
   [s_projInspector setReleasedWhenClosed:NO];
   [s_projInspector setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   /* Build outline view with items from Harbour array */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:
      [[s_projInspector contentView] bounds]];
   [sv setHasVerticalScroller:YES];
   [sv setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

   NSOutlineView * outline = [[NSOutlineView alloc] initWithFrame:[sv bounds]];
   NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
   [[col headerCell] setStringValue:@"Project"];
   [col setWidth:240];
   [outline addTableColumn:col];
   [outline setOutlineTableColumn:col];
   [outline setHeaderView:nil];  /* No header for tree view look */
   [outline setRowHeight:20];
   [sv setDocumentView:outline];

   [[s_projInspector contentView] addSubview:sv];

   /* Populate from Harbour array if provided */
   /* (For now, uses a static demo layout) */

   [s_projInspector makeKeyAndOrderFront:nil];
}

/* -----------------------------------------------------------------------
 * Git Panel (Source Control) — singleton floating window
 * ----------------------------------------------------------------------- */

/* Git panel */
static NSWindow     * s_gitPanel = nil;
static NSTextField  * s_gitBranchLbl = nil;
static NSTableView  * s_gitChangesTV = nil;
static NSTextView   * s_gitMsgEdit = nil;
static NSMutableArray * s_gitChanges = nil;  /* array of arrays: { status, filename } */

@interface HBGitChangesSource : NSObject <NSTableViewDataSource>
@end
@implementation HBGitChangesSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    return s_gitChanges ? (NSInteger)[s_gitChanges count] : 0;
}
- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    if( !s_gitChanges || row < 0 || row >= (NSInteger)[s_gitChanges count] ) return @"";
    NSArray * entry = [s_gitChanges objectAtIndex:row];
    if( [[col identifier] isEqualToString:@"status"] )
        return [entry count] > 0 ? [entry objectAtIndex:0] : @"";
    return [entry count] > 1 ? [entry objectAtIndex:1] : @"";
}
@end

static HBGitChangesSource * s_gitChangesDS = nil;

HB_FUNC( MAC_GITPANEL )
{
   if( s_gitPanel ) {
      [s_gitPanel makeKeyAndOrderFront:nil];
      return;
   }

   s_gitChanges = [[NSMutableArray alloc] init];
   s_gitChangesDS = [[HBGitChangesSource alloc] init];

   NSRect frame = NSMakeRect(80, 100, 380, 520);
   s_gitPanel = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_gitPanel setTitle:@"Source Control"];
   [s_gitPanel setReleasedWhenClosed:NO];
   [s_gitPanel setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_gitPanel contentView];
   CGFloat w = [cv bounds].size.width;
   CGFloat h = [cv bounds].size.height;

   /* Branch label */
   s_gitBranchLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(10, h-30, w-20, 22)];
   [s_gitBranchLbl setStringValue:@"Branch: (none)"];
   [s_gitBranchLbl setEditable:NO]; [s_gitBranchLbl setBezeled:NO];
   [s_gitBranchLbl setDrawsBackground:NO];
   [s_gitBranchLbl setTextColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1]];
   [s_gitBranchLbl setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
   [s_gitBranchLbl setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
   [cv addSubview:s_gitBranchLbl];

   /* Changes table (Status + File columns) */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 110, w-20, h-150)];
   [sv setHasVerticalScroller:YES];
   [sv setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   [sv setBorderType:NSBezelBorder];

   s_gitChangesTV = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, w-20, h-150)];
   NSTableColumn * colSt = [[NSTableColumn alloc] initWithIdentifier:@"status"];
   [colSt setWidth:40]; [[colSt headerCell] setStringValue:@"St"];
   [s_gitChangesTV addTableColumn:colSt];
   NSTableColumn * colFile = [[NSTableColumn alloc] initWithIdentifier:@"file"];
   [colFile setWidth:300]; [[colFile headerCell] setStringValue:@"File"];
   [s_gitChangesTV addTableColumn:colFile];
   [s_gitChangesTV setDataSource:s_gitChangesDS];
   [s_gitChangesTV setUsesAlternatingRowBackgroundColors:YES];
   [sv setDocumentView:s_gitChangesTV];
   [cv addSubview:sv];

   /* Commit message */
   NSScrollView * msgSV = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 40, w-20, 60)];
   [msgSV setHasVerticalScroller:YES];
   [msgSV setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
   s_gitMsgEdit = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, w-20, 60)];
   [s_gitMsgEdit setEditable:YES];
   [s_gitMsgEdit setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
   [s_gitMsgEdit setBackgroundColor:[NSColor colorWithCalibratedRed:0.15 green:0.15 blue:0.15 alpha:1]];
   [s_gitMsgEdit setTextColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1]];
   [msgSV setDocumentView:s_gitMsgEdit];
   [cv addSubview:msgSV];

   /* Label above message */
   NSTextField * msgLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 102, 200, 16)];
   [msgLbl setStringValue:@"Commit Message:"]; [msgLbl setEditable:NO]; [msgLbl setBezeled:NO];
   [msgLbl setDrawsBackground:NO];
   [msgLbl setTextColor:[NSColor colorWithCalibratedRed:0.7 green:0.7 blue:0.7 alpha:1]];
   [msgLbl setFont:[NSFont systemFontOfSize:11]];
   [cv addSubview:msgLbl];

   /* Buttons */
   NSButton * refreshBtn = [NSButton buttonWithTitle:@"Refresh" target:nil action:nil];
   [refreshBtn setFrame:NSMakeRect(10, 6, 80, 28)];
   [refreshBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
   [cv addSubview:refreshBtn];

   NSButton * commitBtn = [NSButton buttonWithTitle:@"Commit" target:nil action:nil];
   [commitBtn setFrame:NSMakeRect(96, 6, 80, 28)];
   [commitBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
   [cv addSubview:commitBtn];

   NSButton * pushBtn = [NSButton buttonWithTitle:@"Push" target:nil action:nil];
   [pushBtn setFrame:NSMakeRect(182, 6, 80, 28)];
   [pushBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
   [cv addSubview:pushBtn];

   NSButton * pullBtn = [NSButton buttonWithTitle:@"Pull" target:nil action:nil];
   [pullBtn setFrame:NSMakeRect(268, 6, 80, 28)];
   [pullBtn setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
   [cv addSubview:pullBtn];

   [s_gitPanel makeKeyAndOrderFront:nil];
}

/* MAC_GitSetBranch( cBranchName ) */
HB_FUNC( MAC_GITSETBRANCH )
{
   if( s_gitBranchLbl && HB_ISCHAR(1) ) {
      NSString * txt = [NSString stringWithFormat:@"Branch: %s", hb_parc(1)];
      [s_gitBranchLbl setStringValue:txt];
   }
}

/* MAC_GitSetChanges( aChanges ) — array of { cStatus, cFile } */
HB_FUNC( MAC_GITSETCHANGES )
{
   PHB_ITEM pArr = hb_param(1, HB_IT_ARRAY);
   if( !pArr || !s_gitChanges ) return;
   [s_gitChanges removeAllObjects];
   int n = (int)hb_arrayLen(pArr);
   for( int i = 1; i <= n; i++ ) {
      PHB_ITEM pEntry = hb_arrayGetItemPtr(pArr, i);
      if( HB_IS_ARRAY(pEntry) && hb_arrayLen(pEntry) >= 2 ) {
         NSString * st = [NSString stringWithUTF8String:hb_arrayGetCPtr(pEntry, 1)];
         NSString * fn = [NSString stringWithUTF8String:hb_arrayGetCPtr(pEntry, 2)];
         [s_gitChanges addObject:@[st, fn]];
      }
   }
   if( s_gitChangesTV ) [s_gitChangesTV reloadData];
}

/* MAC_GitGetMessage() -> cText */
HB_FUNC( MAC_GITGETMESSAGE )
{
   if( s_gitMsgEdit ) {
      NSString * txt = [[s_gitMsgEdit textStorage] string];
      hb_retc( [txt UTF8String] );
   } else hb_retc( "" );
}

/* MAC_GitClearMessage() */
HB_FUNC( MAC_GITCLEARMESSAGE )
{
   if( s_gitMsgEdit )
      [s_gitMsgEdit setString:@""];
}

/* -----------------------------------------------------------------------
 * Build Error + Progress dialogs
 * ----------------------------------------------------------------------- */

/* Build Error + Progress dialogs */
static NSWindow * s_errDialog = nil;
static NSTextView * s_errTextView = nil;

static NSWindow * s_progressWin = nil;
static NSProgressIndicator * s_progressBar = nil;
static NSTextField * s_progressLbl = nil;

/* Target for Copy to Clipboard button */
@interface HBErrCopyTarget : NSObject
- (void)copyLog:(id)sender;
- (void)closeDialog:(id)sender;
@end
@implementation HBErrCopyTarget
- (void)copyLog:(id)sender {
   if( s_errTextView ) {
      NSString * text = [[s_errTextView textStorage] string];
      NSPasteboard * pb = [NSPasteboard generalPasteboard];
      [pb clearContents];
      [pb setString:text forType:NSPasteboardTypeString];
   }
}
- (void)closeDialog:(id)sender {
   if( s_errDialog ) [s_errDialog orderOut:nil];
}
@end
static HBErrCopyTarget * s_errCopyTarget = nil;

/* MAC_BuildErrorDialog( cTitle, cLog ) — show build log in scrollable monospaced text */
HB_FUNC( MAC_BUILDERRORDIALOG )
{
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Build Error";
   const char * cLog   = HB_ISCHAR(2) ? hb_parc(2) : "";

   if( !s_errCopyTarget ) s_errCopyTarget = [[HBErrCopyTarget alloc] init];

   if( s_errDialog ) {
      [s_errDialog setTitle:[NSString stringWithUTF8String:cTitle]];
      [s_errTextView setString:[NSString stringWithUTF8String:cLog]];
      [s_errDialog makeKeyAndOrderFront:nil];
      return;
   }

   NSRect frame = NSMakeRect(200, 200, 620, 400);
   s_errDialog = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_errDialog setTitle:[NSString stringWithUTF8String:cTitle]];
   [s_errDialog setReleasedWhenClosed:NO];
   [s_errDialog setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_errDialog contentView];
   CGFloat w = [cv bounds].size.width, h = [cv bounds].size.height;

   /* Scrollable text view with build log (read-only, selectable, monospaced) */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(8, 48, w-16, h-56)];
   [sv setHasVerticalScroller:YES];
   [sv setHasHorizontalScroller:YES];
   [sv setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   [sv setBorderType:NSBezelBorder];

   s_errTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, w-16, h-56)];
   [s_errTextView setEditable:NO];
   [s_errTextView setSelectable:YES];
   [s_errTextView setFont:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular]];
   [s_errTextView setBackgroundColor:[NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1]];
   [s_errTextView setTextColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1]];
   [s_errTextView setString:[NSString stringWithUTF8String:cLog]];
   [sv setDocumentView:s_errTextView];
   [cv addSubview:sv];

   /* Copy to Clipboard button */
   NSButton * copyBtn = [NSButton buttonWithTitle:@"Copy to Clipboard" target:s_errCopyTarget action:@selector(copyLog:)];
   [copyBtn setFrame:NSMakeRect(w/2 - 150, 8, 140, 30)];
   [copyBtn setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
   [cv addSubview:copyBtn];

   /* Close button */
   NSButton * closeBtn = [NSButton buttonWithTitle:@"Close" target:s_errCopyTarget action:@selector(closeDialog:)];
   [closeBtn setFrame:NSMakeRect(w/2 + 10, 8, 140, 30)];
   [closeBtn setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
   [cv addSubview:closeBtn];

   [s_errDialog center];
   [s_errDialog makeKeyAndOrderFront:nil];
}

/* -----------------------------------------------------------------------
 * Progress Dialog
 * ----------------------------------------------------------------------- */

/* MAC_ProgressOpen( cTitle, nMax ) — nMax=0 for indeterminate */
HB_FUNC( MAC_PROGRESSOPEN )
{
   const char * title = HB_ISCHAR(1) ? hb_parc(1) : "Working...";
   double nMax = HB_ISNUM(2) ? hb_parnd(2) : 100.0;

   if( s_progressWin ) {
      [s_progressWin makeKeyAndOrderFront:nil];
      return;
   }

   NSRect frame = NSMakeRect(400, 400, 480, 100);
   s_progressWin = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled
      backing:NSBackingStoreBuffered defer:NO];
   [s_progressWin setTitle:[NSString stringWithUTF8String:title]];
   [s_progressWin setReleasedWhenClosed:NO];
   [s_progressWin setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_progressWin contentView];

   s_progressLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 55, 440, 20)];
   [s_progressLbl setStringValue:@""];
   [s_progressLbl setEditable:NO]; [s_progressLbl setBezeled:NO]; [s_progressLbl setDrawsBackground:NO];
   [s_progressLbl setTextColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1]];
   [cv addSubview:s_progressLbl];

   s_progressBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 25, 440, 20)];
   [s_progressBar setStyle:NSProgressIndicatorStyleBar];
   if( nMax <= 0 ) {
      [s_progressBar setIndeterminate:YES];
      [s_progressBar startAnimation:nil];
   } else {
      [s_progressBar setIndeterminate:NO];
      [s_progressBar setMinValue:0.0];
      [s_progressBar setMaxValue:nMax];
      [s_progressBar setDoubleValue:0.0];
   }
   [cv addSubview:s_progressBar];

   [s_progressWin center];
   [s_progressWin makeKeyAndOrderFront:nil];
}

/* MAC_ProgressStep( nValue, [cMessage] ) */
HB_FUNC( MAC_PROGRESSSTEP )
{
   if( s_progressBar ) {
      if( [s_progressBar isIndeterminate] )
         [s_progressBar animate:nil];
      else
         [s_progressBar setDoubleValue:hb_parnd(1)];
   }
   if( s_progressLbl && HB_ISCHAR(2) )
      [s_progressLbl setStringValue:[NSString stringWithUTF8String:hb_parc(2)]];
   /* Flush UI so the user sees the update */
   [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

/* MAC_ShellExecLive( cCmd, [cProgressMsg] ) -> cOutput
 * Run a shell command while keeping the UI responsive (progress dialog updates) */
HB_FUNC( MAC_SHELLEXECLIVE )
{
   const char * szCmd = hb_parc(1);
   if( !szCmd ) { hb_retc(""); return; }

   /* Update label if provided */
   if( s_progressLbl && HB_ISCHAR(2) )
      [s_progressLbl setStringValue:[NSString stringWithUTF8String:hb_parc(2)]];

   FILE * fp = popen( szCmd, "r" );
   if( !fp ) { hb_retc(""); return; }

   size_t bufSize = 8192, total = 0;
   char * buf = (char *) malloc( bufSize );
   buf[0] = 0;

   while( !feof(fp) )
   {
      size_t n = fread( buf + total, 1, 1024, fp );
      total += n;
      if( total >= bufSize - 1024 ) {
         bufSize *= 2;
         buf = (char *) realloc( buf, bufSize );
      }
      /* Pump the run loop so UI stays alive */
      if( s_progressBar && [s_progressBar isIndeterminate] )
         [s_progressBar animate:nil];
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
   }
   buf[total] = 0;
   pclose( fp );

   hb_retc( buf );
   free( buf );
}

/* MAC_ProgressClose() */
HB_FUNC( MAC_PROGRESSCLOSE )
{
   if( s_progressWin ) {
      [s_progressWin orderOut:nil];
      s_progressWin = nil;
      s_progressBar = nil;
      s_progressLbl = nil;
   }
}

/* -----------------------------------------------------------------------
 * Editor Colors Dialog — modal dialog to configure Scintilla colors
 * ----------------------------------------------------------------------- */

/* MAC_EditorColorsDialog( hEditor ) — show color settings, apply to Scintilla */
HB_FUNC( MAC_EDITORCOLORSDIALOG )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciView ) return;

   ScintillaView * sv = ed->sciView;

   /* Preset colours */
   struct { const char * name; sptr_t bg, text, kw, cmd, comment, str, preproc, num, sel; } presets[] = {
      { "Dark",     SCIRGB(30,30,30),    SCIRGB(212,212,212), SCIRGB(86,156,214),
                    SCIRGB(78,201,176),  SCIRGB(106,153,85),  SCIRGB(206,145,120),
                    SCIRGB(197,134,192), SCIRGB(181,206,168), SCIRGB(38,79,120) },
      { "Light",    SCIRGB(255,255,255), SCIRGB(0,0,0),       SCIRGB(0,0,255),
                    SCIRGB(0,128,128),   SCIRGB(0,128,0),     SCIRGB(163,21,21),
                    SCIRGB(128,0,128),   SCIRGB(128,64,0),    SCIRGB(173,214,255) },
      { "Monokai",  SCIRGB(39,40,34),    SCIRGB(248,248,242), SCIRGB(249,38,114),
                    SCIRGB(102,217,239), SCIRGB(117,113,94),  SCIRGB(230,219,116),
                    SCIRGB(166,226,46),  SCIRGB(174,129,255), SCIRGB(73,72,62) },
      { "Solarized",SCIRGB(0,43,54),     SCIRGB(131,148,150), SCIRGB(181,137,0),
                    SCIRGB(42,161,152),  SCIRGB(88,110,117),  SCIRGB(42,161,152),
                    SCIRGB(203,75,22),   SCIRGB(211,54,130),  SCIRGB(7,54,66) },
   };

   /* Create modal alert with preset buttons */
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:@"Editor Colors"];
   [alert setInformativeText:@"Choose a color theme for the code editor:"];

   for( int i = 0; i < 4; i++ )
      [alert addButtonWithTitle:[NSString stringWithUTF8String:presets[i].name]];
   [alert addButtonWithTitle:@"Cancel"];

   NSModalResponse resp = [alert runModal];
   int idx = (int)(resp - NSAlertFirstButtonReturn);
   if( idx < 0 || idx >= 4 ) return;  /* Cancel */

   /* Apply selected preset */
   SciMsg( sv, SCI_STYLESETFORE, STYLE_DEFAULT, presets[idx].text );
   SciMsg( sv, SCI_STYLESETBACK, STYLE_DEFAULT, presets[idx].bg );
   SciMsg( sv, SCI_STYLECLEARALL, 0, 0 );

   SciMsg( sv, SCI_STYLESETFORE, STYLE_LINENUMBER, SCIRGB(133,133,133) );
   sptr_t gutterBg = (idx == 1) ? SCIRGB(240,240,240) : SCIRGB(37,37,38);
   SciMsg( sv, SCI_STYLESETBACK, STYLE_LINENUMBER, gutterBg );

   SciMsg( sv, SCI_STYLESETFORE, SCE_C_WORD,  presets[idx].kw );
   SciMsg( sv, SCI_STYLESETBOLD, SCE_C_WORD,  1 );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_WORD2, presets[idx].cmd );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_COMMENT,     presets[idx].comment );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_COMMENTLINE,  presets[idx].comment );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_COMMENTDOC,   presets[idx].comment );
   SciMsg( sv, SCI_STYLESETITALIC, SCE_C_COMMENT,    1 );
   SciMsg( sv, SCI_STYLESETITALIC, SCE_C_COMMENTLINE, 1 );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_STRING,    presets[idx].str );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_CHARACTER,  presets[idx].str );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_NUMBER,     presets[idx].num );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_PREPROCESSOR, presets[idx].preproc );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_OPERATOR,   presets[idx].text );
   SciMsg( sv, SCI_STYLESETFORE, SCE_C_IDENTIFIER, presets[idx].text );

   sptr_t caretClr = (idx == 1) ? SCIRGB(0,0,0) : SCIRGB(255,255,255);
   SciMsg( sv, SCI_SETCARETFORE, caretClr, 0 );
   SciMsg( sv, SCI_SETSELBACK, 1, presets[idx].sel );

   /* Update fold marker colours */
   sptr_t foldFore = (idx == 1) ? SCIRGB(80,80,80) : SCIRGB(160,160,160);
   for( int m = 25; m <= 31; m++ ) {
      SciMsg( sv, 2041, m, foldFore );
      SciMsg( sv, 2042, m, gutterBg );
   }

   [sv setNeedsDisplay:YES];
}

/* -----------------------------------------------------------------------
 * Project Options Dialog — modal dialog with build settings
 * ----------------------------------------------------------------------- */

/* MAC_ProjectOptionsDialog() */
HB_FUNC( MAC_PROJECTOPTIONSDIALOG )
{
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:@"Project Options"];
   [alert addButtonWithTitle:@"OK"];
   [alert addButtonWithTitle:@"Cancel"];

   /* Create accessory view with tabs */
   NSTabView * tabs = [[NSTabView alloc] initWithFrame:NSMakeRect(0, 0, 450, 300)];

   /* Tab 1: Harbour */
   NSTabViewItem * t1 = [[NSTabViewItem alloc] initWithIdentifier:@"harbour"];
   [t1 setLabel:@"Harbour"];
   NSView * v1 = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 270)];
   NSTextField * lbl1 = [NSTextField labelWithString:@"Harbour Directory:"];
   [lbl1 setFrame:NSMakeRect(10, 230, 150, 20)];
   NSTextField * hbDir = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 205, 420, 24)];
   [hbDir setStringValue:@"/Users/usuario/harbour"];
   NSTextField * lbl2 = [NSTextField labelWithString:@"Compiler Flags:"];
   [lbl2 setFrame:NSMakeRect(10, 175, 150, 20)];
   NSTextField * hbFlags = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 150, 420, 24)];
   [hbFlags setStringValue:@"-n -w -q"];
   [v1 addSubview:lbl1]; [v1 addSubview:hbDir];
   [v1 addSubview:lbl2]; [v1 addSubview:hbFlags];
   [t1 setView:v1];

   /* Tab 2: C Compiler */
   NSTabViewItem * t2 = [[NSTabViewItem alloc] initWithIdentifier:@"compiler"];
   [t2 setLabel:@"C Compiler"];
   NSView * v2 = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 270)];
   NSTextField * lbl3 = [NSTextField labelWithString:@"Compiler:"];
   [lbl3 setFrame:NSMakeRect(10, 230, 150, 20)];
   NSTextField * ccName = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 205, 420, 24)];
   [ccName setStringValue:@"clang"];
   NSTextField * lbl4 = [NSTextField labelWithString:@"Flags:"];
   [lbl4 setFrame:NSMakeRect(10, 175, 150, 20)];
   NSTextField * ccFlags = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 150, 420, 24)];
   [ccFlags setStringValue:@"-O2 -fobjc-arc"];
   [v2 addSubview:lbl3]; [v2 addSubview:ccName];
   [v2 addSubview:lbl4]; [v2 addSubview:ccFlags];
   [t2 setView:v2];

   /* Tab 3: Linker */
   NSTabViewItem * t3 = [[NSTabViewItem alloc] initWithIdentifier:@"linker"];
   [t3 setLabel:@"Linker"];
   NSView * v3 = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 270)];
   NSTextField * lbl5 = [NSTextField labelWithString:@"Linker Flags:"];
   [lbl5 setFrame:NSMakeRect(10, 230, 150, 20)];
   NSTextField * ldFlags = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 205, 420, 24)];
   [ldFlags setStringValue:@"-framework Cocoa -framework QuartzCore"];
   NSTextField * lbl6 = [NSTextField labelWithString:@"Libraries:"];
   [lbl6 setFrame:NSMakeRect(10, 175, 150, 20)];
   NSTextField * libs = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 150, 420, 24)];
   [libs setStringValue:@"-lhbvm -lhbrtl -lhbcommon -lhbcpage"];
   [v3 addSubview:lbl5]; [v3 addSubview:ldFlags];
   [v3 addSubview:lbl6]; [v3 addSubview:libs];
   [t3 setView:v3];

   /* Tab 4: Directories */
   NSTabViewItem * t4 = [[NSTabViewItem alloc] initWithIdentifier:@"dirs"];
   [t4 setLabel:@"Directories"];
   NSView * v4 = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 270)];
   NSTextField * lbl7 = [NSTextField labelWithString:@"Project Directory:"];
   [lbl7 setFrame:NSMakeRect(10, 230, 150, 20)];
   NSTextField * projDir = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 205, 420, 24)];
   [projDir setStringValue:@"."];
   NSTextField * lbl8 = [NSTextField labelWithString:@"Output Directory:"];
   [lbl8 setFrame:NSMakeRect(10, 175, 150, 20)];
   NSTextField * outDir = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 150, 420, 24)];
   [outDir setStringValue:@"/tmp/hbbuilder_build"];
   NSTextField * lbl9 = [NSTextField labelWithString:@"Include Paths:"];
   [lbl9 setFrame:NSMakeRect(10, 120, 150, 20)];
   NSTextField * incPaths = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 95, 420, 24)];
   [incPaths setStringValue:@"/Users/usuario/harbour/include"];
   [v4 addSubview:lbl7]; [v4 addSubview:projDir];
   [v4 addSubview:lbl8]; [v4 addSubview:outDir];
   [v4 addSubview:lbl9]; [v4 addSubview:incPaths];
   [t4 setView:v4];

   [tabs addTabViewItem:t1];
   [tabs addTabViewItem:t2];
   [tabs addTabViewItem:t3];
   [tabs addTabViewItem:t4];

   [alert setAccessoryView:tabs];
   [alert runModal];
}

/* ======================================================================
 * IN-PROCESS DEBUGGER — executes user .hrb bytecode inside IDE VM
 *
 * Architecture:
 *   harbour -gh -b user.prg → user.hrb (bytecode + debug info)
 *   hb_hrbRun(user.hrb) in IDE VM
 *   hb_dbg_SetEntry(hook) → hook called on every source line
 *   Hook pauses at breakpoints / step commands
 *   NSRunLoop keeps UI responsive during pause
 * ====================================================================== */

/* Debug states */
#define DBG_IDLE      0
#define DBG_RUNNING   1
#define DBG_PAUSED    2
#define DBG_STEPPING  3
#define DBG_STEPOVER  4
#define DBG_STOPPED   5

static int    s_dbgState = DBG_IDLE;
static int    s_dbgLine = 0;
static int    s_dbgStepDepth = 0;
static char   s_dbgModule[256] = "";
static PHB_ITEM s_dbgOnPause = NULL;

/* Breakpoints */
#define DBG_MAX_BP 64
typedef struct { char module[256]; int line; } DBGBP;
static DBGBP  s_breakpoints[DBG_MAX_BP];
static int    s_nBreakpoints = 0;

/* Debugger UI widgets */
static NSWindow *    s_dbgWindow = nil;
static NSTextView *  s_dbgOutputTV = nil;
static NSTextField * s_dbgStatusLbl = nil;
static NSTableView * s_dbgLocalsTV = nil;
static NSTableView * s_dbgStackTV = nil;
static NSMutableArray * s_dbgLocalsData = nil;
static NSMutableArray * s_dbgStackData = nil;

/* -----------------------------------------------------------------------
 * Breakpoint check
 * ----------------------------------------------------------------------- */

static int DbgIsBreakpoint( const char * module, int line )
{
   for( int i = 0; i < s_nBreakpoints; i++ )
      if( s_breakpoints[i].line == line &&
          ( s_breakpoints[i].module[0] == 0 ||
            strcasestr( module, s_breakpoints[i].module ) ) )
         return 1;
   return 0;
}

/* Append text to debug output */
static void DbgOutput( const char * text )
{
   if( !s_dbgOutputTV ) return;
   dispatch_async( dispatch_get_main_queue(), ^{
      NSString * str = [NSString stringWithUTF8String:text];
      [[[s_dbgOutputTV textStorage] mutableString] appendString:str];
      [s_dbgOutputTV scrollRangeToVisible:
         NSMakeRange([[s_dbgOutputTV textStorage] length], 0)];
   });
}

/* -----------------------------------------------------------------------
 * Debug hook — called by Harbour VM on every source line
 * ----------------------------------------------------------------------- */

static void IDE_DebugHook( int nMode, int nLine, const char * szName,
                            int nIndex, PHB_ITEM pFrame )
{
   (void)nIndex; (void)pFrame;

   /* Mode 1 = HB_DBG_MODULENAME: track current module */
   if( nMode == 1 && szName )
   {
      strncpy( s_dbgModule, szName, sizeof(s_dbgModule) - 1 );
      return;
   }

   /* Only process mode 5 = HB_DBG_SHOWLINE */
   if( nMode != 5 ) return;

   s_dbgLine = nLine;

   if( s_dbgState == DBG_STOPPED ) return;

   /* In RUNNING mode, only pause at breakpoints */
   if( s_dbgState == DBG_RUNNING && !DbgIsBreakpoint( s_dbgModule, nLine ) )
      return;

   /* STEPOVER: don't pause inside deeper calls */
   if( s_dbgState == DBG_STEPOVER )
   {
      HB_ULONG curDepth = hb_dbg_ProcLevel();
      if( (int)curDepth > s_dbgStepDepth ) return;
   }

   /* === PAUSE === */
   s_dbgState = DBG_PAUSED;

   /* Call Harbour callback: { |cModule, nLine| OnDebugPause(...) } */
   if( s_dbgOnPause && HB_IS_BLOCK( s_dbgOnPause ) )
   {
      PHB_ITEM pMod  = hb_itemPutC( NULL, s_dbgModule );
      PHB_ITEM pLine = hb_itemPutNI( NULL, nLine );
      hb_itemDo( s_dbgOnPause, 2, pMod, pLine );
      hb_itemRelease( pMod );
      hb_itemRelease( pLine );
   }

   /* Keep UI responsive while paused — process Cocoa events */
   while( s_dbgState == DBG_PAUSED )
   {
      @autoreleasepool {
         NSEvent * event = [NSApp nextEventMatchingMask:NSEventMaskAny
            untilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]
            inMode:NSDefaultRunLoopMode dequeue:YES];
         if( event )
            [NSApp sendEvent:event];
      }
   }

   if( s_dbgState == DBG_STOPPED )
      DbgOutput( "Debug session stopped.\n" );
}

/* -----------------------------------------------------------------------
 * Debugger toolbar button targets
 * ----------------------------------------------------------------------- */

@interface HBDebugTarget : NSObject
- (void)dbgRun:(id)sender;
- (void)dbgPause:(id)sender;
- (void)dbgStepInto:(id)sender;
- (void)dbgStepOver:(id)sender;
- (void)dbgStop:(id)sender;
@end

@implementation HBDebugTarget
- (void)dbgRun:(id)sender      { (void)sender; if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_RUNNING; }
- (void)dbgPause:(id)sender    { (void)sender; if( s_dbgState == DBG_RUNNING ) s_dbgState = DBG_PAUSED; }
- (void)dbgStepInto:(id)sender { (void)sender; if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_STEPPING; }
- (void)dbgStepOver:(id)sender {
   (void)sender;
   if( s_dbgState == DBG_PAUSED ) {
      s_dbgStepDepth = (int) hb_dbg_ProcLevel();
      s_dbgState = DBG_STEPOVER;
   }
}
- (void)dbgStop:(id)sender     { (void)sender; if( s_dbgState != DBG_IDLE ) s_dbgState = DBG_STOPPED; }
@end

static HBDebugTarget * s_dbgTarget = nil;

/* -----------------------------------------------------------------------
 * Locals/Stack table data source
 * ----------------------------------------------------------------------- */

@interface HBDbgTableSource : NSObject <NSTableViewDataSource>
{
@public
   NSMutableArray * rows;  /* Array of arrays: [ [col0, col1, col2], ... ] */
}
@end

@implementation HBDbgTableSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
   (void)tableView;
   return rows ? (NSInteger)[rows count] : 0;
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   (void)tableView;
   if( !rows || row < 0 || row >= (NSInteger)[rows count] ) return @"";
   NSArray * r = [rows objectAtIndex:(NSUInteger)row];
   NSInteger colIdx = [[tableView tableColumns] indexOfObject:col];
   if( colIdx < 0 || colIdx >= (NSInteger)[r count] ) return @"";
   return [r objectAtIndex:(NSUInteger)colIdx];
}
@end

static HBDbgTableSource * s_dbgLocalsDS = nil;
static HBDbgTableSource * s_dbgStackDS = nil;

/* -----------------------------------------------------------------------
 * Create debugger panel (called from Harbour or C)
 * ----------------------------------------------------------------------- */

static void CreateDebuggerPanel(void)
{
   if( s_dbgWindow ) {
      [s_dbgWindow makeKeyAndOrderFront:nil];
      return;
   }

   NSRect frame = NSMakeRect( 100, 80, 650, 420 );
   s_dbgWindow = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_dbgWindow setTitle:@"Debugger"];
   [s_dbgWindow setReleasedWhenClosed:NO];
   [s_dbgWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_dbgWindow contentView];
   CGFloat w = [cv bounds].size.width;
   CGFloat h = [cv bounds].size.height;
   CGFloat tbH = 36;

   /* === Toolbar with debug buttons === */
   s_dbgTarget = [[HBDebugTarget alloc] init];

   NSButton * btnRun = [NSButton buttonWithTitle:@"\u25B6 Run"
      target:s_dbgTarget action:@selector(dbgRun:)];
   [btnRun setFrame:NSMakeRect(5, h-tbH+4, 65, 28)];

   NSButton * btnPause = [NSButton buttonWithTitle:@"\u23F8 Pause"
      target:s_dbgTarget action:@selector(dbgPause:)];
   [btnPause setFrame:NSMakeRect(75, h-tbH+4, 70, 28)];

   NSButton * btnStep = [NSButton buttonWithTitle:@"\u2193 Step"
      target:s_dbgTarget action:@selector(dbgStepInto:)];
   [btnStep setFrame:NSMakeRect(150, h-tbH+4, 65, 28)];

   NSButton * btnOver = [NSButton buttonWithTitle:@"\u2192 Over"
      target:s_dbgTarget action:@selector(dbgStepOver:)];
   [btnOver setFrame:NSMakeRect(220, h-tbH+4, 65, 28)];

   NSButton * btnStop = [NSButton buttonWithTitle:@"\u25A0 Stop"
      target:s_dbgTarget action:@selector(dbgStop:)];
   [btnStop setFrame:NSMakeRect(290, h-tbH+4, 65, 28)];

   s_dbgStatusLbl = [NSTextField labelWithString:@"Ready"];
   [s_dbgStatusLbl setFrame:NSMakeRect(370, h-tbH+8, w-380, 20)];
   [s_dbgStatusLbl setTextColor:[NSColor colorWithCalibratedRed:0.6 green:0.8 blue:1.0 alpha:1]];
   [s_dbgStatusLbl setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];

   for( NSButton * b in @[btnRun, btnPause, btnStep, btnOver, btnStop] ) {
      [b setAutoresizingMask:NSViewMinYMargin];
      [cv addSubview:b];
   }
   [cv addSubview:s_dbgStatusLbl];

   /* === Tab view with 5 tabs === */
   NSTabView * tabs = [[NSTabView alloc] initWithFrame:
      NSMakeRect(0, 0, w, h - tbH)];
   [tabs setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

   /* Helper: create table view with columns */
   NSTableView * (^makeTable)(NSArray *cols, NSArray *widths) =
      ^NSTableView *(NSArray *cols, NSArray *widths) {
         NSTableView * tv = [[NSTableView alloc] initWithFrame:NSZeroRect];
         for( NSUInteger i = 0; i < [cols count]; i++ ) {
            NSTableColumn * c = [[NSTableColumn alloc] initWithIdentifier:cols[i]];
            [[c headerCell] setStringValue:cols[i]];
            [c setWidth:[widths[i] doubleValue]];
            [tv addTableColumn:c];
         }
         [tv setRowHeight:18];
         [tv setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
         return tv;
      };

   /* Tab 0: Watch */
   NSTabViewItem * t0 = [[NSTabViewItem alloc] initWithIdentifier:@"watch"];
   [t0 setLabel:@"Watch"];
   NSTableView * watchTV = makeTable(@[@"Expression",@"Value",@"Type"], @[@(180),@(200),@(100)]);
   NSScrollView * sv0 = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,w,h-tbH-30)];
   [sv0 setDocumentView:watchTV]; [sv0 setHasVerticalScroller:YES];
   [sv0 setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
   [t0 setView:sv0];

   /* Tab 1: Locals */
   NSTabViewItem * t1 = [[NSTabViewItem alloc] initWithIdentifier:@"locals"];
   [t1 setLabel:@"Locals"];
   s_dbgLocalsTV = makeTable(@[@"Name",@"Value",@"Type"], @[@(140),@(250),@(100)]);
   s_dbgLocalsDS = [[HBDbgTableSource alloc] init];
   s_dbgLocalsDS->rows = [NSMutableArray array];
   [s_dbgLocalsTV setDataSource:s_dbgLocalsDS];
   NSScrollView * sv1 = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,w,h-tbH-30)];
   [sv1 setDocumentView:s_dbgLocalsTV]; [sv1 setHasVerticalScroller:YES];
   [sv1 setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
   [t1 setView:sv1];

   /* Tab 2: Call Stack */
   NSTabViewItem * t2 = [[NSTabViewItem alloc] initWithIdentifier:@"stack"];
   [t2 setLabel:@"Call Stack"];
   s_dbgStackTV = makeTable(@[@"#",@"Function",@"Module",@"Line"], @[@(30),@(180),@(180),@(60)]);
   s_dbgStackDS = [[HBDbgTableSource alloc] init];
   s_dbgStackDS->rows = [NSMutableArray array];
   [s_dbgStackTV setDataSource:s_dbgStackDS];
   NSScrollView * sv2 = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,w,h-tbH-30)];
   [sv2 setDocumentView:s_dbgStackTV]; [sv2 setHasVerticalScroller:YES];
   [sv2 setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
   [t2 setView:sv2];

   /* Tab 3: Breakpoints */
   NSTabViewItem * t3 = [[NSTabViewItem alloc] initWithIdentifier:@"bp"];
   [t3 setLabel:@"Breakpoints"];
   NSTableView * bpTV = makeTable(@[@"File",@"Line",@"Enabled"], @[@(200),@(60),@(60)]);
   NSScrollView * sv3 = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,w,h-tbH-30)];
   [sv3 setDocumentView:bpTV]; [sv3 setHasVerticalScroller:YES];
   [sv3 setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
   [t3 setView:sv3];

   /* Tab 4: Output */
   NSTabViewItem * t4 = [[NSTabViewItem alloc] initWithIdentifier:@"output"];
   [t4 setLabel:@"Output"];
   NSScrollView * sv4 = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,w,h-tbH-30)];
   [sv4 setHasVerticalScroller:YES];
   [sv4 setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
   s_dbgOutputTV = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,w,h-tbH-30)];
   [s_dbgOutputTV setEditable:NO];
   [s_dbgOutputTV setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
   [s_dbgOutputTV setBackgroundColor:[NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1]];
   [s_dbgOutputTV setTextColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1]];
   [sv4 setDocumentView:s_dbgOutputTV];
   [t4 setView:sv4];

   [tabs addTabViewItem:t0];
   [tabs addTabViewItem:t1];
   [tabs addTabViewItem:t2];
   [tabs addTabViewItem:t3];
   [tabs addTabViewItem:t4];

   [cv addSubview:tabs];
   [s_dbgWindow makeKeyAndOrderFront:nil];
}

/* -----------------------------------------------------------------------
 * HB_FUNC bridges for debugger
 * ----------------------------------------------------------------------- */

/* MAC_DebugPanel() — replaces the simple 5-tab stub from before */
HB_FUNC( MAC_DEBUGPANEL )
{
   CreateDebuggerPanel();
}

/* IDE_DebugStart( cHrbFile, bOnPause ) — execute .hrb with debug hook */
HB_FUNC( IDE_DEBUGSTART )
{
   const char * cHrbFile = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   if( !cHrbFile || s_dbgState != DBG_IDLE ) { hb_retl( HB_FALSE ); return; }

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Install debug hook */
   hb_dbg_SetEntry( IDE_DebugHook );

   s_dbgState = DBG_STEPPING;
   s_nBreakpoints = 0;

   DbgOutput( "=== Debug session started ===\n" );

   /* Execute user .hrb file in IDE VM */
   {
      PHB_ITEM pFile = hb_itemPutC( NULL, cHrbFile );
      hb_vmPushDynSym( hb_dynsymFind( "HB_HRBRUN" ) );
      hb_vmPushNil();
      hb_vmPush( pFile );
      hb_vmDo( 1 );
      hb_itemRelease( pFile );
   }

   /* Cleanup */
   hb_dbg_SetEntry( NULL );
   s_dbgState = DBG_IDLE;
   DbgOutput( "=== Debug session ended ===\n" );

   if( s_dbgStatusLbl )
      [s_dbgStatusLbl setStringValue:@"Ready"];

   hb_retl( HB_TRUE );
}

/* IDE_DebugGo() */
HB_FUNC( IDE_DEBUGGO )
{ if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_RUNNING; }

/* IDE_DebugStep() */
HB_FUNC( IDE_DEBUGSTEP )
{ if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_STEPPING; }

/* IDE_DebugStepOver() */
HB_FUNC( IDE_DEBUGSTEPOVER )
{
   if( s_dbgState == DBG_PAUSED ) {
      s_dbgStepDepth = (int) hb_dbg_ProcLevel();
      s_dbgState = DBG_STEPOVER;
   }
}

/* IDE_DebugStop() */
HB_FUNC( IDE_DEBUGSTOP )
{ if( s_dbgState != DBG_IDLE ) s_dbgState = DBG_STOPPED; }

/* IDE_DebugGetState() --> nState (0=idle,1=running,2=paused,3=stepping,4=stepover,5=stopped) */
HB_FUNC( IDE_DEBUGGETSTATE )
{ hb_retni( s_dbgState ); }

/* IDE_DebugAddBreakpoint( cModule, nLine ) */
HB_FUNC( IDE_DEBUGADDBREAKPOINT )
{
   if( s_nBreakpoints < DBG_MAX_BP && HB_ISCHAR(1) && HB_ISNUM(2) )
   {
      strncpy( s_breakpoints[s_nBreakpoints].module, hb_parc(1), 255 );
      s_breakpoints[s_nBreakpoints].line = hb_parni(2);
      s_nBreakpoints++;
   }
}

/* IDE_DebugClearBreakpoints() */
HB_FUNC( IDE_DEBUGCLEARBREAKPOINTS )
{
   s_nBreakpoints = 0;
}

/* IDE_DebugGetLocals( nLevel ) --> aLocals */
HB_FUNC( IDE_DEBUGGETLOCALS )
{
   int nLevel = HB_ISNUM(1) ? hb_parni(1) : 1;
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   for( int i = 1; i <= 30; i++ )
   {
      PHB_ITEM pVal = hb_dbg_vmVarLGet( nLevel, i );
      if( !pVal ) break;

      PHB_ITEM pEntry = hb_itemArrayNew( 3 );
      char szName[32], szValue[256], szType[32];

      snprintf( szName, sizeof(szName), "Local_%d", i );

      HB_TYPE t = hb_itemType( pVal );
      if( t & HB_IT_STRING ) {
         snprintf( szValue, sizeof(szValue), "\"%s\"", hb_itemGetCPtr( pVal ) );
         strcpy( szType, "STRING" );
      } else if( t & HB_IT_NUMERIC ) {
         if( t & HB_IT_DOUBLE )
            snprintf( szValue, sizeof(szValue), "%f", hb_itemGetND( pVal ) );
         else
            snprintf( szValue, sizeof(szValue), "%ld", (long)hb_itemGetNL( pVal ) );
         strcpy( szType, "NUMERIC" );
      } else if( t & HB_IT_LOGICAL ) {
         strcpy( szValue, hb_itemGetL( pVal ) ? ".T." : ".F." );
         strcpy( szType, "LOGICAL" );
      } else if( t & HB_IT_NIL ) {
         strcpy( szValue, "NIL" ); strcpy( szType, "NIL" );
      } else if( t & HB_IT_ARRAY ) {
         snprintf( szValue, sizeof(szValue), "Array(%lu)", (unsigned long)hb_arrayLen( pVal ) );
         strcpy( szType, "ARRAY" );
      } else if( t & HB_IT_BLOCK ) {
         strcpy( szValue, "{|| ...}" ); strcpy( szType, "BLOCK" );
      } else if( t & HB_IT_OBJECT ) {
         strcpy( szValue, "(Object)" ); strcpy( szType, "OBJECT" );
      } else {
         strcpy( szValue, "?" ); strcpy( szType, "UNKNOWN" );
      }

      hb_arraySetC( pEntry, 1, szName );
      hb_arraySetC( pEntry, 2, szValue );
      hb_arraySetC( pEntry, 3, szType );
      hb_arrayAdd( pArray, pEntry );
      hb_itemRelease( pEntry );
   }

   hb_itemReturnRelease( pArray );
}

/* MAC_DebugUpdateLocals( aLocals ) — update Locals tab */
HB_FUNC( MAC_DEBUGUPDATELOCALS )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_dbgLocalsTV || !s_dbgLocalsDS || !pArray ) return;

   [s_dbgLocalsDS->rows removeAllObjects];
   int n = (int) hb_arrayLen( pArray );
   for( int i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 3 ) continue;
      NSArray * row = @[
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 1 )],
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 2 )],
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 3 )]
      ];
      [s_dbgLocalsDS->rows addObject:row];
   }
   [s_dbgLocalsTV reloadData];
}

/* MAC_DebugUpdateStack( aStack ) — update Call Stack tab */
HB_FUNC( MAC_DEBUGUPDATESTACK )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_dbgStackTV || !s_dbgStackDS || !pArray ) return;

   [s_dbgStackDS->rows removeAllObjects];
   int n = (int) hb_arrayLen( pArray );
   for( int i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 4 ) continue;
      NSArray * row = @[
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 1 )],
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 2 )],
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 3 )],
         [NSString stringWithUTF8String:hb_arrayGetCPtr( pEntry, 4 )]
      ];
      [s_dbgStackDS->rows addObject:row];
   }
   [s_dbgStackTV reloadData];
}

/* MAC_DebugSetStatus( cText ) */
HB_FUNC( MAC_DEBUGSETSTATUS )
{
   if( s_dbgStatusLbl && HB_ISCHAR(1) )
      [s_dbgStatusLbl setStringValue:[NSString stringWithUTF8String:hb_parc(1)]];
}

/* -----------------------------------------------------------------------
 * Messages Panel — data source + click-to-jump
 * ----------------------------------------------------------------------- */

@interface HBMsgTableSource : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation HBMsgTableSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
   (void)tv;
   return s_msgEditor && s_msgEditor->msgData ? (NSInteger)[s_msgEditor->msgData count] : 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   (void)tv;
   if( !s_msgEditor || !s_msgEditor->msgData || row < 0 ||
       row >= (NSInteger)[s_msgEditor->msgData count] ) return @"";
   NSArray * r = [s_msgEditor->msgData objectAtIndex:(NSUInteger)row];
   NSString * ident = [col identifier];
   if( [ident isEqualToString:@"File"] )    return r[0];
   if( [ident isEqualToString:@"Line"] )    return r[1];
   if( [ident isEqualToString:@"Type"] )    return r[2];
   if( [ident isEqualToString:@"Message"] ) return r[3];
   return @"";
}

/* Double-click on error row → jump to line in editor */
- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)row
{
   (void)tv;
   if( !s_msgEditor || !s_msgEditor->msgData || !s_msgEditor->sciView ) return YES;
   if( row < 0 || row >= (NSInteger)[s_msgEditor->msgData count] ) return YES;

   NSArray * r = [s_msgEditor->msgData objectAtIndex:(NSUInteger)row];
   int lineNum = [r[1] intValue];
   if( lineNum > 0 )
   {
      sptr_t pos = SciMsg( s_msgEditor->sciView, SCI_POSITIONFROMLINE, (uptr_t)(lineNum - 1), 0 );
      SciMsg( s_msgEditor->sciView, SCI_GOTOPOS, (uptr_t)pos, 0 );
      SciMsg( s_msgEditor->sciView, SCI_SCROLLCARET, 0, 0 );
      /* Highlight the error line with a red marker */
      SciMsg( s_msgEditor->sciView, SCI_MARKERDELETEALL, 10, 0 );  /* clear old marks */
      SciMsg( s_msgEditor->sciView, SCI_MARKERADD, (uptr_t)(lineNum - 1), 10 );
   }
   return YES;
}

@end

static HBMsgTableSource * s_msgDS = nil;

/* Ensure messages data source is connected (lazy init) */
static void CE_EnsureMsgDS( CODEEDITOR * ed )
{
   if( !s_msgDS && ed && ed->msgTable )
   {
      s_msgDS = [[HBMsgTableSource alloc] init];
      [ed->msgTable setDataSource:s_msgDS];
      [ed->msgTable setDelegate:s_msgDS];
   }
}

/* CodeEditorClearMessages( hEditor ) */
HB_FUNC( CODEEDITORCLEARMESSAGES )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->msgData ) return;
   CE_EnsureMsgDS( ed );
   [ed->msgData removeAllObjects];
   [ed->msgTable reloadData];
   /* Clear error line markers */
   if( ed->sciView )
      SciMsg( ed->sciView, SCI_MARKERDELETEALL, 10, 0 );
}

/* CodeEditorAddMessage( hEditor, cFile, nLine, cType, cMessage ) */
HB_FUNC( CODEEDITORADDMESSAGE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->msgData ) return;

   NSString * file = HB_ISCHAR(2) ? [NSString stringWithUTF8String:hb_parc(2)] : @"";
   NSString * line = HB_ISNUM(3) ? [NSString stringWithFormat:@"%d", hb_parni(3)] : @"";
   NSString * type = HB_ISCHAR(4) ? [NSString stringWithUTF8String:hb_parc(4)] : @"";
   NSString * msg  = HB_ISCHAR(5) ? [NSString stringWithUTF8String:hb_parc(5)] : @"";

   [ed->msgData addObject:@[file, line, type, msg]];
   [ed->msgTable reloadData];

   /* Auto-scroll to last message */
   NSInteger lastRow = (NSInteger)[ed->msgData count] - 1;
   if( lastRow >= 0 )
      [ed->msgTable scrollRowToVisible:lastRow];
}

/* CodeEditorParseErrors( hEditor, cOutput ) — parse Harbour + clang error output */
HB_FUNC( CODEEDITORPARSEERRORS )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->msgData || !HB_ISCHAR(2) ) return;

   const char * output = hb_parc(2);
   int nErrors = 0;

   /* Parse line by line */
   const char * p = output;
   while( *p )
   {
      /* Find end of line */
      const char * eol = p;
      while( *eol && *eol != '\n' ) eol++;

      int lineLen = (int)(eol - p);
      if( lineLen > 0 && lineLen < 1024 )
      {
         char line[1024];
         memcpy( line, p, lineLen );
         line[lineLen] = 0;

         /* Pattern 1: Harbour — "file.prg(123) Error E0020  description" */
         char * paren = strchr( line, '(' );
         if( paren && strstr( line, "Error" ) )
         {
            *paren = 0;
            int nLine = atoi( paren + 1 );
            char * desc = strstr( paren + 1, "Error" );
            if( desc ) {
               NSString * file = [NSString stringWithUTF8String:line];
               NSString * sLine = [NSString stringWithFormat:@"%d", nLine];
               NSString * msg = [NSString stringWithUTF8String:desc];
               [ed->msgData addObject:@[file, sLine, @"Error", msg]];
               nErrors++;
            }
         }
         /* Pattern 1b: Harbour — "file.prg(123) Warning W0001  description" */
         else if( paren && strstr( line, "Warning" ) )
         {
            *paren = 0;
            int nLine = atoi( paren + 1 );
            char * desc = strstr( paren + 1, "Warning" );
            if( desc ) {
               NSString * file = [NSString stringWithUTF8String:line];
               NSString * sLine = [NSString stringWithFormat:@"%d", nLine];
               NSString * msg = [NSString stringWithUTF8String:desc];
               [ed->msgData addObject:@[file, sLine, @"Warning", msg]];
            }
         }
         /* Pattern 2: clang — "file.c:123:45: error: description" */
         else if( strstr( line, ": error:" ) || strstr( line, ": warning:" ) )
         {
            char * colon1 = strchr( line, ':' );
            if( colon1 ) {
               *colon1 = 0;
               int nLine = atoi( colon1 + 1 );
               char * typeStr = strstr( colon1 + 1, "error:" );
               if( !typeStr ) typeStr = strstr( colon1 + 1, "warning:" );
               if( typeStr ) {
                  BOOL isErr = ( typeStr[0] == 'e' );
                  char * desc = strchr( typeStr, ':' );
                  if( desc ) desc++;
                  NSString * file = [NSString stringWithUTF8String:line];
                  NSString * sLine = [NSString stringWithFormat:@"%d", nLine];
                  NSString * msg = desc ? [NSString stringWithUTF8String:desc] : @"";
                  [ed->msgData addObject:@[file, sLine, isErr ? @"Error" : @"Warning",
                     [msg stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]]];
                  if( isErr ) nErrors++;
               }
            }
         }
      }

      p = *eol ? eol + 1 : eol;
   }

   [ed->msgTable reloadData];

   /* Jump to first error */
   if( nErrors > 0 && [ed->msgData count] > 0 )
   {
      [ed->msgTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
      [ed->msgTable scrollRowToVisible:0];
   }

   hb_retni( nErrors );
}

/* -----------------------------------------------------------------------
 * Report Preview — Core Graphics rendering (macOS port of GTK3/Cairo)
 * White page with drop shadow, margins, text/rect/line draw commands,
 * zoom, page navigation.
 * ----------------------------------------------------------------------- */

#define RPT_PRV_MAX_PAGES   100
#define RPT_PRV_MAX_CMDS    500

typedef struct {
   int  type;         /* 1=text, 2=rect, 3=line */
   int  x, y, w, h;
   int  x2, y2;
   char text[256];
   char fontName[64];
   int  fontSize;
   int  bold, italic;
   int  color;
   int  filled;
   int  lineWidth;
} RptDrawCmd;

typedef struct {
   RptDrawCmd cmds[RPT_PRV_MAX_CMDS];
   int nCmds;
} RptPrvPage;

static NSWindow *   s_rptPreview = nil;
static NSView *     s_rptDrawView = nil;
static NSTextField * s_rptPageLabel = nil;
static RptPrvPage   s_rptPrvPages[RPT_PRV_MAX_PAGES];
static int          s_rptPrvPageCount = 0;
static int          s_rptPrvCurPage = 0;
static int          s_rptPreviewZoom = 100;
static int          s_rptPrvPgW = 210, s_rptPrvPgH = 297;
static int          s_rptPrvMgL = 15, s_rptPrvMgR = 15;
static int          s_rptPrvMgT = 15, s_rptPrvMgB = 15;

/* Custom NSView for page rendering */
@interface HBReportPreviewView : NSView
@end

@implementation HBReportPreviewView

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect
{
   (void)dirtyRect;
   NSRect bounds = [self bounds];

   double ppm = 3.0 * s_rptPreviewZoom / 100.0;
   int pageW = (int)( s_rptPrvPgW * ppm );
   int pageH = (int)( s_rptPrvPgH * ppm );
   int pad = 30;
   int shadowOff = 4;

   /* Dark background */
   [[NSColor colorWithCalibratedRed:0.118 green:0.118 blue:0.118 alpha:1] set];
   NSRectFill( bounds );

   /* Center page */
   int pageX = ((int)bounds.size.width - pageW) / 2;
   if( pageX < pad ) pageX = pad;
   int pageY = pad;

   /* Drop shadow */
   [[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0.5] set];
   NSRectFill( NSMakeRect( pageX + shadowOff, pageY + shadowOff, pageW, pageH ) );

   /* White page */
   [[NSColor whiteColor] set];
   NSRectFill( NSMakeRect( pageX, pageY, pageW, pageH ) );

   /* Page border */
   [[NSColor colorWithCalibratedWhite:0.6 alpha:1] set];
   NSFrameRect( NSMakeRect( pageX, pageY, pageW, pageH ) );

   /* Margin lines — dashed */
   {
      CGFloat dashes[] = { 4.0, 4.0 };
      NSBezierPath * path = [NSBezierPath bezierPath];
      [path setLineDash:dashes count:2 phase:0];
      [path setLineWidth:0.5];
      [[NSColor colorWithCalibratedWhite:0.8 alpha:1] set];

      double mL = pageX + s_rptPrvMgL * ppm;
      double mR = pageX + pageW - s_rptPrvMgR * ppm;
      double mT = pageY + s_rptPrvMgT * ppm;
      double mB = pageY + pageH - s_rptPrvMgB * ppm;

      [path moveToPoint:NSMakePoint(mL, pageY)];
      [path lineToPoint:NSMakePoint(mL, pageY + pageH)];
      [path moveToPoint:NSMakePoint(mR, pageY)];
      [path lineToPoint:NSMakePoint(mR, pageY + pageH)];
      [path moveToPoint:NSMakePoint(pageX, mT)];
      [path lineToPoint:NSMakePoint(pageX + pageW, mT)];
      [path moveToPoint:NSMakePoint(pageX, mB)];
      [path lineToPoint:NSMakePoint(pageX + pageW, mB)];
      [path stroke];
   }

   /* Draw commands for current page */
   if( s_rptPrvCurPage >= 0 && s_rptPrvCurPage < s_rptPrvPageCount )
   {
      RptPrvPage * pg = &s_rptPrvPages[s_rptPrvCurPage];
      for( int i = 0; i < pg->nCmds; i++ )
      {
         RptDrawCmd * cmd = &pg->cmds[i];
         CGFloat r = ((cmd->color >> 16) & 0xFF) / 255.0;
         CGFloat g = ((cmd->color >> 8 ) & 0xFF) / 255.0;
         CGFloat b = ((cmd->color      ) & 0xFF) / 255.0;
         NSColor * clr = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1];

         switch( cmd->type )
         {
            case 1:  /* Text */
            {
               NSString * fontName = cmd->fontName[0] ?
                  [NSString stringWithUTF8String:cmd->fontName] : @"Helvetica";
               double fs = cmd->fontSize * ppm / 3.0;
               if( fs < 6 ) fs = 6;
               NSFont * font;
               if( cmd->bold && cmd->italic )
                  font = [[NSFontManager sharedFontManager]
                     fontWithFamily:fontName traits:NSBoldFontMask|NSItalicFontMask weight:9 size:fs];
               else if( cmd->bold )
                  font = [NSFont boldSystemFontOfSize:fs];
               else if( cmd->italic )
                  font = [[NSFontManager sharedFontManager]
                     fontWithFamily:fontName traits:NSItalicFontMask weight:5 size:fs];
               else
                  font = [NSFont fontWithName:fontName size:fs];
               if( !font ) font = [NSFont systemFontOfSize:fs];

               NSDictionary * attrs = @{
                  NSFontAttributeName: font,
                  NSForegroundColorAttributeName: clr
               };
               NSString * text = [NSString stringWithUTF8String:cmd->text];
               [text drawAtPoint:NSMakePoint( pageX + cmd->x * ppm,
                                              pageY + cmd->y * ppm )
                  withAttributes:attrs];
               break;
            }
            case 2:  /* Rect */
            {
               [clr set];
               NSRect rect = NSMakeRect( pageX + cmd->x * ppm, pageY + cmd->y * ppm,
                                         cmd->w * ppm, cmd->h * ppm );
               if( cmd->filled )
                  NSRectFill( rect );
               else
                  NSFrameRect( rect );
               break;
            }
            case 3:  /* Line */
            {
               [clr set];
               NSBezierPath * lp = [NSBezierPath bezierPath];
               [lp setLineWidth: cmd->lineWidth > 0 ? cmd->lineWidth : 1];
               [lp moveToPoint:NSMakePoint( pageX + cmd->x * ppm, pageY + cmd->y * ppm )];
               [lp lineToPoint:NSMakePoint( pageX + cmd->x2 * ppm, pageY + cmd->y2 * ppm )];
               [lp stroke];
               break;
            }
         }
      }
   }

   /* Set content size for scroll view */
   [self setFrameSize:NSMakeSize( pageW + pad * 2, pageH + pad * 2 )];
}

@end

/* Navigation targets */
@interface HBRptPrvTarget : NSObject
- (void)firstPage:(id)sender;
- (void)prevPage:(id)sender;
- (void)nextPage:(id)sender;
- (void)lastPage:(id)sender;
- (void)zoomIn:(id)sender;
- (void)zoomOut:(id)sender;
@end

static void rpt_prv_update_label(void)
{
   if( s_rptPageLabel )
      [s_rptPageLabel setStringValue:[NSString stringWithFormat:@"Page %d / %d  (%d%%)",
         s_rptPrvCurPage + 1, s_rptPrvPageCount > 0 ? s_rptPrvPageCount : 1,
         s_rptPreviewZoom]];
}

@implementation HBRptPrvTarget
- (void)firstPage:(id)s { (void)s; s_rptPrvCurPage = 0; rpt_prv_update_label(); [s_rptDrawView setNeedsDisplay:YES]; }
- (void)prevPage:(id)s  { (void)s; if(s_rptPrvCurPage>0) s_rptPrvCurPage--; rpt_prv_update_label(); [s_rptDrawView setNeedsDisplay:YES]; }
- (void)nextPage:(id)s  { (void)s; if(s_rptPrvCurPage<s_rptPrvPageCount-1) s_rptPrvCurPage++; rpt_prv_update_label(); [s_rptDrawView setNeedsDisplay:YES]; }
- (void)lastPage:(id)s  { (void)s; s_rptPrvCurPage = s_rptPrvPageCount > 0 ? s_rptPrvPageCount-1 : 0; rpt_prv_update_label(); [s_rptDrawView setNeedsDisplay:YES]; }
- (void)zoomIn:(id)s    { (void)s; if(s_rptPreviewZoom<400) s_rptPreviewZoom+=25; rpt_prv_update_label(); [s_rptDrawView setNeedsDisplay:YES]; }
- (void)zoomOut:(id)s   { (void)s; if(s_rptPreviewZoom>25) s_rptPreviewZoom-=25; rpt_prv_update_label(); [s_rptDrawView setNeedsDisplay:YES]; }
@end

static HBRptPrvTarget * s_rptPrvTarget = nil;

/* RPT_PreviewOpen( nPageW, nPageH, nMgL, nMgR, nMgT, nMgB ) */
HB_FUNC( RPT_PREVIEWOPEN )
{
   s_rptPrvPgW = HB_ISNUM(1) ? hb_parni(1) : 210;
   s_rptPrvPgH = HB_ISNUM(2) ? hb_parni(2) : 297;
   s_rptPrvMgL = HB_ISNUM(3) ? hb_parni(3) : 15;
   s_rptPrvMgR = HB_ISNUM(4) ? hb_parni(4) : 15;
   s_rptPrvMgT = HB_ISNUM(5) ? hb_parni(5) : 15;
   s_rptPrvMgB = HB_ISNUM(6) ? hb_parni(6) : 15;

   s_rptPrvPageCount = 0;
   s_rptPrvCurPage = 0;
   memset( s_rptPrvPages, 0, sizeof(s_rptPrvPages) );
   s_rptPreviewZoom = 100;

   if( s_rptPreview )
   {
      [s_rptPreview makeKeyAndOrderFront:nil];
      rpt_prv_update_label();
      return;
   }

   /* Create preview window */
   NSRect frame = NSMakeRect( 150, 50, 700, 850 );
   s_rptPreview = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_rptPreview setTitle:@"Report Preview"];
   [s_rptPreview setReleasedWhenClosed:NO];
   [s_rptPreview setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_rptPreview contentView];
   CGFloat w = [cv bounds].size.width;
   CGFloat h = [cv bounds].size.height;
   CGFloat tbH = 36;

   /* Toolbar: navigation + zoom */
   s_rptPrvTarget = [[HBRptPrvTarget alloc] init];

   NSButton * b1 = [NSButton buttonWithTitle:@"|<" target:s_rptPrvTarget action:@selector(firstPage:)];
   NSButton * b2 = [NSButton buttonWithTitle:@"<"  target:s_rptPrvTarget action:@selector(prevPage:)];
   NSButton * b3 = [NSButton buttonWithTitle:@">"  target:s_rptPrvTarget action:@selector(nextPage:)];
   NSButton * b4 = [NSButton buttonWithTitle:@">|" target:s_rptPrvTarget action:@selector(lastPage:)];
   NSButton * b5 = [NSButton buttonWithTitle:@"-"  target:s_rptPrvTarget action:@selector(zoomOut:)];
   NSButton * b6 = [NSButton buttonWithTitle:@"+"  target:s_rptPrvTarget action:@selector(zoomIn:)];

   int bx = 5;
   for( NSButton * btn in @[b1, b2, b3, b4, b5, b6] ) {
      [btn setFrame:NSMakeRect(bx, h - tbH + 4, 40, 28)];
      [btn setAutoresizingMask:NSViewMinYMargin];
      [cv addSubview:btn];
      bx += 44;
   }

   s_rptPageLabel = [NSTextField labelWithString:@"Page 1 / 1  (100%)"];
   [s_rptPageLabel setFrame:NSMakeRect(bx + 10, h - tbH + 8, 200, 20)];
   [s_rptPageLabel setTextColor:[NSColor colorWithCalibratedWhite:0.7 alpha:1]];
   [s_rptPageLabel setAutoresizingMask:NSViewMinYMargin];
   [cv addSubview:s_rptPageLabel];

   /* Scroll view with custom draw view */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:
      NSMakeRect( 0, 0, w, h - tbH )];
   [sv setHasVerticalScroller:YES];
   [sv setHasHorizontalScroller:YES];
   [sv setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

   s_rptDrawView = [[HBReportPreviewView alloc] initWithFrame:NSMakeRect(0, 0, 800, 1200)];
   [sv setDocumentView:s_rptDrawView];
   [cv addSubview:sv];

   [s_rptPreview makeKeyAndOrderFront:nil];
   rpt_prv_update_label();
}

HB_FUNC( RPT_PREVIEWCLOSE )
{
   if( s_rptPreview ) [s_rptPreview orderOut:nil];
}

HB_FUNC( RPT_PREVIEWADDPAGE )
{
   if( s_rptPrvPageCount < RPT_PRV_MAX_PAGES )
   {
      s_rptPrvPages[s_rptPrvPageCount].nCmds = 0;
      s_rptPrvPageCount++;
      s_rptPrvCurPage = s_rptPrvPageCount - 1;
   }
}

HB_FUNC( RPT_PREVIEWDRAWTEXT )
{
   int pg = s_rptPrvPageCount - 1;
   if( pg < 0 || pg >= RPT_PRV_MAX_PAGES ) return;
   RptPrvPage * page = &s_rptPrvPages[pg];
   if( page->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &page->cmds[page->nCmds++];
   memset( cmd, 0, sizeof(*cmd) );
   cmd->type = 1;
   if( HB_ISCHAR(1) ) strncpy( cmd->text, hb_parc(1), 255 );
   cmd->x = HB_ISNUM(2) ? hb_parni(2) : 0;
   cmd->y = HB_ISNUM(3) ? hb_parni(3) : 0;
   if( HB_ISCHAR(4) ) strncpy( cmd->fontName, hb_parc(4), 63 );
   cmd->fontSize = HB_ISNUM(5) ? hb_parni(5) : 12;
   cmd->bold   = HB_ISLOG(6) ? hb_parl(6) : 0;
   cmd->italic = HB_ISLOG(7) ? hb_parl(7) : 0;
   cmd->color  = HB_ISNUM(8) ? hb_parni(8) : 0;
}

HB_FUNC( RPT_PREVIEWDRAWRECT )
{
   int pg = s_rptPrvPageCount - 1;
   if( pg < 0 || pg >= RPT_PRV_MAX_PAGES ) return;
   RptPrvPage * page = &s_rptPrvPages[pg];
   if( page->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &page->cmds[page->nCmds++];
   memset( cmd, 0, sizeof(*cmd) );
   cmd->type = 2;
   cmd->x = HB_ISNUM(1) ? hb_parni(1) : 0;
   cmd->y = HB_ISNUM(2) ? hb_parni(2) : 0;
   cmd->w = HB_ISNUM(3) ? hb_parni(3) : 10;
   cmd->h = HB_ISNUM(4) ? hb_parni(4) : 10;
   cmd->color  = HB_ISNUM(5) ? hb_parni(5) : 0;
   cmd->filled = HB_ISLOG(6) ? hb_parl(6) : 0;
}

HB_FUNC( RPT_PREVIEWDRAWLINE )
{
   int pg = s_rptPrvPageCount - 1;
   if( pg < 0 || pg >= RPT_PRV_MAX_PAGES ) return;
   RptPrvPage * page = &s_rptPrvPages[pg];
   if( page->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &page->cmds[page->nCmds++];
   memset( cmd, 0, sizeof(*cmd) );
   cmd->type = 3;
   cmd->x  = HB_ISNUM(1) ? hb_parni(1) : 0;
   cmd->y  = HB_ISNUM(2) ? hb_parni(2) : 0;
   cmd->x2 = HB_ISNUM(3) ? hb_parni(3) : 0;
   cmd->y2 = HB_ISNUM(4) ? hb_parni(4) : 0;
   cmd->color     = HB_ISNUM(5) ? hb_parni(5) : 0;
   cmd->lineWidth = HB_ISNUM(6) ? hb_parni(6) : 1;
}

HB_FUNC( RPT_PREVIEWRENDER )
{
   if( s_rptDrawView )
      [s_rptDrawView setNeedsDisplay:YES];
   rpt_prv_update_label();
}

/* -----------------------------------------------------------------------
 * Report Designer — Visual band/field editor with Core Graphics
 * ----------------------------------------------------------------------- */

#define RPT_MAX_BANDS  20
#define RPT_MAX_FIELDS 50
#define RPT_MARGIN_W   24
#define RPT_RULER_H    24
#define RPT_PAGE_PAD   30
#define RPT_HANDLE_SZ  6

typedef struct {
   char cName[32]; char cText[128]; char cFieldName[64];
   int  nLeft, nTop, nWidth, nHeight, nAlignment;
} RptField;

typedef struct {
   char     cName[32];
   int      nHeight, nFieldCount;
   RptField fields[RPT_MAX_FIELDS];
   double   colorR, colorG, colorB;
   int      lPrintOnEveryPage, lKeepTogether, lVisible;
} RptBand;

static NSWindow * s_rptDesigner = nil;
static NSView *   s_rptDesDrawView = nil;
static RptBand    s_rptBands[RPT_MAX_BANDS];
static int        s_rptBandCount = 0;
static int        s_rptSelBand = -1, s_rptSelField = -1;
static int        s_rptPageWidth = 210, s_rptPageHeight = 297, s_rptScale = 3;
static int        s_rptDragging = 0, s_rptDragStartX = 0, s_rptDragStartY = 0;
static int        s_rptDragOrigX = 0, s_rptDragOrigY = 0, s_rptDragOrigH = 0;

static void rpt_band_color( const char * name, double * r, double * g, double * b )
{
   if( strcasecmp(name,"Header")==0 || strcasecmp(name,"Footer")==0 )
      { *r=0.290; *g=0.565; *b=0.851; }
   else if( strcasecmp(name,"Detail")==0 ) { *r=0.850; *g=0.850; *b=0.850; }
   else if( strncasecmp(name,"Group",5)==0 ) { *r=0.420; *g=0.749; *b=0.420; }
   else if( strncasecmp(name,"Page",4)==0 ) { *r=0.831; *g=0.659; *b=0.263; }
   else { *r=0.600; *g=0.600; *b=0.600; }
}

static int rpt_band_y( int idx )
{
   int y = RPT_RULER_H;
   for( int i = 0; i < idx && i < s_rptBandCount; i++ )
      y += s_rptBands[i].nHeight + 2;
   return y;
}

/* Custom drawing view for report designer */
@interface HBReportDesignerView : NSView
@end

@implementation HBReportDesignerView

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)drawRect:(NSRect)dirtyRect
{
   (void)dirtyRect;
   int pageW = s_rptPageWidth * s_rptScale;
   int pageX = RPT_PAGE_PAD;

   /* Dark background */
   [[NSColor colorWithCalibratedRed:0.145 green:0.145 blue:0.149 alpha:1] set];
   NSRectFill( [self bounds] );

   /* White page area */
   int totalBandH = rpt_band_y( s_rptBandCount ) - RPT_RULER_H;
   int pageH = totalBandH > 200 ? totalBandH + RPT_RULER_H + 20 : s_rptPageHeight * s_rptScale;
   [[NSColor whiteColor] set];
   NSRectFill( NSMakeRect( pageX, RPT_RULER_H, pageW, pageH ) );

   /* Ruler */
   [[NSColor colorWithCalibratedRed:0.22 green:0.22 blue:0.22 alpha:1] set];
   NSRectFill( NSMakeRect( pageX, 0, pageW, RPT_RULER_H ) );

   NSDictionary * rulerAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:9],
      NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.8 alpha:1] };
   for( int mm = 0; mm <= s_rptPageWidth; mm += 10 )
   {
      int rx = pageX + mm * s_rptScale;
      NSBezierPath * tick = [NSBezierPath bezierPath];
      [[NSColor colorWithCalibratedWhite:0.8 alpha:1] set];
      [tick moveToPoint:NSMakePoint(rx, RPT_RULER_H - 2)];
      [tick lineToPoint:NSMakePoint(rx, RPT_RULER_H - 10)];
      [tick stroke];
      if( mm % 50 == 0 )
         [[NSString stringWithFormat:@"%d", mm] drawAtPoint:NSMakePoint(rx+2, 1) withAttributes:rulerAttrs];
   }

   /* Bands */
   int bandY = RPT_RULER_H;
   for( int i = 0; i < s_rptBandCount; i++ )
   {
      RptBand * b = &s_rptBands[i];
      int bH = b->nHeight;
      NSColor * bandClr = [NSColor colorWithCalibratedRed:b->colorR green:b->colorG blue:b->colorB alpha:1];

      /* Left margin strip */
      [bandClr set];
      NSRectFill( NSMakeRect( pageX, bandY, RPT_MARGIN_W, bH ) );

      /* Band name in margin (horizontal, small) */
      NSDictionary * nameAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:8],
         NSForegroundColorAttributeName: [NSColor whiteColor] };
      [[NSString stringWithUTF8String:b->cName] drawAtPoint:NSMakePoint(pageX+2, bandY+2) withAttributes:nameAttrs];

      /* Content area */
      [[NSColor whiteColor] set];
      NSRectFill( NSMakeRect( pageX + RPT_MARGIN_W, bandY, pageW - RPT_MARGIN_W, bH ) );

      /* Selected band highlight */
      if( i == s_rptSelBand && s_rptSelField < 0 )
      {
         [[NSColor colorWithCalibratedRed:b->colorR green:b->colorG blue:b->colorB alpha:0.12] set];
         NSRectFill( NSMakeRect( pageX + RPT_MARGIN_W, bandY, pageW - RPT_MARGIN_W, bH ) );
      }

      /* Fields */
      for( int f = 0; f < b->nFieldCount; f++ )
      {
         RptField * fld = &b->fields[f];
         int fx = pageX + RPT_MARGIN_W + fld->nLeft;
         int fy = bandY + fld->nTop;
         int fw = fld->nWidth, fh = fld->nHeight;

         [[NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.97 alpha:1] set];
         NSRectFill( NSMakeRect(fx, fy, fw, fh) );
         [[NSColor colorWithCalibratedWhite:0.7 alpha:1] set];
         NSFrameRect( NSMakeRect(fx, fy, fw, fh) );

         /* Field label */
         const char * label = fld->cFieldName[0] ? fld->cFieldName : fld->cText;
         char display[140];
         if( fld->cFieldName[0] )
            snprintf( display, sizeof(display), "[%s]", label );
         else
            snprintf( display, sizeof(display), "%s", label );
         NSDictionary * fldAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.15 alpha:1] };
         [[NSString stringWithUTF8String:display] drawAtPoint:NSMakePoint(fx+3, fy+2) withAttributes:fldAttrs];

         /* Selection handles */
         if( i == s_rptSelBand && f == s_rptSelField )
         {
            [[NSColor colorWithCalibratedRed:0 green:0.47 blue:0.84 alpha:1] set];
            NSFrameRectWithWidth( NSMakeRect(fx-1, fy-1, fw+2, fh+2), 2 );
            int hx[4] = { fx-3, fx+fw-3, fx+fw-3, fx-3 };
            int hy[4] = { fy-3, fy-3, fy+fh-3, fy+fh-3 };
            for( int j = 0; j < 4; j++ ) {
               [[NSColor whiteColor] set];
               NSRectFill( NSMakeRect(hx[j], hy[j], RPT_HANDLE_SZ, RPT_HANDLE_SZ) );
               [[NSColor colorWithCalibratedRed:0 green:0.47 blue:0.84 alpha:1] set];
               NSFrameRect( NSMakeRect(hx[j], hy[j], RPT_HANDLE_SZ, RPT_HANDLE_SZ) );
            }
         }
      }

      /* Separator */
      NSBezierPath * sep = [NSBezierPath bezierPath];
      CGFloat dashes[] = { 4.0, 2.0 };
      [sep setLineDash:dashes count:2 phase:0];
      [[NSColor colorWithCalibratedWhite:0.6 alpha:1] set];
      [sep moveToPoint:NSMakePoint(pageX, bandY + bH + 0.5)];
      [sep lineToPoint:NSMakePoint(pageX + pageW, bandY + bH + 0.5)];
      [sep stroke];

      bandY += bH + 2;
   }

   int minH = rpt_band_y( s_rptBandCount ) + 40;
   int minW = pageX + pageW + RPT_PAGE_PAD;
   [self setFrameSize:NSMakeSize( minW, minH < 400 ? 400 : minH )];
}

- (void)mouseDown:(NSEvent *)event
{
   NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];
   int mx = (int)pt.x, my = (int)pt.y;
   int pageX = RPT_PAGE_PAD;

   s_rptSelBand = -1; s_rptSelField = -1; s_rptDragging = 0;

   int bandY = RPT_RULER_H;
   for( int i = 0; i < s_rptBandCount; i++ )
   {
      RptBand * b = &s_rptBands[i];
      int bH = b->nHeight;
      if( my >= bandY && my < bandY + bH + 2 )
      {
         if( my >= bandY + bH - 8 && mx >= pageX && mx < pageX + RPT_MARGIN_W )
         { s_rptSelBand = i; s_rptDragging = 2; s_rptDragStartY = my; s_rptDragOrigH = bH; break; }

         if( mx >= pageX && mx < pageX + RPT_MARGIN_W )
         { s_rptSelBand = i; break; }

         for( int f = b->nFieldCount - 1; f >= 0; f-- )
         {
            RptField * fld = &b->fields[f];
            int fx = pageX + RPT_MARGIN_W + fld->nLeft, fy = bandY + fld->nTop;
            if( mx >= fx && mx < fx + fld->nWidth && my >= fy && my < fy + fld->nHeight )
            {
               s_rptSelBand = i; s_rptSelField = f; s_rptDragging = 1;
               s_rptDragStartX = mx; s_rptDragStartY = my;
               s_rptDragOrigX = fld->nLeft; s_rptDragOrigY = fld->nTop;
               goto done;
            }
         }
         s_rptSelBand = i; break;
      }
      bandY += bH + 2;
   }
done:
   [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event
{
   if( !s_rptDragging ) return;
   NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];
   int mx = (int)pt.x, my = (int)pt.y;

   if( s_rptDragging == 1 && s_rptSelBand >= 0 && s_rptSelField >= 0 )
   {
      RptField * fld = &s_rptBands[s_rptSelBand].fields[s_rptSelField];
      fld->nLeft = s_rptDragOrigX + (mx - s_rptDragStartX);
      fld->nTop  = s_rptDragOrigY + (my - s_rptDragStartY);
      if( fld->nLeft < 0 ) fld->nLeft = 0;
      if( fld->nTop < 0 ) fld->nTop = 0;
   }
   else if( s_rptDragging == 2 && s_rptSelBand >= 0 )
   {
      int newH = s_rptDragOrigH + (my - s_rptDragStartY);
      if( newH < 20 ) newH = 20;
      if( newH > 600 ) newH = 600;
      s_rptBands[s_rptSelBand].nHeight = newH;
   }
   [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event { (void)event; s_rptDragging = 0; }

@end

/* Designer toolbar targets */
@interface HBRptDesTarget : NSObject
- (void)addBand:(id)sender;
- (void)addField:(id)sender;
- (void)deleteSel:(id)sender;
- (void)preview:(id)sender;
@end

@implementation HBRptDesTarget

- (void)addBand:(id)sender
{
   (void)sender;
   NSMenu * menu = [[NSMenu alloc] init];
   NSString * types[] = { @"Header", @"Detail", @"Footer", @"GroupHeader", @"GroupFooter", @"PageHeader", @"PageFooter" };
   for( int i = 0; i < 7; i++ ) {
      NSMenuItem * mi = [[NSMenuItem alloc] initWithTitle:types[i] action:@selector(addBandType:) keyEquivalent:@""];
      [mi setTarget:self]; [mi setTag:i];
      [menu addItem:mi];
   }
   [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(5, 0) inView:nil];
}

- (void)addBandType:(NSMenuItem *)item
{
   if( s_rptBandCount >= RPT_MAX_BANDS ) return;
   const char * names[] = { "Header", "Detail", "Footer", "GroupHeader", "GroupFooter", "PageHeader", "PageFooter" };
   RptBand * b = &s_rptBands[s_rptBandCount];
   memset( b, 0, sizeof(RptBand) );
   strncpy( b->cName, names[[item tag]], 31 );
   b->nHeight = 80; b->lVisible = 1;
   rpt_band_color( b->cName, &b->colorR, &b->colorG, &b->colorB );
   s_rptBandCount++;
   [s_rptDesDrawView setNeedsDisplay:YES];
}

- (void)addField:(id)sender
{
   (void)sender;
   int bi = s_rptSelBand >= 0 ? s_rptSelBand : (s_rptBandCount > 0 ? 0 : -1);
   if( bi < 0 ) return;
   RptBand * b = &s_rptBands[bi];
   if( b->nFieldCount >= RPT_MAX_FIELDS ) return;
   RptField * f = &b->fields[b->nFieldCount];
   memset( f, 0, sizeof(RptField) );
   snprintf( f->cName, 32, "Field%d", b->nFieldCount + 1 );
   snprintf( f->cText, 128, "Field%d", b->nFieldCount + 1 );
   f->nLeft = 10 + (b->nFieldCount % 4) * 80; f->nTop = 10; f->nWidth = 70; f->nHeight = 20;
   s_rptSelBand = bi; s_rptSelField = b->nFieldCount; b->nFieldCount++;
   [s_rptDesDrawView setNeedsDisplay:YES];
}

- (void)deleteSel:(id)sender
{
   (void)sender;
   if( s_rptSelBand < 0 ) return;
   if( s_rptSelField >= 0 ) {
      RptBand * b = &s_rptBands[s_rptSelBand];
      if( s_rptSelField < b->nFieldCount - 1 )
         memmove( &b->fields[s_rptSelField], &b->fields[s_rptSelField+1],
                  sizeof(RptField) * (b->nFieldCount - s_rptSelField - 1) );
      b->nFieldCount--; s_rptSelField = -1;
   } else {
      if( s_rptSelBand < s_rptBandCount - 1 )
         memmove( &s_rptBands[s_rptSelBand], &s_rptBands[s_rptSelBand+1],
                  sizeof(RptBand) * (s_rptBandCount - s_rptSelBand - 1) );
      s_rptBandCount--; s_rptSelBand = -1;
   }
   [s_rptDesDrawView setNeedsDisplay:YES];
}

- (void)preview:(id)sender { (void)sender; /* TODO: trigger report preview from designer */ }

@end

static HBRptDesTarget * s_rptDesTarget = nil;

HB_FUNC( RPT_DESIGNEROPEN )
{
   if( s_rptDesigner ) { [s_rptDesigner makeKeyAndOrderFront:nil]; return; }

   NSRect frame = NSMakeRect(100, 80, 800, 600);
   s_rptDesigner = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
   [s_rptDesigner setTitle:@"Report Designer"];
   [s_rptDesigner setReleasedWhenClosed:NO];
   [s_rptDesigner setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * cv = [s_rptDesigner contentView];
   CGFloat w = [cv bounds].size.width, h = [cv bounds].size.height;
   CGFloat tbH = 36;

   s_rptDesTarget = [[HBRptDesTarget alloc] init];
   NSButton * b1 = [NSButton buttonWithTitle:@"Add Band" target:s_rptDesTarget action:@selector(addBand:)];
   NSButton * b2 = [NSButton buttonWithTitle:@"Add Field" target:s_rptDesTarget action:@selector(addField:)];
   NSButton * b3 = [NSButton buttonWithTitle:@"Delete" target:s_rptDesTarget action:@selector(deleteSel:)];
   NSButton * b4 = [NSButton buttonWithTitle:@"Preview" target:s_rptDesTarget action:@selector(preview:)];
   int bx = 5;
   for( NSButton * btn in @[b1, b2, b3, b4] ) {
      [btn setFrame:NSMakeRect(bx, h-tbH+4, 80, 28)]; [btn setAutoresizingMask:NSViewMinYMargin];
      [cv addSubview:btn]; bx += 84;
   }

   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, w, h-tbH)];
   [sv setHasVerticalScroller:YES]; [sv setHasHorizontalScroller:YES];
   [sv setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
   s_rptDesDrawView = [[HBReportDesignerView alloc] initWithFrame:NSMakeRect(0,0,700,400)];
   [sv setDocumentView:s_rptDesDrawView];
   [cv addSubview:sv];

   [s_rptDesigner makeKeyAndOrderFront:nil];
}

HB_FUNC( RPT_DESIGNERCLOSE ) { if( s_rptDesigner ) [s_rptDesigner orderOut:nil]; }
HB_FUNC( RPT_SETREPORT )     { (void)hb_parni(1); }

HB_FUNC( RPT_ADDBAND )
{
   if( s_rptBandCount >= RPT_MAX_BANDS ) { hb_retni(-1); return; }
   const char * cName = hb_parc(1);
   int nHeight = HB_ISNUM(2) ? hb_parni(2) : 80;
   if( !cName || !cName[0] ) { hb_retni(-1); return; }
   RptBand * b = &s_rptBands[s_rptBandCount];
   memset( b, 0, sizeof(RptBand) );
   strncpy( b->cName, cName, 31 ); b->nHeight = nHeight; b->lVisible = 1;
   rpt_band_color( cName, &b->colorR, &b->colorG, &b->colorB );
   int idx = s_rptBandCount++; if( s_rptDesDrawView ) [s_rptDesDrawView setNeedsDisplay:YES];
   hb_retni( idx );
}

HB_FUNC( RPT_ADDFIELD )
{
   int bi = hb_parni(1);
   if( bi < 0 || bi >= s_rptBandCount ) { hb_retni(-1); return; }
   RptBand * b = &s_rptBands[bi];
   if( b->nFieldCount >= RPT_MAX_FIELDS ) { hb_retni(-1); return; }
   RptField * f = &b->fields[b->nFieldCount]; memset( f, 0, sizeof(RptField) );
   if( HB_ISCHAR(2) ) strncpy( f->cName, hb_parc(2), 31 );
   if( HB_ISCHAR(3) ) strncpy( f->cText, hb_parc(3), 127 );
   f->nLeft = HB_ISNUM(4)?hb_parni(4):10; f->nTop = HB_ISNUM(5)?hb_parni(5):10;
   f->nWidth = HB_ISNUM(6)?hb_parni(6):70; f->nHeight = HB_ISNUM(7)?hb_parni(7):20;
   int idx = b->nFieldCount++; if( s_rptDesDrawView ) [s_rptDesDrawView setNeedsDisplay:YES];
   hb_retni( idx );
}

HB_FUNC( RPT_GETSELECTED )
{
   PHB_ITEM p = hb_itemArrayNew(4);
   hb_arraySetNI(p,1,s_rptSelBand); hb_arraySetNI(p,2,s_rptSelField);
   if( s_rptSelBand >= 0 && s_rptSelBand < s_rptBandCount ) {
      hb_arraySetC(p,3,s_rptBands[s_rptSelBand].cName);
      if( s_rptSelField >= 0 && s_rptSelField < s_rptBands[s_rptSelBand].nFieldCount )
         hb_arraySetC(p,4,s_rptBands[s_rptSelBand].fields[s_rptSelField].cName);
      else hb_arraySetC(p,4,"");
   } else { hb_arraySetC(p,3,""); hb_arraySetC(p,4,""); }
   hb_itemReturnRelease(p);
}

HB_FUNC( RPT_GETBANDPROPS )
{
   int bi = hb_parni(1);
   if( bi < 0 || bi >= s_rptBandCount ) { hb_reta(0); return; }
   RptBand * b = &s_rptBands[bi];
   PHB_ITEM a = hb_itemArrayNew(5), r;
   #define BPR(i,n,v,c,t) r=hb_itemArrayNew(4); hb_arraySetC(r,1,n); hb_arraySet##t(r,2,v); \
      hb_arraySetC(r,3,c); hb_arraySetC(r,4,#t[0]=='C'?"S":(#t[0]=='N'?"N":"L")); hb_arraySet(a,i,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"cName"); hb_arraySetC(r,2,b->cName); hb_arraySetC(r,3,"Info"); hb_arraySetC(r,4,"S"); hb_arraySet(a,1,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"nHeight"); hb_arraySetNI(r,2,b->nHeight); hb_arraySetC(r,3,"Position"); hb_arraySetC(r,4,"N"); hb_arraySet(a,2,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"lPrintOnEveryPage"); hb_arraySetL(r,2,b->lPrintOnEveryPage); hb_arraySetC(r,3,"Behavior"); hb_arraySetC(r,4,"L"); hb_arraySet(a,3,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"lKeepTogether"); hb_arraySetL(r,2,b->lKeepTogether); hb_arraySetC(r,3,"Behavior"); hb_arraySetC(r,4,"L"); hb_arraySet(a,4,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"lVisible"); hb_arraySetL(r,2,b->lVisible); hb_arraySetC(r,3,"Behavior"); hb_arraySetC(r,4,"L"); hb_arraySet(a,5,r); hb_itemRelease(r);
   #undef BPR
   hb_itemReturnRelease(a);
}

HB_FUNC( RPT_GETFIELDPROPS )
{
   int bi = hb_parni(1), fi = hb_parni(2);
   if( bi<0||bi>=s_rptBandCount||fi<0||fi>=s_rptBands[bi].nFieldCount ) { hb_reta(0); return; }
   RptField * f = &s_rptBands[bi].fields[fi];
   PHB_ITEM a = hb_itemArrayNew(8), r;
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"cName"); hb_arraySetC(r,2,f->cName); hb_arraySetC(r,3,"Info"); hb_arraySetC(r,4,"S"); hb_arraySet(a,1,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"cText"); hb_arraySetC(r,2,f->cText); hb_arraySetC(r,3,"Appearance"); hb_arraySetC(r,4,"S"); hb_arraySet(a,2,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"cFieldName"); hb_arraySetC(r,2,f->cFieldName); hb_arraySetC(r,3,"Data"); hb_arraySetC(r,4,"S"); hb_arraySet(a,3,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"nLeft"); hb_arraySetNI(r,2,f->nLeft); hb_arraySetC(r,3,"Position"); hb_arraySetC(r,4,"N"); hb_arraySet(a,4,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"nTop"); hb_arraySetNI(r,2,f->nTop); hb_arraySetC(r,3,"Position"); hb_arraySetC(r,4,"N"); hb_arraySet(a,5,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"nWidth"); hb_arraySetNI(r,2,f->nWidth); hb_arraySetC(r,3,"Position"); hb_arraySetC(r,4,"N"); hb_arraySet(a,6,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"nHeight"); hb_arraySetNI(r,2,f->nHeight); hb_arraySetC(r,3,"Position"); hb_arraySetC(r,4,"N"); hb_arraySet(a,7,r); hb_itemRelease(r);
   r=hb_itemArrayNew(4); hb_arraySetC(r,1,"nAlignment"); hb_arraySetNI(r,2,f->nAlignment); hb_arraySetC(r,3,"Appearance"); hb_arraySetC(r,4,"N"); hb_arraySet(a,8,r); hb_itemRelease(r);
   hb_itemReturnRelease(a);
}

HB_FUNC( RPT_SETBANDPROP )
{
   int bi = hb_parni(1); const char * p = hb_parc(2);
   if( bi<0||bi>=s_rptBandCount||!p ) { hb_retl(0); return; }
   RptBand * b = &s_rptBands[bi];
   if(!strcmp(p,"cName")&&HB_ISCHAR(3)) strncpy(b->cName,hb_parc(3),31);
   else if(!strcmp(p,"nHeight")&&HB_ISNUM(3)) b->nHeight=hb_parni(3);
   else if(!strcmp(p,"lPrintOnEveryPage")&&HB_ISLOG(3)) b->lPrintOnEveryPage=hb_parl(3);
   else if(!strcmp(p,"lKeepTogether")&&HB_ISLOG(3)) b->lKeepTogether=hb_parl(3);
   else if(!strcmp(p,"lVisible")&&HB_ISLOG(3)) b->lVisible=hb_parl(3);
   else { hb_retl(0); return; }
   if( s_rptDesDrawView ) [s_rptDesDrawView setNeedsDisplay:YES];
   hb_retl(1);
}

HB_FUNC( RPT_SETFIELDPROP )
{
   int bi = hb_parni(1), fi = hb_parni(2); const char * p = hb_parc(3);
   if( bi<0||bi>=s_rptBandCount||fi<0||fi>=s_rptBands[bi].nFieldCount||!p ) { hb_retl(0); return; }
   RptField * f = &s_rptBands[bi].fields[fi];
   if(!strcmp(p,"cName")&&HB_ISCHAR(4)) strncpy(f->cName,hb_parc(4),31);
   else if(!strcmp(p,"cText")&&HB_ISCHAR(4)) strncpy(f->cText,hb_parc(4),127);
   else if(!strcmp(p,"cFieldName")&&HB_ISCHAR(4)) strncpy(f->cFieldName,hb_parc(4),63);
   else if(!strcmp(p,"nLeft")&&HB_ISNUM(4)) f->nLeft=hb_parni(4);
   else if(!strcmp(p,"nTop")&&HB_ISNUM(4)) f->nTop=hb_parni(4);
   else if(!strcmp(p,"nWidth")&&HB_ISNUM(4)) f->nWidth=hb_parni(4);
   else if(!strcmp(p,"nHeight")&&HB_ISNUM(4)) f->nHeight=hb_parni(4);
   else if(!strcmp(p,"nAlignment")&&HB_ISNUM(4)) f->nAlignment=hb_parni(4);
   else { hb_retl(0); return; }
   if( s_rptDesDrawView ) [s_rptDesDrawView setNeedsDisplay:YES];
   hb_retl(1);
}

} /* extern "C" */
