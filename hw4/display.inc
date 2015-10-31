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

; Display constants
MAX_STRING_SIZE EQU     7       ; Maximum number of bytes in a string
								; written by dec2string / hex2string.
BUFFER_SIZE		EQU     8      ; Maximum size of the display buffer. Must be
								; a power of 2 to do MOD via AND BUFFER_SIZE - 1.
LEDDisplay      EQU     0000H   ;display address
SEG14_OFFSET	EQU		8		; Offset of byte that controls the last 7 segments
								; of a 14 segment display.
DEFAULT_ON_TIME		EQU		10	; Default on time per cycle in ms
DEFAULT_OFF_TIME	EQU		0	; Default off time per cycle in ms
NUM_DIGITS			EQU		8   ; Number of digits in the display. Code assumes
								; this is a power of 2 to simplify modular
								; arithmetic.
MS_PER_SCROLL		EQU		100