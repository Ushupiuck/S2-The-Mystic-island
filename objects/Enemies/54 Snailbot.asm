; ===========================================================================
; ---------------------------------------------------------------------------
; Object 54 - Snail badnik from	EHZ
; ---------------------------------------------------------------------------
snail_parent		= objoff_2A	; 4 bytes; parent pointer for child objects
snail_turn_timer	= objoff_30	; 2 bytes; countdown before turning around
snail_turning		= objoff_34	; 1 byte; set while waiting to reverse; also kills flame child
snail_boosted		= objoff_35	; 1 byte; set after spotting player so boost only happens once per pass

Obj54:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj54_Index(pc,d0.w),d1
		jmp	Obj54_Index(pc,d1.w)
; ===========================================================================
Obj54_Index:	dc.w Obj54_Init-Obj54_Index
		dc.w Obj54_Move-Obj54_Index
		dc.w loc_177B4-Obj54_Index
		dc.w loc_177EC-Obj54_Index
		dc.w loc_17772-Obj54_Index
; ===========================================================================

Obj54_Init:
		move.l	#Map_obj54,obMap(a0)
		move.w	#make_art_tile(ArtTile_Snail,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$E,obWidth(a0)
		jsr	(FindNextFreeObj).l
		bne.s	loc_17670
		_move.b	#id_Obj54,obID(a1)
		move.b	#6,obRoutine(a1)
		move.l	#Map_obj54,obMap(a1)
		move.w	#make_art_tile(ArtTile_Snail,1,0),obGfx(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.l	a0,snail_parent(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#2,obFrame(a1)

loc_17670:
		addq.b	#2,obRoutine(a0)
		move.w	#-$80,d0
		btst	#0,obStatus(a0)
		beq.s	loc_17682
		neg.w	d0

loc_17682:
		move.w	d0,obVelX(a0)
		rts
; ===========================================================================
; loc_17688:
Obj54_Move:
		bsr.w	sub_176D0
		jsr	(ObjectMove).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Obj54_Display
		cmpi.w	#$C,d1
		bge.s	Obj54_Display
		add.w	d1,obY(a0)
		lea	Ani_Obj54(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
; loc_176B4:
Obj54_Display:
		addq.b	#2,obRoutine(a0)
		move.w	#$14,snail_turn_timer(a0)
		st	snail_turning(a0)
		lea	Ani_Obj54(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l

; =============== S U B R O U T I N E =======================================


sub_176D0:
		tst.b	snail_boosted(a0)
		bne.w	loc_17700.return
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		cmpi.w	#$64,d0
		bgt.w	loc_17700.return
		cmpi.w	#-$64,d0
		blt.w	loc_17700.return
		tst.w	d0
		bmi.s	loc_176F8
		btst	#0,obStatus(a0)
		beq.s	loc_17700.return
		bra.s	loc_17700
; ---------------------------------------------------------------------------

loc_176F8:
		btst	#0,obStatus(a0)
		bne.s	loc_17700.return

loc_17700:
		move.w	obVelX(a0),d0
		asl.w	#2,d0
		move.w	d0,obVelX(a0)
		st	snail_boosted(a0)
		jsr	(FindNextFreeObj).l
		bne.s	.return
		_move.b	#id_Obj54,obID(a1)
		move.b	#8,obRoutine(a1)
		move.l	#Map_obj4B,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.l	a0,snail_parent(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addq.w	#7,obY(a1)
		addi.w	#$D,obX(a1)
		move.b	#1,obAnim(a1)
.return:	rts
; End of function sub_176D0

; ---------------------------------------------------------------------------

loc_17772:
		movea.l	snail_parent(a0),a1
		cmpi.b	#id_Obj54,obID(a1)
		bne.w	loc_17854
		tst.b	snail_turning(a1)
		bne.w	loc_17854
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		addq.w	#7,obY(a0)
		moveq	#$D,d0
		btst	#0,obStatus(a0)
		beq.s	loc_177A2
		neg.w	d0

loc_177A2:
		add.w	d0,obX(a0)
		lea	(Ani_obj4B).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_177B4:
		subq.w	#1,snail_turn_timer(a0)
		bpl.s	+
		neg.w	obVelX(a0)
		jsr	(ObjectMoveAndFall).l
		move.w	obVelX(a0),d0
		asr.w	#2,d0
		move.w	d0,obVelX(a0)
		bchg	#0,obStatus(a0)
		bchg	#0,obRender(a0)
		subq.b	#2,obRoutine(a0)
		sf	snail_turning(a0)
		sf	snail_boosted(a0)
+		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

loc_177EC:
		movea.l	snail_parent(a0),a1
		cmpi.b	#id_Obj54,obID(a1)
		bne.w	loc_17854
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Ani_Obj54:	dc.w byte_17818-Ani_Obj54
		dc.w byte_1781C-Ani_Obj54
byte_17818:	dc.b   5,  0,  1,afEnd
byte_1781C:	dc.b   1,  0,  1,afEnd
		even