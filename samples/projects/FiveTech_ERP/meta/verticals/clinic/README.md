# Vertical pack: clinic

Loaded when `app.vertical` is `"clinic"` in `meta/app.json`.

- Overrides sidebar `modules` with clinic-oriented labels and grouping.
- CRM core remains generic (`data.parties`, `data.activities`, …).
- Clinic screens map onto the same parties where useful (`screen.patients` can use party codes).

To switch vertical: set `"vertical": "clinic"` (or another pack folder under `verticals/`) and restart.
