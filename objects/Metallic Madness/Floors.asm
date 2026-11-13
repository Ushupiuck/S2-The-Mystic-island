; ---------------------------------------------------------------------------
; MMZ's progressively crumbling floor. Low seven bits: 1-8 columns;
; bit 7: static full-solid block. The word subtype remains an editor setting.
; MD CPU. CD source: r8/collapse_floor.asm, scddisasm test 791253ba.
MMZ_floor_origin:	equ objoff_2E
MMZ_floor_count:	equ objoff_30
MMZ_floor_step:	equ objoff_32
MMZ_floor_timer:	equ objoff_34
MMZ_floor_speed:	equ objoff_36 ; long, 16.16 falling-piece speed

MMZ_Floor_Init:
		move.w	obSubtype(a0),d0
		move.w	d0,d1
		andi.w	#$7F,d0
		subq.w	#1,d0
		cmpi.w	#7,d0
		bls.s	.size
		moveq	#0,d0	; malformed lengths safely use one column
.size:
		move.b	d0,obFrame(a0)
		addq.w	#1,d0
		move.w	d0,MMZ_floor_count(a0)
		lsl.w	#3,d0
		move.b	d0,obWidth(a0)
		move.b	d0,width_pixels(a0)
		move.b	#Map_MMZ_Floor_height,height_pixels(a0)
		move.b	#16,obHeight(a0)
		move.l	#Map_MMZ_Floor,obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		ori.b	#4,obRender(a0)
		move.w	#$180,obPriority(a0)
		move.w	obX(a0),MMZ_floor_origin(a0)
		move.l	#MMZ_Floor_Idle,code(a0)
		btst	#7,d1
		beq.s	MMZ_Floor_Draw
		move.w	#$80,obPriority(a0)
		move.l	#MMZ_Floor_Static,code(a0)
		bra.s	MMZ_Floor_Draw

MMZ_Floor_Idle:
		bsr.w	MMZ_Floor_SolidTop
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	MMZ_Floor_Draw
		move.l	#MMZ_Floor_Delay,code(a0)
		move.w	#8,MMZ_floor_timer(a0)
		moveq	#8,d0
		lea	(v_player).w,a1
		btst	#3,obStatus(a0)
		bne.s	.direction
		lea	(v_player2).w,a1
.direction:
		tst.w	obVelX(a1)
		bpl.s	.step
		neg.w	d0
.step:
		move.w	d0,MMZ_floor_step(a0)
		move.w	#sfx_Collapse,d0
		jsr	(PlaySound_Special).l
MMZ_Floor_Draw:
		out_of_range2.w MMZ_Floor_Unload,MMZ_floor_origin(a0)
		jmp	(DisplaySprite).l

MMZ_Floor_Delay:
		bsr.w	MMZ_Floor_SolidTop
		subq.w	#1,MMZ_floor_timer(a0)
		bpl.s	.draw
		move.l	#MMZ_Floor_Break,code(a0)
.draw:
		jmp	(DisplaySprite).l

MMZ_Floor_Break:
		move.w	MMZ_floor_count(a0),d3
		subq.w	#1,d3
		lsl.w	#3,d3
		tst.w	MMZ_floor_step(a0)
		bmi.s	.edge
		neg.w	d3
.edge:
		add.w	obX(a0),d3
		movea.w	d3,a3
		moveq	#0,d5
.piece:
		jsr	(FindFreeObj).l
		bne.s	.shrink
		move.l	#MMZ_FloorPiece_Start,code(a1)
		move.l	#Map_MMZ_Floor,obMap(a1)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a1)
		move.b	#4,obRender(a1)
		move.w	#$180,obPriority(a1)
		move.b	#8,width_pixels(a1)
		move.b	#8,height_pixels(a1)
		move.w	a3,obX(a1)
		move.w	obY(a0),d0
		subq.w	#8,d0
		move.b	#8,obFrame(a1)
		move.w	#4,MMZ_floor_timer(a1)
		tst.w	d5
		beq.s	.place
		addi.w	#16,d0
		move.b	#9,obFrame(a1)
		clr.w	MMZ_floor_timer(a1)
.place:
		move.w	d0,obY(a1)
		addq.w	#1,d5
		cmpi.w	#2,d5
		blo.s	.piece
.shrink:
		subq.w	#1,MMZ_floor_count(a0)
		beq.s	.finished
		subq.b	#1,obFrame(a0)
		subq.b	#8,obWidth(a0)
		subq.b	#8,width_pixels(a0)
		move.w	MMZ_floor_step(a0),d0
		add.w	d0,obX(a0)
		move.w	#7,MMZ_floor_timer(a0)
		move.l	#MMZ_Floor_Delay,code(a0)
; The remaining surface is stationary. Validate both riders against its new
; extent without dragging them eight pixels or releasing/relanding them.
		bsr.s	MMZ_Floor_SolidTop
		jmp	(DisplaySprite).l
.finished:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(DeleteObject).l

MMZ_Floor_Static:
		moveq	#0,d1
		move.b	obWidth(a0),d1
		addi.w	#sonic_solid_width,d1
		moveq	#16,d2
		moveq	#17,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		bra.w	MMZ_Floor_Draw

MMZ_Floor_SolidTop:
		moveq	#0,d1
		move.b	obWidth(a0),d1
		moveq	#16,d3
		move.w	obX(a0),d4
		jmp	(PlatformObject).l

MMZ_Floor_Unload:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(UnloadObject).l

MMZ_FloorPiece_Start:
		move.l	#MMZ_FloorPiece_Wait,code(a0)
		jmp	(DisplaySprite).l
MMZ_FloorPiece_Wait:
		subq.w	#1,MMZ_floor_timer(a0)
		bpl.s	.draw
		move.l	#MMZ_FloorPiece_Fall,code(a0)
.draw:
		jmp	(DisplaySprite).l
MMZ_FloorPiece_Fall:
		tst.b	obRender(a0)
		bmi.s	.active
		jmp	(DeleteObject).l
.active:
		move.l	MMZ_floor_speed(a0),d0
		addi.l	#$4000,d0
		cmpi.l	#$160000,d0
		ble.s	.speed
		move.l	#$160000,d0
.speed:
		move.l	d0,MMZ_floor_speed(a0)
		add.l	d0,obY(a0)
		jmp	(DisplaySprite).l

Map_MMZ_Floor:	binclude "mappings/sprite/MMZ Floor.bin"
		even
