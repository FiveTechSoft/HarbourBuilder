// Form1.prg
//--------------------------------------------------------------------

#include "hbbuilder.ch"

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oMap1       // TMap
   DATA oLabel1     // TLabel
   DATA oButton1    // TButton — Madrid
   DATA oButton2    // TButton — Barcelona
   DATA oButton3    // TButton — New York
   DATA oButton4    // TButton — Tokyo
   DATA oButton5    // TButton — Toggle map type
   DATA oButton6    // TButton — Clear pins
   DATA oButton7    // TButton — Add capital pins

   // Event handlers
   METHOD GoMadrid()
   METHOD GoBarcelona()
   METHOD GoNewYork()
   METHOD GoTokyo()
   METHOD ToggleType()
   METHOD ClearPins()
   METHOD AddCapitals()

   METHOD CreateForm()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Maps Demo (MapKit)"
   ::nLeft   := 250
   ::nTop    := 100
   ::nWidth  := 720
   ::nHeight := 560

   @ 16, 16 SAY ::oLabel1 PROMPT "Drag to pan, scroll to zoom. Click a button to jump." ;
      OF Self SIZE 680

   @ 48, 16 MAP ::oMap1 OF Self SIZE 688, 380 CENTER 40.4168, -3.7038 ZOOM 6

   @ 444, 16 BUTTON ::oButton1 PROMPT "Madrid"     OF Self SIZE 95, 28
   @ 444, 117 BUTTON ::oButton2 PROMPT "Barcelona" OF Self SIZE 95, 28
   @ 444, 218 BUTTON ::oButton3 PROMPT "New York"  OF Self SIZE 95, 28
   @ 444, 319 BUTTON ::oButton4 PROMPT "Tokyo"     OF Self SIZE 95, 28

   @ 484, 16 BUTTON ::oButton5 PROMPT "Toggle Type" OF Self SIZE 130, 28
   @ 484, 152 BUTTON ::oButton7 PROMPT "Add Capitals" OF Self SIZE 130, 28
   @ 484, 288 BUTTON ::oButton6 PROMPT "Clear Pins"   OF Self SIZE 130, 28

   // Event wiring
   ::oButton1:OnClick := { || ::GoMadrid() }
   ::oButton2:OnClick := { || ::GoBarcelona() }
   ::oButton3:OnClick := { || ::GoNewYork() }
   ::oButton4:OnClick := { || ::GoTokyo() }
   ::oButton5:OnClick := { || ::ToggleType() }
   ::oButton7:OnClick := { || ::AddCapitals() }
   ::oButton6:OnClick := { || ::ClearPins() }

return nil
//--------------------------------------------------------------------

METHOD GoMadrid() CLASS TForm1
   ::oMap1:SetRegion( 40.4168, -3.7038, 12 )
return nil

METHOD GoBarcelona() CLASS TForm1
   ::oMap1:SetRegion( 41.3851,  2.1734, 12 )
return nil

METHOD GoNewYork() CLASS TForm1
   ::oMap1:SetRegion( 40.7128, -74.0060, 11 )
return nil

METHOD GoTokyo() CLASS TForm1
   ::oMap1:SetRegion( 35.6762, 139.6503, 11 )
return nil

METHOD ToggleType() CLASS TForm1
   local n := ::oMap1:nMapType
   ::oMap1:nMapType := IIf( n >= 3, 0, n + 1 )    // mtStandard..mtMutedStandard cycle
return nil

METHOD ClearPins() CLASS TForm1
   ::oMap1:ClearPins()
return nil

METHOD AddCapitals() CLASS TForm1
   ::oMap1:ClearPins()
   ::oMap1:AddPin( 40.4168,  -3.7038, "Madrid",     "Spain" )
   ::oMap1:AddPin( 41.3851,   2.1734, "Barcelona",  "Spain (Catalonia)" )
   ::oMap1:AddPin( 48.8566,   2.3522, "Paris",      "France" )
   ::oMap1:AddPin( 51.5074,  -0.1278, "London",     "United Kingdom" )
   ::oMap1:AddPin( 52.5200,  13.4050, "Berlin",     "Germany" )
   ::oMap1:AddPin( 41.9028,  12.4964, "Rome",       "Italy" )
   ::oMap1:AddPin( 40.7128, -74.0060, "New York",   "USA" )
   ::oMap1:AddPin( 35.6762, 139.6503, "Tokyo",      "Japan" )
   ::oMap1:SetRegion( 30.0, 0.0, 3 )    // wide world view
return nil
//--------------------------------------------------------------------
