; ---------------------------------------------------------------------------
; Object 0B - Tilting platform segment from CPZ
; ---------------------------------------------------------------------------

Obj0B:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj0B_Index(pc,d0.w),d1
		jmp	Obj0B_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Obj0B_Index:	dc.w Obj0B_Init-Obj0B_Index
		dc.w Obj0B_WaitTilt-Obj0B_Index
		dc.w Obj0B_TiltLoop-Obj0B_Index

tilt_timer	= objoff_30	; 2 bytes; time until next tilt
tilt_duration	= objoff_32	; 2 bytes; how long it stays tilted for
tilt_offset	= objoff_36	; 1 byte; individual timer per tilting platform
; ---------------------------------------------------------------------------

Obj0B_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Obj0B,obMap(a0)
		move.w	#make_art_tile(ArtTile_Level,3,1),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$200,obPriority(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F0,d0
		addi.w	#$10,d0
		move.w	d0,d1
		subq.w	#1,d0
		move.w	d0,tilt_timer(a0)
		move.w	d0,tilt_duration(a0)
		moveq	#0,d0
		move.b	obSubtype(a0),d0
		andi.w	#$F,d0
		addq.w	#1,d0
		lsl.w	#4,d0
		move.b	d0,tilt_offset(a0)

Obj0B_WaitTilt:
		move.b	(Vint_runcount+3).w,d0
		add.b	tilt_offset(a0),d0
		bne.s	Obj0B_TiltLoop.solid
		addq.b	#2,obRoutine(a0)

Obj0B_TiltLoop:
		subq.w	#1,tilt_timer(a0)
		bpl.s	.animate
		move.w	#$80-1,tilt_timer(a0)
		tst.b	obAnim(a0)
		beq.s	+
		move.w	tilt_duration(a0),tilt_timer(a0)
+
		bchg	#0,obAnim(a0)

.animate:
		lea	Obj0B_Anim(pc),a1
		jsr	(AnimateSprite).l

.solid:
		tst.b	obFrame(a0)
		bne.s	+
		moveq	#0,d1
		move.b	obActWid(a0),d1
		moveq	#$11,d3
		move.w	obX(a0),d4
		bsr.w	PlatformObject
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
+
		move.b	obStatus(a0),d0
		andi.b	#$18,obStatus(a0)	; standing_mask
		beq.s	++
		bclr	#3,obStatus(a0)		; p1_standing_bit
		beq.s	+
		bclr	#3,(v_player+obStatus).w	; on_object
		bset	#1,(v_player+obStatus).w	; in_air
+
		bclr	#4,obStatus(a0)		; p1_standing_bit
		beq.s	+
		bclr	#3,(v_player2+obStatus).w
		bset	#1,(v_player2+obStatus).w
+
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
Obj0B_Anim:	dc.w byte_1428E-Obj0B_Anim
		dc.w byte_14296-Obj0B_Anim
byte_1428E:	dc.b   7,  0,  1,  2,  3,  4,afBack,  1
byte_14296:	dc.b   7,  4,  3,  2,  1,  0,afBack,  1
		even