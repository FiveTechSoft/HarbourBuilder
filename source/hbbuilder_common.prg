/* hbbuilder_common.prg - Shared IDE helpers (linked with all platform IDEs) */

#include "../include/hbide.ch"

/* --- Code generation string helpers (Phase 2) --- */

FUNCTION HB_EscapeHarbourStr( cText )
   LOCAL c

   IF cText == NIL .OR. ValType( cText ) != "C"
      RETURN ""
   ENDIF

   c := cText
   c := StrTran( c, "\", "\\" )
   c := StrTran( c, '"', '\"' )
   c := StrTran( c, Chr(13), '\r' )
   c := StrTran( c, Chr(10), '\n' )
   c := StrTran( c, Chr(9), '\t' )
RETURN c

FUNCTION HB_QHarbourStr( cText )
RETURN '"' + HB_EscapeHarbourStr( cText ) + '"'

FUNCTION HB_NormalizeCtrlType( nType )
   DO CASE
   CASE nType == CT_POPUPMENU_LEGACY
      RETURN CT_POPUPMENU
   ENDCASE
RETURN nType

/* --- Project / file helpers --- */

FUNCTION HB_PrgBaseName( cFile )
   LOCAL cName, nPos

   IF Empty( cFile )
      RETURN ""
   ENDIF

   nPos := Max( RAt( "\", cFile ), RAt( "/", cFile ) )
   cName := SubStr( cFile, nPos + 1 )
   IF "." $ cName
      cName := Left( cName, At( ".", cName ) - 1 )
   ENDIF
RETURN cName

FUNCTION HB_ProjectTabInfo( nTab, nForms, nModules )
   IF nTab == 1
      RETURN { "project", 0 }
   ELSEIF nTab <= nForms + 1
      RETURN { "form", nTab - 1 }
   ELSEIF nTab <= nForms + nModules + 1
      RETURN { "module", nTab - nForms - 1 }
   ENDIF
RETURN { "openfile", nTab - nForms - nModules - 1 }

FUNCTION HB_BuildHbpIndex( aFormNames, aModuleNames )
   LOCAL cHbp := "Project1" + Chr(10), i

   FOR i := 1 TO Len( aFormNames )
      cHbp += aFormNames[i] + Chr(10)
   NEXT

   IF Len( aModuleNames ) > 0
      cHbp += "[modules]" + Chr(10)
      FOR i := 1 TO Len( aModuleNames )
         cHbp += aModuleNames[i] + Chr(10)
      NEXT
   ENDIF
RETURN cHbp

/* --- HIX path security (Phase 4) --- */

FUNCTION HIX_ResolvePath( cRoot, cRel )
   LOCAL cFull, cNorm, cRootNorm

   IF cRel == NIL .OR. Empty( cRel )
      RETURN ""
   ENDIF

   cRel := StrTran( cRel, "\", "/" )
   IF ".." $ cRel
      RETURN ""
   ENDIF

   IF Empty( cRoot )
      cRoot := "."
   ENDIF
   cRoot := StrTran( cRoot, "\", "/" )
   DO WHILE Right( cRoot, 1 ) == "/"
      cRoot := Left( cRoot, Len( cRoot ) - 1 )
   ENDDO

   IF Left( cRel, 1 ) == "/"
      cFull := cRoot + cRel
   ELSEIF Len( cRel ) >= 2 .AND. SubStr( cRel, 2, 1 ) == ":"
      cFull := cRel
   ELSE
      cFull := cRoot + "/" + cRel
   ENDIF

   cNorm := StrTran( StrTran( cFull, "\", "/" ), "//", "/" )
   cRootNorm := Lower( cRoot )
   IF ! ( Lower( cNorm ) == cRootNorm .OR. ;
         Left( Lower( cNorm ), Len( cRootNorm ) + 1 ) == cRootNorm + "/" )
      RETURN ""
   ENDIF

RETURN cNorm

/* --- Component type metadata (Phase 2/3) --- */

FUNCTION IsNonVisual( nType )
   IF nType == CT_WEBVIEW .OR. ;
      ( nType >= CT_BROWSE .AND. nType <= CT_DBIMAGE ) .OR. ;
      ( nType >= CT_BAND .AND. nType <= CT_REPORTIMAGE ) .OR. ;
      nType == CT_MAP .OR. nType == CT_SCENE3D .OR. nType == CT_EARTHVIEW
      RETURN .F.
   ENDIF
   IF nType == CT_MAINMENU .OR. nType == CT_POPUPMENU
      RETURN .T.
   ENDIF
RETURN nType >= CT_TIMER

FUNCTION ComponentTypeName( nType )
   DO CASE
   CASE nType == CT_TIMER;        RETURN "CT_TIMER"
   CASE nType == CT_PAINTBOX;     RETURN "CT_PAINTBOX"
   CASE nType == CT_OPENDIALOG;   RETURN "CT_OPENDIALOG"
   CASE nType == CT_SAVEDIALOG;   RETURN "CT_SAVEDIALOG"
   CASE nType == CT_FONTDIALOG;   RETURN "CT_FONTDIALOG"
   CASE nType == CT_COLORDIALOG;  RETURN "CT_COLORDIALOG"
   CASE nType == CT_FINDDIALOG;   RETURN "CT_FINDDIALOG"
   CASE nType == CT_REPLACEDIALOG; RETURN "CT_REPLACEDIALOG"
   CASE nType == CT_OPENAI;       RETURN "CT_OPENAI"
   CASE nType == CT_GEMINI;       RETURN "CT_GEMINI"
   CASE nType == CT_CLAUDE;       RETURN "CT_CLAUDE"
   CASE nType == CT_DEEPSEEK;     RETURN "CT_DEEPSEEK"
   CASE nType == CT_GROK;         RETURN "CT_GROK"
   CASE nType == CT_OLLAMA;       RETURN "CT_OLLAMA"
   CASE nType == CT_TRANSFORMER;  RETURN "CT_TRANSFORMER"
   CASE nType == CT_DBFTABLE;     RETURN "CT_DBFTABLE"
   CASE nType == CT_MYSQL;        RETURN "CT_MYSQL"
   CASE nType == CT_MARIADB;     RETURN "CT_MARIADB"
   CASE nType == CT_POSTGRESQL;  RETURN "CT_POSTGRESQL"
   CASE nType == CT_SQLITE;      RETURN "CT_SQLITE"
   CASE nType == CT_FIREBIRD;    RETURN "CT_FIREBIRD"
   CASE nType == CT_SQLSERVER;   RETURN "CT_SQLSERVER"
   CASE nType == CT_ORACLE;      RETURN "CT_ORACLE"
   CASE nType == CT_MONGODB;     RETURN "CT_MONGODB"
   CASE nType == CT_WEBVIEW;     RETURN "CT_WEBVIEW"
   CASE nType == CT_THREAD;      RETURN "CT_THREAD"
   CASE nType == CT_MUTEX;       RETURN "CT_MUTEX"
   CASE nType == CT_SEMAPHORE;   RETURN "CT_SEMAPHORE"
   CASE nType == CT_CRITICALSECTION; RETURN "CT_CRITICALSECTION"
   CASE nType == CT_THREADPOOL;  RETURN "CT_THREADPOOL"
   CASE nType == CT_ATOMICINT;   RETURN "CT_ATOMICINT"
   CASE nType == CT_CONDVAR;     RETURN "CT_CONDVAR"
   CASE nType == CT_CHANNEL;     RETURN "CT_CHANNEL"
   CASE nType == CT_WEBSERVER;   RETURN "CT_WEBSERVER"
   CASE nType == CT_WEBSOCKET;   RETURN "CT_WEBSOCKET"
   CASE nType == CT_HTTPCLIENT;  RETURN "CT_HTTPCLIENT"
   CASE nType == CT_FTPCLIENT;   RETURN "CT_FTPCLIENT"
   CASE nType == CT_SMTPCLIENT;  RETURN "CT_SMTPCLIENT"
   CASE nType == CT_TCPSERVER;   RETURN "CT_TCPSERVER"
   CASE nType == CT_TCPCLIENT;   RETURN "CT_TCPCLIENT"
   CASE nType == CT_UDPSOCKET;   RETURN "CT_UDPSOCKET"
   CASE nType == CT_BROWSE;      RETURN "CT_BROWSE"
   CASE nType == CT_DBGRID;      RETURN "CT_DBGRID"
   CASE nType == CT_DBNAVIGATOR; RETURN "CT_DBNAVIGATOR"
   CASE nType == CT_DBTEXT;      RETURN "CT_DBTEXT"
   CASE nType == CT_DBEDIT;      RETURN "CT_DBEDIT"
   CASE nType == CT_DBCOMBOBOX;  RETURN "CT_DBCOMBOBOX"
   CASE nType == CT_DBCHECKBOX;  RETURN "CT_DBCHECKBOX"
   CASE nType == CT_DBIMAGE;     RETURN "CT_DBIMAGE"
   CASE nType == CT_PREPROCESSOR; RETURN "CT_PREPROCESSOR"
   CASE nType == CT_SCRIPTENGINE; RETURN "CT_SCRIPTENGINE"
   CASE nType == CT_REPORTDESIGNER; RETURN "CT_REPORTDESIGNER"
   CASE nType == CT_BARCODE;     RETURN "CT_BARCODE"
   CASE nType == CT_PDFGENERATOR; RETURN "CT_PDFGENERATOR"
   CASE nType == CT_EXCELEXPORT; RETURN "CT_EXCELEXPORT"
   CASE nType == CT_AUDITLOG;    RETURN "CT_AUDITLOG"
   CASE nType == CT_PERMISSIONS; RETURN "CT_PERMISSIONS"
   CASE nType == CT_CURRENCY;    RETURN "CT_CURRENCY"
   CASE nType == CT_TAXENGINE;   RETURN "CT_TAXENGINE"
   CASE nType == CT_DASHBOARD;   RETURN "CT_DASHBOARD"
   CASE nType == CT_SCHEDULER;   RETURN "CT_SCHEDULER"
   CASE nType == CT_PRINTER;     RETURN "CT_PRINTER"
   CASE nType == CT_REPORT;      RETURN "CT_REPORT"
   CASE nType == CT_LABELS;      RETURN "CT_LABELS"
   CASE nType == CT_PRINTPREVIEW; RETURN "CT_PRINTPREVIEW"
   CASE nType == CT_PAGESETUP;    RETURN "CT_PAGESETUP"
   CASE nType == CT_PRINTDIALOG; RETURN "CT_PRINTDIALOG"
   CASE nType == CT_REPORTVIEWER; RETURN "CT_REPORTVIEWER"
   CASE nType == CT_BARCODEPRINTER; RETURN "CT_BARCODEPRINTER"
   CASE nType == CT_WHISPER;     RETURN "CT_WHISPER"
   CASE nType == CT_EMBEDDINGS;  RETURN "CT_EMBEDDINGS"
   CASE nType == CT_PYTHON;      RETURN "CT_PYTHON"
   CASE nType == CT_SWIFT;       RETURN "CT_SWIFT"
   CASE nType == CT_GO;          RETURN "CT_GO"
   CASE nType == CT_NODE;        RETURN "CT_NODE"
   CASE nType == CT_RUST;        RETURN "CT_RUST"
   CASE nType == CT_JAVA;        RETURN "CT_JAVA"
   CASE nType == CT_DOTNET;      RETURN "CT_DOTNET"
   CASE nType == CT_LUA;         RETURN "CT_LUA"
   CASE nType == CT_RUBY;        RETURN "CT_RUBY"
   CASE nType == CT_GITREPO;     RETURN "CT_GITREPO"
   CASE nType == CT_GITCOMMIT;   RETURN "CT_GITCOMMIT"
   CASE nType == CT_GITBRANCH;   RETURN "CT_GITBRANCH"
   CASE nType == CT_GITLOG;      RETURN "CT_GITLOG"
   CASE nType == CT_GITDIFF;     RETURN "CT_GITDIFF"
   CASE nType == CT_GITREMOTE;   RETURN "CT_GITREMOTE"
   CASE nType == CT_GITSTASH;    RETURN "CT_GITSTASH"
   CASE nType == CT_GITTAG;      RETURN "CT_GITTAG"
   CASE nType == CT_GITBLAME;    RETURN "CT_GITBLAME"
   CASE nType == CT_GITMERGE;    RETURN "CT_GITMERGE"
   CASE nType == CT_COMPARRAY;   RETURN "CT_COMPARRAY"
   CASE nType == CT_BAND;        RETURN "CT_BAND"
   CASE nType == CT_MAINMENU;    RETURN "CT_MAINMENU"
   CASE nType == CT_POPUPMENU;   RETURN "CT_POPUPMENU"
   CASE nType == CT_REPORTLABEL; RETURN "CT_REPORTLABEL"
   CASE nType == CT_REPORTFIELD; RETURN "CT_REPORTFIELD"
   CASE nType == CT_REPORTIMAGE; RETURN "CT_REPORTIMAGE"
   ENDCASE
RETURN "CT_UNKNOWN_" + LTrim( Str( nType ) )

FUNCTION ComponentTypeFromName( cName )
   LOCAL i, aMap := { ;
      { "CT_TIMER", CT_TIMER }, { "CT_PAINTBOX", CT_PAINTBOX }, ;
      { "CT_OPENDIALOG", CT_OPENDIALOG }, { "CT_SAVEDIALOG", CT_SAVEDIALOG }, ;
      { "CT_FONTDIALOG", CT_FONTDIALOG }, { "CT_COLORDIALOG", CT_COLORDIALOG }, ;
      { "CT_FINDDIALOG", CT_FINDDIALOG }, { "CT_REPLACEDIALOG", CT_REPLACEDIALOG }, ;
      { "CT_OPENAI", CT_OPENAI }, { "CT_GEMINI", CT_GEMINI }, { "CT_CLAUDE", CT_CLAUDE }, ;
      { "CT_DEEPSEEK", CT_DEEPSEEK }, { "CT_GROK", CT_GROK }, { "CT_OLLAMA", CT_OLLAMA }, ;
      { "CT_TRANSFORMER", CT_TRANSFORMER }, ;
      { "CT_DBFTABLE", CT_DBFTABLE }, { "CT_MYSQL", CT_MYSQL }, { "CT_MARIADB", CT_MARIADB }, ;
      { "CT_POSTGRESQL", CT_POSTGRESQL }, { "CT_SQLITE", CT_SQLITE }, { "CT_FIREBIRD", CT_FIREBIRD }, ;
      { "CT_SQLSERVER", CT_SQLSERVER }, { "CT_ORACLE", CT_ORACLE }, { "CT_MONGODB", CT_MONGODB }, ;
      { "CT_WEBVIEW", CT_WEBVIEW }, { "CT_THREAD", CT_THREAD }, { "CT_MUTEX", CT_MUTEX }, ;
      { "CT_SEMAPHORE", CT_SEMAPHORE }, { "CT_CRITICALSECTION", CT_CRITICALSECTION }, ;
      { "CT_THREADPOOL", CT_THREADPOOL }, { "CT_ATOMICINT", CT_ATOMICINT }, ;
      { "CT_CONDVAR", CT_CONDVAR }, { "CT_CHANNEL", CT_CHANNEL }, ;
      { "CT_WEBSERVER", CT_WEBSERVER }, { "CT_WEBSOCKET", CT_WEBSOCKET }, ;
      { "CT_HTTPCLIENT", CT_HTTPCLIENT }, { "CT_FTPCLIENT", CT_FTPCLIENT }, ;
      { "CT_SMTPCLIENT", CT_SMTPCLIENT }, { "CT_TCPSERVER", CT_TCPSERVER }, ;
      { "CT_TCPCLIENT", CT_TCPCLIENT }, { "CT_UDPSOCKET", CT_UDPSOCKET }, ;
      { "CT_BROWSE", CT_BROWSE }, { "CT_DBGRID", CT_DBGRID }, { "CT_DBNAVIGATOR", CT_DBNAVIGATOR }, ;
      { "CT_DBTEXT", CT_DBTEXT }, { "CT_DBEDIT", CT_DBEDIT }, { "CT_DBCOMBOBOX", CT_DBCOMBOBOX }, ;
      { "CT_DBCHECKBOX", CT_DBCHECKBOX }, { "CT_DBIMAGE", CT_DBIMAGE }, ;
      { "CT_PREPROCESSOR", CT_PREPROCESSOR }, { "CT_SCRIPTENGINE", CT_SCRIPTENGINE }, ;
      { "CT_REPORTDESIGNER", CT_REPORTDESIGNER }, { "CT_BARCODE", CT_BARCODE }, ;
      { "CT_PDFGENERATOR", CT_PDFGENERATOR }, { "CT_EXCELEXPORT", CT_EXCELEXPORT }, ;
      { "CT_AUDITLOG", CT_AUDITLOG }, { "CT_PERMISSIONS", CT_PERMISSIONS }, ;
      { "CT_CURRENCY", CT_CURRENCY }, { "CT_TAXENGINE", CT_TAXENGINE }, ;
      { "CT_DASHBOARD", CT_DASHBOARD }, { "CT_SCHEDULER", CT_SCHEDULER }, ;
      { "CT_PRINTER", CT_PRINTER }, { "CT_REPORT", CT_REPORT }, { "CT_LABELS", CT_LABELS }, ;
      { "CT_PRINTPREVIEW", CT_PRINTPREVIEW }, { "CT_PAGESETUP", CT_PAGESETUP }, ;
      { "CT_PRINTDIALOG", CT_PRINTDIALOG }, { "CT_REPORTVIEWER", CT_REPORTVIEWER }, ;
      { "CT_BARCODEPRINTER", CT_BARCODEPRINTER }, ;
      { "CT_WHISPER", CT_WHISPER }, { "CT_EMBEDDINGS", CT_EMBEDDINGS }, ;
      { "CT_PYTHON", CT_PYTHON }, { "CT_SWIFT", CT_SWIFT }, { "CT_GO", CT_GO }, ;
      { "CT_NODE", CT_NODE }, { "CT_RUST", CT_RUST }, { "CT_JAVA", CT_JAVA }, ;
      { "CT_DOTNET", CT_DOTNET }, { "CT_LUA", CT_LUA }, { "CT_RUBY", CT_RUBY }, ;
      { "CT_GITREPO", CT_GITREPO }, { "CT_GITCOMMIT", CT_GITCOMMIT }, ;
      { "CT_GITBRANCH", CT_GITBRANCH }, { "CT_GITLOG", CT_GITLOG }, ;
      { "CT_GITDIFF", CT_GITDIFF }, { "CT_GITREMOTE", CT_GITREMOTE }, ;
      { "CT_GITSTASH", CT_GITSTASH }, { "CT_GITTAG", CT_GITTAG }, ;
      { "CT_GITBLAME", CT_GITBLAME }, { "CT_GITMERGE", CT_GITMERGE }, ;
      { "CT_COMPARRAY", CT_COMPARRAY }, ;
      { "CT_BAND", CT_BAND }, ;
      { "CT_REPORTLABEL", CT_REPORTLABEL }, { "CT_REPORTFIELD", CT_REPORTFIELD }, ;
      { "CT_REPORTIMAGE", CT_REPORTIMAGE }, ;
      { "CT_MAINMENU", CT_MAINMENU }, { "CT_POPUPMENU", CT_POPUPMENU } }

   FOR i := 1 TO Len( aMap )
      IF Upper( cName ) == aMap[i][1]
         RETURN aMap[i][2]
      ENDIF
   NEXT
RETURN 0

FUNCTION ResolveComponentType( cName )
RETURN ComponentTypeFromName( cName )