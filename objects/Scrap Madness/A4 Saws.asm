; Stationary, oscillating, speeding and diagonal saws, object $A4.
; The movement parameters differ; all blades use the same drawing, frame-pair
; animation and lifetime. The diagonal rail is an optional linked attachment.
saw_origin_y:	equ objoff_38
saw_origin_x:	equ objoff_3A
saw_handle:	equ objoff_3C	; reciprocal word pointer, zero without a rail
saw_parent:	equ objoff_3E
saw_sound:	equ objoff_40	; visible updates for a diagonal blade
saw_stage_step:	equ objoff_42	; signed, next frame-pair change when travelling
MMZ_saw_timer:	equ objoff_2E
saw_stages:	equ objoff_30

SMZ_Saws:
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.w	Saw_InitDiagonal
		cmpi.b	#id_MMZ,(v_zone).w	; editor byte presets
		beq.w	Saw_InitDiagonal
		andi.w	#7,d0
		cmpi.w	#4,d0
		bls.s	.select
		moveq	#0,d0
.select:
		add.w	d0,d0
		lea	Saw_Movement(pc),a1
		adda.w	(a1,d0.w),a1
		move.l	a1,code(a0)
		move.b	#2,obRoutine(a0)
		move.l	#Map_SMZ_Saw,obMap(a0)
		move.b	#Map_SMZ_Saw_height,height_pixels(a0)
		move.w	#ArtTile_SMZ_Atlas,obGfx(a0)
		move.b	#4,obRender(a0)
		move.w	#$200,obPriority(a0)
		move.b	#32,width_pixels(a0)
		move.w	obX(a0),saw_origin_x(a0)
		move.w	obY(a0),saw_origin_y(a0)
		cmpi.w	#3*2,d0
		bhs.s	.update
		move.b	#$22|$80,obColType(a0)
.update:
		jmp	(a1)

Saw_Movement:
		dc.w Saw_Draw-Saw_Movement
		dc.w Saw_OscillateX-Saw_Movement
		dc.w Saw_OscillateY-Saw_Movement
		dc.w Saw_WaitLeft-Saw_Movement
		dc.w Saw_WaitRight-Saw_Movement

Saw_OscillateX:
		moveq	#0,d0
		move.b	(v_oscillate+$E).w,d0
		btst	#0,obStatus(a0)
		beq.s	.position
		neg.w	d0
		addi.w	#$60,d0
.position:
		move.w	saw_origin_x(a0),d1
		sub.w	d0,d1
		move.w	d1,obX(a0)
		moveq	#2,d0
		bsr.w	Saw_AnimatePair
		tst.b	obRender(a0)
		bpl.w	Saw_Draw
		move.w	(v_framecount).w,d0
		andi.w	#$F,d0
		bne.w	Saw_Draw
		bra.w	Saw_BuzzDraw

Saw_OscillateY:
		moveq	#0,d0
		move.b	(v_oscillate+6).w,d0
		btst	#0,obStatus(a0)
		beq.s	.position
		neg.w	d0
		addi.w	#$80,d0
.position:
		move.w	saw_origin_y(a0),d1
		sub.w	d0,d1
		move.w	d1,obY(a0)
		moveq	#2,d0
		bsr.w	Saw_AnimatePair
		tst.b	obRender(a0)
		bpl.w	Saw_Draw
		cmpi.b	#$18,(v_oscillate+6).w
		bne.w	Saw_Draw
		bra.w	Saw_BuzzDraw

; The two directional triggers retain their original different X distances.
Saw_WaitLeft:
		move.w	(v_player+obX).w,d0
		subi.w	#192,d0
		bcs.w	Saw_Cull
		cmp.w	obX(a0),d0
		blo.w	Saw_Cull
		move.w	#$600,d1
		bra.s	Saw_Trigger

Saw_WaitRight:
		move.w	(v_player+obX).w,d0
		addi.w	#224,d0
		cmp.w	obX(a0),d0
		bhs.w	Saw_Cull
		move.w	#-$600,d1

Saw_Trigger:
		move.w	(v_player+obY).w,d0
		subi.w	#128,d0
		cmp.w	obY(a0),d0
		bhs.w	Saw_Draw
		addi.w	#256,d0
		cmp.w	obY(a0),d0
		blo.w	Saw_Draw
		move.l	#Saw_Projectile,code(a0)
		move.w	d1,obVelX(a0)
		move.b	#$22|$80,obColType(a0)
		move.b	#2,obFrame(a0)
		move.w	#SndID_LaserBeam,d0
		jsr	(PlaySound_Special).l
		bra.w	Saw_Cull			; first visible on the next moving update

Saw_Projectile:
		jsr	(ObjectMove).l
		move.w	obX(a0),saw_origin_x(a0)
		moveq	#2,d0
		bsr.w	Saw_AnimatePair
		bra.w	Saw_Draw

Saw_InitDiagonal:
		jsr	(FindFreeObj).l
		bne.w	.return	; retry the intact placement without leaking a handle
		move.w	a1,saw_handle(a0)
		move.w	a0,saw_parent(a1)
		move.l	#Saw_Handle,code(a1)
		move.l	#Map_MMZ_SawHandle,obMap(a1)
		move.b	#Map_MMZ_SawHandle_width,width_pixels(a1)
		move.b	#Map_MMZ_SawHandle_height,height_pixels(a1)
		move.w	obX(a0),obX(a1)
		move.w	obY(a0),obY(a1)
		move.b	obStatus(a0),obStatus(a1)
		move.b	obStatus(a0),obRender(a1)
		ori.b	#4,obRender(a1)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a1)
		move.w	#$200,obPriority(a1)
		move.l	#Map_MMZ_Saw,obMap(a0)
		move.b	#Map_MMZ_Saw_width,width_pixels(a0)
		move.b	#Map_MMZ_Saw_height,height_pixels(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$180,obPriority(a0)
		move.b	obStatus(a0),obRender(a0)
		ori.b	#4,obRender(a0)
		move.b	#$80|Touch_Size_MMZSaw_ID,obColType(a0)
		move.w	obX(a0),saw_origin_x(a0)
		move.w	#$100,obVelX(a0)
		move.w	#$100,obVelY(a0)
		moveq	#80,d0
		moveq	#80,d1
		btst	#0,obStatus(a0)
		beq.s	.y_direction
		neg.w	obVelX(a0)
		neg.w	d0
.y_direction:
		btst	#1,obStatus(a0)
		beq.s	.phase
		neg.w	obVelY(a0)
		neg.w	d1
.phase:
		move.l	#Saw_DiagonalHold,code(a0)
		move.w	obSubtype(a0),d2
		btst	#7,d2
		beq.s	.start
		move.b	#9,obAnim(a0)
		sub.w	d0,obX(a1)
		sub.w	d1,obY(a1)
.start:
		move.b	#-1,obPrevAni(a0)
		move.w	#59,MMZ_saw_timer(a0)
		; Retain the one-pixel displacement on the first drawn update.
		jsr	(ObjectMove).l
		move.b	#1,saw_stage_step(a0)
		tst.b	obAnim(a0)
		bne.s	Saw_DiagonalAnimate
		bsr.s	Saw_ReverseDiagonal
		bra.s	Saw_DiagonalAnimate
.return:
		rts

Saw_DiagonalHold:
		subq.w	#1,MMZ_saw_timer(a0)
		bne.s	Saw_DiagonalAnimate
		bsr.s	Saw_ReverseDiagonal
		move.l	#Saw_DiagonalTravel,code(a0)
		move.w	#9,saw_stages(a0)
		move.w	#1,MMZ_saw_timer(a0)
		bra.s	Saw_DiagonalAnimate

Saw_ReverseDiagonal:
		neg.w	obVelX(a0)
		neg.w	obVelY(a0)
		neg.b	saw_stage_step(a0)
		rts

Saw_DiagonalTravel:
		subq.w	#1,MMZ_saw_timer(a0)
		bne.s	.move
		move.b	saw_stage_step(a0),d0
		add.b	d0,obAnim(a0)
		move.w	#9,MMZ_saw_timer(a0)
		subq.w	#1,saw_stages(a0)
		bne.s	.move
		move.l	#Saw_DiagonalHold,code(a0)
		move.w	#60,MMZ_saw_timer(a0)
.move:
		jsr	(ObjectMove).l
Saw_DiagonalAnimate:
		move.b	obAnim(a0),d0
		cmp.b	obPrevAni(a0),d0
		beq.s	.pair
		move.b	d0,obPrevAni(a0)
		cmpi.b	#8,d0
		bls.s	.frame
		moveq	#8,d0			; stage 9 uses the fully extended pair
.frame:
		add.b	d0,d0
		move.b	d0,obFrame(a0)
		move.b	#1,obTimeFrame(a0)
		bra.s	.sound
.pair:
		moveq	#1,d0
		bsr.s	Saw_AnimatePair
.sound:
		tst.b	obRender(a0)
		bpl.s	Saw_Draw
		addq.w	#1,saw_sound(a0)
		move.w	saw_sound(a0),d0
		andi.w	#31,d0
		bne.s	Saw_Draw

Saw_BuzzDraw:
		move.w	#SndID_LaserBeam,d0
		jsr	(PlaySound_Special).l
Saw_Draw:
		out_of_range2	Saw_Unload,saw_origin_x(a0)
		jmp	(DisplaySprite).l

Saw_Cull:
		out_of_range2	Saw_Unload,saw_origin_x(a0)
		rts

; d0.b: delay minus one (two updates for the rail, three for the other blades).
Saw_AnimatePair:
		subq.b	#1,obTimeFrame(a0)
		bpl.s	.return
		move.b	d0,obTimeFrame(a0)
		bchg	#0,obFrame(a0)
.return:
		rts

Saw_Handle:
		movea.w	saw_parent(a0),a1
		tst.l	code(a1)
		beq.s	.delete
		cmpi.l	#Map_MMZ_Saw,obMap(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	saw_handle(a1),d0
		bne.s	.delete
		jmp	(DisplaySprite).l
.delete:
		jmp	(DeleteObject).l

Saw_Unload:
		move.w	saw_handle(a0),d0
		beq.s	.delete
		movea.w	d0,a1
		cmpi.l	#Saw_Handle,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	saw_parent(a1),d0
		bne.s	.delete
		jsr	(DeleteObject2).l
.delete:
		jmp	(UnloadObject).l

Map_SMZ_Saw:		binclude "mappings/sprite/SMZ Saw.bin"
		even
Map_MMZ_Saw:		binclude "mappings/sprite/MMZ Saw.bin"
		even
Map_MMZ_SawHandle:	binclude "mappings/sprite/MMZ Saw Handle.bin"
		even
