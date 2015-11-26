; Time efficient code

; Inputs 
;   Characters   Input Class    Value
;      0 - 9        digit       0 - 9    (next digit in value)
;     + and -       sign        +1, -1   (sign of value)
;     S and s       S_CMD          0      (sets absolute speed)
;     V and v       V_CMD          0      (sets relative speed)
;     D and d       D_CMD          0      (sets direction)
;     T and t       T_CMD          0      (rotates turret)
;     E and e       E_CMD          0      (changes turret elevation)
;     F and f       LASER_CMD     TRUE   (fires laser)
;     O and o       LASER_CMD     FALSE  (turns laser off)
;     <Return>      endCmd        13     (this is the ASCII decimal 13 or CR that
;                                         signals the end of a command).
;    all others     other         character (original character value for debugging)
;
; Outputs/Actions
;   Actions       Description                           Implementing function
;   setCommand    reset vars and set command to use     SetCommand()
;   addDigit      increases the value shared variable   AddDigit()
;   setSign       sets the sign shared variable         SetSign()
;   doCommand     perform command                       DoCommand()
;   error         set return shared var to PARSER_ERROR SetError()
;       
; States
;   State         Description
;   InitialState  initial/default state
;   READ_S        just read s
;   READ_V
;   READ_D
;   READ_T
;   READ_E
;   READ_LASER
;   SIGN_S
;   SIGN_V
;   SIGN_D 
;   SIGN_T
;   SIGN_E
;   DIGIT_S
;   DIGIT_V 
;   DIGIT_D
;   DIGIT_T
;   DIGIT_E
;   
;   ResetState    wait until next valid command and then reset shared variables. 
;
; State Transition Table
;                                   Current Input
;   Current State     digit       sign       S_CMD   V_CMD  D_CMD   T_CMD   E_CMD  LASER_CMD  endCmd    other*  
;   ResetState     ResetState   ResetState  READ_S  READ_V  READ_D  READ_T  READ_E READ_LASER ResetState ResetState    
;                       e           e       Init      Init   Init    Init    Init                        
;   READ_S         ResetState