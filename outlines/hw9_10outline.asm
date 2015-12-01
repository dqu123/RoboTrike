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
; File serial.asm
; Public functions:
; SerialSendString - send a string through serial
;
; File parser.asm
; Local functions:
; SendSpeed        - send motor speed through serial
; SendDirection    - send motor direction through serial
;
; File: remoteMn.asm 
; Main loop:
; RemoteMain     - run remote main loop
;
; Public functions:
; EnqueueEvent   - add an event to the event queue.
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
;
; File: motorMn.asm
; MotorMain         - run motor main loop.
; 
; Public functions:
; EnqueueEvent   - add an event to the event queue.
; 
; Local functions:
; MtrSerialErrorEvent - handle motor serial error.
; MtrSerialDataEvent  - handle motor serial data.
; DoNop               - do nothing.
;
; Tables:
; ParserError - parser error string
; MotorEventActionTable - actions for each event in a switch table
; MtrSerialErrorTable   - error messages for motor serial errors.

; Remote-motor system communication
; The RoboTrike system consists of two EE51 boards: the remote board,
; which handles keypresses and displays status information, and the
; motor unit, which accepts commands and moves the RoboTrike motors.
; The remote unit sends predetermined strings to the motor unit based on
; keypad inputs. The motor unit parses these strings to do various commands
; according to the parser.asm module.
; The motor unit sends status strings to the remote unit.
; Reserved characters in messages from motor to remote: 
; 'S' - reserved for indicating speed status
; 'D' - reserved for indicating direction status
; 'M' - reserved for indicating motor serial error.
; 'P' - reserved for indicating 
; Note that only the uppercase version of the above letters are reserved, so 
; the lowercase version should be used in messages that need to be displayed.


; Constants
BUFFER_SIZE             EQU     32      ; Size of string buffer.

; Special keys 
DISPLAY_SPEED_KEY       EQU     1DH     ; Keycode for display speed key
DISPLAY_DIRECTION_KEY   EQU     1BH     ; Keycode for display direction key
DISPLAY_ERROR_KEY       EQU     17H     ; Keycode for display error key

; Remote main states
START_STATE             EQU     0       ; Initial state.
SPEED_STATE             EQU     2       ; Reading speed.
DIRECTION_STATE         EQU     4       ; Reading direction.
ERROR_STATE             EQU     6       ; Reading error.

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
        EXTRN   HandleSerial:NEAR       ; Serial handler function.
        EXTRN   InitSerialChip:NEAR     ; Initialize serial chip registers.
		EXTRN 	InitSerialVars:NEAR     ; Initialize serial shared variables.
        EXTRN   Display:NEAR            ; Display a string.

; Read-only tables
ParserError LABEL   BYTE
        DB      'ParseErr', 0       ; Motor parser error string.

RemoteEventActionTable LABEL   WORD ; Table of functions for
        DW      DoSerialErrorEvent  ; the switch statement in 
        DW      DoSerialDataEvent   ; the remote main loop. These functions handle
        DW      DoKeypadEvent       ; various event types.

MotorEventActionTable LABEL   WORD   ; Table of functions for
        DW      MtrSerialErrorEvent  ; the switch statement in 
        DW      MtrSerialDataEvent   ; the motor main loop. These functions handle
        DW      DoNOP                ; various event types.

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
        
        %TABENT('R_parErr')    ; remote serial parity error
        %TABENT('R_frmErr')	   ; remote serial frame error
        %TABENT('R_ovrErr')	   ; remote serial overrun error
        %TABENT('R_bufErr')	   ; remote serial buffer overflow
        %TABENT('unkwnErr')    ; unknown error.
)
SERIAL_ERROR_STR_LENGTH	    EQU	    %length - 1	; the length of the table strings
					;    - 1 because we were counting the delimiters too
                    ; but we add a NULL char.
                    
;actually create the table
RemoteSerialErrorTable  LABEL       BYTE

        %STRFIXTABLE
        
; MtrSerialErrorTable
; Description:      This table contains the motor serial error messages, which
;                   are sent to the remote unit through the serial and stored
;                   in a buffer once received by the remote unit. The user can 
;                   press the DISPLAY_ERROR_KEY to show the most recent motor
;                   error (which is either a serial error or a parser error).
;                   This is a fixed length string table.
;
; Author:           David Qu
; Last Modified:    Nov. 30, 2015       
%*DEFINE(STRFIXTABLE)  (
	%SET(length, 0)			;don't know length yet
        
        %TABENT('M_parErr')    ; motor serial parity error
        %TABENT('M_frmErr')	   ; motor serial frame error
        %TABENT('M_ovrErr')	   ; motor serial overrun error
        %TABENT('M_bufErr')	   ; motor serial buffer overflow
        %TABENT('unkwnErr')    ; unknown error.
)

;actually create the table
MtrSerialErrorTable  LABEL       BYTE

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
                    
; Serial shared variables               
DATA    SEGMENT PUBLIC  'DATA'
    str_buffer		 DB	BUFFER_SIZE	DUP (?) ; buffer for building strings.
DATA    ENDS

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

; Motor main shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    eventQueue       queueSTRUC<> ; Event queue. This is a word queue that
                                  ; holds events.
    
DATA    ENDS
                    
                    
; SerialSendString(char* string) 
; 
; Description:       Sends the null terminated string in SI through the serial by 
;                    calling SerialPutChar. Since SerialPutChar is not guaranteed 
;                    to succeed, calls SerialPutChar repeatedly for each character
;                    until SerialPutChar succeeds.
; Operation:         Iterate through each character in the string and call
;                    SerialPutChar repeatedly on that character until it works.
;                    Stop when the ASCII_NULL character is reached.
;
; Arguments:         string (SI) - start address of a character ASCII string
;                                  to send through the serial.
; Return Value:      None.
;
; Local Variables:   index (BX) - index in the string.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   String - null terminated character (byte) array.   
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX.
; Special notes:     None.
;
; Pseudo code:
; unsigned word i = 0;
; do 
;     char = string[i]
;     do
;         SerialPutChar(char)
;     while (CF != 0)
;     i++
; while (char != NULL)



; SendSpeed()
; 
; Description:       Gets the speed status of the motor and sends it to the
;                    remote system to display.
; Operation:         Writes 'S' to the first character in the str_buffer to
;                    designate a speed status. Then calls UnsignedDec2String to
;                    place the unsigned speed value in the str_buffer after the
;                    'S' and calls SerialSendString to send the string through
;                    serial to display in the remote unit.
;
; Arguments:         speed (AX) - current speed of the RoboTrike.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to str_buffer - buffer for writing strings to send
;                                           through serial.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   str_buffer - character buffer to build a string to send.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; str_buffer[0] = 'S'
; UnsignedDec2String(speed, str_buffer + 1)
; SerialSendString(str_buffer)


; SendDirection(direction)
; 
; Description:       Takes the direction status (AX) of the motor and sends it to the
;                    remote system to display.
; Operation:         Writes 'D' to the first character in the str_buffer to
;                    designate a direction status. Then calls Dec2String to
;                    place the signed direction value in the str_buffer after the
;                    'D' and calls SerialSendString to send the string through
;                    serial to display in the remote unit.
;
; Arguments:         direction (AX) - current direction of the RoboTrike.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to str_buffer - buffer for writing strings to send
;                                           through serial.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   str_buffer - character buffer to build a string to send.   
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
; Pseudo code:
; str_buffer[0] = 'D'
; Dec2String(direction, str_buffer + 1)
; SerialSendString(str_buffer)
                    
                    
; EnqueueEvent(event)
; 
; Description:       Enqueues an event to the event queue.
; Operation:         Calls enqueue on the eventQueue if it is not full.
;
; Arguments:         event (AX) - event to enqueue. Contains the event type (AH)
;                                 and the event value (AL).
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
; Data Structures:   eventQueue - FIFO word queue of events to process
;
; Known Bugs:        None.
; Limitations:       Drops an event if the event queue is empty because this 
;                    function is called by interrupt handlers, which can't block.
;                    The RoboTrike boards do not support asynchronous waiting.
;
; Registers Changed: flags, AX.
; Special notes:     None.
;
; Pseudo code:
; if !QueueFull(eventQueue)
;    Enqueue(eventQueue, event)


; Remote Main 
; 
; Description:       Main loop for the remote unit.
; Operation:         First initializes the chip select, event queue, serial, keypad, 
;                    display, timers and interrupts. Then processes events in 
;                    the event queue using a switch table. Events are added by
;                    the interrupt handlers
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to speed_buffer - buffer for speed status strings to
;                                             display
;                          direction_buffer - buffer for direction status strings 
;                                             to display
;                              error_buffer - buffer for error status strings to
;                                             display
; Global Variables:  None.
;
; Input:             The user can press keys on the keypad to interact with the
;                    system.
; Output:            Displays characters on a 8-digit 14-segment LED display.
;                    Sends command messages to the motor unit.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   RemoteEventActionTable switch table to handle various event 
;                    cases.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; InitRemoteMain() 
; while (true)
;    if (!eventQueue.empty()) 
;        unsigned word event = eventQueue.dequeue()
;        RemoteEventActionTable[event.type].action(event.value) 
        

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
;                              speed_index  - start index of buffer to write to
;                          direction_buffer - buffer for direction status strings 
;                                             to display
;                           direction_index - start index of buffer to write to
;                              error_buffer - buffer for error status strings to
;                                             display
;                               error_index - start index of buffer to write to
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
; Pseudo code:
; SetupStack()
; InitCS()
; ClrIRQVectors()
; QueueInit(eventQueue, 0, WORD_SIZE)
; state = NONE_STATE 
; speed_index = 1
; speed_buffer[0] = 'S'
; direction_index = 1
; direction_buffer[0] = 'D'
; error_index = 0
; InitSerialVars()
; InitSerialChip()
; INSTALL_HANDLER(INT_14, INT_14_SEGMENT, HandleSerial)
; InstallTimer0Handler()
; InstallTimer1Handler()
; InitKeypad()
; InitDisplay()
; InitTimer0()
; InitTimer1()
; STI


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
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; if error == SERIAL_PARITY_ERROR
;     Display(RemoteSerialErrorTable[0 * SERIAL_ERROR_STR_LENGTH])
; else if error == SERIAL_FRAME_ERROR
;     Display(RemoteSerialErrorTable[1 * SERIAL_ERROR_STR_LENGTH])
; else if error == SERIAL_OVERRUN_ERROR 
;     Display(RemoteSerialErrorTable[2 * SERIAL_ERROR_STR_LENGTH])
; else if error == SERIAL_OVERFLOW_ERROR
;     Display(RemoteSerialErrorTable[3 * SERIAL_ERROR_STR_LENGTH])


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
; Pseudo code:
; switch (data)
; case ('S'):
;     state = SPEED_STATE
;     speed_index = 1
;     break
; case ('D'):
;     state = DIRECTION_STATE
;     direction_index = 1
;     break
; case ('M')
;     state = ERROR_STATE
;     error_index = 1
;     error_buffer[0] = 'M' 
;     break
; case ('P')
;     state = ERROR_STATE
;     error_index = 1
;     error_buffer[0] = 'P'
; default
;     if state == SPEED_STATE
;         speed_buffer[speed_index] = data
;         speed_index++
;         speed_buffer[speed_index] = NULL ; Null end in case want to display
                                           ; early, or if null is forgotten.
;     else if state == DIRECTION_STATE
;         direction_buffer[direction_index] = data
;         direction_index++
;         direction_buffer[direction_index] = NULL
;     else if state = ERROR_STATE
;         error_buffer[error_index] = data
;         error_index++
;         error_buffer[error_index] = NULL


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
;     break
; default:
;     string = KeypadCommandTable[keycode * KEYPAD_COMMAND_STR_LENGTH]
;     Display(string)
;     SerialSendString(string)


; Motor Main
; 
; Description:       Main loop for the motor unit.
; Operation:         First initializes the chip select, event queue, serial,
;                    motor, parser and interrupts. Then processes events in 
;                    the event queue using a switch table. Events are added by
;                    the interrupt handlers.   
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
; Registers Changed: flags, AX.
; Special notes:     None.
;
; Pseudo code:
; InitMotorMain()
; while (true)
;    if (!eventQueue.empty()) 
;        unsigned word event = eventQueue.dequeue()
;        MotorEventActionTable[event.type].action(event.value)


; InitMotorMain()
; 
; Description:       Initializes the motor main loop. Sets up chip select, 
;                    clears IVT, initializes remote main shared variables, sets 
;                    up serial, serial handler, parser and turns on interrupts.
; Operation:         Calls InitCS, ClrIRQVectors. Then calls QueueInit on
;                    eventQueue. Initializes the serial by calling InitSerialVars 
;                    and InitSerialchip and installs the serial handler. Initializes
;                    the parser shared variables. Finally allows interrupts.         
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
; Registers Changed: flags, AX.
; Special notes:     None.
;
; Pseudo code:
; SetupStack()
; InitCS()
; ClrIRQVectors()
; QueueInit(eventQueue, 0, WORD_SIZE)
; InitSerialVars()
; InitSerialChip()
; INSTALL_HANDLER(INT_14, INT_14_SEGMENT, HandleSerial)
; InitParser()
; STI


; MtrSerialErrorEvent(error)
; 
; Description:       Handles a serial error event by sending the appropriate
;                    message using a table lookup (after converting from
;                    error value table index). Sends an error message to the
;                    remote unit 
; Operation:         Checks for each error manually. The possible errors are
;                    SERIAL_PARITY_ERROR, SERIAL_FRAME_ERROR, SERIAL_OVERRUN_ERROR,
;                    and SERIAL_OVERFLOW_ERROR. Calls SerialSendString on the 
;                    appropriate string.        
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Sends an error message to the remote unit if a parser error
;                    occurs.
;
; Error Handling:    Sends an error message to the remote unit if a parser error 
;                    occurs.
;
; Algorithms:        None.
; Data Structures:   Table lookup of MtrSerialErrorTable - table of error strings.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; if error == SERIAL_PARITY_ERROR
;     SerialSendString(MtrSerialErrorTable[0 * SERIAL_ERROR_STR_LENGTH])
; else if error == SERIAL_FRAME_ERROR
;     SerialSendString(MtrSerialErrorTable[1 * SERIAL_ERROR_STR_LENGTH])
; else if error == SERIAL_OVERRUN_ERROR 
;     SerialSendString(MtrSerialErrorTable[2 * SERIAL_ERROR_STR_LENGTH])
; else if error == SERIAL_OVERFLOW_ERROR
;     SerialSendString(MtrSerialErrorTable[3 * SERIAL_ERROR_STR_LENGTH])


; MtrSerialDataEvent(char)
; 
; Description:       Handles a motor serial data event by calling ParseSerialChar
;                    and sends out an error message to the remote unit if there
;                    is a parser error.
; Operation:         Calls ParseSerialChar to parse the passed char. Then checks 
;                    the return status to see if PARSER_ERROR. If it is, then 
;                    sends the ParserError string through the serial.
;
; Arguments:         char (AL) - character received from serial.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Sends an error message to the remote unit if a parser error
;                    occurs.
;
; Error Handling:    Sends an error message to the remote unit if a parser error 
;                    occurs.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX.
; Special notes:     None.
;
; Pseudo code:
; if ParseSerialChar(char) == PARSER_ERROR:
;      SerialSendString(ParserError)


; DoNOP()
; 
; Description:       Does nothing. Used for switch tables.
; Operation:         Does nothing.
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
; Registers Changed: None.
; Special notes:     None.
;
; Pseudo code:
; NOP