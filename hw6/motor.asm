        NAME    MOTOR
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                  MOTOR                                       ;
;                             Motor Functions                                  ;
;                                 EE/CS 51                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 

; Public functions:
; HandleMotors()             - Rotate motors according to the speed_array.
; InitMotors()               - Initializes motor shared variables.
; SetMotorSpeed(speed,angle) - Compute the values of the speed_array.
; GetMotorSpeed()            - Return the overall speed of the RoboTrike.
; GetMotorDirection()        - Return the direction of the RoboTrike.
; SetLaser(onoff)            - Sets the laser on or off.
; GetLaser()                 - Return the status of the laser.
;
; Local functions:
; None.
;
; Revision History:
; 		11/12/15  David Qu		initial revision.



; Motor details:
; The RoboTrike has three motors, equally spaced out in a circle. These 
; motors have the force vectors [1, 0], [-1/2, -Sqrt[3]/2], [-1/2, Sqrt[3]/2]. 
; By combining the force vectors of the motors, a resultant velocity vector with
; the desired speed and direction can be computed. Likewise, the required
; individual velocities for each motor can be calculated from an overall 
; velocity, as detailed in SetMotorSpeed().

; local include files
$INCLUDE(motor.INC)
$INCLUDE(eoi.INC)
$INCLUDE(general.INC)

CGROUP	GROUP	CODE 


CODE 	SEGMENT PUBLIC 'CODE'


		ASSUME 	CS:CGROUP, DS:DATA
        
        EXTRN 	Sin_table:NEAR  ; Table to compute Sin(a) where a is in degrees
        EXTRN 	Cos_table:NEAR  ; Table to compute Cos(a) where a is in degrees
        
        
; Read-only tables
MotorForceXTable    LABEL   WORD               ; Q0.15 value for motor force
                    PUBLIC  MotorForceXTable   ; in the x direction.

        DW      07FFFH    ; F_1x              
        DW      0C000H    ; F_2x
        DW      0C000H    ; F_3x

MotorForceYTable    LABEL   WORD               ; Q0.15 value for motor force
                    PUBLIC  MotorForceYTable   ; in the y direction.
        DW      00000H    ; F_1y
        DW      09127H    ; F_2y
        DW      06ED9H    ; F_3y
        
  
RotateForwardTable  LABEL   BYTE               ; Bit patterns for rotating
                    PUBLIC  RotateForwardTable ; motor i forward.
        DB      00000010b    ; Motor 1
        DB      00001000b    ; Motor 2
        DB      00100000b    ; Motor 3

RotateBackwardTable LABEL   BYTE                ; Bit patterns for rotating
                    PUBLIC  RotateBackwardTable ; motor i backward.
        DB      00000011b    ; Motor 1
        DB      00001100b    ; Motor 2
        DB      00110000b    ; Motor 3

StopTable           LABEL   BYTE                ; Bit patterns for stopping
                    PUBLIC  StopTable ; motor i.
        DB      00000000b    ; Motor 1
        DB      00000000b    ; Motor 2
        DB      00000000b    ; Motor 3

        
; HandleMotors
; 
; Description: Rotates the three motors according to the speed_array shared
;              variable to produce holonomic motion. Increments motor_count MOD
;              MAX_SPEED for Pulse Width Modulation (PWM).
;    
; Operation:   Rotates each motor according to its speed by Pulse Width Modulation
;              (PWM). This is done by comparing the motor_count to the speed,
;              and only rotating the motor if motor_count <= its speed.
;              Finally, increments motor_count MOD MAX_SPEED_COUNT.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   output (AL) - bits to write to the 82A55C chip.
;                    i (BX) - index variable.
; Shared Variables:  Reads from speed_array - byte array of individual motor speeds.
;                    Write to motor_count - count of timer ticks for PWM.
; Global Variables:  None.
;
; Input:             None.
; Output:            Moves RoboTrike motors using parallel output.
;
; Error Handling:    None.
;
; Algorithms:        None.
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       Assumes motor shared variables have been properly initialized.
;                    Assumes MAX_SPEED_COUNT is a power of 2 to perform MOD using
;                    bitwise AND (MAX_SPEED_COUNT - 1).
;
; Registers Changed: flags, BX.
; Special notes:     None.

HandleMotors    PROC    NEAR
                PUBLIC  HandleMotors

StartHandleMotors:
        PUSHA
        XOR     AX, AX
        XOR     BX, BX

CheckLaser:
        CMP      laserOn, FALSE             ; Check if the laser is on,
        JE       HandleMotorsLoop           ; and the laser fire bit pattern
        ;JNE     FireLaser                  ; if it is.
 
FireLaser:
        OR      AL, LaserOnVAl              ; Add the laser fire bit pattern
                                            ; to AL.
                
HandleMotorsLoop:
        MOV     CL, BYTE PTR speed_array[BX]
        CMP     CL, 0                       ; Determine the sign of the speed.
        JG      PositiveSpeed               ; If positive compare to motor_count directly.
        JE      StopMotor                   ; If 0, stop the motor.
        JL      NegativeSpeed               ; If negative, negate the speed and
                                            ; then compare to the motor_count.

PositiveSpeed:
        CMP     motor_count, CL             ; If speed is positive,
        JG      StopMotor
        OR      AL, RotateForwardTable[BX]
        JMP     EndHandleMotorsLoop
        
NegativeSpeed:
        NEG     CL                          ;
        CMP     motor_count, CL
        JG      StopMotor
        OR      AL, RotateBackwardTable[BX]
        JMP     EndHandleMotorsLoop
        
StopMotor:
        OR      AL, StopTable[BX]
        ;JMP    EndHandleMotorsLoop
        
EndHandleMotorsLoop:
        INC     BX                          ; Update motor index.
        CMP     BX, NUM_MOTORS              ; Stop looping when done with all
        JL      HandleMotorsLoop            ; motors.
        ;JGE    UpdateMotors

UpdateMotors:
        MOV     DX, PeriphChipPortB         ; Write bitpattern to PortB in the       
        OUT     DX, AL                      ; Peripheral Chip.

UpdateMotorCount:
        INC     motor_count                      ; Update the motor_count
        AND     motor_count, MAX_SPEED_COUNT - 1 ; MOD MAX_SPEED_COUNT.

EndHandleMotors:                    ;done taking care of the timer
        MOV     DX, INTCtrlrEOI     ;send the EOI to the interrupt controller
        MOV     AX, TimerEOI
        OUT     DX, AL

        POPA		                ;restore the registers


        IRET                ;and return (Event Handlers end with IRET not RET)    

HandleMotors    ENDP



; InitMotors
; 
; Description:       Configures the 82C55A peripheral chip, which controls
;                    the motors. This activates the chip as an output chip. 
;                    Initializes motor shared variables:
;                    motor_count is set to 0, total_speed is set to 0, 
;                    angle is set to 0, laserOn is set to FALSE, and the 
;                    speed_array is 0-ed. This ensures that the motors all
;                    start at rest, the default angle is in the x direction,
;                    and the laser is initially off
;
; Operation:         Outputs PeriphChipVal to the PeriphCtrlChip. 
;                    Sets total_speed = 0, angle = 0, laserOn = FALSE, and
;                    speed_array[i] = 0.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   i (BX) - index variable.
; Shared Variables:  Writes to motor_count - timer counter for the motors.
;                              total_speed - overall speed for the RoboTrike.
;                              angle - angle to move the RoboTrike, counter-
;                                      clockwise from the x-axis.
;                              laserOn - boolean determining laser state.
;                              speed_array - byte array of individual motor speeds.
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
; Limitations:       Assumes the Chip Select has been initialized so the PeriphCtrlChip
;                    can be written to properly.
;
; Registers Changed: flags, BX.
; Special notes:     None.

InitMotors      PROC    NEAR
                PUBLIC  InitMotors

        MOV     motor_count, 0
        MOV     total_speed, 0
        MOV     angle, 0
        MOV     laserOn, FALSE
        
        XOR     BX, BX

InitMotorsLoop:
        MOV     speed_array[BX], 0
        INC     BX
        CMP     BX, NUM_MOTORS
        JL      InitMotorsLoop
        ;JGE    EndInitMotors

InitPeriphChip:
        MOV     DX, PeriphChipCtrl
        MOV     AL, PeriphChipVal
        OUT     DX, AL

EndInitMotors:
        RET

InitMotors      ENDP



; SetMotorSpeed
; 
; Description:       Sets the NUM_MOTORS motors' speeds in the speed_array based
;                    on the passed total speed (AX), and angle (BX). The passed 
;                    speed ranges from 0 to MAX_TOTAL_SPEED, and can be set to 
;                    NO_SPEED_CHANGE if only angle needs to be changed. The 
;                    angle ranges from MIN_ANGLE_CHANGE to MAX_ANGLE_CHANGE,
;                    can be set to NO_ANGLE_CHANGE if only the speed needs
;                    to change. 
; Operation:         Updates total_speed and angle appropriately if they are
;                    not NO_SPEED_CHANGE nor NO_ANGLE_CHANGE, and then
;                    computes the corresponding NUM_MOTORS motor speeds in
;                    the speed_array using trigonometry from a table, and
;                    the MotorForceTable.
;
; Arguments:         speed (AX), new_angle (BX).
; Return Value:      None.
;
; Local Variables:   i (CX) - index variable.
; Shared Variables:  Writes to total_speed - overall speed for the RoboTrike.
;                              angle - angle to move the RoboTrike, counter-
;                                      clockwise from the x-axis.
;                              speed_array - byte array of individual motor speeds.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    None.
;
; Algorithms:        Computes each individual motor speed by using its force
;                    vector relative to the overall RoboTrike motor set up.
;                    speed_i = F_ix * v * cos(angle) + F_iy * v * sin(angle).
; Data Structures:   None.    
;
; Known Bugs:        None.
; Limitations:       None.
;
; Registers Changed: flags.
; Special notes:     None.

SetMotorSpeed      PROC     NEAR
                   PUBLIC   SetMotorSpeed

        PUSHA   ; Save caller registers.

CheckSpeed:
        CMP     AX, NO_SPEED_CHANGE     ; Check if the speed needs to be
        ;JNE      SetTotalSpeed         ; set. If speed == NO_SPEED_CHANGE,
        JE     CheckAngle               ; then it is ignored.
        
SetTotalSpeed:
        SHR     AX, POSITIVE_Q0_15_SHIFT; Convert from a word unsigned speed to
                                        ; a positive Q0.15 value.
        MOV     total_speed, AX         ; Sets the total_speed shared variable
        ;JMP    CheckAngle              ; to the given value.

CheckAngle:
        CMP     BX, NO_ANGLE_CHANGE     ; Check if the angle needs to be set.
        ;JME    SetTotalAngle         ; If new_angle == NO_ANGLE_CHANGE,
        JE     SetMotorSpeedLoop       ; then it is ignored.
        
SetTotalAngle:
        MOV     AX, BX                  ; Sets the angle shared variable to
        MOV     BX, CIRCLE_DEGREES      ; the new_angle MOD CIRCLE_DEGREES, 
        CWD                             ; making sure set a value between 0
        IDIV    BX                      ; and CIRCLE_DEGREES.
         
        CMP     DX, 0                   ; Check if remainder is negative MOD
        JGE     UpdateAngle             ; CIRCLE_DEGREES. If it is, add CIRCLE_DEGREES
        ;JL     MakePositiveMod         ; to make the result positive.
        
MakePositiveMod:
        ADD     DX, CIRCLE_DEGREES      ; Adss CIRCLE_DEGREES to a negative
                                        ; angle to make it positive.

UpdateAngle:
        MOV     angle, DX               ; Sets angle to the computed value.
        ;JMP    CheckAngle

        XOR     BX, BX                 ; Clear index variable for loop.
SetMotorSpeedLoop:
        MOV     AX, total_speed        ; Prepare to compute 
        MOV     SI, angle              ; Compute byte index in trig tables to   
        SHL     SI, TRIG_TABLE_SHIFT   ; compute cos(a) and sin(a).
        
        XOR     DX, DX                 ; Clear DX for IMUL.
        SHL     BX, FORCE_SHIFT        ; Convert from motor index to byte index
                                       ; in force tables (which are word tables).
        IMUL    MotorForceXTable[BX]   ; Compute F_xi * s as a Q0.30
        MOV     AX, DX                 ; Move top byte of result to AX to chain multiply.
                                       ; This truncates to a Q0.14.
        XOR     DX, DX                 ; Clear DX for IMUL.
        IMUL    WORD PTR Cos_table[SI] ; Store value of F_xi * s * cos(a),
        MOV     CX, DX                 ; the x contribution of the i-th motor's 
                                       ; speed in CX as a Q0.13.
        
        MOV     AX, total_speed        ; Prepare to compute F_yi * s * sin(a)
        XOR     DX, DX                 ; Clear DX for IMUL.
        IMUL    MotorForceYTable[BX]   ; Compute F_yi * s as a Q0.30
        SHR     BX, FORCE_SHIFT        ; Convert back to motor index from byte index
                                       ; in force tables (which are word tables).
        MOV     AX, DX                 ; Move top byte of result to AX to chain multiply.
                                       ; This truncates to a Q0.14.
        XOR     DX, DX                 ; Clear DX for IMUL.
        IMUL    WORD PTR Sin_table[SI] ; Compute F_yi * s * sin(a), the y 
                                       ; contribution of the i-th motor's velocity
                                       ; in DX as a Q0.13.
  
        ADD     CX, DX                 ; Add the x and y contributions to get
                                       ; the total speed as a Q0.13.
ConvertFromFixedPoint:
        SAL     CX, FIXED_POINT_SHIFT  ; Convert from a Q0.13 (3 repeated sign
                                       ; bits due to 2 multiplications) to 
                                       ; an integer with SPEED_PRECISION bits
                                       ; of precision. This leaves a valid
                                       ; word in CH.
        
UpdateSpeedArray:
        MOV     speed_array[BX], CH    ; Updated speed_array with new speed.
        
        INC     BX                     ; Increment index, moving to the next motor.
        CMP     BX, NUM_MOTORS         ; Check if all motors have been done.
        JL      SetMotorSpeedLoop      ; Loop if not done.
        ;JGE    EndSetMotorSpeed
        
EndSetMotorSpeed:
        POPA           ; Restore caller registers.
        RET

SetMotorSpeed      ENDP



; GetMotorSpeed
; 
; Description:       Gets the total motor speed. This speed is on a unitless
;                    scale from 0 to MAX_TOTAL_SPEED.
; Operation:         Read from the total_speed shared variable into AX.
;
; Arguments:         None.
; Return Value:      total_speed (AX).
;
; Local Variables:   None.
; Shared Variables:  Reads total_speed - overall speed for the RoboTrike.
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
; Registers Changed: flags, AX.
; Special notes:     None.

GetMotorSpeed      PROC     NEAR
                   PUBLIC   GetMotorSpeed

        MOV     AX, total_speed ; Gets total_speed.
        RET

GetMotorSpeed      ENDP



; GetMotorDirection
; 
; Description:       Gets the direction of the RoboTrike in degrees from 0 to 360.    
; Operation:         Read from the angle shared variable into AX.
;
; Arguments:         None.
; Return Value:      angle (AX).
;
; Local Variables:   None.
; Shared Variables:  Reads angle - angle to move the RoboTrike, counter-
;                                  clockwise from the x-axis.
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
; Registers Changed: flags, AX.
; Special notes:     None.
 
GetMotorDirection  PROC     NEAR
                   PUBLIC   GetMotorDirection

        MOV     AX, angle   ; Sets angle.
        RET

GetMotorDirection  ENDP



; SetLaser
; 
; Description:       Sets the boolean laserOn shared variable to the value
;                    passed in AX. This variable determines when the laser
;                    should be fired.
; Operation:         Sets laserOn = onoff (AX).
;
; Arguments:         onoff(AX) - boolean determining when laser should be fired.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  Writes to laserOn - boolean determining laser state.
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
; Registers Changed: flags, AX.
; Special notes:     None.

SetLaser        PROC     NEAR
                PUBLIC   SetLaser

        MOV     laserOn, AL  ; Sets laserOn.
        RET

SetLaser        ENDP



; GetLaser
; 
; Description:       Gets the value of the boolean laserOn.
; Operation:         Returns laserOn in AX.
;
; Arguments:         None.
; Return Value:      laserOn (AX).
;
; Local Variables:   None.
; Shared Variables:  Reads laserOn - boolean determining laser state.
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
; Registers Changed: flags, AX.
; Special notes:     None.
 
GetLaser        PROC     NEAR
                PUBLIC   GetLaser

        XOR     AH, AH       ; Clear high byte of return value.
        MOV     AL, laserOn  ; Write low byte of return value (laserOn is a byte
                             ; but the functional specification says to return
                             ; in AX, a word).
        RET

GetLaser        ENDP



CODE    ENDS



; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    
    motor_count     DB  ?   ; timer for setting the motor speeds via pulse width
                            ; modulation (PWM).
    total_speed     DW  ?   ; desired total speed of RoboTrike. This is measured
                            ; on a unitless scale from 0 to MAX_TOTAL_SPEED 
                            ; because there is no feedback mechanism to determine
                            ; actual speed in the system.
    angle           DW  ?   ; desired angle of RoboTrike in degrees.
    laserOn         DB  ?   ; boolean whether the laser is on.
    speed_array     DB  NUM_MOTORS  DUP (?) ; speeds for each motor.

    
DATA    ENDS
 
 
        END 