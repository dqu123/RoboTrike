        NAME    REMOTEMN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                             ROBOTRIKE REMOTE MAIN                          ;
;                                  EE/CS  51                                 ;
;                                  David Qu                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This
;
; Input:            None.
; Output:           None.
;
; User Interface:   The user can press buttons on the
; Error Handling:   None.
;
; Algorithms:       None.
; Data Structures:  None.
;
; Known Bugs:       None.
; Limitations:      None.
;
; Revision History:
;    12/3/15  David Qu	               initial revision
; local include files

CGROUP  GROUP   CODE

CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DATA, ES:NOTHING


; external function declarations
        EXTRN   InitCS:NEAR             ;initialize chip select
        EXTRN   InitParser:NEAR         ;initialize shared variables
		EXTRN   ParseTest:NEAR          ;tests parser behavior.

START:  

MAIN:
        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX
        
        CALL    InitCS                  ;initialize chip select.
        
        CALL    InitParser              ;initialize parser shared varibles,
                                        ;so the parser will start in the
                                        ;RESET_STATE.
       
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