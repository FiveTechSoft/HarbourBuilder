#!/usr/bin/env python3
"""Execute real OnDebugPause with seeded breakpoint and recording UI stubs.
Not a GUI navigation test and not a test of the breakpoint menu placeholder.
"""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function OnDebugPause(');b=s.index('// === Debugger ===',a)
src='''static aDbgOffsets := {{7,'Project1.prg',1,1},{20,'Form1.prg',2,2},{109,'HelperA.prg',3,1},{115,'HelperB.prg',4,1},{120,'classes.prg',0,0}}
static hCodeEditor := 0
static nTabGot := 0
static nLineGot := 0
static nBpTab := 3
function Main()
 local nFail := 0
 if !OnDebugPause('HELPERA',111,nil,nil).or.nTabGot!=3.or.nLineGot!=3; nFail++; endif
 nBpTab := 4
 if !OnDebugPause('HELPERB',116,nil,nil).or.nTabGot!=4.or.nLineGot!=2; nFail++; endif
 if OnDebugPause('FRAMEWORK',121,nil,nil); nFail++; endif
 QOut('REAL CALLBACK seeded BP map failures='+hb_ntos(nFail)+' lastTab='+hb_ntos(nTabGot)+' lastLine='+hb_ntos(nLineGot))
 ErrorLevel(nFail)
return nil
function IDE_IsBreakpoint(f,l)
return (nBpTab==3.and.f=='HelperA.prg'.and.l==3).or.(nBpTab==4.and.f=='HelperB.prg'.and.l==2)
function IDE_DbgIsStepping()
return .F.
function CodeEditorSelectTab(h,t)
 HB_SYMBOL_UNUSED(h)
 nTabGot:=t
return nil
function CodeEditorShowDebugLine(h,l)
 HB_SYMBOL_UNUSED(h)
 nLineGot:=l
return nil
function DbgMapLocalNames(v,f,t)
 HB_SYMBOL_UNUSED(f)
 HB_SYMBOL_UNUSED(t)
return v
function _InsGetData()
return 0
function INS_SetDebugLocals(h,v)
 HB_SYMBOL_UNUSED(h)
 HB_SYMBOL_UNUSED(v)
return nil
function INS_SetDebugStack(h,v)
 HB_SYMBOL_UNUSED(h)
 HB_SYMBOL_UNUSED(v)
return nil
function DbgFixStackLines(v)
return v
'''
p=pathlib.Path('/tmp/debug-module-callback');p.mkdir(exist_ok=True);(p/'probe.prg').write_text(src+s[a:b])
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
subprocess.run([str(p/'probe')],check=True)
