#!/usr/bin/env python3
"""Execute the actual Value method gate with an internal return and next method."""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1]
for plat in ['win','macos']:
 s=(r/f'source/hbbuilder_{plat}.prg').read_text();a=s.index('      if "METHOD CREATEFORM"',s.index('static function RestoreFormFromCode'));b=s.index('      if lInCreateForm .and.',a)
 gate=s[a:b]
 src='''function Main()
 local lInCreateForm := .F., cTrim, nFail := 0, i
 local lines := {'METHOD CreateForm()','if .F.','return nil','endif','::oList:Value := 2','METHOD Handler()','::oList:Value := GetValue()'}
 for i := 1 to Len(lines)
 cTrim := lines[i]
'''+gate+''' if i==5.and.!lInCreateForm; nFail++; endif
 if i==7.and.lInCreateForm; nFail++; endif
 next
 QOut('method gate failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
'''
 p=pathlib.Path('/tmp/h9-gate-'+plat);p.mkdir(exist_ok=True);(p/'probe.prg').write_text(src)
 print('platform:',plat,'commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
 subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),str(r/'source/hbbuilder_common.prg'),str(r/'tests/messages_stubs.prg'),'-I'+str(r/'include'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
 subprocess.run([str(p/'probe')],check=True)
