# -*- coding: utf-8 -*-
"""Extend layout:dashboard with configurable widgets + form designer UI."""
from __future__ import annotations

from pathlib import Path

DASH = Path(__file__).resolve().parent / "www" / "dashboard.html"


CSS_OLD = """  .xf-kpis { display: grid; grid-template-columns: repeat(auto-fill,minmax(180px,1fr)); gap: 12px; }
  .xf-kpi {
    border: 1px solid var(--line); border-radius: 10px; padding: 14px 16px;
    background: var(--surface-2); box-shadow: var(--shadow);
  }
  .xf-kpi .lab { font-size: .72rem; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); font-weight: 700; }
  .xf-kpi .val { font-size: 1.6rem; font-weight: 800; margin-top: 6px; color: var(--text); }
  .xf-kpi .tr { font-size: .8rem; color: var(--muted); margin-top: 4px; }
  .xf-kpi.ok .val { color: var(--ok); }
  .xf-kpi.warn .val { color: #d97706; }
  .xf-kpi.danger .val { color: var(--danger); }"""

CSS_NEW = """  .xf-kpis { display: grid; grid-template-columns: repeat(auto-fill,minmax(180px,1fr)); gap: 12px; }
  .xf-kpi {
    border: 1px solid var(--line); border-radius: 10px; padding: 14px 16px;
    background: var(--surface-2); box-shadow: var(--shadow);
  }
  .xf-kpi .lab { font-size: .72rem; text-transform: uppercase; letter-spacing: .05em; color: var(--muted); font-weight: 700; }
  .xf-kpi .val { font-size: 1.6rem; font-weight: 800; margin-top: 6px; color: var(--text); }
  .xf-kpi .tr { font-size: .8rem; color: var(--muted); margin-top: 4px; }
  .xf-kpi.ok .val { color: var(--ok); }
  .xf-kpi.warn .val { color: #d97706; }
  .xf-kpi.danger .val { color: var(--danger); }
  /* Configurable dashboard layout (widgets: kpi / bar / donut / text) */
  .xf-dash { display: flex; flex-direction: column; gap: 12px; width: 100%; min-height: 0; }
  .xf-dash-grid {
    display: grid;
    grid-template-columns: repeat(12, minmax(0, 1fr));
    gap: 12px;
    align-items: stretch;
  }
  .xf-dash-w { min-width: 0; }
  @media (max-width: 900px) {
    .xf-dash-grid { grid-template-columns: 1fr 1fr; }
    .xf-dash-w { grid-column: span 1 !important; }
  }
  @media (max-width: 560px) {
    .xf-dash-grid { grid-template-columns: 1fr; }
  }
  .xf-dash-card {
    background: var(--panel, var(--surface-2));
    border: 1px solid var(--line);
    border-radius: 12px;
    padding: 14px 16px;
    box-shadow: var(--shadow);
    height: 100%;
    border-top: 3px solid transparent;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
  .xf-dash-card.tone-info { border-top-color: #3b82f6; }
  .xf-dash-card.tone-ok { border-top-color: #16a34a; }
  .xf-dash-card.tone-warn { border-top-color: #f59e0b; }
  .xf-dash-card.tone-danger { border-top-color: #ef4444; }
  .xf-dash-card.tone-purple { border-top-color: #8b5cf6; }
  .xf-dash-card.tone-teal { border-top-color: #0d9488; }
  .xf-dash-wtitle {
    font-size: .72rem; font-weight: 700; letter-spacing: .04em;
    text-transform: uppercase; color: var(--muted); margin: 0 0 10px;
  }
  .xf-dash-kpi .lab {
    font-size: .72rem; text-transform: uppercase; letter-spacing: .05em;
    color: var(--muted); font-weight: 700;
  }
  .xf-dash-kpi .val {
    font-size: 1.55rem; font-weight: 800; margin-top: 8px; color: var(--text);
    font-variant-numeric: tabular-nums; line-height: 1.15;
  }
  .xf-dash-kpi .tr { font-size: .8rem; color: var(--muted); margin-top: 6px; }
  .xf-dash-kpi.ok .val { color: var(--ok); }
  .xf-dash-kpi.warn .val { color: #d97706; }
  .xf-dash-kpi.danger .val { color: var(--danger); }
  .xf-dash-text { font-size: .88rem; color: var(--text-2); line-height: 1.45; white-space: pre-wrap; }
  .xf-bar-plot {
    display: flex; align-items: flex-end; gap: 8px; flex: 1;
    min-height: 140px; padding: 4px 2px 0;
  }
  .xf-bar-group {
    flex: 1; display: flex; flex-direction: column; align-items: center;
    gap: 6px; min-width: 0;
  }
  .xf-bar-bars {
    display: flex; align-items: flex-end; justify-content: center;
    gap: 3px; width: 100%; height: 140px;
  }
  .xf-bar {
    width: 13px; max-width: 40%; border-radius: 4px 4px 0 0; min-height: 2px;
  }
  .xf-bar-lab {
    font-size: .68rem; color: var(--muted); white-space: nowrap;
    overflow: hidden; text-overflow: ellipsis; max-width: 100%;
  }
  .xf-bar-legend, .xf-donut-legend {
    display: flex; flex-wrap: wrap; gap: 10px 14px; margin-top: 12px;
    font-size: .75rem; color: var(--muted);
  }
  .xf-bar-legend span, .xf-donut-legend span {
    display: inline-flex; align-items: center; gap: 5px;
  }
  .xf-swatch {
    display: inline-block; width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0;
  }
  .xf-donut-wrap {
    display: flex; flex-wrap: wrap; align-items: center; justify-content: center;
    gap: 16px 20px; flex: 1;
  }
  .xf-donut {
    width: 148px; height: 148px; border-radius: 50%; flex-shrink: 0;
    display: flex; align-items: center; justify-content: center;
  }
  .xf-donut-hole {
    width: 88px; height: 88px; border-radius: 50%;
    background: var(--panel, var(--surface-2));
    display: flex; align-items: center; justify-content: center; text-align: center;
    font-size: .78rem; font-weight: 700; color: var(--text); padding: 6px;
    box-shadow: inset 0 0 0 1px var(--line);
    line-height: 1.2;
  }
  .xf-donut-legend { flex-direction: column; gap: 6px; margin-top: 0; align-items: flex-start; }
  #des-dash-widgets input, #des-dash-widgets select {
    width: 100%; min-width: 0; font-size: .78rem;
  }
  #des-dash-widgets td { vertical-align: middle; }"""


DES_BLOCK = r'''    <div class="designer-section" id="des-dash-block" style="display:none;margin-bottom:12px">
      <h3>
        <span>Dashboard widgets</span>
        <span class="tools">
          <button type="button" class="btn-ghost" id="des-dash-add" style="height:28px;font-size:.75rem">+ Widget</button>
        </span>
      </h3>
      <div class="designer-grid" style="padding:12px">
        <div class="designer-field">
          <label for="des-dash-subtitle">Subtitle / period</label>
          <input type="text" id="des-dash-subtitle" placeholder="Agosto 2026">
        </div>
        <div class="designer-field">
          <label for="des-dash-cols">Grid columns</label>
          <select id="des-dash-cols">
            <option value="12">12</option>
            <option value="6">6</option>
            <option value="4">4</option>
          </select>
        </div>
        <div class="designer-field">
          <label for="des-dash-gap">Gap (px)</label>
          <input type="number" id="des-dash-gap" min="0" max="48" value="12" step="1">
        </div>
      </div>
      <div style="padding:0 12px 8px;overflow-x:auto">
        <table class="designer-cols" style="min-width:860px">
          <thead>
            <tr>
              <th style="width:9%">Type</th>
              <th style="width:9%">Id</th>
              <th style="width:16%">Title</th>
              <th style="width:6%">Span</th>
              <th style="width:9%">Tone</th>
              <th style="width:14%">dataRef</th>
              <th style="width:28%">Options</th>
              <th class="act">Order</th>
            </tr>
          </thead>
          <tbody id="des-dash-widgets"></tbody>
        </table>
      </div>
      <p style="padding:0 12px 12px;margin:0;font-size:.72rem;color:var(--muted)">
        Widget types: <b>kpi</b> (metric tile), <b>bar</b> (grouped columns), <b>donut</b> (share pie), <b>text</b> (note).
        <b>Span</b> is width on a 12-column grid (e.g. 3 = quarter, 4 = third, 8+4 = chart row).
        <b>Tone</b> sets the coloured top border: info · ok · warn · danger · purple · teal.
        <b>Options</b> are <code>key=value</code> pairs separated by <code>;</code> —
        kpi: <code>row=k1;format=money;subtitle=Atualizado agora</code> or static <code>value=0;format=money</code>;
        bar: <code>cat=month;height=180;series=capital:Capital:#16a34a,loans:Loans:#2563eb</code>;
        donut: <code>label=label;value=value;color=color;center=Carteira</code>.
        Leave the widget list empty to auto-tile every row of the screen <code>dataRef</code> (legacy).
      </p>
    </div>
'''


RENDER_FN = r'''function xfDashParseOpts(s) {
  var out = {}, parts, i, p, eq, k, v;
  s = String(s || "").trim();
  if (!s) return out;
  parts = s.split(";");
  for (i = 0; i < parts.length; i++) {
    p = strTrim(parts[i]);
    if (!p) continue;
    eq = p.indexOf("=");
    if (eq < 0) { out[p] = "1"; continue; }
    k = strTrim(p.slice(0, eq));
    v = strTrim(p.slice(eq + 1));
    if (k) out[k] = v;
  }
  return out;
}

function xfDashOptsToText(w) {
  var parts = [], k, series, i, s, bit;
  if (!w || typeof w !== "object") return "";
  if (w.rowId != null && w.rowId !== "") parts.push("row=" + w.rowId);
  if (w.rowIndex != null && w.rowIndex !== "") parts.push("rowIndex=" + w.rowIndex);
  if (w.format) parts.push("format=" + w.format);
  if (w.subtitle) parts.push("subtitle=" + w.subtitle);
  if (w.value != null && w.value !== "" && (w.type === "kpi" || w.type === "text"))
    parts.push("value=" + w.value);
  if (w.valueField && w.valueField !== "value") parts.push("valueField=" + w.valueField);
  if (w.labelField && w.labelField !== "label") parts.push("labelField=" + w.labelField);
  if (w.trendField && w.trendField !== "trend") parts.push("trendField=" + w.trendField);
  if (w.unitField && w.unitField !== "unit") parts.push("unitField=" + w.unitField);
  if (w.categoryField && w.categoryField !== "month") parts.push("cat=" + w.categoryField);
  if (w.height) parts.push("height=" + w.height);
  if (w.centerLabel) parts.push("center=" + w.centerLabel);
  if (w.colorField && w.colorField !== "color") parts.push("color=" + w.colorField);
  if (Array.isArray(w.series) && w.series.length) {
    series = [];
    for (i = 0; i < w.series.length; i++) {
      s = w.series[i] || {};
      bit = String(s.field || s.id || ("s" + (i + 1)));
      if (s.label) bit += ":" + s.label;
      if (s.color) bit += ":" + s.color;
      series.push(bit);
    }
    parts.push("series=" + series.join(","));
  }
  if (w.text) parts.push("text=" + w.text);
  // pass-through unknown opts stored as w._opts
  if (w._opts && typeof w._opts === "object") {
    for (k in w._opts) {
      if (Object.prototype.hasOwnProperty.call(w._opts, k) && w._opts[k] != null)
        parts.push(k + "=" + w._opts[k]);
    }
  }
  return parts.join(";");
}

function xfDashApplyOpts(w, optTxt) {
  var o = xfDashParseOpts(optTxt), series, bits, i, b, segs, item;
  if (!w) return w;
  if (o.row != null) { w.rowId = o.row; delete o.row; }
  if (o.rowId != null) { w.rowId = o.rowId; delete o.rowId; }
  if (o.rowIndex != null) { w.rowIndex = parseInt(o.rowIndex, 10); delete o.rowIndex; }
  if (o.format != null) { w.format = o.format; delete o.format; }
  if (o.subtitle != null) { w.subtitle = o.subtitle; delete o.subtitle; }
  if (o.value != null) { w.value = o.value; delete o.value; }
  if (o.valueField != null) { w.valueField = o.valueField; delete o.valueField; }
  if (o.labelField != null) { w.labelField = o.labelField; delete o.labelField; }
  if (o.trendField != null) { w.trendField = o.trendField; delete o.trendField; }
  if (o.unitField != null) { w.unitField = o.unitField; delete o.unitField; }
  if (o.cat != null) { w.categoryField = o.cat; delete o.cat; }
  if (o.categoryField != null) { w.categoryField = o.categoryField; delete o.categoryField; }
  if (o.height != null) { w.height = parseInt(o.height, 10) || 180; delete o.height; }
  if (o.center != null) { w.centerLabel = o.center; delete o.center; }
  if (o.centerLabel != null) { w.centerLabel = o.centerLabel; delete o.centerLabel; }
  if (o.color != null) { w.colorField = o.color; delete o.color; }
  if (o.colorField != null) { w.colorField = o.colorField; delete o.colorField; }
  if (o.text != null) { w.text = o.text; delete o.text; }
  if (o.series != null) {
    series = [];
    bits = String(o.series).split(",");
    for (i = 0; i < bits.length; i++) {
      b = strTrim(bits[i]);
      if (!b) continue;
      segs = b.split(":");
      item = { field: segs[0] };
      if (segs[1]) item.label = segs[1];
      if (segs[2]) item.color = segs[2];
      series.push(item);
    }
    w.series = series;
    delete o.series;
  }
  w._opts = o;
  return w;
}

function renderDesignerDashWidgets() {
  var tb = document.getElementById("des-dash-widgets");
  var list = DESIGNER.dashWidgets || [];
  var html = "", i, w, t, tone, span;
  if (!tb) return;
  if (!list.length) {
    tb.innerHTML = "<tr><td colspan='8' style='padding:14px;text-align:center;color:var(--muted)'>" +
      "No widgets — auto-tiles dataRef rows as KPIs (legacy). Click + Widget to design a layout.</td></tr>";
    return;
  }
  for (i = 0; i < list.length; i++) {
    w = list[i] || {};
    t = w.type || "kpi";
    tone = w.tone || "";
    span = (w.span != null && w.span !== "") ? w.span : 3;
    html += "<tr data-i='" + i + "'>" +
      "<td><select data-f='type'>" +
        ["kpi", "bar", "donut", "text"].map(function (x) {
          return "<option value='" + x + "'" + (t === x ? " selected" : "") + ">" + x + "</option>";
        }).join("") +
      "</select></td>" +
      "<td><input type='text' data-f='id' value='" + esc(w.id || "") + "' placeholder='w1'></td>" +
      "<td><input type='text' data-f='title' value='" + esc(w.title || "") + "' placeholder='Title'></td>" +
      "<td><input type='number' data-f='span' min='1' max='12' value='" + esc(String(span)) + "'></td>" +
      "<td><select data-f='tone'>" +
        [["", "—"], ["info", "info"], ["ok", "ok"], ["warn", "warn"],
         ["danger", "danger"], ["purple", "purple"], ["teal", "teal"]].map(function (p) {
          return "<option value='" + p[0] + "'" + (tone === p[0] ? " selected" : "") + ">" + p[1] + "</option>";
        }).join("") +
      "</select></td>" +
      "<td><input type='text' data-f='dataRef' value='" + esc(w.dataRef || "") + "' placeholder='data.…'></td>" +
      "<td><input type='text' data-f='opts' value='" + esc(xfDashOptsToText(w)) +
        "' placeholder='row=k1;format=money' title='Semicolon-separated options'></td>" +
      "<td class='act'>" +
        "<button type='button' data-act='up' title='Up'>&#9650;</button>" +
        "<button type='button' data-act='down' title='Down'>&#9660;</button>" +
        "<button type='button' data-act='del' title='Remove'>&#10005;</button>" +
      "</td></tr>";
  }
  tb.innerHTML = html;
}

function syncDesignerDashWidgetsFromDom() {
  var rows = document.querySelectorAll("#des-dash-widgets tr[data-i]");
  var list = DESIGNER.dashWidgets || [];
  var i, tr, idx, w, el;
  for (i = 0; i < rows.length; i++) {
    tr = rows[i];
    idx = parseInt(tr.getAttribute("data-i"), 10);
    if (isNaN(idx) || !list[idx]) continue;
    w = { type: "kpi", span: 3 };
    el = tr.querySelector("[data-f='type']"); if (el) w.type = el.value || "kpi";
    el = tr.querySelector("[data-f='id']"); if (el) w.id = el.value.trim();
    el = tr.querySelector("[data-f='title']"); if (el) w.title = el.value.trim();
    el = tr.querySelector("[data-f='span']");
    if (el) {
      w.span = parseInt(el.value, 10);
      if (isNaN(w.span) || w.span < 1) w.span = 3;
      if (w.span > 12) w.span = 12;
    }
    el = tr.querySelector("[data-f='tone']"); if (el && el.value) w.tone = el.value;
    el = tr.querySelector("[data-f='dataRef']"); if (el && el.value.trim()) w.dataRef = el.value.trim();
    el = tr.querySelector("[data-f='opts']");
    xfDashApplyOpts(w, el ? el.value : "");
    if (!w.id) w.id = "w" + (idx + 1);
    list[idx] = w;
  }
}

function designerAddDashWidget() {
  syncDesignerDashWidgetsFromDom();
  if (!DESIGNER.dashWidgets) DESIGNER.dashWidgets = [];
  DESIGNER.dashWidgets.push({
    type: "kpi",
    id: "w" + (DESIGNER.dashWidgets.length + 1),
    title: "KPI",
    span: 3,
    tone: "info",
    dataRef: (document.getElementById("des-dataref") || {}).value || "",
    format: "money"
  });
  DESIGNER.dirty = true;
  renderDesignerDashWidgets();
}

function xfDashFmt(val, format, unit) {
  var u = unit != null ? String(unit) : "";
  var f = format != null ? String(format) : "";
  if (f === "money" || u === "EUR" || u === "BRL" || u === "USD" || u === "GBP")
    return moneyFmt(val);
  if (f === "percent" || u === "%") return String(val == null ? "" : val) + "%";
  if (u && u !== "EUR" && u !== "BRL" && u !== "USD")
    return String(val == null ? "" : val) + " " + u;
  return String(val == null ? "" : val);
}

function xfDashPickRow(rows, w) {
  var i, r, idF;
  rows = rows || [];
  if (w.rowId != null && w.rowId !== "") {
    for (i = 0; i < rows.length; i++) {
      r = rows[i] || {};
      if (String(r.id) === String(w.rowId) || String(r.code) === String(w.rowId) ||
          String(r.key) === String(w.rowId)) return r;
    }
  }
  if (w.rowIndex != null && !isNaN(w.rowIndex) && rows[w.rowIndex]) return rows[w.rowIndex];
  return rows[0] || null;
}

function xfDashDefaultColors() {
  return ["#2563eb", "#16a34a", "#f59e0b", "#8b5cf6", "#0d9488", "#ef4444", "#64748b", "#06b6d4"];
}

function xfRenderBarWidgetHtml(w, rows) {
  var catF = w.categoryField || "month";
  var series = Array.isArray(w.series) && w.series.length ? w.series :
    [{ field: "value", label: "Value", color: "#16a34a" }];
  var height = parseInt(w.height, 10) || 180;
  var max = 0, i, j, r, s, v, pct, html, lab;
  var colors = xfDashDefaultColors();
  rows = rows || [];
  for (i = 0; i < rows.length; i++) {
    r = rows[i] || {};
    for (j = 0; j < series.length; j++) {
      v = parseFloat(r[series[j].field]);
      if (!isNaN(v) && v > max) max = v;
    }
  }
  if (max <= 0) max = 1;
  html = "<div class='xf-dash-card" + (w.tone ? (" tone-" + esc(w.tone)) : "") + "'>";
  if (w.title) html += "<div class='xf-dash-wtitle'>" + esc(w.title) + "</div>";
  html += "<div class='xf-bar-plot' style='min-height:" + height + "px'>";
  for (i = 0; i < rows.length; i++) {
    r = rows[i] || {};
    html += "<div class='xf-bar-group'><div class='xf-bar-bars' style='height:" + height + "px'>";
    for (j = 0; j < series.length; j++) {
      s = series[j] || {};
      v = parseFloat(r[s.field]);
      if (isNaN(v)) v = 0;
      pct = Math.max(2, Math.round((v / max) * 100));
      html += "<div class='xf-bar' style='height:" + pct + "%;background:" +
        esc(s.color || colors[j % colors.length]) + "' title='" +
        esc((s.label || s.field) + ": " + v) + "'></div>";
    }
    lab = r[catF] != null ? r[catF] : (r.label || ("#" + (i + 1)));
    html += "</div><div class='xf-bar-lab' title='" + esc(String(lab)) + "'>" + esc(String(lab)) + "</div></div>";
  }
  if (!rows.length) html += "<div style='color:var(--muted);font-size:.85rem;padding:20px'>No series data</div>";
  html += "</div><div class='xf-bar-legend'>";
  for (j = 0; j < series.length; j++) {
    s = series[j] || {};
    html += "<span><i class='xf-swatch' style='background:" + esc(s.color || colors[j % colors.length]) +
      "'></i>" + esc(s.label || s.field || ("S" + (j + 1))) + "</span>";
  }
  html += "</div></div>";
  return html;
}

function xfRenderDonutWidgetHtml(w, rows) {
  var labelF = w.labelField || "label";
  var valueF = w.valueField || "value";
  var colorF = w.colorField || "color";
  var colors = xfDashDefaultColors();
  var total = 0, slices = [], i, r, v, acc = 0, stops = [], pct, html, c;
  rows = rows || [];
  for (i = 0; i < rows.length; i++) {
    r = rows[i] || {};
    v = parseFloat(r[valueF]);
    if (isNaN(v)) v = 0;
    total += v;
    slices.push({
      label: r[labelF] != null ? String(r[labelF]) : ("Item " + (i + 1)),
      value: v,
      color: r[colorF] || colors[i % colors.length]
    });
  }
  if (total <= 0) {
    stops.push("#e2e8f0 0% 100%");
  } else {
    for (i = 0; i < slices.length; i++) {
      pct = (slices[i].value / total) * 100;
      stops.push(slices[i].color + " " + acc.toFixed(2) + "% " + (acc + pct).toFixed(2) + "%");
      acc += pct;
    }
  }
  html = "<div class='xf-dash-card" + (w.tone ? (" tone-" + esc(w.tone)) : "") + "'>";
  if (w.title) html += "<div class='xf-dash-wtitle'>" + esc(w.title) + "</div>";
  html += "<div class='xf-donut-wrap'>";
  html += "<div class='xf-donut' style='background:conic-gradient(" + stops.join(",") + ")'>" +
    "<div class='xf-donut-hole'>" + esc(w.centerLabel || w.title || "") + "</div></div>";
  html += "<div class='xf-donut-legend'>";
  for (i = 0; i < slices.length; i++) {
    c = slices[i];
    pct = total > 0 ? Math.round((c.value / total) * 100) : 0;
    html += "<span><i class='xf-swatch' style='background:" + esc(c.color) + "'></i>" +
      esc(c.label) + " " + pct + "%</span>";
  }
  if (!slices.length) html += "<span style='color:var(--muted)'>No slices</span>";
  html += "</div></div></div>";
  return html;
}

function xfRenderKpiWidgetHtml(w, rows) {
  var r = null, tone, lab, val, unit, trend, sub, html, format;
  if (w.value != null && w.value !== "" && (w.rowId == null || w.rowId === "") &&
      (w.rowIndex == null || w.rowIndex === "") && !w.dataRef) {
    r = {
      label: w.title,
      value: w.value,
      unit: w.unit || "",
      trend: w.subtitle || w.trend || ""
    };
  } else {
    r = xfDashPickRow(rows, w) || {};
  }
  tone = w.tone || r.tone || "info";
  lab = w.title || r[w.labelField || "label"] || r.label || "";
  val = (w.value != null && w.value !== "" && !w.rowId && w.rowIndex == null)
    ? w.value
    : r[w.valueField || "value"];
  unit = r[w.unitField || "unit"] || w.unit || "";
  trend = w.subtitle || r[w.trendField || "trend"] || r.trend || "";
  sub = w.subtitle || "";
  format = w.format || (unit === "EUR" || unit === "BRL" || unit === "USD" ? "money" : "");
  // if subtitle set, prefer it as footer; else trend
  if (sub) trend = sub;
  html = "<div class='xf-dash-card tone-" + esc(tone) + " xf-dash-kpi " + esc(tone) + "'>";
  html += "<div class='lab'>" + esc(lab) + "</div>";
  html += "<div class='val'>" + esc(xfDashFmt(val, format, unit)) + "</div>";
  if (trend) html += "<div class='tr'>" + esc(trend) + "</div>";
  html += "</div>";
  return html;
}

function xfRenderTextWidgetHtml(w) {
  var html = "<div class='xf-dash-card" + (w.tone ? (" tone-" + esc(w.tone)) : "") + "'>";
  if (w.title) html += "<div class='xf-dash-wtitle'>" + esc(w.title) + "</div>";
  html += "<div class='xf-dash-text'>" + esc(w.text || w.value || w.subtitle || "") + "</div>";
  html += "</div>";
  return html;
}

function xfFetchMany(refs, cb) {
  var left, map = {}, i;
  refs = (refs || []).filter(function (x) { return !!x; });
  // unique
  var seen = {}, uniq = [];
  for (i = 0; i < refs.length; i++) {
    if (!seen[refs[i]]) { seen[refs[i]] = 1; uniq.push(refs[i]); }
  }
  left = uniq.length;
  if (!left) { cb({}); return; }
  for (i = 0; i < uniq.length; i++) {
    (function (key) {
      xfFetch(key, function (rows) {
        map[key] = rows;
        left--;
        if (left <= 0) cb(map);
      });
    })(uniq[i]);
  }
}

function xfRenderDashboard(scr) {
  var host = xfHost();
  var dash = (scr && scr.dashboard && typeof scr.dashboard === "object") ? scr.dashboard : {};
  var widgets = Array.isArray(dash.widgets) ? dash.widgets : [];
  var refs = [], i, w, sub;
  var mSub = document.getElementById("meta-sub");
  sub = dash.subtitle != null ? String(dash.subtitle) : (scr.subtitle != null ? String(scr.subtitle) : "");
  if (mSub) {
    if (sub) { mSub.textContent = sub; mSub.style.display = ""; }
    else { mSub.textContent = ""; mSub.style.display = "none"; }
  }
  if (scr && scr.dataRef) refs.push(scr.dataRef);
  for (i = 0; i < widgets.length; i++) {
    w = widgets[i] || {};
    if (w.dataRef) refs.push(w.dataRef);
  }
  xfFetchMany(refs, function (byRef) {
    var html, cols, gap, span, rows, defRows, tone, r;
    defRows = (scr && scr.dataRef && byRef[scr.dataRef]) ? byRef[scr.dataRef] : [];
    // Legacy: no widgets → auto KPI tiles from dataRef
    if (!widgets.length) {
      html = "<div class='xf-kpis'>";
      for (i = 0; i < defRows.length; i++) {
        r = defRows[i] || {};
        tone = r.tone || "info";
        html += "<div class='xf-kpi " + esc(tone) + "'><div class='lab'>" + esc(r.label) + "</div>" +
          "<div class='val'>" + esc(r.unit === "EUR" || r.unit === "BRL" || r.unit === "USD"
            ? moneyFmt(r.value)
            : (r.value + (r.unit && r.unit !== "EUR" && r.unit !== "BRL" && r.unit !== "USD"
              ? (" " + r.unit) : ""))) + "</div>" +
          "<div class='tr'>" + esc(r.trend || "") + "</div></div>";
      }
      if (!defRows.length)
        html += "<div style='color:var(--muted);padding:20px'>No KPI rows in " +
          esc(scr.dataRef || "(no dataRef)") + ". Add widgets in Design form.</div>";
      html += "</div>";
      host.innerHTML = html;
      return;
    }
    cols = parseInt(dash.columns, 10) || 12;
    gap = dash.gap != null ? parseInt(dash.gap, 10) : 12;
    if (isNaN(gap)) gap = 12;
    html = "<div class='xf-dash'><div class='xf-dash-grid' style='grid-template-columns:repeat(" +
      cols + ",minmax(0,1fr));gap:" + gap + "px'>";
    for (i = 0; i < widgets.length; i++) {
      w = widgets[i] || {};
      span = parseInt(w.span, 10);
      if (isNaN(span) || span < 1) span = (w.type === "bar" ? 8 : (w.type === "donut" ? 4 : 3));
      if (span > cols) span = cols;
      rows = w.dataRef && byRef[w.dataRef] ? byRef[w.dataRef] : defRows;
      html += "<div class='xf-dash-w' style='grid-column:span " + span + "'>";
      if (w.type === "bar") html += xfRenderBarWidgetHtml(w, rows);
      else if (w.type === "donut") html += xfRenderDonutWidgetHtml(w, rows);
      else if (w.type === "text") html += xfRenderTextWidgetHtml(w);
      else html += xfRenderKpiWidgetHtml(w, rows);
      html += "</div>";
    }
    html += "</div></div>";
    host.innerHTML = html;
  });
}
'''


def main() -> None:
    t = DASH.read_text(encoding="utf-8")
    orig = t

    if CSS_OLD not in t:
        raise SystemExit("CSS_OLD not found")
    if "/* Configurable dashboard layout" not in t:
        t = t.replace(CSS_OLD, CSS_NEW, 1)
        print("CSS: ok")
    else:
        print("CSS: already present")

    # Designer HTML block — insert before des-edit-form-block
    marker = '    <div class="designer-section" id="des-edit-form-block">'
    if 'id="des-dash-block"' not in t:
        if marker not in t:
            raise SystemExit("des-edit-form-block marker not found")
        t = t.replace(marker, DES_BLOCK + marker, 1)
        print("DES_BLOCK: ok")
    else:
        print("DES_BLOCK: already present")

    # updateDesignerLayoutUi
    old_ui = '''function updateDesignerLayoutUi() {
  var lay = document.getElementById("des-layout");
  var layout = lay ? lay.value : "list";
  var md = document.getElementById("des-md-block");
  var formB = document.getElementById("des-form-block");
  var editFormB = document.getElementById("des-edit-form-block");
  var folderB = document.getElementById("des-folder-block");
  var menuB = document.getElementById("des-menu-block");
  var wfB = document.getElementById("des-wf-block");
  var isMd = (layout === "master-detail" || layout === "document");
  var isForm = (layout === "form" || layout === "wizard");
  var isFolder = (layout === "folder");
  var isMenu = (layout === "menu");
  var isWf = (layout === "workflow");
  var isListish = (!isForm && !isFolder && !isMenu);
  if (md) md.style.display = isMd ? "block" : "none";
  if (formB) formB.style.display = isForm ? "block" : "none";
  if (editFormB) editFormB.style.display = isListish ? "block" : "none";
  if (folderB) folderB.style.display = isFolder ? "block" : "none";
  if (menuB) menuB.style.display = isMenu ? "block" : "none";
  if (wfB) wfB.style.display = isWf ? "block" : "none";
  var custom = document.getElementById("des-form-custom");
  DESIGNER.formCustom = !!(custom && custom.checked);
  var bar = document.getElementById("des-cols-scope-bar");
  var showBar = isMd || (isListish && DESIGNER.formCustom);
  if (bar) bar.style.display = showBar ? "flex" : "none";
  var sf = document.getElementById("des-scope-form");
  if (sf) sf.style.display = (isListish && DESIGNER.formCustom) ? "inline-block" : "none";
  var sd = document.getElementById("des-scope-detail");
  if (sd) sd.style.display = isMd ? "inline-block" : "none";
  if (!isMd && DESIGNER.colScope === "detail") setDesignerColScope("master");
  if (!(isListish && DESIGNER.formCustom) && DESIGNER.colScope === "form")
    setDesignerColScope("master");
  var t = document.getElementById("des-cols-title");
  if (t && DESIGNER.colScope === "master") {
    if (isForm) t.textContent = "Form fields (controls)";
    else if (isWf) t.textContent = "Queue / board columns";
    else if (isMenu || isFolder) t.textContent = "Optional (unused for this layout)";
    else t.textContent = "Grid columns (master)";
  } else if (t && DESIGNER.colScope === "form") {
    t.textContent = "Form fields (edit dialog)";
  }
}'''
    new_ui = '''function updateDesignerLayoutUi() {
  var lay = document.getElementById("des-layout");
  var layout = lay ? lay.value : "list";
  var md = document.getElementById("des-md-block");
  var formB = document.getElementById("des-form-block");
  var editFormB = document.getElementById("des-edit-form-block");
  var folderB = document.getElementById("des-folder-block");
  var menuB = document.getElementById("des-menu-block");
  var wfB = document.getElementById("des-wf-block");
  var dashB = document.getElementById("des-dash-block");
  var isMd = (layout === "master-detail" || layout === "document");
  var isForm = (layout === "form" || layout === "wizard");
  var isFolder = (layout === "folder");
  var isMenu = (layout === "menu");
  var isWf = (layout === "workflow");
  var isDash = (layout === "dashboard");
  var isListish = (!isForm && !isFolder && !isMenu && !isDash);
  if (md) md.style.display = isMd ? "block" : "none";
  if (formB) formB.style.display = isForm ? "block" : "none";
  if (editFormB) editFormB.style.display = isListish ? "block" : "none";
  if (folderB) folderB.style.display = isFolder ? "block" : "none";
  if (menuB) menuB.style.display = isMenu ? "block" : "none";
  if (wfB) wfB.style.display = isWf ? "block" : "none";
  if (dashB) dashB.style.display = isDash ? "block" : "none";
  var custom = document.getElementById("des-form-custom");
  DESIGNER.formCustom = !!(custom && custom.checked);
  var bar = document.getElementById("des-cols-scope-bar");
  var showBar = isMd || (isListish && DESIGNER.formCustom);
  if (bar) bar.style.display = showBar ? "flex" : "none";
  var sf = document.getElementById("des-scope-form");
  if (sf) sf.style.display = (isListish && DESIGNER.formCustom) ? "inline-block" : "none";
  var sd = document.getElementById("des-scope-detail");
  if (sd) sd.style.display = isMd ? "inline-block" : "none";
  if (!isMd && DESIGNER.colScope === "detail") setDesignerColScope("master");
  if (!(isListish && DESIGNER.formCustom) && DESIGNER.colScope === "form")
    setDesignerColScope("master");
  var t = document.getElementById("des-cols-title");
  if (t && DESIGNER.colScope === "master") {
    if (isForm) t.textContent = "Form fields (controls)";
    else if (isWf) t.textContent = "Queue / board columns";
    else if (isDash) t.textContent = "Optional (unused when widgets are set)";
    else if (isMenu || isFolder) t.textContent = "Optional (unused for this layout)";
    else t.textContent = "Grid columns (master)";
  } else if (t && DESIGNER.colScope === "form") {
    t.textContent = "Form fields (edit dialog)";
  }
}'''
    if old_ui in t:
        t = t.replace(old_ui, new_ui, 1)
        print("updateDesignerLayoutUi: ok")
    elif "var isDash = (layout === \"dashboard\")" in t:
        print("updateDesignerLayoutUi: already present")
    else:
        raise SystemExit("updateDesignerLayoutUi not found")

    # closeFormDesigner DESIGNER reset
    old_close = '''  DESIGNER = {
    key: "", doc: null, cols: [], detailCols: [], formCols: [], dirty: false,
    toolbar: [], detailToolbar: [], layout: "list", colScope: "master",
    formCustom: false, fromScreen: ""
  };'''
    new_close = '''  DESIGNER = {
    key: "", doc: null, cols: [], detailCols: [], formCols: [], dirty: false,
    toolbar: [], detailToolbar: [], layout: "list", colScope: "master",
    formCustom: false, fromScreen: "", dashWidgets: []
  };'''
    if old_close in t:
        t = t.replace(old_close, new_close, 1)
        print("closeFormDesigner: ok")
    elif "dashWidgets" in t:
        print("closeFormDesigner: already has dashWidgets")
    else:
        print("WARN: closeFormDesigner block not found")

    # loadDesignerKey: after workflow extras, load dashboard
    old_load = '''        // workflow extras
        el = document.getElementById("des-statusfield");
        if (el) el.value = j.doc.statusField || "status";
        el = document.getElementById("des-keyfield-wf");
        if (el) el.value = j.doc.keyField || "code";
        el = document.getElementById("des-transitions");
        if (el) el.value = transitionsToText(j.doc.transitions || null);
      }
      document.getElementById("des-title").value = DESIGNER.doc.title || "";'''
    new_load = '''        // workflow extras
        el = document.getElementById("des-statusfield");
        if (el) el.value = j.doc.statusField || "status";
        el = document.getElementById("des-keyfield-wf");
        if (el) el.value = j.doc.keyField || "code";
        el = document.getElementById("des-transitions");
        if (el) el.value = transitionsToText(j.doc.transitions || null);
        // dashboard widgets
        DESIGNER.dashWidgets = [];
        var dash = (j.doc.dashboard && typeof j.doc.dashboard === "object") ? j.doc.dashboard : {};
        el = document.getElementById("des-dash-subtitle");
        if (el) el.value = dash.subtitle != null ? String(dash.subtitle) : (j.doc.subtitle || "");
        el = document.getElementById("des-dash-cols");
        if (el) el.value = dash.columns != null ? String(dash.columns) : "12";
        el = document.getElementById("des-dash-gap");
        if (el) el.value = dash.gap != null ? String(dash.gap) : "12";
        if (Array.isArray(dash.widgets)) {
          for (i = 0; i < dash.widgets.length; i++) {
            DESIGNER.dashWidgets.push(JSON.parse(JSON.stringify(dash.widgets[i] || {})));
          }
        }
      }
      if (!DESIGNER.dashWidgets) DESIGNER.dashWidgets = [];
      renderDesignerDashWidgets();
      document.getElementById("des-title").value = DESIGNER.doc.title || "";'''
    if old_load in t:
        t = t.replace(old_load, new_load, 1)
        print("loadDesignerKey dash: ok")
    elif "des-dash-subtitle" in t and "DESIGNER.dashWidgets" in t:
        print("loadDesignerKey dash: already present")
    else:
        raise SystemExit("loadDesignerKey workflow extras not found")

    # Also reset dashWidgets when doc not found
    old_empty = '''        DESIGNER.formCustom = false;
        DESIGNER.layout = "list";
        DESIGNER.toolbar = ["add", "edit", "delete", "print", "pdf", "excel", "refresh"];
        DESIGNER.detailToolbar = ["add", "edit", "delete", "refresh"];'''
    new_empty = '''        DESIGNER.formCustom = false;
        DESIGNER.layout = "list";
        DESIGNER.toolbar = ["add", "edit", "delete", "print", "pdf", "excel", "refresh"];
        DESIGNER.detailToolbar = ["add", "edit", "delete", "refresh"];
        DESIGNER.dashWidgets = [];
        var _ds = document.getElementById("des-dash-subtitle");
        var _dc = document.getElementById("des-dash-cols");
        var _dg = document.getElementById("des-dash-gap");
        if (_ds) _ds.value = "";
        if (_dc) _dc.value = "12";
        if (_dg) _dg.value = "12";
        renderDesignerDashWidgets();'''
    if old_empty in t:
        t = t.replace(old_empty, new_empty, 1)
        print("load empty dash: ok")
    else:
        print("WARN: empty load path not patched (maybe already)")

    # saveFormDesigner: after folder block, before KNOWN_LAYOUTS
    old_save = '''  // folder: notebook tabs hosting child screens
  if (layout === "folder") {
    var ftTxt = ((document.getElementById("des-folder-tabs") || {}).value || "");
    var fTabs = textToFolderTabs(ftTxt);
    if (fTabs.length) doc.tabs = fTabs;
    else delete doc.tabs;
    delete doc.fields;
    delete doc.steps;
    delete doc.groups;
  }

  // Drop keys that do not apply to the target layout. Unknown (custom)'''
    new_save = '''  // folder: notebook tabs hosting child screens
  if (layout === "folder") {
    var ftTxt = ((document.getElementById("des-folder-tabs") || {}).value || "");
    var fTabs = textToFolderTabs(ftTxt);
    if (fTabs.length) doc.tabs = fTabs;
    else delete doc.tabs;
    delete doc.fields;
    delete doc.steps;
    delete doc.groups;
  }

  // dashboard widgets
  if (layout === "dashboard") {
    syncDesignerDashWidgetsFromDom();
    var dSub = ((document.getElementById("des-dash-subtitle") || {}).value || "").trim();
    var dCols = parseInt(((document.getElementById("des-dash-cols") || {}).value || "12"), 10) || 12;
    var dGap = parseInt(((document.getElementById("des-dash-gap") || {}).value || "12"), 10);
    if (isNaN(dGap)) dGap = 12;
    var dWidgets = [], di, dw, clean, kk;
    for (di = 0; di < (DESIGNER.dashWidgets || []).length; di++) {
      dw = DESIGNER.dashWidgets[di] || {};
      if (!dw.type && !dw.title && !dw.dataRef) continue;
      clean = {};
      for (kk in dw) {
        if (!Object.prototype.hasOwnProperty.call(dw, kk)) continue;
        if (kk === "_opts") continue;
        if (dw[kk] == null || dw[kk] === "") continue;
        clean[kk] = dw[kk];
      }
      if (!clean.type) clean.type = "kpi";
      if (!clean.id) clean.id = "w" + (di + 1);
      dWidgets.push(clean);
    }
    doc.dashboard = { columns: dCols, gap: dGap, widgets: dWidgets };
    if (dSub) doc.dashboard.subtitle = dSub;
    if (dSub) doc.subtitle = dSub;
    else delete doc.subtitle;
  }

  // Drop keys that do not apply to the target layout. Unknown (custom)'''
    if old_save in t:
        t = t.replace(old_save, new_save, 1)
        print("save dashboard: ok")
    elif "if (layout === \"dashboard\")" in t and "syncDesignerDashWidgetsFromDom" in t:
        print("save dashboard: already present")
    else:
        raise SystemExit("saveFormDesigner folder block not found")

    # KNOWN_LAYOUTS cleanup for dashboard
    old_known = '''  if (KNOWN_LAYOUTS[layout]) {
    if (layout !== "master-detail" && layout !== "document") delete doc.detail;
    if (layout !== "form" && layout !== "wizard") {
      delete doc.fields;
      delete doc.steps;
      if (layout !== "folder") delete doc.tabs;
      if (layout !== "workflow") delete doc.keyField;
    }
    if (layout !== "menu") delete doc.groups;
    if (layout !== "workflow") {
      delete doc.statusField;
      delete doc.transitions;
    }
  }'''
    new_known = '''  if (KNOWN_LAYOUTS[layout]) {
    if (layout !== "master-detail" && layout !== "document") delete doc.detail;
    if (layout !== "form" && layout !== "wizard") {
      delete doc.fields;
      delete doc.steps;
      if (layout !== "folder") delete doc.tabs;
      if (layout !== "workflow") delete doc.keyField;
    }
    if (layout !== "menu") delete doc.groups;
    if (layout !== "workflow") {
      delete doc.statusField;
      delete doc.transitions;
    }
    if (layout !== "dashboard") {
      delete doc.dashboard;
      // keep generic subtitle only when used by dashboard
      if (layout !== "form") delete doc.subtitle;
    }
  }'''
    if old_known in t:
        t = t.replace(old_known, new_known, 1)
        print("KNOWN_LAYOUTS: ok")
    elif "if (layout !== \"dashboard\")" in t:
        print("KNOWN_LAYOUTS: already present")
    else:
        print("WARN: KNOWN_LAYOUTS block not patched")

    # Replace xfRenderDashboard function
    start = t.find("function xfRenderDashboard(scr) {")
    if start < 0:
        raise SystemExit("xfRenderDashboard not found")
    # find next function at column 0 after this
    end = t.find("\nfunction ", start + 10)
    if end < 0:
        raise SystemExit("end of xfRenderDashboard not found")
    # If already patched (xfFetchMany near), skip replace only if marker present
    if "function xfRenderBarWidgetHtml" in t and "xfFetchMany" in t:
        print("render helpers: already present")
    else:
        t = t[:start] + RENDER_FN + t[end + 1 :]
        print("xfRenderDashboard + helpers: ok")

    # Wire UI events for dash widgets near des-layout onchange
    old_bind = '''  var lay = document.getElementById("des-layout");
  if (lay) lay.onchange = function () {
    DESIGNER.layout = lay.value;
    updateDesignerLayoutUi();
  };
  var tb = document.getElementById("des-cols");'''
    new_bind = '''  var lay = document.getElementById("des-layout");
  if (lay) lay.onchange = function () {
    DESIGNER.layout = lay.value;
    updateDesignerLayoutUi();
  };
  var dashAdd = document.getElementById("des-dash-add");
  if (dashAdd) dashAdd.onclick = function () { designerAddDashWidget(); };
  var dashTb = document.getElementById("des-dash-widgets");
  if (dashTb) {
    dashTb.onclick = function (e) {
      var btn = e.target;
      if (!btn || !btn.getAttribute) return;
      var act = btn.getAttribute("data-act");
      if (!act) return;
      var tr = btn.closest("tr");
      if (!tr) return;
      var i = parseInt(tr.getAttribute("data-i"), 10);
      if (isNaN(i)) return;
      syncDesignerDashWidgetsFromDom();
      var list = DESIGNER.dashWidgets || [];
      var tmp;
      if (act === "del") list.splice(i, 1);
      else if (act === "up" && i > 0) {
        tmp = list[i - 1]; list[i - 1] = list[i]; list[i] = tmp;
      } else if (act === "down" && i < list.length - 1) {
        tmp = list[i + 1]; list[i + 1] = list[i]; list[i] = tmp;
      }
      DESIGNER.dirty = true;
      renderDesignerDashWidgets();
    };
    dashTb.oninput = function () { DESIGNER.dirty = true; };
    dashTb.onchange = function () {
      DESIGNER.dirty = true;
      syncDesignerDashWidgetsFromDom();
    };
  }
  var tb = document.getElementById("des-cols");'''
    if old_bind in t:
        t = t.replace(old_bind, new_bind, 1)
        print("bind dash UI: ok")
    elif "des-dash-add" in t and "designerAddDashWidget" in t:
        print("bind dash UI: already present")
    else:
        raise SystemExit("layout bind block not found")

    # Update option label for dashboard layout
    t = t.replace(
        '<option value="dashboard">Dashboard KPIs</option>',
        '<option value="dashboard">Dashboard (KPIs + charts)</option>',
        1,
    )

    if t == orig:
        print("No changes written (already patched?)")
    else:
        DASH.write_text(t, encoding="utf-8")
        print("Wrote", DASH, "bytes", len(t))


if __name__ == "__main__":
    main()
