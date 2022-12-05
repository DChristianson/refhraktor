
    processor 6502
    include "vcs.h"
    include "macro.h"
    include "math.h"
    include "refhraktor.h"
    include "bank_switch_f6.h"

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
BALL_COLOR = $2C
LOGO_COLOR = $C4
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
BALL_COLOR = $2A
LOGO_COLOR = $53
SCANLINES = 262
#endif

;
; game states
; 
; $0yyyxxxx : attract/menu screens
; $1yyyxxxx ; game play screens
;  xxxx = current screen
;   yyy = game control
;
GS_ATTRACT             = $00;
GS_ATTRACT_SPLASH_0    = $00;
GS_ATTRACT_SPLASH_1    = $01;
GS_ATTRACT_SPLASH_2    = $02;
GS_ATTRACT_TITLE       = $03; 
; FUTURE: credits
; FUTURE: hi scores
; FUTURE: instructions
; FUTURE: shoutouts

GS_MENU_GAME           = $04; 
GS_MENU_EQUIP          = $05; 
GS_MENU_STAGE          = $06; 
GS_MENU_TRACK          = $07; 
; select game types
__MENU_GAME_VERSUS     = $00
__MENU_GAME_QUEST      = $10
__MENU_GAME_TOURNAMENT = $20

GS_GAME                = $80
GS_GAME_VERSUS         = $80;
GS_GAME_QUEST          = $90;
GS_GAME_TOURNAMENT     = $a0;
; game types
__GAME_MODE_PLAY       = $00
__GAME_MODE_CELEBRATE  = $01
__GAME_MODE_DROP       = $02
__GAME_MODE_GAME_OVER  = $03
__GAME_MODE_START      = $04

NUM_PLAYERS        = 2
NUM_AUDIO_CHANNELS = 2

DROP_DELAY            = 63
SPLASH_DELAY          = 7
CELEBRATE_DELAY       = 127

PLAYFIELD_WIDTH = 154
PLAYFIELD_VIEWPORT_HEIGHT = 80
PLAYFIELD_BEAM_RES = 16

PLAYER_MIN_X = 6
PLAYER_MAX_X = 140
BALL_MIN_X = 12
BALL_MAX_X = 130

GOAL_SCORE_DEPTH = 4
GOAL_HEIGHT = 16
BALL_HEIGHT = BALL_GRAPHICS_END - BALL_GRAPHICS
PLAYER_HEIGHT = MTP_MKI_1 - MTP_MKI_0
TITLE_HEIGHT = TITLE_96x2_01 - TITLE_96x2_00

LOOKUP_STD_HMOVE = STD_HMOVE_END - 256
LOOKUP_STD_HMOVE_B2 = STD_HMOVE_END_B2 - 256

PLAYER_STATE_HAS_POWER = $01 ; BUGBUG: TODO
PLAYER_STATE_FIRING    = $02
PLAYER_STATE_RANGE     = $03 ;  
PLAYER_STATE_LINE      = $08 ; 
PLAYER_STATE_BEAM_MASK = $03 ; 0 = pulse, 1 = continuous, 2 = wide, 3 = double wide
PLAYER_STATE_AUTO_FIRE = $70 ; BUGBUG: TODO
PLAYER_STATE_AUTO_AIM  = $80 ; BUGBUG: TODO

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

frame            ds 1  ; frame counter
game_timer       ds 1  ; countdown

audio_tracker    ds 2  ; next track
audio_timer      ds 2  ; time left on audio

game_state       ds 1  ; current game state
formation_select ds 1           ; which level
track_select     ds 1           ; which audio track
player_select    ds NUM_PLAYERS ; what player options

tx_on_timer      ds 2  ; timed event sub ptr
jx_on_press_down ds 2  ; on press sub ptr
jx_on_move       ds 2  ; on move sub ptr

player_input     ds NUM_PLAYERS      ; player input buffer
player_sprite    ds 2 * NUM_PLAYERS  ; pointer

formation_up     ds 2   ; formation update ptr
formation_p0     ds 2   ; formation p0 ptr
formation_p1_dl  ds 12  ; playfield ptr pf1
formation_p2_dl  ds 12  ; playfield ptr pf2
formation_colupf ds 2
formation_colubk ds 2

player_state      ds NUM_PLAYERS
player_x          ds NUM_PLAYERS  ; player x position
player_power      ds NUM_PLAYERS  ; player power reserve
player_score      ds NUM_PLAYERS  ; score

power_grid_pf0    ds NUM_PLAYERS
power_grid_pf1    ds NUM_PLAYERS
power_grid_pf2    ds NUM_PLAYERS
power_grid_pf3    ds NUM_PLAYERS
power_grid_pf4    ds NUM_PLAYERS
power_grid_pf5    ds NUM_PLAYERS

laser_ax          ds 2  ;
laser_ay          ds 2  ;
laser_lo_x        ds 1  ; start x for the low laser
laser_hmov_0      ds PLAYFIELD_BEAM_RES

ball_y            ds 2 
ball_x            ds 2
ball_dy           ds 2
ball_dx           ds 2
ball_ay           ds 2
ball_ax           ds 2
ball_color        ds 1
ball_voffset      ds 1 ; ball position countdown
ball_cx           ds BALL_HEIGHT ; collision registers

display_scroll    ; scroll adjusted to modulo block
scroll         ds 1 ; y value to start showing playfield

display_playfield_limit ds 1

LOCAL_OVERLAY           ds 8

; -- joystick kernel locals
local_jx_player_input = LOCAL_OVERLAY
local_jx_player_count = LOCAL_OVERLAY + 1

; -- jmp table
local_jmp_addr = LOCAL_OVERLAY ; (ds 2)

; -- formation load args
local_formation_load_p1 = LOCAL_OVERLAY ; (ds 2)
local_formation_load_p2 = LOCAL_OVERLAY + 2 ; (ds 2)

; -- strfmt locals
local_strfmt_stack    = LOCAL_OVERLAY 
local_strfmt_index_hi = LOCAL_OVERLAY + 1
local_strfmt_index_lo = LOCAL_OVERLAY + 2
local_strfmt_index_offset = LOCAL_OVERLAY + 3
local_strfmt_start = LOCAL_OVERLAY + 4

; -- grid kernel locals
local_grid_gap = LOCAL_OVERLAY      
local_grid_inc = LOCAL_OVERLAY + 1

; -- player update kernel locals
local_player_sprite_lobyte = LOCAL_OVERLAY ; (ds 1)

; -- player beam drawing kernel locals
local_player_draw_x_travel    = LOCAL_OVERLAY
local_player_draw_aim_x       = LOCAL_OVERLAY + 1 ; player aim point x
local_player_draw_dy          = LOCAL_OVERLAY + 2 ; use for line drawing computation
local_player_draw_dx          = LOCAL_OVERLAY + 3
local_player_draw_D           = LOCAL_OVERLAY + 4
local_player_draw_hmove       = LOCAL_OVERLAY + 5
local_player_draw_buffer      = LOCAL_OVERLAY + 6 ; (ds 2)


; -- playfield kernel locals
local_pf_stack = LOCAL_OVERLAY           ; hold stack ptr during playfield
local_pf_beam_index = LOCAL_OVERLAY + 1  ; hold beam offset during playfield kernel 
local_pf_y_min      = LOCAL_OVERLAY + 2  ; hold y min 

; BUGBUG: TODO: placeholder for to protect overwriting stack with locals

; ----------------------------------
; menu RAM

  SEG.U SCRAM

STRING_BUFFER_0 = 0
STRING_BUFFER_1 = STRING_BUFFER_0 + 8
STRING_BUFFER_2 = STRING_BUFFER_1 + 8
STRING_BUFFER_3 = STRING_BUFFER_2 + 8
STRING_BUFFER_4 = STRING_BUFFER_3 + 8
STRING_BUFFER_5 = STRING_BUFFER_4 + 8 ; 48
STRING_BUFFER_6 = STRING_BUFFER_5 + 8
STRING_BUFFER_7 = STRING_BUFFER_6 + 8
STRING_BUFFER_8 = STRING_BUFFER_7 + 8
STRING_BUFFER_9 = STRING_BUFFER_8 + 8
STRING_BUFFER_A = STRING_BUFFER_9 + 8
STRING_BUFFER_B = STRING_BUFFER_A + 8 ; 96
STRING_BUFFER_C = STRING_BUFFER_B + 8
STRING_BUFFER_D = STRING_BUFFER_C + 8
STRING_BUFFER_E = STRING_BUFFER_D + 8
STRING_BUFFER_F = STRING_BUFFER_E + 8 ; 128


STRING_WRITE = SUPERCHIP_WRITE + STRING_BUFFER_0
STRING_READ = SUPERCHIP_READ + STRING_BUFFER_0

  SEG Code

; ----------------------------------
; Game Play Kernels Bank 0

    START_BANK 0

    include "_fhrakas_kernel.asm"

    END_BANK

; ----------------------------------
; Main (Game Control) Bank

    START_BANK 1

CleanStart
    ; do the clean start superchip macro
            CLEAN_START_SUPERCHIP

    ; game setup
            jsr gs_splash_setup

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

    ; check reset switches
            lda #$01
            bit SWCHB
            bne _end_switches
            jmp CleanStart
_end_switches

            ; jump to audio bank
            JMP_LBL bank_audio_tracker
        DEF_LBL bank_return_audio_tracker

            ; timed event
            jsr sub_tx_update

            ; sub process input
            jsr sub_jx_update

            ; game state processing 
            lda game_state
            bpl _jmp_attract_menu_kernels
            and #$0f
            asl
            tax
            lda GAME_JUMP_TABLE,x
            sta local_jmp_addr
            lda GAME_JUMP_TABLE + 1,x
            sta local_jmp_addr + 1
            jmp (local_jmp_addr)
_jmp_attract_menu_kernels
            JMP_LBL attract_menu_kernels

GAME_JUMP_TABLE
    word kernel_playGame
    word kernel_celebrateScore
    word kernel_dropBall
    word kernel_gameOver
    word kernel_startGame


;--------------------
; gameplay update kernel

kernel_startGame
kernel_gameOver
kernel_dropBall
            ; ball state
            lda #64 - BALL_HEIGHT / 2
            sta ball_y
            lda #PLAYFIELD_WIDTH / 2 - BALL_HEIGHT / 2
            sta ball_x
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
            lda game_timer ; todo: TX this?
            bne _drop_continue
_drop_init_game
            ; start audio track
            ldx track_select
            lda TRACKS,x
            sta audio_tracker
            ; init to game
            lda #BALL_COLOR
            sta ball_color
            lda game_state
            and #$f0
            ora #__GAME_MODE_PLAY
            sta game_state
_drop_continue
            jmp scroll_update

kernel_celebrateScore
            ; TODO: something to celebrate            
            inc ball_color
            lda game_timer ; todo: TX this?
            bne _celebrate_continue
            lda #DROP_DELAY
            sta game_timer
            lda game_state
            and #$f0
            ora #__GAME_MODE_DROP
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
            lda game_state
            and #$f0
            ora #__GAME_MODE_CELEBRATE
            sta game_state
_ball_score_end

ball_update
            ; collision
            ldy #0
_ball_update_cx_bottom
            lda ball_cx + BALL_HEIGHT - 1)
            ora ball_cx + BALL_HEIGHT - 2
            bpl _ball_update_cx_top
            ABS16 ball_dy
            iny
            jmp _ball_update_cx_horiz
_ball_update_cx_top
            ora ball_cx + 1
            ora ball_cx
            bpl _ball_update_cx_horiz
            NEG16 ball_dy
            iny
_ball_update_cx_horiz
            ldx #BALL_HEIGHT - 3
_ball_update_cx_loop
            lda ball_cx,x
            bmi _ball_update_cx_horiz_update
            dex
            cpx #2
            bcs _ball_update_cx_loop
            jmp _ball_update_cx_end_acc
_ball_update_cx_horiz_update
            ; BUGBUG 005f to ffa1 (min needs to be dx/1)
            lda ball_dx
            bne _ball_update_cx_horiz_ltz
            dec ball_x
_ball_update_cx_horiz_ltz
            cmp #$ff
            bne _ball_update_cx_horiz_inv
            inc ball_x
_ball_update_cx_horiz_inv
            INV16 ball_dx
            iny
            jmp _ball_update_cx_end
_ball_update_cx_end_acc
            dey
            bpl _ball_update_cx_end
            ; apply acceleration if no collision
            ADD16 ball_dx, ball_ax
            CLAMP16 ball_dx, -4, 4
            ADD16 ball_dy, ball_ay
            CLAMP16 ball_dy, -4, 4
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
            lda scroll
            and #$0f
            sta display_scroll

            ; power_grid update
power_grid_update
            ; BUGBUG: TODO: update rate
            lda frame
            and #$01
            beq _power_grid_update_end
            ldx #NUM_PLAYERS - 1
            
_power_grid_update_loop
            ; BUGBUG: TODO: other methods
            ; roll in from sides
            ;         5 <B   23> 27<2B  43> 47<4B 53>57<5B 73 77<7B
            ;  | 4..7 | 7......0 | 0......7 | 4..7 | 7......0 | 0......7 |
            lda player_x,x
            lsr
            lsr
            lsr
            lsr
            tay ; y is approx player location
            sec
            sbc #$0a
            pha
            lda player_state,x
            and #PLAYER_STATE_FIRING
            clc
            eor #PLAYER_STATE_FIRING
            beq _power_grid_skip_power
            lda #$08
            sec
_power_grid_skip_power
            php
            ora power_grid_pf0,x
            rol 
            sta power_grid_pf0,x
            dey
            bmi _power_grid_right
            ror power_grid_pf1,x
            dey
            dey
            bmi _power_grid_right
            rol power_grid_pf2,x
            dey
            dey
            bmi _power_grid_right
            lda #$00
            bcc _power_grid_bridge_power_left
            lda #$08
_power_grid_bridge_power_left
            ora power_grid_pf3,x
            rol 
            sta power_grid_pf3,x
            dey
            bmi _power_grid_right
            ror power_grid_pf4,x
_power_grid_right
            plp
            pla
            tay
            ror power_grid_pf5,x
            iny
            iny
            bpl _power_grid_next
            rol power_grid_pf4,x
            iny
            iny
            bpl _power_grid_next
            lda power_grid_pf3,x
            and #$f0 ; BUGBUG could add power here
            ror
            sta power_grid_pf3,x
            iny 
            bpl _power_grid_next
            and #$08
            beq _power_grid_bridge_power_right
            sec
_power_grid_bridge_power_right
            ror power_grid_pf2,x
            iny
            iny
            bpl _power_grid_next
            ror power_grid_pf1,x
_power_grid_next
            dex
            bpl _power_grid_update_loop
_power_grid_update_end

player_update
            ldx #NUM_PLAYERS - 1
_player_update_loop
            ; auto player movement
            cpx #1
            bcc _player_update_skip_auto_track
            lda ball_x
            sec
            sbc #(PLAYFIELD_WIDTH / 2)
            asl
            adc #(PLAYFIELD_WIDTH / 2)
            sbc player_x,x
            bmi _player_update_left
            bne _player_update_right
            jmp _player_end_move
_player_update_skip_auto_track
            lda player_input,x
            lsr
            lsr
            lsr
            bcc _player_update_left   
            lsr    
            bcc _player_update_right 
            jmp _player_end_move
_player_update_right
            lda player_x,x
            cmp #PLAYER_MAX_X
            bcs _player_end_move
            adc #$01 
            jmp _player_save_x
_player_update_left
            lda player_x,x
            cmp #PLAYER_MIN_X
            bcc _player_end_move
            sbc #$01
_player_save_x
            sta player_x,x
_player_update_anim
            and #$03
            tay
            lda PLAYER_HEIGHTS,y
            ldy player_select,x
            clc
            adc PLAYER_SPRITES,y
            sta local_player_sprite_lobyte
            txa
            asl
            tay
            lda local_player_sprite_lobyte
            sta player_sprite,y ; y = x * 2
_player_end_move
            cpx #1
            bcc _player_update_skip_auto_fire
            lda player_state,x
            and #PLAYER_STATE_HAS_POWER
            beq _player_no_fire 
            jmp _player_fire
            ; power ; BUGBUG: debugging power
_player_update_skip_auto_fire
            lda player_input,x
            bmi _player_no_fire
_player_fire
            lda player_state,x
            and #PLAYER_STATE_HAS_POWER
            beq _player_misfire 
            ; BUGBUG ; drain power
            lda player_state,x
            ora #PLAYER_STATE_FIRING            
            jmp _player_save_fire
_player_misfire
           ; BUGBUG penalize power
_player_no_fire            
            lda player_state,x
            and #$fd
_player_save_fire
            sta player_state,x
_player_update_next_player
            ;; next player
            dex
            bmi _player_update_end
            jmp _player_update_loop
_player_update_end

player_aim
            lda #$00
            sta local_player_draw_buffer + 1
            lda frame
            and #$01
            tax
            ; calc distance between player and aim point
            ; firing - auto-aim
            lda ball_x
            sta local_player_draw_aim_x
            lda ball_voffset ; get distance to ball
            cpx #$00
            beq _player_aim_beam_lo
_player_aim_beam_hi
            eor #$ff      ; invert offset to get dy
            clc
            adc #$01
            tay            ; dy
            lda #laser_hmov_0
            sta local_player_draw_buffer ; point at top of beam hmov stack
            lda player_x,x
            sec
            sbc local_player_draw_aim_x    ; dx
            jmp _player_aim_beam_interp
_player_aim_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            tay           ; dy
            lda #laser_hmov_0
            sta local_player_draw_buffer ; point to top of beam hmov stack
            lda local_player_draw_aim_x
            sec
            sbc player_x,x ; dx
_player_aim_beam_interp
            cpy #PLAYFIELD_BEAM_RES ; if dy < BEAM res, double everything
            bcs _player_aim_beam_end
            asl 
            sta local_player_draw_dx
            tya
            asl 
            tay
            lda local_player_draw_dx
_player_aim_beam_end

            ; figure out beam path
_player_draw_beam_calc ; on entry, a is dx (signed), y is dy (unsigned)
            sty local_player_draw_dy
            cmp #00
            bpl _player_draw_beam_left
            eor #$ff
            clc
            adc #$01
            cmp local_player_draw_dy
            bcc _player_draw_skip_normalize_dx_right
            tya
_player_draw_skip_normalize_dx_right
            sta local_player_draw_dx 
            lda #$f0
            jmp _player_draw_beam_set_hmov
_player_draw_beam_left
            cmp local_player_draw_dy
            bcc _player_draw_skip_normalize_dx_left
            tya
_player_draw_skip_normalize_dx_left
            sta local_player_draw_dx
            lda #$10
_player_draw_beam_set_hmov
            sta local_player_draw_hmove
            asl local_player_draw_dx  ; dx = 2 * dx
            lda local_player_draw_dx
            sec
            sbc local_player_draw_dy  ; D = 2dx - dy
            asl local_player_draw_dy  ; dy = 2 * dy
            sta local_player_draw_D
            lda #$00
            sta local_player_draw_x_travel
            ldy #PLAYFIELD_BEAM_RES - 1 ; will stop at 16
_player_draw_beam_loop
            lda #$01
            cmp local_player_draw_D
            bpl _player_draw_beam_skip_bump_hmov
            ; need an hmov
            lda local_player_draw_D
            sec
            sbc local_player_draw_dy  ; D = D - 2 * dy
            sta local_player_draw_D
            lda local_player_draw_hmove
            inc local_player_draw_x_travel
_player_draw_beam_skip_bump_hmov
            sta (local_player_draw_buffer),y ; cheating that #$01 is in a            
            lda local_player_draw_D
            clc
            adc local_player_draw_dx  ; D = D + 2 * dx
            sta local_player_draw_D
            dey
            bpl _player_draw_beam_loop
            lda player_state,x
            and #PLAYER_STATE_FIRING
            beq _player_draw_beam_skip_firing
            ; we are firing - calc force values
_player_draw_beam_pattern_loop
            iny
            tya
            and #PLAYER_STATE_FIRING
            ora (local_player_draw_buffer),y
            sta (local_player_draw_buffer),y
            cpy #PLAYFIELD_BEAM_RES - 1
            bmi _player_draw_beam_pattern_loop
            ; calc ax/ay coefficient
            ldy #$f0
            sec
            lda #PLAYFIELD_BEAM_RES * 2
            sbc local_player_draw_x_travel
            cpx #$00
            bne _player_draw_beam_skip_invert_ay
            ldy #$10
            eor #$ff
            clc
            adc #$01
_player_draw_beam_skip_invert_ay
            sta laser_ay,x
            lda local_player_draw_x_travel
            asl
            cpy local_player_draw_hmove 
            beq _player_draw_beam_skip_invert_ax
            eor #$ff
            clc
            adc #$01
_player_draw_beam_skip_invert_ax
            sta laser_ax,x
_player_draw_beam_skip_firing
            cpx #0
            beq _player_aim_calc_lo
            lda player_x + 1
            sec
            sbc #5
            sta laser_lo_x 
            jmp _player_aim_save_laser_x         
_player_aim_calc_lo
            ; find lo player beam starting point
            ; last local_player_x_travel will have the (signed) x distance covered  
            ; multiply by 5 to get 80 scanline x distance
            lda local_player_draw_x_travel
            asl 
            asl 
            clc
            adc local_player_draw_x_travel
            ldy local_player_draw_hmove 
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

            ; jump out to draw screen and back
            JMP_LBL fhrakas_kernel
    DEF_LBL return_main_kernel

;--------------------
; Overscan start

    DEF_LBL waitOnOverscan
            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop
            jmp newFrame

;------------------------
; splash kernel state transition

gs_splash_setup
            lda #GS_ATTRACT_SPLASH_0
            sta game_state
            ;
            SET_TX_CALLBACK splash_on_timer, SPLASH_DELAY
            ; input jump tables
            SET_JX_CALLBACKS noop_on_press_down, noop_on_move
            rts

splash_on_timer
            ; next state
            inc game_state
            lda game_state
            cmp #GS_ATTRACT_TITLE
            bne _splash_timer_repeat
            jsr gs_title_setup
            jmp tx_on_timer_return
_splash_timer_repeat
            lda #SPLASH_DELAY
            sta game_timer
            jmp tx_on_timer_return

;------------------------
; title kernel state transition

gs_title_setup
            lda #GS_ATTRACT_TITLE 
            sta game_state
            ; start sound
            lda #TRACK_0      
            sta audio_tracker
            sta audio_tracker + 1
            ; stop_timer
            SET_TX_CALLBACK noop_on_timer, 0
            ; input jump tables
            SET_JX_CALLBACKS title_on_press_down, noop_on_move
            rts

title_on_press_down
            ; change loop
            jsr gs_menu_game_setup
            jmp jx_on_press_down_return


;---------------------------
; menu kernel state transition

gs_menu_equip_setup
            ; switch to equip
            lda game_state
            and #$f0
            ora #GS_MENU_EQUIP
            sta game_state
            ; jmp tables
            SET_JX_CALLBACKS menu_equip_on_press_down, menu_equip_on_move
            ; done
            rts

menu_equip_on_press_down
            jsr gs_menu_stage_setup
            jmp jx_on_press_down_return

menu_equip_on_move
            and #$0f
            eor #$0f
            beq _menu_equip_on_move_end      
            and player_input,x
            beq _menu_equip_on_move_end      
            ; BUGBUG sense the jx proper
            ; BUGBUG move up/down left/right
            jsr switch_player
_menu_equip_on_move_end
            jmp jx_on_move_return

gs_menu_stage_setup
            lda game_state
            and #$f0
            ora #GS_MENU_STAGE
            sta game_state
            ldy formation_select
            jsr select_formation
            ; jmp tables
            SET_JX_CALLBACKS menu_stage_on_press_down, menu_stage_on_move
            rts

menu_stage_on_press_down
            jsr gs_menu_track_setup
            jmp jx_on_press_down_return

menu_stage_on_move
            and #$0f
            eor #$0f
            beq _menu_stage_on_move_end      
            and player_input,x
            beq _menu_stage_on_move_end      
            ; BUGBUG sense the jx proper
            ; BUGBUG move up/down left/right
            jsr switch_formation
_menu_stage_on_move_end
            jmp jx_on_move_return

gs_menu_track_setup
            lda game_state
            and #$f0
            ora #GS_MENU_TRACK
            sta game_state
            SET_JX_CALLBACKS menu_track_on_press_down, menu_track_on_move
            rts

menu_track_on_press_down
            ; game setups
            jsr gs_game_setup
            jmp jx_on_press_down_return

menu_track_on_move
            and #$0f
            eor #$0f
            beq _menu_track_on_move_end      
            and player_input,x
            beq _menu_track_on_move_end      
            ; BUGBUG sense the jx proper
            ; BUGBUG move up/down left/right
            jsr switch_track
_menu_track_on_move_end
            jmp jx_on_move_return

gs_menu_game_setup
            ; setup game mode 
            lda #(GS_MENU_GAME + __MENU_GAME_VERSUS)
            sta game_state
            ; jmp tables
            SET_JX_CALLBACKS menu_game_on_press_down, menu_game_on_move
            rts

menu_game_on_press_down
            ; select game
            jsr gs_menu_equip_setup
            jmp jx_on_press_down_return

menu_game_on_move
            and #$0f
            eor #$0f
            beq _menu_game_on_move_end      
            and player_input,x
            beq _menu_game_on_move_end      
            ; BUGBUG sense the jx proper
            ; BUGBUG move up/down left/right
            jsr switch_game_mode
_menu_game_on_move_end
            jmp jx_on_move_return

;-----------------------------------
; game init

gs_game_setup
            lda game_state
            and #$f0
            ora #(GS_GAME + __GAME_MODE_START)
            sta game_state
            ; move to game
            lda #0
            sta scroll
            lda #DROP_DELAY
            sta game_timer
            ; initial formation
            lda #<P0_WALLS
            sta formation_p0
            lda #>P0_WALLS
            sta formation_p0 + 1
            lda #<COLUPF_COLORS_0
            sta formation_colupf
            lda #>COLUPF_COLORS_0
            sta formation_colupf + 1
            lda #<COLUBK_COLORS_1
            sta formation_colubk
            lda #>COLUBK_COLORS_1
            sta formation_colubk + 1
            ldx #NUM_PLAYERS - 1
_player_setup_loop
            lda #PLAYFIELD_WIDTH / 2
            sta player_x,x
            dex
            bpl _player_setup_loop
            ; disable JX callbacks
            ; TODO: use JX
            SET_JX_CALLBACKS noop_on_press_down, noop_on_move 
            rts

;--------------------------
; timed event handling

noop_on_timer
            jmp tx_on_timer_return

sub_tx_update
            lda game_timer
            beq _tx_update_end
            dec game_timer
            bne _tx_update_end
            jmp (tx_on_timer)
tx_on_timer_return
_tx_update_end
            rts

;--------------------------
; joystick control

noop_on_press_down
            ; # noop
            jmp jx_on_press_down_return

noop_on_move
            ; # noop
            jmp jx_on_move_return

sub_jx_update
            ldx #NUM_PLAYERS - 1
            lda SWCHA
            and #$0f
_jx_update_loop
            sta local_jx_player_input
            lda #$80
            and INPT4,x
            ora local_jx_player_input
            sta local_jx_player_input
            stx local_jx_player_count
            bmi jx_on_press_down_return
            eor player_input,x ; debounce
            bpl jx_on_press_down_return
            jmp (jx_on_press_down)
jx_on_press_down_return
            lda local_jx_player_input
            ldx local_jx_player_count ; restore x
            jmp (jx_on_move)
jx_on_move_return
            lda local_jx_player_input
            ldx local_jx_player_count ; restore x
            sta player_input,x
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
; switch game subroutines

switch_game_mode
            lda game_state
            clc
            adc #$10
            cmp #(GS_MENU_GAME + __MENU_GAME_QUEST + 1) ; BUGBUG: tournament disabled
            bcc _switch_game_mode_save_state
            lda #(GS_MENU_GAME + __MENU_GAME_VERSUS)
_switch_game_mode_save_state
            sta game_state
            rts

;--------------------------
; player select subroutines

switch_player
            ldy player_select,x
            iny 
            cpy #3
            bcc _switch_player_save
            ldy #0
_switch_player_save
            sty player_select,x
            rts

;-------------------------
; track select subroutines

switch_track
            ldy track_select
            iny 
            cpy #3
            bcc _switch_track_save
            ldy #0
_switch_track_save
            sty track_select
            rts

TRACKS
    byte CLICK_0
    byte TABLA_0
    byte GLITCH_0

;--------------------------
; formation select subroutines

switch_formation
            ldy formation_select
            iny
            cpy #4
            bcc _switch_stage_save
            ldy #0
_switch_stage_save
            sty formation_select
select_formation 
            tya 
            asl
            tay
            lda FORMATION_UP_TABLE,y
            sta formation_up
            lda FORMATION_UP_TABLE + 1,y
            sta formation_up + 1
            rts

FORMATION_UP_TABLE
    word #FORMATION_VOID_UP
    word #FORMATION_CHUTE_UP
    word #FORMATION_DIAMONDS_UP
    word #FORMATION_WINGS_UP

    ALIGN 256

FORMATION_VOID_UP
            lda #<FORMATION_VOID_P1
            sta local_formation_load_p1
            lda #>FORMATION_VOID_P1
            sta local_formation_load_p1 + 1
            lda #<FORMATION_VOID_P2
            sta local_formation_load_p2
            lda #>FORMATION_VOID_P2
            sta local_formation_load_p2 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_CHUTE_UP
            lda #<FORMATION_CHUTE_P1
            sta local_formation_load_p1
            lda #>FORMATION_CHUTE_P1
            sta local_formation_load_p1 + 1
            lda #<FORMATION_CHUTE_P2
            sta local_formation_load_p2
            lda #>FORMATION_CHUTE_P2
            sta local_formation_load_p2 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_DIAMONDS_UP
            lda #<FORMATION_DIAMONDS_P1
            sta local_formation_load_p1
            lda #>FORMATION_DIAMONDS_P1
            sta local_formation_load_p1 + 1
            lda #<FORMATION_DIAMONDS_P2
            sta local_formation_load_p2
            lda #>FORMATION_DIAMONDS_P2
            sta local_formation_load_p2 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_WINGS_UP
            lda #<FORMATION_WINGS_P1
            sta local_formation_load_p1
            lda #>FORMATION_WINGS_P1
            sta local_formation_load_p1 + 1
            lda #<FORMATION_WINGS_P2
            sta local_formation_load_p2
            lda #>FORMATION_WINGS_P2
            sta local_formation_load_p2 + 1
            jsr formation_load
            jmp formation_update_return

            ; routing to load a static formation into the dl
formation_load
            ; figure out which formation block is first
            ; and where it starts
            lda scroll
            lsr
            lsr
            lsr
            and #$fe
            tay
            ; copy the list
            ldx #0
_formation_load_loop
            lda (local_formation_load_p1),y
            sta formation_p1_dl,x
            lda (local_formation_load_p2),y
            sta formation_p2_dl,x
            iny
            inx
            cpx #12
            bcc _formation_load_loop
            rts

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

FORMATION_WINGS_P1
    word #P1_GOAL_TOP
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #P1_WALLS_WINGS_TOP
    word #P1_WALLS_WINGS_BOTTOM
    word #P1_GOAL_BOTTOM

FORMATION_WINGS_P2
    word #P2_GOAL_TOP
    word #PX_WALLS_BLANK
    word #P2_WALLS_WINGS_TOP
    word #P2_WALLS_WINGS_BOTTOM
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #PX_WALLS_BLANK
    word #P2_GOAL_BOTTOM    

; BUGBUG; duplicate data
PLAYER_SPRITES
    byte #<MTP_MKIV_0
    byte #<MTP_MKI_0
    byte #<MTP_MX888_0

PLAYER_HEIGHTS
    byte #0
    byte #(PLAYER_HEIGHT)
    byte #(PLAYER_HEIGHT * 2)
    byte #(PLAYER_HEIGHT * 3)

;------------------------
; vblank sub

waitOnVBlank
            ldx #$00
waitOnVBlank_loop          
            cpx INTIM
            bmi waitOnVBlank_loop
            stx VBLANK
            rts 

    END_BANK

;
; ATTRACT MODE KERNELS
; MENU KERNELS
;

    START_BANK 2

    include "_menu_kernel.asm"

    END_BANK

;
; -- audio bank
;

    START_BANK 3

    include "_audio_kernel.asm"

; game notes
;
; DONE
;  - make fire buttons work
;  - make lasers not be chained to ball 
;  - make ball move when fired on
;  - add goal area
;  - make ball score when reaching goal
;  - replace ball in center after score
;  - alternate playfields
;  - bank switching
;  - different ships
;  - menu system
;    - choose game mode
;       - versus
;       - quest
;    - choose pod
;         - show player 1 pod and allow switch
;         - show player 2 pod and allow switch
;    - choose stage
;         - show stage and allow switch
;    - choose track
;         - show track and allow switch
;  - stabilize framerate
;  - remove extra scanline glitch due to player
;  - add power track
;  - power grid controls firing
;  - adjust players to change sprite
;  - remove player cutoff glitch
;  - no changing of values on startup  for menu
;  - basic opposing ai
;    - auto move ability
;    - auto fire ability
;  - physics bugs
;     - ball score not in goal
;       - one factor is when ball_voffset starts at 1
;     - collision bugs (stuck)
;  - switch controls to shared code
; MVP TODO
;  - physics glitches
;     - shot variable hi/lo power
;     - shot range changes power
;     - uncontrollable bouncing
;     - ununtuitive reaction to shots
;  - power grid mechanics MVP
;    - variables
;      - power reserve level
;      - waveform (flow pattern)
;      - pull rate (flow in from next to player)
;      - draw (remove from under player)
;      - width (area drained)
;      - capacitance (withhold before firing)
;      - relation to sound
;  - power bank mechanics
;     - boost / penalty 
;     - add special powerup indicator
;  - shield weapon (would be good to test if possible)
;     - need way to organize player options
;     - need way to turn beam on/off per line
;     - need way to turn beam on/off based on zone
;     - need alternate aiming systems to get shield effect
;  - playfields
;     - more vertical space
;  - game over criteria
;     - some way to end game
;  - controls
;     - some way to cancel back to lobby
;  - MVP levels 
;     - void (empty)
;     - chute (tracks)
;     - maze 
;     - diamonds (obstacles)
;     - crescent wings (dynamic)
;     - pachinko (pins)
;     - pinball (diagonal banks)
;     - combat
;  - code
;     - split up by bank
;     - organize superchip ram
;  - clean up menus 
;     - disable unused game modes
;     - forward/back/left/right value tranitions
;     - gradient color
;     - switch ai on/off
;  - graphical glitches
;     - remove color change glitches
;     - remove vdelay glitch on ball update
;     - lasers weird at certain positions
;  - clean up play screen 
;     - adjust background / foreground color
;     - free up player/missile/ball
;     - add score
;  MAYBE SOON
;  - sounds
;     - some basic sounds
;  - basic quest mode (could be good for testing)
;  DELAY
;  - make lasers refract off ball (maybe showing the power of the shot?)
;  - basic special attacks
;    - gravity wave (affect background)
;    - emp (affect foreground)
;  - dynamic levels 
;     - locking rings (dynamic)
;     - breakfall (dynamic, destructable)
;     - blocks (dynamic)
;     - conway (dynamic)
;     - mandala (spinning symmmetrics)
;     - chakra (circular rotating maze)
;  THINK ABOUT
;  - alternate target
;    - multiball (shadowball...)
;    - being able to attack other player
;  - menu system
;    - choose game mode
;         - tournament
;    - choose equipment
;         - show pod capabilities
;         - player 1 opt in (whoever pressed go/or)
;         - second player opt in (whoever pressed go/or)
;         - double press - on both press go to stage
;    - choose stage
;         - double press - on both press go to track
;         - show stage
;    - choose defenses
;         - each player configures their defence
;    - choose track
;         - play track
;         - double press - on both press go to game
;    - join fhaktion 
;         - build pod / more combinations
;    - secret code
;         - extra special weapons
;  - physics
;    - friction
;    - gradient field s
;    - boost zones
;    - speed limit
;  - dynamic playfield
;    - can we do breakout 
;    - animated levels
;    - gradient fields 
;    - cellular automata
;    - dark levels
;    - different goal setups
;      - alternate goals
;      - standard
;      - wide
;      - 3x
;      - pockets
;  - play with grid design
;  - start / end game logic
;  - intro screen
;  - game timer
;  - start / end game transitions
;  - cracktro
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
;  - quest mode : gateway peril hazard 
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
;
; NOT DO
;  - add in game logo?
;  - manual aim ability
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