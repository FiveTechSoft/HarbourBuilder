/* android_core.c - Android GUI backend for HarbourBuilder
 *
 * Implements the UI_* HB_FUNCs that classes.prg / user PRGs call to
 * create native android.widget.* controls. Each HB_FUNC turns into a
 * JNI callback into MainActivity which runs on the UI thread.
 *
 * Control handle model: each widget is identified by a small integer
 * id. Harbour receives the id as a numeric handle (hb_retni/hb_parni).
 * Java side keeps a HashMap<Integer,View>.
 *
 * Event dispatch (click): Java calls nativeOnClick(controlId) ->
 * we look up the registered Harbour codeblock for that id and eval it.
 */

#include <jni.h>
#include <string.h>
#include <stdlib.h>
#include <android/log.h>
#include "hbapi.h"
#include "hbapiitm.h"
#include "hbvm.h"
#include "hbstack.h"

#define TAG "HbAndroid"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)

/* ------------ JNI globals ------------ */
static JavaVM  * g_jvm        = NULL;
static jobject   g_activity   = NULL;   /* global ref to MainActivity */
static jclass    g_actClass   = NULL;   /* global ref to MainActivity class */

/* Java method ids (looked up once in nativeInit) */
static jmethodID m_createForm;    /* (String title, int w, int h) -> void */
static jmethodID m_createLabel;   /* (int id, String text, int x, int y, int w, int h) */
static jmethodID m_createButton;  /* idem */
static jmethodID m_createEdit;    /* idem */
static jmethodID m_setText;       /* (int id, String text) */
static jmethodID m_getText;       /* (int id) -> String */

/* ------------ Control id table ------------ */
#define MAX_CTRLS 256
static PHB_ITEM g_click_handlers[MAX_CTRLS] = { 0 };  /* codeblocks */
static int      g_next_id = 1;

JNIEXPORT jint JNICALL JNI_OnLoad( JavaVM * vm, void * reserved )
{
    (void) reserved;
    g_jvm = vm;
    return JNI_VERSION_1_6;
}

static JNIEnv * get_env( void )
{
    JNIEnv * env = NULL;
    (*g_jvm)->GetEnv( g_jvm, (void **) &env, JNI_VERSION_1_6 );
    return env;
}

static jstring to_jstr( JNIEnv * env, const char * s )
{
    return (*env)->NewStringUTF( env, s ? s : "" );
}

/* ================================================================
 *                     Harbour-callable HB_FUNCs
 * ================================================================ */

/* UI_FormNew( cTitle, nWidth, nHeight, cFont, nFontSize ) -> hForm
   On Android a form is the Activity's root FrameLayout. We ignore
   width/height (the Activity is full-screen) but the API keeps the
   same signature so classes.prg compiles untouched. Returns id 1. */
HB_FUNC( UI_FORMNEW )
{
    JNIEnv * env = get_env();
    const char * title = HB_ISCHAR(1) ? hb_parc(1) : "Harbour";
    int w = HB_ISNUM(2) ? hb_parni(2) : 0;
    int h = HB_ISNUM(3) ? hb_parni(3) : 0;

    jstring js = to_jstr( env, title );
    (*env)->CallVoidMethod( env, g_activity, m_createForm, js, w, h );
    (*env)->DeleteLocalRef( env, js );

    hb_retni( 1 );   /* the one and only form id in iter 1 */
}

HB_FUNC( UI_FORMSHOW )  { /* already visible */ }
HB_FUNC( UI_FORMHIDE )  { }
HB_FUNC( UI_FORMCLOSE ) { }
HB_FUNC( UI_FORMDESTROY ) { }

/* UI_FormRun( hForm ) - Android owns the loop; just return. */
HB_FUNC( UI_FORMRUN )   { LOGI( "UI_FormRun (no-op on Android)" ); }

/* Helper to create a widget and bump the id counter. */
static int create_widget( jmethodID m, const char * text, int x, int y, int w, int h )
{
    JNIEnv * env = get_env();
    int id = g_next_id++;
    if( id >= MAX_CTRLS ) { LOGE( "too many controls" ); return 0; }

    jstring js = to_jstr( env, text );
    (*env)->CallVoidMethod( env, g_activity, m, id, js, x, y, w, h );
    (*env)->DeleteLocalRef( env, js );
    return id;
}

/* UI_LabelNew( hParent, cText, nLeft, nTop, nWidth, nHeight ) -> hCtrl */
HB_FUNC( UI_LABELNEW )
{
    int id = create_widget( m_createLabel,
                            HB_ISCHAR(2) ? hb_parc(2) : "",
                            hb_parni(3), hb_parni(4),
                            hb_parni(5), hb_parni(6) );
    hb_retni( id );
}

HB_FUNC( UI_BUTTONNEW )
{
    int id = create_widget( m_createButton,
                            HB_ISCHAR(2) ? hb_parc(2) : "",
                            hb_parni(3), hb_parni(4),
                            hb_parni(5), hb_parni(6) );
    hb_retni( id );
}

HB_FUNC( UI_EDITNEW )
{
    int id = create_widget( m_createEdit,
                            HB_ISCHAR(2) ? hb_parc(2) : "",
                            hb_parni(3), hb_parni(4),
                            hb_parni(5), hb_parni(6) );
    hb_retni( id );
}

/* UI_SetText( hCtrl, cText ) */
HB_FUNC( UI_SETTEXT )
{
    JNIEnv * env = get_env();
    int id = hb_parni(1);
    const char * text = HB_ISCHAR(2) ? hb_parc(2) : "";
    jstring js = to_jstr( env, text );
    (*env)->CallVoidMethod( env, g_activity, m_setText, id, js );
    (*env)->DeleteLocalRef( env, js );
}

/* UI_GetText( hCtrl ) -> cText */
HB_FUNC( UI_GETTEXT )
{
    JNIEnv * env = get_env();
    int id = hb_parni(1);
    jstring js = (jstring)(*env)->CallObjectMethod( env, g_activity, m_getText, id );
    if( js == NULL ) { hb_retc( "" ); return; }
    const char * c = (*env)->GetStringUTFChars( env, js, NULL );
    hb_retc( c );
    (*env)->ReleaseStringUTFChars( env, js, c );
    (*env)->DeleteLocalRef( env, js );
}

/* UI_OnClick( hCtrl, bBlock ) - store codeblock keyed by control id. */
HB_FUNC( UI_ONCLICK )
{
    int id = hb_parni(1);
    PHB_ITEM pBlock = hb_param( 2, HB_IT_BLOCK );
    if( id <= 0 || id >= MAX_CTRLS ) return;
    if( g_click_handlers[id] ) hb_itemRelease( g_click_handlers[id] );
    g_click_handlers[id] = pBlock ? hb_itemNew( pBlock ) : NULL;
}

/* ----- Stubs so classes.prg links even if called. ----- */
HB_FUNC( UI_SETCTRLOWNER )        { }
HB_FUNC( UI_GETCTRLOWNER )        { hb_retptr( NULL ); }
HB_FUNC( UI_GETCTRLPAGE )         { hb_retni( 1 ); }
HB_FUNC( UI_SETPENDINGPAGEOWNER ) { }
HB_FUNC( UI_TABCONTROLNEW )       { hb_retni( 0 ); }

/* ================================================================
 *                     Symbol registration
 * ================================================================ */
static HB_SYMB s_symbols[] = {
    { "UI_FORMNEW",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMNEW       ) }, NULL },
    { "UI_FORMSHOW",      { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMSHOW      ) }, NULL },
    { "UI_FORMHIDE",      { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMHIDE      ) }, NULL },
    { "UI_FORMCLOSE",     { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMCLOSE     ) }, NULL },
    { "UI_FORMDESTROY",   { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMDESTROY   ) }, NULL },
    { "UI_FORMRUN",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_FORMRUN       ) }, NULL },
    { "UI_LABELNEW",      { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_LABELNEW      ) }, NULL },
    { "UI_BUTTONNEW",     { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_BUTTONNEW     ) }, NULL },
    { "UI_EDITNEW",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_EDITNEW       ) }, NULL },
    { "UI_SETTEXT",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETTEXT       ) }, NULL },
    { "UI_GETTEXT",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_GETTEXT       ) }, NULL },
    { "UI_ONCLICK",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_ONCLICK       ) }, NULL },
    { "UI_SETCTRLOWNER",        { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETCTRLOWNER        ) }, NULL },
    { "UI_GETCTRLOWNER",        { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_GETCTRLOWNER        ) }, NULL },
    { "UI_GETCTRLPAGE",         { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_GETCTRLPAGE         ) }, NULL },
    { "UI_SETPENDINGPAGEOWNER", { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_SETPENDINGPAGEOWNER ) }, NULL },
    { "UI_TABCONTROLNEW",       { HB_FS_PUBLIC }, { HB_FUNCNAME( UI_TABCONTROLNEW       ) }, NULL }
};

static void hb_register_android_ui( void )
{
    hb_vmProcessSymbols( s_symbols,
                         sizeof(s_symbols) / sizeof(HB_SYMB),
                         "ANDROID_CORE", 0, HB_PCODE_VER );
}

/* ================================================================
 *                     JNI entry points
 * ================================================================ */

/* Called from MainActivity.onCreate() - once. */
JNIEXPORT void JNICALL
Java_com_harbour_builder_MainActivity_nativeInit( JNIEnv * env, jobject thiz )
{
    g_activity = (*env)->NewGlobalRef( env, thiz );
    jclass cls = (*env)->GetObjectClass( env, thiz );
    g_actClass = (jclass)(*env)->NewGlobalRef( env, cls );

    m_createForm   = (*env)->GetMethodID( env, cls, "createForm",   "(Ljava/lang/String;II)V" );
    m_createLabel  = (*env)->GetMethodID( env, cls, "createLabel",  "(ILjava/lang/String;IIII)V" );
    m_createButton = (*env)->GetMethodID( env, cls, "createButton", "(ILjava/lang/String;IIII)V" );
    m_createEdit   = (*env)->GetMethodID( env, cls, "createEdit",   "(ILjava/lang/String;IIII)V" );
    m_setText      = (*env)->GetMethodID( env, cls, "setCtrlText",  "(ILjava/lang/String;)V" );
    m_getText      = (*env)->GetMethodID( env, cls, "getCtrlText",  "(I)Ljava/lang/String;" );
    (*env)->DeleteLocalRef( env, cls );

    hb_register_android_ui();

    /* HB_TRUE => run Main() in the PRG. Main() will call UI_FormNew etc. */
    hb_vmInit( HB_TRUE );
    LOGI( "Harbour VM initialized, Main() returned" );
}

/* Called by MainActivity when a button is clicked. */
JNIEXPORT void JNICALL
Java_com_harbour_builder_MainActivity_nativeOnClick( JNIEnv * env, jobject thiz,
                                                      jint controlId )
{
    (void) env; (void) thiz;
    if( controlId <= 0 || controlId >= MAX_CTRLS ) return;
    PHB_ITEM pBlock = g_click_handlers[controlId];
    if( pBlock ) hb_evalBlock0( pBlock );
}
