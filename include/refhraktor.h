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