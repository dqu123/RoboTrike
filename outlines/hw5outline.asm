;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                HW5 Outline                                   ;
;                                 David Qu                                     ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; Public functions:
; HandleKeypad   - scans for a key press, or debounces the current keypress.
;                  if a key is debounced, calls EnqueueEvent.
;
; Local functions:
; ResetKeypad    - reset shared variables (key, debounced, debCntr, rptRate)
; KeypadDebounce - updates and returns debounced value in AL (true or false).
; ScanKeypad     - Return key or NO_KEY in AL, picks first row that has a valid 
;                  key combination that includes at least one pressed key.

; Keypad Encoding:
; The keypad is a 4x4 grid that groups each row into a byte value that ranges
; from 70 to 7F, depending on which combination of 4 buttons is pressed.
; For these procedures, key values are encoded as bytes that determine both
; the row in the keypad, and the button combination.
; The top four bits repesent the row in the keypad while the bottom four bits
; represent the key combination, which ranges from 0 to F, and has the same 
; encoding as the bottom four bits of the keypad's output ports.

; Constants.
NO_KEY_VALUE        EQU     0FH
KEY_VALUE_MASK      EQU     0FH
NUM_KEY_ROWS        EQU     4
DEFAULT_RPT_RATE    EQU     1000
FAST_RPT_RATE       EQU     500  


; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    
    key         DB  ? 
    debounced   DB  ?
    debCntr     DW  ?
    rptRate     DW  ?
    
DATA    ENDS


; Function1
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


; Function1
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