
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
LOGO_COLOR = $C4
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
WALL_COLOR = $92
BALL_COLOR = $2A
LOGO_COLOR = $53
SCANLINES = 262
#endif

GAME_STATE_SPLASH_0   = -3
GAME_STATE_SPLASH_1   = -2
GAME_STATE_SPLASH_2   = -1
GAME_STATE_PLAY       = 0
GAME_STATE_CELEBRATE  = 1
GAME_STATE_DROP       = 2
GAME_STATE_GAME_OVER  = 3
GAME_STATE_MENU       = 4
GAME_STATE_START      = 5

NUM_PLAYERS        = 2
NUM_AUDIO_CHANNELS = 2

DROP_DELAY            = 63
SPLASH_DELAY          = 31
CELEBRATE_DELAY       = 127

PLAYFIELD_WIDTH = 154
PLAYFIELD_VIEWPORT_HEIGHT = 80
PLAYFIELD_BEAM_RES = 16

PLAYER_MIN_X = 6
PLAYER_MAX_X = 140
BALL_MIN_X = 12
BALL_MAX_X = 132

GOAL_SCORE_DEPTH = 4
GOAL_HEIGHT = 16
BALL_HEIGHT = BALL_GRAPHICS_END - BALL_GRAPHICS
PLAYER_HEIGHT = TARGET_1 - TARGET_0
TITLE_HEIGHT = TITLE_96x2_01 - TITLE_96x2_00

LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

game_state   ds 1  ; current game state
game_timer   ds 1  ; countdown

frame        ds 1  ; frame counter

audio_tracker ds 2  ; next track
audio_timer   ds 2  ; time left on audio

player_opt    ds 2  ; player options (d0 = ball tracking on/off, d1 = manual aim on/off)
player_state  ds 2  ; player state (d1 = fire)
player_x      ds 2  ; player x position
player_aim_x  ds 2  ; player aim point x
player_aim_y  ds 2  ; player aim point y
player_bg     ds 4  ; 
player_color  ds 4  ;
player_sprite ds 4  ;
player_score  ds 2  ;
laser_ax      ds 2  ;
laser_ay      ds 2  ;
laser_color   ds 2  ;
temp_x_travel 
laser_lo_x    ds 1  ; start x for the low laser
laser_hmov_0  ds PLAYFIELD_BEAM_RES
laser_hmov_1  ds PLAYFIELD_BEAM_RES

ball_y       ds 2 
ball_x       ds 2
ball_dy      ds 2
ball_dx      ds 2
ball_ay      ds 2
ball_ax      ds 2
ball_color   ds 1
ball_voffset ds 1 ; ball position countdown
ball_cx      ds BALL_HEIGHT ; collision registers

scroll       ds 1 ; y value to start showing playfield

display_playfield_limit ds 1 ; counter of when to stop showing playfield

temp_grid_gap
temp_stack            ; hold stack ptr during collision capture
temp_dy          ds 1 ; use for line drawing computation
temp_grid_inc
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
    lda #DROP_DELAY
    sta game_timer
    lda #GAME_STATE_MENU ; GAME_STATE_SPLASH_0
    sta game_state
    lda #TRACK_0      ; start sound
    sta audio_tracker
    sta audio_tracker + 1

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

            ldx #NUM_AUDIO_CHANNELS - 1
audio_loop 
            lda audio_tracker,x
            beq audio_next_channel
            ldy audio_timer,x
            beq _audio_next_note
            dey
            sty audio_timer,x
            jmp audio_next_channel
_audio_next_note
            tay
            lda AUDIO_TRACKS,y
            beq _audio_pause
            cmp #255
            beq _audio_stop
            sta AUDC0,x
            iny
            lda AUDIO_TRACKS,y
            sta AUDF0,x
            iny
            lda AUDIO_TRACKS,y
            sta AUDV0,x
            jmp _audio_next_timer
_audio_pause
            lda #$0
            sta AUDC0,x
            sta AUDV0,x
_audio_next_timer
            iny
            lda AUDIO_TRACKS,y
            sta audio_timer,x
            iny
            sty audio_tracker,x
            jmp audio_next_channel
_audio_stop
            lda #$0
            sta AUDV0,x
            sta audio_tracker,x
            sta audio_timer,x
audio_next_channel
            dex
            bpl audio_loop

            ldx game_state
            beq kernel_playGame
            bmi jmpSplash
            dex
            beq kernel_celebrateScore
            dex
            beq kernel_dropBall
            dex 
            beq kernel_gameOver
            dex
            beq jmpMenu
            dex 
            jmp kernel_startGame
jmpMenu
            jmp kernel_menu
jmpSplash
            jmp kernel_showSplash

;--------------------
; gameplay update kernel

kernel_startGame
kernel_gameOver

kernel_dropBall
            ; ball state
            lda #64 - BALL_HEIGHT / 2
            sta ball_y
            lda #PLAYER_HEIGHT / 2 - BALL_HEIGHT / 2
            sta player_aim_y
            sta player_aim_y + 1
            lda #PLAYFIELD_WIDTH / 2 - BALL_HEIGHT / 2
            sta ball_x
            sta player_aim_x
            sta player_aim_x + 1
            lda #$00
            sta ball_ax
            sta ball_ax + 1
            sta ball_ay
            sta ball_ay + 1
            sta ball_dx
            sta ball_dx + 1
            sta ball_dy
            sta ball_dy + 1
            ; animate ball drop
            lda game_timer
            and #$01
            bne _drop_flicker_ball
            lda #BALL_COLOR
            jmp _drop_save_ball_color
_drop_flicker_ball
            lda #$00
_drop_save_ball_color
            sta ball_color
_drop_count_down
            dec game_timer
            bne _drop_continue
_drop_init_game
            ; init to game
            lda #BALL_COLOR
            sta ball_color
            lda #GAME_STATE_PLAY
            sta game_state
_drop_continue
            jmp scroll_update

kernel_celebrateScore
            ; TODO: something to celebrate            
            inc ball_color
            dec game_timer
            bne _celebrate_continue
            lda #DROP_DELAY
            sta game_timer
            lda #GAME_STATE_DROP
            sta game_state
_celebrate_continue
            jmp scroll_update ; skip ball update

kernel_playGame

ball_score_check
            lda ball_y
            cmp #GOAL_SCORE_DEPTH
            bcs _ball_score_lo_check
            jmp _ball_score_celebrate
            inc player_score
_ball_score_lo_check
            cmp #127 - GOAL_SCORE_DEPTH - BALL_HEIGHT
            bcc _ball_score_end
            inc player_score + 1
_ball_score_celebrate
            ; next screen will be score celebration
            lda #CELEBRATE_DELAY
            sta game_timer
            lda #GAME_STATE_CELEBRATE
            sta game_state
_ball_score_end

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
            jmp _ball_update_cx_end_acc
_ball_update_cx_top
            ABS16 ball_dy
            jmp _ball_update_cx_end
_ball_update_cx_horiz
            INV16 ball_dx
            jmp _ball_update_cx_end
_ball_update_cx_bottom
            NEG16 ball_dy
_ball_update_cx_end_acc
            ; apply acceleration if no collision
            ADD16 ball_dx, ball_ax
            ADD16 ball_dy, ball_ay
_ball_update_cx_end

ball_update_hpos
            ADD16 ball_x, ball_dx
            CLAMP_REFLECT_16 ball_x, ball_dx, BALL_MIN_X, BALL_MAX_X

ball_update_vpos
            ADD16 ball_y, ball_dy
            CLAMP_REFLECT_16 ball_y, ball_dy, 2, 127 - 2 - BALL_HEIGHT

; TODO; friction
; ball_decay_velocity
;             DOWNSCALE16_8 ball_dx, 1
;             DOWNSCALE16_8 ball_dy, 1

scroll_update
            lda ball_y
            sec 
            sbc #PLAYFIELD_VIEWPORT_HEIGHT / 2 - BALL_HEIGHT / 2
            bcc _scroll_update_up
            cmp #127 - PLAYFIELD_VIEWPORT_HEIGHT
            bcc _scroll_update_store
            lda #127 - PLAYFIELD_VIEWPORT_HEIGHT - 1
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
            ; firing - auto-aim
            lda ball_x
            sta player_aim_x,x
            lda ball_voffset
            sta player_aim_y,x
            lda #$08
            jmp _player_end_fire
_player_no_fire            
            lda player_state,x
            beq _player_end_fire
            sec
            sbc #$01
_player_end_fire
            sta player_state,x
_player_aim_beam
            ; calc distance between player and aim point
            lda player_aim_y,x
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
            sbc player_aim_x,x    ; dx
            jmp _player_aim_beam_interp
_player_aim_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            tay           ; dy
            lda #laser_hmov_0
            sta temp_draw_buffer ; point to middle of beam hmov stack
            lda player_aim_x,x
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
            bpl _player_draw_beam_skip_bump_hmov
            ; need an hmov
            lda temp_D
            sec
            sbc temp_dy  ; D = D - 2 * dy
            sta temp_D
            lda temp_hmove
            inc temp_x_travel
_player_draw_beam_skip_bump_hmov
            sta (temp_draw_buffer),y ; cheating that #$01 is in a
            lda temp_D
            clc
            adc temp_dx  ; D = D + 2 * dx
            sta temp_D
            dey
            bpl _player_draw_beam_loop
            lda player_state,x
            and #$02
            bne _player_update_next_player
            ; calc ax/ay coefficient
            ldy #$f0
            sec
            lda #PLAYFIELD_BEAM_RES * 2
            sbc temp_x_travel
            cpx #$00
            bne _player_draw_beam_skip_invert_ay
            ldy #$10
            eor #$ff
            clc
            adc #$01
_player_draw_beam_skip_invert_ay
            sta laser_ay,x
            lda temp_x_travel
            cpy temp_hmove 
            beq _player_draw_beam_skip_invert_ax
            eor #$ff
            clc
            adc #$01
_player_draw_beam_skip_invert_ax
            sta laser_ax,x
_player_update_next_player
            ;; next player
            dex
            bmi _player_update_end
            jmp _player_update_loop
_player_update_end
            
refract_lo_calc
            ; find lo player beam starting point
            ; last temp_x_travel will have the (signed) x distance covered  
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
            cmp #160 ; compare to screen width
            bcc refract_lo_skip_rollover
            sbc #96
refract_lo_skip_rollover
            sta laser_lo_x


;---------------------
; end vblank

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #1
            sta CTRLPF ; reflect playfield
            lda #WALL_COLOR
            sta COLUPF
            jmp playfield_start

    ; try to avoid page branching problems
    ORG $F400

playfield_start

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
            lda (player_bg+2),y     ;6  12
            sta COLUBK              ;3  15
            lda (player_sprite+2),y ;6  21
            sta GRP1                ;3  23
            lda (player_color+2),y  ;6  29
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
            lda ball_x              ;3   3
            sec                     ;2   5
_ball_resp_loop
            sbc #15                 ;2   7
            sbcs _ball_resp_loop    ;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMP0                ;3  18+
            sta HMP1                ;3  21+
            sta RESP0               ;3  24+
            sta RESP1               ;3  27+

 ; BUGBUG: vdelay?
            ; hmove ball, shadow 
            sta WSYNC                    ;3   0
            sta HMOVE                    ;3   3
            lda ball_color               ;3   6
            bne _ball_resp_color
            sta ball_voffset
_ball_resp_color
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
            lda laser_lo_x          ;3   3
            sec                     ;2   5
_lo_resp_loop
            sbc #15                 ;2   7
            sbcs _lo_resp_loop      ;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMM0                ;3  18+
            SLEEP 6                 ;6  24+
            sta RESM0               ;3  27+

            ; hmove ++ and prep for playfield next line
            sta WSYNC                    ;0   0
            sta HMOVE                    ;3   3
            lda player_state+1           ;3   6
            sta ENAM1                    ;3   9
            and #$02
            beq _skip_laser_color_1
            lda laser_color+1            ;3  18
            sta COLUP1                   ;3  21
_skip_laser_color_1
            lda player_state+0           ;3  12
            sta ENAM0                    ;3  15
            and #$02
            beq _skip_laser_color_2
            lda laser_color              ;-----
            sta COLUP0                   ;-----            
_skip_laser_color_2
            ldy scroll                   ;3  24
            lda #$00                     ;2  26 
            sta HMP0                     ;3  29 
            sta HMP1                     ;3  32
            sta temp_beam_index          ;3  35
            lda #$01                     ;2  37
            sta VDELP1                   ;3  40
            jmp playfield_loop_0         ;3  43

    ; try to avoid page branching problems
    ORG $F500

playfield_loop_0
            sta WSYNC                    ;3   0
_playfield_loop_0_hm
            lda P0_WALLS,y               ;4   4
            sta PF0                      ;3   7
            lda P1_WALLS,y               ;4  11
            sta PF1                      ;3  14
            lda P2_WALLS,y               ;4  18
            sta PF2                      ;3  21
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
            lda #$00                     ;2  52
            jmp _pl0_end_grp_0           ;3  55
_pl0_draw_grp_0
            lda BALL_GRAPHICS,x          ;4  55
_pl0_end_grp_0
            sta GRP0                     ;3  58
            sta GRP1                     ;3  61
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
           lda #$00
           sta ENAM0
           sta ENAM1
           sta PF0
           sta PF1
           sta PF2
           sta ball_ax + 1
           sta ball_ax
           sta ball_ay + 1
           sta ball_ay
           sta VDELP1
_laser_hit_test_hi
           lda #$80
           and CXM1P
           beq _laser_hit_test_lo
           inc laser_color + 1
           ADD16_8 ball_ax, laser_ax + 1
           ADD16_8 ball_ay, laser_ay + 1
_laser_hit_test_lo
           lda #$40
           and CXM0P
           beq _laser_hit_test_end
           ADD16_8 ball_ax, laser_ax
           ADD16_8 ball_ay, laser_ay
_laser_hit_test_end     
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

            ldx #6
playfield_shim_loop
            sta WSYNC
            dex
            bne playfield_shim_loop

;--------------------
; Overscan start

waitOnOverscan
            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop

            jmp newFrame

;------------------------
; menu kernel

kernel_menu

menu_update
            ldx #NUM_PLAYERS - 1
_menu_update_loop
            lda INPT4,x
            bmi _menu_update_no_fire
            lda #$01
            jmp _menu_update_end_fire
_menu_update_no_fire            
            lda player_state,x
            beq _menu_update_end_fire
            ; kill sound
            lda #0
            sta AUDC0
            sta AUDF0
            sta AUDC0
            ; change loop
            lda #GAME_STATE_DROP
            sta game_state
            lda #0
_menu_update_end_fire
            sta player_state,x
            dex
            bpl _menu_update_loop
menu_update_end

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #192 / 2 - TITLE_HEIGHT * 2 - 10
menu_waitOnMenu_top
            sta WSYNC
            dex
            bne menu_waitOnMenu_top

menu_setup    
            lda #3      ;3=Player and Missile are drawn twice 32 clocks apart 
            sta NUSIZ0    
            sta NUSIZ1    
            lda #LOGO_COLOR
            sta COLUP0        ;3
            sta COLUP1          ;3
            ldy #TITLE_HEIGHT - 1
            lda #$01
            and frame
            beq jmp_menu_96x2_resp_frame_0
            jmp menu_96x2_resp_frame_1  
jmp_menu_96x2_resp_frame_0
            jmp menu_96x2_resp_frame_0

menu_codeEnd
            lda #0 
            sta NUSIZ0    
            sta NUSIZ1    
            sta GRP0
            sta GRP1
            sta WSYNC

            ldx #SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 42
            lda #$00
            sta temp_grid_inc
            lda #$01
            sta temp_grid_gap
            tay 
menu_waitOnMenu_bottom
            sta WSYNC
            dey
            beq menu_drawGridLine 
            lda #$00
            sta COLUBK
            jmp menu_nextGridLine
menu_drawGridLine
            lda #LOGO_COLOR
            sta COLUBK
            lda temp_grid_gap
            asl
            sta temp_grid_gap
            clc
            adc temp_grid_inc
            tay
menu_nextGridLine
            dex
            bne menu_waitOnMenu_bottom

            jmp waitOnOverscan

	align 256
    
menu_96x2_resp_frame_0
            ; position P0 and P1
            ; TODO: cleanup
            sta WSYNC
            lda #%11100000
            sta HMP0
            lda #%00010000
            sta HMP1
            sta WSYNC
            sleep 28
            sta RESP0
            sleep 14
            sta RESP1
            sta WSYNC
            sta HMOVE
            sta WSYNC
            sta HMCLR
            sta WSYNC              ;3   0
            SLEEP 7                ;7   7

menu_96x2_frame_0
            SLEEP 8                ;8  15
            lda TITLE_96x2_06,y    ;4  19
            sta GRP1               ;3  22
            lda TITLE_96x2_00,y    ;4  26
            sta GRP0               ;3  29 - any
            lda TITLE_96x2_02,y    ;4  33
            sta GRP0               ;3  36 - 36
            lda TITLE_96x2_04,y    ;4  40
            sta GRP0               ;3  43 - 43
            SLEEP 2                ;2  45
            lda TITLE_96x2_08,y    ;4  49
            sta GRP1               ;3  52 - 52
            lda TITLE_96x2_10,y    ;4  56
            sta GRP1               ;3  59 - 59
            lda TITLE_96x2_01,y    ;4  63
            sta GRP0               ;3  66 - 66
            lda #$80               ;2  68
            sta HMP0               ;3  71
            sta HMP1               ;3  74
            sta HMOVE              ;3   1 ; HMOVE $80@74 = +8
            SLEEP 16               ;16 17
            lda #0                 ;2  19
            sta HMP0               ;3  22
            sta HMP1               ;3  25
            lda TITLE_96x2_07,y    ;4  29
            sta GRP1               ;3  32 - any
            lda TITLE_96x2_03,y    ;4  36
            sta GRP0               ;3  39 - 39
            lda TITLE_96x2_05,y    ;4  41
            sta GRP0               ;3  46 - 46
            SLEEP 2                ;2  48
            lda TITLE_96x2_09,y    ;4  52
            sta GRP1               ;3  55 - 55
            lda TITLE_96x2_11,y    ;4  59
            sta GRP1               ;3  62 - 62
            SLEEP 9                ;9  71
            sta HMOVE              ;3  74 ; HMOVE $00@71 = -8
            SLEEP 4                ;4   2
            dey                    ;2   4        
            sbpl menu_96x2_frame_0 ;2/+ 6/7
            jmp menu_codeEnd
	
	align 256

menu_96x2_resp_frame_1
            ; position P0 and P1
            ; TODO: cleanup
            sta WSYNC
            lda #%00100000
            sta HMP0
            lda #%11110000
            sta HMP1
            sta WSYNC
            sleep 32
            sta RESP0
            sleep 12
            sta RESP1
            sta WSYNC
            sta HMOVE
            sta WSYNC
            sta HMCLR
            sta WSYNC              ;3   0
            SLEEP 7                ;7   7

menu_96x2_frame_1 ; on entry HMP+0, on loop HMP+8
            sta HMOVE              ;3  10 ; HMOVE $80@6 = +8
            lda TITLE_96x2_07,y    ;4  14
            sta GRP1               ;3  17
            lda #$00               ;2  19 - TODO: dangerous?
            sta HMP0               ;3  22
            sta HMP1               ;3  25
            lda TITLE_96x2_01,y    ;4  29 
            sta GRP0               ;3  32 - 32
            lda TITLE_96x2_03,y    ;4  36
            sta GRP0               ;3  39 - 39
            lda TITLE_96x2_05,y    ;4  45
            sta GRP0               ;3  46 - 46
            SLEEP 2                ;2  48
            lda TITLE_96x2_09,y    ;4  52
            sta GRP1               ;3  55 - 55
            lda TITLE_96x2_11,y    ;4  59
            sta GRP1               ;3  62 - 62
            lda TITLE_96x2_00,y    ;4  66
            sta GRP0               ;3  69 - 69
            sta.w HMOVE            ;4  73 ; HMOVE $00@69-73 = -8
            SLEEP 25               ;25 22
            lda TITLE_96x2_06,y    ;4  26
            sta GRP1               ;3  29 - any
            lda TITLE_96x2_02,y    ;4  33
            sta GRP0               ;3  36 - 36
            lda TITLE_96x2_04,y    ;4  40
            sta GRP0               ;3  43 - 43
            SLEEP 2                ;2  45 
            lda TITLE_96x2_08,y    ;4  49
            sta GRP1               ;3  52 - 52
            lda TITLE_96x2_10,y    ;4  56
            sta GRP1               ;3  59 - 59
            SLEEP 3                ;3  62
            lda #$80               ;2  64
            sta HMP0               ;3  67
            sta HMP1               ;3  70
            SLEEP 8                ;8   2
            dey                    ;2   4        
            sbpl menu_96x2_frame_1 ;2/+ 6/7
            jmp menu_codeEnd

;------------------------
; splash kernel

kernel_showSplash
            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #160 / 2
waitOnSplash
            sta WSYNC
            dex
            bne waitOnSplash

            ldx #160 / 2
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

    ORG $FC00

TITLE_96x2_00
    byte %00000000
    byte %00001000
    byte %00011000
    byte %00111000
    byte %00101001
    byte %00101111
    byte %00101111
    byte %00101011
    byte %00101001
    byte %00101000
    byte %01111111
    byte %11111111

TITLE_96x2_01
    byte %00000000
    byte %00000100
    byte %00011001
    byte %01110011
    byte %11100011
    byte %11000000
    byte %10000011
    byte %11000000
    byte %11100011
    byte %11100011
    byte %11100010
    byte %11000000

TITLE_96x2_02
    byte %00000000
    byte %00000000
    byte %11111100
    byte %11111001
    byte %11110011
    byte %00000011
    byte %11100011
    byte %00000011
    byte %10000011
    byte %00000000
    byte %00000011
    byte %00000011

TITLE_96x2_03
    byte %00000000
    byte %00000010
    byte %00000011
    byte %00000011
    byte %00000011
    byte %00000011
    byte %00000011
    byte %11000011
    byte %11100011
    byte %00000011
    byte %11111001
    byte %11111100

TITLE_96x2_04
    byte %00100000
    byte %00110000
    byte %00110001
    byte %11110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00100111
    byte %00001111

TITLE_96x2_05
    byte %00000000
    byte %10000000
    byte %10000001
    byte %10000111
    byte %10011110
    byte %11111100
    byte %11111000
    byte %10111100
    byte %10011110
    byte %10001110
    byte %11111110
    byte %11111100

TITLE_96x2_06
    byte %00000000
    byte %01000000
    byte %10000000
    byte %00110000
    byte %00110111
    byte %00110001
    byte %00110011
    byte %00010111
    byte %00001110
    byte %00011100
    byte %00111000
    byte %00110000

TITLE_96x2_07
    byte %00000000
    byte %00000000
    byte %00000000
    byte %01110011
    byte %11100111
    byte %11001110
    byte %10011100
    byte %00111100
    byte %01110110
    byte %00111011
    byte %00011101
    byte %00001110

TITLE_96x2_08
    byte %00000000
    byte %00000000
    byte %00000001
    byte %10000011
    byte %00000010
    byte %00000010
    byte %00000010
    byte %00000010
    byte %00000010
    byte %00000010
    byte %10001111
    byte %11011111

TITLE_96x2_09
    byte %00000000
    byte %10001000
    byte %10011100
    byte %10011010
    byte %10011101
    byte %10011010
    byte %10011001
    byte %10011000
    byte %10011100
    byte %10001111
    byte %11100111
    byte %11110011

TITLE_96x2_10
    byte %00000000
    byte %00000010
    byte %00000110
    byte %00001110
    byte %00001110
    byte %10001111
    byte %01001111
    byte %11001110
    byte %11001110
    byte %11001110
    byte %10011111
    byte %00111111

TITLE_96x2_11
    byte %00000000
    byte %00000001
    byte %00000110
    byte %00011100
    byte %01111000
    byte %11110000
    byte %11100000
    byte %11110000
    byte %01111000
    byte %00111000
    byte %11111000
    byte %11110000

    ORG $FD00
P2_WALLS
    byte #$ff,#$ff,#$ff,#$ff,#$07,#$07,#$03,#$03
    byte #$01,#$01,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$01,#$01
    byte #$03,#$03,#$07,#$07,#$ff,#$ff,#$ff,#$ff

P1_WALLS
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    byte #$ff,#$ff,#$ff,#$7f,#$01,#$01,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    byte #$01,#$01,#$01,#$01,#$01,#$01,#$01,#$01
    
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$01,#$01,#$ff,#$ff,#$ff,#$7f
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    
    ORG $FE00
P0_WALLS
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

PLAYFIELD_COLORS
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09

    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09

    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09

    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$09,#$09,#$09,#$09
    byte #$09,#$09,#$09,#$09,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

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

AUDIO_TRACKS ; AUDCx,AUDFx,AUDVx,T
    byte 0,
TRACK_0 = . - AUDIO_TRACKS
    byte 3,31,15,64,3,31,7,16,3,31,3,8,3,31,1,16,255;

BALL_GRAPHICS
    byte #$3c,#$7e,#$ff,#$ff,#$ff,#$ff,#$7e,#$3c
BALL_GRAPHICS_END
SPLASH_0_GRAPHICS
    byte $ff ; loading... (8 bit console?)  message incoming... (scratching)
SPLASH_1_GRAPHICS
    byte $ef ; Presenting... (chorus rising)
SPLASH_2_GRAPHICS
    byte $df ; REFHRAKTOR / (deep note 3/31 .. scrolling) 
SPLASH_GRAPHICS
    byte $00 ; -- to menu - ReFhRaKtOr - players - controls - menu

    MAC CLAMP_REFLECT_16 ; given A, B, MIN, MAX 
            ; check bounds, reflect B if we hit
.clamp16_check_max
            lda #{4}
            cmp {1}
            bcs .clamp16_end
            sta {1}
            lda #$00
            sta {1} + 1
            lda {2}
            bmi .clamp16_end
            clc
            lda {2} + 1
            eor #$ff
            adc #$01
            sta {2} + 1
            lda {2}
            eor #$ff
            adc #$00
            sta {2}            
            jmp .clamp16_end
.clamp16_check_min
            lda #{3}
            cmp {1}
            bcc .clamp16_end
            sta {1}
            lda #$00
            sta {1} + 1
            lda {2}
            bpl .clamp16_end
            clc
            lda {2} + 1
            eor #$ff
            adc #$01
            sta {2} + 1
            lda {2}
            eor #$ff
            adc #$00
            sta {2}            
.clamp16_end
    ENDM

    MAC INV16 ; A = -A
            clc
            lda {1} + 1
            eor #$ff
            adc #$01
            sta {1} + 1
            lda {1}
            eor #$ff
            adc #$00
            sta {1}
    ENDM

    MAC ABS16 ; A = ABS(A)
            lda {1}
            bpl .abs16_end
            clc
            lda {1} + 1
            eor #$ff
            adc #$01
            sta {1} + 1
            lda {1}
            eor #$ff
            adc #$00
            sta {1}
.abs16_end
    ENDM

    MAC NEG16 ; A = -ABS(A)
            lda {1}
            bmi .neg16_end
            clc
            lda {1} + 1
            eor #$ff
            adc #$01
            sta {1} + 1
            lda {1}
            eor #$ff
            adc #$00
            sta {1}
.neg16_end
    ENDM

    MAC INC16 ;  A = A + #B
            clc
            lda {1} + 1
            adc #<{2}
            sta {1} + 1
            lda {1}
            adc #>{2}
            sta {1}
    ENDM

    MAC DEC16 ; A + A - #B
            clc
            lda {1} + 1
            adc #<{2}
            sta {1} + 1
            lda {1}
            adc #>{2}
            sta {1}
    ENDM

    MAC ADD16 ; Given A16, B16, store A + B -> A 
            clc
            lda {1} + 1
            adc {2} + 1
            sta {1} + 1
            lda {1}
            adc {2}
            sta {1}
    ENDM

    MAC DOWNSCALE16_8 ; Given A16, B8, store SIGN(A) * (ABS(A) - #B) -> A
            lda {1}
            bmi .downscale16_8_inv
            sec
            lda {1} + 1
            sbc #{2}
            sta {1} + 1
            sbc #$00
            bmi .downscale16_8_zero
            jmp .downscale16_8_end
.downscale16_8_inv
            clc
            lda {1} + 1
            adc #{2}
            sta {1} + 1
            adc #$00
            bpl .downscale16_8_end
.downscale16_8_zero
            lda #$00
            sta {1} + 1
.downscale16_8_end  
            sta {1}

    ENDM

    MAC ADD16_8 ; Given A16, B8, store A + B -> A 
            ldy #$00
            lda {2}
            bpl ._add16_8
            ldy #$ff
._add16_8
            clc
            adc {1} + 1
            sta {1} + 1
            tya
            adc {1}
            sta {1}
    ENDM

    ORG $FFFA

; game notes - MVP
; DONE
;  - make fire buttons work
;  - make lasers not be chained to ball 
;  - make ball move when fired on
;  - add goal area
;  - make ball score when reaching goal
;  - replace ball in center after score
; TODO
;  - clean up screen / make room for score
;  - alternate playfields
;  - goal shield and/or bricks
;  - initial, weak, opposing ai
;  - make lasers  still refract off ball
;  - friction      
;  - x collision bug (stuck)
;  - menu system
;  - manual aim ability
;  - auto move ability
;  - auto fire ability
;  - better colors
;  - add logo
;  - start / end game logic
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