; ---------------------------------------------------------------------------
; Object 35 - all four S2 invincibility-star layers in one shared SST
; Keep the normal object fields intact. Persistent local state is $30-$39;
; the eight child sprites exist only in a temporary render-time stack buffer.
; ---------------------------------------------------------------------------
; SST Variables:

invincibility_angles	= objoff_30	; four bytes: the current frame's orbit angles
invincibility_frames	= objoff_34	; four bytes: the current frame's animation indices
invincibility_parent	= objoff_38	; word: the player followed by this shared effect
invincibility_draw_size	= subspr_data+8*next_subspr	; temporary composite header and eight children
		if (invincibility_angles<objoff_30)||(invincibility_frames<>invincibility_angles+4)||(invincibility_parent<>invincibility_frames+4)||(invincibility_parent+2>object_size)
			fatal "The shared stars need ten non-overlapping scratch bytes starting at objoff_30."
		endif
; ---------------------------------------------------------------------------

; Initialise the shared effect on its first update, then choose its parent.
Obj35:
		moveq	#0,d2
		tst.b	obRoutine(a0)
		bne.s	InvincibilityStars_Update
		move.b	#2,obRoutine(a0)
		move.l	#Map_InvincibilityStars,obMap(a0)
		move.w	#make_art_tile(ArtTile_Invincibility,0,0),obGfx(a0)
		move.b	#$44,obRender(a0)		; world coordinates, multiple stars
		move.w	#$80,obPriority(a0)
		move.b	#$18,obActWid(a0)
		clr.b	obFrame(a0)
		move.l	#$0400162C,invincibility_angles(a0)
		clr.l	invincibility_frames(a0)
		moveq	#1,d2				; draw the initial phase before advancing it

; ===========================================================================
; Routine 2 - follow a live invincible player and queue the shared effect.
; Prefer the main player; switch to the partner if only they are invincible.
; ---------------------------------------------------------------------------
InvincibilityStars_Update:
		tst.b	(Super_Sonic_flag).w
		bne.w	DeleteObject
		lea	(v_player).w,a1			; prefer the main player when both are invincible
		bsr.w	InvincibilityStars_CheckParent
		bne.s	.parent_ready
		lea	(v_player2).w,a1
		bsr.w	InvincibilityStars_CheckParent
		beq.w	DeleteObject
.parent_ready:
		tst.w	d2
		bne.s	.position
		bsr.w	InvincibilityStars_Advance
.position:
		move.w	a1,invincibility_parent(a0)
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		move.b	obStatus(a1),obStatus(a0)
		andi.b	#1,obStatus(a0)			; remember this frame's orbit direction
		jmp	(DisplaySprite).l

; ===========================================================================
; Advance once per object update, including frames that are not rendered.
; The saved orientation belongs to the preceding frame, matching S2's
; draw-then-advance orbit timing when the parent turns or changes.
; ---------------------------------------------------------------------------
InvincibilityStars_Advance:
		lea	invincibility_angles(a0),a2
		lea	invincibility_frames(a0),a3
		lea	InvincibilityStars_Layers(pc),a4
		moveq	#3,d1
		moveq	#9*2,d2
.layer:
		btst	#status.player.x_flip,obStatus(a0)
		beq.s	.direction
		neg.w	d2
.direction:
		add.b	d2,(a2)+
		addq.b	#1,(a3)
		move.b	(a3),d0
		cmp.b	3(a4),d0
		blo.s	.frame_ready
		clr.b	(a3)
.frame_ready:
		addq.w	#1,a3
		addq.w	#4,a4
		moveq	#2,d2
		dbf	d1,.layer
		rts

; ===========================================================================
; BuildSprites calls this directly for Obj35. The generic composite layout
; is confined to this stack buffer, never overlaid on the persistent SST.
; Keep the queue/priority registers intact and return the advanced VDP
; pointer in a2 and sprite count in d5, as the normal renderer does.
; ---------------------------------------------------------------------------
InvincibilityStars_Draw:
		movem.l	d4/d6-d7/a1/a3-a6,-(sp)
		movea.w	invincibility_parent(a0),a1
		bsr.w	InvincibilityStars_CheckParent
		beq.w	.return
		move.l	a0,-(sp)			; owner, below the temporary buffer
		move.l	a2,-(sp)			; current VDP sprite-table pointer
		move.l	d5,-(sp)			; current VDP sprite count
		lea	-invincibility_draw_size(sp),sp
		move.l	obMap(a0),obMap(sp)
		move.w	obGfx(a0),obGfx(sp)
		lea	invincibility_angles(a0),a4
		movea.l	sp,a0
		move.b	#$54,obRender(a0)
		clr.b	mainspr_mapframe(a0)		; no main sprite
		move.b	#$FF,mainspr_width(a0)
		move.w	(Camera_RAM).w,obX(a0)		; children perform their own bounds checks
		move.w	(Camera_RAM+4).w,obY(a0)
		; Select this player's position history, including Tails as player 1.
		lea	(Sonic_Pos_Record_Buf).w,a5
		move.w	(Sonic_Pos_Record_Index).w,d4
		cmpa.w	#v_player,a1
		bne.s	.tails_history
		cmpi.w	#2,(Player_mode).w
		bne.s	.history_ready
.tails_history:
		lea	(Tails_Pos_Record_Buf).w,a5
		move.w	(Tails_Pos_Record_Index).w,d4
.history_ready:
		clr.b	mainspr_childsprites(a0)
		lea	subspr_data(a0),a2
		lea	InvincibilityStars_Layers(pc),a3
		moveq	#0,d7
.layer:
		; The first pair orbits the current position; the remaining pairs
		; orbit progressively older entries in the player's position history.
		move.w	obX(a1),d0
		move.w	obY(a1),d1
		tst.w	d7
		beq.s	.position_ready
		move.w	d4,d0
		move.w	d7,d1
		lsl.w	#2,d1
		move.w	d1,d2
		add.w	d1,d1
		add.w	d2,d1			; layer * 12 bytes: three recorded positions per layer
		sub.b	d1,d0				; wrap within the $100-byte position history
		lea	(a5,d0.w),a6
		move.w	(a6)+,d0
		move.w	(a6)+,d1
.position_ready:
		moveq	#0,d2
		move.b	invincibility_frames-invincibility_angles(a4),d2
		cmp.b	3(a3),d2
		blo.s	.frame_ready
		moveq	#0,d2
.frame_ready:
		move.w	(a3),d5
		lea	InvincibilityStars_Layers(pc),a6
		adda.w	d5,a6
		moveq	#0,d5
		move.b	(a6,d2.w),d5			; frame of the opposite star
		swap	d5
		add.b	2(a3),d2
		move.b	(a6,d2.w),d5			; frame of the first star
		lea	InvincibilityStars_Positions(pc),a6
		moveq	#0,d6
		move.b	(a4),d6
		bsr.w	InvincibilityStars_GetPosition
		bsr.w	InvincibilityStars_WriteChild
		addi.w	#16*2,d6			; opposite side of the orbit
		swap	d5
		bsr.w	InvincibilityStars_GetPosition
		bsr.w	InvincibilityStars_WriteChild
		addq.w	#1,a4
		addq.w	#4,a3
		addq.w	#1,d7
		cmpi.w	#4,d7
		blo.w	.layer
		; Render the packed children, then discard the temporary composite.
		move.b	#$FF,mainspr_height(a0)		; unused high byte of the first child's frame
		move.l	invincibility_draw_size(sp),d5
		movea.l	invincibility_draw_size+4(sp),a2
		tst.b	mainspr_childsprites(a0)
		beq.s	.no_children
		movea.l	invincibility_draw_size+8(sp),a6
		ori.b	#$80,obRender(a6)
		moveq	#$54,d4			; composite flags, independent of the history index
		bsr.w	BuildSprites_DrawComposite
.no_children:
		lea	invincibility_draw_size+8(sp),sp
		movea.l	(sp)+,a0
.return:
		movem.l	(sp)+,d4/d6-d7/a1/a3-a6
		rts

; ===========================================================================
; Z clear only for a living, present player with the invincibility bit set.
; Input: a1 = player SST. Output: d0 = 1 if valid, 0 otherwise.
; ---------------------------------------------------------------------------
InvincibilityStars_CheckParent:
		moveq	#0,d0
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a1)
		beq.s	.return
		tst.b	obID(a1)
		beq.s	.return
		cmpi.b	#6,obRoutine(a1)
		bhs.s	.return
		moveq	#1,d0
.return:
		tst.b	d0
		rts

; ===========================================================================
; Pack only nearby children. This prevents distant trail coordinates from
; wrapping onto the screen when the VDP truncates X positions to nine bits.
; Input: d2 = child X, d1 = orbit centre Y, d5 = mapping frame;
; a0 = temporary composite, a2 = next child, a6/d6 = orbit position.
; ---------------------------------------------------------------------------
InvincibilityStars_WriteChild:
		move.w	d2,d3				; preserve X while checking the horizontal bounds
		sub.w	(Camera_RAM).w,d3
		addi.w	#32,d3
		cmpi.w	#320+64,d3
		bhs.s	.return
		move.b	1(a6,d6.w),d3		; recover Y from the orbit and its center
		ext.w	d3
		add.w	d1,d3
		move.w	d3,-(sp)
		sub.w	(Camera_RAM+4).w,d3
		addi.w	#32,d3
		andi.w	#$7FF,d3
		cmpi.w	#224+64,d3
		bhs.s	.outside_y
		move.w	(sp)+,d3
		move.w	d2,(a2)+
		move.w	d3,(a2)+
		move.w	d5,(a2)+
		addq.b	#1,mainspr_childsprites(a0)
.return:
		rts
.outside_y:
		addq.w	#2,sp
		rts

; ===========================================================================
; Add a signed orbit offset to its centre. The angle wraps within 32 pairs.
; Input: d0/d1 = centre X/Y, d6 = angle, a6 = orbit-offset table.
; Output: d2/d3 = child X/Y.
; ---------------------------------------------------------------------------
InvincibilityStars_GetPosition:
		andi.w	#$3E,d6
		move.b	(a6,d6.w),d2
		move.b	1(a6,d6.w),d3
		ext.w	d2
		ext.w	d3
		add.w	d0,d2
		add.w	d1,d3
		rts

; ===========================================================================
; Layer records: frame-table offset (word), first-star sequence offset
; (byte), and animation frame count (byte).
; ---------------------------------------------------------------------------
InvincibilityStars_Layers:
		dc.w InvincibilityStars_Layer0Frames-InvincibilityStars_Layers
		dc.b 0,12
		dc.w InvincibilityStars_Layer1Frames-InvincibilityStars_Layers
		dc.b 10,10
		dc.w InvincibilityStars_Layer2Frames-InvincibilityStars_Layers
		dc.b 12,12
		dc.w InvincibilityStars_Layer3Frames-InvincibilityStars_Layers
		dc.b 12,12

; ---------------------------------------------------------------------------
; Signed X/Y offsets for the 32 positions around each star's orbit.
; ---------------------------------------------------------------------------
InvincibilityStars_Positions:
		dc.b 15,0,15,3,14,6,13,8,11,11,8,13,6,14,3,15
		dc.b 0,16,-4,15,-7,14,-9,13,-12,11,-14,8,-15,6,-16,3
		dc.b -16,0,-16,-4,-15,-7,-14,-9,-12,-12,-9,-14,-7,-15,-4,-16
		dc.b -1,-16,3,-16,6,-15,8,-14,11,-12,13,-9,14,-7,15,-4
; ---------------------------------------------------------------------------
; Animation frames for each pair of stars. Layer 0 shares one sequence;
; layers 1-3 store the opposite-star sequence before the first-star sequence.
; ---------------------------------------------------------------------------
InvincibilityStars_Layer0Frames:
		dc.b 8,5,7,6,6,7,5,8,6,7,7,6
InvincibilityStars_Layer1Frames:
		dc.b 8,7,6,5,4,3,4,5,6,7
		dc.b 3,4,5,6,7,8,7,6,5,4
InvincibilityStars_Layer2Frames:
		dc.b 8,7,6,5,4,3,2,3,4,5,6,7
		dc.b 2,3,4,5,6,7,8,7,6,5,4,3
InvincibilityStars_Layer3Frames:
		dc.b 7,6,5,4,3,2,1,2,3,4,5,6
		dc.b 1,2,3,4,5,6,7,6,5,4,3,2
		even

; ===========================================================================
; Sprite mappings
; ---------------------------------------------------------------------------
Map_InvincibilityStars:
		include	"mappings/sprite/Invincibility Stars.asm"
; ===========================================================================
