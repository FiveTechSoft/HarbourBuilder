/*
 * hix_template.prg — HIX template engine
 *
 * Supports: @args, {{ expr }}, @foreach var IN array, @endforeach,
 *           @if expr, @else, @endif
 */

#include "hbbuilder.ch"

FUNCTION HIX_RenderTemplate( cTpl, aArgs )
   local aLines, i, cLine, cOut
   local hVars, aArgNames
   local lInForeach, cForeachVar, aForeachArr, aForeachLines
   local lInIf, lIfResult, lInElse
   local j, k, m, cSpec, nIn, cArrName
   local cExprIf

   aLines      := hb_aTokens( cTpl, Chr(10) )
   cOut        := ""
   hVars       := { => }
   aArgNames   := {}
   lInForeach  := .F.
   cForeachVar := ""
   aForeachArr := {}
   aForeachLines := {}
   lInIf       := .F.
   lIfResult   := .T.
   lInElse     := .F.

   for i := 1 to Len( aLines )
      cLine := aLines[i]

      // ── @args ────────────────────────────────────────────────────────────
      if Left( LTrim(cLine), 5 ) == "@args"
         aArgNames := hb_aTokens( AllTrim( SubStr(LTrim(cLine),6) ), "," )
         for j := 1 to Len( aArgNames )
            aArgNames[j] := AllTrim( aArgNames[j] )
            if j <= Len( aArgs )
               hVars[ aArgNames[j] ] := aArgs[j]
            endif
         next
         loop
      endif

      // ── @foreach ─────────────────────────────────────────────────────────
      if Left( LTrim(cLine), 8 ) == "@foreach"
         cSpec := AllTrim( SubStr(LTrim(cLine),9) )
         nIn   := At( " IN ", Upper(cSpec) )
         if nIn > 0
            cForeachVar  := AllTrim( Left(cSpec, nIn-1) )
            cArrName     := AllTrim( SubStr(cSpec, nIn+4) )
            aForeachArr  := hb_hGetDef( hVars, cArrName, {} )
            lInForeach   := .T.
            aForeachLines := {}
         endif
         loop
      endif

      if lInForeach
         if Left( LTrim(cLine), 11 ) == "@endforeach"
            for k := 1 to Len( aForeachArr )
               hVars[ cForeachVar ] := aForeachArr[k]
               for m := 1 to Len( aForeachLines )
                  cOut += HIX_ProcessLine( aForeachLines[m], hVars ) + Chr(10)
               next
            next
            lInForeach := .F.
            aForeachLines := {}
         else
            AAdd( aForeachLines, cLine )
         endif
         loop
      endif

      // ── @if / @else / @endif ─────────────────────────────────────────────
      if Left( LTrim(cLine), 3 ) == "@if"
         cExprIf   := AllTrim( SubStr(LTrim(cLine),4) )
         lInIf     := .T.
         lInElse   := .F.
         lIfResult := ( HIX_EvalExpr( cExprIf, hVars ) == .T. )
         loop
      endif
      if lInIf .and. AllTrim(cLine) == "@else"
         lInElse   := .T.
         lIfResult := !lIfResult
         loop
      endif
      if lInIf .and. AllTrim(cLine) == "@endif"
         lInIf := .F.; lIfResult := .T.; lInElse := .F.
         loop
      endif
      if lInIf .and. !lIfResult
         loop
      endif

      // ── Normal line ───────────────────────────────────────────────────────
      cOut += HIX_ProcessLine( cLine, hVars ) + Chr(10)

   next

return cOut

//─── Process one line: replace {{ expr }} with evaluated result ──────────────

FUNCTION HIX_ProcessLine( cLine, hVars )
   local cOut, nStart, nEnd, cExpr, cVal
   cOut := ""
   do while .T.
      nStart := At( "{{", cLine )
      if nStart == 0; EXIT; endif
      nEnd := At( "}}", cLine )
      if nEnd == 0; EXIT; endif
      cOut  += Left( cLine, nStart-1 )
      cExpr  := AllTrim( SubStr( cLine, nStart+2, nEnd-nStart-2 ) )
      cVal   := hb_CStr( HIX_EvalExpr( cExpr, hVars ) )
      cOut  += cVal
      cLine  := SubStr( cLine, nEnd+2 )
   enddo
   cOut += cLine
return cOut

//─── Evaluate a Harbour expression in template variable context ───────────────

FUNCTION HIX_EvalExpr( cExpr, hVars )
   local nBr, cKey, nIdx, bExpr, uResult
   // Fast path: plain variable name
   if hb_hHasKey( hVars, cExpr )
      return hVars[ cExpr ]
   endif
   // Array element: var[n]
   if "[" $ cExpr
      nBr  := At("[", cExpr)
      cKey := Left(cExpr, nBr-1)
      nIdx := Val( SubStr(cExpr, nBr+1) )
      if hb_hHasKey(hVars, cKey) .and. ValType(hVars[cKey]) == "A" .and. nIdx >= 1
         return hVars[cKey][nIdx]
      endif
   endif
   // General expression: inject vars as PRIVATEs and eval via macro
   hb_hEval( hVars, { |k,v| HIX_SetPrivate(k,v) } )
   bExpr := hb_macroBlock( "{||" + cExpr + "}" )
   if bExpr != nil
      begin sequence
         uResult := Eval( bExpr )
      recover
         uResult := ""
      end sequence
      return uResult
   endif
return ""

//─── Helper: set a PRIVATE variable by name ──────────────────────────────────

FUNCTION HIX_SetPrivate( cName, uVal )
   __mvPrivate( cName )
   __mvPut( cName, uVal )
return nil
