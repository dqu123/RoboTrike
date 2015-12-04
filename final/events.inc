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

; Remote Event constants
KEYPRESS_EVENT      EQU     0       ; Value for a keypress event. 
SERIAL_ERROR_EVENT  EQU     2       ; Value for a serial error event.
SERIAL_DATA_EVENT   EQU     4       ; Value for a serial data event.
PARSER_ERROR_EVENT  EQU     6       ; Value for a parser error event.
