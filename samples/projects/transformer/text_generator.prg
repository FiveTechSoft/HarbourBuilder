// text_generator.prg - Autoregressive text generation with temperature control
//
// Demonstrates: TTransformer with OnGenerate event, temperature slider
// Shows token-by-token generation with adjustable randomness
//
// Architecture: Decoder-only transformer (like GPT)
// - Causal mask ensures each token only attends to previous tokens
// - Temperature controls softmax sharpness: 0.1=deterministic, 2.0=creative
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oPrompt, oOutput, oSlider, oLblTemp
static oBtnGenerate, oBtnStop
static lGenerating := .F.

function Main()

   DEFINE FORM oForm TITLE "Text Generator (Decoder-Only Transformer)" ;
      SIZE 650, 480 FONT "Segoe UI", 10

   @ 10, 10 SAY "Prompt:" OF oForm SIZE 60
   @ 8, 75 GET oPrompt VAR "Once upon a time" OF oForm SIZE 460, 24

   @ 8, 545 BUTTON oBtnGenerate PROMPT "Generate" OF oForm SIZE 88, 24
   oBtnGenerate:OnClick := { || Generate() }

   @ 40, 10 SAY "Temperature:" OF oForm SIZE 90
   // Temperature: 0.1 (focused) to 2.0 (creative)
   // Low temp -> argmax (greedy), High temp -> more uniform sampling
   @ 40, 105 SAY oLblTemp PROMPT "0.7" OF oForm SIZE 40
   // In a full implementation, this would be a TTrackBar:
   // @ 38, 150 TRACKBAR oSlider OF oForm SIZE 200 MIN 1 MAX 20

   @ 70, 10 SAY "Generated text (token by token):" OF oForm SIZE 300

   @ 90, 10 GET oOutput VAR "" OF oForm SIZE 620, 350

   ACTIVATE FORM oForm CENTERED

return nil

static function Generate()

   local cPrompt, aTokens, cGenerated, nMaxTokens, i
   local nTemp, cNextToken, e

   e := Chr(13) + Chr(10)
   cPrompt := oPrompt:cText
   nTemp := 0.7
   nMaxTokens := 100

   cGenerated := cPrompt
   oOutput:cText := "=== Generating with temperature " + LTrim(Str(nTemp,4,1)) + " ===" + e + e
   oOutput:cText += cPrompt

   // Simulate token-by-token generation
   // In production: TTransformer:Generate( cPrompt, nMaxTokens, nTemp )
   // Each step: embed -> self-attention (causal) -> FFN -> logits -> sample
   for i := 1 to nMaxTokens
      cNextToken := SampleNextToken( cGenerated, nTemp )
      if cNextToken == "<EOS>"; exit; endif
      cGenerated += " " + cNextToken
      oOutput:cText += " " + cNextToken
   next

   oOutput:cText += e + e
   oOutput:cText += "=== Generation complete ===" + e
   oOutput:cText += "Tokens generated: " + LTrim(Str(i-1)) + e
   oOutput:cText += e
   oOutput:cText += "How temperature works:" + e
   oOutput:cText += "  logits = model_output / temperature" + e
   oOutput:cText += "  probs  = softmax(logits)" + e
   oOutput:cText += "  token  = sample(probs)" + e
   oOutput:cText += e
   oOutput:cText += "Low temperature (0.1): sharp distribution -> predictable text" + e
   oOutput:cText += "High temperature (2.0): flat distribution -> creative/random text"

return nil

static function SampleNextToken( cContext, nTemp )

   // Simulated vocabulary with probabilities
   // Real implementation: run transformer forward pass, get logits, apply temperature
   static aVocab := { ;
      "in", "a", "the", "kingdom", "far", "away", "there", ;
      "lived", "brave", "young", "princess", "who", "loved", ;
      "to", "explore", "deep", "forests", "and", "tall", ;
      "mountains", "one", "day", "she", "discovered", "a", ;
      "magical", "crystal", "that", "could", "grant", "wishes" }
   static nPos := 0

   nPos++
   if nPos > Len( aVocab )
      return "<EOS>"
   endif

return aVocab[ nPos ]
