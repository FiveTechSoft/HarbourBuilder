#!/usr/bin/env python3
"""Compile actual platform emitter branches with a tiny property backend.
No native UI or full IDE roundtrip claim. Branches are copied at run time,
not reimplemented; backend calls below only return supplied model values.
"""
import pathlib, subprocess, tempfile, os
root=pathlib.Path(__file__).resolve().parents[1]
def branch(platform,start,end):
 s=(root/f'source/hbbuilder_{platform}.prg').read_text();s=s[s.index('static function RegenerateFormCode'):]
 a=s.index(start); b=s.index(end,a); return s[a:b]
maccombo=branch('macos','            case nType == 5  // ComboBox','            case nType == 6  // GroupBox')
maclist=branch('macos','            case nType == 7  // ListBox','            case nType == 8  // RadioButton')
winpic=branch('win','            case nType == 12  // BitBtn','            case nType == 14  // Image')
winimage=branch('win','            case nType == 14  // Image','            case nType == 15  // Shape')
macradio=branch('macos','            case nType == 8  // RadioButton','            case nType == 12  // BitBtn')
winradio=branch('win','            case nType == 8  // RadioButton','            case nType == 12  // BitBtn')
pre='''#include "hbide.ch"
static nFails := 0
static nSelection := 2
static cPicture := "icon.png"
static lChecked := .T.
function Main()
 local c, path
 c := EmitMac(5)
 Check('Mac Combo Value 2', '::oProbe:Value := 2' $ c)
 c := EmitMac(7)
 Check('Mac List Value 2', '::oProbe:Value := 2' $ c)
 c := EmitWin(12)
 Check('Win BitBtn picture', ('PICTURE ' + HB_QHarbourStr('icon.png')) $ c)
 c := EmitWin(14)
 Check('Win Image picture', ('PICTURE ' + HB_QHarbourStr('icon.png')) $ c)
 nSelection := 0
 Check('Mac Combo deselection', '::oProbe:Value := 0' $ EmitMac(5))
 Check('Mac List deselection', '::oProbe:Value := 0' $ EmitMac(7))
 lChecked := .T.
 Check('Mac Radio checked', ' CHECKED' $ EmitMac(8))
 Check('Win Radio checked', ' CHECKED' $ EmitWin(8))
 lChecked := .F.
 Check('Mac Radio unchecked', !(' CHECKED' $ EmitMac(8)))
 Check('Win Radio unchecked', !(' CHECKED' $ EmitWin(8)))
 for each path in {' ', 'a"b.png', 'dir/file with spaces.png', 'line'+Chr(10)+'break'}
    cPicture := path
    Check('Win BitBtn quoted path', ('PICTURE '+HB_QHarbourStr(path)) $ EmitWin(12))
    Check('Win Image quoted path', ('PICTURE '+HB_QHarbourStr(path)) $ EmitWin(14))
 next
 QOut('H9 EMITTER failures=' + hb_ntos(nFails))
 ErrorLevel(nFails)
return nil
function Check(label,ok)
 QOut(iif(ok,'PASS: ','FAIL: ')+label)
 if !ok; nFails++; endif
return nil
'''
locals=''' local cCreate := '', e := Chr(10), cCtrlName := 'Probe', cParent := 'Self'
 local nT := 10, nL := 10, nCW := 120, nCH := 30, hCtrl := 1
 local cVal, aHdrs, kk, nColCount, nVal, cText := 'Probe'
'''
post='''function UI_GetProp(h,p)
 HB_SYMBOL_UNUSED(h)
 do case
 case p == 'nItemIndex'; return nSelection
 case p == 'lChecked'; return lChecked
 case p == 'cPicture'; return cPicture
 case p == 'aItems'; return 'Uno|Dos'
 endcase
return nil
function UI_ComboGetCount(h)
 HB_SYMBOL_UNUSED(h)
return 2
function UI_ComboGetItem(h,n)
 HB_SYMBOL_UNUSED(h)
return iif(n==1,'Uno','Dos')
'''
src=pre+'function EmitMac(nType)\n'+locals+' do case\n'+maccombo+maclist+macradio+' endcase\nreturn cCreate\n'+'function EmitWin(nType)\n'+locals+' do case\n'+winradio+winpic+winimage+' endcase\nreturn cCreate\n'+post
out=pathlib.Path('/tmp/h9-emitter');out.mkdir(exist_ok=True);(out/'probe.prg').write_text(src)
hb=pathlib.Path(os.environ.get('HBDIR','/tmp/harbour-review'))
cmd=[str(hb/'bin/linux/gcc/hbmk2'),str(out/'probe.prg'),str(root/'source/hbbuilder_common.prg'),str(root/'tests/messages_stubs.prg'),'-I'+str(root/'include'),'-gtstd','-quiet','-q','-o'+str(out/'probe')]
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),flush=True)
subprocess.run(cmd,check=True)
raise SystemExit(subprocess.run([str(out/'probe')]).returncode)
