
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

PLAYFIELD_WIDTH = 160
PLAYFIELD_VIEWPORT_HEIGHT = 80
PLAYFIELD_BEAM_RES = 16

PLAYER_MIN_X = 10
PLAYER_MAX_X = 140
BALL_MIN_X = 10
BALL_MAX_X = 140

GOAL_HEIGHT = 16
BALL_HEIGHT = BALL_GRAPHICS_END - BALL_GRAPHICS
PLAYER_HEIGHT = TARGET_1 - TARGET_0

LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

game_state   ds 1  ; current game state
game_timer   ds 1  ; countdown

frame        ds 1  ; frame counter

player_opt    ds 2  ; player options (d0 = ball tracking on/off, d1 = manual aim on/off)
player_state  ds 2  ; player state (d1 = fire)
player_x      ds 2  ; player x position
player_bg     ds 4  ; 
player_color  ds 4  ;
player_sprite ds 4  ;
laser_color   ds 2  ;
temp_x_travel 
laser_lo_x    ds 1  ; start x for the low laser
laser_hmov_0  ds PLAYFIELD_BEAM_RES
laser_hmov_1  ds PLAYFIELD_BEAM_RES

ball_y       ds 1 
ball_x       ds 1
ball_dy      ds 1
ball_dx      ds 1
ball_color   ds 1
ball_voffset ds 1 ; ball position countdown
ball_cx      ds BALL_HEIGHT ; collision registers

scroll       ds 1 ; y value to start showing playfield

display_playfield_limit ds 1 ; counter of when to stop showing playfield

temp_stack            ; hold stack ptr during collision capture
temp_dy          ds 1 ; use for line drawing computation
temp_beam_index       ; hold beam offset during playfield kernel 
temp_dx          ds 1
temp_D           ds 1
temp_hmove       ds 1
temp_draw_buffer ds 2

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
    lda #GAME_STATE_PLAY ; #GAME_STATE_SPLASH_0
    sta game_state

    ; player setup
    lda #>TARGET_0
    sta player_sprite + 1
    sta player_sprite + 3
    lda #<TARGET_0
    sta player_sprite + 0
    sta player_sprite + 2
    lda #>TARGET_BG_0
    sta player_bg + 1
    sta player_bg + 3
    lda #<TARGET_BG_0
    sta player_bg + 0
    sta player_bg + 2
    lda #>TARGET_COLOR_0
    sta player_color + 1
    sta player_color + 3
    lda #<TARGET_COLOR_0
    sta player_color + 0
    sta player_color + 2
    ldx #NUM_PLAYERS - 1
_player_setup_loop
    sta laser_color,x
    lda #$00
    sta player_opt,x
    lda #PLAYFIELD_WIDTH / 2
    sta player_x,x
    dex
    bpl _player_setup_loop

    ; ball positioning
    lda #BALL_COLOR
    sta ball_color
    lda #$01
    sta ball_dy
    lda #$00
    sta ball_dx
    lda #32 - BALL_HEIGHT / 2
    sta ball_y
    lda #PLAYFIELD_WIDTH / 2
    sta ball_x

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

            lda #%00000010
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
            bmi _ball_update_cx_top
            dex
_ball_update_cx_loop
            ora ball_cx,x
            bmi _ball_update_cx_horiz
            dex
            cpx #2
            bcs _ball_update_cx_loop
            ora ball_cx,x
            dex
            ora ball_cx,x
            bmi _ball_update_cx_bottom
            jmp ball_update_hpos
_ball_update_cx_top
            ldx #$01
            jmp _ball_update_cx_save_y
_ball_update_cx_horiz
            lda ball_dx
            eor #$ff
            clc
            adc #$01
            sta ball_dx
            jmp ball_update_hpos
_ball_update_cx_bottom
            ldx #$ff
_ball_update_cx_save_y
            stx ball_dy

ball_update_hpos
            ; ball x pos
            lda ball_dx
            bmi _ball_update_hpos_left
            clc
            adc ball_x
            cmp #BALL_MAX_X
            bcc _save_ball_hpos
            ldy #$ff
            sty ball_dx
            lda #BALL_MAX_X
            jmp _save_ball_hpos
_ball_update_hpos_left
            clc
            adc ball_x
            cmp #BALL_MIN_X    
            bcs _save_ball_hpos  
            lda #$01
            sty ball_dx
            lda #PLAYER_MIN_X
_save_ball_hpos
            sta ball_x

ball_update_vpos
            lda ball_dy
            bmi _ball_update_vpos_up
            clc
            adc ball_y
            cmp #255 - GOAL_HEIGHT - BALL_HEIGHT
            bcc _save_ball_vpos
            ldy #$ff
            sty ball_dy
            lda #255 - GOAL_HEIGHT - BALL_HEIGHT
            jmp _save_ball_vpos
_ball_update_vpos_up
            clc
            adc ball_y
            cmp #GOAL_HEIGHT
            bcs _save_ball_vpos 
            ldy #$01
            sty ball_dy
            lda #GOAL_HEIGHT
_save_ball_vpos
            sta ball_y
        
scroll_update
            sec ; assume a is ball_y
            sbc #PLAYFIELD_VIEWPORT_HEIGHT / 2 - BALL_HEIGHT / 2
            bcc _scroll_update_up
            cmp #255 - PLAYFIELD_VIEWPORT_HEIGHT
            bcc _scroll_update_store
            lda #255 - PLAYFIELD_VIEWPORT_HEIGHT -1
            jmp _scroll_update_store            
_scroll_update_up
            lda #0
_scroll_update_store
            sta scroll
            tay
            ; calc end of playfield
            clc
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            sta display_playfield_limit
            ; calc ball offset
            tya
            sec             
            sbc ball_y  
            sta ball_voffset          

player_update
            ldx #NUM_PLAYERS - 1
_player_update_loop
            ;
            ; TODO: control player
            ;
            ; manual player movement
            ldy #$00
            lda #$80
            cpx #$00
            beq _player_update_checkbits
            ldy #$02
            lda #$08
_player_update_checkbits
            bit SWCHA                 
            beq _player_update_right          
            lsr                      
            bit SWCHA                 
            beq _player_update_left       
            jmp _player_end_move
_player_update_right
            lda player_x,x
            cmp #PLAYER_MAX_X
            bcs _player_end_move
            adc #$01 
            sta player_x,x
            lda player_sprite,y ; bugbug can do indirectly?
            clc 
            adc #PLAYER_HEIGHT
            cmp #<TARGET_3
            bcc _player_update_anim_right
            lda #<TARGET_0
_player_update_anim_right
            sta player_sprite,y
            jmp _player_end_move
_player_update_left
            lda player_x,x
            cmp #PLAYER_MIN_X
            bcc _player_end_move
            sbc #$01
            sta player_x,x
            lda player_sprite,y ; bugbug can do indirectly?
            sec 
            sbc #PLAYER_HEIGHT
            cmp #<TARGET_0
            bcs _player_update_anim_left
            lda #<TARGET_3
_player_update_anim_left
            sta player_sprite,y
_player_end_move
            lda INPT4,x
            bmi _player_no_fire
            lda #$02
            jmp _player_end_fire
_player_no_fire            
            lda #$00
_player_end_fire
            sta player_state,x
_player_aim_beam
            ; auto-aim, calc distance between player and ball
            lda ball_voffset
            cpx #$00
            beq _player_aim_beam_lo
_player_aim_beam_hi
            eor #$ff      ; invert offset to get dy
            clc
            adc #$01
            tay            ; dy
            lda #laser_hmov_1
            sta temp_draw_buffer ; point at top of beam hmov stack
            lda player_x,x
            sec
            sbc ball_x    ; dx
            jmp _player_aim_beam_interp
_player_aim_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            tay           ; dy
            lda #laser_hmov_0
            sta temp_draw_buffer ; point to middle of beam hmov stack
            lda ball_x
            sec
            sbc player_x,x ; dx
_player_aim_beam_interp
            cpy #PLAYFIELD_BEAM_RES ; if dy < BEAM res, double everything
            bcs _player_aim_beam_end
            asl 
            sta temp_dx
            tya
            asl 
            tay
            lda temp_dx
_player_aim_beam_end
            ; figure out beam path
_player_draw_beam_calc ; on entry, a is dx (signed), y is dy (unsigned)
            sty temp_dy
            cmp #00
            bpl _player_draw_beam_left
            eor #$ff
            clc
            adc #$01
            cmp temp_dy
            bcc _player_draw_skip_normalize_dx_right
            tya
_player_draw_skip_normalize_dx_right
            sta temp_dx 
            lda #$f0
            jmp _player_draw_beam_set_hmov
_player_draw_beam_left
            cmp temp_dy
            bcc _player_draw_skip_normalize_dx_left
            tya
_player_draw_skip_normalize_dx_left
            sta temp_dx
            lda #$10
_player_draw_beam_set_hmov
            sta temp_hmove
            asl temp_dx  ; dx = 2 * dx
            lda temp_dx
            sec
            sbc temp_dy  ; D = 2dx - dy
            asl temp_dy  ; dy = 2 * dy
            sta temp_D
            lda #$00
            sta temp_x_travel
            ldy #PLAYFIELD_BEAM_RES - 1 ; will stop at 16
_player_draw_beam_loop
            lda #$01
            cmp temp_D
            bpl _skip_bump_hmov
            ; need an hmov
            lda temp_D
            sec
            sbc temp_dy  ; D = D - 2 * dy
            sta temp_D
            lda temp_hmove
            inc temp_x_travel
_skip_bump_hmov
            sta (temp_draw_buffer),y ; cheating that #$01 is in a
            lda temp_D
            clc
            adc temp_dx  ; D = D + 2 * dx
            sta temp_D
            dey
            bpl _player_draw_beam_loop
            dex
            bmi _player_update_end
            jmp _player_update_loop
_player_update_end
            
refract_lo_calc
            ; find lo player beam starting point
            ; last temp_x_travel will have the (unsigned) x distance covered  
            ; multiply by 5 to get 80 scanline x distance
            lda temp_x_travel
            asl 
            asl 
            clc
            adc temp_x_travel
            ldy temp_hmove 
            bpl refract_lo_skip_invert
            eor #$ff
            clc
            adc #$01
refract_lo_skip_invert
            adc player_x
            sec
            sbc #$05
            sta laser_lo_x


;---------------------
; end vblank

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #1
            sta CTRLPF ; reflect playfield
            lda #WALL_COLOR
            sta COLUPF


;---------------------
; laser track (hi)

            ; resp top player
            sta WSYNC               ;3   0
            lda player_x + 1        ;3   3
            sec                     ;2   5
_player_1_resp_loop
            sbc #15                 ;2   7
            sbcs _player_1_resp_loop;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMP1                ;3  18+
            sta HMM1                ;3  21+
            sta RESP1               ;3  24+ 
            sta RESM1               ;3  27+

            sta WSYNC
            sta HMOVE               ;3   3
            ldy #PLAYER_HEIGHT - 1  ;3   6
            lda (player_bg+2),y       ;6  12
            sta COLUBK              ;3  15
            lda (player_sprite+2),y   ;6  21
            sta GRP1                ;3  23
            lda (player_color+2),y    ;6  29
            sta COLUP1              ;3  32
            lda #$00                ;3  35
            sta HMP1                ;3  38
            lda #$50                ;3  41
            sta HMM1                ;3  44
            dey                     ;2  46

_player_1_draw_loop
            sta WSYNC
            lda (player_bg+2),y     ;6   6
            sta COLUBK              ;3   9
            lda (player_sprite+2),y ;6  15
            sta GRP1                ;3  18
            lda (player_color+2),y  ;6  24
            sta COLUP1              ;3  28
            dey                     ;2  30
            bpl _player_1_draw_loop ;2  32

;---------------------
; playfield
           
            ; resp ball, shadow 
            sta WSYNC
            lda ball_x            ;3   3
            sec                   ;2   5
_ball_resp_loop
            sbc #15               ;2   7
            sbcs _ball_resp_loop  ;2   9
            tay                   ;2  11+
            lda LOOKUP_STD_HMOVE,y;4  15+
            sta HMP0              ;3  18+
            sta HMP1              ;3  21+
            sta RESP0             ;3  24+
            sta RESP1             ;3  27+

 ; BUGBUG: vdelay?
            ; hmove ball, shadow 
            sta WSYNC                    ;3   0
            sta HMOVE                    ;3   3
            lda ball_color               ;3   6
            sta COLUP0                   ;3   9
            ; point SP at collision register
            tsx                          ;2  11
            stx temp_stack               ;3  14
            ldx #ball_cx + BALL_HEIGHT-1 ;2  16
            txs                          ;2  18
            sta CXCLR                    ;3  21
            ; zero out hmoves what need zeros
            lda #$00                     ;2  23
            sta HMP0                     ;3  26
            sta HMM1                     ;3  29
            lda #$70                     ;2  31 ; shift P1/M0 back 7 clocks
            sta HMP1                     ;3  33

            ; resp lower beam
            sta WSYNC
            lda laser_lo_x        ;3   3
            sec                   ;2   5
_lo_resp_loop
            sbc #15               ;2   7
            sbcs _lo_resp_loop    ;2   9
            tay                   ;2  11+
            lda LOOKUP_STD_HMOVE,y;4  15+
            sta HMM0              ;3  18+
            SLEEP 6               ;6  24+
            sta RESM0             ;3  27+

            ; hmove ++ and prep for playfield next line
            sta WSYNC                    ;0   0
            sta HMOVE                    ;3   3
            lda player_state+1           ;3   6
            sta ENAM1                    ;3   9
            lda player_state+0           ;3  12
            sta ENAM0                    ;3  15
            lda laser_color+1            ;3  18
            sta COLUP1                   ;3  21
            ldy scroll                   ;3  24
            lda #$00                     ;2  26 
            sta HMP0                     ;3  29 
            sta HMP1                     ;3  32
            sta temp_beam_index          ;3  35
            jmp playfield_loop_0         ;3  38

    ; try to avoid page branching problems
    align 256

playfield_loop_0
            sta WSYNC                    ;3   0
_playfield_loop_0_hm
            PF_MACRO                     ;21 21
            ;; adjust playfield color
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            ;; set beam hmov
            ldx temp_beam_index          ;3  31             
            lda laser_hmov_0,x           ;4  35
            sta HMM0                     ;3  38
            lda laser_hmov_1,x           ;4  42
            sta HMM1                     ;3  45
            ;; ball graphics
            ldx ball_voffset             ;3  48
            sbpl _pl0_draw_grp_0         ;2  50
            SLEEP 8                      ;7  58
            jmp _pl0_end_grp_0           ;3  61
_pl0_draw_grp_0
            lda BALL_GRAPHICS,x          ;4  55
            sta GRP0                     ;3  58
            sta GRP1                     ;3  61
_pl0_end_grp_0
            SLEEP 5                      ;5  66
            ;; EOL
            lda #$00                     ;2  68
            sta COLUBK                   ;3  71 
            sta WSYNC                    ;3  --
            ;; 2nd line
            sta HMOVE                    ;3   3
            ;; 
            lda temp_beam_index          ;3   6
            clc                          ;2   8
            adc #$01                     ;2  10
            and #$0f                     ;2  12
            sta temp_beam_index          ;3  15
            SLEEP 6                      ;6  21
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            ;; ball offsets
            cpx #$00                     ;2  30
            sbmi _pl0_inc_ball_offset    ;2  32
            lda CXP0FB                   ;3  35
            pha                          ;3  38
            dex                          ;2  40
            sbmi _pl0_ball_end           ;2  42
            SLEEP 3                      ;3  45
            jmp _pl0_save_ball_offset    ;3  48
_pl0_ball_end
            ldx #128                     ;2  45
            jmp _pl0_save_ball_offset    ;3  48
_pl0_inc_ball_offset 
            SLEEP 8                      ;8  41
            inx                          ;2  43
            sbeq _pl0_ball_start         ;2  45
            jmp _pl0_save_ball_offset    ;3  48
_pl0_ball_start 
            ldx #BALL_HEIGHT - 1         ;2  48
_pl0_save_ball_offset
            stx ball_voffset             ;3  51
            SLEEP 10                     ;10 61
            ;; EOL
            lda #$00                     ;2  63
            iny                          ;2  65
            cpy display_playfield_limit  ;3  68
            sta COLUBK                   ;3  71
            SLEEP 2                      ;2  73
            sbcc _playfield_loop_0_hm    ;2  --

playfield_end

           sta WSYNC
           sta WSYNC 

;---------------------
; laser track (lo)

            ; resp lo player
            sta WSYNC               ;3   0
            lda player_x            ;3   3
            sec                     ;2   5
_player_0_resp_loop
            sbc #15                 ;2   7
            sbcs _player_0_resp_loop;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMP0                ;3  18+
            sta HMM0                ;3  21+ ; just for timing shim
            sta RESP0               ;3  24+ 

            sta WSYNC
            sta HMOVE               ;3   3
            ldy #$00                ;3   6
            lda (player_bg),y       ;6  12
            sta COLUBK              ;3  15
            lda (player_sprite),y   ;6  21
            sta GRP0                ;3  23
            lda (player_color),y    ;6  29
            sta COLUP0              ;3  32
            lda #$00                ;3  35
            sta HMP0                ;3  38
            sta ENAM0               ;3  41
            iny                     ;2  43

_player_0_draw_loop
            sta WSYNC
            lda (player_bg),y       ;6   6
            sta COLUBK              ;3   9
            lda (player_sprite),y   ;6  15
            sta GRP0                ;3  18
            lda (player_color),y    ;6  24
            sta COLUP0              ;3  28
            iny                     ;2  30
            cpy #PLAYER_HEIGHT      ;2  32
            bcc _player_0_draw_loop ;2  34

; kernel exit

            ldx temp_stack               ;3   --
            txs                          ;2   --

;--------------------
; Overscan start

waitOnOverscan
            sta WSYNC
            lda #$00
            sta PF0
            sta PF1
            sta PF2
            sta GRP0
            sta GRP1
            sta ENAM0
            sta ENAM1
            sta COLUBK

            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop

            jmp newFrame

;------------------------
; splash kernel

kernel_showSplash
            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #192 / 2
waitOnSplash
            sta WSYNC
            dex
            bne waitOnSplash

            ldx #192 / 2
            ldy #8
drawSplashGrid
            sta WSYNC
            lda #0
            dey
            bne skipDrawGridLine 
            ldy #8
            lda SPLASH_GRAPHICS,x 
skipDrawGridLine
            sta COLUBK
            dex
            bne drawSplashGrid


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

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END

TARGET_0
    byte $00,$18,$7e,$77,$55,$55,$77,$7e,$3c; 8
TARGET_1
    byte $00,$18,$7e,$ee,$aa,$aa,$ee,$7e,$3c; 8
TARGET_2
    byte $00,$18,$7e,$dd,$55,$55,$dd,$7e,$3c; 8
TARGET_3
    byte $00,$18,$7e,$bb,$aa,$aa,$bb,$7e,$3c; 8
TARGET_COLOR_0
    byte $00,$0a,$0c,$0e,$0e,$0e,$0e,$0c,$0a; 8
TARGET_BG_0
    byte $00,$02,$00,$02,$00,$02,$00,$02,$00; 8

BALL_GRAPHICS
    byte #$00,#$18,#$3c,#$7e,#$ff,#$ff,#$7e,#$3c,#$18
BALL_GRAPHICS_END
SPLASH_0_GRAPHICS
    byte $ff ; loading... (8 bit console?)  message incoming... (scratching)
SPLASH_1_GRAPHICS
    byte $ef ; Presenting... (chorus rising)
SPLASH_2_GRAPHICS
    byte $df ; REFHRAKTOR / (deep note 3/31 .. scrolling) 
SPLASH_GRAPHICS
    byte $00 ; -- to menu - ReFhRaKtOr - players - controls - menu

    MAC PF_MACRO
            lda P0_WALLS,y               ;4   4
            sta PF0                      ;3   7
            lda P1_WALLS,y               ;4  11
            sta PF1                      ;3  14
            lda P2_WALLS,y               ;4  18
            sta PF2                      ;3  21
    ENDM

    ORG $FFFA

; game notes - MVP
; DONE
;  - make fire buttons work
; TODO
;  - make lasers not be chained to ball but still refract off ball
;  - make ball move when fired on
;  - make ball score when reaching
;  - score transition
;  - manual aim ability
;  - auto move ability
;  - auto fire ability
;  - better colors
;  - make room for score
;  - add logo
;  - start / end game logic
;  - menu system
;  - alternate playfields
;  - intro screen
;  - play with grid design
;  - game timer
;  - different ships
;  - start / end game cool transition
;

    .word reset          ; NMI
    .word reset          ; RESET
    .word reset          ; IRQ

    END