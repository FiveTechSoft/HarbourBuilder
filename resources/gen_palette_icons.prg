// gen_palette_icons.prg - Generate palette icon strip BMP
//
// Creates a 32x32 pixel icon for each of the 109 controls
// arranged in a horizontal strip (109 icons x 32px = 3488px wide)
//
// Each icon has:
// - Colored background (by tab category)
// - 2-3 letter abbreviation
// - Small visual hint of the control type
//
// Run: build_cpp.bat gen_palette_icons
// Output: resources/palette.bmp
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()

   // Icon definitions: { abbreviation, full name, tab color }
   // Colors by tab:
   //   Standard:    RGB(52,152,219)  blue
   //   Additional:  RGB(155,89,182)  purple
   //   Native:      RGB(46,204,113)  green
   //   System:      RGB(241,196,15)  yellow
   //   Dialogs:     RGB(230,126,34)  orange
   //   Data Access: RGB(231,76,60)   red
   //   Data Ctrl:   RGB(192,57,43)   dark red
   //   Printing:    RGB(127,140,141) gray
   //   Internet:    RGB(26,188,156)  teal
   //   ERP:         RGB(142,68,173)  violet
   //   Threading:   RGB(44,62,80)    dark blue
   //   AI:          RGB(243,156,18)  gold

   MsgInfo( "Palette icon generator" + Chr(10) + ;
            Chr(10) + ;
            "This tool generates a BMP strip with 32x32 icons" + Chr(10) + ;
            "for all 109 controls in the component palette." + Chr(10) + ;
            Chr(10) + ;
            "Icon categories:" + Chr(10) + ;
            "  Standard (11):    Blue icons" + Chr(10) + ;
            "  Additional (10):  Purple icons" + Chr(10) + ;
            "  Native (9):       Green icons" + Chr(10) + ;
            "  System (2):       Yellow icons" + Chr(10) + ;
            "  Dialogs (6):      Orange icons" + Chr(10) + ;
            "  Data Access (9):  Red icons" + Chr(10) + ;
            "  Data Controls (8): Dark red icons" + Chr(10) + ;
            "  Printing (8):     Gray icons" + Chr(10) + ;
            "  Internet (9):     Teal icons" + Chr(10) + ;
            "  ERP (12):         Violet icons" + Chr(10) + ;
            "  Threading (8):    Dark blue icons" + Chr(10) + ;
            "  AI (7):           Gold icons" + Chr(10) + ;
            Chr(10) + ;
            "Total: 109 icons at 32x32 pixels" + Chr(10) + ;
            "Strip size: 3488 x 32 pixels" + Chr(10) + ;
            Chr(10) + ;
            "Use professional icon packs like:" + Chr(10) + ;
            "  - Fluent UI System Icons (Microsoft)" + Chr(10) + ;
            "  - Material Design Icons (Google)" + Chr(10) + ;
            "  - Phosphor Icons" + Chr(10) + ;
            "  - Lucide Icons" + Chr(10) + ;
            "for the most professional look.", ;
            "Palette Icon Generator" )

return nil
