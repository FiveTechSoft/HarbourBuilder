#!/usr/bin/env python3
"""Compile actual Run/Debug source staging prefixes and fail real disk writes."""
import pathlib,subprocess,shutil
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text()
p=pathlib.Path('/tmp/build-write-refusal')
if p.exists(): shutil.rmtree(p)
p.mkdir()
parts=[]
for name,fn,start in [('Run','TBRun','   // Step 1: Save files'),('Debug','TBDebugRun','   // Step 1: Save user code')]:
 a=s.index(start,s.index('static function '+fn+'('));b=s.index('   if ! HB_StageFramework( cProjDir',a)
 parts.append('function Probe'+name+'(cBuildDir)\n local cLog:=\'\', i\n'+s[a:b]+''' nContinued++
return .T.
''')
main='''static aForms := {{'Form1',nil,'FORMNEW'}}
static aModules := {{'Helpers','OLD',''}}
static hCodeEditor := 0
static nContinued := 0
function Main()
 local nFail:=0, cRoot:='/tmp/build-write-refusal/', cStage, cBad, lResult
 for each cStage in {'run','debug'}
 for each cBad in iif(cStage=='run',{'Project1.prg','Form1.prg','Helpers.prg'},{'Project1.prg','Form1.prg'})
 FErase(cRoot+cStage+'/Project1.prg')
 FErase(cRoot+cStage+'/Form1.prg')
 FErase(cRoot+cStage+'/Helpers.prg')
 DirRemove(cRoot+cStage+'/Project1.prg')
 DirRemove(cRoot+cStage+'/Form1.prg')
 DirRemove(cRoot+cStage+'/Helpers.prg')
 hb_DirCreate(cRoot+cStage+'/'+cBad)
 nContinued:=0
 lResult:=iif(cStage=='run',ProbeRun(cRoot+cStage),ProbeDebug(cRoot+cStage))
 if lResult.or.nContinued!=0; nFail++; endif
 DirRemove(cRoot+cStage+'/'+cBad)
 next
 next
 nContinued:=0
 if !ProbeRun(cRoot+'run').or.nContinued!=1; nFail++; endif
 nContinued:=0
 if !ProbeDebug(cRoot+'debug').or.nContinued!=1; nFail++; endif
 for each cBad in {'main.prg','debug_main.prg'}
 hb_DirCreate(cRoot+cBad)
 if HB_BuildWrite(cRoot+cBad,'NEW'); nFail++; endif
 DirRemove(cRoot+cBad)
 next
 MemoWrit(cRoot+'old.prg','OLD')
 if HB_BuildWrite(cRoot+'missing/sub/old.prg','NEW'); nFail++; endif
 if !(MemoRead(cRoot+'old.prg')=='OLD'); nFail++; endif
 QOut('BUILD write refusal cases=8 positive=2 failures='+hb_ntos(nFail))
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
a=s.index('static function HB_BuildWrite(');b=s.index('static function HB_StageFramework',a)
(p/'probe.prg').write_text(main+''.join(parts)+s[a:b])
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
