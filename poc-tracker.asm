
    processor 6502
    include "vcs.h"
    include "macro.h"
    include "math.h"
    include "refhraktor.h"
    include "bank_switch_f8.h"

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

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

frame        ds 1  ; frame counter
game_timer   ds 1  ; countdown

audio_tracker ds 2  ; next track
audio_timer   ds 2  ; time left on audio

track_select     ds 1           ; which audio track

tx_on_timer      ds 2  ; timed event sub ptr
jx_on_press_down ds 2  ; on press sub ptr
jx_on_move       ds 2  ; on move sub ptr

player_input  ds NUM_PLAYERS      ; player input buffer
player_sprite ds 2 * NUM_PLAYERS  ; pointer

LOCAL_OVERLAY           ds 8

; -- joystick kernel locals
local_jx_player_input = LOCAL_OVERLAY
local_jx_player_count = LOCAL_OVERLAY + 1

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


            ; resp not
            lda audio_timer
            sec
            sbc #64
            eor #$ff
            clc
            adc #1
            sta WSYNC
            sec
_note_1_resp_loop
            sbc #15
            sbcs _note_1_resp_loop
            tay
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMM0                ;3  18+
            sta RESM0
            lda #2
            sta ENAM0

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
            SLEEP 3                 ;3  21+ ; BUGBUG: leftover
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
           
            ldy #15
_arena_loop
            sta WSYNC
            dey 
            bpl _arena_loop

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

    END_BANK

    START_BANK 1

; ----------------------------------
; Main Bank

CleanStart
    ; do the clean start macro
            CLEAN_START


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
    byte CLICK_0
    byte TABLA_0
    byte GLITCH_0

;------------------------
; vblank sub

waitOnVBlank
            ldx #$00
waitOnVBlank_loop          
            cpx INTIM
            bmi waitOnVBlank_loop
            stx VBLANK
            rts 


;
; -- audio bank
;

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




    END_BANK