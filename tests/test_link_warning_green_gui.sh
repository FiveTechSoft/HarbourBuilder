#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
trap 'rt_cleanup' EXIT
RUN=/tmp/link_warning_gui
mkdir -p "$RUN/tools"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
cat > "$RUN/tools/gcc" <<'GCC'
#!/bin/bash
case "$*" in *"/UserApp "*|*"/DebugApp "*)
 /usr/bin/gcc "$@"
 ec=$?
 echo "warning: link diagnostic: error-count=0" >&2
 echo "link_exit=$ec" >> /tmp/link_warning_status
 exit "$ec";;
esac
exec /usr/bin/gcc "$@"
GCC
chmod +x "$RUN/tools/gcc"
export PATH="$RUN/tools:$PATH"
rm -f /tmp/link_warning_status
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
rm -f /tmp/debugmodules-result.txt
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;if [ "${MODE:-run}" = debug ];then xdotool mousemove 15 62 click 1;else xdotool key ctrl+r;fi
for try in $(seq 1 50);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL no app';exit 1; }
for w in $(rt_ide_windows);do
 case "$(xdotool getwindowname "$w")" in *Messages*|*Compiler*)xdotool windowmap "$w";xdotool windowmove "$w" 0 125;xdotool windowsize "$w" 1500 820;xdotool windowraise "$w";;esac
done
sleep 1
if [ "${MODE:-run}" = debug ];then
 xdotool mousemove 300 300 click 1;xdotool key ctrl+End;sleep 1
fi
import -window root /tmp/link-warning-red.png
tesseract /tmp/link-warning-red.png - --psm 6 2>/dev/null | tee "$RUN/ocr"
grep -q 'error-count=0' "$RUN/ocr" || { echo 'FAIL RED not seen';exit 1; }
cat /tmp/link_warning_status
grep -q 'link_exit=0' /tmp/link_warning_status || exit 1
echo "GREEN native IDE ${MODE:-run} link exit0 with diagnostic error-count=0 executes app" 
