; ---------------------------------------------------------------------------
; Object 1D - Horizontal Ball Hog enemy
; ---------------------------------------------------------------------------

ObjHBallhog:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Hog_Index(pc,d0.w),d1
		jmp	Hog_Index(pc,d1.w)
; ===========================================================================
Hog_Index:	dc.w Hog_Main-Hog_Index
		dc.w Hog_Horizontal-Hog_Index
hog_launchflag	= objoff_30	; byte; 0 to launch a cannonball
; ===========================================================================

Hog_Main:	; Routine 0
		move.l	#Map_BallHogH,obMap(a0)
		move.w	#make_art_tile(ArtTile_Ball_HogH,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#4,obPriority(a0)
		move.b	#5,obColType(a0)
		move.b	#$C,obActWid(a0)
		move.b	#$13,obHeight(a0)
		move.b	#8,obWidth(a0)
		bsr.w	ObjectMoveAndFall
		jsr	(ObjHitFloor).l	; find floor
		tst.w	d1
		bpl.s	.floornotfound
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0) ; HogVertical

.floornotfound:
		rts
; ===========================================================================

Hog_Horizontal:	; Routine 4
		lea	Ani_HogHoriz(pc),a1
		bsr.w	AnimateSprite
		cmpi.b	#1,obFrame(a0)	; is final frame (01) displayed?
		bne.s	.setlaunchflag	; if not, branch
		tst.b	hog_launchflag(a0)	; is it	set to launch cannonball?
		beq.s	.makeball	; if yes, branch
		bra.w	MarkObjGone
.setlaunchflag:
		sf	hog_launchflag(a0)	; set to launch	cannonball
		bra.w	MarkObjGone
; ===========================================================================

.makeball:
		st	hog_launchflag(a0)
		bsr.w	FindFreeObj
		bne.s	.fail
		_move.b	#id_Obj20,obID(a1) ; load cannonball object ($20)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#-$100,obVelX(a1) ; cannonball bounces to the left
		clr.w	obVelY(a1)
		moveq	#-4,d0
		btst	#0,obStatus(a0)	; is Ball Hog facing right?
		beq.s	.noflip		; if not, branch
		neg.w	d0
		neg.w	obVelX(a1)	; cannonball bounces to	the right

.noflip:
		add.w	d0,obX(a1)
		addi.w	#$C,obY(a1)
		move.b	obSubtype(a0),obSubtype(a1) ; copy object type from Ball Hog

.fail:
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
Ani_HogHoriz:	dc.w .frame1-Ani_HogHoriz
.frame1:	dc.b   9,  0,  0,  2,  2,  3,  2,  0
		dc.b   0,  2,  2,  3,  2,  0,  0,  2
		dc.b   2,  3,  2,  0,  0,  1, afEnd
		even