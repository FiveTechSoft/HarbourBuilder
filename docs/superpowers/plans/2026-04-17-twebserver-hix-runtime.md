# TWebServer HIX Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement TWebServer with full HIX-compatible runtime — HTTP server, U* global functions, template engine — plus two sample projects that demonstrate basic usage and 100% HIX code compatibility.

**Architecture:** BSD sockets on a GCD background queue accept HTTP connections; each request is dispatched synchronously to the main thread (`dispatch_sync(main_queue)`) where Harbour runs safely. U* functions read/write a C global `HixCtx*` pointer that is valid only during handler execution (safe because all Harbour runs on the main thread serially). Template engine parses HIX syntax line by line in pure Harbour.

**Tech Stack:** Objective-C + GCD + BSD sockets (HTTP listener), Harbour PRG (U* runtime + template engine), Network.framework optional (HTTPS phase 2).

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `source/backends/cocoa/cocoa_webserver.m` | HixCtx, HTTP parser, socket server, HB_FUNCs for U* context |
| Create | `source/hix_runtime.prg` | All U* Harbour functions (UGet, UPost, UWrite, UView, …) |
| Create | `source/hix_template.prg` | Template engine: `@args`, `{{ }}`, `@foreach`, `@if` |
| Modify | `source/core/classes.prg` | Replace TWebServer stub with full class + Dispatch() method |
| Modify | `build_mac.sh` | Compile cocoa_webserver.m + hix_runtime.prg + hix_template.prg |
| Modify | `source/hbbuilder_macos.prg` | User-project build pipeline: compile + bundle-copy hix files |
| Create | `samples/projects/webserver/Project1.prg` | Sample 1 main |
| Create | `samples/projects/webserver/Form1.prg` | Sample 1 UI |
| Create | `samples/projects/webserver/www/index.html` | Sample 1 static page |
| Create | `samples/projects/hix_app/Project1.prg` | Sample 2 main |
| Create | `samples/projects/hix_app/Form1.prg` | Sample 2 UI (TWebView) |
| Create | `samples/projects/hix_app/controllers/home.prg` | HIX controller (identical to HIX example1.prg) |
| Create | `samples/projects/hix_app/controllers/api.prg` | JSON API controller |
| Create | `samples/projects/hix_app/views/home.html` | HIX template |
| Create | `samples/projects/hix_app/www/style.css` | Static CSS |

---

## Task 1: Replace TWebServer stub in classes.prg

**Files:**
- Modify: `source/core/classes.prg` (lines 2715–2748, existing stub)

- [ ] **Step 1: Replace the existing TWebServer stub**

Find and replace the entire block from `CLASS TWebServer` through `METHOD ServeStatic( cPath ) CLASS TWebServer … return "404 Not Found"` with:

```harbour
//============================================================================//
//  INTERNET COMPONENTS (Internet tab)
//============================================================================//

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
   DATA nMaxUpload     INIT 10485760
   DATA cSessionCookie INIT "HIXSID"
   DATA nSessionTTL    INIT 3600
   DATA aRoutes        INIT {}
   DATA hErrorPages    INIT { => }

   DATA bOnStart       INIT nil
   DATA bOnStop        INIT nil
   DATA bOnError       INIT nil

   METHOD New() CONSTRUCTOR
   METHOD Start()
   METHOD Stop()
   METHOD AddRoute( cMethod, cPath, xHandler )
   METHOD SetSSL( cCert, cKey )
   METHOD SetErrorPage( nCode, cFile )
   METHOD Dispatch( cMethod, cPath, cQuery, cBody, cIP )
ENDCLASS

METHOD New() CLASS TWebServer
return Self

METHOD Start() CLASS TWebServer
   if UI_WebServerStart( ::nPort, ::nPortSSL, ::cRoot, ::lTrace, Self )
      ::lRunning := .T.
      if ::bOnStart != nil; Eval( ::bOnStart ); endif
   endif
return Self

METHOD Stop() CLASS TWebServer
   UI_WebServerStop()
   ::lRunning := .F.
   if ::bOnStop != nil; Eval( ::bOnStop ); endif
return Self

METHOD AddRoute( cMethod, cPath, xHandler ) CLASS TWebServer
   AAdd( ::aRoutes, { Upper(cMethod), cPath, xHandler } )
return Self

METHOD SetSSL( cCert, cKey ) CLASS TWebServer
   ::cSSLCert := cCert
   ::cSSLKey  := cKey
   ::lHTTPS   := .T.
return Self

METHOD SetErrorPage( nCode, cFile ) CLASS TWebServer
   ::hErrorPages[ nCode ] := cFile
return Self

METHOD Dispatch( cMethod, cPath, cQuery, cBody, cIP ) CLASS TWebServer
   local i, aRoute, xHandler
   local cFilePath

   // Set cRoot for UView() and static file helpers
   HIX_SetRoot( ::cRoot )

   // Try registered routes first
   for i := 1 to Len( ::aRoutes )
      aRoute := ::aRoutes[ i ]
      if ( aRoute[1] == "*" .or. Upper(aRoute[1]) == Upper(cMethod) ) .and. aRoute[2] == cPath
         xHandler := aRoute[3]
         if ValType( xHandler ) == "B"
            Eval( xHandler )
         elseif ValType( xHandler ) == "C"
            HIX_ExecPrg( ::cRoot + "/" + xHandler )
         endif
         return nil
      endif
   next

   // Fall back to static file
   cFilePath := ::cRoot + cPath
   if cPath == "/"
      cFilePath := ::cRoot + "/index.html"
   endif
   if File( cFilePath )
      HIX_ServeStatic( cFilePath )
   else
      UI_HIX_SETSTATUS( 404 )
      UI_HixWrite( "<h1>404 Not Found</h1><p>" + cPath + "</p>" )
      if ::bOnError != nil; Eval( ::bOnError, 404, cPath ); endif
   endif

return nil
```

- [ ] **Step 2: Verify syntax by attempting a build**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -20
```

Expected: build proceeds past `[1/4] Compiling hbbuilder_macos.prg` (may fail later at link if cocoa_webserver.m is not yet created — that is expected).

- [ ] **Step 3: Commit**

```bash
git add source/core/classes.prg
git commit -m "feat(webserver): replace TWebServer stub with full class + Dispatch method"
```

---

## Task 2: Create cocoa_webserver.m — HTTP server + HB_FUNCs

**Files:**
- Create: `source/backends/cocoa/cocoa_webserver.m`

- [ ] **Step 1: Create the file**

```bash
touch /Users/usuario/HarbourBuilder/source/backends/cocoa/cocoa_webserver.m
```

- [ ] **Step 2: Write the complete implementation**

Write the following to `source/backends/cocoa/cocoa_webserver.m`:

```objc
/*
 * cocoa_webserver.m — HIX-compatible HTTP server for HarbourBuilder/macOS
 *
 * Architecture:
 *   - BSD socket listener on GCD global queue (background accept loop)
 *   - Each accepted connection → GCD concurrent queue (parse HTTP)
 *   - Harbour dispatch → dispatch_sync(main_queue) to call TWebServer:Dispatch()
 *   - s_current_ctx global pointer is valid only while Harbour handler runs
 *     (safe: all Harbour runs serialized on main thread)
 */

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>

#include "hbapi.h"
#include "hbvm.h"
#include "hbapiitm.h"
#include "hbapicls.h"

/* ── HixCtx ─────────────────────────────────────────────────── */

typedef struct {
    char   *method;
    char   *path;
    char   *query;
    char   *body;
    char   *ip;
    char   *out_buf;
    size_t  out_len;
    size_t  out_cap;
    int     status;
    char   *content_type;
} HixCtx;

static HixCtx *hix_ctx_new(const char *method, const char *path,
                             const char *query,  const char *body,
                             const char *ip)
{
    HixCtx *ctx   = calloc(1, sizeof(HixCtx));
    ctx->method   = strdup(method ? method : "GET");
    ctx->path     = strdup(path   ? path   : "/");
    ctx->query    = strdup(query  ? query  : "");
    ctx->body     = strdup(body   ? body   : "");
    ctx->ip       = strdup(ip     ? ip     : "");
    ctx->status   = 200;
    ctx->out_cap  = 8192;
    ctx->out_buf  = malloc(ctx->out_cap);
    ctx->out_buf[0] = '\0';
    ctx->content_type = strdup("text/html; charset=utf-8");
    return ctx;
}

static void hix_ctx_write(HixCtx *ctx, const char *text, size_t len)
{
    if (!text || len == 0) return;
    if (ctx->out_len + len + 1 > ctx->out_cap) {
        ctx->out_cap = (ctx->out_len + len + 1) * 2 + 4096;
        ctx->out_buf = realloc(ctx->out_buf, ctx->out_cap);
    }
    memcpy(ctx->out_buf + ctx->out_len, text, len);
    ctx->out_len += len;
    ctx->out_buf[ctx->out_len] = '\0';
}

static void hix_ctx_free(HixCtx *ctx)
{
    if (!ctx) return;
    free(ctx->method); free(ctx->path); free(ctx->query);
    free(ctx->body);   free(ctx->ip);   free(ctx->out_buf);
    free(ctx->content_type);
    free(ctx);
}

/* ── Global context pointer (main-thread only) ──────────────── */

static HixCtx  *s_current_ctx = NULL;
static PHB_ITEM s_pServer     = NULL;
static volatile int s_running = 0;
static int      s_listen_fd   = -1;

/* ── HTTP parser ─────────────────────────────────────────────── */

typedef struct {
    char method[16];
    char path[1024];
    char query[4096];
    char body[65536];
    char ip[64];
} ParsedRequest;

static int parse_http(int fd, const char *ip, ParsedRequest *req)
{
    char buf[16384];
    ssize_t n = recv(fd, buf, sizeof(buf)-1, 0);
    if (n <= 0) return -1;
    buf[n] = '\0';

    /* Request line: METHOD SP path SP HTTP/x.x */
    char *p = buf;
    char *sp = memchr(p, ' ', 16);
    if (!sp) return -1;
    int mlen = (int)(sp - p);
    if (mlen >= 16) mlen = 15;
    memcpy(req->method, p, mlen); req->method[mlen] = '\0';

    p = sp + 1;
    sp = memchr(p, ' ', 1100);
    if (!sp) return -1;
    char rawpath[1100];
    int rlen = (int)(sp - p);
    if (rlen >= 1024) rlen = 1023;
    memcpy(rawpath, p, rlen); rawpath[rlen] = '\0';

    char *qp = strchr(rawpath, '?');
    if (qp) {
        strncpy(req->query, qp+1, sizeof(req->query)-1);
        *qp = '\0';
    } else {
        req->query[0] = '\0';
    }
    strncpy(req->path, rawpath, sizeof(req->path)-1);
    strncpy(req->ip,   ip,      sizeof(req->ip)-1);

    /* Body (after \r\n\r\n) */
    req->body[0] = '\0';
    char *bstart = strstr(buf, "\r\n\r\n");
    if (bstart) {
        bstart += 4;
        int blen = (int)(n - (bstart - buf));
        if (blen > 0 && blen < (int)sizeof(req->body)) {
            memcpy(req->body, bstart, blen);
            req->body[blen] = '\0';
        }
    }
    return 0;
}

/* ── HTTP response sender ────────────────────────────────────── */

static void send_response(int fd, HixCtx *ctx)
{
    char hdr[512];
    int hlen = snprintf(hdr, sizeof(hdr),
        "HTTP/1.1 %d OK\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %zu\r\n"
        "Connection: close\r\n"
        "\r\n",
        ctx->status, ctx->content_type, ctx->out_len);
    send(fd, hdr, hlen, 0);
    if (ctx->out_len > 0)
        send(fd, ctx->out_buf, ctx->out_len, 0);
}

/* ── Harbour dispatch (runs on main thread) ──────────────────── */

static void harbour_dispatch(int client_fd, ParsedRequest *req)
{
    HixCtx *ctx = hix_ctx_new(req->method, req->path, req->query, req->body, req->ip);

    dispatch_sync(dispatch_get_main_queue(), ^{
        s_current_ctx = ctx;
        if (s_pServer) {
            HB_FUNC_EXEC( hb_vmPushSymbol( hb_dynsymFindName("DISPATCH") ) );
            hb_vmPush( s_pServer );
            hb_vmPushString( req->method, strlen(req->method) );
            hb_vmPushString( req->path,   strlen(req->path)   );
            hb_vmPushString( req->query,  strlen(req->query)  );
            hb_vmPushString( req->body,   strlen(req->body)   );
            hb_vmPushString( req->ip,     strlen(req->ip)     );
            hb_vmSend(5);
        }
        s_current_ctx = NULL;
    });

    send_response(client_fd, ctx);
    hix_ctx_free(ctx);
    close(client_fd);
}

/* ── HB_FUNCs ────────────────────────────────────────────────── */

HB_FUNC( UI_WEBSERVERSTART )
{
    int nPort = hb_parni(1);
    /* param 2: nPortSSL (future HTTPS) */
    /* param 3: cRoot   (handled in Harbour Dispatch) */
    /* param 4: lTrace */
    /* param 5: Self (TWebServer object) */

    if (s_pServer) { hb_itemRelease(s_pServer); s_pServer = NULL; }
    PHB_ITEM pSelf = hb_param(5, HB_IT_OBJECT);
    if (pSelf) s_pServer = hb_itemNew(pSelf);

    int lsock = socket(AF_INET, SOCK_STREAM, 0);
    if (lsock < 0) { hb_retl(HB_FALSE); return; }

    int opt = 1;
    setsockopt(lsock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(nPort);

    if (bind(lsock, (struct sockaddr*)&addr, sizeof(addr)) < 0 ||
        listen(lsock, 32) < 0) {
        close(lsock);
        hb_retl(HB_FALSE);
        return;
    }

    s_listen_fd = lsock;
    s_running   = 1;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (s_running) {
            struct sockaddr_in caddr;
            socklen_t clen = sizeof(caddr);
            int cfd = accept(s_listen_fd, (struct sockaddr*)&caddr, &clen);
            if (cfd < 0) { if (s_running) continue; break; }

            char ip[64] = "0.0.0.0";
            inet_ntop(AF_INET, &caddr.sin_addr, ip, sizeof(ip));

            __block int  bfd = cfd;
            __block char bip[64];
            strncpy(bip, ip, sizeof(bip));

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                ParsedRequest req;
                memset(&req, 0, sizeof(req));
                if (parse_http(bfd, bip, &req) == 0) {
                    harbour_dispatch(bfd, &req);
                } else {
                    close(bfd);
                }
            });
        }
        close(s_listen_fd);
        s_listen_fd = -1;
    });

    if (hb_parl(4)) NSLog(@"[HIX] HTTP server listening on port %d", nPort);
    hb_retl(HB_TRUE);
}

HB_FUNC( UI_WEBSERVERSTOP )
{
    s_running = 0;
    if (s_listen_fd >= 0) { shutdown(s_listen_fd, SHUT_RDWR); }
    if (s_pServer) { hb_itemRelease(s_pServer); s_pServer = NULL; }
    hb_ret();
}

HB_FUNC( UI_WEBSERVERRUNNING )
{
    hb_retl(s_running ? HB_TRUE : HB_FALSE);
}

/* — Context readers (called from hix_runtime.prg U* functions) — */

HB_FUNC( UI_HIX_METHOD ) { hb_retc(s_current_ctx ? s_current_ctx->method : ""); }
HB_FUNC( UI_HIX_PATH   ) { hb_retc(s_current_ctx ? s_current_ctx->path   : ""); }
HB_FUNC( UI_HIX_QUERY  ) { hb_retc(s_current_ctx ? s_current_ctx->query  : ""); }
HB_FUNC( UI_HIX_BODY   ) { hb_retc(s_current_ctx ? s_current_ctx->body   : ""); }
HB_FUNC( UI_HIX_IP     ) { hb_retc(s_current_ctx ? s_current_ctx->ip     : ""); }

HB_FUNC( UI_HIX_WRITE )
{
    if (s_current_ctx && hb_parclen(1) > 0)
        hix_ctx_write(s_current_ctx, hb_parc(1), hb_parclen(1));
    hb_ret();
}

HB_FUNC( UI_HIX_SETSTATUS )
{
    if (s_current_ctx) s_current_ctx->status = hb_parni(1);
    hb_ret();
}

HB_FUNC( UI_HIX_SETCONTENTTYPE )
{
    if (s_current_ctx && hb_parclen(1) > 0) {
        free(s_current_ctx->content_type);
        s_current_ctx->content_type = strdup(hb_parc(1));
    }
    hb_ret();
}

HB_FUNC( UI_HIX_STATUS )
{
    hb_retni(s_current_ctx ? s_current_ctx->status : 200);
}
```

- [ ] **Step 3: Fix the hb_vmPushSymbol call — remove incorrect macro wrapper**

The line `HB_FUNC_EXEC( hb_vmPushSymbol(...) )` in `harbour_dispatch` is wrong. `HB_FUNC_EXEC` is not needed here. Replace that block with the correct pattern:

```objc
        if (s_pServer) {
            hb_vmPushSymbol( hb_dynsymFindName("DISPATCH") );
            hb_vmPush( s_pServer );
            hb_vmPushString( req->method, strlen(req->method) );
            hb_vmPushString( req->path,   strlen(req->path)   );
            hb_vmPushString( req->query,  strlen(req->query)  );
            hb_vmPushString( req->body,   strlen(req->body)   );
            hb_vmPushString( req->ip,     strlen(req->ip)     );
            hb_vmSend(5);
        }
```

- [ ] **Step 4: Commit**

```bash
git add source/backends/cocoa/cocoa_webserver.m
git commit -m "feat(webserver): add cocoa_webserver.m — HTTP server + HixCtx + HB_FUNCs"
```

---

## Task 3: Create hix_runtime.prg — all U* functions

**Files:**
- Create: `source/hix_runtime.prg`

- [ ] **Step 1: Create the file with all U* functions**

Write the following to `source/hix_runtime.prg`:

```harbour
/*
 * hix_runtime.prg — HIX-compatible global functions for TWebServer
 *
 * All U* functions read/write through UI_HIX_* HB_FUNCs which access
 * the current HixCtx* in cocoa_webserver.m (main-thread only, safe).
 */

#include "hbbuilder.ch"

//─── Query string parser ─────────────────────────────────────────────────────

STATIC FUNCTION HIX_ParseQuery( cStr )
   local hResult := { => }
   local aPairs, aPair, i
   if Empty( cStr ); return hResult; endif
   aPairs := hb_aTokens( cStr, "&" )
   for i := 1 to Len( aPairs )
      aPair := hb_aTokens( aPairs[i], "=" )
      if Len( aPair ) >= 2
         hResult[ UUrlDecode(aPair[1]) ] := UUrlDecode(aPair[2])
      elseif Len( aPair ) == 1 .and. !Empty(aPair[1])
         hResult[ UUrlDecode(aPair[1]) ] := ""
      endif
   next
return hResult

//─── Input functions ─────────────────────────────────────────────────────────

FUNCTION UGet( cVar )
   local hGet := HIX_ParseQuery( UI_HIX_QUERY() )
   if cVar == nil; return hGet; endif
   if hb_hHasKey( hGet, cVar ); return hGet[ cVar ]; endif
return ""

FUNCTION UPost( cVar )
   local cBody := UI_HIX_BODY()
   local hPost
   // Try form-encoded first; JSON body is returned raw via UPost() with no arg
   if "{" $ cBody .or. "[" $ cBody
      hPost := { "body" => cBody }
   else
      hPost := HIX_ParseQuery( cBody )
   endif
   if cVar == nil; return hPost; endif
   if hb_hHasKey( hPost, cVar ); return hPost[ cVar ]; endif
return ""

FUNCTION UHeader( cVar )
   // Headers not yet parsed at this level (extend in future)
   HB_SYMBOL_UNUSED( cVar )
return ""

FUNCTION UCookie( cName )
   HB_SYMBOL_UNUSED( cName )
return ""

FUNCTION USetCookie( cKey, cVal, nSecs, cPath, cDomain, lHttps, lOnlyHttp, cSameSite )
   HB_SYMBOL_UNUSED( cKey ); HB_SYMBOL_UNUSED( cVal )
   HB_SYMBOL_UNUSED( nSecs ); HB_SYMBOL_UNUSED( cPath )
   HB_SYMBOL_UNUSED( cDomain ); HB_SYMBOL_UNUSED( lHttps )
   HB_SYMBOL_UNUSED( lOnlyHttp ); HB_SYMBOL_UNUSED( cSameSite )
return nil

FUNCTION UServer( cKey )
   local hInfo := { ;
      "SERVER_SOFTWARE" => "HbBuilder/HIX", ;
      "REQUEST_METHOD"  => UI_HIX_METHOD(), ;
      "REQUEST_URI"     => UI_HIX_PATH(), ;
      "QUERY_STRING"    => UI_HIX_QUERY() ;
   }
   if cKey == nil; return hInfo; endif
   if hb_hHasKey( hInfo, cKey ); return hInfo[ cKey ]; endif
return ""

FUNCTION UGetServerInfo()
return UServer()

FUNCTION UGetIp()
return UI_HIX_IP()

//─── Output functions ────────────────────────────────────────────────────────

FUNCTION UWrite( ... )
   local i
   for i := 1 to PCount()
      UI_HIX_WRITE( hb_CStr( hb_pValue(i) ) )
   next
return nil

FUNCTION USetStatusCode( nCode )
   UI_HIX_SETSTATUS( nCode )
return nil

FUNCTION USetErrorStatus( nStatus, cPage, cAjax )
   HB_SYMBOL_UNUSED( cPage ); HB_SYMBOL_UNUSED( cAjax )
   UI_HIX_SETSTATUS( nStatus )
return nil

FUNCTION UAddHeader( cType, uValue )
   HB_SYMBOL_UNUSED( cType ); HB_SYMBOL_UNUSED( uValue )
   // Future: accumulate response headers in HixCtx
return nil

FUNCTION UView( cTpl, ... )
   local aArgs := hb_aParams()
   local cRoot, cFile, cHtml
   // cRoot is passed as first arg via the static set by TWebServer
   cRoot := HIX_GetRoot()
   cFile := cRoot + "/" + cTpl
   if ! File( cFile )
      cFile := cTpl  // try absolute
   endif
   if ! File( cFile )
      UWrite( "<!-- UView: template not found: " + cTpl + " -->" )
      return nil
   endif
   cHtml := HIX_RenderTemplate( MemoRead( cFile ), aArgs )
   UWrite( cHtml )
return nil

//─── Encoding / helpers ──────────────────────────────────────────────────────

FUNCTION UHtmlEncode( c )
   c := StrTran( c, "&",  "&amp;"  )
   c := StrTran( c, "<",  "&lt;"   )
   c := StrTran( c, ">",  "&gt;"   )
   c := StrTran( c, '"',  "&quot;" )
return c

FUNCTION UUrlEncode( c )
   local i, n, cOut := "", cCh, nAsc
   for i := 1 to Len(c)
      cCh  := SubStr(c, i, 1)
      nAsc := Asc(cCh)
      if (nAsc >= 65 .and. nAsc <= 90)  .or. ;   // A-Z
         (nAsc >= 97 .and. nAsc <= 122) .or. ;   // a-z
         (nAsc >= 48 .and. nAsc <= 57)  .or. ;   // 0-9
         cCh $ "-_.~"
         cOut += cCh
      else
         cOut += "%" + hb_NumToHex( nAsc, 2 )
      endif
   next
return cOut

FUNCTION UUrlDecode( c )
   local i, cOut := "", cHex
   i := 1
   do while i <= Len(c)
      if SubStr(c,i,1) == "+"
         cOut += " "
         i++
      elseif SubStr(c,i,1) == "%" .and. i+2 <= Len(c)
         cHex := SubStr(c, i+1, 2)
         cOut += Chr( hb_HexToNum(cHex) )
         i += 3
      else
         cOut += SubStr(c,i,1)
         i++
      endif
   enddo
return cOut

FUNCTION Ulink( cText, cUrl )
return "<a href='" + cUrl + "'>" + cText + "</a>"

FUNCTION ULoadHtml( cFile )
   local cRoot := HIX_GetRoot()
   local cPath := cRoot + "/" + cFile
   if File( cPath )
      UWrite( MemoRead( cPath ) )
   endif
return nil

FUNCTION UExecuteHtml( cFile )
   if File( cFile )
      UWrite( MemoRead( cFile ) )
   endif
return nil

FUNCTION UExecutePrg( cFile )
   HIX_ExecPrg( cFile )
return nil

FUNCTION _d( ... )
   local i
   for i := 1 to PCount()
      hb_ToOutErr( hb_CStr( hb_pValue(i) ) + Chr(10) )
   next
return nil

FUNCTION _w( uVal )
return "<pre>" + UHtmlEncode( hb_CStr(uVal) ) + "</pre>"

//─── Internal helpers (used by TWebServer:Dispatch and UView) ────────────────

STATIC s_cHixRoot := "."

FUNCTION HIX_SetRoot( cRoot )
   s_cHixRoot := cRoot
return nil

FUNCTION HIX_GetRoot()
return s_cHixRoot

FUNCTION HIX_ServeStatic( cFilePath )
   local cExt := Lower( hb_FNameExt( cFilePath ) )
   local cMime
   local hMime := { ;
      ".html" => "text/html; charset=utf-8", ;
      ".htm"  => "text/html; charset=utf-8", ;
      ".css"  => "text/css", ;
      ".js"   => "application/javascript", ;
      ".json" => "application/json", ;
      ".png"  => "image/png", ;
      ".jpg"  => "image/jpeg", ;
      ".jpeg" => "image/jpeg", ;
      ".gif"  => "image/gif", ;
      ".svg"  => "image/svg+xml", ;
      ".ico"  => "image/x-icon", ;
      ".txt"  => "text/plain" ;
   }
   cMime := iif( hb_hHasKey(hMime, cExt), hMime[cExt], "application/octet-stream" )
   UI_HIX_SETCONTENTTYPE( cMime )
   UI_HIX_WRITE( MemoRead( cFilePath ) )
return nil

FUNCTION HIX_ExecPrg( cFile )
   local cCode, pHrb
   if ! File( cFile )
      UWrite( "<!-- HIX_ExecPrg: file not found: " + cFile + " -->" )
      return nil
   endif
   cCode := MemoRead( cFile )
   pHrb  := hb_compileStr( cCode, "-n", "-w", "-q" )
   if pHrb != nil
      hb_hrbDo( hb_hrbLoad( pHrb ) )
   else
      UWrite( "<!-- HIX_ExecPrg: compile error in: " + cFile + " -->" )
   endif
return nil
```

- [ ] **Step 2: Commit**

```bash
git add source/hix_runtime.prg
git commit -m "feat(webserver): add hix_runtime.prg — all U* HIX-compatible functions"
```

---

## Task 4: Create hix_template.prg — template engine

**Files:**
- Create: `source/hix_template.prg`

- [ ] **Step 1: Create the template engine**

Write the following to `source/hix_template.prg`:

```harbour
/*
 * hix_template.prg — HIX template engine
 *
 * Supports: @args, {{ expr }}, @foreach var IN array, @endforeach,
 *           @if expr, @else, @endif
 */

#include "hbbuilder.ch"

FUNCTION HIX_RenderTemplate( cTpl, aArgs )
   local aLines := hb_aTokens( cTpl, Chr(10) )
   local i, cLine, cOut := ""
   local hVars   := { => }   // template variable namespace
   local aArgNames := {}     // from @args line
   local lInForeach := .F.
   local cForeachVar, aForeachArr, nForeachIdx
   local aForeachLines := {}
   local lInIf := .F., lIfResult := .T., lInElse := .F.

   for i := 1 to Len( aLines )
      cLine := aLines[i]

      // ── @args ──────────────────────────────────────────────────────────────
      if Left( LTrim(cLine), 5 ) == "@args"
         aArgNames := hb_aTokens( AllTrim( SubStr(LTrim(cLine),6) ), "," )
         local j
         for j := 1 to Len( aArgNames )
            aArgNames[j] := AllTrim( aArgNames[j] )
            if j <= Len( aArgs )
               hVars[ aArgNames[j] ] := aArgs[j]
            endif
         next
         loop
      endif

      // ── @foreach ───────────────────────────────────────────────────────────
      if Left( LTrim(cLine), 8 ) == "@foreach"
         local cSpec := AllTrim( SubStr(LTrim(cLine),9) )
         // "var IN array"
         local nIn := At( " IN ", Upper(cSpec) )
         if nIn > 0
            cForeachVar  := AllTrim( Left(cSpec, nIn-1) )
            local cArrName := AllTrim( SubStr(cSpec, nIn+4) )
            aForeachArr  := hb_hGetDef( hVars, cArrName, {} )
            lInForeach   := .T.
            nForeachIdx  := 0
            aForeachLines := {}
         endif
         loop
      endif

      if lInForeach
         if Left( LTrim(cLine), 11 ) == "@endforeach"
            // Process accumulated lines for each array element
            local k
            for k := 1 to Len( aForeachArr )
               hVars[ cForeachVar ] := aForeachArr[k]
               local m
               for m := 1 to Len( aForeachLines )
                  cOut += HIX_ProcessLine( aForeachLines[m], hVars )
               next
            next
            lInForeach := .F.
            aForeachLines := {}
         else
            AAdd( aForeachLines, cLine )
         endif
         loop
      endif

      // ── @if / @else / @endif ───────────────────────────────────────────────
      if Left( LTrim(cLine), 3 ) == "@if"
         local cExpr := AllTrim( SubStr(LTrim(cLine),4) )
         lInIf     := .T.
         lInElse   := .F.
         lIfResult := HIX_EvalExpr( cExpr, hVars )
         loop
      endif
      if lInIf .and. LTrim(cLine) == "@else"
         lInElse   := .T.
         lIfResult := !lIfResult
         loop
      endif
      if lInIf .and. LTrim(cLine) == "@endif"
         lInIf := .F.; lIfResult := .T.; lInElse := .F.
         loop
      endif
      if lInIf .and. !lIfResult
         loop
      endif

      // ── Normal line ────────────────────────────────────────────────────────
      cOut += HIX_ProcessLine( cLine, hVars ) + Chr(10)

   next

return cOut

//─── Process one line: replace {{ expr }} with evaluated result ───────────────

FUNCTION HIX_ProcessLine( cLine, hVars )
   local cOut := "", nStart, nEnd, cExpr, cVal
   do while .T.
      nStart := At( "{{", cLine )
      if nStart == 0; EXIT; endif
      nEnd := At( "}}", cLine )
      if nEnd == 0; EXIT; endif
      cOut  += Left( cLine, nStart-1 )
      cExpr  := AllTrim( SubStr( cLine, nStart+2, nEnd-nStart-2 ) )
      cVal   := hb_CStr( HIX_EvalExpr( cExpr, hVars ) )
      cOut  += cVal
      cLine  := SubStr( cLine, nEnd+2 )
   enddo
   cOut += cLine
return cOut

//─── Evaluate a Harbour expression in the context of template variables ───────

FUNCTION HIX_EvalExpr( cExpr, hVars )
   local cKey, uVal
   // Fast path: plain variable name lookup
   if hb_hHasKey( hVars, cExpr )
      return hVars[ cExpr ]
   endif
   // Array element: var[n]
   if "[" $ cExpr
      local nBr := At("[", cExpr)
      cKey := Left(cExpr, nBr-1)
      local nIdx := Val( SubStr(cExpr, nBr+1) )
      if hb_hHasKey(hVars, cKey) .and. ValType(hVars[cKey]) == "A" .and. nIdx >= 1
         return hVars[cKey][nIdx]
      endif
   endif
   // Hash key: var["key"] or var['key']
   // Object field: var:field
   // Harbour built-in functions: time(), date(), etc.
   // For safety use hb_macroBlock
   local bExpr := hb_macroBlock( "{||" + cExpr + "}" )
   if bExpr != nil
      // Inject template vars as locals is not possible directly;
      // fall back to evaluating with macros that reference hVars.
      // Inject each variable using PRIVATE (simplest approach).
      local cPub := ""
      hb_hEval( hVars, { |k,v| __mvPrivate(k); __mvPut(k,v) } )
      return Eval( bExpr )
   endif
return ""
```

- [ ] **Step 2: Commit**

```bash
git add source/hix_template.prg
git commit -m "feat(webserver): add hix_template.prg — HIX template engine"
```

---

## Task 5: Update build_mac.sh — compile new files

**Files:**
- Modify: `build_mac.sh`

- [ ] **Step 1: Add compilation of cocoa_webserver.m after cocoa_inspector block**

After the block that compiles `cocoa_inspector.m` (around line 130–138), add:

```bash
if needs_rebuild "$PROJDIR/source/backends/cocoa/cocoa_webserver.m" cocoa_webserver.o; then
   echo "[3d/4] Compiling cocoa_webserver.m..."
   clang -c -O2 -mmacosx-version-min=10.15 -fobjc-arc \
      -I"$HBINC" \
      "$PROJDIR/source/backends/cocoa/cocoa_webserver.m" -o cocoa_webserver.o
   NEED_LINK=1
else
   echo "[3d/4] cocoa_webserver.o — up to date"
fi
```

- [ ] **Step 2: Add compilation of hix_runtime.prg and hix_template.prg**

After the `cocoa_webserver.m` block, add:

```bash
if needs_rebuild "$PROJDIR/source/hix_runtime.prg" hix_runtime.o || \
   needs_rebuild "$PROJDIR/include/hbbuilder.ch" hix_runtime.o; then
   echo "[3e/4] Compiling hix_runtime.prg..."
   "$HBBIN/harbour" "$PROJDIR/source/hix_runtime.prg" -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -I"$PROJDIR/source/core" \
      -ohix_runtime.c
   clang -c -O2 -mmacosx-version-min=10.15 -Wno-unused-value \
      -I"$HBINC" hix_runtime.c -o hix_runtime.o
   NEED_LINK=1
else
   echo "[3e/4] hix_runtime.o — up to date"
fi

if needs_rebuild "$PROJDIR/source/hix_template.prg" hix_template.o || \
   needs_rebuild "$PROJDIR/include/hbbuilder.ch" hix_template.o; then
   echo "[3f/4] Compiling hix_template.prg..."
   "$HBBIN/harbour" "$PROJDIR/source/hix_template.prg" -n -w -q \
      -I"$HBINC" \
      -I"$PROJDIR/include" \
      -I"$PROJDIR/source/core" \
      -ohix_template.c
   clang -c -O2 -mmacosx-version-min=10.15 -Wno-unused-value \
      -I"$HBINC" hix_template.c -o hix_template.o
   NEED_LINK=1
else
   echo "[3f/4] hix_template.o — up to date"
fi
```

- [ ] **Step 3: Add the new .o files to the link command**

Find the `clang++ -o ${PROG}` link command (around line 178) and add the new objects after `stddlgs_mac.o`:

```bash
   hix_runtime.o hix_template.o cocoa_webserver.o \
```

- [ ] **Step 4: Run a full build and verify it succeeds**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1
```

Expected output ends with:
```
-- HbBuilder built successfully (with Scintilla editor) --
Run with: open .../bin/HbBuilder.app
```

Fix any compile errors before proceeding.

- [ ] **Step 5: Copy binary and run a quick smoke test**

```bash
cp /Users/usuario/HarbourBuilder/source/HbBuilder /Users/usuario/HarbourBuilder/bin/HbBuilder
cp /Users/usuario/HarbourBuilder/source/HbBuilder /Users/usuario/HarbourBuilder/bin/HbBuilder.app/Contents/MacOS/HbBuilder
open /Users/usuario/HarbourBuilder/bin/HbBuilder.app &
```

Expected: HbBuilder opens normally (no crash = HTTP server code doesn't break startup).

- [ ] **Step 6: Commit**

```bash
git add build_mac.sh
git commit -m "build: compile cocoa_webserver.m + hix_runtime/template in build_mac.sh"
```

---

## Task 6: Update user-project build pipeline in hbbuilder_macos.prg

User projects built from within HbBuilder also need hix_runtime and hix_template. The pipeline in `source/hbbuilder_macos.prg` copies framework files and compiles them separately.

**Files:**
- Modify: `source/hbbuilder_macos.prg`

- [ ] **Step 1: Copy hix files in the bundle step (around line 3072)**

Find the block that copies `classes.prg`, `hbbuilder.ch`, etc. to `cBuildDir`. After the existing copies, add:

```harbour
   MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/hix_runtime.prg " + cBuildDir + "/ 2>/dev/null || " + ;
                  "cp " + cProjDir + "/source/hix_runtime.prg " + cBuildDir + "/" )
   MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/hix_template.prg " + cBuildDir + "/ 2>/dev/null || " + ;
                  "cp " + cProjDir + "/source/hix_template.prg " + cBuildDir + "/" )
   MAC_ShellExec( "cp " + HB_DirBase() + "../Resources/backends/cocoa/cocoa_webserver.m " + cBuildDir + "/ 2>/dev/null || " + ;
                  "cp " + cProjDir + "/source/backends/cocoa/cocoa_webserver.m " + cBuildDir + "/" )
```

- [ ] **Step 2: Add hix_runtime and hix_template compilation in Step 4**

After Step 4 (classes.prg compilation, around line 3120), add:

```harbour
   // Step 4b: Compile hix_runtime.prg
   if ! lError
      cCmd := cHbBin + "/harbour " + cBuildDir + "/hix_runtime.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/hix_runtime.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED (hix_runtime):" + Chr(10) + cOutput + Chr(10)
      endif
   endif

   // Step 4c: Compile hix_template.prg
   if ! lError
      cCmd := cHbBin + "/harbour " + cBuildDir + "/hix_template.prg -n -w -q" + ;
              " -I" + cHbInc + " -I" + cBuildDir + ;
              " -o" + cBuildDir + "/hix_template.c 2>&1"
      cOutput := MAC_ShellExec( cCmd )
      if ! Empty( cOutput ) .and. "error" $ Lower( cOutput )
         cLog += "    FAILED (hix_template):" + Chr(10) + cOutput + Chr(10)
      endif
   endif
```

- [ ] **Step 3: Compile the new .c files in Step 5**

In the C compilation step (around line 3136), add after the `classes.c` compilation:

```harbour
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/hix_runtime.c -o " + cBuildDir + "/hix_runtime.o 2>&1"
      MAC_ShellExec( cCmd )
      cCmd := "clang -c -O2 -Wno-unused-value -I" + cHbInc + ;
              " " + cBuildDir + "/hix_template.c -o " + cBuildDir + "/hix_template.o 2>&1"
      MAC_ShellExec( cCmd )
```

- [ ] **Step 4: Compile cocoa_webserver.m in Step 6**

In the Cocoa backend compilation step (around line 3160), add after `cocoa_core.m`:

```harbour
      if File( cBuildDir + "/cocoa_webserver.m" )
         cCmd := "clang -c -O2 -fobjc-arc -I" + cHbInc + ;
                 " " + cBuildDir + "/cocoa_webserver.m" + ;
                 " -o " + cBuildDir + "/cocoa_webserver.o 2>&1"
         MAC_ShellExec( cCmd )
      endif
```

- [ ] **Step 5: Add new .o files to the linker command in Step 7**

Find the link command (around line 3188). Add the new objects after `classes.o`:

```harbour
              " " + iif(File(cBuildDir+"/hix_runtime.o"),  " "+cBuildDir+"/hix_runtime.o",  "") + ;
              " " + iif(File(cBuildDir+"/hix_template.o"), " "+cBuildDir+"/hix_template.o", "") + ;
              " " + iif(File(cBuildDir+"/cocoa_webserver.o"), " "+cBuildDir+"/cocoa_webserver.o", "") + ;
```

- [ ] **Step 6: Copy hix files to the app bundle Resources/ in build_mac.sh**

In `build_mac.sh`, in the `[5/5] Create .app bundle` section, after the line that copies `classes.prg`, add:

```bash
cp "$PROJDIR/source/hix_runtime.prg"  "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/source/hix_template.prg" "$APP/Contents/Resources/" 2>/dev/null
cp "$PROJDIR/source/backends/cocoa/cocoa_webserver.m" "$APP/Contents/Resources/backends/cocoa/" 2>/dev/null
```

- [ ] **Step 7: Build, copy, and verify no regression**

```bash
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1 | tail -10
cp source/HbBuilder bin/HbBuilder
cp source/HbBuilder bin/HbBuilder.app/Contents/MacOS/HbBuilder
```

Expected: successful build.

- [ ] **Step 8: Commit**

```bash
git add build_mac.sh source/hbbuilder_macos.prg
git commit -m "build: include hix_runtime/template/webserver in user-project build pipeline"
```

---

## Task 7: Sample 1 — webserver (basic HTTP demo)

**Files:**
- Create: `samples/projects/webserver/Project1.prg`
- Create: `samples/projects/webserver/Form1.prg`
- Create: `samples/projects/webserver/www/index.html`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p /Users/usuario/HarbourBuilder/samples/projects/webserver/www
```

- [ ] **Step 2: Create Project1.prg**

```harbour
#include "hbbuilder.ch"

REQUEST HB_GT_NUL_DEFAULT
REQUEST DBFCDX, DBFNTX, DBFFPT

PROCEDURE Main()
   UI_AppInit()
   Form1()
   UI_AppRun()
RETURN
```

- [ ] **Step 3: Create Form1.prg**

```harbour
#include "hbbuilder.ch"

static oServer

PROCEDURE Form1()
   local oForm, oStart, oStop, oLabel, oView

   oForm  := TForm():New( nil, "WebServer Demo", 100, 100, 640, 480 )
   oLabel := TLabel():New( oForm, "Server stopped. Port 8080.", 10, 10, 400, 30 )
   oView  := TWebView():New( oForm, 10, 50, 610, 360 )

   oStart := TButton():New( oForm, "Start Server", 10, 420, 120, 30 )
   oStart:bOnClick := {||
      oServer := TWebServer():New()
      oServer:nPort := 8080
      oServer:cRoot := hb_DirBase() + "www"
      oServer:lTrace := .T.

      // GET /api/time → JSON
      oServer:AddRoute( "GET", "/api/time", {||
         UAddHeader( "Content-Type", "application/json" )
         UWrite( '{"time":"' + Time() + '","date":"' + DToC(Date()) + '"}' )
      })

      // POST /api/echo → echoes POST body as JSON
      oServer:AddRoute( "POST", "/api/echo", {||
         local cBody := UPost("body")
         if Empty(cBody); cBody := hb_jsonEncode( UPost() ); endif
         UWrite( '{"echo":' + hb_jsonEncode(cBody) + '}' )
      })

      oServer:bOnStart := {|| oLabel:SetText("Running at http://localhost:8080") }
      oServer:Start()
      oView:Navigate("http://localhost:8080")
   }

   oStop := TButton():New( oForm, "Stop Server", 140, 420, 120, 30 )
   oStop:bOnClick := {||
      if oServer != nil
         oServer:Stop()
         oLabel:SetText("Server stopped.")
         oServer := nil
      endif
   }

   oForm:Show()
RETURN
```

- [ ] **Step 4: Create www/index.html**

```html
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>HbBuilder WebServer Demo</title>
<style>
  body { font-family: system-ui; padding: 2em; background: #f5f5f7; }
  h1   { color: #1d1d1f; }
  button { padding: .5em 1.2em; margin: .4em; border-radius: 8px;
           border: none; background: #0071e3; color: #fff; cursor: pointer; }
  pre  { background: #1c1c1e; color: #f2f2f2; padding: 1em;
         border-radius: 8px; min-height: 3em; }
</style>
</head>
<body>
<h1>HbBuilder / HIX WebServer Demo</h1>
<p>Static files ✓ &nbsp; REST API ✓ &nbsp; HIX runtime ✓</p>

<button onclick="fetchTime()">GET /api/time</button>
<button onclick="echoTest()">POST /api/echo</button>
<pre id="out">Awaiting request…</pre>

<script>
async function fetchTime() {
  const r = await fetch('/api/time');
  document.getElementById('out').textContent = JSON.stringify(await r.json(), null, 2);
}
async function echoTest() {
  const r = await fetch('/api/echo', {
    method: 'POST',
    headers: {'Content-Type':'application/x-www-form-urlencoded'},
    body: 'body=Hello+from+HbBuilder'
  });
  document.getElementById('out').textContent = JSON.stringify(await r.json(), null, 2);
}
</script>
</body>
</html>
```

- [ ] **Step 5: Verify the sample builds and runs**

Open HbBuilder, open `samples/projects/webserver/`, press Run. Click "Start Server". In the embedded TWebView verify:
- `http://localhost:8080` loads the index.html page
- Clicking "GET /api/time" shows JSON with current time
- Clicking "POST /api/echo" shows the echoed body

Open Terminal and also verify with curl:
```bash
curl http://localhost:8080/api/time
# Expected: {"time":"HH:MM:SS","date":"MM/DD/YYYY"}

curl -X POST -d "body=hello" http://localhost:8080/api/echo
# Expected: {"echo":"hello"}
```

- [ ] **Step 6: Commit**

```bash
git add samples/projects/webserver/
git commit -m "feat(samples): add webserver demo — basic TWebServer with REST routes"
```

---

## Task 8: Sample 2 — hix_app (HIX MVC compatibility demo)

**Files:**
- Create: `samples/projects/hix_app/Project1.prg`
- Create: `samples/projects/hix_app/Form1.prg`
- Create: `samples/projects/hix_app/controllers/home.prg`
- Create: `samples/projects/hix_app/controllers/api.prg`
- Create: `samples/projects/hix_app/views/home.html`
- Create: `samples/projects/hix_app/www/style.css`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p /Users/usuario/HarbourBuilder/samples/projects/hix_app/controllers
mkdir -p /Users/usuario/HarbourBuilder/samples/projects/hix_app/views
mkdir -p /Users/usuario/HarbourBuilder/samples/projects/hix_app/www
```

- [ ] **Step 2: Create Project1.prg**

```harbour
#include "hbbuilder.ch"

REQUEST HB_GT_NUL_DEFAULT
REQUEST DBFCDX, DBFNTX, DBFFPT

PROCEDURE Main()
   UI_AppInit()
   Form1()
   UI_AppRun()
RETURN
```

- [ ] **Step 3: Create Form1.prg**

```harbour
#include "hbbuilder.ch"

static oServer

PROCEDURE Form1()
   local oForm, oView, oStatus

   oForm   := TForm():New( nil, "HIX App — MVC Demo", 100, 100, 800, 600 )
   oStatus := TLabel():New( oForm, "Starting server…", 10, 10, 600, 24 )
   oView   := TWebView():New( oForm, 10, 40, 775, 510 )

   oForm:bOnCreate := {||
      oServer := TWebServer():New()
      oServer:nPort := 8181
      oServer:cRoot := hb_DirBase()
      oServer:lTrace := .T.

      // HIX-style routes: map URL to controller file
      oServer:AddRoute( "GET",  "/",         "controllers/home.prg"  )
      oServer:AddRoute( "GET",  "/home",     "controllers/home.prg"  )
      oServer:AddRoute( "GET",  "/api/data", "controllers/api.prg"   )

      oServer:bOnStart := {||
         oStatus:SetText( "HIX App running at http://localhost:8181" )
         oView:Navigate( "http://localhost:8181/" )
      }
      oServer:Start()
   }

   oForm:bOnClose := {||
      if oServer != nil; oServer:Stop(); oServer := nil; endif
   }

   oForm:Show()
RETURN
```

- [ ] **Step 4: Create controllers/home.prg — identical to HIX example1.prg**

```harbour
// controllers/home.prg
// This is the SAME code as example1.prg from https://github.com/carles9000/hix
// It runs unmodified inside HarbourBuilder's TWebServer.

FUNCTION main()

   local aData := {;
      { "Harbour", "Open-source language derived from Clipper, focused on business applications.", .T. },;
      { "PHP",     "Server-side scripting language designed for web development.",                 .F. },;
      { "Python",  "High-level language with clean syntax, used in data science and backend.",     .F. },;
      { "Rust",    "Systems language focused on safety, performance, and concurrency.",            .F. },;
      { "Kotlin",  "Modern JVM language combining functional and OOP with concise syntax.",        .F. };
   }
   local cTicket := "ABC-" + LTrim( Str( hb_RandomInt(100000, 999999) ) )

RETURN UView( "views/home.html", aData, cTicket )
```

- [ ] **Step 5: Create controllers/api.prg**

```harbour
// controllers/api.prg — JSON API endpoint

FUNCTION main()
   local hData := { ;
      "server"    => "HbBuilder/HIX", ;
      "version"   => "1.0", ;
      "time"      => Time(), ;
      "date"      => DToC(Date()), ;
      "languages" => { "Harbour", "PHP", "Python", "Rust", "Kotlin" } ;
   }
   UAddHeader( "Content-Type", "application/json" )
   UWrite( hb_jsonEncode( hData ) )
RETURN nil
```

- [ ] **Step 6: Create views/home.html — HIX template**

```html
@args mydata, cId

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>HIX App — HbBuilder</title>
<link rel="stylesheet" href="/www/style.css">
</head>
<body>

<header>
  <h1>HIX App running inside HbBuilder</h1>
  <p class="ticket"><strong>Ticket:</strong> {{ cId }}</p>
</header>

<main>
  <h2>Programming Languages</h2>
  <ul class="lang-list">

  @foreach oItem IN myData
    <li class="{{ iif(oItem[3], "featured", "normal") }}">
      <strong>{{ oItem[1] }}</strong> — {{ oItem[2] }}
    </li>
  @endforeach

  </ul>

  <p class="time">Server time: <code>{{ time() }}</code></p>
  <p><a href="/api/data">View JSON API →</a></p>
</main>

</body>
</html>
```

- [ ] **Step 7: Create www/style.css**

```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, sans-serif; background: #f5f5f7; color: #1d1d1f; padding: 2em; }
header { background: #0071e3; color: #fff; padding: 1.5em 2em; border-radius: 12px; margin-bottom: 2em; }
h1 { font-size: 1.4em; }
.ticket { opacity: .8; margin-top: .4em; font-size: .9em; }
h2 { margin-bottom: 1em; color: #333; }
.lang-list { list-style: none; display: grid; gap: .6em; }
.lang-list li { background: #fff; padding: 1em 1.4em; border-radius: 8px;
                box-shadow: 0 1px 4px rgba(0,0,0,.08); }
.lang-list li.featured { border-left: 4px solid #0071e3; }
.time { margin-top: 2em; color: #666; font-size: .9em; }
a { color: #0071e3; text-decoration: none; }
```

- [ ] **Step 8: Verify the sample**

Open HbBuilder, open `samples/projects/hix_app/`, press Run. Verify:
- TWebView loads `http://localhost:8181/` showing the HIX template rendered with the language list
- Ticket number changes on each reload (random)
- Clicking "View JSON API →" loads JSON in the WebView
- In Terminal: `curl http://localhost:8181/` returns valid HTML with language names
- In Terminal: `curl http://localhost:8181/api/data` returns JSON

- [ ] **Step 9: Commit**

```bash
git add samples/projects/hix_app/
git commit -m "feat(samples): add hix_app demo — 100% HIX-compatible MVC with UView templates"
```

---

## Task 9: Final integration test and cleanup

- [ ] **Step 1: Full build from clean state**

```bash
cd /Users/usuario/HarbourBuilder/source
rm -f hix_runtime.o hix_template.o cocoa_webserver.o hix_runtime.c hix_template.c
cd /Users/usuario/HarbourBuilder && ./build_mac.sh 2>&1
```

Expected: all files compile cleanly.

- [ ] **Step 2: Copy binary to bin/**

```bash
cp source/HbBuilder bin/HbBuilder
cp source/HbBuilder bin/HbBuilder.app/Contents/MacOS/HbBuilder
cp source/backends/cocoa/cocoa_webserver.m bin/HbBuilder.app/Contents/Resources/backends/cocoa/
cp source/hix_runtime.prg  bin/HbBuilder.app/Contents/Resources/
cp source/hix_template.prg bin/HbBuilder.app/Contents/Resources/
```

- [ ] **Step 3: Run both samples from HbBuilder and verify end-to-end**

1. Open Sample 1 (`webserver`): Start server → curl tests pass → Stop server
2. Open Sample 2 (`hix_app`): Page loads → template renders → `/api/data` returns JSON

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: TWebServer HIX runtime complete — HTTP server + U* functions + templates + 2 samples"
```
