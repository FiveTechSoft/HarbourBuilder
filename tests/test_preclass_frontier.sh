#!/bin/bash
# Pre-CLASS frontier regression (header preservation, tramo 2):
# the pre-CLASS region must end at the REAL form class declaration,
# recognized with token boundaries (space OR tab), CREATE CLASS syntax,
# and block-comment awareness; when the form class cannot be identified
# the sync/save must be REFUSED (no duplication, no silent loss).
# Cases: tabclass helperclass blockcomment createclass noclass
# RED at 4a9208e (Left(...,6)=="CLASS " literal): all five fail.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIXBASE="$REPO/tests/fixtures/preclass"
source "$REPO/tests/harness_lib.sh"
fail() { echo "PRECLASS_FRONTIER FAIL: $1"; rt_cleanup; exit 1; }

[ -d /tmp/harbour-review/bin/linux/gcc ] && export PATH=/tmp/harbour-review/bin/linux/gcc:$PATH
HBINCS="-I/tmp/harbour-review/include -I$REPO/include -I$REPO/source"

rt_provenance
FAILN=0
CASES="${@:-tabclass helperclass blockcomment createclass noclass}"

syntax_check() {  # $1=case $2=file ; the ACTUAL saved original, no artifacts
  command -v harbour >/dev/null 2>&1 || { echo "  CASE $1: harbour toolchain absent, syntax SKIP"; return; }
  ( cd "$(dirname "$2")" && harbour "$(basename "$2")" -n -w -es2 -q $HBINCS \
      -o"/tmp/preclass_syntax_$1.c" ) >/tmp/preclass_syntax_$1.log 2>&1 \
    && echo "  CASE $1: saved original compiles standalone (exit 0)" \
    || { echo "  CASE $1: saved original FAILS standalone syntax:"; \
         head -8 /tmp/preclass_syntax_$1.log | sed 's/^/    /'; FAILN=$((FAILN+1)); }
}

run_save_case() {  # $1=case  (tabclass helperclass blockcomment createclass)
  local c=$1 FIX="$FIXBASE/$1" RUN=/tmp/rt_preclass_$1
  local BAR M1 F ncls ninc lhelp lform MARKER
  rm -rf "$RUN"; mkdir -p "$RUN"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
  rt_setup "$RUN"
  rt_launch_ide
  rt_reopen_project
  eval "$(xdotool getwindowgeometry --shell "$RT_DESIGNER")"
  xdotool windowsize "$RT_DESIGNER" $((WIDTH+1)) "$HEIGHT"; sleep 1.5
  xdotool windowsize "$RT_DESIGNER" "$WIDTH" "$HEIGHT"; sleep 1.5
  BAR=$(rt_find_bar) || fail "IDE bar not found ($c)"
  rt_unmap_all_but "$BAR"; sleep 0.3
  xdotool mousemove 700 12 click 1; sleep 0.4
  touch -d '2000-01-01 00:00:00' "$RUN/Form1.prg"
  xdotool key ctrl+s; sleep 2
  M1=$(stat -c %Y "$RUN/Form1.prg")
  if [ "$M1" -lt 1000000000 ]; then
    xdotool mousemove 20 12 click 1; sleep 0.8
    xdotool mousemove 100 200 click 1; sleep 2
    M1=$(stat -c %Y "$RUN/Form1.prg")
  fi
  if [ "$M1" -lt 1000000000 ]; then
    echo "  CASE $c: NO REAL SAVE (mtime unchanged)"; FAILN=$((FAILN+1)); rt_cleanup; return
  fi
  F="$RUN/Form1.prg"
  ncls=$(grep -ciE 'CLASS[ \t]+TForm1[ \t]+FROM[ \t]+TForm' "$F")
  [ "$ncls" = "1" ] || { echo "  CASE $c: form class declaration lines = $ncls, expected 1 (duplication?)"; FAILN=$((FAILN+1)); }
  ninc=$(grep -c '#include "hbbuilder.ch"' "$F")
  [ "$ninc" = "1" ] || { echo "  CASE $c: #include lines = $ninc, expected 1"; FAILN=$((FAILN+1)); }
  MARKER=""
  case "$c" in
    tabclass) MARKER=TAB;; helperclass) MARKER=HELPER;;
    blockcomment) MARKER=BLOCK;; createclass) MARKER=CREATE;;
  esac
  grep -q "COMENTARIO-PRECLASS-$MARKER" "$F" \
    || { echo "  CASE $c: header comment missing"; FAILN=$((FAILN+1)); }
  grep -q 'BUTTON ::oButton1 PROMPT' "$F" \
    || { echo "  CASE $c: generated BUTTON line missing"; FAILN=$((FAILN+1)); }
  case "$c" in
    helperclass)
      [ "$(grep -c '^CLASS THelper FROM TForm$' "$F")" = "1" ] \
        || { echo "  CASE $c: helper class dropped"; FAILN=$((FAILN+1)); }
      lhelp=$(grep -n '^CLASS THelper FROM TForm$' "$F" | cut -d: -f1)
      lform=$(grep -n '^CLASS TForm1 FROM TForm$' "$F" | cut -d: -f1)
      [ -n "$lhelp" ] && [ -n "$lform" ] && [ "$lhelp" -lt "$lform" ] \
        || { echo "  CASE $c: helper class not preserved BEFORE the form class"; FAILN=$((FAILN+1)); }
      ;;
    blockcomment)
      grep -q 'Class de la ventana principal' "$F" \
        || { echo "  CASE $c: block-comment body lost"; FAILN=$((FAILN+1)); }
      grep -q '^\*/$' "$F" \
        || { echo "  CASE $c: block-comment close lost"; FAILN=$((FAILN+1)); }
      ;;
    createclass)
      grep -q 'CREATE CLASS' "$F" \
        && { echo "  CASE $c: CREATE CLASS line must be consumed, not copied"; FAILN=$((FAILN+1)); }
      ;;
  esac
  syntax_check "$c" "$F"
  rt_cleanup
}

run_noclass_case() {
  local c=noclass FIX="$FIXBASE/noclass" RUN=/tmp/rt_preclass_noclass
  local MD0 MD1 W0 CED BAR DLG w i TXT
  rm -rf "$RUN"; mkdir -p "$RUN"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$RUN"/
  rt_setup "$RUN"
  rt_launch_ide
  rt_reopen_project
  MD0=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  W0=$(rt_ide_windows | tr '\n' ' ')
  sed '/^CLASS TForm1 FROM TForm$/d' "$RUN/Form1.prg" > /tmp/preclass_noclass_edit.txt
  CED=""
  for w in $(rt_ide_windows); do
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "Code Editor" ] && { CED=$w; break; }
  done
  [ -n "$CED" ] || fail "Code Editor window not found"
  BAR=$(rt_find_bar) || fail "IDE bar not found"
  rt_park_all_but "$CED" "$BAR"; sleep 0.5
  eval "$(xdotool getwindowgeometry --shell "$CED")"
  xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT/2)) click 1; sleep 0.5
  xdotool key ctrl+a; sleep 0.5
  xdotool type --delay 6 --file /tmp/preclass_noclass_edit.txt; sleep 2
  xdotool windowactivate "$BAR" 2>/dev/null
  xdotool mousemove 700 12 click 1; sleep 0.4
  xdotool key ctrl+s; sleep 2
  DLG=""
  for i in 1 2 3 4 5 6; do
    for w in $(rt_ide_windows); do
      case " $W0 " in *" $w "*) continue;; esac
      [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && { DLG=$w; break; }
    done
    [ -n "$DLG" ] && break
    sleep 1
  done
  if [ -z "$DLG" ]; then
    echo "  CASE noclass: NO refusal dialog on save without an identifiable form class"
    FAILN=$((FAILN+1))
  else
    eval "$(xdotool getwindowgeometry --shell "$DLG")"
    import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/preclass_noclass_dlg.png 2>/dev/null
    TXT=$(tesseract /tmp/preclass_noclass_dlg.png - 2>/dev/null)
    echo "  dialog OCR: $(echo "$TXT" | tr '\n' ' ' | head -c 200)"
    echo "$TXT" | grep -qi 'could not be identified' \
      || { echo "  CASE noclass: dialog is not the unidentifiable-class refusal"; FAILN=$((FAILN+1)); }
    xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
  fi
  MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  [ "$MD0" = "$MD1" ] \
    || { echo "  CASE noclass: Form1.prg CHANGED on disk despite unidentifiable class"; FAILN=$((FAILN+1)); }
  rt_cleanup
}

for c in $CASES; do
  echo "== case: $c =="
  if [ "$c" = "noclass" ]; then run_noclass_case; else run_save_case "$c"; fi
done

if [ "$FAILN" -eq 0 ]; then
  echo "PRECLASS_FRONTIER PASS: pre-CLASS region ends at the real form class (tab, CREATE CLASS, block comments, helper classes) and unidentifiable class refuses the save."
else
  echo "PRECLASS_FRONTIER FAIL: $FAILN problem(s)"
  exit 1
fi
