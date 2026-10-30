#!/usr/bin/env python3
"""Execute actual Debug assembly between Project1 and framework sections."""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('   // Project1.prg —',s.index('static function TBDebugRun'));b=s.index('   // classes.prg (framework',a)
src='''static aForms := {{'Form1',nil,''}}
static aModules := {{'HelperA','OLD',''},{'HelperB','OLD',''}}
static aDbgOffsets := {}
function Main()
 local nCurLine:=7, cAllPrg:=Replicate(Chr(10),6), cMainPrg, cSection, cBuildDir:='/tmp/h9-debug-modules', i, nFail:=0
 MemoWrit(cBuildDir+'/Form1.prg','FORMMARK')
'''+s[a:b]+''' if !('NEWMODULE' $ cAllPrg); nFail++; endif
 if 'OLD' $ cAllPrg; nFail++; endif
 if '#include' $ cAllPrg.or.!('MODULE2' $ cAllPrg); nFail++; endif
 if Len(aDbgOffsets)!=4
 nFail++
 else
 if !(aDbgOffsets[3][2]=='HelperA.prg').or.aDbgOffsets[3][3]!=3.or.aDbgOffsets[3][4]!=1; nFail++; endif
 if !(aDbgOffsets[4][2]=='HelperB.prg').or.aDbgOffsets[4][3]!=4.or.aDbgOffsets[4][4]!=1; nFail++; endif
 if aDbgOffsets[4][1] != aDbgOffsets[3][1]+3; nFail++; endif
 endif
 QOut('DEBUG MODULE failures='+hb_ntos(nFail))
 QOut(cAllPrg)
 ErrorLevel(nFail)
return nil
function CodeEditorGetTabText(h,t)
 HB_SYMBOL_UNUSED(h)
return iif(t==1,'MAINMARK',iif(t==3,'#include "hbbuilder.ch"'+Chr(10)+'NEWMODULE'+Chr(10)+'return nil',iif(t==4,'#include "classes.prg"'+Chr(10)+'MODULE2','FORMMARK')))
function NumLines(c)
 local n:=1,i
 for i:=1 to Len(c)
 if SubStr(c,i,1)==Chr(10); n++; endif
 next
return n
'''
src='static hCodeEditor := 0\n'+src
p=pathlib.Path('/tmp/h9-debug-modules');p.mkdir(exist_ok=True);(p/'probe.prg').write_text(src)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
