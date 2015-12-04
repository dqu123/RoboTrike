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
;    11/21/15  David Qu         updated queue length.
;    12/3/15   David Qu         moved size_error_table to .asm. Added num_resend.

SWITCH_TABLE_SHIFT    EQU     1   ; Amount to shift a valid interrupt (not 
                                  ; NONE_INTERRUPT) to convert it to a
                                  ; switch table index. This takes advantage
                                  ; of the fact that all the valid interrupts
                                  ; are multiples of 2s.

TX_QUEUE_LENGTH       EQU     0   ; This is value passed to QueueInit, which
                                  ; is ultimately ignored. This is a result
                                  ; of HW3's specification of queue.asm.
TX_QUEUE_ELEMENT_SIZE EQU     1   ; byte sized elements for the txQueue since
                                  ; it holds characters.
INIT_PARITY_INDEX     EQU     0   ; initial value for parity shared variable. 
NUM_RESEND            EQU     5   ; Number of times to try resend a character 
                                  ; in SerialSendString.