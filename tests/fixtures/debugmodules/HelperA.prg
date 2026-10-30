#include "hbbuilder.ch"
function HelperA()
   local x := HelperB()
   MemoWrit( "/tmp/debugmodules-result.txt", x )
return nil
