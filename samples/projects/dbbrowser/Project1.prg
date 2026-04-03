// Project1.prg - Database Browser application entry point
// Standard HarbourBuilder project main module

#include "hbbuilder.ch"

REQUEST HB_GT_GUI_DEFAULT

// Request the DBFCDX RDD so we can work with .dbf files
REQUEST DBFCDX

function Main()

   // Set the default RDD to DBFCDX (supports CDX indexes)
   RddSetDefault( "DBFCDX" )

   Form1Main()

return nil

// Framework
#include "classes.prg"
