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
that level (`USE <table> VIA "RDDHDBC"`), so adding it is additive: no other
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
compile, compiles+links your connector, and links `hdbctools.lib`. Missing
either one → the script prints an `HDBC: not configured` note and builds
exactly as before.

In practice `hdbctools.lib` alone is not enough to link a working exe — the
underlying package also ships driver-specific pieces (e.g. a MariaDB
Connector/C wrapper lib) and needs the actual MariaDB Connector/C runtime
DLL reachable at run time. List whatever `.lib` names and `/LIBPATH`s your
own package needs via `HDBC_EXTRA_LIBS`; this was confirmed end-to-end
against a real local MariaDB, see the "Verified" note below.

Then set `meta/app.json -> "database"` either directly, or from
`http://<host>:2222/db-config.html` (any admin session) — a small page that
reads the current config via `GET /api/meta?key=app`, lets you edit
driver/host/port/dataPath/user/password, and saves it back with
`POST /api/meta` (same admin-only write path the runtime form designer
already uses). Reachable from a browser, from the web branch's `/portal/`
(companion PR #24), or, on the "PC" branch, by starting the exe with
`ZWEB_FRONT=db-config.html` — `Form1.prg`'s `ZWEB_FRONT` (see PR #24)
already accepts a bare `.html` file, not just a bundle folder, so this
loads directly inside the embedded WebView2:

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

Check `GET /api/db/status` (also shown on `db-config.html`) — `hdbcAvailable`
reflects whether the running exe was actually built with `HB_WITH_HDBC`.

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
  RDDHDBC's docs. Calling this also writes each dataset's `<name>.map.json`
  next to `./data` if it doesn't exist yet (same file `dbfcdx` relies on) —
  `ErpDbReadRows`/`ErpDbApply` need it to know the column<->field mapping
  once you actually switch `driver` to `"hdbc"`.
- **Record locking (`RLock`) is process-local**, not database-wide — it
  correctly serializes the concurrent threads of a *single*
  `FiveTech_ERP.exe`, the model this sample already uses, but does not
  protect against a second, separate process writing the same rows.
- Large tables: this integration does not configure or assume any
  windowed/paged fetch mode RDDHDBC may offer — validate with your own
  data volumes.
- Update this file (not `erp_db.prg`'s comments) if any of the above
  changes after you test against your own RDDHDBC version.

## Verified end-to-end (own local build, own local database)

This driver was built and exercised against a real MariaDB instance (own
licensed RDDHDBC package, not part of this repo) before opening this PR:
`GET /api/db/status` reporting `hdbcAvailable:true`; `GET /api/dataset`
returning real rows (UTF-8, accents intact) sourced from MariaDB, not the
JSON files; `POST /api/dataset` add/update/delete all round-tripped
correctly (verified independently with direct SQL). Two real bugs were
found and fixed in that process, both already reflected above:

1. The RDD's actual registered name is `"RDDHDBC"`, not `"HDBC"` — used in
   the `dbUseArea()` call. There is also no standalone `REQUEST` target for
   it: your `ErpDbHdbcUserConnect()` calling any of the RDD's own public
   functions (as the contract requires) already force-links its
   registration code, since both live in the same compiled module.
2. `ErpDbApply()`'s "delete not persisted" re-check (`Deleted()` right after
   `dbDelete()`) is an OpenADS-specific workaround that produced false
   negatives on hdbc — deletes were persisting correctly (`deleted_at` set)
   even though `Deleted()` on the just-modified record read back `.F.`
   before the next fetch. Now scoped to `driver == "openads"` only.
