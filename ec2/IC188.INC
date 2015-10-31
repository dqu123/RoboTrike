;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  IC188.INC                                 ;
;                        80188 Interrupt Controller Definitions              ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the 80188 Interrupt Controller.
;
;
; Revision History:
;    10/29/15  David Qu       initial revision


;Addresses
;Note these variable names come from the names used in Table 4-1 of
;the 80C186/C188, 80C186XL/C188XL User's Manual page 4-3.

I3CON           EQU     PeriphBase + 03EH       ;INT3 Control Register
I2CON           EQU     PeriphBase + 03CH       ;INT2 Control Register
I1CON           EQU     PeriphBase + 03AH       ;INT1 Control Register
I0CON           EQU     PeriphBase + 038H       ;INT0 Control Register
DMA0CON         EQU     PeriphBase + 034H       ;DMA0 Control Register
DMA1CON         EQU     PeriphBase + 036H       ;DMA1 Control Register
TCUCON          EQU     PeriphBase + 032H       ;Timer Control Register
INSTS           EQU     PeriphBase + 030H       ;Interrupt Status Register
REQST           EQU     PeriphBase + 02EH       ;Interrupt Request Register
INSERV          EQU     PeriphBase + 02CH       ;In-Service Register
PRIMSK          EQU     PeriphBase + 02AH       ;Priority Mask Register
IMASK           EQU     PeriphBase + 028H       ;Interrupt Mask Register
POLLSTS         EQU     PeriphBase + 026H       ;Poll Status Register
POLL            EQU     PeriphBase + 024H       ;Poll Register
EOI             EQU     PeriphBase + 022H       ;EOI Register


;Control Register Definitions
;  	each set of control register definitions includes various constant bit
;  	patterns that have specific meanings. These constants come from the tables
;  	of interrupt control register groups starting at page 8-13 in the manual. 
;   Registers that share bit patterns with a previous register group have the
;	repeated bit patterns commented out. All single bit patterns end with _BIT
;	and all multi-bit patterns end with _BIT_MASK, for the mas k

;Register Name: Interrupt Control Register (internal sources)
;Register Mnemonic: TCUCON, DMA0CON, DMA1CON
;Register Function: Control register for the internal interrupt sources
MSK_BIT			EQU		0000000000001000B 	; Turns off the interrupt.
PM_BIT_MASK		EQU		0000000000000111B	; Used to get the interrupt priority (from 0 to 7).
PRIORITY_0		EQU		0000000000000000B
PRIORITY_1		EQU		1

;Register Name: Interrupt Control Register (non-cascadable pins)
;Register Mnemonic: I2CON, I3CON
;Register Function: Control register for the non-cascadable external internal
;	interrupt pins.
LVL_BIT			EQU		0000000000010000B	; Sets level triggering instead of edge triggering.
; PM_BIT_MASK


