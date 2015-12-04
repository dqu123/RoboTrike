;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  parser.inc                                ;
;                             RoboTrike Parser Module                        ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the RoboTrike parser module, which 
; contains the functions to parse serial data one character at a time, asynchronously.
; This module is designed for use on the RoboTrike motor unit, and implements
; the RoboTrike Serial Command Format, which is specified at 
; wolverine.caltech.edu/eecs51/homework/rcser.htm 
; The parser operates as a Mealy Finite State Machine (FSM). The token types, 
; token values, action functions, and states of the FSM are listed below as
; constants.
;
; Revision History:
;	 11/25/15  David Qu			initial revision
;    11/27/15  David Qu         added SIGN_STATES

; Return values for ParseSerialChar (PSC)
PARSER_GOOD             EQU     0       ; Return value for a good call to PSC.
PARSER_ERROR            EQU     1       ; Return value for a bad call to PSC.

; Parser overflow constants
MAX_NEGATIVE            EQU     32768   ; Maximum magnitude of a unsigned 
                                        ; negative number.

; Token Type constants:
TOKEN_DIGIT             EQU     0       ; token is a digit: 0 to 9
TOKEN_SIGN              EQU     1       ; token is a sign: + or -
TOKEN_S_CMD             EQU     2       ; token is a "S" or "s" command.
TOKEN_V_CMD             EQU     3       ; token is a "S" or "s" command.
TOKEN_D_CMD             EQU     4       ; token is a "S" or "s" command.
TOKEN_T_CMD             EQU     5       ; token is a "S" or "s" command.
TOKEN_E_CMD             EQU     6       ; token is a "S" or "s" command.
TOKEN_LASER_CMD         EQU     7       ; token is a "F", "f", "O", or "o" command.
TOKEN_END_CMD           EQU     8       ; token is Carriage Return (<Return>).
TOKEN_WHITE_SPACE       EQU     9       ; token is white space (ignore).
TOKEN_OTHER             EQU     10      ; anything else.

NUM_TOKEN_TYPES         EQU     11      ; number of token types

; Token values
NO_SIGN                 EQU     0       ; Default no sign value.
                                        ; This lets us know if the optional sign
                                        ; has been included or not. The sign value
                                        ; is set to 1 if a "+" is seen, and to 
                                        ; -1 if a "-" is seen.

; State constants:
;   note that these MUST match the layout of the transition table. 
RESET_STATE             EQU     0       ; initial/reset state for FSM.
READ_S_STATE            EQU     1       ; just read "S"
READ_V_STATE            EQU     2       ; just read "V"
READ_D_STATE            EQU     3       ; just read "D"
READ_T_STATE            EQU     4       ; just read "T"
READ_E_STATE            EQU     5       ; just read "E"
READ_LASER_STATE        EQU     6       ; just read "F" or "O"
S_SIGN_STATE            EQU     7       ; just read sign token after "S"
V_SIGN_STATE            EQU     8       ; just read sign token after "V"
D_SIGN_STATE            EQU     9       ; just read sign token after "D"
T_SIGN_STATE            EQU     10      ; just read sign token after "T"
E_SIGN_STATE            EQU     11      ; just read sign token after "E"
S_DIGIT_STATE           EQU     12      ; just read digit token after "S"
V_DIGIT_STATE           EQU     13      ; just read digit token after "V"
D_DIGIT_STATE           EQU     14      ; just read digit token after "D"
T_DIGIT_STATE           EQU     15      ; just read digit token after "T"
E_DIGIT_STATE           EQU     16      ; just read digit token after "E"

NUM_STATES              EQU     17      ; number of states

; Other constants
TOKEN_MASK              EQU     01111111B ; mask high bit of token.