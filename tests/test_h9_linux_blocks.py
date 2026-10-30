#!/usr/bin/env python3
"""Compile real Linux refusal storage and project guard; UI/sync are stubs."""
import pathlib,subprocess
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text()
a=s.index('static function HB_SetParseBlock');b=s.index('function Main()',a);storage=s[a:b]
a=s.index('static function HB_CheckFormsSerializable');b=s.index('static function TBSave()',a);guard=s[a:b]
main='''#include "hbclass.ch"
static s_aParseBlocked := {}
static aForms := {}
static nActiveForm := 0
static s_aUnserializable := {}
static s_cUnidentClass := ""
static nRegens := 0
class Probe
 data hCpp init 100
endclass
function Main()
 local nFail := 0, o := Probe():New()
 aForms := {{'Form1',o}}
 HB_SetParseBlock(100,'old')
 HB_SetParseBlock(100,'new')
 if Len(s_aParseBlocked)!=1.or.!(HB_ParseBlockFor(100)=='new'); nFail++; endif
 if HB_CheckFormsSerializable().or.nRegens!=0; nFail++; endif
 HB_ClearParseBlock(100)
 if !Empty(HB_ParseBlockFor(100)).or.Len(s_aParseBlocked)!=0; nFail++; endif
 if !HB_CheckFormsSerializable().or.nRegens!=1; nFail++; endif
 nActiveForm:=1
 HB_SetParseBlock(100,'active')
 if HB_CheckFormsSerializable(); nFail++; endif
 HB_ClearParseBlock(100)
 if !HB_CheckFormsSerializable(); nFail++; endif
 QOut('REAL Linux block storage+project guard failures='+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function SyncDesignerToCode(l)
 HB_SYMBOL_UNUSED(l)
return nil
function RegenerateFormCode(n,h)
 HB_SYMBOL_UNUSED(n)
 HB_SYMBOL_UNUSED(h)
 nRegens++
return ''
function MsgInfo(t,title)
 HB_SYMBOL_UNUSED(title)
 QOut(t)
return nil
'''
p=pathlib.Path('/tmp/h9-linux-blocks');p.mkdir(exist_ok=True);(p/'probe.prg').write_text(main+storage+guard)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
subprocess.run([str(p/'probe')],check=True)
