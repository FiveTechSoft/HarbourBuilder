#!/usr/bin/env python3
"""Compile actual Run/Debug source staging prefixes and fail real disk writes."""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text()
p=pathlib.Path('/tmp/build-write-refusal');p.mkdir(exist_ok=True)
parts=[]
for name,fn,start in [('Run','TBRun','   // Step 1: Save files'),('Debug','TBDebugRun','   // Step 1: Save user code')]:
 a=s.index(start,s.index('static function '+fn+'('));b=s.index('   GTK_ShellExec( "cp ',a)
 parts.append('function Probe'+name+'(cBuildDir)\n local cLog:=\'\', i\n'+s[a:b]+''' nContinued++
return .T.
''')
main='''static aForms := {{'Form1',nil,'FORMNEW'}}
static aModules := {{'Helpers','OLD',''}}
static hCodeEditor := 0
static nContinued := 0
function Main()
 local nFail:=0
 if ProbeRun('/tmp/build-write-refusal/run'); nFail++; endif
 if ProbeDebug('/tmp/build-write-refusal/debug'); nFail++; endif
 if nContinued!=0; nFail++; endif
 QOut('BUILD write refusal failures='+hb_ntos(nFail)+' continued='+hb_ntos(nContinued))
 ErrorLevel(nFail)
return nil
function CodeEditorGetTabText(h,t)
 HB_SYMBOL_UNUSED(h)
 HB_SYMBOL_UNUSED(t)
return 'NEW'
function GTK_ProgressStep(t)
 HB_SYMBOL_UNUSED(t)
return nil
function GTK_ProgressClose()
return nil
function MsgInfo(t,title)
 HB_SYMBOL_UNUSED(title)
 QOut(t)
return nil
'''
for stage in ['run','debug']:
 (p/stage/'Project1.prg').mkdir(parents=True,exist_ok=True)
(p/'probe.prg').write_text(main+''.join(parts))
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
