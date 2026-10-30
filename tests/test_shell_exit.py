#!/usr/bin/env python3
"""Execute the actual GTK_ShellExec C body with real child process statuses.
GTK presentation calls and Harbour value transport are recording stubs only.
"""
from pathlib import Path
import subprocess, tempfile
r=Path(__file__).resolve().parents[1]
s=(r/'source/backends/gtk3/gtk3_core.c').read_text()
a=s.index('HB_FUNC( GTK_SHELLEXEC )'); b=s.index('/* GTK_OpenFileDialog',a)
body=s[a:b]
pre=r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/wait.h>
#define HB_FUNC(n) void n(void)
#define HB_ISCHAR(n) 1
#define FALSE 0
static const char *cmd;
static char output[4096];
static int result=999,s_progressCancelled=0,s_progressBar=0,s_progressSteps=0;
static const char *hb_parc(int n){return cmd;}
static void hb_retc(const char *t){snprintf(output,sizeof(output),"%s",t);}
static void hb_storni(int status,int n){result=status;}
static void ProgressLogAppend(const char*t,int n){}
static int gtk_events_pending(void){return 0;}
static void gtk_main_iteration_do(int n){}
static void g_usleep(int n){usleep(n);}
static void gtk_progress_bar_pulse(int n){}
#define GTK_PROGRESS_BAR(x) x
'''
post=r'''
int main(void){
 int fail=0;
 cmd="printf OK; exit 0"; GTK_SHELLEXEC();
 if(result!=0 || strcmp(output,"OK")){printf("FAIL success status=%d output=%s\n",result,output);fail++;}
 result=999;cmd="exit 7"; GTK_SHELLEXEC();
 if(result!=7 || output[0]){printf("FAIL silent exit status=%d output=%s\n",result,output);fail++;}
 result=999;cmd="printf warning; exit 0"; GTK_SHELLEXEC();
 if(result!=0 || strcmp(output,"warning")){printf("FAIL warning status=%d\n",result);fail++;}
 result=999;cmd="kill -TERM $$"; GTK_SHELLEXEC();
 if(result!=143){printf("FAIL signal status=%d\n",result);fail++;}
 result=999;s_progressCancelled=1;cmd="exit 0"; GTK_SHELLEXEC();
 if(result!=130){printf("FAIL cancelled status=%d\n",result);fail++;}
 printf("SHELL EXIT actual C body failures=%d\n",fail);return fail;
}
'''
print('commit:',subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'probe.c').write_text(pre+body+post)
 subprocess.run(['gcc','-w',str(p/'probe.c'),'-o',str(p/'probe')],check=True)
 raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
