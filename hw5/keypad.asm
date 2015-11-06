        NAME    KEYPAD

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  KEYPAD                                      ;
;                             Keypad functions                                 ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; Public functions:
; HandleKeypad   - scans for a key press, or debounces the current keypress.
;                  if a key is debounced, calls EnqueueEvent.
; InitKeypad     - Initializes the keypad
;
; Local functions:
; ResetKeypad    - reset shared variables (key, debCntr, rptCntr, rptRate)
; ScanKeypad     - scans current row that for a valid key combination that 
;                  includes at least one pressed key. Return key or NO_KEY_VALUE 
;                  in AL.
; KeypadDebounce - updates debounce counter and returns debounced value in AL 
;                  (true or false). Also checks if key is NO_KEY_VALUE.



; Keypad Encoding:
; The keypad is a 4x4 grid that groups each row into a output byte value that 
; ranges from X0H to XFH, depending on the combination of 4 buttons pressed.
;
;  Decimal value        -1 -2 -4 -8   For example, if key #10 is pressed, then
;  ================================   address 82H will contain XDH because 15 - 2
;  Row 0 (Address 80H):  1  2  3  4   = 13 = D in hex. If both keys 6 and 7 are
;  Row 1 (Address 81H):  5  6  7  8   pressed, address 81H will contain X9H
;  Row 2 (Address 82H):  9 10 11 12   since 15 - 2 - 4 = 9. Note that the top
;  Row 3 (Address 83H): 13 14 15 16   four bits are always XH, where X is 
;                                     dependent on the specific board, and
;                                     can be any value.
; 
; For these procedures, key values are encoded as bytes that determine both
; the row in the keypad, and the button combination.
; The top four bits represent the row in the keypad while the bottom four bits
; represent the key combination, which ranges from 0 to F, and has the same 
; encoding as the bottom four bits of the keypad's output ports. So, if both
; keys 6 and 7 are press this will be represented as 19H.
; Note that this encoding prevents combinations of keys spanning multiple rows,
; such as 1 and 5. The 2^16 possible combinations of key presses on a 16 digit 
; keypad takes at least one word to fully encode, but is unnecessary because no 
; one can remember 2^16 button combinations. The 4 * 2^4 = 64 button combinations
; allowed by this scheme should be plenty. 


; local include files
$INCLUDE(keypad.inc)
$INCLUDE(events.inc)
$INCLUDE(eoi.inc)
$INCLUDE(general.inc)


CGROUP	GROUP	CODE 
DGROUP  GROUP   DATA

CODE 	SEGMENT PUBLIC 'CODE'

		ASSUME 	CS:CGROUP, DS:DATA
		
		EXTRN	EnqueueEvent:NEAR   ;Adds events to the event queue.

; HandleKeypad
; 
; Description:       Checks the keypad for a keypress and enqueues an keypress
;                    event to the EventQueue if a keypress has occurred.
;                    Keypresses are encoded in the byte format described above,
;                    and keypress events are encoded as words with the top byte
;                    set as the KEYPRESS_EVENT constant, and the bottom byte
;                    set as the keypress value.
;                    Note: this procedure is an event handler should be 
;                    installed in the IVT to handle a timer event.
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
; Local Variables:   key (AL) - what the key press was.
;                    debounced (AH) - whether the key press has been debounced. 
; Shared Variables:  Writes to key - encoding of a key press/combination.
;                              row - current keypad row to scan.
;                              debCntr - counter to detemine if the key press
;                                        should be debounced.
;                              rptCntr - counter to determine if the repeat rate
;                                        should increase.
;                              rptRate - rate to auto repeat a key when held.
;                    (Writes by calling KeypadDebounce).
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
; Registers Changed: flags, AX.
; Special notes:     None.

HandleKeypad    PROC        NEAR
                PUBLIC      HandleKeypad
                
        PUSHA		                ;save the registers

HandleKeypadBody:                        
		CALL    KeypadDebounce      ;check for keypad event by calling
        TEST    AH, AH              ;KeypadDebounce, which sets AH to TRUE
        JZ      EndHandleKeypad     ;if there is an event to enqueue.    
        ;JNZ    EnqueueKeyEvent
        
EnqueueKeyEvent:
        MOV     AH, KEYPRESS_EVENT  ;If there's a key event, KeypadDebounce will
        CALL    EnqueueEvent        ;put the row, key bit pattern in AL, so we 
                                    ;just add the event type in AH to pass the 
                                    ;whole event.
        
        ;JMP    EndHandleKeypad     ;done handling keypad.


EndHandleKeypad:                    ;done taking care of the timer
        MOV     DX, INTCtrlrEOI     ;send the EOI to the interrupt controller
        MOV     AX, TimerEOI
        OUT     DX, AL

        POPA		                ;restore the registers


        IRET                ;and return (Event Handlers end with IRET not RET)

HandleKeypad  ENDP

; InitKeypad
; 
; Description:       Initializes the keypad shared variables. key is set to
;                    NO_KEY_VALUE, row is set to 0, debounced is set to FALSE, 
;                    debCntr is set to DEBOUNCE_TIME, and rptRate is set to 
;                    DEFAULT_RPT_RATE.
;   
; Operation:         Sets key = NO_KEY_VALUE, row = 0, debCntr = DEBOUNCE_TIME, 
;                    rptCntr = REPEAT_TIME, and rptRate = DEFAULT_RPT_RATE.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to key - encoding of a key press/combination.
;                              row - current keypad row to scan.
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
; Registers Changed: None.
; Special notes:     None.

InitKeypad     PROC        NEAR
        
        CALL    ResetKeypad     ; Reset key, debCntr, rptCntr, rptRate,
        MOV     row, 0          ; and row.
        
        RET

InitKeypad     ENDP

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
; Registers Changed: None.
; Special notes:     None.

ResetKeypad     PROC        NEAR
        
        MOV     key, NO_KEY_VALUE
        MOV     debCntr, DEBOUNCE_TIME
        MOV     rptCntr, REPEAT_TIME
        MOV     rptRate, DEFAULT_RPT_RATE
        
        RET

ResetKeypad     ENDP


; ScanKeypad
; 
; Description:       Scans the next keypad row for a keypress. Returns the
;                    keypress of the first row with a valid keypress starting
;                    from KEYPAD_ADDRESS. The returned value encodes the row,
;                    key comination pressed as specified in the file
;                    description. 
;                    Note this scanning prevents button combinations across rows 
;                    from registering. 
;   
; Operation:         Check each row in the keypad output port until a valid
;                    keypress is found, or the end of the keypad is reached.
;                    If a valid keypress is found, encode the row number into
;                    the keypress and return the modified value. Otherwise, 
;                    return NO_KEY_VALUE.
;
; Arguments:         None.
; Return Value:      Keypress (AL) - keypress byte encoding both the row and key
;                                    combination pressed. If no key is pressed,
;                                    keypress = NO_KEY_VALUE (row is not encoded).
;
; Local Variables:   key (AL) - keypress being processed.
;                    row (BL) - row to encode into keypress
; Shared Variables:  Reads row - current keypad row to scan.
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
; Limitations:       Assumes chip select has been initialized to access keypad.
;
; Registers Changed: flags, AL, BL, DX.
; Special notes:     None.

ScanKeypad      PROC        NEAR
        
        MOV     DX, KEYPAD_ADDRESS  ;Read keypress bits from
        ADD     DL, row             ;the keypad input port.
        IN      AL, DX
        
        AND     AL, KEY_VALUE_MASK  ;Extract key combination, and check
        CMP     AL, NO_KEY_VALUE    ;if any key has been pressed. 
        ;JNE    EncodeKeyRow        ;Encode the row number if a key has been
                                    ;pressed.
        JE      EndScanKeypad       ;Otherwise, return NO_KEY_VALUE.     
        
EncodeKeyRow:
        MOV     BL, row             ;Add the row number to the
        SHL     BL, KEY_ROW_SHIFT   ;key combination encoding
        OR      AL, BL              ;by OR-ing in a shifted value.

EndScanKeypad:

        RET

ScanKeypad  ENDP



; KeypadDebounce
; 
; Description:       Debounces a keypress by scanning to make sure the same
;                    keypress is being sent DEBOUNCE_TIME counts in a row.
;                    Auto-repeats a keypress if it is held for rptRate counts
;                    after the initial debounce, and will speed up the auto
;                    repeat rate to FAST_RPT_RATE after REPEAT_TIME counts.
;                    Note: this procedure is used by HandleKeypad, which should
;                    be installed as an event handler function to
;                    work correctly.
;   
; Operation:         First, scan the keypad to get the current keypress.
;                    Then, check if key is NO_KEY_VALUE. If it is, then there
;                    is no key to debounce, so ResetKeypad, update the row, and 
;                    return false. If key is valid, then compare key with the 
;                    current keypress and decrement the debCntr if they match. 
;                    If they don't match, ResetKeypad, update the row and return 
;                    false. If they match but debCntr != 0, then just return 
;                    false. If debCntr reaches 0, then set the debCntr to the 
;                    rptRate and return true. Also decrement the rptCntr and 
;                    update rptRate to FAST_RPT_RATE if rptCntr reaches 0.
;
; Arguments:         None.
; Return Value:      debounced (AH) - whether the key has been debounced or not.
;                    key       (AL) - debounced key if it's been debounced.
;
; Local Variables:   keypress (AL) - the current keypress when debouncing.
;                    temp (BX)     - temporary value for referencing.
; Shared Variables:  Reads/writes to key - encoding of a key press/combination.
;                    Writes to debCntr - counter to detemine if the key press
;                                        should be debounced.
;                              rptRate - rate to auto repeat a key when held.
;                              row - current keypad row to scan.
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
; Registers Changed: flags, AX.
; Special notes:     None.

KeypadDebounce  PROC        NEAR
        
        CALL    ScanKeypad          ;Scan current row for a keypress.
        CMP     AL, NO_KEY_VALUE    ;If no keys have been pressed, move on to
        JE      NextRow             ;the next row.
        
        CMP     key, NO_KEY_VALUE   ;If the previous key was not valid
        JE      CheckRptCntr        ;start debouncing.
        
        CMP     AL, key             ;If previous key was valid, check to
        JE      CheckRptCntr        ;make sure it is the same key as last time.
        ;JNE    NextRow             ;If not, move on to the next row.
        
NextRow:        
        CALL    ResetKeypad           ;If no key is pressed, reset the keypad,
        INC     row                   ;and update the row MOD NUM_KEY_ROWS taking
        AND     row, NUM_KEY_ROWS - 1 ;advantage of the fact that NUM_KEY_ROWS
        MOV     AH, FALSE             ;is a power of 2. Then return false. This
        JMP     EndKeypadDebounce     ;lets us scan the next row on the following
                                      ;call to KeypadDebounce.
        
CheckRptCntr:
        DEC     rptCntr
        ;JZ     FastRepeat 
        JNZ     CheckDebCntr

FastRepeat:
        MOV     rptRate, FAST_RPT_RATE
        ;JMP    CheckDebCntr
        
CheckDebCntr:
        DEC     debCntr
        ;JZ     DebounceKeypad
        JNZ     WaitToDebounce

DebounceKeypad:
        MOV     BX, rptRate
        MOV     debCntr, BX
        MOV     AH, TRUE
        JMP     EndKeypadDebounce

WaitToDebounce:
        MOV     AH, FALSE
        ;JMP    EndKeypadDebounce

EndKeypadDebounce:
     
        RET

KeypadDebounce  ENDP

CODE    ENDS 




; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    
    key         DB  ?   ; The most recent key value scanned from the keypad.
                        ; Gives the 4 button combination.
    row         DB  ?   ; Current row to scan in keypad.
    debCntr     DW  ?   ; Counter of clock ticks that determines when the key
                        ; has been debounced.
    rptCntr     DW  ?   ; Counter of clock ticks that determines when the repeat
                        ; rate should speed up to FAST_RPT_RATE.
    rptRate     DW  ?   ; Time in ms to wait until registering an auto-repeated
                        ; button press.
    
DATA    ENDS



        END