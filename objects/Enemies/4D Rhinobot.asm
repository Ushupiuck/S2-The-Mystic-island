; ---------------------------------------------------------------------------
; Object 4D - Rhinobot badnik
;----------------------------------------------------------------------------

Obj4D:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4D_Index(pc,d0.w),d1
		jmp	Obj4D_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj4D_Index:
		dc.w Obj4D_Init-Obj4D_Index
		dc.w Obj4D_Main-Obj4D_Index
; ---------------------------------------------------------------------------

Obj4D_Init:
		move.l	#Map_Rhinobot,obMap(a0)
		move.w	#make_art_tile(ArtTile_Rhinobot,1,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$18,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$18,obWidth(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		clr.w	obVelY(a0)
		addq.b	#2,obRoutine(a0)
.return:	rts
; ---------------------------------------------------------------------------

Obj4D_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4D_SubIndex(pc,d0.w),d1
		jsr	Obj4D_SubIndex(pc,d1.w)
		lea	Ani_Obj4D(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj4D_SubIndex:
		dc.w loc_158FE-Obj4D_SubIndex
		dc.w loc_15922-Obj4D_SubIndex
; ---------------------------------------------------------------------------

loc_158FE:
		subq.w	#1,objoff_30(a0)
		bpl.s	.return
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$80,obVelX(a0)
		clr.b	obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_15922:
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0
		bmi.s	loc_159A0
		cmpi.w	#$60,d0
		bgt.s	.return
		btst	#0,obStatus(a0)
		bne.s	loc_15992
		move.b	#2,obAnim(a0)
		move.w	#-$200,obVelX(a0)
		jsr	(ObjectMoveAndFall).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	loc_15948
		cmpi.w	#$C,d1
		bge.s	.return
		clr.w	obVelY(a0)
		add.w	d1,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_15948:
		subq.b	#2,ob2ndRout(a0)
		move.w	#59,objoff_30(a0)
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		sub.l	d0,obX(a0)
		clr.w	obVelX(a0)
		move.b	#1,obAnim(a0)
		rts

; ---------------------------------------------------------------------------

loc_15992:
		clr.b	obAnim(a0)
		move.w	#$80,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

loc_159A0:
		cmpi.w	#-$60,d0
		blt.s	.return
		btst	#0,obStatus(a0)
		beq.s	loc_159BC
		move.b	#2,obAnim(a0)
		move.w	#$200,obVelX(a0)
.return:	rts
; ---------------------------------------------------------------------------

loc_159BC:
		clr.b	obAnim(a0)
		move.w	#-$80,obVelX(a0)
		rts
; End of function sub_1596C

; ---------------------------------------------------------------------------
Ani_Obj4D:	dc.w byte_159D0-Ani_Obj4D
		dc.w byte_159DE-Ani_Obj4D
		dc.w byte_159E1-Ani_Obj4D
byte_159D0:	dc.b   2,  0,  0,  0,  3,  3,  4,  1,  1,  2,  5,  5,  5,afEnd
byte_159DE:	dc.b  $F,  0,afEnd
byte_159E1:	dc.b   2,  6,  7,afEnd
		even