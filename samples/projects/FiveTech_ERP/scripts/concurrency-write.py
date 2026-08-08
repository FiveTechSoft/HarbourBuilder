# concurrency-write.py — Estrés de ESCRITURA concurrente sobre el contrato web.
# N sesiones hacen login y cada una agrega/actualiza/elimina filas propias
# (prefijo ZZW<i>), sin pisarse. Al final se verifica integridad del dataset:
# mismo número de filas de partida y cero residuos ZZW.
# Uso: python scripts/concurrency-write.py [sesiones] [filas_por_sesion] [base]
import json, sys, threading, time, urllib.request

BASE = sys.argv[3] if len(sys.argv) > 3 else "http://127.0.0.1:2222"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10
K = int(sys.argv[2]) if len(sys.argv) > 2 else 3
KEY = "data.products"
results, lock = [], threading.Lock()

def req(path, body=None, cookie=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data)
    if body is not None:
        r.add_header("Content-Type", "application/json")
    if cookie:
        r.add_header("Cookie", cookie)
    with urllib.request.urlopen(r, timeout=60) as resp:
        sc = resp.headers.get("Set-Cookie")
        return json.loads(resp.read().decode()), (sc.split(";")[0] if sc else None)

def baseline():
    j, cookie = req("/api/login", {"user": "admin", "password": "1234"})
    j2, _ = req("/api/dataset?key=" + KEY, cookie=cookie)
    return len(j2["rows"]), cookie

def worker(i):
    t0 = time.time()
    try:
        j, cookie = req("/api/login", {"user": "admin", "password": "1234"})
        assert j.get("ok")
        ops = 0
        for k in range(K):
            code = f"ZZW{i:02d}{k}"
            j, _ = req("/api/dataset", {"key": KEY, "action": "add",
                 "row": {"code": code, "name": f"escritura {i}-{k}", "category": "Gift",
                         "price": 1.0, "active": True}}, cookie)
            assert j.get("ok"), "add: " + str(j.get("msg"))
            ops += 1
            j, _ = req("/api/dataset", {"key": KEY, "action": "update", "keyField": "code",
                 "keyValue": code, "row": {"code": code, "name": f"escritura {i}-{k} upd",
                 "category": "Gift", "price": 2.0, "active": True}}, cookie)
            assert j.get("ok"), "update: " + str(j.get("msg"))
            ops += 1
            j, _ = req("/api/dataset", {"key": KEY, "action": "delete",
                 "keyField": "code", "keyValue": code}, cookie)
            assert j.get("ok"), "delete: " + str(j.get("msg"))
            ops += 1
        with lock:
            results.append({"i": i, "ok": True, "ops": ops, "ms": round((time.time() - t0) * 1000)})
    except Exception as e:
        with lock:
            results.append({"i": i, "ok": False, "error": str(e)})

n0, _ = baseline()
t0 = time.time()
ths = [threading.Thread(target=worker, args=(i,)) for i in range(N)]
[t.start() for t in ths]
[t.join() for t in ths]
total = round((time.time() - t0) * 1000)
n1, _ = baseline()

oks = [r for r in results if r["ok"]]
errs = [r for r in results if not r["ok"]]
ops = sum(r.get("ops", 0) for r in oks)
print(f"sesiones: {N} x {K} filas · OK: {len(oks)} · errores: {len(errs)} · ops CRUD: {ops} · {total} ms")
print(f"integridad: filas antes={n0} despues={n1} -> {'OK' if n0 == n1 else 'CORRUPCION'}")
for e in errs[:5]:
    print(f"  ERR sesion {e['i']}: {e['error']}")
sys.exit(0 if (not errs and n0 == n1) else 1)
