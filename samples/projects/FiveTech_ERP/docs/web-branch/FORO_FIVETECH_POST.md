# FiveTech_ERP ya es un ERP web — propuesta de rama web parametrizable (PC / híbrida / 100% web)

*Post de contribución técnica · sin ánimo comercial · todo el código queda MIT como el repo.*

Hola Antonio, comunidad:

Llevamos semanas trabajando con el sample `FiveTech_ERP` de HarbourBuilder
(para entender su contrato, no para otra cosa) y llegamos a una conclusión que
queremos devolver al proyecto como propuesta: **el sample ya es, técnicamente,
un ERP 100% web que hoy se muestra con un WebView**. El servidor
`erp_http.prg` atiende en `0.0.0.0`, sirve HTML, meta JSON y API con sesión
por cookie HttpOnly… exactamente el mismo contrato que consume su WebView2.

Lo que proponemos es **encender esa luz**: declarar una matriz de tres ramas
sobre el mismo binario y el mismo contrato, con el frontend como parámetro del
despliegue. Adjuntamos prototipo funcional, evidencia medible y dos parches
verificados.

---

## 1. El concepto en una figura

```
              FiveTech_ERP.exe  (erp_http.prg, sin cambios)
              API JSON + meta FWH + estáticos  ·  cookie DWSESS
                            │
      ┌─────────────────────┼──────────────────────┐
      ▼                     ▼                      ▼
  Rama PC               Rama híbrida           Rama 100% web
  WebView2 del exe      WebView2 por módulo    navegador real
  (ZWEB_FRONT=…)        dentro del shell       PC / tablet / móvil
                        nativo (FW_DASHBOARD)  /portal/ → 4 frontends
```

**Regla de oro:** el frontend es un parámetro del despliegue, no del código.
Lo demostramos consumiendo el mismo contrato con **cuatro frontends distintos**
sin adaptadores: vanilla (HTML/CSS/JS puro), **Angular 21 + PrimeNG**, React 19
y Vue 3 — login, multi-empresa/multi-app, grilla CRUD desde `screen.*`/`data.*`
y ejecución de `process.*`.

## 2. Las tres ramas, en corto (¿cuál y cuándo?)

| Rama | Cómo se activa | Recomendada para | A favor | En contra |
|---|---|---|---|---|
| **PC** | `ZWEB_FRONT=web-angular` → el WebView2 del exe carga esa montura | enterprise on-premise, puesto fijo, migraciones de FiveWin | cero infraestructura nueva; actualizar = reemplazar exe | requiere Windows en el puesto; scaling por puesto |
| **Híbrida** | shell nativo monta `/web-*` por módulo junto a pantallas nativas | ERP legacy en modernización incremental | riesgo acotado por módulo; convive con lo estable | coordina dos mundos (foco, estilos, atajos) |
| **100% web** | cualquier navegador → `http://servidor:2222/portal/` | SaaS multi-tenant, remotos, móviles, clientes sin legacy | despliegue y actualización centrales; cualquier dispositivo | exige TLS/hardening para internet; renderer de layouts no-list pendiente |

Las ramas **conviven**: mismo backend, mismos datos, misma sesión de negocio.
Un usuario en WebView2 y otro en navegador no se distinguen del lado Harbour.

## 3. Evidencia (todo reproducible con un comando)

| Prueba | Resultado |
|---|---|
| Contrato completo desde navegador (login→contexto→meta→dataset→CRUD→logout) | 8/8 OK, ~80 ms |
| 10 sesiones concurrentes (lectura) | 10/10, login mediana 175 ms |
| 10 sesiones × 3 filas CRUD concurrentes **con el fix** | 10/10, integridad 12→12 |
| 4 frontends: login → cambio de app → grilla CRUD (Playwright) | 4/4, 697–784 ms |
| Rama PC: SPA dentro del WebView2 del exe | captura adjunta |
| UTF-8 (tildes, €, ñ) intacto por el canal | capturas adjuntas |

## 4. Lo que entregamos (para revisión / merge si lo aprueban)

1. **Sample `FiveTech_ERP_Web`**: monturas `web-vanilla|angular|react|vue`
   servidas como estáticos del propio backend + `/portal/` (selector de
   frontends con asistente de activación por rama) + `INICIAR.bat`
   (menú de usuario final: rama web / PC / híbrida + frontend por defecto).
2. **Parche `Form1.prg` (3 líneas, opt-in)**: variable `ZWEB_FRONT` — sin ella,
   el exe se comporta exactamente igual que hoy.
3. **Parche `erp_http.prg` — fix de concurrencia (regalo importante)**:
   `POST /api/dataset` pierde escrituras bajo clientes simultáneos: la lectura
   del doc JSON vive **fuera** del mutex (read-modify-write no atómico →
   last-writer-wins). Lo medimos: sin fix, 2/10 sesiones OK y filas perdidas;
   con el fix (guard de mutex con destructor, RMW atómico) 10/10 sin
   corrupción. El mismo patrón aparece en `ErpUserSavePrefs`/`ErpApiMetaPost`
   para su revisión.
4. **Parche opcional CORS**: `ErpHttpOkCookie` no emite
   `Access-Control-Allow-Origin` (sí `ErpHttpOk`); lo proponemos opcional por
   configuración para desarrollo cross-origin, sin cambiar el default.

## 5. Garantías (por qué aprobarlo es seguro)

- Todo es **opt-in**: sin variable/config nueva, el sample es el de hoy.
- **Contrato congelado**: solo adiciones; ninguna ruta o JSON existente cambia.
- **Sin dependencias nuevas en Harbour**: los frontends son estáticos; el
  servidor ignora qué framework los sirve.
- Método verificable: cada número tiene su guion (`api-check.mjs`,
  `concurrency.py`, `concurrency-write.py`, `evidence.cjs`).

## 6. Alineado con su roadmap

- **HIX**: cuando estabilice, podrá reemplazar al servidor del sample **sin
  tocar los frontends** (mismo contrato). El sample web queda como banco de
  pruebas de HIX.
- **Android nativo del IDE**: complementario (móvil offline), no competidor.
- **Builds por SO**: intactos; la rama web no añade ni una línea a esos scripts.

## 7. Preguntas abiertas al mantenedor

1. ¿Aceptan el sample `FiveTech_ERP_Web` como variante oficial (carpeta propia)?
2. ¿El fix de concurrencia por guard-destructor o prefieren relectura dentro
   del lock? (ambas validadas conceptualmente; la primera ya medida).
3. ¿`ZWEB_FRONT` como variable de entorno o prefieren argumento/INI?
4. ¿Rebuild del `FiveTech_ERP.exe` incluido en el repo? Hoy el binario
   empaquetado es anterior a los fuentes (no devuelve `isAdmin/canSwitch*`).

## 8. Reproducir en 5 minutos

```
1) Ejecutar backend\FiveTech_ERP_local.exe   (o el oficial: mismo contrato)
2) Navegador → http://127.0.0.1:2222/portal/   (admin/1234)
3) node scripts/api-check.mjs
4) python scripts/concurrency-write.py 10 3
5) set ZWEB_FRONT=web-angular && start backend\FiveTech_ERP_local.exe
```

Cierro como empezó: esto no vende nada — devuelve al proyecto método, código y
evidencia. Si la dirección técnica lo aprueba, lo siguiente sería un renderer
de layouts no-list (`form`, `dashboard`) en un frontend de referencia y la
receta TLS para exposición internet.

Gracias por el sample: es la mejor prueba de concepto de "Harbour como
servidor de empresa" que hemos visto.

— equipo Russoft/Zerus
