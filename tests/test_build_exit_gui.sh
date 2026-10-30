#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
MODE=${MODE:-run}
export FAIL_STAGE=${FAIL_STAGE:-compile}
export WARN_ONLY=${WARN_ONLY:-0}
RUN=/tmp/build_exit_gui
rt_provenance
mkdir -p "$RUN/tools"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
cat > "$RUN/tools/gcc" <<'EOF'
#!/bin/bash
if [ -f /tmp/build_exit_gui/fail ]; then
 if [ "$FAIL_STAGE" = link ]; then
  case "$*" in *"/UserApp "*|*"/DebugApp "*) echo "$*" >> /tmp/build_exit_gui/refusals; exit 7;; esac
 else
  case "$*" in *main.c*) echo "$*" >> /tmp/build_exit_gui/refusals; exit 7;; esac
 fi
fi
if [ "$WARN_ONLY" = 1 ]; then
 case "$*" in *main.c*) echo "warning: compiler-success-regression-probe" >&2;; esac
fi
exec /usr/bin/gcc "$@"
EOF
chmod +x "$RUN/tools/gcc"
export PATH="$RUN/tools:$PATH"
rm -f "$RUN/fail" "$RUN/refusals"
B=/tmp/hbbuilder_build/$(printf '%s' "$RUN/Project1.hbp" | md5sum | cut -d' ' -f1)
[ "$MODE" != debug ] || B=/tmp/hbbuilder_debug
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
press_run(){ BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; if [ "$MODE" = debug ]; then xdotool mousemove 15 62 click 1; else xdotool key ctrl+r; fi; }
rm -f /tmp/debugmodules-result.txt
press_run
for try in $(seq 1 50); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { rt_cleanup; exit 1; }
OBJ=main.o
[ "$MODE" != debug ] || OBJ=debug_main.o
if [ "$WARN_ONLY" = 1 ]; then
 for w in $(rt_ide_windows); do
  case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*) xdotool windowmap "$w"; xdotool windowmove "$w" 0 125; xdotool windowsize "$w" 1300 700; xdotool windowraise "$w";; esac
 done
 sleep 1
 import -window root /tmp/build-warning-success.png
 tesseract /tmp/build-warning-success.png - --psm 6 2>/dev/null | tee "$RUN/warning-ocr"
 grep -q compiler-success-regression-probe "$RUN/warning-ocr" || { rt_cleanup; exit 1; }
 rt_cleanup
 echo 'GUI warning with exit0 preserved and valid app executed PASS'
 exit 0
fi
OLD=$(sha256sum "$B/$OBJ" | cut -d' ' -f1)
rm -f "$B/.srchash" /tmp/debugmodules-result.txt
touch "$RUN/fail"
press_run
sleep 5
if [ "${EXPECT_OLD:-0}" = 1 ]; then
 for try in $(seq 1 40); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
 grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { rt_cleanup; exit 1; }
 echo "RED reproduced: silent gcc exit7 reused stale $OBJ and executed app"
 rt_cleanup; exit 0
fi
[ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL stale app launched'; rt_cleanup; exit 1; }
[ "$OLD" = "$(sha256sum "$B/$OBJ" | cut -d' ' -f1)" ] || { rt_cleanup; exit 1; }
[ -s "$RUN/refusals" ] || { rt_cleanup; exit 1; }
for w in $(rt_ide_windows); do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*) xdotool windowmap "$w"; xdotool windowmove "$w" 0 125; xdotool windowsize "$w" 1300 700; xdotool windowraise "$w";; esac
done
sleep 1
if [ "$MODE" = debug ] && [ "$FAIL_STAGE" = link ]; then
 xdotool mousemove 300 300 click 1; xdotool key ctrl+End; sleep 1
fi
import -window root /tmp/build-exit-$MODE-refused.png
tesseract /tmp/build-exit-$MODE-refused.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -q 'exited 7' "$RUN/ocr" || { rt_cleanup; exit 1; }
echo "BUILD EXIT GUI refusal PASS mode=$MODE stale $OBJ=$OLD not executed"
# IDE_ShowBuildResult only shows Messages; no modal to dismiss.
rm "$RUN/fail"
press_run
for try in $(seq 1 50); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { rt_cleanup; exit 1; }
rt_cleanup
echo "BUILD EXIT GUI mode=$MODE stage=$FAIL_STAGE recovery PASS"
