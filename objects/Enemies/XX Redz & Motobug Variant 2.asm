; ---------------------------------------------------------------------------
; Object 40 - Wanderers
; subtype 0 = MotoBug (GHZ)
; subtype 1 = Redz (HPZ)
; subtype 2 = Yadrin (SYZ)
; ---------------------------------------------------------------------------

Wanderer:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Wanderer_Index(pc,d0.w),d1
		jmp	Wanderer_Index(pc,d1.w)
; ===========================================================================
Wanderer_Index:
		dc.w MotoBug_Init-Wanderer_Index
		dc.w MotoBug_Main-Wanderer_Index
		dc.w Wanderer_Animate-Wanderer_Index	; smoke child only (MotoBug)
		dc.w MotoBug_Delete-Wanderer_Index
; ===========================================================================

MotoBug_Init:
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		move.w	d0,d1
		lsl.w	#3,d0				; d0*8
		add.w	d1,d0
		add.w	d1,d0				; d0*8 + d0*2 = d0*10
		lea	Wanderer_StatTable(pc,d0.w),a1
		move.l	(a1)+,obMap(a0)			; mappings
		move.w	(a1)+,obGfx(a0)			; art tile
		move.b	(a1)+,obActWid(a0)		; action width
		move.b	(a1)+,obHeight(a0)		; height
		move.b	(a1)+,obWidth(a0)		; width
		move.b	(a1)+,obColType(a0)		; collision type
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		tst.b	obAnim(a0)			; is this a smoke child?
		bne.s	MotoBug_Smoke			; if yes, branch
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
; Stat table — 10 bytes per entry (matches Scenery object layout)
; map(4), gfx(2), actWid(1), height(1), width(1), colType(1)
Wanderer_StatTable:
		dc.l Map_obj40						; MotoBug
		dc.w make_art_tile(ArtTile_Moto_Bug,0,0)
		dc.b $14, $E, 8, $C
		dc.l Map_Redz						; Redz
		dc.w make_art_tile(ArtTile_Redz,0,0)
		dc.b $10, $10, 6, $C
		dc.l Map_Yad						; Yadrin
		dc.w make_art_tile(ArtTile_Yadrin,1,0)
		dc.b $14, $11, 8, $CC
		even
; ===========================================================================

MotoBug_Smoke:					; smoke child - MotoBug only
		addq.b	#4,obRoutine(a0)	; skip to Wanderer_Animate
Wanderer_Animate:				; shared entry point
		lea	Ani_MotoBug(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================

MotoBug_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	MotoBug_Main_Index(pc,d0.w),d1
		jsr	MotoBug_Main_Index(pc,d1.w)
		; select animation table by subtype
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		move.w	Wanderer_AniIndex(pc,d0.w),d0
		lea	Wanderer_AniIndex(pc,d0.w),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
Wanderer_AniIndex:
		dc.w Ani_MotoBug-Wanderer_AniIndex	; subtype 0
		dc.w Ani_Redz-Wanderer_AniIndex		; subtype 1
		dc.w Ani_Yadrin-Wanderer_AniIndex	; subtype 2
; ===========================================================================
MotoBug_Main_Index:
		dc.w MotoBug_Move-MotoBug_Main_Index
		dc.w MotoBug_Floor-MotoBug_Main_Index
; ===========================================================================

MotoBug_Move:
		subq.w	#1,objoff_30(a0)		; is object paused?
		bpl.s	.return				; if so, branch
		addq.b	#2,ob2ndRout(a0)
		; load speed from table indexed by subtype
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		add.w	d0,d0
		move.w	Wanderer_SpeedTable(pc,d0.w),obVelX(a0)
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================
; Speed table — one word per subtype (always negative = leftward base)
Wanderer_SpeedTable:
		dc.w -$100				; MotoBug
		dc.w -$80				; Redz
		dc.w -$100				; Yadrin
; ===========================================================================

MotoBug_Floor:
		bsr.w	ObjectMove
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	MotoBug_StopMoving
		cmpi.w	#$C,d1
		bge.s	MotoBug_StopMoving
		add.w	d1,obY(a0)
		; subtype-specific floor behaviour
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		bne.s	.notmotobug			; subtype 0 only: smoke
		subq.b	#1,objoff_33(a0)		; countdown to next smoke puff
		bpl.s	.return
		move.b	#15,objoff_33(a0)
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_Obj40,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#2,obAnim(a1)
		rts

.notmotobug:
		cmpi.b	#2,d0				; subtype 2 only: Yadrin wall check
		bne.s	.return				; Redz: nothing extra
		bsr.w	ChkHitLeftRightWall		; shared wall check routine
		beq.s	.return				; no wall — keep going
		neg.w	obVelX(a0)			; wall hit — reverse
		bchg	#0,obRender(a0)
		bchg	#0,obStatus(a0)
.return:	rts
; ===========================================================================

MotoBug_StopMoving:
		subq.b	#2,ob2ndRout(a0)
		move.w	#59,objoff_30(a0)		; pause for 1 second
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		rts
; ===========================================================================

MotoBug_Delete:
		bra.w	DeleteObject
; ===========================================================================

Ani_MotoBug:	dc.w byte_F386-Ani_MotoBug
		dc.w byte_F389-Ani_MotoBug
		dc.w byte_F38F-Ani_MotoBug
byte_F386:	dc.b	$F,  2,afEnd
byte_F389:	dc.b	7,  0,  1,  0,  2,afEnd
byte_F38F:	dc.b	1,  3,  6,  3,  6,  4,  6,  4
		dc.b	6,  4,  6,  5,afRoutine
		even

Ani_Redz:	dc.w byte_Redz0-Ani_Redz
		dc.w byte_Redz1-Ani_Redz
byte_Redz0:	dc.b	9,  1,afEnd
byte_Redz1:	dc.b	9,  0,  1,  2,  1,afEnd
		even

Ani_Yadrin:	dc.w .stand-Ani_Yadrin
		dc.w .walk-Ani_Yadrin
.stand:		dc.b	7,  0,afEnd
		even
.walk:		dc.b	7,  0,  3,  1,  4,  0,  3,  2,  5,afEnd
		even