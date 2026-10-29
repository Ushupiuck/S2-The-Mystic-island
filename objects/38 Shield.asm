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
		move.b	#Map_obj38_width,obActWid(a0)

; ===========================================================================
; Routine 2 - follow the shield's owner. Hide the shield during
; invincibility, and delete it when that player dies or loses the shield.
; ---------------------------------------------------------------------------
Obj38_Shield:
		movea.w	obParent(a0),a2
		tst.l	code(a2)
		beq.s	Obj38_Delete
		cmpi.b	#6,obRoutine(a2)
		bhs.s	Obj38_Delete
		btst	#obStatusSecondary_isInvincible,obStatusSecondary(a2)
		bne.s	Obj38_Delete.return		; retain the shield while its owner is invincible
		btst	#obStatusSecondary_hasShield,obStatusSecondary(a2)
		beq.s	Obj38_Delete
		; Tails uses the auxiliary bank. Sonic also uses it while Tails has
		; invincibility, leaving the primary bank's shared star art intact.
		move.w	#make_art_tile(ArtTile_Shield_2,0,0),obGfx(a0)
		cmpi.w	#v_player,obParent(a0)
		bne.s	.bank_ready
		btst	#obStatusSecondary_isInvincible,(v_player2+obStatusSecondary).w
		bne.s	.bank_ready
		move.w	#make_art_tile(ArtTile_Shield,0,0),obGfx(a0)
.bank_ready:
		move.w	obX(a2),obX(a0)
		move.w	obY(a2),obY(a0)
		move.b	obStatus(a2),obStatus(a0)
		andi.w	#drawing_mask,obGfx(a0)
		tst.w	obGfx(a2)
		bpl.s	.animate
		ori.w	#high_priority,obGfx(a0)
.animate:
		lea	Ani_obj38(pc),a1
		jsr	(AnimateSprite).l
		bsr.s	Shield_LoadArt
		bcs.s	Obj38_Delete.return		; retry a full DMA queue before drawing
		jmp	(DisplaySprite).l

; ===========================================================================
; Remove this player's shield effect; the partner's effect is independent.
; These SSTs are reserved: retain their physical-bank cache when retiring
; the object, including the Game Over reservation stored there.
; ---------------------------------------------------------------------------
Obj38_Delete:
		clr.l	code(a0)
.return:	rts

; Stream the current frame through the common S3&K DPLC loader. The cache
; also records resident stars, so the first visible shield frame restores
; its art even when its animation frame did not change during invincibility.
Shield_LoadArt:
		moveq	#0,d0
		move.b	obFrame(a0),d0
		addq.w	#PlayerEffects_ShieldFrameBias,d0 ; zero remains the empty-bank cache
		lea	(DPLC_Shield).l,a2
		move.w	obGfx(a0),d4
		lsl.w	#5,d4				; tile bytes; upper attribute bits shift out
		lea	(v_shieldobj+effect_loaded_frame).w,a3
		cmpi.w	#ArtTile_Shield*tile_size,d4
		beq.s	.cache_ready
		lea	(v_shieldobj2+effect_loaded_frame).w,a3
.cache_ready:
		cmpi.b	#PlayerEffects_GameOverLoaded,(a3)
		beq.w	Load_DynamicPLC.full_return	; no frame was pushed by this caller
		move.l	#Art_Shield,d6
		jmp	(Load_DynamicPLC).l

; ===========================================================================
; Shield animation
; ---------------------------------------------------------------------------
Ani_obj38:
		dc.w .shield-Ani_obj38
.shield:	dc.b 1
		dc.b 1, 0, 2, 0, 3, 0
		dc.b afEnd
		even
; ===========================================================================
