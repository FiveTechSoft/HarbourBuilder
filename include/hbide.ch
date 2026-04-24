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

// Component type IDs (must match C-side CT_* defines)
#define CT_FORM              0
#define CT_LABEL             1
#define CT_EDIT              2
#define CT_BUTTON            3
#define CT_CHECKBOX          4
#define CT_COMBOBOX          5
#define CT_GROUPBOX          6
#define CT_LISTBOX           7
#define CT_RADIO             8
#define CT_TOOLBAR           9
#define CT_TABCONTROL       10
#define CT_STATUSBAR        11
#define CT_BITBTN           12
#define CT_SPEEDBTN         13
#define CT_IMAGE            14
#define CT_SHAPE            15
#define CT_BEVEL            16
#define CT_TREEVIEW         20
#define CT_LISTVIEW         21
#define CT_PROGRESSBAR      22
#define CT_RICHEDIT         23
#define CT_MEMO             24
#define CT_PANEL            25
#define CT_SCROLLBAR        26
#define CT_MASKEDIT         28
#define CT_STRINGGRID       29
#define CT_SCROLLBOX        30
#define CT_STATICTEXT       31
#define CT_LABELEDEDIT      32
#define CT_TABCONTROL2      33
#define CT_TRACKBAR         34
#define CT_UPDOWN           35
#define CT_DATETIMEPICKER   36
#define CT_MONTHCALENDAR    37
// Non-visual: System
#define CT_TIMER            38
#define CT_PAINTBOX         39
// Non-visual: Dialogs
#define CT_OPENDIALOG       40
#define CT_SAVEDIALOG       41
#define CT_FONTDIALOG       42
#define CT_COLORDIALOG      43
#define CT_FINDDIALOG       44
#define CT_REPLACEDIALOG    45
// Non-visual: AI
#define CT_OPENAI           46
#define CT_GEMINI           47
#define CT_CLAUDE           48
#define CT_DEEPSEEK         49
#define CT_GROK             50
#define CT_OLLAMA           51
#define CT_TRANSFORMER      52
// Non-visual: Data Access
#define CT_DBFTABLE         53
#define CT_MYSQL            54
#define CT_MARIADB          55
#define CT_POSTGRESQL       56
#define CT_SQLITE           57
#define CT_FIREBIRD         58
#define CT_SQLSERVER        59
#define CT_ORACLE           60
#define CT_MONGODB          61
// Non-visual: Internet
#define CT_WEBVIEW          62
#define CT_THREAD           63
#define CT_MUTEX            64
#define CT_SEMAPHORE        65
#define CT_CRITICALSECTION  66
#define CT_THREADPOOL       67
#define CT_ATOMICINT        68
#define CT_CONDVAR          69
#define CT_CHANNEL          70
#define CT_WEBSERVER        71
#define CT_WEBSOCKET        72
#define CT_HTTPCLIENT       73
#define CT_FTPCLIENT        74
#define CT_SMTPCLIENT       75
#define CT_TCPSERVER        76
#define CT_TCPCLIENT        77
#define CT_UDPSOCKET        78
// Data-aware controls
#define CT_BROWSE           79
#define CT_DBGRID           80
#define CT_DBNAVIGATOR      81
#define CT_DBTEXT           82
#define CT_DBEDIT           83
#define CT_DBCOMBOBOX       84
#define CT_DBCHECKBOX       85
#define CT_DBIMAGE          86
#define CT_BRWCOLUMN        87
// Non-visual: Business
#define CT_PREPROCESSOR     90
#define CT_SCRIPTENGINE     91
#define CT_REPORTDESIGNER   92
#define CT_BARCODE          93
#define CT_PDFGENERATOR     94
#define CT_EXCELEXPORT      95
#define CT_AUDITLOG         96
#define CT_PERMISSIONS      97
#define CT_CURRENCY         98
#define CT_TAXENGINE        99
#define CT_DASHBOARD       100
#define CT_SCHEDULER       101
// Non-visual: Printing
#define CT_PRINTER         102
#define CT_REPORT          103
#define CT_LABELS          104
#define CT_PRINTPREVIEW    105
#define CT_PAGESETUP       106
#define CT_PRINTDIALOG     107
#define CT_REPORTVIEWER    108
#define CT_BARCODEPRINTER  109
// Non-visual: AI (extended)
#define CT_WHISPER         110
#define CT_EMBEDDINGS      111
// Non-visual: Scripting
#define CT_PYTHON          112
#define CT_SWIFT           113
#define CT_GO              114
#define CT_NODE            115
#define CT_RUST            116
#define CT_JAVA            117
#define CT_DOTNET          118
#define CT_LUA             119
#define CT_RUBY            120
// Non-visual: Git
#define CT_GITREPO         121
#define CT_GITCOMMIT       122
#define CT_GITBRANCH       123
#define CT_GITLOG          124
#define CT_GITDIFF         125
#define CT_GITREMOTE       126
#define CT_GITSTASH        127
#define CT_GITTAG          128
#define CT_GITBLAME        129
#define CT_GITMERGE        130
// Non-visual: Data containers
#define CT_COMPARRAY       131
#define CT_MAINMENU        132   // Linux non-visual menu bar (same value as CT_BAND, which is Windows-only)

// Report designer
#define CT_BAND            132
#define CT_REPORTLABEL     133
#define CT_REPORTFIELD     134
#define CT_REPORTIMAGE     135

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
