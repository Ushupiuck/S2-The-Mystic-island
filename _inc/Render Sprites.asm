; ---------------------------------------------------------------------------
; S3&K Render_Sprites and mapping loops, adapted to Mystic Island's SST/queue.
; d7: remaining SAT entries minus one; a6: SAT output; a3: camera copy.
; a5: priority queue; a4: next object; a2: end of this priority's objects.
; d0/d1: sprite origin; d4: pieces minus one; d5: art tile; d6: render flags.
; HUD and rings fall through here; ordinary mappings return by branch.
; Composite mapping groups also rejoin by branch; no per-object BSR/RTS.
; ---------------------------------------------------------------------------

; Links are fixed between table clears. Each frame only repairs the previous
; terminator, then places a new terminator. The S1 layout pass may append to it.
Init_SpriteTable:
		lea	(Sprite_Table).w,a1
		moveq	#Sprite_Table_Max-1,d0
		moveq	#1,d1
.loop:
		clr.w	(a1)
		move.b	d1,3(a1)
		addq.b	#1,d1
		addq.w	#8,a1
		dbf	d0,.loop
		clr.b	-5(a1)
		clr.b	(v_spritecount).w
		rts

Render_Sprites:
		lea	(Sprite_Table).w,a6
		moveq	#0,d0
		move.b	(v_spritecount).w,d0
		cmpi.w	#Sprite_Table_Max-1,d0
		bhs.s	.links_ready		; the final entry must always retain link zero
		move.w	d0,d1
		lsl.w	#3,d0
		addq.b	#1,d1
		move.b	d1,3(a6,d0.w)	; restore the preceding frame's terminator link
.links_ready:
		moveq	#Sprite_Table_Max-1,d7
		moveq	#0,d6
		lea	(Camera_X_pos_copy).w,a3
		tst.b	(Level_started_flag).w
		beq.w	Render_Sprites_Queues

		; Inlined HUD setup and unflipped S3&K mapping loop.
		moveq	#0,d0
		tst.b	(Debug_mode_flag).w
		beq.s	.hud_blink
		moveq	#2,d0
.hud_blink:
		btst	#3,(Timer_frames+1).w
		bne.s	.hud_frame
		cmpi.b	#9,(v_timemin).w
		bne.s	.hud_frame
		addq.w	#1,d0
.hud_frame:
		lea	Map_obj21(pc),a1
		add.w	d0,d0
		adda.w	(a1,d0.w),a1
		move.w	(a1)+,d4
		subq.w	#1,d4
		bmi.s	.rings
		move.w	#128+16,d0
		move.w	#128+136,d1
		move.w	#make_art_tile(ArtTile_HUD,0,0),d5
.hud_piece:
		move.b	(a1)+,d2
		ext.w	d2
		add.w	d1,d2
		move.w	d2,(a6)+
		move.b	(a1)+,(a6)+
		addq.w	#1,a6		; retain the preinitialized link
		move.w	(a1)+,d2
		add.w	d5,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		add.w	d0,d2
		andi.w	#$1FF,d2
		bne.s	.hud_x
		addq.w	#1,d2		; X=0 activates VDP sprite masking
.hud_x:
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,.hud_piece

.rings:
		tst.w	d7
		bmi.w	Render_Sprites_Queues
		movea.w	(Ring_start_addr).w,a0
		movea.w	(Ring_end_addr).w,a4
		cmpa.l	a0,a4
		beq.w	Render_Sprites_Queues
		lea	MapUnc_Rings(pc),a2
.ring:
		tst.w	(a0)
		bmi.s	.next_ring
		move.w	4(a0),d1
		sub.w	Camera_Y_pos-Camera_RAM(a3),d1
		addq.w	#8,d1
		andi.w	#$7FF,d1
		cmpi.w	#224+16,d1
		bhs.s	.next_ring
		addi.w	#128-8,d1
		moveq	#0,d4
		move.b	1(a0),d4
		cmpi.b	#5,d4
		bhs.s	.next_ring
		lsl.w	#3,d4		; custom ring records are eight bytes, as in S3&K
		lea	(a2,d4.w),a1
		add.w	(a1)+,d1
		move.w	d1,(a6)+
		move.w	(a1)+,d2
		move.b	d2,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,(a6)+
		move.w	2(a0),d0
		sub.w	(a3),d0
		addi.w	#128,d0
		add.w	(a1)+,d0
		andi.w	#$1FF,d0
		bne.s	.ring_x
		addq.w	#1,d0
.ring_x:
		move.w	d0,(a6)+
		subq.w	#1,d7
		bmi.s	Render_Sprites_Queues
.next_ring:
		addq.w	#6,a0
		cmpa.l	a0,a4
		bne.s	.ring

Render_Sprites_Queues:
		lea	(v_spritequeue).w,a5
Render_Sprites_NextLevel:
		move.w	(a5),d3
		beq.w	Render_Sprites_AdvanceLevel
		clr.w	(a5)		; consume the queue once instead of writing it per object
		lea	2(a5),a4
		lea	(a4,d3.w),a2
Render_Sprites_NextEntry:
		movea.w	(a4)+,a0
		; A queued object can be deleted later in the update.
		tst.l	code(a0)
		beq.w	Render_Sprites_NextObj
		move.b	obRender(a0),d6
		andi.w	#$7F,d6
		move.b	d6,obRender(a0)
		move.w	obX(a0),d0
		btst	#obRender.multi_sprite,d6
		bne.w	Render_Sprites_Composite
		btst	#obRender.level_fg,d6
		beq.s	Render_Sprites_CheckBG
Render_Sprites_World:
		moveq	#0,d2
		move.b	width_pixels(a0),d2
		sub.w	(a3),d0
		move.w	d0,d3
		add.w	d2,d3
		bmi.s	Render_Sprites_NextObj
		move.w	d0,d3
		sub.w	d2,d3
		cmpi.w	#320,d3
		bge.s	Render_Sprites_NextObj
		addi.w	#128,d0
		move.w	obY(a0),d1
		sub.w	Camera_Y_pos-Camera_RAM(a3),d1
		move.b	height_pixels(a0),d2
		add.w	d2,d1
		andi.w	#$7FF,d1
		move.w	d2,d3
		add.w	d2,d2
		addi.w	#224,d2
		cmp.w	d2,d1
		bhs.s	Render_Sprites_NextObj
		addi.w	#128,d1
		sub.w	d3,d1
		bra.s	Render_Sprites_Visible
Render_Sprites_CheckBG:
		btst	#obRender.level_bg,d6	; retain legacy background-relative objects
		bne.s	Render_Sprites_World
		move.w	obScreenY(a0),d1	; screen-space Y is at $12; world Y is at $14
Render_Sprites_Visible:
		ori.b	#$80,obRender(a0)
		tst.w	d7
		bmi.s	Render_Sprites_NextObj
		movea.l	obMap(a0),a1
		moveq	#0,d4
		btst	#obRender.static_mappings,d6
		bne.s	.draw
		move.b	obFrame(a0),d4
		add.w	d4,d4
		adda.w	(a1,d4.w),a1
		move.w	(a1)+,d4
		subq.w	#1,d4
		bmi.s	Render_Sprites_NextObj
.draw:
		move.w	obGfx(a0),d5
		bra.w	Render_Mappings	; inline continuation: no BSR/RTS per ordinary object

Render_Sprites_NextObj:
		cmpa.l	a2,a4
		bne.w	Render_Sprites_NextEntry
Render_Sprites_AdvanceLevel:
		lea	$80(a5),a5
		cmpa.w	#v_spritequeue_end,a5
		blo.w	Render_Sprites_NextLevel
		moveq	#Sprite_Table_Max-1,d0
		sub.w	d7,d0
		move.b	d0,(v_spritecount).w
		tst.w	d7
		bmi.s	.return
		clr.l	(a6)		; one hidden terminator, rather than clearing every unused Y
.return:
		rts

; ---------------------------------------------------------------------------
; Generic composite. Children occupy $18-$47; display fields use the shared
; header, with the child count in the unused Y fractional byte.
; a2 remains the queue end; a4 temporarily holds the shared mapping base.
; d3 holds child count in its low word and saved render flags in its high word.
; ---------------------------------------------------------------------------
Render_Sprites_Composite:
		move.w	obY(a0),d1
		moveq	#0,d2
		move.b	mainspr_width(a0),d2
		btst	#obRender.level_fg,d6
		beq.w	.check_bg
.world:
		sub.w	(a3),d0
		move.w	d0,d3
		add.w	d2,d3
		bmi.w	Render_Sprites_NextObj
		move.w	d0,d3
		sub.w	d2,d3
		cmpi.w	#320,d3
		bge.w	Render_Sprites_NextObj
		addi.w	#128,d0
		sub.w	Camera_Y_pos-Camera_RAM(a3),d1
		move.b	height_pixels(a0),d2
		add.w	d2,d1
		andi.w	#$7FF,d1
		move.w	d2,d3
		add.w	d2,d2
		addi.w	#224,d2
		cmp.w	d2,d1
		bhs.w	Render_Sprites_NextObj
		addi.w	#128,d1
		sub.w	d3,d1
		ori.b	#$80,obRender(a0)
		tst.w	d7
		bmi.w	Render_Sprites_NextObj
		move.l	a4,-(sp)
		movea.l	obMap(a0),a4
		move.w	obGfx(a0),d5
		moveq	#0,d3
		move.b	mainspr_childsprites(a0),d3
		swap	d3
		move.w	d6,d3
		swap	d3
		moveq	#0,d4
		move.b	mainspr_mapframe(a0),d4
		lea	subspr_data(a0),a0	; the same continuation handles main and child groups
		beq.w	.children
		add.w	d4,d4
		movea.l	a4,a1
		adda.w	(a1,d4.w),a1
		move.w	(a1)+,d4
		subq.w	#1,d4
		bmi.w	.children
		bra.w	Render_CompositeMappings	; main group rejoins .next_piece directly
.check_bg:
		btst	#obRender.level_bg,d6
		beq.s	.screen
		bset	#obRender.level_fg,d6	; normalize legacy BG-relative children once
		bra.w	.world
.screen:
		move.w	d0,d3
		subi.w	#128,d3
		add.w	d2,d3
		bmi.w	Render_Sprites_NextObj
		sub.w	d2,d3
		sub.w	d2,d3
		cmpi.w	#320,d3
		bge.w	Render_Sprites_NextObj
		moveq	#0,d2
		move.b	height_pixels(a0),d2
		move.w	d1,d3
		subi.w	#128,d3
		add.w	d2,d3
		bmi.w	Render_Sprites_NextObj
		sub.w	d2,d3
		sub.w	d2,d3
		cmpi.w	#224,d3
		bge.w	Render_Sprites_NextObj
		ori.b	#$80,obRender(a0)
		tst.w	d7
		bmi.w	Render_Sprites_NextObj
		move.l	a4,-(sp)
		movea.l	obMap(a0),a4
		move.w	obGfx(a0),d5
		moveq	#0,d3
		move.b	mainspr_childsprites(a0),d3
		swap	d3
		move.w	d6,d3
		swap	d3
		moveq	#0,d4
		move.b	mainspr_mapframe(a0),d4
		lea	subspr_data(a0),a0	; the same continuation handles main and child groups
		beq.s	.children
		add.w	d4,d4
		movea.l	a4,a1
		adda.w	(a1,d4.w),a1
		move.w	(a1)+,d4
		subq.w	#1,d4
		bmi.s	.children
		bra.w	Render_CompositeMappings	; main group rejoins .next_piece directly
.children:
		subq.w	#1,d3
		bcs.s	.done
.child:
		move.w	(a0)+,d0
		move.w	(a0)+,d1
		btst	#obRender.level_fg,d6
		beq.s	.child_screen
		sub.w	(a3),d0
		addi.w	#128,d0
		sub.w	Camera_Y_pos-Camera_RAM(a3),d1
		addi.w	#128,d1
		andi.w	#$7FF,d1
.child_screen:
		addq.w	#1,a0
		moveq	#0,d4
		move.b	(a0)+,d4
		add.w	d4,d4
		movea.l	a4,a1
		adda.w	(a1,d4.w),a1
		move.w	(a1)+,d4
		subq.w	#1,d4
		bmi.s	.next_piece
		bra.w	Render_CompositeMappings	; child groups use the same branch continuation
.next_piece:
		swap	d3
		move.w	d3,d6
		swap	d3
		tst.w	d7
		dbmi	d3,.child
.done:
		movea.l	(sp)+,a4
		bra.w	Render_Sprites_NextObj


Render_Mappings:
		lsr.b	#1,d6
		bcs.s	Render_Mappings_FlipX_Entry
		lsr.b	#1,d6
		bcs.w	Render_Mappings_FlipY

Render_Mappings_NoFlip:
		move.b	(a1)+,d2
		ext.w	d2
		add.w	d1,d2
		move.w	d2,(a6)+
		move.b	(a1)+,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		add.w	d0,d2
		andi.w	#$1FF,d2
		bne.s	Render_Mappings_NoFlip_XReady
		addq.w	#1,d2

Render_Mappings_NoFlip_XReady:
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Mappings_NoFlip
		bra.w	Render_Sprites_NextObj
; ---------------------------------------------------------------------------

Render_Mappings_FlipX_Entry:
		lsr.b	#1,d6
		bcs.s	Render_Mappings_FlipXY

Render_Mappings_FlipX:
		move.b	(a1)+,d2
		ext.w	d2
		add.w	d1,d2
		move.w	d2,(a6)+
		move.b	(a1)+,d6
		move.b	d6,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		eori.w	#$800,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		neg.w	d2
		move.b	Render_Mappings_XSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d0,d2
		andi.w	#$1FF,d2
		bne.s	Render_Mappings_FlipX_XReady
		addq.w	#1,d2

Render_Mappings_FlipX_XReady:
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Mappings_FlipX
		bra.w	Render_Sprites_NextObj
; ---------------------------------------------------------------------------
Render_Mappings_XSize:
		dc.b    8,   8,   8,   8
		dc.b  $10, $10, $10, $10
		dc.b  $18, $18, $18, $18
		dc.b  $20, $20, $20, $20
		even
; ---------------------------------------------------------------------------

Render_Mappings_FlipXY:
		move.b	(a1)+,d2
		ext.w	d2
		neg.w	d2
		move.b	(a1),d6
		move.b	Render_Mappings_YSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d1,d2
		move.w	d2,(a6)+
		move.b	(a1)+,d6
		move.b	d6,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		eori.w	#$1800,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		neg.w	d2
		move.b	Render_Mappings_XSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d0,d2
		andi.w	#$1FF,d2
		bne.s	Render_Mappings_FlipXY_XReady
		addq.w	#1,d2

Render_Mappings_FlipXY_XReady:
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Mappings_FlipXY
		bra.w	Render_Sprites_NextObj
; ---------------------------------------------------------------------------
Render_Mappings_YSize:
		dc.b    8, $10, $18, $20
		dc.b    8, $10, $18, $20
		dc.b    8, $10, $18, $20
		dc.b    8, $10, $18, $20
		even
; ---------------------------------------------------------------------------

Render_Mappings_FlipY:
		move.b	(a1)+,d2
		ext.w	d2
		neg.w	d2
		move.b	(a1)+,d6
		move.b	d6,2(a6)
		move.b	Render_Mappings_YSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d1,d2
		move.w	d2,(a6)+
		addq.w	#2,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		eori.w	#$1000,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		add.w	d0,d2
		andi.w	#$1FF,d2
		bne.s	Render_Mappings_FlipY_XReady
		addq.w	#1,d2

Render_Mappings_FlipY_XReady:
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Mappings_FlipY
		bra.w	Render_Sprites_NextObj
; End of function Render_Mappings


; =============== S U B R O U T I N E =======================================


Render_CompositeMappings:
		lsr.b	#1,d6
		bcs.s	Render_Composite_FlipX_Entry
		lsr.b	#1,d6
		bcs.w	Render_Composite_FlipY

Render_Composite_NoFlip:
		move.b	(a1)+,d2
		ext.w	d2
		add.w	d1,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_NoFlip_SkipY
		cmpi.w	#224+128,d2
		bhs.s	Render_Composite_NoFlip_SkipY
		move.w	d2,(a6)+
		move.b	(a1)+,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		add.w	d0,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_NoFlip_SkipX
		cmpi.w	#320+128,d2
		bhs.s	Render_Composite_NoFlip_SkipX
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Composite_NoFlip
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_NoFlip_SkipX:
		subq.w	#6,a6
		dbf	d4,Render_Composite_NoFlip
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_NoFlip_SkipY:
		addq.w	#5,a1
		dbf	d4,Render_Composite_NoFlip
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipX_Entry:
		lsr.b	#1,d6
		bcs.s	Render_Composite_FlipXY

Render_Composite_FlipX:
		move.b	(a1)+,d2
		ext.w	d2
		add.w	d1,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_FlipX_SkipY
		cmpi.w	#224+128,d2
		bhs.s	Render_Composite_FlipX_SkipY
		move.w	d2,(a6)+
		move.b	(a1)+,d6
		move.b	d6,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		eori.w	#$800,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		neg.w	d2
		move.b	Render_Composite_XSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d0,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_FlipX_SkipX
		cmpi.w	#320+128,d2
		bhs.s	Render_Composite_FlipX_SkipX
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Composite_FlipX
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipX_SkipX:
		subq.w	#6,a6
		dbf	d4,Render_Composite_FlipX
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipX_SkipY:
		addq.w	#5,a1
		dbf	d4,Render_Composite_FlipX
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_XSize:
		dc.b 8,8,8,8,$10,$10,$10,$10,$18,$18,$18,$18,$20,$20,$20,$20
		even

Render_Composite_FlipXY:
		move.b	(a1)+,d2
		ext.w	d2
		neg.w	d2
		move.b	(a1),d6
		move.b	Render_Composite_YSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d1,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_FlipXY_SkipY
		cmpi.w	#224+128,d2
		bhs.s	Render_Composite_FlipXY_SkipY
		move.w	d2,(a6)+
		move.b	(a1)+,d6
		move.b	d6,(a6)+
		addq.w	#1,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		eori.w	#$1800,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		neg.w	d2
		move.b	Render_Composite_XSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d0,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_FlipXY_SkipX
		cmpi.w	#320+128,d2
		bhs.s	Render_Composite_FlipXY_SkipX
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Composite_FlipXY
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipXY_SkipX:
		subq.w	#6,a6
		dbf	d4,Render_Composite_FlipXY
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipXY_SkipY:
		addq.w	#5,a1
		dbf	d4,Render_Composite_FlipXY
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_YSize:
		dc.b 8,$10,$18,$20,8,$10,$18,$20,8,$10,$18,$20,8,$10,$18,$20
		even

Render_Composite_FlipY:
		move.b	(a1)+,d2
		ext.w	d2
		neg.w	d2
		move.b	(a1)+,d6
		move.b	d6,2(a6)
		move.b	Render_Composite_YSize(pc,d6.w),d6
		sub.w	d6,d2
		add.w	d1,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_FlipY_SkipY
		cmpi.w	#224+128,d2
		bhs.s	Render_Composite_FlipY_SkipY
		move.w	d2,(a6)+
		addq.w	#2,a6
		move.w	(a1)+,d2
		add.w	d5,d2
		eori.w	#$1000,d2
		move.w	d2,(a6)+
		move.w	(a1)+,d2
		add.w	d0,d2
		cmpi.w	#-32+128,d2
		bls.s	Render_Composite_FlipY_SkipX
		cmpi.w	#320+128,d2
		bhs.s	Render_Composite_FlipY_SkipX
		move.w	d2,(a6)+
		subq.w	#1,d7
		dbmi	d4,Render_Composite_FlipY
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipY_SkipX:
		subq.w	#6,a6
		dbf	d4,Render_Composite_FlipY
		bra.w	Render_Sprites_Composite.next_piece
; ---------------------------------------------------------------------------

Render_Composite_FlipY_SkipY:
		addq.w	#4,a1
		dbf	d4,Render_Composite_FlipY
		bra.w	Render_Sprites_Composite.next_piece