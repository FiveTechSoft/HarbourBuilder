# Windows IDE — macOS Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Windows IDE up to feature parity with the macOS IDE for all features added in sessions 28–32.

**Architecture:** All changes are in 3 files: `source/hbbuilder_win.prg` (autocomplete, code gen, save prompt), `source/cpp/hbbridge.cpp` (browse column bridge functions), and `source/inspector/inspector_win.prg` (combo map, column selection, arrow keys). The Windows code already has the C++ infrastructure (TBrowse with FCols, Scintilla editor with tab text storage) — we're wiring up the Harbour/IDE layer on top.

**Tech Stack:** Harbour PRG, C (Win32 API, Scintilla), C++ (TBrowse/TControl)

---

### Task 1: Save prompt before New/Open

**Files:**
- Modify: `source/cpp/hbbridge.cpp` — add `HB_FUNC( MSGYESNOCANCEL )`
- Modify: `source/hbbuilder_win.prg:1421-1465` — `TBNew()` add save prompt
- Modify: `source/hbbuilder_win.prg:1610-1632` — `TBOpen()` add save prompt

- [ ] **Step 1: Add MsgYesNoCancel to hbbridge.cpp**

In `source/cpp/hbbridge.cpp`, after the existing `UI_MSGYESNO` function (around line 4018 of hbbuilder_win.prg — but this one is in hbbridge.cpp), add:

```c
/* MsgYesNoCancel( cText, cTitle ) -> 0=Cancel, 1=Yes, 2=No */
HB_FUNC( MSGYESNOCANCEL )
{
   int nResult = MessageBoxA( GetActiveWindow(),
      hb_parc(1),
      HB_ISCHAR(2) ? hb_parc(2) : "Confirm",
      MB_YESNOCANCEL | MB_ICONQUESTION );
   switch( nResult ) {
      case IDYES:    hb_retni( 1 ); break;
      case IDNO:     hb_retni( 2 ); break;
      default:       hb_retni( 0 ); break;  /* IDCANCEL or closed */
   }
}
```

- [ ] **Step 2: Add save prompt to TBNew()**

In `source/hbbuilder_win.prg`, modify `TBNew()` (line 1421). Add after the local declarations and before "Destroy all existing forms":

```harbour
   // Ask to save current work if there are forms open
   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before creating a new one?", "HbBuilder" )
      if nAns == 0  // Cancel
         return nil
      elseif nAns == 1  // Yes
         TBSave()
      endif
   endif
```

Add `nAns` to the `local` declaration on line 1423.

- [ ] **Step 3: Add save prompt to TBOpen()**

In `source/hbbuilder_win.prg`, modify `TBOpen()` (line 1610). Add after `local` declarations (line 1613) and before the file dialog call:

```harbour
   local nAns

   // Ask to save current work if there are forms open
   if Len( aForms ) > 0
      nAns := MsgYesNoCancel( "Save current project before opening?", "HbBuilder" )
      if nAns == 0  // Cancel
         return nil
      elseif nAns == 1  // Yes
         TBSave()
      endif
   endif
```

- [ ] **Step 4: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit**

```bash
git add source/cpp/hbbridge.cpp source/hbbuilder_win.prg
git commit -m "feat(Windows): save prompt before New/Open (macOS parity)"
```

---

### Task 2: IsNonVisual + code generation for Browse, TCompArray, TDbfTable

**Files:**
- Modify: `source/hbbuilder_win.prg:655-860` — `RegenerateFormCode()` 

This task adds:
- `IsNonVisual()` helper function
- `ComponentTypeName()` helper function  
- Browse HEADERS + COLSIZES code generation
- TCompArray property serialization
- TDbfTable cRDD property serialization
- Memo control code generation (currently missing)
- Proper non-visual COMPONENT syntax for all component types >= 38

- [ ] **Step 1: Add IsNonVisual() and ComponentTypeName() functions**

Add at the end of `source/hbbuilder_win.prg` (before the final `#pragma ENDDUMP` or at end of Harbour section):

```harbour
static function IsNonVisual( nType )
   // Visual controls that have high CT_* numbers
   // CT_BROWSE=79, CT_DBGRID=80, CT_DBNAVIGATOR=81, CT_DBTEXT=82,
   // CT_DBEDIT=83, CT_DBCOMBOBOX=84, CT_DBCHECKBOX=85, CT_DBIMAGE=86,
   // CT_WEBVIEW=62
   if nType == 62 .or. ( nType >= 79 .and. nType <= 86 )
      return .F.
   endif
return nType >= 38

static function ComponentTypeName( nType )
   do case
      case nType == 38;  return "CT_TIMER"
      case nType == 39;  return "CT_PAINTBOX"
      case nType == 40;  return "CT_OPENDIALOG"
      case nType == 41;  return "CT_SAVEDIALOG"
      case nType == 42;  return "CT_FONTDIALOG"
      case nType == 43;  return "CT_COLORDIALOG"
      case nType == 44;  return "CT_FINDDIALOG"
      case nType == 45;  return "CT_REPLACEDIALOG"
      case nType == 53;  return "CT_DBFTABLE"
      case nType == 54;  return "CT_MYSQL"
      case nType == 55;  return "CT_MARIADB"
      case nType == 56;  return "CT_POSTGRESQL"
      case nType == 57;  return "CT_SQLITE"
      case nType == 58;  return "CT_FIREBIRD"
      case nType == 59;  return "CT_SQLSERVER"
      case nType == 60;  return "CT_ORACLE"
      case nType == 61;  return "CT_MONGODB"
      case nType == 62;  return "CT_WEBVIEW"
      case nType == 63;  return "CT_WEBSERVER"
      case nType == 64;  return "CT_WEBSOCKET"
      case nType == 65;  return "CT_HTTPCLIENT"
      case nType == 131; return "CT_COMPARRAY"
   endcase
return "CT_UNKNOWN_" + LTrim( Str( nType ) )
```

- [ ] **Step 2: Rewrite the control code generation in RegenerateFormCode()**

Replace the `otherwise` case (line 778-781) in the `do case` block inside `RegenerateFormCode()` with proper handling. The full `do case` block for control creation (starting ~line 714) should be updated:

After the existing `case nType == 23  // RichEdit` block, add these new cases **before** `otherwise`:

```harbour
            case nType == 9   // Memo
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' MEMO ::o' + cCtrlName + ' VAR "' + cText + '" OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH)) + e
            case nType == 79  // Browse
               cCreate += '   @ ' + LTrim(Str(nT)) + ", " + LTrim(Str(nL)) + ;
                  ' BROWSE ::o' + cCtrlName + ' OF Self SIZE ' + ;
                  LTrim(Str(nCW)) + ", " + LTrim(Str(nCH))
               cVal := UI_GetProp( hCtrl, "aColumns" )
               if ! Empty( cVal )
                  aHdrs := hb_ATokens( cVal, "|" )
                  cCreate += ' HEADERS '
                  for kk := 1 to Len( aHdrs )
                     if kk > 1; cCreate += ', '; endif
                     cCreate += '"' + AllTrim( aHdrs[kk] ) + '"'
                  next
               endif
               // Column widths
               nColCount := UI_BrowseColCount( hCtrl )
               if nColCount > 0
                  cCreate += ' COLSIZES '
                  for kk := 1 to nColCount
                     if kk > 1; cCreate += ', '; endif
                     aColProps := UI_BrowseGetColProps( hCtrl, kk - 1 )
                     nColW := 100
                     if Len( aColProps ) >= 3; nColW := aColProps[3][2]; endif
                     cCreate += LTrim( Str( nColW ) )
                  next
               endif
               cCreate += e
               cVal := UI_GetProp( hCtrl, "cDataSource" )
               if ! Empty( cVal )
                  cCreate += '   ::o' + cCtrlName + ':cDataSource := "' + cVal + '"' + e
               endif
```

Replace the `otherwise` block with:

```harbour
            otherwise
               if IsNonVisual( nType )
                  cCreate += '   COMPONENT ::o' + cCtrlName + ' TYPE ' + ;
                     ComponentTypeName( nType ) + ' OF Self  // ' + cCtrlClass + e
                  // DBFTable properties
                  if nType == 53
                     cVal := UI_GetProp( hCtrl, "cFileName" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':cFileName := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "cRDD" )
                     if ! Empty( cVal ) .and. Upper( cVal ) != "DBFCDX"
                        cCreate += '   ::o' + cCtrlName + ':cRDD := "' + cVal + '"' + e
                     endif
                     if UI_GetProp( hCtrl, "lActive" )
                        cCreate += '   ::o' + cCtrlName + ':Open()' + e
                     endif
                  elseif nType == 131  // CompArray
                     cVal := UI_GetProp( hCtrl, "aHeaders" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':aHeaders := "' + cVal + '"' + e
                     endif
                     cVal := UI_GetProp( hCtrl, "aData" )
                     if ! Empty( cVal )
                        cCreate += '   ::o' + cCtrlName + ':aData := "' + cVal + '"' + e
                     endif
                  endif
               else
                  cCreate += '   // ::o' + cCtrlName + ' (' + cCtrlClass + ') at ' + ;
                     LTrim(Str(nL)) + ',' + LTrim(Str(nT)) + ' SIZE ' + ;
                     LTrim(Str(nCW)) + ',' + LTrim(Str(nCH)) + e
               endif
```

Add these local vars to `RegenerateFormCode()` declaration (line 665):
```harbour
   local cVal, aHdrs, kk, nColCount, aColProps, nColW
```

- [ ] **Step 3: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit**

```bash
git add source/hbbuilder_win.prg
git commit -m "feat(Windows): IsNonVisual, Browse HEADERS/COLSIZES, TCompArray, cRDD code gen"
```

---

### Task 3: Browse column bridge functions

**Files:**
- Modify: `source/cpp/hbbridge.cpp` — add `UI_BROWSECOLCOUNT`, `UI_BROWSEGETCOLPROPS`, `UI_BROWSESETCOLPROP`

These functions let Harbour code query and modify individual browse column properties.

- [ ] **Step 1: Add the three browse column functions to hbbridge.cpp**

Add after the existing `UI_BROWSEREFRESH` function (around line 514):

```c
/* UI_BrowseColCount( hBrowse ) -> nCols */
HB_FUNC( UI_BROWSECOLCOUNT )
{
   TControl * p = (TControl *) hb_parnint(1);
   if( p && p->FControlType == CT_BROWSE )
      hb_retni( ((TBrowse *)p)->FColCount );
   else
      hb_retni( 0 );
}

/* UI_BrowseGetColProps( hBrowse, nCol ) -> { {"cTitle",val}, {"cFieldName",val}, {"nWidth",val}, {"nAlign",val}, {"cFooterText",val} } */
HB_FUNC( UI_BROWSEGETCOLPROPS )
{
   TControl * p = (TControl *) hb_parnint(1);
   int nCol = hb_parni(2);
   if( p && p->FControlType == CT_BROWSE )
   {
      TBrowse * br = (TBrowse *) p;
      if( nCol >= 0 && nCol < br->FColCount )
      {
         PHB_ITEM aResult = hb_itemArrayNew( 5 );
         PHB_ITEM aPair;

         /* 1: cTitle */
         aPair = hb_itemArrayNew( 2 );
         hb_arraySetC( aPair, 1, "cTitle" );
         hb_arraySetC( aPair, 2, br->FCols[nCol].szTitle );
         hb_arraySet( aResult, 1, aPair );
         hb_itemRelease( aPair );

         /* 2: cFieldName */
         aPair = hb_itemArrayNew( 2 );
         hb_arraySetC( aPair, 1, "cFieldName" );
         hb_arraySetC( aPair, 2, br->FCols[nCol].szFieldName );
         hb_arraySet( aResult, 2, aPair );
         hb_itemRelease( aPair );

         /* 3: nWidth */
         aPair = hb_itemArrayNew( 2 );
         hb_arraySetC( aPair, 1, "nWidth" );
         hb_arraySetNI( aPair, 2, br->FCols[nCol].nWidth );
         hb_arraySet( aResult, 3, aPair );
         hb_itemRelease( aPair );

         /* 4: nAlign */
         aPair = hb_itemArrayNew( 2 );
         hb_arraySetC( aPair, 1, "nAlign" );
         hb_arraySetNI( aPair, 2, br->FCols[nCol].nAlign );
         hb_arraySet( aResult, 4, aPair );
         hb_itemRelease( aPair );

         /* 5: cFooterText */
         aPair = hb_itemArrayNew( 2 );
         hb_arraySetC( aPair, 1, "cFooterText" );
         hb_arraySetC( aPair, 2, br->FCols[nCol].szFooterText );
         hb_arraySet( aResult, 5, aPair );
         hb_itemRelease( aPair );

         hb_itemReturnRelease( aResult );
         return;
      }
   }
   hb_reta( 0 );
}

/* UI_BrowseSetColProp( hBrowse, nCol, cPropName, xValue ) */
HB_FUNC( UI_BROWSESETCOLPROP )
{
   TControl * p = (TControl *) hb_parnint(1);
   int nCol = hb_parni(2);
   const char * szProp = hb_parc(3);
   if( !p || p->FControlType != CT_BROWSE || !szProp ) return;

   TBrowse * br = (TBrowse *) p;
   if( nCol < 0 || nCol >= br->FColCount ) return;

   if( lstrcmpiA( szProp, "cTitle" ) == 0 && HB_ISCHAR(4) )
   {
      lstrcpynA( br->FCols[nCol].szTitle, hb_parc(4), 64 );
      /* Update ListView column header if handle exists */
      if( br->FHandle )
      {
         LVCOLUMNA lvc = {0};
         lvc.mask = LVCF_TEXT;
         lvc.pszText = br->FCols[nCol].szTitle;
         SendMessageA( br->FHandle, LVM_SETCOLUMNA, nCol, (LPARAM)&lvc );
      }
   }
   else if( lstrcmpiA( szProp, "nWidth" ) == 0 )
   {
      br->FCols[nCol].nWidth = hb_parni(4);
      if( br->FHandle )
         SendMessageA( br->FHandle, LVM_SETCOLUMNWIDTH, nCol, br->FCols[nCol].nWidth );
   }
   else if( lstrcmpiA( szProp, "nAlign" ) == 0 )
   {
      br->FCols[nCol].nAlign = hb_parni(4);
   }
   else if( lstrcmpiA( szProp, "cFieldName" ) == 0 && HB_ISCHAR(4) )
   {
      lstrcpynA( br->FCols[nCol].szFieldName, hb_parc(4), 64 );
   }
   else if( lstrcmpiA( szProp, "cFooterText" ) == 0 && HB_ISCHAR(4) )
   {
      lstrcpynA( br->FCols[nCol].szFooterText, hb_parc(4), 64 );
   }
}
```

- [ ] **Step 2: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit**

```bash
git add source/cpp/hbbridge.cpp
git commit -m "feat(Windows): UI_BrowseColCount/GetColProps/SetColProp bridge functions"
```

---

### Task 4: Inspector browse column support + arrow keys

**Files:**
- Modify: `source/inspector/inspector_win.prg` — add combo map, column enumeration, InspectorRefreshColumn, arrow key navigation, event handler resolution

- [ ] **Step 1: Add combo map storage and EXTERNAL declarations**

At the top of `source/inspector/inspector_win.prg` (before `function InspectorOpen`), add:

```harbour
// Force symbol registration for C functions called via hb_dynsymFindName
EXTERNAL UI_BROWSESETCOLPROP
EXTERNAL UI_BROWSEGETCOLPROPS
EXTERNAL UI_BROWSECOLCOUNT
```

Add combo map static storage in the `#pragma BEGINDUMP` section (after `s_insData`):

```c
static PHB_ITEM s_comboMap = NULL;
static PHB_ITEM s_editorCode = NULL;

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
HB_FUNC( _INSSETEDITORCODE ) {
   if( s_editorCode ) hb_itemRelease( s_editorCode );
   s_editorCode = hb_itemClone( hb_param(1, HB_IT_STRING) );
}
HB_FUNC( _INSGETEDITORCODE ) {
   if( s_editorCode )
      hb_itemReturn( s_editorCode );
   else
      hb_retc( "" );
}
```

- [ ] **Step 2: Update InspectorRefresh to resolve event handlers**

Replace the current `InspectorRefresh` function with:

```harbour
function InspectorRefresh( hCtrl, hForm )
   local h := _InsGetData()
   local aProps, aEvents
   local i, cName, cHandler, cCode
   if h != 0
      if hCtrl != nil .and. hCtrl != 0
         aProps  := UI_GetAllProps( hCtrl )
         aEvents := UI_GetAllEvents( hCtrl )

         // Resolve handler names from editor code
         cCode := _InsGetEditorCode()
         cName := UI_GetProp( hCtrl, "cName" )
         if Empty( cName )
            if UI_GetProp( hCtrl, "cClassName" ) == "TForm"
               cName := "Form1"
            else
               cName := "ctrl"
            endif
         endif
         if ! Empty( cCode ) .and. ! Empty( aEvents )
            for i := 1 to Len( aEvents )
               if Len( aEvents[i] ) >= 3 .and. ! Empty( aEvents[i][1] )
                  cHandler := cName + SubStr( aEvents[i][1], 3 )
                  if ( "function " + cHandler ) $ cCode
                     aEvents[i][2] := cHandler
                  endif
               endif
            next
         endif

         INS_RefreshWithData( h, hCtrl, aProps )
         INS_SetEvents( h, aEvents )
      else
         INS_RefreshWithData( h, 0, {} )
         INS_SetEvents( h, {} )
      endif
   endif
return nil
```

- [ ] **Step 3: Update InspectorPopulateCombo to include browse columns**

Replace the current `InspectorPopulateCombo` function with:

```harbour
// Populate combo with all controls from the design form
// Combo map: maps combo index -> { nType, hCtrl, nColIdx }
//   nType: 0=form, 1=control, 2=browse column
function InspectorPopulateCombo( hForm )
   local h := _InsGetData()
   local i, j, nCount, hChild, cName, cClass, cEntry, nColCount
   local aMap

   if h == 0 .or. hForm == 0
      return nil
   endif

   INS_ComboClear( h )
   INS_SetFormCtrl( h, hForm )
   aMap := {}

   // Add the form itself: "oForm1 AS TForm1"
   cName  := UI_GetProp( hForm, "cName" )
   cClass := UI_GetProp( hForm, "cClassName" )
   if Empty( cName ); cName := "Form1"; endif
   cEntry := "o" + cName + " AS T" + cName
   INS_ComboAdd( h, cEntry )
   AAdd( aMap, { 0, hForm, 0 } )

   // Add all child controls: "oButton1 AS TButton"
   nCount := UI_GetChildCount( hForm )
   for i := 1 to nCount
      hChild := UI_GetChild( hForm, i )
      if hChild != 0
         cName  := UI_GetProp( hChild, "cName" )
         cClass := UI_GetProp( hChild, "cClassName" )
         if Empty( cName ); cName := "ctrl" + LTrim( Str( i ) ); endif
         cEntry := "o" + cName + " AS " + cClass
         INS_ComboAdd( h, cEntry )
         AAdd( aMap, { 1, hChild, 0 } )

         // If it's a Browse, add its columns as sub-entries
         if UI_GetType( hChild ) == 79  // CT_BROWSE
            nColCount := UI_BrowseColCount( hChild )
            for j := 1 to nColCount
               cEntry := "  o" + cName + "Col" + LTrim( Str( j ) ) + " AS TBrwColumn"
               INS_ComboAdd( h, cEntry )
               AAdd( aMap, { 2, hChild, j - 1 } )  // 0-based col index
            next
         endif
      endif
   next

   _InsSetComboMap( aMap )

   // Select form (first entry)
   INS_ComboSelect( h, 0 )

return nil

function InspectorGetComboMap()
return _InsGetComboMap()
```

- [ ] **Step 4: Add InspectorRefreshColumn function**

Add after `InspectorGetComboMap`:

```harbour
// Refresh inspector showing column properties
function InspectorRefreshColumn( hBrowse, nCol )
   local h := _InsGetData()
   local aProps
   if h != 0 .and. hBrowse != 0
      aProps := UI_BrowseGetColProps( hBrowse, nCol )
      if ! Empty( aProps )
         INS_RefreshWithData( h, hBrowse, aProps )
         INS_SetEvents( h, {} )  // Columns have no events
      endif
   endif
return nil
```

- [ ] **Step 5: Add nBrowseCol field and arrow key navigation in C code**

In the `INSDATA` struct in the C section, add after `int nActiveTab`:

```c
   int    nBrowseCol;  /* -1 = not editing column, >= 0 = column index */
```

Initialize it to -1 in `INS_Create`.

In the `InsWndProc` `WM_NOTIFY` handler, add arrow key handling for the property list. After the existing `NM_CLICK` handler for idFrom==100, add:

```c
         /* Arrow key navigation: skip category rows */
         if( pnm->code == LVN_ITEMCHANGED && pnm->idFrom == 100 )
         {
            NMLISTVIEW * pnlv = (NMLISTVIEW *) lParam;
            if( d && (pnlv->uNewState & LVIS_SELECTED) && !(pnlv->uOldState & LVIS_SELECTED) )
            {
               int nRow = pnlv->iItem;
               if( nRow >= 0 && nRow < d->nVisible )
               {
                  int nReal = d->map[nRow];
                  if( d->rows[nReal].bIsCat )
                  {
                     /* Find next non-category row in the direction of movement */
                     int next = nRow + 1;
                     if( next < d->nVisible && !d->rows[d->map[next]].bIsCat )
                        ListView_SetItemState( d->hList, next, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED );
                     else if( nRow > 0 )
                        ListView_SetItemState( d->hList, nRow - 1, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED );
                     ListView_SetItemState( d->hList, nRow, 0, LVIS_SELECTED|LVIS_FOCUSED );
                  }
               }
            }
         }
```

- [ ] **Step 6: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 7: Commit**

```bash
git add source/inspector/inspector_win.prg
git commit -m "feat(Windows): browse columns in inspector, combo map, arrow key navigation"
```

---

### Task 5: Cross-file autocomplete with class member resolution

**Files:**
- Modify: `source/hbbuilder_win.prg` — add class member table, `:` key handler, cross-file resolution

This is the largest task. It adds:
- `s_classMembers[]` lookup table (same as macOS)
- `CE_FindClassMembers()` — resolve class name to member list
- `CE_FindCurrentClass()` — scan backwards for CLASS declaration
- `CE_ResolveVarClass()` — 4 strategies to determine class from variable name
- `CE_FindClassInText()` / `CE_CollectUserDataFromText()` — cross-file search
- `CE_CollectUserData()` — collect DATA/METHOD from current editor
- `:` key handler in SCN_CHARADDED to trigger member autocomplete

- [ ] **Step 1: Add s_classMembers table**

In `source/hbbuilder_win.prg`, in the `#pragma BEGINDUMP` C section, before `CE_ShowAutoComplete` (around line 5722), add the class member table:

```c
/* ======================================================================
 * Class member autocomplete — triggered when ':' is typed
 * ====================================================================== */

typedef struct {
   const char * className;
   const char * members;      /* space-separated, methods have () suffix */
} ClassMembers;

static ClassMembers s_classMembers[] = {
   { "TForm",
     "Activate() AlphaBlend AlphaBlendValue AppBar AutoScroll BorderIcons "
     "BorderStyle BorderWidth ClientHeight ClientWidth Close() Color Cursor "
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
     "Height Left Name OnChange OnClick OnClose OnTimer Text Top Width" },
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
```

- [ ] **Step 2: Add helper functions for class resolution**

Add after the `s_classMembers` table:

```c
/* Collect DATA/ACCESS/METHOD member names from a CLASS definition.
 * Scans from classLine+1 until ENDCLASS. Returns chars written to buf. */
static int CE_CollectUserData( HWND hSci, int classLine, char * buf, int bufSize )
{
   int pos = 0;
   int totalLines = (int) SciMsg( hSci, 2009, 0, 0 ); /* SCI_GETLINECOUNT */
   int l;
   for( l = classLine + 1; l < totalLines; l++ )
   {
      char line[512];
      int len = (int) SciMsg( hSci, 2094, l, 0 ); /* SCI_LINELENGTH */
      const char * p;
      int isData, isMethod;
      char name[64];
      int ni;

      if( len <= 0 || len >= (int)sizeof(line) ) continue;
      SciMsg( hSci, 2095, l, (LPARAM)line ); /* SCI_GETLINE */
      line[len] = 0;

      p = line;
      while( *p == ' ' || *p == '\t' || *p == '\r' || *p == '\n' ) p++;
      if( *p == 0 ) continue;

      if( _strnicmp( p, "ENDCLASS", 8 ) == 0 ) break;

      isData = ( _strnicmp( p, "DATA ", 5 ) == 0 );
      isMethod = ( _strnicmp( p, "METHOD ", 7 ) == 0 ) ||
                 ( _strnicmp( p, "ACCESS ", 7 ) == 0 );
      if( !isData && !isMethod ) continue;

      if( isData ) p += 5; else p += 7;
      while( *p == ' ' ) p++;

      ni = 0;
      while( ni < 63 && (isalnum((unsigned char)p[ni]) || p[ni] == '_') )
         { name[ni] = p[ni]; ni++; }
      name[ni] = 0;
      if( ni == 0 ) continue;

      /* Append "()" for methods */
      if( isMethod && ni < 61 ) { name[ni++] = '('; name[ni++] = ')'; name[ni] = 0; }

      if( pos > 0 && pos < bufSize - 1 ) buf[pos++] = ' ';
      if( ni > bufSize - pos - 1 ) break;
      memcpy( buf + pos, name, (size_t)ni );
      pos += ni;
   }
   buf[pos] = 0;
   return pos;
}

/* Search plain text for CLASS declaration matching cls.
 * Returns pointer to CLASS line start, fills parentCls. */
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
         memcpy( line, cur, (size_t)lineLen );
         line[lineLen] = 0;

         p = line;
         while( *p == ' ' || *p == '\t' ) p++;

         if( _strnicmp( p, "CLASS ", 6 ) == 0 )
         {
            char foundCls[64];
            int fi = 0;
            p += 6;
            while( *p == ' ' ) p++;
            while( fi < 63 && (isalnum((unsigned char)p[fi]) || p[fi] == '_') )
               { foundCls[fi] = p[fi]; fi++; }
            foundCls[fi] = 0;

            if( _stricmp( foundCls, cls ) == 0 )
            {
               p += fi;
               while( *p == ' ' ) p++;
               if( _strnicmp( p, "INHERIT ", 8 ) == 0 ) p += 8;
               else if( _strnicmp( p, "FROM ", 5 ) == 0 ) p += 5;
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
            if( _strnicmp( p, "ENDCLASS", 8 ) == 0 ) break;

            isData = ( _strnicmp( p, "DATA ", 5 ) == 0 );
            isMethod = ( _strnicmp( p, "METHOD ", 7 ) == 0 ) ||
                       ( _strnicmp( p, "ACCESS ", 7 ) == 0 );
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

/* Find current CLASS name by scanning backwards from line */
static const char * CE_FindCurrentClass( HWND hSci, int fromLine )
{
   static char s_curClass[64];
   int l;
   for( l = fromLine; l >= 0; l-- )
   {
      char buf[512];
      int len = (int) SciMsg( hSci, 2094, l, 0 );
      const char * cp;
      int ci;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( hSci, 2095, l, (LPARAM)buf );
      buf[len] = 0;
      cp = buf;
      while( *cp == ' ' || *cp == '\t' ) cp++;
      if( _strnicmp( cp, "CLASS ", 6 ) == 0 ) {
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

/* Find class members combining standard + user-defined.
 * Searches current editor then all other tabs. */
static const char * CE_FindClassMembers( CODEEDITOR * ed, const char * cls )
{
   static char s_combined[4096];
   const char * stdMembers = NULL;
   char userMembers[2048] = "";
   int classLine = -1, i, t;

   /* Standard table lookup */
   for( i = 0; s_classMembers[i].className; i++ )
      if( _stricmp( cls, s_classMembers[i].className ) == 0 )
         { stdMembers = s_classMembers[i].members; break; }

   if( !ed || !ed->hEdit ) goto combine;

   /* Search current editor for CLASS definition */
   {
      int totalLines = (int) SciMsg( ed->hEdit, 2009, 0, 0 );
      for( i = 0; i < totalLines; i++ )
      {
         char buf[512];
         int len = (int) SciMsg( ed->hEdit, 2094, i, 0 );
         const char * cp;
         char foundCls[64];
         int fi;
         if( len <= 0 || len >= (int)sizeof(buf) ) continue;
         SciMsg( ed->hEdit, 2095, i, (LPARAM)buf );
         buf[len] = 0;
         cp = buf;
         while( *cp == ' ' || *cp == '\t' ) cp++;
         if( _strnicmp( cp, "CLASS ", 6 ) != 0 ) continue;
         cp += 6;
         while( *cp == ' ' ) cp++;
         fi = 0;
         while( fi < 63 && (isalnum((unsigned char)cp[fi]) || cp[fi] == '_') )
            { foundCls[fi] = cp[fi]; fi++; }
         foundCls[fi] = 0;

         if( _stricmp( foundCls, cls ) == 0 )
         {
            classLine = i;
            /* Check for parent class */
            cp += fi;
            while( *cp == ' ' ) cp++;
            if( _strnicmp( cp, "INHERIT ", 8 ) == 0 ) cp += 8;
            else if( _strnicmp( cp, "FROM ", 5 ) == 0 ) cp += 5;
            else cp = NULL;
            if( cp && !stdMembers ) {
               char parent[64];
               int pi = 0;
               while( *cp == ' ' ) cp++;
               while( pi < 63 && (isalnum((unsigned char)cp[pi]) || cp[pi] == '_') )
                  { parent[pi] = cp[pi]; pi++; }
               parent[pi] = 0;
               for( i = 0; s_classMembers[i].className; i++ )
                  if( _stricmp( parent, s_classMembers[i].className ) == 0 )
                     { stdMembers = s_classMembers[i].members; break; }
            }
            break;
         }
      }

      if( classLine >= 0 )
         CE_CollectUserData( ed->hEdit, classLine, userMembers, sizeof(userMembers) );
   }

   /* If not found, search other tabs */
   if( classLine < 0 )
   {
      for( t = 0; t < ed->nTabs; t++ )
      {
         char parentCls[64];
         const char * classPos;
         if( t == ed->nActiveTab || !ed->aTexts[t] || !ed->aTexts[t][0] ) continue;
         classPos = CE_FindClassInText( ed->aTexts[t], cls, parentCls );
         if( classPos ) {
            CE_CollectUserDataFromText( ed->aTexts[t], classPos, userMembers, sizeof(userMembers) );
            if( parentCls[0] && !stdMembers ) {
               for( i = 0; s_classMembers[i].className; i++ )
                  if( _stricmp( parentCls, s_classMembers[i].className ) == 0 )
                     { stdMembers = s_classMembers[i].members; break; }
            }
            break;
         }
      }
   }

combine:
   if( stdMembers && userMembers[0] ) {
      _snprintf( s_combined, sizeof(s_combined), "%s %s", stdMembers, userMembers );
      return s_combined;
   }
   if( stdMembers ) return stdMembers;
   if( userMembers[0] ) { lstrcpynA( s_combined, userMembers, sizeof(s_combined) ); return s_combined; }
   return NULL;
}
```

- [ ] **Step 3: Add CE_ResolveVarClass (4-strategy variable class resolution)**

Add after `CE_FindClassMembers`:

```c
/* Resolve variable class from context. 4 strategies:
 * 1) Self: -> current CLASS  2) DATA comment  3) := assignment  4) naming convention */
static const char * CE_ResolveVarClass( CODEEDITOR * ed, int colonPos )
{
   static char s_resolved[64];
   int line, lineStart, lineLen;
   char lineBuf[512];
   int end, nameEnd, nameStart, varLen;
   char varName[128];
   int hasDblColon;
   int totalLines, l;

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

   if( !ed || !ed->hEdit ) return NULL;

   line = (int) SciMsg( ed->hEdit, SCI_LINEFROMPOSITION, colonPos, 0 );
   lineStart = (int) SciMsg( ed->hEdit, 2166, line, 0 ); /* SCI_POSITIONFROMLINE */
   lineLen = colonPos - lineStart;
   if( lineLen <= 0 || lineLen > 500 ) return NULL;

   {
      LONG_PTR range[2];
      range[0] = lineStart; range[1] = colonPos;
      /* Use SCI_GETTEXT with target range */
      SciMsg( ed->hEdit, 2160, lineStart, 0 ); /* SCI_SETTARGETSTART */
      SciMsg( ed->hEdit, 2162, colonPos, 0 );  /* SCI_SETTARGETEND */
   }
   /* Get text before colon */
   {
      int i;
      for( i = 0; i < lineLen && i < 511; i++ )
         lineBuf[i] = (char) SciMsg( ed->hEdit, 2007, lineStart + i, 0 ); /* SCI_GETCHARAT */
      lineBuf[i] = 0;
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
   if( _stricmp( varName, "Self" ) == 0 )
      return CE_FindCurrentClass( ed->hEdit, line );

   /* Strategy 1: DATA comment — "DATA oName // TClassName" */
   totalLines = (int) SciMsg( ed->hEdit, 2009, 0, 0 );
   for( l = 0; l < totalLines; l++ )
   {
      char buf[512];
      int len = (int) SciMsg( ed->hEdit, 2094, l, 0 );
      const char * dp, * cmt;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( ed->hEdit, 2095, l, (LPARAM)buf );
      buf[len] = 0;
      dp = buf;
      while( *dp == ' ' || *dp == '\t' ) dp++;
      if( _strnicmp( dp, "DATA ", 5 ) != 0 ) continue;
      dp += 5;
      while( *dp == ' ' ) dp++;
      if( _strnicmp( dp, varName, (size_t)varLen ) != 0 ) continue;
      dp += varLen;
      if( isalnum((unsigned char)*dp) || *dp == '_' ) continue;
      cmt = strstr( dp, "//" );
      if( !cmt ) continue;
      cmt += 2;
      while( *cmt == ' ' ) cmt++;
      if( isalpha((unsigned char)*cmt) ) {
         int ri = 0;
         char rawCls[64];
         while( ri < 63 && (isalnum((unsigned char)cmt[ri]) || cmt[ri] == '_') )
            { rawCls[ri] = cmt[ri]; ri++; }
         rawCls[ri] = 0;
         if( rawCls[0] == 'T' && isupper((unsigned char)rawCls[1]) )
            lstrcpynA( s_resolved, rawCls, 63 );
         else
            _snprintf( s_resolved, 64, "T%s", rawCls );
         return s_resolved;
      }
   }

   /* Strategy 2: assignment pattern — "varName := TClassName():New" */
   for( l = 0; l < totalLines; l++ )
   {
      char buf[512];
      int len = (int) SciMsg( ed->hEdit, 2094, l, 0 );
      const char * vp;
      if( len <= 0 || len >= (int)sizeof(buf) ) continue;
      SciMsg( ed->hEdit, 2095, l, (LPARAM)buf );
      buf[len] = 0;
      vp = strstr( buf, varName );
      if( !vp ) continue;
      vp += varLen;
      while( *vp == ' ' ) vp++;
      if( *vp != ':' || vp[1] != '=' ) continue;
      vp += 2;
      while( *vp == ' ' ) vp++;
      if( *vp == 'T' && isalpha((unsigned char)vp[1]) ) {
         int ci = 0;
         int slen;
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
      return CE_FindCurrentClass( ed->hEdit, line );

   /* Strategy 4: naming convention — oForm→TForm, oButton→TButton */
   {
      const char * base = varName;
      int i;
      if( (base[0] == 'o' || base[0] == 'O') && isupper((unsigned char)base[1]) )
         base++;
      for( i = 0; s_nameMap[i].prefix; i++ ) {
         int plen = (int)strlen( s_nameMap[i].prefix );
         if( _strnicmp( base, s_nameMap[i].prefix, (size_t)plen ) == 0 ) {
            char next = base[plen];
            if( next == 0 || isdigit((unsigned char)next) || isupper((unsigned char)next) || next == '_' ) {
               lstrcpynA( s_resolved, s_nameMap[i].cls, 63 );
               return s_resolved;
            }
         }
      }
   }

   return NULL;
}
```

- [ ] **Step 4: Add `:` key handler in SCN_CHARADDED**

In `source/hbbuilder_win.prg`, in the `SCN_CHARADDED` handler (around line 6095), after the auto-indent block that handles `\n`/`\r`, add:

```c
               /* ':' typed — show class member dropdown */
               else if( scn->ch == ':' )
               {
                  int pos = (int) SciMsg( ed->hEdit, SCI_GETCURRENTPOS, 0, 0 );
                  const char * cls = CE_ResolveVarClass( ed, pos - 1 );
                  if( cls )
                  {
                     const char * members = CE_FindClassMembers( ed, cls );
                     if( members )
                     {
                        SciMsg( ed->hEdit, SCI_AUTOCSETIGNORECASE, 1, 0 );
                        SciMsg( ed->hEdit, SCI_AUTOCSETSEPARATOR, ' ', 0 );
                        SciMsg( ed->hEdit, 2235, 1, 0 );  /* SCI_AUTOCSETORDER = SC_ORDER_PERFORMSORT */
                        SciMsg( ed->hEdit, SCI_AUTOCSHOW, 0, (LPARAM) members );
                     }
                  }
               }
```

The `else if` connects to the existing `if( scn->ch == '\n' || scn->ch == '\r' )` block on line 6097.

- [ ] **Step 5: Build and verify**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 6: Commit**

```bash
git add source/hbbuilder_win.prg
git commit -m "feat(Windows): cross-file autocomplete with class member resolution"
```

---

### Task 6: Final build + ChangeLog + push

**Files:**
- Modify: `ChangeLog.txt`

- [ ] **Step 1: Update ChangeLog**

Add entry at the top of `ChangeLog.txt`:

```
2026-04-09 (Session 33: Windows — macOS parity: autocomplete, inspector, code gen)

  CROSS-FILE AUTOCOMPLETE:
  - ':' after variable triggers class member dropdown (Self:, oForm:, ::member)
  - 4 resolution strategies: Self, DATA comment, assignment pattern, naming convention
  - Searches all open editor tabs for CLASS definitions (cross-file)
  - Methods show with () suffix, properties without
  - s_classMembers table with 22 standard classes

  INSPECTOR — BROWSE COLUMNS:
  - Browse columns appear as "oBrowse1Col1 AS TBrwColumn" in inspector combo
  - Selecting a column shows editable properties: cTitle, nWidth, nAlign, cFieldName, cFooterText
  - New bridge functions: UI_BrowseColCount, UI_BrowseGetColProps, UI_BrowseSetColProp
  - Combo map tracks form/control/column entries
  - Arrow keys skip category rows in property grid

  CODE GENERATION:
  - Browse: HEADERS + COLSIZES clauses with per-column widths
  - IsNonVisual() classifies component types (CT_BROWSE/DBGRID/WEBVIEW are visual)
  - COMPONENT syntax for non-visual types (Timer, Database, etc.)
  - TDbfTable: cFileName, cRDD, Open() serialization
  - TCompArray: aHeaders, aData serialization
  - Memo control code generation

  SAVE PROMPT:
  - MsgYesNoCancel before New Application / Open Project
  - Offers Save / Don't Save / Cancel

  EVENT HANDLERS:
  - InspectorRefresh resolves handler names from editor code
```

- [ ] **Step 2: Final build**

Run: `cmd //c "c:\HarbourBuilder\build_win.bat"` (select compiler 1)
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit and push**

```bash
git add -A
git commit -m "feat(Windows): macOS parity — autocomplete, browse inspector, code gen, save prompt"
git push
```
