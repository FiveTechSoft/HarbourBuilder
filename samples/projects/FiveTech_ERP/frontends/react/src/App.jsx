import { useEffect, useMemo, useState } from 'react';

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

export default function App() {
  const webview = !!(window.chrome && window.chrome.webview);
  const bridge = typeof window.SendToFWH === 'function';
  const rama = webview ? (bridge ? 'hibrida' : 'pc') : 'web';
  const [theme, setTheme] = useState(() => { try { return localStorage.getItem('dw-theme') || 'dark'; } catch (e) { return 'dark'; } });
  const [ctx, setCtx] = useState(null);
  const [view, setView] = useState('login');
  const [user, setUser] = useState('admin');
  const [pass, setPass] = useState('1234');
  const [date, setDate] = useState(todayISO());
  const [error, setError] = useState('');
  const [modules, setModules] = useState([]);
  const [screenKey, setScreenKey] = useState('');
  const [screen, setScreen] = useState(null);
  const [rows, setRows] = useState([]);
  const [procs, setProcs] = useState(null);
  const [procOut, setProcOut] = useState('');
  const [q, setQ] = useState('');
  const [colFilters, setColFilters] = useState({});
  const [sortCol, setSortCol] = useState(null);
  const [sortDir, setSortDir] = useState('asc');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [sel, setSel] = useState(null);
  const [editing, setEditing] = useState(null);
  const [editNavIdx, setEditNavIdx] = useState(-1);
  const [notice, setNotice] = useState('');
  const [version, setVersion] = useState('');
  const [detailRows, setDetailRows] = useState([]);
  const [selDet, setSelDet] = useState(null);
  const [formIdx, setFormIdx] = useState(0);
  const [formNew, setFormNew] = useState(false);
  const [formDraft, setFormDraft] = useState({});
  const [formTab, setFormTab] = useState('');
  const [lookups, setLookups] = useState({});
  const [tool, setTool] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(() => {
    try { return localStorage.getItem('dw-sidebar') === '1'; } catch (e) { return false; }
  });
  const [secCollapsed, setSecCollapsed] = useState(() => {
    try { return JSON.parse(localStorage.getItem('dw-nav-sec') || '{}'); } catch (e) { return {}; }
  });
  const [copied, setCopied] = useState(false);
  const [copiedUrl, setCopiedUrl] = useState(false);
  const [ip, setIp] = useState(() => {
    const h = location.hostname;
    return !h || h === 'localhost' ? '127.0.0.1' : h;
  });
  const mount = location.pathname.split('/')[1] || 'portal';
  const remoteUrl = 'http://' + (ip.trim() || location.hostname || '127.0.0.1') + ':2222/portal/';
  const ramaLabel = rama === 'pc' ? '1 · PC (escritorio)'
    : rama === 'hibrida' ? '2 · WebView + HTTP' : '3 · Web 100%';
  function openExternal(url) {
    try { url = new URL(url, location.href).href; } catch (e) { /* keep */ }
    if (webview && window.chrome?.webview) {
      try { window.chrome.webview.postMessage(JSON.stringify({ cmd: 'open', url })); } catch (e1) {}
      try { window.chrome.webview.postMessage('open:' + url); } catch (e2) {}
    }
    fetch('/api/open-browser', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'url=' + encodeURIComponent(url),
      credentials: 'same-origin',
    }).catch(() => {});
    if (!webview) window.open(url, '_blank', 'noopener');
  }
  function onMountClick(e, href) {
    e.preventDefault();
    openExternal(href);
  }

  useEffect(() => { applyTheme(theme); }, [theme]);
  useEffect(() => {
    try { localStorage.setItem('dw-sidebar', sidebarCollapsed ? '1' : '0'); } catch (e) {}
  }, [sidebarCollapsed]);
  useEffect(() => {
    try { localStorage.setItem('dw-nav-sec', JSON.stringify(secCollapsed)); } catch (e) {}
  }, [secCollapsed]);
  useEffect(() => {
    api.context().then((j) => { if (j.ok) { setCtx(j); enter(j); } }).catch(() => {});
  }, []);
  function goDashboard() { location.href = '/dashboard.html'; }
  function toggleSec(id) {
    setSecCollapsed((m) => ({ ...m, [id]: !m[id] }));
  }

  async function enter() {
    setView('app');
    const m = await api.meta('modules');
    const secs = m.ok ? m.doc.sections || [] : [];
    setModules(secs);
    const va = await api.meta('app');
    if (va.ok && va.doc.version) setVersion(va.doc.version);
    const first = secs.flatMap((s) => s.items || []).find((i) => i.screen && !i.sub)?.screen;
    if (first) openScreen(first);
  }

  async function doLogin(e) {
    e.preventDefault();
    setError('');
    const j = await api.login(user.trim(), pass, date);
    if (!j.ok) return setError(j.msg || 'Credenciales inválidas');
    const c = await api.context();
    setCtx(c);
    enter();
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
    const map = {};
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
    setLookups((prev) => ({ ...prev, ...map }));
  }

  async function openScreen(key) {
    setProcs(null);
    setScreenKey(key);
    setSel(null);
    setSelDet(null);
    setDetailRows([]);
    setFormNew(false);
    setFormIdx(0);
    const m = await api.meta(key);
    if (!m.ok) return setScreen(null);
    setScreen(m.doc);
    setQ('');
    setColFilters({});
    setSortCol(null);
    setSortDir('asc');
    setPage(1);
    if (isMasterDetail(m.doc)) {
      const d = await api.dataset(m.doc.dataRef);
      const masters = d.ok ? d.rows : [];
      setRows(masters);
      setSel(masters[0] || null);
      const dd = await api.dataset(m.doc.detail.dataRef);
      setDetailRows(dd.ok ? dd.rows : []);
    } else if (isFormScreen(m.doc)) {
      const d = await api.dataset(m.doc.dataRef);
      const rs = d.ok ? d.rows : [];
      setRows(rs);
      setFormDraft(rs[0] ? { ...rs[0] } : {});
      setFormTab((m.doc.tabs && m.doc.tabs[0]?.id) || 'all');
      await loadLookupsFor(m.doc.fields);
    } else if (isListScreen(m.doc) && m.doc.dataRef) {
      const d = await api.dataset(m.doc.dataRef);
      setRows(d.ok ? d.rows : []);
    } else setRows([]);
  }

  async function openProcesses() {
    setScreen(null);
    setScreenKey('__procs');
    const j = await api.processGet();
    setProcs(j.ok ? j : { items: [], handlers: [] });
    setProcOut('');
  }

  async function runProcess(it) {
    setProcOut('Ejecutando ' + it.key + '…');
    const r = await api.processPost({ key: it.key, params: {} });
    setProcOut(JSON.stringify(r, null, 2));
  }

  async function switchTo(action, value) {
    const j = await api.cmd(action, value);
    if (j.ok) { const c = await api.context(); setCtx(c); enter(); }
    else setNotice(j.msg || 'No autorizado');
  }

  async function save() {
    const { isNew, row } = editing;
    const key = screen.dataRef, kf = keyFieldOf(screen);
    // master-detail modal: detail uses nested dataRef when editing.scope === 'detail'
    const dataKey = editing.scope === 'detail' ? screen.detail.dataRef : key;
    const kfd = editing.scope === 'detail' ? (screen.detail.keyField || 'code') : kf;
    const body = isNew
      ? { key: dataKey, action: 'add', row }
      : { key: dataKey, action: 'update', keyField: kfd, keyValue: String(row[kfd]), row };
    const j = await api.datasetPost(body);
    setNotice(j.ok ? 'Guardado' : j.msg || 'Error');
    if (j.ok) { setEditing(null); openScreen(screen.id); }
  }

  async function saveForm() {
    const kf = keyFieldOf(screen);
    const body = formNew
      ? { key: screen.dataRef, action: 'add', row: formDraft }
      : { key: screen.dataRef, action: 'update', keyField: kf, keyValue: String(rows[formIdx]?.[kf]), row: formDraft };
    const j = await api.datasetPost(body);
    setNotice(j.ok ? 'Guardado' : j.msg || 'Error');
    if (j.ok) openScreen(screen.id);
  }

  async function delForm() {
    if (formNew) return;
    const kf = keyFieldOf(screen);
    const row = rows[formIdx];
    if (!row) return;
    if (!confirm('¿Eliminar ' + row[kf] + '?')) return;
    const j = await api.datasetPost({ key: screen.dataRef, action: 'delete', keyField: kf, keyValue: String(row[kf]) });
    setNotice(j.ok ? 'Eliminado' : j.msg || 'Error');
    if (j.ok) openScreen(screen.id);
  }

  function fieldEditor(f, draft, setDraft) {
    const v = draft[f.id];
    if (f.type === 'checkbox')
      return <input type="checkbox" checked={!!v} onChange={(e) => setDraft({ ...draft, [f.id]: e.target.checked })} />;
    if (f.type === 'checklist') {
      const arr = Array.isArray(v) ? v : (v ? String(v).split(/[,;]/).map((s) => s.trim()) : []);
      return (
        <div className="checklist">
          {(f.options || []).map((o) => (
            <label key={o} className="chk-item">
              <input type="checkbox" checked={arr.includes(o)} onChange={(e) => {
                const next = e.target.checked ? [...arr, o] : arr.filter((x) => x !== o);
                setDraft({ ...draft, [f.id]: next });
              }} /> {o}
            </label>
          ))}
        </div>
      );
    }
    if (f.type === 'select')
      return (
        <select value={v ?? ''} onChange={(e) => setDraft({ ...draft, [f.id]: e.target.value })}>
          <option value="" />
          {(f.options || []).map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
      );
    if (f.type === 'lookup') {
      const opts = lookups[f.lookup] || [];
      return (
        <select value={v ?? ''} onChange={(e) => setDraft({ ...draft, [f.id]: e.target.value })}>
          <option value="" />
          {opts.map((o) => <option key={o.value} value={o.value}>{o.label} ({o.value})</option>)}
        </select>
      );
    }
    if (isMoney(f))
      return <input type="number" step="0.01" value={v ?? ''} onChange={(e) => setDraft({ ...draft, [f.id]: e.target.value === '' ? null : Number(e.target.value) })} />;
    return <input value={v ?? ''} readOnly={!formNew && keyFieldOf(screen) === f.id && draft === formDraft} onChange={(e) => setDraft({ ...draft, [f.id]: e.target.value })} />;
  }

  async function del() {
    if (!sel || !screen) return;
    const kf = keyFieldOf(screen);
    if (!confirm('¿Eliminar ' + sel[kf] + '?')) return;
    const j = await api.datasetPost({ key: screen.dataRef, action: 'delete', keyField: kf, keyValue: String(sel[kf]) });
    setNotice(j.ok ? 'Eliminado' : j.msg || 'Error');
    if (j.ok) openScreen(screen.id);
  }

  function exportExcel() {
    if (!screen) return;
    const cols = screen.grid?.columns || [];
    const cell = (v) => {
      const s = v == null ? '' : String(v);
      return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
    };
    const lines = [cols.map((c) => cell(c.label || c.id)).join(',')];
    visible.forEach((r) => lines.push(cols.map((c) => cell(r[c.id])).join(',')));
    const blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = String(screen.title || screen.id).replace(/[^A-Za-z0-9_\-]+/g, '_') + '.csv';
    a.click();
    URL.revokeObjectURL(a.href);
    setNotice('Excel/CSV exportado (' + visible.length + ' filas)');
  }

  function printList() {
    if (!screen) return;
    const cols = screen.grid?.columns || [];
    const w = window.open('', '_blank');
    if (!w) { window.print(); return; }
    const th = cols.map((c) => '<th>' + (c.label || c.id) + '</th>').join('');
    const body = visible.map((r) => '<tr>' + cols.map((c) => '<td>' + fmt(r[c.id], c) + '</td>').join('') + '</tr>').join('');
    w.document.write('<!doctype html><html><head><title>' + (screen.title || '') + '</title>' +
      '<style>body{font:12px Segoe UI,sans-serif}table{border-collapse:collapse;width:100%}' +
      'th,td{border:1px solid #ccc;padding:4px 6px}th{background:#eee}</style></head><body>' +
      '<h2>' + (screen.title || '') + '</h2><table><thead><tr>' + th + '</tr></thead><tbody>' + body +
      '</tbody></table></body></html>');
    w.document.close();
    setTimeout(() => { try { w.print(); } catch (e) {} }, 250);
  }

  const cols = screen?.grid?.columns || [];
  const filterCols = useMemo(
    () => cols.filter((c) => c.type === 'select' && Array.isArray(c.options) && c.options.length),
    [cols]
  );
  const visible = useMemo(() => {
    const f = q.toLowerCase().trim();
    const fields = screen?.searchFields || cols.map((c) => c.id);
    let list = rows.filter((r) => {
      if (f && !fields.some((k) => String(r[k] ?? '').toLowerCase().includes(f))) return false;
      for (const [cid, val] of Object.entries(colFilters)) {
        if (val !== '' && val != null && String(r[cid] ?? '') !== String(val)) return false;
      }
      return true;
    });
    if (sortCol) {
      const col = cols.find((c) => c.id === sortCol) || { id: sortCol };
      const dir = sortDir === 'desc' ? -1 : 1;
      list = list.slice().sort((a, b) => {
        const va = a[sortCol], vb = b[sortCol];
        if (isMoney(col) || col.type === 'number') {
          const na = Number(va), nb = Number(vb);
          if (!Number.isNaN(na) && !Number.isNaN(nb)) return dir * (na - nb);
        }
        if (col.type === 'checkbox') return dir * ((va ? 1 : 0) - (vb ? 1 : 0));
        return dir * String(va ?? '').localeCompare(String(vb ?? ''), 'es', { sensitivity: 'base', numeric: true });
      });
    }
    return list;
  }, [rows, q, screen, cols, colFilters, sortCol, sortDir]);

  const pageCount = Math.max(1, Math.ceil(visible.length / pageSize) || 1);
  const safePage = Math.min(page, pageCount);
  const pageRows = useMemo(() => {
    const p = Math.min(page, Math.max(1, Math.ceil(visible.length / pageSize) || 1));
    const start = (p - 1) * pageSize;
    return visible.slice(start, start + pageSize);
  }, [visible, page, pageSize]);

  const fmt = (v, c) => isMoney(c) && v != null && v !== ''
    ? Number(v).toLocaleString('es', { minimumFractionDigits: 2 })
    : c.type === 'checkbox' ? (v ? '✔' : '') : (v == null ? '' : String(v));

  function toggleSort(id) {
    if (sortCol === id) setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    else { setSortCol(id); setSortDir('asc'); }
  }
  function openEditNav(row, isNew) {
    if (isNew) {
      setEditing({ isNew: true, row: {} });
      setEditNavIdx(-1);
      return;
    }
    const idx = visible.findIndex((r) => String(r[keyFieldOf(screen)]) === String(row[keyFieldOf(screen)]));
    setEditNavIdx(idx);
    setEditing({ isNew: false, row: { ...row } });
  }
  function navEdit(act) {
    if (!screen || !visible.length || editing?.isNew) return;
    let i = editNavIdx;
    if (act === 'first') i = 0;
    else if (act === 'prev') i = Math.max(0, i - 1);
    else if (act === 'next') i = Math.min(visible.length - 1, i + 1);
    else if (act === 'last') i = visible.length - 1;
    setEditNavIdx(i);
    setEditing({ isNew: false, row: { ...visible[i] } });
  }

  if (view === 'login')
    return (
      <div className="login-wrap">
        <button className="theme-fab" onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>{theme === 'dark' ? 'Dark' : 'Light'}</button>
        <div className="login-card">
          <div className="login-brand">FiveTech ERP</div>
          <div className="login-sub">Rama 100% web · frontend React</div>
          <form onSubmit={doLogin}>
            <label>Usuario</label>
            <input value={user} onChange={(e) => setUser(e.target.value)} />
            <label>Clave</label>
            <input type="password" value={pass} onChange={(e) => setPass(e.target.value)} />
            <label>Fecha de trabajo</label>
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            <button type="submit">Entrar</button>
            <div className="login-error">{error}</div>
          </form>
          <button type="button" className="tool-toggle" onClick={() => setTool(!tool)}>Opciones de vista (ayuda)</button>
          {tool && (
            <div className="tool-panel">
              <div className="tool-row"><span>Ahora está en:</span> <b>{ramaLabel}</b></div>
              <div className="tool-row">
                <span><b>1 · Login directo — versión PC</b></span>
                <div className="tool-note">Aplicación de este equipo. Login clásico: <a href="/login" onClick={(e) => onMountClick(e, '/login')}>/login</a></div>
              </div>
              <div className="tool-row">
                <span><b>2 · WebView + HTTP</b></span>
                <div className="tool-note">App de escritorio + navegador (como Edge con localhost:2222/portal).</div>
                <nav className="tool-links">
                  <a href="/portal/" onClick={(e) => { e.preventDefault(); openExternal('http://127.0.0.1:2222/portal/'); }}>Abrir portal en el navegador</a>
                </nav>
              </div>
              <div className="tool-row">
                <span><b>3 · Web 100%</b> — elija la vista (mismos datos)</span>
                <nav className="tool-links">
                  <a href="/web-vanilla/index.html" onClick={(e) => onMountClick(e, '/web-vanilla/index.html')}>Vanilla</a>
                  <a href="/web-angular/index.html" onClick={(e) => onMountClick(e, '/web-angular/index.html')}>Angular</a>
                  <a href="/web-react/index.html" onClick={(e) => onMountClick(e, '/web-react/index.html')}>React</a>
                  <a href="/web-vue/index.html" onClick={(e) => onMountClick(e, '/web-vue/index.html')}>Vue</a>
                  <a href="/portal/" onClick={(e) => onMountClick(e, '/portal/')}>Menú…</a>
                </nav>
              </div>
              <div className="tool-row">
                <span><b>Acceso por la red</b></span>
                <div className="tool-note"><b>Intranet:</b> en otro PC/celular de la oficina use la dirección de abajo.</div>
                <nav className="tool-links">
                  <input className="tool-ip" value={ip} onChange={(e) => setIp(e.target.value)} placeholder="ej. 192.168.1.20" />
                  <button type="button" className="btn" onClick={() => openExternal(remoteUrl)}>Probar</button>
                  <button type="button" className="btn" onClick={() => navigator.clipboard.writeText(remoteUrl).then(() => { setCopiedUrl(true); setTimeout(() => setCopiedUrl(false), 1400); })}>{copiedUrl ? '¡Copiado!' : 'Copiar enlace'}</button>
                </nav>
                <div className="tool-note">Enlace: {remoteUrl}</div>
                <div className="tool-note"><b>Remoto (internet):</b> solo si sistemas habilitó acceso seguro (VPN o túnel).</div>
              </div>
            </div>
          )}
        </div>
      </div>
    );

  return (
    <div className="app">
      <header className="topbar">
        <div className="topbar-left">
          <button type="button" className="btn-icon-bar" title={sidebarCollapsed ? 'Mostrar menú' : 'Ocultar menú'}
            aria-expanded={!sidebarCollapsed}
            onClick={() => setSidebarCollapsed((c) => !c)}>☰</button>
          <span className="brand">FiveTech ERP</span>
          <span className="branch-tag">rama {rama} · react{version ? ' · v' + version : ''}</span>
          <button type="button" className="btn-ghost btn-dash" title="Ir al dashboard FWH" onClick={goDashboard}>Dashboard</button>
        </div>
        <div className="topbar-right">
          <select value={ctx?.company || ''} disabled={ctx?.canSwitchCompany === false} onChange={(e) => switchTo('company', e.target.value)}>
            {(ctx?.companies || []).map((c) => <option key={c.code} value={c.code}>{c.name || c.code}</option>)}
          </select>
          <select value={ctx?.app || ''} disabled={ctx?.canSwitchApp === false} onChange={(e) => switchTo('app', e.target.value)}>
            {(ctx?.apps || []).map((a) => <option key={a.id} value={a.id}>{a.label || a.id}</option>)}
          </select>
          <input type="date" value={date} onChange={(e) => { setDate(e.target.value); api.cmd('workdate', e.target.value); }} />
          <span className="user-chip">{ctx?.company} · {ctx?.appLabel || ctx?.app} · {ctx?.isAdmin ? 'admin' : 'usuario'}</span>
          <button className="btn-ghost" onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>{theme === 'dark' ? 'Dark' : 'Light'}</button>
          <button className="btn-ghost" onClick={async () => { await api.cmd('logout'); setView('login'); setCtx(null); }}>Salir</button>
        </div>
      </header>
      <div className={'body' + (sidebarCollapsed ? ' sidebar-collapsed' : '')}>
        <nav className="sidebar" aria-label="Módulos">
          <div className="nav-pin">
            <button type="button" className="nav-item dash" onClick={goDashboard}>⊞ Dashboard</button>
          </div>
          {modules.map((sec) => {
            const sid = sec.id || sec.title;
            const closed = !!secCollapsed[sid];
            return (
              <div key={sid} className={'nav-group' + (closed ? ' collapsed' : '')}>
                <button type="button" className="nav-section" onClick={() => toggleSec(sid)}>
                  <span>{sec.title}</span><span className="chev">▼</span>
                </button>
                <div className="nav-group-body">
                  {(sec.items || []).filter((i) => i.screen).map((it) => (
                    <button key={it.id} type="button"
                      className={'nav-item' + (it.sub ? ' sub' : '') + (screenKey === it.screen ? ' active' : '')}
                      onClick={() => openScreen(it.screen)}>
                      {it.label}
                    </button>
                  ))}
                </div>
              </div>
            );
          })}
          <div className={'nav-group' + (secCollapsed.__tools ? ' collapsed' : '')}>
            <button type="button" className="nav-section" onClick={() => toggleSec('__tools')}>
              <span>Herramientas</span><span className="chev">▼</span>
            </button>
            <div className="nav-group-body">
              <button type="button" className={'nav-item' + (screenKey === '__procs' ? ' active' : '')} onClick={openProcesses}>Procesos</button>
            </div>
          </div>
        </nav>
        <main className="main">
          {procs ? (
            <>
              <div className="screen-head">
                <h2>Procesos</h2>
                <span className="layout-tag">handlers: {(procs.handlers || []).length}</span>
              </div>
              <div className="proc-list">
                {(procs.items || []).map((it) => (
                  <div className="proc-row" key={it.key}>
                    <div><b>{it.title || it.key}</b><div className="proc-sub">{it.key} · handler: {it.handler || '—'}</div></div>
                    <button className="btn" onClick={() => runProcess(it)}>Ejecutar</button>
                  </div>
                ))}
              </div>
              <pre className="proc-out">{procOut}</pre>
            </>
          ) : !screen ? <div className="empty">Selecciona un módulo.</div> : (
            <>
              <div className="screen-head">
                <h2>{screen.title}</h2>
                {isListScreen(screen) && (
                  <div className="toolbar">
                    <input className="search" placeholder="Buscar…" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} />
                    {hasTb(screen, 'add') && <button className="btn primary" onClick={() => openEditNav(null, true)}>+ Nuevo</button>}
                    {hasTb(screen, 'edit') && <button className="btn" disabled={!sel} onClick={() => sel && openEditNav(sel, false)}>Editar</button>}
                    {hasTb(screen, 'delete') && <button className="btn danger" disabled={!sel} onClick={del}>Eliminar</button>}
                    {hasTb(screen, 'print') && <button className="btn" onClick={printList}>Imprimir</button>}
                    {hasTb(screen, 'pdf') && <button className="btn" onClick={printList}>PDF</button>}
                    {hasTb(screen, 'excel') && <button className="btn" onClick={exportExcel}>Excel</button>}
                    {hasTb(screen, 'refresh') && <button className="btn" onClick={() => openScreen(screen.id)}>Refrescar</button>}
                  </div>
                )}
              </div>
              {notice && <div className="notice">{notice}</div>}
              {isListScreen(screen) && filterCols.length > 0 && (
                <div className="list-filters">
                  {filterCols.map((c) => (
                    <label key={c.id} className="filter-chip">{c.label}
                      <select value={colFilters[c.id] || ''} onChange={(e) => { setColFilters({ ...colFilters, [c.id]: e.target.value }); setPage(1); }}>
                        <option value="">(todos)</option>
                        {(c.options || []).map((o) => <option key={o} value={o}>{o}</option>)}
                      </select>
                    </label>
                  ))}
                  <button type="button" className="btn" onClick={() => { setColFilters({}); setQ(''); setPage(1); }}>Limpiar filtros</button>
                </div>
              )}
              {isFormScreen(screen) ? (
                <div className="form-layout">
                  <aside className="form-nav">
                    <div className="form-nav-title">Registros</div>
                    {rows.map((r, i) => (
                      <button key={i} type="button" className={'form-nav-item' + (i === formIdx && !formNew ? ' active' : '')}
                        onClick={() => { setFormNew(false); setFormIdx(i); setFormDraft({ ...r }); }}>
                        {(r[keyFieldOf(screen)] ?? '') + (r.name ? ' · ' + r.name : '')}
                      </button>
                    ))}
                  </aside>
                  <div className="form-main">
                    <div className="toolbar" style={{ padding: '8px 12px' }}>
                      {hasTb(screen, 'add') && <button className="btn primary" onClick={() => { setFormNew(true); setFormDraft({}); }}>+ Nuevo</button>}
                      <button className="btn primary" onClick={saveForm}>Guardar</button>
                      {hasTb(screen, 'delete') && <button className="btn danger" disabled={formNew} onClick={delForm}>Eliminar</button>}
                      {hasTb(screen, 'refresh') && <button className="btn" onClick={() => openScreen(screen.id)}>Refrescar</button>}
                      <span className="rowcount">{formNew ? 'Nuevo' : ((rows.length ? formIdx + 1 : 0) + ' / ' + rows.length)}</span>
                    </div>
                    <div className="form-tabs">
                      {(screen.tabs || [{ id: 'all', label: 'Datos', fields: (screen.fields || []).map((f) => f.id) }]).map((t) => (
                        <button key={t.id} type="button" className={'form-tab' + (formTab === t.id ? ' active' : '')} onClick={() => setFormTab(t.id)}>{t.label || t.id}</button>
                      ))}
                    </div>
                    <div className="form form-body">
                      {(screen.fields || []).filter((f) => {
                        const tab = (screen.tabs || []).find((t) => t.id === formTab) || { fields: (screen.fields || []).map((x) => x.id) };
                        return (tab.fields || []).includes(f.id);
                      }).map((f) => (
                        <div key={f.id} className={'field' + (f.type === 'checkbox' ? ' chk' : '')}>
                          <label>{f.label}{f.required ? ' *' : ''}</label>
                          {fieldEditor(f, formDraft, setFormDraft)}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              ) : isMasterDetail(screen) ? (
                <div className="md-layout">
                  <section className="md-master">
                    <div className="md-head">
                      <b>Maestro</b>
                      <div className="toolbar">
                        {hasTb(screen, 'add') && <button className="btn primary" onClick={() => setEditing({ isNew: true, row: {}, scope: 'master' })}>+ Nuevo</button>}
                        {hasTb(screen, 'edit') && <button className="btn" disabled={!sel} onClick={() => sel && setEditing({ isNew: false, row: { ...sel }, scope: 'master' })}>Editar</button>}
                        {hasTb(screen, 'delete') && <button className="btn danger" disabled={!sel} onClick={async () => {
                          if (!sel) return;
                          const kf = keyFieldOf(screen);
                          if (!confirm('¿Eliminar ' + sel[kf] + '?')) return;
                          const j = await api.datasetPost({ key: screen.dataRef, action: 'delete', keyField: kf, keyValue: String(sel[kf]) });
                          setNotice(j.ok ? 'Eliminado' : j.msg || 'Error');
                          if (j.ok) openScreen(screen.id);
                        }}>Eliminar</button>}
                        {hasTb(screen, 'excel') && <button className="btn" onClick={exportExcel}>Excel</button>}
                        {hasTb(screen, 'refresh') && <button className="btn" onClick={() => openScreen(screen.id)}>Refrescar</button>}
                        <input className="search" placeholder="Buscar…" value={q} onChange={(e) => setQ(e.target.value)} />
                      </div>
                    </div>
                    <div className="grid-wrap">
                      <table>
                        <thead><tr>{cols.map((c) => <th key={c.id}>{c.label}</th>)}</tr></thead>
                        <tbody>
                          {visible.map((r, i) => (
                            <tr key={i} className={sel === r ? 'sel' : ''} onClick={() => { setSel(r); setSelDet(null); }} onDoubleClick={() => setEditing({ isNew: false, row: { ...r }, scope: 'master' })}>
                              {cols.map((c) => <td key={c.id} className={c.align === 'right' || isMoney(c) ? 'right' : ''}>{fmt(r[c.id], c)}</td>)}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </section>
                  <section className="md-detail">
                    <div className="md-head">
                      <b>{screen.detail?.title || 'Detalle'}</b>
                      <div className="toolbar">
                        <button className="btn primary" disabled={!sel} onClick={() => {
                          const mk = screen.detail?.masterKey || keyFieldOf(screen);
                          setEditing({ isNew: true, row: { [mk]: sel[keyFieldOf(screen)] }, scope: 'detail' });
                        }}>+ Línea</button>
                        <button className="btn" disabled={!selDet} onClick={() => selDet && setEditing({ isNew: false, row: { ...selDet }, scope: 'detail' })}>Editar</button>
                        <button className="btn danger" disabled={!selDet} onClick={async () => {
                          if (!selDet) return;
                          const dk = screen.detail.keyField || 'code';
                          if (!confirm('¿Eliminar ' + selDet[dk] + '?')) return;
                          const j = await api.datasetPost({ key: screen.detail.dataRef, action: 'delete', keyField: dk, keyValue: String(selDet[dk]) });
                          setNotice(j.ok ? 'Eliminado' : j.msg || 'Error');
                          if (j.ok) openScreen(screen.id);
                        }}>Eliminar</button>
                      </div>
                    </div>
                    <div className="grid-wrap">
                      <table>
                        <thead><tr>{(screen.detail?.grid?.columns || []).map((c) => <th key={c.id}>{c.label}</th>)}</tr></thead>
                        <tbody>
                          {detailRows.filter((r) => sel && String(r[screen.detail?.masterKey || keyFieldOf(screen)]) === String(sel[keyFieldOf(screen)])).map((r, i) => (
                            <tr key={i} className={selDet === r ? 'sel' : ''} onClick={() => setSelDet(r)} onDoubleClick={() => setEditing({ isNew: false, row: { ...r }, scope: 'detail' })}>
                              {(screen.detail?.grid?.columns || []).map((c) => <td key={c.id} className={c.align === 'right' || isMoney(c) ? 'right' : ''}>{fmt(r[c.id], c)}</td>)}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </section>
                </div>
              ) : isListScreen(screen) ? (
                <>
                  <div className="grid-wrap">
                    <table>
                      <thead>
                        <tr>
                          {cols.map((c) => (
                            <th key={c.id}
                              className={['sortable', sortCol === c.id ? 'sorted' : '', c.align === 'right' || isMoney(c) ? 'right' : ''].filter(Boolean).join(' ')}
                              onClick={() => toggleSort(c.id)}
                              title="Clic para ordenar"
                            >
                              {c.label} <span className="sort-ind">{sortCol === c.id ? (sortDir === 'asc' ? '▲' : '▼') : ''}</span>
                            </th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {pageRows.length === 0 ? (
                          <tr><td colSpan={Math.max(cols.length, 1)} className="empty-cell">Sin registros con los filtros actuales</td></tr>
                        ) : pageRows.map((r, i) => (
                          <tr key={i} className={sel && String(sel[keyFieldOf(screen)]) === String(r[keyFieldOf(screen)]) ? 'sel' : ''}
                            onClick={() => setSel(r)}
                            onDoubleClick={() => hasTb(screen, 'edit') && openEditNav(r, false)}>
                            {cols.map((c) => <td key={c.id} className={c.align === 'right' || isMoney(c) ? 'right' : ''}>{fmt(r[c.id], c)}</td>)}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  <div className="list-foot">
                    <div className="foot-left">
                      <span className="rowcount">
                        {visible.length
                          ? `${(safePage - 1) * pageSize + 1}–${Math.min(safePage * pageSize, visible.length)} de ${visible.length}` +
                            (visible.length !== rows.length ? ` (total ${rows.length})` : '') + ' filas'
                          : `0 / ${rows.length} filas`}
                      </span>
                      <label className="page-size">Filas
                        <select value={pageSize} onChange={(e) => { setPageSize(Number(e.target.value) || 25); setPage(1); }}>
                          {[10, 25, 50, 100].map((n) => <option key={n} value={n}>{n}</option>)}
                        </select>
                      </label>
                    </div>
                    <div className="foot-nav">
                      <button type="button" className="btn btn-icon" disabled={safePage <= 1} onClick={() => setPage(1)}>«</button>
                      <button type="button" className="btn btn-icon" disabled={safePage <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>‹</button>
                      <span className="pg-info">Pág. {safePage} / {pageCount}</span>
                      <button type="button" className="btn btn-icon" disabled={safePage >= pageCount} onClick={() => setPage((p) => p + 1)}>›</button>
                      <button type="button" className="btn btn-icon" disabled={safePage >= pageCount} onClick={() => setPage(pageCount)}>»</button>
                    </div>
                  </div>
                </>
              ) : (
                <div className="empty">Layout <b>{screen.layout || 'especial'}</b> — lista, form y master-detail cubiertos; resto en shell HTTP. Ver PROPUESTA/SUSTENTO.</div>
              )}
            </>
          )}
        </main>
      </div>

      {editing && screen && (() => {
        const eCols = editing.scope === 'detail' ? (screen.detail?.grid?.columns || []) : cols;
        const ekf = editing.scope === 'detail' ? (screen.detail?.keyField || 'code') : keyFieldOf(screen);
        const showNav = !editing.isNew && !editing.scope && visible.length > 0;
        return (
        <div className="overlay" onKeyDown={(e) => { if (e.key === 'Escape') setEditing(null); }}>
          <div className="modal modal-form" role="dialog" aria-modal="true">
            <div className="modal-head">
              <h3>{editing.isNew ? 'Nuevo registro' : 'Editar ' + (editing.row[ekf] ?? '')}</h3>
              {showNav && (
                <div className="modal-nav">
                  <button type="button" className="btn btn-icon" disabled={editNavIdx <= 0} onClick={() => navEdit('first')}>«</button>
                  <button type="button" className="btn btn-icon" disabled={editNavIdx <= 0} onClick={() => navEdit('prev')}>‹</button>
                  <span className="pg-info">{editNavIdx >= 0 ? (editNavIdx + 1) + ' / ' + visible.length : '—'}</span>
                  <button type="button" className="btn btn-icon" disabled={editNavIdx < 0 || editNavIdx >= visible.length - 1} onClick={() => navEdit('next')}>›</button>
                  <button type="button" className="btn btn-icon" disabled={editNavIdx < 0 || editNavIdx >= visible.length - 1} onClick={() => navEdit('last')}>»</button>
                </div>
              )}
            </div>
            <div className="form">
              {eCols.map((c) => (
                <div key={c.id} className={'field' + (c.type === 'checkbox' ? ' chk' : '')}>
                  <label>{c.label}</label>
                  {c.type === 'checkbox'
                    ? <input type="checkbox" checked={!!editing.row[c.id]} onChange={(e) => setEditing({ ...editing, row: { ...editing.row, [c.id]: e.target.checked } })} />
                    : c.type === 'select'
                      ? <select value={editing.row[c.id] ?? ''} onChange={(e) => setEditing({ ...editing, row: { ...editing.row, [c.id]: e.target.value } })}>
                          {(c.options || []).map((o) => <option key={o} value={o}>{o}</option>)}
                        </select>
                      : <input type={isMoney(c) ? 'number' : 'text'} step="0.01" value={editing.row[c.id] ?? ''}
                          readOnly={!editing.isNew && ekf === c.id}
                          onChange={(e) => setEditing({ ...editing, row: { ...editing.row, [c.id]: isMoney(c) ? (e.target.value === '' ? null : Number(e.target.value)) : e.target.value } })} />}
                </div>
              ))}
            </div>
            <div className="modal-actions">
              <button className="btn" onClick={() => setEditing(null)}>Cancelar</button>
              <button className="btn primary" onClick={save}>Guardar</button>
            </div>
          </div>
        </div>
        );
      })()}
    </div>
  );
}
