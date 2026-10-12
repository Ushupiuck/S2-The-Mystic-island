; ---------------------------------------------------------------------------
; Object 02 - S3&K Tails. Uses this engine's SST, collision and power-up state.
; Flight/swimming, carry and normal CPU behaviors are adapted from skdisasm
; 73de97c6b55055bcb8089c1d55d006b02136f163. Stage-specific cutscenes stay out.
; ---------------------------------------------------------------------------
Obj02:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj02_Index(pc,d0.w),d1
		jmp	Obj02_Index(pc,d1.w)
Obj02_Index:
		dc.w Obj02_Init-Obj02_Index
		dc.w Obj02_Control-Obj02_Index
		dc.w Obj02_Hurt-Obj02_Index
		dc.w Obj02_Dead-Obj02_Index
		dc.w Obj02_ResetLevel-Obj02_Index

Obj02_Init:
		move.b	#2,obRoutine(a0)
		move.b	#tails_height,obHeight(a0)
		move.b	#tails_width,obWidth(a0)
		move.b	#tails_height,default_y_radius(a0)
		move.b	#tails_width,default_x_radius(a0)
		move.b	#CharacterID_Tails,character_id(a0)
		move.l	#Map_Tails,obMap(a0)
		move.w	#make_art_tile(ArtTile_Tails,0,0),obGfx(a0)
		move.w	#$100,obPriority(a0)
		move.b	#$18,width_pixels(a0)
		move.b	#$18,height_pixels(a0)
		move.b	#$84,obRender(a0)
		move.b	#$C,obTopSolidBit(a0)
		move.b	#$D,obLRBSolidBit(a0)
		cmpa.w	#v_player,a0
		beq.s	.primary
		move.w	(v_player+obTopSolidBit).w,obTopSolidBit(a0)
		tst.w	(v_player+obGfx).w
		bpl.s	.primary
		ori.w	#high_priority,obGfx(a0)
.primary:
		movea.l	a0,a2
		jsr	(Player_UpdateSpeed).l
		bsr.w	CreatePlayerDust
		clr.b	flips_remaining(a0)
		move.b	#4,flip_speed(a0)
		move.b	#30,air_left(a0)
		clr.b	tails_flight_flag(a0)
		clr.w	(Tails_CPU_idle_timer).w
		clr.w	(Tails_CPU_flight_timer).w
		clr.w	(Tails_CPU_routine).w
		clr.b	(Tails_CPU_auto_jump_flag).w
		clr.w	(Flying_carrying_Sonic_flag).w
		clr.b	(Tails_LastLoadedDPLC).w
		clr.b	(TailsTails_LastLoadedDPLC).w	; reset body and tail caches together
		bsr.w	Tails_ResetHistory
		move.b	#id_Obj05,(v_player2tails).w
		clr.b	(v_player2tails+obRoutine).w
		move.w	a0,(v_player2tails+obParent).w
		move.b	#-1,(v_player2tails+objoff_34).w
		; Run the first update now, so body art and the separate tail are ready
		; together before the first BuildSprites, as with Sonic's initialization.

Obj02_Control:
		lea	(Tails_top_speed).w,a4
		bsr.w	Tails_Control
		btst	#0,obControl(a0)
		bne.s	.update
		cmpa.w	#v_player,a0
		bne.s	.movement
		btst	#0,(f_playerctrl).w
		bne.s	.update
.movement:
		movem.l	a4-a6,-(sp)
		moveq	#0,d0
		move.b	obStatus(a0),d0
		andi.w	#6,d0
		move.w	Obj02_Modes(pc,d0.w),d1
		jsr	Obj02_Modes(pc,d1.w)
		movem.l	(sp)+,a4-a6
.update:
		btst	#0,obControl(a0)
		beq.s	+
		bsr.w	Tails_ReleaseCarry
+
		bsr.w	Tails_Display
		bsr.w	RecordTailsMoves
		bsr.w	Tails_Water
		move.b	(Primary_Angle).w,next_tilt(a0)
		move.b	(Secondary_Angle).w,tilt(a0)
		btst	#1,obControl(a0)
		bne.s	.touch
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
.touch:
		move.b	obControl(a0),d0
		andi.b	#$A0,d0
		bne.s	.return
		jsr	(TouchResponse).l
.return:
		rts
Obj02_Modes:
		dc.w Obj02_MdNormal-Obj02_Modes
		dc.w Obj02_MdJump-Obj02_Modes
		dc.w Obj02_MdRoll-Obj02_Modes
		dc.w Obj02_MdJump2-Obj02_Modes

Tails_Display:
		move.w	flashtime(a0),d0
		beq.s	.show
		subq.w	#1,flashtime(a0)
		lsr.w	#3,d0
		bcs.s	.show
		st	tails_hidden(a0)		; the tail still animates/uploads while hidden
		bra.w	Obj01_Display.effects	; shared power-up timers; no second flash decrement
.show:
		clr.b	tails_hidden(a0)
		bra.w	Obj01_Display		; queue the body and update its power-up timers

; Physical controller 2 remains intact. AI only writes its logical copy.
Tails_Control:
		cmpa.w	#v_player,a0
		bne.s	.partner
		move.w	(v_jpadholdlogical).w,(v_jpadholdlogical2).w
		tst.b	(f_lockctrl).w
		bne.s	.return
		move.w	(v_jpadhold1).w,(v_jpadholdlogical2).w
		move.w	(v_jpadhold1).w,(v_jpadholdlogical).w
.return:
		rts
.partner:
		move.w	(v_jpadhold2).w,(v_jpadholdlogical2).w
		move.b	(v_jpadhold2).w,d0
		andi.b	#btnUp|btnDn|btnL|btnR|btnABC,d0
		beq.s	.cpu
		move.w	#Tails_CPU_ManualTime,(Tails_CPU_idle_timer).w
.cpu:
		lea	(v_player).w,a1
		move.w	(Tails_CPU_routine).w,d0
		cmpi.w	#8,d0
		bhi.s	.init
		move.w	.index(pc,d0.w),d0
		jmp	.index(pc,d0.w)
.index:
		dc.w .init-.index
		dc.w Tails_Catch_Up_Flying-.index
		dc.w Tails_FlySwim_Unknown-.index
		dc.w TailS3_loc_13D4A-.index
		dc.w TailS3_loc_13F40-.index
.init:
		move.w	#6,(Tails_CPU_routine).w
		clr.b	obControl(a0)
		rts

Tails_GetStandingObject:
		moveq	#0,d0
		move.b	standonobject(a0),d0
		mulu.w	#object_size,d0
		lea	(v_objspace).w,a3
		adda.w	d0,a3
		rts

Tails_ResetHistory:
		lea	(Tails_Pos_Record_Buf).w,a1
		move.w	#bytesToLcnt(Tails_Pos_Record_Buf_End-Tails_Pos_Record_Buf),d0
.loop:
		move.w	obX(a0),(a1)+
		move.w	obY(a0),(a1)+
		dbf	d0,.loop
		clr.w	(Tails_Pos_Record_Index).w
		cmpa.w	#v_player,a0
		bne.s	.return
		jmp	(Sonic_ResetPositionHistory).l
.return:
		rts
RecordTailsMoves:
		move.w	(Tails_Pos_Record_Index).w,d0
		lea	(Tails_Pos_Record_Buf).w,a1
		move.w	obX(a0),(a1,d0.w)
		move.w	obY(a0),2(a1,d0.w)
		addq.b	#4,(Tails_Pos_Record_Index+1).w
		jmp	(Sonic_RecordPos).l	; primary Tails also owns the shared camera history

Tails_ReleaseCarry:
		tst.b	(Flying_carrying_Sonic_flag).w
		beq.s	.return
		clr.b	(v_player+obControl).w
		bset	#status.player.in_air,(v_player+obStatus).w
		clr.w	(Flying_carrying_Sonic_flag).w
.return:
		rts

Obj02_MdNormal:
		bsr.s	Tails_ReleaseCarry
		bsr.w	Tails_CheckSpindash
		bsr.w	Tails_Jump
		jsr	(Sonic_SlopeResist).l
		bsr.w	Tails_InputAcceleration_Path
		bsr.w	Tails_Roll
		bsr.w	Tails_LevelBound
		jsr	(ObjectMove).l
		jsr	(AnglePos).l
		jmp	(Sonic_SlopeRepel).l
Obj02_MdRoll:
		bsr.w	Tails_ReleaseCarry
		tst.b	spindash_flag(a0)
		bne.s	.forced
		bsr.w	Tails_Jump
.forced:
		jsr	(Sonic_RollRepel).l
		bsr.w	Tails_RollSpeed
		bsr.w	Tails_LevelBound
		jsr	(ObjectMove).l
		jsr	(AnglePos).l
		jmp	(Sonic_SlopeRepel).l
Obj02_MdJump2:
		bsr.w	Tails_ReleaseCarry
Obj02_MdJump:
		tst.b	tails_flight_flag(a0)
		bne.s	Tails_FlyingSwimming
		bsr.w	Tails_JumpHeight
		bsr.w	Tails_JumpDirection
		bsr.w	Tails_LevelBound
		jsr	(ObjectMoveAndFall).l
		btst	#status.player.underwater,obStatus(a0)
		beq.s	.collision
		subi.w	#$28,obVelY(a0)
.collision:
		bsr.w	Tails_JumpAngle
		bra.w	Tails_DoLevelCollision
Tails_FlyingSwimming:
		bsr.w	Tails_Move_FlySwim
		bsr.w	Tails_JumpDirection
		bsr.w	Tails_LevelBound
		jsr	(ObjectMove).l
		bsr.w	Tails_JumpAngle
		bsr.w	Tails_DoLevelCollision
		cmpa.w	#v_player,a0
		beq.s	.return
		tst.b	tails_flight_flag(a0)
		beq.w	Tails_ReleaseCarry
		tst.w	(Player_mode).w
		bne.s	.return
		lea	(Flying_carrying_Sonic_flag).w,a2
		lea	(v_player).w,a1
		move.w	(v_jpadholdlogical).w,d0
		bra.w	Tails_Carry_Sonic
.return:
		rts

; Each character owns an air/countdown object; the companion uses air_left.
; Only the primary character controls drowning music and the shared camera.
Tails_Water:
		tst.b	(Water_flag).w
		beq.w	.return
		move.w	(v_waterpos1).w,d0
		cmp.w	obY(a0),d0
		bge.w	.out
		bset	#status.player.underwater,obStatus(a0)
		bne.s	.air
		move.b	#30,air_left(a0)
		movea.l	a0,a2
		jsr	(Player_UpdateSpeed).l
		cmpa.w	#v_player,a0
		bne.s	.bubbles
		jsr	(ResumeMusic).l
		move.b	#id_Obj0A,(v_sonicbubbles).w
		move.b	#$81,(v_sonicbubbles+obSubtype).w
		bra.s	.drag
.bubbles:
		move.b	#id_Obj0A,(v_tailsbubbles).w
		clr.b	(v_tailsbubbles+obRoutine).w
		move.b	#$81,(v_tailsbubbles+obSubtype).w
		move.w	a0,(v_tailsbubbles+obParent).w
.drag:
		tst.b	obControl(a0)
		bne.s	.air
		asr	obVelX(a0)
		asr	obVelY(a0)
		asr	obVelY(a0)
		beq.s	.air
		jsr	(SpawnPlayerSplash).l
		move.w	#sfx_Splash,d0
		jsr	(PlaySound_Special).l
.air:
		cmpa.w	#v_player,a0
		bne.s	.companion
		move.b	(v_air+1).w,air_left(a0)
		bra.s	.return
.companion:
		rts
.out:
		bclr	#status.player.underwater,obStatus(a0)
		beq.s	.return
		move.b	#30,air_left(a0)
		cmpa.w	#v_player,a0
		bne.s	.speed
		jsr	(ResumeMusic).l
.speed:
		movea.l	a0,a2
		jsr	(Player_UpdateSpeed).l
		cmpi.b	#4,obRoutine(a0)
		beq.s	.splash
		tst.b	obControl(a0)
		bne.s	.splash
		cmpi.w	#-Sonic_JumpReleaseSpeed,obVelY(a0)
		blt.s	.splash
		asl	obVelY(a0)
.splash:
		cmpi.b	#AniIDSonAni_Blank,obAnim(a0)
		beq.s	.return
		tst.w	obVelY(a0)
		beq.s	.return
		cmpi.w	#-Sonic_WaterExitSpeedLimit,obVelY(a0)
		bgt.s	.sound
		move.w	#-Sonic_WaterExitSpeedLimit,obVelY(a0)
.sound:
		jsr	(SpawnPlayerSplash).l
		move.w	#sfx_Splash,d0
		jmp	(PlaySound_Special).l
.return:
		rts

Tails_Catch_Up_Flying:
		move.b	(v_jpadholdlogical2).w,d0
		andi.b	#button_A_mask|button_B_mask|button_C_mask|button_start_mask,d0
		bne.s	TailS3_loc_13B50
		move.w	(Timer_frames).w,d0
		andi.w	#$3F,d0
		bne.w	TailS3_locret_13BF6
		tst.b	obControl(a1)
		bmi.w	TailS3_locret_13BF6
		move.b	obStatus(a1),d0
		andi.b	#$80,d0
		bne.w	TailS3_locret_13BF6

TailS3_loc_13B50:
		move.w	#4,(Tails_CPU_routine).w
		move.w	obX(a1),d0
		move.w	d0,obX(a0)
		move.w	d0,(Tails_CPU_target_X).w
		move.w	obY(a1),d0
		move.w	d0,(Tails_CPU_target_Y).w
		subi.w	#$C0,d0
TailS3_loc_13B78:
		move.w	d0,obY(a0)
		ori.w	#high_priority,obGfx(a0)
		move.w	#$100,obPriority(a0)
		moveq	#0,d0
		move.w	d0,obVelX(a0)
		move.w	d0,obVelY(a0)
		move.w	d0,obInertia(a0)
		move.b	d0,flip_turned(a0)
		move.b	d0,tails_flight_flag(a0)
		move.b	#2,obStatus(a0)
		move.b	#30,air_left(a0)
		move.b	#$81,obControl(a0)
		move.b	d0,flips_remaining(a0)
		move.b	d0,flip_speed(a0)
		move.w	d0,move_lock(a0)
		move.w	d0,flashtime(a0)
		move.w	d0,invtime(a0)
		move.w	d0,shoetime(a0)
		move.b	d0,scroll_delay_counter(a0)
		move.w	d0,next_tilt(a0)	; and tilt
		move.b	d0,stick_to_convex(a0)
		move.b	d0,spindash_flag(a0)
		move.w	d0,spindash_counter(a0)
		move.b	d0,jumping(a0)
		move.b	d0,objoff_41(a0)
		movem.l	a1-a3,-(sp)
		jsr	(Player_ClearPowerUps).l
		movea.l	a0,a2
		jsr	(Player_UpdateSpeed).l	; catch-up has reset the underwater status
		movem.l	(sp)+,a1-a3
		move.b	#Tails_FlightBudget,tails_flight_energy(a0)
		bsr.w	Tails_Set_Flying_Animation

TailS3_locret_13BF6:
		rts
; ---------------------------------------------------------------------------

Tails_FlySwim_Unknown:
		tst.b	obRender(a0)
		bmi.s	TailS3_loc_13C3A
		addq.w	#1,(Tails_CPU_flight_timer).w
		cmpi.w	#Tails_CPU_RespawnTime,(Tails_CPU_flight_timer).w
		blo.s	TailS3_loc_13C50
		move.w	#0,(Tails_CPU_flight_timer).w
		move.w	#2,(Tails_CPU_routine).w
		move.b	#$81,obControl(a0)
		move.b	#1<<status.player.in_air,obStatus(a0)
		move.w	#0,obX(a0)
		move.w	#0,obY(a0)
		move.b	#Tails_FlightBudget,tails_flight_energy(a0)
		bsr.w	Tails_Set_Flying_Animation
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13C3A:
		move.b	#Tails_FlightBudget,tails_flight_energy(a0)
		ori.b	#1<<status.player.in_air,obStatus(a0)
		bsr.w	Tails_Set_Flying_Animation
		move.w	#0,(Tails_CPU_flight_timer).w

TailS3_loc_13C50:
		lea	(Sonic_Pos_Record_Buf).w,a2
		move.w	#$10,d2
		lsl.b	#2,d2
		addq.b	#4,d2
		move.w	(Sonic_Pos_Record_Index).w,d3
		sub.b	d2,d3
		move.w	(a2,d3.w),(Tails_CPU_target_X).w
		move.w	2(a2,d3.w),(Tails_CPU_target_Y).w
		move.w	obX(a0),d0
		sub.w	(Tails_CPU_target_X).w,d0
		beq.s	TailS3_loc_13CBE
		move.w	d0,d2
		bpl.s	TailS3_loc_13C7E
		neg.w	d2

TailS3_loc_13C7E:
		lsr.w	#4,d2
		cmpi.w	#$C,d2
		blo.s	TailS3_loc_13C88
		moveq	#$C,d2

TailS3_loc_13C88:
		move.b	obVelX(a1),d1
		bpl.s	TailS3_loc_13C90
		neg.b	d1

TailS3_loc_13C90:
		add.b	d1,d2
		addq.w	#1,d2
		tst.w	d0
		bmi.s	TailS3_loc_13CAA
		bset	#status.player.x_flip,obStatus(a0)
		cmp.w	d0,d2
		blo.s	TailS3_loc_13CA6
		move.w	d0,d2
		moveq	#0,d0

TailS3_loc_13CA6:
		neg.w	d2
		bra.s	TailS3_loc_13CBA
; ---------------------------------------------------------------------------

TailS3_loc_13CAA:
		bclr	#status.player.x_flip,obStatus(a0)
		neg.w	d0
		cmp.w	d0,d2
		blo.s	TailS3_loc_13CBA
		move.b	d0,d2
		moveq	#0,d0

TailS3_loc_13CBA:
		add.w	d2,obX(a0)

TailS3_loc_13CBE:
		moveq	#1,d2
		move.w	obY(a0),d1
		sub.w	(Tails_CPU_target_Y).w,d1
		beq.s	TailS3_loc_13CD2
		bmi.s	TailS3_loc_13CCE
		neg.w	d2

TailS3_loc_13CCE:
		add.w	d2,obY(a0)

TailS3_loc_13CD2:
		lea	(Sonic_Stat_Record_Buf).w,a2
		move.b	2(a2,d3.w),d2
		andi.b	#$80,d2
		bne.s	TailS3_loc_13D42
		or.w	d0,d1
		bne.s	TailS3_loc_13D42
		cmpi.b	#6,(v_player+obRoutine).w
		bhs.s	TailS3_loc_13D42
		move.w	#6,(Tails_CPU_routine).w
		move.b	#0,obControl(a0)
		move.b	#0,obAnim(a0)
		move.w	#0,obVelX(a0)
		move.w	#0,obVelY(a0)
		move.w	#0,obInertia(a0)
		andi.b	#1<<status.player.underwater,obStatus(a0)
		ori.b	#1<<status.player.in_air,obStatus(a0)
		move.w	#0,move_lock(a0)
		andi.w	#drawing_mask,obGfx(a0)
		tst.b	obGfx(a1)
		bpl.s	TailS3_loc_13D34
		ori.w	#high_priority,obGfx(a0)

TailS3_loc_13D34:
		move.b	obTopSolidBit(a1),obTopSolidBit(a0)
		move.b	obLRBSolidBit(a1),obLRBSolidBit(a0)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13D42:
		move.b	#$81,obControl(a0)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13D4A:
		cmpi.b	#6,(v_player+obRoutine).w
		blo.s	TailS3_loc_13D78
		move.w	#4,(Tails_CPU_routine).w
		move.b	#0,spindash_flag(a0)
		move.w	#0,spindash_counter(a0)
		move.b	#$81,obControl(a0)
		move.b	#1<<status.player.in_air,obStatus(a0)
		move.b	#$20,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13D78:
		bsr.w	TailS3_sub_13EFC
		tst.w	(Tails_CPU_idle_timer).w
		bne.w	TailS3_loc_13EBE
		tst.b	obControl(a0)
		bmi.w	TailS3_loc_13EBE
		tst.w	move_lock(a0)
		beq.s	TailS3_loc_13DA6
		tst.w	obInertia(a0)
		bne.s	TailS3_loc_13DA6
		move.w	#8,(Tails_CPU_routine).w

TailS3_loc_13DA6:
		lea	(Sonic_Pos_Record_Buf).w,a2
		move.w	#$10,d1
		lsl.b	#2,d1
		addq.b	#4,d1
		move.w	(Sonic_Pos_Record_Index).w,d0
		sub.b	d1,d0
		move.w	(a2,d0.w),d2
		btst	#status.player.on_object,obStatus(a1)
		bne.s	TailS3_loc_13DD0
		cmpi.w	#$400,obInertia(a1)
		bge.s	TailS3_loc_13DD0
		subi.w	#$20,d2

TailS3_loc_13DD0:
		move.w	2(a2,d0.w),d3
		lea	(Sonic_Stat_Record_Buf).w,a2
		move.w	(a2,d0.w),d1
		move.b	2(a2,d0.w),d4
		move.w	d1,d0
		btst	#status.player.pushing,obStatus(a0)
		beq.s	TailS3_loc_13DF2
		btst	#5,d4
		beq.w	TailS3_loc_13E9C

TailS3_loc_13DF2:
		sub.w	obX(a0),d2
		beq.s	TailS3_loc_13E50
		bpl.s	TailS3_loc_13E26
		neg.w	d2
		cmpi.w	#$30,d2
		blo.s	TailS3_loc_13E0A
		andi.w	#$F3F3,d1
		ori.w	#$404,d1

TailS3_loc_13E0A:
		tst.w	obInertia(a0)
		beq.s	TailS3_loc_13E64
		btst	#status.player.x_flip,obStatus(a0)
		beq.s	TailS3_loc_13E64
		btst	#0,obControl(a0)
		bne.s	TailS3_loc_13E64
		subq.w	#1,obX(a0)
		bra.s	TailS3_loc_13E64
; ---------------------------------------------------------------------------

TailS3_loc_13E26:
		cmpi.w	#$30,d2
		blo.s	TailS3_loc_13E34
		andi.w	#$F3F3,d1
		ori.w	#$808,d1

TailS3_loc_13E34:
		tst.w	obInertia(a0)
		beq.s	TailS3_loc_13E64
		btst	#status.player.x_flip,obStatus(a0)
		bne.s	TailS3_loc_13E64
		btst	#0,obControl(a0)
		bne.s	TailS3_loc_13E64
		addq.w	#1,obX(a0)
		bra.s	TailS3_loc_13E64
; ---------------------------------------------------------------------------

TailS3_loc_13E50:
		bclr	#status.player.x_flip,obStatus(a0)
		move.b	d4,d0
		andi.b	#1,d0
		beq.s	TailS3_loc_13E64
		bset	#status.player.x_flip,obStatus(a0)

TailS3_loc_13E64:
		tst.b	(Tails_CPU_auto_jump_flag).w
		beq.s	TailS3_loc_13E7C
		ori.w	#((button_A_mask|button_B_mask|button_C_mask)<<8)|0,d1
		btst	#status.player.in_air,obStatus(a0)
		bne.s	TailS3_loc_13EB8
		move.b	#0,(Tails_CPU_auto_jump_flag).w

TailS3_loc_13E7C:
		move.w	(Timer_frames).w,d0
		andi.w	#$FF,d0
		beq.s	TailS3_loc_13E8C
		cmpi.w	#$40,d2
		bhs.s	TailS3_loc_13EB8

TailS3_loc_13E8C:
		sub.w	obY(a0),d3
		beq.s	TailS3_loc_13EB8
		bpl.s	TailS3_loc_13EB8
		neg.w	d3
		cmpi.w	#$20,d3
		blo.s	TailS3_loc_13EB8

TailS3_loc_13E9C:
		move.b	(Timer_frames+1).w,d0
		andi.b	#$3F,d0
		bne.s	TailS3_loc_13EB8
		cmpi.b	#8,obAnim(a0)
		beq.s	TailS3_loc_13EB8
		ori.w	#((button_A_mask|button_B_mask|button_C_mask)<<8)|(button_A_mask|button_B_mask|button_C_mask),d1
		move.b	#1,(Tails_CPU_auto_jump_flag).w

TailS3_loc_13EB8:
		move.w	d1,(v_jpadholdlogical2).w
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13EBE:
		tst.w	(Tails_CPU_idle_timer).w
		beq.s	TailS3_locret_13EC8
		subq.w	#1,(Tails_CPU_idle_timer).w

TailS3_locret_13EC8:
		rts

; =============== S U B R O U T I N E =======================================


TailS3_sub_13ECA:
		move.w	#0,(Tails_CPU_idle_timer).w
		move.w	#0,(Tails_CPU_flight_timer).w
		move.w	#2,(Tails_CPU_routine).w
		move.b	#$81,obControl(a0)
		move.b	#1<<status.player.in_air,obStatus(a0)
		move.w	#$7F00,obX(a0)
		move.w	#0,obY(a0)
		move.b	#0,tails_flight_flag(a0)
		rts
; End of function TailS3_sub_13ECA


; =============== S U B R O U T I N E =======================================


TailS3_sub_13EFC:
		tst.b	obRender(a0)
		bmi.s	TailS3_loc_13F28
		btst	#status.player.on_object,obStatus(a0)
		beq.s	TailS3_loc_13F18
		moveq	#0,d0
		bsr.w	Tails_GetStandingObject
		move.w	(Tails_CPU_interact).w,d0
		moveq	#0,d1
		move.b	obID(a3),d1
		cmp.w	d1,d0
		bne.s	TailS3_loc_13F24

TailS3_loc_13F18:
		addq.w	#1,(Tails_CPU_flight_timer).w
		cmpi.w	#Tails_CPU_RespawnTime,(Tails_CPU_flight_timer).w
		blo.s	TailS3_loc_13F2E

TailS3_loc_13F24:
		bra.w	TailS3_sub_13ECA
; ---------------------------------------------------------------------------

TailS3_loc_13F28:
		move.w	#0,(Tails_CPU_flight_timer).w

TailS3_loc_13F2E:
		btst	#status.player.on_object,obStatus(a0)
		beq.s	TailS3_locret_13F3E
		bsr.w	Tails_GetStandingObject
		moveq	#0,d0
		move.b	obID(a3),d0
		move.w	d0,(Tails_CPU_interact).w

TailS3_locret_13F3E:
		rts
; End of function TailS3_sub_13EFC

; ---------------------------------------------------------------------------

TailS3_loc_13F40:
		bsr.w	TailS3_sub_13EFC
		tst.w	(Tails_CPU_idle_timer).w
		bne.w	TailS3_locret_13FBE
		tst.w	move_lock(a0)
		bne.s	TailS3_locret_13FBE
		tst.b	spindash_flag(a0)
		bne.s	TailS3_loc_13F94
		tst.w	obInertia(a0)
		bne.s	TailS3_locret_13FBE
		bclr	#status.player.x_flip,obStatus(a0)
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bcs.s	TailS3_loc_13F74
		bset	#status.player.x_flip,obStatus(a0)

TailS3_loc_13F74:
		move.w	#(button_down_mask<<8)|button_down_mask,(v_jpadholdlogical2).w
		move.b	(Timer_frames+1).w,d0
		andi.b	#$7F,d0
		beq.s	TailS3_loc_13FA4
		cmpi.b	#8,obAnim(a0)
		bne.s	TailS3_locret_13FBE
		move.w	#((button_A_mask|button_B_mask|button_C_mask|button_down_mask)<<8)|(button_A_mask|button_B_mask|button_C_mask|button_down_mask),(v_jpadholdlogical2).w
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13F94:
		move.w	#(button_down_mask<<8)|button_down_mask,(v_jpadholdlogical2).w
		move.b	(Timer_frames+1).w,d0
		andi.b	#$7F,d0
		bne.s	TailS3_loc_13FB2

TailS3_loc_13FA4:
		move.w	#(0<<8)|0,(v_jpadholdlogical2).w
		move.w	#6,(Tails_CPU_routine).w
		rts
; ---------------------------------------------------------------------------

TailS3_loc_13FB2:
		andi.b	#$1F,d0
		bne.s	TailS3_locret_13FBE
		ori.w	#((button_A_mask|button_B_mask|button_C_mask)<<8)|(button_A_mask|button_B_mask|button_C_mask),(v_jpadholdlogical2).w

TailS3_locret_13FBE:
		rts
; ---------------------------------------------------------------------------


Tails_Carry_Sonic:
		tst.b	(a2)
		beq.w	TailS3_loc_14534
		cmpi.b	#4,obRoutine(a1)
		bhs.w	TailS3_loc_14466
		btst	#status.player.in_air,obStatus(a1)
		beq.w	TailS3_loc_1445A
		move.w	(Tails_Carry_SavedXSpeed).w,d1
		cmp.w	obVelX(a1),d1
		bne.s	TailS3_loc_1445A
		move.w	(Tails_Carry_SavedYSpeed).w,d1
		cmp.w	obVelY(a1),d1
		bne.s	TailS3_loc_14460
		tst.b	obControl(a1)
		bmi.s	TailS3_loc_1446A
		andi.b	#button_A_mask|button_B_mask|button_C_mask,d0
		beq.w	TailS3_loc_14474
		clr.b	obControl(a1)
		clr.b	(a2)
		move.b	#$12,1(a2)
		andi.w	#(button_up_mask|button_down_mask|button_left_mask|button_right_mask)<<8,d0
		beq.w	TailS3_loc_14410
		move.b	#$3C,1(a2)

TailS3_loc_14410:
		btst	#button_left+8,d0
		beq.s	TailS3_loc_1441C
		move.w	#-$200,obVelX(a1)

TailS3_loc_1441C:
		btst	#button_right+8,d0
		beq.s	TailS3_loc_14428
		move.w	#$200,obVelX(a1)

TailS3_loc_14428:
		move.w	#-$380,obVelY(a1)
		bset	#status.player.in_air,obStatus(a1)
		move.b	#1,jumping(a1)
		move.b	#$E,obHeight(a1)
		move.b	#7,obWidth(a1)
		move.b	#2,obAnim(a1)
		bset	#status.player.rolling,obStatus(a1)
		bclr	#status.player.rolljumping,obStatus(a1)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_1445A:
		move.w	#-$100,obVelY(a1)

TailS3_loc_14460:
		move.b	#0,jumping(a1)

TailS3_loc_14466:
		clr.b	obControl(a1)

TailS3_loc_1446A:
		clr.b	(a2)
		move.b	#$3C,1(a2)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_14474:
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addi.w	#Tails_CarriedYOffset,obY(a1)
TailS3_loc_14492:
		andi.b	#$FC,obRender(a1)
		andi.b	#$FE,obStatus(a1)
		move.b	obStatus(a0),d0
		andi.b	#1,d0
		or.b	d0,obRender(a1)
		or.b	d0,obStatus(a1)
TailS3_loc_144BA:
		subq.b	#1,obTimeFrame(a1)
		bpl.s	TailS3_loc_144F8
		move.b	#Sonic_CarriedFrameDelay,obTimeFrame(a1)
		moveq	#0,d1
		move.b	obAniFrame(a1),d1
		addq.b	#1,obAniFrame(a1)
		move.b	AniRaw_Tails_Carry(pc,d1.w),d0
		cmpi.b	#-1,d0
		bne.s	TailS3_loc_144E4
		move.b	#0,obAniFrame(a1)
		move.b	AniRaw_Tails_Carry(pc),d0

TailS3_loc_144E4:
		move.b	d0,obFrame(a1)

TailS3_loc_144F8:
		; Retry a deferred upload every frame; the shared loader skips cached art.
		moveq	#0,d0
		move.b	obFrame(a1),d0
		move.l	a2,-(sp)
		jsr	(Perform_Player_DPLC).l
		movea.l	(sp)+,a2
		move.w	obVelX(a0),(v_player+obVelX).w
		move.w	obVelX(a0),(Tails_Carry_SavedXSpeed).w
		move.w	obVelY(a0),(v_player+obVelY).w
		move.w	obVelY(a0),(Tails_Carry_SavedYSpeed).w
		movem.l	d0-a6,-(sp)
		lea	(v_player).w,a0
		bsr.w	Sonic_DoLevelCollision
		movem.l	(sp)+,d0-a6
		rts
; ---------------------------------------------------------------------------
SonAni_Carried:
		dc.b Sonic_CarriedFrameDelay	; also available through Sonic's normal animation table
AniRaw_Tails_Carry:
		; Existing prototype poses: centre, sway left, centre, sway right.
		dc.b SonicFrame_CarriedBase+2,SonicFrame_CarriedBase+1,SonicFrame_CarriedBase,SonicFrame_CarriedBase+1
		dc.b SonicFrame_CarriedBase+2,SonicFrame_CarriedBase+3,SonicFrame_CarriedBase+4,SonicFrame_CarriedBase+3,afEnd
		even
; ---------------------------------------------------------------------------

TailS3_loc_14534:
		tst.b	1(a2)
		beq.s	TailS3_loc_14542
		subq.b	#1,1(a2)
		bne.w	TailS3_locret_1459C

TailS3_loc_14542:
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		addi.w	#$10,d0
		cmpi.w	#$20,d0
		bhs.w	TailS3_locret_1459C
		move.w	obY(a1),d1
		sub.w	obY(a0),d1
		subi.w	#$20,d1
TailS3_loc_1456C:
		cmpi.w	#$10,d1
		bhs.w	TailS3_locret_1459C
		tst.b	obControl(a1)
		bne.s	TailS3_locret_1459C
		cmpi.b	#4,obRoutine(a1)
		bhs.s	TailS3_locret_1459C
		tst.w	(Debug_placement_mode).w
		bne.s	TailS3_locret_1459C
		tst.b	spindash_flag(a1)
		bne.s	TailS3_locret_1459C
		bsr.s	TailS3_sub_1459E
		move.w	#sfx_Grab,d0
		jsr	(PlaySound_Special).l
		move.b	#1,(a2)

TailS3_locret_1459C:
		rts
; End of function Tails_Carry_Sonic


; =============== S U B R O U T I N E =======================================


TailS3_sub_1459E:
		clr.w	obVelX(a1)
		clr.w	obVelY(a1)
		clr.w	obInertia(a1)
		clr.w	obAngle(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		addi.w	#Tails_CarriedYOffset,obY(a1)
		move.w	#AniIDSonAni_Carried<<8,obAnim(a1)	; and obPrevAni
		move.b	#SonicFrame_CarriedFirst,obFrame(a1)
		move.b	#0,obTimeFrame(a1)
		move.b	#0,obAniFrame(a1)
		move.b	#3,obControl(a1)
		bset	#status.player.in_air,obStatus(a1)
		bclr	#status.player.rolljumping,obStatus(a1)
		move.b	#0,spindash_flag(a1)
		andi.b	#$FC,obRender(a1)
		andi.b	#$FE,obStatus(a1)
		move.b	obStatus(a0),d0
		andi.b	#1,d0
		or.b	d0,obRender(a1)
		or.b	d0,obStatus(a1)
		move.w	obVelX(a0),(Tails_Carry_SavedXSpeed).w
		move.w	obVelX(a0),obVelX(a1)
		move.w	obVelY(a0),(Tails_Carry_SavedYSpeed).w
		move.w	obVelY(a0),obVelY(a1)
		; The pickup frame must upload the hanging pose before either sprite is drawn.
		move.w	#SonicFrame_CarriedFirst,d0
		move.l	a2,-(sp)
		jsr	(Perform_Player_DPLC).l
		movea.l	(sp)+,a2
TailS3_locret_14630:
		rts
; End of function TailS3_sub_1459E


; =============== S U B R O U T I N E =======================================



Tails_Move_FlySwim:
		move.b	(Timer_frames+1).w,d0
		andi.b	#1,d0
		beq.s	TailS3_loc_14836
		tst.b	tails_flight_energy(a0)
		beq.s	TailS3_loc_14836
		subq.b	#1,tails_flight_energy(a0)

TailS3_loc_14836:
		cmpi.b	#1,tails_flight_flag(a0)
		beq.s	TailS3_loc_14860
		cmpi.w	#-Tails_FlapRiseLimit,obVelY(a0)
		blt.s	TailS3_loc_14858
		subi.w	#Tails_FlapAcceleration,obVelY(a0)
		addq.b	#1,tails_flight_flag(a0)
		cmpi.b	#Tails_FlapStateLimit,tails_flight_flag(a0)
		bne.s	TailS3_loc_1485E

TailS3_loc_14858:
		move.b	#1,tails_flight_flag(a0)

TailS3_loc_1485E:
		bra.s	TailS3_loc_14892
; ---------------------------------------------------------------------------

TailS3_loc_14860:
		move.b	(v_jpadpresslogical2).w,d0
		andi.b	#button_A_mask|button_B_mask|button_C_mask,d0
		beq.s	TailS3_loc_1488C
		cmpi.w	#-Tails_FlapRiseLimit,obVelY(a0)
		blt.s	TailS3_loc_1488C
		tst.b	tails_flight_energy(a0)
		beq.s	TailS3_loc_1488C
		btst	#status.player.underwater,obStatus(a0)
		beq.s	TailS3_loc_14886
		tst.b	(Flying_carrying_Sonic_flag).w
		bne.s	TailS3_loc_1488C

TailS3_loc_14886:
		move.b	#2,tails_flight_flag(a0)

TailS3_loc_1488C:
		addi.w	#Tails_FlightGravity,obVelY(a0)

TailS3_loc_14892:
		move.w	(Camera_Min_Y_pos).w,d0
		addi.w	#$10,d0
		cmp.w	obY(a0),d0
		blt.s	Tails_Set_Flying_Animation
		tst.w	obVelY(a0)
		bpl.s	Tails_Set_Flying_Animation
		move.w	#0,obVelY(a0)
; End of function Tails_Move_FlySwim


; =============== S U B R O U T I N E =======================================


Tails_Set_Flying_Animation:
		btst	#status.player.underwater,obStatus(a0)
		bne.s	TailS3_loc_14914
		moveq	#$20,d0
		tst.w	obVelY(a0)
		bpl.s	TailS3_loc_148C4
		moveq	#$21,d0

TailS3_loc_148C4:
		tst.b	(Flying_carrying_Sonic_flag).w
		beq.s	TailS3_loc_148CC
		addq.b	#2,d0

TailS3_loc_148CC:
		tst.b	tails_flight_energy(a0)
		bne.s	TailS3_loc_148F4
		moveq	#$24,d0
		move.b	d0,obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	TailS3_locret_148F2
		move.b	(Timer_frames+1).w,d0
		addq.b	#8,d0
		andi.b	#$F,d0
		bne.s	TailS3_locret_148F2
		move.w	#sfx_FlyTired,d0
		jsr	(PlaySound_Special).l

TailS3_locret_148F2:
		rts
; ---------------------------------------------------------------------------

TailS3_loc_148F4:
		move.b	d0,obAnim(a0)
		tst.b	obRender(a0)
		bpl.s	TailS3_locret_14912
		move.b	(Timer_frames+1).w,d0
		addq.b	#8,d0
		andi.b	#$F,d0
		bne.s	TailS3_locret_14912
		move.w	#sfx_Flying,d0
		jsr	(PlaySound_Special).l

TailS3_locret_14912:
		rts
; ---------------------------------------------------------------------------

TailS3_loc_14914:
		moveq	#$25,d0
		tst.w	obVelY(a0)
		bpl.s	TailS3_loc_1491E
		moveq	#$26,d0

TailS3_loc_1491E:
		tst.b	(Flying_carrying_Sonic_flag).w
		beq.s	TailS3_loc_14926
		moveq	#$27,d0

TailS3_loc_14926:
		tst.b	tails_flight_energy(a0)
		bne.s	TailS3_loc_1492E
		moveq	#$28,d0

TailS3_loc_1492E:
		move.b	d0,obAnim(a0)
		rts
; End of function Tails_Set_Flying_Animation

; ---------------------------------------------------------------------------


Tails_InputAcceleration_Path:
		move.w	(Tails_top_speed).w,d6
		move.w	(Tails_acceleration).w,d5
		move.w	(Tails_deceleration).w,d4
		tst.b	obStatusSecondary(a0)
		bmi.w	TailS3_loc_14B5C
		tst.w	move_lock(a0)
		bne.w	Tails_ResetScr
		btst	#button_left,(v_jpadholdlogical2).w
		beq.s	TailS3_loc_14A0A
		bsr.w	TailS3_sub_14C20

TailS3_loc_14A0A:
		btst	#button_right,(v_jpadholdlogical2).w
		beq.s	TailS3_loc_14A16
		bsr.w	TailS3_sub_14CAC

TailS3_loc_14A16:
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
		bne.w	Tails_ResetScr
		tst.w	obInertia(a0)
		bne.w	Tails_ResetScr
		bclr	#status.player.pushing,obStatus(a0)
		move.b	#5,obAnim(a0)
		btst	#status.player.on_object,obStatus(a0)
		beq.s	TailS3_loc_14A6C
		bsr.w	Tails_GetStandingObject
		movea.l	a3,a1
		tst.b	obStatus(a1)
		bmi.s	TailS3_loc_14AA0
		moveq	#0,d1
		move.b	width_pixels(a1),d1
		move.w	d1,d2
		add.w	d2,d2
		subq.w	#4,d2
		add.w	obX(a0),d1
		sub.w	obX(a1),d1
		cmpi.w	#4,d1
		blt.s	TailS3_loc_14A92
		cmp.w	d2,d1
		bge.s	TailS3_loc_14A82
		bra.s	TailS3_loc_14AA0
; ---------------------------------------------------------------------------

TailS3_loc_14A6C:
		move.w	obX(a0),d3
		bsr.w	ChkFloorEdge_Part2
		cmpi.w	#$C,d1
		blt.s	TailS3_loc_14AA0
		cmpi.b	#3,next_tilt(a0)
		bne.s	TailS3_loc_14A8A

TailS3_loc_14A82:
		bclr	#status.player.x_flip,obStatus(a0)
		bra.s	TailS3_loc_14A98
; ---------------------------------------------------------------------------

TailS3_loc_14A8A:
		cmpi.b	#3,tilt(a0)
		bne.s	TailS3_loc_14AA0

TailS3_loc_14A92:
		bset	#status.player.x_flip,obStatus(a0)

TailS3_loc_14A98:
		move.b	#6,obAnim(a0)
		bra.w	Tails_ResetScr
; ---------------------------------------------------------------------------

TailS3_loc_14AA0:
		bra.w	Tails_Duck

TailS3_loc_14B26:
TailS3_loc_14B30:
		move.b	(v_jpadholdlogical2).w,d0
		andi.b	#button_left_mask|button_right_mask,d0
		bne.s	TailS3_loc_14B5C
		move.w	obInertia(a0),d0
		beq.s	TailS3_loc_14B5C
		bmi.s	TailS3_loc_14B50
		sub.w	d5,d0
		bcc.s	TailS3_loc_14B4A
		move.w	#0,d0

TailS3_loc_14B4A:
		move.w	d0,obInertia(a0)
		bra.s	TailS3_loc_14B5C
; ---------------------------------------------------------------------------

TailS3_loc_14B50:
		add.w	d5,d0
		bcc.s	TailS3_loc_14B58
		move.w	#0,d0

TailS3_loc_14B58:
		move.w	d0,obInertia(a0)

TailS3_loc_14B5C:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		move.w	d1,obVelX(a0)
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)

TailS3_loc_14B7A:
		jmp	(Player_CheckWallsOnGround).l
; End of function Tails_InputAcceleration_Path


; =============== S U B R O U T I N E =======================================


TailS3_sub_14C20:
		move.w	obInertia(a0),d0
		beq.s	TailS3_loc_14C28
		bpl.s	TailS3_loc_14C5A

TailS3_loc_14C28:
		bset	#status.player.x_flip,obStatus(a0)
		bne.s	TailS3_loc_14C3C
		bclr	#status.player.pushing,obStatus(a0)
		move.b	#1,obPrevAni(a0)

TailS3_loc_14C3C:
		sub.w	d5,d0
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0
		bgt.s	TailS3_loc_14C4E
		add.w	d5,d0
		cmp.w	d1,d0
		ble.s	TailS3_loc_14C4E
		move.w	d1,d0

TailS3_loc_14C4E:
		move.w	d0,obInertia(a0)
		move.b	#0,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_14C5A:
		sub.w	d4,d0
		bcc.s	TailS3_loc_14C62
		move.w	#-$80,d0

TailS3_loc_14C62:
		move.w	d0,obInertia(a0)
	if FixBugs
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
	else
		; These three instructions partially overwrite the inertia value in
		; 'd0'! This causes the character to trigger their skidding
		; animation at different speeds depending on whether they're going
		; right or left. To fix this, make these instructions use 'd1'
		; instead.
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
	endif
		bne.s	TailS3_locret_14CAA
		cmpi.w	#$400,d0
		blt.s	TailS3_locret_14CAA
		tst.b	flip_turned(a0)
		bmi.s	TailS3_locret_14CAA
		move.w	#sfx_Skid,d0
		jsr	(PlaySound_Special).l
		move.b	#$D,obAnim(a0)
		bclr	#status.player.x_flip,obStatus(a0)

TailS3_locret_14CAA:
		rts
; End of function TailS3_sub_14C20


; =============== S U B R O U T I N E =======================================


TailS3_sub_14CAC:
		move.w	obInertia(a0),d0
		bmi.s	TailS3_loc_14CE0
		bclr	#status.player.x_flip,obStatus(a0)
		beq.s	TailS3_loc_14CC6
		bclr	#status.player.pushing,obStatus(a0)
		move.b	#1,obPrevAni(a0)

TailS3_loc_14CC6:
		add.w	d5,d0
		cmp.w	d6,d0
		blt.s	TailS3_loc_14CD4
		sub.w	d5,d0
		cmp.w	d6,d0
		bge.s	TailS3_loc_14CD4
		move.w	d6,d0

TailS3_loc_14CD4:
		move.w	d0,obInertia(a0)
		move.b	#0,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

TailS3_loc_14CE0:
		add.w	d4,d0
		bcc.s	TailS3_loc_14CE8
		move.w	#$80,d0

TailS3_loc_14CE8:
		move.w	d0,obInertia(a0)
	if FixBugs
		move.b	obAngle(a0),d1
		addi.b	#$20,d1
		andi.b	#$C0,d1
	else
		; These three instructions partially overwrite the inertia value in
		; 'd0'! This causes the character to trigger their skidding
		; animation at different speeds depending on whether they're going
		; right or left. To fix this, make these instructions use 'd1'
		; instead.
		move.b	obAngle(a0),d0
		addi.b	#$20,d0
		andi.b	#$C0,d0
	endif
		bne.s	TailS3_locret_14D30
		cmpi.w	#-$400,d0
		bgt.s	TailS3_locret_14D30
		tst.b	flip_turned(a0)
		bmi.s	TailS3_locret_14D30
		move.w	#sfx_Skid,d0
		jsr	(PlaySound_Special).l
		move.b	#$D,obAnim(a0)
		bset	#status.player.x_flip,obStatus(a0)

TailS3_locret_14D30:
		rts
; End of function TailS3_sub_14CAC


; =============== S U B R O U T I N E =======================================



Tails_Duck:
		btst	#button_down,(v_jpadholdlogical2).w	; is down being pressed?
		beq.s	Tails_LookUp			; if not, branch
		move.b	#AniIDSonAni_Duck,obAnim(a0)	; use "ducking" animation
		cmpa.w	#v_player,a0
		bne.w	TailS3_loc_14B26
		addq.b	#1,scroll_delay_counter(a0)
		cmpi.b	#Camera_LookDelay,scroll_delay_counter(a0)
		blo.s	Tails_ResetScr_Part2
		move.b	#Camera_LookDelay,scroll_delay_counter(a0)
		cmpi.w	#Camera_LookDownLimit,(Camera_Y_pos_bias).w
		beq.w	TailS3_loc_14B26
		subq.w	#Camera_LookPanSpeed,(Camera_Y_pos_bias).w
		bra.w	TailS3_loc_14B26

Tails_LookUp:
		btst	#button_up,(v_jpadholdlogical2).w	; is up being pressed?
		beq.s	Tails_ResetScr			; if not, branch
		move.b	#AniIDSonAni_LookUp,obAnim(a0)	; use "looking up" animation
		cmpa.w	#v_player,a0			; only the camera's player can move its bias
		bne.w	TailS3_loc_14B26
		addq.b	#1,scroll_delay_counter(a0)
		cmpi.b	#Camera_LookDelay,scroll_delay_counter(a0)
		blo.s	Tails_ResetScr_Part2
		move.b	#Camera_LookDelay,scroll_delay_counter(a0)
		cmpi.w	#Camera_LookUpLimit,(Camera_Y_pos_bias).w
		beq.w	TailS3_loc_14B26
		addq.w	#Camera_LookPanSpeed,(Camera_Y_pos_bias).w
		bra.w	TailS3_loc_14B26
; ---------------------------------------------------------------------------
; loc_1C1A2:
Tails_ResetScr_Traction:
		bsr.w	Player_ResetScr
		bra.w	TailS3_loc_14B5C
Tails_ResetScr:
		bsr.w	Player_ResetScr
		bra.w	TailS3_loc_14B26
Tails_ResetScr_Part2:
		bsr.w	Player_ResetScr_Part2
		bra.w	TailS3_loc_14B26

; ---------------------------------------------------------------------------
; updates Tails's speed on the ground
; ---------------------------------------------------------------------------


Tails_RollSpeed:
		bsr.w	Player_ResetScr
		move.w	(Tails_acceleration).w,d5
		asr.w	#1,d5
		move.w	#Sonic_RollBraking,d4
		tst.b	spindash_flag(a0)
		bmi.w	.velocity
		tst.b	(f_slidemode).w
		bne.w	.velocity
		btst	#status_secondary.sliding,obStatusSecondary(a0)
		bne.w	.velocity
		tst.w	move_lock(a0)
		bne.s	.friction
		btst	#button_left,(v_jpadholdlogical2).w
		beq.s	.notleft
		bsr.w	Tails_RollLeft
.notleft:
		btst	#button_right,(v_jpadholdlogical2).w
		beq.s	.friction
		bsr.w	Tails_RollRight
.friction:
		move.w	obInertia(a0),d0
		beq.s	.checkstop
		bmi.s	.left
		sub.w	d5,d0
		bhs.s	.setspeed
		clr.w	d0
.setspeed:
		move.w	d0,obInertia(a0)
		bra.s	.checkstop
.left:
		add.w	d5,d0
		bhs.s	.setleft
		clr.w	d0
.setleft:
		move.w	d0,obInertia(a0)
.checkstop:
		mvabs.w	obInertia(a0),d0
		cmpi.w	#Sonic_RollStopSpeed,d0
		bhs.s	.velocity
		tst.b	spindash_flag(a0)
		bne.s	.keeprolling
		bclr	#status.player.rolling,obStatus(a0)
		move.b	obHeight(a0),d0
		move.b	default_y_radius(a0),obHeight(a0)
		move.b	default_x_radius(a0),obWidth(a0)
		move.b	#AniIDSonAni_Wait,obAnim(a0)
		sub.b	default_y_radius(a0),d0
		ext.w	d0
		add.w	d0,obY(a0)
		bra.s	.velocity
.keeprolling:
		move.w	#Sonic_ForcedRollSpeed,obInertia(a0)
		btst	#status.player.x_flip,obStatus(a0)
		beq.s	.velocity
		neg.w	obInertia(a0)
.velocity:
		move.b	obAngle(a0),d0
		jsr	(CalcSine).l
		muls.w	obInertia(a0),d0
		asr.l	#8,d0
		move.w	d0,obVelY(a0)
		muls.w	obInertia(a0),d1
		asr.l	#8,d1
		cmpi.w	#Sonic_RollMaxXSpeed,d1
		ble.s	.checkleftcap
		move.w	#Sonic_RollMaxXSpeed,d1
.checkleftcap:
		cmpi.w	#-Sonic_RollMaxXSpeed,d1
		bge.s	.setx
		move.w	#-Sonic_RollMaxXSpeed,d1
.setx:
		move.w	d1,obVelX(a0)
		bra.w	Player_CheckWallsOnGround


Tails_RollLeft:
		move.w	obInertia(a0),d0
		beq.s	TailPhysics_loc_100C8
		bpl.s	TailPhysics_loc_100D6

TailPhysics_loc_100C8:
		bset	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_100D6:
		sub.w	d4,d0
		bhs.s	TailPhysics_loc_100DE
		move.w	#-$80,d0

TailPhysics_loc_100DE:
		move.w	d0,obInertia(a0)
		rts
; End of function Tails_RollLeft


; =============== S U B R O U T I N E =======================================


Tails_RollRight:
		move.w	obInertia(a0),d0
		bmi.s	TailPhysics_loc_100F8
		bclr	#0,obStatus(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_100F8:
		add.w	d4,d0
		bhs.s	TailPhysics_loc_10100
		move.w	#$80,d0

TailPhysics_loc_10100:
		move.w	d0,obInertia(a0)
		rts
; End of function Tails_RollRight


; =============== S U B R O U T I N E =======================================


Tails_JumpDirection:
		move.w	(Tails_top_speed).w,d6
		move.w	(Tails_acceleration).w,d5
		asl.w	#1,d5
	;	btst	#4,obStatus(a0)
	;	bne.s	loc_10150
		move.w	obVelX(a0),d0
		btst	#bitL,(v_jpadholdlogical2).w
		beq.s	+
		bset	#0,obStatus(a0)
		sub.w	d5,d0	; add acceleration to the left
		move.w	d6,d1
		neg.w	d1
		cmp.w	d1,d0	; compare new speed with top speed
		bgt.s	+	; if new speed is less than the maximum, branch
		add.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d1,d0	; compare speed with top speed
		ble.s	+	; if speed was already greater than the maximum, branch
		move.w	d1,d0	; limit speed on ground going left
+
		btst	#bitR,(v_jpadholdlogical2).w
		beq.s	+
		bclr	#0,obStatus(a0)
		add.w	d5,d0	; add acceleration to the right
		cmp.w	d6,d0	; compare new speed with top speed
		blt.s	+	; if new speed is less than the maximum, branch
		sub.w	d5,d0	; remove this frame's acceleration change
		cmp.w	d6,d0	; compare speed with top speed
		bge.s	+	; if speed was already greater than the maximum, branch
		move.w	d6,d0	; limit speed on ground going right
+
		move.w	d0,obVelX(a0)

; loc_10150:
		bsr.w	Player_ResetScr

TailPhysics_loc_10162:
		cmpi.w	#-$400,obVelY(a0)
		blo.s	TailPhysics_locret_10190
		move.w	obVelX(a0),d0
		move.w	d0,d1
		asr.w	#5,d1
		beq.s	TailPhysics_locret_10190
		bmi.s	TailPhysics_loc_10184
		sub.w	d1,d0
		bhs.s	TailPhysics_loc_1017E
		clr.w	d0

TailPhysics_loc_1017E:
		move.w	d0,obVelX(a0)
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_10184:
		sub.w	d1,d0
		blo.s	TailPhysics_loc_1018C
		clr.w	d0

TailPhysics_loc_1018C:
		move.w	d0,obVelX(a0)

TailPhysics_locret_10190:
		rts
; End of function Tails_JumpDirection


; =============== S U B R O U T I N E =======================================

; Sonic_LevelBoundaries:
Tails_LevelBound:
		move.l	obX(a0),d1
		move.w	obVelX(a0),d0
		ext.l	d0
		asl.l	#8,d0
		add.l	d0,d1
		swap	d1
		move.w	(Camera_Min_X_pos).w,d0
		addi.w	#$10,d0
		cmp.w	d1,d0
		bhi.s	loc_11374
		move.w	(Camera_Max_X_pos).w,d0
		addi.w	#$128,d0
		tst.b	(f_lockscreen).w
		bne.s	loc_1133A
		addi.w	#$40,d0

loc_1133A:
		cmp.w	d1,d0
		bls.s	loc_11374
; loc_1133E:
		move.w	(Camera_Max_Y_pos).w,d0
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(Camera_Max_Y_pos_target).w,d1
		cmp.w	d0,d1
		blo.s	.skip
		move.w	d1,d0
.skip:
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blt.s	loc_1134E
		rts
; ---------------------------------------------------------------------------

loc_1134E:
		cmpa.w	#v_player,a0
		beq.s	+
		movea.l	a0,a2
		jmp	(KillCharacter).l
+
		; a2 needs to be set here, otherwise KillCharacter
		; will access a dangling pointer!
		movea.l	a0,a2
		cmpi.w	#(id_SBZ<<8)+1,(Current_ZoneAndAct).w
		bne.w	KillCharacter
		cmpi.w	#$2000,obX(a0)
		blo.w	KillCharacter
		clr.b	(v_lastlamp).w
		move.w	#1,(Level_Inactive_flag).w
		move.w	#(id_LZ<<8)+3,(Current_ZoneAndAct).w
		rts
; ---------------------------------------------------------------------------

loc_11374:
		move.w	d0,obX(a0)
		clr.w	obXSub(a0)
		clr.w	obVelX(a0)
		clr.w	obInertia(a0)
		move.w	(Camera_Max_Y_pos).w,d0
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(Camera_Max_Y_pos_target).w,d1
		cmp.w	d0,d1
		blo.s	.skip
		move.w	d1,d0
.skip:
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blt.s	loc_1134E
		rts
; End of function Tails_LevelBoundaries


; =============== S U B R O U T I N E =======================================


Tails_Roll:
		tst.b	(f_slidemode).w
		bne.s	Obj02_NoRoll
		btst	#status_secondary.sliding,obStatusSecondary(a0)
		bne.s	Obj02_NoRoll
		move.b	(v_jpadholdlogical2).w,d0
		andi.b	#button_left_mask|button_right_mask,d0
		bne.s	Obj02_NoRoll
		btst	#button_down,(v_jpadholdlogical2).w
		beq.s	.checkwalk
		mvabs.w	obInertia(a0),d0
		cmpi.w	#Sonic_RollStartSpeed,d0
		bhs.s	.doroll
		btst	#status.player.on_object,obStatus(a0)
		bne.s	Obj02_NoRoll
		move.b	#AniIDSonAni_Duck,obAnim(a0)
		rts
.checkwalk:
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	Obj02_NoRoll
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		rts
.doroll:
		btst	#status.player.rolling,obStatus(a0)
		bne.s	Obj02_NoRoll
		bset	#status.player.rolling,obStatus(a0)
		move.b	#tails_roll_height,obHeight(a0)
		move.b	#tails_roll_width,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#tails_height-tails_roll_height,obY(a0)
		move.w	#sfx_Roll,d0
		jmp	(PlaySound_Special).l
Obj02_NoRoll:
		rts


Tails_Jump:
		move.b	(v_jpadpresslogical2).w,d0
		andi.b	#btnABC,d0
		beq.s	Obj02_NoRoll
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.b	#$80,d0
		bsr.w	sub_13102
		cmpi.w	#6,d1
		blt.s	Obj02_NoRoll
		move.w	#Sonic_JumpSpeed,d2
		btst	#status.player.underwater,obStatus(a0)
		beq.s	+
		move.w	#Sonic_WaterJumpSpeed,d2
+
		moveq	#0,d0
		move.b	obAngle(a0),d0
		subi.b	#$40,d0
		jsr	(CalcSine).l
		muls.w	d2,d1
		asr.l	#8,d1
		add.w	d1,obVelX(a0)
		muls.w	d2,d0
		asr.l	#8,d0
		add.w	d0,obVelY(a0)
		bset	#1,obStatus(a0)
		bclr	#5,obStatus(a0)
		addq.l	#4,sp
		move.b	#1,jumping(a0)
		clr.b	stick_to_convex(a0)
		move.w	#sfx_Jump,d0
		jsr	(PlaySound_Special).l
		btst	#2,obStatus(a0)
		bne.s	.return
		move.b	#tails_roll_height,obHeight(a0)
		move.b	#tails_roll_width,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		bset	#2,obStatus(a0)
		addq.w	#5,obY(a0)
.return:	rts
; ---------------------------------------------------------------------------

;loc_1031E:
	;	bset	#4,obStatus(a0)
	;	rts
; End of function Tails_Jump


; =============== S U B R O U T I N E =======================================


Tails_JumpHeight:
		tst.b	jumping(a0)
		beq.s	TailS3_loc_15106
		move.w	#-Sonic_JumpReleaseSpeed,d1
		btst	#status.player.underwater,obStatus(a0)
		beq.s	TailS3_loc_150F0
		move.w	#-Sonic_WaterJumpReleaseSpeed,d1

TailS3_loc_150F0:
		cmp.w	obVelY(a0),d1
		ble.s	Tails_Test_For_Flight
		move.b	(v_jpadholdlogical2).w,d0
		andi.b	#button_A_mask|button_B_mask|button_C_mask,d0
		bne.s	TailS3_locret_15104
		move.w	d1,obVelY(a0)

TailS3_locret_15104:
		rts
; ---------------------------------------------------------------------------

TailS3_loc_15106:
		tst.b	spindash_flag(a0)
		bne.s	TailS3_locret_1511A
		cmpi.w	#-Sonic_UpwardSpeedLimit,obVelY(a0)
		bge.s	TailS3_locret_1511A
		move.w	#-Sonic_UpwardSpeedLimit,obVelY(a0)

TailS3_locret_1511A:
		rts
; ---------------------------------------------------------------------------

Tails_Test_For_Flight:
		tst.b	tails_flight_flag(a0)
		bne.w	TailS3_locret_151A2
		move.b	(v_jpadpresslogical2).w,d0
		andi.b	#button_A_mask|button_B_mask|button_C_mask,d0
		beq.w	TailS3_locret_151A2
		cmpa.w	#v_player,a0
		beq.s	TailS3_loc_1515C
TailS3_loc_15156:
		tst.w	(Tails_CPU_idle_timer).w
		beq.s	TailS3_locret_151A2

TailS3_loc_1515C:
		btst	#status.player.rolling,obStatus(a0)
		beq.s	TailS3_loc_1518C
		bclr	#status.player.rolling,obStatus(a0)
		move.b	obHeight(a0),d1
		move.b	default_y_radius(a0),obHeight(a0)
		move.b	default_x_radius(a0),obWidth(a0)
		sub.b	default_y_radius(a0),d1
		ext.w	d1
TailS3_loc_15188:
		add.w	d1,obY(a0)

TailS3_loc_1518C:
		bclr	#status.player.rolljumping,obStatus(a0)
		move.b	#1,tails_flight_flag(a0)
		move.b	#Tails_FlightBudget,tails_flight_energy(a0)
		bsr.w	Tails_Set_Flying_Animation

TailS3_locret_151A2:
		rts
; ---------------------------------------------------------------------------

Tails_CheckSpindash:
		tst.b	spindash_flag(a0)
		bne.s	Tails_UpdateSpindash
		cmpi.b	#AniIDSonAni_Duck,obAnim(a0)
		bne.s	.return
		move.b	(v_jpadpresslogical2).w,d0
		andi.b	#btnABC,d0
		beq.s	.return
		move.b	#AniIDSonAni_Spindash,obAnim(a0)
		move.w	#sfx_Spindash,d0
		jsr	(PlaySound_Special).l
		move.b	#1,spindash_flag(a0)
		clr.w	spindash_counter(a0)
		bra.w	Tails_SpindashGround
.return:
		rts

Tails_UpdateSpindash:
		btst	#button_down,(v_jpadholdlogical2).w
		bne.w	Tails_ChargingSpindash
		move.b	#tails_roll_height,obHeight(a0)
		move.b	#tails_roll_width,obWidth(a0)
		move.b	#AniIDSonAni_Roll,obAnim(a0)
		addq.w	#tails_height-tails_roll_height,obY(a0)
		clr.b	spindash_flag(a0)
		moveq	#0,d0
		move.b	spindash_counter(a0),d0	; integer part of the 8.8 charge
		add.w	d0,d0
		move.w	Tails_SpindashSpeeds(pc,d0.w),obInertia(a0)
		cmpa.w	#v_player,a0
		bne.s	.nocamera
		move.w	obInertia(a0),d0
		subi.w	#Sonic_SpindashMinSpeed,d0
		add.w	d0,d0
		neg.w	d0
		addi.w	#Sonic_SpindashCameraDelayMax<<8,d0
	if FixBugs
		lsr.w	#8,d0
		move.b	d0,(Horiz_scroll_delay_val).w
		move.b	(Sonic_Pos_Record_Index+1).w,(Horiz_scroll_delay_val+1).w
	else
		move.w	d0,(Horiz_scroll_delay_val).w
	endif
 .nocamera:
		btst	#status.player.x_flip,obStatus(a0)
		beq.s	.right
		neg.w	obInertia(a0)
.right:
		bset	#status.player.rolling,obStatus(a0)
		move.w	#sfx_Dash,d0
		jsr	(PlaySound_Special).l
		bra.s	Tails_SpindashGround

Tails_SpindashSpeeds:
		dc.w Sonic_SpindashMinSpeed
		dc.w Sonic_SpindashMinSpeed+Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+2*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+3*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+4*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+5*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+6*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+7*Sonic_SpindashSpeedStep
		dc.w Sonic_SpindashMinSpeed+8*Sonic_SpindashSpeedStep

Tails_ChargingSpindash:
		tst.w	spindash_counter(a0)
		beq.s	.press
		move.w	spindash_counter(a0),d0
		lsr.w	#Sonic_SpindashDecayShift,d0
		sub.w	d0,spindash_counter(a0)
		bhs.s	.press
		clr.w	spindash_counter(a0)
.press:
		move.b	(v_jpadpresslogical2).w,d0
		andi.b	#btnABC,d0
		beq.s	Tails_SpindashGround
		move.w	#AniIDSonAni_Spindash<<8,obAnim(a0)
		move.w	#sfx_Spindash,d0
		jsr	(PlaySound_Special).l
		addi.w	#Sonic_SpindashChargeStep,spindash_counter(a0)
		cmpi.w	#Sonic_SpindashMaxCharge,spindash_counter(a0)
		blo.s	Tails_SpindashGround
		move.w	#Sonic_SpindashMaxCharge,spindash_counter(a0)

Tails_SpindashGround:
		addq.l	#4,sp			; skip the rest of MdNormal on start, charge and release
		bsr.w	Player_ResetScr
		bsr.w	Tails_LevelBound
		bra.w	AnglePos			; follow the ground while charging


Tails_JumpAngle:
		move.b	obAngle(a0),d0	; get Sonic's angle
		beq.s	TailPhysics_loc_104BC	; if already 0, branch
		bpl.s	TailPhysics_loc_104B2	; if higher than 0, branch
		addq.b	#2,d0		; increase angle
		bhs.s	TailPhysics_loc_104B8
		moveq	#0,d0
		bra.s	TailPhysics_loc_104B8
; ---------------------------------------------------------------------------

TailPhysics_loc_104B2:
		subq.b	#2,d0		; decrease angle
		bhs.s	TailPhysics_loc_104B8
		moveq	#0,d0

TailPhysics_loc_104B8:
		move.b	d0,obAngle(a0)

TailPhysics_loc_104BC:
		move.b	flip_angle(a0),d0
		beq.s	.return
		tst.w	obInertia(a0)
		bmi.s	TailPhysics_loc_104E0
		move.b	flip_speed(a0),d1
		add.b	d1,d0
		bhs.s	+
		subq.b	#1,flips_remaining(a0)
		bhs.s	+
		moveq	#0,d0
		move.b	d0,flips_remaining(a0)
+
		move.b	d0,flip_angle(a0)
.return:	rts
; ---------------------------------------------------------------------------

TailPhysics_loc_104E0:
		move.b	flip_speed(a0),d1
		sub.b	d1,d0
		bhs.s	TailPhysics_loc_104F6
		subq.b	#1,flips_remaining(a0)
		bhs.s	TailPhysics_loc_104F6
		moveq	#0,d0
		move.b	d0,flips_remaining(a0)

TailPhysics_loc_104F6:
		move.b	d0,flip_angle(a0)
		rts
; End of function Tails_JumpAngle


; =============== S U B R O U T I N E =======================================

; Sonic_Floor:
Tails_DoLevelCollision:
		move.l	(v_colladdr1).w,(Collision_addr).w
		cmpi.b	#$C,obTopSolidBit(a0)
		beq.s	+
		move.l	(v_colladdr2).w,(Collision_addr).w
+
		move.b	obLRBSolidBit(a0),d5
		move.w	obVelX(a0),d0				; get X speed
		move.w	obVelY(a0),d1				; get Y speed
		bpl.s	TailPhysics_SonAirCol_PosY				; if it's positive, branch
		cmp.w	d0,d1					; are we moving towards the left?
		bgt.w	Tails_FloorLeft				; if so, branch
		neg.w	d0					; negate for right cheeck
		cmp.w	d0,d1					; are we moving towards the right?
		bge.w	Tails_FloorRight			; if so, branch
		bra.w	Tails_FloorUp				; we are moving upwards
; ===========================================================================

TailPhysics_SonAirCol_PosY:
		cmp.w	d0,d1					; are we moving towards the right?
		blt.w	Tails_FloorRight			; if so, branch
		neg.w	d0					; negate for left check
		cmp.w	d0,d1					; are we moving towards the left?
		ble.w	Tails_FloorLeft				; if so, branch
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	+
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	+
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
+
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		move.b	obVelY(a0),d2
		addq.b	#8,d2
		neg.b	d2
		cmp.b	d2,d1
		bge.s	+
		cmp.b	d2,d0
		blt.s	.return
+
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	TailPhysics_loc_105C0
		move.b	d3,d0
		addi.b	#$10,d0
		andi.b	#$20,d0
		beq.s	TailPhysics_loc_105B2
		asr	obVelY(a0)
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_105B2:
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_105C0:
		clr.w	obVelX(a0)
		cmpi.w	#$FC0,obVelY(a0)
		ble.s	TailPhysics_loc_105D4
		move.w	#$FC0,obVelY(a0)

TailPhysics_loc_105D4:
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorLeft:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	TailPhysics_loc_105FE
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_105FE:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	TailPhysics_loc_10618
		neg.w	d1
		cmpi.w	#Sonic_CeilingPenetrationLimit,d1
		bhs.s	Tails_FloorLeft_OppositeWall
		add.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorLeft_OppositeWall:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	.return
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
.return:
		rts

TailPhysics_loc_10618:
		tst.b	(f_wtunnelmode).w
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorUp:
		bsr.w	Sonic_HitWall
		tst.w	d1
		bpl.s	TailPhysics_loc_10658
		sub.w	d1,obX(a0)
		clr.w	obVelX(a0)

TailPhysics_loc_10658:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	TailPhysics_loc_1066A
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)

TailPhysics_loc_1066A:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	.return
		sub.w	d1,obY(a0)
		move.b	d3,d0
		addi.b	#$20,d0
		andi.b	#$40,d0
		bne.s	TailPhysics_loc_1068A
		clr.w	obVelY(a0)
.return:	rts
; ---------------------------------------------------------------------------

TailPhysics_loc_1068A:
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		move.w	obVelY(a0),obInertia(a0)
		tst.b	d3
		bpl.s	.return
		neg.w	obInertia(a0)

.return:
		rts
; ---------------------------------------------------------------------------

Tails_FloorRight:
		bsr.w	sub_132EE
		tst.w	d1
		bpl.s	TailPhysics_loc_106BC
		add.w	d1,obX(a0)
		clr.w	obVelX(a0)
		move.w	obVelY(a0),obInertia(a0)
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_106BC:
		bsr.w	Sonic_DontRunOnWalls
		tst.w	d1
		bpl.s	TailPhysics_loc_106D6
		sub.w	d1,obY(a0)
		tst.w	obVelY(a0)
		bpl.s	.return
		clr.w	obVelY(a0)

.return:
		rts
; ---------------------------------------------------------------------------

TailPhysics_loc_106D6:
		tst.b	(f_wtunnelmode).w
		bne.s	.checkfloor
		tst.w	obVelY(a0)
		bmi.s	.return
.checkfloor:
		bsr.w	loc_13146
		tst.w	d1
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	d3,obAngle(a0)
		bsr.w	Tails_ResetOnFloor
		clr.w	obVelY(a0)
		move.w	obVelX(a0),obInertia(a0)

.return:
		rts
; End of function Tails_DoLevelCollision


; =============== S U B R O U T I N E =======================================


Tails_ResetOnFloor:
		tst.b	spindash_flag(a0)
		bne.s	.reset			; forced rolls retain their ball and animation
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.b	obHeight(a0),d0
		move.b	default_y_radius(a0),obHeight(a0)
		move.b	default_x_radius(a0),obWidth(a0)
		btst	#status.player.rolling,obStatus(a0)
		beq.s	.reset
		bclr	#status.player.rolling,obStatus(a0)
		sub.b	default_y_radius(a0),d0
		ext.w	d0
		move.w	d0,-(sp)
		move.b	obAngle(a0),d0
		addi.b	#$40,d0
		bpl.s	.adjustheight
		neg.w	(sp)			; standing radius extends the other way on ceilings
.adjustheight:
		move.w	(sp)+,d0
		add.w	d0,obY(a0)
.reset:
		bclr	#status.player.in_air,obStatus(a0)
		bclr	#status.player.pushing,obStatus(a0)
		; Roll-jump locking stays removed; rolling jumps retain air control.
		clr.b	jumping(a0)
		clr.w	(v_itembonus).w
		clr.b	flip_angle(a0)
		clr.b	flip_turned(a0)
		clr.b	flips_remaining(a0)
		clr.b	tails_flight_flag(a0)
		clr.b	scroll_delay_counter(a0)
		rts

; ---------------------------------------------------------------------------

Obj02_Hurt:
		clr.b	tails_hidden(a0)		; hurt recoil draws the body unconditionally
		bsr.w	Player_ChkInvincibility
		bsr.w	Player_ChkSpeedShoes
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$30,obVelY(a0)
		btst	#6,obStatus(a0)
		beq.s	TailPhysics_loc_1077E
		subi.w	#$20,obVelY(a0)

TailPhysics_loc_1077E:
		bsr.w	Tails_HurtStop
		bsr.w	Tails_LevelBound
		bsr.w	RecordTailsMoves
		bsr.w	Tails_Water
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Tails_HurtStop:
		; a2 needs to be set here, otherwise KillCharacter
		; will access a dangling pointer!
		movea.l	a0,a2
		move.w	(Camera_Max_Y_pos).w,d0
		; The original code does not consider that the camera boundary
		; may be in the middle of lowering itself, which is why going
		; down the S-tunnel in Green Hill Zone Act 1 fast enough can
		; kill Sonic.
		move.w	(Camera_Max_Y_pos_target).w,d1
		cmp.w	d0,d1
		blo.s	.skip
		move.w	d1,d0
.skip:
		addi.w	#224,d0
		cmp.w	obY(a0),d0
		blo.w	KillCharacter
		bsr.w	Tails_DoLevelCollision
		btst	#1,obStatus(a0)	; in_air
		bne.s	.return
		moveq	#0,d0
		move.w	d0,obVelY(a0)
		move.w	d0,obVelX(a0)
		move.w	d0,obInertia(a0)
		move.b	d0,obControl(a0)
		move.b	#AniIDSonAni_Walk,obAnim(a0)
		move.w	#$100,obPriority(a0)
		subq.b	#2,obRoutine(a0)
		move.w	#Player_HurtFlashTime,flashtime(a0)
		move.b	d0,spindash_flag(a0)
.return:	rts
; End of function Tails_HurtStop

; ---------------------------------------------------------------------------
; Obj01_Death:
Obj02_Dead:
		clr.b	tails_hidden(a0)
		bsr.w	Tails_GameOver
		movem.w	obVelX(a0),d0/d2			; load xy speed
		lsl.l	#8,d0					; shift velocity to line up with the middle 16 bits of the 32-bit position
		lsl.l	#8,d2					; shift velocity to line up with the middle 16 bits of the 32-bit position
		add.l	d0,obX(a0)				; add to x-axis position ; note this affects the subpixel position x_sub(a0) = 2+x_pos(a0)
		add.l	d2,obY(a0)				; add to y-axis position ; note this affects the subpixel position y_sub(a0) = 2+y_pos(a0)
		addi.w	#$38,obVelY(a0)				; increase vertical speed (apply gravity)
		bsr.w	RecordTailsMoves
		bsr.w	Tails_Animate
		bsr.w	LoadTailsDynPLC
		jmp	(DisplaySprite).l

; =============== S U B R O U T I N E =======================================


Tails_GameOver:
		bsr.w	Tails_ReleaseCarry
		clr.b	tails_flight_flag(a0)
		cmpa.w	#v_player,a0
		beq.w	Sonic_GameOver
		move.w	(Camera_Y_pos).w,d0
		addi.w	#Sonic_DeathScreenMargin,d0
		cmp.w	obY(a0),d0
		bge.s	.return
		jsr	(Player_ClearPowerUps).l
		move.b	#2,obRoutine(a0)
		bra.w	TailS3_sub_13ECA
.return:
		rts

Obj02_ResetLevel:
		tst.w	restart_countdown(a0)
		beq.s	.return
		subq.w	#1,restart_countdown(a0)
		bne.s	.return
		move.w	#1,(Level_Inactive_flag).w
.return:	rts

; =============== S U B R O U T I N E =======================================



Tails_Animate:
Animate_Tails:
		lea	(AniTails).l,a1

Animate_Tails_Part2:
		moveq	#0,d0
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0
		beq.s	TailS3_loc_1588A
		move.b	d0,obPrevAni(a0)
		move.b	#0,obAniFrame(a0)
		move.b	#0,obTimeFrame(a0)
		bclr	#status.player.pushing,obStatus(a0)

TailS3_loc_1588A:
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.b	(a1),d0
		bmi.s	TailS3_loc_158FA
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.s	TailS3_locret_158C8
		move.b	d0,obTimeFrame(a0)
; End of function Animate_Tails


; =============== S U B R O U T I N E =======================================


TailS3_sub_158B0:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1
		move.b	1(a1,d1.w),d0
		cmpi.b	#$FC,d0
		bhs.s	TailS3_loc_158CA

TailS3_loc_158C0:
		move.b	d0,obFrame(a0)
		addq.b	#1,obAniFrame(a0)

TailS3_locret_158C8:
		rts
; ---------------------------------------------------------------------------

TailS3_loc_158CA:
		addq.b	#1,d0
		bne.s	TailS3_loc_158DA
		move.b	#0,obAniFrame(a0)
		move.b	1(a1),d0
		bra.s	TailS3_loc_158C0
; ---------------------------------------------------------------------------

TailS3_loc_158DA:
		addq.b	#1,d0
		bne.s	TailS3_loc_158EE
		move.b	2(a1,d1.w),d0
		sub.b	d0,obAniFrame(a0)
		sub.b	d0,d1
		move.b	1(a1,d1.w),d0
		bra.s	TailS3_loc_158C0
; ---------------------------------------------------------------------------

TailS3_loc_158EE:
		addq.b	#1,d0
		bne.s	TailS3_locret_158F8
		move.b	2(a1,d1.w),obAnim(a0)

TailS3_locret_158F8:
		rts
; End of function TailS3_sub_158B0

; ---------------------------------------------------------------------------

TailS3_loc_158FA:
		addq.b	#1,d0
		bne.w	TailS3_loc_159C8
		moveq	#0,d0
		tst.b	flip_turned(a0)
		bmi.w	SAnim_Tumble
		move.b	flip_angle(a0),d0
		bne.w	SAnim_Tumble
		moveq	#0,d1
		move.b	obAngle(a0),d0
		bmi.s	TailS3_loc_1591E
		beq.s	TailS3_loc_1591E
		subq.b	#1,d0

TailS3_loc_1591E:
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	TailS3_loc_1592A
		not.b	d0

TailS3_loc_1592A:
		addi.b	#$10,d0
		bpl.s	TailS3_loc_15932
		moveq	#3,d1

TailS3_loc_15932:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
		btst	#status.player.pushing,obStatus(a0)
		bne.w	TailS3_loc_15A14
		lsr.b	#4,d0
		andi.b	#6,d0
		move.w	obInertia(a0),d2
		bpl.s	TailS3_loc_15956
		neg.w	d2

TailS3_loc_15956:
		tst.b	obStatusSecondary(a0)
		bpl.w	TailS3_loc_15960
		add.w	d2,d2

TailS3_loc_15960:
		move.b	d0,d3
		add.b	d3,d3
		add.b	d3,d3
		lea	(AniTails00).l,a1
		cmpi.w	#$600,d2
		blo.s	TailS3_loc_1598A
		lea	(AniTails01).l,a1
		move.b	d0,d3
		add.b	d3,d3
		cmpi.w	#$700,d2
		blo.s	TailS3_loc_1598A
		lea	(AniTails1F).l,a1
		move.b	d0,d3

TailS3_loc_1598A:
		moveq	#0,d1
		move.b	obAniFrame(a0),d1
		move.b	1(a1,d1.w),d0
		cmpi.b	#-1,d0
		bne.s	TailS3_loc_159A4
		move.b	#0,obAniFrame(a0)
		move.b	1(a1),d0

TailS3_loc_159A4:
		move.b	d0,obFrame(a0)
		add.b	d3,obFrame(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.s	TailS3_locret_159C6
		neg.w	d2
		addi.w	#$800,d2
		bpl.s	TailS3_loc_159BC
		moveq	#0,d2

TailS3_loc_159BC:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		addq.b	#1,obAniFrame(a0)

TailS3_locret_159C6:
		rts
; ---------------------------------------------------------------------------

TailS3_loc_159C8:
		addq.b	#1,d0
		bne.s	TailS3_loc_15A3C
		move.b	obStatus(a0),d1
		andi.b	#1,d1
		andi.b	#$FC,obRender(a0)
		or.b	d1,obRender(a0)
		subq.b	#1,obTimeFrame(a0)
		bpl.w	TailS3_locret_158C8
		move.w	obInertia(a0),d2
		bpl.s	TailS3_loc_159EE
		neg.w	d2

TailS3_loc_159EE:
		lea	(AniTails03).l,a1
		cmpi.w	#$600,d2
		bhs.s	TailS3_loc_15A00
		lea	(AniTails02).l,a1

TailS3_loc_15A00:
		neg.w	d2
		addi.w	#$400,d2
		bpl.s	TailS3_loc_15A0A
		moveq	#0,d2

TailS3_loc_15A0A:
		lsr.w	#8,d2
		move.b	d2,obTimeFrame(a0)
		bra.w	TailS3_sub_158B0
; ---------------------------------------------------------------------------

TailS3_loc_15A14:
		subq.b	#1,obTimeFrame(a0)
		bpl.w	TailS3_locret_158C8
		move.w	obInertia(a0),d2
		bmi.s	TailS3_loc_15A24
		neg.w	d2

TailS3_loc_15A24:
		addi.w	#$800,d2
		bpl.s	TailS3_loc_15A2C
		moveq	#0,d2

TailS3_loc_15A2C:
		lsr.w	#6,d2
		move.b	d2,obTimeFrame(a0)
		lea	(AniTails04).l,a1
		bra.w	TailS3_sub_158B0
; ---------------------------------------------------------------------------

TailS3_loc_15A3C:
		subq.b	#1,obTimeFrame(a0)
		bpl.w	TailS3_locret_158C8
		move.w	obVelX(a2),d1
		move.w	obVelY(a2),d2
		jsr	(CalcAngle).l

TailS3_loc_15A5E:
		moveq	#0,d1
		move.b	obStatus(a0),d2
		andi.b	#1,d2
		bne.s	TailS3_loc_15A6E
		not.b	d0
		bra.s	TailS3_loc_15A72
; ---------------------------------------------------------------------------

TailS3_loc_15A6E:
		addi.b	#$80,d0

TailS3_loc_15A72:
		addi.b	#$10,d0
		bpl.s	TailS3_loc_15A7A
		moveq	#3,d1

TailS3_loc_15A7A:
		andi.b	#$FC,obRender(a0)
		eor.b	d1,d2
		or.b	d2,obRender(a0)
TailS3_loc_15A92:
		lsr.b	#3,d0
		andi.b	#$C,d0
		move.b	d0,d3
		lea	(AniTails_Tail03).l,a1
		move.b	#3,obTimeFrame(a0)
		bsr.w	TailS3_sub_158B0
		add.b	d3,obFrame(a0)
		rts
; ---------------------------------------------------------------------------
AniTails:
		include "animations/Tails.asm"
; ---------------------------------------------------------------------------


; ---------------------------------------------------------------------------
; S3&K word-count/run DPLCs, through the shared atomic queue loader.
; The tail has its own art/table and a 12-tile bank ending before the rings.
; ---------------------------------------------------------------------------

LoadTailsTailsDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		lea	(TailsTailsDynPLC).l,a2
		lea	(TailsTails_LastLoadedDPLC).w,a3
		move.w	#ArtTile_TailsTails*tile_size,d4
		move.l	#Art_Tails_Tails,d6
		jmp	(Load_DynamicPLC).l

LoadTailsDynPLC:
		moveq	#0,d0
		move.b	obFrame(a0),d0
LoadTailsDynPLC_Frame:
		lea	(TailsDynPLC).l,a2
		lea	(Tails_LastLoadedDPLC).w,a3
		move.w	#ArtTile_Tails*tile_size,d4
		move.l	#Art_Tails,d6
		cmpi.w	#Tails_ExtraFirstFrame,d0
		blo.s	.ready
		move.l	#Art_Tails_Extra,d6
.ready:
		jmp	(Load_DynamicPLC).l

; S3&K carry animation calls this for the player in a1, using d0 as frame.
Perform_Player_DPLC:
		movem.l	a0-a1,-(sp)
		movea.l	a1,a0
		cmpi.b	#id_Obj02,obID(a0)
		beq.s	.tails
		jsr	(LoadSonicDynPLC_Frame).l
		bra.s	.return
.tails:
		bsr.s	LoadTailsDynPLC_Frame
.return:
		movem.l	(sp)+,a0-a1
		rts
