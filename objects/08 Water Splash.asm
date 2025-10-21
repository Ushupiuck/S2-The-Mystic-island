; ---------------------------------------------------------------------------
; Object 08 - Water splash, Spindash dust
; ---------------------------------------------------------------------------

Splash:
		moveq	#0,d0
		move.b	obRoutine(a0),d0
		move.w	Spla_Index(pc,d0.w),d1
		jmp	Spla_Index(pc,d1.w)
; ===========================================================================
Spla_Index:	dc.w Spla_Main-Spla_Index
		dc.w Spla_Display-Spla_Index
		dc.w Spla_Delete-Spla_Index

obj08_previous_frame = objoff_30
obj08_dust_timer = objoff_32
obj08_belongs_to_tails = objoff_34
obj08_vram_address = objoff_3C
; ===========================================================================

Spla_Main:	; Routine 0
		addq.b	#2,obRoutine(a0)
		move.l	#Map_Splash,obMap(a0)
		ori.b	#4,obRender(a0)
		move.b	#1,obPriority(a0)
		move.b	#$10,obActWid(a0)
		move.w	#make_art_tile(ArtTile_LZ_Splash,2,0),obGfx(a0)
		move.w	(v_player+obX).w,obX(a0) ; copy x-position from Sonic

Spla_Display:	; Routine 2
		move.w	(v_waterpos1).w,obY(a0) ; copy y-position from water height
		lea	Ani_Splash(pc),a1
		jsr	(AnimateSprite).l
		jmp	(DisplaySprite).l
; ===========================================================================

Spla_Delete:	; Routine 4
		jmp	(DeleteObject).l	; delete when animation is complete
; ===========================================================================
; animation script
Ani_Splash:	dc.w byte_129C2-Ani_Splash
byte_129C2:	dc.b 4,	0,	1,	2,	$FC,	0
		even
; ---------------------------------------------------------------------------
; sprite mappings
; ---------------------------------------------------------------------------
Map_Splash:	binclude	"mappings/sprite/obj08.bin"
		even