

    MAC  TSY
            tsx              ;2 
            txa              ;2
            tay              ;2
    ENDM

    MAC  TYS
            tya              ;2
            tax              ;2
            txs              ;2
    ENDM

    MAC WRITE_ADDR
            lda #>{2}        ;2
            sta {1} + 1      ;3
            lda #<{2}        ;2
            sta {1}          ;3
    ENDM

    ; write a dl
    MAC WRITE_DL 
            ldx #<({1} + 11) ;2
            txs              ;2
        REPEAT 6 
            lda #>{2}        ;2
            pha              ;3
            lda #<{2}        ;2
            pha              ;3
        REPEND
    ENDM


    MAC WRITE_BUFFER 
VAR SET 0
        REPEAT 16 
            sta {1} + VAR
VAR SET VAR + 1
        REPEND
    ENDM

            ; firing - no beam
wx_clear_beam
            lda #0
            sta ball_ax 
            sta ball_ay
            sta laser_lo_x
            TSY
            WRITE_ADDR formation_pf0_ptr, P0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_DL local_fk_m0_dl, BEAM_OFF_HMOV_0
            TYS
            jmp wx_player_return

            ; firing - "regular" beam-style weapons
wx_auto_aim_beam
            ; calc distance between player and aim point
            jsr sub_calc_beam_aim
            ; interpolate beam
            lda local_player_draw_dy
            cmp #PLAYFIELD_BEAM_RES
            bcs _player_aim_beam_end
            asl local_player_draw_dx
            asl local_player_draw_dy    
_player_aim_beam_end
            ; BUGBUG: TODO get preliminary acceleration values
            ; get beam pattern
            lda #PLAYER_STATE_BEAM_MASK
            and player_state,x
            lsr
            lsr
            tay
            lda TABLE_BEAM_PATTERNS,y
            sta local_player_draw_pattern
            ; draw beam 
            jsr sub_draw_beam_check
            ; sort out beam x placement
            cpx #0
            beq _player_aim_calc_lo
            lda player_x + 1
            sec
            sbc #5
            jmp _player_aim_save_laser_x         
_player_aim_calc_lo
            ; find lo player beam starting point
            ; last local_player_x_travel will have the (signed) x distance covered  
            ; multiply by 5 to get 80 scanline x distance
            lda local_player_draw_x_travel
            asl 
            asl 
            clc
            adc local_player_draw_x_travel
            ldy local_player_draw_hmove 
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
            TSY
            WRITE_ADDR formation_pf0_ptr, P0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_DL local_fk_m0_dl, SC_READ_LASER_HMOV_1
            TYS
            jmp wx_player_return

wx_arc_beam
            ; calc distance between player and aim point
            jsr sub_calc_beam_aim
            lda local_player_draw_dy
            sec 
            sbc #20
            bcs _player_arc_miss
            lda local_player_draw_dx
            ldy #$80  ; BUGBUG: need lo/hi
_player_arc_miss
            lda #0
            ldy #0
_player_arc_save_accel
            sta ball_ax 
            sty ball_ay
            ; base draw pattern
            lda #%10101010
            sta local_player_draw_pattern
            lda #$02
            bit frame
            beq _player_arc_skip_rol_pattern
            rol local_player_draw_pattern
_player_arc_skip_rol_pattern
            ; sweep back and forth
            ; TODO: randomized value
            lda frame
            and #$fe
            asl
            asl
            and #$1f
            sec
            sbc #16
            sta local_player_draw_dx
            lda #16
            sta local_player_draw_dy
            ; clear draw buffer
            lda #0
            WRITE_BUFFER SC_WRITE_LASER_HMOV_0
            WRITE_BUFFER SC_WRITE_LASER_HMOV_2
            ; draw beam
            jsr sub_draw_beam_check
            ; figure out x
            cpx #0
            beq _player_arc_aim_calc_lo
            lda player_x + 1
            sec
            sbc #5
            jmp _player_aim_save_laser_x         
_player_arc_aim_calc_lo
            ; find lo player beam starting point
            ; last local_player_x_travel will have the (signed) x distance covered  
            lda local_player_draw_x_travel
            ldy local_player_draw_hmove 
            bpl _player_arc_aim_refract_no_invert
            eor #$ff
            clc
            adc #$01
_player_arc_aim_refract_no_invert
            adc player_x
            sec
            sbc #$05
            cmp #160 ; compare to screen width
            bcc _player_arc_aim_save_laser_x
            sbc #96
_player_arc_aim_save_laser_x
            sta laser_lo_x
            ; BUGBUG: TODO: make dl
            TSY
            WRITE_ADDR formation_pf0_ptr, P0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_ADDR local_fk_m0_dl + 0, BEAM_OFF_HMOV_0 ; hack
            WRITE_ADDR local_fk_m0_dl + 2, BEAM_OFF_HMOV_0 ; hack
            WRITE_ADDR local_fk_m0_dl + 4, BEAM_OFF_HMOV_0 ; hack
            WRITE_ADDR local_fk_m0_dl + 6, BEAM_OFF_HMOV_0 ; hack
            TYS
            ; pad draw buffer
            lda #>SC_READ_LASER_HMOV_0
            sta local_fk_m0_dl + 11
            sta local_fk_m0_dl + 9
            lda ball_voffset
            and #$0f
            clc
            adc #<SC_READ_LASER_HMOV_0
            sta local_fk_m0_dl + 10
            adc #16
            sta local_fk_m0_dl + 8
            jmp wx_player_return

wx_gamma_beam
            ; BUGBUG: TODO: check collision
            lda #0
            sta ball_ax 
            lda #BEAM_GAMMA_POWER
            sta ball_ay
            lda player_x,x
            sta laser_lo_x
            TSY
            WRITE_ADDR formation_pf0_ptr, P0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_DL local_fk_m0_dl, BEAM_ON_HMOV_0
            TYS
            jmp wx_player_return


            ; expects: 
            ;   ball_voffset
            ;   x -> player #
            ; modifies:
            ;   local_player_draw_dx
            ;   local_player_draw_dy
sub_calc_beam_aim
            lda ball_voffset ; get distance to ball
            cpx #$00
            beq _player_aim_beam_lo
_player_aim_beam_hi
            eor #$ff      ; invert offset to get dy
            clc
            adc #$01
            sta local_player_draw_dy
            lda player_x,x
            sec
            sbc ball_x    ; dx
            sta local_player_draw_dx
            rts
_player_aim_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            sta local_player_draw_dy
            lda ball_x
            sec
            sbc player_x,x ; dx
            sta local_player_draw_dx
            rts

            ; expects: 
            ;   local_player_draw_dx
            ;   local_player_draw_dy
            ;   local_player_draw_pattern
            ; modifies:
            ;   local_player_draw_dx - normalized
            ;   local_player_draw_pattern - rotated
            ;   local_player_draw_D
            ;   local_player_draw_x_travel
            ;   local_player_draw_hmove 
sub_draw_beam_check 
            ; figure out beam path
            ldy local_player_draw_dy
            lda local_player_draw_dx
_player_draw_beam_calc ; on entry, a is dx (signed), y is dy (unsigned)
            bpl _player_draw_beam_left
            eor #$ff
            clc
            adc #$01
            cmp local_player_draw_dy
            bcc _player_draw_skip_normalize_dx_right
            sbc local_player_draw_dy
            cmp #4 ; BUGBUG: shim - checking if this is a miss
            bcc _player_draw_skip_clear_ax_right
            lda #0
            sta ball_ax
            sta ball_ay
_player_draw_skip_clear_ax_right
            tya
_player_draw_skip_normalize_dx_right
            sta local_player_draw_dx 
            lda #$f0
            jmp _player_draw_beam_set_hmov
_player_draw_beam_left
            cmp local_player_draw_dy
            bcc _player_draw_skip_normalize_dx_left
            sbc local_player_draw_dy
            cmp #4 ; BUGBUG: shim - checking if this is a miss
            bcc _player_draw_skip_clear_ax_left
            lda #0
            sta ball_ax
            sta ball_ay
_player_draw_skip_clear_ax_left
            tya
_player_draw_skip_normalize_dx_left
            sta local_player_draw_dx
            lda #$10
_player_draw_beam_set_hmov
            sta local_player_draw_hmove
            asl local_player_draw_dx  ; dx = 2 * dx
            lda #$00
            sta local_player_draw_x_travel
            lda local_player_draw_dx
            sec
            sbc local_player_draw_dy  ; D = 2dx - dy
            asl local_player_draw_dy  ; dy = 2 * dy
            sta local_player_draw_D
            ldy #((PLAYFIELD_BEAM_RES / 2) - 1) ; BUGBUG: HALVING RESOLUTION (for speed)
_player_draw_beam_loop
            lda #$01
            cmp local_player_draw_D
            bpl _player_draw_beam_skip_bump_hmov
            ; need an hmov
            lda local_player_draw_D
            sec
            sbc local_player_draw_dy  ; D = D - 2 * dy
            sta local_player_draw_D
            lda local_player_draw_hmove
            inc local_player_draw_x_travel
_player_draw_beam_skip_bump_hmov
            rol local_player_draw_pattern ; shift pattern
            bcc _player_draw_beam_skip_enam0
            ora #$02
_player_draw_beam_skip_enam0
            sta SC_WRITE_LASER_HMOV_1,y ; cheating that #$01 is in a            
            sta SC_WRITE_LASER_HMOV_1 + PLAYFIELD_BEAM_RES / 2,y ; double          
            lda local_player_draw_D
            clc
            adc local_player_draw_dx  ; D = D + 2 * dx
            sta local_player_draw_D
            dey
            bpl _player_draw_beam_loop
            asl local_player_draw_x_travel; BUGBUG: doubling x travel
            rts

TABLE_BEAM_JUMP
    word #wx_auto_aim_beam
    word #wx_auto_aim_beam
    word #wx_arc_beam
    word #wx_gamma_beam

TABLE_BEAM_PATTERNS
    byte %11111111
    byte %10101010
    ; pattern table not used by other beam types
