# FiveTech_ERP — HarbourBuilder (Win / Linux / macOS)

Cross-platform ERP shell using the **same meta** as FWH DesktopWeb:

| Layer | Implementation |
|-------|----------------|
| Product name | **FiveTech_ERP** |
| UI shell | HarbourBuilder `TForm` + **`TWebView`** |
| Windows WebView | **Edge WebView2** (FWH engine in `source/backends/win32/webview2`) |
| Linux / macOS WebView | Native HbBuilder backends |
| HTTP | Portable Harbour sockets (`erp_http.prg`, MT) |
| Meta | **Exact copy** of `C:\fwteam\samples\DesktopWeb\meta` → `./meta` (`sync_meta.bat`) |

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

> Linux/macOS binaries cannot be produced from a Windows host without cross-toolchains; use a Linux VM/CI or a Mac.

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

`build_win64.bat` runs this automatically. Runtime order:

1. `./meta/` (exact FWH copy)
2. `C:\fwteam\samples\DesktopWeb\meta\` (live FWH if copy missing)
3. `./meta_fwh/` (legacy junction)

> Looking different in the window is usually the **HTML shell** (`www\index.html` is a slim client). FWH serves the full dashboard HTML from `login.prg`. Meta JSON can be identical while the UI chrome still differs.
