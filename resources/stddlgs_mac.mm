/* Standard dialog runtime backends for HbBuilder projects (macOS / Cocoa).
 * Exposes MAC_ExecOpenDialog / MAC_ExecSaveDialog / MAC_ExecFontDialog /
 * MAC_ExecColorDialog used by TOpenDialog/TSaveDialog/TFontDialog/
 * TColorDialog classes in classes.prg.
 */
#import <Cocoa/Cocoa.h>
#include <string.h>
#include <hbapi.h>
#include <hbapiitm.h>

/* Parse "Text Files (*.txt)|*.txt|All|*.*" → NSArray of extensions
 * (e.g. @[ @"txt" ]). Win32 uses the full filter; NSOpen/SavePanel only needs
 * extensions. We strip "*." and "." prefixes, keep letters/digits, drop "*". */
static NSArray<NSString *> * _dlgExtensions( const char * src )
{
   NSMutableArray * exts = [NSMutableArray array];
   if( !src || !src[0] ) return exts;

   NSString * full = [NSString stringWithUTF8String:src];
   NSArray * parts = [full componentsSeparatedByString:@"|"];
   /* Odd-indexed parts (1,3,5,…) are the patterns. Even-indexed are labels. */
   for( NSUInteger i = 1; i < parts.count; i += 2 )
   {
      NSString * pat = parts[i];
      for( NSString * one in [pat componentsSeparatedByString:@";"] )
      {
         NSString * t = [one stringByTrimmingCharactersInSet:
                         NSCharacterSet.whitespaceCharacterSet];
         if( [t hasPrefix:@"*."] ) t = [t substringFromIndex:2];
         else if( [t hasPrefix:@"."] ) t = [t substringFromIndex:1];
         if( t.length == 0 || [t isEqualToString:@"*"] ) continue;  /* *.* => no filter */
         [exts addObject:t];
      }
   }
   return exts;
}

HB_FUNC( MAC_EXECOPENDIALOG )
{
   @autoreleasepool {
      NSOpenPanel * panel = [NSOpenPanel openPanel];
      const char * cTitle = hb_parc(1);
      const char * cInit  = hb_parc(3);

      if( cTitle && cTitle[0] )
         panel.message = [NSString stringWithUTF8String:cTitle];
      if( cInit && cInit[0] )
         panel.directoryURL = [NSURL fileURLWithPath:
                               [NSString stringWithUTF8String:cInit]];

      NSArray * exts = _dlgExtensions( hb_parc(2) );
      if( exts.count > 0 )
         panel.allowedFileTypes = exts;
      panel.canChooseFiles = YES;
      panel.canChooseDirectories = NO;
      panel.allowsMultipleSelection = NO;

      if( [panel runModal] == NSModalResponseOK && panel.URL )
         hb_retc( [panel.URL.path UTF8String] );
      else
         hb_retc( "" );
   }
}

HB_FUNC( MAC_EXECSAVEDIALOG )
{
   @autoreleasepool {
      NSSavePanel * panel = [NSSavePanel savePanel];
      const char * cTitle = hb_parc(1);
      const char * cInit  = hb_parc(3);
      const char * cExt   = hb_parc(4);
      const char * cName  = hb_parc(5);

      if( cTitle && cTitle[0] )
         panel.message = [NSString stringWithUTF8String:cTitle];
      if( cInit && cInit[0] )
         panel.directoryURL = [NSURL fileURLWithPath:
                               [NSString stringWithUTF8String:cInit]];
      if( cName && cName[0] )
         panel.nameFieldStringValue = [[NSString stringWithUTF8String:cName]
                                       lastPathComponent];

      NSArray * exts = _dlgExtensions( hb_parc(2) );
      if( exts.count > 0 )
         panel.allowedFileTypes = exts;
      else if( cExt && cExt[0] )
         panel.allowedFileTypes = @[ [NSString stringWithUTF8String:cExt] ];

      if( [panel runModal] == NSModalResponseOK && panel.URL )
         hb_retc( [panel.URL.path UTF8String] );
      else
         hb_retc( "" );
   }
}

/* NSFontPanel is modeless — we run a short modal session via an accessory
 * window so Execute() behaves like Win32 (blocks until OK/Cancel). */
@interface HBFontPanelDelegate : NSObject <NSWindowDelegate>
{
@public
   NSFont  * chosen;
   NSColor * chosenColor;
   BOOL      ok;
}
- (void)pickFont:(id)sender;
- (void)cancel:(id)sender;
- (void)changeFont:(id)sender;
- (void)changeAttributes:(id)sender;
@end

@implementation HBFontPanelDelegate
- (void)pickFont:(id)sender { (void)sender; ok = YES; [NSApp stopModal]; }
- (void)cancel:(id)sender   { (void)sender; ok = NO;  [NSApp stopModal]; }
- (void)changeFont:(id)sender
{
   NSFontManager * fm = (NSFontManager *) sender;
   chosen = [fm convertFont:chosen ? chosen : [NSFont systemFontOfSize:12]];
}
- (void)changeAttributes:(id)sender
{
   NSDictionary * cur = @{};
   if( chosenColor ) cur = @{ NSForegroundColorAttributeName : chosenColor };
   NSDictionary * newAttrs = [sender convertAttributes:cur];
   NSColor * c = newAttrs[NSForegroundColorAttributeName];
   if( c ) chosenColor = c;
}
- (void)windowWillClose:(NSNotification *)n { (void)n; ok = NO; [NSApp stopModal]; }
@end

HB_FUNC( MAC_EXECFONTDIALOG )
{
   @autoreleasepool {
      const char * cName = hb_parc(1);
      int nSize  = hb_parni(2);
      int nColor = hb_parni(3);   /* BGR (Win32-style) */
      int nStyle = hb_parni(4);   /* 1=bold, 2=italic, 4=underline */

      if( nSize <= 0 ) nSize = 12;

      NSString * face = ( cName && cName[0] )
         ? [NSString stringWithUTF8String:cName]
         : @"Helvetica";
      NSFont * font = [NSFont fontWithName:face size:nSize];
      if( !font ) font = [NSFont systemFontOfSize:nSize];

      NSFontManager * fm = [NSFontManager sharedFontManager];
      if( nStyle & 1 ) font = [fm convertFont:font toHaveTrait:NSBoldFontMask];
      if( nStyle & 2 ) font = [fm convertFont:font toHaveTrait:NSItalicFontMask];

      /* BGR → RGB */
      CGFloat r = ( nColor        & 0xFF) / 255.0;
      CGFloat g = ((nColor >> 8)  & 0xFF) / 255.0;
      CGFloat b = ((nColor >> 16) & 0xFF) / 255.0;
      NSColor * color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];

      HBFontPanelDelegate * del = [[HBFontPanelDelegate alloc] init];
      del->chosen = font;
      del->chosenColor = color;
      del->ok = NO;

      [fm setSelectedFont:font isMultiple:NO];
      [fm setSelectedAttributes:@{ NSForegroundColorAttributeName : color }
                     isMultiple:NO];
      [fm setTarget:del];
      [fm setAction:@selector(changeFont:)];

      NSFontPanel * panel = [fm fontPanel:YES];
      panel.delegate = del;

      /* Accessory view with OK / Cancel buttons */
      NSView * acc = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 40)];
      NSButton * bOk = [[NSButton alloc] initWithFrame:NSMakeRect(130, 6, 100, 28)];
      bOk.bezelStyle = NSBezelStyleRounded;
      bOk.title = @"OK";
      bOk.keyEquivalent = @"\r";
      bOk.target = del;
      bOk.action = @selector(pickFont:);
      NSButton * bCancel = [[NSButton alloc] initWithFrame:NSMakeRect(20, 6, 100, 28)];
      bCancel.bezelStyle = NSBezelStyleRounded;
      bCancel.title = @"Cancel";
      bCancel.keyEquivalent = @"\033";
      bCancel.target = del;
      bCancel.action = @selector(cancel:);
      [acc addSubview:bOk];
      [acc addSubview:bCancel];
      [panel setAccessoryView:acc];

      [panel makeKeyAndOrderFront:nil];
      [NSApp runModalForWindow:panel];
      [panel orderOut:nil];
      panel.delegate = nil;
      [panel setAccessoryView:nil];

      if( del->ok && del->chosen )
      {
         NSFont  * f = del->chosen;
         NSColor * c = del->chosenColor ?: color;
         NSColor * rgb = [c colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];

         int outStyle = 0;
         NSFontTraitMask tr = [fm traitsOfFont:f];
         if( tr & NSBoldFontMask )   outStyle |= 1;
         if( tr & NSItalicFontMask ) outStyle |= 2;

         int ir = (int) (rgb.redComponent   * 255.0 + 0.5);
         int ig = (int) (rgb.greenComponent * 255.0 + 0.5);
         int ib = (int) (rgb.blueComponent  * 255.0 + 0.5);
         int bgr = (ib << 16) | (ig << 8) | ir;

         PHB_ITEM aRet = hb_itemArrayNew( 4 );
         hb_arraySetC ( aRet, 1, [f.fontName UTF8String] );
         hb_arraySetNI( aRet, 2, (int) f.pointSize );
         hb_arraySetNI( aRet, 3, bgr );
         hb_arraySetNI( aRet, 4, outStyle );
         hb_itemReturnRelease( aRet );
      }
      else
      {
         hb_ret();  /* NIL */
      }
   }
}

/* Same accessory-button trick for NSColorPanel */
@interface HBColorPanelDelegate : NSObject <NSWindowDelegate>
{
@public
   BOOL ok;
}
- (void)pickColor:(id)sender;
- (void)cancel:(id)sender;
@end

@implementation HBColorPanelDelegate
- (void)pickColor:(id)sender { (void)sender; ok = YES; [NSApp stopModal]; }
- (void)cancel:(id)sender    { (void)sender; ok = NO;  [NSApp stopModal]; }
- (void)windowWillClose:(NSNotification *)n { (void)n; ok = NO; [NSApp stopModal]; }
@end

HB_FUNC( MAC_EXECCOLORDIALOG )
{
   @autoreleasepool {
      int nColor = hb_parni(1);  /* BGR */
      CGFloat r = ( nColor        & 0xFF) / 255.0;
      CGFloat g = ((nColor >> 8)  & 0xFF) / 255.0;
      CGFloat b = ((nColor >> 16) & 0xFF) / 255.0;

      NSColorPanel * panel = [NSColorPanel sharedColorPanel];
      panel.color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];

      HBColorPanelDelegate * del = [[HBColorPanelDelegate alloc] init];
      del->ok = NO;
      panel.delegate = del;

      NSView * acc = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 40)];
      NSButton * bOk = [[NSButton alloc] initWithFrame:NSMakeRect(130, 6, 100, 28)];
      bOk.bezelStyle = NSBezelStyleRounded;
      bOk.title = @"OK";
      bOk.keyEquivalent = @"\r";
      bOk.target = del;
      bOk.action = @selector(pickColor:);
      NSButton * bCancel = [[NSButton alloc] initWithFrame:NSMakeRect(20, 6, 100, 28)];
      bCancel.bezelStyle = NSBezelStyleRounded;
      bCancel.title = @"Cancel";
      bCancel.keyEquivalent = @"\033";
      bCancel.target = del;
      bCancel.action = @selector(cancel:);
      [acc addSubview:bOk];
      [acc addSubview:bCancel];
      [panel setAccessoryView:acc];

      [panel makeKeyAndOrderFront:nil];
      [NSApp runModalForWindow:panel];
      [panel orderOut:nil];
      panel.delegate = nil;
      [panel setAccessoryView:nil];

      if( del->ok )
      {
         NSColor * c = [panel.color colorUsingColorSpace:
                        NSColorSpace.genericRGBColorSpace];
         int ir = (int) (c.redComponent   * 255.0 + 0.5);
         int ig = (int) (c.greenComponent * 255.0 + 0.5);
         int ib = (int) (c.blueComponent  * 255.0 + 0.5);
         hb_retni( (ib << 16) | (ig << 8) | ir );
      }
      else
         hb_retni( -1 );
   }
}
