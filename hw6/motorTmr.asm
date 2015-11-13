       NAME  motorTmr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                    motorTmr                                ;
;                Timer Event Handler Initialization Routines                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the functions for initializing the 80188 timer 0 interrupt
; that will manage the Robotrike. motors. The public functions included are:
;	InstallTimer0Handler - add the multiplexing timer 0 event handler to the IVT.
; 	InitTimer0		     - initialize timer0 interrupts.
;
; Revision History:
;    11/12/15  David Qu          initial revision.

; local include files
$INCLUDE(motorTmr.inc)
$INCLUDE(eoi.inc)



CGROUP	GROUP	CODE 


CODE 	SEGMENT PUBLIC 'CODE'


		ASSUME 	CS:CGROUP
		
; external function declarations
			
        EXTRN   HandleMotors:NEAR     ;Motor event handler.
 
 
 
; InstallTimer0Handler
;
; Description:       Install the event handler for the timer 0 interrupt.
;
; Operation:         Writes the address of the timer event handler to the
;                    appropriate interrupt vector.
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
; Registers Changed: flags, AX, ES
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Jan. 28, 2002

InstallTimer0Handler  PROC    NEAR
                      PUBLIC  InstallTimer0Handler

        XOR     AX, AX          ;clear ES (interrupt vectors are in segment 0)
        MOV     ES, AX
                                ;store the vector
        MOV     ES: WORD PTR (Tmr0VecOffset), OFFSET(HandleMotors)
        MOV     ES: WORD PTR (Tmr0VecSeg), SEG(HandleMotors)


        RET                     ;all done, return


InstallTimer0Handler  ENDP


       
; InitTimer0
;
; Description:       Initialize the 80188 Timer 0.  Timer 0 is initialized
;                    to generate interrupts every millisecond.
;                    The interrupt controller is also initialized to allow the
;                    timer interrupts.  Timer #0 then counts COUNTS_PER_MS 
;                    clocks to generate the interrupts at 1 kHz, which is good
;                    enough to multiplex an 8 digit display (8 * 30Hz = 240).
;
; Operation:         The appropriate values are written to the timer control
;                    registers in the PCB.  Also, the timer count registers
;                    are reset to zero.  Finally, the interrupt controller is
;                    setup to accept timer interrupts and any pending
;                    interrupts are cleared by sending a TimerEOI to the
;                    interrupt controller.
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
; Last Modified:     Oct. 31, 2015 (David Qu)

InitTimer0      PROC    NEAR
				PUBLIC	InitTimer0
				
                                ;initialize Timer #0 for 1 ms interrupts
        MOV     DX, Tmr0Count   ;initialize the count register to 0
        XOR     AX, AX
        OUT     DX, AL

        MOV     DX, Tmr0MaxCntA     ;setup max count of timer clocks
        MOV     AX, COUNTS_PER_MS   ;so can time digits
        OUT     DX, AL

        MOV     DX, Tmr0Ctrl    ;setup the control register, interrupts on
        MOV     AX, Tmr0CtrlVal
        OUT     DX, AL

                                ;initialize interrupt controller for timers
        MOV     DX, INTCtrlrCtrl;setup the interrupt control register
        MOV     AX, INTCtrlrCVal
        OUT     DX, AL

        MOV     DX, INTCtrlrEOI ;send a timer EOI (to clear out controller)
        MOV     AX, TimerEOI
        OUT     DX, AL


        RET                     ;done so return


InitTimer0       ENDP



CODE        ENDS

            END