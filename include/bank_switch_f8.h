; F8 bank switching
; Modified from TJ's Atari standard bankswitching macros

BANK_SIZE        = $1000 ; 4K bank size 
SUPERCHIP_WRITE  = $1000 ; SC Write location
SUPERCHIP_READ   = $1080 ; SC Read location

    IFNCONST SUPERCHIP
SUPERCHIP = 0
    ENDIF

; put at the start of every bank 
  MAC START_BANK ; {bank_number}
BANK_NUM    SET {1}	
BANK_ORG    SET $8000 + BANK_NUM * BANK_SIZE 
BANK_RORG   SET $1000 + BANK_NUM * BANK_SIZE * 2
    SEG     code		
    ORG     BANK_ORG, $55	
    RORG    BANK_RORG	
    ECHO    "Start of bank", [BANK_NUM]d, ", ORG", BANK_ORG, ", RORG", BANK_RORG
   IF SUPERCHIP = 1
    ECHO    "Superchip RAM enabled"
    ; super chip RAM
    ds 128, $ff
    ds 128, $ff
   ENDIF
    ; from reset, always jump to bank 1  
ON_RESET = (. & $fff) | $1000 
    lda $fff9
    jmp CleanStart 
SWITCH_BANKS = (. & $fff) | $1000 
    lda $fff8,y
    rts
  ENDM
 
; put at the end of every bank
  MAC END_BANK 
    ORG     BANK_ORG + $ff8
    RORG    BANK_RORG + $ff8
    ; 2 hot spots
    ds      2, 0 
	; nmi, reset and break vectors
   IF SUPERCHIP = 1
    .word  $5343                          ; SUPERCHIP magic word
   ELSE
    .word   0                             ; NMI (unused)
   ENDIF
    .word   (ON_RESET & $fff) | BANK_RORG ; RESET (high nibble needs to match BANK_RORG for debugging)
    .word   0                             ; BRK (unused)
  ENDM


; Define a label which can be used by JMP_LBL macro
; Example:
;    DEF_LBL Foo
  MAC DEF_LBL 
{1}			
{1}_BANK    = BANK_NUM	
  ENDM

; Jump to a label in other or same bank. The assembler will take care if the
; code has to bankswitch or not.
  MAC JMP_LBL ; address
   IF {1}_BANK != BANK_NUM  
    lda     #>({1}-1)		
    pha
    lda     #<({1}-1)		
    pha
    ldy     #{1}_BANK		
    jmp     SWITCH_BANKS         
   ELSE		
    jmp     {1}
   ENDIF
  ENDM 

  MAC CLEAN_START_SUPERCHIP
    CLEAN_START
    lda #0
    ldx #128
.CLEAN_SUPERCHIP
    dex
    sta SUPERCHIP_WRITE,x
    bne .CLEAN_SUPERCHIP
  ENDM