#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/userapp_publish_gui
rt_provenance
mkdir -p "$RUN"
cp "$REPO/tests/fixtures/debugmodules/"* "$RUN/"
TARGET=$RUN/userapp_publish_gui
[ ! -f "$TARGET" ] || rm "$TARGET"
mkdir -p "$TARGET"
rm -f /tmp/debugmodules-result.txt
rt_setup "$RUN"; rt_launch_ide
for try in $(seq 1 12); do rt_find_bar >/dev/null && break; sleep 1; done
rt_reopen_project
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; xdotool key ctrl+r
sleep 11
import -window root /tmp/userapp-publish-refusal.png
text=$(tesseract /tmp/userapp-publish-refusal.png - --psm 6 2>/dev/null)
echo "$text" | grep -E 'Build aborted|UserApp|copy' || true
if ! echo "$text" | grep -q 'Build aborted'; then rt_cleanup; echo 'PUBLISH GUI FAIL no refusal'; exit 1; fi
if [ -f /tmp/debugmodules-result.txt ]; then rt_cleanup; echo 'PUBLISH GUI FAIL launched'; exit 1; fi
xdotool key Return; sleep 1
rmdir "$TARGET"
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; xdotool key ctrl+r
for try in $(seq 1 50); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
if ! grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt 2>/dev/null || [ ! -x "$TARGET" ]; then rt_cleanup; echo 'PUBLISH GUI FAIL repair'; exit 1; fi
B=/tmp/hbbuilder_build/$(printf '%s' "$RUN/Project1.hbp" | md5sum | cut -d' ' -f1)
cmp "$TARGET" "$B/UserApp" || { rt_cleanup; exit 1; }
stat -c 'published mode=%a bytes=%s' "$TARGET"
# Same IDE, no edits: force publication failure on the cache-hit path.
BEFORE=$(stat -c %Y "$B/UserApp")
rm -f /tmp/debugmodules-result.txt "$TARGET"
mkdir "$TARGET"
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; xdotool key ctrl+r
sleep 3
import -window root /tmp/userapp-publish-cache-refusal.png
text=$(tesseract /tmp/userapp-publish-cache-refusal.png - --psm 6 2>/dev/null)
if ! echo "$text" | grep -q 'Build aborted' || [ -f /tmp/debugmodules-result.txt ]; then rt_cleanup; echo 'PUBLISH CACHE FAIL no refusal or launched'; exit 1; fi
[ "$BEFORE" = "$(stat -c %Y "$B/UserApp")" ] || { rt_cleanup; exit 1; }
xdotool key Return; sleep 1; rmdir "$TARGET"
BAR=$(rt_find_bar); rt_unmap_all_but "$BAR"; xdotool mousemove 700 12 click 1; xdotool key ctrl+r
for try in $(seq 1 12); do [ -f /tmp/debugmodules-result.txt ] && break; sleep 1; done
if ! grep -q MODULES-EXECUTED /tmp/debugmodules-result.txt 2>/dev/null || [ ! -x "$TARGET" ]; then rt_cleanup; echo 'PUBLISH CACHE FAIL repair'; exit 1; fi
cmp "$TARGET" "$B/UserApp" || { rt_cleanup; exit 1; }
[ "$BEFORE" = "$(stat -c %Y "$B/UserApp")" ] || { rt_cleanup; exit 1; }
echo 'PUBLISH CACHE PASS no rebuild, refused publication then repaired executable and ran'

rt_cleanup
echo 'PUBLISH GUI PASS refused directory, no launch; repaired copy executable identical and ran'
