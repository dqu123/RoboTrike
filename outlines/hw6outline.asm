;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;                                HW6 Outline                                   ;
;                                 David Qu                                     ;
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

; Local functions:
; None.

; Motor details:
; The RoboTrike has three motors, equally spaced out in a circle. These 
; motors have the force vectors [1, 0], [-1/2, -Sqrt[3]/2], [-1/2, Sqrt[3]/2]. 
; By combining the force vectors of the motors, a resultant velocity vector with
; the desired speed and direction can be computed. Likewise, the required
; individual velocities for each motor can be calculated from an overall 
; velocity, as detailed in SetMotorSpeed().

; Constants 

; General constants
TRUE                EQU     1   ; Boolean true value.
FALSE               EQU     0   ; Boolean false value.

; Motor constants
NUM_MOTORS          EQU     3     ; Total number of motors
FORCE_SIZE          EQU     4     ; Number of bytes in each force entry. (2 bytes
                                  ; per component).
FORCE_SHIFT         EQU     2     ; Amount to shift to convert from a force index
                                  ; to a byte index in the MotorForceTable.
                                  ; = log_2(FORCE_SIZE).
X_COORD_OFFSET      EQU     0     ; Offset in MotorForceTable to access F_x.    
Y_COORD_OFFSET      EQU     2     ; Offset in MotorForceTable to access F_y.
SPEED_SIZE          EQU     2     ; Number of bytes in each speed entry.
SPEED_SHIFT         EQU     1     ; = log_2(SPEED_SIZE)
MAX_SPEED_COUNT     EQU     128   ; Number of counts to wait before reseting to 0.
MAX_TOTAL_SPEED     EQU     65534 ; Maximum total speed of the RoboTrike on a
                                  ; dimensionless scale (see total_speed).
NO_SPEED_CHANGE     EQU     MAX_TOTAL_SPEED + 1 ; Indicates no change in speed.
NO_ANGLE_CHANGE     EQU     -32768; Indicates no change in angle
MIN_ANGLE_CHANGE    EQU     NO_ANGLE_CHANGE + 1 ; Lowest valid angle change.
MAX_ANGLE_CHANGE    EQU     32767 ; Maximum valid angle change.
MOTOR_CLOCK_RATE    EQU     2304  ; Timer clocks to count between each interrupt. 



; Read-only tables
MotorForceTable   LABEL   BYTE
                  PUBLIC  MotorForceTable

        DW      07FFFH    ; F_1x              
        DW      00000H    ; F_1y
        DW      0C000H    ; F_2x
        DW      09127H    ; F_2y
        DW      0C000H    ; F_3x
        DW      06ED9H    ; F_3y

; Shared variables.
DATA    SEGMENT PUBLIC  'DATA'
    
    motor_count     DW  ?   ; timer for setting the motor speeds via pulse width
                            ; modulation (PWM).
    total_speed     DW  ?   ; desired total speed of RoboTrike. This is measured
                            ; on a unitless scale from 0 to MAX_TOTAL_SPEED 
                            ; because there is no feedback mechanism to determine
                            ; actual speed in the system.
    angle           DW  ?   ; desired angle of RoboTrike in degrees.
    laserOn         DB  ?   ; boolean whether the laser is on.
    speed_array     DW  NUM_MOTORS  DUP (?) ; speeds for each motor.

    
DATA    ENDS

; HandleMotors
; 
; Description: Rotates the three motors according to the speed_array shared
;              variable to produce holonomic motion. Increments motor_count MOD
;              MAX_SPEED for Pulse Width Modulation (PWM). Must be set up as
;              a Timer Event Handler to work properly.
;    
; Operation:   Rotates each motor according to its speed by Pulse Width Modulation
;              (PWM). This is done by comparing the motor_count to the speed,
;              and only rotating the motor if motor_count <= its speed.
;              Finally, increments motor_count MOD MAX_SPEED_COUNT.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   i (BX) - index variable.
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
;
; Pseudo code:
; for (unsigned word i = 0; i < NUM_MOTORS, i++)
;     if (speed_array[i] == 0 or motor_count > abs(speed_array[i]))
;         MotorTable[i].stop()
;     else
;         if (speed_array[i] > 0)
;             MotorTable[i].rotateForward()
;         else 
;             MotorTable[i].rotateBackward()
; motor_count = (motor_count + 1) mod MAX_SPEED_COUNT


; InitMotors
; 
; Description:       Initializes motor shared variables. motor_count is set to 0,
;                    total_speed is set to 0, angle is set to 0, 
;                    laserOn is set to FALSE, and the speed_array is 0-ed.
;
; Operation:         Sets total_speed = 0, angle = 0, laserOn = FALSE, and
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
; Limitations:       None.
;
; Registers Changed: flags, BX.
; Special notes:     None.
;
; Pseudo code:
; motor_count = 0
; total_speed = 0
; angle = 0
; laserOn = FALSE
; for (unsigned word i = 0; i < NUM_MOTORS; i++)
;     speed_array[i] = 0


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
; Arguments:         speed (AX), angle (BX).
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
;
; Pseudo code:
; if speed != NO_SPEED_CHANGE
;     total_speed = speed
; if angle != NO_ANGLE_CHANGE
;     motor.angle = angle MOD 360.
; for (unsigned word i = 0; i < NUM_MOTORS; i++)
;     speed_array[i] = MotorForceTable[i + X_COORD_OFFSET] * total_speed * 
;       cos(motor.angle) + MotorForceTable[i + Y_COORD_OFFSET] * total_speed *
;       sin(motor.angle)


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
;
; Pseudo code:
; return total_speed


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
;
; Pseudo code:
; return angle 


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
;
; Pseudo code:
; laserOn = onoff 


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
;
; Pseudo code: 
; return laserOn 