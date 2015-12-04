        NAME    CONVERTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   CONVERTS                                 ;
;                             Conversion Functions                           ;
;                                   EE/CS 51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This module contains conversion functions from integer values to string
; representations.
;
; Public functions:
; Dec2String          - converts a signed word to a decimal string representation
; UnsignedDec2String  - converts an unsigned word to a decimal string representation
; Hex2String          - converts an unsigned word to a hex string representation
;
; Local functions: 
; None. 
;
; Revision History:
;     1/26/06  Glen George      initial revision
;     10/12/15 David Qu         first draft
;     10/15/15 David Qu         cleaned up code
;     10/16/15 David Qu         fixed major bug (now using CL instead of CX
;                               to add characters).
;     11/30/15 David Qu         added UnsignedDec2String.

; local include files
$INCLUDE(CONVERTS.INC)


CGROUP  GROUP   CODE


CODE	SEGMENT PUBLIC 'CODE'

        ASSUME  CS:CGROUP




; Dec2String
;
; Description: Converts the 16-bit signed number in AX to a zero-padded string 
; containing its decimal representation. This includes a leading '-' character 
; for negative values. Stores the string at the passed address DS:SI starting 
; with the leftmost digits. The string will take up 6 bytes for nonnegative 
; values, and 7 bytes for negatives values. (5 bytes for digits plus one 
; for NULL).
;
; Operation: First, check if the number is negative. If it is, add a
; negative sign, and then negate it. Compute one base 10 digit at a time,
; starting with 10,000 by unsigned division. Add each digit to the next 
; available position in the string. End when all powers of ten are 
; processed, adding a NULL character to terminate the string.
;
; Arguments: AX - 16 bit signed integer
;            SI - address of character array to store string
; Return Value: None. (6-7 byte string will be added to address SI).
;
; Local Variables: length (BX) - Current size of string. Used to access string.
;                  pwr10 (CX) - Power of 10 being processed. Initially 10000.
;                  digit (AX) - Integer value of base 10 digit being processed.
;                  temp (DX) - Temporary variables that must be in registers
;                              (For example for indirect access).
; Shared Variables: None. 
; Global Variables: None.
;
; Input:	None.
; Output:	None.
;
; Error Handling: None.
;
; Algorithms: Base conversion from binary value to decimal digits.
;     Done by division modulo powers of 10.
; Data Structures: 6-7 byte character array. Linear left to right format.
;
; Known Bugs: None.
; Limitations: None.
;
; Registers Changed: flags, AX, BX, CX, DX.
; Stack Depth: 0 words.
;
; Author: David Qu
; Last Modified: 10/16/15

Dec2String      PROC        NEAR
                PUBLIC      Dec2String
Dec2StringInit:
	MOV	CX, POWER_TEN         ; Initialize pwr10 = 10000.
	XOR	BX, BX                ; Initialize length = 0.
	CMP	AX, 0                 ; Check if n < 0.
 	JGE	Dec2StringLoop        ; If n >= 0, skip negative case logic.
    ;JL NegativeValue         ; Otherwise handle negative number.

NegativeValue:                
	MOV	DL, '-'               ; Store '-' ASCII in BX to add to string.
	MOV	[SI + BX], DL         ; Add '-' to string.
	INC	BX                    ; Update position in string.
	NEG	AX                    ; Convert to positive number.

Dec2StringLoop:               ; DO WHILE LOOP:
	XOR	DX, DX		          ; Clear out DX for DIV.
	DIV	CX                    ; Divide by pwr10 to get next digit.
	PUSH DX		              ; Save remainder on stack.
	ADD	AL, '0'               ; Convert to ASCII digit.
	MOV	[SI + BX], AL         ; Add ASCII form of digit to string.
	INC	BX		              ; Increased length of string.
	MOV AX, CX                ; Move pwr10 (CX) to AX to divide by 10.
	MOV CX, 10                ; Prepare to divide by 10.
	XOR	DX, DX	              ; Clear out DX for DIV.
	DIV	CX 	         	      ; Get next pwr10 by dividing by 10.
	MOV	CX, AX	              ; Store new pwr10 in CX. 
	POP	AX	                  ; Retrieve remainder from stack as new n.
	;JMP EndDec2StringLoop    ; Check loop condition.

EndDec2StringLoop:
	CMP	CX, 0                 ; Check if pwr10 > 0
	;JLE EndDec2String        ; If not, have done all digits, done. 
	JG	Dec2StringLoop        ; else get the next digit. 
                              ; END DO WHILE.

EndDec2String:
	MOV	DL, ASCII_NULL        ; Prepare to add NULL character.
	MOV	[SI + BX], DL         ; NULL terminate string.
	RET

Dec2String	ENDP

; UnsignedDec2String
;
; Description: Converts the 16-bit unsigned number in AX to a zero-padded string 
; containing its decimal representation. Stores the string at the passed address 
; DS:SI starting with the leftmost digits. The string will take up 6. 
; (5 bytes for digits plus one for NULL).
;
; Operation: Compute one base 10 digit at a time,
; starting with 10,000 by unsigned division. Add each digit to the next 
; available position in the string. End when all powers of ten are 
; processed, adding a NULL character to terminate the string.
;
; Arguments: AX - 16 bit signed integer
;            SI - address of character array to store string
; Return Value: None. (6-7 byte string will be added to address SI).
;
; Local Variables: length (BX) - Current size of string. Used to access string.
;                  pwr10 (CX) - Power of 10 being processed. Initially 10000.
;                  digit (AX) - Integer value of base 10 digit being processed.
;                  temp (DX) - Temporary variables that must be in registers
;                              (For example for indirect access).
; Shared Variables: None. 
; Global Variables: None.
;
; Input:	None.
; Output:	None.
;
; Error Handling: None.
;
; Algorithms: Base conversion from binary value to decimal digits.
;     Done by division modulo powers of 10.
; Data Structures: 6 byte character array. Linear left to right format.
;
; Known Bugs: None.
; Limitations: None.
;
; Registers Changed: flags, AX, BX, CX, DX.
; Stack Depth: 0 words.
;
; Author: David Qu
; Last Modified: 11/30/15

UnsignedDec2String  PROC        NEAR
                    PUBLIC      UnsignedDec2String
UDec2StringInit:
	MOV	CX, POWER_TEN         ; Initialize pwr10 = 10000.
	XOR	BX, BX                ; Initialize length = 0.

UDec2StringLoop:              ; DO WHILE LOOP:
	XOR	DX, DX		          ; Clear out DX for DIV.
	DIV	CX                    ; Divide by pwr10 to get next digit.
	PUSH DX		              ; Save remainder on stack.
	ADD	AL, '0'               ; Convert to ASCII digit.
	MOV	[SI + BX], AL         ; Add ASCII form of digit to string.
	INC	BX		              ; Increased length of string.
	MOV AX, CX                ; Move pwr10 (CX) to AX to divide by 10.
	MOV CX, 10                ; Prepare to divide by 10.
	XOR	DX, DX	              ; Clear out DX for DIV.
	DIV	CX 	         	      ; Get next pwr10 by dividing by 10.
	MOV	CX, AX	              ; Store new pwr10 in CX. 
	POP	AX	                  ; Retrieve remainder from stack as new n.
	;JMP EndUDec2StringLoop   ; Check loop condition.

EndUDec2StringLoop:
	CMP	CX, 0                 ; Check if pwr10 > 0
	;JLE EndUDec2String       ; If not, have done all digits, done. 
	JG	UDec2StringLoop       ; else get the next digit. 
                              ; END DO WHILE.

EndUDec2String:
	MOV	DL, ASCII_NULL        ; Prepare to add NULL character.
	MOV	[SI + BX], DL         ; NULL terminate string.
	RET

UnsignedDec2String	ENDP



; Hex2String
;
; Description: Converts the 16-bit unsigned value AX to a string containing 
; its decimal representation. Stores the string at the passed address DS:SI
; as a 5 byte null-terminated character array.
;
; Operation: Process four bits at a time, starting from the top four bits.
; Convert from 0-15 integer values to the appropriate ASCII characters
; for hexadecimal digits. Always generates a 4 digit hexadecimal number
; since it converts 16 bit numbers.
;
; Arguments: AX - 16 bit unsigned integer
;            SI - Address of character array to store string.
; Return Value: None. (Adds 5 byte string to address at SI).
;
; Local Variables: temp (CX) - Temporary values that must be in registers.
;                              (e.g. adding characters via indirect access).
;                  i (BX) - Loop index.
;                  digit (CX) - Integer value of digit being processed.
; Shared Variables: None.
; Global Variables: None.
;
; Input: None.
; Output: None.
;
; Error Handling: None.
;
; Algorithms: Base conversion by shifting by multiples of 4 
;             to divide by powers of 16. 
; Data Structures: 5 byte null-terminated character array.
;
; Known Bugs: None.
; Limitations: None. 
;
; Registers Changed: flags, AX, BX, CX. 
; Stack Depth: 0 words.
;
; Author: David Qu
; Last Modified: 10/15/15

Hex2String      PROC        NEAR
                PUBLIC      Hex2String
Hex2StringInit:
	XOR	BX, BX                     ; Set i = 0.

Hex2StringLoop:                    ; DO WHILE LOOP:
	MOV	CX, AX                     ; Move n to CX for processing.
	SHR	CX, 4 * NUM_HEX_DIGITS - 4 ; Extract top 4 bits in CX.
	CMP	CX, 10                     ; Check whether decimal or alpha digit.
	JGE	AlphaDigit                 ; digit >= 10 is alphabetical.
	;JL	DecimalDigit               ; digit < 10 is decimal.

DecimalDigit:
	ADD CL, '0'                    ; Add ASCII for '0'.
	JMP AddHexChar                 ; Then add character to string.

AlphaDigit:
	ADD	CL, 'A' - 10               ; Convert 10-16 to ASCII chars 'A' to 'F'.
	;JMP AddHexChar                ; Then add character to string.

AddHexChar:
	MOV	[SI + BX], CL              ; Add digit char to string.
	INC	BX                         ; Update index.
	;JMP EndHex2StringLoop         ; Then check loop condition.

EndHex2StringLoop:                  
	SHL	AX, 4                      ; Move to next 4 bits in AX.
	CMP	BX, NUM_HEX_DIGITS         ; Check if i < NUM_HEX_DIGITS.
	;JGE EndHex2String             ; If not, end loop.
	JL Hex2StringLoop              ; Otherwise keep going.
				                   ; END DO WHILE.

EndHex2String:
	MOV	CL, ASCII_NULL             ; Prepare to add NULL character to string.
	MOV	[SI + BX], CL              ; Add NULL character to string.
	RET

Hex2String	ENDP



CODE    ENDS



        END	
