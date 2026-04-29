; ---------------------------------------------------------------------------
; Object 40 - GHZ Motobug
; ---------------------------------------------------------------------------

MotoBug:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	MotoBug_Index(pc,d0.w),d1
		jmp	MotoBug_Index(pc,d1.w)
; ===========================================================================
MotoBug_Index:
		dc.w MotoBug_Init-MotoBug_Index		; 0
		dc.w MotoBug_Main-MotoBug_Index		; 2
		dc.w MotoBug_Animate-MotoBug_Index	; 4
		dc.w DeleteObject-MotoBug_Index		; 6 ; We can reach it directly. If it ever goes out of range,
	;	dc.w MotoBug_Delete-MotoBug_Index	; 6 ; Swap the above line with this
; ===========================================================================

MotoBug_Init:
		move.l	#Map_obj40,obMap(a0)
		move.w	#make_art_tile(ArtTile_Moto_Bug,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$14,obActWid(a0)
		tst.b	obAnim(a0)
		bne.s	MotoBug_Smoke
		move.b	#$E,obHeight(a0)
		move.b	#8,obWidth(a0)
		move.b	#$C,obColType(a0)
		bsr.w	ObjectMoveAndFall
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)
		bchg	#0,obStatus(a0)
.return:	rts
; ===========================================================================

MotoBug_Smoke:
		addq.b	#4,obRoutine(a0)
MotoBug_Animate:
		lea	Ani_MotoBug(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================

MotoBug_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	.secondary_index(pc,d0.w),d1
		jsr	.secondary_index(pc,d1.w)
		lea	Ani_MotoBug(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
.secondary_index:
		dc.w MotoBug_Move-.secondary_index	; 0
		dc.w MotoBug_Floor-.secondary_index	; 2
; ===========================================================================

MotoBug_Move:
		subq.w	#1,objoff_30(a0)		; is Motobug still?
		bpl.s	.return				; if so, branch
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$100,obVelX(a0)
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================

MotoBug_Floor:
		bsr.w	ObjectMove
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	MotoBug_StopMoving
		cmpi.w	#$C,d1
		bge.s	MotoBug_StopMoving
		add.w	d1,obY(a0)
		subq.b	#1,objoff_33(a0)
		bpl.s	.return
		move.b	#15,objoff_33(a0)
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_Obj40,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#2,obAnim(a1)
.return:	rts
; ===========================================================================

MotoBug_StopMoving:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,objoff_30(a0)	; set pause time to 1 second
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		rts
; ===========================================================================

; MotoBug_Delete:
	;	bra.w	DeleteObject
; ===========================================================================
Ani_MotoBug:	dc.w byte_F386-Ani_MotoBug
		dc.w byte_F389-Ani_MotoBug
		dc.w byte_F38F-Ani_MotoBug
byte_F386:	dc.b  $F,  2,afEnd
byte_F389:	dc.b   7,  0,  1,  0,  2,afEnd
byte_F38F:	dc.b   1,  3,  6,  3,  6,  4,  6,  4
		dc.b   6,  4,  6,  5,afRoutine
		even