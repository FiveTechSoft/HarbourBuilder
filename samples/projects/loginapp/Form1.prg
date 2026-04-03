// Form1.prg - Login form
//
// Shows a login dialog first, then opens the main application form
// Demonstrates: modal forms, input validation, form communication
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oLoginForm, oMainForm
static oUser, oPass
static cLoggedUser := ""

function LoginMain()

   local oBtnLogin, oBtnCancel, oLbl

   // === Login Form (shown first) ===
   DEFINE FORM oLoginForm TITLE "Login - HbBuilder App" ;
      SIZE 350, 220 FONT "Segoe UI", 10

   @ 20, 20 SAY "Welcome! Please log in:" OF oLoginForm SIZE 300

   @ 60, 20 SAY "Username:" OF oLoginForm SIZE 80
   @ 58, 110 GET oUser VAR "admin" OF oLoginForm SIZE 200, 24

   @ 95, 20 SAY "Password:" OF oLoginForm SIZE 80
   @ 93, 110 GET oPass VAR "" OF oLoginForm SIZE 200, 24

   @ 140, 110 BUTTON oBtnLogin PROMPT "&Login" OF oLoginForm SIZE 88, 28
   oBtnLogin:OnClick := { || DoLogin() }

   @ 140, 210 BUTTON oBtnCancel PROMPT "&Cancel" OF oLoginForm SIZE 88, 28
   oBtnCancel:OnClick := { || oLoginForm:Close() }

   ACTIVATE FORM oLoginForm CENTERED

   // After login form closes, check if login was successful
   if ! Empty( cLoggedUser )
      ShowMainForm()
   endif

return nil

static function DoLogin()

   local cUser, cPass

   cUser := oUser:Text
   cPass := oPass:Text

   // Simple validation (in production: check against database)
   if Empty( cUser )
      MsgInfo( "Please enter a username" )
      return nil
   endif

   if cUser == "admin" .and. cPass == "1234"
      cLoggedUser := cUser
      oLoginForm:Close()
   elseif cUser == "demo" .and. cPass == "demo"
      cLoggedUser := cUser
      oLoginForm:Close()
   else
      MsgInfo( "Invalid username or password" + Chr(10) + ;
               Chr(10) + ;
               "Try: admin/1234 or demo/demo" )
   endif

return nil

static function ShowMainForm()

   local oLbl, oBtnLogout

   DEFINE FORM oMainForm TITLE "Main Application - " + cLoggedUser ;
      SIZE 600, 400 FONT "Segoe UI", 10

   @ 20, 20 SAY "Welcome, " + cLoggedUser + "!" OF oMainForm SIZE 400
   @ 50, 20 SAY "You are now logged into the application." OF oMainForm SIZE 400
   @ 80, 20 SAY "This demonstrates multi-form projects in HarbourBuilder." OF oMainForm SIZE 500

   @ 130, 20 GROUPBOX "User Info" OF oMainForm SIZE 540, 80
   @ 155, 40 SAY "Username: " + cLoggedUser OF oMainForm SIZE 200
   @ 175, 40 SAY "Role: " + If( cLoggedUser == "admin", "Administrator", "User" ) OF oMainForm SIZE 200
   @ 155, 300 SAY "Login time: " + Time() OF oMainForm SIZE 200

   @ 240, 20 BUTTON oBtnLogout PROMPT "&Logout" OF oMainForm SIZE 100, 28
   oBtnLogout:OnClick := { || oMainForm:Close(), MsgInfo( "Logged out successfully" ) }

   ACTIVATE FORM oMainForm CENTERED

return nil
