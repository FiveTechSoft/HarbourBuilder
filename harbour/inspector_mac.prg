// inspector_mac.prg - Harbour wrapper functions for the inspector
// The C implementation (INS_Create, etc.) comes from cocoa_inspector.m
// This file contains ONLY the Harbour-level functions.

function InspectorOpen()
   if _InsGetData() == 0
      _InsSetData( INS_Create() )
   endif
return nil

function InspectorRefresh( hCtrl )
   local h := _InsGetData()
   local aProps, aEvents
   if h != 0
      if hCtrl != nil .and. hCtrl != 0
         aProps  := UI_GetAllProps( hCtrl )
         aEvents := UI_GetAllEvents( hCtrl )
         INS_RefreshWithData( h, hCtrl, aProps )
         INS_SetEvents( h, aEvents )
      else
         INS_RefreshWithData( h, 0, {} )
         INS_SetEvents( h, {} )
      endif
   endif
return nil

// Populate combo with all controls from the design form
function InspectorPopulateCombo( hForm )
   local h := _InsGetData()
   local i, nCount, hChild, cName, cClass, cEntry

   if h == 0 .or. hForm == 0
      return nil
   endif

   INS_ComboClear( h )
   INS_SetFormCtrl( h, hForm )

   // Add the form itself
   cName  := UI_GetProp( hForm, "cName" )
   cClass := UI_GetProp( hForm, "cClassName" )
   if Empty( cName ); cName := "Form1"; endif
   cEntry := cName + " AS " + cClass
   INS_ComboAdd( h, cEntry )

   // Add all child controls
   nCount := UI_GetChildCount( hForm )
   for i := 1 to nCount
      hChild := UI_GetChild( hForm, i )
      if hChild != 0
         cName  := UI_GetProp( hChild, "cName" )
         cClass := UI_GetProp( hChild, "cClassName" )
         if Empty( cName ); cName := "ctrl" + LTrim( Str( i ) ); endif
         cEntry := cName + " AS " + cClass
         INS_ComboAdd( h, cEntry )
      endif
   next

   // Select form (first entry)
   INS_ComboSelect( h, 0 )

return nil

function InspectorClose()
   local h := _InsGetData()
   if h != 0
      INS_Destroy( h )
      _InsSetData( 0 )
   endif
return nil

function Inspector( hCtrl )
   InspectorOpen()
   InspectorRefresh( hCtrl )
return nil
