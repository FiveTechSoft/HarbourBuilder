// controls.prg - Concrete control classes (Form, Button, Label, etc.)
// Each adds its specific properties on top of UIControl base.

#include "hbclass.ch"
#include "hbide.ch"

//----------------------------------------------------------------------------//
// UIForm - Top-level form/window
//----------------------------------------------------------------------------//

CLASS UIForm INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIForm

   ::Super:Init( oParent )
   ::cClass := CTRL_FORM

   ::oProps:Add( "FontName",  "Segoe UI", PROPTYPE_STRING, PROP_APPEARANCE )
   ::oProps:Add( "FontSize",  12,         PROPTYPE_NUMBER, PROP_APPEARANCE )
   ::oProps:Add( "BackColor", -1,         PROPTYPE_COLOR,  PROP_APPEARANCE )
   ::oProps:Add( "Center",    .t.,        PROPTYPE_LOGICAL, PROP_POSITION )
   ::oProps:Add( "Modal",     .t.,        PROPTYPE_LOGICAL, PROP_BEHAVIOR )

   // Form defaults
   ::Width  := 470
   ::Height := 400
   ::Text   := "New Form"

return Self

//----------------------------------------------------------------------------//
// UILabel - Static text
//----------------------------------------------------------------------------//

CLASS UILabel INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UILabel

   ::Super:Init( oParent )
   ::cClass := CTRL_LABEL

   ::oProps:Add( "Alignment", ALIGN_LEFT, PROPTYPE_ENUM, PROP_APPEARANCE, , ;
      { "Left", "Center", "Right" } )

   ::Width  := 80
   ::Height := 15
   ::Text   := "Label"

return Self

//----------------------------------------------------------------------------//
// UIEdit - Text input (GET)
//----------------------------------------------------------------------------//

CLASS UIEdit INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIEdit

   ::Super:Init( oParent )
   ::cClass := CTRL_EDIT

   ::oProps:Add( "MaxLength",  0,    PROPTYPE_NUMBER,  PROP_BEHAVIOR )
   ::oProps:Add( "ReadOnly",   .f.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "Password",   .f.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "MultiLine",  .f.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "Picture",    "",   PROPTYPE_STRING,  PROP_DATA )

   ::Width  := 200
   ::Height := 24

return Self

//----------------------------------------------------------------------------//
// UIButton - Push button
//----------------------------------------------------------------------------//

CLASS UIButton INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIButton

   ::Super:Init( oParent )
   ::cClass := CTRL_BUTTON

   ::oProps:Add( "Default",  .f., PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "Cancel",   .f., PROPTYPE_LOGICAL, PROP_BEHAVIOR )

   ::Width  := 88
   ::Height := 26
   ::Text   := "Button"

return Self

//----------------------------------------------------------------------------//
// UICheckBox
//----------------------------------------------------------------------------//

CLASS UICheckBox INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UICheckBox

   ::Super:Init( oParent )
   ::cClass := CTRL_CHECKBOX

   ::oProps:Add( "Checked", .f., PROPTYPE_LOGICAL, PROP_DATA )

   ::Width  := 150
   ::Height := 19

return Self

//----------------------------------------------------------------------------//
// UIComboBox
//----------------------------------------------------------------------------//

CLASS UIComboBox INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIComboBox

   ::Super:Init( oParent )
   ::cClass := CTRL_COMBOBOX

   ::oProps:Add( "Items",      {},  PROPTYPE_ITEMS,  PROP_DATA )
   ::oProps:Add( "ItemIndex",   1,  PROPTYPE_NUMBER, PROP_DATA )
   ::oProps:Add( "DropDown",  .t.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )

   ::Width  := 175
   ::Height := 200   // dropdown area

return Self

//----------------------------------------------------------------------------//
// UIGroupBox
//----------------------------------------------------------------------------//

CLASS UIGroupBox INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIGroupBox

   ::Super:Init( oParent )
   ::cClass := CTRL_GROUPBOX

   ::Width  := 200
   ::Height := 100

return Self

//----------------------------------------------------------------------------//
// UIRadioButton
//----------------------------------------------------------------------------//

CLASS UIRadioButton INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIRadioButton

   ::Super:Init( oParent )
   ::cClass := CTRL_RADIOBUTTON

   ::oProps:Add( "Checked", .f., PROPTYPE_LOGICAL, PROP_DATA )
   ::oProps:Add( "Group",   .f., PROPTYPE_LOGICAL, PROP_BEHAVIOR )

   ::Width  := 150
   ::Height := 19

return Self

//----------------------------------------------------------------------------//
// UIListBox
//----------------------------------------------------------------------------//

CLASS UIListBox INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIListBox

   ::Super:Init( oParent )
   ::cClass := CTRL_LISTBOX

   ::oProps:Add( "Items",      {},  PROPTYPE_ITEMS,  PROP_DATA )
   ::oProps:Add( "ItemIndex",   0,  PROPTYPE_NUMBER, PROP_DATA )

   ::Width  := 150
   ::Height := 120

return Self

//----------------------------------------------------------------------------//
// UIProgressBar
//----------------------------------------------------------------------------//

CLASS UIProgressBar INHERIT UIControl

   METHOD Init( oParent )

ENDCLASS

METHOD Init( oParent ) CLASS UIProgressBar

   ::Super:Init( oParent )
   ::cClass := CTRL_PROGRESSBAR

   ::oProps:Add( "Min",     0,   PROPTYPE_NUMBER, PROP_DATA )
   ::oProps:Add( "Max",   100,   PROPTYPE_NUMBER, PROP_DATA )
   ::oProps:Add( "Value",   0,   PROPTYPE_NUMBER, PROP_DATA )

   ::Width  := 200
   ::Height := 20

return Self

//----------------------------------------------------------------------------//
// Factory function - creates control by class name
//----------------------------------------------------------------------------//

function CreateControlByClass( cClass )

   do case
      case cClass == CTRL_FORM;        return UIForm():New()
      case cClass == CTRL_LABEL;       return UILabel():New()
      case cClass == CTRL_EDIT;        return UIEdit():New()
      case cClass == CTRL_BUTTON;      return UIButton():New()
      case cClass == CTRL_CHECKBOX;    return UICheckBox():New()
      case cClass == CTRL_COMBOBOX;    return UIComboBox():New()
      case cClass == CTRL_GROUPBOX;    return UIGroupBox():New()
      case cClass == CTRL_RADIOBUTTON; return UIRadioButton():New()
      case cClass == CTRL_LISTBOX;     return UIListBox():New()
      case cClass == CTRL_PROGRESSBAR; return UIProgressBar():New()
   endcase

return nil
