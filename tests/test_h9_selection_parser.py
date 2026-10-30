#!/usr/bin/env python3
"""Execute actual Mac Value parser with deterministic control handles."""
import pathlib,subprocess,sys
r=pathlib.Path(__file__).resolve().parents[1]; platform=sys.argv[1] if len(sys.argv)>1 else 'macos'; s=(r/f'source/hbbuilder_{platform}.prg').read_text();a=s.index('static function RestoreSelectionAssignment');b=s.index('static function RestoreFormFromCode',a);parser=s[a:b].split("static function PictureExprEval")[0]
p=pathlib.Path('/tmp/h9-selection');p.mkdir(exist_ok=True)
main='''static aSelectionParseBlocks := {}
static aWrites := {}
static nMessages := 0
function Main()
 local nFail := 0
 RestoreSelectionAssignment(100,'::oCOMBO:Value := 2')
 if Len(aWrites) != 1 .or. aWrites[1][1] != 11 .or. aWrites[1][2] != 2; nFail++; endif
 RestoreSelectionAssignment(100,'::oList:Value := 0')
 if Len(aWrites) != 2 .or. aWrites[2][1] != 22 .or. aWrites[2][2] != 0; nFail++; endif
 RestoreSelectionAssignment(100,'::oCombo:Value := 2x')
 RestoreSelectionAssignment(100,'::oCombo:Value := 1+1')
 RestoreSelectionAssignment(100,'::oMissing:Value := 2')
 if Len(aWrites) != 2 .or. Len(aSelectionParseBlocks) != 3; nFail++; endif
 if SelectionParseAllowed(100,.T.); nFail++; endif
 if nMessages != 0; nFail++; endif
 if SelectionParseAllowed(100); nFail++; endif
 if nMessages != 1; nFail++; endif
 QOut('H9 SELECTION PARSER failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function UI_GetChildCount(h)
 HB_SYMBOL_UNUSED(h)
return 2
function UI_GetChild(h,i)
 HB_SYMBOL_UNUSED(h)
return iif(i==1,11,22)
function UI_GetProp(h,p)
 HB_SYMBOL_UNUSED(p)
return iif(h==11,'Combo','List')
function UI_GetType(h)
return iif(h==11,5,7)
function UI_SetProp(h,p,v)
 HB_SYMBOL_UNUSED(p)
 AAdd(aWrites,{h,v})
return nil
function MsgInfo(t,title)
 HB_SYMBOL_UNUSED(title)
 nMessages++
 QOut(t)
return nil
'''
(p/'probe.prg').write_text(main+parser)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
