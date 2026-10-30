#!/bin/bash
# H8 driver: builds the runtime selection test app against the current
# gtk3_core.o + classes.prg and runs it under Xvfb. Verifies real GTK widget
# selection state, not pixels. H8 FAIL lines in /tmp/h8_result.txt = RED.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
BUILD=/tmp/h8_build
RESULT=/tmp/h8_result.txt
source "$REPO/tests/harness_lib.sh"
rt_provenance

export PKG_CONFIG_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu/pkgconfig:/tmp/gtk-root/usr/share/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=/tmp/gtk-root
export LIBRARY_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu:/tmp/gtk-root/lib64
HB=/tmp/harbour-review
HBIN="$HB/bin/linux/gcc"; [ -x "$HBIN/harbour" ] || HBIN="$HB/bin"

rm -rf "$BUILD"; mkdir -p "$BUILD"; rm -f "$RESULT"
cp "${H8_PRG:-$REPO/tests/test_h8_select.prg}" "$BUILD/test_h8_select.prg"
cp "$REPO/tests/h8_helper.c" "$BUILD/"
cp "$REPO/source/core/classes.prg" "$BUILD/"
cp "$REPO/include/hbbuilder.ch" "$REPO/include/hbide.ch" "$BUILD/"

cd "$BUILD" || exit 1
for m in test_h8_select classes; do
  "$HBIN/harbour" "$m.prg" -n -w -q -I"$HB/include" -I. -o"$m.c" || { echo "H8 FAIL: harbour compile $m"; exit 1; }
  gcc -c -O2 -Wno-unused-value -I"$HB/include" "$m.c" -o "$m.o" || { echo "H8 FAIL: gcc $m"; exit 1; }
done
gcc -c -O2 -I"$HB/include" $(pkg-config --cflags gtk+-3.0) h8_helper.c -o h8_helper.o || { echo "H8 FAIL: gcc h8_helper"; exit 1; }
gcc -o H8Test test_h8_select.o classes.o h8_helper.o "$REPO/source/gtk3_core.o" "$REPO/source/hbdb_real.o" "$REPO/source/hbbuilder_common.o" \
  -L"$HB/lib/linux/gcc" -L"$HB/lib" -Wl,--start-group \
  -lhbvm -lhbrtl -lhbcommon -lhbcpage -lhblang -lhbmacro -lhbpp -lhbrdd -lhbcplr -lhbdebug \
  -lhbct -lhbextern -lrddntx -lrddnsx -lrddcdx -lrddfpt -lhbhsx -lhbsix -lhbusrrdd \
  -lhbsqlit3 -lsddsqlt3 -lrddsql -lgttrm -lhbpcre -Wl,--end-group \
  $(pkg-config --libs gtk+-3.0) $(pkg-config --libs webkit2gtk-4.1 2>/dev/null || pkg-config --libs webkit2gtk-4.0) \
  -lm -lpthread -ldl -lrt -lsqlite3 -lncurses || { echo "H8 FAIL: link"; exit 1; }
echo "H8Test built: $(sha256sum H8Test)"

xvfb-run -a -s "-screen 0 1280x800x24" env LD_LIBRARY_PATH=/tmp/gtk-root/usr/lib/x86_64-linux-gnu GDK_BACKEND=x11 WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 ./H8Test &
APP=$!
for i in $(seq 1 30); do [ -f "$RESULT" ] && break; sleep 1; done
kill "$APP" 2>/dev/null; wait "$APP" 2>/dev/null

if [ ! -f "$RESULT" ]; then echo "H8 FAIL: no result file (app did not reach assertions)"; exit 1; fi
cat "$RESULT"
grep -q "^FAIL" "$RESULT" && { echo "H8 FAIL"; exit 1; }
grep -q "H8 DONE" "$RESULT" || { echo "H8 FAIL: assertions did not complete"; exit 1; }
echo "H8 PASS: combo/listbox nItemIndex selection, unselect(0) and 1-based user-change mapping verified against real GTK widget state"
