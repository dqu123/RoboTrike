;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 motorTmr.INC                               ;
;                                Timer Constants                             ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains constants for the timers.
;
; Revision History:
;	 11/12/15  David Qu			initial revision

; Addresses
PeriphBase  EQU     0FF00H            ;address of peripheral control block
Tmr0Ctrl    EQU     PeriphBase + 056H ;address of Timer 0 Control Register
Tmr0MaxCntA EQU     PeriphBase + 052H ;address of Timer 0 Max Count A Register
Tmr0Count   EQU     PeriphBase + 050H ;address of Timer 0 Count Register

; Control Register Values
Tmr0CtrlVal     EQU     0E001H          ;value to write to Timer 0 Control Register
                                        ;1---------------  enable timer
                                        ;-1--------------  write to control
                                        ;--1-------------  enable interrupts
                                        ;----000000------  reserved
                                        ;---0------0-----  read only
                                        ;-----------0----  TMRIN0 is an enable
                                        ;------------00--  count CPU clocks
                                        ;--------------0-  single counter mode
                                        ;---------------1  continuous mode

; Interrupt Controller Definitions

; Addresses
INTCtrlrCtrl    EQU     PeriphBase + 032H ;address of interrupt controller for timer

; Register Values
INTCtrlrCVal    EQU     00001H          ;set priority for timers to 1 and enable
                                        ;000000000000----  reserved
                                        ;------------0---  enable timer interrupt
                                        ;-------------001  timer priority                                        
                                        
; Interrupt Vectors
Tmr0Vec         EQU     8               ;interrupt vector for Timer 0
Tmr0VecOffset   EQU     4 * Tmr0Vec     ;location for EH offset in IVT.
Tmr0VecSeg      EQU     4 * Tmr0Vec + 2 ;location for EH seg in IVT.

; Timing Definitions
COUNTS_PER_MS    EQU    2304	;number of timer counts per 1 ms (assumes 18.432 MHz clock)
COUNTS_PER_MOTOR EQU    600     ; = 2304 (COUNTS_PER_MS) kHz / desired rate. 
                                ; desired rate = 3840 Hz = 30 Hz * 128 (MAX_SPEED_COUNT)