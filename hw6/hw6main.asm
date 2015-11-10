        NAME    HW6MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW6MAIN                                  ;
;                            Homework #6 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the motor functions for Homework #6.  
;                   First, it initializes the chip select, timer interrupts,
;                   and, motor shared variables. Then it calls the MotorTest
;                   function to test the keypad. This procedure runs each
;                   test case and then waits for a keypress before moving on 
;                   to the next test case. The test case number is displayed
;                   on the LED display.
;
; Input:            Keypad.
; Output:           Display, parallel output (82C55A chip).
;
; User Interface:   The user needs to connect to a motor set up or a
;                   oscilloscope to test the PWM signal. The test run through
;                   the function calls described at:
;                   wolverine.caltech.edu/eecs51/homework/hw6/hw6test.htm
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
;    11/12/15  David Qu	               initial revision
;    11/13/15  David Qu                updated comments

; local include files


CGROUP  GROUP   CODE


CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DATA, SS:STACK, ES:NOTHING


; external function declarations

		EXTRN	InitCS:NEAR			        ;Initialize Chip Select.
        EXTRN   ClrIRQVectors:NEAR          ;Clear Interrupt Vector Table.
        EXTRN   InstallTimer0Handler:NEAR   ;Install motor handlers on timer 0.
        EXTRN   InitTimer0:NEAR             ;Initialize timer 0.
		EXTRN 	InitMotors:NEAR             ;Initialize motor shared variables.
		EXTRN   MotorTest:NEAR              ;Tests various motor speeds and angles.

START:  

MAIN:
        MOV     AX, STACK              ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DATA              ;initialize the data segment
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
