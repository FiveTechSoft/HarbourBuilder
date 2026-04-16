// hbbuilder.ch - xBase commands for the IDE framework
// Translates familiar syntax to TForm/TControl OOP calls

#ifndef _IDECOMMANDS_CH
#define _IDECOMMANDS_CH

#include "hbclass.ch"
#include "hbide.ch"

// BorderStyle constants (C++Builder TFormBorderStyle)
#define bsNone           0
#define bsSingle         1
#define bsSizeable       2
#define bsDialog         3
#define bsToolWindow     4
#define bsSizeToolWin    5

// BorderIcons (bitmask, C++Builder TBorderIcons)
#define biSystemMenu     1
#define biMinimize       2
#define biMaximize       4
#define biHelp           8

// Position constants (C++Builder TPosition)
#define poDesigned       0
#define poDefault        1
#define poScreenCenter   2
#define poDesktopCenter  3
#define poMainFormCenter 4

// WindowState constants (C++Builder TWindowState)
#define wsNormal         0
#define wsMinimized      1
#define wsMaximized      2

// FormStyle constants (C++Builder TFormStyle)
#define fsNormal         0
#define fsStayOnTop      1
#define fsMDIChild       2
#define fsMDIForm        3

// System colors (C++Builder style, BGR byte order)
#define clBtnFace        15790320    // 0x00F0F0F0
#define clBtnShadow       8421504    // 0x00808080
#define clBlack                 0
#define clWhite          16777215    // 0x00FFFFFF
#define clRed                 255    // 0x000000FF (BGR)
#define clGreen             65280    // 0x0000FF00
#define clBlue           16711680    // 0x00FF0000

// BitBtn Kind (C++Builder TBitBtnKind)
#define bkCustom         0
#define bkOK             1
#define bkCancel         2
#define bkHelp           3
#define bkYes            4
#define bkNo             5
#define bkClose          6
#define bkAbort          7
#define bkRetry          8
#define bkIgnore         9
#define bkAll           10

// ModalResult (C++Builder TModalResult)
#define mrNone           0
#define mrOk             1
#define mrCancel         2
#define mrAbort          3
#define mrRetry          4
#define mrIgnore         5
#define mrYes            6
#define mrNo             7
#define mrAll            8
#define mrClose          9

// Cursor constants (C++Builder TCursor)
#define crDefault        0
#define crArrow          1
#define crIBeam          2
#define crCross          3
#define crHand           4
#define crSizeNESW       5
#define crSizeNS         6
#define crSizeNWSE       7
#define crSizeWE         8
#define crWait           9
#define crHelp          10
#define crNo            11

// Form
#xcommand DEFINE FORM <oForm> ;
      [ TITLE <cTitle> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
      [ FONT <cFont> [, <nSize>] ] ;
      [ <sizable: SIZABLE> ] ;
      [ <appbar: APPBAR> ] ;
      [ <toolwin: TOOLWINDOW> ] ;
   => ;
      <oForm> := TForm():New( <cTitle>, <nWidth>, <nHeight> ) ;
      [; <oForm>:FontName := <cFont> ] ;
      [; <oForm>:FontSize := <nSize> ] ;
      [; <oForm>:Sizable := <.sizable.> ] ;
      [; <oForm>:AppBar := <.appbar.> ] ;
      [; <oForm>:ToolWindow := <.toolwin.> ]

#xcommand ACTIVATE FORM <oForm> [ <center: CENTERED> ] => ;
      <oForm>:Activate()

// Label / SAY
#xcommand @ <nTop>, <nLeft> SAY <oCtrl> ;
      [ PROMPT <cText> ] ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth> [, <nHeight>] ] ;
   => ;
      <oCtrl> := TLabel():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

#xcommand @ <nTop>, <nLeft> SAY <cText> ;
      OF <oParent> ;
      [ SIZE <nWidth> [, <nHeight>] ] ;
   => ;
      TLabel():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

// Edit / GET
#xcommand @ <nTop>, <nLeft> GET <oCtrl> ;
      [ VAR <cVar> ] ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth> [, <nHeight>] ] ;
   => ;
      <oCtrl> := TEdit():New( <oParent>, <cVar>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

// Button with w,h
#xcommand @ <nTop>, <nLeft> BUTTON <oCtrl> ;
      PROMPT <cText> ;
      OF <oParent> ;
      SIZE <nWidth>, <nHeight> ;
      [ <default: DEFAULT> ] ;
      [ <cancel: CANCEL> ] ;
   => ;
      <oCtrl> := TButton():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth>, <nHeight> ) ;
      [; <oCtrl>:Default := <.default.> ] ;
      [; <oCtrl>:Cancel := <.cancel.> ]

// BitBtn (button with image/kind)
#xcommand @ <nTop>, <nLeft> BITBTN <oCtrl> ;
      [ PROMPT <cText> ] ;
      OF <oParent> ;
      SIZE <nWidth>, <nHeight> ;
      [ KIND <nKind> ] ;
      [ PICTURE <cPic> ] ;
   => ;
      <oCtrl> := TBitBtn():New( <oParent>, <cText>, <nLeft>, <nTop>, ;
                                <nWidth>, <nHeight>, <nKind>, <cPic> )

// SpeedButton (borderless button with image/kind)
#xcommand @ <nTop>, <nLeft> SPEEDBUTTON <oCtrl> ;
      [ PROMPT <cText> ] ;
      OF <oParent> ;
      SIZE <nWidth>, <nHeight> ;
      [ KIND <nKind> ] ;
      [ PICTURE <cPic> ] ;
   => ;
      <oCtrl> := TSpeedButton():New( <oParent>, <cText>, <nLeft>, <nTop>, ;
                                     <nWidth>, <nHeight>, <nKind>, <cPic> )

// Image
#xcommand @ <nTop>, <nLeft> IMAGE <oCtrl> ;
      OF <oParent> ;
      SIZE <nWidth>, <nHeight> ;
      [ PICTURE <cPic> ] ;
   => ;
      <oCtrl> := TImage():New( <oParent>, <nLeft>, <nTop>, <nWidth>, <nHeight>, <cPic> )

// Memo
#xcommand @ <nTop>, <nLeft> MEMO <oCtrl> ;
      [ VAR <cVar> ] ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
   => ;
      <oCtrl> := TMemo():New( <oParent>, <cVar>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

// Browse
#xcommand @ <nTop>, <nLeft> TREEVIEW <oCtrl> ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
      [ ITEMS <items,...> ] ;
   => ;
      <oCtrl> := TTreeView():New( <oParent>, <nLeft>, <nTop>, <nWidth>, <nHeight> ) ;
      [; <oCtrl>:SetItems( \{ <items> \} ) ]

#xcommand @ <nTop>, <nLeft> FOLDER <oCtrl> ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
      [ PROMPTS <prompts,...> ] ;
   => ;
      <oCtrl> := TFolder():New( <oParent>, <nLeft>, <nTop>, <nWidth>, <nHeight> ) ;
      [; <oCtrl>:SetPrompts( \{ <prompts> \} ) ]

#xcommand @ <nTop>, <nLeft> BROWSE <oCtrl> ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
      [ HEADERS <hdrs,...> ] ;
      [ COLSIZES <sizes,...> ] ;
      [ FOOTERS <ftrs,...> ] ;
   => ;
      <oCtrl> := TBrowse():New( <oParent>, <nLeft>, <nTop>, <nWidth>, <nHeight> ) ;
      [; <oCtrl>:SetupColumns( \{ <hdrs> \} ) ] ;
      [; <oCtrl>:SetColSizes( \{ <sizes> \} ) ] ;
      [; <oCtrl>:SetFooters( \{ <ftrs> \} ) ]

// CheckBox
#xcommand @ <nTop>, <nLeft> CHECKBOX <oCtrl> ;
      PROMPT <cText> ;
      OF <oParent> ;
      SIZE <nWidth> ;
      [ <checked: CHECKED> ] ;
   => ;
      <oCtrl> := TCheckBox():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth> ) ;
      [; <oCtrl>:Checked := <.checked.> ]

// ComboBox
#xcommand @ <nTop>, <nLeft> COMBOBOX <oCtrl> ;
      [ OF <oParent> ] ;
      [ ITEMS <aItems> ] ;
      [ SIZE <nWidth> [, <nHeight>] ] ;
   => ;
      <oCtrl> := TComboBox():New( <oParent>, <nLeft>, <nTop>, <nWidth>, <nHeight> ) ;
      [; <oCtrl>:FillItems( <aItems> ) ]

// RadioButton
#xcommand @ <nTop>, <nLeft> RADIOBUTTON <oCtrl> ;
      PROMPT <cText> ;
      OF <oParent> ;
      SIZE <nWidth> ;
      [ <checked: CHECKED> ] ;
   => ;
      <oCtrl> := TRadioButton():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth> ) ;
      [; <oCtrl>:Checked := <.checked.> ]

// ListBox
#xcommand @ <nTop>, <nLeft> LISTBOX <oCtrl> ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
      [ ITEMS <items,...> ] ;
   => ;
      <oCtrl> := TListBox():New( <oParent>, <nLeft>, <nTop>, <nWidth>, <nHeight> ) ;
      [; <oCtrl>:SetItems( \{ <items> \} ) ]

// GroupBox
#xcommand @ <nTop>, <nLeft> GROUPBOX <oCtrl> ;
      [ PROMPT <cText> ] ;
      [ OF <oParent> ] ;
      SIZE <nWidth>, <nHeight> ;
   => ;
      <oCtrl> := TGroupBox():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

// Shortcut: GROUPBOX without object var
#xcommand @ <nTop>, <nLeft> GROUPBOX ;
      <cText> ;
      OF <oParent> ;
      SIZE <nWidth>, <nHeight> ;
   => ;
      TGroupBox():New( <oParent>, <cText>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

// Toolbar
#xcommand DEFINE TOOLBAR <oTB> OF <oForm> => ;
   <oTB> := TToolBar():New( <oForm> )

#xcommand BUTTON <cText> [ OF <oTB> ] ;
      [ TOOLTIP <cTip> ] ;
      [ ACTION <action> ] ;
   => ;
      <oTB>:AddButton( <cText>, <cTip>, [ { || <action> } ] )

#xcommand SEPARATOR OF <oTB> => ;
   <oTB>:AddSeparator()

// Component Palette
#xcommand DEFINE PALETTE <oPal> OF <oForm> => ;
   <oPal> := TComponentPalette():New( <oForm> )

// Menu
#xcommand DEFINE MENUBAR OF <oForm> => ;
   <oForm>:CreateMenu()

#xcommand DEFINE POPUP <oPopup> PROMPT <cText> OF <oForm> => ;
   <oPopup> := <oForm>:AddPopup( <cText> )

#xcommand MENUITEM <cText> OF <oPopup> ACTION <action> ;
      [ ACCEL <cKey> ] => ;
   <oPopup>:AddItem( <cText>, { || <action> }, <cKey> )

#xcommand MENUSEPARATOR OF <oPopup> => ;
   <oPopup>:AddSeparator()

// Report Designer commands
#xcommand DEFINE REPORT <oRpt> ;
      [ TITLE <cTitle> ] ;
      [ DATASOURCE <oDS> ] ;
   => ;
      <oRpt> := TReport():New() ;
      [; <oRpt>:cTitle := <cTitle> ] ;
      [; <oRpt>:oDataSource := <oDS> ]

#xcommand DEFINE BAND <oBand> NAME <cName> ;
      [ HEIGHT <nH> ] ;
      OF <oRpt> ;
   => ;
      <oBand> := TReportBand():New( <cName> ) ;
      [; <oBand>:nHeight := <nH> ] ;
      ; <oRpt>:AddDesignBand( <oBand> )

// REPORT TEXT - static text field with font
#xcommand REPORT TEXT <oFld> ;
      PROMPT <cText> ;
      AT <nTop>, <nLeft> ;
      SIZE <nW>, <nH> ;
      FONT <cFont>, <nFSize> ;
      [ <bold: BOLD> ] ;
      [ <italic: ITALIC> ] ;
      [ ALIGN <nAlign> ] ;
      OF <oBand> ;
   => ;
      <oFld> := RPT_NewTextField( <oBand>, <cText>, ;
         <nTop>, <nLeft>, <nW>, <nH>, ;
         <cFont>, <nFSize>, <.bold.>, <.italic.>, <nAlign> )

// REPORT TEXT - static text field without font
#xcommand REPORT TEXT <oFld> ;
      PROMPT <cText> ;
      AT <nTop>, <nLeft> ;
      SIZE <nW>, <nH> ;
      [ <bold: BOLD> ] ;
      [ <italic: ITALIC> ] ;
      [ ALIGN <nAlign> ] ;
      OF <oBand> ;
   => ;
      <oFld> := RPT_NewTextField( <oBand>, <cText>, ;
         <nTop>, <nLeft>, <nW>, <nH>, ;
         nil, nil, <.bold.>, <.italic.>, <nAlign> )

// REPORT DATA - data-bound field with font
#xcommand REPORT DATA <oFld> ;
      FIELD <cField> ;
      AT <nTop>, <nLeft> ;
      SIZE <nW>, <nH> ;
      FONT <cFont>, <nFSize> ;
      [ <bold: BOLD> ] ;
      [ <italic: ITALIC> ] ;
      [ ALIGN <nAlign> ] ;
      OF <oBand> ;
   => ;
      <oFld> := RPT_NewDataField( <oBand>, <cField>, ;
         <nTop>, <nLeft>, <nW>, <nH>, ;
         <cFont>, <nFSize>, <.bold.>, <.italic.>, <nAlign> )

// REPORT DATA - data-bound field without font
#xcommand REPORT DATA <oFld> ;
      FIELD <cField> ;
      AT <nTop>, <nLeft> ;
      SIZE <nW>, <nH> ;
      [ <bold: BOLD> ] ;
      [ <italic: ITALIC> ] ;
      [ ALIGN <nAlign> ] ;
      OF <oBand> ;
   => ;
      <oFld> := RPT_NewDataField( <oBand>, <cField>, ;
         <nTop>, <nLeft>, <nW>, <nH>, ;
         nil, nil, <.bold.>, <.italic.>, <nAlign> )

#xcommand REPORT PREVIEW <oRpt> => <oRpt>:Preview()

#xcommand REPORT PRINT <oRpt> => <oRpt>:Print()

// Non-visual component (used in generated CreateForm code)
#xcommand COMPONENT <oVar> TYPE <nType> OF <oParent> => ;
   <oVar> := HB_CreateComponent( <nType>, <oParent> )

#endif
