#!/usr/bin/env python3
"""Actual main.c status branch with real GCC warning, error and silent failure."""
from pathlib import Path
import subprocess,shutil
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();p=Path('/tmp/build-warning-probe');shutil.rmtree(p,ignore_errors=True);p.mkdir()
(p/'warning.c').write_text('#warning harmless compiler diagnostic\nint sample(void){return 0;}\n')
(p/'error.c').write_text('this is invalid C;\n')
a=s.index('      if ! HB_BuildExec( cCmd, @cOutput )',s.index('cLog += "[5] Compiling C sources..."'));b=s.index('      if ! lError\n',a);branch=s[a:b]
a=s.index('static function HB_BuildExec');b=s.index('static function TBRun',a);helper=s[a:b]
main='''function Main()
 local nFail:=0
 if Probe('gcc -c /tmp/build-warning-probe/warning.c -o /tmp/build-warning-probe/warning.o 2>&1'); nFail++; endif
 if !Probe('gcc -c /tmp/build-warning-probe/error.c -o /tmp/build-warning-probe/error.o 2>&1'); nFail++; endif
 if !Probe('exit 7'); nFail++; endif
 QOut('BUILD WARNING real GCC failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function Probe(cCmd)
 local cOutput:='',cLog:='',lError:=.F.
'''+branch+''' QOut(cLog)
return lError
function GTK_ShellExec(c,nExit)
 local out:='',err:=''
 nExit:=hb_processRun('/bin/sh -c '+Chr(34)+c+Chr(34),,@out,@err)
return out+err
'''
(p/'probe.prg').write_text(main+helper)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
