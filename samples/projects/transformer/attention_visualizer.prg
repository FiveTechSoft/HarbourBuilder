// attention_visualizer.prg - Visualize self-attention weights as a heatmap
//
// Demonstrates: TTransformer component with OnAttention event
// Shows how attention heads focus on different parts of the input
//
// "Attention Is All You Need" (Vaswani et al., 2017)
// This example visualizes the attention matrix Q*K^T / sqrt(d_k)
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oTransformer, oGrid, oInput, oBtnRun
static oComboHead, oComboLayer
static aWeights := {}

function Main()

   local oLbl

   DEFINE FORM oForm TITLE "Attention Visualizer" ;
      SIZE 700, 500 FONT "Segoe UI", 10

   @ 10, 10 SAY oLbl PROMPT "Input text:" OF oForm SIZE 80
   @ 8, 95 GET oInput VAR "The cat sat on the mat" OF oForm SIZE 400, 24

   @ 8, 505 BUTTON oBtnRun PROMPT "Analyze" OF oForm SIZE 80, 24
   oBtnRun:OnClick := { || RunAttention() }

   @ 40, 10 SAY "Layer:" OF oForm SIZE 45
   @ 38, 60 COMBOBOX oComboLayer OF oForm ;
      ITEMS { "Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6" } SIZE 100
   oComboLayer:Value := 0

   @ 40, 180 SAY "Head:" OF oForm SIZE 40
   @ 38, 225 COMBOBOX oComboHead OF oForm ;
      ITEMS { "Head 1", "Head 2", "Head 3", "Head 4", "Head 5", "Head 6", "Head 7", "Head 8" } SIZE 100
   oComboHead:Value := 0

   // The attention heatmap grid
   // In a full implementation, this would be a custom PaintBox with
   // colored cells representing attention weights (0.0 = white, 1.0 = deep blue)
   @ 70, 10 SAY "Attention weights (Q*K^T / sqrt(d_k)) after softmax:" OF oForm SIZE 600

   // Placeholder: attention matrix as text
   @ 90, 10 GET oGrid VAR "" OF oForm SIZE 670, 370

   // TTransformer component (non-visual)
   // In a full implementation:
   // oTransformer := TTransformer():New()
   // oTransformer:nLayers := 6
   // oTransformer:nHeads  := 8
   // oTransformer:nEmbedDim := 512
   // oTransformer:OnAttention := { |nLayer, nHead, aMatrix| ... }

   ACTIVATE FORM oForm CENTERED

return nil

static function RunAttention()

   local cText, aTokens, nLen, i, j, cMatrix, e
   local aRow, nVal

   e := Chr(13) + Chr(10)
   cText := oInput:cText
   aTokens := HB_ATokens( cText, " " )
   nLen := Len( aTokens )

   // Simulate attention weights (in production, the TTransformer
   // component would compute real Q*K^T/sqrt(d_k) + softmax)
   cMatrix := "Token        "
   for i := 1 to nLen
      cMatrix += PadR( aTokens[i], 10 )
   next
   cMatrix += e
   cMatrix += Replicate( "-", 13 + nLen * 10 ) + e

   for i := 1 to nLen
      cMatrix += PadR( aTokens[i], 13 )
      aRow := SimulateAttention( nLen, i )
      for j := 1 to nLen
         nVal := aRow[j]
         cMatrix += PadR( LTrim(Str(nVal, 6, 3)), 10 )
      next
      cMatrix += e
   next

   cMatrix += e
   cMatrix += "Legend: Higher values = stronger attention" + e
   cMatrix += "Diagonal = self-attention (token attends to itself)" + e
   cMatrix += "Off-diagonal = cross-attention between tokens" + e
   cMatrix += e
   cMatrix += "Key insight: In 'The cat sat on the mat'," + e
   cMatrix += "'sat' strongly attends to 'cat' (subject-verb)" + e
   cMatrix += "'mat' attends to 'the' and 'on' (determiner + preposition)"

   oGrid:cText := cMatrix

return nil

// Simulate softmax attention weights for a given query position
static function SimulateAttention( nLen, nQuery )

   local aWeights := Array( nLen ), i, nSum, nDist

   // Simulate: higher attention for nearby tokens + self
   nSum := 0
   for i := 1 to nLen
      nDist := Abs( i - nQuery )
      aWeights[i] := Exp( -nDist * 0.5 )  // Gaussian-like falloff
      if i == nQuery
         aWeights[i] := aWeights[i] * 2.0  // Self-attention boost
      endif
      nSum += aWeights[i]
   next

   // Softmax normalization
   for i := 1 to nLen
      aWeights[i] := Round( aWeights[i] / nSum, 3 )
   next

return aWeights
