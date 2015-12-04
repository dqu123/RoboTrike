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
; Public functions:
; None.
;
; Local functions:
; DisplayStatus      - display a status value with character to designate what
;                      parameter is being displayed.
; DoSerialErrorEvent - handle remote serial error.
; DoSerialDataEvent  - handle remote serial data.
; DoKeypadEvent      - Handle keypad events by calling the keypad table.
;
; Tables:
; RemoteEventActionTable - actions for each remote event in a switch table.
; RemoteSerialErrorTable - error messages for remote serial errors.
; KeypadCommandTable     - commands for each keypress.
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


; Remote main shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state            DB  ?   ; state of remote main loop (based on received)
    speed_index      DB  ?   ; current index in the speed buffer.
    speed_buffer     DB BUFFER_SIZE DUP (?) ; speed status of motor.
    direction_index  DB  ?   ; current index in the direction buffer.
    direction_buffer DB BUFFER_SIZE DUP (?) ; direction status of motor.
    error_index      DB  ?   ; current index in the error buffer.
    error_buffer	 DB	BUFFER_SIZE	DUP (?) ; buffer of last motor error.
    eventQueue       queueSTRUC<> ; Event queue. This is a word queue that
                                 ; holds events.
DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START