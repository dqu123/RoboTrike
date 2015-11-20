        NAME    INITSERI
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  INITSERI                                    ;
;                             Serial Functions                                 ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contains the general purpose initialization function for the 
; TL16C450 Serial Chip.
;
; Public functions:
; InitSerialChip()          - initializes the serial chip.
; SetSerialDivisor(divisor) - sets the divisor latch on the serial
;
; Local functions:
; None.
;
; Revision History:
; 		11/19/15  David Qu		initial revision.

; local include files
$INCLUDE(genMacro.inc)
$INCLUDE(initSeri.inc)

CGROUP	GROUP	CODE 

CODE 	SEGMENT PUBLIC 'CODE'
		ASSUME 	CS:CGROUP

; InitSerialChip()
; 
; Description:       Initializes the serial chip, enabling its interrupts,
;                    and setting it to its default baud rate of INIT_BAUD_RATE,
;                    and configuring 8 character words, no extra stop bit,
;                    parity checking, stick parity, clearing the break bit,
;                    and enabling the divisor latch.   
; Operation:         Sets the Interrupt Enable Register to ENABLE_SERIAL_INT,
;                    the Line Control Register to INIT_LCR, 
;                    the Divisor Latch to the LSB of INIT_BAUD_DIVISOR,
;                    and the Latch to the MSB of INIT_BAUD_DIVISOR.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   temp (AX) - holds the INIT_BAUD_DIVISOR value to control
;                                where the MSB and LSB go, and values to OUT.
;                    output (DX) - used to OUT values to the correct peripheral
;                                  locations.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       Assumes the peripheral chip select has been initialized
;                    properly.
;
; Registers Changed: flags, AX, DX.
; Special notes:     None.
InitSerialChip  PROC     NEAR
                PUBLIC   InitSerialChip
                
        MOV     DX, LINE_CTRL_REG       ; Initialize the line control register
        MOV     AL, INIT_LCR            ; to the INIT_LCR value specified in
        OUT     DX, AL                  ; initSeri.inc. This determines parity
                                        ; settings, break conditions, word size, 
                                        ; and other parameters of the chip.
        
        MOV     AX, INIT_BAUD_DIVISOR   ; Initialize the serial divsor registers
        CALL    SetSerialDivisor      ; to the INIT_BAUD_DIVISOR specified
                                        ; in initSeri.inc. This determines
                                        ; the sending rate.
        
        MOV     DX, INT_ENABLE_REG      ; Initialize IER to
        MOV     AL, ENABLE_SERIAL_INT   ; enable all interrupts so
        OUT     DX, AL                  ; event handlers will be called.
        
        

        RET

InitSerialChip  ENDP

; SetSerialDivisor(divisor)
; 
; Description:       Sets the divisor latch in the serial chip to the
;                    desired word value passed in AX.
; Operation:         
;
; Arguments:         divisor (AX) - baud rate divisor that determines baud
;                                   rate by the formula. 
;                                   baud rate = CLOCK_FREQ / 16 / DIVISOR.
; Return Value:      None.
;
; Local Variables:   temp (AX) - used for values to OUT.
;                    output (DX) - designates output port.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       Assumes the peripheral chip select has been initialized
;                    properly.
;
; Registers Changed: flags, DX
; Special notes:     None.
SetSerialDivisor  PROC     NEAR
                  PUBLIC   SetSerialDivisor

        PUSH    AX  ; Save divisor argument.
        
        
        MOV     DX, LINE_CTRL_REG           ; Read current LCR value and
        IN      AL, DX                      ; set the DLAB.
        OR      AL, ENABLE_DIVISOR_LATCH    
        
        %CRITICAL_START           ; Entering critical code because
                                  ; we don't want to be interrupted while
                                  ; the divisor latch is enabled. (This will 
                                  ; lead to improper writes in the EH).
                                  
        OUT     DX, AL            ; Divisor latch is now enabled.
        
        POP     AX                ; Restore divisor argument.
        
        MOV     DX, DIVISOR_LATCH ; Write low byte of divisor to
        OUT     DX, AL            ; the DIVISOR_LATCH to update part
                                  ; of the baud rate.
        
        MOV     DX, LATCH_MSB     ; Write high byte of divisor to  
        MOV     AL, AH            ; the LATCH_MSB to finish writing the    
        OUT     DX, AL            ; baud rate. 
        
        %CRITICAL_END             ; End of critical code.
        

        RET

SetSerialDivisor  ENDP

CODE    ENDS
        END
