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
; InitParser()        - initializes parser shared variables.
; ParseSerialChar(c)  - parse the passed character as part of a serial command. 
;
; Local functions:
; GetParserToken      - returns the token class and token value for the passed char.
; SetCommand          - sets the command shared variable.
; AddDigit            - updates the value shared variable based on the next digit.
; SetSign             - sets the sign shared variable.
; DoCommand           - does a command based on the command, value, and sign
;                       shared variables.
; DoNOP               - does nothing.
; EnqueueError        - enqueues an error to the event queue.
; 
; 
; Read only tables:
; TokenTypeTable
; TokenValueTable
; StateTable
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
;     <Return>      endCmd        0      (this is the ASCII decimal 13 or CR that
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
;   ResetState      ResetState  ResetState   InitialState InitialState  ResetState  ResetState
;                      NOP        NOP          reset        reset           NOP       NOP
;
; Note this design uses the ResetState for both reseting out of errors and
; reseting from a completed command. This is because in both cases, you stay
; at ResetState until you read. Because this is a Mealy FSM, the error function
; is called as part of the bad transitions that lead to ResetState. The
; DoCommand is called as part of the valid transition from digit state to 
; ResetState or ReadSimpleCmd to ResetState. 

; Return values for ParseSerialChar (PSC)
PARSER_GOOD         EQU     0       ; Return value for a good call to PSC.
PARSER_ERROR        EQU     1       ; Return value for a bad call to PSC.

; Token constants:


; State constants:
INITIAL_STATE       EQU     0       ; Value for initial state
READ_CMD            EQU     1       ; Value for a serial error event.
READ_SIMPLE_CMD     EQU     2       ; Value for a serial data event.  

; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    command         DB  ?   ; index of command to use.
    value           DW  ?   ; value used by transitions
    sign            DB  ?   ; sign of value
    return          DB  ?   ; return value for ParseSerialChar.
    
DATA    ENDS

; InitParser()
; 
; Description:       Initializes the command        
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
; Pseudo code:
; 

; ParseSerialChar(c)
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
; Pseudo code:
; 
