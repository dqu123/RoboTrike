;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  initSeri.INC                              ;
;                       TL16C450 Serial Chip Initialization                  ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definitions for the initSeri module, which contains
; the general purpose initialization function for the TL16C450 Serial Chip.
;
; Revision History:
;	 11/19/15  David Qu			initial revision

; Addresses of registers
SERIAL_BASE         EQU     100H            ; Base address for serial chip
RECIEVER_BUFFER     EQU     SERIAL_BASE + 0 ; Receiver Buffer Register
TRANSMITTER_BUFFER  EQU     SERIAL_BASE + 0 ; Transmitter Holding Register
INT_ENABLE_REG      EQU     SERIAL_BASE + 1 ; Interrupt Enable Register
INT_IDENT_REG       EQU     SERIAL_BASE + 2 ; Interupt Ident. Register
LINE_CTRL_REG       EQU     SERIAL_BASE + 3 ; Line Control Register
MODEM_CTRL_REG      EQU     SERIAL_BASE + 4 ; Modem Control Register
LINE_STATUS_REG     EQU     SERIAL_BASE + 5 ; Line Status Register
MODEM_STATUS_REG    EQU     SERIAL_BASE + 6 ; Modem Status Register
SCRATCH_REG         EQU     SERIAL_BASE + 7 ; Scratch Register
DIVISOR_LATCH       EQU     SERIAL_BASE + 0 ; Divisor Latch (LSB)
LATCH_MSB           EQU     SERIAL_BASE + 1 ; Latch (MSB)

; Register values
; Interrupt Enable Register (IER) values
ENABLE_RDA_INT      EQU     00000001b ; -------1 enables received data available
                                      ;          interrupt when OR-ed with the IER. 
DISABLE_RDA_INT     EQU     NOT ENABLE_RDA_INT ; disables RDA interrupts when
                                               ; AND-ed with the IER.
ENABLE_THRE_INT     EQU     00000010b ; ------1- enables transmitter holding
                                      ;          register empty interrupt
                                      ; when OR-ed with the IER.
DISABLE_THRE_INT    EQU     NOT ENABLE_THRE_INT ; disables THRE interrupt
                                                ; when AND-ed with the IER.
ENABLE_RLS_INT      EQU     00000100b ; -----1-- enables receiver line status interrupt
DISABLE_RLS_INT     EQU     NOT ENABLE_RLS_INT ; disables RLS interrupts when
                                               ; AND-ed with the IER.
ENABLE_MODEM_INT    EQU     00001000b ; ----1--- enables modem status interrupt
DISABLE_MODEM_INT   EQU     NOT ENABLE_MODEM_INT ; disables modem interrupts
                                                 ; when AND-ed with the IER.

ENABLE_SERIAL_INT   EQU     00001111b ; Enables all interrupts
                                      ; 0000---- Unused (always zero)
                                      ; ----1--- Enable Modem Status Interrupt
                                      ; -----1-- Enable Receiver Line Status
                                      ; ------1- Enable Transmitter Holding 
                                      ;          Register Empty Interrupt
                                      ; -------1 Enable Received Data Available
                                      ;          Interrupt
DISABLE_SERIAL_INT  EQU     00000000b ; Disables all interrupts.
                                      ; 0000---- Unused (always zero)
                                      ; ----0--- Disable Modem Status Interrupt
                                      ; -----0-- Disable Receiver Line Status
                                      ; ------0- Disable Transmitter Holding 
                                      ;          Register Empty Interrupt
                                      ; -------0 Disable Received Data Available
                                      ;          Interrupt

; Interupt Ident. Register values (Shows type of interrupt).
NONE_INTERRUPT      EQU    001b    ; No interrupt.
LINE_STATUS_INT     EQU    110b    ; Line status interrupt
RECEIVED_DATA_INT   EQU    100b    ; Received data interrupt.
TRANSMITTER_EMPTY_INT EQU  010b    ; Transmitter empty interrupt.
MODEM_STATUS_INT    EQU    000b    ; Modem status interrupt.


; Divisor Latch (Baud rate)
INIT_BAUD_RATE      EQU     600    ; Default baud rate.
INIT_BAUD_DIVISOR   EQU     192    ; = BAUD_CLOCK_FACTOR / INIT_BAUD_RATE
                                   ; See Table 7 on page 22 of the TL 16C450
                                   ; manual for more details on this relation.  
BAUD_CLOCK_FACTOR   EQU     1152000; BAUD_CLOCK_FACTOR is determined by
                                   ; the clock frequency. In this case, we
                                   ; are using a 18.432 MHz crystal. We divide
                                   ; this rate by 16 because the serial produces
                                   ; a 16 * clock. i.e. 1152000 = 18,432,000 / 16
                                   ; However this is more than 16 bits, so we
                                   ; need to split into top word and bottom word.
BAUD_CLOCK_TOP_WORD EQU     00011H ; 1152000 = 119400H, so we have to break
BAUD_CLOCK_BOT_WORD EQU     09400H ; this into two words.


; Line Control Register (LCR)
LCR_CHAR_WORD_MASK  EQU     00000011b ; mask for the LCR character word size.
CHAR_WORD_LENGTH_5  EQU     00000000b ; ------00 5 + 0 character word length
CHAR_WORD_LENGTH_6  EQU     00000001b ; ------01 5 + 1 character word length
CHAR_WORD_LENGTH_7  EQU     00000010b ; ------10 5 + 2 character word length
CHAR_WORD_LENGTH_8  EQU     00000011b ; ------11 5 + 3 character word length

LCR_STOP_BIT_MASK   EQU     00000100b ; mask for extra stop bit.
EXTRA_STOP_BIT      EQU     00000100b ; -----1-- Sets extra stop bit for lengths
                                      ; 6, 7, 8, and an extra 1/2 stop bit for
                                      ; a word length of 5.
NO_EXTRA_STOP_BIT   EQU     00000000b ; clears extra stop bit.

LCR_PARITY_MASK     EQU     00111000b ; mask for parity bits 
NO_PARITY           EQU     00000000b ; no parity value
EVEN_PARITY         EQU     00011000b ; even parity value
ODD_PARITY          EQU     00001000b ; odd parity value
EVEN_STICK_PARITY   EQU     00111000b ; even stick parity value
ODD_STICK_PARITY    EQU     00101000b ; odd stick parity value           

LCR_BREAK_MASK      EQU     01000000b ; mask for LCR break bit.                                               
LCR_BREAK           EQU     01000000b ; -1------ Sets the break control bit.
NO_LCR_BREAK        EQU     00000000b ; Disables the break condition.
                                          
LCR_LATCH_MASK      EQU     10000000b ; mask for LCR divisor latch bit.
ENABLE_DIVISOR_LATCH EQU    10000000b ; 1------- Enables the divisor latch.
                                      ; Note that this must be set to access
                                      ; the DIVISOR_LATCH and LATCH_MSB, and
                                      ; must be reset to access the
NO_DIVISOR_LATCH    EQU     00000000b ; Disables the divisor latch

                                                     
INIT_LCR            EQU     01000011b ; Default line control register value.
                                      ; ------11 8 bit words
                                      ; -----0-- no extra stop bit
                                      ; --000--- no parity
                                      ; -1------ LCR break bit set.
                                      ; 0------- Disable divisor latch.
                                      
; Line Status Register (LSR)
DATA_READY_BIT      EQU     00000001b ; bit for data ready
OVERRUN_BIT         EQU     00000010b ; bit for overrun error
PARITY_ERROR_BIT    EQU     00000100b ; bit for parity error
FRAMING_ERROR_BIT   EQU     00001000b ; bit for framing error
BREAK_INT_BIT       EQU     00010000b ; bit for break interrupt
THRE_BIT            EQU     00100000b ; bit for transmitter holding register
TEMT_BIT            EQU     01000000b ; bit for transmitter empty

; Modem Status Register (MSR)
DCTS_BIT            EQU     00000001b ; bit for delta clear to send
DDSR_BIT            EQU     00000010b ; bit for delta data set ready
TERI_BIT            EQU     00000100b ; bit for trailing edge ring indicator
DDCD_BIT            EQU     00001000b ; bit for delta data carrier detect
CTS_BIT             EQU     00010000b ; bit for clear to send
DSR_BIT             EQU     00100000b ; bit for data set ready
RI_BIT              EQU     01000000b ; bit for ring indicator
DCD_BIT             EQU     10000000b ; bit for data carrier detect
