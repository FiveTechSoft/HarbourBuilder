#!/usr/bin/env python3
from pathlib import Path
import tempfile,subprocess
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function HB_NextFormName(');b=s.index('static function MenuNewForm()',a)
main='''function Main()
 local nFail:=0
 if !(HB_NextFormName({{"Form1"},{"Form2"}}, {}) == "Form3");nFail++;endif
 if !(HB_NextFormName({{"Form1"},{"Form3"}}, {}) == "Form4");nFail++;endif
 if !(HB_NextFormName({{"Form1"},{"form3"}}, {{"FORM4"},{"Form5"}}) == "Form6");nFail++;endif
 if !(HB_NextFormName({{"Invoice"}}, {{"Form2"}}) == "Form3");nFail++;endif
 QOut("NAME selection failures="+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'p.prg').write_text(main+s[a:b]);subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'p.prg'),'-gtstd','-q','-quiet','-o'+str(p/'p')],check=True);raise SystemExit(subprocess.run([str(p/'p')]).returncode)
