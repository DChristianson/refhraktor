
    MAC FORMATION ; given p0, p1, p2, c, w, mask, addr, m0, p0
._pl0_loop_0_hm
            lda ({1}),y                  ;5   5
            sta PF0                      ;3   8
            lda ({2}),y                  ;5  13
            sta PF1                      ;3  16 
            ;; adjust playfield color
            lda ({4}),y                  ;5  21
            SLEEP 4                      ;4  25
            sta COLUBK                   ;3  28
            lda ({3}),y                  ;5  33
            sta PF2                      ;3  36
            ;; set beam hmov
            lda ({8}),y                  ;5  41
            sta HMM0                     ;3  44
            sta ENAM0                    ;3  47
            ;; ball graphics
            lda ({9}),y                  ;5  52
            sta GRP0                     ;3  55
            sta GRP1                     ;3  58
            ldx #0                       ;2  60
            SLEEP 3                      ;3  63
            lda ({5}),y                  ;5  68 ; load pf color 
            ;; EOL
            stx COLUBK                   ;4  71
            SLEEP 2                      ;2  73
            sta COLUPF                   ;3  76
            ;; 2nd line
            sta HMOVE                    ;3   3
            ;; get C set for checking collision
            lda #$80                     ;2   5
            adc CXP0FB                   ;3   8
            sta CXCLR                    ;3  11
            SLEEP 4                      ;4  15
            lda ({4}),y                  ;5  20
            dey                          ;2  22 ; getting ready for later
            ldx ball_voffset             ;3  25
            sta COLUBK                   ;3  28
            ;; ball offsets
            bmi ._pl0_inc_ball_offset    ;2  30 ; sbmi
            lda ball_cx                  ;3  33
            ror                          ;2  35
            sta ball_cx                  ;3  38
            dex                          ;2  40
            bmi ._pl0_ball_end           ;2  42 ; sbmi
            SLEEP 3                      ;3  45
            jmp ._pl0_save_ball_offset   ;3  48 
._pl0_ball_end
            ldx #128                     ;2  45
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_inc_ball_offset 
            SLEEP 10                     ;10 41
            inx                          ;2  43
            beq ._pl0_ball_start         ;2  45 ; sbeq
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_ball_start 
            ldx #BALL_HEIGHT - 1         ;2  48
._pl0_save_ball_offset
            stx ball_voffset             ;3  51
            dec display_playfield_limit  ;5  56
            bpl ._pl0_continue           ;2  58 ; sbpl
            jmp formation_end            ;3  61
._pl0_continue
            ldx #0                       ;2  61 ; get a 0
            tya                          ;2  63
            bmi ._pl0_advance_formation  ;2  65 ; sbeq
            SLEEP 3                      ;3  68
            stx COLUBK                   ;3  71
            ;; EOL
            SLEEP 2                      ;2  73
            jmp ._pl0_loop_0_hm          ;3  --
._pl0_advance_formation
            SLEEP 2                      ;2  68
            stx COLUBK                   ;3  71
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
            sta RESM0               ;3  27+ ; BUGBUG: GLITCH: goes over

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
            sta RESP0               ;3  24+ ; 

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
            sta GRP0                         ;3   3
            stx COLUP0                       ;3   6
            lda TARGET_BG_0,y                ;5  11
            sta COLUBK                       ;3  14
            dey                              ;2  16
            cpy #PLAYER_HEIGHT - 3           ;2  18
            bcs _lt_hi_draw_loop_2           ;2  20
            lda #$00                         ;2  22
            sta PF0                          ;3  25
            sta PF1                          ;3  28
            sta PF2                          ;3  31
            sta CTRLPF                       ;3  34
            lda SC_READ_POWER_GRID_COLOR + 1 ;3  37
            sta COLUPF                       ;3  40
            lda (player_sprite+2),y          ;5  45
            ldx TARGET_COLOR_0,y             ;4  49
            sta CXCLR                        ;3  52 ; start collision

            sta WSYNC
            sta GRP0                        ;3   3
            stx COLUP0                      ;3   6
            lda #$00                        ;2   8
            sta COLUBK                      ;3  11
            lda SC_READ_POWER_GRID_PF0 + 1  ;4  15
            sta PF0                         ;3  18
            lda SC_READ_POWER_GRID_PF1 + 1  ;4  22
            sta PF1                         ;3  25
            lda SC_READ_POWER_GRID_PF2 + 1  ;4  29
            sta PF2                         ;3  32
            dey                             ;2  34
            lda SC_READ_POWER_GRID_PF3 + 1  ;4  38
            sta PF0                         ;3  41
            lda SC_READ_POWER_GRID_PF4 + 1  ;4  45
            sta PF1                         ;3  48 
            lda SC_READ_POWER_GRID_PF5 + 1  ;4  52
            sta PF2                         ;3  55
    
            lda (player_sprite+2),y         ;5  60
            ldx TARGET_COLOR_0,y            ;4  64
            sta WSYNC
            sta GRP0                        ;3   3
            stx COLUP0                      ;3   6
            lda SC_READ_POWER_GRID_PF0 + 1  ;4  10
            sta PF0                         ;3  13
            lda SC_READ_POWER_GRID_PF1 + 1  ;4  17
            sta PF1                         ;3  20
            lda SC_READ_POWER_GRID_PF2 + 1  ;4  24
            sta PF2                         ;3  27

            lda SC_READ_POWER_GRID_PF3 + 1  ;4  31
            sta PF0                         ;3  34
            lda SC_READ_POWER_GRID_PF4 + 1  ;4  38
            sta PF1                         ;3  41
            ldx SC_READ_POWER_GRID_PF5 + 1  ;4  45

            ; power collision test
            lda player_state + 1            ;3  48
            stx PF2                         ;3  51
            and #$fe                        ;2  53
            bit CXP0FB                      ;3  56
            bpl _hi_skip_power              ;2  58
            ora #PLAYER_STATE_HAS_POWER     ;2  60
_hi_skip_power
            sta player_state + 1            ;3  62/63

            dey                             ;2  64/65
            lda TARGET_BG_0,y               ;5  69/70
            sta WSYNC
            sta COLUBK              ;3   3
            sta COLUPF              ;3   6
            lda (player_sprite+2),y ;5  11
            ldx TARGET_COLOR_0,y    ;4  17
            sta GRP0                ;3  20
            stx COLUP0              ;3  23
            lda #$00                ;2  25
            sta PF0                 ;3  28
            sta PF1                 ;3  31
            sta PF2                 ;3  34
            dey                     ;2  36
            lda #$01                ;2  37
            sta CTRLPF              ;3  40

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

            ; hmove ball, shadow 
            sta WSYNC                    ;3   0
            sta HMOVE                    ;3   3
            lda ball_color               ;3   6
            sta COLUP0                   ;3   9
            ; clear collision register
            sta CXCLR                    ;3  12
            ; start prepping playfield 
            lda display_scroll           ;3  15
            eor #$ff                     ;2  17 ; invert as we will count down
            and #$0f                     ;2  19
            tay                          ;2  21
            ; zero out hmoves what need zeros
            lda #$00                     ;2  23
            sta HMP0                     ;3  26
            lda #$70                     ;2  28 ; shift P1/M0 back 7 clocks
            sta HMP1                     ;3  32

            ; hmove ++ and prep for playfield next line
            sta WSYNC                    ;0   0
            sta HMOVE                    ;3   3
            lda #80                      ;2   5
            sta display_playfield_limit  ;3   8
            lda #$01                     ;2  10
            sta VDELP1                   ;3  13
            lda #$00                     ;2  15 
            sta COLUP1                   ;3  18
            SLEEP 6                      ;6  24
            sta HMP1                     ;3  27
            jmp formation_0              ;3  27

    ; try to avoid page branching problems
    ALIGN 256

formation_0
    sta WSYNC
    FORMATION formation_pf0_ptr, formation_pf1_dl + 0, formation_pf2_dl + 0, local_fk_colubk_dl, local_fk_colupf_dl, #$0f, formation_1_jmp, local_fk_m0_dl + 0, local_fk_p0_dl + 0
formation_1
    sta WSYNC
formation_1_jmp
    FORMATION formation_pf0_ptr, formation_pf1_dl + 2, formation_pf2_dl + 2, local_fk_colubk_dl, local_fk_colupf_dl, #$0f, formation_2_jmp, local_fk_m0_dl + 2, local_fk_p0_dl + 2
formation_2
    sta WSYNC
formation_2_jmp
    FORMATION formation_pf0_ptr, formation_pf1_dl + 4, formation_pf2_dl + 4, local_fk_colubk_dl, local_fk_colupf_dl, #$0f, formation_3_jmp, local_fk_m0_dl + 4, local_fk_p0_dl + 4

    ; try to avoid page branching problems
    ALIGN 256

formation_3
    sta WSYNC
formation_3_jmp
    FORMATION formation_pf0_ptr, formation_pf1_dl + 6, formation_pf2_dl + 6, local_fk_colubk_dl, local_fk_colupf_dl, #$0f, formation_4_jmp, local_fk_m0_dl + 6, local_fk_p0_dl + 6
formation_4
    sta WSYNC
formation_4_jmp
    FORMATION formation_pf0_ptr, formation_pf1_dl + 8, formation_pf2_dl + 8, local_fk_colubk_dl, local_fk_colupf_dl, #$0f, formation_5_jmp, local_fk_m0_dl + 8, local_fk_p0_dl + 8
formation_5
    sta WSYNC
formation_5_jmp
    FORMATION formation_pf0_ptr, formation_pf1_dl + 10, formation_pf2_dl + 10, local_fk_colubk_dl, local_fk_colupf_dl, #$0f, formation_end_jmp, local_fk_m0_dl + 10, local_fk_p0_dl + 10
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
            sta VDELP1                      ;3  30

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
            sta RESP0               ;3  24+ ; 

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
            sta CTRLPF              ;3  44
            iny                     ;2  46

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

            lda SC_READ_POWER_GRID_COLOR ;3  16
            sta COLUPF                   ;3  19
            lda (player_sprite),y        ;5  24
            ldx TARGET_COLOR_0,y         ;4  28
            sta CXCLR                    ;3  31 ; start power collision check

            sta WSYNC
            sta GRP0                        ;3   3
            stx COLUP0                      ;3   6
            lda #$00                        ;2   8
            sta COLUBK                      ;3  11
            lda SC_READ_POWER_GRID_PF0      ;4  15
            sta PF0                         ;3  18
            lda SC_READ_POWER_GRID_PF1      ;4  22
            sta PF1                         ;3  25
            lda SC_READ_POWER_GRID_PF2      ;4  29
            sta PF2                         ;3  32
            iny                             ;2  34
            lda SC_READ_POWER_GRID_PF3      ;4  38
            sta PF0                         ;3  41
            lda SC_READ_POWER_GRID_PF4      ;4  45
            sta PF1                         ;3  48
            lda SC_READ_POWER_GRID_PF5      ;4  52
            sta PF2                         ;3  55
        
            lda (player_sprite),y           ;5  -- 
            ldx TARGET_COLOR_0,y            ;4  --
            sta WSYNC
            sta GRP0                        ;3   3
            stx COLUP0                      ;3   6
            lda SC_READ_POWER_GRID_PF0      ;4  10
            sta PF0                         ;3  13
            lda SC_READ_POWER_GRID_PF1      ;4  17
            sta PF1                         ;3  20
            lda SC_READ_POWER_GRID_PF2      ;4  24
            sta PF2                         ;3  27
            iny                             ;2  29

            lda SC_READ_POWER_GRID_PF3      ;4  33
            sta PF0                         ;3  36
            lda SC_READ_POWER_GRID_PF4      ;4  40
            sta PF1                         ;3  43
            ldx SC_READ_POWER_GRID_PF5      ;4  47

            ; power collision test
            lda player_state                ;3  50
            and #$fe                        ;2  52
            stx PF2                         ;3  55
            bit CXP0FB                      ;3  58
            bpl _lo_skip_power              ;2  60
            ora #PLAYER_STATE_HAS_POWER     ;2  62
_lo_skip_power
            sta player_state                ;3  64/65


            lda (player_sprite),y   ;5  --
            sta WSYNC
            ldx TARGET_COLOR_0,y    ;4   4
            sta GRP0                ;3   7
            stx COLUP0              ;3  10
            lda #$0a                ;2  12
            sta COLUPF              ;3  15
            lda #$ff                ;2  17
            sta PF0                 ;3  20
            sta PF1                 ;3  23
            sta PF2                 ;3  26
            iny                     ;2  28
            lda #$01                ;2  30
            sta CTRLPF              ;3  33
    
            lda TARGET_BG_0,y       ;5  38
            sta COLUBK              ;3  41
            lda (player_sprite),y   ;5  46
            ldx TARGET_COLOR_0,y    ;4  50
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

PF0_WALLS
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

PF2_GOAL_TOP
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$01,#$01
    byte #$03,#$03,#$07,#$07,#$ff,#$ff,#$ff,#$ff

PFX_WALLS_BLANK
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00

PF2_GOAL_BOTTOM   
    byte #$ff,#$ff,#$ff,#$ff,#$07,#$07,#$03,#$03
    byte #$01,#$01,#$00,#$00,#$00,#$00,#$00,#$00


PF1_GOAL_BOTTOM
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f
    byte #$ff,#$ff,#$ff,#$7f,#$01,#$01,#$00,#$00

PF1_GOAL_TOP
    byte #$00,#$00,#$01,#$01,#$7f,#$ff,#$ff,#$ff 
    byte #$ff,#$ff,#$ff,#$7f,#$ff,#$ff,#$ff,#$7f



PF1_WALLS_CHUTE
PF2_WALLS_CHUTE
    byte #$00,#$00,#$00,#$00,#$01,#$01,#$01,#$01
    byte #$00,#$00,#$00,#$00,#$01,#$01,#$01,#$01

PF1_WALLS_DIAMONDS
    byte #$00,#$00,#$00,#$08,#$14,#$14,#$14,#$22
    byte #$22,#$22,#$14,#$14,#$14,#$08,#$00,#$00

PF2_WALLS_CUBES_TOP
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
PF2_WALLS_CUBES_BOTTOM
    byte #$e0,#$e0,#$e0,#$20,#$20,#$e0,#$e0,#$e0
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    
    ALIGN 256
    
PF1_WALLS_WINGS_TOP
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

PF1_WALLS_WINGS_BOTTOM
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


PF2_WALLS_WINGS_TOP
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

PF2_WALLS_WINGS_BOTTOM
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
    ; SHIELD animation (uses one whole page...)

SHIELD_ANIM_0_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $02,$02,$f0,$02,$12,$20,$02,$e2,$c0,$02,$42,$02,$02,$00,$00,$00; 16
SHIELD_ANIM_1_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $02,$02,$02,$e0,$02,$20,$02,$22,$00,$02,$e2,$c2,$c2,$00,$10,$00; 16
SHIELD_ANIM_2_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $02,$02,$00,$02,$e0,$02,$22,$40,$02,$c2,$72,$92,$02,$00,$00,$00; 16
SHIELD_ANIM_3_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $02,$02,$f2,$30,$02,$e0,$02,$e2,$e0,$02,$42,$42,$42,$b0,$d0,$00; 16
SHIELD_ANIM_0_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$00,$00,$02,$00,$02,$c2,$40,$02,$22,$e0,$02,$f2,$10,$02,$02; 16
SHIELD_ANIM_1_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$90,$00,$02,$20,$62,$22,$00,$02,$e2,$e0,$02,$20,$02,$02,$02; 16
SHIELD_ANIM_2_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$00,$00,$02,$20,$52,$92,$42,$c0,$02,$e2,$20,$02,$00,$02,$02; 16
SHIELD_ANIM_3_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$00,$20,$62,$b0,$d2,$c2,$20,$02,$22,$20,$02,$d0,$02,$12,$02; 16

    ALIGN 256

BEAM_OFF_HMOV_0
BALL_GRAPHICS_OFF
COLUBK_COLORS_0 ; compression - 16 0's
    byte $00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$00,$00,$00,$00,$00,$00,$00
BALL_GRAPHICS_PAD
    byte $00,$00,$00,$00,$00,$00,$00,$00
BALL_GRAPHICS
    byte $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c
BALL_GRAPHICS_END
    ; pad 16 0 at end of ball graphics
    byte $00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$00,$00,$00,$00,$00,$00,$00

BEAM_ON_HMOV_0
COLUBK_COLORS_1 ; compression, enam0 always on and 16 bytes of color 2 are the same
    byte $02,$02,$02,$02,$02,$02,$02,$02
    byte $02,$02,$02,$02,$02,$02,$02,$02

COLUPF_COLORS_0
    byte $06,$06,$08,$08,$0a,$0a,$0c,$0c
    byte $0e,$0e,$0c,$0c,$0a,$0a,$08,$08

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
MTP_CPU_0
    byte $0,$18,$18,$0,$c3,$99,$c3,$0,$18; 9
MTP_CPU_1
    byte $0,$18,$18,$0,$c3,$99,$c3,$0,$18; 9
MTP_CPU_2
    byte $0,$18,$18,$0,$c3,$99,$c3,$0,$18; 9
MTP_CPU_3
    byte $0,$18,$18,$0,$c3,$99,$c3,$0,$18; 9
TARGET_COLOR_0
    byte $0,$0a,$0c,$0e,$0e,$0f,$0e,$0e,$0c,$0a; 9
TARGET_BG_0
    byte $0,$00,$00,$0b,$bc,$bc,$0b,$00,$00,$00; 9


