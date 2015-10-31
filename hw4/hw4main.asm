        NAME    HW4MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW4MAIN                                  ;
;                            Homework #4 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the display functions for Homework #4.  
;                   First, it initializes the timer interrupts and display
;					display buffer to show a blank display until something is 
;					written to the display buffer. Then, it calls each display 
;                   function with some test values using the DisplayTest 
;					function defined in HW4TEST.OBJ. After a few initial test
;					cases, the test continues to call the hw4test.HexDisplay
;					and hw4test.DecimalDisplay functions, so the program can
;					be tested by values input in the debugger.
;
; Input:            None.
; Output:           None.
;
; User Interface:   No real user interface.  The user can set breakpoints at 
;                   hw4test.HexDisplay and hw4test.DecimalDisplay to test 
;					different values.
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
;    10/29/15  David Qu	               initial revision

; local include files


CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK



CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP


; external function declarations

		EXTRN	InitCS:NEAR			
        EXTRN   ClrIRQVectors:NEAR          
        EXTRN   InstallHandler:NEAR     
		EXTRN	InitTimer:NEAR		
		EXTRN 	InitDisplay:NEAR
		EXTRN	Display:NEAR			
		EXTRN	DisplayNum:NEAR			
		EXTRN	DisplayHex:NEAR
		EXTRN	DisplayTest:NEAR

START:  

MAIN:
        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX


        CALL    InitCS                  ;initialize the 80188 chip selects
                                        ;   assumes LCS and UCS already setup

        CALL    ClrIRQVectors           ;clear (initialize) interrupt vector table

        CALL    InstallHandler          ;install the event handler
                                        ;   ALWAYS install handlers before
                                        ;   allowing the hardware to interrupt.

		CALL 	InitDisplay				;initialize display shared variables.
		
        CALL    InitTimer               ;initialize the internal timer
        STI                             ;and finally allow interrupts.

		CALL 	DisplayTest				;run test routines.

        HLT                             ;never executed (hopefully)

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
