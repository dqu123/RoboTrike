;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                HW9/10 Outline                                ;
;                                 David Qu                                     ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; Main loops:
; RemoteMain     - run remote main loop
; MotorMain      - run motor system main loop
;
; Files: motorMn.asm, remoteMn.asm, event.asm
; Event Public functions:
; EnqueueEvent
;  
; Motor Public functions: 
;
; Motor local functions: 
; SendSpeed
; SendDirection 
;
; Remote Public functions:
; EnqueueEvent   - 
;
; Local functions:
; Function2   - 
; File Serial.asm
; Public functions:
; SerialSendString
;
; File: remoteMn.asm 
; Main loop:
; RemoteMain     - run remote main loop
;
; Public functions:
; EnqueueEvent   -  
;
; Local functions:
; DisplayStatus      - display a status value with character to designate what
;                      parameter is being displayed.
; DoSerialErrorEvent -
; DoSerialDataEvent  -
; DoKeypadEvent      - Handle keypad events by calling the keypad table
;
; Tables:
; ParserError
; RemoteEventActionTable
; SerialErrorTable
; KeypadCommandTable
;
; File: motorMn.asm
; MotorMain         - run motor main loop
; 
; Public functions:
; EnqueueEvent  
;
; Local functions:
; MtrSerialErrorEvent -
; MtrSerialDataEvent  -
; DoNop


; Constants
BUFFER_SIZE             EQU     32      ; Size of string buffer.

; states
SPEED_STATE             EQU     0       ; Reading speed.
DIRECTION_STATE         EQU     1       ; Reading direction.
ERROR_STATE             EQU     2       ; Reading error.

; Remote Event constants
SERIAL_ERROR_EVENT  EQU     0       ; Value for a serial error event.
SERIAL_DATA_EVENT   EQU     2       ; Value for a serial data event.
KEYPRESS_EVENT      EQU     4       ; Value for a keypress event.

END_CMD             EQU     13      ; ASCII for carriage return.

; external function declarations
        EXTRN   QueueInit:NEAR          ; Initializes queue.
        EXTRN   QueueEmpty:NEAR         ; Checks if queue is empty. 
		EXTRN	QueueFull:NEAR			; Checks if queue is full. 
		EXTRN	Dequeue:NEAR			; Removes element from queue. 
		EXTRN	Enqueue:NEAR			; Adds element to queue. 
        EXTRN   SerialSendString:NEAR   ; Send a string through the serial.
        EXTRN   Dec2String:NEAR         ; Signed word to decimal string.
        EXTRN   UnsignedDec2String:NEAR ; Unsigned word to decimal string.

; Read-only tables
ParserError LABEL   BYTE
        DB      'ParseErr', 0       ; Motor parser error string.

RemoteEventActionTable LABEL   WORD ; Table of functions for
        DW      DoSerialErrorEvent  ; the switch statement in 
        DW      DoSerialDataEvent   ; the remote main loop. These functions handle
        DW      DoKeypadEvent       ; various event types.

RemoteEventActionTable LABEL   WORD ; Table of functions for
        DW      DoSerialErrorEvent  ; the switch statement in 
        DW      DoSerialDataEvent   ; the remote main loop. These functions handle
        DW      DoKeypadEvent       ; various event types.

; Fixed Length String Tables
;
; Description:      This table contains the fixed length strings used in a
;                   parity selection menu system.  The tables are defined
;                   using macros.
;
; Author:           Glen George
; Last Modified:    Mar. 30, 2001

; this macro sets up the table of fixed length strings

; this macro defines the table entries - note that it checks the size
%*DEFINE(TABENT(string))  (
        DB      %string, 0		%' define the string '
    %IF (%length EQ 0)  THEN  (		%' check to be sure string length is correct '
        %SET(length, %LEN(%string))	%' first string, get the length '
    )  ELSE  (
        %IF (%length NE %LEN(%string))  THEN  (	%' 2+ string - check length '
            %OUT(Non-fixed length strings)	%' unmatched length error '
        )  FI
    )  FI
)

%*DEFINE(STRFIXTABLE)  (
	%SET(length, 0)			;don't know length yet
        %TABENT('PArity E')             ;even parity
        %TABENT('PArity o')             ;odd parity
        %TABENT('PArity 1')		;mark (1) parity
        %TABENT('PArity 0')		;space (0) parity
        %TABENT('PArity n')		;no parity
)

;actually create the table
ParityMenuStringsF  LABEL       BYTE

        %STRFIXTABLE

STRFIXLength	EQU	%length - 1	; the length of the table strings
					;    - 1 because we were counting the delimiters too
                    ; but we add a NULL char.
                    
%*DEFINE(STRFIXTABLE)  (
	%SET(length, 0)			;don't know length yet
        
        %TABENT('R_ParErr')    ; remote serial parity error
        %TABENT('R_FrmErr')	   ; remote serial frame error
        %TABENT('R_OvrErr')	   ; remote serial overrun error
        %TABENT('R_BufErr')	   ; remote serial buffer overflow
        %TABENT('M_ParErr')    ; motor serial parity error
        %TABENT('M_FrmErr')	   ; motor serial frame error
        %TABENT('M_OvrErr')	   ; motor serial overrun error
        %TABENT('M_BufErr')	   ; motor serial buffer overflow
        %TABENT('UnkwnErr')    ; unknown error.
)

;actually create the table
SerialErrorTable  LABEL       BYTE

        %STRFIXTABLE

SERIAL_ERROR_STR_LENGTH	    EQU	    %length - 1	; the length of the table strings
					;    - 1 because we were counting the delimiters too
                    ; but we add a NULL char.

                    
                    
; End command (Carriage Return), null terminated strings.
%*DEFINE(TABENT(string))  (
        DB      %string, END_CMD, 0 %' define the string '
    %IF (%length EQ 0)  THEN  (		%' check to be sure string length is correct '
        %SET(length, %LEN(%string))	%' first string, get the length '
    )  ELSE  (
        %IF (%length NE %LEN(%string))  THEN  (	%' 2+ string - check length '
            %OUT(Non-fixed length strings)	%' unmatched length error '
        )  FI
    )  FI
)
                    
; Keypad layout
; 0  1  2  3
; 4  5  6  7
; 8  9  10 11
; 12 13 14 15
%*DEFINE(STRFIXTABLE)  (
	%SET(length, 0)			;don't know length yet
        ; Row 0 of keypad
        %TABENT('      ')   ; 00H 
        %TABENT('      ')   ; 01H 
        %TABENT('      ')   ; 02H
        %TABENT('      ')   ; 03H 
        %TABENT('      ')   ; 04H
        %TABENT('      ')   ; 05H
        %TABENT('      ')   ; 06H
        %TABENT('      ')   ; 07H  Button 3
        %TABENT('      ')   ; 08H 
        %TABENT('      ')   ; 09H 
        %TABENT('      ')   ; 0AH
        %TABENT('      ')   ; 0BH  Button 2
        %TABENT('      ')   ; 0CH 
        %TABENT('      ')   ; 0DH  Button 1
        %TABENT('      ')   ; 0EH  Button 0
        %TABENT('      ')   ; 0FH
        
        %TABENT('      ')   ; 10H 
        %TABENT('      ')   ; 11H 
        %TABENT('      ')   ; 12H
        %TABENT('      ')   ; 13H 
        %TABENT('      ')   ; 14H
        %TABENT('      ')   ; 15H
        %TABENT('      ')   ; 16H
        %TABENT('      ')   ; 17H  Button 7
        %TABENT('      ')   ; 18H 
        %TABENT('      ')   ; 19H 
        %TABENT('      ')   ; 1AH
        %TABENT('      ')   ; 1BH  Button 6
        %TABENT('      ')   ; 1CH 
        %TABENT('      ')   ; 1DH  Button 5
        %TABENT('      ')   ; 1EH  Button 4
        %TABENT('      ')   ; 1FH
        
        %TABENT('      ')   ; 20H 
        %TABENT('      ')   ; 21H 
        %TABENT('      ')   ; 22H
        %TABENT('      ')   ; 23H 
        %TABENT('      ')   ; 24H
        %TABENT('      ')   ; 25H
        %TABENT('      ')   ; 26H
        %TABENT('S0    ')   ; 27H  Button 11 (stop command)
        %TABENT('      ')   ; 28H 
        %TABENT('      ')   ; 29H 
        %TABENT('      ')   ; 2AH
        %TABENT('V+1000')   ; 2BH  Button 10 (forward command)
        %TABENT('      ')   ; 2CH 
        %TABENT('V-1000')   ; 2DH  Button 9  (slow down command)
        %TABENT('F     ')   ; 2EH  Button 8  (fire laser command)
        %TABENT('      ')   ; 2FH
        
        %TABENT('      ')   ; 30H 
        %TABENT('      ')   ; 31H 
        %TABENT('      ')   ; 32H
        %TABENT('      ')   ; 33H 
        %TABENT('      ')   ; 34H
        %TABENT('      ')   ; 35H
        %TABENT('      ')   ; 36H
        %TABENT('D-0030')   ; 37H  Button 15 (move right command)
        %TABENT('      ')   ; 38H 
        %TABENT('      ')   ; 39H 
        %TABENT('      ')   ; 3AH
        %TABENT('D+0180')   ; 3BH  Button 14 (reverse command)  
        %TABENT('      ')   ; 3CH 
        %TABENT('D+0030')   ; 3DH  Button 13 (move left command)
        %TABENT('O     ')   ; 3EH  Button 12 (laser off command)
        %TABENT('      ')   ; 3FH

)

; Table which 
KeypadCommandTable  LABEL       BYTE

        %STRFIXTABLE

KEYPAD_COMMAND_STR_LENGTH	    EQU	    %length	; the length of the table strings
					;    +0 because we were counting the delimiters too, but
                    ; we add END_CMD and NULL characters.
                    
; Remote main shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state            DB  ?   ; state of remote main loop (based on received)
    speed_buffer     DB BUFFER_SIZE DUP (?) ; speed status of motor.
    direction_buffer DB BUFFER_SIZE DUP (?) ; direction status of motor
    error_buffer	 DB	BUFFER_SIZE	DUP (?) ; buffer of last error
    eventQueue       queueSTRUC<> ; Event queue. This is a word queue that
                                 ; holds events.
    
DATA    ENDS

; Motor main shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    str_buffer		 DB	BUFFER_SIZE	DUP (?) ; buffer for building strings.
    eventQueue       queueSTRUC<> ; Event queue. This is a word queue that
                                 ; holds events.
    
DATA    ENDS
                    

; Serial Main 
; Pseudo code: 
; while (true)
;    if (!eventQueue.empty()) 
;        unsigned word event = eventQueue.dequeue()
;        RemoteEventActionTable[event.type].action(event.value) 
        
; Motor Main
; Pseudo code:
; while (true)
;    if (!eventQueue.empty()) 
;        unsigned word event = eventQueue.dequeue()
;        MotorEventActionTable[event.type].action(event.value)


; DoKeypadEvent
; 
; Description:       
; Operation:         
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; switch (keycode):
; case (DISPLAY_SPEED_KEY): 
;     Display(speed_buffer)
;     break
; case (DISPLAY_DIRECTION_KEY):
;     Display(direction_buffer)
;     break
; case (DISPLAY_ERROR_KEY):
;     Display(error_buffer)
; default:
;     SerialSendString(KeypadCommandTable[keycode * KEYPAD_COMMAND_STR_LENGTH])


; SerialSendString(char* string) Pseudo code:
; unsigned word i = 0;
; do 
;     char = string[i]
;     do
;         SerialPutChar(char)
;     while (CF != 0)
; while (char != NULL)