// Project1.prg - Accounting (Contabilidad) entry point
#include "hbbuilder.ch"

REQUEST HB_GT_GUI_DEFAULT

function Main()
   ErrorBlock( { |oError| AppShowError( oError ) } )
   Form1Main()
return nil

#include "classes.prg"
