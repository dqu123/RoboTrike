;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  serial.inc                                ;
;                             RoboTrike Serial Module                        ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the RoboTrike serial module, which 
; contains the functions to transmit and receive data from the serial 
; device. To use this module, the serial device must first be initialized using 
; the initSeri module. These functions are used both by the motor unit and the 
; remote unit of the RoboTrike to communicate between the two systems. They
; implement a Event-Driven communication protocol with a transmission queue
; and an event queue for each side of the link.
;
; Revision History:
;	 11/19/15  David Qu			initial revision

SWITCH_TABLE_SHIFT    EQU     1   ; Amount to shift a valid interrupt (not 
                                  ; NONE_INTERRUPT) to convert it to a
                                  ; switch table index. This takes advantage
                                  ; of the fact that all the valid interrupts
                                  ; are multiples of 2s.

TX_QUEUE_LENGTH       EQU     512 ; This is the maximum length of the txQueue.
TX_QUEUE_ELEMENT_SIZE EQU     1   ; byte sized elements for the txQueue since
                                  ; it holds characters.
SIZE_ERROR_TABLE      EQU     4   ; Number of error bits in the LSR.
 