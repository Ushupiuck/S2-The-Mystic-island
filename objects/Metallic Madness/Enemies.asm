; ===========================================================================
; Metallic Madness enemies. MD CPU; scddisasm test 791253ba, r8/mecha_bu.asm.
; Mapping words already include their offsets in the resident MMZ atlas.
; ===========================================================================

MMZ_bu_origin:		equ objoff_2E ; body: original loading-window X
MMZ_bu_speed:		equ objoff_30 ; body: signed 16.16 patrol displacement
MMZ_bu_turn:		equ objoff_34 ; body: updates before reversing
MMZ_bu_sound:		equ objoff_36 ; body: visible buzzing clock
MMZ_bu_child:		equ objoff_38 ; body: reciprocal blade handle
MMZ_bu_parent:		equ objoff_2E ; blade: reciprocal body handle
MMZ_bu_timer:		equ objoff_30 ; blade: updates before changing reach
MMZ_bu_dx:		equ objoff_32 ; blade: signed relative X
MMZ_bu_dy:		equ objoff_34 ; blade: signed relative Y

; A full pool leaves the untouched constructor eligible to retry. No partial
; body or blade is exposed, and the root retains sole placement ownership.
MMZ_MechaBu:
		cmpi.b	#2,(Current_Timezone).w
		beq.w	MMZ_MechaBu_Delete
		out_of_range.w MMZ_MechaBu_Abort
		jsr	(FindFreeObj).l
		bne.w	.return
		move.w	a1,MMZ_bu_child(a0)
		move.w	a0,MMZ_bu_parent(a1)
		move.l	#MMZ_MechaBu_Fall,code(a0)
		move.l	#MMZ_MechaBu_Blade,code(a1)
		move.w	obX(a0),MMZ_bu_origin(a0)
		move.l	#-$5000,MMZ_bu_speed(a0)
		move.l	#Map_MMZ_MechaBu,obMap(a0)
		move.l	#Map_MMZ_MechaBuSaw,obMap(a1)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	obGfx(a0),obGfx(a1)
		move.w	#$200,obPriority(a0)
		move.w	#$180,obPriority(a1)
		move.b	#Map_MMZ_MechaBu_height,height_pixels(a0)
		move.b	#sprite_bound($18,Map_MMZ_MechaBu_width),width_pixels(a0)
		move.b	#Map_MMZ_MechaBuSaw_height,height_pixels(a1)
		move.b	#Map_MMZ_MechaBuSaw_width,width_pixels(a1)
		move.b	#$18,obWidth(a0)
		move.b	#$E,obHeight(a0)
		move.b	#Touch_Size_MMZMechaBu_ID,obColType(a0)
		move.b	#$89,obColType(a1) ; existing $0C x $10 harmful hitbox
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		ori.b	#4,obRender(a0)
		ori.b	#4,obRender(a1)
		move.w	obSubtype(a0),obSubtype(a1)
		move.w	obSubtype(a0),d0
		btst	#0,d0
		bne.s	.fixed
		move.b	#1,obAnim(a1)
		move.w	#61,MMZ_bu_timer(a1)
.fixed:
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		; Initialize the actual blade pose now, including when its allocated
		; slot precedes the root and will not execute until the next update.
		movem.l	a0-a1,-(sp)
		movea.l	a1,a0
		bsr.w	MMZ_MechaBu_BladePose
		movem.l	(sp)+,a0-a1
		bra.s	MMZ_MechaBu_Fall
.return:	rts

MMZ_MechaBu_Fall:
		addq.w	#1,obY(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	MMZ_MechaBu_Draw
		add.w	d1,obY(a0)
		move.l	#MMZ_MechaBu_Walk,code(a0)
		bra.s	MMZ_MechaBu_Draw

MMZ_MechaBu_Walk:
		tst.b	obRender(a0)
		bpl.s	.move
		addq.w	#1,MMZ_bu_sound(a0)
		move.w	MMZ_bu_sound(a0),d0
		andi.w	#$1F,d0
		bne.s	.move
		move.w	#SndID_LaserBeam,d0
		jsr	(PlaySound_Special).l
.move:
		move.l	MMZ_bu_speed(a0),d0
		add.l	d0,obX(a0)
		jsr	(ObjHitFloor).l
		add.w	d1,obY(a0)
		subq.w	#1,MMZ_bu_turn(a0)
		bpl.s	MMZ_MechaBu_Draw
		move.w	#$199,MMZ_bu_turn(a0)
		neg.l	MMZ_bu_speed(a0)

MMZ_MechaBu_Draw:
		out_of_range2.w MMZ_MechaBu_Unload,MMZ_bu_origin(a0)
		; Allocation may use an earlier slot. Synchronize its final position
		; after body movement; BuildSprites reads the updated SST either way.
		movea.w	MMZ_bu_child(a0),a1
		cmpi.l	#MMZ_MechaBu_Blade,code(a1)
		bne.s	.draw
		move.w	a0,d0
		cmp.w	MMZ_bu_parent(a1),d0
		bne.s	.draw
		movem.l	a0-a1,-(sp)
		movea.l	a1,a0
		bsr.w	MMZ_MechaBu_BladePose
		movem.l	(sp)+,a0-a1
.draw:
		jmp	(DisplaySprite).l

MMZ_MechaBu_Abort:
		jmp	(UnloadObject).l
MMZ_MechaBu_Delete:
		jmp	(DeleteObject).l

MMZ_MechaBu_Unload:
		move.w	MMZ_bu_child(a0),d0
		beq.s	.unload
		movea.w	d0,a1
		cmpi.l	#MMZ_MechaBu_Blade,code(a1)
		bne.s	.unload
		move.w	a0,d0
		cmp.w	MMZ_bu_parent(a1),d0
		bne.s	.unload
		jsr	(DeleteObject2).l
.unload:
		jmp	(UnloadObject).l

MMZ_MechaBu_Blade:
		movea.w	MMZ_bu_parent(a0),a1
		cmpi.l	#MMZ_MechaBu_Fall,code(a1)
		beq.s	.owner
		cmpi.l	#MMZ_MechaBu_Walk,code(a1)
		bne.w	MMZ_MechaBu_Delete
.owner:
		move.w	a0,d0
		cmp.w	MMZ_bu_child(a1),d0
		bne.w	MMZ_MechaBu_Delete
		bsr.s	MMZ_MechaBu_BladePosition
		lea	Ani_MMZ_MechaBuSaw(pc),a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l

MMZ_MechaBu_BladePosition:
		move.w	obSubtype(a0),d2
		btst	#0,d2
		bne.s	MMZ_MechaBu_BladePose
		subq.w	#1,MMZ_bu_timer(a0)
		bpl.s	MMZ_MechaBu_BladePose
		move.w	#60,MMZ_bu_timer(a0)
		eori.b	#1,obAnim(a0)
MMZ_MechaBu_BladePose:
		movea.w	MMZ_bu_parent(a0),a1
		moveq	#-25,d0
		moveq	#0,d1
		tst.b	obAnim(a0)
		beq.s	.position
		moveq	#-19,d0
		moveq	#-15,d1
.position:
		btst	#0,obStatus(a0)
		beq.s	.offset
		neg.w	d0
.offset:
		move.w	d0,MMZ_bu_dx(a0)
		move.w	d1,MMZ_bu_dy(a0)
		add.w	obX(a1),d0
		add.w	obY(a1),d1
		move.w	d0,obX(a0)
		move.w	d1,obY(a0)
		rts

; The source's two reach poses share the ordinary two-frame spin cadence.
Ani_MMZ_MechaBuSaw:
		dc.w .low-Ani_MMZ_MechaBuSaw,.high-Ani_MMZ_MechaBuSaw
.low:		dc.b 2,0,1,$FF
.high:		dc.b 2,2,3,$FF
		even
Map_MMZ_MechaBu:
		binclude "mappings/sprite/MMZ MechaBu.bin"
		even
Map_MMZ_MechaBuSaw:
		binclude "mappings/sprite/MMZ MechaBu Saw.bin"
		even

; ===========================================================================
; Dango. The two shells share one state machine and use the existing Act 2
; atlas. Physics, animation and combat stay in the same SST.
; ===========================================================================

MMZ_dango_anim = objoff_30
MMZ_Dango_Rebounding = $16

MMZ_Dango:
		cmpi.b	#2,(Current_Timezone).w
		bne.s	.setup
		jmp	(DeleteObject).l
.setup:
		move.l	#MMZ_Dango_Run,code(a0)
		move.b	#2,obRoutine(a0)
		move.l	#Map_MMZ_Dango,obMap(a0)
		lea	Ani_MMZ_Dango(pc),a1
		btst	#0,obSubtype+1(a0)
		beq.s	.art
		move.l	#Map_MMZ_DangoSlow,obMap(a0)
		lea	Ani_MMZ_DangoSlow(pc),a1
.art:
		move.l	a1,MMZ_dango_anim(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$200,obPriority(a0)
		move.b	#sprite_bound(Map_MMZ_Dango_width,Map_MMZ_DangoSlow_width),width_pixels(a0)
		move.b	#sprite_bound(Map_MMZ_Dango_height,Map_MMZ_DangoSlow_height),height_pixels(a0)
		move.b	#14,obWidth(a0)
		move.b	#9,obHeight(a0)
		move.b	#Touch_Size_DangoBody_ID,obColType(a0)
		ori.b	#4,obRender(a0)
		st	obPrevAni(a0)

MMZ_Dango_Run:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	.states-2(pc,d0.w),d0
		jsr	.states(pc,d0.w)
		jmp	(MarkObjGone).l

.states:	dc.w MMZ_Dango_Fall-.states,MMZ_Dango_Patrol-.states
		dc.w MMZ_Dango_Animate-.states,MMZ_Dango_Curl-.states
		dc.w MMZ_Dango_Animate-.states,MMZ_Dango_BeginRoll-.states
		dc.w MMZ_Dango_Roll-.states,MMZ_Dango_Uncurl-.states
		dc.w MMZ_Dango_Animate-.states,MMZ_Dango_ResumeWalk-.states
		dc.w MMZ_Dango_Rebound-.states

MMZ_Dango_Fall:
		addq.w	#1,obY(a0)
		jsr	(ObjHitFloor).l
		bpl.s	.return
		add.w	d1,obY(a0)
		move.b	#4,obRoutine(a0)
		bra.s	MMZ_Dango_WalkSpeed
.return:	rts

MMZ_Dango_ResumeWalk:
		addq.w	#7,obY(a0)
		move.b	#9,obHeight(a0)
		move.b	#4,obRoutine(a0)
		clr.b	obAnim(a0)
MMZ_Dango_WalkSpeed:
		move.w	#$60,d0
		btst	#0,obSubtype+1(a0)
		beq.s	MMZ_Dango_SetSpeed
		moveq	#$10,d0
MMZ_Dango_SetSpeed:
		btst	#0,obStatus(a0)
		bne.s	.right
		neg.w	d0
.right:
		move.w	d0,obVelX(a0)
		bra.w	MMZ_Dango_Animate

MMZ_Dango_Patrol:
		bsr.w	MMZ_Dango_Step
		bmi.s	.reverse
		tst.w	(Debug_placement_mode).w
		bne.w	MMZ_Dango_Animate
		lea	(v_player).w,a1
		bsr.s	.target
		bcs.s	.windup
		lea	(v_player2).w,a1
		bsr.s	.target
		bcc.w	MMZ_Dango_Animate
.windup:
		move.b	#6,obRoutine(a0)
		move.b	#1,obAnim(a0)
		bra.w	MMZ_Dango_Animate
.reverse:
		bchg	#0,obStatus(a0)
		neg.w	obVelX(a0)
		bra.w	MMZ_Dango_Animate
.target:
		tst.l	code(a1)
		beq.s	.miss
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.miss
		tst.b	obControl(a1)
		bmi.s	.miss
		move.w	obX(a1),d0
		sub.w	obX(a0),d0
		btst	#0,obStatus(a0)
		bne.s	.x
		neg.w	d0
.x:
		cmpi.w	#128,d0
		bhs.s	.miss
		move.w	obY(a1),d0
		sub.w	obY(a0),d0
		addi.w	#128,d0
		tst.w	(Camera_Min_Y_pos).w
		bpl.s	.y
		andi.w	#Level_YWrapMask,d0
.y:
		cmpi.w	#256,d0
		rts
.miss:
		andi.b	#$FE,ccr
		rts

MMZ_Dango_Curl:
		subq.w	#7,obY(a0)
		move.b	#16,obHeight(a0)
		move.b	#10,obRoutine(a0)
		move.b	#2,obAnim(a0)
		bra.s	MMZ_Dango_Animate

MMZ_Dango_BeginRoll:
		addq.w	#3,obY(a0)
		move.b	#13,obHeight(a0)
		move.b	#Touch_Size_DangoShell_ID|$C0,obColType(a0)
		move.b	#14,obRoutine(a0)
		move.b	#3,obAnim(a0)
		move.w	#$400,d0
		btst	#0,obSubtype+1(a0)
		beq.w	MMZ_Dango_SetSpeed
		move.w	#$100,d0
		bra.w	MMZ_Dango_SetSpeed

MMZ_Dango_Rebound:
		tst.w	obVelX(a0)
		beq.s	MMZ_Dango_Uncurl
MMZ_Dango_Roll:
		bsr.s	MMZ_Dango_Step
		bpl.s	MMZ_Dango_Animate
MMZ_Dango_Uncurl:
		subq.w	#3,obY(a0)
		move.b	#16,obHeight(a0)
		move.b	#Touch_Size_DangoBody_ID,obColType(a0)
		move.b	#18,obRoutine(a0)
		move.b	#5,obAnim(a0)
MMZ_Dango_Animate:
		movea.l	MMZ_dango_anim(a0),a1
		jmp	(AnimateSprite).l

; Test the leading wall, then the floor. An obstruction rolls back the
; fractional step as well as the integer coordinate.
MMZ_Dango_Step:
		move.l	obX(a0),-(sp)
		jsr	(SpeedToPos).l
		moveq	#14,d3
		tst.w	obVelX(a0)
		bmi.s	.left
		jsr	(ObjHitWallRight).l
		bra.s	.floor
.left:
		moveq	#-14,d3
		jsr	(ObjHitWallLeft).l
.floor:
		bmi.s	.blocked
		jsr	(ObjHitFloor).l
		addq.w	#7,d1
		cmpi.w	#14,d1
		bhs.s	.blocked
		subq.w	#7,d1
		add.w	d1,obY(a0)
		addq.l	#4,sp
		moveq	#0,d1
		rts
.blocked:
		move.l	(sp)+,obX(a0)
		moveq	#-1,d1
		rts

; The special touch type routes only a curled shell here. The ordinary
; enemy response still handles upright contact and Tails's flight attack.
MMZ_Dango_Touch:
		btst	#status.player.rolling,obStatus(a0)
		bne.s	.bounce
		jmp	(Touch_Enemy).l
.bounce:
		move.w	obX(a0),d1
		sub.w	obX(a1),d1
		move.w	obY(a0),d2
		sub.w	obY(a1),d2
		jsr	(CalcAngle).l
		jsr	(CalcSine).l
		muls.w	#$700,d1
		asr.l	#8,d1
		muls.w	#$700,d0
		asr.l	#8,d0
		move.w	d1,obVelX(a0)
		move.w	d0,obVelY(a0)
		neg.w	d1
		move.w	d1,obVelX(a1)
		bset	#status.player.in_air,obStatus(a0)
		bclr	#status.player.on_object,obStatus(a0)
		bclr	#status.player.pushing,obStatus(a0)
		clr.b	jumping(a0)
		move.b	#MMZ_Dango_Rebounding,obRoutine(a1)
		move.b	#4,obAnim(a1)
		rts

Ani_MMZ_Dango:
		dc.w .walk-*,.wait-Ani_MMZ_Dango,.curl-Ani_MMZ_Dango,.roll-Ani_MMZ_Dango
		dc.w .bounce-Ani_MMZ_Dango,.uncurl-Ani_MMZ_Dango
.walk:		dc.b 9,0,1,afEnd
.wait:		dc.b 0,0,afRoutine
.curl:		dc.b 3,4,4,5,afRoutine
.roll:		dc.b 4,2,3,2,3,2,3,afRoutine
.bounce:	dc.b 4,2,3,afEnd
.uncurl:	dc.b 4,5,4,4,afRoutine
		even

Ani_MMZ_DangoSlow:
		dc.w .walk-*,.wait-Ani_MMZ_DangoSlow,.curl-Ani_MMZ_DangoSlow,.roll-Ani_MMZ_DangoSlow
		dc.w .bounce-Ani_MMZ_DangoSlow,.uncurl-Ani_MMZ_DangoSlow
.walk:		dc.b 29,0,1,afEnd
.wait:		dc.b 59,0,afRoutine
.curl:		dc.b 9,4,4,5,afRoutine
.roll:		dc.b 9,2,3,2,3,2,3,2,3,2,3,2,3,afRoutine
.bounce:	dc.b 9,2,3,afEnd
.uncurl:	dc.b 9,5,4,4,afRoutine
		even

Map_MMZ_Dango:	binclude "mappings/sprite/MMZ Dango 1.bin"
		even
Map_MMZ_DangoSlow:	binclude "mappings/sprite/MMZ Dango 2.bin"
		even

; Both acts load the same generator tiles at the same atlas offset. The Past
; bank adds the working machine; the other eras display its unpowered shell.
TimeGenerator:
		move.l	#Map_TimeGenerator,obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$200,obPriority(a0)
		move.b	#Map_TimeGenerator_height,height_pixels(a0)
		move.b	#Map_TimeGenerator_width,width_pixels(a0)
		ori.b	#4,obRender(a0)
		move.l	#TimeGenerator_Dormant,code(a0)
		cmpi.b	#1,(Current_Timezone).w
		beq.s	.past
		move.b	#2,obFrame(a0)
		cmpi.b	#2,(Current_Timezone).w
		beq.s	.restored
		tst.b	(TimeWarp_GoodFuture).l
		beq.s	TimeGenerator_Dormant
.restored:
		clr.b	obFrame(a0)
		bra.s	TimeGenerator_Dormant
.past:
		move.b	#1,obFrame(a0)
		tst.b	(TimeWarp_GoodFuture).l
		bne.s	TimeGenerator_Dormant
		move.l	#TimeGenerator_Active,code(a0)
		move.b	#2,obRoutine(a0)
		move.b	#3,obFrame(a0)
		move.b	#$C0|Touch_Size_TimeGenerator_ID,obColType(a0)
		subi.w	#16,obY(a0)
		bra.s	TimeGenerator_Active

TimeGenerator_Dormant:
		jmp	(MarkObjGone).l

; Standard rolling, spindash, invincibility and flight attacks break a
; working machine. Ordinary contact can safely stand on or push its body.
TimeGenerator_Touch:
		cmpi.b	#2,obRoutine(a1)
		bne.s	.return
		jsr	(Player_AttacksOnContact).l
		bcc.s	.return
		move.b	#4,obRoutine(a1)
.return:
		rts

TimeGenerator_Active:
		cmpi.b	#4,obRoutine(a0)
		beq.s	.break
		moveq	#$2B,d1
		moveq	#$18,d2
		moveq	#$18,d3
		move.w	obX(a0),d4
		jsr	(SolidObject_Always).l
		lea	Ani_TimeGenerator(pc),a1
		jsr	(AnimateSprite).l
		bra.s	TimeGenerator_Dormant
.break:
		clr.b	obColType(a0)
		jsr	(ReleaseObjectRiders).l
		move.b	#1,(TimeWarp_GoodFuture).l
		move.l	#TimeGenerator_Dormant,code(a0)
		move.b	#1,obFrame(a0)
		moveq	#15,d0
		jsr	(AddPoints).l
		jsr	(FindFreeObj).l
		bne.s	.no_effect
		move.l	#FieryExplosion,code(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
.no_effect:
		addi.w	#16,obY(a0)
		bra.w	TimeGenerator_Dormant

Ani_TimeGenerator:
		dc.w .on-Ani_TimeGenerator
.on:		dc.b 3,3,4,5,6,$FF
		even

Map_TimeGenerator:
		binclude "mappings/sprite/MMZ Generator.bin"
		even
