		NAME	DISPLAY
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  DISPLAY                                     ;
;                              Display Functions                               ;
;                                EE/CS 51                                      ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; This file contains the functions for manipulating the display_buffer, a shared
; variable defined in this file that contains the segment pattern that should
; be multiplexed to the display. The public functions included are:
;	InitDisplay	- initializes display shared variables
; 	Display		- adds segment bit pattern of a string to the display_buffer
;	DisplayNum	- adds segment bit pattern of a decimal num to the display_buffer
;	DisplayHex	- adds segment bit pattern of a hex number to the display_buffer
;
; Local functions:
;	ClearDisplay 	- sets all the bits in the display_buffer to 0.
; 
; Revision History:
; 		10/29/15  David Qu		initial revision

; local include files
$INCLUDE(DISPLAY.INC)
$INCLUDE(CONVERTS.INC)

CGROUP	GROUP	CODE 
DGROUP  GROUP   DATA

CODE 	SEGMENT PUBLIC 'CODE'

		ASSUME 	CS:CGROUP, DS:DATA
		
		EXTRN 	ASCIISegTable:NEAR
		EXTRN	Hex2String:NEAR
		EXTRN	Dec2String:NEAR

; ClearDisplay
; 
; Description: 		Clears the display buffer.
; Operation: 		Goes through display buffer, clearing one word at a time.
;
; Arguments:		None.
; Return Value:		None.
;
; Local Variables:	None.
; Shared Variables:	Writes to display_buffer - shared word array of segment
;									 bit patterns.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		Loops from BUFFER_SIZE to 0.
; Data Structures:	display buffer (array of words).	
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Changed: flags.
; 
; Author: David Qu
; Last Modified: 10/29/15

ClearDisplay		PROC		NEAR
				
ClearDisplayInit:
		PUSH	BX						; Save BX for caller.
		MOV		BX, BUFFER_SIZE - 1     ; Start loop at BUFFER_SIZE - 1.

ClearDisplayLoop:
		MOV		display_buffer[BX], 0	; Write 0 to each word in the
		DEC		BX						; display_buffer.
		JS		ClearDisplayLoop		
        ;JNS 	EndClearDisplay
		
EndClearDisplay:
		POP		BX						; Restore BX for caller.
		
		RET
		
ClearDisplay		ENDP

; InitDisplay
; 
; Description: 		Initializes the display shared variables: digit, 
;					scroll_index, and display_buffer. The string_buffer doesn't
;					need to be initialized because it is always written to 
;					before it is read by dec2string and hex2string.
; Operation: 		Sets digit = 0, scroll_index = 0, and calls ClearDisplay to
;					set all the bits in the display_buffer
;
; Arguments:		None. 
; Return Value:		None.
;
; Local Variables:	None.
; Shared Variables:	Writes to
;						digit - current digit to multiplex
;						scroll_index - current scroll_index
;						display_buffer - word array of segment bit patterns
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		None.
; Data Structures:	display buffer (array of words).	
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Used:	flags.
; 
; Author: David Qu
; Last Modified: 10/29/15

InitDisplay		PROC		NEAR
				PUBLIC		InitDisplay
				
		MOV		digit, 0     		; Initialize display shared variables.
		MOV		scroll_index, 0
		MOV		blink_dim_cnt, 0
		MOV		on_time, DEFAULT_ON_TIME
		MOV		off_time, DEFAULT_OFF_TIME
        CALL 	ClearDisplay
		
		RET
		
InitDisplay		ENDP

; MultiplexDisplay
; 
; Description: 		Reads from the display_buffer and writes it to the display.
;					Writes one digit at a time, updating the shared variable 
;					digit each time it is called to track its progress.
;
; Operation: 
;
; Arguments:		string (ES:SI) - null terminated ASCII string to display.
; Return Value:		None.
;
; Local Variables:	index (BP) - used to access characters in the string.
;					char  (BL) - tracks the current character read.
;					temp  (AX) - used for multiple dereferences.
; Shared Variables:	Reads display_buffer - word array of segment patterns.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		Interrupt based multiplexing.
; Data Structures:	display buffer (array of words).
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Changed: flags.
; 
; Author: David Qu
; Last Modified: 10/29/15

MultiplexDisplay	PROC		NEAR
					PUBLIC		MultiplexDisplay
        
MultiplexDisplayInit:
		PUSHA						; Save caller registers.
		XOR 	BX, BX
		
		MOV		AX, on_time
		CMP		blink_dim_cnt, AX 
		;JL		MultiplexDisplayOn		
		JGE		MultiplexDisplayOff
		
MultiplexDisplayOn:
		MOV 	DX, LEDDisplay
		ADD		DL, digit
		
		MOV		BL, digit
		SHL		BL, 1
		ADD		BL, scroll_index
		MOV 	AL, BYTE PTR display_buffer[BX]
		OUT		DX, AL
		
		MOV		DX, LEDDisplay + SEG14_OFFSET
		INC		BL
		MOV		AL, BYTE PTR display_buffer[BX]
		OUT		DX, AL
		
		INC		digit
		AND		digit, NUM_DIGITS - 1  
		
		JMP 	UpdateBlinkDimCnt
		
MultiplexDisplayOff:
		MOV		DX, LEDDisplay + SEG14_OFFSET
		MOV		AL, 0
		OUT		DX, AL
		
		;JMP 	UpdateBlinkDimCnt
		
UpdateBlinkDimCnt:
		INC	 	blink_dim_cnt
		MOV		CX, on_time
		ADD		CX, off_time
		XOR		DX, DX
		DIV 	CX
		MOV		blink_dim_cnt, DX
	
UpdateScrollIndex:
		
		;JMP   	EndMultiplexDisplay
		
EndMultiplexDisplay:		
		POPA						; Restore caller registers.
        
        RET
		
MultiplexDisplay			ENDP

; Display
; 
; Description: 		Clears display buffer and then writes the 14 segment bit pattern 
;					corresponding to the passed string to display_buffer. The bit 
;					pattern will be sent to the display by the MultiplexDisplay 
;					function. The maximum allowed string size is BUFFER_SIZE, 
;					defined in DISPLAY.INC. If a string is larger than the 
;					BUFFER_SIZE, it is truncated to the BUFFER_SIZE.
;
; Operation: 		Loop through each character in the string, and add its 
;					corresponding segment pattern to the display_buffer. Stop 
;					when a NULL character is read or the end of the buffer is 
;					reached.
;
; Arguments:		string (ES:SI) - null terminated ASCII string to display.
; Return Value:		None.
;
; Local Variables:	index (BP) - used to access characters in the string.
;					char  (BL) - tracks the current character read.
;					temp  (AX) - used for multiple dereferences.
; Shared Variables:	Writes to display_buffer - word array of segment patterns.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		Loop until end of string or end of buffer.
; Data Structures:	display buffer (array of words).
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Changed: flags.
; 
; Author: David Qu
; Last Modified: 10/29/15

Display			PROC		NEAR
				PUBLIC		Display
        
DisplayFunctionStart:
		PUSHA						; Save caller registers.
		
		XOR		BP, BP				; Start at the beginning of the string.
		XOR		BX, BX				; Clear high byte for accessing 256 entry
									; ASCIISegTable.
		CALL	ClearDisplay		; Clear any bits set from previous calls to
									; Display.
		
DisplayLoop:
		MOV 	BL, BYTE PTR ES:[SI+BP]			; Keep track of each character
		MOV		AX, WORD PTR ASCIISegTable[BX]	; read from the string to 
		MOV		WORD PTR display_buffer[BP], AX	; determine if NULL
		INC 	BP

CheckNull:
		CMP 	BL, ASCII_NULL		; Stop writing to buffer if NULL character is
		JE 		EndDisplay			; read. Otherwise check if at end of buffer. 
		;JNE	CheckEndOfBuffer

CheckEndOfBuffer:					
		CMP		BP, BUFFER_SIZE		; If at end of buffer, stop writing to it.
		;JGE	EndDisplay			
		JL		DisplayLoop
		
EndDisplay:
		POPA						; Restore caller registers.
        
        RET
		
Display			ENDP


; DisplayNum
; 
; Description: 		Converts a 16-bit signed decimal number to a zero-padded
;					6-7 byte string that is then displayed on the LEDDisplay.
;					The string contains a minus sign if the number is negative
;					and no sign if the number is positive. The resulting number
;					will be left aligned on the display and will overwrite 
;					any existing values in the display.
;
; Operation:		Set up SI and ES to call Dec2String and then Display.
;
; Arguments:		n (AX) - 16-bit signed decimal number to display.
; Return Value:		None.
;
; Local Variables:	SI - used to pass string_buffer to dec2string.
;					ES - set to DS so Display will work properly.
; Shared Variables:	Writes to string_buffer - char array to store string.
;					Writes to display_buffer - word array of segment patterns.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		None.
; Data Structures:  string buffer (array of chars).
;					display_buffer (array of words).
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Changed: flags.
; 
; Author: David Qu
; Last Modified: 10/29/15

DisplayNum		PROC		NEAR
				PUBLIC		DisplayNum
        
DisplayNumInit:
		PUSHA						; Save caller registers.
		
		MOV 	AX, DS
		MOV		ES, AX
		LEA		SI, string_buffer
		
DisplayNumBody:
		CALL	Dec2String 
		CALL	Display
		
EndDisplayNum:
		POPA						; Restore caller registers.
        
        RET
		
DisplayNum		ENDP

; DisplayHex
; 
; Description: 		Converts a 16-bit unsigned hexadecimal number to a zero-padded
;					5 byte string that is then displayed on the LEDDisplay.
;					The resulting number will be left aligned on the display and 
;					will overwrite any existing values in the display.
;
; Operation:		Set up SI and ES to call Dec2String and then Display.
;
; Arguments:		n (AX) - 16-bit unsigned hexadecimal number to display.
; Return Value:		None.
;
; Local Variables:	SI - used to pass string_buffer to dec2string.
;					ES - set to DS so Display will work properly.
; Shared Variables:	Writes to string_buffer - char array to store string.
;					Writes to display_buffer - word array of segment patterns.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		None.
; Data Structures:  string buffer (array of chars).
;					display_buffer (array of words).
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Changed: flags.
; 
; Author: David Qu
; Last Modified: 10/29/15

DisplayHex		PROC		NEAR
				PUBLIC		DisplayHex
        
DisplayHexInit:
		PUSHA						; Save caller registers.
		
		MOV		AX, DS
		MOV		ES, AX
		LEA		SI, string_buffer
		
DisplayHexBody:
		CALL	Hex2String 
		CALL	Display
		
EndDisplayHex:
		POPA						; Restore caller registers.
        
        RET
		
DisplayHex		ENDP


CODE	ENDS

; the data segment

DATA    SEGMENT		  'DATA'
	digit			DB	?
	scroll_index	DB	?
	blink_dim_cnt	DW 	?
	on_time			DW 	?
	off_time		DW  ?
	string_buffer	DB	(MAX_STRING_SIZE) DUP  (?)
	display_buffer	DW	(BUFFER_SIZE)     DUP  (?)	
	

DATA    ENDS		
		
		
		END