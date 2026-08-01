# Windows TWebView → Edge WebView2 (FWH port)

Live `TWebView` on Windows uses the **FiveWin WebView2 host**, adapted for HarbourBuilder.

## Origin (FWH / c:\fwteam)

| FWH | HarbourBuilder |
|-----|----------------|
| `source/internal/twebview/cwebview.cpp` | `fwh_webview2.cpp` |
| `source/internal/twebview/TWebView.h` | `FwhWebView2.h` (class renamed `FwhWebView2`) |
| `source/internal/twebview/webview2.h` | `webview2.h` (Microsoft Edge WebView2 SDK headers) |
| `source/winapi/webview2.c` | C API embedded at bottom of `fwh_webview2.cpp` |

Class rename avoids clashing with HarbourBuilder’s control class `TWebView` (`TControl` child).

## Architecture

```
Harbour  TWebView:Navigate / LoadHTML / EvaluateJS
    → UI_WebViewLoad / UI_WebViewLoadHTML / …   (hbbridge.cpp)
    → TWebView::Navigate / LoadHTML             (tcontrols.cpp)
    → webview2_new / navigate / sethtml / eval  (fwh_webview2.cpp)
    → Edge WebView2 (EmbeddedBrowserWebView.dll via registry / Evergreen)
```

Linux / macOS keep their native WebView backends; **same Harbour `TWebView` API**.

## Runtime requirement

Target machine needs **Microsoft Edge WebView2 Runtime** (Evergreen or Fixed Version).

Optional: copy `WebView2Loader.dll` next to the exe (not required by this host loader path, which loads `EmbeddedBrowserWebView.dll` from the Runtime install).

## Rebuild

```bat
cd /d c:\harbourbuilder
build_msvc_x64.bat
```

Or full IDE build via `build_win.bat` (option MSVC x64).

Verified: `fwh_webview2.cpp` + IDE link succeed with MSVC x64 (2026-08).

## Same Harbour source on three platforms

```harbour
@ 50, 10 WEBVIEW ::oWeb OF Self SIZE 800, 600
::oWeb:Navigate( "http://localhost:2222/" )
```

| OS | Backend |
|----|---------|
| Windows | Edge WebView2 (`fwh_webview2.cpp` / FWH port) |
| Linux | GTK / native WebView in `gtk3_core.c` |
| macOS | Cocoa / WKWebView in `cocoa_core.m` |

Application PRG code stays the same; only the UI_* implementation differs.
