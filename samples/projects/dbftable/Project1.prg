// Project1.prg
//--------------------------------------------------------------------
// DBF Table sample - exercises the two new inspector dropdowns:
//
//   1. cRDD (string-valued enum) on TDbfTable - click oDbfTable1 in
//      the designer, find cRDD in the inspector, pick one of
//      DBFCDX / DBFNTX / DBFFPT.
//
//   2. Any logical property gets a Yes/No picker - click oButton1,
//      find lDefault or lCancel, or click oLabel1 and tweak lVisible
//      / lEnabled. All of them now offer a dropdown rather than free
//      text entry.
//--------------------------------------------------------------------
#include "hbbuilder.ch"
//--------------------------------------------------------------------

PROCEDURE Main()

   local oApp

   oApp := TApplication():New()
   oApp:cTitle := "DBF Table dropdown demo"
   oApp:CreateForm( TForm1():New() )
   oApp:Run()

return
//--------------------------------------------------------------------
