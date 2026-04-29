; ===========================================================================
; ---------------------------------------------------------------------------
; Object 4B - Buzzer from EHZ
; ---------------------------------------------------------------------------
; OST Variables:
Obj4B_move_timer	= objoff_2C	; word
Obj4B_turn_delay	= objoff_2E	; word
Obj4B_shot_timer	= objoff_30	; word
Obj4B_parent		= objoff_32	; long
Obj4B_shooting_flag	= objoff_36	; byte
; ---------------------------------------------------------------------------

Obj4B:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj4B_Index(pc,d0.w),d1
		jmp	Obj4B_Index(pc,d1.w)
; ===========================================================================
Obj4B_Index:
		dc.w Obj4B_Init-Obj4B_Index
		dc.w Obj4B_Main-Obj4B_Index
		dc.w Obj4B_Flame-Obj4B_Index
		dc.w Obj4B_Projectile-Obj4B_Index
; ===========================================================================
; loc_167AA:
Obj4B_Projectile:
		bsr.w	ObjectMove
		lea	Ani_obj4B(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
	;	jsr	(AnimateSprite).l
	;	jmp	(MarkObjGone).l
; ===========================================================================
; loc_167BC:
Obj4B_Flame:
		movea.l	Obj4B_parent(a0),a1
		cmpi.b	#id_Obj4B,(a1)
		bne.w	DeleteObject
		tst.w	Obj4B_turn_delay(a1)
		bmi.s	+
		rts
; ---------------------------------------------------------------------------
+
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		move.b	obRender(a1),obRender(a0)
		lea	Ani_obj4B(pc),a1
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
	;	jsr	(AnimateSprite).l
	;	jmp	(MarkObjGone).l
; ===========================================================================

Obj4B_Init:
		move.l	#Map_Buzzer,obMap(a0)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a0)
		ori.b	#4,obRender(a0)
		move.b	#$A,obColType(a0)
		move.w	#$200,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.b	#$10,obHeight(a0)
		move.b	#$18,obWidth(a0)
		addq.b	#2,obRoutine(a0)		; => Obj4B_Main

		; load exhaust flame object
		bsr.w	FindNextFreeObj
		bne.s	.return

		_move.b	#id_Obj4B,obID(a1)			; load obj4B
		move.b	#4,obRoutine(a1)		; => Obj4B_Flame
		move.l	#Map_Buzzer,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	#1,obAnim(a1)
		move.l	a0,Obj4B_parent(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#$100,Obj4B_move_timer(a0)
		move.w	#-$100,obVelX(a0)
		btst	#0,obRender(a0)
		beq.s	.return
		neg.w	obVelX(a0)
.return:	rts
; ===========================================================================

Obj4B_Main:
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		move.w	Obj4B_Main_Index(pc,d0.w),d1
		jsr	Obj4B_Main_Index(pc,d1.w)
		lea	Ani_obj4B(pc),a1
	;	jsr	(AnimateSprite).l
	;	jmp	(MarkObjGone).l
		bsr.w	AnimateSprite
		bra.w	MarkObjGone
; ===========================================================================
Obj4B_Main_Index:
		dc.w Obj4B_Roaming-Obj4B_Main_Index
		dc.w Obj4B_Shooting-Obj4B_Main_Index
; ===========================================================================
; loc_168C0:
Obj4B_Roaming:
		bsr.s	Obj4B_ChkPlayers
		subq.w	#1,Obj4B_turn_delay(a0)
		move.w	Obj4B_turn_delay(a0),d0
		cmpi.w	#15,d0
		beq.s	Obj4B_TurnAround
		tst.w	d0
		bpl.s	.return
		subq.w	#1,Obj4B_move_timer(a0)
		bgt.w	ObjectMove
		move.w	#30,Obj4B_turn_delay(a0)
.return:	rts
; ---------------------------------------------------------------------------
; loc_168E6:
Obj4B_TurnAround:
		sf	Obj4B_shooting_flag(a0)			; reenable shooting
		neg.w	obVelX(a0)			; reverse movement direction
		bchg	#0,obRender(a0)
		bchg	#0,obStatus(a0)
		move.w	#$100,Obj4B_move_timer(a0)
		rts

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; sub_16902:
Obj4B_ChkPlayers:
		tst.b	Obj4B_shooting_flag(a0)
		bne.s	.return				; branch, if shooting is disabled
		move.w	obX(a0),d0
		sub.w	(v_player+obX).w,d0		; a1=character
		move.w	d0,d1
		bpl.s	+
		neg.w	d0
+
		; test if player is inside an 8 pixel wide strip
		cmpi.w	#$28,d0
		blt.s	.return
		cmpi.w	#$30,d0
		bgt.s	.return

		tst.w	d1				; test sign of distance
		bpl.s	Obj4B_PlayerIsLeft		; branch, if player is left from object
		btst	#0,obRender(a0)
		beq.s	.return				; branch, if object is facing right
		; Obj4B_ReadyToShoot
		st	Obj4B_shooting_flag(a0)			; disable shooting
		addq.b	#2,ob2ndRout(a0)		; => Obj4B_Shooting
		move.b	#3,obAnim(a0)			; play shooting animation
		move.w	#$32,Obj4B_shot_timer(a0)
.return:	rts
; ---------------------------------------------------------------------------
; loc_16932:
Obj4B_PlayerIsLeft:
		btst	#0,obRender(a0)
		bne.s	.return				; branch, if object is facing left
		; Obj4B_ReadyToShoot
		st	Obj4B_shooting_flag(a0)			; disable shooting
		addq.b	#2,ob2ndRout(a0)		; => Obj4B_Shooting
		move.b	#3,obAnim(a0)			; play shooting animation
		move.w	#$32,Obj4B_shot_timer(a0)
.return:	rts
; End of function Obj4B_ChkPlayers

; ===========================================================================
; loc_16950:
Obj4B_Shooting:
		move.w	Obj4B_shot_timer(a0),d0		; get timer value
		subq.w	#1,d0				; decrement
		blt.s	Obj4B_DoneShooting		; branch, if timer has expired
		move.w	d0,Obj4B_shot_timer(a0)		; update timer value
		cmpi.w	#$14,d0				; has timer reached a certain value?
		beq.s	Obj4B_ShootProjectile		; if yes, branch
		rts
; ===========================================================================
; loc_16964:
Obj4B_DoneShooting:
		subq.b	#2,ob2ndRout(a0)		; => Obj4B_Roaming
		rts
; ===========================================================================
; loc_1696A:
Obj4B_ShootProjectile:
		bsr.w	FindNextFreeObj
		bne.s	.return

		_move.b	#id_Obj4B,obID(a1)			; load obj4B
		move.b	#6,obRoutine(a1)		; => Obj4B_Projectile
		move.l	#Map_Buzzer,obMap(a1)
		move.w	#make_art_tile(ArtTile_Buzzer,0,0),obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.b	#$98,obColType(a1)
		move.b	#$10,obActWid(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obRender(a0),obRender(a1)
		move.b	#2,obAnim(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#13,d0				; absolute horizontal offset for stinger
		move.w	#$180,obVelY(a1)
		move.w	#-$180,obVelX(a1)
		btst	#0,obRender(a1)			; is object facing left?
		beq.s	.return				; if not, branch
		neg.w	obVelX(a1)			; move in other direction
		neg.w	d0				; make offset negative
.return:	add.w	d0,obX(a1)			; align horizontally with stinger
		rts
; ===========================================================================
; animation script
; off_169DA:
Ani_obj4B:
		dc.w byte_169E2-Ani_obj4B
		dc.w byte_169E5-Ani_obj4B
		dc.w byte_169E9-Ani_obj4B
		dc.w byte_169ED-Ani_obj4B
byte_169E2:	dc.b  $F,  0,afEnd
byte_169E5:	dc.b   2,  3,  4,afEnd
byte_169E9:	dc.b   3,  5,  6,afEnd
byte_169ED:	dc.b   9,  1,  1,  1,  1,  1,afChange,  0
		even