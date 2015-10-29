;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  EHDEMO.INC                                ;
;                              Event Handler Demo                            ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the Event Handler Demonstration
; program (EHDEMO.ASM).
;
; Revision History:
;    11/11/92  Glen George      initial revision (originally part of
;                                  ISRDEMO.ASM)
;    10/27/93  Glen George      split definitions into own file (EHDEMO.INC)
;                               updated/corrected comments
;    10/24/94  Glen George      added Revision History section
;                               updated comments
;    10/25/95  Glen George      updated comments
;    10/28/96  Glen George      added COUNTS_PER_MS and MS_PER_SEG constants
;                               updated comments
;    10/28/97  Glen George      added RESERVED_VECS constant
;                               changed PACSVal and MPCSVal to not set
;                                  reserved bits and set 3 wait states
;                               updated comments
;    12/26/99  Glen George      updated comments
;     2/13/01  Glen George      changed MPCSVAL to a legal value
;     2/03/03  Glen George      changed NO_DIGITS to NUM_DIGITS
;                               changed Timer0EOI to TimerEOI
;                               added NUM_IRQ_VECTORS
;                               updated comments
;     1/28/04  Glen George      updated comments
;     2/05/05  Glen George      added FIRST_RESERVED_VEC and LAST_RESERVED_VEC
;                                  and removed RESERVED_VECS for new version
;                                  of ClrIRQVectors
;                               updated comments



; Timer Definitions

; Addresses
Tmr0Ctrl        EQU     0FF56H          ;address of Timer 0 Control Register
Tmr0MaxCntA     EQU     0FF52H          ;address of Timer 0 Max Count A Register
Tmr0Count       EQU     0FF50H          ;address of Timer 0 Count Register
Tmr2Ctrl        EQU     0FF66H          ;address of Timer 2 Control Register
Tmr2MaxCnt      EQU     0FF62H          ;address of Timer 2 Max Count A Register
Tmr2Count       EQU     0FF60H          ;address of Timer 2 Count Register

; Control Register Values
Tmr0CtrlVal     EQU     0E009H          ;value to write to Timer 0 Control Register
                                        ;1---------------  enable timer
                                        ;-1--------------  write to control
                                        ;--1-------------  enable interrupts
                                        ;----000000------  reserved
                                        ;---0------0-----  read only
                                        ;-----------0----  TMRIN0 is an enable
                                        ;------------10--  count timer 2 outs
                                        ;--------------0-  single counter mode
                                        ;---------------1  continuous mode
Tmr2CtrlVal     EQU     0C001H          ;value to write to Timer 2 Control Register
                                        ;1---------------  enable timer
                                        ;-1--------------  write to control
                                        ;--0-------------  no interrupts
                                        ;----000000-0000-  reserved
                                        ;---0------0-----  read only
                                        ;---------------1  continuous mode

; Interrupt Vectors
Tmr0Vec         EQU     8               ;interrupt vector for Timer 0


; Interrupt Controller Definitions

; Addresses
INTCtrlrCtrl    EQU     0FF32H          ;address of interrupt controller for timer
INTCtrlrEOI     EQU     0FF22H          ;address of interrupt controller EOI register

; Register Values
INTCtrlrCVal    EQU     00001H          ;set priority for timers to 1 and enable
                                        ;000000000000----  reserved
                                        ;------------0---  enable timer interrupt
                                        ;-------------001  timer priority
TimerEOI        EQU     00008H          ;Timer EOI command (same for all timers)
NonSpecEOI      EQU     08000H          ;Non-specific EOI command


; Chip Select Unit Definitions

; Addresses
PACSreg         EQU     0FFA4H          ;address of PACS register
MPCSreg         EQU     0FFA8H          ;address of MPCS register

; Control Register Values
PACSval         EQU     00003H          ;PCS base at 0, 3 wait states
                                        ;0000000000------  starts at address 0
                                        ;----------000---  reserved
                                        ;-------------0--  wait for RDY inputs
                                        ;--------------11  3 wait states
MPCSval         EQU     00183H          ;PCS in I/O space, use PCS5/6, 3 wait states
                                        ;0---------000---  reserved
                                        ;-0000001--------  MCS is 8KB
                                        ;--------1-------  output PCS5/PCS6
                                        ;---------0------  PCS in I/O space
                                        ;-------------0--  wait for RDY inputs
                                        ;--------------11  3 wait states



; Timing Definitions

COUNTS_PER_MS   EQU     2304            ;number of timer counts per 1 ms (assumes 18.432 MHz clock)
MS_PER_SEG      EQU     200             ;number of ms for each segment



; General Definitions

FIRST_RESERVED_VEC	EQU	1	;reserve vectors 1-3
LAST_RESERVED_VEC	EQU	3
NUM_IRQ_VECTORS         EQU     256     ;number of interrupt vectors

LEDDisplay      EQU     0000H           ;display address

NUM_DIGITS      EQU     8               ;number of digits in the display
