; ---------------------------------------------------------------------------
; Object 42 - GHZ Newtron badnik
; ---------------------------------------------------------------------------

Obj42:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj42_Index(pc,d0.w),d1
		jmp	Obj42_Index(pc,d1.w)
; ===========================================================================
Obj42_Index:
		dc.w Obj42_Init-Obj42_Index	; 0
		dc.w Obj42_Main-Obj42_Index	; 2
		dc.w Obj42_Vanish-Obj42_Index	; 4
; ===========================================================================

Obj42_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj42,obMap(a0)
		move.w	#make_art_tile(ArtTile_Newtron,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$14,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#8,obWidth(a0)
; loc_EC00:
Obj42_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj42_Main_Index(pc,d0.w),d1
		jsr	Obj42_Main_Index(pc,d1.w)
		lea	Ani_obj42(pc),a1
		bsr.w	AnimateSprite	; If green, go to Vanish next time (animation flag afRoutine ensures this)
		bra.w	MarkObjGone
; ===========================================================================
Obj42_Main_Index:
		dc.w Obj42_ChkDistance-Obj42_Main_Index	; 0
		dc.w Obj42_Type00-Obj42_Main_Index	; 2
		dc.w Obj42_ChkFloor-Obj42_Main_Index	; 4
		dc.w Obj42_Type02-Obj42_Main_Index	; 6
; ===========================================================================
; loc_EC26:
Obj42_ChkDistance:
		bset	#0,obStatus(a0)
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bhs.s	+
		neg.w	d0
		bclr	#0,obStatus(a0)
+
		cmpi.w	#$80,d0
		bhs.s	.return
		addq.b	#2,ob2ndRout(a0)
		move.b	#1,obAnim(a0)
		tst.b	obSubtype(a0)
		beq.s	.return
		move.w	#make_art_tile(ArtTile_Newtron,1,0),obGfx(a0)
		move.b	#6,ob2ndRout(a0)
		move.b	#3,obAnim(a0)
.return:	rts
; ===========================================================================
; Blue Newtron that appears before chasing Sonic/Tails
; loc_EC6C:
Obj42_Type00:
		cmpi.b	#4,obFrame(a0)
		bhs.s	Obj42_Fall
		bset	#0,obStatus(a0)
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bhs.s	.return
		bclr	#0,obStatus(a0)
.return:	rts
; ---------------------------------------------------------------------------
; loc_EC8C:
Obj42_Fall:
		cmpi.b	#1,obFrame(a0)
		bne.s	+
		move.b	#$C,obColType(a0)
+
		bsr.w	ObjectMoveAndFall
		bsr.w	ObjHitFloor
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,ob2ndRout(a0)
		move.b	#2,obAnim(a0)
		move.b	#$D,obColType(a0)
		move.w	#$200,obVelX(a0)
		btst	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================
; loc_ECE0:
Obj42_ChkFloor:
		bsr.w	ObjectMove
		bsr.w	ObjHitFloor
		cmpi.w	#-8,d1
		blt.s	.return	; Change to ObjectMove and it'll speed up
		cmpi.w	#$C,d1
		bge.s	.return	; Change to ObjectMove and it'll speed up
		add.w	d1,obY(a0)
.return:	rts
; ===========================================================================
; Green Newtron that fires a missile
; loc_ED06:
Obj42_Type02:
		cmpi.b	#1,obFrame(a0)
		bne.s	Obj42_FireMissile
		move.b	#$C,obColType(a0)
; loc_ED14:
Obj42_FireMissile:
		cmpi.b	#2,obFrame(a0)
		bne.s	.return
		tst.b	objoff_32(a0)
		bne.s	.return
		move.b	#1,objoff_32(a0)
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_Obj23,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		subq.w	#8,obY(a1)
		move.w	#$200,obVelX(a1)
		move.w	#20,d0
		btst	#0,obStatus(a0)
		bne.s	+
		neg.w	d0
		neg.w	obVelX(a1)
+
		add.w	d0,obX(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#1,obSubtype(a1)
.return:	rts
; ===========================================================================
; loc_ED6E:
Obj42_Vanish:
		clr.b	obColType(a0)	; Set as intangible
		bra.w	MarkObjGone
; ===========================================================================
Ani_obj42:	dc.w ani_newt_blank-Ani_obj42
		dc.w ani_newt_drop-Ani_obj42
		dc.w ani_newt_fly-Ani_obj42
		dc.w ani_newt_firing-Ani_obj42
ani_newt_blank:	dc.b  $F,  8,afEnd
ani_newt_drop:	dc.b $13,  0,  1,  3,  4,  5, afBack,  1
ani_newt_fly:	dc.b   2,  6,  7, afEnd
ani_newt_firing:dc.b $13,  0,  1,  1,  2,  1,  1,  0,  8, afRoutine
		even