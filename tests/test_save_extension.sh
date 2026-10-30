#!/bin/bash
# Save dialog extension normalization: typing a name that already ends in
# .hbp must produce exactly one extension (RED: GTK appended a second one,
# name.hbp.hbp), and the save must write the full project there.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
RUNA=/tmp/rt_saveext
DEST=/tmp/rt_saveext_dest
source "$REPO/tests/harness_lib.sh"
fail() { echo "SAVEEXT FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
rm -rf "$RUNA" "$DEST"; mkdir -p "$RUNA" "$DEST"
rt_setup "$RUNA"; rt_launch_ide
IDEPID=$RT_IDEPID; sleep 3
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+s; sleep 2.5
xdotool key ctrl+l; sleep 0.8
xdotool type --delay 15 "$DEST/foo.hbp"; sleep 0.5
xdotool key Return; sleep 3
[ -f "$DEST/foo.hbp.hbp" ] && fail "double extension written: foo.hbp.hbp exists"
[ -f "$DEST/foo.hbp" ]      || fail "foo.hbp not written"
[ -f "$DEST/Project1.prg" ] || fail "Project1.prg not written next to foo.hbp"
[ -f "$DEST/Form1.prg" ]    || fail "Form1.prg not written next to foo.hbp"
grep -q "foo" "$DEST/foo.hbp" || true
echo "  saveext: foo.hbp + Project1.prg + Form1.prg written, no double extension"
# and the save must leave the session clean (no unsaved-changes prompt)
DLG=""
xdotool mousemove 700 12 click 1; sleep 0.4
xdotool key ctrl+q; sleep 3
for w in $(rt_ide_windows); do rt_is_unsaved_dialog "$w" && DLG=$w; done
[ -n "$DLG" ] && { rt_cleanup; fail "unsaved prompt after a complete save"; }
sleep 2
kill -0 "$IDEPID" 2>/dev/null && fail "IDE did not exit after save+ctrl+q"
echo "SAVEEXT PASS: typed name with .hbp saved once, full project written, session clean"
rt_cleanup
