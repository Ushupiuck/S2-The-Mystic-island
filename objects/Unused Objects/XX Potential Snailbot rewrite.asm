; ---------------------------------------------------------------------------
; Object 54 - Snailbot (EHZ)
; Moves like MotoBug. Speeds up once when Sonic enters trigger zone ahead.
; Slows back to normal on wall/edge. Spawns flame child like MotoBug smoke.
; Shell is integrated into mappings — no separate child object needed.
; ---------------------------------------------------------------------------

Snailbot:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Snailbot_Index(pc,d0.w),d1
		jmp	Snailbot_Index(pc,d1.w)
; ===========================================================================
Snailbot_Index:
		dc.w Snailbot_Init-Snailbot_Index
		dc.w Snailbot_Main-Snailbot_Index
		dc.w Snailbot_Animate-Snailbot_Index	; flame child
		dc.w Snailbot_Delete-Snailbot_Index

snail_wait	= objoff_30			; word; pause countdown
snail_flame	= objoff_32			; byte; flame spawn countdown
; ===========================================================================

Snailbot_Init:
		move.l	#Map_Snailbot,obMap(a0)
		move.w	#make_art_tile(ArtTile_Snailbot,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$E,obWidth(a0)
		move.b	#$C,obColType(a0)
		tst.b	obAnim(a0)			; flame child?
		bne.s	Snailbot_Flame
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

Snailbot_Flame:					; flame child entry point
		addq.b	#4,obRoutine(a0)		; skip to Snailbot_Animate
Snailbot_Animate:
		lea	Ani_Snailbot(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================

Snailbot_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Snailbot_Main_Index(pc,d0.w),d1
		jsr	Snailbot_Main_Index(pc,d1.w)
		lea	Ani_Snailbot(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
Snailbot_Main_Index:
		dc.w Snailbot_Wait-Snailbot_Main_Index
		dc.w Snailbot_Move-Snailbot_Main_Index
		dc.w Snailbot_Burst-Snailbot_Main_Index
; ===========================================================================

Snailbot_Wait:
		subq.w	#1,snail_wait(a0)
		bpl.s	.return
		addq.b	#2,ob2ndRout(a0)
		move.w	#-$100,obVelX(a0)		; normal speed
		move.b	#1,obAnim(a0)
		bchg	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================

Snailbot_Move:
		bsr.w	ObjectMove
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Snailbot_StopMoving
		cmpi.w	#$C,d1
		bge.s	Snailbot_StopMoving
		add.w	d1,obY(a0)
		; flame child — same pattern as MotoBug smoke
		subq.b	#1,snail_flame(a0)
		bpl.s	.chktrigger
		move.b	#15,snail_flame(a0)
		bsr.w	FindFreeObj
		bne.s	.chktrigger
		_move.b	#id_Snailbot,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	#2,obAnim(a1)			; flame animation index
.chktrigger:
		; check if Sonic is within trigger zone ahead of Snailbot
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		btst	#0,obStatus(a0)			; facing left?
		bne.s	.chkrange
		neg.w	d0				; flip so positive = ahead
.chkrange:
		tst.w	d0				; Sonic behind us?
		bmi.s	.return
		cmpi.w	#$64,d0				; within $64px ahead?
		bhi.s	.return
		move.w	(v_player+obY).w,d1
		sub.w	obY(a0),d1
		addi.w	#$30,d1				; centre window vertically
		cmpi.w	#$60,d1				; within $60px vertically?
		bhs.s	.return
		; Sonic is in the zone — trigger burst
		addq.b	#2,ob2ndRout(a0)
		asl.w	#2,obVelX(a0)			; ×4 speed burst
.return:	rts
; ===========================================================================

Snailbot_Burst:
		bsr.w	ObjectMove
		jsr	(ObjHitFloor).l
		cmpi.w	#-8,d1
		blt.s	Snailbot_BurstEnd
		cmpi.w	#$C,d1
		bge.s	Snailbot_BurstEnd
		add.w	d1,obY(a0)
		rts
; ===========================================================================

Snailbot_BurstEnd:
		subq.b	#2,ob2ndRout(a0)		; burst ? normal move (no wait)
		asr.w	#2,obVelX(a0)			; ÷4 back to normal speed
		rts
; ===========================================================================

Snailbot_StopMoving:
		subq.b	#2,ob2ndRout(a0)		; normal move ? wait
		move.w	#59,snail_wait(a0)		; 1 second pause
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		rts
; ===========================================================================

Snailbot_Delete:
		bra.w	DeleteObject
; ===========================================================================
Ani_Snailbot:	dc.w byte_Snail0-Ani_Snailbot
		dc.w byte_Snail1-Ani_Snailbot
		dc.w byte_Snail2-Ani_Snailbot
byte_Snail0:	dc.b  $F,  0,afEnd			; idle
byte_Snail1:	dc.b   7,  0,  1,  0,  2,afEnd		; moving
byte_Snail2:	dc.b   1,  3,  6,  3,  6,  4,  6,  4	; flame child
		dc.b   6,  4,  6,  5,afRoutine
		even