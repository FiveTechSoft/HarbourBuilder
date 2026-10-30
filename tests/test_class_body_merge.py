#!/usr/bin/env python3
"""Actual class-body preservation helper, exact lines and identity cases."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function HB_DesignerDataName');b=s.index('static function RegenerateFormCode',a)
main='''static s_aUnserializable:={}
function Main()
 local e:=Chr(13)+Chr(10),cOld,cNew,cOut,nFail:=0,cLine
 cOld:='CLASS TForm1 FROM TForm'+e+;
 ' // USER comment'+e+' DATA nCounter INIT 42 // USER-COUNTER'+e+;
 ' DATA cNote INIT "keep  spaces" // USER-NOTE'+e+;
 ' DATA oKeep INIT nil // custom member'+e+;
 '   DATA oGone   // TButton'+e+;
 '   DATA oAmbiguous   // custom'+e+;
 ' METHOD UserCounter()'+e+' METHOD CreateForm()'+e+'ENDCLASS'+e+;
 'METHOD CreateForm() CLASS TForm1'+e+' @ 1, 2 BUTTON ::oGone OF Self SIZE 10, 10'+e
 cNew:='   DATA oKeep   // TButton'+e+'   DATA oAdded   // TButton'+e
 cOut:=HB_MergeClassBody(cOld,1,cNew,'|GONE|AMBIGUOUS|')
 for each cLine in {' // USER comment',' DATA nCounter INIT 42 // USER-COUNTER',' DATA cNote INIT "keep  spaces" // USER-NOTE',' DATA oKeep INIT nil // custom member',' METHOD UserCounter()',' METHOD CreateForm()','   DATA oAmbiguous   // custom'}
  if !(cLine+e $ cOut); nFail++; endif
 next
 if 'DATA oGone' $ cOut; nFail++; endif
 if !( 'DATA oAdded' $ cOut ); nFail++; endif
 if 'DATA oKeep   //' $ cOut; nFail++; endif
 if !(HB_MergeClassBody('CLASS TForm1'+e+cOut+'ENDCLASS'+e,1,cNew,'|')==cOut); nFail++; endif
 if !HB_ClassDeclaresMember('DATA oOther, oAdded INIT nil','OADDED').or.Len(s_aUnserializable)!=1; nFail++; endif
 QOut(cOut)
 QOut('CLASS BODY exact custom lines/add/delete/fixpoint failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
'''
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'probe.prg').write_text(main+s[a:b]);subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),str(r/'source/hbbuilder_common.prg'),str(r/'tests/messages_stubs.prg'),'-I'+str(r/'include'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True);raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
