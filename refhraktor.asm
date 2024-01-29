
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

;['a6', 'a0', '16', '40', 'b0', '07']

#if SYSTEM = NTSC
; NTSC Colors
WHITE = $0f
BLACK = 0
BALL_COLOR = $40
LOGO_COLOR = $B4
POWER_COLOR = $B0
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
BALL_COLOR = $2A
LOGO_COLOR = $53
POWER_COLOR = $50
SCANLINES = 262
#endif

;
; game states
; 
; $0yyyxxxx : attract/menu screens
;   yyy = current screen 
;  xxxx = game type select
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
GS_MENU_ACCEPT         = $07; 
; select game types
__MENU_GAME_VERSUS     = $00
__MENU_GAME_QUEST      = $10
__MENU_GAME_TOURNAMENT = $20

; $1yyyxxxx ; game play screens
;   yyy = game type
;  xxxx = game mode

GS_GAME                = $80
GS_GAME_VERSUS         = $80;
GS_GAME_QUEST          = $90;
GS_GAME_TOURNAMENT     = $a0;
; game types
__GAME_TYPE_MASK       = $f0
__GAME_MODE_MASK       = $0f
__GAME_MODE_PLAY       = $00
__GAME_MODE_CELEBRATE  = $01
__GAME_MODE_DROP       = $02
__GAME_MODE_GAME_OVER  = $03
__GAME_MODE_START      = $04
__GAME_MODE_SCROLL_UP  = $05

NUM_PLAYERS        = 2
NUM_AUDIO_CHANNELS = 2

FORMATION_COUNT = 6

GAME_PULSE            = 127
DROP_DELAY            = 63
SPLASH_DELAY          = 7
CELEBRATE_DELAY       = 127

PLAYFIELD_WIDTH = 154
PLAYFIELD_VIEWPORT_HEIGHT = 80
PLAYFIELD_BEAM_RES = 16

PLAYER_MIN_X = 0
PLAYER_MAX_X = 140
BALL_MIN_X = 12
BALL_MAX_X = 132

GOAL_SCORE_DEPTH = 4
GOAL_HEIGHT = 16
BALL_HEIGHT = BALL_GRAPHICS_END - BALL_GRAPHICS
PLAYER_HEIGHT = MTP_MKI_1 - MTP_MKI_0

LOOKUP_STD_HMOVE = STD_HMOVE_END - 256
LOOKUP_STD_HMOVE_B2 = STD_HMOVE_END_B2 - 256

PLAYER_STATE_HAS_POWER        = $01 ; power grid has power
PLAYER_STATE_FIRING           = $02 ; player is firing
PLAYER_STATE_BEAM_MASK        = $0c ; beam type mask
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

DEFAULT_TIME_LIMIT = 64

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

frame            ds 1  ; frame counter
game_timer       ds 1  ; countdown

audio_tracker 
audio_track_0    ds 1  ; channel 0 track
audio_track_1    ds 1  ; channel 1 track
audio_timer      ds 2  ; time left on audio

game_state       ds 1  ; current game state
time_limit       ds 1  ; game time limit
formation_select ds 1           ; which level
player_select    ds NUM_PLAYERS ; what player options

tx_on_timer      ds 2  ; timed event sub ptr
jx_on_press_down ds 2  ; on press sub ptr
jx_on_move       ds 2  ; on move sub ptr

formation_pf1_dl  ds FORMATION_COUNT * 2 ; playfield df pf1 - left
formation_pf2_dl  ds FORMATION_COUNT * 2 ; playfield dl pf2 - left
formation_pf3_dl  ds FORMATION_COUNT * 2 ; playfield dl pf0 - right
formation_pf4_dl  ds FORMATION_COUNT * 2 ; playfield dl pf1 - right

player_score      ds NUM_PLAYERS      ; score
player_input      ds NUM_PLAYERS      ; player input buffer
player_state      ds NUM_PLAYERS      ; 
player_sprite     ds 2 * NUM_PLAYERS  ; pointer
player_x          ds NUM_PLAYERS      ; player x position

power_grid_reserve ds NUM_PLAYERS
power_grid_timer   ds NUM_PLAYERS
power_grid_recover ds NUM_PLAYERS

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

local_overlay = .

    ORG local_overlay

; -- joystick kernel locals
local_jx_player_input ds 1
local_jx_player_count ds 1

    ORG local_overlay

; -- formation load args
local_formation_load_pf1 ds 2 ; (ds 2)
local_formation_load_pf2 ds 2 ; (ds 2)
local_formation_load_pf3 ds 2 ; (ds 2)
local_formation_load_pf4 ds 2 ; (ds 2)
local_formation_offset   ds 1
local_formation_start    ds 1
local_formation_end      ds 1

    ORG local_overlay

; -- strfmt locals 
local_strfmt_stack        ds 1
local_strfmt_index_hi     ds 1
local_strfmt_index_lo     ds 1
local_strfmt_index_offset ds 1
local_strfmt_tail         ds 1

    ORG local_overlay

; -- bcdfmt locals
local_bcdfmt_hi ds 1
local_bcdfmt_lo ds 1

    ORG local_overlay

; -- grid kernel locals
local_grid_gap ds 1  
local_grid_inc ds 1

    ORG local_overlay

; -- player update kernel locals
local_player_sprite_lobyte  ds 1

    ORG local_overlay

; -- beam drawing kernel locals
local_beam_draw_cx          ds 1  ; collision distance
local_beam_draw_dy          ds 1  ; y distance (positive)
local_beam_draw_dx          ds 1  ; x distance (positive)
local_beam_draw_hmove       ds 1  ; hmove direction
local_beam_draw_pattern     ds 1  ; pattern for drawing
local_beam_draw_D           ds 1
local_beam_draw_x_travel    ds 1

    ORG local_overlay

; -- text kernel locals
local_tk_stack ds 1      ; hold stack ptr during text
local_tk_y_min ds 1  ; hold y min during text kernel

    ORG local_overlay

; -- fhrakas kernel locals
local_fk_m0_dl      ds (FORMATION_COUNT * 2)  ; pattern for missile 0
local_fk_p0_dl      ds (FORMATION_COUNT * 2)  ; pattern for p0 



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
            lda #PLAYER_SELECT_MKI
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
            tax
            lda TABLE_GAME_JUMP_HI,x
            pha
            lda TABLE_GAME_JUMP_LO,x
            pha
            rts
_jmp_attract_menu_kernels
            JMP_LBL attract_menu_kernels

TABLE_GAME_JUMP_LO
    byte <(kernel_playGame-1),<(kernel_celebrateScore-1),<(kernel_dropBall-1),<(kernel_gameOver-1),<(kernel_startGame-1),<(kernel_scrollUp-1)
TABLE_GAME_JUMP_HI
    byte >(kernel_playGame-1),>(kernel_celebrateScore-1),>(kernel_dropBall-1),>(kernel_gameOver-1),>(kernel_startGame-1),>(kernel_scrollUp-1)

;--------------------
; gameplay update kernel

kernel_startGame
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
            ldy #1 ; TODO: make constant
            sty power_grid_recover + 1
            sty power_grid_recover
            ; game specific state
            lda game_state
            and #__GAME_TYPE_MASK
            cmp #GS_GAME_QUEST
            bne _kernel_drop_skip_quest
            ; BUGBUG: if this changes much, make a jump table
            lda #96 - BALL_HEIGHT / 2
            sta ball_y
            lda #PLAYFIELD_WIDTH / 2 - BALL_HEIGHT / 2
            sta ball_x
            lda #0 ; zero for p0
            sta power_grid_recover
_kernel_drop_skip_quest
            ; animate ball drop
            lda frame
            and #$01
            bne _drop_flicker_ball
            lda #BALL_COLOR
            jmp _drop_save_ball_color
_drop_flicker_ball
            lda #$00
_drop_save_ball_color
            sta ball_color
            jmp scroll_update

kernel_celebrateScore
            inc ball_color
            jmp scroll_update ; skip ball update

kernel_scrollUp
            inc ball_color
            ; at t = 0, ball_voffset = - ball_y, scroll = 16, 
            ;           next formation in first dl
            ;           
            ; scroll to the next formation
            ;;
            lda game_timer
            cmp #$58  ; BUGBUG: magic number
            bpl _quest_scroll_vdelay
            cmp #$2f
            bmi _quest_scroll_vdelay
            lda ball_y
            clc 
            adc #1
            sta ball_y
_quest_scroll_vdelay
            lda ball_y
            eor #$ff
            clc
            adc #1
            sta ball_voffset    
            lda #(FORMATION_COUNT * 2)    ; do last first 
            sta local_formation_end  ; always to end
            lda #$8f
            sec
            sbc game_timer  ; counting down from 127
            cmp #$60
            bmi _quest_scroll_up
            lda #FORMATION_COUNT
            sta local_formation_offset
            lda #0
            jmp _quest_scroll_next_formation
_quest_scroll_up
            lsr             ; div 8 
            lsr             ; .
            lsr             ; .
            and #$fe 
            sta local_formation_start
            lda #$00
            sta local_formation_offset
            ldx formation_select
            jsr sub_formation_update
            ; move up
            lda local_formation_start
            sta local_formation_end
            lda #$10
            sec
            sbc local_formation_start
            sta local_formation_offset
            lda game_timer
            and #$0f
_quest_scroll_next_formation
            sta display_scroll
            lda #$00
            sta local_formation_start
            ldy formation_select
            ldx TABLE_QUEST_FORMATION_NEXT,y  ; BUGBUG: not interesting logic
            jsr sub_formation_update
            jmp power_grid_update ; skip ball update

kernel_playGame

ball_score_check
            lda ball_y
            cmp #GOAL_SCORE_DEPTH
            bcs _ball_score_lo_check
            inc player_score
            lda game_state
            ; check if we are questing
            and #__GAME_TYPE_MASK
            cmp #GS_GAME_QUEST
            bne _ball_score_celebrate
            ; play score
            SET_AX_TRACK TRACK_QUEST_ADVANCE, 0
            ; next screen will be score celebration
            SET_TX_CALLBACK game_quest_timer, CELEBRATE_DELAY
            lda game_state
            and #$f0
            ora #__GAME_MODE_SCROLL_UP
            jmp _ball_score_save_state
_ball_score_lo_check
            cmp #127 - GOAL_SCORE_DEPTH - BALL_HEIGHT
            bcc _ball_score_end
            inc player_score + 1
_ball_score_celebrate
            ; play score
            SET_AX_TRACK TRACK_SCORE, 0
            ; next screen will be score celebration
            SET_TX_CALLBACK game_celebrate_timer, CELEBRATE_DELAY
            lda game_state
            and #$f0
            ora #__GAME_MODE_CELEBRATE
_ball_score_save_state
            sta game_state ; goto celebrate
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
            bmi _ball_update_cx_acc
            ; play a sound if we bounced
            SET_AX_TRACK TRACK_BOUNCE, 1
            jmp _ball_update_cx_end
_ball_update_cx_acc
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

            ; scroll offset
            ; figure out which formation block is first
            ; and where it starts
            ; BUGBUG: be able to splice into a window 
            lda scroll
            lsr       ; div 8
            lsr       ; .
            lsr       ; .
            and #$fe  ; 2x addresses
            sta local_formation_offset
            lda #0 
            sta local_formation_start
            lda #(FORMATION_COUNT * 2)
            sta local_formation_end  
            ldx formation_select
            jsr sub_formation_update
            lda scroll
            and #$0f
            sta display_scroll

            ; power_grid update
power_grid_update
            ; update players on alternate frames
            lda frame
            and #$01
            tax
            GRID_TREATMENT_2
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
            bne _player_no_fire ; only fire in gameplay
            lda player_state,x 
            ; check auto fire ($80)
            bpl _player_update_skip_auto_fire
_player_fire_auto
            and #0; BUGBUG:testing PLAYER_STATE_HAS_POWER
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
            SET_AX_TRACK_PLAYER TRACK_POWER_SHUTDOWN
            lda #POWER_RESERVE_COOLDOWN
_player_power_save
            sta power_grid_reserve,x
            lda player_state,x
            ora #PLAYER_STATE_FIRING            
            jmp _player_save_fire
_player_misfire
           ; BUGBUG penalize power
            SET_AX_TRACK_PLAYER TRACK_POWER_MISFIRE
_player_no_fire
            lda power_grid_reserve,x ; restore power reserve
            bpl _player_power_skip_restore
            ; cmp #POWER_RESERVE_MAX
            ; beq _player_power_skip_restore
            clc
            adc power_grid_recover,x
            bmi _player_power_save_restore
            lda #POWER_RESERVE_MAX
_player_power_save_restore
            sta power_grid_reserve,x
            SET_AX_TRACK_PLAYER TRACK_POWER_RESTORE
_player_power_skip_restore
            lda player_state,x
            and #$fd
_player_save_fire
            sta player_state,x
            ; jump to beam drawing
            and #(PLAYER_STATE_BEAM_MASK + PLAYER_STATE_FIRING)
            lsr ; lsr power bit
            lsr ; lsr fire bit 
            bcs _player_call_wx
            jmp wx_clear_beam
_player_call_wx
            tay
            txa
            beq _player_fire_wx
            lda game_state
            and #__GAME_TYPE_MASK
            cmp #GS_GAME_QUEST
            beq _player_power_transfer
_player_fire_wx            
            lda TABLE_BEAM_JUMP_HI,y
            pha
            lda TABLE_BEAM_JUMP_LO,y
            pha
            rts
_player_power_transfer
            ; BUGBUG: TODO: grid transfer   
            lda power_grid_reserve
            clc
            adc #POWER_RESERVE_SHOT_DRAIN
            sta power_grid_reserve
            SET_AX_TRACK_PLAYER TRACK_TRANSFER
            jmp wx_clear_beam         
            ; by the time we hit wx_player_return we've set up 
            ; the dl's for beam
wx_player_return
            ; final dl - for p0 / p1
            ; notes: 
            ;  -36 ball_voffset
            ;  will start in formation 2 at y = 4
ball_dl_setup
            ; WARNING: need to store stack    
            WRITE_DL local_fk_p0_dl, BALL_GRAPHICS_OFF
            ldx #$ff
            txs ; BUGBUG: KLUDGE
            lda ball_voffset
            eor #$ff
            clc
            adc #1 ;
            clc
            adc display_scroll
            tax
            lsr
            lsr
            lsr
            lsr
            asl 
            tay
            txa
            and #$0f         ; 
            adc #<BALL_GRAPHICS_PAD
            sta local_fk_p0_dl,y ; this needs to be 
            iny
            iny
            sec
            sbc #16
            sta local_fk_p0_dl,y
_ball_dl_end

;---------------------
; end vblank

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35

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

;-------------------------------------
; game over - jump to summary kernel 

kernel_gameOver
          JMP_LBL game_summary_kernel

;---------------------
; beam effect drawing

    include "_beam_kernel.asm"

;---------------------
; power grid drawing

    include "_power_kernel.asm"
;
;

game_on_timer
            lda time_limit
            sec
            sbc #1 
            sta time_limit
            beq _game_on_time_up
            lsr
            lsr
            lsr
            beq _game_on_time_8left
            jmp _game_on_timer_repeat
_game_on_time_8left
            ; play a sound
            SET_AX_TRACK TRACK_CHIME, 1
            ; continue
            jmp _game_on_timer_repeat
_game_on_time_up
            SET_AX_TRACK TRACK_GAME_OVER, 0
            SET_TX_CALLBACK game_over_timer, DROP_DELAY
            lda game_state
            and #$f0
            ora #__GAME_MODE_GAME_OVER
            sta game_state
            jmp tx_on_timer_return
_game_on_timer_repeat
            lda #GAME_PULSE
            sta game_timer
            jmp tx_on_timer_return

game_drop_timer
            ; drop complete
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
            sta game_state ; goto game play
            ; play sound
            SET_AX_TRACK TRACK_DROP, 0
            ; set play callback
            SET_TX_CALLBACK game_on_timer, GAME_PULSE
            jmp tx_on_timer_return

game_quest_timer
            ldy formation_select
            lda TABLE_QUEST_FORMATION_NEXT,y  ; BUGBUG: not interesting logic
            sta formation_select
            ; intentional fallthrough to game drop

game_celebrate_timer
            SET_TX_CALLBACK game_drop_timer, DROP_DELAY
            lda game_state
            and #$f0
            ora #__GAME_MODE_DROP
            sta game_state ; goto drop ball
            jmp tx_on_timer_return

game_over_timer
            jsr gs_title_setup ; back to title
            jmp tx_on_timer_return

;------------------------
; splash kernel state transition

gs_splash_setup
            lda #GS_ATTRACT_SPLASH_0
            sta game_state ; goto splash screen
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
            jsr gs_title_setup ; on to title
            jmp tx_on_timer_return
_splash_timer_repeat
            lda #SPLASH_DELAY
            sta game_timer
            jmp tx_on_timer_return

;------------------------
; title kernel state transition

gs_title_setup
            lda #GS_ATTRACT_TITLE 
            sta game_state ; goto title display
            ; play title
            SET_AX_TRACK TRACK_TITLE, 0
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
            sta game_state ; goto equip menu
            ; play note
            SET_AX_TRACK TRACK_MENU_MAJOR_1, 0
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
            sta game_state ; goto stage menu
            ; play note
            SET_AX_TRACK TRACK_MENU_MAJOR_2, 0
            ; jmp tables
            SET_JX_CALLBACKS menu_stage_on_press_down, menu_stage_on_move
            rts

menu_stage_on_press_down
            jsr gs_menu_accept_setup
            jmp jx_on_press_down_return

menu_stage_on_move
            lsr
            bcc _menu_stage_on_move_down
            jsr gs_menu_equip_setup
            jmp jx_on_move_return
_menu_stage_on_move_down
            lsr
            bcc _menu_stage_on_move_lr
            jsr gs_menu_accept_setup
            jmp jx_on_move_return
_menu_stage_on_move_lr    
            beq _menu_stage_on_move_end      
            SWITCH_JX formation_select, 6 ; limit
_menu_stage_on_move_end
            jmp jx_on_move_return

gs_menu_accept_setup
            lda game_state
            and #$f0
            ora #GS_MENU_ACCEPT
            sta game_state ; goto accept menu
            ; play note
            SET_AX_TRACK TRACK_MENU_MAJOR_3, 0
            ; jmp tables
            SET_JX_CALLBACKS menu_accept_on_press_down, menu_accept_on_move
            rts

menu_accept_on_press_down
            ; game setups
            ; BUGBUG : check both players
            jsr gs_game_setup
            jmp jx_on_press_down_return

menu_accept_on_move
            lsr
            bcc _menu_accept_on_move_down
            jsr gs_menu_stage_setup
_menu_accept_on_move_down
            jmp jx_on_move_return

gs_menu_game_setup
            ; setup game mode 
            lda #(GS_MENU_GAME + __MENU_GAME_VERSUS)
            sta game_state ; set default game mode
            ; play note
            SET_AX_TRACK TRACK_MENU_MAJOR_0, 0
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
            lda game_state
            clc
            adc #$10
            cmp #(GS_MENU_GAME + __MENU_GAME_QUEST + 1) ; BUGBUG: tournament disabled
            bcc _menu_game_mode_save_state
            lda #(GS_MENU_GAME + __MENU_GAME_VERSUS)
_menu_game_mode_save_state
            sta game_state ; choose game mode
_menu_game_on_move_end
            jmp jx_on_move_return

;-----------------------------------
; game init

gs_game_setup
            lda game_state
            and #$f0
            ora #(GS_GAME + __GAME_MODE_START)
            sta game_state ; goto game start
            ; set time limit
            lda #DEFAULT_TIME_LIMIT
            sta time_limit
            ; move to game
            lda #0
            sta scroll
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
            ; play setup
            SET_AX_TRACK TRACK_GAME_SETUP, 0
            ; disable JX callbacks (will use inputs from JX though)
            SET_JX_CALLBACKS noop_on_press_down, noop_on_move 
            SET_TX_CALLBACK game_drop_timer, DROP_DELAY
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

            
;--------------------------
; formation select subroutines

sub_formation_update
            lda TABLE_FORMATION_JUMP_HI,x
            pha
            lda TABLE_FORMATION_JUMP_LO,x
            pha
            rts
formation_update_return 
            rts

TABLE_FORMATION_JUMP_LO
    byte <(FORMATION_VOID_UP-1),<(FORMATION_CHUTE_UP-1),<(FORMATION_DIAMONDS_UP-1),<(FORMATION_PACHINKO_UP-1),<(FORMATION_LADDER_UP-1),<(FORMATION_BREAKOUT_UP-1)
TABLE_FORMATION_JUMP_HI
    byte >(FORMATION_VOID_UP-1),>(FORMATION_CHUTE_UP-1),>(FORMATION_DIAMONDS_UP-1),>(FORMATION_PACHINKO_UP-1),>(FORMATION_LADDER_UP-1),>(FORMATION_BREAKOUT_UP-1)

TABLE_QUEST_FORMATION_NEXT
    byte 1,2,3,0

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
            lda #<FORMATION_VOID_PF3
            sta local_formation_load_pf3
            lda #>FORMATION_VOID_PF3
            sta local_formation_load_pf3 + 1
            lda #<FORMATION_VOID_PF4
            sta local_formation_load_pf4
            lda #>FORMATION_VOID_PF4
            sta local_formation_load_pf4 + 1
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
            lda #<FORMATION_CHUTE_PF3
            sta local_formation_load_pf3
            lda #>FORMATION_CHUTE_PF3
            sta local_formation_load_pf3 + 1
            lda #<FORMATION_CHUTE_PF4
            sta local_formation_load_pf4
            lda #>FORMATION_CHUTE_PF4
            sta local_formation_load_pf4 + 1
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
            lda #<FORMATION_DIAMONDS_PF3
            sta local_formation_load_pf3
            lda #>FORMATION_DIAMONDS_PF3
            sta local_formation_load_pf3 + 1
            lda #<FORMATION_DIAMONDS_PF4
            sta local_formation_load_pf4
            lda #>FORMATION_DIAMONDS_PF4
            sta local_formation_load_pf4 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_PACHINKO_UP
            lda #<FORMATION_PACHINKO_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_PACHINKO_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_PACHINKO_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_PACHINKO_PF2
            sta local_formation_load_pf2 + 1
            lda #<FORMATION_PACHINKO_PF3
            sta local_formation_load_pf3
            lda #>FORMATION_PACHINKO_PF3
            sta local_formation_load_pf3 + 1
            lda #<FORMATION_PACHINKO_PF4
            sta local_formation_load_pf4
            lda #>FORMATION_PACHINKO_PF4
            sta local_formation_load_pf4 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_LADDER_UP
            lda #<FORMATION_LADDER_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_LADDER_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_LADDER_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_LADDER_PF2
            sta local_formation_load_pf2 + 1
            lda #<FORMATION_LADDER_PF3
            sta local_formation_load_pf3
            lda #>FORMATION_LADDER_PF3
            sta local_formation_load_pf3 + 1
            lda #<FORMATION_LADDER_PF4
            sta local_formation_load_pf4
            lda #>FORMATION_LADDER_PF4
            sta local_formation_load_pf4 + 1
            jsr formation_load
            jmp formation_update_return

FORMATION_BREAKOUT_UP
            lda #<FORMATION_BREAKOUT_PF1
            sta local_formation_load_pf1
            lda #>FORMATION_BREAKOUT_PF1
            sta local_formation_load_pf1 + 1
            lda #<FORMATION_BREAKOUT_PF2
            sta local_formation_load_pf2
            lda #>FORMATION_BREAKOUT_PF2
            sta local_formation_load_pf2 + 1
            lda #<FORMATION_BREAKOUT_PF3
            sta local_formation_load_pf3
            lda #>FORMATION_BREAKOUT_PF3
            sta local_formation_load_pf3 + 1
            lda #<FORMATION_BREAKOUT_PF4
            sta local_formation_load_pf4
            lda #>FORMATION_BREAKOUT_PF4
            sta local_formation_load_pf4 + 1
            jsr formation_load
            jmp formation_update_return

            ; routing to load a static formation into the dl
formation_load
            ; copy the list
            ldy local_formation_offset
            ldx local_formation_start
_formation_load_loop
            lda (local_formation_load_pf1),y
            sta formation_pf1_dl,x
            lda (local_formation_load_pf2),y
            sta formation_pf2_dl,x
            lda (local_formation_load_pf3),y ; KLUDGE
            sta formation_pf3_dl,x
            lda (local_formation_load_pf4),y ; KLUDGE
            sta formation_pf4_dl,x
            iny
            inx
            cpx local_formation_end
            bne _formation_load_loop
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
    word #PF2_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF2_GOAL_BOTTOM

FORMATION_VOID_PF3
    word #PF3_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF3_GOAL_BOTTOM

FORMATION_VOID_PF4
    word #PF4_GOAL_TOP
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PFX_WALLS_BLANK
    word #PF4_GOAL_BOTTOM

FORMATION_CHUTE_PF1
    word #PF1_CHUTE_0
    word #PF1_CHUTE_1
    word #PF1_CHUTE_2
    word #PF1_CHUTE_3
    word #PF1_CHUTE_4
    word #PF1_CHUTE_5
    word #PF1_CHUTE_6
    word #PF1_CHUTE_7

FORMATION_CHUTE_PF2
    word #PF2_CHUTE_0
    word #PF2_CHUTE_1
    word #PF2_CHUTE_2
    word #PF2_CHUTE_3
    word #PF2_CHUTE_4
    word #PF2_CHUTE_5
    word #PF2_CHUTE_6
    word #PF2_CHUTE_7

FORMATION_CHUTE_PF3
    word #PF3_CHUTE_0
    word #PF3_CHUTE_1
    word #PF3_CHUTE_2
    word #PF3_CHUTE_3
    word #PF3_CHUTE_4
    word #PF3_CHUTE_5
    word #PF3_CHUTE_6
    word #PF3_CHUTE_7

FORMATION_CHUTE_PF4
    word #PF4_CHUTE_0
    word #PF4_CHUTE_1
    word #PF4_CHUTE_2
    word #PF4_CHUTE_3
    word #PF4_CHUTE_4
    word #PF4_CHUTE_5
    word #PF4_CHUTE_6
    word #PF4_CHUTE_7

FORMATION_DIAMONDS_PF1
    word #PF1_DIAMONDS_0
    word #PF1_DIAMONDS_1
    word #PF1_DIAMONDS_2
    word #PF1_DIAMONDS_3
    word #PF1_DIAMONDS_4
    word #PF1_DIAMONDS_5
    word #PF1_DIAMONDS_6
    word #PF1_DIAMONDS_7

FORMATION_DIAMONDS_PF2
    word #PF2_DIAMONDS_0
    word #PF2_DIAMONDS_1
    word #PF2_DIAMONDS_2
    word #PF2_DIAMONDS_3
    word #PF2_DIAMONDS_4
    word #PF2_DIAMONDS_5
    word #PF2_DIAMONDS_6
    word #PF2_DIAMONDS_7

FORMATION_DIAMONDS_PF3
    word #PF3_DIAMONDS_0
    word #PF3_DIAMONDS_1
    word #PF3_DIAMONDS_2
    word #PF3_DIAMONDS_3
    word #PF3_DIAMONDS_4
    word #PF3_DIAMONDS_5
    word #PF3_DIAMONDS_6
    word #PF3_DIAMONDS_7

FORMATION_DIAMONDS_PF4
    word #PF4_DIAMONDS_0
    word #PF4_DIAMONDS_1
    word #PF4_DIAMONDS_2
    word #PF4_DIAMONDS_3
    word #PF4_DIAMONDS_4
    word #PF4_DIAMONDS_5
    word #PF4_DIAMONDS_6
    word #PF4_DIAMONDS_7

FORMATION_PACHINKO_PF1
    word #PF1_PACHINKO_0
    word #PF1_PACHINKO_1
    word #PF1_PACHINKO_2
    word #PF1_PACHINKO_3
    word #PF1_PACHINKO_4
    word #PF1_PACHINKO_5
    word #PF1_PACHINKO_6
    word #PF1_PACHINKO_7

FORMATION_PACHINKO_PF2
    word #PF2_PACHINKO_0
    word #PF2_PACHINKO_1
    word #PF2_PACHINKO_2
    word #PF2_PACHINKO_3
    word #PF2_PACHINKO_4
    word #PF2_PACHINKO_5
    word #PF2_PACHINKO_6
    word #PF2_PACHINKO_7

FORMATION_PACHINKO_PF3
    word #PF3_PACHINKO_0
    word #PF3_PACHINKO_1
    word #PF3_PACHINKO_2
    word #PF3_PACHINKO_3
    word #PF3_PACHINKO_4
    word #PF3_PACHINKO_5
    word #PF3_PACHINKO_6
    word #PF3_PACHINKO_7

FORMATION_PACHINKO_PF4
    word #PF4_PACHINKO_0
    word #PF4_PACHINKO_1
    word #PF4_PACHINKO_2
    word #PF4_PACHINKO_3
    word #PF4_PACHINKO_4
    word #PF4_PACHINKO_5
    word #PF4_PACHINKO_6
    word #PF4_PACHINKO_7

FORMATION_LADDER_PF1
    word #PF1_LADDER_0
    word #PF1_LADDER_1
    word #PF1_LADDER_2
    word #PF1_LADDER_3
    word #PF1_LADDER_4
    word #PF1_LADDER_5
    word #PF1_LADDER_6
    word #PF1_LADDER_7

FORMATION_LADDER_PF2
    word #PF2_LADDER_0
    word #PF2_LADDER_1
    word #PF2_LADDER_2
    word #PF2_LADDER_3
    word #PF2_LADDER_4
    word #PF2_LADDER_5
    word #PF2_LADDER_6
    word #PF2_LADDER_7

FORMATION_LADDER_PF3
    word #PF3_LADDER_0
    word #PF3_LADDER_1
    word #PF3_LADDER_2
    word #PF3_LADDER_3
    word #PF3_LADDER_4
    word #PF3_LADDER_5
    word #PF3_LADDER_6
    word #PF3_LADDER_7

FORMATION_LADDER_PF4
    word #PF4_LADDER_0
    word #PF4_LADDER_1
    word #PF4_LADDER_2
    word #PF4_LADDER_3
    word #PF4_LADDER_4
    word #PF4_LADDER_5
    word #PF4_LADDER_6
    word #PF4_LADDER_7

FORMATION_BREAKOUT_PF1
    word #PF1_BREAKOUT_0
    word #PF1_BREAKOUT_1
    word #PF1_BREAKOUT_2
    word #PF1_BREAKOUT_3
    word #PF1_BREAKOUT_4
    word #PF1_BREAKOUT_5
    word #PF1_BREAKOUT_6
    word #PF1_BREAKOUT_7

FORMATION_BREAKOUT_PF2
    word #PF2_BREAKOUT_0
    word #PF2_BREAKOUT_1
    word #PF2_BREAKOUT_2
    word #PF2_BREAKOUT_3
    word #PF2_BREAKOUT_4
    word #PF2_BREAKOUT_5
    word #PF2_BREAKOUT_6
    word #PF2_BREAKOUT_7

FORMATION_BREAKOUT_PF3
    word #PF3_BREAKOUT_0
    word #PF3_BREAKOUT_1
    word #PF3_BREAKOUT_2
    word #PF3_BREAKOUT_3
    word #PF3_BREAKOUT_4
    word #PF3_BREAKOUT_5
    word #PF3_BREAKOUT_6
    word #PF3_BREAKOUT_7

FORMATION_BREAKOUT_PF4
    word #PF4_BREAKOUT_0
    word #PF4_BREAKOUT_1
    word #PF4_BREAKOUT_2
    word #PF4_BREAKOUT_3
    word #PF4_BREAKOUT_4
    word #PF4_BREAKOUT_5
    word #PF4_BREAKOUT_6
    word #PF4_BREAKOUT_7

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

    END_BANK