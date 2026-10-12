; ---------------------------------------------------------------------------
; Object 08 - water splash; dust is handled by object 0E
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Spawn the splash in the owner's reserved slot and reset a previous animation.
; a0 remains the player. Dust has its own controller and is never reused here.
; ---------------------------------------------------------------------------
SpawnPlayerSplash:
		lea	(v_splash).w,a1
		cmpa.w	#v_player,a0
		beq.s	.slot
		lea	(v_tsplash).w,a1
.slot:
		movea.l	a1,a2
		moveq	#object_size/2-1,d1
.clear:
		clr.w	(a2)+
		dbf	d1,.clear
		move.b	#id_Obj08,obID(a1)
		move.w	a0,obParent(a1)
		move.w	obX(a0),obX(a1)
		rts

Splash:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Spla_Index(pc,d0.w),d1
		jmp	Spla_Index(pc,d1.w)
; ===========================================================================
Spla_Index:	dc.w Spla_Main-Spla_Index
		dc.w Spla_Display-Spla_Index
		dc.w Spla_Delete-Spla_Index

; ===========================================================================

Spla_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Splash,obMap(a0)
		ori.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.w	#make_art_tile(ArtTile_LZ_Splash,2,0),obGfx(a0)
		; Scripted/debug splashes default to the main player.
		tst.w	obParent(a0)
		bne.s	Spla_Display
		move.w	(v_player+obX).w,obX(a0)

Spla_Display:	; Routine 2
		move.w	(v_waterpos1).w,obY(a0) ; copy y-position from water height
		lea	Ani_Splash(pc),a1
		bsr.w	AnimateSprite
		bra.w	DisplaySprite
; ===========================================================================

Spla_Delete:	; Routine 4
		bra.w	DeleteObject	; delete when animation is complete
; ===========================================================================
; animation script
Ani_Splash:	dc.w byte_129C2-Ani_Splash
byte_129C2:	dc.b 4, 0, 1, 2, afRoutine
		even
