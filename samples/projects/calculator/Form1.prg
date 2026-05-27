// Form1.prg - Calculator form
// A fully functional four-operation calculator using xBase command syntax.
// Supports digit entry, decimal point, four arithmetic operations,
// clear (C), and equals (=).

#include "hbbuilder.ch"

// Static variables for calculator state
static oDisplay        // Edit control showing current value
static nAccum  := 0    // Accumulated result from previous operations
static cOp     := ""   // Pending operator (+, -, *, /)
static lNewNumber := .t.  // .t. when next digit should start a new number

//----------------------------------------------------------------------------//
// Form1() - Build and activate the calculator form
//----------------------------------------------------------------------------//

function Form1()

   local oForm, oBtn
   local nRow, nCol, n
   local nBtnW := 60     // Button width
   local nBtnH := 50     // Button height
   local nGap  := 5      // Gap between buttons
   local nLeft := 10     // Left margin
   local nTop  := 50     // First row of buttons (below display)

   // Button labels arranged in 4 rows x 4 columns
   local aButtons := { ;
      { "7", "8", "9", "/" }, ;
      { "4", "5", "6", "*" }, ;
      { "1", "2", "3", "-" }, ;
      { "C", "0", "=", "+" }  ;
   }

   // --- Create the form ---
   DEFINE FORM oForm TITLE "Calculator" SIZE 280, 380 FONT "Segoe UI", 14

   // --- Display field at the top (read-only, shows current number) ---
   @ 10, nLeft GET oDisplay VAR "0" OF oForm SIZE 252, 30
   oDisplay:cText := "0"

   // --- Create 4 rows x 4 columns of buttons ---
   for nRow := 1 to 4
      for nCol := 1 to 4

         // Calculate button position
         @ nTop + ( nRow - 1 ) * ( nBtnH + nGap ), ;
           nLeft + ( nCol - 1 ) * ( nBtnW + nGap ) ;
           BUTTON oBtn PROMPT aButtons[ nRow ][ nCol ] ;
           OF oForm SIZE nBtnW, nBtnH

         // Each button calls CalcPress() with its label
         oBtn:OnClick := CalcBlock( aButtons[ nRow ][ nCol ] )

      next
   next

   // --- Show the form centered on screen ---
   ACTIVATE FORM oForm CENTERED

   oForm:Destroy()

return nil

//----------------------------------------------------------------------------//
// CalcBlock() - Return a code block that calls CalcPress with cKey
// We need a separate function so each block captures its own cKey value.
//----------------------------------------------------------------------------//

static function CalcBlock( cKey )
return { || CalcPress( cKey ) }

//----------------------------------------------------------------------------//
// CalcPress() - Handle a button press
//
// cKey: the label of the button pressed ("0"-"9", "+", "-", "*", "/", "=", "C")
//
// Logic:
//   Digits (0-9): accumulate into display. If lNewNumber is true, replace
//                 the display text; otherwise append the digit.
//   Operators (+, -, *, /): evaluate any pending operation, store the new
//                           operator, and flag that the next digit starts
//                           a new number.
//   Equals (=): evaluate the pending operation and clear the operator.
//   Clear (C): reset everything to initial state.
//----------------------------------------------------------------------------//

static function CalcPress( cKey )

   local cDisplay
   local nCurrent

   // --- Clear ---
   if cKey == "C"
      nAccum     := 0
      cOp        := ""
      lNewNumber := .t.
      oDisplay:cText := "0"
      return nil
   endif

   // --- Digit keys: 0 through 9 ---
   if cKey >= "0" .and. cKey <= "9"
      if lNewNumber
         // Start a fresh number
         oDisplay:cText := cKey
         lNewNumber := .f.
      else
         // Append digit to current display
         cDisplay := oDisplay:cText
         if cDisplay == "0"
            // Replace leading zero
            oDisplay:cText := cKey
         else
            oDisplay:cText := cDisplay + cKey
         endif
      endif
      return nil
   endif

   // --- Operator or Equals ---
   // First, evaluate any pending operation
   nCurrent := Val( oDisplay:cText )

   if !Empty( cOp )
      // Apply the pending operator
      nAccum := DoOperation( nAccum, nCurrent, cOp )
   else
      // No pending operation: just store current value
      nAccum := nCurrent
   endif

   // Update display with the result so far
   oDisplay:cText := LTrim( Str( nAccum ) )

   if cKey == "="
      // Equals: clear the pending operator
      cOp := ""
   else
      // Store the new operator (+, -, *, /)
      cOp := cKey
   endif

   // Next digit press should start a new number
   lNewNumber := .t.

return nil

//----------------------------------------------------------------------------//
// DoOperation() - Perform an arithmetic operation
//
// nLeft:  left operand (accumulator)
// nRight: right operand (current display value)
// cOper:  operator character
//
// Returns the result as a numeric value.
//----------------------------------------------------------------------------//

static function DoOperation( nLeft, nRight, cOper )

   local nResult := 0

   do case
      case cOper == "+"
         nResult := nLeft + nRight

      case cOper == "-"
         nResult := nLeft - nRight

      case cOper == "*"
         nResult := nLeft * nRight

      case cOper == "/"
         // Guard against division by zero
         if nRight != 0
            nResult := nLeft / nRight
         else
            nResult := 0
         endif
   endcase

return nResult
