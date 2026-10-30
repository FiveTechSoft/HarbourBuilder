#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
source "$REPO/tests/harness_lib.sh"
RUN=/tmp/ins_identity
fail(){ echo "IDENTITY FAIL: $1"; rt_cleanup; exit 1; }
rt_provenance
mkdir -p "$RUN"
cp "$REPO"/tests/fixtures/roundtrip/{Form1.prg,Project1.prg,Project1.hbp} "$RUN/"
rt_setup "$RUN"; rt_launch_ide; rt_reopen_project
INS=""
for w in $(rt_ide_windows); do
 case "$(xdotool getwindowname "$w")" in Inspector*) INS=$w;; esac
done
[ -n "$INS" ] || fail 'Inspector missing'
pick(){
 local idx=$1 want=$2
 xdotool windowmove "$INS" 0 165; xdotool windowraise "$INS"; xdotool windowfocus "$INS"
 xdotool mousemove 100 182 click 1; xdotool key Home
 [ "$idx" -gt 0 ] && xdotool key --repeat "$idx" --repeat-delay 40 Down
 xdotool key Return; sleep 0.7
 xdotool windowraise "$INS"
 eval "$(xdotool getwindowgeometry --shell "$INS")"
 import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" "/tmp/identity_${idx}.png"
 convert "/tmp/identity_${idx}.png" +repage -resize 200% "/tmp/identity_ocr.png"
 local title txt
 title=$(xdotool getwindowname "$INS")
 txt=$(tesseract /tmp/identity_ocr.png - --psm 6 2>/dev/null)
 if [[ "$want" == page* ]]; then
  echo "$txt" | grep -q cCaption || fail "index$idx did not expose page caption"
  echo "$txt" | grep -q nPage || fail "index$idx did not expose page index"
 elif [ "$want" = column ]; then
  echo "$txt" | grep -q nWidth || fail "column width property missing"
 else
  [[ "$title" == "Inspector: $want" ]] || fail "index$idx expected $want got $title"
 fi
 echo "  selected index$idx expected=$want title=$title"
}
case "${1:-browse}" in
 before) pick 1 TButton;;
 folder) pick 13 TFolder;;
 page1) pick 14 page1;;
 page2) pick 15 page2;;
 after) pick 16 TButton;;
 browse) pick 17 TBrowse;;
 column) pick 18 column;;
 delete)
  pick 1 TButton
  xdotool windowmove "$RT_DESIGNER" 400 200
  xdotool windowraise "$RT_DESIGNER"; xdotool windowfocus "$RT_DESIGNER"
  xdotool key Delete; sleep 1
  pick 16 TBrowse;;
esac
rt_cleanup
echo "IDENTITY CASE ${1:-browse} PASS"
