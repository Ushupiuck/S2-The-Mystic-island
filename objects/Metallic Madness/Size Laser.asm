; Object $BF - downward size-changing beam and ceiling emitter.
; Low subtype 0 shrinks and 1 grows. Pulse hit windows apply per actor.

MMZ_LaserPeriod = 30
MMZ_LaserStep = 4
MMZ_LaserSegments = 7		; 112px leaves a gap at the 120px firing interval
laser_start_y = objoff_30	; pulse launch Y
laser_impact_y = objoff_32	; leading edge at the floor, minus four
laser_top = objoff_34		; top of the visible hit window
laser_spark_timer = objoff_36

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
		move.w	#$300,obPriority(a1)	; behind players and the emitter's nozzle
		move.w	#(MMZ_LaserSegments*16)<<8|4,height_pixels(a1)
		move.b	#4,obHeight(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),d0
		andi.w	#$FFF0,d0
		move.w	d0,obY(a1)
		move.w	d0,laser_start_y(a1)
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
		move.w	obY(a0),d0
		cmpi.w	#Level_YWrapMask+1,d0
		bhs.w	.expire
		andi.w	#$F,d0
		bne.s	.floor
		cmpi.b	#MMZ_LaserSegments-1,obAnim(a0)
		bhs.s	.floor
		addq.b	#1,obAnim(a0)
.floor:
		jsr	(ObjHitFloor).l
		bpl.s	.active
		addq.w	#1,d1			; probe stops one row above the floor
		add.w	d1,obY(a0)
		move.w	obY(a0),laser_impact_y(a0)
		move.b	#2,obRoutine(a0)
		bsr.w	MMZ_LaserMakeSpark
		bra.s	.active
.retract:
		; The tail keeps travelling. Drop one 16px section each time
		; the leading edge would pass the floor.
		move.w	obY(a0),d0
		addq.w	#MMZ_LaserStep,d0
		cmp.w	laser_impact_y(a0),d0
		ble.s	.tip
		subi.w	#16,d0
		subq.b	#1,obAnim(a0)
		bmi.s	.expire
.tip:
		move.w	d0,obY(a0)
.active:
		lea	Ani_MMZ_Laser(pc),a1
		jsr	(AnimateSprite).l
		tst.w	(Debug_placement_mode).w
		bne.s	.draw
		moveq	#0,d0
		move.b	obAnim(a0),d0
		lsl.w	#4,d0
		move.w	obY(a0),d1
		subi.w	#12,d1
		sub.w	d0,d1
		cmp.w	laser_start_y(a0),d1
		bge.s	.top
		move.w	laser_start_y(a0),d1
.top:
		move.w	d1,laser_top(a0)
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
		move.w	#$280,obPriority(a1)
		move.b	#MMZ_LaserSegments,obAnim(a1)
		move.b	#12,laser_spark_timer(a1)
.return:
		rts

MMZ_LaserSpark:
		subq.b	#1,laser_spark_timer(a0)
		jeq	(DeleteObject).l
		lea	Ani_MMZ_Laser(pc),a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l

Ani_MMZ_Laser:
		dc.w .one-Ani_MMZ_Laser,.two-Ani_MMZ_Laser,.three-Ani_MMZ_Laser,.four-Ani_MMZ_Laser
		dc.w .five-Ani_MMZ_Laser,.six-Ani_MMZ_Laser,.seven-Ani_MMZ_Laser,.spark-Ani_MMZ_Laser
.one:		dc.b 2,5,13,$FF
.two:		dc.b 2,6,14,$FF
.three:		dc.b 2,7,15,$FF
.four:		dc.b 2,8,16,$FF
.five:		dc.b 2,9,17,$FF
.six:		dc.b 2,10,18,$FF
.seven:		dc.b 2,11,19,$FF
.spark:		dc.b 2,3,4,$FF

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
