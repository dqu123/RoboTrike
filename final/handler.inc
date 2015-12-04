;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 handler.INC                                ;
;                            Event handler definitions                       ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains general definitions and macroes for setting up event
; handlers to particular interrupt types. The macros included are:
;    INSTALL_HANDLER(vector_addr, vector_offset, function) - install a certain 
;           function as a handler to a particular IVT entry.
;
; Revision History
;    11/19/15  David Qu            initial revision
;    11/20/15  David Qu            changed some initial values.
;    11/21/15  David Qu            updated comments.

; Control Register Addresses
PeriphBase  EQU     0FF00H            ;address of peripheral control block
Tmr0Ctrl    EQU     PeriphBase + 056H ;address of Timer 0 Control Register
Tmr0MaxCntA EQU     PeriphBase + 052H ;address of Timer 0 Max Count A Register
Tmr0Count   EQU     PeriphBase + 050H ;address of Timer 0 Count Register
INT2Ctrl    EQU		PeriphBase + 03CH ;address of INT2 Input.

; Control Register Values
Tmr0CtrlVal     EQU     0E001H          ;value to write to Timer 0 Control Register
                                        ;1---------------  enable timer
                                        ;-1--------------  write to control
                                        ;--1-------------  enable interrupts
                                        ;----000000------  reserved
                                        ;---0------0-----  read only
                                        ;-----------0----  TMRIN0 is an enable
                                        ;------------00--  count CPU clocks
                                        ;--------------0-  single counter mode
                                        ;---------------1  continuous mode
                                        
INT2CtrlVal     EQU     00001H          ;00000000000----- unused 
                                        ;-----------0---- edge triggering
                                        ;------------0--- enable interrupt
                                        ;-------------001 priority
                                       
; IVT Constants
IVT_POINTER_SIZE    EQU         2     ; 2 bytes per address / segment value.

; IVT Interrupt addresses
INT_14              EQU         0038H       ; word address to store INT 14
                                            ; event handler function offset.
INT_14_SEGMENT      EQU         INT_14 + 2  ; word address to store INT 14
                                            ; event handler function segment.


$NOLIST
; INSTALL_HANDLER
;
; Description:       Installs the passed function at the passed vector address
;                    in the IVT with the passed segment.
;
; Operation:         Moves OFFSET(function) and SEGMENT(function) into the the appropriate
;                    address in the IVT.
;
; Arguments:         vector_addr - start of byte address in vector table to install
;                                  handler
;                    vector_offset - address in IVT to store the offset of the
;                                  function
;                    function    - name of function to install
;
; Registers Changed: flags, AX, ES.
%*DEFINE(INSTALL_HANDLER(vector_addr, vector_offset, function))   (
        XOR     AX, AX
        MOV     ES, AX
                                ;store the vector
        MOV     ES: WORD PTR (%vector_addr), OFFSET(%function)
        MOV     ES: WORD PTR (%vector_offset), SEG(%function)
)

$LIST
