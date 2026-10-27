; ---------------------------------------------------------------------------
; DA - reusable lowering/raising chain (MD main CPU).
; LBZ lowering grapple / FBZ chain movement, with D9's shared hanging service.
; Subtype: --NS LLLL RDDD DDDD
; D = travel * 8px; R = start lowered and rise while held;
; L = resting 16px links; S = silent; N = disable foot-support release.
; Placement X/Y flips are unused. Origin is the fixed ceiling anchor.
; One parent draws the clipped chain; one D9 child owns both players' state.
; ---------------------------------------------------------------------------
Pull_hanger:		equ objoff_2E	; word: owned D9 child, no placement handle
Pull_anchorY:		equ objoff_30	; word: authored ceiling anchor, independent of display Y
Pull_limit:		equ objoff_32	; word: maximum extension
Pull_extension:		equ objoff_34	; word: current extension
Pull_rest:		equ objoff_36	; word: resting chain length in pixels

PullChain:
		tst.b	obRoutine(a0)
		bne.s	.ready
		move.b	#2,obRoutine(a0)
		move.w	obY(a0),Pull_anchorY(a0)
		move.l	#Map_PullChain,obMap(a0)
		move.w	#make_art_tile(ArtTile_HangingSurface,0,0),obGfx(a0)
		move.w	#$80,obPriority(a0)
		move.b	#Map_PullChain_height,height_pixels(a0)
		move.b	#Map_PullChain_width,width_pixels(a0)
		move.b	#4,obRender(a0)
		move.w	obSubtype(a0),d0
		move.w	d0,d1
		andi.w	#$7F,d0
		lsl.w	#3,d0
		move.w	d0,Pull_limit(a0)
		btst	#7,d1
		beq.s	.rest
		move.w	d0,Pull_extension(a0)
.rest:
		lsr.w	#4,d1
		andi.w	#$F0,d1
		move.w	d1,Pull_rest(a0)
.ready:
		move.w	obX(a0),d0
		andi.w	#$FF80,d0
		sub.w	(Camera_X_pos_coarse_back).w,d0
		cmpi.w	#$280,d0
		bhi.w	PullChain_Unload
		move.w	Pull_hanger(a0),d0
		beq.s	.spawn
		movea.w	d0,a1
		cmpi.l	#Hanging_Child,code(a1)
		bne.s	.spawn
		move.w	a0,d0
		cmp.w	Hang_parent(a1),d0
		beq.s	.move
.spawn:
		clr.w	Pull_hanger(a0)
		move.w	obSubtype(a0),d0
		lsr.w	#5,d0
		andi.w	#$100,d0		; N -> D9's no-support setting
		move.w	obSubtype(a0),d1
		lsr.w	#3,d1
		andi.w	#$200,d1		; S -> D9's silent setting
		or.w	d1,d0
		moveq	#16,d1		; same 32px catch width as the original chains
		move.w	Pull_anchorY(a0),d2
		add.w	Pull_rest(a0),d2
		add.w	Pull_extension(a0),d2
		addi.w	#24,d2		; D9 origin: hands at the bottom of the 40px grip
		sub.w	obY(a0),d2
		lea	Pull_hanger(a0),a2
		jsr	(Hanging_SpawnChild).l
		bcs.s	.display		; display remains live; retry interaction when a slot frees
		move.b	#1,Hang_snapX(a1)
.move:
		moveq	#0,d1
		move.b	Hang_p1+Hang_active(a1),d1
		or.b	Hang_p2+Hang_active(a1),d1
		move.w	obSubtype(a0),d0
		btst	#7,d0
		beq.s	.target
		eori.b	#1,d1
.target:
		move.w	Pull_extension(a0),d0
		tst.b	d1
		beq.s	.retract
		cmp.w	Pull_limit(a0),d0
		beq.s	.position
		addq.w	#2,d0
		bra.s	.position
.retract:
		tst.w	d0
		beq.s	.position
		subq.w	#2,d0
.position:
		move.w	d0,Pull_extension(a0)
		add.w	Pull_rest(a0),d0
		add.w	Pull_anchorY(a0),d0
		addi.w	#24,d0
		move.w	d0,obY(a1)
		move.w	obX(a0),obX(a1)
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Hanging_Update).l
		movea.l	(sp)+,a0
.display:

; The main SST's obY is only the visible mapping centre. Physical movement and
; child placement always use Pull_anchorY, so clipping cannot move the grip.
PullChain_Draw:
		move.w	Pull_rest(a0),d2
		add.w	Pull_extension(a0),d2
		move.w	d2,d4
		add.w	Pull_anchorY(a0),d4	; grip top
		addi.w	#15,d2
		lsr.w	#4,d2		; total complete link sprites (top can enter the ceiling)
		move.w	d4,d1
		sub.w	(Camera_Y_pos).w,d1
		addi.w	#39,d1
		cmpi.w	#263,d1
		bhs.s	.chain_only
		subi.w	#24,d1		; visible links above the grip: floor((relative Y+15)/16)
		bpl.s	.grip_count
		moveq	#0,d1
.grip_count:
		lsr.w	#4,d1
		cmp.w	d1,d2
		bls.s	.grip
		move.w	d1,d2
.grip:
		move.b	d2,obFrame(a0)	; frames 0..14 include the handhold
		move.w	d2,d0
		lsl.w	#4,d0
		sub.w	d0,d4
		lsl.w	#3,d2
		addi.w	#20,d2
		cmpi.w	#128,d2
		bls.s	.centre
		move.w	#128,d2
		bra.s	.centre
.chain_only:
		tst.w	d2
		beq.s	.return
		move.w	d2,d0
		lsl.w	#4,d0
		sub.w	d0,d4		; topmost complete link
		move.w	(Camera_Y_pos).w,d0
		subi.w	#15,d0
		sub.w	d4,d0
		bpl.s	.first
		moveq	#0,d0
.first:
		addi.w	#15,d0
		lsr.w	#4,d0
		sub.w	d0,d2
		ble.s	.return
		lsl.w	#4,d0
		add.w	d0,d4
		move.w	(Camera_Y_pos).w,d0
		addi.w	#223,d0
		sub.w	d4,d0
		bmi.s	.return
		lsr.w	#4,d0
		addq.w	#1,d0
		cmp.w	d0,d2
		bls.s	.links
		move.w	d0,d2
.links:
		move.w	d2,d0
		addi.w	#14,d0
		move.b	d0,obFrame(a0)	; frames 15..29 contain only the visible links
		lsl.w	#3,d2
.centre:
		add.w	d2,d4
		move.w	d4,obY(a0)
		jmp	(DisplaySprite).l
.return:
		rts

PullChain_Unload:
		move.w	Pull_hanger(a0),d0
		beq.s	.delete
		clr.w	Pull_hanger(a0)
		movea.w	d0,a1
		cmpi.l	#Hanging_Child,code(a1)
		bne.s	.delete
		move.w	a0,d0
		cmp.w	Hang_parent(a1),d0
		bne.s	.delete
		move.l	a0,-(sp)
		movea.l	a1,a0
		jsr	(Hanging_DeleteChild).l
		movea.l	(sp)+,a0
.delete:
		jmp	(UnloadObject).l

Map_PullChain:
		binclude "mappings/sprite/Pull chain.bin"
