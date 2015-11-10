        NAME    HW5MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW5MAIN                                  ;
;                            Homework #6 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the keypad functions for Homework #5.  
;                   First, it initializes the chip select, timer interrupts,
;                   and, display and keypad shared variables. Then it calls
;                   the KeyTest function to test the keypad.
;
; Input:            Keypad.
; Output:           Display.
;
; User Interface:   The user can press various key combinations, and any
;                   resulting events will displayed on the LED display. The
;                   keypress and the number of times it has been pressed will 
;                   be displayed.
;
; Error Handling:   None.
;
; Algorithms:       None.
; Data Structures:  None.
;
; Known Bugs:       None.
; Limitations:      None.
;
; Revision History:
;    11/5/15  David Qu	               initial revision
;    11/6/15  David Qu                 added comments

; local include files


CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK



CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP


; external function declarations

		EXTRN	InitCS:NEAR			        ;Initialize Chip Select.
        EXTRN   ClrIRQVectors:NEAR          ;Clear Interrupt Vector Table.
        EXTRN   InstallTimer0Handler:NEAR   ;Install motor handlers on timer 0.
        EXTRN   InitTimer0:NEAR             ;Initialize timer 0.
		EXTRN 	InitMotors:NEAR             ;Initialize motor shared variables.
		EXTRN   MotorTest:NEAR                ;Shows enqueued events in display.

START:  

MAIN:
        MOV     AX, DGROUP              ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DGROUP              ;initialize the data segment
        MOV     DS, AX


        CALL    InitCS                  ;initialize the 80188 chip selects
                                        ;   assumes LCS and UCS already setup

        CALL    ClrIRQVectors           ;clear (initialize) interrupt vector table

        
        CALL    InstallTimer0Handler    ;install the event handler
                                        ;   ALWAYS install handlers before
                                        ;   allowing the hardware to interrupt.

		CALL 	InitMotors
		
        CALL    InitTimer0              ;initialize the internal timer
        STI                             ;and finally allow interrupts.

		CALL 	MotorTest				;run test routine.

        RET                             ;Exit program.

CODE    ENDS


; the data segment
DATA    SEGMENT PUBLIC  'DATA'

DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START
