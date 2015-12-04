        NAME    SERIAL
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  SERIAL                                      ;
;                             Serial Functions                                 ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contains the functions to transmit and receive data from the serial 
; device. To use this module, the serial device must first be initialized using 
; the initSeri module. These functions are used both by the motor unit and the 
; remote unit of the RoboTrike to communicate between the two systems. They
; implement a Event-Driven communication protocol with a transmission queue
; and an event queue for each side of the link.
;
; Public functions:
; InitSerialVars()        - initializes serial shared variables.
; SerialSendString        - sends a null terminated string to the serial channel.
; HandleSerial()          - handles serial interrupts.
; SerialPutChar(c)        - outputs a character to the serial channel.
; SetSerialBaudRate(rate) - sets the baud rate of the serial channel.
; ToggleParity()          - toggles the parity setting of the serial.
;
; Local functions:
; HandleSerialError()      - handles a serial error interrupt.
; HandleSerialData()       - handles a serial data interrupt.
; HandleEmptyTransmitter() - handles an empty transmitter interrupt.
; HandleModem()            - handles a modem interrupt. 
;
; Read-only tables: 
; HandleSerialTable        - table of functions used for HandleSerial() 's
;                            "switch" statement.
; SerialErrorTable         - table of error bits in the LSR that correspond
;                            to error events in the system. This table lets
;                            us loop through the bits and enqueue each as
;                            a separate event.
; ParityTable              - table of parity bit pattern to toggle through
;                            in a cyclic fashion.
;
; Revision History:
; 		11/19/15  David Qu		initial revision.
;       11/20/15  David Qu      fixed bugs.
;       11/21/15  David Qu      added comments.

;local include files. 
$INCLUDE(genMacro.inc) ; General purpose macroes (CRITICAL_START, CRITICAL_END)
$INCLUDE(general.inc)  ; General constants.
$INCLUDE(initSeri.inc) ; General serial constants.
$INCLUDE(queue.inc)    ; Queue struct.
$INCLUDE(serial.inc)   ; RoboTrike serial protocol constants.
$INCLUDE(events.inc)   ; Event types.
$INCLUDE(eoi.inc)      ; EOIs for event handler.
 
; Transmission protocol:
; This code uses an event-driven approach to handle data transmission with
; transmission and event queues on both sides of the system. To send
; a character from the motor unit to the remote unit, one would call SerialPutChar
; on the motor unit. This enqueues the character into a transmission queue on
; the motor unit txQueue. The motor unit event handler will send a character from
; the txQueue to the motor Transmitter Holding Register when a transmitter empty
; interrupt is received. The motor serial chip will send the character to the 
; remote serial chip at a rate determined by the baud rate. The remote serial 
; chip will receive the byte and enqueue it into remote event queue, where
; it will be processed by the remote main loop.
;
; Special notes:
; Note that the transmitter empty interrupt is only fired once and turns itself off to
; reduce polling. This means that the Interrupt Enable Register must be kickstarted
; (reset and then set) before another interrupt can be received.
; Note that the baud rates of the motor and remote serial chips must be synchronized.
; This is done by initialization. Changes in the baud rate must be synchronized
; with a protocol (that is not provided in this module).
; Note that the order of various instructions is very critical since this
; system is interrupt based. Changes in order of instruction should be carefully
; considered.

CGROUP	GROUP	CODE 

CODE 	SEGMENT PUBLIC 'CODE'
		ASSUME 	CS:CGROUP, DS:DATA
        
        ; external function declarations
        EXTRN 	EnqueueEvent:NEAR  ; Enqueues to the event queue.
        EXTRN   QueueInit:NEAR     ; Initializes queue.
        EXTRN   QueueEmpty:NEAR    ; Checks if queue is empty. 
		EXTRN	QueueFull:NEAR     ; Checks if queue is full. 
		EXTRN	Dequeue:NEAR       ; Removes element from queue. 
		EXTRN	Enqueue:NEAR       ; Adds element to queue.  
        EXTRN   SetSerialDivisor:NEAR ; Sets the serial divisor.
        EXTRN   SetParity:NEAR     ; Sets the parity bits.
        
; Read-only tables
HandleSerialTable LABEL   WORD
        DW      HandleModem             ; Table of functions for
        DW      HandleEmptyTransmitter  ; the switch statement in 
        DW      HandleSerialData        ; HandleSerial(). These functions handle
        DW      HandleSerialError       ; various interrupt cases.
        
SerialErrorTable  LABEL   BYTE
        DB      OVERRUN_BIT           ; Table of LSR bits that correspond to
        DB      PARITY_ERROR_BIT      ; errors. This table lets us loop
        DB      FRAMING_ERROR_BIT     ; through all the bits and process
        DB      BREAK_INT_BIT         ; them as separate events.
SIZE_ERROR_TABLE        EQU     $ - SerialErrorTable
        
ParityTable       LABEL   BYTE  
        DB      NO_PARITY             ; Table of parity bit patterns that
        DB      EVEN_PARITY           ; correspond to various parity options.
        DB      ODD_PARITY            ; Used by ToggleParity().
        DB      EVEN_STICK_PARITY
        DB      ODD_STICK_PARITY
NUM_PARITY_OPTIONS      EQU     $ - ParityTable
        
; InitSerialVars()
; 
; Description:       Initializes serial shared variables. Initializes
;                    kickstart = FALSE, parity = INIT_PARITY_INDEX and the 
;                    txQueue using the queue functions.
; Operation:         Sets kickstart = FALSE, parity = INIT_PARITY_INDEX, 
;                    and calls QueueInit() to initialize the transmission queue.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to kickstart   - boolean that determines whether
;                                            the serial needs to be kickstarted.
;                              txQueue     - queue of transmission data to send.
;                              parity      - toggle index for parity.
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
; Registers Changed: flags.
; Special notes:     None.
InitSerialVars  PROC     NEAR
                PUBLIC   InitSerialVars
                
        MOV     kickstart, FALSE    ; Don't need to kickstart initially since
                                    ; there is nothing in the txQueue.
                                    
        MOV     parity, INIT_PARITY_INDEX ; Start with initial parity setting.
                                    
        MOV     SI, OFFSET(txQueue)       ; Set arguments to QueueInit:        
        MOV     AX, TX_QUEUE_LENGTH       ; a=txQueue, length=TX_QUEUE_LENGTH,
        MOV     BL, FALSE 				  ; size=TX_QUEUE_ELEMENT_SIZE.
        CALL    QueueInit                 ; Note that TX_QUEUE_LENGTH should
                                          ; be less than the queue array size,
                                          ; and is ignored if less than the
                                          ; queue max size.
        
        RET

InitSerialVars  ENDP


; SerialSendString(char* string) 
; 
; Description:       Sends the null terminated string in SI through the serial by 
;                    calling SerialPutChar. Since SerialPutChar is not guaranteed 
;                    to succeed, calls SerialPutChar repeatedly for each character
;                    until SerialPutChar succeeds.
; Operation:         Iterate through each character in the string and call
;                    SerialPutChar repeatedly on that character until it works.
;                    Stop when the ASCII_NULL character is reached.
;
; Arguments:         string (SI) - start address of a character ASCII string
;                                  to send through the serial.
; Return Value:      None.
;
; Local Variables:   index (BX) - index in the string.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   String - null terminated character (byte) array.   
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AL, BX, CX.
; Special notes:     None.
SerialSendString    PROC     NEAR
                    PUBLIC   SerialSendString
				
        XOR     BX, BX          ; Start with first character (index = 0).

SerialSendStringLoop:
        XOR     CL, CL          ; Prepare inner loop index CL = 0 to
                                ; retry SerialPutChar if it fails.
        MOV     AL, SI[BX]      ; Get current character in string.
        MOV     CH, AL          ; Save a copy in CH since AX may be used
                                ; to call EnqueueEvent.
        
SerialSendStringResendChar:
        CALL    SerialPutChar   ; Try to send it to serial.
        JNC     SerialSendStringEndLoop ; CF is reset if serial put char was
                                ; successful and reset otherwise. No error
                                ; if CF is reset, so skip enqueuing an error.
        INC     CL              ; update inner loop index CL
        CMP     CL, 5           ; end when CL = 5 (do up to 5 times)
        JNE     SerialSendStringResendChar ; Loop if CL < 5. 
        ;JE     SerialSendStringError
        
SerialSendStringError:
        MOV     AH, SERIAL_ERROR_EVENT  ; Encode serial error event type
        MOV     AL, SIZE_ERROR_TABLE    ; Use index value of end of table
                                        ; to denote a serial send string error.
        CALL    EnqueueEvent            ; Enqueue error event.
        
SerialSendStringEndLoop:
        INC     BX              ; Update index to next character.
        CMP     CH, ASCII_NULL  ; Check if at end of string by looking for NULL.
        JNE     SerialSendStringLoop ; If not at end, continue looping.
        ;JE     EndSerialSendString              

EndSerialSendString:
        
        RET

SerialSendString    ENDP

; HandleSerial
; 
; Description:       Handles serial chip interrupts which include, None, receiver 
;                    line status, received data available, transmitter holding
;                    register empty, and modem status interrupts. 
;                    Calls helper functions for each case using a switch table.
;                    Note this should be installed as a INT 2 interupt handler
;                    in the IVT.
; Operation:         First checks INT_IDENT_REG (IIR) for the interrupt type:
;                    Then calls HandleModem, HandleEmptyTransmitter, 
;                    HandleSerialData, or HandleSerialError depending on the case.                  
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   iir_val (AL) - value of IIR.
;                    index (BX) - used to access the HandleSerialTable.
;                    
;                    
; Shared Variables:  Writes to kickstart - which determines if the serial chip
;                                          needs to be kickstarted.
; Global Variables:  None.
;
; Input:             Serial chip - causes interrupts and has the value of the
;                                  current interrupt in the IIR.
; Output:            Serial chip - writes to various registers to handle
;                                  interrupts. See the TL16C450 data sheet for
;                                  details.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   txQueue, eventQueue to hold events and pending characters
;                    to send. These are queueSTRUC<>s defined in queue.inc. 
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: None (event handler).
; Special notes:     None.
HandleSerial    PROC     NEAR
                PUBLIC   HandleSerial
                
        PUSHA       ; Save interrupted code's registers.
        
HandleSerialLoop:
        MOV    DX, INT_IDENT_REG    ; Read in the INT_IDENT_REG to
        IN     AL, DX               ; check what kind of interrupt it is
        
        CMP    AL, NONE_INTERRUPT   ; If none interrupt, do nothing,  
        JE     EndHandleSerialLoop  ; and return.
        ;JNE   HandelSerialSwitch

HandelSerialSwitch:
        XOR    AH, AH                  ; Otherwise, use the interrupt
                                       ; value which is conveniently a multiple
        MOV    BX, AX                  ; of two into an index in the HandleSerialTable
        CALL   HandleSerialTable[BX]   ; which contains a function to call
                                       ; in each case (this is word table so
                                       ; the numbers work out perfectly to
                                       ; just use as indices).
                                       
        JMP    HandleSerialLoop        ; Repeat until NONE_INTERRUPT.
        
EndHandleSerialLoop:
        MOV     DX, INTCtrlrEOI ;send an INT 2 EOI (to clear out controller)
        MOV     AX, INT2EOI
        OUT     DX, AL
        
		POPA        ; Restore interrupted code's registers.
        IRET

HandleSerial    ENDP



; SerialPutChar(c)
; 
; Description:       Outputs the passed character (AL) to the serial channel by
;                    enqueuing it into the txQueue. The event handler dequeues
;                    character from the txQueue to send them through the serial.
;                    Calling this function signals that there is something
;                    that needs to be sent, so it will kickstart the serial
;                    if the kickstart shared variable has been set by the 
;                    serial handler.
;                        
; Operation:         First checks if the queue is full. If is not full, then calls 
;                    Enqueue with the passed character, and kickstarts iff
;                    the kickstart is set, finally reseting the CF. If the queue 
;                    is full, clears the CF.
;
; Arguments:         c (AL) - character to send to the serial channel.
; Return Value:      Resets the carry flag iff the character has been output.
;
; Local Variables:   None.
; Shared Variables:  Read/writes kickstart - boolean that determines kickstarting.
; Global Variables:  None.
;
; Input:             Serial chip - read from IER to perserve its value.
; Output:            Serial chip - writes to IER to kickstart. 
;                                  See the TL16C450 data sheet for details.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   txQueue, which is a queueStruc<> defined in queue.inc.
;                    This keeps track of all outgoing characters.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, SI, AX, DX.
; Special notes:     This function contains critical code from the accessing
;                    the txQueue and the kickstart shared variable that
;                    the event handler also interacts with.
SerialPutChar   PROC     NEAR
                PUBLIC   SerialPutChar
				
        
CheckTxQueueFull:        	
        MOV     SI, OFFSET(txQueue)  ; Check the txQueue
        CALL    QueueFull            ; to see if it is full.
        JZ      TxQueueFull
        ;JNZ    TxQueueNotFull
        
TxQueueNotFull:
        CALL    Enqueue              ; If it is not full, enqueue the char
        ;JMP    CheckKickStart       ; and check the kickstart. 
		
CheckKickstart:
        CMP     kickstart, TRUE      ; Check we need to kickstart the serial
        JNE     SPCClearCF           ; (because it only triggers once to be
        ;JE     KickstartSerial      ; efficient).
        
KickstartSerial:
        MOV     kickstart, FALSE     ; If kickstart is TRUE, set it to FALSE.
                                     ; We do this first to avoid critical code
                                     ; that could happen if the THRE INT occurs
                                     ; right after you kickstart (and before
                                     ; you set kickstart FALSE).
        
        MOV     DX, INT_ENABLE_REG   ; Disable the THRE interrupt
        IN      AL, DX               ; by writing to the interrupt enable
        AND     AL, DISABLE_THRE_INT ; register on the serial chip.
        OUT     DX, AL
        
        OR      AL, ENABLE_THRE_INT  ; Enable the THRE interrupt after
        OUT     DX, AL               ; disabling it to kickstart the serial.
        ;JMP    SPCClearCF

SPCClearCF:
        CLC                          ; reset the CF to show the caller that
                                     ; the char was enqueued.
        JMP     EndSerialPutChar
        
TxQueueFull:
        STC                          ; If it is full, set the CF to show the
        ;JMP    EndSerialPutChar     ; caller that the char was not enqueued.


        
EndSerialPutChar:
        
        RET

SerialPutChar   ENDP



; SetSerialBaudRate(rate)
; 
; Description:       Sets the baud divisor in the serial chip using the
;                    SetSerialDivisor function after calculating the divisor
;                    value using division. Truncates the divisor to the nearest
;                    integer. Note that the baud rate must not be 0, or there
;                    will be a division error.
; Operation:         Compute baud divisor = BAUD_CLOCK_FACTOR / rate.
;                    then call SetSerialDivisor to set the baud divisor on the
;                    chip.
;
; Arguments:         rate (BX) - desired baud rate.
; Return Value:      None.
;
; Local Variables:   temp (AX) - used for division.
;                    upper_byte (DX) - used for division.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Writes to the divisor registers in the serial chip.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       Baud rate must not be 0.
;
; Registers Changed: flags, AX, BX, DX.
; Special notes:     None.
SetSerialBaudRate   PROC     NEAR
                    PUBLIC   SetSerialBaudRate
                    
        MOV     DX, BAUD_CLOCK_TOP_WORD  ; Load DX for word division.
        MOV     AX, BAUD_CLOCK_BOT_WORD  ; Compute the divisor by dividing the
        DIV     BX                       ; clock factor by the baud rate. This
        CALL    SetSerialDivisor         ; divisor is used by serial.
        
        RET

SetSerialBaudRate   ENDP


; ToggleParity()
; 
; Description:       Toggles the parity from NO_PARITY (default), to
;                    EVEN_PARITY, ODD_PARITY, EVEN_STICK_PARITY, and
;                    ODD_STICK_PARITY (and back to NO_PARITY).
;                    
; Operation:         Increment the parity value MOD NUM_PARITY_OPTIONS.
;                    Then, change the parity setting using the SetParity function
;                    defined in the initSeri module.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Read/write to parity - index of parity setting in parity table.
; Global Variables:  None.
;
; Input:             Reads from the line control register in the serial chip.
; Output:            Writes to the line control register in the serial chip.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   parityTable - a table of parity bit patterns.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, BX.
; Special notes:     None.
ToggleParity    PROC     NEAR
                PUBLIC   ToggleParity
        
        INC     parity                  ; Move to the next parity setting.
        MOV     AL, parity              ; Prepare to divide 
        XOR     AH, AH                  ; parity + 1 by NUM_PARITY_OPTIONS
        MOV     BL, NUM_PARITY_OPTIONS  ; to compute parity + 1
        DIV     BL                      ; MOD NUM_PARITY_OPTIONS
        MOV     parity, AH              ; Update parity variable to
                                        ; the new parity setting.
        
        XOR     BH, BH                  ; Clear top byte of index to ParityTable  
        MOV     BL, parity              ; Read the parity pattern from 
        MOV     AH, ParityTable[BX]     ; the table and call SetParity to
        CALL    SetParity               ; configure LCR.
        
        RET

ToggleParity       ENDP


; HandleSerialError()
; 
; Description:       Handles a receiver line status interrupt, which corresponds
;                    to an error by enqueuing an SERIAL_ERROR_EVENT containing
;                    the error status into the event queue.
; Operation:         Encodes the SERIAL_ERROR_EVENT to the top byte
;                    of the event and the LINE_STATUS_REG value into the lower
;                    byte of the event.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   event (AX) - event to enqueue.
;                    index (BX) - which error to process.
; Shared Variables:  Writes to the eventQueue - which contains system events.
; Global Variables:  None.
;
; Input:             Serial Chip - reads from the LSR to determine the errors.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   eventQueue, which is a queueSTRUC<> described in
;                    queue.inc that keeps track of all the events in the system.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, BX, CL, DX.
; Special notes:     None.
HandleSerialError     PROC     NEAR

        MOV     DX, LINE_STATUS_REG      ; Read in the LSR to determine
        IN      AL, DX                   ; which errors occurred.
        MOV     CL, AL                   ; Save a copy in CL to restore later.

HandleSerialErrorLoopInit:       
        XOR     BX, BX                   ; Loop through all the possible errors
                                         ; in the table.
        
HandleSerialErrorLoop:
        MOV     AL, SerialErrorTable[BX] ; For each error, check for the
        AND     AL, CL                   ; corresponding error bit.
        JZ      CheckHSELoop             
        ;JNZ    EnqueueErrorEvent
        
EnqueueErrorEvent:
        MOV     AH, SERIAL_ERROR_EVENT   ; Enqueue an error event for each
        MOV     AL, BL                   ; error that contains the specific
        CALL    EnqueueEvent             ; error bit in AL. Encode the index
                                         ; (BL) as the error event data to
                                         ; make for easy switch statements.
  
CheckHSELoop: 
        INC     BX                       ; Loop through all possible errors.
        CMP     BX, SIZE_ERROR_TABLE
        JB      HandleSerialErrorLoop
        ;JAE    EndHandelSerialError
        
EndHandelSerialError:        
        
        RET     

HandleSerialError     ENDP



; HandleEmptyTransmitter()
; 
; Description:       Handles a transmitter register empty interrupt by checking
;                    txQueue, and writing the dequeued value to the Transmitter
;                    Holding Register if txQueue is not empty.
; Operation:         First checks if txQueue is empty. If it is not empty,
;                    dequeues and writes that value to the Transmitter Holding
;                    Register.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             None.
; Output:            Serial Chip - writes to the TRANSMITTER_BUFFER to send
;                                  data.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   txQueue, which is a queueSTRUC<> defined in queue.inc.
;                    This keeps track of all outgoing characters.      
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, SI, AL, DX.
; Special notes:     None.
HandleEmptyTransmitter     PROC     NEAR
        
        MOV     SI, OFFSET(txQueue)    ; Check if the transmission queue is
        CALL    QueueEmpty             ; empty to avoid blocking in a EvtHandler.
        JZ      SignalKickstart
        ;JNZ    LoadTransmission
        
LoadTransmission:
        CALL    Dequeue                   ; If txQueue is not empty, dequeue
        MOV     DX, TRANSMITTER_BUFFER    ; and move the
        OUT     DX, AL                    ; next character into the serial transmitter.
		
		JMP     EndHandleEmptyTransmitter
        
SignalKickstart:
        MOV     kickstart, TRUE           ; Otherwise, signal that we will
        ;JMP    EndHandleEmptyTransmitter ; need to kickstart to reset the
                                          ; interrupt.

EndHandleEmptyTransmitter:

        RET     

HandleEmptyTransmitter     ENDP



; HandleSerialData()
; 
; Description:       Handles a received data available interrupt, by enqueuing 
;                    an SERIAL_DATA_EVENT into the event queue. 
; Operation:         Encodes the SERIAL_DATA_EVENT to the top byte
;                    of the event and the RECIEVER_BUFFER value into the lower
;                    byte of the event.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   event (AX) - event to enqueue.
; Shared Variables:  Writes to the eventQueue - which contains system events.
; Global Variables:  None.
;
; Input:             Serial Chip - reads from the RECEIVER_BUFFER.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   eventQueue, which is a queueSTRUC<> described in
;                    queue.inc that keeps track of all events in the system.
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags, AX, DX.
; Special notes:     None.
HandleSerialData     PROC     NEAR

        MOV     DX, RECIEVER_BUFFER   ; Read the buffer, which resets
        IN      AL, DX                ; the interrupt.
        
        MOV     AH, SERIAL_DATA_EVENT ; Encode the event type SERIAL_DATA_EVENT.
        CALL    EnqueueEvent          ; Enqueue the event.
        
        RET     

HandleSerialData     ENDP



; HandleModem()
; 
; Description:       Handles a modem interrupt by reading the modem status
;                    register.
;                    This is a placeholder function in the switch table.       
; Operation:         Handles a modem interrupt by reading the modem
;                    status register.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
; Global Variables:  None.
;
; Input:             Serial Chip - reads from the MSR to determine modem status.
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
; Registers Changed: flags, AL, DX.
; Special notes:     None.
HandleModem     PROC     NEAR
        
        MOV     DX, MODEM_STATUS_REG ; Reads the status to
        IN      AL, DX               ; reset the interrupt.
        RET     

HandleModem     ENDP

CODE    ENDS


; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    kickstart    DB     ?       ; Boolean that determines whether the serial
                                ; chip should be kickstarted.
    parity       DB     ?       ; Determines which parity state to read from
                                ; the parity table.
    txQueue      queueSTRUC<>   ; Transmission queue. This is a byte queue that
                                ; holds characters that need to be send through
                                ; the serial unit. It acts as a buffer to hold
                                ; data since the serial can only hold and send
                                ; one byte at a time.
    
DATA    ENDS
 
 
        END 