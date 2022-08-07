

    processor 6502
    include "vcs.h"
    include "macro.h"
    include "bank_switch_f8.h"

NTSC = 0
PAL60 = 1

    IFNCONST SYSTEM
SYSTEM = NTSC
    ENDIF

; ----------------------------------
; constants

#if SYSTEM = NTSC
; NTSC Colors
WHITE = $00f
BLACK = 0
#else
; PAL Colors
WHITE = $00E
BLACK = 0
#endif

SUPERCHIP = 1

RR_START = SUPERCHIP_READ
RW_START = SUPERCHIP_WRITE

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

frame        ds 1    
bank         ds 1
button       ds 1

    START_BANK 0

;--------------------
; Bank 0 kernel

    DEF_LBL bank_0_kernel

            ldx #128
horizon_loop_0
            ldy #16
horizon_loop_1
            sta WSYNC
            lda #0           
            sta COLUBK            
            dex
            dey
            bne horizon_loop_1

            ldy #16
horizon_loop_2
            sta WSYNC

            lda RR_START,x
            sta COLUBK            
            dex
            dey
            bne horizon_loop_2

            cpx #0 
            bne horizon_loop_0
            
    JMP_LBL end_kernel

    END_BANK 

    START_BANK 1

; ----------------------------------
; code

CleanStart
    ; do the clean start macro
            CLEAN_START

    ; setup
    ldx #$7f
setup_loop
    txa
    asl 
    sta RW_START,x
    dex
    bpl setup_loop

newFrame

    ; 3 scanlines of vertical sync signal to follow

            ldx #%00000010
            stx VSYNC               ; turn ON VSYNC bit 1

            sta WSYNC               ; wait a scanline
            sta WSYNC               ; another
            sta WSYNC               ; another = 3 lines total

            sta VSYNC               ; turn OFF VSYNC bit 1

    ; 37 scanlines of vertical blank to follow

;--------------------
; VBlank start

            lda #%10000010
            sta VBLANK

            lda #42    ; vblank timer will land us ~ on scanline 34
            sta TIM64T

            inc frame ; new frame

check_button_press
            lda INPT4
            and #$80
            bpl _button_down
            sta button
_button_down
            cmp button
            beq _button_no_press
            inc bank
            sta button
_button_no_press

            ldx #$00
waitOnVBlank            
            cpx INTIM
            bmi waitOnVBlank
            sta WSYNC
            stx VBLANK


            lda #BLACK
            sta COLUBK
; SL35
            sta WSYNC             ;3   0
            
; SL36
            sta WSYNC             ;3   0
            
            lda #1
            bit bank
            bne skip_jmp
            JMP_LBL bank_0_kernel
skip_jmp

;--------------------
; Bank 1 kernel

            ldx #128
horizon_loop
            sta WSYNC
            lda RR_START,x           
            sta COLUBK            
            dex
            bne horizon_loop

    DEF_LBL end_kernel

            ldx #(192 - 128)
end_scan
            sta WSYNC
            lda #0           
            sta COLUBK            
            dex
            bne end_scan

;--------------------
; Overscan start


            lda #$000
            sta ENAM0
            sta COLUBK

            ldx #30
waitOnOverscan
            sta WSYNC
            dex
            bne waitOnOverscan

            jmp newFrame

    END_BANK