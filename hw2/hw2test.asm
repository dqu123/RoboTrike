        NAME    HW2TEST

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                            ;
;                                   HW2TEST                                  ;
;                            Homework #2 Test Code                           ;
;                                  EE/CS  51                                 ;
;                                                                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Description:      This program tests the conversion functions for Homework
;                   #2.  It calls each conversion function with a number of
;                   test values.  If all tests pass it jumps to the label
;                   AllTestsGood.  If any test fails it jumps to the label
;                   TestFailed.
;
; Input:            None.
; Output:           None.
;
; User Interface:   No real user interface.  The user can set breakpoints at
;                   AllTestsGood and TestFailed to see if the code is working
;                   or not.
; Error Handling:   If a test fails the program jumps to TestFailed.
;
; Algorithms:       None.
; Data Structures:  None.
;
; Known Bugs:       None.
; Limitations:      The returned strings must be less than MAX_STRING_SIZE
;                   characters.
;
; Revision History:
;    1/24/06  Glen George               initial revision
;    1/26/06  Glen George               fixed a minor bug
;                                       allow lowercase hex digits
;                                       removed DUPs
;    1/22/07  Glen George               updated comments
;    9/29/10  Glen George               updated comments to indicate it is now
;                                          for Homework #2



;definitions

MAX_STRING_SIZE EQU     20              ;maximum string buffer size
ASCII_NULL      EQU     0               ;string termination character (<null>)




CGROUP  GROUP   CODE
DGROUP  GROUP   DATA, STACK



CODE    SEGMENT PUBLIC 'CODE'


        ASSUME  CS:CGROUP, DS:DGROUP



;external function declarations

        EXTRN   Dec2String:NEAR         ;convert a number to a decimal string
        EXTRN   Hex2String:NEAR         ;convert a number to a hex string




START:  

MAIN:
        MOV     AX, DGROUP              ;initialize the stack pointer
        MOV     SS, AX
        MOV     SP, OFFSET(DGROUP:TopOfStack)

        MOV     AX, DGROUP              ;initialize the data segment
        MOV     DS, AX


        CALL    ConvertTest             ;do the conversion tests
        JCXZ    AllTestsGood            ;go to appropriate infinite loop
        ;JMP    TestFailed              ;  based on return value


TestFailed:                             ;a test failed
        JMP     TestFailed              ;just sit here until get interrupted


AllTestsGood:                           ;all tests passed
        JMP     AllTestsGood            ;just sit here until get interrupted




; ConvertTest
;
; Description:       This procedure does the conversion tests.  It repeatedly
;                    calls the conversion functions with values from a table
;                    and then checks the results, also against table values.
;                    If there is a failure in a test the function returns with
;                    the failed test number in CX.  If all tests pass the
;                    function returns 0 in CX.
;
; Operation:         The string buffer is first filled with a known pattern.
;                    Next the conversion function is called with a value from
;                    the test table.  After it returns the buffer contents are
;                    checked against the table entry and if it matches, the
;                    next test is done.  Otherwise the code returns with the
;                    number of the test that failed in CX.
;
; Arguments:         None.
; Return Value:      CX - number of the failed test, zero (0) if all tests
;                         passed.
;
; Local Variables:   CX - test number.
; Shared Variables:  StringOut - filled with the converted strings.
; Global Variables:  None.
;
; Input:             None.
; Output:            None.
;
; Error Handling:    If there is an error in the conversion functions the
;                    number of the test that failed is returned in CX.
;
; Algorithms:        None.
; Data Structures:   None.
;
; Registers Changed: flags, AX, BX, CX, DX, DI, SI
; Stack Depth:       unknown
;
; Author:            Glen George
; Last Modified:     Jan. 24, 2006

ConvertTest     PROC        NEAR
                PUBLIC      ConvertTest


ConvertTestInit:

        MOV     CX, 0                   ;start with the first test

ConvertTestLoop:                        ;loop doing tests

        CALL    FillBuffer              ;fill the buffer with a known value

        MOV     SI, OFFSET(StringOut)   ;get the buffer address for the call
        IMUL    BX, CX, TESTCASE_SIZE   ;get the offset for this test case
        MOV     DX, 07FFFH              ;keep DX non-zero to test DIV issues
        MOV     AX, CS:Tests[BX + VALUE];get value for test
        PUSH    CX                      ;don't trash the test number

HexTest:                                ;convert the number to a hex string
        CALL    Hex2String

        POP     CX                      ;get test number back
        CALL    CheckHexStr             ;check the converted string

        JNZ     ConvertTestFailed       ;if the test failed - done
        ;JZ     CheckDecimal            ;otherwise test OK, try decimal next

CheckDecimal:                           ;check decimal conversion

        CALL    FillBuffer              ;fill the buffer with a known value

        MOV     SI, OFFSET(StringOut)   ;get the buffer address for the call
        IMUL    BX, CX, TESTCASE_SIZE   ;get the offset for this test case
        MOV     DX, 07FFFH              ;keep DX non-zero to test DIV issues
        MOV     AX, CS:Tests[BX + VALUE];get value for test
        PUSH    CX                      ;don't trash the test number

DecimalTest:                            ;convert the number to a decimal string
        CALL    Dec2String

        POP     CX                      ;get test number back
        CALL    CheckDecStr             ;check the converted string

        JNZ     ConvertTestFailed       ;if the test failed - done
        ;JZ     DoNextTest              ;otherwise test OK, try next value


DoNextTest:                             ;do the next test
        INC     CX
        CMP     CX, NUM_TESTS           ;check if there are any more tests
        JL      ConvertTestLoop         ;have more tests to do - do them
        ;JGE    ConvertTestPassed       ;else done with tests - everything passed


ConvertTestPassed:                      ;all conversion tests passed
        MOV     CX, 0                   ;so set return value to 0
        JMP     ConvertTestDone         ;and done


ConvertTestFailed:                      ;the test failed
        INC     CX                      ;adjust CX (return value) to 1-based
        ;JMP    ConvertTestDone         ;  failed test number and done


ConvertTestDone:                        ;done with the conversion tests
                                        ;return with the status
        RET


ConvertTest     ENDP




; CheckHexStr
;
; Description:       This procedure checks if the hex string in the buffer
;                    matches the expected hex string for this test.  Leading
;                    zeros or spaces are ignored in the hex string.  If the
;                    strings match the zero flag is set.  If they don't match
;                    the zero flag is reset.
;
; Operation:         The procedure first skips all leading spaces then zeros
;                    in the converted string, except the last one.  Then the
;                    remaining characters are checked against the expected
;                    string up to and including the <null> character.  Lastly
;                    the buffer is checked to be sure nothing else was
;                    overwritten (it still has FF's in it).
;
; Arguments:         CX - test number
; Return Value:      ZF - set if the strings match, reset otherwise.
;
; Local Variables:   SI - pointer into the buffer.
;                    DI - pointer into the expected string.
; Shared Variables:  StringOut - checked against the expected string.
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
; Registers Changed: flags, AL, BX, DI, SI
; Stack Depth:       1 word
;
; Author:            Glen George
; Last Modified:     Jan. 26, 2006

CheckHexStr     PROC        NEAR


CheckHexStrInit:

        MOV     SI, 0                   ;start with the first byte of buffer
        IMUL    BX, CX, TESTCASE_SIZE   ;get the test case entry
        LEA     DI, Tests[BX + HEXSTR]  ;get start of hex string into DI for comparisons

HexSkipLeading:                         ;skip leading spaces and zeros
        CALL    SkipSpaces              ;skip leading spaces
        CALL    SkipZeros               ;skip leading zeros

        CMP     SI, MAX_STRING_SIZE     ;check if past end of string
        JAE     HexCheckFail            ;nothing must be in buffer - test fails
        ;JB     HexCheckValue           ;otherwise check value in buffer


HexCheckValue:                          ;check if buffer value is correct
	CALL    Str2UC			;convert string to uppercase
        CALL    CheckStr		;now check the value
        JMP     CheckHexStrDone         ;all done - return with zero flag


HexCheckFail:                           ;test failed
        OR      AL, 0FFH                ;reset the zero flag
        ;JMP    CheckHexStrDone         ;and done


CheckHexStrDone:                        ;all done - just return with zero flag

        RET


CheckHexStr     ENDP




; CheckDecStr
;
; Description:       This procedure checks if the decimal string in the buffer
;                    matches the expected hex string for this test.  Leading
;                    spaces are ignored in the decimal string.  Leading zeros
;                    are ignored either before or after the sign (but not
;                    both).  A single leading positive sign is also ignored.
;                    If the strings match the zero flag is set.  If they don't
;                    match the zero flag is reset.
;
; Operation:         The procedure first skips all leading spaces.  It then
;                    checks for a sign and skips a plus sign or matching minus
;                    sign (if it matches the expected string).  Next it skips
;                    any zeros up to, but not including, the last zero.  Then
;                    the remaining characters are checked against the expected
;                    string up to and including the <null> character.  Lastly
;                    the buffer is checked to be sure nothing else was
;                    overwritten (it still has FF's in it).
;
; Arguments:         CX - test number
; Return Value:      ZF - set if the strings match, reset otherwise.
;
; Local Variables:   SI - pointer into the buffer.
;                    DI - pointer into the expected string.
; Shared Variables:  StringOut - checked against the expected string.
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
; Registers Changed: flags, AL, BX, DI, SI
; Stack Depth:       1 word
;
; Author:            Glen George
; Last Modified:     Jan. 24, 2006

CheckDecStr     PROC        NEAR


CheckDecStrInit:

        MOV     SI, 0                   ;start with the first byte of buffer
        IMUL    BX, CX, TESTCASE_SIZE   ;get the test case entry
        LEA     DI, Tests[BX + DECSTR]  ;get start of decimal string into DI for comparisons

DecSkipLeading:                         ;skip leading spaces and zeros
        CALL    SkipSpaces              ;skip leading spaces
        CMP     SI, MAX_STRING_SIZE     ;be sure not past end of string
        JAE     DecCheckFail            ;nothing left in buffer - test fails

        CMP     StringOut[SI], '+'      ;check for leading positive sign
        JE      DoSkipSign              ;if have it, skip the sign
        CMP     StringOut[SI], '-'      ;check for leading minus sign
        JNE     DecSkipZeros            ;none, so try to skip zeros
        CMP     BYTE PTR CS:[DI], '-'   ;otherwise see if match the buffer
        JNE     DecCheckFail            ;doesn't match, test fails
        ;JE     DoSkipMinusSign         ;otherwise skip the signs

DoSkipMinusSign:                        ;skip the sign
        INC     SI                      ;in the buffer
        INC     DI                      ;and the matching string
        JMP     DecSkipZeros            ;and now can skip zeros

DoSkipSign:                             ;skip the leading positive sign
        INC     SI
        ;JMP    DecSkipZeros            ;and can skip zeros once get '+' sign

DecSkipZeros:                           ;skip leading spaces and zeros
        CMP     BYTE PTR CS:[DI], '-'   ;first be sure not expecting a sign
        JE      DecCheckFail            ;if we were - didn't get it in the right place
        CALL    SkipSpaces              ;otherwise skip spaces then zeros
        CALL    SkipZeros               ;   after the sign
        CMP     SI, MAX_STRING_SIZE     ;be sure not past end of string
        JAE     DecCheckFail            ;nothing left in buffer - test fails
        ;JB     DecCheckValue           ;otherwise check the value


DecCheckValue:                          ;check if buffer value is correct
        CALL    CheckStr
        JMP     CheckDecStrDone         ;all done - return with zero flag


DecCheckFail:                           ;test failed
        OR      AL, 0FFH                ;reset the zero flag
        ;JMP    CheckDecStrDone         ;and done


CheckDecStrDone:                        ;all done - just return with zero flag

        RET


CheckDecStr     ENDP




; SkipSpaces
;
; Description:       This procedure skips spaces in the string buffer starting
;                    at the passed location.
;
; Operation:         Skip spaces in the string until the end of the string or
;                    the end of the string buffer is reached.
;
; Arguments:         SI - offset of string in StringOut buffer where skipping
;                         is to start.
; Return Value:      SI - offset in StringOut buffer past skipped spaces or
;                         the buffer length if there is no <null> to end the
;                         string.
;
; Local Variables:   None.
; Shared Variables:  StringOut - read to skip spaces in this buffer.
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
; Registers Changed: flags, SI
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Jan. 24, 2006

SkipSpaces      PROC        NEAR


SkipSpaceLoop:                          ;loop, skipping spaces
        CMP     SI, MAX_STRING_SIZE     ;be sure not past end of string
        JAE     DoneSpaceSkipping       ;nothing left in buffer - return

        CMP     StringOut[SI], ' '      ;check for a space
        ;JE     DoSpaceSkip             ;if have it, skip it
        JNE     DoneSpaceSkipping       ;otherwise, done with skipping

DoSpaceSkip:                            ;skip the space
        INC     SI
        JMP     SkipSpaceLoop           ;and keep looking for more


DoneSpaceSkipping:                      ;done skipping spaces
                                        ;just return with SI skipped past spaces
        RET


SkipSpaces      ENDP




; SkipZeros
;
; Description:       This procedure skips zeros in the string buffer starting
;                    at the passed location.  The last zero in the string is
;                    not skipped.
;
; Operation:         Skip zeros until on last zero in the string or the end of
;                    the string or the end of the string buffer is reached.
;
; Arguments:         SI - offset of string in StringOut buffer where skipping
;                         is to start.
; Return Value:      SI - offset in StringOut buffer past skipped zeros or the
;                         buffer length if there is no <null> to end the
;                         string.
;
; Local Variables:   None.
; Shared Variables:  StringOut - read to skip zeros in this buffer.
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
; Registers Changed: flags, SI
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Jan. 24, 2006

SkipZeros       PROC        NEAR


SkipZeroLoop:                           ;loop, skipping zeros
        CMP     StringOut[SI + 1], ASCII_NULL  ;never skip last character
        JE      DoneZeroSkipping
        CMP     SI, MAX_STRING_SIZE     ;be sure not past end of string
        JAE     DoneZeroSkipping        ;nothing left in buffer - return

        CMP     StringOut[SI], '0'      ;check for a zero
        ;JE     DoZeroSkip              ;if have it, skip it
        JNE     DoneZeroSkipping        ;otherwise, done with skipping

DoZeroSkip:                             ;skip the zero
        INC     SI
        JMP     SkipZeroLoop            ;and keep looking for more


DoneZeroSkipping:                       ;done skipping zeros
                                        ;just return with SI skipped past zeros
        RET


SkipZeros       ENDP




; Str2UC
;
; Description:       This procedure converts the string stored in StringOut
;                    to uppercase.  The conversion is started at the position
;                    indicated by the passed argument.
;
; Operation:         Convert any lowercase characters to uppercase until the
;                    end of the string or the end of the string buffer is
;                    reached.
;
; Arguments:         SI - offset of string in StringOut buffer where the
;                         conversion to uppercase is to start.
; Return Value:      None.
;
; Local Variables:   None.
; Shared Variables:  StringOut - converted to uppercase.
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
; Registers Changed: flags
; Stack Depth:       1 word
;
; Author:            Glen George
; Last Modified:     Jan. 26, 2006

Str2UC          PROC        NEAR


	PUSH	SI			;don't trash SI

CvtUCLoop:                              ;loop, converting to uppercase
        CMP     StringOut[SI], ASCII_NULL  ;stop at the end of the string
        JE      DoneUCConversion
        CMP     SI, MAX_STRING_SIZE     ;be sure not past end of string
        JAE     DoneUCConversion        ;nothing left in buffer - return

        CMP     StringOut[SI], 'a'      ;check for a lowercase character
        JB      DoNextChar              ;if not, just go to the next character
	CMP	StringOut[SI], 'z'      ;and check end of lowercase range
        JA      DoNextChar              ;if past, go to the next character
	;JBE    HaveLowercase		;otherwise have a lowercase character

HaveLowercase:				;have lowercase
	ADD	StringOut[SI], 'A' - 'a';convert to uppercase
	;JMP	DoNextChar		;and move to next character

DoNextChar:				;move to the next character
        INC     SI
        JMP     CvtUCLoop               ;and keep converting


DoneUCConversion:                       ;done converting to uppercase
                                        ;restore SI and return
	POP	SI
        RET


Str2UC          ENDP




; CheckStr
;
; Description:       This procedure checks if the rest of the string in the
;                    buffer matches the expected string for this test.  If the
;                    strings match the zero flag is set.  If they don't match
;                    the zero flag is reset.  It is also verified that the
;                    buffer has not been written over by checking the rest of
;                    it for FF.
;
; Operation:         The procedure checks the buffer characters against the
;                    expected string up to and including the <null> character.
;                    Next the rest of the buffer is checked to be sure nothing
;                    else was overwritten (it still has FF's in it).
;
; Arguments:         SI - pointer into the StringOut buffer to be checked.
;                    CS:DI - pointer to the expected string.
; Return Value:      ZF - set if the strings match, reset otherwise.
;
; Local Variables:   None.
; Shared Variables:  StringOut - checked against the expected string.
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
; Registers Changed: flags, AL, SI, DI
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Jan. 24, 2006

CheckStr        PROC        NEAR


StrCheckLoop:                           ;check if buffer is correct
        MOV     AL, StringOut[SI]       ;get a byte from buffer
        CMP     AL, CS:[DI]             ;compare with expected value
        JNE     StrCheckFail            ;didn't match - test fails
        INC     SI                      ;else move to next character
        INC     DI
        CMP     AL, ASCII_NULL          ;was it a <null> that was just checked
        JNE     StrCheckLoop            ;if not keep checking
        ;JE     StrCheckFF              ;otherwise done comparing strings


StrCheckFF:                             ;now check if rest of buffer is unaffected
        CMP     SI, MAX_STRING_SIZE     ;check if at end of buffer
        JE      DoneStrCheckFF          ;if so - done with this check
        CMP     StringOut[SI], 0FFH     ;otherwise check for buffer still FF
        JNE     StrCheckFail            ;if not FF, check fails - overwrote buffer
        INC     SI                      ;otherwise go to next buffer byte
        JMP     StrCheckFF              ;and keep checking

DoneStrCheckFF:                         ;done checking for FF in rest of buffer
                                        ;this means all is well
        ;JMP    CheckStrDone            ;zero flag is already set - return


StrCheckFail:                           ;test failed (zero flag is reset) 
        ;JMP    CheckStrDone            ;all done - return


CheckStrDone:                           ;all done - just return with zero flag

        RET


CheckStr        ENDP




; FillBuffer
;
; Description:       This procedure fills the test buffer with the value FF.
;
; Operation:         The procedure loops, filling the test buffer byte by byte
;                    with the value FF.
;
; Arguments:         None.
; Return Value:      None.
;
; Local Variables:   SI - pointer into the buffer.
; Shared Variables:  StringOut - filled with FF.
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
; Registers Changed: flags, SI
; Stack Depth:       0 words
;
; Author:            Glen George
; Last Modified:     Jan. 24, 2006

FillBuffer      PROC        NEAR


FillBufferInit:

        MOV     SI, 0                   ;start with the first byte

FillLoop:                               ;loop filling the buffer
        MOV     StringOut[SI], 0FFH     ;fill buffer with FF
        INC     SI                      ;go to next location
        CMP     SI, MAX_STRING_SIZE     ;has whole buffer been filled ?
        JB      FillLoop                ;if not, keep looping
        ;JAE    FillBufferDone          ;otherwise all done filling buffer


FillBufferDone:                         ;done filling buffer, return

        RET


FillBuffer      ENDP




; Tests
;
; Description:      This is the table of tests for the conversion functions.
;                   Each entry is the value and the string expected from the
;                   hexadecimal conversion and the decimal conversion.  Note
;                   that leading zeros and positive signs are not included as
;                   those are optional in the implementation.
;
; Author:           Glen George
; Last Modified:    Jan. 26, 2006

Tests   LABEL   WORD

VALUE   EQU     $ - Tests               ;offset of value within entry

        DW      0                       ;value to test

HEXSTR  EQU     $ - Tests               ;offset of expected hex string

        DB      '0', ASCII_NULL         ;expected hex string
        DB      0FFH, 0FFH, 0FFH        ;padding to get to fixed length

DECSTR  EQU     $ - Tests               ;offset of expected decimal string

        DB      '0', ASCII_NULL         ;expected decimal string
        DB      0FFH, 0FFH, 0FFH, 0FFH, 0FFH  ;padding to get to fixed length

TESTCASE_SIZE   EQU     $ - Tests       ;size of a test case

        DW      0FFFFH                  ;test #2
        DB      'FFFF', ASCII_NULL
        DB      '-1', ASCII_NULL, 0FFH, 0FFH, 0FFH, 0FFH

        DW      9999                    ;test #3
        DB      '270F', ASCII_NULL
        DB      '9999', ASCII_NULL, 0FFH, 0FFH

        DW      10000                   ;test #4
        DB      '2710', ASCII_NULL
        DB      '10000', ASCII_NULL, 0FFH

        DW      32767                   ;test #5
        DB      '7FFF', ASCII_NULL
        DB      '32767', ASCII_NULL, 0FFH

        DW      -9999                   ;test #6
        DB      'D8F1', ASCII_NULL
        DB      '-9999', ASCII_NULL, 0FFH

        DW      -10000                  ;test #7
        DB      'D8F0', ASCII_NULL
        DB      '-10000', ASCII_NULL

        DW      -32768                  ;test #8
        DB      '8000', ASCII_NULL
        DB      '-32768', ASCII_NULL

        DW      9ABCH                   ;test #9
        DB      '9ABC', ASCII_NULL
        DB      '-25924', ASCII_NULL

        DW      14                      ;test #10
        DB      'E', ASCII_NULL, 0FFH, 0FFH, 0FFH
        DB      '14', ASCII_NULL, 0FFH, 0FFH, 0FFH, 0FFH

        DW      1                       ;test #11
        DB      '1', ASCII_NULL, 0FFH, 0FFH, 0FFH
        DB      '1', ASCII_NULL, 0FFH, 0FFH, 0FFH, 0FFH, 0FFH

        DW      2561                    ;test #12
        DB      'A01', ASCII_NULL, 0FFH
        DB      '2561', ASCII_NULL, 0FFH, 0FFH


NUM_TESTS       EQU     ($ - Tests) / TESTCASE_SIZE


CODE    ENDS




;the data segment

DATA    SEGMENT PUBLIC  'DATA'


StringOut       DB      MAX_STRING_SIZE  DUP (?) ;buffer for converted strings


DATA    ENDS




;the stack

STACK   SEGMENT STACK  'STACK'

                DB      80 DUP ('Stack ')       ;240 words

TopOfStack      LABEL   WORD

STACK   ENDS



        END     START
