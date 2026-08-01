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
#ifdef HBIDE_XHARBOUR
   #include <classes.h>
#else
   #include <hbapicls.h>
#endif
#include <hbstack.h>
#include <hbvm.h>

/* Forward declarations */
class TObject;
class TControl;
class TForm;
class TToolBar;
class TComponentPalette;

#include "hbide_ct.h"

/* ControlAlign constants (used by FDockAlign: 0=alNone..5=alClient) */
#define ALIGN_NONE    0
#define ALIGN_TOP     1
#define ALIGN_BOTTOM  2
#define ALIGN_LEFT    3
#define ALIGN_RIGHT   4
#define ALIGN_CLIENT  5

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
   COLORREF     FClrText;     /* CLR_INVALID = inherit */
   int          FInterval;     /* Timer interval (ms), default 1000 */
   HBRUSH       FBkBrush;

   /* Non-visual database components (CT_DBFTABLE etc.) */
   char         FFileName[260];
   HBITMAP      FBitmap;
   char         FRDD[16];
   BOOL         FActive;
   BOOL         FTransparent;

   /* TPageControl ownership: when this control was created with
      `OF ::oFolder:aPages[N]`, FPageOwner points to the TPageControl
      and FPageIndex is the 0-based page. NULL owner = not paged. */
   TControl *   FPageOwner;
   int          FPageIndex;  /* TRUE: WM_CTLCOLORSTATIC returns NULL_BRUSH so the parent's bg shows through (TLabel default) */

   /* Harbour event codeblocks */
   PHB_ITEM     FOnClick;
   PHB_ITEM     FOnChange;
   PHB_ITEM     FOnInit;
   PHB_ITEM     FOnClose;
   PHB_ITEM     FOnTimer;
   UINT_PTR     FTimerID;      /* Win32 timer ID (0 = inactive) */

   /* ControlAlign dock layout (0=alNone..5=alClient) */
   int          FDockAlign;

   /* Band field serialization: pipe/newline-separated records */
   char         FData[4096];

   /* Parent/children */
   TControl *   FCtrlParent;
   TControl *   FBandParent;   /* non-NULL for report controls; points to owning CT_BAND */
   TControl *   FChildren[MAX_CHILDREN];
   int          FChildCount;

   TControl();
   virtual ~TControl();

   /* Core methods */
   virtual void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   virtual void CreateHandle( HWND hParent );
   virtual void DestroyHandle();
   void         AddChild( TControl * pChild );
   BOOL         RemoveChild( TControl * pChild );
   void         SetText( const char * szText );
   /* Virtual so dock layout (alClient) and maximize resize TWebView's WebView2 */
   virtual void SetBounds( int nLeft, int nTop, int nWidth, int nHeight );
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
   int          FBorderStyle;  /* 0=bsNone,1=bsSingle,2=bsSizeable,3=bsDialog,4=bsToolWindow,5=bsSizeToolWin */
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
   BOOL         FModal;        /* TRUE = ShowModal() is active (nested message loop) */
   BOOL         FDesignMode;
   BOOL         FInSizeMove;     /* TRUE between WM_ENTERSIZEMOVE..WM_EXITSIZEMOVE */
   char         FAppTitle[128];  /* custom binary/app name; defaults to UserApp when empty */

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
   BOOL         FRubberDrawn;
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
   int          ShowModal();  /* Show as modal, block until closed, return FModalResult */
   void         Close();
   void         Center();

   void         CreateAllChildren();
   void         SubclassChildren();

   /* Toolbar */
   void         AttachToolBar( TToolBar * pTB );
   void         StackToolBars();

   /* Menu */
   void         CreateMenuBar();
   void         PaintDarkMenuBar();
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
   PHB_ITEM     FOnActivateApp;  /* fires only when switching from another app */
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
   void         FreeChildren();
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
   char FItems[64][64];  /* max 64 items, 64 chars each */
   int  FItemCount;
   int  FItemIndex;

   TListBox();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
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
   void CreateHandle( HWND hParent );
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
 * TTabControl2 - aka TFolder/TPageControl. Wraps SysTabControl32 and
 * tracks per-page child ownership: children created with
 * `OF ::oFolder:aPages[N]` carry FPageOwner=this + FPageIndex=N and
 * are auto shown/hidden when the user clicks a tab.
 */
class TTabControl2 : public TControl
{
public:
   char FTabs[1024];     /* "Tab1|Tab2|Tab3" */
   int  FPageCount;

   TTabControl2();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   const PROPDESC * GetPropDescs( int * pnCount );
   void SetTabs( const char * szTabs );
   int  GetActivePage();
   void ApplyPageVisibility();
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
 * TWebView — live Edge WebView2 on Windows (ported from FWH cwebview.cpp).
 * Linux/macOS use their own UI_WebView* backends; same Harbour TWebView class.
 */
class TWebView : public TControl
{
public:
   void * FEngine;                 /* FwhWebView2* (Windows WebView2 host) */
   char   FPendingUrl[2048];
   char   FUserDataFolder[MAX_PATH];

   TWebView();
   virtual ~TWebView();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   virtual void SetBounds( int nLeft, int nTop, int nWidth, int nHeight );
   virtual LRESULT HandleMessage( UINT msg, WPARAM wParam, LPARAM lParam );
   void EnsureEngine();
   void Navigate( const char * szUrl );
   void LoadHTML( const char * szHtml );
   void EvaluateJS( const char * szScript );
   void SyncEngineSize();
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

/* TPageControl removed - functionality merged into TTabControl2 above. */

/*
 * TListView - List/report control (C++Builder Win32 tab)
 *
 * aColumns: pipe-separated header titles ("Name|Age|City")
 * aItems:   pipe-separated rows; cells in each row separated by ';'
 *           ("John;30;NY|Mary;25;LA")
 */
#define LV_MAX_COLS  8
#define LV_MAX_ROWS  64
#define LV_TXT_LEN   64
#define LV_MAX_IMGS  16
#define LV_PATH_LEN  260

class TListView : public TControl
{
public:
   int        FViewStyle;  /* 0=vsIcon, 1=vsList, 2=vsReport, 3=vsSmallIcon */
   int        FColCount;
   int        FRowCount;
   char       FColumns[LV_MAX_COLS][LV_TXT_LEN];
   char       FCells[LV_MAX_ROWS][LV_MAX_COLS][LV_TXT_LEN];
   /* ImageList state — pipe-separated PNG paths in FImages stored
      via SetImages(); ImageLists built lazily in CreateHandle/Repopulate
      and re-attached when paths change. */
   char       FImages[LV_MAX_IMGS][LV_PATH_LEN];
   int        FImageCount;
   HIMAGELIST FImgListLarge;  /* 32x32 for vsIcon */
   HIMAGELIST FImgListSmall;  /* 16x16 for vsSmallIcon (and report row icons) */

   TListView();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   void Repopulate();
   void RebuildImageLists();
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
   char         FDataSourceName[64]; /* name of data component for code gen */
   HWND         FFooterWnd;   /* footer bar below ListView */

   TBrowse();
   virtual ~TBrowse();
   void CreateParams( DWORD * pdwStyle, DWORD * pdwExStyle, const char ** pszClass );
   void CreateHandle( HWND hParent );
   int  AddColumn( const char * szTitle, const char * szField, int nWidth, int nAlign );
   void SetFooterText( int nCol, const char * szText );
   void SetCellText( int nRow, int nCol, const char * szText );
   const char * GetCellText( int nRow, int nCol );
   void Refresh();
   void UpdateFooter();
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
   HWND         FBtnTips[MAX_PALETTE_BTNS]; /* per-button tooltip HWNDs (parallel to FBtns) */
   PaletteTab   FTabs[MAX_PALETTE_TABS];
   int          FTabCount;
   int          FCurrentTab;
   int          FSplitPos;     /* X position of splitter */
   PHB_ITEM     FOnSelect;     /* callback when component selected */
   HIMAGELIST   FPalImageList; /* Image list for component buttons */
   HBITMAP      FCompIconOverride[256]; /* Per-control-type 32x32 PNG (alpha) */

   TComponentPalette();
   virtual ~TComponentPalette();
   void CreateHandle( HWND hParent );
   int  AddTab( const char * szName );
   void AddComponent( int nTab, const char * szText, const char * szTooltip, int nCtrlType );
   void ShowTab( int nTab );
   void HandleTabChange();
   int  GetBarHeight();
   void LoadImages( const char * szBmpPath );
   void AppendImages( const char * szBmpPath );
   void SetCompIcon( int nCtrlType, const char * szPngPath );
   const PROPDESC * GetPropDescs( int * pnCount );
};

/*
 * Factory function
 */
TControl * CreateControlByType( BYTE bType );

/* Unicode / UTF-8 helper functions for native Emoji rendering */
#include <malloc.h>
#include <windows.h>

inline void SetWindowTextDetectUTF8( HWND hWnd, const char * szText )
{
   if( !hWnd || !szText ) return;
   int nLen = (int) strlen( szText );
   int nWideLen = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, szText, nLen, NULL, 0 );
   if( nWideLen > 0 )
   {
      WCHAR * wbuf = (WCHAR *) malloc( (nWideLen + 1) * sizeof(WCHAR) );
      MultiByteToWideChar( CP_UTF8, 0, szText, nLen, wbuf, nWideLen );
      wbuf[nWideLen] = 0;
      SetWindowTextW( hWnd, wbuf );
      free( wbuf );
   }
   else
   {
      nWideLen = MultiByteToWideChar( CP_ACP, 0, szText, nLen, NULL, 0 );
      if( nWideLen > 0 )
      {
         WCHAR * wbuf = (WCHAR *) malloc( (nWideLen + 1) * sizeof(WCHAR) );
         MultiByteToWideChar( CP_ACP, 0, szText, nLen, wbuf, nWideLen );
         wbuf[nWideLen] = 0;
         SetWindowTextW( hWnd, wbuf );
         free( wbuf );
      }
      else
      {
         SetWindowTextA( hWnd, szText );
      }
   }
}

inline void DrawTextDetectUTF8( HDC hDC, const char * szText, int nCount, RECT * lpRect, UINT uFormat )
{
   if( !szText ) return;
   int nLen = (nCount < 0) ? (int) strlen( szText ) : nCount;
   int nWideLen = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, szText, nLen, NULL, 0 );
   if( nWideLen > 0 )
   {
      WCHAR * wbuf = (WCHAR *) malloc( (nWideLen + 1) * sizeof(WCHAR) );
      MultiByteToWideChar( CP_UTF8, 0, szText, nLen, wbuf, nWideLen );
      wbuf[nWideLen] = 0;
      DrawTextW( hDC, wbuf, nWideLen, lpRect, uFormat );
      free( wbuf );
   }
   else
   {
      nWideLen = MultiByteToWideChar( CP_ACP, 0, szText, nLen, NULL, 0 );
      if( nWideLen > 0 )
      {
         WCHAR * wbuf = (WCHAR *) malloc( (nWideLen + 1) * sizeof(WCHAR) );
         MultiByteToWideChar( CP_ACP, 0, szText, nLen, wbuf, nWideLen );
         wbuf[nWideLen] = 0;
         DrawTextW( hDC, wbuf, nWideLen, lpRect, uFormat );
         free( wbuf );
      }
      else
      {
         DrawTextA( hDC, szText, nCount, lpRect, uFormat );
      }
   }
}

inline HWND CreateWindowExDetectUTF8( DWORD dwExStyle, const char * szClass, const char * szText, DWORD dwStyle,
                                      int x, int y, int nWidth, int nHeight, HWND hParent, HMENU hMenu, HINSTANCE hInst, LPVOID lpParam )
{
   WCHAR wClass[128] = {0};
   MultiByteToWideChar( CP_ACP, 0, szClass, -1, wClass, 128 );
   WCHAR * wText = NULL;
   if( szText )
   {
      int nLen = (int) strlen( szText );
      int nWideLen = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, szText, nLen, NULL, 0 );
      if( nWideLen > 0 )
      {
         wText = (WCHAR *) malloc( (nWideLen + 1) * sizeof(WCHAR) );
         MultiByteToWideChar( CP_UTF8, 0, szText, nLen, wText, nWideLen );
         wText[nWideLen] = 0;
      }
      else
      {
         nWideLen = MultiByteToWideChar( CP_ACP, 0, szText, nLen, NULL, 0 );
         if( nWideLen > 0 )
         {
            wText = (WCHAR *) malloc( (nWideLen + 1) * sizeof(WCHAR) );
            MultiByteToWideChar( CP_ACP, 0, szText, nLen, wText, nWideLen );
            wText[nWideLen] = 0;
         }
      }
   }
   HWND hWnd = CreateWindowExW( dwExStyle, wClass, wText, dwStyle, x, y, nWidth, nHeight, hParent, hMenu, hInst, lpParam );
   if( wText ) free( wText );
   return hWnd;
}

#endif /* _HBIDE_H_ */
