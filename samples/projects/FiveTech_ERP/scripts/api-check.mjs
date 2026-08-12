// api-check.mjs — Evidencia de la rama 100% web: recorrido completo del contrato HTTP
// Uso: node scripts/api-check.mjs [baseUrl]   (default http://127.0.0.1:2222)
// Demuestra que TODO lo que hace el WebView de escritorio viaja por HTTP estándar:
// login (cookie HttpOnly) → contexto → menú (meta modules) → meta pantalla → dataset → CRUD.

const BASE = process.argv[2] || 'http://127.0.0.1:2222';
let cookie = '';
const results = [];
const t0 = Date.now();

function ok(name, detail, ms) { results.push({ name, ok: true, detail, ms }); console.log(`  OK  ${name.padEnd(38)} ${String(ms).padStart(5)} ms  ${detail}`); }
function fail(name, err) { results.push({ name, ok: false, detail: String(err) }); console.log(`FAIL  ${name.padEnd(38)}  ${err}`); }

async function req(method, path, body, kind = 'json') {
  const s = Date.now();
  const r = await fetch(BASE + path, {
    method,
    headers: {
      ...(body && kind === 'json' ? { 'Content-Type': 'application/json' } : {}),
      ...(body && kind === 'form' ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
      ...(cookie ? { Cookie: cookie } : {}),
    },
    body: body == null ? undefined : kind === 'json' ? JSON.stringify(body) : body,
  });
  const sc = r.headers.get('set-cookie');
  if (sc) cookie = sc.split(';')[0];
  const j = await r.json();
  return { r, j, ms: Date.now() - s };
}

// 1. Login — la sesión queda en cookie DWSESS (HttpOnly): nunca en el JS del cliente
try {
  const { j, ms } = await req('POST', '/api/login', { user: 'admin', password: '1234' });
  if (!j.ok) throw new Error(j.msg);
  ok('POST /api/login', `user=${j.user} empresa=${j.company} app=${j.app} cookie=${cookie.split('=')[0]}`, ms);
} catch (e) { fail('POST /api/login', e.message); }

// 2. Contexto multi-empresa / multi-app
try {
  const { j, ms } = await req('GET', '/api/context');
  if (!j.ok) throw new Error(j.msg);
  ok('GET /api/context', `empresas=${j.companies.length} apps=${j.apps.length} admin=${j.isAdmin}`, ms);
} catch (e) { fail('GET /api/context', e.message); }

// 3. Menú desde meta (modules) — el sidebar no está hardcodeado
try {
  const { j, ms } = await req('GET', '/api/meta?key=modules');
  if (!j.ok) throw new Error(j.msg);
  const secs = j.doc.sections || [];
  const items = secs.reduce((a, s) => a + (s.items?.length || 0), 0);
  ok('GET /api/meta?key=modules', `secciones=${secs.length} items=${items}`, ms);
} catch (e) { fail('GET /api/meta?key=modules', e.message); }

// 4. Meta de una pantalla list (contrato del renderer genérico)
try {
  const { j, ms } = await req('GET', '/api/meta?key=screen.products');
  if (!j.ok) throw new Error(j.msg);
  ok('GET /api/meta?key=screen.products', `layout=${j.doc.layout} dataRef=${j.doc.dataRef} cols=${j.doc.grid.columns.length}`, ms);
} catch (e) { fail('GET /api/meta?key=screen.products', e.message); }

// 5. Dataset (datos reales)
let rowCount = 0;
try {
  const { j, ms } = await req('GET', '/api/dataset?key=data.products');
  if (!j.ok) throw new Error(j.msg);
  rowCount = j.rows.length;
  ok('GET /api/dataset?key=data.products', `filas=${rowCount}`, ms);
} catch (e) { fail('GET /api/dataset?key=data.products', e.message); }

// 6. CRUD de ida y vuelta sobre fila scratch (se autolimpia)
const scratch = { code: 'ZZ-PROTO-1', name: 'Fila evidencia rama web', category: 'Gift', price: 1.5, active: true };
try {
  let { j, ms } = await req('POST', '/api/dataset', { key: 'data.products', action: 'add', row: scratch });
  if (!j.ok) throw new Error('add: ' + j.msg);
  const msAdd = ms;
  ({ j, ms } = await req('POST', '/api/dataset', { key: 'data.products', action: 'update', keyField: 'code', keyValue: scratch.code, row: { ...scratch, price: 2.5 } }));
  if (!j.ok) throw new Error('update: ' + j.msg);
  const { j: jv } = await req('GET', '/api/dataset?key=data.products');
  const row = jv.rows.find((r) => r.code === scratch.code);
  if (!row || row.price !== 2.5) throw new Error('verificación update falló');
  ({ j, ms } = await req('POST', '/api/dataset', { key: 'data.products', action: 'delete', keyField: 'code', keyValue: scratch.code }));
  if (!j.ok) throw new Error('delete: ' + j.msg);
  ok('POST /api/dataset CRUD add→update→delete', `add=${msAdd}ms · verificado price=2.5 · delete ok`, ms);
} catch (e) { fail('POST /api/dataset CRUD', e.message); }

// 7. Logout
try {
  const { j, ms } = await req('POST', '/api/cmd', 'action=logout', 'form');
  if (!j.ok) throw new Error(j.msg);
  ok('POST /api/cmd action=logout', 'sesión cerrada', ms);
} catch (e) { fail('POST /api/cmd logout', e.message); }

// 8. Sin cookie → API rechaza (la seguridad vive en el servidor)
try {
  cookie = '';
  const { j, ms } = await req('GET', '/api/dataset?key=data.products');
  if (j.ok) throw new Error('¡debió rechazar sin sesión!');
  ok('GET /api/dataset sin sesión', `rechazado: "${j.msg}"`, ms);
} catch (e) { fail('control sin sesión', e.message); }

const fails = results.filter((r) => !r.ok).length;
console.log(`\n${fails === 0 ? 'CONTRATO COMPLETO VALIDADO' : 'FALLAS: ' + fails} · ${results.length} pruebas · ${Date.now() - t0} ms totales · base=${BASE}`);
process.exit(fails === 0 ? 0 : 1);
