#!/bin/bash
# HIX mainloop characterization: a single slow-drip client holds the
# synchronous request callback on the GTK main loop (the same loop that
# drives the app UI) until the slow-client deadline (eca1179) aborts it.
# Source-verified: deadline is an ABSOLUTE wall of 5s (time(NULL)+5 once
# before the read loop), on top of a 2s SO_RCVTIMEO per recv.
# Measures: baseline latency, concurrent-request latency during the drip,
# precise server close time, GTK heartbeat gap (= measured UI freeze),
# and recovery. No product changes.
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
cp "$REPO/tests/test_hix_mainloop_app.prg" "$REPO/tests/hix_hb_helper.c" "$REPO/source/core/classes.prg" "$BUILD/"
cp "$REPO/include/hbbuilder.ch" "$REPO/include/hbide.ch" "$BUILD/"
cd "$BUILD" || exit 1
for m in test_hix_mainloop_app classes; do
  "$HBIN/harbour" "$m.prg" -n -w -q -I"$HB/include" -I. -o"$m.c" || exit 1
  gcc -c -O2 -Wno-unused-value -I"$HB/include" "$m.c" -o "$m.o" || exit 1
done
gcc -c -O2 -I"$HB/include" $(pkg-config --cflags gtk+-3.0) hix_hb_helper.c -o hix_hb_helper.o || exit 1
gcc -o HixMainloopTest test_hix_mainloop_app.o classes.o hix_hb_helper.o "$REPO/source/gtk3_core.o" "$REPO/source/hbdb_real.o" "$REPO/source/hbbuilder_common.o" \
  -L"$HB/lib/linux/gcc" -L"$HB/lib" -Wl,--start-group \
  -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug \
  -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd \
  -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
  $(pkg-config --libs gtk+-3.0) $(pkg-config --libs webkit2gtk-4.1 2>/dev/null || pkg-config --libs webkit2gtk-4.0) \
  -lm -lpthread -ldl -lrt -lsqlite3 -lncurses || exit 1
echo "HixMainloopTest built: $(sha256sum HixMainloopTest)"

rm -f /tmp/hix_mainloop_out.txt /tmp/hix_mainloop_hb.txt
xvfb-run -a -s "-screen 0 800x600x24" env LD_LIBRARY_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu GDK_BACKEND=x11 WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 ./HixMainloopTest >app.log 2>&1 &
for i in $(seq 1 20); do [ -f /tmp/hix_mainloop_out.txt ] && break; sleep 1; done
[ -f /tmp/hix_mainloop_out.txt ] || { echo "HIXMAINLOOP FAIL: app did not start"; exit 1; }

python3 - <<'PY_EOF'
import socket, time, threading, urllib.request, sys
def drip(res):
    t0=time.time()
    try:
        s=socket.create_connection(('127.0.0.1',8091),timeout=10)
        s.settimeout(0.15)
        for i in range(25):
            try: s.sendall(b'X')
            except Exception as e:
                res['drip']=('send-fail-%s'%type(e).__name__, round(time.time()-t0,2)); return
            try:
                if s.recv(1, socket.MSG_PEEK) == b'':
                    res['drip']=('closed-detected', round(time.time()-t0,2)); return
            except socket.timeout: pass
            time.sleep(1.0)
        res['drip']=('still-open', round(time.time()-t0,2))
    except Exception as e:
        res['drip']=('connect-%s'%type(e).__name__, round(time.time()-t0,2))
def probe(res,key):
    t0=time.time()
    try:
        r=urllib.request.urlopen('http://127.0.0.1:8091/',timeout=25)
        res[key]=(r.status, round(time.time()-t0,3))
    except Exception as e:
        res[key]=(type(e).__name__, round(time.time()-t0,3))
res={}
probe(res,'baseline')
t=threading.Thread(target=drip,args=(res,)); t.start()
time.sleep(2.0); probe(res,'during-drip')
time.sleep(6.0); probe(res,'after-deadline')
t.join(timeout=30); probe(res,'recovery')
for k in ['baseline','drip','during-drip','after-deadline','recovery']:
    print('  hix-mainloop %-14s %s'%(k,res.get(k)))

ticks=[float(l) for l in open('/tmp/hix_mainloop_hb.txt') if l.strip()]
gaps=sorted(((ticks[i+1]-ticks[i], ticks[i]) for i in range(len(ticks)-1)), reverse=True)
for g,a in gaps[:3]:
    print('  hb-gap %.3fs starting at tick %.0f ms'%(g/1000.0, a))
maxgap=gaps[0][0]/1000.0 if gaps else 0
ok = (res.get('baseline',(0,99))[0]==200 and res['baseline'][1] < 2
      and res.get('during-drip',(0,0))[0]==200 and res['during-drip'][1] > 1.0
      and res.get('drip',('x',99))[0]=='closed-detected' and 3.0 < res['drip'][1] < 8.0
      and 1.5 < maxgap < 8.0
      and res.get('after-deadline',(0,99))[0]==200 and res['after-deadline'][1] < 2
      and res.get('recovery',(0,99))[0]==200 and res['recovery'][1] < 2)
print('  hb-ticks=%d max-gap=%.3fs'%(len(ticks),maxgap))
print('HIXMAINLOOP ' + ('PASS: absolute 5s wall deadline aborts the slow drip; mainloop freeze measured by GTK heartbeat; clean recovery'
      if ok else 'FAIL: see measurements above'))
sys.exit(0 if ok else 1)
PY_EOF
RC=$?
pkill -f HixMainloopTest 2>/dev/null
exit $RC
