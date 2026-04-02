// classes.prg - Harbour OOP wrappers over C++ core
// User-facing classes: TForm, TLabel, TEdit, TButton, TCheckBox, TComboBox, TGroupBox

#include "hbclass.ch"

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

ENDCLASS

//----------------------------------------------------------------------------//
// TForm
//----------------------------------------------------------------------------//

CLASS TForm INHERIT TControl

   // Title (alias for Text - C++Builder uses Caption/Title)
   ACCESS Title         INLINE UI_GetProp( ::hCpp, "cText" )
   ASSIGN Title( c )    INLINE UI_SetProp( ::hCpp, "cText", c )

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

   // Color (alias for nClrPane - C++Builder uses Color)
   ACCESS Color            INLINE UI_GetProp( ::hCpp, "nClrPane" )
   ASSIGN Color( n )       INLINE UI_SetProp( ::hCpp, "nClrPane", n )

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
return Self

METHOD CreateForm( oForm ) CLASS TApplication

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
