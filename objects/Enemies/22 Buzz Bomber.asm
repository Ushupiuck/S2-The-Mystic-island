; ===========================================================================
; ---------------------------------------------------------------------------
; Object 22 - Buzz Bomber from GHZ
; ---------------------------------------------------------------------------
; OST:
Buzz_time	= objoff_2C	; time to wait for performing an action
Buzz_status	= objoff_2E	; 0 = still, 1 = flying, 2 = shooting
Buzz_parent	= objoff_3C
; ---------------------------------------------------------------------------

Obj22:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj22_Index(pc,d0.w),d1
		jmp	Obj22_Index(pc,d1.w)
; ===========================================================================
Obj22_Index:	dc.w Obj22_Init-Obj22_Index
		dc.w Obj22_Main-Obj22_Index
		dc.w DeleteObject-Obj22_Index	; small tweak to remove an optional jmpto
; ===========================================================================
; loc_A41C:
Obj22_Init:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_obj22,obMap(a0)
		move.w	#make_art_tile(ArtTile_Buzz_Bomber,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#8,obColType(a0)
		move.b	#$18,obActWid(a0)
; loc_A44A:
Obj22_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj22_Main_Index(pc,d0.w),d1
		jsr	Obj22_Main_Index(pc,d1.w)
		lea	Ani_obj22(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
Obj22_Main_Index:
		dc.w Obj22_Move-Obj22_Main_Index
		dc.w Obj22_NearSonic-Obj22_Main_Index
; ===========================================================================
; loc_A46A:
Obj22_Move:
		subq.w	#1,Buzz_time(a0)
		bpl.s	.return
		btst	#1,Buzz_status(a0)
		bne.s	Obj22_LoadMissile
		addq.b	#2,ob2ndRout(a0)
		move.w	#128-1,Buzz_time(a0)
		move.w	#$400,obVelX(a0)
		move.b	#1,obAnim(a0)
		btst	#0,obStatus(a0)
		bne.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================
; loc_A49C:
Obj22_LoadMissile:
		bsr.w	FindFreeObj
		bne.s	.return
		_move.b	#id_Obj23,obID(a1)			; load Obj23 (Buzz Bomber/Newtron missile)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addi.w	#$1C,obY(a1)
		move.w	#$200,obVelX(a1)
		move.w	#$200,obVelY(a1)
		move.w	#$14,d0
		btst	#0,obStatus(a0)
		bne.s	+
		neg.w	d0
		neg.w	obVelX(a1)
+
		add.w	d0,obX(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.w	#15-1,Buzz_time(a1)
		move.l	a0,Buzz_parent(a1)
		move.b	#1,Buzz_status(a0)
		move.w	#60-1,Buzz_time(a0)
		move.b	#2,obAnim(a0)
.return:	rts
; ===========================================================================
; loc_A500:
Obj22_NearSonic:
		subq.w	#1,Buzz_time(a0)
		bmi.s	loc_A536
		bsr.w	ObjectMove
		tst.b	Buzz_status(a0)
		bne.s	.return
		move.w	(v_player+obX).w,d0
		sub.w	obX(a0),d0
		bpl.s	+
		neg.w	d0
+
		cmpi.w	#$60,d0				; is Buzz Bomber within $60 pixels of Sonic?
		bcc.s	.return				; if not, branch
		tst.b	obRender(a0)
		bpl.s	.return
		move.b	#2,Buzz_status(a0)
		move.w	#29,Buzz_time(a0)
		subq.b	#2,ob2ndRout(a0)
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
.return:	rts
; ===========================================================================

loc_A536:
		clr.b	Buzz_status(a0)
		bchg	#0,obStatus(a0)
		move.w	#59,Buzz_time(a0)
		subq.b	#2,ob2ndRout(a0)
		clr.w	obVelX(a0)
		clr.b	obAnim(a0)
		rts
; ===========================================================================
; loc_A55A:
; Obj22_Delete:
	;	bra.w	DeleteObject
; ===========================================================================
; animation script
Ani_obj22:	dc.w byte_A652-Ani_obj22
		dc.w byte_A656-Ani_obj22
		dc.w byte_A65A-Ani_obj22
byte_A652:	dc.b   1,  0,  1,$FF
byte_A656:	dc.b   1,  2,  3,$FF
byte_A65A:	dc.b   1,  4,  5,$FF
		even