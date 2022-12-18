;;
;; math macros
;;

    MAC CLAMP16 ; given A, MIN, MAX
            ; check bounds, set to MIN or MAX if out of bounds
            ; BUGBUG: doesn't handle fractions
            lda {1}
            bmi .clamp16_check_min
.clamp16_check_max
            lda #({3} - 1) ; BUGBUG: faking the fraction
            cmp {1}
            bcs .clamp16_end
            sta {1}
            lda #$00
            sta {1} + 1
            jmp .clamp16_end
.clamp16_check_min
            lda #{2}
            cmp {1}
            bcc .clamp16_end
            sta {1}
            lda #$00
            sta {1} + 1
.clamp16_end
    ENDM

    MAC CLAMP_REFLECT_16 ; given A, B, MIN, MAX 
            ; check bounds, reflect B if we hit
.clamp16_check_max
            lda #{4}
            cmp {1}
            bcs .clamp16_check_min
            sta {1}
            lda #$00
            sta {1} + 1
            lda {2}
            bmi .clamp16_end
            clc
            lda {2} + 1
            eor #$ff
            adc #$01
            sta {2} + 1
            lda {2}
            eor #$ff
            adc #$00
            sta {2}            
            jmp .clamp16_end
.clamp16_check_min
            lda #{3}
            cmp {1}
            bcc .clamp16_end
            sta {1}
            lda #$00
            sta {1} + 1
            lda {2}
            bpl .clamp16_end
            clc
            lda {2} + 1
            eor #$ff
            adc #$01
            sta {2} + 1
            lda {2}
            eor #$ff
            adc #$00
            sta {2}            
.clamp16_end
    ENDM

    MAC INV16 ; A = -A
            clc
            lda {1} + 1
            eor #$ff
            adc #$01
            sta {1} + 1
            lda {1}
            eor #$ff
            adc #$00
            sta {1}
    ENDM

    MAC ABS16 ; A = ABS(A)
            lda {1}
            bpl .abs16_end
            clc
            lda {1} + 1
            eor #$ff
            adc #$01
            sta {1} + 1
            lda {1}
            eor #$ff
            adc #$00
            sta {1}
.abs16_end
    ENDM

    MAC NEG16 ; A = -ABS(A)
            lda {1}
            bmi .neg16_end
            clc
            lda {1} + 1
            eor #$ff
            adc #$01
            sta {1} + 1
            lda {1}
            eor #$ff
            adc #$00
            sta {1}
.neg16_end
    ENDM

    MAC INC16 ;  A = A + #B
            clc
            lda {1} + 1
            adc #<{2}
            sta {1} + 1
            lda {1}
            adc #>{2}
            sta {1}
    ENDM

    MAC DEC16 ; A + A - #B
            clc
            lda {1} + 1
            adc #<{2}
            sta {1} + 1
            lda {1}
            adc #>{2}
            sta {1}
    ENDM

    MAC ADD16 ; Given A16, B16, store A + B -> A 
            clc
            lda {1} + 1
            adc {2} + 1
            sta {1} + 1
            lda {1}
            adc {2}
            sta {1}
    ENDM

    MAC DOWNSCALE16_8 ; Given A16, B8, store SIGN(A) * (ABS(A) - #B) -> A
            lda {1}
            bmi .downscale16_8_inv
            sec
            lda {1} + 1
            sbc #{2}
            sta {1} + 1
            sbc #$00
            bmi .downscale16_8_zero
            jmp .downscale16_8_end
.downscale16_8_inv
            clc
            lda {1} + 1
            adc #{2}
            sta {1} + 1
            adc #$00
            bpl .downscale16_8_end
.downscale16_8_zero
            lda #$00
            sta {1} + 1
.downscale16_8_end  
            sta {1}

    ENDM

    MAC ADD16_8x; Given A16, B8, store A + B -> A 
            ldy #$00       ;2  2
            lda {2}        ;4  6
            bpl ._add16_8  ;2  8
            ldy #$ff       ;2 10
._add16_8
            clc            ;2 12
            adc {1} + 1    ;3 15
            sta {1} + 1    ;3 18
            tya            ;2 20
            adc {1}        ;3 23
            sta {1}        ;3 26
    ENDM