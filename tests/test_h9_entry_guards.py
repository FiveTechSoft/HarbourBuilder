#!/usr/bin/env python3
"""Compile actual entry prefixes through their parse guard, with an effect sentinel.
This proves early return before subsequent body, not native file I/O behavior.
"""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1]
src='''static nCalls := 0
static nEffects := 0
function Main()
''';parts=[]
for plat,guard in [('win','PictureParseAllowed'),('macos','PictureParseAllowed')]:
 s=(r/f'source/hbbuilder_{plat}.prg').read_text()
 for fn in ['TBSave','TBSaveAs','TBRun','TBDebugRun']:
  a=s.index('static function '+fn+'(');b=s.index(f'if ! {guard}( nil ); return .F.; endif',a)+len(f'if ! {guard}( nil ); return .F.; endif')
  prefix=s[a:b].replace('static function '+fn+'(', 'static function '+plat+'_'+fn+'(')
  parts.append(prefix+'\n nEffects++\nreturn .T.\n')
  src+=f' {plat}_{fn}()\n'
src+=''' QOut('entry guard calls='+hb_ntos(nCalls)+' post-guard effects='+hb_ntos(nEffects))
 ErrorLevel(iif(nCalls==8.and.nEffects==0,0,1))
return nil
function PictureParseAllowed(h)
 HB_SYMBOL_UNUSED(h)
 nCalls++
return .F.
function SelectionParseAllowed(h)
 HB_SYMBOL_UNUSED(h)
 nCalls++
return .F.
'''+''.join(parts)
p=pathlib.Path('/tmp/h9-guards');p.mkdir(exist_ok=True);(p/'probe.prg').write_text(src)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
