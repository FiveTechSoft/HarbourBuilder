/*
 * gtk3_inspector.c - Property inspector using GTK3 TreeView
 * Replaces the Win32 ListView-based inspector for Linux.
 *
 * Exports: INS_Create, INS_RefreshWithData, INS_BringToFront, INS_Destroy
 *          _INSGETDATA, _INSSETDATA
 */

#include <gtk/gtk.h>

/* Avoid HB_DEPRECATED macro clash between harfbuzz and Harbour */
#undef HB_DEPRECATED

#include <hbapi.h>
#include <hbapiitm.h>
#include <hbvm.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* From gtk3_core.c */
extern int GTK_IsDark(void);
#include <strings.h>

/* Defined in gtk3_core.c */
extern void EnsureGTK( void );

#define MAX_ROWS 64

/* ======================================================================
 * Data model
 * ====================================================================== */

typedef struct {
   char szName[32];
   char szValue[4096];
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
   HB_PTRUINT   hFormCtrl;   /* form handle for combo enumeration */
   IROW         rows[MAX_ROWS];
   int          nRows;
   int          map[MAX_ROWS]; /* visible row -> rows index */
   int          nVisible;
   GtkWidget *  combo;       /* control selection combo (GtkComboBoxText) */
   PHB_ITEM     pOnComboSel; /* callback for combo selection change */
   /* Properties/Events tabs */
   GtkWidget *  tabWidget;   /* GtkNotebook for Properties/Events */
   int          nTab;        /* 0 = Properties, 1 = Events */
   /* Cached property rows (saved when switching to Events tab) */
   IROW         propRows[MAX_ROWS];
   int          nPropRows;
   int          propMap[MAX_ROWS];
   int          nPropVisible;
   /* Events tab */
   IROW         evRows[MAX_ROWS];
   int          nEvRows;
   int          evMap[MAX_ROWS];
   int          nEvVisible;
   /* Callbacks */
   PHB_ITEM     pOnEventDblClick;  /* double-click on event row */
   PHB_ITEM     pOnPropChanged;    /* after property edit (two-way sync) */
   /* Browse column editing */
   int          nBrowseCol;  /* -1 = not editing column, >= 0 = column index */
   /* TFolderPage view: -1 = normal, >= 0 = showing page N of folder in hCtrl */
   int          nFolderPage;
   /* Debug mode */
   int          bDebugMode;
   IROW         dbgLocalsRows[MAX_ROWS];
   int          nDbgLocalsRows;
   int          dbgLocalsMap[MAX_ROWS];
   int          nDbgLocalsVisible;
   IROW         dbgStackRows[MAX_ROWS];
   int          nDbgStackRows;
   int          dbgStackMap[MAX_ROWS];
   int          nDbgStackVisible;
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
 * Enum lookup table: numeric property name -> literal value array
 * Mirrors the s_enums[] table in the Windows inspector.
 * ====================================================================== */

typedef struct { const char * szPropName; const char ** aValues; int nCount; } ENUMDEF;

static const char * s_borderStyle[]  = { "bsNone", "bsSingle", "bsSizeable", "bsDialog", "bsToolWindow", "bsSizeToolWin" };
static const char * s_borderIcons[]  = { "biNone", "biSystemMenu", "biMinimize", "biSystemMenu+biMinimize",
                                          "biMaximize", "biSystemMenu+biMaximize", "biMinimize+biMaximize", "biAll" };
static const char * s_position[]     = { "poDesigned", "poCenter", "poCenterScreen" };
static const char * s_windowState[]  = { "wsNormal", "wsMinimized", "wsMaximized" };
static const char * s_formStyle[]    = { "fsNormal", "fsStayOnTop" };
static const char * s_cursor[]       = { "crDefault", "crArrow", "crCross", "crIBeam", "crHand",
                                          "crHelp", "crNo", "crWait", "crSizeAll" };
static const char * s_controlAlign[] = { "alNone", "alTop", "alBottom", "alLeft", "alRight", "alClient" };
static const char * s_bevelStyle[]   = { "bsLowered", "bsRaised" };
static const char * s_scrollBars[]   = { "ssNone", "ssVertical", "ssHorizontal", "ssBoth" };
static const char * s_viewStyle[]    = { "vsIcon", "vsList", "vsReport", "vsSmallIcon" };
static const char * s_alignment[]    = { "taLeftJustify", "taCenter", "taRightJustify" };

static ENUMDEF s_enums[] = {
   { "nBorderStyle",  s_borderStyle,  6 },
   { "nBorderIcons",  s_borderIcons,  8 },
   { "nPosition",     s_position,     3 },
   { "nWindowState",  s_windowState,  3 },
   { "nFormStyle",    s_formStyle,    2 },
   { "nCursor",       s_cursor,       9 },
   { "nControlAlign", s_controlAlign, 6 },
   { "nBevelStyle",   s_bevelStyle,   2 },
   { "nScrollBars",   s_scrollBars,   4 },
   { "nViewStyle",    s_viewStyle,    4 },
   { "nAlign",        s_alignment,    3 },
   { NULL, NULL, 0 }
};

static ENUMDEF * InsGetEnum( const char * szName )
{
   int i;
   for( i = 0; s_enums[i].szPropName; i++ )
      if( strcasecmp( szName, s_enums[i].szPropName ) == 0 )
         return &s_enums[i];
   return NULL;
}

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
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), sizeof(d->rows[0].szValue)-1 );
         else if( d->rows[d->nRows].cType == 'N' )
            sprintf( d->rows[d->nRows].szValue, "%d", hb_arrayGetNI(pRow,2) );
         else if( d->rows[d->nRows].cType == 'L' )
            strcpy( d->rows[d->nRows].szValue, hb_arrayGetL(pRow,2) ? ".T." : ".F." );
         else if( d->rows[d->nRows].cType == 'C' )
            sprintf( d->rows[d->nRows].szValue, "%u", (unsigned) hb_arrayGetNInt(pRow,2) );
         else if( d->rows[d->nRows].cType == 'F' )
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), sizeof(d->rows[0].szValue)-1 );
         else if( d->rows[d->nRows].cType == 'A' )
         {
            /* Store raw pipe-separated value; InsRebuildStore shows "(N items)" */
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), sizeof(d->rows[0].szValue)-1 );
         }
         else if( d->rows[d->nRows].cType == 'M' )
         {
            strncpy( d->rows[d->nRows].szValue, hb_arrayGetCPtr(pRow,2), sizeof(d->rows[0].szValue)-1 );
         }

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
            COL_BG_COLOR, GTK_IsDark() ? "#3C3C3C" : "#E6E6E6",
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
            strcpy( bgColor, GTK_IsDark() ? "#333333" : "#F8F8F8" );
            hasBg = TRUE;
         }

         /* Resolve display value: enum literal, array count, or raw string */
         const char * dispValue = d->rows[nReal].szValue;
         char arrayDisp[32];
         char enumDisp[64];
         ENUMDEF * pEnumRow = NULL;
         if( d->rows[nReal].cType == 'A' )
         {
            const char * raw = d->rows[nReal].szValue;
            int nItems = 0;
            if( raw[0] ) { nItems = 1; for( const char * p = raw; *p; p++ ) if( *p == '|' ) nItems++; }
            snprintf( arrayDisp, sizeof(arrayDisp), "(%d items)  ...", nItems );
            dispValue = arrayDisp;
         }
         else if( d->rows[nReal].cType == 'M' )
         {
            const char * raw = d->rows[nReal].szValue;
            int nNodes = 0;
            if( raw[0] ) { nNodes = 1; for( const char * p = raw; *p; p++ ) if( *p == '|' ) nNodes++; }
            snprintf( arrayDisp, sizeof(arrayDisp), "(%d nodes)  ...", nNodes );
            dispValue = arrayDisp;
         }
         else if( d->rows[nReal].cType == 'N' )
         {
            pEnumRow = InsGetEnum( d->rows[nReal].szName );
            if( pEnumRow )
            {
               int idx = atoi( d->rows[nReal].szValue );
               if( idx >= 0 && idx < pEnumRow->nCount )
               {
                  strncpy( enumDisp, pEnumRow->aValues[idx], sizeof(enumDisp) - 1 );
                  enumDisp[sizeof(enumDisp) - 1] = 0;
                  dispValue = enumDisp;
               }
            }
         }

         /* Enum 'N' properties are not inline-editable (no dropdown yet) */
         gboolean editable = (d->nTab == 0) &&
            (d->rows[nReal].cType != 'C' && d->rows[nReal].cType != 'F' &&
             d->rows[nReal].cType != 'A' && d->rows[nReal].cType != 'M' &&
             !(d->rows[nReal].cType == 'N' && pEnumRow != NULL));

         gtk_list_store_set( d->store, &iter,
            COL_NAME, dispName,
            COL_VALUE, dispValue,
            COL_EDITABLE, editable,
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
   /* If editing a browse column, use UI_BrowseSetColProp instead of UI_SetProp */
   if( d->nBrowseCol >= 0 )
   {
      PHB_DYNS pDyn = hb_dynsymFindName( "UI_BROWSESETCOLPROP" );
      if( !pDyn ) return;
      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushInteger( d->nBrowseCol );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );
      if( d->rows[nReal].cType == 'N' )
         hb_vmPushInteger( atoi(d->rows[nReal].szValue) );
      else
         hb_vmPushString( d->rows[nReal].szValue, strlen(d->rows[nReal].szValue) );
      hb_vmDo( 4 );
   }
   else
   {
      PHB_DYNS pDyn = hb_dynsymFindName( "UI_SETPROP" );
      if( !pDyn ) return;

      hb_vmPushDynSym( pDyn ); hb_vmPushNil();
      hb_vmPushNumInt( d->hCtrl );
      hb_vmPushString( d->rows[nReal].szName, strlen(d->rows[nReal].szName) );

      if( d->rows[nReal].cType == 'S' || d->rows[nReal].cType == 'F' ||
          d->rows[nReal].cType == 'A' || d->rows[nReal].cType == 'M' )
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

   /* Notify property changed (two-way sync) */
   if( d->pOnPropChanged && HB_IS_BLOCK( d->pOnPropChanged ) )
      hb_itemDo( d->pOnPropChanged, 0 );
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
   if( d->nTab == 1 ) return;  /* Events tab: no inline editing */

   strncpy( d->rows[nReal].szValue, new_text, sizeof(d->rows[0].szValue) - 1 );
   InsApplyValue( d, nReal );
   InsRebuildStore( d );
}

/* Activate the current tab: swap rows/map/nVisible for display */
static void InsActivateTab( INSDATA * d )
{
   if( d->bDebugMode )
   {
      /* Debug mode tabs: 0=Vars, 1=Call Stack, 2=Watch */
      if( d->nTab == 0 )
      {
         memcpy( d->rows, d->dbgLocalsRows, sizeof(IROW) * (size_t)d->nDbgLocalsRows );
         d->nRows = d->nDbgLocalsRows;
         d->nVisible = d->nDbgLocalsVisible;
         for( int k = 0; k < d->nRows; k++ ) d->map[k] = k;
      }
      else if( d->nTab == 1 )
      {
         memcpy( d->rows, d->dbgStackRows, sizeof(IROW) * (size_t)d->nDbgStackRows );
         d->nRows = d->nDbgStackRows;
         d->nVisible = d->nDbgStackVisible;
         for( int k = 0; k < d->nRows; k++ ) d->map[k] = k;
      }
      else
      {
         d->nRows = 0;
         d->nVisible = 0;
      }
   }
   else if( d->nTab == 1 )
   {
      /* Show event rows */
      memcpy( d->rows, d->evRows, sizeof(d->evRows) );
      d->nRows = d->nEvRows;
      memcpy( d->map, d->evMap, sizeof(d->evMap) );
      d->nVisible = d->nEvVisible;
   }
   else
   {
      /* Restore property rows */
      memcpy( d->rows, d->propRows, sizeof(d->propRows) );
      d->nRows = d->nPropRows;
      memcpy( d->map, d->propMap, sizeof(d->propMap) );
      d->nVisible = d->nPropVisible;
   }
   InsRebuildStore( d );
}

/* Tab switch callback */
static void on_inspector_tab_switched( GtkNotebook * nb, GtkWidget * page, guint nPage, gpointer data )
{
   INSDATA * d = (INSDATA *)data;
   if( !d ) return;
   d->nTab = (int)nPage;

   /* Update column headers */
   GList * cols = gtk_tree_view_get_columns( GTK_TREE_VIEW(d->treeView) );
   if( cols )
   {
      GtkTreeViewColumn * nameCol = (GtkTreeViewColumn *)cols->data;
      GtkTreeViewColumn * valCol = cols->next ? (GtkTreeViewColumn *)cols->next->data : NULL;

      if( d->bDebugMode )
      {
         if( d->nTab == 0 ) {
            gtk_tree_view_column_set_title( nameCol, "Variable" );
            if( valCol ) gtk_tree_view_column_set_title( valCol, "Value" );
         } else if( d->nTab == 1 ) {
            gtk_tree_view_column_set_title( nameCol, "#" );
            if( valCol ) gtk_tree_view_column_set_title( valCol, "Function(Line)" );
         } else {
            gtk_tree_view_column_set_title( nameCol, "Expression" );
            if( valCol ) gtk_tree_view_column_set_title( valCol, "Value" );
         }
      }
      else
      {
         gtk_tree_view_column_set_title( nameCol, d->nTab == 0 ? "Property" : "Event" );
         if( valCol )
            gtk_tree_view_column_set_title( valCol, d->nTab == 0 ? "Value" : "Handler" );
      }
      g_list_free( cols );
   }

   InsActivateTab( d );
}

/* Context passed to each enum popup menu item */
typedef struct { INSDATA * d; int nReal; int nIdx; } EnumMenuData;

static void on_enum_menu_activate( GtkMenuItem * item, gpointer userData )
{
   EnumMenuData * emd = (EnumMenuData *)userData;
   sprintf( emd->d->rows[emd->nReal].szValue, "%d", emd->nIdx );
   InsApplyValue( emd->d, emd->nReal );
   InsRebuildStore( emd->d );
}

/* ===== Menu Items Editor ===== */
#define MEI_MAX 128

typedef struct {
   char  szCaption[128];
   char  szShortcut[32];
   char  szHandler[128];
   int   bSeparator;
   int   bEnabled;
   int   nLevel;
   int   nParent;
} MEINode;

typedef struct {
   MEINode     nodes[MEI_MAX];
   int         nCount;
   GtkWidget * tree;
   GtkWidget * eCaption;
   GtkWidget * eShortcut;
   GtkWidget * eHandler;
   GtkWidget * cbEnabled;
   int         nSel;
   int         bUpdating;
} MEIDATA;

static void MEI_Serialize( MEIDATA * d, char * out, int outLen )
{
   int pos = 0;
   out[0] = 0;
   for( int i = 0; i < d->nCount && pos < outLen - 64; i++ ) {
      if( i > 0 ) out[pos++] = '|';
      const char * cap = d->nodes[i].bSeparator ? "---" : d->nodes[i].szCaption;
      int n = snprintf( out+pos, outLen-pos, "%s\x01%s\x01%s\x01%d\x01%d\x01%d",
         cap, d->nodes[i].szShortcut, d->nodes[i].szHandler,
         d->nodes[i].bEnabled, d->nodes[i].nLevel, d->nodes[i].nParent );
      if( n > 0 ) pos += n;
   }
}

static void MEI_Parse( MEIDATA * d, const char * raw )
{
   d->nCount = 0;
   if( !raw || !raw[0] ) return;
   while( *raw && d->nCount < MEI_MAX )
   {
      const char * pipe = strchr( raw, '|' );
      int tl = pipe ? (int)(pipe-raw) : (int)strlen(raw);
      if( tl > 511 ) tl = 511;
      char tok[512]; memcpy(tok,raw,tl); tok[tl]=0;
      int fi = d->nCount;
      char*f0=tok;
      char*f1=strchr(f0,'\x01'); if(f1){*f1++=0;}else f1=(char*)"";
      char*f2=f1[0]?strchr(f1,'\x01'):NULL; if(f2){*f2++=0;}else f2=(char*)"";
      char*f3=f2?strchr(f2,'\x01'):NULL; if(f3){*f3++=0;}else f3=(char*)"";
      char*f4=f3?strchr(f3,'\x01'):NULL; if(f4){*f4++=0;}else f4=(char*)"";
      char*f5=f4?strchr(f4,'\x01'):NULL; if(f5){*f5++=0;}else f5=(char*)"-1";
      d->nodes[fi].bSeparator = strcmp(f0,"---")==0;
      strncpy(d->nodes[fi].szCaption, d->nodes[fi].bSeparator?"":f0, 127);
      strncpy(d->nodes[fi].szShortcut, f1, 31);
      strncpy(d->nodes[fi].szHandler,  f2, 127);
      d->nodes[fi].bEnabled = f3[0]?atoi(f3):1;
      d->nodes[fi].nLevel   = f4[0]?atoi(f4):0;
      d->nodes[fi].nParent  = f5[0]?atoi(f5):-1;
      d->nCount++;
      if(!pipe) break;
      raw = pipe+1;
   }
}

static void MEI_RebuildTree( MEIDATA * d )
{
   GtkTreeStore * store = GTK_TREE_STORE(
      gtk_tree_view_get_model(GTK_TREE_VIEW(d->tree)) );
   gtk_tree_store_clear( store );

   GtkTreeIter iters[8];
   int hasIter[8] = {0};

   for( int i = 0; i < d->nCount; i++ ) {
      MEINode * n = &d->nodes[i];
      GtkTreeIter it;
      GtkTreeIter * parent = (n->nLevel>0 && n->nLevel<=7 && hasIter[n->nLevel-1])
                              ? &iters[n->nLevel-1] : NULL;
      gtk_tree_store_append( store, &it, parent );
      const char * cap = n->bSeparator ? "──────" : n->szCaption;
      gtk_tree_store_set( store, &it, 0, cap, 1, n->szShortcut, 2, i, -1 );
      if( !n->bSeparator ) {
         iters[n->nLevel] = it;
         hasIter[n->nLevel] = 1;
         for(int lv=n->nLevel+1;lv<8;lv++) hasIter[lv]=0;
      }
   }
   gtk_tree_view_expand_all( GTK_TREE_VIEW(d->tree) );
}

static void on_mei_selection_changed( GtkTreeSelection * sel, gpointer data )
{
   MEIDATA * d = (MEIDATA *)data;
   if( d->bUpdating ) return;
   GtkTreeIter it;
   GtkTreeModel * model;
   if( !gtk_tree_selection_get_selected(sel, &model, &it) ) { d->nSel=-1; return; }
   int idx; gtk_tree_model_get( model, &it, 2, &idx, -1 );
   if( idx<0 || idx>=d->nCount ) { d->nSel=-1; return; }
   d->bUpdating = 1;
   d->nSel = idx;
   MEINode * n = &d->nodes[idx];
   gtk_entry_set_text( GTK_ENTRY(d->eCaption),  n->bSeparator?"":n->szCaption );
   gtk_entry_set_text( GTK_ENTRY(d->eShortcut), n->szShortcut );
   gtk_entry_set_text( GTK_ENTRY(d->eHandler),  n->szHandler );
   gtk_toggle_button_set_active( GTK_TOGGLE_BUTTON(d->cbEnabled), n->bEnabled );
   gtk_widget_set_sensitive( d->eCaption,  !n->bSeparator );
   gtk_widget_set_sensitive( d->eShortcut, !n->bSeparator );
   gtk_widget_set_sensitive( d->eHandler,  !n->bSeparator );
   d->bUpdating = 0;
}

static void on_mei_caption_changed( GtkEditable * e, gpointer data )
{
   MEIDATA * d = (MEIDATA *)data;
   if( d->bUpdating || d->nSel<0 ) return;
   strncpy( d->nodes[d->nSel].szCaption, gtk_entry_get_text(GTK_ENTRY(e)), 127 );
   int saved = d->nSel;
   d->bUpdating = 1;
   MEI_RebuildTree(d);
   d->bUpdating = 0;
   d->nSel = saved;
}

static void on_mei_shortcut_changed( GtkEditable * e, gpointer data )
{
   MEIDATA * d = (MEIDATA *)data;
   if( d->bUpdating || d->nSel<0 ) return;
   strncpy( d->nodes[d->nSel].szShortcut, gtk_entry_get_text(GTK_ENTRY(e)), 31 );
   int saved = d->nSel;
   d->bUpdating = 1;
   MEI_RebuildTree(d);
   d->bUpdating = 0;
   d->nSel = saved;
}

static void on_mei_handler_changed( GtkEditable * e, gpointer data )
{
   MEIDATA * d = (MEIDATA *)data;
   if( d->bUpdating || d->nSel<0 ) return;
   strncpy( d->nodes[d->nSel].szHandler, gtk_entry_get_text(GTK_ENTRY(e)), 127 );
}

static void on_mei_enabled_toggled( GtkToggleButton * tb, gpointer data )
{
   MEIDATA * d = (MEIDATA *)data;
   if( d->bUpdating || d->nSel<0 ) return;
   d->nodes[d->nSel].bEnabled = gtk_toggle_button_get_active(tb) ? 1 : 0;
}

static void mei_add_node( MEIDATA * d, int nLevel, int bSeparator )
{
   if( d->nCount >= MEI_MAX ) return;
   int insPos = (d->nSel >= 0) ? d->nSel + 1 : d->nCount;
   /* Shift nodes up */
   for( int i = d->nCount; i > insPos; i-- )
      d->nodes[i] = d->nodes[i-1];
   /* Find parent index */
   int nParent = -1;
   if( nLevel > 0 ) {
      for( int i = insPos-1; i >= 0; i-- ) {
         if( d->nodes[i].nLevel == nLevel-1 && !d->nodes[i].bSeparator ) {
            nParent = i; break;
         }
      }
   }
   memset( &d->nodes[insPos], 0, sizeof(MEINode) );
   if( !bSeparator ) strcpy( d->nodes[insPos].szCaption, "NewItem" );
   d->nodes[insPos].bSeparator = bSeparator;
   d->nodes[insPos].bEnabled   = 1;
   d->nodes[insPos].nLevel     = nLevel;
   d->nodes[insPos].nParent    = nParent;
   d->nCount++;
   /* Fix parent refs shifted past the insertion point */
   for( int i = insPos+1; i < d->nCount; i++ )
      if( d->nodes[i].nParent >= insPos )
         d->nodes[i].nParent++;
   d->nSel = insPos;
   d->bUpdating = 1;
   MEI_RebuildTree(d);
   d->bUpdating = 0;
}

static void on_mei_add_popup ( GtkButton * b, gpointer d ) { (void)b; mei_add_node((MEIDATA*)d,0,0); }
static void on_mei_add_item  ( GtkButton * b, gpointer d ) { (void)b; mei_add_node((MEIDATA*)d,1,0); }
static void on_mei_add_sub   ( GtkButton * b, gpointer d ) { (void)b; mei_add_node((MEIDATA*)d,2,0); }
static void on_mei_add_sep   ( GtkButton * b, gpointer d )
{
   (void)b;
   MEIDATA * dd = (MEIDATA*)d;
   int lv = (dd->nSel>=0) ? dd->nodes[dd->nSel].nLevel : 1;
   mei_add_node(dd, lv, 1);
}

static void on_mei_move_up( GtkButton * b, gpointer data )
{
   (void)b;
   MEIDATA * d = (MEIDATA *)data;
   if( d->nSel <= 0 ) return;
   MEINode tmp = d->nodes[d->nSel]; d->nodes[d->nSel]=d->nodes[d->nSel-1]; d->nodes[d->nSel-1]=tmp;
   d->nSel--;
   d->bUpdating = 1;
   MEI_RebuildTree(d);
   d->bUpdating = 0;
}

static void on_mei_move_down( GtkButton * b, gpointer data )
{
   (void)b;
   MEIDATA * d = (MEIDATA *)data;
   if( d->nSel<0 || d->nSel>=d->nCount-1 ) return;
   MEINode tmp = d->nodes[d->nSel]; d->nodes[d->nSel]=d->nodes[d->nSel+1]; d->nodes[d->nSel+1]=tmp;
   d->nSel++;
   d->bUpdating = 1;
   MEI_RebuildTree(d);
   d->bUpdating = 0;
}

static void on_mei_delete( GtkButton * b, gpointer data )
{
   (void)b;
   MEIDATA * d = (MEIDATA *)data;
   if( d->nSel<0 || d->nCount==0 ) return;
   int del = d->nSel;
   for( int i=del; i<d->nCount-1; i++ ) d->nodes[i]=d->nodes[i+1];
   d->nCount--;
   d->nSel = del < d->nCount ? del : d->nCount-1;
   d->bUpdating = 1;
   MEI_RebuildTree(d);
   d->bUpdating = 0;
}

static void OpenMenuEditor( INSDATA * ins, int nReal )
{
   MEIDATA d;
   memset( &d, 0, sizeof(d) );
   d.nSel = -1;
   MEI_Parse( &d, ins->rows[nReal].szValue );

   GtkWidget * dialog = gtk_dialog_new_with_buttons( "Menu Items Editor",
      GTK_WINDOW(ins->window),
      GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "OK", GTK_RESPONSE_OK,
      "Cancel", GTK_RESPONSE_CANCEL,
      NULL );
   gtk_window_set_default_size( GTK_WINDOW(dialog), 640, 400 );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );

   /* Toolbar */
   GtkWidget * toolbar = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
   gtk_widget_set_margin_start( toolbar, 4 );
   gtk_widget_set_margin_top( toolbar, 4 );
   gtk_box_pack_start( GTK_BOX(content), toolbar, FALSE, FALSE, 0 );

   const char * btnLabels[] = { "+Popup", "+Item", "+SubItem", "+Sep", "↑", "↓", "✕" };
   GCallback    btnCbs[]    = {
      G_CALLBACK(on_mei_add_popup), G_CALLBACK(on_mei_add_item),
      G_CALLBACK(on_mei_add_sub),   G_CALLBACK(on_mei_add_sep),
      G_CALLBACK(on_mei_move_up),   G_CALLBACK(on_mei_move_down),
      G_CALLBACK(on_mei_delete)
   };
   for( int i = 0; i < 7; i++ ) {
      GtkWidget * btn = gtk_button_new_with_label( btnLabels[i] );
      g_signal_connect( btn, "clicked", btnCbs[i], &d );
      gtk_box_pack_start( GTK_BOX(toolbar), btn, FALSE, FALSE, 2 );
   }

   /* Paned: tree | props */
   GtkWidget * paned = gtk_paned_new( GTK_ORIENTATION_HORIZONTAL );
   gtk_paned_set_position( GTK_PANED(paned), 360 );
   gtk_box_pack_start( GTK_BOX(content), paned, TRUE, TRUE, 4 );

   /* Left: scrolled tree */
   GtkWidget * sw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(sw),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   GtkTreeStore * store = gtk_tree_store_new( 3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_INT );
   d.tree = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );
   g_object_unref( store );
   gtk_tree_view_set_headers_visible( GTK_TREE_VIEW(d.tree), TRUE );

   GtkCellRenderer * r0 = gtk_cell_renderer_text_new();
   GtkTreeViewColumn * c0 = gtk_tree_view_column_new_with_attributes( "Caption", r0, "text", 0, NULL );
   gtk_tree_view_column_set_min_width( c0, 180 );
   gtk_tree_view_column_set_resizable( c0, TRUE );
   gtk_tree_view_append_column( GTK_TREE_VIEW(d.tree), c0 );

   GtkCellRenderer * r1 = gtk_cell_renderer_text_new();
   GtkTreeViewColumn * c1 = gtk_tree_view_column_new_with_attributes( "Shortcut", r1, "text", 1, NULL );
   gtk_tree_view_column_set_min_width( c1, 100 );
   gtk_tree_view_append_column( GTK_TREE_VIEW(d.tree), c1 );

   gtk_container_add( GTK_CONTAINER(sw), d.tree );
   gtk_widget_show( d.tree );
   gtk_paned_add1( GTK_PANED(paned), sw );

   GtkTreeSelection * treeSel = gtk_tree_view_get_selection( GTK_TREE_VIEW(d.tree) );
   g_signal_connect( treeSel, "changed", G_CALLBACK(on_mei_selection_changed), &d );

   /* Right: properties grid in a scrolled window */
   GtkWidget * propSw = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(propSw),
      GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC );

   GtkWidget * grid = gtk_grid_new();
   gtk_grid_set_row_spacing( GTK_GRID(grid), 8 );
   gtk_grid_set_column_spacing( GTK_GRID(grid), 8 );
   gtk_widget_set_margin_start( grid, 8 );
   gtk_widget_set_margin_top( grid, 8 );
   gtk_widget_set_margin_end( grid, 8 );

   d.eCaption  = gtk_entry_new();
   d.eShortcut = gtk_entry_new();
   d.eHandler  = gtk_entry_new();
   d.cbEnabled = gtk_check_button_new_with_label( "Enabled" );

   GtkWidget * lCaption  = gtk_label_new("Caption:");  gtk_widget_set_halign(lCaption, GTK_ALIGN_END);
   GtkWidget * lShortcut = gtk_label_new("Shortcut:"); gtk_widget_set_halign(lShortcut, GTK_ALIGN_END);
   GtkWidget * lOnClick  = gtk_label_new("OnClick:");  gtk_widget_set_halign(lOnClick, GTK_ALIGN_END);

   gtk_grid_attach( GTK_GRID(grid), lCaption,    0, 0, 1, 1 );
   gtk_grid_attach( GTK_GRID(grid), d.eCaption,  1, 0, 1, 1 );
   gtk_grid_attach( GTK_GRID(grid), lShortcut,   0, 1, 1, 1 );
   gtk_grid_attach( GTK_GRID(grid), d.eShortcut, 1, 1, 1, 1 );
   gtk_grid_attach( GTK_GRID(grid), lOnClick,    0, 2, 1, 1 );
   gtk_grid_attach( GTK_GRID(grid), d.eHandler,  1, 2, 1, 1 );
   gtk_grid_attach( GTK_GRID(grid), d.cbEnabled, 1, 3, 1, 1 );

   gtk_widget_set_hexpand( d.eCaption,  TRUE );
   gtk_widget_set_hexpand( d.eShortcut, TRUE );
   gtk_widget_set_hexpand( d.eHandler,  TRUE );

   g_signal_connect( d.eCaption,  "changed", G_CALLBACK(on_mei_caption_changed),  &d );
   g_signal_connect( d.eShortcut, "changed", G_CALLBACK(on_mei_shortcut_changed), &d );
   g_signal_connect( d.eHandler,  "changed", G_CALLBACK(on_mei_handler_changed),  &d );
   g_signal_connect( d.cbEnabled, "toggled", G_CALLBACK(on_mei_enabled_toggled),  &d );

   gtk_container_add( GTK_CONTAINER(propSw), grid );
   gtk_paned_add2( GTK_PANED(paned), propSw );

   gtk_widget_show_all( content );

   MEI_RebuildTree( &d );

   if( gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_OK ) {
      char result[4096] = "";
      MEI_Serialize( &d, result, sizeof(result) );
      strncpy( ins->rows[nReal].szValue, result, sizeof(ins->rows[nReal].szValue)-1 );
      InsApplyValue( ins, nReal );
      InsRebuildStore( ins );
   }
   gtk_widget_destroy( dialog );
}

/* Row activated (double-click) - toggle category, open picker, or fire event handler */
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

   /* Enum 'N' property: show popup menu with named options */
   if( d->rows[nReal].cType == 'N' )
   {
      ENUMDEF * pE = InsGetEnum( d->rows[nReal].szName );
      if( pE )
      {
         int curIdx = atoi( d->rows[nReal].szValue );
         GtkWidget * menu = gtk_menu_new();
         for( int i = 0; i < pE->nCount; i++ )
         {
            GtkWidget * item = gtk_check_menu_item_new_with_label( pE->aValues[i] );
            gtk_check_menu_item_set_draw_as_radio( GTK_CHECK_MENU_ITEM(item), TRUE );
            if( i == curIdx )
               gtk_check_menu_item_set_active( GTK_CHECK_MENU_ITEM(item), TRUE );
            EnumMenuData * emd = g_new( EnumMenuData, 1 );
            emd->d = d; emd->nReal = nReal; emd->nIdx = i;
            g_object_set_data_full( G_OBJECT(item), "emd", emd, g_free );
            g_signal_connect( item, "activate", G_CALLBACK(on_enum_menu_activate), emd );
            gtk_menu_shell_append( GTK_MENU_SHELL(menu), item );
         }
         gtk_widget_show_all( menu );
         gtk_menu_popup_at_pointer( GTK_MENU(menu), NULL );
         return;
      }
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

   /* Menu property: open Menu Items Editor */
   if( d->rows[nReal].cType == 'M' )
   {
      OpenMenuEditor( d, nReal );
      return;
   }

   /* Array property: open multiline editor (pipe-separated items) */
   if( d->rows[nReal].cType == 'A' )
   {
      GtkWidget * dialog = gtk_dialog_new_with_buttons( "Array Editor",
         GTK_WINDOW(d->window),
         GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
         "OK", GTK_RESPONSE_OK,
         "Cancel", GTK_RESPONSE_CANCEL,
         NULL );
      gtk_window_set_default_size( GTK_WINDOW(dialog), 360, 300 );
      gtk_window_set_position( GTK_WINDOW(dialog), GTK_WIN_POS_CENTER );

      GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );
      GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
      gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
         GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );

      GtkWidget * textView = gtk_text_view_new();
      gtk_text_view_set_monospace( GTK_TEXT_VIEW(textView), TRUE );
      gtk_text_view_set_left_margin( GTK_TEXT_VIEW(textView), 6 );
      gtk_text_view_set_top_margin( GTK_TEXT_VIEW(textView), 6 );

      /* Convert pipe-separated to newline-separated for editing */
      {
         const char * raw = d->rows[nReal].szValue;
         char buf[2048] = {0};
         int o = 0;
         for( const char * p = raw; *p && o < (int)sizeof(buf) - 2; p++ )
         {
            if( *p == '|' ) buf[o++] = '\n';
            else buf[o++] = *p;
         }
         buf[o] = 0;
         GtkTextBuffer * tbuf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(textView) );
         gtk_text_buffer_set_text( tbuf, buf, -1 );
      }

      gtk_container_add( GTK_CONTAINER(scroll), textView );
      gtk_box_pack_start( GTK_BOX(content), scroll, TRUE, TRUE, 0 );
      gtk_widget_show_all( content );

      if( gtk_dialog_run( GTK_DIALOG(dialog) ) == GTK_RESPONSE_OK )
      {
         GtkTextBuffer * tbuf = gtk_text_view_get_buffer( GTK_TEXT_VIEW(textView) );
         GtkTextIter start, end;
         gtk_text_buffer_get_bounds( tbuf, &start, &end );
         gchar * text = gtk_text_buffer_get_text( tbuf, &start, &end, FALSE );

         /* Convert newlines back to pipes */
         char result[256] = {0};
         int o = 0;
         if( text )
         {
            for( const char * p = text; *p && o < (int)sizeof(result) - 1; p++ )
            {
               if( *p == '\r' ) continue;
               if( *p == '\n' ) result[o++] = '|';
               else result[o++] = *p;
            }
            /* Trim trailing pipes */
            while( o > 0 && result[o-1] == '|' ) o--;
            result[o] = 0;
            g_free( text );
         }

         strncpy( d->rows[nReal].szValue, result, sizeof(d->rows[nReal].szValue)-1 );
         InsApplyValue( d, nReal );
         InsRebuildStore( d );

         /* If aColumns changed, repopulate combo to show TBrwColumn entries */
         if( strcasecmp( d->rows[nReal].szName, "aColumns" ) == 0 && d->hFormCtrl )
         {
            PHB_DYNS pDyn = hb_dynsymFindName( "INSPECTORPOPULATECOMBO" );
            if( pDyn && hb_vmRequestReenter() ) {
               hb_vmPushDynSym( pDyn ); hb_vmPushNil();
               hb_vmPushNumInt( d->hFormCtrl );
               hb_vmDo( 1 );
               hb_vmRequestRestore();
            }
         }
      }
      gtk_widget_destroy( dialog );
      return;
   }

   /* Events tab: double-click fires event handler callback */
   if( d->nTab == 1 )
   {
      if( d->pOnEventDblClick && HB_IS_BLOCK( d->pOnEventDblClick ) )
      {
         const char * szEvent = d->rows[nReal].szName;
         PHB_ITEM pArg1 = hb_itemPutNInt( hb_itemNew(NULL), d->hCtrl );
         PHB_ITEM pArg2 = hb_itemPutC( hb_itemNew(NULL), szEvent );
         hb_itemDo( d->pOnEventDblClick, 2, pArg1, pArg2 );
         hb_itemRelease( pArg1 );
         hb_itemRelease( pArg2 );
      }
      return;
   }
}

/* Right-click context menu on Events tab — delete handler */
static void on_event_delete_handler( GtkMenuItem * menuItem, gpointer data )
{
   INSDATA * d = (INSDATA *)data;
   const char * szHandler = g_object_get_data( G_OBJECT(menuItem), "handler" );
   if( !szHandler || !szHandler[0] ) return;

   PHB_DYNS pDel = hb_dynsymFindName( "INS_DELETEHANDLER" );
   if( pDel && hb_vmRequestReenter() )
   {
      hb_vmPushDynSym( pDel ); hb_vmPushNil();
      hb_vmPushString( szHandler, strlen(szHandler) );
      hb_vmDo( 1 );
      hb_vmRequestRestore();

      /* Refresh inspector via Harbour callback */
      PHB_DYNS pRefresh = hb_dynsymFindName( "INSPECTORREFRESH" );
      if( pRefresh && hb_vmRequestReenter() )
      {
         hb_vmPushDynSym( pRefresh ); hb_vmPushNil();
         hb_vmPushNumInt( d->hCtrl );
         hb_vmDo( 1 );
         hb_vmRequestRestore();
      }
   }
}

static gboolean on_tree_button_press( GtkWidget * widget, GdkEventButton * event,
   gpointer data )
{
   INSDATA * d = (INSDATA *)data;

   /* Only handle right-click on Events tab */
   if( event->button != 3 || d->nTab != 1 )
      return FALSE;

   GtkTreePath * path = NULL;
   if( !gtk_tree_view_get_path_at_pos( GTK_TREE_VIEW(widget),
      (gint)event->x, (gint)event->y, &path, NULL, NULL, NULL ) )
      return FALSE;

   GtkTreeIter iter;
   if( !gtk_tree_model_get_iter( GTK_TREE_MODEL(d->store), &iter, path ) )
   {
      gtk_tree_path_free( path );
      return FALSE;
   }
   gtk_tree_path_free( path );

   int nReal;
   gtk_tree_model_get( GTK_TREE_MODEL(d->store), &iter, COL_REAL_IDX, &nReal, -1 );

   if( nReal < 0 || nReal >= d->nRows ) return FALSE;
   if( d->rows[nReal].bIsCat ) return FALSE;
   if( d->rows[nReal].szValue[0] == 0 ) return FALSE; /* No handler assigned */

   /* Build context menu */
   GtkWidget * menu = gtk_menu_new();
   char title[4104];
   snprintf( title, sizeof(title), "Delete %s", d->rows[nReal].szValue );
   GtkWidget * item = gtk_menu_item_new_with_label( title );
   g_object_set_data_full( G_OBJECT(item), "handler",
      g_strdup( d->rows[nReal].szValue ), g_free );
   g_signal_connect( item, "activate", G_CALLBACK(on_event_delete_handler), d );
   gtk_menu_shell_append( GTK_MENU_SHELL(menu), item );
   gtk_widget_show_all( menu );
   gtk_menu_popup_at_pointer( GTK_MENU(menu), (GdkEvent *)event );

   return TRUE;
}

/* Combo box selection changed */
static void on_combo_sel_changed( GtkComboBox * widget, gpointer data )
{
   INSDATA * d = (INSDATA *)data;
   int idx = gtk_combo_box_get_active( widget );
   if( idx >= 0 && d->pOnComboSel && HB_IS_BLOCK( d->pOnComboSel ) )
   {
      PHB_ITEM pArg = hb_itemPutNI( hb_itemNew(NULL), idx );
      hb_itemDo( d->pOnComboSel, 1, pArg );
      hb_itemRelease( pArg );
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

/* Combo map: maps combo index to { nType, hCtrl, nColIdx } */
static PHB_ITEM s_comboMap = NULL;

HB_FUNC( _INSSETCOMBOMAP ) {
   if( s_comboMap ) hb_itemRelease( s_comboMap );
   s_comboMap = hb_itemClone( hb_param(1, HB_IT_ARRAY) );
}
HB_FUNC( _INSGETCOMBOMAP ) {
   if( s_comboMap )
      hb_itemReturn( s_comboMap );
   else
      hb_reta( 0 );
}

/* INS_SetBrowseCol( hInsData, nCol ) - set column index for property editing */
HB_FUNC( INS_SETBROWSECOL )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d ) d->nBrowseCol = hb_parni(2);
}

/* ======================================================================
 * INS_Create() --> hInsData
 * ====================================================================== */

HB_FUNC( INS_CREATE )
{
   EnsureGTK();

   INSDATA * d = (INSDATA *) calloc( 1, sizeof(INSDATA) );
   d->nBrowseCol = -1;
   d->nFolderPage = -1;

   /* Create window */
   d->window = gtk_window_new( GTK_WINDOW_TOPLEVEL );
   gtk_window_set_title( GTK_WINDOW(d->window), "Inspector" );
   gtk_window_set_default_size( GTK_WINDOW(d->window), 320, 450 );
   gtk_window_set_type_hint( GTK_WINDOW(d->window), GDK_WINDOW_TYPE_HINT_UTILITY );
   g_signal_connect( d->window, "delete-event", G_CALLBACK(on_inspector_delete), d );

   /* VBox: combo + property table */
   GtkWidget * vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
   gtk_container_add( GTK_CONTAINER(d->window), vbox );

   /* Control selection combo at top */
   d->combo = gtk_combo_box_text_new();
   gtk_box_pack_start( GTK_BOX(vbox), d->combo, FALSE, FALSE, 2 );
   g_signal_connect( d->combo, "changed", G_CALLBACK(on_combo_sel_changed), d );

   /* Properties / Events tabs */
   d->nTab = 0;
   d->tabWidget = gtk_notebook_new();
   gtk_notebook_set_show_border( GTK_NOTEBOOK(d->tabWidget), FALSE );
   GtkWidget * propLabel = gtk_label_new( "Properties" );
   GtkWidget * evLabel   = gtk_label_new( "Events" );
   GtkWidget * propDummy = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
   GtkWidget * evDummy   = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
   gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), propDummy, propLabel );
   gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), evDummy, evLabel );
   gtk_box_pack_start( GTK_BOX(vbox), d->tabWidget, FALSE, FALSE, 0 );
   g_signal_connect( d->tabWidget, "switch-page", G_CALLBACK(on_inspector_tab_switched), d );

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

   /* Right-click context menu for event handler deletion */
   g_signal_connect( d->treeView, "button-press-event", G_CALLBACK(on_tree_button_press), d );

   /* Scroll view */
   GtkWidget * scroll = gtk_scrolled_window_new( NULL, NULL );
   gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(scroll),
      GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
   gtk_container_add( GTK_CONTAINER(scroll), d->treeView );
   gtk_box_pack_start( GTK_BOX(vbox), scroll, TRUE, TRUE, 0 );

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
   d->nBrowseCol = -1;  /* reset; InspectorRefreshColumn sets it after */
   d->nFolderPage = -1; /* reset; INS_SetFolderPage sets it after */

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

   /* Cache property rows */
   memcpy( d->propRows, d->rows, sizeof(d->rows) );
   d->nPropRows = d->nRows;
   memcpy( d->propMap, d->map, sizeof(d->map) );
   d->nPropVisible = d->nVisible;

   /* If Events tab is active, show events instead */
   if( d->nTab == 1 )
      InsActivateTab( d );
   else
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
   if( d->pOnComboSel ) { hb_itemRelease( d->pOnComboSel ); d->pOnComboSel = NULL; }
   if( d->window ) gtk_widget_destroy( d->window );
   free( d );
}

/* ======================================================================
 * INS_SetFormCtrl( hInsData, hForm )
 * ====================================================================== */

HB_FUNC( INS_SETFORMCTRL )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d ) d->hFormCtrl = (HB_PTRUINT) hb_parnint(2);
}

/* ======================================================================
 * INS_SetOnComboSel( hInsData, bBlock )
 * ====================================================================== */

HB_FUNC( INS_SETONCOMBOSEL )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnComboSel ) hb_itemRelease( d->pOnComboSel );
      d->pOnComboSel = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* ======================================================================
 * INS_ComboAdd( hInsData, cText )
 * ====================================================================== */

HB_FUNC( INS_COMBOADD )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d && d->combo && HB_ISCHAR(2) )
      gtk_combo_box_text_append_text( GTK_COMBO_BOX_TEXT(d->combo), hb_parc(2) );
}

/* ======================================================================
 * INS_ComboSelect( hInsData, nIndex )
 * ====================================================================== */

HB_FUNC( INS_COMBOSELECT )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   int idx = hb_parni(2);
   if( d && d->combo )
      gtk_combo_box_set_active( GTK_COMBO_BOX(d->combo), idx );
}

/* ======================================================================
 * INS_ComboClear( hInsData )
 * ====================================================================== */

HB_FUNC( INS_COMBOCLEAR )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( d && d->combo )
      gtk_combo_box_text_remove_all( GTK_COMBO_BOX_TEXT(d->combo) );
}

/* ======================================================================
 * INS_SetPos( hInsData, nLeft, nTop, nWidth, nHeight )
 * ====================================================================== */

HB_FUNC( INS_SETPOS )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d || !d->window ) return;

   int nLeft   = hb_parni(2);
   int nTop    = hb_parni(3);
   int nWidth  = hb_parni(4);
   int nHeight = hb_parni(5);

   gtk_window_move( GTK_WINDOW(d->window), nLeft, nTop );
   gtk_window_resize( GTK_WINDOW(d->window), nWidth, nHeight );
}

/* ======================================================================
 * INS_SetEvents( hInsData, aEvents )
 * Store events array for inspector Events tab
 * Each event: { cName, lAssigned, cCategory }
 * ====================================================================== */

HB_FUNC( INS_SETEVENTS )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pArray = hb_param(2, HB_IT_ARRAY);
   if( !d ) return;

   d->nEvRows = 0;
   if( !pArray ) return;

   HB_SIZE nLen = hb_arrayLen( pArray );
   char lastCat[32] = "";

   for( HB_SIZE i = 1; i <= nLen && d->nEvRows < MAX_ROWS; i++ )
   {
      PHB_ITEM pRow = hb_arrayGetItemPtr( pArray, i );
      if( !pRow || hb_arrayLen( pRow ) < 3 ) continue;

      const char * name = hb_arrayGetCPtr( pRow, 1 );
      const char * cat = hb_arrayGetCPtr( pRow, 3 );

      /* Field 2: handler name (string) or assigned flag (logical) */
      char handlerName[64] = "";
      PHB_ITEM pField2 = hb_arrayGetItemPtr( pRow, 2 );
      if( pField2 && HB_IS_STRING( pField2 ) )
         strncpy( handlerName, hb_itemGetCPtr( pField2 ), 63 );
      else if( pField2 && HB_IS_LOGICAL( pField2 ) && hb_itemGetL( pField2 ) )
         strcpy( handlerName, "(assigned)" );

      /* Insert category header if new category */
      if( strcmp( cat, lastCat ) != 0 && d->nEvRows < MAX_ROWS )
      {
         IROW * r = &d->evRows[d->nEvRows++];
         strncpy( r->szName, cat, 31 );
         r->szValue[0] = 0;
         strncpy( r->szCategory, cat, 31 );
         r->cType = 'S';
         r->bIsCat = 1;
         r->bCollapsed = 0;
         r->bVisible = 1;
         strncpy( lastCat, cat, 31 );
      }

      if( d->nEvRows < MAX_ROWS )
      {
         IROW * r = &d->evRows[d->nEvRows++];
         strncpy( r->szName, name, 31 );
         strncpy( r->szValue, handlerName, sizeof(r->szValue)-1 );
         strncpy( r->szCategory, cat, 31 );
         r->cType = 'S';
         r->bIsCat = 0;
         r->bCollapsed = 0;
         r->bVisible = 1;
      }
   }

   /* Build visible map */
   d->nEvVisible = 0;
   for( int k = 0; k < d->nEvRows; k++ )
   {
      if( d->evRows[k].bVisible || d->evRows[k].bIsCat )
         d->evMap[d->nEvVisible++] = k;
   }

   /* If Events tab is active, refresh display */
   if( d->nTab == 1 )
      InsActivateTab( d );
}

/* ======================================================================
 * INS_SetOnEventDblClick( hInsData, bBlock )
 * Callback when event row is double-clicked: bBlock( hCtrl, cEventName )
 * ====================================================================== */

HB_FUNC( INS_SETONEVENTDBLCLICK )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnEventDblClick ) hb_itemRelease( d->pOnEventDblClick );
      d->pOnEventDblClick = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* ======================================================================
 * INS_SetOnPropChanged( hInsData, bBlock )
 * Callback after any property is edited (for two-way sync)
 * ====================================================================== */

HB_FUNC( INS_SETONPROPCHANGED )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   PHB_ITEM pBlock = hb_param(2, HB_IT_BLOCK);
   if( d )
   {
      if( d->pOnPropChanged ) hb_itemRelease( d->pOnPropChanged );
      d->pOnPropChanged = pBlock ? hb_itemNew( pBlock ) : NULL;
   }
}

/* ======================================================================
 * Debug mode: switch inspector to Locals/CallStack/Watch tabs
 * ====================================================================== */

/* INS_SetDebugMode( hInsData, lDebug )
 * .T. = switch to debug tabs (Vars/CallStack/Watch), hide combo
 * .F. = restore Properties/Events tabs, show combo */
HB_FUNC( INS_SETDEBUGMODE )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   HB_BOOL bDebug = hb_parl(2);
   if( !d ) return;

   d->bDebugMode = bDebug;

   if( bDebug )
   {
      /* Block tab switch signal to avoid recursive callbacks */
      g_signal_handlers_block_matched( d->tabWidget, G_SIGNAL_MATCH_FUNC,
         0, 0, NULL, (gpointer)on_inspector_tab_switched, NULL );

      /* Remove existing tabs, add debug tabs */
      while( gtk_notebook_get_n_pages( GTK_NOTEBOOK(d->tabWidget) ) > 0 )
         gtk_notebook_remove_page( GTK_NOTEBOOK(d->tabWidget), 0 );

      GtkWidget * d0 = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
      GtkWidget * d1 = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
      GtkWidget * d2 = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
      gtk_widget_show( d0 ); gtk_widget_show( d1 ); gtk_widget_show( d2 );
      gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), d0, gtk_label_new("Vars") );
      gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), d1, gtk_label_new("Call Stack") );
      gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), d2, gtk_label_new("Watch") );
      gtk_notebook_set_current_page( GTK_NOTEBOOK(d->tabWidget), 0 );

      g_signal_handlers_unblock_matched( d->tabWidget, G_SIGNAL_MATCH_FUNC,
         0, 0, NULL, (gpointer)on_inspector_tab_switched, NULL );

      d->nTab = 0;
      gtk_widget_hide( d->combo );
      gtk_window_set_title( GTK_WINDOW(d->window), "Debugger" );

      /* Set column headers for Vars tab */
      GList * cols = gtk_tree_view_get_columns( GTK_TREE_VIEW(d->treeView) );
      if( cols )
      {
         gtk_tree_view_column_set_title( (GtkTreeViewColumn *)cols->data, "Variable" );
         if( cols->next )
            gtk_tree_view_column_set_title( (GtkTreeViewColumn *)cols->next->data, "Value" );
         g_list_free( cols );
      }

      /* Clear display */
      d->nDbgLocalsRows = 0; d->nDbgLocalsVisible = 0;
      d->nDbgStackRows = 0; d->nDbgStackVisible = 0;
      d->nRows = 0; d->nVisible = 0;
      InsRebuildStore( d );
   }
   else
   {
      /* Restore Properties/Events tabs */
      g_signal_handlers_block_matched( d->tabWidget, G_SIGNAL_MATCH_FUNC,
         0, 0, NULL, (gpointer)on_inspector_tab_switched, NULL );

      while( gtk_notebook_get_n_pages( GTK_NOTEBOOK(d->tabWidget) ) > 0 )
         gtk_notebook_remove_page( GTK_NOTEBOOK(d->tabWidget), 0 );

      GtkWidget * p0 = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
      GtkWidget * p1 = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
      gtk_widget_show( p0 ); gtk_widget_show( p1 );
      gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), p0, gtk_label_new("Properties") );
      gtk_notebook_append_page( GTK_NOTEBOOK(d->tabWidget), p1, gtk_label_new("Events") );
      gtk_notebook_set_current_page( GTK_NOTEBOOK(d->tabWidget), 0 );

      g_signal_handlers_unblock_matched( d->tabWidget, G_SIGNAL_MATCH_FUNC,
         0, 0, NULL, (gpointer)on_inspector_tab_switched, NULL );

      d->nTab = 0;
      gtk_widget_show( d->combo );
      gtk_window_set_title( GTK_WINDOW(d->window), "Inspector" );

      /* Restore column headers */
      GList * cols = gtk_tree_view_get_columns( GTK_TREE_VIEW(d->treeView) );
      if( cols )
      {
         gtk_tree_view_column_set_title( (GtkTreeViewColumn *)cols->data, "Property" );
         if( cols->next )
            gtk_tree_view_column_set_title( (GtkTreeViewColumn *)cols->next->data, "Value" );
         g_list_free( cols );
      }

      /* Restore property rows */
      memcpy( d->rows, d->propRows, sizeof(d->propRows) );
      d->nRows = d->nPropRows;
      memcpy( d->map, d->propMap, sizeof(d->propMap) );
      d->nVisible = d->nPropVisible;
      InsRebuildStore( d );
   }
}

/* INS_SetDebugLocals( hInsData, cVarsStr )
 * Format: "VARS [PUBLIC] name=val ... [PRIVATE] name=val ... [LOCAL] name=val ..." */
HB_FUNC( INS_SETDEBUGLOCALS )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   const char * str = hb_parc(2);
   if( !d || !str ) return;

   d->nDbgLocalsRows = 0;
   d->nDbgLocalsVisible = 0;

   /* Skip prefix */
   if( strncmp( str, "VARS", 4 ) == 0 ) str += 4;
   while( *str == ' ' ) str++;

   while( *str )
   {
      if( d->nDbgLocalsRows >= MAX_ROWS ) break;

      /* Check for category header [PUBLIC], [PRIVATE], [LOCAL] */
      if( *str == '[' )
      {
         IROW * r = &d->dbgLocalsRows[d->nDbgLocalsRows];
         memset( r, 0, sizeof(IROW) );
         r->bIsCat = 1;
         r->bVisible = 1;
         r->bCollapsed = 0;
         str++;
         int ni = 0;
         while( *str && *str != ']' && ni < 31 ) r->szName[ni++] = *str++;
         r->szName[ni] = 0;
         if( *str == ']' ) str++;
         while( *str == ' ' ) str++;
         d->dbgLocalsMap[d->nDbgLocalsRows] = d->nDbgLocalsRows;
         d->nDbgLocalsRows++;
         d->nDbgLocalsVisible++;
         continue;
      }

      /* Parse "name=value" token */
      IROW * r = &d->dbgLocalsRows[d->nDbgLocalsRows];
      memset( r, 0, sizeof(IROW) );
      r->bVisible = 1;
      r->cType = 'S';

      /* Name (up to '=') */
      int ni = 0;
      while( *str && *str != '=' && *str != ' ' && ni < 31 ) r->szName[ni++] = *str++;
      r->szName[ni] = 0;
      if( *str == '=' ) str++;

      /* Value (up to next space) */
      int vi = 0;
      while( *str && *str != ' ' && vi < 255 ) r->szValue[vi++] = *str++;
      r->szValue[vi] = 0;
      while( *str == ' ' ) str++;

      if( ni > 0 )
      {
         d->dbgLocalsMap[d->nDbgLocalsRows] = d->nDbgLocalsRows;
         d->nDbgLocalsRows++;
         d->nDbgLocalsVisible++;
      }
   }

   /* If showing Vars tab (tab 0), update display */
   if( d->bDebugMode && d->nTab == 0 )
   {
      memcpy( d->rows, d->dbgLocalsRows, sizeof(IROW) * (size_t)d->nDbgLocalsRows );
      d->nRows = d->nDbgLocalsRows;
      d->nVisible = d->nDbgLocalsVisible;
      for( int k = 0; k < d->nRows; k++ ) d->map[k] = k;
      InsRebuildStore( d );
   }
}

/* INS_SetDebugStack( hInsData, cStackStr )
 * Format: "STACK func1(line1) func2(line2) ..." */
HB_FUNC( INS_SETDEBUGSTACK )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   const char * str = hb_parc(2);
   if( !d || !str ) return;

   d->nDbgStackRows = 0;
   d->nDbgStackVisible = 0;

   if( strncmp( str, "STACK", 5 ) == 0 ) str += 5;
   while( *str == ' ' ) str++;

   while( *str )
   {
      if( d->nDbgStackRows >= MAX_ROWS ) break;
      IROW * r = &d->dbgStackRows[d->nDbgStackRows];
      memset( r, 0, sizeof(IROW) );
      r->bVisible = 1;

      /* Name column: "#N" */
      snprintf( r->szName, sizeof(r->szName), "#%d", d->nDbgStackRows + 1 );

      /* Value: "FuncName(line)" */
      int vi = 0;
      while( *str && *str != ' ' && vi < 255 ) r->szValue[vi++] = *str++;
      r->szValue[vi] = 0;
      while( *str == ' ' ) str++;

      r->cType = 'S';
      d->dbgStackMap[d->nDbgStackRows] = d->nDbgStackRows;
      d->nDbgStackRows++;
      d->nDbgStackVisible++;
   }

   /* If showing Call Stack tab (tab 1), update display */
   if( d->bDebugMode && d->nTab == 1 )
   {
      memcpy( d->rows, d->dbgStackRows, sizeof(IROW) * (size_t)d->nDbgStackRows );
      d->nRows = d->nDbgStackRows;
      d->nVisible = d->nDbgStackVisible;
      for( int k = 0; k < d->nRows; k++ ) d->map[k] = k;
      InsRebuildStore( d );
   }
}

/* ======================================================================
 * TFolderPage inspector view: Harbour drives the rows directly via
 * INS_SetFolderPage + INS_AddCategoryRow + INS_AddRow and finishes with
 * INS_Rebuild. Bypasses UI_GetAllProps.
 * ====================================================================== */

HB_FUNC( INS_SETFOLDERPAGE )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   d->hCtrl = (HB_PTRUINT) hb_parnint(2);
   d->nFolderPage = HB_ISNUM(3) ? hb_parni(3) : -1;
   d->nRows = 0;
}

HB_FUNC( INS_ADDROW )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d || d->nRows >= MAX_ROWS - 1 ) return;
   IROW * r = &d->rows[d->nRows++];
   memset( r, 0, sizeof(IROW) );
   strncpy( r->szName,     HB_ISCHAR(2) ? hb_parc(2) : "", 31 );
   strncpy( r->szValue,    HB_ISCHAR(3) ? hb_parc(3) : "", sizeof(r->szValue)-1 );
   strncpy( r->szCategory, HB_ISCHAR(4) ? hb_parc(4) : "General", 31 );
   r->cType = ( HB_ISCHAR(5) && hb_parc(5)[0] ) ? hb_parc(5)[0] : 'S';
   r->bIsCat = 0;
   r->bCollapsed = 0;
   r->bVisible = 1;
}

HB_FUNC( INS_ADDCATEGORYROW )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d || d->nRows >= MAX_ROWS - 1 ) return;
   IROW * r = &d->rows[d->nRows++];
   memset( r, 0, sizeof(IROW) );
   strncpy( r->szName,     HB_ISCHAR(2) ? hb_parc(2) : "", 31 );
   strncpy( r->szCategory, HB_ISCHAR(2) ? hb_parc(2) : "", 31 );
   r->cType = 0;
   r->bIsCat = 1;
   r->bCollapsed = 0;
   r->bVisible = 1;
}

HB_FUNC( INS_REBUILD )
{
   INSDATA * d = (INSDATA *)(HB_PTRUINT) hb_parnint(1);
   if( !d ) return;
   for( int k = 0; k < d->nRows; k++ ) d->map[k] = k;
   d->nVisible = d->nRows;
   InsRebuildStore( d );
}
