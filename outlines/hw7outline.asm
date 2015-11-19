;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                HW7 Outline                                   ;
;                                 David Qu                                     ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; Public functions:
; InitSerialChip()        - initializes the serial chip.
; InitSerialVars()        - initializes serial shared variables.
; HandleSerial()          - handles serial interrupts.
; SerialPutChar(c)        - outputs a character to the serial channel.
; SetSerialBaudRate(rate) - sets the baud rate of the serial channel.
; EnableParity()          - enables parity checking.
; DisableParity()         - disables parity checking.
; SetEvenParity()         - sets the parity mode to even.
; SetOddParity()          - sets the parity mode to odd.
; SetLineCtrlReg(value)   - sets the value of the Line Control Register manually
;                           letting the programmer control all options. This
;                           makes the API robust, without including too many
;                           functions.
;
; Local functions:
; HandleSerialError()      - handles a serial error interrupt.
; HandleSerialData()       - handles a serial data interrupt.
; HandleEmptyTransmitter() - handles an empty transmitter interrupt.
; HandleModem()            - handles a modem interrupt. 


; Event Constants (in events.inc)
KEYPRESS_EVENT      EQU     0       ; Value for a keypress event. 
SERIAL_ERROR_EVENT  EQU     1       ; Value for a serial error event.
SERIAL_DATA_EVENT   EQU     2       ; Value for a serial data event.

; Serial Constants
; Addresses of registers
SERIAL_BASE         EQU     100H            ; Base address for serial chip
RECIEVER_BUFFER     EQU     SERIAL_BASE + 0 ; Receiver Buffer Register
TRANSMITTER_BUFFER  EQU     SERIAL_BASE + 1 ; Transmitter Holding Register
INT_ENABLE_REG      EQU     SERIAL_BASE + 2 ; Interrupt Enable Register
INT_IDENT_REG       EQU     SERIAL_BASE + 3 ; Interupt Ident. Register
LINE_CTRL_REG       EQU     SERIAL_BASE + 4 ; Line Control Register
MODEM_CTRL_REG      EQU     SERIAL_BASE + 5 ; Modem Control Register
LINE_STATUS_REG     EQU     SERIAL_BASE + 6 ; Line Status Register
MODEM_STATUS_REG    EQU     SERIAL_BASE + 7 ; Modem Status Register
SCRATCH_REG         EQU     SERIAL_BASE + 8 ; Scratch Register
DIVISOR_LATCH       EQU     SERIAL_BASE + 9 ; Divisor Latch (LSB)
LATCH_MSB           EQU     SERIAL_BASE + 10; Latch (MSB)

; Register values
; Interrupt Enable Register
ENABLE_SERIAL_INT   EQU     00001111b ; Enables interrupts
                                      ; 0000---- Unused (always zero)
                                      ; ----1--- Enable Modem Status Interrupt
                                      ; -----1-- Enable Receiver Line Status
                                      ; ------1- Enable Transmitter Holding 
                                      ;          Register Empty Interrupt
                                      ; -------1 Enable Received Data Available
                                      ;          Interrupt
DISABLE_SERIAL_INT  EQU     00000000b ; Disables interrupts.

; Line Status Register (Shows type of interrupt).
NONE_INTERRUPT      EQU    000b
LINE_STATUS_INT     EQU    110b
RECEIVED_DATA_INT   EQU    100b
TRANSMITTER_EMPTY_INT EQU  010b
MODEM_STATUS_INT    EQU    001b


; Divisor Latch (Baud rate)
INIT_BAUD_RATE      EQU     600    ; Default baud rate.
INIT_BAUD_DIVISOR   EQU     192    ; = BAUD_RATE_FACTOR / INIT_BAUD_RATE
                                   ; See Table 7 on page 22 of the TL 16C450
                                   ; manual for more details on this relation.
BAUD_RATE_FACTOR    EQU     115200 ; Divisor =  BAUD_RATE_FACTOR / baud_rate


; Line Control Register (LCR)
CHAR_WORD_LENGTH_5  EQU     00000000b ; ------00 5 + 0 character word length
CHAR_WORD_LENGTH_6  EQU     00000001b ; ------01 5 + 1 character word length
CHAR_WORD_LENGTH_7  EQU     00000010b ; ------10 5 + 2 character word length
CHAR_WORD_LENGTH_8  EQU     00000011b ; ------11 5 + 3 character word length

EXTRA_STOP_BIT      EQU     00000100b ; -----1-- Sets extra stop bit for lengths
                                      ; 6, 7, 8, and an extra 1/2 stop bit for
                                      ; a word length of 5.
NO_EXTRA_STOP_BIT   EQU     NOT EXTRA_STOP_BIT ; Clears the extra stop bit when
                                               ; AND-ed with the LCR.

ENABLE_PARITY       EQU     00001000b ; ----1--- Enables parity checking.
NO_PARITY           EQU     NOT ENABLE_PARITY ; Disables parity checking when
                                              ; AND-ed with the LCR.
EVEN_PARITY         EQU     00010000b ; ---1---- Even parity checking.
ODD_PARITY          EQU     NOT EVEN_PARITY ; Uses Odd parity checking when
                                            ; AND-ed with the LCR.

STICK_PARITY        EQU     00100000b ; --1----- Enables stick parity.
NO_STICK_PARITY     EQU     NOT STICK_PARITY ; Disables stick parity when OR-ed
                                             ; with the LCR.
LCR_BREAK           EQU     01000000b ; -1------ Sets the break control bit.
NO_LCR_BREAK        EQU     NOT LCR_BREAK ; Disables the break condition when
                                          ; AND-ed with the LCR.

ENABLE_DIVISOR_LATCH EQU    10000000b ; 1------- Enables the divisor latch.
NO_DIVISOR_LATCH    EQU     NOT ENABLE_DIVISOR_LATCH ; Disables the divisor latch
                                                     ; when AND-ed with the LCR.

INIT_LCR            EQU     CHAR_WORD_LENGTH_8 OR   ; Default settings for the
                            NO_EXTRA_STOP_BIT  OR   ; Line Control Register.
                            ENABLE_PARITY      OR 
                            EVEN_PARITY        OR
                            STICK_PARITY       OR
                            NO_LCR_BREAK       AND
                            NO_DIVISOR_LATCH

; external function declarations
        EXTRN   QueueInit:NEAR          ; Initializes queue.
        EXTRN   QueueEmpty:NEAR         ; Checks if queue is empty. 
		EXTRN	QueueFull:NEAR			; Checks if queue is full. 
		EXTRN	Dequeue:NEAR			; Removes element from queue. 
		EXTRN	Enqueue:NEAR			; Adds element to queue.                           
                            
; Read-only tables
HandleSerialTable LABEL   WORD
                  PUBLIC  HandleSerialTable

        DW      OFFSET(HandleModem)             ; Table of functions for
        DW      OFFSET(HandleEmptyTransmitter)  ; the switch statement in 
        DW      OFFSET(HandleSerialData)        ; HandleSerial()
        DW      OFFSET(HandleSerialError)

; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    
    lineCtrlReg     DB  ?   ; Value for the Line Control Register.
    baudDivisor     DW  ?   ; Divisor that determines baud rate.
    txQueue		queueSTRUC<>; Transmission queue.
    
DATA    ENDS


; InitSerialChip()
; 
; Description:       Initializes the serial chip, enabling its interrupts,
;                    and setting it to its default baud rate of INIT_BAUD_RATE,
;                    and configuring 8 character words, no extra stop bit,
;                    parity checking, stick parity, clearing the break bit,
;                    and enabling the divisor latch.   
; Operation:         Sets the Interrupt Enable Register to ENABLE_SERIAL_INT,
;                    the Line Control Register to INIT_LCR, 
;                    the Divisor Latch to the LSB of INIT_BAUD_DIVISOR,
;                    and the Latch to the MSB of INIT_BAUD_DIVISOR.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   temp (AX) - holds the INIT_BAUD_DIVISOR value to control
;                                where the MSB and LSB go.
; Shared Variables:  None.
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
; Limitations:       Assumes the peripheral chip select has been initialized
;                    properly.
;
; Registers Changed: flags.
; Special notes:     None, AX.
;
; Pseudo code:
; *INT_ENABLE_REG = ENABLE_SERIAL_INT
; *LINE_CTRL_REG = INIT_LCR
; AX = INIT_BAUD_DIVISOR
; *DIVISOR_LATCH = AL
; *LATCH_MSB = AH


; InitSerialVars()
; 
; Description:       Initializes serial shared variables. Sets baudDivisor to
;                    INIT_BAUD_DIVISOR, lineCtrlReg to INIT_LCR, and initializes
;                    the txQueue.
; Operation:         Sets baudDivisor = INIT_BAUD_DIVISOR, 
;                    lineCtrlReg = INIT_LCR, and calls InitQueue() to initialize
;                    the transmission queue.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to baudDivisor - variable that determines the baud rate.
;                              lineCtrlReg - variable that determines the LCR value.
;                              txQueue     - queue of transmission data to send.
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
;
; Pseudo code:
; baudDivisor = INIT_BAUD_DIVISOR
; lineCtrlReg = INIT_LCR
; InitQueue(a=txQueue, length=MAX_QUEUE_SIZE, size=bytes)

 
; HandleSerial
; 
; Description:       Handles serial chip interrupts which include, None, receiver 
;                    line status, received data available, transmitter holding
;                    register empty, and modem status interrupts. 
;                    Calls helper functions for each case using a switch table.
; Operation:         First checks INT_IDENT_REG (IIR) for the interrupt type:
;                    Then calls HandleModem, HandleEmptyTransmitter, 
;                    HandleSerialData, or HandleSerialError depending on the case.                  
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Reads from baudDivisor - variable that determines the baud rate.
;                               lineCtrlReg - variable that determines the LCR value.
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
;
; Pseudo code:
; save_flags()
;
; AX = BAUD_RATE_FACTOR / baudRate
; *DIVISOR_LATCH = AL
; *LATCH_MSB = AH
; *LINE_CTRL_REG = lineCtrlReg
; switch (*INT_IDENT_REG)
; case MODEM_STATUS_INT: 
;     HandleModem()
;     break
; case TRANSMITTER_EMPTY_INT:
;     HandleEmptyTransmitter()
;     break
; case RECEIVED_DATA_INT:
;     HandleSerialData()
;     break
; case LINE_STATUS_INT:
;     HandleSerialError()
;     break
;
; pop_flags()
; IRET


; SerialPutChar(c)
; 
; Description:       Outputs the passed character (AL) to the serial channel.    
; Operation:         Calls Enqueue with the passed character.
;
; Arguments:         c (AL) - character to send to the serial channel.
; Return Value:      Resets the carry flag iff the character has been output.
;
; Local Variables:   None.
; Shared Variables:  None.
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
;
; Pseudo code:
; if not QueueFull(txQueue)
;     Enqueue(c)
;     resetCF() ; CLC
; else
;     setCF()   ; STC


; SetSerialBaudRate(rate)
; 
; Description:       Sets the baudDivisor shared variable based on the baud
;                    rate passed in AX.
; Operation:         Sets baudDivisor = BAUD_RATE_FACTOR / rate.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   temp (BX) - used for division.
; Shared Variables:  Writes to baudDivisor - variable that determines the baud rate.
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
; Registers Changed: flags, AX, BX, DX
; Special notes:     None.
; Pseudo code:
; baudDivisor = BAUD_RATE_FACTOR / rate


; EnableParity()
; 
; Description:       Enables parity on the serial by writing to the lineCtrlReg
;                    shared variable.
; Operation:         ORs in the ENABLE_PARITY bit pattern to the lineCtrlReg.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to lineCtrlReg - variable that determines the LCR value.
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
; 
; Pseudo code:
; lineCtrlReg |= ENABLE_PARITY


; DisableParity()
; 
; Description:       Disables parity on the serial by writing to the lineCtrlReg
;                    shared variable.
; Operation:         ORs in the NO_PARITY bit pattern to the lineCtrlReg.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to lineCtrlReg - variable that determines the LCR value.
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
; 
; Pseudo code:
; lineCtrlReg |= NO_PARITY


; SetEvenParity()
; 
; Description:       Sets even parity on the serial by writing to the lineCtrlReg
;                    shared variable.
; Operation:         ORs in the EVEN_PARITY bit pattern to the lineCtrlReg.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to lineCtrlReg - variable that determines the LCR value.
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
; 
; Pseudo code:
; lineCtrlReg |= EVEN_PARITY


; SetOddParity()
; 
; Description:       Sets odd parity on the serial by writing to the lineCtrlReg
;                    shared variable.
; Operation:         ORs in the ODD_PARITY bit pattern to the lineCtrlReg.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to lineCtrlReg - variable that determines the LCR value.
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
; 
; Pseudo code:
; lineCtrlReg |= ODD_PARITY


; SetLineCtrlReg(value)
; 
; Description:       Writes the passed value in AL to the lineCtrlReg
;                    shared variable.
; Operation:         Sets lineCtrlReg = AL.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to lineCtrlReg - variable that determines the LCR value.
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
; 
; Pseudo code:
; lineCtrlReg = value (AL)


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
; Shared Variables:  Writes to the eventQueue - which contains system events.
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
; Pseudo code:
; unsigned word event = SERIAL_ERROR_EVENT, *LINE_STATUS_REG
; EnqueueEvent(event)


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
; Pseudo code:
; if not QueueEmpty(txQueue)


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
; Pseudo code:
; unsigned word event = SERIAL_DATA_EVENT, *RECIEVER_BUFFER
; Enqueue(event)


; HandleModem()
; 
; Description:       Handles a modem interrupt by doing nothing.
;                    This is a placeholder function in the switch table.       
; Operation:         Handles a modem interrupt by doing nothing.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  None.
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
; Registers Changed: None.
; Special notes:     None.
;
; Pseudo code:
; return