#!/bin/bash
# HIX mainloop characterization: a single slow-drip client holds the
# synchronous request callback on the GTK main loop (the same loop that
# drives the app UI) until the slow-client deadline (eca1179) aborts it.
# Measures: baseline latency, latency of a concurrent request during the
# drip (= mainloop freeze), drip fate, and recovery. No product changes.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
BUILD=/tmp/hix_mainloop_build
source "$REPO/tests/harness_lib.sh"
rt_provenance

export PKG_CONFIG_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu/pkgconfig:/tmp/gtk-root/usr/share/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=/tmp/gtk-root
export LIBRARY_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu:/tmp/gtk-root/lib64
HB=/tmp/harbour-review; HBIN="$HB/bin/linux/gcc"; [ -x "$HBIN/harbour" ] || HBIN="$HB/bin"

rm -rf "$BUILD"; mkdir -p "$BUILD"
cp "$REPO/tests/test_hix_mainloop_app.prg" "$REPO/source/core/classes.prg" "$BUILD/"
cp "$REPO/include/hbbuilder.ch" "$REPO/include/hbide.ch" "$BUILD/"
cd "$BUILD" || exit 1
for m in test_hix_mainloop_app classes; do
  "$HBIN/harbour" "$m.prg" -n -w -q -I"$HB/include" -I. -o"$m.c" || exit 1
  gcc -c -O2 -Wno-unused-value -I"$HB/include" "$m.c" -o "$m.o" || exit 1
done
gcc -o HixMainloopTest test_hix_mainloop_app.o classes.o "$REPO/source/gtk3_core.o" "$REPO/source/hbdb_real.o" "$REPO/source/hbbuilder_common.o" \
  -L"$HB/lib/linux/gcc" -L"$HB/lib" -Wl,--start-group \
  -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug \
  -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd \
  -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
  $(pkg-config --libs gtk+-3.0) $(pkg-config --libs webkit2gtk-4.1 2>/dev/null || pkg-config --libs webkit2gtk-4.0) \
  -lm -lpthread -ldl -lrt -lsqlite3 -lncurses || exit 1
echo "HixMainloopTest built: $(sha256sum HixMainloopTest)"

rm -f /tmp/hix_mainloop_out.txt
xvfb-run -a -s "-screen 0 800x600x24" env LD_LIBRARY_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu GDK_BACKEND=x11 WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 ./HixMainloopTest >app.log 2>&1 &
for i in $(seq 1 20); do [ -f /tmp/hix_mainloop_out.txt ] && break; sleep 1; done
[ -f /tmp/hix_mainloop_out.txt ] || { echo "HIXMAINLOOP FAIL: app did not start"; exit 1; }

python3 - <<'PY'
import socket, time, threading, urllib.request, sys
def drip(res):
    t0=time.time()
    try:
        s=socket.create_connection(('127.0.0.1',8091),timeout=10)
        for i in range(20):
            s.sendall(b'X'); time.sleep(1.2)
        res['drip']=('still-open', time.time()-t0)
    except Exception as e:
        res['drip']=('closed-%s'%type(e).__name__, time.time()-t0)
def probe(res,key):
    t0=time.time()
    try:
        r=urllib.request.urlopen('http://127.0.0.1:8091/',timeout=25)
        res[key]=(r.status, time.time()-t0)
    except Exception as e:
        res[key]=(type(e).__name__, time.time()-t0)
res={}
probe(res,'baseline')
t=threading.Thread(target=drip,args=(res,)); t.start()
time.sleep(2.0); probe(res,'during-drip')
time.sleep(6.0); probe(res,'after-deadline')
t.join(timeout=30); probe(res,'recovery')
for k in ['baseline','drip','during-drip','after-deadline','recovery']:
    print('  hix-mainloop %-14s %s'%(k,res.get(k)))
ok = (res.get('baseline',(0,99))[0]==200 and res['baseline'][1] < 2
      and res.get('during-drip',(0,0))[0]==200 and res['during-drip'][1] > 1.0
      and res.get('drip',('x',0))[0].startswith('closed')
      and res.get('after-deadline',(0,99))[0]==200 and res['after-deadline'][1] < 2
      and res.get('recovery',(0,99))[0]==200 and res['recovery'][1] < 2)
print('HIXMAINLOOP ' + ('PASS: slow client freezes the shared mainloop until the deadline, then clean recovery'
      if ok else 'FAIL: unexpected behavior, see measurements above'))
sys.exit(0 if ok else 1)
PY
RC=$?
pkill -f HixMainloopTest 2>/dev/null
exit $RC
