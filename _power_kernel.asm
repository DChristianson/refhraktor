

;------------------------
; grid helpers          

sub_fill_grid ; x = player, a = value
            sta power_grid_pf0,x
            sta power_grid_pf1,x
            sta power_grid_pf2,x
            sta power_grid_pf3,x
            sta power_grid_pf4,x
            sta power_grid_pf5,x
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
            and power_grid_pf0,y
            sta power_grid_pf0,y
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

