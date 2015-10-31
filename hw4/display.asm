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
;	InitDisplay	- initializes display shared variables.
;	MultiplexDisplay - reads from the display_buffer and writes to display.
; 	Display		- adds segment bit pattern of a string to the display_buffer.
;	DisplayNum	- adds segment bit pattern of a decimal num to the display_buffer.
;	DisplayHex	- adds segment bit pattern of a hex number to the display_buffer.
;
; Local functions:
;	ClearDisplay - sets all the bits in the display_buffer to 0.
; 
; Revision History:
; 		10/29/15  David Qu		initial revision.
;		10/30/15  David Qu	    fixed display_buffer accesses.
;								added comments.

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
;									 	       bit patterns.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		Loops from the end of the display_buffer to the beginning.
; Data Structures:	display buffer (array of words).	
;
; Known Bugs:		None.
; Limitations:		None.
;
; Registers Changed: flags.
; 
; Author: David Qu
; Last Modified: 10/30/15

ClearDisplay		PROC		NEAR
				
ClearDisplayInit:
		PUSH	BX						; Save BX for caller.
		MOV		BX, 2 * BUFFER_SIZE - 2 ; Start loop at BUFFER_SIZE - 1.           

ClearDisplayLoop:
		MOV		display_buffer[BX], 0	; Clear each digit in the
		SUB		BX, 2					; display_buffer.
		JNS		ClearDisplayLoop		
        ;JS 	EndClearDisplay
		
EndClearDisplay:
		POP		BX						; Restore BX for caller.
		
		RET
		
ClearDisplay		ENDP

; InitDisplay
; 
; Description: 		Initializes the display shared variables: digit, scroll_index, 
;					blink_dim_cnt, on_time,. off_time and display_buffer. The 
;					string_buffer doesn't need to be initialized because it is 
;					always written to before it is read by dec2string and hex2string.
;
; Operation: 		Sets digit = 0, scroll_index = 0, blink_dim_cnt = 0, 
;					on_time = DEFAULT_ON_TIME, off_time = DEFAULT_OFF_TIME and 
;					calls ClearDisplay to clear all the bits in the display_buffer.
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
				
		MOV		digit, 0     		; digit, scroll_index, and blink_dim_cnt
		MOV		scroll_index, 0		; are all counters of timer ticks that
		MOV		blink_dim_cnt, 0	; should start at 0.
		
		MOV		on_time, DEFAULT_ON_TIME	; on_time, and off_time are numbers
		MOV		off_time, DEFAULT_OFF_TIME	; of timer ticks to turn on and off
											; the display per blink_dim cycle.
		
        CALL 	ClearDisplay				; The display_buffer should be 
											; empty initially.
		
		RET
		
InitDisplay		ENDP

; MultiplexDisplay
; 
; Description: 		Reads from the display_buffer and writes it to the display.
;					Writes one digit at a time, updating the shared variable 
;					digit each time it is called to track its progress.
;					Multiplexes by updating a new digit each time it is called
;					and also has a dynamically adjustable brightness setting.
;
; Operation: 		First
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
		
		MOV		AX, blink_dim_cnt	; blink_dim_cnt adjusts the display 
		CMP		AX, on_time 		; brightness by turning the display on
									; for on_time timer counts, and then off_time
									; timer counts in a periodic manner.
		;JL		MultiplexDisplayOn		
		JGE		MultiplexDisplayOff
		
MultiplexDisplayOn:
		XOR 	BX, BX							; Prepare to access the next
		MOV		BL, digit						; digit in the display_buffer,
		SHL		BL, 1							; by converting to bytes and 
		ADD		BL, scroll_index				; scrolling as necessary.
      	
		MOV		AX, WORD PTR display_buffer[BX]	; The top byte contains the extra 
												; 7 segments while the bottom 
												; byte contains the regular 7.
												
        PUSH    AX   							; Save low byte because we
												; to write the high byte first
												; and since OUT can only read
												; bytes from AL.
		
		MOV		DX, LEDDisplay + SEG14_OFFSET	; Write the high byte to the 
        MOV     AL, AH							; SEG14_OFFSET position on the
		OUT		DX, AL							; display. This clears the
												; display, so we must do it 
												; first.
		
		POP     AX								; Restore the low byte.
		
		MOV 	DX, LEDDisplay					; Write the low byte to the 
		ADD		DL, digit						; specific digit output port.
		OUT		DX, AL							; This displays the full 14 
												; segment pattern.
		
		INC		digit							; Update the digit number,
		AND		digit, NUM_DIGITS - 1  			; modulo NUM_DIGITS, using the
												; AND 2^n - 1 trick.
		
		JMP 	UpdateBlinkDimCnt
		
MultiplexDisplayOff:
		MOV		DX, LEDDisplay + SEG14_OFFSET	; Clear the SEG14_OFFSET port,
		MOV		AL, 0							; which contains the extra 7
		OUT		DX, AL							; segment pattern. This clears 
												; the display.
		;JMP 	UpdateBlinkDimCnt
		
UpdateBlinkDimCnt:
		INC	 	blink_dim_cnt		; Update the blink_dim_cnt MOD (on_time +
		MOV		CX, on_time			; off_time) using the DIV instruction.
		ADD		CX, off_time		
		XOR		DX, DX
		DIV 	CX
		MOV		blink_dim_cnt, DX
		;JMP 	UpdateScrollIndex
	
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
; Last Modified: 10/30/15

Display			PROC		NEAR
				PUBLIC		Display
        
DisplayFunctionStart:
		PUSHA						; Save caller registers.
		
        XOR     CX, CX				; Start at first element in the array.
        MOV     DI, OFFSET(display_buffer) ;
		CALL	ClearDisplay		; Clear any bits set from previous calls to
									; Display.
		
DisplayLoop:
        MOV     BX, CX
        MOV 	BL, BYTE PTR ES:[SI+BX]	; Keep track of each character
        
CheckNull:
		CMP 	BL, ASCII_NULL		; Stop writing to buffer if NULL character is
		JE 		EndDisplay			; read.
		;JMP

GetSegPattern:        
        SHL     BL, 1							; Read the digit pattern from
		MOV		AX, WORD PTR ASCIISegTable[BX]	; the ASCIISegTable.

WriteSegPattern:
        MOV     BX, CX		;
        SHL     BX, 1		;
        MOV		[DI+BX], AX	; determine if NULL
		INC 	CX

CheckEndOfBuffer:					
		CMP		CX, BUFFER_SIZE		; If at end of buffer, stop writing to it
		;JGE	EndDisplay			; and truncate the displayed string.
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
; Data Structures:  string_buffer (array of chars).
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
		
DisplayNumBody:
		LEA		SI, string_buffer	; Write the string version of n into
		CALL	Dec2String 			; string_buffer using Dec2String, which
									; takes in n from AX and writes to DS:SI.
		
		MOV 	AX, DS				; Add the segment pattern of the string
		MOV		ES, AX				; in the string_buffer into the display_buffer
		CALL	Display				; using Display, which reads from ES:SI
									; and writes to the display_buffer.
		
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
		
DisplayHexBody:
		LEA		SI, string_buffer	; Write the string version of n into
		CALL	Hex2String 			; string_buffer using Hex2String, which
									; takes in n from AX and writes to DS:SI.
		
		MOV 	AX, DS				; Add the segment pattern of the string
		MOV		ES, AX				; in the string_buffer into the display_buffer
		CALL	Display				; using Display, which reads from ES:SI
									; and writes to the display_buffer.
		
EndDisplayHex:
		POPA						; Restore caller registers.
        
        RET
		
DisplayHex		ENDP


CODE	ENDS



; the data segment

DATA    SEGMENT PUBLIC  'DATA'
	digit			DB	?	; determines digit to write to/read from.
	scroll_index	DB	?	; determines position in the display_buffer to read.
	blink_dim_cnt	DW 	?	; determines when/when not to display.
	on_time			DW 	?	; timer counts to show display.
	off_time		DW  ?	; timer counts to hide display.
	string_buffer	DB	(MAX_STRING_SIZE) DUP  (?) ; 
	display_buffer	DW	(BUFFER_SIZE)     DUP  (?) ;
	

DATA    ENDS		
		
		
		END