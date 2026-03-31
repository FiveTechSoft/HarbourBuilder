// test_cpp.prg - Preferences using C++ core with events
// C++ handles all window management. Harbour handles logic via events.

REQUEST HB_GT_GUI_DEFAULT

function Main()

   local hForm, hCtrl, hLblStatus, hCboIdioma

   // Create form
   hForm := UI_FormNew( "Preferencias", 471, 405, "Segoe UI", 12 )

   // GroupBoxes
   UI_GroupBoxNew( hForm, "General", 12, 13, 431, 122 )
   UI_GroupBoxNew( hForm, "Apariencia", 12, 146, 431, 150 )

   // Labels
   UI_LabelNew( hForm, "Idioma:", 26, 43, 79, 15 )
   UI_LabelNew( hForm, "Ruta:", 26, 77, 79, 15 )
   UI_LabelNew( hForm, "Fuente:", 26, 176, 79, 15 )

   // Status label at bottom
   hLblStatus := UI_LabelNew( hForm, "", 12, 360, 440, 15 )

   // ComboBox: Idioma - with OnChange event
   hCboIdioma := UI_ComboBoxNew( hForm, 112, 39, 175, 200 )
   UI_ComboAddItem( hCboIdioma, "Espanol" )
   UI_ComboAddItem( hCboIdioma, "English" )
   UI_ComboAddItem( hCboIdioma, "Portugues" )
   UI_ComboAddItem( hCboIdioma, "Deutsch" )
   UI_ComboSetIndex( hCboIdioma, 0 )

   // When language changes, update status label
   UI_OnEvent( hCboIdioma, "OnChange", ;
      { |hSender| UI_SetProp( hLblStatus, "cText", "Idioma cambiado!" ) } )

   // ComboBox: Fuente
   hCtrl := UI_ComboBoxNew( hForm, 112, 173, 210, 200 )
   UI_ComboAddItem( hCtrl, "Segoe UI" )
   UI_ComboAddItem( hCtrl, "Tahoma" )
   UI_ComboAddItem( hCtrl, "Arial" )
   UI_ComboAddItem( hCtrl, "Consolas" )
   UI_ComboSetIndex( hCtrl, 0 )

   // Edit
   UI_EditNew( hForm, "C:\Projects", 112, 73, 312, 24 )

   // CheckBoxes
   hCtrl := UI_CheckBoxNew( hForm, "Mostrar barra de herramientas", 112, 210, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   hCtrl := UI_CheckBoxNew( hForm, "Mostrar barra de estado", 112, 234, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   hCtrl := UI_CheckBoxNew( hForm, "Confirmar al salir", 112, 259, 245, 19 )
   UI_SetProp( hCtrl, "lChecked", .t. )

   // Buttons with OnClick events
   hCtrl := UI_ButtonNew( hForm, "&Aceptar", 170, 326, 88, 26 )
   UI_SetProp( hCtrl, "lDefault", .t. )
   UI_OnEvent( hCtrl, "OnClick", { |hSender| UI_SetProp( hLblStatus, "cText", "Aceptar pulsado!" ) } )

   hCtrl := UI_ButtonNew( hForm, "&Cancelar", 266, 326, 88, 26 )
   UI_SetProp( hCtrl, "lCancel", .t. )

   // Run
   UI_FormRun( hForm )

   // Show result
   if UI_FormResult( hForm ) == 1
      // User clicked Aceptar
   endif

   // Cleanup
   UI_FormDestroy( hForm )

return nil
