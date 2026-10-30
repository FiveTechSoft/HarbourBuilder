#!/usr/bin/env python3
"""Actual complete Run C compile step, real GCC, checks abort and warning logs."""
from pathlib import Path
import subprocess,shutil
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();p=Path('/tmp/build-c-sequence');shutil.rmtree(p,ignore_errors=True);p.mkdir()
for name in ['main','classes','hix_runtime','hix_template']:
 (p/(name+'.c')).write_text('#warning '+name+'_diagnostic\nint '+name+'_sample(void){return 0;}\n')
a=s.index('   // Step 5: Compile C sources',s.index('static function TBRun'));b=s.index('   // Step 6:',a);step=s[a:b]
a=s.index('static function HB_BuildExec');b=s.index('static function TBRun',a);helper=s[a:b]
main='''static aCommands:={}
function Main()
 local nFail:=0,cLog,c,cGood:=MemoRead('/tmp/build-c-sequence/main.c')
 hb_MemoWrit('/tmp/build-c-sequence/classes.o','KEEP-OLD-CLASS')
 MemoWrit('/tmp/build-c-sequence/main.c','this is invalid C;')
 cLog:=Probe()
 if !('FAILED (main.c)' $ cLog).or.'FAILED (classes.c)' $ cLog; nFail++; endif
 if Len(aCommands)!=1; nFail++; endif
 if !(hb_MemoRead('/tmp/build-c-sequence/classes.o')=='KEEP-OLD-CLASS'); nFail++; endif
 QOut('NEGATIVE commands='+hb_ntos(Len(aCommands)))
 QOut(cLog)
 MemoWrit('/tmp/build-c-sequence/main.c',cGood)
 aCommands:={}
 cLog:=Probe()
 for each c in {'main','classes','hix_runtime','hix_template'}
  if !(c+'_diagnostic' $ cLog); nFail++; endif
 next
 if 'FAILED' $ cLog; nFail++; endif
 QOut(cLog)
 QOut('C SEQUENCE failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function Probe()
 local lError:=.F.,cLog:='',cCmd,cOutput,cHbInc:='/tmp/harbour-review/include',cBuildDir:='/tmp/build-c-sequence'
'''+step+'''return cLog
function GTK_ShellExec(c,nExit)
 local out:='',err:=''
 AAdd(aCommands,c)
 nExit:=hb_processRun('/bin/sh -c '+Chr(34)+c+Chr(34),,@out,@err)
return out+err
function GTK_ProgressStep(t)
 HB_SYMBOL_UNUSED(t)
return nil
'''
(p/'probe.prg').write_text(main+helper)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
