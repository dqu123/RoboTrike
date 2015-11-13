;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                  motor.INC                                 ;
;                               RoboTrike Motors                             ;
;                                 Include File                               ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; This file contains the definition for the motor module, which contains
; functions to set up the 82A55C chip that controls the motors, and constants
; for the motor functions.
;
; Revision History:
;	 11/12/15  David Qu			initial revision

; Chip Select Unit Definitions

; Addresses
PeriphChip      EQU     180H            ;address of 82A55C peripheral chip.
PeriphChipPortB EQU     PeriphChip + 1  ;address of port B.
PeriphChipCtrl  EQU     PeriphChip + 3  ;address of Peripheral chip control register.

; Control Register Values
PeriphChipVal   EQU     80H             ;Value for 82A55C peripheral chip.
                                        ;1-------  Activates chip
                                        ;-00-----  GROUP A MODE 0
                                        ;---0----  Port A output mode
                                        ;----0---  Port C (Upper) output mode
                                        ;-----0--  GROUP B MODE 0
                                        ;------0-  Port B output mode
                                        ;-------0  Port C (Lower) output mode
                                        
LaserOnVal      EQU     10000000b       ;1------- Activates laser. 
                                        
; Trig constants
CIRCLE_DEGREES      EQU     360   ; Number of degrees in a circle.
TRIG_TABLE_SIZE     EQU     2     ; Size of trig table elements in bytes.  
TRIG_TABLE_SHIFT    EQU     1     ; Amount to shift to convert from an index of
                                  ; trig table elements to bytes.
POSITIVE_Q0_15_SHIFT EQU    1     ; Amount to shift to convert from a 16-bit
                                  ; unsigned integer to a positive Q0.15 value.
                                        
; Motor constants
NUM_MOTORS          EQU     3     ; Total number of motors
FORCE_SIZE          EQU     4     ; Number of bytes in each force entry. (2 bytes
                                  ; per component).
FORCE_SHIFT         EQU     2     ; Amount to shift to convert from a force index
                                  ; to a byte index in the MotorForceTable.
                                  ; = log_2(FORCE_SIZE).
SPEED_SIZE          EQU     2     ; Number of bytes in each speed entry.
SPEED_SHIFT         EQU     1     ; = log_2(SPEED_SIZE)
SPEED_PRECISION     EQU     8     ; Bits of precision, maximum is 8.
FIXED_POINT_SHIFT   EQU     10 - SPEED_PRECISION ; Amount to shift the fixed point
                                  ; values after 2 Q0.15 multiplications.
MAX_SPEED_COUNT     EQU     128   ; Number of counts to wait before reseting to 0.
                                  ; Should be 2^(SPEED_PRECISION - 1).
MAX_TOTAL_SPEED     EQU     65534 ; Maximum total speed of the RoboTrike on a
                                  ; dimensionless scale (see total_speed).
NO_SPEED_CHANGE     EQU     MAX_TOTAL_SPEED + 1 ; Indicates no change in speed.
NO_ANGLE_CHANGE     EQU     -32768; Indicates no change in angle
MIN_ANGLE_CHANGE    EQU     NO_ANGLE_CHANGE + 1 ; Lowest valid angle change.
MAX_ANGLE_CHANGE    EQU     32767 ; Maximum valid angle change. 
