        NAME   PARSER
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  PARSER                                      ;
;                             Parser Functions                                 ;
;                                 EE/CS 51                                     ;
;                                 David Qu                                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contains the functions to transmit and receive data from the serial 
; device. To use this module, the serial device must first be initialized using 
; the initSeri module. These functions are used both by the motor unit and the 
; remote unit of the RoboTrike to communicate between the two systems. They
; implement a Event-Driven communication protocol with a transmission queue
; and an event queue for each side of the link.
;
; Public functions:
; ParseSerialChar(c)       - 
;
; Local functions:
; HandleSerialError()      - handles a serial error interrupt.
;
; Read-only tables: 
; HandleSerialTable        - table of
;
; Revision History:
; 		11/25/15  David Qu		initial revision.

;local include files. 
$INCLUDE(general.inc)  ; General constants.
$INCLUDE(parser.inc)   ; Parser constants including token types/values, and states.
$INCLUDE(motor.inc)    ; Motor constants including ones needed for motor function calls.
 
CGROUP	GROUP	CODE 

CODE 	SEGMENT PUBLIC 'CODE'
		ASSUME 	CS:CGROUP, DS:DATA
        
        ; external function declarations
        EXTRN 	SetMotorSpeed:NEAR     ; Set absolute motor speed or angle.
        EXTRN   GetMotorSpeed:NEAR     ; Get current motor speed.
        EXTRN   GetMotorDirection:NEAR ; Get current motor direction. 
		EXTRN	SetLaser:NEAR          ; Sets motor laser.
		EXTRN	SetTurretAngle:NEAR    ; Sets the absolute turret angle. 
		EXTRN	SetRelTurretAngle:NEAR ; Sets the relative turret angle.
        EXTRN   SetTurretElevation:NEAR; Sets the abolute turret elevation.

        
; InitParser()
; 
; Description:       Initializes the state, value, and sign shared variables.  
;                    Must be run before ParseSerialChar can be called.     
; Operation:         Sets state = RESET_STATE, value = 0, and sign = NO_SIGN
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to state   - current state in FSM
;                    Writes to value   - value being built up
;                    Writes to sign    - flag for optional sign token
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
InitParser      PROC     NEAR
                PUBLIC   InitParser
                
        MOV     state, RESET_STATE  ; Start at reset state, waiting for a
                                    ; _CMD token.
        MOV     value, 0            ; Value is the function argument built up digit 
                                    ; by digit from a passed character, so it 
                                    ; MUST start at 0 (or else you will add junk
                                    ; to the built up digit).
        MOV     sign, NO_SIGN       ; The NO_SIGN value indicates that no sign
                                    ; token has been seen yet.
        
        RET

InitParser      ENDP


; ParseSerialChar(char)
; 
; Description:       Parses the next serial character by using a Mealy FSM to 
;                    implement the RoboTrike Serial Command Format. Returns
;                    the status of the parser after receiving that character.
;                    This is either PARSER_GOOD or PARSER_ERROR.
; Operation:         First get the token_value and token_type using GetParserToken().
;                    Then, perform the action specified by the state and token_type
;                    with the token_value as an argument. Finally, update the
;                    state based on the state and token_type combination. Return
;                    the status value from the ACTION function.
;
; Arguments:         char (AL) - character from serial to parse.
; Return Value:      return_status (AL) - status value indicating whether or not
;                                    the call was valid / successful.
;
; Local Variables:   token_value (AL) - value of the token for action function
;                    token_type  (AH) - type of token to determine state transition
;                    index (BX)       - byte index into state table
; Shared Variables:  Read/Writes to state   - current state in FSM
;                    Read/Writes to value   - value being built up
;                    Read/Writes to sign    - flag for optional sign token
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        State Machine.
; Data Structures:   StateTable of transition entries, which contain a NEXTSTATE
;                    (constant) and an ACTION (function).
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, BX, CX, DH.
; Special notes:     None.
ParseSerialChar PROC     NEAR
                PUBLIC   ParseSerialChar
                
GetNextToken:                
        CALL    GetParserToken      ; Convert from char to token_value (AL),
                                    ; token_type (AH)
        MOV     DH, AH              ; save token_type in DH
        MOV     CH, AL              ; save token_value in CH
        
ComputeTransition:                  ; figure out what transition to do    
        MOV     AL, NUM_TOKEN_TYPES ; find row in the table
        MOV     CL, state           ; prepare to multiply by current state
        MUL     CL                  ; AX is start of row for current state
        ADD     AL, DH              ; get the actual transition
        ADC     AH, 0               ; propagate low byte carry into high byte
        
        IMUL    BX, AX, SIZE TRANSITION_ENTRY ; now convert to table offset

DoAction:                                ; do the actions
        MOV     AL, CH                   ; get token value back for actions
        CALL    CS:StateTable[BX].ACTION ; do action, which returns the
                                         ; status of the action (PARSER_GOOD or
                                         ; PARSER_ERROR) in AL.
        
DoTransition:                                   ; go to next state
        MOV     CL, CS:StateTable[BX].NEXTSTATE ; Get new state,
        MOV     state, CL                       ; and update shared variable.

        RET     ; Returns PARSER_GOOD or PARSER_ERROR depending on action.

ParseSerialChar ENDP


; GetParserToken()
; 
; Description:       Returns the token_value (AL) and token_type (AH) of a 
;                    given character received from the serial.
; Operation:         First, removes the high bit of the char, because it should
;                    be a standard ASCII value from 0 to 127. Then look up the
;                    token_value and token_type
;
; Arguments:         char (AL) - character from serial to parse
; Return Value:      token_value (AL) - value of the token for action function
;                    token_type  (AH) - type of token to determine state transition
;
; Local Variables:   token_value (AL) - value of the token for action function
;                    token_type  (AH) - type of token to determine state transition
;                    index       (BX) - table pointer, points at lookup tables
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Table lookup.
; Data Structures:   Two tables, one containing token values and the other
;                    containing token types.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX.
; Special notes:     None.
GetParserToken  PROC     NEAR
                PUBLIC   GetParserToken
                
InitGetParserToken:	            ;setup for lookups
        AND	    AL, TOKEN_MASK  ;strip unused bits (high bit)
        MOV 	AH, AL			;and preserve value in AH


TokenTypeLookup:                            ;get the token type
        MOV     BX, OFFSET(TokenTypeTable)  ;BX points at table
        XLAT	CS:TokenTypeTable	        ;have token type in AL
        XCHG	AH, AL			            ;token type in AH, character in AL

TokenValueLookup:			                 ;get the token value
        MOV     BX, OFFSET(TokenValueTable)  ;BX points at table
        XLAT	CS:TokenValueTable	         ;have token value in AL


EndGetParserToken:              ;done looking up type and value
        RET

GetParserToken  ENDP


; AddDigit(tkn_val)
; 
; Description:       Sets the value shared variable according to the passed
;                    tkn_val (AL). Builds up value on digit at a time. Note 
;                    that this function is always called in transitions that
;                    have PARSER_GOOD status. Thus, even if there is an overflow,
;                    it must be handled gracefully. In this case, overflows
;                    automatically set value to the MAX_SIGNED_VALUE.
; Operation:         Sets value = 10 * value + tkn_val.
;
; Arguments:         tkn_val (AL) - token value for action.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Read/Writes to value - value being built up
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     None.
AddDigit        PROC     NEAR
                PUBLIC   AddDigit
                
        IMUL    BX, value, 10   ; Multiply the current value by 10
        JO      Overflow        ; and check for overflow. (Seeing another
        ;JNO    PerformAddition ; digit means we need to shift all our
                                ; decimal digits left).
        
PerformAddition:        
        XOR     AH, AH      ; Clear out token type.
        ADD     BX, AX      ; Add in the next digit 
        ;JO     Overflow    ; and check for overflow.
        JNO     EndAddDigit

Overflow:
        MOV     value, MAX_SIGNED_VALUE ; Handle overflow gracefully by
                                        ; just setting value (which is a magnitude)
                                        ; to the MAX_SIGNED_VALUE.
        
        
EndAddDigit:        
        MOV     AL, PARSER_GOOD  ; Always returns a good status
                                 ; since the parser will continue in a
                                 ; potentially valid path.
                
        RET

AddDigit        ENDP

; SetSign(tkn_val)
; 
; Description:       Sets the sign shared variable according to the passed
;                    tkn_val (AL). This function is only called as part of
;                    transition from SIGN states to DIGIT states.
; Operation:         Sets sign = tkn_val.
;
; Arguments:         tkn_val (AL) - token value for action.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to sign - flag for option sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: None.
; Special notes:     None.
SetSign         PROC     NEAR
                PUBLIC   SetSign
                
        MOV     sign, AL   ; Only transitions that calls this are from
                           ; SIGN states to DIGIT states, where the tkn_val
                           ; is simply 1 for + and -1 for -, and represents
                           ; the sign value.
        RET

SetSign         ENDP

; ParserError()
; 
; Description:       This function is only called when an error occurs and
;                    returns PARSER_ERROR.
; Operation:         Returns PARSER_ERROR.
;
; Arguments:         None.
; Return Value:      Parser status (AL) - the status of ParseSerialChar, which
;                                         is always PARSER_ERROR if ParserError
;                                         is called.
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: None.
; Special notes:     None.
;
; Pseudo code:
; return PARSER_ERROR
GetParserToken  PROC     NEAR
                PUBLIC   GetParserToken
                
        MOV     AL, PARSER_ERROR    ; Return error status through AL.
        RET                         ; This is returned by ParseSerialChar.

GetParserToken  ENDP

; SetAbsSpeed()
; 
; Description:       Sets the absolute speed of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token. Should
;                    only be used in the CommandTable.
; Operation:         First checks if the sign has been set, and makes it 1
;                    if NO_SIGN. Then multiplies the value by sign, and
;                    calls SetMotorSpeed() to set the absolute motor speed.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads sign  - flag for optional sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; if (sign == NO_SIGN)
;     sign = 1
; value *= sign
; SetMotorSpeed(value, NO_ANGLE_CHANGE)


; SetRelativeSpeed()
; 
; Description:       Sets the relative speed of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token. Should
;                    only be used in the CommandTable.
; Operation:         First checks if the sign has been set, and makes it 1
;                    if NO_SIGN. Then multiplies the value by sign, adds the
;                    current speed (found via GetMotorSpeed) and
;                    calls SetMotorSpeed() to set the new motor speed.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads sign  - flag for optional sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     The specification states that if after adding the the 
;                    specified relative speed, the resulting speed is negative,
;                    it should be truncated to zero, and the RoboTrike should
;                    be halted.
;
; Pseudo code:
; if (sign == NO_SIGN)
;    sign = 1
; value *= sign
; value += GetMotorSpeed()
; if (value < 0)
;     value = 0
; SetMotorSpeed(value, NO_ANGLE_CHANGE)


; SetDirection()
; 
; Description:       Sets the relative direction of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token. Should
;                    only be used in the CommandTable.
; Operation:         First checks if the sign has been set. If not, then
;                    sets sign = 1. Then sets value = value * sign + GetMotorDirection()
;                    because value is treated as a relative direction.
;                    Finally calls SetMotorSpeed(NO_SPEED_CHANGE, value)
;                    to change the Robotrike direction.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads sign  - flag for optional sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; if (sign == NO_SIGN)
;   sign = 1
; value = value * sign + GetMotorDirection()
; SetMotorSpeed(NO_SPEED_CHANGE, value)


; RotateTurret()
; 
; Description:       Rotates the turret of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token. Should
;                    only be used in the CommandTable.
; Operation:         First checks if the sign has been set. If not, then
;                    simply calls SetTurretAngle(value) to set the absolute
;                    turret angle. If the sign has been set, sets value *= sign, 
;                    and then sets the relative angle using SetRelTurretAngle(value).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads sign  - flag for optional sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     The specification states that if the sign token is present
;                    a relative angle should be set. Otherwise an absolute
;                    angle is set.
;
; Pseudo code:
; if (sign)
;   value *= sign
;   SetRelTurretAngle(value)
; else
;   SetTurretAngle(value)


; SetTurretEle()
; 
; Description:       Sets the turret elevation of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token. Should
;                    only be used in the CommandTable.
; Operation:         First checks if the sign has been set. If not, then
;                    sets sign = 1. Then sets value *= sign, and 
;                    and sets the absolute angle using SetTurretElevation(value).
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads sign  - flag for optional sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; if (sign == NO_SIGN)
;    sign = 1
; value *= sign
; SetTurretElevation(value)


; FireLaser(tkn_val)
; 
; Description:       Fires the RoboTrike laser. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token. Should
;                    only be used in the CommandTable.
; Operation:         Calls SetLaser(TRUE) to fire the laser.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads sign  - flag for optional sign token
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
; Limitations:       Assumes that the parser shared variables have been
;                    initialized properly.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; SetLaser(AL)

       
; Token Tables
;
; Description:      This creates the tables of token types and token values.
;                   Each entry corresponds to the token type and the token
;                   value for a character.  Macros are used to actually build
;                   two separate tables - TokenTypeTable for token types and
;                   TokenValueTable for token values.
;
; Author:           Glen George
; Last Modified:    Nov. 23, 2015 (David Qu)

%*DEFINE(TABLE)  (
        %TABENT(TOKEN_OTHER, 0)		;<null> 
        %TABENT(TOKEN_OTHER, 1)		;SOH
        %TABENT(TOKEN_OTHER, 2)		;STX
        %TABENT(TOKEN_OTHER, 3)		;ETX
        %TABENT(TOKEN_OTHER, 4)		;EOT
        %TABENT(TOKEN_OTHER, 5)		;ENQ
        %TABENT(TOKEN_OTHER, 6)		;ACK
        %TABENT(TOKEN_OTHER, 7)		;BEL
        %TABENT(TOKEN_OTHER, 8)		;backspace
        %TABENT(TOKEN_OTHER, 9)		;TAB
        %TABENT(TOKEN_OTHER, 10)	;new line
        %TABENT(TOKEN_OTHER, 11)	;vertical tab
        %TABENT(TOKEN_OTHER, 12)	;form feed
        %TABENT(TOKEN_END_CMD, 13)	;carriage return (signals end of command)
        %TABENT(TOKEN_OTHER, 14)	;SO
        %TABENT(TOKEN_OTHER, 15)	;SI
        %TABENT(TOKEN_OTHER, 16)	;DLE
        %TABENT(TOKEN_OTHER, 17)	;DC1
        %TABENT(TOKEN_OTHER, 18)	;DC2
        %TABENT(TOKEN_OTHER, 19)	;DC3
        %TABENT(TOKEN_OTHER, 20)	;DC4
        %TABENT(TOKEN_OTHER, 21)	;NAK
        %TABENT(TOKEN_OTHER, 22)	;SYN
        %TABENT(TOKEN_OTHER, 23)	;ETB
        %TABENT(TOKEN_OTHER, 24)	;CAN
        %TABENT(TOKEN_OTHER, 25)	;EM
        %TABENT(TOKEN_OTHER, 26)	;SUB
        %TABENT(TOKEN_OTHER, 27)	;escape
        %TABENT(TOKEN_OTHER, 28)	;FS
        %TABENT(TOKEN_OTHER, 29)	;GS
        %TABENT(TOKEN_OTHER, 30)	;AS
        %TABENT(TOKEN_OTHER, 31)	;US
        %TABENT(TOKEN_OTHER, ' ')	;space
        %TABENT(TOKEN_OTHER, '!')	;!
        %TABENT(TOKEN_OTHER, '"')	;"
        %TABENT(TOKEN_OTHER, '#')	;#
        %TABENT(TOKEN_OTHER, '$')	;$
        %TABENT(TOKEN_OTHER, 37)	;percent
        %TABENT(TOKEN_OTHER, '&')	;&
        %TABENT(TOKEN_OTHER, 39)	;'
        %TABENT(TOKEN_OTHER, 40)	;open paren
        %TABENT(TOKEN_OTHER, 41)	;close paren
        %TABENT(TOKEN_OTHER, '*')	;*
        %TABENT(TOKEN_SIGN, +1)		;+  (positive sign)
        %TABENT(TOKEN_OTHER, 44)	;,
        %TABENT(TOKEN_SIGN, -1)		;-  (negative sign)
        %TABENT(TOKEN_OTHER, 46)    ;.  
        %TABENT(TOKEN_OTHER, '/')	;/
        %TABENT(TOKEN_DIGIT, 0)		;0  (digit)
        %TABENT(TOKEN_DIGIT, 1)		;1  (digit)
        %TABENT(TOKEN_DIGIT, 2)		;2  (digit)
        %TABENT(TOKEN_DIGIT, 3)		;3  (digit)
        %TABENT(TOKEN_DIGIT, 4)		;4  (digit)
        %TABENT(TOKEN_DIGIT, 5)		;5  (digit)
        %TABENT(TOKEN_DIGIT, 6)		;6  (digit)
        %TABENT(TOKEN_DIGIT, 7)		;7  (digit)
        %TABENT(TOKEN_DIGIT, 8)		;8  (digit)
        %TABENT(TOKEN_DIGIT, 9)		;9  (digit)
        %TABENT(TOKEN_OTHER, ':')	;:
        %TABENT(TOKEN_OTHER, ';')	;;
        %TABENT(TOKEN_OTHER, '<')	;<
        %TABENT(TOKEN_OTHER, '=')	;=
        %TABENT(TOKEN_OTHER, '>')	;>
        %TABENT(TOKEN_OTHER, '?')	;?
        %TABENT(TOKEN_OTHER, '@')	;@
        %TABENT(TOKEN_OTHER, 'A')	;A
        %TABENT(TOKEN_OTHER, 'B')	;B
        %TABENT(TOKEN_OTHER, 'C')	;C
        %TABENT(TOKEN_OTHER, 'D')	;D
        %TABENT(TOKEN_E_CMD, 0)     ;E (set turret elevation angle command)
        %TABENT(TOKEN_OTHER, 'F')	;F
        %TABENT(TOKEN_OTHER, 'G')	;G
        %TABENT(TOKEN_OTHER, 'H')	;H
        %TABENT(TOKEN_OTHER, 'I')	;I
        %TABENT(TOKEN_OTHER, 'J')	;J
        %TABENT(TOKEN_OTHER, 'K')	;K
        %TABENT(TOKEN_OTHER, 'L')	;L
        %TABENT(TOKEN_OTHER, 'M')	;M
        %TABENT(TOKEN_OTHER, 'N')	;N
        %TABENT(TOKEN_OTHER, 'O')	;O
        %TABENT(TOKEN_OTHER, 'P')	;P
        %TABENT(TOKEN_OTHER, 'Q')	;Q
        %TABENT(TOKEN_OTHER, 'R')	;R
        %TABENT(TOKEN_OTHER, 'S')	;S
        %TABENT(TOKEN_OTHER, 'T')	;T
        %TABENT(TOKEN_OTHER, 'U')	;U
        %TABENT(TOKEN_OTHER, 'V')	;V
        %TABENT(TOKEN_OTHER, 'W')	;W
        %TABENT(TOKEN_OTHER, 'X')	;X
        %TABENT(TOKEN_OTHER, 'Y')	;Y
        %TABENT(TOKEN_OTHER, 'Z')	;Z
        %TABENT(TOKEN_OTHER, '[')	;[
        %TABENT(TOKEN_OTHER, '\')	;\
        %TABENT(TOKEN_OTHER, ']')	;]
        %TABENT(TOKEN_OTHER, '^')	;^
        %TABENT(TOKEN_OTHER, '_')	;_
        %TABENT(TOKEN_OTHER, '`')	;`
        %TABENT(TOKEN_OTHER, 'a')	;a
        %TABENT(TOKEN_OTHER, 'b')	;b
        %TABENT(TOKEN_OTHER, 'c')	;c
        %TABENT(TOKEN_OTHER, 'd')	;d
        %TABENT(TOKEN_E_CMD, 0)		;e (set turret elevation angle command)
        %TABENT(TOKEN_OTHER, 'f')	;f
        %TABENT(TOKEN_OTHER, 'g')	;g
        %TABENT(TOKEN_OTHER, 'h')	;h
        %TABENT(TOKEN_OTHER, 'i')	;i
        %TABENT(TOKEN_OTHER, 'j')	;j
        %TABENT(TOKEN_OTHER, 'k')	;k
        %TABENT(TOKEN_OTHER, 'l')	;l
        %TABENT(TOKEN_OTHER, 'm')	;m
        %TABENT(TOKEN_OTHER, 'n')	;n
        %TABENT(TOKEN_OTHER, 'o')	;o
        %TABENT(TOKEN_OTHER, 'p')	;p
        %TABENT(TOKEN_OTHER, 'q')	;q
        %TABENT(TOKEN_OTHER, 'r')	;r
        %TABENT(TOKEN_OTHER, 's')	;s
        %TABENT(TOKEN_OTHER, 't')	;t
        %TABENT(TOKEN_OTHER, 'u')	;u
        %TABENT(TOKEN_OTHER, 'v')	;v
        %TABENT(TOKEN_OTHER, 'w')	;w
        %TABENT(TOKEN_OTHER, 'x')	;x
        %TABENT(TOKEN_OTHER, 'y')	;y
        %TABENT(TOKEN_OTHER, 'z')	;z
        %TABENT(TOKEN_OTHER, '{')	;{
        %TABENT(TOKEN_OTHER, '|')	;|
        %TABENT(TOKEN_OTHER, '}')	;}
        %TABENT(TOKEN_OTHER, '~')	;~
        %TABENT(TOKEN_OTHER, 127)	;rubout
)

; token type table - uses first byte of macro table entry
%*DEFINE(TABENT(tokentype, tokenvalue))  (
        DB      %tokentype
)

TokenTypeTable	LABEL   BYTE
        %TABLE


; token value table - uses second byte of macro table entry
%*DEFINE(TABENT(tokentype, tokenvalue))  (
        DB      %tokenvalue
)

TokenValueTable	LABEL       BYTE
        %TABLE

; StateTable
;
; Description:      This is the state transition table for the state machine.
;                   Each entry consists of the next state and actions for that
;                   transition.  The rows are associated with the current
;                   state and the columns with the input type.
;
; Author:           Glen George
; Last Modified:    Nov. 23, 2015 (David Qu)

TRANSITION_ENTRY        STRUC           ;structure used to define table
    NEXTSTATE   DB      ?               ;the next state for the transition
    ACTION      DW      ?               ;action for the transition
TRANSITION_ENTRY      ENDS


;define a macro to make table a little more readable
;macro just does an offset of the action routine entries to build the STRUC
%*DEFINE(TRANSITION(nxtst, act))  (
    TRANSITION_ENTRY< %nxtst, OFFSET(%act) >
)

; FSM State transition table.
StateTable	LABEL	TRANSITION_ENTRY
    
    ;Current State = RESET_STATE             Input Token Type
    %TRANSITION(RESET_STATE, ParserError)    ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, ParserError)    ;TOKEN_SIGN
    %TRANSITION(READ_S_STATE, InitParser)    ;TOKEN_S_CMD
    %TRANSITION(READ_V_STATE, InitParser)    ;TOKEN_V_CMD
    %TRANSITION(READ_D_STATE, InitParser)    ;TOKEN_D_CMD
    %TRANSITION(READ_T_STATE, InitParser)    ;TOKEN_T_CMD
    %TRANSITION(READ_E_STATE, InitParser)    ;TOKEN_E_CMD
    %TRANSITION(READ_LASER_STATE, FireLaser) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, ParserError)    ;TOKEN_END_CMD
    %TRANSITION(RESET_STATE, ParserError)    ;TOKEN_OTHER
    
    ;Current State = READ_S_STATE           Input Token Type
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_END_CMD
    %TRANSITION(RESET_STATE, ParserError)   ;TOKEN_OTHER
    
    
CODE    ENDS
    
    
    
; Parser shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state           DB  ?   ; current FSM state.
    value           DW  ?   ; value used by transitions.
    sign            DB  ?   ; sign of value. signals if the optional sign token
                            ; has been included or not.
DATA    ENDS

        END