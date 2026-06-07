; ---------------------------------------------------------------------------
; Object 47 - pinball bumper (SYZ)
; ---------------------------------------------------------------------------

Obj47:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Bump_Index(pc,d0.w),d1
		jmp	Bump_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Bump_Index:	dc.w Bump_Main-Bump_Index
		dc.w Bump_Hit-Bump_Index
; ---------------------------------------------------------------------------

Bump_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.b	#4,obRender(a0)
		move.b	#$10,obActWid(a0)
		move.w	#$80,obPriority(a0)
		move.b	#$D7,obColType(a0)
		move.l	#Map_Bump,obMap(a0)
		move.w	#make_art_tile(ArtTile_Bumper,0,0),obGfx(a0)
		move.w	obX(a0),objoff_30(a0)	; setting these up for later!
		move.w	obY(a0),objoff_32(a0)

Bump_Hit:	; Routine 2
		move.b	obColProp(a0),d0
		beq.s	+
		lea	(v_player).w,a1
		bclr	#0,obColProp(a0)
		beq.s	loc_138CA
		bsr.s	Bumper_bump

loc_138CA:
		lea	(v_player2).w,a1
		bclr	#1,obColProp(a0)
		beq.s	loc_138D8
		bsr.s	Bumper_bump

loc_138D8:
		clr.b	obColProp(a0)
+		lea	Ani_Bump(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ---------------------------------------------------------------------------
Ani_Bump:	dc.w byte_13988-Ani_Bump
		dc.w byte_1398B-Ani_Bump
byte_13988:	dc.b  $F,  0,afEnd
byte_1398B:	dc.b   3,  1,  2,  1,  2,afChange,  0
		even
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================


Bumper_bump:
		move.w	obX(a0),d1
		move.w	obY(a0),d2
		sub.w	obX(a1),d1
		sub.w	obY(a1),d2
		jsr	(CalcAngle).l
		moveq	#3,d1
		and.b	(v_framecount).w,d1
		add.w	d1,d0
		jsr	(CalcSine).l
		move.w	d1,d3		; multiply by -$700
		asl.w	#3,d1
		sub.w	d3,d1
		neg.w	d1
		move.w	d0,d3		; ...For X and Y
		asl.w	#3,d0
		sub.w	d3,d0
		neg.w	d0
		move.w	d1,obVelX(a1)
		move.w	d0,obVelY(a1)	; and bounce Sonic away
		bset	#1,obStatus(a1)
	;	bclr	#4,obStatus(a1)
		bclr	#5,obStatus(a1)
		clr.b	jumping(a1)
		move.b	#1,obAnim(a0)	; use "hit" animation
		move.w	#sfx_Bumper,d0
		jsr	(PlaySound_Special).l	; play bumper sound
		lea	(v_objstate).w,a2
		moveq	#0,d0
		move.b	obRespawnNo(a0),d0
		beq.s	.addscore
		cmpi.b	#$8A,2(a2,d0.w)
		bhs.s	.return
		addq.b	#1,2(a2,d0.w)

.addscore:
		moveq	#1,d0
	;	jsr	(AddPoints).l
		bsr.w	AddPoints
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_ObjFF,obID(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	#4,obFrame(a1)
.return:	rts
; End of function Obj47_Bump