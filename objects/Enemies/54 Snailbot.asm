; ===========================================================================
; ---------------------------------------------------------------------------
; Object 54 - Snail badnik from EHZ (Nick Arcade / Simon Wai prototypes)
; ---------------------------------------------------------------------------
snail_turn_timer	= objoff_2E	; 2 bytes; countdown before turning around
snail_turning		= objoff_30	; 1 byte; set while waiting to reverse; also kills flame child
snail_boosted		= objoff_31	; 1 byte; set after spotting player so boost only happens once per pass
snail_parent		= objoff_32	; 4 bytes; parent pointer for child objects

Obj54:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj54_Index(pc,d0.w),d1
		jmp	Obj54_Index(pc,d1.w)
; ===========================================================================
Obj54_Index:	dc.w	Obj54_Init-Obj54_Index
		dc.w	Obj54_Move-Obj54_Index
		dc.w	Obj54_TurnAround-Obj54_Index
		dc.w	Obj54_SlaveSprite-Obj54_Index
		dc.w	Obj54_FlameTrail-Obj54_Index
; ===========================================================================

Obj54_Init:
		move.l	#Map_Snailbot,obMap(a0)
		move.w	#make_art_tile(ArtTile_Snail,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$E,obWidth(a0)
		jsr	(FindNextFreeObj).l
		bne.s	Obj54_InitDone
		_move.b	#id_Obj54,obID(a1)
		move.b	#6,obRoutine(a1)
		move.l	#Map_Snailbot,obMap(a1)
		move.w	#make_art_tile(ArtTile_Snail,1,0),obGfx(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.l	a0,snail_parent(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#2,obFrame(a1)

Obj54_InitDone:
		addq.b	#2,obRoutine(a0)
		move.w	#-$80,d0
		btst	#0,obStatus(a0)
		beq.s	Obj54_SetStartSpeed
		neg.w	d0

Obj54_SetStartSpeed:
		move.w	d0,obVelX(a0)
		rts
; ===========================================================================
Obj54_Move:
		bsr.w	Obj54_CheckPlayerAndBoost
		jsr	(ObjectMove).l
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Obj54_BeginTurnAround
		cmpi.w	#$C,d1
		bge.s	Obj54_BeginTurnAround
		add.w	d1,obY(a0)
		lea	Ani_Obj54(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ===========================================================================

Obj54_BeginTurnAround:
		addq.b	#2,obRoutine(a0)
		move.w	#$14,snail_turn_timer(a0)
		st	snail_turning(a0)
		lea	Ani_Obj54(pc),a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l

; =============== S U B R O U T I N E =======================================
; Check for player ahead; if found, quadruple speed and spawn flame trail
Obj54_CheckPlayerAndBoost:
		tst.b	snail_boosted(a0)
		bne.w	.return
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		cmpi.w	#$64,d0
		bgt.w	.return
		cmpi.w	#-$64,d0
		blt.w	.return
		tst.w	d0
		bmi.s	.playerLeft
		btst	#0,obStatus(a0)
		beq.s	.return
		bra.s	.boost

.playerLeft:
		btst	#0,obStatus(a0)
		bne.s	.return

.boost:
		move.w	obVelX(a0),d0
		asl.w	#2,d0
		move.w	d0,obVelX(a0)
		st	snail_boosted(a0)
		jsr	(FindNextFreeObj).l
		bne.s	.return
		_move.b	#id_Obj54,obID(a1)
		move.b	#8,obRoutine(a1)
		move.l	#Map_Buzzer,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.l	a0,snail_parent(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addq.w	#7,obY(a1)
		addi.w	#$D,obX(a1)
		move.b	#1,obAnim(a1)
.return:	rts
; End of function sub_176D0

; ---------------------------------------------------------------------------

Obj54_FlameTrail:
		movea.l	snail_parent(a0),a1
		cmpi.b	#id_Obj54,obID(a1)
		bne.w	DeleteObject
		tst.b	snail_turning(a1)
		bne.w	DeleteObject
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		addq.w	#7,obY(a0)
		moveq	#$D,d0
		btst	#0,obStatus(a0)
		beq.s	Obj54_FlameOffset
		neg.w	d0

Obj54_FlameOffset:
		add.w	d0,obX(a0)
		lea	(Ani_obj4B).l,a1
		jsr	(AnimateSprite).l
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------

Obj54_TurnAround:
		subq.w	#1,snail_turn_timer(a0)
		bpl.s	.display
		neg.w	obVelX(a0)
		jsr	(ObjectMoveAndFall).l
		move.w	obVelX(a0),d0
		asr.w	#2,d0
		move.w	d0,obVelX(a0)
		bchg	#0,obStatus(a0)
		bchg	#0,obRender(a0)
		subq.b	#2,obRoutine(a0)
		sf	snail_turning(a0)
		sf	snail_boosted(a0)
.display:	jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Obj54_SlaveSprite:
		movea.l	snail_parent(a0),a1
		cmpi.b	#id_Obj54,obID(a1)
		bne.w	DeleteObject
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		jmp	(MarkObjGone).l
; ---------------------------------------------------------------------------
Ani_Obj54:	dc.w byte_17818-Ani_Obj54
		dc.w byte_1781C-Ani_Obj54
byte_17818:	dc.b   5,  0,  1,afEnd
byte_1781C:	dc.b   1,  0,  1,afEnd
		even