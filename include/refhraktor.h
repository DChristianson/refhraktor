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

    MAC GRID_TREATMENT_0
           ; roll in from sides
            ;         5 <B   23> 27<2B  43> 47<4B 53>57<5B 73 77<7B
            ;  | 4..7 | 7......0 | 0......7 | 4..7 | 7......0 | 0......7 |
            lda player_x,x
            lsr
            lsr
            lsr
            lsr
            tay ; y is approx player location
            sec
            sbc #$0a
            pha
            lda player_state,x
            and #PLAYER_STATE_FIRING
            clc
            eor #PLAYER_STATE_FIRING
            beq _power_grid_skip_power
            lda #$08
            sec
_power_grid_skip_power
            php
            ora power_grid_pf0,x
            rol 
            sta power_grid_pf0,x
            dey
            bmi _power_grid_right
            ror power_grid_pf1,x
            dey
            dey
            bmi _power_grid_right
            rol power_grid_pf2,x
            dey
            dey
            bmi _power_grid_right
            lda #$00
            bcc _power_grid_bridge_power_left
            lda #$08
_power_grid_bridge_power_left
            ora power_grid_pf3,x
            rol 
            sta power_grid_pf3,x
            dey
            bmi _power_grid_right
            ror power_grid_pf4,x
_power_grid_right
            plp
            pla
            tay
            ror power_grid_pf5,x
            iny
            iny
            bpl _power_grid_next
            rol power_grid_pf4,x
            iny
            iny
            bpl _power_grid_next
            lda power_grid_pf3,x
            and #$f0 ; BUGBUG could add power here
            ror
            sta power_grid_pf3,x
            iny 
            bpl _power_grid_next
            and #$08
            beq _power_grid_bridge_power_right
            sec
_power_grid_bridge_power_right
            ror power_grid_pf2,x
            iny
            iny
            bpl _power_grid_next
            ror power_grid_pf1,x
_power_grid_next

    ENDM


    MAC GRID_TREATMENT_1
           ; roll in from sides
            ;         5 <B   23> 27<2B  43> 47<4B 53>57<5B 73 77<7B
            ;  | 4..7 | 7......0 | 0......7 | 4..7 | 7......0 | 0......7 |
            lda #$ff
            sta power_grid_pf0,x
            sta power_grid_pf1,x
            sta power_grid_pf2,x
            sta power_grid_pf3,x
            sta power_grid_pf4,x
            sta power_grid_pf5,x
            lda player_x,x
            clc
            adc #$0a
            lsr
            lsr
            lsr
            lsr
            tay ; y is approx player location
            bne _power_grid_pf1_lo
            lda #$00
            sta power_grid_pf0,x
            jmp _power_grid_next
_power_grid_pf1_lo
            dey
            bne _power_grid_pf1_hi
            lda #$0f
            sta power_grid_pf1,x
            jmp _power_grid_next
_power_grid_pf1_hi            
            dey 
            bne _power_grid_pf2_lo
            lda #$f0
            sta power_grid_pf1,x
            jmp _power_grid_next
_power_grid_pf2_lo
            dey 
            bne _power_grid_pf2_hi
            lda #$f0
            sta power_grid_pf2,x
            jmp _power_grid_next
_power_grid_pf2_hi
            dey 
            bne _power_grid_pf3_hi
            lda #$0f
            sta power_grid_pf2,x
            jmp _power_grid_next
_power_grid_pf3_hi
            dey 
            bne _power_grid_pf4_lo
            lda #$00
            sta power_grid_pf3,x
            jmp _power_grid_next
_power_grid_pf4_lo
            dey 
            bne _power_grid_pf4_hi
            lda #$0f
            sta power_grid_pf4,x
            jmp _power_grid_next
_power_grid_pf4_hi
            dey 
            bne _power_grid_pf5_lo
            lda #$f0
            sta power_grid_pf4,x
            jmp _power_grid_next
_power_grid_pf5_lo
            dey 
            bne _power_grid_pf5_hi
            lda #$f0
            sta power_grid_pf5,x
            jmp _power_grid_next
_power_grid_pf5_hi
            lda #$0f
            sta power_grid_pf5,x
_power_grid_next

    ENDM


            
