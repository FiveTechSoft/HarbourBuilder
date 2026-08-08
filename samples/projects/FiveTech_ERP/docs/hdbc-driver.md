# Optional `hdbc` data driver (RDDHDBC over MariaDB)

`erp_db.prg` already supports a pluggable data layer selected by
`meta/app.json -> "database" -> "driver"`: `json` (default), `dbfcdx`,
`openads`. This adds a fourth option, `hdbc`, backed by **RDDHDBC** — a
third-party Harbour RDD (by Manu Expósito) that maps standard xBase RDD
calls onto MariaDB.

## What this repo ships, and what it does not

This repo ships only:

- a fourth branch in `ErpDbConfig`/`ErpDbOpen`/`ErpDbStatus` in `erp_db.prg`,
  compiled in only when the build defines `HB_WITH_HDBC`;
- the matching, equally opt-in wiring in `build_win64.bat`.

It does **not** ship, link, vendor, or reference any RDDHDBC/HDBC source,
binary, or API name. RDDHDBC is Manu Expósito's own commercial, licensed
product — obtaining and using it is between you and him, same as MariaDB
itself. A build of this sample that doesn't configure HDBC (the default) is
byte-for-byte what it is today; `hdbc` simply isn't a selectable driver.

## Why an RDD, not raw SQL

`erp_db.prg`'s existing drivers (`dbfcdx`, `openads`) already talk to their
backend exclusively through standard RDD verbs — `dbUseArea`, `dbGoTop`,
`dbSkip`, `FieldGet`, `dbAppend`, `RLock`, `FieldPut`, `dbDelete`,
`dbCommit`, `dbCreate` — never hand-built SQL. RDDHDBC operates at exactly
that level (`USE <table> VIA "HDBC"`), so adding it is additive: no other
file changes, and `ErpDbReadRows`/`ErpDbApply`/`erp_http.prg`'s dispatch
(`if ErpDbDriver() != "json" ...`) work unmodified.

## How to enable it (you provide two things)

1. **`hdbctools.lib`** — your own licensed RDDHDBC build, placed in the same
   `%HBLIB%` directory as the rest of your Harbour libs.
2. **A connector `.prg`** implementing one function:

   ```harbour
   // your own file, NOT part of this repo
   function ErpDbHdbcUserConnect( hCfg )
      // hCfg = the "database" hash from app.json: driver/backend/host/port/
      // dataPath (used as the DB name for this driver)/user/password.
      // Build a connection with your licensed HDBC package and register it
      // with the RDD via ITS OWN public entry point (documented by
      // RDDHDBC, not reproduced here). Return .T. once ready, .F. to fail
      // the open cleanly.
   return .T.
   ```

   Point `build_win64.bat` at it via `HDBC_CONNECT_PRG=C:\path\to\your_file.prg`.

With both present, `build_win64.bat` adds `-dHB_WITH_HDBC` to the `erp_db.prg`
compile, compiles+links your connector, and links `hdbctools.lib` (plus
anything you list in `HDBC_EXTRA_LIBS`). Missing either one → the script
prints an `HDBC: not configured` note and builds exactly as before.

Then, in `meta/app.json`:

```json
"database": {
   "driver": "hdbc",
   "host": "127.0.0.1",
   "port": 3306,
   "dataPath": "your_db_name",
   "user": "...",
   "password": "..."
}
```

Check `GET /api/db/status` — `hdbcAvailable` reflects whether the running
exe was actually built with `HB_WITH_HDBC`.

## Known limits (verify before relying on this in production)

- **Tables are not auto-created against a live connection** — by design;
  `ErpDbEnsureTables()` treats `hdbc` like a SQL backend and does nothing
  automatically. What this repo *does* provide is `GET /api/db/schema-sql`
  (any authenticated session), which returns `CREATE TABLE IF NOT EXISTS`
  DDL for every `data.*` dataset — inferred from `meta/data/*.json` with the
  same logic `ErpDbInferSchema()` already uses for `dbfcdx`, plus the
  `_h_rowid_`/`deleted_at` bookkeeping columns RDDHDBC tables need. It only
  ever generates text (`ErpDbHdbcSchemaSql()` in `erp_db.prg`, no HDBC
  dependency at all) — review it, then run it yourself, e.g.
  `curl -b cookies.txt http://127.0.0.1:2222/api/db/schema-sql > schema.sql && mysql -u ... < schema.sql`.
  RDDHDBC's own index-metadata table is **not** included — provision it per
  RDDHDBC's docs.
- **Record locking (`RLock`) is process-local**, not database-wide — it
  correctly serializes the concurrent threads of a *single*
  `FiveTech_ERP.exe`, the model this sample already uses, but does not
  protect against a second, separate process writing the same rows.
- Large tables: this integration does not configure or assume any
  windowed/paged fetch mode RDDHDBC may offer — validate with your own
  data volumes.
- Update this file (not `erp_db.prg`'s comments) if any of the above
  changes after you test against your own RDDHDBC version.
