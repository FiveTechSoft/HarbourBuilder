/* ios_core.m - iOS UIKit backend for HarbourBuilder
 *
 * Implements the UI_* HB_FUNCs that classes.prg / user PRGs call to
 * create native UIKit controls. Each HB_FUNC creates/manipulates
 * Objective-C UIView subclasses directly on the main thread.
 *
 * Control handle model: each widget is identified by a small integer
 * id. Harbour receives the id as a numeric handle (hb_retni/hb_parni).
 * A C array maps id -> UIView*.
 *
 * Event dispatch (click): UIButton addTarget calls back into this file,
 * which looks up the registered Harbour codeblock for that id and evals it.
 *
 * Architecture:
 *   - AppDelegate starts the Harbour VM in application:didFinishLaunchingWithOptions:
 *   - UI_FormNew creates a UIViewController with a UIView
 *   - Controls are added as subviews
 *   - UI_FormRun starts UIApplicationMain (or is a no-op if already running)
 */

#import <UIKit/UIKit.h>
#include <string.h>
#include <stdlib.h>
#include "hbapi.h"
#include "hbapiitm.h"
#include "hbvm.h"
#include "hbstack.h"

/* ------------ Control id table ------------ */
#define MAX_CTRLS 256

static UIView *       g_ctrls[MAX_CTRLS]      = { NULL };  /* view map  */
static PHB_ITEM       g_click_handlers[MAX_CTRLS] = { 0 }; /* codeblocks */
static int            g_next_id = 1;
static UIViewController * g_rootVC = NULL;
static UIWindow *        g_window = NULL;

/* Forward declaration of click target (defined below) */
@interface HBActionTarget : NSObject
+ (instancetype) sharedTarget;
- (void) onButtonTap:(UIButton *) sender;
@end

/* BGR (Win32 COLORREF 0x00BBGGRR) -> UIColor */
static UIColor * bgr_to_uicolor( int bgr )
{
    CGFloat r = (CGFloat)( ( bgr       ) & 0xFF ) / 255.0;
    CGFloat g = (CGFloat)( ( bgr >>  8 ) & 0xFF ) / 255.0;
    CGFloat b = (CGFloat)( ( bgr >> 16 ) & 0xFF ) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

/* Store a view and return its id */
static int store_view( UIView * v )
{
    int id = g_next_id++;
    if( id >= MAX_CTRLS ) return 0;
    g_ctrls[id] = v;
    return id;
}

/* ================================================================
 *                     Harbour-callable HB_FUNCs
 * ================================================================ */

/* UI_FormNew( cTitle, nWidth, nHeight, cFont, nFontSize ) -> hForm
   On iOS a form is the root UIViewController's view.
   Width/height are in points (density-independent, like Android dp). */
HB_FUNC( UI_FORMNEW )
{
    const char * title = HB_ISCHAR(1) ? hb_parc(1) : "Harbour";

    if( ! g_window )
    {
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        g_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

        g_rootVC = [[UIViewController alloc] init];
        g_rootVC.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, screenH)];
        g_rootVC.view.backgroundColor = [UIColor whiteColor];
        g_rootVC.title = [NSString stringWithUTF8String:title];

        g_window.rootViewController = g_rootVC;
        [g_window makeKeyAndVisible];
    }
    else
    {
        g_rootVC.title = [NSString stringWithUTF8String:title];
    }

    /* id 1 is always the form */
    if( ! g_ctrls[1] )
        g_ctrls[1] = g_rootVC.view;

    hb_retni( 1 );
}

HB_FUNC( UI_FORMSHOW )  { /* already visible */ }
HB_FUNC( UI_FORMHIDE )  { }
HB_FUNC( UI_FORMCLOSE ) { }
HB_FUNC( UI_FORMDESTROY ) { }

/* UI_FormRun( hForm ) - iOS owns the loop; just return. */
HB_FUNC( UI_FORMRUN ) { }

/* UI_LabelNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) -> hCtrl */
HB_FUNC( UI_LABELNEW )
{
    const char * text = HB_ISCHAR(2) ? hb_parc(2) : "";
    CGFloat x = (CGFloat) hb_parni(3);
    CGFloat y = (CGFloat) hb_parni(4);
    CGFloat w = (CGFloat) hb_parni(5);
    CGFloat h = (CGFloat) hb_parni(6);

    UILabel * label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, h)];
    label.text  = [NSString stringWithUTF8String:text];
    label.textColor = [UIColor blackColor];
    label.textAlignment = NSTextAlignmentLeft;
    [g_rootVC.view addSubview:label];

    hb_retni( store_view(label) );
}

/* UI_ButtonNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) -> hCtrl */
HB_FUNC( UI_BUTTONNEW )
{
    const char * text = HB_ISCHAR(2) ? hb_parc(2) : "";
    CGFloat x = (CGFloat) hb_parni(3);
    CGFloat y = (CGFloat) hb_parni(4);
    CGFloat w = (CGFloat) hb_parni(5);
    CGFloat h = (CGFloat) hb_parni(6);

    UIButton * btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(x, y, w, h);
    [btn setTitle:[NSString stringWithUTF8String:text] forState:UIControlStateNormal];

    /* Give the button a visible rounded-rect background */
    btn.backgroundColor = [UIColor colorWithRed:0.82 green:0.82 blue:0.84 alpha:1.0];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 8.0;
    btn.clipsToBounds = YES;

    /* tag stores the control id for click dispatch */
    int id = g_next_id;   /* pre-allocate id so we can set tag */
    if( id >= MAX_CTRLS ) { hb_retni(0); return; }
    btn.tag = id;
    g_ctrls[id] = btn;
    g_next_id++;

    /* click handler */
    [btn addTarget:[HBActionTarget sharedTarget]
            action:@selector(onButtonTap:)
  forControlEvents:UIControlEventTouchUpInside];

    [g_rootVC.view addSubview:btn];
    hb_retni( id );
}

/* UI_EditNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) -> hCtrl */
HB_FUNC( UI_EDITNEW )
{
    const char * text = HB_ISCHAR(2) ? hb_parc(2) : "";
    CGFloat x = (CGFloat) hb_parni(3);
    CGFloat y = (CGFloat) hb_parni(4);
    CGFloat w = (CGFloat) hb_parni(5);
    CGFloat h = (CGFloat) hb_parni(6);

    UITextField * edit = [[UITextField alloc] initWithFrame:CGRectMake(x, y, w, h)];
    edit.text = [NSString stringWithUTF8String:text];
    edit.borderStyle = UITextBorderStyleRoundedRect;
    edit.font = [UIFont systemFontOfSize:17];
    [g_rootVC.view addSubview:edit];

    hb_retni( store_view(edit) );
}

/* UI_SetText( hCtrl, cText ) */
HB_FUNC( UI_SETTEXT )
{
    int id = hb_parni(1);
    const char * text = HB_ISCHAR(2) ? hb_parc(2) : "";
    if( id <= 0 || id >= MAX_CTRLS || ! g_ctrls[id] ) return;

    UIView * v = g_ctrls[id];
    if( [v isKindOfClass:[UILabel class]] )
        [(UILabel *)v setText:[NSString stringWithUTF8String:text]];
    else if( [v isKindOfClass:[UIButton class]] )
        [(UIButton *)v setTitle:[NSString stringWithUTF8String:text] forState:UIControlStateNormal];
    else if( [v isKindOfClass:[UITextField class]] )
        [(UITextField *)v setText:[NSString stringWithUTF8String:text]];
}

/* UI_GetText( hCtrl ) -> cText */
HB_FUNC( UI_GETTEXT )
{
    int id = hb_parni(1);
    if( id <= 0 || id >= MAX_CTRLS || ! g_ctrls[id] ) { hb_retc(""); return; }

    UIView * v = g_ctrls[id];
    NSString * ns = nil;
    if( [v isKindOfClass:[UILabel class]] )
        ns = [(UILabel *)v text];
    else if( [v isKindOfClass:[UIButton class]] )
        ns = [(UIButton *)v titleForState:UIControlStateNormal];
    else if( [v isKindOfClass:[UITextField class]] )
        ns = [(UITextField *)v text];

    hb_retc( ns ? [ns UTF8String] : "" );
}

/* UI_SetFormColor( nClr ) */
HB_FUNC( UI_SETFORMCOLOR )
{
    int clr = hb_parni(1);
    if( clr < 0 ) return;
    if( g_rootVC )
        g_rootVC.view.backgroundColor = bgr_to_uicolor(clr);
}

/* UI_SetCtrlColor( hCtrl, nClr ) */
HB_FUNC( UI_SETCTRLCOLOR )
{
    int id  = hb_parni(1);
    int clr = hb_parni(2);
    if( id <= 0 || id >= MAX_CTRLS || ! g_ctrls[id] || clr < 0 ) return;
    g_ctrls[id].backgroundColor = bgr_to_uicolor(clr);
}

/* UI_SetCtrlFont( hCtrl, cFamily, nSize ) */
HB_FUNC( UI_SETCTRLFONT )
{
    int id = hb_parni(1);
    const char * family = HB_ISCHAR(2) ? hb_parc(2) : "";
    CGFloat size = (CGFloat)( HB_ISNUM(3) ? hb_parni(3) : 17 );
    if( id <= 0 || id >= MAX_CTRLS || ! g_ctrls[id] ) return;

    UIFont * font;
    if( family[0] )
        font = [UIFont fontWithName:[NSString stringWithUTF8String:family] size:size];
    else
        font = [UIFont systemFontOfSize:size];

    /* fallback if named font not found */
    if( ! font ) font = [UIFont systemFontOfSize:size];

    UIView * v = g_ctrls[id];
    if( [v isKindOfClass:[UILabel class]] )
        [(UILabel *)v setFont:font];
    else if( [v isKindOfClass:[UIButton class]] )
        [(UIButton *)v titleLabel].font = font;
    else if( [v isKindOfClass:[UITextField class]] )
        [(UITextField *)v setFont:font];
}

/* UI_OnClick( hCtrl, bBlock ) */
HB_FUNC( UI_ONCLICK )
{
    int id = hb_parni(1);
    PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
    if( id <= 0 || id >= MAX_CTRLS ) return;
    if( g_click_handlers[id] ) hb_itemRelease( g_click_handlers[id] );
    g_click_handlers[id] = pBlock ? hb_itemNew(pBlock) : NULL;
}

/* ----- Stubs so classes.prg links even if called. ----- */
HB_FUNC( UI_SETCTRLOWNER )        { }
HB_FUNC( UI_GETCTRLOWNER )        { hb_retptr(NULL); }
HB_FUNC( UI_GETCTRLPAGE )         { hb_retni(1); }
HB_FUNC( UI_SETPENDINGPAGEOWNER ) { }
HB_FUNC( UI_TABCONTROLNEW )       { hb_retni(0); }

/* ================================================================
 *          Objective-C helper for button click dispatch
 * ================================================================ */

@implementation HBActionTarget

+ (instancetype) sharedTarget
{
    static HBActionTarget * s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s = [[HBActionTarget alloc] init]; });
    return s;
}

- (void) onButtonTap:(UIButton *) sender
{
    int id = (int) sender.tag;
    if( id <= 0 || id >= MAX_CTRLS ) return;
    PHB_ITEM pBlock = g_click_handlers[id];
    if( pBlock ) hb_evalBlock0( pBlock );
}

@end

/* ================================================================
 *                     Symbol registration
 * ================================================================ */
static HB_SYMB s_symbols[] = {
    { "UI_FORMNEW",              { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMNEW              ) }, NULL },
    { "UI_FORMSHOW",             { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMSHOW             ) }, NULL },
    { "UI_FORMHIDE",             { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMHIDE             ) }, NULL },
    { "UI_FORMCLOSE",            { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMCLOSE            ) }, NULL },
    { "UI_FORMDESTROY",          { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMDESTROY          ) }, NULL },
    { "UI_FORMRUN",              { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMRUN              ) }, NULL },
    { "UI_LABELNEW",             { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_LABELNEW             ) }, NULL },
    { "UI_BUTTONNEW",            { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_BUTTONNEW            ) }, NULL },
    { "UI_EDITNEW",              { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_EDITNEW              ) }, NULL },
    { "UI_SETTEXT",              { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETTEXT              ) }, NULL },
    { "UI_GETTEXT",              { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_GETTEXT              ) }, NULL },
    { "UI_ONCLICK",              { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_ONCLICK              ) }, NULL },
    { "UI_SETFORMCOLOR",         { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETFORMCOLOR         ) }, NULL },
    { "UI_SETCTRLCOLOR",         { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETCTRLCOLOR         ) }, NULL },
    { "UI_SETCTRLFONT",          { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETCTRLFONT          ) }, NULL },
    { "UI_SETCTRLOWNER",         { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETCTRLOWNER         ) }, NULL },
    { "UI_GETCTRLOWNER",         { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_GETCTRLOWNER         ) }, NULL },
    { "UI_GETCTRLPAGE",          { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_GETCTRLPAGE          ) }, NULL },
    { "UI_SETPENDINGPAGEOWNER",  { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETPENDINGPAGEOWNER ) }, NULL },
    { "UI_TABCONTROLNEW",        { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_TABCONTROLNEW       ) }, NULL }
};

static void hb_register_ios_ui( void )
{
    hb_vmProcessSymbols( s_symbols,
                         sizeof(s_symbols) / sizeof(HB_SYMB),
                         "IOS_CORE", 0, HB_PCODE_VER );
}

/* ================================================================
 *                     iOS App entry point
 * ================================================================ */

/* AppDelegate - the iOS application delegate that starts the Harbour VM */
@interface HBAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow * window;
@end

@implementation HBAppDelegate

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    (void) application; (void) launchOptions;

    /* Register our UI_* symbols before starting the VM */
    hb_register_ios_ui();

    /* Start the Harbour VM - this calls Main() in the user's PRG */
    hb_vmInit( HB_TRUE );

    return YES;
}

@end

/* Dummy gt implementation for iOS (no terminal) */
HB_FUNC( GT_SYS_INIT )  { }
HB_FUNC( GT_SYS_EXIT )  { }

/* This is the real C main() - it starts the iOS app.
   The Harbour VM is initialized inside the AppDelegate above. */
int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"HBAppDelegate");
    }
}
