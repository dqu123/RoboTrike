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
; SetCriticalError()   -
; GetCriticalError()   -
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
; Shared Variables:  Reads status/writes to the eventQueue - queue of events in
;                                                            the system.
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
; Limitations:       Drops an event if the event queue is empty because this 
;                    function is called by interrupt handlers, which can't block.
;                    The RoboTrike boards do not support asynchronous waiting.
;
; Registers Changed: flags, AX.
; Special notes:     None.
InitEvents      PROC     NEAR
                PUBLIC   InitEvents
                                    
        MOV     criticalError, INIT_PARITY_INDEX ; Start with initial parity setting.
                                    
        MOV     SI, OFFSET(eventQueue)    ; Set arguments to QueueInit:        
        MOV     AX, DEFAULT_QUEUE_LEN     ; a=eventQueue, length=DEFAULT_QUEUE_LEN,
        MOV     BL, WORD_QUEUE 		      ; size=WORD_QUEUE.
        CALL    QueueInit                 
        RET     

InitEvents      ENDP

; EnqueueEvent(event)
; 
; Description:       Enqueues an event to the event queue.
; Operation:         Calls enqueue on the eventQueue if it is not full.
;
; Arguments:         event (AX) - event to enqueue. Contains the event type (AH)
;                                 and the event value (AL).
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads status/writes to the eventQueue - queue of events in
;                                                            the system.
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
; Limitations:       Drops an event if the event queue is empty because this 
;                    function is called by interrupt handlers, which can't block.
;                    The RoboTrike boards do not support asynchronous waiting.
;
; Registers Changed: flags, AX.
; Special notes:     None.
;
; Pseudo code:
; if !QueueFull(eventQueue)
;    Enqueue(eventQueue, event)
EnqueueEvent    PROC     NEAR
                PUBLIC   EnqueueEvent
                

        RET     

EnqueueEvent    ENDP

; EnqueueEvent(event)
; 
; Description:       Enqueues an event to the event queue.
; Operation:         Calls enqueue on the eventQueue if it is not full.
;
; Arguments:         event (AX) - event to enqueue. Contains the event type (AH)
;                                 and the event value (AL).
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads status/writes to the eventQueue - queue of events in
;                                                            the system.
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
; Limitations:       Drops an event if the event queue is empty because this 
;                    function is called by interrupt handlers, which can't block.
;                    The RoboTrike boards do not support asynchronous waiting.
;
; Registers Changed: flags, AX.
; Special notes:     None.
;
; Pseudo code:
; if !QueueFull(eventQueue)
;    Enqueue(eventQueue, event)
EnqueueEvent    PROC     NEAR
                PUBLIC   EnqueueEvent
                

        RET     

EnqueueEvent    ENDP

CODE    ENDS


; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    criticalError   DB     ?    ; Whether a critical error has occurred or not.
    eventQueue      queueSTRUC<>; Event queue. This is a word queue that
                                ; holds events, which consist of a byte event_type
                                ; and a byte event_value.
    
DATA    ENDS
 
 
        END 