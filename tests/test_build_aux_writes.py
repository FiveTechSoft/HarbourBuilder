#!/usr/bin/env python3
"""Execute actual auxiliary writes from TBRun with real disk failures."""
import pathlib,subprocess,shutil
r=pathlib.Path(__file__).resolve().parents[1];s=(r/'source/hbbuilder_linux.prg').read_text();p=pathlib.Path('/tmp/build-aux-writes');shutil.rmtree(p,ignore_errors=True);p.mkdir();(p/'.srchash').mkdir()
a=s.index('   MemoWrit( "/tmp/hbbuilder_debug_main.prg"',s.index('static function TBRun')) if '   if ! MemoWrit( "/tmp/hbbuilder_debug_main.prg"' not in s else s.index('   if ! MemoWrit( "/tmp/hbbuilder_debug_main.prg"',s.index('static function TBRun'));b=s.index('   // Step 3:',a);diag=s[a:b].replace('/tmp/hbbuilder_debug_main.prg','/tmp/build-aux-writes/diagnostic.prg')
a=s.index('      cLastHash := cHash',s.index('      if ! HB_PublishProjectApp( cBuildDir )',s.index('   if lError\n      IDE_ShowBuildResult( "Build Failed"',s.index('static function TBRun'))));b=s.index('      GTK_ShellExec( cBuildDir + "/UserApp',a);cache=s[a:b]
main='''function Main()
 local cLog:='', cAllPrg:='NEW', cHash:='CURRENT', cLastHash:='OLD', cBuildDir:='/tmp/build-aux-writes', nFail:=0
'''+diag+cache+''' if !('diagnostic copy not written' $ cLog).or.!('build cache not written' $ cLog); nFail++; endif
 if Len(cLastHash)!=0; nFail++; endif
 QOut(cLog)
 QOut('AUX WRITE failures='+hb_ntos(nFail)+' cache='+cLastHash)
 ErrorLevel(nFail)
return nil
function IDE_SetMessages(t)
 HB_SYMBOL_UNUSED(t)
return nil
'''
(p/'diagnostic.prg').mkdir();(p/'probe.prg').write_text(main)
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
negative = subprocess.run([str(p/'probe')]).returncode
if negative:
 raise SystemExit(negative)
(p/'diagnostic.prg').rmdir();(p/'.srchash').rmdir()
positive = main.replace("if !('diagnostic copy not written' $ cLog).or.!('build cache not written' $ cLog); nFail++; endif", "if Len(cLog)!=0; nFail++; endif").replace("if Len(cLastHash)!=0; nFail++; endif", "if !(cLastHash=='CURRENT'); nFail++; endif")
(p/'probe.prg').write_text(positive)
subprocess.run(['/tmp/harbour-review/bin/linux/gcc/hbmk2',str(p/'probe.prg'),'-gtstd','-q','-quiet','-o'+str(p/'probe')],check=True)
status=subprocess.run([str(p/'probe')]).returncode
assert (p/'diagnostic.prg').read_bytes()==b'NEW'
assert (p/'.srchash').read_bytes()==b'CURRENT'
print('AUX POSITIVE exact diagnostic/cache bytes checked; exit='+str(status),flush=True)
raise SystemExit(status)
