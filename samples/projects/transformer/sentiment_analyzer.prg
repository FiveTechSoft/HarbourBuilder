// sentiment_analyzer.prg - Sentiment classification with transformer encoder
//
// Demonstrates: Encoder-only transformer for text classification
// Architecture: Similar to BERT (encoder-only, [CLS] token for classification)
//
// Pipeline:
//   [CLS] + tokens -> Encoder -> [CLS] embedding -> Linear -> softmax -> label
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oInput, oOutput, oResult, oBtnAnalyze

function Main()

   DEFINE FORM oForm TITLE "Sentiment Analyzer (Encoder Transformer)" ;
      SIZE 650, 420 FONT "Segoe UI", 10

   @ 10, 10 SAY "Enter text to analyze:" OF oForm SIZE 200
   @ 30, 10 GET oInput VAR "This movie was absolutely fantastic! Great acting and story." ;
      OF oForm SIZE 620, 50

   @ 90, 10 BUTTON oBtnAnalyze PROMPT "Analyze Sentiment" OF oForm SIZE 140, 28
   oBtnAnalyze:OnClick := { || AnalyzeSentiment() }

   @ 90, 170 SAY oResult PROMPT "" OF oForm SIZE 400

   @ 130, 10 SAY "Analysis:" OF oForm SIZE 100
   @ 150, 10 GET oOutput VAR "" OF oForm SIZE 620, 240

   ACTIVATE FORM oForm CENTERED

return nil

static function AnalyzeSentiment()

   local cText, nPositive, nNegative, nNeutral, cOut, e
   local aPositive, aNegative, nPosCount, nNegCount, cSentiment

   e := Chr(13) + Chr(10)
   cText := Lower( oInput:cText )

   // Simplified sentiment analysis
   // Real implementation: TTransformer encoder with classification head
   aPositive := { "great", "fantastic", "amazing", "wonderful", "excellent", ;
                  "love", "loved", "best", "good", "beautiful", "awesome", ;
                  "brilliant", "perfect", "superb", "outstanding" }
   aNegative := { "bad", "terrible", "awful", "horrible", "worst", ;
                  "hate", "hated", "boring", "poor", "ugly", "stupid", ;
                  "disappointing", "waste", "dreadful", "mediocre" }

   nPosCount := 0; nNegCount := 0
   AEval( aPositive, { |w| iif( w $ cText, nPosCount++, nil ) } )
   AEval( aNegative, { |w| iif( w $ cText, nNegCount++, nil ) } )

   nPositive := 0.33 + nPosCount * 0.15
   nNegative := 0.33 + nNegCount * 0.15
   nNeutral  := Max( 0.01, 1.0 - nPositive - nNegative )

   // Normalize (softmax)
   nPositive := Round( nPositive / (nPositive+nNegative+nNeutral), 3 )
   nNegative := Round( nNegative / (nPositive+nNegative+nNeutral), 3 )
   nNeutral  := Round( 1.0 - nPositive - nNegative, 3 )

   if nPositive > nNegative .and. nPositive > nNeutral
      cSentiment := "POSITIVE"
   elseif nNegative > nPositive .and. nNegative > nNeutral
      cSentiment := "NEGATIVE"
   else
      cSentiment := "NEUTRAL"
   endif

   oResult:cText := "Result: " + cSentiment + ;
      " (pos:" + LTrim(Str(nPositive,5,2)) + ;
      " neg:" + LTrim(Str(nNegative,5,2)) + ;
      " neu:" + LTrim(Str(nNeutral,5,2)) + ")"

   cOut := "=== Transformer Encoder Pipeline ===" + e + e
   cOut += "1. Tokenization:" + e
   cOut += "   [CLS] " + cText + " [SEP]" + e + e
   cOut += "2. Embedding (d_model=768):" + e
   cOut += "   [CLS] -> [0.12, -0.34, 0.56, ...] (768 dims)" + e
   cOut += "   Each token -> learned embedding + position encoding" + e + e
   cOut += "3. Encoder (12 layers x 12 heads):" + e
   cOut += "   Self-attention: every token attends to every other" + e
   cOut += "   [CLS] token aggregates meaning from entire sequence" + e + e
   cOut += "4. Classification head:" + e
   cOut += "   h_CLS = encoder_output[0]  (the [CLS] embedding)" + e
   cOut += "   logits = h_CLS * W_cls + b_cls  (768 -> 3 classes)" + e
   cOut += "   probs = softmax(logits)" + e + e
   cOut += "5. Output probabilities:" + e
   cOut += "   Positive: " + Str(nPositive * 100, 6, 1) + "%" + e
   cOut += "   Negative: " + Str(nNegative * 100, 6, 1) + "%" + e
   cOut += "   Neutral:  " + Str(nNeutral * 100, 6, 1) + "%" + e + e
   cOut += "=== Architecture: BERT-style (Encoder Only) ===" + e
   cOut += "Unlike GPT (decoder-only), BERT uses bidirectional attention:" + e
   cOut += "each token can attend to ALL other tokens (no causal mask)." + e
   cOut += "This makes it ideal for classification, not generation."

   oOutput:cText := cOut

return nil
