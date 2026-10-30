#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/build_exit_gui
rt_provenance
mkdir -p "$RUN/tools"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
cat > "$RUN/tools/gcc" <<'EOF'
#!/bin/bash
if [ -f /tmp/build_exit_gui/fail ]; then
 case "$*" in *main.c*) echo "$*" >> /tmp/build_exit_gui/refusals; exit 7;; esac
fi
exec /usr/bin/gcc "$@"
EOF
chmod +x "$RUN/tools/gcc"
export PATH="$RUN/tools:$PATH"
rm -f "$RUN/fail" "$RUN/refusals"
B=/tmp/hbbuilder_build/$(printf '%s' "$RUN/Project1.hbp" | md5sum | cut -d' ' -f1)
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
press_run(){ BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; xdotool key ctrl+r; }
rm -f /tmp/debugmodules-result.txt
press_run
for try in $(seq 1 50); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { rt_cleanup; exit 1; }
OLD=$(sha256sum "$B/main.o" | cut -d' ' -f1)
rm "$B/.srchash" /tmp/debugmodules-result.txt
touch "$RUN/fail"
press_run
sleep 5
[ ! -f /tmp/debugmodules-result.txt ] || { echo 'FAIL stale app launched'; rt_cleanup; exit 1; }
[ "$OLD" = "$(sha256sum "$B/main.o" | cut -d' ' -f1)" ] || { rt_cleanup; exit 1; }
[ -s "$RUN/refusals" ] || { rt_cleanup; exit 1; }
for w in $(rt_ide_windows); do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*|*Build*) xdotool windowmap "$w"; xdotool windowmove "$w" 0 125; xdotool windowsize "$w" 1300 700; xdotool windowraise "$w";; esac
done
sleep 1
import -window root /tmp/build-exit-refused.png
tesseract /tmp/build-exit-refused.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -q 'exited 7' "$RUN/ocr" || { rt_cleanup; exit 1; }
echo "BUILD EXIT GUI refusal PASS stale main.o=$OLD not executed"
# Build failure displays a modal result dialog. Close only that dialog.
for w in $(rt_ide_windows); do
 case "$(xdotool getwindowname "$w")" in *Build\ Failed*) xdotool windowfocus "$w"; xdotool key Escape;; esac
done
rm "$RUN/fail"
press_run
for try in $(seq 1 50); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { rt_cleanup; exit 1; }
rt_cleanup
echo 'BUILD EXIT GUI recovery PASS'
