
    processor 6502
    include "vcs.h"
    include "macro.h"
    include "math.h"
    include "refhraktor.h"
    include "bank_switch_f6.h"

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

NUM_PLAYERS        = 2
NUM_AUDIO_CHANNELS = 2

DROP_DELAY            = 63
SPLASH_DELAY          = 7
CELEBRATE_DELAY       = 127

PLAYFIELD_WIDTH = 154
PLAYFIELD_VIEWPORT_HEIGHT = 80
PLAYFIELD_BEAM_RES = 16

PLAYER_MIN_X = 3
PLAYER_MAX_X = 140
BALL_MIN_X = 12
BALL_MAX_X = 132

GOAL_SCORE_DEPTH = 4
GOAL_HEIGHT = 16
PLAYER_HEIGHT = MTP_MKIV_1 - MTP_MKIV_0

LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

frame        ds 1  ; frame counter
game_timer   ds 1  ; countdown

audio_order        ds 1  ; where are we in song
audio_row_idx      ds 1  ; where are we in pattern
audio_pattern_idx  ds 2  ; which pattern is playing
audio_waveform_idx ds 2  ; where are we in waveform
audio_timer        ds 2  ; time left on next action
tmp_pattern_ptr    ds 2  ; holding for pattern ptr
tmp_waveform_ptr   ds 2  ; holding for waveform ptr

grid_x        ds 1
grid_timer    ds 1
grid_power    ds 1

track_select     ds 1           ; which audio track

tx_on_timer      ds 2  ; timed event sub ptr
jx_on_press_down ds 2  ; on press sub ptr
jx_on_move       ds 2  ; on move sub ptr

player_input  ds NUM_PLAYERS      ; player input buffer
player_sprite ds 2 * NUM_PLAYERS  ; pointer
player_x      ds NUM_PLAYERS  ; player x position
player_bg     ds 2 * NUM_PLAYERS  ; 

LOCAL_OVERLAY           ds 8

; -- joystick kernel locals
local_jx_player_input = LOCAL_OVERLAY
local_jx_player_count = LOCAL_OVERLAY + 1

; -- player bkgnd computation
local_tmp_power = LOCAL_OVERLAY

; -- player track locals
local_pf0 = LOCAL_OVERLAY

; ----------------------------------
; bank 0

  SEG bank_0_code

    START_BANK 0

    DEF_LBL fhrakas_kernel

            ldx #40
_top_margin_loop
            sta WSYNC
            dex
            bne _top_margin_loop

;---------------------
; laser track (hi)

            lda #$00
            sta COLUPF
            sta COLUBK

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
            ldy #PLAYER_HEIGHT - 1       ;2  11

_lt_hi_draw_loop_2
            lda (player_sprite+2),y      ;5  16
            ldx TARGET_COLOR_0,y         ;4  20

            sta WSYNC
            sta GRP0                     ;3   3
            stx COLUP0                   ;3   6
            lda (player_bg+2),y          ;5  11
            sta COLUBK                   ;3  14
            dey                          ;2  16
            cpy #PLAYER_HEIGHT - 3       ;2  18
            bcs _lt_hi_draw_loop_2       ;2  20
            lda #$ff                     ;2  22
            sta PF0                      ;3  25
            sta PF1                      ;3  28
            sta PF2                      ;3  31
            lda (player_bg+2),y          ;5  36
            sta COLUBK                   ;3  39

            lda (player_sprite+2),y ;5  44
            ldx TARGET_COLOR_0,y    ;4  48
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$00                ;2   8
            sta COLUPF              ;3  11
            sta PF0                 ;3  14
            ldx grid_x              ;3  17
            lda TRACK_PF2_GRID,x    ;4  21
            sta PF1                 ;3  24
            lda TRACK_PF1_GRID,x    ;4  28
            sta PF2                 ;3  31
            dey                     ;2  33
            
            lda (player_sprite+2),y   ;5  56
            ldx TARGET_COLOR_0,y    ;4  60
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda (player_bg+2),y     ;5  11
            sta COLUBK              ;3  14
            dey                     ;2  16

               
            lda (player_sprite+2),y   ;5  56
            ldx TARGET_COLOR_0,y    ;4  60
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda (player_bg+2),y       ;5  11
            sta COLUBK              ;3  14
            lda #$00                ;2  16
            sta PF0                 ;3  19
            sta PF1                 ;3  22
            sta PF2                 ;3  25
            dey                     ;2  27
            
_lt_hi_draw_loop_0
            lda (player_sprite+2),y   ;5  32
            ldx TARGET_COLOR_0,y    ;4  36
            sta WSYNC
            sta GRP0                     ;3   3
            stx COLUP0                   ;3   6
            lda (player_bg+2),y            ;5  11
            sta COLUBK                   ;3  14
            dey                          ;2  16
            bpl _lt_hi_draw_loop_0       ;2  20


;---------------------
; arena
            ldy #45
_arena_lo_loop
            sta WSYNC
            dey 
            bpl _arena_lo_loop

;---------------------
; laser track (mkiv)

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
            lda #$ff                ;2  32
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
            lda (player_bg),y       ;5  11
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
            sta COLUPF              ;3  11
            iny                     ;2  13

            lda (player_bg),y       ;5  18
            sta COLUBK              ;3  21
            lda (player_sprite),y   ;5  26
            ldx TARGET_COLOR_0,y    ;4  30
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$00                ;2   8
            sta COLUPF              ;3  11
            sta PF0                 ;3  14
            ldx grid_x              ;3  17
            lda TRACK_PF2_GRID,x    ;4  21
            sta PF1                 ;3  24
            lda TRACK_PF1_GRID,x    ;4  28
            sta PF2                 ;3  31
            iny                     ;2  33
            
            lda (player_sprite),y   ;5  56
            ldx TARGET_COLOR_0,y    ;4  60
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            iny                     ;2  33
            
            lda (player_sprite),y   ;5  56
            ldx TARGET_COLOR_0,y    ;4  60
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$0a                ;2   8
            sta COLUPF              ;3  11
            lda #$ff                ;2  13
            sta PF0                 ;3  16
            sta PF1                 ;3  19
            sta PF2                 ;3  21
            iny                     ;2  23
            
            lda (player_bg),y       ;5  28
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
            lda (player_bg),y            ;5  11
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

            lda #0
            sta WSYNC
            stx COLUBK
            sta WSYNC



; kernel exit

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

            ldx #40
_bottom_margin_loop
            sta WSYNC
            dex
            bne _bottom_margin_loop

    JMP_LBL return_main_kernel

;------------------------
; game data

    ; try to avoid page branching problems
    ALIGN 256

P0_WALLS
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00
    byte #$30,#$c0,#$80,#$00,#$30,#$c0,#$80,#$00

    
    ALIGN 256

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END

MTP_MKI_0
    byte $0,$18,$3c,$ff,$55,$ff,$30,$3c,$18; 9
MTP_MKI_1
    byte $0,$18,$3c,$ff,$aa,$ff,$0,$3c,$18; 9
MTP_MKI_2
    byte $0,$18,$3c,$ff,$55,$ff,$c,$3c,$18; 9
MTP_MKI_3
    byte $0,$18,$3c,$ff,$aa,$ff,$3c,$3c,$18; 9
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
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$00,$00; 8
TARGET_BG_1
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$00,$b2; 8
TARGET_BG_2
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$b0,$b2; 8
TARGET_BG_3
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$b2,$b4; 8
TARGET_BG_4
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$b2,$b4; 8
TARGET_BG_5
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$b4,$b8; 8
TARGET_BG_6
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$b4,$b8; 8
TARGET_BG_7
    byte $00,$00,$00,$0b,$bf,$bf,$0b,$ba,$ba; 8


TRACK_PF1
	.byte %00000000
	.byte %11111111
	.byte %00000000
	.byte %10000000
	.byte %11111111
	.byte %10000000
	.byte %00000000
	.byte %11111111
	.byte %00000000


TRACK_PF2
	.byte %00000000
	.byte %11111111
	.byte %00000000
	.byte %00000000
	.byte %11111111
	.byte %00000000
	.byte %00000000
	.byte %11111111
	.byte %00000000


TRACK_PF1_GRID
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
	.byte $03
	.byte $0f
	.byte $3f
	.byte $ff

TRACK_PF2_GRID
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
	.byte $c0
	.byte $f0
	.byte $fc
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
	.byte $ff
    
    END_BANK

    START_BANK 1

; ----------------------------------
; Main Bank

CleanStart
    ; do the clean start macro
            CLEAN_START

    ; setup
            SET_TX_CALLBACK noop_on_timer, 0
            SET_JX_CALLBACKS noop_on_press_down, noop_on_move
            ldx #NUM_PLAYERS - 1
_player_setup_loop
            lda #PLAYFIELD_WIDTH / 2
            sta player_x,x
            dex
            bpl _player_setup_loop
            ; load player graphics
            lda #>MTP_MKIV_0
            sta player_sprite + 1
            sta player_sprite + 3
            lda #<MTP_MKIV_0
            sta player_sprite
            sta player_sprite + 2
            lda #>TARGET_BG_0
            sta player_bg + 1
            sta player_bg + 3
            lda #<TARGET_BG_0
            sta player_bg + 0

            ; load track
            JMP_LBL bank_audio_init
        DEF_LBL bank_return_audio_init

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

            ; power graphics
            lda grid_power
            and #$07
            sta local_tmp_power
            asl
            asl
            asl
            clc
            adc local_tmp_power
            adc #<TARGET_BG_0
            sta player_bg + 0
            sta player_bg + 2

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
            lda player_sprite,y ; bugbug can do indirectly?
            sec 
            sbc #PLAYER_HEIGHT
            cmp #<MTP_MKI_0 ; TODO: swap
            bcs _player_update_anim_left
            lda #<MTP_MKI_3 ; TODO: swap
_player_update_anim_left
            sta player_sprite,y
_player_end_move
            ;; next player
            dex
            bpl _player_update_loop

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

    DEF_LBL waitOnOverscan
            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop
            jmp newFrame


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
    ; byte CLICK_0
    ; byte TABLA_0
    ; byte GLITCH_0

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
; -- audio bank
;

    START_BANK 2

            DEF_LBL bank_audio_init
            ldy #0
            lda ORDERS,y
            sta audio_pattern_idx
            iny
            lda ORDERS,y
            sta audio_pattern_idx+1
            iny
            sty audio_order
            JMP_LBL bank_return_audio_init

            DEF_LBL bank_audio_tracker
audio_tracker           
            ldx #NUM_AUDIO_CHANNELS - 1
audio_loop 
            ldy audio_timer,x
            beq _audio_next_note
            dey
            sty audio_timer,x
            jmp _audio_next_channel
_audio_next_note
            ldy audio_pattern_idx,x 
            lda PAT_TABLE_START,y
_audio_next_note_t
            sta tmp_pattern_ptr
            lda PAT_TABLE_START+1,y
            sta tmp_pattern_ptr + 1
            ldy audio_row_idx
            lda (tmp_pattern_ptr),y
_audio_next_note_ty
            tay                       ; y is now waveform ptr
            lda WF_TABLE_START,y
            sta tmp_waveform_ptr
            lda WF_TABLE_START+1,y
            sta tmp_waveform_ptr + 1
            ldy audio_waveform_idx,x
            lda (tmp_waveform_ptr),y
            cmp #255
            beq _audio_advance_tracker
            sta AUDC0,x
            iny
            lda (tmp_waveform_ptr),y
            sta AUDF0,x
            iny
            lda (tmp_waveform_ptr),y
            sta AUDV0,x
            iny
            lda (tmp_waveform_ptr),y
            sta audio_timer,x
            iny
            sty audio_waveform_idx,x
            jmp _audio_next_channel
_audio_advance_tracker ; got a 255 on waveform
            lda #255
            sta audio_timer,x
            lda #255
            sta audio_waveform_idx,x
_audio_next_channel
            dex
            bpl audio_loop

            ; update track - check if both waveforms done
            lda audio_waveform_idx
            and audio_waveform_idx+1
            cmp #255
            bne audio_end            
            lda #0
            sta audio_timer
            sta audio_timer+1
            sta audio_waveform_idx
            sta audio_waveform_idx+1
            ldy audio_row_idx
            iny
            lda (tmp_pattern_ptr),y
            cmp #255
            beq _audio_advance_order
            sty audio_row_idx
            jmp audio_tracker; if not 255 loop back 
_audio_advance_order ; got a 255 on pattern
            lda #0
            sta audio_row_idx
            ldy audio_order
            lda ORDERS,y
            cmp #255
            bne _audio_advance_order_advance_pattern
            ldy #0
            lda ORDERS,y
_audio_advance_order_advance_pattern
            sta audio_pattern_idx
            iny
            lda ORDERS,y
            sta audio_pattern_idx+1
            iny
            sty audio_order
            jmp audio_tracker;  loop back 

audio_end

_grid_update
            dec grid_timer
            bpl _skip_grid_update
            lda #4
            sta grid_timer
_grid_advance
            lda grid_x
            clc
            adc #1
            cmp #24
            bcc _end_grid_update
            inc grid_power
            lda #$00
_end_grid_update
            sta grid_x
_skip_grid_update

            JMP_LBL bank_return_audio_tracker

    ALIGN 256

    #include "game_tracks.inc"

    END_BANK

    START_BANK 3

    END_BANK