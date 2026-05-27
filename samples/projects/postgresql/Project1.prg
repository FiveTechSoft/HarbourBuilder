// Project1.prg — TPostgreSQL demo
// Demonstrates: properties, bOnConnect / bOnDisconnect / bOnError events,
// Tables(), Query(), Execute(), cursor navigation, LastInsertId, TableExists.
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp, oForm

   oApp := TApplication():New()
   oApp:cTitle := "TPostgreSQL Demo"

   oForm := TForm1():New()
   oApp:CreateForm( oForm )

   // ------- Wire TPostgreSQL events -------
   oForm:oDb1:bOnConnect := { || ;
      oForm:oStatus1:cText := "Connected → " + oForm:oDb1:cServer + ":" + ;
                             hb_ValToStr( oForm:oDb1:nPort ) + "/" + ;
                             oForm:oDb1:cDatabase, ;
      LogLine( oForm, "[OnConnect] handle ok, charset=" + oForm:oDb1:cCharSet ) }

   oForm:oDb1:bOnDisconnect := { || ;
      oForm:oStatus1:cText := "Disconnected.", ;
      LogLine( oForm, "[OnDisconnect]" ) }

   oForm:oDb1:bOnError := { | cMsg | ;
      oForm:oStatus1:cText := "ERROR: " + cMsg, ;
      LogLine( oForm, "[OnError] " + cMsg ) }

   // ------- Wire button handlers -------
   oForm:oBtnConnect:OnClick     := { || DoConnect   ( oForm ) }
   oForm:oBtnDisconnect:OnClick  := { || DoDisconnect( oForm ) }
   oForm:oBtnLoadTable:OnClick   := { || DoLoadTable ( oForm ) }
   oForm:oBtnExec:OnClick        := { || DoExecute   ( oForm ) }
   oForm:oBtnQuery:OnClick       := { || DoQuery     ( oForm ) }
   oForm:oBtnLastId:OnClick      := { || DoLastId    ( oForm ) }
   oForm:oBtnTop:OnClick         := { || NavTop ( oForm ) }
   oForm:oBtnPrev:OnClick        := { || NavSkip( oForm, -1 ) }
   oForm:oBtnNext:OnClick        := { || NavSkip( oForm,  1 ) }

   oApp:Run()

return
//--------------------------------------------------------------------

static function DoConnect( oForm )

   local oDb := oForm:oDb1, aTables, i

   // Push edits → properties
   oDb:cServer   := oForm:oEdHost:cText
   oDb:nPort     := Val( oForm:oEdPort:cText )
   oDb:cUser     := oForm:oEdUser:cText
   oDb:cPassword := oForm:oEdPass:cText
   oDb:cDatabase := oForm:oEdDb:cText
   oDb:cCharSet  := oForm:oEdCharSet:cText

   if oDb:IsConnected(); oDb:Close(); endif

   if ! oDb:Open()
      // bOnError already fired; cLastError populated
      return nil
   endif

   aTables := oDb:Tables()
   oForm:oLstTables:Clear()
   for i := 1 to Len( aTables )
      oForm:oLstTables:Add( aTables[ i ] )
   next
   LogLine( oForm, "Tables: " + hb_ValToStr( Len( aTables ) ) )

return nil
//--------------------------------------------------------------------

static function DoDisconnect( oForm )
   if oForm:oDb1:IsConnected()
      oForm:oDb1:Close()       // fires bOnDisconnect
   endif
return nil
//--------------------------------------------------------------------

static function DoLoadTable( oForm )

   local oDb := oForm:oDb1, cTable, n

   if ! oDb:IsConnected()
      oForm:oStatus1:cText := "Connect first."
      return nil
   endif

   n := oForm:oLstTables:Value
   if n < 1; oForm:oStatus1:cText := "Select a table."; return nil; endif

   cTable := oForm:oLstTables:GetItem( n )
   if ! oDb:TableExists( cTable )
      oForm:oStatus1:cText := "Table not found: " + cTable
      return nil
   endif

   oDb:cTable := cTable
   oDb:cSQL   := ""               // cTable wins
   oDb:LoadCursor()

   ShowCursorHeader( oForm )
   ShowCurrentRow  ( oForm )

return nil
//--------------------------------------------------------------------

static function DoExecute( oForm )

   local oDb := oForm:oDb1, cSQL, aRows, i, j, cOut

   if ! oDb:IsConnected()
      oForm:oStatus1:cText := "Connect first."
      return nil
   endif

   cSQL := AllTrim( oForm:oMemSQL:cText )
   if Empty( cSQL ); return nil; endif

   if Upper( Left( cSQL, 6 ) ) == "SELECT"
      // Use cSQL property + LoadCursor → cursor navigation works
      oDb:cTable := ""
      oDb:cSQL   := cSQL
      oDb:LoadCursor()
      ShowCursorHeader( oForm )
      ShowCurrentRow  ( oForm )
      return nil
   endif

   // Non-select: Execute
   if oDb:Execute( cSQL )
      cOut := "OK." + hb_eol()
      // If INSERT and a sequence is set, show LastInsertId
      if ! Empty( oDb:cIdSequence )
         cOut += "LastInsertId(" + oDb:cIdSequence + ") = " + ;
                 hb_ValToStr( oDb:LastInsertId() ) + hb_eol()
      endif
      oForm:oMemOut:cText := cOut
      oForm:oStatus1:cText := "Execute OK."
   else
      oForm:oMemOut:cText  := "FAIL: " + oDb:LastError()
      // bOnError already fired
   endif

return nil
//--------------------------------------------------------------------

static function DoQuery( oForm )

   local oDb := oForm:oDb1, cSQL, aRows, i, j, cOut := ""

   if ! oDb:IsConnected()
      oForm:oStatus1:cText := "Connect first."
      return nil
   endif

   cSQL := AllTrim( oForm:oMemSQL:cText )
   if Empty( cSQL ); return nil; endif

   aRows := oDb:Query( cSQL )    // direct Query() — returns array of rows
   cOut  := "Query rows: " + hb_ValToStr( Len( aRows ) ) + hb_eol()
   for i := 1 to Min( Len( aRows ), 200 )
      for j := 1 to Len( aRows[ i ] )
         cOut += iif( j > 1, " | ", "" ) + hb_ValToStr( aRows[ i ][ j ] )
      next
      cOut += hb_eol()
   next
   oForm:oMemOut:cText := cOut

return nil
//--------------------------------------------------------------------

static function DoLastId( oForm )

   local oDb := oForm:oDb1, nId

   if ! oDb:IsConnected()
      oForm:oStatus1:cText := "Connect first."
      return nil
   endif

   oDb:cIdSequence := AllTrim( oForm:oEdSeq:cText )    // set property
   if Empty( oDb:cIdSequence )
      oForm:oStatus1:cText := "Set sequence name (e.g. mytable_id_seq)."
      return nil
   endif

   nId := oDb:LastInsertId()                          // uses cIdSequence
   LogLine( oForm, "LastInsertId(" + oDb:cIdSequence + ") = " + hb_ValToStr( nId ) )

return nil
//--------------------------------------------------------------------

static function NavTop( oForm )
   if Empty( oForm:oDb1:aRows ); return nil; endif
   oForm:oDb1:GoTop()
   ShowCurrentRow( oForm )
return nil

static function NavSkip( oForm, n )
   local oDb := oForm:oDb1
   if Empty( oDb:aRows ); return nil; endif
   oDb:Skip( n )
   if oDb:nRecord > Len( oDb:aRows ); oDb:nRecord := Len( oDb:aRows ); endif
   if oDb:nRecord < 1;                oDb:nRecord := 1;                endif
   ShowCurrentRow( oForm )
return nil
//--------------------------------------------------------------------

static function ShowCursorHeader( oForm )

   local oDb := oForm:oDb1, i, cHdr := ""

   for i := 1 to oDb:FieldCount()
      cHdr += iif( i > 1, " | ", "" ) + oDb:FieldName( i )
   next
   oForm:oMemOut:cText := cHdr + hb_eol() + Replicate( "-", Len( cHdr ) ) + hb_eol()

return nil

static function ShowCurrentRow( oForm )

   local oDb := oForm:oDb1, i, cLine := "", cAll

   if oDb:Eof()
      cLine := "<EOF>"
   else
      for i := 1 to oDb:FieldCount()
         cLine += iif( i > 1, " | ", "" ) + hb_ValToStr( oDb:FieldGet( i ) )
      next
   endif

   cAll := oForm:oMemOut:cText + cLine + hb_eol()
   oForm:oMemOut:cText := cAll
   oForm:oLbRec:cText  := "Rec: " + hb_ValToStr( oDb:nRecord ) + "/" + ;
                                   hb_ValToStr( Len( oDb:aRows ) )

return nil
//--------------------------------------------------------------------

static function LogLine( oForm, cTxt )
   oForm:oMemOut:cText := oForm:oMemOut:cText + cTxt + hb_eol()
return nil
//--------------------------------------------------------------------
