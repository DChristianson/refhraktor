
    MAC FORMATION ; given pf1, pf2, pf3, pf4, formation height, jump addr, m0 pattern + hmove, p0
._pl0_loop_0_hm
            ;; ball graphics
            lda ({8}),y                  ;5   5
            sta GRP0                     ;3   8
            adc #$ff                     ;2  10 ; force carry if not zero
            ; load left side of screen
            lda PF0_WALLS,y              ;4  14
            sta PF0                      ;3  17
            lda ({1}),y                  ;5  22
            sta PF1                      ;3  25 
            lax ({2}),y                  ;5  30
            stx PF2                      ;3  33
            ; right side of screen
            lda ({3}),y                  ;5  38 ; PF3
            sta PF0                      ;3  41 ; PF4
            lda ({4}),y                  ;5  46
            sta PF1                      ;3  49
            lda PF2_WALLS,y              ;4  53
            sta PF2                      ;3  56
            lda PF0_WALLS,y              ;4  60
            sta PF0                      ;3  63
            ;; set beam hmov and laser pattern
            lda ({7}),y                  ;5  68
            sta HMM0                     ;3  71
            sta ENAM0                    ;3  74
            ;; 2nd line
            sta HMOVE                    ;3   1
            ; PF1
            lda ({1}),y                  ;5   6
            sta PF1                      ;3   9
            stx PF2                      ;3  12
            ; check collision
            bcc ._pl0_skip_collide       ;2  14
            lda #$80                     ;2  16
            adc CXP0FB                   ;3  19 
            sta CXCLR                    ;3  22
            lda ball_cx                  ;3  25
            ror                          ;2  27
            sta ball_cx                  ;3  30
._pl0_continue
            ; right side of screen
            lda ({3}),y                  ;5  35 ; PF3
            sta PF0                      ;3  38 ; 
            lda ({4}),y                  ;5  43 ; PF4
            sta PF1                      ;3  46
            lda PF2_WALLS,y              ;4  50
            sta PF2                      ;3  53
            dec display_playfield_limit  ;5  58
            bmi ._pl0_end                ;2  60 ; sbpl
            dey                          ;2  62
            bpl ._pl0_advance_formation  ;2  64 ; sbeq
            SLEEP 7                      ;7  71
            ldy #{5}                     ;2  73
            jmp {6}                      ;3  --
._pl0_advance_formation
            SLEEP 8                      ;8  73
            jmp ._pl0_loop_0_hm          ;3  --
._pl0_end
            jmp formation_end            ;3  70
._pl0_skip_collide
            SLEEP 12                     ;12 27
            jmp ._pl0_continue           ;3  30
    ENDM

;-------------------------------
; Begin kernel

    DEF_LBL fhrakas_kernel

;---------------------
; upper score area and P1M1 mask

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

            sta WSYNC
            lda frame               ;3   3
            and #$01                ;2   5
            tax                     ;2   7
            lda player_state,x      ;4  11
            and #$30                ;2  13
            sta NUSIZ0              ;3  16
            ; resp P1
            lda #136
            ldx #1
            jsr sub_respx           ;-   9
            lda #$07                ;2  11 ; . quad player
            sta NUSIZ1              ;3  14 ; .
            ldx #$00                ;2  16 ; black P1
            stx COLUP1              ;3  19 ; . 
            ; check exit
            lda game_state          ;3  21  ; check game type
            and #__GAME_TYPE_MASK   ;2  23  ; .
            stx HMP1                ;3  26 ; .
            stx HMM1                ;3  29 ; .
            stx HMM0                ;3  31
            cmp #GS_GAME_QUEST      ;2  33  ; .
            bne laser_track_hi      ;2  35  ; no upper track for quest
            jmp arena               ;3  38  ; .

;---------------------
; laser track (hi)

laser_track_hi
            lda #$00                ;2  37 ; BUGBUG: testing asymmetric
            sta CTRLPF              ;3  40 ; BUGBUG: need?
            lda player_x + 1
            ldx #0
            jsr sub_respx           ;-   9 ; RESP P0

            ldy #PLAYER_HEIGHT - 1  ;2  11  

_lt_hi_draw_loop_2
            lda (player_sprite+2),y ;5  16/32
            ldx #$e0                ;2  34
            stx PF0                 ;3  35
            ldx #$05                ;2  18/37
            stx PF2                 

            sta WSYNC               ;-----
            sta GRP0                ;3   3
            lda TARGET_COLOR_0,y    ;4   7
            sta COLUP0              ;3  10
            lda TARGET_RAIL_0,y     ;4  14
            sta COLUPF              ;3  17
            lda #$ff                ;2  19
            sta PF1                 ;3  22
            sta PF2                 ;3  25
            dey                     ;2  27
            cpy #PLAYER_HEIGHT - 3  ;2  29
            bne _lt_hi_draw_loop_2  ;2  31


            lda SC_READ_POWER_GRID_COLOR + 1 ;3  37
            sta COLUPF                       ;3  40
            lda (player_sprite+2),y          ;5  45
            ldx TARGET_COLOR_0,y             ;4  49
            lda #$ff                         ;2  51
            sta PF2                          ;3  54
            sta CXCLR                        ;3  57 ; start collision

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
            lda #0                          ;4  52
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
            ldx #0                          ;4  45

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

;---------------------
; arena

arena

            ; scoop M1 Mask HMOVE
            lda #$20
            sta HMM1

            ldx #0
            lda ball_x
            jsr sub_respx
            ; return after hmove + rts
            lda ball_color               ;3  12
            sta COLUP0                   ;3  15
            ; clear collision register
            sta CXCLR                    ;3  18
            ; start prepping playfield 
            lda display_scroll           ;3  21
            eor #$ff                     ;2  23 ; invert as we will count down
            and #$0f                     ;2  25
            tay                          ;2  27
            ; zero out hmoves what need zeros
            lda #$00                     ;2  29
            sta HMP0                     ;3  31

            ; hmove ++ and prep for playfield next line
            sta WSYNC                    ;0   0
            lda #80                      ;2   2
            sta display_playfield_limit  ;3   5
            lda #$04                     ;2   7 : BUGBUG: testing reflect
            sta CTRLPF                   ;3  10
            lda #$ff                     ;2  12 activate missile mask
            sta GRP1                     ;3  15 .
            lda #$00                     ;2  17 .
            sta HMM1                     ;3  20 . clear hmove
            jmp formation_0              ;3  23

    ; try to avoid page branching problems
    ALIGN 256

formation_0
    sta WSYNC
    FORMATION formation_pf1_dl + 0, formation_pf2_dl + 0, formation_pf3_dl + 0, formation_pf4_dl + 0, #$0f, formation_1_jmp, local_fk_m0_dl + 0, local_fk_p0_dl + 0
formation_1
    sta WSYNC
formation_1_jmp
    FORMATION formation_pf1_dl + 2, formation_pf2_dl + 2, formation_pf3_dl + 2, formation_pf4_dl + 2, #$0f, formation_2_jmp, local_fk_m0_dl + 2, local_fk_p0_dl + 2
formation_2
    sta WSYNC
formation_2_jmp
    FORMATION formation_pf1_dl + 4, formation_pf2_dl + 4, formation_pf3_dl + 4, formation_pf4_dl + 4, #$0f, formation_3_jmp, local_fk_m0_dl + 4, local_fk_p0_dl + 4

    ; try to avoid page branching problems
    ALIGN 256

formation_3
    sta WSYNC
formation_3_jmp
    FORMATION formation_pf1_dl + 6, formation_pf2_dl + 6, formation_pf3_dl + 6, formation_pf4_dl + 6, #$0f, formation_4_jmp, local_fk_m0_dl + 6, local_fk_p0_dl + 6
formation_4
    sta WSYNC
formation_4_jmp
    FORMATION formation_pf1_dl + 8, formation_pf2_dl + 8, formation_pf3_dl + 8, formation_pf4_dl + 8, #$0f, formation_5_jmp, local_fk_m0_dl + 8, local_fk_p0_dl + 8
formation_5
    sta WSYNC
formation_5_jmp
    FORMATION formation_pf1_dl + 10, formation_pf2_dl + 10, formation_pf3_dl + 10, formation_pf4_dl + 10, #$0f, formation_end_jmp, local_fk_m0_dl + 10, local_fk_p0_dl + 10
formation_end
            SLEEP 6                         ;6  66
            lda #$00                        ;2  68
            sta COLUBK                      ;3  71
            sta WSYNC                       ;3   0
formation_end_jmp

;---------------------
; laser track (lo)


laser_track_lo
            lda #$c0                        ;2   2
            sta PF0                         ;3   5
            lda player_x
            ldx #0
            jsr sub_respx           ;-   9 ; RESP P0


            ldy #1                  ;2  11
            lda (player_sprite),y   ;6  17
            sta GRP0                ;3  20
            lda TARGET_COLOR_0,y    ;4  24
            sta COLUP0              ;3  28
            lda #0                  ;2  30
            sta PF1                 ;3  23
            sta PF2                 ;3  26
            sty CTRLPF              ;2  28 ; CODE: take advantage of y = 1
            iny                     ;2  35

            ; BUGBUG: right place to end missile mask?
            lda #$00                     ;2  20 activate missile mask
            sta ENAM1                    ;3  23 .
            sta GRP1                     ;3  26 .


_lt_lo_draw_loop_0
            sta WSYNC
            lda TARGET_BG_0,y
            sta COLUPF              ;3  28
            lda (player_sprite),y   ;6  11
            sta GRP0                ;3  14
            lda TARGET_COLOR_0,y    ;4  20
            sta COLUP0              ;3  23
            ; BUGBUG pattern
            lda #$ff                ;2  21 ; BUGBUG: magic number
            sta PF1                 ;3  26
            lda #$ff                ;2  28 ; BUGBUG: magic number
            sta PF2                 ;3  31
            iny                     ;2  33
            cpy #4                  ;2  35 ; BUGBUG: magic number
            bcc _lt_lo_draw_loop_0

            lda (player_sprite),y   ;5   5
            sta WSYNC               ;-----
            sta GRP0                ;3   3
            lda TARGET_COLOR_0,y    ;4   7
            sta COLUP0              ;3  10
            lda #$00                ;2  12
            sta PF0                 ;3  15
            lda TARGET_BG_0,y       ;4  19
            sta COLUPF              ;3  22
            lda #$24                ;2  24 ; BUGBUG: magic number
            sta PF1                 ;3  27
            lda #$49                ;2  29 ; BUGBUG: magic number
            sta PF2                 ;3  32
            lda #$20                ;2  34
            sta PF0                 ;3  37
            lda #$92                ;2  39
            sta PF1                 ;3  42
            lda #0                  ;2  44
            sta CTRLPF              ;3  47
            lda #$02                ;2  49 ; BUGBUG: magic number
            sta PF2                 ;3  52
            iny                     ;2  54
            SLEEP 10                ;10 64
            lda #0                  ;2  66
            sta CXCLR               ;3  69


_lt_lo_draw_loop_2
            sta WSYNC
            lda (player_sprite),y           ;5   5
            sta GRP0                        ;3   8
            lda TARGET_COLOR_0,y            ;4  12
            sta COLUP0                      ;3  15
            lda SC_READ_POWER_GRID_PF0      ;4  19
            sta PF0                         ;3  22
            lda SC_READ_POWER_GRID_PF1      ;4  26
            sta PF1                         ;3  29
            lda SC_READ_POWER_GRID_PF2      ;4  33
            sta PF2                         ;3  36
            lda SC_READ_POWER_GRID_PF3      ;4  40
            sta PF0                         ;3  43
            lda SC_READ_POWER_GRID_PF4      ;4  47
            sta PF1                         ;3  50
            lda SC_READ_POWER_GRID_PF5      ;4  54
            sta PF2                         ;3  57
            iny                             ;2  59
            cpy #PLAYER_HEIGHT - 2          ;2  61
            bcc _lt_lo_draw_loop_2          ;2  63

            lda #0                          ;2  65
            sta PF0                         ;3  68
            asl CXP0FB                      ;5  73; save power to carry bit

            SLEEP 3                         ;-- --
            lda (player_sprite),y           ;5   5
            sta GRP0                        ;3   8
            lda TARGET_COLOR_0,y            ;4  12
            sta COLUP0                      ;3  15
            lda #1                          ;2  17
            sta CTRLPF                      ;3  20
            lda #$24                        ;2  22
            sta PF1                         ;3  25
            lda #$49                        ;2  28
            sta PF2                         ;3  32

            ; save power
            lda player_state                ;3
            and #$fe                        ;2
            adc #0                          ;2
            sta player_state                ;3

            iny
            lda (player_sprite),y           ;5   5

            sta WSYNC
            sta GRP0                        ;3   3
            lda TARGET_COLOR_0,y            ;4   7
            sta COLUP0                      ;3  10
            lda TARGET_BG_0,y               ;4  14
            sta COLUPF                      ;3  17
            lda #$c0                        ;2  19
            sta PF0                         ;3  22
            lda #$ff                        ;2  25
            sta PF1                         ;3  28
            sta PF2                         ;3  32
    
            lda game_state               ;3  23  ; check game type
            and #__GAME_TYPE_MASK        ;2  25  ; .
            cmp #GS_GAME_QUEST           ;2  27  ; .
            beq laser_track_coop         ;2  29  ; no upper track for quest
            jmp kernel_exit              ;3  32  ; .            

laser_track_coop
           ; resp lo player
            sta WSYNC               ;3   0
            lda player_x + 1        ;3   3
            sec                     ;2   5
_lt_co_resp_loop
            sbc #15                 ;2   7
            sbcs _lt_co_resp_loop   ;2   9
            tay                     ;2  11+
            lda LOOKUP_STD_HMOVE,y  ;4  15+
            sta HMP0                ;3  18+
            sta HMM0                ;3  21+ ; just for timing shim
            sta RESP0               ;3  24+ ; 

            ; top line
            sta WSYNC
            sta HMOVE               ;3   3
            ldy #$00                ;3   6
            lda (player_sprite+2),y ;6   9
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

_lt_co_draw_loop_0
            lda (player_sprite+2),y ;5  51
            ldx TARGET_COLOR_0,y    ;4  55
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda TARGET_BG_0,y       ;5  11
            sta COLUBK              ;3  14
            iny                     ;2  16
            cpy #3                  ;2  18
            bcc _lt_co_draw_loop_0  ;2  20
            lda (player_sprite+2),y ;5  25
            ldx TARGET_COLOR_0,y    ;4  29
            sta WSYNC
            sta GRP0                ;3   3
            stx COLUP0              ;3   6
            lda #$0b                ;2   8
            sta COLUBK              ;3  11
            iny                     ;2  13

            lda SC_READ_POWER_GRID_COLOR ;3  16
            sta COLUPF                   ;3  19
            lda (player_sprite+2),y      ;5  24
            ldx TARGET_COLOR_0,y         ;4  28
            sta CXCLR                    ;3  31 ; start power collision check

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
            iny                             ;2  34
            lda SC_READ_POWER_GRID_PF3 + 1  ;4  38
            sta PF0                         ;3  41
            lda SC_READ_POWER_GRID_PF4 + 1  ;4  45
            sta PF1                         ;3  48
            lda #0                          ;4  52
            sta PF2                         ;3  55
        
            lda (player_sprite+2),y         ;5  -- 
            ldx TARGET_COLOR_0,y            ;4  --
            sta WSYNC
            sta GRP0                        ;3   3
            stx COLUP0                      ;3   6
            lda SC_READ_POWER_GRID_PF0 + 1  ;4  10
            sta PF0                         ;3  13
            lda SC_READ_POWER_GRID_PF1 + 1  ;4  17
            sta PF1                         ;3  20
            lda SC_READ_POWER_GRID_PF2 + 1  ;4  24
            sta PF2                         ;3  27
            iny                             ;2  29

            lda SC_READ_POWER_GRID_PF3 + 1  ;4  33
            sta PF0                         ;3  36
            lda SC_READ_POWER_GRID_PF4 + 1  ;4  40
            sta PF1                         ;3  43
            ldx #0                          ;4  47

            ; power collision test
            lda player_state + 1            ;3  50
            and #$fe                        ;2  52
            stx PF2                         ;3  55
            bit CXP0FB                      ;3  58
            bpl _co_skip_power              ;2  60
            ora #PLAYER_STATE_HAS_POWER     ;2  62
_co_skip_power
            sta player_state + 1            ;3  64/65


            lda (player_sprite+2),y ;5  --
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
            lda (player_sprite+2),y ;5  46
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

_lt_co_draw_loop_2
            lda (player_sprite+2),y      ;5  56
            ldx TARGET_COLOR_0,y         ;4  60

            sta WSYNC
            sta GRP0                     ;3   3
            stx COLUP0                   ;3   6
            lda TARGET_BG_0,y            ;5  11
            sta COLUBK                   ;3  14
            iny                          ;2  16
            cpy #PLAYER_HEIGHT           ;2  18
            bcc _lt_co_draw_loop_2       ;2  20

; kernel exit
kernel_exit
            sta WSYNC
            lda #$00
            sta PF0
            sta PF1
            sta PF2
            sta GRP0
            sta GRP1
            sta ENAM0
            ;sta ENAM1
            sta COLUBK
            lda #$30
            sta NUSIZ1

            ldx #4
playfield_shim_loop
            sta WSYNC
            dex
            bne playfield_shim_loop

    JMP_LBL return_main_kernel

; generic resp
; a is position, x is object (0 = P0, 1 = P1, ...)
sub_respx
            ; resp P0,x 
            sta WSYNC
            sec                     ;2   2
_ball_resp_loop
            sbc #15                 ;2   4
            sbcs _ball_resp_loop    ;2   6
            tay                     ;2   8
            lda LOOKUP_STD_HMOVE,y  ;4  12
            sta.w HMP0,x            ;5  17
            sta.w RESP0,x           ;5  23
            ; first hmove 
            sta WSYNC                    ;3   0
            sta HMOVE                    ;3   3
            rts

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

	.byte %11000011
	.byte %11000011
	.byte %11000011
	.byte %01000010
	.byte %11000011
	.byte %11000011
	.byte %11000011
	.byte %10000001
	.byte %11000011
	.byte %11000011
	.byte %11000011
	.byte %01000010
	.byte %11000011
	.byte %11000011
	.byte %11000011
	.byte %10000001

PF2_WALLS
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000010
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000001
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000010
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000001

PF1_GOAL_BOTTOM
PF4_GOAL_BOTTOM
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000


PF1_GOAL_TOP
PF4_GOAL_TOP
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111
	.byte %11111111


PF2_GOAL_TOP
PF2_GOAL_BOTTOM   
PF3_GOAL_TOP
PF3_GOAL_BOTTOM   
PFX_WALLS_BLANK
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00
    byte #$00,#$00,#$00,#$00,#$00,#$00,#$00,#$00


    include "_chute.asm"
    include "_ladder.asm"
    include "_pachinko.asm"
    include "_diamonds.asm"
    include "_breakout.asm"

    ALIGN 256
    ; SHIELD LO animation (uses one whole page...) BUGBUG: can compress

SHIELD_ANIM_0_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $2,$0,$e2,$f0,$32,$20,$20,$20,$20,$c2,$f2,$f0,$f0,$f0,$0,$0; 16
SHIELD_ANIM_1_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $2,$12,$10,$c2,$d0,$12,$10,$10,$10,$10,$0,$2,$0,$0,$0,$0; 16
SHIELD_ANIM_2_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $2,$0,$22,$10,$d2,$e0,$e0,$e0,$e0,$42,$12,$10,$10,$10,$0,$0; 16
SHIELD_ANIM_3_CTRL_LO
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $2,$f2,$f0,$42,$30,$f2,$f0,$f0,$f0,$f0,$2,$0,$0,$0,$0,$0; 16
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    ALIGN 256
    ; SHIELD HI animation (uses one whole page...) BUGBUG: can compress

SHIELD_ANIM_0_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $10,$10,$10,$10,$0,$42,$d2,$e0,$e0,$e0,$e0,$22,$10,$2,$0,$2; 16
SHIELD_ANIM_1_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $0,$0,$0,$0,$f2,$f0,$f0,$f0,$f0,$0,$42,$30,$f2,$f0,$2,$2; 16
SHIELD_ANIM_2_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $f0,$f0,$f0,$f0,$0,$c2,$32,$20,$20,$20,$20,$e2,$f0,$2,$0,$2; 16
SHIELD_ANIM_3_CTRL_HI
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    byte $0,$0,$0,$0,$0,$12,$10,$10,$10,$10,$c2,$d0,$12,$10,$2,$2; 16
    byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

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
    byte $00,$00,$00,$00,$00,$00,$00,$00
    byte $00,$00,$00,$00,$00,$00,$00,$00

COLUPF_COLORS_0
    byte $a6,$a6,$a8,$a8,$aa,$aa,$ac,$ac
    byte $ad,$ad,$ac,$ac,$aa,$aa,$a8,$a8

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
TARGET_RAIL_0
TARGET_BG_0
    byte $0,$02,$04,$0b,$bc,$bc,$0b,$04,$02,$00; 9


