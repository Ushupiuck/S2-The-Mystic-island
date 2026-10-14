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
		move.l	#Splash,code(a1)
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
		move.b	#Map_Splash_height,height_pixels(a0)
		ori.b	#4,obRender(a0)
		move.w	#$80,obPriority(a0)
		move.b	#sprite_bound($10,Map_Splash_width),obActWid(a0)
		move.w	#make_art_tile(ArtTile_Sonic_Dust,0,0),obGfx(a0)
		move.w	#ArtTile_Sonic_Dust*tile_size,objoff_40(a0)
		; Scripted/debug splashes default to the main player.
		tst.w	obParent(a0)
		bne.s	.owner
		move.w	#v_player,obParent(a0)
		move.w	(v_player+obX).w,obX(a0)
.owner:
		cmpi.w	#v_player,obParent(a0)
		beq.s	Spla_Display
		move.w	#make_art_tile(ArtTile_Tails_Dust,0,0),obGfx(a0)
		move.w	#ArtTile_Tails_Dust*tile_size,objoff_40(a0)

Spla_Display:	; Routine 2
		move.w	(v_waterpos1).w,obY(a0) ; copy y-position from water height
		lea	Ani_Splash(pc),a1
		bsr.w	AnimateSprite
		cmpi.b	#4,obRoutine(a0)
		beq.s	Spla_Delete
		moveq	#0,d0
		move.b	obFrame(a0),d0
		lea	DPLC_Splash(pc),a2
		move.w	objoff_40(a0),d4
		moveq	#WaterArt_Splash,d5
		move.l	#Art_WaterSplash,d6
		bsr.w	PlayerWaterArt_LoadDPLC
		bcs.s	.return
		bra.w	DisplaySprite
.return:	rts
; ===========================================================================

Spla_Delete:	; Routine 4
		bra.w	DeleteObject	; delete when animation is complete
; ===========================================================================
; animation script
Ani_Splash:	dc.w byte_129C2-Ani_Splash
byte_129C2:	dc.b 3,1,2,3,4,5,6,7,8,9,afRoutine
		even
DPLC_Splash:
		include "mappings/spriteDPLC/Water splash.asm"
