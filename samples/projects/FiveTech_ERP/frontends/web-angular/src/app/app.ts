import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterOutlet } from '@angular/router';
import { ButtonModule } from 'primeng/button';
import { TableModule } from 'primeng/table';
import { InputTextModule } from 'primeng/inputtext';
import { InputNumberModule } from 'primeng/inputnumber';
import { SelectModule } from 'primeng/select';
import { CheckboxModule } from 'primeng/checkbox';
import { DialogModule } from 'primeng/dialog';
import { TagModule } from 'primeng/tag';
import { ApiService, Ctx, GridCol, MetaDoc, ModuleSection } from './api.service';

interface Rama {
  branch: 'pc' | 'hibrida' | 'web';
  webview: boolean;
  nativeBridge: boolean;
}

@Component({
  selector: 'app-root',
  imports: [
    FormsModule, RouterOutlet,
    ButtonModule, TableModule, InputTextModule, InputNumberModule,
    SelectModule, CheckboxModule, DialogModule, TagModule
  ],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App {
  private api = inject(ApiService);

  readonly rama = signal<Rama>(this.detectRama());
  readonly view = signal<'login' | 'app'>('login');
  readonly loginError = signal('');
  readonly busy = signal(false);
  user = 'admin';
  pass = '1234';
  workDate = this.today();
  readonly theme = signal<string>((() => { try { return localStorage.getItem('dw-theme') || 'dark'; } catch { return 'dark'; } })());
  readonly version = signal('');
  readonly procs = signal<{ items?: any[]; handlers?: any[] } | null>(null);
  readonly procOut = signal('');
  readonly toolOpen = signal(false);
  readonly sidebarCollapsed = signal((() => {
    try { return localStorage.getItem('dw-sidebar') === '1'; } catch { return false; }
  })());
  readonly secCollapsed = signal<Record<string, boolean>>((() => {
    try { return JSON.parse(localStorage.getItem('dw-nav-sec') || '{}'); } catch { return {}; }
  })());
  readonly copied = signal(false);
  readonly mount = location.pathname.split('/')[1] || 'portal';
  readonly pcCmd = 'set ZWEB_FRONT=' + (location.pathname.split('/')[1] || 'portal') + ' && FiveTech_ERP_local.exe';

  copyPc() {
    navigator.clipboard.writeText(this.pcCmd).then(() => {
      this.copied.set(true);
      setTimeout(() => this.copied.set(false), 1200);
    });
  }

  ip = (() => {
    const h = location.hostname;
    return !h || h === 'localhost' ? '127.0.0.1' : h;
  })();
  readonly copiedUrl = signal(false);
  get remoteUrl(): string {
    return 'http://' + (this.ip.trim() || location.hostname || '127.0.0.1') + ':2222/portal/';
  }
  ramaLabel(): string {
    const b = this.rama().branch;
    if (b === 'pc') return '1 · PC (escritorio)';
    if (b === 'hibrida') return '2 · WebView + HTTP';
    return '3 · Web 100%';
  }
  /** Abre el navegador del sistema (como Edge con la dirección). No cambia esta ventana. */
  openExternal(url: string) {
    try { url = new URL(url, location.href).href; } catch { /* keep */ }
    const wv = (window as any).chrome?.webview;
    if (wv) {
      try { wv.postMessage(JSON.stringify({ cmd: 'open', url })); } catch { /* */ }
      try { wv.postMessage('open:' + url); } catch { /* */ }
    }
    fetch('/api/open-browser', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'url=' + encodeURIComponent(url),
      credentials: 'same-origin',
    }).catch(() => {});
    if (!wv) window.open(url, '_blank', 'noopener');
  }
  openRemote() {
    this.openExternal(this.remoteUrl);
  }
  openLocal(ev?: Event) {
    ev?.preventDefault();
    this.openExternal('http://127.0.0.1:2222/portal/');
  }
  openMount(ev: Event, href: string) {
    ev.preventDefault();
    this.openExternal(href);
  }
  copyRemote() {
    navigator.clipboard.writeText(this.remoteUrl).then(() => {
      this.copiedUrl.set(true);
      setTimeout(() => this.copiedUrl.set(false), 1200);
    });
  }

  readonly ctx = signal<Ctx | null>(null);
  readonly modules = signal<ModuleSection[]>([]);
  readonly activeScreenKey = signal('');
  readonly screen = signal<MetaDoc | null>(null);
  readonly rows = signal<any[]>([]);
  readonly search = signal('');
  readonly colFilters = signal<Record<string, string>>({});
  readonly selected = signal<any | null>(null);
  readonly pageSize = 15;
  readonly rowsPerPageOptions = [10, 15, 25, 50, 100];
  readonly loading = signal(false);
  readonly edit = signal<{ isNew: boolean; row: Record<string, any> } | null>(null);
  readonly notice = signal('');
  readonly detailRows = signal<any[]>([]);
  readonly selectedDetail = signal<any | null>(null);
  readonly formIdx = signal(0);
  readonly formNew = signal(false);
  formDraft: Record<string, any> = {};
  readonly formTab = signal('all');
  lookups: Record<string, { value: any; label: any }[]> = {};
  editScope: 'master' | 'detail' = 'master';

  readonly cols = computed<GridCol[]>(() => this.screen()?.grid?.columns ?? []);
  readonly detailCols = computed<GridCol[]>(() => (this.screen() as any)?.detail?.grid?.columns ?? []);
  readonly formFields = computed<any[]>(() => (this.screen() as any)?.fields ?? []);
  readonly formTabs = computed<any[]>(() => {
    const sc: any = this.screen();
    if (!sc) return [];
    return sc.tabs?.length ? sc.tabs : [{ id: 'all', label: 'Datos', fields: (sc.fields || []).map((f: any) => f.id) }];
  });
  readonly formFieldsVisible = computed(() => {
    const fields = this.formFields();
    const tab = this.formTabs().find((t: any) => t.id === this.formTab()) || this.formTabs()[0];
    const ids = tab?.fields || [];
    return fields.filter((f: any) => ids.includes(f.id));
  });
  readonly detailVisible = computed(() => {
    const sc: any = this.screen();
    const sel = this.selected();
    if (!sc?.detail || !sel) return [];
    const mk = sc.detail.masterKey || this.keyFieldOf(sc);
    return this.detailRows().filter((r) => String(r[mk]) === String(sel[this.keyFieldOf(sc)]));
  });
  readonly filterCols = computed(() =>
    this.cols().filter((c: any) => c.type === 'select' && Array.isArray(c.options) && c.options.length)
  );
  readonly visibleRows = computed(() => {
    const f = this.search().toLowerCase().trim();
    const rows = this.rows();
    const fields = this.screen()?.searchFields ?? this.cols().map((c) => c.id);
    const filters = this.colFilters();
    return rows.filter((r) => {
      if (f && !fields.some((k) => String(r[k] ?? '').toLowerCase().includes(f))) return false;
      for (const [cid, val] of Object.entries(filters)) {
        if (val !== '' && val != null && String(r[cid] ?? '') !== String(val)) return false;
      }
      return true;
    });
  });
  setColFilter(id: string, value: string) {
    this.colFilters.update((m) => ({ ...m, [id]: value }));
  }
  clearListFilters() {
    this.colFilters.set({});
    this.search.set('');
  }
  optSelect(options: string[] | undefined) {
    return (options || []).map((o) => ({ label: o, value: o }));
  }
  readonly companyOptions = computed(() => (this.ctx()?.companies ?? []).map((c) => ({ label: c.name || c.code, value: c.code })));
  readonly appOptions = computed(() => (this.ctx()?.apps ?? []).map((a) => ({ label: a.label || a.id, value: a.id })));

  constructor() {
    document.documentElement.classList.toggle('p-dark', this.theme() === 'dark');
    document.documentElement.setAttribute('data-theme', this.theme());
    this.boot();
  }

  private detectRama(): Rama {
    const w = window as any;
    const webview = !!(w.chrome && w.chrome.webview);
    const nativeBridge = typeof w.SendToFWH === 'function';
    return { branch: webview ? (nativeBridge ? 'hibrida' : 'pc') : 'web', webview, nativeBridge };
  }

  private today(): string {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  toggleTheme() {
    const t = this.theme() === 'dark' ? 'light' : 'dark';
    this.theme.set(t);
    document.documentElement.setAttribute('data-theme', t);
    document.documentElement.classList.toggle('p-dark', t === 'dark');
    document.documentElement.classList.toggle('light', t === 'light');
    try { localStorage.setItem('dw-theme', t); } catch { /* privado */ }
  }

  goDashboard() {
    location.href = '/dashboard.html';
  }

  toggleSidebar() {
    const next = !this.sidebarCollapsed();
    this.sidebarCollapsed.set(next);
    try { localStorage.setItem('dw-sidebar', next ? '1' : '0'); } catch { /* */ }
  }

  toggleSec(id: string) {
    const m = { ...this.secCollapsed() };
    m[id] = !m[id];
    this.secCollapsed.set(m);
    try { localStorage.setItem('dw-nav-sec', JSON.stringify(m)); } catch { /* */ }
  }

  secId(sec: ModuleSection): string {
    return (sec as any).id || sec.title || 'sec';
  }

  isSecCollapsed(id: string): boolean {
    return !!this.secCollapsed()[id];
  }

  onWorkdate(v: string) {
    this.workDate = v;
    this.api.cmd('workdate', v);
  }

  async openProcesses() {
    this.screen.set(null);
    this.activeScreenKey.set('__procs');
    const j = await this.api.processGet();
    this.procs.set(j.ok ? j : { items: [], handlers: [] });
    this.procOut.set('');
  }

  async runProcess(it: any) {
    this.procOut.set('Ejecutando ' + it.key + '…');
    const r = await this.api.processPost({ key: it.key, params: {} });
    this.procOut.set(JSON.stringify(r, null, 2));
  }

  private async boot() {
    try {
      const j = await this.api.context();
      if (j.ok) { this.ctx.set(j); await this.enterApp(); }
    } catch { /* sin sesión */ }
  }

  async onLogin() {
    this.busy.set(true);
    this.loginError.set('');
    try {
      const j = await this.api.login(this.user.trim(), this.pass, this.workDate);
      if (!j.ok) { this.loginError.set(j.msg || 'Credenciales inválidas'); return; }
      this.ctx.set(await this.api.context());
      await this.enterApp();
    } catch (e: any) {
      this.loginError.set(e?.message ?? 'Error de red');
    } finally {
      this.busy.set(false);
    }
  }

  private async enterApp() {
    this.view.set('app');
    const m = await this.api.meta('modules');
    const secs = m.ok ? (m.doc.sections ?? []) : [];
    this.modules.set(secs);
    const va = await this.api.meta('app');
    const ver = va.ok ? String(va.doc['version'] ?? '') : '';
    if (ver) this.version.set(ver);
    const first = secs.flatMap((s) => s.items ?? []).find((i) => i.screen && !i.sub)?.screen;
    if (first) this.openScreen(first);
  }

  isMasterDetail(doc: MetaDoc | null | undefined): boolean {
    return !!(doc && (doc.layout === 'master-detail' || doc.layout === 'document') && (doc as any).detail?.dataRef);
  }
  isFormScreen(doc: MetaDoc | null | undefined): boolean {
    return !!(doc && doc.layout === 'form' && Array.isArray((doc as any).fields) && (doc as any).fields.length);
  }
  isListScreen(doc: MetaDoc | null | undefined): boolean {
    if (!doc || this.isMasterDetail(doc) || this.isFormScreen(doc)) return false;
    return doc.layout === 'list' || !!(doc.dataRef && doc.grid?.columns?.length);
  }
  toolbarIds(doc: MetaDoc | null | undefined): string[] {
    const t = doc?.toolbar;
    if (Array.isArray(t) && t.length)
      return t.map((x: any) => typeof x === 'string' ? x : (x?.id || '')).filter(Boolean);
    return ['add', 'edit', 'delete', 'refresh'];
  }
  hasTb(id: string): boolean {
    return this.toolbarIds(this.screen()).includes(id);
  }
  keyFieldOf(doc: MetaDoc | null | undefined): string {
    return doc?.keyField || doc?.grid?.columns?.[0]?.id || 'code';
  }

  async loadLookups(fields: any[]) {
    for (const f of fields || []) {
      if (f.type !== 'lookup' || !f.lookup || this.lookups[f.lookup]) continue;
      try {
        const lm = await this.api.meta(f.lookup);
        if (!lm.ok) continue;
        const vf = (lm.doc as any).valueField || 'code';
        const lf = (lm.doc as any).labelField || 'name';
        const dd = await this.api.dataset((lm.doc as any).dataRef);
        this.lookups[f.lookup] = (dd.ok ? dd.rows : []).map((r: any) => ({ value: r[vf], label: r[lf] != null ? r[lf] : r[vf] }));
      } catch { this.lookups[f.lookup] = []; }
    }
  }

  async openScreen(key: string) {
    this.procs.set(null);
    this.activeScreenKey.set(key);
    this.loading.set(true);
    this.selected.set(null);
    this.selectedDetail.set(null);
    this.detailRows.set([]);
    this.formNew.set(false);
    this.formIdx.set(0);
    this.search.set('');
    this.colFilters.set({});
    try {
      const m = await this.api.meta(key);
      if (!m.ok) { this.screen.set(null); return; }
      this.screen.set(m.doc);
      const doc: any = m.doc;
      if (this.isMasterDetail(m.doc)) {
        const d = await this.api.dataset(doc.dataRef);
        const masters = d.ok ? d.rows : [];
        this.rows.set(masters);
        this.selected.set(masters[0] || null);
        const dd = await this.api.dataset(doc.detail.dataRef);
        this.detailRows.set(dd.ok ? dd.rows : []);
      } else if (this.isFormScreen(m.doc)) {
        const d = await this.api.dataset(doc.dataRef);
        const rs = d.ok ? d.rows : [];
        this.rows.set(rs);
        this.formDraft = rs[0] ? { ...rs[0] } : {};
        this.formTab.set(doc.tabs?.[0]?.id || 'all');
        await this.loadLookups(doc.fields || []);
      } else if (this.isListScreen(m.doc) && m.doc.dataRef) {
        const d = await this.api.dataset(m.doc.dataRef);
        this.rows.set(d.ok ? d.rows : []);
      } else {
        this.rows.set([]);
      }
    } finally {
      this.loading.set(false);
    }
  }

  selectFormRow(i: number) {
    this.formNew.set(false);
    this.formIdx.set(i);
    this.formDraft = { ...this.rows()[i] };
  }
  newFormRow() {
    this.formNew.set(true);
    this.formDraft = {};
  }
  setFormField(id: string, value: any) {
    this.formDraft = { ...this.formDraft, [id]: value };
  }
  optList(opts?: string[]) {
    return (opts || []).map((o) => ({ label: o, value: o }));
  }
  lookupOpts(key?: string) {
    return (this.lookups[key || ''] || []).map((o) => ({ label: o.label + ' (' + o.value + ')', value: o.value }));
  }
  async saveForm() {
    const sc = this.screen();
    if (!sc?.dataRef) return;
    const kf = this.keyFieldOf(sc);
    const body = this.formNew()
      ? { key: sc.dataRef, action: 'add', row: this.formDraft }
      : { key: sc.dataRef, action: 'update', keyField: kf, keyValue: String(this.rows()[this.formIdx()]?.[kf]), row: this.formDraft };
    const j = await this.api.datasetPost(body as any);
    this.notice.set(j.ok ? 'Guardado' : (j.msg ?? 'Error'));
    if (j.ok) await this.openScreen(sc.id);
  }
  async delForm() {
    if (this.formNew()) return;
    const sc = this.screen();
    const row = this.rows()[this.formIdx()];
    if (!sc?.dataRef || !row) return;
    const kf = this.keyFieldOf(sc);
    if (!confirm('¿Eliminar ' + row[kf] + '?')) return;
    const j = await this.api.datasetPost({ key: sc.dataRef, action: 'delete', keyField: kf, keyValue: String(row[kf]) });
    this.notice.set(j.ok ? 'Eliminado' : (j.msg ?? 'Error'));
    if (j.ok) await this.openScreen(sc.id);
  }

  onCompanyChange(code: string) { this.switchCmd('company', code); }
  onAppChange(id: string) { this.switchCmd('app', id); }
  private async switchCmd(action: string, value: string) {
    const j = await this.api.cmd(action, value);
    if (j.ok) {
      this.ctx.set(await this.api.context());
      await this.enterApp();
    } else {
      this.notice.set(j.msg ?? 'No autorizado');
    }
  }

  openNew(scope: 'master' | 'detail' = 'master') {
    this.editScope = scope;
    let row: any = {};
    if (scope === 'detail' && this.selected()) {
      const sc: any = this.screen();
      const mk = sc?.detail?.masterKey || this.keyFieldOf(sc);
      row[mk] = this.selected()[this.keyFieldOf(sc)];
    }
    this.edit.set({ isNew: true, row });
  }
  openEdit(row?: any, scope: 'master' | 'detail' = 'master') {
    const r = row ?? (scope === 'detail' ? this.selectedDetail() : this.selected());
    if (!r) return;
    this.editScope = scope;
    this.edit.set({ isNew: false, row: { ...r } });
  }
  openEditDetail(row?: any) { this.openEdit(row, 'detail'); }
  async deleteDetail() {
    const sc: any = this.screen();
    const row = this.selectedDetail();
    if (!sc?.detail || !row) return;
    const kf = sc.detail.keyField || 'code';
    if (!confirm('¿Eliminar ' + row[kf] + '?')) return;
    const j = await this.api.datasetPost({ key: sc.detail.dataRef, action: 'delete', keyField: kf, keyValue: String(row[kf]) });
    this.notice.set(j.ok ? 'Eliminado' : (j.msg ?? 'Error'));
    if (j.ok) await this.openScreen(sc.id);
  }
  closeEdit() {
    this.edit.set(null);
  }

  async saveEdit() {
    const e = this.edit();
    const sc: any = this.screen();
    if (!e || !sc) return;
    const dataKey = this.editScope === 'detail' ? sc.detail?.dataRef : sc.dataRef;
    const kf = this.editScope === 'detail' ? (sc.detail?.keyField || 'code') : this.keyFieldOf(sc);
    if (!dataKey) return;
    const body = e.isNew
      ? { key: dataKey, action: 'add', row: e.row }
      : { key: dataKey, action: 'update', keyField: kf, keyValue: String(e.row[kf]), row: e.row };
    const j = await this.api.datasetPost(body as any);
    this.notice.set(j.ok ? 'Guardado' : (j.msg ?? 'Error al guardar'));
    if (j.ok) { this.edit.set(null); await this.openScreen(sc.id); }
  }

  async deleteSelected() {
    const sc = this.screen();
    const row = this.selected();
    if (!sc?.dataRef || !row) return;
    const kf = this.keyFieldOf(sc);
    if (!confirm('¿Eliminar ' + row[kf] + '?')) return;
    const j = await this.api.datasetPost({ key: sc.dataRef, action: 'delete', keyField: kf, keyValue: String(row[kf]) });
    this.notice.set(j.ok ? 'Eliminado' : (j.msg ?? 'Error'));
    if (j.ok) await this.openScreen(sc.id);
  }

  exportExcel() {
    const sc = this.screen();
    const cols = this.cols();
    const rows = this.visibleRows();
    if (!sc || !cols.length) return;
    const cell = (v: any) => {
      const s = v == null ? '' : String(v);
      return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
    };
    const lines = [cols.map((c) => cell(c.label || c.id)).join(',')];
    rows.forEach((r) => lines.push(cols.map((c) => cell(r[c.id])).join(',')));
    const blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = String(sc.title || sc.id).replace(/[^A-Za-z0-9_\-]+/g, '_') + '.csv';
    a.click();
    URL.revokeObjectURL(a.href);
    this.notice.set('Excel/CSV exportado (' + rows.length + ' filas)');
  }

  printList() {
    const sc = this.screen();
    const cols = this.cols();
    const rows = this.visibleRows();
    if (!sc) return;
    const w = window.open('', '_blank');
    if (!w) { window.print(); return; }
    const th = cols.map((c) => '<th>' + (c.label || c.id) + '</th>').join('');
    const body = rows.map((r) => '<tr>' + cols.map((c) => '<td>' + this.fmt(r[c.id], c) + '</td>').join('') + '</tr>').join('');
    w.document.write('<!doctype html><html><head><title>' + (sc.title || '') + '</title>' +
      '<style>body{font:12px Segoe UI,sans-serif}table{border-collapse:collapse;width:100%}' +
      'th,td{border:1px solid #ccc;padding:4px 6px}th{background:#eee}</style></head><body>' +
      '<h2>' + (sc.title || '') + '</h2><table><thead><tr>' + th + '</tr></thead><tbody>' + body +
      '</tbody></table></body></html>');
    w.document.close();
    setTimeout(() => { try { w.print(); } catch { /* */ } }, 250);
  }

  async logout() {
    await this.api.cmd('logout');
    this.ctx.set(null);
    this.modules.set([]);
    this.screen.set(null);
    this.view.set('login');
  }

  fmt(v: any, c: GridCol): string {
    if (c.type === 'money' || c.format === 'money')
      return v == null || v === '' ? '' : Number(v).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (c.type === 'checkbox') return v ? 'Sí' : '';
    return v == null ? '' : String(v);
  }

  setField(id: string, value: any) {
    const e = this.edit();
    if (e) e.row[id] = value;
  }
}
