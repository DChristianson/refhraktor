
    DEF_LBL bank_audio_tracker
            ldx #NUM_AUDIO_CHANNELS - 1
audio_loop 
            lda audio_tracker,x
            beq audio_next_channel
            ldy audio_timer,x
            beq _audio_next_note
            dey
            sty audio_timer,x
            jmp audio_next_channel
_audio_next_note
            tay
            lda AUDIO_TRACKS,y
            beq _audio_pause
            cmp #255
            beq _audio_stop
            sta AUDC0,x
            iny
            lda AUDIO_TRACKS,y
            sta AUDF0,x
            iny
            lda AUDIO_TRACKS,y
            sta AUDV0,x
            jmp _audio_next_timer
_audio_pause
            lda #$0
            sta AUDC0,x
            sta AUDV0,x
_audio_next_timer
            iny
            lda AUDIO_TRACKS,y
            sta audio_timer,x
            iny
            sty audio_tracker,x
            jmp audio_next_channel
_audio_stop ; got a 255
            iny 
            lda AUDIO_TRACKS,y ; store next track #
            sta audio_tracker,x 
            bne _audio_next_note ; if not zero loop back 
            sta AUDV0,x
            sta audio_timer,x
audio_next_channel
            dex
            bpl audio_loop

            JMP_LBL bank_return_audio_tracker

AUDIO_TRACKS ; AUDCx,AUDFx,AUDVx,T
    byte 0,
TRACK_0 = . - AUDIO_TRACKS
    byte 3,31,15,64,3,31,7,16,3,31,3,8,3,31,1,16,255,0;
CLICK_0 = . - AUDIO_TRACKS
    byte 3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,255,CLICK_0;
TABLA_0 = . - AUDIO_TRACKS
    byte 3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,255,TABLA_0;
GLITCH_0 = . - AUDIO_TRACKS
    byte 3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,3,31,15,15,0,45,255,GLITCH_0;