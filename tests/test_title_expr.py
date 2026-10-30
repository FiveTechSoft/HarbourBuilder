from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function HB_FormTitleExprEval');b=s.index('static function RestoreFormFromCode',a)
main='''function Main()
 local nFail:=0,c
 if !(HB_FormTitleExprEval('"a" + Chr(34) + "b"')=='a"b');nFail++;endif
 for each c in {'"a" + Upper("b")','"a" +','"a" "b"','Chr(foo)','Chr(256)',''}
  if HB_FormTitleExprEval(c)!=nil;nFail++;endif
 next
 QOut('TITLE expression strict safe subset failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
'''
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'probe.prg').write_text(main+s[a:b]);subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),str(r/'source/hbbuilder_common.prg'),str(r/'tests/messages_stubs.prg'),'-I'+str(r/'include'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True);raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
