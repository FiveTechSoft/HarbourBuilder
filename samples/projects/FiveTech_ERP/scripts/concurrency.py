# concurrency.py — Evidencia multi-sesión de la rama 100% web
# N sesiones simultáneas (cada una con su cookie DWSESS propia) hacen
# login + contexto + dataset, como lo harían N navegadores reales.
# Uso: python scripts/concurrency.py [sesiones] [base]
import json, sys, threading, time, urllib.request

BASE = sys.argv[2] if len(sys.argv) > 2 else "http://127.0.0.1:2222"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10
results = []
lock = threading.Lock()

def req(path, body=None, cookie=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data)
    if body is not None:
        r.add_header("Content-Type", "application/json")
    if cookie:
        r.add_header("Cookie", cookie)
    with urllib.request.urlopen(r, timeout=30) as resp:
        sc = resp.headers.get("Set-Cookie")
        return json.loads(resp.read().decode()), (sc.split(";")[0] if sc else None)

def worker(i):
    t0 = time.time()
    try:
        j, cookie = req("/api/login", {"user": "admin", "password": "1234"})
        assert j.get("ok"), j.get("msg")
        t_login = time.time() - t0
        t1 = time.time()
        j, _ = req("/api/context", cookie=cookie)
        assert j.get("ok"), j.get("msg")
        j, _ = req("/api/meta?key=modules", cookie=cookie)
        assert j.get("ok"), j.get("msg")
        j, _ = req("/api/dataset?key=data.products", cookie=cookie)
        assert j.get("ok"), j.get("msg")
        rows = len(j.get("rows", []))
        t_data = time.time() - t1
        with lock:
            results.append({"i": i, "ok": True, "login_ms": round(t_login * 1000),
                            "data_ms": round(t_data * 1000), "rows": rows})
    except Exception as e:
        with lock:
            results.append({"i": i, "ok": False, "error": str(e)})

t0 = time.time()
threads = [threading.Thread(target=worker, args=(i,)) for i in range(N)]
[t.start() for t in threads]
[t.join() for t in threads]
total = round((time.time() - t0) * 1000)

oks = [r for r in results if r["ok"]]
errs = [r for r in results if not r["ok"]]
print(f"sesiones: {N} · OK: {len(oks)} · errores: {len(errs)} · total: {total} ms")
if oks:
    lg = sorted(r["login_ms"] for r in oks)
    dt = sorted(r["data_ms"] for r in oks)
    print(f"login  min/med/max: {lg[0]}/{lg[len(lg)//2]}/{lg[-1]} ms")
    print(f"datos  min/med/max: {dt[0]}/{dt[len(dt)//2]}/{dt[-1]} ms (context+modules+dataset)")
for e in errs[:5]:
    print(f"  ERR sesion {e['i']}: {e['error']}")
sys.exit(0 if not errs else 1)
