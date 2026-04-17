# TWebServer — HIX Runtime Completo para macOS

**Fecha:** 2026-04-17  
**Estado:** Aprobado

## Objetivo

Implementar `TWebServer` como componente no-visual en HarbourBuilder (macOS) con el runtime HIX completo: servidor HTTP/HTTPS nativo, funciones globales `U*` compatibles con HIX, motor de templates, y dos proyectos de ejemplo en `samples/`.

El código de un controller HIX existente debe funcionar sin modificaciones dentro de HarbourBuilder.

---

## Arquitectura

```
App Harbour (HarbourBuilder)
│
├── TWebServer (non-visual component, classes.prg)
│   ├── Route Table (aRoutes)
│   └── Start() → GCD Background Queue (macOS)
│
└── GCD Background Queue
    ├── HTTP Listener (BSD sockets) / HTTPS (NWListener + TLS)
    ├── Request Parser → method, path, headers, body
    ├── Request Context (thread-local) ← funciones U* leen/escriben aquí
    ├── Route Dispatcher
    │   ├── bloque Harbour  → ejecuta directamente
    │   ├── archivo .prg    → hb_compile + call main()
    │   └── archivo estático → leer y servir
    └── Template Engine (UView) → procesa {{ }}, @args, @foreach
```

**Capas y archivos:**

| Capa | Implementación | Archivo |
|------|---------------|---------|
| HTTP Listener + parser | Objective-C + GCD + BSD sockets | `backends/cocoa/cocoa_webserver.m` (nuevo) |
| HTTPS/TLS | Network.framework `NWListener` | `backends/cocoa/cocoa_webserver.m` |
| Request Context thread-local | C + Harbour | `cocoa_webserver.m` + `hix_runtime.prg` |
| Funciones U* | Harbour puro | `source/hix_runtime.prg` (nuevo) |
| Motor de templates | Harbour puro | `source/hix_template.prg` (nuevo) |
| Clase TWebServer | Harbour | `source/core/classes.prg` (ampliar) |

---

## Clase TWebServer

```harbour
CLASS TWebServer
   DATA nPort          INIT 8080
   DATA nPortSSL       INIT 8443
   DATA cRoot          INIT "."
   DATA lHTTPS         INIT .F.
   DATA cSSLCert       INIT ""
   DATA cSSLKey        INIT ""
   DATA lRunning       INIT .F.
   DATA lTrace         INIT .F.
   DATA nTimeout       INIT 30
   DATA nMaxUpload     INIT 10485760   // 10 MB
   DATA cSessionCookie INIT "HIXSID"
   DATA nSessionTTL    INIT 3600
   DATA aRoutes        INIT {}
   DATA hErrorPages    INIT { => }

   DATA bOnStart       INIT nil        // { || }
   DATA bOnStop        INIT nil        // { || }
   DATA bOnError       INIT nil        // { |nCode, cPath| }

   METHOD New()
   METHOD Start()
   METHOD Stop()
   METHOD AddRoute( cMethod, cPath, xHandler )
   METHOD SetSSL( cCert, cKey )
   METHOD SetErrorPage( nCode, cFile )
ENDCLASS
```

### AddRoute xHandler

`xHandler` puede ser:
- **Bloque:** `{|| UWrite("hola") }` — ejecutado directamente; usa funciones U* globales igual que HIX
- **String ruta .prg:** `"controllers/home.prg"` — compilado y ejecutado como `main()`

---

## Funciones globales U* (HIX-compatibles)

Implementadas en `source/hix_runtime.prg`. Leen/escriben el **Request Context** del hilo actual (variable `t_oCtx` thread-local vía `hb_threadLocal()`).

### Input
```harbour
UGet( [cVar] )         // params GET  → cVal | hHash completo
UPost( [cVar] )        // params POST → cVal | hHash completo
UHeader( [cVar] )      // headers de entrada → cVal | hHash
UCookie( cName )       // valor de cookie
UServer( [cKey] )      // info servidor (HTTP_HOST, etc.) → cVal | hHash
UGetServerInfo()       // hHash completo de servidor
UGetIp()               // IP del cliente como string
```

### Output
```harbour
UWrite( ... )          // acumula texto en buffer de respuesta (acepta N args)
UView( cTpl, ... )     // render template relativo a cRoot; args → @args
UAddHeader( c, v )     // añade header HTTP de salida
USetStatusCode( n )    // establece HTTP status (default 200)
USetErrorStatus( n, cPage, cAjax )
USetCookie( cKey, cVal, nSecs, cPath, cDomain, lHttps, lOnlyHttp, cSameSite )
```

### Encoding / helpers
```harbour
UHtmlEncode( c )
UUrlEncode( c )
UUrlDecode( c )
Ulink( cText, cUrl )   // → "<a href='cUrl'>cText</a>"
ULoadHtml( cFile )     // ejecuta HTML relativo a cRoot
UExecuteHtml( cFile )  // ejecuta HTML con ruta absoluta
UExecutePrg( cFile )   // compila y ejecuta .prg, captura UWrite output
```

### Debug
```harbour
_d( ... )              // log a consola si lTrace = .T.
_w( ... )              // formatea variable para salida web
```

---

## Motor de templates (hix_template.prg)

### Sintaxis soportada

| Construcción | Comportamiento |
|---|---|
| `@args a, b, c` | Liga args de `UView()` a variables locales en orden |
| `{{ expr }}` | Evalúa expresión Harbour, inserta como string |
| `@foreach var IN array` | Itera array; `var` disponible en el bloque |
| `@endforeach` | Cierra bloque foreach |
| `@if expr` / `@else` / `@endif` | Condicional |
| HTML literal | Emitido tal cual vía UWrite() |

### Ejemplo
```html
@args mydata, cId

<h1>Ticket: {{ cId }}</h1>
<ul>
  @foreach oItem IN myData
    <li>{{ oItem[1] }} — {{ oItem[2] }}</li>
  @endforeach
</ul>
<p>Hora: {{ time() }}</p>
```

### Flujo interno de UView()
1. Leer archivo relativo a `TWebServer:cRoot`
2. Parsear `@args` → ligar parámetros recibidos a nombres de variables
3. Procesar línea a línea: evaluar `{{ }}`, gestionar `@foreach`/`@if`, emitir HTML literal
4. Todo el output va al buffer de respuesta del contexto actual

---

## Request Context (thread-local)

Estructura interna por hilo, gestionada en C:

```c
typedef struct {
    char   *method;        // "GET", "POST", ...
    char   *path;          // "/api/users"
    char   *query;         // "name=Ana&age=30"
    char   *body;          // body raw del request
    char   *client_ip;
    // headers de entrada como array de pares clave/valor
    // buffer de salida (response body acumulado)
    int     status_code;   // default 200
    // headers de salida
    // cookies de salida
} HixRequestContext;
```

Expuesto a Harbour como `hb_threadLocal()` con ID fijo. Las funciones U* acceden a él sin parámetros de contexto explícitos, igual que en HIX.

---

## Implementación HTTP en macOS

### HTTP (puerto nPort)
- BSD sockets (`socket`, `bind`, `listen`, `accept`) en GCD global queue
- Parser HTTP/1.1 mínimo: request line + headers + body
- Cada conexión aceptada → `dispatch_async` a queue concurrente

### HTTPS (puerto nPortSSL, cuando lHTTPS = .T.)
- `NWListener` de Network.framework con `NWProtocolTLS`
- Certificado autofirmado generado automáticamente si `cSSLCert = ""`
- Certificado personalizado si se provee `cSSLCert` + `cSSLKey`

### Archivos estáticos
- Si la ruta no coincide con ninguna ruta registrada y el archivo existe en `cRoot`, se sirve directamente
- MIME types comunes detectados por extensión (.html, .css, .js, .json, .png, .jpg, etc.)

---

## Funciones C expuestas a Harbour (HB_FUNC)

```c
UI_WebServerStart( nPort, nPortSSL, cRoot, lHTTPS, cSSLCert, cSSLKey, lTrace )
UI_WebServerStop()
UI_WebServerRunning()       // → lógico

// Contexto (llamadas desde dentro de un handler)
UI_HixGetMethod()
UI_HixGetPath()
UI_HixGetQueryString()
UI_HixGetBody()
UI_HixGetHeader( cName )
UI_HixGetClientIp()
UI_HixSetStatus( nCode )
UI_HixAddResponseHeader( cName, cVal )
UI_HixWrite( cText )        // acumula en buffer
UI_HixGetOutput()           // devuelve buffer acumulado (para enviar respuesta)
UI_HixClearOutput()
```

---

## Proyectos de ejemplo

### Sample 1: `samples/projects/webserver/`

Demuestra funcionalidad básica de TWebServer.

```
webserver/
  Project1.prg       // app principal: crea TWebServer, registra rutas
  Form1.prg          // UI: botones Start/Stop, TLabel con URL, TWebView
  www/
    index.html       // página estática de bienvenida
```

Rutas del sample:
- `GET /` → archivo estático `www/index.html`
- `GET /api/time` → bloque que devuelve JSON `{ "time": "12:34:56" }`
- `POST /api/echo` → bloque que lee `UPost()` y devuelve el body como JSON

### Sample 2: `samples/projects/hix_app/`

Demuestra compatibilidad 100% con HIX (controllers + templates).

```
hix_app/
  Project1.prg          // TWebServer + rutas → controllers
  Form1.prg             // UI con TWebView apuntando a localhost:8080
  controllers/
    home.prg            // function main() → UView("home.html", aData, cTicket)
    api.prg             // function main() → UWrite(hb_jsonEncode(hData))
  views/
    home.html           // template HIX: @args, {{ }}, @foreach
  www/
    style.css
```

El código de `controllers/home.prg` es idéntico al `example1.prg` del repositorio HIX original.

---

## Criterios de éxito

1. `oServer:Start()` levanta el servidor y no bloquea la UI
2. Un controller `.prg` copiado de HIX funciona sin modificaciones
3. Templates con `@args`, `{{ }}`, `@foreach` renderizan correctamente
4. HTTPS con certificado autofirmado funciona en Safari/TWebView
5. `oServer:Stop()` detiene el servidor limpiamente
6. Sample 1 muestra Start/Stop desde la UI y responde en TWebView
7. Sample 2 renderiza una página con template HIX completo en TWebView
