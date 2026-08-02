# FiveTech_ERP — HarbourBuilder (Win / Linux / macOS)

**Same PRG source on every OS** — only the C/C++/ObjC backend and link step change.

| Layer | Shared | Platform |
|-------|--------|----------|
| Entry | `Project1.prg` | — |
| Form + WebView | `Form1.prg` | Win WebView2 / Mac WKWebView / Linux WebKitGTK |
| HTTP API | `erp_http.prg` | Harbour MT sockets |
| Meta loader | `erp_meta.prg` | disk JSON |
| Framework classes | `classes.prg` (HbBuilder) | — |
| Meta data | `./meta` (FWH DesktopWeb JSON) | sync on Windows via `sync_meta.bat` |
| UI HTML | `./www` (login + dashboard from FWH) | — |

## Build

### Windows 64 (MSVC) — builds on this machine

```bat
cd /d c:\harbourbuilder\samples\projects\FiveTech_ERP
build_win64.bat
```

**Output:** `c:\harbourbuilder\samples\projects\FiveTech_ERP\FiveTech_ERP.exe`  
Requires: Visual Studio x64, Harbour msvc64 + **hbvmmt**, Edge **WebView2 Runtime**.

### Linux — run the script **on Linux**

```bash
cd /path/to/harbourbuilder/samples/projects/FiveTech_ERP
chmod +x build_linux.sh
./build_linux.sh
```

**Output:** `./FiveTech_ERP`  
Requires: Harbour, `libgtk-3-dev`, pkg-config.

### macOS — run the script **on a Mac**

```bash
cd /path/to/harbourbuilder/samples/projects/FiveTech_ERP
chmod +x build_mac.sh
./build_mac.sh
```

**Output:** `./FiveTech_ERP`  
Requires: Harbour darwin/clang, Xcode CLI tools.

> Linux/macOS binaries must be built **on that OS** (or CI). Source PRGs are identical; only native backends differ.

### Source units (all platforms)

```
Project1.prg   Form1.prg   erp_meta.prg   erp_http.prg
assemble_main.ps1 | assemble_main.sh   → main.prg (Project1+Form1 only)
erp_meta / erp_http compile as separate Harbour units (STATIC-safe)
```

## Run

```
FiveTech_ERP.exe   # or ./FiveTech_ERP
```

- Embedded WebView → `http://127.0.0.1:2222/` (same idea as FWH DesktopWeb: HTTP + WebView only)

Login: **admin/1234** or **demo/demo**

## Meta path (same JSON as FWH)

**Source of truth:** `C:\fwteam\samples\DesktopWeb\meta`  
**Local tree:** `./meta` — full mirror (all screens, data, lookups, reports, verticals).

```bat
sync_meta.bat
```

`build_win64.bat` runs this automatically. Runtime order (`ErpMetaRoot()` in `erp_meta.prg`):

1. `./meta/` (exact FWH copy)
2. `../Resources/meta/` (inside macOS .app bundle)
3. `./meta_fwh/` (legacy junction)
4. `C:\fwteam\samples\DesktopWeb\meta\` (live FWH, Windows dev only)

> Looking different in the window is usually the **HTML shell** (`www\index.html` is a slim client). FWH serves the full dashboard HTML from `login.prg`. Meta JSON can be identical while the UI chrome still differs.

> **Warning — generated files:** `sync_meta.bat` (run by every build) mirrors `./meta` from the FWH tree and **regenerates `www\login.html` / `www\dashboard.html`** from the TEXT blocks in `C:\fwteam\samples\DesktopWeb\login.prg` (`_extract_fwh_html.py`). Never edit `www\*.html` or `./meta` locally as the only copy — apply durable changes in the FWH source and re-sync, or they are lost on the next build.
