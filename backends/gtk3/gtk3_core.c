/*
 * gtk3_core.c - GTK3 implementation of hbcpp framework for Linux
 * Replaces the Win32 C++ core (tcontrol.cpp, tform.cpp, tcontrols.cpp, hbbridge.cpp)
 *
 * Provides the same HB_FUNC bridge interface so Harbour code (classes.prg) works unchanged.
 */

#include <gtk/gtk.h>
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
 * Forward declarations
 * ====================================================================== */

typedef struct _HBControl  HBControl;
typedef struct _HBForm     HBForm;
typedef struct _HBButton   HBButton;
typedef struct _HBCheckBox HBCheckBox;
typedef struct _HBComboBox HBComboBox;
typedef struct _HBEdit     HBEdit;
typedef struct _HBGroupBox HBGroupBox;
typedef struct _HBLabel    HBLabel;

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

   PHB_ITEM FOnClick, FOnChange, FOnInit, FOnClose;

   HBControl * FCtrlParent;
   HBControl * FChildren[MAX_CHILDREN];
   int FChildCount;
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
   /* Toolbar */
   HBControl *  FToolBar;
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
   p->FOnClick = NULL; p->FOnChange = NULL;
   p->FOnInit = NULL; p->FOnClose = NULL;
   p->FCtrlParent = NULL; p->FChildCount = 0;
   memset( p->FChildren, 0, sizeof(p->FChildren) );
}

static void HBControl_AddChild( HBControl * parent, HBControl * child )
{
   if( parent->FChildCount < MAX_CHILDREN )
   {
      parent->FChildren[parent->FChildCount++] = child;
      child->FCtrlParent = parent;
   }
}

static void HBControl_SetText( HBControl * p, const char * text )
{
   strncpy( p->FText, text, sizeof(p->FText) - 1 );
   p->FText[sizeof(p->FText) - 1] = 0;
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
   HBControl_ApplyFont( &p->base );
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
         frm->FRunning = 0;
         if( frm->FWindow ) gtk_widget_destroy( frm->FWindow );
         frm->FWindow = NULL;
         /* FRunning = 0 stops the manual event loop */
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
   if( p->FItemIndex >= 0 && p->FItemIndex < p->FItemCount )
      gtk_combo_box_set_active( GTK_COMBO_BOX(combo), p->FItemIndex );
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

      /* 8 handles */
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
      HBForm_ClearSelection( form );

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
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   GtkListStore * store = gtk_list_store_new( 1, G_TYPE_STRING );
   GtkWidget * tv = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   GtkCellRenderer * r = gtk_cell_renderer_text_new();
   gtk_tree_view_insert_column_with_attributes( GTK_TREE_VIEW(tv), -1, "Items", r, "text", 0, NULL );
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(tv), FALSE );
   gtk_container_add( GTK_CONTAINER(sw), tv );
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

static void HBTabControl_CreateWidget( HBControl * p, GtkWidget * container )
{
   GtkWidget * nb = gtk_notebook_new();
   GtkWidget * page1 = gtk_label_new( "Page 1" );
   gtk_notebook_append_page( GTK_NOTEBOOK(nb), page1, gtk_label_new("Tab 1") );
   HBGeneric_CreateWidget( p, container, nb );
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
            { CT_TABCONTROL2,"TTabControl",     "",           200, 150 },
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
               HBControl * p = (HBControl*)calloc(1,sizeof(HBControl));
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
      HBControl_AddChild( &form->base, newCtrl );

      /* Create GTK widget and add to the form's GtkFixed */
      if( form->FFixed )
      {
         HBControl_CreateWidget( newCtrl, form->FFixed, form->FFormFontDesc );
         gtk_widget_show_all( form->FFixed );
      }

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

         /* Enforce minimum size */
         if( rw < 20 ) rw = 80;
         if( rh < 10 ) rh = 24;
         /* Snap to 8-pixel grid */
         rx1 = (rx1 / 8) * 8;
         ry1 = (ry1 / 8) * 8;

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
   form->FToolBar = NULL; form->FClientTop = 0; form->FSizable = 0; form->FAppBar = 0;
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
   form->FRunning = 0;
   form->FWindow = NULL;
   gtk_main_quit();
}

static void HBForm_CreateAllChildren( HBForm * form )
{
   /* GroupBoxes first */
   for( int i = 0; i < form->base.FChildCount; i++ )
      if( form->base.FChildren[i]->FControlType == CT_GROUPBOX )
      {
         strcpy( form->base.FChildren[i]->FFontDesc, form->FFormFontDesc );
         HBGroupBox_CreateWidget( (HBGroupBox *)form->base.FChildren[i], form->FFixed );
      }
   /* Then other controls */
   for( int i = 0; i < form->base.FChildCount; i++ )
   {
      HBControl * child = form->base.FChildren[i];
      if( child->FControlType == CT_GROUPBOX ) continue;
      strcpy( child->FFontDesc, form->FFormFontDesc );
      switch( child->FControlType )
      {
         case CT_LABEL:    HBLabel_CreateWidget( (HBLabel *)child, form->FFixed ); break;
         case CT_EDIT:     HBEdit_CreateWidget( (HBEdit *)child, form->FFixed ); break;
         case CT_BUTTON:   HBButton_CreateWidget( (HBButton *)child, form->FFixed ); break;
         case CT_CHECKBOX: HBCheckBox_CreateWidget( (HBCheckBox *)child, form->FFixed ); break;
         case CT_COMBOBOX: HBComboBox_CreateWidget( (HBComboBox *)child, form->FFixed ); break;
      }
   }
}

static void HBForm_Run( HBForm * form )
{
   EnsureGTK();

   form->FWindow = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(form->FWindow), form->base.FText );
   gtk_window_set_default_size( GTK_WINDOW(form->FWindow), form->base.FWidth, form->base.FHeight );
   gtk_window_set_resizable( GTK_WINDOW(form->FWindow),
      (form->FSizable && !form->FAppBar) ? TRUE : FALSE );
   g_signal_connect( form->FWindow, "destroy", G_CALLBACK(on_window_destroy), form );
   g_signal_connect( form->FWindow, "configure-event", G_CALLBACK(on_window_configure), form );

   /* Set background color via CSS */
   {
      unsigned int clr = form->base.FClrPane;
      int r = clr & 0xFF, g = (clr >> 8) & 0xFF, b = (clr >> 16) & 0xFF;
      char css[128];
      snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
      GtkCssProvider * provider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( form->FWindow );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
      g_object_unref( provider );
   }

   /* Attach accelerator group if menu accelerators were defined */
   if( s_accelGroup )
      gtk_window_add_accel_group( GTK_WINDOW(form->FWindow), s_accelGroup );

   /* VBox: menubar + toolbar + overlay(fixed + design) */
   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(form->FWindow), vbox );
   gtk_widget_show( vbox );

   /* Menu bar if created */
   if( form->FMenuBar ) {
      gtk_box_pack_start( GTK_BOX(vbox), form->FMenuBar, FALSE, FALSE, 0 );
      gtk_widget_show_all( form->FMenuBar );
   }

   /* Toolbar if attached */
   if( form->FToolBar ) {
      HBToolBar * tb = (HBToolBar *)form->FToolBar;
      GtkWidget * toolbar = gtk_toolbar_new();
      gtk_toolbar_set_style( GTK_TOOLBAR(toolbar), GTK_TOOLBAR_TEXT );
      gtk_toolbar_set_icon_size( GTK_TOOLBAR(toolbar), GTK_ICON_SIZE_SMALL_TOOLBAR );
      tb->FToolBarWidget = toolbar;

      for( int i = 0; i < tb->FBtnCount; i++ ) {
         if( tb->FBtnSeparator[i] ) {
            GtkToolItem * sep = gtk_separator_tool_item_new();
            gtk_toolbar_insert( GTK_TOOLBAR(toolbar), sep, -1 );
         } else {
            GtkToolItem * btn = gtk_tool_button_new( NULL, tb->FBtnTexts[i] );
            gtk_tool_item_set_tooltip_text( btn, tb->FBtnTooltips[i] );
            /* Store index in data for callback */
            g_object_set_data( G_OBJECT(btn), "btn_idx", GINT_TO_POINTER(i) );
            g_object_set_data( G_OBJECT(btn), "toolbar", tb );
            g_signal_connect( btn, "clicked", G_CALLBACK(on_toolbar_btn_clicked), tb );
            gtk_toolbar_insert( GTK_TOOLBAR(toolbar), btn, -1 );
         }
      }

      /* Apply deferred toolbar icons */
      if( tb->FIconCount > 0 ) {
         gtk_toolbar_set_style( GTK_TOOLBAR(toolbar), GTK_TOOLBAR_ICONS );
         HBToolBar_ApplyIcons( tb );
      }

      /* If palette exists, pack toolbar + palette in an hbox */
      if( s_palData && s_palData->notebook ) {
         GtkWidget * tbHBox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
         gtk_box_pack_start( GTK_BOX(tbHBox), toolbar, FALSE, FALSE, 0 );
         /* Vertical separator */
         GtkWidget * sep = gtk_separator_new( GTK_ORIENTATION_VERTICAL );
         gtk_box_pack_start( GTK_BOX(tbHBox), sep, FALSE, FALSE, 2 );
         gtk_box_pack_start( GTK_BOX(tbHBox), s_palData->notebook, TRUE, TRUE, 0 );
         gtk_box_pack_start( GTK_BOX(vbox), tbHBox, FALSE, FALSE, 0 );
         gtk_widget_show_all( tbHBox );
      } else {
         gtk_box_pack_start( GTK_BOX(vbox), toolbar, FALSE, FALSE, 0 );
         gtk_widget_show_all( toolbar );
      }

      form->FClientTop = 0; /* GTK handles layout via box, no manual offset needed */
   }

   /* Use GtkOverlay to layer the fixed container and the design overlay */
   GtkWidget * overlay = gtk_overlay_new();
   gtk_box_pack_start( GTK_BOX(vbox), overlay, TRUE, TRUE, 0 );
   gtk_widget_show( overlay );

   form->FFixed = gtk_fixed_new();
   gtk_container_add( GTK_CONTAINER(overlay), form->FFixed );
   gtk_widget_show( form->FFixed );

   HBForm_CreateAllChildren( form );

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

   gtk_widget_show( overlay );

   /* StatusBar at bottom */
   if( s_statusBar ) {
      gtk_box_pack_end( GTK_BOX(vbox), s_statusBar, FALSE, FALSE, 0 );
      gtk_widget_show( s_statusBar );
   }

   if( form->FCenter )
      gtk_window_set_position( GTK_WINDOW(form->FWindow), GTK_WIN_POS_CENTER );

   gtk_widget_show( form->FWindow );

   /* Grab focus for overlay in design mode */
   if( form->FDesignMode && form->FOverlay )
      gtk_widget_grab_focus( form->FOverlay );

   form->FRunning = 1;
   gtk_main();
}

/* Show() - create and show without entering gtk_main */
static void HBForm_Show( HBForm * form )
{
   EnsureGTK();

   form->FWindow = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(form->FWindow), form->base.FText );
   gtk_window_set_default_size( GTK_WINDOW(form->FWindow), form->base.FWidth, form->base.FHeight );
   gtk_window_set_resizable( GTK_WINDOW(form->FWindow),
      (form->FSizable && !form->FAppBar) ? TRUE : FALSE );
   g_signal_connect( form->FWindow, "destroy", G_CALLBACK(on_window_destroy), form );
   g_signal_connect( form->FWindow, "configure-event", G_CALLBACK(on_window_configure), form );

   /* Background color */
   {
      unsigned int clr = form->base.FClrPane;
      int r = clr & 0xFF, g = (clr >> 8) & 0xFF, b = (clr >> 16) & 0xFF;
      char css[128];
      snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
      GtkCssProvider * provider = gtk_css_provider_new();
      gtk_css_provider_load_from_data( provider, css, -1, NULL );
      GtkStyleContext * ctx = gtk_widget_get_style_context( form->FWindow );
      gtk_style_context_add_provider( ctx, GTK_STYLE_PROVIDER(provider),
         GTK_STYLE_PROVIDER_PRIORITY_APPLICATION );
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

   if( form->FCenter )
      gtk_window_set_position( GTK_WINDOW(form->FWindow), GTK_WIN_POS_CENTER );
   else
      gtk_window_move( GTK_WINDOW(form->FWindow), form->base.FLeft, form->base.FTop );

   gtk_widget_show( form->FWindow );

   if( form->FDesignMode && form->FOverlay )
      gtk_widget_grab_focus( form->FOverlay );

   form->FRunning = 1;
   /* No gtk_main() - shares the main window's loop */
}

static void HBForm_Close( HBForm * form )
{
   form->FRunning = 0;
   if( form->FWindow )
   {
      gtk_widget_destroy( form->FWindow );
      form->FWindow = NULL;
   }
}

static void HBForm_SetDesignMode( HBForm * form, int design )
{
   form->FDesignMode = design;
   HBForm_ClearSelection( form );
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
HB_FUNC( UI_FORMCLOSE )     { HBForm * p = GetForm(1); if( p ) HBForm_Close( p ); }
HB_FUNC( UI_FORMDESTROY )   { HBForm * p = GetForm(1); if( p ) { HBControl_ReleaseEvents(&p->base); RemoveControl(&p->base); free(p); } }
HB_FUNC( UI_FORMRESULT )    { HBForm * p = GetForm(1); hb_retni( p ? p->FModalResult : 0 ); }

/* --- Control creation --- */

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

/* --- Property access --- */

HB_FUNC( UI_SETPROP )
{
   HBControl * p = GetCtrl(1);
   const char * szProp = hb_parc(2);
   if( !p || !szProp ) return;

   if( strcasecmp( szProp, "cText" ) == 0 && HB_ISCHAR(3) )
   {
      HBControl_SetText( p, hb_parc(3) );
      if( p->FWidget )
      {
         if( GTK_IS_LABEL(p->FWidget) )
            gtk_label_set_text( GTK_LABEL(p->FWidget), p->FText );
         else if( GTK_IS_ENTRY(p->FWidget) )
            gtk_entry_set_text( GTK_ENTRY(p->FWidget), p->FText );
         else if( GTK_IS_BUTTON(p->FWidget) )
            gtk_button_set_label( GTK_BUTTON(p->FWidget), p->FText );
         else if( GTK_IS_FRAME(p->FWidget) )
            gtk_frame_set_label( GTK_FRAME(p->FWidget), p->FText );
         else if( p->FControlType == CT_FORM )
         {
            HBForm * pF = (HBForm *)p;
            if( pF->FWindow )
               gtk_window_set_title( GTK_WINDOW(pF->FWindow), p->FText );
         }
      }
   }
   else if( strcasecmp(szProp,"nLeft")==0 )   { p->FLeft = hb_parni(3); HBControl_UpdatePosition(p); }
   else if( strcasecmp(szProp,"nTop")==0 )    { p->FTop = hb_parni(3); HBControl_UpdatePosition(p); }
   else if( strcasecmp(szProp,"nWidth")==0 )  { p->FWidth = hb_parni(3); HBControl_UpdatePosition(p); }
   else if( strcasecmp(szProp,"nHeight")==0 ) { p->FHeight = hb_parni(3); HBControl_UpdatePosition(p); }
   else if( strcasecmp(szProp,"lVisible")==0 ) {
      p->FVisible = hb_parl(3);
      if( p->FWidget ) gtk_widget_set_visible( p->FWidget, p->FVisible );
   }
   else if( strcasecmp(szProp,"lEnabled")==0 ) {
      p->FEnabled = hb_parl(3);
      if( p->FWidget ) gtk_widget_set_sensitive( p->FWidget, p->FEnabled );
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
   else if( strcasecmp(szProp,"nClrPane")==0 )
   {
      p->FClrPane = (unsigned int)hb_parnint(3);
      if( p->FControlType == CT_FORM )
      {
         HBForm * pF = (HBForm *)p;
         if( pF->FWindow )
         {
            int r = p->FClrPane & 0xFF, g = (p->FClrPane >> 8) & 0xFF, b = (p->FClrPane >> 16) & 0xFF;
            char css[128];
            snprintf( css, sizeof(css), "window { background-color: #%02X%02X%02X; }", r, g, b );
            GtkCssProvider * provider = gtk_css_provider_new();
            gtk_css_provider_load_from_data( provider, css, -1, NULL );
            GtkStyleContext * ctx = gtk_widget_get_style_context( pF->FWindow );
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
   else if( strcasecmp(szProp,"nItemIndex")==0 && p->FControlType==CT_COMBOBOX )
      hb_retni( ((HBComboBox *)p)->FItemIndex );
   else if( strcasecmp(szProp,"nClrPane")==0 )   hb_retnint( (HB_MAXINT)p->FClrPane );
   else if( strcasecmp(szProp,"oFont")==0 )
   {
      /* Convert Pango format "Sans 12" to "Sans,12" */
      char szFont[128];
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
      char sf[128];
      const char * lastSpace = strrchr( p->FFontDesc, ' ' );
      if( lastSpace )
         snprintf( sf, sizeof(sf), "%.*s,%s", (int)(lastSpace - p->FFontDesc), p->FFontDesc, lastSpace + 1 );
      else
         snprintf( sf, sizeof(sf), "%s,12", p->FFontDesc );
      ADD_F("oFont",sf,"Appearance");
   }
   ADD_C("nClrPane",p->FClrPane,"Appearance");

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
         ADD_N("nItemIndex",((HBComboBox*)p)->FItemIndex,"Data");
         ADD_N("nItemCount",((HBComboBox*)p)->FItemCount,"Data"); break;
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
   HBToolBar * p = (HBToolBar *) calloc( 1, sizeof(HBToolBar) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TToolBar" );
   p->base.FControlType = CT_TOOLBAR;
   p->FBtnCount = 0;
   p->FToolBarWidget = NULL;
   memset( p->FBtnOnClick, 0, sizeof(p->FBtnOnClick) );
   memset( p->FBtnSeparator, 0, sizeof(p->FBtnSeparator) );
   KeepAlive( &p->base );
   if( pForm ) { pForm->FToolBar = &p->base; p->base.FCtrlParent = &pForm->base; }
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

   GtkWidget * menuItem = gtk_menu_item_new_with_mnemonic( hb_parc(2) );
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
      targetForm->FPendingControlType = nType;
      if( targetForm->FWindow )
      {
         GdkCursor * cursor = gdk_cursor_new_from_name(
            gdk_display_get_default(), "crosshair" );
         gdk_window_set_cursor( gtk_widget_get_window(targetForm->FWindow), cursor );
         if( cursor ) g_object_unref( cursor );
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
         HBForm_SelectControl( pForm, pCtrl, 0 );
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
      char libPath[1024];
      snprintf( libPath, sizeof(libPath), "%s/../resources/libscintilla.so", szPath );
      s_hScintilla = dlopen( libPath, RTLD_LAZY );
      if( fLog ) fprintf( fLog, "dlopen Scintilla '%s' => %p\n", libPath, s_hScintilla );
   }

   if( !s_hScintilla ) {
      /* Try resources/ in project root */
      char libPath[1024];
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
      char libPath[1024];
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
} CODEEDITOR;

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
   SciMsg( ed->sciWidget, SCI_SETTEXT, 0,
      (intptr_t)( ed->tabTexts[nNewTab] ? ed->tabTexts[nNewTab] : "" ) );

   SciMsg( ed->sciWidget, SCI_EMPTYUNDOBUFFER, 0, 0 );
   UpdateHarbourFolding( ed->sciWidget );
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

/* Scintilla notification handler via GtkWidget "sci-notify" signal */
static void on_sci_notify( GtkWidget * sci, gint id, gpointer scnPtr, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   /* SCNotification is passed as a struct pointer.
      We cast to access the notification code and fields. */
   struct SCNotification {
      unsigned int hwndFrom; unsigned int idFrom; unsigned int code;
      int position; int ch; int modifiers; int modificationType;
      const char * text; int length; int linesAdded;
      int message; uintptr_t wParam; intptr_t lParam;
      int line; int foldLevelNow; int foldLevelPrev; int margin;
   } * scn = (struct SCNotification *) scnPtr;

   if( !ed || !scn ) return;

   if( scn->code == SCN_MARGINCLICK ) {
      int line = (int) SciMsg( sci, SCI_LINEFROMPOSITION, scn->position, 0 );
      SciMsg( sci, SCI_TOGGLEFOLD, line, 0 );
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
   }

   if( scn->code == SCN_UPDATEUI ) {
      UpdateStatusBar( ed );
   }

   if( scn->code == SCN_MODIFIED ) {
      if( scn->linesAdded != 0 && (scn->modificationType & (0x01|0x02)) ) {
         static int s_inFoldUpdate = 0;
         if( !s_inFoldUpdate ) {
            s_inFoldUpdate = 1;
            UpdateHarbourFolding( sci );
            s_inFoldUpdate = 0;
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

      GdkPixbuf * scaled = gdk_pixbuf_scale_simple( tb->FIconImages[imgIdx], 28, 28, GDK_INTERP_BILINEAR );
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

   /* Apply icons to palette buttons across all tabs */
   for( int t = 0; t < pd->nTabCount; t++ )
   {
      GtkWidget * box = pd->tabBoxes[t];
      if( !box ) continue;

      GList * children = gtk_container_get_children( GTK_CONTAINER(box) );
      int btnIdx = 0;
      for( GList * l = children; l != NULL; l = l->next )
      {
         GtkWidget * btn = GTK_WIDGET( l->data );
         if( !GTK_IS_BUTTON(btn) ) continue;

         PaletteTab * pt = &pd->tabs[t];
         if( btnIdx >= pt->nBtnCount ) break;

         int nCtrlType = pt->btns[btnIdx].nControlType;
         if( nCtrlType > 0 && nCtrlType <= nIcons )
         {
            GdkPixbuf * scaled = gdk_pixbuf_scale_simple( icons[nCtrlType - 1], 28, 28, GDK_INTERP_BILINEAR );
            GtkWidget * img = gtk_image_new_from_pixbuf( scaled );
            g_object_unref( scaled );

            /* Remove text label, set image */
            gtk_button_set_label( GTK_BUTTON(btn), NULL );
            gtk_button_set_image( GTK_BUTTON(btn), img );
            gtk_button_set_always_show_image( GTK_BUTTON(btn), TRUE );
         }
         btnIdx++;
      }
      g_list_free( children );
   }

   /* Free icon pixbufs */
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

   /* Release child objects */
   for( int i = 0; i < pForm->base.FChildCount; i++ )
   {
      RemoveControl( pForm->base.FChildren[i] );
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
      SciMsg( ed->sciWidget, SCI_SETTEXT, 0, (intptr_t) ed->tabTexts[nTab] );
      SciMsg( ed->sciWidget, SCI_EMPTYUNDOBUFFER, 0, 0 );
      UpdateHarbourFolding( ed->sciWidget );
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
      char * nl = strchr( found, '\n' );
      if( nl ) { nl = strchr( nl + 1, '\n' ); if( nl ) offset = (int)(nl - fullText) + 1; }

      SciMsg( ed->sciWidget, SCI_GOTOPOS, offset, 0 );
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

/* ======================================================================
 * Platform dialogs & utilities (GTK3 equivalents of MAC_*)
 * ====================================================================== */

/* GTK_ShellExec( cCommand ) --> cOutput */
HB_FUNC( GTK_SHELLEXEC )
{
   if( !HB_ISCHAR(1) ) { hb_retc(""); return; }
   char * output = NULL;
   GError * err = NULL;
   gint exitStatus = 0;
   char * argv[] = { "/bin/bash", "-c", (char*)hb_parc(1), NULL };
   g_spawn_sync( NULL, argv, NULL,
      G_SPAWN_SEARCH_PATH, NULL, NULL,
      &output, NULL, &exitStatus, &err );
   hb_retc( output ? output : "" );
   if( output ) g_free( output );
   if( err ) g_error_free( err );
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
         gtk_message_dialog_set_image( GTK_MESSAGE_DIALOG(dialog), img );
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

HB_FUNC( GTK_SETDARKMODE )
{
   EnsureGTK();
   int bDark = hb_parl(1);
   GtkSettings * settings = gtk_settings_get_default();
   if( settings )
      g_object_set( settings, "gtk-application-prefer-dark-theme", (gboolean)bDark, NULL );
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

/* Provide pointer to s_dbgState for the debug panel toolbar buttons */
static int * _dbg_state_ptr(void) { return &s_dbgState; }
static int           s_dbgLine = 0;
static int           s_dbgStepDepth = 0;
static char          s_dbgModule[256] = "";
static GtkWidget *   s_dbgOutputTV = NULL;
static PHB_ITEM      s_dbgOnPause = NULL;

/* Breakpoints */
#define DBG_MAX_BP 64
typedef struct { char module[256]; int line; } DBGBP;
static DBGBP s_breakpoints[DBG_MAX_BP];
static int   s_nBreakpoints = 0;

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
HB_FUNC( IDE_DEBUGGO )       { if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_RUNNING; }
HB_FUNC( IDE_DEBUGSTEP )     { if( s_dbgState == DBG_PAUSED ) s_dbgState = DBG_STEPPING; }
HB_FUNC( IDE_DEBUGSTEPOVER ) {
   if( s_dbgState == DBG_PAUSED ) {
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

