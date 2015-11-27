        NAME    HW8MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW8MAIN                                  ;
;                            Homework #8 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                  David Qu                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the parser functions for Homework #8.
;                   First it initializes the chip select and parser shared
;                   variables. Then it calls the ParseTest function to test the
;                   parser with various strings.
;
; Input:            None.
; Output:           None.
;
; User Interface:   SerialPutChar is called with many 37 different path strings.
;                   Each path is a sequence of commands to test various error
;                   and command input conditions. The user can set breakpoints
;                   at hw8test.compareok and hw8test.miscompare to determine
;                   whether a path is working and check the hw8test.path
;                   against the hw8.test.exppathX to test path number X. The
;                   registers at the two breakpoints give information about
;                   the test status. BX gives the zero indexed path number
;                   DI is 64H if the paths match, and indicates the number of 
;                   the first misaligned path character. The details of the
;                   path encoding are given at  
;                   http://wolverine.caltech.edu/eecs51/homework/hw8/hw8test.htm
;                   along with path information.
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
;    11/26/15  David Qu                added InitParser call
;    11/27/15  David Qu                updated commments

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
