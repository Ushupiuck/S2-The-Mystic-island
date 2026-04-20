; ---------------------------------------------------------------------------
; Object 13 - HPZ waterfall
; ---------------------------------------------------------------------------

HPZ_Waterfall:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	HPZ_Waterfall_Index(pc,d0.w),d1
		jmp	HPZ_Waterfall_Index(pc,d1.w)
; ---------------------------------------------------------------------------
HPZ_Waterfall_Index:
		dc.w loc_1446C-HPZ_Waterfall_Index	; 0
		dc.w loc_14532-HPZ_Waterfall_Index	; 2
		dc.w loc_14584-HPZ_Waterfall_Index	; 4
; ---------------------------------------------------------------------------

loc_1446C:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Waterfall2,obMap(a0)
		move.w	#make_art_tile(ArtTile_HPZ_Waterfall,3,1),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$80,obPriority(a0)
		move.b	#$12,obFrame(a0)

		jsr	(FindNextFreeObj).l
		bne.w	loc_1459C.return
		_move.b	#id_Obj1E,obID(a1)
	;	_move.b	obID(a0),obID(a1)
		addq.b	#4,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_Waterfall2,obMap(a1)
		move.w	#make_art_tile(ArtTile_HPZ_Waterfall,3,1),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$80,obPriority(a1)
		move.b	#$A0,obHeight(a1)
		bset	#4,obRender(a1)

		move.l	a1,objoff_38(a0)
		move.w	obY(a0),objoff_34(a0)
		move.w	obY(a0),objoff_36(a0)
		cmpi.b	#$10,obSubtype(a0)
		blo.s	loc_14518

		jsr	(FindNextFreeObj).l
		bne.w	loc_1459C.return
		_move.b	#id_Obj1E,obID(a1)
	;	_move.b	obID(a0),obID(a1)
		addq.b	#4,obRoutine(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_Waterfall2,obMap(a1)
		move.w	#make_art_tile(ArtTile_HPZ_Waterfall,3,1),obGfx(a1)
		move.b	#4,obRender(a1)
		move.b	#$10,obActWid(a1)
		move.w	#$80,obPriority(a1)
		move.l	a1,objoff_3C(a0)
		move.w	obY(a0),obY(a1)
		addi.w	#$98,obY(a1)

loc_14518:
		moveq	#0,d1
		move.b	obSubtype(a0),d1
		move.w	objoff_34(a0),d0
		subi.w	#$78,d0
		lsl.w	#4,d1
		add.w	d1,d0
		move.w	d0,obY(a0)
		move.w	d0,objoff_34(a0)

loc_14532:
		movea.l	objoff_38(a0),a1
		move.b	#$12,obFrame(a0)
		move.w	objoff_34(a0),d0
		move.w	(v_waterpos1).w,d1
		cmp.w	d0,d1
		bhs.s	loc_1454A
		move.w	d1,d0

loc_1454A:
		move.w	d0,obY(a0)
		sub.w	objoff_36(a0),d0
		addi.w	#$80,d0
		bmi.s	loc_1459C
		lsr.w	#4,d0
		move.w	d0,d1
		cmpi.w	#$F,d0
		blo.s	loc_14564
		moveq	#$F,d0

loc_14564:
		move.b	d0,obFrame(a1)
		cmpi.b	#$10,obSubtype(a0)
		blo.s	loc_14584
		movea.l	objoff_3C(a0),a1
		subi.w	#$F,d1
		bhs.s	+
		moveq	#0,d1
+
		addi.w	#$13,d1
		move.b	d1,obFrame(a1)

loc_14584:
		out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------

loc_1459C:
		moveq	#$13,d0
		move.b	d0,obFrame(a0)
		move.b	d0,obFrame(a1)
		out_of_range.w	DeleteObject
.return:	rts