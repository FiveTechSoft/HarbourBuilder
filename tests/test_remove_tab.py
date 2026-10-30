#!/usr/bin/env python3
from pathlib import Path
import tempfile,subprocess
r=Path(__file__).resolve().parents[1];s=(r/'source/backends/gtk3/gtk3_core.c').read_text();a=s.index('HB_FUNC( CODEEDITORREMOVETAB )');b=s.index('/* CodeEditorGetActiveTab',a)
pre=r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#define CE_MAX_TABS 32
#define HB_FUNC(n) void n(void)
#define HB_PTRUINT uintptr_t
#define HB_ISCHAR(n) 1
#define G_SIGNAL_MATCH_FUNC 0
#define GTK_ORIENTATION_HORIZONTAL 0
#define GTK_NOTEBOOK(n) (n)
typedef void GtkWidget;
typedef void *gpointer;
typedef struct {void *tabBar;void *sciWidget;int bSettingText;int nTabs,nActiveTab;char tabNames[32][64];char *tabTexts[32];} CODEEDITOR;
static CODEEDITOR ed;
static int pos,ret,saved,gtk;
#define SCI_SETTEXT 1
#define SCI_EMPTYUNDOBUFFER 2
static char visible[64];
#define SciMsg(w,m,a,b) ((m)==SCI_SETTEXT ? (strcpy(visible,(const char *)(b)),0) : 0)
#define gtk_notebook_remove_page(...) (gtk++)
static uintptr_t hb_parnint(int n){return (uintptr_t)&ed;}
static int hb_parni(int n){return pos;}
static const char *hb_parc(int n){return "Inserted";}
static void hb_retl(int n){ret=n;}
static void SaveCurrentTabText(CODEEDITOR *e){saved++;free(e->tabTexts[e->nActiveTab]);e->tabTexts[e->nActiveTab]=strdup("LIVE-EDIT");}
static void on_editor_tab_switched(void){}
#define g_signal_handlers_block_matched(...) (gtk++)
#define g_signal_handlers_unblock_matched(...) (gtk++)
static void *gtk_box_new(int a,int b){return (void*)1;}
static void *gtk_label_new(const char *n){return (void*)1;}
#define gtk_notebook_insert_page(...) (gtk++)
#define gtk_widget_show_all(...) (gtk++)
#define gtk_notebook_set_current_page(...) (gtk++)

'''
post=r'''
int main(void){
 int active,removed,i,expected;
 for(active=0;active<5;active++)for(removed=0;removed<5;removed++){
  memset(&ed,0,sizeof(ed));ed.tabBar=ed.sciWidget=(void*)1;ed.nTabs=5;ed.nActiveTab=active;saved=0;
  for(i=0;i<5;i++){sprintf(ed.tabNames[i],"Tab%d",i);ed.tabTexts[i]=strdup(ed.tabNames[i]);}
  pos=removed+1;CODEEDITORREMOVETAB();
  expected=active>removed?active-1:active==removed?(removed>0?removed-1:0):active;
  if(ed.nTabs!=4||ed.nActiveTab!=expected||saved!=1)return 1;
  if(active!=removed&&strcmp(visible,"LIVE-EDIT"))return 2;
  if(strcmp(visible,ed.tabTexts[expected]))return 3;
  for(i=0;i<4;i++)free(ed.tabTexts[i]);
 }
 puts("REMOVE actual C 25 active/removal pairs: live buffer saved, logical selection and rendered text agree");return 0;
}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'p.c').write_text(pre+s[a:b]+post);subprocess.run(['gcc','-w',str(p/'p.c'),'-o',str(p/'p')],check=True);raise SystemExit(subprocess.run([str(p/'p')]).returncode)
