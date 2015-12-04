        NAME    INITSERI
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  INITSERI                                    ;
;                             Serial Functions                                 ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contains the general purpose initialization function and other
; setter functions for the TL16C450 Serial Chip.
;
; Public functions:
; InitSerialChip()          - initializes the serial chip.
; SetSerialDivisor(divisor) - sets the divisor latch on the serial
; SetLineCtrlReg(value)     - sets the value of the Line Control Register manually
;                             letting the programmer control all options. 
; SetParity(parity)         - sets the parity configuration of the channel in LCR.
;
; Local functions:
; None.
;
; Revision History:
; 		11/19/15  David Qu		initial revision.

; local include files
$INCLUDE(genMacro.inc)
$INCLUDE(initSeri.inc)
$INCLUDE(handler.inc)
$INCLUDE(eoi.inc)

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
; Input:             Serial chip - reads LCR value to preserve it before
;                                  writing the divisor bits.
; Output:            Serial chip - writes to various registers set up the chip. 
;                                  See the TL16C450 data sheet for details.
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
        
        MOV     AX, INIT_BAUD_DIVISOR   ; Initialize the serial divisor registers
        CALL    SetSerialDivisor        ; to the INIT_BAUD_DIVISOR specified
                                        ; in initSeri.inc. This determines
                                        ; the sending rate.
        
        MOV     DX, INT_ENABLE_REG      ; Initialize IER to
        MOV     AL, ENABLE_SERIAL_INT   ; enable all interrupts so
        OUT     DX, AL                  ; event handlers will be called.
        
        MOV     DX, INT2Ctrl            ; initialize interrupt controller
        MOV     AX, INT2CtrlVal         ; for INT 2.
        OUT     DX, AX
        
        MOV     DX, INTCtrlrEOI ;send a non spec EOI (to clear out controller)
        MOV     AX, INT2EOI
        OUT     DX, AL

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
; Input:             Serial chip - read from LCR to preserve it.
; Output:            Serial chip - writes to LCR to access and set divisor. 
;                                  See the TL16C450 data sheet for details.
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
; Registers Changed: flags, AX, BX, CX, DX.
; Special notes:     None.
SetSerialDivisor  PROC     NEAR
                  PUBLIC   SetSerialDivisor
        
        MOV		CX, AX						; Save a copy of the current argument.
        MOV     DX, LINE_CTRL_REG           ; Read current LCR value and
        IN      AL, DX                      ; set the DLAB.
        MOV     BL, AL                      ; Save a copy of the current LCR val.
        OR      AL, ENABLE_DIVISOR_LATCH    ; value to restore.
        
        %CRITICAL_START           ; Entering critical code because
                                  ; we don't want to be interrupted while
                                  ; the divisor latch is enabled. (This will 
                                  ; lead to improper writes in the EH).
                                  
        OUT     DX, AL            ; Divisor latch is now enabled.
        
        
        MOV		AX, CX
        MOV     DX, DIVISOR_LATCH ; Write low byte of divisor to
        OUT     DX, AL            ; the DIVISOR_LATCH to update part
                                  ; of the baud rate.
        
        MOV     DX, LATCH_MSB     ; Write high byte of divisor to  
        MOV     AL, AH            ; the LATCH_MSB to finish writing the    
        OUT     DX, AL            ; baud rate. 
        
        MOV     DX, LINE_CTRL_REG ; Restore the original LCR value.
        MOV     AL, BL
        OUT     DX, AL
        
        %CRITICAL_END             ; End of critical code.
        

        RET

SetSerialDivisor  ENDP

; SetLineCtrlReg(value)
; 
; Description:       Writes the passed value in AL to the line control register.
;                    This function gives fine control over the LCR, which sets
;                    the serial character size, extra stop bits, parity,
;                    break
; Operation:         Outs the passed value in AL to the line control register.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   output (DX) - output address.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Serial chip - writes to LCR.
;                                  See the TL16C450 data sheet for details.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AL, DX.
; Special notes:     None.
SetLineCtrlReg  PROC     NEAR
                PUBLIC   SetLineCtrlReg
        
        MOV     DX, LINE_CTRL_REG   ; Output the value in AL
        OUT     DX, AL              ; to the LCR.
        
        RET

SetLineCtrlReg  ENDP



; SetParity(parity)
; 
; Description:       Sets the parity bits to one the values specified by the
;                    parity argument in AH. This must be one of NO_PARITY,
;                    EVEN_PARITY, ODD_PARITY, EVEN_STICK_PARITY, and
;                    ODD_STICK_PARITY. This design allows a programmer to
;                    construct a table of these values to have a UI button
;                    that will toggle through the table easily with a simple
;                    call to SetParity(parity).
;                    
; Operation:         Read in the old line control reg value into AL, and then
;                    remove the parity bits and add in the new parity bits. 
;                    Then output through AL.
;
; Arguments:         parity (AH).
; Return Value:      None.
;
; Local Variables:   lcr_value (AL) - value of the LCR before the change occurs.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Reads from the line control register in the serial chip.
; Output:            Writes to the line control register in the serial chip.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, DX.
; Special notes:     None.
SetParity       PROC     NEAR
                PUBLIC   SetParity
                
        MOV     DX, LINE_CTRL_REG   ; Read in the current line control register
        IN      AL, DX              ; value to save the non parity bits.
        
        AND     AL, NOT LCR_PARITY_MASK ; Remove the parity bits using a bit mask.
        OR      AL, AH                  ; Add the desired parity bits.
        OUT     DX, AL                  ; Output to the LCR.
        
        RET

SetParity       ENDP


CODE    ENDS

        END
