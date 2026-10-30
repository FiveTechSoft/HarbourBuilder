#!/usr/bin/env python3
"""Execute actual UserApp publication statement, not a rewritten copy."""
import pathlib,subprocess,shutil
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();p=pathlib.Path('/tmp/userapp-copy');shutil.rmtree(p,ignore_errors=True);p.mkdir()
a=s.index('         GTK_ShellExec( "cp " + cBuildDir + "/UserApp',s.index('static function TBRun')) if 'HB_PublishUserApp' not in s else s.index('         if ! HB_PublishUserApp(',s.index('static function TBRun'));b=s.index('\n      endif',a)
main='''static nContinued:=0
function Main()
 local nFail:=0
 if Probe('/tmp/userapp-copy/build','/tmp/userapp-copy/dest/','Program'); nFail++; endif
 if nContinued!=0; nFail++; endif
 QOut('USERAPP publication failures='+hb_ntos(nFail)+' continued='+hb_ntos(nContinued))
 ErrorLevel(nFail)
return nil
function Probe(cBuildDir,cDestDir,cAppExe)
'''+s[a:b]+'''\n nContinued++
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
(p/'build').mkdir();f=p/'build/UserApp';f.write_bytes(b'#!/bin/sh\nprintf COPIED\n');f.chmod(0o755);(p/'dest/Program').mkdir(parents=True)
helper=''
if 'static function HB_PublishUserApp' in s:
 a=s.index('static function HB_BuildCopy');b=s.index('static function TBRun',a);helper=s[a:b]
(p/'probe.prg').write_text(main+helper)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
rc=subprocess.run([str(p/'probe')]).returncode
print('source mode',oct(f.stat().st_mode&0o777),flush=True)
raise SystemExit(rc)
