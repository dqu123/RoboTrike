;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  eoi.INC                                   ;
;                                EOI Constants                               ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains EOI constants for writing event handlers.
;
; Revision History:
;	 11/5/15  David Qu			initial revision

INTCtrlrEOI     EQU     0FF22H  ;address of interrupt controller EOI register
TimerEOI        EQU     00008H  ;Timer EOI command (same for all timers)
INT2EOI         EQU     0000EH  ; Int2EOI
NonSpecEOI      EQU     08000H  ;Non-specific EOI command
