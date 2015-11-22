;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                 QUEUE.INC                                    ;
;                              Queue Functions                                 ;
;                               EE51 RoboTrike                                 ;
;                               Include File                                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; This file contains the definitions for the queue functions for RoboTrike.
;
; Revision History:
;		10/22/15  David Qu 		initial revision
;       10/23/15  David Qu      added bytes_per_word, word_shift_amt

; Queue definitions

; Queue constants
BYTES_PER_WORD  EQU     2           ; Number of bytes per word.
WORD_SHIFT_AMT  EQU     1           ; Factor to shift by to convert from number
                                    ; of words to number of bytes.
ARRAY_SIZE		EQU		512 		; Maximum size of queue in bytes, reserving 
                                    ; 1 element size (byte or word) for a blank
									; space. Note that this number must be a
									; power of 2 because several mod operations
									; were implemented using AND bit operations
									; that only work for powers of 2.

; Queue structure
queueSTRUC		STRUC 			; structure containing queue internals.
	head		DW	?			; index of first element in the queue in number
                                ; of bytes.
	tail 		DW	?			; index of first open position in queue in 
                                ; number of bytes.
	e_size 	  	DW	?			; element size in bytes.
	array		DB	ARRAY_SIZE	DUP (?) ; array of memory for the queue.
queueSTRUC		ENDS