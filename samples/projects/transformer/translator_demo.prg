// translator_demo.prg - Encoder-Decoder transformer for translation
//
// Demonstrates: Full encoder-decoder architecture (the original transformer)
// Task: Spanish -> English translation
//
// Architecture:
//   Encoder: processes source sentence (bidirectional attention)
//   Decoder: generates target sentence (causal + cross-attention)
//
// Cross-attention: decoder queries attend to encoder keys/values
// This is what connects the two languages.
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oInput, oOutput, oDetails, oBtnTranslate

function Main()

   DEFINE FORM oForm TITLE "Translator (Encoder-Decoder Transformer)" ;
      SIZE 700, 480 FONT "Segoe UI", 10

   @ 10, 10 SAY "Spanish:" OF oForm SIZE 70
   @ 8, 85 GET oInput VAR "El gato se sienta en la alfombra" OF oForm SIZE 420, 24

   @ 8, 520 BUTTON oBtnTranslate PROMPT "Translate" OF oForm SIZE 88, 24
   oBtnTranslate:OnClick := { || Translate() }

   @ 45, 10 SAY "English:" OF oForm SIZE 70
   @ 43, 85 SAY oOutput PROMPT "" OF oForm SIZE 500

   @ 80, 10 SAY "Step-by-step decoding:" OF oForm SIZE 200
   @ 100, 10 GET oDetails VAR "" OF oForm SIZE 670, 350

   ACTIVATE FORM oForm CENTERED

return nil

static function Translate()

   local cSource, cOut, e, i
   local aSource, aTarget

   e := Chr(13) + Chr(10)
   cSource := oInput:cText

   // Simple word-level translation (real: learned encoder-decoder)
   aSource := HB_ATokens( cSource, " " )
   aTarget := TranslateWords( aSource )

   oOutput:cText := ArrayToStr( aTarget )

   cOut := "=== Encoder-Decoder Translation ===" + e + e

   cOut += "ENCODER (processes entire source at once):" + e
   cOut += "  Input:  " + cSource + e
   cOut += "  Tokens: "
   for i := 1 to Len(aSource)
      cOut += "[" + aSource[i] + "] "
   next
   cOut += e
   cOut += "  Self-attention: bidirectional (each word sees all others)" + e
   cOut += "  Output: context-aware embeddings for each source token" + e + e

   cOut += Replicate("-", 60) + e + e

   cOut += "DECODER (generates target left-to-right):" + e + e

   for i := 1 to Len( aTarget )
      cOut += "  Step " + LTrim(Str(i)) + ": Generate '" + aTarget[i] + "'" + e
      cOut += "    Masked self-attention: only sees previous target tokens" + e
      cOut += "      Context: [" + ArrayToStr( ASize( AClone(aTarget), i ) ) + "]" + e
      cOut += "    Cross-attention: queries target, keys/values from encoder" + e
      cOut += "      Attends to: "
      if i <= Len(aSource)
         cOut += "'" + aSource[i] + "' (aligned source word)" + e
      else
         cOut += "(full source context)" + e
      endif
      cOut += "    FFN -> LayerNorm -> logits -> argmax -> '" + aTarget[i] + "'" + e
      cOut += e
   next

   cOut += Replicate("=", 60) + e
   cOut += "KEY INSIGHT: Cross-Attention" + e
   cOut += "  Q = decoder state (what am I looking for?)" + e
   cOut += "  K = encoder output (what's available in the source?)" + e
   cOut += "  V = encoder output (what information to retrieve?)" + e
   cOut += e
   cOut += "  This is how the decoder 'reads' the source sentence" + e
   cOut += "  while generating the target sentence word by word."

   oDetails:cText := cOut

return nil

static function TranslateWords( aSource )

   local aTarget := {}, i, cWord, cTrans
   // Simple dictionary (real: learned through training)
   static aDict := { ;
      { "el",        "the" }, ;
      { "la",        "the" }, ;
      { "gato",      "cat" }, ;
      { "perro",     "dog" }, ;
      { "se",        "" }, ;
      { "sienta",    "sits" }, ;
      { "en",        "on" }, ;
      { "alfombra",  "mat" }, ;
      { "casa",      "house" }, ;
      { "es",        "is" }, ;
      { "grande",    "big" }, ;
      { "pequeno",   "small" } }

   for i := 1 to Len( aSource )
      cWord := Lower( aSource[i] )
      cTrans := LookupDict( aDict, cWord )
      if ! Empty( cTrans )
         AAdd( aTarget, cTrans )
      endif
   next

return aTarget

static function LookupDict( aDict, cWord )
   local i
   for i := 1 to Len( aDict )
      if aDict[i][1] == cWord
         return aDict[i][2]
      endif
   next
return cWord  // passthrough if not found

static function ArrayToStr( a )
   local c := "", i
   for i := 1 to Len( a )
      if i > 1; c += " "; endif
      c += a[i]
   next
return c
