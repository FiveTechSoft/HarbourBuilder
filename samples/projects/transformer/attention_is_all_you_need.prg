// attention_is_all_you_need.prg - Reproduce the original paper step by step
//
// "Attention Is All You Need" (Vaswani et al., 2017)
// This example walks through every component of the transformer architecture
// with visual output at each stage.
//
// Full architecture:
//   Input -> Embedding + PositionalEncoding
//   -> N x EncoderLayer(MultiHeadAttention + FFN + LayerNorm + Residual)
//   -> N x DecoderLayer(MaskedMHA + CrossMHA + FFN + LayerNorm + Residual)
//   -> Linear -> Softmax -> Output
//
//----------------------------------------------------------------------

#include "hbbuilder.ch"

static oForm, oOutput

function Main()

   local oBtnRun

   DEFINE FORM oForm TITLE "Attention Is All You Need - Step by Step" ;
      SIZE 750, 550 FONT "Consolas", 10

   @ 8, 10 BUTTON oBtnRun PROMPT "Run Full Pipeline" OF oForm SIZE 140, 26
   oBtnRun:OnClick := { || RunPipeline() }

   @ 40, 10 GET oOutput VAR "" OF oForm SIZE 720, 480

   ACTIVATE FORM oForm CENTERED

return nil

static function RunPipeline()

   local e := Chr(13) + Chr(10), cOut := ""
   local cSep := Replicate( "=", 70 ) + e

   // ===== STEP 1: Input Embedding =====
   cOut += cSep
   cOut += "STEP 1: Input Embedding" + e
   cOut += cSep
   cOut += e
   cOut += 'Input sentence: "I love transformers"' + e
   cOut += "Tokenized:  [I] [love] [transform] [ers]" + e
   cOut += "Token IDs:  [42] [891] [12045] [567]" + e
   cOut += e
   cOut += "Embedding matrix E (vocab_size x d_model):" + e
   cOut += "  E[42]    = [0.12, -0.34, 0.56, ...] (512-dim vector)" + e
   cOut += "  E[891]   = [0.78, 0.23, -0.45, ...]" + e
   cOut += "  E[12045] = [-0.11, 0.67, 0.89, ...]" + e
   cOut += "  E[567]   = [0.45, -0.12, 0.33, ...]" + e
   cOut += e

   // ===== STEP 2: Positional Encoding =====
   cOut += cSep
   cOut += "STEP 2: Positional Encoding (sinusoidal)" + e
   cOut += cSep
   cOut += e
   cOut += "PE(pos, 2i)   = sin(pos / 10000^(2i/d_model))" + e
   cOut += "PE(pos, 2i+1) = cos(pos / 10000^(2i/d_model))" + e
   cOut += e
   cOut += "Position 0: [0.000, 1.000, 0.000, 1.000, ...]" + e
   cOut += "Position 1: [0.841, 0.540, 0.010, 0.999, ...]" + e
   cOut += "Position 2: [0.909, -0.416, 0.020, 0.999, ...]" + e
   cOut += "Position 3: [0.141, -0.990, 0.030, 0.999, ...]" + e
   cOut += e
   cOut += "Input to encoder = Embedding + PositionalEncoding" + e
   cOut += "  (element-wise addition, same dimensions)" + e
   cOut += e

   // ===== STEP 3: Multi-Head Self-Attention =====
   cOut += cSep
   cOut += "STEP 3: Multi-Head Self-Attention" + e
   cOut += cSep
   cOut += e
   cOut += "For each head h (h=1..8):" + e
   cOut += "  Q_h = X * W_Q_h   (seq_len x d_k, where d_k = d_model/n_heads = 64)" + e
   cOut += "  K_h = X * W_K_h" + e
   cOut += "  V_h = X * W_V_h" + e
   cOut += e
   cOut += "  Attention(Q,K,V) = softmax(Q * K^T / sqrt(d_k)) * V" + e
   cOut += e
   cOut += "  Q*K^T (4x4 attention matrix):" + e
   cOut += "         I     love  trans  ers" + e
   cOut += "  I    [0.82   0.12  0.04  0.02]  <- 'I' mostly attends to itself" + e
   cOut += "  love [0.15   0.70  0.10  0.05]  <- 'love' attends to itself" + e
   cOut += "  trans[0.05   0.25  0.60  0.10]  <- 'trans' attends to 'love' too" + e
   cOut += "  ers  [0.03   0.08  0.44  0.45]  <- 'ers' attends to 'trans' (subword!)" + e
   cOut += e
   cOut += "MultiHead = Concat(head_1, ..., head_8) * W_O" + e
   cOut += "  Output shape: (seq_len x d_model) = (4 x 512)" + e
   cOut += e

   // ===== STEP 4: Add & Norm =====
   cOut += cSep
   cOut += "STEP 4: Add & Norm (Residual Connection + Layer Normalization)" + e
   cOut += cSep
   cOut += e
   cOut += "  output = LayerNorm(x + MultiHeadAttention(x))" + e
   cOut += e
   cOut += "  LayerNorm: normalize across d_model dimension" + e
   cOut += "    mean = sum(x_i) / d_model" + e
   cOut += "    var  = sum((x_i - mean)^2) / d_model" + e
   cOut += "    x_norm = (x - mean) / sqrt(var + 1e-6)" + e
   cOut += "    output = gamma * x_norm + beta  (learned params)" + e
   cOut += e

   // ===== STEP 5: Feed-Forward Network =====
   cOut += cSep
   cOut += "STEP 5: Position-wise Feed-Forward Network" + e
   cOut += cSep
   cOut += e
   cOut += "  FFN(x) = max(0, x * W1 + b1) * W2 + b2" + e
   cOut += e
   cOut += "  W1: (512 x 2048)  - expand to 4x wider" + e
   cOut += "  W2: (2048 x 512)  - project back to d_model" + e
   cOut += "  ReLU activation between layers" + e
   cOut += e
   cOut += "  Followed by another Add & Norm:" + e
   cOut += "  output = LayerNorm(x + FFN(x))" + e
   cOut += e

   // ===== STEP 6: Stack N Layers =====
   cOut += cSep
   cOut += "STEP 6: Repeat N=6 times (Encoder Stack)" + e
   cOut += cSep
   cOut += e
   cOut += "  Layer 1: MHA -> Add&Norm -> FFN -> Add&Norm" + e
   cOut += "  Layer 2: MHA -> Add&Norm -> FFN -> Add&Norm" + e
   cOut += "  ...                                         " + e
   cOut += "  Layer 6: MHA -> Add&Norm -> FFN -> Add&Norm" + e
   cOut += e
   cOut += "  Total parameters (base model):" + e
   cOut += "    Embedding:  512 * 37000 =  18.9M" + e
   cOut += "    Per layer:  4 * 512^2 + 2 * 512 * 2048 = 3.1M" + e
   cOut += "    x6 layers:  6 * 3.1M = 18.9M" + e
   cOut += "    Output:     512 * 37000 = 18.9M" + e
   cOut += "    TOTAL:      ~65M parameters" + e
   cOut += e

   // ===== STEP 7: Output =====
   cOut += cSep
   cOut += "STEP 7: Output Linear + Softmax" + e
   cOut += cSep
   cOut += e
   cOut += "  logits = encoder_output * W_out  (seq_len x vocab_size)" + e
   cOut += "  probs  = softmax(logits)          (probability distribution)" + e
   cOut += e
   cOut += "  Top-5 predictions for next token:" + e
   cOut += "    'are'     : 0.342" + e
   cOut += "    'will'    : 0.187" + e
   cOut += "    'can'     : 0.123" + e
   cOut += "    'have'    : 0.098" + e
   cOut += "    'really'  : 0.067" + e
   cOut += e
   cOut += cSep
   cOut += "COMPLETE - The entire forward pass of a Transformer" + e
   cOut += cSep

   oOutput:cText := cOut

return nil
