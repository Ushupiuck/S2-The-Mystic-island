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

Monitor_Shoes:
		bset	#obStatusSecondary_hasSpeedShoes,obStatusSecondary(a1)	; give super sneakers status
		move.w	#60*20,shoetime(a1)
		cmpa.w	#v_player,a1		; did the main character break the monitor?
		bne.s	super_shoes_Tails	; if not, branch
		cmpi.w	#2,(Player_mode).w	; is player using Tails?
		beq.s	super_shoes_Tails	; if yes, branch
		move.w	#$C00,(Sonic_top_speed).w	; set stats
		move.w	#$18,(Sonic_acceleration).w
		move.w	#$80,(Sonic_deceleration).w
		move.w	#bgm_Speedup,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------
;loc_12A10:
super_shoes_Tails:
		move.w	#$C00,(Tails_top_speed).w
		move.w	#$18,(Tails_acceleration).w
		move.w	#$80,(Tails_deceleration).w
		move.w	#bgm_Speedup,d0
		jmp	(PlaySound).l
; ---------------------------------------------------------------------------

Monitor_Shield:
		bset	#obStatusSecondary_hasShield,obStatusSecondary(a1)	; give shield status
		move.w	#sfx_Shield,d0
		jsr	(PlaySound).l
		tst.b	obParent+1(a0)
		bne.s	+
		_move.b	#id_Obj38,(v_shieldobj+obID).w ; load Obj38 (shield) at $FFFFD180
		move.w	a1,(v_shieldobj+obParent).w
		rts
; ---------------------------------------------------------------------------
+		; give shield to sidekick
		_move.b	#id_Obj38,(v_shieldobj2+obID).w ; load Obj38 (shield) at $FFFFD1C0
		move.w	a1,(v_shieldobj2+obParent).w
		rts
; ---------------------------------------------------------------------------

Monitor_Invincibility:
		tst.b	(Super_Sonic_flag).w	; is Sonic super?
		bne.s	+++	; rts		; if yes, branch
		bset	#obStatusSecondary_isInvincible,obStatusSecondary(a1)	; give invincibility status
		move.w	#20*60,invtime(a1)	; 20 seconds
		tst.b	(f_lockscreen).w	; don't change music during boss battles
		bne.s	+
	;	cmpi.b	#12,air_left(a1)	; or when drowning
		cmpi.w	#12,(v_air).w
		bls.s	+
		move.w	#bgm_Invincible,d0
		jsr	(PlaySound).l
+
		tst.b	obParent+1(a0)
		bne.s	+
		_move.b	#id_Obj38,(v_starsobj1+obID).w ; load Obj35 (invincibility stars) at $FFFFD200
		move.w	a1,(v_starsobj1+obParent).w
		rts
; ---------------------------------------------------------------------------
+		; give invincibility to sidekick
		_move.b	#id_Obj38,(v_tstarsobj1+obID).w ; load Obj35 (invincibility stars) at $FFFFD300
		move.w	a1,(v_tstarsobj1+obParent).w
/
		rts
; ---------------------------------------------------------------------------

Pow_Delete:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	-
		addq.l	#4,sp
		bra.w	DeleteObject