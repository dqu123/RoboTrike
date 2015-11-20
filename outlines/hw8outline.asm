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
DIGIT_TOKEN             EQU     0       ; token is a digit: 0 to 9
SIGN_TOKEN              EQU     1       ; token is a sign: + or -
COMMAND_TOKEN           EQU     2       ; token is a command that takes arguments: 
                                        ; S, s, V, v, D, d, T, t, E, or e.
SIMPLE_CMD_TOKEN        EQU     3       ; token is a command that doesn't take arguments:
                                        ; F, f, O, or o.
END_CMD_TOKEN           EQU     4       ; token is Carriage Return (<Return>)
OTHER_TOKEN             EQU     5       ; anything else

NUM_TOKEN_TYPES         EQU     6       ; number of token types


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
        %TABENT(TOKEN_EOS, 0)		;<null>  (end of string)
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
        %TABENT(TOKEN_OTHER, 13)	;carriage return
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
        %TABENT(TOKEN_DP, 0)		;.  (decimal point)
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
        %TABENT(TOKEN_EXP, 0)		;E  (exponent indicator)
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
        %TABENT(TOKEN_EXP, 0)		;e  (exponent indicator)
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


StateTable	LABEL	TRANSITION_ENTRY

	;Current State = ST_INITIAL                      Input Token Type
	%TRANSITION(ST_MANDIGIT, setExp10P, addDigit)	;TOKEN_DIGIT
	%TRANSITION(ST_MANSIGN, setSign, doNOP)		;TOKEN_SIGN
	%TRANSITION(ST_LEADINGDP, setExp10N, doNOP)	;TOKEN_DP
	%TRANSITION(ST_ERROR, error, doNOP)		;TOKEN_EXP
	%TRANSITION(ST_ERROR, error, doNOP)		;TOKEN_EOS
	%TRANSITION(ST_ERROR, error, doNOP)		;TOKEN_OTHER

   
        
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
