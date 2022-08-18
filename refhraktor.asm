
    processor 6502
    include "vcs.h"
    include "macro.h"
    include "math.h"
    include "bank_switch_f8.h"

SUPERCHIP = 1

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

GAME_STATE_SPLASH_0     = -3
GAME_STATE_SPLASH_1     = -2
GAME_STATE_SPLASH_2     = -1
GAME_STATE_PLAY         = 0
GAME_STATE_CELEBRATE    = 1
GAME_STATE_DROP         = 2
GAME_STATE_GAME_OVER    = 3
GAME_STATE_TITLE        = 4 ; title screen
GAME_STATE_MENU_ROOT = 5 ; choose game type
GAME_STATE_MENU_PLAYERS = 6 ; choose equipment
GAME_STATE_MENU_STAGE   = 7 ; choose stage 
GAME_STATE_MENU_TUNE    = 8 ; choose chiptune
GAME_STATE_START        = 9

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

formation_select ds 1   ; which level

player_opt    ds 2  ; player options (d0 = ball tracking on/off, d1 = manual aim on/off)
player_state  ds 2  ; player state (d1 = fire)
player_sprite ds 4  ;

jx_on_press_down ds 2  ; on press code
jx_on_move       ds 2  ; on move code

formation_up     ds 2   ; formation obj ptr
formation_p0     ds 2   ; formation p0 ptr
formation_p1_dl  ds 16  ; playfield ptr pf1
formation_p2_dl  ds 16  ; playfield ptr pf2

player_x      ds 2  ; player x position
temp_strfmt_index_hi
player_aim_x  ds 2  ; player aim point x
temp_strfmt_index_lo
player_aim_y  ds 2  ; player aim point y
player_bg     ds 4  ; 
player_score  ds 2  ;
laser_ax      ds 2  ;
laser_ay      ds 2  ;
temp_strfmt_count
laser_color   ds 2  ;
temp_x_travel  
laser_lo_x    ds 1  ; start x for the low laser
laser_hmov_0  ds PLAYFIELD_BEAM_RES
;laser_hmov_1  ds PLAYFIELD_BEAM_RES

ball_y       ds 2 
ball_x       ds 2
ball_dy      ds 2
ball_dx      ds 2
ball_ay      ds 2
ball_ax      ds 2
ball_color   ds 1
ball_voffset ds 1 ; ball position countdown
ball_cx      ds BALL_HEIGHT ; collision registers


display_scroll    ; scroll adjusted to modulo block
scroll       ds 1 ; y value to start showing playfield

display_formation_jmp   ds 2   ; formation jump ptr
display_playfield_limit ds 1

temp_player_state
temp_grid_gap
temp_stack            ; hold stack ptr during collision capture
temp_dy          ds 1 ; use for line drawing computation
temp_grid_inc
temp_beam_index       ; hold beam offset during playfield kernel 
temp_jx_player_count 
temp_dx          ds 1 
temp_D           ds 1
temp_hmove       ds 1
temp_draw_buffer ds 2

; ----------------------------------
; menu RAM

  SEG.U SCRAM

STRING_BUFFER_0 = 0
STRING_BUFFER_1 = STRING_BUFFER_0 + 8
STRING_BUFFER_2 = STRING_BUFFER_1 + 8
STRING_BUFFER_3 = STRING_BUFFER_2 + 8
STRING_BUFFER_4 = STRING_BUFFER_3 + 8
STRING_BUFFER_5 = STRING_BUFFER_4 + 8
STRING_WRITE = SUPERCHIP_WRITE + STRING_BUFFER_0
STRING_READ = SUPERCHIP_READ + STRING_BUFFER_0

; ----------------------------------
; bank 0

  SEG bank_0_code

    START_BANK 0

    DEF_LBL fhrakas_kernel

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
            SLEEP 3                 ;3  21+
            sta RESP1               ;3  24+ 

            sta WSYNC
            sta HMOVE               ;3   3
            ldy #PLAYER_HEIGHT - 1  ;3   6
            lda (player_bg+2),y     ;6  12
            sta COLUBK              ;3  15
            lda (player_sprite+2),y ;6  21
            sta GRP1                ;3  23
            lda TARGET_COLOR_0,y    ;-----
            sta COLUP1              ;3  32
            lda #$00                ;3  35
            sta HMP1                ;3  38
            dey                     ;2  46

_player_1_draw_loop
            sta WSYNC
            lda (player_bg+2),y     ;6   6
            sta COLUBK              ;3   9
            lda (player_sprite+2),y ;6  15
            sta GRP1                ;3  18
            lda TARGET_COLOR_0,y    ;-----
            sta COLUP1              ;3  28
            dey                     ;2  30
            bpl _player_1_draw_loop ;2  32

;---------------------
; arena
           
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
            lda frame
            and #$01
            tax
            lda player_state,x           ;3   6
            sta ENAM0                    ;3   9
            and #$02
            beq _skip_laser_color_1
            lda laser_color,x            ;3  18
            sta COLUP0                   ;3  21
_skip_laser_color_1
            lda display_scroll           ;3  24
            and #$0f
            tay
            lda #80
            sta display_playfield_limit  
            lda #$00                     ;2  26 
            sta HMP0                     ;3  29 
            sta HMP1                     ;3  32
            sta temp_beam_index          ;3  35
            lda #$01                     ;2  37
            sta VDELP1                   ;3  40
            jmp (display_formation_jmp)  ;3  43

    ; try to avoid page branching problems
    ALIGN 256

formation_0
    sta WSYNC
    FORMATION formation_p0, formation_p1_dl + 0, formation_p2_dl + 0, PLAYFIELD_COLORS_0, #$0f, formation_1_jmp
formation_1
    sta WSYNC
formation_1_jmp
    FORMATION formation_p0, formation_p1_dl + 2, formation_p2_dl + 2, PLAYFIELD_COLORS_1, #$0f, formation_2_jmp
formation_2
    sta WSYNC
formation_2_jmp
    FORMATION formation_p0, formation_p1_dl + 4, formation_p2_dl + 4, PLAYFIELD_COLORS_1, #$0f, formation_3_jmp
formation_3
    sta WSYNC
formation_3_jmp
    FORMATION formation_p0, formation_p1_dl + 6, formation_p2_dl + 6, PLAYFIELD_COLORS_1, #$0f, formation_4_jmp
formation_4
    sta WSYNC
formation_4_jmp
    FORMATION formation_p0, formation_p1_dl + 8, formation_p2_dl + 8, PLAYFIELD_COLORS_1, #$0f, formation_5_jmp
formation_5
    sta WSYNC
formation_5_jmp
    FORMATION formation_p0, formation_p1_dl + 10, formation_p2_dl + 10, PLAYFIELD_COLORS_1, #$0f, formation_6_jmp
formation_6
    sta WSYNC
formation_6_jmp
    FORMATION formation_p0, formation_p1_dl + 12, formation_p2_dl + 12, PLAYFIELD_COLORS_1, #$0f, formation_7_jmp
formation_7
    sta WSYNC
formation_7_jmp
    FORMATION formation_p0, formation_p1_dl + 14, formation_p2_dl + 14, PLAYFIELD_COLORS_2, #$0f, formation_end
formation_end

            lda #$00
            sta COLUBK
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
            lda frame
            and #$01
            tax
_laser_hit_test
            lda #$40
            and CXM0P
            beq _laser_hit_test_end
            ADD16_8x ball_ax, laser_ax
            ADD16_8x ball_ay, laser_ay
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
            lda TARGET_COLOR_0,y    ;-----
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
            lda TARGET_COLOR_0,y    ;-----
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

            ldx #5
playfield_shim_loop
            sta WSYNC
            dex
            bne playfield_shim_loop

    JMP_LBL return_main_kernel

    ; try to avoid page branching problems
    ALIGN 256

P0_WALLS
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

P2_GOAL_TOP
    byte #$ff,#$ff,#$ff,#$ff,#$07,#$07,#$03,#$03
    byte #$01,#$01 ; stealing from next

PX_WALLS_BLANK
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00 ; stealing from next

P2_GOAL_BOTTOM   
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$01,#$01
    byte #$03,#$03,#$07,#$07,#$ff,#$ff,#$ff,#$ff


P1_GOAL_BOTTOM
    byte #$00,#$00,#$01,#$01,#$ff,#$ff,#$ff,#$7f ; stealing from next
P1_GOAL_TOP
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    byte #$ff,#$ff,#$ff,#$7f,#$01,#$01,#$00,#$00

P1_WALLS_CHUTE
P2_WALLS_CHUTE
    byte #$01,#$01,#$01,#$01,#$00,#$00,#$00,#$00
    byte #$01,#$01,#$01,#$01,#$00,#$00,#$00,#$00

P1_WALLS_DIAMONDS
    byte #$00,#$00,#$00,#$08,#$14,#$14,#$14,#$22
    byte #$22,#$22,#$14,#$14,#$14,#$08,#$00,#$00

P2_WALLS_CUBES_TOP
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
P2_WALLS_CUBES_BOTTOM
    byte #$e0,#$e0,#$e0,#$20,#$20,#$e0,#$e0,#$e0
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    ALIGN 256

PLAYFIELD_COLORS_0
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
PLAYFIELD_COLORS_1
    byte #$02,#$02,#$02,#$02,#$02,#$02,#$02,#$02
    byte #$02,#$02,#$02,#$02,#$02,#$02,#$02,#$02
PLAYFIELD_COLORS_2
    byte #$09,#$09,#$09,#$09,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

BALL_GRAPHICS
    byte #$3c,#$7e,#$ff,#$ff,#$ff,#$ff,#$7e,#$3c
BALL_GRAPHICS_END

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
; BUGBUG; TODO: PLAYER GRAPHICS
; MT_MKI_0
;     byte $18,$3c,$ff,$55,$ff,$30,$3c,$18; 8
; MT_MKI_1
;     byte $18,$3c,$ff,$aa,$ff,$0,$3c,$18; 8
; MT_MKI_2
;     byte $18,$3c,$ff,$55,$ff,$c,$3c,$18; 8
; MT_MKI_3
;     byte $18,$3c,$ff,$aa,$ff,$3c,$3c,$18; 8
; MT_MKIV_0
;     byte $18,$7e,$f7,$55,$55,$f7,$7e,$3c; 8
; MT_MKIV_1
;     byte $18,$7e,$ef,$aa,$aa,$ef,$7e,$3c; 8
; MT_MKIV_2
;     byte $18,$7e,$dd,$55,$55,$dd,$7e,$3c; 8
; MT_MKIV_3
;     byte $18,$7e,$bb,$aa,$aa,$bb,$7e,$3c; 8
; RADAR_TANK_0
;     byte $2a,$80,$3d,$e7,$42,$ff,$e7,$81; 8
; RADAR_TANK_1
;     byte $54,$1,$bc,$e7,$42,$ff,$e7,$81; 8
; RADAR_TANK_2
;     byte $2a,$80,$3d,$e7,$42,$ff,$e7,$81; 8
; RADAR_TANK_3
;     byte $54,$1,$bc,$e7,$42,$ff,$e7,$81; 8
TARGET_COLOR_0
    byte $00,$0a,$0c,$0e,$0e,$0e,$0e,$0c,$0a; 8
TARGET_BG_0
    byte $00,$02,$00,$02,$00,$02,$00,$02,$00; 8

    END_BANK

    START_BANK 1

; ----------------------------------
; code


CleanStart
    ; do the clean start macro
            CLEAN_START

    ; game setup
    lda #0
    sta scroll
    lda #DROP_DELAY
    sta game_timer
    lda #GAME_STATE_TITLE ; GAME_STATE_SPLASH_0
    sta game_state
    jsr kernel_title_setup

    ; initial formation
    jsr formation_diamonds
    lda #<FORMATION_CHUTE_UP
    sta formation_up
    lda #>FORMATION_CHUTE_UP
    sta formation_up + 1
    lda #<P0_WALLS
    sta formation_p0
    lda #>P0_WALLS
    sta formation_p0 + 1

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
    ldx #NUM_PLAYERS - 1
_player_setup_loop
    sta laser_color,x
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

    ; check switches
            lda #$01
            bit SWCHB
            bne check_select
            jmp CleanStart
check_select
            lda #$02
            bit SWCHB
            bne no_select
            sta player_opt ; TODO:placeholder
            jmp done_select
no_select
            bit player_opt
            beq done_select
            lda #$00
            sta player_opt
            jsr switch_formation
done_select

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
            beq jmpTitle
            dex 
            beq jmpMenu
            dex 
            jmp kernel_startGame
jmpSplash
            jmp kernel_showSplash
jmpTitle
            jmp kernel_title
jmpMenu     
            jmp kernel_menu

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
            ; calc ball offset
            sec             
            sbc ball_y  
            sta ball_voffset          

formation_update
            jmp (formation_up)
formation_update_return 
            ; figure out which formation block is first
            ; and where it starts
            lda scroll
            tay
            lsr
            lsr
            lsr
            lsr
            asl
            tax
            lda FORMATION_JMP_TABLE,x
            sta display_formation_jmp
            lda FORMATION_JMP_TABLE+1,x
            sta display_formation_jmp + 1
            tya
            and #$0f
            sta display_scroll

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
_player_update_next_player
            ;; next player
            dex
            bpl _player_update_loop
_player_update_end

player_aim
            lda frame
            and #$01
            tax
            ; calc distance between player and aim point
            lda player_aim_y,x
            cpx #$00
            beq _player_aim_beam_lo
_player_aim_beam_hi
            eor #$ff      ; invert offset to get dy
            clc
            adc #$01
            tay            ; dy
            lda #laser_hmov_0
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
            sta temp_draw_buffer ; point to top of beam hmov stack
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
            bne _player_draw_beam_end
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
_player_draw_beam_end
            cpx #0
            beq _player_aim_calc_lo
            lda player_x + 1
            sec
            sbc #5
            sta laser_lo_x 
            jmp _player_aim_save_laser_x         
_player_aim_calc_lo
            ; find lo player beam starting point
            ; last temp_x_travel will have the (signed) x distance covered  
            ; multiply by 5 to get 80 scanline x distance
            lda temp_x_travel
            asl 
            asl 
            clc
            adc temp_x_travel
            ldy temp_hmove 
            bpl _player_aim_refract_no_invert
            eor #$ff
            clc
            adc #$01
_player_aim_refract_no_invert
            adc player_x
            sec
            sbc #$05
            cmp #160 ; compare to screen width
            bcc _player_aim_save_laser_x
            sbc #96
_player_aim_save_laser_x
            sta laser_lo_x


;---------------------
; end vblank

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #1
            sta CTRLPF ; reflect playfield
            lda #WALL_COLOR
            sta COLUPF

            ; jump out to draw screen and back
            JMP_LBL fhrakas_kernel
    DEF_LBL return_main_kernel


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
; title kernel

kernel_title_setup
            ; start sound
            lda #TRACK_0      
            sta audio_tracker
            sta audio_tracker + 1
            ; input jump tables
            lda #>title_on_press_down
            sta jx_on_press_down + 1
            lda #<title_on_press_down
            sta jx_on_press_down
            lda #>title_on_move
            sta jx_on_move + 1
            lda #<title_on_move
            sta jx_on_move
            rts

title_on_press_down
            ; change loop
            lda #GAME_STATE_MENU_ROOT
            sta game_state
            jsr kernel_menu_setup
            jmp jx_on_press_down_return

kernel_title
            jsr sub_jx_update

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #192 / 2 - TITLE_HEIGHT * 2 - 10
            jsr sky_kernel

            jsr title_kernel

            ldx #SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 42
            jsr grid_kernel

            ; jump back
            jmp waitOnOverscan


;------------------------
; menu kernel

kernel_menu_setup
            ; load string
            ldx #STRING_BUFFER_0
            ldy #STRING_VERSUS
            jsr strfmt
            ; jmp tables
            lda #>menu_on_press_down
            sta jx_on_press_down + 1
            lda #<menu_on_press_down
            sta jx_on_press_down
            lda #>menu_on_move
            sta jx_on_move + 1
            lda #<menu_on_move
            sta jx_on_move
            rts

menu_on_press_down
            ; change loop
            lda #GAME_STATE_DROP
            sta game_state
            jmp jx_on_press_down_return

kernel_menu
            jsr sub_jx_update

            jsr waitOnVBlank ; SL 34

            ; skip empty space
            ldx #30 
            jsr sky_kernel
            
            jsr title_kernel

            ; skip empty space
            ldx #10 
            jsr sky_kernel

            ; menu text
            jsr text_kernel

            ; bottom grid
            ldx #SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 49
            jsr grid_kernel
            
            jmp waitOnOverscan

;--------------------------
; sky drawing routing

            ; x is number of lines
sky_kernel
            sta WSYNC
            lda #$00
            sta COLUBK
            dex
            bne sky_kernel
            rts

;--------------------------
; text drawing kernel

text_kernel
menu_text_setup_0
            sta WSYNC
            lda #$01
            sta VDELP0
            sta VDELP1
            SLEEP 24
            sta RESP0    
            sta RESP1
            lda #$03
            sta NUSIZ0
            sta NUSIZ1
            lda #30
            sta COLUP0
            sta COLUP1
            lda #$00
            sta HMP0
            lda #$10
            sta HMP1
            sta WSYNC
            sta HMOVE

            tsx
            stx temp_stack
            ldy #6
menu_text_draw_0
            sta WSYNC                                     ;3   0
            ; load and store first 3 
            lda SUPERCHIP_READ + STRING_BUFFER_0,y        ;4   4
            sta GRP0                                      ;3   7
            lda SUPERCHIP_READ + STRING_BUFFER_1,y        ;4  11
            sta GRP1                                      ;3  14
            lda SUPERCHIP_READ + STRING_BUFFER_2,y        ;4  18
            sta GRP0                                      ;3  21
            ; load next 3 EDF
            ldx SUPERCHIP_READ + STRING_BUFFER_4,y        ;4  25
            txs                                           ;2  27
            ldx SUPERCHIP_READ + STRING_BUFFER_3,y        ;4  31
            lda SUPERCHIP_READ + STRING_BUFFER_5,y        ;4  35
            stx.w GRP1                                    ;4  39
            tsx                                           ;2  41
            stx GRP0                                      ;3  44
            sta GRP1                                      ;3  47
            sty GRP0                                      ;3  50 force vdelp
            dey
            bpl menu_text_draw_0
            ldx temp_stack
            txs
            lda #$00
            sta NUSIZ0
            sta NUSIZ1
            sta GRP0
            sta GRP1
            sta VDELP0
            sta VDELP1
            rts

;--------------------------
; grid drawing kernel

            ; x is number of lines
grid_kernel
            lda #0 
            sta NUSIZ0    
            sta NUSIZ1    
            sta GRP0
            sta GRP1
            sta WSYNC

            lda #$00
            sta temp_grid_inc
            lda #$01
            sta temp_grid_gap
            tay 
_grid_loop
            sta WSYNC
            dey
            beq _grid_drawGridLine 
            lda #$00
            sta COLUBK
            jmp _grid_nextGridLine
_grid_drawGridLine
            lda #LOGO_COLOR
            sta COLUBK
            lda temp_grid_gap
            asl
            sta temp_grid_gap
            clc
            adc temp_grid_inc
            tay
_grid_nextGridLine
            dex
            bne _grid_loop
            rts

;--------------------------
; joystick menu

noop_on_press_down
            ; # noop
            jmp jx_on_press_down_return

title_on_move
menu_on_move
noop_on_move
            ; # noop
            jmp jx_on_move_return


sub_jx_update
            ldx #NUM_PLAYERS - 1
            lda SWCHA
            and #$0f
_jx_update_loop
            sta temp_player_state
            stx temp_jx_player_count
            lda #$80
            and INPT4,x
            ora temp_player_state
            pha ; save player state
            bmi jx_on_press_down_return
            eor player_state,x ; debounce
            bpl jx_on_press_down_return
            jmp (jx_on_press_down)
jx_on_press_down_return
            ldx temp_jx_player_count ; restore x
            jmp (jx_on_move)
jx_on_move_return
            pla ; recover player state
            sta player_state,x
            ldx temp_jx_player_count ; restore x
            dex
            bmi jx_menu_end
            lda SWCHA
            lsr
            lsr
            lsr
            lsr
            jmp _jx_update_loop
jx_menu_end
            rts

;--------------------------
; text blitter routine
; x = graphics buffer offset
; y = char buffer offset

strfmt
            txa
            tsx
            stx temp_stack
            tax 
            txs
_strfmt_loop
            lda #7
            sta temp_strfmt_count
            lda STRING_CONSTANTS,y      
            bne _strfmt_cont
            jmp _strfmt_stop
_strfmt_cont
            lsr
            bcc _strfmt_hi___
_strfmt_lo___
            asl
            sta temp_strfmt_index_hi
            iny 
            lda STRING_CONSTANTS,y      
            beq _strfmt_lo_00
            lsr 
            bcs _strfmt_lo_lo
            ; hi << 4 + lo >> 4 
_strfmt_lo_hi
            asl
            sta temp_strfmt_index_lo
_strfmt_lo_hi_loop
            ldx temp_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            ldx temp_strfmt_index_lo
            lda FONT_0,x
            lsr
            lsr
            lsr
            lsr
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            inx
            txs
            inc temp_strfmt_index_hi
            inc temp_strfmt_index_lo
            dec temp_strfmt_count
            bpl _strfmt_lo_hi_loop
            iny 
            jmp _strfmt_loop
            ; hi << 4 + lo & 0f
_strfmt_lo_lo
            asl
            sta temp_strfmt_index_lo
_strfmt_lo_lo_loop
            ldx temp_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            ldx temp_strfmt_index_lo
            lda FONT_0,x
            and #$0f
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            inx
            txs
            inc temp_strfmt_index_hi
            inc temp_strfmt_index_lo
            dec temp_strfmt_count
            bpl _strfmt_lo_lo_loop
            iny 
            jmp _strfmt_loop
_strfmt_lo_00            
            ldx temp_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            inx
            txs
            inc temp_strfmt_index_hi
            dec temp_strfmt_count
            bpl _strfmt_lo_00
            iny 
            jmp _strfmt_loop
_strfmt_hi___
            asl
            sta temp_strfmt_index_hi
            iny 
            lda STRING_CONSTANTS,y      
            beq _strfmt_hi_00
            lsr 
            bcs _strfmt_hi_lo
_strfmt_hi_hi
            asl
            sta temp_strfmt_index_lo
_strfmt_hi_hi_loop
            ldx temp_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            ldx temp_strfmt_index_lo
            lda FONT_0,x
            lsr
            lsr
            lsr
            lsr
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            inx
            txs
            inc temp_strfmt_index_hi
            inc temp_strfmt_index_lo
            dec temp_strfmt_count
            bpl _strfmt_hi_hi_loop
            iny 
            jmp _strfmt_loop
            ; hi << 4 + lo & 0f
_strfmt_hi_lo
            asl
            sta temp_strfmt_index_lo
_strfmt_hi_lo_loop
            ldx temp_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            ldx temp_strfmt_index_lo
            lda FONT_0,x
            and #$0f
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            inx
            txs
            inc temp_strfmt_index_hi
            inc temp_strfmt_index_lo
            dec temp_strfmt_count
            bpl _strfmt_hi_lo_loop
            iny 
            jmp _strfmt_loop
_strfmt_hi_00            
            ldx temp_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            inx
            txs
            inc temp_strfmt_index_hi
            dec temp_strfmt_count
            bpl _strfmt_hi_00
            iny 
            jmp _strfmt_loop
_strfmt_stop
            tsx
_strfmt_00_loop
            cpx #(6 * 8)
            bpl _strfmt_end
            sta STRING_WRITE,x
            inx
            jmp _strfmt_00_loop
_strfmt_end
            ldx temp_stack
            txs
            rts

;--------------------------
; player select subroutines

; BUGBUG: TODO

;--------------------------
; formation select subroutines

switch_formation
            lda formation_select
            clc
            adc #$01
            and #$03
            sta formation_select
            tax 
            beq formation_chute
            dex
            beq formation_diamonds
            dex
            beq formation_chute
formation_void
            ldx #14
_populate_formation_void_dl
            lda FORMATION_VOID_P1,x
            sta formation_p1_dl,x
            lda FORMATION_VOID_P1+1,x
            sta formation_p1_dl+1,x
            lda FORMATION_VOID_P2,x
            sta formation_p2_dl,x
            lda FORMATION_VOID_P2+1,x
            sta formation_p2_dl+1,x
            dex
            dex
            bpl _populate_formation_void_dl
            rts
formation_chute
            ldx #14
_populate_formation_chute_dl
            lda FORMATION_CHUTE_P1,x
            sta formation_p1_dl,x
            lda FORMATION_CHUTE_P1+1,x
            sta formation_p1_dl+1,x
            lda FORMATION_CHUTE_P2,x
            sta formation_p2_dl,x
            lda FORMATION_CHUTE_P2+1,x
            sta formation_p2_dl+1,x
            dex
            dex
            bpl _populate_formation_chute_dl
            rts
formation_diamonds
            ldx #14
_populate_formation_diamonds_dl
            lda FORMATION_DIAMONDS_P1,x
            sta formation_p1_dl,x
            lda FORMATION_DIAMONDS_P1+1,x
            sta formation_p1_dl+1,x
            lda FORMATION_DIAMONDS_P2,x
            sta formation_p2_dl,x
            lda FORMATION_DIAMONDS_P2+1,x
            sta formation_p2_dl+1,x
            dex
            dex
            bpl _populate_formation_diamonds_dl
            rts

    ALIGN 256

FORMATION_JMP_TABLE
    word #formation_0
    word #formation_1
    word #formation_2
    word #formation_3
    word #formation_4
    word #formation_5

FORMATION_VOID_UP
FORMATION_CHUTE_UP
    jmp formation_update_return

FORMATION_VOID_P1
    word #P1_GOAL_TOP
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #P1_GOAL_BOTTOM

FORMATION_VOID_P2
FORMATION_CHUTE_P2
    word #P2_GOAL_TOP
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #P2_GOAL_BOTTOM

FORMATION_CHUTE_P1
    word #P1_GOAL_TOP
    word #PX_WALLS_BLANK
    word #P1_WALLS_CHUTE
    word #P1_WALLS_CHUTE
    word #P1_WALLS_CHUTE
    word #P1_WALLS_CHUTE
    word #PX_WALLS_BLANK
    word #P1_GOAL_BOTTOM

FORMATION_DIAMONDS_P1
    word #P1_GOAL_TOP
    word #PX_WALLS_BLANK
    word #P1_WALLS_DIAMONDS
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #P1_WALLS_DIAMONDS
    word #PX_WALLS_BLANK
    word #P1_GOAL_BOTTOM

FORMATION_DIAMONDS_P2
    word #P2_GOAL_TOP
    word #P2_WALLS_CUBES_TOP
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #P2_WALLS_CUBES_BOTTOM
    word #P2_GOAL_BOTTOM

	ALIGN 256

title_kernel    
            lda #3      ;3=Player and Missile are drawn twice 32 clocks apart 
            sta NUSIZ0    
            sta NUSIZ1    
            lda #LOGO_COLOR
            sta COLUP0        ;3
            sta COLUP1          ;3
            ldy #TITLE_HEIGHT - 1
            lda #$01
            and frame
            beq _jmp_title_96x2_resp_frame_0
            jmp title_96x2_resp_frame_1  
_jmp_title_96x2_resp_frame_0
            jmp title_96x2_resp_frame_0

title_96x2_resp_frame_0
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

title_96x2_frame_0
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
            sbpl title_96x2_frame_0 ;2/+ 6/7
            rts

    ALIGN 256

title_96x2_resp_frame_1
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

title_96x2_frame_1 ; on entry HMP+0, on loop HMP+8
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
            sbpl title_96x2_frame_1 ;2/+ 6/7
            rts

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
            lda #GAME_STATE_TITLE
            sta game_state

keepSplashing
            jmp waitOnOverscan

;------------------------
; vblank sub

waitOnVBlank
            ldx #$00
waitOnVBlank_loop          
            cpx INTIM
            bmi waitOnVBlank_loop
            stx VBLANK
            rts 

;-----------------------------
; Font
; 4x7 bit font packed into 7x23 byte array
FONT_0
    byte $4e,$a4,$a4,$a4,$a4,$20,$cc,$0;8
    byte $6c,$82,$82,$66,$22,$0,$cc,$0;8
    byte $2c,$22,$62,$ac,$a8,$20,$a6,$0;8
    byte $48,$a8,$a8,$c4,$82,$0,$6e,$0;8
    byte $42,$a2,$a6,$ea,$aa,$22,$cc,$0;8
    byte $0,$0,$40,$e,$40,$0,$0,$0;8
    byte $0,$2,$46,$ee,$46,$2,$0,$0;8
    byte $0,$8,$ec,$e,$ec,$8,$0,$0;8
    byte $64,$40,$e0,$40,$e0,$0,$a0,$0;8
    byte $44,$0,$44,$42,$42,$48,$4c,$0;8
    byte $ac,$aa,$ea,$ac,$aa,$22,$ec,$0;8
    byte $ec,$8a,$8a,$8a,$8a,$2,$ec,$0;8
    byte $e8,$88,$88,$cc,$88,$0,$ee,$0;8
    byte $ea,$aa,$aa,$8e,$8a,$2,$ea,$0;8
    byte $4e,$4a,$42,$2,$42,$0,$42,$0;8
    byte $ae,$a8,$a8,$c8,$a8,$20,$a8,$0;8
    byte $aa,$aa,$aa,$a,$ea,$2,$ee,$0;8
    byte $e8,$a8,$a8,$ae,$aa,$22,$ee,$0;8
    byte $6a,$8a,$ac,$aa,$aa,$22,$ee,$0;8
    byte $e4,$24,$24,$e4,$84,$0,$ee,$0;8
    byte $e4,$a4,$aa,$aa,$aa,$2,$aa,$0;8
    byte $aa,$ea,$ee,$4,$ae,$2,$aa,$0;8
    byte $4e,$48,$48,$e4,$a2,$20,$ae,$0;8

STRING_CONSTANTS
STRING_VERSUS = . - STRING_CONSTANTS
    byte 161, 96, 145, 152, 160, 152, 0
STRING_QUEST = . - STRING_CONSTANTS
    byte 144, 160, 96, 152, 153, 0
STRING_TOURNAMENT = . - STRING_CONSTANTS
    byte 153, 136, 160, 145, 129, 80, 128, 96, 129, 153, 0

; versus
; quest
; tournament

; laser mk i
; laser mk iv
; maser tank
; 0123456789:-/=$+.?!
    
; player
; battle
; fracas
; combat
; gateway
; peril
; hazard
; vendetta
; facing
; against
; absconder

;---------------------------
; title graphics

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

    ALIGN 256

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


AUDIO_TRACKS ; AUDCx,AUDFx,AUDVx,T
    byte 0,
TRACK_0 = . - AUDIO_TRACKS
    byte 3,31,15,64,3,31,7,16,3,31,3,8,3,31,1,16,255;

SPLASH_0_GRAPHICS
    byte $ff ; loading... (8 bit console?)  message incoming... (scratching)
SPLASH_1_GRAPHICS
    byte $ef ; Presenting... (chorus rising)
SPLASH_2_GRAPHICS
    byte $df ; REFHRAKTOR / (deep note 3/31 .. scrolling) 
SPLASH_GRAPHICS
    byte $00 ; -- to menu - ReFhRaKtOr - players - controls - menu


    MAC FORMATION ; given p0, p1, p2, c, mask addr
._pl0_loop_0_hm
            lda ({1}),y                  ;5   5
            sta PF0                      ;3   8
            lda ({2}),y                  ;5  13
            sta PF1                      ;3  16 
            ldx {4},y                    ;4  20
            ;; p2 ahead
            lda ({3}),y                  ;5  25
            ;; adjust playfield color
            stx COLUBK                   ;3  28
            sta PF2                      ;3  31
            ;; set beam hmov          
            lda laser_hmov_0,y           ;4  35
            sta HMM0                     ;3  38
            SLEEP 7                      ;7  45
            ; lda laser_hmov_1,y           ;4  42
            ; sta HMM1                     ;3  45
            ;; ball graphics
            ldx ball_voffset             ;3  48
            cpx #$00                     ;2  50
            bpl ._pl0_draw_grp_0         ;2  52  ; sbpl
            lda #$00                     ;2  54
            jmp ._pl0_end_grp_0          ;3  57
._pl0_draw_grp_0
            lda BALL_GRAPHICS,x          ;4  57
._pl0_end_grp_0
            sta GRP0                     ;3  60
            sta GRP1                     ;3  63 
            SLEEP 3                      ;3  66
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
            lda {4},y                    ;4  19
            iny                          ;2  21 ; getting ready for later
            SLEEP 4                      ;4  25
            sta COLUBK                   ;3  28
            ;; ball offsets
            cpx #$00                     ;2  30
            bmi ._pl0_inc_ball_offset    ;2  32 ; sbmi
            lda CXP0FB                   ;3  35
            pha                          ;3  38
            dex                          ;2  40
            bmi ._pl0_ball_end           ;2  42 ; sbmi
            SLEEP 3                      ;3  45
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_ball_end
            ldx #128                     ;2  45
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_inc_ball_offset 
            SLEEP 8                      ;8  41
            inx                          ;2  43
            beq ._pl0_ball_start         ;2  45 ; sbeq
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_ball_start 
            ldx #BALL_HEIGHT - 1         ;2  48
._pl0_save_ball_offset
            stx ball_voffset             ;3  51
            dec display_playfield_limit  ;3  54
            bpl ._pl0_continue           ;2  56 ; sbpl
            jmp formation_end            ;3  59
._pl0_continue
            ldx #$00                     ;2  61
            tya                          ;2  63
            and #{5}                     ;2  65
            beq ._pl0_advance_formation  ;2  67 ; sbeq
            stx.w COLUBK                 ;4  71
            ;; EOL
            SLEEP 2                      ;2  73
            jmp ._pl0_loop_0_hm          ;3  --
._pl0_advance_formation
            stx COLUBK                   ;4  71
            tay                          ;2  73
            jmp {6}                      ;3  --
        ENDM

; game notes - MVP
; DONE
;  - make fire buttons work
;  - make lasers not be chained to ball 
;  - make ball move when fired on
;  - add goal area
;  - make ball score when reaching goal
;  - replace ball in center after score
;  - alternate playfields
;  - bank switching
; TODO
;  - menu system
;    - choose pod
;    - choose mode
;       - versus
;       - quest
;       - tournament
;    - choose stage
;    - second player opt in (either/or)
;       - vs / co-op
;  - different ships
;  - power grid
;  - dynamic playfield
;  - framerate glitches
;  - manual aim ability
;  - clean up screen / make room for score
;  - play with grid design
;  - special attacks
;  - initial, weak, opposing ai
;  - make lasers  still refract off ball (maybe showing the power of the shot?)
;  - speed limit
;  - friction  
;  - collision bugs (stuck)
;  - auto move ability
;  - auto fire ability
;  - better colors
;  - add logo
;  - start / end game logic
;  - intro screen
;  - game timer
;  - start / end game transitions
;  - cracktro
;  - shadowball (multiball)
;  - co-op play
;        - MVP: available in quest mode
;        - two rails on same side of screen (up to 4 total with quadtari?)
;          - front rail for shooting, no power recovery is possible
;          - back rail for power banking, no shooting possible
;          - players can hop rails by double tap up/down
;          - players block each other, they must jump back/forward if they want to switch sides
;          - players in the tandem position can switch places if they push up/down simultaneously
;        - tandem firing
;          - a player on the back rail can transmit power to a player on the front rail
;          - the two pods must be on top of each other or there will be a power drop
;          - essentially, back rail player "fires" into the front player
;        - beam bros
;          - players can both sit on the front rail and fire simultaneously
;        - bank buddies
;          - players can both sit on the back rail and draw power
;  - versus mode : battle fracas combat
;  - quest  mode : gateway peril hazard 
;        - time attack
;        - no opposing player (or maybe... sometimes ai), but continuous gravity down
;        - playfield extends up infinitely through a series of gates
;        - player(s) must guide ball up the field as far as possible
;        - players must reach each gate in time or game ends
;        - second player can join any time (can choose during play?)
;  - tournament mode : vendetta facing against  
;        - versus battle where players choose the defenses starting with their goals
;        - after the players lock in their choices for goal, they choose the next level up / down
;        - can play from 2 to 6 levels each (not counting midfield)
;        - game begins when the players have locked in their choices behind midfield
;
;
; top player cutoff glitch
; scan line glitchy?
; ball score not in goal
; lasers off at certain positions
;
; button mash avoidance
;   continuous fire with button down
;   instead of continuous fire, have button down charge
;   heat meter / cooldown
;   golf shot pendulum
;   music rhythm shot
;   change color / color matters in shot power 
;;
;
; specials 
    ;  - button masher weapon
    ;  - continuous fire weapon
    ;  - charge weapon
    ;  - rhythm weapon
    ;  - golf shot weapon
    ;  - defensive weapon
;   moving playfield
;   refhrakting laser
;   gamma laser
;   gravity wave
;   meson bomb
;;
;; F600 - FB00
;; need - say 1536 bytes for current kernel scheme (256 bytes x 6)
;; each formation has
;;   6 + n  byte update routine (2 byte pointer + n bytes code + 3 byte jmp/rts)
;;   16     byte display list
;;   t * 32 bytes for tiles
;; if each formation uses 256 bytes
;;   will get ~30 update instructions and 4 unique tiles
;; a 1k block can hold 4 formations
;; a 2k block can hold 8 formations
;; a 4k block with no kernel can hold 16 formations
;; a 4k block with kernel can hold 10 formations
;; with 4k banks
;;     - assume one bank for game stuff, the rest for formations and kernel copies
;;     - 8k game has 10 formations
;;     - 16k game has 30 formations
;;     - 32k game has 70 formations
;; with 2k banks
;;     - assume one bank for the kernel, two banks for other game stuff
;;     - 8k game has 8 formations
;;     - 16k game has 40 formations
;;     - 32k game has 104 formations
;; if kernel can reduce to 1k
;;     - 4k banks = 12@8k, 36@16k, 84@32k
;;     - 2k banks = 12@8k, 44@16k, 108@32k
;;     - 1k banks = 12@8k, 44@16k, 108@32k

    END_BANK