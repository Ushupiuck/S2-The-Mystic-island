; =============== S U B R O U T I N E =======================================


SmashObject:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		add.w	d0,d0
		movea.l	obMap(a0),a3
		adda.w	(a3,d0.w),a3	; put address of appropriate frame to a3
		move.w	(a3)+,d1	; amount of pieces the frame consists of
		subq.w	#1,d1
		bset	#5,obRender(a0)
		_move.b	obID(a0),d4
		move.b	obRender(a0),d5
		movea.l	a0,a1
		bra.s	loc_C9CA
; ---------------------------------------------------------------------------

-		bsr.w	FindNextFreeObj
		bne.s	loc_CA1C
		addq.w	#8,a3	; in Sonic 3's mapping format, this is just addq.w #6,a3 due to different mapping format sizes (addq.w #5,a3 for Sonic 1)

loc_C9CA:
		move.b	#4,obRoutine(a1)
		_move.b	d4,obID(a1)
		move.l	a3,obMap(a1)
		move.b	d5,obRender(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	obPriority(a0),obPriority(a1)
		move.b	obActWid(a0),obActWid(a1)
		move.w	(a4)+,obVelX(a1)
		move.w	(a4)+,obVelY(a1)
		dbf	d1,-

loc_CA1C:
		move.w	#sfx_WallSmash,d0
		jmp	(PlaySound_Special).l
; End of function SmashObject