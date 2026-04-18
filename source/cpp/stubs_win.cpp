/* Stub implementations for functions not yet ported to Windows.
   These allow the linker to resolve symbols so the IDE can be built and tested. */

#include "hbapi.h"

HB_FUNC( UI_GETPRINTERS )     { hb_reta(0); }
HB_FUNC( UI_SHOWPRINTPANEL )  { hb_retl(0); }

HB_FUNC( RPT_PDFOPEN )        { hb_retl(0); }
HB_FUNC( RPT_PDFADDPAGE )     { hb_retl(0); }
HB_FUNC( RPT_PDFDRAWTEXT )    { hb_retl(0); }
HB_FUNC( RPT_EXPORTPDF )      { hb_retl(0); }

HB_FUNC( HIX_SETROOT )        { hb_retl(0); }
HB_FUNC( UI_HIX_SETSTATUS )   { hb_retl(0); }
HB_FUNC( UI_HIX_WRITE )       { hb_retl(0); }
HB_FUNC( HIX_EXECPRG )        { hb_retl(0); }
HB_FUNC( HIX_SERVESTATIC )    { hb_retl(0); }
