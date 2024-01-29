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


    MAC SET_AX_TRACK; given sound seq
        lda #{1}      
        sta audio_track_{2}
    ENDM

    MAC SET_AX_TRACK_PLAYER; given sound seq
        lda audio_tracker,x
        bne ._skip_track_player
        lda #{1}      
        sta audio_tracker,x
._skip_track_player
    ENDM

    MAC SET_TX_CALLBACK ; given timer callback + time
            lda #{2}
            sta game_timer
            lda #>{1}
            sta tx_on_timer + 1
            lda #<{1}
            sta tx_on_timer
    ENDM

    MAC SWITCH_JX_X; given var, max switch l/r
            ldy {1},x
            lsr
            bcc ._switch_jx_right
            dey
            bpl ._switch_jx_save 
            ldy #({2} - 1)
            jmp ._switch_jx_save
._switch_jx_right
            iny 
            cpy #{2}
            bcc ._switch_jx_save
            ldy #0
._switch_jx_save
            sty {1},x
    ENDM

    MAC SWITCH_JX ; given var, max switch l/r
            ldy {1}
            lsr
            bcc ._switch_jx_right
            dey
            bpl ._switch_jx_save 
            ldy #({2} - 1)
            jmp ._switch_jx_save
._switch_jx_right
            iny 
            cpy #{2}
            bcc ._switch_jx_save
            ldy #0
._switch_jx_save
            sty {1}
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
            
    ; TREATMENT 2: (pull) pull towards player
    MAC GRID_TREATMENT_2
            ; roll in from sides
            ;         5 <B   23> 27<2B  43> 47<4B 53>57<5B 73 77<7B
            ;  | 4..7 | 7......0 | 0......7 | 4..7 | 7......0 | 0......7 |
            ;  | 0      1   2      3   4      5      6   7     8
            ;  
            ; get playfield / 4 position for player 
            lda player_x,x
            lsr
            lsr
            pha ; save pinch bit
            lsr
            lsr
            tay ; y is approx player location
            lda TABLE_PF_COMPLEMENTARY_LOCATION,y
            pha ; save opposing position
            ; PF0 right
            lda SC_READ_POWER_GRID_PF0,x
            rol 
            sta SC_WRITE_POWER_GRID_PF0,x   
            dey
            bmi _grid_continue_left
            ; PF1 right
            lda SC_READ_POWER_GRID_PF1,x
            ror
            sta SC_WRITE_POWER_GRID_PF1,x
            dey 
            dey 
            bpl _grid_continue_left 
            ; PF2 right
            lda SC_READ_POWER_GRID_PF2,x
            rol
            sta SC_WRITE_POWER_GRID_PF2,x
            dey
            dey
            bmi _grid_continue_left
            ; PF3 right
            lda SC_READ_POWER_GRID_PF3,x
            bcc _grid_bridge_pf3_right
            ora #$08
_grid_bridge_pf3_right
            asl
            sta SC_WRITE_POWER_GRID_PF3,x
            dey
            bmi _grid_continue_left
            ; PF4 right
            lda SC_READ_POWER_GRID_PF4,x
            ror
            sta SC_WRITE_POWER_GRID_PF4,x
_grid_continue_left
            pla
            tay
            php ; save carry bit
            ; PF5 left
            bmi _grid_pinch_pf5
            lda SC_READ_POWER_GRID_PF5,x
            ror
            sta SC_WRITE_POWER_GRID_PF5,x
            ; PF4 left
            dey
            dey
            bmi _grid_pinch_pf4
            lda SC_READ_POWER_GRID_PF4,x
            rol
            sta SC_WRITE_POWER_GRID_PF4,x
            ; PF3 left
            dey
            dey
            bmi _grid_pinch_pf3
            lda SC_READ_POWER_GRID_PF3,x
            and #$f0 
            ror
            sta SC_WRITE_POWER_GRID_PF3,x
            and #$08
            beq _grid_bridge_pf3_left
            sec
_grid_bridge_pf3_left
            ; PF2 left
            dey
            dey
            bmi _grid_pinch_pf2
            lda SC_READ_POWER_GRID_PF2,x
            ror
            sta SC_WRITE_POWER_GRID_PF2,x
            ; PF1 left
            dey
            dey
            bmi _grid_pinch_pf1
            lda SC_READ_POWER_GRID_PF1,x
            rol
            sta SC_WRITE_POWER_GRID_PF1,x
            ; PINCH PF0
_grid_pinch_pf0
            plp
            pla
            

_grid_pinch_pf1
_grid_pinch_pf2
_grid_pinch_pf3
_grid_pinch_pf4
_grid_pinch_pf5
_power_grid_skip_power
_power_grid_next

    ENDM


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
         
        ; TREATMENT 4: (glitch) rebuild random
    MAC GRID_TREATMENT_4
;         lda player_state,x
;         and #PLAYER_STATE_FIRING
;         beq _power_grid_replenish
; _power_grid_drain
;         lda player_x,x
;         jsr sub_x2pf
;         lda player_x,x
;         clc
;         adc #$04 ; BUGBUG: using a lot of cycles
;         jsr sub_x2pf
;         lda player_x,x
;         clc
;         adc #$08 ; BUGBUG: using a lot of cycles
;         jsr sub_x2pf
; _power_grid_replenish
        dec power_grid_timer,x
        bpl _power_grid_next
        lda #$40
        sta power_grid_timer,x
        lda power_grid_reserve,x
        clc
        adc #$08
        sta power_grid_reserve,x
        and #$78
        tay
        lda CleanStart,y
        sta SC_WRITE_POWER_GRID_PF0,x
        iny
        lda CleanStart,y
        sta SC_WRITE_POWER_GRID_PF1,x
        iny
        lda CleanStart,y
        sta SC_WRITE_POWER_GRID_PF2,x
        iny
        lda CleanStart,y
        sta SC_WRITE_POWER_GRID_PF3,x
        iny
        lda CleanStart,y
        sta SC_WRITE_POWER_GRID_PF4,x
        iny
        lda CleanStart,y
        sta SC_WRITE_POWER_GRID_PF5,x
        iny
_power_grid_next
    ENDM 

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

        ; TREATMENT 6: adjust colors
    MAC GRID_TREATMENT_6
        lda power_grid_reserve,x
        bmi _zero_grid
        lsr
        lsr
        lsr
        lsr
        ora #POWER_GRID_COLOR
        sta SC_WRITE_POWER_GRID_COLOR,x           
        lda #$ff 
        jmp _store_grid
_zero_grid
        lda #$00
_store_grid
        jsr sub_fill_grid
_power_grid_next
    ENDM 

        ; TREATMENT 7: flicker as power drains


        ; TREATMENT 8: (river) no drain, alternating flow left/right/center/away
    MAC GRID_TREATMENT_8
        ; need state + timer + flow
    ENDM 


