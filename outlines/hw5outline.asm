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
; ResetKeypad    - reset shared variables (key, debCntr, rptCntr, rptRate)
; ScanKeypad     - Return key or NO_KEY in AL, picks first row that has a valid 
;                  key combination that includes at least one pressed key.
; KeypadDebounce - updates and returns debounced value in AL (true or false).



; Keypad Encoding:
; The keypad is a 4x4 grid that groups each row into a output byte value that 
; ranges from 70 to 7F, depending on which combination of 4 buttons is pressed.
;
;  Decimal value        -1 -2 -4 -8   For example, if key #10 is pressed, then
;  ================================   address 82H will contain 7DH because 15 - 2
;  Row 0 (Address 80H):  1  2  3  4   = 13 = D in hex. If both keys 6 and 7 are
;  Row 1 (Address 81H):  5  6  7  8   pressed, address 81H will contain 79H
;  Row 2 (Address 82H):  9 10 11 12   since 15 - 2 - 4 = 9. Note that the top
;  Row 3 (Address 83H): 13 14 15 16   four bits are always 7H.
; 
; For these procedures, key values are encoded as bytes that determine both
; the row in the keypad, and the button combination.
; The top four bits repesent the row in the keypad while the bottom four bits
; represent the key combination, which ranges from 0 to F, and has the same 
; encoding as the bottom four bits of the keypad's output ports. So, if both
; keys 6 and 7 are press this will be represented as 19H.

; Constants.

; General constants
TRUE                EQU     1       ; Boolean true value.
FALSE               EQU     0       ; Boolean false value.

; Keypad constants
KEYPAD_ADDRESS      EQU     80H     ; Address of keypad io ports.
NO_KEY_VALUE        EQU     0FH     ; Value representing no key pressed.
KEY_VALUE_MASK      EQU     0FH     ; Mask to get digit combination from the
                                    ; keypad output byte format.
NUM_KEY_ROWS        EQU     4       ; Number of rows in the keypad.
KEY_ROW_SHIFT       EQU     4       ; Amount to shift index to encode key row.

; Event constants
KEYPRESS_EVENT      EQU     1       ; Value for a keypress event. (Actual value
                                    ; will be determined once all events are 
                                    ; determined).

; Timing parameters
DEBOUNCE_TIME       EQU     10      ; Time in ms to debounce a key press to
                                    ; make sure a button was actually pressed.
REPEAT_TIME         EQU     5000    ; Time in ms until start fast repeating (5s)
DEFAULT_RPT_RATE    EQU     2000    ; slow repeat rate (0.5 Hz)
FAST_RPT_RATE       EQU     500     ; fast repeat rate (2 Hz)


; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    
    key         DB  ?   ; The most recent key value scanned from the keypad.
                        ; Gives both row and 4 button combination of the first
                        ; row with pressed keys.
    debCntr     DW  ?   ; Counter of clock ticks that determines when the key
                        ; has been debounced.
    rptCntr     DW  ?   ; Counter of clock ticks that determines when the repeat
                        ; rate should speed up to FAST_RPT_RATE.
    rptRate     DW  ?   ; Time in ms to wait until registering an auto-repeated
                        ; button press.
    
DATA    ENDS

; HandleKeypad
; 
; Description:       Checks the keypad for a keypress and enqueues an keypress
;                    event to the EventQueue if a keypress has occurred.
;                    Keypresses are encoded in the byte format described above,
;                    and keypress events are encoded as words with the top byte
;                    set as the KEYPRESS_EVENT constant, and the bottom byte
;                    set as the keypress value.
;                    Note: this procedure should be called by a timer interrupt 
;                    handler that is installed in the IVT.
;   
; Operation:         First, check if key != NO_KEY_VALUE. If key == NO_KEY_VALUE,
;                    scan the keypad (using ScanKeypad) to see if a valid (non
;                    NO_KEY_VALUE) key combination has been pressed, and update
;                    key to the scanned value. If key is valid, debounce the key
;                    (using KeypadDebounce) and enqueue the event iff the
;                    debounced value == TRUE.   
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to key - encoding of a key press/combination.
;                              debCntr - counter to detemine if the key press
;                                        should be debounced.
;                              rptRate - rate to auto repeat a key when held.
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
; Limitations:       Assumes keypad shared variables have been initialized.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; if (KeypadDebounce(key))
;     EnqueueEvent(KEYPRESS_EVENT, key)  



; ResetKeypad
; 
; Description:       Resets the keypad shared variables. key is set to
;                    NO_KEY_VALUE, debounced is set to FALSE, debCntr is set to 
;                    DEBOUNCE_TIME, and rptRate is set to DEFAULT_RPT_RATE.
;   
; Operation:         Sets key = NO_KEY_VALUE, debCntr = DEBOUNCE_TIME, 
;                    rptCntr = REPEAT_TIME, and rptRate = DEFAULT_RPT_RATE.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to key - encoding of a key press/combination.
;                              debCntr - counter to detemine if the key press
;                                        should be debounced.
;                              rptCntr - counter to determine if the repeat rate
;                                        should increase.
;                              rptRate - rate to auto repeat a key when held.
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
; unsigned byte key = NO_KEY_VALUE
; unsigned word debCntr = DEBOUNCE_TIME
; unsigned word rptCntr = REPEAT_TIME
; unsigned word rptRate = DEFAULT_RPT_RATE



; ScanKeypad
; 
; Description:       Scans the keypad row by row for a keypress. Returns the
;                    keypress of the first row with a valid keypress starting
;                    from KEYPAD_ADDRESS. The returned value encodes both the
;                    row and key comination pressed as specified in the file
;                    description. Note this prevents button combinations across 
;                    rows from registering. 
;   
; Operation:         Check each row in the keypad output port until a valid
;                    keypress is found, or the end of the keypad is reached.
;                    If a valid keypress is found, encode the row number into
;                    the keypress and return the modified value. Otherwise, 
;                    return NO_KEY_VALUE.
;
; Arguments:         None.
; Return Value:      Keypress (AL) - keypress byte encoding both the row and key
;                                    combination pressed.
;
; Local Variables:   key (AL) - keypress being processed.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Iterates through array of keypress io ports, and encodes
;                    the row into the keypress using bit manipulations.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.
;
; Pseudo code:
; for (unsigned byte i = 0; i < NUM_KEY_ROWS; i++)
;     unsigned byte key = KEYPAD_ADDRESS[i]
;     if (key != NO_KEY_VALUE)
;         return_byte (i << KEY_ROW_SHIFT) | (key & KEY_VALUE_MASK)
; return_byte NO_KEY_VALUE




; KeypadDebounce
; 
; Description:       Debounces a keypress by scanning to make sure the same
;                    keypress is being sent DEBOUNCE_TIME counts in a row.
;                    Auto-repeats a keypress if it is held for rptRate counts
;                    after the initial debounce, and will speed up the auto
;                    repeat rate to FAST_RPT_RATE after REPEAT_TIME counts.
;                    Note: this procedure is used by HandleKeypad, which should
;                    be called in an appropriate event handler function to
;                    work correctly.
;   
; Operation:         First, scan the keypad to get the current keypress.
;                    Then, check if key is NO_KEY_VALUE. If it is, then there
;                    is no key to debounce, so ResetKeypad, update the key with 
;                    the current keypress, and return false. If key is valid, 
;                    then compare key with the current keypress and decrement 
;                    the debCntr if they match. If they don't match, ResetKeypad 
;                    and return false. If they match but debCntr != 0, then
;                    just return false. If debCntr reaches 0, then set the 
;                    debCntr to the rptRate and return true. Also decrement the 
;                    rptCntr and update rptRate to FAST_RPT_RATE if rptCntr reaches 0.
;
; Arguments:         None.
; Return Value:      debounced (AL) - whether the key has been debounced or not.
;
; Local Variables:   keypress (AX) - the current keypress when debouncing.
; Shared Variables:  Reads/writes to key - encoding of a key press/combination.
;                    Writes to debCntr - counter to detemine if the key press
;                                        should be debounced.
;                              rptRate - rate to auto repeat a key when held.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Debounces keypresses by checking that the same keypress
;                    has been registered DEBOUNCE_TIME counts in a row. Also
;                    registers an auto-repeated debounce if DEFAULT_RPT_RATE
;                    counts pass with the same keypress, and will increase
;                    the repeat rate after REPEAT_TIME.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       Assumes keypad shared variables have been properly initialized.
;
; Registers Changed: flags, AL.
; Special notes:     None.
;
; Pseudo code:
; unsigned byte cur_key = ScanKeypad()
; if (key == NO_KEY_VALUE)
;     ResetKeypad()
;     key = cur_key
;     return FALSE
; else if (key == cur_key)
;     debCntr--
;     rptCntr--
;     if (rptCntr == 0)
;         rptRate = FAST_RPT_RATE
;     if (debCntr == 0)
;         debCntr = rptRate
;         return TRUE
; else 
;     ResetKeypad()
;     return FALSE
