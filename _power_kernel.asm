

;------------------------
; grid helpers          

sub_fill_grid ; x = player, a = value
            sta SC_WRITE_POWER_GRID_PF0,x ; BUGBUG: WILL NOT USE
            sta SC_WRITE_POWER_GRID_PF1,x
            sta SC_WRITE_POWER_GRID_PF2,x
            sta SC_WRITE_POWER_GRID_PF3,x ; BUGBUG: ONLY USE HALF
            sta SC_WRITE_POWER_GRID_PF4,x
            sta SC_WRITE_POWER_GRID_PF5,x ; will be reservoir
            rts

; sub_x2pf ; a=coord, x=player => a=bit, y=blockptr
;             lsr ; div by 4 to get 0...40
;             lsr ; ...
;             tay
;             iny ; BUGBUG: shim for RESP0 at cycle 24
;             lda TABLE_PF_X_BITS,y
;             pha ; push bit pattern temporarily
;             clc
;             txa ; add x to PF ptr
;             adc TABLE_PF_PTR,y
;             tay 
;             pla ; pull bit pattern
;             eor #$ff ; BUGBUG inverting set bit
;             and SC_WRITE_POWER_GRID_PF0,y
;             sta SC_WRITE_POWER_GRID_PF0,y
;             rts

sub_grid_pinch_rl
            pha
            ror
            sta local_power_temp
            lda local_power_pinch_x 
            cmp #20
            bmi _grid_pinch_rl_mod_20
            sec
            sbc #20
_grid_pinch_rl_mod_20
            and #$07
            tay
            lda TABLE_PF_MASK_RL_A,y
            and local_power_temp
            sta local_power_temp
            lda local_power_carry
            asl
            pla
            rol
            and TABLE_PF_MASK_RL_B,y
            ora local_power_temp
            rts

sub_grid_pinch_lr
            pha
            rol
            sta local_power_temp
            lda local_power_pinch_x 
            cmp #20
            bmi _grid_pinch_lr_mod_20
            sec
            sbc #20
_grid_pinch_lr_mod_20
            and #$07
            tay
            lda TABLE_PF_MASK_LR_A,y
            and local_power_temp
            sta local_power_temp
            lda local_power_carry
            asl
            pla
            ror
            and TABLE_PF_MASK_LR_B,y
            ora local_power_temp
            rts

TABLE_PF_COMPLEMENTARY_LOCATION
 .byte 7,6,5,4,3,2,1,0,-1

TABLE_PF_MASK_RL_A
 .byte $f0,$e0,$c0,$8,$ff,$fe,$fc,$f8
 
TABLE_PF_MASK_RL_B
 .byte $0f,$1f,$3f,$7f,$0,$01,$03,$07

TABLE_PF_MASK_LR_A
 .byte $07,$03,$01,$0,$7f,$3f,$1f,$0f

TABLE_PF_MASK_LR_B
 .byte $f8,$fc,$fe,$ff,$8,$c0,$e0,$f0


;  | PF0  | PF1      | PF2      | PF3  | PF4      | PF5      |
;  | 4..7 | 7......0 | 0......7 | 4..7 | 7......0 | 0......7 |
TABLE_PF_X_BITS
 .byte $10
 .byte $20
 .byte $40
 .byte $80
 .byte $80
 .byte $40
 .byte $20
 .byte $10
 .byte $08
 .byte $04
 .byte $02
 .byte $01
 .byte $01
 .byte $02
 .byte $04
 .byte $08
 .byte $10
 .byte $20
 .byte $40
 .byte $80
 .byte $10
 .byte $20
 .byte $40
 .byte $80
 .byte $80
 .byte $40
 .byte $20
 .byte $10
 .byte $08
 .byte $04
 .byte $02
 .byte $01
 .byte $01
 .byte $02
 .byte $04
 .byte $08
 .byte $10
 .byte $20
 .byte $40
 .byte $80

TABLE_PF_PTR
 .byte $00
 .byte $00
 .byte $00
 .byte $00
 .byte $02
 .byte $02
 .byte $02
 .byte $02
 .byte $02
 .byte $02
 .byte $02
 .byte $02
 .byte $04
 .byte $04
 .byte $04
 .byte $04
 .byte $04
 .byte $04
 .byte $04
 .byte $04
 .byte $06
 .byte $06
 .byte $06
 .byte $06
 .byte $08
 .byte $08
 .byte $08
 .byte $08
 .byte $08
 .byte $08
 .byte $08
 .byte $08
 .byte $0a
 .byte $0a
 .byte $0a
 .byte $0a
 .byte $0a
 .byte $0a
 .byte $0a
 .byte $0a

PF0_GRID
  .byte $f0, $00, $00, $00, $00, $f0, $0, $0 ; BUGBUG pad
  .byte $f0, $81, $81, $10, $18, $f8, $0, $0
  .byte $f0, $c3, $c3, $30, $3c, $fc, $0, $0
  .byte $f0, $c3, $c3, $30, $3c, $fc, $0, $0
  .byte $f0, $42, $42, $20, $24, $f4, $0, $0
  .byte $f0, $24, $24, $40, $24, $f2, $0, $0
  .byte $f0, $3c, $3c, $c0, $c3, $f3, $0, $0
  .byte $f0, $3c, $3c, $c0, $c3, $f3, $0, $0
  .byte $f0, $18, $18, $80, $81, $f1, $0, $0
  .byte $f0, $3c, $3c, $c0, $c3, $f3, $0, $0
  .byte $f0, $3c, $3c, $c0, $c3, $f3, $0, $0
  .byte $f0, $24, $24, $40, $24, $f2, $0, $0
  .byte $f0, $42, $42, $20, $24, $f4, $0, $0
  .byte $f0, $c3, $c3, $30, $3c, $fc, $0, $0
  .byte $f0, $c3, $c3, $30, $3c, $fc, $0, $0
  .byte $f0, $81, $81, $10, $18, $f8, $0, $0

;   .byte $f0, $3c, $3c, $c0, $c3, $f3, $0, $0
;   .byte $f0, $81, $81, $10, $18, $f8, $0, $0
;   .byte $f0, $18, $18, $80, $81, $f1, $0, $0


