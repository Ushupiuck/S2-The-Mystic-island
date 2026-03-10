; ---------------------------------------------------------------------------
; Object 5E - HTZ see-saw
; ---------------------------------------------------------------------------

Obj5E:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj5E_Index(pc,d0.w),d1
		jsr	Obj5E_Index(pc,d1.w)
		out_of_range.w	DeleteObject,objoff_30(a0)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Obj5E_Index:	dc.w See_Main-Obj5E_Index
		dc.w See_Slope-Obj5E_Index
		dc.w loc_14F10.return-Obj5E_Index
		dc.w See_Spikeball-Obj5E_Index
		dc.w See_MoveSpike-Obj5E_Index
		dc.w See_SpikeFall-Obj5E_Index
; ---------------------------------------------------------------------------

See_Main:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj5E,obMap(a0)
		move.w	#make_art_tile(ArtTile_HTZ_Seesaw,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$30,obActWid(a0)
		move.w	obX(a0),objoff_30(a0)
		tst.b	obSubtype(a0)	; is object type 00 ?
		bne.s	.noball		; if not, branch

		bsr.w	FindNextFreeObj
		bne.s	.noball
		_move.b	#id_Obj5E,obID(a1)	; load spikeball object
		addq.b	#6,obRoutine(a1)	; use See_Spikeball routine
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.l	a0,objoff_3C(a1)

.noball:
		btst	#0,obStatus(a0)	; is seesaw flipped?
		beq.s	.noflip		; if not, branch
		move.b	#2,obFrame(a0)	; use different frame

.noflip:
		move.b	obFrame(a0),objoff_3A(a0)

See_Slope:
		move.b	objoff_3A(a0),d1
		btst	#3,obStatus(a0) ; p1_standing_bit
		beq.s	loc_14D9A
		moveq	#2,d1
		lea	(v_player).w,a1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bhs.s	+
		neg.w	d0
		moveq	#0,d1
+
		cmpi.w	#8,d0
		bhs.s	+
		moveq	#1,d1
+
		btst	#4,obStatus(a0) ; p2_standing_bit
		beq.s	See_ChgFrame
		moveq	#2,d2
		lea	(v_player2).w,a1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bhs.s	+
		neg.w	d0
		moveq	#0,d2
+
		cmpi.w	#8,d0
		bhs.s	+
		moveq	#1,d2
+
		add.w	d2,d1
		cmpi.w	#3,d1
		bne.s	+
		addq.w	#1,d1
+
		lsr.w	#1,d1
		bra.s	See_ChgFrame
; ---------------------------------------------------------------------------

loc_14D9A:
		btst	#4,obStatus(a0) ; p2_standing_bit
		beq.s	See_StoodOn
		moveq	#2,d1
		lea	(v_player2).w,a1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bhs.s	+
		neg.w	d0
		moveq	#0,d1
+
		cmpi.w	#8,d0
		bhs.s	See_ChgFrame
		moveq	#1,d1
		bra.s	See_ChgFrame
; ===========================================================================
See_StoodOn:
		move.w	(v_player+obVelY).w,d0
		move.w	(v_player2+obVelY).w,d2
		cmp.w	d0,d2
		blt.s	+
		move.w	d2,d0
+
		move.w	d0,objoff_38(a0)


See_ChgFrame:
		move.b	obFrame(a0),d0
		cmp.b	d1,d0		; does frame need to change?
		beq.s	.noflip		; if not, branch
		bhs.s	.reduce_frame
		addq.b	#2,d0

.reduce_frame:
		subq.b	#1,d0
		move.b	d0,obFrame(a0)
		move.b	d1,objoff_3A(a0)
		bclr	#0,obRender(a0)
		btst	#1,obFrame(a0)
		beq.s	.noflip
		bset	#0,obRender(a0)

.noflip:
		lea	See_DataSlope(pc),a2
		btst	#0,obFrame(a0)
		beq.s	+
		lea	See_DataFlat(pc),a2
+
		move.w	obX(a0),-(sp)
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#8,d3
		move.w	(sp)+,d4
		bra.w	SlopedPlatform
; End of function See_ChgFrame

; ---------------------------------------------------------------------------

See_Spikeball:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj5Eb,obMap(a0)
		move.w	#make_art_tile(ArtTile_HTZ_Seesaw,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$8B,obColType(a0)
		move.b	#$C,obActWid(a0)
		move.w	obX(a0),objoff_30(a0)
		addi.w	#$28,obX(a0)
		addi.w	#$10,obY(a0)
		move.w	obY(a0),objoff_34(a0)
		move.b	#1,obFrame(a0)
		btst	#0,obStatus(a0)
		beq.s	See_MoveSpike
		subi.w	#$50,obX(a0)
		move.b	#2,objoff_3A(a0)

See_MoveSpike:
		movea.l	objoff_3C(a0),a1
		moveq	#0,d0
		move.b	objoff_3A(a0),d0
		sub.b	objoff_3A(a1),d0
		beq.s	loc_14EF2
		bhs.s	loc_14EB0
		neg.b	d0

loc_14EB0:
		move.w	#-$818,d1
		move.w	#-$114,d2
		cmpi.b	#1,d0
		beq.s	loc_14ED6
		move.w	#-$AF0,d1
		move.w	#-$CC,d2
		cmpi.w	#$A00,objoff_38(a1)
		blt.s	loc_14ED6
		move.w	#-$E00,d1
		move.w	#-$A0,d2

loc_14ED6:
		move.w	d1,obVelY(a0)
		move.w	d2,obVelX(a0)
		move.w	obX(a0),d0
		sub.w	objoff_30(a0),d0
		bhs.s	+
		neg.w	obVelX(a0)
+
		addq.b	#2,obRoutine(a0)
		; fall through
; ---------------------------------------------------------------------------

See_SpikeFall:
		tst.w	obVelY(a0)
		bpl.s	loc_14F4E
		jsr	(ObjectMoveAndFall).l
		move.w	objoff_34(a0),d0
		subi.w	#$2F,d0
		cmp.w	obY(a0),d0
		bgt.s	loc_14F10.return
		jmp	(ObjectMoveAndFall).l
; ---------------------------------------------------------------------------

loc_14EF2:
		lea	See_YPos(pc),a2
		moveq	#0,d0
		move.b	obFrame(a1),d0
		move.w	#$28,d2
		move.w	obX(a0),d1
		sub.w	objoff_30(a0),d1
		bhs.s	loc_14F10
		neg.w	d2
		addq.w	#2,d0

loc_14F10:
		add.w	d0,d0
		move.w	objoff_34(a0),d1
		add.w	(a2,d0.w),d1
		move.w	d1,obY(a0)
		add.w	objoff_30(a0),d2
		move.w	d2,obX(a0)
		clr.w	obXSub(a0)	; x_sub/obXSub
		clr.w	obYSub(a0)	; y_sub/obYSub
.return:	rts
; ---------------------------------------------------------------------------

loc_14F4E:
		jsr	(ObjectMoveAndFall).l
		movea.l	objoff_3C(a0),a1
		lea	See_YPos(pc),a2
		moveq	#0,d0
		move.b	obFrame(a1),d0
		move.w	obX(a0),d1
		sub.w	objoff_30(a0),d1
		bhs.s	loc_14F6E
		addq.w	#2,d0

loc_14F6E:
		add.w	d0,d0
		move.w	objoff_34(a0),d1
		add.w	(a2,d0.w),d1
		cmp.w	obY(a0),d1
		bgt.s	loc_14F10.return
		movea.l	objoff_3C(a0),a1
		moveq	#2,d1
		tst.w	obVelX(a0)
		bmi.s	loc_14F8C
		moveq	#0,d1

loc_14F8C:
		move.b	d1,objoff_3A(a1)
		move.b	d1,objoff_3A(a0)
		cmp.b	obFrame(a1),d1
		beq.s	loc_14FB6
		lea	(v_player).w,a2
		bclr	#3,obStatus(a1)
		beq.s	loc_14FA8
		bsr.s	sub_14FC4

loc_14FA8:
		lea	(v_player2).w,a2
		bclr	#4,obStatus(a1)
		beq.s	loc_14FB6
		bsr.s	sub_14FC4

loc_14FB6:
		clr.w	obVelX(a0)
		clr.w	obVelY(a0)
		subq.b	#2,obRoutine(a0)
		rts

; =============== S U B R O U T I N E =======================================


sub_14FC4:
		move.w	obVelY(a0),obVelY(a2)
		neg.w	obVelY(a2)
		bset	#1,obStatus(a2)
		bclr	#3,obStatus(a2)
		clr.b	objoff_3C(a2)
		move.b	#$10,obAnim(a2)
		move.b	#2,obRoutine(a2)
		move.w	#sfx_Spring,d0
		jmp	(PlaySound_Special).l
; End of function sub_14FC4

; ---------------------------------------------------------------------------
See_YPos:	dc.w	 -8,  -$1C,  -$2F,  -$1C,    -8	; 0
See_DataSlope:	dc.b  $14, $14,	$16, $18, $1A, $1C, $1A	; 0
		dc.b  $18, $16,	$14, $13, $12, $11, $10	; 7
		dc.b   $F,  $E,	 $D,  $C,  $B,	$A,   9	; 14
		dc.b	8,   7,	  6,   5,   4,	 3,   2	; 21
		dc.b	1,   0,	 -1,  -2,  -3,	-4,  -5	; 28
		dc.b   -6,  -7,	 -8,  -9, -$A, -$B, -$C	; 35
		dc.b  -$D, -$E,	-$E, -$E, -$E, -$E, -$E	; 42
See_DataFlat:	dc.b	5,   5,	  5,   5,   5,	 5,   5	; 0
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 7
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 14
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 21
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 28
		dc.b	5,   5,	  5,   5,   5,	 5,   5	; 35
		dc.b	5,   5,	  5,   5,   5,	 5,   0	; 42
		even