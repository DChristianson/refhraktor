
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
BALL_MAX_X = 132

GOAL_SCORE_DEPTH = 4
GOAL_HEIGHT = 16
BALL_HEIGHT = BALL_GRAPHICS_END - BALL_GRAPHICS
PLAYER_HEIGHT = MTP_MKI_1 - MTP_MKI_0
TITLE_HEIGHT = TITLE_96x2_01 - TITLE_96x2_00

LOOKUP_STD_HMOVE = STD_HMOVE_END - 256
LOOKUP_STD_HMOVE_2 = STD_HMOVE_END_2 - 256

PLAYER_STATE_FIRING  = $02

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

frame        ds 1  ; frame counter
game_timer   ds 1  ; countdown

audio_tracker ds 2  ; next track
audio_timer   ds 2  ; time left on audio

game_state       ds 1  ; current game state
formation_select ds 1           ; which level
track_select     ds 1           ; which audio track
player_select    ds NUM_PLAYERS ; what player options

tx_on_timer      ds 2  ; timed event sub ptr
jx_on_press_down ds 2  ; on press sub ptr
jx_on_move       ds 2  ; on move sub ptr

player_input  ds NUM_PLAYERS      ; player input buffer
player_sprite ds 2 * NUM_PLAYERS  ; pointer

formation_up     ds 2   ; formation update ptr
formation_p0     ds 2   ; formation p0 ptr
formation_p1_dl  ds 12  ; playfield ptr pf1
formation_p2_dl  ds 12  ; playfield ptr pf2
formation_colupf ds 2
formation_colubk ds 2

player_state  ds NUM_PLAYERS
player_x      ds NUM_PLAYERS  ; player x position
player_aim_x  ds NUM_PLAYERS  ; player aim point x
player_aim_y  ds NUM_PLAYERS  ; player aim point y
player_power  ds NUM_PLAYERS  ; player power reserve
player_score  ds NUM_PLAYERS  ; score

power_grid_pf0 ds NUM_PLAYERS
power_grid_pf1 ds NUM_PLAYERS
power_grid_pf2 ds NUM_PLAYERS

laser_ax      ds 2  ;
laser_ay      ds 2  ;
laser_lo_x    ds 1  ; start x for the low laser
laser_hmov_0  ds PLAYFIELD_BEAM_RES

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

display_playfield_limit ds 1

LOCAL_OVERLAY           ds 8

; -- joystick kernel locals
local_jx_player_input = LOCAL_OVERLAY
local_jx_player_count = LOCAL_OVERLAY + 1

; -- jmp table
local_jmp_addr = LOCAL_OVERLAY ; (ds 2)

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
local_player_x_travel    = LOCAL_OVERLAY
local_player_dy          = LOCAL_OVERLAY + 1 ; use for line drawing computation
local_player_dx          = LOCAL_OVERLAY + 2
local_player_D           = LOCAL_OVERLAY + 3
local_player_hmove       = LOCAL_OVERLAY + 4
local_player_draw_buffer = LOCAL_OVERLAY + 5 ; (ds 2)


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

; ----------------------------------
; bank 0

  SEG bank_0_code

    START_BANK 0

    DEF_LBL fhrakas_kernel

;---------------------
; laser track (hi)

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
            SLEEP 6                 ;3  24+
            sta RESM0               ;3  27+ ; TODO: seems wasteful

             ; resp top player
            sta WSYNC               ;3   0
            lda player_x + 1        ;3   3
            sec                     ;2   5
_lt_hi_resp_loop
            sbc #15                 ;2   7
            sbcs _lt_hi_resp_loop   ;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMP0                ;3  18+
            SLEEP 3                 ;3  21+ ; BUGBUG: leftover
            sta RESP0               ;3  24+ 

            ; top line
            sta WSYNC
            sta HMOVE                    ;3   3
            lda #$30                     ;2  --
            sta PF0                      ;3  --      
            ldx #$0b                     ;2  --

            sta WSYNC
            stx COLUBK                   ;3   6
            stx COLUPF                   ;3   9
            lda #$00                     ;2  11
            sta HMP0                     ;3  14
            sta HMM0                     ;3  17
            ldy #PLAYER_HEIGHT - 1       ;2  19

_lt_hi_draw_loop_2
            lda (player_sprite+2),y      ;5  16
            ldx TARGET_COLOR_0,y         ;4  20

            sta WSYNC
            sta GRP0                     ;3   3
            stx COLUP0                   ;3   6
            lda TARGET_BG_0,y          ;5  11
            sta COLUBK                   ;3  14
            dey                          ;2  16
            cpy #PLAYER_HEIGHT - 3       ;2  18
            bcs _lt_hi_draw_loop_2       ;2  20
            lda #$00                     ;2  22
            sta PF0                      ;3  25
            sta PF1                      ;3  28
            sta PF2                      ;3  31
            lda TARGET_BG_0,y            ;5  36
            sta COLUPF                   ;3  39

            lda (player_sprite+2),y ;5  44
            ldx TARGET_COLOR_0,y    ;4  48
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$00                ;2   8
            sta COLUBK              ;3  11
            lda power_grid_pf0 + 1  ;3  14
            sta PF0                 ;3  17
            lda power_grid_pf1 + 1  ;3  20
            sta PF1                 ;3  23
            lda power_grid_pf2 + 1  ;3  26
            sta PF2                 ;3  29
            dey                     ;2  31
            
            sta CXCLR               ;3  34 ; start collision
            lda (player_sprite+2),y ;5  56
            ldx TARGET_COLOR_0,y    ;4  60
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            dey                     ;2   8 

            lda (player_sprite+2),y ;5  16
            ldx TARGET_COLOR_0,y    ;4  20
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            ldx CXP0FB              ;3   9
            lda TARGET_BG_0,y       ;5  14
            sta COLUBK              ;3  17
            sta COLUPF              ;3  20
            lda #$00                ;2  22
            sta PF0                 ;3  25
            sta PF1                 ;3  28
            sta PF2                 ;3  31
            dey                     ;2  33

            ; power collision test
            txa                     ;2  35
            and #$80                ;3  38
            beq _hi_skip_power      ;2  40
            inc player_power + 1    ;5  45
_hi_skip_power

_lt_hi_draw_loop_0
            lda (player_sprite+2),y      ;5  --
            ldx TARGET_COLOR_0,y         ;4  --
            sta WSYNC
            sta GRP0                     ;3   3
            stx COLUP0                   ;3   6
            lda TARGET_BG_0,y            ;5  11
            sta COLUBK                   ;3  14
            dey                          ;2  16
            bpl _lt_hi_draw_loop_0       ;2  20

            ; activate laser
            lda frame
            and #$01
            tax
            lda player_state,x           ;3   6
            sta ENAM0                    ;3   9

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
            stx local_pf_stack           ;3  14
            ldx #ball_cx + BALL_HEIGHT-1 ;2  16
            txs                          ;2  18
            sta CXCLR                    ;3  21
            ; zero out hmoves what need zeros
            lda #$00                     ;2  23
            sta HMP0                     ;3  26
            lda #$70                     ;2  28 ; shift P1/M0 back 7 clocks
            sta HMP1                     ;3  31

            ; hmove ++ and prep for playfield next line
            sta WSYNC                    ;0   0
            sta HMOVE                    ;3   3
            lda display_scroll           ;3   6
            eor #$ff                     ;2   8 ; invert as we will count down
            and #$0f                     ;2  10
            tay                          ;2  12
            lda #80                      ;2  14
            sta display_playfield_limit  ;3  17
            lda #$01                     ;2  19
            sta VDELP1                   ;3  22
            lda #$00                     ;2  24 
            sta HMP1                     ;3  27
            sta COLUP1                   ;3  30
            sta local_pf_beam_index      ;3  33
            jmp formation_0              ;3  36

    ; try to avoid page branching problems
    ALIGN 256

formation_0
    sta WSYNC
    FORMATION formation_p0, formation_p1_dl + 0, formation_p2_dl + 0, formation_colubk, formation_colupf, #$0f, formation_1_jmp
formation_1
    sta WSYNC
formation_1_jmp
    FORMATION formation_p0, formation_p1_dl + 2, formation_p2_dl + 2, formation_colubk, formation_colupf, #$0f, formation_2_jmp
formation_2
    sta WSYNC
formation_2_jmp
    FORMATION formation_p0, formation_p1_dl + 4, formation_p2_dl + 4, formation_colubk, formation_colupf, #$0f, formation_3_jmp

    ; try to avoid page branching problems
    ALIGN 256

formation_3
    sta WSYNC
formation_3_jmp
    FORMATION formation_p0, formation_p1_dl + 6, formation_p2_dl + 6, formation_colubk, formation_colupf, #$0f, formation_4_jmp
formation_4
    sta WSYNC
formation_4_jmp
    FORMATION formation_p0, formation_p1_dl + 8, formation_p2_dl + 8, formation_colubk, formation_colupf, #$0f, formation_5_jmp
formation_5
    sta WSYNC
formation_5_jmp
    FORMATION formation_p0, formation_p1_dl + 10, formation_p2_dl + 10, formation_colubk, formation_colupf, #$0f, formation_end_jmp
formation_end
            SLEEP 6                         ;6  66
            lda #$00                        ;2  68
            sta COLUBK                      ;3  71
            sta WSYNC                       ;3   0
formation_end_jmp
            sta ENAM0                       ;3   3
            sta ENAM1                       ;3   6
            sta PF0                         ;3   9
            sta PF1                         ;3  12
            sta PF2                         ;3  15
            sta ball_ax + 1                 ;3  18
            sta ball_ax                     ;3  21
            sta ball_ay + 1                 ;3  24
            sta ball_ay                     ;3  27
            sta VDELP1                      ;3  30
            lda frame                       ;3  33
            and #$01                        ;2  35
            tax                             ;2  37
_laser_hit_test
            lda #$40                        ;2  39
            and CXM0P                       ;2  41 ; check collision
            bne _laser_hit_test_hit         ;2  43
            sta WSYNC 
            jmp _laser_hit_test_end
_laser_hit_test_hit
            ADD16_8x ball_ax, laser_ax      ;26 70
            ADD16_8x ball_ay, laser_ay      ;26 ..
_laser_hit_test_end

;---------------------
; laser track (lo)

           ; resp lo player
            sta WSYNC               ;3   0
            lda player_x            ;3   3
            sec                     ;2   5
_lt_lo_resp_loop
            sbc #15                 ;2   7
            sbcs _lt_lo_resp_loop   ;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMP0                ;3  18+
            sta HMM0                ;3  21+ ; just for timing shim
            sta RESP0               ;3  24+ 

            ; top line
            sta WSYNC
            sta HMOVE               ;3   3
            ldy #$00                ;3   6
            lda (player_sprite),y   ;6   9
            sta GRP0                ;3  12
            lda TARGET_COLOR_0,y    ;4  16
            sta COLUP0              ;3  19
            lda #$00                ;2  21
            sta COLUPF              ;3  24
            sta COLUBK              ;3  27
            sta HMP0                ;3  30
            sta PF0                 ;3  35
            sta PF1                 ;3  38
            sta PF2                 ;3  41
            iny                     ;2  43

_lt_lo_draw_loop_0
            lda (player_sprite),y   ;5  51
            ldx TARGET_COLOR_0,y    ;4  55
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda TARGET_BG_0,y       ;5  11
            sta COLUBK              ;3  14
            iny                     ;2  16
            cpy #3                  ;2  18
            bcc _lt_lo_draw_loop_0  ;2  20
            lda (player_sprite),y   ;5  25
            ldx TARGET_COLOR_0,y    ;4  29
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$0b                ;2   8
            sta COLUBK              ;3  11
            iny                     ;2  13

            lda TARGET_BG_0,y       ;5  18
            sta COLUPF              ;3  21
            lda (player_sprite),y   ;5  26
            ldx TARGET_COLOR_0,y    ;4  30
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$00                ;2   8
            sta COLUBK              ;3  11
            lda power_grid_pf0      ;3  14
            sta PF0                 ;3  17
            lda power_grid_pf1      ;3  20
            sta PF1                 ;3  23
            lda power_grid_pf2      ;3  26
            sta PF2                 ;3  29
            iny                     ;2  31
        
            sta CXCLR               ;3  34 ; start power collision check
            lda (player_sprite),y   ;5  -- 
            ldx TARGET_COLOR_0,y    ;4  --
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            iny                     ;2   8

            lda (player_sprite),y   ;5  16
            ldx TARGET_COLOR_0,y    ;4  20
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$0a                ;2   8
            sta COLUPF              ;3  11
            ldx CXP0FB              ;3  14
            lda #$ff                ;2  16
            sta PF0                 ;3  19
            sta PF1                 ;3  21
            sta PF2                 ;3  24
            iny                     ;2  26

            ; power collision test
            txa                     ;2  28
            and #$80                ;3  32
            beq _lo_skip_power      ;2  34
            inc player_power        ;5  39
_lo_skip_power
    
            lda TARGET_BG_0,y       ;5  28
            sta COLUBK              ;3  31
            lda (player_sprite),y   ;5  36
            ldx TARGET_COLOR_0,y    ;4  40
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$30                ;2   8   
            sta PF0                 ;3  11
            lda #$00                ;2  13
            sta PF1                 ;3  16
            sta PF2                 ;3  19
            iny                     ;2  20

_lt_lo_draw_loop_2
            lda (player_sprite),y        ;5  56
            ldx TARGET_COLOR_0,y         ;4  60

            sta WSYNC
            sta GRP0                     ;3   3
            stx COLUP0                   ;3   6
            lda TARGET_BG_0,y            ;5  11
            sta COLUBK                   ;3  14
            iny                          ;2  16
            cpy #PLAYER_HEIGHT           ;2  18
            bcc _lt_lo_draw_loop_2       ;2  20

            lda #$0b
            ldx #$00
            sta WSYNC
            sta COLUBK
            stx GRP0
            stx PF0
            stx PF1
            stx PF2
            stx COLUPF

; kernel exit

            ldx local_pf_stack      ;3   --
            txs                     ;2   --

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

            ldx #4
playfield_shim_loop
            sta WSYNC
            dex
            bne playfield_shim_loop

    JMP_LBL return_main_kernel

;------------------------
; equip sub

    DEF_LBL equip_kernel
            ldy #PLAYER_HEIGHT - 1
_equip_p1_draw_loop
            sta WSYNC
            lda #P1_GRAPHICS_0,y
            sta GRP0
            lda (player_sprite),y
            sta GRP1
            dey
            bpl _equip_p1_draw_loop 
            ldy #PLAYER_HEIGHT - 1
_equip_p2_draw_loop
            sta WSYNC
            lda #P2_GRAPHICS_0,y
            sta GRP0
            lda (player_sprite + 2),y
            sta GRP1
            dey
            bpl _equip_p2_draw_loop
            sta GRP0 ; for vdelay
            JMP_LBL equip_kernel_return

P1_GRAPHICS_0
    byte $0, $8e, $84, $84, $e4, $a4, $20, $ec
P2_GRAPHICS_0
    byte $0, $86, $88, $88, $e6, $a2, $20, $ec

;------------------------
; game data

    ; try to avoid page branching problems
    ALIGN 256

P0_WALLS
	; .byte %11000000
	; .byte %10000000
	; .byte %10000000
	; .byte %01000000
	; .byte %01000000
	; .byte %11000000
	; .byte %11000000
	; .byte %01000000
	; .byte %01000000
	; .byte %00000000
	; .byte %11000000
	; .byte %10000000
	; .byte %11000000
	; .byte %00000000
	; .byte %10000000
	; .byte %11000000

	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %01000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %10000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %01000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %10000000

	; .byte %11000000
	; .byte %11000000
	; .byte %01000000
	; .byte %01000000
	; .byte %11000000
	; .byte %11000000
	; .byte %10000000
	; .byte %10000000
	; .byte %11000000
	; .byte %11000000
	; .byte %01000000
	; .byte %01000000
	; .byte %11000000
	; .byte %11000000
	; .byte %10000000
	; .byte %10000000

	; .byte %10000000
	; .byte %10110000
	; .byte %01100000
	; .byte %11010000
	; .byte %00010000
	; .byte %11010000
	; .byte %01100000
	; .byte %10110000
	; .byte %10000000
	; .byte %10110000
	; .byte %01100000
	; .byte %11010000
	; .byte %00010000
	; .byte %11010000
	; .byte %01100000
	; .byte %10110000

    ; byte #$50,#$20,#$50,#$A0,#$50,#$A0,#$50,#$A0
    ; byte #$50,#$20,#$50,#$A0,#$50,#$A0,#$50,#$A0

P2_GOAL_TOP
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$01,#$01
    byte #$03,#$03,#$07,#$07,#$ff,#$ff,#$ff,#$ff

PX_WALLS_BLANK
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

P2_GOAL_BOTTOM   
    byte #$ff,#$ff,#$ff,#$ff,#$07,#$07,#$03,#$03
    byte #$01,#$01,#$00,#$00,#$00,#$00,#$00,#$00


P1_GOAL_BOTTOM
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    byte #$ff,#$ff,#$ff,#$7f,#$01,#$01,#$00,#$00

P1_GOAL_TOP
    byte #$00,#$00,#$01,#$01,#$7f,#$ff,#$ff,#$ff 
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f



P1_WALLS_CHUTE
P2_WALLS_CHUTE
    byte #$00,#$00,#$00,#$00,#$01,#$01,#$01,#$01
    byte #$00,#$00,#$00,#$00,#$01,#$01,#$01,#$01

P1_WALLS_DIAMONDS
    byte #$00,#$00,#$00,#$08,#$14,#$14,#$14,#$22
    byte #$22,#$22,#$14,#$14,#$14,#$08,#$00,#$00

P2_WALLS_CUBES_TOP
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
P2_WALLS_CUBES_BOTTOM
    byte #$e0,#$e0,#$e0,#$20,#$20,#$e0,#$e0,#$e0
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    ALIGN 256

COLUBK_COLORS_0
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
COLUBK_COLORS_1
    byte #$02,#$02,#$02,#$02,#$02,#$02,#$02,#$02
    byte #$02,#$02,#$02,#$02,#$02,#$02,#$02,#$02
COLUBK_COLORS_2
    byte #$09,#$09,#$09,#$09,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

COLUPF_COLORS_0
    byte #$06,#$06,#$08,#$08,#$0a,#$0a,#$0c,#$0c
    byte #$0e,#$0e,#$0c,#$0c,#$0a,#$0a,#$08,#$08

BALL_GRAPHICS
    byte #$3c,#$7e,#$ff,#$ff,#$ff,#$ff,#$7e,#$3c
BALL_GRAPHICS_END

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END

MTP_MKI_0
    byte $0,$18,$3c,$30,$ff,$55,$ff,$3c,$18; 9
MTP_MKI_1
    byte $0,$18,$3c,$0,$ff,$aa,$ff,$3c,$18; 9
MTP_MKI_2
    byte $0,$18,$3c,$c,$ff,$55,$ff,$3c,$18; 9
MTP_MKI_3
    byte $0,$18,$3c,$3c,$ff,$aa,$ff,$3c,$18; 9
MTP_MKIV_0
    byte $0,$18,$7e,$f7,$55,$55,$f7,$7e,$3c; 9
MTP_MKIV_1
    byte $0,$18,$7e,$ef,$aa,$aa,$ef,$7e,$3c; 9
MTP_MKIV_2
    byte $0,$18,$7e,$dd,$55,$55,$dd,$7e,$3c; 9
MTP_MKIV_3
    byte $0,$18,$7e,$bb,$aa,$aa,$bb,$7e,$3c; 9
MTP_MX888_0
    byte $0,$2a,$80,$3d,$e7,$42,$ff,$e7,$81; 9
MTP_MX888_1
    byte $0,$54,$1,$bc,$e7,$42,$ff,$e7,$81; 9
MTP_MX888_2
    byte $0,$2a,$80,$3d,$e7,$42,$ff,$e7,$81; 9
MTP_MX888_3
    byte $0,$54,$1,$bc,$e7,$42,$ff,$e7,$81; 9
TARGET_COLOR_0
    byte $0,$0a,$0c,$0e,$0e,$0f,$0e,$0e,$0c,$0a; 9
TARGET_BG_0
    byte $0,$00,$00,$0b,$bc,$bc,$0b,$00,$00,$00; 9

COLUBK_0_ADDR
    word #COLUBK_COLORS_0
COLUBK_1_ADDR
    word #COLUBK_COLORS_1
COLUBK_2_ADDR
    word #COLUBK_COLORS_2

COLUPF_0_ADDR
    word #COLUPF_COLORS_0

    END_BANK

    START_BANK 1

; ----------------------------------
; Main Bank

CleanStart
    ; do the clean start macro
            CLEAN_START

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
            lda scroll
            and #$0f
            sta display_scroll

            ; power_grid update
power_grid_update
            lda frame
            lsr
            lsr
            and #$1f
            tay
            ldx #NUM_PLAYERS - 1
_power_grid_update_loop
            lda TRACK_PF0_GRID,y
            sta power_grid_pf0,x
            lda TRACK_PF1_GRID,y
            sta power_grid_pf1,x
            lda TRACK_PF2_GRID,y
            sta power_grid_pf2,x
            dex
            bpl _power_grid_update_loop

player_update
            ldx #NUM_PLAYERS - 1
_player_update_loop
            ;
            ; TODO: control player using jx_ callback
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
            cmp #<MTP_MKI_3 ; TODO: swap
            bcc _player_update_anim_right
            lda #<MTP_MKI_0 ; TODO: swap
_player_update_anim_right
            sta player_sprite,y
            jmp _player_end_move
_player_update_left
            lda player_x,x
            cmp #PLAYER_MIN_X
            bcc _player_end_move
            sbc #$01
            sta player_x,x
            lda player_sprite,y ; BUGBUG: can do indirectly?
            sec 
            sbc #PLAYER_HEIGHT
            cmp #<MTP_MKI_0 ; BUGBUG: need to make work correctly
            bcs _player_update_anim_left
            lda #<MTP_MKI_3 ; BUGBUG: need to make work correctly
_player_update_anim_left
            sta player_sprite,y
_player_end_move
            ; power ; BUGBUG: debugging power
            lda player_power,x
            beq _player_no_fire 
            inc ball_color ; BUGBUG: just for debug
            lda #$00
            sta player_power,x
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
            lda #$00
            sta local_player_draw_buffer + 1
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
            sta local_player_draw_buffer ; point at top of beam hmov stack
            lda player_x,x
            sec
            sbc player_aim_x,x    ; dx
            jmp _player_aim_beam_interp
_player_aim_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            tay           ; dy
            lda #laser_hmov_0
            sta local_player_draw_buffer ; point to top of beam hmov stack
            lda player_aim_x,x
            sec
            sbc player_x,x ; dx
_player_aim_beam_interp
            cpy #PLAYFIELD_BEAM_RES ; if dy < BEAM res, double everything
            bcs _player_aim_beam_end
            asl 
            sta local_player_dx
            tya
            asl 
            tay
            lda local_player_dx
_player_aim_beam_end

            ; figure out beam path
_player_draw_beam_calc ; on entry, a is dx (signed), y is dy (unsigned)
            sty local_player_dy
            cmp #00
            bpl _player_draw_beam_left
            eor #$ff
            clc
            adc #$01
            cmp local_player_dy
            bcc _player_draw_skip_normalize_dx_right
            tya
_player_draw_skip_normalize_dx_right
            sta local_player_dx 
            lda #$f0
            jmp _player_draw_beam_set_hmov
_player_draw_beam_left
            cmp local_player_dy
            bcc _player_draw_skip_normalize_dx_left
            tya
_player_draw_skip_normalize_dx_left
            sta local_player_dx
            lda #$10
_player_draw_beam_set_hmov
            sta local_player_hmove
            asl local_player_dx  ; dx = 2 * dx
            lda local_player_dx
            sec
            sbc local_player_dy  ; D = 2dx - dy
            asl local_player_dy  ; dy = 2 * dy
            sta local_player_D
            lda #$00
            sta local_player_x_travel
            ldy #PLAYFIELD_BEAM_RES - 1 ; will stop at 16
_player_draw_beam_loop
            lda #$01
            cmp local_player_D
            bpl _player_draw_beam_skip_bump_hmov
            ; need an hmov
            lda local_player_D
            sec
            sbc local_player_dy  ; D = D - 2 * dy
            sta local_player_D
            lda local_player_hmove
            inc local_player_x_travel
_player_draw_beam_skip_bump_hmov
            sta (local_player_draw_buffer),y ; cheating that #$01 is in a
            lda local_player_D
            clc
            adc local_player_dx  ; D = D + 2 * dx
            sta local_player_D
            dey
            bpl _player_draw_beam_loop
            lda player_state,x
            and #PLAYER_STATE_FIRING
            bne _player_draw_beam_end
            ; calc ax/ay coefficient
            ldy #$f0
            sec
            lda #PLAYFIELD_BEAM_RES * 2
            sbc local_player_x_travel
            cpx #$00
            bne _player_draw_beam_skip_invert_ay
            ldy #$10
            eor #$ff
            clc
            adc #$01
_player_draw_beam_skip_invert_ay
            sta laser_ay,x
            lda local_player_x_travel
            cpy local_player_hmove 
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
            ; last local_player_x_travel will have the (signed) x distance covered  
            ; multiply by 5 to get 80 scanline x distance
            lda local_player_x_travel
            asl 
            asl 
            clc
            adc local_player_x_travel
            ldy local_player_hmove 
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
            ; position players
            lda #120
            sta player_x + 1
            lda #0
            sta player_x
            ldx #1
            jsr switch_player
            ldx #0
            jsr switch_player
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
            jsr switch_formation
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
            lda #(GS_MENU_GAME + __MENU_GAME_TOURNAMENT)
            sta game_state
            jsr switch_game_mode
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
            asl
            asl
            and #$30
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
            cpy #3
            bcc _switch_stage_save
            ldy #0
_switch_stage_save
            sty formation_select
            beq formation_chute
            dey
            beq formation_diamonds
formation_void
            lda #<FORMATION_VOID_UP
            sta formation_up
            lda #>FORMATION_VOID_UP
            sta formation_up + 1
            rts
formation_chute
            lda #<FORMATION_CHUTE_UP
            sta formation_up
            lda #>FORMATION_CHUTE_UP
            sta formation_up + 1
            rts
formation_diamonds
            lda #<FORMATION_DIAMONDS_UP
            sta formation_up
            lda #>FORMATION_DIAMONDS_UP
            sta formation_up + 1
            rts

    ALIGN 256

FORMATION_VOID_UP
            ; figure out which formation block is first
            ; and where it starts
            lda scroll
            lsr
            lsr
            lsr
            lsr
            asl
            tax
            ldy #0
_formation_void_dl_loop
            lda FORMATION_VOID_P1,x
            sta formation_p1_dl,y
            lda FORMATION_VOID_P2,x
            sta formation_p2_dl,y
            inx
            iny
            lda FORMATION_VOID_P1,x
            sta formation_p1_dl,y
            lda FORMATION_VOID_P2,x
            sta formation_p2_dl,y
            inx
            iny
            cpy #12
            bcc _formation_chute_dl_loop
            jmp formation_update_return

FORMATION_CHUTE_UP
            ; figure out which formation block is first
            ; and where it starts
            lda scroll
            lsr
            lsr
            lsr
            lsr
            asl
            tax
            ldy #0
_formation_chute_dl_loop
            lda FORMATION_CHUTE_P1,x
            sta formation_p1_dl,y
            lda FORMATION_CHUTE_P2,x
            sta formation_p2_dl,y
            inx
            iny
            lda FORMATION_CHUTE_P1,x
            sta formation_p1_dl,y
            lda FORMATION_CHUTE_P2,x
            sta formation_p2_dl,y
            inx
            iny
            cpy #12
            bcc _formation_chute_dl_loop
            jmp formation_update_return

FORMATION_DIAMONDS_UP
            ; figure out which formation block is first
            ; and where it starts
            lda scroll
            lsr
            lsr
            lsr
            lsr
            asl
            tax
            ldy #0
_formation_diamonds_dl_loop
            lda FORMATION_DIAMONDS_P1,x
            sta formation_p1_dl,y
            lda FORMATION_DIAMONDS_P2,x
            sta formation_p2_dl,y
            inx
            iny
            lda FORMATION_DIAMONDS_P1,x
            sta formation_p1_dl,y
            lda FORMATION_DIAMONDS_P2,x
            sta formation_p2_dl,y
            inx
            iny
            cpy #12
            bcc _formation_diamonds_dl_loop
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

;------------------------
; power grid patterns


TRACK_PF0_GRID
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $10
	.byte $30
	.byte $70
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
	.byte $f0
    .byte $e0
    .byte $c0
    .byte $80
    .byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00

TRACK_PF1_GRID
	.byte $ff
	.byte $7f
	.byte $3f
	.byte $1f
	.byte $0f
	.byte $07
	.byte $03
	.byte $01
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $c0
	.byte $f0
	.byte $fc
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff

TRACK_PF2_GRID
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $fe
	.byte $fc
	.byte $f8
	.byte $f0
	.byte $e0
	.byte $c0
	.byte $80
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $00
	.byte $03
	.byte $0f
	.byte $3f
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff

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

        ; select which screen to show
        DEF_LBL attract_menu_kernels
            lda game_state
            and #$0f
            asl
            tax
            lda MENU_JUMP_TABLE,x
            sta local_jmp_addr
            lda MENU_JUMP_TABLE + 1,x
            sta local_jmp_addr + 1
            jmp (local_jmp_addr)

    align 2

MENU_JUMP_TABLE
    word kernel_showSplash
    word kernel_showSplash
    word kernel_showSplash
    word kernel_title
    word kernel_menu_game
    word kernel_menu_equip
    word kernel_menu_stage
    word kernel_menu_track


;------------------
; title

kernel_title
            jsr waitOnVBlank_2 ; SL 34

            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #(192 / 2 - TITLE_HEIGHT * 2 - 8)
            jsr sky_kernel

            jsr title_kernel

            ldx #(SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 42)
            jsr grid_kernel

            ; jump back
            JMP_LBL waitOnOverscan


;------------------------
; std menu kernels

    align 256

kernel_menu_game
kernel_menu_equip
kernel_menu_stage
kernel_menu_track
            ; load game
            lda game_state
            lsr
            lsr
            lsr
            lsr
            tax
            ldy GAME_MODE_NAMES,x
            lda #12
            ldx #STRING_BUFFER_0
            jsr strfmt
            ; load player graphics
            lda #>MTP_MKI_0
            sta player_sprite + 1
            sta player_sprite + 3
            ldx player_select
            lda PLAYER_SPRITES,x
            sta player_sprite
            ldx player_select + 1
            lda PLAYER_SPRITES,x
            sta player_sprite + 2
            ; load stage
            lda #12
            ldx formation_select
            ldy STAGE_NAMES,x
            ldx #STRING_BUFFER_6
            jsr strfmt
            ; load track
            lda #8
            ldx track_select
            ldy TRACK_NAMES,x
            ldx #STRING_BUFFER_C
            jsr strfmt

            jsr waitOnVBlank_2 ; SL 34
            
            ldx #20
            jsr sky_kernel
            
            ; menu title text
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_GAME
            bne _not_title
            ldy #30
_not_title
            ldx #STRING_BUFFER_0
            jsr text_kernel

            ; players
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_EQUIP
            bne _not_equip
            ldy #30
_not_equip
            sty COLUP0
            sty COLUP1
            sta WSYNC               ;3   0
            lda #41                 ;3   3
            sec                     ;2   5
_equip_resp_loop
            sbc #15                 ;2   7
            sbcs _equip_resp_loop   ;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE_2,y;4  15+
            sta HMP0                ;3  18+
            sta HMP1                ;3  21+
            sta RESP0               ;3  24+ 
            sta RESP1               ;3  27+ 
            sta WSYNC
            sta HMOVE
            lda #0
            sta NUSIZ0
            sta NUSIZ1
            JMP_LBL equip_kernel
    DEF_LBL equip_kernel_return
            sta WSYNC 

            ; stage
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_STAGE
            bne _not_stage
            ldy #30
_not_stage
            ldx #STRING_BUFFER_6
            jsr text_kernel

            ; track
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_TRACK
            bne _not_track
            ldy #30
_not_track
            ldx #STRING_BUFFER_C
            jsr text_kernel_4

            ldx #19
            jsr sky_kernel

            ; bottom grid
            ldx #SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 42
            jsr grid_kernel
            
            JMP_LBL waitOnOverscan            


;--------------------------
; sky drawing minikernel

            ; x is number of lines
sky_kernel
            sta WSYNC
            lda #$00
            sta COLUBK
            dex
            bne sky_kernel
            rts



;--------------------------
; text drawing minikernel
; x is string buffer location
; y is color

text_kernel
            sta WSYNC
            lda #$01
            sta VDELP0
            sta VDELP1
            SLEEP 24
;             lda #30
;             sec
; _text_resp_loop
;             sbc #15
;             bcs _text_resp_loop
            sta RESP0    
            sta RESP1
            lda #$03
            sta NUSIZ0
            sta NUSIZ1
            sty COLUP0
            sty COLUP1
            lda #$ff
            sta HMP0
            lda #$00
            sta HMP1
            sta WSYNC
            sta HMOVE

            txa
            sta local_pf_y_min
            clc
            adc #7 ; font height
            tay
            tsx
            stx local_pf_stack
_text_draw_0
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
            cpy local_pf_y_min
            bpl _text_draw_0
            ldx local_pf_stack
            txs
            lda #$00
            sta NUSIZ0
            sta NUSIZ1
            sta GRP0
            sta GRP1
            sta VDELP0
            sta VDELP1
            rts

text_kernel_4
            sta WSYNC
            lda #$01
            sta VDELP0
            sta VDELP1
            SLEEP 24
;             lda #30
;             sec
; _text_resp_loop
;             sbc #15
;             bcs _text_resp_loop
            sta RESP0    
            sta RESP1
            lda #$01
            sta NUSIZ0
            sta NUSIZ1
            sty COLUP0
            sty COLUP1
            lda #$ff
            sta HMP0
            lda #$00
            sta HMP1
            sta WSYNC
            sta HMOVE

            txa
            sta local_pf_y_min
            clc
            adc #7 ; font height
            tay
_text_draw_4_0
            sta WSYNC                                     ;3   0
            ; load and store first 3 
            lda SUPERCHIP_READ + STRING_BUFFER_0,y        ;4   4
            sta GRP0                                      ;3   7
            lda SUPERCHIP_READ + STRING_BUFFER_1,y        ;4  11
            sta GRP1                                      ;3  14
            lda SUPERCHIP_READ + STRING_BUFFER_2,y        ;4  18
            sta GRP0                                      ;3  21
            ; load next 3 EDF
            ldx SUPERCHIP_READ + STRING_BUFFER_3,y        ;4  25
            SLEEP 10                                      ;10 35
            stx.w GRP1                                    ;4  39
            sty GRP0                                      ;3  42 force vdelp
            dey
            cpy local_pf_y_min
            bpl _text_draw_4_0
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
            sta local_grid_inc
            lda #$01
            sta local_grid_gap
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
            lda local_grid_gap
            asl
            sta local_grid_gap
            clc
            adc local_grid_inc
            tay
_grid_nextGridLine
            dex
            bne _grid_loop
            rts

;--------------------------
; text blitter routine
; a = chars to write
; x = graphics buffer offset
; y = char buffer offset

strfmt
            sty local_strfmt_start
            clc
            adc local_strfmt_start
            sta local_strfmt_start
            ;; only write one line per run
            lda frame
            and #$07
            sta local_strfmt_index_offset
            txa
            ;; push stack counter
            tsx
            stx local_strfmt_stack
            clc
            adc local_strfmt_index_offset
            tax 
            txs
_strfmt_loop
            lda STRING_CONSTANTS,y      
            bne _strfmt_cont
            jmp _strfmt_stop
_strfmt_cont
            lsr
            bcc _strfmt_hi___
_strfmt_lo___
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_hi
            iny 
            lda STRING_CONSTANTS,y      
            beq _strfmt_lo_00
            lsr 
            bcs _strfmt_lo_lo
            ; hi << 4 + lo >> 4 
_strfmt_lo_hi
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_lo_hi_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            lsr
            lsr
            lsr
            lsr
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_lo_hi_loop
            iny 
            jmp _strfmt_loop
            ; hi << 4 + lo & 0f
_strfmt_lo_lo
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_lo_lo_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            and #$0f
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_lo_lo_loop
            iny 
            jmp _strfmt_loop
_strfmt_lo_00            
            ldx local_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; dec local_strfmt_count
            ; bpl _strfmt_lo_00
            iny
            jmp _strfmt_stop
_strfmt_hi___
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_hi
            iny 
            lda STRING_CONSTANTS,y      
            beq _strfmt_hi_00
            lsr 
            bcs _strfmt_hi_lo
_strfmt_hi_hi
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_hi_hi_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            lsr
            lsr
            lsr
            lsr
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_hi_hi_loop
            iny 
            jmp _strfmt_loop
            ; hi << 4 + lo & 0f
_strfmt_hi_lo
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_hi_lo_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            and #$0f
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_hi_lo_loop
            iny 
            jmp _strfmt_loop
_strfmt_hi_00            
            ldx local_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; dec local_strfmt_count
            ; bpl _strfmt_hi_00
            iny
            ; fallthrough
_strfmt_stop
            tya
            sec
            sbc local_strfmt_start
            bpl _strfmt_end
            eor #$ff
            adc #$00
            lsr
            tay
            tsx
_strfmt_00_loop
            lda #$00
            sta STRING_WRITE,x
            txa
            clc
            adc #$08
            tax
            ; inx
            dey
            bpl _strfmt_00_loop
_strfmt_end
            ldx local_strfmt_stack
            txs
            rts

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
            iny
            sty GRP0
            sty GRP1
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
            iny
            sty GRP0
            sty GRP1
            rts  

;------------------------
; splash kernel

kernel_showSplash
            jsr waitOnVBlank_2 ; SL 34
            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #(SCANLINES - 69)
            ldy #8
drawSplashGrid
            sta WSYNC
            lda #0
            dey
            bne skipDrawGridLine 
            ldy game_state
            lda SPLASH_GRAPHICS,y
            ldy #8
skipDrawGridLine
            sta COLUBK
            dex
            bne drawSplashGrid

            sta WSYNC
            lda #0
            sta COLUBK

            JMP_LBL waitOnOverscan ; BUGBUG jump

;------------------------
; vblank sub

waitOnVBlank_2
            ldx #$00
_waitOnVBlank_loop_2
            cpx INTIM
            bmi _waitOnVBlank_loop_2
            stx VBLANK
            rts 
;---------------------------
; player menu graphics

    ALIGN 256 

; TODO: move to another bank?

; TODO: need a better way to dup?
STD_HMOVE_BEGIN_2
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END_2

PLAYER_SPRITES
    byte #<MTP_MKI_0
    byte #<MTP_MKIV_0
    byte #<MTP_MX888_0
    
;-----------------------------
; Font
; 4x7 bit font packed into 8x32 byte array

    ALIGN 256 

FONT_0
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$4e,$a4,$a4,$a4,$a4,$20,$cc; 8
    byte $0,$6c,$82,$82,$66,$22,$0,$cc; 8
    byte $0,$2c,$22,$62,$ac,$a8,$20,$a6; 8
    byte $0,$48,$a8,$a8,$c4,$82,$0,$6e; 8
    byte $0,$42,$a2,$a6,$ea,$aa,$22,$cc; 8
    byte $0,$0,$0,$40,$e,$40,$0,$0; 8
    byte $0,$0,$2,$46,$ee,$46,$2,$0; 8
    byte $0,$0,$8,$ec,$e,$ec,$8,$0; 8
    byte $0,$64,$40,$e0,$40,$e0,$0,$e0; 8
    byte $0,$44,$0,$44,$42,$42,$48,$4c; 8
    byte $0,$ac,$aa,$ea,$ac,$aa,$22,$ec; 8
    byte $0,$ec,$8a,$8a,$8a,$8a,$2,$ec; 8
    byte $0,$e8,$88,$88,$cc,$88,$0,$ee; 8
    byte $0,$ea,$aa,$aa,$8e,$8a,$2,$ea; 8
    byte $0,$4e,$4a,$42,$2,$42,$0,$42; 8
    byte $0,$ae,$a8,$a8,$c8,$a8,$20,$a8; 8
    byte $0,$aa,$aa,$aa,$a,$ea,$2,$ee; 8
    byte $0,$e8,$a8,$a8,$ae,$aa,$22,$ee; 8
    byte $0,$6a,$8a,$ac,$aa,$aa,$22,$ee; 8
    byte $0,$e4,$24,$24,$e4,$84,$0,$ee; 8
    byte $0,$e4,$a4,$aa,$aa,$aa,$2,$aa; 8
    byte $0,$aa,$ea,$ee,$4,$ae,$2,$aa; 8
    byte $0,$4e,$48,$48,$e4,$a2,$20,$ae; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8

; string constants
; 0 code is reserved for the end of strings
; code bytes format: xxxxx__y 
;   x locates the byte containing the char
;   y is whether we want the lo/hi nibble

STRING_CONSTANTS
STRING_GAME = . - STRING_CONSTANTS
    byte 112, 88, 136, 104, 0
STRING_EQUIP = . - STRING_CONSTANTS
    byte 104, 152, 168, 120, 145, 0
STRING_STAGE = . - STRING_CONSTANTS
    byte 160, 161, 88, 112, 104, 0
STRING_TRACK = . - STRING_CONSTANTS
    byte 161, 153, 88, 96, 128, 0
STRING_LC008 = . - STRING_CONSTANTS
    byte 129, 96, 8, 8, 40, 0
STRING_LC0X1 = . - STRING_CONSTANTS
    byte 129, 96, 8, 177, 9, 0
STRING_MX888 = . - STRING_CONSTANTS
    byte 136, 177, 40, 40, 40, 0
STRING_VERSUS = . - STRING_CONSTANTS
    byte 169, 104, 153, 160, 168, 160, 0
STRING_QUEST = . - STRING_CONSTANTS
    byte 152, 168, 104, 160, 161, 0
STRING_TOURNAMENT = . - STRING_CONSTANTS
    byte 161, 144, 168, 153, 137, 88, 136, 104, 137, 161, 0
STRING_GET_READY = . - STRING_CONSTANTS
    byte 112, 104, 161, 1, 153, 104, 88, 97, 184, 0
STRING_GATE = . - STRING_CONSTANTS
    byte 112, 88, 161, 104, 0
STRING_CLEAR = . - STRING_CONSTANTS
    byte 96, 129, 104, 88, 153, 0
STRING_GAME_OVER = . - STRING_CONSTANTS
    byte 112, 88, 136, 104, 1, 144, 169, 104, 153, 0
STRING_PLAYER_1 = . - STRING_CONSTANTS
    byte 145, 129, 88, 184, 104, 153, 1, 9, 0
STRING_PLAYER_2 = . - STRING_CONSTANTS
    byte 145, 129, 88, 184, 104, 153, 1, 16, 0
STRING_CLICK = . - STRING_CONSTANTS
    byte 96, 129, 120, 96, 128, 0
STRING_TABLA = . - STRING_CONSTANTS
    byte 161, 88, 89, 129, 88, 0
STRING_GLITCH = . - STRING_CONSTANTS
    byte 112, 129, 120, 161, 96, 113, 0
STRING_VOID = . - STRING_CONSTANTS
    byte 169, 144, 120, 97, 0
STRING_CHUTE = . - STRING_CONSTANTS
    byte 96, 113, 168, 161, 104, 0
STRING_DIAMONDS = . - STRING_CONSTANTS
    byte 97, 120, 88, 136, 144, 137, 97, 160, 0
STRING_BATTLE = . - STRING_CONSTANTS
    byte 89, 88, 161, 161, 129, 104, 0
STRING_FRACAS = . - STRING_CONSTANTS
    byte 105, 153, 88, 96, 88, 160, 0
STRING_COMBAT = . - STRING_CONSTANTS
    byte 96, 144, 136, 89, 88, 161, 0
STRING_GATEWAY = . - STRING_CONSTANTS
    byte 112, 88, 161, 104, 176, 88, 184, 0
STRING_PERIL = . - STRING_CONSTANTS
    byte 145, 104, 153, 120, 129, 0
STRING_HAZARD = . - STRING_CONSTANTS
    byte 113, 88, 185, 88, 153, 97, 0
STRING_VENDETTA = . - STRING_CONSTANTS
    byte 169, 104, 137, 97, 104, 161, 161, 88, 0
STRING_FACING = . - STRING_CONSTANTS
    byte 105, 88, 96, 120, 137, 112, 0
STRING_AGAINST = . - STRING_CONSTANTS
    byte 88, 112, 88, 120, 137, 160, 161, 0
STRING_ABSCONDER = . - STRING_CONSTANTS
    byte 88, 89, 160, 96, 144, 137, 97, 104, 153, 0

    
PLAYER_SPRITE_NAMES
    byte STRING_LC008
    byte STRING_LC0X1
    byte STRING_MX888

GAME_MODE_NAMES
    byte STRING_VERSUS
    byte STRING_QUEST
    byte STRING_TOURNAMENT

STAGE_NAMES
    byte STRING_VOID
    byte STRING_CHUTE
    byte STRING_DIAMONDS

TRACK_NAMES
    byte STRING_CLICK
    byte STRING_TABLA
    byte STRING_GLITCH

;---------------------------
; title graphics

    ALIGN 256

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

SPLASH_GRAPHICS
SPLASH_0_GRAPHICS
    byte $ff ; 
SPLASH_1_GRAPHICS
    byte $ef ; 
SPLASH_2_GRAPHICS
    byte $df ;  

    END_BANK

;
; -- audio bank
;

    START_BANK 3

            DEF_LBL bank_audio_tracker
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
_audio_stop ; got a 255
            iny 
            lda AUDIO_TRACKS,y ; store next track #
            sta audio_tracker,x 
            bne _audio_next_note ; if not zero loop back 
            sta AUDV0,x
            sta audio_timer,x
audio_next_channel
            dex
            bpl audio_loop

            JMP_LBL bank_return_audio_tracker

AUDIO_TRACKS ; AUDCx,AUDFx,AUDVx,T
    byte 0,
TRACK_0 = . - AUDIO_TRACKS
    byte 3,31,15,64,3,31,7,16,3,31,3,8,3,31,1,16,255,0;
CLICK_0 = . - AUDIO_TRACKS
    byte 3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,255,CLICK_0;
TABLA_0 = . - AUDIO_TRACKS
    byte 3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,255,TABLA_0;
GLITCH_0 = . - AUDIO_TRACKS
    byte 3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,255,GLITCH_0;



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
; MVP TODO
;  - power grid mechanics
;     - boost player shots
;     - drain player power
;     - add special powerup indicator
;  - playfields
;     - more vertical space
;  - graphical glitches
;     - remove color change glitches
;     - remove vdelay glitch on ball update
;     - lasers off at certain positions
;  - clean up play screen 
;     - adjust players
;     - adjust background / foreground color
;     - free up player/missile/ball
;     - add score
;     - remove player cutoff
;  - game over criteria
;     - some way to end game
;  - physics glitches
;     - ball score not in goal
;     - collision bugs (stuck)
;  - clean up menus 
;     - disable unused game modes
;     - better startup behavior
;     - forward/back/left/right transitions
;     - gradient color
;  MAYBE DELAY
;  - basic quest mode (could be good for testing)
;  - shield weapon (would be good to test if possible)
;  DELAY
;  - make lasers refract off ball (maybe showing the power of the shot?)
;  - basic special attacks
;    - gravity blast
;    - emp
;  THINK ABOUT 
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
;    - choose defenses
;         - each player configures their defence
;    - choose track
;         - double press - on both press go to game
;    - join fhaktion 
;         - build pod / more combinations
;    - secret code
;         - extra special weapons
;  - physics
;    - friction
;    - gradient field 
;    - boost zones
;    - speed limit
;  - dynamic playfield
;    - animated levels
;    - gradient fields 
;    - cellular automata
;    - dark levels
;  - play with grid design
;  - initial, weak, opposing ai
;    - auto move ability
;    - auto fire ability
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