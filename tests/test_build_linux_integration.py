#!/usr/bin/env python3
"""Exercise build_linux.sh with fake compilers/pkg-config, not a native build."""
from pathlib import Path
import tempfile, shutil, subprocess, os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as d:
    tmp=Path(d); repo=tmp/'project space'; tools=tmp/'tools'; hb=tmp/'harbour'
    tools.mkdir(); (hb/'bin').mkdir(parents=True); (hb/'include').mkdir()
    for f in ['build_linux.sh','scripts/build_cache.sh','source/hbbuilder_linux.prg',
              'source/hbbuilder_common.prg','source/core/classes.prg','source/inspector/inspector_gtk.prg',
              'include/hbbuilder.ch','include/hbide.ch','source/backends/gtk3/gtk3_core.c',
              'source/backends/gtk3/gtk3_inspector.c','source/backends/gtk3/gtk3_db_real.c']:
        dst=repo/f;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy(root/f,dst)
    (repo/'resources').mkdir()
    for f in ['libscintilla.so','liblexilla.so']: (repo/'resources'/f).touch()
    compiler='''#!/usr/bin/env python3
import sys,os,pathlib
args=sys.argv[1:]
with open(os.environ['COMPILE_LOG'],'a') as f:f.write(' '.join(args)+'\\n')
out=None
for i,a in enumerate(args):
 if a=='-o':out=args[i+1]
 elif a.startswith('-o'):out=a[2:]
if out:pathlib.Path(out).write_text('fake build output')
'''
    for f in [tools/'gcc',hb/'bin/harbour']:
        f.write_text(compiler);f.chmod(0o755)
    pc=tools/'pkg-config'
    pc.write_text('''#!/bin/sh
case "$*" in
 *webkit2gtk-4.1*) [ "$TEST_WEBKIT" = on ] || exit 1; case "$1" in --cflags) echo -I/fake/webkit;; --libs) echo -lwebkit-test;; esac;;
 *webkit2gtk-4.0*) exit 1;;
 *gtk+-3.0*) case "$1" in --cflags) echo -I/fake/gtk;; --libs) echo -lgtk-test;; esac;;
esac
''');pc.chmod(0o755)
    log=tmp/'compile.log'
    env=dict(os.environ,PATH=str(tools)+':'+os.environ['PATH'],HBDIR=str(hb),COMPILE_LOG=str(log))
    def build(webkit):
        env['TEST_WEBKIT']=webkit;log.write_text('')
        subprocess.run(['bash',str(repo/'build_linux.sh')],env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        return log.read_text().splitlines()
    assert any('gtk3_core.c' in x for x in build('off'))
    assert not build('off'), 'unchanged build should use cache'
    assert any('gtk3_core.c' in x and '-DHAVE_WEBKIT2GTK' in x for x in build('on'))
    assert not build('on'), 'unchanged WebKit build should use cache'
    assert any('gtk3_core.c' in x and '-DHAVE_WEBKIT2GTK' not in x for x in build('off'))
    print('PASS: actual build script invalidates GTK core with WebKit off -> on -> off, path with spaces')
