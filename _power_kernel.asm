

;------------------------
; grid helpers          

sub_fill_grid ; x = player, a = value
            sta SC_WRITE_POWER_GRID_PF0,x ; BUGBUG: WILL NOT USE
            sta SC_WRITE_POWER_GRID_PF1,x
            sta SC_WRITE_POWER_GRID_PF2,x
            sta SC_WRITE_POWER_GRID_PF3,x ; BUGBUG: ONLY USE HALF
            sta SC_WRITE_POWER_GRID_PF4,x
            sta SC_WRITE_POWER_GRID_PF5,x ; BUGBUG: ONLY USE HALF
            rts

sub_x2pf ; a=coord, x=player => a=bit, y=blockptr
            lsr ; div by 4 to get 0...40
            lsr ; ...
            tay
            iny ; BUGBUG: shim for RESP0 at cycle 24
            lda TABLE_PF_X_BITS,y
            pha ; push bit pattern temporarily
            clc
            txa ; add x to PF ptr
            adc TABLE_PF_PTR,y
            tay 
            pla ; pull bit pattern
            eor #$ff ; BUGBUG inverting set bit
            and SC_WRITE_POWER_GRID_PF0,y
            sta SC_WRITE_POWER_GRID_PF0,y
            rts

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


