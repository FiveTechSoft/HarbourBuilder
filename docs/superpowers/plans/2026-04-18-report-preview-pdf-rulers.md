# Report Preview, PDF Export & Rulers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add measurement rulers to the report designer and implement `TReport:Preview()` / `TReport:ExportPDF()` using Core Graphics PDF rendering.

**Architecture:** `HBRulerView` NSView subclasses appear as overlay views atop `FContentView` when the first CT_BAND is placed; they disappear when all bands are removed. Six `HB_FUNC RPT_*` implementations in `cocoa_core.m` drive PDF generation via `CGPDFContextCreateWithURL` + Core Text; `TReport:Preview()` already calls them and `TReport:ExportPDF()` is new.

**Tech Stack:** Objective-C / Cocoa, CoreGraphics (CGPDFContext), CoreText (CTLineDraw), Harbour (HB_FUNC), `objc_setAssociatedObject` for ruler view tracking.

---

## File Map

| File | Change |
|------|--------|
| `source/backends/cocoa/cocoa_core.m` | Add `HBRulerView`, `UI_BandRulersUpdate`, RPT_* HB_FUNCs, imports |
| `build_mac.sh` | Add `-framework CoreText` to linker line |
| `source/core/classes.prg` | Add `METHOD ExportPDF(cFile)` to `TReport` |

---

## Task 1: HBRulerView and UI_BandRulersUpdate

**Files:**
- Modify: `source/backends/cocoa/cocoa_core.m:1–20` (imports)
- Modify: `source/backends/cocoa/cocoa_core.m:559–561` (forward declarations)
- Modify: `source/backends/cocoa/cocoa_core.m:1426–1427` (after HBBandView @end)
- Modify: `source/backends/cocoa/cocoa_core.m:4908–4911` (end of BandStackAll)
- Modify: `source/backends/cocoa/cocoa_core.m:3442–3448` (keyDown delete branch)

- [ ] **Step 1: Add `#include <objc/runtime.h>` import**

  In `source/backends/cocoa/cocoa_core.m`, after line 16 (`#define HAS_UTTYPE 1`), add:

  ```objc
  #include <objc/runtime.h>
  ```

  The file currently starts:
  ```objc
  #import <Cocoa/Cocoa.h>
  #import <MapKit/MapKit.h>
  #include <cups/cups.h>
  #import <SceneKit/SceneKit.h>
  #import <WebKit/WebKit.h>
  #if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
  #import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
  #define HAS_UTTYPE 1
  #endif
  #include <hbapi.h>
  ```

  Add `#include <objc/runtime.h>` just before `#include <hbapi.h>`:

  ```objc
  #if __has_include(<UniformTypeIdentifiers/UniformTypeIdentifiers.h>)
  #import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
  #define HAS_UTTYPE 1
  #endif
  #include <objc/runtime.h>
  #include <hbapi.h>
  ```

- [ ] **Step 2: Add forward declaration for UI_BandRulersUpdate**

  At line 561 the file has:
  ```c
  static void BandStackAll( HBControl * parent );   /* forward declaration */
  ```

  Add a new forward declaration on the next line:
  ```c
  static void BandStackAll( HBControl * parent );   /* forward declaration */
  static void UI_BandRulersUpdate( HBControl * form ); /* forward declaration */
  ```

- [ ] **Step 3: Add HBRulerView class after HBBandView @end (around line 1427)**

  After `@end` of `HBBandView` (the line that reads `@end` after the band border stroke code), add:

  ```objc
  /* --- HBRulerView --- */
  /* Thin ruler strip drawn at top (horizontal) or left (vertical) of the report designer.
   * Appears when the first CT_BAND is placed; removed when no bands remain. */

  static const char s_rulerHKey   = 0;   /* associated-object key for horizontal ruler */
  static const char s_rulerVKey   = 0;   /* associated-object key for vertical ruler    */
  static const char s_rulerCrnKey = 0;   /* associated-object key for corner square     */

  @interface HBRulerView : NSView
  @property (assign) BOOL isHorizontal;
  @end

  @implementation HBRulerView
  - (BOOL)isFlipped { return YES; }
  - (void)drawRect:(NSRect)dirtyRect
  {
     (void)dirtyRect;
     [[NSColor colorWithWhite:0.85 alpha:1.0] setFill];
     NSRectFill(self.bounds);

     NSFont * font = [NSFont systemFontOfSize:8];
     NSDictionary * attrs = @{ NSFontAttributeName: font,
                                NSForegroundColorAttributeName: [NSColor darkGrayColor] };

     CGFloat totalLen = self.isHorizontal ? self.bounds.size.width : self.bounds.size.height;
     CGFloat rulerW   = self.isHorizontal ? self.bounds.size.height : self.bounds.size.width;

     for( int i = 0; i <= (int)totalLen; i += 10 ) {
        CGFloat tick = (i % 100 == 0) ? rulerW * 0.6 : (i % 50 == 0) ? rulerW * 0.4 : rulerW * 0.2;
        NSBezierPath * p = [NSBezierPath bezierPath];
        [[NSColor colorWithWhite:0.5 alpha:1.0] setStroke];
        if( self.isHorizontal ) {
           [p moveToPoint:NSMakePoint(i, rulerW - tick)];
           [p lineToPoint:NSMakePoint(i, rulerW)];
        } else {
           [p moveToPoint:NSMakePoint(rulerW - tick, i)];
           [p lineToPoint:NSMakePoint(rulerW, i)];
        }
        [p setLineWidth:0.5];
        [p stroke];
        if( i % 100 == 0 && i > 0 ) {
           NSString * label = [NSString stringWithFormat:@"%d", i];
           NSPoint pt = self.isHorizontal ? NSMakePoint(i + 2, 1) : NSMakePoint(1, i + 1);
           [label drawAtPoint:pt withAttributes:attrs];
        }
     }
     /* Bottom/right border line */
     [[NSColor colorWithWhite:0.4 alpha:1.0] setStroke];
     NSBezierPath * border = [NSBezierPath bezierPath];
     if( self.isHorizontal ) {
        [border moveToPoint:NSMakePoint(0, rulerW - 0.5)];
        [border lineToPoint:NSMakePoint(totalLen, rulerW - 0.5)];
     } else {
        [border moveToPoint:NSMakePoint(rulerW - 0.5, 0)];
        [border lineToPoint:NSMakePoint(rulerW - 0.5, totalLen)];
     }
     [border setLineWidth:1.0];
     [border stroke];
  }
  @end

  /* UI_BandRulersUpdate — show or hide ruler overlay views on the report designer form.
   * Call after any CT_BAND add/remove/restack operation. */
  static void UI_BandRulersUpdate( HBControl * form )
  {
     if( !form || ![form isKindOfClass:[HBForm class]] ) return;
     HBForm * hbf = (HBForm *)form;
     if( !hbf->FContentView ) return;

     /* Count visible bands (FView != nil means not deleted) */
     int nBands = 0;
     for( int i = 0; i < form->FChildCount; i++ )
        if( form->FChildren[i] && form->FChildren[i]->FControlType == CT_BAND
              && form->FChildren[i]->FView )
           nBands++;

     const CGFloat RS = 20.0;
     HBRulerView * rh = objc_getAssociatedObject(hbf->FContentView, &s_rulerHKey);
     HBRulerView * rv = objc_getAssociatedObject(hbf->FContentView, &s_rulerVKey);

     if( nBands > 0 && !rh ) {
        /* Create rulers */
        NSRect bounds = hbf->FContentView.bounds;
        HBRulerView * nh = [[HBRulerView alloc] initWithFrame:
           NSMakeRect(RS, 0, bounds.size.width - RS, RS)];
        nh.isHorizontal   = YES;
        nh.autoresizingMask = NSViewWidthSizable;
        [hbf->FContentView addSubview:nh positioned:NSWindowAbove relativeTo:nil];

        HBRulerView * nv = [[HBRulerView alloc] initWithFrame:
           NSMakeRect(0, RS, RS, bounds.size.height - RS)];
        nv.isHorizontal   = NO;
        nv.autoresizingMask = NSViewHeightSizable;
        [hbf->FContentView addSubview:nv positioned:NSWindowAbove relativeTo:nil];

        /* Corner square */
        NSView * corner = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, RS, RS)];
        corner.wantsLayer = YES;
        corner.layer.backgroundColor = [[NSColor colorWithWhite:0.75 alpha:1.0] CGColor];
        [hbf->FContentView addSubview:corner positioned:NSWindowAbove relativeTo:nil];

        objc_setAssociatedObject(hbf->FContentView, &s_rulerHKey,   nh,     OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(hbf->FContentView, &s_rulerVKey,   nv,     OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(hbf->FContentView, &s_rulerCrnKey, corner, OBJC_ASSOCIATION_RETAIN);
     }
     else if( nBands == 0 && rh ) {
        /* Remove rulers */
        [rh removeFromSuperview];
        [rv removeFromSuperview];
        NSView * corner = objc_getAssociatedObject(hbf->FContentView, &s_rulerCrnKey);
        if( corner ) [corner removeFromSuperview];
        objc_setAssociatedObject(hbf->FContentView, &s_rulerHKey,   nil, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(hbf->FContentView, &s_rulerVKey,   nil, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(hbf->FContentView, &s_rulerCrnKey, nil, OBJC_ASSOCIATION_RETAIN);
     }
     else if( nBands > 0 && rh ) {
        /* Resize to match current window size */
        NSRect bounds = hbf->FContentView.bounds;
        rh.frame = NSMakeRect(RS, 0, bounds.size.width - RS, RS);
        rv.frame = NSMakeRect(0, RS, RS, bounds.size.height - RS);
        [rh setNeedsDisplay:YES];
        [rv setNeedsDisplay:YES];
     }
  }
  ```

- [ ] **Step 4: Call UI_BandRulersUpdate at the end of BandStackAll**

  At the end of `BandStackAll` (currently around line 4910), the function ends with:
  ```c
     [b updateViewFrame];
     if( b->FView ) [b->FView setNeedsDisplay:YES];
  }
  ```
  followed by the closing `}` of BandStackAll.

  Add the call AFTER the for loop, before the final `}`:
  ```c
     for( HBControl * b in bands ) {
        b->FLeft = 0;
        b->FTop  = (int)y;
        if( formW > 0 ) b->FWidth = (int)formW;
        y += b->FHeight;
        [b updateViewFrame];
        if( b->FView ) [b->FView setNeedsDisplay:YES];
     }
     UI_BandRulersUpdate( parent );
  }
  ```

- [ ] **Step 5: Call UI_BandRulersUpdate in keyDown: after band delete**

  In `keyDown:` (around line 3442), the delete branch currently reads:
  ```c
  if( (keyCode == 51 || keyCode == 117) && form->FSelCount > 0 ) {
     for( int i = 0; i < form->FSelCount; i++ )
        if( form->FSelected[i]->FView ) {
           [form->FSelected[i]->FView removeFromSuperview];
           form->FSelected[i]->FView = nil;
        }
     [form clearSelection]; return;
  }
  ```

  Add `UI_BandRulersUpdate((HBControl *)form)` before `[form clearSelection]`:
  ```c
  if( (keyCode == 51 || keyCode == 117) && form->FSelCount > 0 ) {
     for( int i = 0; i < form->FSelCount; i++ )
        if( form->FSelected[i]->FView ) {
           [form->FSelected[i]->FView removeFromSuperview];
           form->FSelected[i]->FView = nil;
        }
     UI_BandRulersUpdate( (HBControl *)form );
     [form clearSelection]; return;
  }
  ```

- [ ] **Step 6: Build and verify rulers appear**

  ```bash
  cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -20
  ```
  Expected: no errors, binary built.

  Run the app, create a new form, drop a Band from the Printing palette tab. Verify:
  - A horizontal ruler (20px tall) appears at the top of the form designer
  - A vertical ruler (20px wide) appears at the left of the form designer
  - A gray corner square (20×20) appears at top-left
  - Rulers show tick marks at 10px intervals, labels at 100px intervals

  Delete the band (select it, press Backspace). Verify rulers disappear.

- [ ] **Step 7: Commit**

  ```bash
  cd /Users/usuario/HarbourBuilder
  cp source/HbBuilder bin/HbBuilder 2>/dev/null || cp source/HbBuilder bin/ 2>/dev/null || true
  git add source/backends/cocoa/cocoa_core.m
  git commit -m "feat(mac): ruler overlay views in report designer when bands are present"
  ```

---

## Task 2: RPT_* HB_FUNC implementations (PDF rendering)

**Files:**
- Modify: `source/backends/cocoa/cocoa_core.m` (add CoreText import + RPT_* functions at end)
- Modify: `build_mac.sh` (add `-framework CoreText` to linker)

- [ ] **Step 1: Add CoreText import**

  In `source/backends/cocoa/cocoa_core.m`, after `#include <objc/runtime.h>` (added in Task 1), add:
  ```objc
  #import <CoreText/CoreText.h>
  ```

  Result:
  ```objc
  #include <objc/runtime.h>
  #import <CoreText/CoreText.h>
  #include <hbapi.h>
  ```

- [ ] **Step 2: Add CoreText framework to build_mac.sh linker**

  In `build_mac.sh`, the linker line (around line 234) ends with:
  ```bash
     -framework Cocoa \
     -framework QuartzCore \
  ```

  Add `-framework CoreText \` after `-framework QuartzCore \`:
  ```bash
     -framework Cocoa \
     -framework QuartzCore \
     -framework CoreText \
  ```

- [ ] **Step 3: Add static PDF state globals**

  At the very end of `cocoa_core.m` (after the last `}` of `UI_STACKTOOLBARS` and the DPI stub comment), append:

  ```objc
  /* =====================================================================
   * Report Preview / PDF Export — RPT_* HB_FUNCs
   * ===================================================================== */

  static CGContextRef s_pdfCtx       = NULL;
  static CFURLRef     s_pdfURL       = NULL;
  static CGRect       s_pageRect;
  static float        s_pdfScale     = 0.75f;   /* 96 screen px → 72 PDF pt */
  static char         s_pdfTempPath[1024] = "";
  ```

- [ ] **Step 4: Add RPT_PREVIEWOPEN**

  Append after the globals from Step 3:

  ```objc
  /* RPT_PREVIEWOPEN( nPageW, nPageH, nMarginL, nMarginR, nMarginT, nMarginB )
   * Creates a PDF context writing to a temp file. Must be called before any other RPT_*. */
  HB_FUNC( RPT_PREVIEWOPEN )
  {
     if( s_pdfCtx ) { CGContextRelease(s_pdfCtx); s_pdfCtx = NULL; }
     if( s_pdfURL ) { CFRelease(s_pdfURL); s_pdfURL = NULL; }

     float nW = (float)hb_parnd(1);
     float nH = (float)hb_parnd(2);
     if( nW <= 0 ) nW = 794;   /* A4 96 DPI default */
     if( nH <= 0 ) nH = 1123;

     s_pageRect = CGRectMake(0, 0, nW * s_pdfScale, nH * s_pdfScale);

     NSString * tempDir = NSTemporaryDirectory();
     NSString * path = [tempDir stringByAppendingPathComponent:@"hbpreview.pdf"];
     strncpy(s_pdfTempPath, [path UTF8String], sizeof(s_pdfTempPath) - 1);

     s_pdfURL = CFURLCreateWithFileSystemPath(NULL,
        (__bridge CFStringRef)path, kCFURLPOSIXPathStyle, false);

     CFMutableDictionaryRef info = CFDictionaryCreateMutable(NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
     s_pdfCtx = CGPDFContextCreateWithURL(s_pdfURL, &s_pageRect, info);
     CFRelease(info);
  }
  ```

- [ ] **Step 5: Add RPT_PREVIEWADDPAGE**

  ```objc
  /* RPT_PREVIEWADDPAGE()
   * Opens a new page in the PDF. Coordinate origin is top-left (matching screen). */
  HB_FUNC( RPT_PREVIEWADDPAGE )
  {
     if( !s_pdfCtx ) return;
     CGPDFContextBeginPage(s_pdfCtx, NULL);
  }
  ```

- [ ] **Step 6: Add RPT_PREVIEWDRAWTEXT**

  ```objc
  /* RPT_PREVIEWDRAWTEXT( nX, nY, cText, cFont, nFontSize, lBold, lItalic, nForeColor )
   * Draws a text string at screen-pixel coordinates (nX, nY = top-left of text). */
  HB_FUNC( RPT_PREVIEWDRAWTEXT )
  {
     if( !s_pdfCtx ) return;

     float   nX    = (float)hb_parnd(1) * s_pdfScale;
     float   nY    = (float)hb_parnd(2) * s_pdfScale;
     const char * szText = hb_parc(3) ? hb_parc(3) : "";
     const char * szFont = hb_parc(4) ? hb_parc(4) : "Helvetica";
     float   nSize = (float)(hb_parnd(5) > 0 ? hb_parnd(5) : 10) * s_pdfScale;
     BOOL    lBold   = hb_parl(6);
     BOOL    lItalic = hb_parl(7);
     long    nColor  = hb_parnl(8);

     /* Build font with optional bold/italic traits */
     NSString * fontName = [NSString stringWithUTF8String:szFont];
     NSFontDescriptor * desc = [NSFontDescriptor fontDescriptorWithName:fontName size:nSize];
     NSFontDescriptorSymbolicTraits traits = 0;
     if( lBold )   traits |= NSFontDescriptorTraitBold;
     if( lItalic ) traits |= NSFontDescriptorTraitItalic;
     if( traits ) desc = [desc fontDescriptorWithSymbolicTraits:traits];
     NSFont * nsFont = [NSFont fontWithDescriptor:desc size:nSize];
     if( !nsFont ) nsFont = [NSFont systemFontOfSize:nSize];

     /* Decode BGR color (Harbour stores as B*65536 + G*256 + R) */
     float r = ((nColor)       & 0xFF) / 255.0f;
     float g = ((nColor >> 8)  & 0xFF) / 255.0f;
     float b = ((nColor >> 16) & 0xFF) / 255.0f;

     NSDictionary * attrs = @{
        NSFontAttributeName:            nsFont,
        NSForegroundColorAttributeName: [NSColor colorWithRed:r green:g blue:b alpha:1.0]
     };
     NSAttributedString * as = [[NSAttributedString alloc]
        initWithString:[NSString stringWithUTF8String:szText] attributes:attrs];
     CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)as);

     /* PDF origin is bottom-left; screen origin is top-left.
      * Baseline position: pageH - screen_y_px*scale - fontSize */
     float pdf_y = s_pageRect.size.height - nY - nSize;

     CGContextSetTextMatrix(s_pdfCtx, CGAffineTransformIdentity);
     CGContextSetTextPosition(s_pdfCtx, nX, pdf_y);
     CTLineDraw(line, s_pdfCtx);
     CFRelease(line);
  }
  ```

- [ ] **Step 7: Add RPT_PREVIEWDRAWRECT**

  ```objc
  /* RPT_PREVIEWDRAWRECT( nX, nY, nW, nH, nBorderColor, nFillColor )
   * Draws a filled/stroked rectangle. Pass -1 for nFillColor to skip fill. */
  HB_FUNC( RPT_PREVIEWDRAWRECT )
  {
     if( !s_pdfCtx ) return;
     float nX = (float)hb_parnd(1) * s_pdfScale;
     float nW = (float)hb_parnd(3) * s_pdfScale;
     float nH = (float)hb_parnd(4) * s_pdfScale;
     float nY = s_pageRect.size.height - (float)hb_parnd(2) * s_pdfScale - nH;
     CGRect r = CGRectMake(nX, nY, nW, nH);
     long fillC   = hb_parnl(6);
     long borderC = hb_parnl(5);
     if( fillC >= 0 ) {
        CGContextSetRGBFillColor(s_pdfCtx,
           (fillC & 0xFF)/255.0, ((fillC>>8)&0xFF)/255.0, ((fillC>>16)&0xFF)/255.0, 1.0);
        CGContextFillRect(s_pdfCtx, r);
     }
     if( borderC >= 0 ) {
        CGContextSetRGBStrokeColor(s_pdfCtx,
           (borderC & 0xFF)/255.0, ((borderC>>8)&0xFF)/255.0, ((borderC>>16)&0xFF)/255.0, 1.0);
        CGContextStrokeRect(s_pdfCtx, r);
     }
  }
  ```

- [ ] **Step 8: Add RPT_PREVIEWRENDER**

  ```objc
  /* RPT_PREVIEWRENDER()
   * Closes the current PDF page, finalizes the context, and opens the file in Preview.app. */
  HB_FUNC( RPT_PREVIEWRENDER )
  {
     if( !s_pdfCtx ) return;
     CGPDFContextEndPage(s_pdfCtx);
     CGContextRelease(s_pdfCtx); s_pdfCtx = NULL;
     if( s_pdfURL ) { CFRelease(s_pdfURL); s_pdfURL = NULL; }
     if( s_pdfTempPath[0] ) {
        NSString * path = [NSString stringWithUTF8String:s_pdfTempPath];
        [[NSWorkspace sharedWorkspace] openFile:path];
     }
  }
  ```

- [ ] **Step 9: Add RPT_EXPORTPDF**

  ```objc
  /* RPT_EXPORTPDF( cDestFile )
   * Closes the PDF and moves the temp file to cDestFile. */
  HB_FUNC( RPT_EXPORTPDF )
  {
     const char * szFile = hb_parc(1);
     if( !s_pdfCtx ) return;
     CGPDFContextEndPage(s_pdfCtx);
     CGContextRelease(s_pdfCtx); s_pdfCtx = NULL;
     if( s_pdfURL ) { CFRelease(s_pdfURL); s_pdfURL = NULL; }
     if( !szFile || !s_pdfTempPath[0] ) return;
     if( strcmp(s_pdfTempPath, szFile) != 0 ) {
        NSString * src = [NSString stringWithUTF8String:s_pdfTempPath];
        NSString * dst = [NSString stringWithUTF8String:szFile];
        NSError * err = nil;
        [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:&err];
     }
  }
  ```

- [ ] **Step 10: Build and verify no compilation errors**

  ```bash
  cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -20
  ```
  Expected: Builds cleanly. If CoreText symbols are unresolved, verify `-framework CoreText` is in build_mac.sh.

- [ ] **Step 11: Commit**

  ```bash
  cd /Users/usuario/HarbourBuilder
  git add source/backends/cocoa/cocoa_core.m build_mac.sh
  git commit -m "feat(mac): RPT_* HB_FUNCs for PDF rendering via CoreGraphics + CoreText"
  ```

---

## Task 3: TReport:ExportPDF in classes.prg

**Files:**
- Modify: `source/core/classes.prg:2562–2572` (TReport class declaration)
- Modify: `source/core/classes.prg:2609–2610` (after Preview METHOD)

- [ ] **Step 1: Add METHOD ExportPDF declaration to TReport class**

  In `source/core/classes.prg`, the TReport class declaration (around line 2562) currently reads:
  ```harbour
     METHOD New( oPrn ) CONSTRUCTOR
     METHOD AddBand( cName, bBlock )
     METHOD AddColumn( cTitle, cField, nWidth )
     METHOD Preview()
     METHOD Print()
     METHOD AddDesignBand( oBand )
     METHOD RemoveDesignBand( nIndex )
     METHOD GetDesignBand( cName )
     METHOD RenderBand( oBand )
     METHOD GenerateCode( cClassName )
  ENDCLASS
  ```

  Add `METHOD ExportPDF( cFile )` after `METHOD Preview()`:
  ```harbour
     METHOD New( oPrn ) CONSTRUCTOR
     METHOD AddBand( cName, bBlock )
     METHOD AddColumn( cTitle, cField, nWidth )
     METHOD Preview()
     METHOD ExportPDF( cFile )
     METHOD Print()
     METHOD AddDesignBand( oBand )
     METHOD RemoveDesignBand( nIndex )
     METHOD GetDesignBand( cName )
     METHOD RenderBand( oBand )
     METHOD GenerateCode( cClassName )
  ENDCLASS
  ```

- [ ] **Step 2: Add METHOD ExportPDF implementation**

  After the `METHOD Preview() CLASS TReport` implementation (which ends around line 2609 with `return nil`), insert the new method:

  ```harbour
  METHOD ExportPDF( cFile ) CLASS TReport
     local i, j, oBand, oFld, nY
     if cFile == nil .or. Empty( cFile ); return nil; endif

     RPT_PreviewOpen( ::nPageWidth, ::nPageHeight, ;
        ::nMarginLeft, ::nMarginRight, ::nMarginTop, ::nMarginBottom )
     RPT_PreviewAddPage()

     nY := ::nMarginTop

     for i := 1 to Len( ::aDesignBands )
        oBand := ::aDesignBands[i]
        if ! oBand:lVisible; loop; endif

        for j := 1 to Len( oBand:aFields )
           oFld := oBand:aFields[j]
           RPT_PreviewDrawText( ::nMarginLeft + oFld:nLeft, nY + oFld:nTop, ;
              iif( ! Empty(oFld:cText), oFld:cText, "[" + oFld:cFieldName + "]" ), ;
              oFld:cFontName, oFld:nFontSize, oFld:lBold, oFld:lItalic, oFld:nForeColor )
        next

        nY += oBand:nHeight
     next

     RPT_ExportPDF( cFile )
  return nil
  ```

  The exact insertion point is after the closing `return nil` of `METHOD Preview()`. The Preview method currently ends:
  ```harbour
     RPT_PreviewRender()
  return nil

  METHOD Print() CLASS TReport
  ```

  Insert the new ExportPDF method between `return nil` and `METHOD Print()`:
  ```harbour
     RPT_PreviewRender()
  return nil

  METHOD ExportPDF( cFile ) CLASS TReport
     local i, j, oBand, oFld, nY
     if cFile == nil .or. Empty( cFile ); return nil; endif
     RPT_PreviewOpen( ::nPageWidth, ::nPageHeight, ;
        ::nMarginLeft, ::nMarginRight, ::nMarginTop, ::nMarginBottom )
     RPT_PreviewAddPage()
     nY := ::nMarginTop
     for i := 1 to Len( ::aDesignBands )
        oBand := ::aDesignBands[i]
        if ! oBand:lVisible; loop; endif
        for j := 1 to Len( oBand:aFields )
           oFld := oBand:aFields[j]
           RPT_PreviewDrawText( ::nMarginLeft + oFld:nLeft, nY + oFld:nTop, ;
              iif( ! Empty(oFld:cText), oFld:cText, "[" + oFld:cFieldName + "]" ), ;
              oFld:cFontName, oFld:nFontSize, oFld:lBold, oFld:lItalic, oFld:nForeColor )
        next
        nY += oBand:nHeight
     next
     RPT_ExportPDF( cFile )
  return nil

  METHOD Print() CLASS TReport
  ```

- [ ] **Step 3: Build**

  ```bash
  cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -20
  ```
  Expected: builds without Harbour errors. If you get "RPT_PREVIEWOPEN undefined", the HB_FUNC names must match — HB_FUNC names are all-caps versions of the Harbour function name.

- [ ] **Step 4: Commit**

  ```bash
  cd /Users/usuario/HarbourBuilder
  git add source/core/classes.prg
  git commit -m "feat: add TReport:ExportPDF method for PDF file export"
  ```

---

## Task 4: End-to-End Test and Final Build

**Files:**
- No code changes — manual smoke test only

- [ ] **Step 1: Build final binary and copy to bin/**

  ```bash
  cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -5
  cp source/HbBuilder bin/HbBuilder 2>/dev/null || true
  ```

- [ ] **Step 2: Run the app**

  ```bash
  cd /Users/usuario/HarbourBuilder && ./bin/HbBuilder &
  ```

- [ ] **Step 3: Smoke test — Rulers**

  1. Create a new form (`File → New` or toolbar)
  2. Open the Palette, click the **Printing** tab
  3. Click the **Band** palette item once
  4. Verify: rulers appear on the form designer (horizontal at top, vertical at left, gray corner)
  5. Add a second band — rulers stay visible
  6. Select one band, press Backspace — rulers remain (still one band left)
  7. Select the last band, press Backspace — rulers disappear

- [ ] **Step 4: Smoke test — Preview**

  1. Create a new form, add one or two Band components
  2. In the code for the form's OnCreate (or a button's OnClick), write:
     ```harbour
     local oReport := TReport():New()
     local oBand   := TBand():New( nil, "Header", 40 )
     local oFld    := TReportField():New()
     oFld:cText    := "Hello from HbBuilder Report"
     oFld:nLeft    := 10
     oFld:nTop     := 8
     oFld:nFontSize := 14
     oBand:AddField( oFld )
     oReport:AddDesignBand( oBand )
     oReport:Preview()
     ```
  3. Run the project — macOS Preview.app should open showing "Hello from HbBuilder Report" on a white page

- [ ] **Step 5: Smoke test — ExportPDF**

  Modify the button's OnClick to call `oReport:ExportPDF("/tmp/test_report.pdf")` instead of `Preview()`. After running:
  ```bash
  ls -la /tmp/test_report.pdf
  open /tmp/test_report.pdf
  ```
  The PDF should open in Preview.app with the text visible.

- [ ] **Step 6: Final commit**

  ```bash
  cd /Users/usuario/HarbourBuilder
  git add -p   # review any unstaged changes
  git commit -m "feat: report Preview+PDF+Rulers complete — smoke tested" 2>/dev/null || echo "nothing to commit"
  ```

---

## Quick Reference: Key Coordinate Conversion

PDF uses bottom-left origin; screen uses top-left. In `RPT_PREVIEWDRAWTEXT`:
```
pdf_y_baseline = pageHeight_pt - screen_y_px * scale - fontSize_pt
```
Where `scale = 0.75` (96 DPI screen → 72 DPI PDF). A4 page: 794×1123 px → 595.5×842.25 pt.
