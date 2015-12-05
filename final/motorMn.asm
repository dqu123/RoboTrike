        NAME    MOTORMN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                             ROBOTRIKE MOTOR MAIN                           ;
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
;
; local include files
$INCLUDE(general.inc)
$INCLUDE(parser.inc)
$INCLUDE(string.inc)
$INCLUDE(handler.inc)

CGROUP  GROUP   CODE

CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DATA, ES:NOTHING


; external function declarations
        EXTRN   InitCS:NEAR                 ;Initialize chip select
        EXTRN   InitParser:NEAR             ;Initialize parser shared variables
        EXTRN   ClrIRQVectors:NEAR          ;Clear Interrupt Vector Table.
        EXTRN   ParseSerialChar:NEAR        ;Parses serial character.
        EXTRN   SerialSendString:NEAR       ;Send a string through the serial.
        EXTRN   HandleSerial:NEAR           ;Serial handler function.
        EXTRN   InitSerialChip:NEAR         ;Initialize serial chip registers.
		EXTRN 	InitSerialVars:NEAR         ;Initialize serial shared variables.
        EXTRN   InitEvents:NEAR             ;Initialize events module.
        EXTRN   DequeueEvent:NEAR           ;Dequeue an event from the eventQueue.
        EXTRN   GetCriticalError:NEAR       ;Determine if a critical error has
                                            ;occurred in the system.
        EXTRN   Dec2String:NEAR             ;Signed word to decimal string.
        EXTRN   UnsignedDec2String:NEAR     ;Unsigned word to decimal string.
        EXTRN   InstallTimer0Handler:NEAR   ;Install motor handlers on timer 0.
        EXTRN   InitTimer0:NEAR             ;Initialize timer 0.
		EXTRN 	InitMotors:NEAR             ;Initialize motor shared variables.
        EXTRN   GetMotorSpeed:NEAR          ;Get motor speed.
        EXTRN   GetMotorDirection:NEAR      ;Get motor direction.
		EXTRN   DoNOP:NEAR                  ;Does nothing.

; Constant strings and tables
ParserError LABEL   BYTE
DB      'ParseErr', 0       ; Motor parser error string.

; MotorEventActionTable 
; Description:      This table contains the function that should be performed
;                   when a specific event type is processed.
;
; Author:           David Qu
; Last Modified:    Dec. 4, 2015 
MtrEventActionTable LABEL   WORD  ; Table of functions for
        DW      DoNOP               ; the switch statement in 
        DW      DoSerialErrorEvent  ; the motor main loop. These functions handle
        DW      MtrSerialDataEvent   ; various event types.     
        
; Fixed Length String Tables
;
; MtrSerialErrorTable
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
        
        %TABENT('M_ovrErr')	   ; motor serial overrun error
        %TABENT('M_parErr')    ; motor serial parity error
        %TABENT('M_frmErr')	   ; motor serial frame error
        %TABENT('M_brkErr')	   ; motor serial buffer overflow
        %TABENT('M_putErr')    ; error when calling SerialSendString.
)

                    
;actually create the table
MtrSerialErrorTable  LABEL       BYTE

        %STRFIXTABLE
        
SERIAL_ERROR_STR_LENGTH	    EQU	    %length - 1	; the length of the table strings
					;    - 1 because we were counting the delimiters too
                    ; but we add a NULL char.                    
                    
START:  

MAIN:
        CLI                             ; Turn off interrupts
        MOV     AX, STACK               ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(TopOfStack)

        MOV     AX, DATA                ;initialize the data segment
        MOV     DS, AX
        
        CALL    InitMotorMain           ;initialize main variables, display,
                                        ;keypad, and serial, associated timers,
                                        ;and event handlers.
        
        STI                             ;and finally allow interrupts. 
        
ProcessMotorMainLoop:
        CALL    DequeueEvent            ; Check for event in the event queue.
        JC      CheckForCriticalError   ; CF is set if there is no event.
        ;JNC    DoRemoteMainEvent       ; If CF is reset, handle the event.
        
DoMotorMainEvent:        
        MOV     BL, AH                      ; Extract event type as a word index
        XOR     BH, BH                      ; into BX to determine what function
        CALL    MtrEventActionTable[BX]  ; to call.

CheckForCriticalError:
        CALL    GetCriticalError        ; Check for a critical error.
        TEST    AL, AL
        JNZ     MAIN                    ; If there is, reset.
        JZ      ProcessMotorMainLoop    ; Otherwise continue processing events.
        
        
        RET                             ;Exit program. Should not be called. 

        
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
InitMotorMain      PROC     NEAR
                   PUBLIC   InitMotorMain
        
        CALL    InitCS                  ;initialize the 80188 chip selects
                                        ;   assumes LCS and UCS already setup

        CALL    ClrIRQVectors           ;clear (initialize) interrupt vector table

        CALL    InitEvents              ;initialize event queue.
        
        %INSTALL_HANDLER(INT_14, INT_14_SEGMENT, HandleSerial) ;install the serial 
                                        ; event handler ALWAYS install handlers 
                                        ; before allowing the hardware to interrupt.

        CALL    InitSerialVars          ;initialize the serial shared variables
		CALL 	InitSerialChip          ;initialize the serial chip registers
     
		CALL 	InitParser				;initialize parser shared variables.
        
		CALL    InstallTimer0Handler    ;install the event handler
                                        ;   ALWAYS install handlers before
                                        ;   allowing the hardware to interrupt.

		CALL 	InitMotors              ;initialize motor shared variables.
		
        CALL    InitTimer0              ;initialize the internal timer
      
      
        RET     

InitMotorMain      ENDP

; DoSerialErrorEvent(error)
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
DoSerialErrorEvent  PROC     NEAR
                    PUBLIC   DoSerialErrorEvent

        MOV     SI, OFFSET(MtrSerialErrorTable)     ; Load table of error strings
        XOR     AH, AH                              ; Extend AL to positive
                                                    ; 16-bit index.
        IMUL    AX, AX, SERIAL_ERROR_STR_LENGTH     ; Use 3 argument IMUL to
                                                    ; avoid using another register.
        ADD     SI, AX                              ; Load location of desired
                                                    ; error string.
        
        MOV     BX, CS      ; Set ES to CS since the
        MOV     ES, BX      ; error string is in code space.
        CALL    SerialSendString ; Display the error string.
        
        RET     

DoSerialErrorEvent  ENDP

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
MtrSerialDataEvent  PROC     NEAR

        CALL    ParseSerialChar
        CMP     AX, PARSER_ERROR
        JNE     MtrSendStatus
        ;JE     MtrSendParserError
        
MtrSendParserError:       
        MOV     SI, OFFSET(ParserError)
        MOV     BX, CS      ; Set ES to CS since the
        MOV     ES, BX      ; error string is in code space.
        CALL    SerialSendString ; Display the error string.
        JMP     MtrSerialDataEvent
        
MtrSendStatus:     
        MOV     BX, DS
        MOV     ES, BX
        MOV     SI, OFFSET(str_buffer) + 1
                
        CALL    GetMotorSpeed
        MOV     str_buffer, 'S'

        CALL    UnsignedDec2String
        CALL    SerialSendString
        
        CALL    GetMotorDirection
        MOV     str_buffer, 'D'
        
        CALL    Dec2String
        CALL    SerialSendString

EndMtrSerialDataEvent:   
        RET     

MtrSerialDataEvent  ENDP        

CODE    ENDS


; the data segment 
DATA    SEGMENT PUBLIC  'DATA'
    str_buffer		 DB	BUFFER_SIZE	DUP (?) ; buffer for building strings.
DATA    ENDS


; the stack
STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START