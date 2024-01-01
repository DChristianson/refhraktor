
    ; select which screen to show
    DEF_LBL attract_menu_kernels
            lda game_state
            and #$0f
            tax
            lda MENU_JUMP_TABLE_HI,x
            pha
            lda MENU_JUMP_TABLE_LO,x
            pha
            rts

MENU_JUMP_TABLE_LO
    byte <(kernel_showSplash-1),<(kernel_showSplash-1),<(kernel_showSplash-1),<(kernel_title-1)
    byte <(kernel_menu_game-1),<(kernel_menu_equip-1),<(kernel_menu_stage-1),<(kernel_menu_accept-1)
MENU_JUMP_TABLE_HI
    byte >(kernel_showSplash-1),>(kernel_showSplash-1),>(kernel_showSplash-1),>(kernel_title-1)
    byte >(kernel_menu_game-1),>(kernel_menu_equip-1),>(kernel_menu_stage-1),>(kernel_menu_accept-1)

;------------------
; title

kernel_title
            jsr waitOnVBlank_2 ; SL 34

            sta WSYNC ; SL 35
            lda #0
            sta COLUBK

            ldx #(192 / 2 - TITLE_HEIGHT * 2 - 8)
            jsr sky_kernel

            jsr title_kernel

            ldx #(SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 42)
            jsr grid_kernel

            ; jump back
            JMP_LBL waitOnOverscan


;------------------------
; std menu kernels

    align 256

kernel_menu_game
kernel_menu_equip
kernel_menu_stage
kernel_menu_accept
            ; load game
            lda game_state
            lsr
            lsr
            lsr
            lsr
            tax
            ldy GAME_MODE_NAMES,x
            lda #12
            ldx #STRING_BUFFER_0
            jsr strfmt
            ; load player graphics
            lda #>MTP_MKI_0
            sta player_sprite + 1
            sta player_sprite + 3
            ldx player_select
            lda PLAYER_SPRITES_B2,x
            sta player_sprite
            ldx player_select + 1
            lda PLAYER_SPRITES_B2,x
            sta player_sprite + 2
            ; load stage
            lda #8
            ldx formation_select
            ldy STAGE_NAMES,x
            ldx #STRING_BUFFER_6
            jsr strfmt
            ; load accept
            lda #8
            ldy #STRING_READY
            ldx #STRING_BUFFER_A
            jsr strfmt

            jsr waitOnVBlank_2 ; SL 34
            
            ldx #20
            jsr sky_kernel
            
            ; menu title text
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_GAME
            bne _not_title
            ldy #30
_not_title
            ldx #STRING_BUFFER_0
            jsr text_kernel

            ; players
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_EQUIP
            bne _not_equip
            ldy #30
_not_equip
            sty COLUP0
            sty COLUP1
            sta WSYNC                ;3   0
            lda #41                  ;3   3
            sec                      ;2   5
_equip_resp_loop
            sbc #15                  ;2   7
            sbcs _equip_resp_loop    ;2   9
            tay                      ;2  11+
            lda LOOKUP_STD_HMOVE_B2,y;4  15+
            sta HMP0                 ;3  18+
            sta HMP1                 ;3  21+
            sta RESP0                ;3  24+ 
            sta RESP1                ;3  27+ 
            sta WSYNC
            sta HMOVE
            lda #0
            sta NUSIZ0
            sta NUSIZ1
            JMP_LBL equip_kernel
    DEF_LBL equip_kernel_return
            sta WSYNC 

            ; stage
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_STAGE
            bne _not_stage
            ldy #30
_not_stage
            ldx #STRING_BUFFER_6
            jsr text_kernel_4

            ; accept
            ldy #02
            lda game_state
            and #$0f
            cmp #GS_MENU_ACCEPT
            bne _not_accept
            ldy #30
_not_accept
            ldx #STRING_BUFFER_A
            jsr text_kernel_4

            ldx #19
            jsr sky_kernel

            ; bottom grid
            ldx #SCANLINES - 192/2 - TITLE_HEIGHT * 2 - 42
            jsr grid_kernel
            
            JMP_LBL waitOnOverscan            


;--------------------------
; sky drawing minikernel

            ; x is number of lines
sky_kernel
            sta WSYNC
            lda #$00
            sta COLUBK
            dex
            bne sky_kernel
            rts



;--------------------------
; text drawing minikernel
; x is string buffer location
; y is color

text_kernel
            sta WSYNC
            lda #$01
            sta VDELP0
            sta VDELP1
            SLEEP 24
;             lda #30
;             sec
; _text_resp_loop
;             sbc #15
;             bcs _text_resp_loop
            sta RESP0    
            sta RESP1
            lda #$03
            sta NUSIZ0
            sta NUSIZ1
            sty COLUP0
            sty COLUP1
            lda #$ff
            sta HMP0
            lda #$00
            sta HMP1
            sta WSYNC
            sta HMOVE

            txa
            sta local_tk_y_min
            clc
            adc #7 ; font height
            tay
            tsx
            stx local_tk_stack
_text_draw_0
            sta WSYNC                                     ;3   0
            ; load and store first 3 
            lda SC_READ_STRING_BUFFER_0,y        ;4   4
            sta GRP0                                      ;3   7
            lda SC_READ_STRING_BUFFER_1,y        ;4  11
            sta GRP1                                      ;3  14
            lda SC_READ_STRING_BUFFER_2,y        ;4  18
            sta GRP0                                      ;3  21
            ; load next 3 EDF
            ldx SC_READ_STRING_BUFFER_4,y        ;4  25
            txs                                           ;2  27
            ldx SC_READ_STRING_BUFFER_3,y        ;4  31
            lda SC_READ_STRING_BUFFER_5,y        ;4  35
            stx.w GRP1                                    ;4  39
            tsx                                           ;2  41
            stx GRP0                                      ;3  44
            sta GRP1                                      ;3  47
            sty GRP0                                      ;3  50 force vdelp
            dey
            cpy local_tk_y_min
            bpl _text_draw_0
            ldx local_tk_stack
            txs
            lda #$00
            sta NUSIZ0
            sta NUSIZ1
            sta GRP0
            sta GRP1
            sta VDELP0
            sta VDELP1
            rts

text_kernel_4
            sta WSYNC
            lda #$01
            sta VDELP0
            sta VDELP1
            SLEEP 24 ; just sleep instead of loop
;             lda #30
;             sec
; _text_resp_loop
;             sbc #15
;             bcs _text_resp_loop
            sta RESP0    
            sta RESP1
            lda #$01
            sta NUSIZ0
            sta NUSIZ1
            sty COLUP0
            sty COLUP1
            lda #$ff
            sta HMP0
            lda #$00
            sta HMP1
            sta WSYNC
            sta HMOVE

            txa
            sta local_tk_y_min
            clc
            adc #7 ; font height
            tay
_text_draw_4_0
            sta WSYNC                                     ;3   0
            ; load and store first 3 
            lda SC_READ_STRING_BUFFER_0,y        ;4   4
            sta GRP0                                      ;3   7
            lda SC_READ_STRING_BUFFER_1,y        ;4  11
            sta GRP1                                      ;3  14
            lda SC_READ_STRING_BUFFER_2,y        ;4  18
            sta GRP0                                      ;3  21
            ; load next 3 EDF
            ldx SC_READ_STRING_BUFFER_3,y        ;4  25
            SLEEP 10                                      ;10 35
            stx.w GRP1                                    ;4  39
            sty GRP0                                      ;3  42 force vdelp
            dey
            cpy local_tk_y_min
            bpl _text_draw_4_0
            lda #$00
            sta NUSIZ0
            sta NUSIZ1
            sta GRP0
            sta GRP1
            sta VDELP0
            sta VDELP1
            rts

;--------------------------
; grid drawing kernel

            ; x is number of lines
grid_kernel
            lda #0 
            sta NUSIZ0    
            sta NUSIZ1    
            sta GRP0
            sta GRP1
            sta WSYNC

            lda #$00
            sta local_grid_inc
            lda #$01
            sta local_grid_gap
            tay 
_grid_loop
            sta WSYNC
            dey
            beq _grid_drawGridLine 
            lda #$00
            sta COLUBK
            jmp _grid_nextGridLine
_grid_drawGridLine
            lda #LOGO_COLOR
            sta COLUBK
            lda local_grid_gap
            asl
            sta local_grid_gap
            clc
            adc local_grid_inc
            tay
_grid_nextGridLine
            dex
            bne _grid_loop
            rts


;--------------------------
; number blitter routine
; y = number to write
; x = graphics buffer offset

bcdfmt
            ; will write one char to x 
            txa 
            clc
            adc #7
            tax
            ; get hi/lo nibble addresses
            tya
            clc
            adc #$11 ; 0-9 numbers start at 
            lsr
            lsr
            lsr
            lsr
            lsr
            sta local_bcdfmt_hi
            bcc _bcdfmt_hi_X
            asl
            asl
            asl
            adc #7
            sta local_bcdfmt_hi
_bcdfmt_lo_X
            tya 
            and #$0f
            lsr
            sta local_bcdfmt_lo
            bcc _bcdfmt_lo_hi
_bcdfmt_lo_lo
            asl
            asl
            asl
            adc #7
            sta local_bcdfmt_lo
_bcdfmt_lo_lo_loop
            ldy local_bcdfmt_hi
            lda FONT_0,y
            asl
            asl
            asl
            asl
            sta STRING_WRITE,x 
            ldy local_bcdfmt_lo
            lda FONT_0,y
            and #$0f
            ora STRING_READ,x
            sta STRING_WRITE,x 
            beq _bcdfmt_exit ; BUGBUG: could exit early
            dec local_bcdfmt_hi
            dec local_bcdfmt_lo
            dex
            jmp _bcdfmt_lo_lo_loop
_bcdfmt_lo_hi
            asl
            asl
            asl
            adc #7
            sta local_bcdfmt_lo
_bcdfmt_lo_hi_loop
            ldy local_bcdfmt_hi
            lda FONT_0,y
            asl
            asl
            asl
            asl
            sta STRING_WRITE,x 
            ldy local_bcdfmt_lo
            lda FONT_0,y
            lsr
            lsr
            lsr
            lsr
            ora STRING_READ,x
            sta STRING_WRITE,x 
            beq _bcdfmt_exit; BUGBUG: could exit early
            dec local_bcdfmt_hi
            dec local_bcdfmt_lo
            dex
            jmp _bcdfmt_lo_hi_loop
_bcdfmt_exit
            rts  ; located in the middle to avoid branch out of bounds
_bcdfmt_hi_X
            asl
            asl
            asl
            adc #7
            sta local_bcdfmt_hi
            tya 
            and #$0f
            lsr
            sta local_bcdfmt_lo
            bcc _bcdfmt_hi_hi
_bcdfmt_hi_lo
            asl
            asl
            asl
            adc #7
_bcdfmt_hi_lo_loop
            sta local_bcdfmt_lo
            ldy local_bcdfmt_hi
            lda FONT_0,y
            and #$f0
            sta STRING_WRITE,x 
            ldy local_bcdfmt_lo
            lda FONT_0,y
            and #$0f
            ora STRING_READ,x
            sta STRING_WRITE,x 
            beq _bcdfmt_exit; BUGBUG: could exit early
            dec local_bcdfmt_hi
            dec local_bcdfmt_lo
            dex
            jmp _bcdfmt_hi_lo_loop
_bcdfmt_hi_hi
            asl
            asl
            asl
            adc #7
            sta local_bcdfmt_lo
_bcdfmt_hi_hi_loop
            ldy local_bcdfmt_hi
            lda FONT_0,y
            and #$f0
            sta STRING_WRITE,x 
            ldy local_bcdfmt_lo
            lda FONT_0,y
            lsr
            lsr
            lsr
            lsr
            ora STRING_READ,x
            sta STRING_WRITE,x 
            beq _bcdfmt_exit; BUGBUG: could exit early
            dec local_bcdfmt_hi
            dec local_bcdfmt_lo
            dex
            jmp _bcdfmt_hi_hi_loop
            
;--------------------------
; text blitter routine
; a = chars to write
; x = graphics buffer offset
; y = char buffer offset

strfmt
            sty local_strfmt_tail
            clc
            adc local_strfmt_tail 
            sta local_strfmt_tail
            ;; only write one line per run
            lda frame
            and #$07
            sta local_strfmt_index_offset
            txa
            ;; push stack counter
            tsx
            stx local_strfmt_stack
            clc
            adc local_strfmt_index_offset
            tax 
            txs
_strfmt_loop
            lda STRING_CONSTANTS,y      
            bne _strfmt_cont
            jmp _strfmt_stop
_strfmt_cont
            lsr
            bcc _strfmt_hi___
_strfmt_lo___
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_hi
            iny 
            lda STRING_CONSTANTS,y      
            beq _strfmt_lo_00
            lsr 
            bcs _strfmt_lo_lo
            ; hi << 4 + lo >> 4 
_strfmt_lo_hi
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_lo_hi_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            lsr
            lsr
            lsr
            lsr
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_lo_hi_loop
            iny 
            jmp _strfmt_loop
            ; hi << 4 + lo & 0f
_strfmt_lo_lo
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_lo_lo_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            and #$0f
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_lo_lo_loop
            iny 
            jmp _strfmt_loop
_strfmt_lo_00            
            ldx local_strfmt_index_hi
            lda FONT_0,x
            asl
            asl
            asl
            asl
            tsx
            sta STRING_WRITE,x
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; dec local_strfmt_count
            ; bpl _strfmt_lo_00
            iny
            jmp _strfmt_stop
_strfmt_hi___
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_hi
            iny 
            lda STRING_CONSTANTS,y      
            beq _strfmt_hi_00
            lsr 
            bcs _strfmt_hi_lo
_strfmt_hi_hi
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_hi_hi_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            lsr
            lsr
            lsr
            lsr
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_hi_hi_loop
            iny 
            jmp _strfmt_loop
            ; hi << 4 + lo & 0f
_strfmt_hi_lo
            asl
            clc
            adc local_strfmt_index_offset
            sta local_strfmt_index_lo
_strfmt_hi_lo_loop
            ldx local_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            ldx local_strfmt_index_lo
            lda FONT_0,x
            and #$0f
            tsx
            ora STRING_READ,x
            sta STRING_WRITE,x 
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; inc local_strfmt_index_lo
            ; dec local_strfmt_count
            ; bpl _strfmt_hi_lo_loop
            iny 
            jmp _strfmt_loop
_strfmt_hi_00            
            ldx local_strfmt_index_hi
            lda FONT_0,x
            and #$f0
            tsx
            sta STRING_WRITE,x
            txa
            clc
            adc #$08
            tax
            txs
            ; inx
            ; txs
            ; inc local_strfmt_index_hi
            ; dec local_strfmt_count
            ; bpl _strfmt_hi_00
            iny
            ; fallthrough
_strfmt_stop
            ; fill out any blanks
            tya
            sec
            sbc local_strfmt_tail
            bpl _strfmt_end
            eor #$ff
            adc #$00
            lsr
            tay
            tsx
_strfmt_00_loop
            lda #$00
            sta STRING_WRITE,x
            txa
            clc
            adc #$08
            tax
            ; inx
            dey
            bpl _strfmt_00_loop
_strfmt_end
            ldx local_strfmt_stack
            txs
            rts

; -------------
; summary screen

    DEF_LBL game_summary_kernel
            ldy #STRING_GAME_OVER
            lda #10
            ldx #STRING_BUFFER_0
            jsr strfmt
            ; ldy player_score
            ; ldx #STRING_BUFFER_5            
            ; jsr bcdfmt
            ; ldy player_score + 1
            ; ldx #STRING_BUFFER_7
            ; jsr bcdfmt

            jsr waitOnVBlank_2 ; SL 34
            
            ldx #40
            jsr sky_kernel
            
            ; game over text
            ldy #30
            ldx #STRING_BUFFER_0
            jsr text_kernel
            ; ldy #30
            ; ldx #STRING_BUFFER_5
            ; jsr text_kernel

            ldx #(192 - 49) ; shim to end of screen
            jsr sky_kernel

            ; jump back
            JMP_LBL waitOnOverscan    

; ------------ 
; title screen

	ALIGN 256

title_kernel    
            lda #$33      ;3=Player and Missile are drawn twice 32 clocks apart 
            sta NUSIZ0    
            sta NUSIZ1    
            lda #LOGO_COLOR
            sta COLUP0        ;3
            sta COLUP1          ;3
            ldy #TITLE_HEIGHT - 1
            lda #$01
            and frame
            beq _jmp_title_96x2_resp_frame_0
            jmp title_96x2_resp_frame_1  
_jmp_title_96x2_resp_frame_0
            jmp title_96x2_resp_frame_0

title_96x2_resp_frame_0
            ; position P0 and P1
            ; TODO: cleanup
            sta WSYNC
            lda #%11100000
            sta HMP0
            lda #%00010000
            sta HMP1
            sta WSYNC
            sleep 28
            sta RESP0
            sleep 14
            sta RESP1
            sta WSYNC
            sta HMOVE
            sta WSYNC
            sta HMCLR
            sta WSYNC              ;3   0
            SLEEP 7                ;7   7

title_96x2_frame_0
            SLEEP 8                ;8  15
            lda TITLE_96x2_06,y    ;4  19
            sta GRP1               ;3  22
            lda TITLE_96x2_00,y    ;4  26
            sta GRP0               ;3  29 - any
            lda TITLE_96x2_02,y    ;4  33
            sta GRP0               ;3  36 - 36
            lda TITLE_96x2_04,y    ;4  40
            sta GRP0               ;3  43 - 43
            SLEEP 2                ;2  45
            lda TITLE_96x2_08,y    ;4  49
            sta GRP1               ;3  52 - 52
            lda TITLE_96x2_10,y    ;4  56
            sta GRP1               ;3  59 - 59
            lda TITLE_96x2_01,y    ;4  63
            sta GRP0               ;3  66 - 66
            lda #$80               ;2  68
            sta HMP0               ;3  71
            sta HMP1               ;3  74
            sta HMOVE              ;3   1 ; HMOVE $80@74 = +8
            SLEEP 16               ;16 17
            lda #0                 ;2  19
            sta HMP0               ;3  22
            sta HMP1               ;3  25
            lda TITLE_96x2_07,y    ;4  29
            sta GRP1               ;3  32 - any
            lda TITLE_96x2_03,y    ;4  36
            sta GRP0               ;3  39 - 39
            lda TITLE_96x2_05,y    ;4  41
            sta GRP0               ;3  46 - 46
            SLEEP 2                ;2  48
            lda TITLE_96x2_09,y    ;4  52
            sta GRP1               ;3  55 - 55
            lda TITLE_96x2_11,y    ;4  59
            sta GRP1               ;3  62 - 62
            SLEEP 9                ;9  71
            sta HMOVE              ;3  74 ; HMOVE $00@71 = -8
            SLEEP 4                ;4   2
            dey                    ;2   4        
            sbpl title_96x2_frame_0 ;2/+ 6/7
            iny
            sty GRP0
            sty GRP1
            rts

    ALIGN 256

title_96x2_resp_frame_1
            ; position P0 and P1
            ; TODO: cleanup
            sta WSYNC
            lda #%00100000
            sta HMP0
            lda #%11110000
            sta HMP1
            sta WSYNC
            sleep 32
            sta RESP0
            sleep 12
            sta RESP1
            sta WSYNC
            sta HMOVE
            sta WSYNC
            sta HMCLR
            sta WSYNC              ;3   0
            SLEEP 7                ;7   7

title_96x2_frame_1 ; on entry HMP+0, on loop HMP+8
            sta HMOVE              ;3  10 ; HMOVE $80@6 = +8
            lda TITLE_96x2_07,y    ;4  14
            sta GRP1               ;3  17
            lda #$00               ;2  19 - TODO: dangerous?
            sta HMP0               ;3  22
            sta HMP1               ;3  25
            lda TITLE_96x2_01,y    ;4  29 
            sta GRP0               ;3  32 - 32
            lda TITLE_96x2_03,y    ;4  36
            sta GRP0               ;3  39 - 39
            lda TITLE_96x2_05,y    ;4  45
            sta GRP0               ;3  46 - 46
            SLEEP 2                ;2  48
            lda TITLE_96x2_09,y    ;4  52
            sta GRP1               ;3  55 - 55
            lda TITLE_96x2_11,y    ;4  59
            sta GRP1               ;3  62 - 62
            lda TITLE_96x2_00,y    ;4  66
            sta GRP0               ;3  69 - 69
            sta.w HMOVE            ;4  73 ; HMOVE $00@69-73 = -8
            SLEEP 25               ;25 22
            lda TITLE_96x2_06,y    ;4  26
            sta GRP1               ;3  29 - any
            lda TITLE_96x2_02,y    ;4  33
            sta GRP0               ;3  36 - 36
            lda TITLE_96x2_04,y    ;4  40
            sta GRP0               ;3  43 - 43
            SLEEP 2                ;2  45 
            lda TITLE_96x2_08,y    ;4  49
            sta GRP1               ;3  52 - 52
            lda TITLE_96x2_10,y    ;4  56
            sta GRP1               ;3  59 - 59
            SLEEP 3                ;3  62
            lda #$80               ;2  64
            sta HMP0               ;3  67
            sta HMP1               ;3  70
            SLEEP 8                ;8   2
            dey                    ;2   4        
            sbpl title_96x2_frame_1 ;2/+ 6/7
            iny
            sty GRP0
            sty GRP1
            rts  

;------------------------
; splash kernel

kernel_showSplash
            jsr waitOnVBlank_2 ; SL 34
            sta WSYNC ; SL 35
            lda frame
            sta COLUBK

            ldx #(SCANLINES - 69)
drawSplashGrid
            sta WSYNC
            ldy #5                  ;3
_loop_splash_grid
            adc #7                  ;2   55  (2)
            sta COLUBK              ;3   58  (5)
            dey                     ;2   60  (7)
            bpl _loop_splash_grid   ;2/3 63 (10)
            adc #7                  ;2   65  
            dex                     ;2   67
            sta COLUBK              ;3   70  
            bne drawSplashGrid      ;2/3 72
            sta WSYNC
            lda #0
            sta COLUBK

            JMP_LBL waitOnOverscan ; BUGBUG jump

;------------------------
; vblank sub

waitOnVBlank_2
            ldx #$00
_waitOnVBlank_loop_2
            cpx INTIM
            bmi _waitOnVBlank_loop_2
            stx VBLANK
            rts 
;---------------------------
; player menu graphics

    ALIGN 256 

; TODO: move to another bank?

; TODO: need a better way to dup?
STD_HMOVE_BEGIN_B2
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END_B2

PLAYER_SPRITES_B2
    byte #<MTP_MKIV_0
    byte #<MTP_MKI_0
    byte #<MTP_MX888_0
    byte #<MTP_CPU_0
    
;-----------------------------
; Font
; 4x7 bit font packed into 8x32 byte array

    ALIGN 256 

FONT_0
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$4e,$a4,$a4,$a4,$a4,$20,$cc; 8
    byte $0,$6c,$82,$82,$66,$22,$0,$cc; 8
    byte $0,$2c,$22,$62,$ac,$a8,$20,$a6; 8
    byte $0,$48,$a8,$a8,$c4,$82,$0,$6e; 8
    byte $0,$42,$a2,$a6,$ea,$aa,$22,$cc; 8
    byte $0,$0,$0,$40,$e,$40,$0,$0; 8
    byte $0,$0,$2,$46,$ee,$46,$2,$0; 8
    byte $0,$0,$8,$ec,$e,$ec,$8,$0; 8
    byte $0,$64,$40,$e0,$40,$e0,$0,$e0; 8
    byte $0,$44,$0,$44,$42,$42,$48,$4c; 8
    byte $0,$ac,$aa,$ea,$ac,$aa,$22,$ec; 8
    byte $0,$ec,$8a,$8a,$8a,$8a,$2,$ec; 8
    byte $0,$e8,$88,$88,$cc,$88,$0,$ee; 8
    byte $0,$ea,$aa,$aa,$8e,$8a,$2,$ea; 8
    byte $0,$4e,$4a,$42,$2,$42,$0,$42; 8
    byte $0,$ae,$a8,$a8,$c8,$a8,$20,$a8; 8
    byte $0,$aa,$aa,$aa,$a,$ea,$2,$ee; 8
    byte $0,$e8,$a8,$a8,$ae,$aa,$22,$ee; 8
    byte $0,$6a,$8a,$ac,$aa,$aa,$22,$ee; 8
    byte $0,$e4,$24,$24,$e4,$84,$0,$ee; 8
    byte $0,$e4,$a4,$aa,$aa,$aa,$2,$aa; 8
    byte $0,$aa,$ea,$ee,$4,$ae,$2,$aa; 8
    byte $0,$4e,$48,$48,$e4,$a2,$20,$ae; 8
    byte $18,$3c,$ff,$55,$ff,$30,$3c,$18; 8
    byte $3c,$7e,$f7,$55,$55,$f7,$7e,$18; 8
    byte $2a,$80,$3d,$e7,$42,$ff,$e7,$81; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8

; string constants
; 0 code is reserved for the end of strings
; code bytes format: xxxxx__y 
;   x locates the byte containing the char
;   y is whether we want the lo/hi nibble

STRING_CONSTANTS
STRING_CHOOSE = . - STRING_CONSTANTS
    byte 96, 113, 144, 144, 160, 104, 0
STRING_GAME = . - STRING_CONSTANTS
    byte 112, 88, 136, 104, 0
STRING_PF1 = . - STRING_CONSTANTS
    byte 145, 9, 0
STRING_PF2 = . - STRING_CONSTANTS
    byte 145, 16, 0
STRING_STAGE = . - STRING_CONSTANTS
    byte 160, 161, 88, 112, 104, 0
STRING_TRACK = . - STRING_CONSTANTS
    byte 161, 153, 88, 96, 128, 0
STRING_VERSUS = . - STRING_CONSTANTS
    byte 169, 104, 153, 160, 168, 160, 0
STRING_QUEST = . - STRING_CONSTANTS
    byte 152, 168, 104, 160, 161, 0
STRING_TOURNAMENT = . - STRING_CONSTANTS
    byte 161, 144, 168, 153, 137, 88, 136, 104, 137, 161, 0
STRING_LC008 = . - STRING_CONSTANTS
    byte 129, 96, 8, 8, 40, 0
STRING_LC0X1 = . - STRING_CONSTANTS
    byte 129, 96, 8, 177, 9, 0
STRING_MX888 = . - STRING_CONSTANTS
    byte 136, 177, 40, 40, 40, 0
STRING_AIM = . - STRING_CONSTANTS
    byte 88, 120, 136, 0
STRING_FIRE = . - STRING_CONSTANTS
    byte 105, 120, 153, 104, 0
STRING_CPU = . - STRING_CONSTANTS
    byte 96, 145, 168, 0
STRING_VOID = . - STRING_CONSTANTS
    byte 169, 144, 120, 97, 0
STRING_CHUTE = . - STRING_CONSTANTS
    byte 96, 113, 168, 161, 104, 0
STRING_DIAMONDS = . - STRING_CONSTANTS
    byte 97, 120, 88, 136, 144, 137, 97, 160, 0
STRING_WINGS = . - STRING_CONSTANTS
    byte 176, 120, 137, 112, 160, 0
STRING_CLICK = . - STRING_CONSTANTS
    byte 96, 129, 120, 96, 128, 0
STRING_TABLA = . - STRING_CONSTANTS
    byte 161, 88, 89, 129, 88, 0
STRING_GLITCH = . - STRING_CONSTANTS
    byte 112, 129, 120, 161, 96, 113, 0
STRING_READY = . - STRING_CONSTANTS
    byte 153, 104, 88, 97, 184, 0
STRING_GATE = . - STRING_CONSTANTS
    byte 112, 88, 161, 104, 0
STRING_CLEAR = . - STRING_CONSTANTS
    byte 96, 129, 104, 88, 153, 0
STRING_GAME_OVER = . - STRING_CONSTANTS
    byte 112, 88, 136, 104, 1, 144, 169, 104, 153, 0
STRING_PLAYER_1 = . - STRING_CONSTANTS
    byte 145, 129, 88, 184, 104, 153, 1, 9, 0
STRING_PLAYER_2 = . - STRING_CONSTANTS
    byte 145, 129, 88, 184, 104, 153, 1, 16, 0
STRING_BATTLE = . - STRING_CONSTANTS
    byte 89, 88, 161, 161, 129, 104, 0
STRING_FRACAS = . - STRING_CONSTANTS
    byte 105, 153, 88, 96, 88, 160, 0
STRING_COMBAT = . - STRING_CONSTANTS
    byte 96, 144, 136, 89, 88, 161, 0
STRING_GATEWAY = . - STRING_CONSTANTS
    byte 112, 88, 161, 104, 176, 88, 184, 0
STRING_PERIL = . - STRING_CONSTANTS
    byte 145, 104, 153, 120, 129, 0
STRING_HAZARD = . - STRING_CONSTANTS
    byte 113, 88, 185, 88, 153, 97, 0
STRING_VENDETTA = . - STRING_CONSTANTS
    byte 169, 104, 137, 97, 104, 161, 161, 88, 0
STRING_FACING = . - STRING_CONSTANTS
    byte 105, 88, 96, 120, 137, 112, 0
STRING_AGAINST = . - STRING_CONSTANTS
    byte 88, 112, 88, 120, 137, 160, 161, 0
STRING_ABSCONDER = . - STRING_CONSTANTS
    byte 88, 89, 160, 96, 144, 137, 97, 104, 153, 0
    
PLAYER_SPRITE_NAMES
    byte STRING_LC008
    byte STRING_LC0X1
    byte STRING_MX888
    byte STRING_CPU

GAME_MODE_NAMES
    byte STRING_VERSUS
    byte STRING_QUEST
    byte STRING_TOURNAMENT

STAGE_NAMES
    byte STRING_VOID
    byte STRING_CHUTE
    byte STRING_DIAMONDS
    ;byte STRING_WINGS

;---------------------------
; title graphics

    ALIGN 256

TITLE_96x2_00
    byte %00000000
    byte %00001000
    byte %00011000
    byte %00111000
    byte %00101001
    byte %00101111
    byte %00101111
    byte %00101011
    byte %00101001
    byte %00101000
    byte %01111111
    byte %11111111

TITLE_96x2_01
    byte %00000000
    byte %00000100
    byte %00011001
    byte %01110011
    byte %11100011
    byte %11000000
    byte %10000011
    byte %11000000
    byte %11100011
    byte %11100011
    byte %11100010
    byte %11000000

TITLE_96x2_02
    byte %00000000
    byte %00000000
    byte %11111100
    byte %11111001
    byte %11110011
    byte %00000011
    byte %11100011
    byte %00000011
    byte %10000011
    byte %00000000
    byte %00000011
    byte %00000011

TITLE_96x2_03
    byte %00000000
    byte %00000010
    byte %00000011
    byte %00000011
    byte %00000011
    byte %00000011
    byte %00000011
    byte %11000011
    byte %11100011
    byte %00000011
    byte %11111001
    byte %11111100

TITLE_96x2_04
    byte %00100000
    byte %00110000
    byte %00110001
    byte %11110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00110011
    byte %00100111
    byte %00001111

TITLE_96x2_05
    byte %00000000
    byte %10000000
    byte %10000001
    byte %10000111
    byte %10011110
    byte %11111100
    byte %11111000
    byte %10111100
    byte %10011110
    byte %10001110
    byte %11111110
    byte %11111100

TITLE_96x2_06
    byte %00000000
    byte %01000000
    byte %10000000
    byte %00110000
    byte %00110111
    byte %00110001
    byte %00110011
    byte %00010111
    byte %00001110
    byte %00011100
    byte %00111000
    byte %00110000

TITLE_96x2_07
    byte %00000000
    byte %00000000
    byte %00000000
    byte %01110011
    byte %11100111
    byte %11001110
    byte %10011100
    byte %00111100
    byte %01110110
    byte %00111011
    byte %00011101
    byte %00001110

TITLE_96x2_08
    byte %00000000
    byte %00000000
    byte %00000001
    byte %10000011
    byte %00000010
    byte %00000010
    byte %00000010
    byte %00000010
    byte %00000010
    byte %00000010
    byte %10001111
    byte %11011111

TITLE_96x2_09
    byte %00000000
    byte %10001000
    byte %10011100
    byte %10011010
    byte %10011101
    byte %10011010
    byte %10011001
    byte %10011000
    byte %10011100
    byte %10001111
    byte %11100111
    byte %11110011

TITLE_96x2_10
    byte %00000000
    byte %00000010
    byte %00000110
    byte %00001110
    byte %00001110
    byte %10001111
    byte %01001111
    byte %11001110
    byte %11001110
    byte %11001110
    byte %10011111
    byte %00111111

TITLE_96x2_11
    byte %00000000
    byte %00000001
    byte %00000110
    byte %00011100
    byte %01111000
    byte %11110000
    byte %11100000
    byte %11110000
    byte %01111000
    byte %00111000
    byte %11111000
    byte %11110000
