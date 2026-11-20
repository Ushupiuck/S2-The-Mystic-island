; ---------------------------------------------------------------------------
; Object $0A - per-actor collision path and sprite priority switcher.
; ---------------------------------------------------------------------------

PathSwitch_Door		equ $100	; the act must load the MMZ2 door art
switch_inside		equ objoff_34	; bits 7/6: primary/companion inside the trigger
switch_turn		equ objoff_35	; remaining door animation updates
switch_half_width	equ objoff_36
switch_half_height	equ objoff_38

CollisionSwitcher:
		move.l	#CollisionSwitcher_Run,code(a0)
		move.l	#Map_Obj03,obMap(a0)
		move.b	#Map_Obj03_height,height_pixels(a0)
		move.w	#make_art_tile(ArtTile_Ring,1,0),obGfx(a0)
		move.b	#4,obRender(a0)
		move.b	#sprite_bound($10,Map_Obj03_width),width_pixels(a0)
		move.w	#$280,obPriority(a0)

		move.w	obSubtype(a0),d0
		move.w	d0,d1
		andi.w	#7,d1
		move.b	d1,obFrame(a0)
		andi.w	#3,d1
		moveq	#$20,d2
		lsl.w	d1,d2
		btst	#8,d0
		beq.s	.set_extent
		move.l	#Map_MMZ_RevolveDoor,obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.b	#Map_MMZ_RevolveDoor_width,width_pixels(a0)
		move.b	#Map_MMZ_RevolveDoor_height,height_pixels(a0)
		move.b	#2,obFrame(a0)
		moveq	#Map_MMZ_RevolveDoor_height,d2	; upright door span
		btst	#2,d0
		beq.s	.set_extent
		clr.b	obFrame(a0)
		moveq	#Map_MMZ_RevolveDoor_width,d2	; horizontal door span

.set_extent:
		moveq	#8,d1
		btst	#2,d0
		beq.s	.store_extent
		exg	d1,d2
.store_extent:
		move.w	d1,switch_half_width(a0)
		move.w	d2,switch_half_height(a0)

CollisionSwitcher_Run:
		tst.w	(Debug_placement_mode).w
		bne.s	.draw
		move.w	obX(a0),d2
		move.w	d2,d3
		sub.w	switch_half_width(a0),d2
		add.w	switch_half_width(a0),d3
		move.w	obY(a0),d4
		move.w	d4,d5
		sub.w	switch_half_height(a0),d4
		add.w	switch_half_height(a0),d5

		lea	(v_player).w,a1
		moveq	#7,d6
		bsr.w	CollisionSwitcher_Actor
		lea	(v_player2).w,a1
		moveq	#6,d6
		bsr.w	CollisionSwitcher_Actor

.draw:
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.w	CollisionSwitcher_DrawDoor
		tst.b	(Debug_mode_flag).w
		bne.w	MarkObjGone
		bra.w	MarkObjGone2

; d2-d5 = trigger bounds [min,max), d6 = this actor's occupancy bit.
CollisionSwitcher_Actor:
		tst.l	code(a1)
		beq.s	.missing
		move.w	obX(a1),d1
		cmp.w	d2,d1
		blo.s	.exit
		cmp.w	d3,d1
		bhs.s	.exit
		move.w	obY(a1),d1
		cmp.w	d4,d1
		blo.s	.exit
		cmp.w	d5,d1
		bhs.s	.exit
		bset	d6,switch_inside(a0)
		bne.s	.return
		move.w	obSubtype(a0),d0
		btst	#8,d0
		beq.s	.return
		move.b	#16,switch_turn(a0)
.return:
		rts

.missing:
		bclr	d6,switch_inside(a0)
		rts

.exit:
		bclr	d6,switch_inside(a0)
		beq.s	.return
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	.side
		btst	#1,obStatus(a1)
		bne.s	.return
.side:
		btst	#2,d0
		bne.s	.vertical_crossing
		move.w	obX(a1),d1
		cmp.w	obX(a0),d1
		bra.s	.select_side
.vertical_crossing:
		move.w	obY(a1),d1
		cmp.w	obY(a0),d1
.select_side:
		bhs.s	.apply
		lsr.w	#1,d0				; left/up settings into the right/down bits
.apply:
		move.w	#$0C0D,d1
		btst	#3,d0
		beq.s	.path
		move.w	#$0E0F,d1
.path:
		move.w	d1,obTopSolidBit(a1)
		bclr	#7,obGfx(a1)
		btst	#5,d0
		beq.s	.sound
		bset	#7,obGfx(a1)
.sound:
		tst.b	(Debug_mode_flag).w
		beq.s	.return
		move.w	#SndID_Checkpoint,d0
		jmp	(PlaySound_Special).l

; Either actor starts the same short turn. The horizontal mapping alternates
; panel poses; the upright rail alternates its shading using the sprite flip.
CollisionSwitcher_DrawDoor:
		moveq	#2,d1
		btst	#2,d0
		beq.s	.pose
		moveq	#0,d1
.pose:
		bclr	#0,obRender(a0)
		tst.b	switch_turn(a0)
		beq.s	.draw
		subq.b	#1,switch_turn(a0)
		btst	#2,switch_turn(a0)
		beq.s	.draw
		tst.b	d1
		bne.s	.flip_rail
		moveq	#1,d1
		bra.s	.draw
.flip_rail:
		bset	#0,obRender(a0)
.draw:
		move.b	d1,obFrame(a0)
		bra.w	MarkObjGone

Map_MMZ_RevolveDoor:
		binclude "mappings/sprite/MMZ RevolveDoor.bin"
		even
