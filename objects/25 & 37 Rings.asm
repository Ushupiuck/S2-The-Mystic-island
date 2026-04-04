; ===========================================================================
;----------------------------------------------------------------------------
; Object 25 - Rings
;----------------------------------------------------------------------------

Obj25:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj25_Index(pc,d0.w),d1
		jmp	Obj25_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj25_Index:
		dc.w Obj25_Init-Obj25_Index
		dc.w Obj25_Animate-Obj25_Index
		dc.w Obj25_Collect-Obj25_Index
		dc.w Obj25_Sparkle-Obj25_Index
		dc.w DeleteObject-Obj25_Index	; small tweak to remove an optional jmpto
; ---------------------------------------------------------------------------

Obj25_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Ring,obMap(a0)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$47,obColType(a0)
		move.b	#8,obActWid(a0)

Obj25_Animate:
		move.b	(v_ani1_frame).w,obFrame(a0)
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------

Obj25_Collect:
		addq.b	#2,obRoutine(a0)
		clr.b	obColType(a0)
		move.w	#$80,obPriority(a0)
		bsr.s	CollectRing

Obj25_Sparkle:
		lea	Ani_Obj25(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Ani_Obj25:	dc.w byte_ABEC-Ani_Obj25
byte_ABEC:	dc.b   5,  4,  5,  6,  7,$FC
		even
; =============== S U B	R O U T	I N E =======================================


CollectRing:
		move.w	#sfx_Ring,d0
		cmpi.w	#999,(v_rings).w
		bhs.s	.playsound
		addq.w	#1,(v_rings).w
		ori.b	#1,(f_ringcount).w
		cmpi.w	#100,(v_rings).w
		bcs.s	.playsound
		bset	#1,(v_lifecount).w
		beq.s	+
		cmpi.w	#200,(v_rings).w
		bcs.s	.playsound
		bset	#2,(v_lifecount).w
		bne.s	.playsound
+
		addq.b	#1,(v_lives).w
		addq.b	#1,(f_lifecount).w
		moveq	#bgm_ExtraLife,d0

.playsound:
		jmp	(PlaySound_Special).l
; End of function CollectRing

; ---------------------------------------------------------------------------
; Object 37 - Rings flying out of you when you get hit
;----------------------------------------------------------------------------
obDelayAni	= obXSub	; time to delay animation

Obj37:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj37_Index(pc,d0.w),d1
		jmp	Obj37_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj37_Index:	dc.w loc_A936-Obj37_Index
		dc.w loc_A9FA-Obj37_Index
		dc.w loc_AA4C-Obj37_Index
		dc.w loc_AA60-Obj37_Index
		dc.w DeleteObject-Obj37_Index	; small tweak to remove an optional jmpto
; ---------------------------------------------------------------------------

loc_A936:
		movea.l	a0,a1
		moveq	#0,d5
		move.w	(v_rings).w,d5
		moveq	#32,d0
		cmp.w	d0,d5
		bcs.s	loc_A946
		move.w	d0,d5

loc_A946:
		subq.w	#1,d5
		move.w	#$288,d4
		bra.s	loc_A956
; ---------------------------------------------------------------------------

loc_A94E:
		bsr.w	FindFreeObj
		bne.w	loc_A9DE

loc_A956:
		_move.b	#id_Obj37,obID(a1)
		addq.b	#2,obRoutine(a1)
		move.b	#8,obHeight(a1)
		move.b	#8,obWidth(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.l	#Map_Ring,obMap(a1)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$47,obColType(a1)
		move.b	#8,obActWid(a1)
		tst.w	d4
		bmi.s	+
		move.w	d4,d0
		bsr.w	CalcSine
		move.w	d4,d2
		lsr.w	#8,d2
		asl.w	d2,d0
		asl.w	d2,d1
		move.w	d0,d2
		move.w	d1,d3
		addi.b	#$10,d4
		bcc.s	+
		subi.w	#$80,d4
		bcc.s	+
		move.w	#$288,d4
+
		move.w	d2,obVelX(a1)
		move.w	d3,obVelY(a1)
		neg.w	d2
		neg.w	d4
		dbf	d5,loc_A94E

loc_A9DE:
		clr.w	(v_rings).w
		move.b	#$80,(f_ringcount).w
		clr.b	(v_lifecount).w
		moveq	#-1,d0			; Move 255 to d0
		move.b	d0,obDelayAni(a0)	; Move d0 to new timer
		move.b	d0,(v_ani3_time).w	; Move d0 to old timer (for animated purposes)
		moveq	#sfx_RingLoss,d0
		jsr	(PlaySound_Special).l

loc_A9FA:
		move.b	(v_ani3_frame).w,obFrame(a0)
		bsr.w	ObjectMove
		addi.w	#$18,obVelY(a0)
		bmi.s	loc_AA34
		move.b	(Vint_runcount+3).w,d0
		add.b	d7,d0
		andi.b	#3,d0
		bne.s	loc_AA34
		tst.b	obRender(a0)
		bpl.s	loc_AA34
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	loc_AA34
		add.w	d1,obY(a0)
		move.w	obVelY(a0),d0
		asr.w	#2,d0
		sub.w	d0,obVelY(a0)
		neg.w	obVelY(a0)

loc_AA34:
		subq.b	#1,obDelayAni(a0)	; Subtract 1
		beq.w	DeleteObject		; If 0, delete
		tst.w	(v_limittop2).w		; is vertical wrapping enabled?
		bmi.w	DisplaySprite		; if so, don't delete rings by boundary
		move.w	(Camera_Max_Y_pos).w,d0
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		bcs.w	DeleteObject
		btst	#0,obDelayAni(a0)	; Test the first bit of the timer, so rings flash every other frame.
		beq.w	DisplaySprite		; If the bit is 0, the ring will appear.
		cmpi.b	#80,obDelayAni(a0)	; Rings will flash during last 80 steps of their life.
		bhi.w	DisplaySprite		; If the timer is higher than 80, obviously the rings will STAY visible.
		rts
; ---------------------------------------------------------------------------

loc_AA4C:
		addq.b	#2,obRoutine(a0)
		clr.b	obColType(a0)
		move.w	#$80,obPriority(a0)
		bsr.w	CollectRing

loc_AA60:
		lea	Ani_Obj25(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite

; ---------------------------------------------------------------------------
; ObjRing_Delete:	; just in case it ever becomes neccesary
	;	bra.w	DeleteObject