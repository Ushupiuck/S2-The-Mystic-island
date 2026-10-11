; ---------------------------------------------------------------------------
; Object 35 - all four S2 invincibility-star layers in one shared SST
; $10-$3F: eight six-byte child sprites; $40-$47: four angles/frame counters;
; $48-$49: parent. Normal routine/priority/parent fields overlap child sprites.
; ---------------------------------------------------------------------------

invincibility_angles	= $40
invincibility_frames	= $44
invincibility_parent	= $48
		if (subspr_data+8*next_subspr<>invincibility_angles)||(invincibility_parent+2>object_size)
			fatal "The composite invincibility stars need eight children and ten bytes of state."
		endif

Obj35:
		move.l	d7,-(sp)			; ExecuteObjects owns this loop counter
		btst	#6,obRender(a0)
		bne.s	InvincibilityStars_Update
		move.l	#Map_InvincibilityStars,obMap(a0)
		move.w	#make_art_tile(ArtTile_Invincibility,0,0),obGfx(a0)
		move.b	#$54,obRender(a0)		; world coordinates, composite sprites, accurate Y culling
		clr.b	mainspr_mapframe(a0)		; no main sprite
		move.b	#$FF,mainspr_width(a0)		; include the moving history trail in X culling
		move.l	#$0400162C,invincibility_angles(a0)
		clr.l	invincibility_frames(a0)

InvincibilityStars_Update:
		tst.b	(Super_Sonic_flag).w
		bne.w	InvincibilityStars_Delete
		lea	(v_player).w,a1			; prefer the main player when both are invincible
		bsr.w	InvincibilityStars_CheckParent
		bne.s	.parent_ready
		lea	(v_player2).w,a1
		bsr.w	InvincibilityStars_CheckParent
		beq.w	InvincibilityStars_Delete
.parent_ready:
		move.w	a1,invincibility_parent(a0)
		move.w	obX(a1),obX(a0)
		move.w	obY(a1),obY(a0)
		lea	(Sonic_Pos_Record_Buf).w,a5
		move.w	(Sonic_Pos_Record_Index).w,d4
		cmpa.w	#v_player,a1
		bne.s	.tails_history
		cmpi.w	#2,(Player_mode).w		; Tails as the main character
		bne.s	.history_ready
.tails_history:
		lea	(Tails_Pos_Record_Buf).w,a5
		move.w	(Tails_Pos_Record_Index).w,d4
.history_ready:
		clr.b	mainspr_childsprites(a0)
		lea	subspr_data(a0),a2
		lea	InvincibilityStars_Layers(pc),a3
		lea	invincibility_angles(a0),a4
		moveq	#0,d7
.layer:
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
		move.b	d2,invincibility_frames-invincibility_angles(a4)
		addq.b	#1,invincibility_frames-invincibility_angles(a4)
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
		moveq	#2,d2
		tst.w	d7
		bne.s	.speed_ready
		moveq	#9*2,d2				; the leading layer orbits faster
.speed_ready:
		btst	#status.player.x_flip,obStatus(a1)
		beq.s	.angle_ready
		neg.w	d2
.angle_ready:
		add.b	d2,(a4)+
		addq.w	#4,a3
		addq.w	#1,d7
		cmpi.w	#4,d7
		blo.w	.layer
		move.b	#$FF,mainspr_height(a0)		; first child's unused frame high byte holds the Y radius
		tst.b	mainspr_childsprites(a0)
		beq.s	.return
		move.w	#$80,d0				; priority is supplied, never written over child #2
		bsr.w	DisplaySprite3
.return:
		move.l	(sp)+,d7
		rts

InvincibilityStars_Delete:
		move.l	(sp)+,d7
		bra.w	DeleteObject

; Z clear only for a living, present player with the invincibility bit set.
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

; Pack only nearby children. This prevents distant trail coordinates from
; wrapping onto the screen when the VDP truncates X positions to nine bits.
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

InvincibilityStars_GetPosition:
		andi.w	#$3E,d6
		move.b	(a6,d6.w),d2
		move.b	1(a6,d6.w),d3
		ext.w	d2
		ext.w	d3
		add.w	d0,d2
		add.w	d1,d3
		rts

InvincibilityStars_Layers:
		dc.w InvincibilityStars_Layer0Frames-InvincibilityStars_Layers
		dc.b 0,12
		dc.w InvincibilityStars_Layer1Frames-InvincibilityStars_Layers
		dc.b 10,10
		dc.w InvincibilityStars_Layer2Frames-InvincibilityStars_Layers
		dc.b 12,12
		dc.w InvincibilityStars_Layer3Frames-InvincibilityStars_Layers
		dc.b 12,12

InvincibilityStars_Positions:
		dc.b 15,0,15,3,14,6,13,8,11,11,8,13,6,14,3,15
		dc.b 0,16,-4,15,-7,14,-9,13,-12,11,-14,8,-15,6,-16,3
		dc.b -16,0,-16,-4,-15,-7,-14,-9,-12,-12,-9,-14,-7,-15,-4,-16
		dc.b -1,-16,3,-16,6,-15,8,-14,11,-12,13,-9,14,-7,15,-4
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

Map_InvincibilityStars:
		include	"mappings/sprite/Invincibility Stars.asm"

; ---------------------------------------------------------------------------
; Shared per-player invincibility timer. Keep the music while either player
; remains invincible; shield/speed-shoe migration is handled separately.
; ---------------------------------------------------------------------------
Player_ChkInvincibility:
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a0)
		beq.s	.return
		tst.w	invtime(a0)
		beq.s	.return
		subq.w	#1,invtime(a0)
		bne.s	.return
		bclr	#obStatusSecondary_isInvincible,obStatusSecondary(a0)
		move.b	(v_player+obStatusSecondary).w,d0
		or.b	(v_player2+obStatusSecondary).w,d0
		btst	#obStatusSecondary_isInvincible,d0
		bne.s	.return
		tst.b	(Super_Sonic_flag).w
		bne.s	.return
		tst.b	(f_lockscreen).w
		bne.s	.return
		cmpi.w	#12,(v_air).w
		bls.s	.return
		moveq	#0,d0
		move.b	(Current_Zone).w,d0
		lea	(MusicList).l,a1
		move.b	(a1,d0.w),d0
		jmp	(PlaySound).l
.return:
		rts
