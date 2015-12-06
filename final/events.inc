;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 events.INC                                 ;
;                             Event Type Constants                           ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains Event Type constants for encoding and parsing events.
;
; Revision History:
;	 11/5/15  David Qu			initial revision
;    11/19/15 David Qu          changed to 0 index, and added serial events
;    11/30/15 David Qu          revised event numbering 
;    12/4/15  David Qu          removed parser error event
;    12/5/15  David Qu			added comments.

; Remote Event constants
; Note that these constants MUST match the tables in remoteMn.asm and
; motorMn.asm which determine which function to call to handle
; each event type.
KEYPRESS_EVENT      EQU     0       ; Value for a keypress event. 
SERIAL_ERROR_EVENT  EQU     2       ; Value for a serial error event.
SERIAL_DATA_EVENT   EQU     4       ; Value for a serial data event.
