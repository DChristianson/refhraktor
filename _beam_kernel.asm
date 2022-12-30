

    ; invert an address
    MAC  INV8
            lda {1} 
            eor #$ff
            clc
            adc #1
            sta {1}
    ENDM

    ; BUGBUG : probably not needed
    MAC  TSY
            tsx              ;2 
            txa              ;2
            tay              ;2
    ENDM

    ; BUGBUG : probably not needed
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
            WRITE_ADDR formation_pf0_ptr, PF0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_DL local_fk_m0_dl, BEAM_OFF_HMOV_0
            TYS
            jmp wx_player_return

            ; firing - "regular" beam-style weapons
wx_auto_aim_beam
            ; calc distance between player and aim point
            jsr sub_calc_beam_parameters
            ; interpolate beam BUGBUG: needed?
            lda local_beam_draw_dy
            cmp #PLAYFIELD_BEAM_RES
            bcs _player_aim_beam_end
            asl local_beam_draw_dx
            asl local_beam_draw_dy    
_player_aim_beam_end
            lda local_beam_draw_cx
            cmp #4
            bmi _player_aim_calc_acceleration
            lda #0
            jmp _player_aim_save_ay
_player_aim_calc_acceleration
            ; get ball ay
            lda local_beam_draw_dy
            lsr
            lsr
            lsr
            lsr
            tay
            lda TABLE_BEAM_POWER,y
_player_aim_save_ay
            sta ball_ay
            beq _player_aim_save_ax
            ; get ball ax
            lda local_beam_draw_dx
            lsr
            beq _player_aim_save_ax
            lsr
            lsr
            tay
            lda TABLE_BEAM_SPIN,y
            bit local_beam_draw_hmove
            bpl _player_aim_save_ax
            eor #$ff
            clc
            adc #1
_player_aim_save_ax
            sta ball_ax
            ; get beam pattern
            lda #PLAYER_STATE_BEAM_MASK
            and player_state,x
            lsr
            lsr
            tay
            lda TABLE_BEAM_PATTERNS,y
            sta local_beam_draw_pattern
            ; draw beam 
            jsr sub_draw_beam
            ; sort out beam x placement
            cpx #0
            beq _player_aim_calc_lo
            ; invert x acceleration
            INV8 ball_ax
            lda player_x + 1
            sec
            sbc #5
            jmp _player_aim_save_laser_x         
_player_aim_calc_lo
            ; invert y acceleration
            INV8 ball_ay
            ; find lo player beam starting point
            ; last local_beam_x_travel will have the (unsigned) x distance covered  
            ; multiply by 5 to get 80 scanline x distance
            lda local_beam_draw_x_travel
            asl 
            asl 
            clc
            adc local_beam_draw_x_travel
            ldy local_beam_draw_hmove 
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
            WRITE_ADDR formation_pf0_ptr, PF0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_DL local_fk_m0_dl, SC_READ_LASER_HMOV_1
            TYS
            jmp wx_player_return

wx_arc_beam
            ; calc distance between player and aim point
            jsr sub_calc_beam_parameters
            lda local_beam_draw_dy
            sec 
            sbc #16 ; BUGBUG: variablize
            bcs _player_arc_miss
            lda local_beam_draw_cx
            cmp #2
            bpl _player_arc_miss
            lda ball_x ; 
            sec
            sbc player_x,x
            ldy TABLE_BEAM_ARC_POWER,x
            jmp _player_arc_save_accel
_player_arc_miss
            lda #0
            ldy #0
_player_arc_save_accel
            sta ball_ax 
            sty ball_ay
            ; figure out x
            lda player_x,x
            sec
            sbc #8
            sta laser_lo_x
            ; BUGBUG: TODO: make dl
            WRITE_ADDR formation_pf0_ptr, PF0_WALLS
            WRITE_ADDR local_fk_m0_dl + 4, SHIELD_ANIM_0_CTRL_LO ; hack
            WRITE_ADDR local_fk_m0_dl + 6, SHIELD_ANIM_0_CTRL_LO ; hack
            ; sweep back and forth
            lda frame 
            and #$06
            asl
            asl
            asl
            asl
            cpx #0 ; BUGBUG has been wiped
            beq _player_arc_skip_shim_hi
            clc
            adc #<SHIELD_ANIM_0_CTRL_HI
            sta local_fk_m0_dl + 2
            ; pad draw buffer
            lda scroll
            and #$0f
            clc
            adc local_fk_m0_dl + 2
            sta local_fk_m0_dl + 2
            adc #16
            sta local_fk_m0_dl + 0
            lda #>SHIELD_ANIM_0_CTRL_HI
            sta local_fk_m0_dl + 1
            sta local_fk_m0_dl + 3
            WRITE_ADDR local_fk_m0_dl + 8, SHIELD_ANIM_0_CTRL_LO ; hack
            WRITE_ADDR local_fk_m0_dl + 10, SHIELD_ANIM_0_CTRL_LO ; hack
            jmp _player_arc_done
_player_arc_skip_shim_hi
            sta local_fk_m0_dl + 10
            ; pad draw buffer
            lda scroll
            and #$0f
            clc
            adc local_fk_m0_dl + 10
            sta local_fk_m0_dl + 10
            adc #16
            sta local_fk_m0_dl + 8
            lda #>SHIELD_ANIM_0_CTRL_LO
            sta local_fk_m0_dl + 9
            sta local_fk_m0_dl + 11
            WRITE_ADDR local_fk_m0_dl + 0, SHIELD_ANIM_0_CTRL_LO ; hack
            WRITE_ADDR local_fk_m0_dl + 2, SHIELD_ANIM_0_CTRL_LO ; hack
_player_arc_done
            ; BUGBUG: TODO: make dl
            TSY
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            TYS
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
            WRITE_ADDR formation_pf0_ptr, PF0_WALLS
            WRITE_DL local_fk_colupf_dl, COLUPF_COLORS_0
            WRITE_DL local_fk_colubk_dl, COLUBK_COLORS_1
            WRITE_DL local_fk_m0_dl, BEAM_ON_HMOV_0
            TYS
            jmp wx_player_return


            ; expects: 
            ;   ball_voffset
            ;   x -> player #
            ; modifies:
            ;   local_beam_draw_dx      - normalized to positive
            ;   local_beam_draw_dy      - normalized to positive
            ;   local_beam_draw_pattern - on/off pattern
            ;   local_beam_draw_hmove   - x direction
sub_calc_beam_parameters
            lda ball_voffset ; get distance to ball
            sec
            sbc #4 ; shim to center
            cpx #0
            beq _player_aim_beam_lo
_player_aim_beam_hi
            eor #$ff      ; invert offset to get dy
            clc
            adc #$01
            sta local_beam_draw_dy
            tay
            lda player_x,x
            sec
            sbc ball_x    ; dx
            jmp _player_draw_beam_calc
_player_aim_beam_lo
            clc           ; add view height to get dy
            adc #PLAYFIELD_VIEWPORT_HEIGHT
            sta local_beam_draw_dy
            tay
            lda ball_x
            sec
            sbc player_x,x ; dx
_player_draw_beam_calc ; on entry, a is dx (signed), y is dy (unsigned)
            bpl _player_draw_beam_left
            eor #$ff
            clc
            adc #$01
            sta local_beam_draw_dx 
            sec
            sbc local_beam_draw_dy
            sta local_beam_draw_cx
            bcc _player_draw_skip_normalize_dx_right
            sty local_beam_draw_dx
_player_draw_skip_normalize_dx_right
            lda #$f0
            jmp _player_draw_beam_set_hmov
_player_draw_beam_left
            sta local_beam_draw_dx 
            sec
            sbc local_beam_draw_dy
            sta local_beam_draw_cx
            bcc _player_draw_skip_normalize_dx_left
            sbc local_beam_draw_dy
            sty local_beam_draw_dx
_player_draw_skip_normalize_dx_left
            lda #$10
_player_draw_beam_set_hmov
            sta local_beam_draw_hmove
            rts

            ; Bresenham line drawing
            ; expects: 
            ;   local_beam_draw_dx      - normalized to positive
            ;   local_beam_draw_dy      - normalized to positive
            ;   local_beam_draw_pattern - on/off pattern
            ;   local_beam_draw_hmove   - x direction
            ; modifies:
            ;   local_beam_draw_dx - used for scratch
            ;   local_beam_draw_pattern - rotated
            ;   local_beam_draw_D - 
            ;   local_beam_draw_x_travel - hmove distance
sub_draw_beam
            asl local_beam_draw_dx  ; dx = 2 * dx
            lda #$00
            sta local_beam_draw_x_travel
            lda local_beam_draw_dx
            sec
            sbc local_beam_draw_dy  ; D = 2dx - dy
            asl local_beam_draw_dy  ; dy = 2 * dy
            sta local_beam_draw_D
            ldy #((PLAYFIELD_BEAM_RES / 2) - 1) ; BUGBUG: HALVING RESOLUTION (for speed)
_player_draw_beam_loop
            lda #$01
            cmp local_beam_draw_D
            bpl _player_draw_beam_skip_bump_hmov
            ; need an hmov
            lda local_beam_draw_D
            sec
            sbc local_beam_draw_dy  ; D = D - 2 * dy
            sta local_beam_draw_D
            lda local_beam_draw_hmove
            inc local_beam_draw_x_travel
_player_draw_beam_skip_bump_hmov
            rol local_beam_draw_pattern ; shift pattern
            bcc _player_draw_beam_skip_enam0
            ora #$02
_player_draw_beam_skip_enam0
            sta SC_WRITE_LASER_HMOV_1,y ; cheating that #$01 is in a            
            sta SC_WRITE_LASER_HMOV_1 + PLAYFIELD_BEAM_RES / 2,y ; double          
            lda local_beam_draw_D
            clc
            adc local_beam_draw_dx  ; D = D + 2 * dx
            sta local_beam_draw_D
            dey
            bpl _player_draw_beam_loop
            asl local_beam_draw_x_travel; BUGBUG: doubling x travel
            rts

TABLE_BEAM_ARC_POWER
    byte $80
    byte $7f

TABLE_BEAM_JUMP
    word #wx_auto_aim_beam
    word #wx_auto_aim_beam
    word #wx_arc_beam
    word #wx_gamma_beam

TABLE_BEAM_POWER
    byte $40
    byte $20
    byte $10
    byte $10
    byte $08
    byte $08

TABLE_BEAM_SPIN
    ; BUGBUG: super sketch
    byte $08
    byte $08
    byte $10
    byte $10
    byte $10
    byte $20
    byte $20
    byte $20
    byte $40
    byte $40

TABLE_BEAM_PATTERNS
    byte %11111111
    byte %10101010
    ; pattern table not used by other beam types
