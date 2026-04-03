; ---------------------------------------------------------------------------
; Object XX - Redz (dinosaur badnik) from HPZ
; ---------------------------------------------------------------------------

Redz:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Redz_Index(pc,d0.w),d1
		jmp	Redz_Index(pc,d1.w)
; ===========================================================================
Redz_Index:
		dc.w Redz_Init-Redz_Index
		dc.w Redz_Main-Redz_Index
		dc.w Redz_Delete-Redz_Index
; ===========================================================================

Redz_Init:
		move.l	#Map_Redz,obMap(a0)
		move.w	#make_art_tile(ArtTile_Redz,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#6,obWidth(a0)
		move.b	#$C,obColType(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)
		bchg	#0,obStatus(a0)
.return:	rts
; ===========================================================================

Redz_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Redz_SubIndex(pc,d0.w),d1
		jsr	Redz_SubIndex(pc,d1.w)
		lea	Ani_Redz(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================
Redz_SubIndex:
		dc.w Redz_MoveLeft-Redz_SubIndex
		dc.w Redz_ChkFloor-Redz_SubIndex
; ===========================================================================
; loc_15E58:
Redz_MoveLeft:
		subq.w	#1,objoff_30(a0)		; is Redz not moving?
		bpl.s	.return				; if not, branch
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$80,obVelX(a0)
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================
; loc_15E7C:
Redz_ChkFloor:
		jsr	(ObjectMove).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Redz_StopMoving
		cmpi.w	#$C,d1
		bge.s	Redz_StopMoving
		add.w	d1,obY(a0)
		rts
; ---------------------------------------------------------------------------
; loc_15E98:
Redz_StopMoving:
		subq.b	#2,ob2ndRout(a0)
		move.w	#60-1,objoff_30(a0)		; pause for 1 second
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		rts
; ===========================================================================

Redz_Delete:
		jmp	(DeleteObject).l
; ===========================================================================
; animation script
Ani_Redz:	dc.w byte_15EB8-Ani_Redz
		dc.w byte_15EBB-Ani_Redz
byte_15EB8:	dc.b   9,  1,afEnd
byte_15EBB:	dc.b   9,  0,  1,  2,  1,afEnd
		even