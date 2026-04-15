/*
 * cocoa_core.m - Cocoa/AppKit implementation of hbcpp framework for macOS
 * Replaces the Win32 C++ core (tcontrol.cpp, tform.cpp, tcontrols.cpp, hbbridge.cpp)
 *
 * Provides the same HB_FUNC bridge interface so Harbour code (classes.prg) works unchanged.
 */

#import <Cocoa/Cocoa.h>
#if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#define HAS_UTTYPE 1
#endif
#include <hbapi.h>
#include <hbapiitm.h>
#include <hbapicls.h>
#include <hbstack.h>
#include <hbvm.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>

/* Suppress macOS "Wait cursor is invalid" / "Reverse arrow cursor is invalid" warnings */
__attribute__((constructor))
static void SuppressCursorWarnings(void)
{
   setenv( "OS_ACTIVITY_MODE", "disable", 0 );
}

/* Control types - must match all platforms */
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
#define CT_STATUSBAR  11
#define CT_BITBTN     12
#define CT_SPEEDBTN   13
#define CT_IMAGE      14
#define CT_SHAPE      15
#define CT_BEVEL      16
#define CT_TREEVIEW   20
#define CT_LISTVIEW   21
#define CT_PROGRESSBAR 22
#define CT_RICHEDIT   23
#define CT_MEMO       24
#define CT_PANEL      25
#define CT_SCROLLBAR  26
#define CT_MASKEDIT2  28
#define CT_STRINGGRID 29
#define CT_SCROLLBOX  30
#define CT_STATICTEXT 31
#define CT_LABELEDEDIT 32
#define CT_TABCONTROL2 33
#define CT_TRACKBAR   34
#define CT_UPDOWN     35
#define CT_DATETIMEPICKER 36
#define CT_MONTHCALENDAR  37
#define CT_TIMER      38
#define CT_PAINTBOX   39
#define CT_OPENDIALOG  40
#define CT_SAVEDIALOG  41
#define CT_FONTDIALOG  42
#define CT_COLORDIALOG 43
#define CT_FINDDIALOG  44
#define CT_REPLACEDIALOG 45
#define CT_OPENAI     46
#define CT_GEMINI     47
#define CT_CLAUDE     48
#define CT_DEEPSEEK   49
#define CT_GROK       50
#define CT_OLLAMA     51
#define CT_TRANSFORMER 52
#define CT_DBFTABLE   53
#define CT_MYSQL      54
#define CT_MARIADB    55
#define CT_POSTGRESQL 56
#define CT_SQLITE     57
#define CT_FIREBIRD   58
#define CT_SQLSERVER  59
#define CT_ORACLE     60
#define CT_MONGODB    61
#define CT_WEBVIEW    62
#define CT_WEBSERVER  71
#define CT_WEBSOCKET  72
#define CT_HTTPCLIENT 73
#define CT_FTPCLIENT  74
#define CT_SMTPCLIENT 75
#define CT_TCPSERVER  76
#define CT_TCPCLIENT  77
#define CT_UDPSOCKET  78
#define CT_BROWSE     79
#define CT_COMPARRAY  131
#define CT_DBGRID     80
#define CT_DBNAVIGATOR 81
#define CT_DBTEXT     82
#define CT_DBEDIT     83
#define CT_DBCOMBOBOX 84
#define CT_DBCHECKBOX 85
#define CT_DBIMAGE    86
#define CT_BRWCOLUMN  87
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
#define CT_PRINTER    102
#define CT_REPORT     103
#define CT_LABELS     104
#define CT_PRINTPREVIEW 105
#define CT_PAGESETUP  106
#define CT_PRINTDIALOG 107
#define CT_REPORTVIEWER 108
#define CT_BARCODEPRINTER 109
#define CT_THREAD     63
#define CT_MUTEX      64
#define CT_SEMAPHORE  65
#define CT_CRITICALSECTION 66
#define CT_THREADPOOL 67
#define CT_ATOMICINT  68
#define CT_CONDVAR    69
#define CT_CHANNEL    70

#define MAX_CHILDREN  256
#define MAX_TOOLBTNS  64
#define TOOLBAR_BTN_ID_BASE 100
#define MENU_ID_BASE        1000
#define MAX_MENUITEMS       128

/* --- TBrowse data grid structures --- */
#define MAX_BROWSE_COLS  64
#define MAX_BROWSE_ROWS  10000

@class HBControl;

typedef struct {
    char szTitle[64];
    char szFieldName[64];
    int  nWidth;
    int  nAlign;  /* 0=left, 1=center, 2=right */
    char szFooterText[64];
} BrowseCol;

typedef struct {
    HBControl * __unsafe_unretained pCtrl;  /* back-pointer to HBControl */
    NSTableView * tableView;
    NSScrollView * scrollView;
    BrowseCol cols[MAX_BROWSE_COLS];
    int nColCount;
    NSMutableArray * rowData;    /* Array of arrays of NSString */
    PHB_ITEM FOnCellClick, FOnCellDblClick, FOnHeaderClick;
    PHB_ITEM FOnRowSelect, FOnKeyDown;
} BrowseData;

#define MAX_BROWSES 32
static BrowseData s_browses[MAX_BROWSES];
static int s_nBrowses = 0;

/* LONG_PTR equivalent for macOS */
typedef long LONG_PTR_MAC;
#define LONG_PTR LONG_PTR_MAC

/* Forward declarations */
@class HBToolBar;
@class HBSplitterView;
static void KeepAlive( HBControl * p );

/* Component Palette data (forward declared for use in HBForm) */
#define CT_TABCONTROL 10
#define MAX_PALETTE_TABS 16
#define MAX_PALETTE_BTNS 32

typedef struct {
   char szText[32];
   char szTooltip[128];
   int  nControlType;
} PaletteBtn;

typedef struct {
   char szName[32];
   PaletteBtn btns[MAX_PALETTE_BTNS];
   int nBtnCount;
} PaletteTab;

@class HBForm;

typedef struct {
   HBForm * __unsafe_unretained parentForm;
   NSView *           containerView;
   NSView *           splitterView;
   NSSegmentedControl * segmented;
   NSView *           btnPanel;
   NSButton *         buttons[MAX_PALETTE_BTNS];
   PaletteTab         tabs[MAX_PALETTE_TABS];
   int                nTabCount;
   int                nCurrentTab;
   int                nSplitPos;
   PHB_ITEM           pOnSelect;
   NSMutableArray *   palImages;
} PALDATA;

static PALDATA * s_palData = NULL;
static HBForm * s_designForm = NULL;  /* the design-mode form for component drops */
static void PalShowTab( PALDATA * pd, int nTab );

/* ======================================================================
 * NSApp initialization
 * ====================================================================== */

static BOOL s_appInitialized = NO;

void EnsureNSApp( void )
{
   if( !s_appInitialized )
   {
      [NSApplication sharedApplication];
      [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

      NSMenu * menuBar = [[NSMenu alloc] init];
      NSMenuItem * appMenuItem = [[NSMenuItem alloc] init];
      NSMenu * appMenu = [[NSMenu alloc] initWithTitle:@"HbBuilder"];
      [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
      [appMenuItem setSubmenu:appMenu];
      [menuBar addItem:appMenuItem];
      [NSApp setMainMenu:menuBar];

      s_appInitialized = YES;
   }
}

/* ======================================================================
 * Flipped NSView (top-left origin like Win32)
 * ====================================================================== */

@interface HBFlippedView : NSView
@end
@implementation HBFlippedView
- (BOOL)isFlipped { return YES; }
@end

/* HBFormContentView: declared here, implemented after HBForm @interface */

/* Dot grid view for design-time (drawn as first subview of content) */
@interface HBDotGridView : NSView
{
@public
   NSColor * bgColor;
}
@end
@implementation HBDotGridView
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (void)drawRect:(NSRect)dirtyRect
{
   /* Form background color (dark theme) */
   NSColor * bg = bgColor ? bgColor :
      [NSColor colorWithCalibratedRed:0.18 green:0.18 blue:0.18 alpha:1.0];
   [bg setFill];
   NSRectFill( dirtyRect );

   /* Classic C++Builder dot grid (lighter dots on dark bg) */
   [[NSColor colorWithCalibratedWhite:0.35 alpha:1.0] setFill];
   int gridStep = 8;
   int x1 = ((int)dirtyRect.origin.x / gridStep) * gridStep;
   int y1 = ((int)dirtyRect.origin.y / gridStep) * gridStep;
   int x2 = (int)(dirtyRect.origin.x + dirtyRect.size.width);
   int y2 = (int)(dirtyRect.origin.y + dirtyRect.size.height);
   for( int y = y1; y <= y2; y += gridStep )
      for( int x = x1; x <= x2; x += gridStep )
         NSRectFill( NSMakeRect( x, y, 1, 1 ) );
}
@end

/* ======================================================================
 * ALL @interface declarations (full definitions before any @implementation)
 * ====================================================================== */

/* --- HBControl --- */
@interface HBControl : NSObject
{
@public
   char FClassName[32];
   char FName[64];
   char FText[256];
   char FFileName[512];       /* Design-time file path (e.g. DBF file for TDBFTable) */
   char FRdd[16];             /* RDD driver: DBFCDX, DBFNTX, DBFFPT */
   char FHeaders[512];        /* Column headers: "Name|Age|City" */
   int  FColWidths[MAX_BROWSE_COLS]; /* Deferred column widths */
   char FData[4096];          /* Row data: "John|45|NYC;Mary|32|LA" */
   char FDataSource[64];      /* Name of data component (e.g. "CompArray1") */
   BOOL FActive;              /* Design-time Active flag (auto-open on form load) */
   int  FLeft, FTop, FWidth, FHeight;
   BOOL FVisible, FEnabled, FTabStop;
   int  FControlType;
   NSView * FView;
   NSFont * FFont;
   NSColor * FBgColor;
   unsigned int FClrPane;
   unsigned int FClrText;

   PHB_ITEM FOnClick, FOnChange, FOnInit, FOnClose;
   PHB_ITEM FOnTimer;
   int      FInterval;       /* Timer interval in milliseconds (default 1000) */
   NSTimer * FTimer;         /* NSTimer for CT_TIMER controls */

   HBControl * FCtrlParent;
   HBControl * FChildren[MAX_CHILDREN];
   int FChildCount;

   /* TPageControl ownership: if FOwnerCtrl != nil, this control belongs to
    * page FOwnerPage of that TPageControl. Its position remains in form
    * coordinates; it is shown/hidden when the owner's selected tab matches. */
   HBControl * FOwnerCtrl;
   int         FOwnerPage;
   BOOL        FAutoPage;   /* Auto-created page TPanel for a TPageControl tab */
   BOOL        FTransparent; /* TRUE = don't draw background (labels default TRUE) */
   int         nAlign;      /* 0=Left, 1=Center, 2=Right (text alignment) */
}
- (void)addChild:(HBControl *)child;
- (void)setText:(const char *)text;
- (void)createViewInParent:(NSView *)parentView;
- (void)updateViewFrame;
- (void)setEvent:(const char *)event block:(PHB_ITEM)block;
- (void)fireEvent:(PHB_ITEM)block;
- (void)releaseEvents;
- (void)applyFont;
- (void)startTimer;
- (void)stopTimer;
- (void)timerFired:(NSTimer *)timer;
@end

/* BorderStyle constants (match C++Builder) */
#define BS_NONE        0
#define BS_SINGLE      1
#define BS_SIZEABLE    2
#define BS_DIALOG      3
#define BS_TOOLWINDOW  4
#define BS_SIZETOOLWIN 5

/* Position constants */
#define POS_DESIGNED       0
#define POS_DEFAULT        1
#define POS_SCREENCENTER   2
#define POS_DESKTOPCENTER  3
#define POS_MAINFORMCENTER 4

/* WindowState constants */
#define WS_NORMAL    0
#define WS_MINIMIZED 1
#define WS_MAXIMIZED 2

/* FormStyle constants */
#define FS_NORMAL      0
#define FS_STAYONTOP   1
#define FS_MDICHILD    2
#define FS_MDIFORM     3

/* Cursor constants */
#define CR_DEFAULT    0
#define CR_ARROW      1
#define CR_IBEAM      2
#define CR_CROSS      3
#define CR_HAND       4
#define CR_SIZENESW   5
#define CR_SIZENS     6
#define CR_SIZENWSE   7
#define CR_SIZEWE     8
#define CR_WAIT       9
#define CR_HELP      10
#define CR_NO        11

/* --- HBForm --- */
@interface HBForm : HBControl <NSWindowDelegate>
{
@public
   NSWindow * FWindow;
   NSFont *   FFormFont;
   BOOL       FCenter;
   BOOL       FSizable;
   BOOL       FAppBar;
   int        FModalResult;
   BOOL       FRunning;
   BOOL       FWasRunning;      /* was in modal [NSApp run] loop when close was requested */
   BOOL       FDesignMode;
   HBControl * FSelected[MAX_CHILDREN];
   int        FSelCount;
   BOOL       FDragging, FResizing;
   int        FResizeHandle;
   int        FDragStartX, FDragStartY;
   PHB_ITEM   FOnSelChange;
   NSView *   FOverlayView;
   HBFlippedView * FContentView;
   /* Toolbars (up to 4 rows, stacked vertically) */
   HBToolBar * FToolBars[4];
   int         FToolBarCount;
   int         FClientTop;
   /* Menu */
   PHB_ITEM    FMenuActions[MAX_MENUITEMS];
   int         FMenuItemCount;
   /* Component drop from palette */
   int         FPendingControlType;  /* -1 = none, CT_LABEL..CT_GROUPBOX */
   /* Captured at the moment component-drop starts: the currently selected
    * auto-page panel (if any), so newly dropped controls can be owned by
    * that TPageControl page even though selection is cleared for rubber band. */
   HBControl * FPendingOwner;
   int         FPendingOwnerPage;
   PHB_ITEM    FOnComponentDrop;     /* callback( hForm, nControlType, nLeft, nTop, nWidth, nHeight ) */
   /* C++Builder TForm properties */
   int        FBorderStyle;     /* BS_NONE..BS_SIZETOOLWIN */
   int        FBorderIcons;     /* bitmask: 1=SystemMenu, 2=Minimize, 4=Maximize, 8=Help */
   int        FPosition;        /* POS_DESIGNED..POS_MAINFORMCENTER */
   int        FWindowState;     /* WS_NORMAL..WS_MAXIMIZED */
   int        FFormStyle;       /* FS_NORMAL..FS_MDIFORM */
   BOOL       FKeyPreview;
   BOOL       FAlphaBlend;
   int        FAlphaBlendValue; /* 0..255 */
   int        FCursor;          /* CR_DEFAULT..CR_NO */
   BOOL       FShowHint;
   char       FHint[256];
   BOOL       FAutoScroll;
   BOOL       FDoubleBuffered;
   int        FBorderWidth;
   char       FAppTitle[128];    /* Application menu title (main form only) */
   /* Events */
   PHB_ITEM   FOnActivate;
   PHB_ITEM   FOnDeactivate;
   PHB_ITEM   FOnResize;
   PHB_ITEM   FOnPaint;
   PHB_ITEM   FOnShow;
   PHB_ITEM   FOnHide;
   PHB_ITEM   FOnCloseQuery;
   PHB_ITEM   FOnCreate;
   PHB_ITEM   FOnDestroy;
   PHB_ITEM   FOnKeyDown;
   PHB_ITEM   FOnKeyUp;
   PHB_ITEM   FOnKeyPress;
   PHB_ITEM   FOnMouseDown;
   PHB_ITEM   FOnMouseUp;
   PHB_ITEM   FOnMouseMove;
   PHB_ITEM   FOnDblClick;
   PHB_ITEM   FOnMouseWheel;
}
- (void)run;
- (void)showOnly;  /* Create + show without entering run loop */
- (int)showModal;  /* Show as modal, block until closed, return FModalResult */
- (void)close;
- (void)center;
- (void)createAllChildren;
- (void)setDesignMode:(BOOL)design;
- (HBControl *)hitTestControl:(NSPoint)point;
- (int)hitTestHandle:(NSPoint)point;
- (void)selectControl:(HBControl *)ctrl add:(BOOL)add;
- (void)clearSelection;
- (BOOL)isSelected:(HBControl *)ctrl;
- (void)notifySelChange;
@end

/* Form content view: fires form OnClick/OnMouseDown/OnMouseUp events at runtime */
@interface HBFormContentView : HBFlippedView
{
@public
   HBForm * __unsafe_unretained form;
}
@end

/* --- HBLabel --- */
@interface HBLabel : HBControl
@end

/* --- HBEdit --- */
@interface HBEdit : HBControl
{
@public
   BOOL FReadOnly, FPassword;
}
@end

/* --- HBButton --- */
@interface HBButton : HBControl
{
@public
   BOOL FDefault, FCancel;
}
- (void)buttonClicked:(id)sender;
@end

/* --- HBCheckBox --- */
@interface HBCheckBox : HBControl
{
@public
   BOOL FChecked;
}
- (void)setChecked:(BOOL)checked;
@end

/* --- HBComboBox --- */
@interface HBComboBox : HBControl
{
@public
   int  FItemIndex;
   char FItems[32][64];
   int  FItemCount;
}
- (void)addItem:(const char *)item;
- (void)setItemIndex:(int)idx;
@end

/* --- HBGroupBox --- */
@interface HBGroupBox : HBControl
@end

/* --- HBToolBar --- */

@interface HBToolBar : HBControl
{
@public
   char     FBtnTexts[MAX_TOOLBTNS][32];
   char     FBtnTooltips[MAX_TOOLBTNS][128];
   BOOL     FBtnSeparator[MAX_TOOLBTNS];
   PHB_ITEM FBtnOnClick[MAX_TOOLBTNS];
   int      FBtnCount;
   NSMutableArray * FIconImages;
}
- (int)addButton:(const char *)text tooltip:(const char *)tooltip;
- (void)addSeparator;
- (void)setBtnClick:(int)idx block:(PHB_ITEM)block;
- (void)doCommand:(int)idx;
- (int)barHeight;
@end

/* --- HBOverlayView --- */
@interface HBOverlayView : NSView
{
@public
   HBForm * __unsafe_unretained form;
   BOOL isRubberBand;
   NSPoint rubberOrigin, rubberCurrent;
}
@end

/* --- HBBrowseDelegate (data source/delegate for TBrowse NSTableView) --- */
@interface HBBrowseDelegate : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
@public
    int browseIdx;  /* index into s_browses */
}
@end

/* ======================================================================
 * ALL @implementation sections
 * ====================================================================== */

/* --- HBFormContentView implementation --- */

@implementation HBFormContentView
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {
   if( form && !form->FDesignMode ) {
      if( ((HBControl *)form)->FOnClick )
         [((HBControl *)form) fireEvent:((HBControl *)form)->FOnClick];
      if( form->FOnMouseDown )
         [((HBControl *)form) fireEvent:form->FOnMouseDown];
   }
}
- (void)mouseUp:(NSEvent *)event {
   if( form && !form->FDesignMode ) {
      if( form->FOnMouseUp )
         [((HBControl *)form) fireEvent:form->FOnMouseUp];
   }
}
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent *)event {
   if( form && !form->FDesignMode ) {
      if( form->FOnKeyDown )
         [((HBControl *)form) fireEvent:form->FOnKeyDown];
      if( form->FOnKeyPress )
         [((HBControl *)form) fireEvent:form->FOnKeyPress];
   }
}
- (void)keyUp:(NSEvent *)event {
   if( form && !form->FDesignMode ) {
      if( form->FOnKeyUp )
         [((HBControl *)form) fireEvent:form->FOnKeyUp];
   }
}
@end

/* --- HBControl implementation --- */

/* HBTabDelegate — routes NSTabView selection changes to show/hide owned
 * controls based on FOwnerCtrl + FOwnerPage. Also updates the designer
 * overlay so selection handles re-render. */
static void HBUpdateTabVisibility( HBControl * owner );

@interface HBTabDelegate : NSObject <NSTabViewDelegate>
{
@public
   __weak HBControl * ownerCtrl;
}
@end

@implementation HBTabDelegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
   (void)tabView; (void)tabViewItem;
   HBControl * o = ownerCtrl;
   if( !o || !o->FCtrlParent ) return;
   HBUpdateTabVisibility( o );
}
@end

id HBMakeTabDelegate( HBControl * owner )
{
   HBTabDelegate * d = [[HBTabDelegate alloc] init];
   d->ownerCtrl = owner;
   /* Keep alive via static list so ARC doesn't dealloc */
   static NSMutableArray * s_keep = nil;
   if( !s_keep ) s_keep = [NSMutableArray array];
   [s_keep addObject:d];
   return d;
}

static int HBTabSelectedIndex( HBControl * owner )
{
   if( !owner || owner->FControlType != CT_TABCONTROL2 || !owner->FView ) return 0;
   NSTabView * tv = (NSTabView *) owner->FView;
   NSTabViewItem * sel = [tv selectedTabViewItem];
   if( !sel ) return 0;
   return (int) [tv indexOfTabViewItem:sel];
}

static void HBUpdateTabVisibility( HBControl * owner )
{
   if( !owner || !owner->FCtrlParent ) return;
   HBControl * form = owner->FCtrlParent;
   int sel = HBTabSelectedIndex( owner );
   for( int i = 0; i < form->FChildCount; i++ ) {
      HBControl * c = form->FChildren[i];
      if( c && c->FOwnerCtrl == owner && c->FView ) {
         BOOL visible = ( c->FOwnerPage == sel );
         [c->FView setHidden:!visible];
      }
   }
   if( [form isKindOfClass:[HBForm class]] ) {
      HBForm * f = (HBForm *) form;
      if( f->FOverlayView ) [(NSView *)f->FOverlayView setNeedsDisplay:YES];
   }
}

/* Pending page ownership set by TFolderPage:hCpp access; applied to the
 * next control added to a form. Used so `OF ::oFolder:aPages[n]` reads
 * naturally while the backend stays flat. */
static HBControl * s_pendingFolder = nil;
static int         s_pendingPage   = 0;

/* NSOutlineView data source: hierarchical items backed by a pipe-separated
 * string on the owning HBControl. Leading spaces define the level
 * (2 spaces = 1 indent). Items are wrapped in NSNumber with the flat index;
 * children are computed by walking the list with level info. */
@interface HBTreeDataSource : NSObject <NSOutlineViewDataSource>
{
@public
   __weak HBControl * owner;
   NSMutableArray * items;   /* parsed: array of @{ @"text":..., @"level":... } */
}
- (void)rebuild;
@end

@implementation HBTreeDataSource
- (void)rebuild
{
   items = [NSMutableArray array];
   HBControl * o = owner;
   if( !o || !o->FHeaders[0] ) return;
   NSString * s = [NSString stringWithUTF8String:o->FHeaders];
   for( NSString * raw in [s componentsSeparatedByString:@"|"] ) {
      int lvl = 0;
      NSUInteger i = 0, n = [raw length];
      while( i + 1 < n && [raw characterAtIndex:i] == ' ' &&
             [raw characterAtIndex:i+1] == ' ' ) { lvl++; i += 2; }
      NSString * txt = [raw substringFromIndex:i];
      if( [txt length] > 0 )
         [items addObject:@{ @"text": txt, @"level": @(lvl) }];
   }
}
- (NSInteger)indexOfItem:(id)item
{
   if( !item ) return -1;
   return [items indexOfObjectIdenticalTo:item];
}
- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{
   (void)ov;
   if( !items ) [self rebuild];
   NSInteger startLvl, startIdx;
   if( item == nil ) { startLvl = -1; startIdx = -1; }
   else {
      startIdx = [self indexOfItem:item];
      if( startIdx < 0 ) return 0;
      startLvl = [item[@"level"] integerValue];
   }
   NSInteger count = 0;
   for( NSInteger i = startIdx + 1; i < (NSInteger)[items count]; i++ ) {
      NSInteger lvl = [items[i][@"level"] integerValue];
      if( lvl <= startLvl ) break;
      if( lvl == startLvl + 1 ) count++;
   }
   return count;
}
- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item
{
   (void)ov;
   if( !items ) [self rebuild];
   NSInteger startLvl, startIdx;
   if( item == nil ) { startLvl = -1; startIdx = -1; }
   else {
      startIdx = [self indexOfItem:item];
      if( startIdx < 0 ) return nil;
      startLvl = [item[@"level"] integerValue];
   }
   NSInteger seen = 0;
   for( NSInteger i = startIdx + 1; i < (NSInteger)[items count]; i++ ) {
      NSInteger lvl = [items[i][@"level"] integerValue];
      if( lvl <= startLvl ) break;
      if( lvl == startLvl + 1 ) {
         if( seen == index ) return items[i];
         seen++;
      }
   }
   return nil;
}
- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
   return [self outlineView:ov numberOfChildrenOfItem:item] > 0;
}
- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)col byItem:(id)item
{ (void)ov; (void)col; return item[@"text"]; }
@end

@implementation HBControl

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TControl" );
      FName[0] = 0; FText[0] = 0;
      FLeft = 0; FTop = 0; FWidth = 80; FHeight = 24;
      FVisible = YES; FEnabled = YES; FTabStop = YES;
      FControlType = 0; FView = nil; FFont = nil; FBgColor = nil;
      FClrPane = 0xFFFFFFFF; FClrText = 0xFFFFFFFF; FFileName[0] = '\0'; strcpy(FRdd, "DBFCDX");
      FHeaders[0] = '\0'; FData[0] = '\0'; FDataSource[0] = '\0'; FActive = NO;
      FOnClick = NULL; FOnChange = NULL; FOnInit = NULL; FOnClose = NULL;
      FOnTimer = NULL; FInterval = 1000; FTimer = nil;
      FCtrlParent = nil; FChildCount = 0;
      memset( FChildren, 0, sizeof(FChildren) );
      FOwnerCtrl = nil; FOwnerPage = 0; FAutoPage = NO; FTransparent = NO; nAlign = 0;
   }
   return self;
}

- (void)dealloc { [self releaseEvents]; }

- (void)addChild:(HBControl *)child
{
   if( FChildCount < MAX_CHILDREN ) {
      FChildren[FChildCount++] = child;
      child->FCtrlParent = self;
      /* Apply pending page owner set by TFolderPage:hCpp */
      if( s_pendingFolder && !child->FOwnerCtrl ) {
         child->FOwnerCtrl = s_pendingFolder;
         child->FOwnerPage = s_pendingPage;
         s_pendingFolder = nil;
         s_pendingPage = 0;
      }
   }
}

- (void)setText:(const char *)text
{
   strncpy( FText, text, sizeof(FText) - 1 );
   FText[sizeof(FText) - 1] = 0;
}

- (void)createViewInParent:(NSView *)parentView {
   /* Generic view creation for new control types */
   if( FView ) return;  /* already created by subclass */
   NSView * v = nil;
   switch( FControlType ) {
      case CT_MEMO: {
         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         NSTextView * tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,FWidth,FHeight)];
         [tv setEditable:YES]; [tv setRichText:NO];
         if( FText[0] ) [tv setString:[NSString stringWithUTF8String:FText]];
         [sv setDocumentView:tv]; [sv setHasVerticalScroller:YES];
         [sv setBorderType:NSBezelBorder]; v = sv; break;
      }
      case CT_PANEL: {
         NSBox * box = [[NSBox alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [box setBoxType:NSBoxPrimary]; [box setTitlePosition:NSNoTitle];
         v = box; break;
      }
      case CT_LISTBOX: {
         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         NSTableView * tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0,0,FWidth,FHeight)];
         NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:@"col"];
         [col setWidth:FWidth-20]; [tv addTableColumn:col]; [tv setHeaderView:nil];
         [sv setDocumentView:tv]; [sv setHasVerticalScroller:YES]; [sv setBorderType:NSBezelBorder];
         v = sv; break;
      }
      case CT_RADIO: {
         NSButton * rb = [[NSButton alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [rb setButtonType:NSButtonTypeRadio];
         NSMutableAttributedString * rbTitle = [[NSMutableAttributedString alloc]
            initWithString:[NSString stringWithUTF8String:FText]
            attributes:@{ NSForegroundColorAttributeName: [NSColor blackColor] }];
         [rb setAttributedTitle:rbTitle];
         v = rb; break;
      }
      case CT_SCROLLBAR: {
         NSScroller * sc = [[NSScroller alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         v = sc; break;
      }
      case CT_BITBTN: case CT_SPEEDBTN: {
         NSButton * btn = [[NSButton alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [btn setTitle:[NSString stringWithUTF8String:FText]];
         [btn setBezelStyle:NSBezelStyleRounded];
         if( FControlType == CT_SPEEDBTN ) [btn setBordered:NO];
         v = btn; break;
      }
      case CT_IMAGE: {
         NSImageView * iv = [[NSImageView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [iv setImageFrameStyle:NSImageFrameGrayBezel]; v = iv; break;
      }
      case CT_SHAPE: case CT_PAINTBOX: {
         NSView * dv = [[NSView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [dv setWantsLayer:YES]; dv.layer.borderWidth = 1;
         dv.layer.borderColor = [[NSColor grayColor] CGColor]; v = dv; break;
      }
      case CT_BEVEL: {
         NSBox * box = [[NSBox alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [box setBoxType:NSBoxSeparator]; v = box; break;
      }
      case CT_MASKEDIT2: case CT_LABELEDEDIT: {
         NSTextField * tf = [[NSTextField alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [tf setStringValue:@""]; [tf setBezeled:YES]; v = tf; break;
      }
      case CT_STRINGGRID: case CT_LISTVIEW: {
         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         NSTableView * tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0,0,FWidth,FHeight)];
         for( int i = 0; i < 3; i++ ) {
            NSString * ident = [NSString stringWithFormat:@"col%d", i];
            NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:ident];
            [col setWidth:60]; [[col headerCell] setStringValue:[NSString stringWithFormat:@"Col%d",i+1]];
            [tv addTableColumn:col];
         }
         [sv setDocumentView:tv]; [sv setHasVerticalScroller:YES]; [sv setBorderType:NSBezelBorder];
         v = sv; break;
      }
      case CT_SCROLLBOX: {
         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [sv setHasVerticalScroller:YES]; [sv setHasHorizontalScroller:YES];
         [sv setBorderType:NSBezelBorder]; v = sv; break;
      }
      case CT_STATICTEXT: {
         NSTextField * tf = [[NSTextField alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [tf setStringValue:[NSString stringWithUTF8String:FText]];
         [tf setEditable:NO]; [tf setBezeled:YES]; v = tf; break;
      }
      case CT_TABCONTROL2: {
         extern id HBMakeTabDelegate( HBControl * );
         NSTabView * tv = [[NSTabView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [tv setDelegate:(id<NSTabViewDelegate>) HBMakeTabDelegate(self)];
         if( FHeaders[0] == 0 ) strcpy( FHeaders, "Tab 1" );
         const char * src = FHeaders;
         int idx = 0;
         while( src && *src )
         {
            const char * sep = strchr( src, '|' );
            int len = sep ? (int)(sep - src) : (int)strlen(src);
            if( len > 0 )
            {
               NSString * lbl = [[NSString alloc] initWithBytes:src length:len encoding:NSUTF8StringEncoding];
               NSTabViewItem * it = [[NSTabViewItem alloc]
                  initWithIdentifier:[NSString stringWithFormat:@"tab%d", idx++]];
               [it setLabel:lbl];
               [it setView:[[NSView alloc] initWithFrame:NSMakeRect(0,0,10,10)]];
               [tv addTabViewItem:it];
            }
            src = sep ? sep + 1 : NULL;
         }
         v = tv; break;
      }
      case CT_TREEVIEW: {
         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         NSOutlineView * ov = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0,0,FWidth,FHeight)];
         NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:@"tree"];
         [col setWidth:FWidth-20]; [ov addTableColumn:col]; [ov setOutlineTableColumn:col];
         [ov setHeaderView:nil]; [sv setDocumentView:ov]; [sv setHasVerticalScroller:YES];
         [sv setBorderType:NSBezelBorder];
         HBTreeDataSource * ds = [[HBTreeDataSource alloc] init];
         ds->owner = self;
         [ov setDataSource:ds];
         static NSMutableArray * s_treeDS = nil;
         if( !s_treeDS ) s_treeDS = [NSMutableArray array];
         [s_treeDS addObject:ds];
         [ov reloadData];
         v = sv; break;
      }
      case CT_PROGRESSBAR: {
         NSProgressIndicator * pi = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [pi setIndeterminate:NO]; [pi setDoubleValue:0]; v = pi; break;
      }
      case CT_RICHEDIT: {
         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         NSTextView * tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,FWidth,FHeight)];
         [tv setRichText:YES]; [sv setDocumentView:tv]; [sv setHasVerticalScroller:YES];
         [sv setBorderType:NSBezelBorder]; v = sv; break;
      }
      case CT_TRACKBAR: {
         NSSlider * sl = [[NSSlider alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [sl setMinValue:0]; [sl setMaxValue:10]; v = sl; break;
      }
      case CT_UPDOWN: {
         NSStepper * st = [[NSStepper alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [st setMinValue:0]; [st setMaxValue:100]; v = st; break;
      }
      case CT_DATETIMEPICKER: {
         NSDatePicker * dp = [[NSDatePicker alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [dp setDatePickerStyle:NSTextFieldAndStepperDatePickerStyle];
         [dp setDatePickerElements:NSYearMonthDayDatePickerElementFlag]; v = dp; break;
      }
      case CT_MONTHCALENDAR: {
         NSDatePicker * dp = [[NSDatePicker alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         [dp setDatePickerStyle:NSClockAndCalendarDatePickerStyle];
         [dp setDatePickerElements:NSYearMonthDayDatePickerElementFlag]; v = dp; break;
      }
      case CT_BROWSE: {
         if( s_nBrowses >= MAX_BROWSES ) { v = nil; break; }
         int bi = s_nBrowses++;
         memset( (void*)&s_browses[bi], 0, sizeof(BrowseData) );
         s_browses[bi].pCtrl = self;
         s_browses[bi].rowData = [[NSMutableArray alloc] init];

         NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(FLeft,FTop,FWidth,FHeight)];
         NSTableView * tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0,0,FWidth,FHeight)];
         [tv setUsesAlternatingRowBackgroundColors:YES];
         [tv setGridStyleMask:NSTableViewSolidHorizontalGridLineMask|NSTableViewSolidVerticalGridLineMask];
         [tv setAllowsColumnReordering:YES];
         [tv setAllowsColumnResizing:YES];

         HBBrowseDelegate * del = [[HBBrowseDelegate alloc] init];
         del->browseIdx = bi;
         [tv setDataSource:del];
         [tv setDelegate:del];

         s_browses[bi].tableView = tv;
         s_browses[bi].scrollView = sv;
         [sv setDocumentView:tv];
         [sv setHasVerticalScroller:YES];
         [sv setHasHorizontalScroller:YES];
         [sv setBorderType:NSBezelBorder];

         /* If FHeaders was set before view creation, create columns now */
         if( FHeaders[0] )
         {
            BrowseData * bd = &s_browses[bi];
            const char * src = FHeaders;
            while( src && *src )
            {
               const char * sep = strchr( src, '|' );
               int len = sep ? (int)(sep - src) : (int)strlen(src);
               if( len > 0 && bd->nColCount < MAX_BROWSE_COLS )
               {
                  int idx = bd->nColCount++;
                  memset( bd->cols[idx].szTitle, 0, 64 );
                  if( len > 63 ) len = 63;
                  memcpy( bd->cols[idx].szTitle, src, (size_t)len );
                  int colW = FColWidths[idx] > 0 ? FColWidths[idx] : 100;
                  bd->cols[idx].nWidth = colW;
                  bd->cols[idx].nAlign = 0;
                  bd->cols[idx].szFieldName[0] = 0;

                  NSString * ident = [NSString stringWithFormat:@"%d", idx];
                  NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:ident];
                  [col setWidth:colW];
                  [[col headerCell] setStringValue:
                     [[NSString alloc] initWithBytes:src length:len encoding:NSUTF8StringEncoding]];
                  [tv addTableColumn:col];
               }
               src = sep ? sep + 1 : NULL;
            }
         }

         /* Apply nClrPane if it was set before the view was created */
         if( FClrPane != 0xFFFFFFFF && FBgColor ) {
            [tv setBackgroundColor:FBgColor];
            [tv setUsesAlternatingRowBackgroundColors:NO];
            [sv setDrawsBackground:YES];
            [sv setBackgroundColor:FBgColor];
            [[sv contentView] setDrawsBackground:YES];
            [(NSClipView *)[sv contentView] setBackgroundColor:FBgColor];
         }

         v = sv; break;
      }
      default: {
         /* Non-visual (Timer, Dialogs, DB components) or unknown.
          * Palette icons are laid out sequentially (imgBase + btnIdx),
          * NOT keyed by FControlType. */
         int imgIdx = -1;
         const char * btnText = NULL;
         if( s_palData ) {
            int imgBase = 0;
            for( int k = 0; k < s_palData->nTabCount && imgIdx < 0; k++ ) {
               PaletteTab * t = &s_palData->tabs[k];
               for( int i = 0; i < t->nBtnCount; i++ ) {
                  if( t->btns[i].nControlType == FControlType ) {
                     imgIdx = imgBase + i;
                     btnText = t->btns[i].szText;
                     break;
                  }
               }
               imgBase += t->nBtnCount;
            }
         }
         BOOL hasImage = ( s_palData && s_palData->palImages && imgIdx >= 0 &&
                           imgIdx < (int)[s_palData->palImages count] );
         if( hasImage ) {
            NSImageView * iv = [[NSImageView alloc] initWithFrame:NSMakeRect(FLeft,FTop,32,32)];
            [iv setImage:s_palData->palImages[imgIdx]];
            [iv setImageScaling:NSImageScaleProportionallyUpOrDown];
            [iv setEditable:NO];
            v = iv;
         } else {
            NSString * ns = btnText ? [NSString stringWithUTF8String:btnText]
                                    : [NSString stringWithUTF8String:FName[0] ? FName : FClassName];
            NSImage * img = [NSImage imageWithSize:NSMakeSize(32,32)
                                           flipped:NO
                                    drawingHandler:^BOOL(NSRect r) {
               [[NSColor colorWithCalibratedRed:0.25 green:0.45 blue:0.70 alpha:1.0] set];
               NSRectFill( r );
               NSDictionary * attrs = @{
                  NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
                  NSForegroundColorAttributeName: [NSColor whiteColor]
               };
               NSSize sz = [ns sizeWithAttributes:attrs];
               NSPoint pt = NSMakePoint( (r.size.width - sz.width)/2,
                                         (r.size.height - sz.height)/2 );
               [ns drawAtPoint:pt withAttributes:attrs];
               return YES;
            }];
            NSImageView * iv = [[NSImageView alloc] initWithFrame:NSMakeRect(FLeft,FTop,32,32)];
            [iv setImage:img];
            [iv setImageScaling:NSImageScaleNone];
            [iv setEditable:NO];
            v = iv;
         }
         break;
      }
   }
   if( v ) {
      FView = v;
      [parentView addSubview:v];
      if( FFont && [v respondsToSelector:@selector(setFont:)] ) [(id)v setFont:FFont];
   }
}

- (void)updateViewFrame
{
   if( FView ) [FView setFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
}

- (void)applyFont
{
   if( FFont && FView && [FView respondsToSelector:@selector(setFont:)] ) {
      [(id)FView setFont:FFont];
      /* For labels, adjust height to fit the font */
      if( FControlType == CT_LABEL ) {
         [(id)FView sizeToFit];
         NSRect r = [FView frame];
         FHeight = (int)r.size.height;
         r.origin.x = FLeft; r.origin.y = FTop; r.size.width = FWidth;
         [FView setFrame:r];
         /* Redraw overlay so selection handles match new size */
         if( FCtrlParent && ((HBForm *)FCtrlParent)->FOverlayView )
            [((HBForm *)FCtrlParent)->FOverlayView setNeedsDisplay:YES];
      }
   }
}

- (void)setEvent:(const char *)event block:(PHB_ITEM)block
{
   PHB_ITEM * ppTarget = NULL;
   if( strcasecmp( event, "OnClick" ) == 0 )       ppTarget = &FOnClick;
   else if( strcasecmp( event, "OnChange" ) == 0 )  ppTarget = &FOnChange;
   else if( strcasecmp( event, "OnInit" ) == 0 )    ppTarget = &FOnInit;
   else if( strcasecmp( event, "OnClose" ) == 0 )   ppTarget = &FOnClose;
   else if( strcasecmp( event, "OnTimer" ) == 0 )   ppTarget = &FOnTimer;
   /* Form-specific events */
   else if( FControlType == CT_FORM ) {
      HBForm * f = (HBForm *)self;
      if( strcasecmp( event, "OnActivate" ) == 0 )       ppTarget = &f->FOnActivate;
      else if( strcasecmp( event, "OnDeactivate" ) == 0 ) ppTarget = &f->FOnDeactivate;
      else if( strcasecmp( event, "OnResize" ) == 0 )     ppTarget = &f->FOnResize;
      else if( strcasecmp( event, "OnPaint" ) == 0 )      ppTarget = &f->FOnPaint;
      else if( strcasecmp( event, "OnShow" ) == 0 )       ppTarget = &f->FOnShow;
      else if( strcasecmp( event, "OnHide" ) == 0 )       ppTarget = &f->FOnHide;
      else if( strcasecmp( event, "OnCloseQuery" ) == 0 ) ppTarget = &f->FOnCloseQuery;
      else if( strcasecmp( event, "OnCreate" ) == 0 )     ppTarget = &f->FOnCreate;
      else if( strcasecmp( event, "OnDestroy" ) == 0 )    ppTarget = &f->FOnDestroy;
      else if( strcasecmp( event, "OnKeyDown" ) == 0 )    ppTarget = &f->FOnKeyDown;
      else if( strcasecmp( event, "OnKeyUp" ) == 0 )      ppTarget = &f->FOnKeyUp;
      else if( strcasecmp( event, "OnKeyPress" ) == 0 )   ppTarget = &f->FOnKeyPress;
      else if( strcasecmp( event, "OnMouseDown" ) == 0 )  ppTarget = &f->FOnMouseDown;
      else if( strcasecmp( event, "OnMouseUp" ) == 0 )    ppTarget = &f->FOnMouseUp;
      else if( strcasecmp( event, "OnMouseMove" ) == 0 )  ppTarget = &f->FOnMouseMove;
      else if( strcasecmp( event, "OnDblClick" ) == 0 )   ppTarget = &f->FOnDblClick;
      else if( strcasecmp( event, "OnMouseWheel" ) == 0 ) ppTarget = &f->FOnMouseWheel;
   }
   if( ppTarget ) {
      if( *ppTarget ) hb_itemRelease( *ppTarget );
      *ppTarget = hb_itemNew( block );
   }
   /* Auto-start timer when OnTimer is assigned */
   if( FControlType == CT_TIMER && FOnTimer && FEnabled && FInterval > 0 )
      [self startTimer];
}

- (void)fireEvent:(PHB_ITEM)block
{
   if( block && HB_IS_BLOCK( block ) ) {
      if( hb_vmRequestReenter() ) {
         hb_vmPushEvalSym();
         hb_vmPush( block );
         hb_vmSend( 0 );
         hb_vmRequestRestore();
      }
   }
}

- (void)releaseEvents
{
   if( FOnClick )  { hb_itemRelease( FOnClick );  FOnClick = NULL; }
   if( FOnChange ) { hb_itemRelease( FOnChange ); FOnChange = NULL; }
   if( FOnInit )   { hb_itemRelease( FOnInit );   FOnInit = NULL; }
   if( FOnClose )  { hb_itemRelease( FOnClose );  FOnClose = NULL; }
   if( FOnTimer )  { hb_itemRelease( FOnTimer );  FOnTimer = NULL; }
   [self stopTimer];
}

- (void)startTimer
{
   [self stopTimer];
   if( FControlType == CT_TIMER && FEnabled && FInterval > 0 && FOnTimer )
   {
      FTimer = [NSTimer scheduledTimerWithTimeInterval:FInterval / 1000.0
                                               target:self
                                             selector:@selector(timerFired:)
                                             userInfo:nil
                                              repeats:YES];
   }
}

- (void)stopTimer
{
   if( FTimer ) { [FTimer invalidate]; FTimer = nil; }
}

- (void)timerFired:(NSTimer *)timer
{
   if( FOnTimer ) [self fireEvent:FOnTimer];
}

@end

/* --- HBLabel implementation --- */

@implementation HBLabel

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TLabel" );
      FControlType = CT_LABEL; FWidth = 80; FHeight = 15; FTabStop = NO; FTransparent = YES;
      strcpy( FText, "Label" );
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   NSTextField * tf = [[NSTextField alloc] initWithFrame:
      NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   [tf setStringValue:[NSString stringWithUTF8String:FText]];
   [tf setBezeled:NO];
   if( FClrPane != 0xFFFFFFFF ) {
      [tf setDrawsBackground:YES];
      if( FBgColor ) [tf setBackgroundColor:FBgColor];
   } else {
      [tf setDrawsBackground:!FTransparent];
   }
   [tf setEditable:NO]; [tf setSelectable:NO];
   if( nAlign == 1 ) [tf setAlignment:NSTextAlignmentCenter];
   else if( nAlign == 2 ) [tf setAlignment:NSTextAlignmentRight];
   if( FClrText != 0xFFFFFFFF ) {
      CGFloat r = (FClrText & 0xFF)/255.0, g = ((FClrText>>8)&0xFF)/255.0, b = ((FClrText>>16)&0xFF)/255.0;
      [tf setTextColor:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]];
   } else {
      [tf setTextColor:[NSColor blackColor]];
   }
   if( FFont ) {
      [tf setFont:FFont];
      /* Adjust height to fit the font */
      [tf sizeToFit];
      NSRect r = [tf frame];
      FHeight = (int)r.size.height;
      r.origin.x = FLeft; r.origin.y = FTop; r.size.width = FWidth;
      [tf setFrame:r];
   }
   [tf setAllowsEditingTextAttributes:NO];
   /* Enable click handling for OnClick at runtime */
   NSClickGestureRecognizer * click = [[NSClickGestureRecognizer alloc]
      initWithTarget:self action:@selector(labelClicked:)];
   [tf addGestureRecognizer:click];
   [parentView addSubview:tf];
   FView = tf;
}

- (void)labelClicked:(id)sender
{
   if( FOnClick ) [self fireEvent:FOnClick];
}

@end

/* --- HBEdit implementation --- */

@implementation HBEdit

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TEdit" );
      FControlType = CT_EDIT; FWidth = 200; FHeight = 24;
      FReadOnly = NO; FPassword = NO;
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   NSTextField * tf;
   if( FPassword )
      tf = [[NSSecureTextField alloc] initWithFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   else
      tf = [[NSTextField alloc] initWithFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   [tf setStringValue:[NSString stringWithUTF8String:FText]];
   [tf setBezeled:YES]; [tf setBezelStyle:NSTextFieldSquareBezel];
   [tf setEditable:!FReadOnly];
   [tf setTextColor:[NSColor blackColor]];
   if( nAlign == 1 ) [tf setAlignment:NSTextAlignmentCenter];
   else if( nAlign == 2 ) [tf setAlignment:NSTextAlignmentRight];
   if( FFont ) [tf setFont:FFont];
   [parentView addSubview:tf];
   FView = tf;
}

@end

/* --- HBButton implementation --- */

@implementation HBButton

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TButton" );
      FControlType = CT_BUTTON; FWidth = 88; FHeight = 26;
      FDefault = NO; FCancel = NO;
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   NSButton * btn = [[NSButton alloc] initWithFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   NSString * title = [[NSString stringWithUTF8String:FText]
      stringByReplacingOccurrencesOfString:@"&" withString:@""];
   [btn setTitle:title];
   [btn setBezelStyle:NSBezelStyleRegularSquare];
   [btn setButtonType:NSButtonTypeMomentaryPushIn];
   if( FDefault ) [btn setKeyEquivalent:@"\r"];
   if( FCancel )  [btn setKeyEquivalent:@"\033"];
   if( FFont ) [btn setFont:FFont];
   btn.wantsLayer = YES;
   btn.layer.masksToBounds = YES;
   btn.layer.cornerRadius = 6.0;
   btn.layer.backgroundColor = [[NSColor controlColor] CGColor];
   [btn setTarget:self]; [btn setAction:@selector(buttonClicked:)];
   [parentView addSubview:btn];
   FView = btn;
}

- (void)buttonClicked:(id)sender
{
   [self fireEvent:FOnClick];

   /* Find parent form */
   HBControl * p = FCtrlParent;
   while( p && p->FControlType != CT_FORM ) p = p->FCtrlParent;

   if( p ) {
      HBForm * frm = (HBForm *)p;
      if( FDefault ) frm->FModalResult = 1;
      else if( FCancel ) frm->FModalResult = 2;
      if( FDefault || FCancel ) [frm close];
   }
}

@end

/* --- HBCheckBox implementation --- */

@implementation HBCheckBox

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TCheckBox" );
      FControlType = CT_CHECKBOX; FWidth = 150; FHeight = 19; FChecked = NO;
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   NSButton * btn = [[NSButton alloc] initWithFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   [btn setButtonType:NSButtonTypeSwitch];
   [btn setTitle:[NSString stringWithUTF8String:FText]];
   NSMutableAttributedString * cbTitle = [[NSMutableAttributedString alloc]
      initWithString:[NSString stringWithUTF8String:FText]
      attributes:@{ NSForegroundColorAttributeName: [NSColor blackColor] }];
   [btn setAttributedTitle:cbTitle];
   if( FChecked ) [btn setState:NSControlStateValueOn];
   if( FFont ) [btn setFont:FFont];
   [parentView addSubview:btn];
   FView = btn;
}

- (void)setChecked:(BOOL)checked
{
   FChecked = checked;
   if( FView ) [(NSButton *)FView setState:checked ? NSControlStateValueOn : NSControlStateValueOff];
}

@end

/* --- HBComboBox implementation --- */

@implementation HBComboBox

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TComboBox" );
      FControlType = CT_COMBOBOX; FWidth = 175; FHeight = 26;
      FItemIndex = 0; FItemCount = 0;
      memset( FItems, 0, sizeof(FItems) );
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   /* In Win32, combobox height is the dropdown height, not the control height.
      NSPopUpButton has a fixed intrinsic height (~26px). Use that instead. */
   CGFloat popupHeight = 26;
   NSPopUpButton * popup = [[NSPopUpButton alloc] initWithFrame:
      NSMakeRect( FLeft, FTop, FWidth, popupHeight ) pullsDown:NO];
   for( int i = 0; i < FItemCount; i++ )
      [popup addItemWithTitle:[NSString stringWithUTF8String:FItems[i]]];
   if( FItemIndex >= 0 && FItemIndex < FItemCount )
      [popup selectItemAtIndex:FItemIndex];
   if( FFont ) [popup setFont:FFont];
   [popup setTarget:self]; [popup setAction:@selector(comboChanged:)];
   [parentView addSubview:popup];
   FView = popup;
   FHeight = (int)popupHeight;
}

- (void)comboChanged:(id)sender
{
   FItemIndex = (int)[(NSPopUpButton *)FView indexOfSelectedItem];
   [self fireEvent:FOnChange];
}

- (void)addItem:(const char *)item
{
   if( FItemCount < 32 ) strncpy( FItems[FItemCount++], item, 63 );
   if( FView ) [(NSPopUpButton *)FView addItemWithTitle:[NSString stringWithUTF8String:item]];
}

- (void)setItemIndex:(int)idx
{
   FItemIndex = idx;
   if( FView && idx >= 0 ) [(NSPopUpButton *)FView selectItemAtIndex:idx];
}

@end

/* --- HBGroupBox implementation --- */

@implementation HBGroupBox

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TGroupBox" );
      FControlType = CT_GROUPBOX; FWidth = 200; FHeight = 100; FTabStop = NO;
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   NSBox * box = [[NSBox alloc] initWithFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   [box setTitle:[NSString stringWithUTF8String:FText]];
   [box setTitlePosition:NSAtTop];
   [box setBorderColor:[NSColor grayColor]];
   if( FFont ) [box setTitleFont:FFont];
   [parentView addSubview:box];
   FView = box;
}

@end

/* --- HBToolBar implementation --- */

@implementation HBToolBar

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TToolBar" );
      FControlType = CT_TOOLBAR; FBtnCount = 0;
      memset( FBtnOnClick, 0, sizeof(FBtnOnClick) );
   }
   return self;
}

- (void)dealloc
{
   for( int i = 0; i < FBtnCount; i++ )
      if( FBtnOnClick[i] ) hb_itemRelease( FBtnOnClick[i] );
}

- (void)createViewInParent:(NSView *)parentView
{
   /* Create a horizontal stack of buttons as a toolbar strip.
      Width is sized to fit content, not the parent. */
   NSView * toolbar = [[HBFlippedView alloc] initWithFrame:NSMakeRect( 0, 0, 100, 30 )];

   /* Toolbar background — inherits from parent window appearance */
   toolbar.wantsLayer = YES;
   toolbar.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.22 alpha:1.0] CGColor];

   int btnW = 24, btnH = 24;
   int xPos = 4;
   int yOff = 2;
   for( int i = 0; i < FBtnCount; i++ )
   {
      if( FBtnSeparator[i] ) {
         NSBox * sep = [[NSBox alloc] initWithFrame:NSMakeRect( xPos, yOff + 2, 1, btnH - 4 )];
         [sep setBoxType:NSBoxSeparator];
         [toolbar addSubview:sep];
         xPos += 8;
      } else {
         /* Measure text width to size button */
         NSString * title = [NSString stringWithUTF8String:FBtnTexts[i]];
         NSFont * btnFont = [NSFont systemFontOfSize:11];
         NSDictionary * attrs = @{ NSFontAttributeName: btnFont };
         CGFloat textW = [title sizeWithAttributes:attrs].width;
         int thisBtnW = (int)(textW + 16);
         if( thisBtnW < btnW ) thisBtnW = btnW;

         NSButton * btn = [[NSButton alloc] initWithFrame:NSMakeRect( xPos, yOff, thisBtnW, btnH )];
         [btn setTitle:title];
         [btn setToolTip:[NSString stringWithUTF8String:FBtnTooltips[i]]];
         [btn setBezelStyle:NSBezelStyleSmallSquare];
         [btn setFont:btnFont];
         [btn setTarget:self];
         [btn setAction:@selector(toolBtnClicked:)];
         [btn setTag:i];
         [toolbar addSubview:btn];
         xPos += thisBtnW + 2;
      }
   }

   /* Size toolbar to fit its content, position at FTop for stacking */
   int tbHeight = btnH + yOff * 2;
   [toolbar setFrame:NSMakeRect( 0, FTop, xPos + 4, tbHeight )];
   FWidth = xPos + 4;
   FHeight = tbHeight;

   [parentView addSubview:toolbar];
   FView = toolbar;

   /* Apply stored icon images if available */
   if( FIconImages && [FIconImages count] > 0 )
   {
      int imgIdx = 0;
      xPos = 4;
      for( NSView * sv in [toolbar subviews] )
      {
         if( imgIdx >= (int)[FIconImages count] ) break;
         if( ![sv isKindOfClass:[NSButton class]] ) continue;

         NSButton * btn = (NSButton *)sv;
         NSImage * img = FIconImages[imgIdx];
         [img setSize:NSMakeSize(20, 20)];
         [btn setImage:img];
         [btn setImagePosition:NSImageOnly];
         [btn setTitle:@""];
         [btn setBordered:NO];
         NSRect f = [btn frame];
         f.size.width = 28;
         f.size.height = 28;
         [btn setFrame:f];
         imgIdx++;
      }
      /* Re-layout with new sizes */
      xPos = 4;
      int maxH = 0;
      for( NSView * sv in [toolbar subviews] )
      {
         NSRect f = [sv frame];
         f.origin.x = xPos;
         f.origin.y = 2;
         [sv setFrame:f];
         if( (int)f.size.height > maxH ) maxH = (int)f.size.height;
         if( [sv isKindOfClass:[NSBox class]] )
            xPos += 8;
         else
            xPos += (int)f.size.width + 2;
      }
      FWidth = xPos + 4;
      tbHeight = maxH + 4;
      FHeight = tbHeight;
      [toolbar setFrame:NSMakeRect( 0, FTop, FWidth, tbHeight )];
   }
}

- (void)toolBtnClicked:(id)sender
{
   int idx = (int)[sender tag];
   [self doCommand:idx];
}

- (int)addButton:(const char *)text tooltip:(const char *)tooltip
{
   if( FBtnCount >= MAX_TOOLBTNS ) return -1;
   int idx = FBtnCount++;
   strncpy( FBtnTexts[idx], text, 31 ); FBtnTexts[idx][31] = 0;
   strncpy( FBtnTooltips[idx], tooltip, 127 ); FBtnTooltips[idx][127] = 0;
   FBtnSeparator[idx] = NO;
   FBtnOnClick[idx] = NULL;
   return idx;
}

- (void)addSeparator
{
   if( FBtnCount >= MAX_TOOLBTNS ) return;
   FBtnSeparator[FBtnCount] = YES;
   FBtnTexts[FBtnCount][0] = 0;
   FBtnTooltips[FBtnCount][0] = 0;
   FBtnOnClick[FBtnCount] = NULL;
   FBtnCount++;
}

- (void)setBtnClick:(int)idx block:(PHB_ITEM)block
{
   if( idx < 0 || idx >= FBtnCount ) return;
   if( FBtnOnClick[idx] ) hb_itemRelease( FBtnOnClick[idx] );
   FBtnOnClick[idx] = hb_itemNew( block );
}

- (void)doCommand:(int)idx
{
   if( idx >= 0 && idx < FBtnCount && FBtnOnClick[idx] ) {
      hb_vmPushEvalSym();
      hb_vmPush( FBtnOnClick[idx] );
      hb_vmSend( 0 );
   }
}

- (int)barHeight { return FView ? (int)[FView frame].size.height : 36; }

@end

/* --- HBSplitterView implementation --- */

@interface HBSplitterView : NSView
{
@public
   PALDATA * palData;
   CGFloat dragStartX;
   CGFloat startSplitPos;
}
@end

@implementation HBSplitterView

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (NSView *)hitTest:(NSPoint)point
{
   /* Always capture clicks in our bounds */
   NSPoint local = [self convertPoint:point fromView:[self superview]];
   if( NSPointInRect( local, [self bounds] ) ) return self;
   return nil;
}

- (void)drawRect:(NSRect)dirtyRect
{
   [[NSColor colorWithCalibratedWhite:0.70 alpha:1.0] setFill];
   NSRectFill( [self bounds] );
   /* Draw grip dots */
   [[NSColor colorWithCalibratedWhite:0.45 alpha:1.0] setFill];
   CGFloat midX = [self bounds].size.width / 2;
   CGFloat midY = [self bounds].size.height / 2;
   for( int i = -2; i <= 2; i++ )
      NSRectFill( NSMakeRect( midX - 1, midY + i * 4, 3, 2 ) );
}

- (void)resetCursorRects
{
   [self addCursorRect:[self bounds] cursor:[NSCursor resizeLeftRightCursor]];
}

- (void)mouseDown:(NSEvent *)event
{
   dragStartX = [event locationInWindow].x;
   startSplitPos = palData ? palData->nSplitPos : 0;
   [[NSCursor resizeLeftRightCursor] push];
}

- (void)mouseDragged:(NSEvent *)event
{
   if( !palData ) return;
   CGFloat dx = [event locationInWindow].x - dragStartX;
   int newPos = (int)(startSplitPos + dx);
   if( newPos < 80 ) newPos = 80;
   if( newPos > 600 ) newPos = 600;
   palData->nSplitPos = newPos;

   int splW = 8;
   CGFloat segH = 24;
   NSRect containerBounds = [palData->containerView bounds];
   [palData->splitterView setFrame:NSMakeRect( newPos, 0, splW, containerBounds.size.height )];
   CGFloat rightX = newPos + splW;
   CGFloat rightW = containerBounds.size.width - rightX;
   [palData->btnPanel setFrame:NSMakeRect( rightX, 0, rightW, containerBounds.size.height - segH - 2 )];
   [palData->segmented setFrame:NSMakeRect( rightX + 4, containerBounds.size.height - segH - 1, rightW - 8, segH )];

   /* Resize all toolbars to new splitter position */
   if( palData->parentForm ) {
      for( int t = 0; t < palData->parentForm->FToolBarCount; t++ ) {
         if( palData->parentForm->FToolBars[t] && palData->parentForm->FToolBars[t]->FView ) {
            NSRect tbFrame = [palData->parentForm->FToolBars[t]->FView frame];
            tbFrame.size.width = newPos;
            [palData->parentForm->FToolBars[t]->FView setFrame:tbFrame];
         }
      }
   }
}

- (void)mouseUp:(NSEvent *)event
{
   [NSCursor pop];
}

@end

/* --- HBPaletteTarget --- */

@interface HBPaletteTarget : NSObject
{
@public
   PALDATA * palData;
}
- (void)tabChanged:(id)sender;
- (void)palBtnClicked:(id)sender;
@end

@implementation HBPaletteTarget

- (void)tabChanged:(id)sender
{
   if( palData ) {
      int sel = (int)[palData->segmented selectedSegment];
      PalShowTab( palData, sel );
   }
}

- (void)palBtnClicked:(id)sender
{
   NSLog(@"[HB] palBtnClicked entry palData=%p", palData);
   if( !palData ) return;

   /* Find which button was clicked */
   PaletteTab * t = &palData->tabs[palData->nCurrentTab];
   int btnIdx = -1;
   for( int i = 0; i < t->nBtnCount; i++ ) {
      if( palData->buttons[i] == sender ) { btnIdx = i; break; }
   }
   if( btnIdx < 0 ) return;

   int ctrlType = t->btns[btnIdx].nControlType;
   NSLog(@"[HB] palBtnClicked ctrlType=%d btnIdx=%d tooltip=%s", ctrlType, btnIdx, t->btns[btnIdx].szTooltip);

   /* Set pending drop mode on the design form (not the IDE bar) */
   HBForm * targetForm = s_designForm;
   if( !targetForm || !targetForm->FDesignMode ) { NSLog(@"[HB] no design form"); return; }
   NSLog(@"[HB] targetForm=%p FChildCount=%d", targetForm, targetForm->FChildCount);

   /* Check if non-visual component (auto-drop, no click needed) */
   int isNonVisual = 0;
   if( ctrlType == CT_TIMER || ctrlType == CT_PAINTBOX ) isNonVisual = 1;
   if( ctrlType >= CT_OPENDIALOG && ctrlType <= CT_REPLACEDIALOG ) isNonVisual = 1;
   if( ctrlType >= CT_OPENAI && ctrlType <= CT_TRANSFORMER ) isNonVisual = 1;
   if( ctrlType >= CT_DBFTABLE && ctrlType <= CT_MONGODB ) isNonVisual = 1;
   if( ctrlType >= CT_THREAD && ctrlType <= CT_CHANNEL ) isNonVisual = 1;
   if( ctrlType >= CT_WEBSERVER && ctrlType <= CT_UDPSOCKET ) isNonVisual = 1;
   if( ctrlType >= CT_PREPROCESSOR && ctrlType <= CT_SCHEDULER ) isNonVisual = 1;
   if( ctrlType >= CT_PRINTER && ctrlType <= CT_BARCODEPRINTER ) isNonVisual = 1;
   if( ctrlType >= 110 ) isNonVisual = 1; /* Whisper, Embeddings, Connectivity, Git */

   NSLog(@"[HB] isNonVisual=%d", isNonVisual);
   if( isNonVisual )
   {
      NSLog(@"[HB] entering nonVisual path");
      /* Auto-drop: create non-visual component icon at bottom of form */
      int nNV = 0;
      for( int ci = 0; ci < targetForm->FChildCount; ci++ )
         if( targetForm->FChildren[ci]->FWidth == 32 &&
             targetForm->FChildren[ci]->FHeight == 32 )
            nNV++;
      int nx = 8 + (nNV % 8) * 40;
      int ny = targetForm->FHeight - 80 + (nNV / 8) * 40;
      if( ny < 40 ) ny = 40;

      HBControl * ctrl = [[HBControl alloc] init];
      ctrl->FControlType = ctrlType;
      ctrl->FLeft = nx;
      ctrl->FTop = ny;
      ctrl->FWidth = 32;
      ctrl->FHeight = 32;
      strncpy( ctrl->FClassName, t->btns[btnIdx].szTooltip, sizeof(ctrl->FClassName) - 1 );

      KeepAlive( ctrl );
      [targetForm addChild:ctrl];

      /* Create the view: palette icon image (or text fallback).
       * Icons in palette.bmp are laid out sequentially across tabs, so the
       * image index is the palette position (imgBase + btnIdx), not ctrlType. */
      if( targetForm->FContentView ) {
         int imgBase = 0;
         for( int k = 0; k < palData->nCurrentTab; k++ )
            imgBase += palData->tabs[k].nBtnCount;
         int imgIdx = imgBase + btnIdx;
         BOOL hasImage = ( palData->palImages && imgIdx >= 0 &&
                           imgIdx < (int)[palData->palImages count] );
         if( hasImage ) {
            NSImageView * iv = [[NSImageView alloc] initWithFrame:
               NSMakeRect( nx, ny + targetForm->FClientTop, 32, 32 )];
            [iv setImage:palData->palImages[imgIdx]];
            [iv setImageScaling:NSImageScaleProportionallyUpOrDown];
            [iv setEditable:NO];
            ctrl->FView = (NSView *)iv;
            [targetForm->FContentView addSubview:iv];
         } else {
            /* Fallback when no BMP icon is available: render a 32x32 image
             * in code (blue square with the palette's short label) so the
             * view is an NSImageView (does not intercept mouse events). */
            NSString * ns = [NSString stringWithUTF8String:t->btns[btnIdx].szText];
            NSImage * img = [NSImage imageWithSize:NSMakeSize(32,32)
                                           flipped:NO
                                    drawingHandler:^BOOL(NSRect r) {
               [[NSColor colorWithCalibratedRed:0.25 green:0.45 blue:0.70 alpha:1.0] set];
               NSRectFill( r );
               NSDictionary * attrs = @{
                  NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
                  NSForegroundColorAttributeName: [NSColor whiteColor]
               };
               NSSize sz = [ns sizeWithAttributes:attrs];
               NSPoint pt = NSMakePoint( (r.size.width - sz.width)/2,
                                         (r.size.height - sz.height)/2 );
               [ns drawAtPoint:pt withAttributes:attrs];
               return YES;
            }];
            NSImageView * iv = [[NSImageView alloc] initWithFrame:
               NSMakeRect( nx, ny + targetForm->FClientTop, 32, 32 )];
            [iv setImage:img];
            [iv setImageScaling:NSImageScaleNone];
            [iv setEditable:NO];
            ctrl->FView = (NSView *)iv;
            [targetForm->FContentView addSubview:iv];
         }
      }

      /* Select the new control */
      targetForm->FSelCount = 1;
      targetForm->FSelected[0] = ctrl;

      /* Fire OnComponentDrop callback */
      if( targetForm->FOnComponentDrop &&
          HB_IS_BLOCK( targetForm->FOnComponentDrop ) )
      {
         hb_vmPushEvalSym();
         hb_vmPush( targetForm->FOnComponentDrop );
         hb_vmPushNumInt( (HB_PTRUINT) targetForm );
         hb_vmPushInteger( ctrlType );
         hb_vmPushInteger( nx );
         hb_vmPushInteger( ny );
         hb_vmPushInteger( 32 );
         hb_vmPushInteger( 32 );
         hb_vmSend( 6 );
      }

      if( targetForm->FOverlayView )
         [targetForm->FOverlayView setNeedsDisplay:YES];
   }
   else
   {
      /* Visual control: set pending, wait for click on form */
      targetForm->FPendingControlType = ctrlType;
      [[NSCursor crosshairCursor] set];
   }
}

@end

static HBPaletteTarget * s_palTarget = nil;

/* --- HBOverlayView implementation --- */

@implementation HBOverlayView

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event; return YES; }

- (NSView *)hitTest:(NSPoint)point
{
   (void)point;
   if( form && form->FDesignMode ) return self;
   return nil;
}

- (void)drawRect:(NSRect)dirtyRect
{
   if( !form ) return;

   /* Dot grid is drawn by FContentView (HBFlippedView::drawRect) */

   NSColor * handleColor = [NSColor colorWithCalibratedRed:0.0 green:0.47 blue:0.84 alpha:1.0];

   for( int i = 0; i < form->FSelCount; i++ )
   {
      HBControl * ctrl = form->FSelected[i];
      NSRect bounds = NSMakeRect( ctrl->FLeft, ctrl->FTop, ctrl->FWidth, ctrl->FHeight );

      /* Dashed border */
      NSBezierPath * border = [NSBezierPath bezierPathWithRect:NSInsetRect( bounds, -1, -1 )];
      CGFloat pattern[] = { 4, 2 };
      [border setLineDash:pattern count:2 phase:0];
      [border setLineWidth:1.0];
      [handleColor set];
      [border stroke];

      /* 8 handles */
      int px = ctrl->FLeft, py = ctrl->FTop, pw = ctrl->FWidth, ph = ctrl->FHeight;
      NSPoint handles[8] = {
         { px-3, py-3 }, { px+pw/2-3, py-3 }, { px+pw-3, py-3 },
         { px+pw-3, py+ph/2-3 }, { px+pw-3, py+ph-3 },
         { px+pw/2-3, py+ph-3 }, { px-3, py+ph-3 }, { px-3, py+ph/2-3 }
      };

      for( int j = 0; j < 8; j++ ) {
         NSRect hr = NSMakeRect( handles[j].x, handles[j].y, 7, 7 );
         [[NSColor whiteColor] setFill]; NSRectFill( hr );
         [handleColor setStroke]; [NSBezierPath strokeRect:hr];
      }
   }

   /* Rubber band */
   if( isRubberBand ) {
      CGFloat rx = fmin(rubberOrigin.x, rubberCurrent.x);
      CGFloat ry = fmin(rubberOrigin.y, rubberCurrent.y);
      CGFloat rw = fabs(rubberCurrent.x - rubberOrigin.x);
      CGFloat rh = fabs(rubberCurrent.y - rubberOrigin.y);
      NSBezierPath * rbPath = [NSBezierPath bezierPathWithRect:NSMakeRect(rx,ry,rw,rh)];
      CGFloat pat[] = { 3, 3 };
      [rbPath setLineDash:pat count:2 phase:0];
      [handleColor set]; [rbPath stroke];
      [[handleColor colorWithAlphaComponent:0.1] setFill];
      NSRectFillUsingOperation( NSMakeRect(rx,ry,rw,rh), NSCompositingOperationSourceOver );
   }
}

- (void)mouseDown:(NSEvent *)event
{
   if( !form || !form->FDesignMode ) return;
   NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];
   BOOL isShift = ([event modifierFlags] & NSEventModifierFlagShift) != 0;

   /* Component drop mode: start rubber band to define new control area */
   if( form->FPendingControlType >= 0 ) {
      /* Capture current auto-page selection before clearing */
      form->FPendingOwner = nil;
      form->FPendingOwnerPage = 0;
      if( form->FSelCount >= 1 ) {
         HBControl * sel = form->FSelected[0];
         if( sel && sel->FAutoPage && sel->FOwnerCtrl ) {
            form->FPendingOwner = sel->FOwnerCtrl;
            form->FPendingOwnerPage = sel->FOwnerPage;
         }
      }
      [form clearSelection];
      isRubberBand = YES;
      rubberOrigin = pt; rubberCurrent = pt;
      return;
   }

   int nHandle = [form hitTestHandle:pt];
   if( nHandle >= 0 ) {
      /* Auto-page panels: ignore handles; geometry is set by TPageControl. */
      if( form->FSelCount == 1 && form->FSelected[0]->FAutoPage ) {
         return;
      }
      /* Block resize for non-visual components (32x32 fixed) */
      if( form->FSelCount == 1 &&
          form->FSelected[0]->FWidth == 32 && form->FSelected[0]->FHeight == 32 )
      {
         /* Start drag instead of resize */
         form->FDragging = YES;
         form->FDragStartX = (int)pt.x; form->FDragStartY = (int)pt.y;
      } else {
         form->FResizing = YES; form->FResizeHandle = nHandle;
         form->FDragStartX = (int)pt.x; form->FDragStartY = (int)pt.y;
      }
      return;
   }

   HBControl * hit = [form hitTestControl:pt];

   /* TPageControl tab-bar click: switch tab, then fall through to normal
    * select/drag so the user can still move the control from the tab bar. */
   if( hit && hit->FControlType == CT_TABCONTROL2 &&
       pt.y >= hit->FTop && pt.y <= hit->FTop + 24 )
   {
      NSTabView * tv = (NSTabView *) hit->FView;
      if( tv ) {
         NSInteger nItems = [[tv tabViewItems] count];
         if( nItems > 0 ) {
            CGFloat tabW = hit->FWidth / (CGFloat) nItems;
            NSInteger idx = (NSInteger) ((pt.x - hit->FLeft) / tabW);
            if( idx < 0 ) idx = 0;
            if( idx >= nItems ) idx = nItems - 1;
            [tv selectTabViewItemAtIndex:idx];
         }
      }
   }

   /* Auto-page panels: selectable (as drop target) but not movable/resizable.
    * Their geometry is controlled by the owning TPageControl. */
   if( hit && hit->FAutoPage ) {
      if( ![form isSelected:hit] ) [form selectControl:hit add:NO];
      return;
   }

   if( hit ) {
      if( isShift ) {
         if( [form isSelected:hit] ) {
            for( int k = 0; k < form->FSelCount; k++ )
               if( form->FSelected[k] == hit ) {
                  form->FSelected[k] = form->FSelected[--form->FSelCount]; break;
               }
            [self setNeedsDisplay:YES];
         } else
            [form selectControl:hit add:YES];
      } else {
         if( ![form isSelected:hit] ) [form selectControl:hit add:NO];
         form->FDragging = YES;
         form->FDragStartX = (int)pt.x; form->FDragStartY = (int)pt.y;
      }
   } else {
      [form clearSelection];
      isRubberBand = YES;
      rubberOrigin = pt; rubberCurrent = pt;
   }
}

- (void)mouseDragged:(NSEvent *)event
{
   if( !form || !form->FDesignMode ) return;
   NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];

   if( isRubberBand ) {
      rubberCurrent = pt; [self setNeedsDisplay:YES]; return;
   }

   if( form->FResizing && form->FSelCount > 0 ) {
      int dx = (int)pt.x - form->FDragStartX, dy = (int)pt.y - form->FDragStartY;
      HBControl * p = form->FSelected[0];
      int nl = p->FLeft, nt = p->FTop, nw = p->FWidth, nh = p->FHeight;
      dx = (dx/8)*8; dy = (dy/8)*8;
      if( dx == 0 && dy == 0 ) return;
      switch( form->FResizeHandle ) {
         case 0: nl+=dx; nt+=dy; nw-=dx; nh-=dy; break;
         case 1: nt+=dy; nh-=dy; break;
         case 2: nw+=dx; nt+=dy; nh-=dy; break;
         case 3: nw+=dx; break;
         case 4: nw+=dx; nh+=dy; break;
         case 5: nh+=dy; break;
         case 6: nl+=dx; nw-=dx; nh+=dy; break;
         case 7: nl+=dx; nw-=dx; break;
      }
      if( nw < 20 ) { nw = 20; nl = p->FLeft; }
      if( nh < 10 ) { nh = 10; nt = p->FTop; }
      p->FLeft = nl; p->FTop = nt; p->FWidth = nw; p->FHeight = nh;
      [p updateViewFrame];
      form->FDragStartX += dx; form->FDragStartY += dy;
      [self setNeedsDisplay:YES]; [form notifySelChange];
      return;
   }

   if( form->FDragging && form->FSelCount > 0 ) {
      int dx = (int)pt.x - form->FDragStartX, dy = (int)pt.y - form->FDragStartY;
      dx = (dx/8)*8; dy = (dy/8)*8;
      if( dx == 0 && dy == 0 ) return;
      for( int i = 0; i < form->FSelCount; i++ ) {
         HBControl * s = form->FSelected[i];
         if( s->FAutoPage ) continue; /* pages follow their TPageControl */
         s->FLeft += dx; s->FTop += dy;
         [s updateViewFrame];
         /* If moving a TPageControl, translate all its owned controls too */
         if( s->FControlType == CT_TABCONTROL2 ) {
            for( int k = 0; k < form->FChildCount; k++ ) {
               HBControl * c = form->FChildren[k];
               if( c && c->FOwnerCtrl == s ) {
                  c->FLeft += dx; c->FTop += dy;
                  [c updateViewFrame];
               }
            }
         }
      }
      form->FDragStartX += dx; form->FDragStartY += dy;
      [self setNeedsDisplay:YES]; [form notifySelChange];
   }
}

- (void)mouseUp:(NSEvent *)event
{
   if( !form || !form->FDesignMode ) return;

   if( isRubberBand ) {
      isRubberBand = NO;
      int rx1 = (int)fmin(rubberOrigin.x, rubberCurrent.x);
      int ry1 = (int)fmin(rubberOrigin.y, rubberCurrent.y);
      int rx2 = (int)fmax(rubberOrigin.x, rubberCurrent.x);
      int ry2 = (int)fmax(rubberOrigin.y, rubberCurrent.y);
      int rw = rx2 - rx1, rh = ry2 - ry1;

      /* Component drop mode: create the control at drawn rectangle */
      if( form->FPendingControlType >= 0 ) {
         int ctrlType = form->FPendingControlType;
         form->FPendingControlType = -1;  /* reset */
         [[NSCursor arrowCursor] set];

         /* Enforce minimum size */
         if( rw < 20 ) rw = 80;
         if( rh < 10 ) rh = 24;

         /* Snap to 4-pixel grid */
         rx1 = (rx1 / 8) * 8;
         ry1 = (ry1 / 8) * 8;

         /* Create the control in C */
         HBControl * newCtrl = nil;
         switch( ctrlType ) {
            case CT_LABEL: {
               HBLabel * p = [[HBLabel alloc] init];
               [p setText:"Label"]; p->FLeft=rx1; p->FTop=ry1; p->FWidth=rw; p->FHeight=rh;
               newCtrl = p; break;
            }
            case CT_EDIT: {
               HBEdit * p = [[HBEdit alloc] init];
               p->FLeft=rx1; p->FTop=ry1; p->FWidth=rw; p->FHeight=rh;
               newCtrl = p; break;
            }
            case CT_BUTTON: {
               HBButton * p = [[HBButton alloc] init];
               [p setText:"Button"]; p->FLeft=rx1; p->FTop=ry1; p->FWidth=rw; p->FHeight=rh;
               newCtrl = p; break;
            }
            case CT_CHECKBOX: {
               HBCheckBox * p = [[HBCheckBox alloc] init];
               [p setText:"CheckBox"]; p->FLeft=rx1; p->FTop=ry1; p->FWidth=rw; p->FHeight=rh;
               newCtrl = p; break;
            }
            case CT_COMBOBOX: {
               HBComboBox * p = [[HBComboBox alloc] init];
               p->FLeft=rx1; p->FTop=ry1; p->FWidth=rw; p->FHeight=rh;
               newCtrl = p; break;
            }
            case CT_GROUPBOX: {
               HBGroupBox * p = [[HBGroupBox alloc] init];
               [p setText:"GroupBox"]; p->FLeft=rx1; p->FTop=ry1; p->FWidth=rw; p->FHeight=rh;
               newCtrl = p; break;
            }
            default: {
               /* Generic: all new control types use base HBControl */
               static struct { int type; const char * cls; const char * text; int dw; int dh; } defs[] = {
                  { CT_MEMO,       "TMemo",           "",           180, 80  },
                  { CT_PANEL,      "TPanel",          "Panel",      185, 41  },
                  { CT_LISTBOX,    "TListBox",        "",           120, 80  },
                  { CT_RADIO,      "TRadioButton",    "RadioButton",120, 20  },
                  { CT_SCROLLBAR,  "TScrollBar",      "",           150, 17  },
                  { CT_BITBTN,     "TBitBtn",         "BitBtn",      88, 26  },
                  { CT_SPEEDBTN,   "TSpeedButton",    "Speed",       23, 22  },
                  { CT_IMAGE,      "TImage",          "",           100, 100 },
                  { CT_SHAPE,      "TShape",          "",            65,  65 },
                  { CT_BEVEL,      "TBevel",          "",           150,  50 },
                  { CT_MASKEDIT2,  "TMaskEdit",       "",           120,  24 },
                  { CT_STRINGGRID, "TStringGrid",     "",           200, 120 },
                  { CT_SCROLLBOX,  "TScrollBox",      "",           185, 140 },
                  { CT_STATICTEXT, "TStaticText",     "StaticText",  65,  17 },
                  { CT_LABELEDEDIT,"TLabeledEdit",    "",           120,  24 },
                  { CT_TABCONTROL2,"TFolder",         "",           200, 150 },
                  { CT_TREEVIEW,   "TTreeView",       "",           150, 200 },
                  { CT_LISTVIEW,   "TListView",       "",           200, 150 },
                  { CT_PROGRESSBAR,"TProgressBar",    "",           150,  20 },
                  { CT_RICHEDIT,   "TRichEdit",       "",           200, 100 },
                  { CT_TRACKBAR,   "TTrackBar",       "",           150,  25 },
                  { CT_UPDOWN,     "TUpDown",         "",            50,  22 },
                  { CT_DATETIMEPICKER,"TDateTimePicker","",          186,  24 },
                  { CT_MONTHCALENDAR,"TMonthCalendar","",            227, 155 },
                  { CT_PAINTBOX,   "TPaintBox",       "",           105, 105 },
                  { CT_TIMER,      "TTimer",          "",            32,  32 },
                  { CT_OPENDIALOG, "TOpenDialog",     "",            32,  32 },
                  { CT_SAVEDIALOG, "TSaveDialog",     "",            32,  32 },
                  { CT_FONTDIALOG, "TFontDialog",     "",            32,  32 },
                  { CT_COLORDIALOG,"TColorDialog",    "",            32,  32 },
                  { CT_FINDDIALOG, "TFindDialog",     "",            32,  32 },
                  { CT_REPLACEDIALOG,"TReplaceDialog","",            32,  32 },
                  { CT_OPENAI,     "TOpenAI",         "",            32,  32 },
                  { CT_GEMINI,     "TGemini",         "",            32,  32 },
                  { CT_CLAUDE,     "TClaude",         "",            32,  32 },
                  { CT_DEEPSEEK,   "TDeepSeek",       "",            32,  32 },
                  { CT_GROK,       "TGrok",           "",            32,  32 },
                  { CT_OLLAMA,     "TOllama",         "",            32,  32 },
                  { CT_TRANSFORMER,"TTransformer",    "",            32,  32 },
                  { CT_DBFTABLE,   "TDBFTable",       "",            32,  32 },
                  { CT_MYSQL,      "TMySQL",          "",            32,  32 },
                  { CT_MARIADB,    "TMariaDB",        "",            32,  32 },
                  { CT_POSTGRESQL, "TPostgreSQL",     "",            32,  32 },
                  { CT_SQLITE,     "TSQLite",         "",            32,  32 },
                  { CT_FIREBIRD,   "TFirebird",       "",            32,  32 },
                  { CT_SQLSERVER,  "TSQLServer",      "",            32,  32 },
                  { CT_ORACLE,     "TOracle",         "",            32,  32 },
                  { CT_MONGODB,    "TMongoDB",        "",            32,  32 },
                  { CT_WEBVIEW,    "TWebView",        "",           320, 240 },
                  { CT_THREAD,     "TThread",         "",            32,  32 },
                  { CT_MUTEX,      "TMutex",          "",            32,  32 },
                  { CT_SEMAPHORE,  "TSemaphore",      "",            32,  32 },
                  { CT_CRITICALSECTION,"TCriticalSection","",        32,  32 },
                  { CT_THREADPOOL, "TThreadPool",     "",            32,  32 },
                  { CT_ATOMICINT,  "TAtomicInt",      "",            32,  32 },
                  { CT_CONDVAR,    "TCondVar",        "",            32,  32 },
                  { CT_CHANNEL,    "TChannel",        "",            32,  32 },
                  { CT_WEBSERVER,  "TWebServer",      "",            32,  32 },
                  { CT_WEBSOCKET,  "TWebSocket",      "",            32,  32 },
                  { CT_HTTPCLIENT, "THttpClient",     "",            32,  32 },
                  { CT_FTPCLIENT,  "TFtpClient",      "",            32,  32 },
                  { CT_SMTPCLIENT, "TSmtpClient",     "",            32,  32 },
                  { CT_TCPSERVER,  "TTcpServer",      "",            32,  32 },
                  { CT_TCPCLIENT,  "TTcpClient",      "",            32,  32 },
                  { CT_UDPSOCKET,  "TUdpSocket",      "",            32,  32 },
                  { CT_BROWSE,     "TBrowse",         "",           400, 200 },
                  { CT_DBGRID,     "TDBGrid",         "",           400, 200 },
                  { CT_DBNAVIGATOR,"TDBNavigator",    "",           240,  28 },
                  { CT_DBTEXT,     "TDBText",         "",            80,  20 },
                  { CT_DBEDIT,     "TDBEdit",         "",           120,  24 },
                  { CT_DBCOMBOBOX, "TDBComboBox",     "",           120,  24 },
                  { CT_DBCHECKBOX, "TDBCheckBox",     "",           120,  20 },
                  { CT_DBIMAGE,    "TDBImage",        "",           100, 100 },
                  { CT_PREPROCESSOR,"TPreprocessor", "",            32,  32 },
                  { CT_SCRIPTENGINE,"TScriptEngine", "",            32,  32 },
                  { CT_REPORTDESIGNER,"TReportDesigner","",         32,  32 },
                  { CT_BARCODE,    "TBarcode",        "",            32,  32 },
                  { CT_PDFGENERATOR,"TPDFGenerator",  "",            32,  32 },
                  { CT_EXCELEXPORT,"TExcelExport",    "",            32,  32 },
                  { CT_AUDITLOG,   "TAuditLog",       "",            32,  32 },
                  { CT_PERMISSIONS,"TPermissions",    "",            32,  32 },
                  { CT_CURRENCY,   "TCurrency",       "",            32,  32 },
                  { CT_TAXENGINE,  "TTaxEngine",      "",            32,  32 },
                  { CT_DASHBOARD,  "TDashboard",      "",           200, 150 },
                  { CT_SCHEDULER,  "TScheduler",      "",           300, 200 },
                  { CT_PRINTER,    "TPrinter",        "",            32,  32 },
                  { CT_REPORT,     "TReport",         "",            32,  32 },
                  { CT_LABELS,     "TLabels",         "",            32,  32 },
                  { CT_PRINTPREVIEW,"TPrintPreview",  "",           400, 300 },
                  { CT_PAGESETUP,  "TPageSetup",      "",            32,  32 },
                  { CT_PRINTDIALOG,"TPrintDialog",    "",            32,  32 },
                  { CT_REPORTVIEWER,"TReportViewer",  "",           400, 300 },
                  { CT_BARCODEPRINTER,"TBarcodePrinter","",          32,  32 },
                  { 0, NULL, NULL, 0, 0 }
               };
               for( int i = 0; defs[i].cls; i++ ) {
                  if( defs[i].type == ctrlType ) {
                     HBControl * p = [[HBControl alloc] init];
                     strcpy(p->FClassName, defs[i].cls);
                     p->FControlType = ctrlType;
                     if( defs[i].text[0] ) [p setText:defs[i].text];
                     p->FLeft=rx1; p->FTop=ry1;
                     p->FWidth = rw > 10 ? rw : defs[i].dw;
                     p->FHeight = rh > 10 ? rh : defs[i].dh;
                     newCtrl = p;
                     break;
                  }
               }
               break;
            }
         }

         if( newCtrl ) {
            KeepAlive( newCtrl );
            newCtrl->FFont = form->FFormFont;

            /* TPageControl ownership: if the drop rect's center falls inside a
             * TTabControl/TPageControl content area, assign to its selected tab.
             * Fallback: if an auto-page TPanel is currently selected in the
             * designer, use its owner + page. */
            if( ctrlType != CT_TABCONTROL2 && ctrlType != CT_PANEL ) {
               int cx = rx1 + (rw > 0 ? rw / 2 : 10);
               int cy = ry1 + (rh > 0 ? rh / 2 : 10);
               HBControl * ownerPC = nil;
               int ownerPage = 0;
               for( int i = 0; i < form->FChildCount; i++ ) {
                  HBControl * pc = form->FChildren[i];
                  if( pc && pc->FControlType == CT_TABCONTROL2 &&
                      cx >= pc->FLeft && cx <= pc->FLeft + pc->FWidth &&
                      cy >= pc->FTop + 24 && cy <= pc->FTop + pc->FHeight )
                  {
                     ownerPC = pc;
                     ownerPage = HBTabSelectedIndex( pc );
                     break;
                  }
               }
               if( !ownerPC && form->FPendingOwner ) {
                  ownerPC = form->FPendingOwner;
                  ownerPage = form->FPendingOwnerPage;
               }
               if( ownerPC ) {
                  newCtrl->FOwnerCtrl = ownerPC;
                  newCtrl->FOwnerPage = ownerPage;
               }
            }

            [form addChild:newCtrl];
            [newCtrl createViewInParent:form->FContentView];

            /* Move overlay to front (must stay on top of all children) */
            if( form->FOverlayView )
               [form->FContentView addSubview:(NSView *)form->FOverlayView
                                   positioned:NSWindowAbove relativeTo:nil];

            /* Select the new control */
            [form selectControl:newCtrl add:NO];

            /* Fire Harbour callback */
            if( form->FOnComponentDrop && HB_IS_BLOCK( form->FOnComponentDrop ) ) {
               hb_vmPushEvalSym();
               hb_vmPush( form->FOnComponentDrop );
               hb_vmPushNumInt( (HB_PTRUINT)(__bridge void *)form );
               hb_vmPushInteger( ctrlType );
               hb_vmPushInteger( rx1 );
               hb_vmPushInteger( ry1 );
               hb_vmPushInteger( rw );
               hb_vmPushInteger( rh );
               hb_vmSend( 6 );
            }
         }
         [self setNeedsDisplay:YES];
         return;
      }

      /* Normal rubber band: select controls inside rectangle */
      [form clearSelection];
      for( int i = 0; i < form->FChildCount; i++ ) {
         HBControl * p = form->FChildren[i];
         if( p->FControlType == CT_GROUPBOX ) continue;
         if( p->FLeft + p->FWidth > rx1 && p->FLeft < rx2 &&
             p->FTop + p->FHeight > ry1 && p->FTop < ry2 )
            if( form->FSelCount < MAX_CHILDREN )
               form->FSelected[form->FSelCount++] = p;
      }
      [self setNeedsDisplay:YES]; [form notifySelChange];
      return;
   }

   if( form->FDragging || form->FResizing ) {
      form->FDragging = NO; form->FResizing = NO; form->FResizeHandle = -1;
      [self setNeedsDisplay:YES]; [form notifySelChange];
   }
}

- (void)keyDown:(NSEvent *)event
{
   if( !form || !form->FDesignMode ) return;
   unsigned short keyCode = [event keyCode];

   if( (keyCode == 51 || keyCode == 117) && form->FSelCount > 0 ) {
      for( int i = 0; i < form->FSelCount; i++ )
         if( form->FSelected[i]->FView ) {
            [form->FSelected[i]->FView removeFromSuperview];
            form->FSelected[i]->FView = nil;
         }
      [form clearSelection]; return;
   }

   NSString * chars = [event charactersIgnoringModifiers];
   if( [chars length] > 0 && form->FSelCount > 0 ) {
      unichar ch = [chars characterAtIndex:0];
      int dx = 0, dy = 0, step = ([event modifierFlags] & NSEventModifierFlagShift) ? 1 : 8;
      switch( ch ) {
         case NSLeftArrowFunctionKey:  dx = -step; break;
         case NSRightArrowFunctionKey: dx = step;  break;
         case NSUpArrowFunctionKey:    dy = -step; break;
         case NSDownArrowFunctionKey:  dy = step;  break;
         default: [super keyDown:event]; return;
      }
      for( int i = 0; i < form->FSelCount; i++ ) {
         form->FSelected[i]->FLeft += dx; form->FSelected[i]->FTop += dy;
         [form->FSelected[i] updateViewFrame];
      }
      [self setNeedsDisplay:YES]; [form notifySelChange];
   }
}

@end

/* --- HBForm implementation --- */

@implementation HBForm

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TForm" );
      FControlType = CT_FORM;
      FFormFont = [NSFont systemFontOfSize:12];
      FFont = FFormFont;
      FCenter = YES; FSizable = NO; FAppBar = NO; FModalResult = 0; FRunning = NO; FDesignMode = NO;
      FSelCount = 0; FDragging = NO; FResizing = NO; FResizeHandle = -1;
      FOnSelChange = NULL; FOverlayView = nil; FContentView = nil;
      memset(FToolBars, 0, sizeof(FToolBars)); FToolBarCount = 0;
      FClientTop = 0; FMenuItemCount = 0;
      FPendingControlType = -1; FOnComponentDrop = NULL;
      memset( FSelected, 0, sizeof(FSelected) );
      memset( FMenuActions, 0, sizeof(FMenuActions) );
      FWidth = 470; FHeight = 400;
      strcpy( FText, "New Form" );
      FClrPane = 0x00F0F0F0;
      FWindow = nil;
      /* C++Builder defaults */
      FBorderStyle = BS_SIZEABLE;
      FBorderIcons = 1 | 2 | 4;  /* biSystemMenu | biMinimize | biMaximize */
      FPosition = POS_SCREENCENTER;
      FWindowState = WS_NORMAL;
      FFormStyle = FS_NORMAL;
      FKeyPreview = NO;
      FAlphaBlend = NO;
      FAlphaBlendValue = 255;
      FCursor = CR_DEFAULT;
      FShowHint = YES;
      FHint[0] = 0;
      FAutoScroll = YES;
      FDoubleBuffered = NO;
      FBorderWidth = 0;
      FAppTitle[0] = 0;
      /* Events */
      FOnActivate = NULL; FOnDeactivate = NULL;
      FOnResize = NULL; FOnPaint = NULL;
      FOnShow = NULL; FOnHide = NULL;
      FOnCloseQuery = NULL;
      FOnCreate = NULL; FOnDestroy = NULL;
      FOnKeyDown = NULL; FOnKeyUp = NULL; FOnKeyPress = NULL;
      FOnMouseDown = NULL; FOnMouseUp = NULL; FOnMouseMove = NULL;
      FOnDblClick = NULL; FOnMouseWheel = NULL;
   }
   return self;
}

- (void)dealloc
{
   if( FOnSelChange ) { hb_itemRelease( FOnSelChange ); FOnSelChange = NULL; }
   if( FOnComponentDrop ) { hb_itemRelease( FOnComponentDrop ); FOnComponentDrop = NULL; }
   for( int i = 0; i < FMenuItemCount; i++ )
      if( FMenuActions[i] ) { hb_itemRelease( FMenuActions[i] ); FMenuActions[i] = NULL; }
   /* Release form events */
   if( FOnActivate )   { hb_itemRelease( FOnActivate );   FOnActivate = NULL; }
   if( FOnDeactivate ) { hb_itemRelease( FOnDeactivate ); FOnDeactivate = NULL; }
   if( FOnResize )     { hb_itemRelease( FOnResize );     FOnResize = NULL; }
   if( FOnPaint )      { hb_itemRelease( FOnPaint );      FOnPaint = NULL; }
   if( FOnShow )       { hb_itemRelease( FOnShow );       FOnShow = NULL; }
   if( FOnHide )       { hb_itemRelease( FOnHide );       FOnHide = NULL; }
   if( FOnCloseQuery ) { hb_itemRelease( FOnCloseQuery ); FOnCloseQuery = NULL; }
   if( FOnCreate )     { hb_itemRelease( FOnCreate );     FOnCreate = NULL; }
   if( FOnDestroy )    { hb_itemRelease( FOnDestroy );    FOnDestroy = NULL; }
   if( FOnKeyDown )    { hb_itemRelease( FOnKeyDown );    FOnKeyDown = NULL; }
   if( FOnKeyUp )      { hb_itemRelease( FOnKeyUp );      FOnKeyUp = NULL; }
   if( FOnKeyPress )   { hb_itemRelease( FOnKeyPress );   FOnKeyPress = NULL; }
   if( FOnMouseDown )  { hb_itemRelease( FOnMouseDown );  FOnMouseDown = NULL; }
   if( FOnMouseUp )    { hb_itemRelease( FOnMouseUp );    FOnMouseUp = NULL; }
   if( FOnMouseMove )  { hb_itemRelease( FOnMouseMove );  FOnMouseMove = NULL; }
   if( FOnDblClick )   { hb_itemRelease( FOnDblClick );   FOnDblClick = NULL; }
   if( FOnMouseWheel ) { hb_itemRelease( FOnMouseWheel ); FOnMouseWheel = NULL; }
}

- (void)run
{
   EnsureNSApp();

   /* Update application menu title from AppTitle property */
   if( FAppTitle[0] ) {
      NSMenu * mainMenu = [NSApp mainMenu];
      if( mainMenu && [mainMenu numberOfItems] > 0 ) {
         NSMenuItem * appItem = [mainMenu itemAtIndex:0];
         if( [appItem submenu] ) {
            NSString * title = [NSString stringWithUTF8String:FAppTitle];
            [[appItem submenu] setTitle:title];
            /* Update Quit item text */
            NSMenu * appMenu = [appItem submenu];
            for( NSInteger i = 0; i < [appMenu numberOfItems]; i++ ) {
               NSMenuItem * item = [appMenu itemAtIndex:i];
               if( [[item keyEquivalent] isEqualToString:@"q"] )
                  [item setTitle:[NSString stringWithFormat:@"Quit %@", title]];
            }
         }
      }
   }

   [self createWindowWithRunLoop:YES];
}

- (void)createWindowWithRunLoop:(BOOL)enterLoop
{
   EnsureNSApp();

   if( FWindow )
   {
      /* Window already created (by Show before Activate).
         Re-create children to pick up toolbar/palette added after Show. */
      for( NSView * sv in [[FContentView subviews] copy] )
         [sv removeFromSuperview];
      FOverlayView = nil;
      if( FDesignMode ) {
         HBDotGridView * grid = [[HBDotGridView alloc] initWithFrame:[FContentView bounds]];
         if( FBgColor ) grid->bgColor = FBgColor;
         [grid setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
         [FContentView addSubview:grid];
      }
      [self createAllChildren];
      if( FDesignMode ) {
         HBOverlayView * ov = [[HBOverlayView alloc] initWithFrame:[FContentView bounds]];
         ov->form = self;
         [ov setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
         [FContentView addSubview:ov];
         FOverlayView = ov;
         [FWindow makeFirstResponder:ov];
      }
      [FWindow makeKeyAndOrderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
      FRunning = YES;
      if( enterLoop ) {
         [NSApp run];
         FRunning = NO;
      }
      return;
   }

   NSRect frame = NSMakeRect( 0, 0, FWidth, FHeight );
   NSUInteger style = 0;

   if( FAppBar ) {
      /* AppBar: no title bar, no shadow - thin strip flush with content below */
      style = NSWindowStyleMaskBorderless;
   }
   else {
      switch( FBorderStyle ) {
         case BS_NONE:
            style = NSWindowStyleMaskBorderless;
            break;
         case BS_SINGLE:
         case BS_DIALOG:
            style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
            if( FBorderIcons & 2 ) style |= NSWindowStyleMaskMiniaturizable;
            break;
         case BS_TOOLWINDOW:
            style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  | NSWindowStyleMaskUtilityWindow;
            break;
         case BS_SIZETOOLWIN:
            style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  | NSWindowStyleMaskResizable | NSWindowStyleMaskUtilityWindow;
            break;
         case BS_SIZEABLE:
         default:
            style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
            if( FBorderIcons & 2 ) style |= NSWindowStyleMaskMiniaturizable;
            if( FBorderIcons & 4 ) style |= NSWindowStyleMaskResizable;
            break;
      }
      /* Legacy FSizable override */
      if( FSizable && FBorderStyle != BS_NONE )
         style |= NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;
   }

   FWindow = [[NSWindow alloc] initWithContentRect:frame
      styleMask:style
      backing:NSBackingStoreBuffered defer:NO];
   [FWindow setTitle:[NSString stringWithUTF8String:FText]];
   [FWindow setDelegate:self];
   [FWindow setReleasedWhenClosed:NO];
   if( FDesignMode ) {
      [FWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
      [FWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1.0]];
   } else if( FBgColor ) {
      [FWindow setBackgroundColor:FBgColor];
   }
   if( FAppBar ) [FWindow setHasShadow:NO];

   /* FormStyle: stay on top */
   if( FFormStyle == FS_STAYONTOP )
      [FWindow setLevel:NSFloatingWindowLevel];

   /* AlphaBlend */
   if( FAlphaBlend )
      [FWindow setAlphaValue:FAlphaBlendValue / 255.0];

   HBFormContentView * fcv = [[HBFormContentView alloc] initWithFrame:[[FWindow contentView] bounds]];
   fcv->form = self;
   FContentView = fcv;
   [FContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   if( FDesignMode ) {
      FContentView.wantsLayer = YES;
      FContentView.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.18 alpha:1.0] CGColor];
   }

   /* Design-time dot grid (first subview, behind all controls) */
   if( FDesignMode )
   {
      HBDotGridView * grid = [[HBDotGridView alloc] initWithFrame:[FContentView bounds]];
      if( FBgColor ) grid->bgColor = FBgColor;
      [grid setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
      [FContentView addSubview:grid];
   }
   /* Force light appearance to avoid dark mode white-on-dark text */
   if( [NSAppearance respondsToSelector:@selector(appearanceNamed:)] )
      [FWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
   if( FBgColor )
      [FWindow setBackgroundColor:FBgColor];
   else
      [FWindow setBackgroundColor:[NSColor colorWithCalibratedRed:0.94 green:0.94 blue:0.94 alpha:1.0]];
   [FWindow setContentView:FContentView];

   [self createAllChildren];

   if( FDesignMode ) {
      HBOverlayView * ov = [[HBOverlayView alloc] initWithFrame:[FContentView bounds]];
      ov->form = self;
      [ov setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
      [FContentView addSubview:ov];
      FOverlayView = ov;
      [FWindow makeFirstResponder:ov];
   }

   /* Position: FCenter is legacy, FPosition is C++Builder style */
   if( FCenter && FPosition == POS_SCREENCENTER )
      [self center];
   else {
      switch( FPosition ) {
         case POS_SCREENCENTER:
         case POS_DESKTOPCENTER:
         case POS_MAINFORMCENTER:
            [self center];
            break;
         case POS_DESIGNED:
         case POS_DEFAULT:
         default: {
            /* FTop is the distance from the top of the screen to the top
               of the window frame (title bar), FHeight is the content
               height. setFrameOrigin uses the full frame (incl. title bar)
               so we must use the frame's height, not FHeight. */
            NSRect screenFrame = [[NSScreen mainScreen] frame];
            NSRect fr = [FWindow frame];
            NSPoint origin;
            origin.x = FLeft;
            origin.y = screenFrame.size.height - FTop - fr.size.height;
            [FWindow setFrameOrigin:origin];
            break;
         }
      }
   }

   /* WindowState */
   switch( FWindowState ) {
      case WS_MINIMIZED: [FWindow miniaturize:nil]; break;
      case WS_MAXIMIZED: [FWindow zoom:nil]; break;
   }

   /* Fire OnShow */
   if( FOnShow ) [self fireEvent:FOnShow];

   [FWindow makeKeyAndOrderFront:nil];
   [NSApp activateIgnoringOtherApps:YES];

   static int s_nRunLoopDepth = 0;
   if( enterLoop ) {
      if( s_nRunLoopDepth > 0 ) {
         /* Already inside [NSApp run] — don't nest, just show */
      } else {
         FRunning = YES;
         s_nRunLoopDepth++;
         [NSApp run];
         s_nRunLoopDepth--;
         FRunning = NO;
      }
   }
}

- (void)showOnly
{
   [self createWindowWithRunLoop:NO];
}

- (int)showModal
{
   [self createWindowWithRunLoop:NO];
   FModalResult = 0;
   [NSApp runModalForWindow:FWindow];
   return FModalResult;
}

- (void)close
{
   FWasRunning = FRunning;
   FRunning = NO;
   [FWindow close];
}

- (void)center
{
   if( !FWindow ) return;
   NSRect scr = [[NSScreen mainScreen] visibleFrame];
   NSRect win = [FWindow frame];
   CGFloat x = scr.origin.x + ( scr.size.width  - win.size.width  ) / 2;
   CGFloat y = scr.origin.y + ( scr.size.height - win.size.height ) / 2;
   [FWindow setFrameOrigin:NSMakePoint( x, y )];
}

- (void)createAllChildren
{
   /* Toolbars: stack vertically, accumulate height */
   FClientTop = 0;
   for( int t = 0; t < FToolBarCount; t++ )
   {
      if( FToolBars[t] ) {
         FToolBars[t]->FWidth = FWidth;
         FToolBars[t]->FTop = FClientTop;
         [FToolBars[t] createViewInParent:FContentView];
         FClientTop += [FToolBars[t] barHeight];
      }
   }

   /* Component Palette: create tabs + splitter to the right of toolbar */
   if( s_palData && s_palData->parentForm == self && s_palData->nTabCount > 0 )
   {
      PALDATA * pd = s_palData;
      NSRect contentBounds = [FContentView bounds];
      int tbWidth = 0;
      /* Use widest toolbar as reference */
      for( int t = 0; t < FToolBarCount; t++ ) {
         if( FToolBars[t] && FToolBars[t]->FView ) {
            NSRect tbFrame = [FToolBars[t]->FView frame];
            if( (int)tbFrame.size.width > tbWidth )
               tbWidth = (int) tbFrame.size.width;
         }
      }
      pd->nSplitPos = tbWidth + 62;

      /* Container view for palette area (full width, full content height) */
      CGFloat fullH = contentBounds.size.height;
      pd->containerView = [[HBFlippedView alloc] initWithFrame:
         NSMakeRect( 0, 0, contentBounds.size.width, fullH )];
      [pd->containerView setAutoresizingMask:NSViewWidthSizable];

      /* Splitter (8px wide for easy grabbing) */
      int splW = 8;
      HBSplitterView * sp = [[HBSplitterView alloc] initWithFrame:
         NSMakeRect( pd->nSplitPos, 0, splW, fullH )];
      sp->palData = pd;
      pd->splitterView = sp;
      [pd->containerView addSubview:sp];

      /* Layout: buttons on top, tab selector at bottom of window */
      CGFloat rightX = pd->nSplitPos + splW;
      CGFloat rightW = contentBounds.size.width - rightX;
      CGFloat segH = 24;

      /* Button panel (top area, below toolbar) */
      pd->btnPanel = [[HBFlippedView alloc] initWithFrame:
         NSMakeRect( rightX, 0, rightW, fullH - segH - 2 )];
      [pd->btnPanel setAutoresizingMask:NSViewWidthSizable];
      [pd->containerView addSubview:pd->btnPanel];

      /* Segmented control for tabs (bottom) */
      pd->segmented = [NSSegmentedControl segmentedControlWithLabels:@[] trackingMode:NSSegmentSwitchTrackingSelectOne target:nil action:nil];
      [pd->segmented setSegmentCount:pd->nTabCount];
      for( int i = 0; i < pd->nTabCount; i++ )
         [pd->segmented setLabel:[NSString stringWithUTF8String:pd->tabs[i].szName] forSegment:i];
      [pd->segmented setSelectedSegment:0];
      [pd->segmented setFrame:NSMakeRect( rightX + 4, fullH - segH - 1, rightW - 8, segH )];
      [pd->segmented setAutoresizingMask:NSViewWidthSizable];
      [pd->segmented setFont:[NSFont systemFontOfSize:11]];

      s_palTarget = [[HBPaletteTarget alloc] init];
      s_palTarget->palData = pd;
      [pd->segmented setTarget:s_palTarget];
      [pd->segmented setAction:@selector(tabChanged:)];

      [pd->containerView addSubview:pd->segmented];

      [FContentView addSubview:pd->containerView];

      /* Show first tab */
      PalShowTab( pd, 0 );
   }

   /* GroupBoxes first */
   for( int i = 0; i < FChildCount; i++ )
      if( FChildren[i]->FControlType == CT_GROUPBOX ) {
         if( !FChildren[i]->FFont ) FChildren[i]->FFont = FFormFont;
         FChildren[i]->FTop += FClientTop;
         [FChildren[i] createViewInParent:FContentView];
      }
   for( int i = 0; i < FChildCount; i++ )
      if( FChildren[i]->FControlType != CT_GROUPBOX &&
          FChildren[i]->FControlType != CT_TOOLBAR &&
          !( FChildren[i]->FControlType >= CT_TIMER && !FDesignMode ) ) {
         if( !FChildren[i]->FFont ) FChildren[i]->FFont = FFormFont;
         FChildren[i]->FTop += FClientTop;
         [FChildren[i] createViewInParent:FContentView];
      }
}

- (void)setDesignMode:(BOOL)design
{
   FDesignMode = design;
   [self clearSelection];
   if( design && FContentView && !FOverlayView ) {
      HBOverlayView * ov = [[HBOverlayView alloc] initWithFrame:[FContentView bounds]];
      ov->form = self;
      [ov setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
      [FContentView addSubview:ov];
      FOverlayView = ov;
      [FWindow makeFirstResponder:ov];
   }
}

- (HBControl *)hitTestControl:(NSPoint)point
{
   int border = 8;
   HBControl * groupHit = nil;
   for( int i = FChildCount - 1; i >= 0; i-- ) {
      HBControl * p = FChildren[i];
      int l = p->FLeft, t = p->FTop, r = l + p->FWidth, b = t + p->FHeight;
      if( point.x >= l && point.x <= r && point.y >= t && point.y <= b ) {
         if( p->FControlType == CT_GROUPBOX ) {
            if( point.y <= t+18 || point.x <= l+border || point.x >= r-border || point.y >= b-border )
               if( !groupHit ) groupHit = p;
         } else
            return p;
      }
   }
   return groupHit;
}

- (int)hitTestHandle:(NSPoint)point
{
   for( int i = 0; i < FSelCount; i++ ) {
      HBControl * p = FSelected[i];
      int px=p->FLeft, py=p->FTop, pw=p->FWidth, ph=p->FHeight;
      int hx[8], hy[8];
      hx[0]=px-3; hy[0]=py-3; hx[1]=px+pw/2-3; hy[1]=py-3;
      hx[2]=px+pw-3; hy[2]=py-3; hx[3]=px+pw-3; hy[3]=py+ph/2-3;
      hx[4]=px+pw-3; hy[4]=py+ph-3; hx[5]=px+pw/2-3; hy[5]=py+ph-3;
      hx[6]=px-3; hy[6]=py+ph-3; hx[7]=px-3; hy[7]=py+ph/2-3;
      for( int j = 0; j < 8; j++ )
         if( point.x >= hx[j] && point.x <= hx[j]+7 && point.y >= hy[j] && point.y <= hy[j]+7 )
            return j;
   }
   return -1;
}

- (void)selectControl:(HBControl *)ctrl add:(BOOL)add
{
   if( !add ) { FSelCount = 0; memset( FSelected, 0, sizeof(FSelected) ); }
   if( ctrl && FSelCount < MAX_CHILDREN && ![self isSelected:ctrl] )
      FSelected[FSelCount++] = ctrl;
   if( FOverlayView ) [(NSView *)FOverlayView setNeedsDisplay:YES];
   [self notifySelChange];
}

- (void)clearSelection
{
   FSelCount = 0; memset( FSelected, 0, sizeof(FSelected) );
   if( FOverlayView ) [(NSView *)FOverlayView setNeedsDisplay:YES];
   [self notifySelChange];
}

- (BOOL)isSelected:(HBControl *)ctrl
{
   for( int i = 0; i < FSelCount; i++ )
      if( FSelected[i] == ctrl ) return YES;
   return NO;
}

- (void)notifySelChange
{
   if( FOnSelChange && HB_IS_BLOCK( FOnSelChange ) ) {
      hb_vmPushEvalSym();
      hb_vmPush( FOnSelChange );
      hb_vmPushNumInt( FSelCount > 0 ? (HB_PTRUINT) FSelected[0] : 0 );
      hb_vmSend( 1 );
   }
}

- (void)windowWillClose:(NSNotification *)notification
{
   if( FOnClose ) [self fireEvent:FOnClose];
   if( FOnHide ) [self fireEvent:FOnHide];

   /* If this window is running a modal session, end it */
   if( [NSApp modalWindow] == FWindow ) {
      [NSApp stopModal];
      FRunning = NO;
      FWasRunning = NO;
      return;
   }

   /* Only stop the run loop if this form had its own modal loop (Activate/Run) */
   BOOL wasModal = FRunning || FWasRunning;
   FRunning = NO;
   FWasRunning = NO;

   if( wasModal ) {
      [NSApp stop:nil];
      [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
         location:NSZeroPoint modifierFlags:0 timestamp:0
         windowNumber:0 context:nil subtype:0 data1:0 data2:0] atStart:YES];
   }
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
   if( FOnCloseQuery && HB_IS_BLOCK( FOnCloseQuery ) ) {
      hb_vmPushEvalSym();
      hb_vmPush( FOnCloseQuery );
      hb_vmSend( 0 );
      /* Block returns .T. to allow close, .F. to prevent */
      PHB_ITEM pResult = hb_stackReturnItem();
      if( pResult && HB_IS_LOGICAL( pResult ) )
         return hb_itemGetL( pResult );
   }
   return YES;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
   if( FOnActivate ) [self fireEvent:FOnActivate];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
   if( FOnDeactivate ) [self fireEvent:FOnDeactivate];
}

- (void)windowDidResize:(NSNotification *)notification
{
   if( FWindow ) {
      NSRect fr = [FWindow contentRectForFrameRect:[FWindow frame]];
      FWidth = (int)fr.size.width;
      FHeight = (int)fr.size.height;
   }
   if( FOnResize ) [self fireEvent:FOnResize];
}

- (void)windowDidMove:(NSNotification *)notification
{
   if( FWindow ) {
      NSRect screenFrame = [[NSScreen mainScreen] frame];
      NSRect fr = [FWindow frame];
      FLeft = (int)fr.origin.x;
      FTop  = (int)(screenFrame.size.height - fr.origin.y - fr.size.height);
   }
   /* Reuse OnResize callback for move too (syncs code) */
   if( FOnResize ) [self fireEvent:FOnResize];
}

- (void)windowDidMiniaturize:(NSNotification *)notification
{
   FWindowState = WS_MINIMIZED;
}

- (void)windowDidDeminiaturize:(NSNotification *)notification
{
   FWindowState = WS_NORMAL;
}

@end

/* ======================================================================
 * HBBrowseDelegate implementation
 * ====================================================================== */

@implementation HBBrowseDelegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    if( browseIdx < 0 || browseIdx >= s_nBrowses ) return 0;
    return [s_browses[browseIdx].rowData count];
}
- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    if( browseIdx < 0 || browseIdx >= s_nBrowses ) return @"";
    BrowseData * bd = &s_browses[browseIdx];
    NSInteger colIdx = [[col identifier] integerValue];
    if( row < 0 || row >= (NSInteger)[bd->rowData count] ) return @"";
    NSArray * rowArr = [bd->rowData objectAtIndex:row];
    if( colIdx < 0 || colIdx >= (NSInteger)[rowArr count] ) return @"";
    return [rowArr objectAtIndex:colIdx];
}
@end

static BrowseData * FindBrowse( HBControl * p )
{
    for( int i = 0; i < s_nBrowses; i++ )
        if( s_browses[i].pCtrl == p ) return &s_browses[i];
    return NULL;
}

/* ======================================================================
 * HB_FUNC Bridge functions
 * ====================================================================== */

/* Object lifetime management */
static NSMutableArray * s_allControls = nil;

static void KeepAlive( HBControl * p )
{
   if( !s_allControls ) s_allControls = [[NSMutableArray alloc] init];
   [s_allControls addObject:p];
}

static HBControl * GetCtrlRaw( int nParam )
{
   HB_PTRUINT n = (HB_PTRUINT) hb_parnint( nParam );
   if( n == 0 || !s_allControls ) return nil;
   /* Validate: the handle must still be in s_allControls, otherwise it's a
    * stale pointer to a freed HBControl and bridge-casting would crash. */
   void * raw = (void *) n;
   for( id obj in s_allControls )
      if( (__bridge void *) obj == raw )
         return (__bridge HBControl *) raw;
   return nil;
}

static void RetCtrl( HBControl * p )
{
   KeepAlive( p );
   hb_retnint( (HB_PTRUINT)(__bridge void *)p );
}

#define GetCtrl(n) GetCtrlRaw(n)
#define GetForm(n) ((HBForm *)GetCtrlRaw(n))

/* --- Form --- */

HB_FUNC( UI_FORMNEW )
{
   HBForm * p = [[HBForm alloc] init];
   if( HB_ISCHAR(1) ) [p setText:hb_parc(1)];
   if( HB_ISNUM(2) )  p->FWidth = hb_parni(2);
   if( HB_ISNUM(3) )  p->FHeight = hb_parni(3);
   if( HB_ISCHAR(4) && HB_ISNUM(5) ) {
      NSString * fontName = [NSString stringWithUTF8String:hb_parc(4)];
      CGFloat fontSize = (CGFloat)hb_parni(5);
      NSFont * font = [NSFont fontWithName:fontName size:fontSize];
      if( !font ) font = [NSFont systemFontOfSize:fontSize];
      p->FFormFont = font; p->FFont = font;
   }
   RetCtrl( p );
}

HB_FUNC( UI_ONSELCHANGE )
{
   HBForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p && pBlock ) {
      if( p->FOnSelChange ) hb_itemRelease( p->FOnSelChange );
      p->FOnSelChange = hb_itemNew( pBlock );
   }
}

HB_FUNC( UI_GETSELECTED )
{
   HBForm * p = GetForm(1);
   if( p && p->FSelCount > 0 )
      hb_retnint( (HB_PTRUINT)(__bridge void *)p->FSelected[0] );
   else hb_retnint( 0 );
}

HB_FUNC( UI_FORMSETDESIGN ) { HBForm * p = GetForm(1); if( p ) [p setDesignMode:hb_parl(2)]; }
HB_FUNC( UI_FORMSETDARKMODE ) {
   HBForm * p = GetForm(1);
   if( p && p->FWindow ) {
      [p->FWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
      [p->FWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1.0]];
      if( p->FContentView ) {
         p->FContentView.wantsLayer = YES;
         p->FContentView.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.18 alpha:1.0] CGColor];
      }
   }
}
HB_FUNC( UI_FORMRUN )       { HBForm * p = GetForm(1); if( p ) [p run]; }
HB_FUNC( UI_FORMSHOW )      { HBForm * p = GetForm(1); if( p ) [p showOnly]; }
HB_FUNC( UI_FORMSHOWMODAL ) { HBForm * p = GetForm(1); if( p ) hb_retni( [p showModal] ); else hb_retni(0); }
HB_FUNC( UI_FORMCLOSE )     { HBForm * p = GetForm(1); if( p ) [p close]; }
HB_FUNC( UI_FORMHIDE )      { HBForm * p = GetForm(1); if( p && p->FWindow ) [p->FWindow orderOut:nil]; }
HB_FUNC( UI_FORMISVISIBLE ) { HBForm * p = GetForm(1); hb_retl( p && p->FWindow && [p->FWindow isVisible] ); }
HB_FUNC( UI_FORMISKEYWINDOW ) { HBForm * p = GetForm(1); hb_retl( p && p->FWindow && [p->FWindow isKeyWindow] ); }
HB_FUNC( UI_FORMDESTROY )   { HBForm * p = GetForm(1); if( p ) [s_allControls removeObject:p]; }
HB_FUNC( UI_FORMRESULT )    { HBForm * p = GetForm(1); hb_retni( p ? p->FModalResult : 0 ); }

/* --- Control creation --- */

HB_FUNC( UI_LABELNEW )
{
   HBForm * pForm = GetForm(1); HBLabel * p = [[HBLabel alloc] init];
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

/* UI_MemoNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_MEMONEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_MEMO;
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( p->FWidth < 1 ) p->FWidth = 180;  if( p->FHeight < 1 ) p->FHeight = 80;
   strncpy( p->FClassName, "TMemo", sizeof(p->FClassName) - 1 );
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

/* UI_SetCtrlOwner( hCtrl, hOwner, nPage ) — assign TPageControl ownership */
HB_FUNC( UI_SETCTRLOWNER )
{
   HBControl * c = GetCtrl(1);
   HBControl * o = GetCtrl(2);
   int nPage = hb_parni(3);
   if( !c ) return;
   c->FOwnerCtrl = o;
   c->FOwnerPage = nPage;
   if( o ) HBUpdateTabVisibility( o );
}

/* UI_GetCtrlOwner( hCtrl ) --> hOwner (0 if none) */
HB_FUNC( UI_GETCTRLOWNER )
{
   HBControl * c = GetCtrl(1);
   hb_retnint( c && c->FOwnerCtrl ? (HB_PTRUINT)(__bridge void *) c->FOwnerCtrl : 0 );
}

/* UI_GetCtrlPage( hCtrl ) --> nPage (0-based) */
HB_FUNC( UI_GETCTRLPAGE )
{
   HBControl * c = GetCtrl(1);
   hb_retni( c ? c->FOwnerPage : 0 );
}

/* UI_IsAutoPage( hCtrl ) --> lAutoCreated */
HB_FUNC( UI_ISAUTOPAGE )
{
   HBControl * c = GetCtrl(1);
   hb_retl( c ? c->FAutoPage : 0 );
}

HB_FUNC( UI_SETPENDINGPAGEOWNER )
{
   HBControl * f = GetCtrl(1);
   s_pendingFolder = f;
   s_pendingPage   = hb_parni(2);
}

/* UI_TabControlSetSel( hFolder, nPage ) - switch active tab page */
HB_FUNC( UI_TABCONTROLSETSEL )
{
   HBControl * p = GetCtrl(1);
   int nPage = hb_parni(2);
   if( p && p->FControlType == CT_TABCONTROL2 && p->FView )
   {
      NSTabView * tv = (NSTabView *)p->FView;
      NSInteger nItems = [[tv tabViewItems] count];
      if( nPage >= 0 && nPage < nItems )
         [tv selectTabViewItemAtIndex:nPage];
   }
}

/* UI_TabControlNew( hForm, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_TABCONTROLNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_TABCONTROL2;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( p->FWidth < 1 ) p->FWidth = 200;  if( p->FHeight < 1 ) p->FHeight = 150;
   strncpy( p->FClassName, "TTabControl", sizeof(p->FClassName) - 1 );
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_EDITNEW )
{
   HBForm * pForm = GetForm(1); HBEdit * p = [[HBEdit alloc] init];
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_BUTTONNEW )
{
   HBForm * pForm = GetForm(1); HBButton * p = [[HBButton alloc] init];
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_CHECKBOXNEW )
{
   HBForm * pForm = GetForm(1); HBCheckBox * p = [[HBCheckBox alloc] init];
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_COMBOBOXNEW )
{
   HBForm * pForm = GetForm(1); HBComboBox * p = [[HBComboBox alloc] init];
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_GROUPBOXNEW )
{
   HBForm * pForm = GetForm(1); HBGroupBox * p = [[HBGroupBox alloc] init];
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_IMAGENEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_IMAGE;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_SHAPENEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_SHAPE;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_BEVELNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_BEVEL;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_LISTBOXNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_LISTBOX;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

/* UI_RadioButtonNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) --> hCtrl */
HB_FUNC( UI_RADIOBUTTONNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_RADIO;
   p->FWidth = 120; p->FHeight = 20;  /* RadioButton defaults */
   if( HB_ISCHAR(2) ) [p setText:hb_parc(2)];
   if( HB_ISNUM(3) ) p->FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->FHeight = hb_parni(6);
   strncpy( p->FClassName, "TRadioButton", sizeof(p->FClassName) - 1 );
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_PROGRESSBARNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_PROGRESSBAR;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_TREEVIEWNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_TREEVIEW;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_LISTVIEWNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_LISTVIEW;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_BITBTNNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_BITBTN;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

HB_FUNC( UI_RICHEDITNEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_RICHEDIT;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

/* --- TBrowse data grid --- */

/* UI_BrowseNew( hForm, nLeft, nTop, nWidth, nHeight ) --> hBrowse */
HB_FUNC( UI_BROWSENEW )
{
   HBForm * pForm = GetForm(1); HBControl * p = [[HBControl alloc] init];
   p->FControlType = CT_BROWSE;
   strcpy( p->FClassName, "TBrowse" );
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) [pForm addChild:p]; RetCtrl( p );
}

/* UI_BrowseAddCol( hBrowse, cTitle, cField, nWidth, nAlign ) --> nColIdx */
HB_FUNC( UI_BROWSEADDCOL )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   const char * title = hb_parc(2) ? hb_parc(2) : "";

   /* If view not yet created, store in FHeaders for deferred creation */
   if( !bd ) {
      if( !p ) { hb_retni(-1); return; }
      /* Count existing deferred columns */
      int nDef = 0;
      if( p->FHeaders[0] ) {
         nDef = 1;
         for( const char * s = p->FHeaders; *s; s++ )
            if( *s == '|' ) nDef++;
      }
      if( nDef >= MAX_BROWSE_COLS ) { hb_retni(-1); return; }
      int pos = (int)strlen(p->FHeaders);
      if( pos > 0 && pos < (int)sizeof(p->FHeaders) - 1 )
         p->FHeaders[pos++] = '|';
      int slen = (int)strlen(title);
      if( pos + slen >= (int)sizeof(p->FHeaders) - 1 )
         slen = (int)sizeof(p->FHeaders) - 1 - pos;
      memcpy( p->FHeaders + pos, title, (size_t)slen );
      p->FHeaders[pos + slen] = 0;
      p->FColWidths[nDef] = HB_ISNUM(4) ? hb_parni(4) : 100;
      hb_retni( nDef );
      return;
   }
   if( bd->nColCount >= MAX_BROWSE_COLS ) { hb_retni(-1); return; }

   int idx = bd->nColCount++;
   strncpy( bd->cols[idx].szTitle, title, 63 );
   strncpy( bd->cols[idx].szFieldName, HB_ISCHAR(3) ? hb_parc(3) : "", 63 );
   bd->cols[idx].nWidth = HB_ISNUM(4) ? hb_parni(4) : 100;
   bd->cols[idx].nAlign = HB_ISNUM(5) ? hb_parni(5) : 0;

   /* Add NSTableColumn */
   NSString * ident = [NSString stringWithFormat:@"%d", idx];
   NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:ident];
   [col setWidth:bd->cols[idx].nWidth];
   [[col headerCell] setStringValue:[NSString stringWithUTF8String:bd->cols[idx].szTitle]];
   [bd->tableView addTableColumn:col];

   hb_retni( idx );
}

/* UI_BrowseColCount( hBrowse ) --> nCols */
HB_FUNC( UI_BROWSECOLCOUNT )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   hb_retni( bd ? bd->nColCount : 0 );
}

/* UI_BrowseGetColProps( hBrowse, nCol ) --> { {cName,xVal,cCat,cType}, ... }
 * Returns properties for a single column (0-based index) */
HB_FUNC( UI_BROWSEGETCOLPROPS )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   int col = hb_parni(2);  /* 0-based */
   if( !bd || col < 0 || col >= bd->nColCount ) { hb_reta(0); return; }

   BrowseCol * c = &bd->cols[col];
   PHB_ITEM pArray = hb_itemArrayNew(0), pRow;

   #define ADDCP_S(n,v,cat) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); \
      hb_arraySetC(pRow,2,v); hb_arraySetC(pRow,3,cat); hb_arraySetC(pRow,4,"S"); \
      hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   #define ADDCP_N(n,v,cat) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); \
      hb_arraySetNI(pRow,2,v); hb_arraySetC(pRow,3,cat); hb_arraySetC(pRow,4,"N"); \
      hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   #define ADDCP_D(n,v,opts,cat) { char _db[256]; snprintf(_db,sizeof(_db),"%d|%s",v,opts); \
      pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetC(pRow,2,_db); \
      hb_arraySetC(pRow,3,cat); hb_arraySetC(pRow,4,"D"); \
      hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow); }

   /* First row: class name (convention for inspector title) */
   { char colLabel[128]; snprintf(colLabel, sizeof(colLabel), "TBrwColumn");
     pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,"cClassName"); hb_arraySetC(pRow,2,colLabel);
     hb_arraySetC(pRow,3,""); hb_arraySetC(pRow,4,"S");
     hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow); }

   ADDCP_S("cTitle", c->szTitle, "Data");
   ADDCP_N("nWidth", c->nWidth, "Position");
   ADDCP_D("nAlign", c->nAlign, "Left|Center|Right", "Position");
   ADDCP_S("cFieldName", c->szFieldName, "Data");
   ADDCP_S("cFooterText", c->szFooterText, "Appearance");

   #undef ADDCP_S
   #undef ADDCP_N
   #undef ADDCP_D

   hb_itemReturnRelease(pArray);
}

/* UI_BrowseSetColProp( hBrowse, nCol, cPropName, xValue ) */
HB_FUNC( UI_BROWSESETCOLPROP )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   int col = hb_parni(2);  /* 0-based */
   const char * szProp = hb_parc(3);
   if( !szProp ) return;

   /* If view not yet created, store width in deferred array */
   if( !bd ) {
      if( p && col >= 0 && col < MAX_BROWSE_COLS && strcasecmp(szProp,"nWidth")==0 && HB_ISNUM(4) )
         p->FColWidths[col] = hb_parni(4);
      return;
   }
   if( col < 0 || col >= bd->nColCount ) return;

   BrowseCol * c = &bd->cols[col];

   if( strcasecmp(szProp,"cTitle")==0 && HB_ISCHAR(4) ) {
      strncpy( c->szTitle, hb_parc(4), 63 ); c->szTitle[63] = 0;
      /* Update NSTableColumn header */
      NSArray * cols = [bd->tableView tableColumns];
      if( col < (int)[cols count] )
         [[[cols objectAtIndex:col] headerCell] setStringValue:
            [NSString stringWithUTF8String:c->szTitle]];
      [bd->tableView.headerView setNeedsDisplay:YES];
      [bd->tableView.headerView setNeedsLayout:YES];
      [bd->tableView reloadData];
      /* Sync FHeaders pipe-string */
      char buf[512]; buf[0] = 0; int pos = 0;
      for( int i = 0; i < bd->nColCount && pos < 510; i++ ) {
         if( i > 0 ) buf[pos++] = '|';
         int sl = (int)strlen(bd->cols[i].szTitle);
         if( pos+sl >= 510 ) sl = 510 - pos;
         memcpy(buf+pos, bd->cols[i].szTitle, sl); pos += sl;
      }
      buf[pos] = 0;
      strncpy( p->FHeaders, buf, sizeof(p->FHeaders)-1 );
   }
   else if( strcasecmp(szProp,"nWidth")==0 && HB_ISNUM(4) ) {
      c->nWidth = hb_parni(4);
      NSArray * cols = [bd->tableView tableColumns];
      if( col < (int)[cols count] )
         [[cols objectAtIndex:col] setWidth:c->nWidth];
   }
   else if( strcasecmp(szProp,"nAlign")==0 ) {
      if( HB_ISNUM(4) ) c->nAlign = hb_parni(4);
   }
   else if( strcasecmp(szProp,"cFieldName")==0 && HB_ISCHAR(4) ) {
      strncpy( c->szFieldName, hb_parc(4), 63 ); c->szFieldName[63] = 0;
   }
   else if( strcasecmp(szProp,"cFooterText")==0 && HB_ISCHAR(4) ) {
      strncpy( c->szFooterText, hb_parc(4), 63 ); c->szFooterText[63] = 0;
   }
}

/* UI_BrowseSetCell( hBrowse, nRow, nCol, cText ) */
HB_FUNC( UI_BROWSESETCELL )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   if( !bd || !HB_ISCHAR(4) ) return;

   int nRow = hb_parni(2);
   int nCol = hb_parni(3);
   NSString * text = [NSString stringWithUTF8String:hb_parc(4)];

   /* Ensure rows exist */
   while( (int)[bd->rowData count] <= nRow ) {
       NSMutableArray * row = [[NSMutableArray alloc] init];
       for( int c = 0; c < bd->nColCount; c++ ) [row addObject:@""];
       [bd->rowData addObject:row];
   }

   NSMutableArray * rowArr = [bd->rowData objectAtIndex:nRow];
   /* Ensure columns exist in row */
   while( (int)[rowArr count] <= nCol ) [rowArr addObject:@""];
   [rowArr replaceObjectAtIndex:nCol withObject:text];
}

/* UI_BrowseGetCell( hBrowse, nRow, nCol ) --> cText */
HB_FUNC( UI_BROWSEGETCELL )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   if( !bd ) { hb_retc(""); return; }

   int nRow = hb_parni(2);
   int nCol = hb_parni(3);
   if( nRow < 0 || nRow >= (int)[bd->rowData count] ) { hb_retc(""); return; }
   NSArray * rowArr = [bd->rowData objectAtIndex:nRow];
   if( nCol < 0 || nCol >= (int)[rowArr count] ) { hb_retc(""); return; }
   hb_retc( [[rowArr objectAtIndex:nCol] UTF8String] );
}

/* UI_BrowseSetFooter( hBrowse, nCol, cText ) */
HB_FUNC( UI_BROWSESETFOOTER )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   if( !bd || !HB_ISCHAR(3) ) return;
   int nCol = hb_parni(2);
   if( nCol >= 0 && nCol < bd->nColCount )
       strncpy( bd->cols[nCol].szFooterText, hb_parc(3), 63 );
}

/* UI_BrowseRefresh( hBrowse ) */
HB_FUNC( UI_BROWSEREFRESH )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   if( bd && bd->tableView ) [bd->tableView reloadData];
}

/* UI_BrowseOnEvent( hBrowse, cEvent, bBlock ) */
HB_FUNC( UI_BROWSEONEVENT )
{
   HBControl * p = GetCtrl(1);
   BrowseData * bd = p ? FindBrowse(p) : NULL;
   const char * ev = hb_parc(2);
   PHB_ITEM blk = hb_param(3, HB_IT_BLOCK);
   if( !bd || !ev || !blk ) return;

   PHB_ITEM * ppTarget = NULL;
   if( strcasecmp(ev,"OnCellClick")==0 )         ppTarget = &bd->FOnCellClick;
   else if( strcasecmp(ev,"OnCellDblClick")==0 ) ppTarget = &bd->FOnCellDblClick;
   else if( strcasecmp(ev,"OnHeaderClick")==0 )  ppTarget = &bd->FOnHeaderClick;
   else if( strcasecmp(ev,"OnRowSelect")==0 )    ppTarget = &bd->FOnRowSelect;
   else if( strcasecmp(ev,"OnKeyDown")==0 )      ppTarget = &bd->FOnKeyDown;

   if( ppTarget ) {
       if( *ppTarget ) hb_itemRelease( *ppTarget );
       *ppTarget = hb_itemNew( blk );
   }
}

/* UI_DropNonVisual( hForm, nType, cName, [cIconPath] ) - place non-visual component icon */
HB_FUNC( UI_DROPNONVISUAL )
{
   HBForm * form = GetForm(1);
   int nType = hb_parni(2);
   const char * cName = hb_parc(3);
   if( !form || !cName ) return;

   /* Find next available position (grid of 40x40, bottom area of form) */
   int nExisting = 0;
   for( int i = 0; i < form->FChildCount; i++ )
   {
      if( form->FChildren[i]->FControlType >= CT_TIMER )
         nExisting++;
   }
   int col = nExisting % 8;
   int row = nExisting / 8;
   int x = 8 + col * 40;
   int y = form->FHeight - 80 + row * 40;
   if( y < 40 ) y = 40;

   /* Create a generic control with the non-visual type */
   HBControl * ctrl = [[HBControl alloc] init];
   ctrl->FControlType = nType;
   ctrl->FLeft = x;
   ctrl->FTop = y;
   ctrl->FWidth = 32;
   ctrl->FHeight = 32;
   strncpy( ctrl->FName, cName, sizeof(ctrl->FName) - 1 );
   strncpy( ctrl->FText, cName, sizeof(ctrl->FText) - 1 );

   /* Set FClassName based on component type */
   {
      static struct { int type; const char * cls; } s_typeMap[] = {
         { CT_TIMER, "TTimer" }, { CT_PAINTBOX, "TPaintBox" },
         { CT_OPENDIALOG, "TOpenDialog" }, { CT_SAVEDIALOG, "TSaveDialog" },
         { CT_FONTDIALOG, "TFontDialog" }, { CT_COLORDIALOG, "TColorDialog" },
         { CT_FINDDIALOG, "TFindDialog" }, { CT_REPLACEDIALOG, "TReplaceDialog" },
         { CT_OPENAI, "TOpenAI" }, { CT_GEMINI, "TGemini" },
         { CT_CLAUDE, "TClaude" }, { CT_DEEPSEEK, "TDeepSeek" },
         { CT_GROK, "TGrok" }, { CT_OLLAMA, "TOllama" },
         { CT_TRANSFORMER, "TTransformer" },
         { CT_DBFTABLE, "TDbfTable" }, { CT_MYSQL, "TMySQL" },
         { CT_MARIADB, "TMariaDB" }, { CT_POSTGRESQL, "TPostgreSQL" },
         { CT_SQLITE, "TSQLite" }, { CT_FIREBIRD, "TFirebird" },
         { CT_SQLSERVER, "TSQLServer" }, { CT_ORACLE, "TOracle" },
         { CT_MONGODB, "TMongoDB" },
         { CT_WEBVIEW, "TWebView" }, { CT_WEBSERVER, "TWebServer" },
         { CT_WEBSOCKET, "TWebSocket" }, { CT_HTTPCLIENT, "THttpClient" },
         { CT_FTPCLIENT, "TFtpClient" }, { CT_SMTPCLIENT, "TSmtpClient" },
         { CT_TCPSERVER, "TTcpServer" }, { CT_TCPCLIENT, "TTcpClient" },
         { CT_UDPSOCKET, "TUdpSocket" },
         { CT_THREAD, "TThread" }, { CT_MUTEX, "TMutex" },
         { CT_SEMAPHORE, "TSemaphore" }, { CT_THREADPOOL, "TThreadPool" },
         { CT_PRINTER, "TPrinter" }, { CT_REPORT, "TReport" },
         { CT_COMPARRAY, "TCompArray" },
         { CT_BROWSE, "TBrowse" }, { CT_DBGRID, "TDbGrid" },
         { CT_DBNAVIGATOR, "TDbNavigator" },
         { 112, "TPython" }, { 113, "TSwift" }, { 114, "TGo" },
         { 115, "TNode" }, { 116, "TRust" }, { 117, "TJava" },
         { 118, "TDotNet" }, { 119, "TLua" }, { 120, "TRuby" },
         { 0, NULL }
      };
      BOOL found = NO;
      for( int i = 0; s_typeMap[i].cls; i++ )
      {
         if( s_typeMap[i].type == nType )
         {
            strncpy( ctrl->FClassName, s_typeMap[i].cls, sizeof(ctrl->FClassName) - 1 );
            found = YES;
            break;
         }
      }
      if( !found )
         snprintf( ctrl->FClassName, sizeof(ctrl->FClassName), "TComponent%d", nType );
   }

   [form addChild:ctrl];

   /* Create the visual representation (bitmap icon or text fallback).
    * Palette icons are laid out sequentially (imgBase + btnIdx), NOT by
    * ctrlType. Locate this type's button in the palette to get its index. */
   if( form->FContentView ) {
      int imgIdx = -1;
      const char * btnText = NULL;
      if( s_palData ) {
         int imgBase = 0;
         for( int k = 0; k < s_palData->nTabCount && imgIdx < 0; k++ ) {
            PaletteTab * t = &s_palData->tabs[k];
            for( int i = 0; i < t->nBtnCount; i++ ) {
               if( t->btns[i].nControlType == nType ) {
                  imgIdx = imgBase + i;
                  btnText = t->btns[i].szText;
                  break;
               }
            }
            imgBase += t->nBtnCount;
         }
      }
      BOOL hasImage = ( s_palData && s_palData->palImages && imgIdx >= 0 &&
                        imgIdx < (int)[s_palData->palImages count] );
      if( hasImage ) {
         NSImageView * iv = [[NSImageView alloc] initWithFrame:
            NSMakeRect( x, y + form->FClientTop, 32, 32 )];
         [iv setImage:s_palData->palImages[imgIdx]];
         [iv setImageScaling:NSImageScaleProportionallyUpOrDown];
         [iv setEditable:NO];
         ctrl->FView = (NSView *)iv;
         [form->FContentView addSubview:iv];
      } else {
         NSString * ns = btnText ? [NSString stringWithUTF8String:btnText]
                                 : [NSString stringWithUTF8String:cName];
         NSImage * img = [NSImage imageWithSize:NSMakeSize(32,32)
                                        flipped:NO
                                 drawingHandler:^BOOL(NSRect r) {
            [[NSColor colorWithCalibratedRed:0.25 green:0.45 blue:0.70 alpha:1.0] set];
            NSRectFill( r );
            NSDictionary * attrs = @{
               NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
               NSForegroundColorAttributeName: [NSColor whiteColor]
            };
            NSSize sz = [ns sizeWithAttributes:attrs];
            NSPoint pt = NSMakePoint( (r.size.width - sz.width)/2,
                                      (r.size.height - sz.height)/2 );
            [ns drawAtPoint:pt withAttributes:attrs];
            return YES;
         }];
         NSImageView * iv = [[NSImageView alloc] initWithFrame:
            NSMakeRect( x, y + form->FClientTop, 32, 32 )];
         [iv setImage:img];
         [iv setImageScaling:NSImageScaleNone];
         [iv setEditable:NO];
         ctrl->FView = (NSView *)iv;
         [form->FContentView addSubview:iv];
      }
   }

   RetCtrl( ctrl );
}

/* UI_TimerNew( hForm, nInterval ) - create runtime timer (no view, no icon) */
HB_FUNC( UI_TIMERNEW )
{
   HBForm * form = GetForm(1);
   int nInterval = HB_ISNUM(2) ? hb_parni(2) : 1000;
   if( !form ) return;

   HBControl * ctrl = [[HBControl alloc] init];
   ctrl->FControlType = CT_TIMER;
   ctrl->FInterval = nInterval;
   ctrl->FWidth = 0; ctrl->FHeight = 0;
   ctrl->FView = nil;  /* No visual representation at runtime */
   strncpy( ctrl->FClassName, "TTimer", sizeof(ctrl->FClassName) - 1 );
   strncpy( ctrl->FName, "Timer", sizeof(ctrl->FName) - 1 );
   [form addChild:ctrl];
   RetCtrl( ctrl );
}

/* --- Property access --- */

HB_FUNC( UI_SETPROP )
{
   HBControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);
   if( !p || !szProp ) return;

   if( strcasecmp( szProp, "cText" ) == 0 && HB_ISCHAR(3) ) {
      [p setText:hb_parc(3)];
      if( p->FControlType == CT_FORM && ((HBForm *)p)->FWindow )
         [((HBForm *)p)->FWindow setTitle:[NSString stringWithUTF8String:p->FText]];
      else if( p->FControlType == CT_MEMO && p->FView ) {
         NSView * v = p->FView;
         NSTextView * tv = nil;
         if( [v isKindOfClass:[NSScrollView class]] )
            tv = (NSTextView *)[(NSScrollView *)v documentView];
         else if( [v isKindOfClass:[NSTextView class]] )
            tv = (NSTextView *)v;
         if( tv ) [tv setString:[NSString stringWithUTF8String:p->FText]];
      }
      else if( p->FView && [p->FView isKindOfClass:[NSButton class]] )
         [(NSButton *)p->FView setTitle:[NSString stringWithUTF8String:p->FText]];
      else if( p->FView && [p->FView respondsToSelector:@selector(setStringValue:)] )
         [(id)p->FView setStringValue:[NSString stringWithUTF8String:p->FText]];
   }
   else if( strcasecmp(szProp,"nLeft")==0 )   {
      p->FLeft = hb_parni(3);
      if( p->FControlType == CT_FORM ) { ((HBForm *)p)->FCenter = NO; ((HBForm *)p)->FPosition = POS_DESIGNED; }
      [p updateViewFrame];
   }
   else if( strcasecmp(szProp,"nTop")==0 )    {
      p->FTop = hb_parni(3);
      if( p->FControlType == CT_FORM ) { ((HBForm *)p)->FCenter = NO; ((HBForm *)p)->FPosition = POS_DESIGNED; }
      [p updateViewFrame];
   }
   else if( strcasecmp(szProp,"nWidth")==0 )  { p->FWidth = hb_parni(3); [p updateViewFrame]; }
   else if( strcasecmp(szProp,"nHeight")==0 ) { p->FHeight = hb_parni(3); [p updateViewFrame]; }
   else if( strcasecmp(szProp,"lVisible")==0 ) {
      p->FVisible = hb_parl(3); if( p->FView ) [p->FView setHidden:!p->FVisible]; }
   else if( strcasecmp(szProp,"lEnabled")==0 ) {
      p->FEnabled = hb_parl(3);
      if( p->FControlType == CT_TIMER ) {
         if( p->FEnabled ) [p startTimer]; else [p stopTimer];
      }
      else if( p->FView && [p->FView respondsToSelector:@selector(setEnabled:)] )
         [(id)p->FView setEnabled:p->FEnabled]; }
   else if( strcasecmp(szProp,"lTransparent")==0 ) {
      p->FTransparent = hb_parl(3);
      if( p->FView && [p->FView isKindOfClass:[NSTextField class]] && p->FControlType == CT_LABEL )
      {
         [(NSTextField *)p->FView setDrawsBackground:!p->FTransparent];
         /* When switching to non-transparent, apply nClrPane background if set */
         if( !p->FTransparent && p->FClrPane != 0xFFFFFFFF && p->FBgColor )
            [(NSTextField *)p->FView setBackgroundColor:p->FBgColor];
      }
   }
   else if( strcasecmp(szProp,"nAlign")==0 && HB_ISNUM(3) ) {
      p->nAlign = hb_parni(3);
      if( p->FView && [p->FView respondsToSelector:@selector(setAlignment:)] ) {
         NSTextAlignment a = NSTextAlignmentLeft;
         if( p->nAlign == 1 ) a = NSTextAlignmentCenter;
         else if( p->nAlign == 2 ) a = NSTextAlignmentRight;
         [(id)p->FView setAlignment:a];
      }
   }
   else if( strcasecmp(szProp,"lDefault")==0 && p->FControlType == CT_BUTTON )
      ((HBButton *)p)->FDefault = hb_parl(3);
   else if( strcasecmp(szProp,"lCancel")==0 && p->FControlType == CT_BUTTON )
      ((HBButton *)p)->FCancel = hb_parl(3);
   else if( strcasecmp(szProp,"lChecked")==0 && p->FControlType == CT_CHECKBOX )
      [(HBCheckBox *)p setChecked:hb_parl(3)];
   else if( strcasecmp(szProp,"cName")==0 && HB_ISCHAR(3) )
      strncpy( p->FName, hb_parc(3), sizeof(p->FName)-1 );
   else if( strcasecmp(szProp,"cFileName")==0 && HB_ISCHAR(3) )
      strncpy( p->FFileName, hb_parc(3), sizeof(p->FFileName)-1 );
   else if( strcasecmp(szProp,"cRDD")==0 ) {
      if( HB_ISCHAR(3) )
         strncpy( p->FRdd, hb_parc(3), sizeof(p->FRdd)-1 );
      else if( HB_ISNUM(3) ) {
         static const char * rddNames[] = { "DBFCDX", "DBFNTX", "DBFFPT" };
         int idx = hb_parni(3);
         if( idx >= 0 && idx < 3 ) strcpy( p->FRdd, rddNames[idx] );
      }
   }
   else if( strcasecmp(szProp,"aHeaders")==0 || strcasecmp(szProp,"aColumns")==0 ||
            strcasecmp(szProp,"aTabs")==0 || strcasecmp(szProp,"aItems")==0 )
   {
      /* Accept string or array */
      if( HB_ISCHAR(3) )
         strncpy( p->FHeaders, hb_parc(3), sizeof(p->FHeaders)-1 );
      else if( HB_ISARRAY(3) )
      {
         /* Convert array { "A", "B", "C" } to "|"-separated string */
         PHB_ITEM pArr = hb_param(3, HB_IT_ARRAY);
         int n = (int) hb_arrayLen( pArr );
         p->FHeaders[0] = 0;
         int pos = 0;
         for( int i = 1; i <= n && pos < (int)sizeof(p->FHeaders) - 2; i++ )
         {
            const char * s = hb_arrayGetCPtr( pArr, i );
            int slen = (int)strlen( s );
            if( i > 1 && pos < (int)sizeof(p->FHeaders) - 1 ) p->FHeaders[pos++] = '|';
            if( pos + slen >= (int)sizeof(p->FHeaders) - 1 ) slen = (int)sizeof(p->FHeaders) - 1 - pos;
            memcpy( p->FHeaders + pos, s, (size_t)slen );
            pos += slen;
         }
         p->FHeaders[pos] = 0;
      }

      /* For Browse controls, create/update NSTableView columns immediately */
      if( p->FControlType == CT_BROWSE )
      {
         BrowseData * bd = FindBrowse( p );
         if( bd && bd->tableView )
         {
            /* Remove all existing columns */
            while( [[bd->tableView tableColumns] count] > 0 )
               [bd->tableView removeTableColumn:[[bd->tableView tableColumns] lastObject]];
            bd->nColCount = 0;

            /* Parse "|"-separated titles and create columns */
            const char * src = p->FHeaders;
            while( src && *src )
            {
               const char * sep = strchr( src, '|' );
               int len = sep ? (int)(sep - src) : (int)strlen(src);
               if( len > 0 && bd->nColCount < MAX_BROWSE_COLS )
               {
                  int idx = bd->nColCount++;
                  memset( bd->cols[idx].szTitle, 0, 64 );
                  if( len > 63 ) len = 63;
                  memcpy( bd->cols[idx].szTitle, src, (size_t)len );
                  bd->cols[idx].nWidth = 100;
                  bd->cols[idx].nAlign = 0;
                  bd->cols[idx].szFieldName[0] = 0;

                  NSString * ident = [NSString stringWithFormat:@"%d", idx];
                  NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:ident];
                  [col setWidth:100];
                  [[col headerCell] setStringValue:
                     [[NSString alloc] initWithBytes:src length:len encoding:NSUTF8StringEncoding]];
                  [bd->tableView addTableColumn:col];
               }
               src = sep ? sep + 1 : NULL;
            }
            [bd->tableView reloadData];
         }
      }

      /* For TreeView, reload the NSOutlineView from FHeaders */
      if( p->FControlType == CT_TREEVIEW && p->FView )
      {
         NSScrollView * sv = (NSScrollView *) p->FView;
         NSOutlineView * ov = (NSOutlineView *) [sv documentView];
         if( ov ) {
            id ds = [ov dataSource];
            if( [ds isKindOfClass:[HBTreeDataSource class]] )
               [(HBTreeDataSource *)ds rebuild];
            [ov reloadData];
         }
      }

      /* For TTabControl, create/update NSTabView tabs immediately */
      if( p->FControlType == CT_TABCONTROL2 && p->FView )
      {
         NSTabView * tv = (NSTabView *)p->FView;
         while( [[tv tabViewItems] count] > 0 )
            [tv removeTabViewItem:[[tv tabViewItems] lastObject]];
         const char * src = p->FHeaders;
         int idx = 0;
         while( src && *src )
         {
            const char * sep = strchr( src, '|' );
            int len = sep ? (int)(sep - src) : (int)strlen(src);
            if( len > 0 )
            {
               NSString * lbl = [[NSString alloc] initWithBytes:src length:len encoding:NSUTF8StringEncoding];
               NSTabViewItem * it = [[NSTabViewItem alloc]
                  initWithIdentifier:[NSString stringWithFormat:@"tab%d", idx++]];
               [it setLabel:lbl];
               [it setView:[[NSView alloc] initWithFrame:NSMakeRect(0,0,10,10)]];
               [tv addTabViewItem:it];
            }
            src = sep ? sep + 1 : NULL;
         }
         if( [[tv tabViewItems] count] == 0 )
         {
            NSTabViewItem * it = [[NSTabViewItem alloc] initWithIdentifier:@"tab1"];
            [it setLabel:@"Tab 1"];
            [it setView:[[NSView alloc] initWithFrame:NSMakeRect(0,0,10,10)]];
            [tv addTabViewItem:it];
         }
         [tv setNeedsDisplay:YES];

         /* Auto-create/remove TPanel pages: one TPanel per tab, flagged
          * FAutoPage so codegen can skip them. Positioned inside the tab
          * content area. Owned by this TPageControl for visibility toggling. */
         if( p->FCtrlParent && [p->FCtrlParent isKindOfClass:[HBForm class]] )
         {
            HBForm * pf = (HBForm *)p->FCtrlParent;
            int nTabs = (int) [[tv tabViewItems] count];

            /* Remove existing auto-pages for this TPageControl */
            for( int i = pf->FChildCount - 1; i >= 0; i-- ) {
               HBControl * c = pf->FChildren[i];
               if( c && c->FAutoPage && c->FOwnerCtrl == p ) {
                  if( c->FView ) [c->FView removeFromSuperview];
                  for( int k = i; k < pf->FChildCount - 1; k++ )
                     pf->FChildren[k] = pf->FChildren[k+1];
                  pf->FChildren[--pf->FChildCount] = nil;
               }
            }

            /* Create new auto-page panels */
            int pageL = p->FLeft + 4;
            int pageT = p->FTop + 26;
            int pageW = p->FWidth - 8;
            int pageH = p->FHeight - 30;
            for( int i = 0; i < nTabs; i++ ) {
               HBControl * panel = [[HBControl alloc] init];
               panel->FControlType = CT_PANEL;
               strncpy( panel->FClassName, "TPanel", sizeof(panel->FClassName) - 1 );
               snprintf( panel->FName, sizeof(panel->FName), "%s_Page%d", p->FName, i );
               panel->FLeft = pageL; panel->FTop = pageT;
               panel->FWidth = pageW; panel->FHeight = pageH;
               panel->FOwnerCtrl = p;
               panel->FOwnerPage = i;
               panel->FAutoPage = YES;
               KeepAlive( panel );
               [pf addChild:panel];
               [panel createViewInParent:pf->FContentView];
            }

            /* Keep overlay on top */
            if( pf->FOverlayView && pf->FContentView )
               [pf->FContentView addSubview:(NSView *)pf->FOverlayView
                                positioned:NSWindowAbove relativeTo:nil];

            /* Apply visibility for currently selected tab */
            HBUpdateTabVisibility( p );
         }
      }
   }
   else if( strcasecmp(szProp,"aData")==0 && HB_ISCHAR(3) )
      strncpy( p->FData, hb_parc(3), sizeof(p->FData)-1 );
   else if( strcasecmp(szProp,"cDataSource")==0 && HB_ISCHAR(3) )
      strncpy( p->FDataSource, hb_parc(3), sizeof(p->FDataSource)-1 );
   else if( strcasecmp(szProp,"lActive")==0 )
      p->FActive = hb_parl(3);
   else if( strcasecmp(szProp,"nInterval")==0 && p->FControlType == CT_TIMER ) {
      p->FInterval = hb_parni(3);
      if( p->FEnabled && p->FOnTimer ) [p startTimer];
   }
   else if( strcasecmp(szProp,"lSizable")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FSizable = hb_parl(3);
   else if( strcasecmp(szProp,"lAppBar")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FAppBar = hb_parl(3);
   else if( strcasecmp(szProp,"lToolWindow")==0 && p->FControlType == CT_FORM ) {
      if( hb_parl(3) ) ((HBForm *)p)->FBorderStyle = BS_TOOLWINDOW;
   }
   else if( strcasecmp(szProp,"nBorderStyle")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FBorderStyle = hb_parni(3);
   else if( strcasecmp(szProp,"nBorderIcons")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FBorderIcons = hb_parni(3);
   else if( strcasecmp(szProp,"nPosition")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FPosition = hb_parni(3);
   else if( strcasecmp(szProp,"nWindowState")==0 && p->FControlType == CT_FORM ) {
      HBForm * f = (HBForm *)p;
      f->FWindowState = hb_parni(3);
      if( f->FWindow ) {
         switch( f->FWindowState ) {
            case WS_MINIMIZED: [f->FWindow miniaturize:nil]; break;
            case WS_MAXIMIZED: [f->FWindow zoom:nil]; break;
            case WS_NORMAL:
               if( [f->FWindow isMiniaturized] ) [f->FWindow deminiaturize:nil];
               else if( [f->FWindow isZoomed] ) [f->FWindow zoom:nil];
               break;
         }
      }
   }
   else if( strcasecmp(szProp,"nFormStyle")==0 && p->FControlType == CT_FORM ) {
      HBForm * f = (HBForm *)p;
      f->FFormStyle = hb_parni(3);
      if( f->FWindow )
         [f->FWindow setLevel:(f->FFormStyle == FS_STAYONTOP) ? NSFloatingWindowLevel : NSNormalWindowLevel];
   }
   else if( strcasecmp(szProp,"lKeyPreview")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FKeyPreview = hb_parl(3);
   else if( strcasecmp(szProp,"lAlphaBlend")==0 && p->FControlType == CT_FORM ) {
      HBForm * f = (HBForm *)p;
      f->FAlphaBlend = hb_parl(3);
      if( f->FWindow )
         [f->FWindow setAlphaValue:f->FAlphaBlend ? f->FAlphaBlendValue / 255.0 : 1.0];
   }
   else if( strcasecmp(szProp,"nAlphaBlendValue")==0 && p->FControlType == CT_FORM ) {
      HBForm * f = (HBForm *)p;
      f->FAlphaBlendValue = hb_parni(3);
      if( f->FAlphaBlend && f->FWindow )
         [f->FWindow setAlphaValue:f->FAlphaBlendValue / 255.0];
   }
   else if( strcasecmp(szProp,"nCursor")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FCursor = hb_parni(3);
   else if( strcasecmp(szProp,"lShowHint")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FShowHint = hb_parl(3);
   else if( strcasecmp(szProp,"cAppTitle")==0 && p->FControlType == CT_FORM && HB_ISCHAR(3) )
      strncpy( ((HBForm *)p)->FAppTitle, hb_parc(3), sizeof(((HBForm *)p)->FAppTitle)-1 );
   else if( strcasecmp(szProp,"cHint")==0 && p->FControlType == CT_FORM && HB_ISCHAR(3) )
      strncpy( ((HBForm *)p)->FHint, hb_parc(3), sizeof(((HBForm *)p)->FHint)-1 );
   else if( strcasecmp(szProp,"lAutoScroll")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FAutoScroll = hb_parl(3);
   else if( strcasecmp(szProp,"lDoubleBuffered")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FDoubleBuffered = hb_parl(3);
   else if( strcasecmp(szProp,"nBorderWidth")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FBorderWidth = hb_parni(3);
   else if( strcasecmp(szProp,"nClrPane")==0 ) {
      p->FClrPane = (unsigned int)hb_parnint(3);
      CGFloat r = (p->FClrPane & 0xFF)/255.0;
      CGFloat g = ((p->FClrPane>>8)&0xFF)/255.0;
      CGFloat b = ((p->FClrPane>>16)&0xFF)/255.0;
      p->FBgColor = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
      if( p->FControlType == CT_FORM && ((HBForm *)p)->FWindow )
      {
         [((HBForm *)p)->FWindow setBackgroundColor:p->FBgColor];
         /* Update dot grid view in design mode */
         HBForm * f = (HBForm *)p;
         if( f->FContentView ) {
            for( NSView * sv in [f->FContentView subviews] )
               if( [sv isKindOfClass:[HBDotGridView class]] ) {
                  ((HBDotGridView *)sv)->bgColor = p->FBgColor;
                  [sv setNeedsDisplay:YES];
                  break;
               }
         }
         /* Invalidate transparent children so they pick up the new bg */
         for( int ci = 0; ci < p->FChildCount; ci++ ) {
            HBControl * ch = p->FChildren[ci];
            if( ch->FTransparent && ch->FView ) [ch->FView setNeedsDisplay:YES];
         }
      }
      else if( p->FControlType == CT_BROWSE )
      {
         BrowseData * bd = FindBrowse( p );
         if( bd && bd->tableView ) {
            [bd->tableView setBackgroundColor:p->FBgColor];
            [bd->tableView setUsesAlternatingRowBackgroundColors:NO];
            [bd->tableView setNeedsDisplay:YES];
            if( bd->scrollView ) {
               [bd->scrollView setDrawsBackground:YES];
               [bd->scrollView setBackgroundColor:p->FBgColor];
               [[bd->scrollView contentView] setDrawsBackground:YES];
               [(NSClipView *)[bd->scrollView contentView] setBackgroundColor:p->FBgColor];
               [bd->scrollView setNeedsDisplay:YES];
            }
         }
      }
      else if( p->FView )
      {
         if( [p->FView isKindOfClass:[NSTextField class]] ) {
            [(NSTextField *)p->FView setBackgroundColor:p->FBgColor];
            /* Respect lTransparent for labels — don't force drawsBackground if transparent */
            if( !( p->FControlType == CT_LABEL && p->FTransparent ) )
               [(NSTextField *)p->FView setDrawsBackground:YES];
         }
         else
            [p->FView setNeedsDisplay:YES];
      }
   }
   else if( strcasecmp(szProp,"nClrText")==0 ) {
      p->FClrText = (unsigned int)hb_parnint(3);
      if( p->FView && [p->FView respondsToSelector:@selector(setTextColor:)] ) {
         CGFloat r = (p->FClrText & 0xFF)/255.0;
         CGFloat g = ((p->FClrText>>8)&0xFF)/255.0;
         CGFloat b = ((p->FClrText>>16)&0xFF)/255.0;
         [(id)p->FView setTextColor:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]];
      }
   }
   else if( strcasecmp(szProp,"oFont")==0 && HB_ISCHAR(3) ) {
      char szFace[64]={0}; int nSize=12; unsigned int clrText = 0xFFFFFFFF;
      const char * val = hb_parc(3);
      const char * comma = strchr(val,',');
      if( comma ) {
         int len=(int)(comma-val); if(len>63)len=63; memcpy(szFace,val,len);
         nSize=atoi(comma+1);
         /* Optional third field: color as hex RRGGBB */
         const char * comma2 = strchr(comma+1,',');
         if( comma2 ) {
            unsigned int r=0,g=0,b=0;
            if( sscanf(comma2+1,"%02X%02X%02X",&r,&g,&b) == 3 )
               clrText = (r) | (g<<8) | (b<<16);  /* BGR like nClrPane */
         }
      }
      else strncpy(szFace,val,63);
      if( nSize <= 0 ) nSize = 12;
      NSFont * font = [NSFont fontWithName:[NSString stringWithUTF8String:szFace] size:(CGFloat)nSize];
      if( !font ) font = [NSFont systemFontOfSize:(CGFloat)nSize];
      if( clrText != 0xFFFFFFFF ) p->FClrText = clrText;
      if( p->FControlType == CT_FORM ) {
         HBForm * pF = (HBForm *)p; pF->FFormFont = font; pF->FFont = font;
         for( int i = 0; i < pF->FChildCount; i++ ) { pF->FChildren[i]->FFont = font; [pF->FChildren[i] applyFont]; }
      } else {
         p->FFont = font; [p applyFont];
         /* Apply text color if set */
         if( p->FClrText != 0xFFFFFFFF && p->FView && [p->FView respondsToSelector:@selector(setTextColor:)] ) {
            CGFloat r = (p->FClrText & 0xFF) / 255.0;
            CGFloat g = ((p->FClrText >> 8) & 0xFF) / 255.0;
            CGFloat b = ((p->FClrText >> 16) & 0xFF) / 255.0;
            [(id)p->FView setTextColor:[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0]];
         }
      }
   }
}

HB_FUNC( UI_GETPROP )
{
   HBControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);
   if( !p || !szProp ) { hb_ret(); return; }

   if( strcasecmp(szProp,"cText")==0 ) {
      /* For editable controls, return live value from the NSView */
      if( p->FView ) {
         NSString * s = nil;
         if( p->FControlType == CT_EDIT && [p->FView isKindOfClass:[NSTextField class]] )
            s = [(NSTextField *)p->FView stringValue];
         else if( p->FControlType == CT_MEMO ) {
            NSView * v = p->FView;
            if( [v isKindOfClass:[NSScrollView class]] ) {
               NSTextView * tv = (NSTextView *)[(NSScrollView *)v documentView];
               if( tv ) s = [tv string];
            } else if( [v isKindOfClass:[NSTextView class]] ) {
               s = [(NSTextView *)v string];
            }
         }
         if( s ) {
            const char * c = [s UTF8String];
            strncpy( p->FText, c ? c : "", sizeof(p->FText) - 1 );
            p->FText[sizeof(p->FText) - 1] = 0;
         }
      }
      hb_retc( p->FText );
   }
   else if( strcasecmp(szProp,"nLeft")==0 )      hb_retni( p->FLeft );
   else if( strcasecmp(szProp,"nTop")==0 )       hb_retni( p->FTop );
   else if( strcasecmp(szProp,"nWidth")==0 )     hb_retni( p->FWidth );
   else if( strcasecmp(szProp,"nHeight")==0 )    hb_retni( p->FHeight );
   else if( strcasecmp(szProp,"lDefault")==0 && p->FControlType==CT_BUTTON )
      hb_retl( ((HBButton *)p)->FDefault );
   else if( strcasecmp(szProp,"lCancel")==0 && p->FControlType==CT_BUTTON )
      hb_retl( ((HBButton *)p)->FCancel );
   else if( strcasecmp(szProp,"lChecked")==0 && p->FControlType==CT_CHECKBOX )
      hb_retl( ((HBCheckBox *)p)->FChecked );
   else if( strcasecmp(szProp,"cName")==0 )      hb_retc( p->FName );
   else if( strcasecmp(szProp,"cClassName")==0 ) hb_retc( p->FClassName );
   else if( strcasecmp(szProp,"cFileName")==0 )  hb_retc( p->FFileName );
   else if( strcasecmp(szProp,"cRDD")==0 )      hb_retc( p->FRdd );
   else if( strcasecmp(szProp,"aHeaders")==0 || strcasecmp(szProp,"aColumns")==0 ||
            strcasecmp(szProp,"aTabs")==0 || strcasecmp(szProp,"aItems")==0 )
      hb_retc( p->FHeaders );
   else if( strcasecmp(szProp,"aData")==0 )     hb_retc( p->FData );
   else if( strcasecmp(szProp,"cDataSource")==0 ) hb_retc( p->FDataSource );
   else if( strcasecmp(szProp,"lActive")==0 )   hb_retl( p->FActive );
   else if( strcasecmp(szProp,"lTransparent")==0 ) hb_retl( p->FTransparent );
   else if( strcasecmp(szProp,"nAlign")==0 ) hb_retni( p->nAlign );
   else if( strcasecmp(szProp,"nInterval")==0 && p->FControlType==CT_TIMER )
      hb_retni( p->FInterval );
   else if( strcasecmp(szProp,"lSizable")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FSizable );
   else if( strcasecmp(szProp,"lAppBar")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FAppBar );
   else if( strcasecmp(szProp,"lToolWindow")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FBorderStyle == BS_TOOLWINDOW || ((HBForm *)p)->FBorderStyle == BS_SIZETOOLWIN );
   else if( strcasecmp(szProp,"nBorderStyle")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FBorderStyle );
   else if( strcasecmp(szProp,"nBorderIcons")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FBorderIcons );
   else if( strcasecmp(szProp,"nPosition")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FPosition );
   else if( strcasecmp(szProp,"nWindowState")==0 && p->FControlType==CT_FORM ) {
      HBForm * f = (HBForm *)p;
      if( f->FWindow ) {
         if( [f->FWindow isMiniaturized] ) hb_retni( WS_MINIMIZED );
         else if( [f->FWindow isZoomed] ) hb_retni( WS_MAXIMIZED );
         else hb_retni( WS_NORMAL );
      } else hb_retni( f->FWindowState );
   }
   else if( strcasecmp(szProp,"nFormStyle")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FFormStyle );
   else if( strcasecmp(szProp,"lKeyPreview")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FKeyPreview );
   else if( strcasecmp(szProp,"lAlphaBlend")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FAlphaBlend );
   else if( strcasecmp(szProp,"nAlphaBlendValue")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FAlphaBlendValue );
   else if( strcasecmp(szProp,"nCursor")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FCursor );
   else if( strcasecmp(szProp,"lShowHint")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FShowHint );
   else if( strcasecmp(szProp,"cAppTitle")==0 && p->FControlType==CT_FORM )
      hb_retc( ((HBForm *)p)->FAppTitle );
   else if( strcasecmp(szProp,"cHint")==0 && p->FControlType==CT_FORM )
      hb_retc( ((HBForm *)p)->FHint );
   else if( strcasecmp(szProp,"lAutoScroll")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FAutoScroll );
   else if( strcasecmp(szProp,"lDoubleBuffered")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FDoubleBuffered );
   else if( strcasecmp(szProp,"nBorderWidth")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FBorderWidth );
   else if( strcasecmp(szProp,"nClientWidth")==0 && p->FControlType==CT_FORM ) {
      HBForm * f = (HBForm *)p;
      if( f->FWindow ) hb_retni( (int)[[f->FWindow contentView] bounds].size.width );
      else hb_retni( f->FWidth );
   }
   else if( strcasecmp(szProp,"nClientHeight")==0 && p->FControlType==CT_FORM ) {
      HBForm * f = (HBForm *)p;
      if( f->FWindow ) hb_retni( (int)[[f->FWindow contentView] bounds].size.height );
      else hb_retni( f->FHeight );
   }
   else if( strcasecmp(szProp,"nItemIndex")==0 && p->FControlType==CT_COMBOBOX )
      hb_retni( ((HBComboBox *)p)->FItemIndex );
   else if( strcasecmp(szProp,"nClrPane")==0 )   hb_retnint( (HB_MAXINT)p->FClrPane );
   else if( strcasecmp(szProp,"oFont")==0 ) {
      char szFont[192] = "System,12";
      if( p->FFont ) {
         sprintf(szFont,"%s,%d", [[p->FFont fontName] UTF8String], (int)[p->FFont pointSize]);
         if( p->FClrText != 0xFFFFFFFF ) {
            char szClr[16];
            sprintf(szClr,",%02X%02X%02X", (p->FClrText & 0xFF), ((p->FClrText>>8)&0xFF), ((p->FClrText>>16)&0xFF));
            strcat(szFont, szClr);
         }
      }
      hb_retc( szFont );
   }
   else if( strcasecmp(szProp,"cFontName")==0 )
      hb_retc( p->FFont ? [[p->FFont displayName] UTF8String] : "System" );
   else if( strcasecmp(szProp,"nFontSize")==0 )
      hb_retni( p->FFont ? (int)[p->FFont pointSize] : 12 );
   else hb_ret();
}

/* --- Events --- */

HB_FUNC( UI_ONEVENT )
{
   HBControl * p = GetCtrl(1);
   const char * ev = hb_parc(2);
   PHB_ITEM blk = hb_param(3, HB_IT_BLOCK);
   if( p && ev && blk ) [p setEvent:ev block:blk];
}

/* --- ComboBox --- */

HB_FUNC( UI_COMBOADDITEM )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   if( p && p->FControlType == CT_COMBOBOX && HB_ISCHAR(2) ) [p addItem:hb_parc(2)];
}
HB_FUNC( UI_COMBOSETINDEX )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   if( p && p->FControlType == CT_COMBOBOX ) [p setItemIndex:hb_parni(2)];
}
HB_FUNC( UI_COMBOGETITEM )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1); int n = hb_parni(2)-1;
   if( p && p->FControlType == CT_COMBOBOX && n >= 0 && n < p->FItemCount ) hb_retc(p->FItems[n]);
   else hb_retc("");
}
HB_FUNC( UI_COMBOGETCOUNT )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   hb_retni( p && p->FControlType == CT_COMBOBOX ? p->FItemCount : 0 );
}

/* --- Children --- */

HB_FUNC( UI_GETCHILDCOUNT ) { HBControl * p = GetCtrl(1); hb_retni( p ? p->FChildCount : 0 ); }
HB_FUNC( UI_GETCHILD )
{
   HBControl * p = GetCtrl(1); int n = hb_parni(2)-1;
   if( p && n >= 0 && n < p->FChildCount ) hb_retnint((HB_PTRUINT)(__bridge void *)p->FChildren[n]);
   else hb_retnint(0);
}
HB_FUNC( UI_GETTYPE ) { HBControl * p = GetCtrl(1); hb_retni( p ? p->FControlType : -1 ); }

/* --- Introspection --- */

HB_FUNC( UI_GETPROPCOUNT )
{
   HBControl * p = GetCtrl(1); int n = 0;
   if( p ) { n = 8;
      switch(p->FControlType) { case CT_BUTTON: n+=2; break; case CT_CHECKBOX: n+=1; break;
         case CT_EDIT: n+=2; break; case CT_COMBOBOX: n+=2; break; }
   }
   hb_retni(n);
}

HB_FUNC( UI_GETALLPROPS )
{
   HBControl * p = GetCtrl(1);
   PHB_ITEM pArray, pRow;
   if( !p ) { hb_reta(0); return; }
   pArray = hb_itemArrayNew(0);

   #define ADD_S(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetC(pRow,2,v); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"S"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   #define ADD_N(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetNI(pRow,2,v); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"N"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   #define ADD_L(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetL(pRow,2,v); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"L"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   #define ADD_C(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetNInt(pRow,2,(HB_MAXINT)(v)); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"C"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   #define ADD_F(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetC(pRow,2,v); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"F"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   /* Path/file: shows "..." button that opens a file picker */
   #define ADD_P(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetC(pRow,2,v); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"P"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   /* Array: value stored as "|"-separated string, edited via multi-line dialog */
   #define ADD_A(n,v,c) pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetC(pRow,2,v); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"A"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);
   /* Dropdown: value stored as "index|opt0|opt1|opt2|..." */
   #define ADD_D(n,v,opts,c) { char _db[512]; snprintf(_db,sizeof(_db),"%d|%s",v,opts); \
      pRow=hb_itemArrayNew(4); hb_arraySetC(pRow,1,n); hb_arraySetC(pRow,2,_db); \
      hb_arraySetC(pRow,3,c); hb_arraySetC(pRow,4,"D"); hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow); }

   ADD_S("cClassName",p->FClassName,"Info");
   ADD_S("cName",p->FName,"Appearance");
   ADD_S("cText",p->FText,"Appearance");
   ADD_N("nLeft",p->FLeft,"Position"); ADD_N("nTop",p->FTop,"Position");
   ADD_N("nWidth",p->FWidth,"Position"); ADD_N("nHeight",p->FHeight,"Position");
   ADD_L("lVisible",p->FVisible,"Behavior"); ADD_L("lEnabled",p->FEnabled,"Behavior");
   ADD_L("lTabStop",p->FTabStop,"Behavior");

   { char sf[192]="System,12";
     if(p->FFont) {
        sprintf(sf,"%s,%d",[[p->FFont fontName] UTF8String],(int)[p->FFont pointSize]);
        if( p->FClrText != 0xFFFFFFFF ) {
           char sc[16]; sprintf(sc,",%02X%02X%02X",(p->FClrText&0xFF),((p->FClrText>>8)&0xFF),((p->FClrText>>16)&0xFF));
           strcat(sf,sc);
        }
     }
     ADD_F("oFont",sf,"Appearance"); }
   ADD_C("nClrPane",p->FClrPane,"Appearance");

   switch(p->FControlType) {
      case CT_FORM: {
         HBForm * f = (HBForm *)p;
         ADD_S("cAppTitle",f->FAppTitle,"Appearance");
         ADD_D("nBorderStyle",f->FBorderStyle,"bsNone|bsSingle|bsSizeable|bsDialog|bsToolWindow|bsSizeToolWin","Appearance");
         ADD_N("nBorderIcons",f->FBorderIcons,"Appearance");
         ADD_N("nBorderWidth",f->FBorderWidth,"Appearance");
         ADD_D("nPosition",f->FPosition,"poDesigned|poDefault|poScreenCenter|poDesktopCenter|poMainFormCenter","Position");
         ADD_D("nWindowState",f->FWindowState,"wsNormal|wsMinimized|wsMaximized","Appearance");
         ADD_D("nFormStyle",f->FFormStyle,"fsNormal|fsStayOnTop","Appearance");
         ADD_L("lSizable",f->FSizable,"Behavior");
         ADD_L("lAppBar",f->FAppBar,"Behavior");
         ADD_L("lKeyPreview",f->FKeyPreview,"Behavior");
         ADD_L("lAlphaBlend",f->FAlphaBlend,"Appearance");
         ADD_N("nAlphaBlendValue",f->FAlphaBlendValue,"Appearance");
         ADD_D("nCursor",f->FCursor,"crDefault|crArrow|crCross|crIBeam|crHand|crNo","Appearance");
         ADD_L("lShowHint",f->FShowHint,"Behavior");
         ADD_S("cHint",f->FHint,"Behavior");
         ADD_L("lAutoScroll",f->FAutoScroll,"Behavior");
         ADD_L("lDoubleBuffered",f->FDoubleBuffered,"Behavior");
         int cw = f->FWidth, ch = f->FHeight;
         if( f->FWindow ) { cw = (int)[[f->FWindow contentView] bounds].size.width;
            ch = (int)[[f->FWindow contentView] bounds].size.height; }
         ADD_N("nClientWidth",cw,"Position");
         ADD_N("nClientHeight",ch,"Position");
         break;
      }
      case CT_BUTTON:
         ADD_L("lDefault",((HBButton*)p)->FDefault,"Behavior");
         ADD_L("lCancel",((HBButton*)p)->FCancel,"Behavior"); break;
      case CT_CHECKBOX: ADD_L("lChecked",((HBCheckBox*)p)->FChecked,"Data"); break;
      case CT_LABEL: ADD_L("lTransparent",p->FTransparent,"Appearance");
         ADD_C("nClrText",p->FClrText,"Appearance");
         ADD_D("nAlign",p->nAlign,"Left|Center|Right","Appearance"); break;
      case CT_EDIT:
         ADD_L("lReadOnly",((HBEdit*)p)->FReadOnly,"Behavior");
         ADD_L("lPassword",((HBEdit*)p)->FPassword,"Behavior");
         ADD_D("nAlign",p->nAlign,"Left|Center|Right","Appearance"); break;
      case CT_COMBOBOX:
         ADD_N("nItemIndex",((HBComboBox*)p)->FItemIndex,"Data");
         ADD_N("nItemCount",((HBComboBox*)p)->FItemCount,"Data"); break;
      case CT_DBFTABLE: {
         int rddIdx = 0;
         if( strcasecmp(p->FRdd,"DBFNTX") == 0 ) rddIdx = 1;
         else if( strcasecmp(p->FRdd,"DBFFPT") == 0 ) rddIdx = 2;
         ADD_P("cFileName",p->FFileName,"Data");
         ADD_D("cRDD",rddIdx,"DBFCDX|DBFNTX|DBFFPT","Data");
         ADD_L("lActive",p->FActive,"Data"); break;
      }
      case CT_COMPARRAY:
         ADD_A("aHeaders",p->FHeaders,"Data");
         ADD_A("aData",p->FData,"Data"); break;
      case CT_BROWSE:
         ADD_A("aColumns",p->FHeaders,"Data");
         ADD_S("cDataSource",p->FDataSource,"Data"); break;
      case CT_TIMER:
         ADD_N("nInterval",p->FInterval,"Behavior"); break;
      case CT_TABCONTROL2:
         ADD_A("aTabs",p->FHeaders,"Behavior"); break;
      case CT_TREEVIEW:
         ADD_A("aItems",p->FHeaders,"Data"); break;
   }
   hb_itemReturnRelease(pArray);
}

/* UI_GetAllEvents( hCtrl ) --> { { "EventName", lAssigned, "Category" }, ... }
 * Returns all events for a control with assignment status */
HB_FUNC( UI_GETALLEVENTS )
{
   HBControl * p = GetCtrl(1);
   PHB_ITEM pArray, pRow;
   if( !p ) { hb_reta(0); return; }
   pArray = hb_itemArrayNew(0);

   #define ADD_E(n,assigned,c) pRow=hb_itemArrayNew(3); hb_arraySetC(pRow,1,n); \
      hb_arraySetL(pRow,2,assigned); hb_arraySetC(pRow,3,c); \
      hb_arrayAdd(pArray,pRow); hb_itemRelease(pRow);

   switch( p->FControlType ) {
      case CT_FORM: {
         HBForm * f = (HBForm *)p;
         /* Action */
         ADD_E("OnClick",       f->FOnClick != NULL,      "Action");
         ADD_E("OnDblClick",    f->FOnDblClick != NULL,   "Action");
         /* Lifecycle */
         ADD_E("OnCreate",      f->FOnCreate != NULL,     "Lifecycle");
         ADD_E("OnDestroy",     f->FOnDestroy != NULL,    "Lifecycle");
         ADD_E("OnShow",        f->FOnShow != NULL,       "Lifecycle");
         ADD_E("OnHide",        f->FOnHide != NULL,       "Lifecycle");
         ADD_E("OnClose",       f->FOnClose != NULL,      "Lifecycle");
         ADD_E("OnCloseQuery",  f->FOnCloseQuery != NULL, "Lifecycle");
         ADD_E("OnActivate",    f->FOnActivate != NULL,   "Lifecycle");
         ADD_E("OnDeactivate",  f->FOnDeactivate != NULL, "Lifecycle");
         /* Layout */
         ADD_E("OnResize",      f->FOnResize != NULL,     "Layout");
         ADD_E("OnPaint",       f->FOnPaint != NULL,      "Layout");
         /* Keyboard */
         ADD_E("OnKeyDown",     f->FOnKeyDown != NULL,    "Keyboard");
         ADD_E("OnKeyUp",       f->FOnKeyUp != NULL,      "Keyboard");
         ADD_E("OnKeyPress",    f->FOnKeyPress != NULL,   "Keyboard");
         /* Mouse */
         ADD_E("OnMouseDown",   f->FOnMouseDown != NULL,  "Mouse");
         ADD_E("OnMouseUp",     f->FOnMouseUp != NULL,    "Mouse");
         ADD_E("OnMouseMove",   f->FOnMouseMove != NULL,  "Mouse");
         ADD_E("OnMouseWheel",  f->FOnMouseWheel != NULL, "Mouse");
         break;
      }
      case CT_BUTTON:
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnEnter",       0,                     "Focus");
         ADD_E("OnExit",        0,                     "Focus");
         ADD_E("OnKeyDown",     0,                     "Keyboard");
         ADD_E("OnKeyUp",       0,                     "Keyboard");
         ADD_E("OnKeyPress",    0,                     "Keyboard");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
      case CT_EDIT:
         ADD_E("OnChange",      p->FOnChange != NULL,  "Action");
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnDblClick",    0,                     "Action");
         ADD_E("OnEnter",       0,                     "Focus");
         ADD_E("OnExit",        0,                     "Focus");
         ADD_E("OnKeyDown",     0,                     "Keyboard");
         ADD_E("OnKeyUp",       0,                     "Keyboard");
         ADD_E("OnKeyPress",    0,                     "Keyboard");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
      case CT_CHECKBOX:
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnEnter",       0,                     "Focus");
         ADD_E("OnExit",        0,                     "Focus");
         ADD_E("OnKeyDown",     0,                     "Keyboard");
         ADD_E("OnKeyUp",       0,                     "Keyboard");
         ADD_E("OnKeyPress",    0,                     "Keyboard");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
      case CT_COMBOBOX:
         ADD_E("OnChange",      p->FOnChange != NULL,  "Action");
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnDblClick",    0,                     "Action");
         ADD_E("OnDropDown",    0,                     "Action");
         ADD_E("OnCloseUp",     0,                     "Action");
         ADD_E("OnEnter",       0,                     "Focus");
         ADD_E("OnExit",        0,                     "Focus");
         ADD_E("OnKeyDown",     0,                     "Keyboard");
         ADD_E("OnKeyUp",       0,                     "Keyboard");
         ADD_E("OnKeyPress",    0,                     "Keyboard");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
      case CT_LABEL:
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnDblClick",    0,                     "Action");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
      case CT_GROUPBOX:
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnDblClick",    0,                     "Action");
         ADD_E("OnEnter",       0,                     "Focus");
         ADD_E("OnExit",        0,                     "Focus");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
      default:
         /* Generic fallback */
         ADD_E("OnClick",       p->FOnClick != NULL,   "Action");
         ADD_E("OnChange",      p->FOnChange != NULL,  "Action");
         ADD_E("OnEnter",       0,                     "Focus");
         ADD_E("OnExit",        0,                     "Focus");
         ADD_E("OnKeyDown",     0,                     "Keyboard");
         ADD_E("OnKeyUp",       0,                     "Keyboard");
         ADD_E("OnKeyPress",    0,                     "Keyboard");
         ADD_E("OnMouseDown",   0,                     "Mouse");
         ADD_E("OnMouseUp",     0,                     "Mouse");
         ADD_E("OnMouseMove",   0,                     "Mouse");
         break;
   }
   #undef ADD_E

   hb_itemReturnRelease(pArray);
}

/* --- JSON --- */

HB_FUNC( UI_FORMTOJSON )
{
   HBForm * pForm = GetForm(1);
   char buf[16384], tmp[512]; int pos = 0;
   if( !pForm ) { hb_retc("{}"); return; }
   #define ADDC(s) { int l=(int)strlen(s); if(pos+l<(int)sizeof(buf)-1){strcpy(buf+pos,s);pos+=l;} }
   ADDC("{\"class\":\"Form\"")
   sprintf(tmp,",\"w\":%d,\"h\":%d",pForm->FWidth,pForm->FHeight); ADDC(tmp)
   sprintf(tmp,",\"text\":\"%s\"",pForm->FText); ADDC(tmp)
   ADDC(",\"children\":[")
   for( int i = 0; i < pForm->FChildCount; i++ ) {
      HBControl * p = pForm->FChildren[i];
      if( i > 0 ) ADDC(",")
      ADDC("{")
      sprintf(tmp,"\"type\":%d,\"name\":\"%s\"",p->FControlType,p->FName); ADDC(tmp)
      sprintf(tmp,",\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d",p->FLeft,p->FTop,p->FWidth,p->FHeight); ADDC(tmp)
      sprintf(tmp,",\"text\":\"%s\"",p->FText); ADDC(tmp)
      if( p->FControlType==CT_BUTTON ) {
         sprintf(tmp,",\"default\":%s,\"cancel\":%s",((HBButton*)p)->FDefault?"true":"false",((HBButton*)p)->FCancel?"true":"false"); ADDC(tmp) }
      if( p->FControlType==CT_CHECKBOX ) {
         sprintf(tmp,",\"checked\":%s",((HBCheckBox*)p)->FChecked?"true":"false"); ADDC(tmp) }
      if( p->FControlType==CT_COMBOBOX ) {
         HBComboBox * cb=(HBComboBox*)p;
         sprintf(tmp,",\"sel\":%d,\"items\":[",cb->FItemIndex); ADDC(tmp)
         for( int j=0; j<cb->FItemCount; j++ ) { if(j>0) ADDC(",") sprintf(tmp,"\"%s\"",cb->FItems[j]); ADDC(tmp) }
         ADDC("]") }
      ADDC("}")
   }
   ADDC("]}") buf[pos]=0;
   hb_retclen(buf,pos);
   #undef ADDC
}

/* ======================================================================
 * Toolbar bridge
 * ====================================================================== */

HB_FUNC( UI_TOOLBARNEW )
{
   HBForm * pForm = GetForm(1);
   HBToolBar * p = [[HBToolBar alloc] init];
   KeepAlive( (HBControl *)p );
   if( pForm && pForm->FToolBarCount < 4 ) {
      pForm->FToolBars[pForm->FToolBarCount++] = p;
      p->FCtrlParent = (HBControl *)pForm;
   }
   hb_retnint( (HB_PTRUINT) p );
}

HB_FUNC( UI_TOOLBTNADD )
{
   HBToolBar * p = (__bridge HBToolBar *)(void *)(HB_PTRUINT)hb_parnint(1);
   if( p && p->FControlType == CT_TOOLBAR )
      hb_retni( [p addButton:hb_parc(2) tooltip:HB_ISCHAR(3)?hb_parc(3):""] );
   else hb_retni( -1 );
}

HB_FUNC( UI_TOOLBTNADDSEP )
{
   HBToolBar * p = (__bridge HBToolBar *)(void *)(HB_PTRUINT)hb_parnint(1);
   if( p && p->FControlType == CT_TOOLBAR ) [p addSeparator];
}

HB_FUNC( UI_TOOLBTNONCLICK )
{
   HBToolBar * p = (__bridge HBToolBar *)(void *)(HB_PTRUINT)hb_parnint(1);
   PHB_ITEM pBlock = hb_param(3, HB_IT_BLOCK);
   if( p && p->FControlType == CT_TOOLBAR && pBlock )
      [p setBtnClick:hb_parni(2) block:pBlock];
}

/* UI_ToolBtnHighlight( hToolbar, nBtn, lHighlight )
 * nBtn is 1-based. Sets/clears a colored background on the button. */
HB_FUNC( UI_TOOLBTNHIGHLIGHT )
{
   HBToolBar * p = (__bridge HBToolBar *)(void *)(HB_PTRUINT)hb_parnint(1);
   int nBtn = hb_parni(2) - 1;
   BOOL bOn = hb_parl(3);
   if( !p || p->FControlType != CT_TOOLBAR || !p->FView ) return;

   /* Find the nth NSButton in the toolbar subviews */
   int idx = 0;
   for( NSView * sv in [p->FView subviews] )
   {
      if( ![sv isKindOfClass:[NSButton class]] ) continue;
      if( idx == nBtn )
      {
         NSButton * btn = (NSButton *)sv;
         btn.wantsLayer = YES;
         if( bOn )
            btn.layer.backgroundColor = [[NSColor colorWithSRGBRed:0.8 green:0.2 blue:0.2 alpha:0.7] CGColor];
         else
            btn.layer.backgroundColor = nil;
         break;
      }
      idx++;
   }
}

/* SliceBmpStrip - load a BMP strip, slice into 32x32 icons with magenta transparency.
 * BMP has no alpha channel, so we create a new RGBA bitmap and write pixels directly. */
static NSMutableArray * SliceBmpStrip( const char * szPath )
{
   NSString * path = [NSString stringWithUTF8String:szPath];
   NSImage * strip = [[NSImage alloc] initWithContentsOfFile:path];
   if( !strip ) return nil;

   /* Use actual pixel dimensions from CGImage, not point size (which varies with DPI/Retina) */
   CGImageRef cgStrip = [strip CGImageForProposedRect:NULL context:nil hints:nil];
   if( !cgStrip ) return nil;

   int pixelW = (int)CGImageGetWidth( cgStrip );
   int pixelH = (int)CGImageGetHeight( cgStrip );
   int iconW = 32, iconH = pixelH;
   int nIcons = pixelW / iconW;

   NSMutableArray * icons = [NSMutableArray arrayWithCapacity:nIcons];
   for( int i = 0; i < nIcons; i++ )
   {
      CGImageRef tile = CGImageCreateWithImageInRect( cgStrip,
         CGRectMake( i * iconW, 0, iconW, iconH ) );
      if( !tile ) continue;

      /* Draw tile into a 32-bit RGBA context so we have an alpha channel */
      CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
      uint8_t * pixels = (uint8_t *)calloc( iconW * iconH * 4, 1 );
      CGContextRef ctx = CGBitmapContextCreate( pixels, iconW, iconH, 8,
         iconW * 4, cs, kCGImageAlphaPremultipliedLast );
      CGContextDrawImage( ctx, CGRectMake( 0, 0, iconW, iconH ), tile );
      CGImageRelease( tile );

      /* Replace magenta (R>240, G<16, B>240) with transparent */
      for( int p = 0; p < iconW * iconH; p++ )
      {
         uint8_t r = pixels[p * 4];
         uint8_t g = pixels[p * 4 + 1];
         uint8_t b = pixels[p * 4 + 2];
         if( r > 240 && g < 16 && b > 240 )
         {
            pixels[p * 4]     = 0;
            pixels[p * 4 + 1] = 0;
            pixels[p * 4 + 2] = 0;
            pixels[p * 4 + 3] = 0;
         }
      }

      CGImageRef rgbaImage = CGBitmapContextCreateImage( ctx );
      CGContextRelease( ctx );
      free( pixels );
      CGColorSpaceRelease( cs );

      if( rgbaImage )
      {
         NSImage * icon = [[NSImage alloc] initWithCGImage:rgbaImage
            size:NSMakeSize( iconW, iconH )];
         CGImageRelease( rgbaImage );
         [icons addObject:icon];
      }
   }
   return icons;
}

/* UI_ToolBarLoadImages( hToolBar, cBmpPath )
 * Load a BMP strip of 32x32 icons and apply to toolbar buttons.
 * Magenta (255,0,255) is treated as transparency mask. */
HB_FUNC( UI_TOOLBARLOADIMAGES )
{
   HBToolBar * p = (__bridge HBToolBar *)(void *)(HB_PTRUINT)hb_parnint(1);
   const char * szPath = hb_parc(2);
   if( !p || p->FControlType != CT_TOOLBAR || !szPath ) return;

   NSMutableArray * icons = SliceBmpStrip( szPath );
   if( !icons || [icons count] == 0 ) return;

   /* Store icons - they will be applied when createViewInParent runs */
   p->FIconImages = icons;

   /* If view already exists, apply icons now */
   if( p->FView )
   {
      int imgIdx = 0;
      for( NSView * sv in [p->FView subviews] )
      {
         if( imgIdx >= (int)[icons count] ) break;
         if( ![sv isKindOfClass:[NSButton class]] ) continue;
         NSButton * btn = (NSButton *)sv;
         NSImage * img = icons[imgIdx];
         [img setSize:NSMakeSize(28, 28)];
         [btn setImage:img];
         [btn setImagePosition:NSImageOnly];
         [btn setTitle:@""];
         [btn setBordered:NO];
         NSRect f = [btn frame];
         f.size.width = 40;
         f.size.height = 40;
         [btn setFrame:f];
         imgIdx++;
      }
      /* Re-layout */
      int xPos = 4;
      int maxH = 0;
      for( NSView * sv in [p->FView subviews] )
      {
         NSRect f = [sv frame];
         f.origin.x = xPos;
         f.origin.y = 2;
         [sv setFrame:f];
         if( (int)f.size.height > maxH ) maxH = (int)f.size.height;
         if( [sv isKindOfClass:[NSBox class]] )
            xPos += 8;
         else
            xPos += (int)f.size.width + 2;
      }
      p->FWidth = xPos + 4;
      NSRect tbFrame = [p->FView frame];
      tbFrame.size.width = p->FWidth;
      tbFrame.size.height = maxH + 4;
      [p->FView setFrame:tbFrame];
   }
}

/* ======================================================================
 * Menu bridge
 * ====================================================================== */

/* Menu storage: use tag-based approach with NSMenu */
static NSMenu * s_currentMenuBar = nil;

HB_FUNC( UI_MENUBARCREATE )
{
   /* On macOS, we use the application menu bar */
   EnsureNSApp();
   NSMenu * menuBar = [[NSMenu alloc] init];
   [NSApp setMainMenu:menuBar];
   s_currentMenuBar = menuBar;
}

HB_FUNC( UI_MENUPOPUPADD )
{
   HBForm * pForm = GetForm(1);
   EnsureNSApp();
   NSMenu * menuBar = [NSApp mainMenu];
   if( !menuBar ) { menuBar = [[NSMenu alloc] init]; [NSApp setMainMenu:menuBar]; }
   NSMenuItem * item = [[NSMenuItem alloc] init];
   NSMenu * popup = [[NSMenu alloc] initWithTitle:[NSString stringWithUTF8String:hb_parc(2)]];
   [item setSubmenu:popup];
   [menuBar addItem:item];
   hb_retnint( (HB_PTRUINT) popup );
}

HB_FUNC( UI_MENUITEMADD ) { hb_retni( -1 ); }  /* Stub - use UI_MENUITEMADDEX */

/* Helper target for menu actions */
@interface HBMenuTarget : NSObject
{ @public PHB_ITEM pAction; }
- (void)menuAction:(id)sender;
@end
@implementation HBMenuTarget
- (void)menuAction:(id)sender {
   if( pAction && HB_IS_BLOCK(pAction) ) {
      hb_vmPushEvalSym(); hb_vmPush(pAction); hb_vmSend(0);
   }
}
@end

static NSMutableArray * s_menuTargets = nil;

HB_FUNC( UI_MENUITEMADDEX )
{
   HBForm * pForm = GetForm(1);
   NSMenu * popup = (__bridge NSMenu *)(void *)(HB_PTRUINT)hb_parnint(2);
   PHB_ITEM pBlock = hb_param(4, HB_IT_BLOCK);

   if( !popup || !HB_ISCHAR(3) ) { hb_retni(-1); return; }

   if( !s_menuTargets ) s_menuTargets = [[NSMutableArray alloc] init];

   HBMenuTarget * target = [[HBMenuTarget alloc] init];
   target->pAction = pBlock ? hb_itemNew(pBlock) : NULL;
   [s_menuTargets addObject:target];

   /* Build clean title (strip &, it's a Windows convention) */
   const char * text = hb_parc(3);
   NSString * title = [NSString stringWithUTF8String:text];
   title = [title stringByReplacingOccurrencesOfString:@"&" withString:@""];

   /* Key equivalent from optional 5th parameter (e.g. "n", "o", "s") */
   NSString * keyEq = @"";
   if( HB_ISCHAR(5) && hb_parclen(5) > 0 )
      keyEq = [NSString stringWithUTF8String:hb_parc(5)];

   NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:title
      action:@selector(menuAction:) keyEquivalent:keyEq];
   [item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
   [item setTarget:target];
   [popup addItem:item];

   int idx = pForm ? pForm->FMenuItemCount++ : 0;
   if( pForm && pBlock ) pForm->FMenuActions[idx] = hb_itemNew(pBlock);
   hb_retni( idx );
}

HB_FUNC( UI_MENUSEPADD )
{
   NSMenu * popup = (__bridge NSMenu *)(void *)(HB_PTRUINT)hb_parnint(2);
   if( popup ) [popup addItem:[NSMenuItem separatorItem]];
}

HB_FUNC( UI_FORMSETSIZABLE )
{
   HBForm * p = GetForm(1);
   if( p ) p->FSizable = hb_parl(2);
}

HB_FUNC( UI_FORMSETAPPBAR )
{
   HBForm * p = GetForm(1);
   if( p ) p->FAppBar = hb_parl(2);
}

HB_FUNC( UI_FORMGETHWND )
{
   /* macOS doesn't use HWND, return the object pointer as handle */
   HBForm * p = GetForm(1);
   hb_retnint( p ? (HB_PTRUINT)(__bridge void *)p : 0 );
}

/* ======================================================================
 * Component Palette (macOS - NSSegmentedControl tabs + NSButton components)
 * ====================================================================== */

/* Show buttons for a given tab */
static void PalShowTab( PALDATA * pd, int nTab )
{
   if( !pd || nTab < 0 || nTab >= pd->nTabCount ) return;
   pd->nCurrentTab = nTab;

   /* Remove existing buttons */
   for( int i = 0; i < MAX_PALETTE_BTNS; i++ ) {
      if( pd->buttons[i] ) {
         [pd->buttons[i] removeFromSuperview];
         pd->buttons[i] = nil;
      }
   }

   /* Create 52x50 buttons for this tab */
   PaletteTab * t = &pd->tabs[nTab];
   CGFloat xPos = 4;
   int btnW = 52, btnH = 50;
   CGFloat y = 0;

   /* Icons in palette.bmp are laid out sequentially following the AddComp
    * order across tabs, not keyed by nControlType. Compute this tab's base
    * index by summing prior tabs' button counts. */
   int imgBase = 0;
   for( int k = 0; k < nTab; k++ ) imgBase += pd->tabs[k].nBtnCount;

   for( int i = 0; i < t->nBtnCount; i++ ) {
      NSString * title = [NSString stringWithUTF8String:t->btns[i].szText];
      NSFont * btnFont = [NSFont systemFontOfSize:11];
      int thisBtnW = btnW;

      int imgIdx = imgBase + i;
      BOOL hasImage = ( pd->palImages && imgIdx >= 0 && imgIdx < (int)[pd->palImages count] );

      if( !hasImage ) {
         NSDictionary * attrs = @{ NSFontAttributeName: btnFont };
         CGFloat textW = [title sizeWithAttributes:attrs].width;
         thisBtnW = (int)(textW + 24);
         if( thisBtnW < btnW ) thisBtnW = btnW;
      }

      NSButton * btn = [[NSButton alloc] initWithFrame:NSMakeRect( xPos, y, thisBtnW, btnH )];
      [btn setBezelStyle:NSBezelStyleSmallSquare];
      [btn setFont:btnFont];

      if( hasImage ) {
         [btn setImage:pd->palImages[imgIdx]];
         [btn setImagePosition:NSImageOnly];
         [btn setTitle:@""];
      } else {
         [btn setTitle:title];
      }
      [btn setToolTip:[NSString stringWithUTF8String:t->btns[i].szTooltip]];
      [btn setTarget:s_palTarget];
      [btn setAction:@selector(palBtnClicked:)];
      [pd->btnPanel addSubview:btn];
      pd->buttons[i] = btn;
      xPos += thisBtnW + 2;
   }
}

/* UI_PaletteNew( hForm ) --> hPalette */
HB_FUNC( UI_PALETTENEW )
{
   HBForm * pForm = GetForm(1);
   if( !pForm ) { hb_retnint(0); return; }

   PALDATA * pd = (PALDATA *) calloc( 1, sizeof(PALDATA) );
   pd->parentForm = pForm;
   s_palData = pd;

   /* Return a control handle (use a lightweight HBControl) */
   HBControl * p = [[HBControl alloc] init];
   strcpy( p->FClassName, "TComponentPalette" );
   p->FControlType = CT_TABCONTROL;
   KeepAlive( p );
   hb_retnint( (HB_PTRUINT)(__bridge void *)p );
}

/* UI_PaletteAddTab( hPalette, cName ) --> nTabIndex */
HB_FUNC( UI_PALETTEADDTAB )
{
   PALDATA * pd = s_palData;
   if( pd && pd->nTabCount < MAX_PALETTE_TABS && HB_ISCHAR(2) ) {
      int idx = pd->nTabCount++;
      strncpy( pd->tabs[idx].szName, hb_parc(2), 31 );
      pd->tabs[idx].nBtnCount = 0;
      hb_retni( idx );
   } else
      hb_retni( -1 );
}

/* UI_PaletteAddComp( hPalette, nTab, cText, cTooltip, nCtrlType ) */
HB_FUNC( UI_PALETTEADDCOMP )
{
   PALDATA * pd = s_palData;
   int nTab = hb_parni(2);
   if( pd && nTab >= 0 && nTab < pd->nTabCount ) {
      PaletteTab * t = &pd->tabs[nTab];
      if( t->nBtnCount < MAX_PALETTE_BTNS ) {
         int idx = t->nBtnCount++;
         strncpy( t->btns[idx].szText, hb_parc(3), 31 );
         strncpy( t->btns[idx].szTooltip, HB_ISCHAR(4) ? hb_parc(4) : "", 127 );
         t->btns[idx].nControlType = hb_parni(5);
      }
   }
}

/* UI_PaletteOnSelect( hPalette, bBlock ) */
HB_FUNC( UI_PALETTEONSELECT )
{
   PALDATA * pd = s_palData;
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( pd ) {
      if( pd->pOnSelect ) hb_itemRelease( pd->pOnSelect );
      pd->pOnSelect = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* UI_PaletteLoadImages( hPalette, cBmpPath )
 * Load a BMP strip of 32x32 icons for component palette buttons.
 * Magenta (255,0,255) is treated as transparency mask. */
HB_FUNC( UI_PALETTELOADIMAGES )
{
   PALDATA * pd = s_palData;
   const char * szPath = hb_parc(2);
   if( !pd || !szPath ) return;

   NSMutableArray * icons = SliceBmpStrip( szPath );
   if( !icons || [icons count] == 0 ) return;

   pd->palImages = icons;

   /* Refresh current tab to show icons */
   if( pd->nTabCount > 0 )
      PalShowTab( pd, pd->nCurrentTab );
}

HB_FUNC( UI_TOOLBARGETWIDTH )
{
   HBToolBar * p = (__bridge HBToolBar *)(void *)(HB_PTRUINT)hb_parnint(1);
   if( p && p->FControlType == CT_TOOLBAR && p->FView )
   {
      NSRect f = [p->FView frame];
      hb_retni( (int) f.size.width );
   }
   else
      hb_retni( 200 );
}

/* ======================================================================
 * StatusBar (macOS)
 * ====================================================================== */

HB_FUNC( UI_STATUSBARCREATE )
{
   /* On macOS, status bar is a thin NSTextField at the bottom of the window */
   /* For now, just mark the form as having a status bar */
   HBForm * p = GetForm(1);
   (void)p;
}

HB_FUNC( UI_STATUSBARSETTEXT )
{
   /* Stub - will be implemented with NSTextField panels */
   HBForm * p = GetForm(1);
   (void)p;
}

HB_FUNC( UI_FORMSELECTCTRL )
{
   HBForm * pForm = GetForm(1);
   HBControl * pCtrl = GetCtrl(2);
   if( pForm && pForm->FDesignMode )
   {
      if( pCtrl && pCtrl != (HBControl *)pForm )
         [pForm selectControl:pCtrl add:NO];
      else
         [pForm clearSelection];
   }
}

/* UI_FormBringToFront( hForm ) - bring form window to front */
HB_FUNC( UI_FORMBRINGTOFRONT )
{
   HBForm * p = GetForm(1);
   if( p && p->FWindow ) {
      [p->FWindow makeKeyAndOrderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
   }
}

/* UI_SetDesignForm( hForm ) - register the form that receives palette drops */
HB_FUNC( UI_SETDESIGNFORM )
{
   HBForm * p = GetForm(1);
   s_designForm = p;
}

/* UI_FormSetPending( hForm, nControlType ) - set pending component drop mode
 * nControlType: 1=Label 2=Edit 3=Button 4=CheckBox 5=ComboBox 6=GroupBox, -1=cancel */
HB_FUNC( UI_FORMSETPENDING )
{
   HBForm * p = GetForm(1);
   if( p ) {
      p->FPendingControlType = hb_parni(2);
      /* Change cursor to crosshair when in drop mode */
      if( p->FPendingControlType >= 0 )
         [[NSCursor crosshairCursor] set];
      else
         [[NSCursor arrowCursor] set];
   }
}

/* UI_FormOnComponentDrop( hForm, bBlock )
 * Block receives: hForm, nControlType, nLeft, nTop, nWidth, nHeight */
HB_FUNC( UI_FORMONCOMPONENTDROP )
{
   HBForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p ) {
      if( p->FOnComponentDrop ) hb_itemRelease( p->FOnComponentDrop );
      p->FOnComponentDrop = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

HB_FUNC( UI_FORMSETPOS )
{
   HBForm * p = GetForm(1);
   if( p ) {
      p->FLeft = hb_parni(2);
      p->FTop = hb_parni(3);
      p->FCenter = NO;
      p->FPosition = POS_DESIGNED;
      if( p->FWindow ) {
         /* macOS uses bottom-left origin, flip Y. Use full frame height
            (incl. title bar) — FHeight is content-only. */
         NSRect screenFrame = [[NSScreen mainScreen] frame];
         NSRect fr = [p->FWindow frame];
         NSPoint origin;
         origin.x = p->FLeft;
         origin.y = screenFrame.size.height - p->FTop - fr.size.height;
         [p->FWindow setFrameOrigin:origin];
      }
   }
}

/* --- Window geometry --- */

/* MAC_GetWindowBottom( hForm ) -> nY in top-left coords (where bottom edge of window is) */
HB_FUNC( MAC_GETWINDOWBOTTOM )
{
   HBForm * p = GetForm(1);
   if( p && p->FWindow )
   {
      NSRect screenFrame = [[NSScreen mainScreen] frame];
      NSRect winFrame = [p->FWindow frame];
      /* In macOS coords (bottom-left origin):
         winFrame.origin.y = bottom edge of window
         winFrame.origin.y + winFrame.size.height = top edge of window

         Convert to top-left coords:
         topOfWindow = screenH - (origin.y + height)
         bottomOfWindow = topOfWindow + height = screenH - origin.y
      */
      int bottom = (int)(screenFrame.size.height - winFrame.origin.y);
      hb_retni( bottom );
   }
   else
      hb_retni( 0 );
}

/* --- Screen size --- */

HB_FUNC( MAC_GETSCREENWIDTH )
{
   EnsureNSApp();
   NSRect frame = [[NSScreen mainScreen] frame];
   hb_retni( (int) frame.size.width );
}

HB_FUNC( MAC_GETSCREENHEIGHT )
{
   EnsureNSApp();
   NSRect frame = [[NSScreen mainScreen] frame];
   hb_retni( (int) frame.size.height );
}

/* --- MsgBox --- */

HB_FUNC( MAC_MSGBOX )
{
   EnsureNSApp();
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:hb_parc(2) ? hb_parc(2) : ""]];
   [alert setInformativeText:[NSString stringWithUTF8String:hb_parc(1) ? hb_parc(1) : ""]];
   [alert addButtonWithTitle:@"OK"];
   [alert setAlertStyle:NSAlertStyleInformational];
   [alert runModal];
}

/* UI_MsgBox - cross-platform alias */
HB_FUNC( UI_MSGBOX )
{
   EnsureNSApp();
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:hb_parc(2) ? hb_parc(2) : ""]];
   [alert setInformativeText:[NSString stringWithUTF8String:hb_parc(1) ? hb_parc(1) : ""]];
   [alert addButtonWithTitle:@"OK"];
   [alert setAlertStyle:NSAlertStyleInformational];
   [alert runModal];
}

/* MAC_RuntimeErrorDialog( cTitle, cMsg, aButtons ) --> nChoice
 * Shows error text in a scrollable memo with Copy button + dynamic action buttons.
 * Returns the 1-based index of the pressed button (1=first, 2=second, etc.) */
HB_FUNC( MAC_RUNTIMEERRORDIALOG )
{
   EnsureNSApp();
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Error";
   const char * cMsg   = HB_ISCHAR(2) ? hb_parc(2) : "";
   PHB_ITEM pButtons   = hb_param(3, HB_IT_ARRAY);

   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:cTitle]];
   [alert setAlertStyle:NSAlertStyleCritical];

   /* Add action buttons from array */
   int nBtns = pButtons ? (int) hb_arrayLen( pButtons ) : 0;
   for( int i = 1; i <= nBtns; i++ )
      [alert addButtonWithTitle:[NSString stringWithUTF8String:hb_arrayGetCPtr( pButtons, i )]];
   if( nBtns == 0 )
      [alert addButtonWithTitle:@"OK"];

   /* Add "Copy to Clipboard" button at the end */
   [alert addButtonWithTitle:@"Copy to Clipboard"];

   /* Scrollable text view as accessory (monospaced, dark, read-only) */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 500, 280)];
   [sv setHasVerticalScroller:YES];
   [sv setHasHorizontalScroller:YES];
   [sv setBorderType:NSBezelBorder];

   NSTextView * tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 280)];
   [tv setEditable:NO];
   [tv setSelectable:YES];
   [tv setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
   [tv setString:[NSString stringWithUTF8String:cMsg]];
   [sv setDocumentView:tv];
   [alert setAccessoryView:sv];

   /* Run modal — loop to handle Copy button without closing */
   NSModalResponse r;
   int copyIdx = NSAlertFirstButtonReturn + (nBtns > 0 ? nBtns : 1);
   do {
      r = [alert runModal];
      if( (int)r == copyIdx ) {
         /* Copy to clipboard */
         NSPasteboard * pb = [NSPasteboard generalPasteboard];
         [pb clearContents];
         [pb setString:[NSString stringWithUTF8String:cMsg] forType:NSPasteboardTypeString];
      }
   } while( (int)r == copyIdx );

   /* Return 1-based button index */
   hb_retni( (int)(r - NSAlertFirstButtonReturn) + 1 );
}

/* MAC_AppTerminate() — force quit the macOS application (NSApp terminate) */
HB_FUNC( MAC_APPTERMINATE )
{
   [NSApp terminate:nil];
}

/* MsgYesNoCancel( cText [, cTitle] ) --> nResult  (1=Yes, 2=No, 0=Cancel) */
HB_FUNC( MSGYESNOCANCEL )
{
   EnsureNSApp();
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:HB_ISCHAR(2) ? hb_parc(2) : "Confirm"]];
   [alert setInformativeText:[NSString stringWithUTF8String:HB_ISCHAR(1) ? hb_parc(1) : ""]];
   [alert addButtonWithTitle:@"Yes"];
   [alert addButtonWithTitle:@"No"];
   [alert addButtonWithTitle:@"Cancel"];
   [alert setAlertStyle:NSAlertStyleWarning];
   NSModalResponse r = [alert runModal];
   if( r == NSAlertFirstButtonReturn )       hb_retni( 1 );  /* Yes */
   else if( r == NSAlertSecondButtonReturn )  hb_retni( 2 );  /* No */
   else                                       hb_retni( 0 );  /* Cancel */
}

/* UI_MsgYesNo( cText [, cTitle] ) --> lYes  (.T. if Yes clicked) */
HB_FUNC( UI_MSGYESNO )
{
   EnsureNSApp();
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:HB_ISCHAR(2) ? hb_parc(2) : "Confirm"]];
   [alert setInformativeText:[NSString stringWithUTF8String:HB_ISCHAR(1) ? hb_parc(1) : ""]];
   [alert addButtonWithTitle:@"Yes"];
   [alert addButtonWithTitle:@"No"];
   [alert setAlertStyle:NSAlertStyleWarning];
   NSModalResponse r = [alert runModal];
   hb_retl( r == NSAlertFirstButtonReturn );
}

/* MAC_ShellExec( cCommand ) --> cOutput
 * Execute a shell command and return stdout+stderr as string */
HB_FUNC( MAC_SHELLEXEC )
{
   if( !HB_ISCHAR(1) ) { hb_retc(""); return; }

   NSTask * task = [[NSTask alloc] init];
   [task setLaunchPath:@"/bin/zsh"];
   [task setArguments:@[@"-c", [NSString stringWithUTF8String:hb_parc(1)]]];

   NSPipe * pipe = [NSPipe pipe];
   [task setStandardOutput:pipe];
   [task setStandardError:pipe];

   @try {
      [task launch];
      [task waitUntilExit];

      NSData * data = [[pipe fileHandleForReading] readDataToEndOfFile];
      NSString * output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      hb_retc( output ? [output UTF8String] : "" );
   }
   @catch( NSException * e ) {
      hb_retc( [[e reason] UTF8String] );
   }
}

/* MAC_AboutDialog( cTitle, cMessage, cImagePath ) - show About dialog with logo */
HB_FUNC( MAC_ABOUTDIALOG )
{
   EnsureNSApp();
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:HB_ISCHAR(1) ? hb_parc(1) : "About"]];
   [alert setInformativeText:[NSString stringWithUTF8String:HB_ISCHAR(2) ? hb_parc(2) : ""]];
   [alert addButtonWithTitle:@"OK"];
   [alert setAlertStyle:NSAlertStyleInformational];

   if( HB_ISCHAR(3) )
   {
      NSString * path = [NSString stringWithUTF8String:hb_parc(3)];
      NSImage * logo = [[NSImage alloc] initWithContentsOfFile:path];
      if( logo )
      {
         [logo setSize:NSMakeSize(128, 128)];
         [alert setIcon:logo];
      }
   }

   [alert runModal];
}

/* MAC_OpenFileDialog( [cTitle], [cFilter] ) --> cFilePath or "" */
HB_FUNC( MAC_OPENFILEDIALOG )
{
   EnsureNSApp();
   NSOpenPanel * panel = [NSOpenPanel openPanel];
   [panel setCanChooseFiles:YES];
   [panel setCanChooseDirectories:NO];
   [panel setAllowsMultipleSelection:NO];
   if( HB_ISCHAR(1) )
      [panel setTitle:[NSString stringWithUTF8String:hb_parc(1)]];
   if( HB_ISCHAR(2) )
   {
      NSString * ext = [NSString stringWithUTF8String:hb_parc(2)];
#if HAS_UTTYPE
      if( @available(macOS 11.0, *) )
      {
         UTType * type = [UTType typeWithFilenameExtension:ext];
         if( type )
            [panel setAllowedContentTypes:@[type]];
      }
      else
#endif
      {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
         [panel setAllowedFileTypes:@[ext]];
#pragma clang diagnostic pop
      }
   }
   if( [panel runModal] == NSModalResponseOK )
   {
      NSString * path = [[panel URL] path];
      hb_retc( [path UTF8String] );
   }
   else
      hb_retc( "" );
}

/* MAC_SaveFileDialog( [cTitle], [cDefaultName], [cFilter] ) --> cFilePath or "" */
HB_FUNC( MAC_SAVEFILEDIALOG )
{
   EnsureNSApp();
   NSSavePanel * panel = [NSSavePanel savePanel];
   if( HB_ISCHAR(1) )
      [panel setTitle:[NSString stringWithUTF8String:hb_parc(1)]];
   if( HB_ISCHAR(2) )
      [panel setNameFieldStringValue:[NSString stringWithUTF8String:hb_parc(2)]];
   if( HB_ISCHAR(3) )
   {
      NSString * ext = [NSString stringWithUTF8String:hb_parc(3)];
#if HAS_UTTYPE
      if( @available(macOS 11.0, *) )
      {
         UTType * type = [UTType typeWithFilenameExtension:ext];
         if( type )
            [panel setAllowedContentTypes:@[type]];
      }
      else
#endif
      {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
         [panel setAllowedFileTypes:@[ext]];
#pragma clang diagnostic pop
      }
   }
   if( [panel runModal] == NSModalResponseOK )
   {
      NSString * path = [[panel URL] path];
      hb_retc( [path UTF8String] );
   }
   else
      hb_retc( "" );
}

/* MAC_SelectFromList( cTitle, aItems ) --> nIndex (1-based) or 0 if cancelled */
HB_FUNC( MAC_SELECTFROMLIST )
{
   EnsureNSApp();
   const char * szTitle = HB_ISCHAR(1) ? hb_parc(1) : "Select";
   PHB_ITEM pArray = hb_param(2, HB_IT_ARRAY);
   if( !pArray ) { hb_retni(0); return; }

   HB_SIZE nLen = hb_arrayLen( pArray );
   if( nLen == 0 ) { hb_retni(0); return; }

   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:[NSString stringWithUTF8String:szTitle]];
   [alert addButtonWithTitle:@"OK"];
   [alert addButtonWithTitle:@"Cancel"];

   /* Create popup button with items */
   NSPopUpButton * popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 250, 28) pullsDown:NO];
   for( HB_SIZE i = 1; i <= nLen; i++ )
      [popup addItemWithTitle:[NSString stringWithUTF8String:hb_arrayGetCPtr(pArray, i)]];
   [alert setAccessoryView:popup];

   NSModalResponse result = [alert runModal];
   if( result == NSAlertFirstButtonReturn )
      hb_retni( (int)[popup indexOfSelectedItem] + 1 );
   else
      hb_retni( 0 );
}

/* UI_FormRebuildChildren( hForm ) - recreate NSViews for children added after Show.
   Used by the IDE after RestoreFormFromCode repopulates FChildren but the
   UI_*New() helpers only call addChild (no view creation). */
HB_FUNC( UI_FORMREBUILDCHILDREN )
{
   HBForm * pForm = GetForm(1);
   if( !pForm || !pForm->FContentView ) return;

   /* Remove existing control views (keep dot grid + overlay) */
   for( NSView * sv in [[pForm->FContentView subviews] copy] )
   {
      if( [sv isKindOfClass:[HBDotGridView class]] ) continue;
      if( pForm->FOverlayView && sv == (NSView *)pForm->FOverlayView ) continue;
      [sv removeFromSuperview];
   }

   /* Drop FView refs so createViewInParent rebuilds them */
   for( int i = 0; i < pForm->FChildCount; i++ )
      if( pForm->FChildren[i] )
         pForm->FChildren[i]->FView = nil;

   [pForm createAllChildren];

   /* Keep overlay on top */
   if( pForm->FOverlayView ) {
      [(NSView *)pForm->FOverlayView removeFromSuperview];
      [pForm->FContentView addSubview:(NSView *)pForm->FOverlayView];
      [(NSView *)pForm->FOverlayView setNeedsDisplay:YES];
   }
   [pForm->FContentView setNeedsDisplay:YES];
}

/* UI_FormClearChildren( hForm ) - remove all child controls from form */
HB_FUNC( UI_FORMCLEARCHILDREN )
{
   HBForm * pForm = GetForm(1);
   if( !pForm ) return;

   /* Remove views from content view */
   if( pForm->FContentView )
   {
      for( NSView * sv in [[pForm->FContentView subviews] copy] )
      {
         /* Keep overlay view and dot grid for design mode */
         if( pForm->FOverlayView && sv == (NSView *)pForm->FOverlayView ) continue;
         if( [sv isKindOfClass:[HBDotGridView class]] ) continue;
         [sv removeFromSuperview];
      }
   }

   /* Release child objects */
   for( int i = 0; i < pForm->FChildCount; i++ )
   {
      if( pForm->FChildren[i] )
         [s_allControls removeObject:pForm->FChildren[i]];
      pForm->FChildren[i] = nil;
   }
   pForm->FChildCount = 0;

   /* Clear selection */
   [pForm clearSelection];

   /* Redraw overlay */
   if( pForm->FOverlayView )
      [(NSView *)pForm->FOverlayView setNeedsDisplay:YES];
}

/* ======================================================================
 * Form Designer: Copy/Paste controls + Align/Distribute
 * ====================================================================== */

/* Clipboard for copied controls: type, left, top, width, height, text */
#define MAX_CLIPBOARD 32

static struct {
   int nType;
   int nLeft, nTop, nWidth, nHeight;
   char szText[128];
} s_clipboard[MAX_CLIPBOARD];
static int s_clipCount = 0;

/* UI_FormCopySelected( hForm ) — copy selected controls to clipboard */
HB_FUNC( UI_FORMCOPYSELECTED )
{
   HBForm * pForm = (__bridge HBForm *)(void *)(HB_PTRUINT) hb_parnint(1);
   if( !pForm ) return;

   s_clipCount = 0;
   for( int i = 0; i < pForm->FSelCount && s_clipCount < MAX_CLIPBOARD; i++ )
   {
      HBControl * c = pForm->FSelected[i];
      s_clipboard[s_clipCount].nType   = c->FControlType;
      s_clipboard[s_clipCount].nLeft   = c->FLeft;
      s_clipboard[s_clipCount].nTop    = c->FTop;
      s_clipboard[s_clipCount].nWidth  = c->FWidth;
      s_clipboard[s_clipCount].nHeight = c->FHeight;
      strncpy( s_clipboard[s_clipCount].szText, c->FText, 127 );
      s_clipCount++;
   }
   hb_retni( s_clipCount );
}

/* UI_FormPasteControls( hForm ) --> nPasted — paste with +16px offset */
HB_FUNC( UI_FORMPASTECONTROLS )
{
   HBForm * pForm = (__bridge HBForm *)(void *)(HB_PTRUINT) hb_parnint(1);
   if( !pForm || s_clipCount == 0 ) { hb_retni(0); return; }

   [pForm clearSelection];

   for( int i = 0; i < s_clipCount; i++ )
   {
      /* Create control of the appropriate type */
      HBControl * c = nil;
      int t = s_clipboard[i].nType;
      if( t == CT_LABEL )         c = [[HBLabel alloc] init];
      else if( t == CT_EDIT )     c = [[HBEdit alloc] init];
      else if( t == CT_BUTTON )   c = [[HBButton alloc] init];
      else if( t == CT_CHECKBOX ) c = [[HBCheckBox alloc] init];
      else if( t == CT_COMBOBOX ) c = [[HBComboBox alloc] init];
      else if( t == CT_GROUPBOX ) c = [[HBGroupBox alloc] init];
      else                        c = [[HBControl alloc] init];

      if( c ) {
         c->FControlType = t;
         c->FLeft   = s_clipboard[i].nLeft + 16;
         c->FTop    = s_clipboard[i].nTop + 16;
         c->FWidth  = s_clipboard[i].nWidth;
         c->FHeight = s_clipboard[i].nHeight;
         strncpy( c->FText, s_clipboard[i].szText, sizeof(c->FText) - 1 );
         [pForm addChild:c];
         if( pForm->FSelCount < MAX_CHILDREN )
            pForm->FSelected[pForm->FSelCount++] = c;
      }
   }

   if( pForm->FOverlayView )
      [(NSView *)pForm->FOverlayView setNeedsDisplay:YES];

   hb_retni( s_clipCount );
}

/* UI_FormGetClipCount() --> nCount */
HB_FUNC( UI_FORMGETCLIPCOUNT )
{
   hb_retni( s_clipCount );
}

/* -----------------------------------------------------------------------
 * Align selected controls
 * UI_FormAlignSelected( hForm, nMode )
 *   1=AlignLeft, 2=AlignRight, 3=AlignTop, 4=AlignBottom
 *   5=CenterH, 6=CenterV, 7=SpaceEvenlyH, 8=SpaceEvenlyV
 * ----------------------------------------------------------------------- */

HB_FUNC( UI_FORMALIGNSELECTED )
{
   HBForm * pForm = (__bridge HBForm *)(void *)(HB_PTRUINT) hb_parnint(1);
   int mode = hb_parni(2);
   if( !pForm || pForm->FSelCount < 2 ) return;

   int i, n = pForm->FSelCount;
   int minL = 99999, maxR = 0, minT = 99999, maxB = 0;
   int totalW = 0, totalH = 0;

   /* Find bounding box */
   for( i = 0; i < n; i++ )
   {
      HBControl * c = pForm->FSelected[i];
      if( c->FLeft < minL ) minL = c->FLeft;
      if( c->FTop < minT ) minT = c->FTop;
      if( c->FLeft + c->FWidth > maxR ) maxR = c->FLeft + c->FWidth;
      if( c->FTop + c->FHeight > maxB ) maxB = c->FTop + c->FHeight;
      totalW += c->FWidth;
      totalH += c->FHeight;
   }

   switch( mode )
   {
      case 1: /* Align Left */
         for( i = 0; i < n; i++ ) pForm->FSelected[i]->FLeft = minL;
         break;
      case 2: /* Align Right */
         for( i = 0; i < n; i++ )
            pForm->FSelected[i]->FLeft = maxR - pForm->FSelected[i]->FWidth;
         break;
      case 3: /* Align Top */
         for( i = 0; i < n; i++ ) pForm->FSelected[i]->FTop = minT;
         break;
      case 4: /* Align Bottom */
         for( i = 0; i < n; i++ )
            pForm->FSelected[i]->FTop = maxB - pForm->FSelected[i]->FHeight;
         break;
      case 5: /* Center Horizontally */
      {
         int center = (minL + maxR) / 2;
         for( i = 0; i < n; i++ )
            pForm->FSelected[i]->FLeft = center - pForm->FSelected[i]->FWidth / 2;
         break;
      }
      case 6: /* Center Vertically */
      {
         int center = (minT + maxB) / 2;
         for( i = 0; i < n; i++ )
            pForm->FSelected[i]->FTop = center - pForm->FSelected[i]->FHeight / 2;
         break;
      }
      case 7: /* Space Evenly Horizontal */
      {
         if( n < 3 ) break;
         int gap = (maxR - minL - totalW) / (n - 1);
         /* Sort by left position (bubble sort, small n) */
         for( int a = 0; a < n-1; a++ )
            for( int b = a+1; b < n; b++ )
               if( pForm->FSelected[b]->FLeft < pForm->FSelected[a]->FLeft )
               { HBControl * t = pForm->FSelected[a]; pForm->FSelected[a] = pForm->FSelected[b]; pForm->FSelected[b] = t; }
         int x = minL;
         for( i = 0; i < n; i++ ) {
            pForm->FSelected[i]->FLeft = x;
            x += pForm->FSelected[i]->FWidth + gap;
         }
         break;
      }
      case 8: /* Space Evenly Vertical */
      {
         if( n < 3 ) break;
         int gap = (maxB - minT - totalH) / (n - 1);
         for( int a = 0; a < n-1; a++ )
            for( int b = a+1; b < n; b++ )
               if( pForm->FSelected[b]->FTop < pForm->FSelected[a]->FTop )
               { HBControl * t = pForm->FSelected[a]; pForm->FSelected[a] = pForm->FSelected[b]; pForm->FSelected[b] = t; }
         int y = minT;
         for( i = 0; i < n; i++ ) {
            pForm->FSelected[i]->FTop = y;
            y += pForm->FSelected[i]->FHeight + gap;
         }
         break;
      }
   }

   /* Update all views — reposition NSViews to match new FLeft/FTop */
   for( i = 0; i < n; i++ )
   {
      HBControl * c = pForm->FSelected[i];
      if( c->FView )
      {
         NSRect f = [(NSView *)c->FView frame];
         f.origin.x = c->FLeft;
         f.origin.y = c->FTop + pForm->FClientTop;
         [(NSView *)c->FView setFrame:f];
      }
   }
   if( pForm->FOverlayView )
      [(NSView *)pForm->FOverlayView setNeedsDisplay:YES];
}

/* ======================================================================
 * Form Designer: Undo/Redo history
 * Stores snapshots of all control states before each operation.
 * ====================================================================== */

#define UNDO_MAX_STEPS  50
#define UNDO_MAX_CTRLS  MAX_CHILDREN

typedef struct {
   int nType;
   int nLeft, nTop, nWidth, nHeight;
   char szName[32];
   char szText[128];
} UNDO_CTRL;

typedef struct {
   UNDO_CTRL ctrls[UNDO_MAX_CTRLS];
   int nCount;
} UNDO_SNAPSHOT;

static UNDO_SNAPSHOT s_undoStack[UNDO_MAX_STEPS];
static int s_undoPos = -1;
static int s_undoCount = 0;

static void UndoPushSnapshot( HBForm * pForm )
{
   if( !pForm ) return;
   s_undoPos++;
   if( s_undoPos >= UNDO_MAX_STEPS ) s_undoPos = 0;
   if( s_undoCount < UNDO_MAX_STEPS ) s_undoCount++;

   UNDO_SNAPSHOT * snap = &s_undoStack[s_undoPos];
   snap->nCount = pForm->FChildCount;
   for( int i = 0; i < pForm->FChildCount && i < UNDO_MAX_CTRLS; i++ )
   {
      HBControl * c = pForm->FChildren[i];
      snap->ctrls[i].nType   = c->FControlType;
      snap->ctrls[i].nLeft   = c->FLeft;
      snap->ctrls[i].nTop    = c->FTop;
      snap->ctrls[i].nWidth  = c->FWidth;
      snap->ctrls[i].nHeight = c->FHeight;
      strncpy( snap->ctrls[i].szName, c->FName, 31 );
      strncpy( snap->ctrls[i].szText, c->FText, 127 );
   }
}

static void UndoRestoreSnapshot( HBForm * pForm, UNDO_SNAPSHOT * snap )
{
   if( !pForm || !snap ) return;
   int n = snap->nCount < pForm->FChildCount ? snap->nCount : pForm->FChildCount;
   for( int i = 0; i < n; i++ )
   {
      HBControl * c = pForm->FChildren[i];
      c->FLeft   = snap->ctrls[i].nLeft;
      c->FTop    = snap->ctrls[i].nTop;
      c->FWidth  = snap->ctrls[i].nWidth;
      c->FHeight = snap->ctrls[i].nHeight;
      if( c->FView )
         [(NSView *)c->FView setFrame:NSMakeRect( c->FLeft, c->FTop + pForm->FClientTop,
                                                   c->FWidth, c->FHeight )];
   }
   [pForm clearSelection];
   if( pForm->FOverlayView )
      [(NSView *)pForm->FOverlayView setNeedsDisplay:YES];
}

/* UI_FormUndoPush( hForm ) — save state before operation */
HB_FUNC( UI_FORMUNDOPUSH )
{
   HBForm * pForm = (__bridge HBForm *)(void *)(HB_PTRUINT) hb_parnint(1);
   UndoPushSnapshot( pForm );
}

/* UI_FormUndo( hForm ) — restore previous state */
HB_FUNC( UI_FORMUNDO )
{
   HBForm * pForm = (__bridge HBForm *)(void *)(HB_PTRUINT) hb_parnint(1);
   if( !pForm || s_undoCount <= 0 ) return;
   s_undoPos--;
   if( s_undoPos < 0 ) s_undoPos = UNDO_MAX_STEPS - 1;
   s_undoCount--;
   UndoRestoreSnapshot( pForm, &s_undoStack[s_undoPos] );
}


/* ======================================================================
 * Tab Order Editor — dialog showing controls in tab order
 * Click to reorder, drag to rearrange (simplified: shows order + swap)
 * ====================================================================== */

/* UI_FormTabOrderDialog( hForm ) — show tab order dialog */
HB_FUNC( UI_FORMTABORDERDIALOG )
{
   HBForm * pForm = (__bridge HBForm *)(void *)(HB_PTRUINT) hb_parnint(1);
   if( !pForm || pForm->FChildCount == 0 ) return;

   /* Build array of control names in current order */
   NSMutableArray * names = [NSMutableArray array];
   for( int i = 0; i < pForm->FChildCount; i++ )
   {
      HBControl * c = pForm->FChildren[i];
      NSString * entry = [NSString stringWithFormat:@"%d.  %s  (%s)",
         i + 1, c->FName, c->FClassName];
      [names addObject:entry];
   }

   /* Create dialog with list */
   NSAlert * alert = [[NSAlert alloc] init];
   [alert setMessageText:@"Tab Order"];
   [alert setInformativeText:@"Select a control and use Move Up/Down to change order:"];
   [alert addButtonWithTitle:@"OK"];
   [alert addButtonWithTitle:@"Move Up"];
   [alert addButtonWithTitle:@"Move Down"];
   [alert addButtonWithTitle:@"Cancel"];

   /* List view as accessory */
   NSScrollView * sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 350, 250)];
   [sv setHasVerticalScroller:YES];
   NSTableView * tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 350, 250)];
   NSTableColumn * col = [[NSTableColumn alloc] initWithIdentifier:@"name"];
   [[col headerCell] setStringValue:@"Control (Tab Order)"];
   [col setWidth:330];
   [tv addTableColumn:col];
   [tv setHeaderView:nil];
   [tv setRowHeight:22];

   /* Simple data source using names array */
   /* For simplicity, just show the list and allow Move Up/Down via repeated alerts */
   [sv setDocumentView:tv];
   [alert setAccessoryView:sv];

   /* For now, just display the order — a full drag-reorder would need more UI */
   NSModalResponse resp = [alert runModal];
   (void)resp;
   /* TODO: implement Move Up/Down with repeated dialog */
}

/* --- Git integration --- */
static char * GitExec( const char * szArgs, const char * szWorkDir )
{
    char cmd[1024];
    snprintf( cmd, sizeof(cmd), "cd \"%s\" && git %s 2>&1", szWorkDir, szArgs );

    FILE * fp = popen( cmd, "r" );
    if( !fp ) return NULL;

    size_t bufSize = 4096, total = 0;
    char * buf = (char *) malloc( bufSize );
    buf[0] = 0;

    while( !feof(fp) )
    {
        size_t n = fread( buf + total, 1, bufSize - total - 1, fp );
        total += n;
        if( total >= bufSize - 256 ) {
            bufSize *= 2;
            buf = (char *) realloc( buf, bufSize );
        }
    }
    buf[total] = 0;
    pclose( fp );
    return buf;
}

/* GIT_Exec( cArgs, [cWorkDir] ) -> cOutput */
HB_FUNC( GIT_EXEC )
{
   const char * szArgs = hb_parc(1);
   const char * szDir  = HB_ISCHAR(2) ? hb_parc(2) : ".";
   if( !szArgs ) { hb_retc(""); return; }
   char * pOut = GitExec( szArgs, szDir );
   if( pOut ) { hb_retc( pOut ); free( pOut ); }
   else hb_retc( "" );
}

/* GIT_IsRepo( [cWorkDir] ) -> lIsGitRepo */
HB_FUNC( GIT_ISREPO )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "rev-parse --is-inside-work-tree", szDir );
   if( pOut ) { hb_retl( strstr(pOut, "true") != NULL ); free( pOut ); }
   else hb_retl( HB_FALSE );
}

/* GIT_CurrentBranch( [cWorkDir] ) -> cBranchName */
HB_FUNC( GIT_CURRENTBRANCH )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "rev-parse --abbrev-ref HEAD", szDir );
   if( pOut ) {
      int len = (int)strlen(pOut);
      while( len > 0 && (pOut[len-1] == '\n' || pOut[len-1] == '\r') ) pOut[--len] = 0;
      hb_retc( pOut ); free( pOut );
   } else hb_retc( "" );
}

/* GIT_Status( [cWorkDir] ) -> { { cStatus, cFile }, ... } */
HB_FUNC( GIT_STATUS )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "status --porcelain", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   if( pOut ) {
      char * p = pOut;
      while( *p ) {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);
         if( eol - p >= 4 ) {
            PHB_ITEM pEntry = hb_itemArrayNew( 2 );
            char status[4] = { p[0], p[1], 0 };
            char file[512];
            int fLen = (int)(eol - p - 3);
            if( fLen > 511 ) fLen = 511;
            strncpy( file, p + 3, fLen ); file[fLen] = 0;
            hb_arraySetC( pEntry, 1, status );
            hb_arraySetC( pEntry, 2, file );
            hb_arrayAdd( pArray, pEntry );
            hb_itemRelease( pEntry );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_Log( [nCount], [cWorkDir] ) -> { { cHash, cAuthor, cDate, cMessage }, ... } */
HB_FUNC( GIT_LOG )
{
   int nCount = HB_ISNUM(1) ? hb_parni(1) : 20;
   const char * szDir = HB_ISCHAR(2) ? hb_parc(2) : ".";
   char args[256];
   snprintf( args, sizeof(args), "log --oneline --format=%%H|%%an|%%ar|%%s -n %d", nCount );
   char * pOut = GitExec( args, szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   if( pOut ) {
      char * p = pOut;
      while( *p ) {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);
         if( eol > p ) {
            char line[1024];
            int len = (int)(eol - p);
            if( len > 1023 ) len = 1023;
            strncpy( line, p, len ); line[len] = 0;
            char * f1 = line;
            char * f2 = strchr(f1,'|'); if(f2) *f2++ = 0; else f2 = (char*)"";
            char * f3 = strchr(f2,'|'); if(f3) *f3++ = 0; else f3 = (char*)"";
            char * f4 = strchr(f3,'|'); if(f4) *f4++ = 0; else f4 = (char*)"";
            PHB_ITEM pEntry = hb_itemArrayNew( 4 );
            hb_arraySetC( pEntry, 1, f1 );
            hb_arraySetC( pEntry, 2, f2 );
            hb_arraySetC( pEntry, 3, f3 );
            hb_arraySetC( pEntry, 4, f4 );
            hb_arrayAdd( pArray, pEntry );
            hb_itemRelease( pEntry );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_Diff( [cFile], [cWorkDir] ) -> cDiffText */
HB_FUNC( GIT_DIFF )
{
   const char * szFile = HB_ISCHAR(1) ? hb_parc(1) : "";
   const char * szDir  = HB_ISCHAR(2) ? hb_parc(2) : ".";
   char args[512];
   if( szFile[0] ) snprintf( args, sizeof(args), "diff -- \"%s\"", szFile );
   else snprintf( args, sizeof(args), "diff" );
   char * pOut = GitExec( args, szDir );
   if( pOut ) { hb_retc( pOut ); free( pOut ); }
   else hb_retc( "" );
}

/* GIT_BranchList( [cWorkDir] ) -> { { cName, lCurrent }, ... } */
HB_FUNC( GIT_BRANCHLIST )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "branch --no-color", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   if( pOut ) {
      char * p = pOut;
      while( *p ) {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);
         if( eol - p >= 2 ) {
            PHB_ITEM pEntry = hb_itemArrayNew( 2 );
            int isCurrent = ( p[0] == '*' ) ? 1 : 0;
            char name[256]; char * start = p + 2;
            int nLen = (int)(eol - start);
            if( nLen > 255 ) nLen = 255;
            strncpy( name, start, nLen ); name[nLen] = 0;
            while( nLen > 0 && name[nLen-1] == ' ' ) name[--nLen] = 0;
            hb_arraySetC( pEntry, 1, name );
            hb_arraySetL( pEntry, 2, isCurrent ? HB_TRUE : HB_FALSE );
            hb_arrayAdd( pArray, pEntry );
            hb_itemRelease( pEntry );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_RemoteList( [cWorkDir] ) -> { { cName, cUrl }, ... } */
HB_FUNC( GIT_REMOTELIST )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "remote -v", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   if( pOut ) {
      char * p = pOut;
      while( *p ) {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);
         if( eol > p && strstr( p, "(fetch)" ) ) {
            char line[512];
            int len = (int)(eol - p);
            if( len > 511 ) len = 511;
            strncpy( line, p, len ); line[len] = 0;
            char * tab = strchr( line, '\t' );
            if( tab ) {
               *tab = 0; char * url = tab + 1;
               char * sp = strstr( url, " (fetch)" );
               if( sp ) *sp = 0;
               PHB_ITEM pEntry = hb_itemArrayNew( 2 );
               hb_arraySetC( pEntry, 1, line );
               hb_arraySetC( pEntry, 2, url );
               hb_arrayAdd( pArray, pEntry );
               hb_itemRelease( pEntry );
            }
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_StashList( [cWorkDir] ) -> { cStashEntry, ... } */
HB_FUNC( GIT_STASHLIST )
{
   const char * szDir = HB_ISCHAR(1) ? hb_parc(1) : ".";
   char * pOut = GitExec( "stash list", szDir );
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   if( pOut ) {
      char * p = pOut;
      while( *p ) {
         char * eol = strchr( p, '\n' );
         if( !eol ) eol = p + strlen(p);
         if( eol > p ) {
            char line[512];
            int len = (int)(eol - p);
            if( len > 511 ) len = 511;
            strncpy( line, p, len ); line[len] = 0;
            PHB_ITEM pStr = hb_itemPutC( NULL, line );
            hb_arrayAdd( pArray, pStr );
            hb_itemRelease( pStr );
         }
         p = ( *eol ) ? eol + 1 : eol;
      }
      free( pOut );
   }
   hb_itemReturnRelease( pArray );
}

/* GIT_Blame( cFile, [cWorkDir] ) -> cBlameOutput */
HB_FUNC( GIT_BLAME )
{
   const char * szFile = hb_parc(1);
   const char * szDir  = HB_ISCHAR(2) ? hb_parc(2) : ".";
   if( !szFile ) { hb_retc(""); return; }
   char args[512];
   snprintf( args, sizeof(args), "blame --date=short \"%s\"", szFile );
   char * pOut = GitExec( args, szDir );
   if( pOut ) { hb_retc( pOut ); free( pOut ); }
   else hb_retc( "" );
}

/* ======================================================================
 * Threading - POSIX thread wrappers
 * ====================================================================== */

/* UI_ThreadStart( bBlock ) --> nThreadId */
HB_FUNC( UI_THREADSTART )
{
   /* Placeholder - in production uses hb_threadStart() */
   hb_retnint( 1 );
}

/* UI_ThreadWait( nThreadId ) */
HB_FUNC( UI_THREADWAIT )
{
   /* Placeholder */
}

/* UI_ThreadSleep( nMilliseconds ) */
HB_FUNC( UI_THREADSLEEP )
{
   int nMs = hb_parni(1);
   if( nMs > 0 ) usleep( nMs * 1000 );
}

/* UI_MutexCreate() --> nMutex */
HB_FUNC( UI_MUTEXCREATE )
{
   pthread_mutex_t * pm = (pthread_mutex_t *) malloc( sizeof(pthread_mutex_t) );
   pthread_mutex_init( pm, NULL );
   hb_retnint( (HB_PTRUINT) pm );
}

/* UI_MutexLock( nMutex ) */
HB_FUNC( UI_MUTEXLOCK )
{
   pthread_mutex_t * pm = (pthread_mutex_t *)(HB_PTRUINT) hb_parnint(1);
   if( pm ) pthread_mutex_lock( pm );
}

/* UI_MutexUnlock( nMutex ) */
HB_FUNC( UI_MUTEXUNLOCK )
{
   pthread_mutex_t * pm = (pthread_mutex_t *)(HB_PTRUINT) hb_parnint(1);
   if( pm ) pthread_mutex_unlock( pm );
}

/* UI_MutexDestroy( nMutex ) */
HB_FUNC( UI_MUTEXDESTROY )
{
   pthread_mutex_t * pm = (pthread_mutex_t *)(HB_PTRUINT) hb_parnint(1);
   if( pm ) { pthread_mutex_destroy( pm ); free( pm ); }
}

/* UI_CriticalSectionCreate() --> nCS (recursive mutex) */
HB_FUNC( UI_CRITICALSECTIONCREATE )
{
   pthread_mutex_t * pm = (pthread_mutex_t *) malloc( sizeof(pthread_mutex_t) );
   pthread_mutexattr_t attr;
   pthread_mutexattr_init( &attr );
   pthread_mutexattr_settype( &attr, PTHREAD_MUTEX_RECURSIVE );
   pthread_mutex_init( pm, &attr );
   pthread_mutexattr_destroy( &attr );
   hb_retnint( (HB_PTRUINT) pm );
}

/* UI_CriticalSectionEnter( nCS ) */
HB_FUNC( UI_CRITICALSECTIONENTER )
{
   pthread_mutex_t * pm = (pthread_mutex_t *)(HB_PTRUINT) hb_parnint(1);
   if( pm ) pthread_mutex_lock( pm );
}

/* UI_CriticalSectionLeave( nCS ) */
HB_FUNC( UI_CRITICALSECTIONLEAVE )
{
   pthread_mutex_t * pm = (pthread_mutex_t *)(HB_PTRUINT) hb_parnint(1);
   if( pm ) pthread_mutex_unlock( pm );
}

/* UI_CriticalSectionDestroy( nCS ) */
HB_FUNC( UI_CRITICALSECTIONDESTROY )
{
   pthread_mutex_t * pm = (pthread_mutex_t *)(HB_PTRUINT) hb_parnint(1);
   if( pm ) { pthread_mutex_destroy( pm ); free( pm ); }
}

/* UI_AtomicIncrement( @nValue ) --> nNewValue */
HB_FUNC( UI_ATOMICINCREMENT )
{
   long val = (long) hb_parnl(1);
   hb_retnl( __sync_add_and_fetch( &val, 1 ) );
}

/* UI_AtomicDecrement( @nValue ) --> nNewValue */
HB_FUNC( UI_ATOMICDECREMENT )
{
   long val = (long) hb_parnl(1);
   hb_retnl( __sync_sub_and_fetch( &val, 1 ) );
}

/* ======================================================================
 * Networking - TCP / HTTP / WebServer
 * ====================================================================== */

/* UI_TcpConnect( cHost, nPort ) --> nSocket */
HB_FUNC( UI_TCPCONNECT )
{
   /* Placeholder - returns simulated socket handle */
   hb_retnint( 1001 );
}

/* UI_TcpSend( nSocket, cData ) --> nBytesSent */
HB_FUNC( UI_TCPSEND )
{
   hb_retni( HB_ISCHAR(2) ? (int) hb_parclen(2) : 0 );
}

/* UI_TcpRecv( nSocket, nMaxBytes ) --> cData */
HB_FUNC( UI_TCPRECV )
{
   hb_retc( "(no data - placeholder)" );
}

/* UI_TcpClose( nSocket ) */
HB_FUNC( UI_TCPCLOSE )
{
   /* Placeholder */
}

/* UI_HttpGet( cURL ) --> cResponse */
HB_FUNC( UI_HTTPGET )
{
   const char * url = hb_parc(1);
   char buf[256];
   if( url ) snprintf( buf, sizeof(buf), "HTTP GET %s -> 200 OK (placeholder)", url );
   else buf[0] = 0;
   hb_retc( buf );
}

/* UI_HttpPost( cURL, cBody ) --> cResponse */
HB_FUNC( UI_HTTPPOST )
{
   const char * url = hb_parc(1);
   const char * body = hb_parc(2);
   char buf[256];
   if( url ) snprintf( buf, sizeof(buf), "HTTP POST %s [%d bytes] -> 200 OK (placeholder)",
                       url, body ? (int)strlen(body) : 0 );
   else buf[0] = 0;
   hb_retc( buf );
}

/* UI_WebServerStart( nPort ) --> lSuccess */
HB_FUNC( UI_WEBSERVERSTART )
{
   /* Placeholder */
   hb_retl( HB_TRUE );
}

/* UI_WebServerStop() */
HB_FUNC( UI_WEBSERVERSTOP )
{
   /* Placeholder */
}

/* ======================================================================
 * Menu and Toolbar utilities
 * ====================================================================== */

/* UI_MenuSetBitmapByPos( hForm, nPopupIdx, nItemIdx, cBmpPath ) */
/* UI_MenuSetBitmapByPos( hPopup, nPos, cPngPath ) */
HB_FUNC( UI_MENUSETBITMAPBYPOS )
{
   NSMenu * popup = (__bridge NSMenu *)(void *)(HB_PTRUINT) hb_parnint(1);
   int nPos = hb_parni(2);
   const char * szPath = hb_parc(3);
   if( !popup || !szPath ) return;
   if( nPos < 0 || nPos >= (int)[popup numberOfItems] ) return;

   NSMenuItem * item = [popup itemAtIndex:nPos];
   if( !item || [item isSeparatorItem] ) return;

   NSString * path = [NSString stringWithUTF8String:szPath];
   NSImage * img = [[NSImage alloc] initWithContentsOfFile:path];
   if( img ) {
      [img setSize:NSMakeSize(16, 16)];
      [item setImage:img];
   }
}

/* UI_StackToolBars( hForm ) - Arrange toolbar rows vertically */
HB_FUNC( UI_STACKTOOLBARS )
{
   /* On macOS, toolbars are already stacked by the form layout in HBForm */
   /* This is a no-op since Cocoa handles toolbar stacking natively */
   (void) hb_parnint(1);
}

/* --- DPI stub (macOS handles Retina natively) --- */
HB_FUNC( SETDPIAWARE ) { /* no-op on macOS */ }
