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
INT3Ctrl        EQU     PeriphBase + 03EH       ;INT3 Control Register
INT2Ctrl        EQU     PeriphBase + 03CH       ;INT2 Control Register
INT1Ctrl        EQU     PeriphBase + 03AH       ;INT1 Control Register
INT0Ctrl        EQU     PeriphBase + 038H       ;INT0 Control Register
DMA0Ctrl        EQU     PeriphBase + 034H       ;DMA0 Control Register
DMA1Ctrl        EQU     PeriphBase + 038H       ;INT0 Control Register
TimerCtrl       EQU     PeriphBase + 038H       ;INT0 Control Register
INTStatus       EQU     PeriphBase + 038H       ;INT0 Control Register
INTRequest      EQU     PeriphBase + 038H       ;INT0 Control Register
InService       EQU     PeriphBase + 038H       ;INT0 Control Register
PriorityMask    EQU     PeriphBase + 038H       ;INT0 Control Register
INTMask         EQU     PeriphBase + 038H       ;INT0 Control Register
PollStatus      EQU     PeriphBase + 038H       ;INT0 Control Register
INT0Ctrl        EQU     PeriphBase + 038H       ;INT0 Control Register
INT0Ctrl        EQU     PeriphBase + 038H       ;INT0 Control Register


;Control Register Definitions
;  each set of control register definitions includes a mask for masking the
;  high 16-bits of the starting physical address (starting segment number)
;  and a shift amount for fitting that value into the control register


;Upper Chip Select Control Register (UCSCtrl)

UCSBaseMask     EQU     0011111111000000B       ;mask for UCS base address segment
UCSBaseShift    EQU     0                       ;amount to shift UCS base address segment

UCSSize1K	EQU     0011111111000000B	;UCS is 1K   (FFC00 - FFFFF)
UCSSize2K	EQU     0011111110000000B	;UCS is 2K   (FF800 - FFFFF)
UCSSize4K	EQU     0011111100000000B	;UCS is 4K   (FF000 - FFFFF)
UCSSize8K	EQU     0011111000000000B	;UCS is 8K   (FE000 - FFFFF)
UCSSize16K	EQU     0011110000000000B	;UCS is 16K  (FC000 - FFFFF)
UCSSize32K	EQU     0011100000000000B	;UCS is 32K  (F8000 - FFFFF)
UCSSize64K	EQU     0011000000000000B	;UCS is 64K  (F0000 - FFFFF)
UCSSize128K	EQU     0010000000000000B	;UCS is 128K (E0000 - FFFFF)
UCSSize256K	EQU     0000000000000000B	;UCS is 256K (C0000 - FFFFF)


