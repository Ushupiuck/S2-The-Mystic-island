; ---------------------------------------------------------------------------
; Object FF - points that appear when you destroy something
; Two tiles per player; repeat the zero tile for the larger awards.
; ---------------------------------------------------------------------------
points_parent = obParent2		; survives enemy -> explosion -> animal -> points
; The reserved shield SSTs have unused bytes beside their effect-bank cache.
; Cache the points banks here too; no SST or global RAM allocation grows.
points_loaded_frame = objoff_31	; byte, zero = empty, DPLC indices 1-7 = loaded
points_last_object = objoff_32	; word, latest popup for this player
Points_FrameBias = 1
Points_HiddenFrame = 7

Points:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Points_Index(pc,d0.w),d1
		jmp	Points_Index(pc,d1.w)
; ---------------------------------------------------------------------------
Points_Index:	dc.w Points_main-Points_Index
		dc.w Points_Deccelerate-Points_Index
; ---------------------------------------------------------------------------

Points_main:
		move.w	#make_art_tile(ArtTile_Points,0,0),obGfx(a0)
		move.w	#ArtTile_Points*tile_size,d4
		lea	(v_shieldobj+points_loaded_frame).w,a3
		cmpi.w	#v_player2,points_parent(a0)
		bne.s	.primary
		move.w	#make_art_tile(ArtTile_Points_2,0,0),obGfx(a0)
		move.w	#ArtTile_Points_2*tile_size,d4
		lea	(v_shieldobj2+points_loaded_frame).w,a3
		bra.s	.load
.primary:
		move.w	#v_player,points_parent(a0)	; unowned/debug animals use player 1
.load:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		addq.w	#Points_FrameBias,d0		; keep zero as the empty-bank cache
		lea	(DPLC_Points).l,a2
		move.l	#Art_Points,d6
		bsr.w	Load_DynamicPLC
		bcs.s	Points_Return			; retry before moving or replacing the old popup
		; A bank holds one value. Retire only this player's previous popup,
		; including one queued earlier this frame. An empty mapping hides it
		; until its next update deletes it, so queued SSTs cannot be reused early.
		move.w	points_last_object-points_loaded_frame(a3),d0
		move.w	a0,points_last_object-points_loaded_frame(a3)
		tst.w	d0
		beq.s	.setup
		cmp.w	a0,d0
		beq.s	.setup				; the old SST may have been reused for this popup
		movea.w	d0,a1
		cmpi.b	#id_ObjFF,obID(a1)
		bne.s	.setup
		cmpi.b	#2,obRoutine(a1)
		bne.s	.setup				; do not delete a newly allocated, pending popup
		move.w	points_parent(a0),d0
		cmp.w	points_parent(a1),d0
		bne.s	.setup				; a reused SST may belong to the other player
		clr.w	obVelY(a1)
		move.b	#Points_HiddenFrame,obFrame(a1)
.setup:
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Points,obMap(a0)
		move.b	#Map_Points_height,height_pixels(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#sprite_bound(8,Map_Points_width),obActWid(a0)
		move.w	#-$300,obVelY(a0)			; move object upwards

Points_Deccelerate:
		tst.w	obVelY(a0)				; is object moving?
		bpl.w	DeleteObject				; if not, delete
		bsr.w	ObjectMove				; update position
		addi.w	#$18,obVelY(a0)				; reduce object speed
		bra.w	DisplaySprite
Points_Return:
		rts