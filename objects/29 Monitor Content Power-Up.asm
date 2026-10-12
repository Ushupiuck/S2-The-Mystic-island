; ---------------------------------------------------------------------------
; Object 29 - monitor contents (code for power-up behavior and rising image)
; ---------------------------------------------------------------------------

Obj29:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj29_Index(pc,d0.w),d1
		jsr	Obj29_Index(pc,d1.w)
		bra.w	DisplaySprite
; ---------------------------------------------------------------------------
Obj29_Index:	dc.w loc_B04E-Obj29_Index
		dc.w loc_B092-Obj29_Index
		dc.w Pow_Delete-Obj29_Index
; ---------------------------------------------------------------------------

loc_B04E:
		addq.b	#2,obRoutine(a0)
		move.w	#make_art_tile(ArtTile_Monitor,0,0),obGfx(a0)
		ori.b	#$24,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#8,obActWid(a0)
		move.w	#-$300,obVelY(a0)
		moveq	#0,d0
		move.b	obAnim(a0),d0
		addq.b	#1,d0
		move.b	d0,obFrame(a0)
		movea.l	#Map_Obj26,a1
		add.b	d0,d0
		adda.w	(a1,d0.w),a1
		addq.w	#2,a1
		move.l	a1,obMap(a0)
		move.b	#Map_Obj26_height,height_pixels(a0)

loc_B092:
		btst	#1,obRender(a0)
		bne.s	+
		tst.w	obVelY(a0)	; is icon still floating up?
		bpl.s	++		; if not, branch
		bsr.w	ObjectMove	; update position
		addi.w	#$18,obVelY(a0)	; reduce upward speed
		bra.w	DisplaySprite

; =============== S U B	R O U T	I N E =======================================

+
		tst.w	obVelY(a0)
		bmi.s	+
		bsr.w	ObjectMove	; update position
		subi.w	#$18,obVelY(a0)	; increment upward speed
		rts
; ---------------------------------------------------------------------------

+
		addq.b	#2,obRoutine(a0)
		move.b	#30-1,obTimeFrame(a0)
		movea.w	obParent(a0),a1 ; a1=character
		moveq	#0,d0
		move.b	obAnim(a0),d0
		add.w	d0,d0
		move.w	Monitor_Subroutines(pc,d0.w),d0
		jmp	Monitor_Subroutines(pc,d0.w)
; End of function sub_B098

; ---------------------------------------------------------------------------
Monitor_Subroutines:
		dc.w Monitor_Null-Monitor_Subroutines		; 0 - Static
		dc.w Monitor_SonicLife-Monitor_Subroutines	; 1 - Double up
		dc.w Monitor_TailsLife-Monitor_Subroutines	; 2 - One up
		dc.w Monitor_Null-Monitor_Subroutines		; 3 - Eggman
		dc.w Monitor_Rings-Monitor_Subroutines		; 4 - Super Ring
		dc.w Monitor_Shoes-Monitor_Subroutines		; 5 - Speedshoes
		dc.w Monitor_Shield-Monitor_Subroutines		; 6 - Plasma Shield
		dc.w Monitor_Invincibility-Monitor_Subroutines	; 7 - Invincibility
		dc.w Monitor_Null-Monitor_Subroutines		; 8 - Water Shield	(TBA)
		dc.w Monitor_Null-Monitor_Subroutines		; 9 - Fire Shield	(TBA)
		dc.w Monitor_Null-Monitor_Subroutines		;$A - Electric Shield	(TBA)
		dc.w Monitor_Null-Monitor_Subroutines		;$B - Super		(TBA)
; ---------------------------------------------------------------------------

Monitor_Null:
		jmp	(HurtSonic).l
; ---------------------------------------------------------------------------

Monitor_SonicLife:	; Now rarer and MUCH more valuable!
		addq.b	#2,(v_lives).w
		addq.b	#2,(f_lifecount).w
		move.w	#bgm_DoubleLife,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------

Monitor_TailsLife:	; 1up monitor
		addq.b	#1,(v_lives).w
		addq.b	#1,(f_lifecount).w
		move.w	#bgm_ExtraLife,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------

Monitor_Rings:
		addi.w	#10,(v_rings).w
		ori.b	#1,(f_ringcount).w
		cmpi.w	#100,(v_rings).w
		bcs.s	loc_B130
		bset	#1,(v_lifecount).w
		beq.w	Monitor_SonicLife
		cmpi.w	#200,(v_rings).w
		bcs.s	loc_B130
		bset	#2,(v_lifecount).w
		beq.w	Monitor_SonicLife

loc_B130:
		move.w	#sfx_Ring,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------

; Give both live players speed shoes, then change the shared tempo once.
; ---------------------------------------------------------------------------
Monitor_Shoes:
		movea.l	a1,a2
		bsr.w	Monitor_GiveShoes
		bsr.w	Monitor_GetPartner
		beq.s	.sound
		bsr.w	Monitor_GiveShoes
.sound:
		moveq	#8,d0
		jmp	(ChangeMusicTempo).l

; ---------------------------------------------------------------------------
; Grant speed shoes to the player in a2 without retriggering the audio.
; ---------------------------------------------------------------------------
Monitor_GiveShoes:
		bset	#obStatusSecondary_hasSpeedShoes,obStatusSecondary(a2)
		move.w	#20*60,shoetime(a2)
		jmp	(Player_UpdateSpeed).l
; ---------------------------------------------------------------------------

; Give both live players their own shield state and effect object.
; ---------------------------------------------------------------------------
Monitor_Shield:
		movea.l	a1,a2
		bsr.w	Monitor_GiveShield
		bsr.w	Monitor_GetPartner
		beq.s	.sound
		bsr.w	Monitor_GiveShield
.sound:
		move.w	#sfx_Shield,d0
		jmp	(PlaySound).l

; ---------------------------------------------------------------------------
; Apply a shield to one player. Pickup sharing calls this once per live
; player; damage/death clear only the affected player's shield status.
; ---------------------------------------------------------------------------
Monitor_GiveShield:
		bset	#obStatusSecondary_hasShield,obStatusSecondary(a2)
		lea	(v_shieldobj2).w,a3
		cmpa.w	#v_player,a2
		bne.s	.slot_ready
		lea	(v_shieldobj).w,a3
.slot_ready:
		_move.b	#id_Obj38,obID(a3)
		clr.b	obRoutine(a3)
		clr.b	obAnim(a3)
		clr.b	obAniFrame(a3)
		clr.b	obTimeFrame(a3)
		move.w	a2,obParent(a3)
		rts
; ---------------------------------------------------------------------------

; a1 is the collector; return the other player in a2, Z clear if live.
; ---------------------------------------------------------------------------
Monitor_GetPartner:
		lea	(v_player).w,a2
		cmpa.w	#v_player,a1
		bne.s	.check
		lea	(v_player2).w,a2
.check:
		moveq	#0,d0
		tst.b	obID(a2)
		beq.s	.return
		cmpi.b	#6,obRoutine(a2)
		bhs.s	.return
		moveq	#1,d0
.return:
		tst.b	d0
		rts
; ---------------------------------------------------------------------------

; Give both live players invincibility, refresh the shared star object,
; and request the music once when the current scene permits it.
; ---------------------------------------------------------------------------
Monitor_Invincibility:
		tst.b	(Super_Sonic_flag).w	; is Sonic super?
		bne.s	.return			; if yes, branch
		bset	#obStatusSecondary_isInvincible,obStatusSecondary(a1)	; give invincibility status
		move.w	#20*60,invtime(a1)	; 20 seconds
		bsr.w	Monitor_GetPartner	; either player's pickup also covers the live partner
		beq.s	.shared_ready
		bset	#obStatusSecondary_isInvincible,obStatusSecondary(a2)
		move.w	#20*60,invtime(a2)
.shared_ready:
		tst.b	(f_lockscreen).w	; don't change music during boss battles
		bne.s	+
	;	cmpi.b	#12,air_left(a1)	; or when drowning
		cmpi.w	#12,(v_air).w
		bls.s	+
		move.w	#bgm_Invincible,d0
		jsr	(PlayMusic).l
+
		lea	(v_starsobj).w,a2
		_move.b	#id_Obj35,obID(a2)
		clr.b	invincibility_flags(a2)	; reinitialize all four layers on a fresh pickup
.return:
		rts
; ---------------------------------------------------------------------------

Pow_Delete:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.return
		addq.l	#4,sp
		bra.w	DeleteObject
.return:
		rts
