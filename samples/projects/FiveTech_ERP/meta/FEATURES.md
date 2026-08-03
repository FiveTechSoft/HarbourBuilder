# DesktopWeb ERP sample — feature list

Built as a **meta-driven FiveWin / Harbour sample**: one Windows desktop shell (WebView2) + embedded HTTP server; the same UI runs in the browser and on the desktop.

Spanish version: [FEATURES.es.md](FEATURES.es.md)  
Product roadmap: [ROADMAP.md](ROADMAP.md) · [ROADMAP.es.md](ROADMAP.es.md)

---

## 1. Architecture & runtime

- **Dual delivery**: desktop WebView2 app and pure browser UI share the same HTML/CSS/JS and HTTP API
- **Embedded multi-thread HTTP server** (default port **2222**, configurable)
- **Session login** with cookie auth (`DWSESS`); users in `data.users` (Admin → Users)
- Passwords stored as **CRC32 only** (never plain text); seed: `admin`/`1234`, `demo`/`demo`
- **Multi-company + multi-app**: session company (`data.companies`); each company can link **N apps** (verticals: clinic, demo, services, retail, **ferreteria**); status-bar / `screen.context`; menu follows active app
- **App metadata model**: JSON files under `meta/` → `data/appmeta.dbf` → in-memory cache
- **Live APIs**: `/api/login`, `/api/meta`, `/api/dataset`, `/api/context`, `/api/patients`, `/api/balances`, `/api/verticals`, …
- **CRUD on demo datasets** (`data.*`) from the UI (add / edit / delete)
- **English UI** (sample branding: FiveTech Desktop & Web)

---

## 2. Authentication & security

- Login screen (user, password, work date) defined in meta
- Role-style **admin gate** for designers and app configuration
- Non-admin users can run operational screens without design tools

---

## 3. Shell / chrome (desktop + web)

- Sidebar navigation driven by `modules` meta
- Docked workspace panels (painel-style chrome for list/detail screens)
- Dark / light theme tokens (`theme.json`)
- Branding: logo text, brand name, subtitle, window title
- Toast messages, floating modals, patient F2-style lookup panel
- **Learning-center demo** (`demo.main` menu mode / **▶ Demo**): catalog of tours (`demo.overview`, `demo.list_edit`, `demo.designers`, `demo.multi_app`); pick what to learn; Pause/Next/Stop; returns to menu when a tour ends; optional auto-start for user `demo`

---

## 4. Meta-driven screens & layouts

Generic screen engine driven by JSON. Supported **layouts**:

| Layout | Purpose |
|--------|---------|
| `list` | Single grid + toolbar; optional `filters`, `markRows`, `totals` / `sumFields`; **edit dialog** defaults from `grid.columns` (auto multi-col width); optional per-screen `form` (admin designer) |
| `master-detail` | Master grid + linked detail lines |
| `document` | Document + line totals + tax |
| `form` | Card form with tabs |
| `wizard` | Multi-step wizard |
| `folder` | Notebook tabs hosting child screens |
| `menu` | Painel groups of actions |
| `calendar` | Day / agenda style |
| `dashboard` | KPI tiles + bar/donut widgets (`dashboard.widgets`, Design form) |
| `tree-detail` | Org tree + detail |
| `matrix` | Roster / slot matrix |
| `assign` | Dual-list assignment (users ↔ roles) |
| `workflow` | Status queue + transitions (pipeline) |
| `settings` | Parameter-style form |
| `audit` | Audit log view |
| `import` | CSV import sketch |
| `period` | Period / close sketch |
| `context` | Company / multi-company context |
| `report-list` | Report catalog |

**Grid field controls**: text, money, select, checklist (multi), checkbox

**Toolbars**: add, edit, delete, print, PDF, Excel/CSV, refresh, close

---

## 5. CRM core (generic, always seeded)

- **Parties** (persons & organizations, roles, source, owner)
- **Party card** (tabbed form)
- **Accounts** (segments / partners / companies)
- **Activities** (call, task, appointment, meeting, note)
- **Opportunities** (funnel amounts, probability, close date)
- **Pipeline board** (workflow layout by stage)
- Lookup / F2 master prefers **parties**, falls back to patients

---

## 6. Vertical industry packs

Selectable via `app.vertical` or **Edit app → Vertical pack** (applies immediately):

| Vertical | Focus |
|----------|--------|
| **clinic** | Patients, cards, balance, exams, admission, invoices, quotes, schedule |
| **services** | Projects, project card, timesheets, delivery + commercial |
| **retail** | Products, stock, POS tickets, store back-office |

- Packs live under `meta/verticals/<name>/modules.json`
- Menu edits while a pack is active write into that pack
- Clearing the pack restores base `modules.json`
- API: `GET /api/verticals`

---

## 7. Clinic / healthcare demos

- Patients master list
- Patient card (form)
- Patient balance
- Exam archive
- Admission wizard
- Appointments (home-style operational grid)
- Day agenda calendar
- Invoices master-detail
- Quotes document with tax totals

---

## 8. Services vertical demos

- Projects list (budget, spent, status, type)
- Project card (form tabs)
- Timesheets (hours, rate, amount, billable, approval status)
- Reuses CRM parties, quotes, invoices, work orders

---

## 9. Retail / POS demos

- Product catalog (SKU, barcode, tax, UoM)
- Stock by warehouse (qty, min, reserved, bin, status)
- POS sales tickets (register, cashier, tender, status)
- Customer parties / segments

---

## 10. ERP form gallery demos

- Dashboard KPIs
- Organization tree
- Weekly roster matrix
- Users ↔ roles assignment
- Approvals workflow queue
- Parameters / settings
- Audit log
- CSV import
- Period close
- Company context
- Work orders & service catalog (control demos)
- Group, budget, accounting, calendar list, stats

---

## 11. Designers (admin only)

### Form designer

- Design any `screen.*` / `lookup.*` at runtime
- Choose layout, title, dataRef, columns / field types & options
- Master-detail settings (detail dataRef, link key)
- **Form / wizard**: key field + tabs/steps (`id|Label|fields`)
- **Workflow / pipeline**: status field + transitions
- Saves to memory + DBF + `meta/screens/*.json`

### Edit app (app designer)

- Branding (logo, name, subtitle, window title)
- HTTP port (restart required to bind)
- **Database** driver / OpenADS connection
- **Locale & numbers** (see below)
- **Screens catalog**: list / new / edit (→ form designer) / open / delete `screen.*`
- **Processes catalog**: list / new / run / delete `process.*` (binds to compiled Harbour handlers)
- Full **sidebar menu editor** (sections, items, icons, screens **or processes**, sub/active)

Delete screen/process: `POST /api/meta` with `{ "key":"screen.x"|"process.x", "action":"delete" }` (admin; not `app` / `modules` / `screen.login`).

### Processes (server-side Harbour)

- Meta under `meta/processes/*.json` → key `process.*`
- Each process names a **whitelist handler** from `erp_proc.prg` (never browser-executed code)
- Run: `POST /api/process` `{ "key":"process.hello", "params":{}, "row":{...} }`
- Call from **menu** (`"process":"process.hello"`), **toolbar** object entries, or Edit app → Processes → Run
- Demo handlers: `Hello`, `EchoContext`, `PingStatus`

---

## 12. Locale & regional configuration

Stored in `app.locale`, editable in Edit app:

- Currency code & symbol
- Symbol position (prefix / suffix / none)
- Show/hide symbol in grids
- Decimal places (0–6)
- Decimal & thousands separators
- Default VAT / tax % (document totals)
- Date format, time format, first day of week
- Live sample preview in the designer
- Runtime `moneyFmt` / `parseMoney` + refresh of open grids after save

---

## 13. Reports (lightweight sketch — not a band designer)

- Meta documents `report.*` under `meta/reports/`
- Sample reports: parties (grouped), projects (grouped + sums), POS day
- **Reports catalog** screen (preview / PDF / CSV)
- **Save as report** from any list (admin): captures columns, dataRef, optional groupBy
- Group headers, subtotals on money fields, grand total, orientation
- Ad-hoc print/PDF/Excel still available on live grids

---

## 14. Printing & export

- Print list / report (browser print dialog)
- Print to PDF (via print dialog)
- Excel-style **CSV export** (BOM, semicolon separator)
- Document recalculate (subtotal / tax / total)

---

## 15. Data model (demo JSON datasets)

Examples among many:

- CRM: parties, accounts, activities, opportunities
- Clinic: patients, balances, exams, patient cards, calendar day slots
- Commercial: invoices + lines, quotes + lines, catalog
- Services: projects, timesheets
- Retail: products, stock, pos_sales
- Admin: users, roles, user_roles, settings, audit, companies, workflow, dashboard KPIs, org tree, matrix slots

Runtime mutation persists through the meta/DBF path used by the sample.

---

## 16. Admin & platform ops (sample scope)

- Parameters screen
- Audit log view
- User / role assignment
- Company context
- Import CSV sketch
- Period close sketch
- Configurable entry routes (`login` / `home` in `app.json`)

---

## 17. Developer / sample engineering

- Build via `build_new.bat` (e.g. `hm64 -mt`)
- Source of truth: JSON under `meta/` (git-friendly)
- Documented load path and designers in `meta/README.md`
- Vertical README packs for clinic / services / retail
- Safe patterns for Harbour `TEXT INTO` (no broken JS escapes)

---

## What this is *not* (honest scope)

- Full financial GL / multi-ledger accounting product
- Native Crystal/FastReport-style visual band report designer
- Production multi-tenant SaaS security model
- Real POS hardware, payroll, or deep manufacturing MRP

It **is** a showcase ERP shell: **meta UI + CRM core + industry verticals + designers + locale + light reports**, suitable for demos and as a blueprint for FiveWin Desktop & Web applications.

---

See also: [README.md](README.md) for meta file layout and API notes.
