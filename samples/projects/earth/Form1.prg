// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel
   DATA oEarth1   // TEarthView
   DATA oButton1   // TButton
   DATA oButton2   // TButton
   DATA oButton3   // TButton
   DATA oButton4   // TButton
   DATA oButton5   // TButton

   // Event handlers

   METHOD CreateForm()
   METHOD ToggleRotation()
   METHOD GoMadrid()
   METHOD GoTokyo()
   METHOD GoNewYork()
   METHOD GoSydney()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Earth View — Apple MapKit Globe"
   ::nLeft   := 953
   ::nTop    := 183
   ::nWidth  := 600
   ::nHeight := 620

   @ 16, 16 SAY ::oLabel1 PROMPT "Real Earth from Apple Maps satellite — auto-rotating. Drag to interact." OF Self SIZE 568
   ::oLabel1:oFont := ".AppleSystemUIFont,12"
   @ 48, 16 EARTHVIEW ::oEarth1 OF Self SIZE 568, 460 CENTER 20.000000, 0.000000
   ::oEarth1:oFont := ".AppleSystemUIFont,12"
   @ 528, 16 BUTTON ::oButton1 PROMPT "Pause / Resume" OF Self SIZE 130, 28
   ::oButton1:oFont := ".AppleSystemUIFont,12"
   @ 528, 152 BUTTON ::oButton2 PROMPT "Madrid" OF Self SIZE 95, 28
   ::oButton2:oFont := ".AppleSystemUIFont,12"
   @ 528, 253 BUTTON ::oButton3 PROMPT "Tokyo" OF Self SIZE 95, 28
   ::oButton3:oFont := ".AppleSystemUIFont,12"
   @ 528, 354 BUTTON ::oButton4 PROMPT "New York" OF Self SIZE 95, 28
   ::oButton4:oFont := ".AppleSystemUIFont,12"
   @ 528, 455 BUTTON ::oButton5 PROMPT "Sydney" OF Self SIZE 95, 28
   ::oButton5:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oButton1:OnClick := { || ::ToggleRotation() }
   ::oButton2:OnClick := { || ::GoMadrid() }
   ::oButton3:OnClick := { || ::GoTokyo() }
   ::oButton4:OnClick := { || ::GoNewYork() }
   ::oButton5:OnClick := { || ::GoSydney() }

return nil
//--------------------------------------------------------------------

METHOD ToggleRotation() CLASS TForm1
   ::oEarth1:lAutoRotate := ! ::oEarth1:lAutoRotate
return nil

METHOD GoMadrid() CLASS TForm1
   ::oEarth1:lAutoRotate := .F.
   ::oEarth1:nLat:= 40.4168
   ::oEarth1:nLon:= -3.7038
return nil

METHOD GoTokyo() CLASS TForm1
   ::oEarth1:lAutoRotate := .F.
   ::oEarth1:nLat:= 35.6762
   ::oEarth1:nLon:= 139.6503
return nil

METHOD GoNewYork() CLASS TForm1
   ::oEarth1:lAutoRotate := .F.
   ::oEarth1:nLat:= 40.7128
   ::oEarth1:nLon:= -74.0060
return nil

METHOD GoSydney() CLASS TForm1
   ::oEarth1:lAutoRotate := .F.
   ::oEarth1:nLat:= -33.8688
   ::oEarth1:nLon:= 151.2093
return nil
//--------------------------------------------------------------------
