# TReport Visual Designer (Option B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a visual report designer to HarbourBuilder where users place TBand controls on a TForm and TReportField controls inside bands, generating portable Harbour/TPrinter code.

**Architecture:** TBand is a TControl subclass — it reuses the existing form designer (drag/drop, inspector, code generation, two-way sync) with no structural changes. Bands auto-stack vertically by type order (Header→PageHeader→Detail→PageFooter→Footer), always span full form width, and contain TReportField children positioned relative to the band top. TReport:Print() iterates the design bands and fires TPrinter calls per field, keeping all rendering logic in Harbour for cross-platform portability.

**Tech Stack:** Harbour OOP (classes.prg), Cocoa/Objective-C (cocoa_core.m, cocoa_inspector.m), HarbourBuilder xcommand macros (hbbuilder.ch, hbide.ch), HarbourBuilder parser/generator (hbbuilder_macos.prg)

---

## File Map

| File | Change |
|------|--------|
| `include/hbide.ch` | Add `#define CT_BAND 132` |
| `include/hbbuilder.ch` | Replace old DEFINE BAND macro; add new BAND and REPORTFIELD xcommands |
| `source/core/classes.prg` | Add CLASS TBand (TControl subclass); extend TReportField with oBand + Render(); rewrite TReport:Print() with full band loop |
| `source/backends/cocoa/cocoa_core.m` | Add HBBand NSView class; CT_BAND palette entry; UI_BandNew / UI_BandGetType / UI_BandSetType / UI_BandSetLayout functions; CT_BAND case in HB_CreateComponent |
| `source/backends/cocoa/cocoa_inspector.m` | Add CT_BAND case in InsPopulateEvents; add BandType/Height/PrintOnEveryPage/Visible/BackColor properties wiring |
| `source/hbbuilder_macos.prg` | Add BAND parsing in RestoreFormFromCode; add REPORTFIELD parsing; add TBand/TReportField generation in RegenerateFormCode |
| `samples/projects/report/` | New sample: Report1.hbp, Project1.prg, Form1.prg |

---

### Task 1: Add CT_BAND constant and update macros

**Files:**
- Modify: `include/hbide.ch` — add CT_BAND constant
- Modify: `include/hbbuilder.ch` — replace old DEFINE BAND macro, add new BAND + REPORTFIELD xcommands

- [ ] **Step 1: Add CT_BAND to hbide.ch**

Open `include/hbide.ch`. Find the last `#define CT_` line (currently `#define CT_COMPARRAY  131` near line 172). Add immediately after:

```harbour
#define CT_BAND          132
```

- [ ] **Step 2: Replace old BAND macro in hbbuilder.ch**

Open `include/hbbuilder.ch`. Find the existing `#xcommand DEFINE BAND` block (lines ~435-441):

```harbour
#xcommand DEFINE BAND <oBand> NAME <cName> ;
      [ HEIGHT <nH> ] ;
      OF <oRpt> ;
   => ;
      <oBand> := TReportBand():New( <cName> ) ;
      [; <oBand>:nHeight := <nH> ] ;
      ; <oRpt>:AddDesignBand( <oBand> )
```

Replace it with the new visual-designer macro:

```harbour
#xcommand BAND <oVar> TYPE <cType> OF <oParent> HEIGHT <nH> => ;
   <oVar> := TBand():New( <oParent>, <cType>, <nH> )
```

- [ ] **Step 3: Add REPORTFIELD macro to hbbuilder.ch**

After the BAND xcommand above, add:

```harbour
#xcommand REPORTFIELD <oVar> TYPE <cType> ;
      [ PROMPT <cText> ] ;
      [ FIELD <cField> ] ;
      [ FORMAT <cFmt> ] ;
      OF <oBand> ;
      AT <nTop>, <nLeft> SIZE <nW> [, <nH>] ;
      [ FONT <cFont> [, <nFSize>] ] ;
      [ BOLD ] [ ITALIC ] ;
      [ ALIGN <nAlign> ] ;
   => ;
   <oVar> := TReportField():New() ;; ;
   <oVar>:cFieldType := <cType> ;; ;
   [ <oVar>:cText      := <cText> ;; ] ;
   [ <oVar>:cFieldName := <cField> ;; ] ;
   [ <oVar>:cFormat    := <cFmt> ;; ] ;
   <oVar>:nTop    := <nTop> ; <oVar>:nLeft   := <nLeft> ;; ;
   <oVar>:nWidth  := <nW>   ; <oVar>:nHeight := <nH> ;; ;
   [ <oVar>:cFontName := <cFont> ; <oVar>:nFontSize := <nFSize> ;; ] ;
   [ <oVar>:lBold   := .T. ;; ] ;
   [ <oVar>:lItalic := .T. ;; ] ;
   [ <oVar>:nAlignment := <nAlign> ;; ] ;
   <oBand>:AddField( <oVar> )
```

- [ ] **Step 4: Build and verify no compile errors**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -20
```

Expected: Build succeeds (CT_BAND=132 is an integer constant; macros compile if syntactically correct).

- [ ] **Step 5: Commit**

```bash
git add include/hbide.ch include/hbbuilder.ch
git commit -m "feat: add CT_BAND constant and BAND/REPORTFIELD xcommand macros"
```

---

### Task 2: TBand class in classes.prg

**Files:**
- Modify: `source/core/classes.prg` — add TBand class after existing TReportBand

- [ ] **Step 1: Locate insertion point**

Open `source/core/classes.prg`. Find the line where `CLASS TReportBand` ends (around line 3002 in the built copy — the source file at `source/core/classes.prg` may differ). Look for `ENDCLASS` after TReportBand's methods. Insert TBand after that ENDCLASS.

- [ ] **Step 2: Add TBand class**

Insert the following class definition after TReportBand's ENDCLASS:

```harbour
//--------------------------------------------------------------------
// TBand — visual designer control (TControl subclass, auto-stacked)
//--------------------------------------------------------------------

CLASS TBand FROM TControl

   DATA cBandType          INIT "Detail"
   DATA lPrintOnEveryPage  INIT .F.
   DATA lVisible           INIT .T.
   DATA nBackColor         INIT -1
   DATA aFields            INIT {}
   DATA bOnPrint
   DATA bOnAfterPrint

   METHOD New( oParent, cType, nHeight )
   METHOD AddField( oField )
   METHOD RemoveField( nIndex )
   METHOD FieldCount()
   METHOD BandOrder()

ENDCLASS

METHOD New( oParent, cType, nHeight ) CLASS TBand
   local nOrder, nColor
   ::Super:New( oParent )
   ::nType       := CT_BAND
   ::cBandType   := iif( ValType( cType ) == "C", cType, "Detail" )
   ::nHeight     := iif( ValType( nHeight ) == "N", nHeight, 20 )
   ::nLeft       := 0
   ::nTop        := 0
   ::nWidth      := iif( oParent != nil, oParent:nWidth, 600 )
   nOrder        := ::BandOrder()
   ::lPrintOnEveryPage := ( nOrder == 2 .or. nOrder == 4 )
   do case
   case ::cBandType == "Header"     ; nColor := UI_RGB( 173, 216, 230 )  // light blue
   case ::cBandType == "PageHeader" ; nColor := UI_RGB( 144, 238, 144 )  // light green
   case ::cBandType == "Detail"     ; nColor := UI_RGB( 255, 255, 255 )  // white
   case ::cBandType == "PageFooter" ; nColor := UI_RGB( 144, 238, 144 )  // light green
   case ::cBandType == "Footer"     ; nColor := UI_RGB( 211, 211, 211 )  // light gray
   otherwise                        ; nColor := UI_RGB( 255, 255, 255 )
   endcase
   ::nBackColor := nColor
   if oParent != nil
      oParent:AddControl( Self )
   endif
return Self

METHOD AddField( oField ) CLASS TBand
   oField:oBand := Self
   AAdd( ::aFields, oField )
return nil

METHOD RemoveField( nIndex ) CLASS TBand
   ADel( ::aFields, nIndex )
   ASize( ::aFields, Len( ::aFields ) - 1 )
return nil

METHOD FieldCount() CLASS TBand
return Len( ::aFields )

METHOD BandOrder() CLASS TBand
   do case
   case ::cBandType == "Header"     ; return 1
   case ::cBandType == "PageHeader" ; return 2
   case ::cBandType == "Detail"     ; return 3
   case ::cBandType == "PageFooter" ; return 4
   case ::cBandType == "Footer"     ; return 5
   endcase
return 3
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | grep -E "error|warning|TBand"
```

Expected: No errors about TBand. Class compiles cleanly.

- [ ] **Step 4: Commit**

```bash
git add source/core/classes.prg
git commit -m "feat: add TBand class (TControl subclass) with auto-stack and band type support"
```

---

### Task 3: TReportField:Render() + TReport:Print() loop

**Files:**
- Modify: `source/core/classes.prg` — extend TReportField with oBand + Render(); rewrite TReport:Print()

- [ ] **Step 1: Add oBand and Render() to TReportField**

In `source/core/classes.prg`, find `CLASS TReportField` (around line 3030 in the built copy). Add `DATA oBand INIT nil` to the DATA declarations. Add `METHOD Render( oPrinter, nBaseY, oDataSource )` to the METHOD declarations.

After TReportField's existing methods (before its ENDCLASS), add:

```harbour
METHOD Render( oPrinter, nBaseY, oDataSource ) CLASS TReportField
   local nAbsY := nBaseY + ::nTop
   local cVal
   do case
   case ::cFieldType == "label"
      oPrinter:PrintLine( nAbsY, ::nLeft, ::cText, ::cFontName, ::nFontSize, ::lBold, ::lItalic )
   case ::cFieldType == "data"
      cVal := ::GetValue( oDataSource )
      oPrinter:PrintLine( nAbsY, ::nLeft, cVal, ::cFontName, ::nFontSize, ::lBold, ::lItalic )
   case ::cFieldType == "image"
      oPrinter:PrintImage( nAbsY, ::nLeft, ::nWidth, ::nHeight, ::cText )
   case ::cFieldType == "line"
      oPrinter:PrintRect( nAbsY, ::nLeft, ::nWidth, ::nBorderWidth )
   endcase
return nil
```

- [ ] **Step 2: Extend TReport class DATA**

Find `CLASS TReport` in `source/core/classes.prg`. In its DATA declarations add:

```harbour
DATA nCurrentY     INIT 0
DATA nCurrentPage  INIT 0
DATA nUsableHeight INIT 0
```

Add METHOD declarations:
```harbour
METHOD RenderBand( oBand )
METHOD GetDesignBand( cType )
```

- [ ] **Step 3: Rewrite TReport:Print()**

Find `METHOD Print() CLASS TReport` (around line 2608 in built copy). Replace the entire method with:

```harbour
METHOD Print() CLASS TReport
   local oBand, oField

   ::nCurrentPage  := 0
   ::nCurrentY     := ::nMarginTop
   ::nUsableHeight := ::nPageHeight - ::nMarginTop - ::nMarginBottom

   ::oPrinter:BeginDoc( ::cTitle )
   ::nCurrentPage := 1

   ::RenderBand( ::GetDesignBand( "Header" ) )
   ::RenderBand( ::GetDesignBand( "PageHeader" ) )

   if ::oDataSource != nil
      ::oDataSource:GoFirst()
      while ! ::oDataSource:Eof()
         oBand := ::GetDesignBand( "Detail" )
         if oBand != nil .and. ::nCurrentY + oBand:nHeight > ::nMarginTop + ::nUsableHeight
            ::RenderBand( ::GetDesignBand( "PageFooter" ) )
            ::oPrinter:NewPage()
            ::nCurrentPage++
            ::nCurrentY := ::nMarginTop
            ::RenderBand( ::GetDesignBand( "PageHeader" ) )
         endif
         ::RenderBand( oBand )
         ::oDataSource:Skip()
      enddo
   endif

   ::RenderBand( ::GetDesignBand( "PageFooter" ) )
   ::RenderBand( ::GetDesignBand( "Footer" ) )

   ::oPrinter:EndDoc()
return nil

METHOD RenderBand( oBand ) CLASS TReport
   local oField
   if oBand == nil .or. ! oBand:lVisible
      return nil
   endif
   if oBand:bOnPrint != nil
      Eval( oBand:bOnPrint )
   endif
   for each oField in oBand:aFields
      oField:Render( ::oPrinter, ::nCurrentY, ::oDataSource )
   next
   ::nCurrentY += oBand:nHeight
   if oBand:bOnAfterPrint != nil
      Eval( oBand:bOnAfterPrint )
   endif
return nil

METHOD GetDesignBand( cType ) CLASS TReport
   local oBand
   for each oBand in ::aBands
      if oBand:cBandType == cType
         return oBand
      endif
   next
return nil
```

Note: `::aBands` holds the TBand controls attached to this report. The wiring (`::oReport1:aBands := ...`) is set up in the form's CreateForm() generated code or OnStartClick handler.

- [ ] **Step 4: Build and verify**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | grep -iE "error|treport|treportfield"
```

Expected: No errors; Print(), RenderBand(), GetDesignBand() compile cleanly.

- [ ] **Step 5: Commit**

```bash
git add source/core/classes.prg
git commit -m "feat: add TReportField:Render(), extend TReport with full band-loop Print()"
```

---

### Task 4: HBBand NSView in cocoa_core.m

**Files:**
- Modify: `source/backends/cocoa/cocoa_core.m` — add HBBand NSView subclass; palette entry; UI functions; CT_BAND case in component creation

- [ ] **Step 1: Add HBBand NSView class**

In `source/backends/cocoa/cocoa_core.m`, find where other HBControl subclasses are defined (e.g., HBButton, HBLabel). Add the following HBBand class in the same section:

```objc
//--------------------------------------------------------------------
// HBBand — NSView for TBand (auto-stacked report band)
//--------------------------------------------------------------------

@interface HBBand : HBControl
@property (nonatomic, copy) NSString * bandType;
@end

@implementation HBBand

- (instancetype)initWithFrame:(NSRect)frame bandType:(NSString *)type
{
    self = [super initWithFrame:frame];
    if (self) {
        _bandType = type ? type : @"Detail";
        self.wantsLayer = YES;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    NSColor * bg;
    if      ([_bandType isEqualToString:@"Header"])     bg = [NSColor colorWithRed:0.678 green:0.847 blue:0.902 alpha:1.0]; // light blue
    else if ([_bandType isEqualToString:@"PageHeader"]) bg = [NSColor colorWithRed:0.565 green:0.933 blue:0.565 alpha:1.0]; // light green
    else if ([_bandType isEqualToString:@"PageFooter"]) bg = [NSColor colorWithRed:0.565 green:0.933 blue:0.565 alpha:1.0]; // light green
    else if ([_bandType isEqualToString:@"Footer"])     bg = [NSColor colorWithRed:0.827 green:0.827 blue:0.827 alpha:1.0]; // light gray
    else                                                bg = [NSColor whiteColor]; // Detail
    [bg setFill];
    NSRectFill(dirtyRect);

    // Draw type label centered
    NSDictionary * attrs = @{
        NSFontAttributeName:            [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.3 alpha:0.7]
    };
    NSString * label = [NSString stringWithFormat:@"[ %@ ]", _bandType];
    NSSize sz = [label sizeWithAttributes:attrs];
    NSPoint pt = NSMakePoint(
        (self.bounds.size.width  - sz.width)  / 2,
        (self.bounds.size.height - sz.height) / 2
    );
    [label drawAtPoint:pt withAttributes:attrs];

    // Draw bottom resize handle line
    NSColor * border = [NSColor colorWithWhite:0.5 alpha:0.5];
    [border setStroke];
    NSBezierPath * path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(0, 0)];
    [path lineToPoint:NSMakePoint(self.bounds.size.width, 0)];
    [path setLineWidth:1.0];
    [path stroke];
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

@end
```

- [ ] **Step 2: Add CT_BAND palette entry**

Find the palette `defs[]` table in `source/backends/cocoa/cocoa_core.m` (around line 3185 in the built copy — search for `static struct { int type`). Add a CT_BAND entry:

```c
{ CT_BAND,   "TBand",  "Band",   600, 24 },
```

Place it logically after the last report-related entry (CT_REPORT or CT_PRINTER). The palette width 600 and height 24 are the defaults dropped onto the form.

- [ ] **Step 3: Add UI_BandNew, UI_BandGetType, UI_BandSetType functions**

Find a natural location near other component-specific UI functions. Add:

```objc
HB_FUNC( UI_BANDNEW )
{
    // params: parent view handle, bandType string, x, y, w, h
    NSView * parent = (__bridge NSView *)(void *)hb_parnl(1);
    const char * cType = hb_parc(2);
    CGFloat x = hb_parnd(3), y = hb_parnd(4), w = hb_parnd(5), h = hb_parnd(6);
    NSRect frame = NSMakeRect(x, y, w, h);
    NSString * type = cType ? [NSString stringWithUTF8String:cType] : @"Detail";
    HBBand * band = [[HBBand alloc] initWithFrame:frame bandType:type];
    if (parent) [parent addSubview:band];
    hb_retnl((NSInteger)(__bridge_retained void *)band);
}

HB_FUNC( UI_BANDGETTYPE )
{
    HBBand * band = (__bridge HBBand *)(void *)hb_parnl(1);
    hb_retc(band ? [band.bandType UTF8String] : "Detail");
}

HB_FUNC( UI_BANDSETTYPE )
{
    HBBand * band = (__bridge HBBand *)(void *)hb_parnl(1);
    const char * cType = hb_parc(2);
    if (band && cType) {
        band.bandType = [NSString stringWithUTF8String:cType];
        [band setNeedsDisplay:YES];
    }
}

HB_FUNC( UI_BANDSETLAYOUT )
{
    // Called after any band height change to restack all bands on the parent form
    HBBand * band = (__bridge HBBand *)(void *)hb_parnl(1);
    if (!band) return;
    NSView * parent = [band superview];
    if (!parent) return;
    CGFloat y = 0;
    NSArray * subs = [parent subviews];
    // Collect all HBBand subviews, sort by bandType order, reposition
    NSMutableArray * bands = [NSMutableArray array];
    for (NSView * v in subs) {
        if ([v isKindOfClass:[HBBand class]]) [bands addObject:v];
    }
    NSDictionary * order = @{ @"Header":@1, @"PageHeader":@2, @"Detail":@3, @"PageFooter":@4, @"Footer":@5 };
    [bands sortUsingComparator:^NSComparisonResult(HBBand * a, HBBand * b) {
        return [order[a.bandType] compare:order[b.bandType]];
    }];
    for (HBBand * b in bands) {
        NSRect f = b.frame;
        f.origin.x = 0;
        f.origin.y = y;
        f.size.width = parent.bounds.size.width;
        b.frame = f;
        y += f.size.height;
    }
}
```

- [ ] **Step 4: Add CT_BAND case in HB_CreateComponent**

Find the `HB_FUNC( HB_CreateComponent )` function (or equivalent component creation switch). It has cases for CT_BUTTON, CT_LABEL, etc. Add:

```c
case CT_BAND:
{
    const char * cType = hb_parc(3);  // 3rd param = band type string
    NSString * type = cType ? [NSString stringWithUTF8String:cType] : @"Detail";
    HBBand * band = [[HBBand alloc] initWithFrame:frame bandType:type];
    if (parent) [parent addSubview:band];
    handle = (NSInteger)(__bridge_retained void *)band;
    break;
}
```

Adjust param indices to match the existing convention in that function.

- [ ] **Step 5: Build and verify**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | grep -iE "error|HBBand|UI_BAND"
```

Expected: No errors; HBBand compiles; UI_BANDNEW / UI_BANDGETTYPE / UI_BANDSETTYPE / UI_BANDSETLAYOUT link.

- [ ] **Step 6: Smoke-test palette entry**

```bash
cp /Users/usuario/HarbourBuilder/HbBuilder /Users/usuario/HarbourBuilder/bin/ && cd /Users/usuario/HarbourBuilder/bin && ./HbBuilder &
```

Open the IDE, check that a "Band" entry appears in the component palette. Dragging it onto a form should create a colored strip.

- [ ] **Step 7: Commit**

```bash
git add source/backends/cocoa/cocoa_core.m
git commit -m "feat(mac): add HBBand NSView, CT_BAND palette entry, UI_Band* functions"
```

---

### Task 5: Inspector properties and events for CT_BAND

**Files:**
- Modify: `source/backends/cocoa/cocoa_inspector.m` — add CT_BAND case in InsPopulateEvents; wire BandType/Height/PrintOnEveryPage/Visible/BackColor properties

- [ ] **Step 1: Add CT_BAND to InsPopulateEvents**

Open `source/backends/cocoa/cocoa_inspector.m`. Find `InsPopulateEvents` (around line 1493 in built copy). Find the switch statement with CT_* cases. Using `CT_PRINTER` (lines ~1687-1695) as a model, add a CT_BAND case:

```objc
case CT_BAND:
    hb_vmPushDynSym( hb_dynsymFindName("INSADDEVENT") );
    hb_vmPushNil();
    hb_vmPushString("OnPrint", 7);
    hb_vmDo(1);
    hb_vmPushDynSym( hb_dynsymFindName("INSADDEVENT") );
    hb_vmPushNil();
    hb_vmPushString("OnAfterPrint", 12);
    hb_vmDo(1);
    break;
```

(Adjust to match the exact calling convention used in existing CT_PRINTER case.)

- [ ] **Step 2: Add BandType property inspector wiring**

In `source/backends/cocoa/cocoa_inspector.m`, find where properties are populated for individual control types (search for `CT_BUTTON` or `CT_LABEL` in property-related code). The inspector reads properties dynamically via `UI_GETALLPROPS`, so properties declared as `DATA` in the Harbour class are picked up automatically.

However, BandType is an enum — verify the inspector can display enum choices. If the inspector has special handling for enum properties (e.g., via a `cPropType` or similar mechanism), add:

```c
// BandType enum values for CT_BAND
// These may need to be registered in the inspector's prop-type registry
// Check how CT_COMBOBOX "Style" or similar enum props are registered
```

If no special registration is needed (the inspector shows a text field for string DATA), this step is a no-op — BandType will be editable as a plain string.

- [ ] **Step 3: Verify inspector shows band properties**

Build and run. Click a TBand on the form. The Inspector should show:
- Properties tab: cBandType, nHeight, lPrintOnEveryPage, lVisible, nBackColor
- Events tab: OnPrint, OnAfterPrint

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | grep -iE "error|inspector"
```

- [ ] **Step 4: Commit**

```bash
git add source/backends/cocoa/cocoa_inspector.m
git commit -m "feat(mac): add CT_BAND inspector events (OnPrint, OnAfterPrint)"
```

---

### Task 6: RestoreFormFromCode — parse BAND and REPORTFIELD lines

**Files:**
- Modify: `source/hbbuilder_macos.prg` — add BAND and REPORTFIELD parsing in RestoreFormFromCode

- [ ] **Step 1: Locate parsing loop in RestoreFormFromCode**

Open `source/hbbuilder_macos.prg`. Find `RestoreFormFromCode` (around line 1350). It iterates form code lines matching patterns like `"COMPONENT "`, `"@ "`, `"BUTTON "`, etc. Find the section that creates controls from line patterns.

- [ ] **Step 2: Add BAND line parsing**

In the parsing loop, after the COMPONENT parsing block (or in a logical position for non-@ controls), add:

```harbour
// Parse: BAND ::oX TYPE "Header" OF Self HEIGHT 40
if Left( cLine, 5 ) == "BAND "
   local cVarName, cType, nHeight
   // Extract variable name (token after "BAND ")
   cVarName := hb_TokenGet( cLine, 2 )                 // "::oBand1"
   // Extract TYPE value (after TYPE keyword)
   cType    := ExtractQuotedAfter( cLine, "TYPE" )     // "Header"
   // Extract HEIGHT value (last token)
   nHeight  := Val( hb_TokenGet( cLine, Len( hb_ATokens( cLine, " " ) ) ) )
   // Create TBand control on the form
   local oBand := TBand():New( oForm, cType, nHeight )
   SetFormVar( oForm, cVarName, oBand )
   UI_BANDSETLAYOUT( oBand:hWnd )    // restack
   loop
endif
```

Note: `ExtractQuotedAfter` and `SetFormVar` are existing helper functions in hbbuilder_macos.prg — adapt to the actual helper names used there. Check how existing COMPONENT parsing extracts strings and assigns DATA variables.

- [ ] **Step 3: Add REPORTFIELD line parsing**

After the BAND parsing block, add REPORTFIELD parsing:

```harbour
// Parse: REPORTFIELD ::oFld TYPE "label" PROMPT "X" OF ::oBand1 AT 5,10 SIZE 80,14
if Left( cLine, 12 ) == "REPORTFIELD "
   local cVarName, cFType, cText, cField, cFmt, cBandVar
   local nTop, nLeft, nW, nH, cFont, nFSize
   local lBold, lItalic, nAlign
   local oField, oBand
   cVarName := hb_TokenGet( cLine, 2 )              // "::oFld1"
   cFType   := ExtractQuotedAfter( cLine, "TYPE" )  // "label"
   cText    := ExtractQuotedAfter( cLine, "PROMPT" )
   cField   := ExtractQuotedAfter( cLine, "FIELD" )
   cFmt     := ExtractQuotedAfter( cLine, "FORMAT" )
   cBandVar := ExtractTokenAfter( cLine, "OF" )     // "::oBand1"
   // AT nTop, nLeft SIZE nW, nH
   ParseAtSize( cLine, @nTop, @nLeft, @nW, @nH )
   cFont    := ExtractQuotedAfter( cLine, "FONT" )
   nFSize   := Val( ExtractTokenAfterComma( cLine, "FONT" ) )
   lBold    := ( "BOLD"   $ cLine )
   lItalic  := ( "ITALIC" $ cLine )
   nAlign   := iif( "ALIGN" $ cLine, Val( ExtractTokenAfter( cLine, "ALIGN" ) ), 0 )
   oField := TReportField():New()
   oField:cFieldType  := cFType
   oField:cText       := cText
   oField:cFieldName  := cField
   oField:cFormat     := cFmt
   oField:nTop        := nTop
   oField:nLeft       := nLeft
   oField:nWidth      := nW
   oField:nHeight     := nH
   oField:cFontName   := cFont
   oField:nFontSize   := nFSize
   oField:lBold       := lBold
   oField:lItalic     := lItalic
   oField:nAlignment  := nAlign
   oBand := GetFormVar( oForm, cBandVar )
   if oBand != nil
      oBand:AddField( oField )
   endif
   SetFormVar( oForm, cVarName, oField )
   loop
endif
```

Again — adapt `ExtractQuotedAfter`, `ExtractTokenAfter`, `ParseAtSize`, `GetFormVar`, `SetFormVar` to whatever helpers actually exist in the file. The pattern is the same used for COMPONENT and control parsing.

- [ ] **Step 4: Build and smoke-test round-trip**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | grep -iE "error"
```

Run the IDE. Place a TBand on a form, save the project, close and reopen. The band should be restored correctly.

- [ ] **Step 5: Commit**

```bash
git add source/hbbuilder_macos.prg
git commit -m "feat: parse BAND and REPORTFIELD lines in RestoreFormFromCode"
```

---

### Task 7: RegenerateFormCode — emit BAND and REPORTFIELD lines

**Files:**
- Modify: `source/hbbuilder_macos.prg` — add TBand/TReportField output in RegenerateFormCode

- [ ] **Step 1: Locate code generation loop**

In `source/hbbuilder_macos.prg`, find `RegenerateFormCode` (around line 636). It iterates the form's controls and emits xcommand lines for each type. Find where it handles CT_COMPONENT (non-visual) and regular `@ row,col` controls.

- [ ] **Step 2: Add BAND code generation**

In the control iteration loop, add a case for TBand (CT_BAND):

```harbour
case oCtrl:nType == CT_BAND
   // Emit: BAND ::oBand1 TYPE "Header" OF Self HEIGHT 40
   cCode += "   BAND " + oCtrl:cName + ' TYPE "' + oCtrl:cBandType + '"' + ;
            " OF Self HEIGHT " + hb_ntos( oCtrl:nHeight ) + Chr(13)+Chr(10)
```

Insert this BEFORE the general control loop so bands are emitted after COMPONENT lines but before regular controls. Use the generation order from the spec:
1. COMPONENT lines
2. BAND lines (sorted by BandOrder())
3. REPORTFIELD lines (grouped by band)
4. Event wiring

- [ ] **Step 3: Sort bands by BandOrder() before emitting**

Before the band emission loop, sort the form's band controls:

```harbour
// Collect and sort bands
local aBands := {}
for each oCtrl in oForm:aControls
   if oCtrl:nType == CT_BAND
      AAdd( aBands, oCtrl )
   endif
next
ASort( aBands,,, {|a,b| a:BandOrder() < b:BandOrder()} )
for each oBand in aBands
   cCode += "   BAND " + oBand:cName + ' TYPE "' + oBand:cBandType + '"' + ;
            " OF Self HEIGHT " + hb_ntos( oBand:nHeight ) + Chr(13)+Chr(10)
next
```

- [ ] **Step 4: Add REPORTFIELD code generation**

After the BAND emission loop, emit REPORTFIELD lines grouped by band:

```harbour
for each oBand in aBands
   for each oFld in oBand:aFields
      cLine := "   REPORTFIELD " + oFld:cName + ' TYPE "' + oFld:cFieldType + '"'
      if !Empty( oFld:cText )
         cLine += ' PROMPT "' + oFld:cText + '"'
      endif
      if !Empty( oFld:cFieldName )
         cLine += ' FIELD "' + oFld:cFieldName + '"'
      endif
      if !Empty( oFld:cFormat )
         cLine += ' FORMAT "' + oFld:cFormat + '"'
      endif
      cLine += " OF " + oBand:cName
      cLine += " AT " + hb_ntos( oFld:nTop ) + "," + hb_ntos( oFld:nLeft )
      cLine += " SIZE " + hb_ntos( oFld:nWidth ) + "," + hb_ntos( oFld:nHeight )
      if !Empty( oFld:cFontName )
         cLine += ' FONT "' + oFld:cFontName + '"'
         if oFld:nFontSize > 0
            cLine += "," + hb_ntos( oFld:nFontSize )
         endif
      endif
      if oFld:lBold;   cLine += " BOLD";   endif
      if oFld:lItalic; cLine += " ITALIC"; endif
      if oFld:nAlignment > 0
         cLine += " ALIGN " + hb_ntos( oFld:nAlignment )
      endif
      cCode += cLine + Chr(13)+Chr(10)
   next
next
```

- [ ] **Step 5: Build and full round-trip test**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | grep -iE "error"
```

Run the IDE. Create a form with a Header band (height=40) containing a label field "Test". Save, reopen. The generated code should contain:
```
BAND ::oBand1 TYPE "Header" OF Self HEIGHT 40
REPORTFIELD ::oFld1 TYPE "label" PROMPT "Test" OF ::oBand1 AT 0,5 SIZE 100,16
```
Close and reopen the project — it should restore correctly.

- [ ] **Step 6: Commit**

```bash
git add source/hbbuilder_macos.prg
git commit -m "feat: emit BAND and REPORTFIELD lines in RegenerateFormCode"
```

---

### Task 8: Sample project — Product Inventory report

**Files:**
- Create: `samples/projects/report/Report1.hbp`
- Create: `samples/projects/report/Project1.prg`
- Create: `samples/projects/report/Form1.prg`

- [ ] **Step 1: Create Report1.hbp**

```
[Files]
Project1.prg
Form1.prg
```

- [ ] **Step 2: Create Project1.prg**

```harbour
// Project1.prg — Report Designer Demo
#include "hbbuilder.ch"

procedure Main()
   local oApp := TApplication():New()
   local oForm := TForm1():New()
   oForm:Show()
   oApp:Run()
return
```

- [ ] **Step 3: Create Form1.prg**

```harbour
// Form1.prg — Product Inventory Report
#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   DATA oPrinter1
   DATA oReport1
   DATA oBand1         // Header
   DATA oBand2         // PageHeader
   DATA oBand3         // Detail
   DATA oBand4         // PageFooter
   DATA oBand5         // Footer
   DATA oFldTitle      // Header: title label
   DATA oFldDate       // Header: date expression
   DATA oFldHdrName    // PageHeader: "Name" column label
   DATA oFldHdrPrice   // PageHeader: "Price" column label
   DATA oFldHdrStock   // PageHeader: "Stock" column label
   DATA oFldSep1       // PageHeader: separator line
   DATA oFldName       // Detail: NAME field
   DATA oFldPrice      // Detail: PRICE field
   DATA oFldStock      // Detail: STOCK field
   DATA oFldPageNo     // PageFooter: page number
   DATA oFldEnd        // Footer: "End of Report" label
   DATA oFldSep2       // Footer: separator line
   DATA oBtnPrint      // TButton
   DATA oBtnSetup      // TButton
   DATA oLog           // TMemo

   METHOD CreateForm()
   METHOD OnStartClick()
   METHOD OnSetupClick()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::Title  := "Report Designer Demo"
   ::Left   := 100
   ::Top    := 100
   ::Width  := 640
   ::Height := 580

   COMPONENT ::oPrinter1 TYPE CT_PRINTER OF Self
   COMPONENT ::oReport1  TYPE CT_REPORT  OF Self

   // Bands
   BAND ::oBand1 TYPE "Header"     OF Self HEIGHT 40
   BAND ::oBand2 TYPE "PageHeader" OF Self HEIGHT 24
   BAND ::oBand3 TYPE "Detail"     OF Self HEIGHT 18
   BAND ::oBand4 TYPE "PageFooter" OF Self HEIGHT 20
   BAND ::oBand5 TYPE "Footer"     OF Self HEIGHT 30

   // Header fields
   REPORTFIELD ::oFldTitle  TYPE "label" PROMPT "Product Inventory" ;
      OF ::oBand1 AT 12, 10 SIZE 300, 16 FONT ".AppleSystemUIFont", 14 BOLD

   REPORTFIELD ::oFldDate   TYPE "data"  FIELD "DToC(Date())" ;
      OF ::oBand1 AT 12, 480 SIZE 130, 16 FONT ".AppleSystemUIFont", 11

   // PageHeader fields
   REPORTFIELD ::oFldSep1   TYPE "line" ;
      OF ::oBand2 AT 22, 0 SIZE 620, 1

   REPORTFIELD ::oFldHdrName  TYPE "label" PROMPT "Name" ;
      OF ::oBand2 AT 4, 10  SIZE 200, 14 BOLD

   REPORTFIELD ::oFldHdrPrice TYPE "label" PROMPT "Price" ;
      OF ::oBand2 AT 4, 220 SIZE 80,  14 BOLD ALIGN 2

   REPORTFIELD ::oFldHdrStock TYPE "label" PROMPT "Stock" ;
      OF ::oBand2 AT 4, 310 SIZE 60,  14 BOLD ALIGN 2

   // Detail fields
   REPORTFIELD ::oFldName   TYPE "data" FIELD "NAME" ;
      OF ::oBand3 AT 2, 10  SIZE 200, 14

   REPORTFIELD ::oFldPrice  TYPE "data" FIELD "PRICE" FORMAT "999,999.99" ;
      OF ::oBand3 AT 2, 220 SIZE 80,  14 ALIGN 2

   REPORTFIELD ::oFldStock  TYPE "data" FIELD "STOCK" ;
      OF ::oBand3 AT 2, 310 SIZE 60,  14 ALIGN 2

   // PageFooter fields
   REPORTFIELD ::oFldPageNo TYPE "data" FIELD "hb_ntos( ::oReport1:nCurrentPage )" ;
      OF ::oBand4 AT 4, 280 SIZE 60, 14 ALIGN 2

   // Footer fields
   REPORTFIELD ::oFldSep2   TYPE "line" ;
      OF ::oBand5 AT 4, 0 SIZE 620, 1

   REPORTFIELD ::oFldEnd    TYPE "label" PROMPT "End of Report" ;
      OF ::oBand5 AT 10, 220 SIZE 200, 16 BOLD

   // Buttons and log (below bands)
   @ 500, 10  BUTTON ::oBtnPrint OF Self PROMPT "Print"       SIZE 100, 30
   @ 500, 120 BUTTON ::oBtnSetup OF Self PROMPT "Printer Setup" SIZE 120, 30
   @ 540, 10  MEMO   ::oLog      OF Self SIZE 610, 30

   // Wiring
   ::oReport1:oPrinter := ::oPrinter1
   ::oReport1:cTitle   := "Product Inventory"
   ::oReport1:aBands   := { ::oBand1, ::oBand2, ::oBand3, ::oBand4, ::oBand5 }
   ::oBtnPrint:OnClick := { || ::OnStartClick() }
   ::oBtnSetup:OnClick := { || ::OnSetupClick() }

return nil
//--------------------------------------------------------------------

METHOD OnStartClick() CLASS TForm1
   local aP, oDS
   // Create test DBF if not present
   if ! hb_FileExists( "products.dbf" )
      DBCreate( "products", { {"NAME","C",30,0}, {"PRICE","N",10,2}, {"STOCK","N",6,0} } )
      USE products
      APPEND BLANK; REPLACE NAME WITH "Widget A", PRICE WITH 12.50, STOCK WITH 100
      APPEND BLANK; REPLACE NAME WITH "Gadget B", PRICE WITH 99.95, STOCK WITH 25
      APPEND BLANK; REPLACE NAME WITH "Doohickey C", PRICE WITH 5.00, STOCK WITH 500
      CLOSE
   endif
   USE products
   ::oReport1:oDataSource := Select()   // or pass a TDatabase object
   ::oReport1:nPageWidth  := 612
   ::oReport1:nPageHeight := 792
   ::oReport1:nMarginLeft := 20
   ::oReport1:nMarginRight := 20
   ::oReport1:nMarginTop  := 20
   ::oReport1:nMarginBottom := 20
   ::oReport1:Print()
   USE
   ::oLog:Text += "Printed." + Chr(13)+Chr(10)
return nil

METHOD OnSetupClick() CLASS TForm1
   ::oPrinter1:ShowPrintPanel()
return nil
```

- [ ] **Step 4: Build the sample project from the IDE**

Run the IDE, open `samples/projects/report/Report1.hbp`, press Run. Verify it compiles without errors.

- [ ] **Step 5: Commit**

```bash
git add samples/projects/report/
git commit -m "feat(samples): add Product Inventory report designer demo"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| CT_BAND constant | Task 1 |
| BAND xcommand macro | Task 1 |
| REPORTFIELD xcommand macro | Task 1 |
| TBand class (TControl subclass) with 5 band types | Task 2 |
| TBand auto-stack by BandOrder() | Task 2 + Task 4 (UI_BANDSETLAYOUT) |
| TBand lPrintOnEveryPage auto-set | Task 2 |
| TBand background color per type | Task 2 + Task 4 (drawRect:) |
| TBand band label in design mode | Task 4 (drawRect:) |
| TReportField:Render() with 4 field types | Task 3 |
| TReport:Print() full band loop with page break | Task 3 |
| TReport:RenderBand() / GetDesignBand() | Task 3 |
| HBBand NSView palette entry | Task 4 |
| UI_BandNew / UI_BandGetType / UI_BandSetType | Task 4 |
| CT_BAND in HB_CreateComponent | Task 4 |
| Inspector OnPrint / OnAfterPrint events | Task 5 |
| RestoreFormFromCode BAND parsing | Task 6 |
| RestoreFormFromCode REPORTFIELD parsing | Task 6 |
| RegenerateFormCode BAND output | Task 7 |
| RegenerateFormCode REPORTFIELD output | Task 7 |
| Sample project with all 5 band types | Task 8 |

**Out of scope confirmed not in plan:** GroupHeader/Footer, sub-reports, export, undo/redo, zoom/rulers, summary fields, conditional formatting.

**Type consistency:** TBand:BandOrder() returns integer (1-5); sort comparator uses `<`; ASort call in Task 7 matches. TBand:aFields holds TReportField objects; RenderBand iterates `oBand:aFields` — consistent. `::oReport1:aBands` set in Form1.prg wiring and iterated in GetDesignBand() — consistent.

**Potential gaps:**
- `ExtractQuotedAfter`, `ParseAtSize`, `GetFormVar`, `SetFormVar` in Task 6/7: these are placeholders for actual helpers. The implementer must read RestoreFormFromCode/RegenerateFormCode and adapt to whatever string-parsing utilities already exist in the file.
- `::oReport1:oDataSource := Select()` in the sample is simplified — adapt to whatever TDatabase/DBF API the TReport class actually expects.
- `UI_RGB()` in TBand:New() — verify this function exists in classes.prg or substitute the actual color-creation function used elsewhere.
