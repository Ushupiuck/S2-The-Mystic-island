; ---------------------------------------------------------------------------
; Object 0A - drowning bubbles and countdown numbers
; ---------------------------------------------------------------------------

Obj0A:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj0A_Index(pc,d0.w),d1
		jmp	Obj0A_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj0A_Index:	dc.w Obj0A_Init-Obj0A_Index
		dc.w Obj0A_Animate-Obj0A_Index
		dc.w Obj0A_ChkWater-Obj0A_Index
		dc.w Obj0A_Display-Obj0A_Index
		dc.w Obj0A_Delete-Obj0A_Index
		dc.w Obj0A_Countdown-Obj0A_Index
		dc.w Obj0A_AirLeft-Obj0A_Index
		dc.w Obj0A_Display-Obj0A_Index
		dc.w Obj0A_Delete-Obj0A_Index
; ---------------------------------------------------------------------------

Obj0A_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj09_Bubbles,obMap(a0)
		move.w	#make_art_tile(ArtTile_LZ_Bubbles,0,1),obGfx(a0)
		move.b	#$84,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$80,obPriority(a0)
		move.b	obSubtype(a0),d0
		bpl.s	loc_11ECC
		addq.b	#8,obRoutine(a0)
		move.l	#Map_Obj0A_Countdown,obMap(a0)
		move.w	#make_art_tile(ArtTile_LZ_Sonic_Drowning,0,0),obGfx(a0)
		andi.w	#$7F,d0
		move.b	d0,objoff_33(a0)
		bra.w	Obj0A_Countdown
; ---------------------------------------------------------------------------

loc_11ECC:
		move.b	d0,obAnim(a0)
		move.w	obX(a0),objoff_30(a0)
		move.w	#-$88,obVelY(a0)

Obj0A_Animate:
		lea	Ani_Obj0A(pc),a1
		jsr	(AnimateSprite).l

Obj0A_ChkWater:
		move.w	(v_waterpos1).w,d0
		cmp.w	obY(a0),d0
		blo.s	loc_11F0A
		move.b	#6,obRoutine(a0)
		addq.b	#7,obAnim(a0)
		cmpi.b	#$D,obAnim(a0)
		beq.s	Obj0A_Display
		bra.s	Obj0A_Display
; ---------------------------------------------------------------------------

loc_11F0A:
		tst.b	(f_wtunnelmode).w
		beq.s	loc_11F14
		addq.w	#4,objoff_30(a0)

loc_11F14:
		move.b	obAngle(a0),d0
		addq.b	#1,obAngle(a0)
		andi.w	#$7F,d0
		lea	(Drown_WobbleData).l,a1
		move.b	(a1,d0.w),d0
		ext.w	d0
		add.w	objoff_30(a0),d0
		move.w	d0,obX(a0)
		bsr.s	Obj0A_ShowNumber
		jsr	(ObjectMove).l
		tst.b	obRender(a0)
		bpl.s	Obj0A_Delete
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

Obj0A_Display:
		bsr.s	Obj0A_ShowNumber
		lea	Ani_Obj0A(pc),a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ---------------------------------------------------------------------------

Obj0A_Delete:
		jmp	(DeleteObject).l
; ---------------------------------------------------------------------------

Obj0A_AirLeft:
		cmpi.w	#$C,(v_air).w
		bhi.s	Obj0A_Delete
		subq.w	#1,objoff_38(a0)
		bne.s	loc_11F82
		move.b	#$E,obRoutine(a0)
		addq.b	#7,obAnim(a0)
		bra.s	Obj0A_Display
; ---------------------------------------------------------------------------

loc_11F82:
		lea	Ani_Obj0A(pc),a1
		jsr	(AnimateSprite).l
		tst.b	obRender(a0)
		bpl.s	Obj0A_Delete
		jmp	(DisplaySprite).l

; =============== S U B	R O U T	I N E =======================================


Obj0A_ShowNumber:
		tst.w	objoff_38(a0)
		beq.s	.return
		subq.w	#1,objoff_38(a0)
		bne.s	.return
		cmpi.b	#7,obAnim(a0)
		bhs.s	.return
		move.w	#$F,objoff_38(a0)
		clr.w	obVelY(a0)
		move.b	#$80,obRender(a0)
		move.w	obX(a0),d0
		sub.w	(Camera_RAM).w,d0
		addi.w	#$80,d0
		move.w	d0,obX(a0)
		move.w	obY(a0),d0
		sub.w	(Camera_Y_pos).w,d0
		addi.w	#$80,d0
		move.w	d0,obScreenY(a0)
		move.b	#$C,obRoutine(a0)

.return:
		rts
; End of function Obj0A_ShowNumber

; ---------------------------------------------------------------------------

Obj0A_Countdown:
		tst.w	objoff_2C(a0)
		bne.w	loc_121D6
		cmpi.b	#6,(v_player+obRoutine).w
		bhs.w	Obj0A_ShowNumber.return
		btst	#6,(v_player+obStatus).w
		beq.w	Obj0A_ShowNumber.return
		subq.w	#1,objoff_38(a0)
		bpl.w	loc_121FC
		move.w	#60-1,objoff_38(a0)
		move.w	#1,objoff_36(a0)
		jsr	(RandomNumber).l
		andi.w	#1,d0
		move.b	d0,objoff_34(a0)
		move.w	(v_air).w,d0
		cmpi.w	#25,d0
		beq.s	loc_12166
		cmpi.w	#20,d0
		beq.s	loc_12166
		cmpi.w	#15,d0
		beq.s	loc_12166
		cmpi.w	#12,d0
		bhi.s	loc_12170
		bne.s	loc_12152
		move.w	#bgm_Drowning,d0
		jsr	(PlaySound).l

loc_12152:
		subq.b	#1,objoff_32(a0)
		bpl.s	loc_12170
		move.b	objoff_33(a0),objoff_32(a0)
		bset	#7,objoff_36(a0)
		bra.s	loc_12170
; ---------------------------------------------------------------------------

loc_12166:
		move.w	#sfx_Warning,d0
		jsr	(PlaySound_Special).l

loc_12170:
		subq.w	#1,(v_air).w
		bhs.w	loc_1220C
		bsr.w	ResumeMusic
		move.b	#$81,(f_playerctrl).w
		move.w	#sfx_Drown,d0
		jsr	(PlaySound_Special).l
		move.b	#$A,objoff_34(a0)
		move.w	#1,objoff_36(a0)
		move.w	#60*2,objoff_2C(a0)
		move.l	a0,-(sp)
		lea	(v_player).w,a0
		bsr.w	Sonic_ResetOnFloor
		move.b	#$17,obAnim(a0)
		bset	#1,obStatus(a0)
		bset	#7,obGfx(a0)
		clr.w	obVelY(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		move.b	#1,(Deform_lock).w
		movea.l	(sp)+,a0
		rts
; ---------------------------------------------------------------------------

loc_121D6:
		subq.w	#1,objoff_2C(a0)
		bne.s	loc_121E4
		move.b	#6,(v_player+obRoutine).w
		rts
; ---------------------------------------------------------------------------

loc_121E4:
		move.l	a0,-(sp)
		lea	(v_player).w,a0
		jsr	(ObjectMove).l
		addi.w	#$10,obVelY(a0)
		movea.l	(sp)+,a0
; ---------------------------------------------------------------------------

loc_121FC:
		tst.w	objoff_36(a0)
		beq.w	loc_12242.return
		subq.w	#1,objoff_3A(a0)
		bpl.w	loc_12242.return

loc_1220C:
		jsr	(RandomNumber).l
		andi.w	#$F,d0
		move.w	d0,objoff_3A(a0)
		jsr	(FindFreeObj).l
		bne.s	loc_12242.return
		_move.b	#id_Obj0A,obID(a1)
		move.w	(v_player+obX).w,obX(a1)
		moveq	#6,d0
		btst	#0,(v_player+obStatus).w
		beq.s	loc_12242
		neg.w	d0
		move.b	#$40,obAngle(a1)

loc_12242:
		add.w	d0,obX(a1)
		move.w	(v_player+obY).w,obY(a1)
		move.b	#6,obSubtype(a1)
		tst.w	objoff_2C(a0)
		beq.w	loc_1228E
		andi.w	#7,objoff_3A(a0)
		move.w	(v_player+obY).w,d0
		subi.w	#$C,d0
		move.w	d0,obY(a1)
		jsr	(RandomNumber).l
		move.b	d0,obAngle(a1)
		move.w	(Timer_frames).w,d0
		andi.b	#3,d0
		bne.s	+
		move.b	#$E,obSubtype(a1)
+
		subq.b	#1,objoff_34(a0)
		bpl.s	.return
		clr.w	objoff_36(a0)
.return:
		rts
; ---------------------------------------------------------------------------

loc_1228E:
		btst	#7,objoff_36(a0)
		beq.s	loc_122D2
		move.w	(v_air).w,d2
		lsr.w	#1,d2
		jsr	(RandomNumber).l
		andi.w	#3,d0
		bne.s	loc_122BA
		bset	#6,objoff_36(a0)
		bne.s	loc_122D2
		move.b	d2,obSubtype(a1)
		move.w	#$1C,objoff_38(a1)

loc_122BA:
		tst.b	objoff_34(a0)
		bne.s	loc_122D2
		bset	#6,objoff_36(a0)
		bne.s	loc_122D2
		move.b	d2,obSubtype(a1)
		move.w	#$1C,objoff_38(a1)

loc_122D2:
		subq.b	#1,objoff_34(a0)
		bpl.s	.return
		clr.w	objoff_36(a0)

.return:
		rts
; ---------------------------------------------------------------------------
Ani_Obj0A:
		dc.w byte_1233A-Ani_Obj0A,byte_12343-Ani_Obj0A
		dc.w byte_1234C-Ani_Obj0A,byte_12355-Ani_Obj0A
		dc.w byte_1235E-Ani_Obj0A,byte_12367-Ani_Obj0A
		dc.w byte_12370-Ani_Obj0A,byte_12375-Ani_Obj0A
		dc.w byte_1237D-Ani_Obj0A,byte_12385-Ani_Obj0A
		dc.w byte_1238D-Ani_Obj0A,byte_12395-Ani_Obj0A
		dc.w byte_1239D-Ani_Obj0A,byte_123A5-Ani_Obj0A
		dc.w byte_123A7-Ani_Obj0A
byte_1233A:	dc.b   5,  0,  1,  2,  3,  4,  9, $D,$FC
byte_12343:	dc.b   5,  0,  1,  2,  3,  4, $C,$12,$FC
byte_1234C:	dc.b   5,  0,  1,  2,  3,  4, $C,$11,$FC
byte_12355:	dc.b   5,  0,  1,  2,  3,  4, $B,$10,$FC
byte_1235E:	dc.b   5,  0,  1,  2,  3,  4,  9, $F,$FC
byte_12367:	dc.b   5,  0,  1,  2,  3,  4, $A, $E,$FC
byte_12370:	dc.b  $E,  0,  1,  2,$FC
byte_12375:	dc.b   7,$16, $D,$16, $D,$16, $D,$FC
byte_1237D:	dc.b   7,$16,$12,$16,$12,$16,$12,$FC
byte_12385:	dc.b   7,$16,$11,$16,$11,$16,$11,$FC
byte_1238D:	dc.b   7,$16,$10,$16,$10,$16,$10,$FC
byte_12395:	dc.b   7,$16, $F,$16, $F,$16, $F,$FC
byte_1239D:	dc.b   7,$16, $E,$16, $E,$16, $E,$FC
byte_123A5:	dc.b  $E,$FC
byte_123A7:	dc.b  $E,  1,  2,  3,  4,$FC
		even
; ---------------------------------------------------------------------------
Drown_WobbleData:
		rept 2
		dc.b 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2
		dc.b 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
		dc.b 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2
		dc.b 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0
		dc.b 0, -1, -1, -1, -1, -1, -2, -2, -2, -2, -2, -3, -3, -3, -3, -3
		dc.b -3, -3, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4
		dc.b -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -3
		dc.b -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, -1
		endm