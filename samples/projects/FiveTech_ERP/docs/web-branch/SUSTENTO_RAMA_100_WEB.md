# Sustento — La rama 100% web existe y está demostrada

**Fecha:** 2026-08-08 · **Backend:** `FiveTech_ERP.exe` oficial de
HarbourBuilder (repo, sin modificar) · **Máquina:** Windows x64 dev.

## Criterios y evidencia

| # | Criterio "100% web" | Evidencia (reproducible) |
|---|---|---|
| 1 | La UI es 100% HTML/CSS/JS servida por HTTP; ningún control nativo en el cliente | 4 bundles independientes (vanilla, Angular 21+PrimeNG, React 19, Vue 3) renderizados en Chromium real; capturas `docs/evidencia/*-app.png` |
| 2 | Todo dato y toda acción viajan por HTTP JSON; el negocio no depende del contenedor | `node scripts/api-check.mjs` → 8/8 OK (login, contexto, meta, dataset, CRUD add→update→delete, logout) en ~104 ms |
| 3 | La sesión y la seguridad viven en el servidor, no en el cliente | Cookie `DWSESS` HttpOnly+SameSite=Lax fija por el servidor; sin cookie → `"Not authenticated"` (api-check prueba 8); logout invalida token |
| 4 | Multiples usuarios reales concurrentes | `python scripts/concurrency.py 10` → 10/10 sesiones OK, login mediana 175 ms, datos mediana 11 ms, 0 errores |
| 5 | Accesible desde cualquier dispositivo (no solo localhost) | `erp_http.prg` hace `bind 0.0.0.0` (verificado en fuente, línea del bind); servidor escuchando en LAN; prueba remota pendiente de firewall (igual que §3.5 del pool) |
| 6 | Es el MISMO backend que el WebView de escritorio | El exe no se tocó: su ventana WebView abre `127.0.0.1:2222/` mientras los 4 navegadores consumen el mismo puerto; cero cambios en Harbour |
| 7 | El frontend es parametrizable: mismo bundle en ramas PC / híbrida / web | `container.js`/`detectRama()` detectan contenedor (`chrome.webview`→pc, `+SendToFWH`→híbrida, else→web); expone capacidades y `data-rama`; un solo build servido siempre por el mismo origen |
| 8 | El meta JSON de FWH DesktopWeb se renderiza fuera de WebView | Menú de 32 ítems y grilla `screen.products` (9 columnas, tipos money/select/checkbox) renderizados por 4 engines distintos; CRUD verificado contra `data.products` |
| 9 | UTF-8 y datos reales intactos por el canal | Capturas muestran "Ferretería", "Taladro percutor", "€" correctos (tildes/ñ en categorías y nombres) |
| 10 | Latencia compatible con uso real desde navegador | Login+shell en navegador headless: 719–784 ms por frontend (evidence.cjs); p50 de datos 11 ms bajo 10 sesiones |

## Resultados medidos (este informe)

```
api-check.mjs        8 pruebas OK · 104 ms totales
concurrency.py 10    10/10 OK · login 174/175/177 ms · datos 5/11/13 ms
evidence.cjs         vanilla 719 ms · angular 780 ms · react 731 ms · vue 742 ms — 0 fallos
```

## Por qué esto valida la rama web del ecosistema FiveTech

1. **El HTTP ya es multiusuario real** (`hb_threadStart` por cliente, mutex en
   estado, TTL de sesión): no es un "modo demo", es un servidor.
2. **El contrato es declarativo**: `modules` + `screen.*` + `data.*` permiten
   renderizadores genéricos en cualquier framework — la UI deja de ser
   patrimonio del WebView.
3. **La rama web convive**: `/` sigue sirviendo el login FWH; los bundles
   viven en `www/web-*`. Nada del camino WebView/WebView2 se rompe.

## Brechas documentadas (honestidad técnica)

- **Exe vs fuentes**: el binario empaquetado no expone `isAdmin/canSwitchCompany/
  canSwitchApp` que los fuentes actuales sí devuelven → reconstruir el exe
  antes de presentar (los frontends ya toleran ambos contratos).
- **CORS sin cookie en login cross-origin**: `ErpHttpOkCookie` no emite
  `Access-Control-Allow-Origin` (sí lo hace `ErpHttpOk`); el prototipo lo evita
  sirviendo todo same-origin (es también la forma correcta en producción).
- **TLS**: ausente por diseño del sample (loopback/LAN); para internet requiere
  túnel o proxy TLS delante — igual que el worker-pool de Zerus.
- **Layouts especiales** (dashboard, wizard, calendar, designer, KPI tiles…):
  **no se implementan como CRUD de grilla** en la SPA 100% web. Motivo:
  el meta FWH de esos screens describe widgets compuestos (series, agenda,
  cards, designers) que el shell HTTP `/dashboard.html` (rama PC/híbrida)
  ya resuelve con el runtime DesktopWeb. Reimplementarlos en 4 frameworks
  sin valor de contrato (no hay `dataRef` + `grid` + toolbar CRUD) duplicaría
  superficie sin probar el núcleo de la propuesta.

  **Alcance funcional entregado en listas (estándar web):**
  - CRUD completo (`add` / `update` / `delete` vía `POST /api/dataset`)
  - Búsqueda en `searchFields`
  - Filtros por columna `type: select` (category, tax, uom…)
  - Ordenamiento por clic en cabecera (asc/desc, numérico y texto)
  - Paginación cliente (tamaño de página 10/25/50/100, pie « ‹ › », informe de rango)
  - Toolbar meta (add/edit/delete/print/excel/refresh)
  - Formulario modal optimizado (foco, Escape, navegación prev/next entre
    registros filtrados; clave readonly en edición)
  - Layouts **form** (nav de registros + tabs) y **master-detail/document**

  **Exclusión documentada (honestidad):** dashboard/KPI/calendar/wizard
  muestran mensaje + meta JSON o redirigen mentalmente al shell HTTP;
  la evidencia de paridad se centra en Artículos (`screen.products`) y
  pantallas list/form/MD del vertical demo.

- **Escritura concurrente sobre datasets JSON**: no stress-testeada a fondo
  (el pool de Zerus documenta el patrón de mutex; aquí hay mutex en escritura
  de archivos pero sin prueba de 48 h).

## Para presentar a FiveTechSoft

1. Fork + rama `feature/web-branch-spa` con `samples/projects/FiveTech_ERP_Web`:
   este prototipo + README reubicado.
2. PR complementario (pequeño, gancho de confianza): `ErpHttpOkCookie` con
   `Access-Control-Allow-Origin` opcional por config + rebuild del exe desde
   fuentes actuales.
3. Issue/discussion proponiendo la matriz de ramas (PC/híbrida/web) con
   detección de contenedor — el mismo patrón probado en producción por Zerus
   (WebView2 + tableros + worker HTTP).
4. Adjuntar este sustento + `docs/evidencia/` (8 capturas) + guiones
   reproducibles.

*Generado con lecturas y pruebas de solo ejecución; el sample Harbour no fue modificado.*
