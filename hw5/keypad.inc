;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 keypad.INC                                 ;
;                                Keypad Constants                            ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains constants for the keypad module.
;
; Revision History:
;	 11/5/15  David Qu			initial revision

; Keypad constants
KEYPAD_ADDRESS      EQU     80H     ; Address of keypad io ports.
NO_KEY_VALUE        EQU     0FH     ; Value representing no key pressed.
KEY_VALUE_MASK      EQU     0FH     ; Mask to get digit combination from the
                                    ; keypad output byte format.
NUM_KEY_ROWS        EQU     4       ; Number of rows in the keypad.
KEY_ROW_SHIFT       EQU     4       ; Amount to shift index to encode key row.



; Timing parameters
DEBOUNCE_TIME       EQU     10      ; Time in ms to debounce a key press to
                                    ; make sure a button was actually pressed.
REPEAT_TIME         EQU     5000    ; Time in ms until start fast repeating (5s)
DEFAULT_RPT_RATE    EQU     2000    ; slow repeat rate (0.5 Hz)
FAST_RPT_RATE       EQU     500     ; fast repeat rate (2 Hz)