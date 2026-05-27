// tokenizer_explorer.prg - Interactive BPE tokenization visualizer
//
// Demonstrates: How text becomes tokens for transformer input
//
// Tokenization pipeline:
//   Raw text -> Byte-Pair Encoding (BPE) -> Token IDs -> Embeddings
//
// BPE algorithm (Sennrich et al., 2016):
//   1. Start with character-level tokens
//   2. Count all adjacent pairs
//   3. Merge the most frequent pair
//   4. Repeat until vocabulary size reached
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oInput, oOutput, oBtnTokenize
static oCharView, oTokenView, oIdView

function Main()

   DEFINE FORM oForm TITLE "Tokenizer Explorer (BPE)" ;
      SIZE 700, 480 FONT "Segoe UI", 10

   @ 10, 10 SAY "Input text:" OF oForm SIZE 80
   @ 8, 95 GET oInput VAR "Hello, world! Transformers are amazing." OF oForm SIZE 420, 24

   @ 8, 525 BUTTON oBtnTokenize PROMPT "Tokenize" OF oForm SIZE 88, 24
   oBtnTokenize:OnClick := { || Tokenize() }

   @ 45, 10 SAY "Step 1 - Characters:" OF oForm SIZE 200
   @ 65, 10 GET oCharView VAR "" OF oForm SIZE 670, 60

   @ 135, 10 SAY "Step 2 - BPE Tokens:" OF oForm SIZE 200
   @ 155, 10 GET oTokenView VAR "" OF oForm SIZE 670, 60

   @ 225, 10 SAY "Step 3 - Token IDs:" OF oForm SIZE 200
   @ 245, 10 GET oIdView VAR "" OF oForm SIZE 670, 60

   @ 320, 10 SAY "Details:" OF oForm SIZE 80
   @ 340, 10 GET oOutput VAR "" OF oForm SIZE 670, 110

   ACTIVATE FORM oForm CENTERED

return nil

static function Tokenize()

   local cText, i, cChars, cTokens, cIds, cDetails, e
   local aTokens, aIds

   e := Chr(13) + Chr(10)
   cText := oInput:cText

   // Step 1: Show individual characters
   cChars := ""
   for i := 1 to Len( cText )
      cChars += "[" + SubStr( cText, i, 1 ) + "] "
   next
   cChars += e + "Total characters: " + LTrim(Str(Len(cText)))
   oCharView:cText := cChars

   // Step 2: Simulate BPE tokenization
   // In production, TTransformer:Tokenize() would use a real BPE vocabulary
   aTokens := SimulateBPE( cText )
   cTokens := ""
   for i := 1 to Len( aTokens )
      cTokens += "[" + aTokens[i] + "] "
   next
   cTokens += e + "Total tokens: " + LTrim(Str(Len(aTokens)))
   oTokenView:cText := cTokens

   // Step 3: Map to token IDs
   aIds := TokensToIds( aTokens )
   cIds := ""
   for i := 1 to Len( aIds )
      cIds += LTrim(Str(aIds[i])) + " "
   next
   cIds += e + "Vocabulary size: 50257 (GPT-2)"
   oIdView:cText := cIds

   // Details
   cDetails := "BPE Merge Rules Applied:" + e
   cDetails += "  'T' + 'r' -> 'Tr'  (common bigram)" + e
   cDetails += "  'a' + 'n' -> 'an'  (common bigram)" + e
   cDetails += "  'Tr' + 'an' -> 'Tran'  (merge of merges)" + e
   cDetails += "  'Tran' + 'sform' -> 'Transform'  (full word)" + e
   cDetails += e
   cDetails += "Compression ratio: " + LTrim(Str(Len(cText))) + ;
               " chars -> " + LTrim(Str(Len(aTokens))) + ;
               " tokens (" + LTrim(Str(Round(Len(cText)/Max(Len(aTokens),1), 1), 4, 1)) + ;
               " chars/token)"
   oOutput:cText := cDetails

return nil

static function SimulateBPE( cText )

   local aTokens := {}, cWord := "", i, c

   // Simplified: split on spaces/punctuation, simulate subword merges
   for i := 1 to Len( cText )
      c := SubStr( cText, i, 1 )
      if c == " " .or. c == "," .or. c == "!" .or. c == "." .or. c == "?"
         if ! Empty( cWord )
            AAdd( aTokens, cWord )
         endif
         if c != " "
            AAdd( aTokens, c )
         endif
         cWord := ""
      else
         cWord += c
      endif
   next
   if ! Empty( cWord )
      AAdd( aTokens, cWord )
   endif

return aTokens

static function TokensToIds( aTokens )

   local aIds := {}, i

   // Simulated vocabulary mapping
   for i := 1 to Len( aTokens )
      AAdd( aIds, Abs( HB_CRC32( aTokens[i] ) ) % 50257 )
   next

return aIds
