; ---------------------------------------------------------------------------
; Object 1C - scenery (GHZ/HTZ bridge stump, SLZ lava thrower, HPZ Bridge)
; ---------------------------------------------------------------------------

Obj1C:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj1C_Index(pc,d0.w),d1
		jmp	Obj1C_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj1C_Index:	dc.w loc_93F4-Obj1C_Index
		dc.w loc_9442-Obj1C_Index
		dc.w loc_9464-Obj1C_Index
Obj1C_Conf:	dc.l Map_obj11_HPZ
		dc.w make_art_tile(ArtTile_HPZ_Bridge,3,0)
		dc.b	3,	4,	1,	0
		dc.l Map_Obj1C_01
		dc.w make_art_tile($35A,3,1)
		dc.b	0,	$10,	1,	0
		dc.l Map_obj11
		dc.w make_art_tile($3C6,2,0)
		dc.b	1,	4,	1,	0
		dc.l Map_obj11_GHZ
		dc.w make_art_tile($4C6,2,0)
		dc.b	1,	$10,	1,	0
		dc.l Map_Obj16
		dc.w make_art_tile(ArtTile_HtzZipline,2,0)
		dc.b	1,	8,	4,	0
		dc.l Map_Obj16
		dc.w make_art_tile(ArtTile_HtzZipline,2,0)
		dc.b	2,	8,	4,	0
; ---------------------------------------------------------------------------

loc_93F4:
		addq.b	#2,obRoutine(a0)
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		move.w	d0,d1
		lsl.w	#3,d0
		add.w	d1,d0
		add.w	d1,d0
		lea	Obj1C_Conf(pc,d0.w),a1
		move.l	(a1)+,obMap(a0)
		move.w	(a1)+,obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	(a1)+,obFrame(a0)
		move.b	(a1)+,obActWid(a0)
		move.b	(a1)+,obPriority(a0)
		move.b	obPriority(a0),d0	; Priority is manually converted here
		lsr.w	#1,d0		; as otherwise this would be a convoluted mess
		andi.w	#$380,d0
		move.w	d0,obPriority(a0)
		move.b	(a1)+,obColType(a0)
		move.b	obSubtype(a0),d0	; we gotta process subtype one more time!
		andi.w	#$F0,d0
		beq.s	loc_9442
		addq.b	#2,obRoutine(a0)
		lsr.b	#4,d0
		subq.b	#1,d0
		move.b	d0,obAnim(a0)
		; fall through to the next subroutine
; ---------------------------------------------------------------------------
loc_9464:	lea	Ani_Obj1C(pc),a1
		bsr.w	AnimateSprite
loc_9442:	out_of_range.w	DeleteObject
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Ani_Obj1C:	dc.w byte_9494-Ani_Obj1C
		dc.w byte_949C-Ani_Obj1C
byte_9494:	dc.b   8,  3,  3,  4,  5,  5,  4,$FF
byte_949C:	dc.b   5,  0,  0,  0,  1,  2,  3,  3
		dc.b   2,  1,  2,  3,  3,  1,$FF
		even