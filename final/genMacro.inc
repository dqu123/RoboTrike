$NOLIST


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                 GENMACRO.INC                               ;
;                            General Purpose Macroes                         ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains generally useful macros for the 80186/80188.  The macros
; included are:
;    AUTODECSTR     - set string instructions to auto-decrement
;    AUTOINCSTR     - set string instructions to auto-increment
;    CRITICAL_END   - end of critical code section
;    CRITICAL_START - start of critical code section
;    DISABLEIRQ     - disable interrupts
;    DIV16          - divide unsigned AX by 16-bit argument
;    ENABLEIRQ      - enable interrupts
;    IDIV16         - divide signed AX by 16-bit argument
;    JF             - jump if register value is false
;    JT             - jump if register value is true
;    MULBY2         - multiply argument by 2
;    SCBW           - convert a signed byte (AL) to a signed word (AX)
;    SCWD           - convert a signed word (AX) to a signed doubleword (DX|AX)
;    UCBW           - convert an unsigned byte (AL) to an unsigned word (AX)
;    UCWD           - convert an unsigned word (AX) to an unsigned doubleword (DX|AX)
;
;
; Revision History
;    11/27/96  Glen George         initial revision
;    10/20/98  Glen George         updated comments
;    12/26/99  Glen George         updated comments
;     2/19/03  Glen George         added MULBY2 and DIV16 macros
;                                  updated comments
;    12/31/03  Glen George         added CRITICAL_START and CRITICAL_END
;                                     macros to handle critical code
;                                  updated comments
;     2/14/05  Glen George         added UCBW, SCBW, UCWD, SCWD macros for
;                                     better size conversions
;                                  added IDIV16 macro for signed division
;                                  updated comments
;    11/19/15  David Qu            imported for use in Robotrike



; local include files
;   none




; AUTOINCSTR
;
; Description:       This macro generates code to set the string instructions
;                    to do auto-increment.
;
; Operation:         The direction flag is cleared.
;
; Arguments:         None.
;
; Registers Changed: DF
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Nov. 27, 1996

%*DEFINE(AUTOINCSTR)   (
        CLD                     ;clear the direction flag, auto-inc strings
)




; AUTODECSTR
;
; Description:       This macro generates code to set the string instructions
;                    to do auto-decrement.
;
; Operation:         The direction flag is set.
;
; Arguments:         None.
;
; Registers Changed: DF
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Nov. 27, 1996

%*DEFINE(AUTODECSTR)   (
        STD                     ;set the direction flag, auto-dec strings
)




; ENABLEIRQ
;
; Description:       This macro generates code to enable interrupts.
;
; Operation:         The interrupt flag is set.
;
; Arguments:         None.
;
; Registers Changed: IF
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Nov. 27, 1996

%*DEFINE(ENABLEIRQ)   (
        STI                     ;set the interrupt flag, enabling interrupts
)




; DISABLEIRQ
;
; Description:       This macro generates code to disable interrupts.
;
; Operation:         The interrupt flag is cleared.
;
; Arguments:         None.
;
; Registers Changed: IF
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Nov. 27, 1996

%*DEFINE(DISABLEIRQ)   (
        CLI                     ;clear the interrupt flag, disabling interrupts
)




; SCBW
;
; Description:       This macro generates code to convert the signed byte
;                    value in AL to a signed word value in AX.
;
; Operation:         The CBW command is used to sign extend AL.
;
; Arguments:         None.
;
; Registers Changed: AX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 14, 2005

%*DEFINE(SCBW)   (
        CBW                     ;just do "normal" signed conversion
)




; UCBW
;
; Description:       This macro generates code to convert the unsigned byte
;                    value in AL to an unsigned word value in AX.
;
; Operation:         The AH register is cleared since there is no sign to
;                    extend into it.
;
; Arguments:         None.
;
; Registers Changed: AX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 14, 2005

%*DEFINE(UCBW)   (
        XOR     AH, AH          ;clear the upper byte, there is no sign to extend
)




; SCWD
;
; Description:       This macro generates code to convert the signed word
;                    value in AX to a signed doubleword value in DX | AX.
;
; Operation:         The CWD command is used to sign extend AX.
;
; Arguments:         None.
;
; Registers Changed: AX, DX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 14, 2005

%*DEFINE(SCWD)   (
        CWD                     ;just do "normal" signed conversion
)




; UCWD
;
; Description:       This macro generates code to convert the unsigned word
;                    value in AX to an unsigned doubleword value in DX | AX.
;
; Operation:         The DX register is cleared (there is no sign extension).
;
; Arguments:         None.
;
; Registers Changed: AX, DX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 14, 2005

%*DEFINE(UCWD)   (
        XOR     DX, DX          ;clear the upper word, there is no sign to extend
)




; MULBY2
;
; Description:       This macro generates code to multiply its argument by 2.
;
; Operation:         The argument is shifted left by 1.
;
; Arguments:         arg - value to multiply by 2.
;
; Registers Changed: flags
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 19, 2003

%*DEFINE(MULBY2(arg))   (
        SHL     %arg, 1         ;shift left to multiply by 2
)




; DIV16
;
; Description:       This macro generates code to divide AX (unsigned) by a
;                    16-bit argument.  This argument must be an addressing
;                    mode that is valid for a DIV instruction (16-bit register
;                    or memory location).  The quotient is returned in AX and
;                    the remainder is returned in DX.
;
; Operation:         DX is cleared and then a DIV instruction is executed.
;
; Arguments:         None.
;
; Registers Changed: flags, AX, DX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 19, 2003

%*DEFINE(DIV16(arg))   (
        XOR     DX, DX                  ;clear DX for DIV instruction
        DIV     %arg                    ;do division (DX|AX / arg)
)




; IDIV16
;
; Description:       This macro generates code to divide AX (signed) by a
;                    16-bit argument.  This argument must be an addressing
;                    mode that is valid for an IDIV instruction (16-bit
;                    register or memory location).  The quotient is returned
;                    in AX and the remainder is returned in DX.
;
; Operation:         AX is signed extended into DX and then an IDIV
;                    instruction is executed.
;
; Arguments:         None.
;
; Registers Changed: flags, AX, DX
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 14, 2005

%*DEFINE(IDIV16(arg))   (
        CWD                             ;signed extend AX into DX for division
        IDIV    %arg                    ;do division (DX|AX / arg)
)




; JF
;
; Description:       This macro jumps to the specified address if the given
;                    register is false (zero).
;
; Operation:         The register is TESTed for zero and the passed label is
;                    jumped to if it is.
;
; Arguments:         reg  - register to test for true/false, cannot be a
;                           segment register.
;                    dest - destination to jump to if reg is false.
;
; Registers Changed: flags
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 19, 2005

%*DEFINE(JF(reg, dest))   (
        TEST    %reg, %reg      ;test the register for zero/non-zero
        JZ      %dest           ;jump to destination if false (zero)
)




; JT
;
; Description:       This macro jumps to the specified address if the given
;                    register is true (non-zero).
;
; Operation:         The register is TESTed for non-zero and the passed label
;                    is jumped to if it is.
;
; Arguments:         reg  - register to test for true/false, cannot be a
;                           segment register.
;                    dest - destination to jump to if reg is true.
;
; Registers Changed: flags
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Feb. 19, 2005

%*DEFINE(JT(reg, dest))   (
        TEST    %reg, %reg      ;test the register for zero/non-zero
        JNZ     %dest           ;jump to destination if true (non-zero)
)




; CRITICAL_START
;
; Description:       This macro generates the necessary code to begin a
;                    critical section of code.  Critical code must disable
;                    interrupts, so this macro saves the current interrupt
;                    status and then turns off interrupts.  This macro MUST
;                    be paired with the CRITICAL_END macro.
;
; Operation:         The flags are saved on the stack and interrupts are
;                    disabled.
;
; Arguments:         None.
;
; Registers Changed: IF
; Stack Depth:       1 word
;
; Author:            Glen George
; Last Modified:     Dec. 31, 2003

%*DEFINE(CRITICAL_START)   (
        PUSHF                           ;save flags
        CLI                             ;disable the interrupts
)




; CRITICAL_END
;
; Description:       This macro generates the necessary code to end a critical
;                    section of code.  Critical code must disable interrupts
;                    while it is executing, so this macro restores the
;                    previously saved interrupt status, possibly reenabling
;                    the interrupts.  This macro MUST be paired with the
;                    CRITICAL_START macro.
;
; Operation:         The flags previously saved on the stack are restored.
;
; Arguments:         None.
;
; Registers Changed: flags
; Stack Depth:       -1 word
;
; Author:            Glen George
; Last Modified:     Dec. 31, 2003

%*DEFINE(CRITICAL_END)   (
        POPF                            ;restore flags (interrupt flag in particular)
)



$LIST
