#!/usr/bin/env python3
"""Actual insert C body, recording GTK stubs: capacity refusal and array ownership."""
from pathlib import Path
import tempfile,subprocess
r=Path(__file__).resolve().parents[1];s=(r/'source/backends/gtk3/gtk3_core.c').read_text();a=s.index('HB_FUNC( CODEEDITORINSERTTAB )');b=s.index('/* CodeEditorSetTabText',a)
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
typedef struct {void *tabBar;int nTabs,nActiveTab;char tabNames[32][64];char *tabTexts[32];} CODEEDITOR;
static CODEEDITOR ed;
static int pos,ret,saved,gtk;
static uintptr_t hb_parnint(int n){return (uintptr_t)&ed;}
static int hb_parni(int n){return pos;}
static const char *hb_parc(int n){return "Inserted";}
static void hb_retl(int n){ret=n;}
static void SaveCurrentTabText(CODEEDITOR *e){saved++;}
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
 int i;char *old[32];
 ed.tabBar=(void*)1;ed.nTabs=32;ed.nActiveTab=30;
 for(i=0;i<32;i++){sprintf(ed.tabNames[i],"Tab%d",i);old[i]=ed.tabTexts[i]=strdup(ed.tabNames[i]);}
 pos=3;CODEEDITORINSERTTAB();
 if(ret||saved||gtk||ed.nTabs!=32||ed.nActiveTab!=30)return 1;
 for(i=0;i<32;i++)if(ed.tabTexts[i]!=old[i])return 2;
 free(ed.tabTexts[31]);ed.tabTexts[31]=NULL;ed.nTabs=31;
 CODEEDITORINSERTTAB();
 if(!ret||saved!=1||ed.nTabs!=32||ed.nActiveTab!=31||strcmp(ed.tabNames[2],"Inserted"))return 3;
 for(i=0;i<31;i++)if(ed.tabTexts[i+(i>=2)]!=old[i])return 4;
 for(i=0;i<32;i++)free(ed.tabTexts[i]);
 puts("INSERT actual C capacity refusal no mutation; pointer shift and active index preserved");return 0;
}
'''
with tempfile.TemporaryDirectory() as t:
 p=Path(t);(p/'p.c').write_text(pre+s[a:b]+post);subprocess.run(['gcc','-Wall','-Wno-unused-function',str(p/'p.c'),'-o',str(p/'p')],check=True);raise SystemExit(subprocess.run([str(p/'p')]).returncode)
