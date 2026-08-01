# DesktopWeb — product roadmap

Positioning (Pritpal, 2026): this sample is essentially an **ERP application builder** — comprehensive and impressive. Focus must shift to **simplicity of change** and **data security**. Web front-ends leak easily and need utmost attention. As **OpenADS** matures, data retention and security should ride on it. **Data-driven screens with in-place validation** are hard in the GUI world, and harder when users can edit component definitions — but if done well, this can be a **killer in its segment**.

English overview; Spanish version: [ROADMAP.es.md](ROADMAP.es.md).  
Feature inventory: [FEATURES.md](FEATURES.md) · [FEATURES.es.md](FEATURES.es.md).

---

## 1. Product identity

| Today (sample) | Target (platform) |
|----------------|-------------------|
| Meta-driven ERP shell + demos (clinic / services / retail) | **ERP application builder** for Desktop & Web |
| JSON meta + local DBF/demo data | Same meta UI + **hardened data plane** (OpenADS) |
| Admin designers (forms, menu, locale, reports sketch) | Safe, simple definition editing + **server-side rules** |
| Impressive showcase | Product segment: FWH / mid-market / desktop+web builders |

**Promise to keep**

- Change structure without recompile (meta JSON + designers).
- Same UI on Windows (WebView2) and browser.
- Vertical packs as menu/label overlays on a shared CRM/core.

**Promise to earn**

- Change data only with rights, validation, and audit.
- Web front cannot bypass rules or leak privileged meta.

---

## 2. Strategic pillars (from feedback)

1. **Simplicity to change elements** — fewer steps, clearer designers, fewer broken meta loads.
2. **Data security** — least privilege, server authority, no trust of the browser alone.
3. **Data-driven validation** — rules in meta, enforced client + server before/while editing definitions.
4. **OpenADS as data backbone** — retention, security, multi-user concurrency when ready.

---

## 3. Phased roadmap

### Phase A — Harden the sample (near term)

*Goal: same demos, trustworthy HTTP surface for local/LAN use.*

| Item | Notes |
|------|--------|
| Role model | Beyond `admin` / other: e.g. `admin`, `designer`, `user`, `readonly` |
| API authorization | Every mutating route checks role **server-side** (never only `IS_ADMIN` in JS) |
| Cookie / session | `HttpOnly`, `SameSite`, optional `Secure`; idle timeout; logout invalidates |
| CSRF | Token or same-site discipline on `POST /api/*` |
| Write allowlists | Which `data.*` / `screen.*` keys may be written; deny by default |
| Error hygiene | No paths/stack traces to clients |
| Meta load robustness | Directory seed + disk fallback + UTF-8 BOM strip (in progress) |
| Audit trail | Who changed which meta key / data row (append-only log) |

### Phase B — Safe editing & validation (medium term)

*Goal: designers remain powerful but cannot invent unsafe behaviour.*

| Item | Notes |
|------|--------|
| Field schema in meta | `required`, `min`/`max`, `pattern`, `options`, `readonly`, `unique` |
| Server validation | `POST /api/dataset` rejects invalid rows with field-level errors |
| Client validation | Same rules for UX; never the only gate |
| Designer constraints | Only schema-supported types/layouts; no free-form executable logic from browser |
| Draft / publish | Optional: edit draft `screen.*`, publish to live key |
| Undo / version | Keep last N versions of designed documents under `meta/` or DB |
| Contextual edit | “Design this screen” from open workspace; less hunting in catalogs |
| Menu/app designer | Guardrails: cannot orphan home route; vertical save path explicit |

Example field rule (sketch):

```json
{
  "id": "email",
  "type": "text",
  "required": true,
  "pattern": "email",
  "maxLength": 120
}
```

### Phase C — OpenADS data plane (when OpenADS is ready)

*Goal: same screens; production-grade storage and rights.*

| Item | Notes |
|------|--------|
| `dataRef` adapter | Map meta datasets to ADS tables / queries |
| Server rights | User/role → table/field/row (OpenADS + app layer) |
| Multi-company | Align with existing `context` layout / company switcher |
| Retention | Backup, archive, legal hold hooks via ADS practices |
| Concurrency | Optimistic locks or ADS locks on update |
| Migration path | Demo JSON → ADS seed tools for vertical packs |

### Phase D — Platform polish (later)

| Item | Notes |
|------|--------|
| Report definitions | Grow `report.*` (filters, parameters) without full band designer first |
| More vertical packs | Only after A–B stable (security + validation) |
| Theming / branding | Already partial; lock down who may change `app` / theme |
| Automated tests | API auth matrix; validation matrix; meta import smoke |
| Product tour | Keep didactic demo; optional vertical-specific `demo.*` packs |

---

## 4. Explicit non-goals (for now)

- Full GL / payroll / hardware POS as core product.
- Crystal/FastReport-class visual band designer as v1 priority.
- Arbitrary script execution from meta (security anti-pattern).
- Multi-tenant public SaaS without Phase A–C complete.
- More vertical demos at the expense of security/validation depth.

---

## 5. Success criteria (“killer in its segment”)

A partner or ISV can:

1. Clone the sample, switch vertical, rebrand, set locale — **in minutes**, without C rebuild.
2. Design a list/form/workflow screen in-app — **without breaking** other users’ data.
3. Expose the web UI on a LAN — **without** anonymous writes or meta leakage.
4. Point `dataRef` at OpenADS — **same screens**, real rights and audit.
5. Explain the product in one sentence: *“Meta-driven ERP builder for Desktop & Web.”*

---

## 6. Suggested near-term work order

1. **Security pass** on HTTP API (roles, CSRF, allowlists, session).
2. **Validation schema** on `screen.*` + enforce in `POST /api/dataset`.
3. **Designer safety** (schema-only fields, draft/publish optional).
4. **OpenADS adapter** behind `dataRef` when ADS stack is mature enough for the sample.
5. Verticals / reports expansion only after 1–3.

---

## 7. Documentation map

| Doc | Purpose |
|-----|---------|
| [FEATURES.md](FEATURES.md) | What the sample does today |
| [README.md](README.md) | Meta layout, API, locale, demo tour |
| [ROADMAP.md](ROADMAP.md) | This file — where to invest next |
| `verticals/*/README.md` | Per-pack menu focus |

---

*This roadmap is directional for the DesktopWeb sample and product conversation; it does not commit FiveTech to dates or release numbers.*
