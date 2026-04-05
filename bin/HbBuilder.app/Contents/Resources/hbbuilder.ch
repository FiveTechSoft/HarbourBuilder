// hbbuilder.ch - xBase commands for the IDE framework
// Translates familiar syntax to TForm/TControl OOP calls

#ifndef _IDECOMMANDS_CH
#define _IDECOMMANDS_CH

#include "hbclass.ch"

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

// Memo
#xcommand @ <nTop>, <nLeft> MEMO <oCtrl> ;
      [ VAR <cVar> ] ;
      [ OF <oParent> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
   => ;
      <oCtrl> := TMemo():New( <oParent>, <cVar>, <nLeft>, <nTop>, <nWidth>, <nHeight> )

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
      [; AEval( <aItems>, { |x| <oCtrl>:AddItem( x ) } ) ]

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

#endif
