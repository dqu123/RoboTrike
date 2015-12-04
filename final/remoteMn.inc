;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  remoteMn.inc                              ;
;                             RoboTrike Remote Main Loop                     ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the RoboTrike Remote Main Loop, which
; processes the remote system events, which come from the keypad, display, and
; serial.
;
; Revision History:
;	 12/3/15  David Qu			initial revision

; Special keys 
DISPLAY_SPEED_KEY       EQU     1DH     ; Keycode for display speed key
DISPLAY_DIRECTION_KEY   EQU     1BH     ; Keycode for display direction key
DISPLAY_ERROR_KEY       EQU     17H     ; Keycode for display error key

; Remote main states
SPEED_STATE             EQU     0       ; Reading speed.
DIRECTION_STATE         EQU     1       ; Reading direction.
ERROR_STATE             EQU     2       ; Reading error.
START_STATE             EQU     3       ; Initial state.