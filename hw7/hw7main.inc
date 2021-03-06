;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 hw7main.INC                                ;
;                             Main file Constants                            ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains constants for the hw7main test program.
;
; Revision History:
;    11/21/15 David Qu          initial revision

; Event constants
TEST_BAUD_RATE      EQU     19200     ; Value to test setSerialBaudRate.
TOGGLE_PARITY_NUM   EQU     7         ; Times to toggle parity.
                                      ; 0 MOD 5 = NO_PARITY
                                      ; 1 MOD 5 = EVEN_PARITY
                                      ; 2 MOD 5 = ODD_PARITY
                                      ; 3 MOD 5 = EVEN_STICK_PARITY
                                      ; 4 MOD 5 = ODD_STICK_PARITY
                                      ; Must be >= 1 since the loop runs
                                      ; at least one time.