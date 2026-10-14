; S3&K option-screen art/text, two pages of eight four-act zones.
; v_levselitem: bit 8 = page; low byte = 32 acts, NEXT/PREV, sound, bonus.
LevelSelect_Init:
        bsr.w Pal_FadeToBlack
        bsr.w ClearPLC
        disable_ints
        move.w (v_vdp_buffer1).w,d0
        andi.b #$BF,d0
        move.w d0,(vdp_control_port).l
        bsr.w ClearScreen
        clearRAM v_spritequeue,v_spritequeue_end
        clearRAM v_objspace,v_objend
        clearRAM v_hscrolltablebuffer,v_hscrolltablebuffer_end
        ResetDMAQueue
        lea (vdp_control_port).l,a6
        move.w #$8230,(a6)
        move.w #$8407,(a6)
        move.w #$8700,(a6)
        move.w #$8C81,(a6)
        move.w #$9001,(a6)
        move.w #$8B00,(a6)
        clr.l (v_scrposy_vdp).w
        locVRAM $200
        lea (Nem_S3LevelSelect).l,a0
        bsr.w NemDec
        lea (Eni_S3LevelSelect).l,a0
        lea (Chunk_Table).l,a1
        move.w #$6000,d0
        bsr.w EniDec
        copyTilemap Chunk_Table,vram_bg,40,28
        clr.w (v_levselitem).w
        clr.w (v_levseldelay).w
        clr.w (v_title_dcount).w
        clr.w (v_title_ccount).w
        bsr.w LevelSelect_AnimateBackground
        bsr.w LevelSelect_TextLoad
        moveq #palid_LevelSel,d0
        bsr.w PalLoad1
        move.w #Vint_Title,(v_vbla_routine).w
        bsr.w WaitForVint
        move.w (v_vdp_buffer1).w,d0
        ori.b #$40,d0
        move.w d0,(vdp_control_port).l
        bsr.w Pal_FadeFromBlack
LevelSelect_Loop:
        move.w #Vint_Title,(v_vbla_routine).w
        bsr.w WaitForVint
        disable_ints
        bsr.w LevelSelect_Controls
        bsr.w LevelSelect_AnimateBackground
        enable_ints
        move.b (v_jpadpress1).w,d1
        move.w (v_levselitem).w,d0
        andi.w #$FF,d0
        cmpi.w #33,d0
        beq.s .sound
        cmpi.w #32,d0
        beq.s .page
        btst #bitC,d1
        beq.s .launch
        addq.w #1,(Player_mode).w
        cmpi.w #3,(Player_mode).w
        blo.s .characterReady
        clr.w (Player_mode).w
.characterReady:
        disable_ints
        bsr.w LevelSelect_TextLoad
        enable_ints
        bra.w LevelSelect_Loop
.launch:
        andi.b #btnA+btnB+btnStart,d1
        beq.w LevelSelect_Loop
        cmpi.w #34,d0
        beq.s .bonus
        move.w d0,d2
        andi.w #3,d2
        andi.w #$1C,d0
        lsl.w #6,d0
        or.w d2,d0
        btst #0,(v_levselitem).w
        beq.s .firstPage
        ori.w #$800,d0
.firstPage:
        move.w d0,(Current_ZoneAndAct).w
        bra.w PlayLevel
.page:
        andi.b #btnABC+btnStart,d1
        beq.w LevelSelect_Loop
        eori.w #$100,(v_levselitem).w
        disable_ints
        bsr.w LevelSelect_TextLoad
        enable_ints
        bra.w LevelSelect_Loop
.sound:
        andi.b #btnABC+btnStart,d1
        beq.w LevelSelect_Loop
        move.w (v_levselsound).w,d0
        jsr (PlaySound_Special).l
        bra.w LevelSelect_Loop
.bonus:
        move.w #BonusStage,(v_gamemode).w
        moveq #0,d0
        move.w d0,(Current_ZoneAndAct).w
        move.b #3,(v_lives).w
        move.w d0,(v_rings).w
        move.l d0,(v_time).w
        move.l d0,(v_score).w
        move.l #5000,(v_scorelife).w
        rts

LevelSelect_Controls:
        move.b (v_jpadpress1).w,d1
        andi.b #btnUp+btnDn,d1
        bne.s .repeat
        subq.w #1,(v_levseldelay).w
        bpl.s .horizontal
.repeat:
        move.w #11,(v_levseldelay).w
        move.b (v_jpadhold1).w,d1
        andi.b #btnUp+btnDn,d1
        beq.s .horizontal
        moveq #0,d0
        move.b (v_levselitem+1).w,d0
        btst #bitUp,d1
        beq.s .down
        move.b LevelSelect_Up(pc,d0.w),d0
        bra.s .store
.down:
        move.b LevelSelect_Down(pc,d0.w),d0
.store:
        move.b d0,(v_levselitem+1).w
        bra.w LevelSelect_TextLoad
.horizontal:
        move.b (v_jpadpress1).w,d1
        andi.b #btnL+btnR,d1
        beq.s .return
        moveq #0,d0
        move.b (v_levselitem+1).w,d0
        cmpi.w #33,d0
        beq.s .sound
        cmpi.w #32,d0
        bhs.s .return
        eori.b #16,(v_levselitem+1).w
        bra.w LevelSelect_TextLoad
.sound:
        move.w (v_levselsound).w,d0
        btst #bitL,d1
        beq.s .right
        subq.w #1,d0
.right:
        btst #bitR,d1
        beq.s .soundStore
        addq.w #1,d0
.soundStore:
        andi.w #$FF,d0
        move.w d0,(v_levselsound).w
        bra.w LevelSelect_TextLoad
.return:
        rts
LevelSelect_Up:
        dc.b 34,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
        dc.b 34,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30
        dc.b 31,32,33
LevelSelect_Down:
        dc.b 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,32
        dc.b 17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32
        dc.b 33,34,0
        even

LevelSelect_TextLoad:
        lea (Chunk_Table).l,a1
        move.w #40*28/2-1,d1
.clear:
        clr.l (a1)+
        dbf d1,.clear
        lea (Chunk_Table).l,a4
        lea LevelSelect_Heading(pc),a1
        lea (a4),a2
        moveq #0,d3
        bsr.w LevelSelect_WriteString
        moveq #0,d6
        move.b (v_levselitem).w,d6
        lsl.w #5,d6
        lea LevelSelect_Names(pc),a5
        adda.w d6,a5
        moveq #0,d7
.zone:
        move.w d7,d0
        lsl.w #2,d0
        lea (LevelSelect_Positions).l,a3
        adda.w d0,a3
        moveq #0,d0
        move.b (a3),d0
        mulu.w #80,d0
        moveq #0,d1
        move.b 1(a3),d1
        add.w d1,d1
        add.w d1,d0
        lea (a4,d0.w),a2
        moveq #0,d3
        moveq #0,d0
        move.b (v_levselitem+1).w,d0
        lsr.w #2,d0
        cmp.w d7,d0
        bne.s .normal
        move.w #$6000,d3
.normal:
        movea.l (a5)+,a1
        bsr.w LevelSelect_WriteString
        moveq #0,d0
        move.b (a3),d0
        mulu.w #80,d0
        moveq #0,d1
        move.b 3(a3),d1
        add.w d1,d1
        add.w d1,d0
        lea (a4,d0.w),a2
        moveq #0,d2
.acts:
        moveq #0,d3
        move.w d7,d0
        lsl.w #2,d0
        add.w d2,d0
        cmp.b (v_levselitem+1).w,d0
        bne.s .actNormal
        move.w #$6000,d3
.actNormal:
        move.w d2,d0
        addi.w #17,d0
        or.w d3,d0
        move.w d0,(a2)
        lea 80(a2),a2
        addq.w #1,d2
        cmpi.w #4,d2
        blo.s .acts
        addq.w #1,d7
        cmpi.w #8,d7
        blo.w .zone
        lea LevelSelect_Next(pc),a1
        tst.b (v_levselitem).w
        beq.s .next
        lea LevelSelect_Previous(pc),a1
.next:
        lea 23*80+2(a4),a2
        moveq #32,d2
        bsr.s .option
        lea LevelSelect_Sound(pc),a1
        lea 24*80+2(a4),a2
        moveq #33,d2
        bsr.s .option
        move.w (v_levselsound).w,d0
        move.w d0,d1
        lsr.w #4,d0
        bsr.w LevelSelect_Hex
        move.w d1,d0
        bsr.w LevelSelect_Hex
        lea LevelSelect_Bonus(pc),a1
        lea 25*80+2(a4),a2
        moveq #34,d2
        bsr.s .option
        lea LevelSelect_Characters(pc),a1
        move.w (Player_mode).w,d0
        andi.w #3,d0
        lsl.w #2,d0
        movea.l (a1,d0.w),a1
        lea 26*80+2(a4),a2
        moveq #0,d3
        bsr.w LevelSelect_WriteString
        copyTilemap Chunk_Table,vram_fg,40,28
        rts
.option:
        moveq #0,d3
        cmp.b (v_levselitem+1).w,d2
        bne.s .optionNormal
        move.w #$6000,d3
.optionNormal:
        ; Fall through.
LevelSelect_WriteString:
        moveq #0,d0
        move.b (a1)+,d0
        cmpi.b #$FF,d0
        beq.s .return
        or.w d3,d0
        move.w d0,(a2)+
        bra.s LevelSelect_WriteString
.return:
        rts
LevelSelect_Hex:
        andi.w #15,d0
        cmpi.w #10,d0
        blo.s .digit
        addq.w #4,d0
.digit:
        addi.w #16,d0
        or.w d3,d0
        move.w d0,(a2)+
        rts
LevelSelect_Positions:
        dc.b 1,1,0,19, 6,1,0,19, 11,1,0,19, 16,1,0,19
        dc.b 1,21,0,39, 6,21,0,39, 11,21,0,39, 16,21,0,39
LevelSelect_AnimateBackground:
        subq.w #1,(v_title_ccount).w
        bpl.s .return
        move.w (v_title_dcount).w,d0
        addq.w #1,(v_title_dcount).w
        cmpi.w #6,(v_title_dcount).w
        blo.s .frame
        clr.w (v_title_dcount).w
.frame:
        add.w d0,d0
        lea LevelSelect_BackgroundFrames(pc),a1
        moveq #0,d1
        move.b (a1,d0.w),d1
        moveq #0,d2
        move.b 1(a1,d0.w),d2
        move.w d2,(v_title_ccount).w
        lsl.w #5,d1
        lea (Art_S3LevelSelectBackground).l,a1
        adda.w d1,a1
        locVRAM $20
        move.w #10*8-1,d2
.copy:
        move.l (a1)+,(vdp_data_port).l
        dbf d2,.copy
.return:
        rts
LevelSelect_BackgroundFrames:
        dc.b 0,199,10,5,20,5,30,199,20,5,10,5
LevelSelect_Names: dc.l LevelSelect_Name0,LevelSelect_Name1,LevelSelect_Name2,LevelSelect_Name3,LevelSelect_Name4,LevelSelect_Name5,LevelSelect_Name6,LevelSelect_Name7,LevelSelect_Name8,LevelSelect_Name9,LevelSelect_Name10,LevelSelect_Name11,LevelSelect_Name12,LevelSelect_Name13,LevelSelect_Name14,LevelSelect_Name15
LevelSelect_Name0: dc.b 49,52,38,41,38,36,37,49,0,37,38,41,41,255
LevelSelect_Name1: dc.b 47,50,48,49,38,32,0,47,50,38,43,48,255
LevelSelect_Name2: dc.b 30,43,32,38,34,43,49,0,52,44,47,40,31,34,43,32,37,255
LevelSelect_Name3: dc.b 34,42,34,47,30,41,33,0,37,38,41,41,255
LevelSelect_Name4: dc.b 32,47,54,48,49,30,41,0,51,30,41,41,34,54,255
LevelSelect_Name5: dc.b 34,36,36,0,42,44,50,43,49,30,38,43,255
LevelSelect_Name6: dc.b 42,34,49,47,44,45,44,41,38,48,255
LevelSelect_Name7: dc.b 48,37,44,32,40,38,43,36,0,31,41,38,55,55,30,47,33,255
LevelSelect_Name8: dc.b 48,32,47,30,45,0,42,30,33,43,34,48,48,255
LevelSelect_Name9: dc.b 33,34,30,49,37,0,34,36,36,255
LevelSelect_Name10: dc.b 41,34,51,34,41,0,16,30,255
LevelSelect_Name11: dc.b 41,34,51,34,41,0,16,31,255
LevelSelect_Name12: dc.b 41,34,51,34,41,0,16,32,255
LevelSelect_Name13: dc.b 41,34,51,34,41,0,16,33,255
LevelSelect_Name14: dc.b 41,34,51,34,41,0,16,34,255
LevelSelect_Name15: dc.b 41,34,51,34,41,0,16,35,255
LevelSelect_Heading: dc.b 41,34,51,34,41,0,48,34,41,34,32,49,255
LevelSelect_Next: dc.b 43,34,53,49,255
LevelSelect_Previous: dc.b 45,47,34,51,38,44,50,48,255
LevelSelect_Sound: dc.b 48,44,50,43,33,0,49,34,48,49,0,0,255
LevelSelect_Bonus: dc.b 48,45,34,32,38,30,41,0,48,49,30,36,34,255
LevelSelect_Both: dc.b 32,28,0,48,44,43,38,32,0,30,43,33,0,49,30,38,41,48,255
LevelSelect_Sonic: dc.b 32,28,0,48,44,43,38,32,255
LevelSelect_Tails: dc.b 32,28,0,49,30,38,41,48,255
LevelSelect_Reverse: dc.b 32,28,0,49,30,38,41,48,0,30,43,33,0,48,44,43,38,32,255
	even
LevelSelect_Characters: dc.l LevelSelect_Both,LevelSelect_Sonic,LevelSelect_Tails,LevelSelect_Reverse
