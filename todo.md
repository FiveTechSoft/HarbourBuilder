# HbBuilder TODO

## Fixed
- [x] Inspector event double-click: cursor was not positioned correctly on new handler code. Cause: CRLF (`Chr(13)+Chr(10)`) was used for line breaks but Scintilla on macOS converts to LF internally, making the byte offset calculation wrong. Fix: use `Chr(10)` in `OnEventDblClick()` in `hbbuilder_macos.prg`.
- [x] Inspector window focus: when clicking the inspector window, only that window came to front while the rest of the IDE stayed behind. Fix: added `NSWindowDelegate` with `windowDidBecomeKey:` to `HBInspectorDelegate` in `cocoa_inspector.m` — brings all visible IDE windows to front when the inspector is activated.
- [x] Run from .app bundle: paths to backends, scintilla, and framework files were wrong when running from the macOS bundle. Fix: detect bundle via `Resources/backends` and resolve paths accordingly in `TBRun()` and `TBDebugRun()` in `hbbuilder_macos.prg`.
- [x] Run link failure: `gtgui.o` was compiled from `~/harbour/src/rtl/gtgui/gtgui.c` which doesn't exist in Harbour install. Fix: removed gtgui compile/link step, added `HB_GT_GUI_DEFAULT` stub to `gt_dummy.c`.
- [x] Event handler cursor positioning: after double-clicking an event in inspector, cursor landed at correct line but column 0. Fix: `CodeEditorGotoFunction()` in `cocoa_editor.mm` now adds 3 to position for the indent. Also added re-positioning call after `SyncDesignerToCode()` in `OnEventDblClick()`.

- [x] Project load does not restore visual controls. Implemented `RestoreFormFromCode()` — parses .prg code to recreate controls (Button, Label, Edit, CheckBox, ComboBox, GroupBox, ListBox, RadioButton) with correct position, size, text and name. Called from `TBOpen()` after `CreateDesignForm()`.

- [x] Non-visual components (Timer, OpenAI, Thread, SQLite, etc.) now serialize as `COMPONENT ::oName TYPE nType OF Self` in `RegenerateFormCode()` and restore via `UI_DropNonVisual()` in `RestoreFormFromCode()`.

- [x] Loading a project shows both the default startup form AND the loaded project forms. Fix: `TBOpen()` now calls `Close()` + `Destroy()` on each existing form before loading (was only calling `Destroy()` which didn't close the window).

- [x] TMemo not appearing at runtime. Cause: no `MEMO` command in `hbbuilder.ch`, no TMemo class in `classes.prg`, no `UI_MemoNew` in cocoa_core.m, and `RegenerateFormCode` sent Memo to the `otherwise` (comment) case. Fix: added all four pieces + parser in `RestoreFormFromCode`.

- [x] RadioButton palette bitmap is incorrect — shows wrong icon in the component palette. Fix: Memo icon at strip position 3 shifted CheckBox/ComboBox/GroupBox/RadioButton icons off by one. Rearranged palette.bmp to match CT_ constants: pos 3=CheckBox, 4=ComboBox, 5=GroupBox, 6=ListBox, 7=RadioButton. Also moved Memo icon to position 23 (CT_MEMO=24).

- [x] RadioButton does not appear at the correct position on the form at runtime. Fix: used deprecated `NSRadioButton` constant (replaced with `NSButtonTypeRadio`), missing black text color attribute (added attributed title like CheckBox), and height defaulted to 24 (HBControl init) instead of 20 (now set explicitly before param checks in `UI_RadioButtonNew`).

- [x] Before loading a project (`TBOpen`), ask the user if they want to save the current work. Fix: added `MsgYesNoCancel()` function (NSAlert with Yes/No/Cancel buttons) to cocoa_core.m. `TBOpen()` now prompts when forms are open — Yes saves first, No proceeds, Cancel aborts.

- [x] Toggle Form/Code button in toolbar: added after Run button (with separator) in the top speedbar. Checks if form is the key window via `UI_FormIsKeyWindow()` (`[FWindow isKeyWindow]`) — if form is in front brings code editor, otherwise brings form. Previous approach using `isVisible` failed because both windows are always visible (just layered); `isKeyWindow` correctly detects which is active/frontmost. Custom form/window icon at position 9 in `toolbar.bmp`. Function: `ToggleFormCode()` in `hbbuilder_macos.prg`.

- [x] TApplication runtime error handler following Harbour errorsys.prg pattern. `AppShowError()` handles recoverable errors silently: EG_ZERODIV→return 0 (substitute), EG_LOCK→return .T. (retry), EG_OPEN/EG_APPENDLOCK→NetErr(.T.)+return .F. (default). Non-recoverable errors show `MAC_RuntimeErrorDialog` (NSAlert with scrollable mono memo + Copy to Clipboard). Buttons are dynamic: always "Quit", plus "Retry" if canRetry, "Default" if canDefault. Copy button loops without closing. Quit calls `MAC_AppTerminate()` (forces `[NSApp terminate:nil]` to end the Cocoa run loop) then `ErrorLevel(1); QUIT`. Without `MAC_AppTerminate()` the NSApp run loop kept the process alive after Harbour's QUIT. Implemented in `harbour/classes.prg` + `cocoa_core.m`.

- [x] README link: Antonio Linares link now points to `https://github.com/FiveTechSoft` (was `AntoninoLinares`).

- [x] Code editor class member dropdown: 4 strategies to resolve variable class when `:` is typed: 1) `Self:` → current CLASS via `CE_FindCurrentClass()`, 2) DATA comment (`DATA oBtn // TButton`), 3) assignment pattern (`oVar := TForm():New()`), 4) naming convention fallback (`oForm`→TForm, `oButton`→TButton, etc.). `CE_FindClassMembers()` now combines standard class members + user-defined DATA/ACCESS/METHOD from the editor. For `oForm:oButton1` — resolves oForm→TForm, finds `CLASS TForm1 INHERIT TForm` in editor, scans its DATA/ACCESS/METHOD declarations (oButton1, oEdit1, etc.) via `CE_CollectUserData()`, and merges both lists into the dropdown. Also works for the exact class case (Self: in TForm1 shows both TForm members and user DATA).

- [x] MsgInfo() acepta cualquier tipo de valor: nil→"nil", ""→'""', N→Str, L→".T."/".F.", D→DToC, A→"{Array(n)}", O→"{Object:ClassName}", B→"{Block}", C→tal cual. Usa `ValToStr()` helper en `classes.prg`. Strings vacíos muestran '""' en vez de un cuadrado vacío.

- [x] Dropdown no mostraba DATA del usuario (oButton1, etc.): Scintilla usa `SC_ORDER_PRESORTED` por defecto (búsqueda binaria), así que la lista combinada (miembros estándar A-Z + DATA del usuario al final) no estaba ordenada y Scintilla no encontraba los DATA. Fix: `SCI_AUTOCSETORDER` con `SC_ORDER_PERFORMSORT` (=1) para que Scintilla ordene la lista antes de mostrarla.

- [x] Dropdown no buscaba `FROM` (solo `INHERIT`): el código generado por RegenerateFormCode usa `CLASS TForm1 FROM TForm`, no `INHERIT`. Fix: `CE_FindClassMembers()` ahora acepta ambas keywords (`INHERIT` y `FROM`) en los dos puntos donde busca la cláusula de herencia.

- [x] Form OnClick no se disparaba en runtime: el content view del form (`HBFlippedView`) no tenía handler de mouse. Fix: creado `HBFormContentView` (subclase de `HBFlippedView`) con `mouseDown:`/`mouseUp:` que dispara `FOnClick`, `FOnMouseDown`, `FOnMouseUp` del form. Solo en runtime (no en design mode). El form ahora usa `HBFormContentView` como content view.

- [x] Socket-based debugger: replaced broken .hrb in-process debugger with TCP socket protocol. IDE starts TCP server on port 19800, compiles user project as native exe (with `dbgclient.prg` injected), launches process, accepts connection. `dbgclient.prg` installs `__dbgSetEntry` hook, sends PAUSE module:line on each source line, receives STEP/GO/QUIT/GETLOCALS/GETSTACK commands. Uses static array via `DbgState()` to avoid Harbour E0004 ("STATIC follows executable") when concatenated. IDE side: `DbgServerStart/Accept/Send/Recv/Stop` in cocoa_editor.mm, `IDE_DebugStart2` command loop with Cocoa event pump. Debug panel buttons (Step/Go/Stop) change `s_dbgState` which the loop reads.

- [x] Debugger UX simplificado: eliminado el diálogo de debugger redundante (`MAC_DebugPanel`). Un solo click en Debug (toolbar) compila, lanza y conecta directamente. Step/Over/Go/Stop se controlan desde la toolbar inferior (oTB2). Watch/Locals/Stack se mostrarán en el Inspector. Sin diálogos intermedios.

- [x] Inspector en dark mode: `NSAppearanceNameDarkAqua`, table background 0.15, category headers 0.20, text 0.82, alternating rows 0.18.

- [x] Inspector modo debug: al pulsar Debug, el inspector cambia a tabs Locals/CallStack/Watch (oculta combo, título "Debugger"). `INS_SetDebugMode()`, `INS_SetDebugLocals()`, `INS_SetDebugStack()` en cocoa_inspector.m. OnDebugPause recibe 4 params (cFunc, nLine, cLocals, cStack) y actualiza inspector + editor. Al terminar debug, vuelve a Properties/Events. Sin diálogo de debugger redundante.

- [x] IDE Dark Mode completo (por defecto, configurable en futuro):
  - **IDE bar** (ventana superior): `UI_FormSetDarkMode()` aplica `NSAppearanceNameDarkAqua` + fondo 0.18 en window y content view. Se llama después de `Show()` (FWindow debe existir).
  - **Design form**: dark appearance + fondo 0.18 en `createWindowWithRunLoop` cuando `FDesignMode`. Content view (`HBFormContentView`) también con layer bg 0.18.
  - **Dot grid**: fondo cambiado de 0.94 (gris claro) a 0.18 (oscuro), puntos de 0.72 a 0.35.
  - **Inspector**: `NSAppearanceNameDarkAqua`, table bg 0.15, category headers bg 0.20 + text 0.85, rows text 0.82, alternating rows bg 0.18. Guard `respondsToSelector:setTextColor:` para celdas de botón.
  - **Toolbars**: fondo cambiado de 0.92 a 0.22.
  - **Editor**: ya era dark (Scintilla dark theme existente).
  - Para replicar en otros IDEs (Windows/Linux): aplicar los mismos colores de fondo y texto en los equivalentes de cada plataforma.

- [x] Debug button highlight: `UI_ToolBtnHighlight(hToolbar, nBtn, lHighlight)` cambia el layer.backgroundColor del botón a rojo semitransparente cuando activo. Se activa al entrar en debug, se desactiva al salir.

- [x] Debug oculta design form: `UI_FormHide(oDesignForm)` al iniciar debug, `UI_FormBringToFront` al terminar.

- [x] Inspector debug tabs reordenados: tab 0=Call Stack (#:30px, Function:240px), tab 1=Vars (Variable:140px, Value:130px con categorías colapsables PUBLIC/PRIVATE/LOCAL), tab 2=Watch. Headers y anchos se ajustan dinámicamente al cambiar de tab y al entrar/salir de debug mode.

- [x] Variables por scope: `BuildLocals()` en dbgclient.prg usa `__mvDbgInfo(1)` para PUBLIC, `__mvDbgInfo(2)` para PRIVATE, `__dbgVmLocalList(nFrame)` para LOCAL. Envía formato `VARS [PUBLIC] name=val(T) [PRIVATE] ... [LOCAL] ...`. Inspector parsea `[CATEGORY]` como headers colapsables.

- [x] Protocolo inline PAUSE: formato `PAUSE path:FUNC:line|VARS ...|STACK ...` — elimina round-trips GETLOCALS/GETSTACK que causaban desincronización TCP.

- [x] INIT PROCEDURE __DbgInit: `DbgClientStart(19800)` se ejecuta como INIT PROCEDURE en vez de inyectar código en el Project1.prg del usuario. El código del usuario no se modifica (solo se elimina `#include` duplicado).

- [x] Line offset por sección: `aDbgOffsets` guarda `{startLine, name, tabIndex, adjustment}`. Project1.prg usa ajuste +1 (por #include eliminado), Form files +2. Stack lines también convertidos via `DbgFixStackLines()`.

- [x] Framework auto-step: `OnDebugPause` retorna `.F.` para código del framework (nTab==0), el IDE envía STEP automáticamente sin pausar.

- [x] Debug frame detection: `BuildLocals()` recibe `cProcName` del C hook para encontrar el frame exacto en el stack (antes usaba heurística que fallaba con métodos de framework en el stack, ej. oApp desaparecía al asignar `TApplication():New()`). C hook pasa procName como 3er argumento al block.

- [x] User class debugging: el filtro del C hook (`dbghook.c`) e `IsFrameworkFunc` ahora distinguen clases del framework (TForm, TButton — sin dígitos) de clases del usuario (TForm1, TForm2 — con dígitos). Antes filtraba todas las funciones T* y no se podía debuggear código de formularios.

- [x] Self en debug locals: cuando el debugger está dentro de un METHOD (ProcName contiene `:`), se añade `Self` a la sección [LOCAL] usando `__dbgVmVarLGet(nFrame, 0)`.

- [x] Nombres de clase legibles: `DbgValStr` para objetos muestra `TApplication` en vez de `{TAPPLICATION}` — proper-case via `Left+Upper+Lower`.

- [x] Design form → editor tab sync: al hacer click en una ventana de diseño, el editor cambia automáticamente al tab del código fuente de ese formulario. `OnActivate` event en `CreateDesignForm()` llama `OnDesignFormActivate(nFormIdx)` → `SwitchToForm()`.

## Open
