# Propuesta — Rama Web parametrizable para FiveTech_ERP

**De:** equipo Russoft/Zerus (usuario del ecosistema FiveWin/Harbour)
**Para:** FiveTechSoft · Antonio Linares · comunidad HarbourBuilder
**Fecha:** 2026-08-08 · **Estado:** prototipo funcional con evidencia reproducible
**Objetivo:** aprobación técnica de una **rama 100% web** como variante oficial del
sample `FiveTech_ERP`, sin romper nada de lo existente. No es una propuesta
comercial: es código + método + evidencia puestos a disposición del proyecto.

---

## 1. Resumen ejecutivo

FiveTech_ERP ya contiene, en un solo binario, **dos clientes del mismo contrato
HTTP**: el WebView2 de escritorio y cualquier navegador (el servidor
`erp_http.prg` atiende en `0.0.0.0` y sirve HTML, meta JSON y API). Lo que
falta no es tecnología: es **hacer explícita esa dualidad como matriz de tres
ramas** (PC / híbrida / 100% web) con un frontend intercambiable y
parametrizable.

Esta propuesta:

1. **Aporta** la capa que falta: monturas de SPA (`www/web-*`), portal de
   selección, parámetro `ZWEB_FRONT` para el exe, y detección de contenedor en
   el cliente.
2. **Regala** un fix verificado de concurrencia en `POST /api/dataset`
   (race condition con pérdida de escrituras bajo clientes simultáneos).
3. **Demuestra** con 4 frontends reales (vanilla, Angular 21+PrimeNG, React,
   Vue) que el meta JSON de FWH DesktopWeb se renderiza fuera del WebView,
   con CRUD completo, multi-empresa y procesos.
4. **No toca** el shell FWH, el contrato HTTP, los scripts de build ni el
   comportamiento por defecto del exe.

---

## 2. Punto de partida (lo que el proyecto ya tiene)

| Pieza | Estado hoy | Rol en la propuesta |
|---|---|---|
| `erp_http.prg` | Servidor MT, sesiones con cookie `DWSESS` HttpOnly, TTL deslizante, multi-empresa/multi-app | Backend único de las 3 ramas — sin cambios |
| `meta/` (FWH DesktopWeb JSON) | screens/data/lookups/reports/processes + verticals | El "lenguaje" que cualquier frontend interpreta |
| `www/login.html` + `dashboard.html` | Shell HTML de escritorio (WebView2) | Rama PC por defecto — se conserva |
| Builds por SO | `build_win64.bat`, `build_linux.sh`, `build_mac.sh` | Automatización existente por plataforma |
| HIX (`hix_runtime.prg`) | Runtime HTTP en construcción | Futuro natural del servidor web standalone |
| Android nativo (IDE) | Pipeline APK del IDE | Complemento móvil nativo, ortogonal a esta propuesta |

**Brecha que cierra esta propuesta:** no existe hoy (a) un despliegue de SPA
externa servida por el propio backend, (b) un selector de frontend, (c) una
declaración explícita de qué contenedor (WebView vs navegador) usa cada rama.

---

## 3. El concepto en una figura

```
                      ┌────────────────────────────────────────────┐
                      │        FiveTech_ERP.exe (sin cambios)      │
                      │  erp_http.prg  →  API JSON + meta + estáticos
                      └───────────────┬────────────────────────────┘
                                      │  HTTP mismo origen · cookie DWSESS
        ┌───────────────┬─────────────┼──────────────┬──────────────────┐
        ▼               ▼             ▼              ▼                  ▼
   Rama PC          Rama híbrida   Rama 100% web   Rama 100% web     Shell FWH
   WebView2 del     WebView2 por   navegador PC    navegador móvil   original
   exe (ZWEB_FRONT) módulo dentro  /portal/ →      (mismo URL)       /login
                    del shell      web-vanilla |
                    nativo         web-angular |
                    (FW_DASHBOARD) web-react   |
                                               web-vue
```

**Regla de oro:** el frontend es un **parámetro del despliegue**, no del
código. Un solo build de cada SPA; lo único que cambia es el contenedor que
navega a su ruta. El contrato (login → contexto → meta → dataset → procesos)
es idéntico en las tres ramas — por eso cuatro frameworks distintos lo
consumen sin adaptadores.

---

## 4. Las tres ramas — ficha didáctica

### 4.1 Rama PC (WebView2 dentro del exe)

- **Qué es:** el exe de siempre; con `ZWEB_FRONT=<montura>` su WebView2 carga
  cualquier SPA del servidor en lugar del HTML FWH. Sin el parámetro,
  comportamiento 100% idéntico al actual.
- **Cómo se carga:** `set ZWEB_FRONT=web-angular && FiveTech_ERP.exe` (o
  `ZWEB_FRONT=portal` para elegir visualmente dentro del propio exe).
- **Cuándo recomendarla:**
  - Cliente **enterprise on-premise** con usuarios de escritorio fijo.
  - Instalaciones mono-puesto o con Terminal Server/RDP (el WebView vive en el
    servidor, el puesto solo remota pantalla).
  - Migraciones desde FiveWin donde se quiere UI web pero el despliegue
    sigue siendo "un exe por puesto".
- **Ventajas:** cero infraestructura nueva (el exe lo trae todo); funciona sin
  navegador instalado; actualización = reemplazar el exe; el mismo binario
  atiende a otros clientes web si se desea.
- **Desventajas:** requiere Windows en el puesto (WebView2); no sirve para
  usuarios remotos sin acceso al exe; el scaling es por puesto, no por servidor.

### 4.2 Rama híbrida (nativo + web por módulo)

- **Qué es:** un shell nativo (FiveWin/HarbourBuilder u otro) que monta un
  WebView2 **por módulo** apuntando a las rutas `/web-*`, conviviendo con
  pantallas nativas (patrón probado en producción por Zerus: tableros web
  dentro del ERP de escritorio).
- **Cómo se carga:** el contenedor nativo navega `http://127.0.0.1:2222/web-x/`
  módulo a módulo; detección con `window.chrome.webview` + bridge opcional
  (`SendToFWH`) para imprimir/F-keys nativas con fallback HTTP.
- **Cuándo recomendarla:**
  - **ERP legacy en modernización**: lo estable sigue nativo, lo nuevo
    (tableros, CRUDs de mantenimiento, reportes interactivos) entra web.
  - Operaciones de escritorio intensivas (browses de miles de filas,
    impresoras fiscales) + módulos modernos ligeros.
- **Ventajas:** migración incremental sin "big bang"; el riesgo por módulo es
  acotado; reutiliza permisos/sesión del ERP anfitrión.
- **Desventajas:** dos mundos que coordinar (estilos, atajos, foco); depende
  del shell nativo; no aplica a clientes sin legacy.

### 4.3 Rama 100% web (navegador real)

- **Qué es:** cualquier navegador (PC, tablet, móvil) consume el mismo
  backend: `/portal/` lista los frontends; login con cookie HttpOnly; CRUD y
  procesos completos.
- **Cómo se carga:** URL directa o portal; en producción detrás de un proxy
  TLS (igual que cualquier despliegue web).
- **Cuándo recomendarla:**
  - **SaaS multi-tenant**: el puesto no instala nada; el scaling es del lado
    del servidor (N procesos por sesión, como ya mide el pool de Zerus:
    ~9 MB privados por worker).
  - Usuarios remotos/móviles, franquicias, teletrabajo.
  - Clientes nuevos sin legacy de escritorio.
- **Ventajas:** despliegue y actualización instantáneos; cualquier dispositivo;
  el frontend puede evolucionar con frameworks modernos sin tocar Harbour;
  separación de responsabilidades (negocio en Harbour, UI en el stack que el
  cliente elija).
- **Desventajas:** exige TLS y hardening de exposición (el sample hoy es
  loopback/LAN por diseño); la sesión vive mientras viva el proceso (re-login
  ante reinicio).
- **Alcance de UI en el prototipo (estándar web de mantenimiento):**
  - Listas CRUD: paginación, filtros por `select`, ordenamiento, búsqueda,
    toolbar meta, export CSV/print, formulario modal con navegación
    entre registros.
  - Form (tabs + nav de registros) y master-detail/document.
  - **Fuera de alcance deliberado:** dashboard, calendar, wizard, designers,
    KPI tiles — el shell FWH `/dashboard.html` ya los renderiza; la SPA
    documenta la exclusión (no hay contrato grid/CRUD que demostrar).
    Ver `docs/SUSTENTO_RAMA_100_WEB.md` §Brechas.

---

## 5. Matriz rama × modelo de negocio

| Necesidad | PC | Híbrida | 100% web |
|---|---|---|---|
| Enterprise on-premise, puesto fijo | ★★★ recomendada | ★★ si hay legacy | ★ posible |
| ERP legacy en modernización | ★ | ★★★ recomendada | ★★ para módulos nuevos |
| SaaS multi-tenant | ✗ (scaling por puesto) | ✗ | ★★★ recomendada |
| Usuarios remotos / móviles | ✗ | ✗ | ★★★ (o Android nativo del IDE) |
| Sin equipo de frontend propio | ★★★ (HTML FWH listo) | ★★ | ★★ (vanilla listo) |
| Operación intensiva de escritorio | ★★★ | ★★★ | ★★ |
| Actualización centralizada | ★ (por exe) | ★★ | ★★★ |
| Aislamiento / offline por puesto | ★★★ | ★★★ | ★ |

(★ = aptitud relativa; la tabla es guía, no camisa de fuerza: las ramas
conviven y comparten backend y datos.)

---

## 6. Evidencia adjunta (todo reproducible)

| Prueba | Resultado | Guion |
|---|---|---|
| Contrato completo desde navegador | 8/8 OK, ~80 ms | `node scripts/api-check.mjs` |
| 10 sesiones concurrentes (lectura) | 10/10, login 175 ms | `python scripts/concurrency.py 10` |
| 10 sesiones × 3 filas CRUD concurrentes (con fix) | 10/10, integridad 12→12 | `python scripts/concurrency-write.py 10 3` |
| 4 frontends: login → multi-app → grilla CRUD | 4/4, 697–784 ms | `node scripts/evidence.cjs` (Playwright) |
| Rama PC con SPA dentro del WebView2 | captura OK | `ZWEB_FRONT=web-vanilla` + screenshot |
| UTF-8/tilde/€ intactos por el canal | capturas | `docs/evidencia/*` |

**Hallazgo incluido (regalo #1):** sin el fix, el estrés de escritura da
2/10 OK con pérdida de filas (last-writer-wins sobre el doc JSON; la lectura
vive fuera del mutex). El fix (`ErpMutexGuard`, destructor que libera el lock)
lo vuelve atómico: 10/10 sin corrupción. Documentado en
`docs/HALLAZGO_CONCURRENCIA_DATASETS.md`.

**Regalo #2 (PR pequeño):** `ErpHttpOkCookie` no emite
`Access-Control-Allow-Origin` (sí lo hace `ErpHttpOk`); se propone header
opcional por configuración para habilitar dev cross-origin sin cambiar el
comportamiento por defecto.

---

## 7. Qué se entrega exactamente (para revisión)

1. `samples/projects/FiveTech_ERP_Web/` — monturas `web-vanilla|angular|react|
   vue` + `portal/` + este documento + guiones de evidencia.
2. Parche a `Form1.prg`: `ZWEB_FRONT` (3 líneas; sin la variable el exe es
   byte-a-byte el de hoy en comportamiento).
3. Parche a `erp_http.prg`: `ErpMutexGuard` + RMW atómico en dataset.
4. Parche opcional CORS en `ErpHttpOkCookie`.
5. `docs/` con matriz de ramas y guía de cargue (ruta / app local / híbrida).

## 8. Garantías (por qué aprobarlo es seguro)

- **Sin cambios por defecto:** todos los parches son opt-in (variable, config,
  sample aparte). El build actual genera exactamente lo mismo que hoy.
- **Contrato congelado:** ninguna modificación a rutas/JSON existentes; solo
  adiciones opt-in.
- **Sin dependencias nuevas en Harbour:** los frontends viven como estáticos;
  el servidor no sabe qué framework los sirve.
- **Método verificable:** cada afirmación tiene guion de un comando; el
  reviewer puede destruir la propuesta en 10 minutos si algo no aguanta.
- **Alineado con su roadmap:** HIX podrá reemplazar mañana al servidor del
  sample sin tocar los frontends (mismo contrato U*/JSON); Android nativo del
  IDE cubre el caso móvil offline, complementario a la rama web.

## 9. Roadmap sugerido tras la aprobación

1. **Fase 0 (esta entrega):** sample + parches + evidencia. ✔ lista.
2. **Fase 1:** rebuild del `FiveTech_ERP.exe` incluido en el repo desde los
   fuentes actuales (hoy el binario empaquetado es anterior: no devuelve
   `isAdmin/canSwitch*`).
3. **Fase 2:** renderer de layouts no-list (form/dashboard) en al menos un
   frontend de referencia; documentar el resto.
4. **Fase 3:** guía TLS/proxy para exposición internet + receta de despliegue
   SaaS (pool de workers con afinidad de sesión, método Zerus).
5. **Fase 4 (opcional):** migrar el servidor del sample a HIX cuando estabilice,
   manteniendo el contrato.

## 10. Criterios de aceptación propuestos

- `run_tests`/builds existentes siguen en verde sin modificaciones.
- `api-check`, `concurrency*` y `evidence` en verde contra el exe recompilado.
- Comportamiento por defecto del exe idéntico (sin `ZWEB_FRONT`, sin config
  nueva).
- Revisión del fix de concurrencia por el mantenedor (es el único parche que
  toca lógica compartida; las alternativas están documentadas en el hallazgo).

---

## 11. Cómo reproducir todo en 5 minutos

```
git clone <fork>/HarbourBuilder && cd HarbourBuilder/samples/projects/FiveTech_ERP_Web
backend\FiveTech_ERP_local.exe          # o el oficial: mismo contrato
# navegador: http://127.0.0.1:2222/portal/   (admin/1234)
node scripts/api-check.mjs && python scripts/concurrency-write.py 10 3
set ZWEB_FRONT=web-angular && start backend\FiveTech_ERP_local.exe
```

---

*Cierre:* FiveTech_ERP ya es, técnicamente, un ERP web que hoy se muestra con
un WebView. Esta propuesta solo enciende la luz: declara la matriz de ramas,
la demuestra con cuatro frameworks y devuelve al proyecto dos parches
verificados. Se pide aprobación de la dirección técnica, no compromiso
comercial: el código queda MIT, como el resto del repo.
