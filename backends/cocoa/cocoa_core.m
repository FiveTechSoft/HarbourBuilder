/*
 * cocoa_core.m - Cocoa/AppKit implementation of hbcpp framework for macOS
 * Replaces the Win32 C++ core (tcontrol.cpp, tform.cpp, tcontrols.cpp, hbbridge.cpp)
 *
 * Provides the same HB_FUNC bridge interface so Harbour code (classes.prg) works unchanged.
 */

#import <Cocoa/Cocoa.h>
#include <hbapi.h>
#include <hbapiitm.h>
#include <hbapicls.h>
#include <hbstack.h>
#include <hbvm.h>
#include <string.h>
#include <stdio.h>

/* Control types - must match original */
#define CT_FORM       0
#define CT_LABEL      1
#define CT_EDIT       2
#define CT_BUTTON     3
#define CT_CHECKBOX   4
#define CT_COMBOBOX   5
#define CT_GROUPBOX   6
#define CT_TOOLBAR    9

#define MAX_CHILDREN  256
#define MAX_TOOLBTNS  64
#define TOOLBAR_BTN_ID_BASE 100
#define MENU_ID_BASE        1000
#define MAX_MENUITEMS       128

/* LONG_PTR equivalent for macOS */
typedef long LONG_PTR_MAC;
#define LONG_PTR LONG_PTR_MAC

/* Forward declaration */
@class HBToolBar;
@class HBSplitterView;

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
static void PalShowTab( PALDATA * pd, int nTab );

/* ======================================================================
 * NSApp initialization
 * ====================================================================== */

static BOOL s_appInitialized = NO;

static void EnsureNSApp( void )
{
   if( !s_appInitialized )
   {
      [NSApplication sharedApplication];
      [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

      NSMenu * menuBar = [[NSMenu alloc] init];
      NSMenuItem * appMenuItem = [[NSMenuItem alloc] init];
      NSMenu * appMenu = [[NSMenu alloc] initWithTitle:@"hbcpp"];
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
   int  FLeft, FTop, FWidth, FHeight;
   BOOL FVisible, FEnabled, FTabStop;
   int  FControlType;
   NSView * FView;
   NSFont * FFont;
   NSColor * FBgColor;
   unsigned int FClrPane;

   PHB_ITEM FOnClick, FOnChange, FOnInit, FOnClose;

   HBControl * FCtrlParent;
   HBControl * FChildren[MAX_CHILDREN];
   int FChildCount;
}
- (void)addChild:(HBControl *)child;
- (void)setText:(const char *)text;
- (void)createViewInParent:(NSView *)parentView;
- (void)updateViewFrame;
- (void)setEvent:(const char *)event block:(PHB_ITEM)block;
- (void)fireEvent:(PHB_ITEM)block;
- (void)releaseEvents;
- (void)applyFont;
@end

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
   BOOL       FDesignMode;
   HBControl * FSelected[MAX_CHILDREN];
   int        FSelCount;
   BOOL       FDragging, FResizing;
   int        FResizeHandle;
   int        FDragStartX, FDragStartY;
   PHB_ITEM   FOnSelChange;
   NSView *   FOverlayView;
   HBFlippedView * FContentView;
   /* Toolbar */
   HBToolBar * FToolBar;
   int         FClientTop;
   /* Menu */
   PHB_ITEM    FMenuActions[MAX_MENUITEMS];
   int         FMenuItemCount;
}
- (void)run;
- (void)showOnly;  /* Create + show without entering run loop */
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

/* ======================================================================
 * ALL @implementation sections
 * ====================================================================== */

/* --- HBControl implementation --- */

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
      FClrPane = 0xFFFFFFFF;
      FOnClick = NULL; FOnChange = NULL; FOnInit = NULL; FOnClose = NULL;
      FCtrlParent = nil; FChildCount = 0;
      memset( FChildren, 0, sizeof(FChildren) );
   }
   return self;
}

- (void)dealloc { [self releaseEvents]; }

- (void)addChild:(HBControl *)child
{
   if( FChildCount < MAX_CHILDREN ) {
      FChildren[FChildCount++] = child;
      child->FCtrlParent = self;
   }
}

- (void)setText:(const char *)text
{
   strncpy( FText, text, sizeof(FText) - 1 );
   FText[sizeof(FText) - 1] = 0;
}

- (void)createViewInParent:(NSView *)parentView { /* override */ }

- (void)updateViewFrame
{
   if( FView ) [FView setFrame:NSMakeRect( FLeft, FTop, FWidth, FHeight )];
}

- (void)applyFont
{
   if( FFont && FView && [FView respondsToSelector:@selector(setFont:)] )
      [(id)FView setFont:FFont];
}

- (void)setEvent:(const char *)event block:(PHB_ITEM)block
{
   PHB_ITEM * ppTarget = NULL;
   if( strcasecmp( event, "OnClick" ) == 0 )       ppTarget = &FOnClick;
   else if( strcasecmp( event, "OnChange" ) == 0 )  ppTarget = &FOnChange;
   else if( strcasecmp( event, "OnInit" ) == 0 )    ppTarget = &FOnInit;
   else if( strcasecmp( event, "OnClose" ) == 0 )   ppTarget = &FOnClose;
   if( ppTarget ) {
      if( *ppTarget ) hb_itemRelease( *ppTarget );
      *ppTarget = hb_itemNew( block );
   }
}

- (void)fireEvent:(PHB_ITEM)block
{
   if( block && HB_IS_BLOCK( block ) ) {
      hb_vmPushEvalSym();
      hb_vmPush( block );
      hb_vmPushNumInt( (HB_PTRUINT) self );
      hb_vmSend( 1 );
   }
}

- (void)releaseEvents
{
   if( FOnClick )  { hb_itemRelease( FOnClick );  FOnClick = NULL; }
   if( FOnChange ) { hb_itemRelease( FOnChange ); FOnChange = NULL; }
   if( FOnInit )   { hb_itemRelease( FOnInit );   FOnInit = NULL; }
   if( FOnClose )  { hb_itemRelease( FOnClose );  FOnClose = NULL; }
}

@end

/* --- HBLabel implementation --- */

@implementation HBLabel

- (instancetype)init
{
   self = [super init];
   if( self ) {
      strcpy( FClassName, "TLabel" );
      FControlType = CT_LABEL; FWidth = 80; FHeight = 15; FTabStop = NO;
      strcpy( FText, "Label" );
   }
   return self;
}

- (void)createViewInParent:(NSView *)parentView
{
   NSTextField * tf = [[NSTextField alloc] initWithFrame:
      NSMakeRect( FLeft, FTop, FWidth, FHeight )];
   [tf setStringValue:[NSString stringWithUTF8String:FText]];
   [tf setBezeled:NO]; [tf setDrawsBackground:NO];
   [tf setEditable:NO]; [tf setSelectable:NO];
   [tf setTextColor:[NSColor blackColor]];
   if( FFont ) [tf setFont:FFont];
   [parentView addSubview:tf];
   FView = tf;
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
   [btn setBezelStyle:NSBezelStyleRounded];
   [btn setButtonType:NSButtonTypeMomentaryPushIn];
   if( FDefault ) [btn setKeyEquivalent:@"\r"];
   if( FCancel )  [btn setKeyEquivalent:@"\033"];
   if( FFont ) [btn setFont:FFont];
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

   /* Light gray background */
   toolbar.wantsLayer = YES;
   toolbar.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.92 alpha:1.0] CGColor];

   int btnW = 32, btnH = 32;
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

   /* Size toolbar to fit its content */
   int tbHeight = btnH + yOff * 2;
   [toolbar setFrame:NSMakeRect( 0, 0, xPos + 4, tbHeight )];
   FWidth = xPos + 4;

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
      [toolbar setFrame:NSMakeRect( 0, 0, FWidth, tbHeight )];
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

   if( palData->parentForm && palData->parentForm->FToolBar && palData->parentForm->FToolBar->FView )
   {
      NSRect tbFrame = [palData->parentForm->FToolBar->FView frame];
      tbFrame.size.width = newPos;
      [palData->parentForm->FToolBar->FView setFrame:tbFrame];
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
@end

@implementation HBPaletteTarget

- (void)tabChanged:(id)sender
{
   if( palData ) {
      int sel = (int)[palData->segmented selectedSegment];
      PalShowTab( palData, sel );
   }
}

@end

static HBPaletteTarget * s_palTarget = nil;

/* --- HBOverlayView implementation --- */

@implementation HBOverlayView

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (NSView *)hitTest:(NSPoint)point
{
   if( form && form->FDesignMode ) return self;
   return nil;
}

- (void)drawRect:(NSRect)dirtyRect
{
   if( !form ) return;

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

   int nHandle = [form hitTestHandle:pt];
   if( nHandle >= 0 ) {
      form->FResizing = YES; form->FResizeHandle = nHandle;
      form->FDragStartX = (int)pt.x; form->FDragStartY = (int)pt.y;
      return;
   }

   HBControl * hit = [form hitTestControl:pt];
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
      dx = (dx/4)*4; dy = (dy/4)*4;
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
      dx = (dx/4)*4; dy = (dy/4)*4;
      if( dx == 0 && dy == 0 ) return;
      for( int i = 0; i < form->FSelCount; i++ ) {
         form->FSelected[i]->FLeft += dx; form->FSelected[i]->FTop += dy;
         [form->FSelected[i] updateViewFrame];
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
      CGFloat rx1 = fmin(rubberOrigin.x, rubberCurrent.x);
      CGFloat ry1 = fmin(rubberOrigin.y, rubberCurrent.y);
      CGFloat rx2 = fmax(rubberOrigin.x, rubberCurrent.x);
      CGFloat ry2 = fmax(rubberOrigin.y, rubberCurrent.y);
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
      int dx = 0, dy = 0, step = ([event modifierFlags] & NSEventModifierFlagShift) ? 1 : 4;
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
      FToolBar = nil; FClientTop = 0; FMenuItemCount = 0;
      memset( FSelected, 0, sizeof(FSelected) );
      memset( FMenuActions, 0, sizeof(FMenuActions) );
      FWidth = 470; FHeight = 400;
      strcpy( FText, "New Form" );
      FClrPane = 0x00F0F0F0;
      FWindow = nil;
   }
   return self;
}

- (void)dealloc
{
   if( FOnSelChange ) { hb_itemRelease( FOnSelChange ); FOnSelChange = NULL; }
   for( int i = 0; i < FMenuItemCount; i++ )
      if( FMenuActions[i] ) { hb_itemRelease( FMenuActions[i] ); FMenuActions[i] = NULL; }
}

- (void)run
{
   EnsureNSApp();

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
      [self createAllChildren];
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
   NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
   if( FAppBar ) {
      /* AppBar: no title bar, no shadow - thin strip flush with content below */
      style = NSWindowStyleMaskBorderless;
   }
   else if( FSizable )
      style |= NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;
   FWindow = [[NSWindow alloc] initWithContentRect:frame
      styleMask:style
      backing:NSBackingStoreBuffered defer:NO];
   [FWindow setTitle:[NSString stringWithUTF8String:FText]];
   [FWindow setDelegate:self];
   [FWindow setReleasedWhenClosed:NO];
   if( FAppBar ) [FWindow setHasShadow:NO];  /* no shadow gap for appbar */

   FContentView = [[HBFlippedView alloc] initWithFrame:[[FWindow contentView] bounds]];
   [FContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   /* Force light appearance to avoid dark mode white-on-dark text */
   if( [NSAppearance respondsToSelector:@selector(appearanceNamed:)] )
      [FWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
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

   if( FCenter ) [self center];
   else if( !FCenter ) {
      NSRect screenFrame = [[NSScreen mainScreen] frame];
      NSPoint origin;
      origin.x = FLeft;
      origin.y = screenFrame.size.height - FTop - FHeight;
      [FWindow setFrameOrigin:origin];
   }
   [FWindow makeKeyAndOrderFront:nil];
   [NSApp activateIgnoringOtherApps:YES];

   FRunning = YES;
   if( enterLoop ) {
      [NSApp run];
      FRunning = NO;
   }
}

- (void)showOnly
{
   [self createWindowWithRunLoop:NO];
}

- (void)close
{
   FRunning = NO;
   [FWindow close];
}

- (void)center { if( FWindow ) [FWindow center]; }

- (void)createAllChildren
{
   /* Toolbar first */
   if( FToolBar ) {
      FToolBar->FWidth = FWidth;
      [FToolBar createViewInParent:FContentView];
      FClientTop = [FToolBar barHeight];
   }

   /* Component Palette: create tabs + splitter to the right of toolbar */
   if( s_palData && s_palData->parentForm == self && s_palData->nTabCount > 0 )
   {
      PALDATA * pd = s_palData;
      NSRect contentBounds = [FContentView bounds];
      int tbWidth = 0;
      if( FToolBar && FToolBar->FView ) {
         NSRect tbFrame = [FToolBar->FView frame];
         tbWidth = (int) tbFrame.size.width;
      }
      pd->nSplitPos = tbWidth;

      /* Container view for palette area (full width, full content height) */
      CGFloat fullH = contentBounds.size.height;
      pd->containerView = [[HBFlippedView alloc] initWithFrame:
         NSMakeRect( 0, 0, contentBounds.size.width, fullH )];
      [pd->containerView setAutoresizingMask:NSViewWidthSizable];

      /* Splitter (8px wide for easy grabbing) */
      int splW = 8;
      HBSplitterView * sp = [[HBSplitterView alloc] initWithFrame:
         NSMakeRect( tbWidth, 0, splW, fullH )];
      sp->palData = pd;
      pd->splitterView = sp;
      [pd->containerView addSubview:sp];

      /* Layout: buttons on top, tab selector at bottom of window */
      CGFloat rightX = tbWidth + splW;
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
         FChildren[i]->FFont = FFormFont;
         FChildren[i]->FTop += FClientTop;
         [FChildren[i] createViewInParent:FContentView];
      }
   for( int i = 0; i < FChildCount; i++ )
      if( FChildren[i]->FControlType != CT_GROUPBOX &&
          FChildren[i]->FControlType != CT_TOOLBAR ) {
         FChildren[i]->FFont = FFormFont;
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
   FRunning = NO;
   [NSApp stop:nil];
   [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
      location:NSZeroPoint modifierFlags:0 timestamp:0
      windowNumber:0 context:nil subtype:0 data1:0 data2:0] atStart:YES];
}

- (BOOL)windowShouldClose:(NSWindow *)sender { return YES; }

@end

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
   return (__bridge HBControl *)(void *)(HB_PTRUINT) hb_parnint( nParam );
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
HB_FUNC( UI_FORMRUN )       { HBForm * p = GetForm(1); if( p ) [p run]; }
HB_FUNC( UI_FORMSHOW )      { HBForm * p = GetForm(1); if( p ) [p showOnly]; }
HB_FUNC( UI_FORMCLOSE )     { HBForm * p = GetForm(1); if( p ) [p close]; }
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

/* --- Property access --- */

HB_FUNC( UI_SETPROP )
{
   HBControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);
   if( !p || !szProp ) return;

   if( strcasecmp( szProp, "cText" ) == 0 && HB_ISCHAR(3) ) {
      [p setText:hb_parc(3)];
      if( p->FView && [p->FView respondsToSelector:@selector(setStringValue:)] )
         [(id)p->FView setStringValue:[NSString stringWithUTF8String:p->FText]];
      else if( p->FView && [p->FView respondsToSelector:@selector(setTitle:)] )
         [(id)p->FView setTitle:[NSString stringWithUTF8String:p->FText]];
   }
   else if( strcasecmp(szProp,"nLeft")==0 )   { p->FLeft = hb_parni(3); [p updateViewFrame]; }
   else if( strcasecmp(szProp,"nTop")==0 )    { p->FTop = hb_parni(3); [p updateViewFrame]; }
   else if( strcasecmp(szProp,"nWidth")==0 )  { p->FWidth = hb_parni(3); [p updateViewFrame]; }
   else if( strcasecmp(szProp,"nHeight")==0 ) { p->FHeight = hb_parni(3); [p updateViewFrame]; }
   else if( strcasecmp(szProp,"lVisible")==0 ) {
      p->FVisible = hb_parl(3); if( p->FView ) [p->FView setHidden:!p->FVisible]; }
   else if( strcasecmp(szProp,"lEnabled")==0 ) {
      p->FEnabled = hb_parl(3);
      if( p->FView && [p->FView respondsToSelector:@selector(setEnabled:)] )
         [(id)p->FView setEnabled:p->FEnabled]; }
   else if( strcasecmp(szProp,"lDefault")==0 && p->FControlType == CT_BUTTON )
      ((HBButton *)p)->FDefault = hb_parl(3);
   else if( strcasecmp(szProp,"lCancel")==0 && p->FControlType == CT_BUTTON )
      ((HBButton *)p)->FCancel = hb_parl(3);
   else if( strcasecmp(szProp,"lChecked")==0 && p->FControlType == CT_CHECKBOX )
      [(HBCheckBox *)p setChecked:hb_parl(3)];
   else if( strcasecmp(szProp,"cName")==0 && HB_ISCHAR(3) )
      strncpy( p->FName, hb_parc(3), sizeof(p->FName)-1 );
   else if( strcasecmp(szProp,"lSizable")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FSizable = hb_parl(3);
   else if( strcasecmp(szProp,"lAppBar")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FAppBar = hb_parl(3);
   else if( strcasecmp(szProp,"nClrPane")==0 ) {
      p->FClrPane = (unsigned int)hb_parnint(3);
      CGFloat r = (p->FClrPane & 0xFF)/255.0;
      CGFloat g = ((p->FClrPane>>8)&0xFF)/255.0;
      CGFloat b = ((p->FClrPane>>16)&0xFF)/255.0;
      p->FBgColor = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
      if( p->FControlType == CT_FORM && ((HBForm *)p)->FWindow )
         [((HBForm *)p)->FWindow setBackgroundColor:p->FBgColor];
   }
   else if( strcasecmp(szProp,"oFont")==0 && HB_ISCHAR(3) ) {
      char szFace[64]={0}; int nSize=12;
      const char * val = hb_parc(3);
      const char * comma = strchr(val,',');
      if( comma ) { int len=(int)(comma-val); if(len>63)len=63; memcpy(szFace,val,len); nSize=atoi(comma+1); }
      else strncpy(szFace,val,63);
      if( nSize <= 0 ) nSize = 12;
      NSFont * font = [NSFont fontWithName:[NSString stringWithUTF8String:szFace] size:(CGFloat)nSize];
      if( !font ) font = [NSFont systemFontOfSize:(CGFloat)nSize];
      if( p->FControlType == CT_FORM ) {
         HBForm * pF = (HBForm *)p; pF->FFormFont = font; pF->FFont = font;
         for( int i = 0; i < pF->FChildCount; i++ ) { pF->FChildren[i]->FFont = font; [pF->FChildren[i] applyFont]; }
      } else { p->FFont = font; [p applyFont]; }
   }
}

HB_FUNC( UI_GETPROP )
{
   HBControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);
   if( !p || !szProp ) { hb_ret(); return; }

   if( strcasecmp(szProp,"cText")==0 )          hb_retc( p->FText );
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
   else if( strcasecmp(szProp,"lSizable")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FSizable );
   else if( strcasecmp(szProp,"lAppBar")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FAppBar );
   else if( strcasecmp(szProp,"nItemIndex")==0 && p->FControlType==CT_COMBOBOX )
      hb_retni( ((HBComboBox *)p)->FItemIndex );
   else if( strcasecmp(szProp,"nClrPane")==0 )   hb_retnint( (HB_MAXINT)p->FClrPane );
   else if( strcasecmp(szProp,"oFont")==0 ) {
      char szFont[128] = "System,12";
      if( p->FFont ) sprintf(szFont,"%s,%d", [[p->FFont fontName] UTF8String], (int)[p->FFont pointSize]);
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

   ADD_S("cClassName",p->FClassName,"Info");
   ADD_S("cName",p->FName,"Appearance");
   ADD_S("cText",p->FText,"Appearance");
   ADD_N("nLeft",p->FLeft,"Position"); ADD_N("nTop",p->FTop,"Position");
   ADD_N("nWidth",p->FWidth,"Position"); ADD_N("nHeight",p->FHeight,"Position");
   ADD_L("lVisible",p->FVisible,"Behavior"); ADD_L("lEnabled",p->FEnabled,"Behavior");
   ADD_L("lTabStop",p->FTabStop,"Behavior");

   { char sf[128]="System,12";
     if(p->FFont) sprintf(sf,"%s,%d",[[p->FFont fontName] UTF8String],(int)[p->FFont pointSize]);
     ADD_F("oFont",sf,"Appearance"); }
   ADD_C("nClrPane",p->FClrPane,"Appearance");

   switch(p->FControlType) {
      case CT_BUTTON:
         ADD_L("lDefault",((HBButton*)p)->FDefault,"Behavior");
         ADD_L("lCancel",((HBButton*)p)->FCancel,"Behavior"); break;
      case CT_CHECKBOX: ADD_L("lChecked",((HBCheckBox*)p)->FChecked,"Data"); break;
      case CT_EDIT:
         ADD_L("lReadOnly",((HBEdit*)p)->FReadOnly,"Behavior");
         ADD_L("lPassword",((HBEdit*)p)->FPassword,"Behavior"); break;
      case CT_COMBOBOX:
         ADD_N("nItemIndex",((HBComboBox*)p)->FItemIndex,"Data");
         ADD_N("nItemCount",((HBComboBox*)p)->FItemCount,"Data"); break;
   }
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
   if( pForm ) { pForm->FToolBar = p; p->FCtrlParent = (HBControl *)pForm; }
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

   for( int i = 0; i < t->nBtnCount; i++ ) {
      NSString * title = [NSString stringWithUTF8String:t->btns[i].szText];
      NSFont * btnFont = [NSFont systemFontOfSize:11];
      int thisBtnW = btnW;

      /* If palette images loaded, use icon index from nControlType */
      int imgIdx = t->btns[i].nControlType;
      BOOL hasImage = ( pd->palImages && imgIdx > 0 && imgIdx <= (int)[pd->palImages count] );

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
         [btn setImage:pd->palImages[imgIdx - 1]];
         [btn setImagePosition:NSImageOnly];
         [btn setTitle:@""];
      } else {
         [btn setTitle:title];
      }
      [btn setToolTip:[NSString stringWithUTF8String:t->btns[i].szTooltip]];
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

HB_FUNC( UI_FORMSETPOS )
{
   HBForm * p = GetForm(1);
   if( p ) {
      p->FLeft = hb_parni(2);
      p->FTop = hb_parni(3);
      p->FCenter = NO;
      if( p->FWindow ) {
         /* macOS uses bottom-left origin, flip Y */
         NSRect screenFrame = [[NSScreen mainScreen] frame];
         NSPoint origin;
         origin.x = p->FLeft;
         origin.y = screenFrame.size.height - p->FTop - p->FHeight;
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

/* ======================================================================
 * Code Editor - NSTextView with syntax highlighting (dark theme)
 * ====================================================================== */

#define GUTTER_WIDTH 45

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

static int CE_IsWordChar( char c )
{
   return ( c >= 'A' && c <= 'Z' ) || ( c >= 'a' && c <= 'z' ) ||
          ( c >= '0' && c <= '9' ) || c == '_';
}

static int CE_IsKeyword( const char * word, int len )
{
   char buf[64];
   if( len <= 0 || len >= 63 ) return 0;
   for( int i = 0; i < len; i++ ) buf[i] = (char)tolower( (unsigned char)word[i] );
   buf[len] = 0;
   for( int i = 0; s_keywords[i]; i++ )
      if( strcmp( buf, s_keywords[i] ) == 0 ) return 1;
   return 0;
}

static int CE_IsCommand( const char * word, int len )
{
   char buf[64];
   if( len <= 0 || len >= 63 ) return 0;
   for( int i = 0; i < len; i++ ) buf[i] = (char)toupper( (unsigned char)word[i] );
   buf[len] = 0;
   for( int i = 0; s_commands[i]; i++ )
      if( strcmp( buf, s_commands[i] ) == 0 ) return 1;
   return 0;
}

/* -----------------------------------------------------------------------
 * Line number gutter view
 * ----------------------------------------------------------------------- */

@interface HBGutterView : NSView
{
@public
   NSTextView * __unsafe_unretained textView;
   NSFont * font;
}
@end

@implementation HBGutterView

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect
{
   /* Dark background */
   [[NSColor colorWithCalibratedRed:37/255.0 green:37/255.0 blue:38/255.0 alpha:1.0] setFill];
   NSRectFill( dirtyRect );

   /* Right border */
   [[NSColor colorWithCalibratedRed:60/255.0 green:60/255.0 blue:60/255.0 alpha:1.0] setStroke];
   NSBezierPath * line = [NSBezierPath bezierPath];
   [line moveToPoint:NSMakePoint( GUTTER_WIDTH - 1, dirtyRect.origin.y )];
   [line lineToPoint:NSMakePoint( GUTTER_WIDTH - 1, dirtyRect.origin.y + dirtyRect.size.height )];
   [line stroke];

   if( !textView ) return;

   NSLayoutManager * lm = [textView layoutManager];
   NSTextContainer * tc = [textView textContainer];
   NSString * text = [[textView textStorage] string];
   NSUInteger length = [text length];

   if( length == 0 ) return;

   NSDictionary * attrs = @{
      NSFontAttributeName: font ? font : [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular],
      NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:133/255.0 green:133/255.0 blue:133/255.0 alpha:1.0]
   };

   /* Visible rect in textView coordinates */
   NSRect visibleRect = [textView visibleRect];
   NSRange glyphRange = [lm glyphRangeForBoundingRect:visibleRect inTextContainer:tc];
   NSRange charRange = [lm characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];

   /* Walk lines in visible range */
   NSUInteger idx = charRange.location;
   int lineNum = 1;

   /* Count lines before visible range */
   for( NSUInteger i = 0; i < idx && i < length; i++ )
      if( [text characterAtIndex:i] == '\n' ) lineNum++;

   CGFloat yOffset = [textView textContainerInset].height;

   while( idx < NSMaxRange(charRange) && idx < length )
   {
      NSRange lineRange = [text lineRangeForRange:NSMakeRange(idx, 0)];
      NSRange glRange = [lm glyphRangeForCharacterRange:lineRange actualCharacterRange:NULL];
      NSRect lineRect = [lm boundingRectForGlyphRange:glRange inTextContainer:tc];

      /* Convert textView coords to gutter coords */
      CGFloat yPos = lineRect.origin.y + yOffset - visibleRect.origin.y;

      NSString * numStr = [NSString stringWithFormat:@"%d", lineNum];
      NSSize numSize = [numStr sizeWithAttributes:attrs];
      [numStr drawAtPoint:NSMakePoint( GUTTER_WIDTH - 8 - numSize.width, yPos )
           withAttributes:attrs];

      lineNum++;
      idx = NSMaxRange(lineRange);
   }
}

@end

/* -----------------------------------------------------------------------
 * Code editor data structure
 * ----------------------------------------------------------------------- */

typedef struct {
   NSWindow *     window;
   NSTextView *   textView;
   NSScrollView * scrollView;
   HBGutterView * gutterView;
   NSFont *       font;
} CODEEDITOR;

/* -----------------------------------------------------------------------
 * Syntax highlighting
 * ----------------------------------------------------------------------- */

static void CE_HighlightCode( NSTextView * tv )
{
   NSTextStorage * ts = [tv textStorage];
   NSString * text = [ts string];
   NSUInteger nLen = [text length];

   if( nLen == 0 ) return;

   const char * buf = [text UTF8String];
   NSUInteger utf8Len = strlen( buf );

   /* Default color: light gray */
   NSColor * clrDefault  = [NSColor colorWithCalibratedRed:212/255.0 green:212/255.0 blue:212/255.0 alpha:1.0];
   NSColor * clrComment  = [NSColor colorWithCalibratedRed:106/255.0 green:153/255.0 blue:85/255.0  alpha:1.0];
   NSColor * clrString   = [NSColor colorWithCalibratedRed:206/255.0 green:145/255.0 blue:120/255.0 alpha:1.0];
   NSColor * clrKeyword  = [NSColor colorWithCalibratedRed:86/255.0  green:156/255.0 blue:214/255.0 alpha:1.0];
   NSColor * clrCommand  = [NSColor colorWithCalibratedRed:78/255.0  green:201/255.0 blue:176/255.0 alpha:1.0];
   NSColor * clrPreproc  = [NSColor colorWithCalibratedRed:198/255.0 green:120/255.0 blue:221/255.0 alpha:1.0];

   NSFont * boldFont = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightBold];

   [ts beginEditing];

   /* Reset all to default */
   [ts addAttribute:NSForegroundColorAttributeName value:clrDefault range:NSMakeRange(0, nLen)];

   /* We work in UTF-8 offsets and convert to NSString offsets.
      For ASCII-only code, they are the same. Use a mapping approach. */
   NSUInteger i = 0;
   while( i < utf8Len )
   {
      /* Line comments: // */
      if( buf[i] == '/' && i + 1 < utf8Len && buf[i+1] == '/' )
      {
         NSUInteger start = i;
         while( i < utf8Len && buf[i] != '\r' && buf[i] != '\n' ) i++;
         [ts addAttribute:NSForegroundColorAttributeName value:clrComment
            range:NSMakeRange(start, i - start)];
         continue;
      }

      /* Block comments */
      if( buf[i] == '/' && i + 1 < utf8Len && buf[i+1] == '*' )
      {
         NSUInteger start = i;
         i += 2;
         while( i + 1 < utf8Len && !( buf[i] == '*' && buf[i+1] == '/' ) ) i++;
         if( i + 1 < utf8Len ) i += 2;
         [ts addAttribute:NSForegroundColorAttributeName value:clrComment
            range:NSMakeRange(start, i - start)];
         continue;
      }

      /* Strings */
      if( buf[i] == '"' || buf[i] == '\'' )
      {
         char q = buf[i];
         NSUInteger start = i;
         i++;
         while( i < utf8Len && buf[i] != q && buf[i] != '\r' && buf[i] != '\n' ) i++;
         if( i < utf8Len && buf[i] == q ) i++;
         [ts addAttribute:NSForegroundColorAttributeName value:clrString
            range:NSMakeRange(start, i - start)];
         continue;
      }

      /* Preprocessor: # */
      if( buf[i] == '#' )
      {
         NSUInteger start = i;
         i++;
         while( i < utf8Len && CE_IsWordChar(buf[i]) ) i++;
         [ts addAttribute:NSForegroundColorAttributeName value:clrPreproc
            range:NSMakeRange(start, i - start)];
         continue;
      }

      /* Logical literals: .T. .F. .AND. .OR. .NOT. */
      if( buf[i] == '.' && i + 2 < utf8Len )
      {
         NSUInteger start = i;
         i++;
         while( i < utf8Len && buf[i] != '.' && CE_IsWordChar(buf[i]) ) i++;
         if( i < utf8Len && buf[i] == '.' ) {
            i++;
            [ts addAttribute:NSForegroundColorAttributeName value:clrPreproc
               range:NSMakeRange(start, i - start)];
         }
         continue;
      }

      /* Words */
      if( CE_IsWordChar(buf[i]) )
      {
         NSUInteger ws = i;
         while( i < utf8Len && CE_IsWordChar(buf[i]) ) i++;
         int wlen = (int)(i - ws);
         if( CE_IsKeyword( buf + ws, wlen ) ) {
            [ts addAttribute:NSForegroundColorAttributeName value:clrKeyword
               range:NSMakeRange(ws, wlen)];
            [ts addAttribute:NSFontAttributeName value:boldFont
               range:NSMakeRange(ws, wlen)];
         } else if( CE_IsCommand( buf + ws, wlen ) ) {
            [ts addAttribute:NSForegroundColorAttributeName value:clrCommand
               range:NSMakeRange(ws, wlen)];
         }
         continue;
      }

      i++;
   }

   [ts endEditing];
}

/* -----------------------------------------------------------------------
 * Text change delegate — triggers re-highlight and gutter repaint
 * ----------------------------------------------------------------------- */

@interface HBCodeEditorDelegate : NSObject <NSTextViewDelegate>
{
@public
   CODEEDITOR * ed;
}
@end

@implementation HBCodeEditorDelegate

- (void)textDidChange:(NSNotification *)notification
{
   if( ed && ed->textView )
   {
      CE_HighlightCode( ed->textView );
      [ed->gutterView setNeedsDisplay:YES];
   }
}

/* Gutter sync on scroll */
- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
   if( ed && ed->gutterView )
      [ed->gutterView performSelector:@selector(setNeedsDisplay:)
         withObject:@YES afterDelay:0.0];
   return proposedVisibleRect;
}

@end

static HBCodeEditorDelegate * s_codeDelegate = nil;

/* -----------------------------------------------------------------------
 * Scroll observer — repaint gutter when user scrolls
 * ----------------------------------------------------------------------- */

@interface HBScrollObserver : NSObject
{
@public
   CODEEDITOR * ed;
}
@end

@implementation HBScrollObserver

- (void)scrollViewDidScroll:(NSNotification *)notification
{
   if( ed && ed->gutterView )
      [ed->gutterView setNeedsDisplay:YES];
}

@end

static HBScrollObserver * s_scrollObserver = nil;

/* -----------------------------------------------------------------------
 * HB_FUNC Bridge: CodeEditorCreate, CodeEditorSetText, CodeEditorGetText, CodeEditorDestroy
 * ----------------------------------------------------------------------- */

/* CodeEditorCreate( nLeft, nTop, nWidth, nHeight ) --> hEditor */
HB_FUNC( CODEEDITORCREATE )
{
   EnsureNSApp();

   int nLeft   = hb_parni(1);
   int nTop    = hb_parni(2);
   int nWidth  = hb_parni(3);
   int nHeight = hb_parni(4);

   CODEEDITOR * ed = (CODEEDITOR *) calloc( 1, sizeof(CODEEDITOR) );

   /* Monospace font 15pt */
   ed->font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightRegular];

   /* Window */
   NSRect screenFrame = [[NSScreen mainScreen] frame];
   NSRect frame = NSMakeRect( nLeft, screenFrame.size.height - nTop - nHeight, nWidth, nHeight );
   ed->window = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable
      backing:NSBackingStoreBuffered defer:NO];
   [ed->window setTitle:@"Code Editor"];
   [ed->window setReleasedWhenClosed:NO];
   if( [NSAppearance respondsToSelector:@selector(appearanceNamed:)] )
      [ed->window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

   NSView * content = [ed->window contentView];
   NSRect contentBounds = [content bounds];

   /* Gutter view */
   ed->gutterView = [[HBGutterView alloc] initWithFrame:
      NSMakeRect( 0, 0, GUTTER_WIDTH, contentBounds.size.height )];
   ed->gutterView->font = ed->font;
   [ed->gutterView setAutoresizingMask:NSViewHeightSizable];

   /* Scroll view + text view (to the right of gutter) */
   ed->scrollView = [[NSScrollView alloc] initWithFrame:
      NSMakeRect( GUTTER_WIDTH, 0, contentBounds.size.width - GUTTER_WIDTH, contentBounds.size.height )];
   [ed->scrollView setHasVerticalScroller:YES];
   [ed->scrollView setHasHorizontalScroller:YES];
   [ed->scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

   NSSize contentSize = [ed->scrollView contentSize];
   ed->textView = [[NSTextView alloc] initWithFrame:
      NSMakeRect( 0, 0, contentSize.width, contentSize.height )];
   [ed->textView setMinSize:NSMakeSize( 0, contentSize.height )];
   [ed->textView setMaxSize:NSMakeSize( 1e7, 1e7 )];
   [ed->textView setVerticallyResizable:YES];
   [ed->textView setHorizontallyResizable:YES];
   [ed->textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
   [[ed->textView textContainer] setContainerSize:NSMakeSize( 1e7, 1e7 )];
   [[ed->textView textContainer] setWidthTracksTextView:NO];

   /* Dark theme */
   [ed->textView setBackgroundColor:[NSColor colorWithCalibratedRed:30/255.0 green:30/255.0 blue:30/255.0 alpha:1.0]];
   [ed->textView setInsertionPointColor:[NSColor whiteColor]];
   [ed->textView setTextColor:[NSColor colorWithCalibratedRed:212/255.0 green:212/255.0 blue:212/255.0 alpha:1.0]];
   [ed->textView setFont:ed->font];
   [ed->textView setRichText:YES];
   [ed->textView setUsesFindBar:YES];
   [ed->textView setAllowsUndo:YES];

   /* Text inset for better readability */
   [ed->textView setTextContainerInset:NSMakeSize( 4, 4 )];

   /* Link gutter to text view */
   ed->gutterView->textView = ed->textView;

   /* Delegate for text changes */
   s_codeDelegate = [[HBCodeEditorDelegate alloc] init];
   s_codeDelegate->ed = ed;
   [ed->textView setDelegate:s_codeDelegate];

   [ed->scrollView setDocumentView:ed->textView];

   /* Observe scroll for gutter sync */
   s_scrollObserver = [[HBScrollObserver alloc] init];
   s_scrollObserver->ed = ed;
   [[NSNotificationCenter defaultCenter] addObserver:s_scrollObserver
      selector:@selector(scrollViewDidScroll:)
      name:NSViewBoundsDidChangeNotification
      object:[ed->scrollView contentView]];
   [[ed->scrollView contentView] setPostsBoundsChangedNotifications:YES];

   [content addSubview:ed->gutterView];
   [content addSubview:ed->scrollView];

   [ed->window orderFront:nil];

   hb_retnint( (HB_PTRUINT) ed );
}

/* CodeEditorSetText( hEditor, cText ) */
HB_FUNC( CODEEDITORSETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->textView && HB_ISCHAR(2) )
   {
      NSString * text = [NSString stringWithUTF8String:hb_parc(2)];
      [[ed->textView textStorage] replaceCharactersInRange:
         NSMakeRange(0, [[ed->textView textStorage] length]) withString:text];
      [ed->textView setFont:ed->font];
      CE_HighlightCode( ed->textView );
      [ed->gutterView setNeedsDisplay:YES];
   }
}

/* CodeEditorGetText( hEditor ) --> cText */
HB_FUNC( CODEEDITORGETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->textView )
   {
      NSString * text = [[ed->textView textStorage] string];
      const char * utf8 = [text UTF8String];
      hb_retc( utf8 ? utf8 : "" );
   }
   else
      hb_retc( "" );
}

/* CodeEditorDestroy( hEditor ) */
HB_FUNC( CODEEDITORDESTROY )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed )
   {
      [[NSNotificationCenter defaultCenter] removeObserver:s_scrollObserver];
      if( ed->window ) [ed->window close];
      free( ed );
   }
}
