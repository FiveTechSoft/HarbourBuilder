# -*- coding: utf-8 -*-
"""Apply FiveTech_ERP shell UI patches to www/dashboard.html (atomic).

Features:
  - scrollable left menu (CSS Grid min-height fix)
  - collapsible menu branches + fechaSubmenus / alternaBarra
  - bottom status bar
  - Salir del sistema button
  - list pagination chrome where missing
"""
from __future__ import annotations

from pathlib import Path

DASH = Path(__file__).resolve().parent / "www" / "dashboard.html"

CSS_OLD = """  .app { display: grid; grid-template-columns: 248px 1fr; height: 100vh; }
  .sidebar {
    background: var(--side); border-right: 1px solid var(--line);
    display: flex; flex-direction: column; padding: 18px 14px 12px;
  }
  .side-brand { display: flex; align-items: center; gap: 12px; padding: 4px 8px 16px; flex-shrink: 0; }
  .side-logo {
    width: 40px; height: 40px; border-radius: 12px;
    background: linear-gradient(135deg, var(--blue), #0f172a);
    color: #fff; font-weight: 800; font-size: 12px;
    display: flex; align-items: center; justify-content: center;
  }
  .side-brand h1 { font-size: 1rem; font-weight: 700; line-height: 1.15; color: var(--text); }
  .side-brand p  { font-size: .75rem; color: var(--muted); margin-top: 2px; }
  .side-search {
    display: flex; align-items: center; gap: 8px; flex-shrink: 0;
    background: var(--surface); border: 1px solid var(--line);
    border-radius: 10px; padding: 0 12px; height: 38px; margin: 0 4px 14px;
  }
  .side-search input {
    border: 0; background: transparent; outline: none; width: 100%;
    font-size: .85rem; color: var(--text);
  }
  .nav { flex: 1 1 auto; min-height: 0; overflow-y: auto; padding: 0 4px; }
  .nav-section {
    font-size: .68rem; font-weight: 700; letter-spacing: .08em;
    text-transform: uppercase; color: var(--muted); margin: 14px 8px 6px;
  }
  .nav-item {
    display: flex; align-items: center; gap: 10px;
    padding: 9px 12px; border-radius: 10px; color: var(--text-2); font-size: .9rem;
    cursor: pointer; border: 0; background: transparent; width: 100%; text-align: left;
  }
  .nav-item:hover { background: var(--nav-hover); }
  .nav-item.active { background: var(--blue-soft); color: var(--blue); font-weight: 600; }
  .nav-item.sub { padding-left: 28px; font-size: .86rem; color: var(--text-3); }
  .side-foot { border-top: 1px solid var(--line); padding-top: 10px; margin-top: 8px; flex-shrink: 0; }
  .btn-logout {
    display: flex; align-items: center; gap: 8px; width: 100%; border: 0;
    background: transparent; color: var(--muted); padding: 10px 12px; border-radius: 10px;
    cursor: pointer; font-size: .88rem;
  }
  .btn-logout:hover { background: var(--logout-hover-bg); color: var(--logout-hover); }
  .main { display: flex; flex-direction: column; min-width: 0; height: 100vh; padding: 16px 18px 14px; }
  .topbar {
    display: flex; align-items: center; justify-content: space-between;
    margin-bottom: 12px; padding: 0 4px;
  }
  .crumbs { color: var(--muted); font-size: .85rem; }
  .crumbs strong { color: var(--text); font-weight: 600; }
  .top-right { display: flex; align-items: center; gap: 10px; }
  .btn-theme {
    height: 34px; padding: 0 12px; border-radius: 999px;
    border: 1px solid var(--line); background: var(--surface-2); color: var(--text-2);
    font-size: .78rem; font-weight: 600; cursor: pointer;
    display: inline-flex; align-items: center; gap: 6px;
  }
  .btn-theme:hover { border-color: var(--blue); color: var(--blue); }
  .pill {
    background: var(--surface-2); border: 1px solid var(--line); border-radius: 999px;
    padding: 6px 12px; font-size: .8rem; color: var(--muted);
  }
  .pill b { color: var(--text); }
  .avatar {
    width: 34px; height: 34px; border-radius: 50%;
    background: linear-gradient(135deg, #3b82f6, var(--blue));
    color: #fff; display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: .8rem;
  }"""

CSS_NEW = r"""  /* === FiveTech shell UI (do not strip: scroll + status + collapse) === */
  .shell {
    display: flex; flex-direction: column; height: 100vh; min-height: 0; overflow: hidden;
  }
  .app {
    display: grid; grid-template-columns: 248px 1fr;
    flex: 1 1 auto; min-height: 0; overflow: hidden;
  }
  .sidebar {
    background: var(--side); border-right: 1px solid var(--line);
    display: flex; flex-direction: column; padding: 18px 14px 12px;
    min-height: 0; height: 100%; overflow: hidden;
  }
  .side-brand {
    display: flex; align-items: center; gap: 12px; padding: 4px 8px 16px;
    flex-shrink: 0; position: relative;
  }
  .side-logo {
    width: 40px; height: 40px; border-radius: 12px;
    background: linear-gradient(135deg, var(--blue), #0f172a);
    color: #fff; font-weight: 800; font-size: 12px;
    display: flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .side-brand-txt { min-width: 0; flex: 1; }
  .side-brand h1 { font-size: 1rem; font-weight: 700; line-height: 1.15; color: var(--text); }
  .side-brand p  { font-size: .75rem; color: var(--muted); margin-top: 2px; }
  .side-brand-acts {
    display: flex; align-items: center; gap: 4px; flex-shrink: 0; margin-left: auto;
  }
  .btn-recolhe {
    width: 22px; height: 22px; padding: 0;
    display: flex; align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--line); border-radius: 6px;
    color: var(--muted); cursor: pointer;
    transition: color .15s, border-color .15s, background .15s;
  }
  .btn-recolhe:hover {
    color: var(--text); border-color: var(--muted); background: var(--nav-hover);
  }
  .btn-recolhe svg { width: 13px; height: 13px; display: block; transition: transform .2s; }
  .app.sidebar-recolhida { grid-template-columns: 58px 1fr; }
  .sidebar.recolhida { padding: 12px 6px 10px; }
  .sidebar.recolhida .side-brand {
    flex-direction: column; align-items: center; gap: 8px; padding: 4px 0 12px;
  }
  .sidebar.recolhida .side-brand-txt,
  .sidebar.recolhida .side-search,
  .sidebar.recolhida .nav-arrow,
  .sidebar.recolhida .nav-header span,
  .sidebar.recolhida .nav-item .lbl,
  .sidebar.recolhida .nav-branch,
  .sidebar.recolhida .btn-menu-edit,
  .sidebar.recolhida .btn-logout .lbl,
  .sidebar.recolhida #btn-fecha-subs { display: none !important; }
  .sidebar.recolhida .side-brand-acts { margin-left: 0; }
  .sidebar.recolhida .btn-recolhe { margin: 0 auto; }
  .sidebar.recolhida #btn-recolhe svg { transform: rotate(180deg); }
  .sidebar.recolhida .nav { padding-left: 2px; padding-right: 2px; }
  .sidebar.recolhida .nav-header {
    justify-content: center; gap: 0; padding: 9px 0; letter-spacing: 0;
  }
  .sidebar.recolhida .nav-header::before {
    content: attr(data-initial); font-size: .75rem; font-weight: 800; color: var(--text-2);
  }
  .sidebar.recolhida .side-foot { padding-top: 8px; }
  .sidebar.recolhida .btn-logout { justify-content: center; padding: 10px 0; }
  .side-search {
    display: flex; align-items: center; gap: 8px; flex-shrink: 0;
    background: var(--surface); border: 1px solid var(--line);
    border-radius: 10px; padding: 0 12px; height: 38px; margin: 0 4px 14px;
  }
  .side-search input {
    border: 0; background: transparent; outline: none; width: 100%;
    font-size: .85rem; color: var(--text);
  }
  .nav {
    flex: 1 1 auto; min-height: 0; overflow-x: hidden; overflow-y: auto;
    padding: 0 4px 4px; overscroll-behavior: contain;
  }
  .nav::-webkit-scrollbar { width: 8px; }
  .nav::-webkit-scrollbar-track { background: transparent; }
  .nav::-webkit-scrollbar-thumb {
    background: var(--line); border-radius: 8px; border: 2px solid var(--side);
  }
  .nav-group { margin-bottom: 4px; }
  .nav-header {
    display: flex; align-items: center; gap: 8px; width: 100%;
    padding: 8px 10px; border: 0; border-radius: 8px;
    background: transparent; color: var(--muted); cursor: pointer;
    font-size: .68rem; font-weight: 700; letter-spacing: .08em;
    text-transform: uppercase; text-align: left; user-select: none;
    transition: background .15s, color .15s;
  }
  .nav-header:hover { background: var(--nav-hover); color: var(--text-2); }
  .nav-header.open { color: var(--blue); }
  .nav-header .nav-arrow {
    margin-left: auto; width: 12px; height: 12px; flex-shrink: 0;
    color: var(--muted); transition: transform .2s;
  }
  .nav-header.open .nav-arrow { transform: rotate(90deg); color: var(--blue); }
  .nav-branch { display: none; padding: 0 0 4px; }
  .nav-branch.open { display: block; }
  .nav-item {
    display: flex; align-items: center; gap: 10px;
    padding: 9px 12px; border-radius: 10px; color: var(--text-2); font-size: .9rem;
    cursor: pointer; border: 0; background: transparent; width: 100%; text-align: left;
  }
  .nav-item:hover { background: var(--nav-hover); }
  .nav-item.active { background: var(--blue-soft); color: var(--blue); font-weight: 600; }
  .nav-item.sub { padding-left: 28px; font-size: .86rem; color: var(--text-3); }
  .side-foot { border-top: 1px solid var(--line); padding-top: 10px; margin-top: 8px; flex-shrink: 0; }
  .btn-logout {
    display: flex; align-items: center; gap: 8px; width: 100%; border: 0;
    background: transparent; color: var(--muted); padding: 10px 12px; border-radius: 10px;
    cursor: pointer; font-size: .88rem;
  }
  .btn-logout:hover { background: var(--logout-hover-bg); color: var(--logout-hover); }
  .main {
    display: flex; flex-direction: column; min-width: 0; min-height: 0;
    height: 100%; padding: 16px 18px 14px; overflow: hidden;
  }
  #status-bar {
    height: 28px; flex-shrink: 0;
    background: var(--side); border-top: 1px solid var(--line);
    display: flex; align-items: center; padding: 0 12px 0 16px;
    font-size: 11px; color: var(--text-3); user-select: none; overflow: hidden;
  }
  #status-bar .sb-item {
    display: flex; align-items: center; gap: 5px;
    padding: 0 14px 0 0; margin-right: 14px;
    border-right: 1px solid var(--line); height: 100%;
    white-space: nowrap; flex-shrink: 0;
  }
  #status-bar .sb-item:last-child { border-right: none; margin-right: 0; padding-right: 0; }
  #status-bar .sb-item svg { opacity: 0.55; flex-shrink: 0; width: 13px; height: 13px; }
  #status-bar .sb-txt {
    overflow: hidden; text-overflow: ellipsis; max-width: 220px; color: var(--text-2);
  }
  #status-bar .sb-clic { cursor: pointer; }
  #status-bar .sb-clic:hover .sb-txt,
  #status-bar .sb-clic:hover svg { color: var(--blue); opacity: 1; }
  #status-bar .sb-spacer { flex: 1 1 auto; min-width: 8px; border: 0; margin: 0; padding: 0; }
  #status-bar .sb-msg { max-width: 280px; color: var(--muted); font-style: italic; }
  #status-bar .sb-warn .sb-txt { color: #d97706; }
  .topbar {
    display: flex; align-items: center; justify-content: space-between;
    margin-bottom: 12px; padding: 0 4px; flex-shrink: 0;
  }
  .crumbs { color: var(--muted); font-size: .85rem; }
  .crumbs strong { color: var(--text); font-weight: 600; }
  .top-right { display: flex; align-items: center; gap: 10px; }
  .btn-theme {
    height: 34px; padding: 0 12px; border-radius: 999px;
    border: 1px solid var(--line); background: var(--surface-2); color: var(--text-2);
    font-size: .78rem; font-weight: 600; cursor: pointer;
    display: inline-flex; align-items: center; gap: 6px;
  }
  .btn-theme:hover { border-color: var(--blue); color: var(--blue); }
  .pill {
    background: var(--surface-2); border: 1px solid var(--line); border-radius: 999px;
    padding: 6px 12px; font-size: .8rem; color: var(--muted);
  }
  .pill b { color: var(--text); }
  .avatar {
    width: 34px; height: 34px; border-radius: 50%;
    background: linear-gradient(135deg, #3b82f6, var(--blue));
    color: #fff; display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: .8rem; flex-shrink: 0;
  }
  .btn-salir {
    height: 34px; padding: 0 12px; border-radius: 999px;
    border: 1px solid var(--line); background: var(--surface-2); color: var(--text-2);
    font-size: .78rem; font-weight: 600; cursor: pointer;
    display: inline-flex; align-items: center; gap: 7px; flex-shrink: 0;
    font-family: inherit;
  }
  .btn-salir:hover {
    background: var(--logout-hover-bg); color: var(--logout-hover);
    border-color: var(--logout-hover);
  }
  .btn-salir svg { width: 14px; height: 14px; flex-shrink: 0; }
  .paginacao {
    display: flex; align-items: center; gap: 6px; flex-wrap: wrap; flex-shrink: 0;
  }
  .paginacao .info {
    font-size: 12px; color: var(--muted); min-width: 110px; text-align: center; white-space: nowrap;
  }
  .paginacao .spacer { flex: 1 1 auto; min-width: 4px; }
  .paginacao .btn.mini, .btn.mini {
    height: 28px; min-width: 28px; padding: 0 10px;
    border: 1px solid var(--line); border-radius: 6px; background: var(--surface-2);
    color: var(--text); cursor: pointer; font: inherit; font-size: 12px; font-weight: 500;
    display: inline-flex; align-items: center; justify-content: center;
  }
  .paginacao .btn.mini:hover:not(:disabled) { border-color: var(--blue); color: var(--blue); }
  .paginacao .btn.mini:disabled { opacity: .4; cursor: default; }
  #ws-meta .md-paginacao { margin: 0 14px 10px; }
"""

BODY_OLD_START = """<body class="__BODY_ADMIN_CLASS__">
<div class="app">
  <aside class="sidebar">
    <div class="side-brand">
      <div class="side-logo" id="brand-logo">ERP</div>
      <div>
        <h1 id="brand-name">FiveTech</h1>
        <p id="brand-sub">Desktop &amp; Web</p>
      </div>
    </div>
    <div class="side-search">
      <span style="opacity:.5">&#128269;</span>
      <input type="search" id="modsearch" placeholder="Search module...">
    </div>
    <nav class="nav" id="nav"><!-- filled from meta modules.json --></nav>
    <div class="side-foot">
      <button type="button" class="btn-menu-edit admin-only" id="btn-menu-edit" title="Edit app branding and menu (admin)">
        &#9998; Edit app
      </button>
      <button class="btn-logout" onclick="cmd('logout')">&#9211; Sign out</button>
    </div>
  </aside>

  <section class="main">
    <div class="topbar">
      <div class="crumbs">Clinic &rsaquo; <strong id="crumb">Appointments</strong></div>
      <div class="top-right">
        <button type="button" class="btn-theme" id="btn-theme" title="Toggle dark mode" aria-label="Toggle dark mode">
          <span id="theme-icon">&#9790;</span> <span id="theme-label">Dark</span>
        </button>
        <button type="button" class="btn-demo" id="btn-demo" title="Play product tour demo" aria-label="Play demo">
          &#9654; Demo
        </button>
        <button type="button" class="btn-theme admin-only" id="btn-design" title="Form designer (admin only)" aria-label="Form designer">
          &#9998; Design form
        </button>
        <span class="pill">Work date: <b>__WORKDATE__</b></span>
        <span class="pill">User: <b>__USER__</b></span>
        <div class="avatar">__AVATAR__</div>
      </div>
    </div>"""

BODY_NEW_START = """<body class="__BODY_ADMIN_CLASS__">
<div class="shell">
<div class="app">
  <aside class="sidebar">
    <div class="side-brand">
      <div class="side-logo" id="brand-logo">ERP</div>
      <div class="side-brand-txt">
        <h1 id="brand-name">FiveTech</h1>
        <p id="brand-sub">Desktop &amp; Web</p>
      </div>
      <div class="side-brand-acts">
        <button type="button" class="btn-recolhe" id="btn-fecha-subs"
          onclick="fechaSubmenus()" title="Fechar os submenus abertos"
          aria-label="Fechar os submenus abertos">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <polyline points="18 15 12 9 6 15"></polyline>
          </svg>
        </button>
        <button type="button" class="btn-recolhe" id="btn-recolhe"
          onclick="alternaBarra()" title="Recolher o menu"
          aria-label="Recolher o menu">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <polyline points="15 18 9 12 15 6"></polyline>
          </svg>
        </button>
      </div>
    </div>
    <div class="side-search">
      <span style="opacity:.5">&#128269;</span>
      <input type="search" id="modsearch" placeholder="Search module..." autocomplete="off">
    </div>
    <nav class="nav" id="nav"><!-- filled from meta modules.json --></nav>
    <div class="side-foot">
      <button type="button" class="btn-menu-edit admin-only" id="btn-menu-edit" title="Edit app branding and menu (admin)">
        &#9998; Edit app
      </button>
      <button class="btn-logout" onclick="cmd('logout')" title="Sign out">
        <span class="ico" aria-hidden="true">&#9211;</span><span class="lbl"> Sign out</span>
      </button>
    </div>
  </aside>

  <section class="main">
    <div class="topbar">
      <div class="crumbs">Clinic &rsaquo; <strong id="crumb">Appointments</strong></div>
      <div class="top-right">
        <button type="button" class="btn-theme" id="btn-theme" title="Toggle dark mode" aria-label="Toggle dark mode">
          <span id="theme-icon">&#9790;</span> <span id="theme-label">Dark</span>
        </button>
        <button type="button" class="btn-demo" id="btn-demo" title="Play product tour demo" aria-label="Play demo">
          &#9654; Demo
        </button>
        <button type="button" class="btn-theme admin-only" id="btn-design" title="Form designer (admin only)" aria-label="Form designer">
          &#9998; Design form
        </button>
        <div class="avatar" title="__USER__" id="top-avatar">__AVATAR__</div>
        <button type="button" class="btn-salir" id="btn-salir"
          title="Salir del sistema" aria-label="Salir del sistema"
          onclick="cmd('logout')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
            <polyline points="16 17 21 12 16 7"></polyline>
            <line x1="21" y1="12" x2="9" y2="12"></line>
          </svg>
          <span>Salir del sistema</span>
        </button>
      </div>
    </div>"""

STATUS_FOOTER = """
</div><!-- /.app -->
<footer id="status-bar" role="status" aria-live="polite">
  <div class="sb-item sb-clic" id="sb-user-item" title="Usuario">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
    </svg>
    <span class="sb-txt" id="sb-usuario">__USER__</span>
  </div>
  <div class="sb-item sb-clic" id="sb-company-item" title="Empresa">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
      <path d="M3 21h18M5 21V8l7-4 7 4v13M9 21v-5h6v5"/>
    </svg>
    <span class="sb-txt" id="sb-company">—</span>
  </div>
  <div class="sb-item" id="sb-db-item" title="Base de datos">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
      <ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
      <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
    </svg>
    <span class="sb-txt" id="sb-db">—</span>
  </div>
  <div class="sb-item sb-clic" id="sb-date-item" title="Fecha de trabajo">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
      <rect x="3" y="4" width="18" height="18" rx="2"/>
      <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
      <line x1="3" y1="10" x2="21" y2="10"/>
    </svg>
    <span class="sb-txt" id="sb-data">__WORKDATE__</span>
  </div>
  <div class="sb-item sb-spacer" aria-hidden="true"></div>
  <div class="sb-item"><span class="sb-txt sb-msg" id="sb-msg">Listo</span></div>
  <div class="sb-item" id="sb-clock-item">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
      <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
    </svg>
    <span class="sb-txt" id="sb-clock">—</span>
  </div>
  <div class="sb-item" title="Versión">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
      <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/>
      <line x1="7" y1="7" x2="7.01" y2="7"/>
    </svg>
    <span class="sb-txt" id="sb-versao">__APPVER__</span>
  </div>
</footer>
</div><!-- /.shell -->
"""

JS_SIDEBAR = r"""
/* ---------- FiveTech shell: status bar + collapsible menu ---------- */
var WORK_DATE = "__WORKDATE__";
var APP_VER = "__APPVER__";
var STATUS_BAR = { msgTimer: null, clockTimer: null };
var NAV_ARROW_SVG =
  '<svg class="nav-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
  'stroke-width="2" aria-hidden="true"><polyline points="9 18 15 12 9 6"></polyline></svg>';

function sbSetText(id, text) {
  var el = document.getElementById(id);
  if (el) el.textContent = (text == null || text === "") ? "—" : String(text);
}
function setStatusMsg(msg, kind) {
  var el = document.getElementById("sb-msg");
  if (!el) return;
  el.textContent = msg || "Listo";
  if (STATUS_BAR.msgTimer) clearTimeout(STATUS_BAR.msgTimer);
  if (msg && msg !== "Listo") {
    STATUS_BAR.msgTimer = setTimeout(function () { setStatusMsg("Listo"); }, 6000);
  }
}
function refreshStatusClock() {
  var el = document.getElementById("sb-clock");
  if (!el) return;
  var n = new Date(), h = n.getHours(), m = n.getMinutes(), s = n.getSeconds();
  el.textContent = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
}
function refreshStatusDb() {
  fetch("/api/db/status", { credentials: "same-origin", cache: "no-store" })
    .then(function (r) { return r.json(); })
    .then(function (j) {
      var txt, host;
      if (!j || !j.ok) { sbSetText("sb-db", "DB ?"); return; }
      host = j.host ? (String(j.host) + (j.port ? (":" + j.port) : "")) : "";
      if (j.driver === "dbfcdx" || j.backend === "dbfcdx")
        txt = "DBF " + (j.dbfDir || j.dataPath || "local");
      else if (host) txt = String(j.backend || j.driver || "db") + " @ " + host;
      else txt = String(j.backend || j.driver || "json");
      if (j.lastError) txt += " !";
      sbSetText("sb-db", txt);
    })
    .catch(function () { sbSetText("sb-db", "DB offline"); });
}
function refreshStatusCompany() {
  var c = "";
  try {
    c = (typeof APP_CONTEXT !== "undefined" && APP_CONTEXT.company) ||
      localStorage.getItem("dw-company") || "";
  } catch (e) {}
  sbSetText("sb-company", c || "(sin empresa)");
}
function initStatusBar() {
  var ver = APP_VER;
  try { if (APP_META && APP_META.version) ver = String(APP_META.version); } catch (e) {}
  sbSetText("sb-usuario", CURRENT_USER || "—");
  sbSetText("sb-data", WORK_DATE || "—");
  sbSetText("sb-versao", ver || "1.0.0");
  refreshStatusCompany();
  refreshStatusDb();
  refreshStatusClock();
  if (STATUS_BAR.clockTimer) clearInterval(STATUS_BAR.clockTimer);
  STATUS_BAR.clockTimer = setInterval(refreshStatusClock, 1000);
  setInterval(refreshStatusDb, 60000);
  var di = document.getElementById("sb-date-item");
  if (di) di.onclick = function () {
    var n = window.prompt("Fecha de trabajo (esta sesión):", WORK_DATE || "");
    if (n == null) return;
    n = String(n).trim();
    if (!n) return;
    WORK_DATE = n; sbSetText("sb-data", n); setStatusMsg("Fecha: " + n);
  };
  var ci = document.getElementById("sb-company-item");
  if (ci) ci.onclick = function () {
    var mid = (typeof moduleIdByScreen === "function") ? moduleIdByScreen("screen.context") : "";
    if (mid) cmd("nav", mid);
    else if (typeof showMetaScreen === "function") showMetaScreen("screen.context", "Company");
  };
}

function setNavBranchOpen(group, open) {
  if (!group) return;
  var branch = group.querySelector(".nav-branch");
  var hdr = group.querySelector(".nav-header");
  if (branch) branch.classList.toggle("open", !!open);
  if (hdr) {
    hdr.classList.toggle("open", !!open);
    hdr.setAttribute("aria-expanded", open ? "true" : "false");
  }
}
function toggleNavBranch(hdr) {
  var group = hdr && hdr.closest ? hdr.closest(".nav-group") : null;
  if (!group) return;
  var branch = group.querySelector(".nav-branch");
  setNavBranchOpen(group, !(branch && branch.classList.contains("open")));
}
function closeAllNavBranches() {
  var groups = document.querySelectorAll("#nav .nav-group"), i;
  for (i = 0; i < groups.length; i++) setNavBranchOpen(groups[i], false);
}
function fechaSubmenus() { closeAllNavBranches(); }
function alternaBarra(recolher) {
  var sb = document.querySelector(".sidebar");
  var app = document.querySelector(".app");
  var btn = document.getElementById("btn-recolhe");
  var hdrs, i, h, span, label;
  if (!sb) return;
  if (recolher === undefined) recolher = !sb.classList.contains("recolhida");
  sb.classList.toggle("recolhida", !!recolher);
  if (app) app.classList.toggle("sidebar-recolhida", !!recolher);
  if (btn) btn.title = recolher ? "Expandir o menu" : "Recolher o menu";
  hdrs = document.querySelectorAll("#nav .nav-header");
  for (i = 0; i < hdrs.length; i++) {
    h = hdrs[i];
    span = h.querySelector("span");
    label = span ? String(span.textContent || "").trim() : "";
    if (label) {
      h.setAttribute("data-initial", label.charAt(0).toUpperCase());
      if (recolher) {
        if (!h.getAttribute("data-tt")) h.setAttribute("data-tt", h.title || "");
        h.title = label;
      } else h.title = h.getAttribute("data-tt") || "";
    }
  }
  try { localStorage.setItem("fte_barra", recolher ? "1" : "0"); } catch (e) {}
}
function restoreBarraState() {
  var v = null;
  try { v = localStorage.getItem("fte_barra"); } catch (e) {}
  if (v === "1") alternaBarra(true);
}
document.addEventListener("click", function (e) {
  var sb = document.querySelector(".sidebar");
  var h;
  if (!sb || !sb.classList.contains("recolhida")) return;
  h = e.target && e.target.closest ? e.target.closest(".nav-header") : null;
  if (h) alternaBarra(false);
}, true);
function openNavBranchForItem(el) {
  if (!el || !el.closest) return;
  var g = el.closest(".nav-group");
  if (g) setNavBranchOpen(g, true);
}
function ensureActiveNavVisible() {
  var act = document.querySelector("#nav .nav-item.active");
  if (act) openNavBranchForItem(act);
}
function wireSidebarNav(nav) {
  var i, btns, hdrs;
  if (!nav) return;
  hdrs = nav.querySelectorAll(".nav-header");
  for (i = 0; i < hdrs.length; i++) {
    hdrs[i].onclick = function (e) { e.preventDefault(); toggleNavBranch(this); };
  }
  btns = nav.querySelectorAll(".nav-item");
  for (i = 0; i < btns.length; i++) {
    btns[i].onclick = function () {
      openNavBranchForItem(this);
      cmd("nav", this.getAttribute("data-id"));
    };
  }
}
function buildNavGroupHtml(secId, title, itemsHtml, forceOpen) {
  var open = !!forceOpen;
  var tit = title || secId || "Section";
  var initial = String(tit).charAt(0).toUpperCase() || "?";
  return "<div class='nav-group' data-sec='" + esc(secId || "") + "'>" +
    "<button type='button' class='nav-header" + (open ? " open" : "") +
    "' aria-expanded='" + (open ? "true" : "false") +
    "' data-initial='" + esc(initial) + "'>" +
    "<span>" + esc(tit) + "</span>" + NAV_ARROW_SVG +
    "</button>" +
    "<div class='nav-branch" + (open ? " open" : "") + "'>" + (itemsHtml || "") + "</div>" +
    "</div>";
}
function renderSidebarFromMeta() {
  var nav = document.getElementById("nav");
  var html = "", i, j, sec, it, ico, cls, label, items, itemsHtml, hasActive, openAll;
  try { applyAppBranding(APP_META); } catch (e) {}
  if (!nav) return;
  openAll = true;
  if (!MODULES || !MODULES.sections || !MODULES.sections.length) {
    html =
      buildNavGroupHtml("clinic", "Clinic",
        "<button type='button' class='nav-item' data-id='patients' data-screen='screen.patients'>" +
        "<span class='ico'>&#128100;</span><span class='lbl'> Patients</span></button>", true) +
      buildNavGroupHtml("workflow", "Workflow",
        "<button type='button' class='nav-item active' data-id='appointments' data-screen='screen.appointments'>" +
        "<span class='ico'>&#128197;</span><span class='lbl'> Appointments</span></button>", true);
    nav.innerHTML = html;
  } else {
    for (i = 0; i < MODULES.sections.length; i++) {
      items = MODULES.sections[i].items || [];
      for (j = 0; j < items.length; j++) {
        if (items[j].active) { openAll = false; break; }
      }
      if (!openAll) break;
    }
    for (i = 0; i < MODULES.sections.length; i++) {
      sec = MODULES.sections[i];
      items = sec.items || [];
      itemsHtml = "";
      hasActive = false;
      for (j = 0; j < items.length; j++) {
        it = items[j];
        ico = (it.icon && ICONS[it.icon]) ? ICONS[it.icon] : "";
        cls = "nav-item" + (it.sub ? " sub" : "") + (it.active ? " active" : "");
        if (it.active) hasActive = true;
        label = esc(it.label || it.id);
        itemsHtml += "<button type='button' class='" + cls + "' data-id='" + esc(it.id) +
          "' data-screen='" + esc(it.screen || "") + "'>";
        if (ico && !it.sub) itemsHtml += "<span class='ico'>" + ico + "</span>";
        itemsHtml += "<span class='lbl'>" + (ico && !it.sub ? " " : "") + label + "</span></button>";
      }
      html += buildNavGroupHtml(sec.id, sec.title || sec.id, itemsHtml, openAll || hasActive);
    }
    nav.innerHTML = html;
  }
  wireSidebarNav(nav);
  ensureActiveNavVisible();
  try { restoreBarraState(); } catch (e2) {}
}
/* ---------- end shell UI ---------- */
"""


def main() -> None:
    t = DASH.read_text(encoding="utf-8")
    if "/* === FiveTech shell UI" in t and "function fechaSubmenus" in t and 'id="status-bar"' in t:
        print("already patched")
        return

    # If partially patched, restore from git-ish raw by re-reading and force-applying
    # when shell CSS marker missing.
    if CSS_OLD not in t and "/* === FiveTech shell UI" not in t:
        # try flexible CSS replace around .app block
        import re
        m = re.search(
            r"  \.app \{ display: grid; grid-template-columns: 248px 1fr; height: 100vh; \}.*?  \.avatar \{[^}]+\}",
            t,
            flags=re.S,
        )
        if not m:
            raise SystemExit("CSS .app/.avatar block not found — abort")
        t = t[: m.start()] + CSS_NEW + t[m.end() :]
    elif CSS_OLD in t:
        t = t.replace(CSS_OLD, CSS_NEW, 1)
    # else already has CSS

    if BODY_OLD_START in t:
        t = t.replace(BODY_OLD_START, BODY_NEW_START, 1)
    elif 'class="shell"' not in t:
        raise SystemExit("body start not matched — abort")

    # Close shell after </section></div> before toast
    if 'id="status-bar"' not in t:
        needle = "  </section>\n</div>\n<div id=\"toast\"></div>"
        if needle not in t:
            needle = "  </section>\r\n</div>\r\n<div id=\"toast\"></div>"
        if needle not in t:
            # flexible
            import re
            m = re.search(r"  </section>\s*</div>\s*<div id=\"toast\"></div>", t)
            if not m:
                raise SystemExit("section/app close not found")
            t = t[: m.start()] + "  </section>\n" + STATUS_FOOTER + "\n<div id=\"toast\"></div>" + t[m.end() :]
        else:
            t = t.replace(needle, "  </section>\n" + STATUS_FOOTER + "\n<div id=\"toast\"></div>", 1)

    # Replace renderSidebarFromMeta function body block
    import re
    m = re.search(
        r"function renderSidebarFromMeta\(\) \{.*?\n\}\n\nfunction openPatientsFromMeta",
        t,
        flags=re.S,
    )
    if m:
        # Keep the original "function openPatientsFromMeta" trailer intact
        t = t[: m.start()] + JS_SIDEBAR + "\n\nfunction openPatientsFromMeta" + t[m.end() :]
        # If the match already ended with openPatientsFromMeta name, avoid double prefix
        t = t.replace(
            "function openPatientsFromMeta\nfunction openPatientsFromMeta",
            "function openPatientsFromMeta",
        )
        t = t.replace(
            "function openPatientsFromMetafunction openPatientsFromMeta",
            "function openPatientsFromMeta",
        )
    elif "function fechaSubmenus" not in t:
        # insert before first renderSidebarFromMeta if present
        idx = t.find("function renderSidebarFromMeta()")
        if idx < 0:
            raise SystemExit("renderSidebarFromMeta not found")
        # find end of that function naively
        m2 = re.search(r"function renderSidebarFromMeta\(\) \{.*?\n\}\n", t[idx:], flags=re.S)
        if not m2:
            raise SystemExit("could not replace renderSidebarFromMeta")
        end = idx + m2.end()
        t = t[:idx] + JS_SIDEBAR + "\n" + t[end:]

    # Ensure CURRENT_USER block has WORK_DATE if needed - optional

    # dashNav open branch
    old_nav = """  document.querySelectorAll(".nav-item").forEach(function (el) {
    el.classList.toggle("active", el.getAttribute("data-id") === id ||
      (id === "licensed" && el.getAttribute("data-id") === "appointments"));
  });"""
    new_nav = """  var activeEl = null;
  document.querySelectorAll("#nav .nav-item").forEach(function (el) {
    var on = el.getAttribute("data-id") === id ||
      (id === "licensed" && el.getAttribute("data-id") === "appointments");
    el.classList.toggle("active", on);
    if (on) activeEl = el;
  });
  if (activeEl && typeof openNavBranchForItem === "function") openNavBranchForItem(activeEl);"""
    if old_nav in t:
        t = t.replace(old_nav, new_nav, 1)

    old_demo = """function demoActivateNav(menuId) {
  if (!menuId) return;
  document.querySelectorAll(".nav-item").forEach(function (el) {
    el.classList.toggle("active", el.getAttribute("data-id") === menuId);
  });
}"""
    new_demo = """function demoActivateNav(menuId) {
  if (!menuId) return;
  var activeEl = null;
  document.querySelectorAll("#nav .nav-item").forEach(function (el) {
    var on = el.getAttribute("data-id") === menuId;
    el.classList.toggle("active", on);
    if (on) activeEl = el;
  });
  if (activeEl && typeof openNavBranchForItem === "function") openNavBranchForItem(activeEl);
}"""
    if old_demo in t:
        t = t.replace(old_demo, new_demo, 1)

    old_search = """document.getElementById("modsearch").addEventListener("input", function (e) {
  var q = (e.target.value || "").toLowerCase();
  document.querySelectorAll(".nav-item").forEach(function (el) {
    el.style.display = (!q || el.textContent.toLowerCase().indexOf(q) >= 0) ? "flex" : "none";
  });
});"""
    new_search = """document.getElementById("modsearch").addEventListener("input", function (e) {
  var q = (e.target.value || "").toLowerCase().trim();
  var groups = document.querySelectorAll("#nav .nav-group");
  var gi, group, items, ii, item, match, any, title, titleMatch;
  for (gi = 0; gi < groups.length; gi++) {
    group = groups[gi];
    items = group.querySelectorAll(".nav-item");
    any = false;
    title = group.querySelector(".nav-header span");
    titleMatch = !!(q && title && title.textContent.toLowerCase().indexOf(q) >= 0);
    for (ii = 0; ii < items.length; ii++) {
      item = items[ii];
      match = !q || titleMatch || item.textContent.toLowerCase().indexOf(q) >= 0;
      item.style.display = match ? "flex" : "none";
      if (match) any = true;
    }
    group.style.display = any ? "" : "none";
    if (q && any && typeof setNavBranchOpen === "function") setNavBranchOpen(group, true);
  }
  if (!q && typeof ensureActiveNavVisible === "function") ensureActiveNavVisible();
});"""
    if old_search in t:
        t = t.replace(old_search, new_search, 1)

    # toast + status
    if "function dashToast(msg)" in t and "setStatusMsg" not in t[t.find("function dashToast") : t.find("function dashToast") + 300]:
        t = t.replace(
            """function dashToast(msg) {
  var t = document.getElementById("toast");
  t.textContent = msg; t.classList.add("show");
  setTimeout(function () { t.classList.remove("show"); }, 1800);
}""",
            """function dashToast(msg) {
  var t = document.getElementById("toast");
  t.textContent = msg; t.classList.add("show");
  setTimeout(function () { t.classList.remove("show"); }, 1800);
  try { setStatusMsg(String(msg || "")); } catch (e) {}
}""",
            1,
        )

    # init
    if "initStatusBar()" not in t:
        t = t.replace(
            "try { renderSidebarFromMeta(); } catch (e) {}",
            "try { renderSidebarFromMeta(); } catch (e) {}\ntry { initStatusBar(); } catch (e) {}",
            1,
        )

    # pagination chrome for meta-foot if missing
    if 'id="pg-prim"' not in t and "meta-foot meta-single" in t:
        t = t.replace(
            """      <div class="meta-foot meta-single">
        <span class="hint">
          <b id="meta-n-single">0</b> records""",
            """      <div class="meta-foot meta-single">
        <div class="paginacao" id="paginacao-list" data-pager="list">
          <button type="button" class="btn mini" id="pg-prim" onclick="vaiPagina(1)" title="Primeira" disabled>«</button>
          <button type="button" class="btn mini" id="pg-prev" onclick="vaiPagina(pagInfo.pagina - 1)" disabled>‹ Anterior</button>
          <span class="info" id="pg-info">Página 1 de 1</span>
          <button type="button" class="btn mini" id="pg-next" onclick="vaiPagina(pagInfo.pagina + 1)" disabled>Próxima ›</button>
          <button type="button" class="btn mini" id="pg-ult" onclick="vaiPagina(pagInfo.paginas)" title="Última" disabled>»</button>
          <span class="spacer"></span>
        </div>
        <span class="hint">
          <b id="meta-n-single">0</b> records""",
            1,
        )

    if 'data-pager="appt"' not in t and "ws-foot" in t:
        t = t.replace(
            """        <div class="ws-foot">
          <span class="hint">
            <b id="st-rows">0</b> records""",
            """        <div class="ws-foot">
          <div class="paginacao" id="paginacao-appt" data-pager="appt">
            <button type="button" class="btn mini" data-pg="first" title="Primeira" disabled>«</button>
            <button type="button" class="btn mini" data-pg="prev" disabled>‹ Anterior</button>
            <span class="info" data-pg="info">Página 1 de 1</span>
            <button type="button" class="btn mini" data-pg="next" disabled>Próxima ›</button>
            <button type="button" class="btn mini" data-pg="last" title="Última" disabled>»</button>
            <span class="spacer"></span>
          </div>
          <span class="hint">
            <b id="st-rows">0</b> records""",
            1,
        )

    # atomic write
    tmp = DASH.with_suffix(".html.tmp")
    tmp.write_text(t, encoding="utf-8")
    tmp.replace(DASH)
    print("patched", DASH, "bytes", DASH.stat().st_size)
    for k in [
        "status-bar",
        "btn-recolhe",
        "function fechaSubmenus",
        "function alternaBarra",
        "function initStatusBar",
        'class="shell"',
        "nav-branch",
        "min-height: 0; height: 100%",
    ]:
        print(("OK" if k in t else "MISSING"), k)


if __name__ == "__main__":
    main()
