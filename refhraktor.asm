
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
__GAME_MODE_MASK       = $0f
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

PLAYER_STATE_HAS_POWER        = $01 ; power grid has power
PLAYER_STATE_FIRING           = $02 ; player is firing
PLAYER_STATE_BEAM_MASK        = $0e 
PLAYER_STATE_BEAM_PULSE       = $04 ; 
PLAYER_STATE_BEAM_ARC         = $08 ; 
PLAYER_STATE_BEAM_GAMMA       = $0c ; 
PLAYER_STATE_BEAM_2XWIDE      = $10 ; 
PLAYER_STATE_BEAM_4XWIDE      = $20 ; 
PLAYER_STATE_BEAM_8XWIDE      = $30 ; 
PLAYER_STATE_AUTO_AIM         = $40 ; 
PLAYER_STATE_AUTO_FIRE        = $80 ; 

PLAYER_INPUT_MASK = $8f ; nothing pressed

POWER_RESERVE_COOLDOWN = -32
POWER_RESERVE_MAX = 127
POWER_RESERVE_SHOT_DRAIN = 4

BEAM_GAMMA_POWER = $80

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

formation_up      ds 2   ; formation update ptr 
formation_pf0_ptr ds 2   ; playfield ptr pf0
formation_pf1_dl  ds 12  ; playfield dl pf1
formation_pf2_dl  ds 12  ; playfield dl pf2

player_score      ds NUM_PLAYERS      ; score
player_input      ds NUM_PLAYERS      ; player input buffer
player_state      ds NUM_PLAYERS      ; 
player_sprite     ds 2 * NUM_PLAYERS  ; pointer
player_x          ds NUM_PLAYERS      ; player x position

power_grid_reserve ds NUM_PLAYERS
power_grid_timer   ds NUM_PLAYERS

laser_lo_x        ds 1  ; start x for the low laser

ball_y            ds 2 
ball_x            ds 2
ball_dy           ds 2
ball_dx           ds 2
ball_ay           ds 1
ball_ax           ds 1
ball_color        ds 1
ball_voffset      ds 1 ; ball position countdown 
ball_cx           ds 1 ; collision register

display_scroll      ; scroll adjusted to modulo block 
scroll         ds 1 ; y value to start showing playfield

display_playfield_limit ds 1 ; BUGBUG see if need

LOCAL_OVERLAY           ds 50

; -- joystick kernel locals
local_jx_player_input = LOCAL_OVERLAY
local_jx_player_count = LOCAL_OVERLAY + 1

; -- jmp table
local_jmp_addr = LOCAL_OVERLAY ; (ds 2)

; -- formation load args
local_formation_load_pf1 = LOCAL_OVERLAY ; (ds 2)
local_formation_load_pf2 = LOCAL_OVERLAY + 2 ; (ds 2)

; -- strfmt locals
local_strfmt_stack    = LOCAL_OVERLAY 
local_strfmt_index_hi = LOCAL_OVERLAY + 1
local_strfmt_index_lo = LOCAL_OVERLAY + 2
local_strfmt_index_offset = LOCAL_OVERLAY + 3
local_strfmt_tail = LOCAL_OVERLAY + 4

; -- grid kernel locals
local_grid_gap = LOCAL_OVERLAY      
local_grid_inc = LOCAL_OVERLAY + 1

; -- player update kernel locals
local_player_sprite_lobyte = LOCAL_OVERLAY ; (ds 1)

; -- used to jump to wx processing
local_wx_beam_proc_ptr        = LOCAL_OVERLAY

; -- beam drawing kernel locals
local_beam_draw_cx          = LOCAL_OVERLAY     ; collision distance
local_beam_draw_dy          = LOCAL_OVERLAY + 1 ; y distance (positive)
local_beam_draw_dx          = LOCAL_OVERLAY + 2 ; x distance (positive)
local_beam_draw_hmove       = LOCAL_OVERLAY + 3 ; hmove direction
local_beam_draw_pattern     = LOCAL_OVERLAY + 4 ; pattern for drawing
local_beam_draw_D           = LOCAL_OVERLAY + 5
local_beam_draw_x_travel    = LOCAL_OVERLAY + 6

; -- text kernel locals
local_tk_stack = LOCAL_OVERLAY      ; hold stack ptr during text
local_tk_y_min = LOCAL_OVERLAY + 1  ; hold y min during text kernel

; -- fhrakas kernel locals
local_fk_m0_dl      = LOCAL_OVERLAY      ; pattern for missile 0
local_fk_colupf_dl  = LOCAL_OVERLAY + 12
local_fk_colubk_dl  = LOCAL_OVERLAY + 24
local_fk_p0_dl      = LOCAL_OVERLAY + 36 ; pattern for p0 

; BUGBUG: TODO: placeholder for to protect overwriting stack with locals

; ----------------------------------
; menu RAM

  SEG.U SCRAM

; BUGBUG: TODO: figure out how to do this with ds
  
  SC_START

  SC_DS STRING_BUFFER_0, 8
  SC_DS STRING_BUFFER_1, 8
  SC_DS STRING_BUFFER_2, 8
  SC_DS STRING_BUFFER_3, 8
  SC_DS STRING_BUFFER_4, 8
  SC_DS STRING_BUFFER_5, 8
  SC_DS STRING_BUFFER_6, 8
  SC_DS STRING_BUFFER_7, 8
  SC_DS STRING_BUFFER_8, 8
  SC_DS STRING_BUFFER_9, 8
  SC_DS STRING_BUFFER_A, 8
  SC_DS STRING_BUFFER_B, 8
  SC_DS STRING_BUFFER_C, 8
  SC_DS STRING_BUFFER_D, 8
  SC_DS STRING_BUFFER_E, 8
  SC_DS STRING_BUFFER_F, 8

STRING_READ = SC_READ_STRING_BUFFER_0
STRING_WRITE = SC_WRITE_STRING_BUFFER_0

  SC_START
 
  SC_DS LASER_HMOV_0, PLAYFIELD_BEAM_RES
  SC_DS LASER_HMOV_1, PLAYFIELD_BEAM_RES
  SC_DS LASER_HMOV_2, PLAYFIELD_BEAM_RES
  SC_DS LASER_HMOV_3, PLAYFIELD_BEAM_RES
  SC_DS LASER_HMOV_4, PLAYFIELD_BEAM_RES
  SC_DS LASER_HMOV_5, PLAYFIELD_BEAM_RES

  SC_DS POWER_GRID_COLOR, NUM_PLAYERS
  SC_DS POWER_GRID_PF0, NUM_PLAYERS
  SC_DS POWER_GRID_PF1, NUM_PLAYERS
  SC_DS POWER_GRID_PF2, NUM_PLAYERS
  SC_DS POWER_GRID_PF3, NUM_PLAYERS
  SC_DS POWER_GRID_PF4, NUM_PLAYERS
  SC_DS POWER_GRID_PF5, NUM_PLAYERS

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

    ; initial settings
            lda #PLAYER_SELECT_MX888
            sta player_select
            lda #PLAYER_SELECT_CPU
            sta player_select + 1

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
            sta power_grid_timer
            sta power_grid_timer + 1
            sta ball_ax
            sta ball_ay
            sta ball_dx
            sta ball_dx + 1
            sta ball_dy
            sta ball_dy + 1
            lda #POWER_RESERVE_MAX
            sta power_grid_reserve
            sta power_grid_reserve + 1
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
            ; power up
            lda #POWER_RESERVE_MAX
            sta power_grid_reserve
            sta power_grid_reserve + 1
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
            lda #%11000000
            and ball_cx
            beq _ball_update_cx_top
            NEG16 ball_dy
            iny
            jmp _ball_update_cx_horiz
_ball_update_cx_top
            lda #%00000011
            and ball_cx
            beq _ball_update_cx_horiz
            ABS16 ball_dy
            iny
_ball_update_cx_horiz
            lda #%00111100
            and ball_cx
            beq _ball_update_cx_end_acc
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
            ADD16_8x ball_dx, ball_ax
            CLAMP16 ball_dx, -4, 4
            ADD16_8x ball_dy, ball_ay
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
            ; update players on alternate frames
            lda frame
            and #$01
            tax
            GRID_TREATMENT_6
_power_grid_update_end

player_update
            ldx #NUM_PLAYERS - 1
_player_update_loop
            ; auto player movement
            lda player_state,x
            and #PLAYER_STATE_AUTO_AIM
            beq _player_update_skip_auto_track
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
            ;; next player
            dex
            bmi _player_update_end
            jmp _player_update_loop
_player_update_end
            
            ; player firing sequences run on alternative frames
player_fire_aim
            lda frame
            and #$01
            tax
            ; no firing until ball drops
            lda game_state
            and #__GAME_MODE_MASK
            bne _player_no_fire ; in gameplay
            lda player_state,x 
            ; check auto fire ($80)
            bpl _player_update_skip_auto_fire
_player_fire_auto
            and #PLAYER_STATE_HAS_POWER
            beq _player_no_fire 
            lda power_grid_reserve,x ; check power reserve
            bmi _player_no_fire ; 
            jmp _player_fire
            ; power ; BUGBUG: debugging power
_player_update_skip_auto_fire
            lda player_input,x
            bmi _player_no_fire
_player_fire
            lda player_state,x
            and #PLAYER_STATE_HAS_POWER
            beq _player_misfire 
            lda power_grid_reserve,x ; drain power reserve
            bmi _player_misfire
            sec
            sbc #POWER_RESERVE_SHOT_DRAIN
            bcs _player_power_save
            lda #POWER_RESERVE_COOLDOWN
_player_power_save
            sta power_grid_reserve,x
            lda player_state,x
            ora #PLAYER_STATE_FIRING            
            jmp _player_save_fire
_player_misfire
           ; BUGBUG penalize power
_player_no_fire
            lda power_grid_reserve,x ; restore power reserve
            bpl _player_power_skip_restore
            ; cmp #POWER_RESERVE_MAX
            ; beq _player_power_skip_restore
            clc
            adc #$01
            bmi _player_power_save_restore
            lda #POWER_RESERVE_MAX
_player_power_save_restore
            sta power_grid_reserve,x
_player_power_skip_restore
            lda player_state,x
            and #$fd
_player_save_fire
            sta player_state,x
            ; jump to beam drawing
            and #PLAYER_STATE_BEAM_MASK
            lsr
            lsr 
            bcs _player_call_wx
            jmp wx_clear_beam
_player_call_wx
            asl
            tay
            lda TABLE_BEAM_JUMP + 1,y
            sta local_wx_beam_proc_ptr + 1
            lda TABLE_BEAM_JUMP,y
            sta local_wx_beam_proc_ptr
            jmp (local_wx_beam_proc_ptr)
            ; by the time we hit wx_player_return we've set up 
            ; the dl's for beam, p0, colupf and colubk
wx_player_return

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

;---------------------
; beam effect drawing

    include "_beam_kernel.asm"

;---------------------
; power grid drawing

    include "_power_kernel.asm"

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
            lsr
            bcc _menu_equip_on_move_down
            jsr gs_menu_game_setup
            jmp jx_on_move_return
_menu_equip_on_move_down
            lsr
            bcc _menu_equip_on_move_lr   
            jsr gs_menu_stage_setup
            jmp jx_on_move_return
_menu_equip_on_move_lr
            beq _menu_equip_on_move_end      
            SWITCH_JX_X player_select, 4
_menu_equip_on_move_end
            jmp jx_on_move_return

gs_menu_stage_setup
            lda game_state
            and #$f0
            ora #GS_MENU_STAGE
            sta game_state
            lda formation_select
            jsr select_formation
            ; jmp tables
            SET_JX_CALLBACKS menu_stage_on_press_down, menu_stage_on_move
            rts

menu_stage_on_press_down
            jsr gs_menu_track_setup
            jmp jx_on_press_down_return

menu_stage_on_move
            lsr
            bcc _menu_stage_on_move_down
            jsr gs_menu_equip_setup
            jmp jx_on_move_return
_menu_stage_on_move_down
            lsr
            bcc _menu_stage_on_move_lr
            jsr gs_menu_track_setup
            jmp jx_on_move_return
_menu_stage_on_move_lr    
            beq _menu_stage_on_move_end      
            SWITCH_JX formation_select, 4
            tya ; y will be the formation
            jsr select_formation
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
            lsr
            bcc _menu_track_on_move_down
            jsr gs_menu_stage_setup
            jmp jx_on_move_return
_menu_track_on_move_down
            lsr
            bcc _menu_track_on_move_lr
            jsr gs_game_setup
            jmp jx_on_move_return
_menu_track_on_move_lr 
            beq _menu_track_on_move_end  
            SWITCH_JX track_select, 3
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
            ; move on
            jsr gs_menu_equip_setup
            jmp jx_on_press_down_return

menu_game_on_move
            lsr
            lsr
            bcc _menu_game_on_move_lr    
            jsr gs_menu_equip_setup
            jmp jx_on_move_return
_menu_game_on_move_lr
            ; TODO: we only really support one mode right now
            lda game_state
            clc
            adc #$10
            cmp #(GS_MENU_GAME + __MENU_GAME_QUEST + 1) ; BUGBUG: tournament disabled
            bcc _menu_game_mode_save_state
            lda #(GS_MENU_GAME + __MENU_GAME_VERSUS)
_menu_game_mode_save_state
            sta game_state
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
            ldx #NUM_PLAYERS - 1
_player_setup_loop
            ; setup player state based on equipment
            ldy player_select,x
            lda PLAYER_STATES,y
            sta player_state,x
            ; put player in center
            lda #PLAYFIELD_WIDTH / 2
            sta player_x,x
            dex
            bpl _player_setup_loop
            ; disable JX callbacks (will use inputs from JX though)
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
            and #$0f
            eor #$0f
            and player_input,x ; debounce
            beq jx_on_move_return
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


;-------------------------
; track select data

TRACKS
    byte CLICK_0
    byte TABLA_0
    byte GLITCH_0

;--------------------------
; formation select subroutines

select_formation 
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
            lda #<FORMATION_VOID_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_VOID_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_VOID_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_VOID_PF2
            sta local_formation_load_pf2 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_CHUTE_UP
            lda #<FORMATION_CHUTE_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_CHUTE_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_CHUTE_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_CHUTE_PF2
            sta local_formation_load_pf2 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_DIAMONDS_UP
            lda #<FORMATION_DIAMONDS_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_DIAMONDS_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_DIAMONDS_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_DIAMONDS_PF2
            sta local_formation_load_pf2 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_WINGS_UP
            lda #<FORMATION_WINGS_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_WINGS_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_WINGS_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_WINGS_PF2
            sta local_formation_load_pf2 + 1
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
            lda (local_formation_load_pf1),y
            sta formation_pf1_dl,x
            lda (local_formation_load_pf2),y
            sta formation_pf2_dl,x
            iny
            inx
            cpx #12 ; BUGBUG: TODO: go backwards
            bcc _formation_load_loop
            rts

FORMATION_VOID_PF1
    word #PF1_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF1_GOAL_BOTTOM

FORMATION_VOID_PF2
FORMATION_CHUTE_PF2
    word #PF2_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF2_GOAL_BOTTOM

FORMATION_CHUTE_PF1
    word #PF1_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PF1_WALLS_CHUTE
    word #PF1_WALLS_CHUTE
    word #PF1_WALLS_CHUTE
    word #PF1_WALLS_CHUTE
    word #PFX_WALLS_BLANK
    word #PF1_GOAL_BOTTOM

FORMATION_DIAMONDS_PF1
    word #PF1_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PF1_WALLS_DIAMONDS
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF1_WALLS_DIAMONDS
    word #PFX_WALLS_BLANK
    word #PF1_GOAL_BOTTOM

FORMATION_DIAMONDS_PF2
    word #PF2_GOAL_TOP
    word #PF2_WALLS_CUBES_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF2_WALLS_CUBES_BOTTOM
    word #PF2_GOAL_BOTTOM

FORMATION_WINGS_PF1
    word #PF1_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF1_WALLS_WINGS_TOP
    word #PF1_WALLS_WINGS_BOTTOM
    word #PF1_GOAL_BOTTOM

FORMATION_WINGS_PF2
    word #PF2_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PF2_WALLS_WINGS_TOP
    word #PF2_WALLS_WINGS_BOTTOM
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF2_GOAL_BOTTOM    

; BUGBUG; duplicate data
PLAYER_SPRITES
    byte #<MTP_MKIV_0
    byte #<MTP_MKI_0
    byte #<MTP_MX888_0
    byte #<MTP_CPU_0

PLAYER_STATES
PLAYER_SELECT_MKIV = . - PLAYER_STATES
    byte #PLAYER_STATE_BEAM_2XWIDE
PLAYER_SELECT_MKI = . - PLAYER_STATES
    byte #PLAYER_STATE_BEAM_PULSE
PLAYER_SELECT_MX888 = . - PLAYER_STATES
    byte #PLAYER_STATE_BEAM_ARC | #PLAYER_STATE_BEAM_8XWIDE
PLAYER_SELECT_CPU = . - PLAYER_STATES
    byte #PLAYER_STATE_BEAM_PULSE | #PLAYER_STATE_AUTO_AIM | PLAYER_STATE_AUTO_FIRE 

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
;  - different weapons
;     - need way to organize player options
;     - need way to turn beam on/off per line
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
;     - forward/back/left/right value tranitions
;     - switch ai on/off
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
;     - no power at certain angles
;       - at least partially due to collision glitch fixes (if you miss bottom)
;     - stuck vertical
;     - ununtuitive reaction to shots
;     - incorrect for hi/lo player
;     - relatively low power - can't knock out of sideways motion easily
;        - spin could be good
;  - switch controls to shared code
;  - shot mechanics 
;      - shot range affects power
;  - power grid mechanics
;    - variables (per player?)
;      - max power 
;      - shot drain per shot
;      - cooldown recovery per frame
;      - normal recovery per frame
;  - code
;     - split up by bank
;     - organize superchip ram
;     - replace ball_cx vector with rol bitmap (will free up a chunk of ZPR)
;  - input glitches
;     - accidental firing when game starts
;  - shield (arc) weapon (would be good to test if possible)
;     - need way to turn beam on/off based on zone
;     - need alternate aiming systems to get shield effect
;  - laser weapons
;     - different patterns for different ships..
;     - arc shield mechanic
;  - shot glitches
;     - not calculated off on ball center
; MVP TODO
;  - code
;     - massive number of cycles used drawing
;     - use DL for ball (heavy ZPR but will free a ton of cycles, allow anims)
;     - review bugbugs
;  - game start / end logic
;     - end game at specific score...
;     - game timer?
;     - alternating player gets to "serve"
;     - alternately - some way to cancel back to lobby?
;  - clean up play screen 
;     - add score or timer
;     - get rid of crap on side
;     - free up scanlines around power tracks
;     - adjust background / foreground color
;     - free up player/missile/ball for background?
;  - basic special attacks
;     - gravity wave (affect background)
;     - emp (affect foreground)
;     - gamma laser 
;  - weapon effects
;     - make lasers refract off ball
;     - improve arc shield anim 
;  - shot mechanics MVP
;     - recharge if don't fire
;     - arc shield needs less drain but maybe less power
;     - arc shield range adjust mode
;  - sounds MVP
;    - audio queues
;      - menu l/r (fugue arpeggio bits)
;      - menu u/d (fugue other bits)
;      - game start (fugue pause)
;      - ball drop / get ready ()
;      - shot sound (blast)
;      - bounce sound (adjust tempo)
;      - cooldown warning (alarm)
;      - cooldown occurred (power down)
;      - power restored (tune)
;      - goal sound (pulses)
;  - physics glitches
;     - spin calc
;     - doesn't reflect bounce on normal well enough?
;  - power glitches
;     - accidental drain when game starts
;  - graphical glitches
;     - get lasers starting from players
;     - remove color change glitches
;     - remove / mitigate vdelay glitch on ball update
;     - lasers weird at certain positions 
;     - frame rate glitch at certain positions
;  - clean up menus 
;     - explicit start game option
;     - instructions?
;     - show level 
;     - disable unused game modes
;     - gradient color
;  - power grid sprinkles
;    - visual cues
;      - some sort of rolling effect
;      - grid color shows power level
;      - waveform (flow pattern)
;         - recovery (from sides)
;         - pull rate (flow in from next to player)
;          - draw (remove from under player)
;          - width (area drained)
;  - playfields MVP
;    - void (empty)
;    - diamonds (obstacles)
;    - ladder (maze-like)
;    - chute (tracks)
;    - pachinko (pins)
;  SOON
;  - basic quest mode (could be good for testing)
;  - alternative goals
;  - different height levels
;  - more levels themes
;     - locking rings (dynamic)
;     - breakfall (dynamic, destructable)
;     - blocks (dynamic)
;     - crescent wings (dynamic)
;     - conway (dynamic)
;     - mandala (spinning symmmetrics)
;     - chakra (circular rotating maze)
;     - pinball (diagonal banks, active targets
;     - combat
;     - castle
;  THINK ABOUT
;  - power grid shot mechanics
;      - shot power (capacitance) (per player)
;      - choosable hi/lo power 
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
;    - gradient fields
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
;  - sprinkles
;    - play with grid design
;    - intro screen
;    - start / end game transitions
;    - cracktro
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