
    MAC FORMATION ; given p0, p1, p2, c, w, mask, addr
._pl0_loop_0_hm
            lda ({1}),y                  ;5   5
            sta PF0                      ;3   8
            lda ({2}),y                  ;5  13
            sta PF1                      ;3  16 
            ;; adjust playfield color
            lda ({4}),y                  ;5  21
            ldx laser_hmov_0,y           ;4  25
            sta COLUBK                   ;3  28
            lda ({3}),y                  ;5  33
            sta PF2                      ;3  36
            ;; set beam hmov          
            stx HMM0                     ;3  39
            stx ENAM0                    ;3  42
            ;; ball graphics
            ldx ball_voffset             ;3  45
            bpl ._pl0_draw_grp_0         ;2  47  ; sbpl
            lda #$00                     ;2  49
            jmp ._pl0_end_grp_0          ;3  52
._pl0_draw_grp_0
            lda BALL_GRAPHICS,x          ;4  52
._pl0_end_grp_0
            sta GRP0                     ;3  55
            sta GRP1                     ;3  58 
            lda ({5}),y                  ;5  63 ; load pf color 
            tax                          ;2  65
            ;; EOL
            lda #$00                     ;2  67
            sta.w COLUBK                 ;4  71
            SLEEP 2                      ;2  73 
            stx COLUPF                   ;3  76
            ;; 2nd line
            sta HMOVE                    ;3   3
            ;; 
            lda local_pf_beam_index      ;3   6
            clc                          ;2   8
            adc #$01                     ;2  10
            and #$0f                     ;2  12
            sta local_pf_beam_index      ;3  15
            lda ({4}),y                  ;5  20
            dey                          ;2  22 ; getting ready for later
            SLEEP 3                      ;3  25
            sta COLUBK                   ;3  28
            ;; ball offsets
            ldx ball_voffset             ;3  31
            bmi ._pl0_inc_ball_offset    ;2  33 ; sbmi
            lda CXP0FB                   ;3  36
            pha                          ;3  39
            dex                          ;2  41
            bmi ._pl0_ball_end           ;2  43 ; sbmi
            sta CXCLR                    ;3  46 ; clear collision for next line
            jmp ._pl0_save_ball_offset   ;3  49 
._pl0_ball_end
            ldx #128                     ;2  46
            jmp ._pl0_save_ball_offset   ;3  49
._pl0_inc_ball_offset 
            SLEEP 8                      ;8  42
            inx                          ;2  44
            beq ._pl0_ball_start         ;2  46 ; sbeq
            jmp ._pl0_save_ball_offset   ;3  49
._pl0_ball_start 
            ldx #BALL_HEIGHT - 1         ;2  49
._pl0_save_ball_offset
            stx ball_voffset             ;3  52
            dec display_playfield_limit  ;3  55
            bpl ._pl0_continue           ;2  57 ; sbpl
            jmp formation_end            ;3  60
._pl0_continue
            ldx #$00                     ;2  62
            tya                          ;2  64
            bmi ._pl0_advance_formation  ;2  66 ; sbeq
            SLEEP 2                      ;2  68
            stx COLUBK                   ;3  71
            ;; EOL
            SLEEP 2                      ;2  73
            jmp ._pl0_loop_0_hm          ;3  --
._pl0_advance_formation
            stx.w COLUBK                 ;3  71
            ldy #{6}                     ;2  73
            jmp {7}                      ;3  --
    ENDM

;-------------------------------
; Begin kernel

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
            SLEEP 6                 ;3  24+ ; BUGBUG: line glitch
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
            SLEEP 3                 ;2  21+ ; BUGBUG: shim
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
            sta CTRLPF                   ;3  34
            lda TARGET_BG_0,y            ;5  39
            sta COLUPF                   ;3  42

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
            sta CXCLR               ;3  23 ; start collision
            sta PF1                 ;3  26
            lda power_grid_pf2 + 1  ;3  29
            sta PF2                 ;3  32
            dey                     ;2  34
            lda power_grid_pf3 + 1  ;3  37
            sta PF0                 ;3  40
            lda power_grid_pf4 + 1  ;3  43
            sta PF1                 ;3  46
            lda power_grid_pf5 + 1  ;3  49
            sta PF2                 ;3  52
    
            lda (player_sprite+2),y ;5  57
            ldx TARGET_COLOR_0,y    ;4  61
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda power_grid_pf0 + 1  ;3   9
            sta PF0                 ;3  12
            lda power_grid_pf1 + 1  ;3  15
            sta PF1                 ;3  18
            lda power_grid_pf2 + 1  ;3  21
            sta PF2                 ;3  24

            ; power collision test
            lda player_state + 1    ;3  27
            and #$fe                ;2  29
            bit CXP0FB              ;3  32
            bpl _hi_skip_power      ;2  34
            ora #PLAYER_STATE_HAS_POWER ;2  36
_hi_skip_power
            sta player_state + 1    ;3  38/39

            lda power_grid_pf3 + 1  ;3  41/42
            sta PF0                 ;3  44/45
            lda power_grid_pf4 + 1  ;3  47/48
            sta PF1                 ;3  50/51
            lda power_grid_pf5 + 1  ;3  53/54
            sta PF2                 ;3  56/57
            dey                     ;2  58/59

            lda (player_sprite+2),y ;5  --
            ldx TARGET_COLOR_0,y    ;4  --
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda TARGET_BG_0,y       ;5  14
            sta COLUBK              ;3  17
            sta COLUPF              ;3  20
            lda #$00                ;2  22
            sta PF0                 ;3  25
            sta PF1                 ;3  28
            sta PF2                 ;3  31
            dey                     ;2  33
            lda #$01                ;2  35
            sta CTRLPF              ;3  38

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

            ; activate laser beam width
            lda frame
            and #$01
            tax
            lda player_state,x           ;3   6
            and #$30                     ;2   8
            sta NUSIZ0                   ;3   9

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
            ; BUGBUG: disable ball?
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
            sta CTRLPF              ;3  13
            lda power_grid_pf0      ;3  17
            sta PF0                 ;3  20
            lda power_grid_pf1      ;3  23
            sta PF1                 ;3  26
            sta CXCLR               ;3  29 ; start power collision check
            lda power_grid_pf2      ;3  32
            sta PF2                 ;3  35
            iny                     ;2  38
            lda power_grid_pf3      ;3  41
            sta PF0                 ;3  44
            lda power_grid_pf4      ;3  47
            sta PF1                 ;3  50
            lda power_grid_pf5      ;3  53
            sta PF2                 ;3  56
        
            lda (player_sprite),y   ;5  -- 
            ldx TARGET_COLOR_0,y    ;4  --
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda power_grid_pf0      ;3   9
            sta PF0                 ;3  12
            lda power_grid_pf1      ;3  15
            sta PF1                 ;3  18
            lda power_grid_pf2      ;3  21
            sta PF2                 ;3  24
            iny                     ;2  26

            ; power collision test
            lda player_state        ;3  29
            and #$fe                ;2  31
            bit CXP0FB              ;3  34
            bpl _lo_skip_power      ;2  36
            ora #PLAYER_STATE_HAS_POWER ;2  38
_lo_skip_power
            sta player_state        ;3  40/41

            lda power_grid_pf3      ;3  43/44
            sta PF0                 ;3  46/47
            lda power_grid_pf4      ;3  49/50
            sta PF1                 ;3  52/53
            lda power_grid_pf5      ;3  55/56
            sta PF2                 ;3  58/59

            lda (player_sprite),y   ;5  --
            ldx TARGET_COLOR_0,y    ;4  --
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$0a                ;2   8
            sta COLUPF              ;3  11
            lda #$ff                ;2  13
            sta PF0                 ;3  16
            sta PF1                 ;3  19
            sta PF2                 ;3  22
            iny                     ;2  24
            lda #$01                ;2  26
            sta CTRLPF              ;3  29
    
            lda TARGET_BG_0,y       ;5  34
            sta COLUBK              ;3  37
            lda (player_sprite),y   ;5  42
            ldx TARGET_COLOR_0,y    ;4  46
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
            ldx #PLAYER_HEIGHT - 1
            ldy #1
_equip_p1_draw_loop
            sta WSYNC
            lda #P1_GRAPHICS_0,x
            sta GRP0
            lda (player_sprite),y
            sta GRP1
            iny
            dex
            bpl _equip_p1_draw_loop 
            ldx #PLAYER_HEIGHT - 1
            ldy #1
_equip_p2_draw_loop
            sta WSYNC
            lda #P2_GRAPHICS_0,x
            sta GRP0
            lda (player_sprite + 2),y
            sta GRP1
            iny
            dex
            bpl _equip_p2_draw_loop
            lda #0
            sta GRP0 
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
    
P1_WALLS_WINGS_TOP
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00010000
	.byte %00100000
	.byte %01000000
	.byte %00100000
	.byte %01000000
	.byte %00100000
	.byte %01000000
	.byte %00100000
	.byte %00010000
	.byte %00100000
	.byte %00010000
	.byte %00001000
    .byte %00010000

P1_WALLS_WINGS_BOTTOM
	.byte %00001000
	.byte %00000100
	.byte %00001000
	.byte %00000100
	.byte %00001000
	.byte %00000100
	.byte %00001000
	.byte %00010000
	.byte %00001000
	.byte %00010000
	.byte %00100000
	.byte %00010000
	.byte %00100000
	.byte %01000000
	.byte %00000000
	.byte %00000000


P2_WALLS_WINGS_TOP
	.byte %00000010
	.byte %00000100
	.byte %00001010
	.byte %00000100
	.byte %00001010
	.byte %00010100
	.byte %00001010
	.byte %00010100
	.byte %00001000
	.byte %00010100
	.byte %00101000
	.byte %00010000
	.byte %00101000
	.byte %01010000
	.byte %10100000
	.byte %01010000

P2_WALLS_WINGS_BOTTOM
	.byte %10100000
	.byte %01000000
	.byte %10100000
	.byte %01000000
	.byte %10000000
	.byte %01000000
	.byte %10000000
	.byte %01000000
	.byte %10100000
	.byte %01000000
	.byte %10100000
	.byte %01010000
	.byte %00100000
	.byte %00010000
	.byte %00001000
	.byte %00000000


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
    byte $0,$81,$e7,$ff,$42,$e7,$3d,$80,$2a; 9
MTP_MX888_1
    byte $0,$81,$e7,$ff,$42,$e7,$bc,$1,$54; 9
MTP_MX888_2
    byte $0,$81,$e7,$ff,$42,$e7,$3d,$80,$2a; 9
MTP_MX888_3
    byte $0,$81,$e7,$ff,$42,$e7,$bc,$1,$54; 9
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