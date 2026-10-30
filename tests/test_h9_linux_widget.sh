#!/bin/bash
set -u
REPO=$(cd "$(dirname "$0")/.." && pwd)
python3 - "$REPO" <<'PY'
import pathlib,sys
r=pathlib.Path(sys.argv[1]);s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function RestoreSelectionAssignment');b=s.index('static function RestoreFormFromCode',a)
p=(r/'tests/test_h8_select.prg').read_text()
p=p.replace('   // Fresh widget', '''   UI_SetProp(oForm:oCombo:hCpp, 'cName', 'Combo')
   UI_SetProp(oForm:oList:hCpp, 'cName', 'List')
   // Fresh widget''')
p=p.replace('oForm:oCombo:Value := 2',"RestoreSelectionAssignment(oForm:hCpp, '::oCOMBO:Value := 2')")
p=p.replace('oForm:oCombo:Value := 0',"RestoreSelectionAssignment(oForm:hCpp, '::oCombo:Value := 0')")
p=p.replace('oForm:oList:nItemIndex := 2',"RestoreSelectionAssignment(oForm:hCpp, '::oList:Value := 2')")
p=p.replace('oForm:oList:nItemIndex := 0',"RestoreSelectionAssignment(oForm:hCpp, '::oList:Value := 0')")
p+=s[a:b]+'''\nfunction HB_SetParseBlock(h,t)
 HB_SYMBOL_UNUSED(h)
 MemoWrit('/tmp/h9_widget_block.txt',t)
return nil
'''
pathlib.Path('/tmp/h9_widget.prg').write_text(p)
PY
rm -f /tmp/h9_widget_block.txt
H8_PRG=/tmp/h9_widget.prg bash "$REPO/tests/test_h8_select.sh" || exit 1
[ ! -f /tmp/h9_widget_block.txt ] || { cat /tmp/h9_widget_block.txt; exit 1; }
echo 'H9 actual Linux parser -> native GTK widget PASS'
