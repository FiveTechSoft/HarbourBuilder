// inspector_gtk.prg - Harbour wrapper functions for the GTK3 inspector
// The C implementation (INS_Create, etc.) comes from gtk3_inspector.c
// This file contains ONLY the Harbour-level functions.

function InspectorOpen()
   if _InsGetData() == 0
      _InsSetData( INS_Create() )
   endif
return nil

function InspectorRefresh( hCtrl )
   local h := _InsGetData()
   local aProps
   if h != 0
      if hCtrl != nil .and. hCtrl != 0
         aProps := UI_GetAllProps( hCtrl )
         INS_RefreshWithData( h, hCtrl, aProps )
      else
         INS_RefreshWithData( h, 0, {} )
      endif
      INS_BringToFront( h )
   endif
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
