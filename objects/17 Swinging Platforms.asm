; ---------------------------------------------------------------------------
; Object 17 - pendulums, rotating platforms and S3&K swing lifts (MD CPU).
; Word: PPDR IIII SMMM LLLL
; PP = quarter-turn orientation/phase; D = detachable; R = impulse relay;
; S = optional material sound; IIII = platform-body recipe;
; MMM = movement 0 normal, 1 half, 2 static, 3 rotate, 4 ICZ momentum,
;                5 SOZ half-circle lift, 6 DEZ quarter-circle lift, 7 S2 trap.
; 0-8 links are supported. 9-F are reserved, clamped to 8, never payloads.
; ---------------------------------------------------------------------------
swing_max_links = 8              ; declared packed capacity, including 0 links
swing_orientation = objoff_2E     ; byte: quarter-turn angle
swing_preset = objoff_2F          ; byte: body recipe 0-11; reserved values use 0
swing_helper_ptr = objoff_30      ; long: packed decorative chain
swing_mode_timer = objoff_34      ; word: endpoint pause / static release delay
swing_ang_vel = objoff_36         ; word: 8.8 angular velocity
swing_orig_y = objoff_38          ; word: pivot Y
swing_orig_x = objoff_3A          ; word: pivot X
swing_radius = objoff_3C          ; word: 16*links+8
swing_movement = objoff_3E        ; long: cached movement routine
swing_previous_x = objoff_42      ; word: preceding position / collision X
swing_previous_y = objoff_44      ; word: preceding position
swing_contact = objoff_46         ; word: last relay neighbour
swing_cooldown = objoff_48        ; byte: relay feedback guard
swing_impulse = objoff_4A         ; word: pending signed world impulse
swing_body = objoff_4C            ; word: owned Obj18 body, attached or released
swing_helper_owner = objoff_4C    ; word: back-reference in the packed helper
swing_last_angle = obColProp     ; byte: last angle; no NPC touch property
swing_mode_started = obAnim      ; 0 idle/global, 1 active, 2 relay active, 3 relay rest
swing_dir_flag = obPrevAni
status_standing_mask = $18
status_in_air_bit = 1

SwingingPtfm:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	SwingingPtfm_Index(pc,d0.w),d0
		jmp	SwingingPtfm_Index(pc,d0.w)
SwingingPtfm_Index:
		dc.w	SwingingPtfm_Init-SwingingPtfm_Index
		dc.w	SwingingPtfm_SetSolid-SwingingPtfm_Index
		dc.w	SwingingPtfm_PostDetach-SwingingPtfm_Index

SwingingPtfm_HelperDisplay:
		movea.w	swing_helper_owner(a0),a1
		cmpi.l	#SwingingPtfm,code(a1)
		bne.s	.orphan
		move.l	swing_helper_ptr(a1),d0
		cmpa.l	d0,a0
		bne.s	.orphan
		move.w	#$200,d0
		jmp	DisplaySprite3
.orphan:
		jmp	(DeleteObject).l

SwingingPtfm_Init:
		move.b	#2,obRoutine(a0)
		move.l	#Map_Obj17,obMap(a0)
		move.b	#Map_Obj17_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_GHZ_MZ_Swing,0,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.b	#sprite_bound($18,Map_Obj17_width),obActWid(a0)
		move.b	#8,obHeight(a0)
		move.w	obX(a0),swing_orig_x(a0)
		move.w	obY(a0),swing_orig_y(a0)
		move.w	obX(a0),swing_previous_x(a0)
		move.w	obY(a0),swing_previous_y(a0)
		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	.smz
		move.l	#Map_Obj17_SLZ,obMap(a0)
		move.b	#Map_Obj17_SLZ_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_SLZ_Swing,2,0),obGfx(a0)
		move.b	#sprite_bound($20,Map_Obj17_SLZ_width),obActWid(a0)
		move.b	#$10,obHeight(a0)
.smz:
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	.settings
		move.l	#Map_SMZ_Swing,obMap(a0)
		move.b	#Map_SMZ_Swing_height,height_pixels(a0)
		move.w	#ArtTile_SMZ_Atlas,obGfx(a0)
.settings:
		move.w	obSubtype(a0),d4
		move.w	d4,d0
		lsr.w	#8,d0
		move.w	d0,d1
		andi.w	#$F,d0
		cmpi.w	#Platform_SwingPresetCount,d0
		blo.s	.profile_ready
		moveq	#platform_top,d0
.profile_ready:
		move.b	d0,swing_preset(a0)
		lsr.w	#6,d1
		lsl.w	#6,d1
		move.b	d1,swing_orientation(a0)
		moveq	#0,d0
		move.l	d0,swing_helper_ptr(a0)
		move.l	d0,swing_mode_timer(a0)
		move.w	d0,swing_contact(a0)
		move.l	d0,swing_cooldown(a0)
		move.w	d0,swing_body(a0)
		move.w	d0,swing_mode_started(a0)
		move.b	#$FF,swing_last_angle(a0)
		move.w	d4,d0
		andi.w	#$F,d0
		cmpi.w	#swing_max_links,d0
		bls.s	.length
		moveq	#swing_max_links,d0
.length:
		move.w	d0,d1
		lsl.w	#4,d1
		addq.w	#8,d1
		move.w	d1,swing_radius(a0)
.movement:
		move.w	d4,d0
		andi.w	#$70,d0
		lsr.w	#3,d0
		lea	SwingingPtfm_MotionIndex(pc),a1
		move.w	(a1,d0.w),d0
		adda.w	d0,a1
		move.l	a1,swing_movement(a0)
		clr.w	obAngle(a0)
		cmpa.l	#SwingingPtfm_Motion_SOZ,a1
		bne.s	.trapAngle
		move.w	#$4000,obAngle(a0)
.trapAngle:
		cmpa.l	#SwingingPtfm_Motion_Trap,a1
		bne.s	.art
		move.w	#$8000,obAngle(a0)
.art:
		bsr.w	SwingingPtfm_UpdateMotion
		bsr.w	SwingingPtfm_TryBody
		bsr.w	SwingingPtfm_TryHelper
		move.w	obX(a0),swing_previous_x(a0)
		move.w	obY(a0),swing_previous_y(a0)
		rts

SwingingPtfm_TryHelper:
		move.l	swing_helper_ptr(a0),d0
		beq.s	.spawn
		movea.l	d0,a1
		cmpi.l	#SwingingPtfm_HelperDisplay,code(a1)
		bne.s	.lost
		move.w	a0,d0
		cmp.w	swing_helper_owner(a1),d0
		beq.w	.return
.lost:
		clr.l	swing_helper_ptr(a0)
.spawn:
		jsr	(FindFreeObj).l
		bne.s	.return
		move.l	#SwingingPtfm_HelperDisplay,code(a1)
		move.l	obMap(a0),obMap(a1)
		move.w	obGfx(a0),obGfx(a1)
		move.b	#$44,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#$90,mainspr_width(a1)
		move.b	#$90,mainspr_height(a1)
		move.b	#2,mainspr_mapframe(a1)
		move.w	swing_radius(a0),d0
		subq.w	#8,d0
		lsr.w	#4,d0
		move.b	d0,mainspr_childsprites(a1)
		move.w	swing_orig_x(a0),obX(a1)
		move.w	swing_orig_y(a0),obY(a1)
		lea	subspr_data(a1),a2
		subq.w	#1,d0
		bmi.s	.helperReady
.links:
		clr.l	(a2)+
		move.w	#1,(a2)+
		dbf	d0,.links
.helperReady:
		move.l	a1,swing_helper_ptr(a0)
		move.w	a0,swing_helper_owner(a1)
		moveq	#0,d0
		move.b	swing_last_angle(a0),d0
		not.b	swing_last_angle(a0)
		bsr.w	SwingingPtfm_ApplyAngle	; new helper needs the current pose now
.return:
		rts
SwingingPtfm_TryBody:
		tst.w	swing_body(a0)
		beq.s	.spawn
		movea.w	swing_body(a0),a1
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.s	.lost
		move.w	a0,d0
		cmp.w	Plat_parent(a1),d0
		beq.s	.dimensions
.lost:
		clr.w	swing_body(a0)
.spawn:
		jsr	(Platform_CreateSwingBody).l
		bcs.s	.return
.dimensions:
		move.b	obActWid(a1),obActWid(a0)
		move.b	obHeight(a1),obHeight(a0)
.return:
		rts

SwingingPtfm_SetSolid:
		bsr.w	SwingingPtfm_TryBody
		bsr.w	SwingingPtfm_TryHelper
		bsr.w	SwingingPtfm_UpdateMotion
		bsr.s	SwingingPtfm_Interact
		cmpi.l	#SwingingPtfm_Motion_Momentum,swing_movement(a0)
		bne.s	.release
		jsr	(Platform_SwingMomentumInput).l
.release:
		bsr.w	SwingingPtfm_DetachCheck
		bsr.w	SwingingPtfm_Relay
		bra.w	SwingingPtfm_ChkDel

; Collision remains independent of movement, release and optional sounds.
SwingingPtfm_Interact:
		tst.w	swing_body(a0)
		beq.s	.return
		movea.w	swing_body(a0),a1
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	Plat_parent(a1),d0
		bne.s	.return
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Platform_UpdateSuspended).l
		movea.l	(sp)+,a0
		movea.w	swing_body(a0),a1
		move.b	obStatus(a1),d0
		andi.b	#status_standing_mask,d0
		andi.b	#$E7,obStatus(a0)
		or.b	d0,obStatus(a0)
.return:
		rts

SwingingPtfm_UpdateMotion:
		move.w	obX(a0),swing_previous_x(a0)
		move.w	obY(a0),swing_previous_y(a0)
		movea.l	swing_movement(a0),a1
		jmp	(a1)
SwingingPtfm_MotionIndex:
		dc.w	SwingingPtfm_Motion_Normal-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_Half-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_Static-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_Rotate-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_Momentum-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_SOZ-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_DEZ-SwingingPtfm_MotionIndex
		dc.w	SwingingPtfm_Motion_Trap-SwingingPtfm_MotionIndex
SwingingPtfm_Motion_Normal:
		cmpi.b	#2,swing_mode_started(a0)
		bhs.s	SwingingPtfm_Motion_Momentum
		moveq	#0,d0
		move.b	(v_oscillate+$1A).w,d0
		bra.w	SwingingPtfm_ApplyAngle
SwingingPtfm_Motion_Half:
		cmpi.b	#2,swing_mode_started(a0)
		bhs.s	SwingingPtfm_Motion_Momentum
		moveq	#0,d0
		move.b	(v_oscillate+$1A).w,d0
		btst	#0,obStatus(a0)
		beq.s	.clamp
		neg.w	d0
		addi.w	#$80,d0
.clamp:
		cmpi.b	#$40,d0
		bhs.s	.apply
		moveq	#$40,d0
.apply:
		cmpi.b	#$40,d0
		bne.s	.angle
		cmpi.b	#$40,swing_last_angle(a0)
		beq.s	.angle
		cmpi.b	#$FF,swing_last_angle(a0)
		beq.s	.angle
		move.w	d0,-(sp)
		bsr.w	SwingingPtfm_Sound
		move.w	(sp)+,d0
.angle:
		bra.w	SwingingPtfm_ApplyAngle
SwingingPtfm_Motion_Static:
		moveq	#$40,d0
		bra.w	SwingingPtfm_ApplyAngle
SwingingPtfm_Motion_Rotate:
		moveq	#0,d0
		move.b	obAngle(a0),d0
		addi.w	#$100,obAngle(a0)
		bra.w	SwingingPtfm_ApplyAngle

; ICZ's constant angular acceleration, capped visible excursion and return.
; The angle is displacement from rest; positive displacement travels right.
SwingingPtfm_Motion_Momentum:
		move.w	obAngle(a0),-(sp)
		tst.b	swing_mode_started(a0)
		beq.s	.pose
		cmpi.b	#3,swing_mode_started(a0)
		beq.s	.pose
		move.w	obAngle(a0),d2
		move.w	d2,d3
		move.w	swing_ang_vel(a0),d1
		tst.w	d2
		bmi.s	.left
		subi.w	#$10,d1
		bra.s	.advance
.left:
		addi.w	#$10,d1
.advance:
		move.w	d1,swing_ang_vel(a0)
		add.w	d1,d2
		tst.w	d3
		bmi.s	.fromLeft
		tst.w	d2
		bmi.s	.rest
		bra.s	.store
.fromLeft:
		tst.w	d2
		bpl.s	.rest

		bra.s	.store
.rest:
		moveq	#0,d2
		clr.w	swing_ang_vel(a0)
		cmpi.b	#2,swing_mode_started(a0)
		bne.s	.idle
		cmpi.l	#SwingingPtfm_Motion_Momentum,swing_movement(a0)
		beq.w	.idle
		move.b	#3,swing_mode_started(a0)
		bra.w	.store
.idle:
		clr.b	swing_mode_started(a0)
.store:
		move.w	d2,obAngle(a0)
.pose:
		move.w	obAngle(a0),d0
		cmpi.w	#$6E00,d0
		ble.s	.negativeLimit
		move.w	#$6E00,d0
.negativeLimit:
		cmpi.w	#-$6E00,d0
		bge.s	.visibleAngle
		move.w	#-$6E00,d0
.visibleAngle:
		lsr.w	#8,d0
		neg.b	d0
		addi.b	#$40,d0
		andi.w	#$FF,d0
		bsr.w	SwingingPtfm_ApplyAngle
		move.w	(sp)+,d3
		tst.b	swing_mode_started(a0)
		beq.s	.return
		; A wall can hold the outward swing while its momentum dissipates.
		move.w	obX(a0),d0
		sub.w	swing_previous_x(a0),d0
		beq.s	.return
		movem.w	d3,-(sp)
		jsr	(Platform_BodyWall).l
		movem.w	(sp)+,d3
		tst.w	d1
		bpl.s	.return
		move.w	d3,obAngle(a0)
		moveq	#$40,d0
		sub.b	obAngle(a0),d0
		move.b	d0,swing_last_angle(a0)
		not.b	swing_last_angle(a0)
		bra.w	SwingingPtfm_ApplyAngle
.return:
		rts

; Original SOZ/DEZ integrator: +/-8 torque, midpoint direction changes,
; 30-update endpoint pause held while either rider remains on the platform.
SwingingPtfm_Motion_SOZ:
		move.w	#$8000,d5
		moveq	#0,d6
		bra.s	SwingingPtfm_Lift
SwingingPtfm_Motion_DEZ:
		move.w	#$2000,d5
		moveq	#0,d6
SwingingPtfm_Lift:
		tst.w	swing_mode_timer(a0)
		beq.s	.trigger
		move.b	obStatus(a0),d0
		andi.b	#status_standing_mask,d0
		bne.w	.pose
		subq.w	#1,swing_mode_timer(a0)
		bra.w	.pose
.trigger:
		tst.b	swing_mode_started(a0)
		bne.s	.integrate
		move.b	obStatus(a0),d0
		andi.b	#status_standing_mask,d0
		beq.s	.pose
		tst.w	(Debug_placement_mode).w
		bne.s	.pose
		move.b	#1,swing_mode_started(a0)
		bsr.w	SwingingPtfm_Sound
.integrate:
		tst.b	swing_dir_flag(a0)
		bne.s	.negative
		move.w	swing_ang_vel(a0),d0
		addq.w	#8,d0
		move.w	d0,swing_ang_vel(a0)
		add.w	d0,obAngle(a0)
		tst.w	d0
		bne.s	.positiveMoving
		clr.b	swing_mode_started(a0)
.positiveMoving:
		cmp.w	obAngle(a0),d5
		bhi.s	.pose
		move.b	#1,swing_dir_flag(a0)
		bra.s	.pose
.negative:
		move.w	swing_ang_vel(a0),d0
		subq.w	#8,d0
		move.w	d0,swing_ang_vel(a0)
		add.w	d0,obAngle(a0)
		tst.w	d0
		bne.s	.negativeMoving
		move.w	#30,swing_mode_timer(a0)
.negativeMoving:
		cmp.w	obAngle(a0),d5
		bls.s	.pose
		clr.b	swing_dir_flag(a0)
.pose:
		move.w	obAngle(a0),d0
		add.w	d6,d0
		lsr.w	#8,d0
		cmpi.l	#SwingingPtfm_Motion_DEZ,swing_movement(a0)
		bne.w	SwingingPtfm_ApplyAngle
		addi.w	#$80,d0
		bra.w	SwingingPtfm_ApplyAngle

SwingingPtfm_Motion_Trap:
		tst.w	swing_mode_timer(a0)
		beq.s	.trigger
		subq.w	#1,swing_mode_timer(a0)
		bra.w	.pose
.trigger:
		tst.b	swing_mode_started(a0)
		bne.s	.run
		tst.w	(Debug_placement_mode).w
		bne.s	.pose
		lea	(v_player).w,a1
		bsr.s	.near
		bne.s	.activate
		lea	(v_player2).w,a1
		bsr.s	.near
		beq.s	.pose
.activate:
		move.b	#1,swing_mode_started(a0)
.run:
		move.w	swing_ang_vel(a0),d0
		move.w	#8,d1
		tst.b	swing_dir_flag(a0)
		bne.s	.accelerate
		neg.w	d1
.accelerate:
		add.w	d1,d0
		move.w	d0,swing_ang_vel(a0)
		add.w	d0,obAngle(a0)
		cmpi.w	#$200,d0
		beq.s	.right
		cmpi.w	#-$200,d0
		bne.s	.pose
		move.w	#$4000,obAngle(a0)
		move.b	#1,swing_dir_flag(a0)
		bra.s	.pause
.right:
		move.w	#$8000,obAngle(a0)
		clr.b	swing_dir_flag(a0)
.pause:
		clr.w	swing_ang_vel(a0)
		move.w	#60,swing_mode_timer(a0)
		bsr.w	SwingingPtfm_Sound
.pose:
		moveq	#0,d0
		move.b	obAngle(a0),d0
		bra.s	SwingingPtfm_ApplyAngle
.near:
		tst.l	code(a1)
		beq.s	.return
		cmpi.b	#4,obRoutine(a1)
		bhs.s	.notNear
		move.w	obX(a1),d0
		sub.w	swing_orig_x(a0),d0
		addi.w	#$20,d0
		cmpi.w	#$40,d0
		scs	d0
		tst.b	d0
.return:
		rts
.notNear:
		moveq	#0,d0
		rts

SwingingPtfm_ApplyAngle:
		cmp.b	swing_last_angle(a0),d0
		beq.w	.return
		move.b	d0,swing_last_angle(a0)
		btst	#0,obStatus(a0)
		beq.s	.yFlip
		neg.w	d0
		addi.w	#$80,d0
.yFlip:
		btst	#1,obStatus(a0)
		beq.s	.orientation
		neg.w	d0
.orientation:
		add.b	swing_orientation(a0),d0
		andi.w	#$FF,d0
		jsr	(CalcSine).l
		move.l	swing_helper_ptr(a0),d6
		beq.s	.single
		movea.l	d6,a1
		cmpi.l	#SwingingPtfm_HelperDisplay,code(a1)
		bne.w	.lost_helper
		move.w	a0,d6
		cmp.w	swing_helper_owner(a1),d6
		bne.w	.lost_helper
		moveq	#0,d6
		move.b	mainspr_childsprites(a1),d6
		subq.w	#1,d6
		asl.w	#4,d0
		asl.w	#4,d1
		ext.l	d0
		ext.l	d1
		asl.l	#8,d0
		asl.l	#8,d1
		moveq	#0,d4
		moveq	#0,d5
		lea	subspr_data(a1),a2
		tst.w	d6
		bmi.s	.body
.links:
		add.l	d0,d4
		add.l	d1,d5
		movem.l	d4-d5,-(sp)
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	d5,(a2)+
		move.w	d4,(a2)+
		addq.w	#2,a2
		movem.l	(sp)+,d4-d5
		dbf	d6,.links
.body:
		; Reuse the final chain position plus half a link. No per-frame
		; radius multiplications when the packed helper exists.
		asr.l	#1,d0
		asr.l	#1,d1
		add.l	d0,d4
		add.l	d1,d5
		swap	d4
		swap	d5
		add.w	swing_orig_y(a0),d4
		add.w	swing_orig_x(a0),d5
		move.w	d4,obY(a0)
		move.w	d5,obX(a0)
		rts
.lost_helper:
		clr.l	swing_helper_ptr(a0)
.single:
		muls.w	swing_radius(a0),d0
		muls.w	swing_radius(a0),d1
		asr.l	#8,d0
		asr.l	#8,d1
		add.w	swing_orig_y(a0),d0
		add.w	swing_orig_x(a0),d1
		move.w	d0,obY(a0)
		move.w	d1,obX(a0)
.return:
		rts

; Optional sound bit, with an editable zone/material table. Zero is silent.
SwingingPtfm_Sound:
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	.return
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		cmpi.w	#16,d0
		bhs.s	.return
		add.w	d0,d0
		move.w	SwingingPtfm_Sounds(pc,d0.w),d0
		beq.s	.return
		jmp	PlaySound_Special
.return:
		rts
SwingingPtfm_Sounds:
		dc.w	sfx_Push,0,0,0,0,0,0,0,sfx_ChainStomp,0,0,0,0,0,0,0

; Release the existing Obj18 body. No allocation, copy, standing-index transfer
; or grip reparenting is needed; only this suspension owns placement state.
SwingingPtfm_DetachCheck:
		move.w	obSubtype(a0),d0
		btst	#12,d0
		beq.w	.return
		cmpi.l	#SwingingPtfm_Motion_Momentum,swing_movement(a0)
		beq.s	.momentum
		move.b	obStatus(a0),d0
		andi.b	#status_standing_mask,d0
		bne.s	.endpoint
		tst.b	swing_mode_started(a0)
		beq.w	.return
.endpoint:
		cmpi.l	#SwingingPtfm_Motion_Static,swing_movement(a0)
		bne.s	.moving
		addq.w	#1,swing_mode_timer(a0)
		cmpi.w	#30,swing_mode_timer(a0)
		blo.w	.return
		bra.s	.release
.moving:
		cmpi.l	#SwingingPtfm_Motion_Half,swing_movement(a0)
		bne.w	.otherEndpoint
		tst.b	(v_oscillate+$1A).w
		beq.w	.release
.otherEndpoint:
		tst.b	swing_last_angle(a0)
		beq.s	.release
		cmpi.w	#30,swing_mode_timer(a0)
		beq.s	.release
		cmpi.w	#60,swing_mode_timer(a0)
		bne.w	.return
		bra.s	.release
.momentum:
		move.w	obAngle(a0),d0
		bpl.s	.angleAbs
		neg.w	d0
.angleAbs:
		cmpi.w	#$4800,d0
		blo.w	.return
		move.w	swing_ang_vel(a0),d0
		bpl.s	.speedAbs
		neg.w	d0
.speedAbs:
		cmpi.w	#$200,d0
		blo.w	.return
.release:
		tst.w	swing_body(a0)
		beq.w	.return
		movea.w	swing_body(a0),a1
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.w	.return
		move.w	a0,d0
		cmp.w	Plat_parent(a1),d0
		bne.w	.return
		move.w	#$200,d0
		moveq	#0,d1
		cmpi.l	#SwingingPtfm_Motion_Momentum,swing_movement(a0)
		bne.s	.facing
		move.w	#$400,d0
		move.w	#-$600,d1
.facing:
		btst	#0,obStatus(a0)
		beq.s	.release_body
		neg.w	d0
.release_body:
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Platform_ReleaseSuspended).l
		movea.l	(sp)+,a0
		move.b	#4,obRoutine(a0)
		andi.b	#$E7,obStatus(a0)
		cmpi.l	#SwingingPtfm_Motion_Momentum,swing_movement(a0)
		bne.s	.return
		; ICZ releases the existing packed links as debris, not individual SSTs.
		move.b	#1,ob2ndRout(a0)
		move.l	swing_helper_ptr(a0),d0
		beq.s	.hide_chain
		movea.l	d0,a2
		move.l	#SwingingPtfm_ChainDebris,code(a2)
		clr.w	swing_impulse(a2)
		move.w	#60,swing_body(a2)
		clr.l	swing_helper_ptr(a0)
.hide_chain:
		move.w	swing_orig_x(a0),obX(a0)
		move.w	swing_orig_y(a0),obY(a0)
.return:
		rts

SwingingPtfm_PostDetach:
		tst.b	ob2ndRout(a0)
		bne.s	.display
		bsr.w	SwingingPtfm_TryHelper
		bsr.w	SwingingPtfm_UpdateMotion
.display:
		bra.w	SwingingPtfm_ChkDel

; The helper retains its eight six-byte records. An elapsed-time velocity
; function supplies breakup motion without growing records or allocating links.
SwingingPtfm_ChainDebris:
		addq.w	#1,swing_impulse(a0)
		subq.w	#1,swing_body(a0)
		bne.s	.external1
		jmp	(DeleteObject).l
.external1:
		move.w	swing_impulse(a0),d2
		mulu.w	#$18,d2
		moveq	#0,d6
		move.b	mainspr_childsprites(a0),d6
		subq.w	#1,d6
		bmi.s	.display
		moveq	#1,d4
		lea	subspr_data(a0),a2
.links:
		move.w	d4,d0
		lsl.w	#7,d0
		move.w	d2,d1
		sub.w	d0,d1
		asr.w	#8,d1
		add.w	d1,2(a2)
		asr.w	#8,d0
		add.w	d0,(a2)
		addq.w	#6,a2
		addq.w	#1,d4
		dbf	d6,.links
.display:
		move.w	#$200,d0
		jmp	(DisplaySprite3).l

; Relay is opt-in on both bodies. Transfer only a new physical contact or one
; received impulse, never scan-order proximity. Static members forward without
; moving. A source pointer and eight-update cooldown stop feedback through them.
SwingingPtfm_Relay:
		tst.w	swing_body(a0)
		beq.w	.return
		move.w	obSubtype(a0),d0
		btst	#13,d0
		beq.w	.return
		move.w	swing_impulse(a0),d7
		clr.w	swing_impulse(a0)
		tst.b	swing_cooldown(a0)
		beq.s	.input
		subq.b	#1,swing_cooldown(a0)
.input:
		tst.w	d7
		beq.s	.ownVelocity
		bsr.w	SwingingPtfm_ReceiveImpulse
		bra.s	.scan
.ownVelocity:
		tst.b	swing_cooldown(a0)
		bne.w	.return
		move.w	obX(a0),d7
		sub.w	swing_previous_x(a0),d7
		asl.w	#8,d7
		beq.w	.clearContact
.scan:
		lea	(v_lvlobjspace).w,a1
		moveq	#dynamic_object_slots-1,d6
		moveq	#0,d5
.loop:
		cmpa.l	a0,a1
		beq.w	.next
		cmpi.l	#SwingingPtfm,code(a1)
		bne.w	.next
		cmpi.b	#4,obRoutine(a1)
		bhs.w	.next
		tst.w	swing_body(a1)
		beq.w	.next
		movea.w	swing_body(a1),a2
		cmpi.l	#Platform_SuspendedBody,code(a2)
		bne.w	.next
		move.w	a1,d0
		cmp.w	Plat_parent(a2),d0
		bne.w	.next
		move.w	obSubtype(a1),d0
		btst	#13,d0
		beq.s	.next
		moveq	#0,d1
		move.b	obActWid(a0),d1
		add.b	obActWid(a1),d1
		addq.w	#4,d1
		move.w	obX(a0),d0
		sub.w	obX(a1),d0
		bpl.s	.xAbs
		neg.w	d0
.xAbs:
		cmp.w	d1,d0
		bhi.s	.next
		moveq	#0,d1
		move.b	obHeight(a0),d1
		add.b	obHeight(a1),d1
		addq.w	#4,d1
		move.w	obY(a0),d0
		sub.w	obY(a1),d0
		bpl.s	.yAbs
		neg.w	d0
.yAbs:
		cmp.w	d1,d0
		bhi.s	.next
		move.w	a1,d5
		cmp.w	swing_contact(a0),d5
		beq.s	.next
		tst.b	swing_cooldown(a1)
		bne.s	.next
		move.w	d7,swing_impulse(a1)
		move.w	a0,swing_contact(a1)
		move.b	#8,swing_cooldown(a1)
		move.b	#8,swing_cooldown(a0)
.next:
		lea	object_size(a1),a1
		dbf	d6,.loop
		tst.w	d5
		beq.s	.clearContact
		move.w	d5,swing_contact(a0)
		rts
.clearContact:
		clr.w	swing_contact(a0)
.return:
		rts

SwingingPtfm_ReceiveImpulse:
		cmpi.l	#SwingingPtfm_Motion_Static,swing_movement(a0)
		beq.w	.return
		cmpi.l	#SwingingPtfm_Motion_Rotate,swing_movement(a0)
		beq.w	.return
		cmpi.l	#SwingingPtfm_Motion_SOZ,swing_movement(a0)
		beq.s	.activate
		cmpi.l	#SwingingPtfm_Motion_DEZ,swing_movement(a0)
		beq.s	.activate
		cmpi.l	#SwingingPtfm_Motion_Trap,swing_movement(a0)
		beq.s	.activate
		move.w	d7,d0
		btst	#0,obStatus(a0)
		beq.s	.local
		neg.w	d0
.local:
		asr.w	#1,d0
		cmpi.w	#$400,d0
		ble.s	.negative
		move.w	#$400,d0
.negative:
		cmpi.w	#-$400,d0
		bge.s	.velocity
		move.w	#-$400,d0
.velocity:
		move.w	d0,swing_ang_vel(a0)
		cmpi.b	#2,swing_mode_started(a0)
		bhs.s	.activateRelay
		moveq	#$40,d0
		cmpi.l	#SwingingPtfm_Motion_Momentum,swing_movement(a0)
		beq.s	.activateRelay
		sub.b	swing_last_angle(a0),d0
		lsl.w	#8,d0
		move.w	d0,obAngle(a0)
.activateRelay:
		move.b	#2,swing_mode_started(a0)
		rts
.activate:
		move.b	#1,swing_mode_started(a0)
.return:
		rts

SwingingPtfm_ChkDel:
		move.w	swing_orig_x(a0),d0
		add.w	swing_radius(a0),d0
		addi.w	#$80,d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		move.w	swing_radius(a0),d1
		add.w	d1,d1
		addi.w	#$300,d1
		cmp.w	d1,d0
		bls.s	.return
		tst.w	swing_body(a0)
		beq.s	.delete
		movea.w	swing_body(a0),a1
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	Plat_parent(a1),d0
		bne.s	.delete
		move.w	obX(a1),d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		addi.w	#$80,d0
		cmpi.w	#$300,d0
		bls.s	.return
.delete:
		bra.s	SwingingPtfm_DelAll
.return:
		rts

SwingingPtfm_DelAll:
		move.l	swing_helper_ptr(a0),d0
		beq.s	.body
		movea.l	d0,a1
		cmpi.l	#SwingingPtfm_HelperDisplay,code(a1)
		bne.s	.body
		move.w	a0,d0
		cmp.w	swing_helper_owner(a1),d0
		bne.s	.body
		jsr	(DeleteObject2).l
.body:
		tst.w	swing_body(a0)
		beq.s	.unload
		movea.w	swing_body(a0),a1
		cmpi.l	#Platform_SuspendedBody,code(a1)
		bne.s	.unload
		move.w	a0,d0
		cmp.w	Plat_parent(a1),d0
		bne.s	.unload
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Platform_DeleteBody).l
		movea.l	(sp)+,a0
.unload:
		jmp	(UnloadObject).l
