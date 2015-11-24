;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                HW8 Outline                                   ;
;                                 David Qu                                     ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contain the functions to parse the next serial character as a part
; of a finite state machine (FSM). This FSM is meant to be run on the motor
; unit of the RoboTrike, and will call various motor functions in response to 
; commands in the RoboTrike Serial Command Format. An overview of the parser
; design with more details follows after the table of contents.
; 
; Public functions:
; InitParser()         - initializes parser shared variables.
; ParseSerialChar(c)   - parse the passed character as part of a serial command. 
;
; Local functions:
; GetParserToken(char) - returns the token class and token value for the passed char.
; SetCommand(tkn_val)  - sets the command shared variable.
; AddDigit(tkn_val)    - updates the value shared variable based on the next digit.
; SetSign(tkn_val)     - sets the sign shared variable.
; DoCommand(tkn_val)   - does a command based on the command, value, and sign
;                        shared variables.
; SetAbsSpeed()        - sets absolute speed of the RoboTrike.
; SetRelativeSpeed()   - sets relative speed of the RoboTrike.
; SetDirection()       - sets direction of the RoboTrike.
; RotateTurret()       - rotates turret of the RoboTrike.
; SetTurretEle()       - sets turret elevation angle.
; FireLaser()          - fires the laser.
; LaserOff()           - turns the laser off
; DoNOP(tkn_val)       - does nothing.
; SetError(tkn_val)    - sets the return value shared variable to PARSER_ERROR.
; 
; 
; Read only tables:
; TokenTypeTable      - table of token types.
; TokenValueTable     - table of token values.
; StateTable          - table of state transitions.
; CommandTable        - table of commands to do.
;
; Note that the token tables are created using macros to avoid having to sync
; multiple tables.


; Parser Design Overview:
; This parser is implemented as a Mealy Finite State Machine (FSM), because the
; characters received from the serial may have unknown transmission delays
; that divide up command strings. This FSM implements the RoboTrike Serial 
; Command Format, which is specified at wolverine.caltech.edu/eecs51/homework/rcser.htm
;
; Inputs 
;   Characters   Input Class    Value
;      0 - 9        digit       0 - 9    (next digit in value)
;     + and -       sign        +1, -1   (sign of value)
;     S and s       command       0      (sets absolute speed)
;     V and v       command       2      (sets relative speed)
;     D and d       command       4      (sets direction)
;     T and t       command       6      (rotates turret)
;     E and e       command       8      (changes turret elevation)
;     F and f       simpleCmd     10     (fires laser)
;     O and o       simpleCmd     12     (turns laser off)
;     <Return>      endCmd        13      (this is the ASCII decimal 13 or CR that
;                                         signals the end of a command).
;    all others     other         character (original character value for debugging)
;
; Note that simpleCmds don't take in any arguments. This distinction is made
; so that regular commands require an argment and will enqueue an error event
; if they do not contain an argument. simpleCmds and commands share the same
; numbering because they will index into word function tables
;
; 
; Outputs/Actions
;   Actions       Description                           Implementing function
;   setCommand    sets which command to use             SetCommand()
;   addDigit      increases the value shared variable   AddDigit()
;   setSign       sets the sign shared variable         SetSign()
;   doCommand     perform command                       DoCommand()
;   reset         reset shared variables                InitParser()
;   NOP           do nothing                            DoNOP()
;   error         set return shared var to PARSER_ERROR SetError()
;       
; States
;   State         Description
;   InitialState  initial/default state
;   ReadCmd       just read command with arguments
;   ReadSimpleCmd just read command without arguments
;   SignState     just read sign
;   DigitState    just read digit
;   ResetState    wait until next valid command and then reset shared variables. 
;
; State Transition Table
;                                   Current Input
;   Current State     digit       sign       command      simpleCmd       endCmd     other   
;   InitialState    ResetState  ResetState   ReadCmd      ReadSimpleCmd ResetState  ResetState
;                     error       error      setCommand    setCommand      error      error
;   ReadCmd         DigitState  SignState    ResetState   ResetState    ResetState  ResetState
;                    addDigit    setSign       error        error          error      error
;   ReadSimpleCmd   ResetState  ResetState   ResetState   ResetState    ResetState  ResetState
;                     error       error        error        error        doCommand    error
;   SignState       DigitState  ResetState   ResetState   ResetState    ResetState  ResetState
;                    addDigit     error        error        error          error      error
;   DigitState      DigitState  ResetState   ResetState   ResetState    ResetState  ResetState
;                    addDigit     error        error        error        doCommand    error
;   ResetState      ResetState  ResetState   ReadCmd      ReadSimpleCmd ResetState  ResetState
;                      NOP        NOP          reset        reset           NOP       NOP
;
; Note this design uses the ResetState for both reseting out of errors and
; reseting from a completed command. This is because in both cases, you stay
; at ResetState until you read. Because this is a Mealy FSM, the error function
; is called as part of the bad transitions that lead to ResetState. The
; DoCommand is called as part of the valid transition from digit state to 
; ResetState or ReadSimpleCmd to ResetState. 

; Return values for ParseSerialChar (PSC)
PARSER_GOOD             EQU     0       ; Return value for a good call to PSC.
PARSER_ERROR            EQU     1       ; Return value for a bad call to PSC.


; Token Type constants:
TOKEN_DIGIT             EQU     0       ; token is a digit: 0 to 9
TOKEN_SIGN              EQU     1       ; token is a sign: + or -
TOKEN_COMMAND           EQU     2       ; token is a command that takes arguments: 
                                        ; S, s, V, v, D, d, T, t, E, or e.
TOKEN_SIMPLE_CMD        EQU     3       ; token is a command that doesn't take arguments:
                                        ; F, f, O, or o.
TOKEN_END_CMD           EQU     4       ; token is Carriage Return (<Return>)
TOKEN_OTHER             EQU     5       ; anything else

NUM_TOKEN_TYPES         EQU     6       ; number of token types

; Token values
NO_SIGN                 EQU     FALSE   ; Default no sign value.
                                        ; This lets us know if the optional sign
                                        ; has been included or not.
; Command values
COMMAND_S               EQU     0       ; set absolute speed command
COMMAND_V               EQU     2       ; set relative speed command
COMMAND_D               EQU     4       ; set direction command
COMMAND_T               EQU     6       ; rotate turret angle command
COMMAND_E               EQU     8       ; set turret elevation angle command
COMMAND_F               EQU     10      ; fire laser command
COMMAND_O               EQU     12      ; laser off command
COMMAND_NONE            EQU     14      ; No command (Can put a debugging function
                                        ; here during testing).

; State constants:
;   note that these MUST match the layout of the transition table. 
INITIAL_STATE           EQU     0       ; initial state for FSM.
READ_CMD_STATE          EQU     1       ; just read command with arguments
READ_SIMPLE_CMD_STATE   EQU     2       ; just read command without args
SIGN_STATE              EQU     3       ; just read sign token
DIGIT_STATE             EQU     4       ; just read digit
RESET_STATE             EQU     5       ; wait for next command token

NUM_STATES              EQU     6       ; number of states

; Other constants
TOKEN_MASK              EQU     01111111B ; mask high bit of token.


; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    state           DB  ?   ; current FSM state.
    command         DB  ?   ; index of command to use.
    value           DW  ?   ; value used by transitions.
    sign            DB  ?   ; sign of value. signals if the optional sign token
                            ; has been included or not.
    return          DB  ?   ; return value for ParseSerialChar.
    
DATA    ENDS

; InitParser()
; 
; Description:       Initializes the state, command, value, sign, and return 
;                    shared variables.       
; Operation:         Sets state = INITIAL_STATE, command = COMMAND_NONE, 
;                    value = 0, sign = NO_SIGN, and return = PARSER_GOOD.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to state   - current state in FSM
;                    Writes to command - command being processed
;                    Writes to value   - value being built up
;                    Writes to sign    - flag for optional sign token
;                    Writes to return  - return status of ParseSerialChar
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
; state = INITIAL_STATE
; command = COMMAND_NONE
; value = 0
; sign = NO_SIGN
; return = PARSER_GOOD


; ParseSerialChar(char)
; 
; Description:       Parses the next serial character by using a Mealy FSM to 
;                    implement the RoboTrike Serial Command Format.
; Operation:         First get the token_value and token_type using GetParserToken().
;                    Then, perform the action specified by the state and token_type
;                    with the token_value as an argument. Finally, update the
;                    state based on the state and token_type combination.
;
; Arguments:         char (AL) - character from serial to parse.
; Return Value:      return_status - status value indicating whether or not
;                                    the call was valid / successful.
;
; Local Variables:   token_value (AL) - value of the token for action function
;                    token_type  (AH) - type of token to determine state transition
;                    index (BX)       - byte index into state table
; Shared Variables:  Read/Writes to state   - current state in FSM
;                    Read/Writes to command - command being processed
;                    Read/Writes to value   - value being built up
;                    Read/Writes to sign    - flag for optional sign token
;                    Read/Writes to return  - return status of ParseSerialChar
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
; Registers Changed: flags, AX, BX.
; Special notes:     None.
;
; Pseudo code:
; unsigned byte token_value, unsigned byte token_type = GetParserToken(c)
; unsigned word index = NUM_TOKEN_TYPES * state + token_type
; StateTable[index].action(token_value)
; state = StateTable[index].nextstate
; return return  ; Return the return shared variable. Assembly doesn't have
;                ; return as a keyword, so this should be fine.


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
; char &= TOKEN_MASK
; unsigned byte token_value = TokenValueTable[char]
; unsigned byte token_type = TokenTypeTable[char] 
; return token_value, token_type


; SetCommand(tkn_val)
; 
; Description:       Sets the command shared variable according to the passed
;                    tkn_val (AL).
; Operation:         Sets command = tkn_val.
;
; Arguments:         tkn_val (AL) - token value for action.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Read/Writes to command - command being processed
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
; command = tkn_val


