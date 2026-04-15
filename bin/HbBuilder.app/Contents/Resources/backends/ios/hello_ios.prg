/* hello_ios.prg - Simple iOS demo using UI_* API */

PROCEDURE Main()

   LOCAL hForm, hLabel, hButton, hEdit

   hForm := UI_FormNew( "Harbour iOS", 375, 667 )

   UI_SetFormColor( 0xFFFFFF )    /* white background */

   hLabel := UI_LabelNew( hForm, "Hello from Harbour!", 40, 80, 295, 40 )
   UI_SetCtrlColor( hLabel, 0xFF0000 )    /* red background (BGR) */
   UI_SetCtrlFont( hLabel, "Helvetica", 24 )

   hEdit := UI_EditNew( hForm, "Type here...", 40, 160, 295, 40 )

   hButton := UI_ButtonNew( hForm, "Click Me", 40, 240, 295, 50 )
   UI_SetCtrlColor( hButton, 0xCC9966 )   /* olive-ish (BGR) */

   UI_OnClick( hButton, {|| OnButtonClick( hEdit, hLabel ) } )

   UI_FormRun( hForm )

RETURN

PROCEDURE OnButtonClick( hEdit, hLabel )

   LOCAL cText := UI_GetText( hEdit )

   IF Empty( cText )
      cText := "(empty)"
   ENDIF

   UI_SetText( hLabel, "You typed: " + cText )

RETURN
