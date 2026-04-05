# Linux GTK3 Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the GTK3 Linux backend to feature parity with macOS Cocoa, then add missing Win32 controls.

**Architecture:** All Phase A features are added to `backends/gtk3/gtk3_core.c` as new `HB_FUNC` exports following the exact same patterns as `cocoa_core.m`. Phase B controls follow the existing pattern in gtk3_core.c (see `UI_BUTTONNEW`, `UI_EDITNEW`, etc.) — allocate struct, init, set type, add to parent, return handle. The IDE sample `samples/hbbuilder_linux.prg` is updated to wire new menu items and handle new controls in code generation.

**Tech Stack:** C (GTK3, GLib, cairo), Harbour (HB_FUNC bridge), Scintilla (SCI_* messages)

---

## Phase A: macOS Parity

### Task 1: Undo/Redo on Form Designer

**Files:**
- Modify: `backends/gtk3/gtk3_core.c` (insert after line ~7352, end of file)
- Modify: `samples/hbbuilder_linux.prg` (wire Ctrl+Z for form undo)

- [ ] **Step 1: Add undo data structures and helper functions to gtk3_core.c**

Append before the final closing of the file (after the report preview section, line ~7352). This mirrors `cocoa_core.m:3723-3762` exactly:

```c
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
```

- [ ] **Step 2: Add HB_FUNC exports for Undo**

Append immediately after the helpers:

```c
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
```

- [ ] **Step 3: Wire undo into the IDE sample**

In `samples/hbbuilder_linux.prg`, find the Edit menu (line ~81-87) and add a Form Undo item. Add after the existing "Paste" menu item:

```harbour
   MENUSEPARATOR OF oEdit
   MENUITEM "Form Undo"  OF oEdit ACTION FormUndo()
```

Then add a helper function near the other static functions:

```harbour
static function FormUndo()
   if oDesignForm != nil
      UI_FormUndo( oDesignForm:hCpp )
      InspectorRefresh( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil
```

- [ ] **Step 4: Wire UndoPush into destructive operations**

In `samples/hbbuilder_linux.prg`, modify `OnComponentDrop` to push undo before creating a control. Find the `OnComponentDrop` function (line ~688) and add at the start of the function body:

```harbour
   // Push undo before adding control
   UI_FormUndoPush( hForm )
```

Also modify `AlignControls` (search for `static function AlignControls`) to push undo:

```harbour
static function AlignControls( nMode )
   if oDesignForm != nil
      UI_FormUndoPush( oDesignForm:hCpp )
      UI_FormAlignSelected( oDesignForm:hCpp, nMode )
      InspectorRefresh( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil
```

- [ ] **Step 5: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles without errors. Launch the IDE, drop a control on a form, hit Edit > Form Undo — control position should revert.

- [ ] **Step 6: Commit**

```bash
git add backends/gtk3/gtk3_core.c samples/hbbuilder_linux.prg
git commit -m "feat(linux): add form designer undo/redo (UI_FORMUNDOPUSH, UI_FORMUNDO)"
```

---

### Task 2: Copy/Paste Controls

**Files:**
- Modify: `backends/gtk3/gtk3_core.c` (append after undo code)
- Modify: `samples/hbbuilder_linux.prg` (add menu items)

- [ ] **Step 1: Add clipboard data structures and HB_FUNC exports**

Append to `backends/gtk3/gtk3_core.c` after the undo section:

```c
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
      /* Allocate appropriate control type */
      HBControl * c = NULL;
      int t = s_clipboard[i].nType;
      int sz = sizeof(HBControl);

      if( t == CT_LABEL )         sz = sizeof(HBLabel);
      else if( t == CT_EDIT )     sz = sizeof(HBEdit);
      else if( t == CT_BUTTON )   sz = sizeof(HBButton);
      else if( t == CT_CHECKBOX ) sz = sizeof(HBCheckBox);
      else if( t == CT_COMBOBOX ) sz = sizeof(HBComboBox);
      else if( t == CT_GROUPBOX ) sz = sizeof(HBGroupBox);

      c = (HBControl *) calloc( 1, sz );
      if( !c ) continue;
      HBControl_Init( c );
      c->FControlType = t;
      c->FLeft   = s_clipboard[i].nLeft + 16;
      c->FTop    = s_clipboard[i].nTop + 16;
      c->FWidth  = s_clipboard[i].nWidth;
      c->FHeight = s_clipboard[i].nHeight;
      strncpy( c->FText, s_clipboard[i].szText, sizeof(c->FText) - 1 );

      /* Set class name based on type */
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

      /* Select the pasted control */
      if( pForm->FSelCount < MAX_CHILDREN )
         pForm->FSelected[pForm->FSelCount++] = c;
   }

   /* Redraw */
   if( pForm->FOverlay )
      gtk_widget_queue_draw( pForm->FOverlay );

   hb_retni( s_clipCount );
}

/* UI_FormGetClipCount() --> nCount */
HB_FUNC( UI_FORMGETCLIPCOUNT )
{
   hb_retni( s_clipCount );
}
```

- [ ] **Step 2: Add Copy/Paste menu items to IDE sample**

In `samples/hbbuilder_linux.prg`, after the "Form Undo" menu item in the Edit menu, add:

```harbour
   MENUITEM "Copy Controls"  OF oEdit ACTION CopyControls()
   MENUITEM "Paste Controls" OF oEdit ACTION PasteControls()
```

Add the helper functions:

```harbour
static function CopyControls()
   if oDesignForm != nil
      UI_FormCopySelected( oDesignForm:hCpp )
   endif
return nil

static function PasteControls()
   if oDesignForm != nil .and. UI_FormGetClipCount() > 0
      UI_FormPasteControls( oDesignForm:hCpp )
      InspectorRefresh( oDesignForm:hCpp )
      InspectorPopulateCombo( oDesignForm:hCpp )
      SyncDesignerToCode()
   endif
return nil
```

- [ ] **Step 3: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles. Drop 2 controls, select them, Edit > Copy Controls, Edit > Paste Controls — new controls appear at +16px offset.

- [ ] **Step 4: Commit**

```bash
git add backends/gtk3/gtk3_core.c samples/hbbuilder_linux.prg
git commit -m "feat(linux): add copy/paste controls (UI_FORMCOPYSELECTED, UI_FORMPASTECONTROLS, UI_FORMGETCLIPCOUNT)"
```

---

### Task 3: Show Find Bar

**Files:**
- Modify: `backends/gtk3/gtk3_core.c` (add HB_FUNC wrapper)

- [ ] **Step 1: Add CODEEDITORSHOWFINDBAR**

The find bar already exists in GTK3 (the `CE_ShowFindBar` static function at line 3697). We just need to expose it as an HB_FUNC. Append after the existing `CODEEDITORBRINGTOFRONT` function (line ~4815):

```c
/* CodeEditorShowFindBar( hEditor, lReplace ) — show/focus find bar */
HB_FUNC( CODEEDITORSHOWFINDBAR )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   int bReplace = HB_ISLOG(2) ? hb_parl(2) : 0;
   if( ed ) CE_ShowFindBar( ed, 1, bReplace );
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles. Calling `CodeEditorShowFindBar( hCodeEditor )` from Harbour shows the find bar.

- [ ] **Step 3: Commit**

```bash
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): expose CodeEditorShowFindBar HB_FUNC"
```

---

### Task 4: Editor Error Messages Panel

**Files:**
- Modify: `backends/gtk3/gtk3_core.c` (extend CODEEDITOR struct + add 3 HB_FUNCs)
- Modify: `samples/hbbuilder_linux.prg` (use error messages after build)

- [ ] **Step 1: Extend the CODEEDITOR struct**

In `backends/gtk3/gtk3_core.c`, find the CODEEDITOR struct (line ~3457-3479). Add message panel fields before the closing `}`:

```c
   /* Message/Error panel */
   GtkWidget *    msgPanel;      /* GtkScrolledWindow containing msgTree */
   GtkWidget *    msgTree;       /* GtkTreeView for messages */
   GtkListStore * msgStore;      /* columns: icon, line, col, message, file */
   GtkWidget *    msgVBox;       /* outer VBox containing editor + msg panel */
```

- [ ] **Step 2: Create the message panel in CODEEDITORCREATE**

In the `CODEEDITORCREATE` function (line ~3875), after the find bar is created and before the window is shown, add the messages panel. Find the line `gtk_widget_hide( findBox );` (line ~4003) and add after it:

```c
      /* --- Messages/Error panel --- */
      {
         GtkWidget * msgScroll = gtk_scrolled_window_new( NULL, NULL );
         gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(msgScroll),
            GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC );
         gtk_widget_set_size_request( msgScroll, -1, 120 );

         ed->msgStore = gtk_list_store_new( 5,
            G_TYPE_STRING,  /* 0: type (Error/Warning/Info) */
            G_TYPE_STRING,  /* 1: line */
            G_TYPE_STRING,  /* 2: col */
            G_TYPE_STRING,  /* 3: message */
            G_TYPE_STRING   /* 4: file */
         );

         ed->msgTree = gtk_tree_view_new_with_model( GTK_TREE_MODEL(ed->msgStore) );
         g_object_unref( ed->msgStore );

         GtkCellRenderer * ren = gtk_cell_renderer_text_new();
         gtk_tree_view_append_column( GTK_TREE_VIEW(ed->msgTree),
            gtk_tree_view_column_new_with_attributes( "Type", ren, "text", 0, NULL ) );
         gtk_tree_view_append_column( GTK_TREE_VIEW(ed->msgTree),
            gtk_tree_view_column_new_with_attributes( "Line", ren, "text", 1, NULL ) );
         gtk_tree_view_append_column( GTK_TREE_VIEW(ed->msgTree),
            gtk_tree_view_column_new_with_attributes( "Message", ren, "text", 3, NULL ) );
         gtk_tree_view_append_column( GTK_TREE_VIEW(ed->msgTree),
            gtk_tree_view_column_new_with_attributes( "File", ren, "text", 4, NULL ) );

         gtk_container_add( GTK_CONTAINER(msgScroll), ed->msgTree );
         gtk_box_pack_start( GTK_BOX(vbox), msgScroll, FALSE, FALSE, 0 );
         ed->msgPanel = msgScroll;

         /* Double-click on error row → go to line */
         g_signal_connect( ed->msgTree, "row-activated",
            G_CALLBACK(on_msg_row_activated), ed );

         gtk_widget_show_all( msgScroll );
         gtk_widget_hide( msgScroll );  /* hidden by default */
      }
```

- [ ] **Step 3: Add the row-activated callback**

Add before CODEEDITORCREATE (or just after CE_ShowFindBar):

```c
static void on_msg_row_activated( GtkTreeView * tv, GtkTreePath * path,
   GtkTreeViewColumn * col, gpointer data )
{
   CODEEDITOR * ed = (CODEEDITOR *)data;
   GtkTreeIter iter;

   if( !ed || !ed->sciWidget ) return;
   if( !gtk_tree_model_get_iter( GTK_TREE_MODEL(ed->msgStore), &iter, path ) ) return;

   gchar * sLine = NULL;
   gtk_tree_model_get( GTK_TREE_MODEL(ed->msgStore), &iter, 1, &sLine, -1 );
   if( sLine ) {
      int nLine = atoi( sLine ) - 1;  /* Scintilla is 0-based */
      if( nLine >= 0 )
         SciMsg( ed->sciWidget, 2024 /* SCI_GOTOLINE */, nLine, 0 );
      g_free( sLine );
   }
}
```

- [ ] **Step 4: Add the three HB_FUNC exports**

Append after CODEEDITORSHOWFINDBAR:

```c
/* CodeEditorClearMessages( hEditor ) */
HB_FUNC( CODEEDITORCLEARMESSAGES )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->msgStore ) return;
   gtk_list_store_clear( ed->msgStore );
   if( ed->msgPanel )
      gtk_widget_hide( ed->msgPanel );
}

/* CodeEditorAddMessage( hEditor, cFile, nLine, cType, cMessage ) */
HB_FUNC( CODEEDITORADDMESSAGE )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->msgStore ) return;

   const char * file = HB_ISCHAR(2) ? hb_parc(2) : "";
   int nLine = HB_ISNUM(3) ? hb_parni(3) : 0;
   const char * type = HB_ISCHAR(4) ? hb_parc(4) : "";
   const char * msg  = HB_ISCHAR(5) ? hb_parc(5) : "";

   char sLine[16];
   snprintf( sLine, sizeof(sLine), "%d", nLine );

   GtkTreeIter iter;
   gtk_list_store_append( ed->msgStore, &iter );
   gtk_list_store_set( ed->msgStore, &iter,
      0, type, 1, sLine, 2, "", 3, msg, 4, file, -1 );

   /* Show the panel */
   if( ed->msgPanel )
      gtk_widget_show( ed->msgPanel );
}

/* CodeEditorParseErrors( hEditor, cOutput ) — parse Harbour + gcc error output */
HB_FUNC( CODEEDITORPARSEERRORS )
{
   CODEEDITOR * ed = (CODEEDITOR *)(HB_PTRUINT) hb_parnint(1);
   if( !ed || !ed->msgStore || !HB_ISCHAR(2) ) return;

   const char * output = hb_parc(2);
   int nErrors = 0;

   const char * p = output;
   while( *p )
   {
      const char * eol = p;
      while( *eol && *eol != '\n' ) eol++;

      int lineLen = (int)(eol - p);
      if( lineLen > 0 && lineLen < 1024 )
      {
         char line[1024];
         memcpy( line, p, lineLen );
         line[lineLen] = 0;

         /* Pattern 1: Harbour — "file.prg(123) Error E0020  description" */
         char * paren = strchr( line, '(' );
         if( paren && strstr( line, "Error" ) )
         {
            *paren = 0;
            int nLine = atoi( paren + 1 );
            char * desc = strstr( paren + 1, "Error" );
            if( desc ) {
               GtkTreeIter iter;
               char sLine[16]; snprintf( sLine, sizeof(sLine), "%d", nLine );
               gtk_list_store_append( ed->msgStore, &iter );
               gtk_list_store_set( ed->msgStore, &iter,
                  0, "Error", 1, sLine, 2, "", 3, desc, 4, line, -1 );
               nErrors++;
            }
         }
         /* Pattern 1b: Harbour — "file.prg(123) Warning W0001  description" */
         else if( paren && strstr( line, "Warning" ) )
         {
            *paren = 0;
            int nLine = atoi( paren + 1 );
            char * desc = strstr( paren + 1, "Warning" );
            if( desc ) {
               GtkTreeIter iter;
               char sLine[16]; snprintf( sLine, sizeof(sLine), "%d", nLine );
               gtk_list_store_append( ed->msgStore, &iter );
               gtk_list_store_set( ed->msgStore, &iter,
                  0, "Warning", 1, sLine, 2, "", 3, desc, 4, line, -1 );
            }
         }
         /* Pattern 2: gcc/clang — "file.c:123:45: error: description" */
         else if( strstr( line, ": error:" ) || strstr( line, ": warning:" ) )
         {
            char * colon1 = strchr( line, ':' );
            if( colon1 ) {
               *colon1 = 0;
               int nLine = atoi( colon1 + 1 );
               char * typeStr = strstr( colon1 + 1, "error:" );
               if( !typeStr ) typeStr = strstr( colon1 + 1, "warning:" );
               if( typeStr ) {
                  const char * tName = ( typeStr[0] == 'e' ) ? "Error" : "Warning";
                  GtkTreeIter iter;
                  char sLine[16]; snprintf( sLine, sizeof(sLine), "%d", nLine );
                  gtk_list_store_append( ed->msgStore, &iter );
                  gtk_list_store_set( ed->msgStore, &iter,
                     0, tName, 1, sLine, 2, "", 3, typeStr, 4, line, -1 );
                  nErrors++;
               }
            }
         }
      }

      p = ( *eol == '\n' ) ? eol + 1 : eol;
   }

   if( nErrors > 0 && ed->msgPanel )
      gtk_widget_show( ed->msgPanel );

   hb_retni( nErrors );
}
```

- [ ] **Step 5: Wire into the IDE sample**

In `samples/hbbuilder_linux.prg`, find the View menu (line ~98-104) and add:

```harbour
   MENUITEM "Messages"          OF oView ACTION ToggleMessages()
```

Add the helper:

```harbour
static function ToggleMessages()
   // Toggle visibility of the message panel
   // (The panel shows/hides automatically on build; this is a manual toggle)
   if hCodeEditor != nil
      CodeEditorClearMessages( hCodeEditor )
   endif
return nil
```

Then modify `TBRun()` to parse errors. Find `static function TBRun()` and after the build command execution, add:

```harbour
   // After build, parse output for errors
   CodeEditorClearMessages( hCodeEditor )
   if ! Empty( cBuildOutput )
      CodeEditorParseErrors( hCodeEditor, cBuildOutput )
   endif
```

- [ ] **Step 6: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles. Messages panel appears below editor when errors are found during build. Clicking an error row jumps to the line.

- [ ] **Step 7: Commit**

```bash
git add backends/gtk3/gtk3_core.c samples/hbbuilder_linux.prg
git commit -m "feat(linux): add editor error messages panel (CODEEDITORADDMESSAGE, CODEEDITORCLEARMESSAGES, CODEEDITORPARSEERRORS)"
```

---

### Task 5: Tab Order Dialog

**Files:**
- Modify: `backends/gtk3/gtk3_core.c` (add HB_FUNC)
- Modify: `samples/hbbuilder_linux.prg` (add menu item)

- [ ] **Step 1: Add UI_FORMTABORDERDIALOG to gtk3_core.c**

Append after the clipboard section:

```c
/* ======================================================================
 * Tab Order Dialog
 * ====================================================================== */

/* UI_FormTabOrderDialog( hForm ) — show modal dialog to reorder controls */
HB_FUNC( UI_FORMTABORDERDIALOG )
{
   HBForm * pForm = GetForm(1);
   if( !pForm || pForm->base.FChildCount == 0 ) return;

   EnsureGTK();

   GtkWidget * dialog = gtk_dialog_new_with_buttons( "Tab Order",
      pForm->FWindow ? GTK_WINDOW(pForm->FWindow) : NULL,
      GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
      "OK", GTK_RESPONSE_OK,
      "Cancel", GTK_RESPONSE_CANCEL,
      NULL );

   GtkWidget * content = gtk_dialog_get_content_area( GTK_DIALOG(dialog) );

   /* List store: index, display text */
   GtkListStore * store = gtk_list_store_new( 2, G_TYPE_INT, G_TYPE_STRING );
   GtkWidget * tree = gtk_tree_view_new_with_model( GTK_TREE_MODEL(store) );

   GtkCellRenderer * ren = gtk_cell_renderer_text_new();
   gtk_tree_view_append_column( GTK_TREE_VIEW(tree),
      gtk_tree_view_column_new_with_attributes( "Control (Tab Order)", ren, "text", 1, NULL ) );

   /* Copy children to a temp order array */
   int n = pForm->base.FChildCount;
   int * order = (int *) malloc( n * sizeof(int) );
   for( int i = 0; i < n; i++ ) order[i] = i;

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

   /* Up/Down buttons */
   GtkWidget * hbox = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 4 );
   GtkWidget * btnUp = gtk_button_new_with_label( "Move Up" );
   GtkWidget * btnDown = gtk_button_new_with_label( "Move Down" );
   gtk_box_pack_start( GTK_BOX(hbox), btnUp, FALSE, FALSE, 4 );
   gtk_box_pack_start( GTK_BOX(hbox), btnDown, FALSE, FALSE, 4 );

   gtk_box_pack_start( GTK_BOX(content), scroll, TRUE, TRUE, 4 );
   gtk_box_pack_start( GTK_BOX(content), hbox, FALSE, FALSE, 4 );
   gtk_widget_show_all( content );

   /* Simple swap logic via signal data */
   typedef struct { GtkTreeView * tv; GtkListStore * st; int * ord; int n; } TabDlgData;
   TabDlgData tdd = { GTK_TREE_VIEW(tree), store, order, n };

   /* We use a simple approach: run the dialog in a loop, handling Up/Down
      via custom response codes */
   gtk_dialog_add_button( GTK_DIALOG(dialog), "Up", 100 );
   gtk_dialog_add_button( GTK_DIALOG(dialog), "Down", 101 );

   /* Actually, simpler: just run the dialog once and accept the current order.
      For a proper Up/Down we need signal handlers. Let's use a loop: */
   int done = 0;
   while( !done )
   {
      gint resp = gtk_dialog_run( GTK_DIALOG(dialog) );
      if( resp == GTK_RESPONSE_OK )
      {
         /* Apply the order: reorder FChildren */
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
               /* Swap in order array */
               int tmp = order[idx]; order[idx] = order[idx-1]; order[idx-1] = tmp;
               /* Rebuild list */
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
      else /* Cancel or close */
         done = 1;
   }

   free( order );
   g_object_unref( store );
   gtk_widget_destroy( dialog );
}
```

- [ ] **Step 2: Add Tab Order menu item to IDE sample**

In `samples/hbbuilder_linux.prg`, add to the Format menu (after "Space Evenly Vertical", line ~133):

```harbour
   MENUSEPARATOR OF oFormat
   MENUITEM "Tab Order..."  OF oFormat ACTION ShowTabOrder()
```

Add the helper:

```harbour
static function ShowTabOrder()
   if oDesignForm != nil
      UI_FormTabOrderDialog( oDesignForm:hCpp )
   endif
return nil
```

- [ ] **Step 3: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles. Format > Tab Order opens a dialog showing controls. Up/Down buttons reorder. OK applies the new order.

- [ ] **Step 4: Commit**

```bash
git add backends/gtk3/gtk3_core.c samples/hbbuilder_linux.prg
git commit -m "feat(linux): add Tab Order dialog (UI_FORMTABORDERDIALOG)"
```

---

## Phase B: Additional Controls

### Task 6: RadioButton Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c` (add struct + UI_RADIOBUTTONNEW + extend UI_GETALLPROPS/UI_SETPROP)

- [ ] **Step 1: Add RadioButton struct**

In `backends/gtk3/gtk3_core.c`, after the HBComboBox struct (line ~253), add:

```c
typedef struct { HBControl base; int FChecked; char FGroupName[32]; } HBRadioButton;
```

- [ ] **Step 2: Add UI_RADIOBUTTONNEW**

After `UI_GROUPBOXNEW` (line ~2004), add:

```c
HB_FUNC( UI_RADIOBUTTONNEW )
{
   HBForm * pForm = GetForm(1);
   HBRadioButton * p = (HBRadioButton *) calloc( 1, sizeof(HBRadioButton) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TRadioButton" );
   p->base.FControlType = CT_RADIO; p->base.FWidth = 150; p->base.FHeight = 19;
   p->FChecked = 0;
   memset( p->FGroupName, 0, sizeof(p->FGroupName) );
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}
```

- [ ] **Step 3: Extend UI_GETALLPROPS for RadioButton**

In the `switch( p->FControlType )` block inside `UI_GETALLPROPS` (line ~2367-2401), add a case before the closing `}`:

```c
      case CT_RADIO:
         ADD_L("lChecked",((HBRadioButton*)p)->FChecked,"Data");
         ADD_S("cGroupName",((HBRadioButton*)p)->FGroupName,"Behavior");
         break;
```

- [ ] **Step 4: Extend UI_SETPROP for RadioButton**

In `UI_SETPROP` (line ~2008), find the property setters and add handling for RadioButton properties. After the existing checkbox handling, add:

```c
   else if( strcasecmp( szProp, "cGroupName" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_RADIO )
   {
      strncpy( ((HBRadioButton*)p)->FGroupName, hb_parc(3), 31 );
   }
```

- [ ] **Step 5: Extend RealizeControl for RadioButton**

In the `RealizeControl` function (the function that creates actual GTK widgets when a form is shown), find the control-type switch and add:

```c
      case CT_RADIO: {
         GtkWidget * rb = gtk_check_button_new_with_label( p->FText );
         /* GTK3 doesn't have GtkRadioButton in a simple way for design mode;
            use check button with radio appearance via CSS */
         p->FWidget = rb;
         break;
      }
```

- [ ] **Step 6: Update OnComponentDrop in hbbuilder_linux.prg**

In `samples/hbbuilder_linux.prg`, find the `OnComponentDrop` function (line ~688). The function already uses `UI_CreateControl` which handles control creation generically. The palette already registers RadioButton with type 8 (CT_RADIO) at line 238. Verify this works by checking that the `otherwise` case in `RegenerateFormCode` (line ~558) handles unknown types with a comment.

Add a specific case for RadioButton in the code generation `do case` block (line ~533-562):

```harbour
            case nType == 8
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' RADIOBUTTON ::o' + cCtrlName + ' PROMPT "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + e
```

- [ ] **Step 7: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles. Dropping a RadioButton from palette creates a radio button on the form. Inspector shows Checked and GroupName properties.

- [ ] **Step 8: Commit**

```bash
git add backends/gtk3/gtk3_core.c samples/hbbuilder_linux.prg
git commit -m "feat(linux): add RadioButton control (UI_RADIOBUTTONNEW)"
```

---

### Task 7: BitBtn Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add BitBtn struct**

After the HBRadioButton typedef, add:

```c
typedef struct {
   HBControl base;
   char FGlyph[256];    /* path to image file */
   int  FLayout;        /* 0=left, 1=right, 2=top, 3=bottom */
   int  FSpacing;
} HBBitBtn;
```

- [ ] **Step 2: Add UI_BITBTNNEW**

After `UI_RADIOBUTTONNEW`, add:

```c
HB_FUNC( UI_BITBTNNEW )
{
   HBForm * pForm = GetForm(1);
   HBBitBtn * p = (HBBitBtn *) calloc( 1, sizeof(HBBitBtn) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TBitBtn" );
   p->base.FControlType = CT_BITBTN; p->base.FWidth = 88; p->base.FHeight = 26;
   p->FLayout = 0; p->FSpacing = 4;
   memset( p->FGlyph, 0, sizeof(p->FGlyph) );
   if( HB_ISCHAR(2) ) HBControl_SetText( &p->base, hb_parc(2) );
   if( HB_ISNUM(3) ) p->base.FLeft = hb_parni(3);   if( HB_ISNUM(4) ) p->base.FTop = hb_parni(4);
   if( HB_ISNUM(5) ) p->base.FWidth = hb_parni(5);  if( HB_ISNUM(6) ) p->base.FHeight = hb_parni(6);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}
```

- [ ] **Step 3: Extend UI_GETALLPROPS**

Add case in the switch:

```c
      case CT_BITBTN: {
         HBBitBtn * bb = (HBBitBtn*)p;
         ADD_S("cGlyph",bb->FGlyph,"Appearance");
         ADD_N("nLayout",bb->FLayout,"Appearance");
         ADD_N("nSpacing",bb->FSpacing,"Appearance");
         break;
      }
```

- [ ] **Step 4: Extend UI_SETPROP**

Add property setters:

```c
   else if( strcasecmp( szProp, "cGlyph" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_BITBTN )
      strncpy( ((HBBitBtn*)p)->FGlyph, hb_parc(3), 255 );
   else if( strcasecmp( szProp, "nLayout" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BITBTN )
      ((HBBitBtn*)p)->FLayout = hb_parni(3);
   else if( strcasecmp( szProp, "nSpacing" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BITBTN )
      ((HBBitBtn*)p)->FSpacing = hb_parni(3);
```

- [ ] **Step 5: Build and verify**

Run: `cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5`

Expected: Compiles. BitBtn palette entry (type 12) creates a button. Inspector shows Glyph, Layout, Spacing.

- [ ] **Step 6: Commit**

```bash
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add BitBtn control (UI_BITBTNNEW)"
```

---

### Task 8: Image Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add Image struct and UI_IMAGENEW**

```c
typedef struct {
   HBControl base;
   char FPicture[256];  /* path to image file */
   int  FStretch;
   int  FCenter;
   int  FProportional;
} HBImage;

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
```

- [ ] **Step 2: Extend UI_GETALLPROPS**

```c
      case CT_IMAGE: {
         HBImage * img = (HBImage*)p;
         ADD_S("cPicture",img->FPicture,"Data");
         ADD_L("lStretch",img->FStretch,"Appearance");
         ADD_L("lCenter",img->FCenter,"Appearance");
         ADD_L("lProportional",img->FProportional,"Appearance");
         break;
      }
```

- [ ] **Step 3: Extend UI_SETPROP**

```c
   else if( strcasecmp( szProp, "cPicture" ) == 0 && HB_ISCHAR(3) && p->FControlType == CT_IMAGE )
      strncpy( ((HBImage*)p)->FPicture, hb_parc(3), 255 );
   else if( strcasecmp( szProp, "lStretch" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_IMAGE )
      ((HBImage*)p)->FStretch = hb_parl(3);
   else if( strcasecmp( szProp, "lCenter" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_IMAGE )
      ((HBImage*)p)->FCenter = hb_parl(3);
   else if( strcasecmp( szProp, "lProportional" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_IMAGE )
      ((HBImage*)p)->FProportional = hb_parl(3);
```

- [ ] **Step 4: Build, verify, commit**

```bash
cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add Image control (UI_IMAGENEW)"
```

---

### Task 9: Shape Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add Shape struct and UI_SHAPENEW**

```c
typedef struct {
   HBControl base;
   int  FShape;       /* 0=rect, 1=circle, 2=rounded, 3=ellipse */
   int  FPenColor;
   int  FPenWidth;
   int  FBrushColor;
} HBShape;

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
```

- [ ] **Step 2: Extend UI_GETALLPROPS**

```c
      case CT_SHAPE: {
         HBShape * sh = (HBShape*)p;
         ADD_N("nShape",sh->FShape,"Appearance");
         ADD_C("nPenColor",sh->FPenColor,"Appearance");
         ADD_N("nPenWidth",sh->FPenWidth,"Appearance");
         ADD_C("nBrushColor",sh->FBrushColor,"Appearance");
         break;
      }
```

- [ ] **Step 3: Extend UI_SETPROP**

```c
   else if( strcasecmp( szProp, "nShape" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FShape = hb_parni(3);
   else if( strcasecmp( szProp, "nPenColor" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FPenColor = hb_parni(3);
   else if( strcasecmp( szProp, "nPenWidth" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FPenWidth = hb_parni(3);
   else if( strcasecmp( szProp, "nBrushColor" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_SHAPE )
      ((HBShape*)p)->FBrushColor = hb_parni(3);
```

- [ ] **Step 4: Build, verify, commit**

```bash
cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add Shape control (UI_SHAPENEW)"
```

---

### Task 10: Bevel Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add Bevel struct and UI_BEVELNEW**

```c
typedef struct {
   HBControl base;
   int  FBevelStyle;   /* 0=raised, 1=lowered */
   int  FBevelShape;   /* 0=box, 1=frame, 2=topLine, 3=bottomLine */
} HBBevel;

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
```

- [ ] **Step 2: Extend UI_GETALLPROPS**

```c
      case CT_BEVEL: {
         HBBevel * bv = (HBBevel*)p;
         ADD_N("nBevelStyle",bv->FBevelStyle,"Appearance");
         ADD_N("nBevelShape",bv->FBevelShape,"Appearance");
         break;
      }
```

- [ ] **Step 3: Extend UI_SETPROP**

```c
   else if( strcasecmp( szProp, "nBevelStyle" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BEVEL )
      ((HBBevel*)p)->FBevelStyle = hb_parni(3);
   else if( strcasecmp( szProp, "nBevelShape" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BEVEL )
      ((HBBevel*)p)->FBevelShape = hb_parni(3);
```

- [ ] **Step 4: Build, verify, commit**

```bash
cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add Bevel control (UI_BEVELNEW)"
```

---

### Task 11: RichEdit Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add RichEdit struct and UI_RICHEDITNEW**

```c
typedef struct {
   HBControl base;
   int  FReadOnly;
   int  FWordWrap;
   int  FScrollBars;  /* 0=none, 1=horiz, 2=vert, 3=both */
} HBRichEdit;

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
```

- [ ] **Step 2: Extend UI_GETALLPROPS**

```c
      case CT_RICHEDIT: {
         HBRichEdit * re = (HBRichEdit*)p;
         ADD_L("lReadOnly",re->FReadOnly,"Behavior");
         ADD_L("lWordWrap",re->FWordWrap,"Behavior");
         ADD_N("nScrollBars",re->FScrollBars,"Appearance");
         break;
      }
```

- [ ] **Step 3: Extend UI_SETPROP**

```c
   else if( strcasecmp( szProp, "lWordWrap" ) == 0 && HB_ISLOG(3) && p->FControlType == CT_RICHEDIT )
      ((HBRichEdit*)p)->FWordWrap = hb_parl(3);
   else if( strcasecmp( szProp, "nScrollBars" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_RICHEDIT )
      ((HBRichEdit*)p)->FScrollBars = hb_parni(3);
```

- [ ] **Step 4: Build, verify, commit**

```bash
cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add RichEdit control (UI_RICHEDITNEW)"
```

---

### Task 12: ListView Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add ListView struct and UI_LISTVIEWNEW**

```c
typedef struct {
   HBControl base;
   int  FViewStyle;    /* 0=icon, 1=smallIcon, 2=list, 3=report */
   int  FGridLines;
   int  FColumnCount;
   char FColumns[16][64];   /* column headers */
   int  FColumnWidths[16];
} HBListView;

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

/* UI_ListViewAddColumn( hListView, cTitle, nWidth ) */
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
```

- [ ] **Step 2: Extend UI_GETALLPROPS**

```c
      case CT_LISTVIEW: {
         HBListView * lv = (HBListView*)p;
         ADD_N("nViewStyle",lv->FViewStyle,"Appearance");
         ADD_L("lGridLines",lv->FGridLines,"Appearance");
         ADD_N("nColumnCount",lv->FColumnCount,"Data");
         break;
      }
```

- [ ] **Step 3: Build, verify, commit**

```bash
cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add ListView control (UI_LISTVIEWNEW, UI_LISTVIEWADDCOLUMN)"
```

---

### Task 13: Browse (Data Grid) Control

**Files:**
- Modify: `backends/gtk3/gtk3_core.c`

- [ ] **Step 1: Add Browse struct and UI_BROWSENEW**

```c
typedef struct {
   HBControl base;
   int  FReadOnly;
   int  FGridLines;
   int  FRowHeight;
   int  FColumnCount;
   char FColumns[16][64];
   int  FColumnWidths[16];
   char FColumnTypes[16];  /* S=string, N=number, L=logical, D=date */
} HBBrowse;

HB_FUNC( UI_BROWSENEW )
{
   HBForm * pForm = GetForm(1);
   HBBrowse * p = (HBBrowse *) calloc( 1, sizeof(HBBrowse) );
   HBControl_Init( &p->base );
   strcpy( p->base.FClassName, "TBrowse" );
   p->base.FControlType = CT_BROWSE; p->base.FWidth = 300; p->base.FHeight = 200;
   p->FReadOnly = 0; p->FGridLines = 1; p->FRowHeight = 22; p->FColumnCount = 0;
   memset( p->FColumns, 0, sizeof(p->FColumns) );
   memset( p->FColumnWidths, 0, sizeof(p->FColumnWidths) );
   memset( p->FColumnTypes, 'S', sizeof(p->FColumnTypes) );
   if( HB_ISNUM(2) ) p->base.FLeft = hb_parni(2);   if( HB_ISNUM(3) ) p->base.FTop = hb_parni(3);
   if( HB_ISNUM(4) ) p->base.FWidth = hb_parni(4);  if( HB_ISNUM(5) ) p->base.FHeight = hb_parni(5);
   if( pForm ) HBControl_AddChild( &pForm->base, &p->base );
   KeepAlive( &p->base );
   RetCtrl( &p->base );
}

/* UI_BrowseAddCol( hBrowse, cTitle, nWidth, cType ) */
HB_FUNC( UI_BROWSEADDCOL )
{
   HBControl * p = GetCtrl(1);
   if( !p || p->FControlType != CT_BROWSE ) return;
   HBBrowse * br = (HBBrowse*)p;
   if( br->FColumnCount >= 16 ) return;
   if( HB_ISCHAR(2) )
      strncpy( br->FColumns[br->FColumnCount], hb_parc(2), 63 );
   br->FColumnWidths[br->FColumnCount] = HB_ISNUM(3) ? hb_parni(3) : 100;
   br->FColumnTypes[br->FColumnCount] = HB_ISCHAR(4) ? hb_parc(4)[0] : 'S';
   br->FColumnCount++;
}
```

- [ ] **Step 2: Extend UI_GETALLPROPS**

```c
      case CT_BROWSE: {
         HBBrowse * br = (HBBrowse*)p;
         ADD_L("lReadOnly",br->FReadOnly,"Behavior");
         ADD_L("lGridLines",br->FGridLines,"Appearance");
         ADD_N("nRowHeight",br->FRowHeight,"Appearance");
         ADD_N("nColumnCount",br->FColumnCount,"Data");
         break;
      }
```

- [ ] **Step 3: Extend UI_SETPROP**

```c
   else if( strcasecmp( szProp, "nRowHeight" ) == 0 && HB_ISNUM(3) && p->FControlType == CT_BROWSE )
      ((HBBrowse*)p)->FRowHeight = hb_parni(3);
   else if( strcasecmp( szProp, "lGridLines" ) == 0 && HB_ISLOG(3) &&
            ( p->FControlType == CT_BROWSE || p->FControlType == CT_LISTVIEW ) )
   {
      if( p->FControlType == CT_BROWSE ) ((HBBrowse*)p)->FGridLines = hb_parl(3);
      else ((HBListView*)p)->FGridLines = hb_parl(3);
   }
```

- [ ] **Step 4: Build, verify, commit**

```bash
cd /home/anto/harbourbuilder && ./build_scintilla.sh 2>&1 | tail -5
git add backends/gtk3/gtk3_core.c
git commit -m "feat(linux): add Browse data grid control (UI_BROWSENEW, UI_BROWSEADDCOL)"
```

---

### Task 14: Update ChangeLog

**Files:**
- Modify: `ChangeLog.txt`

- [ ] **Step 1: Add entry to ChangeLog.txt**

Add at the top of `ChangeLog.txt`:

```
2026-04-05 - Linux GTK3 parity with macOS/Windows
  Phase A (macOS parity):
  - Form designer Undo/Redo (UI_FORMUNDOPUSH, UI_FORMUNDO)
  - Copy/Paste controls (UI_FORMCOPYSELECTED, UI_FORMPASTECONTROLS, UI_FORMGETCLIPCOUNT)
  - CodeEditorShowFindBar exposed as HB_FUNC
  - Editor error messages panel (CODEEDITORADDMESSAGE, CODEEDITORCLEARMESSAGES, CODEEDITORPARSEERRORS)
  - Tab Order dialog (UI_FORMTABORDERDIALOG)

  Phase B (additional controls from Win32):
  - RadioButton (UI_RADIOBUTTONNEW)
  - BitBtn (UI_BITBTNNEW) with Glyph, Layout, Spacing
  - Image (UI_IMAGENEW) with Picture, Stretch, Center, Proportional
  - Shape (UI_SHAPENEW) with Shape type, PenColor, BrushColor
  - Bevel (UI_BEVELNEW) with BevelStyle, BevelShape
  - RichEdit (UI_RICHEDITNEW) with WordWrap, ScrollBars
  - ListView (UI_LISTVIEWNEW, UI_LISTVIEWADDCOLUMN)
  - Browse data grid (UI_BROWSENEW, UI_BROWSEADDCOL)

```

- [ ] **Step 2: Commit**

```bash
git add ChangeLog.txt
git commit -m "docs: update ChangeLog with Linux GTK3 parity work"
```
