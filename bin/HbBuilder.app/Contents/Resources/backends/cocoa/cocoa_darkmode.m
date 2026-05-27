// cocoa_darkmode.m - Dark mode support for macOS
//
// This file implements dark mode functionality for HarbourBuilder on macOS.
// Uses NSAppearance API for macOS 10.14+.

#import <Cocoa/Cocoa.h>
#import "hbapi.h"

// ============================================================================
// Global Variables
// ============================================================================

static BOOL g_appDarkMode = NO;

// ============================================================================
// Public API Functions
// ============================================================================

// Note: MAC_SETAPPDARKMODE already exists in cocoa_editor.mm
// Note: MAC_SETWINDOWDARKMODE functionality may exist elsewhere

HB_FUNC( MAC_GETAPPDARKMODE )
{
   hb_retl( g_appDarkMode );
}

// ============================================================================
// Utility Functions
// ============================================================================

BOOL IsDarkModeEnabled( void )
{
   if( @available( macOS 10.14, * ) )
   {
      NSAppearance *appearance = [NSApp effectiveAppearance];
      NSAppearanceName appearanceName = [appearance bestMatchFromAppearancesWithNames:@[
         NSAppearanceNameAqua,
         NSAppearanceNameDarkAqua
      ]];

      return [appearanceName isEqualToString:NSAppearanceNameDarkAqua];
   }

   return NO;
}

// ============================================================================
// Harbour Bridge Functions
// ============================================================================

// Note: UI_FORMSETDARKMODE already exists in cocoa_core.m
// Note: MAC_SETAPPDARKMODE already exists in cocoa_editor.mm

HB_FUNC( UI_GETSYSTEMDARKMODE )
{
   BOOL dark = IsDarkModeEnabled();
   hb_retl( dark );
}

// ============================================================================
// Color Utilities for Dark Mode
// ============================================================================

HB_FUNC( MAC_GETDARKMODECOLOR )
{
   // Returns appropriate color for dark/light mode
   // Parameters: nColorType (0=bg, 1=text, 2=control, etc.)
   NSInteger colorType = hb_parni( 1 );
   NSColor *color = nil;

   if( @available( macOS 10.14, * ) )
   {
      switch( colorType )
      {
         case 0: // Background
            color = [NSColor controlBackgroundColor];
            break;
         case 1: // Text
            color = [NSColor textColor];
            break;
         case 2: // Control
            color = [NSColor controlColor];
            break;
         case 3: // Selected control
            color = [NSColor selectedControlColor];
            break;
         case 4: // Window background
            color = [NSColor windowBackgroundColor];
            break;
         default:
            color = [NSColor controlBackgroundColor];
      }
   }
   else
   {
      // Fallback for older macOS
      color = [NSColor controlBackgroundColor];
   }

   // Convert NSColor to Harbour color (RGB)
   CGFloat r, g, b, a;
   [color getRed:&r green:&g blue:&b alpha:&a];

   long rgb = ( (long)(r * 255) << 16 ) |
              ( (long)(g * 255) << 8 ) |
              ( (long)(b * 255) );

   hb_retnl( rgb );
}