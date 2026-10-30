from pathlib import Path
import subprocess
r=Path(__file__).resolve().parents[1];s=(r/'source/backends/gtk3/gtk3_core.c').read_text();a=s.index('/* Only this owner reaps');b=s.index('static int DbgServerStart',a)
p=Path('/tmp/debug-child-test');p.mkdir(exist_ok=True)
(p/'child.c').write_text('#include <unistd.h>\n#include <signal.h>\n#include <stdlib.h>\nint main(){if(getenv("FAST"))return 0;signal(SIGTERM,SIG_IGN);sleep(20);return 0;}\n')
(p/'probe.c').write_text('''#include <glib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/socket.h>
#include <netinet/in.h>
'''+s[a:b]+'''
static int s_dbgServerFD=-1,s_dbgClientFD=-1,s_dbgState=0;
#define DBG_STOPPED 4
static int gtk_events_pending(void){return 0;}
static void gtk_main_iteration_do(int b){(void)b;}
'''+s[s.index('static int DbgServerStart( int port )'):s.index('static void DbgServerSend( const char * cmd )')]+''' 
int main(){
 int status, i; GPid owned; struct sigaction act; sigaction(SIGCHLD,NULL,&act);
 printf("SIGCHLD default=%d ignored=%d no_cldwait=%d\\n",act.sa_handler==SIG_DFL,act.sa_handler==SIG_IGN,!!(act.sa_flags&SA_NOCLDWAIT)); GError *error=NULL;
 pid_t other=fork(); if(other==0){sleep(30);_exit(0);}
 if(!DbgChildStart("/tmp/debug-child-test/child",&error))return 1;
 owned=s_dbgChildPID; g_usleep(50000);
 gint64 start=g_get_monotonic_time(); DbgChildStop();
 printf("stop_ms=%ld unrelated_alive=%d\\n",(long)((g_get_monotonic_time()-start)/1000),kill(other,0)==0);
 if(kill(other,0)!=0)return 2;
 for(i=0;i<100;i++){while(g_main_context_iteration(NULL,FALSE));g_usleep(10000);}
 errno=0;if(waitpid(owned,&status,WNOHANG)!=-1||errno!=ECHILD)return 3;
 setenv("FAST","1",1);if(!DbgChildStart("/tmp/debug-child-test/child",&error))return 4;
 g_usleep(50000);DbgChildStop();DbgChildStop();if(s_dbgChildPID)return 5;
 unsetenv("FAST");
 if(DbgChildStart("/tmp/debug-child-test/missing",&error))return 6;
 if(error){g_error_free(error);error=NULL;}
 if(DbgServerStart(0)!=0)return 7;
 setenv("FAST","1",1);if(!DbgChildStart("/tmp/debug-child-test/child",&error))return 8;
 if(DbgServerAccept(1.0)==0)return 9;DbgChildStop();
 unsetenv("FAST");if(!DbgChildStart("/tmp/debug-child-test/child",&error))return 10;
 s_dbgState=DBG_STOPPED;if(DbgServerAccept(1.0)==0)return 11;DbgChildStop();
 s_dbgState=0;if(!DbgChildStart("/tmp/debug-child-test/child",&error))return 12;
 if(DbgServerAccept(.5)==0)return 13;DbgChildStop();close(s_dbgServerFD);
 puts("PASS actual accept loop: child exits; stop flag; timeout; owned cleanup");
 kill(other,SIGTERM);waitpid(other,&status,0);
 puts("PASS owned TERM/KILL bounded; reap; already exited; duplicate cleanup; exec failure; unrelated survives");return 0;
}
''')
subprocess.run(['gcc',str(p/'child.c'),'-o',str(p/'child')],check=True)
flags=subprocess.check_output(['pkg-config','--cflags','--libs','glib-2.0'],text=True).split()
subprocess.run(['gcc','-Wall','-Wextra',str(p/'probe.c'),'-o',str(p/'probe')]+flags,check=True)
print('source_commit='+subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),flush=True)
raise SystemExit(subprocess.run([str(p/'probe')]).returncode)
