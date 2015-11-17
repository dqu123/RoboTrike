        NAME    MACRO

; Local include files.
$INCLUDE(macro.inc) 
      
$LIST       
CODE SEGMENT PUBLIC 'CODE'
    ; Test the following macros.
    
    ; CLR(AX)
    %CLR(AX)
    ; SETBIT(AX, 15)
    %SETBIT(AX, 15) 
    ; CLRBIT(AX, 0)
    %CLRBIT(AX, 0) 
    ; COMBIT(AX, 7)
    %COMBIT(AX, 7) 
    ; TESTBIT(AX, 11)
    %TESTBIT(AX, 11)
    ; XLATW
    %XLATW
    ; READPCB(0FFA4H)
    %READPCB(0FFA4H)
    ; WRITEPCB(0FFA8H, 0183H)
    %WRITEPCB(0FFA8H, 0183H)

CODE        ENDS

            END