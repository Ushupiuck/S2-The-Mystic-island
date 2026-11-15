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
