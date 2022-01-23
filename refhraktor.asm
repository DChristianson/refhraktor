
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
PLAYFIELD_VIEWPORT_HEIGHT = 160
PLAYFIELD_BEAM_RES = 40

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

game_state   ds 1
game_timer   ds 1

frame        ds 1

player_opt    ds 2  ; player options (d0 = ball tracking on/off, d1 = manual aim on/off)
player_x      ds 2  ; player absolute x
player_bg     ds 4  ;
player_color  ds 4  ;
player_sprite ds 4  ;
laser_color   ds 2  ;
laser_lo_x    ds 1  ; start x for the low laser
laser_lo_hmov ds 1  ; hmov dir for the low laser
laser_hmov    ds PLAYFIELD_BEAM_RES ; how much to hmove the laser

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
    lda #$00
    sta ball_dy
    lda #$00
    sta ball_dx
    lda #128 - BALL_HEIGHT / 2
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
            jmp _player_draw_beam
_player_update_right
            lda player_x,x
            cmp #PLAYER_MAX_X
            bcs _player_draw_beam
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
            jmp _player_draw_beam
_player_update_left
            lda player_x,x
            cmp #PLAYER_MIN_X
            bcc _player_draw_beam
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
_player_draw_beam
            ; auto-aim, calc distance between player and ball
            lda ball_voffset
            sec ; 
            ror
            sec ;
            ror ; expected to be negative so double ror should / 4
            cpx #$00
            beq _player_draw_beam_lo
_player_draw_beam_hi
            eor #$ff      ; invert offset to get dy
            clc
            adc #$01
            sta laser_lo_x ; save for lo x calc later
            tay            ; dy
            lda #laser_hmov
            sta temp_draw_buffer ; point at top of beam hmov stack
            lda player_x,x
            sec
            sbc ball_x    ; dx
            jmp _player_draw_beam_calc
_player_draw_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_BEAM_RES
            tay           ; dy
            eor #$ff      ; invert dy
            clc
            adc #laser_hmov + PLAYFIELD_BEAM_RES - 1
            sta temp_draw_buffer ; point to middle of beam hmov stack
            lda ball_x
            sec
            sbc player_x,x ; dx
_player_draw_beam_calc ; on entry, a is dx (signed), y is dy (unsigned)
            sty temp_dy
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
            ; find lo x starting point
            lda #PLAYER_MAX_X
            sec 
            sbc laser_lo_x
            cmp ball_x
            bcc _refract_lo_left
            lda laser_lo_x
            cmp ball_x
            bcs _refract_lo_right 
            lda frame
            and #$01
            bne _refract_lo_right
_refract_lo_left
            lda ball_x
            sec
            sbc laser_lo_x
            ldx #$f0
_refract_lo_right
            lda ball_x
            clc
            adc laser_lo_x
            ldx #$10
_refract_lo_save
            sta laser_lo_x
            stx laser_lo_hmov

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
            sta RESM1               ;4  28+

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
            lda (player_bg+2),y       ;6   6
            sta COLUBK              ;3   9
            lda (player_sprite+2),y   ;6  15
            sta GRP1                ;3  18
            lda (player_color+2),y    ;6  24
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
            SLEEP 3               ;3  21+
            sta RESM0             ;3  24+

            ; hmove ++ and prep for playfield next line
            sta WSYNC                    ;0   0
            sta HMOVE                    ;3   3
            lda #2                       ;2   5
            sta ENAM0                    ;3   8
            sta ENAM1                    ;3  11
            lda laser_color+1            ;3  14
            sta COLUP1                   ;3  17
            ldy scroll                   ;3  20
            lda #$00                     ;2  22
            sta HMP0                     ;3  23
            sta HMP1                     ;3  26
            ldx #$00                     ;3  32
            lda laser_lo_hmov            ;3  35
            sta HMM0                     ;3  38
            lda laser_hmov,x             ;4  42
            sta HMM1                     ;3  45
            jmp playfield_loop_0         ;3  48

    ORG $F300
playfield_loop_0
            sta WSYNC                    ;3   0
            lda P0_WALLS,y               ;4   4
            sbne _skip_0                 ;2   6
            sta HMOVE                    ;3   9
            inx                          ;2  11
            sta PF0                      ;3  14
            lda P1_WALLS,y               ;4  18
            sta PF1                      ;3  21
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            lda P2_WALLS,y               ;4  32
            sta PF2                      ;3  35
            lda laser_hmov,x             ;4  39
            sta HMM1                     ;3  42
            jmp _shim_0                  ;3  45
_skip_0
            SLEEP 4                      ;4  11
            sta PF0                      ;3  14
            lda P1_WALLS,y               ;4  18
            sta PF1                      ;3  21
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            lda P2_WALLS,y               ;4  32
            sta PF2                      ;3  35
            SLEEP 10                     ;10 45
_shim_0
            inc ball_voffset             ;5  50
            sbeq playfield_loop_0_to_1   ;2  52
            SLEEP 11                     ;11 63
            lda #$00                     ;2  65
            iny                          ;2  67
            sta COLUBK                   ;3  70
            jmp playfield_loop_0         ;3  73

playfield_loop_0_to_1
            ldx #BALL_HEIGHT - 1         ;2  55
            SLEEP 5                      ;5  60
            jmp playfield_loop_1_e       ;3  63 

playfield_loop_1_hm
            sta WSYNC                    ;3   0
            lda P0_WALLS,y               ;4   4
            sta PF0                      ;3   7
            lda P1_WALLS,y               ;4  11
            sta PF1                      ;3  14
            lda P2_WALLS,y               ;4  18
            sta PF2                      ;3  21            
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            ; ball update 
            lda BALL_GRAPHICS,x          ;4  32
            sta GRP0                     ;3  35
            sta GRP1                     ;3  38
            sbeq playfield_loop_1_to_2   ;2  40
            dex                          ;2  42
            SLEEP 15                     ;15 57
            ; push any collisions        
            lda CXP0FB                   ;3  60
            pha                          ;3  63
playfield_loop_1_e
            lda #$00                     ;2  65
            iny                          ;2  67
            sta COLUBK                   ;3  70
            jmp playfield_loop_1_hm      ;3  73

playfield_loop_1_to_2
            ; BUGBUG push any more collisions?
            ; bugbug could avoid this calculation by stashing zx
            tya                          ;2  43
            sec                          ;3  46
            sbc scroll                   ;3  49
            lsr                          ;2  51
            lsr                          ;2  51
            tax                          ;2  53
            lda laser_hmov,x             ;4  57
            sta HMM0                     ;3  60
            lda #$00                     ;2  62
            iny                          ;2  64
            sta COLUBK                   ;3  67
            ; fall through to next loop

playfield_loop_2_hm
            sta WSYNC                    ;3   0
            lda P0_WALLS,y               ;4   4
            sbne _skip_2                 ;2   6
            sta HMOVE                    ;3   9
            inx                          ;2  11
            sta PF0                      ;3  14
            lda P1_WALLS,y               ;4  18
            sta PF1                      ;3  21
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            lda P2_WALLS,y               ;4  32
            sta PF2                      ;3  35
            lda laser_hmov,x             ;4  39
            sta HMM0                     ;3  42
            jmp _shim_2                  ;3  45
_skip_2
            SLEEP 4                      ;4  11
            sta PF0                      ;3  14
            lda P1_WALLS,y               ;4  18
            sta PF1                      ;3  21
            lda PLAYFIELD_COLORS,y       ;4  25
            sta COLUBK                   ;3  28
            lda P2_WALLS,y               ;4  32
            sta PF2                      ;3  35
            SLEEP 10                     ;10 45
_shim_2
            SLEEP 15                     ;15 60 
playfield_loop_2_e
            lda #$00                     ;2  62
            iny                          ;2  64 
            cpy display_playfield_limit  ;3  67
            sta COLUBK                   ;3  70
            sbcc playfield_loop_2_hm     ;2  72 / 73

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
            ldx temp_stack               ;3   --
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

    ; standard lookup for hmoves
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
    byte #$00,#$18,#$3c,#$5e,#$7e,#$ff,#$ff,#$ff,#$ff,#$7e,#$7e,#$3c,#$18
BALL_GRAPHICS_END
SPLASH_0_GRAPHICS
    byte $ff ; loading...   message incoming... (scratching)
SPLASH_1_GRAPHICS
    byte $ef ; Presenting... (chorus rising)
SPLASH_2_GRAPHICS
    byte $df ; REFHRAKTOR / (deep note 3/31 .. scrolling) 
SPLASH_GRAPHICS
    byte $00 ; -- to menu - ReFhRaKtOr - players - controls - menu

    ORG $FFFA

    .word reset          ; NMI
    .word reset          ; RESET
    .word reset          ; IRQ

    END