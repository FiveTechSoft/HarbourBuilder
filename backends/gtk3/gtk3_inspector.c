/*
 * gtk3_inspector.c - Property inspector using GTK3 TreeView
 * Replaces the Win32 ListView-based inspector for Linux.
 *
 * Exports: INS_Create, INS_RefreshWithData, INS_BringToFront, INS_Destroy
 *          _INSGETDATA, _INSSETDATA
 */

#include <gtk/gtk.h>
#include <hbapi.h>
#include <hbapiitm.h>
#include <hbvm.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>

/* Defined in gtk3_core.c */
extern void EnsureGTK( void );

#define MAX_ROWS 64

/* ======================================================================
 * Data model
 * ====================================================================== */

typedef struct {
   char szName[32];
   char szValue[256];
   char szCategory[32];
   char cType;       /* S=string, N=number, L=logical, C=color, F=font */
   int  bIsCat;      /* category header */
   int  bCollapsed;
   int  bVisible;
} IROW;

typedef struct {
   GtkWidget *  window;
   GtkWidget *  treeView;
   GtkListStore * store;
   HB_PTRUINT   hCtrl;       /* currently inspected control handle */
   IROW         rows[MAX_ROWS];
   int          nRows;
   int          map[MAX_ROWS]; /* visible row -> rows index */
   int          nVisible;
} INSDATA;

/* Columns in the GtkListStore */
enum {
   COL_NAME,       /* string */
   COL_VALUE,      /* string */
   COL_EDITABLE,   /* boolean - can this row be edited? */
   COL_WEIGHT,     /* int (Pango weight) */
   COL_BG_COLOR,   /* string (background color for row) */
   COL_BG_SET,     /* boolean (whether to use bg color) */
   COL_REAL_IDX,   /* int - index into INSDATA.rows[] */
   NUM_COLS
};

/* ======================================================================
 * Build rows from Harbour property array
 * ====================================================================== */

static void InsBuildRows( INSDATA * d, PHB_ITEM pArray )
{
   HB_SIZE nLen, i;
   char szCats[16][32];
   int nCats = 0, j;
   int bNew;

   d->nRows = 0;
   if( !pArray || hb_arrayLen(pArray) == 0 ) return;

   nLen = hb_arrayLen( pArray );

   /* Collect categories */
   for( i = 1; i <= nLen && nCats < 16; i++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
      const char * c = hb_arrayGetCPtr( pRow, 3 );
      bNew = 1;
      for( j = 0; j < nCats; j++ )
         if( strcasecmp(szCats[j], c) == 0 ) { bNew = 0; break; }
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
      d->rows[d->nRows].bIsCat = 1;
      d->rows[d->nRows].bCollapsed = 0;
      d->rows[d->nRows].bVisible = 1;
      d->nRows++;

      for( i = 1; i <= nLen && d->nRows < MAX_ROWS; i++ )
      {
         PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
         if( strcasecmp( hb_arrayGetCPtr(pRow,3), szCats[j] ) != 0 ) continue;

         strncpy( d->rows[d->nRows].szName, hb_arrayGetCPtr(pRow,1), 31 );
         strncpy( d->rows[d->nRows].szCategory, hb_arrayGetCPtr(pRow,3), 31 );
         d->rows[d->nRows].cType = hb_arrayGetCPtr(pRow,4)[0];
         d->rows[d->nRows].bIsCat = 0;
         d->rows[d->nRows].bCollapsed = 0;
         d->rows[d->nRows].bVisible = 1;

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
 * Rebuild the GtkListStore from current row data
 * ====================================================================== */

static void InsRebuildStore( INSDATA * d )
{
   gtk_list_store_clear( d->store );

   /* Rebuild visible map */
   d->nVisible = 0;
   for( int i = 0; i < d->nRows; i++ )
   {
      if( d->rows[i].bVisible || d->rows[i].bIsCat )
         d->map[d->nVisible++] = i;
   }

   for( int i = 0; i < d->nVisible; i++ )
   {
      int nReal = d->map[i];
      GtkTreeIter iter;
      gtk_list_store_append( d->store, &iter );

      if( d->rows[nReal].bIsCat )
      {
         char catName[64];
         snprintf( catName, sizeof(catName), "%c  %s",
            d->rows[nReal].bCollapsed ? '+' : '-',
            d->rows[nReal].szName );

         gtk_list_store_set( d->store, &iter,
            COL_NAME, catName,
            COL_VALUE, "",
            COL_EDITABLE, FALSE,
            COL_WEIGHT, PANGO_WEIGHT_BOLD,
            COL_BG_COLOR, "#E6E6E6",
            COL_BG_SET, TRUE,
            COL_REAL_IDX, nReal,
            -1 );
      }
      else
      {
         char dispName[72];
         snprintf( dispName, sizeof(dispName), "    %s", d->rows[nReal].szName );

         /* Color swatch for color properties */
         gboolean hasBg = FALSE;
         char bgColor[16] = "#FFFFFF";
         if( d->rows[nReal].cType == 'C' )
         {
            unsigned int clr = (unsigned int) strtoul( d->rows[nReal].szValue, NULL, 10 );
            int r = clr & 0xFF, g = (clr >> 8) & 0xFF, b = (clr >> 16) & 0xFF;
            snprintf( bgColor, sizeof(bgColor), "#%02X%02X%02X", r, g, b );
            hasBg = TRUE;
         }
         else if( i % 2 == 1 )
         {
            strcpy( bgColor, "#F8F8F8" );
            hasBg = TRUE;
         }

         gtk_list_store_set( d->store, &iter,
            COL_NAME, dispName,
            COL_VALUE, d->rows[nReal].szValue,
            COL_EDITABLE, (d->rows[nReal].cType != 'C' && d->rows[nReal].cType != 'F'),
            COL_WEIGHT, PANGO_WEIGHT_NORMAL,
            COL_BG_COLOR, hasBg ? bgColor : NULL,
            COL_BG_SET, hasBg,
            COL_REAL_IDX, nReal,
            -1 );
      }
   }
}

/* ======================================================================
 * Apply a value to the inspected control via UI_SetProp
 * ====================================================================== */

static void InsApplyValue( INSDATA * d, int nReal )
{
   PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
   if( !pDyn ) return;

   hb_vmPushDynSym( pDyn ); hb_vmPushNil();
   hb_vmPushNumInt( d->hCtrl );
   hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );

   if( d->rows[nReal].cType == 'S' || d->rows[nReal].cType == 'F' )
      hb_vmPushString( d->rows[nReal].szValue, strlen(d->rows[nReal].szValue) );
   else if( d->rows[nReal].cType == 'N' )
      hb_vmPushInteger( atoi(d->rows[nReal].szValue) );
   else if( d->rows[nReal].cType == 'L' )
      hb_vmPushLogical( strcasecmp(d->rows[nReal].szValue,".T.")==0 );
   else if( d->rows[nReal].cType == 'C' )
      hb_vmPushNumInt( (HB_MAXINT) strtoul(d->rows[nReal].szValue, NULL, 10) );
   else
      hb_vmPushNil();

   hb_vmDo( 3 );
}

/* ======================================================================
 * Callbacks
 * ====================================================================== */

/* Value cell edited */
static void on_value_edited( GtkCellRendererText * renderer,
   gchar * path, gchar * new_text, gpointer data )
{
   INSDATA * d = (INSDATA *)data;
   GtkTreeIter iter;
   if( !gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL(d->store), &iter, path ) )
      return;

   int nReal;
   gtk_tree_model_get( GTK_TREE_MODEL(d->store), &iter, COL_REAL_IDX, &nReal, -1 );

   if( nReal < 0 || nReal >= d->nRows || d->rows[nReal].bIsCat ) return;

   strncpy( d->rows[nReal].szValue, new_text, sizeof(d->rows[0].szValue) - 1 );
   InsApplyValue( d, nReal );
   InsRebuildStore( d );
}

/* Row activated (double-click) - toggle category or open picker */
static void on_row_activated( GtkTreeView * treeView, GtkTreePath * path,
   GtkTreeViewColumn * column, gpointer data )
{
   INSDATA * d = (INSDATA *)data;
   GtkTreeIter iter;
   if( !gtk_tree_model_get_iter( GTK_TREE_MODEL(d->store), &iter, path ) )
      return;

   int nReal;
   gtk_tree_model_get( GTK_TREE_MODEL(d->store), &iter, COL_REAL_IDX, &nReal, -1 );

   if( nReal < 0 || nReal >= d->nRows ) return;

   /* Category row: toggle collapse */
   if( d->rows[nReal].bIsCat )
   {
      d->rows[nReal].bCollapsed = !d->rows[nReal].bCollapsed;
      for( int k = nReal + 1; k < d->nRows && !d->rows[k].bIsCat; k++ )
         d->rows[k].bVisible = !d->rows[nReal].bCollapsed;
      InsRebuildStore( d );
      return;
   }

   /* Color property: open color chooser */
   if( d->rows[nReal].cType == 'C' )
   {
      unsigned int clr = (unsigned int) strtoul( d->rows[nReal].szValue, NULL, 10 );
      GdkRGBA initial;
      initial.red   = (clr & 0xFF) / 255.0;
      initial.green  = ((clr >> 8) & 0xFF) / 255.0;
      initial.blue   = ((clr >> 16) & 0xFF) / 255.0;
      initial.alpha  = 1.0;

      GtkWidget * dialog = gtk_color_chooser_dialog_new( "Choose Color", GTK_WINDOW(d->window) );
      gtk_color_chooser_set_rgba( GTK_COLOR_CHOOSER(dialog), &initial );

      if( gtk_dialog_run( GTK_DIALOG(dialog) ) == GTK_RESPONSE_OK )
      {
         GdkRGBA chosen;
         gtk_color_chooser_get_rgba( GTK_COLOR_CHOOSER(dialog), &chosen );
         unsigned int r = (unsigned int)(chosen.red * 255.0 + 0.5);
         unsigned int g = (unsigned int)(chosen.green * 255.0 + 0.5);
         unsigned int b = (unsigned int)(chosen.blue * 255.0 + 0.5);
         unsigned int newClr = r | (g << 8) | (b << 16);
         sprintf( d->rows[nReal].szValue, "%u", newClr );
         InsApplyValue( d, nReal );
         InsRebuildStore( d );
      }
      gtk_widget_destroy( dialog );
      return;
   }

   /* Font property: open font chooser */
   if( d->rows[nReal].cType == 'F' )
   {
      /* Convert "FontName,Size" to Pango format "FontName Size" */
      char pangoDesc[128];
      char szFace[64] = "Sans"; int nSize = 12;
      const char * val = d->rows[nReal].szValue;
      const char * comma = strchr( val, ',' );
      if( comma ) {
         int len = (int)(comma - val); if( len > 63 ) len = 63;
         memcpy( szFace, val, len ); szFace[len] = 0;
         nSize = atoi( comma + 1 );
      } else strncpy( szFace, val, 63 );
      if( nSize <= 0 ) nSize = 12;
      snprintf( pangoDesc, sizeof(pangoDesc), "%s %d", szFace, nSize );

      GtkWidget * dialog = gtk_font_chooser_dialog_new( "Choose Font", GTK_WINDOW(d->window) );
      gtk_font_chooser_set_font( GTK_FONT_CHOOSER(dialog), pangoDesc );

      if( gtk_dialog_run( GTK_DIALOG(dialog) ) == GTK_RESPONSE_OK )
      {
         PangoFontDescription * fd = gtk_font_chooser_get_font_desc( GTK_FONT_CHOOSER(dialog) );
         if( fd )
         {
            const char * family = pango_font_description_get_family( fd );
            int size = pango_font_description_get_size( fd ) / PANGO_SCALE;
            snprintf( d->rows[nReal].szValue, sizeof(d->rows[0].szValue), "%s,%d", family, size );
            InsApplyValue( d, nReal );
            pango_font_description_free( fd );
         }
         InsRebuildStore( d );
      }
      gtk_widget_destroy( dialog );
      return;
   }
}

/* Prevent window close from destroying it; just hide */
static gboolean on_inspector_delete( GtkWidget * widget, GdkEvent * event, gpointer data )
{
   gtk_widget_hide( widget );
   return TRUE;  /* prevent destroy */
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
   EnsureGTK();

   INSDATA * d = (INSDATA *) calloc( 1, sizeof(INSDATA) );

   /* Create window */
   d->window = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(d->window), "Inspector" );
   gtk_window_set_default_size( GTK_WINDOW(d->window), 320, 450 );
   gtk_window_set_type_hint( GTK_WINDOW(d->window), GDK_WINDOW_TYPE_HINT_UTILITY );
   g_signal_connect( d->window, "delete-event", G_CALLBACK(on_inspector_delete), d );

   /* List store */
   d->store = gtk_list_store_new( NUM_COLS,
      G_TYPE_STRING,   /* COL_NAME */
      G_TYPE_STRING,   /* COL_VALUE */
      G_TYPE_BOOLEAN,  /* COL_EDITABLE */
      G_TYPE_INT,      /* COL_WEIGHT */
      G_TYPE_STRING,   /* COL_BG_COLOR */
      G_TYPE_BOOLEAN,  /* COL_BG_SET */
      G_TYPE_INT       /* COL_REAL_IDX */
   );

   /* Tree view */
   d->treeView = gtk_tree_view_new_with_model( GTK_TREE_MODEL(d->store) );
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(d->treeView), TRUE );

   /* Name column */
   {
      GtkCellRenderer * renderer = gtk_cell_renderer_text_new();
      GtkTreeViewColumn * col = gtk_tree_view_column_new_with_attributes(
         "Property", renderer,
         "text", COL_NAME,
         "weight", COL_WEIGHT,
         "cell-background", COL_BG_COLOR,
         "cell-background-set", COL_BG_SET,
         NULL );
      gtk_tree_view_column_set_resizable( col, TRUE );
      gtk_tree_view_column_set_min_width( col, 120 );
      gtk_tree_view_append_column( GTK_TREE_VIEW(d->treeView), col );
   }

   /* Value column */
   {
      GtkCellRenderer * renderer = gtk_cell_renderer_text_new();
      GtkTreeViewColumn * col = gtk_tree_view_column_new_with_attributes(
         "Value", renderer,
         "text", COL_VALUE,
         "editable", COL_EDITABLE,
         "cell-background", COL_BG_COLOR,
         "cell-background-set", COL_BG_SET,
         NULL );
      gtk_tree_view_column_set_resizable( col, TRUE );
      gtk_tree_view_column_set_min_width( col, 100 );
      gtk_tree_view_append_column( GTK_TREE_VIEW(d->treeView), col );

      g_signal_connect( renderer, "edited", G_CALLBACK(on_value_edited), d );
   }

   /* Double-click for category collapse and picker dialogs */
   g_signal_connect( d->treeView, "row-activated", G_CALLBACK(on_row_activated), d );

   /* Scroll view */
   GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_container_add( GTK_CONTAINER(scroll), d->treeView );
   gtk_container_add( GTK_CONTAINER(d->window), scroll );

   gtk_widget_show_all( d->window );

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
      d->nRows = 0; d->nVisible = 0;
      gtk_list_store_clear( d->store );
      gtk_window_set_title( GTK_WINDOW(d->window), "Inspector" );
      return;
   }

   /* Title from first prop (ClassName) */
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, 1 );
      const char * cls = hb_arrayGetCPtr( pRow, 2 );
      char title[128];
      snprintf( title, sizeof(title), "Inspector: %s", cls ? cls : "" );
      gtk_window_set_title( GTK_WINDOW(d->window), title );
   }

   InsBuildRows( d, pArray );
   InsRebuildStore( d );
}

/* ======================================================================
 * INS_BringToFront( hInsData )
 * ====================================================================== */

HB_FUNC( INS_BRINGTOFRONT )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d && d->window )
   {
      gtk_widget_show( d->window );
      gtk_window_present( GTK_WINDOW(d->window) );
   }
}

/* ======================================================================
 * INS_Destroy( hInsData )
 * ====================================================================== */

HB_FUNC( INS_DESTROY )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   if( d->window ) gtk_widget_destroy( d->window );
   free( d );
}
