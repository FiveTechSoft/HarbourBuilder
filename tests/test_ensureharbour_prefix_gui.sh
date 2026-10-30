#!/bin/bash
# Real IDE setup dialog/caller, isolated source/make. Reuses installed toolchain;
# this is NOT a full Harbour download/build test.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/ensureharbour_prefix_gui
[ ! -e /tmp/harbour-src ] || { echo 'BLOCK fixture source already exists';exit 2; }
mkdir -p /tmp/harbour-src/config "$RUN/tools" "$RUN/home with spaces"
touch /tmp/harbour-src/config/global.mk
trap 'rt_cleanup;rm -rf /tmp/harbour-src' EXIT
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
cat > "$RUN/tools/make" <<'MAKE'
#!/bin/sh
printf '%s' "$HB_INSTALL_PREFIX" > "$INSTALL_RECORD"
[ -n "$HB_INSTALL_PREFIX" ] || exit 7
ln -s /tmp/harbour-review "$HB_INSTALL_PREFIX"
MAKE
chmod +x "$RUN/tools/make"
export HOME="$RUN/home with spaces" PATH="$RUN/tools:$PATH" INSTALL_RECORD="$RUN/installed-prefix.txt"
rm -f "$HOME/harbour" "$INSTALL_RECORD" /tmp/debugmodules-result.txt
rt_provenance
rt_setup "$RUN";rt_launch_ide
for try in $(seq 1 12);do rt_find_bar >/dev/null&&break;sleep 1;done
rt_reopen_project
BAR=$(rt_find_bar);rt_unmap_all_but "$BAR";xdotool mousemove 700 12 click 1;xdotool key ctrl+r;sleep 2
import -window root /tmp/ensureharbour-setup-question.png
# Click Yes in the visually checked setup question; default Return is No.
xdotool mousemove 296 126 click 1;sleep 2
import -window root /tmp/ensureharbour-setup-result.png
xdotool mousemove 180 125 click 1
for try in $(seq 1 70);do [ -f /tmp/debugmodules-result.txt ]&&break;sleep 1;done
python3 - "$INSTALL_RECORD" "$HOME/harbour" <<'CHECK'
from pathlib import Path
import sys
p=Path(sys.argv[1]);assert p.exists(),'make did not run';assert p.read_text()==sys.argv[2],p.read_text();assert Path(sys.argv[2]+'/bin/linux/gcc/harbour').is_file();print('GUI setup prefix byte-exact and compiler accessible')
CHECK
[ $? -eq 0 ] || exit 1
grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt || { echo 'FAIL caller Run did not execute';exit 1; }
echo 'GUI EnsureHarbour returned success and caller Run compiled/executed real toolchain'
import -window root /tmp/ensureharbour-caller-run.png
