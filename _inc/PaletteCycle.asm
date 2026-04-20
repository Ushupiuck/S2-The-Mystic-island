; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


PalCycle_Load:
		moveq	#0,d2
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		add.w	d0,d0
		move.w	PalCycle(pc,d0.w),d0
		jmp	PalCycle(pc,d0.w)
; ===========================================================================
PalCycle:	dc.w PalCycle_GHZ-PalCycle	; Zone 0
		dc.w PalCycle_WZ-PalCycle	; Zone 1
		dc.w PalCycle_CPZ-PalCycle	; Zone 2
		dc.w PalCycle_Null-PalCycle	; Zone 3 (DISABLED)
		dc.w PalCycle_HPZ-PalCycle	; Zone 4
		dc.w PalCycle_Null-PalCycle	; Zone 5 (DISABLED)
		dc.w PalCycle_MTZ-PalCycle	; Zone 6
		dc.w PalCycle_WZ-PalCycle	; Zone 7
		dc.w PalCycle_MTZ-PalCycle	; Zone 8
		dc.w PalCycle_GHZ-PalCycle	; Zone 9
; ===========================================================================
PalCycle_Null:
		rts
; ===========================================================================

PalCycle_GHZ:
		lea	(Pal_GHZCyc).l,a0
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#5,(v_pcyc_time).w
		move.w	(v_pcyc_num).w,d0
		addq.w	#1,(v_pcyc_num).w
		andi.w	#3,d0
		lsl.w	#3,d0
		lea	(v_palette+$50).w,a1
		move.l	(a0,d0.w),(a1)+
		move.l	4(a0,d0.w),(a1)
.return:	rts
; ===========================================================================

PalCycle_WZ:
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#2,(v_pcyc_time).w
		lea	(Pal_WZCyc).l,a0
		move.w	(v_pcyc_num).w,d0
		subq.w	#2,(v_pcyc_num).w
		bcc.s	+
		move.w	#6,(v_pcyc_num).w
+
		lea	(v_palette+$66).w,a1
		move.l	(a0,d0.w),(a1)+
		move.l	4(a0,d0.w),(a1)
.return:	rts
; ===========================================================================

PalCycle_CPZ:
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#7,(v_pcyc_time).w
		lea	(Pal_CPZCyc1).l,a0
		move.w	(v_pcyc_num).w,d0
		addq.w	#6,(v_pcyc_num).w
		cmpi.w	#$36,(v_pcyc_num).w
		bcs.s	+
		move.w	#0,(v_pcyc_num).w
+
		lea	(v_palette+$78).w,a1
		move.l	(a0,d0.w),(a1)+
		move.w	4(a0,d0.w),(a1)
		lea	(Pal_CPZCyc2).l,a0
		move.w	(v_pal_buffer+2).w,d0
		addq.w	#2,(v_pal_buffer+2).w
		cmpi.w	#$2A,(v_pal_buffer+2).w
		bcs.s	+
		move.w	#0,(v_pal_buffer+2).w
+
		move.w	(a0,d0.w),(v_palette+$7E).w
		lea	(Pal_CPZCyc3).l,a0
		move.w	(v_pal_buffer+4).w,d0
		addq.w	#2,(v_pal_buffer+4).w
		andi.w	#$1E,(v_pal_buffer+4).w
		move.w	(a0,d0.w),(v_palette+$5E).w
.return:	rts
; ===========================================================================

PalCycle_HPZ:
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#4,(v_pcyc_time).w
		lea	(Pal_HPZCyc1).l,a0
		move.w	(v_pcyc_num).w,d0
		subq.w	#2,(v_pcyc_num).w
		bcc.s	+
		move.w	#6,(v_pcyc_num).w
+
		lea	(v_palette+$72).w,a1
		move.l	(a0,d0.w),(a1)+
		move.l	4(a0,d0.w),(a1)
		lea	(Pal_HPZCyc2).l,a0
		lea	(v_palette_water+$72).w,a1
		move.l	(a0,d0.w),(a1)+
		move.l	4(a0,d0.w),(a1)
.return:	rts
; ===========================================================================

PalCycle_EHZ:
		lea	(Pal_EHZCyc).l,a0
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#7,(v_pcyc_time).w
		move.w	(v_pcyc_num).w,d0
		addq.w	#1,(v_pcyc_num).w
		andi.w	#3,d0
		lsl.w	#3,d0
		move.l	(a0,d0.w),(v_palette+$26).w
		move.l	4(a0,d0.w),(v_palette+$3C).w
.return:	rts
; ===========================================================================

PalCycle_HTZ:
		lea	(Pal_HTZCyc1).l,a0
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#0,(v_pcyc_time).w
		move.w	(v_pcyc_num).w,d0
		addq.w	#1,(v_pcyc_num).w
		andi.w	#$F,d0
		lea	(Pal_HTZCyc2).l,a1
                move.b	(a1,d0.w),(v_pcyc_time+1).w
		lsl.w	#3,d0
		move.l	(a0,d0.w),(v_palette+$26).w
		move.l	4(a0,d0.w),(v_palette+$3C).w
.return:	rts
; ===========================================================================

PalCycle_MTZ:
		subq.w	#1,(v_pcyc_time).w
		bpl.s	++
		move.w	#$11,(v_pcyc_time).w
		lea	(Pal_MTZCyc1).l,a0
		move.w	(v_pcyc_num).w,d0
		addq.w	#2,(v_pcyc_num).w
		cmpi.w	#$C,(v_pcyc_num).w
		bcs.s	+
		move.w	#0,(v_pcyc_num).w
+
		lea	(v_palette+$4A).w,a1
		move.w	(a0,d0.w),(a1)
+
		subq.w	#1,(v_pcyc_time2).w
		bpl.s	++
		move.w	#2,(v_pcyc_time2).w
		lea	(Pal_MTZCyc2).l,a0
		move.w	(v_pcyc_num2).w,d0
		addq.w	#2,(v_pcyc_num2).w
		cmpi.w	#6,(v_pcyc_num2).w
		bcs.s	+
		move.w	#0,(v_pcyc_num2).w
+
		lea	(v_palette+$42).w,a1
		move.l	(a0,d0.w),(a1)+
		move.w	4(a0,d0.w),(a1)
+
		subq.w	#1,(v_pcyc_time3).w
		bpl.s	.return
		move.w	#9,(v_pcyc_time3).w
		lea	(Pal_MTZCyc3).l,a0
		move.w	(v_pcyc_num3).w,d0
		addq.w	#2,(v_pcyc_num3).w
		cmpi.w	#$14,(v_pcyc_num3).w
		bcs.s	+
		move.w	#0,(v_pcyc_num3).w
+
		lea	(v_palette+$5E).w,a1
		move.w	(a0,d0.w),(a1)
.return:	rts
; ===========================================================================
PalCycle_ARZ:
		lea	(Pal_GHZCyc).l,a0
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
		move.w	#5,(v_pcyc_time).w
		move.w	(v_pcyc_num).w,d0
		addq.w	#1,(v_pcyc_num).w
		andi.w	#3,d0
		lsl.w	#3,d0
		lea	(v_palette+$44).w,a1
		move.l	(a0,d0.w),(a1)+
		move.l	4(a0,d0.w),(a1)
.return:	rts
; ===========================================================================
PalCycle_SBZ:
;		lea	(Pal_SBZCycList1).l,a2
;		tst.b	(v_act).w
;		beq.s	.is_act1
;		lea	(Pal_SBZCycList2).l,a2

.is_act1:
		lea	(v_pal_buffer).w,a1
		move.w	(a2)+,d1

.loop:
		subq.b	#1,(a1)
		bmi.s	+
		addq.l	#2,a1
		addq.l	#6,a2
		bra.s	+++
; ===========================================================================
+
		move.b	(a2)+,(a1)+
		move.b	(a1),d0
		addq.b	#1,d0
		cmp.b	(a2)+,d0
		blo.s	+
		moveq	#0,d0
+
		move.b	d0,(a1)+
		andi.w	#$F,d0
		add.w	d0,d0
		movea.w	(a2)+,a0
		movea.w	(a2)+,a3
		move.w	(a0,d0.w),(a3)
+
		dbf	d1,.loop
		subq.w	#1,(v_pcyc_time).w
		bpl.s	.return
;		lea	(Pal_SBZCyc4).l,a0
		move.w	#1,(v_pcyc_time).w
		tst.b	(v_act).w
		beq.s	+
;		lea	(Pal_SBZCyc10).l,a0
		move.w	#0,(v_pcyc_time).w
+
		moveq	#-1,d1
;		tst.b	(f_conveyrev).w
		beq.s	+
		neg.w	d1
+
		move.w	(v_pcyc_num).w,d0
		andi.w	#3,d0
		add.w	d1,d0
		cmpi.w	#3,d0
		blo.s	+
		move.w	d0,d1
		moveq	#0,d0
		tst.w	d1
		bpl.s	+
		moveq	#2,d0
+
		move.w	d0,(v_pcyc_num).w
		add.w	d0,d0
		lea	(v_palette+$58).w,a1
		move.l	(a0,d0.w),(a1)+
		move.w	4(a0,d0.w),(a1)
.return:	rts
; End of function PalCycle_SBZ
; ===========================================================================

PalCycle_Sega:
		tst.b	(v_pcyc_time+1).w
		bne.s	loc_2404
		lea	(v_palette+$20).w,a1
		lea	(Pal_Sega1).l,a0
		moveq	#5,d1
		move.w	(v_pcyc_num).w,d0

loc_23BA:
		bpl.s	loc_23C4
		addq.w	#2,a0
		subq.w	#1,d1
		addq.w	#2,d0
		bra.s	loc_23BA
; ---------------------------------------------------------------------------

loc_23C4:
		move.w	d0,d2
		andi.w	#$1E,d2
		bne.s	loc_23CE
		addq.w	#2,d0

loc_23CE:
		cmpi.w	#$60,d0
		bcc.s	loc_23D8
		move.w	(a0)+,(a1,d0.w)

loc_23D8:
		addq.w	#2,d0
		dbf	d1,loc_23C4
		move.w	(v_pcyc_num).w,d0
		addq.w	#2,d0
		move.w	d0,d2
		andi.w	#$1E,d2
		bne.s	loc_23EE
		addq.w	#2,d0

loc_23EE:
		cmpi.w	#$64,d0
		blt.s	loc_23FC
		move.w	#$401,(v_pcyc_time).w
		moveq	#-$C,d0

loc_23FC:
		move.w	d0,(v_pcyc_num).w
		moveq	#1,d0
		rts
; ---------------------------------------------------------------------------

loc_2404:
		subq.b	#1,(v_pcyc_time).w
		bpl.s	loc_2456
		move.b	#4,(v_pcyc_time).w
		move.w	(v_pcyc_num).w,d0
		addi.w	#$C,d0
		cmpi.w	#$30,d0
		blo.s	loc_2422
		moveq	#0,d0
		rts
; ---------------------------------------------------------------------------

loc_2422:
		move.w	d0,(v_pcyc_num).w
		lea	(Pal_Sega2).l,a0
		lea	(a0,d0.w),a0
		lea	(v_palette+4).w,a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.w	(a0)+,(a1)
		lea	(v_palette+$20).w,a1
		moveq	#0,d0
		moveq	#$2C,d1

loc_2442:
		move.w	d0,d2
		andi.w	#$1E,d2
		bne.s	loc_244C
		addq.w	#2,d0

loc_244C:
		move.w	(a0),(a1,d0.w)
		addq.w	#2,d0
		dbf	d1,loc_2442

loc_2456:
		moveq	#1,d0
		rts
; End of function PalCycle_Load