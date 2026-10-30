from pathlib import Path
import subprocess
r=Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();a=s.index('static function HB_WriteOpenFile');b=s.index('// .T. when every modified File>Open',a)
main='''static aOpenFiles:={}
function Main()
 local cFile:="/tmp/openfile-write-unit-owned.prg",cBase:="BASE"+Chr(13)+Chr(10)+Chr(26),nFail:=0
 aOpenFiles:={{"unit",cBase,cFile}}
 hb_MemoWrit(cFile,"EXTERNAL")
 if HB_WriteOpenFile(1,"EDIT");nFail++;endif
 if !(hb_MemoRead(cFile)=="EXTERNAL").or.!(aOpenFiles[1][2]==cBase);nFail++;endif
 FErase(cFile)
 if HB_WriteOpenFile(1,"EDIT");nFail++;endif
 if File(cFile).or.!(aOpenFiles[1][2]==cBase);nFail++;endif
 hb_MemoWrit(cFile,cBase)
 if !HB_WriteOpenFile(1,"EDIT"+Chr(10));nFail++;endif
 if !(hb_MemoRead(cFile)=="EDIT"+Chr(10)).or.!(aOpenFiles[1][2]=="EDIT"+Chr(10));nFail++;endif
 if !HB_WriteOpenFile(1,"SECOND");nFail++;endif
 if !(hb_MemoRead(cFile)=="SECOND");nFail++;endif
 QOut("OPENFILE raw baseline CRLF EOF conflict/missing/recovery/repeatedwrite failures="+hb_ntos(nFail))
 ErrorLevel(nFail)
return nil
function MsgInfo(c,t)
 HB_SYMBOL_UNUSED(t)
 QOut(c)
return nil
'''
p=Path('/tmp/openfile_write_unit.prg');p.write_text(main+s[a:b]);print('commit='+subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p),'-gtstd','-q','-quiet','-o/tmp/openfile_write_unit'],check=True);raise SystemExit(subprocess.run(['/tmp/openfile_write_unit']).returncode)
