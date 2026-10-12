; ---------------------------------------------------------------------------
; Object 38 - shield only; invincibility stars are handled by Obj35
; ---------------------------------------------------------------------------

Obj38:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Obj38_Index(pc,d0.w),d1
		jmp	Obj38_Index(pc,d1.w)
; ===========================================================================
Obj38_Index:
		dc.w Obj38_Init-Obj38_Index
		dc.w Obj38_Shield-Obj38_Index
; ===========================================================================

Obj38_Init:	; Routine 0
		move.b	#2,obRoutine(a0)
		move.l	#Map_obj38,obMap(a0)
		move.b	#Map_obj38_height,height_pixels(a0)
		move.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#sprite_bound($18,Map_obj38_width),obActWid(a0)
		move.w	#make_art_tile(ArtTile_Shield,0,0),obGfx(a0)
		cmpi.b	#id_EHZ,(Current_Zone).w
		bne.s	Obj38_Shield
		move.w	#make_art_tile(ArtTile_EHZ_Shield,0,0),obGfx(a0)

; ===========================================================================
; Routine 2 - follow the shield's owner. Hide the shield during
; invincibility, and delete it when that player dies or loses the shield.
; ---------------------------------------------------------------------------
Obj38_Shield:
		movea.w	obParent(a0),a2
		tst.b	obID(a2)
		beq.s	Obj38_Delete
		cmpi.b	#6,obRoutine(a2)
		bhs.s	Obj38_Delete
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a2)
		bne.s	.return				; retain the shield while its owner is invincible
		btst	#obStatusSecondary_hasShield,obStatusSecondary(a2)
		beq.s	Obj38_Delete
		move.w	obX(a2),obX(a0)
		move.w	obY(a2),obY(a0)
		move.b	obStatus(a2),obStatus(a0)
		andi.w	#drawing_mask,obGfx(a0)
		tst.w	obGfx(a2)
		bpl.s	.animate
		ori.w	#high_priority,obGfx(a0)
.animate:
		lea	(Ani_obj38).l,a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
.return:
		rts

; ===========================================================================
; Remove this player's shield effect; the partner's effect is independent.
; ---------------------------------------------------------------------------
Obj38_Delete:
		jmp	(DeleteObject).l

; ===========================================================================
; Shield animation. Frame 5 is the large flash between the smaller frames.
; ---------------------------------------------------------------------------
Ani_obj38:
		dc.w .shield-Ani_obj38
.shield:
		dc.b 0,5,0,5,1,5,2,5,3,5,4,afEnd
		even
; ===========================================================================
