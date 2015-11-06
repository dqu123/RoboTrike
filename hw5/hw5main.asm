        NAME    HW5MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW5MAIN                                  ;
;                            Homework #5 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the keypad functions for Homework #5.  
;                   First, it initializes the timer interrupts and keypad
;					shared variables.
;
; Input:            Keypad.
; Output:           None.
;
; User Interface:   The user can set breakpoints at hw5test to test 
;					different keypresses.
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


        ASSUME  CS:CGROUP, DS:DATA


; external function declarations

		EXTRN	InitCS:NEAR			
        EXTRN   ClrIRQVectors:NEAR          
        EXTRN   InstallTimer0Handler:NEAR
        EXTRN   InstallTimer1Handler:NEAR
        EXTRN   InitTimer0:NEAR
		EXTRN	InitTimer1:NEAR		
		EXTRN 	InitKeypad:NEAR
        EXTRN   InitDisplay:NEAR
		EXTRN	KeyTest:NEAR

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

        
        CALL    InstallTimer0Handler
        CALL    InstallTimer1Handler    ;install the event handler
                                        ;   ALWAYS install handlers before
                                        ;   allowing the hardware to interrupt.

		CALL 	InitKeypad				;initialize keypad shared variables.
        CALL    InitDisplay             ;initialize display shared variables.
		
        CALL    InitTimer0             
        CALL    InitTimer1              ;initialize the internal timer
        STI                             ;and finally allow interrupts.

		CALL 	KeyTest				;run test routines.
 
InfiniteLoop:
        JMP     InfiniteLoop   

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
