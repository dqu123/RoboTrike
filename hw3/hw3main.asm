        NAME    HW3MAIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW3MAIN                                  ;
;                            Homework #3 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the queue functions for Homework #3.  
;                   First, it allocates a testQueue using the queueSTRUC 
;                   structure defined in QUEUE.INC. Then, it calls each queue 
;                   function with some test values using the QueueTest function 
;                   defined in U:\eecs51\HW3TEST.OBJ. If all tests pass it jumps 
;                   to the label hw3test.QueueGood. If any test fails it jumps 
;                   to the label hw3test.QueueError with the error number in CX.
;
; Input:            None.
; Output:           None.
;
; User Interface:   No real user interface.  The user can set breakpoints at 
;                   hw3test.QueueGood and hw3test.QueueError to see if the code 
;                   is working or not.
;
; Error Handling:   If a test fails the program jumps to hw3test.QueueError.
;
; Algorithms:       None.
; Data Structures:  None.
;
; Known Bugs:       None.
; Limitations:      None.
;
; Revision History:
;    10/22/15  David Qu	               initial revision
;    10/23/15  David Qu                updated comments

; local include files
$INCLUDE(QUEUE.INC)

CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK



CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP

; local definitions
TEST_QUEUE_SIZE      EQU         1023        ; Queue size for testing.
                                             ; Must be less than ARRAY_SIZE.

; external function declarations

		EXTRN	QueueTest:NEAR			; Tests queue.
        EXTRN   QueueInit:NEAR          ; Initializes queue.
        EXTRN   QueueEmpty:NEAR         ; Checks if queue is empty. 
		EXTRN	QueueFull:NEAR			; Checks if queue is full. 
		EXTRN	Dequeue:NEAR			; Removes element from queue. 
		EXTRN	Enqueue:NEAR			; Adds element to queue.
	


START:  

MAIN:
        MOV     AX, DGROUP                      ; initialize the stack pointer.
        MOV     SS, AX
        MOV     SP, OFFSET(DGROUP:TopOfStack)

        MOV     AX, DGROUP                      ; initialize the data segment.
        MOV     DS, AX
        
        MOV     SI, OFFSET(DGROUP:testQueue)    ; Do the queue tests, passing
        MOV     CX, TEST_QUEUE_SIZE             ; address of queue in DS:SI and
        CALL    QueueTest             	        ; the QUEUE_SIZE in CX.


CODE    ENDS




; the data segment

DATA    SEGMENT PUBLIC  'DATA'

	testQueue		queueSTRUC<>                ; Queue for testing.
                                                ; See QUEUE.INC for details.

DATA    ENDS



; the stack

STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ; 240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START
