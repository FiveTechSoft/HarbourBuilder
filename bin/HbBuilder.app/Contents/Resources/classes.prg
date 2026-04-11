// classes.prg - Harbour OOP wrappers over C++ core
// User-facing classes: TForm, TLabel, TEdit, TButton, TCheckBox, TComboBox, TGroupBox

#include "hbclass.ch"
#include "hbide.ch"

#ifdef __PLATFORM__WINDOWS
EXTERNAL UI_STORECLRPANE
EXTERNAL UI_HASHANDLE
#endif

//----------------------------------------------------------------------------//
// TControl - Base class
//----------------------------------------------------------------------------//

CLASS TControl

   DATA hCpp    INIT 0
   DATA oParent INIT nil

   ACCESS Name      INLINE UI_GetProp( ::hCpp, "cName" )
   ASSIGN Name( c ) INLINE UI_SetProp( ::hCpp, "cName", c )

   ACCESS Left      INLINE UI_GetProp( ::hCpp, "nLeft" )
   ASSIGN Left( n ) INLINE UI_SetProp( ::hCpp, "nLeft", n )

   ACCESS Top       INLINE UI_GetProp( ::hCpp, "nTop" )
   ASSIGN Top( n )  INLINE UI_SetProp( ::hCpp, "nTop", n )

   ACCESS Width     INLINE UI_GetProp( ::hCpp, "nWidth" )
   ASSIGN Width( n ) INLINE UI_SetProp( ::hCpp, "nWidth", n )

   ACCESS Height    INLINE UI_GetProp( ::hCpp, "nHeight" )
   ASSIGN Height( n ) INLINE UI_SetProp( ::hCpp, "nHeight", n )

   ACCESS Text      INLINE UI_GetProp( ::hCpp, "cText" )
   ASSIGN Text( c ) INLINE UI_SetProp( ::hCpp, "cText", c )

   ASSIGN OnClick( b )  INLINE UI_OnEvent( ::hCpp, "OnClick", b )
   ASSIGN OnChange( b ) INLINE UI_OnEvent( ::hCpp, "OnChange", b )
   ASSIGN OnClose( b )  INLINE UI_OnEvent( ::hCpp, "OnClose", b )

   // Font (compound property: "FontName,Size")
   ACCESS oFont            INLINE UI_GetProp( ::hCpp, "oFont" )
   ASSIGN oFont( c )       INLINE UI_SetProp( ::hCpp, "oFont", c )

   // Color / nClrPane (available on all controls, not just forms)
   ACCESS Color            INLINE UI_GetProp( ::hCpp, "nClrPane" )
   ASSIGN Color( n )       INLINE UI_SetProp( ::hCpp, "nClrPane", n )
   ACCESS nClrPane         INLINE UI_GetProp( ::hCpp, "nClrPane" )
   ASSIGN nClrPane( n )    INLINE UI_SetProp( ::hCpp, "nClrPane", n )

ENDCLASS

//----------------------------------------------------------------------------//
// TForm
//----------------------------------------------------------------------------//

CLASS TForm INHERIT TControl

   // Title (alias for Text - C++Builder uses Caption/Title)
   ACCESS Title         INLINE UI_GetProp( ::hCpp, "cText" )
   ASSIGN Title( c )    INLINE UI_SetProp( ::hCpp, "cText", c )

   // AppTitle (application menu name on macOS, window title on Windows)
   ACCESS AppTitle      INLINE UI_GetProp( ::hCpp, "cAppTitle" )
   ASSIGN AppTitle( c ) INLINE UI_SetProp( ::hCpp, "cAppTitle", c )

   // Font
   ACCESS FontName      INLINE UI_GetProp( ::hCpp, "cFontName" )
   ASSIGN FontName( c ) INLINE UI_SetProp( ::hCpp, "cFontName", c )

   ACCESS FontSize      INLINE UI_GetProp( ::hCpp, "nFontSize" )
   ASSIGN FontSize( n ) INLINE UI_SetProp( ::hCpp, "nFontSize", n )

   // Window appearance
   ACCESS BorderStyle      INLINE UI_GetProp( ::hCpp, "nBorderStyle" )
   ASSIGN BorderStyle( n ) INLINE UI_SetProp( ::hCpp, "nBorderStyle", n )

   ACCESS BorderIcons      INLINE UI_GetProp( ::hCpp, "nBorderIcons" )
   ASSIGN BorderIcons( n ) INLINE UI_SetProp( ::hCpp, "nBorderIcons", n )

   ACCESS BorderWidth      INLINE UI_GetProp( ::hCpp, "nBorderWidth" )
   ASSIGN BorderWidth( n ) INLINE UI_SetProp( ::hCpp, "nBorderWidth", n )

   ACCESS Position         INLINE UI_GetProp( ::hCpp, "nPosition" )
   ASSIGN Position( n )    INLINE UI_SetProp( ::hCpp, "nPosition", n )

   ACCESS WindowState      INLINE UI_GetProp( ::hCpp, "nWindowState" )
   ASSIGN WindowState( n ) INLINE UI_SetProp( ::hCpp, "nWindowState", n )

   ACCESS FormStyle        INLINE UI_GetProp( ::hCpp, "nFormStyle" )
   ASSIGN FormStyle( n )   INLINE UI_SetProp( ::hCpp, "nFormStyle", n )

   ACCESS Cursor           INLINE UI_GetProp( ::hCpp, "nCursor" )
   ASSIGN Cursor( n )      INLINE UI_SetProp( ::hCpp, "nCursor", n )

   // Behavior
   ACCESS Sizable       INLINE UI_GetProp( ::hCpp, "lSizable" )
   ASSIGN Sizable( l )  INLINE UI_SetProp( ::hCpp, "lSizable", l )

   ACCESS AppBar        INLINE UI_GetProp( ::hCpp, "lAppBar" )
   ASSIGN AppBar( l )   INLINE UI_SetProp( ::hCpp, "lAppBar", l )

   ACCESS ToolWindow    INLINE UI_GetProp( ::hCpp, "lToolWindow" )
   ASSIGN ToolWindow( l ) INLINE UI_SetProp( ::hCpp, "lToolWindow", l )

   ACCESS KeyPreview       INLINE UI_GetProp( ::hCpp, "lKeyPreview" )
   ASSIGN KeyPreview( l )  INLINE UI_SetProp( ::hCpp, "lKeyPreview", l )

   ACCESS ShowHint         INLINE UI_GetProp( ::hCpp, "lShowHint" )
   ASSIGN ShowHint( l )    INLINE UI_SetProp( ::hCpp, "lShowHint", l )

   ACCESS Hint             INLINE UI_GetProp( ::hCpp, "cHint" )
   ASSIGN Hint( c )        INLINE UI_SetProp( ::hCpp, "cHint", c )

   ACCESS AutoScroll       INLINE UI_GetProp( ::hCpp, "lAutoScroll" )
   ASSIGN AutoScroll( l )  INLINE UI_SetProp( ::hCpp, "lAutoScroll", l )

   ACCESS DoubleBuffered       INLINE UI_GetProp( ::hCpp, "lDoubleBuffered" )
   ASSIGN DoubleBuffered( l )  INLINE UI_SetProp( ::hCpp, "lDoubleBuffered", l )

   // Transparency
   ACCESS AlphaBlend          INLINE UI_GetProp( ::hCpp, "lAlphaBlend" )
   ASSIGN AlphaBlend( l )     INLINE UI_SetProp( ::hCpp, "lAlphaBlend", l )

   ACCESS AlphaBlendValue     INLINE UI_GetProp( ::hCpp, "nAlphaBlendValue" )
   ASSIGN AlphaBlendValue( n ) INLINE UI_SetProp( ::hCpp, "nAlphaBlendValue", n )

   // Read-only
   ACCESS ClientWidth    INLINE UI_GetProp( ::hCpp, "nClientWidth" )
   ACCESS ClientHeight   INLINE UI_GetProp( ::hCpp, "nClientHeight" )
   ACCESS ModalResult    INLINE UI_FormResult( ::hCpp )

   // Events
   ASSIGN OnActivate( b )   INLINE UI_OnEvent( ::hCpp, "OnActivate", b )
   ASSIGN OnDeactivate( b ) INLINE UI_OnEvent( ::hCpp, "OnDeactivate", b )
   ASSIGN OnResize( b )     INLINE UI_OnEvent( ::hCpp, "OnResize", b )
   ASSIGN OnPaint( b )      INLINE UI_OnEvent( ::hCpp, "OnPaint", b )
   ASSIGN OnShow( b )       INLINE UI_OnEvent( ::hCpp, "OnShow", b )
   ASSIGN OnHide( b )       INLINE UI_OnEvent( ::hCpp, "OnHide", b )
   ASSIGN OnCloseQuery( b ) INLINE UI_OnEvent( ::hCpp, "OnCloseQuery", b )
   ASSIGN OnCreate( b )     INLINE UI_OnEvent( ::hCpp, "OnCreate", b )
   ASSIGN OnDestroy( b )    INLINE UI_OnEvent( ::hCpp, "OnDestroy", b )
   ASSIGN OnKeyDown( b )    INLINE UI_OnEvent( ::hCpp, "OnKeyDown", b )
   ASSIGN OnKeyUp( b )      INLINE UI_OnEvent( ::hCpp, "OnKeyUp", b )
   ASSIGN OnKeyPress( b )   INLINE UI_OnEvent( ::hCpp, "OnKeyPress", b )
   ASSIGN OnMouseDown( b )  INLINE UI_OnEvent( ::hCpp, "OnMouseDown", b )
   ASSIGN OnMouseUp( b )    INLINE UI_OnEvent( ::hCpp, "OnMouseUp", b )
   ASSIGN OnMouseMove( b )  INLINE UI_OnEvent( ::hCpp, "OnMouseMove", b )
   ASSIGN OnDblClick( b )   INLINE UI_OnEvent( ::hCpp, "OnDblClick", b )
   ASSIGN OnMouseWheel( b ) INLINE UI_OnEvent( ::hCpp, "OnMouseWheel", b )

   // Methods
   METHOD New( cTitle, nWidth, nHeight )
   METHOD Activate()
   METHOD Show()       INLINE UI_FormShow( ::hCpp )
   METHOD ShowModal()  INLINE UI_FormShowModal( ::hCpp )
   METHOD Hide()       INLINE UI_FormHide( ::hCpp )
   METHOD Close()      INLINE UI_FormClose( ::hCpp )
   METHOD Destroy()    INLINE UI_FormDestroy( ::hCpp )
   METHOD SetDesign(l) INLINE UI_FormSetDesign( ::hCpp, l )
   METHOD ToJSON()     INLINE UI_FormToJSON( ::hCpp )
   METHOD CreateMenu() INLINE UI_MenuBarCreate( ::hCpp )
   METHOD AddPopup( cText )
   METHOD MenuItemAdd( hPopup, cText, bAction )
   METHOD MenuSepAdd( hPopup )

ENDCLASS

METHOD New( cTitle, nWidth, nHeight ) CLASS TForm

   if cTitle == nil;  cTitle := "New Form"; endif
   if nWidth == nil;  nWidth := 470; endif
   if nHeight == nil; nHeight := 400; endif

   ::hCpp := UI_FormNew( cTitle, nWidth, nHeight, "Segoe UI", 12 )

return Self

METHOD Activate() CLASS TForm

   // Apply pending colors before showing (HWNDs created by FormRun)
   UI_FormRun( ::hCpp )

return Self

METHOD AddPopup( cText ) CLASS TForm
return TMenuPopup():New( Self, cText )

METHOD MenuItemAdd( hPopup, cText, bAction ) CLASS TForm
return UI_MenuItemAddEx( ::hCpp, hPopup, cText, bAction )

METHOD MenuSepAdd( hPopup ) CLASS TForm
   UI_MenuSepAdd( ::hCpp, hPopup )
return Self


//----------------------------------------------------------------------------//
// TLabel
//----------------------------------------------------------------------------//

CLASS TLabel INHERIT TControl

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TLabel

   if nWidth == nil;  nWidth := 80; endif
   if nHeight == nil; nHeight := 20; endif

   ::oParent := oParent
   ::hCpp := UI_LabelNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TEdit
//----------------------------------------------------------------------------//

CLASS TEdit INHERIT TControl

   ACCESS Value      INLINE UI_GetProp( ::hCpp, "cText" )
   ASSIGN Value( c ) INLINE UI_SetProp( ::hCpp, "cText", c )

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TEdit

   if cText == nil;   cText := ""; endif
   if nWidth == nil;  nWidth := 200; endif
   if nHeight == nil; nHeight := 26; endif

   ::oParent := oParent
   ::hCpp := UI_EditNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TMemo
//----------------------------------------------------------------------------//

CLASS TMemo INHERIT TControl

   ACCESS Value      INLINE UI_GetProp( ::hCpp, "cText" )
   ASSIGN Value( c ) INLINE UI_SetProp( ::hCpp, "cText", c )

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TMemo

   if cText == nil;   cText := ""; endif
   if nWidth == nil;  nWidth := 180; endif
   if nHeight == nil; nHeight := 80; endif

   ::oParent := oParent
   ::hCpp := UI_MemoNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TButton
//----------------------------------------------------------------------------//

CLASS TButton INHERIT TControl

   ACCESS Default      INLINE UI_GetProp( ::hCpp, "lDefault" )
   ASSIGN Default( l ) INLINE UI_SetProp( ::hCpp, "lDefault", l )

   ACCESS Cancel       INLINE UI_GetProp( ::hCpp, "lCancel" )
   ASSIGN Cancel( l )  INLINE UI_SetProp( ::hCpp, "lCancel", l )

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TButton

   if nWidth == nil;  nWidth := 88; endif
   if nHeight == nil; nHeight := 26; endif

   ::oParent := oParent
   ::hCpp := UI_ButtonNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TCheckBox
//----------------------------------------------------------------------------//

CLASS TCheckBox INHERIT TControl

   ACCESS Checked      INLINE UI_GetProp( ::hCpp, "lChecked" )
   ASSIGN Checked( l ) INLINE UI_SetProp( ::hCpp, "lChecked", l )

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TCheckBox

   if nWidth == nil;  nWidth := 150; endif
   if nHeight == nil; nHeight := 19; endif

   ::oParent := oParent
   ::hCpp := UI_CheckBoxNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TComboBox
//----------------------------------------------------------------------------//

CLASS TComboBox INHERIT TControl

   ACCESS Value      INLINE UI_GetProp( ::hCpp, "nItemIndex" )
   ASSIGN Value( n ) INLINE UI_ComboSetIndex( ::hCpp, n )

   METHOD New( oParent, nLeft, nTop, nWidth, nHeight )
   METHOD AddItem( cItem ) INLINE UI_ComboAddItem( ::hCpp, cItem )

ENDCLASS

METHOD New( oParent, nLeft, nTop, nWidth, nHeight ) CLASS TComboBox

   if nWidth == nil;  nWidth := 175; endif
   if nHeight == nil; nHeight := 200; endif

   ::oParent := oParent
   ::hCpp := UI_ComboBoxNew( oParent:hCpp, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TGroupBox
//----------------------------------------------------------------------------//

CLASS TGroupBox INHERIT TControl

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TGroupBox

   ::oParent := oParent
   ::hCpp := UI_GroupBoxNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TRadioButton
//----------------------------------------------------------------------------//

CLASS TRadioButton INHERIT TControl

   ACCESS Checked      INLINE UI_GetProp( ::hCpp, "lChecked" )
   ASSIGN Checked( l ) INLINE UI_SetProp( ::hCpp, "lChecked", l )

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TRadioButton

   if nWidth == nil;  nWidth := 120; endif
   if nHeight == nil; nHeight := 20; endif

   ::oParent := oParent
   ::hCpp := UI_RadioButtonNew( oParent:hCpp, cText, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TListBox
//----------------------------------------------------------------------------//

CLASS TListBox INHERIT TControl

   METHOD New( oParent, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, nLeft, nTop, nWidth, nHeight ) CLASS TListBox

   if nWidth == nil;  nWidth := 120; endif
   if nHeight == nil; nHeight := 80; endif

   ::oParent := oParent
   ::hCpp := UI_ListBoxNew( oParent:hCpp, nLeft, nTop, nWidth, nHeight )

return Self

//----------------------------------------------------------------------------//
// TBrwColumn - Column descriptor for TBrowse
//----------------------------------------------------------------------------//

CLASS TBrwColumn

   DATA cTitle    INIT ""
   DATA nWidth    INIT 100
   DATA nAlign    INIT 0           // 0=Left, 1=Center, 2=Right
   DATA cField    INIT ""          // Field name for DBF binding
   DATA bBlock    INIT nil         // Code block for data retrieval

   METHOD New( cTitle, nWidth, nAlign ) CONSTRUCTOR

ENDCLASS

METHOD New( cTitle, nWidth, nAlign ) CLASS TBrwColumn

   if cTitle != nil;  ::cTitle := cTitle;  endif
   if nWidth != nil;  ::nWidth := nWidth;  endif
   if nAlign != nil;  ::nAlign := nAlign;  endif

return Self

//----------------------------------------------------------------------------//
// TBrowse - Data grid control
//----------------------------------------------------------------------------//

CLASS TBrowse INHERIT TControl

   DATA aColumns    INIT {}         // Array of TBrwColumn objects
   DATA cDataSource INIT ""         // Name of data component (e.g. "CompArray1")

   METHOD New( oParent, nLeft, nTop, nWidth, nHeight )
   METHOD SetArray( aData, aHeaders )
   METHOD SetupColumns( cColumnsDef )
   METHOD SetColSizes( aSizes )
   METHOD SetFooters( aFooters )
   METHOD AddColumn( cTitle, nWidth, nAlign )
   METHOD Refresh()
   METHOD LoadFromDataSource( oForm )

   ACCESS aArray INLINE nil
   ASSIGN aArray( x ) INLINE ::SetArray( x )

ENDCLASS

METHOD New( oParent, nLeft, nTop, nWidth, nHeight ) CLASS TBrowse

   if nWidth == nil;  nWidth := 400; endif
   if nHeight == nil; nHeight := 200; endif

   ::oParent := oParent
   ::hCpp := UI_BrowseNew( oParent:hCpp, nLeft, nTop, nWidth, nHeight )

return Self

METHOD SetArray( aData, aHeaders ) CLASS TBrowse

   local i, j, nCols, xVal

   if aData == nil .or. Len( aData ) == 0
      return Self
   endif

   // Determine number of columns from first row
   if ValType( aData[1] ) == "A"
      nCols := Len( aData[1] )
   else
      nCols := 1
   endif

   // Create columns from headers if none defined yet
   if Len( ::aColumns ) == 0
      if aHeaders != nil .and. Len( aHeaders ) > 0
         for i := 1 to Len( aHeaders )
            ::AddColumn( aHeaders[i], 100 )
         next
      else
         for i := 1 to nCols
            ::AddColumn( "Col " + LTrim( Str( i ) ), 100 )
         next
      endif
   endif

   // Fill cells
   for i := 1 to Len( aData )
      if ValType( aData[i] ) == "A"
         for j := 1 to Min( nCols, Len( aData[i] ) )
            xVal := aData[i][j]
            UI_BrowseSetCell( ::hCpp, i - 1, j - 1, hb_ValToStr( xVal ) )
         next
      else
         UI_BrowseSetCell( ::hCpp, i - 1, 0, hb_ValToStr( aData[i] ) )
      endif
   next

   ::Refresh()

return Self

METHOD AddColumn( cTitle, nWidth, nAlign ) CLASS TBrowse

   local oCol

   if nWidth == nil; nWidth := 100; endif
   oCol := TBrwColumn():New( cTitle, nWidth, nAlign )
   AAdd( ::aColumns, oCol )
   UI_BrowseAddCol( ::hCpp, cTitle, "", nWidth, iif( nAlign != nil, nAlign, 0 ) )

return oCol

METHOD SetupColumns( aColumnsDef ) CLASS TBrowse

   local i

   if aColumnsDef == nil; return Self; endif

   if ValType( aColumnsDef ) == "A"
      for i := 1 to Len( aColumnsDef )
         ::AddColumn( aColumnsDef[i] )
      next
   elseif ValType( aColumnsDef ) == "C" .and. ! Empty( aColumnsDef )
      for i := 1 to Len( hb_ATokens( aColumnsDef, "|" ) )
         ::AddColumn( hb_ATokens( aColumnsDef, "|" )[i] )
      next
   endif

return Self

METHOD SetColSizes( aSizes ) CLASS TBrowse

   local i

   if aSizes != nil .and. ValType( aSizes ) == "A"
      for i := 1 to Min( Len( aSizes ), UI_BrowseColCount( ::hCpp ) )
         UI_BrowseSetColProp( ::hCpp, i - 1, "nWidth", aSizes[i] )
      next
   endif

return Self

METHOD SetFooters( aFooters ) CLASS TBrowse

   local i

   if aFooters != nil .and. ValType( aFooters ) == "A"
      for i := 1 to Min( Len( aFooters ), UI_BrowseColCount( ::hCpp ) )
         UI_BrowseSetColProp( ::hCpp, i - 1, "cFooterText", aFooters[i] )
      next
   endif

return Self

METHOD Refresh() CLASS TBrowse

   UI_BrowseRefresh( ::hCpp )

return Self

METHOD LoadFromDataSource( oForm ) CLASS TBrowse

   local cDS, oComp

   cDS := ::cDataSource
   if Empty( cDS )
      return Self
   endif

   // Find the component by name in the form's instance variables
   if __objHasMsg( oForm, "o" + cDS )
      oComp := __objSendMsg( oForm, "o" + cDS )
      if oComp != nil .and. __objHasMethod( oComp, "GETARRAY" )
         ::SetArray( oComp:GetArray(), oComp:GetHeaders() )
      endif
   endif

return Self

//----------------------------------------------------------------------------//
// TCompArray - Non-visual array data container
// TTimer - non-visual timer component
//----------------------------------------------------------------------------//

CLASS TTimer

   DATA hCpp      INIT 0
   DATA oParent   INIT nil
   DATA nInterval INIT 1000
   DATA bOnTimer  INIT nil

   ASSIGN OnTimer( b )    INLINE ( ::bOnTimer := b, iif( ::hCpp != 0, UI_OnEvent( ::hCpp, "OnTimer", b ), nil ) )
   ASSIGN nInterval( n )  INLINE ( ::nInterval := n, iif( ::hCpp != 0, UI_SetProp( ::hCpp, "nInterval", n ), nil ) )
   ACCESS Enabled         INLINE iif( ::hCpp != 0, UI_GetProp( ::hCpp, "lEnabled" ), .F. )
   ASSIGN Enabled( l )    INLINE iif( ::hCpp != 0, UI_SetProp( ::hCpp, "lEnabled", l ), nil )

   METHOD New() CONSTRUCTOR

ENDCLASS

METHOD New() CLASS TTimer
return Self

//----------------------------------------------------------------------------//
// TCompArray
// Design-time: aHeaders = "Name|Age|City", aData = "John|45|NYC;Mary|32|LA"
// Runtime: provides parsed arrays for TBrowse binding
//----------------------------------------------------------------------------//

CLASS TCompArray

   DATA aHeaders    INIT ""         // Design-time string: "Name|Age|City"
   DATA aData       INIT ""         // Design-time string: "John|45|NYC;Mary|32|LA"

   METHOD New() CONSTRUCTOR
   METHOD Parse()
   METHOD GetHeaders()
   METHOD GetArray()

ENDCLASS

METHOD New() CLASS TCompArray
return Self

METHOD Parse() CLASS TCompArray
return Self

METHOD GetHeaders() CLASS TCompArray

   if ValType( ::aHeaders ) == "C" .and. ! Empty( ::aHeaders )
      return hb_ATokens( ::aHeaders, "|" )
   elseif ValType( ::aHeaders ) == "A"
      return ::aHeaders
   endif

return {}

METHOD GetArray() CLASS TCompArray

   local aResult := {}, aRows, i

   if ValType( ::aData ) == "C" .and. ! Empty( ::aData )
      aRows := hb_ATokens( ::aData, ";" )
      for i := 1 to Len( aRows )
         if ! Empty( aRows[i] )
            AAdd( aResult, hb_ATokens( aRows[i], "|" ) )
         endif
      next
   elseif ValType( ::aData ) == "A"
      return ::aData
   endif

return aResult

return ::aArray

//----------------------------------------------------------------------------//
// TComponentPalette
//----------------------------------------------------------------------------//

CLASS TComponentPalette INHERIT TControl

   DATA oForm

   METHOD New( oParent )
   METHOD AddTab( cName )     INLINE UI_PaletteAddTab( ::hCpp, cName )
   METHOD AddComp( nTab, cText, cTooltip, nCtrlType ) ;
      INLINE UI_PaletteAddComp( ::hCpp, nTab, cText, cTooltip, nCtrlType )

ENDCLASS

METHOD New( oParent ) CLASS TComponentPalette

   ::oForm := oParent
   ::oParent := oParent
   ::hCpp := UI_PaletteNew( oParent:hCpp )

return Self

//----------------------------------------------------------------------------//
// TToolBar
//----------------------------------------------------------------------------//

CLASS TToolBar INHERIT TControl

   DATA oForm

   METHOD New( oParent )
   METHOD AddButton( cText, cTooltip, bAction )
   METHOD AddSeparator() INLINE UI_ToolBtnAddSep( ::hCpp )

ENDCLASS

METHOD New( oParent ) CLASS TToolBar

   ::oForm := oParent
   ::oParent := oParent
   ::hCpp := UI_ToolBarNew( oParent:hCpp )

return Self

METHOD AddButton( cText, cTooltip, bAction ) CLASS TToolBar

   local nIdx

   if cTooltip == nil; cTooltip := cText; endif
   nIdx := UI_ToolBtnAdd( ::hCpp, cText, cTooltip )
   if bAction != nil .and. nIdx >= 0
      UI_ToolBtnOnClick( ::hCpp, nIdx, bAction )
   endif

return nIdx

//----------------------------------------------------------------------------//
// TMenuPopup - Wrapper for a popup menu
//----------------------------------------------------------------------------//

CLASS TMenuPopup

   DATA oForm
   DATA hPopup INIT 0

   METHOD New( oForm, cText )
   METHOD AddItem( cText, bAction, cAccel )
   METHOD AddSeparator()

ENDCLASS

METHOD New( oForm, cText ) CLASS TMenuPopup

   ::oForm := oForm
   ::hPopup := UI_MenuPopupAdd( oForm:hCpp, cText )

return Self

METHOD AddItem( cText, bAction, cAccel ) CLASS TMenuPopup
return UI_MenuItemAddEx( ::oForm:hCpp, ::hPopup, cText, bAction, cAccel )

METHOD AddSeparator() CLASS TMenuPopup
   UI_MenuSepAdd( ::oForm:hCpp, ::hPopup )
return Self

//----------------------------------------------------------------------------//
// TApplication - Main application object (C++Builder pattern)
//----------------------------------------------------------------------------//

CLASS TApplication

   DATA Title     INIT "Application"
   DATA aForms    INIT {}
   DATA oMainForm INIT nil

   METHOD New()
   METHOD CreateForm( oForm )
   METHOD Run()

ENDCLASS

METHOD New() CLASS TApplication
   SetDPIAware()
return Self

METHOD CreateForm( oForm ) CLASS TApplication

   // Install global error handler on first CreateForm call
   // (must be before form construction, which may open files/databases)
   if ::oMainForm == nil
      ErrorBlock( { |oError| AppShowError( oError ) } )
   endif

   AAdd( ::aForms, oForm )
   if ::oMainForm == nil
      ::oMainForm := oForm
   endif

   // Call the form's CreateForm method (like C++Builder constructor)
   if __objHasMethod( oForm, "CREATEFORM" )
      oForm:CreateForm()
   endif

return Self

METHOD Run() CLASS TApplication

   // Show and activate the main form (enters NSApp run loop)
   if ::oMainForm != nil
      ::oMainForm:Activate()
   endif

return Self

//----------------------------------------------------------------------------//
// AppShowError — global runtime error handler for TApplication
// Formats the Error object with full details + call stack into a dialog
//----------------------------------------------------------------------------//

static function AppShowError( oError )

   local cMsg := "", i, cArgs, nChoice, aOptions

   // Following Harbour errorsys.prg: handle recoverable errors silently
   // Division by zero → substitute 0
   if oError:GenCode == 5 .and. oError:CanSubstitute  // EG_ZERODIV
      return 0
   endif

   // Lock error → auto-retry
   if oError:GenCode == 41 .and. oError:CanRetry  // EG_LOCK
      return .t.
   endif

   // Open error (shared file) → set NetErr() and continue
   if oError:GenCode == 21 .and. oError:OsCode == 32 .and. oError:CanDefault  // EG_OPEN
      NetErr( .t. )
      return .f.
   endif

   // Append lock error → set NetErr() and continue
   if oError:GenCode == 40 .and. oError:CanDefault  // EG_APPENDLOCK
      NetErr( .t. )
      return .f.
   endif

   // Build error message with full details
   cMsg += If( oError:Severity != nil .and. oError:Severity > 1, "ERROR", "Warning" )
   cMsg += ": " + If( oError:Description != nil, oError:Description, "(no description)" ) + Chr(10)
   cMsg += Replicate( "-", 60 ) + Chr(10)

   // Error details
   cMsg += "Subsystem:   " + If( oError:SubSystem != nil, oError:SubSystem, "" ) + Chr(10)
   cMsg += "SubCode:     " + If( oError:SubCode != nil, LTrim( Str( oError:SubCode ) ), "" ) + Chr(10)
   cMsg += "Operation:   " + If( oError:Operation != nil, oError:Operation, "" ) + Chr(10)
   cMsg += "Severity:    " + If( oError:Severity != nil, LTrim( Str( oError:Severity ) ), "" ) + Chr(10)
   cMsg += "GenCode:     " + If( oError:GenCode != nil, LTrim( Str( oError:GenCode ) ), "" ) + Chr(10)
   cMsg += "OsCode:      " + If( oError:OsCode != nil, LTrim( Str( oError:OsCode ) ), "" ) + Chr(10)
   cMsg += "FileName:    " + If( oError:FileName != nil, oError:FileName, "" ) + Chr(10)

   // Arguments
   if oError:Args != nil .and. ValType( oError:Args ) == "A" .and. Len( oError:Args ) > 0
      cArgs := ""
      for i := 1 to Len( oError:Args )
         if i > 1; cArgs += ", "; endif
         cArgs += hb_ValToStr( oError:Args[i] )
      next
      cMsg += "Args:        " + cArgs + Chr(10)
   endif

   // Call stack
   cMsg += Chr(10) + "CALL STACK:" + Chr(10)
   cMsg += Replicate( "-", 60 ) + Chr(10)
   i := 1
   do while ! Empty( ProcName( i ) )
      cMsg += "  " + ProcName( i ) + "(" + LTrim( Str( ProcLine( i ) ) ) + ")"
      if ! Empty( ProcFile( i ) )
         cMsg += " in " + ProcFile( i )
      endif
      cMsg += Chr(10)
      i++
   enddo

   // Build button options (following errorsys.prg)
   aOptions := { "Quit" }
   if oError:CanRetry
      AAdd( aOptions, "Retry" )
   endif
   if oError:CanDefault
      AAdd( aOptions, "Default" )
   endif

   // Show error dialog - use platform-appropriate dialog
   nChoice := 1  // default: Quit
#ifdef __PLATFORM__WINDOWS
   // Windows: rich Win32 dialog (stack + source view)
   W32_ErrorDialog( cMsg )
#else
#ifdef __PLATFORM__DARWIN
   nChoice := MAC_RuntimeErrorDialog( "Runtime Error", cMsg, aOptions )
#else
   // Linux / other Unix: GTK scrollable mono dialog with Copy to Clipboard
   nChoice := GTK_RuntimeErrorDialog( "Runtime Error", cMsg, aOptions )
#endif
#endif

   if nChoice > 1 .and. nChoice <= Len( aOptions )
      if aOptions[ nChoice ] == "Retry"
         return .t.   // retry the operation
      elseif aOptions[ nChoice ] == "Default"
         return .f.   // use default behavior
      endif
   endif

   // "Quit" or dialog closed — terminate the application
   ErrorLevel( 1 )
#ifdef __PLATFORM__DARWIN
   MAC_AppTerminate()   // force NSApp terminate (ends Cocoa run loop)
#else
#ifndef __PLATFORM__WINDOWS
   GTK_AppTerminate()   // force gtk_main_quit (ends GTK main loop)
#endif
#endif
   QUIT

return .f.

//============================================================================//
//  DATA CONTROLS (visual, Data Controls tab - bind to TDatabase)
//============================================================================//

//----------------------------------------------------------------------------//
// TDataSource - binds a TDatabase to visual data controls
//----------------------------------------------------------------------------//

CLASS TDataSource

   DATA oDatabase   INIT nil       // TDatabase subclass instance
   DATA cTable      INIT ""        // Table/alias name
   DATA aControls   INIT {}        // Bound data controls
   DATA lActive     INIT .F.       // Active state

   METHOD New( oDb ) CONSTRUCTOR
   METHOD AddControl( oCtrl )
   METHOD Refresh()
   METHOD MoveFirst()
   METHOD MovePrev()
   METHOD MoveNext()
   METHOD MoveLast()
   METHOD Append()
   METHOD Delete()
   METHOD Save()

ENDCLASS

METHOD New( oDb ) CLASS TDataSource
   if oDb != nil; ::oDatabase := oDb; endif
return Self

METHOD AddControl( oCtrl ) CLASS TDataSource
   AAdd( ::aControls, oCtrl )
   oCtrl:oDataSource := Self
return nil

METHOD Refresh() CLASS TDataSource
   local i
   for i := 1 to Len( ::aControls )
      ::aControls[i]:RefreshFromDB()
   next
return nil

METHOD MoveFirst() CLASS TDataSource
   if ::oDatabase != nil .and. ::oDatabase:IsConnected()
      ::oDatabase:GoTop()
      ::Refresh()
   endif
return nil

METHOD MovePrev() CLASS TDataSource
   if ::oDatabase != nil .and. ::oDatabase:IsConnected()
      ::oDatabase:Skip( -1 )
      ::Refresh()
   endif
return nil

METHOD MoveNext() CLASS TDataSource
   if ::oDatabase != nil .and. ::oDatabase:IsConnected()
      ::oDatabase:Skip( 1 )
      ::Refresh()
   endif
return nil

METHOD MoveLast() CLASS TDataSource
   if ::oDatabase != nil .and. ::oDatabase:IsConnected()
      ::oDatabase:GoBottom()
      ::Refresh()
   endif
return nil

METHOD Append() CLASS TDataSource
   if ::oDatabase != nil .and. ::oDatabase:IsConnected()
      ::oDatabase:Append()
      ::Refresh()
   endif
return nil

METHOD Delete() CLASS TDataSource
   if ::oDatabase != nil .and. ::oDatabase:IsConnected()
      ::oDatabase:Delete()
      ::oDatabase:Skip()
      if ::oDatabase:Eof(); ::oDatabase:GoBottom(); endif
      ::Refresh()
   endif
return nil

METHOD Save() CLASS TDataSource
   ::Refresh()
return nil

//----------------------------------------------------------------------------//
// TDBControl - base for all data-aware controls
//----------------------------------------------------------------------------//

CLASS TDBControl INHERIT TControl

   DATA oDataSource INIT nil       // TDataSource reference
   DATA cFieldName  INIT ""        // Bound field name
   DATA nFieldIndex INIT 0         // Bound field index (1-based)

   METHOD RefreshFromDB()
   METHOD WriteToDB()

ENDCLASS

METHOD RefreshFromDB() CLASS TDBControl
   // Override in subclass
return nil

METHOD WriteToDB() CLASS TDBControl
   // Override in subclass
return nil

//----------------------------------------------------------------------------//
// TDBText - label displaying a field value (read-only)
//----------------------------------------------------------------------------//

CLASS TDBText INHERIT TDBControl
   METHOD RefreshFromDB()
ENDCLASS

METHOD RefreshFromDB() CLASS TDBText
   local xVal
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil .and. ::nFieldIndex > 0
      xVal := ::oDataSource:oDatabase:FieldGet( ::nFieldIndex )
      ::Text := hb_ValToStr( xVal )
   endif
return nil

//----------------------------------------------------------------------------//
// TDBEdit - editable entry bound to a field
//----------------------------------------------------------------------------//

CLASS TDBEdit INHERIT TDBControl
   METHOD RefreshFromDB()
   METHOD WriteToDB()
ENDCLASS

METHOD RefreshFromDB() CLASS TDBEdit
   local xVal
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil .and. ::nFieldIndex > 0
      xVal := ::oDataSource:oDatabase:FieldGet( ::nFieldIndex )
      ::Text := hb_ValToStr( xVal )
   endif
return nil

METHOD WriteToDB() CLASS TDBEdit
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil .and. ::nFieldIndex > 0
      ::oDataSource:oDatabase:FieldPut( ::nFieldIndex, ::Text )
   endif
return nil

//----------------------------------------------------------------------------//
// TDBComboBox - combo box bound to a field
//----------------------------------------------------------------------------//

CLASS TDBComboBox INHERIT TDBControl
   METHOD RefreshFromDB()
ENDCLASS

METHOD RefreshFromDB() CLASS TDBComboBox
   local xVal
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil .and. ::nFieldIndex > 0
      xVal := ::oDataSource:oDatabase:FieldGet( ::nFieldIndex )
      ::Text := hb_ValToStr( xVal )
   endif
return nil

//----------------------------------------------------------------------------//
// TDBCheckBox - check button bound to a logical field
//----------------------------------------------------------------------------//

CLASS TDBCheckBox INHERIT TDBControl
   METHOD RefreshFromDB()
   METHOD WriteToDB()
ENDCLASS

METHOD RefreshFromDB() CLASS TDBCheckBox
   local xVal
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil .and. ::nFieldIndex > 0
      xVal := ::oDataSource:oDatabase:FieldGet( ::nFieldIndex )
      if ValType( xVal ) == "L"
         // Set checked state via property
         UI_SetProp( ::hCpp, "lChecked", xVal )
      endif
   endif
return nil

METHOD WriteToDB() CLASS TDBCheckBox
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil .and. ::nFieldIndex > 0
      ::oDataSource:oDatabase:FieldPut( ::nFieldIndex, UI_GetProp( ::hCpp, "lChecked" ) )
   endif
return nil

//----------------------------------------------------------------------------//
// TDBNavigator - navigation button bar
//----------------------------------------------------------------------------//

CLASS TDBNavigator INHERIT TDBControl

   DATA oDataSource INIT nil

   METHOD New( oDS ) CONSTRUCTOR
   METHOD First()
   METHOD Prior()
   METHOD Next()
   METHOD Last()
   METHOD Insert()
   METHOD Remove()
   METHOD Post()

ENDCLASS

METHOD New( oDS ) CLASS TDBNavigator
   if oDS != nil; ::oDataSource := oDS; endif
return Self

METHOD First() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:MoveFirst(); endif
return nil

METHOD Prior() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:MovePrev(); endif
return nil

METHOD Next() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:MoveNext(); endif
return nil

METHOD Last() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:MoveLast(); endif
return nil

METHOD Insert() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:Append(); endif
return nil

METHOD Remove() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:Delete(); endif
return nil

METHOD Post() CLASS TDBNavigator
   if ::oDataSource != nil; ::oDataSource:Save(); endif
return nil

//----------------------------------------------------------------------------//
// MsgInfo - cross-platform message box
//----------------------------------------------------------------------------//

function MsgInfo( xText, cTitle )

   if cTitle == nil; cTitle := "Information"; endif
   UI_MsgBox( ValToStr( xText ), ValToStr( cTitle ) )

return nil

function MsgYesNo( xText, cTitle )

   if cTitle == nil; cTitle := "Confirm"; endif

return UI_MsgYesNo( ValToStr( xText ), ValToStr( cTitle ) )

static function ValToStr( xVal )
   local cType := ValType( xVal )
   do case
      case xVal == nil;      return "nil"
      case cType == "C"
         if Empty( xVal );   return '""'; endif
         return xVal
      case cType == "N";     return LTrim( Str( xVal ) )
      case cType == "L";     return If( xVal, ".T.", ".F." )
      case cType == "D";     return DToC( xVal )
      case cType == "A";     return "{Array(" + LTrim( Str( Len( xVal ) ) ) + ")}"
      case cType == "O";     return "{Object:" + xVal:ClassName() + "}"
      case cType == "B";     return "{Block}"
   endcase
return hb_ValToStr( xVal )

//============================================================================//
//  DATABASE COMPONENTS (non-visual, Data Access tab)
//============================================================================//

//----------------------------------------------------------------------------//
// TDatabase - Abstract base class for all database connections
//----------------------------------------------------------------------------//

CLASS TDatabase

   DATA cServer     INIT ""        // Host/server name
   DATA nPort       INIT 0         // Port number
   DATA cDatabase   INIT ""        // Database name or file path
   DATA cUser       INIT ""        // Username
   DATA cPassword   INIT ""        // Password
   DATA cCharSet    INIT "UTF8"    // Character set
   DATA lConnected  INIT .F.       // Connection status
   DATA cLastError  INIT ""        // Last error message
   DATA pHandle     INIT nil       // Native connection handle
   DATA cDriver     INIT ""        // Driver name (for identification)

   METHOD New() CONSTRUCTOR
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD TableExists( cTable )
   METHOD Tables()
   METHOD LastError()
   METHOD IsConnected()

ENDCLASS

METHOD New() CLASS TDatabase
return Self

METHOD Open() CLASS TDatabase
   ::cLastError := "Abstract: override Open() in subclass"
return .F.

METHOD Close() CLASS TDatabase
   ::lConnected := .F.
   ::pHandle := nil
return nil

METHOD Execute( cSQL ) CLASS TDatabase
   HB_SYMBOL_UNUSED( cSQL )
   ::cLastError := "Abstract: override Execute() in subclass"
return .F.

METHOD Query( cSQL ) CLASS TDatabase
   HB_SYMBOL_UNUSED( cSQL )
   ::cLastError := "Abstract: override Query() in subclass"
return {}

METHOD TableExists( cTable ) CLASS TDatabase
   HB_SYMBOL_UNUSED( cTable )
return .F.

METHOD Tables() CLASS TDatabase
return {}

METHOD LastError() CLASS TDatabase
return ::cLastError

METHOD IsConnected() CLASS TDatabase
return ::lConnected

//----------------------------------------------------------------------------//
// TDBFTable - Native DBF/NTX/CDX table access via Harbour RDD
//----------------------------------------------------------------------------//

CLASS TDBFTable INHERIT TDatabase

   DATA cFileName   INIT ""        // DBF file path
   DATA cAlias      INIT ""        // Work area alias
   DATA cRDD        INIT "DBFCDX"  // RDD driver: DBFNTX, DBFCDX, DBFFPT
   DATA cIndexFile  INIT ""        // Index file (.ntx, .cdx)
   DATA lExclusive  INIT .F.       // Open exclusive
   DATA lReadOnly   INIT .F.       // Open read-only
   DATA nArea       INIT 0         // Work area number

   METHOD New() CONSTRUCTOR
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD Tables()

   // DBF-specific methods
   METHOD GoTop()
   METHOD GoBottom()
   METHOD Skip( n )
   METHOD GoTo( nRec )
   METHOD RecNo()
   METHOD RecCount()
   METHOD Eof()
   METHOD Bof()
   METHOD FieldGet( nField )
   METHOD FieldPut( nField, xValue )
   METHOD FieldName( nField )
   METHOD FieldCount()
   METHOD Append()
   METHOD Delete()
   METHOD Recall()
   METHOD Deleted()
   METHOD Seek( xKey )
   METHOD Found()
   METHOD CreateIndex( cFile, cKey )
   METHOD Structure()

ENDCLASS

METHOD New() CLASS TDBFTable
   ::cDriver := "DBF"
return Self

METHOD Open() CLASS TDBFTable
   local lOk := .F., nArea

   // cFileName is the primary property; sync to cDatabase for TDatabase compat
   if ! Empty( ::cFileName )
      ::cDatabase := ::cFileName
   endif

   if Empty( ::cDatabase )
      ::cLastError := "Database (file path) not specified"
      return .F.
   endif

   begin sequence
      if ! Empty( ::cAlias )
         if ::lExclusive
            dbUseArea( .T., ::cRDD, ::cDatabase, ::cAlias, .F., ::lReadOnly )
         else
            dbUseArea( .T., ::cRDD, ::cDatabase, ::cAlias, .T., ::lReadOnly )
         endif
      else
         ::cAlias := hb_FNameName( ::cDatabase )
         dbUseArea( .T., ::cRDD, ::cDatabase, ::cAlias, ! ::lExclusive, ::lReadOnly )
      endif

      ::nArea := Select()
      ::lConnected := .T.
      lOk := .T.

      if ! Empty( ::cIndexFile )
         dbSetIndex( ::cIndexFile )
      endif

   recover
      ::cLastError := "Error opening " + ::cDatabase
      ::lConnected := .F.
   end sequence

return lOk

METHOD Close() CLASS TDBFTable
   if ::lConnected .and. ::nArea > 0
      ( ::cAlias )->( dbCloseArea() )
   endif
   ::lConnected := .F.
   ::nArea := 0
return nil

METHOD Execute( cSQL ) CLASS TDBFTable
   HB_SYMBOL_UNUSED( cSQL )
   ::cLastError := "DBF does not support SQL. Use DBF methods directly."
return .F.

METHOD Query( cSQL ) CLASS TDBFTable
   HB_SYMBOL_UNUSED( cSQL )
   ::cLastError := "DBF does not support SQL. Use DBF methods directly."
return {}

METHOD Tables() CLASS TDBFTable
   local aFiles := Directory( hb_FNameDir( ::cDatabase ) + "*.dbf" )
   local aNames := {}, i
   for i := 1 to Len( aFiles )
      AAdd( aNames, aFiles[i][1] )
   next
return aNames

METHOD GoTop() CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( dbGoTop() ); endif
return nil

METHOD GoBottom() CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( dbGoBottom() ); endif
return nil

METHOD Skip( n ) CLASS TDBFTable
   if n == nil; n := 1; endif
   if ::lConnected; ( ::cAlias )->( dbSkip( n ) ); endif
return nil

METHOD GoTo( nRec ) CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( dbGoTo( nRec ) ); endif
return nil

METHOD RecNo() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( RecNo() ); endif
return 0

METHOD RecCount() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( RecCount() ); endif
return 0

METHOD Eof() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( Eof() ); endif
return .T.

METHOD Bof() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( Bof() ); endif
return .T.

METHOD FieldGet( nField ) CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( FieldGet( nField ) ); endif
return nil

METHOD FieldPut( nField, xValue ) CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( FieldPut( nField, xValue ) ); endif
return nil

METHOD FieldName( nField ) CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( FieldName( nField ) ); endif
return ""

METHOD FieldCount() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( FCount() ); endif
return 0

METHOD Append() CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( dbAppend() ); endif
return nil

METHOD Delete() CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( dbDelete() ); endif
return nil

METHOD Recall() CLASS TDBFTable
   if ::lConnected; ( ::cAlias )->( dbRecall() ); endif
return nil

METHOD Deleted() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( Deleted() ); endif
return .F.

METHOD Seek( xKey ) CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( dbSeek( xKey ) ); endif
return .F.

METHOD Found() CLASS TDBFTable
   if ::lConnected; return ( ::cAlias )->( Found() ); endif
return .F.

METHOD CreateIndex( cFile, cKey ) CLASS TDBFTable
   if ::lConnected
      ( ::cAlias )->( dbCreateIndex( cFile, cKey ) )
   endif
return nil

METHOD Structure() CLASS TDBFTable
   local aStruct := {}, i, nFields
   if ::lConnected
      nFields := ( ::cAlias )->( FCount() )
      for i := 1 to nFields
         AAdd( aStruct, { ;
            ( ::cAlias )->( FieldName(i) ), ;
            ( ::cAlias )->( hb_FieldType(i) ), ;
            ( ::cAlias )->( hb_FieldLen(i) ), ;
            ( ::cAlias )->( hb_FieldDec(i) ) } )
      next
   endif
return aStruct

//----------------------------------------------------------------------------//
// TSQLite - SQLite3 database via Harbour's hbsqlit3 library
//----------------------------------------------------------------------------//

CLASS TSQLite INHERIT TDatabase

   DATA lAutoCommit  INIT .T.       // Auto-commit mode

   METHOD New() CONSTRUCTOR
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD TableExists( cTable )
   METHOD Tables()

   // SQLite-specific
   METHOD CreateTable( cName, aFields )
   METHOD BeginTransaction()
   METHOD Commit()
   METHOD Rollback()
   METHOD LastInsertId()

ENDCLASS

METHOD New() CLASS TSQLite
   ::cDriver := "SQLite"
   ::nPort   := 0
return Self

METHOD Open() CLASS TSQLite
   if Empty( ::cDatabase )
      ::cLastError := "Database file path not specified"
      return .F.
   endif
   ::pHandle := sqlite3_open( ::cDatabase, .T. )  // .T. = create if not exists
   if ::pHandle != nil
      ::lConnected := .T.
      if ! Empty( ::cCharSet )
         sqlite3_exec( ::pHandle, "PRAGMA encoding = '" + ::cCharSet + "'" )
      endif
      return .T.
   endif
   ::cLastError := "Failed to open SQLite database: " + ::cDatabase
return .F.

METHOD Close() CLASS TSQLite
   // Harbour's hbsqlit3 uses GC-managed handles - no explicit close needed
   ::pHandle := nil
   ::lConnected := .F.
return nil

METHOD Execute( cSQL ) CLASS TSQLite
   local nResult
   if ! ::lConnected; ::cLastError := "Not connected"; return .F.; endif
   nResult := sqlite3_exec( ::pHandle, cSQL )
   if ValType( nResult ) == "N" .and. nResult != 0
      ::cLastError := sqlite3_errmsg( ::pHandle )
      return .F.
   elseif ValType( nResult ) != "N"
      // sqlite3_exec may return non-numeric on some errors
      ::cLastError := "Unexpected return from sqlite3_exec"
      return .F.
   endif
return .T.

METHOD Query( cSQL ) CLASS TSQLite
   local pStmt, aRows := {}, aRow, nCols, i, nRet
   if ! ::lConnected; ::cLastError := "Not connected"; return {}; endif

   pStmt := sqlite3_prepare( ::pHandle, cSQL )
   if pStmt == nil
      ::cLastError := sqlite3_errmsg( ::pHandle )
      return {}
   endif

   nCols := sqlite3_column_count( pStmt )

   nRet := sqlite3_step( pStmt )
   while nRet == 100  // SQLITE_ROW
      aRow := Array( nCols )
      for i := 1 to nCols
         // Use text for all columns - simplest, most portable
         aRow[i] := sqlite3_column_text( pStmt, i )
      next
      AAdd( aRows, aRow )
      nRet := sqlite3_step( pStmt )
   enddo

   sqlite3_finalize( pStmt )
return aRows

METHOD TableExists( cTable ) CLASS TSQLite
   local aResult
   if ! ::lConnected; return .F.; endif
   aResult := ::Query( "SELECT name FROM sqlite_master WHERE type='table' AND name='" + cTable + "'" )
return Len( aResult ) > 0

METHOD Tables() CLASS TSQLite
   local aResult, aNames := {}, i
   if ! ::lConnected; return {}; endif
   aResult := ::Query( "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name" )
   for i := 1 to Len( aResult )
      AAdd( aNames, aResult[i][1] )
   next
return aNames

METHOD CreateTable( cName, aFields ) CLASS TSQLite
   local cSQL := "CREATE TABLE IF NOT EXISTS " + cName + " (", i
   for i := 1 to Len( aFields )
      if i > 1; cSQL += ", "; endif
      cSQL += aFields[i][1] + " " + aFields[i][2]
   next
   cSQL += ")"
return ::Execute( cSQL )

METHOD BeginTransaction() CLASS TSQLite
return ::Execute( "BEGIN TRANSACTION" )

METHOD Commit() CLASS TSQLite
return ::Execute( "COMMIT" )

METHOD Rollback() CLASS TSQLite
return ::Execute( "ROLLBACK" )

METHOD LastInsertId() CLASS TSQLite
   local aResult
   if ! ::lConnected; return 0; endif
   aResult := ::Query( "SELECT last_insert_rowid()" )
   if Len( aResult ) > 0; return aResult[1][1]; endif
return 0

//----------------------------------------------------------------------------//
// TMySQL - MySQL/MariaDB connection (requires libmysqlclient)
//----------------------------------------------------------------------------//

CLASS TMySQL INHERIT TDatabase
   METHOD New() CONSTRUCTOR
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD Tables()
ENDCLASS

METHOD New() CLASS TMySQL
   ::cDriver := "MySQL"
   ::nPort   := 3306
return Self

METHOD Open() CLASS TMySQL
   ::cLastError := "MySQL support requires libmysqlclient. Install with: apt install libmysqlclient-dev"
return .F.

METHOD Close() CLASS TMySQL
   ::lConnected := .F.
return nil

METHOD Execute( cSQL ) CLASS TMySQL
   HB_SYMBOL_UNUSED( cSQL )
return .F.

METHOD Query( cSQL ) CLASS TMySQL
   HB_SYMBOL_UNUSED( cSQL )
return {}

METHOD Tables() CLASS TMySQL
return {}

//----------------------------------------------------------------------------//
// TMariaDB - alias for TMySQL (wire-compatible)
//----------------------------------------------------------------------------//

CLASS TMariaDB INHERIT TMySQL
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS TMariaDB
   ::Super:New()
   ::cDriver := "MariaDB"
   ::nPort   := 3306
return Self

//----------------------------------------------------------------------------//
// TPostgreSQL - PostgreSQL connection (requires libpq)
//----------------------------------------------------------------------------//

CLASS TPostgreSQL INHERIT TDatabase
   METHOD New() CONSTRUCTOR
   METHOD Open()
   METHOD Close()
   METHOD Execute( cSQL )
   METHOD Query( cSQL )
   METHOD Tables()
ENDCLASS

METHOD New() CLASS TPostgreSQL
   ::cDriver := "PostgreSQL"
   ::nPort   := 5432
return Self

METHOD Open() CLASS TPostgreSQL
   ::cLastError := "PostgreSQL support requires libpq-dev. Install with: apt install libpq-dev"
return .F.

METHOD Close() CLASS TPostgreSQL
   ::lConnected := .F.
return nil

METHOD Execute( cSQL ) CLASS TPostgreSQL
   HB_SYMBOL_UNUSED( cSQL )
return .F.

METHOD Query( cSQL ) CLASS TPostgreSQL
   HB_SYMBOL_UNUSED( cSQL )
return {}

METHOD Tables() CLASS TPostgreSQL
return {}

//----------------------------------------------------------------------------//
// TFirebird - Firebird connection (requires libfbclient)
//----------------------------------------------------------------------------//

CLASS TFirebird INHERIT TDatabase
   METHOD New() CONSTRUCTOR
   METHOD Open()
ENDCLASS

METHOD New() CLASS TFirebird
   ::cDriver := "Firebird"
   ::nPort   := 3050
return Self

METHOD Open() CLASS TFirebird
   ::cLastError := "Firebird support requires libfbclient. Install with: apt install firebird-dev"
return .F.

//----------------------------------------------------------------------------//
// TSQLServer - SQL Server connection (requires FreeTDS/ODBC)
//----------------------------------------------------------------------------//

CLASS TSQLServer INHERIT TDatabase
   METHOD New() CONSTRUCTOR
   METHOD Open()
ENDCLASS

METHOD New() CLASS TSQLServer
   ::cDriver := "SQLServer"
   ::nPort   := 1433
return Self

METHOD Open() CLASS TSQLServer
   ::cLastError := "SQL Server support requires FreeTDS. Install with: apt install freetds-dev"
return .F.

//----------------------------------------------------------------------------//
// TOracle - Oracle connection (requires OCI)
//----------------------------------------------------------------------------//

CLASS TOracle INHERIT TDatabase
   METHOD New() CONSTRUCTOR
   METHOD Open()
ENDCLASS

METHOD New() CLASS TOracle
   ::cDriver := "Oracle"
   ::nPort   := 1521
return Self

METHOD Open() CLASS TOracle
   ::cLastError := "Oracle support requires Oracle Instant Client"
return .F.

//----------------------------------------------------------------------------//
// TMongoDB - MongoDB connection (requires mongoc driver)
//----------------------------------------------------------------------------//

CLASS TMongoDB INHERIT TDatabase
   METHOD New() CONSTRUCTOR
   METHOD Open()
ENDCLASS

METHOD New() CLASS TMongoDB
   ::cDriver := "MongoDB"
   ::nPort   := 27017
return Self

METHOD Open() CLASS TMongoDB
   ::cLastError := "MongoDB support requires libmongoc. Install with: apt install libmongoc-dev"
return .F.

//============================================================================//
//  PRINTING COMPONENTS (Printing tab)
//============================================================================//

CLASS TPrinter
   DATA cPrinterName INIT ""
   DATA nCopies      INIT 1
   DATA lLandscape   INIT .F.
   DATA nPaperSize   INIT 1         // 1=Letter, 9=A4
   DATA lPreview     INIT .F.
   DATA nPageWidth   INIT 0
   DATA nPageHeight  INIT 0
   METHOD New() CONSTRUCTOR
   METHOD BeginDoc( cTitle )
   METHOD EndDoc()
   METHOD NewPage()
   METHOD PrintLine( nRow, nCol, cText )
   METHOD PrintImage( nRow, nCol, nWidth, nHeight, cFile )
   METHOD PrintRect( nRow, nCol, nWidth, nHeight )
ENDCLASS

METHOD New() CLASS TPrinter
return Self

METHOD BeginDoc( cTitle ) CLASS TPrinter
   HB_SYMBOL_UNUSED( cTitle )
return nil

METHOD EndDoc() CLASS TPrinter
return nil

METHOD NewPage() CLASS TPrinter
return nil

METHOD PrintLine( nRow, nCol, cText ) CLASS TPrinter
   HB_SYMBOL_UNUSED( nRow ); HB_SYMBOL_UNUSED( nCol ); HB_SYMBOL_UNUSED( cText )
return nil

METHOD PrintImage( nRow, nCol, nWidth, nHeight, cFile ) CLASS TPrinter
   HB_SYMBOL_UNUSED( nRow ); HB_SYMBOL_UNUSED( nCol )
   HB_SYMBOL_UNUSED( nWidth ); HB_SYMBOL_UNUSED( nHeight )
   HB_SYMBOL_UNUSED( cFile )
return nil

METHOD PrintRect( nRow, nCol, nWidth, nHeight ) CLASS TPrinter
   HB_SYMBOL_UNUSED( nRow ); HB_SYMBOL_UNUSED( nCol )
   HB_SYMBOL_UNUSED( nWidth ); HB_SYMBOL_UNUSED( nHeight )
return nil

//----------------------------------------------------------------------------//

CLASS TReport
   DATA oPrinter     INIT nil
   DATA cTitle       INIT ""
   DATA aBands       INIT {}        // { { "Header", bBlock }, { "Detail", bBlock }, ... }
   DATA aColumns     INIT {}        // { { cTitle, cField, nWidth }, ... }
   DATA oDataSource  INIT nil
   // Visual Report Designer support
   DATA aDesignBands   INIT {}
   DATA nPageWidth     INIT 210
   DATA nPageHeight    INIT 297
   DATA nMarginLeft    INIT 15
   DATA nMarginRight   INIT 15
   DATA nMarginTop     INIT 15
   DATA nMarginBottom  INIT 15
   METHOD New( oPrn ) CONSTRUCTOR
   METHOD AddBand( cName, bBlock )
   METHOD AddColumn( cTitle, cField, nWidth )
   METHOD Preview()
   METHOD Print()
   METHOD AddDesignBand( oBand )
   METHOD RemoveDesignBand( nIndex )
   METHOD GetDesignBand( cName )
   METHOD GenerateCode( cClassName )
ENDCLASS

METHOD New( oPrn ) CLASS TReport
   if oPrn != nil; ::oPrinter := oPrn; endif
return Self

METHOD AddBand( cName, bBlock ) CLASS TReport
   AAdd( ::aBands, { cName, bBlock } )
return nil

METHOD AddColumn( cTitle, cField, nWidth ) CLASS TReport
   AAdd( ::aColumns, { cTitle, cField, nWidth } )
return nil

METHOD Preview() CLASS TReport
   local i, j, oBand, oFld, nY

   RPT_PreviewOpen( ::nPageWidth, ::nPageHeight, ;
      ::nMarginLeft, ::nMarginRight, ::nMarginTop, ::nMarginBottom )
   RPT_PreviewAddPage()

   nY := ::nMarginTop

   for i := 1 to Len( ::aDesignBands )
      oBand := ::aDesignBands[i]
      if ! oBand:lVisible; loop; endif

      for j := 1 to Len( oBand:aFields )
         oFld := oBand:aFields[j]
         RPT_PreviewDrawText( ::nMarginLeft + oFld:nLeft, nY + oFld:nTop, ;
            iif( ! Empty(oFld:cText), oFld:cText, "[" + oFld:cFieldName + "]" ), ;
            oFld:cFontName, oFld:nFontSize, oFld:lBold, oFld:lItalic, oFld:nForeColor )
      next

      nY += oBand:nHeight
   next

   RPT_PreviewRender()
return nil

METHOD Print() CLASS TReport
   local i
   if ::oPrinter == nil; return nil; endif
   ::oPrinter:BeginDoc( ::cTitle )
   // Header band
   for i := 1 to Len( ::aBands )
      if ::aBands[i][1] == "Header" .and. ::aBands[i][2] != nil
         Eval( ::aBands[i][2], ::oPrinter )
      endif
   next
   // Detail band (iterate datasource)
   if ::oDataSource != nil .and. ::oDataSource:oDatabase != nil
      ::oDataSource:oDatabase:GoTop()
      while ! ::oDataSource:oDatabase:Eof()
         for i := 1 to Len( ::aBands )
            if ::aBands[i][1] == "Detail" .and. ::aBands[i][2] != nil
               Eval( ::aBands[i][2], ::oPrinter, ::oDataSource:oDatabase )
            endif
         next
         ::oDataSource:oDatabase:Skip()
      enddo
   endif
   // Footer band
   for i := 1 to Len( ::aBands )
      if ::aBands[i][1] == "Footer" .and. ::aBands[i][2] != nil
         Eval( ::aBands[i][2], ::oPrinter )
      endif
   next
   ::oPrinter:EndDoc()
return nil

METHOD AddDesignBand( oBand ) CLASS TReport
   AAdd( ::aDesignBands, oBand )
return oBand

METHOD RemoveDesignBand( nIndex ) CLASS TReport
   if nIndex >= 1 .and. nIndex <= Len( ::aDesignBands )
      ADel( ::aDesignBands, nIndex )
      ASize( ::aDesignBands, Len( ::aDesignBands ) - 1 )
   endif
return nil

METHOD GetDesignBand( cName ) CLASS TReport
   local i
   local cUpper := Upper( cName )
   for i := 1 to Len( ::aDesignBands )
      if Upper( ::aDesignBands[i]:cName ) == cUpper
         return ::aDesignBands[i]
      endif
   next
return nil

METHOD GenerateCode( cClassName ) CLASS TReport
   local cCode, i, j, oBand, oField
   local cCRLF := Chr(13) + Chr(10)

   if cClassName == nil; cClassName := "MyReport"; endif

   cCode := "CLASS " + cClassName + " INHERIT TReport" + cCRLF
   cCode += "   METHOD CreateReport() CONSTRUCTOR" + cCRLF
   cCode += "ENDCLASS" + cCRLF
   cCode += cCRLF
   cCode += "METHOD CreateReport() CLASS " + cClassName + cCRLF
   cCode += "   local oBand, oField" + cCRLF
   cCode += cCRLF

   // Page setup
   cCode += "   ::nPageWidth    := " + LTrim(Str(::nPageWidth)) + cCRLF
   cCode += "   ::nPageHeight   := " + LTrim(Str(::nPageHeight)) + cCRLF
   cCode += "   ::nMarginLeft   := " + LTrim(Str(::nMarginLeft)) + cCRLF
   cCode += "   ::nMarginRight  := " + LTrim(Str(::nMarginRight)) + cCRLF
   cCode += "   ::nMarginTop    := " + LTrim(Str(::nMarginTop)) + cCRLF
   cCode += "   ::nMarginBottom := " + LTrim(Str(::nMarginBottom)) + cCRLF
   cCode += cCRLF

   // Bands and fields
   for i := 1 to Len( ::aDesignBands )
      oBand := ::aDesignBands[i]
      cCode += "   oBand := TReportBand():New( " + '"' + oBand:cName + '"' + " )" + cCRLF
      cCode += "   oBand:nHeight := " + LTrim(Str(oBand:nHeight)) + cCRLF
      if oBand:lPrintOnEveryPage
         cCode += "   oBand:lPrintOnEveryPage := .T." + cCRLF
      endif
      if oBand:nBackColor != -1
         cCode += "   oBand:nBackColor := " + LTrim(Str(oBand:nBackColor)) + cCRLF
      endif

      for j := 1 to Len( oBand:aFields )
         oField := oBand:aFields[j]
         cCode += "   oField := TReportField():New( " + '"' + oField:cName + '"' + " )" + cCRLF
         if ! Empty( oField:cText )
            cCode += '   oField:cText := "' + oField:cText + '"' + cCRLF
         endif
         if ! Empty( oField:cFieldName )
            cCode += '   oField:cFieldName := "' + oField:cFieldName + '"' + cCRLF
         endif
         if ! Empty( oField:cExpression )
            cCode += '   oField:cExpression := "' + oField:cExpression + '"' + cCRLF
         endif
         cCode += "   oField:nLeft := " + LTrim(Str(oField:nLeft)) + cCRLF
         cCode += "   oField:nTop := " + LTrim(Str(oField:nTop)) + cCRLF
         cCode += "   oField:nWidth := " + LTrim(Str(oField:nWidth)) + cCRLF
         cCode += "   oField:nHeight := " + LTrim(Str(oField:nHeight)) + cCRLF
         if oField:nAlignment != 0
            cCode += "   oField:nAlignment := " + LTrim(Str(oField:nAlignment)) + cCRLF
         endif
         if oField:cFontName != "Sans"
            cCode += '   oField:cFontName := "' + oField:cFontName + '"' + cCRLF
         endif
         if oField:nFontSize != 10
            cCode += "   oField:nFontSize := " + LTrim(Str(oField:nFontSize)) + cCRLF
         endif
         if oField:lBold
            cCode += "   oField:lBold := .T." + cCRLF
         endif
         if oField:lItalic
            cCode += "   oField:lItalic := .T." + cCRLF
         endif
         if ! Empty( oField:cFormat )
            cCode += '   oField:cFormat := "' + oField:cFormat + '"' + cCRLF
         endif
         cCode += "   oBand:AddField( oField )" + cCRLF
      next

      cCode += "   ::AddDesignBand( oBand )" + cCRLF
      cCode += cCRLF
   next

   cCode += "return Self" + cCRLF

return cCode

//============================================================================//
//  INTERNET COMPONENTS (Internet tab)
//============================================================================//

CLASS TWebServer
   DATA nPort        INIT 8080
   DATA cRoot        INIT "."       // Document root
   DATA lRunning     INIT .F.
   DATA bOnRequest   INIT nil       // { |cMethod, cPath, cBody| cResponse }
   DATA aRoutes      INIT {}        // { { cMethod, cPath, bHandler }, ... }
   METHOD New() CONSTRUCTOR
   METHOD AddRoute( cMethod, cPath, bHandler )
   METHOD Start()
   METHOD Stop()
   METHOD ServeStatic( cPath )
ENDCLASS

METHOD New() CLASS TWebServer
return Self

METHOD AddRoute( cMethod, cPath, bHandler ) CLASS TWebServer
   AAdd( ::aRoutes, { Upper(cMethod), cPath, bHandler } )
return nil

METHOD Start() CLASS TWebServer
   ::lRunning := .T.
return nil

METHOD Stop() CLASS TWebServer
   ::lRunning := .F.
return nil

METHOD ServeStatic( cPath ) CLASS TWebServer
   if File( ::cRoot + "/" + cPath )
      return MemoRead( ::cRoot + "/" + cPath )
   endif
return "404 Not Found"

//----------------------------------------------------------------------------//

CLASS THttpClient
   DATA cBaseUrl     INIT ""
   DATA cLastResponse INIT ""
   DATA nLastStatus  INIT 0
   DATA nTimeout     INIT 30
   DATA aHeaders     INIT {}
   METHOD New( cUrl ) CONSTRUCTOR
   METHOD Get( cPath )
   METHOD Post( cPath, cBody )
   METHOD Put( cPath, cBody )
   METHOD Delete( cPath )
   METHOD SetHeader( cName, cValue )
ENDCLASS

METHOD New( cUrl ) CLASS THttpClient
   if cUrl != nil; ::cBaseUrl := cUrl; endif
return Self

METHOD Get( cPath ) CLASS THttpClient
   local cCmd := "curl -s -m " + LTrim(Str(::nTimeout)) + ' "' + ::cBaseUrl + cPath + '" 2>/dev/null'
   ::cLastResponse := hb_MemoRead( cCmd )
return ::cLastResponse

METHOD Post( cPath, cBody ) CLASS THttpClient
   local cCmd := "curl -s -m " + LTrim(Str(::nTimeout)) + ;
      " -X POST -d '" + cBody + "' " + ;
      '"' + ::cBaseUrl + cPath + '" 2>/dev/null'
   ::cLastResponse := hb_MemoRead( cCmd )
return ::cLastResponse

METHOD Put( cPath, cBody ) CLASS THttpClient
   HB_SYMBOL_UNUSED( cPath ); HB_SYMBOL_UNUSED( cBody )
return ""

METHOD Delete( cPath ) CLASS THttpClient
   HB_SYMBOL_UNUSED( cPath )
return ""

METHOD SetHeader( cName, cValue ) CLASS THttpClient
   AAdd( ::aHeaders, { cName, cValue } )
return nil

//============================================================================//
//  THREADING COMPONENTS (Threading tab)
//============================================================================//

CLASS TThread
   DATA bAction      INIT nil       // Code block to execute
   DATA lRunning     INIT .F.
   DATA pHandle      INIT nil       // Thread handle
   METHOD New( bAction ) CONSTRUCTOR
   METHOD Start()
   METHOD Stop()
   METHOD IsRunning()
ENDCLASS

METHOD New( bAction ) CLASS TThread
   if bAction != nil; ::bAction := bAction; endif
return Self

METHOD Start() CLASS TThread
   if ::bAction != nil
      ::lRunning := .T.
      ::pHandle := hb_threadStart( ::bAction )
   endif
return nil

METHOD Stop() CLASS TThread
   ::lRunning := .F.
return nil

METHOD IsRunning() CLASS TThread
return ::lRunning

//----------------------------------------------------------------------------//

CLASS TMutex
   DATA pHandle INIT nil
   METHOD New() CONSTRUCTOR
   METHOD Lock()
   METHOD Unlock()
ENDCLASS

METHOD New() CLASS TMutex
   ::pHandle := hb_mutexCreate()
return Self

METHOD Lock() CLASS TMutex
   if ::pHandle != nil; hb_mutexLock( ::pHandle ); endif
return nil

METHOD Unlock() CLASS TMutex
   if ::pHandle != nil; hb_mutexUnlock( ::pHandle ); endif
return nil

//----------------------------------------------------------------------------//

CLASS TChannel
   DATA pMutex   INIT nil
   DATA aBuffer  INIT {}
   METHOD New() CONSTRUCTOR
   METHOD Send( xValue )
   METHOD Receive()
   METHOD Count()
ENDCLASS

METHOD New() CLASS TChannel
   ::pMutex := hb_mutexCreate()
return Self

METHOD Send( xValue ) CLASS TChannel
   hb_mutexLock( ::pMutex )
   AAdd( ::aBuffer, xValue )
   hb_mutexUnlock( ::pMutex )
return nil

METHOD Receive() CLASS TChannel
   local xVal := nil
   hb_mutexLock( ::pMutex )
   if Len( ::aBuffer ) > 0
      xVal := ::aBuffer[1]
      ADel( ::aBuffer, 1 )
      ASize( ::aBuffer, Len(::aBuffer) - 1 )
   endif
   hb_mutexUnlock( ::pMutex )
return xVal

METHOD Count() CLASS TChannel
return Len( ::aBuffer )

//============================================================================//
//  REPORT DESIGNER DATA MODEL
//============================================================================//

CLASS TReportBand
   DATA cName              INIT ""
   DATA nHeight            INIT 30
   DATA aFields            INIT {}
   DATA lPrintOnEveryPage  INIT .F.
   DATA lKeepTogether      INIT .T.
   DATA lVisible           INIT .T.
   DATA nBackColor         INIT -1
   METHOD New( cName ) CONSTRUCTOR
   METHOD AddField( oField )
   METHOD RemoveField( nIndex )
   METHOD FieldCount()
ENDCLASS

METHOD New( cName ) CLASS TReportBand
   ::aFields := {}
   if cName != nil
      ::cName := cName
      if "HEADER" $ Upper( cName ) .or. "PAGEHEADER" $ Upper( cName )
         ::lPrintOnEveryPage := .T.
      endif
   endif
return Self

METHOD AddField( oField ) CLASS TReportBand
   AAdd( ::aFields, oField )
return oField

METHOD RemoveField( nIndex ) CLASS TReportBand
   if nIndex >= 1 .and. nIndex <= Len( ::aFields )
      ADel( ::aFields, nIndex )
      ASize( ::aFields, Len( ::aFields ) - 1 )
   endif
return nil

METHOD FieldCount() CLASS TReportBand
return Len( ::aFields )

//----------------------------------------------------------------------------//

CLASS TReportField
   DATA cName         INIT ""
   DATA cText         INIT ""
   DATA cFieldName    INIT ""
   DATA cExpression   INIT ""
   DATA nLeft         INIT 0
   DATA nTop          INIT 0
   DATA nWidth        INIT 80
   DATA nHeight       INIT 16
   DATA nAlignment    INIT 0
   DATA cFontName     INIT "Sans"
   DATA nFontSize     INIT 10
   DATA lBold         INIT .F.
   DATA lItalic       INIT .F.
   DATA lUnderline    INIT .F.
   DATA cFormat       INIT ""
   DATA nForeColor    INIT 0
   DATA nBackColor    INIT -1
   DATA nBorderWidth  INIT 0
   DATA cFieldType    INIT "text"
   METHOD New( cName ) CONSTRUCTOR
   METHOD IsDataBound()
   METHOD GetValue( oDataSource )
ENDCLASS

METHOD New( cName ) CLASS TReportField
   if cName != nil; ::cName := cName; endif
return Self

METHOD IsDataBound() CLASS TReportField
return ! Empty( ::cFieldName )

METHOD GetValue( oDataSource ) CLASS TReportField
   local xValue := nil
   if oDataSource != nil .and. oDataSource:oDatabase != nil .and. ! Empty( ::cFieldName )
      xValue := oDataSource:oDatabase:FieldGet( ::cFieldName )
      if ! Empty( ::cFormat ) .and. xValue != nil
         xValue := Transform( xValue, ::cFormat )
      endif
   endif
return xValue

// Helper functions for report xcommand macros
function RPT_NewTextField( oBand, cText, nTop, nLeft, nW, nH, cFont, nFSize, lBold, lItalic, nAlign )
   local oFld

   oFld := TReportField():New()
   oFld:cText := cText
   oFld:nTop := nTop
   oFld:nLeft := nLeft
   oFld:nWidth := nW
   oFld:nHeight := nH
   if cFont != nil;  oFld:cFontName := cFont;  endif
   if nFSize != nil; oFld:nFontSize := nFSize;  endif
   if lBold != nil;  oFld:lBold := lBold;       endif
   if lItalic != nil; oFld:lItalic := lItalic;  endif
   if nAlign != nil; oFld:nAlignment := nAlign;  endif
   oBand:AddField( oFld )
return oFld

function RPT_NewDataField( oBand, cField, nTop, nLeft, nW, nH, cFont, nFSize, lBold, lItalic, nAlign )
   local oFld

   oFld := TReportField():New()
   oFld:cFieldName := cField
   oFld:nTop := nTop
   oFld:nLeft := nLeft
   oFld:nWidth := nW
   oFld:nHeight := nH
   if cFont != nil;  oFld:cFontName := cFont;  endif
   if nFSize != nil; oFld:nFontSize := nFSize;  endif
   if lBold != nil;  oFld:lBold := lBold;       endif
   if lItalic != nil; oFld:lItalic := lItalic;  endif
   if nAlign != nil; oFld:nAlignment := nAlign;  endif
   oBand:AddField( oFld )
return oFld

// Helper for COMPONENT xcommand - maps type number to class instance
function HB_CreateComponent( nType, oParent )
   local oComp
   do case
      case nType == CT_DBFTABLE;   return TDBFTable():New()
      case nType == CT_MYSQL;      return TMySQL():New()
      case nType == CT_MARIADB;    return TMariaDB():New()
      case nType == CT_POSTGRESQL; return TPostgreSQL():New()
      case nType == CT_SQLITE;     return TSQLite():New()
      case nType == CT_FIREBIRD;   return TFirebird():New()
      case nType == CT_SQLSERVER;  return TSQLServer():New()
      case nType == CT_COMPARRAY;  return TCompArray():New()
      case nType == CT_TIMER
         oComp := TTimer():New()
         if oParent != nil .and. __objHasMsg( oParent, "HCPP" ) .and. oParent:hCpp != 0
            oComp:hCpp := UI_TimerNew( oParent:hCpp, 1000 )
         endif
         return oComp
   endcase
return nil
