; Object $BF - downward size-changing beam and ceiling emitter.
; Low subtype 0 shrinks and 1 grows. Pulse hit windows apply per actor.

MMZ_LaserPeriod = 30
MMZ_LaserStep = 4
MMZ_LaserRange = 128
laser_top = objoff_30

MMZ_Laser:
		out_of_range.w	.unload
		tst.b	obRoutine(a0)
		bne.s	.fire
		move.b	#2,obRoutine(a0)
		move.l	#Map_MMZ_Laser1,obMap(a0)
		move.b	#1,obFrame(a0)
		btst	#0,obSubtype+1(a0)
		beq.s	.init
		move.l	#Map_MMZ_Laser2,obMap(a0)
		move.b	#2,obFrame(a0)
.init:
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$200,obPriority(a0)
		move.w	#12<<8|8,height_pixels(a0)
		ori.b	#4,obRender(a0)
		move.b	#1,obTimeFrame(a0)
.fire:
		subq.b	#1,obTimeFrame(a0)
		bne.s	.draw
		jsr	(FindFreeObj).l
		bne.s	.retry
		move.l	#MMZ_LaserPulse,code(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	#4,obRender(a1)
		move.w	#$100,obPriority(a1)
		move.w	#MMZ_LaserRange<<8|4,height_pixels(a1)
		move.b	#4,obHeight(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),d0
		andi.w	#$FFF0,d0
		move.w	d0,obY(a1)
		move.w	d0,laser_top(a1)
		move.w	obSubtype(a0),obSubtype(a1)
		move.b	#MMZ_LaserPeriod,obTimeFrame(a0)
		tst.b	obRender(a0)
		bpl.s	.draw
		move.w	#SndID_LaserBurst,d0
		btst	#0,obSubtype+1(a0)
		beq.s	.sound
		move.w	#SndID_LaserBeam,d0
.sound:
		jsr	(PlaySound_Special).l
		bra.s	.draw
.retry:
		move.b	#1,obTimeFrame(a0)
.draw:
		jmp	(DisplaySprite).l
.unload:
		jmp	(UnloadObject).l

MMZ_LaserPulse:
		out_of_range.w	.expire
		tst.b	obRoutine(a0)
		bne.s	.retract
		addq.w	#MMZ_LaserStep,obY(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bmi.s	.impact
		move.w	obY(a0),d0
		cmpi.w	#Level_YWrapMask+1,d0
		bhs.s	.expire
		subi.w	#MMZ_LaserRange,d0
		cmp.w	laser_top(a0),d0
		ble.s	.active
		move.w	d0,laser_top(a0)	; long drops keep the last 128 pixels
		bra.s	.active
.impact:
		add.w	d1,obY(a0)
		move.b	#2,obRoutine(a0)
		bsr.w	MMZ_LaserMakeSpark
		bra.s	.active
.retract:
		addq.w	#MMZ_LaserStep,laser_top(a0)
.active:
		move.w	obY(a0),d0
		sub.w	laser_top(a0),d0
		ble.s	.expire
		subq.w	#1,d0
		lsr.w	#4,d0
		addq.w	#5,d0
		btst	#1,(Timer_frames+1).w
		beq.s	.frame
		addq.w	#8,d0
.frame:
		move.b	d0,obFrame(a0)
		tst.w	(Debug_placement_mode).w
		bne.s	.draw
		tst.b	(f_playerctrl).w
		bne.s	.companion
		lea	(v_player).w,a1
		bsr.w	MMZ_LaserContact
.companion:
		lea	(v_player2).w,a1
		bsr.w	MMZ_LaserContact
.draw:
		jmp	(DisplaySprite).l
.expire:
		jmp	(DeleteObject).l

MMZ_LaserMakeSpark:
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#MMZ_LaserSpark,code(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.w	#4<<8|8,height_pixels(a1)
		move.b	#4,obRender(a1)
		move.w	#$100,obPriority(a1)
		move.b	#12,obTimeFrame(a1)
.return:
		rts

MMZ_LaserSpark:
		subq.b	#1,obTimeFrame(a0)
		jeq	(DeleteObject).l
		moveq	#3,d0
		btst	#1,(Timer_frames+1).w
		beq.s	.frame
		addq.b	#1,d0
.frame:
		move.b	d0,obFrame(a0)
		jmp	(DisplaySprite).l

MMZ_LaserContact:
		jsr	(Player_CanInteract).l
		bcc.s	.return
		tst.b	obControl(a1)
		bne.s	.return
		cmpi.b	#AniIDSonAni_Blank,obAnim(a1)
		beq.s	.return
		moveq	#0,d0
		move.b	default_y_radius(a1),d0
		cmpi.b	#Player_MiniHeight,d0
		seq	d0
		move.b	obSubtype+1(a0),d1
		eor.b	d1,d0
		btst	#0,d0
		bne.s	.return		; already the requested size
		moveq	#0,d1
		move.b	obWidth(a1),d1
		addq.w	#4,d1
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		add.w	d1,d0
		add.w	d1,d1
		cmp.w	d1,d0
		bhs.s	.return
		moveq	#0,d1
		move.b	obHeight(a1),d1
		move.w	obY(a1),d0
		add.w	d1,d0
		cmp.w	laser_top(a0),d0
		bls.s	.return
		sub.w	d1,d0
		sub.w	d1,d0
		move.w	obY(a0),d1
		addq.w	#4,d1
		cmp.w	d1,d0
		bhs.s	.return
		moveq	#1,d0
		and.b	obSubtype+1(a0),d0
		eori.b	#1,d0
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Player_ChangeSize).l
		bcs.s	.restore
		movea.l	(sp),a1
		bsr.s	MMZ_LaserRecoil
.restore:
		movea.l	(sp)+,a0
.return:
		rts

; Use the character's own recoil/landing state without losing rings or shields.
MMZ_LaserRecoil:
		move.w	#-$200,d2
		move.w	obX(a0),d0
		cmp.w	obX(a1),d0
		blo.s	.detach
		neg.w	d2
.detach:
		move.w	d2,obVelX(a0)
		bclr	#status.player.on_object,obStatus(a0)
		beq.s	.airborne
		jsr	(Player_GetStandingObject).l
		moveq	#3,d0
		cmpa.w	#v_player,a0
		beq.s	.release
		addq.b	#1,d0
.release:
		bclr	d0,obStatus(a3)
.airborne:
		clr.b	standonobject(a0)
		andi.b	#1<<status.player.x_flip|1<<status.player.underwater,obStatus(a0)
		bset	#status.player.in_air,obStatus(a0)
		clr.b	tails_flight_flag(a0)
		clr.b	spindash_flag(a0)
		clr.b	jumping(a0)
		clr.b	stick_to_convex(a0)
		clr.b	obAngle(a0)
		clr.w	obInertia(a0)
		move.w	#-$400,obVelY(a0)
		move.b	#4,obRoutine(a0)
		move.b	#AniIDSonAni_Hurt,obAnim(a0)
		cmpi.b	#CharacterID_Tails,character_id(a0)
		bne.s	.return
		jmp	(Tails_ReleaseCarry).l
.return:
		rts

Map_MMZ_Laser1:	binclude	"mappings/sprite/MMZ Laser 1.bin"
Map_MMZ_Laser2:	binclude	"mappings/sprite/MMZ Laser 2.bin"
		even
