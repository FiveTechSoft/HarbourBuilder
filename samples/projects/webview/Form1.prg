// Form1.prg — WebView Demo
//--------------------------------------------------------------------

CLASS TForm1 FROM TForm

   // IDE-managed Components
   DATA oEdtUrl      // TEdit   — URL bar
   DATA oBtnGo       // TButton — Go / Load URL
   DATA oBtnBack     // TButton — Back
   DATA oBtnFwd      // TButton — Forward
   DATA oBtnReload   // TButton — Reload
   DATA oWebView1    // TWebView
   DATA oLblStatus   // TLabel  — status bar

   METHOD CreateForm()

   // Event handlers
   METHOD BtnGoClick()
   METHOD BtnBackClick()
   METHOD BtnFwdClick()
   METHOD BtnReloadClick()
   METHOD WebNavigate( cUrl )
   METHOD WebLoad()
   METHOD WebError()

ENDCLASS
//--------------------------------------------------------------------

METHOD CreateForm() CLASS TForm1

   ::cTitle  := "WebView Demo"
   ::nLeft   := 200
   ::nTop    := 100
   ::nWidth  := 900
   ::nHeight := 620

   // Toolbar row
   @ 8, 8    BUTTON  ::oBtnBack   PROMPT "< Back"   OF Self SIZE 70, 28
   @ 8, 84   BUTTON  ::oBtnFwd    PROMPT "Fwd >"    OF Self SIZE 70, 28
   @ 8, 160  BUTTON  ::oBtnReload PROMPT "Reload"   OF Self SIZE 70, 28
   @ 8, 240  GET     ::oEdtUrl    VAR "https://harbour.github.io" OF Self SIZE 560, 28
   @ 8, 806  BUTTON  ::oBtnGo     PROMPT "Go"       OF Self SIZE 60, 28

   // WebView — fills the remaining area
   @ 44, 0   WEBVIEW ::oWebView1  OF Self SIZE 900, 550 URL "https://harbour.github.io"
   ::oWebView1:nControlAlign := 5   // alClient

   // Status label
   @ 0, 0    SAY     ::oLblStatus PROMPT "Ready" OF Self SIZE 900

   // Wire events
   ::oBtnGo:OnClick     := {|| ::BtnGoClick()     }
   ::oBtnBack:OnClick   := {|| ::BtnBackClick()   }
   ::oBtnFwd:OnClick    := {|| ::BtnFwdClick()    }
   ::oBtnReload:OnClick := {|| ::BtnReloadClick() }

   ::oWebView1:OnNavigate := {|cUrl| ::WebNavigate( cUrl ) }
   ::oWebView1:OnLoad     := {|| ::WebLoad()  }
   ::oWebView1:OnError    := {|| ::WebError() }

return nil
//--------------------------------------------------------------------

METHOD BtnGoClick() CLASS TForm1

   local cUrl := AllTrim( ::oEdtUrl:cText )
   if Empty( cUrl ); return nil; endif
   if ! ( "://" $ cUrl )
      cUrl := "https://" + cUrl
   endif
   ::oWebView1:Navigate( cUrl )

return nil

METHOD BtnBackClick() CLASS TForm1
   ::oWebView1:GoBack()
return nil

METHOD BtnFwdClick() CLASS TForm1
   ::oWebView1:GoForward()
return nil

METHOD BtnReloadClick() CLASS TForm1
   ::oWebView1:Reload()
return nil

METHOD WebNavigate( cUrl ) CLASS TForm1
   ::oEdtUrl:cText   := cUrl
   ::oLblStatus:cText := "Loading: " + cUrl
return nil

METHOD WebLoad() CLASS TForm1
   ::oLblStatus:cText := "Done — " + ::oWebView1:GetUrl()
return nil

METHOD WebError() CLASS TForm1
   ::oLblStatus:cText := "Error loading page"
return nil
//--------------------------------------------------------------------
