/*
 * gtk3_core.c - GTK3 implementation of hbcpp framework for Linux
 * Replaces the Win32 C++ core (tcontrol.cpp, tform.cpp, tcontrols.cpp, hbbridge.cpp)
 *
 * Provides the same HB_FUNC bridge interface so Harbour code (classes.prg) works unchanged.
 */

#include <gtk/gtk.h>

#ifdef HAVE_WEBKIT2GTK
/* webkit2gtk-4.1 uses webkit/webkit.h, 4.0 uses webkit2/webkit2.h */
#if __has_include(<webkit/webkit.h>)
#include <webkit/webkit.h>
#else
#include <webkit2/webkit2.h>
#endif
#endif

/* Avoid HB_DEPRECATED macro clash between harfbuzz and Harbour */
#undef HB_DEPRECATED

#include <hbapi.h>
#include <hbapiitm.h>
#include <hbapicls.h>
#include <hbstack.h>
#include <hbvm.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <ctype.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <sys/select.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>

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
#define CT_TABCONTROL 10
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
#define CT_DBGRID     80
#define CT_DBNAVIGATOR 81
#define CT_DBTEXT     82
#define CT_DBEDIT     83
#define CT_DBCOMBOBOX 84
#define CT_DBCHECKBOX 85
#define CT_DBIMAGE    86
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
#define CT_SCENE3D    110
#define CT_EARTHVIEW  111
#define CT_MAP        112
#define CT_MAINMENU   132

#define MAX_CHILDREN  256

/* ======================================================================
 * GTK initialization
 * ====================================================================== */

static gboolean s_gtkInitialized = FALSE;

void EnsureGTK( void )
{
   if( !s_gtkInitialized )
   {
      /* Force GDK backend to x11 to avoid conflicts */
      gdk_set_allowed_backends( "x11,wayland,*" );
      gtk_init( NULL, NULL );
      s_gtkInitialized = TRUE;
   }
}


/* ======================================================================
 * Progress dialog state (used by GTK_ShellExec and progress functions)
 * ====================================================================== */

static GtkWidget * s_progressWnd   = NULL;
static GtkWidget * s_progressBar   = NULL;
static GtkWidget * s_progressLabel = NULL;
static GtkWidget * s_progressLog   = NULL;
static int         s_progressSteps = 7;
static int         s_progressCur   = 0;
static int         s_progressCancelled = 0;

/* ======================================================================
 * Forward declarations
 * ====================================================================== */

int GTK_IsDark(void);

typedef struct _HBControl  HBControl;
typedef struct _HBForm     HBForm;
typedef struct _HBButton   HBButton;
typedef struct _HBCheckBox HBCheckBox;
typedef struct _HBComboBox HBComboBox;
typedef struct _HBEdit     HBEdit;
typedef struct _HBGroupBox HBGroupBox;
typedef struct _HBLabel    HBLabel;
typedef struct _HBWebView  HBWebView;

/* ======================================================================
 * HBControl - base control structure
 * ====================================================================== */

struct _HBControl
{
   char  FClassName[32];
   char  FName[64];
   char  FText[256];
   int   FLeft, FTop, FWidth, FHeight;
   int   FVisible, FEnabled, FTabStop;
   int   FControlType;
   GtkWidget * FWidget;
   char  FFontDesc[128];  /* "FontName,Size" */
   unsigned int FClrPane;
   unsigned int FClrText;     /* foreground (text) color; 0xFFFFFFFF = default */
   int   FTransparent;        /* 1 = no background paint (labels default) */
   int   FAlign;              /* 0=Left, 1=Center, 2=Right (Label/Edit) */

   PHB_ITEM FOnClick, FOnChange, FOnInit, FOnClose;

   HBControl * FCtrlParent;
   HBControl * FChildren[MAX_CHILDREN];
   int FChildCount;

   /* TFolder/TPageControl ownership: when this control was created with
      OF ::oFolder:aPages[N], FPageOwner points to the TFolder and
      FPageIndex is the 0-based page. NULL owner = not paged. */
   HBControl * FPageOwner;
   int         FPageIndex;
};

/* ======================================================================
 * HBForm - form/window structure
 * ====================================================================== */

struct _HBForm
{
   HBControl base;
   GtkWidget *  FWindow;
   GtkWidget *  FFixed;      /* GtkFixed container for absolute positioning */
   char         FFormFontDesc[128];
   int          FCenter;
   int          FSizable;
   int          FAppBar;
   int          FModalResult;
   int          FRunning;
   int          FDesignMode;
   HBControl *  FSelected[MAX_CHILDREN];
   int          FSelCount;
   int          FDragging, FResizing;
   int          FResizeHandle;
   int          FDragStartX, FDragStartY;
   int          FRubberBand;
   int          FRubberX1, FRubberY1, FRubberX2, FRubberY2;
   PHB_ITEM     FOnSelChange;
   GtkWidget *  FOverlay;    /* Drawing area for selection handles */
   /* Toolbars (up to 4 rows) */
   HBControl *  FToolBars[4];
   int          FToolBarCount;
   int          FClientTop;
   /* Menu */
   GtkWidget *  FMenuBar;
   PHB_ITEM     FMenuActions[128];
   int          FMenuItemCount;
   /* C++Builder TForm properties */
   int          FBorderStyle;    /* bsNone..bsSizeToolWin */
   int          FBorderIcons;    /* bitmask: biSystemMenu|biMinimize|biMaximize */
   int          FBorderWidth;
   int          FPosition;       /* poDesigned..poMainFormCenter */
   int          FWindowState;    /* wsNormal, wsMinimized, wsMaximized */
   int          FFormStyle;      /* fsNormal, fsStayOnTop, fsMDIChild, fsMDIForm */
   int          FCursor;
   int          FKeyPreview;
   int          FAlphaBlend;
   int          FAlphaBlendValue;
   int          FShowHint;
   char         FHint[256];
   int          FAutoScroll;
   int          FDoubleBuffered;
   char         FAppTitle[128];
   int          FClrPaneExplicit; /* 1 once user set nClrPane — CSS uses USER priority to beat dark-mode */
   /* Component drop (palette) */
   int          FPendingControlType;
   PHB_ITEM     FOnComponentDrop;
   /* Events (C++Builder TForm properties) */
   PHB_ITEM     FOnActivate, FOnDeactivate, FOnResize, FOnPaint;
   PHB_ITEM     FOnShow, FOnHide, FOnCloseQuery, FOnCreate, FOnDestroy;
   PHB_ITEM     FOnKeyDown, FOnKeyUp, FOnKeyPress;
   PHB_ITEM     FOnMouseDown, FOnMouseUp, FOnMouseMove, FOnDblClick, FOnMouseWheel;
};

/* ======================================================================
 * Specific control structures
 * ====================================================================== */

/* TFolder / TPageControl (CT_TABCONTROL2) — a bar of tabs, children of
   the form that carry FPageOwner=this + FPageIndex=N are shown only
   when their page is active. FTabs is pipe-separated "Tab1|Tab2|..." */
typedef struct {
   HBControl base;
   char      FTabs[1024];
   int       FPageCount;
} HBTabControl2;

struct _HBLabel    { HBControl base; };
struct _HBEdit     { HBControl base; int FReadOnly, FPassword; };
struct _HBButton   { HBControl base; int FDefault, FCancel; };
struct _HBCheckBox { HBControl base; int FChecked; };
struct _HBGroupBox { HBControl base; };
struct _HBComboBox {
   HBControl base;
   int  FItemIndex;
   char FItems[32][64];
   int  FItemCount;
};

typedef struct { HBControl base; int FChecked; char FGroupName[32]; } HBRadioButton;

typedef struct {
   HBControl base;
   char FGlyph[256];
   int  FLayout;     /* 0=left, 1=right, 2=top, 3=bottom */
   int  FSpacing;
} HBBitBtn;

typedef struct {
   HBControl base;
   char FPicture[256];
   int  FStretch;
   int  FCenter;
   int  FProportional;
} HBImage;

struct _HBWebView {
   HBControl base;
   char FUrl[512];
};

typedef struct {
   HBControl base;
   int  FShape;       /* 0=rect, 1=circle, 2=rounded, 3=ellipse */
   int  FPenColor;
   int  FPenWidth;
   int  FBrushColor;
} HBShape;

typedef struct {
   HBControl base;
   int  FBevelStyle;   /* 0=raised, 1=lowered */
   int  FBevelShape;   /* 0=box, 1=frame, 2=topLine, 3=bottomLine */
} HBBevel;

#define MAX_MENU_NODES 128

typedef struct {
   char  szCaption[128];
   char  szShortcut[32];
   char  szHandler[128];
   int   bSeparator;
   int   bEnabled;
   int   nParent;
   int   nLevel;
} HBMenuNode;

typedef struct {
   HBControl   base;
   HBMenuNode  FNodes[MAX_MENU_NODES];
   int         FNodeCount;
   PHB_ITEM    FOnClickArray;  /* Harbour array of blocks indexed by node, set by aOnClick ASSIGN */
} HBMainMenu;

typedef struct {
   HBControl base;
   int      FInterval;   /* Timer interval in ms (default 1000) */
   guint    FTimerID;    /* g_timeout_add() source ID, 0 = stopped */
   PHB_ITEM FOnTimer;    /* OnTimer event block */
} HBTimer;

typedef struct {
   HBControl base;
   int  FReadOnly;
   int  FWordWrap;
   int  FScrollBars;  /* 0=none, 1=horiz, 2=vert, 3=both */
} HBRichEdit;

typedef struct {
   HBControl base;
   int  FViewStyle;    /* 0=icon, 1=smallIcon, 2=list, 3=report */
   int  FGridLines;
   int  FColumnCount;
   char FColumns[16][64];
   int  FColumnWidths[16];
} HBListView;

#define MAX_BROWSE_COLS 16

typedef struct {
   char szTitle[64];
   char szFieldName[64];
   int  nWidth;
   int  nAlign;        /* 0=left, 1=center, 2=right */
   char szFooterText[64];
} HBBrowseCol;

typedef struct {
   HBControl    base;
   int          FReadOnly;
   int          FGridLines;
   int          FRowHeight;
   int          FColumnCount;
   int          FRowCount;
   HBBrowseCol  FCols[MAX_BROWSE_COLS];
   GtkListStore * FStore;
   GtkWidget    * FTreeView;
   GtkWidget    * FFooterBar;    /* GtkDrawingArea for per-column footer */
   char         FDataSourceName[64];
} HBBrowse;

#define MAX_TOOLBTNS  64
#define TOOLBAR_BTN_ID_BASE 100
#define MENU_ID_BASE        1000

typedef struct _HBToolBar {
   HBControl base;
   char     FBtnTexts[MAX_TOOLBTNS][32];
   char     FBtnTooltips[MAX_TOOLBTNS][128];
   int      FBtnSeparator[MAX_TOOLBTNS];
   PHB_ITEM FBtnOnClick[MAX_TOOLBTNS];
   int      FBtnCount;
   GtkWidget * FToolBarWidget;
   GdkPixbuf * FIconImages[MAX_TOOLBTNS];
   int      FIconCount;
} HBToolBar;

/* ======================================================================
 * Object lifetime management
 * ====================================================================== */

static HBControl ** s_allControls = NULL;
static int s_nControls = 0;
static int s_nCapacity = 0;

/* Returns 1 if the control type is non-visual (fixed 28x28 icon, no resize) */
static int IsNonVisualControl( int t )
{
   switch( t ) {
      case CT_TIMER: case CT_OPENDIALOG: case CT_SAVEDIALOG:
      case CT_FONTDIALOG: case CT_COLORDIALOG: case CT_FINDDIALOG: case CT_REPLACEDIALOG:
      case CT_OPENAI: case CT_GEMINI: case CT_CLAUDE: case CT_DEEPSEEK:
      case CT_GROK: case CT_OLLAMA: case CT_TRANSFORMER:
      case CT_DBFTABLE: case CT_MYSQL: case CT_MARIADB: case CT_POSTGRESQL:
      case CT_SQLITE: case CT_FIREBIRD: case CT_SQLSERVER: case CT_ORACLE: case CT_MONGODB:
      case CT_THREAD: case CT_MUTEX: case CT_SEMAPHORE: case CT_CRITICALSECTION:
      case CT_THREADPOOL: case CT_ATOMICINT: case CT_CONDVAR: case CT_CHANNEL:
      case CT_WEBSERVER: case CT_WEBSOCKET: case CT_HTTPCLIENT: case CT_FTPCLIENT:
      case CT_SMTPCLIENT: case CT_TCPSERVER: case CT_TCPCLIENT: case CT_UDPSOCKET:
      case CT_PREPROCESSOR: case CT_SCRIPTENGINE: case CT_REPORTDESIGNER:
      case CT_BARCODE: case CT_PDFGENERATOR: case CT_EXCELEXPORT:
      case CT_AUDITLOG: case CT_PERMISSIONS: case CT_CURRENCY: case CT_TAXENGINE:
      case CT_PRINTER: case CT_REPORT: case CT_LABELS: case CT_PAGESETUP:
      case CT_PRINTDIALOG: case CT_BARCODEPRINTER:
      case CT_MAINMENU:
         return 1;
      default:
         return 0;
   }
}

/* Palette icon cache: indexed by control type, used for non-visual component icons on form */
#define MAX_ICON_CACHE 256
static GdkPixbuf * s_paletteIcons[MAX_ICON_CACHE];

static void KeepAlive( HBControl * p )
{
   if( s_nControls >= s_nCapacity )
   {
      s_nCapacity = s_nCapacity ? s_nCapacity * 2 : 64;
      s_allControls = realloc( s_allControls, s_nCapacity * sizeof(HBControl*) );
   }
   s_allControls[s_nControls++] = p;
}

static void RemoveControl( HBControl * p )
{
   for( int i = 0; i < s_nControls; i++ )
   {
      if( s_allControls[i] == p )
      {
         s_allControls[i] = s_allControls[--s_nControls];
         break;
      }
   }
}

/* ======================================================================
 * HBControl methods
 * ====================================================================== */

static void HBControl_Init( HBControl * p )
{
   strcpy( p->FClassName, "TControl" );
   p->FName[0] = 0; p->FText[0] = 0;
   p->FLeft = 0; p->FTop = 0; p->FWidth = 80; p->FHeight = 24;
   p->FVisible = 1; p->FEnabled = 1; p->FTabStop = 1;
   p->FControlType = 0; p->FWidget = NULL;
   strcpy( p->FFontDesc, "Sans 12" );
   p->FClrPane = 0xFFFFFFFF;
   p->FClrText = 0xFFFFFFFF;
   p->FTransparent = 1;
   p->FAlign = 0;
   p->FOnClick = NULL; p->FOnChange = NULL;
   p->FOnInit = NULL; p->FOnClose = NULL;
   p->FCtrlParent = NULL; p->FChildCount = 0;
   memset( p->FChildren, 0, sizeof(p->FChildren) );
   p->FPageOwner = NULL;
   p->FPageIndex = 0;
}

/* Module globals: pending page ownership consumed by the next AddChild.
   Set by TFolderPage:hCpp (UI_SETPENDINGPAGEOWNER) or by the designer
   when a palette drop falls inside a TFolder's client area. */
static HBControl * g_pendingPageOwner = NULL;
static int         g_pendingPageIndex = 0;

static void HbApplyPendingPageOwner( HBControl * pCtrl )
{
   if( pCtrl && g_pendingPageOwner )
   {
      pCtrl->FPageOwner = g_pendingPageOwner;
      pCtrl->FPageIndex = g_pendingPageIndex;
      g_pendingPageOwner = NULL;
      g_pendingPageIndex = 0;
   }
}

static void HBControl_CreateWidget( HBControl * child, GtkWidget * fixed, const char * fontDesc );
static GtkWidget * HBTabControl2_GetPageFixed( HBControl * p, int nPage );

static void HBControl_AddChild( HBControl * parent, HBControl * child )
{
   if( parent->FChildCount < MAX_CHILDREN )
   {
      parent->FChildren[parent->FChildCount++] = child;
      child->FCtrlParent = parent;
      /* If TFolderPage:hCpp set a pending owner just before this call,
         claim ownership for that page now. */
      HbApplyPendingPageOwner( child );

      /* If parent form is already shown (FFixed exists) and child has no widget yet,
         auto-create the GTK widget so runtime-added controls are visible.
         When child has FPageOwner set (from TFolderPage:hCpp) route the
         widget into that folder page's GtkFixed instead of form->FFixed,
         so the notebook handles its visibility + event routing natively. */
      if( parent->FControlType == CT_FORM && !child->FWidget )
      {
         HBForm * form = (HBForm *) parent;
         GtkWidget * container = form->FFixed;
         if( child->FPageOwner )
         {
            GtkWidget * page = HBTabControl2_GetPageFixed(
               child->FPageOwner, child->FPageIndex );
            if( page ) container = page;
         }
         if( container )
            HBControl_CreateWidget( child, container, form->FFormFontDesc );
      }
   }
}

static void HBControl_SetText( HBControl * p, const char * text )
{
   strncpy( p->FText, text, sizeof(p->FText) - 1 );
   p->FText[sizeof(p->FText) - 1] = 0;
}

static void HBControl_FireEvent( HBControl * p, PHB_ITEM block );

/* Timer helpers — defined here so HBControl_SetEvent can use them */
static gboolean on_timer_tick( gpointer data )
{
   HBTimer * t = (HBTimer *) data;
   if( t->FOnTimer && t->base.FEnabled )
      HBControl_FireEvent( &t->base, t->FOnTimer );
   return t->base.FEnabled ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;
}

static void HBTimer_Start( HBTimer * t )
{
   if( t->FTimerID ) g_source_remove( t->FTimerID );
   t->FTimerID = 0;
   if( t->base.FEnabled && t->FInterval > 0 && t->FOnTimer )
   {
      EnsureGTK();
      t->FTimerID = g_timeout_add( (guint)t->FInterval, on_timer_tick, t );
   }
}

static void HBTimer_Stop( HBTimer * t )
{
   if( t->FTimerID ) { g_source_remove( t->FTimerID ); t->FTimerID = 0; }
}

static void HBControl_SetEvent( HBControl * p, const char * event, PHB_ITEM block )
{
   PHB_ITEM * ppTarget = NULL;
   if( strcasecmp( event, "OnClick" ) == 0 )       ppTarget = &p->FOnClick;
   else if( strcasecmp( event, "OnChange" ) == 0 )  ppTarget = &p->FOnChange;
   else if( strcasecmp( event, "OnInit" ) == 0 )    ppTarget = &p->FOnInit;
   else if( strcasecmp( event, "OnClose" ) == 0 )   ppTarget = &p->FOnClose;
   /* Form-specific events */
   else if( p->FControlType == CT_FORM ) {
      HBForm * f = (HBForm *)( (char*)p - offsetof(HBForm, base) );
      if( strcasecmp( event, "OnActivate" ) == 0 )      ppTarget = &f->FOnActivate;
      else if( strcasecmp( event, "OnDeactivate" ) == 0 ) ppTarget = &f->FOnDeactivate;
      else if( strcasecmp( event, "OnResize" ) == 0 )    ppTarget = &f->FOnResize;
      else if( strcasecmp( event, "OnPaint" ) == 0 )     ppTarget = &f->FOnPaint;
      else if( strcasecmp( event, "OnShow" ) == 0 )      ppTarget = &f->FOnShow;
      else if( strcasecmp( event, "OnHide" ) == 0 )      ppTarget = &f->FOnHide;
      else if( strcasecmp( event, "OnCloseQuery" ) == 0 ) ppTarget = &f->FOnCloseQuery;
      else if( strcasecmp( event, "OnCreate" ) == 0 )    ppTarget = &f->FOnCreate;
      else if( strcasecmp( event, "OnDestroy" ) == 0 )   ppTarget = &f->FOnDestroy;
      else if( strcasecmp( event, "OnKeyDown" ) == 0 )   ppTarget = &f->FOnKeyDown;
      else if( strcasecmp( event, "OnKeyUp" ) == 0 )     ppTarget = &f->FOnKeyUp;
      else if( strcasecmp( event, "OnKeyPress" ) == 0 )  ppTarget = &f->FOnKeyPress;
      else if( strcasecmp( event, "OnMouseDown" ) == 0 )  ppTarget = &f->FOnMouseDown;
      else if( strcasecmp( event, "OnMouseUp" ) == 0 )    ppTarget = &f->FOnMouseUp;
      else if( strcasecmp( event, "OnMouseMove" ) == 0 )  ppTarget = &f->FOnMouseMove;
      else if( strcasecmp( event, "OnDblClick" ) == 0 )   ppTarget = &f->FOnDblClick;
      else if( strcasecmp( event, "OnMouseWheel" ) == 0 ) ppTarget = &f->FOnMouseWheel;
   }
   /* Timer-specific event */
   else if( p->FControlType == CT_TIMER && strcasecmp( event, "OnTimer" ) == 0 )
   {
      HBTimer * t = (HBTimer *)p;
      if( t->FOnTimer ) hb_itemRelease( t->FOnTimer );
      t->FOnTimer = hb_itemNew( block );
      /* Auto-start timer when OnTimer is assigned */
      if( t->base.FEnabled && t->FInterval > 0 )
         HBTimer_Start( t );
      return;
   }
   if( ppTarget )
   {
      if( *ppTarget ) hb_itemRelease( *ppTarget );
      *ppTarget = hb_itemNew( block );
   }
}

static void HBControl_FireEvent( HBControl * p, PHB_ITEM block )
{
   if( block && HB_IS_BLOCK( block ) )
   {
      hb_vmPushEvalSym();
      hb_vmPush( block );
      hb_vmSend( 0 );
   }
}

static void HBControl_ReleaseEvents( HBControl * p )
{
   if( p->FOnClick )  { hb_itemRelease( p->FOnClick );  p->FOnClick = NULL; }
   if( p->FOnChange ) { hb_itemRelease( p->FOnChange ); p->FOnChange = NULL; }
   if( p->FOnInit )   { hb_itemRelease( p->FOnInit );   p->FOnInit = NULL; }
   if( p->FOnClose )  { hb_itemRelease( p->FOnClose );  p->FOnClose = NULL; }
}

static void HBControl_ApplyFont( HBControl * p )
{
   if( p->FWidget && p->FFontDesc[0] )
   {
      /* Parse "Sans 12" into family and size for CSS */
      char family[64] = "Sans";
      int size = 12;
      const char * lastSpace = strrchr( p->FFontDesc, ' ' );
      if( lastSpace ) {
         int len = (int)(lastSpace - p->FFontDesc); if( len > 63 ) len = 63;
         memcpy( family, p->FFontDesc, len ); family[len] = 0;
         size = atoi( lastSpace + 1 );
      }
      if( size <= 0 ) size = 12;

      GtkCssProvider * provider = gtk_css_provider_new();
      char css[256];
      snprintf( css, sizeof(css), "* { font-family: \"%s\"; font-size: %dpt; }", family, size );
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( p->FWidget );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
      g_object_unref( provider );

      /* TLabel auto-grow on font change: measure text with Pango since
         CSS-driven preferred sizes don't settle until the next layout pass. */
      if( p->FControlType == CT_LABEL )
      {
         PangoLayout * layout = gtk_widget_create_pango_layout( p->FWidget, p->FText );
         char desc[128];
         snprintf( desc, sizeof(desc), "%s %dpt", family, size );
         PangoFontDescription * fd = pango_font_description_from_string( desc );
         pango_layout_set_font_description( layout, fd );
         int tw = 0, th = 0;
         pango_layout_get_pixel_size( layout, &tw, &th );
         pango_font_description_free( fd );
         g_object_unref( layout );
         if( tw > p->FWidth )  p->FWidth  = tw + 4;
         if( th > p->FHeight ) p->FHeight = th + 2;
         gtk_widget_set_size_request( p->FWidget, p->FWidth, p->FHeight );
      }
   }
}

/* Apply foreground (nClrText) and background (nClrPane, when not transparent)
   to the widget via CSS USER-priority provider. */
static void HBControl_ApplyColors( HBControl * p )
{
   if( !p->FWidget ) return;
   char css[512] = "";
   int has = 0;
   if( p->FClrText != 0xFFFFFFFF )
   {
      int r = p->FClrText & 0xFF, g = (p->FClrText >> 8) & 0xFF, b = (p->FClrText >> 16) & 0xFF;
      char buf[128];
      snprintf( buf, sizeof(buf), "* { color: #%02X%02X%02X; }", r, g, b );
      strcat( css, buf );
      has = 1;
   }
   if( !p->FTransparent && p->FClrPane != 0xFFFFFFFF )
   {
      int r = p->FClrPane & 0xFF, g = (p->FClrPane >> 8) & 0xFF, b = (p->FClrPane >> 16) & 0xFF;
      char buf[160];
      snprintf( buf, sizeof(buf),
         "* { background-color: #%02X%02X%02X; background-image: none; }", r, g, b );
      strcat( css, buf );
      has = 1;
   }
   if( !has ) return;
   GtkCssProvider * prov = gtk_css_provider_new();
   gtk_css_provider_load_from_data( prov, css, -1, NULL );
   gtk_style_context_add_provider( gtk_widget_get_style_context( p->FWidget ),
      GTK_STYLE_PROVIDER(prov), GTK_STYLE_PROVIDER_PRIORITY_USER );
   g_object_unref( prov );
}

/* Apply alignment for Label/Edit via GTK APIs. */
static void HBControl_ApplyAlign( HBControl * p )
{
   if( !p->FWidget ) return;
   GtkAlign ha = GTK_ALIGN_START;
   gfloat xa = 0.0f, ea = 0.0f;
   if( p->FAlign == 1 )      { ha = GTK_ALIGN_CENTER; xa = 0.5f; ea = 0.5f; }
   else if( p->FAlign == 2 ) { ha = GTK_ALIGN_END;    xa = 1.0f; ea = 1.0f; }
   if( p->FControlType == CT_LABEL )
   {
      gtk_label_set_xalign( GTK_LABEL(p->FWidget), xa );
      gtk_widget_set_halign( p->FWidget, ha );
   }
   else if( p->FControlType == CT_EDIT || p->FControlType == CT_MASKEDIT2 ||
            p->FControlType == CT_LABELEDEDIT )
   {
      gtk_entry_set_alignment( GTK_ENTRY(p->FWidget), ea );
   }
}

static void HBControl_UpdatePosition( HBControl * p )
{
   if( !p->FWidget || !p->FCtrlParent ) return;

   HBForm * form = NULL;
   HBControl * par = p->FCtrlParent;
   while( par )
   {
      if( par->FControlType == CT_FORM ) { form = (HBForm *)par; break; }
      par = par->FCtrlParent;
   }

   if( form && form->FFixed )
   {
      gtk_fixed_move( GTK_FIXED(form->FFixed), p->FWidget, p->FLeft, p->FTop );
      gtk_widget_set_size_request( p->FWidget, p->FWidth, p->FHeight );
   }
}

/* ======================================================================
 * Control creation functions
 * ====================================================================== */

static void HBLabel_CreateWidget( HBLabel * p, GtkWidget * container )
{
   GtkWidget * label = gtk_label_new( p->base.FText );
   gtk_widget_set_halign( label, GTK_ALIGN_START );
   gtk_widget_set_valign( label, GTK_ALIGN_CENTER );
   gtk_fixed_put( GTK_FIXED(container), label, p->base.FLeft, p->base.FTop );
   gtk_widget_set_size_request( label, p->base.FWidth, p->base.FHeight );
   p->base.FWidget = label;
   /* ApplyFont handles auto-grow for CT_LABEL after measuring with Pango */
   HBControl_ApplyFont( &p->base );
   HBControl_ApplyColors( &p->base );
   HBControl_ApplyAlign( &p->base );
   gtk_widget_show( label );
}

static void HBEdit_CreateWidget( HBEdit * p, GtkWidget * container )
{
   GtkWidget * entry = gtk_entry_new();
   gtk_entry_set_text( GTK_ENTRY(entry), p->base.FText );
   if( p->FReadOnly )
      gtk_editable_set_editable( GTK_EDITABLE(entry), FALSE );
   if( p->FPassword )
      gtk_entry_set_visibility( GTK_ENTRY(entry), FALSE );
   gtk_fixed_put( GTK_FIXED(container), entry, p->base.FLeft, p->base.FTop );
   gtk_widget_set_size_request( entry, p->base.FWidth, p->base.FHeight );
   p->base.FWidget = entry;
   HBControl_ApplyFont( &p->base );
   HBControl_ApplyColors( &p->base );
   HBControl_ApplyAlign( &p->base );
   gtk_widget_show( entry );
}

static void on_button_clicked( GtkWidget * widget, gpointer data )
{
   HBButton * p = (HBButton *)data;
   HBControl_FireEvent( &p->base, p->base.FOnClick );

   /* Find parent form */
   HBControl * par = p->base.FCtrlParent;
   while( par && par->FControlType != CT_FORM ) par = par->FCtrlParent;

   if( par )
   {
      HBForm * frm = (HBForm *)par;
      if( p->FDefault ) frm->FModalResult = 1;
      else if( p->FCancel ) frm->FModalResult = 2;
      if( p->FDefault || p->FCancel )
      {
         /* Destroy triggers on_window_destroy which checks FRunning
          * to decide whether to quit the gtk_main loop */
         if( frm->FWindow ) gtk_widget_destroy( frm->FWindow );
      }
   }
}

static void HBButton_CreateWidget( HBButton * p, GtkWidget * container )
{
   /* Strip '&' from button text (accelerator markers) */
   char clean[256];
   const char * src = p->base.FText;
   int j = 0;
   while( *src && j < 255 ) { if( *src != '&' ) clean[j++] = *src; src++; }
   clean[j] = 0;

   GtkWidget * btn = gtk_button_new_with_label( clean );
   g_signal_connect( btn, "clicked", G_CALLBACK(on_button_clicked), p );
   gtk_fixed_put( GTK_FIXED(container), btn, p->base.FLeft, p->base.FTop );
   gtk_widget_set_size_request( btn, p->base.FWidth, p->base.FHeight );
   p->base.FWidget = btn;
   HBControl_ApplyFont( &p->base );
   gtk_widget_show( btn );
}

static void HBCheckBox_CreateWidget( HBCheckBox * p, GtkWidget * container )
{
   GtkWidget * chk = gtk_check_button_new_with_label( p->base.FText );
   gtk_toggle_button_set_active( GTK_TOGGLE_BUTTON(chk), p->FChecked );
   gtk_fixed_put( GTK_FIXED(container), chk, p->base.FLeft, p->base.FTop );
   gtk_widget_set_size_request( chk, p->base.FWidth, p->base.FHeight );
   p->base.FWidget = chk;
   HBControl_ApplyFont( &p->base );
   gtk_widget_show( chk );
}

static void on_combo_changed( GtkWidget * widget, gpointer data )
{
   HBComboBox * p = (HBComboBox *)data;
   p->FItemIndex = gtk_combo_box_get_active( GTK_COMBO_BOX(widget) );
   HBControl_FireEvent( &p->base, p->base.FOnChange );
}

static void HBComboBox_CreateWidget( HBComboBox * p, GtkWidget * container )
{
   GtkWidget * combo = gtk_combo_box_text_new();
   for( int i = 0; i < p->FItemCount; i++ )
      gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(combo), p->FItems[i] );
   if( p->FItemCount > 0 )
   {
      int selRow = p->FItemIndex > 0 ? p->FItemIndex - 1 : 0;
      if( selRow >= p->FItemCount ) selRow = 0;
      gtk_combo_box_set_active( GTK_COMBO_BOX(combo), selRow );
      p->FItemIndex = selRow + 1;
   }
   g_signal_connect( combo, "changed", G_CALLBACK(on_combo_changed), p );
   gtk_fixed_put( GTK_FIXED(container), combo, p->base.FLeft, p->base.FTop );
   gtk_widget_set_size_request( combo, p->base.FWidth, p->base.FHeight );
   p->base.FWidget = combo;
   HBControl_ApplyFont( &p->base );
   gtk_widget_show( combo );
}

static void HBGroupBox_CreateWidget( HBGroupBox * p, GtkWidget * container )
{
   GtkWidget * frame = gtk_frame_new( p->base.FText );
   gtk_fixed_put( GTK_FIXED(container), frame, p->base.FLeft, p->base.FTop );
   gtk_widget_set_size_request( frame, p->base.FWidth, p->base.FHeight );
   p->base.FWidget = frame;
   HBControl_ApplyFont( &p->base );
   gtk_widget_show( frame );
}

/* ======================================================================
 * Design mode overlay - drawing and interaction
 * ====================================================================== */

static gboolean on_overlay_draw( GtkWidget * widget, cairo_t * cr, gpointer data )
{
   HBForm * form = (HBForm *)data;
   if( !form->FDesignMode ) return FALSE;

   /* Classic C++Builder dot grid */
   {
      GtkAllocation alloc;
      gtk_widget_get_allocation( widget, &alloc );
      cairo_set_source_rgba( cr, 0.0, 0.0, 0.0, 0.28 );
      int gridStep = 8;
      for( int y = 0; y < alloc.height; y += gridStep )
         for( int x = 0; x < alloc.width; x += gridStep )
            cairo_rectangle( cr, x, y, 1, 1 );
      cairo_fill( cr );
   }

   /* Draw 4 corner dots on ALL non-visual controls (always visible, not just selected) */
   for( int nv = 0; nv < form->base.FChildCount; nv++ )
   {
      HBControl * c = form->base.FChildren[nv];
      if( !IsNonVisualControl( c->FControlType ) ) continue;
      int l = c->FLeft, t = c->FTop, w = c->FWidth, h = c->FHeight;

      /* Dashed blue border */
      cairo_set_source_rgb( cr, 0.0, 0.47, 0.84 );
      double nvDash[] = { 4.0, 2.0 };
      cairo_set_dash( cr, nvDash, 2, 0 );
      cairo_set_line_width( cr, 1.0 );
      cairo_rectangle( cr, l - 1, t - 1, w + 2, h + 2 );
      cairo_stroke( cr );
      cairo_set_dash( cr, NULL, 0, 0 );

      int cx[4], cy[4];
      cx[0]=l-3; cy[0]=t-3; cx[1]=l+w-3; cy[1]=t-3;
      cx[2]=l+w-3; cy[2]=t+h-3; cx[3]=l-3; cy[3]=t+h-3;
      for( int j = 0; j < 4; j++ )
      {
         cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
         cairo_rectangle( cr, cx[j], cy[j], 7, 7 );
         cairo_fill( cr );
         cairo_set_source_rgb( cr, 0.5, 0.5, 0.5 );
         cairo_rectangle( cr, cx[j], cy[j], 7, 7 );
         cairo_stroke( cr );
      }
   }

   /* Draw selection handles */
   for( int i = 0; i < form->FSelCount; i++ )
   {
      HBControl * ctrl = form->FSelected[i];
      int l = ctrl->FLeft, t = ctrl->FTop, w = ctrl->FWidth, h = ctrl->FHeight;

      /* Dashed border */
      cairo_set_source_rgb( cr, 0.0, 0.47, 0.84 );
      double dashes[] = { 4.0, 2.0 };
      cairo_set_dash( cr, dashes, 2, 0 );
      cairo_set_line_width( cr, 1.0 );
      cairo_rectangle( cr, l - 1, t - 1, w + 2, h + 2 );
      cairo_stroke( cr );
      cairo_set_dash( cr, NULL, 0, 0 );

      /* 8 resize handles (visual controls only, non-visual dots drawn above) */
      if( ! IsNonVisualControl( ctrl->FControlType ) )
      {
         int px = l, py = t, pw = w, ph = h;
         int hx[8], hy[8];
         hx[0]=px-3; hy[0]=py-3; hx[1]=px+pw/2-3; hy[1]=py-3;
         hx[2]=px+pw-3; hy[2]=py-3; hx[3]=px+pw-3; hy[3]=py+ph/2-3;
         hx[4]=px+pw-3; hy[4]=py+ph-3; hx[5]=px+pw/2-3; hy[5]=py+ph-3;
         hx[6]=px-3; hy[6]=py+ph-3; hx[7]=px-3; hy[7]=py+ph/2-3;

         for( int j = 0; j < 8; j++ )
         {
            /* White fill */
            cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
            cairo_rectangle( cr, hx[j], hy[j], 7, 7 );
            cairo_fill( cr );
            /* Blue border */
            cairo_set_source_rgb( cr, 0.0, 0.47, 0.84 );
            cairo_rectangle( cr, hx[j], hy[j], 7, 7 );
            cairo_stroke( cr );
         }
      }
   }

   /* Rubber band rectangle */
   if( form->FRubberBand )
   {
      int rx = form->FRubberX1 < form->FRubberX2 ? form->FRubberX1 : form->FRubberX2;
      int ry = form->FRubberY1 < form->FRubberY2 ? form->FRubberY1 : form->FRubberY2;
      int rw = abs(form->FRubberX2 - form->FRubberX1);
      int rh = abs(form->FRubberY2 - form->FRubberY1);
      cairo_set_source_rgba( cr, 0.0, 0.47, 0.84, 0.1 );
      cairo_rectangle( cr, rx, ry, rw, rh );
      cairo_fill( cr );
      cairo_set_source_rgb( cr, 0.0, 0.47, 0.84 );
      double dashes[] = { 3.0, 3.0 };
      cairo_set_dash( cr, dashes, 2, 0 );
      cairo_set_line_width( cr, 1.0 );
      cairo_rectangle( cr, rx, ry, rw, rh );
      cairo_stroke( cr );
      cairo_set_dash( cr, NULL, 0, 0 );
   }

   return FALSE;
}

static int HBForm_HitTestHandle( HBForm * form, int mx, int my )
{
   for( int i = 0; i < form->FSelCount; i++ )
   {
      HBControl * p = form->FSelected[i];
      /* Non-visual controls have no resize handles */
      if( IsNonVisualControl( p->FControlType ) ) continue;
      int px=p->FLeft, py=p->FTop, pw=p->FWidth, ph=p->FHeight;
      int hx[8], hy[8];
      hx[0]=px-3; hy[0]=py-3; hx[1]=px+pw/2-3; hy[1]=py-3;
      hx[2]=px+pw-3; hy[2]=py-3; hx[3]=px+pw-3; hy[3]=py+ph/2-3;
      hx[4]=px+pw-3; hy[4]=py+ph-3; hx[5]=px+pw/2-3; hy[5]=py+ph-3;
      hx[6]=px-3; hy[6]=py+ph-3; hx[7]=px-3; hy[7]=py+ph/2-3;
      for( int j = 0; j < 8; j++ )
         if( mx >= hx[j] && mx <= hx[j]+7 && my >= hy[j] && my <= hy[j]+7 )
            return j;
   }
   return -1;
}

static HBControl * HBForm_HitTestControl( HBForm * form, int mx, int my )
{
   int border = 8;
   HBControl * groupHit = NULL;
   for( int i = form->base.FChildCount - 1; i >= 0; i-- )
   {
      HBControl * p = form->base.FChildren[i];
      /* Skip children hidden on an inactive TFolder page */
      if( p->FPageOwner && p->FWidget && !gtk_widget_get_visible( p->FWidget ) )
         continue;
      int l = p->FLeft, t = p->FTop, r = l + p->FWidth, b = t + p->FHeight;
      if( mx >= l && mx <= r && my >= t && my <= b )
      {
         if( p->FControlType == CT_GROUPBOX )
         {
            if( my <= t+18 || mx <= l+border || mx >= r-border || my >= b-border )
               if( !groupHit ) groupHit = p;
         }
         else
            return p;
      }
   }
   return groupHit;
}

static void HBForm_NotifySelChange( HBForm * form )
{
   if( form->FOnSelChange && HB_IS_BLOCK( form->FOnSelChange ) )
   {
      PHB_ITEM pArg = hb_itemPutNInt( hb_itemNew(NULL),
         form->FSelCount > 0 ? (HB_PTRUINT) form->FSelected[0] : 0 );
      hb_itemDo( form->FOnSelChange, 1, pArg );
      hb_itemRelease( pArg );
   }
}

static void HBForm_ClearSelection( HBForm * form )
{
   form->FSelCount = 0;
   memset( form->FSelected, 0, sizeof(form->FSelected) );
   if( form->FOverlay ) gtk_widget_queue_draw( form->FOverlay );
   HBForm_NotifySelChange( form );
}

static int HBForm_IsSelected( HBForm * form, HBControl * ctrl )
{
   for( int i = 0; i < form->FSelCount; i++ )
      if( form->FSelected[i] == ctrl ) return 1;
   return 0;
}

static void HBForm_SelectControl( HBForm * form, HBControl * ctrl, int add )
{
   if( !add ) { form->FSelCount = 0; memset( form->FSelected, 0, sizeof(form->FSelected) ); }
   if( ctrl && form->FSelCount < MAX_CHILDREN && !HBForm_IsSelected( form, ctrl ) )
      form->FSelected[form->FSelCount++] = ctrl;
   if( form->FOverlay ) gtk_widget_queue_draw( form->FOverlay );
   HBForm_NotifySelChange( form );
}

/* Overlay mouse events for design mode */
static gboolean on_overlay_button_press( GtkWidget * widget, GdkEventButton * event, gpointer data )
{
   HBForm * form = (HBForm *)data;
   if( !form->FDesignMode || event->button != 1 ) return FALSE;

   int mx = (int)event->x, my = (int)event->y;
   int isShift = (event->state & GDK_SHIFT_MASK) != 0;

   /* Component drop mode: start rubber band to define new control area */
   if( form->FPendingControlType >= 0 )
   {
      HBForm_ClearSelection( form );
      form->FRubberBand = 1;
      form->FRubberX1 = mx; form->FRubberY1 = my;
      form->FRubberX2 = mx; form->FRubberY2 = my;
      return TRUE;
   }

   int nHandle = HBForm_HitTestHandle( form, mx, my );
   if( nHandle >= 0 )
   {
      form->FResizing = 1; form->FResizeHandle = nHandle;
      form->FDragStartX = mx; form->FDragStartY = my;
      return TRUE;
   }

   HBControl * hit = HBForm_HitTestControl( form, mx, my );
   if( hit )
   {
      if( isShift )
      {
         if( HBForm_IsSelected( form, hit ) )
         {
            for( int k = 0; k < form->FSelCount; k++ )
               if( form->FSelected[k] == hit ) {
                  form->FSelected[k] = form->FSelected[--form->FSelCount]; break;
               }
            gtk_widget_queue_draw( form->FOverlay );
         }
         else
            HBForm_SelectControl( form, hit, 1 );
      }
      else
      {
         if( !HBForm_IsSelected( form, hit ) )
            HBForm_SelectControl( form, hit, 0 );
         form->FDragging = 1;
         form->FDragStartX = mx; form->FDragStartY = my;
      }
   }
   else
   {
      /* Empty area: start rubber-band for multi-select */
      HBForm_ClearSelection( form );
      form->FRubberBand = 1;
      form->FRubberX1 = mx; form->FRubberY1 = my;
      form->FRubberX2 = mx; form->FRubberY2 = my;
   }

   return TRUE;
}

static gboolean on_overlay_motion( GtkWidget * widget, GdkEventMotion * event, gpointer data )
{
   HBForm * form = (HBForm *)data;
   if( !form->FDesignMode ) return FALSE;

   int mx = (int)event->x, my = (int)event->y;

   if( form->FRubberBand )
   {
      form->FRubberX2 = mx; form->FRubberY2 = my;
      gtk_widget_queue_draw( form->FOverlay );
      return TRUE;
   }

   if( form->FResizing && form->FSelCount > 0 )
   {
      /* Non-visual controls cannot be resized */
      if( IsNonVisualControl( form->FSelected[0]->FControlType ) )
      {
         form->FResizing = 0;
         return TRUE;
      }
      int dx = mx - form->FDragStartX, dy = my - form->FDragStartY;
      HBControl * p = form->FSelected[0];
      int nl = p->FLeft, nt = p->FTop, nw = p->FWidth, nh = p->FHeight;
      dx = (dx/4)*4; dy = (dy/4)*4;
      if( dx == 0 && dy == 0 ) return TRUE;
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
      HBControl_UpdatePosition( p );
      form->FDragStartX += dx; form->FDragStartY += dy;
      gtk_widget_queue_draw( form->FOverlay );
      HBForm_NotifySelChange( form );
      return TRUE;
   }

   if( form->FDragging && form->FSelCount > 0 )
   {
      int dx = mx - form->FDragStartX, dy = my - form->FDragStartY;
      dx = (dx/4)*4; dy = (dy/4)*4;
      if( dx == 0 && dy == 0 ) return TRUE;
      for( int i = 0; i < form->FSelCount; i++ )
      {
         form->FSelected[i]->FLeft += dx;
         form->FSelected[i]->FTop += dy;
         HBControl_UpdatePosition( form->FSelected[i] );
      }
      form->FDragStartX += dx; form->FDragStartY += dy;
      gtk_widget_queue_draw( form->FOverlay );
      HBForm_NotifySelChange( form );
   }

   return TRUE;
}

/* Generic widget creation for new control types */
static void HBGeneric_CreateWidget( HBControl * p, GtkWidget * container, GtkWidget * w )
{
   gtk_fixed_put( GTK_FIXED(container), w, p->FLeft, p->FTop );
   gtk_widget_set_size_request( w, p->FWidth, p->FHeight );
   p->FWidget = w;
   HBControl_ApplyFont( p );
   gtk_widget_show( w );
}

static void HBMemo_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkWidget * tv = gtk_text_view_new();
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_text_view_set_wrap_mode( GTK_TEXT_VIEW(tv), GTK_WRAP_WORD );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBPanel_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * frame = gtk_frame_new( NULL );
   GtkWidget * label = gtk_label_new( p->FText );
   gtk_container_add( GTK_CONTAINER(frame), label );
   gtk_frame_set_shadow_type( GTK_FRAME(frame), GTK_SHADOW_ETCHED_IN );
   HBGeneric_CreateWidget( p, container, frame );
}

static void HBListBox_CreateWidget( HBControl * p, GtkWidget * container )
{
   HBComboBox * cb = (HBComboBox *)p;
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkListStore * store = gtk_list_store_new( 1, G_TYPE_STRING );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Items", r, "text", 0, NULL );
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(tv), FALSE );
   for( int i = 0; i < cb->FItemCount; i++ )
   {
      GtkTreeIter iter;
      gtk_list_store_append( store, &iter );
      gtk_list_store_set( store, &iter, 0, cb->FItems[i], -1 );
   }
   if( cb->FItemCount > 0 )
   {
      int selRow = (cb->FItemIndex > 0) ? cb->FItemIndex - 1 : 0;
      if( selRow >= cb->FItemCount ) selRow = 0;
      GtkTreeSelection * sel = gtk_tree_view_get_selection( GTK_TREE_VIEW(tv) );
      GtkTreePath * path = gtk_tree_path_new_from_indices( selRow, -1 );
      gtk_tree_selection_select_path( sel, path );
      gtk_tree_path_free( path );
      cb->FItemIndex = selRow + 1;
   }
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_widget_show( tv );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   g_object_unref( store );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBRadioButton_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * rb = gtk_radio_button_new_with_label( NULL, p->FText );
   HBGeneric_CreateWidget( p, container, rb );
}

static void HBScrollBar_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkAdjustment * adj = gtk_adjustment_new( 0, 0, 100, 1, 10, 10 );
   GtkWidget * sb = gtk_scrollbar_new( GTK_ORIENTATION_HORIZONTAL, adj );
   HBGeneric_CreateWidget( p, container, sb );
}

static void HBSpeedButton_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * btn = gtk_button_new_with_label( p->FText );
   gtk_button_set_relief( GTK_BUTTON(btn), GTK_RELIEF_NONE );
   HBGeneric_CreateWidget( p, container, btn );
}

static void HBImage_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * img = gtk_image_new();
   GtkWidget * ev = gtk_event_box_new();
   gtk_container_add( GTK_CONTAINER(ev), img );
   HBGeneric_CreateWidget( p, container, ev );
}

static void HBShape_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * da = gtk_drawing_area_new();
   HBGeneric_CreateWidget( p, container, da );
}

static void HBBevel_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * frame = gtk_frame_new( NULL );
   gtk_frame_set_shadow_type( GTK_FRAME(frame), GTK_SHADOW_ETCHED_IN );
   HBGeneric_CreateWidget( p, container, frame );
}

static void HBStaticText_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * label = gtk_label_new( p->FText );
   GtkWidget * frame = gtk_frame_new( NULL );
   gtk_frame_set_shadow_type( GTK_FRAME(frame), GTK_SHADOW_IN );
   gtk_container_add( GTK_CONTAINER(frame), label );
   HBGeneric_CreateWidget( p, container, frame );
}

static void HBStringGrid_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkListStore * store = gtk_list_store_new( 3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Col1", r, "text", 0, NULL );
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Col2", r, "text", 1, NULL );
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Col3", r, "text", 2, NULL );
   gtk_tree_view_set_grid_lines( GTK_TREE_VIEW(tv), GTK_TREE_VIEW_GRID_LINES_BOTH );
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   g_object_unref( store );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBScrollBox_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw), GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBTreeView_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkTreeStore * store = gtk_tree_store_new( 1, G_TYPE_STRING );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Items", r, "text", 0, NULL );
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(tv), FALSE );
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   g_object_unref( store );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBListView_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkListStore * store = gtk_list_store_new( 2, G_TYPE_STRING, G_TYPE_STRING );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Name", r, "text", 0, NULL );
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Value", r, "text", 1, NULL );
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   g_object_unref( store );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBProgressBar_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * pb = gtk_progress_bar_new();
   gtk_progress_bar_set_fraction( GTK_PROGRESS_BAR(pb), 0.0 );
   gtk_progress_bar_set_show_text( GTK_PROGRESS_BAR(pb), TRUE );
   HBGeneric_CreateWidget( p, container, pb );
}

static void HBRichEdit_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkWidget * tv = gtk_text_view_new();
   gtk_text_view_set_wrap_mode( GTK_TEXT_VIEW(tv), GTK_WRAP_WORD );
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );
   HBGeneric_CreateWidget( p, container, sw );
}

static void HBTabControl2_ApplyPageVisibilityAt( HBControl * p, int sel );
static void HBTabControl2_ApplyPageVisibility( HBControl * p );
static gboolean on_tab_switch_idle( gpointer data )
{
   HBControl * p = (HBControl *) data;
   if( !p || !p->FWidget ) return G_SOURCE_REMOVE;
   int sel = gtk_notebook_get_current_page( GTK_NOTEBOOK( p->FWidget ) );
   HBControl * parent = p->FCtrlParent;
   if( parent && parent->FControlType == CT_FORM )
   {
      for( int i = 0; i < parent->FChildCount; i++ )
      {
         HBControl * c = parent->FChildren[i];
         if( c && c->FPageOwner == p && c->FWidget &&
             c->FPageIndex == sel && gtk_widget_get_visible( c->FWidget ) )
         {
            GdkWindow * cw_ = gtk_widget_get_window( c->FWidget );
            if( cw_ ) gdk_window_raise( cw_ );
         }
      }
   }
   return G_SOURCE_REMOVE;
}

static void on_tab_switch_page( GtkNotebook * nb, GtkWidget * page, guint nPageIdx,
                                gpointer data )
{
   (void) nb; (void) page;
   HBTabControl2_ApplyPageVisibilityAt( (HBControl *) data, (int) nPageIdx );
   /* After GTK finishes the switch, raise visible paged children so they
      sit above the notebook and keep receiving click events. */
   g_idle_add( on_tab_switch_idle, data );
}

static void HBTabControl2_SetTabs( HBControl * p, const char * szTabs )
{
   HBTabControl2 * pc = (HBTabControl2 *) p;
   if( !szTabs ) szTabs = "";
   strncpy( pc->FTabs, szTabs, sizeof(pc->FTabs) - 1 );
   pc->FTabs[sizeof(pc->FTabs) - 1] = 0;
   pc->FPageCount = 0;
   if( !p->FWidget ) return;

   GtkNotebook * nb = GTK_NOTEBOOK( p->FWidget );
   while( gtk_notebook_get_n_pages( nb ) > 0 )
      gtk_notebook_remove_page( nb, 0 );

   const char * start = szTabs, * q;
   char buf[256];
   for( q = szTabs; ; q++ )
   {
      if( *q == '|' || *q == 0 )
      {
         int len = (int)( q - start );
         if( len > (int)sizeof(buf) - 1 ) len = sizeof(buf) - 1;
         memcpy( buf, start, len ); buf[len] = 0;
         /* Per-page body = GtkFixed, so children dropped onto that page
            can be re-parented into it and the notebook handles visibility
            + event routing natively. */
         GtkWidget * page = gtk_fixed_new();
         gtk_widget_show( page );
         gtk_notebook_append_page( nb, page, gtk_label_new( buf ) );
         pc->FPageCount++;
         if( *q == 0 ) break;
         start = q + 1;
      }
   }
}

/* Return the GtkFixed widget for page nPage of a TFolder, or NULL. */
static GtkWidget * HBTabControl2_GetPageFixed( HBControl * p, int nPage )
{
   if( !p || !p->FWidget || p->FControlType != CT_TABCONTROL2 ) return NULL;
   GtkNotebook * nb = GTK_NOTEBOOK( p->FWidget );
   if( nPage < 0 || nPage >= gtk_notebook_get_n_pages( nb ) ) return NULL;
   GtkWidget * page = gtk_notebook_get_nth_page( nb, nPage );
   return ( page && GTK_IS_FIXED( page ) ) ? page : NULL;
}

/* Children live inside notebook page GtkFixed containers, so GTK handles
   show/hide on tab switch automatically. These are kept as no-ops for
   binary compat + to satisfy forward declarations. */
static void HBTabControl2_ApplyPageVisibilityAt( HBControl * p, int sel )
{
   (void) p; (void) sel;
}
static void HBTabControl2_ApplyPageVisibility( HBControl * p )
{
   (void) p;
}

static void HBTabControl_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * nb = gtk_notebook_new();
   HBGeneric_CreateWidget( p, container, nb );
   /* Replay FTabs if already set (via palette-drop default or aTabs load) */
   HBTabControl2 * pc = (HBTabControl2 *) p;
   if( pc->FTabs[0] )
   {
      char saved[1024];
      strncpy( saved, pc->FTabs, sizeof(saved) - 1 );
      saved[sizeof(saved) - 1] = 0;
      HBTabControl2_SetTabs( p, saved );
   }
   g_signal_connect( nb, "switch-page", G_CALLBACK( on_tab_switch_page ), p );
}

static void HBTrackBar_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * scale = gtk_scale_new_with_range( GTK_ORIENTATION_HORIZONTAL, 0, 10, 1 );
   HBGeneric_CreateWidget( p, container, scale );
}

static void HBUpDown_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * spin = gtk_spin_button_new_with_range( 0, 100, 1 );
   HBGeneric_CreateWidget( p, container, spin );
}

static void HBDateTimePicker_CreateWidget( HBControl * p, GtkWidget * container )
{
   /* GTK3 has no native DateTimePicker, use an entry as placeholder */
   GtkWidget * entry = gtk_entry_new();
   gtk_entry_set_text( GTK_ENTRY(entry), "2026-01-01" );
   gtk_entry_set_icon_from_icon_name( GTK_ENTRY(entry), GTK_ENTRY_ICON_SECONDARY, "x-office-calendar" );
   HBGeneric_CreateWidget( p, container, entry );
}

static void HBMonthCalendar_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * cal = gtk_calendar_new();
   HBGeneric_CreateWidget( p, container, cal );
}

static void HBPaintBox_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * da = gtk_drawing_area_new();
   HBGeneric_CreateWidget( p, container, da );
}

/* ======================================================================
 * Data Controls - DB-aware visual widgets
 * ====================================================================== */

/* Footer draw callback: renders each column's footer text aligned with
 * the TreeView column widths, similar to Windows BrowseFooterProc. */
static gboolean on_browse_footer_draw( GtkWidget * widget, cairo_t * cr, gpointer data )
{
   HBBrowse * br = (HBBrowse *)data;
   if( !br->FTreeView ) return FALSE;

   int w = gtk_widget_get_allocated_width( widget );
   int h = gtk_widget_get_allocated_height( widget );
   int isDark = GTK_IsDark();

   /* Background */
   if( isDark )
      cairo_set_source_rgb( cr, 0.20, 0.20, 0.22 );
   else
      cairo_set_source_rgb( cr, 0.94, 0.94, 0.94 );
   cairo_rectangle( cr, 0, 0, w, h );
   cairo_fill( cr );

   /* Top border line */
   if( isDark )
      cairo_set_source_rgb( cr, 0.35, 0.35, 0.35 );
   else
      cairo_set_source_rgb( cr, 0.78, 0.78, 0.78 );
   cairo_move_to( cr, 0, 0.5 );
   cairo_line_to( cr, w, 0.5 );
   cairo_set_line_width( cr, 1.0 );
   cairo_stroke( cr );

   /* Draw each column's footer text */
   cairo_select_font_face( cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL );
   cairo_set_font_size( cr, 11 );
   if( isDark )
      cairo_set_source_rgb( cr, 0.80, 0.80, 0.80 );
   else
      cairo_set_source_rgb( cr, 0.23, 0.23, 0.23 );

   int x = 0;
   for( int i = 0; i < br->FColumnCount; i++ )
   {
      GtkTreeViewColumn * col = gtk_tree_view_get_column( GTK_TREE_VIEW(br->FTreeView), i );
      int cw = col ? gtk_tree_view_column_get_width( col ) : 100;

      if( br->FCols[i].szFooterText[0] )
      {
         cairo_move_to( cr, x + 4, h - 5 );
         cairo_show_text( cr, br->FCols[i].szFooterText );
      }

      /* Column separator */
      if( isDark )
         cairo_set_source_rgb( cr, 0.35, 0.35, 0.35 );
      else
         cairo_set_source_rgb( cr, 0.82, 0.82, 0.82 );
      cairo_move_to( cr, x + cw - 0.5, 2 );
      cairo_line_to( cr, x + cw - 0.5, h );
      cairo_stroke( cr );

      /* Restore text color for next column */
      if( isDark )
         cairo_set_source_rgb( cr, 0.80, 0.80, 0.80 );
      else
         cairo_set_source_rgb( cr, 0.23, 0.23, 0.23 );

      x += cw;
   }

   return TRUE;
}

/* TBrowse / TDBGrid - scrollable data table with dynamic columns.
 * FStore is created eagerly in UI_BrowseNew so data can be populated before
 * the widget exists. This function creates the GtkTreeView and attaches
 * the already-populated store. */
static void HBBrowse_CreateWidget( HBControl * p, GtkWidget * container )
{
   HBBrowse * br = (HBBrowse *)p;

   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(sw), GTK_SHADOW_IN );

   /* Create store lazily if not already created (designer path) */
   if( !br->FStore )
   {
      GType types[MAX_BROWSE_COLS];
      for( int i = 0; i < MAX_BROWSE_COLS; i++ )
         types[i] = G_TYPE_STRING;
      br->FStore = gtk_list_store_newv( MAX_BROWSE_COLS, types );
   }

   br->FTreeView = gtk_tree_view_new_with_model( GTK_TREE_MODEL(br->FStore) );

   /* Add columns from struct */
   int nCols = br->FColumnCount > 0 ? br->FColumnCount : 0;
   for( int i = 0; i < nCols; i++ )
   {
      GtkCellRenderer * r = gtk_cell_renderer_text_new();
      float xalign = 0.0;
      if( br->FCols[i].nAlign == 1 ) xalign = 0.5;
      else if( br->FCols[i].nAlign == 2 ) xalign = 1.0;
      g_object_set( r, "xalign", xalign, NULL );

      GtkTreeViewColumn * col = gtk_tree_view_column_new_with_attributes(
         br->FCols[i].szTitle, r, "text", i, NULL );
      gtk_tree_view_column_set_resizable( col, TRUE );
      if( br->FCols[i].nWidth > 0 )
         gtk_tree_view_column_set_fixed_width( col, br->FCols[i].nWidth );
      gtk_tree_view_column_set_sizing( col, GTK_TREE_VIEW_COLUMN_FIXED );
      gtk_tree_view_append_column( GTK_TREE_VIEW(br->FTreeView), col );
   }

   /* Grid lines */
   if( br->FGridLines )
      gtk_tree_view_set_grid_lines( GTK_TREE_VIEW(br->FTreeView),
         GTK_TREE_VIEW_GRID_LINES_BOTH );

   /* Headers visible */
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(br->FTreeView), TRUE );

   gtk_container_add( GTK_CONTAINER(sw), br->FTreeView );
   gtk_widget_show( br->FTreeView );

   /* Apply background color if set (default = 0xFFFFFFFF) */
   if( br->base.FClrPane != 0xFFFFFFFF )
   {
      int r = br->base.FClrPane & 0xFF, g = (br->base.FClrPane >> 8) & 0xFF,
          b = (br->base.FClrPane >> 16) & 0xFF;
      char css[256];
      snprintf( css, sizeof(css),
         "treeview { background-color: #%02X%02X%02X; }"
         "treeview:selected { background-color: @theme_selected_bg_color; }",
         r, g, b );
      GtkCssProvider * provider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( br->FTreeView );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
      g_object_unref( provider );
   }

   /* Footer bar: per-column footer drawn below the TreeView.
    * Always create the VBox wrapper so footer can be added later. */
   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_box_pack_start( GTK_BOX(vbox), sw, TRUE, TRUE, 0 );

   br->FFooterBar = gtk_drawing_area_new();
   gtk_widget_set_size_request( br->FFooterBar, -1, 22 );
   g_signal_connect( br->FFooterBar, "draw", G_CALLBACK(on_browse_footer_draw), br );
   gtk_box_pack_start( GTK_BOX(vbox), br->FFooterBar, FALSE, FALSE, 0 );

   /* Only show footer if any column has footer text */
   {
      int hasFooter = 0;
      for( int i = 0; i < nCols; i++ )
         if( br->FCols[i].szFooterText[0] ) { hasFooter = 1; break; }
      if( hasFooter )
         gtk_widget_show( br->FFooterBar );
      else
         gtk_widget_hide( br->FFooterBar );
   }

   gtk_widget_show( sw );
   gtk_widget_show( vbox );
   HBGeneric_CreateWidget( p, container, vbox );
}

/* TDBNavigator - record navigation buttons */
static void HBDBNavigator_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * box = gtk_button_box_new( GTK_ORIENTATION_HORIZONTAL );
   gtk_button_box_set_layout( GTK_BUTTON_BOX(box), GTK_BUTTONBOX_START );
   gtk_box_set_spacing( GTK_BOX(box), 1 );

   const char * labels[] = { "|<", "<", ">", ">|", "+", "-", "v" };
   const char * tips[] = { "First", "Previous", "Next", "Last", "Add", "Delete", "Save" };
   int i;
   for( i = 0; i < 7; i++ ) {
      GtkWidget * btn = gtk_button_new_with_label( labels[i] );
      gtk_widget_set_tooltip_text( btn, tips[i] );
      gtk_widget_set_size_request( btn, 30, 26 );
      gtk_container_add( GTK_CONTAINER(box), btn );
   }

   HBGeneric_CreateWidget( p, container, box );
}

/* TDBText - label bound to a database field */
static void HBDBText_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * lbl = gtk_label_new( "(DBText)" );
   gtk_label_set_xalign( GTK_LABEL(lbl), 0.0 );
   HBGeneric_CreateWidget( p, container, lbl );
}

/* TDBEdit - entry bound to a database field */
static void HBDBEdit_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * entry = gtk_entry_new();
   gtk_entry_set_placeholder_text( GTK_ENTRY(entry), "(DBEdit)" );
   HBGeneric_CreateWidget( p, container, entry );
}

/* TDBComboBox - combo bound to a database field */
static void HBDBComboBox_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * combo = gtk_combo_box_text_new();
   gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(combo), "(DBComboBox)" );
   gtk_combo_box_set_active( GTK_COMBO_BOX(combo), 0 );
   HBGeneric_CreateWidget( p, container, combo );
}

/* TDBCheckBox - check button bound to a logical field */
static void HBDBCheckBox_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * chk = gtk_check_button_new_with_label( "(DBCheckBox)" );
   HBGeneric_CreateWidget( p, container, chk );
}

/* TDBImage - image display bound to a blob/path field */
static void HBDBImage_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * frame = gtk_frame_new( "DBImage" );
   GtkWidget * img = gtk_image_new_from_icon_name( "image-x-generic", GTK_ICON_SIZE_DIALOG );
   gtk_container_add( GTK_CONTAINER(frame), img );
   HBGeneric_CreateWidget( p, container, frame );
}

/* Non-visual component: 28x28 palette icon on form */
static gboolean on_nonvisual_draw( GtkWidget * w, cairo_t * cr, gpointer data )
{
   HBControl * p = (HBControl *)data;
   int sz = 28;
   int ct = p->FControlType;

   /* Try to draw the cached palette icon */
   if( ct > 0 && ct < MAX_ICON_CACHE && s_paletteIcons[ct] )
   {
      GdkPixbuf * scaled = gdk_pixbuf_scale_simple( s_paletteIcons[ct], sz, sz, GDK_INTERP_BILINEAR );
      gdk_cairo_set_source_pixbuf( cr, scaled, 0, 0 );
      cairo_paint( cr );
      g_object_unref( scaled );
   }
   else
   {
      /* Fallback: white box with class abbreviation */
      cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
      cairo_rectangle( cr, 0, 0, sz, sz );
      cairo_fill( cr );

      const char * name = p->FClassName;
      if( name[0] == 'T' ) name++;
      char abbr[5];
      strncpy( abbr, name, 4 ); abbr[4] = 0;

      cairo_select_font_face( cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD );
      cairo_set_font_size( cr, 9 );
      cairo_text_extents_t ext;
      cairo_text_extents( cr, abbr, &ext );
      cairo_set_source_rgb( cr, 0.15, 0.15, 0.45 );
      cairo_move_to( cr, (sz - ext.width) / 2 - ext.x_bearing,
                         (sz - ext.height) / 2 - ext.y_bearing );
      cairo_show_text( cr, abbr );
   }

   return TRUE;
}

static void HBNonVisual_CreateWidget( HBControl * p, GtkWidget * container )
{
   p->FWidth = 28;
   p->FHeight = 28;

   GtkWidget * da = gtk_drawing_area_new();
   gtk_widget_set_size_request( da, 28, 28 );
   g_signal_connect( da, "draw", G_CALLBACK(on_nonvisual_draw), p );
   gtk_fixed_put( GTK_FIXED(container), da, p->FLeft, p->FTop );
   p->FWidget = da;
   gtk_widget_show( da );
}

/* Forward declarations for extended controls defined at end of file */
static void HBWebView_CreateWidget( HBControl * p, GtkWidget * container );
static gboolean on_scene3d_draw( GtkWidget * w, cairo_t * cr, gpointer data );
static gboolean on_earthview_draw( GtkWidget * w, cairo_t * cr, gpointer data );
static gboolean on_map_draw( GtkWidget * w, cairo_t * cr, gpointer data );

static void HBControl_CreateWidget( HBControl * child, GtkWidget * fixed, const char * fontDesc )
{
   strcpy( child->FFontDesc, fontDesc );
   switch( child->FControlType )
   {
      /* Standard */
      case CT_LABEL:    HBLabel_CreateWidget( (HBLabel *)child, fixed ); break;
      case CT_EDIT:     HBEdit_CreateWidget( (HBEdit *)child, fixed ); break;
      case CT_BUTTON:   HBButton_CreateWidget( (HBButton *)child, fixed ); break;
      case CT_CHECKBOX: HBCheckBox_CreateWidget( (HBCheckBox *)child, fixed ); break;
      case CT_COMBOBOX: HBComboBox_CreateWidget( (HBComboBox *)child, fixed ); break;
      case CT_GROUPBOX: HBGroupBox_CreateWidget( (HBGroupBox *)child, fixed ); break;
      case CT_MEMO:     HBMemo_CreateWidget( child, fixed ); break;
      case CT_PANEL:    HBPanel_CreateWidget( child, fixed ); break;
      case CT_LISTBOX:  HBListBox_CreateWidget( child, fixed ); break;
      case CT_RADIO:    HBRadioButton_CreateWidget( child, fixed ); break;
      case CT_SCROLLBAR: HBScrollBar_CreateWidget( child, fixed ); break;
      /* Additional */
      case CT_BITBTN:   HBButton_CreateWidget( (HBButton *)child, fixed ); break;
      case CT_SPEEDBTN: HBSpeedButton_CreateWidget( child, fixed ); break;
      case CT_IMAGE:    HBImage_CreateWidget( child, fixed ); break;
      case CT_SHAPE:    HBShape_CreateWidget( child, fixed ); break;
      case CT_BEVEL:    HBBevel_CreateWidget( child, fixed ); break;
      case CT_MASKEDIT2: HBEdit_CreateWidget( (HBEdit *)child, fixed ); break;
      case CT_STRINGGRID: HBStringGrid_CreateWidget( child, fixed ); break;
      case CT_SCROLLBOX: HBScrollBox_CreateWidget( child, fixed ); break;
      case CT_STATICTEXT: HBStaticText_CreateWidget( child, fixed ); break;
      case CT_LABELEDEDIT: HBEdit_CreateWidget( (HBEdit *)child, fixed ); break;
      /* Win32/GTK3 native */
      case CT_TREEVIEW: HBTreeView_CreateWidget( child, fixed ); break;
      case CT_LISTVIEW: HBListView_CreateWidget( child, fixed ); break;
      case CT_PROGRESSBAR: HBProgressBar_CreateWidget( child, fixed ); break;
      case CT_RICHEDIT: HBRichEdit_CreateWidget( child, fixed ); break;
      case CT_TABCONTROL2: HBTabControl_CreateWidget( child, fixed ); break;
      case CT_TRACKBAR: HBTrackBar_CreateWidget( child, fixed ); break;
      case CT_UPDOWN:   HBUpDown_CreateWidget( child, fixed ); break;
      case CT_DATETIMEPICKER: HBDateTimePicker_CreateWidget( child, fixed ); break;
      case CT_MONTHCALENDAR: HBMonthCalendar_CreateWidget( child, fixed ); break;
      /* System */
      case CT_PAINTBOX: HBPaintBox_CreateWidget( child, fixed ); break;
      /* Data Controls */
      case CT_BROWSE:      HBBrowse_CreateWidget( child, fixed ); break;
      case CT_DBGRID:      HBBrowse_CreateWidget( child, fixed ); break;
      case CT_DBNAVIGATOR: HBDBNavigator_CreateWidget( child, fixed ); break;
      case CT_DBTEXT:      HBDBText_CreateWidget( child, fixed ); break;
      case CT_DBEDIT:      HBDBEdit_CreateWidget( child, fixed ); break;
      case CT_DBCOMBOBOX:  HBDBComboBox_CreateWidget( child, fixed ); break;
      case CT_DBCHECKBOX:  HBDBCheckBox_CreateWidget( child, fixed ); break;
      case CT_DBIMAGE:     HBDBImage_CreateWidget( child, fixed ); break;
      case CT_WEBVIEW:      HBWebView_CreateWidget( child, fixed ); break;
      case CT_SCENE3D: {
         GtkWidget * da = gtk_drawing_area_new();
         g_signal_connect( da, "draw", G_CALLBACK(on_scene3d_draw), child );
         HBGeneric_CreateWidget( child, fixed, da );
         break;
      }
      case CT_EARTHVIEW: {
         GtkWidget * da = gtk_drawing_area_new();
         g_signal_connect( da, "draw", G_CALLBACK(on_earthview_draw), child );
         HBGeneric_CreateWidget( child, fixed, da );
         break;
      }
      case CT_MAP: {
         GtkWidget * da = gtk_drawing_area_new();
         g_signal_connect( da, "draw", G_CALLBACK(on_map_draw), child );
         HBGeneric_CreateWidget( child, fixed, da );
         break;
      }
      default:
         if( IsNonVisualControl( child->FControlType ) )
            HBNonVisual_CreateWidget( child, fixed );
         break;
   }
}

static HBControl * HBForm_CreateControlOfType( HBForm * form, int ctrlType,
   int nL, int nT, int nW, int nH )
{
   HBControl * newCtrl = NULL;
   switch( ctrlType ) {
      case CT_LABEL: {
         HBLabel * p = (HBLabel*)calloc(1,sizeof(HBLabel));
         HBControl_Init(&p->base); strcpy(p->base.FClassName,"TLabel");
         p->base.FControlType=CT_LABEL; strcpy(p->base.FText,"Label");
         p->base.FLeft=nL; p->base.FTop=nT; p->base.FWidth=nW; p->base.FHeight=nH;
         newCtrl=&p->base; break;
      }
      case CT_EDIT: {
         HBEdit * p = (HBEdit*)calloc(1,sizeof(HBEdit));
         HBControl_Init(&p->base); strcpy(p->base.FClassName,"TEdit");
         p->base.FControlType=CT_EDIT;
         p->base.FLeft=nL; p->base.FTop=nT; p->base.FWidth=nW; p->base.FHeight=nH;
         newCtrl=&p->base; break;
      }
      case CT_BUTTON: {
         HBButton * p = (HBButton*)calloc(1,sizeof(HBButton));
         HBControl_Init(&p->base); strcpy(p->base.FClassName,"TButton");
         p->base.FControlType=CT_BUTTON; strcpy(p->base.FText,"Button");
         p->base.FLeft=nL; p->base.FTop=nT; p->base.FWidth=nW; p->base.FHeight=nH;
         newCtrl=&p->base; break;
      }
      case CT_CHECKBOX: {
         HBCheckBox * p = (HBCheckBox*)calloc(1,sizeof(HBCheckBox));
         HBControl_Init(&p->base); strcpy(p->base.FClassName,"TCheckBox");
         p->base.FControlType=CT_CHECKBOX; strcpy(p->base.FText,"CheckBox");
         p->base.FLeft=nL; p->base.FTop=nT; p->base.FWidth=nW; p->base.FHeight=nH;
         newCtrl=&p->base; break;
      }
      case CT_COMBOBOX: {
         HBComboBox * p = (HBComboBox*)calloc(1,sizeof(HBComboBox));
         HBControl_Init(&p->base); strcpy(p->base.FClassName,"TComboBox");
         p->base.FControlType=CT_COMBOBOX;
         p->base.FLeft=nL; p->base.FTop=nT; p->base.FWidth=nW; p->base.FHeight=nH;
         newCtrl=&p->base; break;
      }
      case CT_GROUPBOX: {
         HBGroupBox * p = (HBGroupBox*)calloc(1,sizeof(HBGroupBox));
         HBControl_Init(&p->base); strcpy(p->base.FClassName,"TGroupBox");
         p->base.FControlType=CT_GROUPBOX; strcpy(p->base.FText,"GroupBox");
         p->base.FLeft=nL; p->base.FTop=nT; p->base.FWidth=nW; p->base.FHeight=nH;
         newCtrl=&p->base; break;
      }
      default: {
         /* Generic: all other control types use base HBControl */
         static const struct { int type; const char * cls; const char * text; int dw; int dh; } defs[] = {
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
            { CT_TABCONTROL2,"TFolder",         "",           300, 200 },
            { CT_TREEVIEW,   "TTreeView",       "",           150, 200 },
            { CT_LISTVIEW,   "TListView",       "",           200, 150 },
            { CT_PROGRESSBAR,"TProgressBar",    "",           150,  20 },
            { CT_RICHEDIT,   "TRichEdit",       "",           200, 100 },
            { CT_TRACKBAR,   "TTrackBar",       "",           150,  25 },
            { CT_UPDOWN,     "TUpDown",         "",            17,  22 },
            { CT_DATETIMEPICKER,"TDateTimePicker","",          186,  24 },
            { CT_MONTHCALENDAR,"TMonthCalendar","",            227, 155 },
            { CT_PAINTBOX,   "TPaintBox",       "",           105, 105 },
            { CT_TIMER,      "TTimer",          "",            32,  32 },
            { CT_MAINMENU,   "TMainMenu",       "",            32,  32 },
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
         int i;
         for( i = 0; defs[i].cls; i++ ) {
            if( defs[i].type == ctrlType ) {
               /* Allocate the correct struct size for types with extra fields */
               size_t sz = sizeof(HBControl);
               switch( ctrlType ) {
                  case CT_BROWSE: case CT_DBGRID: sz = sizeof(HBBrowse); break;
                  case CT_LABEL:    sz = sizeof(HBLabel); break;
                  case CT_EDIT: case CT_MASKEDIT2: case CT_LABELEDEDIT:
                                    sz = sizeof(HBEdit); break;
                  case CT_BUTTON: case CT_BITBTN:
                                    sz = sizeof(HBButton); break;
                  case CT_CHECKBOX: sz = sizeof(HBCheckBox); break;
                  case CT_COMBOBOX: case CT_LISTBOX: sz = sizeof(HBComboBox); break;
                  case CT_GROUPBOX: sz = sizeof(HBGroupBox); break;
                  case CT_LISTVIEW: sz = sizeof(HBListView); break;
                  case CT_RICHEDIT: sz = sizeof(HBRichEdit); break;
                  case CT_RADIO:    sz = sizeof(HBRadioButton); break;
                  case CT_IMAGE:    sz = sizeof(HBImage); break;
                  case CT_SHAPE:    sz = sizeof(HBShape); break;
                  case CT_BEVEL:    sz = sizeof(HBBevel); break;
                  case CT_TIMER:    sz = sizeof(HBTimer); break;
                  case CT_MAINMENU: sz = sizeof(HBMainMenu); break;
                  case CT_TABCONTROL2: sz = sizeof(HBTabControl2); break;
                  /* CT_SPEEDBTN uses base HBControl */
               }
               HBControl * p = (HBControl*)calloc(1, sz);
               HBControl_Init(p);
               strcpy(p->FClassName, defs[i].cls);
               p->FControlType = ctrlType;
               if( defs[i].text[0] ) strcpy(p->FText, defs[i].text);
               p->FLeft=nL; p->FTop=nT;
               p->FWidth = nW > 10 ? nW : defs[i].dw;
               p->FHeight = nH > 10 ? nH : defs[i].dh;
               newCtrl = p;
               break;
            }
         }
         break;
      }
   }
   if( newCtrl )
   {
      KeepAlive( newCtrl );
      strcpy( newCtrl->FFontDesc, form->FFormFontDesc );
      /* Timer: default interval = 1000 ms */
      if( newCtrl->FControlType == CT_TIMER )
         ((HBTimer *)newCtrl)->FInterval = 1000;
      /* HBControl_AddChild auto-creates the GTK widget when the form
         is already shown (FFixed exists). */
      HBControl_AddChild( &form->base, newCtrl );
      if( form->FFixed )
         gtk_widget_show_all( form->FFixed );

      /* Select the new control */
      HBForm_SelectControl( form, newCtrl, 0 );
   }
   return newCtrl;
}

static gboolean on_overlay_button_release( GtkWidget * widget, GdkEventButton * event, gpointer data )
{
   HBForm * form = (HBForm *)data;
   if( !form->FDesignMode ) return FALSE;

   if( form->FRubberBand )
   {
      form->FRubberBand = 0;
      int rx1 = form->FRubberX1 < form->FRubberX2 ? form->FRubberX1 : form->FRubberX2;
      int ry1 = form->FRubberY1 < form->FRubberY2 ? form->FRubberY1 : form->FRubberY2;
      int rx2 = form->FRubberX1 > form->FRubberX2 ? form->FRubberX1 : form->FRubberX2;
      int ry2 = form->FRubberY1 > form->FRubberY2 ? form->FRubberY1 : form->FRubberY2;
      int rw = rx2 - rx1, rh = ry2 - ry1;

      /* Component drop mode: create the control */
      if( form->FPendingControlType >= 0 )
      {
         int ctrlType = form->FPendingControlType;
         form->FPendingControlType = -1;
         /* Reset cursor */
         if( form->FWindow )
            gdk_window_set_cursor( gtk_widget_get_window(form->FWindow), NULL );

         /* Snap to 8-pixel grid */
         rx1 = (rx1 / 8) * 8;
         ry1 = (ry1 / 8) * 8;
         /* Non-visual: fixed 28x28, visual: enforce minimum */
         if( IsNonVisualControl( ctrlType ) ) {
            rw = 28; rh = 28;
         } else {
            if( rw < 20 ) rw = 80;
            if( rh < 10 ) rh = 24;
         }

         /* If drop falls inside a TFolder's client area (and we're not
            dropping the folder itself), tag the new control with that
            folder's active page so AddChild claims ownership. */
         if( ctrlType != CT_TABCONTROL2 )
         {
            for( int j = 0; j < form->base.FChildCount; j++ )
            {
               HBControl * pF = form->base.FChildren[j];
               if( pF && pF->FControlType == CT_TABCONTROL2 &&
                   rx1 >= pF->FLeft && rx1 < pF->FLeft + pF->FWidth &&
                   ry1 >= pF->FTop  && ry1 < pF->FTop  + pF->FHeight )
               {
                  int nPage = pF->FWidget
                     ? gtk_notebook_get_current_page( GTK_NOTEBOOK( pF->FWidget ) )
                     : 0;
                  g_pendingPageOwner = pF;
                  g_pendingPageIndex = nPage < 0 ? 0 : nPage;
                  break;
               }
            }
         }

         HBControl * newCtrl = HBForm_CreateControlOfType( form, ctrlType, rx1, ry1, rw, rh );

         if( newCtrl && form->FOnComponentDrop && HB_IS_BLOCK( form->FOnComponentDrop ) )
         {
            PHB_ITEM args[6];
            args[0] = hb_itemPutNInt( hb_itemNew(NULL), (HB_PTRUINT) form );
            args[1] = hb_itemPutNI( hb_itemNew(NULL), ctrlType );
            args[2] = hb_itemPutNI( hb_itemNew(NULL), rx1 );
            args[3] = hb_itemPutNI( hb_itemNew(NULL), ry1 );
            args[4] = hb_itemPutNI( hb_itemNew(NULL), rw );
            args[5] = hb_itemPutNI( hb_itemNew(NULL), rh );
            hb_itemDo( form->FOnComponentDrop, 6, args[0], args[1], args[2], args[3], args[4], args[5] );
            for( int a = 0; a < 6; a++ ) hb_itemRelease( args[a] );
         }

         /* Keep focus on overlay so keyboard shortcuts (arrows, Delete) work */
         if( form->FOverlay )
            gtk_widget_grab_focus( form->FOverlay );
      }
      else
      {
         /* Multi-select: pick controls whose bounding box intersects the band */
         form->FSelCount = 0;
         memset( form->FSelected, 0, sizeof(form->FSelected) );
         for( int i = 0; i < form->base.FChildCount && form->FSelCount < MAX_CHILDREN; i++ )
         {
            HBControl * c = form->base.FChildren[i];
            int cl = c->FLeft, ct = c->FTop, cr = cl + c->FWidth, cb = ct + c->FHeight;
            if( cl < rx2 && cr > rx1 && ct < ry2 && cb > ry1 )
               form->FSelected[form->FSelCount++] = c;
         }
         HBForm_NotifySelChange( form );
      }

      gtk_widget_queue_draw( form->FOverlay );
      return TRUE;
   }

   if( form->FDragging || form->FResizing )
   {
      form->FDragging = 0; form->FResizing = 0; form->FResizeHandle = -1;
      gtk_widget_queue_draw( form->FOverlay );
      HBForm_NotifySelChange( form );
   }
   return TRUE;
}

static gboolean on_overlay_key_press( GtkWidget * widget, GdkEventKey * event, gpointer data )
{
   HBForm * form = (HBForm *)data;
   if( !form->FDesignMode ) return FALSE;

   /* Delete key */
   if( (event->keyval == GDK_KEY_Delete || event->keyval == GDK_KEY_BackSpace) && form->FSelCount > 0 )
   {
      for( int i = 0; i < form->FSelCount; i++ )
         if( form->FSelected[i]->FWidget )
         {
            gtk_widget_destroy( form->FSelected[i]->FWidget );
            form->FSelected[i]->FWidget = NULL;
         }
      HBForm_ClearSelection( form );
      return TRUE;
   }

   /* Arrow keys */
   if( form->FSelCount > 0 )
   {
      int dx = 0, dy = 0;
      int step = (event->state & GDK_SHIFT_MASK) ? 1 : 4;
      switch( event->keyval ) {
         case GDK_KEY_Left:  dx = -step; break;
         case GDK_KEY_Right: dx = step;  break;
         case GDK_KEY_Up:    dy = -step; break;
         case GDK_KEY_Down:  dy = step;  break;
         default: return FALSE;
      }
      for( int i = 0; i < form->FSelCount; i++ )
      {
         form->FSelected[i]->FLeft += dx;
         form->FSelected[i]->FTop += dy;
         HBControl_UpdatePosition( form->FSelected[i] );
      }
      gtk_widget_queue_draw( form->FOverlay );
      HBForm_NotifySelChange( form );
      return TRUE;
   }

   return FALSE;
}

/* Forward declarations (defined further down) */
static void HBToolBar_ApplyIcons( HBToolBar * tb );
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

typedef struct {
   HBForm *     parentForm;
   GtkWidget *  notebook;
   GtkWidget *  tabBoxes[MAX_PALETTE_TABS];
   PaletteTab   tabs[MAX_PALETTE_TABS];
   int          nTabCount;
   int          nCurrentTab;
   PHB_ITEM     pOnSelect;
} PALDATA;

static PALDATA * s_palData = NULL;
static GtkWidget * s_statusBar = NULL;
static guint s_statusCtxId = 0;
static GtkAccelGroup * s_accelGroup = NULL;
static HBForm * s_designForm = NULL;

/* ======================================================================
 * HBForm methods
 * ====================================================================== */

static void HBForm_Init( HBForm * form )
{
   HBControl_Init( &form->base );
   strcpy( form->base.FClassName, "TForm" );
   form->base.FControlType = CT_FORM;
   strcpy( form->FFormFontDesc, "Sans 12" );
   strcpy( form->base.FFontDesc, "Sans 12" );
   form->FCenter = 1; form->FModalResult = 0; form->FRunning = 0;
   form->FDesignMode = 0;
   form->FSelCount = 0; form->FDragging = 0; form->FResizing = 0;
   form->FResizeHandle = -1; form->FOnSelChange = NULL;
   form->FOverlay = NULL; form->FFixed = NULL; form->FWindow = NULL;
   memset( form->FToolBars, 0, sizeof(form->FToolBars) );
   form->FToolBarCount = 0; form->FClientTop = 0; form->FSizable = 0; form->FAppBar = 0;
   form->FMenuBar = NULL; form->FMenuItemCount = 0;
   form->FBorderStyle = 2; form->FBorderIcons = 7; form->FBorderWidth = 0;
   form->FPosition = 0; form->FWindowState = 0; form->FFormStyle = 0;
   form->FCursor = 0; form->FKeyPreview = 0;
   form->FAlphaBlend = 0; form->FAlphaBlendValue = 255;
   form->FShowHint = 0; form->FHint[0] = 0;
   form->FAutoScroll = 1; form->FDoubleBuffered = 0;
   form->FPendingControlType = -1; form->FOnComponentDrop = NULL;
   form->FOnActivate = NULL; form->FOnDeactivate = NULL;
   form->FOnResize = NULL; form->FOnPaint = NULL;
   form->FOnShow = NULL; form->FOnHide = NULL;
   form->FOnCloseQuery = NULL; form->FOnCreate = NULL; form->FOnDestroy = NULL;
   form->FOnKeyDown = NULL; form->FOnKeyUp = NULL; form->FOnKeyPress = NULL;
   form->FOnMouseDown = NULL; form->FOnMouseUp = NULL; form->FOnMouseMove = NULL;
   form->FOnDblClick = NULL; form->FOnMouseWheel = NULL;
   memset( form->FSelected, 0, sizeof(form->FSelected) );
   memset( form->FMenuActions, 0, sizeof(form->FMenuActions) );
   form->base.FWidth = 470; form->base.FHeight = 400;
   strcpy( form->base.FText, "New Form" );
   form->base.FClrPane = 0x00F0F0F0;
}

/* Toolbar button callback */
static void on_toolbar_btn_clicked( GtkToolButton * button, gpointer data )
{
   HBToolBar * tb = (HBToolBar *)data;
   int idx = GPOINTER_TO_INT( g_object_get_data( G_OBJECT(button), "btn_idx" ) );
   if( idx >= 0 && idx < tb->FBtnCount && tb->FBtnOnClick[idx] )
      hb_itemDo( tb->FBtnOnClick[idx], 0 );
}

/* Menu item callback */
static void on_menu_item_activated( GtkMenuItem * item, gpointer data )
{
   PHB_ITEM pBlock = (PHB_ITEM)data;
   if( pBlock && HB_IS_BLOCK(pBlock) )
      hb_itemDo( pBlock, 0 );
}

static gboolean on_window_configure( GtkWidget * widget, GdkEventConfigure * event, gpointer data )
{
   HBForm * form = (HBForm *)data;
   int changed = 0;

   if( form->base.FLeft != event->x || form->base.FTop != event->y )
   {
      form->base.FLeft = event->x;
      form->base.FTop = event->y;
      changed = 1;
   }
   if( form->base.FWidth != event->width || form->base.FHeight != event->height )
   {
      form->base.FWidth = event->width;
      form->base.FHeight = event->height;
      changed = 1;
   }

   if( changed && form->FOnResize && HB_IS_BLOCK( form->FOnResize ) )
      hb_itemDo( form->FOnResize, 0 );

   return FALSE;
}

static void on_window_destroy( GtkWidget * widget, gpointer data )
{
   HBForm * form = (HBForm *)data;
   int wasRunning = form->FRunning;
   form->FRunning = 0;
   form->FWindow = NULL;
   /* Only quit the main loop if this form owned one (Run or ShowModal) */
   if( wasRunning )
      gtk_main_quit();
}

/* Forward declaration: TMainMenu runtime attach (defined later near Menu bridge) */
static void HBMainMenu_Attach( HBControl * p, HBForm * form );

static void HBForm_CreateAllChildren( HBForm * form )
{
   /* GroupBoxes first */
   for( int i = 0; i < form->base.FChildCount; i++ )
      if( form->base.FChildren[i]->FControlType == CT_GROUPBOX )
      {
         strcpy( form->base.FChildren[i]->FFontDesc, form->FFormFontDesc );
         HBGroupBox_CreateWidget( (HBGroupBox *)form->base.FChildren[i], form->FFixed );
      }
   /* Folders next so their per-page GtkFixed containers exist before
      paged children try to attach. */
   for( int i = 0; i < form->base.FChildCount; i++ )
   {
      HBControl * child = form->base.FChildren[i];
      if( child->FControlType != CT_TABCONTROL2 ) continue;
      strcpy( child->FFontDesc, form->FFormFontDesc );
      HBControl_CreateWidget( child, form->FFixed, form->FFormFontDesc );
   }
   /* Remaining controls */
   for( int i = 0; i < form->base.FChildCount; i++ )
   {
      HBControl * child = form->base.FChildren[i];
      if( child->FControlType == CT_GROUPBOX ) continue;
      if( child->FControlType == CT_TABCONTROL2 ) continue;
      if( IsNonVisualControl( child->FControlType ) && !form->FDesignMode ) {
         if( child->FControlType == CT_MAINMENU )
            HBMainMenu_Attach( child, form );
         continue;
      }
      strcpy( child->FFontDesc, form->FFormFontDesc );
      GtkWidget * container = form->FFixed;
      int savedLeft = child->FLeft, savedTop = child->FTop;
      if( child->FPageOwner )
      {
         GtkWidget * page = HBTabControl2_GetPageFixed(
            child->FPageOwner, child->FPageIndex );
         if( page )
         {
            container = page;
            /* Child coords are form-absolute; convert to page-relative.
               Tab strip height is ~28px; fine-tuned later if needed. */
            HBControl * folder = child->FPageOwner;
            child->FLeft -= folder->FLeft;
            child->FTop  -= folder->FTop + 28;
            if( child->FLeft < 0 ) child->FLeft = 0;
            if( child->FTop  < 0 ) child->FTop  = 0;
         }
      }
      HBControl_CreateWidget( child, container, form->FFormFontDesc );
      /* Restore form-absolute coords so HitTest and later logic stay sane. */
      child->FLeft = savedLeft;
      child->FTop  = savedTop;
   }
}

/* Forward declaration: runtime form click handler */
static gboolean on_form_click( GtkWidget * widget, GdkEventButton * event, gpointer data );

static void HBForm_Run( HBForm * form )
{
   EnsureGTK();

   form->FWindow = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(form->FWindow), form->base.FText );
   gtk_window_set_default_size( GTK_WINDOW(form->FWindow), form->base.FWidth, form->base.FHeight );
   gtk_window_set_resizable( GTK_WINDOW(form->FWindow),
      (form->FDesignMode || (form->FSizable && !form->FAppBar)) ? TRUE : FALSE );
   g_signal_connect( form->FWindow, "destroy", G_CALLBACK(on_window_destroy), form );
   g_signal_connect( form->FWindow, "configure-event", G_CALLBACK(on_window_configure), form );

   /* Set background color via CSS — only when user explicitly set FClrPane,
      so IDE/default forms keep dark-mode global CSS. */
   if( form->FClrPaneExplicit )
   {
      unsigned int clr = form->base.FClrPane;
      int r = clr & 0xFF, g = (clr >> 8) & 0xFF, b = (clr >> 16) & 0xFF;
      char css[128];
      snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
      GtkCssProvider * provider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( form->FWindow );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_USER );
      g_object_unref( provider );
   }

   /* Attach accelerator group if menu accelerators were defined */
   if( s_accelGroup )
      gtk_window_add_accel_group( GTK_WINDOW(form->FWindow), s_accelGroup );

   /* VBox: menubar + toolbar + overlay(fixed + design) */
   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(form->FWindow), vbox );
   gtk_widget_show( vbox );

   /* Toolbars - build all toolbar rows, stack vertically at left of palette */
   if( form->FToolBarCount > 0 ) {
      /* VBox to stack multiple toolbar rows */
      GtkWidget * tbVBox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );

      /* CSS for compact toolbar buttons */
      { GtkCssProvider * tbCss = gtk_css_provider_new();
        gtk_css_provider_load_from_data( tbCss,
           "toolbar { padding: 0; }"
           "toolbar button { padding: 1px 3px; min-height: 20px; min-width: 20px; }"
           "toolbar image { margin: 0; }", -1, NULL );
        gtk_style_context_add_provider_for_screen( gdk_screen_get_default(),
           GTK_STYLE_PROVIDER(tbCss), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
        g_object_unref( tbCss );
      }

      int t;
      for( t = 0; t < form->FToolBarCount; t++ )
      {
         HBToolBar * tb = (HBToolBar *)form->FToolBars[t];
         GtkWidget * toolbar = gtk_toolbar_new();
         gtk_toolbar_set_style( GTK_TOOLBAR(toolbar), GTK_TOOLBAR_TEXT );
         gtk_toolbar_set_icon_size( GTK_TOOLBAR(toolbar), GTK_ICON_SIZE_MENU );
         tb->FToolBarWidget = toolbar;

         int i;
         for( i = 0; i < tb->FBtnCount; i++ ) {
            if( tb->FBtnSeparator[i] ) {
               GtkToolItem * sep = gtk_separator_tool_item_new();
               gtk_toolbar_insert( GTK_TOOLBAR(toolbar), sep, -1 );
            } else {
               GtkToolItem * btn = gtk_tool_button_new( NULL, tb->FBtnTexts[i] );
               gtk_tool_item_set_tooltip_text( btn, tb->FBtnTooltips[i] );
               g_object_set_data( G_OBJECT(btn), "btn_idx", GINT_TO_POINTER(i) );
               g_object_set_data( G_OBJECT(btn), "toolbar", tb );
               g_signal_connect( btn, "clicked", G_CALLBACK(on_toolbar_btn_clicked), tb );
               gtk_toolbar_insert( GTK_TOOLBAR(toolbar), btn, -1 );
            }
         }

         /* Apply deferred toolbar icons (scaled smaller for compact mode) */
         if( tb->FIconCount > 0 ) {
            gtk_toolbar_set_style( GTK_TOOLBAR(toolbar), GTK_TOOLBAR_ICONS );
            HBToolBar_ApplyIcons( tb );
         }

         gtk_box_pack_start( GTK_BOX(tbVBox), toolbar, FALSE, FALSE, 0 );
      }

      /* If palette exists, pack toolbars VBox + palette in an hbox */
      if( s_palData && s_palData->notebook ) {
         GtkWidget * tbHBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
         /* Ensure toolbar has enough width for all buttons (Run must be visible) */
         gtk_widget_set_size_request( tbVBox, 348, -1 );
         gtk_box_pack_start( GTK_BOX(tbHBox), tbVBox, FALSE, FALSE, 0 );
         GtkWidget * sep = gtk_separator_new( GTK_ORIENTATION_VERTICAL );
         gtk_box_pack_start( GTK_BOX(tbHBox), sep, FALSE, FALSE, 2 );
         gtk_box_pack_start( GTK_BOX(tbHBox), s_palData->notebook, TRUE, TRUE, 0 );
         gtk_box_pack_start( GTK_BOX(vbox), tbHBox, FALSE, FALSE, 0 );
         gtk_widget_show_all( tbHBox );
      } else {
         gtk_box_pack_start( GTK_BOX(vbox), tbVBox, FALSE, FALSE, 0 );
         gtk_widget_show_all( tbVBox );
      }

      form->FClientTop = 0;
   }

   /* Use GtkOverlay to layer the fixed container and the design overlay */
   GtkWidget * overlay = gtk_overlay_new();
   gtk_box_pack_start( GTK_BOX(vbox), overlay, TRUE, TRUE, 0 );
   gtk_widget_show( overlay );

   form->FFixed = gtk_fixed_new();
   gtk_container_add( GTK_CONTAINER(overlay), form->FFixed );
   gtk_widget_show( form->FFixed );

   HBForm_CreateAllChildren( form );

   /* Menu bar: built by HBMainMenu_Attach() during CreateAllChildren, or pre-existing */
   if( form->FMenuBar ) {
      gtk_box_pack_start( GTK_BOX(vbox), form->FMenuBar, FALSE, FALSE, 0 );
      gtk_box_reorder_child( GTK_BOX(vbox), form->FMenuBar, 0 );
      gtk_widget_show_all( form->FMenuBar );
   }

   /* Design mode overlay */
   if( form->FDesignMode )
   {
      GtkWidget * da = gtk_drawing_area_new();
      gtk_widget_set_size_request( da, form->base.FWidth, form->base.FHeight );
      gtk_overlay_add_overlay( GTK_OVERLAY(overlay), da );
      gtk_widget_set_can_focus( da, TRUE );
      gtk_widget_add_events( da, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                                 GDK_POINTER_MOTION_MASK | GDK_KEY_PRESS_MASK );
      g_signal_connect( da, "draw", G_CALLBACK(on_overlay_draw), form );
      g_signal_connect( da, "button-press-event", G_CALLBACK(on_overlay_button_press), form );
      g_signal_connect( da, "motion-notify-event", G_CALLBACK(on_overlay_motion), form );
      g_signal_connect( da, "button-release-event", G_CALLBACK(on_overlay_button_release), form );
      g_signal_connect( da, "key-press-event", G_CALLBACK(on_overlay_key_press), form );
      /* Make overlay transparent to see controls beneath */
      gtk_widget_set_app_paintable( da, TRUE );
      form->FOverlay = da;
      gtk_widget_show( da );
   }
   else
   {
      /* Runtime: wire form-level click event on the window */
      gtk_widget_add_events( form->FWindow, GDK_BUTTON_PRESS_MASK );
      g_signal_connect( form->FWindow, "button-press-event", G_CALLBACK(on_form_click), form );
   }

   gtk_widget_show( overlay );

   /* StatusBar at bottom */
   if( s_statusBar ) {
      gtk_box_pack_end( GTK_BOX(vbox), s_statusBar, FALSE, FALSE, 0 );
      gtk_widget_show( s_statusBar );
   }

   if( form->FCenter )
      gtk_window_set_position( GTK_WINDOW(form->FWindow), GTK_WIN_POS_CENTER );
   else
      gtk_window_move( GTK_WINDOW(form->FWindow), form->base.FLeft, form->base.FTop );

   gtk_widget_show( form->FWindow );

   /* Grab focus for overlay in design mode */
   if( form->FDesignMode && form->FOverlay )
      gtk_widget_grab_focus( form->FOverlay );

   form->FRunning = 1;
   gtk_main();
}

/* Runtime form click: fire base.FOnClick */
static gboolean on_form_click( GtkWidget * widget, GdkEventButton * event, gpointer data )
{
   static guint32 lastClickTime = 0;
   static guint32 lastDblTime = 0;
   HBForm * form = (HBForm *)data;
   if( event->button != 1 ) return FALSE;

   if( event->type == GDK_BUTTON_PRESS && event->time != lastClickTime )
   {
      lastClickTime = event->time;
      HBControl_FireEvent( &form->base, form->base.FOnClick );
   }
   else if( event->type == GDK_2BUTTON_PRESS && event->time != lastDblTime )
   {
      lastDblTime = event->time;
      HBControl_FireEvent( &form->base, form->FOnDblClick );
   }
   return FALSE;
}

/* Show() - create and show without entering gtk_main */
static void HBForm_Show( HBForm * form )
{
   EnsureGTK();

   form->FWindow = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(form->FWindow), form->base.FText );
   gtk_window_set_default_size( GTK_WINDOW(form->FWindow), form->base.FWidth, form->base.FHeight );
   gtk_window_set_resizable( GTK_WINDOW(form->FWindow),
      (form->FDesignMode || (form->FSizable && !form->FAppBar)) ? TRUE : FALSE );
   g_signal_connect( form->FWindow, "destroy", G_CALLBACK(on_window_destroy), form );
   g_signal_connect( form->FWindow, "configure-event", G_CALLBACK(on_window_configure), form );

   /* Background color — only when user explicitly set FClrPane */
   if( form->FClrPaneExplicit )
   {
      unsigned int clr = form->base.FClrPane;
      int r = clr & 0xFF, g = (clr >> 8) & 0xFF, b = (clr >> 16) & 0xFF;
      char css[128];
      snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
      GtkCssProvider * provider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( form->FWindow );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_USER );
      g_object_unref( provider );
   }

   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(form->FWindow), vbox );
   gtk_widget_show( vbox );

   GtkWidget * overlay = gtk_overlay_new();
   gtk_box_pack_start( GTK_BOX(vbox), overlay, TRUE, TRUE, 0 );
   gtk_widget_show( overlay );

   form->FFixed = gtk_fixed_new();
   gtk_container_add( GTK_CONTAINER(overlay), form->FFixed );
   gtk_widget_show( form->FFixed );

   HBForm_CreateAllChildren( form );

   /* Menu bar: built by HBMainMenu_Attach() during CreateAllChildren, or pre-existing */
   if( form->FMenuBar ) {
      gtk_box_pack_start( GTK_BOX(vbox), form->FMenuBar, FALSE, FALSE, 0 );
      gtk_box_reorder_child( GTK_BOX(vbox), form->FMenuBar, 0 );
      gtk_widget_show_all( form->FMenuBar );
   }

   if( form->FDesignMode )
   {
      GtkWidget * da = gtk_drawing_area_new();
      gtk_widget_set_size_request( da, form->base.FWidth, form->base.FHeight );
      gtk_overlay_add_overlay( GTK_OVERLAY(overlay), da );
      gtk_widget_set_can_focus( da, TRUE );
      gtk_widget_add_events( da, GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
                                 GDK_POINTER_MOTION_MASK | GDK_KEY_PRESS_MASK );
      g_signal_connect( da, "draw", G_CALLBACK(on_overlay_draw), form );
      g_signal_connect( da, "button-press-event", G_CALLBACK(on_overlay_button_press), form );
      g_signal_connect( da, "motion-notify-event", G_CALLBACK(on_overlay_motion), form );
      g_signal_connect( da, "button-release-event", G_CALLBACK(on_overlay_button_release), form );
      g_signal_connect( da, "key-press-event", G_CALLBACK(on_overlay_key_press), form );
      gtk_widget_set_app_paintable( da, TRUE );
      form->FOverlay = da;
      gtk_widget_show( da );
   }
   else
   {
      /* Runtime: wire form-level click event on the window */
      gtk_widget_add_events( form->FWindow, GDK_BUTTON_PRESS_MASK );
      g_signal_connect( form->FWindow, "button-press-event", G_CALLBACK(on_form_click), form );
   }

   if( form->FCenter )
      gtk_window_set_position( GTK_WINDOW(form->FWindow), GTK_WIN_POS_CENTER );
   else
      gtk_window_move( GTK_WINDOW(form->FWindow), form->base.FLeft, form->base.FTop );

   gtk_widget_show( form->FWindow );

   if( form->FDesignMode && form->FOverlay )
      gtk_widget_grab_focus( form->FOverlay );

   /* No gtk_main() - shares the main window's loop, so FRunning stays 0 */
}

/* ShowModal() - create, show as modal, block until closed, return FModalResult */
static int HBForm_ShowModal( HBForm * form )
{
   EnsureGTK();

   form->FWindow = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(form->FWindow), form->base.FText );
   gtk_window_set_default_size( GTK_WINDOW(form->FWindow), form->base.FWidth, form->base.FHeight );
   gtk_window_set_resizable( GTK_WINDOW(form->FWindow),
      (form->FDesignMode || (form->FSizable && !form->FAppBar)) ? TRUE : FALSE );
   gtk_window_set_modal( GTK_WINDOW(form->FWindow), TRUE );
   /* Set transient for a visible parent window so GTK blocks input to it */
   {
      GList * toplevels = gtk_window_list_toplevels();
      GList * l;
      for( l = toplevels; l; l = l->next )
         if( gtk_widget_get_visible( GTK_WIDGET(l->data) ) &&
             GTK_WIDGET(l->data) != form->FWindow ) {
            gtk_window_set_transient_for( GTK_WINDOW(form->FWindow),
               GTK_WINDOW(l->data) );
            break;
         }
      g_list_free( toplevels );
   }
   g_signal_connect( form->FWindow, "destroy", G_CALLBACK(on_window_destroy), form );
   g_signal_connect( form->FWindow, "configure-event", G_CALLBACK(on_window_configure), form );

   /* Background color — only when user explicitly set FClrPane */
   if( form->FClrPaneExplicit )
   {
      unsigned int clr = form->base.FClrPane;
      int r = clr & 0xFF, g = (clr >> 8) & 0xFF, b = (clr >> 16) & 0xFF;
      char css[128];
      snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
      GtkCssProvider * provider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( form->FWindow );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_USER );
      g_object_unref( provider );
   }

   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(form->FWindow), vbox );
   gtk_widget_show( vbox );

   GtkWidget * overlay = gtk_overlay_new();
   gtk_box_pack_start( GTK_BOX(vbox), overlay, TRUE, TRUE, 0 );
   gtk_widget_show( overlay );

   form->FFixed = gtk_fixed_new();
   gtk_container_add( GTK_CONTAINER(overlay), form->FFixed );
   gtk_widget_show( form->FFixed );

   HBForm_CreateAllChildren( form );

   /* Menu bar: built by HBMainMenu_Attach() during CreateAllChildren, or pre-existing */
   if( form->FMenuBar ) {
      gtk_box_pack_start( GTK_BOX(vbox), form->FMenuBar, FALSE, FALSE, 0 );
      gtk_box_reorder_child( GTK_BOX(vbox), form->FMenuBar, 0 );
      gtk_widget_show_all( form->FMenuBar );
   }

   /* Runtime: wire form-level click event */
   gtk_widget_add_events( form->FWindow, GDK_BUTTON_PRESS_MASK );
   g_signal_connect( form->FWindow, "button-press-event", G_CALLBACK(on_form_click), form );

   if( form->FCenter )
      gtk_window_set_position( GTK_WINDOW(form->FWindow), GTK_WIN_POS_CENTER );
   else
      gtk_window_move( GTK_WINDOW(form->FWindow), form->base.FLeft, form->base.FTop );

   gtk_widget_show( form->FWindow );

   form->FModalResult = 0;
   form->FRunning = 1;
   gtk_main();  /* nested main loop - blocks until gtk_main_quit() */

   return form->FModalResult;
}

static void HBForm_Close( HBForm * form )
{
   /* Don't clear FRunning here — on_window_destroy checks it
    * to decide whether to quit the gtk_main loop */
   if( form->FWindow )
   {
      gtk_widget_destroy( form->FWindow );
      /* on_window_destroy sets FWindow = NULL and FRunning = 0 */
   }
}

static void HBForm_SetDesignMode( HBForm * form, int design )
{
   form->FDesignMode = design;
   HBForm_ClearSelection( form );
   /* In design mode, form must always be resizable */
   if( design && form->FWindow )
      gtk_window_set_resizable( GTK_WINDOW(form->FWindow), TRUE );
}

/* ======================================================================
 * HB_FUNC Bridge functions
 * ====================================================================== */

static HBControl * GetCtrlRaw( int nParam )
{
   return (HBControl *)(HB_PTRUINT) hb_parnint( nParam );
}

static void RetCtrl( HBControl * p )
{
   KeepAlive( p );
   hb_retnint( (HB_PTRUINT) p );
}

#define GetCtrl(n) GetCtrlRaw(n)
#define GetForm(n) ((HBForm *)GetCtrlRaw(n))

/* --- Form --- */

HB_FUNC( UI_FORMNEW )
{
   HBForm * p = (HBForm *) calloc( 1, sizeof(HBForm) );
   HBForm_Init( p );
   if( HB_ISCHAR(1) ) HBControl_SetText( &p->base, hb_parc(1) );
   if( HB_ISNUM(2) )  p->base.FWidth = hb_parni(2);
   if( HB_ISNUM(3) )  p->base.FHeight = hb_parni(3);
   if( HB_ISCHAR(4) && HB_ISNUM(5) )
   {
      snprintf( p->FFormFontDesc, sizeof(p->FFormFontDesc), "%s %d", hb_parc(4), hb_parni(5) );
      strcpy( p->base.FFontDesc, p->FFormFontDesc );
   }
   RetCtrl( &p->base );
}

HB_FUNC( UI_ONSELCHANGE )
{
   HBForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p && pBlock )
   {
      if( p->FOnSelChange ) hb_itemRelease( p->FOnSelChange );
      p->FOnSelChange = hb_itemNew( pBlock );
   }
}

HB_FUNC( UI_GETSELECTED )
{
   HBForm * p = GetForm(1);
   if( p && p->FSelCount > 0 )
      hb_retnint( (HB_PTRUINT) p->FSelected[0] );
   else
      hb_retnint( 0 );
}

HB_FUNC( UI_FORMSETDESIGN ) { HBForm * p = GetForm(1); if( p ) HBForm_SetDesignMode( p, hb_parl(2) ); }
HB_FUNC( UI_FORMRUN )       { HBForm * p = GetForm(1); if( p ) HBForm_Run( p ); }
HB_FUNC( UI_FORMSHOW )      { HBForm * p = GetForm(1); if( p ) HBForm_Show( p ); }
HB_FUNC( UI_FORMSHOWMODAL ) { HBForm * p = GetForm(1); if( p ) hb_retni( HBForm_ShowModal( p ) ); else hb_retni(0); }
HB_FUNC( UI_FORMCLOSE )     { HBForm * p = GetForm(1); if( p ) HBForm_Close( p ); }
HB_FUNC( UI_FORMDESTROY )   { HBForm * p = GetForm(1); if( p ) { if( p->FWindow ) { gtk_widget_destroy( p->FWindow ); p->FWindow = NULL; } HBControl_ReleaseEvents(&p->base); RemoveControl(&p->base); free(p); } }
HB_FUNC( UI_FORMRESULT )    { HBForm * p = GetForm(1); hb_retni( p ? p->FModalResult : 0 ); }

/* --- Control creation --- */

/* UI_DropNonVisual( hForm, nType, cName ) --> hCtrl
 * Create a non-visual component in design mode (used when loading a project) */
HB_FUNC( UI_DROPNONVISUAL )
{
   HBForm * form = GetForm(1);
   int nType = hb_parni(2);
   const char * cName = HB_ISCHAR(3) ? hb_parc(3) : "";
   if( !form || nType <= 0 ) { hb_retnint(0); return; }

   /* Find a free position at the bottom of the form for the non-visual icon */
   int nL = 8, nT = form->base.FHeight - 40;
   int i;
   for( i = 0; i < form->base.FChildCount; i++ )
   {
      HBControl * c = form->base.FChildren[i];
      if( IsNonVisualControl( c->FControlType ) )
      {
         if( c->FLeft >= nL && c->FLeft < nL + 32 &&
             c->FTop >= nT && c->FTop < nT + 32 )
         {
            nL += 36;
            if( nL + 28 > form->base.FWidth ) { nL = 8; nT -= 36; }
         }
      }
   }

   HBControl * newCtrl = HBForm_CreateControlOfType( form, nType, nL, nT, 28, 28 );
   if( newCtrl && cName[0] )
      strncpy( newCtrl->FName, cName, sizeof(newCtrl->FName) - 1 );
   hb_retnint( newCtrl ? (HB_PTRUINT) newCtrl : 0 );
}

HB_FUNC( UI_LABELNEW )
{
   HBForm * pForm = GetForm(1);
   HBLabel * p = (HBLabel *) calloc( 1, sizeof(HBLabel) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TLabel" );
   p->base.FControlType = CT_LABEL; p->base.FWidth = 80; p->base.FHeight = 15; p->base.FTabStop = 0;
   strcpy( p->base.FText, "Label" );
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_EDITNEW )
{
   HBForm * pForm = GetForm(1);
   HBEdit * p = (HBEdit *) calloc( 1, sizeof(HBEdit) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TEdit" );
   p->base.FControlType = CT_EDIT; p->base.FWidth = 200; p->base.FHeight = 24;
   p->FReadOnly = 0; p->FPassword = 0;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_BUTTONNEW )
{
   HBForm * pForm = GetForm(1);
   HBButton * p = (HBButton *) calloc( 1, sizeof(HBButton) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TButton" );
   p->base.FControlType = CT_BUTTON; p->base.FWidth = 88; p->base.FHeight = 26;
   p->FDefault = 0; p->FCancel = 0;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_CHECKBOXNEW )
{
   HBForm * pForm = GetForm(1);
   HBCheckBox * p = (HBCheckBox *) calloc( 1, sizeof(HBCheckBox) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TCheckBox" );
   p->base.FControlType = CT_CHECKBOX; p->base.FWidth = 150; p->base.FHeight = 19;
   p->FChecked = 0;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_COMBOBOXNEW )
{
   HBForm * pForm = GetForm(1);
   HBComboBox * p = (HBComboBox *) calloc( 1, sizeof(HBComboBox) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TComboBox" );
   p->base.FControlType = CT_COMBOBOX; p->base.FWidth = 175; p->base.FHeight = 26;
   p->FItemIndex = 0; p->FItemCount = 0;
   memset( p->FItems, 0, sizeof(p->FItems) );
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_GROUPBOXNEW )
{
   HBForm * pForm = GetForm(1);
   HBGroupBox * p = (HBGroupBox *) calloc( 1, sizeof(HBGroupBox) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TGroupBox" );
   p->base.FControlType = CT_GROUPBOX; p->base.FWidth = 200; p->base.FHeight = 100; p->base.FTabStop = 0;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_RADIOBUTTONNEW )
{
   HBForm * pForm = GetForm(1);
   HBRadioButton * p = (HBRadioButton *) calloc( 1, sizeof(HBRadioButton) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TRadioButton" );
   p->base.FControlType = CT_RADIO; p->base.FWidth = 150; p->base.FHeight = 19;
   p->FChecked = 0; memset( p->FGroupName, 0, sizeof(p->FGroupName) );
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_BITBTNNEW )
{
   HBForm * pForm = GetForm(1);
   HBBitBtn * p = (HBBitBtn *) calloc( 1, sizeof(HBBitBtn) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TBitBtn" );
   p->base.FControlType = CT_BITBTN; p->base.FWidth = 88; p->base.FHeight = 26;
   p->FLayout = 0; p->FSpacing = 4; memset( p->FGlyph, 0, sizeof(p->FGlyph) );
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_IMAGENEW )
{
   HBForm * pForm = GetForm(1);
   HBImage * p = (HBImage *) calloc( 1, sizeof(HBImage) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TImage" );
   p->base.FControlType = CT_IMAGE; p->base.FWidth = 100; p->base.FHeight = 100;
   p->FStretch = 0; p->FCenter = 0; p->FProportional = 0;
   memset( p->FPicture, 0, sizeof(p->FPicture) );
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_SHAPENEW )
{
   HBForm * pForm = GetForm(1);
   HBShape * p = (HBShape *) calloc( 1, sizeof(HBShape) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TShape" );
   p->base.FControlType = CT_SHAPE; p->base.FWidth = 65; p->base.FHeight = 65;
   p->FShape = 0; p->FPenColor = 0; p->FPenWidth = 1; p->FBrushColor = 0xFFFFFF;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_BEVELNEW )
{
   HBForm * pForm = GetForm(1);
   HBBevel * p = (HBBevel *) calloc( 1, sizeof(HBBevel) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TBevel" );
   p->base.FControlType = CT_BEVEL; p->base.FWidth = 200; p->base.FHeight = 50;
   p->FBevelStyle = 1; p->FBevelShape = 0; p->base.FTabStop = 0;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_RICHEDITNEW )
{
   HBForm * pForm = GetForm(1);
   HBRichEdit * p = (HBRichEdit *) calloc( 1, sizeof(HBRichEdit) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TRichEdit" );
   p->base.FControlType = CT_RICHEDIT; p->base.FWidth = 200; p->base.FHeight = 100;
   p->FReadOnly = 0; p->FWordWrap = 1; p->FScrollBars = 3;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_LISTVIEWNEW )
{
   HBForm * pForm = GetForm(1);
   HBListView * p = (HBListView *) calloc( 1, sizeof(HBListView) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TListView" );
   p->base.FControlType = CT_LISTVIEW; p->base.FWidth = 250; p->base.FHeight = 150;
   p->FViewStyle = 3; p->FGridLines = 1; p->FColumnCount = 0;
   memset( p->FColumns, 0, sizeof(p->FColumns) );
   memset( p->FColumnWidths, 0, sizeof(p->FColumnWidths) );
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_LISTVIEWADDCOLUMN )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_LISTVIEW ) return;
   HBListView * lv = (HBListView*)p;
   if( lv->FColumnCount >= 16 ) return;
   if( HB_ISCHAR(2) )
      strncpy( lv->FColumns[lv->FColumnCount], hb_parc(2), 63 );
   lv->FColumnWidths[lv->FColumnCount] = HB_ISNUM(3) ? hb_parni(3) : 100;
   lv->FColumnCount++;
}

/* UI_BrowseNew( hParent, nLeft, nTop, nWidth, nHeight ) --> hCtrl
 * Creates the GtkListStore eagerly so SetCell/SetArray can populate data
 * before the form is activated and the TreeView widget is created. */
HB_FUNC( UI_BROWSENEW )
{
   HBForm * pForm = GetForm(1);
   HBBrowse * p = (HBBrowse *) calloc( 1, sizeof(HBBrowse) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TBrowse" );
   p->base.FControlType = CT_BROWSE;
   p->base.FWidth = 400; p->base.FHeight = 200;
   p->FReadOnly = 0;
   p->FGridLines = 1;
   p->FRowHeight = 22;
   p->FColumnCount = 0;
   p->FRowCount = 0;
   p->FTreeView = NULL;
   p->FDataSourceName[0] = 0;
   memset( p->FCols, 0, sizeof(p->FCols) );

   /* Pre-allocate ListStore so SetCell works before widget creation */
   EnsureGTK();
   GType types[MAX_BROWSE_COLS];
   for( int i = 0; i < MAX_BROWSE_COLS; i++ )
      types[i] = G_TYPE_STRING;
   p->FStore = gtk_list_store_newv( MAX_BROWSE_COLS, types );

   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

/* UI_BrowseAddCol( hBrowse, cTitle, cField, nWidth, nAlign ) --> nColIdx */
HB_FUNC( UI_BROWSEADDCOL )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_BROWSE ) { hb_retni(-1); return; }
   HBBrowse * br = (HBBrowse*)p;
   if( br->FColumnCount >= MAX_BROWSE_COLS ) { hb_retni(-1); return; }

   int idx = br->FColumnCount++;
   if( HB_ISCHAR(2) ) strncpy( br->FCols[idx].szTitle, hb_parc(2), 63 );
   if( HB_ISCHAR(3) ) strncpy( br->FCols[idx].szFieldName, hb_parc(3), 63 );
   br->FCols[idx].nWidth = HB_ISNUM(4) ? hb_parni(4) : 100;
   br->FCols[idx].nAlign = HB_ISNUM(5) ? hb_parni(5) : 0;
   br->FCols[idx].szFooterText[0] = 0;

   /* If widget already exists (live form), add column dynamically */
   if( br->FTreeView )
   {
      GtkCellRenderer * r = gtk_cell_renderer_text_new();
      float xalign = 0.0;
      if( br->FCols[idx].nAlign == 1 ) xalign = 0.5;
      else if( br->FCols[idx].nAlign == 2 ) xalign = 1.0;
      g_object_set( r, "xalign", xalign, NULL );

      GtkTreeViewColumn * col = gtk_tree_view_column_new_with_attributes(
         br->FCols[idx].szTitle, r, "text", idx, NULL );
      gtk_tree_view_column_set_resizable( col, TRUE );
      if( br->FCols[idx].nWidth > 0 )
         gtk_tree_view_column_set_fixed_width( col, br->FCols[idx].nWidth );
      gtk_tree_view_column_set_sizing( col, GTK_TREE_VIEW_COLUMN_FIXED );
      gtk_tree_view_append_column( GTK_TREE_VIEW(br->FTreeView), col );
   }

   hb_retni( idx );
}

/* UI_BrowseSetCell( hBrowse, nRow, nCol, cText ) */
HB_FUNC( UI_BROWSESETCELL )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_BROWSE || !HB_ISCHAR(4) ) return;
   HBBrowse * br = (HBBrowse*)p;
   int nRow = hb_parni(2);
   int nCol = hb_parni(3);
   const char * szText = hb_parc(4);

   if( !br->FStore || nCol < 0 || nCol >= br->FColumnCount ) return;

   /* Ensure row exists — append empty rows as needed */
   GtkTreeIter iter;
   while( br->FRowCount <= nRow )
   {
      gtk_list_store_append( br->FStore, &iter );
      br->FRowCount++;
   }

   /* Navigate to the target row */
   GtkTreePath * path = gtk_tree_path_new_from_indices( nRow, -1 );
   if( gtk_tree_model_get_iter( GTK_TREE_MODEL(br->FStore), &iter, path ) )
      gtk_list_store_set( br->FStore, &iter, nCol, szText, -1 );
   gtk_tree_path_free( path );
}

/* UI_BrowseGetCell( hBrowse, nRow, nCol ) --> cText */
HB_FUNC( UI_BROWSEGETCELL )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_BROWSE ) { hb_retc(""); return; }
   HBBrowse * br = (HBBrowse*)p;
   int nRow = hb_parni(2);
   int nCol = hb_parni(3);

   if( !br->FStore || nRow < 0 || nRow >= br->FRowCount ||
       nCol < 0 || nCol >= br->FColumnCount ) { hb_retc(""); return; }

   GtkTreeIter iter;
   GtkTreePath * path = gtk_tree_path_new_from_indices( nRow, -1 );
   if( gtk_tree_model_get_iter( GTK_TREE_MODEL(br->FStore), &iter, path ) )
   {
      gchar * val = NULL;
      gtk_tree_model_get( GTK_TREE_MODEL(br->FStore), &iter, nCol, &val, -1 );
      hb_retc( val ? val : "" );
      g_free( val );
   }
   else
      hb_retc( "" );
   gtk_tree_path_free( path );
}

/* UI_BrowseColCount( hBrowse ) --> nCols */
HB_FUNC( UI_BROWSECOLCOUNT )
{
   HBControl * p = GetCtrl(1);
   if( p && p->FControlType == CT_BROWSE )
      hb_retni( ((HBBrowse*)p)->FColumnCount );
   else
      hb_retni( 0 );
}

/* UI_BrowseSetColProp( hBrowse, nCol, cPropName, xValue ) */
HB_FUNC( UI_BROWSESETCOLPROP )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_BROWSE ) return;
   HBBrowse * br = (HBBrowse*)p;
   int nCol = HB_ISNUM(2) ? hb_parni(2) : -1;
   const char * szProp = HB_ISCHAR(3) ? hb_parc(3) : NULL;
   if( nCol < 0 || nCol >= br->FColumnCount || !szProp ) return;

   if( strcasecmp( szProp, "cTitle" ) == 0 && HB_ISCHAR(4) )
   {
      strncpy( br->FCols[nCol].szTitle, hb_parc(4), 63 );
      if( br->FTreeView )
      {
         GtkTreeViewColumn * col = gtk_tree_view_get_column(
            GTK_TREE_VIEW(br->FTreeView), nCol );
         if( col )
            gtk_tree_view_column_set_title( col, br->FCols[nCol].szTitle );
      }
   }
   else if( strcasecmp( szProp, "nWidth" ) == 0 && HB_ISNUM(4) )
   {
      br->FCols[nCol].nWidth = hb_parni(4);
      if( br->FTreeView )
      {
         GtkTreeViewColumn * col = gtk_tree_view_get_column(
            GTK_TREE_VIEW(br->FTreeView), nCol );
         if( col )
            gtk_tree_view_column_set_fixed_width( col, br->FCols[nCol].nWidth );
      }
   }
   else if( strcasecmp( szProp, "nAlign" ) == 0 && HB_ISNUM(4) )
   {
      br->FCols[nCol].nAlign = hb_parni(4);
   }
   else if( strcasecmp( szProp, "cFieldName" ) == 0 && HB_ISCHAR(4) )
   {
      strncpy( br->FCols[nCol].szFieldName, hb_parc(4), 63 );
   }
   else if( strcasecmp( szProp, "cFooterText" ) == 0 && HB_ISCHAR(4) )
   {
      strncpy( br->FCols[nCol].szFooterText, hb_parc(4), 63 );
      if( br->FFooterBar )
      {
         /* Show footer bar if any column has footer text, hide otherwise */
         int hasFooter = 0;
         for( int i = 0; i < br->FColumnCount; i++ )
            if( br->FCols[i].szFooterText[0] ) { hasFooter = 1; break; }
         if( hasFooter )
            gtk_widget_show( br->FFooterBar );
         else
            gtk_widget_hide( br->FFooterBar );
         gtk_widget_queue_draw( br->FFooterBar );
      }
   }
}

/* UI_BrowseGetColProps( hBrowse, nCol ) --> aProps (same format as Windows) */
HB_FUNC( UI_BROWSEGETCOLPROPS )
{
   HBControl * p = GetCtrl(1);
   int nCol = hb_parni(2);
   if( !p || p->FControlType != CT_BROWSE ) { hb_reta(0); return; }
   HBBrowse * br = (HBBrowse*)p;
   if( nCol < 0 || nCol >= br->FColumnCount ) { hb_reta(0); return; }

   PHB_ITEM aResult = hb_itemArrayNew( 5 );
   PHB_ITEM aProp;

   aProp = hb_itemArrayNew( 4 );
   hb_arraySetC( aProp, 1, "cTitle" );
   hb_arraySetC( aProp, 2, br->FCols[nCol].szTitle );
   hb_arraySetC( aProp, 3, "Column" );
   hb_arraySetC( aProp, 4, "S" );
   hb_arraySet( aResult, 1, aProp );
   hb_itemRelease( aProp );

   aProp = hb_itemArrayNew( 4 );
   hb_arraySetC( aProp, 1, "cFieldName" );
   hb_arraySetC( aProp, 2, br->FCols[nCol].szFieldName );
   hb_arraySetC( aProp, 3, "Column" );
   hb_arraySetC( aProp, 4, "S" );
   hb_arraySet( aResult, 2, aProp );
   hb_itemRelease( aProp );

   aProp = hb_itemArrayNew( 4 );
   hb_arraySetC( aProp, 1, "nWidth" );
   hb_arraySetNI( aProp, 2, br->FCols[nCol].nWidth );
   hb_arraySetC( aProp, 3, "Column" );
   hb_arraySetC( aProp, 4, "N" );
   hb_arraySet( aResult, 3, aProp );
   hb_itemRelease( aProp );

   aProp = hb_itemArrayNew( 4 );
   hb_arraySetC( aProp, 1, "nAlign" );
   hb_arraySetNI( aProp, 2, br->FCols[nCol].nAlign );
   hb_arraySetC( aProp, 3, "Column" );
   hb_arraySetC( aProp, 4, "N" );
   hb_arraySet( aResult, 4, aProp );
   hb_itemRelease( aProp );

   aProp = hb_itemArrayNew( 4 );
   hb_arraySetC( aProp, 1, "cFooterText" );
   hb_arraySetC( aProp, 2, br->FCols[nCol].szFooterText );
   hb_arraySetC( aProp, 3, "Column" );
   hb_arraySetC( aProp, 4, "S" );
   hb_arraySet( aResult, 5, aProp );
   hb_itemRelease( aProp );

   hb_itemReturnRelease( aResult );
}

/* UI_BrowseRefresh( hBrowse ) */
HB_FUNC( UI_BROWSEREFRESH )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_BROWSE ) return;
   HBBrowse * br = (HBBrowse*)p;
   if( br->FTreeView )
      gtk_widget_queue_draw( br->FTreeView );
}

/* --- Property access --- */

HB_FUNC( UI_SETPROP )
{
   HBControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);
   if( !p || !szProp ) return;

   if( strcasecmp( szProp, "cText" ) == 0 && HB_ISCHAR(3) )
   {
      HBControl_SetText( p, hb_parc(3) );
      if( p->FControlType == CT_FORM )
      {
         HBForm * pF = (HBForm *)p;
         if( pF->FWindow )
            gtk_window_set_title( GTK_WINDOW(pF->FWindow), p->FText );
      }
      else if( p->FWidget )
      {
         if( GTK_IS_LABEL(p->FWidget) )
            gtk_label_set_text( GTK_LABEL(p->FWidget), p->FText );
         else if( GTK_IS_ENTRY(p->FWidget) )
            gtk_entry_set_text( GTK_ENTRY(p->FWidget), p->FText );
         else if( GTK_IS_BUTTON(p->FWidget) )
            gtk_button_set_label( GTK_BUTTON(p->FWidget), p->FText );
         else if( GTK_IS_FRAME(p->FWidget) )
            gtk_frame_set_label( GTK_FRAME(p->FWidget), p->FText );
      }
   }
   else if( strcasecmp(szProp,"nLeft")==0 ) {
      p->FLeft = hb_parni(3);
      if( p->FControlType == CT_FORM ) {
         HBForm * f = (HBForm *)p; f->FCenter = 0;
         if( f->FWindow ) gtk_window_move( GTK_WINDOW(f->FWindow), p->FLeft, p->FTop );
      } else HBControl_UpdatePosition(p);
   }
   else if( strcasecmp(szProp,"nTop")==0 ) {
      p->FTop = hb_parni(3);
      if( p->FControlType == CT_FORM ) {
         HBForm * f = (HBForm *)p; f->FCenter = 0;
         if( f->FWindow ) gtk_window_move( GTK_WINDOW(f->FWindow), p->FLeft, p->FTop );
      } else HBControl_UpdatePosition(p);
   }
   else if( strcasecmp(szProp,"nWidth")==0 ) {
      p->FWidth = hb_parni(3);
      if( p->FControlType == CT_FORM ) {
         HBForm * f = (HBForm *)p; if( f->FWindow ) gtk_window_resize( GTK_WINDOW(f->FWindow), p->FWidth, p->FHeight );
      } else HBControl_UpdatePosition(p);
   }
   else if( strcasecmp(szProp,"nHeight")==0 ) {
      p->FHeight = hb_parni(3);
      if( p->FControlType == CT_FORM ) {
         HBForm * f = (HBForm *)p; if( f->FWindow ) gtk_window_resize( GTK_WINDOW(f->FWindow), p->FWidth, p->FHeight );
      } else HBControl_UpdatePosition(p);
   }
   else if( strcasecmp(szProp,"lVisible")==0 ) {
      p->FVisible = hb_parl(3);
      if( p->FWidget ) gtk_widget_set_visible( p->FWidget, p->FVisible );
   }
   else if( strcasecmp(szProp,"lEnabled")==0 ) {
      p->FEnabled = hb_parl(3);
      if( p->FControlType == CT_TIMER ) {
         HBTimer * t = (HBTimer *)p;
         if( p->FEnabled ) HBTimer_Start( t ); else HBTimer_Stop( t );
      }
      else if( p->FWidget ) gtk_widget_set_sensitive( p->FWidget, p->FEnabled );
   }
   else if( strcasecmp(szProp,"nInterval")==0 && p->FControlType == CT_TIMER ) {
      HBTimer * t = (HBTimer *)p;
      t->FInterval = hb_parni(3);
      if( t->base.FEnabled && t->FOnTimer ) HBTimer_Start( t );
   }
   else if( strcasecmp(szProp,"lDefault")==0 && p->FControlType == CT_BUTTON )
      ((HBButton *)p)->FDefault = hb_parl(3);
   else if( strcasecmp(szProp,"lCancel")==0 && p->FControlType == CT_BUTTON )
      ((HBButton *)p)->FCancel = hb_parl(3);
   else if( strcasecmp(szProp,"lChecked")==0 && p->FControlType == CT_CHECKBOX )
   {
      HBCheckBox * cb = (HBCheckBox *)p;
      cb->FChecked = hb_parl(3);
      if( cb->base.FWidget )
         gtk_toggle_button_set_active( GTK_TOGGLE_BUTTON(cb->base.FWidget), cb->FChecked );
   }
   else if( strcasecmp(szProp,"cName")==0 && HB_ISCHAR(3) )
      strncpy( p->FName, hb_parc(3), sizeof(p->FName)-1 );
   else if( strcasecmp(szProp,"lSizable")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FSizable = hb_parl(3);
   else if( strcasecmp(szProp,"lAppBar")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FAppBar = hb_parl(3);
   else if( strcasecmp(szProp,"nBorderStyle")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FBorderStyle = hb_parni(3);
   else if( strcasecmp(szProp,"nBorderIcons")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FBorderIcons = hb_parni(3);
   else if( strcasecmp(szProp,"nBorderWidth")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FBorderWidth = hb_parni(3);
   else if( strcasecmp(szProp,"nPosition")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FPosition = hb_parni(3);
   else if( strcasecmp(szProp,"nWindowState")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FWindowState = hb_parni(3);
   else if( strcasecmp(szProp,"nFormStyle")==0 && p->FControlType == CT_FORM ) {
      ((HBForm *)p)->FFormStyle = hb_parni(3);
      if( ((HBForm *)p)->FWindow )
         gtk_window_set_keep_above( GTK_WINDOW(((HBForm *)p)->FWindow), hb_parni(3) == 1 );
   }
   else if( strcasecmp(szProp,"nCursor")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FCursor = hb_parni(3);
   else if( strcasecmp(szProp,"lKeyPreview")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FKeyPreview = hb_parl(3);
   else if( strcasecmp(szProp,"lAlphaBlend")==0 && p->FControlType == CT_FORM ) {
      ((HBForm *)p)->FAlphaBlend = hb_parl(3);
      if( ((HBForm *)p)->FWindow )
         gtk_widget_set_opacity( ((HBForm *)p)->FWindow,
            hb_parl(3) ? ((HBForm *)p)->FAlphaBlendValue / 255.0 : 1.0 );
   }
   else if( strcasecmp(szProp,"nAlphaBlendValue")==0 && p->FControlType == CT_FORM ) {
      ((HBForm *)p)->FAlphaBlendValue = hb_parni(3);
      if( ((HBForm *)p)->FAlphaBlend && ((HBForm *)p)->FWindow )
         gtk_widget_set_opacity( ((HBForm *)p)->FWindow, hb_parni(3) / 255.0 );
   }
   else if( strcasecmp(szProp,"lShowHint")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FShowHint = hb_parl(3);
   else if( strcasecmp(szProp,"cHint")==0 && p->FControlType == CT_FORM && HB_ISCHAR(3) )
      strncpy( ((HBForm *)p)->FHint, hb_parc(3), 255 );
   else if( strcasecmp(szProp,"lAutoScroll")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FAutoScroll = hb_parl(3);
   else if( strcasecmp(szProp,"lDoubleBuffered")==0 && p->FControlType == CT_FORM )
      ((HBForm *)p)->FDoubleBuffered = hb_parl(3);
   else if( strcasecmp(szProp,"cAppTitle")==0 && p->FControlType == CT_FORM && HB_ISCHAR(3) )
      strncpy( ((HBForm *)p)->FAppTitle, hb_parc(3), sizeof(((HBForm *)p)->FAppTitle) - 1 );
   else if( strcasecmp(szProp,"aTabs")==0 && p->FControlType == CT_TABCONTROL2 && HB_ISCHAR(3) )
      HBTabControl2_SetTabs( p, hb_parc(3) );
   else if( strcasecmp(szProp,"nClrText")==0 )
   {
      p->FClrText = (unsigned int)hb_parnint(3);
      HBControl_ApplyColors( p );
   }
   else if( strcasecmp(szProp,"lTransparent")==0 )
   {
      p->FTransparent = hb_parl(3) ? 1 : 0;
      HBControl_ApplyColors( p );
   }
   else if( strcasecmp(szProp,"nAlign")==0 )
   {
      p->FAlign = hb_parni(3);
      HBControl_ApplyAlign( p );
   }
   else if( strcasecmp(szProp,"nClrPane")==0 )
   {
      p->FClrPane = (unsigned int)hb_parnint(3);
      /* Setting nClrPane on a non-form/non-browse control implies opaque */
      if( p->FControlType != CT_FORM && p->FControlType != CT_BROWSE &&
          p->FControlType != CT_DBGRID )
      {
         p->FTransparent = 0;
         HBControl_ApplyColors( p );
      }
      if( p->FControlType == CT_FORM )
      {
         HBForm * pF = (HBForm *)p;
         pF->FClrPaneExplicit = 1;
         if( pF->FWindow )
         {
            int r = p->FClrPane & 0xFF, g = (p->FClrPane >> 8) & 0xFF, b = (p->FClrPane >> 16) & 0xFF;
            char css[128];
            snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
            GtkCssProvider * provider = gtk_css_provider_new();
            gtk_css_provider_load_from_data( provider, css, -1, NULL );
            GtkStyleContext * ctx = gtk_widget_get_style_context( pF->FWindow );
            gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
               GTK_STYLE_PROVIDER_PRIORITY_USER );
            g_object_unref( provider );
         }
      }
      else if( p->FControlType == CT_BROWSE || p->FControlType == CT_DBGRID )
      {
         HBBrowse * br = (HBBrowse *)p;
         if( br->FTreeView )
         {
            int r = p->FClrPane & 0xFF, g = (p->FClrPane >> 8) & 0xFF, b = (p->FClrPane >> 16) & 0xFF;
            char css[256];
            snprintf( css, sizeof(css),
               "treeview { background-color: #%02X%02X%02X; }"
               "treeview:selected { background-color: @theme_selected_bg_color; }",
               r, g, b );
            GtkCssProvider * provider = gtk_css_provider_new();
            gtk_css_provider_load_from_data( provider, css, -1, NULL );
            GtkStyleContext * ctx = gtk_widget_get_style_context( br->FTreeView );
            gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
               GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
            g_object_unref( provider );
         }
      }
   }
   else if( strcasecmp(szProp,"oFont")==0 && HB_ISCHAR(3) )
   {
      char szFace[64] = {0}; int nSize = 12;
      const char * val = hb_parc(3);
      const char * comma = strchr( val, ',' );
      if( comma ) {
         int len = (int)(comma - val); if( len > 63 ) len = 63;
         memcpy( szFace, val, len ); nSize = atoi( comma + 1 );
      } else strncpy( szFace, val, 63 );
      if( nSize <= 0 ) nSize = 12;

      snprintf( p->FFontDesc, sizeof(p->FFontDesc), "%s %d", szFace, nSize );

      if( p->FControlType == CT_FORM )
      {
         HBForm * pF = (HBForm *)p;
         strcpy( pF->FFormFontDesc, p->FFontDesc );
         for( int i = 0; i < pF->base.FChildCount; i++ )
         {
            strcpy( pF->base.FChildren[i]->FFontDesc, p->FFontDesc );
            HBControl_ApplyFont( pF->base.FChildren[i] );
         }
      }
      else
         HBControl_ApplyFont( p );
   }
   /* RadioButton */
   else if( strcasecmp( szProp, "cGroupName" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_RADIO )
      strncpy( ((HBRadioButton*)p)->FGroupName, hb_parc(3), 31 );
   /* BitBtn */
   else if( strcasecmp( szProp, "cGlyph" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_BITBTN )
      strncpy( ((HBBitBtn*)p)->FGlyph, hb_parc(3), 255 );
   else if( strcasecmp( szProp, "nLayout" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BITBTN )
      ((HBBitBtn*)p)->FLayout = hb_parni(3);
   else if( strcasecmp( szProp, "nSpacing" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BITBTN )
      ((HBBitBtn*)p)->FSpacing = hb_parni(3);
   /* Image */
   else if( strcasecmp( szProp, "cPicture" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_IMAGE )
      strncpy( ((HBImage*)p)->FPicture, hb_parc(3), 255 );
   else if( strcasecmp( szProp, "lStretch" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_IMAGE )
      ((HBImage*)p)->FStretch = hb_parl(3);
   else if( strcasecmp( szProp, "lCenter" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_IMAGE )
      ((HBImage*)p)->FCenter = hb_parl(3);
   else if( strcasecmp( szProp, "lProportional" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_IMAGE )
      ((HBImage*)p)->FProportional = hb_parl(3);
   /* Shape */
   else if( strcasecmp( szProp, "nShape" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FShape = hb_parni(3);
   else if( strcasecmp( szProp, "nPenColor" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FPenColor = hb_parni(3);
   else if( strcasecmp( szProp, "nPenWidth" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FPenWidth = hb_parni(3);
   else if( strcasecmp( szProp, "nBrushColor" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FBrushColor = hb_parni(3);
   /* Bevel */
   else if( strcasecmp( szProp, "nBevelStyle" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BEVEL )
      ((HBBevel*)p)->FBevelStyle = hb_parni(3);
   else if( strcasecmp( szProp, "nBevelShape" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BEVEL )
      ((HBBevel*)p)->FBevelShape = hb_parni(3);
   /* RichEdit */
   else if( strcasecmp( szProp, "lWordWrap" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_RICHEDIT )
      ((HBRichEdit*)p)->FWordWrap = hb_parl(3);
   else if( strcasecmp( szProp, "nScrollBars" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_RICHEDIT )
      ((HBRichEdit*)p)->FScrollBars = hb_parni(3);
   /* Browse */
   else if( strcasecmp( szProp, "nRowHeight" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BROWSE )
      ((HBBrowse*)p)->FRowHeight = hb_parni(3);
   else if( strcasecmp( szProp, "lGridLines" ) == 0 && HB_ISLOG(3) &&
            ( p->FControlType == CT_BROWSE || p->FControlType == CT_LISTVIEW ) )
   {
      if( p->FControlType == CT_BROWSE ) ((HBBrowse*)p)->FGridLines = hb_parl(3);
      else ((HBListView*)p)->FGridLines = hb_parl(3);
   }
   else if( strcasecmp( szProp, "cDataSource" ) == 0 && HB_ISCHAR(3) &&
            ( p->FControlType == CT_BROWSE || p->FControlType == CT_DBGRID ) )
      strncpy( ((HBBrowse*)p)->FDataSourceName, hb_parc(3), 63 );
   /* WebView */
   else if( strcasecmp( szProp, "cUrl" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_WEBVIEW )
   {
      strncpy( ((HBWebView*)p)->FUrl, hb_parc(3), sizeof(((HBWebView*)p)->FUrl) - 1 );
#ifdef HAVE_WEBKIT2GTK
      if( p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
         webkit_web_view_load_uri( WEBKIT_WEB_VIEW(p->FWidget), hb_parc(3) );
#endif
   }
   else if( strcasecmp( szProp, "aColumns" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_BROWSE )
   {
      /* Parse pipe-separated column titles, rebuild FCols[] */
      HBBrowse * br = (HBBrowse*)p;
      const char * val = hb_parc(3);
      int ci = 0;
      while( *val && ci < MAX_BROWSE_COLS )
      {
         const char * pipe = strchr( val, '|' );
         int len = pipe ? (int)(pipe - val) : (int)strlen(val);
         if( len > 63 ) len = 63;
         if( ci < br->FColumnCount )
         {
            /* Update existing column title */
            memcpy( br->FCols[ci].szTitle, val, len );
            br->FCols[ci].szTitle[len] = 0;
         }
         else
         {
            /* Add new column */
            memset( &br->FCols[ci], 0, sizeof(HBBrowseCol) );
            memcpy( br->FCols[ci].szTitle, val, len );
            br->FCols[ci].szTitle[len] = 0;
            br->FCols[ci].nWidth = 100;
         }
         ci++;
         if( !pipe ) break;
         val = pipe + 1;
      }
      br->FColumnCount = ci;
      /* Update live TreeView column titles if widget exists */
      if( br->FTreeView )
      {
         int existing = (int) gtk_tree_view_get_n_columns( GTK_TREE_VIEW(br->FTreeView) );
         for( int i = 0; i < ci; i++ )
         {
            if( i < existing )
            {
               GtkTreeViewColumn * col = gtk_tree_view_get_column(
                  GTK_TREE_VIEW(br->FTreeView), i );
               if( col ) gtk_tree_view_column_set_title( col, br->FCols[i].szTitle );
            }
            else
            {
               GtkCellRenderer * r = gtk_cell_renderer_text_new();
               GtkTreeViewColumn * col = gtk_tree_view_column_new_with_attributes(
                  br->FCols[i].szTitle, r, "text", i, NULL );
               gtk_tree_view_column_set_resizable( col, TRUE );
               gtk_tree_view_column_set_fixed_width( col, br->FCols[i].nWidth );
               gtk_tree_view_column_set_sizing( col, GTK_TREE_VIEW_COLUMN_FIXED );
               gtk_tree_view_append_column( GTK_TREE_VIEW(br->FTreeView), col );
            }
         }
      }
   }
   else if( strcasecmp(szProp,"aItems")==0 && HB_ISCHAR(3) &&
            (p->FControlType==CT_COMBOBOX || p->FControlType==CT_LISTBOX) )
   {
      HBComboBox * cb = (HBComboBox *)p;
      const char * raw = hb_parc(3);
      /* Parse pipe-separated items into FItems */
      cb->FItemCount = 0;
      memset( cb->FItems, 0, sizeof(cb->FItems) );
      while( *raw && cb->FItemCount < 32 )
      {
         const char * pipe = strchr( raw, '|' );
         int len = pipe ? (int)(pipe - raw) : (int)strlen(raw);
         if( len > 63 ) len = 63;
         memcpy( cb->FItems[cb->FItemCount], raw, len );
         cb->FItems[cb->FItemCount][len] = 0;
         cb->FItemCount++;
         if( !pipe ) break;
         raw = pipe + 1;
      }
      /* Default selection to first item when items are set */
      if( cb->FItemCount > 0 && cb->FItemIndex == 0 )
         cb->FItemIndex = 1;
      /* Rebuild live widget */
      if( p->FControlType == CT_COMBOBOX && p->FWidget &&
          GTK_IS_COMBO_BOX_TEXT(p->FWidget) )
      {
         gtk_combo_box_text_remove_all( GTK_COMBO_BOX_TEXT(p->FWidget) );
         for( int i = 0; i < cb->FItemCount; i++ )
            gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(p->FWidget), cb->FItems[i] );
      }
      else if( p->FControlType == CT_LISTBOX && p->FWidget &&
               GTK_IS_SCROLLED_WINDOW(p->FWidget) )
      {
         GtkWidget * tv = gtk_bin_get_child( GTK_BIN(p->FWidget) );
         if( tv && GTK_IS_TREE_VIEW(tv) )
         {
            GtkListStore * store = GTK_LIST_STORE(
               gtk_tree_view_get_model( GTK_TREE_VIEW(tv) ) );
            if( store )
            {
               gtk_list_store_clear( store );
               for( int i = 0; i < cb->FItemCount; i++ )
               {
                  GtkTreeIter iter;
                  gtk_list_store_append( store, &iter );
                  gtk_list_store_set( store, &iter, 0, cb->FItems[i], -1 );
               }
               /* Update selection to reflect FItemIndex */
               GtkTreeSelection * sel = gtk_tree_view_get_selection( GTK_TREE_VIEW(tv) );
               int selRow = cb->FItemIndex > 0 ? cb->FItemIndex - 1 : 0;
               if( selRow < cb->FItemCount )
               {
                  GtkTreePath * path = gtk_tree_path_new_from_indices( selRow, -1 );
                  gtk_tree_selection_select_path( sel, path );
                  gtk_tree_path_free( path );
               }
            }
         }
      }
   }
   else if( strcasecmp(szProp,"aMenuItems")==0 && HB_ISCHAR(3) &&
            p->FControlType == CT_MAINMENU )
   {
      HBMainMenu * m = (HBMainMenu *)p;
      const char * raw = hb_parc(3);
      m->FNodeCount = 0;
      memset( m->FNodes, 0, sizeof(m->FNodes) );
      while( *raw && m->FNodeCount < MAX_MENU_NODES )
      {
         const char * pipe = strchr( raw, '|' );
         int tokLen = pipe ? (int)(pipe - raw) : (int)strlen(raw);
         char tok[512]; int tl = tokLen < 511 ? tokLen : 511;
         memcpy( tok, raw, tl ); tok[tl] = 0;
         int fi = m->FNodeCount;
         char * f0 = tok;
         char * f1 = strchr(f0, '\x01'); if(f1){*f1++=0;}else f1=(char*)"";
         char * f2 = f1[0]?strchr(f1,'\x01'):NULL; if(f2){*f2++=0;}else f2=(char*)"";
         char * f3 = f2?strchr(f2,'\x01'):NULL; if(f3){*f3++=0;}else f3=(char*)"";
         char * f4 = f3?strchr(f3,'\x01'):NULL; if(f4){*f4++=0;}else f4=(char*)"";
         char * f5 = f4?strchr(f4,'\x01'):NULL; if(f5){*f5++=0;}else f5=(char*)"-1";
         m->FNodes[fi].bSeparator = (strcmp(f0,"---")==0) ? 1 : 0;
         if( !m->FNodes[fi].bSeparator )
            strncpy( m->FNodes[fi].szCaption, f0, sizeof(m->FNodes[fi].szCaption)-1 );
         strncpy( m->FNodes[fi].szShortcut, f1, sizeof(m->FNodes[fi].szShortcut)-1 );
         strncpy( m->FNodes[fi].szHandler,  f2, sizeof(m->FNodes[fi].szHandler)-1 );
         m->FNodes[fi].bEnabled = f3[0]?atoi(f3):1;
         m->FNodes[fi].nLevel   = f4[0]?atoi(f4):0;
         m->FNodes[fi].nParent  = f5[0]?atoi(f5):-1;
         m->FNodeCount++;
         if( !pipe ) break;
         raw = pipe + 1;
      }
   }
   else if( strcasecmp(szProp,"aOnClick")==0 && p->FControlType == CT_MAINMENU )
   {
      HBMainMenu * m = (HBMainMenu *)p;
      PHB_ITEM pArr = hb_param(3, HB_IT_ARRAY);
      if( m->FOnClickArray ) { hb_itemRelease( m->FOnClickArray ); m->FOnClickArray = NULL; }
      if( pArr ) m->FOnClickArray = hb_itemNew( pArr );
   }
}

/* Stubs for controls not yet implemented on Linux */
HB_FUNC( UI_MEMONEW )
{
   /* TMemo — reuse TEdit with multiline GtkTextView */
   HBForm * pForm = GetForm(1);
   HBEdit * p = (HBEdit *) calloc( 1, sizeof(HBEdit) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TMemo" );
   p->base.FControlType = CT_EDIT; p->base.FWidth = 200; p->base.FHeight = 100;
   p->FReadOnly = 0; p->FPassword = 0;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_LISTBOXNEW )
{
   HBForm * pForm = GetForm(1);
   HBComboBox * p = (HBComboBox *) calloc( 1, sizeof(HBComboBox) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TListBox" );
   p->base.FControlType = CT_LISTBOX;
   p->base.FWidth = 120; p->base.FHeight = 100;
   p->FItemIndex = 0; p->FItemCount = 0;
   memset( p->FItems, 0, sizeof(p->FItems) );
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop  = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth  = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

/* UI_TimerNew( hForm, nInterval ) --> hCtrl - create runtime timer (non-visual) */
HB_FUNC( UI_TIMERNEW )
{
   HBForm * pForm = GetForm(1);
   int nInterval = HB_ISNUM(2) ? hb_parni(2) : 1000;
   HBTimer * p = (HBTimer *) calloc( 1, sizeof(HBTimer) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TTimer" );
   strcpy( p->base.FName, "Timer" );
   p->base.FControlType = CT_TIMER;
   p->base.FWidth = 0; p->base.FHeight = 0;
   p->base.FEnabled = 1;
   p->FInterval = nInterval;
   p->FOnTimer = NULL;
   p->FTimerID = 0;

   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_MAINMENUNEW )
{
   HBForm    * pForm = GetForm(1);
   HBMainMenu * p = (HBMainMenu *) calloc( 1, sizeof(HBMainMenu) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TMainMenu" );
   strcpy( p->base.FName,      "MainMenu" );
   p->base.FControlType = CT_MAINMENU;
   p->base.FWidth  = 0; p->base.FHeight = 0;
   p->base.FEnabled = 1;
   p->FNodeCount = 0;
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

/* macOS-only stubs (called from classes.prg error handler) */
HB_FUNC( MAC_RUNTIMEERRORDIALOG ) { hb_retni(0); }
HB_FUNC( MAC_APPTERMINATE ) { }

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
   else if( strcasecmp(szProp,"nBorderStyle")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FBorderStyle );
   else if( strcasecmp(szProp,"nBorderIcons")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FBorderIcons );
   else if( strcasecmp(szProp,"nBorderWidth")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FBorderWidth );
   else if( strcasecmp(szProp,"nPosition")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FPosition );
   else if( strcasecmp(szProp,"nWindowState")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FWindowState );
   else if( strcasecmp(szProp,"nFormStyle")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FFormStyle );
   else if( strcasecmp(szProp,"nCursor")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FCursor );
   else if( strcasecmp(szProp,"lKeyPreview")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FKeyPreview );
   else if( strcasecmp(szProp,"lAlphaBlend")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FAlphaBlend );
   else if( strcasecmp(szProp,"nAlphaBlendValue")==0 && p->FControlType==CT_FORM )
      hb_retni( ((HBForm *)p)->FAlphaBlendValue );
   else if( strcasecmp(szProp,"lShowHint")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FShowHint );
   else if( strcasecmp(szProp,"cHint")==0 && p->FControlType==CT_FORM )
      hb_retc( ((HBForm *)p)->FHint );
   else if( strcasecmp(szProp,"lAutoScroll")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FAutoScroll );
   else if( strcasecmp(szProp,"lDoubleBuffered")==0 && p->FControlType==CT_FORM )
      hb_retl( ((HBForm *)p)->FDoubleBuffered );
   else if( strcasecmp(szProp,"nClientWidth")==0 && p->FControlType==CT_FORM ) {
      HBForm * f = (HBForm *)p;
      if( f->FWindow ) { int w, h; gtk_window_get_size(GTK_WINDOW(f->FWindow),&w,&h); hb_retni(w); }
      else hb_retni( f->base.FWidth );
   }
   else if( strcasecmp(szProp,"nClientHeight")==0 && p->FControlType==CT_FORM ) {
      HBForm * f = (HBForm *)p;
      if( f->FWindow ) { int w, h; gtk_window_get_size(GTK_WINDOW(f->FWindow),&w,&h); hb_retni(h); }
      else hb_retni( f->base.FHeight );
   }
   else if( strcasecmp(szProp,"nInterval")==0 && p->FControlType==CT_TIMER )
      hb_retni( ((HBTimer *)p)->FInterval );
   else if( strcasecmp(szProp,"nItemIndex")==0 &&
            (p->FControlType==CT_COMBOBOX || p->FControlType==CT_LISTBOX) )
      hb_retni( ((HBComboBox *)p)->FItemIndex );
   else if( strcasecmp(szProp,"aItems")==0 &&
            (p->FControlType==CT_COMBOBOX || p->FControlType==CT_LISTBOX) )
   {
      HBComboBox * cb = (HBComboBox *)p;
      char szAll[4096] = "";
      for( int ci = 0; ci < cb->FItemCount; ci++ ) {
         if( ci > 0 ) strcat( szAll, "|" );
         strncat( szAll, cb->FItems[ci], sizeof(szAll) - strlen(szAll) - 1 );
      }
      hb_retc( szAll );
   }
   else if( strcasecmp(szProp,"aMenuItems")==0 && p->FControlType==CT_MAINMENU )
   {
      HBMainMenu * m = (HBMainMenu *)p;
      char szSerial[4096] = "";
      int pos = 0;
      for( int i = 0; i < m->FNodeCount && pos < (int)sizeof(szSerial)-64; i++ ) {
         if( i > 0 ) szSerial[pos++] = '|';
         const char * cap = m->FNodes[i].bSeparator ? "---" : m->FNodes[i].szCaption;
         int n = snprintf( szSerial+pos, sizeof(szSerial)-pos,
            "%s\x01%s\x01%s\x01%d\x01%d\x01%d",
            cap,
            m->FNodes[i].szShortcut,
            m->FNodes[i].szHandler,
            m->FNodes[i].bEnabled,
            m->FNodes[i].nLevel,
            m->FNodes[i].nParent );
         if( n>0 ) pos+=n;
      }
      hb_retc( szSerial );
   }
   else if( strcasecmp(szProp,"cDataSource")==0 &&
            ( p->FControlType==CT_BROWSE || p->FControlType==CT_DBGRID ) )
      hb_retc( ((HBBrowse *)p)->FDataSourceName );
   else if( strcasecmp(szProp,"cUrl")==0 && p->FControlType==CT_WEBVIEW )
      hb_retc( ((HBWebView *)p)->FUrl );
   else if( strcasecmp(szProp,"aColumns")==0 && p->FControlType==CT_BROWSE )
   {
      /* Return pipe-separated column titles */
      HBBrowse * br = (HBBrowse *)p;
      char szCols[1024] = "";
      for( int ci = 0; ci < br->FColumnCount; ci++ ) {
         if( ci > 0 ) strcat( szCols, "|" );
         strncat( szCols, br->FCols[ci].szTitle, sizeof(szCols) - strlen(szCols) - 1 );
      }
      hb_retc( szCols );
   }
   else if( strcasecmp(szProp,"cAppTitle")==0 && p->FControlType == CT_FORM )
      hb_retc( ((HBForm *)p)->FAppTitle );
   else if( strcasecmp(szProp,"aTabs")==0 && p->FControlType == CT_TABCONTROL2 )
      hb_retc( ((HBTabControl2 *)p)->FTabs );
   else if( strcasecmp(szProp,"nClrPane")==0 )   hb_retnint( (HB_MAXINT)p->FClrPane );
   else if( strcasecmp(szProp,"nClrText")==0 )   hb_retnint( (HB_MAXINT)p->FClrText );
   else if( strcasecmp(szProp,"lTransparent")==0 ) hb_retl( p->FTransparent );
   else if( strcasecmp(szProp,"nAlign")==0 )     hb_retni( p->FAlign );
   else if( strcasecmp(szProp,"oFont")==0 )
   {
      /* Convert Pango format "Sans 12" to "Sans,12" */
      char szFont[256];
      const char * desc = p->FFontDesc;
      /* Find last space (before size) */
      const char * lastSpace = strrchr( desc, ' ' );
      if( lastSpace )
      {
         int len = (int)(lastSpace - desc);
         snprintf( szFont, sizeof(szFont), "%.*s,%s", len, desc, lastSpace + 1 );
      }
      else
         snprintf( szFont, sizeof(szFont), "%s,12", desc );
      hb_retc( szFont );
   }
   else if( strcasecmp(szProp,"cFontName")==0 )
   {
      char szFace[64];
      const char * lastSpace = strrchr( p->FFontDesc, ' ' );
      if( lastSpace ) {
         int len = (int)(lastSpace - p->FFontDesc); if( len > 63 ) len = 63;
         memcpy( szFace, p->FFontDesc, len ); szFace[len] = 0;
      } else strcpy( szFace, "Sans" );
      hb_retc( szFace );
   }
   else if( strcasecmp(szProp,"nFontSize")==0 )
   {
      const char * lastSpace = strrchr( p->FFontDesc, ' ' );
      hb_retni( lastSpace ? atoi( lastSpace + 1 ) : 12 );
   }
   else hb_ret();
}

/* --- Events --- */

HB_FUNC( UI_ONEVENT )
{
   HBControl * p = GetCtrl(1);
   const char * ev = hb_parc(2);
   PHB_ITEM blk = hb_param(3, HB_IT_BLOCK);
   if( p && ev && blk ) HBControl_SetEvent( p, ev, blk );
}

/* --- ComboBox --- */

HB_FUNC( UI_COMBOADDITEM )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   if( p && p->base.FControlType == CT_COMBOBOX && HB_ISCHAR(2) )
   {
      if( p->FItemCount < 32 )
         strncpy( p->FItems[p->FItemCount++], hb_parc(2), 63 );
      if( p->base.FWidget )
         gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(p->base.FWidget), hb_parc(2) );
   }
}

HB_FUNC( UI_COMBOSETINDEX )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   if( p && p->base.FControlType == CT_COMBOBOX )
   {
      p->FItemIndex = hb_parni(2);
      if( p->base.FWidget && p->FItemIndex >= 0 )
         gtk_combo_box_set_active( GTK_COMBO_BOX(p->base.FWidget), p->FItemIndex );
   }
}

HB_FUNC( UI_COMBOGETITEM )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   int n = hb_parni(2) - 1;
   if( p && p->base.FControlType == CT_COMBOBOX && n >= 0 && n < p->FItemCount )
      hb_retc( p->FItems[n] );
   else
      hb_retc( "" );
}

HB_FUNC( UI_COMBOGETCOUNT )
{
   HBComboBox * p = (HBComboBox *)GetCtrl(1);
   hb_retni( p && p->base.FControlType == CT_COMBOBOX ? p->FItemCount : 0 );
}

/* --- Children --- */

HB_FUNC( UI_GETCHILDCOUNT ) { HBControl * p = GetCtrl(1); hb_retni( p ? p->FChildCount : 0 ); }

HB_FUNC( UI_GETCHILD )
{
   HBControl * p = GetCtrl(1); int n = hb_parni(2) - 1;
   if( p && n >= 0 && n < p->FChildCount )
      hb_retnint( (HB_PTRUINT) p->FChildren[n] );
   else
      hb_retnint( 0 );
}

HB_FUNC( UI_GETTYPE ) { HBControl * p = GetCtrl(1); hb_retni( p ? p->FControlType : -1 ); }

/* --- Introspection --- */

HB_FUNC( UI_GETPROPCOUNT )
{
   HBControl * p = GetCtrl(1); int n = 0;
   if( p ) {
      n = 8;
      switch( p->FControlType ) {
         case CT_BUTTON: n += 2; break; case CT_CHECKBOX: n += 1; break;
         case CT_EDIT: n += 2; break; case CT_COMBOBOX: n += 2; break;
      }
   }
   hb_retni( n );
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

   /* Font property - convert Pango to "FontName,Size" format */
   {
      char sf[256];
      const char * lastSpace = strrchr( p->FFontDesc, ' ' );
      if( lastSpace )
         snprintf( sf, sizeof(sf), "%.*s,%s", (int)(lastSpace - p->FFontDesc), p->FFontDesc, lastSpace + 1 );
      else
         snprintf( sf, sizeof(sf), "%s,12", p->FFontDesc );
      ADD_F("oFont",sf,"Appearance");
   }
   ADD_C("nClrPane",p->FClrPane,"Appearance");
   if( p->FControlType == CT_LABEL || p->FControlType == CT_EDIT ||
       p->FControlType == CT_MASKEDIT2 || p->FControlType == CT_LABELEDEDIT ||
       p->FControlType == CT_STATICTEXT )
   {
      ADD_C("nClrText",p->FClrText,"Appearance");
      ADD_N("nAlign",p->FAlign,"Appearance");
   }
   if( p->FControlType == CT_LABEL )
   {
      ADD_L("lTransparent",p->FTransparent,"Appearance");
   }

   switch( p->FControlType ) {
      case CT_FORM: {
         HBForm * f = (HBForm *)p;
         ADD_N("nBorderStyle",f->FBorderStyle,"Appearance");
         ADD_N("nBorderIcons",f->FBorderIcons,"Appearance");
         ADD_N("nBorderWidth",f->FBorderWidth,"Appearance");
         ADD_N("nPosition",f->FPosition,"Position");
         ADD_N("nWindowState",f->FWindowState,"Appearance");
         ADD_N("nFormStyle",f->FFormStyle,"Appearance");
         ADD_L("lKeyPreview",f->FKeyPreview,"Behavior");
         ADD_L("lAlphaBlend",f->FAlphaBlend,"Appearance");
         ADD_N("nAlphaBlendValue",f->FAlphaBlendValue,"Appearance");
         ADD_N("nCursor",f->FCursor,"Appearance");
         ADD_L("lShowHint",f->FShowHint,"Behavior");
         ADD_S("cHint",f->FHint,"Behavior");
         ADD_L("lAutoScroll",f->FAutoScroll,"Behavior");
         ADD_L("lDoubleBuffered",f->FDoubleBuffered,"Behavior");
         ADD_S("cAppTitle",f->FAppTitle,"Info");
         /* Read-only: client area */
         int cw = f->base.FWidth, ch = f->base.FHeight;
         if( f->FWindow ) gtk_window_get_size(GTK_WINDOW(f->FWindow),&cw,&ch);
         ADD_N("nClientWidth",cw,"Position");
         ADD_N("nClientHeight",ch,"Position");
         break;
      }
      case CT_BUTTON:
         ADD_L("lDefault",((HBButton*)p)->FDefault,"Behavior");
         ADD_L("lCancel",((HBButton*)p)->FCancel,"Behavior"); break;
      case CT_CHECKBOX: ADD_L("lChecked",((HBCheckBox*)p)->FChecked,"Data"); break;
      case CT_EDIT:
         ADD_L("lReadOnly",((HBEdit*)p)->FReadOnly,"Behavior");
         ADD_L("lPassword",((HBEdit*)p)->FPassword,"Behavior"); break;
      case CT_COMBOBOX:
      case CT_LISTBOX:
      {
         HBComboBox * cb = (HBComboBox *)p;
         char szAll[4096] = ""; int ci;
         for( ci = 0; ci < cb->FItemCount; ci++ ) {
            if( ci > 0 ) strcat( szAll, "|" );
            strncat( szAll, cb->FItems[ci], sizeof(szAll) - strlen(szAll) - 1 );
         }
         pRow = hb_itemArrayNew(4);
         hb_arraySetC( pRow, 1, "aItems" );
         hb_arraySetC( pRow, 2, szAll );
         hb_arraySetC( pRow, 3, "Data" );
         hb_arraySetC( pRow, 4, "A" );
         hb_arrayAdd( pArray, pRow );
         hb_itemRelease( pRow );
         ADD_N("nItemIndex", cb->FItemIndex, "Data");
         break;
      }
      case CT_RADIO:
         ADD_L("lChecked",((HBRadioButton*)p)->FChecked,"Data");
         ADD_S("cGroupName",((HBRadioButton*)p)->FGroupName,"Behavior");
         break;
      case CT_BITBTN: {
         HBBitBtn * bb = (HBBitBtn*)p;
         ADD_S("cGlyph",bb->FGlyph,"Appearance");
         ADD_N("nLayout",bb->FLayout,"Appearance");
         ADD_N("nSpacing",bb->FSpacing,"Appearance");
         break;
      }
      case CT_IMAGE: {
         HBImage * img = (HBImage*)p;
         ADD_S("cPicture",img->FPicture,"Data");
         ADD_L("lStretch",img->FStretch,"Appearance");
         ADD_L("lCenter",img->FCenter,"Appearance");
         ADD_L("lProportional",img->FProportional,"Appearance");
         break;
      }
      case CT_SHAPE: {
         HBShape * sh = (HBShape*)p;
         ADD_N("nShape",sh->FShape,"Appearance");
         ADD_C("nPenColor",sh->FPenColor,"Appearance");
         ADD_N("nPenWidth",sh->FPenWidth,"Appearance");
         ADD_C("nBrushColor",sh->FBrushColor,"Appearance");
         break;
      }
      case CT_BEVEL: {
         HBBevel * bv = (HBBevel*)p;
         ADD_N("nBevelStyle",bv->FBevelStyle,"Appearance");
         ADD_N("nBevelShape",bv->FBevelShape,"Appearance");
         break;
      }
      case CT_RICHEDIT: {
         HBRichEdit * re = (HBRichEdit*)p;
         ADD_L("lReadOnly",re->FReadOnly,"Behavior");
         ADD_L("lWordWrap",re->FWordWrap,"Behavior");
         ADD_N("nScrollBars",re->FScrollBars,"Appearance");
         break;
      }
      case CT_LISTVIEW: {
         HBListView * lv = (HBListView*)p;
         ADD_N("nViewStyle",lv->FViewStyle,"Appearance");
         ADD_L("lGridLines",lv->FGridLines,"Appearance");
         ADD_N("nColumnCount",lv->FColumnCount,"Data");
         break;
      }
      case CT_TABCONTROL2: {
         pRow = hb_itemArrayNew(4);
         hb_arraySetC( pRow, 1, "aTabs" );
         hb_arraySetC( pRow, 2, ((HBTabControl2*)p)->FTabs );
         hb_arraySetC( pRow, 3, "Behavior" );
         hb_arraySetC( pRow, 4, "A" );
         hb_arrayAdd( pArray, pRow );
         hb_itemRelease( pRow );
         break;
      }
      case CT_BROWSE: {
         HBBrowse * br = (HBBrowse*)p;
         ADD_L("lReadOnly",br->FReadOnly,"Behavior");
         ADD_L("lGridLines",br->FGridLines,"Appearance");
         ADD_N("nRowHeight",br->FRowHeight,"Appearance");
         /* aColumns as "|"-separated string from column titles */
         {
            char szCols[1024] = "";
            int ci;
            for( ci = 0; ci < br->FColumnCount; ci++ ) {
               if( ci > 0 ) strcat( szCols, "|" );
               strncat( szCols, br->FCols[ci].szTitle, sizeof(szCols) - strlen(szCols) - 1 );
            }
            pRow = hb_itemArrayNew(4);
            hb_arraySetC( pRow, 1, "aColumns" );
            hb_arraySetC( pRow, 2, szCols );
            hb_arraySetC( pRow, 3, "Data" );
            hb_arraySetC( pRow, 4, "A" );
            hb_arrayAdd( pArray, pRow );
            hb_itemRelease( pRow );
         }
         ADD_S("cDataSource",br->FDataSourceName,"Data");
         break;
      }
      case CT_MAINMENU:
      {
         HBMainMenu * m = (HBMainMenu *)p;
         char szSerial[4096] = "";
         int pos = 0;
         for( int i = 0; i < m->FNodeCount && pos < (int)sizeof(szSerial) - 64; i++ ) {
            if( i > 0 ) szSerial[pos++] = '|';
            const char * cap = m->FNodes[i].bSeparator ? "---" : m->FNodes[i].szCaption;
            int n = snprintf( szSerial + pos, sizeof(szSerial) - pos,
               "%s\x01%s\x01%s\x01%d\x01%d\x01%d",
               cap,
               m->FNodes[i].szShortcut,
               m->FNodes[i].szHandler,
               m->FNodes[i].bEnabled,
               m->FNodes[i].nLevel,
               m->FNodes[i].nParent );
            if( n > 0 ) pos += n;
         }
         pRow = hb_itemArrayNew(4);
         hb_arraySetC( pRow, 1, "aMenuItems" );
         hb_arraySetC( pRow, 2, szSerial );
         hb_arraySetC( pRow, 3, "Data" );
         hb_arraySetC( pRow, 4, "M" );
         hb_arrayAdd( pArray, pRow );
         hb_itemRelease( pRow );
         break;
      }
      case CT_TIMER:
         ADD_N("nInterval",((HBTimer*)p)->FInterval,"Behavior");
         break;
      case CT_WEBVIEW:
         ADD_S("cUrl",((HBWebView*)p)->FUrl,"Data");
         break;
   }
   hb_itemReturnRelease( pArray );

   #undef ADD_S
   #undef ADD_N
   #undef ADD_L
   #undef ADD_C
   #undef ADD_F
}

/* --- JSON --- */

HB_FUNC( UI_FORMTOJSON )
{
   HBForm * pForm = GetForm(1);
   char buf[16384], tmp[512]; int pos = 0;
   if( !pForm ) { hb_retc("{}"); return; }
   #define ADDC(s) { int l=(int)strlen(s); if(pos+l<(int)sizeof(buf)-1){strcpy(buf+pos,s);pos+=l;} }
   ADDC("{\"class\":\"Form\"")
   sprintf(tmp,",\"w\":%d,\"h\":%d",pForm->base.FWidth,pForm->base.FHeight); ADDC(tmp)
   sprintf(tmp,",\"text\":\"%s\"",pForm->base.FText); ADDC(tmp)
   ADDC(",\"children\":[")
   for( int i = 0; i < pForm->base.FChildCount; i++ ) {
      HBControl * p = pForm->base.FChildren[i];
      if( i > 0 ) ADDC(",")
      ADDC("{")
      sprintf(tmp,"\"type\":%d,\"name\":\"%s\"",p->FControlType,p->FName); ADDC(tmp)
      sprintf(tmp,",\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d",p->FLeft,p->FTop,p->FWidth,p->FHeight); ADDC(tmp)
      sprintf(tmp,",\"text\":\"%s\"",p->FText); ADDC(tmp)
      if( p->FControlType==CT_BUTTON ) {
         sprintf(tmp,",\"default\":%s,\"cancel\":%s",((HBButton*)p)->FDefault?"true":"false",((HBButton*)p)->FCancel?"true":"false"); ADDC(tmp) }
      if( p->FControlType==CT_CHECKBOX ) {
         sprintf(tmp,",\"checked\":%s",((HBCheckBox*)p)->FChecked?"true":"false"); ADDC(tmp) }
      if( p->FControlType==CT_COMBOBOX || p->FControlType==CT_LISTBOX ) {
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
   HBToolBar * p = (HBToolBar *) calloc( 1, sizeof(HBToolBar) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TToolBar" );
   p->base.FControlType = CT_TOOLBAR;
   p->FBtnCount = 0;
   p->FToolBarWidget = NULL;
   memset( p->FBtnOnClick, 0, sizeof(p->FBtnOnClick) );
   memset( p->FBtnSeparator, 0, sizeof(p->FBtnSeparator) );
   KeepAlive( &p->base );
   if( pForm && pForm->FToolBarCount < 4 ) {
      pForm->FToolBars[pForm->FToolBarCount] = &p->base;
      pForm->FToolBarCount++;
      p->base.FCtrlParent = &pForm->base;
   }
   RetCtrl( &p->base );
}

HB_FUNC( UI_TOOLBTNADD )
{
   HBToolBar * p = (HBToolBar *) GetCtrl(1);
   if( !p || p->base.FControlType != CT_TOOLBAR || p->FBtnCount >= MAX_TOOLBTNS )
      { hb_retni(-1); return; }
   int idx = p->FBtnCount++;
   strncpy( p->FBtnTexts[idx], hb_parc(2), 31 ); p->FBtnTexts[idx][31] = 0;
   strncpy( p->FBtnTooltips[idx], HB_ISCHAR(3)?hb_parc(3):"", 127 ); p->FBtnTooltips[idx][127] = 0;
   p->FBtnSeparator[idx] = 0;
   p->FBtnOnClick[idx] = NULL;
   hb_retni( idx );
}

HB_FUNC( UI_TOOLBTNADDSEP )
{
   HBToolBar * p = (HBToolBar *) GetCtrl(1);
   if( !p || p->base.FControlType != CT_TOOLBAR || p->FBtnCount >= MAX_TOOLBTNS ) return;
   int idx = p->FBtnCount++;
   p->FBtnSeparator[idx] = 1;
   p->FBtnTexts[idx][0] = 0;
   p->FBtnTooltips[idx][0] = 0;
   p->FBtnOnClick[idx] = NULL;
}

HB_FUNC( UI_TOOLBTNONCLICK )
{
   HBToolBar * p = (HBToolBar *) GetCtrl(1);
   int nIdx = hb_parni(2);
   PHB_ITEM pBlock = hb_param(3, HB_IT_BLOCK);
   if( p && p->base.FControlType == CT_TOOLBAR && pBlock && nIdx >= 0 && nIdx < p->FBtnCount )
   {
      if( p->FBtnOnClick[nIdx] ) hb_itemRelease( p->FBtnOnClick[nIdx] );
      p->FBtnOnClick[nIdx] = hb_itemNew( pBlock );
   }
}

/* ======================================================================
 * TMainMenu runtime attach
 * ====================================================================== */

/* Parse "Ctrl+N", "Alt+F4", "Shift+F5" → modifier + keyval */
static void ParseShortcut( const char * sz, GdkModifierType * mod, guint * key )
{
   *mod = 0; *key = 0;
   if( !sz || !sz[0] ) return;
   char buf[64]; strncpy(buf,sz,63); buf[63]=0;
   char * plus = strrchr(buf,'+');
   const char * keyPart = plus ? plus+1 : buf;
   if( plus ) *plus = 0;
   if( strcasestr(buf,"Ctrl")  ) *mod |= GDK_CONTROL_MASK;
   if( strcasestr(buf,"Alt")   ) *mod |= GDK_MOD1_MASK;
   if( strcasestr(buf,"Shift") ) *mod |= GDK_SHIFT_MASK;
   if( strlen(keyPart)==1 )
      *key = gdk_unicode_to_keyval((guint32)(unsigned char)keyPart[0]);
   else
      *key = gdk_keyval_from_name(keyPart);
}

typedef struct {
   char         szHandler[128];
   HBMainMenu * pMenu;
   int          nNodeIdx;
} HBMenuCBData;

static void on_mainmenu_item_activated( GtkMenuItem * item, gpointer data )
{
   (void)item;
   HBMenuCBData * cbd = (HBMenuCBData *)data;
   if( !cbd ) return;

   /* Preferred path: evaluate the Harbour codeblock (captures Self) */
   if( cbd->pMenu && cbd->pMenu->FOnClickArray )
   {
      HB_SIZE nIdx = (HB_SIZE)(cbd->nNodeIdx + 1);
      if( nIdx >= 1 && nIdx <= hb_arrayLen( cbd->pMenu->FOnClickArray ) )
      {
         PHB_ITEM pBlock = hb_arrayGetItemPtr( cbd->pMenu->FOnClickArray, nIdx );
         if( pBlock && HB_IS_BLOCK( pBlock ) )
         {
            hb_vmPushEvalSym();
            hb_vmPush( pBlock );
            hb_vmSend( 0 );
            return;
         }
      }
   }

   /* Fallback: call handler by name with no args */
   if( !cbd->szHandler[0] ) return;
   char sym[128]; int i;
   for(i=0;cbd->szHandler[i]&&i<127;i++) sym[i]=(char)toupper((unsigned char)cbd->szHandler[i]);
   sym[i]=0;
   PHB_DYNS pDyn = hb_dynsymFindName(sym);
   if(pDyn){ hb_vmPushDynSym(pDyn); hb_vmPushNil(); hb_vmDo(0); }
}

/* Convert Windows-style "&File" mnemonics to GTK "_File" form.
 * "&&" collapses to a literal "&"; existing "_" gets doubled so it renders
 * as a literal underscore rather than a stray mnemonic marker.            */
static void hb_amp_to_gtk_mnemonic( const char * src, char * dst, size_t dstSz )
{
   size_t j = 0;
   if( !dst || dstSz == 0 ) return;
   if( !src ) { dst[0] = 0; return; }
   for( size_t i = 0; src[i] && j + 1 < dstSz; i++ )
   {
      if( src[i] == '&' )
      {
         if( src[i+1] == '&' ) { dst[j++] = '&'; i++; }
         else                  { dst[j++] = '_'; }
      }
      else if( src[i] == '_' )
      {
         if( j + 2 >= dstSz ) break;
         dst[j++] = '_'; dst[j++] = '_';
      }
      else
      {
         dst[j++] = src[i];
      }
   }
   dst[j] = 0;
}

static void HBMainMenu_Attach( HBControl * p, HBForm * form )
{
   HBMainMenu * m = (HBMainMenu *)p;
   if( m->FNodeCount == 0 ) return;

   if( !form->FMenuBar )
      form->FMenuBar = gtk_menu_bar_new();

   /* Level stack: popupShells[0] = menubar shell, [1] = level-1 popup, etc. */
   GtkWidget * popupShells[8] = {0};
   popupShells[0] = form->FMenuBar;

   if( !s_accelGroup ) {
      s_accelGroup = gtk_accel_group_new();
      if( form->FWindow )
         gtk_window_add_accel_group( GTK_WINDOW(form->FWindow), s_accelGroup );
   }

   for( int i = 0; i < m->FNodeCount; i++ )
   {
      HBMenuNode * n = &m->FNodes[i];
      int lv = n->nLevel;

      if( n->bSeparator )
      {
         GtkWidget * parentShell = (lv >= 1 && lv <= 7 && popupShells[lv]) ? popupShells[lv] : popupShells[1];
         if( parentShell ) {
            GtkWidget * sep = gtk_separator_menu_item_new();
            gtk_menu_shell_append( GTK_MENU_SHELL(parentShell), sep );
         }
      }
      else if( lv == 0 )
      {
         /* Root popup: attaches to the menu bar */
         char gtkLabel[256]; hb_amp_to_gtk_mnemonic( n->szCaption, gtkLabel, sizeof gtkLabel );
         GtkWidget * mi = gtk_menu_item_new_with_mnemonic( gtkLabel );
         GtkWidget * sub = gtk_menu_new();
         gtk_menu_item_set_submenu( GTK_MENU_ITEM(mi), sub );
         gtk_menu_shell_append( GTK_MENU_SHELL(form->FMenuBar), mi );
         popupShells[1] = sub;
         for(int lv2=2;lv2<8;lv2++) popupShells[lv2]=NULL;
      }
      else
      {
         /* Determine if this node itself has children (lookahead) */
         int hasChildren = ( i+1 < m->FNodeCount && m->FNodes[i+1].nLevel > lv );
         GtkWidget * parentShell = (lv >= 1 && lv <= 7 && popupShells[lv]) ? popupShells[lv] : NULL;
         if( !parentShell ) continue;

         if( hasChildren )
         {
            /* Sub-popup */
            char gtkLabel[256]; hb_amp_to_gtk_mnemonic( n->szCaption, gtkLabel, sizeof gtkLabel );
            GtkWidget * mi = gtk_menu_item_new_with_mnemonic( gtkLabel );
            GtkWidget * sub = gtk_menu_new();
            gtk_menu_item_set_submenu( GTK_MENU_ITEM(mi), sub );
            gtk_menu_shell_append( GTK_MENU_SHELL(parentShell), mi );
            if( lv+1 < 8 ) popupShells[lv+1] = sub;
            for(int lv2=lv+2;lv2<8;lv2++) popupShells[lv2]=NULL;
         }
         else
         {
            /* Leaf item */
            char gtkLabel[256]; hb_amp_to_gtk_mnemonic( n->szCaption, gtkLabel, sizeof gtkLabel );
            GtkWidget * mi = gtk_menu_item_new_with_mnemonic( gtkLabel );
            if( !n->bEnabled )
               gtk_widget_set_sensitive( mi, FALSE );

            if( n->szHandler[0] || m->FOnClickArray ) {
               HBMenuCBData * cbd = (HBMenuCBData *)malloc(sizeof(HBMenuCBData));
               strncpy( cbd->szHandler, n->szHandler, 127 );
               cbd->pMenu     = m;
               cbd->nNodeIdx  = i;
               g_signal_connect_data( mi, "activate",
                  G_CALLBACK(on_mainmenu_item_activated), cbd,
                  (GClosureNotify)free, 0 );
            }

            if( n->szShortcut[0] ) {
               GdkModifierType mod; guint key;
               ParseShortcut( n->szShortcut, &mod, &key );
               if( key ) {
                  if(!s_accelGroup){ s_accelGroup=gtk_accel_group_new();
                     if(form->FWindow) gtk_window_add_accel_group(GTK_WINDOW(form->FWindow),s_accelGroup); }
                  gtk_widget_add_accelerator(mi,"activate",s_accelGroup,key,mod,GTK_ACCEL_VISIBLE);
               }
            }

            gtk_menu_shell_append( GTK_MENU_SHELL(parentShell), mi );
         }
      }
   }
}

/* ======================================================================
 * Menu bridge
 * ====================================================================== */

HB_FUNC( UI_MENUBARCREATE )
{
   HBForm * p = GetForm(1);
   EnsureGTK();
   if( p && !p->FMenuBar )
      p->FMenuBar = gtk_menu_bar_new();
}

HB_FUNC( UI_MENUPOPUPADD )
{
   HBForm * p = GetForm(1);
   EnsureGTK();
   if( !p || !HB_ISCHAR(2) ) { hb_retnint(0); return; }
   if( !p->FMenuBar ) p->FMenuBar = gtk_menu_bar_new();

   char gtkLabel[256]; hb_amp_to_gtk_mnemonic( hb_parc(2), gtkLabel, sizeof gtkLabel );
   GtkWidget * menuItem = gtk_menu_item_new_with_mnemonic( gtkLabel );
   GtkWidget * subMenu = gtk_menu_new();
   gtk_menu_item_set_submenu( GTK_MENU_ITEM(menuItem), subMenu );
   gtk_menu_shell_append( GTK_MENU_SHELL(p->FMenuBar), menuItem );
   hb_retnint( (HB_PTRUINT) subMenu );
}

HB_FUNC( UI_MENUITEMADD ) { hb_retni( -1 ); } /* stub */

HB_FUNC( UI_MENUITEMADDEX )
{
   HBForm * pForm = GetForm(1);
   GtkWidget * popup = (GtkWidget *)(HB_PTRUINT)hb_parnint(2);
   PHB_ITEM pBlock = hb_param(4, HB_IT_BLOCK);
   EnsureGTK();

   if( !pForm || !popup || !HB_ISCHAR(3) ) { hb_retni(-1); return; }

   /* Convert & mnemonic to _ for GTK */
   const char * text = hb_parc(3);
   char label[128]; int j = 0;
   for( int i = 0; text[i] && j < 126; i++ )
      label[j++] = (text[i] == '&') ? '_' : text[i];
   label[j] = 0;

   GtkWidget * item = gtk_menu_item_new_with_mnemonic( label );
   PHB_ITEM pCopy = pBlock ? hb_itemNew(pBlock) : NULL;
   if( pCopy )
      g_signal_connect( item, "activate", G_CALLBACK(on_menu_item_activated), pCopy );

   /* Keyboard accelerator (Ctrl+key) */
   if( HB_ISCHAR(5) && hb_parclen(5) == 1 )
   {
      const char * accel = hb_parc(5);
      guint key = gdk_unicode_to_keyval( (guint32) accel[0] );

      if( !s_accelGroup )
      {
         s_accelGroup = gtk_accel_group_new();
         if( pForm->FWindow )
            gtk_window_add_accel_group( GTK_WINDOW(pForm->FWindow), s_accelGroup );
      }
      gtk_widget_add_accelerator( item, "activate", s_accelGroup,
         key, GDK_CONTROL_MASK, GTK_ACCEL_VISIBLE );
   }

   gtk_menu_shell_append( GTK_MENU_SHELL(popup), item );

   int idx = pForm->FMenuItemCount++;
   if( pCopy ) pForm->FMenuActions[idx] = pCopy;
   hb_retni( idx );
}

HB_FUNC( UI_MENUSEPADD )
{
   GtkWidget * popup = (GtkWidget *)(HB_PTRUINT)hb_parnint(2);
   EnsureGTK();
   if( popup ) {
      GtkWidget * sep = gtk_separator_menu_item_new();
      gtk_menu_shell_append( GTK_MENU_SHELL(popup), sep );
   }
}

/* UI_MenuSetBitmapByPos( hPopup, nPos, cPngPath ) — set 16x16 icon on menu item */
HB_FUNC( UI_MENUSETBITMAPBYPOS )
{
   GtkWidget * popup = (GtkWidget *)(HB_PTRUINT) hb_parnint(1);
   int nPos = hb_parni(2);
   const char * szPath = hb_parc(3);

   if( !popup || !szPath ) return;

   /* Get the menu item at position nPos */
   GList * children = gtk_container_get_children( GTK_CONTAINER(popup) );
   GtkWidget * item = (GtkWidget *) g_list_nth_data( children, nPos );
   g_list_free( children );

   if( !item || !GTK_IS_MENU_ITEM(item) ) return;

   /* Load the PNG as a 16x16 pixbuf */
   GdkPixbuf * pb = gdk_pixbuf_new_from_file( szPath, NULL );
   if( !pb ) return;
   GdkPixbuf * scaled = gdk_pixbuf_scale_simple( pb, 16, 16, GDK_INTERP_BILINEAR );
   g_object_unref( pb );
   if( !scaled ) return;

   GtkWidget * img = gtk_image_new_from_pixbuf( scaled );
   g_object_unref( scaled );

   /* Copy the label text BEFORE removing the child (it gets destroyed) */
   const char * label = gtk_menu_item_get_label( GTK_MENU_ITEM(item) );
   char labelCopy[256];
   if( label )
      strncpy( labelCopy, label, 255 );
   else
      labelCopy[0] = 0;
   labelCopy[255] = 0;

   /* Replace contents: remove old child, add hbox with image + label */
   GtkWidget * oldChild = gtk_bin_get_child( GTK_BIN(item) );
   if( oldChild )
      gtk_container_remove( GTK_CONTAINER(item), oldChild );

   GtkWidget * hbox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 6 );
   gtk_box_pack_start( GTK_BOX(hbox), img, FALSE, FALSE, 0 );

   GtkWidget * lbl = gtk_label_new_with_mnemonic( labelCopy );
   gtk_label_set_xalign( GTK_LABEL(lbl), 0.0 );
   gtk_box_pack_start( GTK_BOX(hbox), lbl, TRUE, TRUE, 0 );

   gtk_container_add( GTK_CONTAINER(item), hbox );
   gtk_widget_show_all( hbox );
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
   HBForm * p = GetForm(1);
   hb_retnint( p ? (HB_PTRUINT) p : 0 );
}

/* ======================================================================
 * Component Palette (GTK3 - GtkNotebook with buttons)
 * ====================================================================== */

static void PalShowTab( PALDATA * pd, int nTab )
{
   if( !pd || nTab < 0 || nTab >= pd->nTabCount ) return;
   pd->nCurrentTab = nTab;
   gtk_notebook_set_current_page( GTK_NOTEBOOK(pd->notebook), nTab );
}

HB_FUNC( UI_PALETTENEW )
{
   HBForm * pForm = GetForm(1);
   if( !pForm ) { hb_retnint(0); return; }

   PALDATA * pd = (PALDATA *) calloc( 1, sizeof(PALDATA) );
   pd->parentForm = pForm;
   s_palData = pd;

   EnsureGTK();
   pd->notebook = gtk_notebook_new();
   gtk_notebook_set_tab_pos( GTK_NOTEBOOK(pd->notebook), GTK_POS_TOP );

   HBControl * p = (HBControl *) calloc( 1, sizeof(HBControl) );
   HBControl_Init( p );
   strcpy( p->FClassName, "TComponentPalette" );
   p->FControlType = CT_TABCONTROL;
   KeepAlive( p );
   RetCtrl( p );
}

HB_FUNC( UI_PALETTEADDTAB )
{
   PALDATA * pd = s_palData;
   if( pd && pd->nTabCount < MAX_PALETTE_TABS && HB_ISCHAR(2) ) {
      int idx = pd->nTabCount++;
      strncpy( pd->tabs[idx].szName, hb_parc(2), 31 );
      pd->tabs[idx].nBtnCount = 0;

      /* Create a GtkBox for this tab's buttons */
      GtkWidget * box = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 2 );
      gtk_widget_set_margin_start( box, 4 );
      pd->tabBoxes[idx] = box;

      GtkWidget * label = gtk_label_new( pd->tabs[idx].szName );
      gtk_notebook_append_page( GTK_NOTEBOOK(pd->notebook), box, label );
      gtk_widget_show_all( box );

      hb_retni( idx );
   } else
      hb_retni( -1 );
}

static void on_palette_btn_clicked( GtkButton * button, gpointer data )
{
   int nType = GPOINTER_TO_INT( g_object_get_data( G_OBJECT(button), "ctrl_type" ) );

   /* Set pending drop mode on the design form */
   HBForm * targetForm = s_designForm;
   if( targetForm && targetForm->FDesignMode && nType > 0 )
   {
      if( IsNonVisualControl( nType ) )
      {
         /* Non-visual: place at bottom-left of form, advancing right */
         int formH = targetForm->base.FHeight;
         int nL = 8, nT = formH - 36;
         /* Find a free position: scan existing non-visual children */
         for( int i = 0; i < targetForm->base.FChildCount; i++ )
         {
            HBControl * c = targetForm->base.FChildren[i];
            if( IsNonVisualControl( c->FControlType ) )
            {
               if( c->FLeft >= nL && c->FLeft < nL + 32 &&
                   c->FTop >= nT && c->FTop < nT + 32 )
               {
                  nL += 36;
                  if( nL + 28 > targetForm->base.FWidth )
                  {
                     nL = 8;
                     nT -= 36;
                  }
               }
            }
         }

         HBControl * newCtrl = HBForm_CreateControlOfType( targetForm, nType, nL, nT, 28, 28 );

         if( newCtrl && targetForm->FOnComponentDrop && HB_IS_BLOCK( targetForm->FOnComponentDrop ) )
         {
            PHB_ITEM args[6];
            args[0] = hb_itemPutNInt( hb_itemNew(NULL), (HB_PTRUINT) targetForm );
            args[1] = hb_itemPutNI( hb_itemNew(NULL), nType );
            args[2] = hb_itemPutNI( hb_itemNew(NULL), nL );
            args[3] = hb_itemPutNI( hb_itemNew(NULL), nT );
            args[4] = hb_itemPutNI( hb_itemNew(NULL), 28 );
            args[5] = hb_itemPutNI( hb_itemNew(NULL), 28 );
            hb_itemDo( targetForm->FOnComponentDrop, 6, args[0], args[1], args[2], args[3], args[4], args[5] );
            for( int a = 0; a < 6; a++ ) hb_itemRelease( args[a] );
         }

         if( targetForm->FOverlay )
         {
            gtk_widget_queue_draw( targetForm->FOverlay );
            gtk_widget_grab_focus( targetForm->FOverlay );
         }
      }
      else
      {
         /* Visual: enter rubber band mode with crosshair cursor */
         targetForm->FPendingControlType = nType;
         if( targetForm->FWindow )
         {
            GdkCursor * cursor = gdk_cursor_new_from_name(
               gdk_display_get_default(), "crosshair" );
            gdk_window_set_cursor( gtk_widget_get_window(targetForm->FWindow), cursor );
            if( cursor ) g_object_unref( cursor );
         }
      }
   }

   /* Also fire Harbour callback if set */
   PALDATA * pd = s_palData;
   if( pd && pd->pOnSelect && HB_IS_BLOCK(pd->pOnSelect) )
   {
      PHB_ITEM pArg = hb_itemPutNI( hb_itemNew(NULL), nType );
      hb_itemDo( pd->pOnSelect, 1, pArg );
      hb_itemRelease( pArg );
   }
}

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

         /* Create button in the tab's box */
         GtkWidget * btn = gtk_button_new_with_label( t->btns[idx].szText );
         gtk_widget_set_tooltip_text( btn, t->btns[idx].szTooltip );
         g_object_set_data( G_OBJECT(btn), "ctrl_type",
            GINT_TO_POINTER(t->btns[idx].nControlType) );
         g_signal_connect( btn, "clicked", G_CALLBACK(on_palette_btn_clicked), pd );
         gtk_box_pack_start( GTK_BOX(pd->tabBoxes[nTab]), btn, FALSE, FALSE, 1 );
         gtk_widget_show( btn );
      }
   }
}

HB_FUNC( UI_PALETTEONSELECT )
{
   PALDATA * pd = s_palData;
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( pd ) {
      if( pd->pOnSelect ) hb_itemRelease( pd->pOnSelect );
      pd->pOnSelect = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

HB_FUNC( UI_TOOLBARGETWIDTH )
{
   HBToolBar * p = (HBToolBar *) GetCtrl(1);
   if( p && p->base.FControlType == CT_TOOLBAR && p->FToolBarWidget )
   {
      GtkAllocation alloc;
      gtk_widget_get_allocation( p->FToolBarWidget, &alloc );
      hb_retni( alloc.width > 0 ? alloc.width : 200 );
   }
   else
      hb_retni( 200 );
}

/* ======================================================================
 * StatusBar (GTK3 - GtkStatusbar)
 * ====================================================================== */

HB_FUNC( UI_STATUSBARCREATE )
{
   HBForm * pForm = GetForm(1);
   if( !pForm ) return;
   EnsureGTK();

   s_statusBar = gtk_statusbar_new();
   s_statusCtxId = gtk_statusbar_get_context_id( GTK_STATUSBAR(s_statusBar), "ide" );
   /* Will be packed into the form's vbox if window is already created */
   /* For now, store reference - the form's vbox packing happens in HBForm_Run/Show */
}

HB_FUNC( UI_STATUSBARSETTEXT )
{
   if( s_statusBar && HB_ISCHAR(2) )
   {
      gtk_statusbar_pop( GTK_STATUSBAR(s_statusBar), s_statusCtxId );
      gtk_statusbar_push( GTK_STATUSBAR(s_statusBar), s_statusCtxId, hb_parc(2) );
   }
}

/* ======================================================================
 * UI_FormSelectCtrl - programmatic selection from combo
 * ====================================================================== */

HB_FUNC( UI_FORMSELECTCTRL )
{
   HBForm * pForm = GetForm(1);
   HBControl * pCtrl = GetCtrl(2);
   if( pForm && pForm->FDesignMode )
   {
      if( pCtrl && pCtrl != (HBControl *)pForm )
      {
         /* Preserve existing multi-selection if the target is already selected */
         if( HBForm_IsSelected( pForm, pCtrl ) )
            return;
         HBForm_SelectControl( pForm, pCtrl, 0 );
      }
      else
         HBForm_ClearSelection( pForm );
   }
}

HB_FUNC( UI_FORMSETPOS )
{
   HBForm * p = GetForm(1);
   if( p ) {
      p->base.FLeft = hb_parni(2);
      p->base.FTop = hb_parni(3);
      p->FCenter = 0;
      if( p->FWindow )
         gtk_window_move( GTK_WINDOW(p->FWindow), p->base.FLeft, p->base.FTop );
   }
}

/* --- BringToTop --- */

HB_FUNC( GTK_BRINGTOTOP )
{
   HBForm * p = GetForm(1);
   if( p && p->FWindow )
      gtk_window_present( GTK_WINDOW(p->FWindow) );
}

/* --- MsgBox --- */

HB_FUNC( GTK_MSGBOX )
{
   EnsureGTK();
   GtkWidget * dialog = gtk_message_dialog_new( NULL,
      GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
      "%s", hb_parc(1) ? hb_parc(1) : "" );
   gtk_window_set_title( GTK_WINDOW(dialog), hb_parc(2) ? hb_parc(2) : "" );
   gtk_dialog_run( GTK_DIALOG(dialog) );
   gtk_widget_destroy( dialog );
}

/* UI_MsgBox - cross-platform alias */
HB_FUNC( UI_MSGBOX )
{
   EnsureGTK();
   GtkWidget * dialog = gtk_message_dialog_new( NULL,
      GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
      "%s", hb_parc(1) ? hb_parc(1) : "" );
   gtk_window_set_title( GTK_WINDOW(dialog), hb_parc(2) ? hb_parc(2) : "" );
   gtk_dialog_run( GTK_DIALOG(dialog) );
   gtk_widget_destroy( dialog );
}

/* UI_MsgYesNo( cText [, cTitle] ) --> lYes  (.T. if Yes clicked) */
HB_FUNC( UI_MSGYESNO )
{
   EnsureGTK();
   GtkWidget * dialog = gtk_message_dialog_new( NULL,
      GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION, GTK_BUTTONS_YES_NO,
      "%s", hb_parc(1) ? hb_parc(1) : "" );
   gtk_window_set_title( GTK_WINDOW(dialog),
      hb_parc(2) ? hb_parc(2) : "Confirm" );
   gint result = gtk_dialog_run( GTK_DIALOG(dialog) );
   gtk_widget_destroy( dialog );
   hb_retl( result == GTK_RESPONSE_YES );
}

/* ======================================================================
 * Screen geometry
 * ====================================================================== */

HB_FUNC( GTK_GETSCREENWIDTH )
{
   EnsureGTK();
   GdkDisplay * display = gdk_display_get_default();
   GdkMonitor * monitor = gdk_display_get_primary_monitor( display );
   if( !monitor ) monitor = gdk_display_get_monitor( display, 0 );
   GdkRectangle geom;
   gdk_monitor_get_geometry( monitor, &geom );
   hb_retni( geom.width );
}

HB_FUNC( GTK_GETSCREENHEIGHT )
{
   EnsureGTK();
   GdkDisplay * display = gdk_display_get_default();
   GdkMonitor * monitor = gdk_display_get_primary_monitor( display );
   if( !monitor ) monitor = gdk_display_get_monitor( display, 0 );
   GdkRectangle geom;
   gdk_monitor_get_geometry( monitor, &geom );
   hb_retni( geom.height );
}

HB_FUNC( GTK_GETWINDOWBOTTOM )
{
   HBForm * p = GetForm(1);
   if( p && p->FWindow )
   {
      int wx, wy, ww, wh;
      gtk_window_get_position( GTK_WINDOW(p->FWindow), &wx, &wy );
      gtk_window_get_size( GTK_WINDOW(p->FWindow), &ww, &wh );
      hb_retni( wy + wh );
   }
   else
      hb_retni( 0 );
}

/* ======================================================================
 * Code Editor - Scintilla with syntax highlighting and TABS (dark theme)
 * Replaces the GtkTextView-based editor with Scintilla 5.x via GTK widget.
 * ====================================================================== */

#include <dlfcn.h>

#define CE_MAX_TABS  32
#define STATUSBAR_HEIGHT 24

/* Scintilla message defines */
#define SCI_SETTEXT        2181
#define SCI_GETTEXT        2182
#define SCI_GETTEXTLENGTH  2183
#define SCI_ADDTEXT        2001
#define SCI_CLEARALL       2004
#define SCI_GETLENGTH      2006
#define SCI_GETCURRENTPOS  2008
#define SCI_SETSEL         2160
#define SCI_GOTOPOS        2025
#define SCI_GOTOLINE       2024
#define SCI_SCROLLCARET    2169
#define SCI_SETREADONLY    2171
#define SCI_GETREADONLY    2173
#define SCI_REPLACESEL     2170
#define SCI_SEARCHNEXT     2367
#define SCI_SEARCHPREV     2368
#define SCI_SETTARGETSTART 2190
#define SCI_SETTARGETEND   2192
#define SCI_SEARCHINTARGET 2197
#define SCI_REPLACETARGET  2194
#define SCI_GETSELECTIONSTART 2143
#define SCI_GETSELECTIONEND   2145
#define SCI_SETSELECTIONSTART 2142
#define SCI_SETSELECTIONEND   2144
#define SCI_FINDTEXT       2150
#define SCI_GETCHARAT      2007
#define SCI_EMPTYUNDOBUFFER    2175
#define SCI_SETUNDOCOLLECTION  2012
#define SCI_SETSAVEPOINT       2014
#define SCI_SETFOCUS           2380

/* Lexer + Styles */
#define SCI_SETILEXER      4033
#define SCI_SETKEYWORDS    4005
#define SCI_SETPROPERTY    4004
#define SCI_STYLESETFORE   2051
#define SCI_STYLESETBACK   2052
#define SCI_STYLESETBOLD   2053
#define SCI_STYLESETITALIC 2054
#define SCI_STYLESETSIZE   2055
#define SCI_STYLESETFONT   2056
#define SCI_STYLECLEARALL  2050

/* Margin */
#define SCI_SETMARGINTYPEN     2240
#define SCI_SETMARGINWIDTHN    2242
#define SCI_SETMARGINSENSITIVEN 2246
#define SC_MARGIN_NUMBER       1
#define SC_MARGIN_SYMBOL       0

/* Folding */
#define SCI_SETFOLDFLAGS       2233
#define SCI_SETMARGINMASKN     2244
#define SCI_MARKERDEFINE       2040
#define SCI_MARKERSETFORE      2041
#define SCI_MARKERSETBACK      2042
#define SCI_MARKERADD          2043
#define SCI_MARKERDELETE       2044
#define SCI_MARKERDELETEALL    2046
#define SCI_GETFIRSTVISIBLELINE 2152
#define SCI_SETFIRSTVISIBLELINE 2613
#define SC_MARK_CIRCLE         0
#define SC_MARK_BACKGROUND     22
#define SCI_MARKERGET          2035
#define SCI_SETAUTOMATICFOLD   2663
#define SC_AUTOMATICFOLD_SHOW  0x01
#define SC_AUTOMATICFOLD_CLICK 0x02
#define SC_AUTOMATICFOLD_CHANGE 0x04
#define SC_FOLDLEVELBASE       0x400
#define SC_FOLDLEVELHEADERFLAG 0x2000
#define SC_MARKNUM_FOLDEROPEN  31
#define SC_MARKNUM_FOLDER      30
#define SC_MARKNUM_FOLDERSUB   29
#define SC_MARKNUM_FOLDERTAIL  28
#define SC_MARKNUM_FOLDEREND   25
#define SC_MARKNUM_FOLDEROPENMID 26
#define SC_MARKNUM_FOLDERMIDTAIL 27
#define SC_MARK_BOXPLUS         12
#define SC_MARK_BOXMINUS        14
#define SC_MARK_VLINE           9
#define SC_MARK_LCORNER         10
#define SC_MARK_BOXPLUSCONNECTED  13
#define SC_MARK_BOXMINUSCONNECTED 15
#define SC_MARK_TCORNER         11
#define SC_MASK_FOLDERS          0xFE000000

/* Misc */
#define SCI_SETTABWIDTH        2036
#define SCI_SETINDENTATIONGUIDES 2132
#define SC_IV_LOOKBOTH           3
#define SCI_SETVIEWEOL         2356
#define SCI_SETWRAPMODE        2268
#define SCI_SETSELEOLFILLED    2477
#define SCI_SETCARETFORE       2069
#define SCI_SETSELBACK         2068
#define SCI_SETWHITESPACEFORE  2084
#define SCI_SETWHITESPACEBACK  2085
#define SCI_SETEXTRAASCENT     2525
#define SCI_SETEXTRADESCENT    2527
#define SCI_GETCURLINE         2027
#define SCI_LINEFROMPOSITION   2166
#define SCI_POSITIONFROMLINE   2167
#define SCI_GETLINECOUNT       2154
#define SCI_GETLINE            2153
#define SCI_LINELENGTH         2350
#define SCI_SETCODEPAGE        2037
#define SC_CP_UTF8             65001
#define STYLE_DEFAULT          32
#define STYLE_LINENUMBER       33
#define SCI_SETFOLDLEVEL       2222
#define SCI_GETFOLDLEVEL       2223
#define SCI_TOGGLEFOLD         2231
#define SCI_GETCOLUMN          2129
#define SCI_GETOVERTYPE        2187
#define SCI_GETLINEINDENTATION    2127
#define SCI_SETLINEINDENTATION    2126
#define SCI_GETLINEINDENTPOSITION 2128
#define SCI_LINEDUPLICATE      2469
#define SCI_LINEDELETE         2338

/* Auto-complete */
#define SCI_AUTOCSHOW          2100
#define SCI_AUTOCCANCEL        2101
#define SCI_AUTOCACTIVE        2102
#define SCI_AUTOCSETSEPARATOR  2106
#define SCI_AUTOCSETIGNORECASE 2115

/* C/C++ lexer style IDs (used for Harbour too) */
#define SCE_C_DEFAULT          0
#define SCE_C_COMMENT          1
#define SCE_C_COMMENTLINE      2
#define SCE_C_COMMENTDOC       3
#define SCE_C_NUMBER           4
#define SCE_C_WORD             5
#define SCE_C_STRING           6
#define SCE_C_CHARACTER        7
#define SCE_C_PREPROCESSOR     9
#define SCE_C_OPERATOR         10
#define SCE_C_IDENTIFIER       11
#define SCE_C_WORD2            16
#define SCE_C_GLOBALCLASS      19

/* Scintilla notification codes */
#define SCN_CHARADDED     2001
#define SCN_UPDATEUI      2007
#define SCN_MODIFIED      2008
#define SCN_MARGINCLICK   2010

/* Scintilla GTK function types */
typedef void * ILexer5;
typedef ILexer5 * (* CreateLexerFn)(const char * name);

/* GTK Scintilla API function pointers */
typedef GtkWidget * (* ScintillaNewFn)(void);
typedef ssize_t (* ScintillaSendMessageFn)(GtkWidget *, unsigned int, uintptr_t, intptr_t);

static void * s_hScintilla = NULL;
static void * s_hLexilla   = NULL;
static CreateLexerFn         s_pCreateLexer = NULL;
static ScintillaNewFn        s_pScintillaNew = NULL;
static ScintillaSendMessageFn s_pSciSendMsg  = NULL;

/* Helper: send message to Scintilla GTK widget */
static ssize_t SciMsg( GtkWidget * sci, unsigned int msg, uintptr_t wp, intptr_t lp )
{
   if( s_pSciSendMsg && sci )
      return s_pSciSendMsg( sci, msg, wp, lp );
   return 0;
}

/* Helper: pack RGB for Scintilla (0x00BBGGRR on all platforms) */
static int SciRGB( int r, int g, int b )
{
   return r | (g << 8) | (b << 16);
}

/* Initialize Scintilla shared libraries */
static int InitScintilla( void )
{
   char szPath[1024];
   FILE * fLog;

   if( s_hScintilla ) return 1;  /* already loaded */

   fLog = fopen( "/tmp/scintilla_trace.log", "a" );

   /* Try loading from ../resources/ relative to executable */
   {
      ssize_t len = readlink( "/proc/self/exe", szPath, sizeof(szPath) - 1 );
      if( len > 0 ) {
         szPath[len] = 0;
         char * p = strrchr( szPath, '/' );
         if( p ) *p = 0;
      } else {
         strcpy( szPath, "." );
      }
   }

   {
      char libPath[2048];
      snprintf( libPath, sizeof(libPath), "%s/../resources/libscintilla.so", szPath );
      s_hScintilla = dlopen( libPath, RTLD_LAZY );
      if( fLog ) fprintf( fLog, "dlopen Scintilla '%s' => %p\n", libPath, s_hScintilla );
   }

   if( !s_hScintilla ) {
      /* Try resources/ in project root */
      char libPath[2048];
      snprintf( libPath, sizeof(libPath), "%s/resources/libscintilla.so", szPath );
      s_hScintilla = dlopen( libPath, RTLD_LAZY );
      if( fLog ) fprintf( fLog, "dlopen Scintilla '%s' => %p\n", libPath, s_hScintilla );
   }

   if( !s_hScintilla ) {
      /* Try system library path */
      s_hScintilla = dlopen( "libscintilla.so", RTLD_LAZY );
      if( fLog ) fprintf( fLog, "dlopen libscintilla.so (system) => %p\n", s_hScintilla );
   }

   if( !s_hScintilla ) {
      if( fLog ) { fprintf( fLog, "FAILED to load libscintilla.so: %s\n", dlerror() ); fclose( fLog ); }
      return 0;
   }

   /* Get Scintilla GTK API functions */
   s_pScintillaNew = (ScintillaNewFn) dlsym( s_hScintilla, "scintilla_new" );
   s_pSciSendMsg   = (ScintillaSendMessageFn) dlsym( s_hScintilla, "scintilla_send_message" );
   if( fLog ) fprintf( fLog, "scintilla_new => %p, scintilla_send_message => %p\n",
      s_pScintillaNew, s_pSciSendMsg );

   if( !s_pScintillaNew || !s_pSciSendMsg ) {
      if( fLog ) { fprintf( fLog, "FAILED to resolve Scintilla symbols\n" ); fclose( fLog ); }
      dlclose( s_hScintilla ); s_hScintilla = NULL;
      return 0;
   }

   /* Load Lexilla */
   {
      char libPath[2048];
      snprintf( libPath, sizeof(libPath), "%s/../resources/liblexilla.so", szPath );
      s_hLexilla = dlopen( libPath, RTLD_LAZY );
      if( fLog ) fprintf( fLog, "dlopen Lexilla '%s' => %p\n", libPath, s_hLexilla );

      if( !s_hLexilla ) {
         snprintf( libPath, sizeof(libPath), "%s/resources/liblexilla.so", szPath );
         s_hLexilla = dlopen( libPath, RTLD_LAZY );
         if( fLog ) fprintf( fLog, "dlopen Lexilla '%s' => %p\n", libPath, s_hLexilla );
      }

      if( !s_hLexilla ) {
         s_hLexilla = dlopen( "liblexilla.so", RTLD_LAZY );
         if( fLog ) fprintf( fLog, "dlopen liblexilla.so (system) => %p\n", s_hLexilla );
      }
   }

   if( s_hLexilla ) {
      s_pCreateLexer = (CreateLexerFn) dlsym( s_hLexilla, "CreateLexer" );
      if( fLog ) fprintf( fLog, "CreateLexer proc => %p\n", s_pCreateLexer );
   }

   if( fLog ) { fprintf( fLog, "InitScintilla OK\n" ); fclose( fLog ); }
   return 1;
}

/* Configure Scintilla with Harbour syntax highlighting */
static void ConfigureScintilla( GtkWidget * sci )
{
   ILexer5 * pLexer;

   /* UTF-8 code page */
   SciMsg( sci, SCI_SETCODEPAGE, SC_CP_UTF8, 0 );

   /* Tab width */
   SciMsg( sci, SCI_SETTABWIDTH, 3, 0 );

   /* Set C/C++ lexer via Lexilla (works for Harbour too) */
   if( s_pCreateLexer ) {
      pLexer = s_pCreateLexer( "cpp" );
      if( pLexer ) {
         SciMsg( sci, SCI_SETILEXER, 0, (intptr_t) pLexer );
      }
   }

   /* Default style: Monospace 14pt, light gray on dark */
   SciMsg( sci, SCI_STYLESETFONT, STYLE_DEFAULT, (intptr_t) "Monospace" );
   SciMsg( sci, SCI_STYLESETSIZE, STYLE_DEFAULT, 14 );
   SciMsg( sci, SCI_STYLESETFORE, STYLE_DEFAULT, SciRGB(212,212,212) );
   SciMsg( sci, SCI_STYLESETBACK, STYLE_DEFAULT, SciRGB(30,30,30) );
   SciMsg( sci, SCI_STYLECLEARALL, 0, 0 );  /* Apply default to all styles */

   /* Line number margin */
   SciMsg( sci, SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER );
   SciMsg( sci, SCI_SETMARGINWIDTHN, 0, 48 );
   SciMsg( sci, SCI_STYLESETFORE, STYLE_LINENUMBER, SciRGB(133,133,133) );
   SciMsg( sci, SCI_STYLESETBACK, STYLE_LINENUMBER, SciRGB(37,37,38) );

   /* Breakpoint margin (margin 1) — clickable symbol strip */
   SciMsg( sci, SCI_SETMARGINTYPEN, 1, SC_MARGIN_SYMBOL );
   SciMsg( sci, SCI_SETMARGINMASKN, 1, 1 << 12 );   /* only marker 12 */
   SciMsg( sci, SCI_SETMARGINWIDTHN, 1, 14 );
   SciMsg( sci, SCI_SETMARGINSENSITIVEN, 1, 1 );
   SciMsg( sci, SCI_STYLESETBACK, 33, SciRGB(37,37,38) );  /* margin 1 background */

   /* Folding margin */
   SciMsg( sci, SCI_SETMARGINTYPEN, 2, SC_MARGIN_SYMBOL );
   SciMsg( sci, SCI_SETMARGINMASKN, 2, SC_MASK_FOLDERS );
   SciMsg( sci, SCI_SETMARGINWIDTHN, 2, 16 );
   SciMsg( sci, SCI_SETMARGINSENSITIVEN, 2, 1 );
   SciMsg( sci, SCI_SETAUTOMATICFOLD,
      SC_AUTOMATICFOLD_SHOW | SC_AUTOMATICFOLD_CLICK | SC_AUTOMATICFOLD_CHANGE, 0 );

   /* Fold markers - box style */
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDER,        SC_MARK_BOXPLUS );
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEROPEN,    SC_MARK_BOXMINUS );
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERSUB,     SC_MARK_VLINE );
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERTAIL,    SC_MARK_LCORNER );
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEREND,     SC_MARK_BOXPLUSCONNECTED );
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDEROPENMID, SC_MARK_BOXMINUSCONNECTED );
   SciMsg( sci, SCI_MARKERDEFINE, SC_MARKNUM_FOLDERMIDTAIL, SC_MARK_TCORNER );

   { int m;
     for( m = 25; m <= 31; m++ ) {
        SciMsg( sci, SCI_MARKERSETFORE, m, SciRGB(160,160,160) );
        SciMsg( sci, SCI_MARKERSETBACK, m, SciRGB(37,37,38) );
     }
   }

   /* Debug execution line marker (marker 11) - yellow background */
   SciMsg( sci, SCI_MARKERDEFINE, 11, SC_MARK_BACKGROUND );
   SciMsg( sci, SCI_MARKERSETBACK, 11, SciRGB(60,60,0) );

   /* Breakpoint marker (marker 12) - red circle */
   SciMsg( sci, SCI_MARKERDEFINE, 12, SC_MARK_CIRCLE );
   SciMsg( sci, SCI_MARKERSETFORE, 12, SciRGB(180,0,0) );
   SciMsg( sci, SCI_MARKERSETBACK, 12, SciRGB(220,30,30) );

   /* Enable folding property */
   SciMsg( sci, SCI_SETPROPERTY, (uintptr_t) "fold",              (intptr_t) "1" );
   SciMsg( sci, SCI_SETPROPERTY, (uintptr_t) "fold.compact",      (intptr_t) "0" );
   SciMsg( sci, SCI_SETPROPERTY, (uintptr_t) "fold.comment",      (intptr_t) "1" );
   SciMsg( sci, SCI_SETPROPERTY, (uintptr_t) "fold.preprocessor", (intptr_t) "1" );

   /* ===== Harbour keyword lists ===== */
   /* Keywords set 0: Harbour language keywords (all cases) */
   SciMsg( sci, SCI_SETKEYWORDS, 0, (intptr_t)
      "function procedure return local static private public "
      "if else elseif endif do while enddo for next to step in "
      "switch case otherwise endswitch endcase default "
      "class endclass method data access assign inherit inline "
      "nil self super begin end exit loop with sequence recover "
      "try catch finally true false and or not "
      "init announce request external memvar field parameters "
      "break continue optional redefine "
      "FUNCTION PROCEDURE RETURN LOCAL STATIC PRIVATE PUBLIC "
      "IF ELSE ELSEIF ENDIF DO WHILE ENDDO FOR NEXT TO STEP IN "
      "SWITCH CASE OTHERWISE ENDSWITCH ENDCASE DEFAULT "
      "CLASS ENDCLASS METHOD DATA ACCESS ASSIGN INHERIT INLINE "
      "NIL SELF SUPER BEGIN END EXIT LOOP WITH SEQUENCE RECOVER "
      "TRY CATCH FINALLY TRUE FALSE AND OR NOT "
      "INIT ANNOUNCE REQUEST EXTERNAL MEMVAR FIELD PARAMETERS "
      "BREAK CONTINUE OPTIONAL REDEFINE "
      "Function Procedure Return Local Static Private Public "
      "If Else ElseIf EndIf Do While EndDo For Next To Step In "
      "Switch Case Otherwise EndSwitch EndCase Default "
      "Class EndClass Method Data Access Assign Inherit Inline "
      "Nil Self Super Begin End Exit Loop With Sequence Recover "
      "Try Catch Finally True False And Or Not " );

   /* Keywords set 1: xBase commands + FiveWin (uppercase mapped to WORD2) */
   SciMsg( sci, SCI_SETKEYWORDS, 1, (intptr_t)
      "DEFINE ACTIVATE FORM TITLE SIZE FONT SIZABLE APPBAR TOOLWINDOW "
      "CENTERED SAY GET BUTTON PROMPT CHECKBOX COMBOBOX GROUPBOX "
      "ITEMS CHECKED DEFAULT CANCEL OF VAR ACTION ON VALID WHEN FROM "
      "TOOLBAR SEPARATOR TOOLTIP MENUBAR POPUP MENUITEM MENUSEPARATOR "
      "PALETTE REQUEST ACCEL BITMAP ICON BROWSE DIALOG "
      "LISTBOX RADIOBUTTON SCROLLBAR PANEL IMAGE SHAPE BEVEL "
      "TREEVIEW LISTVIEW PROGRESSBAR RICHEDIT STATUSBAR SPLITTER "
      "TABS TAB MEMO DATEPICKER SPINNER GAUGE HEADER "
      "REPORT BAND COLUMN PRINTER PREVIEW "
      "WEBVIEW WEBSERVER SOCKET WEBSOCKET HTTPGET HTTPPOST "
      "THREAD MUTEX SEMAPHORE CRITICALSECTION ATOMICOP "
      "OLLAMA OPENAI GEMINI CLAUDE DEEPSEEK TRANSFORMER " );

   /* ===== Syntax highlighting colors (VS Code Dark+ inspired) ===== */
   /* Keywords: bright blue, bold */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_WORD, SciRGB(86,156,214) );
   SciMsg( sci, SCI_STYLESETBOLD, SCE_C_WORD, 1 );

   /* Commands (WORD2): teal/cyan */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_WORD2, SciRGB(78,201,176) );

   /* Comments: green, italic */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENT,     SciRGB(106,153,85) );
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENTLINE,  SciRGB(106,153,85) );
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENTDOC,   SciRGB(106,153,85) );
   SciMsg( sci, SCI_STYLESETITALIC, SCE_C_COMMENT, 1 );
   SciMsg( sci, SCI_STYLESETITALIC, SCE_C_COMMENTLINE, 1 );

   /* Strings: orange */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_STRING,    SciRGB(206,145,120) );
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_CHARACTER,  SciRGB(206,145,120) );

   /* Numbers: light green */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_NUMBER, SciRGB(181,206,168) );

   /* Preprocessor: magenta */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_PREPROCESSOR, SciRGB(197,134,192) );

   /* Operators: light gray */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_OPERATOR, SciRGB(212,212,212) );

   /* Identifiers: default light gray */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_IDENTIFIER, SciRGB(220,220,220) );

   /* Global classes: teal */
   SciMsg( sci, SCI_STYLESETFORE, SCE_C_GLOBALCLASS, SciRGB(78,201,176) );

   /* Caret and selection */
   SciMsg( sci, SCI_SETCARETFORE, SciRGB(255,255,255), 0 );
   SciMsg( sci, SCI_SETSELBACK, 1, SciRGB(38,79,120) );

   /* Extra line spacing for readability */
   SciMsg( sci, SCI_SETEXTRAASCENT, 1, 0 );
   SciMsg( sci, SCI_SETEXTRADESCENT, 1, 0 );

   /* Indentation guides */
   SciMsg( sci, SCI_SETINDENTATIONGUIDES, SC_IV_LOOKBOTH, 0 );

   { FILE * fLog = fopen( "/tmp/scintilla_trace.log", "a" );
     if( fLog ) { fprintf( fLog, "ConfigureScintilla done for widget=%p\n", sci ); fclose( fLog ); }
   }
}

/* ======================================================================
 * Harbour-aware code folding
 * Scans all lines and sets fold levels based on Harbour keywords
 * ====================================================================== */

static int LineStartsWithCI_GTK( const char * line, int lineLen, const char * word )
{
   int i = 0, wLen = (int)strlen(word);
   while( i < lineLen && (line[i] == ' ' || line[i] == '\t') ) i++;
   if( i + wLen > lineLen ) return 0;
   if( strncasecmp( line + i, word, wLen ) != 0 ) return 0;
   if( i + wLen < lineLen ) {
      char c = line[i + wLen];
      if( (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_' || (c >= '0' && c <= '9') )
         return 0;
   }
   return 1;
}

static void UpdateHarbourFolding( GtkWidget * sci )
{
   int lineCount, i, level;

   if( !sci ) return;

   lineCount = (int) SciMsg( sci, SCI_GETLINECOUNT, 0, 0 );
   level = SC_FOLDLEVELBASE;

   for( i = 0; i < lineCount; i++ )
   {
      int lineLen = (int) SciMsg( sci, SCI_LINELENGTH, i, 0 );
      int curLevel = level;
      int nextLevel = level;
      int isHeader = 0;

      if( lineLen > 0 && lineLen < 4096 )
      {
         char * buf = (char *) malloc( lineLen + 1 );
         SciMsg( sci, SCI_GETLINE, i, (intptr_t) buf );
         buf[lineLen] = 0;

         while( lineLen > 0 && (buf[lineLen-1] == '\r' || buf[lineLen-1] == '\n') )
            buf[--lineLen] = 0;

         if( LineStartsWithCI_GTK(buf, lineLen, "function") ||
             LineStartsWithCI_GTK(buf, lineLen, "procedure") ||
             LineStartsWithCI_GTK(buf, lineLen, "method") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "class") &&
                  !LineStartsWithCI_GTK(buf, lineLen, "endclass") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "if") &&
                  !LineStartsWithCI_GTK(buf, lineLen, "endif") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "do") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "for") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "switch") &&
                  !LineStartsWithCI_GTK(buf, lineLen, "endswitch") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "begin") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "while") &&
                  !LineStartsWithCI_GTK(buf, lineLen, "enddo") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "#pragma BEGINDUMP") ||
                  LineStartsWithCI_GTK(buf, lineLen, "#pragma begindump") )
         {
            isHeader = 1; nextLevel = level + 1;
         }
         else if( LineStartsWithCI_GTK(buf, lineLen, "return") ||
                  LineStartsWithCI_GTK(buf, lineLen, "endclass") ||
                  LineStartsWithCI_GTK(buf, lineLen, "endif") ||
                  LineStartsWithCI_GTK(buf, lineLen, "enddo") ||
                  LineStartsWithCI_GTK(buf, lineLen, "next") ||
                  LineStartsWithCI_GTK(buf, lineLen, "endswitch") ||
                  LineStartsWithCI_GTK(buf, lineLen, "endcase") ||
                  LineStartsWithCI_GTK(buf, lineLen, "end") ||
                  LineStartsWithCI_GTK(buf, lineLen, "#pragma ENDDUMP") ||
                  LineStartsWithCI_GTK(buf, lineLen, "#pragma enddump") )
         {
            if( level > SC_FOLDLEVELBASE )
            {
               curLevel = level - 1;
               nextLevel = level - 1;
            }
         }

         free( buf );
      }

      SciMsg( sci, SCI_SETFOLDLEVEL, i,
         curLevel | (isHeader ? SC_FOLDLEVELHEADERFLAG : 0) );

      level = nextLevel;
   }
}

/* All Harbour keywords + functions for auto-complete (space-separated) */
static const char * s_acList =
   "AAdd AClone ADel AEval AFill AIns ASize AScan ASort "
   "Abs AllTrim Array Asc At "
   "begin break "
   "CToD Chr class "
   "DToC Date data default do "
   "Empty Eval "
   "FClose FOpen FRead FWrite File "
   "GetEnv "
   "HB_ATokens HB_CRC32 HB_DirCreate HB_FNameDir HB_Random HB_StrToUTF8 HB_UTF8ToStr HB_ValToStr "
   "Iif If Int "
   "LTrim Len Lower "
   "Max MemoRead MemoWrit Min MsgInfo MsgStop MsgYesNo "
   "RTrim RAt Replicate Round "
   "Space Str StrTran SubStr "
   "Time Type "
   "Upper "
   "Val ValType "
   "access assign "
   "case class "
   "else elseif end endcase endclass enddo endif endswitch exit "
   "for function "
   "if in inherit inline "
   "local loop "
   "method "
   "next nil not "
   "or otherwise "
   "private procedure public "
   "recover request return "
   "self sequence static step super switch "
   "to try "
   "while with";

static void CE_ShowAutoComplete( GtkWidget * sci )
{
   int nPos, nStart;

   if( !sci ) return;

   nPos = (int) SciMsg( sci, SCI_GETCURRENTPOS, 0, 0 );
   nStart = nPos;

   while( nStart > 0 ) {
      int ch = (int) SciMsg( sci, SCI_GETCHARAT, nStart - 1, 0 );
      if( (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
          (ch >= '0' && ch <= '9') || ch == '_' )
         nStart--;
      else
         break;
   }

   if( nPos - nStart >= 2 ) {
      SciMsg( sci, SCI_AUTOCSETIGNORECASE, 1, 0 );
      SciMsg( sci, SCI_AUTOCSETSEPARATOR, ' ', 0 );
      SciMsg( sci, SCI_AUTOCSHOW, nPos - nStart, (intptr_t) s_acList );
   }
}

/* ======================================================================
 * Class member autocomplete — triggered when ':' is typed
 * ====================================================================== */

#define SCI_AUTOCSETORDER 2235

typedef struct {
   const char * className;
   const char * members;
} ClassMembers;

static ClassMembers s_classMembers[] = {
   { "TForm",
     "Activate() AlphaBlend AlphaBlendValue AppBar AutoScroll BorderIcons "
     "BorderStyle BorderWidth ClientHeight ClientWidth Close() Color CreateForm() Cursor "
     "Destroy() DoubleBuffered FontName FontSize FormStyle Height Hint "
     "KeyPreview Left ModalResult Name OnActivate OnChange OnClick OnClose "
     "OnCloseQuery OnCreate OnDblClick OnDeactivate OnDestroy OnHide "
     "OnKeyDown OnKeyPress OnKeyUp OnMouseDown OnMouseMove OnMouseUp "
     "OnMouseWheel OnPaint OnResize OnShow Position Show() ShowHint "
     "ShowModal() Sizable Text Title ToolWindow Top Width WindowState" },
   { "TLabel",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TEdit",
     "Height Left Name OnChange OnClick OnClose Text Top Value Width" },
   { "TMemo",
     "Height Left Name OnChange OnClick OnClose Text Top Value Width" },
   { "TButton",
     "Cancel Default Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TCheckBox",
     "Checked Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TRadioButton",
     "Checked Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TComboBox",
     "AddItem() Height Left Name OnChange OnClick OnClose Text Top Value Width" },
   { "TListBox",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TGroupBox",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TToolBar",
     "AddButton() AddSeparator() Height Left Name Text Top Width" },
   { "TTimer",
     "Enabled Height Interval Left Name OnTimer Text Top Width" },
   { "TApplication",
     "CreateForm() Run() Title" },
   { "TPanel",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TProgressBar",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TTabControl",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TTreeView",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TListView",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TImage",
     "Height Left Name OnChange OnClick OnClose Text Top Width" },
   { "TDatabase",
     "Close() Exec() Field() FieldCount() FieldName() FreeResult() Goto() Host Name "
     "Open() Password Port Query() RecCount() RecNo() Server Skip() Table User" },
   { "TSQLite",
     "Close() Exec() Field() FieldCount() FieldName() FreeResult() Goto() Host Name "
     "Open() Password Port Query() RecCount() RecNo() Server Skip() Table User" },
   { "TReport",
     "Preview() Print()" },
   { "TWebServer",
     "Get() Post() Run()" },
   { "THttpClient",
     "Get() Post()" },
   { "TThread",
     "Join() Start()" },
   { "TDBFTable",
     "Append() Bof() cAlias cDatabase cFileName cIndexFile cRDD Close() "
     "CreateIndex() Delete() Deleted() Eof() FieldCount() FieldGet() "
     "FieldName() FieldPut() Found() GoBottom() GoTo() GoTop() "
     "lConnected lExclusive lReadOnly nArea Open() Recall() "
     "RecCount() RecNo() Seek() Skip() Structure() Tables()" },
   { NULL, NULL }
};

typedef struct {
   GtkWidget *    window;
   GtkWidget *    sciWidget;   /* Scintilla GTK widget */
   /* Tabs */
   GtkWidget *    tabBar;      /* GtkNotebook used as tab bar */
   char           tabNames[CE_MAX_TABS][64];
   char *         tabTexts[CE_MAX_TABS];  /* heap-allocated text per tab */
   int            nTabs;
   int            nActiveTab;  /* 0-based */
   PHB_ITEM       pOnTabChange;
   /* Find bar */
   GtkWidget *    findBar;
   GtkWidget *    findEntry;
   GtkWidget *    findLabel;
   GtkWidget *    replaceEntry;
   GtkWidget *    replaceLbl;     /* "Replace:" label */
   GtkWidget *    replaceBtn;     /* Replace button */
   GtkWidget *    replaceAllBtn;  /* All button */
   int            bFindVisible;
   int            bReplaceVisible;
   /* Status bar */
   GtkWidget *    statusBar;
   /* Text-change callback (debounced) */
   PHB_ITEM       pOnTextChange;
   guint          debounceTimer;  /* g_timeout source id, 0 = none */
   int            bSettingText;   /* guard: programmatic text set in progress */
} CODEEDITOR;

/* Find current CLASS name by scanning backwards from line */
static const char * CE_FindCurrentClass( GtkWidget * sci, int fromLine )
{
   static char s_curClass[64];
   int l;
   for( l = fromLine; l >= 0; l-- )
   {
      char buf[512];
      int len = (int) SciMsg( sci, SCI_LINELENGTH, l, 0 );
      const char * cp;
      int ci;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( sci, SCI_GETLINE, l, (intptr_t)buf );
      buf[len] = 0;
      cp = buf;
      while( *cp == ' ' || *cp == '\t' ) cp++;
      if( strncasecmp( cp, "CLASS ", 6 ) == 0 ) {
         cp += 6;
         while( *cp == ' ' ) cp++;
         ci = 0;
         while( ci < 63 && (isalnum((unsigned char)cp[ci]) || cp[ci] == '_') )
            { s_curClass[ci] = cp[ci]; ci++; }
         s_curClass[ci] = 0;
         if( ci > 0 ) return s_curClass;
         break;
      }
   }
   return NULL;
}

/* Collect DATA/METHOD from current editor CLASS block */
static int CE_CollectUserData( GtkWidget * sci, int classLine, char * buf, int bufSize )
{
   int pos = 0, l;
   int totalLines = (int) SciMsg( sci, SCI_GETLINECOUNT, 0, 0 );
   for( l = classLine + 1; l < totalLines; l++ )
   {
      char line[512];
      int len = (int) SciMsg( sci, SCI_LINELENGTH, l, 0 );
      const char * p;
      int isData, isMethod;
      char name[64];
      int ni;
      if( len <= 0 || len >= (int)sizeof(line) ) continue;
      SciMsg( sci, SCI_GETLINE, l, (intptr_t)line );
      line[len] = 0;
      p = line;
      while( *p == ' ' || *p == '\t' || *p == '\r' || *p == '\n' ) p++;
      if( *p == 0 ) continue;
      if( strncasecmp( p, "ENDCLASS", 8 ) == 0 ) break;
      isData = ( strncasecmp( p, "DATA ", 5 ) == 0 );
      isMethod = ( strncasecmp( p, "METHOD ", 7 ) == 0 ) ||
                 ( strncasecmp( p, "ACCESS ", 7 ) == 0 );
      if( !isData && !isMethod ) continue;
      if( isData ) p += 5; else p += 7;
      while( *p == ' ' ) p++;
      ni = 0;
      while( ni < 63 && (isalnum((unsigned char)p[ni]) || p[ni] == '_') )
         { name[ni] = p[ni]; ni++; }
      name[ni] = 0;
      if( ni == 0 ) continue;
      if( isMethod && ni < 61 ) { name[ni++] = '('; name[ni++] = ')'; name[ni] = 0; }
      if( pos > 0 && pos < bufSize - 1 ) buf[pos++] = ' ';
      if( ni > bufSize - pos - 1 ) break;
      memcpy( buf + pos, name, (size_t)ni );
      pos += ni;
   }
   buf[pos] = 0;
   return pos;
}

/* Search plain text for CLASS declaration matching cls */
static const char * CE_FindClassInText( const char * text, const char * cls, char * parentCls )
{
   const char * cur = text;
   parentCls[0] = 0;
   while( *cur )
   {
      const char * lineStart = cur;
      const char * lineEnd = cur;
      int lineLen;
      while( *lineEnd && *lineEnd != '\n' ) lineEnd++;
      lineLen = (int)(lineEnd - cur);
      if( lineLen > 0 && lineLen < 510 )
      {
         char line[512];
         const char * p;
         char foundCls[64];
         int fi;
         memcpy( line, cur, (size_t)lineLen );
         line[lineLen] = 0;
         p = line;
         while( *p == ' ' || *p == '\t' ) p++;
         if( strncasecmp( p, "CLASS ", 6 ) == 0 )
         {
            p += 6;
            while( *p == ' ' ) p++;
            fi = 0;
            while( fi < 63 && (isalnum((unsigned char)p[fi]) || p[fi] == '_') )
               { foundCls[fi] = p[fi]; fi++; }
            foundCls[fi] = 0;
            if( strcasecmp( foundCls, cls ) == 0 )
            {
               p += fi;
               while( *p == ' ' ) p++;
               if( strncasecmp( p, "INHERIT ", 8 ) == 0 ) p += 8;
               else if( strncasecmp( p, "FROM ", 5 ) == 0 ) p += 5;
               else p = NULL;
               if( p ) {
                  int pi = 0;
                  while( *p == ' ' ) p++;
                  while( pi < 63 && (isalnum((unsigned char)p[pi]) || p[pi] == '_') )
                     { parentCls[pi] = p[pi]; pi++; }
                  parentCls[pi] = 0;
               }
               return lineStart;
            }
         }
      }
      cur = lineEnd;
      if( *cur == '\n' ) cur++;
   }
   return NULL;
}

/* Collect DATA/METHOD from plain text starting after CLASS line */
static int CE_CollectUserDataFromText( const char * text, const char * classLineStart,
                                        char * buf, int bufSize )
{
   int pos = 0;
   const char * cur = classLineStart;
   while( *cur && *cur != '\n' ) cur++;
   if( *cur == '\n' ) cur++;
   while( *cur )
   {
      const char * lineEnd = cur;
      int lineLen;
      while( *lineEnd && *lineEnd != '\n' ) lineEnd++;
      lineLen = (int)(lineEnd - cur);
      if( lineLen > 0 && lineLen < 510 )
      {
         char line[512];
         const char * p;
         int isData, isMethod;
         memcpy( line, cur, (size_t)lineLen );
         line[lineLen] = 0;
         p = line;
         while( *p == ' ' || *p == '\t' || *p == '\r' ) p++;
         if( *p != 0 )
         {
            if( strncasecmp( p, "ENDCLASS", 8 ) == 0 ) break;
            isData = ( strncasecmp( p, "DATA ", 5 ) == 0 );
            isMethod = ( strncasecmp( p, "METHOD ", 7 ) == 0 ) ||
                       ( strncasecmp( p, "ACCESS ", 7 ) == 0 );
            if( isData || isMethod )
            {
               char name[64];
               int ni = 0;
               if( isData ) p += 5; else p += 7;
               while( *p == ' ' ) p++;
               while( ni < 63 && (isalnum((unsigned char)p[ni]) || p[ni] == '_') )
                  { name[ni] = p[ni]; ni++; }
               name[ni] = 0;
               if( isMethod && ni < 61 ) { name[ni++] = '('; name[ni++] = ')'; name[ni] = 0; }
               if( ni > 0 ) {
                  if( pos > 0 && pos < bufSize - 1 ) buf[pos++] = ' ';
                  if( ni > bufSize - pos - 1 ) break;
                  memcpy( buf + pos, name, (size_t)ni );
                  pos += ni;
               }
            }
         }
      }
      cur = lineEnd;
      if( *cur == '\n' ) cur++;
   }
   buf[pos] = 0;
   return pos;
}

/* Find class members combining standard + user-defined */
static const char * CE_FindClassMembers( CODEEDITOR * ed, const char * cls )
{
   static char s_combined[4096];
   const char * stdMembers = NULL;
   char userMembers[2048] = "";
   int classLine = -1, i, t;

   for( i = 0; s_classMembers[i].className; i++ )
      if( strcasecmp( cls, s_classMembers[i].className ) == 0 )
         { stdMembers = s_classMembers[i].members; break; }

   if( !ed || !ed->sciWidget ) goto cm_combine;

   /* Search current editor for CLASS definition */
   {
      int totalLines = (int) SciMsg( ed->sciWidget, SCI_GETLINECOUNT, 0, 0 );
      for( i = 0; i < totalLines; i++ )
      {
         char buf[512];
         int len = (int) SciMsg( ed->sciWidget, SCI_LINELENGTH, i, 0 );
         const char * cp;
         char foundCls[64];
         int fi;
         if( len <= 0 || len >= (int)sizeof(buf) ) continue;
         SciMsg( ed->sciWidget, SCI_GETLINE, i, (intptr_t)buf );
         buf[len] = 0;
         cp = buf;
         while( *cp == ' ' || *cp == '\t' ) cp++;
         if( strncasecmp( cp, "CLASS ", 6 ) != 0 ) continue;
         cp += 6;
         while( *cp == ' ' ) cp++;
         fi = 0;
         while( fi < 63 && (isalnum((unsigned char)cp[fi]) || cp[fi] == '_') )
            { foundCls[fi] = cp[fi]; fi++; }
         foundCls[fi] = 0;
         if( strcasecmp( foundCls, cls ) == 0 )
         {
            classLine = i;
            cp += fi;
            while( *cp == ' ' ) cp++;
            if( strncasecmp( cp, "INHERIT ", 8 ) == 0 ) cp += 8;
            else if( strncasecmp( cp, "FROM ", 5 ) == 0 ) cp += 5;
            else cp = NULL;
            if( cp && !stdMembers ) {
               char parent[64];
               int pi = 0;
               while( *cp == ' ' ) cp++;
               while( pi < 63 && (isalnum((unsigned char)cp[pi]) || cp[pi] == '_') )
                  { parent[pi] = cp[pi]; pi++; }
               parent[pi] = 0;
               for( i = 0; s_classMembers[i].className; i++ )
                  if( strcasecmp( parent, s_classMembers[i].className ) == 0 )
                     { stdMembers = s_classMembers[i].members; break; }
            }
            break;
         }
      }
      if( classLine >= 0 )
         CE_CollectUserData( ed->sciWidget, classLine, userMembers, sizeof(userMembers) );
   }

   /* If not found, search other tabs */
   if( classLine < 0 )
   {
      for( t = 0; t < ed->nTabs; t++ )
      {
         char parentCls[64];
         const char * classPos;
         if( t == ed->nActiveTab || !ed->tabTexts[t] || !ed->tabTexts[t][0] ) continue;
         classPos = CE_FindClassInText( ed->tabTexts[t], cls, parentCls );
         if( classPos ) {
            CE_CollectUserDataFromText( ed->tabTexts[t], classPos, userMembers, sizeof(userMembers) );
            if( parentCls[0] && !stdMembers ) {
               for( i = 0; s_classMembers[i].className; i++ )
                  if( strcasecmp( parentCls, s_classMembers[i].className ) == 0 )
                     { stdMembers = s_classMembers[i].members; break; }
            }
            break;
         }
      }
   }

cm_combine:
   if( stdMembers && userMembers[0] ) {
      snprintf( s_combined, sizeof(s_combined), "%s %s", stdMembers, userMembers );
      return s_combined;
   }
   if( stdMembers ) return stdMembers;
   if( userMembers[0] ) { strncpy( s_combined, userMembers, sizeof(s_combined)-1 ); return s_combined; }
   return NULL;
}

/* Resolve variable class from context (4 strategies) */
static const char * CE_ResolveVarClass( CODEEDITOR * ed, int colonPos )
{
   static char s_resolved[64];
   int line, lineStart, lineLen;
   char lineBuf[512];
   int end, nameEnd, nameStart, varLen;
   char varName[128];
   int hasDblColon;
   int totalLines, l, i;

   static struct { const char * prefix; const char * cls; } s_nameMap[] = {
      { "Form", "TForm" }, { "Button", "TButton" }, { "Edit", "TEdit" },
      { "Label", "TLabel" }, { "Memo", "TMemo" }, { "CheckBox", "TCheckBox" },
      { "RadioButton", "TRadioButton" }, { "ComboBox", "TComboBox" },
      { "ListBox", "TListBox" }, { "GroupBox", "TGroupBox" }, { "Panel", "TPanel" },
      { "Timer", "TTimer" }, { "ToolBar", "TToolBar" }, { "ProgressBar", "TProgressBar" },
      { "TabControl", "TTabControl" }, { "TreeView", "TTreeView" },
      { "ListView", "TListView" }, { "Image", "TImage" }, { "Database", "TDatabase" },
      { "DBFTable", "TDBFTable" }, { "SQLite", "TSQLite" }, { "Report", "TReport" },
      { "WebServer", "TWebServer" }, { "HttpClient", "THttpClient" },
      { "Thread", "TThread" }, { "App", "TApplication" }, { NULL, NULL }
   };

   if( !ed || !ed->sciWidget ) return NULL;

   line = (int) SciMsg( ed->sciWidget, SCI_LINEFROMPOSITION, colonPos, 0 );
   lineStart = (int) SciMsg( ed->sciWidget, SCI_POSITIONFROMLINE, line, 0 );
   lineLen = colonPos - lineStart;
   if( lineLen <= 0 || lineLen > 500 ) return NULL;

   /* Get text before colon char by char */
   {
      int ci;
      for( ci = 0; ci < lineLen && ci < 511; ci++ )
         lineBuf[ci] = (char) SciMsg( ed->sciWidget, SCI_GETCHARAT, lineStart + ci, 0 );
      lineBuf[ci] = 0;
   }

   end = lineLen - 1;
   while( end >= 0 && lineBuf[end] == ':' ) end--;
   nameEnd = end;
   while( end >= 0 && (isalnum((unsigned char)lineBuf[end]) || lineBuf[end] == '_') ) end--;
   nameStart = end + 1;
   if( nameStart > nameEnd ) return NULL;

   varLen = nameEnd - nameStart + 1;
   if( varLen <= 0 || varLen >= (int)sizeof(varName) ) return NULL;
   memcpy( varName, &lineBuf[nameStart], (size_t)varLen );
   varName[varLen] = 0;

   hasDblColon = ( nameStart >= 2 && lineBuf[nameStart-1] == ':' && lineBuf[nameStart-2] == ':' );

   /* "Self:" */
   if( strcasecmp( varName, "Self" ) == 0 )
      return CE_FindCurrentClass( ed->sciWidget, line );

   /* Strategy 1: DATA comment — "DATA oName // TClassName" */
   totalLines = (int) SciMsg( ed->sciWidget, SCI_GETLINECOUNT, 0, 0 );
   for( l = 0; l < totalLines; l++ )
   {
      char buf[512];
      int len = (int) SciMsg( ed->sciWidget, SCI_LINELENGTH, l, 0 );
      const char * dp, * cmt;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( ed->sciWidget, SCI_GETLINE, l, (intptr_t)buf );
      buf[len] = 0;
      dp = buf;
      while( *dp == ' ' || *dp == '\t' ) dp++;
      if( strncasecmp( dp, "DATA ", 5 ) != 0 ) continue;
      dp += 5;
      while( *dp == ' ' ) dp++;
      if( strncasecmp( dp, varName, (size_t)varLen ) != 0 ) continue;
      dp += varLen;
      if( isalnum((unsigned char)*dp) || *dp == '_' ) continue;
      cmt = strstr( dp, "//" );
      if( !cmt ) continue;
      cmt += 2;
      while( *cmt == ' ' ) cmt++;
      if( isalpha((unsigned char)*cmt) ) {
         int ri = 0;
         while( ri < 62 && (isalnum((unsigned char)cmt[ri]) || cmt[ri] == '_') )
            ri++;
         if( cmt[0] == 'T' && ri > 1 && isupper((unsigned char)cmt[1]) ) {
            memcpy( s_resolved, cmt, (size_t)ri );
            s_resolved[ri] = 0;
         } else {
            s_resolved[0] = 'T';
            memcpy( s_resolved + 1, cmt, (size_t)ri );
            s_resolved[ri + 1] = 0;
         }
         return s_resolved;
      }
   }

   /* Strategy 2: assignment pattern — "varName := TClassName():New" */
   for( l = 0; l < totalLines; l++ )
   {
      char buf[512];
      int len = (int) SciMsg( ed->sciWidget, SCI_LINELENGTH, l, 0 );
      const char * vp;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( ed->sciWidget, SCI_GETLINE, l, (intptr_t)buf );
      buf[len] = 0;
      vp = strstr( buf, varName );
      if( !vp ) continue;
      vp += varLen;
      while( *vp == ' ' ) vp++;
      if( *vp != ':' || vp[1] != '=' ) continue;
      vp += 2;
      while( *vp == ' ' ) vp++;
      if( *vp == 'T' && isalpha((unsigned char)vp[1]) ) {
         int ci = 0, slen;
         while( ci < 63 && (isalnum((unsigned char)vp[ci]) || vp[ci] == '_') )
            { s_resolved[ci] = vp[ci]; ci++; }
         s_resolved[ci] = 0;
         slen = (int)strlen( s_resolved );
         if( slen > 2 && s_resolved[slen-1] == ')' && s_resolved[slen-2] == '(' )
            s_resolved[slen-2] = 0;
         return s_resolved;
      }
   }

   /* Strategy 3: :: prefix → current class */
   if( hasDblColon )
      return CE_FindCurrentClass( ed->sciWidget, line );

   /* Strategy 4: naming convention — oForm→TForm, oButton→TButton */
   {
      const char * base = varName;
      if( (base[0] == 'o' || base[0] == 'O') && isupper((unsigned char)base[1]) )
         base++;
      for( i = 0; s_nameMap[i].prefix; i++ ) {
         int plen = (int)strlen( s_nameMap[i].prefix );
         if( strncasecmp( base, s_nameMap[i].prefix, (size_t)plen ) == 0 ) {
            char next = base[plen];
            if( next == 0 || isdigit((unsigned char)next) || isupper((unsigned char)next) || next == '_' ) {
               strncpy( s_resolved, s_nameMap[i].cls, 63 );
               return s_resolved;
            }
         }
      }
   }

   return NULL;
}

/* ======================================================================
 * Code Editor - implementation
 * ====================================================================== */

/* Save current Scintilla text to the active tab's buffer */
static void SaveCurrentTabText( CODEEDITOR * ed )
{
   int nLen;
   if( !ed || !ed->sciWidget || ed->nActiveTab < 0 || ed->nActiveTab >= ed->nTabs )
      return;

   if( ed->tabTexts[ed->nActiveTab] )
      free( ed->tabTexts[ed->nActiveTab] );

   nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
   ed->tabTexts[ed->nActiveTab] = (char *) malloc( nLen + 1 );
   SciMsg( ed->sciWidget, SCI_GETTEXT, nLen + 1, (intptr_t) ed->tabTexts[ed->nActiveTab] );
}

/* Switch to a different tab */
static void CE_SwitchTab( CODEEDITOR * ed, int nNewTab )
{
   if( !ed || nNewTab < 0 || nNewTab >= ed->nTabs || nNewTab == ed->nActiveTab )
      return;

   SaveCurrentTabText( ed );

   ed->nActiveTab = nNewTab;
   ed->bSettingText = 1;
   SciMsg( ed->sciWidget, SCI_SETTEXT, 0,
      (intptr_t)( ed->tabTexts[nNewTab] ? ed->tabTexts[nNewTab] : "" ) );

   SciMsg( ed->sciWidget, SCI_EMPTYUNDOBUFFER, 0, 0 );
   UpdateHarbourFolding( ed->sciWidget );
   ed->bSettingText = 0;
}

/* Update status bar: Ln X, Col Y | INS/OVR | lines | chars */
static void UpdateStatusBar( CODEEDITOR * ed )
{
   int pos, line, col, lineCount, nLen, ovr;
   char szStatus[256];

   if( !ed || !ed->sciWidget || !ed->statusBar ) return;

   pos = (int) SciMsg( ed->sciWidget, SCI_GETCURRENTPOS, 0, 0 );
   line = (int) SciMsg( ed->sciWidget, SCI_LINEFROMPOSITION, pos, 0 );
   col = (int) SciMsg( ed->sciWidget, SCI_GETCOLUMN, pos, 0 );
   lineCount = (int) SciMsg( ed->sciWidget, SCI_GETLINECOUNT, 0, 0 );
   nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
   ovr = (int) SciMsg( ed->sciWidget, SCI_GETOVERTYPE, 0, 0 );

   snprintf( szStatus, sizeof(szStatus),
      "  Ln %d, Col %d      %s      %d lines      %d chars      UTF-8",
      line + 1, col + 1,
      ovr ? "OVR" : "INS",
      lineCount, nLen );

   gtk_label_set_text( GTK_LABEL(ed->statusBar), szStatus );
}

/* Find text in Scintilla */
static void CE_FindNext( CODEEDITOR * ed, int bForward )
{
   const char * szFind;
   int nPos, nCount = 0, nLen, nFindLen, nCurPos;

   if( !ed || !ed->sciWidget || !ed->findEntry ) return;

   szFind = gtk_entry_get_text( GTK_ENTRY(ed->findEntry) );
   if( !szFind || !szFind[0] ) return;

   nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
   nFindLen = (int) strlen( szFind );
   nCurPos = (int) SciMsg( ed->sciWidget,
      bForward ? SCI_GETSELECTIONEND : SCI_GETSELECTIONSTART, 0, 0 );

   if( bForward ) {
      SciMsg( ed->sciWidget, SCI_SETTARGETSTART, nCurPos, 0 );
      SciMsg( ed->sciWidget, SCI_SETTARGETEND, nLen, 0 );
   } else {
      SciMsg( ed->sciWidget, SCI_SETTARGETSTART, nCurPos - 1, 0 );
      SciMsg( ed->sciWidget, SCI_SETTARGETEND, 0, 0 );
   }

   nPos = (int) SciMsg( ed->sciWidget, SCI_SEARCHINTARGET, nFindLen, (intptr_t) szFind );

   /* Wrap around if not found */
   if( nPos < 0 ) {
      if( bForward ) {
         SciMsg( ed->sciWidget, SCI_SETTARGETSTART, 0, 0 );
         SciMsg( ed->sciWidget, SCI_SETTARGETEND, nLen, 0 );
      } else {
         SciMsg( ed->sciWidget, SCI_SETTARGETSTART, nLen, 0 );
         SciMsg( ed->sciWidget, SCI_SETTARGETEND, 0, 0 );
      }
      nPos = (int) SciMsg( ed->sciWidget, SCI_SEARCHINTARGET, nFindLen, (intptr_t) szFind );
   }

   if( nPos >= 0 ) {
      SciMsg( ed->sciWidget, SCI_SETSEL, nPos, nPos + nFindLen );
      SciMsg( ed->sciWidget, SCI_SCROLLCARET, 0, 0 );
   }

   /* Count total matches */
   { int p, s = 0;
     while( s < nLen ) {
        SciMsg( ed->sciWidget, SCI_SETTARGETSTART, s, 0 );
        SciMsg( ed->sciWidget, SCI_SETTARGETEND, nLen, 0 );
        p = (int) SciMsg( ed->sciWidget, SCI_SEARCHINTARGET, nFindLen, (intptr_t) szFind );
        if( p < 0 ) break;
        nCount++;
        s = p + 1;
     }
   }

   if( ed->findLabel ) {
      char buf[64];
      snprintf( buf, sizeof(buf), "%d matches", nCount );
      gtk_label_set_text( GTK_LABEL(ed->findLabel), buf );
   }
}

/* Replace current match */
static void CE_ReplaceCurrent( CODEEDITOR * ed )
{
   const char * szFind;
   const char * szReplace;
   int selStart, selEnd, nFindLen;

   if( !ed || !ed->sciWidget || !ed->findEntry || !ed->replaceEntry ) return;

   szFind = gtk_entry_get_text( GTK_ENTRY(ed->findEntry) );
   szReplace = gtk_entry_get_text( GTK_ENTRY(ed->replaceEntry) );
   if( !szFind || !szFind[0] ) return;

   selStart = (int) SciMsg( ed->sciWidget, SCI_GETSELECTIONSTART, 0, 0 );
   selEnd = (int) SciMsg( ed->sciWidget, SCI_GETSELECTIONEND, 0, 0 );
   nFindLen = (int) strlen( szFind );

   if( selEnd - selStart == nFindLen ) {
      SciMsg( ed->sciWidget, SCI_REPLACESEL, 0, (intptr_t)(szReplace ? szReplace : "") );
   }
   CE_FindNext( ed, 1 );
}

/* Replace all matches */
static void CE_ReplaceAll( CODEEDITOR * ed )
{
   const char * szFind;
   const char * szReplace;
   int nLen, nFindLen, nReplLen, nPos, nCount = 0;

   if( !ed || !ed->sciWidget || !ed->findEntry || !ed->replaceEntry ) return;

   szFind = gtk_entry_get_text( GTK_ENTRY(ed->findEntry) );
   szReplace = gtk_entry_get_text( GTK_ENTRY(ed->replaceEntry) );
   if( !szFind || !szFind[0] ) return;
   if( !szReplace ) szReplace = "";

   nFindLen = (int) strlen( szFind );
   nReplLen = (int) strlen( szReplace );

   SciMsg( ed->sciWidget, SCI_SETTARGETSTART, 0, 0 );
   nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
   SciMsg( ed->sciWidget, SCI_SETTARGETEND, nLen, 0 );

   while( 1 ) {
      nPos = (int) SciMsg( ed->sciWidget, SCI_SEARCHINTARGET, nFindLen, (intptr_t) szFind );
      if( nPos < 0 ) break;
      SciMsg( ed->sciWidget, SCI_REPLACETARGET, nReplLen, (intptr_t) szReplace );
      nCount++;
      SciMsg( ed->sciWidget, SCI_SETTARGETSTART, nPos + nReplLen, 0 );
      nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      SciMsg( ed->sciWidget, SCI_SETTARGETEND, nLen, 0 );
   }

   if( ed->findLabel ) {
      char buf[64];
      snprintf( buf, sizeof(buf), "%d replaced", nCount );
      gtk_label_set_text( GTK_LABEL(ed->findLabel), buf );
   }
}

/* Find bar button callbacks */
static void on_find_next_clicked( GtkButton * btn, gpointer data )
{ CE_FindNext( (CODEEDITOR *)data, 1 ); }

static void on_find_prev_clicked( GtkButton * btn, gpointer data )
{ CE_FindNext( (CODEEDITOR *)data, 0 ); }

static void on_find_close_clicked( GtkButton * btn, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   if( ed && ed->findBar ) {
      gtk_widget_hide( ed->findBar );
      ed->bFindVisible = 0;
      gtk_widget_grab_focus( ed->sciWidget );
   }
}

static void on_replace_clicked( GtkButton * btn, gpointer data )
{ CE_ReplaceCurrent( (CODEEDITOR *)data ); }

static void on_replace_all_clicked( GtkButton * btn, gpointer data )
{ CE_ReplaceAll( (CODEEDITOR *)data ); }

/* Find entry key-press: Enter = next, Shift+Enter = prev, Esc = close */
static gboolean on_find_entry_key( GtkWidget * w, GdkEventKey * ev, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   if( ev->keyval == GDK_KEY_Return || ev->keyval == GDK_KEY_KP_Enter ) {
      CE_FindNext( ed, !(ev->state & GDK_SHIFT_MASK) );
      return TRUE;
   }
   if( ev->keyval == GDK_KEY_Escape ) {
      on_find_close_clicked( NULL, data );
      return TRUE;
   }
   return FALSE;
}

static void CE_ShowFindBar( CODEEDITOR * ed, int bShow, int bReplace )
{
   if( !ed || !ed->findBar ) return;

   ed->bFindVisible = bShow;
   ed->bReplaceVisible = bReplace;

   if( bShow ) {
      gtk_widget_show( ed->findBar );
      /* Show/hide all replace-related widgets together */
      if( bReplace ) {
         if( ed->replaceLbl )    gtk_widget_show( ed->replaceLbl );
         if( ed->replaceEntry )  gtk_widget_show( ed->replaceEntry );
         if( ed->replaceBtn )    gtk_widget_show( ed->replaceBtn );
         if( ed->replaceAllBtn ) gtk_widget_show( ed->replaceAllBtn );
      } else {
         if( ed->replaceLbl )    gtk_widget_hide( ed->replaceLbl );
         if( ed->replaceEntry )  gtk_widget_hide( ed->replaceEntry );
         if( ed->replaceBtn )    gtk_widget_hide( ed->replaceBtn );
         if( ed->replaceAllBtn ) gtk_widget_hide( ed->replaceAllBtn );
      }
      gtk_widget_grab_focus( ed->findEntry );
   } else {
      gtk_widget_hide( ed->findBar );
      gtk_widget_grab_focus( ed->sciWidget );
   }
}

/* Idle callback to restore cursor after all pending GTK events are processed */
typedef struct {
   CODEEDITOR * ed;
   int          savedPos;
   int          savedFirst;
} CURSORRESTORE;

static gboolean on_restore_cursor( gpointer data )
{
   CURSORRESTORE * cr = (CURSORRESTORE *) data;
   CODEEDITOR * ed = cr->ed;

   if( ed && ed->sciWidget )
   {
      int newLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      int pos = cr->savedPos;
      if( pos > newLen ) pos = newLen;
      SciMsg( ed->sciWidget, SCI_GOTOPOS, pos, 0 );
      SciMsg( ed->sciWidget, SCI_SETFIRSTVISIBLELINE, cr->savedFirst, 0 );
      gtk_widget_grab_focus( ed->sciWidget );
   }
   g_free( cr );
   return G_SOURCE_REMOVE;
}

/* Debounced text-change callback (fires 500ms after last edit) */
static gboolean on_debounce_fire( gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *) data;
   ed->debounceTimer = 0;   /* one-shot: source removed automatically */

   if( ed->pOnTextChange && HB_IS_BLOCK( ed->pOnTextChange ) )
   {
      /* Save cursor position and first visible line */
      int savedPos   = (int) SciMsg( ed->sciWidget, SCI_GETCURRENTPOS, 0, 0 );
      int savedFirst = (int) SciMsg( ed->sciWidget, SCI_GETFIRSTVISIBLELINE, 0, 0 );

      ed->bSettingText = 1;   /* guard: suppress nested SCN_MODIFIED callbacks */

      hb_vmPushEvalSym();
      hb_vmPush( ed->pOnTextChange );
      hb_vmPushNumInt( (HB_PTRUINT) ed );
      hb_vmPushInteger( ed->nActiveTab + 1 );   /* 1-based tab index */
      hb_vmSend( 2 );

      ed->bSettingText = 0;

      /* Schedule cursor restore AFTER all pending GTK events are processed */
      CURSORRESTORE * cr = g_new( CURSORRESTORE, 1 );
      cr->ed         = ed;
      cr->savedPos   = savedPos;
      cr->savedFirst = savedFirst;
      g_idle_add( on_restore_cursor, cr );
   }
   return G_SOURCE_REMOVE;
}

/* Breakpoint storage — defined here so the Scintilla margin-click handler can access it */
#define DBG_MAX_BP 64
typedef struct { char module[256]; int line; } DBGBP;
static DBGBP s_breakpoints[DBG_MAX_BP];
static int   s_nBreakpoints = 0;

/* Scintilla notification handler via GtkWidget "sci-notify" signal */
static void on_sci_notify( GtkWidget * sci, gint id, gpointer scnPtr, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   /* SCNotification layout must match Scintilla's real struct (64-bit safe) */
   struct SCNotification {
      void * hwndFrom;              /* Sci_NotifyHeader */
      uintptr_t idFrom;
      unsigned int code;
      ptrdiff_t position;           /* Sci_Position */
      int ch;
      int modifiers;
      int modificationType;
      const char * text;
      ptrdiff_t length;             /* Sci_Position */
      ptrdiff_t linesAdded;         /* Sci_Position */
      int message;
      uintptr_t wParam;
      intptr_t lParam;
      ptrdiff_t line;               /* Sci_Position */
      int foldLevelNow;
      int foldLevelPrev;
      int margin;
   } * scn = (struct SCNotification *) scnPtr;

   if( !ed || !scn ) return;

   if( scn->code == SCN_MARGINCLICK ) {
      int line = (int) SciMsg( sci, SCI_LINEFROMPOSITION, scn->position, 0 );
      if( scn->margin == 1 ) {
         /* Breakpoint margin — toggle marker 12 and update s_breakpoints[] */
         int lineNum = line + 1;  /* Scintilla is 0-based, breakpoints are 1-based */
         const char * fileName = (ed->nActiveTab >= 0 && ed->nActiveTab < ed->nTabs)
                                 ? ed->tabNames[ed->nActiveTab] : "";
         int hasMarker = (int) SciMsg( sci, SCI_MARKERGET, line, 0 ) & (1 << 12);
         if( hasMarker ) {
            /* Remove breakpoint */
            SciMsg( sci, SCI_MARKERDELETE, line, 12 );
            int i;
            for( i = 0; i < s_nBreakpoints; i++ ) {
               if( s_breakpoints[i].line == lineNum &&
                   strcasecmp( s_breakpoints[i].module, fileName ) == 0 ) {
                  s_nBreakpoints--;
                  if( i < s_nBreakpoints )
                     s_breakpoints[i] = s_breakpoints[s_nBreakpoints];
                  break;
               }
            }
         } else {
            /* Add breakpoint */
            SciMsg( sci, SCI_MARKERADD, line, 12 );
            if( s_nBreakpoints < DBG_MAX_BP ) {
               strncpy( s_breakpoints[s_nBreakpoints].module, fileName, 255 );
               s_breakpoints[s_nBreakpoints].module[255] = 0;
               s_breakpoints[s_nBreakpoints].line = lineNum;
               s_nBreakpoints++;
            }
         }
      } else {
         SciMsg( sci, SCI_TOGGLEFOLD, line, 0 );
      }
   }

   if( scn->code == SCN_CHARADDED ) {
      if( scn->ch == '\n' || scn->ch == '\r' ) {
         int curLine = (int) SciMsg( sci, SCI_LINEFROMPOSITION,
            SciMsg( sci, SCI_GETCURRENTPOS, 0, 0 ), 0 );
         if( curLine > 0 ) {
            int indent = (int) SciMsg( sci, SCI_GETLINEINDENTATION, curLine - 1, 0 );
            SciMsg( sci, SCI_SETLINEINDENTATION, curLine, indent );
            int pos = (int) SciMsg( sci, SCI_GETLINEINDENTPOSITION, curLine, 0 );
            SciMsg( sci, SCI_GOTOPOS, pos, 0 );
         }
      }
      /* ':' typed — show class member dropdown */
      else if( scn->ch == ':' )
      {
         int pos = (int) SciMsg( sci, SCI_GETCURRENTPOS, 0, 0 );
         const char * cls = CE_ResolveVarClass( ed, pos - 1 );
         if( cls )
         {
            const char * members = CE_FindClassMembers( ed, cls );
            if( members )
            {
               SciMsg( sci, SCI_AUTOCSETIGNORECASE, 1, 0 );
               SciMsg( sci, SCI_AUTOCSETSEPARATOR, ' ', 0 );
               SciMsg( sci, SCI_AUTOCSETORDER, 1, 0 );
               SciMsg( sci, SCI_AUTOCSHOW, 0, (intptr_t) members );
            }
         }
      }
   }

   if( scn->code == SCN_UPDATEUI ) {
      UpdateStatusBar( ed );
   }

   if( scn->code == SCN_MODIFIED ) {
      if( scn->modificationType & (0x01|0x02) ) {  /* SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT */
         if( scn->linesAdded != 0 ) {
            static int s_inFoldUpdate = 0;
            if( !s_inFoldUpdate ) {
               s_inFoldUpdate = 1;
               UpdateHarbourFolding( sci );
               s_inFoldUpdate = 0;
            }
         }
         /* Schedule debounced text-change callback (500ms) */
         if( ed->pOnTextChange && !ed->bSettingText )
         {
            if( ed->debounceTimer )
               g_source_remove( ed->debounceTimer );
            ed->debounceTimer = g_timeout_add( 500, on_debounce_fire, ed );
         }
      }
      UpdateStatusBar( ed );
   }
}

/* Key-press handler for Scintilla keyboard shortcuts */
static gboolean on_sci_key_press( GtkWidget * sci, GdkEventKey * ev, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   int ctrl  = (ev->state & GDK_CONTROL_MASK) != 0;
   int shift = (ev->state & GDK_SHIFT_MASK) != 0;

   if( ctrl && (ev->keyval == GDK_KEY_f || ev->keyval == GDK_KEY_F) ) {
      CE_ShowFindBar( ed, !ed->bFindVisible, 0 );
      return TRUE;
   }
   if( ctrl && (ev->keyval == GDK_KEY_h || ev->keyval == GDK_KEY_H) ) {
      CE_ShowFindBar( ed, 1, 1 );
      return TRUE;
   }
   if( ev->keyval == GDK_KEY_Escape && ed->bFindVisible ) {
      CE_ShowFindBar( ed, 0, 0 );
      return TRUE;
   }
   if( ev->keyval == GDK_KEY_F3 ) {
      CE_FindNext( ed, !shift );
      return TRUE;
   }
   if( ctrl && ev->keyval == GDK_KEY_space ) {
      CE_ShowAutoComplete( ed->sciWidget );
      return TRUE;
   }
   if( ctrl && (ev->keyval == GDK_KEY_g || ev->keyval == GDK_KEY_G) && !shift ) {
      SciMsg( ed->sciWidget, SCI_GOTOPOS, 0, 0 );
      return TRUE;
   }
   if( ctrl && ev->keyval == GDK_KEY_slash ) {
      /* Toggle line comment */
      int pos = (int) SciMsg( sci, SCI_GETCURRENTPOS, 0, 0 );
      int line = (int) SciMsg( sci, SCI_LINEFROMPOSITION, pos, 0 );
      int lineStart = (int) SciMsg( sci, SCI_POSITIONFROMLINE, line, 0 );
      int lineLen = (int) SciMsg( sci, SCI_LINELENGTH, line, 0 );
      if( lineLen > 0 && lineLen < 1000 ) {
         char * lineBuf = (char *) malloc( lineLen + 1 );
         SciMsg( sci, SCI_GETLINE, line, (intptr_t) lineBuf );
         lineBuf[lineLen] = 0;
         if( lineBuf[0] == '/' && lineBuf[1] == '/' ) {
            int rmLen = (lineLen > 2 && lineBuf[2] == ' ') ? 3 : 2;
            SciMsg( sci, SCI_SETSEL, lineStart, lineStart + rmLen );
            SciMsg( sci, SCI_REPLACESEL, 0, (intptr_t) "" );
         } else {
            SciMsg( sci, SCI_SETSEL, lineStart, lineStart );
            SciMsg( sci, SCI_REPLACESEL, 0, (intptr_t) "// " );
         }
         free( lineBuf );
      }
      return TRUE;
   }
   if( ctrl && shift && (ev->keyval == GDK_KEY_d || ev->keyval == GDK_KEY_D) ) {
      SciMsg( sci, SCI_LINEDUPLICATE, 0, 0 );
      return TRUE;
   }
   if( ctrl && shift && (ev->keyval == GDK_KEY_k || ev->keyval == GDK_KEY_K) ) {
      SciMsg( sci, SCI_LINEDELETE, 0, 0 );
      return TRUE;
   }
   if( ctrl && (ev->keyval == GDK_KEY_l || ev->keyval == GDK_KEY_L) && !shift ) {
      int pos2 = (int) SciMsg( sci, SCI_GETCURRENTPOS, 0, 0 );
      int ln2 = (int) SciMsg( sci, SCI_LINEFROMPOSITION, pos2, 0 );
      int ls2 = (int) SciMsg( sci, SCI_POSITIONFROMLINE, ln2, 0 );
      int le2 = (int) SciMsg( sci, SCI_POSITIONFROMLINE, ln2 + 1, 0 );
      if( le2 <= ls2 ) le2 = ls2 + (int)SciMsg( sci, SCI_LINELENGTH, ln2, 0 );
      SciMsg( sci, SCI_SETSEL, ls2, le2 );
      return TRUE;
   }

   return FALSE;  /* let Scintilla handle other keys */
}

/* Prevent code editor window close from destroying; just hide */
static gboolean on_editor_delete( GtkWidget * widget, GdkEvent * event, gpointer data )
{
   gtk_widget_hide( widget );
   return TRUE;
}

static void on_editor_tab_switched( GtkNotebook * nb, GtkWidget * page, guint nPage, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   if( !ed || (int)nPage == ed->nActiveTab ) return;

   CE_SwitchTab( ed, (int)nPage );

   if( ed->pOnTabChange && HB_IS_BLOCK( ed->pOnTabChange ) )
   {
      PHB_ITEM pArg1 = hb_itemPutNInt( hb_itemNew(NULL), (HB_PTRUINT) ed );
      PHB_ITEM pArg2 = hb_itemPutNI( hb_itemNew(NULL), (int)nPage + 1 );
      hb_itemDo( ed->pOnTabChange, 2, pArg1, pArg2 );
      hb_itemRelease( pArg1 );
      hb_itemRelease( pArg2 );
   }
}

/* CodeEditorCreate( nLeft, nTop, nWidth, nHeight ) --> hEditor */
HB_FUNC( CODEEDITORCREATE )
{
   EnsureGTK();

   int nLeft   = hb_parni(1);
   int nTop    = hb_parni(2);
   int nWidth  = hb_parni(3);
   int nHeight = hb_parni(4);

   /* Load Scintilla + Lexilla shared libraries */
   if( !InitScintilla() ) {
      fprintf( stderr, "FATAL: Cannot load libscintilla.so / liblexilla.so\n" );
      hb_retnint( 0 );
      return;
   }

   CODEEDITOR * ed = (CODEEDITOR *) calloc( 1, sizeof(CODEEDITOR) );

   /* Window */
   ed->window = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(ed->window), "Code Editor" );
   gtk_window_set_default_size( GTK_WINDOW(ed->window), nWidth, nHeight );
   gtk_window_move( GTK_WINDOW(ed->window), nLeft, nTop );
   g_signal_connect( ed->window, "delete-event", G_CALLBACK(on_editor_delete), ed );

   /* VBox: tab bar + scintilla + find bar + status bar */
   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(ed->window), vbox );

   /* Tab bar using GtkNotebook */
   ed->tabBar = gtk_notebook_new();
   gtk_notebook_set_show_border( GTK_NOTEBOOK(ed->tabBar), FALSE );
   strncpy( ed->tabNames[0], "Project1.prg", 63 );
   ed->tabTexts[0] = strdup( "" );
   ed->nTabs = 1;
   ed->nActiveTab = 0;
   ed->pOnTabChange = NULL;
   GtkWidget * dummyPage = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
   GtkWidget * tabLabel = gtk_label_new( ed->tabNames[0] );
   gtk_notebook_append_page( GTK_NOTEBOOK(ed->tabBar), dummyPage, tabLabel );
   gtk_box_pack_start( GTK_BOX(vbox), ed->tabBar, FALSE, FALSE, 0 );

   /* Create Scintilla editor widget */
   ed->sciWidget = s_pScintillaNew();

   if( ed->sciWidget )
   {
      gtk_widget_set_hexpand( ed->sciWidget, TRUE );
      gtk_widget_set_vexpand( ed->sciWidget, TRUE );
      gtk_box_pack_start( GTK_BOX(vbox), ed->sciWidget, TRUE, TRUE, 0 );

      ConfigureScintilla( ed->sciWidget );

      /* Connect Scintilla notification signal */
      g_signal_connect( ed->sciWidget, "sci-notify", G_CALLBACK(on_sci_notify), ed );

      /* Connect keyboard shortcuts */
      g_signal_connect( ed->sciWidget, "key-press-event", G_CALLBACK(on_sci_key_press), ed );
   }
   else
   {
      fprintf( stderr, "FAILED to create Scintilla widget!\n" );
   }

   /* Find/Replace bar (initially hidden) */
   {
      GtkWidget * findBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
      gtk_box_pack_start( GTK_BOX(vbox), findBox, FALSE, FALSE, 0 );
      ed->findBar = findBox;

      GtkWidget * lblFind = gtk_label_new( "Find:" );
      gtk_box_pack_start( GTK_BOX(findBox), lblFind, FALSE, FALSE, 4 );

      ed->findEntry = gtk_entry_new();
      gtk_entry_set_width_chars( GTK_ENTRY(ed->findEntry), 25 );
      gtk_box_pack_start( GTK_BOX(findBox), ed->findEntry, FALSE, FALSE, 0 );
      g_signal_connect( ed->findEntry, "key-press-event", G_CALLBACK(on_find_entry_key), ed );

      GtkWidget * btnNext = gtk_button_new_with_label( "Next" );
      gtk_box_pack_start( GTK_BOX(findBox), btnNext, FALSE, FALSE, 0 );
      g_signal_connect( btnNext, "clicked", G_CALLBACK(on_find_next_clicked), ed );

      GtkWidget * btnPrev = gtk_button_new_with_label( "Prev" );
      gtk_box_pack_start( GTK_BOX(findBox), btnPrev, FALSE, FALSE, 0 );
      g_signal_connect( btnPrev, "clicked", G_CALLBACK(on_find_prev_clicked), ed );

      ed->findLabel = gtk_label_new( "" );
      gtk_box_pack_start( GTK_BOX(findBox), ed->findLabel, FALSE, FALSE, 4 );

      ed->replaceLbl = gtk_label_new( "Replace:" );
      gtk_box_pack_start( GTK_BOX(findBox), ed->replaceLbl, FALSE, FALSE, 4 );

      ed->replaceEntry = gtk_entry_new();
      gtk_entry_set_width_chars( GTK_ENTRY(ed->replaceEntry), 25 );
      gtk_box_pack_start( GTK_BOX(findBox), ed->replaceEntry, FALSE, FALSE, 0 );
      g_signal_connect( ed->replaceEntry, "key-press-event", G_CALLBACK(on_find_entry_key), ed );

      ed->replaceBtn = gtk_button_new_with_label( "Replace" );
      gtk_box_pack_start( GTK_BOX(findBox), ed->replaceBtn, FALSE, FALSE, 0 );
      g_signal_connect( ed->replaceBtn, "clicked", G_CALLBACK(on_replace_clicked), ed );

      ed->replaceAllBtn = gtk_button_new_with_label( "All" );
      gtk_box_pack_start( GTK_BOX(findBox), ed->replaceAllBtn, FALSE, FALSE, 0 );
      g_signal_connect( ed->replaceAllBtn, "clicked", G_CALLBACK(on_replace_all_clicked), ed );

      GtkWidget * btnClose = gtk_button_new_with_label( "X" );
      gtk_box_pack_end( GTK_BOX(findBox), btnClose, FALSE, FALSE, 0 );
      g_signal_connect( btnClose, "clicked", G_CALLBACK(on_find_close_clicked), ed );

      /* Apply dark theme CSS to find bar */
      {
         GtkCssProvider * provider = gtk_css_provider_new();
         const char * css =
            "box { background-color: #252526; }"
            "entry { background-color: #3C3C3C; color: #D4D4D4;"
            "  border-color: #555; }"
            "button { background-color: #3C3C3C; color: #D4D4D4;"
            "  border-color: #555; }"
            "label { color: #D4D4D4; }";
         gtk_css_provider_load_from_data( provider, css, -1, NULL );
         GtkStyleContext * ctx = gtk_widget_get_style_context( findBox );
         gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
            GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
         g_object_unref( provider );
      }

      /* Show all children so they're ready, then hide the bar and replace widgets */
      gtk_widget_show_all( findBox );
      gtk_widget_hide( findBox );
      gtk_widget_hide( ed->replaceLbl );
      gtk_widget_hide( ed->replaceEntry );
      gtk_widget_hide( ed->replaceBtn );
      gtk_widget_hide( ed->replaceAllBtn );
      ed->bFindVisible = 0;
      ed->bReplaceVisible = 0;
   }

   /* Status bar at bottom */
   ed->statusBar = gtk_label_new( "  Ln 1, Col 1      INS      0 lines      0 chars      UTF-8" );
   gtk_label_set_xalign( GTK_LABEL(ed->statusBar), 0.0 );
   gtk_widget_set_size_request( ed->statusBar, -1, STATUSBAR_HEIGHT );
   gtk_box_pack_start( GTK_BOX(vbox), ed->statusBar, FALSE, FALSE, 0 );

   /* Dark theme for status bar */
   {
      GtkCssProvider * provider = gtk_css_provider_new();
      const char * css =
         "label { background-color: #252526; color: #B4B4B4;"
         "  font-family: \"Monospace\"; font-size: 10pt; padding: 2px 4px; }";
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( ed->statusBar );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
      g_object_unref( provider );
   }

   /* Tab switch callback */
   g_signal_connect( ed->tabBar, "switch-page", G_CALLBACK(on_editor_tab_switched), ed );

   gtk_widget_show_all( ed->window );
   /* Re-hide find bar and replace widgets after show_all */
   gtk_widget_hide( ed->findBar );
   gtk_widget_hide( ed->replaceLbl );
   gtk_widget_hide( ed->replaceEntry );
   gtk_widget_hide( ed->replaceBtn );
   gtk_widget_hide( ed->replaceAllBtn );

   hb_retnint( (HB_PTRUINT) ed );
}

/* CodeEditorSetText( hEditor, cText ) */
HB_FUNC( CODEEDITORSETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget && HB_ISCHAR(2) )
   {
      SciMsg( ed->sciWidget, SCI_SETTEXT, 0, (intptr_t) hb_parc(2) );
      SciMsg( ed->sciWidget, SCI_EMPTYUNDOBUFFER, 0, 0 );
      UpdateHarbourFolding( ed->sciWidget );
   }
}

/* CodeEditorGetText( hEditor ) --> cText */
HB_FUNC( CODEEDITORGETTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget )
   {
      int nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      char * buf = (char *) malloc( nLen + 1 );
      SciMsg( ed->sciWidget, SCI_GETTEXT, nLen + 1, (intptr_t) buf );
      hb_retclen( buf, nLen );
      free( buf );
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
      if( ed->pOnTabChange ) hb_itemRelease( ed->pOnTabChange );
      for( int i = 0; i < ed->nTabs; i++ )
         if( ed->tabTexts[i] ) free( ed->tabTexts[i] );
      if( ed->window ) gtk_widget_destroy( ed->window );
      free( ed );
   }
}

/* ======================================================================
 * Code Editor - clipboard, undo/redo, find/replace operations
 * ====================================================================== */

#define SCI_UNDO       2176
#define SCI_REDO       2011
#define SCI_CUT        2177
#define SCI_COPY       2178
#define SCI_PASTE      2179
#define SCI_SELECTALL  2013
#define SCI_CANUNDO    2174
#define SCI_CANREDO    2016

/* CodeEditorUndo( hEditor ) */
HB_FUNC( CODEEDITORUNDO )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget ) SciMsg( ed->sciWidget, SCI_UNDO, 0, 0 );
}

/* CodeEditorRedo( hEditor ) */
HB_FUNC( CODEEDITORREDO )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget ) SciMsg( ed->sciWidget, SCI_REDO, 0, 0 );
}

/* CodeEditorCut( hEditor ) */
HB_FUNC( CODEEDITORCUT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget ) SciMsg( ed->sciWidget, SCI_CUT, 0, 0 );
}

/* CodeEditorCopy( hEditor ) */
HB_FUNC( CODEEDITORCOPY )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget ) SciMsg( ed->sciWidget, SCI_COPY, 0, 0 );
}

/* CodeEditorPaste( hEditor ) */
HB_FUNC( CODEEDITORPASTE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget ) SciMsg( ed->sciWidget, SCI_PASTE, 0, 0 );
}

/* CodeEditorFind( hEditor ) - show find bar */
HB_FUNC( CODEEDITORFIND )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_ShowFindBar( ed, 1, 0 );
}

/* CodeEditorReplace( hEditor ) - show find+replace bar */
HB_FUNC( CODEEDITORREPLACE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_ShowFindBar( ed, 1, 1 );
}

/* CodeEditorFindNext( hEditor ) */
HB_FUNC( CODEEDITORFINDNEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_FindNext( ed, 1 );
}

/* CodeEditorFindPrev( hEditor ) */
HB_FUNC( CODEEDITORFINDPREV )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed ) CE_FindNext( ed, 0 );
}

/* CodeEditorAutoComplete( hEditor ) */
HB_FUNC( CODEEDITORAUTOCOMPLETE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget ) CE_ShowAutoComplete( ed->sciWidget );
}

/* UI_FormAlignSelected( hForm, nMode ) - align selected controls
 * Modes: 1=left, 2=right, 3=top, 4=bottom, 5=centerH, 6=centerV, 7=spaceH, 8=spaceV */
HB_FUNC( UI_FORMALIGNSELECTED )
{
   HBForm * form = GetForm(1);
   int nMode = hb_parni(2);
   int nSel, i;

   if( !form || !form->FFixed || nMode < 1 || nMode > 8 ) return;
   nSel = form->FSelCount;
   if( nSel < 2 ) return;

   /* Reference = first selected control */
   HBControl * ref = form->FSelected[0];
   int refX = ref->FLeft, refY = ref->FTop;
   int refR = refX + ref->FWidth, refB = refY + ref->FHeight;
   int refCX = refX + ref->FWidth / 2, refCY = refY + ref->FHeight / 2;

   /* Find bounds for spacing */
   int minX = refX, maxR = refR, minY = refY, maxB = refB;
   for( i = 1; i < nSel; i++ ) {
      HBControl * c = form->FSelected[i];
      if( c->FLeft < minX ) minX = c->FLeft;
      if( c->FLeft + c->FWidth > maxR ) maxR = c->FLeft + c->FWidth;
      if( c->FTop < minY ) minY = c->FTop;
      if( c->FTop + c->FHeight > maxB ) maxB = c->FTop + c->FHeight;
   }

   for( i = 1; i < nSel; i++ )
   {
      HBControl * c = form->FSelected[i];
      int newX = c->FLeft, newY = c->FTop;

      switch( nMode ) {
         case 1: newX = refX; break;
         case 2: newX = refR - c->FWidth; break;
         case 3: newY = refY; break;
         case 4: newY = refB - c->FHeight; break;
         case 5: newX = refCX - c->FWidth / 2; break;
         case 6: newY = refCY - c->FHeight / 2; break;
         case 7: case 8:
         {
            int totalW = 0, totalH = 0, gap, j;
            for( j = 0; j < nSel; j++ ) {
               totalW += form->FSelected[j]->FWidth;
               totalH += form->FSelected[j]->FHeight;
            }
            if( nMode == 7 ) {
               gap = (nSel > 1) ? (maxR - minX - totalW) / (nSel - 1) : 0;
               int cx = minX;
               for( j = 0; j < nSel; j++ ) {
                  HBControl * cj = form->FSelected[j];
                  cj->FLeft = cx;
                  if( cj->FWidget ) gtk_fixed_move( GTK_FIXED(form->FFixed), cj->FWidget, cx, cj->FTop );
                  cx += cj->FWidth + gap;
               }
            } else {
               gap = (nSel > 1) ? (maxB - minY - totalH) / (nSel - 1) : 0;
               int cy = minY;
               for( j = 0; j < nSel; j++ ) {
                  HBControl * cj = form->FSelected[j];
                  cj->FTop = cy;
                  if( cj->FWidget ) gtk_fixed_move( GTK_FIXED(form->FFixed), cj->FWidget, cj->FLeft, cy );
                  cy += cj->FHeight + gap;
               }
            }
            if( form->FOverlay ) gtk_widget_queue_draw( form->FOverlay );
            return;
         }
      }

      c->FLeft = newX; c->FTop = newY;
      if( c->FWidget ) gtk_fixed_move( GTK_FIXED(form->FFixed), c->FWidget, newX, newY );
   }

   if( form->FOverlay ) gtk_widget_queue_draw( form->FOverlay );
}

/* ======================================================================
 * BMP Strip Loader - slice a BMP strip into 32x32 icons with magenta transparency
 * ====================================================================== */

static GdkPixbuf ** SliceBmpStrip( const char * szPath, int * outCount )
{
   *outCount = 0;
   GError * err = NULL;
   GdkPixbuf * strip = gdk_pixbuf_new_from_file( szPath, &err );
   if( !strip ) { if( err ) g_error_free( err ); return NULL; }

   int pixelW = gdk_pixbuf_get_width( strip );
   int pixelH = gdk_pixbuf_get_height( strip );
   int iconW = 32, iconH = pixelH;
   int nIcons = pixelW / iconW;
   if( nIcons <= 0 ) { g_object_unref( strip ); return NULL; }

   GdkPixbuf ** icons = (GdkPixbuf **) calloc( nIcons, sizeof(GdkPixbuf*) );

   for( int i = 0; i < nIcons; i++ )
   {
      /* Extract tile from strip */
      GdkPixbuf * tile = gdk_pixbuf_new( GDK_COLORSPACE_RGB, TRUE, 8, iconW, iconH );
      gdk_pixbuf_copy_area( strip, i * iconW, 0, iconW, iconH, tile, 0, 0 );

      /* Ensure alpha channel */
      GdkPixbuf * rgba = tile;
      if( !gdk_pixbuf_get_has_alpha( tile ) )
      {
         rgba = gdk_pixbuf_add_alpha( tile, FALSE, 0, 0, 0 );
         g_object_unref( tile );
      }

      /* Replace magenta (R>240, G<16, B>240) with transparent */
      int rowstride = gdk_pixbuf_get_rowstride( rgba );
      int nChannels = gdk_pixbuf_get_n_channels( rgba );
      guchar * pixels = gdk_pixbuf_get_pixels( rgba );
      int w = gdk_pixbuf_get_width( rgba );
      int h = gdk_pixbuf_get_height( rgba );

      for( int y = 0; y < h; y++ )
      {
         guchar * row = pixels + y * rowstride;
         for( int x = 0; x < w; x++ )
         {
            guchar r = row[x * nChannels];
            guchar g = row[x * nChannels + 1];
            guchar b = row[x * nChannels + 2];
            if( r > 240 && g < 16 && b > 240 )
            {
               row[x * nChannels]     = 0;
               row[x * nChannels + 1] = 0;
               row[x * nChannels + 2] = 0;
               row[x * nChannels + 3] = 0;
            }
         }
      }

      icons[i] = rgba;
   }

   g_object_unref( strip );
   *outCount = nIcons;
   return icons;
}

/* Apply stored toolbar icons to the GtkToolbar widget */
static void HBToolBar_ApplyIcons( HBToolBar * tb )
{
   if( !tb->FToolBarWidget || tb->FIconCount <= 0 ) return;

   GList * items = gtk_container_get_children( GTK_CONTAINER(tb->FToolBarWidget) );
   int imgIdx = 0;
   for( GList * l = items; l != NULL; l = l->next )
   {
      if( imgIdx >= tb->FIconCount ) break;
      GtkWidget * item = GTK_WIDGET( l->data );
      if( !GTK_IS_TOOL_BUTTON(item) ) continue;  /* skip separators */

      GdkPixbuf * scaled = gdk_pixbuf_scale_simple( tb->FIconImages[imgIdx], 20, 20, GDK_INTERP_BILINEAR );
      GtkWidget * img = gtk_image_new_from_pixbuf( scaled );
      g_object_unref( scaled );

      gtk_tool_button_set_icon_widget( GTK_TOOL_BUTTON(item), img );
      gtk_tool_button_set_label( GTK_TOOL_BUTTON(item), NULL );
      gtk_widget_show( img );
      imgIdx++;
   }
   g_list_free( items );
}

/* UI_ToolBarLoadImages( hToolBar, cBmpPath )
 * Load a BMP strip of 32x32 icons and apply to toolbar buttons.
 * Magenta (255,0,255) is treated as transparency mask. */
HB_FUNC( UI_TOOLBARLOADIMAGES )
{
   HBToolBar * p = (HBToolBar *) GetCtrl(1);
   const char * szPath = hb_parc(2);
   if( !p || p->base.FControlType != CT_TOOLBAR || !szPath ) return;

   int nIcons = 0;
   GdkPixbuf ** icons = SliceBmpStrip( szPath, &nIcons );
   if( !icons || nIcons == 0 ) return;

   /* Store icons for deferred application (toolbar widget may not exist yet) */
   int nStore = nIcons < MAX_TOOLBTNS ? nIcons : MAX_TOOLBTNS;
   for( int i = 0; i < nStore; i++ )
      p->FIconImages[i] = icons[i];  /* transfer ownership */
   /* Free any extra beyond MAX_TOOLBTNS */
   for( int i = nStore; i < nIcons; i++ )
      if( icons[i] ) g_object_unref( icons[i] );
   free( icons );
   p->FIconCount = nStore;

   /* If toolbar widget already exists, apply icons now */
   if( p->FToolBarWidget )
      HBToolBar_ApplyIcons( p );
}

/* UI_PaletteLoadImages( hPalette, cBmpPath )
 * Load a BMP strip of 32x32 icons for component palette buttons.
 * Magenta (255,0,255) is treated as transparency mask. */
HB_FUNC( UI_PALETTELOADIMAGES )
{
   PALDATA * pd = s_palData;
   const char * szPath = hb_parc(2);
   if( !pd || !szPath ) return;

   int nIcons = 0;
   GdkPixbuf ** icons = SliceBmpStrip( szPath, &nIcons );
   if( !icons || nIcons == 0 ) return;

   /* Apply icons to palette buttons. Icons in palette.bmp are laid out
      sequentially following AddComp() order across tabs (not keyed by
      nControlType), matching the macOS layout. */
   int imgBase = 0;
   for( int t = 0; t < pd->nTabCount; t++ )
   {
      GtkWidget * box = pd->tabBoxes[t];
      PaletteTab * pt = &pd->tabs[t];
      if( !box ) { imgBase += pt->nBtnCount; continue; }

      GList * children = gtk_container_get_children( GTK_CONTAINER(box) );
      int btnIdx = 0;
      for( GList * l = children; l != NULL; l = l->next )
      {
         GtkWidget * btn = GTK_WIDGET( l->data );
         if( !GTK_IS_BUTTON(btn) ) continue;
         if( btnIdx >= pt->nBtnCount ) break;

         int imgIdx = imgBase + btnIdx;
         int nCtrlType = pt->btns[btnIdx].nControlType;
         if( imgIdx >= 0 && imgIdx < nIcons && icons[imgIdx] )
         {
            GdkPixbuf * scaled = gdk_pixbuf_scale_simple( icons[imgIdx], 28, 28, GDK_INTERP_BILINEAR );
            GtkWidget * img = gtk_image_new_from_pixbuf( scaled );
            g_object_unref( scaled );

            gtk_button_set_label( GTK_BUTTON(btn), NULL );
            gtk_button_set_image( GTK_BUTTON(btn), img );
            gtk_button_set_always_show_image( GTK_BUTTON(btn), TRUE );
         }

         /* Cache icon by control type for non-visual component markers */
         if( nCtrlType > 0 && nCtrlType < MAX_ICON_CACHE &&
             imgIdx >= 0 && imgIdx < nIcons && icons[imgIdx] )
         {
            if( s_paletteIcons[nCtrlType] )
               g_object_unref( s_paletteIcons[nCtrlType] );
            s_paletteIcons[nCtrlType] = g_object_ref( icons[imgIdx] );
         }
         btnIdx++;
      }
      g_list_free( children );
      imgBase += pt->nBtnCount;
   }

   /* Release slice array (cache took its own refs above) */
   for( int i = 0; i < nIcons; i++ )
      if( icons[i] ) g_object_unref( icons[i] );
   free( icons );
}

/* ======================================================================
 * New HbBuilder functions (ported from macOS Cocoa backend)
 * ====================================================================== */

/* UI_SetDesignForm( hForm ) - set active design form for palette drops */
HB_FUNC( UI_SETDESIGNFORM )
{
   HBForm * p = GetForm(1);
   s_designForm = p;
}

/* UI_FormBringToFront( hForm ) */
HB_FUNC( UI_FORMBRINGTOFRONT )
{
   HBForm * p = GetForm(1);
   if( p && p->FWindow )
      gtk_window_present( GTK_WINDOW(p->FWindow) );
}

/* UI_FormHide( hForm ) */
HB_FUNC( UI_FORMHIDE )
{
   HBForm * p = GetForm(1);
   if( p && p->FWindow )
      gtk_widget_hide( p->FWindow );
}

/* UI_FormIsVisible( hForm ) */
HB_FUNC( UI_FORMISVISIBLE )
{
   HBForm * p = GetForm(1);
   hb_retl( p && p->FWindow && gtk_widget_get_visible( p->FWindow ) );
}

/* UI_FormIsKeyWindow( hForm ) - is this form the currently focused window? */
HB_FUNC( UI_FORMISKEYWINDOW )
{
   HBForm * p = GetForm(1);
   hb_retl( p && p->FWindow && gtk_window_is_active( GTK_WINDOW(p->FWindow) ) );
}

/* UI_ToolBtnHighlight( hToolbar, nBtn, lHighlight ) */
HB_FUNC( UI_TOOLBTNHIGHLIGHT )
{
   HBToolBar * p = (HBToolBar *)(HB_PTRUINT) hb_parnint(1);
   int nBtn = hb_parni(2) - 1;
   HB_BOOL bHigh = hb_parl(3);
   if( !p || p->base.FControlType != CT_TOOLBAR || !p->FToolBarWidget ) return;

   /* Walk through toolbar items to find the nth non-separator button */
   GList * children = gtk_container_get_children( GTK_CONTAINER(p->FToolBarWidget) );
   int idx = 0;
   for( GList * l = children; l; l = l->next )
   {
      GtkWidget * item = GTK_WIDGET(l->data);
      if( GTK_IS_TOOL_BUTTON(item) )
      {
         if( idx == nBtn )
         {
            /* Get the actual button widget inside the GtkToolButton */
            GtkWidget * btn = gtk_bin_get_child( GTK_BIN(item) );
            if( !btn ) btn = item;

            if( bHigh )
            {
               GtkCssProvider * cp = gtk_css_provider_new();
               gtk_css_provider_load_from_data( cp,
                  "* { background-color: rgba(200,50,50,0.5); }", -1, NULL );
               gtk_style_context_add_provider(
                  gtk_widget_get_style_context( btn ),
                  GTK_STYLE_PROVIDER(cp), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 1 );
               g_object_set_data_full( G_OBJECT(item), "dbg-highlight", cp, g_object_unref );
            }
            else
            {
               GtkCssProvider * cp = g_object_get_data( G_OBJECT(item), "dbg-highlight" );
               if( cp )
               {
                  gtk_style_context_remove_provider(
                     gtk_widget_get_style_context( btn ),
                     GTK_STYLE_PROVIDER(cp) );
                  g_object_set_data( G_OBJECT(item), "dbg-highlight", NULL );
               }
            }
            break;
         }
         idx++;
      }
   }
   g_list_free( children );
}

/* UI_FormClearChildren( hForm ) - remove all child controls */
HB_FUNC( UI_FORMCLEARCHILDREN )
{
   HBForm * pForm = GetForm(1);
   if( !pForm ) return;

   /* Remove child widgets from GtkFixed */
   if( pForm->FFixed )
   {
      GList * children = gtk_container_get_children( GTK_CONTAINER(pForm->FFixed) );
      for( GList * l = children; l; l = l->next )
         gtk_container_remove( GTK_CONTAINER(pForm->FFixed), GTK_WIDGET(l->data) );
      g_list_free( children );
   }

   /* Release child objects (free type-specific Harbour items first) */
   for( int i = 0; i < pForm->base.FChildCount; i++ )
   {
      HBControl * c = pForm->base.FChildren[i];
      if( c->FControlType == CT_MAINMENU ) {
         HBMainMenu * m = (HBMainMenu *)c;
         if( m->FOnClickArray ) { hb_itemRelease( m->FOnClickArray ); m->FOnClickArray = NULL; }
      }
      if( c->FControlType == CT_TIMER ) {
         HBTimer * t = (HBTimer *)c;
         if( t->FOnTimer ) { hb_itemRelease( t->FOnTimer ); t->FOnTimer = NULL; }
      }
      RemoveControl( c );
      pForm->base.FChildren[i] = NULL;
   }
   pForm->base.FChildCount = 0;

   /* Clear selection */
   HBForm_ClearSelection( pForm );

   /* Redraw overlay */
   if( pForm->FOverlay )
      gtk_widget_queue_draw( pForm->FOverlay );
}

/* UI_FormOnComponentDrop( hForm, bBlock ) */
HB_FUNC( UI_FORMONCOMPONENTDROP )
{
   HBForm * p = GetForm(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( p ) {
      if( p->FOnComponentDrop ) hb_itemRelease( p->FOnComponentDrop );
      p->FOnComponentDrop = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* UI_FormSetPending( hForm, nControlType ) - set pending control type for palette drop */
HB_FUNC( UI_FORMSETPENDING )
{
   HBForm * p = GetForm(1);
   if( p ) {
      p->FPendingControlType = hb_parni(2);
      /* Change cursor to crosshair when in drop mode */
      if( p->FPendingControlType >= 0 && p->FWindow )
      {
         GdkCursor * cursor = gdk_cursor_new_from_name(
            gdk_display_get_default(), "crosshair" );
         gdk_window_set_cursor( gtk_widget_get_window(p->FWindow), cursor );
         g_object_unref( cursor );
      }
      else if( p->FWindow )
         gdk_window_set_cursor( gtk_widget_get_window(p->FWindow), NULL );
   }
}

/* UI_GetAllEvents( hCtrl ) --> aEvents
 * Each event: { cName, lAssigned, cCategory } */
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
         HBForm * f = (HBForm *)( (char*)p - offsetof(HBForm, base) );
         ADD_E("OnClick",       f->base.FOnClick != NULL,  "Action");
         ADD_E("OnDblClick",    f->FOnDblClick != NULL,    "Action");
         ADD_E("OnCreate",      f->FOnCreate != NULL,      "Lifecycle");
         ADD_E("OnDestroy",     f->FOnDestroy != NULL,     "Lifecycle");
         ADD_E("OnShow",        f->FOnShow != NULL,        "Lifecycle");
         ADD_E("OnHide",        f->FOnHide != NULL,        "Lifecycle");
         ADD_E("OnClose",       f->base.FOnClose != NULL,  "Lifecycle");
         ADD_E("OnCloseQuery",  f->FOnCloseQuery != NULL,  "Lifecycle");
         ADD_E("OnActivate",    f->FOnActivate != NULL,    "Lifecycle");
         ADD_E("OnDeactivate",  f->FOnDeactivate != NULL,  "Lifecycle");
         ADD_E("OnResize",      f->FOnResize != NULL,      "Layout");
         ADD_E("OnPaint",       f->FOnPaint != NULL,       "Layout");
         ADD_E("OnKeyDown",     f->FOnKeyDown != NULL,     "Keyboard");
         ADD_E("OnKeyUp",       f->FOnKeyUp != NULL,       "Keyboard");
         ADD_E("OnKeyPress",    f->FOnKeyPress != NULL,    "Keyboard");
         ADD_E("OnMouseDown",   f->FOnMouseDown != NULL,   "Mouse");
         ADD_E("OnMouseUp",     f->FOnMouseUp != NULL,     "Mouse");
         ADD_E("OnMouseMove",   f->FOnMouseMove != NULL,   "Mouse");
         ADD_E("OnMouseWheel",  f->FOnMouseWheel != NULL,  "Mouse");
         break;
      }
      case CT_BUTTON:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnKeyUp",    0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         break;
      case CT_EDIT:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnKeyUp",    0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         ADD_E("OnMouseUp",  0,                    "Mouse");
         break;
      case CT_CHECKBOX:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_COMBOBOX:
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnEnter",    0,                    "Focus");
         ADD_E("OnExit",     0,                    "Focus");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_LABEL:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnDblClick", 0,                    "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_GROUPBOX:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
      case CT_TIMER:
         ADD_E("OnTimer",    ((HBTimer*)p)->FOnTimer != NULL, "Action");
         break;
      default:
         ADD_E("OnClick",    p->FOnClick != NULL,  "Action");
         ADD_E("OnChange",   p->FOnChange != NULL, "Action");
         ADD_E("OnKeyDown",  0,                    "Keyboard");
         ADD_E("OnMouseDown",0,                    "Mouse");
         break;
   }
   #undef ADD_E
   hb_itemReturnRelease(pArray);
}

/* ======================================================================
 * Code Editor - Tab support functions
 * ====================================================================== */

/* CodeEditorAddTab( hEditor, cName ) --> nTabCount */
HB_FUNC( CODEEDITORADDTAB )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->tabBar || !HB_ISCHAR(2) || ed->nTabs >= CE_MAX_TABS )
   { hb_retni(0); return; }

   const char * name = hb_parc(2);
   strncpy( ed->tabNames[ed->nTabs], name, 63 );
   ed->tabTexts[ed->nTabs] = strdup( "" );
   ed->nTabs++;

   /* Add new page to notebook */
   GtkWidget * dummyPage = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
   GtkWidget * label = gtk_label_new( name );
   g_signal_handlers_block_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );
   gtk_notebook_append_page( GTK_NOTEBOOK(ed->tabBar), dummyPage, label );
   gtk_widget_show_all( dummyPage );
   g_signal_handlers_unblock_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );

   hb_retni( ed->nTabs );
}

/* CodeEditorSetTabText( hEditor, nTab, cText ) */
HB_FUNC( CODEEDITORSETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;
   if( !ed || nTab < 0 || nTab >= ed->nTabs || !HB_ISCHAR(3) ) return;

   if( ed->tabTexts[nTab] ) free( ed->tabTexts[nTab] );
   ed->tabTexts[nTab] = strdup( hb_parc(3) );

   /* If this is the active tab, update Scintilla */
   if( nTab == ed->nActiveTab && ed->sciWidget )
   {
      ed->bSettingText = 1;
      SciMsg( ed->sciWidget, SCI_SETTEXT, 0, (intptr_t) ed->tabTexts[nTab] );
      SciMsg( ed->sciWidget, SCI_EMPTYUNDOBUFFER, 0, 0 );
      UpdateHarbourFolding( ed->sciWidget );
      ed->bSettingText = 0;
   }
}

/* CodeEditorGetTabText( hEditor, nTab ) --> cText */
HB_FUNC( CODEEDITORGETTABTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;
   if( !ed || nTab < 0 || nTab >= ed->nTabs ) { hb_retc(""); return; }

   /* If active tab, read from Scintilla (may have been edited) */
   if( nTab == ed->nActiveTab && ed->sciWidget )
   {
      int nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      char * buf = (char *) malloc( nLen + 1 );
      SciMsg( ed->sciWidget, SCI_GETTEXT, nLen + 1, (intptr_t) buf );
      hb_retclen( buf, nLen );
      free( buf );
   }
   else
      hb_retc( ed->tabTexts[nTab] ? ed->tabTexts[nTab] : "" );
}

/* CodeEditorSelectTab( hEditor, nTab ) */
HB_FUNC( CODEEDITORSELECTTAB )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;
   if( !ed || !ed->tabBar || nTab < 0 || nTab >= ed->nTabs ) return;

   /* Block signal to prevent recursive callback */
   g_signal_handlers_block_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );
   CE_SwitchTab( ed, nTab );
   gtk_notebook_set_current_page( GTK_NOTEBOOK(ed->tabBar), nTab );
   g_signal_handlers_unblock_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );
}

/* CodeEditorShowDebugLine( hEditor, nLine ) — highlight execution line
 * Clears previous marker, sets marker 11 on nLine, scrolls to it.
 * nLine is 1-based (Harbour convention). Pass 0 to clear. */
static int s_dbgPrevLine = -1;

HB_FUNC( CODEEDITORSHOWDEBUGLINE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nLine = hb_parni(2) - 1;  /* convert to 0-based */
   if( !ed || !ed->sciWidget ) return;

   /* Delete previous marker explicitly, then delete all as safety net */
   if( s_dbgPrevLine >= 0 )
      SciMsg( ed->sciWidget, SCI_MARKERDELETE, (uintptr_t)s_dbgPrevLine, 11 );
   SciMsg( ed->sciWidget, SCI_MARKERDELETEALL, 11, 0 );

   if( nLine >= 0 )
   {
      /* Set marker on the line */
      SciMsg( ed->sciWidget, SCI_MARKERADD, (uintptr_t)nLine, 11 );
      s_dbgPrevLine = nLine;

      /* Scroll to make line visible and position cursor */
      SciMsg( ed->sciWidget, SCI_GOTOLINE, (uintptr_t)nLine, 0 );
      SciMsg( ed->sciWidget, SCI_SETFIRSTVISIBLELINE,
              (uintptr_t)(nLine > 5 ? nLine - 5 : 0), 0 );

      /* Bring editor window to front */
      if( ed->window )
         gtk_window_present( GTK_WINDOW(ed->window) );
   }
   else
   {
      s_dbgPrevLine = -1;
   }

   /* Force Scintilla to fully repaint */
   {
      ssize_t len = SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      SciMsg( ed->sciWidget, 4003, 0, len );  /* SCI_COLOURISE */
   }
   gtk_widget_queue_draw( ed->sciWidget );
}

/* CodeEditorClearTabs( hEditor ) - reset to single Project1.prg tab */
HB_FUNC( CODEEDITORCLEARTABS )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed ) return;

   for( int i = 1; i < ed->nTabs; i++ )
   {
      if( ed->tabTexts[i] ) { free( ed->tabTexts[i] ); ed->tabTexts[i] = NULL; }
      ed->tabNames[i][0] = 0;
   }

   /* Remove extra notebook pages */
   g_signal_handlers_block_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );
   while( gtk_notebook_get_n_pages( GTK_NOTEBOOK(ed->tabBar) ) > 1 )
      gtk_notebook_remove_page( GTK_NOTEBOOK(ed->tabBar), -1 );
   g_signal_handlers_unblock_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );

   ed->nTabs = 1;
   ed->nActiveTab = 0;

   if( ed->sciWidget )
      SciMsg( ed->sciWidget, SCI_SETTEXT, 0, (intptr_t) "" );
}

/* CodeEditorRemoveTab( hEditor, nTab ) - remove a tab (1-based) */
HB_FUNC( CODEEDITORREMOVETAB )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int nTab = hb_parni(2) - 1;  /* convert to 0-based */
   int i;
   if( !ed || !ed->tabBar || nTab < 0 || nTab >= ed->nTabs || ed->nTabs <= 1 )
      return;

   /* Free the text for this tab */
   if( ed->tabTexts[nTab] ) { free( ed->tabTexts[nTab] ); ed->tabTexts[nTab] = NULL; }

   /* Shift remaining tabs down */
   for( i = nTab; i < ed->nTabs - 1; i++ )
   {
      strncpy( ed->tabNames[i], ed->tabNames[i+1], 63 );
      ed->tabNames[i][63] = 0;
      ed->tabTexts[i] = ed->tabTexts[i+1];
   }
   ed->tabTexts[ed->nTabs - 1] = NULL;
   ed->tabNames[ed->nTabs - 1][0] = 0;
   ed->nTabs--;

   /* Remove the notebook page */
   g_signal_handlers_block_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );
   gtk_notebook_remove_page( GTK_NOTEBOOK(ed->tabBar), nTab );
   g_signal_handlers_unblock_matched( ed->tabBar, G_SIGNAL_MATCH_FUNC,
      0, 0, NULL, (gpointer)on_editor_tab_switched, NULL );

   /* Adjust active tab if needed */
   if( ed->nActiveTab >= ed->nTabs )
      ed->nActiveTab = ed->nTabs - 1;
   if( ed->nActiveTab == nTab && ed->nActiveTab > 0 )
      ed->nActiveTab--;

   /* Refresh Scintilla with the new active tab's text */
   if( ed->sciWidget && ed->nActiveTab >= 0 && ed->nActiveTab < ed->nTabs )
   {
      ed->bSettingText = 1;
      SciMsg( ed->sciWidget, SCI_SETTEXT, 0,
              (intptr_t)( ed->tabTexts[ed->nActiveTab] ? ed->tabTexts[ed->nActiveTab] : "" ) );
      SciMsg( ed->sciWidget, SCI_EMPTYUNDOBUFFER, 0, 0 );
      ed->bSettingText = 0;
   }
}

/* CodeEditorGetActiveTab( hEditor ) --> nTab (1-based) */
HB_FUNC( CODEEDITORGETACTIVETAB )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed )
   { hb_retni(0); return; }
   hb_retni( ed->nActiveTab + 1 );  /* return 1-based */
}

/* CodeEditorOnTabChange( hEditor, bBlock ) */
HB_FUNC( CODEEDITORONTABCHANGE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( ed ) {
      if( ed->pOnTabChange ) hb_itemRelease( ed->pOnTabChange );
      ed->pOnTabChange = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* CodeEditorOnTextChange( hEditor, bBlock )
 * Register a debounced callback fired 500ms after the user stops typing.
 * Block receives ( hEditor, nTab ) where nTab is 1-based. */
HB_FUNC( CODEEDITORONTEXTCHANGE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( ed ) {
      if( ed->pOnTextChange ) hb_itemRelease( ed->pOnTextChange );
      ed->pOnTextChange = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* CodeEditorAppendText( hEditor, cText [, nCursorOffset] ) */
HB_FUNC( CODEEDITORAPPENDTEXT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget && HB_ISCHAR(2) )
   {
      int nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      int nAppend = (int) hb_parclen(2);

      /* Append at end */
      SciMsg( ed->sciWidget, SCI_GOTOPOS, nLen, 0 );
      SciMsg( ed->sciWidget, SCI_ADDTEXT, nAppend, (intptr_t) hb_parc(2) );

      /* Set cursor position */
      if( HB_ISNUM(3) )
      {
         int nOfs = nLen + hb_parni(3);
         SciMsg( ed->sciWidget, SCI_GOTOPOS, nOfs, 0 );
         SciMsg( ed->sciWidget, SCI_SCROLLCARET, 0, 0 );
      }

      /* Bring editor window to front */
      if( ed->window ) gtk_window_present( GTK_WINDOW(ed->window) );
   }
}

/* CodeEditorInsertAfter( hEditor, cSearch, cInsert ) */
HB_FUNC( CODEEDITORINSERTAFTER )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciWidget || !HB_ISCHAR(2) || !HB_ISCHAR(3) ) return;

   const char * search = hb_parc(2);
   const char * insert = hb_parc(3);

   /* Get full text from Scintilla */
   int nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
   char * fullText = (char *) malloc( nLen + 1 );
   SciMsg( ed->sciWidget, SCI_GETTEXT, nLen + 1, (intptr_t) fullText );

   /* Case-insensitive search */
   char * found = strcasestr( fullText, search );
   if( !found ) { free( fullText ); return; }

   /* Find end of the line containing the match */
   char * eol = strchr( found, '\n' );
   int insertOffset = eol ? (int)(eol - fullText) + 1 : (int)strlen(fullText);
   free( fullText );

   /* Insert text at the offset */
   SciMsg( ed->sciWidget, SCI_GOTOPOS, insertOffset, 0 );
   SciMsg( ed->sciWidget, SCI_ADDTEXT, (int) strlen(insert), (intptr_t) insert );
}

/* CodeEditorGotoFunction( hEditor, cFuncName ) --> lFound */
HB_FUNC( CODEEDITORGOTOFUNCTION )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->sciWidget || !HB_ISCHAR(2) ) { hb_retl(0); return; }

   const char * funcName = hb_parc(2);

   int nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
   if( nLen <= 0 ) { hb_retl(0); return; }

   char * fullText = (char *) malloc( nLen + 1 );
   SciMsg( ed->sciWidget, SCI_GETTEXT, nLen + 1, (intptr_t) fullText );

   /* Search for "METHOD name(" or "function name(" */
   char patterns[4][128];
   snprintf( patterns[0], 128, "METHOD %s(", funcName );
   snprintf( patterns[1], 128, "function %s(", funcName );
   snprintf( patterns[2], 128, "METHOD %s (", funcName );
   snprintf( patterns[3], 128, "function %s (", funcName );

   char * found = NULL;
   for( int i = 0; i < 4 && !found; i++ )
      found = strcasestr( fullText, patterns[i] );

   if( found )
   {
      int offset = (int)(found - fullText);
      int line = (int) SciMsg( ed->sciWidget, SCI_LINEFROMPOSITION, offset, 0 );
      int pos = (int) SciMsg( ed->sciWidget, SCI_POSITIONFROMLINE, line + 2, 0 );
      pos += 3;  /* skip "   " indent */

      SciMsg( ed->sciWidget, SCI_GOTOPOS, pos, 0 );
      SciMsg( ed->sciWidget, SCI_SCROLLCARET, 0, 0 );
      gtk_widget_grab_focus( ed->sciWidget );
      if( ed->window ) gtk_window_present( GTK_WINDOW(ed->window) );
   }

   free( fullText );
   hb_retl( found != NULL );
}

/* CodeEditorBringToFront( hEditor ) */
HB_FUNC( CODEEDITORBRINGTOFRONT )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->window ) gtk_window_present( GTK_WINDOW(ed->window) );
}

/* CodeEditorGetText2( hEditor ) --> cText (alias for search) */
HB_FUNC( CODEEDITORGETTEXT2 )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( ed && ed->sciWidget )
   {
      int nLen = (int) SciMsg( ed->sciWidget, SCI_GETLENGTH, 0, 0 );
      char * buf = (char *) malloc( nLen + 1 );
      SciMsg( ed->sciWidget, SCI_GETTEXT, nLen + 1, (intptr_t) buf );
      hb_retclen( buf, nLen );
      free( buf );
   }
   else
      hb_retc( "" );
}

/* CodeEditorShowFindBar( hEditor, lReplace ) — show/focus find bar */
HB_FUNC( CODEEDITORSHOWFINDBAR )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int bReplace = HB_ISLOG(2) ? hb_parl(2) : 0;
   if( ed ) CE_ShowFindBar( ed, 1, bReplace );
}

/* ======================================================================
 * Platform dialogs & utilities (GTK3 equivalents of MAC_*)
 * ====================================================================== */

/* GTK_ShellExec( cCommand ) --> cOutput */
/* GTK_ProcessEvents() — flush pending GTK events to keep UI responsive */
HB_FUNC( GTK_PROCESSEVENTS )
{
   while( gtk_events_pending() )
      gtk_main_iteration_do( FALSE );
}

/* Helper: append text to the progress log view and auto-scroll */
static void ProgressLogAppend( const char * text, int len )
{
   if( !s_progressLog || !text || len <= 0 ) return;
   GtkTextBuffer * buf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(s_progressLog) );
   GtkTextIter end;
   gtk_text_buffer_get_end_iter( buf, &end );
   gtk_text_buffer_insert( buf, &end, text, len );
   /* Auto-scroll to bottom */
   gtk_text_buffer_get_end_iter( buf, &end );
   GtkTextMark * mark = gtk_text_buffer_get_insert( buf );
   gtk_text_buffer_move_mark( buf, mark, &end );
   gtk_text_view_scroll_mark_onscreen( GTK_TEXT_VIEW(s_progressLog), mark );
}

HB_FUNC( GTK_SHELLEXEC )
{
   if( !HB_ISCHAR(1) ) { hb_retc(""); return; }

   FILE * fp = popen( hb_parc(1), "r" );
   if( !fp ) { hb_retc(""); return; }

   size_t bufSize = 65536, total = 0;
   char * buf = (char *) malloc( bufSize );
   buf[0] = 0;

   /* Set pipe to non-blocking so we can pump GTK events */
   int fd = fileno( fp );
   int flags = fcntl( fd, F_GETFL, 0 );
   fcntl( fd, F_SETFL, flags | O_NONBLOCK );

   while( 1 )
   {
      /* Check for cancel */
      if( s_progressCancelled )
      {
         const char * msg = "\n*** Cancelled by user ***\n";
         size_t msgLen = strlen( msg );
         if( total + msgLen + 1 >= bufSize ) {
            bufSize = total + msgLen + 64;
            buf = (char *) realloc( buf, bufSize );
         }
         memcpy( buf + total, msg, msgLen );
         total += msgLen;
         buf[total] = 0;
         ProgressLogAppend( msg, (int)msgLen );
         break;
      }

      char tmp[4096];
      ssize_t n = read( fd, tmp, sizeof(tmp) );
      if( n > 0 )
      {
         if( total + n + 1 >= bufSize ) {
            bufSize = (total + n + 1) * 2;
            buf = (char *) realloc( buf, bufSize );
         }
         memcpy( buf + total, tmp, n );
         total += n;
         buf[total] = 0;

         /* Append to live log if present */
         ProgressLogAppend( tmp, (int)n );

         /* Pulse progress bar */
         if( s_progressBar && s_progressSteps == 0 )
            gtk_progress_bar_pulse( GTK_PROGRESS_BAR(s_progressBar) );
      }
      else if( n == 0 )
         break;  /* EOF */
      else if( errno == EAGAIN || errno == EWOULDBLOCK )
      {
         /* No data yet — pump GTK events to keep UI alive */
         while( gtk_events_pending() )
            gtk_main_iteration_do( FALSE );
         g_usleep( 20000 );  /* 20ms */
      }
      else
         break;  /* read error */
   }

   pclose( fp );
   hb_retc( buf );
   free( buf );
}

/* GTK_OpenFileDialog( cTitle, cExtension ) --> cPath */
HB_FUNC( GTK_OPENFILEDIALOG )
{
   EnsureGTK();
   GtkWidget * dialog = gtk_file_chooser_dialog_new(
      HB_ISCHAR(1) ? hb_parc(1) : "Open",
      NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
      "_Cancel", GTK_RESPONSE_CANCEL,
      "_Open", GTK_RESPONSE_ACCEPT, NULL );
   if( HB_ISCHAR(2) )
   {
      GtkFileFilter * filter = gtk_file_filter_new();
      char pattern[32];
      snprintf( pattern, sizeof(pattern), "*.%s", hb_parc(2) );
      gtk_file_filter_add_pattern( filter, pattern );
      gtk_file_filter_set_name( filter, pattern );
      gtk_file_chooser_add_filter( GTK_FILE_CHOOSER(dialog), filter );
   }
   if( gtk_dialog_run( GTK_DIALOG(dialog) ) == GTK_RESPONSE_ACCEPT )
   {
      char * filename = gtk_file_chooser_get_filename( GTK_FILE_CHOOSER(dialog) );
      hb_retc( filename ? filename : "" );
      if( filename ) g_free( filename );
   }
   else
      hb_retc( "" );
   gtk_widget_destroy( dialog );
}

/* GTK_SaveFileDialog( cTitle, cDefaultName, cExtension ) --> cPath */
HB_FUNC( GTK_SAVEFILEDIALOG )
{
   EnsureGTK();
   GtkWidget * dialog = gtk_file_chooser_dialog_new(
      HB_ISCHAR(1) ? hb_parc(1) : "Save",
      NULL, GTK_FILE_CHOOSER_ACTION_SAVE,
      "_Cancel", GTK_RESPONSE_CANCEL,
      "_Save", GTK_RESPONSE_ACCEPT, NULL );
   gtk_file_chooser_set_do_overwrite_confirmation( GTK_FILE_CHOOSER(dialog), TRUE );
   if( HB_ISCHAR(2) )
      gtk_file_chooser_set_current_name( GTK_FILE_CHOOSER(dialog), hb_parc(2) );
   if( HB_ISCHAR(3) )
   {
      GtkFileFilter * filter = gtk_file_filter_new();
      char pattern[32];
      snprintf( pattern, sizeof(pattern), "*.%s", hb_parc(3) );
      gtk_file_filter_add_pattern( filter, pattern );
      gtk_file_filter_set_name( filter, pattern );
      gtk_file_chooser_add_filter( GTK_FILE_CHOOSER(dialog), filter );
   }
   if( gtk_dialog_run( GTK_DIALOG(dialog) ) == GTK_RESPONSE_ACCEPT )
   {
      char * filename = gtk_file_chooser_get_filename( GTK_FILE_CHOOSER(dialog) );
      hb_retc( filename ? filename : "" );
      if( filename ) g_free( filename );
   }
   else
      hb_retc( "" );
   gtk_widget_destroy( dialog );
}

/* GTK_SelectFromList( cTitle, aItems ) --> nSelected (1-based, 0=cancel) */
HB_FUNC( GTK_SELECTFROMLIST )
{
   EnsureGTK();
   const char * szTitle = HB_ISCHAR(1) ? hb_parc(1) : "Select";
   PHB_ITEM pArray = hb_param(2, HB_IT_ARRAY);
   if( !pArray ) { hb_retni(0); return; }
   HB_SIZE nLen = hb_arrayLen( pArray );
   if( nLen == 0 ) { hb_retni(0); return; }

   GtkWidget * dialog = gtk_dialog_new_with_buttons( szTitle, NULL,
      GTK_DIALOG_MODAL, "_OK", GTK_RESPONSE_ACCEPT,
      "_Cancel", GTK_RESPONSE_CANCEL, NULL );
   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );

   GtkWidget * combo = gtk_combo_box_text_new();
   for( HB_SIZE i = 1; i <= nLen; i++ )
      gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(combo),
         hb_arrayGetCPtr( pArray, i ) );
   gtk_combo_box_set_active( GTK_COMBO_BOX(combo), 0 );
   gtk_container_add( GTK_CONTAINER(content), combo );
   gtk_widget_show_all( content );

   int result = 0;
   if( gtk_dialog_run( GTK_DIALOG(dialog) ) == GTK_RESPONSE_ACCEPT )
      result = gtk_combo_box_get_active( GTK_COMBO_BOX(combo) ) + 1;
   gtk_widget_destroy( dialog );
   hb_retni( result );
}

/* GTK_AboutDialog( cTitle, cMessage, cIconPath ) */
HB_FUNC( GTK_ABOUTDIALOG )
{
   EnsureGTK();
   GtkWidget * dialog = gtk_message_dialog_new( NULL,
      GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
      "%s", HB_ISCHAR(2) ? hb_parc(2) : "" );
   gtk_window_set_title( GTK_WINDOW(dialog),
      HB_ISCHAR(1) ? hb_parc(1) : "About" );
   if( HB_ISCHAR(3) )
   {
      GdkPixbuf * logo = gdk_pixbuf_new_from_file_at_size( hb_parc(3), 128, 128, NULL );
      if( logo )
      {
         GtkWidget * img = gtk_image_new_from_pixbuf( logo );
         GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );
         gtk_container_add( GTK_CONTAINER(content), img );
         gtk_box_reorder_child( GTK_BOX(content), img, 0 );
         gtk_widget_show( img );
         g_object_unref( logo );
      }
   }
   gtk_dialog_run( GTK_DIALOG(dialog) );
   gtk_widget_destroy( dialog );
}

/* ======================================================================
 * Dark Mode - apply GTK dark theme
 * ====================================================================== */

static int s_bDarkMode = 0;
static GtkCssProvider * s_darkCssProvider = NULL;

/* GTK_IsDarkMode() → lDark */
HB_FUNC( GTK_ISDARKMODE )
{
   hb_retl( s_bDarkMode );
}

HB_FUNC( GTK_SETDARKMODE )
{
   EnsureGTK();
   int bDark = hb_parl(1);
   s_bDarkMode = bDark;
   GtkSettings * settings = gtk_settings_get_default();
   if( settings )
      g_object_set( settings, "gtk-application-prefer-dark-theme", (gboolean)bDark, NULL );

   /* Remove previous dark mode CSS if any */
   if( s_darkCssProvider )
   {
      gtk_style_context_remove_provider_for_screen(
         gdk_screen_get_default(), GTK_STYLE_PROVIDER(s_darkCssProvider) );
      g_object_unref( s_darkCssProvider );
      s_darkCssProvider = NULL;
   }

   /* Apply screen-wide dark CSS override */
   if( bDark )
   {
      s_darkCssProvider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( s_darkCssProvider,
         "window { background-color: #2D2D2D; }"
         "toolbar { background-color: #2D2D2D; }"
         "toolbar button { background-color: #3C3C3C; color: #D4D4D4; }"
         , -1, NULL );
      gtk_style_context_add_provider_for_screen(
         gdk_screen_get_default(), GTK_STYLE_PROVIDER(s_darkCssProvider),
         GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 1 );
   }
}

/* GTK_IsDarkMode accessor for inspector */
int GTK_IsDark(void) { return s_bDarkMode; }

/* Apply dark or light theme to a Scintilla widget */
static void ApplyScintillaTheme( GtkWidget * sci, int bDark )
{
   if( !sci ) return;

   if( bDark )
   {
      /* VS Code Dark+ */
      SciMsg( sci, SCI_STYLESETFORE, STYLE_DEFAULT, SciRGB(212,212,212) );
      SciMsg( sci, SCI_STYLESETBACK, STYLE_DEFAULT, SciRGB(30,30,30) );
      SciMsg( sci, SCI_STYLECLEARALL, 0, 0 );
      SciMsg( sci, SCI_STYLESETFORE, STYLE_LINENUMBER, SciRGB(133,133,133) );
      SciMsg( sci, SCI_STYLESETBACK, STYLE_LINENUMBER, SciRGB(37,37,38) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_WORD,       SciRGB(86,156,214) );
      SciMsg( sci, SCI_STYLESETBOLD, SCE_C_WORD,       1 );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_WORD2,      SciRGB(78,201,176) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENT,     SciRGB(106,153,85) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENTLINE,  SciRGB(106,153,85) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENTDOC,   SciRGB(106,153,85) );
      SciMsg( sci, SCI_STYLESETITALIC, SCE_C_COMMENT, 1 );
      SciMsg( sci, SCI_STYLESETITALIC, SCE_C_COMMENTLINE, 1 );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_STRING,      SciRGB(206,145,120) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_CHARACTER,    SciRGB(206,145,120) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_NUMBER,      SciRGB(181,206,168) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_PREPROCESSOR, SciRGB(197,134,192) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_OPERATOR,    SciRGB(212,212,212) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_IDENTIFIER,  SciRGB(220,220,220) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_GLOBALCLASS,  SciRGB(78,201,176) );
      SciMsg( sci, SCI_SETCARETFORE, SciRGB(255,255,255), 0 );
      SciMsg( sci, SCI_SETSELBACK,   1, SciRGB(38,79,120) );
      { int m; for( m = 25; m <= 31; m++ ) {
         SciMsg( sci, SCI_MARKERSETFORE, m, SciRGB(160,160,160) );
         SciMsg( sci, SCI_MARKERSETBACK, m, SciRGB(37,37,38) );
      } }
      SciMsg( sci, SCI_MARKERSETBACK, 11, SciRGB(60,60,0) ); /* debug line */
   }
   else
   {
      /* VS Code Light+ */
      SciMsg( sci, SCI_STYLESETFORE, STYLE_DEFAULT, SciRGB(30,30,30) );
      SciMsg( sci, SCI_STYLESETBACK, STYLE_DEFAULT, SciRGB(255,255,255) );
      SciMsg( sci, SCI_STYLECLEARALL, 0, 0 );
      SciMsg( sci, SCI_STYLESETFORE, STYLE_LINENUMBER, SciRGB(120,120,120) );
      SciMsg( sci, SCI_STYLESETBACK, STYLE_LINENUMBER, SciRGB(240,240,240) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_WORD,       SciRGB(0,0,255) );
      SciMsg( sci, SCI_STYLESETBOLD, SCE_C_WORD,       1 );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_WORD2,      SciRGB(0,128,128) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENT,     SciRGB(0,128,0) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENTLINE,  SciRGB(0,128,0) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_COMMENTDOC,   SciRGB(0,128,0) );
      SciMsg( sci, SCI_STYLESETITALIC, SCE_C_COMMENT, 1 );
      SciMsg( sci, SCI_STYLESETITALIC, SCE_C_COMMENTLINE, 1 );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_STRING,      SciRGB(163,21,21) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_CHARACTER,    SciRGB(163,21,21) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_NUMBER,      SciRGB(9,134,88) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_PREPROCESSOR, SciRGB(175,0,219) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_OPERATOR,    SciRGB(30,30,30) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_IDENTIFIER,  SciRGB(30,30,30) );
      SciMsg( sci, SCI_STYLESETFORE, SCE_C_GLOBALCLASS,  SciRGB(0,128,128) );
      SciMsg( sci, SCI_SETCARETFORE, SciRGB(0,0,0), 0 );
      SciMsg( sci, SCI_SETSELBACK,   1, SciRGB(173,214,255) );
      { int m; for( m = 25; m <= 31; m++ ) {
         SciMsg( sci, SCI_MARKERSETFORE, m, SciRGB(120,120,120) );
         SciMsg( sci, SCI_MARKERSETBACK, m, SciRGB(240,240,240) );
      } }
      SciMsg( sci, SCI_MARKERSETBACK, 11, SciRGB(255,255,200) ); /* debug line */
   }
}

/* CodeEditorApplyTheme( hEditor, lDark ) — switch all tabs dark/light */
HB_FUNC( CODEEDITORAPPLYTHEME )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int bDark = hb_parl(2);
   if( !ed || !ed->sciWidget ) return;
   ApplyScintillaTheme( ed->sciWidget, bDark );

   /* Update editor window background */
   if( ed->window )
   {
      char css[128];
      if( bDark )
         snprintf( css, sizeof(css), "window { background-color: #1E1E1E; }" );
      else
         snprintf( css, sizeof(css), "window { background-color: #FFFFFF; }" );
      GtkCssProvider * prov = gtk_css_provider_new();
      gtk_css_provider_load_from_data( prov, css, -1, NULL );
      gtk_style_context_add_provider( gtk_widget_get_style_context(ed->window),
         GTK_STYLE_PROVIDER(prov), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
      g_object_unref( prov );
   }
}

/* ======================================================================
 * Debugger Panel - floating window with 5 tabs
 * ====================================================================== */

#include <stdarg.h>

static GtkWidget * s_hDbgWnd = NULL;
static GtkWidget * s_dbgLocalsTV = NULL;   /* Locals TreeView */
static GtkWidget * s_dbgStackTV = NULL;    /* Call Stack TreeView */
static GtkWidget * s_dbgBpTV = NULL;       /* Breakpoints TreeView */
static GtkWidget * s_dbgWatchTV = NULL;    /* Watch TreeView */
static GtkWidget * s_dbgStatusLbl = NULL;  /* Status label */
static GtkWidget * s_dbgOutputTV_panel = NULL;  /* Output tab textview (debug panel) */

/* Debug toolbar button callbacks - set state via global variable
 * The actual state variables (s_dbgState etc.) are defined in the
 * Debugger Engine section below. Forward-declare what we need here. */
static int * _dbg_state_ptr(void);   /* returns &s_dbgState */

static void on_dbg_run( GtkButton * b, gpointer d )
   { (void)b; (void)d; int * p = _dbg_state_ptr(); if( p && *p == 2 ) *p = 1; }
static void on_dbg_step( GtkButton * b, gpointer d )
   { (void)b; (void)d; int * p = _dbg_state_ptr(); if( p && *p == 2 ) *p = 3; }
static void on_dbg_stepover( GtkButton * b, gpointer d )
   { (void)b; (void)d; int * p = _dbg_state_ptr(); if( p && *p == 2 ) *p = 4; }
static void on_dbg_stop( GtkButton * b, gpointer d )
   { (void)b; (void)d; int * p = _dbg_state_ptr(); if( p && *p != 0 ) *p = 5; }

/* Helper: create a dark-themed TreeView with columns */
static GtkWidget * DbgCreateTreeView( GtkWidget * container, int nCols, ... )
{
   va_list args;
   GType types[8];
   int i;
   for( i = 0; i < nCols && i < 8; i++ ) types[i] = G_TYPE_STRING;

   GtkListStore * store = gtk_list_store_newv( nCols, types );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   g_object_unref( store );

   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   va_start( args, nCols );
   for( i = 0; i < nCols; i++ )
   {
      const char * title = va_arg( args, const char * );
      GtkTreeViewColumn * col = gtk_tree_view_column_new_with_attributes( title, r, "text", i, NULL );
      gtk_tree_view_column_set_resizable( col, TRUE );
      if( i == 0 ) gtk_tree_view_column_set_min_width( col, 120 );
      gtk_tree_view_append_column( GTK_TREE_VIEW(tv), col );
   }
   va_end( args );

   gtk_tree_view_set_grid_lines( GTK_TREE_VIEW(tv), GTK_TREE_VIEW_GRID_LINES_HORIZONTAL );

   /* Dark theme */
   { GtkCssProvider * p = gtk_css_provider_new();
     gtk_css_provider_load_from_data( p,
        "treeview { background-color: #1E1E1E; color: #D4D4D4; font-family: Monospace; font-size: 10pt; }"
        "treeview:selected { background-color: #094771; }"
        "treeview header button { background-color: #2D2D2D; color: #D4D4D4;"
        "  border-color: #3E3E3E; font-weight: bold; }", -1, NULL );
     gtk_style_context_add_provider( gtk_widget_get_style_context(tv),
        GTK_STYLE_PROVIDER(p), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
     g_object_unref( p );
   }

   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_container_add( GTK_CONTAINER(container), sw );
   return tv;
}

HB_FUNC( GTK_DEBUGPANEL )
{
   EnsureGTK();

   if( s_hDbgWnd ) {
      gtk_window_present( GTK_WINDOW(s_hDbgWnd) );
      return;
   }

   s_hDbgWnd = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(s_hDbgWnd), "Debugger" );
   gtk_window_set_default_size( GTK_WINDOW(s_hDbgWnd), 650, 420 );
   gtk_window_set_type_hint( GTK_WINDOW(s_hDbgWnd), GDK_WINDOW_TYPE_HINT_UTILITY );
   g_signal_connect( s_hDbgWnd, "delete-event",
      G_CALLBACK(gtk_widget_hide_on_delete), NULL );

   /* Dark window background */
   { GtkCssProvider * p = gtk_css_provider_new();
     gtk_css_provider_load_from_data( p,
        "window { background-color: #252526; }"
        "notebook { background-color: #252526; }"
        "notebook tab { background-color: #2D2D2D; color: #D4D4D4; padding: 4px 12px; }"
        "notebook tab:checked { background-color: #1E1E1E; border-bottom: 2px solid #007ACC; }"
        "label { color: #D4D4D4; }"
        "button { background-color: #3C3C3C; color: #D4D4D4; border-color: #555;"
        "  padding: 3px 10px; }"
        "button:hover { background-color: #4C4C4C; }", -1, NULL );
     gtk_style_context_add_provider( gtk_widget_get_style_context(s_hDbgWnd),
        GTK_STYLE_PROVIDER(p), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
     g_object_unref( p );
   }

   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(s_hDbgWnd), vbox );

   /* === Debug toolbar (Lazarus/C++Builder style) === */
   GtkWidget * toolbar = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 2 );
   gtk_widget_set_margin_start( toolbar, 4 );
   gtk_widget_set_margin_top( toolbar, 2 );
   gtk_widget_set_margin_bottom( toolbar, 2 );
   gtk_box_pack_start( GTK_BOX(vbox), toolbar, FALSE, FALSE, 0 );

   { GtkWidget * b;
     b = gtk_button_new_with_label( "\xe2\x96\xb6 Run" );       /* ▶ Run */
     g_signal_connect( b, "clicked", G_CALLBACK(on_dbg_run), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), b, FALSE, FALSE, 2 );

     b = gtk_button_new_with_label( "\xe2\x8f\xb8 Pause" );     /* ⏸ Pause */
     gtk_widget_set_sensitive( b, FALSE );
     gtk_box_pack_start( GTK_BOX(toolbar), b, FALSE, FALSE, 2 );

     b = gtk_button_new_with_label( "\xe2\x86\x93 Step Into" );  /* ↓ Step Into */
     g_signal_connect( b, "clicked", G_CALLBACK(on_dbg_step), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), b, FALSE, FALSE, 2 );

     b = gtk_button_new_with_label( "\xe2\x86\x92 Step Over" );  /* → Step Over */
     g_signal_connect( b, "clicked", G_CALLBACK(on_dbg_stepover), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), b, FALSE, FALSE, 2 );

     b = gtk_button_new_with_label( "\xe2\x96\xa0 Stop" );       /* ■ Stop */
     g_signal_connect( b, "clicked", G_CALLBACK(on_dbg_stop), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), b, FALSE, FALSE, 2 );

     /* Separator + status */
     gtk_box_pack_start( GTK_BOX(toolbar),
        gtk_separator_new( GTK_ORIENTATION_VERTICAL ), FALSE, FALSE, 6 );

     s_dbgStatusLbl = gtk_label_new( "Ready" );
     gtk_box_pack_start( GTK_BOX(toolbar), s_dbgStatusLbl, FALSE, FALSE, 4 );
   }

   /* === Notebook with 5 tabs === */
   GtkWidget * nb = gtk_notebook_new();
   gtk_notebook_set_tab_pos( GTK_NOTEBOOK(nb), GTK_POS_BOTTOM );
   gtk_box_pack_start( GTK_BOX(vbox), nb, TRUE, TRUE, 0 );

   /* Tab 0: Watch */
   { GtkWidget * box = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
     s_dbgWatchTV = DbgCreateTreeView( box, 3, "Expression", "Value", "Type" );
     gtk_notebook_append_page( GTK_NOTEBOOK(nb), box, gtk_label_new("Watch") );
   }

   /* Tab 1: Locals */
   { GtkWidget * box = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
     s_dbgLocalsTV = DbgCreateTreeView( box, 3, "Name", "Value", "Type" );
     gtk_notebook_append_page( GTK_NOTEBOOK(nb), box, gtk_label_new("Locals") );
   }

   /* Tab 2: Call Stack */
   { GtkWidget * box = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
     s_dbgStackTV = DbgCreateTreeView( box, 4, "#", "Function", "Module", "Line" );
     gtk_notebook_append_page( GTK_NOTEBOOK(nb), box, gtk_label_new("Call Stack") );
   }

   /* Tab 3: Breakpoints */
   { GtkWidget * box = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
     s_dbgBpTV = DbgCreateTreeView( box, 3, "File", "Line", "Enabled" );
     gtk_notebook_append_page( GTK_NOTEBOOK(nb), box, gtk_label_new("Breakpoints") );
   }

   /* Tab 4: Output */
   { GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
     gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
     GtkWidget * tv = gtk_text_view_new();
     gtk_text_view_set_editable( GTK_TEXT_VIEW(tv), FALSE );
     gtk_text_view_set_monospace( GTK_TEXT_VIEW(tv), TRUE );
     gtk_text_view_set_left_margin( GTK_TEXT_VIEW(tv), 6 );
     gtk_text_view_set_top_margin( GTK_TEXT_VIEW(tv), 4 );
     { GtkCssProvider * cp = gtk_css_provider_new();
       gtk_css_provider_load_from_data( cp,
          "textview text { background-color: #1E1E1E; color: #D4D4D4;"
          "  font-family: Monospace; font-size: 10pt; }", -1, NULL );
       gtk_style_context_add_provider( gtk_widget_get_style_context(tv),
          GTK_STYLE_PROVIDER(cp), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
       g_object_unref( cp );
     }
     gtk_container_add( GTK_CONTAINER(sw), tv );
     gtk_notebook_append_page( GTK_NOTEBOOK(nb), sw, gtk_label_new("Output") );
   }

   gtk_widget_show_all( s_hDbgWnd );

   /* Auto-connect the Output tab textview for debug logging */
   { GtkWidget * sw = gtk_notebook_get_nth_page( GTK_NOTEBOOK(nb), 4 );
     if( sw ) {
        GtkWidget * child = gtk_bin_get_child( GTK_BIN(sw) );
        if( GTK_IS_TEXT_VIEW(child) ) s_dbgOutputTV_panel = child;
     }
   }
}

/* GTK_DebugUpdateLocals( aLocals ) - update Locals tab from Harbour array */
HB_FUNC( GTK_DEBUGUPDATELOCALS )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_dbgLocalsTV || !pArray ) return;

   GtkListStore * store = GTK_LIST_STORE( gtk_tree_view_get_model( GTK_TREE_VIEW(s_dbgLocalsTV) ) );
   gtk_list_store_clear( store );

   int n = (int) hb_arrayLen( pArray );
   int i;
   for( i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 3 ) continue;
      GtkTreeIter iter;
      gtk_list_store_append( store, &iter );
      gtk_list_store_set( store, &iter,
         0, hb_arrayGetCPtr( pEntry, 1 ),
         1, hb_arrayGetCPtr( pEntry, 2 ),
         2, hb_arrayGetCPtr( pEntry, 3 ), -1 );
   }
}

/* GTK_DebugUpdateStack( aStack ) - update Call Stack from { {level,func,module,line}, ... } */
HB_FUNC( GTK_DEBUGUPDATESTACK )
{
   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );
   if( !s_dbgStackTV || !pArray ) return;

   GtkListStore * store = GTK_LIST_STORE( gtk_tree_view_get_model( GTK_TREE_VIEW(s_dbgStackTV) ) );
   gtk_list_store_clear( store );

   int n = (int) hb_arrayLen( pArray );
   int i;
   for( i = 1; i <= n; i++ )
   {
      PHB_ITEM pEntry = hb_arrayGetItemPtr( pArray, i );
      if( !pEntry || hb_arrayLen(pEntry) < 4 ) continue;
      GtkTreeIter iter;
      gtk_list_store_append( store, &iter );
      gtk_list_store_set( store, &iter,
         0, hb_arrayGetCPtr( pEntry, 1 ),
         1, hb_arrayGetCPtr( pEntry, 2 ),
         2, hb_arrayGetCPtr( pEntry, 3 ),
         3, hb_arrayGetCPtr( pEntry, 4 ), -1 );
   }
}

/* GTK_DebugSetStatus( cStatus ) */
HB_FUNC( GTK_DEBUGSETSTATUS )
{
   if( s_dbgStatusLbl && HB_ISCHAR(1) )
      gtk_label_set_text( GTK_LABEL(s_dbgStatusLbl), hb_parc(1) );
}

/* GTK_DebugUpdateLocalsStr( cVars ) - parse VARS string and update Locals tab
 * Format: "VARS [PUBLIC] name=val name=val [PRIVATE] ... [LOCAL] ..." */
HB_FUNC( GTK_DEBUGUPDATELOCALSSTR )
{
   const char * cVars = hb_parc(1);
   if( !s_dbgLocalsTV || !cVars ) return;

   GtkListStore * store = GTK_LIST_STORE( gtk_tree_view_get_model( GTK_TREE_VIEW(s_dbgLocalsTV) ) );
   gtk_list_store_clear( store );

   /* Skip "VARS " prefix */
   const char * p = cVars;
   if( strncmp( p, "VARS", 4 ) == 0 ) p += 4;

   char category[32] = "";
   while( *p )
   {
      while( *p == ' ' ) p++;
      if( !*p ) break;

      /* Check for [CATEGORY] header */
      if( *p == '[' )
      {
         const char * end = strchr( p, ']' );
         if( end )
         {
            int len = (int)(end - p - 1);
            if( len > 0 && len < 30 )
            {
               memcpy( category, p + 1, (size_t)len );
               category[len] = 0;
            }
            /* Add category header row */
            GtkTreeIter iter;
            gtk_list_store_append( store, &iter );
            gtk_list_store_set( store, &iter,
               0, category, 1, "", 2, "---", -1 );
            p = end + 1;
            continue;
         }
      }

      /* Parse "name=value(type)" or "name=value" token */
      const char * tokStart = p;
      /* Find end of token (next space or end) */
      while( *p && *p != ' ' ) p++;
      int tokLen = (int)(p - tokStart);
      if( tokLen <= 0 ) continue;

      char token[512];
      if( tokLen >= (int)sizeof(token) ) tokLen = (int)sizeof(token) - 1;
      memcpy( token, tokStart, (size_t)tokLen );
      token[tokLen] = 0;

      /* Split at '=' */
      char * eq = strchr( token, '=' );
      if( eq )
      {
         *eq = 0;
         const char * name = token;
         const char * value = eq + 1;

         GtkTreeIter iter;
         gtk_list_store_append( store, &iter );
         gtk_list_store_set( store, &iter,
            0, name, 1, value, 2, category, -1 );
      }
   }
}

/* GTK_DebugUpdateStackStr( cStack ) - parse STACK string and update Call Stack tab
 * Format: "STACK FUNC(line) FUNC2(line2) ..." */
HB_FUNC( GTK_DEBUGUPDATESTACKSTR )
{
   const char * cStack = hb_parc(1);
   if( !s_dbgStackTV || !cStack ) return;

   GtkListStore * store = GTK_LIST_STORE( gtk_tree_view_get_model( GTK_TREE_VIEW(s_dbgStackTV) ) );
   gtk_list_store_clear( store );

   /* Skip "STACK " prefix */
   const char * p = cStack;
   if( strncmp( p, "STACK", 5 ) == 0 ) p += 5;

   int idx = 0;
   while( *p )
   {
      while( *p == ' ' ) p++;
      if( !*p ) break;

      /* Read token: "FUNCNAME(line)" */
      const char * tokStart = p;
      while( *p && *p != ' ' ) p++;
      int tokLen = (int)(p - tokStart);
      if( tokLen <= 0 ) continue;

      char token[256];
      if( tokLen >= (int)sizeof(token) ) tokLen = (int)sizeof(token) - 1;
      memcpy( token, tokStart, (size_t)tokLen );
      token[tokLen] = 0;

      /* Split FUNC(line) */
      char funcName[128] = "";
      char lineStr[32] = "";
      char * paren = strchr( token, '(' );
      if( paren )
      {
         int fLen = (int)(paren - token);
         if( fLen >= (int)sizeof(funcName) ) fLen = (int)sizeof(funcName) - 1;
         memcpy( funcName, token, (size_t)fLen );
         funcName[fLen] = 0;

         char * cp = paren + 1;
         char * ep = strchr( cp, ')' );
         if( ep )
         {
            int lLen = (int)(ep - cp);
            if( lLen >= (int)sizeof(lineStr) ) lLen = (int)sizeof(lineStr) - 1;
            memcpy( lineStr, cp, (size_t)lLen );
            lineStr[lLen] = 0;
         }
      }
      else
      {
         strncpy( funcName, token, sizeof(funcName) - 1 );
      }

      char idxStr[8];
      snprintf( idxStr, sizeof(idxStr), "%d", idx );

      GtkTreeIter iter;
      gtk_list_store_append( store, &iter );
      gtk_list_store_set( store, &iter,
         0, idxStr, 1, funcName, 2, "", 3, lineStr, -1 );
      idx++;
   }
}

/* ======================================================================
 * Project Inspector - floating TreeView showing project structure
 * ====================================================================== */

static GtkWidget * s_hProjInsp = NULL;

HB_FUNC( GTK_PROJECTINSPECTOR )
{
   EnsureGTK();

   PHB_ITEM pArray = hb_param( 1, HB_IT_ARRAY );

   if( s_hProjInsp ) {
      if( !pArray ) {
         gtk_window_present( GTK_WINDOW(s_hProjInsp) );
         return;
      }
      gtk_widget_destroy( s_hProjInsp );
      s_hProjInsp = NULL;
   }

   s_hProjInsp = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(s_hProjInsp), "Project Inspector" );
   gtk_window_set_default_size( GTK_WINDOW(s_hProjInsp), 250, 400 );
   gtk_window_set_type_hint( GTK_WINDOW(s_hProjInsp), GDK_WINDOW_TYPE_HINT_UTILITY );
   g_signal_connect( s_hProjInsp, "delete-event",
      G_CALLBACK(gtk_widget_hide_on_delete), NULL );

   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_container_add( GTK_CONTAINER(s_hProjInsp), sw );

   GtkTreeStore * store = gtk_tree_store_new( 1, G_TYPE_STRING );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   g_object_unref( store );

   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   gtk_tree_view_append_column( GTK_TREE_VIEW(tv),
      gtk_tree_view_column_new_with_attributes( "Project", r, "text", 0, NULL ) );
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(tv), FALSE );

   /* Populate tree from array */
   if( pArray )
   {
      int n = (int) hb_arrayLen( pArray );
      GtkTreeIter parent, child;
      int hasParent = 0;
      int j;

      for( j = 1; j <= n; j++ )
      {
         const char * item = hb_arrayGetCPtr( pArray, j );
         if( !item ) continue;

         if( item[0] == ' ' && item[1] == ' ' ) {
            if( hasParent ) {
               gtk_tree_store_append( store, &child, &parent );
               gtk_tree_store_set( store, &child, 0, item + 2, -1 );
            }
         } else {
            gtk_tree_store_append( store, &parent, NULL );
            gtk_tree_store_set( store, &parent, 0, item, -1 );
            hasParent = 1;
         }
      }
   }

   gtk_container_add( GTK_CONTAINER(sw), tv );
   gtk_tree_view_expand_all( GTK_TREE_VIEW(tv) );
   gtk_widget_show_all( s_hProjInsp );
}

/* ======================================================================
 * AI Assistant Panel - Ollama chat interface
 * ====================================================================== */

static GtkWidget * s_hAIWnd = NULL;
static GtkWidget * s_aiWidgets[4];  /* entry, output, combo, statusLbl */

static void on_ai_send( GtkButton * btn, gpointer data )
{
   GtkWidget ** w = (GtkWidget **) data;
   GtkWidget * entry  = w[0];
   GtkWidget * output = w[1];
   GtkWidget * combo  = w[2];
   GtkWidget * status = w[3];

   const char * prompt = gtk_entry_get_text( GTK_ENTRY(entry) );
   if( !prompt || !prompt[0] ) return;

   char * model = gtk_combo_box_text_get_active_text( GTK_COMBO_BOX_TEXT(combo) );
   if( !model ) model = g_strdup( "codellama" );

   GtkTextBuffer * buf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(output) );
   GtkTextIter endIter;
   gtk_text_buffer_get_end_iter( buf, &endIter );

   char * userMsg = g_strdup_printf( "\n> %s\n", prompt );
   gtk_text_buffer_insert( buf, &endIter, userMsg, -1 );
   g_free( userMsg );

   gtk_label_set_text( GTK_LABEL(status), "Status: Sending..." );

   /* Call Ollama via curl */
   char * escaped = g_strescape( prompt, NULL );
   char * cmd = g_strdup_printf(
      "curl -s -m 30 http://localhost:11434/api/generate "
      "-d '{\"model\":\"%s\",\"prompt\":\"%s\",\"stream\":false}' 2>/dev/null "
      "| python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('response',''))\" 2>/dev/null",
      model, escaped );
   g_free( escaped );

   char * response = NULL;
   g_spawn_command_line_sync( cmd, &response, NULL, NULL, NULL );
   g_free( cmd );

   gtk_text_buffer_get_end_iter( buf, &endIter );
   if( response && response[0] ) {
      gtk_text_buffer_insert( buf, &endIter, response, -1 );
      if( response[strlen(response)-1] != '\n' )
         gtk_text_buffer_insert( buf, &endIter, "\n", -1 );
      { char * s = g_strdup_printf( "Status: Ready | Model: %s | Ollama: localhost:11434", model );
        gtk_label_set_text( GTK_LABEL(status), s );
        g_free( s );
      }
   } else {
      gtk_text_buffer_insert( buf, &endIter,
         "[No response - check Ollama is running on localhost:11434]\n", -1 );
      gtk_label_set_text( GTK_LABEL(status), "Status: Error - Ollama not responding" );
   }
   if( response ) g_free( response );

   /* Scroll to bottom */
   gtk_text_buffer_get_end_iter( buf, &endIter );
   GtkTextMark * mark = gtk_text_buffer_get_mark( buf, "insert" );
   gtk_text_buffer_move_mark( buf, mark, &endIter );
   gtk_text_view_scroll_mark_onscreen( GTK_TEXT_VIEW(output), mark );

   gtk_entry_set_text( GTK_ENTRY(entry), "" );
   g_free( model );
   (void)btn;
}

static void on_ai_clear( GtkButton * btn, gpointer data )
{
   GtkWidget * output = (GtkWidget *) data;
   GtkTextBuffer * buf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(output) );
   gtk_text_buffer_set_text( buf, "AI Assistant ready.\nType a question and press Send.\n", -1 );
   (void)btn;
}

static gboolean on_ai_entry_key( GtkWidget * w, GdkEventKey * ev, gpointer data )
{
   if( ev->keyval == GDK_KEY_Return || ev->keyval == GDK_KEY_KP_Enter ) {
      on_ai_send( NULL, data );
      return TRUE;
   }
   (void)w;
   return FALSE;
}

HB_FUNC( GTK_AIASSISTANTPANEL )
{
   EnsureGTK();

   if( s_hAIWnd ) {
      gtk_window_present( GTK_WINDOW(s_hAIWnd) );
      return;
   }

   s_hAIWnd = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(s_hAIWnd), "AI Assistant" );
   gtk_window_set_default_size( GTK_WINDOW(s_hAIWnd), 420, 550 );
   gtk_window_set_type_hint( GTK_WINDOW(s_hAIWnd), GDK_WINDOW_TYPE_HINT_UTILITY );
   g_signal_connect( s_hAIWnd, "delete-event",
      G_CALLBACK(gtk_widget_hide_on_delete), NULL );

   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 4 );
   gtk_container_set_border_width( GTK_CONTAINER(vbox), 6 );
   gtk_container_add( GTK_CONTAINER(s_hAIWnd), vbox );

   /* Top bar: Model selector + Clear */
   GtkWidget * topBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
   gtk_box_pack_start( GTK_BOX(vbox), topBox, FALSE, FALSE, 0 );
   gtk_box_pack_start( GTK_BOX(topBox), gtk_label_new("Model:"), FALSE, FALSE, 4 );

   GtkWidget * combo = gtk_combo_box_text_new();
   { const char * mdl[] = { "codellama","llama3","deepseek-coder","mistral","phi3","gemma2",NULL };
     int m; for( m = 0; mdl[m]; m++ )
       gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(combo), mdl[m] );
   }
   gtk_combo_box_set_active( GTK_COMBO_BOX(combo), 0 );
   gtk_box_pack_start( GTK_BOX(topBox), combo, TRUE, TRUE, 0 );

   /* Chat output */
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_box_pack_start( GTK_BOX(vbox), sw, TRUE, TRUE, 0 );

   GtkWidget * output = gtk_text_view_new();
   gtk_text_view_set_editable( GTK_TEXT_VIEW(output), FALSE );
   gtk_text_view_set_wrap_mode( GTK_TEXT_VIEW(output), GTK_WRAP_WORD );
   gtk_text_view_set_left_margin( GTK_TEXT_VIEW(output), 6 );
   { GtkTextBuffer * tbuf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(output) );
     gtk_text_buffer_set_text( tbuf,
        "AI Assistant ready.\nType a question and press Send.\n", -1 );
   }
   /* Monospace dark theme for chat */
   { GtkCssProvider * cp = gtk_css_provider_new();
     gtk_css_provider_load_from_data( cp,
        "textview text { background-color: #1E1E1E; color: #D4D4D4;"
        "  font-family: Monospace; font-size: 11pt; }", -1, NULL );
     gtk_style_context_add_provider( gtk_widget_get_style_context(output),
        GTK_STYLE_PROVIDER(cp), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
     g_object_unref( cp );
   }
   gtk_container_add( GTK_CONTAINER(sw), output );

   GtkWidget * clearBtn = gtk_button_new_with_label( "Clear" );
   gtk_box_pack_start( GTK_BOX(topBox), clearBtn, FALSE, FALSE, 0 );
   g_signal_connect( clearBtn, "clicked", G_CALLBACK(on_ai_clear), output );

   /* Input bar */
   GtkWidget * inputBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
   gtk_box_pack_start( GTK_BOX(vbox), inputBox, FALSE, FALSE, 0 );

   GtkWidget * entry = gtk_entry_new();
   gtk_entry_set_placeholder_text( GTK_ENTRY(entry), "Ask a question..." );
   gtk_box_pack_start( GTK_BOX(inputBox), entry, TRUE, TRUE, 0 );

   GtkWidget * sendBtn = gtk_button_new_with_label( "Send" );
   gtk_box_pack_start( GTK_BOX(inputBox), sendBtn, FALSE, FALSE, 0 );

   /* Status bar */
   GtkWidget * statusLbl = gtk_label_new( "Status: Ready | Ollama: localhost:11434" );
   gtk_label_set_xalign( GTK_LABEL(statusLbl), 0.0 );
   gtk_box_pack_start( GTK_BOX(vbox), statusLbl, FALSE, FALSE, 0 );

   /* Wire callbacks */
   s_aiWidgets[0] = entry;
   s_aiWidgets[1] = output;
   s_aiWidgets[2] = combo;
   s_aiWidgets[3] = statusLbl;

   g_signal_connect( sendBtn, "clicked", G_CALLBACK(on_ai_send), s_aiWidgets );
   g_signal_connect( entry, "key-press-event", G_CALLBACK(on_ai_entry_key), s_aiWidgets );

   gtk_widget_show_all( s_hAIWnd );
}

/* ======================================================================
 * Editor Colors Dialog - syntax color settings with presets
 * ====================================================================== */

HB_FUNC( GTK_EDITORSETTINGSDIALOG )
{
   EnsureGTK();

   GtkWidget * dlg = gtk_dialog_new_with_buttons( "Editor Colors",
      NULL, GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "_OK", GTK_RESPONSE_OK, "_Cancel", GTK_RESPONSE_CANCEL, NULL );
   gtk_window_set_default_size( GTK_WINDOW(dlg), 480, 500 );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dlg) );
   gtk_container_set_border_width( GTK_CONTAINER(content), 10 );

   /* Font section */
   GtkWidget * fontBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 8 );
   gtk_box_pack_start( GTK_BOX(content), fontBox, FALSE, FALSE, 4 );
   gtk_box_pack_start( GTK_BOX(fontBox), gtk_label_new("Font:"), FALSE, FALSE, 0 );
   GtkWidget * fontEntry = gtk_entry_new();
   gtk_entry_set_text( GTK_ENTRY(fontEntry), "Monospace" );
   gtk_box_pack_start( GTK_BOX(fontBox), fontEntry, TRUE, TRUE, 0 );
   gtk_box_pack_start( GTK_BOX(fontBox), gtk_label_new("Size:"), FALSE, FALSE, 0 );
   GtkWidget * sizeSpn = gtk_spin_button_new_with_range( 8, 32, 1 );
   gtk_spin_button_set_value( GTK_SPIN_BUTTON(sizeSpn), 14 );
   gtk_box_pack_start( GTK_BOX(fontBox), sizeSpn, FALSE, FALSE, 0 );

   /* Color rows with GtkColorButton */
   const char * colorLabels[] = {
      "Background", "Text", "Keywords", "Commands", "Comments",
      "Strings", "Preprocessor", "Numbers", "Selection"
   };
   const char * colorDefaults[] = {
      "#1E1E1E", "#D4D4D4", "#569CD6", "#4EC9B0", "#6A9955",
      "#CE9178", "#C586C0", "#B5CEA8", "#264F78"
   };
   GtkWidget * colorBtns[9];

   GtkWidget * grid = gtk_grid_new();
   gtk_grid_set_row_spacing( GTK_GRID(grid), 4 );
   gtk_grid_set_column_spacing( GTK_GRID(grid), 8 );
   gtk_box_pack_start( GTK_BOX(content), grid, FALSE, FALSE, 4 );

   { int c;
     for( c = 0; c < 9; c++ ) {
        GtkWidget * lbl = gtk_label_new( colorLabels[c] );
        gtk_label_set_xalign( GTK_LABEL(lbl), 0.0 );
        gtk_grid_attach( GTK_GRID(grid), lbl, 0, c, 1, 1 );
        GdkRGBA rgba;
        gdk_rgba_parse( &rgba, colorDefaults[c] );
        colorBtns[c] = gtk_color_button_new_with_rgba( &rgba );
        gtk_color_chooser_set_use_alpha( GTK_COLOR_CHOOSER(colorBtns[c]), FALSE );
        gtk_grid_attach( GTK_GRID(grid), colorBtns[c], 1, c, 1, 1 );
     }
   }

   /* Preset buttons */
   GtkWidget * presetBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
   gtk_box_pack_start( GTK_BOX(content), presetBox, FALSE, FALSE, 4 );
   gtk_box_pack_start( GTK_BOX(presetBox), gtk_label_new("Presets:"), FALSE, FALSE, 4 );
   { const char * presets[] = { "Dark", "Light", "Monokai", "Solarized" };
     int p; for( p = 0; p < 4; p++ )
        gtk_box_pack_start( GTK_BOX(presetBox),
           gtk_button_new_with_label( presets[p] ), FALSE, FALSE, 0 );
   }

   /* Preview */
   gtk_box_pack_start( GTK_BOX(content), gtk_label_new("Preview:"), FALSE, FALSE, 2 );
   GtkWidget * prevSw = gtk_scrolled_window_new( NULL, NULL );
   gtk_widget_set_size_request( prevSw, -1, 100 );
   gtk_box_pack_start( GTK_BOX(content), prevSw, TRUE, TRUE, 0 );
   GtkWidget * prevTv = gtk_text_view_new();
   gtk_text_view_set_editable( GTK_TEXT_VIEW(prevTv), FALSE );
   gtk_text_view_set_monospace( GTK_TEXT_VIEW(prevTv), TRUE );
   { GtkTextBuffer * pbuf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(prevTv) );
     gtk_text_buffer_set_text( pbuf,
        "// Preview\nfunction Main()\n   local x := 42\n"
        "   MsgInfo( \"Hello\" )\nreturn nil\n", -1 );
   }
   /* Dark preview */
   { GtkCssProvider * cp = gtk_css_provider_new();
     gtk_css_provider_load_from_data( cp,
        "textview text { background-color: #1E1E1E; color: #D4D4D4;"
        "  font-family: Monospace; font-size: 12pt; }", -1, NULL );
     gtk_style_context_add_provider( gtk_widget_get_style_context(prevTv),
        GTK_STYLE_PROVIDER(cp), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
     g_object_unref( cp );
   }
   gtk_container_add( GTK_CONTAINER(prevSw), prevTv );

   gtk_widget_show_all( dlg );
   gtk_dialog_run( GTK_DIALOG(dlg) );
   gtk_widget_destroy( dlg );
}

/* ======================================================================
 * Project Options Dialog - build settings with 4 tabs
 * ====================================================================== */

HB_FUNC( GTK_PROJECTOPTIONSDIALOG )
{
   EnsureGTK();

   GtkWidget * dlg = gtk_dialog_new_with_buttons( "Project Options",
      NULL, GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "_OK", GTK_RESPONSE_OK, "_Cancel", GTK_RESPONSE_CANCEL, NULL );
   gtk_window_set_default_size( GTK_WINDOW(dlg), 520, 440 );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dlg) );

   GtkWidget * nb = gtk_notebook_new();
   gtk_box_pack_start( GTK_BOX(content), nb, TRUE, TRUE, 0 );

   const char * defHbDir  = HB_ISCHAR(1) ? hb_parc(1) : "~/harbour";
   const char * defCDir   = HB_ISCHAR(2) ? hb_parc(2) : "/usr/bin";
   const char * defPDir   = HB_ISCHAR(3) ? hb_parc(3) : ".";
   const char * defODir   = HB_ISCHAR(4) ? hb_parc(4) : "./build";
   const char * defHbFlag = HB_ISCHAR(5) ? hb_parc(5) : "-n -w -q";
   const char * defCFlag  = HB_ISCHAR(6) ? hb_parc(6) : "-g -Wno-unused-value";
   const char * defLFlag  = HB_ISCHAR(7) ? hb_parc(7) : "";
   const char * defInc    = HB_ISCHAR(8) ? hb_parc(8) : "";
   const char * defLib    = HB_ISCHAR(9) ? hb_parc(9) : "";
   const char * defLibs   = HB_ISCHAR(10) ? hb_parc(10) : "";

   /* Tab 0: Harbour */
   { GtkWidget * g = gtk_grid_new();
     gtk_grid_set_row_spacing( GTK_GRID(g), 8 );
     gtk_grid_set_column_spacing( GTK_GRID(g), 8 );
     gtk_container_set_border_width( GTK_CONTAINER(g), 10 );
     GtkWidget * e;
     gtk_grid_attach( GTK_GRID(g), gtk_label_new("Harbour directory:"), 0, 0, 1, 1 );
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defHbDir);
     gtk_widget_set_hexpand(e,TRUE); gtk_grid_attach(GTK_GRID(g),e,1,0,1,1);
     gtk_grid_attach( GTK_GRID(g), gtk_label_new("Compiler flags:"), 0, 1, 1, 1 );
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defHbFlag);
     gtk_grid_attach(GTK_GRID(g),e,1,1,1,1);
     gtk_grid_attach(GTK_GRID(g),
        gtk_check_button_new_with_label("Enable warnings"),0,2,2,1);
     gtk_grid_attach(GTK_GRID(g),
        gtk_check_button_new_with_label("Debug info"),0,3,2,1);
     gtk_notebook_append_page(GTK_NOTEBOOK(nb),g,gtk_label_new("Harbour"));
   }

   /* Tab 1: C Compiler */
   { GtkWidget * g = gtk_grid_new();
     gtk_grid_set_row_spacing( GTK_GRID(g), 8 );
     gtk_grid_set_column_spacing( GTK_GRID(g), 8 );
     gtk_container_set_border_width( GTK_CONTAINER(g), 10 );
     GtkWidget * e;
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("C Compiler directory:"),0,0,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defCDir);
     gtk_widget_set_hexpand(e,TRUE); gtk_grid_attach(GTK_GRID(g),e,1,0,1,1);
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("C compiler flags:"),0,1,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defCFlag);
     gtk_grid_attach(GTK_GRID(g),e,1,1,1,1);
     gtk_grid_attach(GTK_GRID(g),
        gtk_check_button_new_with_label("Enable optimization (-O2)"),0,2,2,1);
     gtk_notebook_append_page(GTK_NOTEBOOK(nb),g,gtk_label_new("C Compiler"));
   }

   /* Tab 2: Linker */
   { GtkWidget * g = gtk_grid_new();
     gtk_grid_set_row_spacing( GTK_GRID(g), 8 );
     gtk_grid_set_column_spacing( GTK_GRID(g), 8 );
     gtk_container_set_border_width( GTK_CONTAINER(g), 10 );
     GtkWidget * e;
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("Linker flags:"),0,0,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defLFlag);
     gtk_widget_set_hexpand(e,TRUE); gtk_grid_attach(GTK_GRID(g),e,1,0,1,1);
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("Libraries:"),0,1,1,1);
     GtkWidget * sw2 = gtk_scrolled_window_new(NULL,NULL);
     gtk_widget_set_size_request(sw2,-1,150);
     GtkWidget * tv2 = gtk_text_view_new();
     gtk_text_view_set_monospace(GTK_TEXT_VIEW(tv2),TRUE);
     if( defLibs[0] ) {
        GtkTextBuffer * b2 = gtk_text_view_get_buffer(GTK_TEXT_VIEW(tv2));
        gtk_text_buffer_set_text(b2,defLibs,-1);
     }
     gtk_container_add(GTK_CONTAINER(sw2),tv2);
     gtk_widget_set_hexpand(sw2,TRUE); gtk_widget_set_vexpand(sw2,TRUE);
     gtk_grid_attach(GTK_GRID(g),sw2,1,1,1,1);
     gtk_notebook_append_page(GTK_NOTEBOOK(nb),g,gtk_label_new("Linker"));
   }

   /* Tab 3: Directories */
   { GtkWidget * g = gtk_grid_new();
     gtk_grid_set_row_spacing( GTK_GRID(g), 8 );
     gtk_grid_set_column_spacing( GTK_GRID(g), 8 );
     gtk_container_set_border_width( GTK_CONTAINER(g), 10 );
     GtkWidget * e;
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("Project directory:"),0,0,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defPDir);
     gtk_widget_set_hexpand(e,TRUE); gtk_grid_attach(GTK_GRID(g),e,1,0,1,1);
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("Output directory:"),0,1,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defODir);
     gtk_grid_attach(GTK_GRID(g),e,1,1,1,1);
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("Include paths:"),0,2,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defInc);
     gtk_grid_attach(GTK_GRID(g),e,1,2,1,1);
     gtk_grid_attach(GTK_GRID(g),gtk_label_new("Library paths:"),0,3,1,1);
     e = gtk_entry_new(); gtk_entry_set_text(GTK_ENTRY(e),defLib);
     gtk_grid_attach(GTK_GRID(g),e,1,3,1,1);
     gtk_notebook_append_page(GTK_NOTEBOOK(nb),g,gtk_label_new("Directories"));
   }

   gtk_widget_show_all( dlg );
   gtk_dialog_run( GTK_DIALOG(dlg) );
   gtk_widget_destroy( dlg );
}

/* ======================================================================
 * Integrated Debugger Engine
 * Runs user .hrb code inside the IDE's Harbour VM with debug hooks.
 * The debug callback pauses execution and processes GTK events,
 * allowing the Debugger panel to update and accept user commands.
 * ====================================================================== */

#include <hbapidbg.h>

/* Debugger states */
#define DBG_IDLE      0
#define DBG_RUNNING   1
#define DBG_PAUSED    2
#define DBG_STEPPING  3
#define DBG_STEPOVER  4
#define DBG_STOPPED   5

static int           s_dbgState = DBG_IDLE;
static int           s_dbgWasStepping = 0;  /* .T. if last PAUSE arrived while in STEPPING mode */

/* Provide pointer to s_dbgState for the debug panel toolbar buttons */
static int * _dbg_state_ptr(void) { return &s_dbgState; }
static int           s_dbgLine = 0;
static int           s_dbgStepDepth = 0;
static char          s_dbgModule[256] = "";
static GtkWidget *   s_dbgOutputTV = NULL;
static PHB_ITEM      s_dbgOnPause = NULL;

static int DbgIsBreakpoint( const char * module, int line )
{
   int i;
   for( i = 0; i < s_nBreakpoints; i++ )
      if( s_breakpoints[i].line == line &&
          ( s_breakpoints[i].module[0] == 0 || strcasestr( module, s_breakpoints[i].module ) ) )
         return 1;
   return 0;
}

static void DbgOutput( const char * text )
{
   /* Use panel's output TV if debugger engine's is not set */
   if( !s_dbgOutputTV && s_dbgOutputTV_panel ) s_dbgOutputTV = s_dbgOutputTV_panel;
   if( !s_dbgOutputTV ) return;
   GtkTextBuffer * buf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(s_dbgOutputTV) );
   GtkTextIter end;
   gtk_text_buffer_get_end_iter( buf, &end );
   gtk_text_buffer_insert( buf, &end, text, -1 );
   gtk_text_buffer_get_end_iter( buf, &end );
   GtkTextMark * mark = gtk_text_buffer_get_mark( buf, "insert" );
   gtk_text_buffer_move_mark( buf, mark, &end );
   gtk_text_view_scroll_mark_onscreen( GTK_TEXT_VIEW(s_dbgOutputTV), mark );
}

/* Debug hook - called by Harbour VM on each line */
static void IDE_DebugHook( int nMode, int nLine, const char * szName,
                            int nIndex, PHB_ITEM pFrame )
{
   (void)nIndex; (void)pFrame;

   if( nMode == 1 && szName ) /* HB_DBG_MODULENAME */
      strncpy( s_dbgModule, szName, sizeof(s_dbgModule) - 1 );

   if( nMode != 5 ) return; /* Only process HB_DBG_SHOWLINE */

   s_dbgLine = nLine;
   if( s_dbgState == DBG_STOPPED ) return;

   if( s_dbgState == DBG_RUNNING && !DbgIsBreakpoint( s_dbgModule, nLine ) )
      return;

   if( s_dbgState == DBG_STEPOVER )
   {
      HB_ULONG curDepth = hb_dbg_ProcLevel();
      if( (int)curDepth > s_dbgStepDepth ) return;
   }

   /* === PAUSE === */
   s_dbgState = DBG_PAUSED;

   /* Notify Harbour callback */
   if( s_dbgOnPause && HB_IS_BLOCK( s_dbgOnPause ) )
   {
      PHB_ITEM pMod  = hb_itemPutC( NULL, s_dbgModule );
      PHB_ITEM pLine = hb_itemPutNI( NULL, nLine );
      hb_itemDo( s_dbgOnPause, 2, pMod, pLine );
      hb_itemRelease( pMod );
      hb_itemRelease( pLine );
   }

   { char msg[512];
     snprintf( msg, sizeof(msg), "Paused at %s:%d\n", s_dbgModule, nLine );
     DbgOutput( msg );
   }

   /* Process GTK events while paused */
   while( s_dbgState == DBG_PAUSED )
      gtk_main_iteration_do( TRUE );

   if( s_dbgState == DBG_STOPPED )
      DbgOutput( "Debug session stopped.\n" );
}

/* IDE_DebugStart( cHrbFile, bOnPause ) -> lSuccess */
HB_FUNC( IDE_DEBUGSTART )
{
   const char * cHrbFile = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   if( !cHrbFile || s_dbgState != DBG_IDLE ) { hb_retl( HB_FALSE ); return; }

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Install debug hook */
   hb_dbg_SetEntry( IDE_DebugHook );
   s_dbgState = DBG_STEPPING;
   s_nBreakpoints = 0;

   DbgOutput( "=== Debug session started ===\n" );
   { char msg[512]; snprintf( msg, sizeof(msg), "Loading: %s\n", cHrbFile ); DbgOutput( msg ); }

   /* Execute .hrb via Harbour's hb_hrbRun() */
   {
      PHB_DYNS pDyn = hb_dynsymFind( "HB_HRBRUN" );
      if( pDyn )
      {
         PHB_ITEM pFile = hb_itemPutC( NULL, cHrbFile );
         hb_vmPushDynSym( pDyn );
         hb_vmPushNil();
         hb_vmPush( pFile );
         hb_vmDo( 1 );
         hb_itemRelease( pFile );
      }
      else
      {
         DbgOutput( "ERROR: HB_HRBRUN symbol not found. Link with -lhbvm.\n" );
      }
   }

   hb_dbg_SetEntry( NULL );
   s_dbgState = DBG_IDLE;
   DbgOutput( "=== Debug session ended ===\n" );
   hb_retl( HB_TRUE );
}

/* Debug control commands */
HB_FUNC( IDE_DEBUGGO )       { if( s_dbgState == DBG_PAUSED ) { s_dbgWasStepping = 0; s_dbgState = DBG_RUNNING; } }
HB_FUNC( IDE_DEBUGSTEP )     { if( s_dbgState == DBG_PAUSED ) { s_dbgWasStepping = 1; s_dbgState = DBG_STEPPING; } }
HB_FUNC( IDE_DEBUGSTEPOVER ) {
   if( s_dbgState == DBG_PAUSED ) {
      s_dbgWasStepping = 1;
      s_dbgStepDepth = (int) hb_dbg_ProcLevel();
      s_dbgState = DBG_STEPOVER;
   }
}
HB_FUNC( IDE_DEBUGSTOP )     { if( s_dbgState != DBG_IDLE ) s_dbgState = DBG_STOPPED; }

/* Breakpoint management */
HB_FUNC( IDE_DEBUGADDBREAKPOINT )
{
   if( s_nBreakpoints >= DBG_MAX_BP ) return;
   const char * mod = HB_ISCHAR(1) ? hb_parc(1) : "";
   strncpy( s_breakpoints[s_nBreakpoints].module, mod, 255 );
   s_breakpoints[s_nBreakpoints].line = hb_parni(2);
   s_nBreakpoints++;
}

HB_FUNC( IDE_DEBUGCLEARBREAKPOINTS ) { s_nBreakpoints = 0; }

/* IDE_IsBreakpoint( cFile, nLine ) — exact source filename + line matching */
HB_FUNC( IDE_ISBREAKPOINT )
{
   const char * cFile = HB_ISCHAR(1) ? hb_parc(1) : "";
   int nLine = hb_parni(2);
   int i;
   for( i = 0; i < s_nBreakpoints; i++ )
      if( s_breakpoints[i].line == nLine &&
          ( s_breakpoints[i].module[0] == 0 ||
            strcasestr( cFile, s_breakpoints[i].module ) != NULL ||
            strcasestr( s_breakpoints[i].module, cFile ) != NULL ) )
      {
         hb_retl( HB_TRUE );
         return;
      }
   hb_retl( HB_FALSE );
}

HB_FUNC( IDE_DBGISSTEPPING )
{
   hb_retl( s_dbgWasStepping );
}

/* Always .F. on Linux — no NSApp-style run loop to detect */
HB_FUNC( IDE_DBGRUNLOOPENDED )
{
   hb_retl( HB_FALSE );
}

/* Pump GTK events for ~20ms — keeps executed form responsive during step */
HB_FUNC( IDE_DBGPUMPEVENTS )
{
   int i;
   for( i = 0; i < 4; i++ ) {
      while( gtk_events_pending() )
         gtk_main_iteration_do( FALSE );
      g_usleep( 5000 );
   }
}

HB_FUNC( IDE_DEBUGPAUSEATSTEP ) {}

/* State queries */
HB_FUNC( IDE_DEBUGGETSTATE )  { hb_retni( s_dbgState ); }
HB_FUNC( IDE_DEBUGGETLINE )   { hb_retni( s_dbgLine ); }
HB_FUNC( IDE_DEBUGGETMODULE ) { hb_retc( s_dbgModule ); }

/* IDE_DebugGetLocals( nLevel ) -> { {cName,cValue,cType}, ... } */
HB_FUNC( IDE_DEBUGGETLOCALS )
{
   int nLevel = HB_ISNUM(1) ? hb_parni(1) : 1;
   PHB_ITEM pArray = hb_itemArrayNew( 0 );
   int i;

   for( i = 1; i <= 30; i++ )
   {
      PHB_ITEM pVal = hb_dbg_vmVarLGet( nLevel, i );
      if( !pVal ) break;

      PHB_ITEM pEntry = hb_itemArrayNew( 3 );
      char szName[32], szValue[256], szType[32];
      snprintf( szName, sizeof(szName), "Local_%d", i );

      switch( hb_itemType( pVal ) )
      {
         case HB_IT_STRING:
            snprintf( szValue, sizeof(szValue), "\"%.*s\"",
               (int)(hb_itemGetCLen(pVal) > 200 ? 200 : hb_itemGetCLen(pVal)),
               hb_itemGetCPtr(pVal) );
            strcpy( szType, "String" ); break;
         case HB_IT_INTEGER: case HB_IT_LONG: case HB_IT_NUMERIC:
            snprintf( szValue, sizeof(szValue), "%g", hb_itemGetND(pVal) );
            strcpy( szType, "Numeric" ); break;
         case HB_IT_LOGICAL:
            strcpy( szValue, hb_itemGetL(pVal) ? ".T." : ".F." );
            strcpy( szType, "Logical" ); break;
         case HB_IT_NIL:
            strcpy( szValue, "NIL" ); strcpy( szType, "NIL" ); break;
         case HB_IT_ARRAY:
            snprintf( szValue, sizeof(szValue), "Array(%lu)", (unsigned long)hb_arrayLen(pVal) );
            strcpy( szType, "Array" ); break;
         case HB_IT_BLOCK:
            strcpy( szValue, "{||}" ); strcpy( szType, "Block" ); break;
         default:
            if( hb_itemType(pVal) & HB_IT_OBJECT )
               { strcpy( szValue, "(object)" ); strcpy( szType, "Object" ); }
            else
               { strcpy( szValue, "(?)" ); strcpy( szType, "?" ); }
            break;
      }
      hb_arraySetC( pEntry, 1, szName );
      hb_arraySetC( pEntry, 2, szValue );
      hb_arraySetC( pEntry, 3, szType );
      hb_arrayAdd( pArray, pEntry );
      hb_itemRelease( pEntry );
   }
   hb_itemReturnRelease( pArray );
}

/* IDE_DebugSetOutputTV() - find and store the Output tab textview */
HB_FUNC( IDE_DEBUGSETOUTPUTTV )
{
   s_dbgOutputTV = NULL;
   if( !s_hDbgWnd ) return;
   GtkWidget * nb = gtk_bin_get_child( GTK_BIN(s_hDbgWnd) );
   if( !GTK_IS_NOTEBOOK(nb) ) return;
   GtkWidget * sw = gtk_notebook_get_nth_page( GTK_NOTEBOOK(nb), 4 );
   if( !sw ) return;
   GtkWidget * child = gtk_bin_get_child( GTK_BIN(sw) );
   if( GTK_IS_TEXT_VIEW(child) ) s_dbgOutputTV = child;
}

/* ======================================================================
 * Socket-based debugger (IDE_DebugStart2) — port from macOS
 * ====================================================================== */

static int s_dbgServerFD = -1;
static int s_dbgClientFD = -1;
static char s_dbgRecvBuf[8192];
static int  s_dbgRecvLen = 0;

static int DbgServerStart( int port )
{
   int fd = socket( AF_INET, SOCK_STREAM, 0 );
   if( fd < 0 ) return -1;
   int yes = 1;
   setsockopt( fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes) );
   struct sockaddr_in addr;
   memset( &addr, 0, sizeof(addr) );
   addr.sin_family = AF_INET;
   addr.sin_addr.s_addr = htonl( INADDR_LOOPBACK );
   addr.sin_port = htons( (uint16_t)port );
   if( bind( fd, (struct sockaddr *)&addr, sizeof(addr) ) < 0 ||
       listen( fd, 1 ) < 0 ) { close( fd ); return -1; }
   s_dbgServerFD = fd;
   return 0;
}

static int DbgServerAccept( double timeoutSec )
{
   fd_set fds;
   struct timeval tv;
   double elapsed = 0;
   while( elapsed < timeoutSec )
   {
      FD_ZERO( &fds );
      FD_SET( s_dbgServerFD, &fds );
      tv.tv_sec = 0; tv.tv_usec = 200000;
      if( select( s_dbgServerFD + 1, &fds, NULL, NULL, &tv ) > 0 )
      {
         s_dbgClientFD = accept( s_dbgServerFD, NULL, NULL );
         if( s_dbgClientFD >= 0 ) return 0;
      }
      /* Pump GTK events while waiting */
      while( gtk_events_pending() )
         gtk_main_iteration_do( FALSE );
      if( s_dbgState == DBG_STOPPED ) return -1;
      elapsed += 0.25;
   }
   return -1;
}

static void DbgServerSend( const char * cmd )
{
   if( s_dbgClientFD < 0 ) return;
   char buf[512];
   snprintf( buf, sizeof(buf), "%s\n", cmd );
   send( s_dbgClientFD, buf, strlen(buf), MSG_NOSIGNAL );
}

/* Receive one complete line from the debug client (line-buffered).
 * Returns length of line (without \n), or -1 on disconnect. */
static int DbgServerRecv( char * buf, int bufSize )
{
   if( s_dbgClientFD < 0 ) return -1;

   while(1) {
      /* Check if we already have a complete line in the buffer */
      int i;
      for( i = 0; i < s_dbgRecvLen; i++ )
      {
         if( s_dbgRecvBuf[i] == '\n' )
         {
            int lineLen = i;
            /* Strip trailing \r */
            while( lineLen > 0 && s_dbgRecvBuf[lineLen-1] == '\r' ) lineLen--;
            if( lineLen >= bufSize ) lineLen = bufSize - 1;
            memcpy( buf, s_dbgRecvBuf, (size_t)lineLen );
            buf[lineLen] = 0;
            /* Remove consumed data from buffer */
            int consumed = i + 1;
            s_dbgRecvLen -= consumed;
            if( s_dbgRecvLen > 0 )
               memmove( s_dbgRecvBuf, s_dbgRecvBuf + consumed, (size_t)s_dbgRecvLen );
            return lineLen;
         }
      }

      /* No complete line yet — read more data */
      fd_set fds; struct timeval tv;
      FD_ZERO( &fds );
      FD_SET( s_dbgClientFD, &fds );
      tv.tv_sec = 0; tv.tv_usec = 100000;
      int r = select( s_dbgClientFD + 1, &fds, NULL, NULL, &tv );
      if( r > 0 ) {
         int space = (int)sizeof(s_dbgRecvBuf) - s_dbgRecvLen - 1;
         if( space <= 0 ) { s_dbgRecvLen = 0; continue; }  /* overflow: reset */
         ssize_t n = recv( s_dbgClientFD, s_dbgRecvBuf + s_dbgRecvLen, (size_t)space, 0 );
         if( n <= 0 ) return -1;
         s_dbgRecvLen += (int)n;
      }

      /* Pump GTK events while waiting */
      while( gtk_events_pending() )
         gtk_main_iteration_do( FALSE );
      if( s_dbgState == DBG_STOPPED ) return -1;
   }
}

static void DbgServerStop(void)
{
   if( s_dbgClientFD >= 0 ) { close( s_dbgClientFD ); s_dbgClientFD = -1; }
   if( s_dbgServerFD >= 0 ) { close( s_dbgServerFD ); s_dbgServerFD = -1; }
   s_dbgRecvLen = 0;
}

/* IDE_DebugStart2( cExePath, bOnPause ) — socket-based debug session */
HB_FUNC( IDE_DEBUGSTART2 )
{
   const char * cExePath = hb_parc(1);
   PHB_ITEM pOnPause = hb_param(2, HB_IT_BLOCK);

   setbuf(stderr, NULL);
   fprintf(stderr, "IDE-DBG: IDE_DebugStart2 called exe='%s'\n", cExePath ? cExePath : "(null)");
   if( !cExePath || s_dbgState != DBG_IDLE ) { fprintf(stderr, "IDE-DBG: rejected (null=%d state=%d)\n", !cExePath, s_dbgState); hb_retl( HB_FALSE ); return; }

   /* Ignore SIGPIPE — prevents crash when debug client disconnects */
   signal( SIGPIPE, SIG_IGN );

   /* Clean up any previous debug session */
   DbgServerStop();
   system( "killall DebugApp 2>/dev/null" );

   if( s_dbgOnPause ) { hb_itemRelease( s_dbgOnPause ); s_dbgOnPause = NULL; }
   if( pOnPause ) s_dbgOnPause = hb_itemNew( pOnPause );

   /* Start TCP server */
   fprintf(stderr, "IDE-DBG: starting server on port 19800...\n");
   int startResult = DbgServerStart( 19800 );
   fprintf(stderr, "IDE-DBG: DbgServerStart returned %d\n", startResult);
   if( startResult != 0 )
   {
      fprintf(stderr, "IDE-DBG: SERVER START FAILED errno=%d\n", errno);
      DbgOutput( "ERROR: Could not start debug server on port 19800\n" );
      hb_retl( HB_FALSE );
      return;
   }

   s_dbgState = DBG_STEPPING;
   DbgOutput( "=== Debug session started (socket) ===\n" );
   DbgOutput( "Listening on port 19800...\n" );

   /* Launch user executable */
   {
      char cmd[1024];
      snprintf( cmd, sizeof(cmd), "\"%s\" 2>/tmp/hb_debugapp.txt &", cExePath );
      system( cmd );
   }
   DbgOutput( "Launched debug process. Waiting for connection...\n" );

   if( s_dbgStatusLbl )
      gtk_label_set_text( GTK_LABEL(s_dbgStatusLbl), "Waiting for debug client..." );

   /* Accept connection */
   fprintf(stderr, "IDE-DBG: waiting for connection...\n");
   if( DbgServerAccept( 30.0 ) != 0 )
   {
      fprintf(stderr, "IDE-DBG: accept FAILED\n");
      DbgOutput( "ERROR: Client did not connect within 30s\n" );
      DbgServerStop();
      s_dbgState = DBG_IDLE;
      hb_retl( HB_FALSE );
      return;
   }
   fprintf(stderr, "IDE-DBG: client connected!\n");
   DbgOutput( "Client connected.\n" );

   /* Command loop */
   char recvBuf[4096];
   s_dbgState = DBG_PAUSED;
   fprintf(stderr, "IDE-DBG: entering command loop\n");

   while( s_dbgState != DBG_IDLE && s_dbgState != DBG_STOPPED )
   {
      int n = DbgServerRecv( recvBuf, sizeof(recvBuf) );
      fprintf(stderr, "IDE-DBG: recv n=%d buf='%.80s'\n", n, n > 0 ? recvBuf : "");
      if( n <= 0 ) {
         fprintf(stderr, "IDE-DBG: client disconnected\n");
         DbgOutput( "Client disconnected.\n" );
         break;
      }

      if( strncmp( recvBuf, "HELLO", 5 ) == 0 )
      {
         DbgOutput( recvBuf ); DbgOutput( "\n" );
         DbgServerSend( "STEP" );
         s_dbgState = DBG_PAUSED;
         continue;
      }

      if( strncmp( recvBuf, "DONE", 4 ) == 0 )
      {
         DbgOutput( "Debug client finished (form closed).\n" );
         break;
      }

      if( strncmp( recvBuf, "PAUSE ", 6 ) == 0 )
      {
         /* Format: PAUSE filepath:FUNCNAME:line|VARS ...|STACK ... */
         char localsStr[4096] = "VARS";
         char stackStr[4096] = "STACK";

         char * pipe1 = strchr( recvBuf, '|' );
         if( pipe1 ) {
            *pipe1 = 0;
            char * pipe2 = strchr( pipe1 + 1, '|' );
            if( pipe2 ) {
               *pipe2 = 0;
               strncpy( localsStr, pipe1 + 1, sizeof(localsStr) - 1 );
               strncpy( stackStr, pipe2 + 1, sizeof(stackStr) - 1 );
            } else {
               strncpy( localsStr, pipe1 + 1, sizeof(localsStr) - 1 );
            }
         }

         /* Parse PAUSE filepath:FUNCNAME:line */
         char * lastColon = strrchr( recvBuf + 6, ':' );
         if( !lastColon ) continue;
         int line = atoi( lastColon + 1 );
         *lastColon = 0;

         char * funcColon = strrchr( recvBuf + 6, ':' );
         const char * funcName = "";
         if( funcColon ) {
            funcName = funcColon + 1;
         }

         s_dbgLine = line;

         /* In RUNNING mode: always send STEP so subprocess keeps sending PAUSE.
          * The callback (OnDebugPause) decides whether to actually stop, based on
          * IDE_IsBreakpoint() and IDE_DbgIsStepping(). This matches macOS behaviour. */
         if( s_dbgState == DBG_RUNNING )
         {
            s_dbgWasStepping = 0;
            DbgServerSend( "STEP" );
            s_dbgState = DBG_PAUSED;
            continue;
         }

         /* s_dbgWasStepping is set by IDE_DEBUGSTEP/STEPOVER and cleared by IDE_DEBUGGO.
          * Do NOT recompute it here — by the time PAUSE arrives, s_dbgState is already
          * DBG_PAUSED (set after sending STEP), which would wrongly clear the flag. */
         s_dbgState = DBG_PAUSED;

         /* Call Harbour callback: ( cFuncName, nLine, cLocals, cStack )
          * Returns .T. if user code (should pause), .F. if framework (auto-step). */
         HB_BOOL shouldPause = HB_TRUE;
         if( s_dbgOnPause && HB_IS_BLOCK( s_dbgOnPause ) )
         {
            PHB_ITEM pFunc   = hb_itemPutC( NULL, funcName );
            PHB_ITEM pLine   = hb_itemPutNI( NULL, line );
            PHB_ITEM pLocals = hb_itemPutC( NULL, localsStr );
            PHB_ITEM pStack  = hb_itemPutC( NULL, stackStr );
            PHB_ITEM pResult = hb_itemDo( s_dbgOnPause, 4, pFunc, pLine, pLocals, pStack );
            if( pResult && HB_IS_LOGICAL( pResult ) )
               shouldPause = hb_itemGetL( pResult );
            else
               shouldPause = HB_TRUE;
            hb_itemRelease( pFunc );
            hb_itemRelease( pLine );
            hb_itemRelease( pLocals );
            hb_itemRelease( pStack );
            if( pResult ) hb_itemRelease( pResult );
         }

         /* Framework code — auto-step */
         if( !shouldPause )
         {
            DbgServerSend( "STEP" );
            s_dbgState = DBG_PAUSED;
            continue;
         }

         /* Update status */
         if( s_dbgStatusLbl ) {
            char status[512];
            snprintf(status, sizeof(status), "Paused at %s() line %d", funcName, line);
            gtk_label_set_text( GTK_LABEL(s_dbgStatusLbl), status );
         }

         /* Wait for user action (Step/Go/Stop via debug panel buttons) */
         while( s_dbgState == DBG_PAUSED )
         {
            gtk_main_iteration_do( TRUE );
         }

         /* Send command based on new state */
         if( s_dbgState == DBG_STEPPING || s_dbgState == DBG_STEPOVER )
         {
            DbgServerSend( "STEP" );
            s_dbgState = DBG_PAUSED;
         }
         else if( s_dbgState == DBG_RUNNING )
            DbgServerSend( "GO" );
         else if( s_dbgState == DBG_STOPPED )
            DbgServerSend( "QUIT" );
      }
   }

   /* Cleanup */
   DbgServerSend( "QUIT" );
   DbgServerStop();

   /* Kill any remaining DebugApp process */
   system( "killall DebugApp 2>/dev/null" );

   s_dbgState = DBG_IDLE;
   s_dbgRecvLen = 0;

   hb_retl( HB_TRUE );
}

/* ======================================================================
 * Report Designer - Visual band/field editor with Cairo rendering
 * ====================================================================== */

#include <math.h>

#define RPT_MAX_BANDS  20
#define RPT_MAX_FIELDS 50
#define RPT_MARGIN_W   24
#define RPT_RULER_H    24
#define RPT_PAGE_PAD   30
#define RPT_HANDLE_SZ  6

typedef struct {
   char cName[32];
   char cText[128];
   char cFieldName[64];
   int  nLeft, nTop, nWidth, nHeight;
   int  nAlignment;   /* 0=Left, 1=Center, 2=Right */
} RptField;

typedef struct {
   char     cName[32];
   int      nHeight;
   int      nFieldCount;
   RptField fields[RPT_MAX_FIELDS];
   double   colorR, colorG, colorB;
   int      lPrintOnEveryPage;
   int      lKeepTogether;
   int      lVisible;
} RptBand;

static GtkWidget * s_rptDesigner = NULL;
static GtkWidget * s_rptDrawArea = NULL;
static RptBand     s_rptBands[RPT_MAX_BANDS];
static int         s_rptBandCount = 0;
static int         s_rptSelBand  = -1;
static int         s_rptSelField = -1;
static int         s_rptPageWidth  = 210;  /* mm, A4 */
static int         s_rptPageHeight = 297;
static int         s_rptScale = 3;         /* pixels per mm */

/* Drag state */
static int  s_rptDragging = 0;    /* 0=none, 1=move field, 2=resize band */
static int  s_rptDragStartX = 0;
static int  s_rptDragStartY = 0;
static int  s_rptDragOrigX  = 0;
static int  s_rptDragOrigY  = 0;
static int  s_rptDragOrigH  = 0;

/* Band color lookup */
static void rpt_band_color( const char * name, double * r, double * g, double * b )
{
   if( strcasecmp( name, "Header" ) == 0 || strcasecmp( name, "Footer" ) == 0 )
      { *r = 0.290; *g = 0.565; *b = 0.851; }
   else if( strcasecmp( name, "Detail" ) == 0 )
      { *r = 0.850; *g = 0.850; *b = 0.850; }
   else if( strncasecmp( name, "Group", 5 ) == 0 )
      { *r = 0.420; *g = 0.749; *b = 0.420; }
   else if( strncasecmp( name, "Page", 4 ) == 0 )
      { *r = 0.831; *g = 0.659; *b = 0.263; }
   else
      { *r = 0.600; *g = 0.600; *b = 0.600; }
}

/* Compute Y offset for a given band (cumulative) */
static int rpt_band_y( int idx )
{
   int y = RPT_RULER_H;
   int i;
   for( i = 0; i < idx && i < s_rptBandCount; i++ )
      y += s_rptBands[i].nHeight + 2;  /* 2px separator */
   return y;
}

/* ---- Cairo draw callback ---- */
static gboolean on_report_draw( GtkWidget * widget, cairo_t * cr, gpointer data )
{
   (void)data;
   GtkAllocation alloc;
   gtk_widget_get_allocation( widget, &alloc );

   int pageW = s_rptPageWidth * s_rptScale;
   int pageX = RPT_PAGE_PAD;

   /* Dark background */
   cairo_set_source_rgb( cr, 0.145, 0.145, 0.149 );
   cairo_paint( cr );

   /* Page area (white surround) */
   int totalBandH = rpt_band_y( s_rptBandCount ) - RPT_RULER_H;
   int pageH = totalBandH > 200 ? totalBandH + RPT_RULER_H + 20 : s_rptPageHeight * s_rptScale;
   cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
   cairo_rectangle( cr, pageX, RPT_RULER_H, pageW, pageH );
   cairo_fill( cr );

   /* ---- Ruler ---- */
   cairo_set_source_rgb( cr, 0.220, 0.220, 0.220 );
   cairo_rectangle( cr, pageX, 0, pageW, RPT_RULER_H );
   cairo_fill( cr );

   cairo_set_source_rgb( cr, 0.800, 0.800, 0.800 );
   cairo_select_font_face( cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL );
   cairo_set_font_size( cr, 9.0 );
   { int mm;
     for( mm = 0; mm <= s_rptPageWidth; mm += 10 )
     {
        int rx = pageX + mm * s_rptScale;
        cairo_move_to( cr, rx, RPT_RULER_H - 2 );
        cairo_line_to( cr, rx, RPT_RULER_H - 10 );
        cairo_stroke( cr );

        if( mm % 50 == 0 )
        {
           char buf[16];
           snprintf( buf, sizeof(buf), "%d", mm );
           cairo_move_to( cr, rx + 2, 10 );
           cairo_show_text( cr, buf );
        }
     }
   }

   /* ---- Bands ---- */
   { int i;
     int bandY = RPT_RULER_H;
     for( i = 0; i < s_rptBandCount; i++ )
     {
        RptBand * b = &s_rptBands[i];
        int bH = b->nHeight;

        /* Left margin strip */
        cairo_set_source_rgb( cr, b->colorR, b->colorG, b->colorB );
        cairo_rectangle( cr, pageX, bandY, RPT_MARGIN_W, bH );
        cairo_fill( cr );

        /* Band name (rotated 90 deg) in margin */
        cairo_save( cr );
        cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
        cairo_set_font_size( cr, 9.0 );
        cairo_move_to( cr, pageX + 4, bandY + bH - 4 );
        cairo_rotate( cr, -G_PI / 2.0 );
        cairo_show_text( cr, b->cName );
        cairo_restore( cr );

        /* Band content area background */
        cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
        cairo_rectangle( cr, pageX + RPT_MARGIN_W, bandY, pageW - RPT_MARGIN_W, bH );
        cairo_fill( cr );

        /* Selected band highlight */
        if( i == s_rptSelBand && s_rptSelField < 0 )
        {
           cairo_set_source_rgba( cr, b->colorR, b->colorG, b->colorB, 0.12 );
           cairo_rectangle( cr, pageX + RPT_MARGIN_W, bandY, pageW - RPT_MARGIN_W, bH );
           cairo_fill( cr );
        }

        /* ---- Fields within band ---- */
        { int f;
          for( f = 0; f < b->nFieldCount; f++ )
          {
             RptField * fld = &b->fields[f];
             int fx = pageX + RPT_MARGIN_W + fld->nLeft;
             int fy = bandY + fld->nTop;
             int fw = fld->nWidth;
             int fh = fld->nHeight;

             /* Field rectangle */
             cairo_set_source_rgb( cr, 0.95, 0.95, 0.97 );
             cairo_rectangle( cr, fx, fy, fw, fh );
             cairo_fill( cr );

             cairo_set_source_rgb( cr, 0.70, 0.70, 0.70 );
             cairo_set_line_width( cr, 1.0 );
             cairo_rectangle( cr, fx + 0.5, fy + 0.5, fw, fh );
             cairo_stroke( cr );

             /* Field text */
             cairo_set_source_rgb( cr, 0.15, 0.15, 0.15 );
             cairo_set_font_size( cr, 10.0 );
             { const char * label = fld->cFieldName[0] ? fld->cFieldName : fld->cText;
               char display[140];
               if( fld->cFieldName[0] )
                  snprintf( display, sizeof(display), "[%s]", label );
               else
                  snprintf( display, sizeof(display), "%s", label );
               cairo_move_to( cr, fx + 3, fy + fh - 4 );
               cairo_show_text( cr, display );
             }

             /* Selection highlight */
             if( i == s_rptSelBand && f == s_rptSelField )
             {
                cairo_set_source_rgb( cr, 0.0, 0.47, 0.84 );
                cairo_set_line_width( cr, 2.0 );
                cairo_rectangle( cr, fx - 1, fy - 1, fw + 2, fh + 2 );
                cairo_stroke( cr );

                /* 4 corner handles */
                int hx[4], hy[4];
                hx[0] = fx - 3;            hy[0] = fy - 3;
                hx[1] = fx + fw - 3;       hy[1] = fy - 3;
                hx[2] = fx + fw - 3;       hy[2] = fy + fh - 3;
                hx[3] = fx - 3;            hy[3] = fy + fh - 3;
                { int j;
                  for( j = 0; j < 4; j++ )
                  {
                     cairo_set_source_rgb( cr, 1.0, 1.0, 1.0 );
                     cairo_rectangle( cr, hx[j], hy[j], RPT_HANDLE_SZ, RPT_HANDLE_SZ );
                     cairo_fill( cr );
                     cairo_set_source_rgb( cr, 0.0, 0.47, 0.84 );
                     cairo_rectangle( cr, hx[j], hy[j], RPT_HANDLE_SZ, RPT_HANDLE_SZ );
                     cairo_stroke( cr );
                  }
                }
             }
          }
        }

        /* Separator line between bands */
        cairo_set_source_rgb( cr, 0.60, 0.60, 0.60 );
        cairo_set_line_width( cr, 1.0 );
        { double dashes[] = { 4.0, 2.0 };
          cairo_set_dash( cr, dashes, 2, 0 );
        }
        cairo_move_to( cr, pageX, bandY + bH + 0.5 );
        cairo_line_to( cr, pageX + pageW, bandY + bH + 0.5 );
        cairo_stroke( cr );
        cairo_set_dash( cr, NULL, 0, 0 );

        /* Band height resize handle (small triangle at bottom-right of margin) */
        cairo_set_source_rgb( cr, b->colorR, b->colorG, b->colorB );
        { int hx = pageX + RPT_MARGIN_W - 2;
          int hy = bandY + bH - 1;
          cairo_move_to( cr, hx - 8, hy );
          cairo_line_to( cr, hx, hy );
          cairo_line_to( cr, hx, hy - 8 );
          cairo_close_path( cr );
          cairo_fill( cr );
        }

        bandY += bH + 2;
     }
   }

   /* Set minimum size for scrolling */
   { int minH = rpt_band_y( s_rptBandCount ) + 40;
     int minW = pageX + pageW + RPT_PAGE_PAD;
     gtk_widget_set_size_request( widget, minW, minH < 400 ? 400 : minH );
   }

   return FALSE;
}

/* ---- Mouse press ---- */
static gboolean on_report_click( GtkWidget * widget, GdkEventButton * ev, gpointer data )
{
   (void)widget; (void)data;
   if( ev->button != 1 ) return FALSE;

   int mx = (int)ev->x;
   int my = (int)ev->y;
   int pageX = RPT_PAGE_PAD;

   s_rptSelBand  = -1;
   s_rptSelField = -1;
   s_rptDragging = 0;

   /* Hit test bands */
   { int i;
     int bandY = RPT_RULER_H;
     for( i = 0; i < s_rptBandCount; i++ )
     {
        RptBand * b = &s_rptBands[i];
        int bH = b->nHeight;

        if( my >= bandY && my < bandY + bH + 2 )
        {
           /* Check resize handle area (bottom 8px of margin strip) */
           if( my >= bandY + bH - 8 && mx >= pageX && mx < pageX + RPT_MARGIN_W )
           {
              s_rptSelBand = i;
              s_rptDragging = 2;
              s_rptDragStartY = my;
              s_rptDragOrigH  = bH;
              goto done;
           }

           /* Check margin strip -> select band */
           if( mx >= pageX && mx < pageX + RPT_MARGIN_W )
           {
              s_rptSelBand = i;
              goto done;
           }

           /* Check fields */
           { int f;
             for( f = b->nFieldCount - 1; f >= 0; f-- )
             {
                RptField * fld = &b->fields[f];
                int fx = pageX + RPT_MARGIN_W + fld->nLeft;
                int fy = bandY + fld->nTop;
                if( mx >= fx && mx < fx + fld->nWidth &&
                    my >= fy && my < fy + fld->nHeight )
                {
                   s_rptSelBand  = i;
                   s_rptSelField = f;
                   s_rptDragging = 1;
                   s_rptDragStartX = mx;
                   s_rptDragStartY = my;
                   s_rptDragOrigX  = fld->nLeft;
                   s_rptDragOrigY  = fld->nTop;
                   goto done;
                }
             }
           }

           /* Clicked in band content area but not on a field */
           s_rptSelBand = i;
           goto done;
        }
        bandY += bH + 2;
     }
   }

done:
   gtk_widget_queue_draw( s_rptDrawArea );
   return TRUE;
}

/* ---- Mouse motion ---- */
static gboolean on_report_motion( GtkWidget * widget, GdkEventMotion * ev, gpointer data )
{
   (void)widget; (void)data;
   if( !s_rptDragging ) return FALSE;

   int mx = (int)ev->x;
   int my = (int)ev->y;

   if( s_rptDragging == 1 && s_rptSelBand >= 0 && s_rptSelField >= 0 )
   {
      /* Move field */
      RptField * fld = &s_rptBands[s_rptSelBand].fields[s_rptSelField];
      int dx = mx - s_rptDragStartX;
      int dy = my - s_rptDragStartY;
      int newLeft = s_rptDragOrigX + dx;
      int newTop  = s_rptDragOrigY + dy;
      if( newLeft < 0 ) newLeft = 0;
      if( newTop  < 0 ) newTop  = 0;
      fld->nLeft = newLeft;
      fld->nTop  = newTop;
      gtk_widget_queue_draw( s_rptDrawArea );
   }
   else if( s_rptDragging == 2 && s_rptSelBand >= 0 )
   {
      /* Resize band height */
      int dy = my - s_rptDragStartY;
      int newH = s_rptDragOrigH + dy;
      if( newH < 20 ) newH = 20;
      if( newH > 600 ) newH = 600;
      s_rptBands[s_rptSelBand].nHeight = newH;
      gtk_widget_queue_draw( s_rptDrawArea );
   }

   return TRUE;
}

/* ---- Mouse release ---- */
static gboolean on_report_release( GtkWidget * widget, GdkEventButton * ev, gpointer data )
{
   (void)widget; (void)ev; (void)data;
   s_rptDragging = 0;
   return TRUE;
}

/* ---- Toolbar callbacks ---- */
static void on_rpt_add_band_type( GtkMenuItem * item, gpointer data )
{
   (void)item;
   const char * name = (const char *)data;
   if( s_rptBandCount >= RPT_MAX_BANDS ) return;

   RptBand * b = &s_rptBands[s_rptBandCount];
   memset( b, 0, sizeof(RptBand) );
   strncpy( b->cName, name, sizeof(b->cName) - 1 );
   b->nHeight = 80;
   b->lVisible = 1;
   rpt_band_color( name, &b->colorR, &b->colorG, &b->colorB );
   s_rptBandCount++;

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );
}

static void on_rpt_add_band_clicked( GtkButton * btn, gpointer data )
{
   (void)data;
   GtkWidget * menu = gtk_menu_new();
   static const char * types[] = {
      "Header", "Detail", "Footer",
      "GroupHeader", "GroupFooter",
      "PageHeader", "PageFooter", NULL
   };
   int i;
   for( i = 0; types[i]; i++ )
   {
      GtkWidget * mi = gtk_menu_item_new_with_label( types[i] );
      g_signal_connect( mi, "activate", G_CALLBACK(on_rpt_add_band_type), (gpointer)types[i] );
      gtk_menu_shell_append( GTK_MENU_SHELL(menu), mi );
   }
   gtk_widget_show_all( menu );
   gtk_menu_popup_at_widget( GTK_MENU(menu), GTK_WIDGET(btn),
      GDK_GRAVITY_SOUTH_WEST, GDK_GRAVITY_NORTH_WEST, NULL );
}

static void on_rpt_add_field( GtkButton * btn, gpointer data )
{
   (void)btn; (void)data;
   int bi = s_rptSelBand;
   if( bi < 0 )
   {
      /* Default to first band if none selected */
      if( s_rptBandCount > 0 ) bi = 0; else return;
   }
   RptBand * b = &s_rptBands[bi];
   if( b->nFieldCount >= RPT_MAX_FIELDS ) return;

   RptField * f = &b->fields[b->nFieldCount];
   memset( f, 0, sizeof(RptField) );
   snprintf( f->cName, sizeof(f->cName), "Field%d", b->nFieldCount + 1 );
   snprintf( f->cText, sizeof(f->cText), "Field%d", b->nFieldCount + 1 );
   f->nLeft   = 10 + (b->nFieldCount % 4) * 80;
   f->nTop    = 10;
   f->nWidth  = 70;
   f->nHeight = 20;

   s_rptSelBand  = bi;
   s_rptSelField = b->nFieldCount;
   b->nFieldCount++;

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );
}

static void on_rpt_delete( GtkButton * btn, gpointer data )
{
   (void)btn; (void)data;
   if( s_rptSelBand < 0 ) return;

   if( s_rptSelField >= 0 )
   {
      /* Delete selected field */
      RptBand * b = &s_rptBands[s_rptSelBand];
      int f = s_rptSelField;
      if( f < b->nFieldCount - 1 )
         memmove( &b->fields[f], &b->fields[f + 1],
                  sizeof(RptField) * (b->nFieldCount - f - 1) );
      b->nFieldCount--;
      s_rptSelField = -1;
   }
   else
   {
      /* Delete selected band */
      int i = s_rptSelBand;
      if( i < s_rptBandCount - 1 )
         memmove( &s_rptBands[i], &s_rptBands[i + 1],
                  sizeof(RptBand) * (s_rptBandCount - i - 1) );
      s_rptBandCount--;
      s_rptSelBand = -1;
   }

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );
}

static void on_rpt_preview( GtkButton * btn, gpointer data );  /* forward decl */

/* RPT_DESIGNEROPEN() - Create/show the report designer window */
HB_FUNC( RPT_DESIGNEROPEN )
{
   EnsureGTK();

   if( s_rptDesigner )
   {
      gtk_window_present( GTK_WINDOW(s_rptDesigner) );
      return;
   }

   s_rptDesigner = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(s_rptDesigner), "Report Designer" );
   gtk_window_set_default_size( GTK_WINDOW(s_rptDesigner), 800, 600 );
   g_signal_connect( s_rptDesigner, "delete-event",
      G_CALLBACK(gtk_widget_hide_on_delete), NULL );

   /* Dark theme CSS */
   { GtkCssProvider * p = gtk_css_provider_new();
     gtk_css_provider_load_from_data( p,
        "window { background-color: #252526; }"
        "button { background-color: #3C3C3C; color: #D4D4D4; border-color: #555;"
        "  padding: 3px 8px; }"
        "button:hover { background-color: #4C4C4C; }"
        "label { color: #D4D4D4; }"
        "toolbar { background-color: #2D2D2D; border-bottom: 1px solid #3E3E3E; }", -1, NULL );
     gtk_style_context_add_provider( gtk_widget_get_style_context(s_rptDesigner),
        GTK_STYLE_PROVIDER(p), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
     g_object_unref( p );
   }

   /* Main layout: vbox with toolbar + scrolled drawing area */
   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(s_rptDesigner), vbox );

   /* Toolbar */
   { GtkWidget * toolbar = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
     gtk_widget_set_margin_start( toolbar, 4 );
     gtk_widget_set_margin_end( toolbar, 4 );
     gtk_widget_set_margin_top( toolbar, 4 );
     gtk_widget_set_margin_bottom( toolbar, 4 );

     GtkWidget * btnAddBand = gtk_button_new_with_label( "Add Band" );
     g_signal_connect( btnAddBand, "clicked", G_CALLBACK(on_rpt_add_band_clicked), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), btnAddBand, FALSE, FALSE, 0 );

     GtkWidget * btnAddField = gtk_button_new_with_label( "Add Field" );
     g_signal_connect( btnAddField, "clicked", G_CALLBACK(on_rpt_add_field), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), btnAddField, FALSE, FALSE, 0 );

     GtkWidget * btnDelete = gtk_button_new_with_label( "Delete" );
     g_signal_connect( btnDelete, "clicked", G_CALLBACK(on_rpt_delete), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), btnDelete, FALSE, FALSE, 0 );

     GtkWidget * btnPreview = gtk_button_new_with_label( "Preview" );
     g_signal_connect( btnPreview, "clicked", G_CALLBACK(on_rpt_preview), NULL );
     gtk_box_pack_start( GTK_BOX(toolbar), btnPreview, FALSE, FALSE, 0 );

     gtk_box_pack_start( GTK_BOX(vbox), toolbar, FALSE, FALSE, 0 );
   }

   /* Scrolled window with drawing area */
   { GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
     gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
     gtk_box_pack_start( GTK_BOX(vbox), sw, TRUE, TRUE, 0 );

     s_rptDrawArea = gtk_drawing_area_new();
     gtk_widget_set_size_request( s_rptDrawArea, 700, 400 );
     gtk_widget_add_events( s_rptDrawArea,
        GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK |
        GDK_POINTER_MOTION_MASK );

     g_signal_connect( s_rptDrawArea, "draw", G_CALLBACK(on_report_draw), NULL );
     g_signal_connect( s_rptDrawArea, "button-press-event", G_CALLBACK(on_report_click), NULL );
     g_signal_connect( s_rptDrawArea, "motion-notify-event", G_CALLBACK(on_report_motion), NULL );
     g_signal_connect( s_rptDrawArea, "button-release-event", G_CALLBACK(on_report_release), NULL );

     gtk_container_add( GTK_CONTAINER(sw), s_rptDrawArea );
   }

   gtk_widget_show_all( s_rptDesigner );
}

/* RPT_DESIGNERCLOSE() - Hide the report designer window */
HB_FUNC( RPT_DESIGNERCLOSE )
{
   if( s_rptDesigner )
      gtk_widget_hide( s_rptDesigner );
}

/* RPT_SETREPORT( pReportHandle ) - Store reference to TReport object */
HB_FUNC( RPT_SETREPORT )
{
   /* Reserved for future integration with TReport Harbour object.
    * Currently the designer uses its own internal C data structures.
    * When integration is complete, this will sync band/field data
    * between the Harbour TReport object and the C arrays. */
   (void)hb_parni(1);
}

/* RPT_ADDBAND( cBandName, nHeight ) - Add a band to the designer */
HB_FUNC( RPT_ADDBAND )
{
   if( s_rptBandCount >= RPT_MAX_BANDS ) { hb_retni( -1 ); return; }

   const char * cName = hb_parc(1);
   int nHeight = HB_ISNUM(2) ? hb_parni(2) : 80;

   if( !cName || !cName[0] ) { hb_retni( -1 ); return; }

   RptBand * b = &s_rptBands[s_rptBandCount];
   memset( b, 0, sizeof(RptBand) );
   strncpy( b->cName, cName, sizeof(b->cName) - 1 );
   b->nHeight = nHeight;
   b->lVisible = 1;
   rpt_band_color( cName, &b->colorR, &b->colorG, &b->colorB );

   int idx = s_rptBandCount;
   s_rptBandCount++;

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );

   hb_retni( idx );
}

/* RPT_ADDFIELD( nBandIndex, cName, cText, nLeft, nTop, nWidth, nHeight ) - Add a field */
HB_FUNC( RPT_ADDFIELD )
{
   int bi = hb_parni(1);
   if( bi < 0 || bi >= s_rptBandCount ) { hb_retni( -1 ); return; }

   RptBand * b = &s_rptBands[bi];
   if( b->nFieldCount >= RPT_MAX_FIELDS ) { hb_retni( -1 ); return; }

   RptField * f = &b->fields[b->nFieldCount];
   memset( f, 0, sizeof(RptField) );

   if( HB_ISCHAR(2) ) strncpy( f->cName, hb_parc(2), sizeof(f->cName) - 1 );
   if( HB_ISCHAR(3) ) strncpy( f->cText, hb_parc(3), sizeof(f->cText) - 1 );
   f->nLeft   = HB_ISNUM(4) ? hb_parni(4) : 10;
   f->nTop    = HB_ISNUM(5) ? hb_parni(5) : 10;
   f->nWidth  = HB_ISNUM(6) ? hb_parni(6) : 70;
   f->nHeight = HB_ISNUM(7) ? hb_parni(7) : 20;

   int idx = b->nFieldCount;
   b->nFieldCount++;

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );

   hb_retni( idx );
}

/* RPT_GETSELECTED() -> { nBandIndex, nFieldIndex, cBandName, cFieldName }
 * Returns info about currently selected band/field for the inspector */
HB_FUNC( RPT_GETSELECTED )
{
   PHB_ITEM pArray = hb_itemArrayNew( 4 );

   hb_arraySetNI( pArray, 1, s_rptSelBand );
   hb_arraySetNI( pArray, 2, s_rptSelField );

   if( s_rptSelBand >= 0 && s_rptSelBand < s_rptBandCount )
   {
      hb_arraySetC( pArray, 3, s_rptBands[s_rptSelBand].cName );
      if( s_rptSelField >= 0 && s_rptSelField < s_rptBands[s_rptSelBand].nFieldCount )
         hb_arraySetC( pArray, 4, s_rptBands[s_rptSelBand].fields[s_rptSelField].cName );
      else
         hb_arraySetC( pArray, 4, "" );
   }
   else
   {
      hb_arraySetC( pArray, 3, "" );
      hb_arraySetC( pArray, 4, "" );
   }

   hb_itemReturnRelease( pArray );
}

/* RPT_GETBANDPROPS( nBandIndex ) -> { {cPropName, xValue, cCategory, cType}, ... }
 * Returns property array for a band, compatible with the inspector format.
 * Types: "S"=String, "N"=Numeric, "L"=Logical */
HB_FUNC( RPT_GETBANDPROPS )
{
   int bi = hb_parni(1);
   if( bi < 0 || bi >= s_rptBandCount )
   {
      hb_reta(0);
      return;
   }

   RptBand * b = &s_rptBands[bi];
   PHB_ITEM pArray = hb_itemArrayNew( 5 );
   PHB_ITEM pRow;

   /* 1: cName */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "cName" );
   hb_arraySetC( pRow, 2, b->cName );
   hb_arraySetC( pRow, 3, "Info" );
   hb_arraySetC( pRow, 4, "S" );
   hb_arraySet( pArray, 1, pRow );
   hb_itemRelease( pRow );

   /* 2: nHeight */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "nHeight" );
   hb_arraySetNI( pRow, 2, b->nHeight );
   hb_arraySetC( pRow, 3, "Position" );
   hb_arraySetC( pRow, 4, "N" );
   hb_arraySet( pArray, 2, pRow );
   hb_itemRelease( pRow );

   /* 3: lPrintOnEveryPage */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "lPrintOnEveryPage" );
   hb_arraySetL( pRow, 2, b->lPrintOnEveryPage ? HB_TRUE : HB_FALSE );
   hb_arraySetC( pRow, 3, "Behavior" );
   hb_arraySetC( pRow, 4, "L" );
   hb_arraySet( pArray, 3, pRow );
   hb_itemRelease( pRow );

   /* 4: lKeepTogether */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "lKeepTogether" );
   hb_arraySetL( pRow, 2, b->lKeepTogether ? HB_TRUE : HB_FALSE );
   hb_arraySetC( pRow, 3, "Behavior" );
   hb_arraySetC( pRow, 4, "L" );
   hb_arraySet( pArray, 4, pRow );
   hb_itemRelease( pRow );

   /* 5: lVisible */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "lVisible" );
   hb_arraySetL( pRow, 2, b->lVisible ? HB_TRUE : HB_FALSE );
   hb_arraySetC( pRow, 3, "Behavior" );
   hb_arraySetC( pRow, 4, "L" );
   hb_arraySet( pArray, 5, pRow );
   hb_itemRelease( pRow );

   hb_itemReturnRelease( pArray );
}

/* RPT_GETFIELDPROPS( nBandIndex, nFieldIndex ) -> { {cPropName, xValue, cCategory, cType}, ... }
 * Returns property array for a field, compatible with the inspector format. */
HB_FUNC( RPT_GETFIELDPROPS )
{
   int bi = hb_parni(1);
   int fi = hb_parni(2);

   if( bi < 0 || bi >= s_rptBandCount ||
       fi < 0 || fi >= s_rptBands[bi].nFieldCount )
   {
      hb_reta(0);
      return;
   }

   RptField * f = &s_rptBands[bi].fields[fi];
   PHB_ITEM pArray = hb_itemArrayNew( 8 );
   PHB_ITEM pRow;

   /* 1: cName */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "cName" );
   hb_arraySetC( pRow, 2, f->cName );
   hb_arraySetC( pRow, 3, "Info" );
   hb_arraySetC( pRow, 4, "S" );
   hb_arraySet( pArray, 1, pRow );
   hb_itemRelease( pRow );

   /* 2: cText */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "cText" );
   hb_arraySetC( pRow, 2, f->cText );
   hb_arraySetC( pRow, 3, "Appearance" );
   hb_arraySetC( pRow, 4, "S" );
   hb_arraySet( pArray, 2, pRow );
   hb_itemRelease( pRow );

   /* 3: cFieldName */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "cFieldName" );
   hb_arraySetC( pRow, 2, f->cFieldName );
   hb_arraySetC( pRow, 3, "Data" );
   hb_arraySetC( pRow, 4, "S" );
   hb_arraySet( pArray, 3, pRow );
   hb_itemRelease( pRow );

   /* 4: nLeft */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "nLeft" );
   hb_arraySetNI( pRow, 2, f->nLeft );
   hb_arraySetC( pRow, 3, "Position" );
   hb_arraySetC( pRow, 4, "N" );
   hb_arraySet( pArray, 4, pRow );
   hb_itemRelease( pRow );

   /* 5: nTop */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "nTop" );
   hb_arraySetNI( pRow, 2, f->nTop );
   hb_arraySetC( pRow, 3, "Position" );
   hb_arraySetC( pRow, 4, "N" );
   hb_arraySet( pArray, 5, pRow );
   hb_itemRelease( pRow );

   /* 6: nWidth */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "nWidth" );
   hb_arraySetNI( pRow, 2, f->nWidth );
   hb_arraySetC( pRow, 3, "Position" );
   hb_arraySetC( pRow, 4, "N" );
   hb_arraySet( pArray, 6, pRow );
   hb_itemRelease( pRow );

   /* 7: nHeight */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "nHeight" );
   hb_arraySetNI( pRow, 2, f->nHeight );
   hb_arraySetC( pRow, 3, "Position" );
   hb_arraySetC( pRow, 4, "N" );
   hb_arraySet( pArray, 7, pRow );
   hb_itemRelease( pRow );

   /* 8: nAlignment */
   pRow = hb_itemArrayNew( 4 );
   hb_arraySetC( pRow, 1, "nAlignment" );
   hb_arraySetNI( pRow, 2, f->nAlignment );
   hb_arraySetC( pRow, 3, "Appearance" );
   hb_arraySetC( pRow, 4, "N" );
   hb_arraySet( pArray, 8, pRow );
   hb_itemRelease( pRow );

   hb_itemReturnRelease( pArray );
}

/* RPT_SETBANDPROP( nBandIndex, cPropName, xValue ) - Update a band property and redraw */
HB_FUNC( RPT_SETBANDPROP )
{
   int bi = hb_parni(1);
   const char * cProp = hb_parc(2);

   if( bi < 0 || bi >= s_rptBandCount || !cProp )
   {
      hb_retl( HB_FALSE );
      return;
   }

   RptBand * b = &s_rptBands[bi];

   if( strcmp( cProp, "cName" ) == 0 && HB_ISCHAR(3) )
      strncpy( b->cName, hb_parc(3), sizeof(b->cName) - 1 );
   else if( strcmp( cProp, "nHeight" ) == 0 && HB_ISNUM(3) )
      b->nHeight = hb_parni(3);
   else if( strcmp( cProp, "lPrintOnEveryPage" ) == 0 && HB_ISLOG(3) )
      b->lPrintOnEveryPage = hb_parl(3) ? 1 : 0;
   else if( strcmp( cProp, "lKeepTogether" ) == 0 && HB_ISLOG(3) )
      b->lKeepTogether = hb_parl(3) ? 1 : 0;
   else if( strcmp( cProp, "lVisible" ) == 0 && HB_ISLOG(3) )
      b->lVisible = hb_parl(3) ? 1 : 0;
   else
   {
      hb_retl( HB_FALSE );
      return;
   }

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );

   hb_retl( HB_TRUE );
}

/* RPT_SETFIELDPROP( nBandIndex, nFieldIndex, cPropName, xValue ) - Update a field property and redraw */
HB_FUNC( RPT_SETFIELDPROP )
{
   int bi = hb_parni(1);
   int fi = hb_parni(2);
   const char * cProp = hb_parc(3);

   if( bi < 0 || bi >= s_rptBandCount ||
       fi < 0 || fi >= s_rptBands[bi].nFieldCount || !cProp )
   {
      hb_retl( HB_FALSE );
      return;
   }

   RptField * f = &s_rptBands[bi].fields[fi];

   if( strcmp( cProp, "cName" ) == 0 && HB_ISCHAR(4) )
      strncpy( f->cName, hb_parc(4), sizeof(f->cName) - 1 );
   else if( strcmp( cProp, "cText" ) == 0 && HB_ISCHAR(4) )
      strncpy( f->cText, hb_parc(4), sizeof(f->cText) - 1 );
   else if( strcmp( cProp, "cFieldName" ) == 0 && HB_ISCHAR(4) )
      strncpy( f->cFieldName, hb_parc(4), sizeof(f->cFieldName) - 1 );
   else if( strcmp( cProp, "nLeft" ) == 0 && HB_ISNUM(4) )
      f->nLeft = hb_parni(4);
   else if( strcmp( cProp, "nTop" ) == 0 && HB_ISNUM(4) )
      f->nTop = hb_parni(4);
   else if( strcmp( cProp, "nWidth" ) == 0 && HB_ISNUM(4) )
      f->nWidth = hb_parni(4);
   else if( strcmp( cProp, "nHeight" ) == 0 && HB_ISNUM(4) )
      f->nHeight = hb_parni(4);
   else if( strcmp( cProp, "nAlignment" ) == 0 && HB_ISNUM(4) )
      f->nAlignment = hb_parni(4);
   else
   {
      hb_retl( HB_FALSE );
      return;
   }

   if( s_rptDrawArea )
      gtk_widget_queue_draw( s_rptDrawArea );

   hb_retl( HB_TRUE );
}

/* ===================================================================
 * Report Preview Window - Cairo page rendering with zoom/pagination
 * =================================================================== */

#define RPT_PRV_MAX_PAGES   100
#define RPT_PRV_MAX_CMDS    500

typedef struct {
   int  type;         /* 1=text, 2=rect, 3=line */
   int  x, y, w, h;
   int  x2, y2;       /* for lines */
   char text[256];
   char fontName[64];
   int  fontSize;
   int  bold, italic;
   int  color;
   int  filled;
   int  lineWidth;
} RptDrawCmd;

typedef struct {
   RptDrawCmd cmds[RPT_PRV_MAX_CMDS];
   int nCmds;
} RptPrvPage;

static GtkWidget * s_rptPreview     = NULL;
static GtkWidget * s_rptPreviewDraw = NULL;
static GtkWidget * s_rptPageLabel   = NULL;
static RptPrvPage  s_rptPrvPages[RPT_PRV_MAX_PAGES];
static int         s_rptPrvPageCount = 0;
static int         s_rptPrvCurPage   = 0;   /* 0-based */
static int         s_rptPreviewZoom  = 100;  /* percentage */
static int         s_rptPrvPgW = 210, s_rptPrvPgH = 297;  /* mm */
static int         s_rptPrvMgL = 15, s_rptPrvMgR = 15;
static int         s_rptPrvMgT = 15, s_rptPrvMgB = 15;

static void rpt_prv_update_label( void )
{
   if( !s_rptPageLabel ) return;
   char buf[64];
   snprintf( buf, sizeof(buf), "Page %d of %d",
             s_rptPrvCurPage + 1,
             s_rptPrvPageCount > 0 ? s_rptPrvPageCount : 1 );
   gtk_label_set_text( GTK_LABEL(s_rptPageLabel), buf );
}

static void rpt_prv_redraw( void )
{
   if( s_rptPreviewDraw )
      gtk_widget_queue_draw( s_rptPreviewDraw );
   rpt_prv_update_label();
}

/* Navigation callbacks */
static void on_prev_first( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   s_rptPrvCurPage = 0;
   rpt_prv_redraw();
}

static void on_prev_prev( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   if( s_rptPrvCurPage > 0 ) s_rptPrvCurPage--;
   rpt_prv_redraw();
}

static void on_prev_next( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   if( s_rptPrvCurPage < s_rptPrvPageCount - 1 ) s_rptPrvCurPage++;
   rpt_prv_redraw();
}

static void on_prev_last( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   if( s_rptPrvPageCount > 0 )
      s_rptPrvCurPage = s_rptPrvPageCount - 1;
   rpt_prv_redraw();
}

static void on_prev_zoom_in( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   if( s_rptPreviewZoom < 400 ) s_rptPreviewZoom += 25;
   rpt_prv_redraw();
}

static void on_prev_zoom_out( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   if( s_rptPreviewZoom > 25 ) s_rptPreviewZoom -= 25;
   rpt_prv_redraw();
}

static void on_prev_close( GtkButton * btn, gpointer d )
{
   (void)btn; (void)d;
   if( s_rptPreview ) gtk_widget_hide( s_rptPreview );
}

/* Cairo draw callback for preview */
static gboolean on_preview_draw( GtkWidget * widget, cairo_t * cr, gpointer data )
{
   (void)data;
   GtkAllocation alloc;
   gtk_widget_get_allocation( widget, &alloc );

   double ppm = 3.0 * s_rptPreviewZoom / 100.0;  /* pixels per mm */
   int pageW = (int)( s_rptPrvPgW * ppm );
   int pageH = (int)( s_rptPrvPgH * ppm );
   int pad = 30;
   int shadowOff = 4;

   /* Request size for scrolled window */
   gtk_widget_set_size_request( widget, pageW + pad * 2, pageH + pad * 2 );

   /* Dark background */
   cairo_set_source_rgb( cr, 0.118, 0.118, 0.118 );  /* #1E1E1E */
   cairo_rectangle( cr, 0, 0, alloc.width, alloc.height );
   cairo_fill( cr );

   /* Center page horizontally */
   int pageX = ( alloc.width - pageW ) / 2;
   if( pageX < pad ) pageX = pad;
   int pageY = pad;

   /* Drop shadow */
   cairo_set_source_rgba( cr, 0, 0, 0, 0.5 );
   cairo_rectangle( cr, pageX + shadowOff, pageY + shadowOff, pageW, pageH );
   cairo_fill( cr );

   /* White page */
   cairo_set_source_rgb( cr, 1, 1, 1 );
   cairo_rectangle( cr, pageX, pageY, pageW, pageH );
   cairo_fill( cr );

   /* Page border */
   cairo_set_source_rgb( cr, 0.6, 0.6, 0.6 );
   cairo_set_line_width( cr, 1 );
   cairo_rectangle( cr, pageX + 0.5, pageY + 0.5, pageW, pageH );
   cairo_stroke( cr );

   /* Margin lines - dashed light gray */
   {
      double dashes[] = { 4.0, 4.0 };
      cairo_set_dash( cr, dashes, 2, 0 );
      cairo_set_source_rgb( cr, 0.8, 0.8, 0.8 );
      cairo_set_line_width( cr, 0.5 );

      double mL = pageX + s_rptPrvMgL * ppm;
      double mR = pageX + pageW - s_rptPrvMgR * ppm;
      double mT = pageY + s_rptPrvMgT * ppm;
      double mB = pageY + pageH - s_rptPrvMgB * ppm;

      /* Left margin */
      cairo_move_to( cr, mL, pageY );
      cairo_line_to( cr, mL, pageY + pageH );
      cairo_stroke( cr );
      /* Right margin */
      cairo_move_to( cr, mR, pageY );
      cairo_line_to( cr, mR, pageY + pageH );
      cairo_stroke( cr );
      /* Top margin */
      cairo_move_to( cr, pageX, mT );
      cairo_line_to( cr, pageX + pageW, mT );
      cairo_stroke( cr );
      /* Bottom margin */
      cairo_move_to( cr, pageX, mB );
      cairo_line_to( cr, pageX + pageW, mB );
      cairo_stroke( cr );

      cairo_set_dash( cr, NULL, 0, 0 );
   }

   /* Draw commands for current page */
   if( s_rptPrvCurPage >= 0 && s_rptPrvCurPage < s_rptPrvPageCount )
   {
      RptPrvPage * pg = &s_rptPrvPages[s_rptPrvCurPage];
      int i;
      for( i = 0; i < pg->nCmds; i++ )
      {
         RptDrawCmd * cmd = &pg->cmds[i];
         double r = ((cmd->color >> 16) & 0xFF) / 255.0;
         double g = ((cmd->color >> 8 ) & 0xFF) / 255.0;
         double b = ((cmd->color      ) & 0xFF) / 255.0;

         switch( cmd->type )
         {
            case 1:  /* Text */
            {
               cairo_set_source_rgb( cr, r, g, b );
               cairo_select_font_face( cr,
                  cmd->fontName[0] ? cmd->fontName : "Sans",
                  cmd->italic ? CAIRO_FONT_SLANT_ITALIC : CAIRO_FONT_SLANT_NORMAL,
                  cmd->bold   ? CAIRO_FONT_WEIGHT_BOLD  : CAIRO_FONT_WEIGHT_NORMAL );
               double fs = cmd->fontSize * ppm / 3.0;
               if( fs < 6 ) fs = 6;
               cairo_set_font_size( cr, fs );
               cairo_move_to( cr, pageX + cmd->x * ppm, pageY + cmd->y * ppm + fs );
               cairo_show_text( cr, cmd->text );
               break;
            }
            case 2:  /* Rect */
            {
               cairo_set_source_rgb( cr, r, g, b );
               cairo_rectangle( cr,
                  pageX + cmd->x * ppm, pageY + cmd->y * ppm,
                  cmd->w * ppm, cmd->h * ppm );
               if( cmd->filled )
                  cairo_fill( cr );
               else
               {
                  cairo_set_line_width( cr, 1 );
                  cairo_stroke( cr );
               }
               break;
            }
            case 3:  /* Line */
            {
               cairo_set_source_rgb( cr, r, g, b );
               cairo_set_line_width( cr, cmd->lineWidth > 0 ? cmd->lineWidth : 1 );
               cairo_move_to( cr, pageX + cmd->x  * ppm, pageY + cmd->y  * ppm );
               cairo_line_to( cr, pageX + cmd->x2 * ppm, pageY + cmd->y2 * ppm );
               cairo_stroke( cr );
               break;
            }
         }
      }
   }

   return FALSE;
}

/* Helper: create the preview window UI */
static void rpt_prv_create_window( void )
{
   s_rptPreview = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(s_rptPreview), "Report Preview" );
   gtk_window_set_default_size( GTK_WINDOW(s_rptPreview), 700, 850 );
   g_signal_connect( s_rptPreview, "delete-event",
      G_CALLBACK(gtk_widget_hide_on_delete), NULL );

   /* Dark theme CSS */
   { GtkCssProvider * p = gtk_css_provider_new();
     gtk_css_provider_load_from_data( p,
        "window { background-color: #1E1E1E; }"
        "button { background-color: #3C3C3C; color: #D4D4D4; border-color: #555;"
        "  padding: 3px 8px; }"
        "button:hover { background-color: #4C4C4C; }"
        "label { color: #D4D4D4; }", -1, NULL );
     gtk_style_context_add_provider( gtk_widget_get_style_context(s_rptPreview),
        GTK_STYLE_PROVIDER(p), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
     g_object_unref( p );
   }

   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(s_rptPreview), vbox );

   /* Toolbar */
   { GtkWidget * tb = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
     gtk_widget_set_margin_start( tb, 4 );
     gtk_widget_set_margin_end( tb, 4 );
     gtk_widget_set_margin_top( tb, 4 );
     gtk_widget_set_margin_bottom( tb, 4 );

     GtkWidget * b;

     b = gtk_button_new_with_label( "|<" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_first), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     b = gtk_button_new_with_label( "<" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_prev), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     s_rptPageLabel = gtk_label_new( "Page 1 of 1" );
     gtk_box_pack_start( GTK_BOX(tb), s_rptPageLabel, FALSE, FALSE, 8 );

     b = gtk_button_new_with_label( ">" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_next), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     b = gtk_button_new_with_label( ">|" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_last), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     /* Separator */
     GtkWidget * sep = gtk_separator_new( GTK_ORIENTATION_VERTICAL );
     gtk_box_pack_start( GTK_BOX(tb), sep, FALSE, FALSE, 8 );

     b = gtk_button_new_with_label( "Zoom +" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_zoom_in), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     b = gtk_button_new_with_label( "Zoom -" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_zoom_out), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     /* Separator */
     sep = gtk_separator_new( GTK_ORIENTATION_VERTICAL );
     gtk_box_pack_start( GTK_BOX(tb), sep, FALSE, FALSE, 8 );

     b = gtk_button_new_with_label( "Close" );
     g_signal_connect( b, "clicked", G_CALLBACK(on_prev_close), NULL );
     gtk_box_pack_start( GTK_BOX(tb), b, FALSE, FALSE, 0 );

     gtk_box_pack_start( GTK_BOX(vbox), tb, FALSE, FALSE, 0 );
   }

   /* Scrolled window with drawing area */
   { GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
     gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
        GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
     gtk_box_pack_start( GTK_BOX(vbox), sw, TRUE, TRUE, 0 );

     s_rptPreviewDraw = gtk_drawing_area_new();
     gtk_widget_set_size_request( s_rptPreviewDraw, 700, 800 );
     g_signal_connect( s_rptPreviewDraw, "draw", G_CALLBACK(on_preview_draw), NULL );
     gtk_container_add( GTK_CONTAINER(sw), s_rptPreviewDraw );
   }

   gtk_widget_show_all( s_rptPreview );
}

/* Preview button handler from designer toolbar */
static void on_rpt_preview( GtkButton * btn, gpointer data )
{
   (void)btn; (void)data;

   /* Reset preview pages */
   s_rptPrvPageCount = 0;
   s_rptPrvCurPage = 0;
   memset( s_rptPrvPages, 0, sizeof(s_rptPrvPages) );

   /* Build a simple preview from designer band/field data */
   s_rptPrvPgW = s_rptPageWidth;
   s_rptPrvPgH = s_rptPageHeight;

   /* Add one page with fields from current bands */
   if( s_rptPrvPageCount < RPT_PRV_MAX_PAGES )
   {
      RptPrvPage * pg = &s_rptPrvPages[0];
      pg->nCmds = 0;
      s_rptPrvPageCount = 1;

      int nY = s_rptPrvMgT;
      int bi, fi;
      for( bi = 0; bi < s_rptBandCount; bi++ )
      {
         RptBand * band = &s_rptBands[bi];
         if( !band->lVisible ) continue;

         for( fi = 0; fi < band->nFieldCount; fi++ )
         {
            if( pg->nCmds >= RPT_PRV_MAX_CMDS ) break;
            RptField * fld = &band->fields[fi];
            RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
            memset( cmd, 0, sizeof(RptDrawCmd) );
            cmd->type = 1;  /* text */
            cmd->x = s_rptPrvMgL + fld->nLeft;
            cmd->y = nY + fld->nTop;
            if( fld->cText[0] )
               strncpy( cmd->text, fld->cText, sizeof(cmd->text) - 1 );
            else
               snprintf( cmd->text, sizeof(cmd->text), "[%s]", fld->cFieldName );
            strncpy( cmd->fontName, "Sans", sizeof(cmd->fontName) - 1 );
            cmd->fontSize = 10;
            cmd->color = 0x000000;
            pg->nCmds++;
         }
         nY += band->nHeight;
      }
   }

   /* Open preview window */
   if( !s_rptPreview )
      rpt_prv_create_window();
   else
   {
      gtk_widget_show_all( s_rptPreview );
      gtk_window_present( GTK_WINDOW(s_rptPreview) );
   }

   rpt_prv_update_label();
   rpt_prv_redraw();
}

/* RPT_PREVIEWOPEN( nPageWidth, nPageHeight, nMarginL, nMarginR, nMarginT, nMarginB ) */
HB_FUNC( RPT_PREVIEWOPEN )
{
   EnsureGTK();

   s_rptPrvPgW = HB_ISNUM(1) ? hb_parni(1) : 210;
   s_rptPrvPgH = HB_ISNUM(2) ? hb_parni(2) : 297;
   s_rptPrvMgL = HB_ISNUM(3) ? hb_parni(3) : 15;
   s_rptPrvMgR = HB_ISNUM(4) ? hb_parni(4) : 15;
   s_rptPrvMgT = HB_ISNUM(5) ? hb_parni(5) : 15;
   s_rptPrvMgB = HB_ISNUM(6) ? hb_parni(6) : 15;

   /* Reset pages */
   s_rptPrvPageCount = 0;
   s_rptPrvCurPage = 0;
   memset( s_rptPrvPages, 0, sizeof(s_rptPrvPages) );
   s_rptPreviewZoom = 100;

   if( s_rptPreview )
   {
      gtk_widget_show_all( s_rptPreview );
      gtk_window_present( GTK_WINDOW(s_rptPreview) );
      rpt_prv_update_label();
      return;
   }

   rpt_prv_create_window();
   rpt_prv_update_label();
}

/* RPT_PREVIEWCLOSE() */
HB_FUNC( RPT_PREVIEWCLOSE )
{
   if( s_rptPreview )
      gtk_widget_hide( s_rptPreview );
}

/* RPT_PREVIEWADDPAGE() - Start a new page */
HB_FUNC( RPT_PREVIEWADDPAGE )
{
   if( s_rptPrvPageCount >= RPT_PRV_MAX_PAGES )
   {
      hb_retl( HB_FALSE );
      return;
   }
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount];
   memset( pg, 0, sizeof(RptPrvPage) );
   pg->nCmds = 0;
   s_rptPrvPageCount++;
   s_rptPrvCurPage = s_rptPrvPageCount - 1;
   hb_retl( HB_TRUE );
}

/* RPT_PREVIEWDRAWTEXT( nX, nY, cText, cFontName, nFontSize, lBold, lItalic, nColor ) */
HB_FUNC( RPT_PREVIEWDRAWTEXT )
{
   if( s_rptPrvPageCount <= 0 ) return;
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount - 1];
   if( pg->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
   memset( cmd, 0, sizeof(RptDrawCmd) );
   cmd->type = 1;
   cmd->x = hb_parni(1);
   cmd->y = hb_parni(2);
   if( HB_ISCHAR(3) )
      strncpy( cmd->text, hb_parc(3), sizeof(cmd->text) - 1 );
   if( HB_ISCHAR(4) )
      strncpy( cmd->fontName, hb_parc(4), sizeof(cmd->fontName) - 1 );
   cmd->fontSize = HB_ISNUM(5) ? hb_parni(5) : 10;
   cmd->bold     = HB_ISLOG(6) ? ( hb_parl(6) ? 1 : 0 ) : 0;
   cmd->italic   = HB_ISLOG(7) ? ( hb_parl(7) ? 1 : 0 ) : 0;
   cmd->color    = HB_ISNUM(8) ? hb_parni(8) : 0;
   pg->nCmds++;
}

/* RPT_PREVIEWDRAWRECT( nX, nY, nW, nH, nColor, lFilled ) */
HB_FUNC( RPT_PREVIEWDRAWRECT )
{
   if( s_rptPrvPageCount <= 0 ) return;
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount - 1];
   if( pg->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
   memset( cmd, 0, sizeof(RptDrawCmd) );
   cmd->type   = 2;
   cmd->x      = hb_parni(1);
   cmd->y      = hb_parni(2);
   cmd->w      = hb_parni(3);
   cmd->h      = hb_parni(4);
   cmd->color  = HB_ISNUM(5) ? hb_parni(5) : 0;
   cmd->filled = HB_ISLOG(6) ? ( hb_parl(6) ? 1 : 0 ) : 0;
   pg->nCmds++;
}

/* RPT_PREVIEWDRAWLINE( nX1, nY1, nX2, nY2, nColor, nWidth ) */
HB_FUNC( RPT_PREVIEWDRAWLINE )
{
   if( s_rptPrvPageCount <= 0 ) return;
   RptPrvPage * pg = &s_rptPrvPages[s_rptPrvPageCount - 1];
   if( pg->nCmds >= RPT_PRV_MAX_CMDS ) return;

   RptDrawCmd * cmd = &pg->cmds[pg->nCmds];
   memset( cmd, 0, sizeof(RptDrawCmd) );
   cmd->type      = 3;
   cmd->x         = hb_parni(1);
   cmd->y         = hb_parni(2);
   cmd->x2        = hb_parni(3);
   cmd->y2        = hb_parni(4);
   cmd->color     = HB_ISNUM(5) ? hb_parni(5) : 0;
   cmd->lineWidth = HB_ISNUM(6) ? hb_parni(6) : 1;
   pg->nCmds++;
}

/* RPT_PREVIEWRENDER() - Trigger Cairo rendering of all stored draw commands */
HB_FUNC( RPT_PREVIEWRENDER )
{
   if( s_rptPrvPageCount > 0 )
      s_rptPrvCurPage = 0;  /* Show first page */
   rpt_prv_redraw();
}

/* ======================================================================
 * Undo/Redo stack for form designer
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
   snap->nCount = pForm->base.FChildCount;
   for( int i = 0; i < pForm->base.FChildCount && i < UNDO_MAX_CTRLS; i++ )
   {
      HBControl * c = pForm->base.FChildren[i];
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
   int n = snap->nCount < pForm->base.FChildCount ? snap->nCount : pForm->base.FChildCount;
   for( int i = 0; i < n; i++ )
   {
      HBControl * c = pForm->base.FChildren[i];
      c->FLeft   = snap->ctrls[i].nLeft;
      c->FTop    = snap->ctrls[i].nTop;
      c->FWidth  = snap->ctrls[i].nWidth;
      c->FHeight = snap->ctrls[i].nHeight;
      /* Update the GTK widget position/size */
      if( c->FWidget && pForm->FFixed )
      {
         gtk_fixed_move( GTK_FIXED(pForm->FFixed), c->FWidget, c->FLeft, c->FTop );
         gtk_widget_set_size_request( c->FWidget, c->FWidth, c->FHeight );
      }
   }
   /* Redraw selection handles */
   if( pForm->FOverlay )
      gtk_widget_queue_draw( pForm->FOverlay );
}

/* UI_FormUndoPush( hForm ) — save state before operation */
HB_FUNC( UI_FORMUNDOPUSH )
{
   HBForm * pForm = GetForm(1);
   UndoPushSnapshot( pForm );
}

/* UI_FormUndo( hForm ) — restore previous state */
HB_FUNC( UI_FORMUNDO )
{
   HBForm * pForm = GetForm(1);
   if( !pForm || s_undoCount <= 0 ) return;
   s_undoCount--;
   s_undoPos--;
   if( s_undoPos < 0 ) s_undoPos = UNDO_MAX_STEPS - 1;
   UndoRestoreSnapshot( pForm, &s_undoStack[s_undoPos] );
}

/* ======================================================================
 * Clipboard for Copy/Paste controls
 * ====================================================================== */

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
   HBForm * pForm = GetForm(1);
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
   HBForm * pForm = GetForm(1);
   if( !pForm || s_clipCount == 0 ) { hb_retni(0); return; }

   UndoPushSnapshot( pForm );  /* push undo before paste */

   for( int i = 0; i < s_clipCount; i++ )
   {
      HBControl * c = NULL;
      int t = s_clipboard[i].nType;
      int sz = sizeof(HBControl);

      if( t == CT_LABEL )         sz = sizeof(HBLabel);
      else if( t == CT_EDIT )     sz = sizeof(HBEdit);
      else if( t == CT_BUTTON )   sz = sizeof(HBButton);
      else if( t == CT_CHECKBOX ) sz = sizeof(HBCheckBox);
      else if( t == CT_COMBOBOX || t == CT_LISTBOX ) sz = sizeof(HBComboBox);
      else if( t == CT_GROUPBOX ) sz = sizeof(HBGroupBox);
      else if( t == CT_TIMER )    sz = sizeof(HBTimer);
      else if( t == CT_MAINMENU ) sz = sizeof(HBMainMenu);

      c = (HBControl *) calloc( 1, sz );
      if( !c ) continue;
      HBControl_Init( c );
      c->FControlType = t;
      c->FLeft   = s_clipboard[i].nLeft + 16;
      c->FTop    = s_clipboard[i].nTop + 16;
      c->FWidth  = s_clipboard[i].nWidth;
      c->FHeight = s_clipboard[i].nHeight;
      strncpy( c->FText, s_clipboard[i].szText, sizeof(c->FText) - 1 );

      switch( t ) {
         case CT_LABEL:    strcpy( c->FClassName, "TLabel" ); break;
         case CT_EDIT:     strcpy( c->FClassName, "TEdit" ); break;
         case CT_BUTTON:   strcpy( c->FClassName, "TButton" ); break;
         case CT_CHECKBOX: strcpy( c->FClassName, "TCheckBox" ); break;
         case CT_COMBOBOX: strcpy( c->FClassName, "TComboBox" ); break;
         case CT_GROUPBOX: strcpy( c->FClassName, "TGroupBox" ); break;
         default:          strcpy( c->FClassName, "TControl" ); break;
      }

      HBControl_AddChild( &pForm->base, c );
      KeepAlive( c );

      if( pForm->FSelCount < MAX_CHILDREN )
         pForm->FSelected[pForm->FSelCount++] = c;
   }

   if( pForm->FOverlay )
      gtk_widget_queue_draw( pForm->FOverlay );

   hb_retni( s_clipCount );
}

/* UI_FormGetClipCount() --> nCount */
HB_FUNC( UI_FORMGETCLIPCOUNT )
{
   hb_retni( s_clipCount );
}

/* ======================================================================
 * Tab Order Dialog
 * ====================================================================== */

HB_FUNC( UI_FORMTABORDERDIALOG )
{
   HBForm * pForm = GetForm(1);
   if( !pForm || pForm->base.FChildCount == 0 ) return;

   EnsureGTK();

   int n = pForm->base.FChildCount;
   int * order = (int *) malloc( n * sizeof(int) );
   for( int i = 0; i < n; i++ ) order[i] = i;

   GtkWidget * dialog = gtk_dialog_new_with_buttons( "Tab Order",
      pForm->FWindow ? GTK_WINDOW(pForm->FWindow) : NULL,
      GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "OK", GTK_RESPONSE_OK,
      "Cancel", GTK_RESPONSE_CANCEL,
      NULL );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );

   GtkListStore * store = gtk_list_store_new( 2, G_TYPE_INT, G_TYPE_STRING );
   GtkWidget * tree = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );

   GtkCellRenderer * ren = gtk_cell_renderer_text_new();
   gtk_tree_view_append_column( GTK_TREE_VIEW(tree),
      gtk_tree_view_column_new_with_attributes( "Control (Tab Order)", ren, "text", 1, NULL ) );

   /* Populate list */
   for( int i = 0; i < n; i++ )
   {
      HBControl * c = pForm->base.FChildren[order[i]];
      char buf[128];
      snprintf( buf, sizeof(buf), "%d.  %s  (%s)", i + 1, c->FName, c->FClassName );
      GtkTreeIter iter;
      gtk_list_store_append( store, &iter );
      gtk_list_store_set( store, &iter, 0, i, 1, buf, -1 );
   }

   GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
      GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC );
   gtk_widget_set_size_request( scroll, 350, 250 );
   gtk_container_add( GTK_CONTAINER(scroll), tree );

   GtkWidget * hbox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
   GtkWidget * btnUp = gtk_button_new_with_label( "Move Up" );
   GtkWidget * btnDown = gtk_button_new_with_label( "Move Down" );
   gtk_box_pack_start( GTK_BOX(hbox), btnUp, FALSE, FALSE, 4 );
   gtk_box_pack_start( GTK_BOX(hbox), btnDown, FALSE, FALSE, 4 );

   gtk_box_pack_start( GTK_BOX(content), scroll, TRUE, TRUE, 4 );
   gtk_box_pack_start( GTK_BOX(content), hbox, FALSE, FALSE, 4 );
   gtk_widget_show_all( content );

   /* Add custom response buttons for Up/Down */
   gtk_dialog_add_button( GTK_DIALOG(dialog), "Up", 100 );
   gtk_dialog_add_button( GTK_DIALOG(dialog), "Down", 101 );

   int done = 0;
   while( !done )
   {
      gint resp = gtk_dialog_run( GTK_DIALOG(dialog) );
      if( resp == GTK_RESPONSE_OK )
      {
         /* Apply the new order */
         HBControl * temp[MAX_CHILDREN];
         for( int i = 0; i < n; i++ )
            temp[i] = pForm->base.FChildren[order[i]];
         for( int i = 0; i < n; i++ )
            pForm->base.FChildren[i] = temp[i];
         done = 1;
      }
      else if( resp == 100 ) /* Up */
      {
         GtkTreeSelection * sel = gtk_tree_view_get_selection( GTK_TREE_VIEW(tree) );
         GtkTreeIter iter;
         if( gtk_tree_selection_get_selected( sel, NULL, &iter ) )
         {
            GtkTreePath * path = gtk_tree_model_get_path( GTK_TREE_MODEL(store), &iter );
            int idx = gtk_tree_path_get_indices( path )[0];
            gtk_tree_path_free( path );
            if( idx > 0 )
            {
               int tmp = order[idx]; order[idx] = order[idx-1]; order[idx-1] = tmp;
               gtk_list_store_clear( store );
               for( int i = 0; i < n; i++ )
               {
                  HBControl * c = pForm->base.FChildren[order[i]];
                  char buf[128];
                  snprintf( buf, sizeof(buf), "%d.  %s  (%s)", i + 1, c->FName, c->FClassName );
                  GtkTreeIter it;
                  gtk_list_store_append( store, &it );
                  gtk_list_store_set( store, &it, 0, i, 1, buf, -1 );
                  if( i == idx - 1 )
                     gtk_tree_selection_select_iter( sel, &it );
               }
            }
         }
      }
      else if( resp == 101 ) /* Down */
      {
         GtkTreeSelection * sel = gtk_tree_view_get_selection( GTK_TREE_VIEW(tree) );
         GtkTreeIter iter;
         if( gtk_tree_selection_get_selected( sel, NULL, &iter ) )
         {
            GtkTreePath * path = gtk_tree_model_get_path( GTK_TREE_MODEL(store), &iter );
            int idx = gtk_tree_path_get_indices( path )[0];
            gtk_tree_path_free( path );
            if( idx < n - 1 )
            {
               int tmp = order[idx]; order[idx] = order[idx+1]; order[idx+1] = tmp;
               gtk_list_store_clear( store );
               for( int i = 0; i < n; i++ )
               {
                  HBControl * c = pForm->base.FChildren[order[i]];
                  char buf[128];
                  snprintf( buf, sizeof(buf), "%d.  %s  (%s)", i + 1, c->FName, c->FClassName );
                  GtkTreeIter it;
                  gtk_list_store_append( store, &it );
                  gtk_list_store_set( store, &it, 0, i, 1, buf, -1 );
                  if( i == idx + 1 )
                     gtk_tree_selection_select_iter( sel, &it );
               }
            }
         }
      }
      else
         done = 1;
   }

   free( order );
   g_object_unref( store );
   gtk_widget_destroy( dialog );
}

/* Stub: DPI awareness is handled natively by GTK3 */
HB_FUNC( SETDPIAWARE )
{
   /* No-op on Linux/GTK3 — DPI scaling is automatic */
}

/* ======================================================================
 * Build Progress Dialog
 * ====================================================================== */

static void on_progress_cancel( GtkWidget * btn, gpointer data )
{
   (void)btn; (void)data;
   s_progressCancelled = 1;
   if( s_progressLabel )
      gtk_label_set_text( GTK_LABEL(s_progressLabel), "Cancelling..." );
}

/* GTK_ProgressOpen( cTitle, nSteps )
 * nSteps=0 → indeterminate mode with live log output */
HB_FUNC( GTK_PROGRESSOPEN )
{
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Building...";
   s_progressSteps = HB_ISNUM(2) ? hb_parni(2) : 7;
   s_progressCur = 0;
   s_progressCancelled = 0;

   EnsureGTK();

   if( s_progressWnd ) {
      gtk_window_present( GTK_WINDOW(s_progressWnd) );
      return;
   }

   int bLiveLog = ( s_progressSteps == 0 );

   s_progressWnd = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(s_progressWnd), cTitle );
   gtk_window_set_default_size( GTK_WINDOW(s_progressWnd),
      bLiveLog ? 560 : 420, bLiveLog ? 420 : 100 );
   gtk_window_set_resizable( GTK_WINDOW(s_progressWnd), bLiveLog );
   gtk_window_set_position( GTK_WINDOW(s_progressWnd), GTK_WIN_POS_CENTER );
   gtk_window_set_keep_above( GTK_WINDOW(s_progressWnd), TRUE );
   gtk_window_set_deletable( GTK_WINDOW(s_progressWnd), FALSE );
   gtk_container_set_border_width( GTK_CONTAINER(s_progressWnd), 12 );

   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 6 );
   gtk_container_add( GTK_CONTAINER(s_progressWnd), vbox );

   s_progressLabel = gtk_label_new( "Preparing..." );
   gtk_label_set_xalign( GTK_LABEL(s_progressLabel), 0.0 );
   gtk_box_pack_start( GTK_BOX(vbox), s_progressLabel, FALSE, FALSE, 0 );

   s_progressBar = gtk_progress_bar_new();
   if( bLiveLog )
      gtk_progress_bar_pulse( GTK_PROGRESS_BAR(s_progressBar) );
   else
      gtk_progress_bar_set_fraction( GTK_PROGRESS_BAR(s_progressBar), 0.0 );
   gtk_box_pack_start( GTK_BOX(vbox), s_progressBar, FALSE, FALSE, 0 );

   s_progressLog = NULL;
   if( bLiveLog )
   {
      /* Scrolled text view for live output */
      GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
      gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
         GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );

      s_progressLog = gtk_text_view_new();
      gtk_text_view_set_editable( GTK_TEXT_VIEW(s_progressLog), FALSE );
      gtk_text_view_set_cursor_visible( GTK_TEXT_VIEW(s_progressLog), FALSE );
      gtk_text_view_set_monospace( GTK_TEXT_VIEW(s_progressLog), TRUE );
      gtk_text_view_set_wrap_mode( GTK_TEXT_VIEW(s_progressLog), GTK_WRAP_WORD_CHAR );
      gtk_text_view_set_left_margin( GTK_TEXT_VIEW(s_progressLog), 6 );
      gtk_text_view_set_top_margin( GTK_TEXT_VIEW(s_progressLog), 4 );

      /* Dark background for log */
      GtkCssProvider * css = gtk_css_provider_new();
      gtk_css_provider_load_from_data( css,
         "textview { background-color: #1e1e1e; color: #d4d4d4; }", -1, NULL );
      gtk_style_context_add_provider( gtk_widget_get_style_context( s_progressLog ),
         GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
      g_object_unref( css );

      gtk_container_add( GTK_CONTAINER(scroll), s_progressLog );
      gtk_box_pack_start( GTK_BOX(vbox), scroll, TRUE, TRUE, 0 );

      /* Cancel button */
      GtkWidget * btnBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
      gtk_box_pack_start( GTK_BOX(vbox), btnBox, FALSE, FALSE, 0 );
      GtkWidget * cancelBtn = gtk_button_new_with_label( "Cancel" );
      g_signal_connect( cancelBtn, "clicked", G_CALLBACK(on_progress_cancel), NULL );
      gtk_box_pack_end( GTK_BOX(btnBox), cancelBtn, FALSE, FALSE, 0 );
   }

   gtk_widget_show_all( s_progressWnd );

   /* Process events so window appears immediately */
   while( gtk_events_pending() ) gtk_main_iteration();
}

/* GTK_ProgressStep( cText ) */
HB_FUNC( GTK_PROGRESSSTEP )
{
   if( !s_progressWnd ) return;

   if( HB_ISCHAR(1) && s_progressLabel )
      gtk_label_set_text( GTK_LABEL(s_progressLabel), hb_parc(1) );

   s_progressCur++;
   if( s_progressBar && s_progressSteps > 0 )
   {
      double frac = (double) s_progressCur / (double) s_progressSteps;
      if( frac > 1.0 ) frac = 1.0;
      gtk_progress_bar_set_fraction( GTK_PROGRESS_BAR(s_progressBar), frac );
   }

   while( gtk_events_pending() ) gtk_main_iteration();
}

/* GTK_ProgressClose() */
HB_FUNC( GTK_PROGRESSCLOSE )
{
   if( s_progressWnd )
   {
      gtk_widget_destroy( s_progressWnd );
      s_progressWnd = NULL;
      s_progressBar = NULL;
      s_progressLabel = NULL;
      s_progressLog = NULL;
      s_progressCancelled = 0;

      /* Flush events so the window disappears immediately */
      while( gtk_events_pending() ) gtk_main_iteration();
   }
}

/* ======================================================================
 * Build Error Dialog — resizable, with selectable/copyable text
 * ====================================================================== */

/* GTK_BuildErrorDialog( cTitle, cLog ) */
HB_FUNC( GTK_BUILDERRORDIALOG )
{
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Build Error";
   const char * cLog   = HB_ISCHAR(2) ? hb_parc(2) : "";

   EnsureGTK();

   GtkWidget * dialog = gtk_dialog_new_with_buttons( cTitle, NULL,
      GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "Copy to Clipboard", 1001,
      "Close", GTK_RESPONSE_CLOSE,
      NULL );
   gtk_window_set_default_size( GTK_WINDOW(dialog), 620, 400 );
   gtk_window_set_position( GTK_WINDOW(dialog), GTK_WIN_POS_CENTER );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );

   /* Scrolled text view with monospace font — read-only, selectable */
   GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );

   GtkWidget * textView = gtk_text_view_new();
   gtk_text_view_set_editable( GTK_TEXT_VIEW(textView), FALSE );
   gtk_text_view_set_cursor_visible( GTK_TEXT_VIEW(textView), TRUE );
   gtk_text_view_set_monospace( GTK_TEXT_VIEW(textView), TRUE );
   gtk_text_view_set_wrap_mode( GTK_TEXT_VIEW(textView), GTK_WRAP_WORD_CHAR );
   gtk_text_view_set_left_margin( GTK_TEXT_VIEW(textView), 8 );
   gtk_text_view_set_right_margin( GTK_TEXT_VIEW(textView), 8 );
   gtk_text_view_set_top_margin( GTK_TEXT_VIEW(textView), 8 );

   GtkTextBuffer * buf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(textView) );
   gtk_text_buffer_set_text( buf, cLog, -1 );

   gtk_container_add( GTK_CONTAINER(scroll), textView );
   gtk_box_pack_start( GTK_BOX(content), scroll, TRUE, TRUE, 0 );
   gtk_widget_show_all( content );

   /* Run dialog in a loop to handle Copy button */
   int done = 0;
   while( !done )
   {
      gint resp = gtk_dialog_run( GTK_DIALOG(dialog) );
      if( resp == 1001 )
      {
         /* Copy all text to clipboard */
         GtkClipboard * clip = gtk_clipboard_get( GDK_SELECTION_CLIPBOARD );
         GtkTextIter start, end;
         gtk_text_buffer_get_bounds( buf, &start, &end );
         gchar * text = gtk_text_buffer_get_text( buf, &start, &end, FALSE );
         gtk_clipboard_set_text( clip, text, -1 );
         g_free( text );

         /* Update button label temporarily */
         GtkWidget * copyBtn = gtk_dialog_get_widget_for_response( GTK_DIALOG(dialog), 1001 );
         if( copyBtn )
            gtk_button_set_label( GTK_BUTTON(copyBtn), "Copied!" );
      }
      else
         done = 1;
   }

   gtk_widget_destroy( dialog );
}

/* GTK_RuntimeErrorDialog( cTitle, cMsg, aButtons ) --> nChoice
 * Shows runtime error text in a scrollable monospaced GtkTextView with dynamic
 * action buttons from aButtons (e.g., {"Quit","Retry","Default"}) plus a
 * "Copy to Clipboard" button that copies without closing.
 * Returns the 1-based index of the pressed action button (Copy does not close).
 * Mirrors MAC_RuntimeErrorDialog in cocoa_core.m. */
HB_FUNC( GTK_RUNTIMEERRORDIALOG )
{
   const char * cTitle = HB_ISCHAR(1) ? hb_parc(1) : "Runtime Error";
   const char * cMsg   = HB_ISCHAR(2) ? hb_parc(2) : "";
   PHB_ITEM pButtons   = hb_param(3, HB_IT_ARRAY);

   EnsureGTK();

   GtkWidget * dialog = gtk_dialog_new( );
   gtk_window_set_title( GTK_WINDOW(dialog), cTitle );
   gtk_window_set_modal( GTK_WINDOW(dialog), TRUE );
   gtk_window_set_destroy_with_parent( GTK_WINDOW(dialog), TRUE );
   gtk_window_set_default_size( GTK_WINDOW(dialog), 620, 400 );
   gtk_window_set_position( GTK_WINDOW(dialog), GTK_WIN_POS_CENTER );

   /* Add dynamic action buttons from aButtons (1-based responses) */
   int nBtns = pButtons ? (int) hb_arrayLen( pButtons ) : 0;
   for( int i = 1; i <= nBtns; i++ )
      gtk_dialog_add_button( GTK_DIALOG(dialog),
         hb_arrayGetCPtr( pButtons, i ), i );
   if( nBtns == 0 )
      gtk_dialog_add_button( GTK_DIALOG(dialog), "OK", 1 );

   /* Copy to Clipboard button at end (response 1001, does not close) */
   gtk_dialog_add_button( GTK_DIALOG(dialog), "Copy to Clipboard", 1001 );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );

   /* Scrolled monospaced text view — read-only, selectable */
   GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );

   GtkWidget * textView = gtk_text_view_new();
   gtk_text_view_set_editable( GTK_TEXT_VIEW(textView), FALSE );
   gtk_text_view_set_cursor_visible( GTK_TEXT_VIEW(textView), TRUE );
   gtk_text_view_set_monospace( GTK_TEXT_VIEW(textView), TRUE );
   gtk_text_view_set_wrap_mode( GTK_TEXT_VIEW(textView), GTK_WRAP_WORD_CHAR );
   gtk_text_view_set_left_margin( GTK_TEXT_VIEW(textView), 8 );
   gtk_text_view_set_right_margin( GTK_TEXT_VIEW(textView), 8 );
   gtk_text_view_set_top_margin( GTK_TEXT_VIEW(textView), 8 );

   GtkTextBuffer * buf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(textView) );
   gtk_text_buffer_set_text( buf, cMsg, -1 );

   gtk_container_add( GTK_CONTAINER(scroll), textView );
   gtk_box_pack_start( GTK_BOX(content), scroll, TRUE, TRUE, 0 );
   gtk_widget_show_all( content );

   /* Run modal loop — Copy button copies text without closing */
   gint nChoice = 1;
   int done = 0;
   while( !done )
   {
      gint resp = gtk_dialog_run( GTK_DIALOG(dialog) );
      if( resp == 1001 )
      {
         GtkClipboard * clip = gtk_clipboard_get( GDK_SELECTION_CLIPBOARD );
         GtkTextIter start, end;
         gtk_text_buffer_get_bounds( buf, &start, &end );
         gchar * text = gtk_text_buffer_get_text( buf, &start, &end, FALSE );
         gtk_clipboard_set_text( clip, text, -1 );
         g_free( text );

         GtkWidget * copyBtn = gtk_dialog_get_widget_for_response( GTK_DIALOG(dialog), 1001 );
         if( copyBtn )
            gtk_button_set_label( GTK_BUTTON(copyBtn), "Copied!" );
      }
      else
      {
         /* Action button (1-based) or window closed (GTK_RESPONSE_DELETE_EVENT = -4) */
         nChoice = ( resp >= 1 && resp <= nBtns ) ? resp : 1;
         done = 1;
      }
   }

   gtk_widget_destroy( dialog );
   hb_retni( nChoice );
}

/* GTK_AppTerminate() — cleanly shut down the GTK main loop and exit.
 * Mirrors MAC_AppTerminate. Called from AppShowError after user chooses Quit. */
HB_FUNC( GTK_APPTERMINATE )
{
   if( gtk_main_level() > 0 )
      gtk_main_quit();
}


/* -----------------------------------------------------------------------
 * Stubs for the macOS-only TFolder / TPageControl / TreeView / TPython
 * backend functions. These exist so the Harbour code compiled from the
 * shared `hbbuilder_macos.prg` (which references them) can also link on
 * GTK3 / Linux. They are no-ops here; full implementation lives in the
 * Cocoa backend.
 * --------------------------------------------------------------------- */

HB_FUNC( UI_SETCTRLOWNER )
{
   HBControl * p = GetCtrl(1);
   HBControl * owner = HB_ISNUM(2) ? (HBControl *)(HB_PTRUINT) hb_parnint(2) : NULL;
   if( !p ) return;
   p->FPageOwner = owner;
   p->FPageIndex = HB_ISNUM(3) ? hb_parni(3) : 0;
}
HB_FUNC( UI_GETCTRLOWNER )
{
   HBControl * p = GetCtrl(1);
   hb_retnint( (HB_PTRUINT)( p ? p->FPageOwner : NULL ) );
}
HB_FUNC( UI_GETCTRLPAGE )
{
   HBControl * p = GetCtrl(1);
   hb_retni( p ? p->FPageIndex : 0 );
}
HB_FUNC( UI_ISAUTOPAGE )       { hb_retl( 0 ); }
HB_FUNC( UI_SETPENDINGPAGEOWNER )
{
   g_pendingPageOwner = HB_ISNUM(1) ? (HBControl *)(HB_PTRUINT) hb_parnint(1) : NULL;
   g_pendingPageIndex = HB_ISNUM(2) ? hb_parni(2) : 0;
}
HB_FUNC( UI_TABCONTROLNEW )
{
   /* (hParent, nLeft, nTop, nWidth, nHeight) -> hCtrl */
   HBControl * parent = GetCtrl(1);
   HBForm * form = NULL;
   HBTabControl2 * pc;
   if( parent )
   {
      HBControl * cur = parent;
      while( cur && cur->FControlType != CT_FORM ) cur = cur->FCtrlParent;
      if( cur ) form = (HBForm *) cur;
   }
   pc = (HBTabControl2 *) calloc( 1, sizeof(HBTabControl2) );
   HBControl_Init( &pc->base );
   strcpy( pc->base.FClassName, "TFolder" );
   pc->base.FControlType = CT_TABCONTROL2;
   pc->base.FLeft   = HB_ISNUM(2) ? hb_parni(2) : 0;
   pc->base.FTop    = HB_ISNUM(3) ? hb_parni(3) : 0;
   pc->base.FWidth  = HB_ISNUM(4) ? hb_parni(4) : 300;
   pc->base.FHeight = HB_ISNUM(5) ? hb_parni(5) : 200;
   /* SetPrompts will call UI_SetProp("aTabs", ...) after; no default here */
   if( form )
      HBControl_AddChild( &form->base, &pc->base );
   hb_retnint( (HB_PTRUINT) &pc->base );
}
HB_FUNC( UI_TREEVIEWNEW )      { hb_retnint( 0 ); }
HB_FUNC( UI_TABCONTROLSETSEL )
{
   HBControl * p = GetCtrl(1);
   int nIdx = HB_ISNUM(2) ? hb_parni(2) : 0;
   if( p && p->FControlType == CT_TABCONTROL2 && p->FWidget )
   {
      gtk_notebook_set_current_page( GTK_NOTEBOOK( p->FWidget ), nIdx );
      HBTabControl2_ApplyPageVisibility( p );
   }
}

/* ======================================================================
 * Extended controls - SpeedButton, StringGrid, MaskEdit, DateTimePicker,
 * MonthCalendar, DBGrid, WebView, Map, Scene3D, EarthView, Printer, PDF,
 * WebServer, HIX runtime
 * ====================================================================== */

/* --- TSpeedButton (flat toolbar-style button) --- */
HB_FUNC( UI_SPEEDBTNNEW )
{
   HBForm * pForm = GetForm(1);
   HBButton * p = (HBButton *) calloc( 1, sizeof(HBButton) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TSpeedButton" );
   p->base.FControlType = CT_SPEEDBTN;
   p->base.FWidth = 23; p->base.FHeight = 22;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);
   if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

/* --- TStringGrid (editable grid with columns/rows) --- */

/* Helper: get GtkListStore and GtkTreeView from a StringGrid control.
   The StringGrid widget is a GtkScrolledWindow containing a GtkTreeView. */
static GtkListStore * SGrid_GetStore( HBControl * p, GtkWidget ** ppTV )
{
   GtkWidget * sw = p ? p->FWidget : NULL;
   if( !sw || !GTK_IS_SCROLLED_WINDOW(sw) ) return NULL;
   GtkWidget * child = gtk_bin_get_child( GTK_BIN(sw) );
   if( !child || !GTK_IS_TREE_VIEW(child) ) return NULL;
   if( ppTV ) *ppTV = child;
   GtkTreeModel * model = gtk_tree_view_get_model( GTK_TREE_VIEW(child) );
   return GTK_IS_LIST_STORE(model) ? GTK_LIST_STORE(model) : NULL;
}

HB_FUNC( UI_STRINGGRIDNEW )
{
   HBForm * pForm = GetForm(1);
   HBBrowse * p = (HBBrowse *) calloc( 1, sizeof(HBBrowse) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TStringGrid" );
   p->base.FControlType = CT_STRINGGRID;
   p->base.FWidth = 200; p->base.FHeight = 120;
   p->FGridLines = 1;
   p->FRowHeight = 22;
   p->FColumnCount = HB_ISNUM(6) ? hb_parni(6) : 3;
   p->FRowCount    = HB_ISNUM(7) ? hb_parni(7) : 0;
   if( p->FColumnCount > MAX_BROWSE_COLS ) p->FColumnCount = MAX_BROWSE_COLS;
   p->FTreeView = NULL;

   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);

   /* Pre-allocate ListStore */
   EnsureGTK();
   GType types[MAX_BROWSE_COLS];
   for( int i = 0; i < MAX_BROWSE_COLS; i++ ) types[i] = G_TYPE_STRING;
   p->FStore = gtk_list_store_newv( p->FColumnCount > 0 ? p->FColumnCount : 3, types );

   /* Pre-populate rows */
   for( int r = 0; r < p->FRowCount; r++ )
   {
      GtkTreeIter iter;
      gtk_list_store_append( p->FStore, &iter );
   }

   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   hb_retnint( (HB_PTRUINT) &p->base );
}

/* UI_GridSetCell( hCtrl, nCol, nRow, cText ) — 0-based */
HB_FUNC( UI_GRIDSETCELL )
{
   HBControl * p = GetCtrl(1);
   if( !p ) return;
   int nCol = hb_parni(2), nRow = hb_parni(3);
   const char * cText = HB_ISCHAR(4) ? hb_parc(4) : "";

   if( p->FControlType == CT_STRINGGRID || p->FControlType == CT_BROWSE ||
       p->FControlType == CT_DBGRID )
   {
      HBBrowse * br = (HBBrowse *)p;
      if( !br->FStore ) return;
      if( nCol < 0 || nCol >= MAX_BROWSE_COLS ) return;

      /* Ensure enough rows exist */
      while( br->FRowCount <= nRow )
      {
         GtkTreeIter iter;
         gtk_list_store_append( br->FStore, &iter );
         br->FRowCount++;
      }

      GtkTreeIter iter;
      GtkTreePath * path = gtk_tree_path_new_from_indices( nRow, -1 );
      if( gtk_tree_model_get_iter( GTK_TREE_MODEL(br->FStore), &iter, path ) )
         gtk_list_store_set( br->FStore, &iter, nCol, cText, -1 );
      gtk_tree_path_free( path );
   }
}

/* UI_GridGetCell( hCtrl, nCol, nRow ) --> cText — 0-based */
HB_FUNC( UI_GRIDGETCELL )
{
   HBControl * p = GetCtrl(1);
   if( !p ) { hb_retc(""); return; }
   int nCol = hb_parni(2), nRow = hb_parni(3);

   if( p->FControlType == CT_STRINGGRID || p->FControlType == CT_BROWSE ||
       p->FControlType == CT_DBGRID )
   {
      HBBrowse * br = (HBBrowse *)p;
      if( !br->FStore || nRow < 0 || nRow >= br->FRowCount ||
          nCol < 0 || nCol >= MAX_BROWSE_COLS )
      { hb_retc(""); return; }

      GtkTreeIter iter;
      GtkTreePath * path = gtk_tree_path_new_from_indices( nRow, -1 );
      if( gtk_tree_model_get_iter( GTK_TREE_MODEL(br->FStore), &iter, path ) )
      {
         gchar * val = NULL;
         gtk_tree_model_get( GTK_TREE_MODEL(br->FStore), &iter, nCol, &val, -1 );
         hb_retc( val ? val : "" );
         if( val ) g_free( val );
      }
      else
         hb_retc("");
      gtk_tree_path_free( path );
   }
   else
      hb_retc("");
}

/* --- TMaskEdit (entry with input mask) --- */
HB_FUNC( UI_MASKEDITNEW )
{
   HBForm * pForm = GetForm(1);
   HBEdit * p = (HBEdit *) calloc( 1, sizeof(HBEdit) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TMaskEdit" );
   p->base.FControlType = CT_MASKEDIT2;
   p->base.FWidth = 120; p->base.FHeight = 24;
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) ); /* mask as text hint */
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);
   if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

/* --- TDateTimePicker --- */
HB_FUNC( UI_DATETIMEPICKERNEW )
{
   HBForm * pForm = GetForm(1);
   HBEdit * p = (HBEdit *) calloc( 1, sizeof(HBEdit) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TDateTimePicker" );
   p->base.FControlType = CT_DATETIMEPICKER;
   p->base.FWidth = 120; p->base.FHeight = 24;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

/* --- TMonthCalendar (GtkCalendar widget) --- */
HB_FUNC( UI_MONTHCALENDARNEW )
{
   HBForm * pForm = GetForm(1);
   HBControl * p = (HBControl *) calloc( 1, sizeof(HBControl) );
   HBControl_Init( p );
   strcpy( p->FClassName, "TMonthCalendar" );
   p->FControlType = CT_MONTHCALENDAR;
   p->FWidth = 240; p->FHeight = 200;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, p );
   RetCtrl( p );
}

/* --- TDBGrid (data-aware grid, shares Browse implementation) --- */
HB_FUNC( UI_DBGRIDNEW )
{
   HBForm * pForm = GetForm(1);
   HBBrowse * p = (HBBrowse *) calloc( 1, sizeof(HBBrowse) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TDBGrid" );
   p->base.FControlType = CT_DBGRID;
   p->base.FWidth = 400; p->base.FHeight = 200;
   p->FReadOnly = 0;
   p->FGridLines = 1;
   p->FRowHeight = 22;
   p->FColumnCount = 0;
   p->FRowCount = 0;
   p->FTreeView = NULL;
   p->FDataSourceName[0] = 0;
   memset( p->FCols, 0, sizeof(p->FCols) );

   EnsureGTK();
   GType types[MAX_BROWSE_COLS];
   for( int i = 0; i < MAX_BROWSE_COLS; i++ ) types[i] = G_TYPE_STRING;
   p->FStore = gtk_list_store_newv( MAX_BROWSE_COLS, types );

   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   hb_retnint( (HB_PTRUINT) &p->base );
}

/* UI_DBGridSetCache( hGrid, aRows ) — populate grid from Harbour array of arrays */
HB_FUNC( UI_DBGRIDSETCACHE )
{
   HBControl * p = GetCtrl(1);
   PHB_ITEM pArray = hb_param(2, HB_IT_ARRAY);
   if( !p || !pArray ) return;

   HBBrowse * br = (HBBrowse *)p;
   if( !br->FStore ) return;

   gtk_list_store_clear( br->FStore );
   br->FRowCount = 0;

   int nRows = (int) hb_arrayLen( pArray );
   for( int r = 0; r < nRows; r++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, r + 1 );
      if( !pRow || !HB_IS_ARRAY(pRow) ) continue;

      GtkTreeIter iter;
      gtk_list_store_append( br->FStore, &iter );
      br->FRowCount++;

      int nCols = (int) hb_arrayLen( pRow );
      if( nCols > MAX_BROWSE_COLS ) nCols = MAX_BROWSE_COLS;
      for( int c = 0; c < nCols; c++ )
      {
         const char * val = hb_arrayGetCPtr( pRow, c + 1 );
         gtk_list_store_set( br->FStore, &iter, c, val ? val : "", -1 );
      }
   }

   /* Refresh tree view if widget exists */
   if( br->FTreeView )
      gtk_widget_queue_draw( br->FTreeView );
}

/* ======================================================================
 * TWebView — uses WebKit2GTK if available at compile time, otherwise a
 * GtkLabel placeholder informing the user to install the dev package.
 * Build with: pkg-config --cflags --libs webkit2gtk-4.1
 * ====================================================================== */

static void HBWebView_CreateWidget( HBControl * p, GtkWidget * container )
{
#ifdef HAVE_WEBKIT2GTK
   HBWebView * wvCtrl = (HBWebView *)p;
   GtkWidget * wv = webkit_web_view_new();
   /* Load stored URL if set, otherwise about:blank */
   if( wvCtrl->FUrl[0] )
      webkit_web_view_load_uri( WEBKIT_WEB_VIEW(wv), wvCtrl->FUrl );
   else
      webkit_web_view_load_uri( WEBKIT_WEB_VIEW(wv), "about:blank" );
   HBGeneric_CreateWidget( p, container, wv );
#else
   GtkWidget * frame = gtk_frame_new( NULL );
   gtk_frame_set_shadow_type( GTK_FRAME(frame), GTK_SHADOW_IN );
   GtkWidget * label = gtk_label_new( "WebView\n(install libwebkit2gtk-4.1-dev)" );
   gtk_label_set_justify( GTK_LABEL(label), GTK_JUSTIFY_CENTER );
   gtk_container_add( GTK_CONTAINER(frame), label );
   HBGeneric_CreateWidget( p, container, frame );
#endif
}

HB_FUNC( UI_WEBVIEWNEW )
{
   HBForm * pForm = GetForm(1);
   HBWebView * p = (HBWebView *) calloc( 1, sizeof(HBWebView) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TWebView" );
   p->base.FControlType = CT_WEBVIEW;
   p->base.FWidth = 320; p->base.FHeight = 240;
   p->FUrl[0] = 0;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

/* UI_WebViewLoad( hCtrl, cURL ) */
HB_FUNC( UI_WEBVIEWLOAD )
{
   HBControl * p = GetCtrl(1);
   const char * url = hb_parc(2);
   if( !p || !url ) return;
   if( p->FControlType == CT_WEBVIEW )
      strncpy( ((HBWebView *)p)->FUrl, url, sizeof(((HBWebView *)p)->FUrl) - 1 );
#ifdef HAVE_WEBKIT2GTK
   if( p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      webkit_web_view_load_uri( WEBKIT_WEB_VIEW(p->FWidget), url );
#endif
}

/* UI_WebViewLoadHTML( hCtrl, cHTML [, cBaseURL] ) */
HB_FUNC( UI_WEBVIEWLOADHTML )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   const char * html = hb_parc(2);
   if( !p || !html || !p->FWidget ) return;
   GtkWidget * wv = p->FWidget;
   if( WEBKIT_IS_WEB_VIEW(wv) )
   {
      const char * base = HB_ISCHAR(3) ? hb_parc(3) : NULL;
      webkit_web_view_load_html( WEBKIT_WEB_VIEW(wv), html, base );
   }
#endif
}

/* UI_WebViewGoBack( hCtrl ) */
HB_FUNC( UI_WEBVIEWGOBACK )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      webkit_web_view_go_back( WEBKIT_WEB_VIEW(p->FWidget) );
#endif
}

/* UI_WebViewGoForward( hCtrl ) */
HB_FUNC( UI_WEBVIEWGOFORWARD )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      webkit_web_view_go_forward( WEBKIT_WEB_VIEW(p->FWidget) );
#endif
}

/* UI_WebViewReload( hCtrl ) */
HB_FUNC( UI_WEBVIEWRELOAD )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      webkit_web_view_reload( WEBKIT_WEB_VIEW(p->FWidget) );
#endif
}

/* UI_WebViewStop( hCtrl ) */
HB_FUNC( UI_WEBVIEWSTOP )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      webkit_web_view_stop_loading( WEBKIT_WEB_VIEW(p->FWidget) );
#endif
}

/* UI_WebViewEvaluateJS( hCtrl, cScript ) */
HB_FUNC( UI_WEBVIEWEVALUATEJS )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   const char * script = hb_parc(2);
   if( p && script && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      webkit_web_view_evaluate_javascript( WEBKIT_WEB_VIEW(p->FWidget),
         script, -1, NULL, NULL, NULL, NULL, NULL );
#endif
}

/* UI_WebViewGetURL( hCtrl ) --> cURL */
HB_FUNC( UI_WEBVIEWGETURL )
{
   HBControl * p = GetCtrl(1);
#ifdef HAVE_WEBKIT2GTK
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
   {
      const gchar * url = webkit_web_view_get_uri( WEBKIT_WEB_VIEW(p->FWidget) );
      hb_retc( url ? url : "" );
      return;
   }
#endif
   if( p && p->FControlType == CT_WEBVIEW )
      hb_retc( ((HBWebView *)p)->FUrl );
   else
      hb_retc( "" );
}

/* UI_WebViewCanGoBack( hCtrl ) --> lBool */
HB_FUNC( UI_WEBVIEWCANGOBACK )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      hb_retl( webkit_web_view_can_go_back( WEBKIT_WEB_VIEW(p->FWidget) ) );
   else
#endif
      hb_retl( 0 );
}

/* UI_WebViewCanGoForward( hCtrl ) --> lBool */
HB_FUNC( UI_WEBVIEWCANGOFORWARD )
{
#ifdef HAVE_WEBKIT2GTK
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget && WEBKIT_IS_WEB_VIEW(p->FWidget) )
      hb_retl( webkit_web_view_can_go_forward( WEBKIT_WEB_VIEW(p->FWidget) ) );
   else
#endif
      hb_retl( 0 );
}

/* ======================================================================
 * TScene3D / TEarthView / TMap — rendered with Cairo drawing
 * These use GtkDrawingArea with informative placeholder rendering.
 * Full 3D/map would require external libs (e.g., libchamplain for maps).
 * ====================================================================== */

typedef struct {
   HBControl base;
   char   FPicture[256];
   double FLat, FLon;
   int    FZoom;
} HBMapControl;

static gboolean on_scene3d_draw( GtkWidget * w, cairo_t * cr, gpointer data )
{
   HBControl * p = (HBControl *)data;
   int width  = gtk_widget_get_allocated_width( w );
   int height = gtk_widget_get_allocated_height( w );

   /* Dark background */
   cairo_set_source_rgb( cr, 0.05, 0.05, 0.15 );
   cairo_paint( cr );

   /* Draw a wireframe cube */
   cairo_set_source_rgb( cr, 0.2, 0.6, 1.0 );
   cairo_set_line_width( cr, 1.5 );
   double cx = width / 2.0, cy = height / 2.0;
   double s = (width < height ? width : height) * 0.25;
   double off = s * 0.4;
   /* Front face */
   cairo_rectangle( cr, cx - s, cy - s, s * 2, s * 2 );
   cairo_stroke( cr );
   /* Back face */
   cairo_rectangle( cr, cx - s + off, cy - s - off, s * 2, s * 2 );
   cairo_stroke( cr );
   /* Connecting edges */
   cairo_move_to( cr, cx - s, cy - s ); cairo_line_to( cr, cx - s + off, cy - s - off );
   cairo_move_to( cr, cx + s, cy - s ); cairo_line_to( cr, cx + s + off, cy - s - off );
   cairo_move_to( cr, cx + s, cy + s ); cairo_line_to( cr, cx + s + off, cy + s - off );
   cairo_move_to( cr, cx - s, cy + s ); cairo_line_to( cr, cx - s + off, cy + s - off );
   cairo_stroke( cr );

   /* Label */
   cairo_set_source_rgb( cr, 0.5, 0.5, 0.6 );
   cairo_select_font_face( cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL );
   cairo_set_font_size( cr, 11 );
   cairo_move_to( cr, 8, height - 8 );
   cairo_show_text( cr, p->FName[0] ? p->FName : "TScene3D" );

   return TRUE;
   (void)data;
}

static gboolean on_earthview_draw( GtkWidget * w, cairo_t * cr, gpointer data )
{
   HBMapControl * mc = (HBMapControl *)data;
   int width  = gtk_widget_get_allocated_width( w );
   int height = gtk_widget_get_allocated_height( w );

   /* Space background */
   cairo_set_source_rgb( cr, 0.0, 0.0, 0.05 );
   cairo_paint( cr );

   /* Draw Earth as a circle */
   double cx = width / 2.0, cy = height / 2.0;
   double r = (width < height ? width : height) * 0.38;
   cairo_arc( cr, cx, cy, r, 0, 2 * 3.14159265 );
   cairo_set_source_rgb( cr, 0.1, 0.3, 0.6 );
   cairo_fill_preserve( cr );
   cairo_set_source_rgb( cr, 0.2, 0.7, 0.3 );
   cairo_set_line_width( cr, 1.0 );
   cairo_stroke( cr );

   /* Continents hint (simple shapes) */
   cairo_set_source_rgb( cr, 0.2, 0.55, 0.2 );
   cairo_arc( cr, cx - r*0.2, cy - r*0.3, r*0.25, 0, 2*3.14159265 );
   cairo_fill( cr );
   cairo_arc( cr, cx + r*0.3, cy + r*0.1, r*0.2, 0, 2*3.14159265 );
   cairo_fill( cr );

   /* Coordinate label */
   char buf[64];
   snprintf( buf, sizeof(buf), "Lat: %.1f  Lon: %.1f", mc->FLat, mc->FLon );
   cairo_set_source_rgb( cr, 0.7, 0.7, 0.8 );
   cairo_select_font_face( cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL );
   cairo_set_font_size( cr, 11 );
   cairo_move_to( cr, 8, height - 8 );
   cairo_show_text( cr, buf );

   return TRUE;
}

static gboolean on_map_draw( GtkWidget * w, cairo_t * cr, gpointer data )
{
   HBMapControl * mc = (HBMapControl *)data;
   int width  = gtk_widget_get_allocated_width( w );
   int height = gtk_widget_get_allocated_height( w );

   /* Light map background */
   cairo_set_source_rgb( cr, 0.85, 0.90, 0.95 );
   cairo_paint( cr );

   /* Draw grid lines */
   cairo_set_source_rgb( cr, 0.75, 0.80, 0.88 );
   cairo_set_line_width( cr, 0.5 );
   int spacing = 40;
   for( int x = 0; x < width; x += spacing )
   { cairo_move_to( cr, x, 0 ); cairo_line_to( cr, x, height ); }
   for( int y = 0; y < height; y += spacing )
   { cairo_move_to( cr, 0, y ); cairo_line_to( cr, width, y ); }
   cairo_stroke( cr );

   /* Center crosshair (map pin) */
   double cx = width / 2.0, cy = height / 2.0;
   cairo_set_source_rgb( cr, 0.9, 0.2, 0.2 );
   cairo_set_line_width( cr, 2.0 );
   cairo_arc( cr, cx, cy - 12, 8, 0, 2 * 3.14159265 );
   cairo_fill( cr );
   cairo_move_to( cr, cx, cy - 4 );
   cairo_line_to( cr, cx, cy + 4 );
   cairo_stroke( cr );

   /* Coordinate label */
   char buf[80];
   snprintf( buf, sizeof(buf), "Lat: %.4f  Lon: %.4f  Zoom: %d",
      mc->FLat, mc->FLon, mc->FZoom );
   cairo_set_source_rgb( cr, 0.2, 0.2, 0.3 );
   cairo_select_font_face( cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL );
   cairo_set_font_size( cr, 11 );
   cairo_move_to( cr, 8, height - 8 );
   cairo_show_text( cr, buf );

   return TRUE;
}

HB_FUNC( UI_SCENE3DNEW )
{
   HBForm * pForm = GetForm(1);
   HBControl * p = (HBControl *) calloc( 1, sizeof(HBControl) );
   HBControl_Init( p );
   strcpy( p->FClassName, "TScene3D" );
   p->FControlType = CT_SCENE3D;
   p->FWidth = 400; p->FHeight = 300;
   if( HB_ISNUM(2) ) p->FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, p );
   RetCtrl( p );
}

HB_FUNC( UI_EARTHVIEWNEW )
{
   HBForm * pForm = GetForm(1);
   HBMapControl * p = (HBMapControl *) calloc( 1, sizeof(HBMapControl) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TEarthView" );
   p->base.FControlType = CT_EARTHVIEW;
   p->base.FWidth = 400; p->base.FHeight = 400;
   p->FLat = 20.0; p->FLon = 0.0; p->FZoom = 3;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( HB_ISNUM(6) ) p->FLat = hb_parnd(6);
   if( HB_ISNUM(7) ) p->FLon = hb_parnd(7);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

HB_FUNC( UI_MAPNEW )
{
   HBForm * pForm = GetForm(1);
   HBMapControl * p = (HBMapControl *) calloc( 1, sizeof(HBMapControl) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TMap" );
   p->base.FControlType = CT_MAP;
   p->base.FWidth = 400; p->base.FHeight = 300;
   p->FLat = 0.0; p->FLon = 0.0; p->FZoom = 5;
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);
   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( HB_ISNUM(6) ) p->FLat = hb_parnd(6);
   if( HB_ISNUM(7) ) p->FLon = hb_parnd(7);
   if( HB_ISNUM(8) ) p->FZoom = hb_parni(8);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   RetCtrl( &p->base );
}

/* UI_MapSetRegion( hCtrl, dLat, dLon, nZoom ) */
HB_FUNC( UI_MAPSETREGION )
{
   HBControl * p = GetCtrl(1);
   if( !p ) return;
   HBMapControl * mc = (HBMapControl *)p;
   if( HB_ISNUM(2) ) mc->FLat = hb_parnd(2);
   if( HB_ISNUM(3) ) mc->FLon = hb_parnd(3);
   if( HB_ISNUM(4) ) mc->FZoom = hb_parni(4);
   if( p->FWidget ) gtk_widget_queue_draw( p->FWidget );
}

/* UI_MapAddPin( hCtrl, dLat, dLon, cTitle, cSubtitle ) */
HB_FUNC( UI_MAPADDPIN )
{
   /* Pins are rendered in the draw callback; for now just redraw */
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget ) gtk_widget_queue_draw( p->FWidget );
}

/* UI_MapClearPins( hCtrl ) */
HB_FUNC( UI_MAPCLEARPINS )
{
   HBControl * p = GetCtrl(1);
   if( p && p->FWidget ) gtk_widget_queue_draw( p->FWidget );
}

/* ======================================================================
 * Printer support — GTK Print API
 * ====================================================================== */

/* UI_GetPrinters() --> aNames */
HB_FUNC( UI_GETPRINTERS )
{
   EnsureGTK();
   PHB_ITEM pArray = hb_itemArrayNew( 0 );

   /* Use CUPS/GTK to enumerate printers */
   GtkPrintSettings * settings = gtk_print_settings_new();
   /* gtk_enumerate_printers is async; for a simple sync list, use CUPS directly
      or return the default printer.  For now, return system default. */
   const gchar * defPrinter = gtk_print_settings_get_printer( settings );
   if( defPrinter )
   {
      PHB_ITEM pItem = hb_itemPutC( NULL, defPrinter );
      hb_arrayAdd( pArray, pItem );
      hb_itemRelease( pItem );
   }
   else
   {
      /* Add a generic entry so the array is not empty */
      PHB_ITEM pItem = hb_itemPutC( NULL, "Default Printer" );
      hb_arrayAdd( pArray, pItem );
      hb_itemRelease( pItem );
   }
   g_object_unref( settings );

   hb_itemReturnRelease( pArray );
}

/* UI_ShowPrintPanel() --> cPrinterName
   Uses GtkPrintOperation to show the native print dialog. */
HB_FUNC( UI_SHOWPRINTPANEL )
{
   EnsureGTK();
   GtkPrintOperation * op = gtk_print_operation_new();
   GtkPrintOperationResult res;

   gtk_print_operation_set_n_pages( op, 1 );
   res = gtk_print_operation_run( op, GTK_PRINT_OPERATION_ACTION_PRINT_DIALOG, NULL, NULL );

   if( res == GTK_PRINT_OPERATION_RESULT_APPLY )
   {
      GtkPrintSettings * settings = gtk_print_operation_get_print_settings( op );
      const gchar * pname = gtk_print_settings_get_printer( settings );
      hb_retc( pname ? pname : "Default Printer" );
   }
   else
      hb_retc( "" );

   g_object_unref( op );
}

/* ======================================================================
 * PDF Generation — direct PDF file output using cairo-pdf
 * ====================================================================== */

#include <cairo-pdf.h>

static cairo_surface_t * s_pdfSurface = NULL;
static cairo_t *         s_pdfCr = NULL;
static double            s_pdfPageW = 595.0;  /* A4 points */
static double            s_pdfPageH = 842.0;
static double            s_pdfMarginL = 36, s_pdfMarginR = 36;
static double            s_pdfMarginT = 36, s_pdfMarginB = 36;

/* RPT_PdfOpen( nPageW, nPageH, nMarginL, nMarginR, nMarginT, nMarginB ) */
HB_FUNC( RPT_PDFOPEN )
{
   s_pdfPageW   = HB_ISNUM(1) ? hb_parnd(1) : 595.0;
   s_pdfPageH   = HB_ISNUM(2) ? hb_parnd(2) : 842.0;
   s_pdfMarginL = HB_ISNUM(3) ? hb_parnd(3) : 36.0;
   s_pdfMarginR = HB_ISNUM(4) ? hb_parnd(4) : 36.0;
   s_pdfMarginT = HB_ISNUM(5) ? hb_parnd(5) : 36.0;
   s_pdfMarginB = HB_ISNUM(6) ? hb_parnd(6) : 36.0;

   /* Create a temporary surface; actual file is written on ExportPDF */
   if( s_pdfSurface ) cairo_surface_destroy( s_pdfSurface );
   if( s_pdfCr ) cairo_destroy( s_pdfCr );

   s_pdfSurface = cairo_pdf_surface_create( "/tmp/hbbuilder_report.pdf",
      s_pdfPageW, s_pdfPageH );
   s_pdfCr = cairo_create( s_pdfSurface );
}

/* RPT_PdfAddPage() */
HB_FUNC( RPT_PDFADDPAGE )
{
   if( !s_pdfCr ) return;
   cairo_show_page( s_pdfCr );
}

/* RPT_PdfDrawRect( nLeft, nTop, nWidth, nHeight, nBackColor, lFilled ) */
HB_FUNC( RPT_PDFDRAWRECT )
{
   if( !s_pdfCr ) return;
   double nL = hb_parnd(1), nT = hb_parnd(2);
   double nW = hb_parnd(3), nH = hb_parnd(4);
   int nColor = HB_ISNUM(5) ? hb_parni(5) : 0xFFFFFF;
   int lFilled = HB_ISLOG(6) ? hb_parl(6) : 0;

   double r = ((nColor >> 16) & 0xFF) / 255.0;
   double g = ((nColor >> 8)  & 0xFF) / 255.0;
   double b = ( nColor        & 0xFF) / 255.0;

   cairo_set_source_rgb( s_pdfCr, r, g, b );
   cairo_rectangle( s_pdfCr, nL, nT, nW, nH );
   if( lFilled )
      cairo_fill( s_pdfCr );
   else
   {
      cairo_set_line_width( s_pdfCr, 0.5 );
      cairo_stroke( s_pdfCr );
   }
}

/* RPT_PdfDrawText( nLeft, nTop, cText, cFontName, nFontSize, lBold, lItalic, nForeColor ) */
HB_FUNC( RPT_PDFDRAWTEXT )
{
   if( !s_pdfCr ) return;
   double nL = hb_parnd(1), nT = hb_parnd(2);
   const char * cText = HB_ISCHAR(3) ? hb_parc(3) : "";
   const char * cFont = HB_ISCHAR(4) ? hb_parc(4) : "Sans";
   double nSize = HB_ISNUM(5) ? hb_parnd(5) : 10.0;
   int lBold   = HB_ISLOG(6) ? hb_parl(6) : 0;
   int lItalic = HB_ISLOG(7) ? hb_parl(7) : 0;
   int nColor  = HB_ISNUM(8) ? hb_parni(8) : 0;

   double r = ((nColor >> 16) & 0xFF) / 255.0;
   double g = ((nColor >> 8)  & 0xFF) / 255.0;
   double b = ( nColor        & 0xFF) / 255.0;

   cairo_select_font_face( s_pdfCr, cFont,
      lItalic ? CAIRO_FONT_SLANT_ITALIC : CAIRO_FONT_SLANT_NORMAL,
      lBold   ? CAIRO_FONT_WEIGHT_BOLD  : CAIRO_FONT_WEIGHT_NORMAL );
   cairo_set_font_size( s_pdfCr, nSize );
   cairo_set_source_rgb( s_pdfCr, r, g, b );
   cairo_move_to( s_pdfCr, nL, nT + nSize );
   cairo_show_text( s_pdfCr, cText );
}

/* RPT_ExportPdf( cFile ) — finish and copy PDF to destination */
HB_FUNC( RPT_EXPORTPDF )
{
   const char * cFile = hb_parc(1);

   if( s_pdfCr )   { cairo_destroy( s_pdfCr );          s_pdfCr = NULL; }
   if( s_pdfSurface ) { cairo_surface_destroy( s_pdfSurface ); s_pdfSurface = NULL; }

   if( cFile && cFile[0] )
   {
      /* Copy temp PDF to destination */
      FILE * src = fopen( "/tmp/hbbuilder_report.pdf", "rb" );
      FILE * dst = fopen( cFile, "wb" );
      if( src && dst )
      {
         char buf[8192];
         size_t n;
         while( (n = fread( buf, 1, sizeof(buf), src )) > 0 )
            fwrite( buf, 1, n, dst );
      }
      if( src ) fclose( src );
      if( dst ) fclose( dst );
   }
}

/* ======================================================================
 * HTTP Web Server — lightweight socket-based server
 * Runs in a background thread, dispatches requests to Harbour callbacks.
 * ====================================================================== */

static int  s_httpServerFd = -1;
static int  s_httpRunning  = 0;
static pthread_t s_httpThread;

/* Current request context (per-request, single-threaded dispatch) */
static int    s_httpClientFd   = -1;
static int    s_httpStatusCode = 200;
static char   s_httpContentType[128] = "text/html; charset=utf-8";
static char * s_httpResponseBody = NULL;
static int    s_httpResponseLen  = 0;

static void http_append_body( const char * data, int len )
{
   if( !data || len <= 0 ) return;
   s_httpResponseBody = (char *) realloc( s_httpResponseBody, s_httpResponseLen + len + 1 );
   memcpy( s_httpResponseBody + s_httpResponseLen, data, len );
   s_httpResponseLen += len;
   s_httpResponseBody[s_httpResponseLen] = 0;
}

static void http_send_response( int fd )
{
   char header[512];
   snprintf( header, sizeof(header),
      "HTTP/1.1 %d OK\r\n"
      "Content-Type: %s\r\n"
      "Content-Length: %d\r\n"
      "Connection: close\r\n\r\n",
      s_httpStatusCode, s_httpContentType, s_httpResponseLen );
   send( fd, header, strlen(header), 0 );
   if( s_httpResponseBody && s_httpResponseLen > 0 )
      send( fd, s_httpResponseBody, s_httpResponseLen, 0 );
}

/* UI_WebServerStart( nPort [, nPortSSL, cRoot, lTrace, oServer] ) --> lSuccess */
HB_FUNC( UI_WEBSERVERSTART )
{
   int nPort = HB_ISNUM(1) ? hb_parni(1) : 8080;
   if( nPort <= 0 ) nPort = 8080;

   if( s_httpRunning ) { hb_retl( 1 ); return; }

   s_httpServerFd = socket( AF_INET, SOCK_STREAM, 0 );
   if( s_httpServerFd < 0 ) { hb_retl( 0 ); return; }

   int opt = 1;
   setsockopt( s_httpServerFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt) );

   struct sockaddr_in addr;
   memset( &addr, 0, sizeof(addr) );
   addr.sin_family = AF_INET;
   addr.sin_addr.s_addr = htonl( INADDR_ANY );
   addr.sin_port = htons( nPort );

   if( bind( s_httpServerFd, (struct sockaddr *)&addr, sizeof(addr) ) < 0 )
   {
      close( s_httpServerFd );
      s_httpServerFd = -1;
      hb_retl( 0 );
      return;
   }

   if( listen( s_httpServerFd, 16 ) < 0 )
   {
      close( s_httpServerFd );
      s_httpServerFd = -1;
      hb_retl( 0 );
      return;
   }

   s_httpRunning = 1;
   hb_retl( 1 );
}

/* UI_WebServerStop() */
HB_FUNC( UI_WEBSERVERSTOP )
{
   s_httpRunning = 0;
   if( s_httpServerFd >= 0 )
   {
      close( s_httpServerFd );
      s_httpServerFd = -1;
   }
}

/* UI_HIX_Write( cText ) — append to current HTTP response body */
HB_FUNC( UI_HIX_WRITE )
{
   const char * data = hb_parc(1);
   if( data )
      http_append_body( data, (int) hb_parclen(1) );
}

/* UI_HIX_SetStatus( nCode ) — set HTTP response status code */
HB_FUNC( UI_HIX_SETSTATUS )
{
   s_httpStatusCode = HB_ISNUM(1) ? hb_parni(1) : 200;
}

/* ======================================================================
 * HIX Runtime — Harbour-compatible template engine functions
 * These are normally defined in hix_runtime.prg but need C linkage
 * when that file is not compiled into the project.
 * ====================================================================== */

static char s_hixRoot[512] = ".";

/* HIX_SetRoot( cRoot ) */
HB_FUNC( HIX_SETROOT )
{
   if( HB_ISCHAR(1) )
      strncpy( s_hixRoot, hb_parc(1), sizeof(s_hixRoot) - 1 );
}

/* HIX_ExecPrg( cFile ) — compile and execute a .prg file at runtime.
   Calls Harbour's hb_compileFromBuf → hb_hrbLoad → hb_hrbDo chain. */
HB_FUNC( HIX_EXECPRG )
{
   const char * cFile = hb_parc(1);
   if( !cFile || !cFile[0] ) return;

   /* Check if file exists */
   FILE * f = fopen( cFile, "r" );
   if( !f )
   {
      char msg[256];
      snprintf( msg, sizeof(msg), "<!-- HIX_ExecPrg: file not found: %s -->", cFile );
      http_append_body( msg, (int)strlen(msg) );
      return;
   }

   /* Read file content */
   fseek( f, 0, SEEK_END );
   long fsize = ftell( f );
   fseek( f, 0, SEEK_SET );
   char * code = (char *) malloc( fsize + 1 );
   fread( code, 1, fsize, f );
   code[fsize] = 0;
   fclose( f );

   /* Compile and execute via Harbour VM dynamic symbol dispatch */
   PHB_DYNS pCompSym = hb_dynsymFind( "HB_COMPILEFROMBUF" );
   if( pCompSym )
   {
      hb_vmPushDynSym( pCompSym );
      hb_vmPushNil();
      hb_vmPushString( code, fsize );
      hb_vmPushString( "-n", 2 );
      hb_vmPushString( "-w", 2 );
      hb_vmPushString( "-q", 2 );
      hb_vmDo( 4 );

      PHB_ITEM pHrb = hb_itemNew( hb_stackReturnItem() );
      if( pHrb && !HB_IS_NIL(pHrb) )
      {
         PHB_DYNS pLoadSym = hb_dynsymFind( "HB_HRBLOAD" );
         if( pLoadSym )
         {
            hb_vmPushDynSym( pLoadSym );
            hb_vmPushNil();
            hb_vmPush( pHrb );
            hb_vmDo( 1 );

            PHB_ITEM pMod = hb_itemNew( hb_stackReturnItem() );
            if( pMod && !HB_IS_NIL(pMod) )
            {
               PHB_DYNS pDoSym = hb_dynsymFind( "HB_HRBDO" );
               if( pDoSym )
               {
                  hb_vmPushDynSym( pDoSym );
                  hb_vmPushNil();
                  hb_vmPush( pMod );
                  hb_vmDo( 1 );
               }
            }
            if( pMod ) hb_itemRelease( pMod );
         }
      }
      if( pHrb ) hb_itemRelease( pHrb );
   }
   else
   {
      /* Fallback: hb_compileFromBuf not available, output raw content */
      http_append_body( code, (int)fsize );
   }
   free( code );
}

/* HIX_ServeStatic( cFilePath ) — serve a static file with correct MIME type */
HB_FUNC( HIX_SERVESTATIC )
{
   const char * cFile = hb_parc(1);
   if( !cFile || !cFile[0] ) return;

   /* Detect MIME type from extension */
   const char * dot = strrchr( cFile, '.' );
   const char * mime = "application/octet-stream";
   if( dot )
   {
      if( strcasecmp(dot, ".html") == 0 || strcasecmp(dot, ".htm") == 0 )
         mime = "text/html; charset=utf-8";
      else if( strcasecmp(dot, ".css") == 0 )  mime = "text/css";
      else if( strcasecmp(dot, ".js") == 0 )   mime = "application/javascript";
      else if( strcasecmp(dot, ".json") == 0 )  mime = "application/json";
      else if( strcasecmp(dot, ".png") == 0 )   mime = "image/png";
      else if( strcasecmp(dot, ".jpg") == 0 || strcasecmp(dot, ".jpeg") == 0 )
         mime = "image/jpeg";
      else if( strcasecmp(dot, ".gif") == 0 )   mime = "image/gif";
      else if( strcasecmp(dot, ".svg") == 0 )   mime = "image/svg+xml";
      else if( strcasecmp(dot, ".ico") == 0 )   mime = "image/x-icon";
      else if( strcasecmp(dot, ".txt") == 0 )   mime = "text/plain";
      else if( strcasecmp(dot, ".pdf") == 0 )   mime = "application/pdf";
   }
   strncpy( s_httpContentType, mime, sizeof(s_httpContentType) - 1 );

   /* Read and append file content */
   FILE * f = fopen( cFile, "rb" );
   if( !f ) return;
   fseek( f, 0, SEEK_END );
   long fsize = ftell( f );
   fseek( f, 0, SEEK_SET );
   char * buf = (char *) malloc( fsize );
   if( buf )
   {
      fread( buf, 1, fsize, f );
      http_append_body( buf, (int) fsize );
      free( buf );
   }
   fclose( f );
}
