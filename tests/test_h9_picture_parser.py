#!/usr/bin/env python3
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_win.prg').read_text();a=s.index('static function RestorePictureClause');b=s.index('static function RestoreFormFromCode',a)
p=pathlib.Path('/tmp/h9-picture');p.mkdir(exist_ok=True)
main='''static aPictureParseBlocks := {}
static aWrites := {}
function Main()
 local nFail := 0, cPath := 'a"b.png'
 RestorePictureClause(100,11,'@ 1,1 BITBTN ::oB OF Self SIZE 40,20 PICTURE "icon.png"')
 RestorePictureClause(100,22,'@ 1,1 IMAGE ::oI OF Self SIZE 40,20 PICTURE '+HB_QHarbourStr(cPath))
 if Len(aWrites) != 2 .or. !(aWrites[1][2]=='icon.png') .or. !(aWrites[2][2]==cPath); nFail++; endif
 RestorePictureClause(100,11,'@ 1,1 BITBTN ::oB PICTURE GetPath()')
 RestorePictureClause(100,11,'@ 1,1 BITBTN ::oB PICTURE "unterminated')
 if Len(aWrites) != 2 .or. Len(aPictureParseBlocks) != 2; nFail++; endif
 if PictureParseAllowed(100); nFail++; endif
 QOut('H9 PICTURE PARSER failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function UI_SetProp(h,p,v)
 HB_SYMBOL_UNUSED(p)
 AAdd(aWrites,{h,v})
return nil
function MsgInfo(t,title)
 HB_SYMBOL_UNUSED(title)
 QOut(t)
return nil
'''
(p/'probe.prg').write_text(main+s[a:b]);print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),str(r/'source/hbbuilder_common.prg'),str(r/'tests/messages_stubs.prg'),'-I'+str(r/'include'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
