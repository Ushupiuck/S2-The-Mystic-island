; ---------------------------------------------------------------------------
; Object 1E - Vertical Ball Hog enemy
; ---------------------------------------------------------------------------

ObjVBallhog:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	PHog_Index(pc,d0.w),d1
		jmp	PHog_Index(pc,d1.w)
; ===========================================================================
PHog_Index:	dc.w PHog_Main-PHog_Index
		dc.w PHog_Vertical-PHog_Index
phog_timer =	 objoff_30	; time to idle around from left to right
phog_launchflag = objoff_32	; 0 to launch a cannonball
; ===========================================================================

PHog_Main:	; Routine 0
		move.l	#Map_BallHogV,obMap(a0)
		move.w	#make_art_tile(ArtTile_Ball_HogV,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#4,obPriority(a0)
		move.b	#5,obColType(a0)
		move.b	#$C,obActWid(a0)
		move.b	#$13,obHeight(a0)
		move.b	#8,obWidth(a0)
		bsr.w	ObjectMoveAndFall
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.floornotfound
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)

.floornotfound:
		rts
; ---------------------------------------------------------------------------

PHog_Vertical:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	.action_index(pc,d0.w),d1
		jsr	.action_index(pc,d1.w)
		lea	Ani_HogVert(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
.action_index:	dc.w Hog_Idle-.action_index
		dc.w Hog_Move-.action_index
; ===========================================================================

Hog_Idle:
		subq.w	#1,phog_timer(a0)
		bpl.s	.fire
		addq.b	#2,ob2ndRout(a0)
		move.w	#256-1,phog_timer(a0)
		move.w	#$40,obVelX(a0)
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.noflip
		neg.w	obVelX(a0)
.noflip:
		sf	phog_launchflag(a0)
		rts
; ---------------------------------------------------------------------------

.fire:
		cmpi.b	#2,obFrame(a0)
		bne.s	.abort
		tst.b	phog_launchflag(a0)
		bne.s	.abort
		st	phog_launchflag(a0)
		bsr.w	FindFreeObj
		bne.s	.abort	; if ObjectRam is full, we bail!
		_move.b	#id_Obj20,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addi.w	#$10,obY(a1)

.abort:		;.fail in the final
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------

Hog_Move:
		subq.w	#1,phog_timer(a0)
		bmi.s	loc_7032
		bsr.w	ObjectMove
		jsr	(ObjHitFloor).l
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------

loc_7032:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,phog_timer(a0)
		clr.w	obVelX(a0)
		sf	obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,obAnim(a0)

.return:
		rts
; ---------------------------------------------------------------------------
Ani_HogVert:	dc.w .frame1-Ani_HogVert
		dc.w .frame2-Ani_HogVert
		dc.w .frame3-Ani_HogVert
Ani_HogVert.frame1:	dc.b $F, 0, afEnd
		even
Ani_HogVert.frame2:	dc.b $B, 1, 0, $21, 0, afEnd
		even
Ani_HogVert.frame3:	dc.b $14, 0, 2, 0, afBack, 1
		even