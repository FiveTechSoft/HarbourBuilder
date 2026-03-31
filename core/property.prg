// property.prg - Property metadata system (pure Harbour, no dependencies)

#include "hbclass.ch"
#include "hbide.ch"

CLASS TProperty

   DATA cName     INIT ""
   DATA xValue
   DATA xDefault
   DATA nType     INIT PROPTYPE_STRING
   DATA cCategory INIT PROP_APPEARANCE
   DATA lReadOnly INIT .F.
   DATA aEnum     INIT {}
   DATA bOnSet

   METHOD New( cName, xDefault, nType, cCategory, bOnSet, aEnum )
   METHOD Get() INLINE ::xValue
   METHOD Set( xNewValue )
   METHOD IsModified() INLINE !( ::xValue == ::xDefault )
   METHOD Reset() INLINE ::xValue := ::xDefault

ENDCLASS

METHOD New( cName, xDefault, nType, cCategory, bOnSet, aEnum ) CLASS TProperty

   if nType == nil; nType := PROPTYPE_STRING; endif
   if cCategory == nil; cCategory := PROP_APPEARANCE; endif

   ::cName    := cName
   ::xValue   := xDefault
   ::xDefault := xDefault
   ::nType    := nType
   ::cCategory := cCategory
   ::bOnSet   := bOnSet
   ::aEnum    := aEnum

return Self

METHOD Set( xNewValue ) CLASS TProperty

   if ::lReadOnly; return ::xValue; endif
   ::xValue := xNewValue
   if ::bOnSet != nil; Eval( ::bOnSet, xNewValue ); endif

return ::xValue

//----------------------------------------------------------------------------//

CLASS TPropertyBag

   DATA aProps  INIT {}
   DATA hIndex  INIT { => }

   METHOD Add( cName, xDefault, nType, cCategory, bOnSet, aEnum )
   METHOD Get( cName )
   METHOD Set( cName, xValue )
   METHOD GetProp( cName )
   METHOD GetModified()
   METHOD GetByCategory()
   METHOD ToHash()
   METHOD FromHash( hData )

ENDCLASS

METHOD Add( cName, xDefault, nType, cCategory, bOnSet, aEnum ) CLASS TPropertyBag

   local oProp := TProperty():New( cName, xDefault, nType, cCategory, bOnSet, aEnum )
   AAdd( ::aProps, oProp )
   ::hIndex[ cName ] := Len( ::aProps )

return oProp

METHOD Get( cName ) CLASS TPropertyBag

   if hb_HHasKey( ::hIndex, cName )
      return ::aProps[ ::hIndex[ cName ] ]:Get()
   endif

return nil

METHOD Set( cName, xValue ) CLASS TPropertyBag

   if hb_HHasKey( ::hIndex, cName )
      return ::aProps[ ::hIndex[ cName ] ]:Set( xValue )
   endif

return nil

METHOD GetProp( cName ) CLASS TPropertyBag

   if hb_HHasKey( ::hIndex, cName )
      return ::aProps[ ::hIndex[ cName ] ]
   endif

return nil

METHOD GetModified() CLASS TPropertyBag

   local aResult := {}, n
   for n := 1 to Len( ::aProps )
      if ::aProps[ n ]:IsModified()
         AAdd( aResult, ::aProps[ n ] )
      endif
   next

return aResult

METHOD GetByCategory() CLASS TPropertyBag

   local hCats := { => }, n, cCat
   for n := 1 to Len( ::aProps )
      cCat := ::aProps[ n ]:cCategory
      if ! hb_HHasKey( hCats, cCat ); hCats[ cCat ] := {}; endif
      AAdd( hCats[ cCat ], ::aProps[ n ] )
   next

return hCats

METHOD ToHash() CLASS TPropertyBag

   local hResult := { => }, n
   for n := 1 to Len( ::aProps )
      if ::aProps[ n ]:IsModified()
         hResult[ ::aProps[ n ]:cName ] := ::aProps[ n ]:Get()
      endif
   next

return hResult

METHOD FromHash( hData ) CLASS TPropertyBag

   local cKey
   for each cKey in hb_HKeys( hData )
      ::Set( cKey, hData[ cKey ] )
   next

return nil
