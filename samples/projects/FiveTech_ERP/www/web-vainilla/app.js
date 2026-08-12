// Rama 100% web — frontend vainilla (sin framework)
// Consume el mismo contrato HTTP que el WebView de escritorio:
//   POST /api/login · GET /api/context · GET /api/meta · GET/POST /api/dataset · POST /api/cmd
// La sesión viaja en la cookie HttpOnly DWSESS que fija el servidor (nunca en JS).

const $ = (id) => document.getElementById(id);
const api = {
  async req(method, url, body) {
    const opt = { method, headers: {} };
    if (body !== undefined) {
      opt.headers['Content-Type'] = 'application/json';
      opt.body = JSON.stringify(body);
    }
    const r = await fetch(url, opt);
    const j = await r.json().catch(() => ({ ok: false, msg: 'Respuesta no JSON (' + r.status + ')' }));
    if (j && j.ok === false && j.msg === 'Not authenticated') { showLogin(); throw new Error('Sesión terminada'); }
    return j;
  },
  login: (user, password, workDate) => api.req('POST', '/api/login', { user, password, workDate }),
  context: () => api.req('GET', '/api/context'),
  meta: (key) => api.req('GET', '/api/meta?key=' + encodeURIComponent(key)),
  modules: () => api.req('GET', '/api/meta?key=modules'),
  dataset: (key) => api.req('GET', '/api/dataset?key=' + encodeURIComponent(key)),
  datasetPost: (body) => api.req('POST', '/api/dataset', body),
  processGet: () => api.req('GET', '/api/process'),
  processPost: (body) => api.req('POST', '/api/process', body),
  cmd: (action, a1, a2) => {
    const p = new URLSearchParams({ action });
    if (a1 !== undefined) p.set('a1', a1);
    if (a2 !== undefined) p.set('a2', a2);
    return fetch('/api/cmd', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: p.toString(),
    }).then((r) => r.json());
  },
};

let ctx = null;
let currentScreen = null;

function showLogin() {
  $('view-login').classList.remove('hidden');
  $('view-app').classList.add('hidden');
}
function showApp() {
  $('view-login').classList.add('hidden');
  $('view-app').classList.remove('hidden');
}

// ---------------------------------------------------------------- tema claro/oscuro (paridad FWH)
function applyTheme(t) {
  t = t === 'light' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', t);
  document.documentElement.classList.toggle('light', t === 'light');
  try { localStorage.setItem('dw-theme', t); } catch (e) {}
  document.querySelectorAll('.theme-fab').forEach((b) => { b.textContent = t === 'dark' ? 'Dark' : 'Light'; });
}
function toggleTheme() {
  applyTheme(document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark');
}
applyTheme((() => { try { return localStorage.getItem('dw-theme') || 'dark'; } catch (e) { return 'dark'; } })());

// ---------------------------------------------------------------- login
$('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('login-error').textContent = '';
  $('login-btn').disabled = true;
  try {
    const j = await api.login($('login-user').value.trim(), $('login-pass').value, $('login-date').value);
    if (!j.ok) { $('login-error').textContent = j.msg || 'Credenciales inválidas'; return; }
    ctx = await api.context();
    await enterApp();
  } catch (err) {
    $('login-error').textContent = err.message;
  } finally {
    $('login-btn').disabled = false;
  }
});

$('btn-logout').addEventListener('click', async () => {
  await api.cmd('logout');
  ctx = null;
  showLogin();
});

// ---------------------------------------------------------------- shell
async function enterApp() {
  showApp();
  $('rama-tag').textContent = 'rama ' + (window.__RAMA__ ? window.__RAMA__.branch : 'web') + ' · vainilla';
  $('user-chip').textContent = ctx.company + ' · ' + (ctx.appLabel || ctx.app) + ' · ' + (ctx.isAdmin ? 'admin' : 'usuario');
  const mApp = await api.meta('app');
  if (mApp.ok && mApp.doc.version) $('user-chip').textContent += ' · v' + mApp.doc.version;
  $('workdate').value = $('login-date').value || new Date().toISOString().slice(0, 10);
  $('btn-theme-top').onclick = toggleTheme;
  applyTheme(document.documentElement.getAttribute('data-theme'));
  initSidebarChrome();
  fillSelectors();
  const m = await api.modules();
  renderSidebar(m.ok ? m.doc : { sections: [] });
  const first = firstScreen(m.ok ? m.doc : null);
  if (first) openScreen(first);
}

function goDashboard() {
  // Shell HTTP FWH (misma cookie DWSESS) — dashboards/KPI/agenda
  location.href = '/dashboard.html';
}

function initSidebarChrome() {
  const body = $('app-body');
  const btn = $('btn-sidebar');
  const dash = $('btn-dashboard');
  if (dash) dash.onclick = goDashboard;
  if (!body || !btn) return;
  let collapsed = false;
  try { collapsed = localStorage.getItem('dw-sidebar') === '1'; } catch (e) {}
  function apply() {
    body.classList.toggle('sidebar-collapsed', collapsed);
    btn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
    btn.title = collapsed ? 'Mostrar menú' : 'Ocultar menú';
    try { localStorage.setItem('dw-sidebar', collapsed ? '1' : '0'); } catch (e) {}
  }
  btn.onclick = () => { collapsed = !collapsed; apply(); };
  apply();
}

$('workdate')?.addEventListener?.('change', async (e) => {
  await api.cmd('workdate', e.target.value);
});

function fillSelectors() {
  const sc = $('sel-company');
  sc.innerHTML = '';
  (ctx.companies || []).forEach((c) => {
    const o = document.createElement('option');
    o.value = c.code; o.textContent = c.name || c.code;
    if (c.code === ctx.company) o.selected = true;
    sc.appendChild(o);
  });
  sc.disabled = ctx.canSwitchCompany === false;
  sc.onchange = async () => {
    const j = await api.cmd('company', sc.value);
    if (j.ok) { ctx = await api.context(); enterApp(); }
  };

  const sa = $('sel-app');
  sa.innerHTML = '';
  (ctx.apps || []).forEach((a) => {
    const o = document.createElement('option');
    o.value = a.id; o.textContent = a.label || a.id;
    if (a.id === ctx.app) o.selected = true;
    sa.appendChild(o);
  });
  sa.disabled = ctx.canSwitchApp === false;
  sa.onchange = async () => {
    const j = await api.cmd('app', sa.value);
    if (j.ok) { ctx = await api.context(); enterApp(); }
  };
}

function renderSidebar(mod) {
  const nav = $('sidebar');
  nav.innerHTML = '';

  // Accesos fijos
  const pin = document.createElement('div');
  pin.className = 'nav-pin';
  const bd = document.createElement('button');
  bd.type = 'button';
  bd.className = 'nav-item dash';
  bd.textContent = '⊞ Dashboard';
  bd.title = 'Shell FWH · dashboard.html';
  bd.onclick = goDashboard;
  pin.appendChild(bd);
  nav.appendChild(pin);

  function makeSection(title, itemsBuild, secId) {
    let collapsed = false;
    try {
      const raw = localStorage.getItem('dw-nav-sec');
      const map = raw ? JSON.parse(raw) : {};
      if (map[secId]) collapsed = true;
    } catch (e) {}
    const group = document.createElement('div');
    group.className = 'nav-group' + (collapsed ? ' collapsed' : '');
    group.dataset.sec = secId;
    const h = document.createElement('button');
    h.type = 'button';
    h.className = 'nav-section';
    h.innerHTML = '<span>' + esc(title) + '</span><span class="chev">▼</span>';
    h.onclick = () => {
      group.classList.toggle('collapsed');
      try {
        const raw = localStorage.getItem('dw-nav-sec');
        const map = raw ? JSON.parse(raw) : {};
        map[secId] = group.classList.contains('collapsed');
        localStorage.setItem('dw-nav-sec', JSON.stringify(map));
      } catch (e) {}
    };
    const body = document.createElement('div');
    body.className = 'nav-group-body';
    itemsBuild(body);
    group.appendChild(h);
    group.appendChild(body);
    nav.appendChild(group);
  }

  (mod.sections || []).forEach((sec, si) => {
    makeSection(sec.title || ('Sección ' + (si + 1)), (body) => {
      (sec.items || []).forEach((it) => {
        if (!it.screen) return;
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'nav-item' + (it.sub ? ' sub' : '');
        b.textContent = it.label;
        b.onclick = () => {
          nav.querySelectorAll('.nav-item').forEach((x) => x.classList.remove('active'));
          b.classList.add('active');
          openScreen(it.screen);
        };
        body.appendChild(b);
      });
    }, sec.id || ('s' + si));
  });

  // Paridad FWH: herramientas del servidor (procesos declarados en meta)
  makeSection('Herramientas', (body) => {
    const bp = document.createElement('button');
    bp.type = 'button';
    bp.className = 'nav-item';
    bp.textContent = 'Procesos';
    bp.onclick = () => {
      nav.querySelectorAll('.nav-item').forEach((x) => x.classList.remove('active'));
      bp.classList.add('active');
      renderProcesses();
    };
    body.appendChild(bp);
  }, '__tools');
}

function firstScreen(mod) {
  if (!mod) return null;
  for (const sec of mod.sections || [])
    for (const it of sec.items || [])
      if (it.screen && !it.sub) return it.screen;
  return null;
}

// ---------------------------------------------------------------- helpers paridad toolbar HTTP (FWH)
function isMasterDetail(doc) {
  return !!(doc && (doc.layout === 'master-detail' || doc.layout === 'document') &&
    doc.detail && doc.detail.dataRef);
}
function isFormScreen(doc) {
  return !!(doc && doc.layout === 'form' && Array.isArray(doc.fields) && doc.fields.length);
}
function isListScreen(doc) {
  if (!doc || isMasterDetail(doc) || isFormScreen(doc)) return false;
  return !!(doc.layout === 'list' || (doc.dataRef && doc.grid && (doc.grid.columns || []).length));
}
function toolbarIds(doc) {
  const t = doc && doc.toolbar;
  if (Array.isArray(t) && t.length)
    return t.map((x) => (typeof x === 'string' ? x : (x && x.id) || '')).filter(Boolean);
  return ['add', 'edit', 'delete', 'refresh'];
}
function hasTb(doc, id) { return toolbarIds(doc).includes(id); }
function isMoneyCol(c) { return c && (c.type === 'money' || c.format === 'money'); }
function keyFieldOf(doc) {
  return (doc && doc.keyField) || (doc.grid && doc.grid.columns && doc.grid.columns[0] && doc.grid.columns[0].id) || 'code';
}
function csvCell(v) {
  const s = v == null ? '' : String(v);
  if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
  return s;
}
function exportCsv(title, cols, rows) {
  const crlf = '\r\n';
  const lines = [cols.map((c) => csvCell(c.label || c.id)).join(',')];
  rows.forEach((r) => lines.push(cols.map((c) => csvCell(r[c.id])).join(',')));
  const blob = new Blob(['\ufeff' + lines.join(crlf)], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = String(title || 'export').replace(/[^A-Za-z0-9_\-]+/g, '_') + '.csv';
  a.click();
  URL.revokeObjectURL(a.href);
}
function printGrid(title, cols, rows, fmt) {
  const w = window.open('', '_blank');
  if (!w) { window.print(); return; }
  const th = cols.map((c) => '<th>' + esc(c.label) + '</th>').join('');
  const body = rows.map((r) => '<tr>' + cols.map((c) => '<td>' + esc(fmt(r[c.id], c)) + '</td>').join('') + '</tr>').join('');
  w.document.write('<!doctype html><html><head><title>' + esc(title) + '</title>' +
    '<style>body{font:12px Segoe UI,sans-serif}table{border-collapse:collapse;width:100%}' +
    'th,td{border:1px solid #ccc;padding:4px 6px;text-align:left}th{background:#eee}</style></head><body>' +
    '<h2>' + esc(title) + '</h2><table><thead><tr>' + th + '</tr></thead><tbody>' + body +
    '</tbody></table><script>onload=function(){print();}</script></body></html>');
  w.document.close();
}

// ---------------------------------------------------------------- renderer de pantallas
async function openScreen(screenKey) {
  const main = $('main');
  main.innerHTML = '<div class="loading">Cargando ' + screenKey + '…</div>';
  const m = await api.meta(screenKey);
  if (!m.ok) { main.innerHTML = '<div class="empty">Meta no disponible: ' + screenKey + '</div>'; return; }
  const doc = m.doc;
  currentScreen = doc;
  if (isMasterDetail(doc)) return renderMasterDetail(doc);
  if (isFormScreen(doc)) return renderForm(doc);
  // Paridad HTTP: grilla con dataRef = lista CRUD (aunque layout no diga "list")
  if (isListScreen(doc)) return renderList(doc);
  return renderGeneric(doc);
}

async function loadLookupOptions(lookupKey) {
  try {
    const m = await api.meta(lookupKey);
    if (!m.ok || !m.doc) return [];
    const vf = m.doc.valueField || 'code';
    const lf = m.doc.labelField || 'name';
    const dref = m.doc.dataRef;
    if (!dref) return [];
    const d = await api.dataset(dref);
    if (!d.ok) return [];
    return (d.rows || []).map((r) => ({ value: r[vf], label: (r[lf] != null ? r[lf] : r[vf]) + '' }));
  } catch (e) { return []; }
}

function fieldControlHtml(f, val, isNew, kf) {
  const id = f.id;
  const label = '<label>' + esc(f.label || id) + (f.required ? ' *' : '') + '</label>';
  const v = val == null ? (f.default != null ? f.default : '') : val;
  if (f.type === 'checkbox')
    return '<div class="field chk">' + label + '<input type="checkbox" data-f="' + id + '"' + (v ? ' checked' : '') + '></div>';
  if (f.type === 'checklist') {
    const arr = Array.isArray(v) ? v : (v ? String(v).split(/[,;]/).map((s) => s.trim()) : []);
    return '<div class="field">' + label + '<div class="checklist" data-f="' + id + '">' +
      (f.options || []).map((o) =>
        '<label class="chk-item"><input type="checkbox" value="' + esc(o) + '"' +
        (arr.includes(o) ? ' checked' : '') + '> ' + esc(o) + '</label>').join('') +
      '</div></div>';
  }
  if (f.type === 'select')
    return '<div class="field">' + label + '<select data-f="' + id + '">' +
      '<option value=""></option>' +
      (f.options || []).map((o) => '<option' + (String(o) === String(v) ? ' selected' : '') + '>' + esc(o) + '</option>').join('') +
      '</select></div>';
  if (f.type === 'lookup')
    return '<div class="field">' + label + '<select data-f="' + id + '" data-lookup="' + esc(f.lookup || '') + '">' +
      '<option value="' + esc(String(v)) + '">' + esc(String(v)) + '</option></select></div>';
  if (isMoneyCol(f))
    return '<div class="field">' + label + '<input type="number" step="0.01" data-f="' + id + '" value="' + esc(String(v)) + '"></div>';
  const ro = (!isNew && kf === id) ? ' readonly class="ro"' : '';
  return '<div class="field">' + label + '<input data-f="' + id + '" value="' + esc(String(v)) + '"' + ro + '></div>';
}

function readFormFields(host, fields) {
  const out = {};
  fields.forEach((f) => {
    if (f.type === 'checklist') {
      const box = host.querySelector('.checklist[data-f="' + f.id + '"]');
      out[f.id] = box ? Array.from(box.querySelectorAll('input:checked')).map((i) => i.value) : [];
      return;
    }
    const el = host.querySelector('[data-f="' + f.id + '"]');
    if (!el) return;
    if (f.type === 'checkbox') out[f.id] = el.checked;
    else if (isMoneyCol(f)) out[f.id] = el.value === '' ? null : Number(el.value);
    else out[f.id] = el.value;
  });
  return out;
}

async function fillLookups(host, fields) {
  for (const f of fields) {
    if (f.type !== 'lookup' || !f.lookup) continue;
    const sel = host.querySelector('select[data-f="' + f.id + '"]');
    if (!sel) continue;
    const cur = sel.value;
    const opts = await loadLookupOptions(f.lookup);
    sel.innerHTML = '<option value=""></option>' +
      opts.map((o) => '<option value="' + esc(o.value) + '"' +
        (String(o.value) === String(cur) ? ' selected' : '') + '>' +
        esc(o.label) + ' (' + esc(o.value) + ')</option>').join('');
    if (cur && !opts.some((o) => String(o.value) === String(cur))) {
      const o = document.createElement('option');
      o.value = cur; o.textContent = cur; o.selected = true;
      sel.appendChild(o);
    }
  }
}

// ---------- FORM (paridad layout form FWH) ----------
async function renderForm(doc) {
  const main = $('main');
  const key = doc.dataRef;
  const kf = keyFieldOf(doc);
  const fields = doc.fields || [];
  const tabs = doc.tabs || [{ id: 'all', label: 'Datos', fields: fields.map((f) => f.id) }];
  const j = await api.dataset(key);
  const rows = j.ok ? (j.rows || []) : [];
  let idx = 0;
  let isNew = false;
  let draft = rows[0] ? { ...rows[0] } : {};

  const labelOf = (r) => {
    if (!r) return '—';
    const n = r.name || r.title || r.label;
    return (r[kf] != null ? r[kf] : '') + (n ? ' · ' + n : '');
  };

  function paintShell() {
    main.innerHTML =
      '<div class="screen-head"><h2>' + esc(doc.title || doc.id) + '</h2>' +
      '<span class="layout-tag">layout: form</span>' +
      '<div class="toolbar" id="form-tb">' +
        (hasTb(doc, 'add') ? '<button class="btn primary" data-act="add">+ Nuevo</button>' : '') +
        (hasTb(doc, 'edit') || hasTb(doc, 'add') ? '<button class="btn primary" data-act="save">Guardar</button>' : '') +
        (hasTb(doc, 'delete') ? '<button class="btn danger" data-act="del">Eliminar</button>' : '') +
        (hasTb(doc, 'refresh') ? '<button class="btn" data-act="ref">Refrescar</button>' : '') +
        '<span class="rowcount" id="form-pos"></span>' +
      '</div></div>' +
      '<div class="form-layout">' +
        '<aside class="form-nav"><div class="form-nav-title">Registros</div><div id="form-nav-list"></div></aside>' +
        '<div class="form-main">' +
          '<div class="form-tabs" id="form-tabs"></div>' +
          '<div class="form form-body" id="form-body"></div>' +
        '</div>' +
      '</div>';

    const nav = $('form-nav-list');
    nav.innerHTML = rows.map((r, i) =>
      '<button type="button" class="form-nav-item' + (i === idx && !isNew ? ' active' : '') +
      '" data-i="' + i + '">' + esc(labelOf(r)) + '</button>').join('') ||
      '<div class="empty" style="padding:12px">Sin registros</div>';
    nav.querySelectorAll('[data-i]').forEach((b) => {
      b.onclick = () => {
        isNew = false;
        idx = Number(b.dataset.i);
        draft = { ...rows[idx] };
        paintShell();
      };
    });

    const tabHost = $('form-tabs');
    let activeTab = tabs[0]?.id || 'all';
    tabHost.innerHTML = tabs.map((t, i) =>
      '<button type="button" class="form-tab' + (i === 0 ? ' active' : '') + '" data-tab="' + esc(t.id) + '">' +
      esc(t.label || t.id) + '</button>').join('');

    function fieldsOfTab(tid) {
      const tab = tabs.find((t) => t.id === tid) || tabs[0];
      const ids = tab.fields || [];
      return fields.filter((f) => ids.includes(f.id));
    }
    function showTab(tid) {
      // conservar valores de la pestaña actual antes de cambiar
      const bodyPrev = $('form-body');
      if (bodyPrev) Object.assign(draft, readFormFields(bodyPrev, fieldsOfTab(activeTab)));
      activeTab = tid;
      tabHost.querySelectorAll('.form-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === tid));
      const fl = fieldsOfTab(tid);
      const body = $('form-body');
      body.innerHTML = fl.map((f) => fieldControlHtml(f, draft[f.id], isNew, kf)).join('') ||
        '<div class="empty">Sin campos en esta pestaña</div>';
      fillLookups(body, fl);
    }
    tabHost.querySelectorAll('.form-tab').forEach((b) => {
      b.onclick = () => showTab(b.dataset.tab);
    });
    showTab(activeTab);

    $('form-pos').textContent = isNew ? 'Nuevo registro' : ((rows.length ? (idx + 1) : 0) + ' / ' + rows.length);
    const tb = $('form-tb');
    tb.querySelector('[data-act="add"]')?.addEventListener('click', () => {
      isNew = true;
      draft = {};
      fields.forEach((f) => { if (f.default != null) draft[f.id] = f.default; });
      paintShell();
    });
    tb.querySelector('[data-act="ref"]')?.addEventListener('click', () => openScreen(doc.id));
    tb.querySelector('[data-act="del"]')?.addEventListener('click', async () => {
      if (isNew || !rows[idx]) return;
      if (!confirm('¿Eliminar ' + rows[idx][kf] + '?')) return;
      const r = await api.datasetPost({ key, action: 'delete', keyField: kf, keyValue: rows[idx][kf] });
      if (!r.ok) alert(r.msg || 'Error');
      openScreen(doc.id);
    });
    tb.querySelector('[data-act="save"]')?.addEventListener('click', async () => {
      const bodyEl = $('form-body');
      Object.assign(draft, readFormFields(bodyEl, fieldsOfTab(activeTab)));
      const out = { ...draft };
      const body = isNew
        ? { key, action: 'add', row: out }
        : { key, action: 'update', keyField: kf, keyValue: String(rows[idx][kf]), row: out };
      const r = await api.datasetPost(body);
      if (!r.ok) { alert(r.msg || 'Error al guardar'); return; }
      openScreen(doc.id);
    });
  }
  paintShell();
}

// ---------- MASTER-DETAIL / document ----------
async function renderMasterDetail(doc) {
  const main = $('main');
  const mKey = doc.dataRef;
  const mKf = keyFieldOf(doc);
  const cols = (doc.grid && doc.grid.columns) || [];
  const det = doc.detail || {};
  const dKey = det.dataRef;
  const dKf = det.keyField || 'code';
  const dCols = (det.grid && det.grid.columns) || [];
  const masterFk = det.masterKey || mKf;

  const [jm, jd] = await Promise.all([api.dataset(mKey), api.dataset(dKey)]);
  const masters = jm.ok ? (jm.rows || []) : [];
  const allDetails = jd.ok ? (jd.rows || []) : [];
  let sel = masters[0] || null;
  let selDet = null;

  const fmt = (v, c) => {
    if (isMoneyCol(c)) return v == null || v === '' ? '' : Number(v).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (c.type === 'checkbox') return v ? '✔' : '';
    return v == null ? '' : String(v);
  };

  function detailsOf(m) {
    if (!m) return [];
    const mk = m[mKf];
    return allDetails.filter((r) => String(r[masterFk]) === String(mk));
  }

  function paint() {
    const detRows = detailsOf(sel);
    const tbM = toolbarIds(doc);
    const tbD = Array.isArray(det.toolbar) ? det.toolbar : ['add', 'edit', 'delete', 'refresh'];
    const hasM = (id) => tbM.includes(id);
    const hasD = (id) => tbD.includes(id);

    main.innerHTML =
      '<div class="screen-head"><h2>' + esc(doc.title || doc.id) + '</h2>' +
      '<span class="layout-tag">layout: ' + esc(doc.layout) + '</span></div>' +
      '<div class="md-layout">' +
        '<section class="md-master">' +
          '<div class="md-head"><b>Maestro</b>' +
            '<div class="toolbar">' +
              (hasM('add') ? '<button class="btn primary" data-m="add">+ Nuevo</button>' : '') +
              (hasM('edit') ? '<button class="btn" data-m="edit" ' + (!sel ? 'disabled' : '') + '>Editar</button>' : '') +
              (hasM('delete') ? '<button class="btn danger" data-m="del" ' + (!sel ? 'disabled' : '') + '>Eliminar</button>' : '') +
              (hasM('excel') ? '<button class="btn" data-m="excel">Excel</button>' : '') +
              (hasM('print') || hasM('pdf') ? '<button class="btn" data-m="print">Imprimir</button>' : '') +
              (hasM('refresh') ? '<button class="btn" data-m="ref">Refrescar</button>' : '') +
              '<input id="md-q" class="search" placeholder="Buscar…">' +
              '<span class="rowcount" id="md-count"></span>' +
            '</div></div>' +
          '<div class="grid-wrap"><table id="md-master"><thead><tr>' +
            cols.map((c) => '<th' + (c.align === 'right' || isMoneyCol(c) ? ' class="right"' : '') + '>' + esc(c.label) + '</th>').join('') +
          '</tr></thead><tbody></tbody></table></div>' +
        '</section>' +
        '<section class="md-detail">' +
          '<div class="md-head"><b>' + esc(det.title || 'Detalle') + '</b>' +
            '<div class="toolbar">' +
              (hasD('add') ? '<button class="btn primary" data-d="add" ' + (!sel ? 'disabled' : '') + '>+ Línea</button>' : '') +
              (hasD('edit') ? '<button class="btn" data-d="edit" disabled>Editar</button>' : '') +
              (hasD('delete') ? '<button class="btn danger" data-d="del" disabled>Eliminar</button>' : '') +
              (hasD('refresh') ? '<button class="btn" data-d="ref">Refrescar</button>' : '') +
              '<span class="rowcount" id="md-dcount"></span>' +
            '</div></div>' +
          '<div class="grid-wrap"><table id="md-detail"><thead><tr>' +
            dCols.map((c) => '<th' + (c.align === 'right' || isMoneyCol(c) ? ' class="right"' : '') + '>' + esc(c.label) + '</th>').join('') +
          '</tr></thead><tbody></tbody></table></div>' +
        '</section>' +
      '</div>';

    let q = '';
    function paintMaster() {
      const tbody = main.querySelector('#md-master tbody');
      tbody.innerHTML = '';
      const f = q.toLowerCase();
      const vis = masters.filter((r) => !f || (doc.searchFields || cols.map((c) => c.id))
        .some((fld) => String(r[fld] ?? '').toLowerCase().includes(f)));
      vis.forEach((r) => {
        const tr = document.createElement('tr');
        if (sel && String(r[mKf]) === String(sel[mKf])) tr.classList.add('sel');
        cols.forEach((c) => {
          const td = document.createElement('td');
          if (c.align === 'right' || isMoneyCol(c)) td.className = 'right';
          td.textContent = fmt(r[c.id], c);
          tr.appendChild(td);
        });
        tr.onclick = () => { sel = r; selDet = null; paint(); };
        tr.ondblclick = () => editMaster(r);
        tbody.appendChild(tr);
      });
      $('md-count').textContent = vis.length + ' / ' + masters.length;
    }

    function paintDetail() {
      const tbody = main.querySelector('#md-detail tbody');
      tbody.innerHTML = '';
      const rows = detailsOf(sel);
      rows.forEach((r) => {
        const tr = document.createElement('tr');
        if (selDet && String(r[dKf]) === String(selDet[dKf])) tr.classList.add('sel');
        dCols.forEach((c) => {
          const td = document.createElement('td');
          if (c.align === 'right' || isMoneyCol(c)) td.className = 'right';
          td.textContent = fmt(r[c.id], c);
          tr.appendChild(td);
        });
        tr.onclick = () => {
          selDet = r;
          tbody.querySelectorAll('tr').forEach((x) => x.classList.remove('sel'));
          tr.classList.add('sel');
          const be = main.querySelector('[data-d="edit"]');
          const bd = main.querySelector('[data-d="del"]');
          if (be) be.disabled = false;
          if (bd) bd.disabled = false;
        };
        tr.ondblclick = () => editDetail(r);
        tbody.appendChild(tr);
      });
      $('md-dcount').textContent = rows.length + ' líneas';
    }

    function editMaster(row) {
      openEditModal(doc, cols, mKey, mKf, row, () => openScreen(doc.id));
    }
    function editDetail(row) {
      const isNew = !row;
      const base = row ? { ...row } : {};
      if (isNew && sel) base[masterFk] = sel[mKf];
      openEditModal(
        { ...det, keyField: dKf, title: det.title || 'Detalle' },
        dCols, dKey, dKf, isNew ? null : row, () => openScreen(doc.id), base
      );
    }

    $('md-q').oninput = (e) => { q = e.target.value; paintMaster(); };
    main.querySelector('[data-m="ref"]')?.addEventListener('click', () => openScreen(doc.id));
    main.querySelector('[data-m="add"]')?.addEventListener('click', () => editMaster(null));
    main.querySelector('[data-m="edit"]')?.addEventListener('click', () => sel && editMaster(sel));
    main.querySelector('[data-m="del"]')?.addEventListener('click', async () => {
      if (!sel) return;
      if (!confirm('¿Eliminar ' + sel[mKf] + '?')) return;
      const r = await api.datasetPost({ key: mKey, action: 'delete', keyField: mKf, keyValue: sel[mKf] });
      if (!r.ok) alert(r.msg || 'Error');
      openScreen(doc.id);
    });
    main.querySelector('[data-m="excel"]')?.addEventListener('click', () => exportCsv(doc.title, cols, masters));
    main.querySelector('[data-m="print"]')?.addEventListener('click', () => printGrid(doc.title, cols, masters, fmt));
    main.querySelector('[data-d="ref"]')?.addEventListener('click', () => openScreen(doc.id));
    main.querySelector('[data-d="add"]')?.addEventListener('click', () => sel && editDetail(null));
    main.querySelector('[data-d="edit"]')?.addEventListener('click', () => selDet && editDetail(selDet));
    main.querySelector('[data-d="del"]')?.addEventListener('click', async () => {
      if (!selDet) return;
      if (!confirm('¿Eliminar línea ' + selDet[dKf] + '?')) return;
      const r = await api.datasetPost({ key: dKey, action: 'delete', keyField: dKf, keyValue: selDet[dKf] });
      if (!r.ok) alert(r.msg || 'Error');
      openScreen(doc.id);
    });

    paintMaster();
    paintDetail();
  }
  paint();
}

function openEditModal(docLike, cols, dataKey, kf, row, onDone, seed) {
  const isNew = !row;
  const vals = row ? { ...row } : { ...(seed || {}) };
  const overlay = document.createElement('div');
  overlay.className = 'overlay';
  overlay.innerHTML =
    '<div class="modal">' +
      '<h3>' + (isNew ? 'Nuevo' : 'Editar ' + esc(String(vals[kf] ?? ''))) + ' — ' + esc(docLike.title || '') + '</h3>' +
      '<div class="form">' + cols.map((c) => fieldHtml(c, vals[c.id], isNew, kf)).join('') + '</div>' +
      '<div class="modal-actions">' +
        '<button class="btn" data-x>Cancelar</button>' +
        '<button class="btn primary" data-ok>Guardar</button>' +
      '</div></div>';
  document.body.appendChild(overlay);
  overlay.querySelector('[data-x]').onclick = () => overlay.remove();
  overlay.querySelector('[data-ok]').onclick = async () => {
    const out = { ...vals };
    cols.forEach((c) => {
      const el = overlay.querySelector('[data-f="' + c.id + '"]');
      if (!el) return;
      if (c.type === 'checkbox') out[c.id] = el.checked;
      else if (isMoneyCol(c)) out[c.id] = el.value === '' ? null : Number(el.value);
      else out[c.id] = el.value;
    });
    const body = isNew
      ? { key: dataKey, action: 'add', row: out }
      : { key: dataKey, action: 'update', keyField: kf, keyValue: String(row[kf]), row: out };
    const r = await api.datasetPost(body);
    if (!r.ok) { alert(r.msg || 'Error'); return; }
    overlay.remove();
    if (onDone) onDone();
  };
}

function renderGeneric(doc) {
  const main = $('main');
  main.innerHTML =
    '<div class="screen-head"><h2>' + esc(doc.title || doc.id) + '</h2>' +
    '<span class="layout-tag">layout: ' + esc(doc.layout || '—') + '</span></div>' +
    '<div class="empty">Layout <b>' + esc(doc.layout || 'especial') + '</b> (form, dashboard, master-detail…): ' +
    'en la rama HTTP de FiveTech se renderiza con el shell completo. ' +
    'La rama web 100% prioriza pantallas de lista/CRUD con el mismo contrato de datos.</div>' +
    '<details><summary>Meta JSON</summary><pre>' + esc(JSON.stringify(doc, null, 2)) + '</pre></details>';
}

async function renderList(doc) {
  const main = $('main');
  const key = doc.dataRef;
  const kf = keyFieldOf(doc);
  const cols = (doc.grid && doc.grid.columns) || [];
  const j = await api.dataset(key);
  const rows = j.ok ? (j.rows || []) : [];
  const searchFields = doc.searchFields || cols.map((c) => c.id);
  const filterCols = cols.filter((c) => c.type === 'select' && Array.isArray(c.options) && c.options.length);
  const PAGE_SIZES = [10, 25, 50, 100];

  const state = {
    q: '',
    colFilters: {},
    sortCol: null,
    sortDir: 'asc',
    page: 1,
    pageSize: 25,
    selected: null,
  };

  const tbBtn = (id, label, cls, extra) =>
    hasTb(doc, id) ? '<button id="btn-' + id + '" class="btn' + (cls ? ' ' + cls : '') + '"' + (extra || '') + '>' + label + '</button>' : '';

  const filterBar = filterCols.length
    ? '<div class="list-filters" id="list-filters">' +
      filterCols.map((c) =>
        '<label class="filter-chip">' + esc(c.label) +
        '<select data-ff="' + esc(c.id) + '"><option value="">(todos)</option>' +
        c.options.map((o) => '<option value="' + esc(String(o)) + '">' + esc(String(o)) + '</option>').join('') +
        '</select></label>').join('') +
      '<button type="button" class="btn" id="btn-clear-filters">Limpiar filtros</button></div>'
    : '';

  main.innerHTML =
    '<div class="screen-head">' +
      '<h2>' + esc(doc.title || doc.id) + '</h2>' +
      '<div class="toolbar" id="list-toolbar">' +
        '<input id="q" class="search" placeholder="Buscar' + (doc.searchFields ? ' en ' + esc(doc.searchFields.join(', ')) : '') + '…" autocomplete="off">' +
        tbBtn('add', '+ Nuevo', 'primary') +
        tbBtn('edit', 'Editar', '', ' disabled') +
        tbBtn('delete', 'Eliminar', 'danger', ' disabled') +
        tbBtn('print', 'Imprimir', '') +
        tbBtn('pdf', 'PDF', '') +
        tbBtn('excel', 'Excel', '') +
        tbBtn('refresh', 'Refrescar', '') +
      '</div>' +
    '</div>' +
    filterBar +
    '<div class="grid-wrap"><table id="grid"><thead><tr>' +
      cols.map((c) => {
        const cls = [
          c.align === 'right' || isMoneyCol(c) ? 'right' : '',
          'sortable',
        ].filter(Boolean).join(' ');
        return '<th class="' + cls + '" data-sort="' + esc(c.id) + '" title="Clic para ordenar">' +
          esc(c.label) + ' <span class="sort-ind" data-ind="' + esc(c.id) + '"></span></th>';
      }).join('') +
    '</tr></thead><tbody></tbody></table></div>' +
    (doc.summary && doc.summary.showTotals ? '<div id="list-totals" class="list-totals"></div>' : '') +
    '<div class="list-foot" id="list-foot">' +
      '<div class="foot-left">' +
        '<span id="rowcount" class="rowcount"></span>' +
        '<label class="page-size">Filas <select id="page-size">' +
          PAGE_SIZES.map((n) => '<option value="' + n + '"' + (n === state.pageSize ? ' selected' : '') + '>' + n + '</option>').join('') +
        '</select></label>' +
      '</div>' +
      '<div class="foot-nav">' +
        '<button type="button" class="btn btn-icon" id="pg-first" title="Primera">«</button>' +
        '<button type="button" class="btn btn-icon" id="pg-prev" title="Anterior">‹</button>' +
        '<span id="pg-info" class="pg-info"></span>' +
        '<button type="button" class="btn btn-icon" id="pg-next" title="Siguiente">›</button>' +
        '<button type="button" class="btn btn-icon" id="pg-last" title="Última">»</button>' +
      '</div>' +
    '</div>';

  const tbody = main.querySelector('#grid tbody');

  const fmt = (v, c) => {
    if (isMoneyCol(c)) return v == null || v === '' ? '' : Number(v).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (c.type === 'checkbox') return v ? '✔' : '';
    return v == null ? '' : String(v);
  };

  function cmpVal(a, b, c) {
    if (isMoneyCol(c) || c.type === 'number') {
      const na = Number(a), nb = Number(b);
      if (!Number.isNaN(na) && !Number.isNaN(nb)) return na - nb;
    }
    if (c.type === 'checkbox') return (a ? 1 : 0) - (b ? 1 : 0);
    return String(a ?? '').localeCompare(String(b ?? ''), 'es', { sensitivity: 'base', numeric: true });
  }

  function filteredSorted() {
    const f = state.q.toLowerCase().trim();
    let list = rows.filter((r) => {
      if (f && !searchFields.some((fld) => String(r[fld] ?? '').toLowerCase().includes(f))) return false;
      for (const [cid, val] of Object.entries(state.colFilters)) {
        if (val !== '' && String(r[cid] ?? '') !== String(val)) return false;
      }
      return true;
    });
    if (state.sortCol) {
      const col = cols.find((c) => c.id === state.sortCol) || { id: state.sortCol };
      const dir = state.sortDir === 'desc' ? -1 : 1;
      list = list.slice().sort((a, b) => dir * cmpVal(a[state.sortCol], b[state.sortCol], col));
    }
    return list;
  }

  function pageSlice(list) {
    const total = list.length;
    const pages = Math.max(1, Math.ceil(total / state.pageSize) || 1);
    if (state.page > pages) state.page = pages;
    if (state.page < 1) state.page = 1;
    const start = (state.page - 1) * state.pageSize;
    return { list: list.slice(start, start + state.pageSize), total, pages, start };
  }

  function syncSelBtns() {
    const ed = $('btn-edit'), del = $('btn-delete');
    if (ed) ed.disabled = !state.selected;
    if (del) del.disabled = !state.selected;
  }

  function paintTotals(visibleAll) {
    const el = $('list-totals');
    if (!el || !doc.summary || !doc.summary.fields) return;
    const parts = (doc.summary.fields || []).map((fid) => {
      const sum = visibleAll.reduce((a, r) => a + (Number(r[fid]) || 0), 0);
      const col = cols.find((c) => c.id === fid);
      return esc(col ? col.label : fid) + ': <b>' + sum.toLocaleString('es', { minimumFractionDigits: 2 }) + '</b>';
    });
    el.innerHTML = 'Totales (filtrados): ' + parts.join(' · ');
  }

  function paintSortInd() {
    main.querySelectorAll('.sort-ind').forEach((el) => {
      const id = el.getAttribute('data-ind');
      if (id === state.sortCol) el.textContent = state.sortDir === 'asc' ? '▲' : '▼';
      else el.textContent = '';
      el.parentElement.classList.toggle('sorted', id === state.sortCol);
    });
  }

  function paint() {
    const all = filteredSorted();
    const { list: pageRows, total, pages, start } = pageSlice(all);
    tbody.innerHTML = '';
    if (!pageRows.length) {
      const tr = document.createElement('tr');
      tr.innerHTML = '<td colspan="' + Math.max(cols.length, 1) + '" class="empty-cell">Sin registros con los filtros actuales</td>';
      tbody.appendChild(tr);
    } else {
      pageRows.forEach((r) => {
        const tr = document.createElement('tr');
        if (state.selected && String(r[kf]) === String(state.selected[kf])) tr.classList.add('sel');
        cols.forEach((c) => {
          const td = document.createElement('td');
          if (c.align === 'right' || isMoneyCol(c)) td.className = 'right';
          td.textContent = fmt(r[c.id], c);
          tr.appendChild(td);
        });
        tr.onclick = () => {
          state.selected = r;
          tbody.querySelectorAll('tr').forEach((x) => x.classList.remove('sel'));
          tr.classList.add('sel');
          syncSelBtns();
        };
        tr.ondblclick = () => { if (hasTb(doc, 'edit')) editRow(r, all); };
        tbody.appendChild(tr);
      });
    }
    const end = total ? Math.min(start + pageRows.length, total) : 0;
    $('rowcount').textContent = total
      ? (start + 1) + '–' + end + ' de ' + total + (total !== rows.length ? ' (total ' + rows.length + ')' : '') + ' filas'
      : '0 / ' + rows.length + ' filas';
    $('pg-info').textContent = 'Pág. ' + state.page + ' / ' + pages;
    const disFirst = state.page <= 1;
    const disLast = state.page >= pages;
    $('pg-first').disabled = disFirst;
    $('pg-prev').disabled = disFirst;
    $('pg-next').disabled = disLast;
    $('pg-last').disabled = disLast;
    paintSortInd();
    paintTotals(all);
    syncSelBtns();
  }

  // eventos toolbar / filtros / paginación / sort
  if ($('q')) $('q').oninput = (e) => { state.q = e.target.value; state.page = 1; paint(); };
  main.querySelectorAll('[data-ff]').forEach((sel) => {
    sel.onchange = () => {
      state.colFilters[sel.getAttribute('data-ff')] = sel.value;
      state.page = 1;
      paint();
    };
  });
  if ($('btn-clear-filters')) {
    $('btn-clear-filters').onclick = () => {
      state.colFilters = {};
      state.q = '';
      if ($('q')) $('q').value = '';
      main.querySelectorAll('[data-ff]').forEach((s) => { s.value = ''; });
      state.page = 1;
      paint();
    };
  }
  main.querySelectorAll('th[data-sort]').forEach((th) => {
    th.onclick = () => {
      const id = th.getAttribute('data-sort');
      if (state.sortCol === id) state.sortDir = state.sortDir === 'asc' ? 'desc' : 'asc';
      else { state.sortCol = id; state.sortDir = 'asc'; }
      paint();
    };
  });
  if ($('page-size')) {
    $('page-size').onchange = (e) => {
      state.pageSize = Number(e.target.value) || 25;
      state.page = 1;
      paint();
    };
  }
  if ($('pg-first')) $('pg-first').onclick = () => { state.page = 1; paint(); };
  if ($('pg-prev')) $('pg-prev').onclick = () => { state.page = Math.max(1, state.page - 1); paint(); };
  if ($('pg-next')) $('pg-next').onclick = () => { state.page += 1; paint(); };
  if ($('pg-last')) $('pg-last').onclick = () => {
    const pages = Math.max(1, Math.ceil(filteredSorted().length / state.pageSize) || 1);
    state.page = pages;
    paint();
  };

  if ($('btn-refresh')) $('btn-refresh').onclick = () => openScreen(doc.id);
  if ($('btn-add')) $('btn-add').onclick = () => editRow(null, filteredSorted());
  if ($('btn-edit')) $('btn-edit').onclick = () => { if (state.selected) editRow(state.selected, filteredSorted()); };
  if ($('btn-delete')) $('btn-delete').onclick = async () => {
    if (!state.selected) return;
    if (!confirm('¿Eliminar ' + state.selected[kf] + '?')) return;
    const r = await api.datasetPost({ key, action: 'delete', keyField: kf, keyValue: state.selected[kf] });
    if (!r.ok) alert(r.msg || 'Error');
    openScreen(doc.id);
  };
  if ($('btn-excel')) $('btn-excel').onclick = () => exportCsv(doc.title || doc.id, cols, filteredSorted());
  if ($('btn-print')) $('btn-print').onclick = () => printGrid(doc.title || doc.id, cols, filteredSorted(), fmt);
  if ($('btn-pdf')) $('btn-pdf').onclick = () => printGrid((doc.title || doc.id) + ' (PDF)', cols, filteredSorted(), fmt);

  function editRow(row, navList) {
    const list = Array.isArray(navList) ? navList : filteredSorted();
    let isNew = !row;
    let cur = row ? { ...row } : {};
    let navIdx = row ? list.findIndex((r) => String(r[kf]) === String(row[kf])) : -1;

    const overlay = document.createElement('div');
    overlay.className = 'overlay';

    function readOut() {
      const out = { ...cur };
      cols.forEach((c) => {
        const el = overlay.querySelector('[data-f="' + c.id + '"]');
        if (!el) return;
        if (c.type === 'checkbox') out[c.id] = el.checked;
        else if (isMoneyCol(c)) out[c.id] = el.value === '' ? null : Number(el.value);
        else out[c.id] = el.value;
      });
      return out;
    }

    function paintModal() {
      const title = isNew ? 'Nuevo registro' : ('Editar ' + esc(String(cur[kf] ?? '')));
      const nav = !isNew && list.length
        ? '<div class="modal-nav">' +
          '<button type="button" class="btn btn-icon" data-nav="first" title="Primero" ' + (navIdx <= 0 ? 'disabled' : '') + '>«</button>' +
          '<button type="button" class="btn btn-icon" data-nav="prev" title="Anterior" ' + (navIdx <= 0 ? 'disabled' : '') + '>‹</button>' +
          '<span class="pg-info">' + (navIdx >= 0 ? (navIdx + 1) + ' / ' + list.length : '—') + '</span>' +
          '<button type="button" class="btn btn-icon" data-nav="next" title="Siguiente" ' + (navIdx < 0 || navIdx >= list.length - 1 ? 'disabled' : '') + '>›</button>' +
          '<button type="button" class="btn btn-icon" data-nav="last" title="Último" ' + (navIdx < 0 || navIdx >= list.length - 1 ? 'disabled' : '') + '>»</button>' +
          '</div>'
        : '';
      overlay.innerHTML =
        '<div class="modal modal-form" role="dialog" aria-modal="true">' +
          '<div class="modal-head"><h3>' + title + '</h3>' + nav + '</div>' +
          '<form class="form" id="list-edit-form">' +
            cols.map((c) => fieldHtml(c, cur[c.id], isNew, kf)).join('') +
          '</form>' +
          '<div class="modal-actions">' +
            '<button type="button" class="btn" data-x>Cancelar</button>' +
            (hasTb(doc, 'add') && !isNew ? '<button type="button" class="btn" data-new>+ Nuevo</button>' : '') +
            '<button type="submit" form="list-edit-form" class="btn primary" data-ok>Guardar</button>' +
          '</div>' +
        '</div>';

      const firstInput = overlay.querySelector('input:not([readonly]), select, textarea');
      if (firstInput) setTimeout(() => firstInput.focus(), 30);

      overlay.querySelector('[data-x]').onclick = () => { document.removeEventListener('keydown', onKey); overlay.remove(); };
      overlay.querySelector('[data-new]')?.addEventListener('click', () => {
        isNew = true;
        cur = {};
        navIdx = -1;
        paintModal();
      });
      overlay.querySelectorAll('[data-nav]').forEach((b) => {
        b.onclick = () => {
          if (isNew || !list.length) return;
          const act = b.getAttribute('data-nav');
          if (act === 'first') navIdx = 0;
          else if (act === 'prev') navIdx = Math.max(0, navIdx - 1);
          else if (act === 'next') navIdx = Math.min(list.length - 1, navIdx + 1);
          else if (act === 'last') navIdx = list.length - 1;
          cur = { ...list[navIdx] };
          isNew = false;
          paintModal();
        };
      });
      overlay.querySelector('#list-edit-form').onsubmit = async (e) => {
        e.preventDefault();
        const out = readOut();
        if (isNew && kf && (out[kf] == null || String(out[kf]).trim() === '')) {
          alert('Indique la clave (' + kf + ')');
          return;
        }
        const body = isNew
          ? { key, action: 'add', row: out }
          : { key, action: 'update', keyField: kf, keyValue: String(row ? row[kf] : cur[kf]), row: out };
        // si navegamos, keyValue es la clave del registro actual en pantalla
        if (!isNew) body.keyValue = String(cur[kf]);
        const r = await api.datasetPost(body);
        if (!r.ok) { alert(r.msg || 'Error al guardar'); return; }
        document.removeEventListener('keydown', onKey);
        overlay.remove();
        openScreen(doc.id);
      };
    }

    function onKey(ev) {
      if (ev.key === 'Escape') {
        document.removeEventListener('keydown', onKey);
        overlay.remove();
      }
    }
    document.addEventListener('keydown', onKey);
    document.body.appendChild(overlay);
    paintModal();
  }

  paint();
}

function fieldHtml(c, v, isNew, kf) {
  const id = c.id;
  const label = '<label>' + esc(c.label) + '</label>';
  const val = v == null ? '' : v;
  if (c.type === 'checkbox')
    return '<div class="field chk">' + label + '<input type="checkbox" data-f="' + id + '"' + (v ? ' checked' : '') + '></div>';
  if (c.type === 'select')
    return '<div class="field">' + label + '<select data-f="' + id + '">' +
      (c.options || []).map((o) => '<option' + (String(o) === String(val) ? ' selected' : '') + '>' + esc(o) + '</option>').join('') +
      '</select></div>';
  if (isMoneyCol(c))
    return '<div class="field">' + label + '<input type="number" step="0.01" data-f="' + id + '" value="' + esc(String(val)) + '"></div>';
  const ro = (!isNew && kf === id) ? ' readonly class="ro"' : '';
  return '<div class="field">' + label + '<input data-f="' + id + '" value="' + esc(String(val)) + '"' + ro + '></div>';
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// ---------------------------------------------------------------- procesos (herramienta FWH)
async function renderProcesses() {
  const main = $('main');
  main.innerHTML = '<div class="loading">Cargando procesos…</div>';
  const j = await api.processGet();
  if (!j.ok) { main.innerHTML = '<div class="empty">Procesos no disponibles</div>'; return; }
  const items = j.items || [];
  const handlers = j.handlers || [];
  main.innerHTML =
    '<div class="screen-head"><h2>Procesos</h2>' +
    '<span class="layout-tag">handlers registrados: ' + (Array.isArray(handlers) ? handlers.length : Object.keys(handlers).length) + '</span></div>' +
    '<div class="proc-list">' +
    items.map((it, i) =>
      '<div class="proc-row"><div><b>' + esc(it.title || it.key) + '</b>' +
      '<div class="proc-sub">' + esc(it.key) + ' · handler: ' + esc(it.handler || '—') + '</div></div>' +
      '<button class="btn" data-run="' + i + '">Ejecutar</button></div>').join('') +
    '</div><pre id="proc-out" class="proc-out"></pre>';
  main.querySelectorAll('[data-run]').forEach((btn) => {
    btn.onclick = async () => {
      const it = items[Number(btn.dataset.run)];
      $('proc-out').textContent = 'Ejecutando ' + it.key + '…';
      const r = await api.processPost({ key: it.key, params: {} });
      $('proc-out').textContent = JSON.stringify(r, null, 2);
    };
  });
}

// ---------------------------------------------------------------- herramienta de cargue y ramas
(function initTool() {
  const btn = $('btn-tool'), panel = $('tool-panel');
  if (!btn || !panel) return;
  const mount = location.pathname.split('/')[1] || 'portal';
  btn.onclick = () => {
    panel.classList.toggle('hidden');
    if (!panel.classList.contains('hidden')) {
      const b = window.__RAMA__ ? window.__RAMA__.branch : 'web';
      const label = b === 'pc' ? '1 · PC (escritorio)'
        : b === 'hibrida' ? '2 · WebView + HTTP'
        : '3 · Web 100%';
      $('tool-rama').textContent = label;
      if ($('tool-cmd-pc')) $('tool-cmd-pc').textContent = 'set ZWEB_FRONT=' + mount + ' && FiveTech_ERP_local.exe';
    }
  };
  const cp = $('tool-copy-pc');
  if (cp) cp.onclick = () => {
    navigator.clipboard.writeText($('tool-cmd-pc').textContent).then(() => {
      cp.textContent = 'Copiado';
      setTimeout(() => { cp.textContent = 'Copiar'; }, 1200);
    });
  };
  const ipIn = $('tool-ip');
  const prev = $('tool-url-preview');
  if (ipIn) {
    let h = location.hostname;
    if (!h || h === 'localhost') h = '127.0.0.1';
    ipIn.value = h;
  }
  const remoteUrl = () => 'http://' + ((ipIn && ipIn.value.trim()) || location.hostname || '127.0.0.1') + ':2222/portal/';
  const refreshPrev = () => { if (prev) prev.textContent = 'Enlace: ' + remoteUrl(); };
  refreshPrev();
  if (ipIn) ipIn.addEventListener('input', refreshPrev);
  const openExt = (u) => (window.__openExternal ? window.__openExternal(u) : window.open(u, '_blank'));
  const ol = $('tool-open-local');
  if (ol) {
    ol.onclick = (ev) => {
      ev.preventDefault();
      openExt('http://127.0.0.1:2222/portal/');
    };
  }
  const orr = $('tool-open-remote');
  if (orr) orr.onclick = () => openExt(remoteUrl());
  const crm = $('tool-copy-remote');
  if (crm) crm.onclick = () => {
    navigator.clipboard.writeText(remoteUrl()).then(() => {
      crm.textContent = '¡Copiado!';
      setTimeout(() => { crm.textContent = 'Copiar enlace'; }, 1400);
    });
  };
  panel.addEventListener('click', (ev) => {
    const a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
    if (!a || a.id === 'tool-open-local') return;
    ev.preventDefault();
    openExt(a.getAttribute('href'));
  });
})();

// ---------------------------------------------------------------- arranque
(function initLoginExtras() {
  const d = new Date();
  const iso = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  if ($('login-date')) $('login-date').value = iso;
  if ($('btn-theme')) $('btn-theme').onclick = toggleTheme;
})();

(async function boot() {
  // ¿Hay sesión viva? (cookie DWSESS la envía el navegador automáticamente)
  try {
    const j = await api.context();
    if (j.ok) { ctx = j; return enterApp(); }
  } catch (e) { /* sin sesión */ }
  showLogin();
})();
