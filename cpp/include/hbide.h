/*
 * hbide.h - Cross-platform IDE framework
 * C++ core with Harbour bridge
 */

#ifndef _HBIDE_H_
#define _HBIDE_H_

#include <windows.h>
#include <commctrl.h>
#include <hbapi.h>
#include <hbapiitm.h>
#include <hbapicls.h>
#include <hbstack.h>
#include <hbvm.h>

/* Forward declarations */
class TObject;
class TControl;
class TForm;
class TToolBar;
class TComponentPalette;

/* Control types */
#define CT_FORM       0
#define CT_LABEL      1
#define CT_EDIT       2
#define CT_BUTTON     3
#define CT_CHECKBOX   4
#define CT_COMBOBOX   5
#define CT_GROUPBOX   6
#define CT_LISTBOX    7
#define CT_RADIO      8
#define CT_TOOLBAR    9
#define CT_TABCONTROL 10
#define CT_STATUSBAR  11
#define CT_BITBTN     12
#define CT_SPEEDBTN   13
#define CT_IMAGE      14
#define CT_SHAPE      15
#define CT_BEVEL      16
#define CT_SCROLLBOX  17
#define CT_MASKEDIT   18
#define CT_STRINGGRID 19
#define CT_TREEVIEW   20
#define CT_LISTVIEW   21
#define CT_PROGRESSBAR 22
#define CT_RICHEDIT   23
/* Standard extras */
#define CT_MEMO       24
#define CT_PANEL      25
#define CT_SCROLLBAR  26
/* Additional extras */
#define CT_SPEEDBTN   27
#define CT_MASKEDIT2  28
#define CT_STRINGGRID 29
#define CT_SCROLLBOX  30
#define CT_STATICTEXT 31
#define CT_LABELEDEDIT 32
/* Win32 extras */
#define CT_TABCONTROL2 33
#define CT_TRACKBAR   34
#define CT_UPDOWN     35
#define CT_DATETIMEPICKER 36
#define CT_MONTHCALENDAR  37
/* System */
#define CT_TIMER      38
#define CT_PAINTBOX   39
/* Dialogs (non-visual) */
#define CT_OPENDIALOG  40
#define CT_SAVEDIALOG  41
#define CT_FONTDIALOG  42
#define CT_COLORDIALOG 43
#define CT_FINDDIALOG  44
#define CT_REPLACEDIALOG 45
/* AI components */
#define CT_OPENAI     46
#define CT_GEMINI     47
#define CT_CLAUDE     48
#define CT_DEEPSEEK   49
#define CT_GROK       50
#define CT_OLLAMA     51
#define CT_TRANSFORMER 52
#define CT_WHISPER    110
#define CT_EMBEDDINGS 111
/* Connectivity (language/runtime interop) */
#define CT_PYTHON     112
#define CT_SWIFT      113
#define CT_GO         114
#define CT_NODE       115
#define CT_RUST       116
#define CT_JAVA       117
#define CT_DOTNET     118
#define CT_LUA        119
#define CT_RUBY       120
/* Database components */
#define CT_DBFTABLE   53
#define CT_MYSQL      54
#define CT_MARIADB    55
#define CT_POSTGRESQL 56
#define CT_SQLITE     57
#define CT_FIREBIRD   58
#define CT_SQLSERVER  59
#define CT_ORACLE     60
#define CT_MONGODB    61
/* Internet */
#define CT_WEBVIEW    62
#define CT_WEBSERVER  71
#define CT_WEBSOCKET  72
#define CT_HTTPCLIENT 73
#define CT_FTPCLIENT  74
#define CT_SMTPCLIENT 75
#define CT_TCPSERVER  76
#define CT_TCPCLIENT  77
#define CT_UDPSOCKET  78
/* Data Controls */
#define CT_BROWSE     79
#define CT_DBGRID     80
#define CT_DBNAVIGATOR 81
#define CT_DBTEXT     82
#define CT_DBEDIT     83
#define CT_DBCOMBOBOX 84
#define CT_DBCHECKBOX 85
#define CT_DBIMAGE    86
/* ERP / Business components */
#define CT_PREPROCESSOR 90
#define CT_SCRIPTENGINE 91
#define CT_REPORTDESIGNER 92
#define CT_BARCODE    93
#define CT_PDFGENERATOR 94
#define CT_EXCELEXPORT 95
#define CT_AUDITLOG   96
#define CT_PERMISSIONS 97
#define CT_CURRENCY   98
#define CT_TAXENGINE  99
#define CT_DASHBOARD  100
#define CT_SCHEDULER  101
/* Printing components */
#define CT_PRINTER    102
#define CT_REPORT     103
#define CT_LABELS     104
#define CT_PRINTPREVIEW 105
#define CT_PAGESETUP  106
#define CT_PRINTDIALOG 107
#define CT_REPORTVIEWER 108
#define CT_BARCODEPRINTER 109
/* Threading components */
#define CT_THREAD     63
#define CT_MUTEX      64
#define CT_SEMAPHORE  65
#define CT_CRITICALSECTION 66
#define CT_THREADPOOL 67
#define CT_ATOMICINT  68
#define CT_CONDVAR    69
#define CT_CHANNEL    70

/* Max children per control */
#define MAX_CHILDREN  256

/* Max properties */
#define MAX_PROPS     64

/* Toolbar / Menu limits */
#define MAX_TOOLBTNS      64
#define MAX_MENUITEMS     128
#define TOOLBAR_BTN_ID_BASE 100
#define MENU_ID_BASE        1000

/* Property types */
#define PT_STRING     1
#define PT_NUMBER     2
#define PT_LOGICAL    3
#define PT_COLOR      4
#define PT_FONT       5

/*
 * Property descriptor - compile-time metadata
 */
typedef struct {
   const char * szName;
   BYTE         bType;
   int          nOffset;    /* offset in the C++ object */
   const char * szCategory;
} PROPDESC;

/*
 * TObject - Base class for all framework objects
 */
class TObject
{
public:
   char         FClassName[32];
   char         FName[64];
   TObject *    FParent;

   TObject();
   virtual ~TObject();

   virtual const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TControl - Base class for all visual controls
 */
class TControl : public TObject
{
public:
   HWND         FHandle;
   int          FLeft;
   int          FTop;
   int          FWidth;
   int          FHeight;
   char         FText[256];
   BOOL         FVisible;
   BOOL         FEnabled;
   BOOL         FTabStop;
   BYTE         FControlType;
   HFONT        FFont;
   COLORREF     FClrPane;
   HBRUSH       FBkBrush;

   /* Harbour event codeblocks */
   PHB_ITEM     FOnClick;
   PHB_ITEM     FOnChange;
   PHB_ITEM     FOnInit;
   PHB_ITEM     FOnClose;

   /* Parent/children */
   TControl *   FCtrlParent;
   TControl *   FChildren[MAX_CHILDREN];
   int          FChildCount;

   TControl();
   virtual ~TControl();

   /* Core methods */
   virtual void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   virtual void CreateHandle( HWND hParent );
   virtual void DestroyHandle();
   void         AddChild( TControl * pChild );
   void         SetText( const char * szText );
   void         SetBounds( int nLeft, int nTop, int nWidth, int nHeight );
   void         SetFont( HFONT hFont );
   void         Show();
   void         Hide();

   /* Message handling */
   virtual LRESULT HandleMessage( UINT msg, WPARAM wParam, LPARAM lParam );
   virtual void    DoOnClick();
   virtual void    DoOnChange();

   /* Event system */
   void SetEvent( const char * szEvent, PHB_ITEM pBlock );
   void FireEvent( PHB_ITEM pBlock );
   void ReleaseEvents();

   /* Properties */
   virtual const PROPDESC * GetPropDescs( int * pnCount );

   /* Static WndProc */
   static LRESULT CALLBACK WndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam );
};

/*
 * TForm - Top-level window
 */
class TForm : public TControl
{
public:
   HFONT        FFormFont;
   HBITMAP      FGridBmp;      /* cached grid background */
   HDC          FGridDC;
   int          FGridW, FGridH;
   HWND         FOverlay;      /* transparent overlay for selection handles */
   BOOL         FCenter;
   BOOL         FSizable;      /* resizable window */
   BOOL         FAppBar;       /* thin top-bar style (IDE main window) */
   BOOL         FToolWindow;   /* compact caption, no taskbar entry */
   int          FBorderStyle;  /* 0=bsSizeable, 1=bsSingle, 2=bsNone, 3=bsToolWindow */
   int          FBorderIcons;  /* bitfield: 1=biSystemMenu, 2=biMinimize, 4=biMaximize */
   int          FBorderWidth;
   int          FPosition;     /* 0=poDesigned, 1=poCenter, 2=poCenterScreen */
   int          FWindowState;  /* 0=wsNormal, 1=wsMinimized, 2=wsMaximized */
   int          FFormStyle;    /* 0=fsNormal, 1=fsStayOnTop */
   int          FCursor;       /* cursor type */
   BOOL         FKeyPreview;
   BOOL         FAlphaBlend;
   int          FAlphaBlendValue; /* 0-255 */
   BOOL         FShowHint;
   char         FHint[256];
   BOOL         FAutoScroll;
   BOOL         FDoubleBuffered;
   int          FModalResult;
   BOOL         FRunning;
   BOOL         FMainWindow;   /* TRUE = this form owns the message loop */
   BOOL         FDesignMode;

   /* Toolbar */
   TToolBar *   FToolBar;
   TToolBar *   FToolBar2;     /* Second toolbar row (debug buttons) */
   TComponentPalette * FPalette;
   HWND         FStatusBar;
   BOOL         FHasStatusBar;
   int          FClientTop;    /* Y offset below toolbar */

   /* Menu */
   HMENU        FMenuBar;
   PHB_ITEM     FMenuActions[MAX_MENUITEMS];
   int          FMenuItemCount;

   /* Design mode state */
   TControl *   FSelected[MAX_CHILDREN];
   int          FSelCount;
   BOOL         FDragging;
   BOOL         FResizing;
   BOOL         FRubberBand;
   int          FRubberX1, FRubberY1, FRubberX2, FRubberY2;
   int          FResizeHandle;  /* 0-7: which handle is being dragged */
   int          FDragStartX, FDragStartY;
   int          FDragOffsetX, FDragOffsetY;

   TForm();
   virtual ~TForm();

   void         CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void         CreateHandle( HWND hParent );
   LRESULT      HandleMessage( UINT msg, WPARAM wParam, LPARAM lParam );

   void         Run();
   void         Show();    /* Create + show without entering message loop */
   void         Close();
   void         Center();

   void         CreateAllChildren();
   void         SubclassChildren();

   /* Toolbar */
   void         AttachToolBar( TToolBar * pTB );
   void         StackToolBars();

   /* Menu */
   void         CreateMenuBar();
   HMENU        AddMenuPopup( const char * szText );
   int          AddMenuItem( HMENU hPopup, const char * szText, PHB_ITEM pBlock );
   void         AddMenuSeparator( HMENU hPopup );

   /* Form events */
   PHB_ITEM     FOnDblClick;
   PHB_ITEM     FOnCreate;
   PHB_ITEM     FOnDestroy;
   PHB_ITEM     FOnShow;
   PHB_ITEM     FOnHide;
   PHB_ITEM     FOnCloseQuery;
   PHB_ITEM     FOnActivate;
   PHB_ITEM     FOnDeactivate;
   PHB_ITEM     FOnResize;
   PHB_ITEM     FOnPaint;
   PHB_ITEM     FOnKeyDown;
   PHB_ITEM     FOnKeyUp;
   PHB_ITEM     FOnKeyPress;
   PHB_ITEM     FOnMouseDown;
   PHB_ITEM     FOnMouseUp;
   PHB_ITEM     FOnMouseMove;
   PHB_ITEM     FOnMouseWheel;

   /* Design mode */
   void         SetDesignMode( BOOL bDesign );
   void         SetFormEvent( const char * szEvent, PHB_ITEM pBlock );
   void         ReleaseFormEvents();
   PHB_ITEM     FOnSelChange;   /* Harbour callback when selection changes */
   PHB_ITEM     FOnComponentDrop; /* Harbour callback for palette component drop */
   int          FPendingControlType; /* -1 = none, >=0 = type to drop from palette */
   TControl *   HitTest( int x, int y );
   int          HitTestHandle( int x, int y );  /* returns 0-7 handle index or -1 */
   void         SelectControl( TControl * pCtrl, BOOL bAdd );
   void         ClearSelection();
   BOOL         IsSelected( TControl * pCtrl );
   void         PaintSelectionHandles( HDC hDC );
   void         UpdateOverlay();

   virtual const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TLabel
 */
class TLabel : public TControl
{
public:
   TLabel();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TEdit
 */
class TEdit : public TControl
{
public:
   BOOL FReadOnly;
   BOOL FPassword;

   TEdit();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TButton
 */
class TButton : public TControl
{
public:
   BOOL FDefault;
   BOOL FCancel;

   TButton();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   void DoOnClick();
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TCheckBox
 */
class TCheckBox : public TControl
{
public:
   BOOL FChecked;

   TCheckBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   void SetChecked( BOOL bChecked );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TComboBox
 */
class TComboBox : public TControl
{
public:
   int  FItemIndex;
   char FItems[32][64];   /* max 32 items, 64 chars each */
   int  FItemCount;

   TComboBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   void AddItem( const char * szItem );
   void SetItemIndex( int nIndex );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TGroupBox
 */
class TGroupBox : public TControl
{
public:
   TGroupBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TListBox
 */
class TListBox : public TControl
{
public:
   TListBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TRadioButton
 */
class TRadioButton : public TControl
{
public:
   BOOL FChecked;

   TRadioButton();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TBitBtn - Button with glyph (C++Builder Additional tab)
 */
class TBitBtn : public TButton
{
public:
   TBitBtn();
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TImage - Static image control (C++Builder Additional tab)
 */
class TImage : public TControl
{
public:
   BOOL FStretch;
   BOOL FCenter;
   BOOL FProportional;

   TImage();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TShape - Geometric shape (C++Builder Additional tab)
 */
class TShape : public TControl
{
public:
   int FShapeType;  /* 0=Rectangle, 1=Circle, 2=RoundRect, 3=Ellipse */

   TShape();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TBevel - Etched frame (C++Builder Additional tab)
 */
class TBevel : public TControl
{
public:
   int FBevelStyle;  /* 0=bsLowered, 1=bsRaised */

   TBevel();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TMemo - Multiline edit (C++Builder Standard tab)
 */
class TMemo : public TControl
{
public:
   BOOL FReadOnly;
   BOOL FWordWrap;
   BOOL FScrollBars;  /* 0=none, 1=vert, 2=horiz, 3=both */
   TMemo();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TPanel - Container panel (C++Builder Standard tab)
 */
class TPanel : public TControl
{
public:
   int FBevelOuter;  /* 0=none, 1=lowered, 2=raised */
   int FAlignment;   /* 0=left, 1=center, 2=right */
   TPanel();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TScrollBar (C++Builder Standard tab)
 */
class TScrollBar : public TControl
{
public:
   int FMin, FMax, FPosition;
   BOOL FHorizontal;
   TScrollBar();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TSpeedButton - Flat toggle button (C++Builder Additional tab)
 */
class TSpeedButton : public TControl
{
public:
   BOOL FFlat;
   TSpeedButton();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TMaskEdit (C++Builder Additional tab)
 */
class TMaskEdit : public TEdit
{
public:
   char FEditMask[128];
   TMaskEdit();
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TStringGrid (C++Builder Additional tab)
 */
class TStringGrid : public TControl
{
public:
   int FColCount, FRowCount;
   int FFixedCols, FFixedRows;
   TStringGrid();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TScrollBox (C++Builder Additional tab)
 */
class TScrollBox : public TControl
{
public:
   TScrollBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TStaticText (C++Builder Additional tab)
 */
class TStaticText : public TControl
{
public:
   TStaticText();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TLabeledEdit (C++Builder Additional tab)
 */
class TLabeledEdit : public TEdit
{
public:
   char FLabelText[128];
   TLabeledEdit();
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TTabControl (C++Builder Win32 tab)
 */
class TTabControl2 : public TControl
{
public:
   TTabControl2();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TTrackBar (C++Builder Win32 tab)
 */
class TTrackBar : public TControl
{
public:
   int FMin, FMax, FPosition;
   TTrackBar();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TUpDown (C++Builder Win32 tab)
 */
class TUpDown : public TControl
{
public:
   int FMin, FMax, FPosition;
   TUpDown();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TDateTimePicker (C++Builder Win32 tab)
 */
class TDateTimePicker : public TControl
{
public:
   TDateTimePicker();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TMonthCalendar (C++Builder Win32 tab)
 */
class TMonthCalendar : public TControl
{
public:
   TMonthCalendar();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TPaintBox (C++Builder System tab)
 */
class TPaintBox : public TControl
{
public:
   TPaintBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TTreeView - Tree control (C++Builder Win32 tab)
 */
class TTreeView : public TControl
{
public:
   TTreeView();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TListView - List/report control (C++Builder Win32 tab)
 */
class TListView : public TControl
{
public:
   int FViewStyle;  /* 0=vsIcon, 1=vsList, 2=vsReport, 3=vsSmallIcon */

   TListView();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TProgressBar (C++Builder Win32 tab)
 */
class TProgressBar : public TControl
{
public:
   int FMin, FMax, FPosition;

   TProgressBar();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TRichEdit (C++Builder Win32 tab)
 */
class TRichEdit : public TControl
{
public:
   BOOL FReadOnly;

   TRichEdit();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TBrowseColumn - Column descriptor for TBrowse
 */
typedef struct {
   char     szTitle[64];
   char     szFieldName[64];
   int      nWidth;
   int      nAlign;       /* 0=left, 1=center, 2=right */
   BOOL     bEditable;
   BOOL     bVisible;
   BOOL     bSortable;
   COLORREF nHeaderClr;
   COLORREF nFooterClr;
   char     szFooterText[64];
   char     szFormat[32];
} BROWSECOLUMN;

/*
 * TBrowse - Powerful data grid (like C++Builder TDBGrid + FiveWin TWBrowse)
 */
#define MAX_BROWSE_COLS 64

class TBrowse : public TControl
{
public:
   BROWSECOLUMN FCols[MAX_BROWSE_COLS];
   int          FColCount;
   int          FRowCount;
   int          FCurrentRow;
   int          FCurrentCol;
   BOOL         FShowHeaders;
   BOOL         FShowFooters;
   BOOL         FShowGridLines;
   BOOL         FShowRowNumbers;
   BOOL         FCellEditing;
   BOOL         FMultiSelect;
   BOOL         FAltRowColors;
   COLORREF     FAltRowColor;
   int          FRowHeight;
   int          FHeaderHeight;
   int          FFooterHeight;
   int          FSortColumn;    /* -1 = none */
   BOOL         FSortAscending;
   PHB_ITEM     FOnCellClick;
   PHB_ITEM     FOnCellDblClick;
   PHB_ITEM     FOnHeaderClick;
   PHB_ITEM     FOnSort;
   PHB_ITEM     FOnScroll;
   PHB_ITEM     FOnCellEdit;
   PHB_ITEM     FOnCellPaint;
   PHB_ITEM     FOnRowSelect;
   PHB_ITEM     FOnKeyDown;
   PHB_ITEM     FOnColumnResize;
   PHB_ITEM     FDataSource;    /* block that returns data for virtual mode */

   TBrowse();
   virtual ~TBrowse();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   int  AddColumn( const char * szTitle, const char * szField, int nWidth, int nAlign );
   void SetFooterText( int nCol, const char * szText );
   void SetCellText( int nRow, int nCol, const char * szText );
   const char * GetCellText( int nRow, int nCol );
   void Refresh();
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TToolBar - Toolbar control
 */
class TToolBar : public TControl
{
public:
   struct ToolBtn {
       char     szText[32];
       char     szTooltip[128];
       BOOL     bSeparator;
       PHB_ITEM pOnClick;
   };

   ToolBtn     FBtns[MAX_TOOLBTNS];
   int         FBtnCount;
   HIMAGELIST  FImageList;
   int         FIdBase;        /* Button ID base (100 for TB1, 500 for TB2) */

   TToolBar();
   virtual ~TToolBar();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   int  AddButton( const char * szText, const char * szTooltip );
   void AddSeparator();
   void SetBtnClick( int nIdx, PHB_ITEM pBlock );
   void DoCommand( int nBtnIdx );
   int  GetBarHeight();
   void LoadImages( const char * szBmpPath );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * TComponentPalette - Tab control with component buttons (IDE-specific)
 */
#define MAX_PALETTE_TABS    16
#define MAX_PALETTE_BTNS    16

class TComponentPalette : public TControl
{
public:
   struct PaletteTab {
       char     szName[32];
       int      nBtnCount;
       struct {
           char szText[16];
           char szTooltip[64];
           int  nControlType;   /* CT_LABEL, CT_EDIT, etc. */
       } btns[MAX_PALETTE_BTNS];
   };

   HWND         FTabCtrl;
   HWND         FSplitter;     /* Draggable vertical splitter */
   HWND         FBtnPanel;     /* Panel to hold buttons for current tab */
   HWND         FBtns[MAX_PALETTE_BTNS]; /* Button HWNDs */
   PaletteTab   FTabs[MAX_PALETTE_TABS];
   int          FTabCount;
   int          FCurrentTab;
   int          FSplitPos;     /* X position of splitter */
   PHB_ITEM     FOnSelect;     /* callback when component selected */
   HIMAGELIST   FPalImageList; /* Image list for component buttons */

   TComponentPalette();
   virtual ~TComponentPalette();
   void CreateHandle( HWND hParent );
   int  AddTab( const char * szName );
   void AddComponent( int nTab, const char * szText, const char * szTooltip, int nCtrlType );
   void ShowTab( int nTab );
   void HandleTabChange();
   int  GetBarHeight();
   void LoadImages( const char * szBmpPath );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * Factory function
 */
TControl * CreateControlByType( BYTE bType );

#endif /* _HBIDE_H_ */
