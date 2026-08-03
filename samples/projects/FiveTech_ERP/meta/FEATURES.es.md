# Sample ERP DesktopWeb — lista de características

Construido como **sample meta-driven FiveWin / Harbour**: un shell de escritorio Windows (WebView2) + servidor HTTP embebido; la misma UI funciona en el navegador y en el escritorio.

Versión en inglés: [FEATURES.md](FEATURES.md)  
Hoja de ruta: [ROADMAP.es.md](ROADMAP.es.md) · [ROADMAP.md](ROADMAP.md)

---

## 1. Arquitectura y runtime

- **Doble entrega**: la app de escritorio WebView2 y la UI en navegador comparten el mismo HTML/CSS/JS y la API HTTP
- **Servidor HTTP multihilo embebido** (puerto por defecto **2222**, configurable)
- **Login con sesión** y cookie (`DWSESS`); usuarios en `data.users` (Admin → Users)
- Contraseñas guardadas solo como **CRC32** (nunca en claro); seed: `admin`/`1234`, `demo`/`demo`
- **Multi-empresa + multi-app**: empresa de sesión (`data.companies`); cada empresa puede tener **N apps** (verticals: clinic, demo, services, retail, **ferreteria**); selector barra de estado / `screen.context`; menú = app activa
- **Modelo de metadatos de la app**: archivos JSON en `meta/` → `data/appmeta.dbf` → caché en memoria
- **APIs en vivo**: `/api/login`, `/api/meta`, `/api/dataset`, `/api/patients`, `/api/balances`, `/api/verticals`, …
- **CRUD sobre datasets demo** (`data.*`) desde la UI (alta / edición / baja)
- **UI en inglés** (branding del sample: FiveTech Desktop & Web)

---

## 2. Autenticación y seguridad

- Pantalla de login (usuario, contraseña, fecha de trabajo) definida en meta
- **Puerta de admin** (estilo rol) para diseñadores y configuración de la app
- Usuarios no admin pueden usar pantallas operativas sin herramientas de diseño

---

## 3. Shell / chrome (escritorio + web)

- Navegación lateral impulsada por el meta `modules`
- Paneles de trabajo acoplados (chrome estilo painel en listados/detalle)
- Tokens de tema claro / oscuro (`theme.json`)
- Branding: texto del logo, nombre de marca, subtítulo, título de ventana
- Mensajes toast, modales flotantes, panel de búsqueda de pacientes estilo F2
- **Centro de aprendizaje Demo** (`demo.main` modo menú / **▶ Demo**): catálogo de tours (`demo.overview`, `demo.list_edit`, `demo.designers`, `demo.multi_app`); elige qué aprender; Pause/Next/Stop; al terminar vuelve al menú; autoarranque opcional para `demo`

---

## 4. Pantallas y layouts meta-driven

Motor genérico de pantallas impulsado por JSON. **Layouts** soportados:

| Layout | Propósito |
|--------|-----------|
| `list` | Rejilla + toolbar; opcionales `filters`, `markRows`, `totals` / `sumFields`; **diálogo Add/Edit** por defecto desde `grid.columns` (auto multi-columna); `form` opcional por pantalla (diseñador admin) |
| `master-detail` | Rejilla maestra + líneas de detalle enlazadas |
| `document` | Documento + totales de líneas + impuestos |
| `form` | Ficha / formulario con pestañas |
| `wizard` | Asistente multipaso |
| `folder` | Carpeta con pestañas (pantallas hijas) |
| `menu` | Painel de grupos de acciones |
| `calendar` | Estilo día / agenda |
| `dashboard` | Tiles de KPIs + widgets bar/donut (`dashboard.widgets`, Design form) |
| `tree-detail` | Árbol organizativo + detalle |
| `matrix` | Matriz de turnos / huecos |
| `assign` | Asignación dual-list (usuarios ↔ roles) |
| `workflow` | Cola por estado + transiciones (pipeline) |
| `settings` | Formulario tipo parámetros |
| `audit` | Vista de log de auditoría |
| `import` | Esbozo de importación CSV |
| `period` | Esbozo de periodo / cierre |
| `context` | Contexto de empresa / multi-empresa |
| `report-list` | Catálogo de informes |

**Controles de campos en rejilla**: text, money, select, checklist (multi), checkbox

**Barras de herramientas**: alta, edición, baja, impresión, PDF, Excel/CSV, refrescar, cerrar

---

## 5. Core CRM (genérico, siempre sembrado)

- **Parties** (personas y organizaciones, roles, origen, propietario)
- **Ficha de party** (formulario con pestañas)
- **Cuentas / accounts** (segmentos / partners / empresas)
- **Actividades** (llamada, tarea, cita, reunión, nota)
- **Oportunidades** (importes del embudo, probabilidad, fecha de cierre)
- **Tablero de pipeline** (layout workflow por etapa)
- El lookup / maestro F2 prioriza **parties** y cae a patients si hace falta

---

## 6. Packs verticales de industria

Seleccionables con `app.vertical` o **Edit app → Vertical pack** (se aplican al momento):

| Vertical | Enfoque |
|----------|---------|
| **clinic** | Pacientes, fichas, saldo, exámenes, admisión, facturas, presupuestos, agenda |
| **services** | Proyectos, ficha de proyecto, partes de horas, entrega + comercial |
| **retail** | Productos, stock, tickets TPV, back-office de tienda |

- Los packs viven en `meta/verticals/<nombre>/modules.json`
- Si hay un pack activo, las ediciones de menú se escriben en ese pack
- Al quitar el pack se restaura el `modules.json` base
- API: `GET /api/verticals`

---

## 7. Demos clínica / sanidad

- Maestro de pacientes
- Ficha de paciente (form)
- Saldo de paciente
- Archivo de exámenes
- Asistente de admisión
- Citas (rejilla operativa tipo home)
- Agenda del día (calendario)
- Facturas maestro-detalle
- Presupuestos documento con totales de IVA

---

## 8. Demos vertical services

- Listado de proyectos (presupuesto, gastado, estado, tipo)
- Ficha de proyecto (pestañas de formulario)
- Partes de horas / timesheets (horas, tarifa, importe, facturable, estado de aprobación)
- Reutiliza parties del CRM, presupuestos, facturas, órdenes de trabajo

---

## 9. Demos retail / TPV

- Catálogo de productos (SKU, código de barras, impuesto, UdM)
- Stock por almacén (cantidad, mínimo, reservado, ubicación, estado)
- Tickets de venta TPV (caja, cajero, forma de cobro, estado)
- Parties de clientes / segmentos

---

## 10. Galería de formularios ERP (demos)

- Dashboard de KPIs
- Árbol de organización
- Matriz de turnos semanal
- Asignación usuarios ↔ roles
- Cola de aprobaciones (workflow)
- Parámetros / settings
- Log de auditoría
- Importación CSV
- Cierre de periodo
- Contexto de empresa
- Órdenes de trabajo y catálogo de servicios (demos de controles)
- Grupo, presupuesto, contabilidad, listado de calendario, estadísticas

---

## 11. Diseñadores (solo admin)

### Diseñador de formularios

- Diseña cualquier `screen.*` / `lookup.*` en tiempo de ejecución
- Elige layout, título, dataRef, columnas / tipos de campo y opciones
- Ajustes master-detail (dataRef de detalle, clave de enlace)
- **Form / wizard**: campo clave + pestañas/pasos (`id|Etiqueta|campos`)
- **Workflow / pipeline**: campo de estado + transiciones
- Guarda en memoria + DBF + `meta/screens/*.json`

### Edit app (diseñador de aplicación)

- Branding (logo, nombre, subtítulo, título de ventana)
- Puerto HTTP (hace falta reiniciar para el bind)
- **Database** driver / conexión OpenADS
- **Locale y números** (ver abajo)
- **Catálogo Screens**: listar / nueva / editar (→ form designer) / abrir / borrar `screen.*`
- **Catálogo Processes**: listar / nueva / ejecutar / borrar `process.*` (enlaza handlers Harbour compilados)
- **Editor completo del menú lateral** (secciones, ítems, iconos, pantallas **o procesos**, sub/activo)

Borrar screen/process: `POST /api/meta` con `{ "key":"screen.x"|"process.x", "action":"delete" }` (admin; no `app` / `modules` / `screen.login`).

### Procesos (Harbour en servidor)

- Meta en `meta/processes/*.json` → clave `process.*`
- Cada proceso nombra un **handler de lista blanca** en `erp_proc.prg` (nunca código en el browser)
- Ejecutar: `POST /api/process` `{ "key":"process.hello", "params":{}, "row":{...} }`
- Desde **menú**, **toolbar** o Edit app → Processes → Run
- Handlers demo: `Hello`, `EchoContext`, `PingStatus`

---

## 12. Configuración regional y de locale

Guardada en `app.locale`, editable en Edit app:

- Código y símbolo de moneda
- Posición del símbolo (prefijo / sufijo / ninguno)
- Mostrar u ocultar el símbolo en rejillas
- Decimales (0–6)
- Separadores decimal y de miles
- % de IVA / impuesto por defecto (totales de documento)
- Formato de fecha, formato de hora, primer día de la semana
- Vista previa en vivo en el diseñador
- Runtime `moneyFmt` / `parseMoney` + refresco de rejillas abiertas al guardar

---

## 13. Informes (esbozo ligero — no es un diseñador de bandas)

- Documentos meta `report.*` en `meta/reports/`
- Informes de ejemplo: parties (agrupado), proyectos (agrupado + sumas), día TPV
- Pantalla **catálogo de informes** (vista previa / PDF / CSV)
- **Guardar como informe** desde cualquier listado (admin): captura columnas, dataRef, groupBy opcional
- Cabeceras de grupo, subtotales en campos money, total general, orientación
- Print/PDF/Excel ad-hoc siguen disponibles en las rejillas en vivo

---

## 14. Impresión y exportación

- Imprimir listado / informe (diálogo de impresión del navegador)
- Imprimir a PDF (vía diálogo de impresión)
- **Exportación CSV** estilo Excel (BOM, separador punto y coma)
- Recálculo de documento (subtotal / impuesto / total)

---

## 15. Modelo de datos (datasets demo en JSON)

Ejemplos entre muchos:

- CRM: parties, accounts, activities, opportunities
- Clínica: patients, balances, exams, patient cards, huecos de agenda del día
- Comercial: invoices + lines, quotes + lines, catalog
- Services: projects, timesheets
- Retail: products, stock, pos_sales
- Admin: users, roles, user_roles, settings, audit, companies, workflow, KPIs de dashboard, árbol org, slots de matriz

Las mutaciones en runtime persisten por la ruta meta/DBF del sample.

---

## 16. Admin y operaciones de plataforma (alcance sample)

- Pantalla de parámetros
- Vista de log de auditoría
- Asignación de usuarios / roles
- Contexto de empresa
- Esbozo de importación CSV
- Esbozo de cierre de periodo
- Rutas de entrada configurables (`login` / `home` en `app.json`)

---

## 17. Ingeniería del sample / desarrollador

- Compilación con `build_new.bat` (p. ej. `hm64 -mt`)
- Fuente de verdad: JSON bajo `meta/` (amigable con git)
- Ruta de carga y diseñadores documentados en `meta/README.md`
- README de verticals clinic / services / retail
- Patrones seguros para Harbour `TEXT INTO` (sin escapes JS rotos)

---

## Qué *no* es esto (alcance honesto)

- Producto contable GL completo / multi-libro
- Diseñador visual nativo de bandas tipo Crystal/FastReport
- Modelo de seguridad SaaS multi-tenant de producción
- Hardware real de TPV, nóminas o MRP de fabricación profundo

**Sí es** un shell ERP de demostración: **UI meta + core CRM + verticales de industria + diseñadores + locale + informes ligeros**, útil para demos y como plano de apps FiveWin Desktop & Web.

---

Ver también: [README.md](README.md) (inglés) sobre estructura de meta y notas de API.
