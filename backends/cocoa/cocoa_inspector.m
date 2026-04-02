/*
 * cocoa_inspector.m - Property inspector using Cocoa NSTableView
 * Replaces the Win32 ListView-based inspector for macOS.
 *
 * Exports: INS_Create, INS_RefreshWithData, INS_BringToFront, INS_Destroy
 *          _INSGETDATA, _INSSETDATA
 */

#import <Cocoa/Cocoa.h>
#include <hbapi.h>
#include <hbapiitm.h>
#include <hbvm.h>
#include <string.h>
#include <hbstack.h>
#include <stdio.h>

#define MAX_ROWS 64

/* ======================================================================
 * Data model
 * ====================================================================== */

typedef struct {
   char szName[32];
   char szValue[256];
   char szCategory[32];
   char cType;       /* S=string, N=number, L=logical, C=color, F=font */
   BOOL bIsCat;      /* category header */
   BOOL bCollapsed;
   BOOL bVisible;
} IROW;

typedef struct {
   NSWindow *   window;
   NSTableView * tableView;
   NSFont *     font;
   NSFont *     boldFont;
   HB_PTRUINT   hCtrl;       /* currently inspected control handle */
   HB_PTRUINT   hFormCtrl;   /* form handle for combo enumeration */
   IROW         rows[MAX_ROWS];
   int          nRows;
   int          map[MAX_ROWS]; /* visible row -> rows index */
   int          nVisible;
   NSScrollView * scrollView;
   NSPopUpButton * combo;    /* control selection combo */
   PHB_ITEM     pOnComboSel; /* callback for combo selection change */
   NSSegmentedControl * tabCtrl; /* Properties / Events tabs */
   int          nTab;        /* 0 = Properties, 1 = Events */
   /* Cached event data */
   IROW         evRows[MAX_ROWS];
   int          nEvRows;
   int          evMap[MAX_ROWS];
   int          nEvVisible;
   /* Callback for double-click on event */
   PHB_ITEM     pOnEventDblClick;
   /* Callback after property edit (two-way sync) */
   PHB_ITEM     pOnPropChanged;
} INSDATA;

/* Forward declarations */
static void InsBuildRows( INSDATA * d, PHB_ITEM pArray );
static void InsBuildEventRows( INSDATA * d );
static void InsRefreshTab( INSDATA * d );

/* ======================================================================
 * Table view data source / delegate
 * ====================================================================== */

/* ======================================================================
 * Color picker helper — receives NSColorPanel selection
 * ====================================================================== */

static void InsApplyColor( INSDATA * d, int nReal, unsigned int clr );

@interface HBColorPickerTarget : NSObject
{
@public
   INSDATA * d;
   int       nReal;  /* row index in d->rows[] */
}
- (void)colorChanged:(id)sender;
@end

@implementation HBColorPickerTarget

- (void)colorChanged:(id)sender
{
   NSColor * c = [[NSColorPanel sharedColorPanel] color];
   c = [c colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
   unsigned int r = (unsigned int)([c redComponent]   * 255.0 + 0.5);
   unsigned int g = (unsigned int)([c greenComponent] * 255.0 + 0.5);
   unsigned int b = (unsigned int)([c blueComponent]  * 255.0 + 0.5);
   unsigned int clr = r | (g << 8) | (b << 16);

   InsApplyColor( d, nReal, clr );
}

@end

static HBColorPickerTarget * s_colorTarget = nil;

/* ======================================================================
 * Font picker helper — receives NSFontPanel selection
 * ====================================================================== */

static void InsApplyFont( INSDATA * d, int nReal, NSFont * font );

@interface HBFontPickerTarget : NSObject
{
@public
   INSDATA * d;
   int       nReal;
}
- (void)changeFont:(id)sender;
@end

@implementation HBFontPickerTarget

- (void)changeFont:(id)sender
{
   NSFontManager * fm = [NSFontManager sharedFontManager];
   NSFont * font = [fm convertFont:[NSFont systemFontOfSize:12]];
   InsApplyFont( d, nReal, font );
}

/* Required to keep the font panel active */
- (BOOL)acceptsFirstResponder { return YES; }

@end

static HBFontPickerTarget * s_fontTarget = nil;

/* ======================================================================
 * Button cell for "..." in color/font rows
 * ====================================================================== */

@interface HBButtonCell : NSButtonCell
{
@public
   INSDATA * insData;
}
@end

@implementation HBButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
   /* Draw nothing - the button column draws its own button per-row */
   [super drawWithFrame:cellFrame inView:controlView];
}

@end

/* ======================================================================
 * Inspector delegate
 * ====================================================================== */

@interface HBInspectorDelegate : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
@public
   INSDATA * d;
}
@end

@implementation HBInspectorDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
   return d ? d->nVisible : 0;
}

- (id)tableView:(NSTableView *)tableView
   objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   if( !d || row < 0 || row >= d->nVisible ) return @"";
   int nReal = d->map[row];

   if( [[col identifier] isEqualToString:@"name"] )
   {
      if( d->rows[nReal].bIsCat )
         return [NSString stringWithFormat:@"%c  %s",
            d->rows[nReal].bCollapsed ? '+' : '-',
            d->rows[nReal].szName];
      else
         return [NSString stringWithFormat:@"    %s", d->rows[nReal].szName];
   }
   else if( [[col identifier] isEqualToString:@"button"] )
   {
      if( d->rows[nReal].bIsCat ) return @"";
      if( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' ) return @"...";
      return @"";
   }
   else
   {
      if( d->rows[nReal].bIsCat ) return @"";
      return [NSString stringWithUTF8String:d->rows[nReal].szValue];
   }
}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)value forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   if( !d || row < 0 || row >= d->nVisible ) return;
   if( ![[col identifier] isEqualToString:@"value"] ) return;

   int nReal = d->map[row];
   if( d->rows[nReal].bIsCat ) return;

   const char * szVal = [value UTF8String];
   strncpy( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) - 1 );

   /* Apply value via UI_SetProp */
   PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
   if( pDyn )
   {
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );

      if( d->rows[nReal].cType == 'S' || d->rows[nReal].cType == 'F' )
         hb_vmPushString( szVal, strlen(szVal) );
      else if( d->rows[nReal].cType == 'N' )
         hb_vmPushInteger( atoi(szVal) );
      else if( d->rows[nReal].cType == 'L' )
         hb_vmPushLogical( strcasecmp(szVal,".T.")==0 );
      else if( d->rows[nReal].cType == 'C' )
         hb_vmPushNumInt( (HB_MAXINT) strtoul(szVal, NULL, 10) );
      else
         hb_vmPushNil();

      hb_vmDo( 3 );
   }

   /* Fire two-way sync callback */
   if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnPropChanged );
      hb_vmSend( 0 );
   }
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   if( !d || row < 0 || row >= d->nVisible ) return NO;
   int nReal = d->map[row];
   if( d->rows[nReal].bIsCat ) return NO;
   if( [[col identifier] isEqualToString:@"name"] ) return NO;
   if( [[col identifier] isEqualToString:@"button"] ) return NO;
   if( d->rows[nReal].cType == 'E' ) return NO; /* Events not editable */

   /* For color properties, open NSColorPanel instead of inline editing */
   if( d->rows[nReal].cType == 'C' && [[col identifier] isEqualToString:@"value"] )
   {
      [self openColorPickerForRow:nReal];
      return NO;
   }
   /* For font properties, open NSFontPanel instead of inline editing */
   if( d->rows[nReal].cType == 'F' && [[col identifier] isEqualToString:@"value"] )
   {
      [self openFontPickerForRow:nReal];
      return NO;
   }
   return YES;
}

- (void)openColorPickerForRow:(int)nReal
{
   /* Set initial color from current value */
   unsigned int clr = (unsigned int) strtoul( d->rows[nReal].szValue, NULL, 10 );
   CGFloat r = (clr & 0xFF) / 255.0;
   CGFloat g = ((clr >> 8) & 0xFF) / 255.0;
   CGFloat b = ((clr >> 16) & 0xFF) / 255.0;
   NSColor * initial = [NSColor colorWithSRGBRed:r green:g blue:b alpha:1.0];

   if( !s_colorTarget )
      s_colorTarget = [[HBColorPickerTarget alloc] init];
   s_colorTarget->d = d;
   s_colorTarget->nReal = nReal;

   NSColorPanel * panel = [NSColorPanel sharedColorPanel];
   [panel setTarget:s_colorTarget];
   [panel setAction:@selector(colorChanged:)];
   [panel setColor:initial];
   [panel setContinuous:YES];
   [panel orderFront:nil];
}

- (void)openFontPickerForRow:(int)nReal
{
   /* Parse current value "FontName,Size" */
   char szFace[64] = "System";
   int nSize = 12;
   const char * val = d->rows[nReal].szValue;
   const char * comma = strchr( val, ',' );
   if( comma )
   {
      int len = (int)(comma - val);
      if( len > 63 ) len = 63;
      memcpy( szFace, val, len );
      szFace[len] = 0;
      nSize = atoi( comma + 1 );
   }
   else
      strncpy( szFace, val, 63 );
   if( nSize <= 0 ) nSize = 12;

   NSFont * current = [NSFont fontWithName:[NSString stringWithUTF8String:szFace]
                                      size:(CGFloat)nSize];
   if( !current ) current = [NSFont systemFontOfSize:(CGFloat)nSize];

   if( !s_fontTarget )
      s_fontTarget = [[HBFontPickerTarget alloc] init];
   s_fontTarget->d = d;
   s_fontTarget->nReal = nReal;

   NSFontManager * fm = [NSFontManager sharedFontManager];
   [fm setSelectedFont:current isMultiple:NO];
   [fm setTarget:s_fontTarget];
   [fm setAction:@selector(changeFont:)];

   NSFontPanel * panel = [fm fontPanel:YES];
   [panel orderFront:nil];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   if( !d || row < 0 || row >= d->nVisible ) return;
   int nReal = d->map[row];

   if( d->rows[nReal].bIsCat )
   {
      if( [[col identifier] isEqualToString:@"button"] )
      {
         [cell setTitle:@""];
         [cell setTransparent:YES];
         [cell setEnabled:NO];
      }
      else
      {
         [cell setFont:d->boldFont];
         [cell setDrawsBackground:YES];
         [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.90 alpha:1.0]];
      }
   }
   else
   {
      [cell setFont:d->font];
      [cell setDrawsBackground:( row % 2 == 1 )];
      if( row % 2 == 1 )
         [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.97 alpha:1.0]];

      /* Color swatch for value column on color properties */
      if( [[col identifier] isEqualToString:@"value"] && d->rows[nReal].cType == 'C' )
      {
         unsigned int clr = (unsigned int) strtoul( d->rows[nReal].szValue, NULL, 10 );
         CGFloat r = (clr & 0xFF) / 255.0;
         CGFloat g = ((clr >> 8) & 0xFF) / 255.0;
         CGFloat b = ((clr >> 16) & 0xFF) / 255.0;
         [cell setDrawsBackground:YES];
         [cell setBackgroundColor:[NSColor colorWithSRGBRed:r green:g blue:b alpha:1.0]];
      }

      /* Show "..." button for color and font properties, hide for others */
      if( [[col identifier] isEqualToString:@"button"] )
      {
         if( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' )
         {
            [cell setTitle:@"..."];
            [cell setTransparent:NO];
            [cell setEnabled:YES];
         }
         else
         {
            [cell setTitle:@""];
            [cell setTransparent:YES];
            [cell setEnabled:NO];
         }
      }
   }
}

/* Handle click on category row to toggle collapse */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
   if( !d || row < 0 || row >= d->nVisible ) return NO;
   int nReal = d->map[row];

   if( d->rows[nReal].bIsCat )
   {
      d->rows[nReal].bCollapsed = !d->rows[nReal].bCollapsed;
      for( int k = nReal + 1; k < d->nRows && !d->rows[k].bIsCat; k++ )
         d->rows[k].bVisible = !d->rows[nReal].bCollapsed;

      /* Rebuild visible map */
      d->nVisible = 0;
      for( int i = 0; i < d->nRows; i++ )
      {
         if( d->rows[i].bVisible || d->rows[i].bIsCat )
            d->map[d->nVisible++] = i;
      }
      [tableView reloadData];
      return NO;
   }
   return YES;
}

/* Handle single-click on the table */
- (void)tableViewClicked:(id)sender
{
   NSInteger row = [d->tableView clickedRow];
   NSInteger col = [d->tableView clickedColumn];
   if( row < 0 || row >= d->nVisible ) return;

   int nReal = d->map[row];

   /* Click on category row: toggle collapse */
   if( d->rows[nReal].bIsCat )
   {
      d->rows[nReal].bCollapsed = !d->rows[nReal].bCollapsed;
      for( int k = nReal + 1; k < d->nRows && !d->rows[k].bIsCat; k++ )
         d->rows[k].bVisible = !d->rows[nReal].bCollapsed;

      d->nVisible = 0;
      for( int i = 0; i < d->nRows; i++ )
      {
         if( d->rows[i].bVisible || d->rows[i].bIsCat )
            d->map[d->nVisible++] = i;
      }
      [d->tableView reloadData];
      return;
   }

   /* Click on "..." button column: open picker */
   if( col >= 0 )
   {
      NSTableColumn * clickedCol = [[d->tableView tableColumns] objectAtIndex:col];
      if( [[clickedCol identifier] isEqualToString:@"button"] )
      {
         if( d->rows[nReal].cType == 'C' )
            [self openColorPickerForRow:nReal];
         else if( d->rows[nReal].cType == 'F' )
            [self openFontPickerForRow:nReal];
      }
   }
}

/* Tab changed (Properties / Events) */
- (void)tabChanged:(id)sender
{
   if( !d || !d->tabCtrl ) return;
   d->nTab = (int)[d->tabCtrl selectedSegment];

   /* Update column headers */
   NSTableColumn * nameCol = [d->tableView tableColumnWithIdentifier:@"name"];
   if( nameCol )
      [[nameCol headerCell] setStringValue: d->nTab == 0 ? @"Property" : @"Event"];

   NSTableColumn * valCol = [d->tableView tableColumnWithIdentifier:@"value"];
   if( valCol )
      [[valCol headerCell] setStringValue: d->nTab == 0 ? @"Value" : @"Handler"];

   InsRefreshTab( d );
   [d->tableView setNeedsDisplay:YES];
   [[d->tableView headerView] setNeedsDisplay:YES];
}

/* Double-click: Properties tab -> inline edit, Events tab -> generate handler */
- (void)tableViewDoubleClicked:(id)sender
{
   if( !d ) return;

   NSInteger row = [d->tableView clickedRow];
   NSInteger col = [d->tableView clickedColumn];

   /* Properties tab: start inline editing on the value column */
   if( d->nTab == 0 )
   {
      if( row < 0 || row >= d->nVisible ) return;
      int nReal = d->map[row];
      if( d->rows[nReal].bIsCat ) return;

      /* Find value column index */
      NSInteger valColIdx = -1;
      for( NSInteger c = 0; c < (NSInteger)[[d->tableView tableColumns] count]; c++ )
      {
         NSTableColumn * tc = [[d->tableView tableColumns] objectAtIndex:c];
         if( [[tc identifier] isEqualToString:@"value"] ) { valColIdx = c; break; }
      }
      if( valColIdx < 0 ) return;

      /* Color/Font: open picker instead */
      if( d->rows[nReal].cType == 'C' ) { [self openColorPickerForRow:nReal]; return; }
      if( d->rows[nReal].cType == 'F' ) { [self openFontPickerForRow:nReal]; return; }

      /* Defer edit to next runloop to avoid conflict with doubleAction */
      dispatch_async( dispatch_get_main_queue(), ^{
         [d->tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
         [d->tableView editColumn:valColIdx row:row withEvent:nil select:YES];
      });
      return;
   }

   /* Events tab */
   if( row < 0 || row >= d->nVisible ) return;

   int nReal = d->map[row];
   if( d->rows[nReal].bIsCat ) return;  /* Skip category headers */

   /* Fire Harbour callback with event name and control handle */
   if( d->pOnEventDblClick && HB_IS_BLOCK( d->pOnEventDblClick ) )
   {
      const char * szEvent = d->rows[nReal].szName;
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnEventDblClick );
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( szEvent, strlen(szEvent) );
      hb_vmSend( 2 );

      /* Update the value in the row from Harbour return value */
      PHB_ITEM pRet = hb_stackReturnItem();
      if( pRet && HB_IS_STRING( pRet ) )
      {
         const char * szHandler = hb_itemGetCPtr( pRet );
         if( szHandler && szHandler[0] )
         {
            strncpy( d->rows[nReal].szValue, szHandler, sizeof(d->rows[0].szValue) - 1 );
            /* Also update evRows */
            if( nReal < d->nEvRows )
               strncpy( d->evRows[nReal].szValue, szHandler, sizeof(d->evRows[0].szValue) - 1 );
            [d->tableView reloadData];
         }
      }
   }
}

/* Combo selection changed - fire Harbour callback */
- (void)comboSelChanged:(id)sender
{
   if( !d || !d->combo || !d->pOnComboSel ) return;
   NSInteger idx = [d->combo indexOfSelectedItem];
   hb_vmPushEvalSym();
   hb_vmPush( d->pOnComboSel );
   hb_vmPushInteger( (int) idx );
   hb_vmSend( 1 );
}

/* Handle click on "..." button column (view-based fallback) */
- (void)onBtnClick:(id)sender
{
   NSInteger row = [d->tableView rowForView:sender];

   /* Fallback: if rowForView fails (cell-based), use clickedRow */
   if( row < 0 ) row = [d->tableView clickedRow];
   if( row < 0 || row >= d->nVisible ) return;

   int nReal = d->map[row];
   if( d->rows[nReal].bIsCat ) return;

   if( d->rows[nReal].cType == 'C' )
      [self openColorPickerForRow:nReal];
}

@end

/* ======================================================================
 * Apply a color value to the inspected control and update the row
 * ====================================================================== */

static void InsApplyColor( INSDATA * d, int nReal, unsigned int clr )
{
   sprintf( d->rows[nReal].szValue, "%u", clr );

   /* Apply via UI_SetProp */
   PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
   if( pDyn )
   {
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
      hb_vmPushNumInt( (HB_MAXINT) clr );
      hb_vmDo( 3 );
   }

   [d->tableView reloadData];

   /* Fire two-way sync */
   if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnPropChanged );
      hb_vmSend( 0 );
   }
}

static void InsApplyFont( INSDATA * d, int nReal, NSFont * font )
{
   /* Format as "FontName,Size" */
   const char * name = [[font displayName] UTF8String];
   int size = (int)[font pointSize];
   snprintf( d->rows[nReal].szValue, sizeof(d->rows[0].szValue), "%s,%d", name, size );

   /* Apply via UI_SetProp as string */
   PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
   if( pDyn )
   {
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
      hb_vmPushString( d->rows[nReal].szValue, strlen(d->rows[nReal].szValue) );
      hb_vmDo( 3 );
   }

   [d->tableView reloadData];

   /* Fire two-way sync */
   if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnPropChanged );
      hb_vmSend( 0 );
   }
}

/* Keep delegate alive */
static HBInspectorDelegate * s_delegate = nil;

/* ======================================================================
 * Build rows from Harbour property array
 * ====================================================================== */

static void InsBuildRows( INSDATA * d, PHB_ITEM pArray )
{
   HB_SIZE nLen, i;
   char szCats[16][32];
   int nCats = 0, j;
   BOOL bNew;

   d->nRows = 0;
   if( !pArray || hb_arrayLen(pArray) == 0 ) return;

   nLen = hb_arrayLen( pArray );

   /* Collect categories */
   for( i = 1; i <= nLen && nCats < 16; i++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
      const char * c = hb_arrayGetCPtr( pRow, 3 );
      bNew = YES;
      for( j = 0; j < nCats; j++ )
         if( strcasecmp(szCats[j], c) == 0 ) { bNew = NO; break; }
      if( bNew ) strncpy( szCats[nCats++], c, 31 );
   }

   /* Build rows grouped by category */
   for( j = 0; j < nCats && d->nRows < MAX_ROWS - 1; j++ )
   {
      /* Category header */
      strncpy( d->rows[d->nRows].szName, szCats[j], 31 );
      d->rows[d->nRows].szValue[0] = 0;
      strncpy( d->rows[d->nRows].szCategory, szCats[j], 31 );
      d->rows[d->nRows].cType = 0;
      d->rows[d->nRows].bIsCat = YES;
      d->rows[d->nRows].bCollapsed = NO;
      d->rows[d->nRows].bVisible = YES;
      d->nRows++;

      for( i = 1; i <= nLen && d->nRows < MAX_ROWS; i++ )
      {
         PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
         if( strcasecmp( hb_arrayGetCPtr(pRow,3), szCats[j] ) != 0 ) continue;

         strncpy( d->rows[d->nRows].szName, hb_arrayGetCPtr(pRow,1), 31 );
         strncpy( d->rows[d->nRows].szCategory, hb_arrayGetCPtr(pRow,3), 31 );
         d->rows[d->nRows].cType = hb_arrayGetCPtr(pRow,4)[0];
         d->rows[d->nRows].bIsCat = NO;
         d->rows[d->nRows].bCollapsed = NO;
         d->rows[d->nRows].bVisible = YES;

         if( d->rows[d->nRows].cType == 'S' )
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 255 );
         else if( d->rows[d->nRows].cType == 'N' )
            sprintf( d->rows[d->nRows].szValue, "%d", hb_arrayGetNI(pRow,2) );
         else if( d->rows[d->nRows].cType == 'L' )
            strcpy( d->rows[d->nRows].szValue, hb_arrayGetL(pRow,2) ? ".T." : ".F." );
         else if( d->rows[d->nRows].cType == 'C' )
            sprintf( d->rows[d->nRows].szValue, "%u", (unsigned) hb_arrayGetNInt(pRow,2) );
         else if( d->rows[d->nRows].cType == 'F' )
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 255 );

         d->nRows++;
      }
   }

   /* Build visible map */
   d->nVisible = 0;
   for( int k = 0; k < d->nRows; k++ )
   {
      if( d->rows[k].bVisible || d->rows[k].bIsCat )
         d->map[d->nVisible++] = k;
   }
}

/* ======================================================================
 * Build event rows from cached evRows data
 * ====================================================================== */

static void InsBuildEventRows( INSDATA * d )
{
   /* Nothing to do — evRows are pre-built by INS_SetEvents */
   (void)d;
}

/* Build evRows from Harbour event array { { "name", lAssigned, "category" }, ... } */
static void InsBuildEvRowsFromArray( INSDATA * d, PHB_ITEM pArray )
{
   d->nEvRows = 0;
   d->nEvVisible = 0;
   if( !pArray || hb_arrayLen(pArray) == 0 ) return;

   HB_SIZE nLen = hb_arrayLen( pArray );
   char szCats[16][32];
   int nCats = 0, j;

   /* Collect categories */
   for( HB_SIZE i = 1; i <= nLen && nCats < 16; i++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
      const char * c = hb_arrayGetCPtr( pRow, 3 );
      BOOL bNew = YES;
      for( j = 0; j < nCats; j++ )
         if( strcasecmp(szCats[j], c) == 0 ) { bNew = NO; break; }
      if( bNew ) strncpy( szCats[nCats++], c, 31 );
   }

   /* Build rows grouped by category */
   for( j = 0; j < nCats && d->nEvRows < MAX_ROWS - 1; j++ )
   {
      /* Category header */
      strncpy( d->evRows[d->nEvRows].szName, szCats[j], 31 );
      d->evRows[d->nEvRows].szValue[0] = 0;
      strncpy( d->evRows[d->nEvRows].szCategory, szCats[j], 31 );
      d->evRows[d->nEvRows].cType = 0;
      d->evRows[d->nEvRows].bIsCat = YES;
      d->evRows[d->nEvRows].bCollapsed = NO;
      d->evRows[d->nEvRows].bVisible = YES;
      d->nEvRows++;

      for( HB_SIZE i = 1; i <= nLen && d->nEvRows < MAX_ROWS; i++ )
      {
         PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
         if( strcasecmp( hb_arrayGetCPtr(pRow,3), szCats[j] ) != 0 ) continue;

         strncpy( d->evRows[d->nEvRows].szName, hb_arrayGetCPtr(pRow,1), 31 );
         strncpy( d->evRows[d->nEvRows].szCategory, hb_arrayGetCPtr(pRow,3), 31 );
         d->evRows[d->nEvRows].cType = 'E';  /* E = event */
         d->evRows[d->nEvRows].bIsCat = NO;
         d->evRows[d->nEvRows].bCollapsed = NO;
         d->evRows[d->nEvRows].bVisible = YES;

         BOOL assigned = hb_arrayGetL( pRow, 2 );
         strcpy( d->evRows[d->nEvRows].szValue, assigned ? "(Block)" : "" );

         d->nEvRows++;
      }
   }

   /* Build visible map */
   d->nEvVisible = 0;
   for( int k = 0; k < d->nEvRows; k++ )
   {
      if( d->evRows[k].bVisible || d->evRows[k].bIsCat )
         d->evMap[d->nEvVisible++] = k;
   }
}

/* Switch rows/map/nVisible based on current tab */
static void InsActivateTab( INSDATA * d )
{
   if( d->nTab == 1 )
   {
      /* Copy evRows into active rows for display */
      memcpy( d->rows, d->evRows, sizeof(d->evRows) );
      d->nRows = d->nEvRows;
      memcpy( d->map, d->evMap, sizeof(d->evMap) );
      d->nVisible = d->nEvVisible;
   }
   /* For tab 0, rows are already set by InsBuildRows */
}

/* Refresh the inspector table based on current tab */
static void InsRefreshTab( INSDATA * d )
{
   if( d->nTab == 0 )
   {
      /* Properties: re-fetch via dynamic symbol */
      PHB_DYNS pDyn = hb_dynsymFindName( "UI_GETALLPROPS" );
      if( pDyn && d->hCtrl != 0 )
      {
         hb_vmPushDynSym( pDyn ); hb_vmPushNil();
         hb_vmPushNumInt( d->hCtrl );
         hb_vmDo( 1 );
         PHB_ITEM pResult = hb_stackReturnItem();
         InsBuildRows( d, pResult );
      }
      else
      {
         d->nRows = 0; d->nVisible = 0;
      }
   }
   else
   {
      InsActivateTab( d );
   }
   [d->tableView reloadData];
}

/* ======================================================================
 * Global inspector data storage
 * ====================================================================== */

static HB_PTRUINT s_insData = 0;

HB_FUNC( _INSGETDATA ) { hb_retnint( s_insData ); }
HB_FUNC( _INSSETDATA ) { s_insData = (HB_PTRUINT) hb_parnint(1); }

/* ======================================================================
 * INS_Create() --> hInsData
 * ====================================================================== */

HB_FUNC( INS_CREATE )
{
   INSDATA * d = (INSDATA *) calloc( 1, sizeof(INSDATA) );

   d->font = [NSFont systemFontOfSize:12];
   d->boldFont = [NSFont boldSystemFontOfSize:12];

   /* Create window */
   NSRect frame = NSMakeRect( 100, 100, 320, 450 );
   d->window = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered
      defer:NO];
   [d->window setTitle:@"Inspector"];
   [d->window setReleasedWhenClosed:NO];
   if( [NSAppearance respondsToSelector:@selector(appearanceNamed:)] )
      [d->window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];

   /* Control selection combo at top */
   NSRect contentFrame = [[d->window contentView] bounds];
   CGFloat comboHeight = 28;
   CGFloat tabHeight = 24;
   d->combo = [[NSPopUpButton alloc] initWithFrame:
      NSMakeRect( 0, contentFrame.size.height - comboHeight, contentFrame.size.width, comboHeight )
      pullsDown:NO];
   [d->combo setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
   [d->combo setFont:[NSFont systemFontOfSize:11]];
   [[d->window contentView] addSubview:d->combo];

   /* Properties / Events tab selector (below combo) */
   d->nTab = 0;
   d->tabCtrl = [NSSegmentedControl segmentedControlWithLabels:@[@"Properties", @"Events"]
      trackingMode:NSSegmentSwitchTrackingSelectOne
      target:nil action:nil];
   [d->tabCtrl setSegmentCount:2];
   [d->tabCtrl setSelectedSegment:0];
   [d->tabCtrl setFrame:NSMakeRect( 4, contentFrame.size.height - comboHeight - tabHeight - 2,
      contentFrame.size.width - 8, tabHeight )];
   [d->tabCtrl setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
   [d->tabCtrl setFont:[NSFont systemFontOfSize:11]];
   [[d->window contentView] addSubview:d->tabCtrl];

   /* Scroll view + table view (below tabs) */
   NSRect tableFrame = NSMakeRect( 0, 0, contentFrame.size.width,
      contentFrame.size.height - comboHeight - tabHeight - 4 );
   d->scrollView = [[NSScrollView alloc] initWithFrame:tableFrame];
   [d->scrollView setHasVerticalScroller:YES];
   [d->scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

   d->tableView = [[NSTableView alloc] initWithFrame:contentFrame];
   [d->tableView setRowHeight:20];

   /* Name column */
   NSTableColumn * nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
   [nameCol setWidth:140];
   [[nameCol headerCell] setStringValue:@"Property"];
   [nameCol setEditable:NO];
   [d->tableView addTableColumn:nameCol];

   /* Value column */
   NSTableColumn * valCol = [[NSTableColumn alloc] initWithIdentifier:@"value"];
   [valCol setWidth:130];
   [[valCol headerCell] setStringValue:@"Value"];
   [valCol setEditable:YES];
   [d->tableView addTableColumn:valCol];

   /* Button column "..." for color/font pickers */
   NSTableColumn * btnCol = [[NSTableColumn alloc] initWithIdentifier:@"button"];
   [btnCol setWidth:28];
   [btnCol setMinWidth:28];
   [btnCol setMaxWidth:28];
   [[btnCol headerCell] setStringValue:@""];
   [btnCol setEditable:NO];
   {
      NSButtonCell * bc = [[NSButtonCell alloc] init];
      [bc setButtonType:NSButtonTypeMomentaryPushIn];
      [bc setBezelStyle:NSBezelStyleSmallSquare];
      [bc setTitle:@""];
      [bc setFont:[NSFont systemFontOfSize:10]];
      [btnCol setDataCell:bc];
   }
   [d->tableView addTableColumn:btnCol];

   /* Delegate */
   s_delegate = [[HBInspectorDelegate alloc] init];
   s_delegate->d = d;
   [d->tableView setDataSource:s_delegate];
   [d->tableView setDelegate:s_delegate];

   /* Single-click action for "..." button column */
   [d->tableView setTarget:s_delegate];
   [d->tableView setAction:@selector(tableViewClicked:)];
   [d->tableView setDoubleAction:@selector(tableViewDoubleClicked:)];

   [d->scrollView setDocumentView:d->tableView];
   [[d->window contentView] addSubview:d->scrollView];

   /* Wire combo action to delegate */
   [d->combo setTarget:s_delegate];
   [d->combo setAction:@selector(comboSelChanged:)];

   /* Wire tab control to delegate */
   [d->tabCtrl setTarget:s_delegate];
   [d->tabCtrl setAction:@selector(tabChanged:)];

   [d->window orderFront:nil];

   hb_retnint( (HB_PTRUINT) d );
}

/* ======================================================================
 * INS_RefreshWithData( hInsData, hCtrl, aProps )
 * ====================================================================== */

HB_FUNC( INS_REFRESHWITHDATA )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pArray = hb_param(3, HB_IT_ARRAY);

   if( !d ) return;

   d->hCtrl = (HB_PTRUINT) hb_parnint(2);

   if( d->hCtrl == 0 || !pArray || hb_arrayLen(pArray) == 0 )
   {
      d->nRows = 0;
      d->nVisible = 0;
      [d->tableView reloadData];
      [d->window setTitle:@"Inspector"];
      return;
   }

   /* Title from first prop (ClassName) */
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, 1 );
      const char * cls = hb_arrayGetCPtr( pRow, 2 );
      [d->window setTitle:[NSString stringWithFormat:@"Inspector: %s", cls ? cls : ""]];
   }

   /* Always build property rows from the passed array */
   InsBuildRows( d, pArray );

   /* If Events tab is active, switch to cached event rows */
   if( d->nTab == 1 )
      InsActivateTab( d );

   [d->tableView reloadData];
}

/* ======================================================================
 * INS_BringToFront( hInsData )
 * ====================================================================== */

HB_FUNC( INS_BRINGTOFRONT )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d && d->window )
      [d->window orderFront:nil];
}

/* ======================================================================
 * INS_Destroy( hInsData )
 * ====================================================================== */

HB_FUNC( INS_DESTROY )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   if( d->pOnComboSel ) { hb_itemRelease( d->pOnComboSel ); d->pOnComboSel = NULL; }
   if( d->pOnEventDblClick ) { hb_itemRelease( d->pOnEventDblClick ); d->pOnEventDblClick = NULL; }
   if( d->pOnPropChanged ) { hb_itemRelease( d->pOnPropChanged ); d->pOnPropChanged = NULL; }
   if( d->window ) [d->window close];
   free( d );
}

/* ======================================================================
 * INS_SetFormCtrl( hInsData, hForm )
 * ====================================================================== */

HB_FUNC( INS_SETFORMCTRL )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d ) d->hFormCtrl = (HB_PTRUINT) hb_parnint(2);
}

/* ======================================================================
 * INS_SetOnComboSel( hInsData, bBlock )
 * ====================================================================== */

HB_FUNC( INS_SETONCOMBOSEL )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnComboSel ) hb_itemRelease( d->pOnComboSel );
      d->pOnComboSel = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* ======================================================================
 * INS_ComboAdd( hInsData, cText )
 * ====================================================================== */

HB_FUNC( INS_COMBOADD )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d && d->combo && HB_ISCHAR(2) )
      [d->combo addItemWithTitle:[NSString stringWithUTF8String:hb_parc(2)]];
}

/* ======================================================================
 * INS_ComboSelect( hInsData, nIndex )
 * ====================================================================== */

HB_FUNC( INS_COMBOSELECT )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   int idx = hb_parni(2);
   if( d && d->combo && idx >= 0 && idx < (int)[d->combo numberOfItems] )
      [d->combo selectItemAtIndex:idx];
}

/* ======================================================================
 * INS_ComboClear( hInsData )
 * ====================================================================== */

HB_FUNC( INS_COMBOCLEAR )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d && d->combo )
      [d->combo removeAllItems];
}

/* ======================================================================
 * INS_SetPos( hInsData, nLeft, nTop, nWidth, nHeight )
 * ====================================================================== */

HB_FUNC( INS_SETPOS )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d || !d->window ) return;

   int nLeft   = hb_parni(2);
   int nTop    = hb_parni(3);
   int nWidth  = hb_parni(4);
   int nHeight = hb_parni(5);

   /* macOS uses bottom-left origin, flip Y */
   NSRect screenFrame = [[NSScreen mainScreen] frame];
   NSRect frame = NSMakeRect( nLeft,
      screenFrame.size.height - nTop - nHeight,
      nWidth, nHeight );
   [d->window setFrame:frame display:YES];
}

/* ======================================================================
 * INS_SetEvents( hInsData, aEvents )
 * Store event data so the Events tab can display it
 * ====================================================================== */

HB_FUNC( INS_SETEVENTS )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pArray = hb_param(2, HB_IT_ARRAY);
   if( !d ) return;

   InsBuildEvRowsFromArray( d, pArray );

   /* If Events tab is active, refresh display */
   if( d->nTab == 1 )
   {
      InsActivateTab( d );
      [d->tableView reloadData];
   }
}

/* ======================================================================
 * INS_SetOnEventDblClick( hInsData, bBlock )
 * Set callback for double-click on event row
 * Block receives ( hCtrl, cEventName ) and returns cHandlerName
 * ====================================================================== */

HB_FUNC( INS_SETONEVENTDBLCLICK )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnEventDblClick ) hb_itemRelease( d->pOnEventDblClick );
      d->pOnEventDblClick = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* INS_SetOnPropChanged( hInsData, bBlock )
 * Called after any property is edited in the inspector (two-way sync) */
HB_FUNC( INS_SETONPROPCHANGED )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnPropChanged ) hb_itemRelease( d->pOnPropChanged );
      d->pOnPropChanged = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}
