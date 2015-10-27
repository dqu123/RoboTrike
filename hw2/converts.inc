;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   CONVERTS.INC                             ;
;                            String Conversion Constants                     ;
;                                 RoboTrike (80188)                          ;
;                                   Include File                             ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the conversion functions for the 80188
; version of the RoboTrike.
;
; Revision History:
; 	10/15/15 David Qu	initial revision
;   10/16/16 David Qu   removed unused constants

; Hardware specific values.
POWER_TEN       EQU	    10000    ; Largest power of ten.
NUM_HEX_DIGITS 	EQU     4        ; Number of hexadecimal digits to process.

; ASCII values.
ASCII_NULL	    EQU     0	     ; Decimal value of ASCII null character.