// control.prg - Abstract base control
// Platform-independent. Backend creates the native widget.

#include "hbclass.ch"
#include "hbide.ch"

//----------------------------------------------------------------------------//
// UIControl - Abstract base class for all controls
//----------------------------------------------------------------------------//

CLASS UIControl

   DATA cClass      AS STRING  INIT ""        // Control type (CTRL_BUTTON, etc.)
   DATA cName       AS STRING  INIT ""        // Unique name within form
   DATA oParent                               // Parent UIControl (form or container)
   DATA aChildren   INIT {}                   // Child controls
   DATA oProps                                // TPropertyBag with all properties
   DATA hEvents     INIT { => }               // Event handlers: { "OnClick" => cMethodName }
   DATA hNative     INIT 0                    // Native handle (hWnd, GtkWidget*, etc.)
   DATA oBackend                              // Backend renderer

   // Core methods
   METHOD Init( oParent )
   METHOD Create()
   METHOD Destroy()
   METHOD AddChild( oChild )

   // Property shortcuts
   METHOD GetProp( cName ) INLINE ::oProps:Get( cName )
   METHOD SetProp( cName, xValue ) INLINE ::oProps:Set( cName, xValue )

   // Convenience accessors
   ACCESS Left    INLINE ::oProps:Get( "Left" )
   ASSIGN Left( n ) INLINE ::oProps:Set( "Left", n )
   ACCESS Top     INLINE ::oProps:Get( "Top" )
   ASSIGN Top( n ) INLINE ::oProps:Set( "Top", n )
   ACCESS Width   INLINE ::oProps:Get( "Width" )
   ASSIGN Width( n ) INLINE ::oProps:Set( "Width", n )
   ACCESS Height  INLINE ::oProps:Get( "Height" )
   ASSIGN Height( n ) INLINE ::oProps:Set( "Height", n )
   ACCESS Text    INLINE ::oProps:Get( "Text" )
   ASSIGN Text( c ) INLINE ::oProps:Set( "Text", c )
   ACCESS Enabled INLINE ::oProps:Get( "Enabled" )
   ASSIGN Enabled( l ) INLINE ::oProps:Set( "Enabled", l )
   ACCESS Visible INLINE ::oProps:Get( "Visible" )
   ASSIGN Visible( l ) INLINE ::oProps:Set( "Visible", l )

   // Serialization
   METHOD ToJSON()
   METHOD FromJSON( hData )

   // Event handling
   METHOD On( cEvent, xHandler )
   METHOD Fire( cEvent, ... )

   // Tree
   METHOD FindByName( cName )

ENDCLASS

METHOD Init( oParent ) CLASS UIControl

   ::oParent := oParent
   ::oProps  := TPropertyBag():New()

   // Register common properties all controls share
   ::oProps:Add( "Name",     "",   PROPTYPE_STRING, PROP_APPEARANCE )
   ::oProps:Add( "Left",      0,   PROPTYPE_NUMBER, PROP_POSITION )
   ::oProps:Add( "Top",       0,   PROPTYPE_NUMBER, PROP_POSITION )
   ::oProps:Add( "Width",    80,   PROPTYPE_NUMBER, PROP_POSITION )
   ::oProps:Add( "Height",   24,   PROPTYPE_NUMBER, PROP_POSITION )
   ::oProps:Add( "Text",     "",   PROPTYPE_STRING, PROP_APPEARANCE )
   ::oProps:Add( "Enabled",  .t.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "Visible",  .t.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "TabStop",  .t.,  PROPTYPE_LOGICAL, PROP_BEHAVIOR )
   ::oProps:Add( "Anchor", 0, PROPTYPE_NUMBER, PROP_POSITION )

   if oParent != nil
      oParent:AddChild( Self )
   endif

return Self

METHOD Create() CLASS UIControl

   // Backend creates the native widget
   if ::oBackend != nil
      ::hNative := ::oBackend:CreateControl( Self )
   endif

return Self

METHOD Destroy() CLASS UIControl

   local n

   // Destroy children first
   for n := 1 to Len( ::aChildren )
      ::aChildren[ n ]:Destroy()
   next
   ::aChildren := {}

   // Backend destroys native widget
   if ::oBackend != nil
      ::oBackend:DestroyControl( Self )
   endif

   ::hNative := 0

return nil

METHOD AddChild( oChild ) CLASS UIControl

   AAdd( ::aChildren, oChild )
   oChild:oBackend := ::oBackend

return nil

METHOD On( cEvent, xHandler ) CLASS UIControl

   ::hEvents[ cEvent ] := xHandler

return nil

METHOD Fire( cEvent, ... ) CLASS UIControl

   local xHandler

   if hb_HHasKey( ::hEvents, cEvent )
      xHandler := ::hEvents[ cEvent ]
      if ValType( xHandler ) == "B"
         return Eval( xHandler, Self, ... )
      endif
   endif

return nil

METHOD FindByName( cName ) CLASS UIControl

   local n, oFound

   if ::cName == cName
      return Self
   endif

   for n := 1 to Len( ::aChildren )
      oFound := ::aChildren[ n ]:FindByName( cName )
      if oFound != nil
         return oFound
      endif
   next

return nil

METHOD ToJSON() CLASS UIControl

   local hResult := { => }
   local hProps, n

   hResult[ "class" ] := ::cClass
   hResult[ "name" ]  := ::cName

   // Only save modified properties
   hProps := ::oProps:ToHash()
   if Len( hProps ) > 0
      hResult[ "properties" ] := hProps
   endif

   // Events
   if Len( ::hEvents ) > 0
      hResult[ "events" ] := hb_HClone( ::hEvents )
   endif

   // Children
   if Len( ::aChildren ) > 0
      hResult[ "children" ] := {}
      for n := 1 to Len( ::aChildren )
         AAdd( hResult[ "children" ], ::aChildren[ n ]:ToJSON() )
      next
   endif

return hResult

METHOD FromJSON( hData ) CLASS UIControl

   local n, hChild, oChild

   if hb_HHasKey( hData, "name" )
      ::cName := hData[ "name" ]
      ::oProps:Set( "Name", ::cName )
   endif

   if hb_HHasKey( hData, "properties" )
      ::oProps:FromHash( hData[ "properties" ] )
   endif

   if hb_HHasKey( hData, "events" )
      ::hEvents := hb_HClone( hData[ "events" ] )
   endif

   if hb_HHasKey( hData, "children" )
      for n := 1 to Len( hData[ "children" ] )
         hChild := hData[ "children" ][ n ]
         oChild := CreateControlByClass( hChild[ "class" ] )
         if oChild != nil
            oChild:Init( Self )
            oChild:FromJSON( hChild )
         endif
      next
   endif

return Self
