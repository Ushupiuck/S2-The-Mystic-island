; ---------------------------------------------------------------------------
; Object 53 - Masher from EHZ
; ---------------------------------------------------------------------------

Obj53:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj53_Index(pc,d0.w),d1
		jsr	Obj53_Index(pc,d1.w)
		jmp	(MarkObjGone).l
; ===========================================================================
Obj53_Index:	dc.w Obj53_Init-Obj53_Index
		dc.w Obj53_Main-Obj53_Index
mash_origY = objoff_30
; ===========================================================================

Obj53_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj53,obMap(a0)
		move.w	#make_art_tile(ArtTile_Masher,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#4,obPriority(a0)
		move.b	#9,obColType(a0)
		move.b	#$10,obActWid(a0)
		move.w	#-$400,obVelY(a0) ; set vertical speed
		move.w	obY(a0),mash_origY(a0) ; save original position

Obj53_Main:
		lea	(Ani_obj53).l,a1
		jsr	(AnimateSprite).l
		jsr	(ObjectMove).l
		addi.w	#$18,obVelY(a0)	; reduce speed
		move.w	chop_origY(a0),d0
		cmp.w	obY(a0),d0	; has Chopper returned to its original position?
		bcc.s	.chganimation	; if not, branch
		move.w	d0,obY(a0)
		move.w	#-$500,obVelY(a0) ; set vertical speed

.chganimation:
		move.b	#1,obAnim(a0)	; use fast animation
		subi.w	#$C0,d0
		cmp.w	obY(a0),d0
		bcc.s	.nochg
		move.b	#0,obAnim(a0)	; use slow animation
		tst.w	obVelY(a0)	; is Chopper at	its highest point?
		bmi.s	.nochg		; if not, branch
		move.b	#2,obAnim(a0)	; use stationary animation

.nochg:
		rts
