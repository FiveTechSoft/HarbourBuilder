# DesktopWeb — hoja de ruta de producto

Posicionamiento (Pritpal, 2026): este sample es esencialmente un **constructor de aplicaciones ERP** — completo e impresionante. El foco debe pasar a la **simplicidad para cambiar elementos** y la **seguridad de los datos**. Los front-ends, sobre todo web, son propensos a fugas y exigen máxima atención. Conforme **OpenADS** madure, la retención y la seguridad de datos deben apoyarse en él. Las pantallas **data-driven con validaciones in-place** son un dolor de cabeza en el mundo GUI, y más aún cuando el usuario puede editar la definición de componentes — pero si se resuelve bien, puede ser un **killer en su segmento**.

Versión en inglés: [ROADMAP.md](ROADMAP.md).  
Inventario de características: [FEATURES.es.md](FEATURES.es.md) · [FEATURES.md](FEATURES.md).

---

## 1. Identidad de producto

| Hoy (sample) | Objetivo (plataforma) |
|--------------|------------------------|
| Shell ERP meta-driven + demos (clinic / services / retail) | **Constructor de aplicaciones ERP** Desktop & Web |
| Meta JSON + datos demo/DBF local | Misma UI meta + **plano de datos endurecido** (OpenADS) |
| Diseñadores admin (forms, menú, locale, informes ligeros) | Edición simple y segura de definiciones + **reglas en servidor** |
| Escaparate impresionante | Segmento: FWH / mid-market / builders desktop+web |

**Promesa a mantener**

- Cambiar la estructura sin recompilar (meta JSON + diseñadores).
- Misma UI en Windows (WebView2) y en el navegador.
- Verticals como menú/etiquetas sobre un core CRM compartido.

**Promesa a ganar**

- Cambiar datos solo con derechos, validación y auditoría.
- El front web no puede saltarse reglas ni filtrar meta privilegiada.

---

## 2. Pilares estratégicos (del feedback)

1. **Simplicidad para cambiar elementos** — menos pasos, diseñadores claros, menos meta roto.
2. **Seguridad de datos** — mínimo privilegio, autoridad en servidor, no confiar solo en el browser.
3. **Validación data-driven** — reglas en meta, aplicadas en cliente y servidor, también al diseñar.
4. **OpenADS como columna vertebral de datos** — retención, seguridad, multi-usuario cuando esté listo.

---

## 3. Fases

### Fase A — Endurecer el sample (corto plazo)

*Objetivo: mismas demos, superficie HTTP fiable para uso local/LAN.*

| Ítem | Notas |
|------|--------|
| Modelo de roles | Más allá de `admin` / resto: p. ej. `admin`, `designer`, `user`, `readonly` |
| Autorización API | Toda ruta de mutación comprueba el rol **en servidor** (nunca solo `IS_ADMIN` en JS) |
| Cookie / sesión | `HttpOnly`, `SameSite`, `Secure` opcional; timeout de inactividad; logout invalida |
| CSRF | Token o disciplina same-site en `POST /api/*` |
| Allowlists de escritura | Qué claves `data.*` / `screen.*` se pueden escribir; denegar por defecto |
| Errores limpios | Sin rutas ni stack traces al cliente |
| Carga de meta robusta | Seed por carpetas + fallback a disco + strip BOM UTF-8 (en marcha) |
| Auditoría | Quién cambió qué meta / fila de datos (log append-only) |

### Fase B — Edición segura y validación (medio plazo)

*Objetivo: diseñadores potentes sin inventar comportamiento inseguro.*

| Ítem | Notas |
|------|--------|
| Schema de campos en meta | `required`, `min`/`max`, `pattern`, `options`, `readonly`, `unique` |
| Validación servidor | `POST /api/dataset` rechaza filas inválidas con error por campo |
| Validación cliente | Mismas reglas para UX; nunca la única barrera |
| Límites del diseñador | Solo tipos/layouts del schema; sin lógica ejecutable libre desde el browser |
| Borrador / publicación | Opcional: editar draft de `screen.*`, publicar a la clave viva |
| Undo / versiones | Guardar últimas N versiones de documentos diseñados |
| Edición contextual | “Diseñar esta pantalla” desde el workspace abierto |
| Diseñador de app/menú | No dejar huérfana la home; ruta de guardado del vertical explícita |

Ejemplo de regla de campo (esbozo):

```json
{
  "id": "email",
  "type": "text",
  "required": true,
  "pattern": "email",
  "maxLength": 120
}
```

### Fase C — Plano de datos OpenADS (cuando OpenADS esté listo)

*Objetivo: mismas pantallas; almacenamiento y derechos de producción.*

| Ítem | Notas |
|------|--------|
| Adaptador `dataRef` | Mapear datasets meta a tablas / queries ADS |
| Rights en servidor | Usuario/rol → tabla/campo/fila (OpenADS + capa app) |
| Multi-empresa | Alinear con layout `context` / selector de compañía |
| Retención | Backup, archivo, retención legal según prácticas ADS |
| Concurrencia | Locks optimistas o de ADS en update |
| Migración | JSON demo → herramientas de seed ADS por vertical |

### Fase D — Pulido de plataforma (después)

| Ítem | Notas |
|------|--------|
| Informes | Crecer `report.*` (filtros, parámetros) sin band designer completo al inicio |
| Más verticals | Solo con A–B estables (seguridad + validación) |
| Tema / branding | Parcial hoy; acotar quién puede cambiar `app` / theme |
| Tests automáticos | Matriz de auth API; matriz de validación; smoke de import meta |
| Tour de producto | Mantener demo didáctica; opcional `demo.*` por vertical |

---

## 4. No-objetivos explícitos (por ahora)

- Contabilidad GL completa / nóminas / TPV hardware como producto core.
- Diseñador visual de bandas tipo Crystal/FastReport como prioridad v1.
- Ejecución de scripts arbitrarios desde meta (anti-patrón de seguridad).
- SaaS multi-tenant público sin completar fases A–C.
- Más demos verticales a costa de profundidad en seguridad/validación.

---

## 5. Criterios de éxito (“killer en su segmento”)

Un partner o ISV puede:

1. Clonar el sample, cambiar vertical, rebranding y locale — **en minutos**, sin rebuild C.
2. Diseñar una pantalla list/form/workflow en la app — **sin romper** los datos de otros usuarios.
3. Exponer la UI web en LAN — **sin** escrituras anónimas ni fuga de meta.
4. Apuntar `dataRef` a OpenADS — **mismas pantallas**, rights y audit reales.
5. Explicar el producto en una frase: *“Constructor ERP meta-driven para Desktop & Web.”*

---

## 6. Orden de trabajo sugerido (corto plazo)

1. **Security pass** del HTTP API (roles, CSRF, allowlists, sesión).
2. **Schema de validación** en `screen.*` + enforce en `POST /api/dataset`.
3. **Seguridad del diseñador** (campos solo-schema, draft/publish opcional).
4. **Adaptador OpenADS** detrás de `dataRef` cuando el stack ADS esté maduro para el sample.
5. Ampliar verticals / reports solo después de 1–3.

---

## 7. Mapa de documentación

| Doc | Propósito |
|-----|-----------|
| [FEATURES.es.md](FEATURES.es.md) | Qué hace el sample hoy |
| [README.md](README.md) | Layout meta, API, locale, tour demo (EN) |
| [ROADMAP.es.md](ROADMAP.es.md) | Este archivo — dónde invertir después |
| `verticals/*/README.md` | Enfoque de menú por pack |

---

*Hoja de ruta orientativa para el sample DesktopWeb y la conversación de producto; no compromete fechas ni números de release de FiveTech.*
