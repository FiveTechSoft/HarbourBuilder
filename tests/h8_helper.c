/* h8_helper.c - GTK widget-state probes for the H8 combo/listbox selection test.
 * Finds the one combo and one listbox in the test form by walking toplevels,
 * so it needs no gtk3_core internals. */
#include <gtk/gtk.h>
#include <hbapi.h>
#include <hbapiitm.h>
#include <hbvm.h>

static GtkWidget * g_combo = NULL, * g_tree = NULL;

static void walk( GtkWidget * w )
{
   if( GTK_IS_COMBO_BOX_TEXT( w ) && ! g_combo ) g_combo = w;
   if( GTK_IS_TREE_VIEW( w ) && ! g_tree ) g_tree = w;
   if( GTK_IS_CONTAINER( w ) )
   {
      GList * l, * ch = gtk_container_get_children( GTK_CONTAINER( w ) );
      for( l = ch; l; l = l->next ) walk( (GtkWidget *) l->data );
      g_list_free( ch );
   }
}

static void locate( void )
{
   GList * l, * tops;
   if( g_combo && g_tree ) return;
   g_combo = NULL; g_tree = NULL;
   tops = gtk_window_list_toplevels();
   for( l = tops; l && ( ! g_combo || ! g_tree ); l = l->next )
      walk( (GtkWidget *) l->data );
   g_list_free( tops );
}

HB_FUNC( H8_COMBOGETACTIVE )   /* 0-based active row, -1 = none */
{
   locate();
   hb_retni( g_combo ? gtk_combo_box_get_active( GTK_COMBO_BOX( g_combo ) ) : -99 );
}

HB_FUNC( H8_COMBOSETACTIVE0 )  /* direct widget change: only the on_combo_changed callback can update FItemIndex */
{
   locate();
   if( g_combo ) gtk_combo_box_set_active( GTK_COMBO_BOX( g_combo ), hb_parni(1) );
   hb_retl( g_combo != NULL );
}

HB_FUNC( H8_LISTSELROW )       /* 0-based selected row, -1 = none */
{
   GtkTreeSelection * sel; GList * rows; int row = -1;
   locate();
   if( ! g_tree ) { hb_retni( -99 ); return; }
   sel = gtk_tree_view_get_selection( GTK_TREE_VIEW( g_tree ) );
   rows = gtk_tree_selection_get_selected_rows( sel, NULL );
   if( rows )
   {
      gint * idx = gtk_tree_path_get_indices( (GtkTreePath *) rows->data );
      if( idx ) row = idx[0];
      g_list_free_full( rows, (GDestroyNotify) gtk_tree_path_free );
   }
   hb_retni( row );
}

static gboolean fire_block( gpointer data )
{
   PHB_ITEM b = (PHB_ITEM) data;
   hb_vmEvalBlock( b );
   hb_itemRelease( b );
   return G_SOURCE_REMOVE;
}

HB_FUNC( H8_RUNAFTER )  /* ms, codeblock */
{
   if( HB_ISNUM(1) && HB_ISBLOCK(2) )
      g_timeout_add( (guint) hb_parni(1), fire_block, (gpointer) hb_itemNew( hb_param(2, HB_IT_BLOCK ) ) );
   hb_ret();
}

HB_FUNC( H8_QUIT ) { gtk_main_quit(); hb_ret(); }
