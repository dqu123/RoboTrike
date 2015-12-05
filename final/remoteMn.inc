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
;    12/5/15  David Qu			removed unneeded constants.

; Remote main states
; By default, the state is ERROR_STATE, but is determined as characters
; are sent through serial. Note that these constants MUST correspond to the
; order of the display string buffers in the remoteMn.asm DATA segment because
; they are used to determine which buffer to write to.
SPEED_STATE             EQU     0       ; Reading speed status.
DIRECTION_STATE         EQU     1       ; Reading direction status.
LASER_STATE				EQU 	2		; Reading laser status.
ERROR_STATE             EQU     3       ; Reading error.
										