; ---------------------------------------------------------------------------
; Object 35 - all four S2 invincibility-star layers in one shared SST
; Pack eight children in $10-$3F and keep orbit state in $40-$48. This is a
; normal composite object: BuildSprites needs no effect-specific dispatch.
; ---------------------------------------------------------------------------
; SST Variables:

InvincibilityStars_LayerCount = 4
InvincibilityStars_Priority = $80
invincibility_angles	= objoff_40	; four bytes: the current frame's orbit angles
invincibility_frames	= objoff_44	; four bytes: the current frame's animation indices
invincibility_flags	= objoff_48	; bit 7: initialized; bit 0: preceding frame's facing
		if (subspr_data+InvincibilityStars_LayerCount*2*next_subspr>invincibility_angles)||(invincibility_frames<>invincibility_angles+InvincibilityStars_LayerCount)||(invincibility_flags<>invincibility_frames+InvincibilityStars_LayerCount)||(invincibility_flags>=height_pixels)
			fatal "The shared stars must fit their children and orbit state below height_pixels."
		endif
; ---------------------------------------------------------------------------

; Initialise the shared effect on its first update, then choose its parent.
Obj35:
		moveq	#0,d2
		tst.b	invincibility_flags(a0)
		bmi.s	InvincibilityStars_Update
		move.l	#Map_InvincibilityStars,obMap(a0)
		move.w	#make_art_tile(ArtTile_Invincibility,0,0),obGfx(a0)
		move.b	#$44,obRender(a0)		; world coordinates, composite with wrapped Y
		clr.b	mainspr_mapframe(a0)		; no main sprite
		move.b	#$FF,mainspr_width(a0)		; children perform their own bounds checks
		move.l	#$0400162C,invincibility_angles(a0)
		clr.l	invincibility_frames(a0)
		moveq	#1,d2				; draw the initial phase before advancing it

; ===========================================================================
; Follow a live invincible player and queue the shared effect.
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
		move.b	obStatus(a1),d0
		andi.b	#1,d0
		ori.b	#$80,d0
		move.b	d0,invincibility_flags(a0)	; initialized, with this frame's orbit direction
		bra.s	InvincibilityStars_BuildChildren

; ===========================================================================
; Advance once per object update, including frames that are not rendered.
; The saved orientation belongs to the preceding frame, matching S2's
; draw-then-advance orbit timing when the parent turns or changes.
; ---------------------------------------------------------------------------
InvincibilityStars_Advance:
		lea	invincibility_angles(a0),a2
		lea	invincibility_frames(a0),a3
		lea	InvincibilityStars_Layers(pc),a4
		moveq	#InvincibilityStars_LayerCount-1,d1
		moveq	#9*2,d2
.layer:
		btst	#status.player.x_flip,invincibility_flags(a0)
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
; Prepare the generic composite during the object's update. Child data
; overlaps the usual routine/status/priority fields, so this object uses
; invincibility_flags for initialization/facing and DisplaySprite3 to queue.
; Preserve ExecuteObjects' loop counter while preparing all four layers.
; ---------------------------------------------------------------------------
InvincibilityStars_BuildChildren:
		move.l	d7,-(sp)
		lea	invincibility_angles(a0),a4
		andi.b	#$7F,obRender(a0)		; no children means the effect stays offscreen
		move.w	(Camera_RAM).w,obX(a0)		; children perform their own bounds checks
		move.w	(Camera_RAM+4).w,d0
		addi.w	#224/2,d0			; header stays visible across camera motion/Y wraps
		move.w	d0,obY(a0)
		; Select this player's position history, including Tails as player 1.
		lea	(Sonic_Pos_Record_Buf).w,a5
		move.w	(Sonic_Pos_Record_Index).w,d4
		cmpa.w	#v_player,a1
		bne.s	.tails_history
		cmpi.w	#PlayerMode_Tails,(Player_mode).w
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
		andi.w	#$3E,d6
		move.b	(a6,d6.w),d2
		move.b	1(a6,d6.w),d3
		ext.w	d2
		ext.w	d3
		add.w	d0,d2
		add.w	d1,d3
		bsr.w	InvincibilityStars_WriteChild
		addi.w	#16*2,d6			; opposite side of the orbit
		swap	d5
		andi.w	#$3E,d6
		move.b	(a6,d6.w),d2
		move.b	1(a6,d6.w),d3
		ext.w	d2
		ext.w	d3
		add.w	d0,d2
		add.w	d1,d3
		bsr.w	InvincibilityStars_WriteChild
		addq.w	#1,a4
		addq.w	#4,a3
		addq.w	#1,d7
		cmpi.w	#InvincibilityStars_LayerCount,d7
		blo.w	.layer
		move.l	(sp)+,d7
		tst.b	mainspr_childsprites(a0)
		beq.s	.return
		move.w	#InvincibilityStars_Priority,d0	; obPriority belongs to packed child data
		jmp	(DisplaySprite3).l
.return:
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
; a0 = shared SST, a2 = next child, a6/d6 = orbit position.
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
