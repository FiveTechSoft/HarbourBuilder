#!/bin/bash
# Multi-form class-identification regression (R5): with TWO live forms,
# RegenerateFormCode must read the TARGET form's own editor tab, not the
# active form's. RED at fc41f290: saving a healthy 2-form project is
# refused ("no identifiable form class") because the non-active Form2 is
# matched against the ACTIVE tab's text. GREEN after the fix: healthy
# project saves both forms (own preface each, no cross-contamination);
# broken Form2 (no CLASS line) refuses naming Form2 with both files
# byte-identical.
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
FIXBASE="$REPO/tests/fixtures/preclass2"
source "$REPO/tests/harness_lib.sh"
fail() { echo "MULTIFORM FAIL: $1"; rt_cleanup; exit 1; }

[ -d /tmp/harbour-review/bin/linux/gcc ] && export PATH=/tmp/harbour-review/bin/linux/gcc:$PATH
HBINCS="-I/tmp/harbour-review/include -I$REPO/include -I$REPO/source"

rt_provenance
FAILN=0
CASES="${@:-healthy broken}"

find_dlg() {  # echoes window id of a NEW HbBuilder dialog, "" if none
  local w
  for w in $(rt_ide_windows); do
    case " $W0 " in *" $w "*) continue;; esac
    [ "$(xdotool getwindowname "$w" 2>/dev/null)" = "HbBuilder" ] && { echo "$w"; return 0; }
  done
  return 1
}

run_case() {  # $1 = healthy|broken
  local c=$1 FIX="$FIXBASE/$1" RUN=/tmp/rt_mf_$1
  local BAR DLG w i TXT M1 M2 MD1 MD2 MD1b MD2b
  rm -rf "$RUN"; mkdir -p "$RUN"
  cp "$FIX"/Project1.hbp "$FIX"/Project1.prg "$FIX"/Form1.prg "$FIX"/Form2.prg "$RUN"/
  rt_setup "$RUN"
  rt_launch_ide
  rt_reopen_project
  MD1b=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
  MD2b=$(md5sum "$RUN/Form2.prg" | cut -d' ' -f1)
  W0=$(rt_ide_windows | tr '\n' ' ')
  BAR=$(rt_find_bar) || fail "IDE bar not found"
  rt_unmap_all_but "$BAR"; sleep 0.3
  xdotool mousemove 700 12 click 1; sleep 0.4
  touch -d '2000-01-01 00:00:00' "$RUN/Form1.prg" "$RUN/Form2.prg"
  xdotool key ctrl+s; sleep 2
  DLG=""
  for i in 1 2 3 4 5; do DLG=$(find_dlg) && break; sleep 1; done
  M1=$(stat -c %Y "$RUN/Form1.prg"); M2=$(stat -c %Y "$RUN/Form2.prg")
  if [ -z "$DLG" ] && { [ "$M1" -lt 1000000000 ] || [ "$M2" -lt 1000000000 ]; }; then
    # fallback: File > Save via menu
    xdotool mousemove 20 12 click 1; sleep 0.8
    xdotool mousemove 100 200 click 1; sleep 2
    for i in 1 2 3; do DLG=$(find_dlg) && break; sleep 1; done
    M1=$(stat -c %Y "$RUN/Form1.prg"); M2=$(stat -c %Y "$RUN/Form2.prg")
  fi
  if [ "$c" = "healthy" ]; then
    if [ -n "$DLG" ]; then
      eval "$(xdotool getwindowgeometry --shell "$DLG")"
      import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/mf_dlg.png 2>/dev/null
      TXT=$(tesseract /tmp/mf_dlg.png - 2>/dev/null | tr '\n' ' ')
      echo "  CASE healthy: SAVE REFUSED on a healthy 2-form project: $(echo "$TXT" | head -c 160)"
      FAILN=$((FAILN+1))
    fi
    [ "$M1" -ge 1000000000 ] || { echo "  CASE healthy: Form1.prg NOT saved"; FAILN=$((FAILN+1)); }
    [ "$M2" -ge 1000000000 ] || { echo "  CASE healthy: Form2.prg NOT saved"; FAILN=$((FAILN+1)); }
    grep -q 'COMENTARIO-PRECLASS-F1' "$RUN/Form1.prg" || { echo "  CASE healthy: Form1 lost its own preface"; FAILN=$((FAILN+1)); }
    grep -q 'COMENTARIO-PRECLASS-F2' "$RUN/Form2.prg" || { echo "  CASE healthy: Form2 lost its own preface"; FAILN=$((FAILN+1)); }
    grep -q 'COMENTARIO-PRECLASS-F2' "$RUN/Form1.prg" && { echo "  CASE healthy: Form1 contaminated with Form2 preface"; FAILN=$((FAILN+1)); }
    grep -q 'COMENTARIO-PRECLASS-F1' "$RUN/Form2.prg" && { echo "  CASE healthy: Form2 contaminated with Form1 preface"; FAILN=$((FAILN+1)); }
    [ "$(grep -ciE 'CLASS[ \t]+TForm1[ \t]+FROM[ \t]+TForm' "$RUN/Form1.prg")" = "1" ] || { echo "  CASE healthy: Form1 class lines != 1"; FAILN=$((FAILN+1)); }
    [ "$(grep -ciE 'CLASS[ \t]+TForm2[ \t]+FROM[ \t]+TForm' "$RUN/Form2.prg")" = "1" ] || { echo "  CASE healthy: Form2 class lines != 1"; FAILN=$((FAILN+1)); }
    for f in Form1 Form2; do
      if command -v harbour >/dev/null 2>&1; then
        ( cd "$RUN" && harbour "$f.prg" -n -w -es2 -q $HBINCS -o"/tmp/mf_syntax_$f.c" ) >/tmp/mf_syntax_$f.log 2>&1 \
          && echo "  CASE healthy: saved $f.prg compiles standalone (exit 0)" \
          || { echo "  CASE healthy: saved $f.prg FAILS standalone syntax"; head -6 /tmp/mf_syntax_$f.log | sed 's/^/    /'; FAILN=$((FAILN+1)); }
      fi
    done
  else
    if [ -z "$DLG" ]; then
      echo "  CASE broken: NO refusal with Form2 lacking its CLASS line"
      FAILN=$((FAILN+1))
    else
      eval "$(xdotool getwindowgeometry --shell "$DLG")"
      import -window root -crop "${WIDTH}x${HEIGHT}+${X}+${Y}" /tmp/mf_dlgb.png 2>/dev/null
      TXT=$(tesseract /tmp/mf_dlgb.png - 2>/dev/null | tr '\n' ' ')
      echo "  dialog OCR: $(echo "$TXT" | head -c 180)"
      echo "$TXT" | grep -q 'Form2' || { echo "  CASE broken: refusal does not name Form2"; FAILN=$((FAILN+1)); }
      xdotool mousemove $((X+WIDTH/2)) $((Y+HEIGHT-14)) click 1; sleep 1
    fi
    MD1=$(md5sum "$RUN/Form1.prg" | cut -d' ' -f1)
    MD2=$(md5sum "$RUN/Form2.prg" | cut -d' ' -f1)
    [ "$MD1" = "$MD1b" ] || { echo "  CASE broken: Form1.prg CHANGED despite refusal"; FAILN=$((FAILN+1)); }
    [ "$MD2" = "$MD2b" ] || { echo "  CASE broken: Form2.prg CHANGED despite refusal"; FAILN=$((FAILN+1)); }
  fi
  rt_cleanup
}

for c in $CASES; do
  echo "== case: $c =="
  run_case "$c"
done

if [ "$FAILN" -eq 0 ]; then
  echo "MULTIFORM PASS: 2-form healthy project saves both forms with their own prefaces; broken Form2 refuses naming Form2 with both files untouched."
else
  echo "MULTIFORM FAIL: $FAILN problem(s)"
  exit 1
fi
