
    processor 6502
    include "vcs.h"
    include "macro.h"

NTSC = 0
PAL60 = 1

    IFNCONST SYSTEM
SYSTEM = NTSC
    ENDIF

; ----------------------------------
; constants

#if SYSTEM = NTSC
; NTSC Colors
WHITE = $0f
BLACK = 0
WALL_COLOR = $A0
BALL_COLOR = $2C
#else
; PAL Colors
WHITE = $0E
BLACK = 0
WALL_COLOR = $92
BALL_COLOR = $2A
#endif

GAME_STATE_SPLASH_0   = -3
GAME_STATE_SPLASH_1   = -2
GAME_STATE_SPLASH_2   = -1
GAME_STATE_PLAY       = 0
GAME_STATE_GAME_OVER  = 1
GAME_STATE_MENU       = 2
GAME_STATE_START      = 3

NUM_PLAYERS     = 2

SPLASH_DELAY    = 255

PLAYFIELD_VIEWPORT_HEIGHT = 160
GOAL_HEIGHT = 16
BALL_HEIGHT = 14

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

game_state   ds 1
game_timer   ds 1

frame        ds 4

target_hpos  ds 2
target_angle ds 2
aim_dir      ds 2

ball_vpos    ds 1
ball_hpos    ds 1
ball_dy      ds 1
ball_dx      ds 1
ball_color   ds 1
ball_voffset ds 1
ball_cx      ds BALL_HEIGHT

scroll       ds 1
scroll_dir   ds 1

display_playfield_limit ds 1
display_goal_limit      ds 1

temp_t       ds 1

    SEG

; ----------------------------------
; code

  SEG
    ORG $F000

reset

    ; do the clean start macro
            CLEAN_START

    ; game setup
    lda #0
    sta scroll
    lda #1
    sta scroll_dir
    lda #GAME_STATE_PLAY ; #GAME_STATE_SPLASH_0
    sta game_state
    ; player setup
    ldx #NUM_PLAYERS
player_setup_loop
    lda #1
    sta aim_dir,x
    dex
    bpl player_setup_loop
    ; ball positioning
    lda #BALL_COLOR
    sta ball_color
    lda #$01
    sta ball_dy
    lda #$10
    sta ball_dx
    lda #GOAL_HEIGHT + 20
    sta ball_vpos
    lda #$36
    sta ball_hpos

newFrame

    ; 3 scanlines of vertical sync signal to follow

            ldx #%00000010
            stx VSYNC               ; turn ON VSYNC bit 1
            ldx #0

            sta WSYNC               ; wait a scanline
            sta WSYNC               ; another
            sta WSYNC               ; another = 3 lines total

            stx VSYNC               ; turn OFF VSYNC bit 1

    ; 37 scanlines of vertical blank to follow

;--------------------
; VBlank start

            lda #%10000010
            sta VBLANK

            lda #42    ; vblank timer will land us ~ on scanline 34
            sta TIM64T

            inc frame ; new frame

            ldx game_state
            beq kernel_playGame
            bmi jmpSplash
            dex 
            beq kernel_gameOver
            dex
            beq kernel_menu
            dex 
            jmp kernel_startGame
jmpSplash
            jmp kernel_showSplash

;--------------------
; gameplay update kernel

kernel_startGame
kernel_menu
kernel_gameOver
kernel_playGame

            ldx #NUM_PLAYERS - 1
            lda #$80 
player_update_loop
            ; update target hpos
            bit SWCHA                 
            beq player_right          
            lsr                      
            bit SWCHA                 
            beq player_left       
            jmp player_update_angle
player_right
            lda #$f0
            clc
            adc target_hpos,x
            bvc player_hpos_store
            adc #$00  ; carry set so this adds 1
            tay
            and #$0f 
            cmp #$0b
            bmi player_hpos_store_y
            jmp player_update_angle
player_left
            lda #$10
            clc
            adc target_hpos,x
            bvc player_hpos_store
            adc #$0f
            tay
            and #$0f 
            cmp #$0b
            bpl player_update_angle
player_hpos_store_y
            tya
player_hpos_store
            sta target_hpos,x
player_update_angle
            ; update target firing angle
            lda target_angle,x
            clc 
            adc aim_dir,x
            bvc player_update_store
            tay
            ; negate aim
            lda #0
            sec 
            sbc aim_dir,x
            sta aim_dir,x
            ; invert target
            tya
            eor #0
player_update_store
            sta target_angle,x
player_update_end
            lda #$40
            dex
            bpl player_update_loop

ball_update
            ; collision
            lda #$00
            ldx #BALL_HEIGHT - 1
            ora ball_cx,x
            dex
            ora ball_cx,x
            bmi ball_update_cx_top
            dex
ball_update_cx_loop
            ora ball_cx,x
            bmi ball_update_cx_horiz
            dex
            cpx #2
            bcs ball_update_cx_loop
            ora ball_cx,x
            dex
            ora ball_cx,x
            bmi ball_update_cx_bottom
            jmp ball_update_hpos

ball_update_cx_top
            ldx #$01
            jmp ball_update_cx_save_y

ball_update_cx_horiz
            lda ball_dx
            eor #$e0
            sta ball_dx
            jmp ball_update_hpos

ball_update_cx_bottom
            ldx #$ff
ball_update_cx_save_y
            stx ball_dy

ball_update_hpos
            ; ball x pos
            lda ball_dx
            bmi ball_update_hpos_right
            ; move ball left
            clc
            adc ball_hpos
            bvc ball_update_hpos_store
            adc #$0f
            tay
            and #$0f 
            cmp #$01
            bpl ball_update_hpos_store_y
            lda #$f0
            sta ball_dx
            jmp ball_update_hpos_end
ball_update_hpos_right
            ; move ball right
            clc
            adc ball_hpos
            bvc ball_update_hpos_store
            adc #$00  ; carry set so this adds 1
            tay

            and #$0f 
            cmp #$09
            bmi ball_update_hpos_store_y
            lda #$10
            sta ball_dx
            jmp ball_update_hpos_end
ball_update_hpos_store_y
            tya
ball_update_hpos_store
            sta ball_hpos
ball_update_hpos_end 
            lda ball_dy
            clc
            bmi ball_update_vpos_up
            adc ball_vpos
            cmp #255 - GOAL_HEIGHT - BALL_HEIGHT
            bcc ball_update_vpos_store
            ldy #$ff
            sty ball_dy
            lda #255 - GOAL_HEIGHT - BALL_HEIGHT
            jmp ball_update_vpos_store
ball_update_vpos_up
            adc ball_vpos
            cmp #GOAL_HEIGHT
            bcs ball_update_vpos_store 
            ldy #$01
            sty ball_dy
            lda #GOAL_HEIGHT
ball_update_vpos_store
            sta ball_vpos
        
scroll_update
            sec ; assume a is ball_vpos
            sbc #PLAYFIELD_VIEWPORT_HEIGHT / 2
            bcc scroll_update_up
            cmp #255 - PLAYFIELD_VIEWPORT_HEIGHT
            bcc scroll_update_store
            lda #255 - PLAYFIELD_VIEWPORT_HEIGHT -1
            jmp scroll_update_store            
scroll_update_up
            lda #0
scroll_update_store
            sta scroll
            ; calc end of playfield
            clc
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            sta display_playfield_limit
            ; calc ball offset
            lda scroll
            sec             
            sbc ball_vpos  
            sta ball_voffset          

            ; end vblank
            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #1
            sta CTRLPF ; reflect playfield
            lda #WALL_COLOR
            sta COLUPF


;---------------------
; playfield

            ; resp target lasers
            ldx #NUM_PLAYERS - 1
target_resp_loop
            sta WSYNC               ;3   0
            lda target_hpos,x       ;4   4
            sta HMM0,x              ;4   8
            and #$0f                ;2  10
            tay                     ;2  12
target_resp_loop_0
            dey                     ;2  14
            bpl target_resp_loop_0  ;2* 16
            sta RESM0,x             ;4  --
            dex                     ;2  --
            bpl target_resp_loop    ;2  --

            ; resp ball
            sta WSYNC
            lda ball_hpos         ;3   3
            sta HMP0              ;3   6
            sta HMP1              ;3   9
            and #$0f              ;2  11
            tax                   ;2  13
            lda ball_color        ;3  16
ball_resp_loop_0
            dex                   ;2  18
            bpl ball_resp_loop_0  ;2* 20
            sta RESP0             ;3  --
            sta RESP1             ;3  --
            sta COLUP0            ;3  --
            
            sta WSYNC             ;3   0
            sta HMOVE             ;3   3
            inx                   ;2   5 ; relying on x = ff
            stx COLUP1            ;3   8
            SLEEP 16              ;14 24
            stx HMP0              ;3  27
            stx HMM0              ;3  30
            stx HMM1              ;3  33
            inx                   ;2  35
            stx VDELP1            ;3  38
            lda #$70              ;2  40 ; shift P1 back 7 clocks
            sta HMP1              ;3  43

            ; prep for playfield
            sta WSYNC                    ;0   0
            sta HMOVE                    ;3   3
            tsx                          ;2   5
            stx temp_t                   ;3   8
            ldx #ball_cx + BALL_HEIGHT-1 ;2  10
            txs                          ;2  12
            sta CXCLR                    ;3  15
            lda $ff
            sta PF0
            lda #$00                     ;2  24
            sta HMP0                     ;3  27
            sta HMP1                     ;3  27
            lda #$10                     ;-----
            sta HMM0
            sta HMM1
            lda #2                       ;2  29
            sta ENAM0                    ;3  32
            sta ENAM1                    ;3  35
            ldy scroll                   ;3  --

playfield_loop_0_hm
            tya                          ;2  -- 74
            and #$0f                     ;2  -- 76
            tax                          ;2  -- 78
            lda WALL_COLORS,x            ;4  -- 80
playfield_loop_0
            sta WSYNC                    ;3   0
            bne .playfield_loop_0_hskip  ;2   2
            sta HMOVE                    ;3   5
.playfield_loop_0_hskip
            sta COLUPF                   ;3   8/6
            lda PLAYFIELD_COLORS,x       ;4  12/10
            sta COLUBK                   ;3  15
            lda P1_WALLS,y               ;4  19
            sta PF1                      ;3  23
            ldx ball_voffset             ;3  26
            bmi .playfield_loop_0_bskip  ;2  28
            lda BALL_GRAPHICS,x          ;4  32
            sta GRP0                     ;3  35
            ; sta GRP1                     ;3  38
            lda CXP0FB                   ;3  41
            sta CXCLR
            pha                          ;3  44
            cpx #BALL_HEIGHT             ;2  46
            bcc .playfield_loop_0_bsave  ;2  48
            ldx #$7F                     ;2  50
.playfield_loop_0_bsave
.playfield_loop_0_bskip
            inx                          ;2  52
            stx ball_voffset             ;3  55
            ;lda P2_WALLS,y               ;4  59
            ;sta PF2                      ;3  62
            iny                          ;2  64
            cpy display_playfield_limit  ;3  69
            bcc playfield_loop_0_hm      ;3  72

playfield_end

;--------------------
; Overscan start

waitOnOverscan
            sta WSYNC
            lda #$00
            sta PF0
            sta PF1
            sta PF2
            sta COLUBK
            ldx temp_t                   ;3   --
            txs                          ;2   --

            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop

            jmp newFrame

;------------------------
; splash kernel

kernel_showSplash
            lda SPLASH_GRAPHICS,x 
            sta COLUBK
            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35

            ldx #192
waitOnSplash
            sta WSYNC
            dex
            bne waitOnSplash

            dec game_timer
            bne keepSplashing
            ; next screen
            lda #SPLASH_DELAY
            sta game_timer
            inc game_state
            bmi keepSplashing
            ; next screen will be menu
            lda #GAME_STATE_MENU
            sta game_state

keepSplashing
            jmp waitOnOverscan

;------------------------
; exit update sub

waitOnVBlank
            ldx #$00
waitOnVBlank_loop          
            cpx INTIM
            bmi waitOnVBlank_loop
            stx VBLANK
            rts 

;---------------------------
; bit graphics
; A
; B
; C
; E
; F
; H
; L 
; R
; T
; U

; a
; c
; d
; e
; g
; i
; j
; l
; n
; o
; p
; r
; s
; n
; t
; y
; .
    ORG $FB00
P2_WALLS
    byte #$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff

    ORG $FC00
P1_WALLS
    byte #$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff
    byte #$fc,#$f8,#$f0,#$c0,#$80,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$80,#$c0,#$f0,#$f8,#$fc
    byte #$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff,#$ff
    
    ORG $FD00

    ORG $FF00
WALL_COLORS
    byte #$00,#$02,#$04,#$06,#$08,#$0a,#$0c,$0e,#$00,#$02,#$04,#$06,#$08,#$0a,#$0c,$0e
PLAYFIELD_COLORS
    byte #$04,#$04,#$04,#$04,#$04,#$04,#$04,#$04,#$08,#$08,#$08,#$08,#$08,#$08,#$08,#$08
BALL_GRAPHICS
    byte #$18,#$3c,#$5e,#$7e,#$ff,#$ff,#$ff,#$ff,#$7e,#$7e,#$3c,#$18,#$00,#$00
BALL_BOUNCE_DIR
    byte #$ff,#$ff,#$ff,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$01,#$01,#$01
SPLASH_0_GRAPHICS
    byte $ff ; loading...   message incoming... (scratching)
SPLASH_1_GRAPHICS
    byte $ef ; Presenting... (chorus rising)
SPLASH_2_GRAPHICS
    byte $df ; REFHRAKTOR / (deep note 3/31 .. scrolling) 
SPLASH_GRAPHICS
    byte $00 ; -- to menu - ReFhRaKtOrB - players - controls - menu

    ORG $FFFA

    .word reset          ; NMI
    .word reset          ; RESET
    .word reset          ; IRQ

    END