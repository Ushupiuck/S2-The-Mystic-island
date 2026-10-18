; Metallic Madness propeller obstacle, sonicretro/scddisasm test 791253ba.
; Original 1 px/frame, 128-frame patrol and alternating blade cycle. The
; mast is harmless; only fully spinning blades hurt, and cannot be destroyed.
; Three SSTs, all private state within $30-$3F; no shared RAM allocation.
prop_timer = objoff_30		; parent patrol / child phase timer (word)
prop_home_x = objoff_32		; parent placement X (word)
prop_upper = objoff_34		; parent upper blade SST (word)
prop_lower = objoff_36		; parent lower blade SST (word)
prop_parent = objoff_3C		; blade owner SST (word)
prop_y_offset = objoff_3E		; blade mount Y (word)
prop_x_step = obVelX			; parent 16.16 X step; also uses unused obVelY

MM_Propeller:
		tst.b	obRoutine(a0)
		beq.s	.init
		cmpi.b	#2,obRoutine(a0)
		beq.w	.settle
		move.l	prop_x_step(a0),d0
		add.l	d0,obX(a0)
		jsr	(ObjHitFloor).l
		add.w	d1,obY(a0)
		subq.w	#1,prop_timer(a0)
		bne.s	.range
		neg.l	prop_x_step(a0)
		move.w	#$80,prop_timer(a0)
.range:
		move.w	prop_home_x(a0),d0
		out_of_range3.s	.check_spawn
.draw:
		lea	Ani_MM_PropellerBase(pc),a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
.check_spawn:
		jsr	(Object_CheckSpawnXRange).l
		bls.s	.draw
		bra.w	MM_Propeller_Unload
.init:
		move.w	obX(a0),prop_home_x(a0)
		move.l	#Map_MM_PropellerBase,obMap(a0)
		move.w	#ArtTile_Propeller,obGfx(a0)
		andi.b	#1,obStatus(a0)
		andi.b	#1,obRender(a0)	; Y flip does not invert the mast
		ori.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#Map_MM_PropellerBase_width,width_pixels(a0)
		move.b	#Map_MM_PropellerBase_height,height_pixels(a0)
		move.b	#8,obWidth(a0)
		move.b	#$2E,obHeight(a0)
		move.l	#$10000,prop_x_step(a0)
		btst	#0,obStatus(a0)
		beq.s	.allocate
		neg.l	prop_x_step(a0)
.allocate:
		; Allocate both blades atomically. Retry with a harmless mast if
		; the pool is full; never leave a single blade or leak a slot.
		jsr	(FindFreeObj).l
		bne.s	.wait
		move.w	a1,prop_upper(a0)
		move.l	#MM_PropellerBlade,code(a1)
		jsr	(FindFreeObj).l
		beq.s	.allocated
		movea.w	prop_upper(a0),a1
		jsr	(DeleteObject2).l
		clr.w	prop_upper(a0)
.wait:
		bra.w	.range
.allocated:
		move.w	a1,prop_lower(a0)
		move.w	#$80,prop_timer(a0)
		move.b	#2,obRoutine(a0)
		bsr.s	.land			; settle before setting either blade's position
		movea.w	prop_lower(a0),a1
		move.w	#$14,prop_y_offset(a1)
		move.b	#2,obStatus(a1)	; lower blades are Y flipped
		moveq	#0,d0			; lower blade starts folded
		bsr.s	.initblade
		movea.w	prop_upper(a0),a1
		move.w	#-$2C,prop_y_offset(a1)
		clr.b	obStatus(a1)
		moveq	#8,d0			; upper blade starts unfolding
		bsr.s	.initblade
		bra.w	.range
.settle:
		bsr.s	.land
		bra.w	.range
.land:
		addq.w	#1,obY(a0)
		jsr	(ObjHitFloor).l
		tst.w	d1
		bpl.s	.landed
		add.w	d1,obY(a0)
		move.b	#4,obRoutine(a0)
.landed:
		rts
.initblade:
		move.l	#MM_PropellerBlade,code(a1)
		move.w	a0,prop_parent(a1)
		move.b	d0,ob2ndRout(a1)
		move.b	#6,obFrame(a1)
		move.w	#5,prop_timer(a1)
		; An earlier SST first runs next frame. Account for the birth
		; frame here so both blades retain CD's phase relationship even
		; when allocation straddles the parent's position in the pool.
		move.w	a1,d0
		cmp.w	a0,d0
		bhs.s	.born
		subq.w	#1,prop_timer(a1)
.born:
		move.b	obStatus(a1),obRender(a1)
		ori.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.l	#Map_MM_PropellerBlade,obMap(a1)
		move.w	#ArtTile_Propeller,obGfx(a1)
		move.b	#Map_MM_PropellerBlade_width,width_pixels(a1)
		move.b	#Map_MM_PropellerBlade_height,height_pixels(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),d0
		add.w	prop_y_offset(a1),d0
		move.w	d0,obY(a1)
		rts

MM_PropellerBlade:
		; Validate both directions. A recycled parent slot, including a
		; new propeller in that slot, must not adopt an old blade.
		movea.w	prop_parent(a0),a1
		cmpi.l	#MM_Propeller,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	prop_upper(a1),d0
		beq.s	.owned
		cmp.w	prop_lower(a1),d0
		bne.s	.delete
.owned:
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),d0
		add.w	prop_y_offset(a0),d0
		move.w	d0,obY(a0)
.timer:
		subq.w	#1,prop_timer(a0)
		bne.s	.animate
		addq.b	#4,ob2ndRout(a0)
		andi.b	#15,ob2ndRout(a0)
		moveq	#0,d0
		move.b	ob2ndRout(a0),d0
		lea	.phases(pc,d0.w),a1
		move.b	(a1)+,obFrame(a0)
		move.b	(a1)+,obColType(a0)
		move.w	(a1),prop_timer(a0)
		cmpi.b	#12,d0
		bne.s	.timer
		move.w	#$FF,obAnim(a0)	; restart the six spinning frames
		bra.s	.timer
.animate:
		cmpi.b	#12,ob2ndRout(a0)
		bne.s	.draw
		lea	Ani_MM_PropellerBlade(pc),a1
		jsr	(AnimateSprite).l
.draw:
		jmp	(DisplaySprite).l
.delete:
		jmp	(DeleteObject).l
.phases:
		; Frame, touch response, timer. Like CD, the next phase ticks on
		; the transition frame: 4-frame folds and 72-frame held phases.
		dc.b	6,0
		dc.w	5
		dc.b	7,0
		dc.w	$49
		dc.b	6,0
		dc.w	5
		dc.b	0,$80+(Touch_Size_Propeller-Touch_Sizes)/2+1
		dc.w	$49

MM_Propeller_Unload:
		movea.w	prop_upper(a0),a1
		bsr.s	.deleteblade
		movea.w	prop_lower(a0),a1
		bsr.s	.deleteblade
		jmp	(UnloadObject).l
.deleteblade:
		move.w	a1,d0
		beq.s	.return
		cmpi.l	#MM_PropellerBlade,code(a1)
		bne.s	.return
		move.w	a0,d0
		cmp.w	prop_parent(a1),d0
		bne.s	.return
		jmp	(DeleteObject2).l
.return:
		rts

Ani_MM_PropellerBase:
		dc.w	.base-Ani_MM_PropellerBase
.base:
		dc.b	$A,0,1,$FF
Ani_MM_PropellerBlade:
		dc.w	.blade-Ani_MM_PropellerBlade
.blade:
		dc.b	2,0,1,2,3,4,5,$FF
		even
Map_MM_PropellerBase:
		binclude	"mappings/sprite/MM Propeller base.bin"
		even
Map_MM_PropellerBlade:
		binclude	"mappings/sprite/MM Propeller blade.bin"
		even
