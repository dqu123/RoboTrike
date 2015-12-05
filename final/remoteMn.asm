        NAME    REMOTEMN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                             ROBOTRIKE REMOTE MAIN                          ;
;                                  EE/CS  51                                 ;
;                                  David Qu                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Description:      This file contains the main loop for the RoboTrike remote
;                   unit. This loop processes keypad and serial events on the
;                   remote unit, and displays various messages to the user
;                   including what command is being sent to the motor unit.
;
; Input:            Keypad  - keypresses are debounced and converted to events
;                             that are processed by the main loop. If a key is
;							  held down, the keypress will register as an auto
;							  repeat, and begin faster auto repeat after 5 sec. 
; Output:           Display - status and error strings appear on the display
;                             as buttons are pressed and serial events are
;                             processed. Additionally, a message is displayed
;						      for each command that is sent to the remote unit.
;			 		Serial  - RoboTrike command strings are sent to the serial 
;							  in the RoboTrike command format, which is described
;							  in detail in the RoboTrike functional specification. 
;
; User Interface:   The user can press buttons on the keypad to read status/error 
;                   buffers, and send commands to the motor unit. Each keypress
;                   is debounced and will auto-repeat if held down.
; 
; Keypad Layout:
; 0  1  2  3
; 4  5  6  7
; 8  9  10 11
; 12 13 14 15
; 
; The keypad is a 4x4 grid of keys as depicted above. 
; Currently, most multiple button combinations are unused, but new button functions 
; could be easily added by changing the KeyActionTable.
;
; Multiple button combinations:
;	  Button 1 + 2 - reset blink rate settings.
; 
; Single button functions: 
;     Button  0 - reset the system.
;     Button  1 - increase on_time and affect blink rate and brightness*
;     Button  2 - increase off_time and affect blink rate and brightness*
;     Button  3 - displays the last motor error received.
;     Button  4 - sends the max speed command to go full speed in the current 
;				  direction.
; 	  Button  5 - displays the speed status of the motor (last value received 
;				  from the motor unit via serial).
;     Button  6 - displays the direction status of the motor (last value received
;                 from the motor unit via serial).
;     Button  7 - displays the laser status.
;     Button  8 - fires the laser
;     Button  9 - slows down 
;     Button 10 - increases speed by 1000 (max is 65534).
;     Button 11 - stops the motor
;     Button 12 - turns off the laser
;     Button 13 - increases the angle by 30 degrees (counterclockwise)
;     Button 14 - turns the RoboTrike around (still goes at the same speed)
;     Button 15 - decreases the angle by 30 degrees (clockwise)
; 
; *Blink rate and brightness are determined by the on_time and off_time.
; The display is displayed for on_time counts and then off_time counts in a
; periodic manner. To blink the display, increase both on_time and off_time
; to roughly equivalent counts. The higher the total count, the more time
; between blinks. To lower the brightness, just increase the off_time. The
; default blink setting is max brightness and no blinking.
;       
; Error Handling:   There is an error buffer which contains the most recent
;                   error that has occurred. It can be accessed by a button in
;                   the keypad. See User interface for the keypad layout.
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
; DoKeypadEvent      - handle keypad events by calling the keypad table.
; DisplaySpeedBuffer - display the speed buffer to the user.
; DisplayDirectionBuffer - display the direction buffer to the user.
; DisplayErrorBuffer - display the error buffer to the user.
; SendMaxSpeed 	     - displays the max speed message, and sends the max string
;					   command sequence to the motor unit.
;
; Tables:
; RemoteEventActionTable - actions for each remote event in a switch table.
; RemoteSerialErrorTable - error messages for remote serial errors.
; KeypadCommandTable     - commands for each keypress.
;
; Revision History:
;    12/3/15  David Qu	               initial revision
;    12/4/15  David Qu                 fixed bugs, minor errors
;	 12/5/15  David Qu				   fixed max speed, added comments.

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
		EXTRN	IncreaseOnTime:NEAR			;Increases ontime shared variable.
		EXTRN	IncreaseOffTime:NEAR		;Increases offtime shared variable.
		EXTRN 	ResetBlinkRate:NEAR			;Resets to default blink rate.

; Constant strings and tables 
ResetSystemMessage		LABEL	BYTE ; Message to send to user about resetting the
								     ; remote system.
DB		'SysReset', ASCII_NULL
      
MaxSpeedMessage		LABEL	BYTE ; Message to send to user about setting max speed.
DB		'MAXSPEED', ASCII_NULL

MaxSpeedCommand		LABEL	BYTE ; Command sequence to obtain max speed.
								 ; The ASCII_RETURNs are needed to register as
								 ; RoboTrike commands in the parser.
DB		'S32767', ASCII_RETURN, 'V32767', ASCII_RETURN, ASCII_NULL

StopCommand			LABEL	BYTE ; Return/Null terminated RoboTrike command that
								 ; stops the RoboTrike. 
DB		'S0', ASCII_RETURN, ASCII_NULL


; Read-only tables
; RemoteEventActionTable 
; Description:      This table contains the function that should be performed
;                   when a specific event type is processed.
;
; Author:           David Qu
; Last Modified:    Dec. 4, 2015 
RemoteEventActionTable LABEL   WORD ; Table of functions for
        DW      DoKeypadEvent       ; the switch statement in 
        DW      DoSerialErrorEvent  ; the remote main loop. These functions handle
        DW      DoSerialDataEvent   ; various event types.     

        
; KeypadActionTable 
; Description:      This table contains the function that should be performed
;                   when a specific button is pressed.
; Keypad layout
; 0  1  2  3
; 4  5  6  7
; 8  9  10 11
; 12 13 14 15
;
; Author:           David Qu
; Last Modified:    Dec. 5, 2015 
KeyActionTable      LABEL   WORD
        ; Row 0 of keypad
        DW      DoNOP       ; 00H 
        DW      DoNOP       ; 01H 
        DW      DoNOP       ; 02H
        DW      DoNOP       ; 03H 
        DW      DoNOP       ; 04H
        DW      DoNOP       ; 05H
        DW      DoNOP       ; 06H
        DW      DisplayErrorBuffer ; 07H  Button 3 (Displays the error buffer).
        DW      DoNOP       ; 08H 
        DW      ResetBlinkRate ; 09H  Button 1 + button 2
        DW      DoNOP       ; 0AH
        DW      IncreaseOffTime ; 0BH  Button 2
        DW      DoNOP       ; 0CH 
        DW      IncreaseOnTime  ; 0DH  Button 1
        DW      SystemReset ; 0EH  Button 0 (Reset the system).
        DW      DoNOP       ; 0FH
        
        ; Row 1 of keypad
        DW      DoNOP       ; 10H 
        DW      DoNOP       ; 11H 
        DW      DoNOP       ; 12H
        DW      DoNOP       ; 13H 
        DW      DoNOP       ; 14H
        DW      DoNOP       ; 15H
        DW      DoNOP       ; 16H
        DW      DisplayLaserBuffer ; 17H  Button 7 (Display error)
        DW      DoNOP       ; 18H 
        DW      DoNOP       ; 19H 
        DW      DoNOP       ; 1AH
        DW      DisplayDirectionBuffer ; 1BH  Button 6 (Display direction)
        DW      DoNOP       ; 1CH 
        DW      DisplaySpeedBuffer ; 1DH  Button 5 (Display speed)
        DW      SendMaxSpeed ; 1EH  Button 4 (Full speed ahead)
        DW      DoNOP       ; 1FH
        
        ; Row 2 of keypad
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
        
        ; Row 3 of keypad
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
; Last Modified:    Dec. 5, 2015                   

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
        
        ; Row 1 of keypad
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
        %TABENT('      ')   ; 1EH  Button 4 (Full speed ahead)
        %TABENT('      ')   ; 1FH
        
        ; Row 2 of keypad
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
        
        ; Row 3 of keypad
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
        TEST    AL, AL
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
;                    denote a speed status), index = 1, direction_buffer[0] = 'D' 
;					 (D denotes direction status). Initializes the serial by 
;					 calling InitSerialVars and InitSerialchip and installing 
;				     the serial handler. Installs and initializes the 
;                    display, keypad and associated timers by calls to the 
;                    appropriate functions. Finally allows interrupts.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to       index  - start index of buffer to write to
;						 	   speed_buffer - buffer for speed status strings to
;                                             display
;                                    
;                          direction_buffer - buffer for direction status strings 
;                                             to display
;							   laser_buffer - buffer for laser status strings
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
        
        CALL    InitCS                  ;initialize the 80188 chip selects
                                        ;   assumes LCS and UCS already setup

        CALL    ClrIRQVectors           ;clear (initialize) interrupt vector table

        CALL    InitEvents              ;initialize event queue.
        MOV     state, ERROR_STATE      ;start at ERROR_STATE in remote parser.
        MOV     index, 0                ;start with index of 0 to record any
									    ;serial characters initially in the
										;error buffer.
        MOV     speed_buffer, 'S'       ;start with an 'S' in speed buffer,
        MOV     direction_buffer, 'D'   ;a 'D' in the direction buffer,
		MOV		laser_buffer, 'L'		;and a 'L' in the laser buffer.
										;Since the error buffer holds different
										;statuses it is not initialized.
        
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

        MOV     SI, OFFSET(RemoteSerialErrorTable)  ; Load table of error strings
        XOR     AH, AH                              ; Extend AL to positive
                                                    ; 16-bit index.
        IMUL    AX, AX, SERIAL_ERROR_STR_LENGTH     ; Use 3 argument IMUL to
                                                    ; avoid using another register.
        ADD     SI, AX                              ; Load location of desired
                                                    ; error string.
        
        MOV     BX, CS      ; Set ES to CS since the
        MOV     ES, BX      ; error string is in code space.
        CALL    Display     ; Display the error string.
        
        RET     

DoSerialErrorEvent  ENDP


; DoSerialDataEvent(data)
; 
; Description:       Handles a remote serial data event by updating the current
;                    state if appropriate, and adding the received character to 
;                    a buffer that can be displayed at the user's input.
; Operation:         Checks for a 'S', 'D', 'L', 'M', or 'P' which are reserved to 
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

        CMP     AL, 'S'                     ; The 'S' character signals that
        JE      DisplaySpeedCase            ; a speed status is being sent.
        
        CMP     AL, 'D'                     ; The 'D' character signals that
        JE      DisplayDirectionCase        ; a direction status is being sent.
        
		CMP		AL, 'L'						; The 'L' character signals that
		JE		DisplayLaserCase			; a laser status is being sent.
		
        CMP     AL, 'M'                     ; The 'M' character signals that
        JE      DisplayMotorSerialErrorCase ; a motor serial error is being
                                            ; sent.
		
        CMP     AL, 'P'                     ; The 'P' character signals that
        JE      DisplayMotorParserErrorCase ; a motor parser error is being sent.
        JNE     SerialDataDefaultCase       ; By default write to a buffer
                                            ; determined by the state.
        
DisplaySpeedCase:
        MOV     state, SPEED_STATE          ; Read 'S', so go to SPEED_STATE.
        JMP     ResetIndex                  ; Then reset index to prepare for
                                            ; new writes.

DisplayDirectionCase:
        MOV     state, DIRECTION_STATE      ; Read 'D', so go to DIRECTION_STATE.
        JMP     ResetIndex                  ; Then reset index to prepare for
                                            ; new writes.
											
DisplayLaserCase:
        MOV     state, LASER_STATE          ; Read 'L', so go to LASER_STATE.
        JMP     ResetIndex                  ; Then reset index to prepare for
                                            ; new writes.

DisplayMotorSerialErrorCase:
        MOV     state, ERROR_STATE          ; Read 'M', so go to ERROR_STATE.
        MOV     error_buffer, 'M'           ; Write the appropriate first char,
        JMP     ResetIndex                  ; and reset index to prepare for
                                            ; new writes.
        
DisplayMotorParserErrorCase:
        MOV     state, ERROR_STATE          ; Read 'P', so go to ERROR_STATE.
        MOV     error_buffer, 'P'           ; Write the appropriate first char,
        ;JMP    ResetIndex                  ; and reset index to prepare for
                                            ; new writes.
        
ResetIndex:
        MOV     index, 1                    ; Start at index of 1 in the buffer
        JMP     EndSerialDataEvent          ; because the 0 index is reserved
                                            ; to denote the buffer type to the
                                            ; user.

SerialDataDefaultCase:
        MOV     SI, OFFSET(speed_buffer)    ; Start with the address of the
                                            ; speed buffer since it is the
                                            ; first buffer.
        XOR     BH, BH                      ; Determine the offset of the
        MOV     BL, state                   ; appropriate buffer by the state
        IMUL    BX, BX, BUFFER_SIZE         ; shared variable.
        MOV     CL, index                   ; The index gives the character
        XOR     CH, CH                      ; offset in the buffer.
        ADD     BX, CX                      ; Perform word addition.
        MOV     [SI + BX], AL               ; Write character to buffer.
        MOV     BYTE PTR [SI + BX + 1], ASCII_NULL ; NULL terminate buffer.
        INC     index                       ; Update index shared variable to
                                            ; indicate next available buffer
                                            ; location.
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
                    
        XOR     BH, BH                 ; Clear top byte since reading byte-sized
        MOV     BL, AL                 ; index. Get index from AL to BL, so we
                                       ; can index into a table.
        SHL     BX, WORD_SHIFT_TO_BYTE ; Convert from word index to byte index.
        CALL    KeyActionTable[BX]     ; Call the appropriate function to handle
                                       ; the specific keycode.

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
                    
        MOV     BX, CS  ; Display displays the string in ES:SI, so
        MOV     ES, BX  ; we set ES to CS, since our command strings are
                        ; constant and stored in the code segment.
        
        MOV     SI, OFFSET(KeypadCommandTable)      ; Start with base address
        XOR     AH, AH                              ; of the command table, 
        IMUL    AX, AX, KEYPAD_COMMAND_STR_LENGTH   ; and add in the index,
        ADD     SI, AX                              ; converting it to bytes
                                              ; using KEYPAD_COMMAND_STR_LENGTH
                                              
        CALL    Display             ; Display the command string to the user.
        
        CALL    SerialSendString    ; Send the command string to the motor unit.

EndSendKeypadCommand: 
        RET     

SendKeypadCommand   ENDP


; DisplaySpeedBuffer()
; 
; Description:       Displays the speed buffer by loading ES:SI with the address
;                    of the speed buffer, and calling display. 
; Operation:         Calls display with ES = DS, and SI = OFFSET(speed_buffer).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads from the speed_buffer - buffer to store speed status.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Displays a string from the speed_buffer.
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   speed_buffer - string buffer of speed status.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX, ES, SI.
; Special notes:     None.
DisplaySpeedBuffer   PROC     NEAR
        
        MOV     BX, DS  ; The speed buffer is in the data segment,
        MOV     ES, BX  ; so we must set ES = DS since Display uses ES:SI
        
        MOV     SI, OFFSET(speed_buffer) ; Load the address of the speed buffer
        CALL    Display                  ; in SI and then display it to the user.
        
        RET     

DisplaySpeedBuffer   ENDP


; DisplayDirectionBuffer()
; 
; Description:       Displays the direction buffer by loading ES:SI with the address
;                    of the direction buffer, and calling display. 
; Operation:         Calls display with ES = DS, and SI = OFFSET(direction_buffer).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads from the direction_buffer - buffer to store direction status.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Displays a string from the direction_buffer.
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   direction_buffer - string buffer of direction status.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX, ES, SI.
; Special notes:     None.
DisplayDirectionBuffer   PROC     NEAR
        
        MOV     BX, DS  ; The direction buffer is in the data segment,
        MOV     ES, BX  ; so we must set ES = DS since Display uses ES:SI.
        
        MOV     SI, OFFSET(direction_buffer) ; Load the address of the direction
        CALL    Display                      ; buffer in SI and then display it 
                                             ; to the user.
        
        RET     

DisplayDirectionBuffer   ENDP


; DisplayLaserBuffer()
; 
; Description:       Displays the laser buffer by loading ES:SI with the address
;                    of the speed buffer, and calling display. 
; Operation:         Calls display with ES = DS, and SI = OFFSET(laser_buffer).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads from the laser_buffer - buffer to store laser status.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Displays a string from the speed_buffer.
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   laser_buffer - string buffer of laser status.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX, ES, SI.
; Special notes:     None.
DisplayLaserBuffer   PROC     NEAR
        
        MOV     BX, DS  ; The laser buffer is in the data segment,
        MOV     ES, BX  ; so we must set ES = DS since Display uses ES:SI
        
        MOV     SI, OFFSET(laser_buffer) ; Load the address of the speed buffer
        CALL    Display                  ; in SI and then display it to the user.
        
        RET     

DisplayLaserBuffer   ENDP


; DisplayErrorBuffer()
; 
; Description:       Displays the error buffer by loading ES:SI with the address
;                    of the error buffer, and calling display. 
; Operation:         Calls display with ES = DS, and SI = OFFSET(error_buffer).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads from the error_buffer - buffer to store error status.
; Global Variables:  None.
;
; Input:             Key presses generate keypress events through the keypad
;                    event handler which debounces on a timer repeat.
; Output:            Displays a string from the error_buffer.
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   error_buffer - string buffer of direction status.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX, ES, SI.
; Special notes:     None.
DisplayErrorBuffer  PROC     NEAR
        
        MOV     BX, DS  ; The error buffer is in the data segment,
        MOV     ES, BX  ; so we must set ES = DS since Display uses ES:SI.
        
        MOV     SI, OFFSET(error_buffer) ; Load the address of the error buffer
        CALL    Display                  ; in SI and then display it to the user.
        
        RET     

DisplayErrorBuffer  ENDP


; SendMaxSpeed()
; 
; Description:       Sends the max speed command, which is a null terminated 
;				     RoboTrike command string located at the label MaxSpeedCommand.
;                    Also displays a message indicating max speed was set.
; Operation:         Sets ES to CS because we are accessing constant strings.
;                    Calls Display on the MaxSpeedMessage label, then
;					 calls SerialSendString on MaxSpeedCommand. 
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
;                    
; Output:            Displays the string message indicating that the RoboTrike
;					 was set to max speed.
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   constant strings - null terminated character arrays.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX, ES, SI.
; Special notes:     None.
SendMaxSpeed  PROC     NEAR
        
        MOV     BX, CS  ; The command and message are in the code segment,
        MOV     ES, BX  ; so we must set ES = CS since Display uses ES:SI.
        
        MOV     SI, OFFSET(MaxSpeedMessage) ; Load the address of the message 
        CALL    Display                  ; in SI and then display it to the user.
        
		MOV		SI, OFFSET(MaxSpeedCommand) ; Load the address of the command
		CALL	SerialSendString			; and send it to the motor via serial.
		
        RET     

SendMaxSpeed  ENDP


; SystemReset()
; 
; Description:       Resets the system at the request of the user. This includes
;					 reinitializing the remote board, and stopping the RoboTrike. 
;					 Note that this does not reset the motor board, and only 
;					 sends a stop command to the motor board.
; Operation:         First sends the stop command to the motor unit. 
;					 Then turns off interrupts, resets the system, writes the 
;					 status message notifying the user, and then turns 
;				     interrupts back on.
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
; Output:            Sends the stop string to the motor unit. 
;					 Displays a string message indicating that the RoboTrike
;					 remote system was reset.
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   constant strings - null terminated character arrays.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, BX, ES, SI.
; Special notes:     None.
SystemReset  	PROC     NEAR
        
		CLI		; Turn off interrupts
		CALL	InitRemoteMain
		
		MOV     BX, CS  ; The command and message are in the code segment,
        MOV     ES, BX  ; so we must set ES = CS since Display uses ES:SI.
        
		MOV		SI, OFFSET(StopCommand)     ; Load the address of the command
		CALL	SerialSendString			; and send it to the motor via serial.
		
        MOV     SI, OFFSET(ResetSystemMessage) ; Load the address of the message 
        CALL    Display                 ; in SI and then display it to the user.
		
		STI		; Turn back on interrupts.
		
        RET     

SystemReset  	ENDP

CODE    ENDS


; Remote main shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state            DB  ?   ; state of remote main loop (based on received)
    index            DB  ?   ; current index in the buffer.
    speed_buffer     DB BUFFER_SIZE DUP (?) ; speed status of motor.
    direction_buffer DB BUFFER_SIZE DUP (?) ; direction status of motor.
	laser_buffer     DB BUFFER_SIZE DUP (?) ; laser status of motor unit.
    error_buffer	 DB	BUFFER_SIZE	DUP (?) ; buffer of last motor error.
DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START