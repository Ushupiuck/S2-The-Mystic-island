; ---------------------------------------------------------------------------
; Object $0A - per-actor collision path and sprite priority switcher.
; ---------------------------------------------------------------------------

PathSwitch_Door		equ $100	; the act must load the MMZ2 door art
PathSwitch_Revolving	equ $200	; alternate the current path from the boarded base
PathSwitch_DoorBaseY	equ 88
PathSwitch_DoorBaseH	equ 8
PathSwitch_DoorRailH	equ 80
switch_inside		equ objoff_34	; bits 7/6: primary/companion inside the trigger
switch_previous		equ objoff_34	; invisible line: one previous side per actor ($01 = unset)
switch_turn		equ objoff_35	; remaining door animation updates
switch_half_width	equ objoff_36
switch_half_height	equ objoff_38

CollisionSwitcher:
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
		bne.s	.door
		move.l	#CollisionSwitcher_Line,code(a0)
		move.w	#$0101,switch_previous(a0)
		move.w	d2,switch_half_height(a0)	; line half-length on either axis
		bra.w	CollisionSwitcher_Line
.door:
		move.l	#CollisionSwitcher_Run,code(a0)
		move.l	#Map_MMZ_RevolveDoor,obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.b	#Map_MMZ_RevolveDoor_width,width_pixels(a0)
		move.b	#Map_MMZ_RevolveDoor_height,height_pixels(a0)
		move.b	#2,obFrame(a0)
		moveq	#PathSwitch_DoorRailH,d2
		btst	#9,d0
		beq.s	.door_axis
		move.b	#3,obFrame(a0)
		moveq	#16,d2				; rider origin range above the bottom cap
		bra.s	.set_extent
.door_axis:
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
		btst	#1,obSubtype(a0)		; PathSwitch_Revolving
		beq.s	.bounds
		addi.w	#PathSwitch_DoorBaseY,obY(a0)
		moveq	#40+sonic_solid_width,d1
		moveq	#PathSwitch_DoorBaseH,d2
		moveq	#PathSwitch_DoorBaseH+1,d3
		move.w	obX(a0),d4
		jsr	(PlatformObject).l
		subi.w	#PathSwitch_DoorBaseY,obY(a0)
.bounds:
		move.w	obX(a0),d2
		move.w	d2,d3
		sub.w	switch_half_width(a0),d2
		add.w	switch_half_width(a0),d3
		move.w	obY(a0),d4
		btst	#1,obSubtype(a0)
		beq.s	.height
		addi.w	#PathSwitch_DoorBaseY-26,d4
.height:
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
		bra.w	CollisionSwitcher_DrawDoor

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
		btst	#1,obSubtype(a0)
		beq.s	.enter
		jsr	(ObjectOwnsRider).l
		bne.s	.missing
.enter:
		bset	d6,switch_inside(a0)
		bne.s	.return
		move.w	obSubtype(a0),d0
		move.b	#16,switch_turn(a0)
		btst	#9,d0
		beq.s	.return
		move.w	#$0C0D,d0
		bset	#7,obGfx(a1)
		cmpi.b	#$E,obTopSolidBit(a1)
		beq.s	.path_ready
		move.w	#$0E0F,d0
		bclr	#7,obGfx(a1)
.path_ready:
		move.w	d0,obTopSolidBit(a1)
.return:
		rts

.missing:
		bclr	d6,switch_inside(a0)
		rts

.exit:
		bclr	d6,switch_inside(a0)
		beq.s	.return
		move.w	obSubtype(a0),d0
		btst	#9,d0
		bne.s	.return
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
		bhs.s	CollisionSwitcher_Apply
CollisionSwitcher_ApplyNegative:
		lsr.w	#1,d0				; left/up settings into the right/down bits
CollisionSwitcher_Apply:
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
		beq.s	CollisionSwitcher_Actor.return
		move.w	#SndID_Checkpoint,d0
		jmp	(PlaySound_Special).l

; Invisible S2 lines trigger on a side change within the perpendicular span.
; A fast roll can cross the entire door band in one update.
CollisionSwitcher_Line:
		tst.w	(Debug_placement_mode).w
		beq.s	.active
		move.w	#$0101,switch_previous(a0)
		bra.s	.draw
.active:
		moveq	#obX,d5
		moveq	#obY,d6
		btst	#2,obFrame(a0)
		beq.s	.bounds
		exg	d5,d6
.bounds:
		move.w	(a0,d5.w),d2		; crossing coordinate
		move.w	switch_half_height(a0),d4
		move.w	(a0,d6.w),d3
		sub.w	d4,d3			; first coordinate along the line
		add.w	d4,d4			; full span
		lea	switch_previous(a0),a2
		lea	(v_player).w,a1
		bsr.s	CollisionSwitcher_LineActor
		addq.l	#1,a2
		lea	(v_player2).w,a1
		bsr.s	CollisionSwitcher_LineActor
.draw:
		tst.b	(Debug_mode_flag).w
		bne.w	MarkObjGone
		bra.w	MarkObjGone2

CollisionSwitcher_LineActor:
		tst.l	code(a1)
		beq.s	.missing
		cmp.w	(a1,d5.w),d2
		sls	d1			; $FF on the right/down side, including equality
		cmp.b	(a2),d1
		beq.s	.return
		move.b	(a2),d0
		move.b	d1,(a2)
		subq.b	#1,d0
		beq.s	.return			; initialize a newly loaded gate/actor
		move.w	(a1,d6.w),d0
		sub.w	d3,d0
		cmp.w	d4,d0
		bhs.s	.return
		move.w	obSubtype(a0),d0
		tst.b	d0
		bpl.s	.side
		btst	#status.player.in_air,obStatus(a1)
		bne.s	.return
.side:
		tst.b	d1
		bmi.w	CollisionSwitcher_Apply
		bra.w	CollisionSwitcher_ApplyNegative
.missing:
		move.b	#1,(a2)
.return:
		rts

; Either actor starts the same short turn. The horizontal mapping alternates
; panel poses; the upright rail alternates its shading using the sprite flip.
CollisionSwitcher_DrawDoor:
		btst	#9,d0
		beq.s	.standard
		moveq	#3,d1
		tst.b	switch_turn(a0)
		beq.s	.draw
		subq.b	#1,switch_turn(a0)
		btst	#2,switch_turn(a0)
		beq.s	.draw
		moveq	#4,d1
		bra.s	.draw
.standard:
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
