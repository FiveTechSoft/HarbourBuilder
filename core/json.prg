// json.prg - JSON serialization/deserialization for forms
// Saves only modified properties (compact output).

#include "hbclass.ch"
#include "hbide.ch"

//----------------------------------------------------------------------------//
// FormToJSON( oForm ) --> cJSON string
//----------------------------------------------------------------------------//

function FormToJSON( oForm )

   local hData := oForm:ToJSON()

return hb_jsonEncode( hData, .t. )  // .t. = pretty print

//----------------------------------------------------------------------------//
// FormFromJSON( cJSON ) --> UIForm object
//----------------------------------------------------------------------------//

function FormFromJSON( cJSON )

   local hData := {=>}, oForm

   hb_jsonDecode( cJSON, @hData )

   if Empty( hData )
      return nil
   endif

   oForm := UIForm():New()
   oForm:Init( nil )
   oForm:FromJSON( hData )

return oForm

//----------------------------------------------------------------------------//
// SaveForm( oForm, cFile ) --> .t./.f.
//----------------------------------------------------------------------------//

function SaveForm( oForm, cFile )

return MemoWrit( cFile, FormToJSON( oForm ) )

//----------------------------------------------------------------------------//
// LoadForm( cFile ) --> UIForm object
//----------------------------------------------------------------------------//

function LoadForm( cFile )

   local cJSON := MemoRead( cFile )

   if Empty( cJSON )
      return nil
   endif

return FormFromJSON( cJSON )
