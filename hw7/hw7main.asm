        NAME    HW7MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW7MAIN                                  ;
;                            Homework #7 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                  David Qu                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the serial functions for Homework #7.  
;                   First, it initializes the chip select, serial IO registers,
;                   and serial shared variables. Then it calls the SerialIOTest
;                   function to test the keypad. This procedure runs each
;                   test case and then waits for a keypress before moving on 
;                   to the next test case. The test case number is displayed
;                   on the LED display.
;
; Input:            Serial Input.
; Output:           Display.
;
; User Interface:   None.
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
;    11/19/15  David Qu	               initial revision

; local include files
$INCLUDE(genMacro.inc)
$INCLUDE(handler.inc)


CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK

CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP, SS:DGROUP, ES:NOTHING


; external function declarations

		EXTRN	InitCS:NEAR			        ;Initialize Chip Select.
        EXTRN   ClrIRQVectors:NEAR          ;Clear Interrupt Vector Table.
        EXTRN   HandleSerial:NEAR           ;Serial handler function.
        EXTRN   InitSerialChip:NEAR         ;Initialize serial chip registers.
		EXTRN 	InitSerialVars:NEAR         ;Initialize serial shared variables.
		EXTRN   SerialIOTest:NEAR           ;Tests serial behavior.

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

        
        %INSTALL_HANDLER(INT_14, INT_14_SEGMENT, HandleSerial) ;install the event handler
                                        ;   ALWAYS install handlers before
                                        ;   allowing the hardware to interrupt.

		
        CALL    InitSerialVars          ;initialize the serial shared variables
       

		CALL 	InitSerialChip          ;initialize the serial chip registers
        STI                             ;and finally allow interrupts.

		CALL 	SerialIOTest	        ;run serial test routine. This should never
                                        ;return.
InfiniteLoop:
        JMP     InfiniteLoop
        
        RET                             ;Exit program.

CODE    ENDS


; the data segment 
; (required for C compatibility).
DATA    SEGMENT PUBLIC  'DATA'

DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START
