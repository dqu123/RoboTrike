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
; InitRemoteMain     - initialize remote main shared variables.
; DisplayStatus      - display a status value based on current state.
; DoSerialErrorEvent - handle remote serial error.
; DoSerialDataEvent  - handle remote serial data.
; DoKeypadEvent      - Handle keypad events by calling the keypad table.
;
; Tables:
; RemoteEventActionTable - actions for each remote event in a switch table.
; RemoteSerialErrorTable - error messages for remote serial errors.
; KeypadCommandTable     - commands for each keypress.
;
; Revision History:
;    12/3/15  David Qu	               initial revision
;
; local include files
$INCLUDE(general.inc)  ; General constants.
$INCLUDE(string.inc)   ; String buffer constants.
$INCLUDE(genMacro.inc) ; General macros.
$INCLUDE(handler.inc)  ; Handler values.
$INCLUDE(events.inc)   ; Event types.
$INCLUDE(remoteMn.inc) ; EOIs for event handler.

CGROUP  GROUP   CODE

CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DATA, ES:NOTHING


; external function declarations
		EXTRN	InitCS:NEAR			        ;Initialize Chip Select.
        EXTRN   ClrIRQVectors:NEAR          ;Clear Interrupt Vector Table.
        EXTRN   InstallTimer0Handler:NEAR   ;Install display multiplex on timer 0
        EXTRN   InstallTimer1Handler:NEAR   ;Install key debouncing on timer 1
        EXTRN   InitTimer0:NEAR             ;Initialize timer 0.
		EXTRN	InitTimer1:NEAR		        ;Initialize timer 1.
		EXTRN 	InitKeypad:NEAR             ;Initialize keypad shared variables.
        EXTRN   InitDisplay:NEAR            ;Initialize display shared variables. 
        EXTRN   SerialSendString:NEAR       ;Send a string through the serial.
        EXTRN   HandleSerial:NEAR           ;Serial handler function.
        EXTRN   InitSerialChip:NEAR         ;Initialize serial chip registers.
		EXTRN 	InitSerialVars:NEAR         ;Initialize serial shared variables.
        EXTRN   Display:NEAR                ;Display a string.
        EXTRN   InitEvents:NEAR             ;Initialize events module.
        EXTRN   DequeueEvent:NEAR           ;Dequeue an event from the eventQueue.
        EXTRN   GetCriticalError:NEAR       ;Determine if a critical error has
                                            ;occurred in the system.
        EXTRN   DoNOP:NEAR                  ;Does nothing.
        
; Read-only tables
ParserError LABEL   BYTE
        DB      'ParseErr', 0       ; Motor parser error string.

RemoteEventActionTable LABEL   WORD ; Table of functions for
        DW      DoSerialErrorEvent  ; the switch statement in 
        DW      DoSerialDataEvent   ; the remote main loop. These functions handle
        DW      DoKeypadEvent       ; various event types.
        DW      DoNOP

KeyActionTable      LABEL   WORD
        ; Row 0 of keypad
        DW      DoNOP       ; 00H 
        DW      DoNOP       ; 01H 
        DW      DoNOP       ; 02H
        DW      DoNOP       ; 03H 
        DW      DoNOP       ; 04H
        DW      DoNOP       ; 05H
        DW      DoNOP       ; 06H
        DW      DoNOP       ; 07H  Button 3
        DW      DoNOP       ; 08H 
        DW      DoNOP       ; 09H 
        DW      DoNOP       ; 0AH
        DW      DoNOP       ; 0BH  Button 2
        DW      DoNOP       ; 0CH 
        DW      DoNOP       ; 0DH  Button 1
        DW      DoNOP       ; 0EH  Button 0
        DW      DoNOP       ; 0FH
        
        DW      DoNOP       ; 10H 
        DW      DoNOP       ; 11H 
        DW      DoNOP       ; 12H
        DW      DoNOP       ; 13H 
        DW      DoNOP       ; 14H
        DW      DoNOP       ; 15H
        DW      DoNOP       ; 16H
        DW      DisplayBuffer ; 17H  Button 7 (Display error)
        DW      DoNOP       ; 18H 
        DW      DoNOP       ; 19H 
        DW      DoNOP       ; 1AH
        DW      DisplayBuffer ; 1BH  Button 6 (Display direction)
        DW      DoNOP       ; 1CH 
        DW      DisplayBuffer ; 1DH  Button 5 (Display speed)
        DW      SendKeypadCommand ; 1EH  Button 4 (Full speed ahead)
        DW      DoNOP       ; 1FH
        
        DW      DoNOP       ; 20H 
        DW      DoNOP       ; 21H 
        DW      DoNOP       ; 22H
        DW      DoNOP       ; 23H 
        DW      DoNOP       ; 24H
        DW      DoNOP       ; 25H
        DW      DoNOP       ; 26H
        DW      SendKeypadCommand ; 27H  Button 11 (stop command)
        DW      DoNOP       ; 28H 
        DW      DoNOP       ; 29H 
        DW      DoNOP       ; 2AH
        DW      SendKeypadCommand ; 2BH  Button 10 (forward command)
        DW      DoNOP       ; 2CH 
        DW      SendKeypadCommand ; 2DH  Button 9  (slow down command)
        DW      SendKeypadCommand ; 2EH  Button 8  (fire laser command)
        DW      DoNOP       ; 2FH
        
        DW      DoNOP       ; 30H 
        DW      DoNOP       ; 31H 
        DW      DoNOP       ; 32H
        DW      DoNOP       ; 33H 
        DW      DoNOP       ; 34H
        DW      DoNOP       ; 35H
        DW      DoNOP       ; 36H
        DW      SendKeypadCommand ; 37H  Button 15 (move right command)
        DW      DoNOP       ; 38H 
        DW      DoNOP       ; 39H 
        DW      DoNOP       ; 3AH
        DW      SendKeypadCommand ; 3BH  Button 14 (reverse command)  
        DW      DoNOP       ; 3CH 
        DW      SendKeypadCommand ; 3DH  Button 13 (move left command)
        DW      SendKeypadCommand ; 3EH  Button 12 (laser off command)
        DW      DoNOP       ; 3FH
        
; Fixed Length String Tables
;
; RemoteSerialErrorTable
; Description:      This table contains the remote serial error messages, which
;                   are immediately displayed when processed by the remote main
;                   loop. This is a fixed length string table.
;
; Author:           David Qu
; Last Modified:    Nov. 30, 2015

; this macro sets up the table of fixed length strings

; this macro defines the table entries - note that it checks the size
%*DEFINE(TABENT(string))  (
        DB      %string, ASCII_NULL %' define the string '
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
        
        %TABENT('R_ovrErr')	   ; remote serial overrun error
        %TABENT('R_parErr')    ; remote serial parity error
        %TABENT('R_frmErr')	   ; remote serial frame error
        %TABENT('R_brkErr')	   ; remote serial buffer overflow
        %TABENT('R_putErr')    ; error when calling SerialSendString.
)

                    
;actually create the table
RemoteSerialErrorTable  LABEL       BYTE

        %STRFIXTABLE
        
SERIAL_ERROR_STR_LENGTH	    EQU	    %length - 1	; the length of the table strings
					;    - 1 because we were counting the delimiters too
                    ; but we add a NULL char.                    
                    
; End command (Carriage Return), null terminated strings.
%*DEFINE(TABENT(string))  (
        DB      %string, ASCII_RETURN, ASCII_NULL %' define the string '
    %IF (%length EQ 0)  THEN  (		%' check to be sure string length is correct '
        %SET(length, %LEN(%string))	%' first string, get the length '
    )  ELSE  (
        %IF (%length NE %LEN(%string))  THEN  (	%' 2+ string - check length '
            %OUT(Non-fixed length strings)	%' unmatched length error '
        )  FI
    )  FI
)

; KeypadCommandTable 
; Description:      This table contains the command messages to send to the
;                   motor unit for each key combination. Unused keys, and keys
;                   that don't need to send any messages simply have spaces, 
;                   which are ignored by the parser. This is a fixed length 
;                   string table.
; Keypad layout
; 0  1  2  3
; 4  5  6  7
; 8  9  10 11
; 12 13 14 15
;
; Author:           David Qu
; Last Modified:    Nov. 30, 2015                   

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
        %TABENT('      ')   ; 17H  Button 7 (Display error)
        %TABENT('      ')   ; 18H 
        %TABENT('      ')   ; 19H 
        %TABENT('      ')   ; 1AH
        %TABENT('      ')   ; 1BH  Button 6 (Display direction)
        %TABENT('      ')   ; 1CH 
        %TABENT('      ')   ; 1DH  Button 5 (Display speed)
        %TABENT('S65534')   ; 1EH  Button 4 (Full speed ahead)
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
                    
START:  

MAIN:
        CLI                             ; Turn off interrupts
        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX
        
        CALL    InitRemoteMain          ;initialize main variables, display,
                                        ;keypad, and serial, associated timers,
                                        ;and event handlers.
        
        STI                             ;and finally allow interrupts. 
        
ProcessRemoteMainLoop:
        CALL    DequeueEvent            ; Check for event in the event queue.
        JC      CheckForCriticalError   ; CF is set if there is no event.
        ;JNC    DoRemoteMainEvent       ; If CF is reset, handle the event.
        
DoRemoteMainEvent:        
        MOV     BL, AH                      ; Extract event type as a word index
        XOR     BH, BH                      ; into BX to determine what function
        CALL    RemoteEventActionTable[BX]  ; to call.

CheckForCriticalError:
        CALL    GetCriticalError        ; Check for a critical error.
        JNZ     MAIN                    ; If there is, reset.
        JZ      ProcessRemoteMainLoop   ; Otherwise continue processing events.
        
        
        RET                             ;Exit program. Should not be called. 
        
        
; InitRemoteMain()
; 
; Description:       Initializes the remote main loop. Sets up chip select, 
;                    clears IVT, initializes remote main shared variables, sets 
;                    up serial, keypad, display, appropriate timers, and turns on
;                    interrupts.
; Operation:         Calls InitCS, ClrIRQVectors. Then calls QueueInit on
;                    eventQueue, sets speed_buffer[0] = 'S' (since we use S to 
;                    denote a speed status), speed_index = 1,
;                    direction_buffer[0] = 'D' (D denotes direction status),
;                    direction_index = 1, and error_index = 0. Initializes the
;                    serial by calling InitSerialVars and InitSerialchip and
;                    installing the serial handler. Installs and initializes the 
;                    display, keypad and associated timers by calls to the 
;                    appropriate functions. Finally allows interrupts.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to speed_buffer - buffer for speed status strings to
;                                             display
;                                    index  - start index of buffer to write to
;                          direction_buffer - buffer for direction status strings 
;                                             to display
;                              error_buffer - buffer for error status strings to
;                                             display
;                                eventQueue - queue of events.
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
InitRemoteMain      PROC     NEAR
                    PUBLIC   InitRemoteMain
        
        CALL    InitCS                  ;initialize the 80188 chip selects
                                        ;   assumes LCS and UCS already setup

        CALL    ClrIRQVectors           ;clear (initialize) interrupt vector table

        CALL    InitEvents              ;initialize event queue.
        MOV     state, START_STATE      ;start at START_STATE in remote parser.
        MOV     index, 0                ;start with index of 0.
        MOV     speed_buffer, 'S'       ;start with an 'S' in speed buffer,
        MOV     direction_buffer, 'D'   ;and a 'D' in the direction buffer.
        
        %INSTALL_HANDLER(INT_14, INT_14_SEGMENT, HandleSerial) ;install the serial 
                                        ; event handler ALWAYS install handlers 
                                        ; before allowing the hardware to interrupt.

        CALL    InitSerialVars          ;initialize the serial shared variables
		CALL 	InitSerialChip          ;initialize the serial chip registers
        
        CALL    InstallTimer0Handler
        CALL    InstallTimer1Handler    ;install the event handler
                                        ;   ALWAYS install handlers before
                                        ;   allowing the hardware to interrupt.

		CALL 	InitKeypad				;initialize keypad shared variables.
        CALL    InitDisplay             ;initialize display shared variables.
		
        CALL    InitTimer0             
        CALL    InitTimer1              ;initialize the internal timer
      
      
        RET     

InitRemoteMain      ENDP


; DoSerialErrorEvent(error)
;
; Description:       Handles a serial error event by displaying the appropriate
;                    message using a table lookup (after converting from
;                    error value table index). Directly displays the message
;                    without storing it in a buffer.
; Operation:         Checks for each error manually. The possible errors are
;                    SERIAL_PARITY_ERROR, SERIAL_FRAME_ERROR, SERIAL_OVERRUN_ERROR,
;                    and SERIAL_OVERFLOW_ERROR. Calls Display on the appropriate
;                    string.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Outputs an error message to the display.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   RemoteSerialErrorTable fixed length string lookup table.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, SI, AX, BX. ES.
; Special notes:     None.
DoSerialErrorEvent  PROC     NEAR
                    PUBLIC   DoSerialErrorEvent

        MOV     SI, OFFSET(RemoteSerialErrorTable)
        XOR     AH, AH
        IMUL    AX, AX, SERIAL_ERROR_STR_LENGTH
        ADD     SI, AX
        
        MOV     BX, CS
        MOV     ES, BX
        CALL    Display
        
        RET     

DoSerialErrorEvent  ENDP


; DoSerialDataEvent(data)
; 
; Description:       Handles a remote serial data event by updating the current
;                    state if appropriate, and adding the received character to 
;                    a buffer that can be displayed at the user's input.
; Operation:         Checks for a 'S', 'D', 'M', or 'P' which are reserved to 
;                    signal which state to go to. On any other character, writes 
;                    the character to the appropriate buffer.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to speed_buffer - buffer for speed status strings to
;                                             display
;                              speed_index  - start index of buffer to write to
;                          direction_buffer - buffer for direction status strings 
;                                             to display
;                           direction_index - start index of buffer to write to
;                              error_buffer - buffer for error status strings to
;                                             display
;                               error_index - start index of buffer to write to
;                    Read/write state - current parsing state of remote loop.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   character buffers of strings to display. 
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
DoSerialDataEvent   PROC     NEAR
                    PUBLIC   DoSerialDataEvent

        CMP     AL, 'S'
        JE      DisplaySpeedCase
        
        CMP     AL, 'D' 
        JE      DisplayDirectionCase
        
        CMP     AL, 'M'
        JE      DisplayMotorParserErrorCase
        
        CMP     AL, 'P' 
        JE      DisplayMotorParserErrorCase
        JNE     DefaultCase
        
DisplaySpeedCase:
        MOV     state, SPEED_STATE
        JMP     ResetIndex

DisplayDirectionCase:
        MOV     state, DIRECTION_STATE
        JMP     ResetIndex        

DisplayMotorSerialErrorCase:
        MOV     state, ERROR_STATE
        MOV     error_buffer, 'M'
        JMP     ResetIndex
        
DisplayMotorParserErrorCase:
        MOV     state, ERROR_STATE
        MOV     error_buffer, 'P'
        ;JMP    ResetIndex
        
ResetIndex:
        MOV     index, 1
        JMP     EndSerialDataEvent

DefaultCase:
        MOV     SI, OFFSET(speed_buffer)
        XOR     BH, BH
        MOV     BL, state
        IMUL    BX, BX, BUFFER_SIZE
        ADD     BL, index
        MOV     [SI + BX], AL
        MOV     BYTE PTR [SI + BX + 1], ASCII_NULL
        INC     index
        ;JMP    EndSerialDataEvent

EndSerialDataEvent:
        
        RET     

DoSerialDataEvent   ENDP


; DoKeypadEvent(keycode)
; 
; Description:       Takes a keycode (AL) and handles the key behavior. For
;                    the DISPLAY keys (such as DISPLAY_SPEED_KEY), this involves
;                    displaying a particular buffer. For the motor command keys,
;                    this involves sending a command to the motor unit. This 
;                    is done with a table look up to the KeypadCommandTable.
; Operation:         First checks for DISPLAY_SPEED_KEY, DISPLAY_DIRECTION_KEY,
;                    and DISPLAY_ERROR_KEY. For those keys, a call to display
;                    is made with the appropriate buffer. If the key is anything
;                    else, sends the associated command message to the serial.
;                    The message to send is determined by the KeypadCommandTable.
;                    The message is displayed for the user.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Displays a string from one of the buffers if one of the 
;                    DISPLAY keys is pressed. Otherwise, sends a message through
;                    the serial and displays the sent message.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   KeypadCommandTable fixed length string table.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
DoKeypadEvent   PROC     NEAR
                PUBLIC   DoKeypadEvent
                    
        XOR     BH, BH
        MOV     BL, AL
        SHL     BX, 1
        CALL    KeyActionTable[BX]

EndDoKeypadEvent:
        
        RET     

DoKeypadEvent   ENDP

; SendKeypadCommand(keycode)
; 
; Description:       Takes a keycode (AL) and handles the key behavior by sending 
;                    a command to the motor unit. This is done with a table look 
;                    up to the KeypadCommandTable.
; Operation:         Sends the associated command message to the serial.
;                    The message to send is determined by the KeypadCommandTable.
;                    The message is displayed for the user.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Sends a message through
;                    the serial and displays the sent message.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   KeypadCommandTable fixed length string table.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
SendKeypadCommand   PROC     NEAR
                    PUBLIC   SendKeypadCommand
                    
        MOV     BX, CS
        MOV     ES, BX
        
        MOV     SI, OFFSET(KeypadCommandTable)
        XOR     AH, AH
        IMUL    AX, AX, KEYPAD_COMMAND_STR_LENGTH
        ADD     SI, AX
        CALL    Display
        
        CALL    SerialSendString

EndSendKeypadCommand:
        
        RET     

SendKeypadCommand   ENDP

; DisplayBuffer()
; 
; Description:       Displays a buffer based on the state shared variable.
; Operation:         
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Displays a string from one of the buffers if one of the 
;                    DISPLAY keys is pressed. Otherwise, sends a message through
;                    the serial and displays the sent message.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   KeypadCommandTable fixed length string table.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
DisplayBuffer   PROC     NEAR
                PUBLIC   DisplayBuffer
        
        MOV     BX, DS
        MOV     ES, BX
        
        MOV     SI, OFFSET(speed_buffer)
        XOR     BH, BH
        MOV     BL, state
        IMUL    BX, BX, BUFFER_SIZE
        ADD     SI, BX
        
        CALL    Display
        
        RET     

DisplayBuffer   ENDP

CODE    ENDS


; Remote main shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state            DB  ?   ; state of remote main loop (based on received)
    index            DB  ?   ; current index in the buffer.
    speed_buffer     DB BUFFER_SIZE DUP (?) ; speed status of motor.
    direction_buffer DB BUFFER_SIZE DUP (?) ; direction status of motor.
    error_buffer	 DB	BUFFER_SIZE	DUP (?) ; buffer of last motor error.
DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START