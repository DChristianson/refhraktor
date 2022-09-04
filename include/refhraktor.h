    MAC SET_JX_CALLBACKS ; given down + move callbacks
            lda #>{1}
            sta jx_on_press_down + 1
            lda #<{1}
            sta jx_on_press_down
            lda #>{2}
            sta jx_on_move + 1
            lda #<{2}
            sta jx_on_move
    ENDM

    MAC SET_TX_CALLBACK ; given timer callback + time
            lda #{2}
            sta game_timer
            lda #>{1}
            sta tx_on_timer + 1
            lda #<{1}
            sta tx_on_timer
    ENDM

    MAC FORMATION ; given p0, p1, p2, c, mask addr
._pl0_loop_0_hm
            lda ({1}),y                  ;5   5
            sta PF0                      ;3   8
            lda ({2}),y                  ;5  13
            sta PF1                      ;3  16 
            ldx {4},y                    ;4  20
            ;; p2 ahead
            lda ({3}),y                  ;5  25
            ;; adjust playfield color
            stx COLUBK                   ;3  28
            sta PF2                      ;3  31
            ;; set beam hmov          
            lda laser_hmov_0,y           ;4  35
            sta HMM0                     ;3  38
            SLEEP 7                      ;7  45
            ; lda laser_hmov_1,y           ;4  42
            ; sta HMM1                     ;3  45
            ;; ball graphics
            ldx ball_voffset             ;3  48
            cpx #$00                     ;2  50
            bpl ._pl0_draw_grp_0         ;2  52  ; sbpl
            lda #$00                     ;2  54
            jmp ._pl0_end_grp_0          ;3  57
._pl0_draw_grp_0
            lda BALL_GRAPHICS,x          ;4  57
._pl0_end_grp_0
            sta GRP0                     ;3  60
            sta GRP1                     ;3  63 
            SLEEP 3                      ;3  66
            ;; EOL
            lda #$00                     ;2  68
            sta COLUBK                   ;3  71 
            sta WSYNC                    ;3  --
            ;; 2nd line
            sta HMOVE                    ;3   3
            ;; 
            lda local_pf_beam_index      ;3   6
            clc                          ;2   8
            adc #$01                     ;2  10
            and #$0f                     ;2  12
            sta local_pf_beam_index      ;3  15
            lda {4},y                    ;4  19
            iny                          ;2  21 ; getting ready for later
            SLEEP 4                      ;4  25
            sta COLUBK                   ;3  28
            ;; ball offsets
            cpx #$00                     ;2  30
            bmi ._pl0_inc_ball_offset    ;2  32 ; sbmi
            lda CXP0FB                   ;3  35
            pha                          ;3  38
            dex                          ;2  40
            bmi ._pl0_ball_end           ;2  42 ; sbmi
            SLEEP 3                      ;3  45
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_ball_end
            ldx #128                     ;2  45
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_inc_ball_offset 
            SLEEP 8                      ;8  41
            inx                          ;2  43
            beq ._pl0_ball_start         ;2  45 ; sbeq
            jmp ._pl0_save_ball_offset   ;3  48
._pl0_ball_start 
            ldx #BALL_HEIGHT - 1         ;2  48
._pl0_save_ball_offset
            stx ball_voffset             ;3  51
            dec display_playfield_limit  ;3  54
            bpl ._pl0_continue           ;2  56 ; sbpl
            jmp formation_end            ;3  59
._pl0_continue
            ldx #$00                     ;2  61
            tya                          ;2  63
            and #{5}                     ;2  65
            beq ._pl0_advance_formation  ;2  67 ; sbeq
            stx.w COLUBK                 ;4  71
            ;; EOL
            SLEEP 2                      ;2  73
            jmp ._pl0_loop_0_hm          ;3  --
._pl0_advance_formation
            stx COLUBK                   ;4  71
            tay                          ;2  73
            jmp {6}                      ;3  --
    ENDM