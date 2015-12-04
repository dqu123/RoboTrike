        NAME   GENERAL
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  GENERAL                                     ;
;                             General Functions                                ;
;                                 EE/CS 51                                     ;
;                                 David Qu                                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; This file contains general purpose functions.
; 
; Public functions:
; DoNOP     - does nothing.
;
; Local functions:
; None.
;
;
; Revision History:
; 		12/3/15  David Qu		initial revision.


;local include files. 
$INCLUDE(general.inc)  ; general constants.

CGROUP	GROUP	CODE 

CODE 	SEGMENT PUBLIC 'CODE'
		ASSUME 	CS:CGROUP
        
; DoNOP()
; 
; Description:       Does nothing.
; Operation:         Does nothing.
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
DoNOP           PROC     NEAR
                PUBLIC   DoNOP
       
        RET     

DoNOP           ENDP

CODE    ENDS


 
 
        END 