<script setup>
import { computed, onMounted, ref } from 'vue';

const api = {
  async req(method, url, body, form) {
    const opt = { method, headers: {} };
    if (body !== undefined) {
      opt.headers['Content-Type'] = form ? 'application/x-www-form-urlencoded' : 'application/json';
      opt.body = form ? body : JSON.stringify(body);
    }
    const r = await fetch(url, opt);
    return r.json().catch(() => ({ ok: false, msg: 'Respuesta no JSON' }));
  },
  login: (user, password, workDate) => api.req('POST', '/api/login', { user, password, workDate }),
  context: () => api.req('GET', '/api/context'),
  meta: (key) => api.req('GET', '/api/meta?key=' + encodeURIComponent(key)),
  dataset: (key) => api.req('GET', '/api/dataset?key=' + encodeURIComponent(key)),
  datasetPost: (body) => api.req('POST', '/api/dataset', body),
  processGet: () => api.req('GET', '/api/process'),
  processPost: (body) => api.req('POST', '/api/process', body),
  cmd: (action, a1) => api.req('POST', '/api/cmd', new URLSearchParams({ action, ...(a1 ? { a1 } : {}) }).toString(), true),
};

function applyTheme(t) {
  t = t === 'light' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', t);
  document.documentElement.classList.toggle('light', t === 'light');
  try { localStorage.setItem('dw-theme', t); } catch (e) {}
}
const todayISO = () => {
  const d = new Date();
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
};

const webview = !!(window.chrome && window.chrome.webview);
const bridge = typeof window.SendToFWH === 'function';
const rama = webview ? (bridge ? 'hibrida' : 'pc') : 'web';

const theme = ref((() => { try { return localStorage.getItem('dw-theme') || 'dark'; } catch (e) { return 'dark'; } })());
const toggleTheme = () => { theme.value = theme.value === 'dark' ? 'light' : 'dark'; applyTheme(theme.value); };
applyTheme(theme.value);

const view = ref('login');
const user = ref('admin');
const pass = ref('1234');
const date = ref(todayISO());
const error = ref('');
const ctx = ref(null);
const modules = ref([]);
const screenKey = ref('');
const screen = ref(null);
const rows = ref([]);
const procs = ref(null);
const procOut = ref('');
const q = ref('');
const colFilters = ref({});
const sortCol = ref(null);
const sortDir = ref('asc');
const page = ref(1);
const pageSize = ref(25);
const editNavIdx = ref(-1);
const sel = ref(null);
const editing = ref(null);
const notice = ref('');
const version = ref('');
const detailRows = ref([]);
const selDet = ref(null);
const formIdx = ref(0);
const formNew = ref(false);
const formDraft = ref({});
const formTab = ref('');
const lookups = ref({});
const tool = ref(false);
const sidebarCollapsed = ref((() => { try { return localStorage.getItem('dw-sidebar') === '1'; } catch (e) { return false; } })());
const secCollapsed = ref((() => { try { return JSON.parse(localStorage.getItem('dw-nav-sec') || '{}'); } catch (e) { return {}; } })());
function goDashboard() { location.href = '/dashboard.html'; }
function toggleSidebar() {
  sidebarCollapsed.value = !sidebarCollapsed.value;
  try { localStorage.setItem('dw-sidebar', sidebarCollapsed.value ? '1' : '0'); } catch (e) {}
}
function toggleSec(id) {
  secCollapsed.value = { ...secCollapsed.value, [id]: !secCollapsed.value[id] };
  try { localStorage.setItem('dw-nav-sec', JSON.stringify(secCollapsed.value)); } catch (e) {}
}
const copied = ref(false);
const ip = ref((() => {
  const h = location.hostname;
  return !h || h === 'localhost' ? '127.0.0.1' : h;
})());
const mount = location.pathname.split('/')[1] || 'portal';
const pcCmd = 'set ZWEB_FRONT=' + mount + ' && FiveTech_ERP_local.exe';
const remoteUrl = computed(() => 'http://' + (ip.value.trim() || location.hostname || '127.0.0.1') + ':2222/portal/');
const ramaLabel = rama === 'pc' ? '1 · PC (escritorio)'
  : rama === 'hibrida' ? '2 · WebView + HTTP' : '3 · Web 100%';
function copyPc() {
  navigator.clipboard.writeText(pcCmd).then(() => { copied.value = true; setTimeout(() => (copied.value = false), 1200); });
}
const loc = location;
const win = window;
const copiedUrl = ref(false);
function copyRemote() {
  navigator.clipboard.writeText(remoteUrl.value).then(() => { copiedUrl.value = true; setTimeout(() => (copiedUrl.value = false), 1400); });
}
function openExternal(url) {
  try { url = new URL(url, location.href).href; } catch (e) { /* keep */ }
  if (webview && win.chrome?.webview) {
    try { win.chrome.webview.postMessage(JSON.stringify({ cmd: 'open', url })); } catch (e1) {}
    try { win.chrome.webview.postMessage('open:' + url); } catch (e2) {}
  }
  fetch('/api/open-browser', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'url=' + encodeURIComponent(url),
    credentials: 'same-origin',
  }).catch(() => {});
  if (!webview) win.open(url, '_blank', 'noopener');
}
function openRemote() { openExternal(remoteUrl.value); }
function openLocal() { openExternal('http://127.0.0.1:2222/portal/'); }
function onMountClick(e, href) {
  e.preventDefault();
  openExternal(href);
}

const cols = computed(() => screen.value?.grid?.columns || []);
const filterCols = computed(() =>
  cols.value.filter((c) => c.type === 'select' && Array.isArray(c.options) && c.options.length)
);
const visible = computed(() => {
  const f = q.value.toLowerCase().trim();
  const fields = screen.value?.searchFields || cols.value.map((c) => c.id);
  let list = rows.value.filter((r) => {
    if (f && !fields.some((k) => String(r[k] ?? '').toLowerCase().includes(f))) return false;
    for (const [cid, val] of Object.entries(colFilters.value)) {
      if (val !== '' && val != null && String(r[cid] ?? '') !== String(val)) return false;
    }
    return true;
  });
  if (sortCol.value) {
    const col = cols.value.find((c) => c.id === sortCol.value) || { id: sortCol.value };
    const dir = sortDir.value === 'desc' ? -1 : 1;
    list = list.slice().sort((a, b) => {
      const va = a[sortCol.value], vb = b[sortCol.value];
      if (isMoney(col) || col.type === 'number') {
        const na = Number(va), nb = Number(vb);
        if (!Number.isNaN(na) && !Number.isNaN(nb)) return dir * (na - nb);
      }
      if (col.type === 'checkbox') return dir * ((va ? 1 : 0) - (vb ? 1 : 0));
      return dir * String(va ?? '').localeCompare(String(vb ?? ''), 'es', { sensitivity: 'base', numeric: true });
    });
  }
  return list;
});
const pageCount = computed(() => Math.max(1, Math.ceil(visible.value.length / pageSize.value) || 1));
const safePage = computed(() => Math.min(page.value, pageCount.value));
const pageRows = computed(() => {
  const start = (safePage.value - 1) * pageSize.value;
  return visible.value.slice(start, start + pageSize.value);
});
function toggleSort(id) {
  if (sortCol.value === id) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc';
  else { sortCol.value = id; sortDir.value = 'asc'; }
}
function openEditNav(row, isNew) {
  if (isNew) {
    editing.value = { isNew: true, row: {} };
    editNavIdx.value = -1;
    return;
  }
  const kf = keyFieldOf(screen.value);
  editNavIdx.value = visible.value.findIndex((r) => String(r[kf]) === String(row[kf]));
  editing.value = { isNew: false, row: { ...row } };
}
function navEdit(act) {
  if (!screen.value || !visible.value.length || editing.value?.isNew) return;
  let i = editNavIdx.value;
  if (act === 'first') i = 0;
  else if (act === 'prev') i = Math.max(0, i - 1);
  else if (act === 'next') i = Math.min(visible.value.length - 1, i + 1);
  else if (act === 'last') i = visible.value.length - 1;
  editNavIdx.value = i;
  editing.value = { isNew: false, row: { ...visible.value[i] } };
}

onMounted(async () => {
  const j = await api.context();
  if (j.ok) { ctx.value = j; await enter(); }
});

async function enter() {
  view.value = 'app';
  const m = await api.meta('modules');
  modules.value = m.ok ? m.doc.sections || [] : [];
  const va = await api.meta('app');
  if (va.ok && va.doc.version) version.value = va.doc.version;
  const first = modules.value.flatMap((s) => s.items || []).find((i) => i.screen && !i.sub)?.screen;
  if (first) openScreen(first);
}

async function doLogin() {
  error.value = '';
  const j = await api.login(user.value.trim(), pass.value, date.value);
  if (!j.ok) { error.value = j.msg || 'Credenciales inválidas'; return; }
  ctx.value = await api.context();
  await enter();
}

function isMasterDetail(doc) {
  return !!(doc && (doc.layout === 'master-detail' || doc.layout === 'document') && doc.detail?.dataRef);
}
function isFormScreen(doc) {
  return !!(doc && doc.layout === 'form' && Array.isArray(doc.fields) && doc.fields.length);
}
function isListScreen(doc) {
  if (!doc || isMasterDetail(doc) || isFormScreen(doc)) return false;
  return !!(doc.layout === 'list' || (doc.dataRef && doc.grid?.columns?.length));
}
function toolbarIds(doc) {
  const t = doc?.toolbar;
  if (Array.isArray(t) && t.length)
    return t.map((x) => (typeof x === 'string' ? x : x?.id || '')).filter(Boolean);
  return ['add', 'edit', 'delete', 'refresh'];
}
function hasTb(doc, id) { return toolbarIds(doc).includes(id); }
function keyFieldOf(doc) {
  return doc?.keyField || doc?.grid?.columns?.[0]?.id || 'code';
}
function isMoney(c) { return c?.type === 'money' || c?.format === 'money'; }

async function loadLookupsFor(fields) {
  const map = { ...lookups.value };
  for (const f of fields || []) {
    if (f.type !== 'lookup' || !f.lookup || map[f.lookup]) continue;
    try {
      const lm = await api.meta(f.lookup);
      if (!lm.ok) continue;
      const vf = lm.doc.valueField || 'code';
      const lf = lm.doc.labelField || 'name';
      const dd = await api.dataset(lm.doc.dataRef);
      map[f.lookup] = (dd.ok ? dd.rows : []).map((r) => ({ value: r[vf], label: r[lf] != null ? r[lf] : r[vf] }));
    } catch (e) { map[f.lookup] = []; }
  }
  lookups.value = map;
}

async function openScreen(key) {
  procs.value = null;
  screenKey.value = key;
  sel.value = null;
  selDet.value = null;
  detailRows.value = [];
  formNew.value = false;
  formIdx.value = 0;
  const m = await api.meta(key);
  if (!m.ok) { screen.value = null; return; }
  screen.value = m.doc;
  q.value = '';
  colFilters.value = {};
  sortCol.value = null;
  sortDir.value = 'asc';
  page.value = 1;
  if (isMasterDetail(m.doc)) {
    const d = await api.dataset(m.doc.dataRef);
    const masters = d.ok ? d.rows : [];
    rows.value = masters;
    sel.value = masters[0] || null;
    const dd = await api.dataset(m.doc.detail.dataRef);
    detailRows.value = dd.ok ? dd.rows : [];
  } else if (isFormScreen(m.doc)) {
    const d = await api.dataset(m.doc.dataRef);
    const rs = d.ok ? d.rows : [];
    rows.value = rs;
    formDraft.value = rs[0] ? { ...rs[0] } : {};
    formTab.value = (m.doc.tabs && m.doc.tabs[0]?.id) || 'all';
    await loadLookupsFor(m.doc.fields);
  } else if (isListScreen(m.doc) && m.doc.dataRef) {
    const d = await api.dataset(m.doc.dataRef);
    rows.value = d.ok ? d.rows : [];
  } else rows.value = [];
}

async function saveForm() {
  const sc = screen.value;
  const kf = keyFieldOf(sc);
  const body = formNew.value
    ? { key: sc.dataRef, action: 'add', row: formDraft.value }
    : { key: sc.dataRef, action: 'update', keyField: kf, keyValue: String(rows.value[formIdx.value]?.[kf]), row: formDraft.value };
  const j = await api.datasetPost(body);
  notice.value = j.ok ? 'Guardado' : j.msg || 'Error';
  if (j.ok) openScreen(sc.id);
}

async function delForm() {
  if (formNew.value) return;
  const sc = screen.value;
  const kf = keyFieldOf(sc);
  const row = rows.value[formIdx.value];
  if (!row || !confirm('¿Eliminar ' + row[kf] + '?')) return;
  const j = await api.datasetPost({ key: sc.dataRef, action: 'delete', keyField: kf, keyValue: String(row[kf]) });
  notice.value = j.ok ? 'Eliminado' : j.msg || 'Error';
  if (j.ok) openScreen(sc.id);
}

const formFieldsVisible = computed(() => {
  const sc = screen.value;
  if (!sc?.fields) return [];
  const tab = (sc.tabs || []).find((t) => t.id === formTab.value) || { fields: sc.fields.map((f) => f.id) };
  return sc.fields.filter((f) => (tab.fields || []).includes(f.id));
});

const detailVisible = computed(() => {
  const sc = screen.value;
  if (!sc?.detail || !sel.value) return [];
  const mk = sc.detail.masterKey || keyFieldOf(sc);
  return detailRows.value.filter((r) => String(r[mk]) === String(sel.value[keyFieldOf(sc)]));
});

async function openProcesses() {
  screen.value = null;
  screenKey.value = '__procs';
  const j = await api.processGet();
  procs.value = j.ok ? j : { items: [], handlers: [] };
  procOut.value = '';
}

async function runProcess(it) {
  procOut.value = 'Ejecutando ' + it.key + '…';
  const r = await api.processPost({ key: it.key, params: {} });
  procOut.value = JSON.stringify(r, null, 2);
}

async function switchTo(action, value) {
  const j = await api.cmd(action, value);
  if (j.ok) { ctx.value = await api.context(); await enter(); }
  else notice.value = j.msg || 'No autorizado';
}

function onWorkdate(v) { api.cmd('workdate', v); }

async function save() {
  const { isNew, row, scope } = editing.value;
  const sc = screen.value;
  const dataKey = scope === 'detail' ? sc.detail.dataRef : sc.dataRef;
  const kf = scope === 'detail' ? (sc.detail.keyField || 'code') : keyFieldOf(sc);
  const body = isNew
    ? { key: dataKey, action: 'add', row }
    : { key: dataKey, action: 'update', keyField: kf, keyValue: String(row[kf]), row };
  const j = await api.datasetPost(body);
  notice.value = j.ok ? 'Guardado' : j.msg || 'Error';
  if (j.ok) { editing.value = null; openScreen(sc.id); }
}

async function del() {
  if (!sel.value) return;
  const kf = keyFieldOf(screen.value);
  if (!confirm('¿Eliminar ' + sel.value[kf] + '?')) return;
  const j = await api.datasetPost({ key: screen.value.dataRef, action: 'delete', keyField: kf, keyValue: String(sel.value[kf]) });
  notice.value = j.ok ? 'Eliminado' : j.msg || 'Error';
  if (j.ok) openScreen(screen.value.id);
}

async function delDetail() {
  if (!selDet.value || !screen.value?.detail) return;
  const dk = screen.value.detail.keyField || 'code';
  if (!confirm('¿Eliminar ' + selDet.value[dk] + '?')) return;
  const j = await api.datasetPost({
    key: screen.value.detail.dataRef,
    action: 'delete',
    keyField: dk,
    keyValue: String(selDet.value[dk]),
  });
  notice.value = j.ok ? 'Eliminado' : j.msg || 'Error';
  if (j.ok) openScreen(screen.value.id);
}

function exportExcel() {
  const sc = screen.value;
  if (!sc) return;
  const cols = sc.grid?.columns || [];
  const cell = (v) => {
    const s = v == null ? '' : String(v);
    return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const lines = [cols.map((c) => cell(c.label || c.id)).join(',')];
  visible.value.forEach((r) => lines.push(cols.map((c) => cell(r[c.id])).join(',')));
  const blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = String(sc.title || sc.id).replace(/[^A-Za-z0-9_\-]+/g, '_') + '.csv';
  a.click();
  URL.revokeObjectURL(a.href);
  notice.value = 'Excel/CSV exportado (' + visible.value.length + ' filas)';
}

function printList() {
  const sc = screen.value;
  if (!sc) return;
  const cols = sc.grid?.columns || [];
  const w = window.open('', '_blank');
  if (!w) { window.print(); return; }
  const th = cols.map((c) => '<th>' + (c.label || c.id) + '</th>').join('');
  const body = visible.value.map((r) => '<tr>' + cols.map((c) => '<td>' + fmt(r[c.id], c) + '</td>').join('') + '</tr>').join('');
  w.document.write('<!doctype html><html><head><title>' + (sc.title || '') + '</title>' +
    '<style>body{font:12px Segoe UI,sans-serif}table{border-collapse:collapse;width:100%}' +
    'th,td{border:1px solid #ccc;padding:4px 6px}th{background:#eee}</style></head><body>' +
    '<h2>' + (sc.title || '') + '</h2><table><thead><tr>' + th + '</tr></thead><tbody>' + body +
    '</tbody></table></body></html>');
  w.document.close();
  setTimeout(() => { try { w.print(); } catch (e) {} }, 250);
}

async function logout() {
  await api.cmd('logout');
  ctx.value = null;
  screen.value = null;
  modules.value = [];
  view.value = 'login';
}

function fmt(v, c) {
  if (isMoney(c) && v != null && v !== '') return Number(v).toLocaleString('es', { minimumFractionDigits: 2 });
  if (c.type === 'checkbox') return v ? '✔' : '';
  return v == null ? '' : String(v);
}
</script>

<template>
  <div v-if="view === 'login'" class="login-wrap">
    <button class="theme-fab" @click="toggleTheme">{{ theme === 'dark' ? 'Dark' : 'Light' }}</button>
    <div class="login-card">
      <div class="login-brand">FiveTech ERP</div>
      <div class="login-sub">Rama 100% web · frontend Vue</div>
      <form @submit.prevent="doLogin">
        <label>Usuario</label>
        <input v-model="user" />
        <label>Clave</label>
        <input type="password" v-model="pass" />
        <label>Fecha de trabajo</label>
        <input type="date" v-model="date" />
        <button type="submit">Entrar</button>
        <div class="login-error">{{ error }}</div>
      </form>
      <button type="button" class="tool-toggle" @click="tool = !tool">Opciones de vista (ayuda)</button>
      <div v-if="tool" class="tool-panel">
        <div class="tool-row"><span>Ahora está en:</span> <b>{{ ramaLabel }}</b></div>
        <div class="tool-row">
          <span><b>1 · Login directo — versión PC</b></span>
          <div class="tool-note">Aplicación de este equipo. Login clásico: <a href="/login" @click="onMountClick($event, '/login')">/login</a></div>
        </div>
        <div class="tool-row">
          <span><b>2 · WebView + HTTP</b></span>
          <div class="tool-note">App de escritorio + navegador (como Edge con localhost:2222/portal).</div>
          <nav class="tool-links">
            <a href="/portal/" @click.prevent="openLocal">Abrir portal en el navegador</a>
          </nav>
        </div>
        <div class="tool-row">
          <span><b>3 · Web 100%</b> — elija la vista (mismos datos)</span>
          <nav class="tool-links">
            <a href="/web-vainilla/index.html" @click="onMountClick($event, '/web-vainilla/index.html')">Vainilla</a>
            <a href="/web-angular/index.html" @click="onMountClick($event, '/web-angular/index.html')">Angular</a>
            <a href="/web-react/index.html" @click="onMountClick($event, '/web-react/index.html')">React</a>
            <a href="/web-vue/index.html" @click="onMountClick($event, '/web-vue/index.html')">Vue</a>
            <a href="/portal/" @click="onMountClick($event, '/portal/')">Menú…</a>
          </nav>
        </div>
        <div class="tool-row">
          <span><b>Acceso por la red</b></span>
          <div class="tool-note"><b>Intranet:</b> en otro PC/celular de la oficina use la dirección de abajo.</div>
          <nav class="tool-links">
            <input class="tool-ip" v-model="ip" placeholder="ej. 192.168.1.20" />
            <button type="button" class="btn" @click="openRemote">Probar</button>
            <button type="button" class="btn" @click="copyRemote">{{ copiedUrl ? '¡Copiado!' : 'Copiar enlace' }}</button>
          </nav>
          <div class="tool-note">Enlace: {{ remoteUrl }}</div>
          <div class="tool-note"><b>Remoto (internet):</b> solo si sistemas habilitó acceso seguro (VPN o túnel).</div>
        </div>
      </div>
    </div>
  </div>

  <div v-else class="app">
    <header class="topbar">
      <div class="topbar-left">
        <button type="button" class="btn-icon-bar" :title="sidebarCollapsed ? 'Mostrar menú' : 'Ocultar menú'"
          :aria-expanded="!sidebarCollapsed" @click="toggleSidebar">☰</button>
        <span class="brand">FiveTech ERP</span>
        <span class="branch-tag">rama {{ rama }} · vue{{ version ? ' · v' + version : '' }}</span>
        <button type="button" class="btn-ghost btn-dash" title="Ir al dashboard FWH" @click="goDashboard">Dashboard</button>
      </div>
      <div class="topbar-right">
        <select :value="ctx?.company" :disabled="ctx?.canSwitchCompany === false" @change="switchTo('company', $event.target.value)">
          <option v-for="c in ctx?.companies || []" :key="c.code" :value="c.code">{{ c.name || c.code }}</option>
        </select>
        <select :value="ctx?.app" :disabled="ctx?.canSwitchApp === false" @change="switchTo('app', $event.target.value)">
          <option v-for="a in ctx?.apps || []" :key="a.id" :value="a.id">{{ a.label || a.id }}</option>
        </select>
        <input type="date" :value="date" @change="date = $event.target.value; onWorkdate(date)" />
        <span class="user-chip">{{ ctx?.company }} · {{ ctx?.appLabel || ctx?.app }} · {{ ctx?.isAdmin ? 'admin' : 'usuario' }}</span>
        <button class="btn-ghost" @click="toggleTheme">{{ theme === 'dark' ? 'Dark' : 'Light' }}</button>
        <button class="btn-ghost" @click="logout">Salir</button>
      </div>
    </header>

    <div class="body" :class="{ 'sidebar-collapsed': sidebarCollapsed }">
      <nav class="sidebar" aria-label="Módulos">
        <div class="nav-pin">
          <button type="button" class="nav-item dash" @click="goDashboard">⊞ Dashboard</button>
        </div>
        <div v-for="sec in modules" :key="sec.id || sec.title" class="nav-group" :class="{ collapsed: secCollapsed[sec.id || sec.title] }">
          <button type="button" class="nav-section" @click="toggleSec(sec.id || sec.title)">
            <span>{{ sec.title }}</span><span class="chev">▼</span>
          </button>
          <div class="nav-group-body">
            <button
              v-for="it in (sec.items || []).filter((i) => i.screen)"
              :key="it.id"
              type="button"
              class="nav-item"
              :class="{ sub: it.sub, active: screenKey === it.screen }"
              @click="openScreen(it.screen)"
            >{{ it.label }}</button>
          </div>
        </div>
        <div class="nav-group" :class="{ collapsed: secCollapsed.__tools }">
          <button type="button" class="nav-section" @click="toggleSec('__tools')">
            <span>Herramientas</span><span class="chev">▼</span>
          </button>
          <div class="nav-group-body">
            <button type="button" class="nav-item" :class="{ active: screenKey === '__procs' }" @click="openProcesses">Procesos</button>
          </div>
        </div>
      </nav>

      <main class="main">
        <template v-if="procs">
          <div class="screen-head">
            <h2>Procesos</h2>
            <span class="layout-tag">handlers: {{ (procs.handlers || []).length }}</span>
          </div>
          <div class="proc-list">
            <div v-for="it in procs.items || []" :key="it.key" class="proc-row">
              <div><b>{{ it.title || it.key }}</b><div class="proc-sub">{{ it.key }} · handler: {{ it.handler || '—' }}</div></div>
              <button class="btn" @click="runProcess(it)">Ejecutar</button>
            </div>
          </div>
          <pre class="proc-out">{{ procOut }}</pre>
        </template>
        <template v-else-if="screen">
          <div class="screen-head">
            <h2>{{ screen.title }}</h2>
            <div v-if="isListScreen(screen)" class="toolbar">
              <input class="search" placeholder="Buscar…" :value="q" @input="q = $event.target.value; page = 1" />
              <button v-if="hasTb(screen, 'add')" class="btn primary" @click="openEditNav(null, true)">+ Nuevo</button>
              <button v-if="hasTb(screen, 'edit')" class="btn" :disabled="!sel" @click="sel && openEditNav(sel, false)">Editar</button>
              <button v-if="hasTb(screen, 'delete')" class="btn danger" :disabled="!sel" @click="del">Eliminar</button>
              <button v-if="hasTb(screen, 'print')" class="btn" @click="printList">Imprimir</button>
              <button v-if="hasTb(screen, 'pdf')" class="btn" @click="printList">PDF</button>
              <button v-if="hasTb(screen, 'excel')" class="btn" @click="exportExcel">Excel</button>
              <button v-if="hasTb(screen, 'refresh')" class="btn" @click="openScreen(screen.id)">Refrescar</button>
            </div>
          </div>
          <div v-if="notice" class="notice">{{ notice }}</div>
          <div v-if="isListScreen(screen) && filterCols.length" class="list-filters">
            <label v-for="c in filterCols" :key="c.id" class="filter-chip">{{ c.label }}
              <select :value="colFilters[c.id] || ''" @change="colFilters = { ...colFilters, [c.id]: $event.target.value }; page = 1">
                <option value="">(todos)</option>
                <option v-for="o in c.options || []" :key="o" :value="o">{{ o }}</option>
              </select>
            </label>
            <button type="button" class="btn" @click="colFilters = {}; q = ''; page = 1">Limpiar filtros</button>
          </div>

          <div v-if="isFormScreen(screen)" class="form-layout">
            <aside class="form-nav">
              <div class="form-nav-title">Registros</div>
              <button v-for="(r, i) in rows" :key="i" type="button" class="form-nav-item" :class="{ active: i === formIdx && !formNew }"
                @click="formNew = false; formIdx = i; formDraft = { ...r }">
                {{ (r[keyFieldOf(screen)] ?? '') + (r.name ? ' · ' + r.name : '') }}
              </button>
            </aside>
            <div class="form-main">
              <div class="toolbar" style="padding:8px 12px">
                <button v-if="hasTb(screen, 'add')" class="btn primary" @click="formNew = true; formDraft = {}">+ Nuevo</button>
                <button class="btn primary" @click="saveForm">Guardar</button>
                <button v-if="hasTb(screen, 'delete')" class="btn danger" :disabled="formNew" @click="delForm">Eliminar</button>
                <button v-if="hasTb(screen, 'refresh')" class="btn" @click="openScreen(screen.id)">Refrescar</button>
                <span class="rowcount">{{ formNew ? 'Nuevo' : ((rows.length ? formIdx + 1 : 0) + ' / ' + rows.length) }}</span>
              </div>
              <div class="form-tabs">
                <button v-for="t in (screen.tabs || [{ id: 'all', label: 'Datos', fields: (screen.fields || []).map(f => f.id) }])" :key="t.id"
                  type="button" class="form-tab" :class="{ active: formTab === t.id }" @click="formTab = t.id">{{ t.label || t.id }}</button>
              </div>
              <div class="form form-body">
                <div v-for="f in formFieldsVisible" :key="f.id" class="field" :class="{ chk: f.type === 'checkbox' }">
                  <label>{{ f.label }}{{ f.required ? ' *' : '' }}</label>
                  <input v-if="f.type === 'checkbox'" type="checkbox" :checked="!!formDraft[f.id]" @change="formDraft[f.id] = $event.target.checked" />
                  <div v-else-if="f.type === 'checklist'" class="checklist">
                    <label v-for="o in f.options || []" :key="o" class="chk-item">
                      <input type="checkbox" :checked="(Array.isArray(formDraft[f.id]) ? formDraft[f.id] : []).includes(o)"
                        @change="formDraft[f.id] = $event.target.checked ? [...(Array.isArray(formDraft[f.id]) ? formDraft[f.id] : []), o] : (formDraft[f.id] || []).filter(x => x !== o)" /> {{ o }}
                    </label>
                  </div>
                  <select v-else-if="f.type === 'select'" v-model="formDraft[f.id]"><option value="" /><option v-for="o in f.options || []" :key="o" :value="o">{{ o }}</option></select>
                  <select v-else-if="f.type === 'lookup'" v-model="formDraft[f.id]">
                    <option value="" />
                    <option v-for="o in (lookups[f.lookup] || [])" :key="o.value" :value="o.value">{{ o.label }} ({{ o.value }})</option>
                  </select>
                  <input v-else-if="isMoney(f)" type="number" step="0.01" :value="formDraft[f.id] ?? ''" @input="formDraft[f.id] = $event.target.value === '' ? null : Number($event.target.value)" />
                  <input v-else :value="formDraft[f.id] ?? ''" :readonly="!formNew && keyFieldOf(screen) === f.id" @input="formDraft[f.id] = $event.target.value" />
                </div>
              </div>
            </div>
          </div>

          <div v-else-if="isMasterDetail(screen)" class="md-layout">
            <section class="md-master">
              <div class="md-head">
                <b>Maestro</b>
                <div class="toolbar">
                  <button class="btn primary" @click="editing = { isNew: true, row: {}, scope: 'master' }">+ Nuevo</button>
                  <button class="btn" :disabled="!sel" @click="sel && (editing = { isNew: false, row: { ...sel }, scope: 'master' })">Editar</button>
                  <button class="btn danger" :disabled="!sel" @click="del">Eliminar</button>
                  <button class="btn" @click="openScreen(screen.id)">Refrescar</button>
                  <input class="search" placeholder="Buscar…" v-model="q" />
                </div>
              </div>
              <div class="grid-wrap">
                <table>
                  <thead><tr><th v-for="c in cols" :key="c.id">{{ c.label }}</th></tr></thead>
                  <tbody>
                    <tr v-for="(r, i) in visible" :key="i" :class="{ sel: sel === r }" @click="sel = r; selDet = null" @dblclick="editing = { isNew: false, row: { ...r }, scope: 'master' }">
                      <td v-for="c in cols" :key="c.id" :class="{ right: c.align === 'right' || isMoney(c) }">{{ fmt(r[c.id], c) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
            <section class="md-detail">
              <div class="md-head">
                <b>{{ screen.detail?.title || 'Detalle' }}</b>
                <div class="toolbar">
                  <button class="btn primary" :disabled="!sel" @click="editing = { isNew: true, row: { [screen.detail?.masterKey || keyFieldOf(screen)]: sel[keyFieldOf(screen)] }, scope: 'detail' }">+ Línea</button>
                  <button class="btn" :disabled="!selDet" @click="selDet && (editing = { isNew: false, row: { ...selDet }, scope: 'detail' })">Editar</button>
                  <button class="btn danger" :disabled="!selDet" @click="delDetail">Eliminar</button>
                </div>
              </div>
              <div class="grid-wrap">
                <table>
                  <thead><tr><th v-for="c in (screen.detail?.grid?.columns || [])" :key="c.id">{{ c.label }}</th></tr></thead>
                  <tbody>
                    <tr v-for="(r, i) in detailVisible" :key="i" :class="{ sel: selDet === r }" @click="selDet = r" @dblclick="editing = { isNew: false, row: { ...r }, scope: 'detail' }">
                      <td v-for="c in (screen.detail?.grid?.columns || [])" :key="c.id" :class="{ right: c.align === 'right' || isMoney(c) }">{{ fmt(r[c.id], c) }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          </div>

          <template v-else-if="isListScreen(screen)">
            <div class="grid-wrap">
              <table>
                <thead>
                  <tr>
                    <th v-for="c in cols" :key="c.id"
                      class="sortable"
                      :class="{ right: c.align === 'right' || isMoney(c), sorted: sortCol === c.id }"
                      title="Clic para ordenar"
                      @click="toggleSort(c.id)"
                    >{{ c.label }} <span class="sort-ind">{{ sortCol === c.id ? (sortDir === 'asc' ? '▲' : '▼') : '' }}</span></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-if="!pageRows.length"><td :colspan="Math.max(cols.length, 1)" class="empty-cell">Sin registros con los filtros actuales</td></tr>
                  <tr
                    v-for="(r, i) in pageRows" :key="i"
                    :class="{ sel: sel && String(sel[keyFieldOf(screen)]) === String(r[keyFieldOf(screen)]) }"
                    @click="sel = r"
                    @dblclick="hasTb(screen, 'edit') && openEditNav(r, false)"
                  >
                    <td v-for="c in cols" :key="c.id" :class="{ right: c.align === 'right' || isMoney(c) }">{{ fmt(r[c.id], c) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div class="list-foot">
              <div class="foot-left">
                <span class="rowcount">
                  {{ visible.length
                    ? ((safePage - 1) * pageSize + 1) + '–' + Math.min(safePage * pageSize, visible.length) + ' de ' + visible.length +
                      (visible.length !== rows.length ? ' (total ' + rows.length + ')' : '') + ' filas'
                    : '0 / ' + rows.length + ' filas' }}
                </span>
                <label class="page-size">Filas
                  <select :value="pageSize" @change="pageSize = Number($event.target.value) || 25; page = 1">
                    <option v-for="n in [10, 25, 50, 100]" :key="n" :value="n">{{ n }}</option>
                  </select>
                </label>
              </div>
              <div class="foot-nav">
                <button type="button" class="btn btn-icon" :disabled="safePage <= 1" @click="page = 1">«</button>
                <button type="button" class="btn btn-icon" :disabled="safePage <= 1" @click="page = Math.max(1, page - 1)">‹</button>
                <span class="pg-info">Pág. {{ safePage }} / {{ pageCount }}</span>
                <button type="button" class="btn btn-icon" :disabled="safePage >= pageCount" @click="page = page + 1">›</button>
                <button type="button" class="btn btn-icon" :disabled="safePage >= pageCount" @click="page = pageCount">»</button>
              </div>
            </div>
          </template>
          <div v-else class="empty">Layout <b>{{ screen.layout || 'especial' }}</b> — lista, form y master-detail cubiertos; resto en shell HTTP. Ver PROPUESTA/SUSTENTO.</div>
        </template>
        <div v-else class="empty">Selecciona un módulo.</div>
      </main>
    </div>

    <div v-if="editing && screen" class="overlay" @keydown.esc="editing = null">
      <div class="modal modal-form" role="dialog" aria-modal="true">
        <div class="modal-head">
          <h3>{{ editing.isNew ? 'Nuevo registro' : 'Editar ' + editing.row[editing.scope === 'detail' ? (screen.detail?.keyField || 'code') : keyFieldOf(screen)] }}</h3>
          <div v-if="!editing.isNew && !editing.scope && visible.length" class="modal-nav">
            <button type="button" class="btn btn-icon" :disabled="editNavIdx <= 0" @click="navEdit('first')">«</button>
            <button type="button" class="btn btn-icon" :disabled="editNavIdx <= 0" @click="navEdit('prev')">‹</button>
            <span class="pg-info">{{ editNavIdx >= 0 ? (editNavIdx + 1) + ' / ' + visible.length : '—' }}</span>
            <button type="button" class="btn btn-icon" :disabled="editNavIdx < 0 || editNavIdx >= visible.length - 1" @click="navEdit('next')">›</button>
            <button type="button" class="btn btn-icon" :disabled="editNavIdx < 0 || editNavIdx >= visible.length - 1" @click="navEdit('last')">»</button>
          </div>
        </div>
        <div class="form">
          <div v-for="c in (editing.scope === 'detail' ? (screen.detail?.grid?.columns || []) : cols)" :key="c.id" class="field" :class="{ chk: c.type === 'checkbox' }">
            <label>{{ c.label }}</label>
            <input v-if="c.type === 'checkbox'" type="checkbox" :checked="!!editing.row[c.id]" @change="editing.row[c.id] = $event.target.checked" />
            <select v-else-if="c.type === 'select'" v-model="editing.row[c.id]">
              <option v-for="o in c.options || []" :key="o" :value="o">{{ o }}</option>
            </select>
            <input
              v-else
              :type="isMoney(c) ? 'number' : 'text'"
              step="0.01"
              :value="editing.row[c.id] ?? ''"
              :readonly="!editing.isNew && (editing.scope === 'detail' ? (screen.detail?.keyField || 'code') : keyFieldOf(screen)) === c.id"
              @input="editing.row[c.id] = isMoney(c) ? ($event.target.value === '' ? null : Number($event.target.value)) : $event.target.value"
            />
          </div>
        </div>
        <div class="modal-actions">
          <button class="btn" @click="editing = null">Cancelar</button>
          <button class="btn primary" @click="save">Guardar</button>
        </div>
      </div>
    </div>
  </div>
</template>
