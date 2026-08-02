# Vertical pack: demo — Consulting group (full showcase)

A **professional services / consulting** vertical that exercises **every layout
the runtime can render** — use it to demo the product end to end or as a
regression checklist for the meta engine.

Activate: **Edit app → Vertical pack → demo** (or set `"vertical": "demo"` in
`meta/app.json` and restart).

## Layout coverage (17/17)

| Layout | Screen | Menu |
|--------|--------|------|
| `list` | `screen.parties`, `screen.accounts`, `screen.activities`, `screen.opportunities`, `screen.projects`, `screen.engagements`, `screen.timesheets`, `screen.tasks`, `screen.accounting`, `screen.budget`, `screen.catalog` | CRM / Delivery / Finance / Admin |
| `form` | `screen.party_card`, `screen.project_card`, **`screen.engagement_form`** | CRM / Delivery |
| `wizard` | **`screen.onboarding`** | CRM |
| `master-detail` | **`screen.cons_invoices`** | Finance |
| `document` | **`screen.cons_quotes`** | Finance |
| `workflow` | `screen.pipeline`, **`screen.cons_approvals`** | CRM / Finance |
| `calendar` | **`screen.cons_agenda`** | Delivery |
| `dashboard` | **`screen.exec_dashboard`** | Executive |
| `tree-detail` | `screen.org` | People |
| `matrix` | `screen.roster` | Delivery |
| `assign` | `screen.user_roles` | People |
| `settings` | `screen.params` | Admin |
| `audit` | `screen.audit_log` | Admin |
| `import` | **`screen.import_clients`** | Admin |
| `period` | `screen.period_close` | Finance |
| `context` | `screen.context` | Executive |
| `report-list` | `screen.reports` | Executive |

Screens in **bold** ship with this pack (consulting-flavoured data); the rest
reuses the base CRM/services screens.

## Showcase form: Engagement card

`screen.engagement_form` demonstrates the rich field framework end to end:

- **Lookups (F2)**: client → `lookup.parties`, account → `lookup.accounts`,
  project → `lookup.projects`, manager → `lookup.consultants`. Click the F2
  button (or press F2) to open the searchable, paginated picker.
- **Validations**: required fields, regex patterns (`ENG-\d{4}`, ISO dates,
  e-mail), numeric ranges (`probability` 0–100, amounts ≥ 0), max length.
  Inline error marks; save is blocked until valid. Required fields hidden by a
  `when` are skipped.
- **Whens**: `retainerFee` / `autoRenew` / `renewalDate` only appear for
  `billingType == 'Retainer'`; `probability` only while `status == 'Draft'`;
  `endDate` is hidden for drafts and read-only once `Closed`; `renewalDate`
  is enabled only when `autoRenew` is checked.

The same props (`type:"lookup"`, `lookup`, `required`, `min`/`max`,
`minLength`/`maxLength`, `pattern`, `email`, `msg`, `when`, `enableWhen`) also
work in grid add/edit forms (`screen.engagements`, `screen.cons_invoices`) and
in the `screen.onboarding` wizard, and are preserved by the runtime form
designer (admin → Design form).

## New meta shipped with this pack

- Screens: `engagement_form`, `engagements`, `onboarding`, `exec_dashboard`,
  `cons_invoices`, `cons_quotes`, `cons_approvals`, `cons_agenda`,
  `import_clients`
- Data: `engagements`, `exec_kpis`, `cons_invoices`, `cons_invoice_lines`,
  `cons_quotes`, `cons_quote_lines`, `cons_approvals`, `cons_agenda`
- Lookups: `parties`, `projects`, `accounts`, `consultants`
- Report: `report.engagements` (visible under Executive → Reports)

All files live in the base `meta/` tree (shared with every vertical); only the
menu (`verticals/demo/modules.json`) is pack-specific.
