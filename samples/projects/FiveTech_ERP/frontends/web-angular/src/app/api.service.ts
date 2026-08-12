import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

export interface MetaDoc {
  id: string;
  kind?: string;
  layout?: string;
  title?: string;
  dataRef?: string;
  keyField?: string;
  searchFields?: string[];
  grid?: { columns: GridCol[] };
  toolbar?: string[];
  sections?: ModuleSection[];
  [k: string]: unknown;
}
export interface GridCol {
  id: string;
  label: string;
  type?: string;
  options?: string[];
  align?: string;
  format?: string;
}
export interface ModuleSection {
  id: string;
  title: string;
  items: { id: string; label: string; icon?: string; screen?: string; sub?: boolean; active?: boolean }[];
}
export interface Ctx {
  ok: boolean;
  company?: string;
  companyName?: string;
  app?: string;
  appLabel?: string;
  isAdmin?: boolean;
  companies?: { code: string; name?: string }[];
  apps?: { id: string; label?: string }[];
  canSwitchCompany?: boolean;
  canSwitchApp?: boolean;
}

@Injectable({ providedIn: 'root' })
export class ApiService {
  private http = inject(HttpClient);

  private async j<T>(p: Promise<unknown>): Promise<T> {
    return (await p) as T;
  }

  login(user: string, password: string, workDate?: string) {
    return this.j<any>(firstValueFrom(this.http.post('/api/login', { user, password, workDate })));
  }
  context() {
    return this.j<Ctx>(firstValueFrom(this.http.get('/api/context')));
  }
  meta(key: string) {
    return this.j<{ ok: boolean; doc: MetaDoc; msg?: string }>(
      firstValueFrom(this.http.get('/api/meta', { params: { key } }))
    );
  }
  dataset(key: string) {
    return this.j<{ ok: boolean; rows: any[]; msg?: string }>(
      firstValueFrom(this.http.get('/api/dataset', { params: { key } }))
    );
  }
  datasetPost(body: { key: string; action: string; row?: any; keyField?: string; keyValue?: string }) {
    return this.j<{ ok: boolean; msg?: string }>(firstValueFrom(this.http.post('/api/dataset', body)));
  }
  processGet() {
    return this.j<{ ok: boolean; items?: any[]; handlers?: any[] }>(firstValueFrom(this.http.get('/api/process')));
  }
  processPost(body: { key: string; params?: any }) {
    return this.j<any>(firstValueFrom(this.http.post('/api/process', body)));
  }
  cmd(action: string, a1?: string, a2?: string) {
    const p = new URLSearchParams({ action });
    if (a1 !== undefined) p.set('a1', a1);
    if (a2 !== undefined) p.set('a2', a2);
    return this.j<{ ok: boolean; msg?: string }>(
      firstValueFrom(
        this.http.post('/api/cmd', p.toString(), {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        })
      )
    );
  }
}
