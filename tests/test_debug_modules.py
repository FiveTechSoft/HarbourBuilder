#!/usr/bin/env python3
"""Execute actual Debug assembly between Project1 and framework sections."""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('   // Project1.prg —',s.index('static function TBDebugRun'));b=s.index('   // classes.prg (framework',a)
src='''static aForms := {{'Form1',nil,''}}
static aModules := {{'Helpers','OLD',''}}
static aDbgOffsets := {}
function Main()
 local nCurLine:=7, cAllPrg:='', cMainPrg, cSection, cBuildDir:='/tmp/h9-debug-modules', i, nFail:=0
 MemoWrit(cBuildDir+'/Form1.prg','FORMMARK')
'''+s[a:b]+''' if !('NEWMODULE' $ cAllPrg); nFail++; endif
 if 'OLD' $ cAllPrg; nFail++; endif
 if Len(aDbgOffsets)!=3
 nFail++
 else
 if !(aDbgOffsets[3][2]=='Helpers.prg').or.aDbgOffsets[3][3]!=3; nFail++; endif
 endif
 QOut('DEBUG MODULE failures='+hb_ntos(nFail))
 QOut(cAllPrg)
 ErrorLevel(nFail)
return nil
function CodeEditorGetTabText(h,t)
 HB_SYMBOL_UNUSED(h)
return iif(t==1,'MAINMARK',iif(t==3,'NEWMODULE','FORMMARK'))
function NumLines(c)
return Len(hb_ATokens(c,Chr(10)))
'''
src='static hCodeEditor := 0\n'+src
p=pathlib.Path('/tmp/h9-debug-modules');p.mkdir(exist_ok=True);(p/'probe.prg').write_text(src)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
