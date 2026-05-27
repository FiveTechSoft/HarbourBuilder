// Form1.prg
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oLabel1   // TLabel
   DATA oScene3D1   // TScene3D
   DATA oLabel2   // TLabel
   DATA oButton1   // TButton
   DATA oButton2   // TButton
   DATA oButton3   // TButton

   // Event handlers

   METHOD CreateForm()
   METHOD Button1Click()
   METHOD Button2Click()
   METHOD Button3Click()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "Scene3D Demo"
   ::nLeft   := 963
   ::nTop    := 191
   ::nWidth  := 640
   ::nHeight := 520

   @ 16, 16 SAY ::oLabel1 PROMPT "3D viewer — drag to orbit, scroll to zoom, two-finger drag to pan" OF Self SIZE 600
   ::oLabel1:oFont := ".AppleSystemUIFont,12"
   @ 48, 16 SCENE3D ::oScene3D1 OF Self SIZE 608, 360
   ::oScene3D1:oFont := ".AppleSystemUIFont,12"
   @ 420, 16 SAY ::oLabel2 PROMPT "No model loaded (default dodecahedron)" OF Self SIZE 608
   ::oLabel2:oFont := ".AppleSystemUIFont,12"
   @ 456, 16 BUTTON ::oButton1 PROMPT "Load Model..." OF Self SIZE 140, 30
   ::oButton1:oFont := ".AppleSystemUIFont,12"
   @ 456, 170 BUTTON ::oButton2 PROMPT "Clear" OF Self SIZE 100, 30
   ::oButton2:oFont := ".AppleSystemUIFont,12"
   @ 456, 284 BUTTON ::oButton3 PROMPT "About" OF Self SIZE 100, 30
   ::oButton3:oFont := ".AppleSystemUIFont,12"

   // Event wiring
   ::oButton1:OnClick := { || ::Button1Click() }
   ::oButton2:OnClick := { || ::Button2Click() }
   ::oButton3:OnClick := { || ::Button3Click() }

return nil
//--------------------------------------------------------------------

METHOD Button1Click() CLASS TForm1

   local cPath := MAC_OpenFileDialog( "Select 3D model (.usdz / .dae / .scn / .obj)", "usdz" )

   if ! Empty( cPath )
      ::oScene3D1:cSceneFile := cPath
      ::oLabel2:cText := "Loaded: " + cPath
   endif

return nil
//--------------------------------------------------------------------

METHOD Button2Click() CLASS TForm1

   ::oScene3D1:cSceneFile := ""
   ::oLabel2:cText := "No model loaded (default dodecahedron)"

return nil
//--------------------------------------------------------------------

METHOD Button3Click() CLASS TForm1

   MAC_MsgBox( "TScene3D demo" + Chr(10) + ;
      "Backend: SceneKit (macOS native, free)" + Chr(10) + ;
      "Supports .usdz, .usd, .dae, .scn, .obj" + Chr(10) + Chr(10) + ;
      "Sample models:" + Chr(10) + ;
      "developer.apple.com/augmented-reality/quick-look/", ;
      "About" )

return nil
//--------------------------------------------------------------------
