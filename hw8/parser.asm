        NAME   PARSER
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  PARSER                                      ;
;                             Parser Functions                                 ;
;                                 EE/CS 51                                     ;
;                                 David Qu                                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contain the functions to parse the next serial character as a part
; of a finite state machine (FSM). This FSM is meant to be run on the motor
; unit of the RoboTrike, and will call various motor functions in response to 
; commands in the RoboTrike Serial Command Format. An overview of the parser
; design with more details follows after the table of contents.
; 
; Public functions:
; InitParser()         - initializes parser shared variables for new command.
; ParseSerialChar(c)   - parse the passed character as part of a serial command. 
;
; Local functions:
; GetParserToken(char) - returns the token class and token value for the passed char.
; AddDigit(tkn_val)    - updates the value shared variable based on the next digit.
; SetSign(tkn_val)     - sets the sign shared variable based on the token value.
; GetParserError()     - returns PARSER_ERROR.
; SetAbsSpeed()        - sets absolute speed of the RoboTrike.
; SetRelSpeed()        - sets relative speed of the RoboTrike.
; SetDirection()       - sets direction of the RoboTrike.
; RotateTurret()       - rotates turret of the RoboTrike.
; ParserSetTurretEle() - sets turret elevation angle.
; WriteLaser(tkn_val)  - sets the laser shared variable based on the token value.
; FireLaser()          - fires the laser based on the shared variable.
; DoNOP()              - returns PARSER_GOOD.
; 
; Read only tables:
; TokenTypeTable      - table of token types (see parser.inc for definitions)
; TokenValueTable     - table of token values (see parser.inc for definitions)
; StateTable          - table of state transitions (see parser design overview)
;
; Note that the token tables are created using macros to avoid having to sync
; multiple tables.
;
; Shared Variables: 
;    state  DB  - current FSM state.
;    laser  DB  - whether to fire the laser or not.
;    value  DW  - value built up by parsing digit tokens.
;    sign   DB  - sign of value. signals if the optional sign token has been 
;                 included or not. Starts as NO_SIGN, and becomes 1, or -1 
;                 depending on the sign. The default assumed value is 1.
;
; Revision History:
; 		11/25/15  David Qu		initial revision.
;       11/26/15  David Qu      implemented commands.
;       11/27/15  David Qu      fixed error handling and overflow issues.

; Parser Design Overview:
; Features: Mealy FSM, Paths for each command, Graceful overflow, special case:
; laser.
; This parser implements a Mealy Finite State Machine by treating character
; inputs as tokens with token values and token types, and maintaining a state
; shared variable. The possible token types and token values can be seen in the
; TokenTypeTable and TokenValueTable, which are generated using macros. 
; Each combination of state and token leads to one of the
; transitions describe in the StateTable. Specifically, in our case there is
; a transition path for each of the S, V, D, T, and E commands, and a special
; LASER transition path for the F and O commands. By transition path, I mean
; that seeing a "S" token leads to a READ_S_STATE that can only go to
; a S_SIGN_STATE, and S_DIGIT_STATE. This isolates the 
; Overflow: 

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
;                    Must be run before ParseSerialChar can be called because
;                    the state must be initialized to RESET_STATE.
;                    Returns PARSER_GOOD in AX because it is also used to
;                    reset state in the FSM.     
; Operation:         Sets state = RESET_STATE, value = 0, and sign = NO_SIGN.
;                    Returns PARSER_GOOD in AX.
;
; Arguments:         None.
; Return Value:      PARSER_GOOD in AX since this always starts a new potentially
;                    valid command path.
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
; Registers Changed: AX.
; Special notes:     The laser shared variable is not written because that
;                    is set when the laser command tokens are seen.
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
        
        MOV     AX, PARSER_GOOD  ; Always returns a good status
                                 ; since the parser will continue in a
                                 ; potentially valid path.     
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
;                    with the token_value as an argument. Next update the
;                    state based on the state and token_type combination. Then
;                    check the status value from the ACTION function. If it is
;                    PARSER_ERROR, transition to the RESET_STATE instead. Return
;                    the status value from the ACTION function.
;
; Arguments:         char (AL) - character from serial to parse.
; Return Value:      return_status (AX) - status value indicating whether or not
;                                    the call was valid / successful.
;
; Local Variables:   token_value (AL) - value of the token for action function
;                    token_type  (AH) - type of token to determine state transition
;                    index (BX)       - byte index into state table
; Shared Variables:  Read/writes to state   - current state in FSM
;                    Read/writes to value   - value being built up
;                    Read/writes to sign    - flag for optional sign token
;                    Read/writes to laser   - whether to fire the laser
;                    (Most of these read/writes occur in action functions).
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Mealy Finite State Machine (FSM) - each character received is
;                    treated as a token, as described in the TokenType and
;                    TokenValue tables. The function uses the state shared 
;                    variable to track its state in the FSM and the combination
;                    of state and token determine the next state and action
;                    performed. These combinations can be seen in the StateTable.
; Data Structures:   StateTable of transition entries, which contain a NEXTSTATE
;                    (constant) and an ACTION (function).
;
; Known Bugs:        None.
; Limitations:       Must call InitParser before using this function to start
;                    in the correct state.
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
        PUSH    BX                       ; Save index to avoid being written
                                         ; by action.
        CALL    CS:StateTable[BX].ACTION ; do action, which returns the
                                         ; status of the action (PARSER_GOOD or
                                         ; PARSER_ERROR) in AX.
        
DoTransition:                                   ; go to next state
        POP     BX                              ; Restore index.
        MOV     CL, CS:StateTable[BX].NEXTSTATE ; Get new state,
        MOV     state, CL                       ; and update shared variable.
        
        CMP     AX, PARSER_ERROR        ; Check return status of action to
        JNE     EndParseSerialChar      ; see if we should transition back
        ;JE     ParseSerialCharError    ; to the reset state instead.
        
ParseSerialCharError:
        MOV     state, RESET_STATE      ; Transition back to RESET_STATE because
                                        ; an error occurred.
        
EndParseSerialChar:
        RET     ; Returns PARSER_GOOD or PARSER_ERROR in AX depending on action.

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
; Registers Changed: flags, AX, BX.
; Special notes:     None.
GetParserToken  PROC     NEAR
                
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
; Operation:         First computes value = 10 * value and checks for overflow. 
;                    Then if no overflow, adds the new digit to value and checks 
;                    for overflow again. If either overflow occurs, value is set 
;                    to MAX_SIGNED_VALUE.
;                    
; Arguments:         tkn_val (AL) - token value for action.
; Return Value:      PARSER_GOOD (AX) - success status of parser.
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
; Registers Changed: flags, AX, BX.
; Special notes:     None.
AddDigit        PROC     NEAR
                
        IMUL    BX, value, 10       ; Multiply the current value by 10
        JO      AddDigitParserError ; and check for overflow. (Seeing another
        ;JNO    PerformAddition     ; digit means we need to shift all our
                                    ; decimal digits left).
        
PerformAddition:        
        XOR     AH, AH          ; Clear out token type to perform word addition with
                                ; digit.
        ADD     AX, BX          ; Add in the next digit
        MOV     value, AX       ; and update value.
        ;JO     AddDigitCheckOverflow ; and check for overflow.
        JNO    AddDigitParserGood     ; If no overflow, we are good, so just
                                      ; return PARSER_GOOD.

AddDigitCheckOverflow:
        CMP     sign, -1                 ; First see if sign is negative. There
        ;JE     AddDigitCheckMinNegative ; is the special negative case of
        JNE     AddDigitParserError      ; 32768, since that is a valid signed
                                         ; value. Since we accumulate a positive
                                         ; value and check for signed overflow,
                                         ; this case will register as
                                         ; a signed overflow.
                                         
AddDigitCheckMinNegative:
        CMP     AX, 32768            ; Check if magnitude is the minimum allowed
        ;JE     AddDigitParserGood   ; signed value. (And negative sign). This
        JNE     AddDigitParserError  ; is a special case because it causes an
                                     ; overflow even though it is a valid
                                     ; command (for example "V-32768").
                                       
AddDigitParserGood:
        MOV     AX, PARSER_GOOD  ; Returns a good status if the parser will 
                                 ; continue in a valid path with no overflow.
        JMP     EndAddDigit

AddDigitParserError:
        MOV     AX, PARSER_ERROR ; Returns a bad status if there is unexpected
        ;JMP    EndAddDigit      ; signed overflow.
        
EndAddDigit:        
                
        RET

AddDigit        ENDP


; SetSign(tkn_val)
; 
; Description:       Sets the sign shared variable according to the passed
;                    tkn_val (AL). This function is only called as part of
;                    transition from SIGN states to DIGIT states.
; Operation:         Sets sign = tkn_val, and then returns PARSER_GOOD in AX.
;
; Arguments:         tkn_val (AL) - token value for action.
; Return Value:      PARSER_GOOD (AX) - success status of parser.
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
; Registers Changed: AX.
; Special notes:     None.
SetSign         PROC     NEAR
                
        MOV     sign, AL   ; Only transitions that calls this are from
                           ; SIGN states to DIGIT states, where the tkn_val
                           ; is simply 1 for + and -1 for -, and represents
                           ; the sign value.
                           
        MOV     AX, PARSER_GOOD  ; Always returns a good status
                                 ; since the parser will continue in a
                                 ; potentially valid path.
        RET

SetSign         ENDP


; GetParserError()
; 
; Description:       This function is only called when an error occurs and
;                    returns PARSER_ERROR in AX.
; Operation:         Returns PARSER_ERROR in AX.
;
; Arguments:         None.
; Return Value:      Parser status (AX) - the status of ParseSerialChar, which
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
; Registers Changed: AX.
; Special notes:     None.
GetParserError  PROC     NEAR
                
        MOV     AX, PARSER_ERROR    ; Return error status through AX.
        RET                         ; This is returned by ParseSerialChar.

GetParserError  ENDP


; SetAbsSpeed()
; 
; Description:       Sets the absolute speed of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token, so returns
;                    PARSER_GOOD.
; Operation:         First checks if the sign has been set, and makes it 1
;                    if NO_SIGN. Then multiplies the value by sign, and
;                    calls SetMotorSpeed() to set the absolute motor speed.
;                    Finally returns PARSER_GOOD in AX.
;
; Arguments:         None.
; Return Value:      PARSER_GOOD (AX) - success status of parser.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads/writes sign - flag for optional sign token
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
; Registers Changed: flags, AX, BX, DX.
; Special notes:     None.
SetAbsSpeed     PROC     NEAR
                
        CMP     sign, NO_SIGN           ; First check if sign token was seen.
        JNE     DoSetAbsSpeed           ; If so, the sign has been set.
        ;JE     SetAbsSpeedDefaultSign  ; Otherwise the sign needs to be set.
        
SetAbsSpeedDefaultSign:
        MOV     sign, 1             ; Default sign is positive.
 
DoSetAbsSpeed:
        MOV     AL, sign            ; Multiply value by sign to get the signed
        CBW                         ; representation of value in AX, which is
        MOV     BX, value           ; the speed argument to SetMotorSpeed.
        IMUL    BX                  ; Note that we must convert sign to a word
                                    ; since value is a word (use CBW).
                                    
        MOV     BX, NO_ANGLE_CHANGE ; Set angle argument to SetMotorSpeed.
                                    ; This value indicates that the angle should
                                    ; remain the same.
        
        CALL    SetMotorSpeed       ; Set the motor speed with the new absolute
                                    ; speed.
        
EndSetAbsSpeed:                
        MOV     AX, PARSER_GOOD     ; Return parser status through AX.
        RET                         ; This is returned by ParseSerialChar.

SetAbsSpeed     ENDP


; SetRelSpeed()
; 
; Description:       Sets the relative speed of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token, so returns
;                    PARSER_GOOD in AX. Handles overflows gracefully.
; Operation:         First checks the sign. It adds or subtracts, depending on 
;                    the sign, the current speed (found via GetMotorSpeed).
;                    Checks for overflow and sets value to MAX_TOTAL_SPEED
;                    if the value was too big in addition, and 0 if the value
;                    went negative. Then calls SetMotorSpeed() to set the new 
;                    motor speed. Finally returns PARSER_GOOD in AX.
;
; Arguments:         None.
; Return Value:      PARSER_GOOD (AX) - success status of parser.
;
; Local Variables:   None.
; Shared Variables:  Reads value - value being built up
;                    Reads/writes sign - flag for optional sign token
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
; Registers Changed: flags, AX, BX, DX.
; Special notes:     The specification states that if after adding the the 
;                    specified relative speed, the resulting speed is negative,
;                    it should be truncated to zero, and the RoboTrike should
;                    be halted. Additionally, this state is always considered
;                    the end of a valid parser path, so overflows are handled
;                    gracefully by setting value to MAX_SIGNED_VALUE.
SetRelSpeed     PROC     NEAR
                

SetRelSpeedGetCurrentSpeed:
        MOV     BX, value            ; Store relative value in register
        CALL    GetMotorSpeed        ; Get current motor speed in AX.
        
        CMP     sign, -1             ; First check if sign token is negative.
        ;JE     SetRelNegativeSpeed  ; If so, subtract values.
        JNE    SetRelPositiveSpeed   ; Otherwise add values.

SetRelNegativeSpeed:
        SUB     AX, BX               ; If the sign is negative, perform
        JNC     DoSetRelSpeed        ; a subtraction and check for unsigned
        JC      SetRelSpeedTruncate  ; overflow (which would indicate a
                                     ; negative value).
        
SetRelPositiveSpeed:
        ADD     AX, BX                  ; If the sign is positive, perform
        ;JNC    CheckNoSpeedChangeValue ; and addition and check for unsigned
        JC      SetRelSpeedOverflow     ; overflow, which indicates that the
                                        ; value is too big.

CheckNoSpeedChangeValue:
        CMP     AX, NO_SPEED_CHANGE  ; The max unsigned speed value is reserved 
        JNE     DoSetRelSpeed        ; for NO_SPEED_CHANGE, which indicates that
        ;JE     SetRelSpeedOverflow  ; no speed change should be made. Since
                                     ; the CF will not catch this, we need to 
                                     ; check manually.
        
SetRelSpeedOverflow:
        MOV     AX, MAX_TOTAL_SPEED  ; If overflow, or the result was 
        JMP     DoSetRelSpeed        ; NO_SPEED_CHANGE, gracefully max out
                                     ; the speed argument to SetMotorSpeed.
                                                                                 
SetRelSpeedTruncate:
        MOV     AX, 0                ; Truncate new absolute speed to 0, so
                                     ; the Trike will stop if the result was
        ;JMP    DoSetRelSpeed        ; negative.
        
DoSetRelSpeed:        
        MOV     BX, NO_ANGLE_CHANGE  ; Set angle argument to SetMotorSpeed.
                                     ; This value indicates that the angle should
                                     ; remain the same.
        
        CALL    SetMotorSpeed        ; Set motor speed with the new absolute speed 
                                     ; computed from the relative speed.
                                     
EndSetRelSpeed:                
        MOV     AX, PARSER_GOOD  ; Always returns a good status
                                 ; since the parser will continue in a
                                 ; potential path.
        RET                      ; This is returned by ParseSerialChar.    

SetRelSpeed     ENDP


; SetDirection()
; 
; Description:       Sets the relative direction of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token, so returns
;                    PARSER_GOOD in AX.
; Operation:         First checks if the sign has been set. If not, then
;                    sets sign = 1. Then sets value = value * sign + GetMotorDirection()
;                    because value is treated as a relative direction.
;                    Finally calls SetMotorSpeed(NO_SPEED_CHANGE, value)
;                    to change the Robotrike direction and returns PARSER_GOOD in AX.
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
; Registers Changed: flags, AX, BX, DX.
; Special notes:     None.
SetDirection    PROC     NEAR
                
        CMP     sign, NO_SIGN           ; First check if sign token was seen.
        JNE     SetDirectionValue       ; If so, the sign has been set.
        ;JE     SetDirectionDefaultSign ; Otherwise the sign needs to be set.
        
SetDirectionDefaultSign:
        MOV     sign, 1              ; Default sign is positive.
 
SetDirectionValue:
        MOV     AL, sign            ; Multiply value by sign to get the signed
        CBW                         ; representation of value in AX, which is
        MOV     BX, value           ; the speed argument to SetMotorSpeed.
        IMUL    BX                  ; Note that we must convert sign to a word
                                    ; since value is a word (use CBW).
       
SetDirectionOverflow:                ; Prevent overflow by MODing value by 360.
        MOV     BX, 360              ; Compute angle MOD 360 to prevent overflow 
                                     ; when adding the current angle.
        CWD                          ; Perform MOD by signed division, so need to
        IDIV    BX                   ; set DX to sign extend AX. The resulting
                                     ; mod is in DX.
        MOV     BX, DX               ; Move to BX because SetMotorSpeed takes
                                     ; the angle in BX.
        
SetDirectionAbsAngle:                ; Compute the absolute angle
        CALL    GetMotorDirection    ; Get current motor direction in AX.
        ADD     BX, AX               ; Compute new absolute direction based on
                                     ; relative angle passed by command.

DoSetDirection:        
        MOV     AX, NO_SPEED_CHANGE  ; Set speed argument to SetMotorSpeed.
                                     ; This value indicates that the speed should
                                     ; remain the same.
        
        CALL    SetMotorSpeed        ; Set motor speed to the new absolute speed 
                                     ; computed from the relative speed.
        
EndSetDirection:                
        MOV     AX, PARSER_GOOD      ; Return parser status through AX.
        RET                          ; This is returned by ParseSerialChar.

SetDirection    ENDP


; RotateTurret()
; 
; Description:       Rotates the turret of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token, so returns
;                    PARSER_GOOD in AX.
; Operation:         First checks if the sign has been set. If not, then
;                    simply calls SetTurretAngle(value) to set the absolute
;                    turret angle. If the sign has been set, sets value *= sign, 
;                    and then sets the relative angle using SetRelTurretAngle(value).
;                    Finally returns PARSER_GOOD in AX.
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
; Registers Changed: flags, AX, BX, DX.
; Special notes:     The specification states that if the sign token is present
;                    a relative angle should be set. Otherwise an absolute
;                    angle is set.
RotateTurret    PROC     NEAR
                
        MOV     AX, value               ; Move value to AX for processing.        
        CMP     sign, NO_SIGN           ; First check if sign token was seen.
        JNE     DoRotateTurretRelative  ; If so, the sign has been set, and
                                        ; the angle is relative.
        ;JE     DoRotateTurretAbsolute  ; Otherwise the angle is absolute.
        
DoRotateTurretAbsolute:             ; Treat value as an absolute angle
        CALL    SetTurretAngle      ; and set the new turret angle.
        JMP     EndRotateTurret
 
DoRotateTurretRelative:             
        MOV     AL, sign            ; Multiply value by sign to get the signed
        CBW                         ; representation of value in AX, which is
        MOV     BX, value           ; the speed argument to SetMotorSpeed.
        IMUL    BX                  ; Note that we must convert sign to a word
                                    ; since value is a word (use CBW).
                                  
        CALL    SetRelTurretAngle   ; Set turret new relative turret angle.
        ;JMP    EndRotateTurret
        
EndRotateTurret:                
        MOV     AX, PARSER_GOOD     ; Return parser status through AX.
        RET                         ; This is returned by ParseSerialChar.

RotateTurret    ENDP


; ParserSetTurretEle()
; 
; Description:       Sets the turret elevation of the RoboTrike based on the
;                    shared variables. Is only called after a correctly
;                    parsed string reaches the TOKEN_END_CMD token, so returns
;                    PARSER_GOOD in AX.
; Operation:         First checks if the sign has been set. If not, then
;                    sets sign = 1. Then sets value *= sign, and 
;                    and sets the absolute angle using SetTurretElevation(value).
;                    Finally returns PARSER_GOOD in AX.
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
; Registers Changed: flags, AX, BX, DX.
; Special notes:     None.
ParserSetTurretEle PROC     NEAR
                
        CMP     sign, NO_SIGN           ; First check if sign token was seen.
        JNE     DoParserSetTurretEle    ; If so, the sign has been set.
        ;JE     ParserSetTurretEleDefaultSign ; Otherwise the sign needs to be set.
        
ParserSetTurretEleDefaultSign:
        MOV     sign, 1             ; Default sign is positive.
 
DoParserSetTurretEle:
        MOV     AL, sign            ; Multiply value by sign to get the signed
        CBW                         ; representation of value in AX, which is
        MOV     BX, value           ; the speed argument to SetMotorSpeed.
        IMUL    BX                  ; Note that we must convert sign to a word
                                    ; since value is a word (use CBW).
                                    
        CALL    SetTurretElevation  ; Set the turret evlevation with the new absolute
                                    ; elevation.
        
EndParserSetTurretEle:                
        MOV     AX, PARSER_GOOD     ; Return parser status through AX.
        RET                         ; This is returned by ParseSerialChar.

ParserSetTurretEle ENDP


; WriteLaser(tkn_val)
; 
; Description:       Fires the RoboTrike laser if the token value is TRUE.
;                    Is only called after a correctly parsed string sees the 
;                    TOKEN_END_CMD token, so returns PARSER_GOOD in AX.
; Operation:         Calls SetLaser(Tkn_val) to fire the laser according to the
;                    token value. Finally returns PARSER_GOOD in AX.
;
; Arguments:         tkn_val (AL) - Value of laser command token. TRUE if laser
;                                   needs to be fired, and FALSE otherwise.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to laser - whether or not to fire the laser.
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
; Registers Changed: flags, AX.
; Special notes:     None.
WriteLaser       PROC     NEAR
                
DoWriteLaser:
        MOV     laser, AL           ; Write to laser shared variable according
                                    ; to token value.
        
EndWriteLaser:                
        MOV     AX, PARSER_GOOD     ; Return parser status through AX.
        RET                         ; This is returned by ParseSerialChar.

WriteLaser       ENDP


; FireLaser()
; 
; Description:       Fires the RoboTrike laser if the token value is TRUE.
;                    Is only called after a correctly parsed string sees the 
;                    TOKEN_END_CMD token, so returns PARSER_GOOD in AX.
; Operation:         Loads laser in AX and calls SetLaser(AX) to fire the laser 
;                    according to the laser shared variable. 
;                    Finally returns PARSER_GOOD in AX.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads laser - laser value from token.
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
; Registers Changed: flags, AX.
; Special notes:     None.
FireLaser       PROC     NEAR
                
DoFireLaser:
        MOV     AL, laser           ; Load laser shared variable (byte) into
        CBW                         ; AX using CBW to convert to word.
        CALL    SetLaser            ; Set laser according to shared variable.
        
EndFireLaser:                
        MOV     AX, PARSER_GOOD     ; Return parser status through AX.
        RET                         ; This is returned by ParseSerialChar.

FireLaser       ENDP


; DoNOP()
; 
; Description:       Used to handle whitespace, which is just ignored. Returns 
;                    PARSER_GOOD in AX.
; Operation:         Returns PARSER_GOOD in AX.
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
; Registers Changed: AX.
; Special notes:     None.
DoNOP           PROC     NEAR
                
        MOV     AX, PARSER_GOOD  ; Return PARSER_GOOD.
        RET     ; This is returned by ParseSerialChar.

DoNOP          ENDP       
       
       
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
        %TABENT(TOKEN_WHITE_SPACE, 9) ;TAB (ignored)
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
        %TABENT(TOKEN_WHITE_SPACE, ' ')	;space (ignored)
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
        %TABENT(TOKEN_D_CMD, 'D')	;D (set direction command)
        %TABENT(TOKEN_E_CMD, 'E')   ;E (set turret elevation angle command)
        %TABENT(TOKEN_LASER_CMD, TRUE) ;F (fire laser on command)
        %TABENT(TOKEN_OTHER, 'G')	;G
        %TABENT(TOKEN_OTHER, 'H')	;H
        %TABENT(TOKEN_OTHER, 'I')	;I
        %TABENT(TOKEN_OTHER, 'J')	;J
        %TABENT(TOKEN_OTHER, 'K')	;K
        %TABENT(TOKEN_OTHER, 'L')	;L
        %TABENT(TOKEN_OTHER, 'M')	;M
        %TABENT(TOKEN_OTHER, 'N')	;N
        %TABENT(TOKEN_LASER_CMD, FALSE) ;O (laser off command)
        %TABENT(TOKEN_OTHER, 'P')	;P
        %TABENT(TOKEN_OTHER, 'Q')	;Q
        %TABENT(TOKEN_OTHER, 'R')	;R
        %TABENT(TOKEN_S_CMD, 'S')	;S (set absolute speed command)
        %TABENT(TOKEN_T_CMD, 'T')	;T (rotate turret angle command)
        %TABENT(TOKEN_OTHER, 'U')	;U
        %TABENT(TOKEN_V_CMD, 'V')	;V (set relative speed command)
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
        %TABENT(TOKEN_D_CMD, 'd')	;d (set direction command)
        %TABENT(TOKEN_E_CMD, 'e')   ;e (set turret elevation angle command)
        %TABENT(TOKEN_LASER_CMD, TRUE) ;f (fire laser on command)
        %TABENT(TOKEN_OTHER, 'g')	;g
        %TABENT(TOKEN_OTHER, 'h')	;h
        %TABENT(TOKEN_OTHER, 'i')	;i
        %TABENT(TOKEN_OTHER, 'j')	;j
        %TABENT(TOKEN_OTHER, 'k')	;k
        %TABENT(TOKEN_OTHER, 'l')	;l
        %TABENT(TOKEN_OTHER, 'm')	;m
        %TABENT(TOKEN_OTHER, 'n')	;n
        %TABENT(TOKEN_LASER_CMD, FALSE) ;o (laser off command)
        %TABENT(TOKEN_OTHER, 'p')	;p
        %TABENT(TOKEN_OTHER, 'q')	;q
        %TABENT(TOKEN_OTHER, 'r')	;r
        %TABENT(TOKEN_S_CMD, 's')	;s (set absolute speed command)
        %TABENT(TOKEN_T_CMD, 't')	;t (rotate turret angle command)
        %TABENT(TOKEN_OTHER, 'u')	;u
        %TABENT(TOKEN_V_CMD, 'v')   ;v (set relative speed command)
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
;                   Each entry consists of the next state and action for that
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
    %TRANSITION(RESET_STATE, GetParserError)  ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError)  ;TOKEN_SIGN
    %TRANSITION(READ_S_STATE, InitParser)     ;TOKEN_S_CMD
    %TRANSITION(READ_V_STATE, InitParser)     ;TOKEN_V_CMD
    %TRANSITION(READ_D_STATE, InitParser)     ;TOKEN_D_CMD
    %TRANSITION(READ_T_STATE, InitParser)     ;TOKEN_T_CMD
    %TRANSITION(READ_E_STATE, InitParser)     ;TOKEN_E_CMD
    %TRANSITION(READ_LASER_STATE, WriteLaser) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, DoNOP)           ;TOKEN_END_CMD
    %TRANSITION(RESET_STATE, DoNOP)           ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError)  ;TOKEN_OTHER
    
    ;Current State = READ_S_STATE            Input Token Type
    %TRANSITION(S_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(S_SIGN_STATE, SetSign)       ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(READ_S_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = READ_V_STATE            Input Token Type
    %TRANSITION(V_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(V_SIGN_STATE, SetSign)       ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(READ_V_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = READ_D_STATE            Input Token Type
    %TRANSITION(D_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(D_SIGN_STATE, SetSign)       ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(READ_D_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER 
    
    ;Current State = READ_T_STATE            Input Token Type
    %TRANSITION(T_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(T_SIGN_STATE, SetSign)       ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(READ_T_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER   
    
    ;Current State = READ_E_STATE            Input Token Type
    %TRANSITION(E_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(E_SIGN_STATE, SetSign)       ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(READ_E_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = READ_LASER_STATE        Input Token Type
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, FireLaser)      ;TOKEN_END_CMD
    %TRANSITION(READ_LASER_STATE, DoNOP)     ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = S_SIGN_STATE           Input Token Type
    %TRANSITION(S_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(S_SIGN_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = V_SIGN_STATE            Input Token Type
    %TRANSITION(V_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_END_CMD
    %TRANSITION(V_SIGN_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = D_SIGN_STATE            Input Token Type
    %TRANSITION(D_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError)  ;TOKEN_END_CMD
    %TRANSITION(D_SIGN_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = T_SIGN_STATE            Input Token Type
    %TRANSITION(T_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError)   ;TOKEN_END_CMD
    %TRANSITION(T_SIGN_STATE, DoNOP)         ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = E_SIGN_STATE                Input Token Type
    %TRANSITION(E_DIGIT_STATE, AddDigit)         ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_END_CMD
    %TRANSITION(E_SIGN_STATE, DoNOP)             ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_OTHER
    
    ;Current State = S_DIGIT_STATE           Input Token Type
    %TRANSITION(S_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, SetAbsSpeed)    ;TOKEN_END_CMD
    %TRANSITION(S_DIGIT_STATE, DoNOP)        ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = V_DIGIT_STATE           Input Token Type
    %TRANSITION(V_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, SetRelSpeed)    ;TOKEN_END_CMD
    %TRANSITION(V_DIGIT_STATE, DoNOP)        ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = D_DIGIT_STATE           Input Token Type
    %TRANSITION(D_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, SetDirection)   ;TOKEN_END_CMD
    %TRANSITION(D_DIGIT_STATE, DoNOP)        ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = T_DIGIT_STATE           Input Token Type
    %TRANSITION(T_DIGIT_STATE, AddDigit)     ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, RotateTurret)   ;TOKEN_END_CMD
    %TRANSITION(T_DIGIT_STATE, DoNOP)        ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError) ;TOKEN_OTHER
    
    ;Current State = E_DIGIT_STATE               Input Token Type
    %TRANSITION(E_DIGIT_STATE, AddDigit)         ;TOKEN_DIGIT
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_SIGN
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_S_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_V_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_D_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_T_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_E_CMD
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_LASER_CMD
    %TRANSITION(RESET_STATE, ParserSetTurretEle) ;TOKEN_END_CMD
    %TRANSITION(E_DIGIT_STATE, DoNOP)            ;TOKEN_WHITE_SPACE
    %TRANSITION(RESET_STATE, GetParserError)     ;TOKEN_OTHER
    
CODE    ENDS
    
    
; Parser shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state           DB  ?   ; current FSM state.
    laser           DB  ?   ; whether to fire the laser.
    value           DW  ?   ; value built up by parsing digit tokens.
    sign            DB  ?   ; sign of value. signals if the optional sign token
                            ; has been included or not. Starts as NO_SIGN, and
                            ; becomes 1, or -1 depending on the sign. The default
                            ; assumed value is 1.
DATA    ENDS

        END