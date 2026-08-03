# App metadata (JSON → table)

This folder holds the **application structure** as JSON. At startup the PRG
loads every document into the DBF table `data\appmeta.dbf` (one row per
document). Runtime code reads from the table (or from memory after load).

## Recommended layout (files)

| File | Key in table | Kind | Purpose |
|------|--------------|------|---------|
| `app.json` | `app` | app | Root: title, version, `vertical`, ports, **`locale`** (currency, decimals, VAT, dates) |
| `modules.json` | `modules` | modules | Sidebar / menu tree (base; may be overridden by vertical) |
| `verticals/<name>/modules.json` | `modules` | modules | Vertical menu overlay when `app.vertical` is set |
| `screens/login.json` | `screen.login` | screen | Login fields, demo users |
| `screens/appointments.json` | `screen.appointments` | screen | Grid columns, filters, toolbar |
| `lookups/patients.json` | `lookup.patients` | lookup | Patient F2 dialog (page size, columns) |
| `screens/parties.json` … | `screen.parties` etc. | screen | **CRM core** lists / card / pipeline |
| `data/parties.json` … | `data.parties` etc. | data | **CRM core** demo rows |
| `screens/patients.json` … | `screen.*` | screen | Clinic + ERP demo screens |
| `data/patients.json` | `data.patients` | data | Clinic patient list (demo; F2 prefers parties) |
| `theme.json` | `theme` | theme | Colors / chrome tokens |

### CRM core (generic)

Always seeded; independent of vertical:

| Menu | Screen | Data | Notes |
|------|--------|------|-------|
| CRM → Parties | `screen.parties` | `data.parties` | Person / organization + roles |
| CRM → Party card | `screen.party_card` | `data.parties` | `layout: form` tabs |
| CRM → Accounts | `screen.accounts` | `data.accounts` | Segments / companies |
| CRM → Activities | `screen.activities` | `data.activities` | Call / task / appointment |
| CRM → Opportunities | `screen.opportunities` | `data.opportunities` | Funnel rows |
| CRM → Pipeline board | `screen.pipeline` | `data.opportunities` | `layout: workflow` by stage |

### Vertical packs

Set `"vertical": "clinic"` in `app.json` (or clear it for base modules only).
At load, `MetaApplyVertical()` imports `meta/verticals/<name>/modules.json` over the
`modules` key. Screens and datasets stay in the base `meta/` tree.

| Pack | Folder | Purpose |
|------|--------|---------|
| clinic | `verticals/clinic/` | Clinic + CRM (patients, exams, admission) |
| services | `verticals/services/` | Professional services (projects, timesheets) |
| retail | `verticals/retail/` | Store / POS (products, stock, tickets) |
| demo | `verticals/demo/` | Consulting group — full showcase: all 17 layouts + lookups/validations/whens |

Switch pack: **Edit app → Vertical pack**, or set `"vertical"` in `app.json` and restart / save.

### Product tour demo (`demo.main`)

| File | Key |
|------|-----|
| `demo.json` | `demo.main` |

Configured via `app.demo` (enabled, ref, autoStartUsers, delay). Runtime: top bar **▶ Demo**.
User `demo` auto-starts once per browser session. Steps support `screenByVertical` for clinic / services / retail.

### App locale (`app.locale`)

Configured in **Edit app → Locale & numbers** (admin):

| Field | Purpose |
|-------|---------|
| `currency` / `currencySymbol` | Code + display symbol (EUR / €) |
| `currencyPosition` | `prefix` · `suffix` · `none` |
| `showCurrencySymbol` | Show symbol in grids / reports |
| `decimals` | 0–6 decimal places |
| `decimalSep` / `thousandSep` | `,` / `.` / space |
| `taxRate` | Default VAT % for document totals |
| `dateFormat` | `DD/MM/YYYY` · `MM/DD/YYYY` · `YYYY-MM-DD` |
| `timeFormat` | `24h` · `12h` |
| `firstDayOfWeek` | 0=Sun · 1=Mon · 6=Sat |

Runtime: `moneyFmt()` / `parseMoney()` / document tax use these settings after Save.

### Services pack screens

| Screen | Data |
|--------|------|
| `screen.projects` | `data.projects` |
| `screen.project_card` | `data.projects` (`layout: form`) |
| `screen.timesheets` | `data.timesheets` |

### Retail pack screens

| Screen | Data |
|--------|------|
| `screen.products` | `data.products` |
| `screen.stock` | `data.stock` |
| `screen.pos_sales` | `data.pos_sales` |

Runtime: every sidebar item with `"screen": "screen.xxx"` opens a generic grid
driven by that screen JSON + its `dataRef`. API: `GET /api/dataset?key=data.xxx&q=`.

### Demo screens for input controls

| Menu | Screen key | Data | Controls shown |
|------|------------|------|----------------|
| Demo controls → Work orders | `screen.tasks` | `data.tasks` | text, select, checklist, money, checkbox |
| Demo controls → Service catalog | `screen.catalog` | `data.catalog` | text, select, checklist, money, checkbox |

Open a row with **Edit** / **New** to exercise select, checklist and checkbox.

### Master-detail / document

| Menu | Screen | Master data | Detail data |
|------|--------|-------------|-------------|
| Clinic → Invoices (M/D) | `screen.invoices` | `data.invoices` | `data.invoice_lines` |
| Clinic → Quotes (document) | `screen.quotes` | `data.quotes` | `data.quote_lines` |

`layout: master-detail` or `document` (+ tax totals bar / Recalc).

### Other ERP layouts (`layout` in screen JSON)

| Layout | Demo menu | Screen |
|--------|-----------|--------|
| `form` | Patient card | `screen.patient_card` |
| `wizard` | Admission wizard | `screen.admission` |
| `folder` | CRM folder (tabs) | `screen.crm_folder` |
| `menu` | Cadastros / launch pad | (vertical packs) |
| `calendar` | Day agenda | `screen.day_agenda` |
| `dashboard` | Dashboard KPIs + charts (bar/donut widgets) | `screen.kpis` |
| `tree-detail` | Org tree | `screen.org` |
| `matrix` | Roster matrix | `screen.roster` |
| `assign` | Users ↔ roles | `screen.user_roles` |
| `workflow` | Approvals queue | `screen.approvals` |
| `settings` | Parameters | `screen.params` |
| `audit` | Audit log | `screen.audit_log` |
| `import` | CSV import | `screen.import_csv` |
| `period` | Period & close | `screen.period_close` |
| `context` | Company context | `screen.context` |

Admin **Design form** can pick these layouts; specialized UIs render from meta JSON.

## Table `appmeta.dbf`

| Field | Type | Len | Notes |
|-------|------|-----|-------|
| KEY | C | 40 | Primary key, dotted name |
| KIND | C | 16 | app / modules / screen / lookup / data / theme |
| TITLE | C | 60 | Human label |
| VER | C | 12 | Document version |
| FPATH | C | 80 | Source relative path (for re-import) |
| JSON | M | | Full JSON document as memo |
| UPDATED | C | 19 | `yyyy-mm-dd hh:mm:ss` |

Why **several JSON files** + **one table**:

- Files: easy to edit, diff, and put in git.
- Table: one place to query at runtime, sync to other DBs later, ship without loose files.

## Load order

1. `MetaOpen()` — open/create `data\appmeta.dbf`
2. `MetaSeedFromFiles()` — if empty (or force), import all files above
3. `MetaGetHash( "app" )` — decode JSON memo to Harbour hash

## API (sample)

- `GET /api/meta` — list of keys/kinds/titles (no big memos)
- `GET /api/meta?key=lookup.patients` — one document
- `POST /api/meta` — **runtime form designer**: body `{ "key":"screen.patients", "doc":{...}, "writeFile":true }`
  (auth required, admin only; keys `app`, `modules`, `screen.*` / `lookup.*` / `report.*`). Updates memory cache and the JSON file under `meta\`. With `app.vertical` set, the `modules` key resolves to that pack's `verticals/<name>/modules.json` for both reads and writes.
- `GET /api/meta/fields?key=data.patients` — field names from first data row (column picker)

## Product docs

| Doc | Language |
|-----|----------|
| [FEATURES.md](FEATURES.md) / [FEATURES.es.md](FEATURES.es.md) | Feature inventory |
| [ROADMAP.md](ROADMAP.md) / [ROADMAP.es.md](ROADMAP.es.md) | Builder positioning, security/validation/OpenADS roadmap |

## Reports sketch (not a full designer)

Lightweight **report definitions** (`report.*`) — columns + dataRef + optional groupBy/sumFields.
No band designer: list → print HTML / PDF / CSV.

| File | Key | Purpose |
|------|-----|---------|
| `reports/parties.json` | `report.parties` | Parties grouped by kind |
| `reports/projects.json` | `report.projects` | Projects by status + budget totals |
| `reports/pos_day.json` | `report.pos_day` | POS tickets by status |
| `screens/reports.json` | `screen.reports` | Catalog UI (`layout: report-list`) |

**Runtime**

- Menu **Reports** → preview / PDF / CSV for each `report.*`
- On any list screen (admin): header button **Report** → “Save as report” (writes `meta/reports/<name>.json`)
- Toolbar Print/PDF on a list still prints the live grid (ad-hoc); saved reports are reusable definitions

Schema sketch:

```json
{
  "id": "report.xxx",
  "kind": "report",
  "title": "…",
  "dataRef": "data.xxx",
  "sourceScreen": "screen.xxx",
  "orientation": "portrait|landscape",
  "groupBy": "fieldId",
  "sumFields": ["amount"],
  "columns": [{ "id", "label", "type", "align", "format" }],
  "footerNote": "…"
}
```

Next steps (not in this sketch): visual column picker UI, filters, master-detail documents, email.

## Runtime designers (admin only)

### Form designer

Opens from **Design form**. Layout dropdown covers all ERP types. Specialized panels:

| Layout | Extra UI |
|--------|----------|
| `list` | Grid columns + control types (text/money/select/checklist/checkbox) |
| `master-detail` / `document` | Detail dataRef, masterKey, master/detail columns |
| `form` / `wizard` | Key field, tabs/steps (`id\|Label\|field1,field2`), field controls |
| `workflow` | Status field, transitions (`Stage = Next1, Next2`), queue columns |
| Other specialized | Layout is preserved; JSON extras kept on save |

**Bug fixed:** load used to force only `list`/`master-detail`, wiping `form`/`workflow`/etc.

### Edit app (admin)

Branding, HTTP port, **vertical pack** (none / clinic / …), and sidebar menu.

- `GET /api/verticals` lists packs under `meta/verticals/*/modules.json`.
- Saving `app.vertical` reloads modules from the pack (or base `modules.json` when cleared) **immediately**.
- With a vertical active, menu Save writes into that pack’s `modules.json`.

## Runtime designers (admin only) — API

Only user **admin** (demo password `1234`) can save meta edits. Server rejects
`POST /api/meta` for other users. UI hides design buttons for non-admin sessions.

### Form designer
From the dashboard: **Design form** (top bar) or on a meta screen header.

You can edit title, `dataRef`, grid columns, and **toolbar actions**.

Column **control** types (edit form + grid display):

| type | Input in add/edit form |
|------|-------------------------|
| `text` | Single-line text |
| `money` | Numeric / money |
| `select` | Combobox (`options`: `["A","B"]` or comma list in designer) |
| `checklist` | Multi-checkbox list (stored as string array) |
| `checkbox` | Yes/No boolean |

Also: align, format (legacy `money`), order, and **toolbar actions**:

| Action | Behaviour |
|--------|-----------|
| `add` | New record form (fields = grid columns) |
| `edit` | Edit selected row (double-click also works) |
| `delete` | Delete selected row (confirm) |
| `print` | HTML list + browser print dialog |
| `pdf` | Same print dialog — choose “Save as PDF” |
| `excel` | Download CSV (Excel-friendly, `;` + BOM) |
| `refresh` | Reload dataset |
| `close` | Back to appointments |

CRUD persists via `POST /api/dataset` into `meta/data/*.json` + `appmeta`.

### App designer
Sidebar footer: **Edit app** (admin only). Edits:

- **Branding**: logo text (badge), brand name (e.g. FiveTech), subtitle
  (Desktop & Web), window title → `meta/app.json`
- **HTTP port**: `httpPort` in `meta/app.json` (default **2222**). Change needs
  app restart to take effect.
- **Menu**: `modules` sections/items (id, label, icon, screen, sub, active, order)
  → `meta/modules.json`

Save refreshes the sidebar branding and menu live.
