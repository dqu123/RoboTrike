        NAME    MACRO

; Local include files.
$INCLUDE(macro.inc) 
             
    
CODE SEGMENT PUBLIC 'CODE'
    ; Test the following macros.
    EXTRN      Testing:NEAR
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
    ; INSTALL_HANDLER(0, Testing, DS)
    %INSTALL_HANDLER(0020H, 0022H, Testing)

CODE        ENDS

            END