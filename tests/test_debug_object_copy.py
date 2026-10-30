#!/usr/bin/env python3
"""Compile actual Debug Inspector-object copy statement with disk failures."""
import pathlib,subprocess,shutil
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();p=pathlib.Path('/tmp/debug-object-copy');shutil.rmtree(p,ignore_errors=True);p.mkdir()
a=s.index('      GTK_ShellExec( "cp " + cProjDir + "/source/gtk3_inspector.o',s.index('static function TBDebugRun')) if 'static function HB_BuildCopy' not in s else s.index('      if ! HB_BuildCopy( cProjDir',s.index('static function TBDebugRun'));b=s.index('      if ! File( cBuildDir + "/dbghook.o"',a)
stmt=s[a:b]
main='''static nContinued:=0
function Main()
 local nFail:=0
 if Probe('/tmp/debug-object-copy/repo','/tmp/debug-object-copy/build'); nFail++; endif
 if nContinued!=0; nFail++; endif
 QOut('DEBUG object copy failures='+hb_ntos(nFail)+' continued='+hb_ntos(nContinued))
 ErrorLevel(nFail)
return nil
function Probe(cProjDir,cBuildDir)
'''+stmt+''' nContinued++
return .T.
function GTK_ShellExec(c)
 local out:='',err:=''
 hb_processRun(c,,@out,@err)
return out+err
function MsgInfo(t,title)
 HB_SYMBOL_UNUSED(title)
 QOut(t)
return nil
'''
(p/'repo/source').mkdir(parents=True);(p/'repo/source/gtk3_inspector.o').write_bytes(b'NEW\0OBJ');(p/'build/gtk3_inspector.o').mkdir(parents=True)
helper=''
if 'static function HB_BuildCopy' in s:
 a=s.index('static function HB_BuildCopy');b=s.index('static function TBRun',a);helper=s[a:b]
(p/'probe.prg').write_text(main+helper)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
