/* Windows-specific helpers for functions not provided by Win32 backend.
   Contains:
     - Real PDF writer for report export (RPT_PDF*)
     - Stubs for features not yet ported to Windows */

#include "hbapi.h"
#include "hbapiitm.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdarg>
#include <string>
#include <vector>

HB_FUNC( UI_GETPRINTERS )     { hb_reta(0); }
HB_FUNC( UI_SHOWPRINTPANEL )  { hb_retl(0); }

HB_FUNC( HIX_SETROOT )        { hb_retl(0); }
HB_FUNC( UI_HIX_SETSTATUS )   { hb_retl(0); }
HB_FUNC( UI_HIX_WRITE )       { hb_retl(0); }
HB_FUNC( HIX_EXECPRG )        { hb_retl(0); }
HB_FUNC( HIX_SERVESTATIC )    { hb_retl(0); }

/* =====================================================================
 * Report PDF Export — native PDF 1.4 writer (no external deps)
 *
 * Coordinate contract (matches Linux/gtk3 backend):
 *   - Units are PDF points as passed by caller
 *   - Origin is top-left (screen convention); Y grows down
 *   - We flip to PDF's bottom-left origin at emit time
 *
 * Fonts: the 12 core scalable fonts from the PDF standard 14. They are
 * guaranteed to be available in every PDF viewer without embedding.
 * Encoding is WinAnsi, compatible with Harbour's default CP_ACP on Windows.
 * ===================================================================== */

static double              s_pageW = 595.0;
static double              s_pageH = 842.0;
static std::vector<std::string> s_pages;
static std::string         s_cur;
static bool                s_hasPage = false;
static bool                s_isOpen  = false;

static const char * const k_fontNames[12] = {
   "Helvetica",     "Helvetica-Bold",  "Helvetica-Oblique", "Helvetica-BoldOblique",
   "Times-Roman",   "Times-Bold",      "Times-Italic",      "Times-BoldItalic",
   "Courier",       "Courier-Bold",    "Courier-Oblique",   "Courier-BoldOblique"
};

static int pdf_family_base( const char * family )
{
   /* Map incoming family name to one of: 0 (Helvetica), 4 (Times), 8 (Courier). */
   if( !family || !*family ) return 0;
   const char * f = family;
   char lo[64]; int i = 0;
   for( ; f[i] && i < 63; i++ )
      lo[i] = (char)( (f[i] >= 'A' && f[i] <= 'Z') ? f[i] + 32 : f[i] );
   lo[i] = 0;
   if( strstr( lo, "times" ) || strstr( lo, "serif" ) || strstr( lo, "roman" ) )
      return 4;
   if( strstr( lo, "courier" ) || strstr( lo, "mono" ) || strstr( lo, "consolas" )
       || strstr( lo, "fixed" ) )
      return 8;
   return 0;
}

static int pdf_font_index( const char * family, int bold, int italic )
{
   int base = pdf_family_base( family );
   int offset = (bold ? 1 : 0) | (italic ? 2 : 0);
   return base + offset;
}

static void pdf_appendf( std::string & out, const char * fmt, ... )
{
   char buf[512];
   va_list ap;
   va_start( ap, fmt );
   int n = vsnprintf( buf, sizeof(buf), fmt, ap );
   va_end( ap );
   if( n > 0 ) out.append( buf, (size_t) ( n < (int)sizeof(buf) ? n : (int)sizeof(buf) - 1 ) );
}

static void pdf_append_escaped( std::string & out, const char * s )
{
   if( !s ) return;
   for( ; *s; s++ )
   {
      unsigned char c = (unsigned char) *s;
      if( c == '\\' || c == '(' || c == ')' ) { out.push_back( '\\' ); out.push_back( (char) c ); }
      else if( c >= 0x20 || c == '\t' )       { out.push_back( (char) c ); }
      /* control chars dropped */
   }
}

static void pdf_reset()
{
   s_pages.clear();
   s_cur.clear();
   s_hasPage = false;
   s_isOpen  = false;
}

/* RPT_PDFOPEN( nPageW, nPageH, nMarginL, nMarginR, nMarginT, nMarginB ) */
HB_FUNC( RPT_PDFOPEN )
{
   pdf_reset();
   s_pageW = HB_ISNUM(1) && hb_parnd(1) > 0 ? hb_parnd(1) : 595.0;
   s_pageH = HB_ISNUM(2) && hb_parnd(2) > 0 ? hb_parnd(2) : 842.0;
   /* margins accepted for API parity; classes.prg positions everything itself */
   s_isOpen = true;
   hb_retl(1);
}

/* RPT_PDFADDPAGE() — start a new page; flushes the in-progress one */
HB_FUNC( RPT_PDFADDPAGE )
{
   if( !s_isOpen ) { hb_retl(0); return; }
   if( s_hasPage )
   {
      s_pages.push_back( s_cur );
      s_cur.clear();
   }
   s_hasPage = true;
   hb_retl(1);
}

/* RPT_PDFDRAWRECT( nLeft, nTop, nWidth, nHeight, nColor, lFilled ) */
HB_FUNC( RPT_PDFDRAWRECT )
{
   if( !s_isOpen || !s_hasPage ) { hb_retl(0); return; }

   double x = hb_parnd(1);
   double y = hb_parnd(2);
   double w = hb_parnd(3);
   double h = hb_parnd(4);
   int    c = HB_ISNUM(5) ? hb_parni(5) : 0xFFFFFF;
   int    filled = HB_ISLOG(6) ? hb_parl(6) : 1;

   if( w <= 0 || h <= 0 ) { hb_retl(0); return; }

   double r = ( (c >> 16) & 0xFF ) / 255.0;
   double g = ( (c >>  8) & 0xFF ) / 255.0;
   double b = (  c        & 0xFF ) / 255.0;

   double pdfY = s_pageH - y - h;   /* flip Y axis */

   if( filled )
      pdf_appendf( s_cur,
         "%.3f %.3f %.3f rg\n"
         "%.2f %.2f %.2f %.2f re\n"
         "f\n",
         r, g, b, x, pdfY, w, h );
   else
      pdf_appendf( s_cur,
         "%.3f %.3f %.3f RG\n"
         "0.5 w\n"
         "%.2f %.2f %.2f %.2f re\n"
         "S\n",
         r, g, b, x, pdfY, w, h );

   hb_retl(1);
}

/* RPT_PDFDRAWTEXT( nLeft, nTop, cText, cFont, nSize, lBold, lItalic, nColor ) */
HB_FUNC( RPT_PDFDRAWTEXT )
{
   if( !s_isOpen || !s_hasPage ) { hb_retl(0); return; }

   double       x     = hb_parnd(1);
   double       y     = hb_parnd(2);
   const char * text  = HB_ISCHAR(3) ? hb_parc(3) : "";
   const char * font  = HB_ISCHAR(4) ? hb_parc(4) : "Helvetica";
   double       size  = HB_ISNUM(5) && hb_parnd(5) > 0 ? hb_parnd(5) : 10.0;
   int          bold  = HB_ISLOG(6) ? hb_parl(6) : 0;
   int          ital  = HB_ISLOG(7) ? hb_parl(7) : 0;
   int          color = HB_ISNUM(8) ? hb_parni(8) : 0;

   if( !text || !*text ) { hb_retl(1); return; }

   int fi = pdf_font_index( font, bold, ital );     /* 0..11 */
   double r = ( (color >> 16) & 0xFF ) / 255.0;
   double g = ( (color >>  8) & 0xFF ) / 255.0;
   double b = (  color        & 0xFF ) / 255.0;

   double baseline = s_pageH - y - size;            /* top-left → baseline */

   pdf_appendf( s_cur,
      "BT\n"
      "/F%d %.2f Tf\n"
      "%.3f %.3f %.3f rg\n"
      "1 0 0 1 %.2f %.2f Tm\n"
      "(",
      fi + 1, size, r, g, b, x, baseline );
   pdf_append_escaped( s_cur, text );
   s_cur.append( ") Tj\nET\n" );

   hb_retl(1);
}

/* RPT_EXPORTPDF( cDestFile ) — assemble and write PDF to disk */
HB_FUNC( RPT_EXPORTPDF )
{
   const char * cFile = hb_parc(1);
   if( !s_isOpen || !cFile || !*cFile ) { pdf_reset(); hb_retl(0); return; }

   /* Finalize last page */
   if( s_hasPage )
   {
      s_pages.push_back( s_cur );
      s_cur.clear();
      s_hasPage = false;
   }
   if( s_pages.empty() ) s_pages.push_back( std::string() );  /* at least one page */

   FILE * fp = fopen( cFile, "wb" );
   if( !fp ) { pdf_reset(); hb_retl(0); return; }

   const int nPages         = (int) s_pages.size();
   const int firstPageObj   = 3;
   const int firstContObj   = firstPageObj + nPages;
   const int firstFontObj   = firstContObj + nPages;
   const int nObjs          = firstFontObj + 12 - 1;

   std::vector<long> offsets;
   offsets.reserve( (size_t) nObjs );

   /* Build the whole PDF in memory, then write it once.
      Tracking offsets by buf.size() avoids lambdas (BCC32 compatibility). */
   std::string out;

   /* Header */
   out.append( "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n" );

   /* 1: Catalog */
   offsets.push_back( (long) out.size() );
   out.append( "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" );

   /* 2: Pages */
   offsets.push_back( (long) out.size() );
   pdf_appendf( out, "2 0 obj\n<< /Type /Pages /Kids [" );
   for( int i = 0; i < nPages; i++ )
      pdf_appendf( out, "%d 0 R ", firstPageObj + i );
   pdf_appendf( out, "] /Count %d >>\nendobj\n", nPages );

   /* Page objects */
   for( int i = 0; i < nPages; i++ )
   {
      offsets.push_back( (long) out.size() );
      pdf_appendf( out,
         "%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] "
         "/Resources << /Font <<",
         firstPageObj + i, s_pageW, s_pageH );
      for( int f = 0; f < 12; f++ )
         pdf_appendf( out, " /F%d %d 0 R", f + 1, firstFontObj + f );
      pdf_appendf( out, " >> >> /Contents %d 0 R >>\nendobj\n", firstContObj + i );
   }

   /* Content streams */
   for( int i = 0; i < nPages; i++ )
   {
      offsets.push_back( (long) out.size() );
      const std::string & cs = s_pages[ (size_t) i ];
      pdf_appendf( out, "%d 0 obj\n<< /Length %lu >>\nstream\n",
         firstContObj + i, (unsigned long) cs.size() );
      out.append( cs );
      out.append( "\nendstream\nendobj\n" );
   }

   /* Font objects */
   for( int f = 0; f < 12; f++ )
   {
      offsets.push_back( (long) out.size() );
      pdf_appendf( out,
         "%d 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /%s "
         "/Encoding /WinAnsiEncoding >>\nendobj\n",
         firstFontObj + f, k_fontNames[f] );
   }

   /* xref */
   long xrefPos = (long) out.size();
   pdf_appendf( out, "xref\n0 %d\n0000000000 65535 f \n", nObjs + 1 );
   for( size_t i = 0; i < offsets.size(); i++ )
      pdf_appendf( out, "%010ld 00000 n \n", offsets[i] );

   /* Trailer */
   pdf_appendf( out,
      "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%ld\n%%%%EOF\n",
      nObjs + 1, xrefPos );

   fwrite( out.data(), 1, out.size(), fp );
   fclose( fp );
   pdf_reset();
   hb_retl(1);
}
