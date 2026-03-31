// hbide.ch - Cross-platform IDE framework
// No external dependencies (no FiveWin)

#ifndef _HBIDE_CH
#define _HBIDE_CH

// Property categories
#define PROP_APPEARANCE    "Appearance"
#define PROP_POSITION      "Position"
#define PROP_BEHAVIOR      "Behavior"
#define PROP_DATA          "Data"

// Property types
#define PROPTYPE_STRING    1
#define PROPTYPE_NUMBER    2
#define PROPTYPE_LOGICAL   3
#define PROPTYPE_COLOR     4
#define PROPTYPE_FONT      5
#define PROPTYPE_ENUM      6
#define PROPTYPE_ITEMS     7

// Control types
#define CTRL_FORM          "Form"
#define CTRL_LABEL         "Label"
#define CTRL_EDIT          "Edit"
#define CTRL_BUTTON        "Button"
#define CTRL_CHECKBOX      "CheckBox"
#define CTRL_COMBOBOX      "ComboBox"
#define CTRL_GROUPBOX      "GroupBox"
#define CTRL_LISTBOX       "ListBox"
#define CTRL_RADIOBUTTON   "RadioButton"
#define CTRL_PROGRESSBAR   "ProgressBar"

// Alignment
#define ALIGN_LEFT         0
#define ALIGN_CENTER       1
#define ALIGN_RIGHT        2

// Win32 styles (for cross-platform abstraction - each backend maps these)
#define WS_POPUP           0x80000000
#define WS_CAPTION         0x00C00000
#define WS_SYSMENU         0x00080000
#define WS_CHILD           0x40000000
#define WS_VISIBLE         0x10000000
#define WS_TABSTOP         0x00010000
#define WS_VSCROLL         0x00200000
#define WS_BORDER          0x00800000
#define WS_CLIPSIBLINGS    0x04000000
#define WS_CLIPCHILDREN    0x02000000
#define WS_EX_TRANSPARENT  0x00000020
#define DS_MODALFRAME      0x00000080
#define ES_AUTOHSCROLL     0x00000080
#define BS_GROUPBOX        0x00000007
#define BS_AUTOCHECKBOX    0x00000003
#define BS_DEFPUSHBUTTON   0x00000001
#define CBS_DROPDOWNLIST   0x00000003
#define COLOR_BTNFACE      15

#define CRLF Chr(13) + Chr(10)

#endif
