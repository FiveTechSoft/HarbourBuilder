# Hallazgo — Race condition en `POST /api/dataset` (escritura concurrente)

**Prototipo web-branch · 2026-08-08 · reproducible con `scripts/concurrency-write.py`**

## Síntoma (exe oficial / fuentes sin parche)

Con 10 sesiones concurrentes haciendo add→update→delete de filas propias:

```
sesiones: 10 x 3 filas · OK: 2 · errores: 8 · ops CRUD: 18
integridad: filas antes=12 despues=13 -> CORRUPCION
  ERR sesion 5: update: Row not found: code=ZZW050   (el add se perdió)
  ...
```

## Causa raíz

En `ErpApiDatasetPost` (erp_http.prg) el ciclo **read-modify-write** no es
atómico: `ErpMetaGetRaw()` lee el documento **fuera** de `s_mtx`; solo la
escritura final (`ErpWriteFileAtomic`) está protegida. Dos escrituras
concurrentes hacen: A lee(12) · B lee(12) · A escribe(13) · B escribe(13 con
su fila, sin la de A) → **last-writer-wins sobre el doc completo**: se pierden
adds (de ahí "Row not found" al update) y quedan residuos si el delete de una
sesión pisa el add de otra.

Es el mismo tipo de bug que el proyecto Zerus documentó para su legacy
(categoría "locks como categoría propia" en el banco de paridad, auditoría
WebView2/HTTP §5.1 C1).

## Fix aplicado en la copia local (propuesto para el PR)

1. `ErpMutexGuard` (clase con destructor): Harbour libera el LOCAL al salir de
   la función por **cualquier** return → el destructor hace `hb_mutexUnlock`.
2. En `ErpApiDatasetPost`: `oGuard := ErpMutexGuard():New( s_mtx )` **antes**
   de `ErpMetaGetRaw()` → el RMW completo queda dentro de la sección crítica.
3. Se retira el lock/unlock redundante alrededor de `ErpWriteFileAtomic`
   (el mutex de Harbour no es recursivo → deadlock si se anida).

## Resultado con el fix (exe local recompilado)

```
sesiones: 10 x 3 filas · OK: 10 · errores: 0 · ops CRUD: 90 · ~900 ms
integridad: filas antes=12 despues=12 -> OK
```

Sin regresión: `api-check.mjs` 8/8 y `evidence.cjs` 4/4 frontends en verde.

## Notas para el PR

- El mismo patrón RMW sin lock completo aparece en `ErpUserSavePrefs` y
  `ErpApiMetaPost` (mem-only path). Revisar con el mismo guard.
- El path `dbfcdx/openads` (`ErpDbApply`) no pasa por este RMW JSON; su
  concurrencia depende del RDD (OpenADS tiene sus locks).
- El guard no cambia el contrato HTTP ni el comportamiento monousuario: es un
  fix interno de bajo riesgo.
