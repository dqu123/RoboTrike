;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                 DISPLAY.INC                                  ;
;                              Display Functions                               ;
;                               EE51 RoboTrike                                 ;
;                               Include File                                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; This file contains the definitions for the display functions for RoboTrike.
;
; Revision History:
;		10/29/15  David Qu 		initial revision
;		10/30/15  David Qu		updated comments.
;		10/31/15  David Qu		added scrolling constants.

; Display constants
MAX_STRING_SIZE EQU     7       ; Maximum number of bytes in a string
								; written by dec2string / hex2string.
BUFFER_SIZE		EQU     16      ; Maximum size of the display buffer in words. Must be
								; a power of 2 to do MOD via AND BUFFER_SIZE - 1.
END_OF_BUFFER	EQU		2 * BUFFER_SIZE - 2 ; End index of buffer in bytes.
BYTES_PER_DIGIT		EQU		2	; Number of bytes per bit pattern of one display digit.
DIGIT_SHIFT			EQU		1   ; log_2(BYTES_PER_DIGIT)
BLANK_SEG_PATTERN	EQU		0	; Bit pattern for a blank digit.
LEDDisplay      EQU     0000H   ; display port start address.
SEG14_OFFSET	EQU		8		; Offset of byte that controls the last 7 segments
								; of a 14 segment display.
DEFAULT_ON_TIME		EQU		128	; Default on time per cycle in timer counts.
DEFAULT_OFF_TIME	EQU		0	; Default off time per cycle in timer counts.
NUM_DIGITS			EQU		8   ; Number of digits in the display. Code assumes
								; this is a power of 2 to simplify modular
								; arithmetic.
COUNTS_PER_SCROLL	EQU		32  ; Default number of timer counts before incrementing
								; the scroll index. Code assumes this is a power
								; of 2 to simplify modular arithmetic.
