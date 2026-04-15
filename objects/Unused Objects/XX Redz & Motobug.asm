; ---------------------------------------------------------------------------
; Object 40 - MotoBug / Redz (fused)
; subtype 0 = MotoBug (GHZ)
; subtype 1 = Redz (HPZ)
; ---------------------------------------------------------------------------

MotoBug:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	MotoBug_Index(pc,d0.w),d1
		jmp	MotoBug_Index(pc,d1.w)
; ===========================================================================
MotoBug_Index:
		dc.w MotoBug_Init-MotoBug_Index
		dc.w MotoBug_Main-MotoBug_Index
		dc.w MotoBug_Animate-MotoBug_Index	; smoke child only
		dc.w MotoBug_Delete-MotoBug_Index
; ===========================================================================

MotoBug_Init:
		tst.b	obSubtype(a0)			; MotoBug or Redz?
		bne.s	.redz
		; MotoBug-specific init
		move.l	#Map_obj40,obMap(a0)
		move.w	#make_art_tile(ArtTile_Moto_Bug,0,0),obGfx(a0)
		move.b	#$14,obActWid(a0)
		move.b	#$E,obHeight(a0)
		move.b	#8,obWidth(a0)
		bra.s	.shared
.redz:
		; Redz-specific init
		move.l	#Map_Redz,obMap(a0)
		move.w	#make_art_tile(ArtTile_Redz,0,0),obGfx(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#6,obWidth(a0)
.shared:
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$C,obColType(a0)
		tst.b	obAnim(a0)			; is this a smoke child object?
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

MotoBug_Smoke:					; smoke child object - MotoBug only
		addq.b	#4,obRoutine(a0)		; skip to MotoBug_Animate
MotoBug_Animate:
		lea	Ani_MotoBug(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================

MotoBug_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	MotoBug_Main_Index(pc,d0.w),d1
		jsr	MotoBug_Main_Index(pc,d1.w)
		tst.b	obSubtype(a0)			; MotoBug or Redz?
		bne.s	.redz
		lea	Ani_MotoBug(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
.redz:		lea	Ani_Redz(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
MotoBug_Main_Index:
		dc.w MotoBug_Move-MotoBug_Main_Index
		dc.w MotoBug_Floor-MotoBug_Main_Index
; ===========================================================================

MotoBug_Move:
		subq.w	#1,objoff_30(a0)		; is object paused?
		bpl.s	.return				; if so, branch
		addq.b	#2,ob2ndRout(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0		; 0=MotoBug, 1=Redz
		neg.b	d0				; 0?0, 1?$FF
		andi.b	#$80,d0				; 0?0, $FF?$80
		move.w	#-$100,obVelX(a0)		; base: MotoBug speed
		add.w	d0,obVelX(a0)			; Redz: -$100+$80=-$80; MotoBug: no change
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
		tst.b	obSubtype(a0)			; is this a Redz? (no smoke)
		bne.s	.return
		subq.b	#1,objoff_33(a0)		; countdown to next smoke puff
		bpl.s	.return
		move.b	#15,objoff_33(a0)		; reset counter
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_Obj40,obID(a1)		; spawn smoke child (subtype 0, obAnim will be set to 2)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#2,obAnim(a1)
.return:	rts
; ---------------------------------------------------------------------------

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
byte_F386:	dc.b  $F,  2,afEnd
byte_F389:	dc.b   7,  0,  1,  0,  2,afEnd
byte_F38F:	dc.b   1,  3,  6,  3,  6,  4,  6,  4
		dc.b   6,  4,  6,  5,afRoutine
		even

Ani_Redz:	dc.w byte_Redz0-Ani_Redz
		dc.w byte_Redz1-Ani_Redz
byte_Redz0:	dc.b   9,  1,afEnd
byte_Redz1:	dc.b   9,  0,  1,  2,  1,afEnd
		even