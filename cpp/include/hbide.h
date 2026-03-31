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

/* Max children per control */
#define MAX_CHILDREN  256

/* Max properties */
#define MAX_PROPS     64

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
   int          FModalResult;
   BOOL         FRunning;
   BOOL         FDesignMode;

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
   void         Close();
   void         Center();

   void         CreateAllChildren();
   void         SubclassChildren();

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
 * Factory function
 */
TControl * CreateControlByType( BYTE bType );

#endif /* _HBIDE_H_ */
