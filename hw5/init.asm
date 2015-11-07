       NAME  init

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                    init                                    ;
;                     RoboTrike Board Initialization Routines                ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the functions for initializing the 80188 board. 
; The public functions included are:
;	InitCS			- initialize the peripheral chip selects.
;	ClrIRQVectors	- initialize all event handlers to IllegalEventHandler.
;
; The local functions included are:
;	IllegalEventHandler	- gives a convenient breakpoint for debugging unexpected
;					      interrupts.
;
; Revision History:
;
;    10/29/15  David Qu	 	     initial revision, added Glen's code.
;	 10/30/15  David Qu			 updated ToC.
;    11/5/15   David Qu          moved code to init.asm.


; local include files
$INCLUDE(init.INC)
$INCLUDE(eoi.INC)


CGROUP	GROUP	CODE 


CODE 	SEGMENT PUBLIC 'CODE'


		ASSUME 	CS:CGROUP
; InitCS
;
; Description:       Initialize the Peripheral Chip Selects on the 80188.
;
; Operation:         Write the initial values to the PACS and MPCS registers.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
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
; Registers Changed: AX, DX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Oct. 29, 1997

InitCS  PROC    NEAR
		PUBLIC	InitCS

        MOV     DX, PACSreg     ;setup to write to PACS register
        MOV     AX, PACSval
        OUT     DX, AL          ;write PACSval to PACS

        MOV     DX, MPCSreg     ;setup to write to MPCS register
        MOV     AX, MPCSval
        OUT     DX, AL          ;write MPCSval to MPCS 


        RET                     ;done so return


InitCS  ENDP

; ClrIRQVectors
;
; Description:      This functions installs the IllegalEventHandler for all
;                   interrupt vectors in the interrupt vector table.  Note
;                   that all 256 vectors are initialized so the code must be
;                   located above 400H.  The initialization skips  (does not
;                   initialize vectors) from vectors FIRST_RESERVED_VEC to
;                   LAST_RESERVED_VEC.
;
; Arguments:        None.
; Return Value:     None.
;
; Local Variables:  CX    - vector counter.
;                   ES:SI - pointer to vector table.
; Shared Variables: None.
; Global Variables: None.
;
; Input:            None.
; Output:           None.
;
; Error Handling:   None.
;
; Algorithms:       None.
; Data Structures:  None.
;
; Registers Used:   flags, AX, CX, SI, ES
; Stack Depth:      0 words.
;
; Author:           Glen George
; Last Modified:    Nov 7, 2015 (David Qu)

ClrIRQVectors   PROC    NEAR
				PUBLIC	ClrIRQVectors

InitClrVectorLoop:              ;setup to store the same handler 256 times

        XOR     AX, AX          ;clear ES (interrupt vectors are in segment 0)
        MOV     ES, AX
        MOV     SI, 0           ;initialize SI 

        MOV     CX, NUM_IRQ_VECTORS ;number of vectors to initialize


ClrVectorLoop:                  ;loop clearing each vector
								;check if should store the vector
		CMP     SI, VECTOR_SIZE * FIRST_RESERVED_VEC
		JB		DoStore			;if before start of reserved field - store it
		CMP		SI, VECTOR_SIZE * LAST_RESERVED_VEC
		JBE		DoneStore		;if in the reserved vectors - don't store it
		;JA		DoStore			;otherwise past them - so do the store

DoStore:                        ;store the vector
        MOV     ES: WORD PTR [SI], OFFSET(IllegalEventHandler)
        MOV     ES: WORD PTR [SI + VECTOR_SEG], SEG(IllegalEventHandler)

DoneStore:						;done storing the vector
        ADD     SI, VECTOR_SIZE ;update pointer to next vector

        LOOP    ClrVectorLoop   ;loop until have cleared all vectors
        ;JMP    EndClrIRQVectors;and all done


EndClrIRQVectors:               ;all done, return
        RET


ClrIRQVectors   ENDP




; IllegalEventHandler
;
; Description:       This procedure is the event handler for illegal
;                    (uninitialized) interrupts.  It does nothing - it just
;                    returns after sending a non-specific EOI.
;
; Operation:         Send a non-specific EOI and return.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
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
; Registers Changed: None
; Stack Depth:       2 words
;
; Author:            Glen George
; Last Modified:     Dec. 25, 2000

IllegalEventHandler     PROC    NEAR

        NOP                             ;do nothing (can set breakpoint here)

        PUSH    AX                      ;save the registers
        PUSH    DX

        MOV     DX, INTCtrlrEOI         ;send a non-specific EOI to the
        MOV     AX, NonSpecEOI          ;   interrupt controller to clear out
        OUT     DX, AL                  ;   the interrupt that got us here

        POP     DX                      ;restore the registers
        POP     AX

        IRET                            ;and return


IllegalEventHandler     ENDP


CODE            ENDS

                END