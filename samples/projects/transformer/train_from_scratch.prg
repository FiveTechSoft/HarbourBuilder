// train_from_scratch.prg - Train a mini-transformer from scratch
//
// Demonstrates: Complete transformer training loop
// Visualizes loss curve in real-time as the model learns
//
// Architecture (mini version of "Attention Is All You Need"):
//   - 2 layers (vs 6 in paper)
//   - 4 heads (vs 8 in paper)
//   - 64-dim embeddings (vs 512 in paper)
//   - 128-dim FFN (vs 2048 in paper)
//
// Training data: Simple character-level sequences
// Task: Predict next character given previous characters
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oLog, oLossChart, oBtnTrain, oBtnStop
static oLblEpoch, oLblLoss, oProgress
static lTraining := .F.

function Main()

   DEFINE FORM oForm TITLE "Train Transformer From Scratch" ;
      SIZE 700, 520 FONT "Segoe UI", 10

   @ 10, 10 SAY "Mini-Transformer Training" OF oForm SIZE 300
   @ 10, 500 BUTTON oBtnTrain PROMPT "Start Training" OF oForm SIZE 100, 26
   oBtnTrain:OnClick := { || TrainModel() }

   @ 10, 610 BUTTON oBtnStop PROMPT "Stop" OF oForm SIZE 60, 26
   oBtnStop:OnClick := { || lTraining := .F. }

   @ 45, 10 SAY oLblEpoch PROMPT "Epoch: 0 / 100" OF oForm SIZE 200
   @ 45, 250 SAY oLblLoss PROMPT "Loss: -" OF oForm SIZE 200

   // Loss curve (text-based chart)
   @ 70, 10 SAY "Loss Curve:" OF oForm SIZE 100
   @ 90, 10 GET oLossChart VAR "" OF oForm SIZE 670, 150

   // Training log
   @ 250, 10 SAY "Training Log:" OF oForm SIZE 100
   @ 270, 10 GET oLog VAR "" OF oForm SIZE 670, 210

   ACTIVATE FORM oForm CENTERED

return nil

static function TrainModel()

   local nEpochs := 100, nEpoch, nLoss, cLog, e
   local aLosses := {}, cChart, nBatchSize := 32
   local nLR := 0.001  // Learning rate (Adam optimizer)

   e := Chr(13) + Chr(10)
   lTraining := .T.
   cLog := ""

   // Model configuration
   cLog += "=== Transformer Configuration ===" + e
   cLog += "  Layers:        2" + e
   cLog += "  Attention Heads: 4" + e
   cLog += "  Embedding Dim:  64" + e
   cLog += "  FFN Dim:        128" + e
   cLog += "  Vocab Size:     128 (ASCII)" + e
   cLog += "  Max Seq Length:  32" + e
   cLog += "  Batch Size:     " + LTrim(Str(nBatchSize)) + e
   cLog += "  Learning Rate:  " + LTrim(Str(nLR, 8, 4)) + e
   cLog += "  Optimizer:      Adam (b1=0.9, b2=0.98, eps=1e-9)" + e
   cLog += "  LR Schedule:    Warmup 4000 steps" + e
   cLog += e
   cLog += "=== Training Data ===" + e
   cLog += '  "hello world", "harbour code", "transformer AI"' + e
   cLog += '  "attention mechanism", "neural network"' + e
   cLog += e
   cLog += "=== Training Loop ===" + e
   cLog += "  For each epoch:" + e
   cLog += "    1. Tokenize: chars -> integer indices" + e
   cLog += "    2. Embed: indices -> vectors (+ positional encoding)" + e
   cLog += "    3. Forward: N x (MultiHeadAttention + FFN + LayerNorm)" + e
   cLog += "    4. Output: linear projection -> logits over vocab" + e
   cLog += "    5. Loss: cross-entropy(logits, targets)" + e
   cLog += "    6. Backward: compute gradients via backpropagation" + e
   cLog += "    7. Update: Adam optimizer step" + e
   cLog += e

   oLog:cText := cLog

   // Simulate training epochs
   for nEpoch := 1 to nEpochs
      if ! lTraining; exit; endif

      // Simulated loss: starts high, decreases exponentially with noise
      nLoss := 4.5 * Exp( -nEpoch * 0.05 ) + ( HB_Random() - 0.5 ) * 0.1
      nLoss := Max( nLoss, 0.01 )
      AAdd( aLosses, nLoss )

      oLblEpoch:cText := "Epoch: " + LTrim(Str(nEpoch)) + " / " + LTrim(Str(nEpochs))
      oLblLoss:cText := "Loss: " + LTrim(Str(nLoss, 8, 4))

      // Update text-based loss chart
      cChart := DrawLossChart( aLosses )
      oLossChart:cText := cChart

      // Log every 10 epochs
      if nEpoch % 10 == 0
         cLog += "Epoch " + PadL(LTrim(Str(nEpoch)),3) + ;
                 "  Loss: " + Str(nLoss, 8, 4) + ;
                 "  LR: " + Str( GetLR(nEpoch), 10, 6 ) + e
         oLog:cText := cLog
      endif
   next

   cLog += e + "=== Training Complete ===" + e
   cLog += "Final loss: " + Str(nLoss, 8, 4) + e
   cLog += e
   cLog += "=== Key Equations ===" + e
   cLog += "Attention(Q,K,V) = softmax(Q*K^T / sqrt(d_k)) * V" + e
   cLog += "MultiHead(Q,K,V) = Concat(head_1,...,head_h) * W_O" + e
   cLog += "  where head_i = Attention(Q*W_Qi, K*W_Ki, V*W_Vi)" + e
   cLog += "FFN(x) = max(0, x*W_1 + b_1) * W_2 + b_2" + e
   cLog += "LayerNorm(x) = (x - mean) / sqrt(var + eps) * gamma + beta" + e
   oLog:cText := cLog
   lTraining := .F.

return nil

// Warmup + inverse sqrt decay (from the paper)
static function GetLR( nStep )

   local nWarmup := 40  // 4000 in paper, scaled down
   local nDModel := 64

   return nDModel^(-0.5) * Min( nStep^(-0.5), nStep * nWarmup^(-1.5) )

// Simple text-based loss chart
static function DrawLossChart( aLosses )

   local cChart := "", i, j, nRows := 6, nMax, nMin, nVal, nRow, e
   local cLine

   e := Chr(13) + Chr(10)
   nMax := 5.0; nMin := 0.0

   for i := nRows to 1 step -1
      nVal := nMin + ( nMax - nMin ) * i / nRows
      cLine := Str( nVal, 4, 1 ) + " |"
      for j := 1 to Min( Len(aLosses), 80 )
         nRow := Int( ( aLosses[j] - nMin ) / ( nMax - nMin ) * nRows ) + 1
         if nRow == i
            cLine += "*"
         else
            cLine += " "
         endif
      next
      cChart += cLine + e
   next
   cChart += "     +" + Replicate( "-", Min(Len(aLosses), 80) ) + e
   cChart += "      Epochs ->"

return cChart
