$NOLIST
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  MACRO.INC                                 ;
;                               Macro Extra Credit                           ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains generally useful macros for the 80186/80188.  The macros
; included are:
;    CLR(reg)           - clears the register reg (sets to zero)
;    SETBIT(reg,bit)    - sets bit #bit in register reg (not a segment reg)
;    CLRBIT(reg,bit)    - clears bit #bit in register reg (not a segment reg)
;    COMBIT(reg,bit)    - complements bit #bit in register reg (not seg reg)
;    TESTBIT(reg,bit)   - sets the zero flag based on bit #bit in reg. (not seg reg)
;    XLATW              - Translate the 16-bit index in AX into another 16-bit
;                         value using the table at BX.
;    READPCB(addr)      - Read the PCB register at address addr and return in AX.
;    WRITEPCB(addr,val) - Write the 16-bit value to the PCB register at address addr.
;
; Revision History
;    11/13/15  David Qu         initial revision
;    11/18/15  David Qu         added macros.


; CLR
;
; Description:       This macro clears a register
; Operation:         XORs the register with itself.
; Arguments:         reg - register to clear (not a segment register)
; Registers Changed: reg.
; 
; Author:            David Qu
; Last Modified:     11/13/2015
%*DEFINE(CLR(reg)) (
    XOR     %reg, %reg
)


; SETBIT
;
; Description:       This macro sets bit #bit in reg. bit must be an integer
;                    between 0 and 15 inclusive.
; Operation:         ORs in the desired bit into the register.
; Arguments:         reg - register to set (not a segment register)
;                    bit - The number of the bit to change from 0 to 15
;                          where 0 is the least significant bit in a word.
; Registers Changed: Reg.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(SETBIT(reg, bit)) (
    OR     %reg, 1 SHL %bit
)

; CLRBIT
;
; Description:       This macro clears bit #bit in reg. bit must be an integer
;                    between 0 and 15 inclusive.
; Operation:         ANDs in the bitwise NOT of the desired bit into the register.
; Arguments:         reg - register to set (not a segment register).
;                    bit - The number of the bit to change from 0 to 15
;                          where 0 is the least significant bit in a word.
; Registers Changed: reg.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(CLRBIT(reg, bit)) (
    AND     %reg, NOT 1 SHL %bit
)

; COMBIT
;
; Description:       This macro compliments bit #bit in reg. bit must be an integer
;                    between 0 and 15 inclusive.
; Operation:         XORs in the desired bit into the register.
; Arguments:         reg - register to set (not a segment register).
;                    bit - The number of the bit to change from 0 to 15
;                          where 0 is the least significant bit in a word.
; Registers Changed: reg.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(COMBIT(reg, bit)) (
    XOR     %reg, 1 SHL %bit
)

; TESTBIT
;
; Description:       This macro sets the zero flag based on bit #bit in reg. 
;                    bit must be an integer between 0 and 15 inclusive.
; Operation:         TESTs the bitwise the desired bit in the register.
; Arguments:         reg - register to set (not a segment register).
;                    bit - The number of the bit to change from 0 to 15
;                          where 0 is the least significant bit in a word.
; Registers Changed: reg.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(TESTBIT(reg, bit)) (
    TEST     %reg, 1 SHL %bit
)

; XLATW
;
; Description:       This macro translates the 16-bit value in AX to another 16
;                    bit value using the table pointed to by BX. Note that this
;                    calculation assumes
; Operation:         Doubles AX to convert from words to bytes, and then moves
;                    the result to SI and uses SI to access BX.
; Arguments:         None.
; Registers Changed: AX, SI.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(XLATW) (
    SHL     AX, 1
    MOV     SI, AX
    MOV     AX, DS:[BX + SI]
)

; READPCB
;
; Description:       This macro reads the PCB register at address addr and
;                    returns the value in AX.
; Operation:         Sets DX to the address, and INs the value into AX.
; Arguments:         addr - address of register 
; Registers Changed: AX, DX.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(READPCB(addr)) (
    MOV     DX, %addr
    IN      AX, DX
)

; WRITEPCB
;
; Description:       This macro writes the value val to the PCB register at 
;                    address addr.
; Operation:         Sets DX to the address, and OUTs the val from AX.
; Arguments:         addr - address of register 
; Registers Changed: AX, DX.
; 
; Author:            David Qu
; Last Modified:     11/18/2015
%*DEFINE(WRITEPCB(addr, val)) (
    MOV     DX, %addr
    MOV     AX, %val
    OUT     DX, AX
)
 