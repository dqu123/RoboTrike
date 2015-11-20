;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                HW8 Outline                                   ;
;                                 David Qu                                     ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contain the functions to parse the next serial character as a part
; of a finite state machine (FSM). This FSM is meant to be run on the motor
; unit of the RoboTrike, and will call various motor functions in response to 
; commands in the RoboTrike Serial Command Format. An overview of the parser
; design with more details follows after the table of contents.
; 
; Public functions:
; ParseSerialChar(c)  - parse the passed character as part of a serial command. 
;
; Local functions:
; GetParserToken      - returns the token class and token value for the passed char.
;
; Read only tables:
; TokenTypeTable
; TokenValueTable
; StateTable

; Parser Design Overview:
; This parser is implemented as a Mealy Finite State Machine (FSM), because the
; characters received from the serial may have unknown transmission delays
; that divide up command strings. 

; ParseSerialChar(c)
; 
; Description:       
; Operation:         
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
; 
