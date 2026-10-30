#!/usr/bin/env python3
"""Execute extracted EnsureHarbour with an isolated fake source/make installation.
GTK prompts/progress are stubs; shell assignment and process exit are real.
No download or real compiler build is performed.
"""
from pathlib import Path
import subprocess,tempfile,os
r=Path(__file__).resolve().parents[1]
s=(r/'source/hbbuilder_linux.prg').read_text()
a=s.index('static function EnsureHarbour(');b=s.index('// Staging is not a save:',a)
body=s[a:b]
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
with tempfile.TemporaryDirectory(prefix='hb-install-probe-') as t:
 p=Path(t);src=p/'source';(src/'config').mkdir(parents=True);(src/'config/global.mk').write_text('fixture')
 bindir=p/'tools';bindir.mkdir();prefix=p/'home with spaces'/'harbour'
 make=bindir/'make';make.write_text('#!/bin/sh\nprintf "%s" "$HB_INSTALL_PREFIX" > "$INSTALL_RECORD"\n[ -n "$HB_INSTALL_PREFIX" ] || exit 7\nmkdir -p "$HB_INSTALL_PREFIX/bin"\ntouch "$HB_INSTALL_PREFIX/bin/harbour"\n');make.chmod(0o755)
 # Only replace the fixed source location to avoid touching /tmp/harbour-src.
 body=body.replace('"/tmp/harbour-src"','"'+str(src)+'"')
 main='''function Main(cPrefix)
 local ok:=EnsureHarbour(cPrefix)
 QOut("ENSURE_RESULT="+if(ok,"TRUE","FALSE"))
 ErrorLevel(if(ok,0,1))
return nil
function UI_MsgYesNo(a,b)
return .T.
function GTK_ProgressOpen(a,b)
return nil
function GTK_ProgressClose()
return nil
function MsgInfo(a,b)
 QOut(a)
return nil
function GTK_BuildErrorDialog(a,b)
 QOut(a+":"+b)
return nil
function GTK_ShellExec(c)
 local out:='',err:='',script:=hb_GetEnv('PROBE_SCRIPT')
 hb_MemoWrit(script,c)
 hb_processRun('/bin/sh '+script,,@out,@err)
return out+err
'''
 (p/'probe.prg').write_text(main+body)
 subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
 env=dict(os.environ,PATH=str(bindir)+':'+os.environ['PATH'],INSTALL_RECORD=str(p/'record'),PROBE_SCRIPT=str(p/'shell.sh'))
 z=subprocess.run([str(p/'probe'),str(prefix)],env=env,text=True,capture_output=True)
 print(z.stdout);print('probe_exit',z.returncode)
 actual=(p/'record').read_text() if (p/'record').exists() else '<make never ran>'
 print('expected_prefix',str(prefix));print('actual_prefix',actual);print('prefix_exact',actual==str(prefix));print('compiler_exists',(prefix/'bin/harbour').exists())
 raise SystemExit(0 if z.returncode==0 and actual==str(prefix) and (prefix/'bin/harbour').exists() else 1)
