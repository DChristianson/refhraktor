
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
target_hmov  ds 2

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

temp_a
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
    lda #0
    sta target_hpos,x
    sta target_hmov,x
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
            tay
            ; calc end of playfield
            clc
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            sta display_playfield_limit
            ; calc ball offset
            tya
            sec             
            sbc ball_vpos  
            sta ball_voffset          

            ldx #NUM_PLAYERS - 1
            lda #$80 
player_update_loop
            ; update target hpos
            bit SWCHA                 
            beq player_right          
            lsr                      
            bit SWCHA                 
            beq player_left       
            jmp player_hpos_end
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
            jmp player_hpos_end
player_left
            lda #$10
            clc
            adc target_hpos,x
            bvc player_hpos_store
            adc #$0f
            tay
            and #$0f 
            cmp #$0b
            bpl player_hpos_end
player_hpos_store_y
            tya
player_hpos_store
            sta target_hpos,x
player_hpos_end

player_update_angle
            ; calc strobe distance between target and ball
            and #$0f
            sta temp_a
            lda ball_hpos
            and #$0f
            sec
            sbc temp_a
            tay 
            beq _end_count
            bcc _count_up
            lda #$00 ; BUGBUG should get fine pos
_count_down_loop
            sec
            sbc #$0f
            dey
            bne _count_down_loop
            jmp _end_count
_count_up
            lda #$00 ; BUGBUG should get fine pos
_count_up_loop
            clc
            adc #$0f
            iny
            bne _count_up_loop
            jmp _end_count
_end_count
            lsr ; div by 2
            tay
            lda TARGET_HMOV_TABLE,Y
            sta target_hmov
player_update_end
            lda #$08
            dex
            bpl player_update_loop


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
            SLEEP 7                      ;7  22
            lda #$00                     ;2  24
            sta HMP0                     ;3  27
            sta HMP1                     ;3  27
            sta HMM0
            sta HMM1
            lda #2                       ;2  29
            sta ENAM0                    ;3  32
            sta ENAM1                    ;3  35
            ldy scroll                   ;3  38
            ldx ball_voffset             ;3  41
            jmp playfield_loop_0


playfield_loop_0_hm
playfield_loop_0
            sta WSYNC                    ;3   0
            lda P0_WALLS,y               ;4   4
            sbne _skip_0                 ;2   6
            sta HMOVE                    ;3   9
            jmp _shim_0                  ;3  12
_skip_0
            SLEEP 5                      ;5  12
_shim_0
            sta PF0                      ;3  15
            lda P1_WALLS,y               ;4  19
            sta PF1                      ;3  22
            lda PLAYFIELD_COLORS,y       ;4  26
            sta COLUBK                   ;3  29
            lda P2_WALLS,y               ;4  33
            sta PF2                      ;3  36
            inx                          ;2  38
            beq playfield_loop_0_to_1    ;2  40
            SLEEP 23                     ;20 60
            lda #$00                     ;2  62
            iny                          ;2  64
            sta COLUBK                   ;3  67
            jmp playfield_loop_0_hm      ;3  70

playfield_loop_0_to_1
            SLEEP 16                     ;26 59     
            jmp playfield_loop_1_e       ;3  62 

playfield_loop_1_hm
            sta WSYNC                    ;3   0
            lda P0_WALLS,y               ;4   4
            sbne _skip_1                 ;2   6
            sta HMOVE                    ;3   9
            jmp _shim_1                  ;3  12
_skip_1
            SLEEP 5                      ;5  12
_shim_1
            sta PF0                      ;3  15
            lda P1_WALLS,y               ;4  19
            sta PF1                      ;3  39
            lda PLAYFIELD_COLORS,y       ;4  29
            sta COLUBK                   ;3  32
            lda P2_WALLS,y               ;4  43
            sta PF2                      ;3  46
            ; ball update 
            lda BALL_GRAPHICS,x          ;4  19
            sta GRP0                     ;3  22
            sta GRP1                     ;3  25
            SLEEP 2                      ;3  
            lda CXP0FB                   ;3  54
            pha                          ;3  57
            inx                          ;2  59
            cpx #BALL_HEIGHT             ;2  61
            sbcs playfield_loop_1_to_2   ;2  62
playfield_loop_1_e
            SLEEP 3
            lda #$00
            iny                          ;2  64
            sta COLUBK
            jmp playfield_loop_1_hm      ;3  71 

playfield_loop_1_to_2
            SLEEP 2
            lda #$00                     ;
            iny                          ;2  64 / 68
            sta COLUBK

playfield_loop_2_hm
            sta WSYNC                    ;3   0
            lda P0_WALLS,y               ;4   4
            sbne _skip_2                 ;2   6
            sta HMOVE                    ;3   9
            jmp _shim_2                  ;3  12
_skip_2
            SLEEP 5                      ;5  12
_shim_2
            sta PF0                      ;3  15
            lda P1_WALLS,y               ;4  19
            sta PF1                      ;3  22
            lda PLAYFIELD_COLORS,y       ;4  26
            sta COLUBK                   ;3  29
            lda P2_WALLS,y               ;4  33
            sta PF2                      ;3  36
            SLEEP 24                     ;24 60
            lda #$00                     ;
            iny                          ;2  64 / 68
            cpy display_playfield_limit  ;3  67 / 71
            sta COLUBK
            sbcc playfield_loop_2_hm      ;2  69 / 73

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
    ORG $FA00

    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

TARGET_HMOV_TABLE ; BUGBUG: fill out
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

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
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
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
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    
    ORG $FD00
P0_WALLS
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    ORG $FE00
PLAYFIELD_COLORS
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09

    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09

    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09

    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09,#$06,#$09,#$09,#$09,#$09,#$09
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

    ORG $FF00

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