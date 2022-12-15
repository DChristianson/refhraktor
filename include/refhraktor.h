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
          ; TREATMENT 0: symmetric flow towards player
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
            sta SC_WRITE_POWER_GRID_PF0,x
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

            ; TREATMENT 1: just track under player to figure out where player is
    MAC GRID_TREATMENT_1
            lda #$ff
            jsr sub_fill_grid
            lda player_x,x
            jsr sub_x2pf
            lda player_x,x
            clc
            adc #$04 ; BUGBUG: using a lot of cycles
            jsr sub_x2pf
            lda player_x,x
            clc
            adc #$08 ; BUGBUG: using a lot of cycles
            jsr sub_x2pf
_power_grid_next

    ENDM
            
        ; TREATMENT 2: (flow) flow in asymmetrically from sides based on power var, converge on player
        
        ; TREATMENT 3: (clean) put in static gaps as power drains, rebuild when empty
   MAC GRID_TREATMENT_3
            lda power_grid_pf5,x
            and #$0f
            bne _power_grip_skip_replenish 
            lda power_grid_pf3,x
            and #$f0
            ora power_grid_pf1,x
            ora power_grid_pf2,x
            ora power_grid_pf4,x
            bne _power_grip_skip_replenish 
            lda #$ff
            jsr sub_fill_grid
_power_grip_skip_replenish
            lda player_state,x
            and #PLAYER_STATE_FIRING
            beq _power_grid_next
_power_grid_drain
            lda player_x,x
            jsr sub_x2pf
            lda player_x,x
            clc
            adc #$04 ; BUGBUG: using a lot of cycles
            jsr sub_x2pf
            lda player_x,x
            clc
            adc #$08 ; BUGBUG: using a lot of cycles
            jsr sub_x2pf
_power_grid_next
    ENDM 
         
        ; TREATMENT 4: (reconnect) draw from adjacent flow as power drains, rebuild in 2d
        
        ; TREATMENT 5: (plaid) no drain, alternating spots of flow
    MAC GRID_TREATMENT_5
        dec power_grid_timer,x
        bpl _power_grid_next
        lda #$10
        sta power_grid_timer,x
        lda power_grid_reserve,x
        clc
        adc #$08
        sta power_grid_reserve,x
        and #$78
        tay
        lda PF0_GRID,y
        sta SC_WRITE_POWER_GRID_PF0,x
        iny
        lda PF0_GRID,y
        sta SC_WRITE_POWER_GRID_PF1,x
        iny
        lda PF0_GRID,y
        sta SC_WRITE_POWER_GRID_PF2,x
        iny
        lda PF0_GRID,y
        sta SC_WRITE_POWER_GRID_PF3,x
        iny
        lda PF0_GRID,y
        sta SC_WRITE_POWER_GRID_PF4,x
        iny
        lda PF0_GRID,y
        sta SC_WRITE_POWER_GRID_PF5,x
_power_grid_next

    ENDM 
        ; TREATMENT 8: (river) no drain, alternating flow left/right/center/away
    MAC GRID_TREATMENT_8
        ; need state + timer + flow
    ENDM 

        ; TREATMENT 6: adjust colors
        ; TREATMENT 7: flicker as power drains
        ; TREATMENT 9: sound designs

