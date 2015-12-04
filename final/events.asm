        NAME   EVENTS
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  EVENTS                                      ;
;                             Event Queue Functions                            ;
;                                 EE/CS 51                                     ;
;                                 David Qu                                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contain the functions to access the event queue along with the DATA
; segment containing the event queue shared variable. This module is used by
; the RoboTrike keypad, display, motor, and serial event handlers, which enqueue
; events to the event queue, and the two main loops, which dequeue events and
; process them.
; 
; Public functions:
; InitEvents()         - Initialize shared variables for events.
; EnqueueEvent()       - Attempt to enqueue an event to the event queue.
; DequeueEvent()       - Dequeue an event from the event queue if it is not empty.
; GetCriticalError()   - Gets the current critical error.
;
; Local functions:
; None.
;
; Shared Variables:
;    criticalError  DB  - whether a critical error has occurred in the system. 
;    eventQueue queueSTRUC<> - queue of events to process.
;
; Revision History:
; 		12/3/15  David Qu		initial revision.


;local include files. 
$INCLUDE(general.inc)  ; general constants.
$INCLUDE(queue.inc)    ; queue constants.

CGROUP	GROUP	CODE 

CODE 	SEGMENT PUBLIC 'CODE'
		ASSUME 	CS:CGROUP, DS:DATA
        
        ; external function declarations
        EXTRN   QueueInit:NEAR     ; Initializes queue.
        EXTRN   QueueEmpty:NEAR    ; Checks if queue is empty. 
		EXTRN	QueueFull:NEAR     ; Checks if queue is full. 
		EXTRN	Dequeue:NEAR       ; Removes element from queue. 
		EXTRN	Enqueue:NEAR       ; Adds element to queue.  
       
; InitEvents()
; 
; Description:       Initializes events.asm shared variables including the
;                    eventQueue, and criticalError shared variable.
; Operation:         Sets criticalError = False, and initializes a word 
;                    eventQueue using QueueInit.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to the eventQueue - queue of events in the system.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   eventQueue - FIFO word queue of events to process
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, BL.
; Special notes:     None.
InitEvents      PROC     NEAR
                PUBLIC   InitEvents
                                    
        MOV     criticalError, FALSE      ; Initially no critical error has
                                          ; occurred.
                                    
        MOV     SI, OFFSET(eventQueue)    ; Set arguments to QueueInit:        
        MOV     AX, DEFAULT_QUEUE_LEN     ; a=eventQueue, length=DEFAULT_QUEUE_LEN,
        MOV     BL, WORD_QUEUE 		      ; size=WORD_QUEUE.
        CALL    QueueInit                 
        
        RET     

InitEvents      ENDP


; EnqueueEvent(event)
; 
; Description:       Enqueues an event in (AX) to the event queue.
;                    This should contain the event type in AH and the event
;                    value in AL.
; Operation:         Calls enqueue on the eventQueue if it is not full.
;                    If it is full, signals a critical error, which MUST be
;                    checked for in the main loop, and the system should be
;                    reset.
;
; Arguments:         event (AX) - event to enqueue. Contains the event type (AH)
;                                 and the event value (AL).
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads status/writes to the eventQueue - queue of events in
;                                                            the system.
;                    Writes to criticalError - whether a critical error has 
;                                              occurred.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   eventQueue - FIFO word queue of events to process
;
; Known Bugs:        None.
; Limitations:       Signals a critical error if the event queue is full because 
;                    this function is called by interrupt handlers, which can't 
;                    block. The RoboTrike boards do not support asynchronous waiting.
;
; Registers Changed: flags, SI.
; Special notes:     None.
EnqueueEvent    PROC     NEAR
                PUBLIC   EnqueueEvent

        MOV     SI, OFFSET(eventQueue)  ; Check if the event queue is full.
        CALL    QueueFull               ; If it is, signal a critical error to
        ;JZ     SignalCriticalError     ; reset the system.
        JNZ     DoEnqueueEvent          ; Else, just enqueue the event.
 
SignalCriticalError:
        MOV     criticalError, TRUE     ; Set a critical error through the
        JMP     EndEnqueueEvent         ; shared variable, and return so it
                                        ; can be processed by the main loop.

DoEnqueueEvent:
        CALL    Enqueue                 ; Enqueue an event to be processed by
        ;JMP    EndEnqueueEvent         ; the main loop.
        
EndEnqueueEvent:
       
        RET     

EnqueueEvent    ENDP


; DequeueEvent()
; 
; Description:       Dequeues an event from the event queue. Returns the event
;                    in AX if there is an event and resets the carry flag.
;                    Otherwise sets the carry flag if the event queue is empty.
; Operation:         Calls dequeue on the eventQueue if it is not empty.
;
; Arguments:         None.
; Return Value:      event (AX) - event to enqueue. Contains the event type (AH)
;                                 and the event value (AL).
;                    CF - set if event queue is empty. reset otherwise.
;
; Local Variables:   None.
; Shared Variables:  Reads from the eventQueue - queue of events in the system.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   eventQueue - FIFO word queue of events to process
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, SI.
; Special notes:     None.
;
; Pseudo code:
; if !QueueFull(eventQueue)
;    Enqueue(eventQueue, event)
DequeueEvent    PROC     NEAR
                PUBLIC   DequeueEvent
                
        MOV     SI, OFFSET(eventQueue)  ; Check if the event queue is empty.
        CALL    QueueEmpty              ; If it is, signal
        ;JZ     EventQueueEmpty         ; reset the system.
        JNZ     DoEnqueueEvent          ; Else, just enqueue the event.
 
EventQueueEmpty:
        STC                             ; Set the CF to signal that the event
                                        ; queue is empty.
        JMP     EndDequeueEvent         

DoDequeueEvent:
        CALL    Dequeue                 ; Enqueue an event to be processed by
                                        ; the main loop.
        CLC                             ; Clear the CF to signal that there is
                                        ; an event.
        ;JMP    EndDequeueEvent        
        
EndDequeueEvent:        

        RET     

DequeueEvent    ENDP


; GetCriticalError()
; 
; Description:       Accessor to get the critical error value in AL.
; Operation:         Returns criticalError in AL.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads criticalError - whether a critical error has occurred.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AL.
; Special notes:     None.
GetCriticalError    PROC     NEAR
                    PUBLIC   GetCriticalError

        MOV     AL, criticalError
       
        RET     

GetCriticalError    ENDP

CODE    ENDS


; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    criticalError   DB     ?    ; Whether a critical error has occurred or not.
    eventQueue      queueSTRUC<>; Event queue. This is a word queue that
                                ; holds events, which consist of a byte event_type
                                ; and a byte event_value.
    
DATA    ENDS
 
 
        END 