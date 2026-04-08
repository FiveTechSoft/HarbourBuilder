// web/backend.prg - HTML/CSS/JS backend
// Generates a self-contained HTML file from abstract UIControls.
// Pure Harbour string generation - no web server needed.

#include "hbclass.ch"
#include "hbide.ch"

CLASS WebBackend

   DATA oForm
   DATA cHTML INIT ""

   METHOD New()
   METHOD Run( oForm )
   METHOD Generate( oForm )
   METHOD GenControl( oCtrl, cIndent )
   METHOD GenCSS()
   METHOD GenJS()
   METHOD SaveAndOpen( cFile )

ENDCLASS

METHOD New() CLASS WebBackend
return Self

METHOD Run( oForm ) CLASS WebBackend

   ::oForm := oForm
   oForm:oBackend := Self

   ::Generate( oForm )
   ::SaveAndOpen( "form.html" )

return nil

METHOD Generate( oForm ) CLASS WebBackend

   local n, cBody := ""

   // Generate child controls
   for n := 1 to Len( oForm:aChildren )
      cBody += ::GenControl( oForm:aChildren[ n ], "      " )
   next

   ::cHTML := '<!DOCTYPE html>' + CRLF + ;
      '<html lang="es">' + CRLF + ;
      '<head>' + CRLF + ;
      '  <meta charset="UTF-8">' + CRLF + ;
      '  <title>' + oForm:Text + '</title>' + CRLF + ;
      '  <style>' + CRLF + ::GenCSS() + '  </style>' + CRLF + ;
      '</head>' + CRLF + ;
      '<body>' + CRLF + ;
      '  <div class="form" style="width:' + NToPixel( oForm:Width - 16 ) + ;
         ';height:' + NToPixel( oForm:Height - 40 ) + ';">' + CRLF + ;
      '    <div class="form-title">' + oForm:Text + '</div>' + CRLF + ;
      '    <div class="form-body">' + CRLF + ;
      cBody + ;
      '    </div>' + CRLF + ;
      '  </div>' + CRLF + ;
      '  <script>' + CRLF + ::GenJS() + '  </script>' + CRLF + ;
      '</body>' + CRLF + ;
      '</html>' + CRLF

return ::cHTML

METHOD GenControl( oCtrl, cIndent ) CLASS WebBackend

   local cClass := oCtrl:cClass
   local cHTML := ""
   local cStyle, cName, n, aItems, nIdx

   cName  := oCtrl:cName
   cStyle := 'left:' + NToPixel( oCtrl:Left ) + ;
             ';top:' + NToPixel( oCtrl:Top ) + ;
             ';width:' + NToPixel( oCtrl:Width ) + ;
             ';height:' + NToPixel( oCtrl:Height )

   do case
      case cClass == CTRL_GROUPBOX
         cHTML += cIndent + '<fieldset id="' + cName + '" style="position:absolute;' + cStyle + ';margin:0;padding:8px;">' + CRLF
         cHTML += cIndent + '  <legend>' + oCtrl:Text + '</legend>' + CRLF
         cHTML += cIndent + '</fieldset>' + CRLF

      case cClass == CTRL_LABEL
         cHTML += cIndent + '<label id="' + cName + '" style="position:absolute;' + cStyle + ;
            ';line-height:' + NToPixel( oCtrl:Height ) + '">' + oCtrl:Text + '</label>' + CRLF

      case cClass == CTRL_EDIT
         cHTML += cIndent + '<input type="text" id="' + cName + '" value="' + oCtrl:Text + ;
            '" style="position:absolute;' + cStyle + ';box-sizing:border-box;">' + CRLF

      case cClass == CTRL_BUTTON
         cHTML += cIndent + '<button id="' + cName + '" style="position:absolute;' + cStyle + '">' + ;
            StrTran( oCtrl:Text, "&", "" ) + '</button>' + CRLF

      case cClass == CTRL_CHECKBOX
         cHTML += cIndent + '<label id="' + cName + '" style="position:absolute;' + cStyle + '">' + CRLF
         cHTML += cIndent + '  <input type="checkbox"'
         if oCtrl:GetProp( "Checked" ); cHTML += ' checked'; endif
         cHTML += '> ' + oCtrl:Text + CRLF
         cHTML += cIndent + '</label>' + CRLF

      case cClass == CTRL_COMBOBOX
         aItems := oCtrl:GetProp( "Items" )
         nIdx   := oCtrl:GetProp( "ItemIndex" )
         cHTML += cIndent + '<select id="' + cName + '" style="position:absolute;' + cStyle + ;
            ';height:24px;">' + CRLF
         if aItems != nil
            for n := 1 to Len( aItems )
               cHTML += cIndent + '  <option' + If( n == nIdx, ' selected', '' ) + '>' + ;
                  aItems[ n ] + '</option>' + CRLF
            next
         endif
         cHTML += cIndent + '</select>' + CRLF

      case cClass == CTRL_LISTBOX
         aItems := oCtrl:GetProp( "Items" )
         cHTML += cIndent + '<select id="' + cName + '" size="' + ;
            LTrim( Str( Max( Int( oCtrl:Height / 20 ), 3 ) ) ) + ;
            '" style="position:absolute;' + cStyle + '">' + CRLF
         if aItems != nil
            for n := 1 to Len( aItems )
               cHTML += cIndent + '  <option>' + aItems[ n ] + '</option>' + CRLF
            next
         endif
         cHTML += cIndent + '</select>' + CRLF

      case cClass == CTRL_RADIOBUTTON
         cHTML += cIndent + '<label id="' + cName + '" style="position:absolute;' + cStyle + '">' + CRLF
         cHTML += cIndent + '  <input type="radio" name="radio_' + cName + '"'
         if oCtrl:GetProp( "Checked" ); cHTML += ' checked'; endif
         cHTML += '> ' + oCtrl:Text + CRLF
         cHTML += cIndent + '</label>' + CRLF

      case cClass == CTRL_PROGRESSBAR
         cHTML += cIndent + '<progress id="' + cName + '" value="' + ;
            LTrim( Str( oCtrl:GetProp( "Value" ) ) ) + '" max="' + ;
            LTrim( Str( oCtrl:GetProp( "Max" ) ) ) + ;
            '" style="position:absolute;' + cStyle + '"></progress>' + CRLF

   endcase

return cHTML

METHOD GenCSS() CLASS WebBackend

   local cFontName := ::oForm:GetProp( "FontName" )
   local nFontSize := ::oForm:GetProp( "FontSize" )

return ;
   '    * { margin: 0; padding: 0; box-sizing: border-box; }' + CRLF + ;
   '    body { font-family: "' + cFontName + '", "Segoe UI", sans-serif; font-size: ' + LTrim( Str( nFontSize ) ) + 'pt;' + CRLF + ;
   '      display: flex; justify-content: center; align-items: center; min-height: 100vh; background: #c0c0c0; }' + CRLF + ;
   '    .form { position: relative; background: #f0f0f0; border: 1px solid #666;' + CRLF + ;
   '      border-radius: 4px; box-shadow: 0 4px 16px rgba(0,0,0,0.35); overflow: hidden; }' + CRLF + ;
   '    .form-title { background: linear-gradient(135deg, #1b5ea4, #2978d4); color: white;' + CRLF + ;
   '      padding: 6px 12px; font-size: 11px; font-weight: normal; letter-spacing: 0.3px;' + CRLF + ;
   '      display: flex; align-items: center; gap: 6px; }' + CRLF + ;
   '    .form-title::before { content: "\2699"; font-size: 13px; }' + CRLF + ;
   '    .form-body { position: relative; padding: 0; }' + CRLF + ;
   '    input[type="text"] { padding: 3px 6px; border: 1px solid #aaa; border-radius: 2px;' + CRLF + ;
   '      background: white; outline: none; font-family: inherit; font-size: inherit; }' + CRLF + ;
   '    input[type="text"]:focus { border-color: #0078d4; box-shadow: 0 0 0 1px #0078d4; }' + CRLF + ;
   '    button { cursor: pointer; border: 1px solid #aaa; border-radius: 3px;' + CRLF + ;
   '      background: linear-gradient(to bottom, #f5f5f5, #e0e0e0); padding: 4px 16px;' + CRLF + ;
   '      font-family: inherit; font-size: inherit; min-width: 75px; }' + CRLF + ;
   '    button:hover { background: linear-gradient(to bottom, #e8f0fe, #d0d8e8); border-color: #0078d4; }' + CRLF + ;
   '    button:active { background: linear-gradient(to bottom, #cce0f0, #b0c8e0); }' + CRLF + ;
   '    label { display: flex; align-items: center; font-size: inherit; cursor: default; }' + CRLF + ;
   '    label input[type="checkbox"] { margin-right: 6px; accent-color: #0078d4; }' + CRLF + ;
   '    fieldset { border: 1px solid #bbb; border-radius: 3px; background: transparent; }' + CRLF + ;
   '    fieldset legend { font-size: ' + LTrim( Str( nFontSize ) ) + 'pt; padding: 0 4px; color: #333; }' + CRLF + ;
   '    select { padding: 3px 6px; border: 1px solid #aaa; border-radius: 2px;' + CRLF + ;
   '      background: white; font-family: inherit; font-size: inherit; outline: none; }' + CRLF + ;
   '    select:focus { border-color: #0078d4; box-shadow: 0 0 0 1px #0078d4; }' + CRLF

METHOD GenJS() CLASS WebBackend

return ;
   '    // Draggable form by title bar' + CRLF + ;
   '    (function() {' + CRLF + ;
   '      const form = document.querySelector(".form");' + CRLF + ;
   '      const title = document.querySelector(".form-title");' + CRLF + ;
   '      let isDragging = false, offsetX = 0, offsetY = 0;' + CRLF + ;
   '      form.style.position = "absolute";' + CRLF + ;
   '      form.style.left = (window.innerWidth - form.offsetWidth) / 2 + "px";' + CRLF + ;
   '      form.style.top = (window.innerHeight - form.offsetHeight) / 2 + "px";' + CRLF + ;
   '      title.style.cursor = "move";' + CRLF + ;
   '      title.addEventListener("mousedown", e => {' + CRLF + ;
   '        isDragging = true;' + CRLF + ;
   '        offsetX = e.clientX - form.offsetLeft;' + CRLF + ;
   '        offsetY = e.clientY - form.offsetTop;' + CRLF + ;
   '        e.preventDefault();' + CRLF + ;
   '      });' + CRLF + ;
   '      document.addEventListener("mousemove", e => {' + CRLF + ;
   '        if (!isDragging) return;' + CRLF + ;
   '        form.style.left = (e.clientX - offsetX) + "px";' + CRLF + ;
   '        form.style.top = (e.clientY - offsetY) + "px";' + CRLF + ;
   '      });' + CRLF + ;
   '      document.addEventListener("mouseup", () => isDragging = false);' + CRLF + ;
   '    })();' + CRLF + ;
   '    // Button click handlers' + CRLF + ;
   '    document.querySelectorAll("button").forEach(btn => {' + CRLF + ;
   '      btn.addEventListener("click", () => {' + CRLF + ;
   '        alert("Clicked: " + btn.textContent);' + CRLF + ;
   '      });' + CRLF + ;
   '    });' + CRLF

METHOD SaveAndOpen( cFile ) CLASS WebBackend

   MemoWrit( cFile, ::cHTML )

   // Open in default browser
   #ifdef __PLATFORM__WINDOWS
      hb_run( 'start "" "' + cFile + '"' )
   #else
      hb_run( 'xdg-open "' + cFile + '" 2>/dev/null || open "' + cFile + '"' )
   #endif

return nil

//----------------------------------------------------------------------------//

static function NToPixel( n )
return LTrim( Str( n ) ) + "px"
