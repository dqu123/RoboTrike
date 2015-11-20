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
; SetCommand
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
;      0-9          digit       0 - 9    (next digit in value)
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
;    all others     other         character
;
; Note that simpleCmds don't take in any arguments. This distinction is made
; so that regular commands require an argment and will enqueue an error event
; if they do not contain an argument. simpleCmds and commands share the same
; numbering because they will index into word function tables
;
; 
; Outputs/Actions
;   Actions       Description
;   setCommand    sets which command to use
;   addDigit      increases the value shared variable
;   setSign       sets the sign shared variable
;   doCommand     perform command
;   reset         reset shared variables 
;   NOP           do nothing
;   error         enqueue serial error event and reset
;       
; States
;   State         Description
;   Initial       initial/default state
;   ReadCmd       just read command with arguments
;   ReadSimpleCmd just read command without arguments
;   SignState     just read sign
;   DigitState    just read digit
;   ResetState    wait until next valid command and then reset shared variables. 
;
; State Transition Table
;                                   Current Input
;   Current State     digit       sign       command      simpleCmd       endCmd     other   
;   Initial         ResetState  ResetState   ReadCmd     ReadSimpleCmd ResetState  ResetState
;                     error       error      setCommand   setCommand      error      error
;   ReadCmd         DigitState  SignState    ResetState  ResetState    ResetState  ResetState
;                    addDigit    setSign       error       error          error      error
;   ReadSimpleCmd   ResetState  ResetState   ResetState  ResetState    ResetState  ResetState
;                     error       error        error       error        doCommand    error
;   SignState       DigitState  ResetState   ResetState  ResetState    ResetState  ResetState
;                    addDigit     error        error       error          error      error
;   DigitState      DigitState  ResetState   ResetState  ResetState    ResetState  ResetState
;                    addDigit     error        error       error        doCommand    error
;   ResetState      ResetState  ResetState   Initial     Initial       ResetState  ResetState
;                      NOP        NOP          reset       reset           NOP       NOP
;
; Note this design uses the ResetState for both reseting out of errors and
; reseting from a completed command. This is because in both cases, you stay
; at ResetState until you read. Because this is a Mealy FSM, the error function
; is called as part of the bad transitions that lead to ResetState. The
; doCommand is called as part of the valid transition from digit state to 
; ResetState or ReadSimpleCmd to ResetState.
  
; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    command         DB  ?   ; index of command to use.
    value           DW  ?   ; value used by transitions
    sign            DB  ?   ; sign of value
    
DATA    ENDS

; InitParser()
; 
; Description:       Initializes        
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
