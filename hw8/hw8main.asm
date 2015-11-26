        NAME    HW8MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW8MAIN                                  ;
;                            Homework #8 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                  David Qu                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the parser functions for Homework #8.
;
; Input:            None.
; Output:           Motor functions are called, changing the motor speed
;                   and direction.
;
; User Interface:   SerialPutChar is called with many different strings.
; Error Handling:   None.
;
; Algorithms:       None.
; Data Structures:  None.
;
; Known Bugs:       None.
; Limitations:      None.
;
; Revision History:
;    11/25/15  David Qu	               initial revision


; local include files


CGROUP  GROUP   CODE

CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DATA, ES:NOTHING


; external function declarations
		EXTRN   ParseTest:NEAR          ;Tests parser behavior.

START:  

MAIN:
        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX

		CALL 	ParseTest	            ;run parser test routine. This should never
                                        ;return.
        
        RET                             ;Exit program.

CODE    ENDS


; the data segment 
DATA    SEGMENT PUBLIC  'DATA'
        ;nothing in the data segment but need it for initializaing DS.
DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START
