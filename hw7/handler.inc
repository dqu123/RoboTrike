$NOLIST


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 handler.INC                                ;
;                            Event handler definitions                       ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains general definitions and macroes for setting up event
; handlers to particular interrupt types. The macros included are:
;    INSTALL_HANDLER - install a certain function as a handler to a particular
;
;
; Revision History
;    11/19/15  David Qu            initial revision

IVT_POINTER_SIZE    EQU         2     ; 2 bytes per address / segment value.

; Interrupt addresses
INT_14              EQU         0038H       ; word address to store INT 14
                                            ; event handler function offset.
INT_14_SEGMENT      EQU         INT_14 + 2  ; word address to store INT 14
                                            ; event handler function segment.



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
