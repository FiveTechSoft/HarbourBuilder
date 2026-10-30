from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function HB_FormNumberEval');b=s.index('static function RestoreFormFromCode',a)
main='''function Main()
 local nFail:=0,c,a
 for each a in {{"-2147483648",.F.,-2147483648},{"2147483647",.F.,2147483647},{"+ 200",.F.,200},{"200.0",.F.,200},{".0",.F.,0},{"0xFFFFFF",.T.,16777215},{"0xFFFFFFFF",.T.,4294967295},{"-1",.T.,4294967295},{"4294967295",.T.,4294967295}}
  if !(HB_FormNumberEval(a[1],a[2])==a[3]);QOut("FAIL "+a[1]);nFail++;endif
 next
 for each c in {'200 + Len("x")',"2147483648","-2147483649","200.5",".5","200.0000000000000000001","200.","1e3","+",".","--1","0x","0xZZ","200 //comment",""}
  if HB_FormNumberEval(c,.F.)!=nil;QOut("FAIL reject "+c);nFail++;endif
 next
 if HB_FormNumberEval("4294967296",.T.)!=nil;nFail++;endif
 QOut("NUMERIC HEADER strict subset failures="+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
'''
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'probe.prg').write_text(main+s[a:b]);subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),str(r/'source/hbbuilder_common.prg'),str(r/'tests/messages_stubs.prg'),'-I'+str(r/'include'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True);raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
