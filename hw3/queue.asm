		NAME	QUEUE
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  QUEUE                                       ;
;                              Queue Functions                                 ;
;                                EE/CS 51                                      ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; Description: Functions for manipulating the queueSTRUC structure defined in 
;   CONVERTS.INC. Fields in the struct include head, tail, e_size, and array.
; 
; Usage: First, allocate a queueSTRUC on the DATA segment. 
;   QueueInit must be called to initialize the queueSTRUC, and determines 
;   whether the queue is a byte or word queue. Once the queue is initialized, 
;   elements can be enqueued with the Enqueue function, or dequeued with the
;   Dequeue function, and the QueueFull and QueueEmpty functions can be used
;   to check if the queue is full or empty.
; 
; Revision History:
; 		10/22/15  David Qu		initial revision
;       10/23/15  David Qu      Added callee save of AX to QueueFull and 
;                               QueueEmpty to avoid trampling register.
;                               Updated code to be more modular in terms
;                               of BYTES_PER_WORD.

; local include files
$INCLUDE(QUEUE.INC)
$INCLUDE(genMacro.inc)

CGROUP	GROUP	CODE 


CODE 	SEGMENT PUBLIC 'CODE'


		ASSUME 	CS:CGROUP

; QueueInit
; 
; Description: Initializes a queue of the passed length (AX) and element size
; 	(BL), at the passed address (DS:SI). This queue is implemented as an array 
;	that circles around by performing addition modulo a fixed ARRAY_SIZE.
; 	This ARRAY_SIZE is a fixed power of 2 defined in the QUEUE.INC file.
; 	After this procedure is called, if the zero flag is not set, the queue is 
; 	empty and ready to accept values. If the zero flag is set, then an error 
; 	occurred (passed length was too large). 
;	
; Operation: First set both head and tail to 0. These represent the index offset 
;   (in bytes) of the queue head and tail relative to the queue array. Then, 
; 	check if the element size (BL) is true (non-zero). If BL is true, set 
;   e_size = BYTES_PER_WORD, otherwise set e_size = 1. Check to make 
;   sure length (AX) * e_size < ARRAY_SIZE. If not, there is not enough 
;   array space (we leave one blank to determine if the queue is full, so we use
;   < instead of <=), and we return with the zero flag set. If there is space, 
;  	then we reset the zero flag to signal that initialization was sucessful. 
;
; Arguments: 		a (DS:SI)	- address where queue will be initialized
; 					length (AX) - maximum length of the queue (ignored if <
;                                 ARRAY_SIZE, otherwise the zero flag is set).
;                 	size (BL)   - boolean representing element size. Is non-zero
;                                 if the elements are words, otherwise is zero 
;                                 if the elements are bytes. (Only words and 
;                                 bytes are allowed).                                            
; Return Value:		Zero flag is set iff there is an error. Otherwise the queue
; 					is initialized and the zero flag is reset.
;
; Local Variables: 	temp (AX) 	- temporary variable for instructions requiring
;								  a register. Also used to convert length to
;                                 bytes.
; Shared Variables: None.
; Global Variables: None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	If the length >= ARRAY_SIZE, the zero flag is set, and 
; 					the queue is not initialized.
;
; Algorithms:		None.
; Data Structures:	queueSTRUC structure. See QUEUE.INC for details.
;
; Known Bugs:		None.
; Limitations:		Can only hold up to ARRAY_SIZE - 1 bytes.
;                   Assumes DS:SI is a valid pointer to a queueSTRUC.
;
; Registers Used:	flags, AX, BL, SI.
; Stack Depth:		0 words.
; 
; Author: David Qu
; Last Modified: 10/23/15

QueueInit		PROC 		NEAR
				PUBLIC		QueueInit
                
        PUSH    AX                          ; Save AX for caller.
        
StartQueueInit:
		MOV 	[SI].head, 0				; Start at the front of the array 		
		MOV		[SI].tail, 0				; with head == tail (empty queue).
		
SizeInit:
		CMP		BL, 0 						; Determine queue element size. 
		JNZ		WordQueue					; Is a byte queue if BL is zero
		;JZ		ByteQueue					; and is a word queue if BL != 0.
		
ByteQueue:
		MOV		[SI].e_size, 1				; Set element size in bytes.
		JMP		CheckLength
		
WordQueue:
		MOV		[SI].e_size, BYTES_PER_WORD	; Set element size in bytes.
		SHL		AX, WORD_SHIFT_AMT 			; Converts length (AX) to bytes
											; by multiplying by WORD_SHIFT_AMT.
		;JMP	CheckLength	

CheckLength:									
		CMP		AX, ARRAY_SIZE				; Ensure the array has enough memory
		;JAE	BadLength					; to hold length (AX) elements of
		JB		GoodLength                  ; the size specified above.
                                          
BadLength:
		CMP 	AX, AX						; Set zero flag to indicate error
		JMP 	EndQueueInit				; and then return.
		
GoodLength:
		OR		AX, 1						; Reset zero flag to show success
		;JMP	EndQueueInit				; and then return.
        
EndQueueInit:
        POP     AX                          ; Restore AX.
		RET
		
QueueInit		ENDP



; QueueEmpty
; 
; Description: Checks if the queue at DS:SI is empty. If it is, return with
; 	the zero flag set. Otherwise, return with the zero flag reset. 
;
; Operation: Compares head and tail for equality and return.
;
; Arguments:		address (DS:SI) - address of the queue.
; Return Value:		Zero flag is set iff the queue is empty.
;
; Local Variables:	head (AX) - head index in bytes.
; Shared Variables:	None.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		head == tail implies that the queue empty.
; Data Structures:	queueSTRUC structure. See QUEUE.INC for details.	
;
; Known Bugs:		None.
; Limitations:		Assumes DS:SI is a valid pointer to a queueSTRUC, and that
;					QueueInit has been called on the queueSTRUC.
;
; Registers Used:	flags, AX, SI.
; Stack Depth:		0 words.
; 
; Author: David Qu
; Last Modified: 10/23/15

QueueEmpty		PROC		NEAR
				PUBLIC		QueueEmpty
        
        
        PUSH    AX                  ; Save AX for caller.
		
        ;CRITICAL_START
        MOV		AX, [SI].head		; Move to AX to do two dereferences.
		CMP		AX, [SI].tail		; Compare head and tail and set
									; flags appropriately.
        ;CRITICAL_END
        
        POP     AX                  ; Restore AX.
        
        
		RET
		
QueueEmpty		ENDP



; QueueFull
; 
; Description: Checks if the queue at DS:SI is full. If it is, return with the
; 	zero flag set. Otherwise returns with the zero flag reset.
;
; Operation: First, compute tail + e_size mod ARRAY_SIZE. 
; 	Then compare this to head (zero flag will be set appropriately).
;
; Arguments:		address (DS:SI) - address of the queue.
; Return Value:		Zero flag is set iff the queue is full.
;
; Local Variables:	index (AX) - used to compute tail + 1 mod ARRAY_SIZE.
; Shared Variables:	None.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		Addition mod powers of 2 via AND (2^n - 1) to handle the
;					circular aspect of the queue. One element space will be 
;					reserved to determine if the queue is full. Thus we add 
;					e_size to tail mod ARRAY_SIZE and compare to head to 
;                   see if the queue is full.
; Data Structures:	queueSTRUC structure. See QUEUE.INC for details.
;
; Known Bugs:		None.
; Limitations:		Assumes DS:SI is a valid pointer to a queueSTRUC, and that
;					QueueInit has been called on the queueSTRUC.
;
; Registers Used:	flags, AX, SI.
; Stack Depth:
; 
; Author: David Qu
; Last Modified: 10/23/15

QueueFull		PROC		NEAR
				PUBLIC		QueueFull
        

        
		PUSH    AX                      ; Save AX for caller.
        
        ;CRITICAL_START
        MOV		AX, [SI].tail			; Compute tail + e_size mod ARRAY_SIZE
		ADD		AX, [SI].e_size			; using the AND bit trick, taking
		AND		AX, ARRAY_SIZE - 1		; advantage of the fact that ARRAY_SIZE
										; is a power of 2.
										
		CMP		AX, [SI].head			; tail + 1 mod ARRAY_SIZE == head iff
										; the queue is full. 
        ;CRITICAL_END
		
        POP     AX                      ; Restore AX.

        
        RET
		
QueueFull		ENDP



; Dequeue
; 
; Description: Removes either a one byte value or two byte value (depending on
; 	e_size) from the head of the queue at the passed address DS:SI, and
; 	returns it in AL or AX. This is a blocking function, and will block if the
;	queue is empty.
;
; Operation: First, block if the queue is empty. Otherwise, read from 
;   array[head] into AX if e_size != 1, and into AL if e_size = 1. Result
; 	will be in AX if it is a word queue and AL if it is a byte queue.
;
; Arguments:		address (DS:SI) - address of the queue.
; Return Value:		If e_size != 1, returns in AX. 
; 					If e_size == 1, returns in AL.
;
; Local Variables:	value (AL/AX) - read value to return.
;					head (BX)	  - head index in bytes.
; Shared Variables:	None.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		head = head + e_size mod ARRAY_SIZE since 
; 					it points to the next available value in the queue.
; Data Structures:	queueSTRUC structure. See QUEUE.INC for details.
;
; Known Bugs:		None.
; Limitations:		Assumes DS:SI is a valid pointer to a queueSTRUC, and that
;					QueueInit has been called on the queueSTRUC.
;
; Registers Used:	flags, AX, BX, SI.
; Stack Depth:		0 words.
; 
; Author: David Qu
; Last Modified: 10/23/15

Dequeue			PROC		NEAR
				PUBLIC		Dequeue
        %CRITICAL_START
        
BlockDequeue:
		CALL	QueueEmpty			; Check if queue is empty and block if
		JZ		BlockDequeue		; it is. Can be interrupted into other
                                    ; code, but will eventually unblock once
									; the queue is not empty.
		
StartDequeue:
		MOV		BX, [SI].head	    ; Move head to BX for indirect access
                                    ; and to update it.
		
		CMP		[SI].e_size, 1		; See if reading byte or word.
		;JZ		ReadByte		
		JNZ		ReadWord

ReadByte:
		MOV		AL, BYTE PTR [SI].array[BX] ; Dequeue element at head.
		JMP		EndDequeue
		
ReadWord:
        MOV     AX, WORD PTR [SI].array[BX] ; Dequeue element at head.
		;JMP	EndDequeue
		
EndDequeue:
		ADD		BX, [SI].e_size     ; Update head by computing head + e_size mod 
		AND		BX, ARRAY_SIZE - 1 	; ARRAY_SIZE using the fact that ARRAY_SIZE
		MOV		[SI].head, BX		; is a power of 2.

        %CRITICAL_END
        
		RET
		
Dequeue			ENDP



; Enqueue
; 
; Description: Adds the passed byte or word value to the tail of the queue
; 	at the passed address DS:SI. This is a blocking function that waits if the
;	queue is full. It does not return until the value is added to the queue.
;
; Operation: First, block if the queue is full. If not, add a word value if
;	e_size != 1, or add a byte value if e_size == 1 to the address specified 
;   by array[tail]. Then increment tail mod ARRAY_SIZE to update the queue.
;
; Arguments:		address (DS:SI) - address of the queue.
;					value (AX)		- value to enqueue. Size is determined by
;									  e_size.
; Return Value:		Zero flag is set iff the queue is empty.
;
; Local Variables:	tail (BX)		- tail index in bytes.
; Shared Variables:	None.
; Global Variables:	None.
;
; Input:			None.
; Output:			None.
;
; Error Handling:	None.
;
; Algorithms:		tail = tail + 1 mod ARRAY_SIZE since tail points to the
;                   next available position in the array.
; Data Structures:	queueSTRUC structure. See QUEUE.INC for details.
;
; Known Bugs:		None.
; Limitations:		Assumes DS:SI is a valid pointer to a queueSTRUC, and that
;					QueueInit has been called on the queueSTRUC.
;
; Registers Used:	flags, AX, BX, SI.
; Stack Depth:		0 words.
; 
; Author: David Qu
; Last Modified: 10/23/15

Enqueue			PROC		NEAR
				PUBLIC		Enqueue
                
        %CRITICAL_START
        
BlockEnqueue:
		CALL	QueueFull			; Check if queue is full and block if 
		JZ		BlockEnqueue		; it is. Can be interrupted into other
                                    ; code, but will eventually unblock once
									; the queue is not full.

StartEnqueue:
		MOV		BX, [SI].tail		; Move tail to BX for indirect access
                                    ; and to update it.
		
		CMP		[SI].e_size, 1		; See if writing byte or word.
		;JZ		WriteByte
		JNZ		WriteWord

WriteByte:
		MOV		BYTE PTR [SI].array[BX], AL   ; Enqueue element to tail.
		JMP 	EndEnqueue
		
WriteWord:
        MOV     WORD PTR [SI].array[BX], AX   ; Enqueue element to tail.
		;JMP	EndEnqueue
		
EndEnqueue:
		ADD		BX, [SI].e_size		; Update tail by adding e_size mod 
									; ARRAY_SIZE using the fact that ARRAY_SIZE
		AND		BX, ARRAY_SIZE - 1	; is a power of 2.
		MOV		[SI].tail, BX		
		
        %CRITICAL_END
        
		RET
Enqueue			ENDP


CODE	ENDS
		
		
		
		END