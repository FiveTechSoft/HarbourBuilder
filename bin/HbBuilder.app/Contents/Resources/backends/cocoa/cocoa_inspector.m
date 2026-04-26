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
   int          nBrowseCol;  /* >=0 when inspecting a browse column, -1 otherwise */
   int          nFolderPage; /* >=0 when inspecting a folder page, -1 otherwise */
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
   char         szClassName[64]; /* class name of currently inspected control */
   /* Debug mode */
   BOOL         bDebugMode;
   IROW         dbgLocalsRows[MAX_ROWS];
   int          nDbgLocalsRows;
   int          dbgLocalsMap[MAX_ROWS];
   int          nDbgLocalsVisible;
   IROW         dbgStackRows[MAX_ROWS];
   int          nDbgStackRows;
   int          dbgStackMap[MAX_ROWS];
   int          nDbgStackVisible;
} INSDATA;

/* Forward declarations */
static void InsBuildRows( INSDATA * d, PHB_ITEM pArray );
static void InsPopulateEvents( INSDATA * d );
static void InsActivateTab( INSDATA * d );
static void InsRefreshTab( INSDATA * d );
static void OpenMenuEditor( INSDATA * ins, int nReal );

/* ======================================================================
 * Menu Items Editor
 * ====================================================================== */

#define MEI_MAX 128

typedef struct {
   char  szCaption[128];
   char  szShortcut[32];
   char  szHandler[128];
   int   bSeparator;
   int   bEnabled;
   int   nLevel;
   int   nParent;
} MEINode;

typedef struct {
   MEINode nodes[MEI_MAX];
   int     nCount;
   int     nSel;
} MEIDATA;

static void MEI_Serialize( MEIDATA * d, char * out, int outLen )
{
   int pos=0; out[0]=0;
   for(int i=0;i<d->nCount&&pos<outLen-64;i++) {
      if(i>0) out[pos++]='|';
      const char * cap=d->nodes[i].bSeparator?"---":d->nodes[i].szCaption;
      int n=snprintf(out+pos,outLen-pos,"%s\x01%s\x01%s\x01%d\x01%d\x01%d",
         cap,d->nodes[i].szShortcut,d->nodes[i].szHandler,
         d->nodes[i].bEnabled,d->nodes[i].nLevel,d->nodes[i].nParent);
      if(n>0) pos+=n;
   }
}

static void MEI_Parse( MEIDATA * d, const char * raw )
{
   d->nCount=0;
   if(!raw||!raw[0]) return;
   while(*raw&&d->nCount<MEI_MAX) {
      const char * pipe=strchr(raw,'|');
      int tl=pipe?(int)(pipe-raw):(int)strlen(raw);
      if(tl>511) tl=511;
      char tok[512]; memcpy(tok,raw,tl); tok[tl]=0;
      int fi=d->nCount;
      char*f0=tok;
      char*f1=strchr(f0,'\x01'); if(f1){*f1++=0;}else f1=(char*)"";
      char*f2=f1[0]?strchr(f1,'\x01'):NULL; if(f2){*f2++=0;}else f2=(char*)"";
      char*f3=f2?strchr(f2,'\x01'):NULL; if(f3){*f3++=0;}else f3=(char*)"";
      char*f4=f3?strchr(f3,'\x01'):NULL; if(f4){*f4++=0;}else f4=(char*)"";
      char*f5=f4?strchr(f4,'\x01'):NULL; if(f5){*f5++=0;}else f5=(char*)"-1";
      d->nodes[fi].bSeparator=(strcmp(f0,"---")==0);
      strncpy(d->nodes[fi].szCaption,d->nodes[fi].bSeparator?"":f0,127);
      strncpy(d->nodes[fi].szShortcut,f1,31);
      strncpy(d->nodes[fi].szHandler,f2,127);
      d->nodes[fi].bEnabled=f3[0]?atoi(f3):1;
      d->nodes[fi].nLevel=f4[0]?atoi(f4):0;
      d->nodes[fi].nParent=f5[0]?atoi(f5):-1;
      d->nCount++;
      if(!pipe) break;
      raw=pipe+1;
   }
}

static void mei_add_node( MEIDATA * d, NSTableView * tv, int nLevel, int bSep )
{
   if(d->nCount>=MEI_MAX) return;
   int insPos=(d->nSel>=0)?d->nSel+1:d->nCount;
   for(int i=d->nCount;i>insPos;i--) d->nodes[i]=d->nodes[i-1];
   int nPar=-1;
   if(nLevel>0)
      for(int i=insPos-1;i>=0;i--)
         if(d->nodes[i].nLevel==nLevel-1&&!d->nodes[i].bSeparator){nPar=i;break;}
   memset(&d->nodes[insPos],0,sizeof(MEINode));
   if(!bSep) strcpy(d->nodes[insPos].szCaption,"NewItem");
   d->nodes[insPos].bSeparator=bSep;
   d->nodes[insPos].bEnabled=bSep?0:1;
   d->nodes[insPos].nLevel=nLevel;
   d->nodes[insPos].nParent=nPar;
   d->nCount++;
   for(int i=insPos+1;i<d->nCount;i++)
      if(d->nodes[i].nParent>=insPos) d->nodes[i].nParent++;
   d->nSel=insPos;
   [tv reloadData];
   [tv selectRowIndexes:[NSIndexSet indexSetWithIndex:insPos] byExtendingSelection:NO];
   [tv scrollRowToVisible:insPos];
}

@interface HBMenuEditorCtrl : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
@public
   MEIDATA *    mei;
   NSTableView * tableView;
   NSTextField * captionField;
   NSTextField * shortcutField;
   NSTextField * handlerField;
   NSButton *   enabledCheck;
   NSWindow *   win;
   BOOL         bUpdating;
   BOOL         bOK;
   BOOL         bPopupMode;  /* CT_POPUPMENU: top-level items at level 0 (no
                                outer popup wrapping like TMainMenu has). */
}
- (void)syncFieldsToNode;
@end

@implementation HBMenuEditorCtrl

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv { (void)tv; return mei?mei->nCount:0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row
{
   (void)tv;
   if(!mei||row<0||row>=mei->nCount) return @"";
   MEINode * n=&mei->nodes[row];
   if([[col identifier] isEqualToString:@"cap"]) {
      if(n->bSeparator) return @"──────";
      NSMutableString * s=[NSMutableString string];
      for(int ii=0;ii<n->nLevel;ii++) [s appendString:@"  "];
      [s appendString:[NSString stringWithUTF8String:n->szCaption]];
      return s;
   }
   if([[col identifier] isEqualToString:@"scut"])
      return [NSString stringWithUTF8String:n->szShortcut];
   return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notif
{
   (void)notif;
   if(bUpdating) return;
   NSInteger row=[tableView selectedRow];
   if(row<0||!mei||row>=mei->nCount) { mei->nSel=-1; return; }
   mei->nSel=(int)row;
   [self syncFieldsToNode];
}

- (void)syncFieldsToNode
{
   if(mei->nSel<0||mei->nSel>=mei->nCount) return;
   MEINode * n=&mei->nodes[mei->nSel];
   bUpdating=YES;
   [captionField  setStringValue:[NSString stringWithUTF8String:n->bSeparator?"":n->szCaption]];
   [shortcutField setStringValue:[NSString stringWithUTF8String:n->szShortcut]];
   [handlerField  setStringValue:[NSString stringWithUTF8String:n->szHandler]];
   [enabledCheck  setState:n->bEnabled?NSControlStateValueOn:NSControlStateValueOff];
   [captionField  setEnabled:!n->bSeparator];
   [shortcutField setEnabled:!n->bSeparator];
   [handlerField  setEnabled:!n->bSeparator];
   bUpdating=NO;
}

- (void)captionChanged:(id)f  { if(!bUpdating&&mei->nSel>=0) {
   strncpy(mei->nodes[mei->nSel].szCaption,[[f stringValue] UTF8String],127);
   int s=mei->nSel; bUpdating=YES; [tableView reloadData];
   [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:s] byExtendingSelection:NO];
   bUpdating=NO; } }
- (void)shortcutChanged:(id)f { if(!bUpdating&&mei->nSel>=0)
   strncpy(mei->nodes[mei->nSel].szShortcut,[[f stringValue] UTF8String],31); }
- (void)handlerChanged:(id)f  { if(!bUpdating&&mei->nSel>=0)
   strncpy(mei->nodes[mei->nSel].szHandler,[[f stringValue] UTF8String],127); }
- (void)enabledToggled:(id)b  { if(!bUpdating&&mei->nSel>=0)
   mei->nodes[mei->nSel].bEnabled=([b state]==NSControlStateValueOn)?1:0; }

- (void)addPopup:(id)s  { (void)s; mei_add_node(mei,tableView,0,0); [self syncFieldsToNode]; }
- (void)addItem:(id)s   { (void)s;
   mei_add_node(mei,tableView,bPopupMode?0:1,0); [self syncFieldsToNode]; }
- (void)addSubItem:(id)s{ (void)s;
   mei_add_node(mei,tableView,bPopupMode?1:2,0); [self syncFieldsToNode]; }
- (void)addSep:(id)s    { (void)s;
   int lv=(mei->nSel>=0)?mei->nodes[mei->nSel].nLevel:(bPopupMode?0:1);
   mei_add_node(mei,tableView,lv,1); [self syncFieldsToNode]; }

- (void)moveUp:(id)s    { (void)s;
   if(mei->nSel<=0) return;
   MEINode tmp=mei->nodes[mei->nSel]; mei->nodes[mei->nSel]=mei->nodes[mei->nSel-1]; mei->nodes[mei->nSel-1]=tmp;
   mei->nSel--;
   [tableView reloadData];
   [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:mei->nSel] byExtendingSelection:NO]; }

- (void)moveDown:(id)s  { (void)s;
   if(mei->nSel<0||mei->nSel>=mei->nCount-1) return;
   MEINode tmp=mei->nodes[mei->nSel]; mei->nodes[mei->nSel]=mei->nodes[mei->nSel+1]; mei->nodes[mei->nSel+1]=tmp;
   mei->nSel++;
   [tableView reloadData];
   [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:mei->nSel] byExtendingSelection:NO]; }

- (void)deleteNode:(id)s { (void)s;
   if(mei->nSel<0||mei->nCount==0) return;
   int del=mei->nSel;
   for(int i=del;i<mei->nCount-1;i++) mei->nodes[i]=mei->nodes[i+1];
   mei->nCount--;
   mei->nSel=del<mei->nCount?del:mei->nCount-1;
   [tableView reloadData];
   if(mei->nSel>=0)
      [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:mei->nSel] byExtendingSelection:NO];
   [self syncFieldsToNode]; }

- (void)clickOK:(id)s     { (void)s; bOK=YES; [NSApp stopModal]; }
- (void)clickCancel:(id)s { (void)s; bOK=NO;  [NSApp stopModal]; }

@end

static void OpenMenuEditor( INSDATA * ins, int nReal )
{
   /* Fetch full serial from HBControl (szValue in IROW is too small for menus) */
   char fullSerial[4096]="";
   {
      PHB_DYNS pDyn=hb_dynsymFindName("UI_GETPROP");
      if(pDyn) {
         hb_vmPushDynSym(pDyn); hb_vmPushNil();
         hb_vmPushNumInt(ins->hCtrl);
         hb_vmPushString("aMenuItems",10);
         hb_vmDo(2);
         const char * res=hb_parc(-1);
         if(res) strncpy(fullSerial,res,sizeof(fullSerial)-1);
      }
   }

   MEIDATA * d=(MEIDATA *)calloc(1,sizeof(MEIDATA));
   d->nSel=-1;
   MEI_Parse(d,fullSerial);

   /* Build editor window */
   NSWindow * win=[[NSWindow alloc]
      initWithContentRect:NSMakeRect(0,0,700,460)
      styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable
      backing:NSBackingStoreBuffered defer:NO];
   [win setTitle:@"Menu Items Editor"];
   NSView * cv=[win contentView];

   /* Detect CT_POPUPMENU (201) so toolbar buttons add items at the levels
    * the popup builder expects (top-level items at level 0). */
   int nCtrlType = 0;
   {
      PHB_DYNS pDynT = hb_dynsymFindName("UI_GETTYPE");
      if( pDynT ) {
         hb_vmPushDynSym(pDynT); hb_vmPushNil();
         hb_vmPushNumInt(ins->hCtrl);
         hb_vmDo(1);
         nCtrlType = hb_parni(-1);
      }
   }

   HBMenuEditorCtrl * ctrl=[[HBMenuEditorCtrl alloc] init];
   ctrl->mei=d; ctrl->win=win; ctrl->bOK=NO; ctrl->bUpdating=NO;
   ctrl->bPopupMode = (nCtrlType == 201);  /* CT_POPUPMENU */

   /* Toolbar */
   NSArray * btnLabels=@[@"+Popup",@"+Item",@"+SubItem",@"+Sep",@"↑",@"↓",@"✕"];
   SEL btnSels[]={@selector(addPopup:),@selector(addItem:),@selector(addSubItem:),
                  @selector(addSep:),@selector(moveUp:),@selector(moveDown:),@selector(deleteNode:)};
   CGFloat bx=8, ty=426;
   for(NSUInteger bi=0;bi<7;bi++) {
      NSButton * b=[[NSButton alloc] initWithFrame:NSMakeRect(bx,ty,65,25)];
      [b setTitle:btnLabels[bi]]; [b setBezelStyle:NSBezelStyleRounded];
      [b setTarget:ctrl]; [b setAction:btnSels[bi]];
      [cv addSubview:b]; bx+=70;
   }

   /* Left: table */
   NSScrollView * sw=[[NSScrollView alloc] initWithFrame:NSMakeRect(8,55,390,360)];
   [sw setHasVerticalScroller:YES]; [sw setAutohidesScrollers:YES];
   NSTableView * tv=[[NSTableView alloc] init];
   [tv setDataSource:ctrl]; [tv setDelegate:ctrl];
   [tv setUsesAlternatingRowBackgroundColors:YES];
   NSTableColumn * c0=[[NSTableColumn alloc] initWithIdentifier:@"cap"];
   [c0 setTitle:@"Caption"]; [c0 setWidth:230]; [c0 setResizingMask:NSTableColumnAutoresizingMask];
   NSTableColumn * c1=[[NSTableColumn alloc] initWithIdentifier:@"scut"];
   [c1 setTitle:@"Shortcut"]; [c1 setWidth:130];
   [tv addTableColumn:c0]; [tv addTableColumn:c1];
   [sw setDocumentView:tv]; [cv addSubview:sw];
   ctrl->tableView=tv;

   /* Right: form */
   CGFloat rx=410;
   NSTextField * lbCap=[NSTextField labelWithString:@"Caption:"];
   NSTextField * lbScut=[NSTextField labelWithString:@"Shortcut:"];
   NSTextField * lbHndl=[NSTextField labelWithString:@"OnClick:"];
   [lbCap  setFrame:NSMakeRect(rx,375,70,22)]; [cv addSubview:lbCap];
   [lbScut setFrame:NSMakeRect(rx,345,70,22)]; [cv addSubview:lbScut];
   [lbHndl setFrame:NSMakeRect(rx,315,70,22)]; [cv addSubview:lbHndl];

   NSTextField * efCap =[[NSTextField alloc] initWithFrame:NSMakeRect(rx+75,375,200,22)];
   NSTextField * efScut=[[NSTextField alloc] initWithFrame:NSMakeRect(rx+75,345,200,22)];
   NSTextField * efHndl=[[NSTextField alloc] initWithFrame:NSMakeRect(rx+75,315,200,22)];
   NSButton   * cbEn  =[[NSButton alloc] initWithFrame:NSMakeRect(rx+75,288,140,22)];
   [cbEn setButtonType:NSButtonTypeSwitch]; [cbEn setTitle:@"Enabled"];
   [cv addSubview:efCap]; [cv addSubview:efScut];
   [cv addSubview:efHndl]; [cv addSubview:cbEn];
   ctrl->captionField=efCap; ctrl->shortcutField=efScut;
   ctrl->handlerField=efHndl; ctrl->enabledCheck=cbEn;
   [efCap  setTarget:ctrl]; [efCap  setAction:@selector(captionChanged:)];
   [efScut setTarget:ctrl]; [efScut setAction:@selector(shortcutChanged:)];
   [efHndl setTarget:ctrl]; [efHndl setAction:@selector(handlerChanged:)];
   [cbEn   setTarget:ctrl]; [cbEn   setAction:@selector(enabledToggled:)];

   /* OK / Cancel */
   NSButton * btnOK=[[NSButton alloc] initWithFrame:NSMakeRect(600,8,90,30)];
   NSButton * btnCl=[[NSButton alloc] initWithFrame:NSMakeRect(500,8,90,30)];
   [btnOK setTitle:@"OK"]; [btnOK setBezelStyle:NSBezelStyleRounded];
   [btnOK setKeyEquivalent:@"\r"];
   [btnCl setTitle:@"Cancel"]; [btnCl setBezelStyle:NSBezelStyleRounded];
   [btnCl setKeyEquivalent:@"\033"];
   [btnOK setTarget:ctrl]; [btnOK setAction:@selector(clickOK:)];
   [btnCl setTarget:ctrl]; [btnCl setAction:@selector(clickCancel:)];
   [cv addSubview:btnOK]; [cv addSubview:btnCl];

   [win center];
   [NSApp runModalForWindow:win];
   [win orderOut:nil];

   if(ctrl->bOK) {
      char result[4096]="";
      MEI_Serialize(d,result,sizeof(result));
      /* Apply via UI_SetProp directly (IROW.szValue is too small for menus) */
      PHB_DYNS pDyn=hb_dynsymFindName("UI_SETPROP");
      if(pDyn) {
         hb_vmPushDynSym(pDyn); hb_vmPushNil();
         hb_vmPushNumInt(ins->hCtrl);
         hb_vmPushString("aMenuItems",10);
         hb_vmPushString(result,(HB_SIZE)strlen(result));
         hb_vmDo(3);
      }
      /* Update display in IROW */
      int nNodes=d->nCount;
      snprintf(ins->rows[nReal].szValue,sizeof(ins->rows[0].szValue),"(%d nodes)",nNodes);
      /* Trigger two-way sync */
      if(ins->pOnPropChanged && HB_IS_BLOCK(ins->pOnPropChanged)) {
         hb_vmPushEvalSym(); hb_vmPush(ins->pOnPropChanged); hb_vmSend(0);
      }
      /* Reload inspector display */
      InsRefreshTab(ins);
   }
   free(d);
}

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
- (void)colorPanelChanged:(NSNotification *)note;
@end

@implementation HBFontPickerTarget

- (void)changeFont:(id)sender
{
   NSFontManager * fm = [NSFontManager sharedFontManager];
   NSFont * font = [fm convertFont:[NSFont systemFontOfSize:12]];
   InsApplyFont( d, nReal, font );
}

- (void)colorPanelChanged:(NSNotification *)note
{
   NSColorPanel * cp = [note object];
   NSColor * color = [cp color];
   if( !color ) return;
   color = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
   if( !color ) return;

   unsigned int r = (unsigned int)([color redComponent] * 255.0);
   unsigned int g = (unsigned int)([color greenComponent] * 255.0);
   unsigned int b = (unsigned int)([color blueComponent] * 255.0);
   unsigned int bgr = r | (g << 8) | (b << 16);

   /* Apply color via UI_SetProp("nClrText") — updates FClrText and live view */
   PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
   if( pDyn )
   {
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( "nClrText", 8 );
      hb_vmPushNumInt( (HB_MAXINT)bgr );
      hb_vmDo( 3 );
   }

   /* Update the oFont row display to include color hex */
   if( nReal >= 0 && nReal < d->nRows && d->rows[nReal].cType == 'F' )
   {
      char * val = d->rows[nReal].szValue;
      const char * c1 = strchr(val, ',');
      if( c1 ) {
         const char * c2 = strchr(c1 + 1, ',');
         char tmp[128];
         int baseLen = c2 ? (int)(c2 - val) : (int)strlen(val);
         if( baseLen > 127 ) baseLen = 127;
         memcpy(tmp, val, baseLen); tmp[baseLen] = 0;
         snprintf(d->rows[nReal].szValue, sizeof(d->rows[0].szValue), "%s,%02X%02X%02X", tmp, r, g, b);
      }
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

@interface HBInspectorDelegate : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
{
@public
   INSDATA * d;
}
@end

@implementation HBInspectorDelegate

- (void)windowDidBecomeKey:(NSNotification *)notification
{
   /* When inspector comes to front, bring all IDE windows to front */
   for( NSWindow * w in [NSApp windows] )
   {
      if( [w isVisible] && ![w isMiniaturized] )
         [w orderFront:nil];
   }
   /* Re-focus the inspector itself */
   [notification.object makeKeyAndOrderFront:nil];
}

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
      if( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' || d->rows[nReal].cType == 'P' || d->rows[nReal].cType == 'S' || d->rows[nReal].cType == 'M' ) return @"...";
      return @"";
   }
   else
   {
      if( d->rows[nReal].bIsCat ) return @"";

      /* Dropdown: parse "index|opt0|opt1|..." and show selected option name */
      if( d->rows[nReal].cType == 'D' )
      {
         const char * raw = d->rows[nReal].szValue;
         int idx = atoi( raw );
         const char * p = strchr( raw, '|' );
         int cur = 0;
         while( p && *p == '|' ) {
            p++;
            const char * end = strchr( p, '|' );
            if( cur == idx ) {
               int len = end ? (int)(end - p) : (int)strlen(p);
               return [[NSString alloc] initWithBytes:p length:len encoding:NSUTF8StringEncoding];
            }
            cur++;
            p = end;
         }
         return [NSString stringWithFormat:@"%d", idx];
      }

      /* Array: show element count */
      if( d->rows[nReal].cType == 'A' )
      {
         const char * raw = d->rows[nReal].szValue;
         if( !raw || !raw[0] ) return @"(0 items)";
         int count = 1;
         for( const char * p = raw; *p; p++ )
            if( *p == '|' ) count++;
         return [NSString stringWithFormat:@"(%d items)", count];
      }

      /* Menu: szValue already holds "(N nodes)" set by InsBuildRows */
      if( d->rows[nReal].cType == 'M' )
         return [NSString stringWithUTF8String:d->rows[nReal].szValue];

      /* Logical: show Yes/No instead of .T./.F. */
      if( d->rows[nReal].cType == 'L' )
         return ( strcasecmp( d->rows[nReal].szValue, ".T." ) == 0 ) ? @"Yes" : @"No";

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

   /* === Property validation === */
   const char * propName = d->rows[nReal].szName;

   /* cName: must not be empty */
   if( strcmp(propName, "cName") == 0 && ( !szVal || strlen(szVal) == 0 ) )
   {
      NSBeep(); return;
   }

   /* Numeric properties: must be valid integer */
   if( d->rows[nReal].cType == 'N' )
   {
      /* Allow empty (treated as 0) */
      if( szVal && strlen(szVal) > 0 )
      {
         char * endp = NULL;
         long val = strtol( szVal, &endp, 10 );
         if( endp == szVal || *endp != 0 ) { NSBeep(); return; }  /* Not a number */

         /* Range checks for specific properties */
         if( strcmp(propName,"nWidth")==0 || strcmp(propName,"nHeight")==0 )
         { if( val < 1 || val > 10000 ) { NSBeep(); return; } }
         else if( strcmp(propName,"nAlphaBlendValue")==0 )
         { if( val < 0 || val > 255 ) { NSBeep(); return; } }
         else if( strcmp(propName,"nLeft")==0 || strcmp(propName,"nTop")==0 )
         { if( val < -5000 || val > 10000 ) { NSBeep(); return; } }
      }
   }

   /* Logical: must be .T. or .F. */
   if( d->rows[nReal].cType == 'L' )
   {
      if( strcasecmp(szVal,".T.") != 0 && strcasecmp(szVal,".F.") != 0 &&
          strcasecmp(szVal,"true") != 0 && strcasecmp(szVal,"false") != 0 )
      { NSBeep(); return; }
   }

   strncpy( d->rows[nReal].szValue, szVal, sizeof(d->rows[0].szValue) - 1 );

   if( d->nBrowseCol >= 0 )
   {
      /* Apply value via UI_BrowseSetColProp for column properties */
      PHB_DYNS pDyn = hb_dynsymFindName( "UI_BROWSESETCOLPROP" );
      if( pDyn )
      {
         hb_vmPushDynSym( pDyn ); hb_vmPushNil();
         hb_vmPushNumInt( d->hCtrl );
         hb_vmPushInteger( d->nBrowseCol );
         hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );

         if( d->rows[nReal].cType == 'S' || d->rows[nReal].cType == 'F' )
            hb_vmPushString( szVal, strlen(szVal) );
         else if( d->rows[nReal].cType == 'N' )
            hb_vmPushInteger( atoi(szVal) );
         else if( d->rows[nReal].cType == 'D' )
            hb_vmPushInteger( atoi(szVal) );
         else
            hb_vmPushNil();

         hb_vmDo( 4 );
      }
   }
   else
   {
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
   /* For logical properties, show Yes/No dropdown */
   if( d->rows[nReal].cType == 'L' && [[col identifier] isEqualToString:@"value"] )
   {
      [self openLogicalDropdownForRow:nReal inTableView:tableView atRow:row];
      return NO;
   }
   /* For dropdown properties, show popup menu */
   if( d->rows[nReal].cType == 'D' && [[col identifier] isEqualToString:@"value"] )
   {
      [self openDropdownForRow:nReal inTableView:tableView atRow:row];
      return NO;
   }
   /* For path/file properties, open file picker */
   if( d->rows[nReal].cType == 'P' && [[col identifier] isEqualToString:@"value"] )
   {
      [self openFilePickerForRow:nReal];
      return NO;
   }
   /* For array properties, open array editor */
   if( d->rows[nReal].cType == 'A' && [[col identifier] isEqualToString:@"value"] )
   {
      [self openArrayEditorForRow:nReal];
      return NO;
   }
   /* For menu properties, open menu items editor */
   if( d->rows[nReal].cType == 'M' && [[col identifier] isEqualToString:@"value"] )
   {
      OpenMenuEditor( d, nReal );
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

   /* Listen for color changes from the font panel's embedded color picker */
   [[NSNotificationCenter defaultCenter] removeObserver:s_fontTarget
      name:NSColorPanelColorDidChangeNotification object:nil];
   [[NSNotificationCenter defaultCenter] addObserver:s_fontTarget
      selector:@selector(colorPanelChanged:)
      name:NSColorPanelColorDidChangeNotification object:nil];

   [panel orderFront:nil];
}

- (void)openFilePickerForRow:(int)nReal
{
   NSOpenPanel * panel = [NSOpenPanel openPanel];
   [panel setCanChooseFiles:YES];
   [panel setCanChooseDirectories:NO];
   [panel setAllowsMultipleSelection:NO];
   [panel setTitle:@"Select File"];

   /* Set allowed file types based on property name */
   if( strcmp( d->rows[nReal].szName, "cFileName" ) == 0 )
   {
      if( strcasecmp( d->szClassName, "TDBFTable" ) == 0 ||
          strcasecmp( d->szClassName, "TDbfTable" ) == 0 ) {
         [panel setAllowedFileTypes:@[@"dbf"]];
         [panel setTitle:@"Select DBF File"];
      } else {
         [panel setAllowedFileTypes:nil];
         [panel setTitle:@"Select File"];
      }
   }
   else if( strcmp( d->rows[nReal].szName, "cPicture" ) == 0 )
   {
      [panel setAllowedFileTypes:@[@"png",@"jpg",@"jpeg",@"gif",@"bmp",@"tiff",@"tif",@"icns"]];
      [panel setTitle:@"Select Image File"];
   }
   else if( strcmp( d->rows[nReal].szName, "cSceneFile" ) == 0 )
   {
      [panel setAllowedFileTypes:@[@"scn",@"dae",@"usdz",@"usd",@"obj"]];
      [panel setTitle:@"Select 3D Scene File"];
   }

   /* Set initial directory from current value */
   const char * curVal = d->rows[nReal].szValue;
   if( curVal && strlen(curVal) > 0 )
   {
      NSString * curPath = [NSString stringWithUTF8String:curVal];
      NSString * dir = [curPath stringByDeletingLastPathComponent];
      if( [[NSFileManager defaultManager] fileExistsAtPath:dir] )
         [panel setDirectoryURL:[NSURL fileURLWithPath:dir]];
   }

   [panel beginSheetModalForWindow:d->window completionHandler:^(NSModalResponse result) {
      if( result == NSModalResponseOK )
      {
         NSString * path = [[panel URL] path];
         const char * szPath = [path UTF8String];
         strncpy( d->rows[nReal].szValue, szPath, sizeof(d->rows[nReal].szValue) - 1 );
         d->rows[nReal].szValue[sizeof(d->rows[nReal].szValue) - 1] = '\0';

         /* Push value to the control */
         if( d->hCtrl )
         {
            hb_vmPushDynSym( hb_dynsymFind( "UI_SETPROP" ) );
            hb_vmPushNil();
            hb_vmPushNumInt( (HB_MAXINT) d->hCtrl );
            hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
            hb_vmPushString( szPath, strlen(szPath) );
            hb_vmDo( 3 );
         }

         [d->tableView reloadData];

         /* Notify property changed */
         if( d->pOnPropChanged )
         {
            hb_vmPushEvalSym();
            hb_vmPush( d->pOnPropChanged );
            hb_vmSend( 0 );
         }
      }
   }];
}

- (void)openTextEditorForRow:(int)nReal
{
   NSString * curVal = [NSString stringWithUTF8String:d->rows[nReal].szValue];

   NSWindow * sheet = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 420, 240)
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
      backing:NSBackingStoreBuffered defer:NO];
   [sheet setTitle:[NSString stringWithFormat:@"Edit: %s", d->rows[nReal].szName]];

   NSScrollView * scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(10, 50, 400, 180)];
   [scrollView setHasVerticalScroller:YES];
   [scrollView setBorderType:NSBezelBorder];

   NSTextView * textView = [[NSTextView alloc]
      initWithFrame:NSMakeRect(0, 0, 380, 160)];
   [textView setMinSize:NSMakeSize(380, 160)];
   [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
   [textView setVerticallyResizable:YES];
   [[textView textContainer] setWidthTracksTextView:YES];
   [textView setFont:[NSFont systemFontOfSize:13]];
   [textView setString:curVal];
   [textView setEditable:YES];
   [textView setRichText:NO];
   [textView setAutomaticQuoteSubstitutionEnabled:NO];
   [textView setAutomaticDashSubstitutionEnabled:NO];

   /* Dark appearance */
   [textView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.15 alpha:1.0]];
   [textView setTextColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
   [textView setInsertionPointColor:[NSColor whiteColor]];

   [scrollView setDocumentView:textView];
   [[sheet contentView] addSubview:scrollView];

   /* OK button */
   NSButton * okBtn = [[NSButton alloc] initWithFrame:NSMakeRect(330, 10, 80, 30)];
   [okBtn setTitle:@"OK"];
   [okBtn setBezelStyle:NSBezelStyleRounded];
   [okBtn setKeyEquivalent:@"\r"];
   [okBtn setTarget:NSApp];
   [okBtn setAction:@selector(stopModal)];
   [[sheet contentView] addSubview:okBtn];

   /* Cancel button */
   NSButton * cancelBtn = [[NSButton alloc] initWithFrame:NSMakeRect(240, 10, 80, 30)];
   [cancelBtn setTitle:@"Cancel"];
   [cancelBtn setBezelStyle:NSBezelStyleRounded];
   [cancelBtn setKeyEquivalent:@"\033"];
   [cancelBtn setTarget:NSApp];
   [cancelBtn setAction:@selector(abortModal)];
   [[sheet contentView] addSubview:cancelBtn];

   [sheet center];
   [sheet makeKeyAndOrderFront:nil];
   [sheet makeFirstResponder:textView];
   [NSApp activateIgnoringOtherApps:YES];
   NSModalResponse response = [NSApp runModalForWindow:sheet];

   if( response == NSModalResponseAbort ) { [sheet orderOut:nil]; return; }

   /* Select all text in textView to get final string */
   NSString * result = [textView string];
   const char * szResult = [result UTF8String];
   if( !szResult ) szResult = "";

   strncpy( d->rows[nReal].szValue, szResult, sizeof(d->rows[nReal].szValue) - 1 );
   d->rows[nReal].szValue[sizeof(d->rows[nReal].szValue) - 1] = '\0';

   /* Push to control */
   if( d->hCtrl )
   {
      hb_vmPushDynSym( hb_dynsymFind( "UI_SETPROP" ) );
      hb_vmPushNil();
      hb_vmPushNumInt( (HB_MAXINT) d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
      hb_vmPushString( szResult, strlen(szResult) );
      hb_vmDo( 3 );
   }

   [d->tableView reloadData];
   if( d->pOnPropChanged )
   {
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnPropChanged );
      hb_vmSend( 0 );
   }

   [sheet orderOut:nil];
}

- (void)openArrayEditorForRow:(int)nReal
{
   /* Convert "|"-separated value to newline-separated text */
   NSString * curVal = [NSString stringWithUTF8String:d->rows[nReal].szValue];
   NSString * text = [curVal stringByReplacingOccurrencesOfString:@"|" withString:@"\n"];

   /* Create modal dialog with NSTextView */
   NSWindow * sheet = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 350, 300)
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
      backing:NSBackingStoreBuffered defer:NO];
   [sheet setTitle:[NSString stringWithFormat:@"Edit %s (one item per line)",
      d->rows[nReal].szName]];

   NSScrollView * scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(10, 50, 330, 240)];
   [scrollView setHasVerticalScroller:YES];
   [scrollView setBorderType:NSBezelBorder];

   NSTextView * textView = [[NSTextView alloc]
      initWithFrame:NSMakeRect(0, 0, 310, 220)];
   [textView setMinSize:NSMakeSize(310, 220)];
   [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
   [textView setVerticallyResizable:YES];
   [[textView textContainer] setWidthTracksTextView:YES];
   [textView setFont:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]];
   [textView setString:text];
   [textView setEditable:YES];

   /* Dark appearance */
   [textView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.15 alpha:1.0]];
   [textView setTextColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
   [textView setInsertionPointColor:[NSColor whiteColor]];

   [scrollView setDocumentView:textView];
   [[sheet contentView] addSubview:scrollView];

   /* OK button */
   NSButton * okBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(260, 10, 80, 30)];
   [okBtn setTitle:@"OK"];
   [okBtn setBezelStyle:NSBezelStyleRounded];
   [okBtn setKeyEquivalent:@"\r"];
   [okBtn setTarget:NSApp];
   [okBtn setAction:@selector(stopModal)];
   [okBtn setTag:1];
   [[sheet contentView] addSubview:okBtn];

   /* Cancel button */
   NSButton * cancelBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(170, 10, 80, 30)];
   [cancelBtn setTitle:@"Cancel"];
   [cancelBtn setBezelStyle:NSBezelStyleRounded];
   [cancelBtn setKeyEquivalent:@"\033"];
   [cancelBtn setTarget:NSApp];
   [cancelBtn setAction:@selector(abortModal)];
   [cancelBtn setTag:0];
   [[sheet contentView] addSubview:cancelBtn];

   [sheet center];
   [sheet setInitialFirstResponder:textView];
   [sheet makeKeyAndOrderFront:nil];
   [sheet makeFirstResponder:textView];
   [NSApp activateIgnoringOtherApps:YES];
   NSModalResponse response = [NSApp runModalForWindow:sheet];
   [sheet makeFirstResponder:textView];

   if( response == NSModalResponseAbort )
   {
      [sheet orderOut:nil];
      return;
   }
   NSString * newText = [textView string];

   /* Convert newlines back to "|" separator. Preserve leading whitespace
    * so indentation-based hierarchy (TTreeView items) survives. Trim only
    * trailing whitespace; drop fully blank lines. */
   NSArray * lines = [newText componentsSeparatedByCharactersInSet:
      [NSCharacterSet newlineCharacterSet]];
   NSMutableArray * nonEmpty = [NSMutableArray array];
   NSCharacterSet * trailWS = [NSCharacterSet whitespaceCharacterSet];
   for( NSString * line in lines )
   {
      /* Trim only trailing whitespace */
      NSRange r = [line rangeOfCharacterFromSet:[trailWS invertedSet]
                                        options:NSBackwardsSearch];
      NSString * rtrimmed = ( r.location == NSNotFound )
         ? @"" : [line substringToIndex:r.location + 1];
      if( [rtrimmed length] > 0 )
         [nonEmpty addObject:rtrimmed];
   }
   NSString * result = [nonEmpty componentsJoinedByString:@"|"];
   const char * szResult = [result UTF8String];

   strncpy( d->rows[nReal].szValue, szResult, sizeof(d->rows[nReal].szValue) - 1 );
   d->rows[nReal].szValue[sizeof(d->rows[nReal].szValue) - 1] = '\0';

   /* Push to control */
   if( d->hCtrl )
   {
      hb_vmPushDynSym( hb_dynsymFind( "UI_SETPROP" ) );
      hb_vmPushNil();
      hb_vmPushNumInt( (HB_MAXINT) d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
      hb_vmPushString( szResult, strlen(szResult) );
      hb_vmDo( 3 );
   }

   [d->tableView reloadData];
   if( d->pOnPropChanged )
   {
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnPropChanged );
      hb_vmSend( 0 );
   }

   [sheet orderOut:nil];
}

static int s_dropdownChoice = -1;
- (void)dropdownMenuSelected:(id)sender { s_dropdownChoice = (int)[sender tag]; }

- (void)openLogicalDropdownForRow:(int)nReal inTableView:(NSTableView *)tv atRow:(NSInteger)row
{
   BOOL curVal = ( strcasecmp( d->rows[nReal].szValue, ".T." ) == 0 );
   int curIdx = curVal ? 0 : 1;

   NSMenu * menu = [[NSMenu alloc] init];
   NSMenuItem * itemYes = [[NSMenuItem alloc] initWithTitle:@"Yes" action:@selector(dropdownMenuSelected:) keyEquivalent:@""];
   NSMenuItem * itemNo  = [[NSMenuItem alloc] initWithTitle:@"No"  action:@selector(dropdownMenuSelected:) keyEquivalent:@""];
   [itemYes setTarget:self];
   [itemNo  setTarget:self];
   [itemYes setTag:1];
   [itemNo  setTag:0];
   if( curVal )  [itemYes setState:NSControlStateValueOn];
   else          [itemNo  setState:NSControlStateValueOn];
   [menu addItem:itemYes];
   [menu addItem:itemNo];

   NSRect cellRect = [tv frameOfCellAtColumn:1 row:row];
   NSPoint pt = NSMakePoint( cellRect.origin.x, cellRect.origin.y );

   s_dropdownChoice = -1;
   [menu popUpMenuPositioningItem:[menu itemAtIndex:curIdx]
      atLocation:pt inView:tv];

   if( s_dropdownChoice >= 0 )
   {
      BOOL newVal = ( s_dropdownChoice == 1 );
      strcpy( d->rows[nReal].szValue, newVal ? ".T." : ".F." );

      if( d->hCtrl )
      {
         hb_vmPushDynSym( hb_dynsymFind( "UI_SETPROP" ) );
         hb_vmPushNil();
         hb_vmPushNumInt( (HB_MAXINT) d->hCtrl );
         hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
         hb_vmPushLogical( newVal );
         hb_vmDo( 3 );
      }
   }

   [d->tableView reloadData];
   if( d->pOnPropChanged )
   {
      hb_vmPushEvalSym();
      hb_vmPush( d->pOnPropChanged );
      hb_vmSend( 0 );
   }
}

- (void)openDropdownForRow:(int)nReal inTableView:(NSTableView *)tv atRow:(NSInteger)row
{
   const char * raw = d->rows[nReal].szValue;
   int curIdx = atoi( raw );

   /* Build menu from "index|opt0|opt1|..." */
   NSMenu * menu = [[NSMenu alloc] init];
   const char * p = strchr( raw, '|' );
   int idx = 0;
   while( p && *p == '|' ) {
      p++;
      const char * end = strchr( p, '|' );
      int len = end ? (int)(end - p) : (int)strlen(p);
      NSString * title = [[NSString alloc] initWithBytes:p length:len encoding:NSUTF8StringEncoding];
      NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:title action:@selector(dropdownMenuSelected:) keyEquivalent:@""];
      [item setTarget:self];
      [item setTag:idx];
      if( idx == curIdx ) [item setState:NSControlStateValueOn];
      [menu addItem:item];
      idx++;
      p = end;
   }

   /* Show popup at cell location */
   NSRect cellRect = [tv frameOfCellAtColumn:1 row:row];
   NSPoint pt = NSMakePoint( cellRect.origin.x, cellRect.origin.y );

   s_dropdownChoice = -1;
   [menu popUpMenuPositioningItem:[menu itemAtIndex:curIdx]
      atLocation:pt inView:tv];

   if( s_dropdownChoice >= 0 && s_dropdownChoice != curIdx )
   {
      int i = s_dropdownChoice;
      /* Rebuild value string with new index */
      const char * opts = strchr( raw, '|' );
      char newVal[512];
      snprintf( newVal, sizeof(newVal), "%d%s", i, opts ? opts : "" );
      strncpy( d->rows[nReal].szValue, newVal, sizeof(d->rows[0].szValue) - 1 );

      /* Apply via UI_BrowseSetColProp or UI_SetProp */
      if( d->nBrowseCol >= 0 ) {
         PHB_DYNS pDyn = hb_dynsymFindName( "UI_BROWSESETCOLPROP" );
         if( pDyn ) {
            hb_vmPushDynSym( pDyn ); hb_vmPushNil();
            hb_vmPushNumInt( d->hCtrl );
            hb_vmPushInteger( d->nBrowseCol );
            hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
            hb_vmPushInteger( i );
            hb_vmDo( 4 );
         }
      } else {
         PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
         if( pDyn ) {
            hb_vmPushDynSym( pDyn ); hb_vmPushNil();
            hb_vmPushNumInt( d->hCtrl );
            hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
            hb_vmPushInteger( i );
            hb_vmDo( 3 );
         }
      }
      if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) ) {
         hb_vmPushEvalSym(); hb_vmPush( d->pOnPropChanged ); hb_vmSend( 0 );
      }
      [tv reloadData];
   }
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
         [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.20 alpha:1.0]];
         if( [cell respondsToSelector:@selector(setTextColor:)] )
            [cell setTextColor:[NSColor colorWithCalibratedWhite:0.85 alpha:1.0]];
      }
   }
   else
   {
      [cell setFont:d->font];
      if( [cell respondsToSelector:@selector(setTextColor:)] )
         [cell setTextColor:[NSColor colorWithCalibratedWhite:0.82 alpha:1.0]];
      [cell setDrawsBackground:( row % 2 == 1 )];
      if( row % 2 == 1 )
         [cell setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1.0]];

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
         if( d->rows[nReal].cType == 'C' || d->rows[nReal].cType == 'F' || d->rows[nReal].cType == 'P' || d->rows[nReal].cType == 'A' || d->rows[nReal].cType == 'S' || d->rows[nReal].cType == 'M' )
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
         else if( d->rows[nReal].cType == 'P' )
            [self openFilePickerForRow:nReal];
         else if( d->rows[nReal].cType == 'A' )
            [self openArrayEditorForRow:nReal];
         else if( d->rows[nReal].cType == 'S' )
            [self openTextEditorForRow:nReal];
         else if( d->rows[nReal].cType == 'M' )
            OpenMenuEditor( d, nReal );
      }
      /* Click on value column for dropdown properties */
      if( [[clickedCol identifier] isEqualToString:@"value"] && d->rows[nReal].cType == 'D' )
         [self openDropdownForRow:nReal inTableView:d->tableView atRow:row];
   }
}

/* Tab changed (Properties / Events / Debug tabs) */
- (void)tabChanged:(id)sender
{
   if( !d || !d->tabCtrl ) return;
   d->nTab = (int)[d->tabCtrl selectedSegment];

   NSTableColumn * nameCol = [d->tableView tableColumnWithIdentifier:@"name"];
   NSTableColumn * valCol = [d->tableView tableColumnWithIdentifier:@"value"];

   if( d->bDebugMode )
   {
      /* Debug mode tabs: 0=Vars, 1=Call Stack, 2=Watch */
      if( d->nTab == 0 ) {
         if( nameCol ) { [[nameCol headerCell] setStringValue:@"Variable"]; [nameCol setWidth:140]; }
         if( valCol )  { [[valCol headerCell] setStringValue:@"Value"]; [valCol setWidth:130]; }
         d->nVisible = d->nDbgLocalsVisible;
         memcpy( d->rows, d->dbgLocalsRows, sizeof(IROW) * (size_t)d->nDbgLocalsRows );
         memcpy( d->map, d->dbgLocalsMap, sizeof(int) * (size_t)d->nDbgLocalsVisible );
         d->nRows = d->nDbgLocalsRows;
      } else if( d->nTab == 1 ) {
         if( nameCol ) { [[nameCol headerCell] setStringValue:@"#"]; [nameCol setWidth:30]; }
         if( valCol )  { [[valCol headerCell] setStringValue:@"Function"]; [valCol setWidth:240]; }
         d->nVisible = d->nDbgStackVisible;
         memcpy( d->rows, d->dbgStackRows, sizeof(IROW) * (size_t)d->nDbgStackRows );
         memcpy( d->map, d->dbgStackMap, sizeof(int) * (size_t)d->nDbgStackVisible );
         d->nRows = d->nDbgStackRows;
      } else {
         if( nameCol ) [[nameCol headerCell] setStringValue:@"Expression"];
         if( valCol )  [[valCol headerCell] setStringValue:@"Value"];
         d->nVisible = 0; d->nRows = 0;
      }
      [d->tableView reloadData];
      [d->tableView setNeedsDisplay:YES];
      return;
   }

   /* Normal mode: Properties / Events */
   if( nameCol )
      [[nameCol headerCell] setStringValue: d->nTab == 0 ? @"Property" : @"Event"];
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

      /* Picker types: open dialog instead of inline edit */
      if( d->rows[nReal].cType == 'C' ) { [self openColorPickerForRow:nReal]; return; }
      if( d->rows[nReal].cType == 'F' ) { [self openFontPickerForRow:nReal]; return; }
      if( d->rows[nReal].cType == 'S' ) { [self openTextEditorForRow:nReal]; return; }

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

      /* The Harbour callback (OnEventDblClick) calls InspectorRefresh
       * which in turn calls INS_SetEvents with resolved handler names.
       * If the callback didn't refresh, fall back to C-side populate. */
      if( d->nEvRows == 0 )
         InsPopulateEvents( d );
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

/* Right-click context menu on Events tab — delete handler */
- (void)rightClickDeleteHandler:(id)sender
{
   if( !d ) return;
   NSMenuItem * mi = (NSMenuItem *)sender;
   const char * szHandler = [[mi representedObject] UTF8String];
   if( !szHandler || !szHandler[0] ) return;

   PHB_DYNS pDel = hb_dynsymFindName( "INS_DELETEHANDLER" );
   if( pDel && hb_vmRequestReenter() )
   {
      hb_vmPushDynSym( pDel ); hb_vmPushNil();
      hb_vmPushString( szHandler, strlen(szHandler) );
      hb_vmDo( 1 );
      hb_vmRequestRestore();

      /* Refresh events to update display */
      InsPopulateEvents( d );
   }
}

@end

/* ======================================================================
 * Custom NSTableView subclass to handle right-click menu for events
 * ====================================================================== */

@interface HBInspectorTableView : NSTableView
@end

@implementation HBInspectorTableView

- (void)keyDown:(NSEvent *)event
{
   HBInspectorDelegate * del = (HBInspectorDelegate *)[self delegate];
   unsigned short keyCode = [event keyCode];
   /* Arrow Up = 126, Arrow Down = 125 */
   if( del && del->d && (keyCode == 125 || keyCode == 126) )
   {
      INSDATA * dd = del->d;
      NSInteger cur = [self selectedRow];
      NSInteger nRows = dd->nVisible;
      int dir = (keyCode == 125) ? 1 : -1;
      NSInteger next = cur + dir;

      /* Skip category rows */
      while( next >= 0 && next < nRows && dd->rows[dd->map[next]].bIsCat )
         next += dir;

      if( next >= 0 && next < nRows )
      {
         NSIndexSet * idx = [NSIndexSet indexSetWithIndex:next];
         [self selectRowIndexes:idx byExtendingSelection:NO];
         [self scrollRowToVisible:next];
      }
      return;
   }
   [super keyDown:event];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
   /* Only show context menu on Events tab */
   HBInspectorDelegate * del = (HBInspectorDelegate *)[self delegate];
   if( !del || !del->d || del->d->nTab != 1 ) return nil;

   NSPoint pt = [self convertPoint:[event locationInWindow] fromView:nil];
   NSInteger row = [self rowAtPoint:pt];
   if( row < 0 || row >= del->d->nVisible ) return nil;

   int nReal = del->d->map[row];
   if( del->d->rows[nReal].bIsCat ) return nil;
   if( del->d->rows[nReal].szValue[0] == 0 ) return nil; /* No handler assigned */

   NSMenu * menu = [[NSMenu alloc] init];
   NSString * handler = [NSString stringWithUTF8String:del->d->rows[nReal].szValue];
   NSString * title = [NSString stringWithFormat:@"Delete %@", handler];
   NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:title
      action:@selector(rightClickDeleteHandler:) keyEquivalent:@""];
   [item setTarget:del];
   [item setRepresentedObject:handler];
   [menu addItem:item];
   return menu;
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
         else if( d->rows[d->nRows].cType == 'D' )
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 255 );
         else if( d->rows[d->nRows].cType == 'P' )
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 255 );
         else if( d->rows[d->nRows].cType == 'A' )
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), 255 );
         else if( d->rows[d->nRows].cType == 'M' )
         {
            /* Count nodes in serial (pipe-separated) and show display string */
            const char * raw = hb_arrayGetCPtr(pRow,2);
            if( raw && raw[0] ) {
               int cnt=1;
               for(const char*p=raw;*p;p++) if(*p=='|') cnt++;
               snprintf(d->rows[d->nRows].szValue,sizeof(d->rows[0].szValue),"(%d nodes)",cnt);
            } else {
               strncpy(d->rows[d->nRows].szValue,"(0 nodes)",sizeof(d->rows[0].szValue)-1);
            }
         }
         else
            d->rows[d->nRows].szValue[0] = 0;

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

/* ======================================================================
 * Event population — mirrors Win32 InsPopulateEvents()
 * Builds event rows by control type, checks handler existence in code
 * ====================================================================== */

/* Case-insensitive substring search */
static BOOL InsCodeContains( const char * pCode, size_t nCodeLen, const char * szSearch )
{
   if( !pCode || !szSearch ) return NO;
   size_t slen = strlen( szSearch );
   if( slen == 0 || slen > nCodeLen ) return NO;
   for( size_t i = 0; i <= nCodeLen - slen; i++ )
   {
      if( strncasecmp( pCode + i, szSearch, slen ) == 0 )
         return YES;
   }
   return NO;
}

/* Add a category header to evRows */
static void InsAddEventCat( INSDATA * d, const char * szCat )
{
   if( d->nEvRows >= MAX_ROWS ) return;
   IROW * r = &d->evRows[d->nEvRows];
   memset( r, 0, sizeof(IROW) );
   strncpy( r->szName, szCat, 31 );
   r->bIsCat = YES;
   r->bVisible = YES;
   strncpy( r->szCategory, szCat, 31 );
   d->nEvRows++;
}

/* Add one event row — builds handler name and checks if it exists in code */
static void InsAddEvent( INSDATA * d, const char * szEvent, const char * szCtrlName,
                         const char * pCode, size_t nCodeLen )
{
   if( d->nEvRows >= MAX_ROWS ) return;
   IROW * r = &d->evRows[d->nEvRows];
   memset( r, 0, sizeof(IROW) );
   strncpy( r->szName, szEvent, 31 );
   r->cType = 'E';
   r->bVisible = YES;

   /* Build handler name: CtrlName + EventName without "On" prefix */
   if( szCtrlName && szCtrlName[0] && strlen(szEvent) > 2 )
   {
      char handler[128], search[160];
      snprintf( handler, sizeof(handler), "%s%s", szCtrlName, szEvent + 2 );
      snprintf( search, sizeof(search), "function %s", handler );
      if( InsCodeContains( pCode, nCodeLen, search ) )
         strncpy( r->szValue, handler, 255 );
   }

   d->nEvRows++;
}

static void InsPopulateEvents( INSDATA * d )
{
   char szCtrlName[64] = "ctrl";
   char * pCode = NULL;
   size_t nCodeLen = 0;
   int nType = 0;

   if( !d ) return;

   d->nEvRows = 0;
   d->nEvVisible = 0;
   if( d->hCtrl == 0 ) return;

   /* Get control name via UI_GetProp( hCtrl, "cName" ) */
   {
      PHB_DYNS pGetProp = hb_dynsymFindName( "UI_GETPROP" );
      if( pGetProp && hb_vmRequestReenter() )
      {
         hb_vmPushDynSym( pGetProp ); hb_vmPushNil();
         hb_vmPushNumInt( d->hCtrl );
         hb_vmPushString( "cName", 5 );
         hb_vmDo( 2 );
         const char * s = hb_itemGetCPtr( hb_stackReturnItem() );
         if( s && s[0] ) strncpy( szCtrlName, s, 63 );
         hb_vmRequestRestore();
      }
   }
   if( szCtrlName[0] == 0 || strcmp(szCtrlName, "ctrl") == 0 )
      strncpy( szCtrlName, "Form1", 63 );

   /* Read all code from editor to check which handlers exist */
   {
      PHB_DYNS pGetCode = hb_dynsymFindName( "INS_GETALLCODE" );
      if( pGetCode && hb_vmRequestReenter() )
      {
         hb_vmPushDynSym( pGetCode ); hb_vmPushNil();
         hb_vmDo( 0 );
         const char * s = hb_itemGetCPtr( hb_stackReturnItem() );
         HB_SIZE len = hb_itemGetCLen( hb_stackReturnItem() );
         if( s && len > 0 )
         {
            pCode = (char *) malloc( len + 1 );
            memcpy( pCode, s, len );
            pCode[len] = 0;
            nCodeLen = len;
         }
         hb_vmRequestRestore();
      }
   }

   /* Get control type via UI_GetType( hCtrl ) */
   {
      PHB_DYNS pDyn = hb_dynsymFindName( "UI_GETTYPE" );
      if( pDyn && hb_vmRequestReenter() )
      {
         hb_vmPushDynSym( pDyn ); hb_vmPushNil();
         hb_vmPushNumInt( d->hCtrl );
         hb_vmDo( 1 );
         nType = hb_itemGetNI( hb_stackReturnItem() );
         hb_vmRequestRestore();
      }
   }

   /* Shorthand macros */
   #define AE(ev) InsAddEvent(d, ev, szCtrlName, pCode, nCodeLen)
   #define AC(cat) InsAddEventCat(d, cat)

   switch( nType )
   {
      case 0: /* CT_FORM */
         AC("Action");
         AE("OnClick"); AE("OnDblClick");
         AC("Lifecycle");
         AE("OnCreate"); AE("OnDestroy");
         AE("OnShow"); AE("OnHide");
         AE("OnClose"); AE("OnCloseQuery");
         AE("OnActivate"); AE("OnDeactivate");
         AC("Layout");
         AE("OnResize"); AE("OnPaint");
         AC("Keyboard");
         AE("OnKeyDown"); AE("OnKeyUp"); AE("OnKeyPress");
         AC("Mouse");
         AE("OnMouseDown"); AE("OnMouseUp");
         AE("OnMouseMove"); AE("OnMouseWheel");
         break;
      case 3: /* CT_BUTTON */
      case 12: /* CT_BITBTN */
         AC("Action");
         AE("OnClick");
         AC("Focus");
         AE("OnEnter"); AE("OnExit");
         AC("Keyboard");
         AE("OnKeyDown");
         AC("Mouse");
         AE("OnMouseDown");
         break;
      case 2: /* CT_EDIT */
      case 24: /* CT_MEMO */
      case 23: /* CT_RICHEDIT */
      case 28: /* CT_MASKEDIT */
      case 32: /* CT_LABELEDEDIT */
         AC("Action");
         AE("OnChange"); AE("OnClick");
         AC("Focus");
         AE("OnEnter"); AE("OnExit");
         AC("Keyboard");
         AE("OnKeyDown"); AE("OnKeyUp");
         AC("Mouse");
         AE("OnMouseDown");
         break;
      case 4: /* CT_CHECKBOX */
      case 8: /* CT_RADIO */
         AC("Action");
         AE("OnClick");
         AC("Focus");
         AE("OnEnter"); AE("OnExit");
         break;
      case 5: /* CT_COMBOBOX */
         AC("Action");
         AE("OnChange"); AE("OnClick");
         AC("Focus");
         AE("OnEnter"); AE("OnExit");
         AC("Keyboard");
         AE("OnKeyDown");
         break;
      case 1: /* CT_LABEL */
      case 31: /* CT_STATICTEXT */
         AC("Action");
         AE("OnClick"); AE("OnDblClick");
         AC("Mouse");
         AE("OnMouseDown");
         break;
      case 6: /* CT_GROUPBOX */
      case 25: /* CT_PANEL */
         AC("Action");
         AE("OnClick"); AE("OnDblClick");
         AC("Layout");
         AE("OnResize");
         AC("Mouse");
         AE("OnMouseDown");
         break;
      case 7: /* CT_LISTBOX */
         AC("Action");
         AE("OnClick"); AE("OnDblClick"); AE("OnChange");
         AC("Focus");
         AE("OnEnter"); AE("OnExit");
         AC("Keyboard");
         AE("OnKeyDown");
         break;
      case 20: /* CT_TREEVIEW */
         AC("Action");
         AE("OnClick"); AE("OnDblClick"); AE("OnChange");
         AE("OnExpand"); AE("OnCollapse");
         AC("Keyboard");
         AE("OnKeyDown");
         break;
      case 21: /* CT_LISTVIEW */
         AC("Action");
         AE("OnClick"); AE("OnDblClick"); AE("OnChange");
         AE("OnColumnClick");
         AC("Keyboard");
         AE("OnKeyDown");
         break;
      case 79: case 80: /* CT_BROWSE, CT_DBGRID */
         AC("Action");
         AE("OnCellClick"); AE("OnCellDblClick");
         AE("OnHeaderClick"); AE("OnSort");
         AE("OnScroll"); AE("OnRowSelect");
         AC("Data");
         AE("OnCellEdit");
         AC("Layout");
         AE("OnColumnResize");
         AC("Keyboard");
         AE("OnKeyDown");
         break;
      case 39: /* CT_PAINTBOX */
         AC("Action");
         AE("OnPaint"); AE("OnClick");
         AC("Mouse");
         AE("OnMouseDown"); AE("OnMouseUp"); AE("OnMouseMove");
         AC("Layout");
         AE("OnResize");
         break;
      case 38: /* CT_TIMER */
         AC("Action");
         AE("OnTimer");
         break;
      case 71: /* CT_WEBSERVER */
         AC("Lifecycle");
         AE("OnStart");
         AE("OnStop");
         AC("Error");
         AE("OnError");
         break;
      case 102: /* CT_PRINTER */
         AC("Document");
         AE("OnBeginDoc");
         AE("OnEndDoc");
         AC("Page");
         AE("OnNewPage");
         AC("Error");
         AE("OnError");
         break;
      case 132: /* CT_BAND */
         AC("Print");
         AE("OnPrint");
         AE("OnAfterPrint");
         break;
      case 22: /* CT_PROGRESSBAR */
         break;
      case 34: /* CT_TRACKBAR */
      case 26: /* CT_SCROLLBAR */
         AC("Action");
         AE("OnChange"); AE("OnScroll");
         break;
      case 33: /* CT_TABCONTROL */
      case 35: /* CT_UPDOWN */
      case 36: /* CT_DATETIMEPICKER */
      case 37: /* CT_MONTHCALENDAR */
         AC("Action");
         AE("OnChange"); AE("OnClick");
         break;
      case 62: /* CT_WEBVIEW */
         AC("Navigation");
         AE("OnNavigate"); AE("OnLoad"); AE("OnError");
         AC("Mouse");
         AE("OnClick");
         break;
      case 14: /* CT_IMAGE */
         AC("Action");
         AE("OnClick"); AE("OnDblClick");
         AC("Mouse");
         AE("OnMouseDown");
         break;
      default:
         AC("Action");
         AE("OnClick"); AE("OnChange");
         AC("Keyboard");
         AE("OnKeyDown");
         AC("Mouse");
         AE("OnMouseDown");
         break;
   }

   #undef AE
   #undef AC

   /* Build visible map */
   d->nEvVisible = 0;
   for( int k = 0; k < d->nEvRows; k++ )
   {
      if( d->evRows[k].bVisible || d->evRows[k].bIsCat )
         d->evMap[d->nEvVisible++] = k;
   }

   /* If Events tab is active, copy to display rows */
   if( d->nTab == 1 )
   {
      InsActivateTab( d );
      [d->tableView reloadData];
   }

   if( pCode ) free( pCode );
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
      InsPopulateEvents( d );
      /* InsPopulateEvents already calls InsActivateTab + reloadData */
      return;
   }
   [d->tableView reloadData];
}

/* ======================================================================
 * Global inspector data storage
 * ====================================================================== */

static HB_PTRUINT s_insData = 0;
static PHB_ITEM s_comboMap = NULL;

HB_FUNC( _INSGETDATA ) { hb_retnint( s_insData ); }
HB_FUNC( _INSSETDATA ) { s_insData = (HB_PTRUINT) hb_parnint(1); }

/* _InsSetComboMap( aMap ) / _InsGetComboMap() --> aMap
 * Stores the combo index -> { nType, hCtrl, nColIdx } mapping array */
HB_FUNC( _INSSETCOMBOMAP )
{
   PHB_ITEM pArr = hb_param(1, HB_IT_ARRAY);
   if( s_comboMap ) { hb_itemRelease( s_comboMap ); s_comboMap = NULL; }
   if( pArr ) s_comboMap = hb_itemNew( pArr );
}
HB_FUNC( _INSGETCOMBOMAP )
{
   if( s_comboMap ) hb_itemReturn( s_comboMap );
   else hb_reta(0);
}

/* ======================================================================
 * INS_Create() --> hInsData
 * ====================================================================== */

HB_FUNC( INS_CREATE )
{
   INSDATA * d = (INSDATA *) calloc( 1, sizeof(INSDATA) );
   d->nBrowseCol = -1;
   d->nFolderPage = -1;

   d->font = [NSFont systemFontOfSize:12];
   d->boldFont = [NSFont boldSystemFontOfSize:12];

   fprintf(stderr, "INS: creating window\n");
   /* Create window */
   NSRect frame = NSMakeRect( 100, 100, 320, 450 );
   d->window = [[NSWindow alloc] initWithContentRect:frame
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered
      defer:NO];
   [d->window setTitle:@"Inspector"];
   [d->window setReleasedWhenClosed:NO];
   fprintf(stderr, "INS: setting dark appearance\n");
   if( [NSAppearance respondsToSelector:@selector(appearanceNamed:)] )
      [d->window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
   fprintf(stderr, "INS: dark appearance set\n");

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

   d->tableView = [[HBInspectorTableView alloc] initWithFrame:contentFrame];
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

   fprintf(stderr, "INS: setting table bg\n");
   /* Dark theme for table */
   [d->tableView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.15 alpha:1.0]];
   fprintf(stderr, "INS: table bg set\n");

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

   [d->window setDelegate:s_delegate];
   fprintf(stderr, "INS: orderFront\n");
   [d->window orderFront:nil];
   fprintf(stderr, "INS: CREATE done\n");

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
   d->nBrowseCol = -1;  /* reset; INS_SetBrowseCol overrides after this call */

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
      strncpy( d->szClassName, cls ? cls : "", sizeof(d->szClassName) - 1 );
   }

   /* Always build property rows from the passed array */
   InsBuildRows( d, pArray );

   /* If Events tab is active, repopulate events for new control */
   if( d->nTab == 1 )
   {
      InsPopulateEvents( d );
      return; /* InsPopulateEvents already reloads */
   }

   [d->tableView reloadData];
}

/* INS_SetBrowseCol( hInsData, nCol ) - set column index for property editing (-1 = not a column) */
HB_FUNC( INS_SETBROWSECOL )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d ) d->nBrowseCol = hb_parni(2);
}

/* INS_SetFolderPage( hInsData, hFolder, nPage ) - prepare inspector for folder-page view */
HB_FUNC( INS_SETFOLDERPAGE )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   d->hCtrl = (HB_PTRUINT) hb_parnint(2);
   d->nFolderPage = HB_ISNUM(3) ? hb_parni(3) : -1;
   d->nBrowseCol = -1;
   d->nRows = 0;
}

/* INS_AddRow( hInsData, cName, cValue, cCategory, cType ) */
HB_FUNC( INS_ADDROW )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   IROW * r;
   if( !d || d->nRows >= MAX_ROWS - 1 ) return;

   r = &d->rows[d->nRows++];
   strncpy( r->szName,     HB_ISCHAR(2) ? hb_parc(2) : "", 31 );
   strncpy( r->szValue,    HB_ISCHAR(3) ? hb_parc(3) : "", 255 );
   strncpy( r->szCategory, HB_ISCHAR(4) ? hb_parc(4) : "General", 31 );
   r->cType = ( HB_ISCHAR(5) && hb_parc(5)[0] ) ? hb_parc(5)[0] : 'S';
   r->bIsCat = NO;
   r->bCollapsed = NO;
   r->bVisible = YES;
}

/* INS_AddCategoryRow( hInsData, cName ) - header/divider row */
HB_FUNC( INS_ADDCATEGORYROW )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   IROW * r;
   if( !d || d->nRows >= MAX_ROWS - 1 ) return;

   r = &d->rows[d->nRows++];
   strncpy( r->szName,     HB_ISCHAR(2) ? hb_parc(2) : "", 31 );
   r->szValue[0] = 0;
   strncpy( r->szCategory, HB_ISCHAR(2) ? hb_parc(2) : "", 31 );
   r->cType = 0;
   r->bIsCat = YES;
   r->bCollapsed = NO;
   r->bVisible = YES;
}

/* INS_Rebuild( hInsData ) - refresh layout after Harbour pushes rows via
 * INS_SetFolderPage / INS_AddCategoryRow / INS_AddRow.
 * Rebuilds the visibility map from existing rows and reloads the table. */
HB_FUNC( INS_REBUILD )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d )
   {
      /* Rebuild visibility map from rows already populated by Harbour */
      int i;
      d->nVisible = 0;
      for( i = 0; i < d->nRows; i++ )
      {
         if( d->rows[i].bVisible )
            d->map[d->nVisible++] = i;
      }
      InsPopulateEvents( d );
      [d->tableView reloadData];
   }
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

   d->nEvRows = 0;
   d->nEvVisible = 0;

   if( !pArray || hb_arrayLen(pArray) == 0 )
   {
      if( d->nTab == 1 ) { InsActivateTab( d ); [d->tableView reloadData]; }
      return;
   }

   HB_SIZE nLen = hb_arrayLen( pArray );
   char szCats[16][32];
   int nCats = 0, j;

   /* Collect unique categories */
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
      IROW * r = &d->evRows[d->nEvRows];
      memset( r, 0, sizeof(IROW) );
      strncpy( r->szName, szCats[j], 31 );
      strncpy( r->szCategory, szCats[j], 31 );
      r->bIsCat = YES;
      r->bVisible = YES;
      d->nEvRows++;

      for( HB_SIZE i = 1; i <= nLen && d->nEvRows < MAX_ROWS; i++ )
      {
         PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
         if( strcasecmp( hb_arrayGetCPtr(pRow,3), szCats[j] ) != 0 ) continue;

         IROW * er = &d->evRows[d->nEvRows];
         memset( er, 0, sizeof(IROW) );
         strncpy( er->szName, hb_arrayGetCPtr(pRow,1), 31 );
         strncpy( er->szCategory, hb_arrayGetCPtr(pRow,3), 31 );
         er->cType = 'E';
         er->bVisible = YES;

         /* Field 2: handler name (string) or assigned flag (logical) */
         PHB_ITEM pField2 = hb_arrayGetItemPtr( pRow, 2 );
         if( pField2 && HB_IS_STRING( pField2 ) )
         {
            const char * h = hb_itemGetCPtr( pField2 );
            if( h && h[0] ) strncpy( er->szValue, h, 255 );
         }

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

/* ======================================================================
 * Debug mode: switch inspector to show Variables / Call Stack / Watch
 * ====================================================================== */

/* INS_SetDebugMode( hInsData, lDebug )
 * .T. = switch tabs to Locals/CallStack/Watch, hide combo
 * .F. = restore Properties/Events tabs, show combo */
HB_FUNC( INS_SETDEBUGMODE )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   BOOL bDebug = hb_parl(2);
   if( !d ) return;

   d->bDebugMode = bDebug;
   if( bDebug )
   {
      [d->tabCtrl setSegmentCount:3];
      [d->tabCtrl setLabel:@"Vars" forSegment:0];
      [d->tabCtrl setLabel:@"Call Stack" forSegment:1];
      [d->tabCtrl setLabel:@"Watch" forSegment:2];
      [d->tabCtrl setSelectedSegment:0];
      d->nTab = 0;
      [d->combo setHidden:YES];
      [d->window setTitle:@"Debugger"];

      /* Set Vars column headers and widths (tab 0 = Vars) */
      NSTableColumn * nc = [d->tableView tableColumnWithIdentifier:@"name"];
      NSTableColumn * vc = [d->tableView tableColumnWithIdentifier:@"value"];
      if( nc ) { [[nc headerCell] setStringValue:@"Variable"]; [nc setWidth:140]; }
      if( vc ) { [[vc headerCell] setStringValue:@"Value"]; [vc setWidth:130]; }

      /* Clear display */
      d->nDbgLocalsRows = 0;
      d->nDbgLocalsVisible = 0;
      d->nDbgStackRows = 0;
      d->nDbgStackVisible = 0;
      d->nVisible = 0;
      [d->tableView reloadData];
   }
   else
   {
      [d->tabCtrl setSegmentCount:2];
      [d->tabCtrl setLabel:@"Properties" forSegment:0];
      [d->tabCtrl setLabel:@"Events" forSegment:1];
      [d->tabCtrl setSelectedSegment:0];
      d->nTab = 0;
      [d->combo setHidden:NO];
      [d->window setTitle:@"Inspector"];
      NSTableColumn * nc = [d->tableView tableColumnWithIdentifier:@"name"];
      NSTableColumn * vc = [d->tableView tableColumnWithIdentifier:@"value"];
      if( nc ) { [[nc headerCell] setStringValue:@"Property"]; [nc setWidth:140]; }
      if( vc ) { [[vc headerCell] setStringValue:@"Value"]; [vc setWidth:130]; }
      [d->tableView reloadData];
   }
}

/* INS_SetDebugLocals( hInsData, cVarsStr )
 * Format: "VARS [PUBLIC] name=val(T) ... [PRIVATE] name=val(T) ... [LOCAL] name=val(T) ..." */
HB_FUNC( INS_SETDEBUGLOCALS )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   const char * str = hb_parc(2);
   if( !d || !str ) return;

   d->nDbgLocalsRows = 0;
   d->nDbgLocalsVisible = 0;

   /* Skip prefix */
   if( strncmp( str, "VARS", 4 ) == 0 ) str += 4;
   else if( strncmp( str, "LOCALS", 6 ) == 0 ) str += 6;
   while( *str == ' ' ) str++;

   while( *str )
   {
      if( d->nDbgLocalsRows >= MAX_ROWS ) break;

      /* Check for category header [PUBLIC], [PRIVATE], [LOCAL] */
      if( *str == '[' )
      {
         IROW * r = &d->dbgLocalsRows[d->nDbgLocalsRows];
         memset( r, 0, sizeof(IROW) );
         r->bIsCat = YES;
         r->bVisible = YES;
         r->bCollapsed = NO;
         str++;
         int ni = 0;
         while( *str && *str != ']' && ni < 31 ) r->szName[ni++] = *str++;
         r->szName[ni] = 0;
         if( *str == ']' ) str++;
         while( *str == ' ' ) str++;
         d->dbgLocalsMap[d->nDbgLocalsRows] = d->nDbgLocalsRows;
         d->nDbgLocalsRows++;
         d->nDbgLocalsVisible++;
         continue;
      }

      IROW * r = &d->dbgLocalsRows[d->nDbgLocalsRows];
      memset( r, 0, sizeof(IROW) );
      r->bVisible = YES;

      /* Extract name */
      int ni = 0;
      while( *str && *str != '=' && *str != ' ' && ni < 31 ) r->szName[ni++] = *str++;
      r->szName[ni] = 0;
      if( *str == '=' ) str++;

      /* Extract value(type) */
      int vi = 0;
      while( *str && *str != ' ' && vi < 255 ) r->szValue[vi++] = *str++;
      r->szValue[vi] = 0;
      while( *str == ' ' ) str++;

      r->cType = 'S';
      d->dbgLocalsMap[d->nDbgLocalsRows] = d->nDbgLocalsRows;
      d->nDbgLocalsRows++;
      d->nDbgLocalsVisible++;
   }

   /* If currently showing Vars tab (tab 0), update display */
   if( d->bDebugMode && d->nTab == 0 )
   {
      d->nVisible = d->nDbgLocalsVisible;
      memcpy( d->rows, d->dbgLocalsRows, sizeof(IROW) * (size_t)d->nDbgLocalsRows );
      memcpy( d->map, d->dbgLocalsMap, sizeof(int) * (size_t)d->nDbgLocalsVisible );
      d->nRows = d->nDbgLocalsRows;
      [d->tableView reloadData];
   }
}

/* INS_SetDebugStack( hInsData, cStackStr )
 * Format: "STACK func1(line1) func2(line2) ..." */
HB_FUNC( INS_SETDEBUGSTACK )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   const char * str = hb_parc(2);
   if( !d || !str ) return;

   d->nDbgStackRows = 0;
   d->nDbgStackVisible = 0;

   if( strncmp( str, "STACK", 5 ) == 0 ) str += 5;
   while( *str == ' ' ) str++;

   while( *str )
   {
      if( d->nDbgStackRows >= MAX_ROWS ) break;
      IROW * r = &d->dbgStackRows[d->nDbgStackRows];
      memset( r, 0, sizeof(IROW) );
      r->bVisible = YES;

      /* Name column: "#N" */
      snprintf( r->szName, sizeof(r->szName), "#%d", d->nDbgStackRows + 1 );

      /* Value: "FuncName(line)" */
      int vi = 0;
      while( *str && *str != ' ' && vi < 255 ) r->szValue[vi++] = *str++;
      r->szValue[vi] = 0;
      while( *str == ' ' ) str++;

      r->cType = 'S';
      d->dbgStackMap[d->nDbgStackRows] = d->nDbgStackRows;
      d->nDbgStackRows++;
      d->nDbgStackVisible++;
   }

   /* If showing Call Stack tab (tab 1), update display */
   if( d->bDebugMode && d->nTab == 1 )
   {
      d->nVisible = d->nDbgStackVisible;
      memcpy( d->rows, d->dbgStackRows, sizeof(IROW) * (size_t)d->nDbgStackRows );
      memcpy( d->map, d->dbgStackMap, sizeof(int) * (size_t)d->nDbgStackVisible );
      d->nRows = d->nDbgStackRows;
      [d->tableView reloadData];
   }
}
