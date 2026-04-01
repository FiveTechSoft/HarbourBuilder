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
   int          FModalResult;
   BOOL         FRunning;
   BOOL         FMainWindow;   /* TRUE = this form owns the message loop */
   BOOL         FDesignMode;

   /* Toolbar */
   TToolBar *   FToolBar;
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

   /* Menu */
   void         CreateMenuBar();
   HMENU        AddMenuPopup( const char * szText );
   int          AddMenuItem( HMENU hPopup, const char * szText, PHB_ITEM pBlock );
   void         AddMenuSeparator( HMENU hPopup );

   /* Design mode */
   void         SetDesignMode( BOOL bDesign );
   PHB_ITEM     FOnSelChange;   /* Harbour callback when selection changes */
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
#define MAX_PALETTE_TABS    8
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
