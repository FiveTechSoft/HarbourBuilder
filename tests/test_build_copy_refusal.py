#!/usr/bin/env python3
"""Compile actual framework staging caller blocks with real filesystem copies."""
import pathlib,subprocess,shutil
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();p=pathlib.Path('/tmp/build-copy-refusal');shutil.rmtree(p,ignore_errors=True);p.mkdir()
parts=[]
for name,fn in [('Run','TBRun'),('Debug','TBDebugRun')]:
 a=s.index('   GTK_ShellExec( "cp " + cProjDir + "/source/core/classes.prg',s.index('static function '+fn+'(')) if 'HB_StageFramework( cProjDir' not in s else s.index('   if ! HB_StageFramework( cProjDir',s.index('static function '+fn+'('))
 b=s.index('   // Step 2:',a)
 parts.append('function Probe'+name+'(cProjDir,cBuildDir)\n'+s[a:b]+' nContinued++\nreturn .T.\n')
main='''static nContinued:=0
function Main()
 local nFail:=0
 if ProbeRun('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/run'); nFail++; endif
 if ProbeDebug('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/debug'); nFail++; endif
 if nContinued!=0; nFail++; endif
 FErase('/tmp/build-copy-refusal/run/classes.prg/old')
 DirRemove('/tmp/build-copy-refusal/run/classes.prg')
 FErase('/tmp/build-copy-refusal/debug/classes.prg/old')
 DirRemove('/tmp/build-copy-refusal/debug/classes.prg')
 if !ProbeRun('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/run'); nFail++; endif
 if !ProbeDebug('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/debug'); nFail++; endif
 FErase('/tmp/build-copy-refusal/repo/source/hix_runtime.prg')
 MemoWrit('/tmp/build-copy-refusal/run/hix_runtime.c','STALE')
 MemoWrit('/tmp/build-copy-refusal/run/hix_runtime.o','STALE')
 if !ProbeRun('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/run'); nFail++; endif
 if File('/tmp/build-copy-refusal/run/hix_runtime.prg').or.File('/tmp/build-copy-refusal/run/hix_runtime.c').or.File('/tmp/build-copy-refusal/run/hix_runtime.o'); nFail++; endif
 FErase('/tmp/build-copy-refusal/repo/include/hbide.ch')
 if ProbeRun('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/run'); nFail++; endif
 hb_DirCreate('/tmp/build-copy-refusal/repo/include/hbide.ch')
 hb_MemoWrit('/tmp/build-copy-refusal/run/hbide.ch','KEEPME')
 if ProbeRun('/tmp/build-copy-refusal/repo','/tmp/build-copy-refusal/run'); nFail++; endif
 if !(hb_MemoRead('/tmp/build-copy-refusal/run/hbide.ch')=='KEEPME'); nFail++; endif
 QOut('COPY failure refusal failures='+hb_ntos(nFail)+' continued='+hb_ntos(nContinued))
 ErrorLevel(nFail)
return nil
function GTK_ShellExec(c)
 local out:='', err:=''
 hb_processRun(c,,@out,@err)
return out+err
function GTK_ProgressClose()
return nil
function MsgInfo(t,title)
 HB_SYMBOL_UNUSED(title)
 QOut(t)
return nil
'''
for f in ['source/core/classes.prg','source/hix_runtime.prg','source/hix_template.prg','include/hbbuilder.ch','include/hbide.ch','source/debugger/dbgclient.prg']:
 q=p/'repo'/f;q.parent.mkdir(parents=True,exist_ok=True);q.write_text('NEW')
for stage in ['run','debug']:
 q=p/stage/'classes.prg';q.mkdir(parents=True);(q/'old').write_text('OLD')
helper=''
if 'static function HB_StageFramework' in s:
 a=s.index('static function HB_StageFramework');b=s.index('static function TBRun',a);helper=s[a:b]
(p/'probe.prg').write_text(main+''.join(parts)+helper)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
