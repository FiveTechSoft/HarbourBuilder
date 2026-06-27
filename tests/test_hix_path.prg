/* HIX_ResolvePath — directory traversal and root containment */

#include "../include/hbide.ch"
#include "test_helpers.ch"

REQUEST HIX_ResolvePath
REQUEST TestFail
REQUEST TestPass

FUNCTION Main()
   LOCAL cRoot := "/var/www/app"
   LOCAL cPath

   TEST_ASSERT_EQ( HIX_ResolvePath( cRoot, "" ), "", "empty relative path" )
   TEST_ASSERT_EQ( HIX_ResolvePath( cRoot, NIL ), "", "NIL relative path" )
   TEST_ASSERT_EQ( HIX_ResolvePath( cRoot, "../etc/passwd" ), "", "parent traversal blocked" )
   TEST_ASSERT_EQ( HIX_ResolvePath( cRoot, "foo/../../secret" ), "", "embedded traversal blocked" )

   cPath := HIX_ResolvePath( cRoot, "pages/index.html" )
   TEST_ASSERT_EQ( cPath, "/var/www/app/pages/index.html", "relative file under root" )

   cPath := HIX_ResolvePath( cRoot, "/pages/index.html" )
   TEST_ASSERT_EQ( cPath, "/var/www/app/pages/index.html", "leading slash relative to root" )

   TEST_ASSERT_EQ( HIX_ResolvePath( cRoot, "/outside/file.txt" ), "", "absolute outside root blocked" )

   cPath := HIX_ResolvePath( "C:/projects/demo", "views/home.html" )
   TEST_ASSERT( Lower( cPath ) == "c:/projects/demo/views/home.html", "windows-style root" )

   cPath := HIX_ResolvePath( cRoot, "C:/windows/system.ini" )
   TEST_ASSERT( ! Empty( cPath ), "drive-absolute path accepted as literal" )

RETURN TestPass( "hix path security" )