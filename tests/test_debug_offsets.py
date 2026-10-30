#!/usr/bin/env python3
"""Compile real Debug header/assembly/NumLines/callback together.
Positions are measured from the resulting bytes, not assumed ideal offsets.
UI and breakpoint lookup are recording stubs, not GUI navigation.
"""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text()
a=s.index('   cAllPrg :=',s.index('   // Header: #include + GT',s.index('static function TBDebugRun')));b=s.index('   // classes.prg (framework',a);assembly=s[a:b]
a=s.index('static function NumLines(');b=s.index('// === Debug Pause',a);numlines=s[a:b]
a=s.index('static function OnDebugPause(');b=s.index('// === Debugger ===',a);callback=s[a:b]
pre='''static aForms := {{'Form1',nil,''},{'Form2',nil,''}}
static aModules := {{'HelperA','OLD',''},{'HelperB','OLD',''}}
static aDbgOffsets := {}
static hCodeEditor := 0
static nTabGot := 0
static nLineGot := 0
static cBPFile := ''
static nBPLine := 0
function Main()
 local nCurLine, cAllPrg, cMainPrg, cSection, cBuildDir:='/tmp/debug-offsets', i, nFail:=0
 local nActual, nExpected, cMarker, nSourceLine, row
 MemoWrit(cBuildDir+'/Form1.prg','// Form1'+Chr(10)+'FORM1MARK'+Chr(10))
 MemoWrit(cBuildDir+'/Form2.prg','// Form2'+Chr(10)+Chr(10)+'FORM2MARK')
'''
post=''' for i:=1 to Len(aDbgOffsets)
 row := aDbgOffsets[i]
 cMarker := {'MAINMARK','FORM1MARK','FORM2MARK','AMARK','BMARK'}[i]
 nSourceLine := {2,2,3,3,2}[i]
 nActual := NumLines(Left(cAllPrg,At(cMarker,cAllPrg)-1))
 nExpected := row[1]+nSourceLine-row[4]
 QOut(row[2]+' recorded='+hb_ntos(row[1])+' markerActual='+hb_ntos(nActual)+' predicted='+hb_ntos(nExpected))
 if nActual!=nExpected; nFail++; endif
 cBPFile:=row[2]
 nBPLine:=nSourceLine
 if !OnDebugPause('PROBE',nActual,nil,nil).or.nTabGot!=i.or.nLineGot!=nSourceLine; nFail++; endif
 next
 QOut('ASSEMBLY measured offsets + actual callback failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function CodeEditorGetTabText(h,t)
 HB_SYMBOL_UNUSED(h)
 do case
 case t==1; return '#include "hbbuilder.ch"'+Chr(10)+'MAINMARK'
 case t==4; return '#include "hbbuilder.ch"'+Chr(10)+Chr(10)+'AMARK'+Chr(10)
 case t==5; return '#include "classes.prg"'+Chr(10)+'BMARK'
 endcase
return ''
function IDE_IsBreakpoint(f,l)
return f==cBPFile.and.l==nBPLine
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
p=pathlib.Path('/tmp/debug-offsets');p.mkdir(exist_ok=True);(p/'probe.prg').write_text(pre+assembly+post+numlines+callback)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
