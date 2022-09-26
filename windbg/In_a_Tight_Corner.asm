TITLE Final Project	(group13.ASM)
; Library
INCLUDE Irvine32.inc
; Library

; This program requires following CMD window settings when excuting:
;   Font: Raster Font
;   Font Size: 8x8
;   Buffer Size: 100x100
;   Screen Size: 100x100

; Sorry for my bad English. Yet I'm not using Chinese for comments since I'm afraid that Chinese might turn out to be garbled.

; Also, I request you to read this code with a fine IDE (ex: CodeBlocks. I mean, absolutly not "note", "notepad" or "word")
; Otherwise, I'd doubt that you can even read anything here because this is a comlex code and I added more complex (and longer) comments trying to explain
; DO NOT judge my code readability if you'r messing with something that's not supposed to open a code, it's not my fault.

; All macros for things that repeat again and again:

; Operations (mov, add and sub) between two variables
    ; main frame
    varOp MACRO op:REQ, a:REQ, b:REQ
        push ebx
        IF TYPE b LE 0
            op a, b
        ELSEIF TYPE a EQ TYPE b
            IF TYPE a EQ 1
                mov bl, b
                op a, bl
            ELSEIF TYPE a EQ 2
                mov bx, b
                op a, bx
            ELSEIF TYPE a EQ 4
                mov ebx, b
                op a, ebx
            ENDIF
        ELSEIF TYPE a GT TYPE b
            IF TYPE a EQ 2
                movsx bx, b
                op a, bx
            ELSEIF TYPE a EQ 4
                movsx ebx, b
                op a, ebx
            ENDIF
        ENDIF
        pop ebx
    ENDM
    ; mov
    vmov MACRO a:REQ, b:REQ
        varOp mov, a, b
    ENDM
    ; add
    vadd MACRO a:REQ, b:REQ
        varOp add, a, b
    ENDM
    ; sub
    vsub MACRO a:REQ, b:REQ
        varOp sub, a, b
    ENDM

; LOOP set up (assembly language compiler doesn't agree loops that contain too much instruction between, thus we have to write cosmetic loop with jump instructions.)
    ; start (header)
    FORLOOP MACRO name:REQ, c:REQ, l:REQ, i, t ; name: label of loop, c: counter, l: loop count, i: iterator (if needed), t: the type of data to be iterated
        IFNB <i>
            IFNB <t>
                mov i, 0
            ENDIF
        ENDIF
        IF TYPE l LE 0 OR TYPE c EQ TYPE l
            mov c, l
        ELSE
            movsx c, l
        ENDIF
        name:
        push c
    ENDM
    ; break implementation
    BREAK MACRO name:REQ
        JMP END&name
    ENDM
    ; end (just like ENDIF, ENDW, etc)
    ENDFL MACRO name:REQ, c:REQ, l:REQ, i, t
        IFNB <i>
            IFNB <t>
                add i, t
            ENDIF
        ENDIF
        pop c
        dec c
        cmp c, 0
        JG name
        push c
        END&name:
        pop c
    ENDM

; Get random number
    rand MACRO result:REQ, from:REQ, to:REQ ; result: the variable to receive number, from: lower bound (constant), to: upper bound (constant)
        push eax
        mov eax, (to-from+1)
        call RandomRange
        add eax, from
        IF TYPE result GT 4
            ECHO ERROR: Result destination is too large
            EXITM
        ELSEIF TYPE result EQ 4
            mov result, eax
        ELSEIF TYPE result EQ 2
            mov result, ax
        ELSE
            mov result, al
        ENDIF
        pop eax
    ENDM

; Set output position (absolute)
    setCursor MACRO x:REQ, y:REQ
        vmov outputXY.x, x
        vmov outputXY.y, y
    ENDM
; Move output position (relatively)
    movCursor MACRO x:REQ, y:REQ
        vadd outputXY.x, x
        vadd outputXY.y, y
    ENDM

; Set a timer, the instructions between will run with a specific interval.
    ; start (header)
    TIMER MACRO t:REQ, i:REQ, additionalConditions:=<TRUE> ; t: the timer variable, i: the interval (in milliseconds), additionalConditions: If any, the instructions won't run while the conditions are not satisfied even if the timer ticks.
        push eax
        vmov tmpDWORD, i
        INVOKE GetTickCount
        sub eax, t
        .IF eax >= tmpDWORD && (additionalConditions)
        vadd t, i
        pop eax
    ENDM
    ; end (just like ENDIF, ENDW, etc)
    ENDT MACRO
        .ELSE
        pop eax
        .ENDIF
    ENDM

; All the macros end here

main	EQU start@0

; Overall constants:
fieldW = 80                     ; the in-game field width
fieldH = 80                     ; the in-game field height
fieldX = 10                     ; the in-game field position relative to window
fieldY = 10                     ; the in-game field position relative to window
FPS = 15                        ; Frame Per Second: apply to redrawing (better lower)
RPS = 150                       ; Refresh Per Second: apply to data-refreshing (better higher)
boulderNum = 20                 ; Max boulder number
boulderMinW = 1                 ; Min boulder width
boulderMaxW = 4                 ; Max boulder width
boulderMinH = 1                 ; Min boulder height
boulderMaxH = 4                 ; Max boulder height
boulderMinWeight = 50           ; Min boulder weight (used as the move interval for boulders)
boulderMaxWeight = 100          ; Max boulder weight (used as the move interval for boulders)
boulderCreateInterval = 300     ; in-game boulder creation interval
playerDashInterval = 10         ; player's move interval when dashing
playerfloatInterval = 250       ; player's move interval when floating
collapseAnimationInterval = 100 ; the interval between two frame of collapsing animation
shiftForCmp = 10                ; we can't compare two variable if they're not same-signed (ex: -1 > 1 is true), thus we shift all variable, especially about coordinates, then compare them.

; Objects status constants:
statusNotOnField = 0            ; the object is not on the field, prepared as spare data to be spawn
statusFloating = 0              ; is floating
statusMoving = 1                ; is moving
statusTurned = 3                ; the character turned once
statusCollapsing = 2            ; is collapsing (playing collapsing animation)
statusInteracting = 2           ; the character is interacting with an object

OBJECT STRUCT
    status BYTE statusNotOnField
    style BYTE 0
    operationsTimer DWORD 0
    objSize COORD <0,0>
    weight DWORD boulderMinWeight
    position COORD <0,0>
    direction COORD <0,0>
OBJECT ENDS

CHARACTER STRUCT
    interactingID DWORD 0
    status BYTE statusFloating
    style BYTE 0
    operationsTimer DWORD 0
    moveInterval DWORD playerFloatInterval
    position COORD <fieldW/2,fieldH/2>
    direction COORD <0,0>
CHARACTER ENDS

Initialize PROTO
Run PROTO
Refresh PROTO
Draw PROTO
InputKey PROTO
GameOver PROTO
CollisionTest PROTO, atop:WORD, abot:WORD, aleft:WORD, aright:WORD, atop:WORD, bbot:WORD, bleft:WORD, bright:WORD
ClearScreen PROTO
BoulderDraw PROTO, drawingObj:OBJECT, material:PTR BYTE
PlayerDraw PROTO
PrintBigWord PROTO, char:BYTE, color:PTR WORD, positionx:BYTE, positiony:BYTE

.data

    output DWORD 0                          ; output handle
    titleStr BYTE "In a Tight Corner", 0    ; title
    ft WORD 0                               ; field top bound
    fb WORD (fieldH-1)                      ; field bottom bound
    fl WORD 0                               ; field left bound
    fr WORD (fieldW-1)                      ; field right bound
    boundTopBot BYTE (fieldW+2) DUP('#')
    boundBody BYTE '#', fieldW DUP(' '), '#'
    paternWhite WORD (fieldW+2) DUP(0Fh)
    paternGreen WORD (fieldW+2) DUP(0Ah)
    refreshTimer DWORD 0
    drawTimer DWORD 0
    boulderCreationTimer DWORD 0
    player CHARACTER <>
    boulders OBJECT boulderNum DUP(<>)
    styles BYTE "OX+x*.        "
    ; big words:
    words BYTE "  OOOO             OOOOO        OOOOOOOO           OOOOOOO    OOOOOOOOOO                        OO    OOOO    OO   OO                   OOOOOO   OOOOOO OOOOOOOO        OO    OO                                "
          BYTE " OOOOOO          OOOOOOO        OOOOOOOO         OOOOOOOOO    OOOOOOOOOO                        OOO  OOOOOO   OO OOOOOO                 OOOOOOO OOO     OOOOOOOO        OO    OO                                "
          BYTE "OOO  OOO        OOO             OO              OOO     OO    OO   OO                           OOOOOOOOOOOO  OOOOO  OOO                OO   OO OOO        OO           OO    OO                                "
          BYTE "OO    OO        OO              OOOOOO          OO   OOOOOOOOOOO   OO                           OOOOOOOOOOOOO OOOO    OO                OOOOOOO  OOOO      OO           OO    OO                                "
          BYTE "OOOOOOOO        OO              OOOOOO          OO   OOOOOOOOOOO   OO                           OO OO OOOO OOOOOOO    OO                OOOOOO     OOOO    OO           OO    OO                                "
          BYTE "OOOOOOOO        OOO             OO              OOO   OOOO    OO   OO                           OO    OOOO  OOOOOOO  OOO                OO OOO       OOO   OO            OO  OO                                 "
          BYTE "OO    OO         OOOOOOO        OOOOOOOO         OOOOOOOOO    OOOOOOOOOO                        OO    OOOO   OOO OOOOOO                 OO  OOO      OOO   OO             OOOO                                  "
          BYTE "OO    OO           OOOOO        OOOOOOOO           OOOOOOO    OOOOOOOOOO                        OO    OOOO    OO   OO                   OO   OOO OOOOOO    OO              OO                                   "
    playerHalo BYTE "|/-\"
    ; temporary variables:
        tmpWORD WORD 10 DUP(0)
        tmpDWORD DWORD 0
    outputXY COORD <0,0>    ; output position

.code

main PROC

    ; The initializations at the start of program:
        INVOKE SetConsoleTitle, ADDR titleStr
        INVOKE GetStdHandle, STD_OUTPUT_HANDLE
        mov output, eax
        INVOKE ClearScreen
        INVOKE PrintBigWord, 'i', ADDR paternWhite, fieldW/2-37, fieldH/2-15
        INVOKE PrintBigWord, 'n', ADDR paternWhite, fieldW/2-28, fieldH/2-15
        INVOKE PrintBigWord, 'a', ADDR paternWhite, fieldW/2-16, fieldH/2-15
        INVOKE PrintBigWord, 't', ADDR paternWhite, fieldW/2-7, fieldH/2-3
        INVOKE PrintBigWord, 'i', ADDR paternWhite, fieldW/2+2, fieldH/2-3
        INVOKE PrintBigWord, 'g', ADDR paternWhite, fieldW/2+11, fieldH/2-3
        INVOKE PrintBigWord, 'h', ADDR paternWhite, fieldW/2+20, fieldH/2-3
        INVOKE PrintBigWord, 't', ADDR paternWhite, fieldW/2+29, fieldH/2-3
        INVOKE PrintBigWord, 'c', ADDR paternWhite, fieldW/2-22, fieldH/2+9
        INVOKE PrintBigWord, 'o', ADDR paternWhite, fieldW/2-13, fieldH/2+9
        INVOKE PrintBigWord, 'r', ADDR paternWhite, fieldW/2-4, fieldH/2+9
        INVOKE PrintBigWord, 'n', ADDR paternWhite, fieldW/2+5, fieldH/2+9
        INVOKE PrintBigWord, 'e', ADDR paternWhite, fieldW/2+14, fieldH/2+9
        INVOKE PrintBigWord, 'r', ADDR paternWhite, fieldW/2+23, fieldH/2+9
    call ReadChar   ; wait any key input
    INVOKE Initialize

main ENDP

; Initialize the game, runs at the start of every game.
Initialize PROC

    call Randomize
    mov player.style, 0
    mov player.position.x, fieldW/2
    mov player.position.y, fieldH/2
    mov player.direction.x, 0
    mov player.direction.y, 0
    FORLOOP ResetBoulder, ecx, boulderNum, esi, TYPE OBJECT
        mov (OBJECT PTR boulders[esi]).status, statusNotOnField
    ENDFL ResetBoulder, ecx, boulderNum, esi, TYPE OBJECT
    INVOKE GetTickCount
    mov refreshTimer, eax
    mov drawTimer, eax
    mov boulderCreationTimer, eax
    mov player.operationsTimer, eax
    mov player.status, statusFloating
    INVOKE Run

Initialize ENDP

; Main running controller of the game
Run PROC

    Controller:
        mov bx, 0
        Timer refreshTimer, (1000/RPS)
            mov bl, 1
            INVOKE Refresh
        ENDT
        Timer drawTimer, (1000/FPS)
            mov bh, 1
            INVOKE Draw
        ENDT
        .IF bx == 0
            INVOKE InputKey
        .ENDIF
    JMP Controller

Run ENDP

; Refresh all data (probably most complex things among the whole code, I'd suggest just give up tracing this and skip it to line 505......)
Refresh PROC

    CreateBoulder:
        TIMER boulderCreationTimer, boulderCreateInterval
            newBoulder TEXTEQU <(OBJECT PTR boulders[esi])>
            FORLOOP FindBoulder, ecx, boulderNum, esi, TYPE OBJECT
                mov bl, newBoulder.status
                .IF bl == statusNotOnField
                    BREAK FindBoulder
                .ENDIF
            ENDFL FindBoulder, ecx, boulderNum, esi, TYPE OBJECT
            mov newBoulder.style, 0
            vmov newBoulder.operationsTimer, boulderCreationTimer
            rand newBoulder.objSize.x, boulderMinW, boulderMaxW
            rand newBoulder.objSize.y, boulderMinH, boulderMaxH
            rand newBoulder.weight, boulderMinWeight, boulderMaxWeight
            rand bx, 0, 3
            .IF bx == 0
                mov newBoulder.direction.x, 0
                mov newBoulder.direction.y, -1
                rand newBoulder.position.x, 0, fieldW
                mov newBoulder.position.y, (fieldH-1)
                vadd newBoulder.position.y, newBoulder.objSize.y
            .ELSEIF bx == 1
                mov newBoulder.direction.x, 0
                mov newBoulder.direction.y, 1
                rand newBoulder.position.x, 0, fieldW
                mov newBoulder.position.y, 0
                vsub newBoulder.position.y, newBoulder.objSize.y
            .ELSEIF bx == 2
                mov newBoulder.direction.x, -1
                mov newBoulder.direction.y, 0
                mov newBoulder.position.x, (fieldW-1)
                vadd newBoulder.position.x, newBoulder.objSize.x
                rand newBoulder.position.y, 0, fieldH
            .ELSEIF bx == 3
                mov newBoulder.direction.x, 1
                mov newBoulder.direction.y, 0
                mov newBoulder.position.x, 0
                vsub newBoulder.position.x, newBoulder.objSize.x
                rand newBoulder.position.y, 0, fieldH
            .ENDIF
            mov newBoulder.status, statusMoving
        ENDT

    FORLOOP MoveBoulder, ecx, boulderNum, esi, TYPE OBJECT
        moving TEXTEQU <(OBJECT PTR boulders[esi])>
        mov bl, moving.status
        TIMER moving.operationsTimer, moving.weight, bl == statusMoving
            vadd moving.position.x, moving.direction.x
            vadd moving.position.y, moving.direction.y
            .IF player.interactingID == esi && player.status == statusInteracting
                vadd player.position.x, moving.direction.x
                vadd player.position.y, moving.direction.y
                INVOKE CollisionTest, player.position.y, player.position.y, player.position.x, player.position.x, ft, fb, fl, fr
                .IF ax == 0
                    vsub player.position.x, moving.direction.x
                    vsub player.position.y, moving.direction.y
                    INVOKE GameOver
                .ENDIF
            .ENDIF
            vmov (WORD PTR tmpWORD[0]), moving.position.y
            vsub (WORD PTR tmpWORD[0]), moving.objSize.y
            mt TEXTEQU <(WORD PTR tmpWORD[0])>
            vmov (WORD PTR tmpWORD[2]), moving.position.y
            vadd (WORD PTR tmpWORD[2]), moving.objSize.y
            mb TEXTEQU <(WORD PTR tmpWORD[2])>
            vmov (WORD PTR tmpWORD[4]), moving.position.x
            vsub (WORD PTR tmpWORD[4]), moving.objSize.x
            ml TEXTEQU <(WORD PTR tmpWORD[4])>
            vmov (WORD PTR tmpWORD[6]), moving.position.x
            vadd (WORD PTR tmpWORD[6]), moving.objSize.x
            mr TEXTEQU <(WORD PTR tmpWORD[6])>
            FORLOOP BoulderToBoulderCollision, edx, boulderNum, edi, TYPE OBJECT
                testing TEXTEQU <(OBJECT PTR boulders[edi])>
                mov bh, testing.status
                .IF edi != esi && bh != statusNotOnField
                    vmov (WORD PTR tmpWORD[8]), testing.position.y
                    vsub (WORD PTR tmpWORD[8]), testing.objSize.y
                    tt TEXTEQU <(WORD PTR tmpWORD[8])>
                    vmov (WORD PTR tmpWORD[10]), testing.position.y
                    vadd (WORD PTR tmpWORD[10]), testing.objSize.y
                    tb TEXTEQU <(WORD PTR tmpWORD[10])>
                    vmov (WORD PTR tmpWORD[12]), testing.position.x
                    vsub (WORD PTR tmpWORD[12]), testing.objSize.x
                    tl TEXTEQU <(WORD PTR tmpWORD[12])>
                    vmov (WORD PTR tmpWORD[14]), testing.position.x
                    vadd (WORD PTR tmpWORD[14]), testing.objSize.x
                    tr TEXTEQU <(WORD PTR tmpWORD[14])>
                    INVOKE CollisionTest, mt, mb, ml, mr, tt, tb, tl, tr
                    .IF ax == 1
                        mov moving.status, statusCollapsing
                        .IF player.interactingID == esi && player.status == statusInteracting
                            vmov player.direction.x, moving.direction.x
                            vmov player.direction.y, moving.direction.y
                            mov player.moveInterval, playerFloatInterval
                            INVOKE GetTickCount
                            mov player.operationsTimer, eax
                            mov player.status, statusFloating
                        .ENDIF
                        .IF bh != statusCollapsing
                            mov testing.status, statusCollapsing
                            .IF player.interactingID == edi && player.status == statusInteracting
                                vmov player.direction.x, testing.direction.x
                                vmov player.direction.y, testing.direction.y
                                mov player.moveInterval, playerFloatInterval
                                INVOKE GetTickCount
                                mov player.operationsTimer, eax
                                mov player.status, statusFloating
                            .ENDIF
                        .ENDIF
                        BREAK BoulderToBoulderCollision
                    .ENDIF
                .ENDIF
            ENDFL BoulderToBoulderCollision, edx, boulderNum, edi, TYPE OBJECT

            BoulderToPlayerCollision:
                INVOKE CollisionTest, mt, mb, ml, mr, player.position.y, player.position.y, player.position.x, player.position.x
                .IF ax == 1
                    vadd player.position.x, moving.direction.x
                    vadd player.position.y, moving.direction.y
                    INVOKE GameOver
                .ENDIF

            BoulderRemove:
                INVOKE CollisionTest, mt, mb, ml, mr, ft, fb, fl, fr
                .IF ax == 0
                    mov moving.status, statusNotOnField
                .ENDIF
        ENDT
    ENDFL MoveBoulder, ecx, boulderNum, esi, TYPE OBJECT

    MovePlayer:
        TIMER player.operationsTimer, player.moveInterval, player.status == statusFloating || player.status == statusMoving || player.status == statusTurned
            vadd player.position.x, player.direction.x
            vadd player.position.y, player.direction.y
            FORLOOP PlayerToBoulderCollision, ecx, boulderNum, esi, TYPE OBJECT
                testing TEXTEQU <(OBJECT PTR boulders[esi])>
                mov bl, testing.status
                .IF bl == statusMoving
                    vmov (WORD PTR tmpWORD[0]), testing.position.y
                    vsub (WORD PTR tmpWORD[0]), testing.objSize.y
                    tt TEXTEQU <(WORD PTR tmpWORD[0])>
                    vmov (WORD PTR tmpWORD[2]), testing.position.y
                    vadd (WORD PTR tmpWORD[2]), testing.objSize.y
                    tb TEXTEQU <(WORD PTR tmpWORD[2])>
                    vmov (WORD PTR tmpWORD[4]), testing.position.x
                    vsub (WORD PTR tmpWORD[4]), testing.objSize.x
                    tl TEXTEQU <(WORD PTR tmpWORD[4])>
                    vmov (WORD PTR tmpWORD[6]), testing.position.x
                    vadd (WORD PTR tmpWORD[6]), testing.objSize.x
                    tr TEXTEQU <(WORD PTR tmpWORD[6])>
                    INVOKE CollisionTest, player.position.y, player.position.y, player.position.x, player.position.x, tt, tb, tl, tr
                    .IF ax == 1
                        vsub player.position.x, player.direction.x
                        vsub player.position.y, player.direction.y
                        vmov (WORD PTR tmpWORD[8]), player.direction.x
                        vadd (WORD PTR tmpWORD[8]), testing.direction.x
                        vmov (WORD PTR tmpWORD[10]), player.direction.y
                        vadd (WORD PTR tmpWORD[10]), testing.direction.y
                        .IF (WORD PTR tmpWORD[8]) == 0 && (WORD PTR tmpWORD[10]) == 0
                            INVOKE GameOver
                        .ELSE
                            mov player.status, statusInteracting
                            mov player.interactingID, esi
                        .ENDIF
                        BREAK PlayerToBoulderCollision
                    .ENDIF
                .ENDIF
            ENDFL PlayerToBoulderCollision, ecx, boulderNum, esi, TYPE OBJECT
            INVOKE CollisionTest, player.position.y, player.position.y, player.position.x, player.position.x, ft, fb, fl, fr
            .IF ax == 0
                vsub player.position.x, player.direction.x
                vsub player.position.y, player.direction.y
                INVOKE GameOver
            .ENDIF
        ENDT

    FORLOOP BoulderCollapse, ecx, boulderNum, esi, TYPE OBJECT
        collapsing TEXTEQU <(OBJECT PTR boulders[esi])>
        mov bl, collapsing.status
        TIMER collapsing.operationsTimer, collapseAnimationInterval, bl == statusCollapsing
            mov bl, collapsing.style
            .IF bl >= 5
                mov collapsing.status, statusNotOnField
            .ELSE
                inc collapsing.style
            .ENDIF
        ENDT
    ENDFL BoulderCollapse, ecx, boulderNum, esi, TYPE OBJECT

    RET

Refresh ENDP

; Redraw
Draw PROC

    INVOKE ClearScreen
    INVOKE PlayerDraw
    FORLOOP DrawBoulder, ecx, boulderNum, esi, TYPE OBJECT
        drawing TEXTEQU <(OBJECT PTR boulders[esi])>
        mov bl, drawing.status
        .IF bl != statusNotOnField
            movsx edi, drawing.style
            INVOKE BoulderDraw, drawing, ADDR styles[edi]
        .ENDIF
    ENDFL DrawBoulder, ecx, boulderNum, esi, TYPE OBJECT

    RET

Draw ENDP

;For key inputs
InputKey PROC

    mov eax, 20
    call Delay
    call ReadKey
    .IF !ZERO?
        .IF dx == 001Bh                         ; ESC
            EXIT
        .ELSEIF dx == 0026h || dx == 0028h || dx == 0025h || dx == 0027h ; player move commands (arrow keys)
            .IF player.status == statusFloating || player.status == statusInteracting || player.status == statusMoving
                .IF dx == 0026h                 ; UP
                    mov player.direction.x, 0
                    mov player.direction.y, -1
                .ELSEIF dx == 0028h             ; DOWN
                    mov player.direction.x, 0
                    mov player.direction.y, 1
                .ELSEIF dx == 0025h             ; LEFT
                    mov player.direction.x, -1
                    mov player.direction.y, 0
                .ELSEIF dx == 0027h             ; RIGHT
                    mov player.direction.x, 1
                    mov player.direction.y, 0
                .ENDIF
                ; Prevent illegal input
                .IF player.status == statusInteracting
                    mov esi, player.interactingID
                    testing TEXTEQU <(OBJECT PTR boulders[esi])>
                    vmov (WORD PTR tmpWORD[0]), testing.position.y
                    vsub (WORD PTR tmpWORD[0]), testing.objSize.y
                    tt TEXTEQU <(WORD PTR tmpWORD[0])>
                    vmov (WORD PTR tmpWORD[2]), testing.position.y
                    vadd (WORD PTR tmpWORD[2]), testing.objSize.y
                    tb TEXTEQU <(WORD PTR tmpWORD[2])>
                    vmov (WORD PTR tmpWORD[4]), testing.position.x
                    vsub (WORD PTR tmpWORD[4]), testing.objSize.x
                    tl TEXTEQU <(WORD PTR tmpWORD[4])>
                    vmov (WORD PTR tmpWORD[6]), testing.position.x
                    vadd (WORD PTR tmpWORD[6]), testing.objSize.x
                    tr TEXTEQU <(WORD PTR tmpWORD[6])>
                    vadd player.position.x, player.direction.x
                    vadd player.position.y, player.direction.y
                    INVOKE CollisionTest, player.position.y, player.position.y, player.position.x, player.position.x, tt, tb, tl, tr
                    vsub player.position.x, player.direction.x
                    vsub player.position.y, player.direction.y
                    .IF ax == 1

                        RET

                    .ENDIF
                .ENDIF
                ; change status to implement "player can only turn once each move"
                .IF player.status == statusMoving
                    mov player.status, statusTurned
                .ELSE
                    mov player.moveInterval, playerDashInterval
                    INVOKE GetTickCount
                    mov player.operationsTimer, eax
                    mov player.status, statusMoving
                .ENDIF
            .ENDIF
        .ENDIF
    .ENDIF

    RET

InputKey ENDP

GameOver PROC

    INVOKE Draw ; Redraw last once lest the last fame when game ends isn't match the real data
    INVOKE GetTickCount
    mov player.operationsTimer, eax
    ; play the dying animation of player
    Anime:
        TIMER player.operationsTimer, collapseAnimationInterval*2
            inc player.style
        ENDT
        .IF player.style >= 13  ; the animation ends, so does the game.
            INVOKE ClearScreen
            INVOKE PrintBigWord, 'g', ADDR paternWhite, fieldW/2-37, fieldH/2-3
            INVOKE PrintBigWord, 'a', ADDR paternWhite, fieldW/2-28, fieldH/2-3
            INVOKE PrintBigWord, 'm', ADDR paternWhite, fieldW/2-19, fieldH/2-3
            INVOKE PrintBigWord, 'e', ADDR paternWhite, fieldW/2-10, fieldH/2-3
            INVOKE PrintBigWord, 'o', ADDR paternWhite, fieldW/2+2, fieldH/2-3
            INVOKE PrintBigWord, 'v', ADDR paternWhite, fieldW/2+11, fieldH/2-3
            INVOKE PrintBigWord, 'e', ADDR paternWhite, fieldW/2+20, fieldH/2-3
            INVOKE PrintBigWord, 'r', ADDR paternWhite, fieldW/2+29, fieldH/2-3
            ; wait any key input then restart:
            call ReadKey    ; this is a tricky solution to solve a problem about:
            call ReadChar   ; if user pressed any key when the dying animation of player is playing,
                            ; then the game will instantly restart after the animation ends.
                            ; I'd guess that's a key-input-buffer-related problem, so this method can solve it.
            INVOKE Initialize ; restart
        .ELSE
            INVOKE PlayerDraw
            JMP Anime
        .ENDIF

GameOver ENDP

; For collision test between two square, ax = 1 if collided, ax = 0 otherwise.
CollisionTest PROC USES bx, atop:WORD, abot:WORD, aleft:WORD, aright:WORD, btop:WORD, bbot:WORD, bleft:WORD, bright:WORD

    mov ax, abot
    add ax, shiftForCmp
    mov bx, btop
    add bx, shiftForCmp
    .IF ax >= bx
    mov ax, atop
    add ax, shiftForCmp
    mov bx, bbot
    add bx, shiftForCmp
    .IF ax <= bx
    mov ax, aright
    add ax, shiftForCmp
    mov bx, bleft
    add bx, shiftForCmp
    .IF ax >= bx
    mov ax, aleft
    add ax, shiftForCmp
    mov bx, bright
    add bx, shiftForCmp
    .IF ax <= bx
        mov ax, 1
        RET
    .ENDIF
    .ENDIF
    .ENDIF
    .ENDIF
    mov ax, 0
    RET

CollisionTest ENDP

; Actually, also draw the field bound.
ClearScreen PROC

    setCursor fieldX-1, fieldY-1
    INVOKE WriteConsoleOutputAttribute, output, ADDR paternWhite, (fieldW+2), outputXY, ADDR tmpDWORD
    INVOKE WriteConsoleOutputCharacter, output, ADDR boundTopBot, (fieldW+2), outputXY, ADDR tmpDWORD
    movCursor 0, 1
    FORLOOP Body, ecx, fieldH
    INVOKE WriteConsoleOutputAttribute, output, ADDR paternWhite, (fieldW+2), outputXY, ADDR tmpDWORD
    INVOKE WriteConsoleOutputCharacter, output, ADDR boundBody, (fieldW+2), outputXY, ADDR tmpDWORD
    movCursor 0, 1
    ENDFL Body, ecx, fieldH
    INVOKE WriteConsoleOutputAttribute, output, ADDR paternWhite, (fieldW+2), outputXY, ADDR tmpDWORD
    INVOKE WriteConsoleOutputCharacter, output, ADDR boundTopBot, (fieldW+2), outputXY, ADDR tmpDWORD
    RET

ClearScreen ENDP

PrintBigWord PROC, char:BYTE, color:PTR WORD, positionx:BYTE, positiony:BYTE

    setCursor fieldX, fieldY
    movCursor positionx, positiony
    FORLOOP Print, ecx, 8, esi, 208
        INVOKE WriteConsoleOutputAttribute, output, color, 8, outputXY, ADDR tmpDWORD
        mov edi, esi
        vadd edi, char
        vadd edi, char
        vadd edi, char
        vadd edi, char
        vadd edi, char
        vadd edi, char
        vadd edi, char
        vadd edi, char
        sub edi, 'a'*8
        INVOKE WriteConsoleOutputCharacter, output, ADDR words[edi], 8, outputXY, ADDR tmpDWORD
        movCursor 0, 1
    ENDFL Print, ecx, 8, esi, 208
    RET

PrintBigWord ENDP

BoulderDraw PROC, drawingObj:OBJECT, material:PTR BYTE

    setCursor fieldX, fieldY
    movCursor drawingObj.position.x, drawingObj.position.y
    movCursor drawingObj.objSize.x, drawingObj.objSize.y
    vmov (WORD PTR tmpWORD[0]), drawingObj.objSize.x
    vadd (WORD PTR tmpWORD[0]), drawingObj.objSize.x
    add (WORD PTR tmpWORD[0]), 1
    totalW TEXTEQU <(WORD PTR tmpWORD[0])>
    vmov (WORD PTR tmpWORD[2]), drawingObj.objSize.y
    vadd (WORD PTR tmpWORD[2]), drawingObj.objSize.y
    add (WORD PTR tmpWORD[2]), 1
    totalH TEXTEQU <(WORD PTR tmpWORD[2])>
    FORLOOP Row, ecx, totalH
        FORLOOP Col, edx, totalW
            .IF outputXY.y >= fieldY && outputXY.y <= (fieldY+fieldH-1) && outputXY.x >= fieldX && outputXY.x <= (fieldX+fieldW-1)
                INVOKE WriteConsoleOutputCharacter, output, material, 1, outputXY, ADDR tmpDWORD
            .ENDIF
            movCursor -1, 0
        ENDFL Col, edx, totalW
        movCursor totalW, -1
    ENDFL Row, ecx, totalW
    RET

BoulderDraw ENDP

PlayerDraw PROC

    setCursor fieldX, fieldY
    movCursor player.position.x, player.position.y
    movsx esi, player.style
    INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
    INVOKE WriteConsoleOutputCharacter, output, ADDR styles[esi], 1, outputXY, ADDR tmpDWORD
    ; I swear that I wanted to use loop, but the iterating is a circle around the player position.
    ; So it might become even more complex if I insist to use loop, then I finally gave up and attempt with the silly method......
    .IF player.style < 6
        movCursor 0, -1
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[0], 1, outputXY, ADDR tmpDWORD
        movCursor 0, 1
    .ELSE
        movCursor -1, -1
        FORLOOP PlayerRow, ecx, 3
            INVOKE WriteConsoleOutputCharacter, output, ADDR styles[6], 3, outputXY, ADDR tmpDWORD
            movCursor 0, 1
        ENDFL PlayerRow, ecx, 3
        movCursor 1, -2
    .ENDIF
    .IF player.style < 7
        movCursor 1, -1
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[1], 1, outputXY, ADDR tmpDWORD
        movCursor -1, 1
    .ENDIF
    .IF player.style < 8
        movCursor 1, 0
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[2], 1, outputXY, ADDR tmpDWORD
        movCursor -1, 0
    .ENDIF
    .IF player.style < 9
        movCursor 1, 1
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[3], 1, outputXY, ADDR tmpDWORD
        movCursor -1, -1
    .ENDIF
    .IF player.style < 10
        movCursor 0, 1
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[0], 1, outputXY, ADDR tmpDWORD
        movCursor 0, -1
    .ENDIF
    .IF player.style < 11
        movCursor -1, 1
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[1], 1, outputXY, ADDR tmpDWORD
        movCursor 1, -1
    .ENDIF
    .IF player.style < 12
        movCursor -1, 0
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[2], 1, outputXY, ADDR tmpDWORD
        movCursor 1, 0
    .ENDIF
    .IF player.style < 13
        movCursor -1, -1
        INVOKE WriteConsoleOutputAttribute, output, ADDR paternGreen, 1, outputXY, ADDR tmpDWORD
        INVOKE WriteConsoleOutputCharacter, output, ADDR playerHalo[3], 1, outputXY, ADDR tmpDWORD
        movCursor 1, 1
    .ENDIF

    RET

PlayerDraw ENDP

END main
