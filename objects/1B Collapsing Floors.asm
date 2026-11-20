; Object $1B. Intact floors share contact and countdown. A floor's
; breakup either replaces the entire slab or removes one column at a time.
floor_origin:		equ objoff_2E
floor_columns:		equ objoff_30	; word, zero for the full slab
floor_step:		equ objoff_32	; signed center shift per disappearing column
floor_timer:		equ objoff_34
floor_break:		equ objoff_36	; selected breakup routine
floor_piece_delay:	equ objoff_3C	; byte, also used by the shared ledge fragmenter
floor_piece_support:	equ objoff_3E	; first slab piece carries the old riders

Obj1B:
		move.l	#Floor_Wait,code(a0)
		move.b	#2,obRoutine(a0)
		ori.b	#4,obRender(a0)
		move.w	obX(a0),floor_origin(a0)
		move.w	obSubtype(a0),d0
		btst	#8,d0
		bne.s	Floor_InitColumns
		cmpi.b	#id_MMZ,(Current_Zone).w	; editor byte presets
		beq.s	Floor_InitColumns
		move.l	#Map_Obj1B,obMap(a0)
		move.b	#Map_Obj1B_height,height_pixels(a0)
		move.w	#make_art_tile($2B8,2,0),obGfx(a0)	; we default to marble zone
		cmpi.b	#id_SLZ,(Current_Zone).w
		bne.s	loc_8D8E
		move.w	#make_art_tile($4E0,2,0),obGfx(a0)	; unless we're in Star light
		addq.b	#2,obFrame(a0)

loc_8D8E:
		cmpi.b	#id_SMZ,(Current_Zone).w
		bne.s	loc_8D9C
		move.w #ArtTile_SMZ_Atlas,obGfx(a0)
		move.l #Map_SMZ_Floor,obMap(a0)
		move.b #Map_SMZ_Floor_height,height_pixels(a0)	; or scrap brain

loc_8D9C:
		move.b	#sprite_bound($44,Map_Obj1B_width),width_pixels(a0)
		move.b	#32,obWidth(a0)
		move.b	#8,obHeight(a0)
		move.w	#$200,obPriority(a0)
		move.l	#Floor_BreakSlab,floor_break(a0)
		bra.w	Floor_Wait

Floor_InitColumns:
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
		move.w	d0,floor_columns(a0)
		lsl.w	#3,d0
		move.b	d0,obWidth(a0)
		move.b	d0,width_pixels(a0)
		move.b	#Map_MMZ_Floor_height,height_pixels(a0)
		move.b	#16,obHeight(a0)
		move.l	#Map_MMZ_Floor,obMap(a0)
		move.w	#ArtTile_MMZ_Atlas,obGfx(a0)
		move.w	#$180,obPriority(a0)
		move.l	#Floor_BreakColumn,floor_break(a0)
		btst	#7,d1
		beq.w	Floor_Draw
		move.w	#$80,obPriority(a0)
		move.l	#Floor_Static,code(a0)
		bra.w	Floor_Draw

Floor_Wait:
		bsr.w	Floor_TopSupport
		move.b	obStatus(a0),d0
		andi.b	#$18,d0
		beq.s	Floor_Draw
		move.l	#Floor_Delay,code(a0)
		move.w	#7,floor_timer(a0)
		tst.w	floor_columns(a0)
		beq.s	Floor_Draw
		addq.w	#1,floor_timer(a0)
		moveq	#8,d0
		lea	(v_player).w,a1
		btst	#3,obStatus(a0)
		bne.s	.direction
		lea	(v_player2).w,a1
.direction:
		tst.w	obVelX(a1)
		bpl.s	.save
		neg.w	d0
.save:
		move.w	d0,floor_step(a0)
		move.w	#SndID_Smash,d0
		jsr	(PlaySound_Special).l
Floor_Draw:
		out_of_range.s	.check_spawn,floor_origin(a0)
.visible:
		jmp	(DisplaySprite).l
.check_spawn:
		jsr	(Object_CheckSpawnXRange).l
		bls.s	.visible
		jsr	(SMZ_ReleaseRiders).l
		jmp	(UnloadObject).l

Floor_Delay:
		bsr.w	Floor_TopSupport
		subq.w	#1,floor_timer(a0)
		bpl.s	Floor_Draw
		move.l	floor_break(a0),code(a0)
		bra.s	Floor_Draw

Floor_Static:
		moveq	#0,d1
		move.b	obWidth(a0),d1
		addi.w	#sonic_solid_width,d1
		moveq	#16,d2
		moveq	#17,d3
		move.w	obX(a0),d4
		jsr	(SolidObject).l
		bra.s	Floor_Draw

Floor_TopSupport:
		moveq	#0,d1
		move.b	obWidth(a0),d1
		moveq	#0,d3
		move.b	obHeight(a0),d3
		move.w	obX(a0),d4
		jmp	(PlatformObject).l

Floor_BreakSlab:
		move.l	#FloorPiece_Run,code(a0)
		st	floor_piece_support(a0)
		lea	(FloorPieceDelaysForward).l,a4
		move.w	obSubtype(a0),d0
		btst	#0,d0
		beq.s	loc_8E52
		lea	(FloorPieceDelaysReverse).l,a4

loc_8E52:
		addq.b	#1,obFrame(a0)
		jmp	(CollapseToPieces).l

Floor_BreakColumn:
		move.w	floor_columns(a0),d3
		subq.w	#1,d3
		lsl.w	#3,d3
		tst.w	floor_step(a0)
		bmi.s	.edge
		neg.w	d3
.edge:
		add.w	obX(a0),d3
		move.w	obY(a0),d2
		subq.w	#8,d2
		move.l	#FloorPiece_Run,d4
		moveq	#$24,d5			; foreground position, single sprite piece
		moveq	#6,d6			; upper piece waits four updates longer
		lea	(Map_MMZ_Floor).l,a2
		movea.l	a2,a3
		adda.w	8*2(a2),a3
		addq.w	#2,a3			; skip frame's piece count
		bsr.s	.piece
		bne.s	.shrink
		addi.w	#16,d2
		movea.l	a2,a3
		adda.w	9*2(a2),a3
		addq.w	#2,a3
		moveq	#2,d6
		bsr.s	.piece
.shrink:
		subq.w	#1,floor_columns(a0)
		beq.s	.finished
		subq.b	#1,obFrame(a0)
		subq.b	#8,obWidth(a0)
		subq.b	#8,width_pixels(a0)
		move.w	floor_step(a0),d0
		add.w	d0,obX(a0)
		move.w	#7,floor_timer(a0)
		move.l	#Floor_Delay,code(a0)
		; The center changed but the remaining surface is stationary.
		bsr.w	Floor_TopSupport
		bra.w	Floor_Draw
.finished:
		jsr	(SMZ_ReleaseRiders).l
		jmp	(DeleteObject).l
.piece:
		jsr	(FindFreeObj).l
		bne.s	.return
		jsr	(CollapsePiece_Init).l
		move.b	#8,width_pixels(a1)
		move.b	#8,height_pixels(a1)
		move.w	d3,obX(a1)
		move.w	d2,obY(a1)
		move.b	d6,floor_piece_delay(a1)
		moveq	#0,d0
.return:
		rts

FloorPiece_Run:
		tst.b	floor_piece_delay(a0)
		beq.s	.fall
		subq.b	#1,floor_piece_delay(a0)
		tst.b	floor_piece_support(a0)
		beq.s	.draw
		bsr.w	Floor_TopSupport
		tst.b	floor_piece_delay(a0)
		bne.s	.draw
		jsr	(SMZ_ReleaseRiders).l
.draw:
		jmp	(DisplaySprite).l
.fall:
		jsr	(ObjectMoveAndFall).l
		tst.b	obRender(a0)
		jpl	(UnloadObject).l
		jmp	(DisplaySprite).l

Map_MMZ_Floor:	binclude "mappings/sprite/MMZ Floor.bin"
		even
