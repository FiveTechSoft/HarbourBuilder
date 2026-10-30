#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv){
    if(argc<2){fprintf(stderr,"usage: wmdel <winid>\n");return 2;}
    Display *d=XOpenDisplay(NULL);
    if(!d){fprintf(stderr,"no display\n");return 1;}
    Window w=(Window)strtoul(argv[1],NULL,10);
    Atom protocols=XInternAtom(d,"WM_PROTOCOLS",False);
    Atom del=XInternAtom(d,"WM_DELETE_WINDOW",False);
    XEvent ev; ev.xclient.type=ClientMessage; ev.xclient.window=w;
    ev.xclient.message_type=protocols; ev.xclient.format=32;
    ev.xclient.data.l[0]=del; ev.xclient.data.l[1]=CurrentTime;
    ev.xclient.data.l[2]=0; ev.xclient.data.l[3]=0; ev.xclient.data.l[4]=0;
    ev.xclient.serial=0; ev.xclient.send_event=True; ev.xclient.display=d;
    XSendEvent(d,w,False,NoEventMask,&ev);
    XFlush(d); XCloseDisplay(d);
    return 0;
}
