#!/usr/bin/env python3
"""Actual Harbour build status wrapper, real commands via hb_processRun."""
from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text()
a=s.index('static function HB_BuildExec');b=s.index('static function TBRun',a)
main='''function Main()
 local cOutput:='', nFail:=0
 if HB_BuildExec('exit 7',@cOutput); nFail++; endif
 if !('exited 7' $ cOutput); nFail++; endif
 if !HB_BuildExec('printf warning',@cOutput); nFail++; endif
 if !(cOutput=='warning'); nFail++; endif
 if !HB_BuildExec('exit 0',@cOutput); nFail++; endif
 if Len(cOutput)!=0; nFail++; endif
 QOut('BUILD EXEC wrapper failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function GTK_ShellExec(c,nExit)
 local out:='',err:=''
 nExit:=hb_processRun('/bin/sh -c '+Chr(34)+c+Chr(34),,@out,@err)
return out+err
'''
# Every compile/link cCmd in Run and Debug must route through the checked helper.
section=s[s.index('static function TBRun'):s.index('// Step 7: Hide design form')]
assert 'GTK_ShellExec( cCmd )' not in section
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'probe.prg').write_text(main+s[a:b]);subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
 raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
