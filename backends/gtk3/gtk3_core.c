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

/* Control types - must match original */
#define CT_FORM       0
#define CT_LABEL      1
#define CT_EDIT       2
#define CT_BUTTON     3
#define CT_CHECKBOX   4
#define CT_COMBOBOX   5
#define CT_GROUPBOX   6

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
   int          FModalResult;
   int          FRunning;
   int          FDesignMode;
   HBControl *  FSelected[MAX_CHILDREN];
   int          FSelCount;
   int          FDragging, FResizing;
   int          FResizeHandle;
   int          FDragStartX, FDragStartY;
   PHB_ITEM     FOnSelChange;
   GtkWidget *  FOverlay;    /* Drawing area for selection handles */
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
      hb_vmPushNumInt( (HB_PTRUINT) p );
      hb_vmSend( 1 );
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
         gtk_main_quit();
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
      hb_vmPushEvalSym();
      hb_vmPush( form->FOnSelChange );
      hb_vmPushNumInt( form->FSelCount > 0 ? (HB_PTRUINT) form->FSelected[0] : 0 );
      hb_vmSend( 1 );
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

static gboolean on_overlay_button_release( GtkWidget * widget, GdkEventButton * event, gpointer data )
{
   HBForm * form = (HBForm *)data;
   if( !form->FDesignMode ) return FALSE;

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
   memset( form->FSelected, 0, sizeof(form->FSelected) );
   form->base.FWidth = 470; form->base.FHeight = 400;
   strcpy( form->base.FText, "New Form" );
   form->base.FClrPane = 0x00F0F0F0;
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
   gtk_window_set_resizable( GTK_WINDOW(form->FWindow), FALSE );
   g_signal_connect( form->FWindow, "destroy", G_CALLBACK(on_window_destroy), form );

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

   /* Use GtkOverlay to layer the fixed container and the design overlay */
   GtkWidget * overlay = gtk_overlay_new();
   gtk_container_add( GTK_CONTAINER(form->FWindow), overlay );

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

   if( form->FCenter )
      gtk_window_set_position( GTK_WINDOW(form->FWindow), GTK_WIN_POS_CENTER );

   gtk_widget_show( form->FWindow );

   /* Grab focus for overlay in design mode */
   if( form->FDesignMode && form->FOverlay )
      gtk_widget_grab_focus( form->FOverlay );

   form->FRunning = 1;
   gtk_main();
   form->FRunning = 0;
}

static void HBForm_Close( HBForm * form )
{
   form->FRunning = 0;
   if( form->FWindow )
   {
      gtk_widget_destroy( form->FWindow );
      form->FWindow = NULL;
      gtk_main_quit();
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

