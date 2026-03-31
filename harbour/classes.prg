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

ENDCLASS

//----------------------------------------------------------------------------//
// TForm
//----------------------------------------------------------------------------//

CLASS TForm INHERIT TControl

   ACCESS FontName      INLINE UI_GetProp( ::hCpp, "cFontName" )
   ASSIGN FontName( c ) INLINE UI_SetProp( ::hCpp, "cFontName", c )

   ACCESS FontSize      INLINE UI_GetProp( ::hCpp, "nFontSize" )
   ASSIGN FontSize( n ) INLINE UI_SetProp( ::hCpp, "nFontSize", n )

   ACCESS ModalResult   INLINE UI_FormResult( ::hCpp )

   METHOD New( cTitle, nWidth, nHeight )
   METHOD Activate()
   METHOD Close()      INLINE UI_FormClose( ::hCpp )
   METHOD Destroy()    INLINE UI_FormDestroy( ::hCpp )
   METHOD SetDesign(l) INLINE UI_FormSetDesign( ::hCpp, l )
   METHOD ToJSON()     INLINE UI_FormToJSON( ::hCpp )

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

//----------------------------------------------------------------------------//
// TLabel
//----------------------------------------------------------------------------//

CLASS TLabel INHERIT TControl

   METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight )

ENDCLASS

METHOD New( oParent, cText, nLeft, nTop, nWidth, nHeight ) CLASS TLabel

   if nWidth == nil;  nWidth := 80; endif
   if nHeight == nil; nHeight := 15; endif

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
   if nHeight == nil; nHeight := 24; endif

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
