; ---------------------------------------------------------------------------
; Object 18 - platforms	(GHZ, SYZ, SLZ)
; ---------------------------------------------------------------------------

Obj18:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj18_Index(pc,d0.w),d1
		jmp	Obj18_Index(pc,d1.w)
; ===========================================================================
Obj18_Index:	dc.w Plat_Main-Obj18_Index
		dc.w Plat_Solid-Obj18_Index
		dc.w Plat_Delete-Obj18_Index
		dc.w Plat_Action-Obj18_Index
		dc.w Plat_Solid2-Obj18_Index
Obj18_Conf:
		;    width_pixels
		;	 frame
		dc.b $20, 0
		dc.b $20, 1
		dc.b $20, 2
		dc.b $40, 3
		dc.b $30, 4
; ===========================================================================

Plat_Main:
		addq.b	#2,obRoutine(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		lsr.w	#3,d0
		andi.w	#$1E,d0
		lea	Obj18_Conf(pc,d0.w),a2
		move.b	(a2)+,obActWid(a0)
		move.b	(a2)+,obFrame(a0)
		move.w	#$4000,obGfx(a0)
		move.l	#Map_Obj18,obMap(a0)
		cmpi.b	#3,(v_zone).w
		beq.s	loc_8866
		cmpi.b	#5,(v_zone).w
		bne.s	loc_8874

loc_8866:
		move.l	#Map_Obj18_EHZ,obMap(a0)
		move.w	#$4000,obGfx(a0)

loc_8874:
		move.b	#4,obRender(a0)
		move.b	#4,obPriority(a0)
		move.w	obY(a0),objoff_2C(a0)
		move.w	obY(a0),objoff_34(a0)
		move.w	obX(a0),objoff_32(a0)
		move.w	#$80,obAngle(a0)
		tst.b	obSubtype(a0)
		bpl.s	.skip
		addq.b	#6,obRoutine(a0)
		andi.b	#$F,obSubtype(a0)
		move.b	#$30,obHeight(a0)
		bset	#4,obRender(a0)
		bra.w	Plat_Solid2

.skip
		andi.b	#$F,obSubtype(a0)

Plat_Solid:
		move.b	obStatus(a0),d0
		andi.b	#standing_mask,d0
		bne.s	+
		tst.b	objoff_38(a0)
		beq.s	++
		subq.b	#4,objoff_38(a0)
		bra.s	++
; ===========================================================================
+
		cmpi.b	#$40,objoff_38(a0)
		beq.s	+
		addq.b	#4,objoff_38(a0)
+
		move.w	obX(a0),-(sp)
		bsr.w	Plat_Move
		bsr.w	Plat_Nudge
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#8,d3
		move.w	(sp)+,d4
		jsr	(PlatformObject).l
		bra.s	loc_88E8
; ===========================================================================

Plat_Action:
		bsr.w	Plat_Move
		bsr.w	Plat_Nudge

loc_88E8:
		out_of_range.w	DeleteObject,objoff_32(a0)
		jmp	(DisplaySprite).l
; ===========================================================================

Plat_Delete:
		jmp	(DeleteObject).l
; ===========================================================================

Plat_Solid2:
		move.b	obStatus(a0),d0
		andi.b	#standing_mask,d0
		bne.s	+
		tst.b	objoff_38(a0)
		beq.s	++
		subq.b	#4,objoff_38(a0)
		bra.s	++
; ===========================================================================
+
		cmpi.b	#$40,objoff_38(a0)
		beq.s	+
		addq.b	#4,objoff_38(a0)
+
		move.w	obX(a0),-(sp)
		bsr.w	Plat_Move
		bsr.w	Plat_Nudge
		moveq	#0,d1
		move.b	obActWid(a0),d1
		addi.w	#$B,d1
		moveq	#0,d2
		move.b	obHeight(a0),d2
		move.w	d2,d3
		addq.w	#1,d3
		move.w	(sp)+,d4
		jsr	(PlatformObject).l
		bra.s	loc_88E8


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


Plat_Nudge:
		move.b	objoff_38(a0),d0
		jsr	(CalcSine).l
		move.w	#$400,d1
		muls.w	d1,d0
		swap	d0
		add.w	objoff_2C(a0),d0
		move.w	d0,obY(a0)
		rts
; End of function Plat_Nudge


; ||||||||||||||| S U B	R O U T	I N E |||||||||||||||||||||||||||||||||||||||


Plat_Move:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		add.w	d0,d0
		move.w	.index(pc,d0.w),d1
		jmp	.index(pc,d1.w)
; End of function Plat_Move

; ===========================================================================
.index:		dc.w type00-.index, type01-.index
		dc.w type02-.index, type03-.index
		dc.w type04-.index, type05-.index
		dc.w type06-.index, type07-.index
		dc.w type08-.index, type00-.index
		dc.w type0A-.index, type0D-.index
		dc.w type0B-.index, type0C-.index
; ===========================================================================

type00:
		rts			; platform 00 doesn't move
; ===========================================================================

type05:
		move.w	objoff_32(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		neg.b	d1		; reverse platform-motion
		addi.b	#$40,d1
		bra.s	type01_move
; ===========================================================================

type01:
		move.w	objoff_32(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		subi.b	#$40,d1

type01_move:
		ext.w	d1
		add.w	d1,d0
		move.w	d0,obX(a0)	; change position on x-axis
		bra.w	chgmotion
; ===========================================================================

type0C:
		move.w	objoff_34(a0),d0
		move.b	(v_oscillate+$E).w,d1 ; load platform-motion variable (was +$E)
		neg.b	d1		; reverse platform-motion
		addi.b	#$30,d1
		bra.s	type02_move
; ===========================================================================

type0B:
		move.w	objoff_34(a0),d0
		move.b	(v_oscillate+$E).w,d1 ; load platform-motion variable (was +$E)
		subi.b	#$30,d1
		bra.s	type02_move
; ===========================================================================

type06:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		neg.b	d1		; reverse platform-motion
		addi.b	#$40,d1
		bra.s	type02_move
; ===========================================================================

type02:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		subi.b	#$40,d1

type02_move:
		ext.w	d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)	; change position on y-axis
		bra.w	chgmotion
; ===========================================================================

type03:
		tst.w	objoff_3A(a0)	; is time delay	set?
		bne.s	.type03_wait	; if yes, branch
		btst	#3,obStatus(a0)	; is Sonic standing on the platform?
		beq.s	.type03_nomove	; if not, branch
		move.w	#30,objoff_3A(a0)	; set time delay to 0.5	seconds

.type03_nomove:
		rts

.type03_wait:
		subq.w	#1,objoff_3A(a0)	; subtract 1 from time
		bne.s	.type03_nomove	; if time is > 0, branch
		move.w	#32,objoff_3A(a0)
		addq.b	#1,obSubtype(a0) ; change to type 04 (falling)
		rts
; ===========================================================================

type04:
		tst.w	objoff_3A(a0)
		beq.s	loc_8A2E
		subq.w	#1,objoff_3A(a0)
		bne.s	loc_8A2E
		btst	#3,obStatus(a0)
		beq.s	loc_8A28
		lea	(v_player).w,a1
		bset	#1,obStatus(a1)
		bclr	#3,obStatus(a1)
		move.b	#2,obRoutine(a1)
		bclr	#3,obStatus(a0)
		clr.b	ob2ndRout(a0)
		move.w	obVelY(a0),obVelY(a1)

loc_8A28:
		move.b	#6,obRoutine(a0)

loc_8A2E:
		move.l	objoff_2C(a0),d3
		move.w	obVelY(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d3
		move.l	d3,objoff_2C(a0)
		addi.w	#$38,obVelY(a0)
		move.w	($FFFFEECE).w,d0
		addi.w	#$E0,d0
		cmp.w	objoff_2C(a0),d0
		bhs.s	+
		move.b	#4,obRoutine(a0)
+		rts
; ===========================================================================

type07:
		tst.w	objoff_3A(a0)	; is time delay	set?
		bne.s	.type07_wait	; if yes, branch
		lea	(f_switch).w,a2	; load switch statuses
		moveq	#0,d0
		move.b	obSubtype(a0),d0 ; move object type ($x7) to d0
		lsr.w	#4,d0		; divide d0 by 8, round	down
		tst.b	(a2,d0.w)	; has switch no. d0 been pressed?
		beq.s	.type07_nomove	; if not, branch
		move.w	#60,objoff_3A(a0)	; set time delay to 1 second

.type07_nomove:
		rts

.type07_wait:
		subq.w	#1,objoff_3A(a0)	; subtract 1 from time delay
		bne.s	.type07_nomove	; if time is > 0, branch
		addq.b	#1,obSubtype(a0) ; change to type 08
		rts
; ===========================================================================

type08:
		subq.w	#2,objoff_2C(a0)	; move platform	up
		move.w	objoff_34(a0),d0
		subi.w	#$200,d0
		cmp.w	objoff_2C(a0),d0	; has platform moved $200 pixels?
		bne.s	.type08_nostop	; if not, branch
		clr.b	obSubtype(a0)	; change to type 00 (stop moving)

.type08_nostop:
		rts
; ===========================================================================

type0A:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		subi.b	#$40,d1
		ext.w	d1
		asr.w	#1,d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)	; change position on y-axis
		bra.w	chgmotion
; ===========================================================================

type0D:
		move.w	objoff_34(a0),d0
		move.b	obAngle(a0),d1	; load platform-motion variable
		neg.b	d1
		addi.b	#$40,d1
		ext.w	d1
		asr.w	#1,d1
		add.w	d1,d0
		move.w	d0,objoff_2C(a0)	; change position on y-axis

chgmotion:
		move.b	(v_oscillate+$1A).w,obAngle(a0) ; (was $1A)
		rts
; ===========================================================================
Map_Obj18x:	dc.w word_8ADE-Map_Obj18x
		dc.w word_8AF0-Map_Obj18x
word_8ADE:	dc.w 2
		dc.w $F40B,  $3C,  $1E,$FFE8; 0
		dc.w $F40B,  $48,  $24,	   0; 4
word_8AF0:	dc.w $A
		dc.w $F40F,  $CA,  $65,$FFE0; 0
		dc.w  $40F,  $DA,  $6D,$FFE0; 4
		dc.w $240F,  $DA,  $6D,$FFE0; 8
		dc.w $440F,  $DA,  $6D,$FFE0; 12
		dc.w $640F,  $DA,  $6D,$FFE0; 16
		dc.w $F40F, $8CA, $865,	   0; 20
		dc.w  $40F, $8DA, $86D,	   0; 24
		dc.w $240F, $8DA, $86D,	   0; 28
		dc.w $440F, $8DA, $86D,	   0; 32
		dc.w $640F, $8DA, $86D,	   0; 36
Map_Obj18:	dc.w word_8B46-Map_Obj18
		dc.w word_8B68-Map_Obj18
word_8B46:	dc.w 4
		dc.w $F40B,  $3B,  $1D,$FFE0; 0
		dc.w $F407,  $3F,  $1F,$FFF8; 4
		dc.w $F407,  $3F,  $1F,	   8; 8
		dc.w $F403,  $47,  $23,	 $18; 12
word_8B68:	dc.w $A
		dc.w $F40F,  $C5,  $62,$FFE0; 0
		dc.w  $40F,  $D5,  $6A,$FFE0; 4
		dc.w $240F,  $D5,  $6A,$FFE0; 8
		dc.w $440F,  $D5,  $6A,$FFE0; 12
		dc.w $640F,  $D5,  $6A,$FFE0; 16
		dc.w $F40F, $8C5, $862,	   0; 20
		dc.w  $40F, $8D5, $86A,	   0; 24
		dc.w $240F, $8D5, $86A,	   0; 28
		dc.w $440F, $8D5, $86A,	   0; 32
		dc.w $640F, $8D5, $86A,	   0; 36
		dc.w	 2,    3,$F60B,	 $49; 40
		dc.w   $24,$FFE0,$F607,	 $51; 44
		dc.w   $28,$FFF8,$F60B,	 $55; 48
		dc.w   $2A,    8,    2,	   2; 52
		dc.w $F80F,  $21,  $10,$FFE0; 56
		dc.w $F80F,  $21,  $10,	   0; 60
Map_Obj18_EHZ:	dc.w word_8BEE-Map_Obj18_EHZ
		dc.w word_8C00-Map_Obj18_EHZ
word_8BEE:	dc.w 2
		dc.w $F40F,  $56,  $2B,$FFE0; 0
		dc.w $F40F, $856, $82B,	   0; 4
word_8C00:	dc.w 8
		dc.w $F407,   $A,    5,$FFE0; 0
		dc.w $F40D,  $12,    9,$FFF0; 4
		dc.w  $40D,  $1A,   $D,$FFF0; 8
		dc.w $F407,  $22,  $11,	 $10; 12
		dc.w $140F,  $2A,  $15,$FFE0; 16
		dc.w $140F, $82A, $815,	   0; 20
		dc.w $340F,  $3A,  $1D,$FFE0; 24
		dc.w $340F, $83A, $81D,	   0; 28
