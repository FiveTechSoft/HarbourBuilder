// cocoa_report.mm - Report designer UI for macOS
//
// This file implements the report designer user interface using AppKit.
// Contains NSView subclasses for report bands, fields, and designer.

#import <Cocoa/Cocoa.h>
#import "hbapi.h"

// ============================================================================
// HBBReportFieldView - Report field view
// ============================================================================

@interface HBBReportFieldView : NSView
@property (nonatomic, copy) NSString *fieldText;
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *borderColor;
@property (nonatomic) BOOL selected;
@end

@implementation HBBReportFieldView

- (instancetype)initWithFrame:(NSRect)frameRect
{
   self = [super initWithFrame:frameRect];
   if( self )
   {
      _fieldText = @"Field";
      _backgroundColor = [NSColor whiteColor];
      _borderColor = [NSColor blueColor];
      _selected = NO;
   }
   return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
   [super drawRect:dirtyRect];

   // Draw background
   [self.backgroundColor setFill];
   NSRectFill(dirtyRect);

   // Draw border
   [self.borderColor setStroke];
   NSFrameRectWithWidth(self.bounds, 1.0);

   // Draw text
   NSDictionary *attrs = @{
      NSFontAttributeName: [NSFont systemFontOfSize:10],
      NSForegroundColorAttributeName: [NSColor blackColor]
   };

   NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:self.fieldText attributes:attrs];
   NSRect textRect = [self bounds];
   [attrStr drawInRect:textRect];

   // Draw selection handles if selected
   if( self.selected )
   {
      [[NSColor blueColor] setFill];
      NSRect handles[] = {
         NSMakeRect(0, 0, 6, 6),
         NSMakeRect(NSWidth(self.bounds)-6, 0, 6, 6),
         NSMakeRect(0, NSHeight(self.bounds)-6, 6, 6),
         NSMakeRect(NSWidth(self.bounds)-6, NSHeight(self.bounds)-6, 6, 6)
      };
      for( int i = 0; i < 4; i++ )
      {
         NSRectFill(handles[i]);
      }
   }
}

@end

// ============================================================================
// HBBReportBandView - Report band view
// ============================================================================

@interface HBBReportBandView : NSView
@property (nonatomic, copy) NSString *bandName;
@property (nonatomic, strong) NSColor *bandColor;
@property (nonatomic) NSInteger bandType; // 0=Header, 1=Detail, 2=Footer, etc.
@property (nonatomic, strong) NSMutableArray<HBBReportFieldView *> *fieldViews;
@end

@implementation HBBReportBandView

- (instancetype)initWithFrame:(NSRect)frameRect
{
   self = [super initWithFrame:frameRect];
   if( self )
   {
      _bandName = @"Band";
      _bandType = 1; // Detail by default
      _fieldViews = [NSMutableArray array];

      // Set color based on band type
      switch( _bandType )
      {
         case 0: _bandColor = [NSColor colorWithCalibratedRed:0.8 green:0.9 blue:1.0 alpha:1.0]; break; // Header - light blue
         case 1: _bandColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.9 alpha:1.0]; break; // Detail - light yellow
         case 2: _bandColor = [NSColor colorWithCalibratedRed:0.9 green:1.0 blue:0.9 alpha:1.0]; break; // Footer - light green
         default: _bandColor = [NSColor lightGrayColor];
      }
   }
   return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
   [super drawRect:dirtyRect];

   // Draw band background
   [self.bandColor setFill];
   NSRectFill(dirtyRect);

   // Draw band label
   NSDictionary *attrs = @{
      NSFontAttributeName: [NSFont boldSystemFontOfSize:12],
      NSForegroundColorAttributeName: [NSColor darkGrayColor]
   };

   NSString *displayName = [NSString stringWithFormat:@"%@ Band", self.bandName];
   NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:displayName attributes:attrs];
   NSRect textRect = NSInsetRect(self.bounds, 10, 0);
   textRect.origin.y = NSMidY(self.bounds) - 8;
   [attrStr drawInRect:textRect];
}

- (void)addFieldView:(HBBReportFieldView *)fieldView
{
   [self.fieldViews addObject:fieldView];
   [self addSubview:fieldView];
}

@end

// ============================================================================
// HBBReportDesignerView - Main report designer view
// ============================================================================

@interface HBBReportDesignerView : NSView <NSDraggingDestination>
@property (nonatomic, strong) NSMutableArray<HBBReportBandView *> *bandViews;
@property (nonatomic, strong) NSRulerView *horizontalRuler;
@property (nonatomic, strong) NSRulerView *verticalRuler;
@property (nonatomic) NSPoint dragStartPoint;
@property (nonatomic, strong) HBBReportFieldView *draggingField;
@end

@implementation HBBReportDesignerView

- (instancetype)initWithFrame:(NSRect)frameRect
{
   self = [super initWithFrame:frameRect];
   if( self )
   {
      _bandViews = [NSMutableArray array];
      [self setupRulers];
      [self registerForDraggedTypes:@[NSPasteboardTypeString]];
   }
   return self;
}

- (void)setupRulers
{
   // Horizontal ruler
   self.horizontalRuler = [[NSRulerView alloc] initWithScrollView:nil orientation:NSHorizontalRuler];
   [self.horizontalRuler setClientView:self];
   [self.horizontalRuler setMeasurementUnits:@"Points"];

   // Vertical ruler
   self.verticalRuler = [[NSRulerView alloc] initWithScrollView:nil orientation:NSVerticalRuler];
   [self.verticalRuler setClientView:self];
   [self.verticalRuler setMeasurementUnits:@"Points"];
}

- (void)drawRect:(NSRect)dirtyRect
{
   [super drawRect:dirtyRect];

   // Draw designer background (grid pattern)
   [[NSColor whiteColor] setFill];
   NSRectFill(dirtyRect);

   // Draw grid
   [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] setStroke];
   NSBezierPath *gridPath = [NSBezierPath bezierPath];

   // Vertical lines
   for( CGFloat x = 0; x < NSWidth(self.bounds); x += 20 )
   {
      [gridPath moveToPoint:NSMakePoint(x, 0)];
      [gridPath lineToPoint:NSMakePoint(x, NSHeight(self.bounds))];
   }

   // Horizontal lines
   for( CGFloat y = 0; y < NSHeight(self.bounds); y += 20 )
   {
      [gridPath moveToPoint:NSMakePoint(0, y)];
      [gridPath lineToPoint:NSMakePoint(NSWidth(self.bounds), y)];
   }

   [gridPath stroke];
}

- (void)addBandView:(HBBReportBandView *)bandView
{
   [self.bandViews addObject:bandView];
   [self addSubview:bandView];
}

// ============================================================================
// Drag and Drop Support
// ============================================================================

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
   return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
   // TODO: Implement drag and drop for report fields
   return YES;
}

@end

// ============================================================================
// Harbour Bridge Functions
// ============================================================================

HB_FUNC( RPT_CREATEDESIGNERWINDOW )
{
   // TODO: Create and show report designer window
   hb_retnl( 0 ); // Return window handle
}

HB_FUNC( RPT_ADDBANDTODESIGNER )
{
   // TODO: Add band to designer
   hb_retl( YES );
}

HB_FUNC( RPT_ADDFIELDTODESIGNER )
{
   // TODO: Add field to designer
   hb_retl( YES );
}

// ============================================================================
// Stub Functions for Future Implementation
// ============================================================================

HB_FUNC( RPT_GETSELECTEDFIELD ) { hb_retnl( 0 ); }
HB_FUNC( RPT_GETSELECTEDBAND ) { hb_retnl( 0 ); }
HB_FUNC( RPT_SETBANDPOSITION ) { hb_retl( YES ); }
HB_FUNC( RPT_SETFIELDPOSITION ) { hb_retl( YES ); }
HB_FUNC( RPT_UPDATEDESIGNER ) { hb_retl( YES ); }