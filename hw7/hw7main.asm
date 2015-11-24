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
;                   function to test the serial. A program such as RealTerm:
;                   Serial Capture Program is needed to view the output from
;                   the serial chip. The string "EE/CS 51 -- the quick brown
;                   fox jumped over the lazy block dog\r\n" is output 100 times
;                   numbered from 0 to 99. The user can test the SetSerialBaudRate
;                   and ToggleParity functions by changing the constants defined
;                   in hw7main.inc (TOGGLE_PARITY_NUM, and TEST_BAUD_RATE).
;
; Input:            Serial Input - reads various serial registers.
; Output:           Serial Output - writes to various serial registers.
;
; User Interface:   None.
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
;    11/21/15  David Qu                added comments, more testing options
;    11/22/15  David Qu                fixed error with loop

; local include files
$INCLUDE(genMacro.inc)
$INCLUDE(handler.inc)
$INCLUDE(hw7main.inc)


CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK

CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP, ES:NOTHING


; external function declarations

		EXTRN	InitCS:NEAR			        ;Initialize Chip Select.
        EXTRN   ClrIRQVectors:NEAR          ;Clear Interrupt Vector Table.
        EXTRN   HandleSerial:NEAR           ;Serial handler function.
        EXTRN   InitSerialChip:NEAR         ;Initialize serial chip registers.
		EXTRN 	InitSerialVars:NEAR         ;Initialize serial shared variables.
		EXTRN   SerialIOTest:NEAR           ;Tests serial behavior.
        EXTRN   SetSerialBaudRate:NEAR      ;Sets the baud rate.
        EXTRN   ToggleParity:NEAR           ;Toggles the parity setting.

START:  

MAIN:
        MOV     AX, DGROUP              ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(DGROUP:TopOfStack)

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
        
        ; Test parity setting
        MOV     CX, TOGGLE_PARITY_NUM   ; Toggle parity TOGGLE_PARITY_NUM times.
MainTestParity:
        CALL    ToggleParity            ; Toggles at least once.
        DEC     CX
        JNZ     MainTestParity
        ;JZ     MainTestBaudRate
        
MainTestBaudRate:        
        MOV     BX, TEST_BAUD_RATE      ;Test set baud rate.
        CALL    SetSerialBaudRate
        
        STI                             ;and finally allow interrupts.

		CALL 	SerialIOTest	        ;run serial test routine. This should never
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
