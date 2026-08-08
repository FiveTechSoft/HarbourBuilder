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

## One design, three branches (PC / hybrid / 100% web)

`erp_http.prg` already answers on `0.0.0.0`, serves the JSON API **and**
static files from `www/`, and the desktop WebView is just one more client of
that HTTP contract. This sample now makes that explicit as three interchangeable
branches of the **same build** — nothing above changes for the default
(no‑argument) run:

| Branch | Container | How it loads |
|---|---|---|
| **PC** (native) | WebView2 inside the exe | `ZWEB_FRONT=<bundle>` makes `Form1.prg` navigate its embedded WebView2 to that bundle instead of the FWH shell. Unset → identical to today. |
| **Hybrid** (native) | WebView2 per module, alongside native screens | Same URLs (`/web-*/`), module by module, from any native shell (pattern used in production by Zerus's `FW_DASHBOARD`). |
| **Web** (ours) | Any real browser | `http://<host>:2222/web-vainilla/`, `/web-angular/`, `/web-react/`, `/web-vue/`, or `/portal/` to pick one. Same origin, same `DWSESS` cookie, no CORS. |

```
frontends/     source of the 4 bundles (vainilla / Angular 21+PrimeNG / React / Vue)
www/web-*      built static output served by erp_http.prg (same as any other www/ asset)
www/portal/    branch picker (login → choose frontend)
scripts/       api-check.mjs · concurrency*.py · evidence.cjs (reproducible checks)
docs/web-branch/  proposal, evidence and the concurrency fix write-up
```

Runtime container detection (`container.js` / `detectRama()` in each
frontend): `window.chrome.webview` → pc, `+SendToFWH` → hybrid, else → web.
Exposes `window.__RAMA__` / `data-rama` for capability flags and CSS — the
SPA code itself calls no container API directly, only an optional bridge with
an HTTP fallback.

Two small, opt-in patches ship with this: `ZWEB_FRONT` in `Form1.prg` (off by
default) and an `ErpMutexGuard` fix for a read‑modify‑write race in
`POST /api/dataset` under concurrent writers (see
`docs/web-branch/HALLAZGO_CONCURRENCIA_DATASETS.md`). Full rationale,
per-branch trade-offs and reproducible evidence:
`docs/web-branch/PROPUESTA_FIVETECH_RAMA_WEB.md` and
`docs/web-branch/SUSTENTO_RAMA_100_WEB.md`.

Rebuilding a frontend after editing its source:

```bat
cd frontends\react  && npm install && npm run build
cd frontends\vue    && npm install && npm run build
cd frontends\web-angular && npm install && npx ng build --configuration=production
:: copy each dist/ output into www\web-<name>\ (vainilla needs no build step)
```
