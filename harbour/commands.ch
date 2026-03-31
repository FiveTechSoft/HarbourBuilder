// commands.ch - xBase commands for the IDE framework
// Translates familiar syntax to TForm/TControl OOP calls

#ifndef _IDECOMMANDS_CH
#define _IDECOMMANDS_CH

// Form
#xcommand DEFINE FORM <oForm> ;
      [ TITLE <cTitle> ] ;
      [ SIZE <nWidth>, <nHeight> ] ;
      [ FONT <cFont> [, <nSize>] ] ;
   => ;
      <oForm> := TForm():New( <cTitle>, <nWidth>, <nHeight> ) ;
      [; <oForm>:FontName := <cFont> ] ;
      [; <oForm>:FontSize := <nSize> ]

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

#endif
